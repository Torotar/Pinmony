import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardCollaborators, PinmonyBoardCollaborator } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyBoardWriteIdentity {
  page: string; boardId: string; ownerId: string; viewerId: string; member: boolean;
}
interface PermissionValue { permission: number; invites: boolean; }
interface PermissionOptions { board_id: string; collaborator_permissions_setting: number; collaborator_invites_enabled: boolean; sensitivity: null; }
interface PermissionEnvelope { options: PermissionOptions; context: Record<string, string>; }
interface InviteVariables { collaboratorIds: string[]; boardId: string; message: string; }
interface InviteEnvelope { queryHash: string; variables: InviteVariables; }
interface WriteBoard { id: string; owner?: WriteUser; collaborator_permissions_setting: number; collaborator_invites_enabled: boolean; }
interface WriteUser { id: string; }
interface WriteResource { status: string; code: number; endpoint_name: string; data: WriteBoard; }
interface WriteResponse { resource_response?: WriteResource; client_context?: WriteContext; errors?: Object; data?: InviteResult; }
interface WriteContext { user?: WriteUser; }
interface InviteResult { v3InviteBoardCollaboratorsMutation?: InviteMutation; }
interface InviteMutation { __typename: string; }
export interface PinmonyBoardCollaboratorsWritePorts {
  state: () => PinmonyBoardCollaborators | undefined;
  identity: () => PinmonyBoardWriteIdentity | undefined;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  changed: (state: PinmonyBoardCollaborators) => void;
  confirmed: (state: PinmonyBoardCollaborators) => void;
  feedback: (message: string) => void;
}

// These two confirmed POST contracts belong to a native board intent, not a Web document.
export class PinmonyBoardCollaboratorsNativeWrites {
  private readonly ports: PinmonyBoardCollaboratorsWritePorts;
  private revision: number = 0;
  private sequence: number = 0;
  private job: string = '';
  private state: PinmonyBoardCollaborators | undefined = undefined;
  constructor(ports: PinmonyBoardCollaboratorsWritePorts) { this.ports = ports; }

