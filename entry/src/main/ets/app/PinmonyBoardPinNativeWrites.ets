import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardFlow } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyBoardRecommendationSource { id: string; tracking_params?: string; }
export interface PinmonyBoardPinWriteIdentity {
  page: string; boardId: string; viewerId: string; intent: number; canContribute: boolean;
  recommendationPath?: string;
  loadedIds: string[]; selectedIds: string[]; sources: PinmonyBoardRecommendationSource[];
}
interface CreateTargetOptions { name: string; privacy: string; }
interface CreateTargetInput { name: string; secret: boolean; }
interface CreatedTarget { id: string; type: string; name: string; privacy: string; owner: CopyOwner; image_cover_url?: string; }
interface SaveOptions { pin_id: string; board_id: string; user_id: string; clientTrackingParams?: string; }
interface UnsaveOptions { id: string; client_tracking_params: string; }
interface SavedRecommendation { id: string; tracking: string; }
interface MoveData { board_id: string; pin_ids: string[]; section_id?: string; }
interface MoveOptions { url: string; data: MoveData; }
interface SectionMoveData { pins: string[]; fields: string[]; }
interface SectionMoveOptions { url: string; data: SectionMoveData; }
interface SectionMoveResult { id: string; type: string; board: CopyOwner; }
interface WriteEnvelope { options: SaveOptions | UnsaveOptions | MoveOptions | SectionMoveOptions | CreateTargetOptions; context: Record<string, string>; }
interface CopyOwner { id: string; }
interface SavedCopy { id: string; board: CopyOwner; pinner: CopyOwner; is_repin: boolean; }
interface WriteResource { status: string; code: number; endpoint_name: string; data: SavedCopy | CreatedTarget | SectionMoveResult | null; }
interface WriteResponse { resource_response: WriteResource; client_context?: WriteContext; }
interface WriteContext { user?: CopyOwner; }
export interface PinmonyBoardPinWritePorts {
  state: () => PinmonyBoardFlow | undefined;
  page: () => string;
  identity: () => PinmonyBoardPinWriteIdentity | undefined;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  changed: (state: PinmonyBoardFlow) => void;
  confirmed: (action: string, source: string[], copy: string) => void;
}

