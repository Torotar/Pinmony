import { PinmonyBoardInvitation } from 'feature_inbox';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyAuxiliaryPorts, PinmonyBusinessAuxiliaryClient } from './PinmonyBusinessAuxiliaryClient';
import { PIN_NATIVE_INBOX_UPDATES_ENABLED } from './PinmonyInboxUpdatesNativeReads';

export const PIN_BOARD_INVITATION_NOTICE_POLL_MS: number = 5000;
interface PinmonyInviteNoticeUser { id: string; username?: string; full_name?: string; image_medium_url?: string; image_large_url?: string; avatar_color_index?: number; }
interface PinmonyInviteNoticeBoard { id: string; url: string; name?: string; }
interface PinmonyInviteNoticeRow { board: PinmonyInviteNoticeBoard; invited_user: PinmonyInviteNoticeUser; invited_by_user: PinmonyInviteNoticeUser; status: string; created_at?: string; }
interface PinmonyInviteNoticeResource { status: string; code: number; error?: Object; endpoint_name: string; data: PinmonyInviteNoticeRow[]; }
interface PinmonyInviteNoticeClient { user?: PinmonyInviteNoticeUser; }
interface PinmonyInviteNoticeResponse { resource_response: PinmonyInviteNoticeResource; client_context?: PinmonyInviteNoticeClient; }
interface PinmonyInviteNoticeOptions { current_user: boolean; field_set_key: string; }
export interface PinmonyBoardInvitationNoticePorts extends PinmonyAuxiliaryPorts {
  active: () => boolean;
  username: () => string;
  observed: (items: PinmonyBoardInvitation[]) => void;
}
// Foreground invitation reads feed the shared message notification publisher.
export class PinmonyBoardInvitationNotice {
  private readonly ports: PinmonyBoardInvitationNoticePorts;
  private readonly client: PinmonyBusinessAuxiliaryClient;
  private identity: string = '';
  private revision: number = 0;
  private lastPoll: number = -1;
  private busy: boolean = false;
  constructor(ports: PinmonyBoardInvitationNoticePorts) { this.ports = ports; this.client = new PinmonyBusinessAuxiliaryClient(ports); }
  pause(): void { this.revision++; this.client.pause(); this.busy = false; }
  reset(): void { this.pause(); this.identity = ''; this.lastPoll = -1; }
  private image(value: string | undefined): string { return typeof value === 'string' && value.length <= 2048 && /^https:\/\/i\.pinimg\.com\//i.test(value) ? value : ''; }
  private map(row: PinmonyInviteNoticeRow, viewer: string): PinmonyBoardInvitation {
    const board: PinmonyInviteNoticeBoard = row.board, sender: PinmonyInviteNoticeUser = row.invited_by_user;
    if(!board || !sender || !/^\d{1,30}$/.test(board.id) || !/^\d{1,30}$/.test(sender.id) || row.invited_user?.id !== viewer)throw new Error('identity');
    const origin: string = this.ports.session().origin;
    if(typeof board.url !== 'string')throw new Error('route');
    const url: string = board.url.startsWith('/') ? origin + board.url : board.url;
    if(!url.startsWith(origin + '/') || !/^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(url.slice(origin.length)))throw new Error('route');
    return {boardId:board.id,boardUrl:url,boardName:typeof board.name === 'string' ? board.name.slice(0,200) : '',imageUrl:'',
      inviter:typeof sender.full_name === 'string' ? sender.full_name.slice(0,200) : (sender.username || '').slice(0,200),
      inviterUsername:/^[A-Za-z0-9_]+$/.test(sender.username || '') ? sender.username : undefined,
      inviterAvatar:this.image(sender.image_medium_url) || this.image(sender.image_large_url),
      inviterAvatarColorIndex:Number.isInteger(sender.avatar_color_index) && sender.avatar_color_index! >= 1 && sender.avatar_color_index! <= 10 ? sender.avatar_color_index : undefined,
      invitedUser:viewer,invitedAvatar:'',createdAt:typeof row.created_at === 'string' ? row.created_at.slice(0,200) : '',status:'new'};
  }
  async poll(): Promise<void> {
    const identity: string = this.client.key();
    if(!PIN_NATIVE_INBOX_UPDATES_ENABLED || !this.ports.active() || !identity) { this.pause(); return; }
    if(identity !== this.identity) { this.reset(); this.identity = identity; }
    if(this.busy || this.lastPoll >= 0 && Date.now() - this.lastPoll < PIN_BOARD_INVITATION_NOTICE_POLL_MS)return;
    this.lastPoll = Date.now(); this.busy = true;
    const revision: number = this.revision;
    const current = (): boolean => revision === this.revision && identity === this.client.key() && this.ports.active();
    try {
      const options: PinmonyInviteNoticeOptions = {current_user:true,field_set_key:'news'};
      const response: PinmonyInviteNoticeResponse = JSON.parse(await this.client.request(this.ports.session().origin + '/inbox/',
        'BoardInvitesResource','get',options,'invites','',current)) as PinmonyInviteNoticeResponse;
      if(!current())return;
      const resource = response.resource_response, viewer: PinmonyInviteNoticeUser | undefined = response.client_context?.user;
      if(resource?.status !== 'success' || resource.code !== 0 || resource.error || resource.endpoint_name !== 'v3_user_board_invites' ||
        !Array.isArray(resource.data) || resource.data.length > 1000 || !viewer || !/^\d{1,30}$/.test(viewer.id) ||
        !this.ports.username() || viewer.username?.toLowerCase() !== this.ports.username().toLowerCase())throw new Error('response');
      const items: PinmonyBoardInvitation[] = resource.data.filter((row: PinmonyInviteNoticeRow): boolean => !!row && row.status === 'new' && row.invited_user?.id === viewer.id)
        .map((row: PinmonyInviteNoticeRow): PinmonyBoardInvitation => this.map(row,viewer.id));
      this.ports.observed(items);
      PinmonyRuntimeLog.info('BoardInviteNoticeTrace: checked');
    } catch (_) { if(current())PinmonyRuntimeLog.warn('BoardInviteNoticeTrace: read unavailable'); }
    finally { if(revision === this.revision)this.busy = false; }
  }
}
