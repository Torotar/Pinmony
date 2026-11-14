import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBoardInviteLink, parseBoardInviteLink } from 'common_network';
import { PinmonyInboxStore, PinmonyBoardInvitation, PinmonyBoardInvitations } from 'feature_inbox';
import { PinmonyAuxiliaryPorts, PinmonyBusinessAuxiliaryClient, PinmonyAuxiliaryNotSent, PinmonyAuxiliaryRejected } from './PinmonyBusinessAuxiliaryClient';
interface User { avatar_color_index?: number; id: string; username?: string; full_name?: string; image_medium_url?: string; image_large_url?: string; image_small_url?: string; }
interface Board { id: string; url: string; name?: string; image_thumbnail_url?: string; image_cover_url?: string; }
interface Invite { board: Board; invited_by_user: User; invited_user: User; status: string; type?: string; created_at?: string; }
interface Resource { status: string; code: number; error?: Object; endpoint_name?: string; data: Invite | Invite[]; }
interface Response { resource_response: Resource;client_context?: Client; }
interface Client {user?: User;is_authenticated?: boolean;}
interface Options {current_user?: boolean;field_set_key?: string;board_id?: string;invited_user_id?: string;}
interface LinkBoardResponse { resource_response: LinkBoardResource; client_context?: Client; }
interface LinkBoardResource { status: string; code: number; endpoint_name?: string; error?: Object; data: Board; }
interface LinkLandResponse { resource_response: LinkLandResource; client_context?: Client; }
interface LinkLandResource { status: string; code: number; endpoint_name: string; error?: Object; data: LinkLandData; }
interface LinkLandData { type: string; board?: Board; from_user_id?: string; is_accepted?: boolean; }
interface LinkBoardOptions { username: string; slug: string; field_set_key: string; is_mobile_fork: boolean; }
interface LinkBannerOptions { board_id: string; field_set_key: string; invite_code: string; invited_user_id: string; }
interface LinkLandOptions { url: string; data: LinkLandOptionsData; send_as_json: boolean; }
interface LinkLandOptionsData { invite_code: string; }
export interface PinmonyBoardInvitationNativePorts extends PinmonyAuxiliaryPorts {store: () => PinmonyInboxStore;page: () => string;active: () => boolean;username: () => string;avatar: () => string;feedback: (message: string) => void;}
export class PinmonyBoardInvitationNative {
  private readonly ports: PinmonyBoardInvitationNativePorts;private readonly client: PinmonyBusinessAuxiliaryClient;
  private revision: number = 0;private account: string = '';private preview: boolean = false;private viewer: string = '';private page: string = '';private uncertain: Set<string> = new Set<string>();
  private declining: boolean = false;
  private reading: boolean = false;
  private linkClient: PinmonyBusinessAuxiliaryClient;
  private linkRevision: number = 0;
  private linkAccount: string = '';
  private linkLands: Map<string, string> = new Map<string, string>();
  constructor(ports: PinmonyBoardInvitationNativePorts){this.ports = ports;this.client = new PinmonyBusinessAuxiliaryClient(ports);this.linkClient = new PinmonyBusinessAuxiliaryClient(ports);}
  cancelLink(): void { this.linkRevision++; this.linkClient.pause(); }
  async resolveLink(link: PinmonyBoardInviteLink, current: () => boolean): Promise<PinmonyBoardInvitation> {
    this.cancelLink();
    const verified: PinmonyBoardInviteLink | undefined = parseBoardInviteLink(link.boardUrl + '?invite_code=' + encodeURIComponent(link.inviteCode) + '&board_collab_inviter=true&inviter_user_id=' + link.inviterUserId);
    if (!verified || verified.boardUrl !== link.boardUrl) throw new Error('invite-link');
    const generation: number = this.linkRevision, account: string = this.linkClient.key();
    if (this.linkAccount !== account) { this.linkLands.clear(); this.linkAccount = account; }
    const live = (): boolean => !!account && generation === this.linkRevision && account === this.linkClient.key() && current();
    const page: string = this.ports.session().origin + link.boardUrl.slice('https://www.pinterest.com'.length);
    const parts: string[] = page.slice(this.ports.session().origin.length).split('/');
    const lookupOptions: LinkBoardOptions = { username: parts[1], slug: decodeURIComponent(parts[2]), field_set_key: 'profile_grid_item', is_mobile_fork: true };
    const boardReply: LinkBoardResponse = JSON.parse(await this.linkClient.request(page, 'BoardResource', 'get',
      lookupOptions,
      'invite-link', '', live)) as LinkBoardResponse;
    const resource: LinkBoardResource = boardReply.resource_response, board: Board | undefined = resource?.data;
    const viewer: User | undefined = boardReply.client_context?.user;
    if (!live() || boardReply.client_context?.is_authenticated === false || resource?.status !== 'success' || resource.code !== 0 || resource.error || !/^\d{1,30}$/.test(board?.id || '') ||
      !/^\d{1,30}$/.test(viewer?.id || '') || viewer?.username?.toLowerCase() !== this.ports.username().toLowerCase()) throw new Error('invite-board');
    const boardId: string = board!.id, viewerId: string = viewer!.id;
    PinmonyRuntimeLog.info('BoardInviteLinkTrace: stage=board-ready');
    const read = async (): Promise<PinmonyBoardInvitation> => {
      const bannerOptions: LinkBannerOptions = { board_id: boardId, field_set_key: 'boardBanner', invite_code: link.inviteCode, invited_user_id: viewerId };
      const reply: Response = JSON.parse(await this.linkClient.request(page, 'BoardInviteResource', 'get',
        bannerOptions,
        'invite-link', boardId + ':' + viewerId, live)) as Response;
      const r: Resource = reply.resource_response, raw: Invite = r?.data as Invite;
      if (!live() || reply.client_context?.is_authenticated === false || r?.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'v3_get_user_board_invite' ||
        raw?.board?.id !== boardId || raw.type !== 'collaboratorinvite' || raw.invited_user?.id !== viewerId || raw.invited_by_user?.id !== link.inviterUserId ||
        reply.client_context?.user?.id !== viewerId) throw new Error('invite-status');
      // boardBanner returns only board.id. Reuse this request's verified board lookup,
      // while preserving any banner URL so conflicting server identities still fail closed.
      const invitationBoard: Board = { id: boardId, url: raw.board.url || board?.url || page,
        name: raw.board.name || board?.name, image_thumbnail_url: raw.board.image_thumbnail_url || board?.image_thumbnail_url,
        image_cover_url: raw.board.image_cover_url || board?.image_cover_url };
      const invitation: Invite = { board: invitationBoard, invited_by_user: raw.invited_by_user,
        invited_user: raw.invited_user, status: raw.status, type: raw.type, created_at: raw.created_at };
      const mapped: PinmonyBoardInvitation = this.map(invitation);
      if (decodeURIComponent(mapped.boardUrl) !== decodeURIComponent(page)) throw new Error('invite-board-route');
      PinmonyRuntimeLog.info('BoardInviteLinkTrace: stage=banner-ready');
      return mapped;
    };
    let item: PinmonyBoardInvitation = await read();
    this.ports.store().boardInvitations = undefined;
    this.ports.store().invitationReadPage = '';
    if (item.status === 'new' && this.linkLands.get(link.inviteCode) === 'pending') {
      const options: Options = { current_user: true, field_set_key: 'news' };
      const inbox: Response = JSON.parse(await this.linkClient.request(page, 'BoardInvitesResource', 'get', options, 'invites', '', live)) as Response;
      const r: Resource = inbox.resource_response, items: Invite[] = r?.data as Invite[];
      if (!live() || inbox.client_context?.is_authenticated === false || r?.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'v3_user_board_invites' ||
        inbox.client_context?.user?.id !== viewerId || !Array.isArray(items) || !items.some((v: Invite): boolean =>
          v.board?.id === boardId && v.invited_user?.id === viewerId && v.invited_by_user?.id === link.inviterUserId && v.status === 'new')) throw new Error('invite-land-uncertain');
      this.linkLands.set(link.inviteCode, 'confirmed');
    }
    if (item.status === 'new' && !this.linkLands.has(link.inviteCode)) {
      if (this.linkLands.size >= 100) throw new Error('invite-land-limit');
      const landOptions: LinkLandOptions = { url: '/v3/invite_code/attribution/land/', data: { invite_code: link.inviteCode }, send_as_json: true };
      this.linkLands.set(link.inviteCode, 'pending');
      let landed: LinkLandResponse;
      try {
        landed = JSON.parse(await this.linkClient.request(page, 'ApiResource', 'create', landOptions, 'invite-link', link.inviteCode, live)) as LinkLandResponse;
      } catch (error) {
        if (error instanceof PinmonyAuxiliaryNotSent && account === this.linkAccount) this.linkLands.delete(link.inviteCode);
        throw new Error('invite-land-unconfirmed');
      }
      const r: LinkLandResource = landed.resource_response;
      if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0 && live()) this.linkLands.delete(link.inviteCode);
      if (!live() || landed.client_context?.is_authenticated === false || r?.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'v3_log_invite_land_attribution' ||
        r.data?.type !== 'invitecode' || r.data.board?.id !== boardId || r.data.from_user_id !== link.inviterUserId || typeof r.data.is_accepted !== 'boolean') throw new Error('invite-land');
      // Attribution and board collaboration have separate acceptance states.
      // Only the subsequent BoardInviteResource response owns collaboration status.
      this.linkLands.set(link.inviteCode, 'confirmed');
      PinmonyRuntimeLog.info('BoardInviteLinkTrace: stage=land-confirmed');
      item = await read();
    }
    if (!live()) throw new Error('invite-stale');
    this.ports.store().boardInvitations = undefined;
    this.ports.store().invitationReadPage = '';
    PinmonyRuntimeLog.info('BoardInviteLinkTrace: stage=resolved');
    return item;
  }
  pause(): void {this.cancelLink();this.revision++;this.client.pause();this.reading = false;this.ports.store().invitationReadPage = '';}
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
