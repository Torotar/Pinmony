import { PinmonyDetailSnapshot, PinmonyVideo, PinmonyVideoSource } from '../models/PinmonyDetail';
import { PinmonyRuntimeLog } from 'common_foundation';

interface PrefetchImage { url: string; width: number; height: number; }
interface PrefetchCreator { full_name?: string; username?: string; image_medium_url?: string; is_verified_merchant?: boolean; }
interface PrefetchOfferSummary { price?: string; }
interface PrefetchProduct { offer_summary?: PrefetchOfferSummary; }
interface PrefetchRichMetadata { description?: string; site_name?: string; url?: string; products?: PrefetchProduct[]; }
interface PrefetchVideo extends PrefetchImage { duration?: number; }
interface PrefetchVideoList { V_HLSV4?: PrefetchVideo; V_720P?: PrefetchVideo; }
interface PrefetchVideos { video_list?: PrefetchVideoList; }
interface PrefetchBlock { block_type?: number; blockType?: number; __typename?: string; video?: Object; videos?: Object; video_data?: Object; }
interface PrefetchStoryPage { blocks?: PrefetchBlock[]; }
interface PrefetchStory { pages?: PrefetchStoryPage[]; story_pages?: PrefetchStoryPage[]; is_deleted?: boolean; }
interface PrefetchCarousel { pages?: Object[]; carousel_slots?: Object[]; }
interface PrefetchPin {
  shuffle?: PrefetchShuffle;
  id: string; type: string; images: Record<string, PrefetchImage>;
  title?: string; grid_title?: string; closeup_unified_title?: string;
  description?: string; closeup_unified_description?: string;
  rich_metadata?: PrefetchRichMetadata; rich_summary?: PrefetchRichMetadata;
  price_value?: number | string; price_currency?: string; affiliate_disclosure?: string;
  closeup_attribution?: PrefetchCreator; closeup_unified_attribution?: PrefetchCreator;
  link?: string; mobile_link?: string; tracked_link?: string; utm_link?: string;
  affiliate_link?: string; pin_direct_to_site_url?: string;
  origin_pinner?: PrefetchCreator; pinner?: PrefetchCreator;
  link_domain?: string; domain?: string; ai_disclosures?: number[];
  gen_ai_topics?: PrefetchAiTopic[]; digital_media_source_type?: number;
  is_video?: boolean; videos?: PrefetchVideos;
  story_pin_data?: PrefetchStory; carousel_data?: PrefetchCarousel;
}
interface PrefetchAiTopic { name?: string; }
interface PrefetchShuffle { id?: string; }
interface PrefetchResource { status: string; data: PrefetchPin; }
interface PrefetchResponse { resource_response: PrefetchResource; }
interface PrefetchEntry { pinUrl: string; detail: PinmonyDetailSnapshot; expiresAt: number; }
interface SelectedPinResource { status: string; data: Record<string, Object>; }
interface SelectedPinResponse { resource_response: SelectedPinResource; }
type DetailReader = (url: string, id: string, current: () => boolean) => Promise<string>;

// Select only business fields used by detail/media/post contracts. Never retain
// client_context, authentication fields or the original response envelope.
function detailResource(body: string, pinUrl: string): string {
  if (body.length > 512 * 1024) throw new Error('detail-too-large');
  const response: PrefetchResponse = JSON.parse(body) as PrefetchResponse;
  const pin: PrefetchPin = response.resource_response?.data;
  if (response.resource_response?.status !== 'success' || !pin || pin.type !== 'pin' ||
      String(pin.id) !== pinUrl.split('/pin/')[1].split('/')[0]) throw new Error('invalid-detail');
  const input: Record<string, Object> = JSON.parse(JSON.stringify(pin)) as Record<string, Object>;
  const selected: Record<string, Object> = {};
  const fields: string[] = ['id', 'type', 'images', 'title', 'grid_title', 'closeup_unified_title',
    'description', 'closeup_unified_description', 'origin_pinner', 'pinner', 'link_domain', 'domain',
    'rich_metadata', 'rich_summary', 'price_value', 'price_currency', 'affiliate_disclosure',
    'closeup_attribution', 'closeup_unified_attribution',
    'link', 'mobile_link', 'tracked_link', 'utm_link', 'affiliate_link', 'pin_direct_to_site_url',
    'ai_disclosures', 'gen_ai_topics', 'digital_media_source_type', 'is_video', 'videos', 'story_pin_data', 'carousel_data', 'aggregated_pin_id',
    'aggregated_pin_data', 'comment_count', 'tracking_params', 'client_tracking_params', 'reaction_data', 'reaction_by_me', 'reaction_counts',
    'is_eligible_for_image_download', 'is_eligible_for_ai_comparison', 'has_hidden_inner_pin', 'board',
    'through_id', 'rec_reason_type', 'source'];
  fields.forEach((field: string) => { if (input[field] !== undefined) selected[field] = input[field]; });
  if (typeof pin.shuffle?.id === 'string' && /^\d{1,40}$/.test(pin.shuffle.id)) {
    const shuffleIdentity: PrefetchShuffle = { id: pin.shuffle.id };
    selected['shuffle'] = shuffleIdentity;
  }
  const result: SelectedPinResponse = { resource_response: { status: 'success', data: selected } };
  return JSON.stringify(result);
}