  private cloneUser(user: PinmonyBoardCollaborator): PinmonyBoardCollaborator {
    return {id:user.id,name:user.name,username:user.username,avatar:user.avatar,status:user.status};
  }
  private clone(state: PinmonyBoardCollaborators): PinmonyBoardCollaborators {
    return {owner:state.owner,canInvite:state.canInvite,token:state.token,page:state.page,phase:state.phase,
      loading:state.loading,busy:state.busy,uncertain:state.uncertain,error:state.error,feedback:state.feedback,
      permission:state.permission,invites:state.invites,users:state.users.map((user: PinmonyBoardCollaborator): PinmonyBoardCollaborator => this.cloneUser(user)),
      suggestions:state.suggestions.map((user: PinmonyBoardCollaborator): PinmonyBoardCollaborator => this.cloneUser(user))};
  }
  private publish(state: PinmonyBoardCollaborators): void { this.ports.changed(this.clone(state)); }
  private unknown(state: PinmonyBoardCollaborators): void {
    state.busy = false; state.uncertain = true; state.feedback = '';
    state.error = PinmonyI18n.message("pm_result_not_confirmed_close_and_reopen_to_check_before_submitting_2fcbc18d");
    this.publish(state);
    PinmonyRuntimeLog.info('BoardCollaboratorNativeWrite: outcome=unknown');
  }
  pause(): void {
    this.revision++;
    if(this.job)this.ports.network().cancel(this.job);
    const state: PinmonyBoardCollaborators | undefined = this.state, visible: PinmonyBoardCollaborators | undefined = this.ports.state();
    if(state?.busy && visible?.token === state.token && visible.page === state.page)this.unknown(state);
    this.job = ''; this.state = undefined;
  }
  async submit(action: string, value: string): Promise<void> {
    const original: PinmonyBoardCollaborators | undefined = this.ports.state(), identity: PinmonyBoardWriteIdentity | undefined = this.ports.identity();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(this.job || !original || !identity || !session.authenticated || !session.accountId || original.page !== identity.page ||
      original.loading || original.busy || original.uncertain || original.error)return;
    let permission: PermissionValue | undefined = undefined;
    if(action === 'send') {
      if(original.phase !== 'invite' || original.canInvite !== true || identity.ownerId !== identity.viewerId && !identity.member ||
        !original.suggestions.some((user: PinmonyBoardCollaborator): boolean => user.id === value && !user.status) ||
        !/^\d{1,30}$/.test(value) || value === identity.viewerId || value === identity.ownerId || original.users.length >= 500)return;
    } else if(action === 'save') {
      try {permission = JSON.parse(value) as PermissionValue;}catch (_) {return;}
      if(original.phase !== 'permissions' || original.owner !== true || identity.ownerId !== identity.viewerId || !permission ||
        ![0,1].includes(permission.permission) || typeof permission.invites !== 'boolean')return;
    } else return;
    const revision: number = this.revision, state: PinmonyBoardCollaborators = this.clone(original);
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = this.ports.session(), target: PinmonyBoardWriteIdentity | undefined = this.ports.identity();
      const visible: PinmonyBoardCollaborators | undefined = this.ports.state();
      return revision === this.revision && actual.authenticated && actual.accountId === session.accountId &&
        actual.generation === session.generation && actual.origin === session.origin && !!target &&
        target.page === identity.page && target.boardId === identity.boardId && target.ownerId === identity.ownerId &&
        target.viewerId === identity.viewerId && target.member === identity.member && visible?.token === state.token && visible.page === state.page;
    };
    const path: string = identity.page.slice(session.origin.length), id: string = 'native_board_collab_write_' + (++this.sequence).toString();
    let url: string, body: string;
    const headers: Record<string,string> = {'Accept':'application/json','X-Requested-With':'XMLHttpRequest'};
    if(action === 'send') {
      const envelope: InviteEnvelope = {queryHash:'42ceaa3423a096a27613e5738f83aaadcee449c55d4dd03624d2f08a6b6dca04',
        variables:{collaboratorIds:[value],boardId:identity.boardId,message:''}};
      url = session.origin + '/_/graphql/'; body = JSON.stringify(envelope);
      headers['Content-Type'] = 'application/json'; headers['X-Pinterest-Source-Url'] = path;
    } else {
      const envelope: PermissionEnvelope = {options:{board_id:identity.boardId,collaborator_permissions_setting:permission!.permission,
        collaborator_invites_enabled:permission!.invites,sensitivity:null},context:{}};
      url = session.origin + '/resource/BoardResource/update/';
      body = 'source_url=' + encodeURIComponent('/board/' + identity.boardId + '/edit/') + '&data=' + encodeURIComponent(JSON.stringify(envelope));
      headers['Content-Type'] = 'application/x-www-form-urlencoded'; headers['X-Pinterest-Pws-Handler'] = 'www/board/[id]/edit.js';
    }
    const job: PinmonyNetworkJob = {id:id,epoch:session.generation,page:identity.page,url:url,method:'POST',body:body,headers:headers};
    this.job = id; this.state = state; state.busy = true; state.error = ''; state.feedback = ''; this.publish(state);
    PinmonyRuntimeLog.info('BoardCollaboratorNativeWrite: start action=' + action);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessBoardCollaboratorWrite(job,
        (): PinmonyBusinessSessionContext => this.ports.session(),identity.boardId,identity.viewerId,identity.ownerId,original.canInvite === true,current);
      if(!current())return;
      if(reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 6 * 1024 * 1024)throw new Error('unconfirmed');
      const response: WriteResponse = JSON.parse(reply.body) as WriteResponse;
      if(response.client_context?.user && response.client_context.user.id !== identity.viewerId)throw new Error('viewer');
      if(action === 'send') {
        if(response.errors || response.data?.v3InviteBoardCollaboratorsMutation?.__typename !== 'V3InviteBoardCollaborators')throw new Error('invite');
        const user: PinmonyBoardCollaborator | undefined = state.suggestions.find((u: PinmonyBoardCollaborator): boolean => u.id === value);
        if(!user)throw new Error('user'); user.status = 'new';
        if(!state.users.some((u: PinmonyBoardCollaborator): boolean => u.id === value))state.users.push(this.cloneUser(user));
        state.feedback = PinmonyI18n.message("pm_1_invitation_sent_9473de94");
      } else {
        const resource: WriteResource | undefined = response.resource_response, data: WriteBoard | undefined = resource?.data;
        if(resource?.status !== 'success' || resource.code !== 0 || resource.endpoint_name !== 'v3_edit_board' || !data ||
          data.id !== identity.boardId || data.owner && data.owner.id !== identity.ownerId ||
          data.collaborator_permissions_setting !== permission!.permission || data.collaborator_invites_enabled !== permission!.invites)throw new Error('permissions');
        state.permission = permission!.permission; state.invites = permission!.invites; state.canInvite = true;
        state.phase = 'members'; state.feedback = PinmonyI18n.message("pm_permissions_updated_d72fbc80");
      }
      state.busy = false; this.ports.confirmed(state); this.publish(state); this.ports.feedback(state.feedback);
      PinmonyRuntimeLog.info('BoardCollaboratorNativeWrite: outcome=confirmed action=' + action);
    }catch (_) {if(current())this.unknown(state);}
    finally {if(revision === this.revision){this.job = '';this.state = undefined;}}
  }
}
