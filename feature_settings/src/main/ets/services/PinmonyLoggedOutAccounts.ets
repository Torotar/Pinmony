import { PinmonyI18n } from 'common_foundation';
import { PinmonyNativeNetwork, PinmonyTransferReply, PinmonyNetworkReply } from 'common_network';
import { PinmonySessionVerificationResult, parseSessionVerification } from 'common_session';
import { PinmonySessionAccount } from '../models/PinmonySessionAccount';
import { ACCOUNT_FIELDS } from './PinmonySessionAccounts';

export interface PinmonyLoggedOutAccountPorts {
  network: () => PinmonyNativeNetwork;
  available: () => boolean;
  epoch: () => number;
  userAgent: () => string;
  confirmed: (result: PinmonySessionVerificationResult) => void;
}
interface PinmonyLoggedOutUser { id?: string; }
interface PinmonyLoggedOutSwitchData { success?: boolean; switch_account?: boolean; user?: PinmonyLoggedOutUser; }
interface PinmonyLoggedOutSwitchResource { status?: string; code?: number; error?: Object; data?: PinmonyLoggedOutSwitchData; }
interface PinmonyLoggedOutSwitchEnvelope { resource_response?: PinmonyLoggedOutSwitchResource; client_context?: PinmonyLoggedOutSwitchContext; }
interface PinmonyLoggedOutSwitchContext { user?: PinmonyLoggedOutUser; is_authenticated?: boolean; }
interface PinmonyLoggedOutSwitchOptions {
  get_user: boolean; switch_account: string; app_type_from_client: number; ui_component: string;
  handler: string; visited_pages_before_login: string; arkoseSessionToken: null; recaptchaV3Token: null;
}
interface PinmonyLoggedOutSwitchRequest { options: PinmonyLoggedOutSwitchOptions; context: Record<string, string>; }
interface LoginAccountUser { id?: string; username?: string; full_name?: string; }
interface LoginAccountFlag { logged_in?: boolean; }
interface LoginAccountList { success?: boolean; session_accounts?: Record<string, LoginAccountFlag>; }
interface LoginAccountProfile { status?: string; code?: number; endpoint_name?: string; data?: LoginAccountUser; }
interface LoginAccountResource { status?: string; code?: number; error?: Object; endpoint_name?: string; data?: Object; }
interface LoginAccountEnvelope { resource_response?: LoginAccountResource; }
interface LoginAccountFields { fields: string; }
interface LoginAccountRequest { uri: string; method: string; params: LoginAccountFields; }
interface LoginAccountListOptions { session_accounts: boolean; }
interface LoginAccountBatchData { requests: string; }
interface LoginAccountBatchOptions { url: string; data: LoginAccountBatchData; }
interface LoginAccountReadRequest { options: LoginAccountListOptions | LoginAccountBatchOptions; context: Record<string, string>; }

