import { PinmonyAccountSettings } from '../models/PinmonyAccountSettings';
import { NotificationGroup } from '../models/PinmonyNotifications';
@Observed
export class PinmonySettingsStore {
  screen: string = 'root';
  notifications: NotificationGroup[] = [];
  recommendationTab: string = 'ai';
  themeReturn: string = 'display';
  confirmOpen: boolean = false;
  pendingPrivate: boolean = false;
  data: PinmonyAccountSettings | undefined = undefined;
  loading: boolean = false;
  busy: boolean = false;
  error: string = '';
  token: number = 0;
  reset(): void { this.token++; this.notifications = []; this.screen = 'root'; this.confirmOpen = false; this.recommendationTab = 'ai'; this.data = undefined; this.loading = false; this.busy = false; this.error = ''; }
  back(): boolean {
    if (this.busy) return true;
    if (this.confirmOpen) { this.confirmOpen = false; return true; }
    if (this.screen === 'root') return false;
    this.token++;
    this.screen = ['birthdate', 'gender', 'country'].includes(this.screen) ? 'personal' : this.screen === 'personal' ? 'account' : this.screen === 'theme' ? this.themeReturn : 'root';
    this.loading = false;
    if (this.screen === 'root') this.error = '';
    return true;
  }
}

