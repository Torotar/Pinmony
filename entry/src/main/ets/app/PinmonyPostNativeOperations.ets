import { PinmonyI18n } from 'common_foundation';
import { PIN_PROFILE_ORGANIZE_ENABLED } from 'feature_profile';
import { PinmonyPinStore, PinmonySaveResult, PinmonySaveBoard, PinmonyEditPinResult, PinmonyDetailAction, PinmonyDetailSnapshot, PIN_POST_API_ENABLED, PIN_POST_EXTENSIONS_ENABLED, PIN_EDIT_API_ENABLED } from 'feature_pin';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
export const PIN_NATIVE_POST_OPERATIONS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED && PIN_POST_API_ENABLED;
interface Owner { id: string; }
interface PinBoard { id: string; name?: string; privacy?: string; layout?: string; }
interface Reaction { reaction_by_me?: number; reaction_counts?: Record<string,number>; }
interface Art { url: string; }
interface NativePin { id: string; pinner?: Owner; board?: PinBoard; is_repin?: boolean; title?: string; description?: string;
  tracking_params?: string; client_tracking_params?: string; reaction_by_me?: number; reaction_data?: Reaction;
  ai_disclosures?: number[]; images?: Record<string,Art>; }
interface NativeBoard { id: string; name: string; privacy?: string; image_cover_url?: string; image_cover_hd_url?: string; access?: string[]; owner?: Owner; }
interface PickerData { all_boards: NativeBoard[]; boards_shortlist: NativeBoard[]; }
interface Resource { status: string; code?: number; endpoint_name?: string; error?: Object; data: Object | null; }
interface Response { resource_response: Resource; client_context?: Context; }
interface Context { user?: Owner; }
interface GraphOwner { entityId: string; }
interface GraphBoard { entityId: string; name: string; imageCoverUrl?: string; }
interface Suggestion { title: string; }
interface GraphPin { entityId?: string; id?: string; pinner?: GraphOwner; board?: GraphBoard; aiDisclosures?: number[];
  section?: GraphOwner; trackingParams?: string; boardTitleSuggestions?: Suggestion[]; }
interface GraphData { v3GetPinQueryv2?: GraphPinData; }
interface GraphPinData { data?: GraphPin; }
interface GraphResponse { data?: GraphData; errors?: Object; }
interface Options { id?: string; pin_id?: string; user_id?: string; board_id?: string; field_set_key?: string; shortlist_length?: number; shortlist_suggestions?: number;
  clientTrackingParams?: string; client_tracking_params?: string; name?: string; privacy?: string; initial_pin_client_tracking_params?: string[];
  board_section_id?: string; ai_disclosures?: number[]; title?: string; description?: string; url?: string; data?: ReactionWrite; }
interface ReactionWrite { client_tracking_params: string; reaction_type: number; }
interface Envelope { options: Options; context: Record<string,string>; }
interface GraphEnvelope { queryHash: string; variables: GraphVariables; }
interface GraphVariables { pinId: string; }
interface SaveCopy { id: string; board: string; boardId: string; viewer: string; scope: string; }
export interface PinmonyPostNativePorts {
  store: () => PinmonyPinStore; session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  active?: () => boolean; originToken?: () => string;
  owns: (pin: string) => boolean; sheet: () => string; show: (kind: string) => void;
  saved?: (pin: string, copy: string, message: string) => void;
  dismissed?: () => void;
  feedback: (message: string) => void; committed: (action: string, pin: string) => void;
}

