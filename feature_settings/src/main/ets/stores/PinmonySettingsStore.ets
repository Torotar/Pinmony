import { PinmonyAccountSettings } from '../models/PinmonyAccountSettings';
import { NotificationGroup } from '../models/PinmonyNotifications';
import { SocialPermissions, emptySocialPermissions } from '../models/PinmonySocialPermissions';
@Observed
export class PinmonySettingsStore {
  screen: string = 'root';
  notifications: NotificationGroup[] = [];
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
  reset(): void { this.token++; this.notifications = []; this.social = emptySocialPermissions(); this.screen = 'root'; this.confirmOpen = false; this.recommendationTab = 'ai'; this.data = undefined; this.loading = false; this.busy = false; this.writeUncertain = false; this.error = ''; }
  back(): boolean {
    if (this.busy) return true;
    if (this.confirmOpen) { this.confirmOpen = false; return true; }
    if (this.screen === 'root') return false;
    this.token++;
    this.screen = ['socialFriends','socialFollowers','socialFollowing','socialOthers'].includes(this.screen) ? 'socialMessages' : ['socialMessages','socialBlocked','socialMentions'].includes(this.screen) ? 'social' : ['birthdate', 'gender', 'country'].includes(this.screen) ? 'personal' : this.screen === 'personal' ? 'account' : this.screen === 'theme' ? this.themeReturn : 'root';
    this.loading = false;
    if (this.screen === 'root') this.error = '';
    return true;
  }
}

