import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore, PinmonyComment, PinmonyCommentResult, PIN_POST_EXTENSIONS_ENABLED } from 'feature_pin';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PIN_BUSINESS_PIN_READ_ENABLED, PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext } from 'common_network';
import { PinmonyDetailNativeReads, NativeCommentData } from './PinmonyDetailNativeReads';
export const PIN_NATIVE_COMMENT_WRITES_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED && PIN_POST_EXTENSIONS_ENABLED;
interface Input { action: string; id?: string; text?: string; imageUri?: string; }
interface Resource { status: string; code?: number; error?: Object; endpoint_name?: string; data: Object | null; }
interface Viewer { id: string; }
interface Client { user?: Viewer; }
interface Response { resource_response: Resource; client_context?: Client; }
interface Base { id: string; aggregated_pin_id?: string; aggregated_pin_data?: Viewer; }
interface CommentWriteData { reaction_type?: number; pin?: string; }
interface Options { force?: boolean; objectId?: string; pinId?: string; tags?: string; text?: string; commentId?: string; url?: string; data?: CommentWriteData | Photo; id?: string; field_set_key?: string; }
interface Envelope { options: Options; context: Record<string,string>; }
interface Photo { details: string; image_signatures: string[]; pin: string; fields: string[]; text_tags: string; }
export interface PinmonyCommentNativePorts {
  store: () => PinmonyPinStore; session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork; reads: () => PinmonyDetailNativeReads;
  readJpeg: (uri: string) => Promise<ArrayBuffer>;
}
export class PinmonyCommentNativeWrites {
  private readonly ports: PinmonyCommentNativePorts;
  private readonly store: PinmonyPinStore;
  private revision: number = 0;
  private sequence: number = 0;
  private pending: boolean = false;
  private token: number = -1;
  private submitted: boolean = false;
  private result: PinmonyCommentResult | undefined = undefined;
  private readonly requests: Set<string> = new Set<string>();
  private readonly waits: Map<string,() => void> = new Map<string,() => void>();
  constructor(ports: PinmonyCommentNativePorts) { this.ports = ports; this.store = ports.store(); }
  pause(): void {
    this.revision++;
    this.requests.forEach((id: string): void => this.ports.network().cancel(id)); this.requests.clear();
    this.waits.forEach((cancel: () => void): void => cancel()); this.waits.clear();
    if (this.pending && this.result && this.store.commentToken === this.token && this.store.commentResult.pin === this.result.pin) {
      this.store.commentResult.busy = false;
      if (this.submitted) { this.store.commentResult.uncertain = true; this.store.commentResult.actionError = PinmonyI18n.message("pm_result_not_confirmed_close_and_reload_to_check_it_will_not_be_re_d952b803"); }
      this.publish();
    }
    this.pending = false; this.submitted = false; this.result = undefined;
  }
  private publish(): void {
    const r: PinmonyCommentResult = this.store.commentResult;
    this.store.commentResult = {pin:r.pin,loading:r.loading,error:r.error,items:r.items.slice(),ended:r.ended,
      busy:r.busy,uncertain:r.uncertain,actionError:r.actionError,mutationVersion:r.mutationVersion};
  }
  private find(id: string): PinmonyComment | undefined {
    for (const item of this.store.commentResult.items) { if (item.id === id) return item; const reply: PinmonyComment | undefined = item.replies?.find((value: PinmonyComment): boolean => value.id === id); if (reply) return reply; }
    return undefined;
  }
  async write(encoded: string, current: () => boolean): Promise<void> { await this.perform(encoded, false, current); }
  async like(id: string, current: () => boolean): Promise<void> { await this.perform(JSON.stringify({ action: 'like', id: id, text: '' }), true, current); }
  private async perform(encoded: string, like: boolean, current: () => boolean): Promise<void> {
    if (!PIN_NATIVE_COMMENT_WRITES_ENABLED || !current() || this.pending || !this.ports.reads().owned()) return;
    const result: PinmonyCommentResult = this.store.commentResult;
    if (result.loading || result.busy || result.uncertain) return;
    let value: Input;
    try { if (encoded.length > 16000) return; value = JSON.parse(encoded) as Input; } catch (_) { return; }
    if (!value || !['create','reply','edit','delete','photo','like'].includes(value.action) || (value.action === 'like') !== like ||
        typeof value.text !== 'string' || value.text.length > 5000 || typeof value.id !== 'string') return;
    const text: string = value.text.trim(), item: PinmonyComment | undefined = this.find(value.id);
    if (!['delete','photo','like'].includes(value.action) && !text) return;
    if (['reply','edit','delete','like'].includes(value.action) && (!item || !/^\d{1,30}$/.test(item.id) ||
        !['aggregatedcomment','userdiditdata'].includes(item.type || ''))) return;
    if (value.action === 'edit' && item?.type !== 'aggregatedcomment') return;
    if (value.action === 'photo' && (!value.imageUri || !/^file:\/\/media\//.test(value.imageUri) || value.id)) return;
    if (value.action === 'create' && value.id) return;
    const session: PinmonyBusinessSessionContext = this.ports.session(), pin: string = result.pin;
    const pinId: string = pin.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/(\d{1,30})\/$/)?.[1] || '';
    const aggregate: string = this.ports.reads().commentAggregate();
    if (!pinId || pin !== session.origin + '/pin/' + pinId + '/' || !/^\d{1,30}$/.test(aggregate) || !session.authenticated) return;
    this.ports.reads().cancelComments();
    const revision: number = ++this.revision, token: number = this.store.commentToken;
    const live = (): boolean => revision === this.revision && current() && this.ports.reads().owned() &&
      token === this.store.commentToken && this.store.commentResult.pin === pin && this.ports.session().authenticated &&
      this.ports.session().accountId === session.accountId && this.ports.session().generation === session.generation &&
      this.ports.session().origin === session.origin;
    this.pending = true; this.submitted = false; this.result = result; this.token = token;
    this.store.commentResult.busy = true; this.store.commentResult.actionError = ''; this.publish();
    let viewer: string = '', confirmed: boolean = false;
    try {
      const base: Response = await this.request('PinResource','get',{id:pinId,field_set_key:'auth_web_main_pin'},pin,session,aggregate,'','',false,live);
      const raw: Base = base.resource_response.data as Base; viewer = base.client_context?.user?.id || '';
      const direct: string = raw?.aggregated_pin_id || '';
      const resolvedAggregate: string = /^\d{1,30}$/.test(direct) ? direct : raw?.aggregated_pin_data?.id || '';
      if (!raw || raw.id !== pinId || !/^\d{1,30}$/.test(viewer) ||
          !!this.ports.reads().commentViewerIdentity() && this.ports.reads().commentViewerIdentity() !== viewer ||
          resolvedAggregate !== aggregate) throw new Error('identity');
      const author: string = item ? this.ports.reads().commentAuthor(item.id) : '';
      if (item && !author || ['edit','delete'].includes(value.action) && author !== viewer) throw new Error('permission');
      let name: string = '', verb: string = 'create', endpoint: string = '', options: Options = {}, signature: string = '';
      const photo: boolean = item?.type === 'userdiditdata';
      if (like) {
        verb = item!.liked ? 'delete' : 'create'; name = 'ApiResource';
        options = {url:photo ? '/v3/did_it/' + item!.id + '/like/' : '/v3/aggregated_comments/' + item!.id + '/react/',data:photo ? {} as CommentWriteData : {reaction_type:1} as CommentWriteData};
        endpoint = photo ? item!.liked ? 'v3_unlike_user_did_it_data' : 'v3_like_user_did_it_data' : item!.liked ? 'v3_delete_reaction_from_comment' : 'v3_add_reaction_to_comment';
      } else if (value.action === 'photo') {
        const bytes: ArrayBuffer = await this.ports.readJpeg(value.imageUri!);
        if (!live()) return;
        const uploadId: string = 'native_comment_upload_' + (++this.sequence).toString();
        const uploadKeys: string[] = [uploadId,uploadId + '_create',uploadId + '_get'];
        uploadKeys.forEach((id: string): void => { this.requests.add(id); });
        const cancelled: Promise<string> = new Promise<string>((resolve): void => { this.waits.set(uploadId,(): void => resolve('')); });
        try {
          signature = await Promise.race([this.ports.network().uploadCommentImage(bytes,pin,(): PinmonyNetworkContext => ({
            authenticated:live(),epoch:session.generation,page:pin,userAgent:this.ports.session().userAgent
          }),uploadId),cancelled]);
        } finally { uploadKeys.forEach((id: string): void => { this.requests.delete(id); }); this.waits.delete(uploadId); }
        if (!live() || !/^[a-f0-9]{32}$/.test(signature)) throw new Error('upload');
        const data: Photo = {details:text,image_signatures:[signature],pin:pinId,text_tags:'[]',fields:[
          'pin.id','user.id','user.full_name','user.username','user.image_medium_url','userdiditdata.id','userdiditdata.type',
          'userdiditdata.details','userdiditdata.user()','userdiditdata.images[150x150,200x,736x,750x]','userdiditdata.pin()',
          'userdiditdata.image_signatures','userdiditdata.like_count','userdiditdata.liked_by_me','userdiditdata.comment_count','userdiditdata.done_at']};
        name = 'ApiResource'; options = {url:'/v3/did_it/',data:data}; endpoint = 'v3_create_user_did_it_data';
      } else if (value.action === 'create' || value.action === 'reply') {
        name = value.action === 'create' ? 'AggregatedCommentResource' : photo ? 'DidItCommentsResource' : 'AggregatedCommentReplyResource';
        endpoint = value.action === 'create' ? 'v3_create_aggregated_pin_data_comment' : photo ? 'v3_create_user_did_it_data_comment' : 'v3_create_aggregated_comment_reply';
        options = {force:false,objectId:item ? item.id : aggregate,pinId:pinId,tags:'[]',text:text};
      } else if (value.action === 'edit') {
        name = 'AggregatedCommentResource'; verb = 'update'; endpoint = 'v3_update_aggregated_comment';
        options = {commentId:item!.id,force:false,tags:'[]',text:text};
      } else {
        name = photo ? 'ApiResource' : 'AggregatedCommentResource'; verb = 'delete';
        endpoint = photo ? 'v3_delete_user_did_it_data' : 'v3_delete_aggregated_comment';
        options = photo ? {url:'/v3/did_it/' + item!.id + '/',data:{pin:pinId} as CommentWriteData} as Options : {commentId:item!.id} as Options;
      }
      if (!live()) return;
      this.submitted = true;
      const response: Response = await this.request(name,verb,options,pin,session,aggregate,viewer,item?.id || '',!!item && author === viewer,live);
      const r: Resource = response.resource_response, data: NativeCommentData | null = r.data as NativeCommentData | null;
      if (r.code !== 0 || r.endpoint_name !== endpoint) throw new Error('unconfirmed');
      if (like) {
        if (photo ? data !== null : !data || data.id !== item!.id) throw new Error('unconfirmed');
      } else if (value.action === 'delete') {
        if (photo ? !data || data.id !== aggregate : data !== null) throw new Error('unconfirmed');
        this.store.commentResult.items = this.store.commentResult.items.filter((row: PinmonyComment): boolean => {
          row.replies = row.replies?.filter((reply: PinmonyComment): boolean => reply.id !== item!.id); return row.id !== item!.id;
        });
      } else {
        if (!data || !/^\d{1,30}$/.test(data.id) || data.user?.id !== viewer ||
            (value.action === 'photo' ? data.details : data.text)?.trim() !== text ||
            value.action === 'edit' && data.id !== item!.id ||
            (value.action === 'photo' ? data.type !== 'userdiditdata' || data.pin?.id !== pinId || !data.image_signatures?.includes(signature) : data.type !== 'aggregatedcomment')) throw new Error('unconfirmed');
        const mapped: PinmonyComment | undefined = this.ports.reads().mapWrittenComment(data,viewer);
        if (!mapped) throw new Error('unconfirmed');
        if (value.action === 'reply') { item!.replies = (item!.replies || []).concat([mapped]); item!.repliesOpen = true; }
        else if (value.action === 'edit') {
          item!.text = mapped.text; item!.translatedText = ''; item!.translationVisible = false; item!.translationError = '';
        }
        else this.store.commentResult.items.unshift(mapped);
      }
      confirmed = true; this.submitted = false;
      if (!like) this.store.commentResult.mutationVersion = (this.store.commentResult.mutationVersion || 0) + 1;
      this.store.detailCache.remove(pinId);
      this.publish();
      const parent: PinmonyComment | undefined = item ? this.store.commentResult.items.find((row: PinmonyComment): boolean => !!row.replies?.includes(item!)) : undefined;
      if (parent && like || value.action === 'reply') {
        const target: PinmonyComment = parent || item!;
        target.repliesOpen = false;
        await this.ports.reads().readReplies(target.id,live,true);
      } else await this.ports.reads().readComments(false,live);
    } catch (_) {
      if (live()) {
        if (this.submitted && !confirmed) this.store.commentResult.uncertain = true;
        this.store.commentResult.actionError = this.submitted && !confirmed ? PinmonyI18n.message("pm_result_not_confirmed_close_and_reload_to_check_it_will_not_be_re_d952b803") :
          value.action === 'photo' ? PinmonyI18n.message("pm_image_upload_or_comment_preparation_incomplete_the_comment_has_n_c87c853f") : PinmonyI18n.message("pm_unable_to_prepare_comment_action_reload_to_retry_19845ac7");
      }
    } finally {
      if (revision === this.revision) {
        this.pending = false; this.submitted = false; this.result = undefined;
        if (live()) { this.store.commentResult.busy = false; this.publish(); }
      }
    }
  }
  private async request(name: string, verb: string, options: Options, pin: string, session: PinmonyBusinessSessionContext,
    aggregate: string, viewer: string, comment: string, own: boolean, current: () => boolean): Promise<Response> {
    if (!current()) throw new Error('stale');
    const source: string = pin.slice(session.origin.length), envelope: Envelope = {options:options,context:{}};
    const body: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const headers: Record<string,string> = {'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest',
      'X-Pinterest-AppState':'active','X-Pinterest-Source-Url':source,'X-Pinterest-Pws-Handler':'www/pin/[id].js'};
    if (session.appVersion) headers['X-App-Version'] = session.appVersion;
    const job: PinmonyNetworkJob = {id:'native_comment_write_' + (++this.sequence).toString(),epoch:session.generation,page:pin,method:verb === 'get' ? 'GET' : 'POST',
      url:session.origin + '/resource/' + name + '/' + verb + '/' + (verb === 'get' ? '?' + body + '&_=' + Date.now().toString() : ''),body:verb === 'get' ? '' : body,headers:headers};
    this.requests.add(job.id);
    const cancelled: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => { this.waits.set(job.id,(): void => resolve(undefined)); });
    let reply: PinmonyNetworkReply | undefined;
    try { reply = await Promise.race([this.ports.network().requestBusinessCommentWrite(job,(): PinmonyBusinessSessionContext => this.ports.session(),pin,aggregate,viewer,comment,own,current),cancelled]); }
    finally { this.requests.delete(job.id); this.waits.delete(job.id); }
    if (!current() || !reply || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 2000000) throw new Error('request');
    const response: Response = JSON.parse(reply.body) as Response, r: Resource = response.resource_response;
    if (!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 ||
        viewer && response.client_context?.user?.id !== undefined && response.client_context.user.id !== viewer) throw new Error('response');
    return response;
  }
}
