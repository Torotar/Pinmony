import { PinmonyI18n } from 'common_foundation';
import { PinmonyHomeStore, PinmonyHomeSnapshot, PinmonyHomePin, PinmonyHomeTab, PinmonyHomeBoard } from 'feature_home';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyVideo, PinmonyVideoSource } from 'common_ui';
import { PinmonyRuntimeLog } from 'common_foundation';

export const PIN_NATIVE_HOME_READS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface HomeImage { url: string; width: number; height: number; }
interface HomeVideo { video_list?: Record<string, HomeVideoSource>; }
interface HomeVideoSource { url: string; width: number; height: number; duration: number; }
interface HomeItem { id: string; type: string; images?: Record<string, HomeImage>; grid_title?: string; title?: string;
  description?: string; videos?: HomeVideo; name?: string; }
interface HomeResource { status: string; code?: number; error?: Object; data: HomeItem[]; bookmark?: string; }
interface HomeResponse { resource_response: HomeResource; }
interface BoardData { id: string; url?: string; name: string; pin_count: number; cover_images?: Record<string, HomeImage>;
  image_cover_url?: string; image_cover_hd_url?: string; }
interface BoardResource { status: string; code?: number; endpoint_name?: string; data: BoardData; }
interface BoardResponse { resource_response: BoardResource; }
interface HomeOptions { field_set_key?: string; in_nux?: boolean; in_news_hub?: boolean; static_feed?: boolean;
  type?: string; id?: string; __track__referrer?: number; bookmarks?: string[]; username?: string;
  filter_stories?: boolean; sort?: string; board_id?: string; is_mobile_fork?: boolean; }
interface HomeEnvelope { options: HomeOptions; context: Record<string, string>; }
interface HomeFeed { snapshot: PinmonyHomeSnapshot; bookmark: string; }
export interface PinmonyHomeNativeReadsPorts {
  store: () => PinmonyHomeStore;
  session: () => PinmonyBusinessSessionContext;
  username: () => string;
  network: () => PinmonyNativeNetwork;
  active: () => boolean;
  committed: (snapshot: PinmonyHomeSnapshot, kind?: 'feed' | 'pagination' | 'cache' | 'metadata') => void;
  saved: (id: string) => boolean;
}

