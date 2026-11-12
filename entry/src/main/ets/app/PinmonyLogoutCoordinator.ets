import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNetworkContext, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyBusinessNetwork as PinmonyNativeNetwork } from './PinmonyBusinessNetwork';
import { PinmonySettingsStore, logoutRequestBody, logoutResponseSucceeded } from 'feature_settings';

export interface PinmonyLogoutPorts {
  enabled: () => boolean;
  authenticated: () => boolean;
  unauthenticated: () => boolean;
  settingsVisible: () => boolean;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  confirmed: () => void;
  loginFailed: (message: string) => void;
}

// An unconfirmed write belongs to one account generation and must not be replayed.
export class PinmonyLogoutCoordinator {
  private readonly store: PinmonySettingsStore;
  private readonly ports: PinmonyLogoutPorts;
  private unknownAccount: string = '';

  constructor(store: PinmonySettingsStore, ports: PinmonyLogoutPorts) {
    this.store = store;
    this.ports = ports;
  }

  async logout(): Promise<void> {
    if (!this.ports.enabled() || !this.ports.authenticated() || !this.ports.settingsVisible() ||
        this.store.screen !== 'root' || this.store.busy || this.store.loading) return;
    const business: PinmonyBusinessSessionContext = this.ports.session();
    if (!business.authenticated || !business.accountId) return;
    const account: string = business.accountId + ':' + business.generation.toString() + ':' + business.origin;
    if (this.unknownAccount === account) {
      this.store.error = PinmonyI18n.message('pm_logout_not_confirmed_wait_for_session_verification_it_will_not_b_cfc74ac5');
      return;
    }
    const context: PinmonyNetworkContext = { authenticated: true, epoch: business.generation,
      page: business.origin + '/', userAgent: business.userAgent };
    const origin: RegExpMatchArray | null = context.page.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
    if (!origin) return;
    const token: number = ++this.store.token;
    this.store.busy = true;
    this.store.error = '';
    this.unknownAccount = account;
    PinmonyRuntimeLog.info('SessionLogout: request started');
    let confirmed: boolean = false;
    try {
      const job: PinmonyNetworkJob = { id: 'native_session_logout_' + token.toString() + '_' + Date.now().toString(),
        epoch: context.epoch, page: context.page, url: origin[0] + '/resource/UserSessionResource/delete/',
        method: 'POST', body: logoutRequestBody(), headers: { 'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/settings.js' } };
      const reply: PinmonyNetworkReply = await this.ports.network().request(job, (): PinmonyNetworkContext => {
        const current: PinmonyBusinessSessionContext = this.ports.session();
        return { authenticated: current.authenticated && current.accountId === business.accountId &&
          current.generation === business.generation && current.origin === business.origin &&
          this.ports.settingsVisible() && token === this.store.token,
          epoch: context.epoch, page: context.page, userAgent: current.userAgent };
      });
      const current: PinmonyBusinessSessionContext = this.ports.session();
      if (token !== this.store.token || !this.ports.authenticated() ||
          current.generation !== business.generation || current.accountId !== business.accountId ||
          current.origin !== business.origin) return;
      if (reply.error || !logoutResponseSucceeded(reply.status, reply.body)) {
        if (['request-unavailable', 'background'].includes(reply.error)) this.unknownAccount = '';
        this.store.error = this.unknownAccount ?
          PinmonyI18n.message('pm_logout_not_confirmed_wait_for_session_verification_it_will_not_b_cfc74ac5') :
          PinmonyI18n.message('pm_logout_was_not_sent_please_retry_6bd93118');
        PinmonyRuntimeLog.warn('SessionLogout: result not confirmed');
        return;
      }
      this.unknownAccount = '';
      PinmonyRuntimeLog.info('SessionLogout: server confirmed');
      confirmed = true;
      this.ports.confirmed();
    } catch (_) {
      const current: PinmonyBusinessSessionContext = this.ports.session();
      if (confirmed && this.ports.unauthenticated()) {
        this.ports.loginFailed(PinmonyI18n.message('pm_logged_out_but_the_sign_in_page_could_not_load_please_retry_93441c6b'));
      } else if (token === this.store.token && this.ports.authenticated() &&
          current.accountId === business.accountId && current.generation === business.generation &&
          current.origin === business.origin) {
        this.store.error = PinmonyI18n.message('pm_logout_not_confirmed_please_retry_later_ec7c6e06');
      }
      PinmonyRuntimeLog.warn('SessionLogout: operation unavailable');
    } finally {
      if (token === this.store.token) this.store.busy = false;
    }
  }
}