function clean(value: string | undefined, limit: number = 4000): string {
  return typeof value === 'string' ? value.trim().slice(0, limit) : '';
}

// Zero is also used by non-commerce Pins: require a positive, finite amount and an ISO currency.
export function detailPriceText(value: number | string | undefined, currency: string | undefined): string {
  if (typeof value !== 'number' && (typeof value !== 'string' || !/^\d+(?:\.\d{1,4})?$/.test(value))) return '';
  const amount: number = Number(value);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000000000 ||
      typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) return '';
  return currency + ' ' + amount.toFixed(2);
}

function detailSourceUrl(pin: PrefetchPin): string {
  const candidates: (string | undefined)[] = [pin.link, pin.mobile_link, pin.tracked_link, pin.utm_link,
    pin.affiliate_link, pin.pin_direct_to_site_url, pin.rich_metadata?.url, pin.rich_summary?.url];
  for (const candidate of candidates) {
    if (typeof candidate !== 'string' || candidate.length > 2000 || /[\s\\]/.test(candidate)) continue;
    const host: RegExpMatchArray | null = candidate.match(/^https:\/\/([^/?#]+)(?:[/?#]|$)/i);
    if (host && !/[@:]/.test(host[1]) && !/(^|\.)(pinterest\.com|pinimg\.com|pin\.it)$/i.test(host[1])) return candidate;
  }
  return '';
}
function imageValid(image: PrefetchImage | undefined): boolean {
  return !!image && typeof image.url === 'string' && image.url.length <= 2000 &&
    /^https:\/\/[^\s]+$/i.test(image.url) && Number.isFinite(image.width) &&
    Number.isFinite(image.height) && image.width > 0 && image.height > 0;
}

// The same PinResource contract as detail, without live controls or playback.
export function mapPrefetchedDetail(body: string, pinUrl: string, allowPendingMedia: boolean = false): PinmonyDetailSnapshot | undefined {
  if (body.length > 512 * 1024 || !/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pinUrl)) return undefined;
  try {
    const payload: PrefetchResponse = JSON.parse(body) as PrefetchResponse;
    const pin: PrefetchPin = payload.resource_response?.data;
    const id: string = pinUrl.split('/pin/')[1].split('/')[0];
    if (payload.resource_response?.status !== 'success' || !pin || pin.type !== 'pin' || String(pin.id) !== id) return undefined;
    const images: Record<string, PrefetchImage> = pin.images || {};
    const image: PrefetchImage | undefined = ['736x', '474x', '564x', 'orig', '236x']
      .map((size: string): PrefetchImage => images[size]).find((item: PrefetchImage): boolean => imageValid(item));
    if (!image) return undefined;
    // A cover is not a complete carousel/story. Keep their existing resolver.
    if (pin.carousel_data?.pages?.length || !allowPendingMedia && pin.carousel_data?.carousel_slots?.length) return undefined;
    const story: PrefetchStory | undefined = pin.story_pin_data;
    if (story?.pages?.length || story?.story_pages?.length) {
      const blocks: PrefetchBlock[] | undefined = story.pages?.[0]?.blocks;
      const block: PrefetchBlock | undefined = blocks?.[0];
      if (story.is_deleted || story.pages?.length !== 1 || story.story_pages?.length || blocks?.length !== 1 || !block ||
        !(block.block_type === 2 || block.blockType === 2 || block.__typename === 'StoryPinImageBlock') ||
        block.video || block.videos || block.video_data) return undefined;
    }
    const sources: PinmonyVideoSource[] = [];
    const list: PrefetchVideoList | undefined = pin.videos?.video_list;
    const hls: PrefetchVideo | undefined = list?.V_HLSV4;
    const mp4: PrefetchVideo | undefined = list?.V_720P;
    if (hls && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/videos\/[^\s?#]+\.m3u8(?:\?[^\s#]*)?$/i.test(hls.url) && hls.url.length <= 2000)
      sources.push({ url: hls.url, kind: 'hls' });
    if (mp4 && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/videos\/[^\s?#]+\.mp4(?:\?[^\s#]*)?$/i.test(mp4.url) && mp4.url.length <= 2000)
      sources.push({ url: mp4.url, kind: 'mp4' });
    const isVideo: boolean = pin.is_video === true || !!pin.videos;
    if (isVideo && !sources.length && !allowPendingMedia) return undefined;
    const primary: PrefetchVideo | undefined = sources[0]?.kind === 'hls' ? hls : mp4;
    const video: PinmonyVideo | undefined = isVideo && primary ? { pinId: id, sources: sources,
      width: Number.isFinite(primary.width) ? Math.max(0, primary.width) : 0,
      height: Number.isFinite(primary.height) ? Math.max(0, primary.height) : 0,
      duration: Number.isFinite(primary.duration) ? Math.max(0, Math.min(86400000, primary.duration || 0)) : 0 } : undefined;
    const creator: PrefetchCreator = pin.closeup_unified_attribution || pin.closeup_attribution || pin.origin_pinner || pin.pinner || {};
    return { kind: 'cached', dataSource: 'api', session: 0, pinUrl: pinUrl,
      shuffleId: typeof pin.shuffle?.id === 'string' && /^\d{1,40}$/.test(pin.shuffle.id) ? pin.shuffle.id : undefined,
      imageUrl: image.url, imageWidth: image.width, imageHeight: image.height,
      originalImageUrl: imageValid(images['orig']) ? images['orig'].url : image.url,
      title: clean(pin.closeup_unified_title || pin.title || pin.grid_title, 500),
      description: clean(pin.closeup_unified_description || pin.description),
      priceText: clean(pin.rich_summary?.products?.[0]?.offer_summary?.price, 80) || detailPriceText(pin.price_value, pin.price_currency),
      richDescription: clean(pin.rich_metadata?.description, 12000),
      affiliateDisclosure: clean(pin.affiliate_disclosure, 300),
      sourceName: clean(pin.rich_metadata?.site_name || pin.rich_summary?.site_name, 180),
      creatorVerified: creator.is_verified_merchant === true,
      creator: clean(creator.full_name || creator.username, 180),
      creatorAvatar: /^https:\/\/[^\s]+$/i.test(creator.image_medium_url || '') ? clean(creator.image_medium_url, 2000) : '',
      creatorUrl: /^[a-zA-Z0-9_]+$/.test(creator.username || '') ? pinUrl.slice(0, pinUrl.indexOf('/', 8)) + '/' + creator.username + '/' : '',
      sourceLabel: detailSourceUrl(pin) ? (clean(pin.link_domain, 180) || clean(pin.domain, 180) || clean(pin.rich_metadata?.site_name, 180) || clean(pin.rich_summary?.site_name, 180) || detailSourceUrl(pin).split('/')[2]) : '',
      sourceUrl: detailSourceUrl(pin),
      aiLabel: (Array.isArray(pin.ai_disclosures) && pin.ai_disclosures.includes(1) ||
        Array.isArray(pin.gen_ai_topics) && pin.gen_ai_topics.some((topic: PrefetchAiTopic): boolean =>
          !!topic && typeof topic.name === 'string' && !!topic.name.trim())) ? '由 AI 修改' : '',
      isVideo: isVideo, video: video, actions: [], related: [] };
  } catch (_) { return undefined; }
}

export class PinmonyDetailPrefetch {
  private readonly requestPrefix: string;
  constructor(requestPrefix: string = 'detail_prefetch_') { this.requestPrefix = requestPrefix; }
  onReady?: (detail: PinmonyDetailSnapshot) => void;
  private entries: PrefetchEntry[] = [];
  private scope: string = '';
  private generation: number = 0;
  private sequence: number = 0;
  private queued: string[] = [];
  private attempted: Set<string> = new Set<string>();
  private jobs: Map<string, string> = new Map<string, string>();
  private pending: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private openingPin: string = '';
  private openingCurrent: (() => boolean) | undefined = undefined;
  private openingRequest: Promise<string> | undefined = undefined;
  private openingConsumed: boolean = false;
  private cancelRequest: ((id: string) => void) | undefined = undefined;

  get(pinUrl: string): PinmonyDetailSnapshot | undefined {
    this.entries = this.entries.filter((item: PrefetchEntry): boolean => item.expiresAt > Date.now());
    return this.entries.find((item: PrefetchEntry): boolean => item.pinUrl === pinUrl)?.detail;
  }
  pause(): void {
    this.generation++;
    this.jobs.forEach((_pin: string, id: string) => { if (this.cancelRequest) this.cancelRequest(id); });
    this.jobs.clear(); this.queued = []; this.attempted.clear(); this.scope = '';
    this.pending.clear(); this.openingPin = ''; this.openingCurrent = undefined;
    this.openingRequest = undefined; this.openingConsumed = false;
  }
  cancelExcept(pinUrl: string): void {
    this.jobs.forEach((pin: string, id: string) => {
      if (pin !== pinUrl) {
        if (this.cancelRequest) this.cancelRequest(id);
        this.jobs.delete(id); this.pending.delete(pin);
      }
    });
    this.queued = [];
  }
  open(pinUrl: string, read: DetailReader, current: () => boolean, cancel: (id: string) => void): Promise<string> {
    this.cancelExcept(pinUrl);
    this.openingPin = pinUrl; this.openingCurrent = current; this.openingConsumed = false;
    this.cancelRequest = cancel;
    // Completed speculative copies remain display-only. A fresh demand read
    // confirms current state; only an in-flight read is transferred to opening.
    const pending: Promise<string> | undefined = this.pending.get(pinUrl);
    this.openingRequest = pending || this.start(pinUrl, read, current);
    PinmonyRuntimeLog.info(pending ? 'DetailPrefetch: demand attached' : 'DetailTrace: demand started');
    return this.openingRequest;
  }
  consume(pinUrl: string): Promise<string> | undefined {
    if (pinUrl !== this.openingPin || this.openingConsumed || !this.openingCurrent?.()) return undefined;
    this.openingConsumed = true;
    const request: Promise<string> | undefined = this.openingRequest;
    this.openingRequest = undefined;
    return request;
  }
  private start(pin: string, read: DetailReader, homeCurrent: () => boolean): Promise<string> {
    const token: number = this.generation;
    const id: string = this.requestPrefix + (++this.sequence).toString();
    this.jobs.set(id, pin);
    const current = (): boolean => token === this.generation && this.jobs.has(id) &&
      (this.openingPin === pin && this.openingCurrent ? this.openingCurrent() : homeCurrent());
    const pinId: string = pin.split('/pin/')[1].split('/')[0];
    const options: string = JSON.stringify({ id: pinId, field_set_key: 'auth_web_main_pin',
      noCache: true, fetch_visual_search_objects: false, get_page_metadata: false,
      add_fields: 'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin' });
    const url: string = pin.slice(0, pin.indexOf('/', 8)) + '/resource/PinResource/get/?source_url=' +
      encodeURIComponent('/pin/' + pinId + '/') + '&data=' + encodeURIComponent('{"options":' + options + ',"context":{}}');
    PinmonyRuntimeLog.info('DetailPrefetch: start');
    const request: Promise<string> = read(url, id, current).then((body: string): string => {
      if (!current()) throw new Error('stale-detail');
      const resource: string = detailResource(body, pin);
      const detail: PinmonyDetailSnapshot | undefined = mapPrefetchedDetail(resource, pin);
      if (detail) PinmonyRuntimeLog.info('DetailCommerceTrace: stage=mapped price=' + (!!detail.priceText).toString() +
        ' description=' + (!!detail.richDescription).toString() + ' disclosure=' + (!!detail.affiliateDisclosure).toString() +
        ' source=' + (!!detail.sourceUrl).toString() + ' attribution=' + (!!detail.creator).toString());
      if (detail) {
        this.entries = this.entries.filter((item: PrefetchEntry): boolean => item.pinUrl !== pin && item.expiresAt > Date.now());
        this.entries.push({ pinUrl: pin, detail: detail, expiresAt: Date.now() + 120000 });
        while (this.entries.length > 24) this.entries.shift();
        if (this.onReady) this.onReady(detail);
      }
      PinmonyRuntimeLog.info('DetailPrefetch: ready');
      return resource;
    }).finally(() => {
      if (token === this.generation) { this.jobs.delete(id); this.pending.delete(pin); }
    });
    this.pending.set(pin, request);
    return request;
  }
  clear(): void { this.pause(); this.entries = []; }
  remove(pinUrl: string): void {
    this.entries = this.entries.filter((item: PrefetchEntry): boolean => item.pinUrl !== pinUrl);
  }

  offer(pinUrls: string[], scope: string, read: DetailReader,
    current: () => boolean, cancel: (id: string) => void): void {
    if (!current()) { this.pause(); return; }
    if (scope !== this.scope) { this.pause(); this.scope = scope; }
    this.cancelRequest = cancel;
    // Replace waiting work when the viewport moves; at most two reads in flight.
    this.queued = pinUrls.slice(0, 6).filter((pin: string): boolean =>
      /^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pin) && !this.get(pin) && !this.attempted.has(pin));
    const token: number = this.generation;
    const pump = (): void => {
      if (token !== this.generation || !current()) return;
      while (this.jobs.size < 2 && this.queued.length) {
        const pin: string = this.queued.shift()!;
        this.attempted.add(pin);
        if (this.attempted.size > 128) {
          const oldest: string = Array.from(this.attempted.values())[0];
          this.attempted.delete(oldest);
        }
        this.start(pin, read, current).catch(() => {
          PinmonyRuntimeLog.info('DetailPrefetch: failed or cancelled');
        }).finally(() => { if (token === this.generation) pump(); });
      }
    };
    pump();
  }
}
