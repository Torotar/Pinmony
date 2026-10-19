import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore, PinmonyDetailSnapshot, PinmonyVideo, PinmonyVideoSource, PinmonyCarousel, PinmonyCarouselItem,
  PinmonyImageCrop, PinmonyVisualResult, PinmonyRelatedPin, PIN_VIDEO_API_ENABLED, PIN_CAROUSEL_API_ENABLED, PIN_VISUAL_SEARCH_API_ENABLED } from 'feature_pin';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
export const PIN_NATIVE_DETAIL_AUXILIARY_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface Art { url: string; width: number; height: number; duration?: number; }
interface VideoList { V_HLSV4?: Art; V_720P?: Art; vHLSV4?: Art; v720P?: Art; }
interface Videos { video_list?: VideoList; videoList?: VideoList; }
interface Slot { id?: string; slot_id?: string; slotId?: string; title?: string; images?: Record<string,Art>; images_1200x?: Art; images_736x?: Art; images_474x?: Art; images_564x?: Art; images_orig?: Art; images_236x?: Art; }
interface Carousel { carousel_slots?: Slot[]; carouselSlots?: Slot[]; }
interface NativePin { id?: string; entityId?: string; type?: string; is_video?: boolean; videos?: Videos; carousel_data?: Carousel; carouselData?: Carousel; images?: Record<string,Art>; grid_title?: string; title?: string; }
interface Resource { status: string; code?: number; error?: Object; endpoint_name?: string; data: NativePin; bookmark?: string; }
interface PinResponse { resource_response: Resource; }
interface GraphPin { data?: NativePin; }
interface GraphData { v3GetPinQueryv2?: GraphPin; }
interface GraphResponse { errors?: Object; data?: GraphData; }
interface VisualData { results: NativePin[]; }
interface VisualResource { status: string; code: number; error?: Object; endpoint_name: string; data: VisualData; bookmark?: string; }
interface VisualResponse { resource_response: VisualResource; }
interface ReadOptions { id?: string; field_set_key?: string; noCache?: boolean; fetch_visual_search_objects?: boolean; get_page_metadata?: boolean; add_fields?: string;
  pin_id?: string; crop?: PinmonyImageCrop; crop_source?: number; is_shopping?: boolean; entry_source?: string; entrypoint?: string; bookmarks?: string[]; }
