import { PinmonyAccountSettings } from '../models/PinmonyAccountSettings';
import { NotificationGroup } from '../models/PinmonyNotifications';
import { SocialPermissions, emptySocialPermissions } from '../models/PinmonySocialPermissions';
export interface PinmonyRecoverableBoard { id: string; name: string; imageUrl: string; pinCount: number; sectionCount: number; restored: boolean; }
@Observed
export class PinmonySettingsStore {
  screen: string = 'root';
  recoverableBoards: PinmonyRecoverableBoard[] = [];
  boardRecoveryReady: boolean = false;
  boardRecoveryFromProfile: boolean = false;
  rootScrollOffset: number = 0;
  notifications: NotificationGroup[] = [];
  socialMessageGroup: number = 0;
  social: SocialPermissions = emptySocialPermissions();
  recommendationTab: string = 'ai';
  themeReturn: string = 'display';
  confirmOpen: boolean = false;
  pendingPrivate: boolean = false;
  data: PinmonyAccountSettings | undefined = undefined;
  loading: boolean = false;
  busy: boolean = false;
  writeUncertain: boolean = false;
  error: string = '';
  token: number = 0;
  reset(preserveScroll: boolean = false): void { if (!preserveScroll) this.rootScrollOffset = 0; this.token++; this.notifications = []; this.recoverableBoards = []; this.boardRecoveryReady = false; this.boardRecoveryFromProfile = false; this.social = emptySocialPermissions(); this.socialMessageGroup = 0; this.screen = 'root'; this.confirmOpen = false; this.recommendationTab = 'ai'; this.data = undefined; this.loading = false; this.busy = false; this.writeUncertain = false; this.error = ''; }
  back(): boolean {
    if (this.busy) return true;
    if (this.confirmOpen) { this.confirmOpen = false; return true; }
    if (this.screen === 'boardRecovery' && this.boardRecoveryFromProfile) return false;
    if (this.screen === 'root') return false;
    this.token++;
    this.screen = ['socialFriends','socialFollowers','socialFollowing','socialOthers'].includes(this.screen) ? 'socialMessages' : ['socialComments','socialMessages','socialBlocked','socialMentions'].includes(this.screen) ? 'social' : ['birthdate', 'gender', 'country'].includes(this.screen) ? 'personal' : this.screen === 'personal' ? 'account' : this.screen === 'boardRecovery' ? 'display' : this.screen === 'theme' ? this.themeReturn : 'root';
    this.loading = false;
    if (this.screen === 'root' || !this.writeUncertain) this.error = '';
    return true;
  }
}

