import { PinmonyInboxStore, PinmonyInboxSnapshot, PinmonyInboxItem } from 'feature_inbox';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
export const PIN_NATIVE_INBOX_UPDATES_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface NewsImage { url?: string; }
interface NewsObject { subscribed_to_notifications?: boolean; id?: string; type?: string; images?: Record<string,NewsImage>; image_cover_url?: string; image_large_url?: string; }
interface NewsText { t?: string; }
interface NewsRow { id: string; type: string; header_text?: string; title_text?: string; content_text?: string; sub_header_text?: string; text_mapping?: Record<string,NewsText>; object_map?: Record<string,NewsObject>; header_icon_object_ids?: string[]; header_icon_image_url?: string; last_updated_at?: string; unread?: boolean; }
interface NewsResource { status: string; code?: number; error?: Object; endpoint_name?: string; data: NewsRow[]; bookmark?: string; }
interface NewsResponse { resource_response: NewsResource; }
interface NewsOptions { url: string; data: NewsData; redux_normalize_feed: boolean; field_sets: string[]; bookmarks?: string[]; }
interface NewsData { field_set_key: string; }
interface NewsEnvelope { options: NewsOptions; context: Record<string,string>; }
interface NativeNews extends PinmonyInboxItem { newsId: string; notificationPinId: string; notificationMuted?: boolean; }
export interface PinmonyInboxUpdatesNativeReadsPorts {
  store: () => PinmonyInboxStore;
  session: () => PinmonyBusinessSessionContext;
  page: () => string;
  active: () => boolean;
  network: () => PinmonyNativeNetwork;
  settled: () => void;
}
export class PinmonyInboxUpdatesNativeReads {
  private readonly ports: PinmonyInboxUpdatesNativeReadsPorts;
  private readonly store: PinmonyInboxStore;
  private section: string = '';
  private account: string = '';
  private origin: string = '';
  private generation: number = -1;
  private page: string = '';
  private revision: number = 0;
  private sequence: number = 0;
  private requestId: string = '';
  private busy: boolean = false;
  private ready: boolean = false;
  private ended: boolean = false;
  private cursor: string = '';
  private error: string = '';
  private moreError: string = '';
  private rows: NativeNews[] = [];
  private readonly hidden: Set<string> = new Set<string>();
  private readonly muted: Set<string> = new Set<string>();
  constructor(ports: PinmonyInboxUpdatesNativeReadsPorts) { this.ports = ports; this.store = ports.store(); }
  selected(): boolean { return PIN_NATIVE_INBOX_UPDATES_ENABLED && (this.section === 'updates' || !this.section && this.store.inbox?.section === 'updates'); }
  eligible(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.selected() && s.authenticated && !!s.accountId && /^\/(?:inbox|messages|updates|notifications)\/$/.test(this.ports.page().slice(s.origin.length)) && this.ports.page().startsWith(s.origin + '/'); }
  owned(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.eligible() && this.ports.active() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.page === this.ports.page(); }
  private bind(): boolean {
    if (!this.eligible() || !this.ports.active()) return false; const s: PinmonyBusinessSessionContext = this.ports.session();
    if (this.account !== s.accountId || this.generation !== s.generation || this.origin !== s.origin || this.page !== this.ports.page()) {
      const section: string = this.section || 'updates'; this.reset(); this.section = section; this.account = s.accountId; this.generation = s.generation; this.origin = s.origin; this.page = this.ports.page();
    }
    return true;
  }
  pause(): void { this.revision++; if (this.requestId) this.ports.network().cancel(this.requestId); this.requestId = ''; this.busy = false; this.store.inboxNativeUpdatesReady = false; }
  reset(): void { this.pause(); if(this.account) { this.store.inboxCache.clear(); if(this.store.inbox?.section === 'updates') this.store.inbox = undefined; } this.account = ''; this.origin = ''; this.generation = -1; this.page = ''; this.section = ''; this.ready = false; this.ended = false; this.cursor = ''; this.rows = []; this.hidden.clear(); this.muted.clear(); this.error = ''; this.moreError = ''; }
  async select(section: string): Promise<boolean> {
    if (!PIN_NATIVE_INBOX_UPDATES_ENABLED || !this.ports.session().authenticated || !this.ports.active()) return false;
    if (section !== 'updates') { this.section = section; this.pause(); return false; }
    if(this.store.inbox && !this.selected()) this.store.inboxCache.put(this.store.inbox,this.store.inboxScrollOffset);
    this.section = 'updates'; if (!this.bind()) return false;
    this.store.inboxScrollOffset = this.store.inboxCache.get(this.page,'updates')?.scrollOffset || 0;
    this.apply(); await this.demand(); return true;
  }
  apply(): void {
    if (!this.owned()) return;
    const snapshot: PinmonyInboxSnapshot = { kind: 'state', session: this.store.inboxSession, pageUrl: this.page, section: 'updates', updateLabel: '更新', inboxLabel: '收件箱', messagesLabel: '消息', readLabel: '已读', unreadLabel: '未读', emptyTitle: this.ready && !this.rows.length ? '暂无更新' : '', emptyDescription: '', homeLabel: '浏览主页', homeId: 'home', composeLabel: '', composeId: '', contactsLabel: '', items: this.rows.map((row: NativeNews): NativeNews => {const next: NativeNews = JSON.parse(JSON.stringify(row)) as NativeNews;next.subdued = this.hidden.has(row.newsId) || row.notificationMuted === true || this.muted.has(row.notificationPinId);if(this.hidden.has(row.newsId)){next.enabled = false;next.moreId = '';}return next;}), contacts: [], dataSource: 'api', hasMore: !this.ended && !!this.cursor, moreLoading: this.ready && this.busy, moreError: this.moreError, apiError: this.error };
    this.store.inbox = snapshot; this.store.inboxUrl = this.page; this.store.inboxSectionReady = true; this.store.inboxNativeUpdatesReady = this.ready;
    this.store.pendingInboxSection = ''; this.store.restoringInboxSection = ''; this.store.inboxLoading = !this.ready && this.busy; this.store.inboxError = this.error;
    if (this.ready && !this.busy && !this.error && !this.moreError) this.store.inboxCache.put(snapshot,this.store.inboxScrollOffset);
  }
  async demand(): Promise<void> { if (!this.bind()) return; this.apply(); if(!this.ready && !this.busy) await this.read(false); }
  async refresh(): Promise<void> { if(this.bind() && !this.busy) await this.read(false); }
  async more(): Promise<void> { if(!this.bind() || this.busy || this.ended && !this.moreError)return; await this.read(this.ready && !!this.cursor && !this.ended); }
  confirmedVisibility(newsId: string, hidden: boolean): void { const s: PinmonyBusinessSessionContext = this.ports.session(); if(this.eligible() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.page === this.ports.page() && this.rows.some((row: NativeNews): boolean => row.newsId === newsId)) { if(hidden)this.hidden.add(newsId); else this.hidden.delete(newsId); this.apply(); } }
  confirmedUnsubscribe(newsId: string): void {const s: PinmonyBusinessSessionContext = this.ports.session();if(this.eligible() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.page === this.ports.page() && this.rows.some((row: NativeNews): boolean => row.newsId === newsId)){const row: NativeNews | undefined = this.rows.find((item: NativeNews): boolean => item.newsId === newsId);if(row && /^\d{1,40}$/.test(row.notificationPinId)){this.muted.add(row.notificationPinId);this.apply();}}}
  menuItem(id: string): NativeNews | undefined {const s: PinmonyBusinessSessionContext = this.ports.session();return this.eligible() && this.account === s.accountId && this.generation === s.generation && this.origin === s.origin && this.page === this.ports.page() ? this.rows.map((row: NativeNews): NativeNews => { const next: NativeNews = JSON.parse(JSON.stringify(row)) as NativeNews; next.notificationMuted = row.notificationMuted === true || this.muted.has(row.notificationPinId); return next; }).find((row: NativeNews): boolean => row.moreId === id && !this.hidden.has(row.newsId)) : undefined;}
  installScript(): string {
    if(!this.owned())return '';
    return 'window.PinmonyInboxApi && window.PinmonyInboxApi.installNative && window.PinmonyInboxApi.installNative(' + JSON.stringify(this.page) + ',' + JSON.stringify(this.rows.filter((row: NativeNews): boolean => !this.hidden.has(row.newsId))) + ');';
  }
  private clean(value: string | undefined): string { return typeof value === 'string' ? value.trim().slice(0,500) : ''; }
  private label(value: string | undefined, mapping: Record<string,NewsText> | undefined): string { return this.clean(value).replace(/\{([^{}]+)\}/g, (all: string,name: string): string => this.clean(mapping?.[name]?.t) || all); }
  private image(value: string | undefined): string { return typeof value === 'string' && value.length <= 2000 && /^https:\/\/i\.pinimg\.com\//i.test(value) ? value : ''; }
  private map(row: NewsRow): NativeNews {
    if(!row || row.type !== 'news' || typeof row.id !== 'string' || !row.id.trim() || row.id.length > 100)throw new Error('news-id');
    const title: string = this.label(row.header_text || row.title_text,row.text_mapping); if(!title || /\{[^{}]+\}/.test(title))throw new Error('news-title');
    const object: NewsObject | undefined = row.object_map?.[row.header_icon_object_ids?.[0] || ''];
    const images: Record<string,NewsImage> | undefined = object?.images;
    const image: string = this.image(row.header_icon_image_url) || this.image(images?.['150x150']?.url) || this.image(images?.['345x']?.url) || this.image(object?.image_cover_url || object?.image_large_url);
    const id: string = 'inbox-news-api-' + this.generation.toString() + '-' + row.id;
    return { id:id, newsId:row.id, notificationPinId: object?.type === 'pin' && /^\d+$/.test(object.id || '') ? object.id || '' : '', notificationMuted: object?.type === 'pin' && object.subscribed_to_notifications === false, title:title, subtitle:this.label(row.content_text || row.sub_header_text,row.text_mapping), imageUrl:image, updatedAt:this.clean(row.last_updated_at), unread:typeof row.unread === 'boolean' ? row.unread : undefined, enabled:false, moreId:'news-menu:' + id };
  }
  private async read(append: boolean): Promise<void> {
    const revision: number = this.revision; const previous: string = append ? this.cursor : ''; const live = (): boolean => revision === this.revision && this.owned();
    const id: string = 'native_inbox_updates_' + (++this.sequence).toString(); this.requestId = id; this.busy = true; this.error = ''; this.moreError = ''; this.apply();
    const options: NewsOptions = { url:'/v3/news_hub/feed/',data:{field_set_key:'unauthed'},redux_normalize_feed:true,field_sets:INBOX_UPDATE_FIELDS.slice() }; if(append)options.bookmarks = [previous];
    const envelope: NewsEnvelope = {options:options,context:{}};
    const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:this.page,url:this.origin+'/resource/ApiResource/get/?source_url='+encodeURIComponent('/inbox/')+'&data='+encodeURIComponent(JSON.stringify(envelope)),method:'GET',body:'',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}};
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessInboxUpdatesRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),live);
      if(!live())return; if(reply.error || reply.status !== 200 || reply.body.length > 4000000)throw new Error('news-request');
      const resource: NewsResource = (JSON.parse(reply.body) as NewsResponse).resource_response;
      if(resource?.status !== 'success' || resource.error || resource.code !== undefined && resource.code !== 0 || resource.endpoint_name && resource.endpoint_name !== 'v3_get_news_hub_feed' || !Array.isArray(resource.data) || resource.data.length > 500)throw new Error('news-response');
      const merged: NativeNews[] = append ? this.rows.slice() : []; resource.data.forEach((row: NewsRow): void => { const item: NativeNews = this.map(row); if(!merged.some((value: NativeNews): boolean => value.newsId === item.newsId))merged.push(item); });
      const cursor: string = typeof resource.bookmark === 'string' && resource.bookmark.length <= 4096 ? resource.bookmark : '';
      merged.forEach((row: NativeNews): void => {
        if (row.notificationMuted === true && /^\d{1,40}$/.test(row.notificationPinId)) this.muted.add(row.notificationPinId);
      });
      this.rows = merged; this.cursor = cursor; this.ended = !cursor || cursor === '-end-' || cursor === previous || !resource.data.length; this.ready = true;
      PinmonyRuntimeLog.info('InboxUpdatesNativeTrace: committed append='+append.toString()+' count='+merged.length.toString());
    } catch (_) { if(live()){ if(append)this.moreError = '加载更多更新失败，请重试'; else this.error = '更新读取失败，请重试'; } }
    finally { if(revision === this.revision){ this.busy = false; this.requestId = ''; if(live())this.apply(); this.ports.settled(); } }
  }
}
export const INBOX_UPDATE_FIELDS: string[] = ['board.name','board.id','board.images[170x]','board.image_cover_url','board.image_thumbnail_urls[100x]','board.subscribed_to_notifications','board.type','interest.background_color','interest.id','interest.type','interest.images[236x]','interest.name','pin.description','pin.id','pin.image_signature','pin.images[150x150,345x]','pin.subscribed_to_notifications','pin.title','pin.tracking_params','pin.type','user.full_name','user.id','user.image_large_url','user.recent_pin_images[200x]','user.subscribed_to_notifications','user.type'];
