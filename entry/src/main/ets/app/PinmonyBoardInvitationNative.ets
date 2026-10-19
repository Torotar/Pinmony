import { PinmonyI18n } from 'common_foundation';
import { PinmonyInboxStore, PinmonyBoardInvitation, PinmonyBoardInvitations } from 'feature_inbox';
import { PinmonyAuxiliaryPorts, PinmonyBusinessAuxiliaryClient, PinmonyAuxiliaryNotSent, PinmonyAuxiliaryRejected } from './PinmonyBusinessAuxiliaryClient';
interface User { id: string; username?: string; full_name?: string; image_medium_url?: string; image_large_url?: string; image_small_url?: string; }
interface Board { id: string; url: string; name?: string; image_thumbnail_url?: string; image_cover_url?: string; }
interface Invite { board: Board; invited_by_user: User; invited_user: User; status: string; created_at?: string; }
interface Resource { status: string; code: number; endpoint_name?: string; data: Invite | Invite[]; }
interface Response { resource_response: Resource;client_context?: Client; }
interface Client {user?: User;}
interface Options {current_user?: boolean;field_set_key?: string;board_id?: string;invited_user_id?: string;}
export interface PinmonyBoardInvitationNativePorts extends PinmonyAuxiliaryPorts {store: () => PinmonyInboxStore;page: () => string;active: () => boolean;username: () => string;avatar: () => string;feedback: (message: string) => void;}
export class PinmonyBoardInvitationNative {
  private readonly ports: PinmonyBoardInvitationNativePorts;private readonly client: PinmonyBusinessAuxiliaryClient;
  private revision: number = 0;private account: string = '';private preview: boolean = false;private viewer: string = '';private page: string = '';private uncertain: Set<string> = new Set<string>();
  constructor(ports: PinmonyBoardInvitationNativePorts){this.ports = ports;this.client = new PinmonyBusinessAuxiliaryClient(ports);}
  pause(): void {this.revision++;this.client.pause();}
  private live(revision: number): boolean {return revision === this.revision && this.client.key() === this.account && this.ports.page() === this.page && this.ports.active();}
  private image(v: string | undefined): string {return typeof v === 'string' && v.length <= 2048 && /^https:\/\/i\.pinimg\.com\//i.test(v) ? v : '';}
  private map(v: Invite): PinmonyBoardInvitation {
    const b: Board = v.board,to: User = v.invited_user,from: User = v.invited_by_user;
    if(!/^\d{1,30}$/.test(b?.id) || !/^\d{1,30}$/.test(to?.id) || !/^\d{1,30}$/.test(from?.id))throw new Error('invite');
    const url: string = b.url.startsWith('/') ? this.ports.session().origin + b.url : b.url;
    if(!url.startsWith(this.ports.session().origin + '/') || !/^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(url.slice(this.ports.session().origin.length)) || !['new','accepted'].includes(v.status))throw new Error('route');
    return {boardId:b.id,boardUrl:url,boardName:(b.name || '').slice(0,200),imageUrl:this.image(b.image_thumbnail_url || b.image_cover_url),inviter:(from.full_name || from.username || '').slice(0,200),inviterAvatar:this.image(from.image_medium_url || from.image_large_url),invitedUser:to.id,invitedAvatar:this.image(to.image_medium_url),createdAt:(v.created_at || '').slice(0,200),status:v.status};
  }
  private async request(verb: string,options: Options,target: string,revision: number): Promise<Response> {
    const value: Response = JSON.parse(await this.client.request(this.page,target ? 'BoardInviteResource' : 'BoardInvitesResource',verb,options,'invites',target,(): boolean => this.live(revision))) as Response;
    const r: Resource = value.resource_response;
    if(r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)throw new PinmonyAuxiliaryRejected('rejected');
    if(!r || r.status !== 'success' || r.code !== 0)throw new Error('response');return value;
  }
  async open(preview: boolean): Promise<void> {
    const store: PinmonyInboxStore = this.ports.store(),item: PinmonyBoardInvitation | undefined = store.boardInvitationPreview;
    if(!this.client.key() || !this.ports.active() || preview && !item)return;
    this.pause();const account: string = this.client.key();if(account !== this.account)this.uncertain.clear();this.account = account;this.page = this.ports.page();this.preview = preview;this.viewer = '';
    const revision: number = this.revision,token: number = ++store.boardInvitationToken;
    store.invitationReadPage = this.page;if(preview)store.invitationBusy = true;else store.boardInvitations = {token:token,page:this.page,loading:true,busy:false,uncertain:false,error:'',feedback:'',items:[]};
    try {
      const target: string = preview ? item!.boardId + ':' + item!.invitedUser : '',options: Options = preview ? {board_id:item!.boardId,invited_user_id:item!.invitedUser,field_set_key:'boardEdit'} : {current_user:true,field_set_key:'news'};
      const p: Response = await this.request('get',options,target,revision);if(!this.live(revision))return;
      const viewer: User | undefined = p.client_context?.user;
      if(!viewer || !/^\d{1,30}$/.test(viewer.id) || !viewer.username || viewer.username.toLowerCase() !== this.ports.username().toLowerCase())throw new Error('viewer');this.viewer = viewer.id;
      if(preview){
        const raw: Invite = p.resource_response.data as Invite;
        if(!raw?.board || raw.board.id !== item!.boardId || raw.invited_user?.id !== item!.invitedUser || viewer.id !== item!.invitedUser || !['new','accepted'].includes(raw.status))throw new Error('target');
        const accepted: boolean = raw.status === 'accepted';if(accepted)this.uncertain.delete(target);
        store.boardInvitationPreview = JSON.parse(JSON.stringify(item)) as PinmonyBoardInvitation;store.boardInvitationPreview.status = raw.status;store.boardInvitationPreview.invitedAvatar = this.image(viewer.image_medium_url || viewer.image_small_url) || item!.invitedAvatar;
        store.invitationBusy = this.uncertain.has(target);if(accepted){store.invitationBannerVisible = false;store.joinedBoardAvatar = store.boardInvitationPreview.invitedAvatar || this.ports.avatar();}
      }else {
        const data: Invite[] = p.resource_response.data as Invite[];if(!Array.isArray(data) || data.length > 1000)throw new Error('list');
        const items: PinmonyBoardInvitation[] = data.filter((v: Invite): boolean => v.status === 'new' && v.invited_user?.id === viewer.id).slice(0,100).map((v: Invite): PinmonyBoardInvitation => this.map(v));
        store.boardInvitations = {token:token,page:this.page,loading:false,busy:false,uncertain:false,error:'',feedback:'',items:items};
      }
    }catch (_) {if(this.live(revision)){if(preview){store.invitationBusy = true;this.ports.feedback(PinmonyI18n.message('邀请状态读取失败，请重新预览'));}else if(store.boardInvitations){const next: PinmonyBoardInvitations = JSON.parse(JSON.stringify(store.boardInvitations)) as PinmonyBoardInvitations;next.loading = false;next.error = PinmonyI18n.message('图板邀请读取失败，请重试');store.boardInvitations = next;}}}
  }
  async accept(): Promise<void> {
    const store: PinmonyInboxStore = this.ports.store(),item: PinmonyBoardInvitation | undefined = store.boardInvitationPreview;
    if(!this.preview || !this.live(this.revision) || !item || store.invitationBusy || !store.invitationBannerVisible || item.status !== 'new' || item.boardUrl !== this.page || item.invitedUser !== this.viewer)return;
    const target: string = item.boardId + ':' + item.invitedUser;if(this.uncertain.has(target))return;this.uncertain.add(target);store.invitationBusy = true;
    const revision: number = this.revision,account: string = this.account;
    try {
      const p: Response = await this.request('update',{board_id:item.boardId,invited_user_id:item.invitedUser},target,revision),r: Resource = p.resource_response,data: Invite = r.data as Invite;
      if(r.endpoint_name !== 'v3_accept_board_collaborator_invite' || data?.status !== 'accepted' || data.board?.id !== item.boardId || data.invited_user?.id !== item.invitedUser || p.client_context?.user && p.client_context.user.id !== this.viewer)throw new Error('unconfirmed');
      if(!this.live(revision))return;this.uncertain.delete(target);store.boardInvitationPreview = JSON.parse(JSON.stringify(item)) as PinmonyBoardInvitation;store.boardInvitationPreview.status = 'accepted';store.invitationBusy = false;store.invitationBannerVisible = false;store.joinedBoardAvatar = item.invitedAvatar || this.ports.avatar();this.ports.feedback(PinmonyI18n.message('你已加入！收藏 Pin 图，与合作用户一起制定计划，还有更多乐趣！'));
    }catch (error){const retry: boolean = error instanceof PinmonyAuxiliaryNotSent || error instanceof PinmonyAuxiliaryRejected;if(retry && account === this.client.key())this.uncertain.delete(target);if(this.live(revision)){store.invitationBusy = !retry;this.ports.feedback(retry ? '邀请未接受成功，请重试' : PinmonyI18n.message('加入结果未确认，请重新预览核对；不会重复接受'));}}
  }
}
