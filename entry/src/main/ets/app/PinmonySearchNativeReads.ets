import { PinmonyI18n } from 'common_foundation';
import { PinmonySearchUserFollow, PinmonySearchUserFollowPorts } from './PinmonySearchUserFollow';
import { PinmonySearchBoardFollow, PinmonySearchBoardFollowPorts } from './PinmonySearchBoardFollow';
import { PinmonySearchNativeAuxiliary, PinmonySearchAuxiliaryPorts } from './PinmonySearchNativeAuxiliary';
import { PinmonySearchStore, PinmonySearchSnapshot, PinmonySearchResult, PinmonySearchCategory, PinmonySearchSuggestion, PinmonySearchFilterOption } from 'feature_search';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED, readNativeSearchProductRoute, PinmonySearchProductRoute } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyVideo, PinmonyVideoSource } from 'common_ui';
export const PIN_NATIVE_SEARCH_READS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface SearchReadOptions { query: string; scope: string; appliedProductFilters: string; domains: string | null; user: null; seoDrawerEnabled: boolean; applied_unified_filters: null; auto_correction_disabled: boolean; filter_genai: boolean; journey_depth: null; source_id: string; source_module_id: null; source_url: string; static_feed: boolean; selected_one_bar_modules: null; query_pin_sigs: null; page_size: number; gated: null; price_max: number | null; price_min: number | null; query_image_pins: null; request_params: null; top_pin_ids: string | null; article: null; corpus: null; filters: null; rs: string; bookmarks?: string[]; }
interface SuggestionOptions { field_set_key: string; limit: number; num_recent_queries: number; personal_search_only: boolean; pin_scope: string; recent_queries_tags: string; term: string; autocomplete_request_surface: number; }
interface ReadEnvelope { options: SearchReadOptions | SuggestionOptions; context: Record<string,string>; }
interface ApiReadData { bookmark_string?: string; }
interface ApiReadOptions { url: string; data: ApiReadData; }
interface ApiReadEnvelope { options: ApiReadOptions; context: Record<string,string>; }
interface ImageData { url: string; width: number; height: number; }
interface VideoData { url: string; width?: number; height?: number; duration?: number; }
interface Videos { video_list?: Record<string, VideoData>; }
interface SearchBoardOwner { full_name?: string; username?: string; }
interface SearchOffer { price?: string; standard_price?: string; }
interface SearchProduct { offer_summary?: SearchOffer; }
interface SearchRichSummary { site_name?: string; products?: SearchProduct[]; }
interface Item { section_count?: number; owner?: SearchBoardOwner; board_order_modified_at?: string; rich_summary?: SearchRichSummary; image_cover_url?: string; image_cover_hd_url?: string; pin_thumbnail_urls?: string[]; follower_count?: number; explicitly_followed_by_me?: boolean; blocked_by_me?: boolean; followed_by_me?: boolean; is_promoted?: boolean; ad_data?: Object; pin_promotion_id?: string; id?: string; type?: string; name?: string; full_name?: string; username?: string; url?: string; pin_count?: number; grid_title?: string; title?: string; description?: string; images?: Record<string, ImageData>; image_large_url?: string; image_medium_url?: string; videos?: Videos; }
interface Guide { term?: string; display?: string; image_medium_url?: string; dominant_color?: string; }
interface Display { display_text?: string; }
interface FilterAction { type?: string; feed_url?: string; filters?: FilterItem[]; title?: string; }
interface FilterItem { type?: string; label?: string; id?: string; title?: string; display?: Display; action?: FilterAction; is_selected?: boolean; disabled?: boolean; is_disabled?: boolean; filter_options?: FilterItem[]; }
interface FilterModule { action?: FilterAction; }
interface Suggestion { query?: string; display_query?: string; label?: string; type?: string; vertical?: string; }
interface ProductDomain { domain: string; label: string; }
interface ProductPrices { currency_type: string; min_value: number; max_value: number; }
interface ProductFilters { domainFilters?: ProductDomain[]; priceFilters?: ProductPrices; }
interface ProductDraft { domains: string[]; min: string; max: string; }
interface SearchData { productFilters?: ProductFilters; results: Item[]; rankedGuides?: Guide[]; oneBarModules?: FilterModule[]; items?: Suggestion[]; }
interface Resource { status: string; data: SearchData; bookmark?: string; }
interface SearchViewer { id: string; }
interface SearchClient { user?: SearchViewer; }
interface ResponseData { resource_response: Resource; client_context?: SearchClient; }
interface ArrayResource { status: string; data: FilterItem[]; }
interface ArrayResponse { resource_response: ArrayResource; }
interface HintItem { text?: string; }
interface HintResource { status: string; data: HintItem[]; }
interface HintResponse { resource_response: HintResource; }
interface ReadFeed { product?: ProductFilters; snapshot: PinmonySearchSnapshot; cursor: string; filters: PinmonySearchFilterOption[]; targets: Map<string, string>; modules: boolean; filterCursor: string; scroll: number; }
export interface PinmonySearchNativeReadsPorts {
  store: () => PinmonySearchStore;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  page: () => string;
  active: () => boolean;
  navigate: (page: string) => void;
  settled: () => void;
  profile?: () => string;
  feedback?: (message: string) => void;
  boardFollowConfirmed?: () => void;
}
// Account-owned reads. None of these capabilities grant website mutation permissions.
export class PinmonySearchNativeReads {
  private readonly ports: PinmonySearchNativeReadsPorts;
  private readonly store: PinmonySearchStore;
  private viewer: string = '';
  private readonly userFollow: PinmonySearchUserFollow;
  private readonly boardFollow: PinmonySearchBoardFollow;
  private account: string = '';
  private generation: number = -1;
  private origin: string = '';
  private revision: number = 0;
  private sequence: number = 0;
  private page: string = '';
  private busy: boolean = false;
  private error: string = '';
  private term: string | undefined = undefined;
  private suggestionRevision: number = 0;
  private suggestionId: string = '';
  private suggestionTimer: number = -1;
  private suggestions: PinmonySearchSuggestion[] = [];
  private suggestionBusy: boolean = false;
  private suggestionError: string = '';
  private hint: string = '';
  private hintReady: boolean = false;
  private filterRevision: number = 0;
  private filterId: string = '';
  cancelFilters(): void { this.filterRevision++; if(this.filterId) this.ports.network().cancel(this.filterId); this.filterId = ''; this.store.searchFilterLoading = false; }
  private readonly requests: Set<string> = new Set<string>();
  private readonly feeds: Map<string, ReadFeed> = new Map<string, ReadFeed>();
  private readonly auxiliary: PinmonySearchNativeAuxiliary;
  constructor(ports: PinmonySearchNativeReadsPorts) { this.userFollow = new PinmonySearchUserFollow({
    session: ports.session, network: ports.network,
    changed: (): void => this.apply(), feedback: (message: string): void => { ports.feedback?.(message); },
    confirmed: (id: string, following: boolean): void => {
      this.feeds.forEach((feed: ReadFeed): void => { feed.snapshot.results.forEach((row: PinmonySearchResult): void => {
        if (row.userId === id) row.following = following;
      }); });
      this.store.searchCache.clear(); ports.boardFollowConfirmed?.();
    }
  } as PinmonySearchUserFollowPorts); this.boardFollow = new PinmonySearchBoardFollow({
    session: ports.session, profile: (): string => ports.profile?.() || '', network: ports.network,
    changed: (): void => this.apply(), feedback: (message: string): void => { ports.feedback?.(message); },
    confirmed: (id: string, following: boolean): void => {
      this.feeds.forEach((feed: ReadFeed): void => { feed.snapshot.results.forEach((row: PinmonySearchResult): void => {
        if (row.boardId === id) row.following = following;
      }); });
      this.store.searchCache.clear(); ports.boardFollowConfirmed?.();
    }
  } as PinmonySearchBoardFollowPorts); this.ports = ports; this.store = ports.store(); this.auxiliary = new PinmonySearchNativeAuxiliary({store:ports.store,session:ports.session,network:ports.network,page:ports.page,active:ports.active} as PinmonySearchAuxiliaryPorts,(): void => this.apply()); }
  clearProductFilter(kind: string): void {
    if (!this.bind() || !this.page.startsWith(this.origin + '/search/buyable_pins/') || this.busy || this.error || !['price','merchant'].includes(kind)) return;
    const feed: ReadFeed | undefined = this.feeds.get(this.page);
    if (!feed || feed.snapshot.results.length || feed.snapshot.apiEnded !== true) return;
    const parts: string[] = this.page.split('?');
    const query: string = (parts[1] || '').split('&').filter((part: string): boolean => {
      const key: string = part.split('=')[0];
      return kind === 'price' ? key !== 'price_min' && key !== 'price_max' : key !== 'domains';
    }).join('&');
    const target: string = parts[0] + (query ? '?' + query : '');
    if (target !== this.page) this.navigate(target);
  }
  async followUser(id: string): Promise<void> {
    if (!this.bind()) return;
    const item: PinmonySearchResult | undefined = this.feeds.get(this.page)?.snapshot.results.find((row: PinmonySearchResult): boolean => row.id === id && row.kind === 'user');
    if (!item) return;
    const revision: number = this.revision, page: string = this.page;
    await this.userFollow.submit(item, this.viewer, (): boolean => this.owned() && this.revision === revision && this.page === page);
  }
  async followBoard(id: string): Promise<void> {
    if (!this.bind()) return;
    const item: PinmonySearchResult | undefined = this.feeds.get(this.page)?.snapshot.results.find((row: PinmonySearchResult): boolean => row.id === id && row.kind === 'board');
    if (!item) return;
    const revision: number = this.revision, page: string = this.page;
    await this.boardFollow.submit(item, this.viewer, (): boolean => this.owned() && this.revision === revision && this.page === page);
  }
  async quizAction(kind: string,id: string = ''): Promise<void> { if(this.bind())await this.auxiliary.action(kind,id); }
  async deleteHistory(id: string): Promise<void> {
    if(!this.bind() || this.term !== '')return;const item: PinmonySearchSuggestion | undefined = this.suggestions.find((s: PinmonySearchSuggestion): boolean => s.id === id && s.deletable === true && !s.deleting);
    if(!item?.query)return;const revision: number = this.suggestionRevision,page: string = this.page,query: string = item.query;
    const live = (): boolean => this.owned() && revision === this.suggestionRevision && page === this.page && this.term === '';
    item.deleting = true;this.apply();
    try {if(await this.auxiliary.deleteHistory(query,live) && live()){this.suggestions = this.suggestions.filter((s: PinmonySearchSuggestion): boolean => s.id !== id);this.apply();}}
    catch (_) {if(live()){item.deleting = false;item.deletable = !this.auxiliary.historyLocked(query);this.suggestionError = item.deletable ? '删除未提交成功，请重试' : PinmonyI18n.message('删除结果未确认，请刷新历史核对；不会重复提交');this.apply();}}
  }
  eligible(): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return PIN_NATIVE_SEARCH_READS_ENABLED && session.authenticated && !!session.accountId &&
      this.ports.page().startsWith(session.origin + '/search/');
  }
  private query(page: string): string { const match: RegExpMatchArray | null = page.match(/[?&]q=([^&#]*)/); try { return match ? decodeURIComponent(match[1].replace(/\+/g, ' ')).trim() : ''; } catch (_) { return ''; } }
  private param(page: string, name: string): string { const match: RegExpMatchArray | null = page.match(new RegExp('[?&]' + name + '=([^&#]*)')); try { return match ? decodeURIComponent(match[1].replace(/\+/g, ' ')) : ''; } catch (_) { return ''; } }
  private supported(page: string): boolean { return !!readNativeSearchProductRoute(page) && page.startsWith(this.origin + '/search/') && /^\/search\/(?:(pins|videos|boards|users|buyable_pins)\/)?(?:\?[^#]*)?$/.test(page.slice(this.origin.length)) && this.query(page).length <= 300 && !/[?&](?:filters|filter|shopping|color|video|filter_genai|applied_unified_filters)=/.test(page); }
  owned(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.eligible() && this.ports.active() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.page === this.ports.page(); }
  private bind(): boolean {
    if (!this.eligible() || !this.ports.active()) return false;
    const s: PinmonyBusinessSessionContext = this.ports.session();
    if (s.accountId !== this.account || s.generation !== this.generation || s.origin !== this.origin) { this.reset(); this.account = s.accountId; this.generation = s.generation; this.origin = s.origin; }
    const page: string = this.ports.page();
    if (page !== this.page) { this.pause(); this.page = page; this.term = undefined; this.suggestions = []; this.suggestionError = ''; this.error = ''; }
    this.store.searchNativeInputReady = true;
    return true;
  }
  pause(preserveScroll: boolean = true): void {
    this.userFollow.pause();
    this.boardFollow.pause();
    this.auxiliary.pause();
    const feed: ReadFeed | undefined = this.feeds.get(this.page); if(feed && preserveScroll) feed.scroll = this.store.searchScrollOffset;
    this.revision++; this.suggestionRevision++; this.filterRevision++;
    this.requests.forEach((id: string): void => this.ports.network().cancel(id)); this.requests.clear(); this.suggestionId = ''; this.filterId = '';
    if (this.suggestionTimer >= 0) clearTimeout(this.suggestionTimer); this.suggestionTimer = -1;
    this.busy = false; this.suggestionBusy = false; this.term = undefined; this.suggestions = []; this.suggestionError = '';
    this.store.searchNativeInputReady = false; this.store.searchNativeReadsReady = false; this.store.searchFilterLoading = false;
  }
  reset(): void { this.userFollow.reset(); this.boardFollow.reset(); this.viewer = ''; this.auxiliary.reset(); this.pause(); this.feeds.clear(); if(this.account) { this.store.search = undefined; this.store.retainedSearch = undefined; this.store.searchCache.clear(); this.store.searchScrollOffset = 0; } this.account = ''; this.generation = -1; this.origin = ''; this.page = ''; this.suggestions = []; this.hint = ''; this.hintReady = false; this.error = ''; this.store.searchFilterOptions = []; this.store.searchFilterError = ''; }
  apply(): void {
    if (!this.owned()) return;
    const feed: ReadFeed | undefined = this.feeds.get(this.page); const previous: PinmonySearchSnapshot | undefined = this.store.search;
    const next: PinmonySearchSnapshot = feed ? JSON.parse(JSON.stringify(feed.snapshot)) as PinmonySearchSnapshot : previous?.pageKey === this.page ? JSON.parse(JSON.stringify(previous)) as PinmonySearchSnapshot :
      { kind: 'loading', session: 0, pageKey: this.page, query: this.query(this.page), placeholder: '', selectedCategory: '', categories: [], suggestions: [], heroes: [], ideaSections: [], results: [] };
    if (this.query(this.page)) { next.kind = feed || this.error ? 'state' : 'loading'; next.api = true; next.apiBusy = this.busy; next.apiActive = !!feed; next.apiError = this.error; this.store.searchLoading = !feed && this.busy; this.store.searchError = this.error; }
    if (this.term !== undefined) next.query = this.term;
    next.results.forEach((row: PinmonySearchResult): void => {
      if (row.kind === 'user' && row.userId) {
        row.followBusy = this.userFollow.busy(row.userId);
        row.canFollow = typeof row.following === 'boolean' && /^\d{1,40}$/.test(this.viewer) && row.userId !== this.viewer &&
          !row.blocked && !this.userFollow.locked(row.userId) && !this.userFollow.pending();
        return;
      }
      if (row.kind !== 'board' || !row.boardId) return;
      row.followBusy = this.boardFollow.busy(row.boardId);
      row.canFollow = typeof row.following === 'boolean' && /^\d{1,40}$/.test(this.viewer) &&
        !!this.ports.profile?.() && !this.boardFollow.locked(row.boardId) && !this.boardFollow.pending();
    });
    next.quiz = this.auxiliary.snapshot();
    next.placeholder = this.hint || next.placeholder; next.suggestions = this.suggestions.slice(); next.suggestionBusy = this.suggestionBusy; next.suggestionError = this.suggestionError;
    this.store.searchNativeInputReady = true; this.store.searchNativeReadsReady = !!feed; this.store.search = next;
    if (feed && !this.busy && !this.error) { feed.scroll = this.store.searchScrollOffset; this.store.searchCache.put(next, feed.scroll); }
  }
  async demand(): Promise<void> {
    if (!this.bind()) return; this.apply();
    if (!this.hintReady) { this.hintReady = true; this.readHint(); }
    if (this.query(this.page) && !this.feeds.has(this.page) && !this.busy) await this.read(false);
    this.auxiliary.demand();
  }
  async refresh(): Promise<void> { if (this.bind() && this.query(this.page) && !this.busy && !this.boardFollow.pending() && !this.userFollow.pending()) await this.read(false); }
  async more(): Promise<void> { if (!this.bind() || this.busy) return; const feed: ReadFeed | undefined = this.feeds.get(this.page); if (feed?.snapshot.apiEnded && !this.error) return; await this.read(!!feed?.cursor && feed.cursor !== '-end-'); }
  navigate(target: string): boolean {
    if (!this.bind() || !this.supported(target) || !this.query(target)) { this.store.searchError = PinmonyI18n.message('当前筛选参数的原生契约尚未确认'); return false; }
    const previous: ReadFeed | undefined = this.feeds.get(this.page); const cached: number | undefined = this.store.searchCache.get(this.page)?.scrollOffset; if(previous && cached !== undefined) previous.scroll = cached;
    this.pause(false); this.ports.navigate(target); this.page = target; this.term = undefined; this.suggestions = []; this.error = '';
    const feed: ReadFeed | undefined = this.feeds.get(target); this.store.searchScrollOffset = feed?.scroll || 0;
    this.store.search = feed ? JSON.parse(JSON.stringify(feed.snapshot)) as PinmonySearchSnapshot : undefined;
    this.demand(); return true;
  }
  private image(value: string | undefined): string { return typeof value === 'string' && /^https:\/\/i\.pinimg\.com\//i.test(value) && value.length <= 2000 ? value : ''; }
  private target(value: string | undefined): string { if (typeof value !== 'string' || value.length > 2048 || /[\s\\#]/.test(value)) return ''; const target: string = value.startsWith('/') && !value.startsWith('//') ? this.origin + value : value; return target.startsWith(this.origin + '/') ? target : ''; }
  private boardImages(item: Item): string[] {
    const result: string[] = [];
    const images: (ImageData | string)[] = item.images?.['236x'] as Object as (ImageData | string)[];
    if (Array.isArray(images)) images.slice(0, 10).forEach((candidate: ImageData | string): void => {
      const url: string = this.image(typeof candidate === 'string' ? candidate : candidate?.url);
      if (url && !result.includes(url)) result.push(url);
    });
    if (Array.isArray(item.pin_thumbnail_urls)) item.pin_thumbnail_urls.slice(0, 10).forEach((candidate: string): void => {
      const url: string = this.image(candidate); if (url && !result.includes(url)) result.push(url);
    });
    return result.slice(0, 3);
  }
  private boardCounts(item: Item): string {
    const parts: string[] = [];
    if (typeof item.pin_count === 'number' && Number.isSafeInteger(item.pin_count) && item.pin_count >= 0) {
      parts.push(item.pin_count.toLocaleString('en-US') + ' 张 Pin 图');
    }
    if (typeof item.section_count === 'number' && Number.isSafeInteger(item.section_count) && item.section_count > 0) {
      parts.push(item.section_count.toLocaleString('en-US') + ' 个图板区块');
    }
    return parts.join(' · ');
  }
  private updated(value: string | undefined): string {
    const elapsed: number = Date.now() - Date.parse(value || '');
    if (!Number.isFinite(elapsed) || elapsed < 0) return '';
    const days: number = Math.floor(elapsed / 86400000);
    if (days >= 7) return Math.floor(days / 7).toString() + ' 周';
    if (days >= 1) return days.toString() + ' 天';
    if (elapsed >= 3600000) return Math.floor(elapsed / 3600000).toString() + ' 小时';
    return Math.max(1, Math.floor(elapsed / 60000)).toString() + ' 分钟';
  }
  private boardCover(item: Item): string {
    const images: (ImageData | string)[] = item.images?.['236x'] as Object as (ImageData | string)[];
    if (Array.isArray(images)) {
      for (const candidate of images.slice(0, 10)) {
        const url: string = this.image(typeof candidate === 'string' ? candidate : candidate?.url);
        if (url) return url;
      }
    }
    const cover: string = this.image(item.image_cover_hd_url) || this.image(item.image_cover_url);
    if (cover) return cover;
    if (Array.isArray(item.pin_thumbnail_urls)) {
      for (const candidate of item.pin_thumbnail_urls.slice(0, 10)) {
        const url: string = this.image(candidate);
        if (url) return url;
      }
    }
    return '';
  }
  private map(item: Item): PinmonySearchResult | undefined {
    if (!item || !item.id) return undefined;
    if (item.type === 'pin' && (item.is_promoted === true || item.ad_data || item.pin_promotion_id)) return undefined;
    let cover: ImageData | undefined = undefined; const sizes: Record<string, ImageData> = item.images || {};
    for (const size of ['474x', '736x', '564x', 'orig', '236x']) { const value: ImageData | undefined = sizes[size]; if (value && this.image(value.url) && Number.isFinite(value.width) && value.width > 0 && Number.isFinite(value.height) && value.height > 0) { cover = value; break; } }
    if (item.type === 'board' || item.type === 'user') {
      const target: string = this.target(item.type === 'board' ? item.url : '/' + item.username + '/'); const label: string = item.name || item.full_name || item.username || '';
      const image: string = item.type === 'user' ? this.image(item.image_large_url || item.image_medium_url) : this.boardCover(item) || cover?.url || '';
      if (!target || !label.trim()) return undefined;
      return { boardImages: item.type === 'board' ? this.boardImages(item) : undefined, ownerName: item.type === 'board' ? (item.owner?.full_name || item.owner?.username || '').slice(0, 180) : undefined, updated: item.type === 'board' ? this.updated(item.board_order_modified_at) : undefined, boardId: item.type === 'board' && /^\d{1,40}$/.test(item.id) ? item.id : undefined, userId: item.type === 'user' && /^\d{1,40}$/.test(item.id) ? item.id : undefined, blocked: item.type === 'user' ? item.blocked_by_me === true : undefined, followerCount: item.type === 'user' && typeof item.follower_count === 'number' && Number.isSafeInteger(item.follower_count) && item.follower_count >= 0 ? item.follower_count : undefined, following: item.type === 'board' && typeof item.followed_by_me === 'boolean' ? item.followed_by_me : item.type === 'user' && typeof item.explicitly_followed_by_me === 'boolean' ? item.explicitly_followed_by_me : undefined, id: 'api-' + item.type + '-' + item.id, kind: item.type, title: label.slice(0,180), subtitle: item.type === 'user' ? item.username || '' : this.boardCounts(item), targetUrl: target, imageUrl: image, imageWidth: 236, imageHeight: 236, enabled: true };
    }
    if (item.type !== 'pin' || !/^\d+$/.test(String(item.id)) || !cover) return undefined;
    const list: Record<string, VideoData> = item.videos?.video_list || {}; const sources: PinmonyVideoSource[] = [];
    for (const key of ['V_HLSV4', 'V_720P']) { const source: VideoData | undefined = list[key]; const kind: string = key === 'V_HLSV4' ? 'hls' : 'mp4'; if (source && source.url.length <= 2000 && /^https:\/\/(?:[A-Za-z0-9-]+\.)*pinimg\.com\/videos\/[^?#]+(?:\.mp4|\.m3u8)(?:\?[^#]*)?$/.test(source.url) && (kind === 'hls' ? /\.m3u8(?:\?|$)/ : /\.mp4(?:\?|$)/).test(source.url)) sources.push({ url: source.url, kind: kind }); }
    const info: VideoData | undefined = list.V_HLSV4 || list.V_720P; const video: PinmonyVideo | undefined = sources.length && info ? { pinId: String(item.id), sources: sources, width: info.width || 0, height: info.height || 0, duration: Math.max(0, Math.min(86400000, info.duration || 0)) } : undefined;
    const offer: SearchOffer | undefined = item.rich_summary?.products?.[0]?.offer_summary;
    return { merchant: item.rich_summary?.site_name?.slice(0, 180), price: typeof offer?.price === 'string' ? offer.price.slice(0, 80) : undefined, standardPrice: typeof offer?.standard_price === 'string' ? offer.standard_price.slice(0, 80) : undefined, id: 'api-pin-' + item.id, kind: 'pin', title: (item.grid_title || item.title || item.description || '').trim().slice(0,180), subtitle: '', targetUrl: /^\d+$/.test(String(item.id)) ? this.origin + '/pin/' + item.id + '/' : '', imageUrl: cover.url, imageWidth: cover.width, imageHeight: cover.height, enabled: /^\d+$/.test(String(item.id)), video: video };
  }
  private async request(endpoint: string, data: Object, post: boolean, live: () => boolean): Promise<PinmonyNetworkReply> {
    const id: string = 'native_search_read_' + (++this.sequence).toString(); this.requests.add(id);
    const fields: string = 'source_url=' + encodeURIComponent(this.page.slice(this.origin.length)) + '&data=' + encodeURIComponent(JSON.stringify(data));
    const job: PinmonyNetworkJob = { id: id, epoch: this.generation, page: this.page, url: this.origin + '/resource/' + endpoint + '/get/' + (post ? '' : '?' + fields), method: post ? 'POST' : 'GET', body: post ? fields : '', headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } };
    if (post) job.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    if (endpoint === 'AdvancedTypeaheadResource') this.suggestionId = id;
    if(endpoint === 'ApiResource' && post) this.filterId = id;
    try { return await this.ports.network().requestBusinessSearchRead(job, (): PinmonyBusinessSessionContext => this.ports.session(), live); } finally { this.requests.delete(id); if (this.suggestionId === id) this.suggestionId = ''; if(this.filterId === id) this.filterId = ''; }
  }
  private async read(append: boolean): Promise<void> {
    const revision: number = this.revision; const page: string = this.page; const live = (): boolean => revision === this.revision && this.owned() && page === this.page;
    if (!this.supported(page)) { this.error = PinmonyI18n.message('当前筛选参数的原生契约尚未确认'); this.apply(); return; }
    const feed: ReadFeed | undefined = this.feeds.get(page); const cursor: string = append ? feed?.cursor || '' : '';
    this.busy = true; this.error = ''; this.apply();
    const options: SearchReadOptions = { query: this.query(page), scope: page.slice(this.origin.length).split('?')[0].split('/')[2] || 'pins', appliedProductFilters: '---', domains: null, user: null, seoDrawerEnabled: false, applied_unified_filters: null, auto_correction_disabled: false, filter_genai: false, journey_depth: null, source_id: this.param(page,'source_id'), source_module_id: null, source_url: page.slice(this.origin.length), static_feed: false, selected_one_bar_modules: null, query_pin_sigs: null, page_size: 25, gated: null, price_max: null, price_min: null, query_image_pins: null, request_params: null, top_pin_ids: this.param(page,'top_pin_ids') || null, article: null, corpus: null, filters: null, rs: this.param(page,'rs') || 'typed' };
    const product: PinmonySearchProductRoute = readNativeSearchProductRoute(page)!;
    options.domains = product.domains; options.price_min = product.priceMin; options.price_max = product.priceMax; options.appliedProductFilters = product.applied;
    if (append) options.bookmarks = [cursor];
    try {
      const reply: PinmonyNetworkReply = await this.request('BaseSearchResource', { options: options, context: {} as Record<string,string> } as ReadEnvelope, true, live);
      if (!live()) return; if (reply.error || reply.status !== 200 || reply.body.length > 6000000) throw new Error('search-request');
      const response: ResponseData = JSON.parse(reply.body) as ResponseData;
      const resource: Resource = response.resource_response;
      if (resource?.status !== 'success' || !Array.isArray(resource.data?.results) || resource.data.results.length > 500) throw new Error('search-response');
      const viewer: string = response.client_context?.user?.id || '';
      this.viewer = /^\d{1,40}$/.test(viewer) ? viewer : '';
      const incoming: PinmonySearchResult[] = []; resource.data.results.forEach((item: Item): void => { const value: PinmonySearchResult | undefined = this.map(item); if (value && !incoming.some((pin: PinmonySearchResult): boolean => pin.id === value.id)) incoming.push(value); });
      incoming.forEach((row: PinmonySearchResult): void => {
        if (row.userId && typeof row.following === 'boolean') this.userFollow.reconcile(row.userId, row.following);
        if (row.boardId && typeof row.following === 'boolean') this.boardFollow.reconcile(row.boardId, row.following);
      });
      if (resource.data.results.length && !incoming.length) throw new Error('unknown-search-items');
      const results: PinmonySearchResult[] = append && feed ? feed.snapshot.results.slice() : []; incoming.forEach((item: PinmonySearchResult): void => { if (!results.some((value: PinmonySearchResult): boolean => value.id === item.id)) results.push(item); });
      const categories: PinmonySearchCategory[] = append && feed ? feed.snapshot.categories.slice() : [];
      if (!append && Array.isArray(resource.data.rankedGuides)) resource.data.rankedGuides.slice(0,40).forEach((guide: Guide): void => { if (!guide?.term?.trim() || guide.term.length > 300 || !guide.display?.trim() || categories.some((c: PinmonySearchCategory): boolean => c.id === 'api-guide-' + guide.term)) return; categories.push({ id: 'api-guide-' + guide.term, label: guide.display.slice(0,100), selected: false, enabled: true, targetUrl: this.origin + '/search/pins/?q=' + encodeURIComponent(guide.term), imageUrl: this.image(guide.image_medium_url), backgroundColor: /^#[0-9a-f]{6}$/i.test(guide.dominant_color || '') ? guide.dominant_color : '' }); });
      const next: string = typeof resource.bookmark === 'string' && resource.bookmark.length <= 4096 ? resource.bookmark : '';
      const snapshot: PinmonySearchSnapshot = { kind: 'state', session: 0, pageKey: page, query: this.query(page), placeholder: this.hint, selectedCategory: '', categories: categories, suggestions: [], heroes: [], ideaSections: [], results: results, api: true, apiActive: true, apiBusy: false, apiError: '', apiEnded: !next || next === '-end-' || next === cursor || !resource.data.results.length };
      const value: ReadFeed = { product: resource.data.productFilters, snapshot: snapshot, cursor: next, filters: [], targets: new Map<string,string>(), modules: Array.isArray(resource.data.oneBarModules), filterCursor: next && next !== '-end-' ? next : feed?.filterCursor || '', scroll: this.store.searchScrollOffset };
      this.mapModules(resource.data.oneBarModules || [], value); this.feeds.set(page,value); if (this.feeds.size > 12) { const oldest: string | undefined = this.feeds.keys().next().value; if (oldest && oldest !== page) this.feeds.delete(oldest); }
      this.store.searchResultsResetPending = false; PinmonyRuntimeLog.info('SearchNativeTrace: results committed append=' + append.toString() + ' count=' + results.length.toString());
    } catch (_) { if (live()) this.error = append ? '更多搜索结果读取失败，请重试' : PinmonyI18n.message('搜索结果读取失败，请重试'); }
    finally { if (revision === this.revision && page === this.page) { this.busy = false; if (live()) this.apply(); this.ports.settled(); } }
  }
  async input(term: string, immediate: boolean = false): Promise<void> {
    if (typeof term !== 'string' || term.length > 300 || !this.bind()) return;
    const version: number = ++this.suggestionRevision; const revision: number = this.revision;
    if (this.suggestionId) this.ports.network().cancel(this.suggestionId); if (this.suggestionTimer >= 0) clearTimeout(this.suggestionTimer);
    this.term = term; this.suggestions = []; this.suggestionError = ''; this.suggestionBusy = true; this.apply();
    const live = (): boolean => this.owned() && revision === this.revision && version === this.suggestionRevision && term === this.term;
    const load = async (): Promise<void> => {
      this.suggestionTimer = -1; if (!live()) return;
      try {
        const options: SuggestionOptions = { field_set_key: 'richResults', limit: 8, num_recent_queries: 20, personal_search_only: false, pin_scope: 'pins', recent_queries_tags: 'recent_queries,recent_personal_searches', term: term, autocomplete_request_surface: 0 };
        const reply: PinmonyNetworkReply = await this.request('AdvancedTypeaheadResource',{options:options,context:{} as Record<string,string>} as ReadEnvelope,false,live);
        if (!live()) return; if (reply.error || reply.status !== 200 || reply.body.length > 2000000) throw new Error('suggestion-request');
        const resource: Resource = (JSON.parse(reply.body) as ResponseData).resource_response; if (resource?.status !== 'success' || !Array.isArray(resource.data?.items)) throw new Error('suggestion-response');
        const values: PinmonySearchSuggestion[] = []; resource.data.items.slice(0,40).forEach((item: Suggestion,index: number): void => { const label: string = item?.display_query || item?.query || item?.label || ''; if (!label.trim() || label.length > 300 || values.some((v: PinmonySearchSuggestion): boolean => v.label === label.trim())) return; values.push({ id: 'native-suggestion-' + version.toString() + '-' + index.toString(), label: label.trim(), query: typeof item.query === 'string' && item.query.length <= 300 ? item.query : '', enabled: true, historyType: item.type || '', deletable: term === '' && item.type === 'recent_query' && item.vertical === 'pins' && typeof item.query === 'string' && !!item.query.trim() && !this.auxiliary.historyLocked(item.query) }); }); this.suggestions = values;
      } catch (_) { if (live()) this.suggestionError = PinmonyI18n.message('搜索建议读取失败，请重试'); }
      finally { if (live()) { this.suggestionBusy = false; this.apply(); } }
    };
    if (immediate || !term) await load(); else this.suggestionTimer = setTimeout((): void => { load(); },250);
  }
  private async readHint(): Promise<void> {
    const revision: number = this.revision; const live = (): boolean => revision === this.revision && this.owned();
    try { const reply: PinmonyNetworkReply = await this.request('ApiResource',{options:{url:'/v3/search/ghost_queries/',data:{} as ApiReadData},context:{} as Record<string,string>} as ApiReadEnvelope,false,live); if (!live() || reply.error || reply.status !== 200 || reply.body.length > 1000000) return; const resource: HintResource = (JSON.parse(reply.body) as HintResponse).resource_response; if(resource?.status === 'success' && Array.isArray(resource.data)) { const hint: HintItem | undefined = resource.data.find((item: HintItem): boolean => typeof item?.text === 'string' && !!item.text.trim()); this.hint = hint?.text?.trim().slice(0,180) || ''; this.apply(); } } catch (_) {} finally { if (!live()) this.hintReady = false; }
  }
  private filterLabel(scope: string, original: string): string {
    // Only the supported fixed content types follow the app language.
    const names: Record<string, string> = { 'pins': '所有 Pin 图', 'videos': '视频', 'boards': '图板', 'users': '用户', 'buyable_pins': '商品' };
    return names[scope] ? PinmonyI18n.message(names[scope]) : original;
  }
  private mapModules(modules: FilterModule[], feed: ReadFeed): void {
    modules.slice(0,20).forEach((module: FilterModule): void => { const action: FilterAction | undefined = module?.action; if(action?.type !== 'contenttypefiltermoduleaction' || !Array.isArray(action.filters)) return;
      action.filters.slice(0,50).forEach((item: FilterItem): void => { const label: string = item?.display?.display_text?.trim() || ''; if(item?.type !== 'filteroption' || !label) return; const target: string = this.target(item.action?.type === 'onebarmoduleaction' ? item.action.feed_url : ''); const id: string = 'native-filter-' + feed.filters.length.toString(); const enabled: boolean = !!target && this.supported(target) && this.query(target) === this.query(feed.snapshot.pageKey) && !item.disabled && !item.is_disabled; feed.filters.push({id:id,label:this.filterLabel(target.slice(this.origin.length).match(/^\/search\/(pins|videos|boards|users|buyable_pins)\//)?.[1] || '', label.slice(0,70)),group:action.title?.slice(0,70) || '',selected:item.is_selected === true,enabled:enabled}); if(enabled)feed.targets.set(id,target); }); });
  }
  async filters(): Promise<void> {
    if (!this.bind()) return; const page: string = this.page; const feed: ReadFeed | undefined = this.feeds.get(page); const token: number = ++this.filterRevision; const panel: number = this.store.searchFilterToken; const revision: number = this.revision;
    const live = (): boolean => this.owned() && page === this.page && token === this.filterRevision && panel === this.store.searchFilterToken && revision === this.revision;
    if (!feed) { this.store.searchFilterLoading = false; this.store.searchFilterError = PinmonyI18n.message('请等待搜索结果读取完成后重试'); return; }
    this.store.searchProductDomains = [];this.store.searchProductCurrency = '';this.store.searchProductPrices = false;this.store.searchProductError = '';
    this.store.searchProductMin = this.param(page,'price_min');this.store.searchProductMax = this.param(page,'price_max');
    if(page.startsWith(this.origin + '/search/buyable_pins/')) {
      const chosen: string[] = this.param(page,'domains').split(',');
      (feed.product?.domainFilters || []).slice(0,50).forEach((domain: ProductDomain): void => {
        if(domain && typeof domain.domain === 'string' && /^[a-z0-9.-]+\.[a-z]{2,63}$/.test(domain.domain) && typeof domain.label === 'string')
          this.store.searchProductDomains.push({id:domain.domain,label:domain.label.slice(0,100),selected:chosen.includes(domain.domain),enabled:true,group:PinmonyI18n.message('商家')});
      });
      const prices: ProductPrices | undefined = feed.product?.priceFilters;
      if(prices && /^[A-Z]{3}$/.test(prices.currency_type) && Number.isFinite(prices.min_value) && Number.isFinite(prices.max_value) && prices.min_value >= 0 && prices.max_value >= prices.min_value) {
        this.store.searchProductCurrency = prices.currency_type;this.store.searchProductPrices = true;
        this.store.searchProductLower = Math.ceil(prices.min_value);
        this.store.searchProductUpper = Math.floor(prices.max_value);
      }
    }
    this.store.searchFilterLoading = true; this.store.searchFilterError = '';
    try {
      if (!feed.modules && !feed.filters.length) {
        if (!feed.filterCursor) throw new Error('missing-filter-cursor');
        const reply: PinmonyNetworkReply = await this.request('ApiResource',{options:{url:'/v3/filters/',data:{bookmark_string:feed.filterCursor}},context:{} as Record<string,string>} as ApiReadEnvelope,true,live);
        if(!live())return; if(reply.error || reply.status !== 200 || reply.body.length > 2000000)throw new Error('filters-request');
        const resource: ArrayResource = (JSON.parse(reply.body) as ArrayResponse).resource_response; if(resource?.status !== 'success' || !Array.isArray(resource.data))throw new Error('filters-response');
        const options: PinmonySearchFilterOption[] = []; const targets: Map<string,string> = new Map<string,string>();
        const labels: Record<string,string> = {'所有 Pin 图':'pins','所有创意':'pins','All Pins':'pins','视频':'videos','Videos':'videos','画板':'boards','图板':'boards','Boards':'boards','个人资料':'users','用户':'users','Profiles':'users','商品':'buyable_pins','产品':'buyable_pins','Products':'buyable_pins'};
        resource.data.slice(0,20).forEach((filter: FilterItem): void => { if(filter?.type !== 'filter' || !Array.isArray(filter.filter_options))return; filter.filter_options.slice(0,50).forEach((item: FilterItem): void => { if(item?.type !== 'filteroption' || !item.label?.trim())return; const scope: string = ['pins','videos','boards','users','buyable_pins'].includes(item.id || '') ? item.id || '' : labels[item.label] || ''; const id: string = 'native-filter-' + options.length.toString(); options.push({id:id,label:this.filterLabel(scope, item.label.trim().slice(0,70)),group:filter.title?.slice(0,70) || '',selected:item.is_selected === true,enabled:!!scope && !item.disabled && !item.is_disabled}); if(scope)targets.set(id,this.origin+'/search/'+scope+'/?q='+encodeURIComponent(this.query(page))+'&rs=content_type_filter'); }); });
        if(resource.data.length && !options.length)throw new Error('unknown-filters'); feed.filters = options; feed.targets = targets;
      }
      if(live()) { this.store.searchFilterOptions = feed.filters.slice(); if(!feed.filters.length && !this.store.searchProductPrices && !this.store.searchProductDomains.length)this.store.searchFilterError = PinmonyI18n.message('当前搜索没有可用的筛选选项'); }
    } catch (_) { if(live())this.store.searchFilterError = PinmonyI18n.message('筛选选项读取失败，请重试'); }
    finally { if(live())this.store.searchFilterLoading = false; }
  }
  filterTarget(id: string): string {
    const feed: ReadFeed | undefined = this.feeds.get(this.page);
    if(id.startsWith('native-product:')) {
      if(!this.owned() || !feed?.product || !this.page.startsWith(this.origin + '/search/buyable_pins/'))return '';
      try {
        if(id.length > 5000)throw new Error('input');
        const input: ProductDraft = JSON.parse(id.slice('native-product:'.length)) as ProductDraft;
        if(!Array.isArray(input.domains) || input.domains.length > 10 || !input.domains.every((domain: string): boolean =>
            typeof domain === 'string' && !!feed.product?.domainFilters?.some((known: ProductDomain): boolean => known.domain === domain)) ||
            typeof input.min !== 'string' || typeof input.max !== 'string' || ((input.min || input.max) && !this.store.searchProductPrices))throw new Error('input');
        let target: string = this.origin + '/search/buyable_pins/?q=' + encodeURIComponent(this.query(this.page)) + '&rs=shopping_filter';
        if(input.domains.length)target += '&domains=' + encodeURIComponent(Array.from(new Set(input.domains)).join(','));
        if(input.min)target += '&price_min=' + encodeURIComponent(input.min);
        if(input.max)target += '&price_max=' + encodeURIComponent(input.max);
        if(!this.supported(target))throw new Error('range');
        this.store.searchProductError = '';return target;
      } catch (_) {this.store.searchProductError = PinmonyI18n.message('请输入有效的整数价格范围，最低价不能高于最高价');return '';}
    }
    return this.owned() && feed?.filters.some((item: PinmonySearchFilterOption): boolean => item.id === id && item.enabled && !item.selected) ? feed.targets.get(id) || '' : '';
  }
}