// Display identities only, retained in memory after a confirmed logout. Credentials
// continue to come from the current ArkWeb store for each individual request.
@Observed
export class PinmonyLoggedOutAccounts {
  accounts: PinmonySessionAccount[] = [];
  active: boolean = false;
  busy: boolean = false;
  uncertain: boolean = false;
  error: string = '';
  restoreFailed: boolean = false;
  private restoreStarted: boolean = false;
  private origin: string = '';
  private revision: number = 0;
  private probeSequence: number = 0;
  private selected: string = '';
  private manualLogin: boolean = false;
  private readonly ports: PinmonyLoggedOutAccountPorts;
  constructor(ports: PinmonyLoggedOutAccountPorts) { this.ports = ports; }
  stage(accounts: PinmonySessionAccount[], origin: string): void {
    this.reset();
    if (!/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin)) return;
    this.origin = origin;
    this.accounts = accounts.filter((account: PinmonySessionAccount): boolean => !account.current && account.loggedIn)
      .map((account: PinmonySessionAccount): PinmonySessionAccount => ({ id: account.id, username: account.username,
        name: account.name, avatar: account.avatar, business: account.business, email: '', current: false, loggedIn: true }));
  }
  arm(): void { this.active = true; this.manualLogin = false; }
  reset(): void {
    this.revision++; this.accounts = []; this.origin = ''; this.selected = ''; this.manualLogin = false;
    this.active = false; this.busy = false; this.uncertain = false; this.error = '';
    this.restoreStarted = false; this.restoreFailed = false;
  }
  async restore(origin: string, retry: boolean = false): Promise<void> {
    if (!this.active || this.busy || this.uncertain || this.accounts.length > 0 ||
        this.restoreStarted && !retry || !this.ports.available() || !this.ports.userAgent() ||
        !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin)) return;
    this.origin = origin; this.restoreStarted = true; this.restoreFailed = false;
    this.busy = true; this.error = ''; this.manualLogin = false;
    const revision: number = ++this.revision, epoch: number = this.ports.epoch();
    try {
      const list: LoginAccountEnvelope = await this.readAccounts('UserSessionResource', { session_accounts: true }, revision, epoch);
      const data: LoginAccountList = list.resource_response!.data as LoginAccountList;
      if (data?.success !== true || !data.session_accounts || typeof data.session_accounts !== 'object' || Array.isArray(data.session_accounts)) throw new Error('accounts');
      const ids: string[] = Object.keys(data.session_accounts);
      if (ids.length > 20 || ids.some((id: string): boolean => !/^[1-9]\d{0,39}$/.test(id) || typeof data.session_accounts![id]?.logged_in !== 'boolean')) throw new Error('accounts');
      const available: string[] = ids.filter((id: string): boolean => data.session_accounts![id].logged_in === true);
      if (!available.length) return;
      const requests: LoginAccountRequest[] = available.map((id: string): LoginAccountRequest => ({ uri: 'v3/users/' + id + '/', method: 'GET', params: { fields: ACCOUNT_FIELDS } }));
      const batch: LoginAccountEnvelope = await this.readAccounts('ApiResource', { url: '/v3/batch/', data: { requests: JSON.stringify(requests) } }, revision, epoch);
      if (batch.resource_response?.endpoint_name !== 'v3_batch_handler') throw new Error('profiles');
      const rows: Record<string, LoginAccountProfile> = batch.resource_response.data as Record<string, LoginAccountProfile>;
      if (!rows || Array.isArray(rows) || Object.keys(rows).length !== available.length) throw new Error('profiles');
      const accounts: PinmonySessionAccount[] = available.map((id: string): PinmonySessionAccount => {
        const row: LoginAccountProfile = rows['GET:v3/users/' + id + '/'];
        const user: LoginAccountUser | undefined = row?.data;
        if (row?.status !== 'success' || row.code !== 0 || row.endpoint_name !== 'v3_get_user_handler' ||
            user?.id !== id || !/^[A-Za-z0-9_]{1,100}$/.test(user.username || '')) throw new Error('profile');
        return { id: id, username: user.username!, name: typeof user.full_name === 'string' && user.full_name ? user.full_name.slice(0, 200) : user.username!,
          avatar: '', email: '', business: false, current: false, loggedIn: true };
      });
      if (this.current(revision, epoch)) this.accounts = accounts;
    } catch (_) {
      if (this.active && revision === this.revision) {
        this.restoreFailed = true; this.error = PinmonyI18n.message('pm_session_accounts_failed');
      }
    } finally { if (revision === this.revision) this.busy = false; }
  }
  async retryRestore(): Promise<void> { await this.restore(this.origin, true); }
  private async readAccounts(resource: string, options: LoginAccountListOptions | LoginAccountBatchOptions, revision: number, epoch: number): Promise<LoginAccountEnvelope> {
    const source: string = '/switch_account/';
    const reply: PinmonyTransferReply = await this.ports.network().transfer({
      id: 'logged_out_accounts_read_' + revision.toString() + '_' + resource, url: this.origin + '/resource/' + resource + '/create/',
      method: 'POST', page: this.origin + source, userAgent: this.ports.userAgent(), authenticated: true,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Pinterest-Source-Url': source, 'X-Pinterest-Pws-Handler': 'www/switch_account.js' },
      body: 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} } as LoginAccountReadRequest)),
      timeoutMs: 15000, maxBytes: 2097152
    }, (): boolean => this.current(revision, epoch));
    if (!this.current(revision, epoch)) throw new Error('stale');
    const body: LoginAccountEnvelope = JSON.parse(reply.text) as LoginAccountEnvelope;
    if (reply.status !== 200 || body.resource_response?.status !== 'success' || body.resource_response.error ||
        body.resource_response.code !== undefined && body.resource_response.code !== 0) throw new Error('accounts-read');
    return body;
  }
  allowManualLogin(): void { if (this.active && !this.busy && !this.uncertain) this.manualLogin = true; }
  acceptsWebLogin(): boolean { return !this.active || this.manualLogin && !this.busy && !this.uncertain; }
  private current(revision: number, epoch: number): boolean {
    return this.active && revision === this.revision && epoch === this.ports.epoch() && this.ports.available();
  }
  async choose(id: string): Promise<void> {
    if (!this.active || this.busy || this.uncertain || !this.ports.available()) return;
    const target: PinmonySessionAccount | undefined = this.accounts.find((account: PinmonySessionAccount): boolean => account.id === id);
    if (!target || !/^[1-9]\d{0,39}$/.test(target.id) || !/^[A-Za-z0-9_]{1,100}$/.test(target.username)) return;
    const revision: number = ++this.revision, epoch: number = this.ports.epoch();
    this.selected = id; this.busy = true; this.error = ''; this.manualLogin = false;
    // Unknown once dispatched. Only read-only verification can recover it.
    this.uncertain = true;
    let dispatched: boolean = false;
    try {
      const source: string = '/switch_account/';
      const options: PinmonyLoggedOutSwitchOptions = { get_user: true, switch_account: target.id, app_type_from_client: 6,
        ui_component: 'undefined.SwitchAccountPage', handler: 'www/switch_account.js',
        visited_pages_before_login: '[]', arkoseSessionToken: null, recaptchaV3Token: null };
      const reply: PinmonyTransferReply = await this.ports.network().transfer({
        id: 'logged_out_account_' + revision.toString(), url: this.origin + '/resource/UserSessionResource/create/',
        method: 'POST', page: this.origin + source, userAgent: this.ports.userAgent(), authenticated: true,
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Pinterest-Source-Url': source,
          'X-Pinterest-Pws-Handler': 'www/switch_account.js' },
        body: 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} } as PinmonyLoggedOutSwitchRequest)),
        timeoutMs: 15000, maxBytes: 2097152
      }, (): boolean => this.current(revision, epoch), (): void => { dispatched = true; });
      if (!this.current(revision, epoch)) return;
      const body: PinmonyLoggedOutSwitchEnvelope = JSON.parse(reply.text) as PinmonyLoggedOutSwitchEnvelope;
      if (reply.status !== 200 || body.resource_response?.status !== 'success' || body.resource_response.error ||
          body.resource_response.code !== undefined && body.resource_response.code !== 0 ||
          body.resource_response.data?.success !== true || body.resource_response.data.switch_account !== true ||
          body.resource_response.data.user?.id !== id || body.client_context?.user?.id !== id ||
          body.client_context?.is_authenticated === false) throw new Error('unconfirmed');
      await this.verify(revision, epoch, target);
    } catch (_) {
      if (this.active && revision === this.revision) {
        if (!dispatched) { this.uncertain = false; this.selected = ''; }
        this.error = PinmonyI18n.message(dispatched ? 'pm_session_switch_unknown' : 'pm_session_accounts_failed');
      }
    } finally { if (revision === this.revision) this.busy = false; }
  }
  private async verify(revision: number, epoch: number, target: PinmonySessionAccount, recovering: boolean = false): Promise<void> {
    const reply: PinmonyNetworkReply = await this.ports.network().verifySession(this.origin, this.ports.userAgent(), epoch,
      'session_probe_' + (2000000 + (++this.probeSequence)).toString(), (): boolean => this.current(revision, epoch));
    if (!this.current(revision, epoch)) return;
    const result: PinmonySessionVerificationResult = parseSessionVerification(this.origin, reply.status, reply.body);
    if (!reply.error && result.status === 'unauthenticated') {
      this.accounts = this.accounts.filter((account: PinmonySessionAccount): boolean => account.id !== target.id);
      this.selected = ''; this.uncertain = false;
      this.error = PinmonyI18n.message('pm_unable_to_verify_the_session_retry_or_sign_in_again_fb5c22fa');
      return;
    }
    if (recovering && !reply.error && result.status === 'authenticated' && result.profileUrl !== this.origin + '/' + target.username + '/') {
      // The selected login did not take effect. Keep passive login blocked, but
      // let the user sign in explicitly after an authoritative read-only check.
      this.selected = ''; this.uncertain = false; this.manualLogin = false;
      this.error = PinmonyI18n.message('pm_unable_to_verify_the_session_retry_or_sign_in_again_fb5c22fa');
      return;
    }
    if (reply.error || result.status !== 'authenticated' || result.profileUrl !== this.origin + '/' + target.username + '/') throw new Error('unconfirmed');
    this.uncertain = false; this.error = '';
    this.ports.confirmed(result);
  }
  async verifySelected(): Promise<void> {
    if (!this.active || this.busy || !this.uncertain || !this.ports.available()) return;
    const target: PinmonySessionAccount | undefined = this.accounts.find((account: PinmonySessionAccount): boolean => account.id === this.selected);
    if (!target) return;
    const revision: number = ++this.revision, epoch: number = this.ports.epoch(); this.busy = true;
    try { await this.verify(revision, epoch, target, true); }
    catch (_) { if (this.active && revision === this.revision) this.error = PinmonyI18n.message('pm_session_switch_unknown'); }
    finally { if (revision === this.revision) this.busy = false; }
  }
}