// Owns account-scoped read state. Web documents and write permissions remain separate.
export class PinmonyHomeNativeReads {
  private readonly ports: PinmonyHomeNativeReadsPorts;
  private readonly store: PinmonyHomeStore;
  private revision: number = 0;
  private sequence: number = 0;
  private account: string = '';
  private generation: number = -1;
  private origin: string = '';
  private username: string = '';
  private board: string = '';
  private bookmark: string = '';
  private boardSummary: PinmonyHomeBoard | undefined = undefined;
  private busy: boolean = false;
  private categoriesBusy: boolean = false;
  private categoriesReady: boolean = false;
  private tabs: PinmonyHomeTab[] = [];
  private readonly feeds: Map<string, HomeFeed> = new Map<string, HomeFeed>();
  private readonly requests: Set<string> = new Set<string>();
  constructor(ports: PinmonyHomeNativeReadsPorts) { this.ports = ports; this.store = ports.store(); }
  reset(): void {
    this.pause(); this.feeds.clear(); this.account = ''; this.generation = -1; this.origin = ''; this.username = '';
    this.board = ''; this.bookmark = ''; this.boardSummary = undefined; this.tabs = []; this.categoriesReady = false;
    this.store.home = undefined; this.store.cachedHome = undefined; this.store.cachedHomeScrollOffset = 0;
    this.store.homeNativeReadsReady = false; this.store.homeActionsReady = false; this.store.homeSourceWarning = '';
  }
  pause(): void {
    if (!PIN_NATIVE_HOME_READS_ENABLED) return;
    this.revision++; this.requests.forEach((id: string): void => this.ports.network().cancel(id)); this.requests.clear();
    this.busy = false; this.categoriesBusy = false;
    this.store.homeLoading = false; this.store.homeRefreshing = false; this.store.pendingHomeTab = '';
    if (this.store.home) { this.store.home.loadingMore = false; this.store.home.refreshing = false; }
  }
  private bind(): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if (!session.authenticated) return false;
    const username: string = this.ports.username();
    if (!session.authenticated || !/^[A-Za-z0-9_]+$/.test(username)) return false;
    if (this.generation !== session.generation || this.account !== session.accountId || this.origin !== session.origin || this.username !== username) {
      const sameAccount: boolean = this.account === session.accountId && this.origin === session.origin;
      this.pause(); this.feeds.clear(); this.bookmark = ''; this.categoriesReady = false; this.tabs = [];
      this.board = ''; this.boardSummary = undefined; this.store.homeNativeReadsReady = false; this.store.homeActionsReady = false;
      if (!sameAccount && this.account) { this.store.home = undefined; this.store.cachedHome = undefined; this.store.cachedHomeScrollOffset = 0; }
      this.store.homeSourceWarning = '';
      this.account = session.accountId; this.generation = session.generation; this.origin = session.origin; this.username = username;
    }
    return true;
  }
  current(): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return PIN_NATIVE_HOME_READS_ENABLED && this.ports.active() && session.authenticated && session.generation === this.generation &&
      session.accountId === this.account && session.origin === this.origin && this.ports.username() === this.username;
  }
  async demand(): Promise<void> {
    if (!this.ports.active() || !this.bind()) return;
    const retained: HomeFeed | undefined = this.feeds.get(this.board);
    if (retained) { this.bookmark = retained.bookmark; this.commit(retained.snapshot, 'cache'); return; }
    const selected: PinmonyHomeTab | undefined = this.store.home?.tabs.find((tab: PinmonyHomeTab): boolean => tab.selected);
    if (selected && /^tab:\d+$/.test(selected.id)) this.board = selected.id.slice(4);
    const feed: Promise<void> = this.readFeed(false);
    if (!this.categoriesReady && !this.categoriesBusy) this.readCategories();
    await feed;
  }
  async refresh(): Promise<void> {
    if (!this.ports.active() || !this.bind() || this.busy) return;
    const feed: Promise<void> = this.readFeed(false);
    if (!this.categoriesReady && !this.categoriesBusy) this.readCategories();
    await feed;
  }
  async select(id: string): Promise<void> {
    if (!this.ports.active() || !this.bind()) return;
    const target: PinmonyHomeTab | undefined = this.store.home?.tabs.find((tab: PinmonyHomeTab): boolean => tab.id === id && tab.enabled);
    if (!target || target.selected && !this.store.homeError) return;
    this.pause(); this.board = id === 'tab:all' ? '' : id.slice(4); this.bookmark = ''; this.boardSummary = undefined;
    this.store.cachedHomeScrollOffset = 0; this.store.homeNativeReadsReady = false;
    const cached: HomeFeed | undefined = this.feeds.get(this.board);
    if (cached) { this.bookmark = cached.bookmark; this.commit(cached.snapshot, 'cache'); return; }
    // Keep the native page and category controls mounted while only the feed loads.
    const tabs: PinmonyHomeTab[] = this.makeTabs();
    this.store.home = { kind: 'loading', session: 0, pageKey: this.origin + '/',
      selectedTab: target.label, tabs: tabs, pins: [], dataSource: 'api' };
    this.store.pendingHomeTab = id;
    await this.readFeed(false);
    if (!this.categoriesReady && !this.categoriesBusy && this.current()) this.readCategories();
  }
  async more(): Promise<void> {
    if (!this.ports.active() || !this.bind() || this.busy) return;
    if (!this.feeds.has(this.board)) { await this.demand(); return; }
    if (!this.store.homeNativeReadsReady || this.store.home !== this.feeds.get(this.board)?.snapshot) {
      const retained: HomeFeed | undefined = this.feeds.get(this.board);
      if (!retained) return;
      this.bookmark = retained.bookmark; this.commit(retained.snapshot, 'cache');
    }
    if (this.store.home?.endReached) return;
    await this.readFeed(true);
  }
  private makeTabs(): PinmonyHomeTab[] {
    const selected: string = this.board ? 'tab:' + this.board : 'tab:all';
    const tabs: PinmonyHomeTab[] = this.tabs.length ? this.tabs : this.store.home?.tabs || [];
    const result: PinmonyHomeTab[] = [{ id: 'tab:all', label: '所有', selected: selected === 'tab:all', enabled: true }];
    tabs.filter((tab: PinmonyHomeTab): boolean => tab.id !== 'tab:all').forEach((tab: PinmonyHomeTab): void => {
      result.push({ id: tab.id, label: tab.label, selected: tab.id === selected, enabled: true });
    });
    if (this.board && !result.some((tab: PinmonyHomeTab): boolean => tab.selected)) {
      result.push({ id: selected, label: this.store.home?.selectedTab || '图板', selected: true, enabled: true });
    }
    return result;
  }
  private commit(snapshot: PinmonyHomeSnapshot, kind: 'feed' | 'pagination' | 'cache' = 'feed'): void {
    if (!this.current()) return;
    snapshot.sourceError = this.store.homeSourceWarning || undefined; snapshot.categorySourceFailure = !!this.store.homeSourceWarning;
    snapshot.tabs = this.makeTabs(); snapshot.selectedTab = snapshot.tabs.find((tab: PinmonyHomeTab): boolean => tab.selected)?.label || '所有';
    this.store.home = snapshot; this.store.cachedHome = snapshot; this.store.homeNativeReadsReady = true;
    this.store.homeLoading = false; this.store.homeError = this.store.homeSourceWarning; this.store.homeRefreshing = false; this.store.pendingHomeTab = '';
    this.store.retainingHomeFeed = false; this.store.diskCacheRestored = false; this.store.startupFeedCommitted = true;
    this.feeds.set(this.board, { snapshot: snapshot, bookmark: this.bookmark });
    if (this.feeds.size > 4) { const first: string = Array.from(this.feeds.keys())[0]; if (first !== this.board) this.feeds.delete(first); }
    this.ports.committed(snapshot, kind);
  }
  private async request(resource: string, options: HomeOptions, source: string, live: () => boolean): Promise<PinmonyNetworkReply> {
    const id: string = 'native_home_' + (++this.sequence).toString();
    const envelope: HomeEnvelope = { options: options, context: {} };
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const headers: Record<string, string> = { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
      'X-Pinterest-Pws-Handler': 'www/index.js', 'X-Pinterest-AppState': 'active', 'X-Pinterest-Source-Url': source };
    if (session.appVersion) headers['X-App-Version'] = session.appVersion;
    const job: PinmonyNetworkJob = { id: id, epoch: this.generation, page: this.origin + '/', method: 'GET', body: '', headers: headers,
      url: this.origin + '/resource/' + resource + '/get/?source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)) };
    this.requests.add(id);
    try { return await this.ports.network().requestBusinessHomeRead(job, (): PinmonyBusinessSessionContext => this.ports.session(), this.username, this.board, live); }
    finally { this.requests.delete(id); }
  }
  private async readFeed(append: boolean): Promise<void> {
    if (!this.current() || this.busy) return;
    const revision: number = this.revision, board: string = this.board;
    const live = (): boolean => revision === this.revision && board === this.board && this.current();
    const previous: string = append ? this.bookmark : '';
    this.busy = true; this.store.homeLoading = !this.store.home?.pins.length;
    this.store.homeRefreshing = !append && !!this.store.home?.pins.length; this.store.homeError = '';
    if (this.store.home) this.store.home.loadingMore = append;
    PinmonyRuntimeLog.info('HomeReadTrace: native request append=' + append.toString());
    try {
      const options: HomeOptions = board ? { type: 'board', id: board, __track__referrer: 19 } :
        { field_set_key: 'hf_grid', in_nux: false, in_news_hub: false, static_feed: false };
      if (previous) options.bookmarks = [previous];
      const source: string = board ? '/?tabId=' + board : '/';
      const pending: Promise<PinmonyNetworkReply> = this.request(board ? 'BoardContentRecommendationResource' : 'UserHomefeedResource', options, source, live);
      if (!append && board) this.readBoard(board, live);
      const reply: PinmonyNetworkReply = await pending;
      if (!live()) return;
      if (reply.error || reply.status !== 200 || reply.body.length > 8000000) throw new Error('home-read-failed');
      const data: HomeResource = (JSON.parse(reply.body) as HomeResponse).resource_response;
      if (data?.status !== 'success' || data.error || data.code !== undefined && data.code !== 0 || !Array.isArray(data.data) || data.data.length > 3000) throw new Error('invalid-home');
      const incoming: PinmonyHomePin[] = this.mapPins(data.data);
      if (data.data.length && !incoming.length) throw new Error('invalid-pins');
      const pins: PinmonyHomePin[] = append ? (this.store.home?.pins || []).slice() : [];
      incoming.forEach((pin: PinmonyHomePin): void => { if (pins.length < 3000 && !pins.some((old: PinmonyHomePin): boolean => old.id === pin.id)) pins.push(pin); });
      const cursor: string = typeof data.bookmark === 'string' && data.bookmark.length <= 4096 ? data.bookmark : '';
      this.bookmark = cursor;
      const snapshot: PinmonyHomeSnapshot = { kind: 'state', session: 0, pageKey: this.origin + '/', selectedTab: '', tabs: [],
        board: this.boardSummary?.id === board ? this.boardSummary : undefined, pins: pins, dataSource: 'api', loadingMore: false,
        refreshing: false, endReached: !cursor || cursor === '-end-' || !!previous && cursor === previous || data.data.length === 0 || pins.length >= 3000 };
      this.commit(snapshot, append ? 'pagination' : 'feed');
    } catch (_) { if (live()) this.store.homeError = append ? '更多帖子读取失败，请重试' : PinmonyI18n.message('首页读取失败，请重试'); }
    finally { if (revision === this.revision) { this.busy = false; this.store.homeLoading = false; this.store.homeRefreshing = false;
      this.store.pendingHomeTab = ''; if (this.store.home) this.store.home.loadingMore = false; } }
  }
  private async readCategories(): Promise<void> {
    if (!this.current() || this.categoriesBusy) return;
    const revision: number = this.revision;
    const live = (): boolean => revision === this.revision && this.current();
    this.categoriesBusy = true;
    try {
      const reply: PinmonyNetworkReply = await this.request('BoardsFeedResource', { field_set_key: 'profile_grid_item', filter_stories: false,
        sort: 'last_pinned_to', username: this.username }, '/' + this.username + '/', live);
      if (!live()) return;
      if (reply.error || reply.status !== 200 || reply.body.length > 4000000) throw new Error('categories-read');
      const data: HomeResource = (JSON.parse(reply.body) as HomeResponse).resource_response;
      if (data?.status !== 'success' || !Array.isArray(data.data) || data.data.length > 2000) throw new Error('invalid-categories');
      const tabs: PinmonyHomeTab[] = [];
      data.data.forEach((item: HomeItem): void => { if (item?.type === 'board' && /^\d+$/.test(String(item.id || '')) && item.name?.trim() &&
        !tabs.some((tab: PinmonyHomeTab): boolean => tab.id === 'tab:' + item.id)) tabs.push({ id: 'tab:' + item.id, label: item.name.trim().slice(0,160), selected: false, enabled: true }); });
      this.tabs = tabs; this.categoriesReady = true; this.store.homeSourceWarning = '';
      if (this.store.home) { this.store.home.tabs = this.makeTabs(); this.store.home.sourceError = undefined; this.store.home.categorySourceFailure = false; this.store.homeError = ''; this.ports.committed(this.store.home, 'metadata'); }
    } catch (_) { if (live()) { this.store.homeSourceWarning = PinmonyI18n.message('已收藏图板分类读取失败，请下拉重试'); this.store.homeError = this.store.homeSourceWarning; if (this.store.home) { this.store.home.sourceError = this.store.homeSourceWarning; this.store.home.categorySourceFailure = true; } } }
    finally { if (revision === this.revision) this.categoriesBusy = false; }
  }
  private async readBoard(board: string, live: () => boolean): Promise<void> {
    try {
      const reply: PinmonyNetworkReply = await this.request('BoardResource', { field_set_key: 'profile_grid_item', is_mobile_fork: true, board_id: board }, '/?tabId=' + board, live);
      if (!live() || reply.error || reply.status !== 200) return;
      const resource: BoardResource = (JSON.parse(reply.body) as BoardResponse).resource_response;
      const data: BoardData = resource?.data;
      if (resource?.status !== 'success' || resource.code !== 0 || resource.endpoint_name !== 'v3_get_board' || String(data?.id) !== board || !data.name?.trim() ||
        !Number.isFinite(data.pin_count) || data.pin_count < 0 || data.pin_count > 1000000000) return;
      const boardUrl: string = typeof data.url === 'string' && data.url.length <= 2000 ?
        (data.url.startsWith('/') && !data.url.startsWith('//') ? this.origin + data.url : data.url) : '';
      const value: PinmonyHomeBoard = { boardUrl: boardUrl.startsWith(this.origin + '/') ? boardUrl : '', id: board, name: data.name.trim().slice(0,160), pinCount: Math.floor(data.pin_count),
        thumbnailUrl: this.imageUrl(data.cover_images?.['236x']?.url || data.cover_images?.['200x150']?.url || data.image_cover_url || data.image_cover_hd_url || '') };
      this.boardSummary = value;
      if (this.store.home && this.board === board) { this.store.home.board = value; this.ports.committed(this.store.home, 'metadata'); }
    } catch (_) {}
  }
  private imageUrl(url: string): string { return url.length <= 2000 && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(url) ? url : ''; }
  private mapPins(data: HomeItem[]): PinmonyHomePin[] {
    const pins: PinmonyHomePin[] = [];
    data.forEach((item: HomeItem): void => {
      if (!item || item.type !== 'pin' || !/^\d+$/.test(String(item.id || '')) || pins.some((pin: PinmonyHomePin): boolean => pin.id === String(item.id))) return;
      const image: HomeImage | undefined = ['474x', '736x', '564x', 'orig', '236x'].map((size: string): HomeImage | undefined => item.images?.[size])
        .find((value: HomeImage | undefined): boolean => !!value && !!this.imageUrl(value.url || '') && value.width > 0 && value.height > 0);
      if (!image) return;
      const title: string = [item.grid_title, item.title, item.description].find((value: string | undefined): boolean => typeof value === 'string' && !!value.trim()) || '';
      const sources: PinmonyVideoSource[] = []; const list: Record<string, HomeVideoSource> = item.videos?.video_list || {};
      ['V_HLSV4', 'V_720P'].forEach((name: string): void => {
        const value: HomeVideoSource | undefined = list[name]; const kind: string = name === 'V_HLSV4' ? 'hls' : 'mp4';
        if (value && value.url.length <= 2000 && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/videos\//i.test(value.url) &&
            (kind === 'hls' ? /[.]m3u8$/i : /[.]mp4$/i).test(value.url)) sources.push({ url: value.url, kind: kind });
      });
      const info: HomeVideoSource | undefined = list['V_HLSV4'] || list['V_720P'];
      const video: PinmonyVideo | undefined = sources.length && info ? { pinId: String(item.id), sources: sources, width: info.width || 0,
        height: info.height || 0, duration: Math.max(0, Math.min(86400000, info.duration || 0)) } : undefined;
      pins.push({ id: String(item.id), pinUrl: this.origin + '/pin/' + item.id + '/', imageUrl: image.url, imageWidth: image.width, imageHeight: image.height,
        video: video, title: title.trim().slice(0,160), hasMore: false, saved: this.ports.saved(String(item.id)) });
    }); return pins;
  }
}