interface Envelope { options: ReadOptions; context: Record<string,string>; }
interface Variables { pinId: string; isAuth: boolean; isDesktop: boolean; isAuthDesktop: boolean; isUnauth: boolean; shouldPrefetchStoryPinFragment: boolean; shouldSkipImageViewerOnPageQuery: boolean; }
interface Query { queryHash: string; variables: Variables; }
export interface PinmonyDetailNativeAuxiliaryPorts {
  store: () => PinmonyPinStore; session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  owned: () => boolean;
}
export class PinmonyDetailNativeAuxiliary {
  private readonly ports: PinmonyDetailNativeAuxiliaryPorts;
  private readonly store: PinmonyPinStore;
  private revision: number = 0;
  private visualRevision: number = 0;
  private sequence: number = 0;
  private pin: string = '';
  private token: number = 0;
  private account: string = '';
  private mediaKind: string = '';
  private mediaLoading: boolean = false;
  private mediaError: string = '';
  private video: PinmonyVideo | undefined = undefined;
  private carousel: PinmonyCarousel | undefined = undefined;
  private original: string = '';
  private mediaVersion: number = 0;
  private bookmark: string = '';
  private crop: string = '';
  private readonly requests: Set<string> = new Set<string>();
  private readonly waits: Map<string,() => void> = new Map<string,() => void>();
  constructor(ports: PinmonyDetailNativeAuxiliaryPorts) { this.ports = ports; this.store = ports.store(); }
  private key(): string { const s: PinmonyBusinessSessionContext = this.ports.session(); return s.authenticated ? s.origin + ':' + s.accountId + ':' + s.generation.toString() : ''; }
  ready(): boolean { return PIN_NATIVE_DETAIL_AUXILIARY_ENABLED && !!this.pin && this.account === this.key() && this.token === this.store.detailOpeningToken && this.store.detailPin === this.pin && this.ports.owned(); }
  private cancel(prefix: string): void {
    this.requests.forEach((id: string): void => { if (id.startsWith(prefix)) { this.ports.network().cancel(id); this.waits.get(id)?.(); } });
  }
  pause(): void {
    this.revision++; this.cancelVisual(); this.cancel('native_detail_aux_');
    if (this.mediaLoading && this.store.detail?.pinUrl === this.pin) { this.mediaLoading = false; this.mediaError = PinmonyI18n.message("pm_media_loading_paused_please_retry_67a4be3d"); this.applyMedia(); }
    this.pin = ''; this.account = ''; this.store.detailMediaRetryBusy = false;
  }
  cancelVisual(): void {
    this.visualRevision++; this.cancel('native_detail_aux_visual_');
    if (this.store.visualResult.loading) this.store.visualResult = {pin:this.store.visualResult.pin,loading:false,error:PinmonyI18n.message("pm_image_search_paused_please_retry_c19326c2"),ended:this.store.visualResult.ended,items:this.store.visualResult.items};
  }
  start(pin: string, token: number, body: string): void {
    this.pause();
    if (!PIN_NATIVE_DETAIL_AUXILIARY_ENABLED || !this.ports.owned()) return;
    try {
      const r: Resource = (JSON.parse(body) as PinResponse).resource_response;
      if (!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 || r.data?.id !== pin.match(/\/pin\/(\d+)\/$/)?.[1]) return;
      this.pin = pin; this.token = token; this.account = this.key(); this.video = undefined; this.carousel = undefined;
      this.mediaVersion = 0; this.original = this.image(r.data.images?.orig?.url || r.data.images?.['736x']?.url || r.data.images?.['474x']?.url || ''); this.mediaError = '';
      this.mediaKind = r.data.carousel_data?.carousel_slots?.length ? 'carousel' : r.data.is_video === true || !!r.data.videos ? 'video' : '';
      this.resolve(r.data,false,false);
    } catch (_) {}
  }
  apply(): void { if (this.ready()) this.applyMedia(); }
  private applyMedia(): void {
    const detail: PinmonyDetailSnapshot | undefined = this.store.detail;
    if (!detail || detail.pinUrl !== this.pin) return;
    const next: PinmonyDetailSnapshot = JSON.parse(JSON.stringify(detail)) as PinmonyDetailSnapshot;
    next.mediaKind = this.mediaKind; next.mediaLoading = this.mediaLoading;
    next.mediaError = this.mediaKind === 'video' ? '' : this.mediaError; next.videoError = this.mediaKind === 'video' ? this.mediaError : '';
    next.video = this.video; next.carousel = this.carousel; next.isVideo = this.mediaKind === 'video';
    if (this.original) next.originalImageUrl = this.original;
    this.store.detail = next;
  }
  async openLayer(layer: string): Promise<void> {
    if (!this.ready() || !['search','zoom'].includes(layer) || layer === 'search' && (!PIN_VISUAL_SEARCH_API_ENABLED || this.mediaKind === 'video')) return;
    this.cancelVisual(); this.bookmark = ''; this.crop = '';
    this.store.imageLayer = layer; this.store.visualResult = {pin:this.pin,loading:false,error:'',ended:false,items:[]};
  }
  downloadUrl(): string {
    if (!this.ready() || this.store.imageLayer !== 'zoom') return '';
    return /^https:\/\/i\.pinimg\.com\//.test(this.original) ? this.original : '';
  }
  private image(value: string): string { return typeof value === 'string' && value.length <= 4096 && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/[^\s#]+$/i.test(value) ? value : ''; }
  private videoMap(p: NativePin, graph: boolean): PinmonyVideo | undefined {
    if ((graph ? p.entityId : p.id) !== this.pin.match(/\/pin\/(\d+)\/$/)?.[1]) return undefined;
    const list: VideoList | undefined = graph ? p.videos?.videoList : p.videos?.video_list;
    const hls: Art | undefined = graph ? list?.vHLSV4 : list?.V_HLSV4, mp4: Art | undefined = graph ? list?.v720P : list?.V_720P;
    const sources: PinmonyVideoSource[] = [];
    const valid = (v: Art | undefined, kind: string): boolean => !!v && !!this.image(v.url) && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/videos\/[^\s?#]+\.(?:m3u8|mp4)(?:\?[^\s#]*)?$/i.test(v.url) &&
      (kind === 'hls' ? /\.m3u8(?:\?|$)/i : /\.mp4(?:\?|$)/i).test(v.url);
    if (valid(hls,'hls')) sources.push({url:hls!.url,kind:'hls'});
    if (valid(mp4,'mp4')) sources.push({url:mp4!.url,kind:'mp4'});
    const primary: Art | undefined = sources[0]?.kind === 'hls' ? hls : mp4;
    const positive = (v: number | undefined): number => typeof v === 'number' && Number.isFinite(v) && v > 0 ? v : 0;
    return sources.length && primary ? {pinId:this.pin.match(/\/pin\/(\d+)\/$/)![1],sources:sources,width:positive(primary.width),height:positive(primary.height),duration:positive(primary.duration),readRevision:this.mediaVersion} : undefined;
  }
  private carouselMap(p: NativePin, graph: boolean): PinmonyCarousel | undefined {
    if ((graph ? p.entityId : p.id) !== this.pin.match(/\/pin\/(\d+)\/$/)?.[1]) return undefined;
    const slots: Slot[] | undefined = graph ? p.carouselData?.carouselSlots : p.carousel_data?.carousel_slots;
    if (!Array.isArray(slots) || !slots.length || slots.length > 100) return undefined;
    const items: PinmonyCarouselItem[] = [];
    for (const slot of slots) {
      if (!slot) return undefined;
      let sizes: Record<string,Art> = slot.images || {};
      if(graph) {
        sizes = {};
        if(slot.images_1200x)sizes['1200x'] = slot.images_1200x;
        if(slot.images_736x)sizes['736x'] = slot.images_736x;
        if(slot.images_474x)sizes['474x'] = slot.images_474x;
        if(slot.images_564x)sizes['564x'] = slot.images_564x;
        if(slot.images_orig)sizes['orig'] = slot.images_orig;
        if(slot.images_236x)sizes['236x'] = slot.images_236x;
      }
      const art: Art | undefined = ['1200x','736x','474x','564x','orig','236x'].map((key: string): Art => sizes[key]).find((v: Art): boolean => !!v && !!this.image(v.url) && Number.isFinite(v.width) && v.width > 0 && Number.isFinite(v.height) && v.height > 0);
      const id: string = graph ? slot.slotId || '' : slot.id || slot.slot_id || '';
      if (!art || typeof id !== 'string' || !id || id.length > 200 || items.some((v: PinmonyCarouselItem): boolean => v.id === id)) return undefined;
      items.push({id:id,imageUrl:art.url,imageWidth:art.width,imageHeight:art.height,title:typeof slot.title === 'string' ? slot.title.slice(0,500) : ''});
    }
    return {pinId:this.pin.match(/\/pin\/(\d+)\/$/)![1],items:items};
  }
  async retryMedia(): Promise<void> {
    if (!this.ready() || !this.mediaKind || this.mediaLoading || this.store.detailMediaRetryBusy) return;
    this.store.detailMediaRetryBusy = true;
    const revision: number = this.revision;
    try {
      const r: PinResponse = JSON.parse(await this.request('pin',{},this.pin.slice(this.ports.session().origin.length),(): boolean => revision === this.revision && this.ready())) as PinResponse;
      if (!this.ready() || revision !== this.revision) return;
      if (r.resource_response?.status !== 'success' || r.resource_response.error || r.resource_response.code !== undefined && r.resource_response.code !== 0 || r.resource_response.data?.id !== this.pin.match(/\/pin\/(\d+)\/$/)?.[1]) throw new Error('pin');
      await this.resolve(r.resource_response.data,false,true);
    } catch (_) { if (revision === this.revision && this.ready()) { this.mediaError = PinmonyI18n.message("pm_unable_to_load_media_url_please_retry_e2d8f3d2"); this.apply(); } }
    finally { if (revision === this.revision) this.store.detailMediaRetryBusy = false; }
  }
  private async resolve(raw: NativePin, graph: boolean, refresh: boolean): Promise<void> {
    if (!this.ready() || !this.mediaKind) { this.apply(); return; }
    if (this.mediaKind === 'video' && !PIN_VIDEO_API_ENABLED || this.mediaKind === 'carousel' && !PIN_CAROUSEL_API_ENABLED) return;
    const revision: number = this.revision;
    this.mediaLoading = true; this.mediaError = ''; this.apply();
    try {
      let video: PinmonyVideo | undefined = this.mediaKind === 'video' ? this.videoMap(raw,graph) : undefined;
      let carousel: PinmonyCarousel | undefined = this.mediaKind === 'carousel' ? this.carouselMap(raw,graph) : undefined;
      if (!video && !carousel) {
        const response: GraphResponse = JSON.parse(await this.request('graph',{},this.pin.slice(this.ports.session().origin.length),(): boolean => revision === this.revision && this.ready())) as GraphResponse;
        if (response.errors || !response.data?.v3GetPinQueryv2?.data) throw new Error('graph');
        const p: NativePin = response.data.v3GetPinQueryv2.data;
        video = this.mediaKind === 'video' ? this.videoMap(p,true) : undefined;
        carousel = this.mediaKind === 'carousel' ? this.carouselMap(p,true) : undefined;
      }
      if (!this.ready() || revision !== this.revision) return;
      if (!video && !carousel) throw new Error('missing-media');
      if (refresh) this.mediaVersion = (this.mediaVersion + 1) % 1000000;
      if (video) { video.readRevision = this.mediaVersion; this.video = video; }
      if (carousel) this.carousel = carousel;
    } catch (_) { if (this.ready() && revision === this.revision) this.mediaError = this.mediaKind === 'video' ? '视频地址读取失败，请重试' : PinmonyI18n.message("pm_unable_to_load_carousel_please_retry_e43842b8"); }
    finally { if (revision === this.revision && this.ready()) { this.mediaLoading = false; this.apply(); } }
  }
  async search(crop: PinmonyImageCrop, append: boolean, first: boolean): Promise<void> {
    if (!this.ready() || !PIN_VISUAL_SEARCH_API_ENABLED || this.store.imageLayer !== 'search' || !crop ||
      ![crop.x,crop.y,crop.w,crop.h].every((v: number): boolean => Number.isFinite(v)) || crop.x < 0 || crop.y < 0 || crop.w < 0.04 || crop.h < 0.04 || crop.x + crop.w > 1.00001 || crop.y + crop.h > 1.00001) return;
    const selected: PinmonyImageCrop = {x:crop.x,y:crop.y,w:crop.w,h:crop.h}, key: string = JSON.stringify(selected);
    if (append && (key !== this.crop || this.store.visualResult.loading || this.store.visualResult.ended || !this.bookmark)) return;
    this.cancelVisual(); this.crop = key; if (!append) this.bookmark = '';
    const revision: number = ++this.visualRevision, pin: string = this.pin, previous: string = append ? this.bookmark : '';
    const live = (): boolean => revision === this.visualRevision && this.ready() && this.pin === pin && this.store.imageLayer === 'search';
    const result: PinmonyVisualResult = {pin:pin,loading:true,error:'',ended:false,items:append ? this.store.visualResult.items.slice() : []};
    this.store.visualResult = result;
    const options: ReadOptions = {pin_id:pin.match(/\/pin\/(\d+)\/$/)![1],crop:selected,crop_source:first ? 5 : 6,is_shopping:false,entry_source:'flashlight',entrypoint:first ? 'closeup_cta' : 'unknown'};
    if (append) options.bookmarks = [previous];
    const source: string = '/pin/' + options.pin_id + '/visual-search/?cropSource=' + options.crop_source!.toString() + '&entrypoint=' + options.entrypoint + '&surfaceType=flashlight';
    try {
      const response: VisualResource = (JSON.parse(await this.request('visual',options,source,live)) as VisualResponse).resource_response;
      if (!live()) return;
      if (response?.status !== 'success' || response.error || response.code !== 0 || response.endpoint_name !== 'v3_unified_flashlight_handler' || !Array.isArray(response.data?.results) || response.data.results.length > 2000) throw new Error('visual');
      response.data.results.forEach((p: NativePin): void => {
        const art: Art | undefined = p?.images?.['736x'] || p?.images?.['474x'] || p?.images?.orig || p?.images?.['236x'];
        if (p?.type !== 'pin' || !/^\d{1,30}$/.test(p.id || '') || !art || !/^https:\/\/i\.pinimg\.com\//.test(this.image(art.url)) ||
            !Number.isFinite(art.width) || art.width <= 0 || !Number.isFinite(art.height) || art.height <= 0 || result.items.length >= 400 || result.items.some((v: PinmonyRelatedPin): boolean => v.id === 'api:' + p.id)) return;
        result.items.push({id:'api:' + p.id,pinUrl:this.ports.session().origin + '/pin/' + p.id + '/',imageUrl:art.url,imageWidth:art.width,imageHeight:art.height,title:typeof (p.grid_title || p.title) === 'string' ? (p.grid_title || p.title)!.slice(0,160) : ''});
      });
      const cursor: string = typeof response.bookmark === 'string' && response.bookmark.length <= 4096 ? response.bookmark : '';
      result.ended = !cursor || cursor === '-end-' || cursor === previous || result.items.length >= 400;
      this.bookmark = cursor;
    } catch (_) { if (live()) result.error = PinmonyI18n.message("pm_image_search_failed_please_retry_a1c501c4"); }
    finally { if (live()) { result.loading = false; this.store.visualResult = {pin:result.pin,loading:result.loading,error:result.error,ended:result.ended,items:result.items.slice()}; } }
  }
  private async request(kind: string, options: ReadOptions, source: string, current: () => boolean): Promise<string> {
    if (!current()) throw new Error('stale');
    const session: PinmonyBusinessSessionContext = this.ports.session(), id: string = this.pin.match(/\/pin\/(\d+)\/$/)![1];
    if (kind === 'pin') options = {id:id,field_set_key:'auth_web_main_pin',noCache:true,fetch_visual_search_objects:false,get_page_metadata:false,add_fields:'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin'};
    const envelope: Envelope = {options:options,context:{}}, form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const graph: boolean = kind === 'graph';
    const query: Query = {queryHash:'c025ad33faccf5d04c2ed38344405d0a6c46dd1d786c17f3954b6980ef798538',variables:{pinId:id,isAuth:true,isDesktop:false,isAuthDesktop:false,isUnauth:false,shouldPrefetchStoryPinFragment:false,shouldSkipImageViewerOnPageQuery:true}};
    const headers: Record<string,string> = {'Accept':'application/json','Content-Type':graph ? 'application/json' : 'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest',
      'X-Pinterest-AppState':'active','X-Pinterest-Source-Url':source,'X-Pinterest-Pws-Handler':kind === 'visual' ? 'www/pin/[id]/visual-search.js' : 'www/pin/[id].js'};
    if (session.appVersion) headers['X-App-Version'] = session.appVersion;
    const job: PinmonyNetworkJob = {id:'native_detail_aux_' + kind + '_' + (++this.sequence).toString(),epoch:session.generation,page:this.pin,headers:headers,
      method:graph ? 'POST' : 'GET',body:graph ? JSON.stringify(query) : '',url:session.origin + (graph ? '/_/graphql/' : '/resource/' + (kind === 'pin' ? 'PinResource' : 'VisualSearchFlashlightUnifiedResource') + '/get/?' + form + '&_=' + Date.now().toString())};
    this.requests.add(job.id);
    let timer: number = -1;
    const cancelled: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => {
      this.waits.set(job.id,(): void => resolve(undefined)); timer = setTimeout((): void => { this.ports.network().cancel(job.id); resolve(undefined); },15000);
    });
    let reply: PinmonyNetworkReply | undefined;
    try { reply = await Promise.race([this.ports.network().requestBusinessDetailAuxiliary(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.pin,current),cancelled]); }
    finally { clearTimeout(timer); this.requests.delete(job.id); this.waits.delete(job.id); }
    if (!current() || !reply || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 6000000) throw new Error('request');
    return reply.body;
  }
}
