import { PinmonyTaskRegistry, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyAccountSettings } from '../models/PinmonyAccountSettings';
import { NotificationResult } from '../models/PinmonyNotifications';

export interface PinmonySettingsPorts {
  nativeEnabled?: () => boolean;
  nativeRequest?: (action: string,value: string) => Promise<void>;
  nativePause?: () => void;
  authenticated: () => boolean;
  foreground: () => boolean;
  epoch: () => number;
  visible: () => boolean;
  document: () => string;
  currentProfile: () => string;
  profileAddress: (page: string) => string;
  prepare: (current: () => boolean) => Promise<boolean>;
  runScript: (script: string) => Promise<string>;
  accountScript: () => string;
  notificationsScript: () => string;
  jsonText: (raw: string) => string;
}

export class PinmonySettingsController {
  private readonly store: PinmonySettingsStore;
  private readonly ports: PinmonySettingsPorts;
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private page: string = '';
  private writeDispatched: boolean = false;
  private ownedRequest: boolean = false;
  constructor(store: PinmonySettingsStore, ports: PinmonySettingsPorts) { this.store = store; this.ports = ports; }
  private allowed(): boolean { return this.ports.authenticated() && this.ports.foreground() && this.ports.visible(); }
  pause(): void {
    if(this.ports.nativeEnabled?.()){this.ports.nativePause?.();return;}
    this.generation++; this.tasks.invalidate();
    if (this.writeDispatched) { this.store.writeUncertain = true; this.store.error = '保存结果未确认，请重新读取核对；不会自动重试保存'; }
    else if (this.store.loading) this.store.error = '读取已暂停，请重试';
    this.store.loading = false;
    if (this.ownedRequest) { this.closeBridge(); this.store.busy = false; }
    this.ownedRequest = false;
    this.writeDispatched = false;
  }
  cancel(): void {
    const owned: boolean = this.ownedRequest;
    this.pause();
    if (!owned) this.closeBridge();
  }
  private closeBridge(): void {
    if(this.ports.nativeEnabled?.())return;
    try {
      if (!this.page || this.page !== this.ports.document() || !this.ports.authenticated()) return;
      this.ports.runScript('window.PinmonyAccountSettings && window.PinmonyAccountSettings.close()').catch(() => {});
    } catch (_) {}
  }
  private current(token: number, generation: number, epoch: number, page: string = ''): boolean {
    return token === this.store.token && generation === this.generation && epoch === this.ports.epoch() &&
      this.allowed() && (!page || page === this.ports.document());
  }
  async readNotifications(): Promise<void> {
    if(this.ports.nativeEnabled?.()){if(this.allowed() && this.store.screen === 'notifications')await this.ports.nativeRequest?.('notifications','');return;}
    if (!this.allowed() || this.store.loading || this.store.busy || this.store.screen !== 'notifications') return;
    const token: number = ++this.store.token, generation: number = this.generation, epoch: number = this.ports.epoch();
    const page: string = this.ports.document(); this.page = page;
    const current = (): boolean => this.current(token, generation, epoch, page) && this.store.screen === 'notifications';
    this.store.loading = true; this.store.error = ''; this.store.notifications = [];
    try {
      await this.ports.runScript(this.ports.notificationsScript());
      for (let attempt: number = 0; attempt < 80; attempt++) {
        if (!current()) return;
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyNotificationsResult)');
        if (!current()) return;
        const result: NotificationResult | null = JSON.parse(this.ports.jsonText(raw)) as NotificationResult | null;
        if (result) {
          if (!Array.isArray(result.groups) || result.groups.length > 100 || typeof result.error !== 'string' ||
              !result.groups.every((group): boolean => !!group && typeof group.key === 'string' && typeof group.label === 'string' &&
                Array.isArray(group.categories) && group.categories.length <= 200 && group.categories.every((category): boolean =>
                  !!category && typeof category.key === 'string' && typeof category.label === 'string' &&
                  Array.isArray(category.channels) && category.channels.length <= 30 && category.channels.every((channel): boolean =>
                    !!channel && typeof channel.label === 'string' && typeof channel.value === 'boolean')))) throw new Error('Invalid notifications');
          this.store.notifications = result.groups; this.store.error = result.error; return;
        }
        if (!await this.tasks.wait(250)) return;
      }
      if (current()) this.store.error = '通知设置读取超时，请重试';
    } catch (_) { if (current()) this.store.error = '通知设置读取失败，请重试'; }
    finally { if (token === this.store.token && generation === this.generation) this.store.loading = false; }
  }
  async request(action: string, value: string): Promise<void> {
    if(this.ports.nativeEnabled?.()){if(this.allowed())await this.ports.nativeRequest?.(action,value);return;}
    if (action === 'notifications') { await this.readNotifications(); return; }
    if (!this.allowed() || this.store.busy || this.store.loading) return;
    const write: boolean = ['birthdate', 'gender', 'customGender', 'country', 'aiTopic', 'aiAll', 'activityClose', 'privateProfile', 'searchPrivacy'].includes(action);
    if (write && this.store.writeUncertain) { this.store.error = '请先重新读取核对保存结果'; return; }
    const token: number = ++this.store.token, generation: number = this.generation, epoch: number = this.ports.epoch();
    let page: string = '';
    const current = (): boolean => this.current(token, generation, epoch, page);
    this.ownedRequest = true;
    this.store.busy = write; this.store.loading = !write; this.store.error = '';
    try {
      if (!await this.ports.prepare(current)) {
        if (current()) this.store.error = '当前资料会话尚未就绪，请重试'; return;
      }
      if (!current()) return;
      page = this.ports.document(); this.page = page;
      if (!this.ports.currentProfile() || this.ports.profileAddress(page) !== this.ports.currentProfile()) {
        this.store.error = '当前资料会话尚未就绪，请重试'; return;
      }
      this.writeDispatched = write;
      await this.ports.runScript(this.ports.accountScript() + '\nwindow.PinmonyAccountSettings.start(' + JSON.stringify(page) + ',' +
        token.toString() + ',' + JSON.stringify(action) + ',' + JSON.stringify(value) + '); true');
      for (let attempt: number = 0; attempt < 70; attempt++) {
        if (!current()) return;
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyAccountSettings.read())');
        if (!current()) return;
        const result: PinmonyAccountSettings = JSON.parse(this.ports.jsonText(raw)) as PinmonyAccountSettings;
        if (!result || result.token !== token || result.page !== page || typeof result.loading !== 'boolean') throw new Error('Stale settings');
        if (!result.loading) {
          if (!Array.isArray(result.countries) || result.countries.length > 400 || typeof result.email !== 'string' || result.email.length > 320 ||
              typeof result.birthdate !== 'string' || typeof result.gender !== 'string' || typeof result.customGender !== 'string' || result.customGender.length > 500 ||
              !Array.isArray(result.topics) || result.topics.length > 1000 || !Array.isArray(result.activities) || result.activities.length > 2000 ||
              typeof result.error !== 'string' || typeof result.ready !== 'boolean' || typeof result.saved !== 'boolean') throw new Error('Invalid settings');
          this.store.data = result; this.store.error = result.error;
          if (result.ready && !result.error) PinmonyRuntimeLog.info('AccountSettingsTrace: validBirthdate=' + (!!result.birthdate).toString());
          this.store.writeUncertain = write ? !result.saved : !result.ready || !!result.error;
          this.writeDispatched = false; return;
        }
        if (!await this.tasks.wait(250)) return;
      }
      throw new Error('Timeout');
    } catch (_) {
      if (current()) { if (write && this.writeDispatched) this.store.writeUncertain = true;
        this.store.error = write ? '保存结果未确认，请重新读取核对；不会自动重试保存' : '读取失败，请重试'; }
    } finally {
      if (token === this.store.token && generation === this.generation) { this.ownedRequest = false; this.writeDispatched = false; this.store.busy = false; this.store.loading = false; }
    }
  }
}
