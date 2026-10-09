import { PinWebInboxCache } from '../services/PinWebInboxCache';
import { PinWebInboxSnapshot } from '../models/PinWebInbox';
import { PinWebInboxFlowSnapshot } from '../models/PinWebInboxFlow';

@Observed
export class PinWebInboxStore {
  onNavigationChange: (() => void) | undefined = undefined;
  inboxSession: number = 0;
  private _inboxFlow: PinWebInboxFlowSnapshot | undefined = undefined;
  get inboxFlow(): PinWebInboxFlowSnapshot | undefined { return this._inboxFlow; }
  set inboxFlow(value: PinWebInboxFlowSnapshot | undefined) {
    if (this._inboxFlow === value) return;
    this._inboxFlow = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  inboxUrl: string = '';
  inboxRequestToken: number = 0;
  pendingInboxSection: string = '';
  readonly inboxCache: PinWebInboxCache = new PinWebInboxCache();
  inboxActionsReady: boolean = false;
  inboxSectionReady: boolean = false;
  inboxRetainedContent: boolean = false;
  inboxScrollOffset: number = 0;
  restoringInboxSection: string = '';
  inbox: PinWebInboxSnapshot | undefined = undefined;
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
