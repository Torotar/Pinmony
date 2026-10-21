import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore, MoreSheetOption, PIN_EDIT_API_ENABLED, PIN_POST_API_ENABLED } from 'feature_pin';
import { PinmonyHomeMenuState } from 'feature_home';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
export const PIN_NATIVE_PIN_MENUS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED && PIN_POST_API_ENABLED;
interface Image { url?: string; }
interface User { id?: string; }
interface Topic { name?: string; }
interface Pin { id: string; pinner?: User; is_repin?: boolean; images?: Record<string,Image>; ai_disclosures?: number[]; gen_ai_topics?: Topic[];
  client_tracking_params?: string; tracking_params?: string; through_id?: string; rec_reason_type?: number; source?: number; }
interface Resource { status: string; code?: number; endpoint_name?: string; error?: Object; data?: Pin; }
interface Response { resource_response: Resource; client_context?: Client; }
interface Client { user?: User; }
interface Feedback { pin: string; client_tracking_params?: string; through_id?: string; rec_reason_type?: number; source?: number; feedback_type?: number; }
interface Options { id?: string; field_set_key?: string; noCache?: boolean; fetch_visual_search_objects?: boolean; get_page_metadata?: boolean; add_fields?: string; url?: string; data?: Feedback; }
interface Envelope { options: Options; context: Record<string,string>; }
interface Undo { pin: string; session: number; account: string; tracking: string; }
class PinMenuNotSent extends Error {}
class PinMenuRejected extends Error {}
export interface PinmonyPinMenuNativePorts {
  store: () => PinmonyPinStore; session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  active: () => boolean; route: () => string; owns: (pin: string) => boolean; sheet: () => string;
  show: () => void; dismiss: () => void; download: (url: string) => void; help: (url: string) => void;
  edit: (pin: string) => Promise<void>; share: (pin: string) => Promise<void>;
  message: (value: string) => void; undoSnack: (value: string,pin: string) => void;
}
export class PinmonyPinMenuNative {
  private readonly ports: PinmonyPinMenuNativePorts; private readonly store: PinmonyPinStore;
  private revision: number = 0; private sequence: number = 0; private requestId: string = '';
  private account: string = ''; private pin: string = ''; private route: string = ''; private token: number = 0;
  private raw: Pin | undefined = undefined; private viewer: string = ''; private photo: boolean = false; private busy: boolean = false;
  private readonly submitted: Set<string> = new Set<string>();
  private undo: Undo | undefined = undefined;
  constructor(ports: PinmonyPinMenuNativePorts) {this.ports = ports;this.store = ports.store();}
  private key(): string {const s: PinmonyBusinessSessionContext = this.ports.session();return s.authenticated && s.accountId ? s.accountId + ':' + s.generation.toString() + ':' + s.origin : '';}
  private id(pin: string = this.pin): string {return pin.match(/\/pin\/(\d{1,30})\/$/)?.[1] || '';}
  pause(): void {this.revision++;if(this.requestId)this.ports.network().cancel(this.requestId);this.requestId = '';this.busy = false;this.store.feedbackUndoBusy = false;}
  private current(revision: number): boolean {return revision === this.revision && this.key() === this.account && this.ports.active() && this.route === this.ports.route() && this.ports.owns(this.pin) &&
    (this.photo ? this.ports.sheet() === 'share' && this.store.shareSession === this.token : this.ports.sheet() === 'more' && this.store.moreSession === this.token);}
  private bind(pin: string,token: number,photo: boolean): number {
    this.pause();const key: string = this.key();if(key !== this.account){this.submitted.clear();this.undo = undefined;}this.account = key;this.pin = pin;this.token = token;this.photo = photo;this.route = this.ports.route();this.raw = undefined;this.viewer = '';return this.revision;
  }
  private async request(options: Options,revision: number,undo: boolean = false): Promise<Resource> {
    const s: PinmonyBusinessSessionContext = this.ports.session(), get: boolean = !options.url;
    const envelope: Envelope = {options:options,context:{}}, path: string = '/pin/' + this.id() + '/';
    const id: string = 'native_pin_menu_' + (++this.sequence).toString();this.requestId = id;
    const live = (): boolean => undo ? revision === this.revision && this.key() === this.account && this.ports.active() && this.ports.owns(this.pin) && this.route === this.ports.route() : this.current(revision);
    const job: PinmonyNetworkJob = {id:id,epoch:s.generation,page:this.pin,url:s.origin + '/resource/' + (get ? 'PinResource/get/?source_url=' + encodeURIComponent(path) + '&data=' + encodeURIComponent(JSON.stringify(envelope)) : 'ApiResource/update/'),
      method:get ? 'GET' : 'POST',body:get ? '' : 'source_url=' + encodeURIComponent(path) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/pin/[id].js','X-Pinterest-Source-Url':path,'Content-Type':'application/x-www-form-urlencoded'}};
    const reply = await this.ports.network().requestBusinessPinMenu(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.pin,live);
    if(['request-unavailable','background'].includes(reply.error))throw new PinMenuNotSent('not-sent');
    if(!live())throw new Error('stale');if(reply.error || reply.status !== 200 || reply.body.length > 6000000)throw new Error('request');
    const body: Response = JSON.parse(reply.body) as Response,r: Resource = body.resource_response;
    if(r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)throw new PinMenuRejected('rejected');
    if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0)throw new Error('response');
    if(get){if(!r.data || r.data.id !== this.id())throw new Error('pin');this.raw = r.data;this.viewer = body.client_context?.user?.id || '';
      const identityReady: boolean = /^\d{1,30}$/.test(this.viewer) && typeof this.raw.pinner?.id === 'string' && /^\d{1,30}$/.test(this.raw.pinner.id);
      PinmonyRuntimeLog.info('PinEditTrace: phase=menu-read identity=' + (identityReady ? 'ready' : 'missing') +
        ' owner=' + (this.raw.pinner?.id === this.viewer && !!this.viewer ? 'self' : 'other') +
        ' content=' + (this.raw.is_repin === false ? 'original' : this.raw.is_repin === true ? 'saved' : 'unknown'));
      if(!identityReady)throw new Error('edit-identity');
    }
    return r;
  }
  private async read(revision: number): Promise<void> {await this.request({id:this.id(),field_set_key:'auth_web_main_pin',noCache:true,fetch_visual_search_objects:false,get_page_metadata:false,
    add_fields:'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin'},revision);}
  private image(): string {const images = this.raw?.images, url: string = (images?.['orig'] || images?.['736x'] || images?.['474x'])?.url || '';return url.length <= 2048 && /^https:\/\/i\.pinimg\.com\//.test(url) ? url : '';}
  private enabled(action: string): boolean {return !this.submitted.has(this.pin + ':' + action);}
  private canOpenEdit(): boolean {return PIN_EDIT_API_ENABLED && /^\d{1,30}$/.test(this.viewer) && this.raw?.pinner?.id === this.viewer;}
  async photoRead(token: number,pin: string): Promise<PinmonyHomeMenuState> {
    const revision: number = this.bind(pin,token,true);
    const state: PinmonyHomeMenuState = {session:token,pinUrl:pin,loading:false,busy:false,error:'',feedback:'',options:[],actions:[]};
    try {await this.read(revision);if(!this.current(revision))return state;
      state.actions = [{id:'home-save',label:PinmonyI18n.message("pm_save_60a53514"),enabled:true},{id:'home-download',label:PinmonyI18n.message("pm_download_image_8894375c"),enabled:!!this.image()},
        {id:'home-see-more',label:PinmonyI18n.message("pm_see_more_92b2b2de"),enabled:this.enabled('more')},{id:'home-see-less',label:PinmonyI18n.message("pm_see_less_9c80a8dc"),enabled:this.enabled('less')}];
      if(this.canOpenEdit())state.actions.unshift({id:'home-edit',label:PinmonyI18n.message("pm_edit_pin_f9119bcf"),enabled:true});
    } catch (_) {state.error = PinmonyI18n.message("pm_unable_to_load_pin_actions_please_retry_1434adac");}
    return state;
  }
  private option(id: string,label: string,enabled: boolean = true): MoreSheetOption {return {id:id,label:label,enabled:enabled,subtitle:'',icon:'',group:0};}
  async open(): Promise<void> {
    const detail = this.store.detail;if(!this.ports.active() || !detail || !this.ports.owns(detail.pinUrl))return;
    const token: number = Math.max(1,this.store.moreSession + 1);this.store.moreSession = token;this.store.morePin = detail.pinUrl;this.store.moreApiMode = true;
    this.store.moreTitle = PinmonyI18n.message('pm_options_bb7486f4');this.store.moreOptions = [];this.store.moreLoading = true;this.store.moreError = '';this.store.ignoredMoreSession = 0;this.ports.show();
    const revision: number = this.bind(detail.pinUrl,token,false);
    try {await this.read(revision);if(!this.current(revision))return;const options: MoreSheetOption[] = [];
      if(this.canOpenEdit())options.push(this.option('detail-edit','编辑 Pin 图'));
      if(this.image())options.push(this.option('detail-download','下载图片'));
      options.push(this.option('detail-see-more','查看更多',this.enabled('more')),this.option('detail-see-less','减少推荐',this.enabled('less')));
      if(this.raw?.ai_disclosures?.includes(1) || this.raw?.gen_ai_topics?.some((t: Topic): boolean => typeof t.name === 'string' && !!t.name.trim()))options.push(this.option('detail-ai-help','详细了解 AI 标签'));
      this.store.moreOptions = options;
    } catch (_) {if(this.current(revision))this.store.moreError = PinmonyI18n.message("pm_unable_to_load_service_options_please_retry_3b2d272d");}
    finally {if(this.current(revision))this.store.moreLoading = false;}
  }
  async action(id: string): Promise<void> {
    const revision: number = this.revision;if(!this.current(revision) || this.busy || !this.raw)return;
    const photo: boolean = this.photo, pin: string = this.pin;
    const options = photo ? undefined : this.store.moreOptions;
    if(!photo && !options?.some((o: MoreSheetOption): boolean => o.id === id && o.enabled))return;
    if(id === 'detail-edit' || id === 'home-edit'){
      if(!this.canOpenEdit() || photo && id !== 'home-edit' || !photo && id !== 'detail-edit')return;
      PinmonyRuntimeLog.info('PinEditTrace: phase=menu-open');this.ports.dismiss();await this.ports.edit(pin);return;
    }
    if(id === 'detail-ai-help'){this.ports.help('https://help.pinterest.com/en/article/gen-ai-labels');return;}
    if(id === 'home-download' || id === 'detail-download'){const url: string = this.image();if(url)this.ports.download(url);return;}
    const less: boolean = id === 'home-see-less' || id === 'detail-see-less';
    if(!less && id !== 'home-see-more' && id !== 'detail-see-more')return;
    const action: string = less ? 'less' : 'more';if(!this.enabled(action))return;
    const data: Feedback = {pin:this.id()}, raw: Pin = this.raw;
    const tracking: string = raw.client_tracking_params || raw.tracking_params || '';
    if(tracking && tracking.length <= 16384)data.client_tracking_params = tracking;
    if(less)data.feedback_type = 10;
    else {if(typeof raw.through_id === 'string' && raw.through_id.length <= 2000)data.through_id = raw.through_id;
      if(typeof raw.rec_reason_type === 'number' && Number.isFinite(raw.rec_reason_type))data.rec_reason_type = raw.rec_reason_type;
      if(typeof raw.source === 'number' && Number.isFinite(raw.source))data.source = raw.source;else if(!photo)data.source = 5;}
    this.busy = true;this.submitted.add(pin + ':' + action);
    this.store.moreOptions = this.store.moreOptions.map((o: MoreSheetOption): MoreSheetOption => ({id:o.id,label:o.label,subtitle:o.subtitle,icon:o.icon,group:o.group,enabled:false}));
    try {const result: Resource = await this.request({url:less ? '/v3/pfy/' + this.id() + '/feedback/' : '/v3/pin/' + this.id() + '/feedback/see_more/',data:data},revision);
      if(!this.current(revision))return;
      if(result.code !== 0 || result.endpoint_name !== (less ? 'v3_provide_pfy_pin_feedback' : 'v3_pin_see_more_user_feedback') || result.data?.id !== this.id())throw new Error('unconfirmed');
      this.submitted.delete(pin + ':' + action);
      if(!less && !photo){this.undo = {pin:pin,session:this.token,account:this.account,tracking:raw.tracking_params || ''};this.store.feedbackUndoPin = pin;this.store.feedbackUndoSession = this.token;}
      this.ports.dismiss();
      const message: string = less ? PinmonyI18n.message("pm_see_less_feedback_submitted_e4ba54ed") : PinmonyI18n.message("pm_see_more_feedback_submitted_a391370a");
      if(!less && !photo)this.ports.undoSnack(message,pin);else this.ports.message(message);
    } catch (error) {
      const retry: boolean = error instanceof PinMenuNotSent || error instanceof PinMenuRejected;
      if(retry && this.key() === this.account)this.submitted.delete(pin + ':' + action);
      if(this.current(revision)){const message: string = retry ? PinmonyI18n.message("pm_feedback_was_not_submitted_please_retry_e44cb016") : PinmonyI18n.message("pm_feedback_result_not_confirmed_refresh_to_check_it_will_not_be_re_a6581062");this.store.moreError = message;this.ports.message(message);}
    }
    finally {if(revision === this.revision)this.busy = false;}
  }
  async undoFeedback(): Promise<void> {
    const state: Undo | undefined = this.undo;
    if(!state || state.pin !== this.store.feedbackUndoPin || state.session !== this.store.feedbackUndoSession || state.account !== this.key() || this.store.feedbackUndoBusy || !this.ports.owns(state.pin) || !this.ports.active())return;
    const lock: string = state.pin + ':undo';if(this.submitted.has(lock))return;
    this.pause();this.account = state.account;this.pin = state.pin;this.route = this.ports.route();const revision: number = this.revision;
    const data: Feedback = {pin:this.id(),source:5};if(state.tracking && state.tracking.length <= 16384)data.client_tracking_params = state.tracking;
    this.submitted.add(lock);this.store.feedbackUndoBusy = true;
    try {const r: Resource = await this.request({url:'/v3/pin/' + this.id() + '/feedback/see_more/undo/',data:data},revision,true);
      if(r.code !== 0 || r.endpoint_name !== 'v3_pin_see_more_undo_user_feedback' || r.data?.id !== this.id())throw new Error('unconfirmed');
      if(revision !== this.revision || state.account !== this.key())return;
      this.submitted.delete(lock);this.undo = undefined;this.store.feedbackUndoPin = '';this.ports.message(PinmonyI18n.message("pm_see_more_feedback_undone_6fb3b185"));
    } catch (error) {
      const retry: boolean = error instanceof PinMenuNotSent || error instanceof PinMenuRejected;
      if(retry && state.account === this.key())this.submitted.delete(lock);
      if(revision === this.revision && state.account === this.key())this.ports.message(retry ? PinmonyI18n.message("pm_undo_was_not_submitted_please_retry_d5a531f7") : PinmonyI18n.message("pm_undo_result_not_confirmed_refresh_to_check_it_will_not_be_resubm_4a85600e"));
    }
    finally {if(revision === this.revision)this.store.feedbackUndoBusy = false;}
  }
}
