import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardFlow, PinmonyBoardTarget } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyBoardManagementIdentity {
  page: string; boardId: string; ownerId: string; ownerUsername: string; viewerId: string;
  member: boolean; followed: boolean; intent: number;
}
interface EditValue { name: string; description: string; privacy: string; recommend: boolean; invites: boolean; requests: boolean; }
interface EditOptions {
  board_id: string; name: string; description: string; privacy: string;
  allow_homefeed_recommendations: boolean; collaborator_invites_enabled: boolean;
  collaborator_requests_enabled: boolean; sensitivity: null;
}
interface BoardIdOptions { board_id: string; }
interface ApiOptions { url: string; data?: Record<string,string>; }
interface ManagementEnvelope { options: EditOptions | BoardIdOptions | ApiOptions; context: Record<string,string>; }
interface ManagementAction { action: string; value?: EditValue | string; }
interface BoardOwner { id: string; username?: string; }
interface ManagementBoard { type: string; id: string; name: string; privacy: string; url: string; owner: BoardOwner; collaborated_by_me?: boolean; }
interface ManagementResource { status: string; code: number; endpoint_name: string; data: ManagementBoard | null; }
interface ManagementResponse { resource_response: ManagementResource; client_context?: ManagementContext; }
interface ManagementContext { user?: BoardOwner; }
export interface PinmonyBoardManagementPorts {
  state: () => PinmonyBoardFlow | undefined; page: () => string;
  identity: () => PinmonyBoardManagementIdentity | undefined;
  session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  changed: (flow: PinmonyBoardFlow) => void;
  confirmed: (action: string, data: string, nextPage: string) => void;
}

