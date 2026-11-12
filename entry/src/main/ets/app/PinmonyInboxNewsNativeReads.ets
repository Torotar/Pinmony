import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyInboxStore, PinmonyInboxItem, PinmonyInboxFlowSnapshot, PinmonyInboxNewsCard } from 'feature_inbox';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyBusinessNetwork as PinmonyNativeNetwork } from './PinmonyBusinessNetwork';
interface InboxNewsImage { url: string; width?: number; height?: number; }
interface InboxNewsObject { id: string; type: string; term?: string; images?: Record<string,InboxNewsImage>; grid_title?: string; title?: string; is_promoted?: boolean; ad_data?: Object; pin_promotion_id?: string | number; }
interface InboxNewsContent { content_object?: InboxNewsObject; }
interface InboxNewsRow { id: string; type: string; display_mode?: number; is_detail?: boolean; detail_header?: string; text_mapping?: Record<string,InboxNewsText>; content_items?: InboxNewsContent[]; }
interface InboxNewsText { t?: string; }
interface InboxNewsResource { status: string; code?: number; error?: Object; endpoint_name: string; data: InboxNewsRow | InboxNewsRow[]; bookmark?: string; }
interface InboxNewsResponse { resource_response: InboxNewsResource; resource?: InboxNewsResourceOptions; }
interface InboxNewsResourceOptions { options?: InboxNewsOptions; }
interface InboxNewsSummaryData { fields: string; }
interface InboxNewsOptions { news_id?: string; url?: string; data?: InboxNewsSummaryData; bookmarks?: string[]; }
interface InboxNewsEnvelope { options: InboxNewsOptions; context: Record<string,string>; }
export interface PinmonyInboxNewsPorts {
  store: () => PinmonyInboxStore;
  session: () => PinmonyBusinessSessionContext;
  page: () => string;
  active: () => boolean;
  network: () => PinmonyNativeNetwork;
  item: (id: string) => PinmonyInboxItem | undefined;
  pin: (card: PinmonyInboxNewsCard) => void;
  search: (term: string) => Promise<void>;
  home: () => Promise<void>;
}
export class PinmonyInboxNewsNativeReads {
  private readonly ports: PinmonyInboxNewsPorts;
  private revision: number = 0;
  private sequence: number = 0;
  private account: string = '';
  private generation: number = -1;
  private origin: string = '';
  private page: string = '';
  private cursor: string = '';
  private busy: boolean = false;
  private readonly requests: Set<string> = new Set<string>();
  constructor(ports: PinmonyInboxNewsPorts) { this.ports = ports; }
  pause(): void {
    const flow: PinmonyInboxFlowSnapshot | undefined = this.ports.store().inboxFlow;
    if(this.busy && flow?.screen === 'news') {
      const next: PinmonyInboxFlowSnapshot = JSON.parse(JSON.stringify(flow)) as PinmonyInboxFlowSnapshot;
      next.loading = false;next.error = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92');this.ports.store().inboxFlow = next;
    }
    this.revision++; this.requests.forEach((id: string): void => this.ports.network().cancel(id)); this.requests.clear(); this.busy = false; }
  reset(): void { this.pause(); this.account = ''; this.generation = -1; this.cursor = ''; }
  private owned(flow: PinmonyInboxFlowSnapshot): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return session.authenticated && session.accountId === this.account && session.generation === this.generation && session.origin === this.origin &&
      this.ports.page() === this.page && this.ports.store().inboxFlow?.nativeToken === flow.nativeToken && this.ports.store().inboxFlow?.screen === 'news';
  }
  private current(flow: PinmonyInboxFlowSnapshot): boolean { return this.ports.active() && this.owned(flow); }
  private detailIdentity(row: InboxNewsRow, newsId: string): boolean {
    if(typeof row.id !== 'string' || row.is_detail !== true)return false;
    if(row.id === newsId)return true;
    return row.id.startsWith(newsId + ':') && /^[A-Za-z0-9_]{1,128}$/.test(row.id.slice(newsId.length + 1));
  }
  async open(id: string): Promise<boolean> {
    if(!id.startsWith('inbox-news-api-'))return false;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const item: PinmonyInboxItem | undefined = this.ports.item(id);
    const match: RegExpMatchArray | null = id.match(/^inbox-news-api-\d+-(\d{1,40})$/);
    if(!item?.enabled || !match || !this.ports.active() || !session.authenticated)return true;
    this.pause();this.account = session.accountId;this.generation = session.generation;this.origin = session.origin;this.page = this.ports.page();this.cursor = '';
    this.ports.store().flowDismissed = false;
    this.ports.store().inboxFlow = {kind:'state',screen:'news',pageUrl:this.page,session:this.ports.store().inboxSession,nativeRead:true,nativeToken:this.revision,
      nativeAccountGeneration:this.generation,newsId:match[1],title:item.title,loading:true,error:'',users:[],messages:[],selectedIds:[],hasMore:false,newsCards:[],newsEnded:false};
    await this.read(false);return true;
  }
  private image(value: string | undefined): string { return typeof value === 'string' && value.length <= 2000 && /^https:\/\/i\.pinimg\.com\//i.test(value) ? value : ''; }
  private card(value: InboxNewsObject): PinmonyInboxNewsCard | undefined {
    if(value?.type === 'news_hub_search') {
      const term: string = typeof value.term === 'string' ? value.term.trim() : '';
      const images: string[] = value.images as Object as string[];
      const image: string = Array.isArray(images) ? this.image(images[0]) : '';
      if(!term || term.length > 300 || !image)return undefined;
      return {id:'search:' + term,kind:'search',title:term,image:image,imageWidth:2,imageHeight:1,target:term};
    }
    if(value?.type !== 'pin' || !/^\d{1,40}$/.test(value.id) || value.is_promoted || value.ad_data || value.pin_promotion_id)return undefined;
    const image: InboxNewsImage | undefined = value.images?.['474x'] || value.images?.['736x'] || value.images?.['236x'];
    const url: string = this.image(image?.url);
    if(!url || !image || !Number.isFinite(image.width) || !Number.isFinite(image.height) || image.width! <= 0 || image.height! <= 0)return undefined;
    return {id:'pin:' + value.id,kind:'pin',title:(value.grid_title || value.title || '').slice(0,500),image:url,imageWidth:image.width!,imageHeight:image.height!,target:this.origin + '/pin/' + value.id + '/'};
  }
  private async request(resource: string, options: InboxNewsOptions, flow: PinmonyInboxFlowSnapshot, live: () => boolean): Promise<InboxNewsResponse> {
    const source: string = '/news_hub/' + flow.newsId + '/';
    const envelope: InboxNewsEnvelope = {options:options,context:{}};
    const id: string = 'native_inbox_news_' + (++this.sequence).toString();
    const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:this.page,url:this.origin + '/resource/' + resource + '/get/?source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      method:'GET',body:'',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/news_hub/[id].js','X-Pinterest-Source-Url':source,'X-Pinterest-AppState':'active'}};
    this.requests.add(id);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessInboxNewsRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),flow.newsId || '',live);
      if(!live() || reply.error || reply.status !== 200 || reply.body.length > 8000000)throw new Error('news-read');
      const response: InboxNewsResponse = JSON.parse(reply.body) as InboxNewsResponse;
      const r: InboxNewsResource = response.resource_response;
      if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 || r.endpoint_name !== (resource === 'ApiResource' ? 'v3_get_news_summary' : 'v3_get_news_details'))throw new Error('news-response');
      return response;
    } finally { this.requests.delete(id); }
  }
  private async read(append: boolean): Promise<void> {
    const flow: PinmonyInboxFlowSnapshot | undefined = this.ports.store().inboxFlow;
    if(!flow || !this.current(flow) || this.busy || append && !this.cursor)return;
    const revision: number = this.revision;this.busy = true;
    let stage: string = 'response';
    const live = (): boolean => revision === this.revision && this.current(flow);
    const next: PinmonyInboxFlowSnapshot = JSON.parse(JSON.stringify(flow)) as PinmonyInboxFlowSnapshot;
    next.loading = true;next.error = '';this.ports.store().inboxFlow = JSON.parse(JSON.stringify(next)) as PinmonyInboxFlowSnapshot;
    PinmonyRuntimeLog.info('InboxNewsTrace: phase=started append=' + append.toString());
    try {
      const options: InboxNewsOptions = {news_id:flow.newsId};if(append)options.bookmarks = [this.cursor];
      const pending: Promise<InboxNewsResponse>[] = [this.request('NewsHubDetailsResource',options,flow,live)];
      if(!append) { const summaryData: InboxNewsSummaryData = {fields:'user.full_name,user.image_large_url,user.type,user.username'}; const summaryOptions: InboxNewsOptions = {url:'/v3/news_hub/' + flow.newsId + '/',data:summaryData};pending.push(this.request('ApiResource',summaryOptions,flow,live)); }
      const replies: InboxNewsResponse[] = await Promise.all<InboxNewsResponse>(pending);
      if(!live())return;
      stage = 'summary';
      if(!append) { const summary: InboxNewsRow = replies[1].resource_response.data as InboxNewsRow;if(summary.id !== flow.newsId || summary.type !== 'news')throw new Error('news-summary'); }
      stage = 'details';
      if(replies[0].resource?.options?.news_id !== flow.newsId)throw new Error('news-owner');
      const rows: InboxNewsRow[] = replies[0].resource_response.data as InboxNewsRow[];
      if(!Array.isArray(rows) || rows.length > 100 || rows.some((row: InboxNewsRow): boolean => !this.detailIdentity(row,flow.newsId || '') || row.type !== 'news' || row.display_mode !== 3 || !Array.isArray(row.content_items) || row.content_items.length > 500))throw new Error('news-content');
      const cards: PinmonyInboxNewsCard[] = append ? (flow.newsCards || []).slice() : [];
      for(const row of rows) {
        if(row.detail_header)next.title = row.detail_header.replace(/\{([^{}]+)\}/g, (all: string,key: string): string => row.text_mapping?.[key]?.t || all).slice(0,500);
        for(const content of row.content_items || []) {const card: PinmonyInboxNewsCard | undefined = content.content_object ? this.card(content.content_object) : undefined;if(card && !cards.some((item: PinmonyInboxNewsCard): boolean => item.id === card.id))cards.push(card);}
      }
      const cursor: string = replies[0].resource_response.bookmark || replies[0].resource?.options?.bookmarks?.[0] || '';
      if(typeof cursor !== 'string' || cursor.length > 4096)throw new Error('news-cursor');
      next.hasMore = !!cursor && cursor !== '-end-' && cursor !== this.cursor && rows.some((row: InboxNewsRow): boolean => !!row.content_items?.length) && cards.length < 1000;
      this.cursor = next.hasMore ? cursor : '';next.newsCards = cards.slice(0,1000);next.newsEnded = !next.hasMore;
      PinmonyRuntimeLog.info('InboxNewsTrace: phase=committed append=' + append.toString() + ' count=' + cards.length.toString() + ' ended=' + (!!next.newsEnded).toString());
    } catch (_) {if(live()){this.requests.forEach((id: string): void => this.ports.network().cancel(id));this.requests.clear();next.error = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92');PinmonyRuntimeLog.info('InboxNewsTrace: phase=failed stage=' + stage + ' append=' + append.toString());}}
    finally {
      if(revision === this.revision) {
        this.busy = false;
        if(this.owned(flow)) {
          if(!this.ports.active()) {next.error = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92');PinmonyRuntimeLog.info('InboxNewsTrace: phase=interrupted');}
          next.newsScrollOffset = this.ports.store().inboxFlow?.newsScrollOffset || 0;
          next.loading = false;this.ports.store().inboxFlow = next;
          PinmonyRuntimeLog.info('InboxNewsTrace: phase=settled error=' + (!!next.error).toString() + ' count=' + (next.newsCards?.length || 0).toString());
        } else PinmonyRuntimeLog.info('InboxNewsTrace: phase=discarded');
      }
    }
  }
  async action(action: string, value: string): Promise<boolean> {
    const flow: PinmonyInboxFlowSnapshot | undefined = this.ports.store().inboxFlow;
    if(flow?.screen !== 'news')return false;
    if(action === 'back') {this.pause();this.ports.store().inboxFlow = undefined;this.ports.store().flowDismissed = true;return true;}
    if(!this.current(flow)) {
      if(action !== 'newsScroll')PinmonyRuntimeLog.info('InboxNewsTrace: phase=action-rejected active=' + this.ports.active().toString() + ' owned=' + this.owned(flow).toString());
      return true;
    }
    if(action !== 'newsScroll')PinmonyRuntimeLog.info('InboxNewsTrace: phase=action action=' + action + ' loading=' + flow.loading.toString());
    if(action === 'newsScroll') {const offset: number = Number(value);if(Number.isFinite(offset) && offset >= 0 && offset <= 1000000)flow.newsScrollOffset = offset;return true;}
    if(action === 'retry') {await this.read(!!flow.newsCards?.length && !!this.cursor);return true;}
    if(action === 'more') {if(flow.hasMore && !flow.error)await this.read(true);return true;}
    if(action === 'newsHome' && flow.newsEnded && !flow.loading && !flow.error) {this.pause();this.ports.store().inboxFlow = undefined;await this.ports.home();return true;}
    const card: PinmonyInboxNewsCard | undefined = flow.newsCards?.find((item: PinmonyInboxNewsCard): boolean => item.id === value);
    if(action === 'newsOpen' && card && !flow.loading) {if(card.kind === 'pin')this.ports.pin(card);else if(card.kind === 'search')await this.ports.search(card.target);}
    return true;
  }
}
