import { PinmonyBoardFlow } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyBoardContentIdentity {
  page: string; boardId: string; ownerId: string; viewerId: string; canContribute: boolean; intent: number; loadedIds: string[];
}
interface ContentOptions { board_id?: string; name?: string; initial_pins?: string[]; id?: string; field_set_key?: string; client_tracking_params?: string; }
interface ContentEnvelope { options: ContentOptions; context: Record<string,string>; }
interface ContentOwner { id: string; section_count?: number; }
interface ContentData { type?: string; id: string; title?: string; board: ContentOwner; pinner?: ContentOwner; is_repin?: boolean; tracking_params?: string; pin_count?: number | null; }
interface ContentResource { status: string; code?: number; error?: Object; endpoint_name?: string; data: ContentData | null; }
interface ContentResponse { resource_response: ContentResource; client_context?: ContentContext; }
interface ContentContext { user?: ContentOwner; }
export interface PinmonyBoardContentWritePorts {
  state: () => PinmonyBoardFlow | undefined; page: () => string;
  identity: () => PinmonyBoardContentIdentity | undefined;
  session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  changed: (flow: PinmonyBoardFlow) => void;
  confirmed: (action: string, value: string, data: string) => void;
}

// Section creation and verified saved-copy cancellation share the native board write lock.
export class PinmonyBoardContentNativeWrites {
  private readonly ports: PinmonyBoardContentWritePorts;
  private revision: number = 0; private sequence: number = 0; private job: string = ''; private sent: boolean = false;
  private cancelWait: (() => void) | undefined = undefined;
  private displayed: PinmonyBoardFlow | undefined = undefined;
  constructor(ports: PinmonyBoardContentWritePorts) {this.ports = ports;}
  private clone(f: PinmonyBoardFlow): PinmonyBoardFlow {
    return {phase:f.phase,sectionId:f.sectionId,sectionTitle:f.sectionTitle,loading:f.loading,busy:f.busy,uncertain:f.uncertain,
      error:f.error,description:f.description,privacy:f.privacy,recommend:f.recommend,invites:f.invites,requests:f.requests,
      pins:f.pins.slice(),targets:f.targets.slice(),saved:f.saved.slice(),hasMore:f.hasMore};
  }
  private publish(f: PinmonyBoardFlow): void {this.displayed = this.clone(f);this.ports.changed(this.displayed);}
  private unknown(f: PinmonyBoardFlow): void {
    f.busy = false;f.uncertain = true;f.error = '操作结果未确认，请关闭后刷新核对；不会重复提交';this.publish(f);
    PinmonyRuntimeLog.info('BoardContentNative: outcome=unknown');
  }
  pause(): void {
    this.revision++;
    if(this.job)this.ports.network().cancel(this.job);
    this.cancelWait?.();this.cancelWait = undefined;
    if(this.displayed?.busy && this.ports.state() === this.displayed) {
      const f: PinmonyBoardFlow = this.clone(this.displayed);
      if(this.sent)this.unknown(f);else {f.busy = false;this.publish(f);}
    }
    this.job = '';this.sent = false;this.displayed = undefined;
  }
  private async request(job: PinmonyNetworkJob, identity: PinmonyBoardContentIdentity, current: () => boolean): Promise<PinmonyNetworkReply | undefined> {
    this.job = job.id;
    const cancelled: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => {this.cancelWait = (): void => resolve(undefined);});
    try {return await Promise.race([this.ports.network().requestBusinessBoardContent(job,(): PinmonyBusinessSessionContext => this.ports.session(),identity.boardId,identity.viewerId,identity.ownerId,identity.canContribute,identity.loadedIds,current),cancelled]);}
    finally {if(this.job === job.id)this.cancelWait = undefined;}
  }
  private response(reply: PinmonyNetworkReply | undefined, viewer: string): ContentResource {
    if(!reply || reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 6000000)throw new Error('request');
    const body: ContentResponse = JSON.parse(reply.body) as ContentResponse, r: ContentResource = body.resource_response;
    if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 || body.client_context?.user && body.client_context.user.id !== viewer)throw new Error('business');
    return r;
  }
  async submit(action: string, value: string, intentCurrent: () => boolean, initialPins: string[] = []): Promise<string> {
    const original: PinmonyBoardFlow | undefined = this.ports.state(), identity: PinmonyBoardContentIdentity | undefined = this.ports.identity();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(this.job || !original || !identity || !session.authenticated || !session.accountId || original.busy || original.loading || original.uncertain || original.error || original.phase && !(action === 'cancel' && original.phase === 'section') && !(action === 'section' && ['sectionSelect','targets'].includes(original.phase)) || !intentCurrent())return '当前图板操作不可用，请关闭后刷新核对';
    if(initialPins.length > 500 || new Set(initialPins).size !== initialPins.length || !initialPins.every((id: string): boolean => /^\d{1,30}$/.test(id) && !!identity?.loadedIds.includes(id)))return '所选 Pin 已失效，请重新选择';
    if(action === 'section') {if(!identity.canContribute || typeof value !== 'string' || !value.trim() || value.trim().length > 100)return '区块名称或图板权限无效';value = value.trim();}
    else if(action === 'cancel') {if(identity.ownerId !== identity.viewerId || !/^\d{1,30}$/.test(value) || !identity.loadedIds.includes(value))return '收藏校验失败，未执行取消收藏';}
    else return '当前操作不可用';
    const revision: number = this.revision, state: PinmonyBoardFlow = this.clone(original);
    const current = (): boolean => {
      const s: PinmonyBusinessSessionContext = this.ports.session(), actual: PinmonyBoardContentIdentity | undefined = this.ports.identity();
      return revision === this.revision && intentCurrent() && s.authenticated && s.accountId === session.accountId && s.generation === session.generation && s.origin === session.origin &&
        !!actual && actual.page === identity.page && actual.boardId === identity.boardId && actual.ownerId === identity.ownerId && actual.viewerId === identity.viewerId &&
        actual.canContribute === identity.canContribute && actual.intent === identity.intent && this.ports.state() === this.displayed;
    };
    const jobFor = (options: ContentOptions, name: string, verb: string): PinmonyNetworkJob => {
      const source: string = action === 'section' ? '/board/' + identity.boardId + '/create_section/' + (['sectionSelect','targets'].includes(original.phase) ? 'pins/' : '') : '/pin/' + value + '/';
      const envelope: ContentEnvelope = {options:options,context:{}}, form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
      const headers: Record<string,string> = {'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest',
        'X-Pinterest-Pws-Handler':action === 'section' ? 'www/board/[id]/create_section.js' : 'www/pin/[id].js'};
      if(action === 'cancel'){headers['X-Pinterest-AppState'] = 'active';headers['X-Pinterest-Source-Url'] = source;if(session.appVersion)headers['X-App-Version'] = session.appVersion;}
      return {id:'native_board_content_' + (++this.sequence).toString(),epoch:session.generation,page:identity.page,
        url:session.origin + '/resource/' + name + '/' + verb + '/' + (verb === 'get' ? '?' + form + '&_=' + Date.now().toString() : ''),method:verb === 'get' ? 'GET' : 'POST',body:verb === 'get' ? '' : form,headers:headers};
    };
    state.busy = true;this.publish(state);this.sent = false;
    PinmonyRuntimeLog.info('BoardContentNative: start action=' + action);
    let submitted: boolean = false;
    try {
      let options: ContentOptions;
      if(action === 'cancel') {
        const r: ContentResource = this.response(await this.request(jobFor({id:value,field_set_key:'auth_web_main_pin'},'PinResource','get'),identity,current),identity.viewerId);
        if(!current())return '收藏校验已中断，未执行取消收藏';
        const copy: ContentData | null = r.data;
        if(!copy || copy.id !== value || copy.is_repin !== true || copy.pinner?.id !== identity.viewerId || copy.board?.id !== identity.boardId)throw new Error('ownership');
        options = {id:value};
        if(typeof copy.tracking_params === 'string' && copy.tracking_params) {
          if(copy.tracking_params.length > 16384)throw new Error('tracking');options.client_tracking_params = copy.tracking_params + '~0';
        }
      }else options = {board_id:identity.boardId,name:value,initial_pins:initialPins.slice()};
      if(!current())return '操作已中断，未提交';
      submitted = true;this.sent = true;
      const r: ContentResource = this.response(await this.request(jobFor(options,action === 'section' ? 'BoardSectionResource' : 'PinResource',action === 'section' ? 'create' : 'delete'),identity,current),identity.viewerId);
      if(!current())return '操作结果未确认，请关闭后刷新核对；不会重复提交';
      const data: ContentData | null = r.data;
      if(action === 'section') {
        if(!data || data.type !== 'board_section' || !/^\d{1,30}$/.test(data.id) || data.title !== value || data.board?.id !== identity.boardId)throw new Error('section');
      }else if(r.code !== 0 || r.endpoint_name !== 'v3_delete_pin_handler')throw new Error('delete');
      state.busy = false;this.publish(state);this.sent = false;
      PinmonyRuntimeLog.info('BoardContentNative: outcome=confirmed action=' + action);
      this.ports.confirmed(action,value,JSON.stringify(data));return '';
    }catch (_) {
      const uncertain: boolean = submitted;
      if(current()) {if(this.sent)this.unknown(state);else {state.busy = false;this.publish(state);}}
      return uncertain ? '操作结果未确认，请关闭后刷新核对；不会重复提交' : '收藏校验失败或读取中断，未执行取消收藏';
    }finally {if(revision === this.revision){if(this.displayed?.busy && this.ports.state() === this.displayed){if(submitted)this.unknown(state);else {state.busy = false;this.publish(state);}}this.job = '';this.sent = false;this.displayed = undefined;}}
  }
}