// Mutations use only account/Pin/panel ownership; the Cookie adapter remains in native transport.
export class PinmonyPostNativeOperations {
  private readonly ports: PinmonyPostNativePorts; private readonly store: PinmonyPinStore;
  private account: string = ''; private revision: number = 0; private sequence: number = 0;
  private pin: string = ''; private mode: string = ''; private viewer: string = ''; private raw: NativePin | undefined = undefined;
  private verifiedCopy: string = ''; private initialBoard: string = ''; private section: string = ''; private disclosures: number[] = []; private tracking: string = '';
  private busy: boolean = false; private sent: boolean = false; private token: number = 0;
  private readonly requests: Set<string> = new Set<string>(); private readonly waits: Map<string,() => void> = new Map<string,() => void>();
  private readonly saved: Map<string,SaveCopy> = new Map<string,SaveCopy>(); private readonly liked: Set<string> = new Set<string>();
  private readonly uncertainLikes: Set<string> = new Set<string>();
  private readonly uncertainCancels: Set<string> = new Set<string>();
  private readonly edited: Map<string,NativePin> = new Map<string,NativePin>();
  constructor(ports: PinmonyPostNativePorts) {this.ports = ports;this.store = ports.store();}
  private id(pin: string = this.pin): string {return pin.match(/\/pin\/(\d{1,30})\/$/)?.[1] || '';}
  private digits(id: string | undefined): boolean {return typeof id === 'string' && /^\d{1,30}$/.test(id);}
  private image(value: string | undefined): string {return typeof value === 'string' && value.length <= 2048 && /^https:\/\/i\.pinimg\.com\//.test(value) ? value : '';}
  private key(): string {const s: PinmonyBusinessSessionContext = this.ports.session();return s.authenticated ? s.accountId + ':' + s.generation.toString() + ':' + s.origin : '';}
  private sync(): boolean {
    const key: string = this.key();if(key !== this.account){this.pause();this.account = key;this.saved.clear();this.liked.clear();this.edited.clear();this.uncertainLikes.clear();this.uncertainCancels.clear();this.mode = '';this.raw = undefined;}
    return !!key && this.ports.session().authenticated;
  }
  private publish(): void {
    if(this.mode === 'save')this.store.saveResult = JSON.parse(JSON.stringify(this.store.saveResult)) as PinmonySaveResult;
    if(this.mode === 'edit')this.store.editResult = JSON.parse(JSON.stringify(this.store.editResult)) as PinmonyEditPinResult;
  }
  private fail(message: string, uncertain: boolean): void {
    if(this.mode === 'save'){this.store.saveResult.loading = false;this.store.saveResult.busy = false;this.store.saveResult.error = message;}
    else if(this.mode === 'edit'){this.store.editResult.loading = false;this.store.editResult.busy = false;this.store.editResult.picker.loading = false;this.store.editResult.picker.busy = false;this.store.editResult.error = message;this.store.editResult.uncertain = uncertain;}
    this.publish();
  }
  private markUnknown(): void {
    if(!this.sent || this.key() !== this.account)return;
    if(this.mode === 'like')this.uncertainLikes.add(this.id());
    if(this.mode === 'cancel')this.uncertainCancels.add(this.id());
    if(this.mode === 'like' || this.mode === 'cancel')this.apply();
  }
  likeBlocked(pin: string): boolean {return this.key() === this.account && this.uncertainLikes.has(this.id(pin));}
  observe(pin: string, body: string): void {
    if(!PIN_NATIVE_POST_OPERATIONS_ENABLED || !this.ports.owns(pin) || !this.sync())return;
    try {
      const r: Resource = (JSON.parse(body) as Response).resource_response, p: NativePin = r?.data as NativePin;
      if(r?.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 || p?.id !== this.id(pin))return;
      const reaction: number | undefined = p.reaction_data?.reaction_by_me === undefined ? p.reaction_by_me : p.reaction_data.reaction_by_me;
      if(reaction === 1){this.liked.add(p.id);this.uncertainLikes.delete(p.id);}
      this.apply();
    }catch (_) {}
  }
  pause(): void {
    if(!PIN_NATIVE_POST_OPERATIONS_ENABLED)return;
    this.markUnknown();
    this.revision++;this.requests.forEach((id: string): void => this.ports.network().cancel(id));this.requests.clear();
    this.waits.forEach((cancel: () => void): void => cancel());this.waits.clear();
    if(this.busy){this.fail(this.sent ? '操作结果未确认，请关闭后重新读取核对；不会重复提交' : PinmonyI18n.message("pm_loading_interrupted_please_reload_67acc483"),this.sent);}
    this.busy = false;this.sent = false;this.store.viewerSaveBusy = false;
  }
  private valid(revision: number): boolean {
    return revision === this.revision && this.key() === this.account && (this.ports.owns(this.pin) || this.mode === 'cancel' && this.owns(this.pin)) &&
      (this.mode === 'like' || this.mode === 'cancel' || this.ports.sheet() === this.mode && this.token === (this.mode === 'save' ? this.store.saveToken : this.store.editToken));
  }
  private begin(mode: string, pin: string): boolean {
    if(!PIN_NATIVE_POST_OPERATIONS_ENABLED || this.busy || !this.sync() || !this.id(pin) || !pin.startsWith(this.ports.session().origin + '/pin/') || !(this.ports.owns(pin) || mode === 'cancel' && this.owns(pin)))return false;
    this.pause();this.pin = pin;this.mode = mode;this.viewer = '';this.raw = undefined;this.verifiedCopy = '';this.initialBoard = '';this.section = '';this.disclosures = [];this.tracking = '';
    this.token = mode === 'save' ? ++this.store.saveToken : mode === 'edit' ? ++this.store.editToken : this.revision;
    if(mode === 'save' || mode === 'edit')this.ports.show(mode);return true;
  }
  private emptyPicker(): PinmonySaveResult {return {pin:this.pin,loading:false,busy:false,error:'',feedback:'',items:[],shortlist:[],savedId:'',savedBoard:'',suggestions:[]};}
  private picker(): PinmonySaveResult {return this.mode === 'edit' ? this.store.editResult.picker : this.store.saveResult;}
  private allowed(): string[] {const p: PinmonySaveResult = this.picker();const ids: string[] = p.items.concat(p.shortlist).filter((b: PinmonySaveBoard): boolean => b.enabled && (this.digits(b.id) || this.mode === 'save' && b.id === 'profile-quick-saves')).map((b: PinmonySaveBoard): string => b.id);if(this.mode === 'edit' && this.digits(this.initialBoard))ids.push(this.initialBoard);return ids;}
  private async request(name: string, verb: string, options: Options, revision: number, graph: string = ''): Promise<Resource | GraphData> {
    if(!this.valid(revision))throw new Error('stale');
    const s: PinmonyBusinessSessionContext = this.ports.session(), source: string = name === 'BoardResource' ? '/board/create/' + this.id() : name === 'BoardPickerBoardsResource' ? '/pin/' + this.id() + '/repin/' : '/pin/' + this.id() + '/';
    const envelope: Envelope = {options:options,context:{}}, form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const headers: Record<string,string> = {'Accept':'application/json','Content-Type':graph ? 'application/json' : 'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active','X-Pinterest-Source-Url':source,
      'X-Pinterest-Pws-Handler':name === 'BoardPickerBoardsResource' ? 'www/pin/[id]/repin.js' : 'www/pin/[id].js'};
    if(s.appVersion)headers['X-App-Version'] = s.appVersion;
    const query: GraphEnvelope = {queryHash:graph,variables:{pinId:this.id()}};
    const job: PinmonyNetworkJob = {id:'native_post_' + (++this.sequence).toString(),epoch:s.generation,page:this.pin,url:s.origin + (graph ? '/_/graphql/' : '/resource/' + name + '/' + verb + '/' + (verb === 'get' ? '?' + form + '&_=' + Date.now().toString() : '')),
      method:graph || verb !== 'get' ? 'POST' : 'GET',body:graph ? JSON.stringify(query) : verb === 'get' ? '' : form,headers:headers};
    const cancel: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => {this.waits.set(job.id,(): void => resolve(undefined));});
    this.requests.add(job.id);
    let reply: PinmonyNetworkReply | undefined;
    try {reply = await Promise.race([this.ports.network().requestBusinessPost(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.pin,this.viewer,this.allowed(),this.raw?.pinner?.id === this.viewer && !!this.viewer,this.raw?.is_repin === false,
      this.saved.get(this.id())?.id || this.store.confirmedSaves.copyId(this.id()),!!this.verifiedCopy,(): boolean => this.valid(revision)),cancel]);}
    finally {this.requests.delete(job.id);this.waits.delete(job.id);}
    if(!this.valid(revision))throw new Error('stale');
    if(!reply || reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 6000000)throw new Error('request');
    if(graph){const body: GraphResponse = JSON.parse(reply.body) as GraphResponse;if(body.errors || !body.data)throw new Error('graph');return body.data;}
    const body: Response = JSON.parse(reply.body) as Response, r: Resource = body.resource_response;
    const viewer: string | undefined = body.client_context?.user?.id;
    if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 || viewer !== undefined && (!this.digits(viewer) || !!this.viewer && viewer !== this.viewer))throw new Error('resource');
    if(!this.viewer){if(!this.digits(viewer))throw new Error('viewer');this.viewer = viewer!;}return r;
  }
  private async base(revision: number): Promise<NativePin> {
    const r: Resource = await this.request('PinResource','get',{id:this.id(),field_set_key:'auth_web_main_pin'},revision) as Resource;
    const p: NativePin = r.data as NativePin;if(!p || p.id !== this.id())throw new Error('pin');this.raw = p;
    if(p.pinner?.id === this.viewer && p.is_repin === true && this.digits(p.board?.id) && !this.store.confirmedSaves.known(p.id))this.store.confirmedSaves.confirm(p.id,true);
    this.apply();return p;
  }
  private board(b: NativeBoard): PinmonySaveBoard {
    if(!b || !this.digits(b.id) || typeof b.name !== 'string')throw new Error('board');
    return {id:b.id,name:b.name.trim().slice(0,300),imageUrl:this.image(b.image_cover_url || b.image_cover_hd_url),secret:b.privacy === 'secret',enabled:Array.isArray(b.access) && b.access.includes('write')};
  }
  private async loadPicker(revision: number): Promise<void> {
    this.picker().loading = true;this.picker().error = '';this.publish();
    const r: Resource = await this.request('BoardPickerBoardsResource','get',{pin_id:this.id(),field_set_key:'profile_grid_item',shortlist_length:2,shortlist_suggestions:3,user_id:this.viewer},revision) as Resource;
    const d: PickerData = r.data as PickerData;if(!d || !Array.isArray(d.all_boards) || !Array.isArray(d.boards_shortlist) || d.all_boards.length > 2000 || d.boards_shortlist.length > 2000)throw new Error('picker');
    const p: PinmonySaveResult = this.picker();p.items = d.all_boards.map((b: NativeBoard): PinmonySaveBoard => this.board(b));p.shortlist = d.boards_shortlist.map((b: NativeBoard): PinmonySaveBoard => this.board(b));
    if(this.mode === 'save' && PIN_PROFILE_ORGANIZE_ENABLED)p.items.push({id:'profile-quick-saves',name:'个人资料',imageUrl:'',enabled:true,secret:false});
    p.loading = false;this.publish();
  }
  async openSave(pin: string): Promise<void> {
    if(!PIN_POST_EXTENSIONS_ENABLED || !this.begin('save',pin))return;this.store.saveCreating = false;this.store.saveResult = this.emptyPicker();this.store.saveResult.loading = true;this.publish();
    const revision: number = this.revision;this.busy = true;
    try {await this.base(revision);await this.loadPicker(revision);const stored: SaveCopy | undefined = this.saved.get(this.id());if(stored){this.store.saveResult.savedId = stored.id;this.store.saveResult.savedBoard = stored.board;}
      this.publish();this.busy = false;
      try {const g: GraphData = await this.request('','',{},revision,'22ab0618812233f56510dbaeb1d76e342780a08cabb50624896db33300f9070e') as GraphData;const p: GraphPin | undefined = g.v3GetPinQueryv2?.data;
        // The persisted query returns Relay Pin identity; a local encoder is supplied without credentials.
        if(p?.id === this.relay(this.id()) && Array.isArray(p.boardTitleSuggestions) && p.boardTitleSuggestions.length <= 100)this.store.saveResult.suggestions = p.boardTitleSuggestions.map((v: Suggestion): string => typeof v.title === 'string' ? v.title.trim().slice(0,300) : '').filter((v: string): boolean => !!v);this.publish();}catch (_) {}
    }catch (_) {if(this.valid(revision))this.fail(PinmonyI18n.message("pm_unable_to_load_boards_please_reload_6b4b6f3e"),false);}finally {if(revision === this.revision && !this.store.saveResult.busy)this.busy = false;}
  }
  private relay(id: string): string {
    const input: string = 'Pin:' + id, alphabet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';let out: string = '';
    for(let i: number = 0;i < input.length;i += 3){const a: number = input.charCodeAt(i), b: number = input.charCodeAt(i + 1), c: number = input.charCodeAt(i + 2);out += alphabet[a >> 2] + alphabet[((a & 3) << 4) | (Number.isNaN(b) ? 0 : b >> 4)] + (Number.isNaN(b) ? '=' : alphabet[((b & 15) << 2) | (Number.isNaN(c) ? 0 : c >> 6)]) + (Number.isNaN(c) ? '=' : alphabet[c & 63]);}return out;
  }
  async openEdit(pin: string): Promise<void> {
    if(!PIN_EDIT_API_ENABLED || !this.begin('edit',pin))return;this.store.saveCreating = false;
    this.store.editResult = {pin:pin,loading:true,busy:false,error:'',phase:'edit',imageUrl:'',title:'',description:'',editableContent:false,ai:false,uncertain:false,done:'',board:{id:'',name:'',imageUrl:'',enabled:false,secret:false},picker:this.emptyPicker()};
    const revision: number = this.revision;this.busy = true;
    try {const raw: NativePin = await this.base(revision);if(raw.pinner?.id !== this.viewer)throw new Error('owner');
      const g: GraphData = await this.request('','',{},revision,'b275f25a3893b0cf502a06e2f634402774be2a3d3b23199b141d4223174d39df') as GraphData,p: GraphPin | undefined = g.v3GetPinQueryv2?.data;
      if(!p || p.entityId !== this.id() || p.pinner?.entityId !== this.viewer || !this.digits(p.board?.entityId) || !Array.isArray(p.aiDisclosures) || p.aiDisclosures.length > 100 || !p.aiDisclosures.every((v: number): boolean => Number.isInteger(v)))throw new Error('graph-owner');
      this.initialBoard = p.board!.entityId;this.section = p.section?.entityId || '';if(this.section && !this.digits(this.section))throw new Error('section');this.disclosures = p.aiDisclosures.slice();this.tracking = p.trackingParams || raw.tracking_params || '';if(this.tracking.length > 16384)throw new Error('tracking');
      const edit: PinmonyEditPinResult = this.store.editResult;edit.loading = false;edit.editableContent = raw.is_repin === false;edit.title = typeof raw.title === 'string' ? raw.title.slice(0,10000) : '';edit.description = typeof raw.description === 'string' ? raw.description.slice(0,10000) : '';
      edit.board = {id:this.initialBoard,name:(p.board!.name || '').slice(0,300),imageUrl:this.image(p.board!.imageCoverUrl),secret:raw.board?.privacy === 'secret',enabled:true};edit.ai = this.disclosures.includes(1);edit.imageUrl = this.image(raw.images?.['736x']?.url || raw.images?.['474x']?.url || raw.images?.orig?.url);this.publish();
    }catch (_) {if(this.valid(revision))this.fail(PinmonyI18n.message("pm_account_editing_details_not_confirmed_please_reload_6061ba9a"),false);}finally {if(revision === this.revision)this.busy = false;}
  }
  private args(encoded: string): (string | boolean)[] {try {const value: (string | boolean)[] = JSON.parse('[' + encoded.replace(/^,/,'') + ']') as (string | boolean)[];return Array.isArray(value) ? value : [];}catch (_) {return [];}}
  private lock(value: boolean): void {if(this.mode === 'save')this.store.saveResult.busy = value;else if(this.mode === 'edit')this.store.editResult.busy = value;this.publish();}
  private async repin(boardId: string, revision: number): Promise<void> {
    const b: PinmonySaveBoard | undefined = this.picker().items.concat(this.picker().shortlist).find((b: PinmonySaveBoard): boolean => b.id === boardId && b.enabled);if(!b)throw new Error('target');
    const o: Options = {pin_id:this.id(),user_id:this.viewer};if(boardId !== 'profile-quick-saves')o.board_id = boardId;
    const tracking: string | undefined = this.raw?.client_tracking_params || this.raw?.tracking_params;if(tracking){if(tracking.length > 16384)throw new Error('tracking');o.clientTrackingParams = tracking;}
    this.sent = true;const r: Resource = await this.request('RepinResource','create',o,revision) as Resource,p: NativePin = r.data as NativePin;
    if(r.code !== 0 || r.endpoint_name !== 'v3_repin_handler' || !p || !this.digits(p.id) || p.id === this.id() || p.pinner?.id !== this.viewer || p.is_repin !== true || !this.digits(p.board?.id) ||
      (boardId === 'profile-quick-saves' ? p.board?.layout !== 'quick_saves' : p.board?.id !== boardId))throw new Error('copy');
    this.sent = false;this.saved.set(this.id(),{id:p.id,board:b.name,boardId:p.board!.id,viewer:this.viewer,scope:this.ports.originToken?.() || ''});this.store.confirmedSaves.confirm(this.id(),true,p.id);this.apply();
    this.store.saveResult.savedId = p.id;this.store.saveResult.savedBoard = b.name;this.store.saveResult.feedback = PinmonyI18n.message("pm_saved_to_b75786b2") + b.name + '”';this.ports.committed('save',this.pin);
  }
  async saveAction(method: string, encoded: string = ''): Promise<void> {
    if(this.mode !== 'save' && !(this.mode === 'edit' && method === 'boardsCreate') || this.busy || !this.valid(this.revision) || this.picker().loading || this.picker().busy || this.picker().error || this.store.editResult.uncertain && this.mode === 'edit')return;
    const a: (string | boolean)[] = this.args(encoded), revision: number = this.revision;if(!['boardsSave','boardsCreate','boardsRemove'].includes(method))return;
    if(this.mode === 'edit' && this.store.editResult.phase !== 'boards')return;
    if(method === 'boardsSave' && (typeof a[0] !== 'string' || !this.picker().items.concat(this.picker().shortlist).some((b: PinmonySaveBoard): boolean => b.enabled && b.id === a[0])))return;
    if(method === 'boardsCreate' && (typeof a[0] !== 'string' || !a[0].trim() || a[0].trim().length > 300 || typeof a[1] !== 'boolean'))return;
    this.busy = true;this.lock(true);this.sent = false;
    try {
      if(method === 'boardsCreate') {
        const name: string = (a[0] as string).trim(), o: Options = {name:name,privacy:a[1] ? 'secret' : 'public'}, tracking: string | undefined = this.raw?.client_tracking_params || this.raw?.tracking_params;
        if(tracking){if(tracking.length > 16384)throw new Error('tracking');o.initial_pin_client_tracking_params = [tracking];}
        this.sent = true;const r: Resource = await this.request('BoardResource','create',o,revision) as Resource,b: NativeBoard = r.data as NativeBoard;
        if(r.code !== 0 || r.endpoint_name !== 'v3_create_board' || !b || b.name !== name || b.privacy !== o.privacy || b.owner?.id !== undefined && b.owner.id !== this.viewer)throw new Error('create');
        const mapped: PinmonySaveBoard = this.board(b);this.sent = false;this.picker().items.push(mapped);this.ports.committed('create-board',this.pin);
        if(this.mode === 'edit'){this.store.editResult.board = mapped;this.store.editResult.phase = 'edit';this.store.saveCreating = false;return;}
        await this.repin(mapped.id,revision);
      }else if(method === 'boardsSave')await this.repin(a[0] as string,revision);
      else {await this.removeCopy(revision);return;}
      const feedback: string = this.store.saveResult.feedback;this.lock(false);this.busy = false;const savedPin: string = this.pin, copy: string = this.store.saveResult.savedId;this.dismiss('save');if(this.ports.saved)this.ports.saved(savedPin,copy,feedback);else this.ports.feedback(feedback);
    }catch (_) {if(this.valid(revision))this.fail(this.sent ? '收藏操作结果未确认，请关闭后重新读取核对；不会重复提交' : PinmonyI18n.message("pm_action_not_submitted_or_loading_failed_check_before_retrying_93362fa3"),this.sent);}
    finally {if(revision === this.revision){if(this.sent && this.key() === this.account)this.fail(PinmonyI18n.message("pm_result_not_confirmed_close_and_reload_to_check_it_will_not_be_re_d952b803"),true);this.busy = false;this.sent = false;this.lock(false);}}
  }
  private async removeCopy(revision: number): Promise<void> {
    const stored: SaveCopy | undefined = this.saved.get(this.id());
    const mapped: string = stored?.id || this.store.confirmedSaves.copyId(this.id());
    const ownSaved: boolean = !mapped && this.raw?.id === this.id() && this.raw.pinner?.id === this.viewer && this.raw.is_repin === true && this.digits(this.raw.board?.id);
    const copy: string = ownSaved ? this.id() : mapped;
    if(!this.digits(copy) || !ownSaved && copy === this.id())throw new Error('copy');
    let p: NativePin;
    if(ownSaved)p = this.raw!;
    else {const r: Resource = await this.request('PinResource','get',{id:copy,field_set_key:'auth_web_main_pin'},revision) as Resource;p = r.data as NativePin;}
    if(!p || p.id !== copy || p.pinner?.id !== this.viewer || p.is_repin !== true || !this.digits(p.board?.id) || stored && p.board?.id !== stored.boardId)throw new Error('copy-owner');
    this.verifiedCopy = ownSaved ? '' : copy;const options: Options = {id:copy}, tracking: string | undefined = ownSaved ? p.tracking_params : p.client_tracking_params || p.tracking_params;
    if(tracking){if(tracking.length > 16384)throw new Error('tracking');options.client_tracking_params = ownSaved ? tracking + '~0' : tracking;}
    this.sent = true;const removed: Resource = await this.request('PinResource','delete',options,revision) as Resource;if(removed.code !== 0 || removed.endpoint_name !== 'v3_delete_pin_handler')throw new Error('remove');
    this.sent = false;this.saved.delete(this.id());if(this.store.saveUndoPin === this.pin){this.store.saveUndoPin = '';this.store.saveUndoId = '';}this.store.confirmedSaves.confirm(this.id(),false);this.apply();this.ports.committed('remove-save',this.pin);this.ports.feedback(ownSaved ? '已取消收藏' : PinmonyI18n.message("pm_save_undone_7d8baadf"));
    this.store.saveResult.savedId = '';this.store.saveResult.savedBoard = '';this.store.saveResult.feedback = PinmonyI18n.message("pm_save_undone_7d8baadf");this.publish();
  }
  async cancelSave(pin: string): Promise<void> {
    if(!this.sync())return;
    if(this.uncertainCancels.has(this.id(pin))){this.ports.feedback(PinmonyI18n.message("pm_unsave_result_not_confirmed_reload_to_check_before_submitting_ag_aba92f81"));return;}
    if(!PIN_POST_EXTENSIONS_ENABLED || !this.begin('cancel',pin))return;const revision: number = this.revision;this.busy = true;this.store.viewerSaveBusy = true;
    try {await this.base(revision);await this.removeCopy(revision);}catch (_) {if(revision === this.revision)this.markUnknown();if(this.valid(revision))this.ports.feedback(this.sent ? '取消收藏结果未确认，请重新读取核对；不会重复提交' : PinmonyI18n.message("pm_saved_copy_verification_failed_nothing_was_unsaved_f0d571ad"));}
    finally {if(revision === this.revision){this.busy = false;this.sent = false;this.store.viewerSaveBusy = false;}}
  }
  owns(pin: string): boolean {
    const stored: SaveCopy | undefined = this.saved.get(this.id(pin));
    return PIN_NATIVE_POST_OPERATIONS_ENABLED && this.key() === this.account && this.ports.active?.() !== false &&
      (this.ports.owns(pin) || !!stored?.scope && stored.scope === this.ports.originToken?.() && this.store.saveUndoPin === pin && this.store.saveUndoId === stored.id);
  }
  ready(): boolean {return PIN_NATIVE_POST_OPERATIONS_ENABLED && this.ports.session().authenticated && !!this.store.detail && this.ports.owns(this.store.detail.pinUrl) && this.store.detailNativeReadsReady;}
  async detailAction(kind: string): Promise<boolean> {
    if(!PIN_NATIVE_POST_OPERATIONS_ENABLED || !['like','save'].includes(kind))return false;
    const pin: string = this.store.detail?.pinUrl || '';if(!this.ports.owns(pin) || this.busy)return true;
    if(kind === 'like')await this.like(pin);
    else if(this.store.confirmedSaves.isSaved(this.id(pin)) || this.store.detail?.actions.some((a: PinmonyDetailAction): boolean => a.kind === 'save' && a.selected))await this.cancelSave(pin);else await this.openSave(pin);
    return true;
  }
  async like(pin: string): Promise<void> {
    if(!this.sync())return;
    if(this.likeBlocked(pin)){this.ports.feedback(PinmonyI18n.message("pm_like_result_not_confirmed_refresh_to_check_before_submitting_aga_35091826"));return;}
    if(!this.begin('like',pin))return;const revision: number = this.revision;this.busy = true;
    try {const raw: NativePin = await this.base(revision), reaction: number | undefined = raw.reaction_data?.reaction_by_me === undefined ? raw.reaction_by_me : raw.reaction_data.reaction_by_me;
      if(reaction === 1 || this.liked.has(this.id())){this.liked.add(this.id());this.apply();return;}
      if(reaction !== 0 || !raw.tracking_params || raw.tracking_params.length > 16384)throw new Error('reaction');
      this.sent = true;const r: Resource = await this.request('ApiResource','create',{url:'/v3/pins/' + this.id() + '/react/',data:{client_tracking_params:raw.tracking_params,reaction_type:1}},revision) as Resource,p: NativePin = r.data as NativePin;
      if(!p || p.id !== this.id())throw new Error('like');this.sent = false;this.liked.add(this.id());this.apply();this.ports.committed('like',pin);
    }catch (_) {if(revision === this.revision)this.markUnknown();if(this.valid(revision))this.ports.feedback(this.sent ? '点赞结果未确认，请重新读取核对；不会重复提交' : PinmonyI18n.message("pm_like_status_or_tracking_details_not_confirmed_5341ec8c"));}
    finally {if(revision === this.revision){this.busy = false;this.sent = false;}}
  }
  async editAction(method: string, encoded: string): Promise<void> {
    if(this.mode !== 'edit' || this.busy || !this.valid(this.revision) || this.store.editResult.loading || this.store.editResult.busy || this.store.editResult.picker.busy || this.store.editResult.error || this.store.editResult.uncertain)return;
    const a: (string | boolean)[] = this.args(encoded), edit: PinmonyEditPinResult = this.store.editResult, revision: number = this.revision;
    if(method === 'boardsCreate'){await this.saveAction(method,encoded);return;}
    if(method === 'editPhase' && typeof a[0] === 'string' && ['edit','boards','confirm'].includes(a[0])) {
      edit.phase = a[0];this.store.saveCreating = false;this.publish();if(a[0] !== 'boards')return;
      this.busy = true;try {await this.loadPicker(revision);}catch (_) {if(this.valid(revision)){this.store.editResult.picker.loading = false;this.store.editResult.picker.error = PinmonyI18n.message("pm_unable_to_load_boards_please_retry_04bec826");this.publish();}}finally {if(revision === this.revision)this.busy = false;}return;
    }
    if(method === 'editSelect'){const b: PinmonySaveBoard | undefined = edit.picker.items.concat(edit.picker.shortlist).find((b: PinmonySaveBoard): boolean => b.id === a[0] && b.enabled && this.digits(b.id));if(b){edit.board = b;edit.phase = 'edit';this.publish();}return;}
    if(method === 'editAi' && typeof a[0] === 'boolean'){edit.ai = a[0];this.publish();return;}
    if(method === 'editText' && edit.editableContent && typeof a[1] === 'string' && a[1].length <= 10000 && edit.phase === 'edit'){if(a[0] === 'title')edit.title = a[1];else if(a[0] === 'description')edit.description = a[1];this.publish();return;}
    if(method !== 'editCommit' || typeof a[0] !== 'boolean' || a[0] && edit.phase !== 'confirm' || !a[0] && edit.phase !== 'edit')return;
    const remove: boolean = a[0];if(!this.raw || this.raw.pinner?.id !== this.viewer || !edit.board.enabled || !this.allowed().includes(edit.board.id))return;
    if(!remove && edit.editableContent && (a.length > 1)){if(typeof a[1] !== 'string' || typeof a[2] !== 'string' || a[1].length > 10000 || a[2].length > 10000)return;edit.title = a[1];edit.description = a[2];}
    this.busy = true;this.lock(true);this.sent = false;
    try {let options: Options;
      if(remove){options = {id:this.id()};if(this.tracking)options.client_tracking_params = this.tracking + '~0';}
      else {const disclosures: number[] = this.disclosures.filter((v: number): boolean => v !== 1);if(edit.ai)disclosures.push(1);options = {id:this.id(),board_id:edit.board.id,board_section_id:edit.board.id === this.initialBoard ? this.section : '',ai_disclosures:disclosures};if(edit.editableContent){options.title = edit.title;options.description = edit.description;}}
      this.sent = true;const r: Resource = await this.request('PinResource',remove ? 'delete' : 'update',options,revision) as Resource,p: NativePin = r.data as NativePin;
      if(r.code !== 0 || r.endpoint_name !== (remove ? 'v3_delete_pin_handler' : 'v3_edit_pin'))throw new Error('edit');
      if(!remove && (!p || p.id !== this.id() || p.board?.id !== edit.board.id || p.pinner?.id !== undefined && p.pinner.id !== this.viewer || !Array.isArray(p.ai_disclosures) || p.ai_disclosures.includes(1) !== edit.ai ||
        edit.editableContent && ((edit.title !== (this.raw.title || '') && p.title !== edit.title) || (edit.description !== (this.raw.description || '') && p.description !== edit.description))))throw new Error('edit-result');
      this.sent = false;if(!remove)this.edited.set(this.id(),p);else this.store.confirmedSaves.confirm(this.id(),false);
      this.apply();this.lock(false);this.busy = false;const pin: string = this.pin;this.dismiss('edit');this.ports.committed(remove ? 'delete' : 'edit',pin);this.ports.feedback(remove ? '已从你的图板移除 Pin 图' : PinmonyI18n.message("pm_changes_saved_1045a8e6"));
    }catch (_) {if(this.valid(revision))this.fail(PinmonyI18n.message("pm_result_not_confirmed_close_and_reload_to_check_it_will_not_be_re_d952b803"),this.sent);}
    finally {if(revision === this.revision){this.busy = false;this.sent = false;this.lock(false);}}
  }
  dismiss(kind: string, force: boolean = false): void {
    if(this.mode !== kind || this.busy && !force)return;this.pause();if(kind === 'save')this.store.saveToken++;else this.store.editToken++;this.mode = '';this.store.saveCreating = false;this.ports.show('');if(kind === 'save')this.ports.dismissed?.();
  }
  apply(): void {
    if(this.key() !== this.account || !this.store.detail)return;const detail = this.store.detail, id: string = this.id(detail.pinUrl);
    const actions: PinmonyDetailAction[] = this.store.confirmedSaves.actions(id,detail.actions).map((a: PinmonyDetailAction): PinmonyDetailAction => {
      if(a.kind !== 'like' || !this.liked.has(id))return a;return {id:a.id,kind:a.kind,label:a.label,countText:a.selected ? a.countText : '',enabled:false,selected:true};});
    if(!actions.some((a: PinmonyDetailAction): boolean => a.kind === 'save'))actions.push({
      id:'native-save',kind:'save',label:this.store.confirmedSaves.isSaved(id) ? PinmonyI18n.message("pm_saved_471dd4d7") : PinmonyI18n.message("pm_save_60a53514"),countText:'',enabled:true,selected:this.store.confirmedSaves.isSaved(id)});
    if(!actions.some((a: PinmonyDetailAction): boolean => a.kind === 'like'))actions.push({
      id:'native-like',kind:'like',label:'点赞',countText:'',enabled:!this.liked.has(id) && !this.likeBlocked(detail.pinUrl),selected:this.liked.has(id)});
    detail.actions = actions;const edit: NativePin | undefined = this.edited.get(id);if(edit){if(typeof edit.title === 'string')detail.title = edit.title;if(typeof edit.description === 'string')detail.description = edit.description;}
    this.store.detail = JSON.parse(JSON.stringify(detail)) as PinmonyDetailSnapshot;
  }
}
