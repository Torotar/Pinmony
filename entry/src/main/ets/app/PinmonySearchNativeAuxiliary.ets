import { PinmonySearchStore, PinmonySearchQuiz, PinmonySearchQuizCard, PinmonySearchQuizTopic, PIN_SEARCH_QUIZ_API_ENABLED } from 'feature_search';
import { PinmonyBusinessAuxiliaryClient, PinmonyAuxiliaryPorts, PinmonyAuxiliaryNotSent, PinmonyAuxiliaryRejected } from './PinmonyBusinessAuxiliaryClient';
interface QuizModule { quiz: QuizText; related_query_items: Topic[]; }
interface QuizText { title?: string; entry_eyebrow?: string; picker_title?: string; picker_see_results_button_copy?: string; }
interface Topic { query: string; cover_pin_url?: string; }
interface Image { url: string; width?: number; height?: number; }
interface Pin { id: string; type: string; images?: Record<string,Image>; image_large_url?: string; image_medium_url?: string; grid_title?: string; title?: string; }
interface Placement { display_data?: QuizModule; }
interface QuizData { results?: Pin[]; '1000269'?: Placement; }
interface Resource { status: string; code?: number; endpoint_name?: string; bookmark?: string; data?: QuizData | Pin[]; }
interface Response { resource_response?: Resource; }
interface EntryOptions { placement_ids: number[]; extra_context: EntryContext; }
interface EntryContext { search_query: string; }
interface TopicOptions { query: string; scope: string; page_size: number; enable_promoted_pins: boolean; bookmarks?: string[]; }
interface RelatedOptions { url: string; data: RelatedData; }
interface RelatedData { client_type: number; pin_ids: string[]; prepend_seed_pins: boolean; }
interface HistoryOptions { url: string; data: HistoryData; }
interface HistoryData { query: string; vertical: string; }
export interface PinmonySearchAuxiliaryPorts extends PinmonyAuxiliaryPorts { store: () => PinmonySearchStore; page: () => string; active: () => boolean; }
export class PinmonySearchNativeAuxiliary {
  private readonly ports: PinmonySearchAuxiliaryPorts; private readonly client: PinmonyBusinessAuxiliaryClient;
  private readonly publish: () => void;
  private account: string = '';private page: string = '';private revision: number = 0;private attempted: boolean = false;
  private module: QuizModule | undefined = undefined;private mode: string = 'entry';private topic: string = '';private cursor: string = '';private ended: boolean = true;
  private cards: PinmonySearchQuizCard[] = [];private selected: string[] = [];private busy: boolean = false;private error: string = '';
  private readonly unknownHistory: Set<string> = new Set<string>();
  constructor(ports: PinmonySearchAuxiliaryPorts,publish: () => void){this.ports = ports;this.client = new PinmonyBusinessAuxiliaryClient(ports);this.publish = publish;}
  pause(): void {this.revision++;this.client.pause();if(this.busy){this.busy = false;if(this.mode === 'entry')this.attempted = false;else this.error = '读取已中断，请重试';}}
  reset(): void {this.pause();this.account = '';this.page = '';this.attempted = false;this.module = undefined;this.cards = [];this.selected = [];this.mode = 'entry';this.error = '';this.cursor = '';this.ended = true;this.unknownHistory.clear();}
  private bind(): boolean {
    const account: string = this.client.key(),page: string = this.ports.page();
    if(!account || !this.ports.active())return false;
    if(account !== this.account){this.reset();this.account = account;}
    if(page !== this.page){this.pause();this.page = page;this.attempted = false;this.module = undefined;this.cards = [];this.selected = [];this.mode = 'entry';this.error = '';this.cursor = '';this.ended = true;}
    return true;
  }
  private query(): string {try {return decodeURIComponent((this.page.match(/[?&]q=([^&]*)/)?.[1] || '').replace(/\+/g,' '));}catch (_) {return '';}}
  private live(revision: number): boolean {return revision === this.revision && this.account === this.client.key() && this.page === this.ports.page() && this.ports.active();}
  snapshot(): PinmonySearchQuiz | undefined {
    if(this.page !== this.ports.page() || this.account !== this.client.key() || !this.module && !this.error)return undefined;
    const text: QuizText | undefined = this.module?.quiz;
    return {mode:this.mode,title:this.mode === 'results' ? '基于你的偏好推荐' + this.query() + '点子' : text?.title || '',entryTitle:text?.title || '',eyebrow:text?.entry_eyebrow || '',pickerTitle:text?.picker_title || '',submitLabel:text?.picker_see_results_button_copy || '',
      topics:(this.module?.related_query_items || []).map((t: Topic,index: number): PinmonySearchQuizTopic => ({id:index.toString(),query:t.query,imageUrl:t.cover_pin_url || ''})),
      cards:this.cards.map((p: PinmonySearchQuizCard): PinmonySearchQuizCard => ({id:p.id,title:p.title,imageUrl:p.imageUrl,targetUrl:p.targetUrl,imageWidth:p.imageWidth,imageHeight:p.imageHeight,selected:this.selected.includes(p.id)})),
      canMore:this.mode === 'picker' && !this.ended,count:this.selected.length,busy:this.busy,error:this.error};
  }
  async demand(): Promise<void> {if(!PIN_SEARCH_QUIZ_API_ENABLED || !this.bind() || this.attempted || !this.query() || !/^\/search\/(?:pins\/?)?(?:\?|$)/.test(this.page.slice(this.ports.session().origin.length)))return;this.attempted = true;await this.read('entry');}
  private map(items: Pin[]): PinmonySearchQuizCard[] {
    const result: PinmonySearchQuizCard[] = [],origin: string = this.ports.session().origin;
    items.slice(0,1000).forEach((p: Pin): void => {if(p?.type !== 'pin' || !/^\d{1,30}$/.test(p.id) || result.some((v: PinmonySearchQuizCard): boolean => v.id === p.id))return;
      const image: Image | undefined = p.images?.['474x'] || p.images?.['236x'],url: string = image?.url || p.image_large_url || p.image_medium_url || '';
      if(url.length > 2048 || !/^https:\/\/i\.pinimg\.com\//i.test(url))return;
      result.push({id:p.id,title:(p.grid_title || p.title || '').slice(0,500),imageUrl:url,imageWidth:image?.width || 236,imageHeight:image?.height || 310,targetUrl:origin + '/pin/' + p.id + '/',selected:false});});return result;
  }
  private async read(kind: string,append: boolean = false): Promise<void> {
    if(this.busy)return;const revision: number = ++this.revision,previous: string = this.cursor;
    this.busy = true;this.error = '';this.publish();
    try {
      let resource: string = 'UserExperienceResource',options: Object,target: string = '';
      if(kind === 'entry'){const value: EntryOptions = {placement_ids:[1000269],extra_context:{search_query:this.query()}};options = value;}
      else if(kind === 'picker'){resource = 'BaseSearchResource';target = this.topic;const value: TopicOptions = {query:this.topic,scope:'pins',page_size:25,enable_promoted_pins:false};if(append)value.bookmarks = [previous];options = value;}
      else {resource = 'ApiResource';target = this.selected.join(',');const value: RelatedOptions = {url:'/v3/batch/related/pins/',data:{client_type:118,pin_ids:this.selected.slice(),prepend_seed_pins:false}};options = value;}
      const response: Response = JSON.parse(await this.client.request(this.page,resource,'get',options,'quiz',target,(): boolean => this.live(revision))) as Response;
      if(!this.live(revision))return;const r: Resource | undefined = response.resource_response;
      if(!r || r.status !== 'success' || r.code !== undefined && r.code !== 0)throw new Error('response');
      if(kind === 'entry'){
        if(!r.data || Array.isArray(r.data))throw new Error('entry');
        const module: QuizModule | undefined = (r.data as Record<string,Placement>)['1000269']?.display_data;
        if(module && (!module.quiz || !Array.isArray(module.related_query_items) || module.related_query_items.length > 100 || !module.related_query_items.every((t: Topic): boolean => typeof t.query === 'string' && t.query.length > 0 && t.query.length <= 300)))throw new Error('module');
        this.module = module;
      }else {
        const items: Pin[] | undefined = kind === 'results' ? r.data as Pin[] : (r.data as QuizData)?.results;
        if(!Array.isArray(items))throw new Error('pins');const incoming: PinmonySearchQuizCard[] = this.map(items);
        if(items.length && !incoming.length)throw new Error('unrecognized');
        this.cards = append ? this.cards.concat(incoming.filter((p: PinmonySearchQuizCard): boolean => !this.cards.some((v: PinmonySearchQuizCard): boolean => v.id === p.id))).slice(0,1000) : incoming;
        this.cursor = typeof r.bookmark === 'string' && r.bookmark.length <= 4096 ? r.bookmark : '';
        this.ended = !this.cursor || this.cursor === '-end-' || append && this.cursor === previous || !items.length;
      }
    }catch (_) {if(this.live(revision))this.error = '灵感推荐读取失败，请重试';}
    finally {if(this.live(revision)){this.busy = false;this.publish();}}
  }
  async action(kind: string,id: string = ''): Promise<void> {
    if(!PIN_SEARCH_QUIZ_API_ENABLED || !this.bind())return;
    if(kind === 'back' || kind === 'dismiss'){this.pause();this.mode = 'entry';this.cards = [];this.selected = [];this.error = '';if(kind === 'dismiss')this.module = undefined;this.publish();return;}
    if(this.busy)return;
    if(kind === 'retry'){await this.read(this.mode,this.mode === 'picker' && !!this.cards.length && !this.ended);return;}
    if(kind === 'topic'){const topic: Topic | undefined = this.module?.related_query_items[Number(id)];if(!topic)return;this.topic = topic.query;this.mode = 'picker';this.cards = [];this.cursor = '';this.ended = true;await this.read('picker');}
    if(kind === 'select' && this.mode === 'picker' && this.cards.some((p: PinmonySearchQuizCard): boolean => p.id === id)){
      if(this.selected.includes(id))this.selected = this.selected.filter((v: string): boolean => v !== id);else if(this.selected.length < 10)this.selected.push(id);this.publish();}
    if(kind === 'more' && this.mode === 'picker' && !this.ended)await this.read('picker',true);
    if(kind === 'submit' && this.mode === 'picker' && this.selected.length){this.mode = 'results';this.cards = [];await this.read('results');}
  }
  historyLocked(query: string): boolean {return this.account === this.client.key() && this.unknownHistory.has(query);}
  async deleteHistory(query: string,current: () => boolean): Promise<boolean> {
    if(!this.bind() || this.unknownHistory.has(query) || !current())return false;
    const account: string = this.account,revision: number = this.revision;this.unknownHistory.add(query);
    const options: HistoryOptions = {url:'/v3/search/recent/',data:{query:query,vertical:'PIN'}};
    try {const p: Response = JSON.parse(await this.client.request(this.page,'ApiResource','delete',options,'history',query,(): boolean => this.live(revision) && current())) as Response;
      const r: Resource | undefined = p.resource_response;
      if(r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)throw new PinmonyAuxiliaryRejected('rejected');
      if(!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== 'v3_recent_search_delete')throw new Error('unconfirmed');
      if(account !== this.client.key() || !this.live(revision) || !current())throw new Error('stale');
      this.unknownHistory.delete(query);return true;
    }catch (error){if(account === this.client.key() && (error instanceof PinmonyAuxiliaryNotSent || error instanceof PinmonyAuxiliaryRejected))this.unknownHistory.delete(query);throw error as Error;}
  }
}
