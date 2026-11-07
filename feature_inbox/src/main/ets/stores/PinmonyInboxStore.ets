import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { PinmonyInboxCache } from '../services/PinmonyInboxCache';
import { PinmonyInboxSnapshot, PinmonyInboxItem } from '../models/PinmonyInbox';
import { PinmonyInboxFlowSnapshot } from '../models/PinmonyInboxFlow';

@Observed
export class PinmonyInboxStore {
  private readonly viewedUpdates: Map<string, string> = new Map<string, string>();
  isUnseenUpdate(id: string, updatedAt: string): boolean {
    const viewed: string | undefined = this.viewedUpdates.get(id);
    if (viewed === undefined) return true;
    if (!updatedAt || viewed === updatedAt) return false;
    const incomingTime: number = Date.parse(updatedAt);
    const viewedTime: number = Date.parse(viewed);
    return Number.isFinite(incomingTime) && Number.isFinite(viewedTime) ? incomingTime > viewedTime : true;
  }
  clearViewedUpdates(): void { this.viewedUpdates.clear(); }
  acknowledgeInboxUpdates(): void {
    const snapshot: PinmonyInboxSnapshot | undefined = this.inbox;
    if (!snapshot || snapshot.section !== 'updates' || snapshot.kind !== 'state' || snapshot.dataSource !== 'api' ||
      this.inboxLoading || this.inboxError || snapshot.apiError) return;
    snapshot.items.forEach((item: PinmonyInboxItem): void => {
      if (item.unread !== true || !item.id) return;
      this.viewedUpdates.delete(item.id);
      this.viewedUpdates.set(item.id, item.updatedAt || '');
    });
    const excess: number = this.viewedUpdates.size - 2000;
    let removed: number = 0;
    this.viewedUpdates.forEach((_stamp: string, id: string): void => {
      if (removed < excess) { this.viewedUpdates.delete(id); removed++; }
    });
    // Local reminder acknowledgement does not change server unread flags.
    this.inboxUpdatesUnreadCount = 0;
  }
  listSearchBack: (() => boolean) | undefined = undefined;
  private _listSection: string = '';
  get listSection(): string { return this._listSection; }
  set listSection(value: string) {
    if (this._listSection === value) return;
    this._listSection = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  inboxNativeMessagesReady: boolean = false;
  inboxNativeUpdatesReady: boolean = false;
  retainedChat: PinmonyInboxFlowSnapshot | undefined = undefined;
  chatScrollOffset: number = 0;
  chatReturnConversation: string = '';
  flowDismissed: boolean = false;
  boardInvitations: PinmonyBoardInvitations | undefined = undefined;
  boardInvitationPreview: PinmonyBoardInvitation | undefined = undefined;
  invitationBannerVisible: boolean = false;
  invitationAllVisible: boolean = false;
  invitationBusy: boolean = false;
  joinedBoardAvatar: string = '';
  joinedBoardName: string = '';
  joinedBoardUsername: string = '';
  joinedBoardAvatarColorIndex: number = 0;
  boardInvitationToken: number = 0;
  invitationReadPage: string = '';
  onNavigationChange: (() => void) | undefined = undefined;
  inboxSession: number = 0;
  private _inboxFlow: PinmonyInboxFlowSnapshot | undefined = undefined;
  get inboxFlow(): PinmonyInboxFlowSnapshot | undefined { return this._inboxFlow; }
  set inboxFlow(value: PinmonyInboxFlowSnapshot | undefined) {
    if (this._inboxFlow === value) return;
    this._inboxFlow = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  inboxUrl: string = '';
  inboxRequestToken: number = 0;
  pendingInboxSection: string = '';
  readonly inboxCache: PinmonyInboxCache = new PinmonyInboxCache();
  inboxActionsReady: boolean = false;
  inboxSectionReady: boolean = false;
  inboxRetainedContent: boolean = false;
  inboxScrollOffset: number = 0;
  restoringInboxSection: string = '';
  onUnreadChange: ((updates: boolean, messages: boolean, updatesCount: number, messagesCount: number) => void) | undefined = undefined;
  private _inboxUpdatesUnreadCount: number = 0;
  private _inboxMessagesUnreadCount: number = 0;
  get inboxUpdatesUnread(): boolean { return this._inboxUpdatesUnreadCount > 0; }
  set inboxUpdatesUnread(value: boolean) { this.inboxUpdatesUnreadCount = value ? Math.max(1, this._inboxUpdatesUnreadCount) : 0; }
  get inboxMessagesUnread(): boolean { return this._inboxMessagesUnreadCount > 0; }
  set inboxMessagesUnread(value: boolean) { this.inboxMessagesUnreadCount = value ? Math.max(1, this._inboxMessagesUnreadCount) : 0; }
  get inboxUpdatesUnreadCount(): number { return this._inboxUpdatesUnreadCount; }
  set inboxUpdatesUnreadCount(value: number) {
    if(!Number.isSafeInteger(value) || value < 0 || value === this._inboxUpdatesUnreadCount)return;
    this._inboxUpdatesUnreadCount = value;
    this.onUnreadChange?.(this.inboxUpdatesUnread, this.inboxMessagesUnread, this._inboxUpdatesUnreadCount, this._inboxMessagesUnreadCount);
  }
  get inboxMessagesUnreadCount(): number { return this._inboxMessagesUnreadCount; }
  set inboxMessagesUnreadCount(value: number) {
    if(!Number.isSafeInteger(value) || value < 0 || value === this._inboxMessagesUnreadCount)return;
    this._inboxMessagesUnreadCount = value;
    this.onUnreadChange?.(this.inboxUpdatesUnread, this.inboxMessagesUnread, this._inboxUpdatesUnreadCount, this._inboxMessagesUnreadCount);
  }
  inbox: PinmonyInboxSnapshot | undefined = undefined;
  inboxLoading: boolean = false;
  inboxError: string = '';
  private _inboxWebFlow: boolean = false;
  get inboxWebFlow(): boolean { return this._inboxWebFlow; }
  set inboxWebFlow(value: boolean) {
    if (this._inboxWebFlow === value) return;
    this._inboxWebFlow = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
}