// Native recommendations/targets prepare these two POSTs without a Web route or action session.
export class PinmonyBoardPinNativeWrites {
  private readonly ports: PinmonyBoardPinWritePorts;
  private readonly savedCopies: Map<string, SavedRecommendation> = new Map();
  private readonly uncertainPins: Set<string> = new Set();
  private operationKey: string = '';
  private readonly createUnknown: Set<string> = new Set();
  private revision: number = 0; private sequence: number = 0; private job: string = '';
  private state: PinmonyBoardFlow | undefined = undefined;
  private identity: PinmonyBoardPinWriteIdentity | undefined = undefined;
  constructor(ports: PinmonyBoardPinWritePorts) {this.ports = ports;}
  private key(source: string, identity: PinmonyBoardPinWriteIdentity, session: PinmonyBusinessSessionContext): string {
    return session.origin + ':' + session.accountId + ':' + session.generation.toString() + ':' + identity.boardId + ':' + source;
  }
  savedIds(): string[] {
    const identity: PinmonyBoardPinWriteIdentity | undefined = this.ports.identity();
    if (!identity) return [];
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return identity.sources.filter((pin: PinmonyBoardRecommendationSource): boolean => this.savedCopies.has(this.key(pin.id, identity, session))).map((pin: PinmonyBoardRecommendationSource): string => pin.id);
  }
  private clone(state: PinmonyBoardFlow): PinmonyBoardFlow {
    return {phase:state.phase,targetBoardId:state.targetBoardId,targetSections:state.targetSections?.slice(),sectionId:state.sectionId,sectionTitle:state.sectionTitle,loading:state.loading,busy:state.busy,
      uncertain:state.uncertain,error:state.error,description:state.description,privacy:state.privacy,recommend:state.recommend,
      invites:state.invites,requests:state.requests,pins:state.pins.slice(),targets:state.targets.slice(),saved:state.saved.slice(),hasMore:state.hasMore};
  }
  private publish(state: PinmonyBoardFlow): void {this.ports.changed(this.clone(state));}
  private unknown(state: PinmonyBoardFlow): void {
    if(this.operationKey)this.uncertainPins.add(this.operationKey);
    state.busy = false;state.uncertain = true;state.error = PinmonyI18n.message("pm_result_not_confirmed_close_and_refresh_to_check_it_will_not_be_r_b66391e3");
    this.publish(state);PinmonyRuntimeLog.info('BoardPinNativeWrite: outcome=unknown');
  }
  pause(): void {
    this.revision++;
    if(this.job)this.ports.network().cancel(this.job);
    if(this.state?.busy && this.ports.page() === this.identity?.page &&
      this.ports.state()?.busy && this.ports.state()?.phase === this.state.phase)this.unknown(this.state);
    this.job = '';this.state = undefined;this.identity = undefined;
  }
  async submit(action: string, value: string): Promise<void> {
    const original: PinmonyBoardFlow | undefined = this.ports.state(), identity: PinmonyBoardPinWriteIdentity | undefined = this.ports.identity();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(this.job || !original || !identity || !identity.canContribute || !session.authenticated || !session.accountId ||
      original.busy || original.loading || original.uncertain || original.error)return;
    let options: SaveOptions | UnsaveOptions | MoveOptions | SectionMoveOptions | CreateTargetOptions;
    const sectionTarget: RegExpMatchArray | null = value.match(/^section:(\d{1,30}):(\d{1,30})$/);
    let createKey: string = '';
    let url: string, source: string, handler: string;
    let selected: string[] = [];
    if(action === 'save' && original.saved.includes(value))action = 'unsave';
    if(action === 'save' || action === 'unsave') {
      const key: string = this.key(value,identity,session);
      if(this.uncertainPins.has(key)){this.operationKey = key;this.unknown(this.clone(original));return;}
      this.operationKey = key;
      const sourcePath: string = identity.recommendationPath || identity.page.slice(session.origin.length) + '_tools/more-ideas/?ideas_referrer=23';
      handler = identity.recommendationPath ? 'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js' : 'www/[username]/[slug]/_tools/more-ideas.js';
      source = sourcePath;
      if(action === 'unsave') {
        const copy: SavedRecommendation | undefined = this.savedCopies.get(key);
        if(original.phase !== 'ideas' || !copy || !original.pins.some((p): boolean => p.id === value))return;
        options = {id:copy.id,client_tracking_params:copy.tracking};selected = [value];url = '/resource/PinResource/delete/';
      } else {
      const pin: PinmonyBoardRecommendationSource | undefined = identity.sources.find((p: PinmonyBoardRecommendationSource): boolean => p.id === value);
      if(original.phase !== 'ideas' || !pin || !original.pins.some((p): boolean => p.id === value) || original.saved.includes(value))return;
      const save: SaveOptions = {pin_id:value,board_id:identity.boardId,user_id:identity.viewerId};
      if(typeof pin.tracking_params === 'string' && pin.tracking_params.length <= 16384)save.clientTrackingParams = pin.tracking_params;
      options = save;selected = [value];url = '/resource/RepinResource/create/';
      }
    }else if(action === 'createTarget') {
      let input: CreateTargetInput;try { input = JSON.parse(value) as CreateTargetInput; }catch (_) {return;}
      if(original.phase !== 'targets' || typeof input.name !== 'string' || !input.name.trim() || input.name.trim().length > 100 ||
          typeof input.secret !== 'boolean' || !identity.selectedIds.length || !identity.selectedIds.every((id: string): boolean => identity.loadedIds.includes(id)))return;
      createKey = session.origin + ':' + session.accountId + ':' + session.generation.toString() + ':' + input.name.trim();
      if(this.createUnknown.has(createKey)){const blocked: PinmonyBoardFlow = this.clone(original);this.unknown(blocked);return;}
      options = {name:input.name.trim(),privacy:input.secret ? 'secret' : 'public'};
      url = '/resource/BoardResource/create/';source = '/board/create/';handler = 'www/board/create.js';
    }else if(action === 'move') {
      const target = original.targets.find((t): boolean => t.id === (sectionTarget && sectionTarget[1] !== identity.boardId ? sectionTarget[1] : value) && t.enabled && t.id !== identity.boardId);
      selected = identity.selectedIds.slice();
      if(original.phase !== 'targets' || !target || !selected.length || selected.length > 500 ||
        !selected.every((id: string,index: number): boolean => /^\d{1,30}$/.test(id) && selected.indexOf(id) === index && identity.loadedIds.includes(id)))return;
      options = {url:'/v3/pins/bulk/move/',data:{board_id:target.id,pin_ids:selected}};url = '/resource/ApiResource/create/';
      if(sectionTarget) {
        if(sectionTarget[1] === identity.boardId) {
          if(selected.length !== 1)return;
          options = {url:'/v3/board/sections/' + sectionTarget[2] + '/',data:{pins:selected,fields:['boardsection.board()','boardsection.id','boardsection.pin_count','boardsection.preview_pins()','boardsection.slug','boardsection.title','boardsection.type']}};
        } else {
          if(original.targetBoardId !== sectionTarget[1] || !original.targetSections?.some((s): boolean => s.id === sectionTarget[2]))return;
          options = {url:'/v3/pins/bulk/move/',data:{board_id:sectionTarget[1],section_id:sectionTarget[2],pin_ids:selected}};
        }
      }
      source = '/board/' + identity.boardId + '/organize/repin/';handler = 'www/board/[id]/organize.js';
      if(sectionTarget && sectionTarget[1] !== identity.boardId) {source = identity.page.slice(session.origin.length) + '_tools/organize/?organization_feed=False';handler = 'www/[username]/[slug]/_tools/organize.js';}
    }else return;
    const revision: number = this.revision, state: PinmonyBoardFlow = this.clone(original);
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = this.ports.session(), target: PinmonyBoardPinWriteIdentity | undefined = this.ports.identity();
      return revision === this.revision && actual.authenticated && actual.accountId === session.accountId &&
        actual.generation === session.generation && actual.origin === session.origin && !!target && target.canContribute &&
        target.page === identity.page && target.boardId === identity.boardId && target.viewerId === identity.viewerId &&
        target.intent === identity.intent && this.ports.state()?.phase === state.phase;
    };
    const envelope: WriteEnvelope = {options:options,context:{}};
    const job: PinmonyNetworkJob = {id:'native_board_pin_write_' + (++this.sequence).toString(),epoch:session.generation,page:identity.page,
      url:session.origin + url,method:'POST',body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':handler}};
    if(createKey)this.createUnknown.add(createKey);
    this.job = job.id;this.state = state;this.identity = identity;state.busy = true;state.error = '';this.publish(state);
    PinmonyRuntimeLog.info('BoardPinNativeWrite: start action=' + action + ' count=' + selected.length.toString());
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessBoardPinWrite(job,
        (): PinmonyBusinessSessionContext => this.ports.session(),identity.boardId,identity.viewerId,identity.loadedIds,original.targets.filter((t): boolean => t.enabled && t.id !== identity.boardId).map((t): string => t.id).concat(original.targetBoardId && original.targets.some((t): boolean => t.id === original.targetBoardId && t.enabled) ? (original.targetSections || []).map((s): string => 'section:' + original.targetBoardId + ':' + s.id) : []),identity.sources.map((p: PinmonyBoardRecommendationSource): string => p.id),current,
          action === 'unsave' ? [(options as UnsaveOptions).id] : [], identity.recommendationPath || '');
      if(!current())return;
      if(reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 6 * 1024 * 1024)throw new Error('unconfirmed');
      const response: WriteResponse = JSON.parse(reply.body) as WriteResponse, resource: WriteResource = response.resource_response;
      if(!resource || resource.status !== 'success' || resource.code !== 0 ||
        resource.endpoint_name !== (action === 'createTarget' ? 'v3_create_board' : action === 'save' ? 'v3_repin_handler' : action === 'unsave' ? 'v3_delete_pin_handler' : sectionTarget && sectionTarget[1] === identity.boardId ? 'v3_post_board_section' : 'v3_move_pins') ||
        response.client_context?.user && response.client_context.user.id !== identity.viewerId)throw new Error('business');
      if(action === 'createTarget') {
        const board: CreatedTarget | null = resource.data as CreatedTarget | null, wanted: CreateTargetOptions = options as CreateTargetOptions;
        if(!board || !/^\d{1,30}$/.test(board.id) || board.type !== 'board' || board.id === identity.boardId || board.name !== wanted.name ||
            board.privacy !== wanted.privacy || board.owner?.id !== identity.viewerId)throw new Error('create');
        this.createUnknown.delete(createKey);
        if(!state.targets.some((t): boolean => t.id === board.id))state.targets.unshift({id:board.id,secret:board.privacy === 'secret',title:board.name,
          imageUrl:/^https:\/\/i\.pinimg\.com\//.test(board.image_cover_url || '') ? board.image_cover_url! : '',enabled:true});
      }else if(action === 'save') {
        const copy: SavedCopy | null = resource.data as SavedCopy | null;
        if(!copy || !/^\d{1,30}$/.test(copy.id) || copy.board?.id !== identity.boardId || copy.pinner?.id !== identity.viewerId || copy.is_repin !== true)throw new Error('copy');
        const sourcePin: PinmonyBoardRecommendationSource | undefined = identity.sources.find((pin: PinmonyBoardRecommendationSource): boolean => pin.id === value);
        this.savedCopies.set(this.key(value,identity,session),{id:copy.id,tracking:sourcePin?.tracking_params || ''});
        state.saved.push(value);
      }else if(action === 'unsave') {
        if(resource.data !== null)throw new Error('delete');
        this.savedCopies.delete(this.key(value,identity,session));state.saved = state.saved.filter((id: string): boolean => id !== value);
      }else if(sectionTarget && sectionTarget[1] === identity.boardId) {
        const result: SectionMoveResult | null = resource.data as SectionMoveResult | null;
        if(!result || result.type !== 'board_section' || result.id !== sectionTarget[2] || result.board?.id !== identity.boardId)throw new Error('section-move');
      }else if(resource.data !== null)throw new Error('move');
      state.busy = false;this.publish(state);
      PinmonyRuntimeLog.info('BoardPinNativeWrite: outcome=confirmed action=' + action);
      this.ports.confirmed(sectionTarget && sectionTarget[1] === identity.boardId ? 'moveSection' : action,selected,action === 'save' ? JSON.stringify(resource.data) : action === 'unsave' ? (options as UnsaveOptions).id : '');
    }catch (_) {if(current())this.unknown(state);}
    finally {if(revision === this.revision){this.job = '';this.state = undefined;this.identity = undefined;}}
  }
}
