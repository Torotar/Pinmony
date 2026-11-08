import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyInboxStore, PinmonyBoardInvitation, PinmonyBoardInvitations } from 'feature_inbox';
import { PinmonyAuxiliaryPorts, PinmonyBusinessAuxiliaryClient, PinmonyAuxiliaryNotSent, PinmonyAuxiliaryRejected } from './PinmonyBusinessAuxiliaryClient';
interface User { avatar_color_index?: number; id: string; username?: string; full_name?: string; image_medium_url?: string; image_large_url?: string; image_small_url?: string; }
interface Board { id: string; url: string; name?: string; image_thumbnail_url?: string; image_cover_url?: string; }
interface Invite { board: Board; invited_by_user: User; invited_user: User; status: string; created_at?: string; }
interface Resource { status: string; code: number; error?: Object; endpoint_name?: string; data: Invite | Invite[]; }
interface Response { resource_response: Resource;client_context?: Client; }
interface Client {user?: User;}
interface Options {current_user?: boolean;field_set_key?: string;board_id?: string;invited_user_id?: string;}
export interface PinmonyBoardInvitationNativePorts extends PinmonyAuxiliaryPorts {store: () => PinmonyInboxStore;page: () => string;active: () => boolean;username: () => string;avatar: () => string;feedback: (message: string) => void;}
export class PinmonyBoardInvitationNative {
  private readonly ports: PinmonyBoardInvitationNativePorts;private readonly client: PinmonyBusinessAuxiliaryClient;
  private revision: number = 0;private account: string = '';private preview: boolean = false;private viewer: string = '';private page: string = '';private uncertain: Set<string> = new Set<string>();
  private declining: boolean = false;
  private reading: boolean = false;
  constructor(ports: PinmonyBoardInvitationNativePorts){this.ports = ports;this.client = new PinmonyBusinessAuxiliaryClient(ports);}
  pause(): void {this.revision++;this.client.pause();this.reading = false;this.ports.store().invitationReadPage = '';}
  private live(revision: number): boolean {return revision === this.revision && this.client.key() === this.account && this.ports.page() === this.page && this.ports.active();}
  private image(v: string | undefined): string {return typeof v === 'string' && v.length <= 2048 && /^https:\/\/i\.pinimg\.com\//i.test(v) ? v : '';}
  private map(v: Invite): PinmonyBoardInvitation {
    const b: Board = v.board,to: User = v.invited_user,from: User = v.invited_by_user;
    if(!/^\d{1,30}$/.test(b?.id) || !/^\d{1,30}$/.test(to?.id) || !/^\d{1,30}$/.test(from?.id))throw new Error('invite');
    const url: string = b.url.startsWith('/') ? this.ports.session().origin + b.url : b.url;
    if(!url.startsWith(this.ports.session().origin + '/') || !/^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(url.slice(this.ports.session().origin.length)) || !['new','accepted'].includes(v.status))throw new Error('route');
    return {boardId:b.id,boardUrl:url,boardName:(b.name || '').slice(0,200),imageUrl:this.image(b.image_thumbnail_url || b.image_cover_url),inviter:(from.full_name || from.username || '').slice(0,200),inviterUsername:/^[A-Za-z0-9_]+$/.test(from.username || '') ? from.username : undefined,invitedUsername:/^[A-Za-z0-9_]+$/.test(to.username || '') ? to.username : undefined,inviterAvatarColorIndex:Number.isInteger(from.avatar_color_index) && from.avatar_color_index! >= 1 && from.avatar_color_index! <= 10 ? from.avatar_color_index : undefined,inviterAvatar:this.image(from.image_medium_url || from.image_large_url),invitedUser:to.id,invitedName:(to.full_name || to.username || '').slice(0,200),invitedAvatarColorIndex:Number.isInteger(to.avatar_color_index) && to.avatar_color_index! >= 1 && to.avatar_color_index! <= 10 ? to.avatar_color_index : undefined,invitedAvatar:this.image(to.image_medium_url),createdAt:(v.created_at || '').slice(0,200),status:v.status};
  }
  private async request(verb: string,options: Options,target: string,revision: number): Promise<Response> {
    const value: Response = JSON.parse(await this.client.request(this.page,target ? 'BoardInviteResource' : 'BoardInvitesResource',verb,options,'invites',target,(): boolean => this.live(revision))) as Response;
    const r: Resource = value.resource_response;
    if(r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)throw new PinmonyAuxiliaryRejected('rejected');
    if(!r || r.status !== 'success' || r.code !== 0 || r.error)throw new Error('response');return value;
  }
  async open(preview: boolean): Promise<void> {
    const store: PinmonyInboxStore = this.ports.store(),item: PinmonyBoardInvitation | undefined = store.boardInvitationPreview;
    if(this.declining || !this.client.key() || !this.ports.active() || preview && !item)return;
    if(this.reading && this.live(this.revision) && this.preview === preview)return;
    const previous: PinmonyBoardInvitations | undefined = this.account === this.client.key() && this.page === this.ports.page() ? store.boardInvitations : undefined;
    this.pause();const account: string = this.client.key();if(account !== this.account)this.uncertain.clear();this.account = account;this.page = this.ports.page();this.preview = preview;this.viewer = '';
    this.reading = true;
    const revision: number = this.revision,token: number = ++store.boardInvitationToken;
    if(preview)store.invitationBusy = true;else store.boardInvitations = {token:token,page:this.page,loading:true,busy:false,uncertain:previous?.uncertain || false,error:'',feedback:'',items:previous?.items || []};
    try {
      const target: string = preview ? item!.boardId + ':' + item!.invitedUser : '',options: Options = preview ? {board_id:item!.boardId,invited_user_id:item!.invitedUser,field_set_key:'boardEdit'} : {current_user:true,field_set_key:'news'};
      const p: Response = await this.request('get',options,target,revision);if(!this.live(revision))return;
      const viewer: User | undefined = p.client_context?.user;
      if(!viewer || !/^\d{1,30}$/.test(viewer.id) || !viewer.username || viewer.username.toLowerCase() !== this.ports.username().toLowerCase())throw new Error('viewer');this.viewer = viewer.id;
      if(preview){
        const raw: Invite = p.resource_response.data as Invite;
        if(!raw?.board || raw.board.id !== item!.boardId || raw.invited_user?.id !== item!.invitedUser || viewer.id !== item!.invitedUser || !['new','accepted'].includes(raw.status))throw new Error('target');
        const accepted: boolean = raw.status === 'accepted';if(accepted)this.uncertain.delete(target);
        store.boardInvitationPreview = JSON.parse(JSON.stringify(item)) as PinmonyBoardInvitation;store.boardInvitationPreview.status = raw.status;store.boardInvitationPreview.invitedUsername = /^[A-Za-z0-9_]+$/.test(viewer.username || '') ? viewer.username : item!.invitedUsername;store.boardInvitationPreview.invitedName = viewer.full_name || viewer.username || item!.invitedName;store.boardInvitationPreview.invitedAvatarColorIndex = Number.isInteger(viewer.avatar_color_index) && viewer.avatar_color_index! >= 1 && viewer.avatar_color_index! <= 10 ? viewer.avatar_color_index : undefined;store.boardInvitationPreview.invitedAvatar = this.image(viewer.image_medium_url || viewer.image_small_url) || item!.invitedAvatar;
        store.invitationBusy = this.uncertain.has(target);if(accepted){store.invitationBannerVisible = false;store.joinedBoardName = store.boardInvitationPreview.invitedName || '';store.joinedBoardUsername = store.boardInvitationPreview.invitedUsername || '';store.joinedBoardAvatarColorIndex = store.boardInvitationPreview.invitedAvatarColorIndex || 0;store.joinedBoardAvatar = store.boardInvitationPreview.invitedAvatar || this.ports.avatar();}
      }else {
        const data: Invite[] = p.resource_response.data as Invite[];if(p.resource_response.endpoint_name !== 'v3_user_board_invites' || !Array.isArray(data) || data.length > 1000)throw new Error('list');
        const items: PinmonyBoardInvitation[] = data.filter((v: Invite): boolean => v.status === 'new' && v.invited_user?.id === viewer.id).slice(0,100).map((v: Invite): PinmonyBoardInvitation => this.map(v));
        const targets: Set<string> = new Set<string>(items.map((entry: PinmonyBoardInvitation): string => entry.boardId + ':' + entry.invitedUser));
        this.uncertain.forEach((key: string): void => { if(!targets.has(key))this.uncertain.delete(key); });
        store.boardInvitations = {token:token,page:this.page,loading:false,busy:false,uncertain:items.some((entry: PinmonyBoardInvitation): boolean => this.uncertain.has(entry.boardId + ':' + entry.invitedUser)),error:'',feedback:'',items:items};
        PinmonyRuntimeLog.info('BoardInviteListTrace: ready count=' + items.length.toString());
      }
      store.invitationReadPage = this.page;
    }catch (_) {if(this.live(revision)){if(preview){store.invitationBusy = true;this.ports.feedback(PinmonyI18n.message("pm_unable_to_load_invitation_status_preview_it_again_bc00bb66"));}else if(store.boardInvitations){const next: PinmonyBoardInvitations = JSON.parse(JSON.stringify(store.boardInvitations)) as PinmonyBoardInvitations;next.loading = false;next.error = PinmonyI18n.message("pm_unable_to_load_board_invitations_please_retry_1e408667");store.boardInvitations = next;}}}
    finally {if(revision === this.revision)this.reading = false;}
  }
  async decline(item: PinmonyBoardInvitation): Promise<void> { await this.respondFromList(item, false); }
  async acceptFromList(item: PinmonyBoardInvitation): Promise<void> { await this.respondFromList(item, true); }
  private async respondFromList(item: PinmonyBoardInvitation, accept: boolean): Promise<void> {
    const store: PinmonyInboxStore = this.ports.store(), state: PinmonyBoardInvitations | undefined = store.boardInvitations;
    const target: string = item.boardId + ':' + item.invitedUser;
    if(this.declining || this.preview || !this.live(this.revision) || this.page !== this.ports.session().origin + '/inbox/' ||
      !state || state.page !== this.page || state.token !== store.boardInvitationToken || state.loading || state.busy ||
      state.uncertain || item.status !== 'new' || item.invitedUser !== this.viewer || this.uncertain.has(target) ||
      !state.items.some((entry: PinmonyBoardInvitation): boolean => entry.boardId === item.boardId && entry.invitedUser === item.invitedUser && entry.createdAt === item.createdAt && entry.boardUrl === item.boardUrl))return;
    this.declining = true; this.uncertain.add(target);
    const next: PinmonyBoardInvitations = JSON.parse(JSON.stringify(state)) as PinmonyBoardInvitations;
    next.busy = true; next.error = ''; store.boardInvitations = next;
    const revision: number = this.revision, account: string = this.account;
    try {
      const reply: Response = await this.request(accept ? 'update' : 'delete',{board_id:item.boardId,invited_user_id:item.invitedUser},target,revision);
      const resource: Resource = reply.resource_response, data: Invite = resource.data as Invite;
      if(resource.endpoint_name !== (accept ? 'v3_accept_board_collaborator_invite' : 'v3_decline_or_delete_board_collaborator_invite') ||
        data?.board?.id !== item.boardId || data.invited_user?.id !== item.invitedUser || data.status !== (accept ? 'accepted' : 'new') ||
        reply.client_context?.user?.id !== this.viewer)throw new Error('unconfirmed');
      if(!this.live(revision))return;
      this.uncertain.delete(target);
      const confirmed: PinmonyBoardInvitations = JSON.parse(JSON.stringify(next)) as PinmonyBoardInvitations;
      confirmed.busy = false; confirmed.uncertain = false;
      confirmed.items = confirmed.items.filter((entry: PinmonyBoardInvitation): boolean => entry.boardId !== item.boardId || entry.invitedUser !== item.invitedUser);
      store.boardInvitations = confirmed;
      if(accept)this.ports.feedback(PinmonyI18n.message('pm_you_have_joined_save_pins_and_plan_together_with_collaborators_23584a97'));
    } catch(error) {
      const retry: boolean = error instanceof PinmonyAuxiliaryNotSent || error instanceof PinmonyAuxiliaryRejected;
      if(retry && account === this.client.key())this.uncertain.delete(target);
      if(this.live(revision)) {
        const failed: PinmonyBoardInvitations = JSON.parse(JSON.stringify(next)) as PinmonyBoardInvitations;
        failed.busy = false; failed.uncertain = !retry;
        failed.error = PinmonyI18n.message(accept ? (retry ? 'pm_invitation_was_not_accepted_please_retry_fd33b3d4' : 'pm_join_result_not_confirmed_preview_again_to_check_it_will_not_be__33091292') : (retry ? 'pm_invitation_decline_failed' : 'pm_invitation_decline_uncertain'));
        store.boardInvitations = failed;
      }
    } finally { this.declining = false; }
  }
  async declinePreview(): Promise<void> {
    const store: PinmonyInboxStore = this.ports.store(), item: PinmonyBoardInvitation | undefined = store.boardInvitationPreview;
    if(this.declining || !this.preview || !this.live(this.revision) || !item || store.invitationBusy || !store.invitationBannerVisible ||
      item.status !== 'new' || item.boardUrl !== this.page || item.invitedUser !== this.viewer)return;
    const target: string = item.boardId + ':' + item.invitedUser;
    if(this.uncertain.has(target))return;
    this.declining = true; this.uncertain.add(target); store.invitationBusy = true;
    const revision: number = this.revision, account: string = this.account;
    try {
      const options: Options = {board_id:item.boardId,invited_user_id:item.invitedUser};
      const reply: Response = JSON.parse(await this.client.request(this.ports.session().origin + '/inbox/','BoardInviteResource','delete',options,'invites',target,
        (): boolean => this.live(revision))) as Response;
      const resource: Resource = reply.resource_response, data: Invite = resource?.data as Invite;
      if(resource?.status === 'failure' && typeof resource.code === 'number' && resource.code !== 0)throw new PinmonyAuxiliaryRejected('rejected');
      if(resource?.status !== 'success' || resource.code !== 0 || resource.error || resource.endpoint_name !== 'v3_decline_or_delete_board_collaborator_invite' ||
        data?.board?.id !== item.boardId || data.invited_user?.id !== item.invitedUser || data.status !== 'new' || reply.client_context?.user?.id !== this.viewer)throw new Error('unconfirmed');
      if(!this.live(revision))return;
      this.uncertain.delete(target); store.invitationBusy = false; store.invitationBannerVisible = false; store.boardInvitationPreview = undefined;
      if(store.boardInvitations) {
        const next: PinmonyBoardInvitations = JSON.parse(JSON.stringify(store.boardInvitations)) as PinmonyBoardInvitations;
        next.items = next.items.filter((entry: PinmonyBoardInvitation): boolean => entry.boardId !== item.boardId || entry.invitedUser !== item.invitedUser);
        store.boardInvitations = next;
      }
    } catch(error) {
      const retry: boolean = error instanceof PinmonyAuxiliaryNotSent || error instanceof PinmonyAuxiliaryRejected;
      if(retry && account === this.client.key())this.uncertain.delete(target);
      if(this.live(revision)) { store.invitationBusy = !retry; this.ports.feedback(PinmonyI18n.message(retry ? 'pm_invitation_decline_failed' : 'pm_invitation_decline_uncertain')); }
    } finally { this.declining = false; }
  }
  async accept(): Promise<void> {
    const store: PinmonyInboxStore = this.ports.store(),item: PinmonyBoardInvitation | undefined = store.boardInvitationPreview;
    if(!this.preview || !this.live(this.revision) || !item || store.invitationBusy || !store.invitationBannerVisible || item.status !== 'new' || item.boardUrl !== this.page || item.invitedUser !== this.viewer)return;
    const target: string = item.boardId + ':' + item.invitedUser;if(this.uncertain.has(target))return;this.uncertain.add(target);store.invitationBusy = true;
    const revision: number = this.revision,account: string = this.account;
    try {
      const p: Response = await this.request('update',{board_id:item.boardId,invited_user_id:item.invitedUser},target,revision),r: Resource = p.resource_response,data: Invite = r.data as Invite;
      if(r.endpoint_name !== 'v3_accept_board_collaborator_invite' || data?.status !== 'accepted' || data.board?.id !== item.boardId || data.invited_user?.id !== item.invitedUser || p.client_context?.user && p.client_context.user.id !== this.viewer)throw new Error('unconfirmed');
      if(!this.live(revision))return;this.uncertain.delete(target);store.boardInvitationPreview = JSON.parse(JSON.stringify(item)) as PinmonyBoardInvitation;store.boardInvitationPreview.status = 'accepted';store.invitationBusy = false;store.invitationBannerVisible = false;store.joinedBoardName = item.invitedName || '';store.joinedBoardUsername = item.invitedUsername || '';store.joinedBoardAvatarColorIndex = item.invitedAvatarColorIndex || 0;store.joinedBoardAvatar = item.invitedAvatar || this.ports.avatar();this.ports.feedback(PinmonyI18n.message("pm_you_have_joined_save_pins_and_plan_together_with_collaborators_23584a97"));
    }catch (error){const retry: boolean = error instanceof PinmonyAuxiliaryNotSent || error instanceof PinmonyAuxiliaryRejected;if(retry && account === this.client.key())this.uncertain.delete(target);if(this.live(revision)){store.invitationBusy = !retry;this.ports.feedback(retry ? PinmonyI18n.message("pm_invitation_was_not_accepted_please_retry_fd33b3d4") : PinmonyI18n.message("pm_join_result_not_confirmed_preview_again_to_check_it_will_not_be__33091292"));}}
  }
}
