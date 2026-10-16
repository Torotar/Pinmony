import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { PinmonyInboxCache } from '../services/PinmonyInboxCache';
import { PinmonyInboxSnapshot } from '../models/PinmonyInbox';
import { PinmonyInboxFlowSnapshot } from '../models/PinmonyInboxFlow';

@Observed
export class PinmonyInboxStore {
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