// These established website contracts use the native account and board intent, never a Web document.
export class PinmonyBoardManagementNativeWrites {
  private readonly ports: PinmonyBoardManagementPorts;
  private revision: number = 0; private sequence: number = 0; private job: string = '';
  private state: PinmonyBoardFlow | undefined = undefined;
  private identity: PinmonyBoardManagementIdentity | undefined = undefined;
  constructor(ports: PinmonyBoardManagementPorts) {this.ports = ports;}
  private clone(f: PinmonyBoardFlow): PinmonyBoardFlow {
    return {phase:f.phase,sectionId:f.sectionId,sectionTitle:f.sectionTitle,loading:f.loading,busy:f.busy,uncertain:f.uncertain,
      error:f.error,description:f.description,privacy:f.privacy,recommend:f.recommend,invites:f.invites,requests:f.requests,
      pins:f.pins.slice(),targets:f.targets.slice(),saved:f.saved.slice(),hasMore:f.hasMore};
  }
  private publish(f: PinmonyBoardFlow): void {this.ports.changed(this.clone(f));}
  private unknown(f: PinmonyBoardFlow): void {
    f.busy = false;f.uncertain = true;f.error = PinmonyI18n.message("pm_result_not_confirmed_close_and_refresh_to_check_it_will_not_be_r_b66391e3");
    this.publish(f);PinmonyRuntimeLog.info('BoardManagementNative: outcome=unknown');
  }
  pause(): void {
    this.revision++;
    if(this.job)this.ports.network().cancel(this.job);
    if(this.state?.busy && this.ports.page() === this.identity?.page && this.ports.state()?.busy && this.ports.state()?.phase === this.state.phase)this.unknown(this.state);
    this.job = '';this.state = undefined;this.identity = undefined;
  }
  private editedPage(board: ManagementBoard, identity: PinmonyBoardManagementIdentity, origin: string): string {
    const page: string = typeof board.url === 'string' && board.url.startsWith('/') && !board.url.startsWith('//') ? origin + board.url : board.url;
    if(typeof page !== 'string' || !page.startsWith(origin + '/') || !/^\/[^/?#]+\/[^/?#]+\/$/.test(page.slice(origin.length)))throw new Error('route');
    const parts: string[] = page.slice(origin.length).split('/').filter((part: string): boolean => !!part);
    if(decodeURIComponent(parts[0]).toLowerCase() !== identity.ownerUsername.toLowerCase() ||
      /^_|^(?:pins|followers|following)$/i.test(decodeURIComponent(parts[1])) || /[\\/?#]/.test(decodeURIComponent(parts[1])))throw new Error('owner-route');
    return page;
  }
  async submit(encoded: string): Promise<void> {
    let a: ManagementAction;try {a = JSON.parse(encoded) as ManagementAction;}catch (_) {return;}
    const original: PinmonyBoardFlow | undefined = this.ports.state(), identity: PinmonyBoardManagementIdentity | undefined = this.ports.identity();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(this.job || !original || !identity || !session.authenticated || !session.accountId || original.busy || original.loading || original.uncertain || original.error)return;
    const own: boolean = identity.ownerId === identity.viewerId, member: boolean = identity.member && !own;
    let options: EditOptions | BoardIdOptions | ApiOptions, name: string, verb: string, endpoint: string;
    let source: string = identity.page.slice(session.origin.length), handler: string = 'www/index.js';
    if(a.action === 'editSave') {
      const v: EditValue | undefined = a.value as EditValue | undefined;
      if(!own || original.phase !== 'edit' || !v || typeof v.name !== 'string' || !v.name.trim() ||
        typeof v.description !== 'string' || !['public','secret'].includes(v.privacy) ||
        typeof v.recommend !== 'boolean' || typeof v.invites !== 'boolean' || typeof v.requests !== 'boolean')return;
      options = {board_id:identity.boardId,name:v.name.trim().slice(0,300),description:v.description.slice(0,500),privacy:v.privacy,
        allow_homefeed_recommendations:v.recommend,collaborator_invites_enabled:v.invites,collaborator_requests_enabled:v.requests,sensitivity:null};
      name = 'BoardResource';verb = 'update';endpoint = 'v3_edit_board';
    }else if(a.action === 'merge') {
      if(!own || original.phase !== 'mergeTargets' || typeof a.value !== 'string' || !/^\d{1,30}$/.test(a.value) || a.value === identity.boardId || !original.targets.some((t: PinmonyBoardTarget): boolean => t.id === a.value && t.enabled))return;
      options = {url:'/v3/boards/' + identity.boardId + '/merge/' + a.value + '/',data:{}};
      name = 'ApiResource';verb = 'create';endpoint = 'v3_board_merge';handler = 'www/[username]/[slug].js';
    }else if(a.action === 'delete') {
      if(!own || original.phase !== 'edit')return;
      options = {board_id:identity.boardId};name = 'BoardResource';verb = 'delete';endpoint = 'v3_delete_board';
    }else if(a.action === 'archive') {
      if(!(own || member) || original.phase !== 'archive')return;
      options = {url:'/v3/boards/' + identity.boardId + '/archive/'};name = 'ApiResource';verb = 'create';endpoint = 'v3_archive_board';handler = 'www/[username]/[slug].js';
    }else if(a.action === 'leave') {
      if(!member || original.phase !== 'edit')return;
      options = {url:'/v3/boards/' + identity.boardId + '/collaborators/' + identity.viewerId + '/',data:{}};
      name = 'ApiResource';verb = 'delete';endpoint = 'v3_remove_board_collaborators';
    }else if(a.action === 'unfollow') {
      if(!member || !identity.followed || original.phase)return;
      options = {url:'/v3/boards/' + identity.boardId + '/follow/'};name = 'ApiResource';verb = 'delete';endpoint = 'v3_unfollow_board';
    }else return;
    if(name === 'BoardResource'){source = '/board/' + identity.boardId + '/edit/';handler = 'www/board/[id]/edit.js';}
    const revision: number = this.revision, state: PinmonyBoardFlow = this.clone(original);
    const current = (): boolean => {
      const s: PinmonyBusinessSessionContext = this.ports.session(), actual: PinmonyBoardManagementIdentity | undefined = this.ports.identity();
      return revision === this.revision && s.authenticated && s.accountId === session.accountId && s.generation === session.generation && s.origin === session.origin &&
        !!actual && actual.page === identity.page && actual.boardId === identity.boardId && actual.ownerId === identity.ownerId && actual.viewerId === identity.viewerId &&
        actual.ownerUsername === identity.ownerUsername && actual.member === identity.member && actual.followed === identity.followed && actual.intent === identity.intent && this.ports.state()?.phase === state.phase;
    };
    const envelope: ManagementEnvelope = {options:options,context:{}};
    const job: PinmonyNetworkJob = {id:'native_board_management_write_' + (++this.sequence).toString(),epoch:session.generation,page:identity.page,
      url:session.origin + '/resource/' + name + '/' + verb + '/',method:'POST',body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':handler}};
    this.job = job.id;this.state = state;this.identity = identity;state.busy = true;state.error = '';this.publish(state);
    PinmonyRuntimeLog.info('BoardManagementNative: start action=' + a.action);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessBoardManagementWrite(job,(): PinmonyBusinessSessionContext => this.ports.session(),
        identity.boardId,identity.viewerId,identity.ownerId,identity.member,current,original.phase === 'mergeTargets' ? original.targets.filter((t: PinmonyBoardTarget): boolean => t.enabled).map((t: PinmonyBoardTarget): string => t.id) : []);
      if(!current())return;
      if(reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 6000000)throw new Error('unconfirmed');
      const body: ManagementResponse = JSON.parse(reply.body) as ManagementResponse, r: ManagementResource = body.resource_response, b: ManagementBoard | null = r?.data;
      if(!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== endpoint ||
        body.client_context?.user && body.client_context.user.id !== identity.viewerId)throw new Error('business');
      let nextPage: string = '';
      if(a.action === 'editSave') {
        const edit: EditOptions = options as EditOptions;
        if(!b || b.type !== 'board' || b.id !== identity.boardId || b.owner?.id !== identity.viewerId || b.name !== edit.name || b.privacy !== edit.privacy)throw new Error('edit');
        nextPage = this.editedPage(b,identity,session.origin);
      }else if(a.action === 'merge') {
        if(!b || b.type !== 'board' || b.id !== a.value)throw new Error('merge');
      }else if(a.action === 'leave') {
        if(!b || b.type !== 'board' || b.id !== identity.boardId || b.collaborated_by_me !== false || b.owner && b.owner.id !== identity.ownerId)throw new Error('leave');
      }else if(a.action === 'delete' || a.action === 'unfollow') {if(b !== null)throw new Error('result');}
      else if(b && (b.id !== undefined && b.id !== identity.boardId || b.owner?.id !== undefined && b.owner.id !== identity.ownerId))throw new Error('archive');
      state.busy = false;this.publish(state);
      PinmonyRuntimeLog.info('BoardManagementNative: outcome=confirmed action=' + a.action);
      this.ports.confirmed(a.action,JSON.stringify(b),nextPage);
    }catch (_) {if(current())this.unknown(state);}
    finally {if(revision === this.revision){this.job = '';this.state = undefined;this.identity = undefined;}}
  }
}
