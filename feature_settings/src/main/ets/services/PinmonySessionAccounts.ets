import { PinmonyI18n } from 'common_foundation';
import { PinmonyNativeNetwork, PinmonyNetworkContext, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyBusinessSessionContext, PinmonySessionVerificationResult, parseSessionVerification } from 'common_session';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonySessionAccount } from '../models/PinmonySessionAccount';
import { PIN_LOGOUT_API_ENABLED, logoutRequestBody, logoutResponseSucceeded } from './PinmonyLogout';

export interface PinmonySessionAccountsPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  profile: () => string;
  active: () => boolean;
  visible: () => boolean;
  beginSwitch: () => void;
  expired: () => void;
  confirmed: (result: PinmonySessionVerificationResult) => void;
  loggedOut?: (accounts: PinmonySessionAccount[], origin: string) => void;
}
interface PinmonySessionAccountUser { id?: string; username?: string; full_name?: string; email?: string; image_medium_url?: string; partner?: Object | null; }
interface PinmonySessionAccountFlag { logged_in?: boolean; }
interface PinmonySessionAccountData { success?: boolean; session_accounts?: Record<string, PinmonySessionAccountFlag>; switch_account?: boolean; user?: PinmonySessionAccountUser; }
interface PinmonySessionAccountBatch { status?: string; code?: number; endpoint_name?: string; data?: PinmonySessionAccountUser; }
interface PinmonySessionAccountResource { status?: string; code?: number; http_status?: number; error?: Object; endpoint_name?: string; data?: Object; }
interface PinmonySessionAccountContext { is_authenticated?: boolean; user?: PinmonySessionAccountUser; }
interface PinmonySessionAccountEnvelope { resource_response?: PinmonySessionAccountResource; client_context?: PinmonySessionAccountContext; }
interface PinmonySessionListOptions { session_accounts: boolean; }
interface PinmonyAccountSwitchOptions { get_user: boolean; switch_account: string; app_type_from_client: number; ui_component: string; handler: string; visited_pages_before_login: string; arkoseSessionToken: null; recaptchaV3Token: null; }
interface PinmonySessionBatchData { requests: string; }
interface PinmonySessionBatchOptions { url: string; data: PinmonySessionBatchData; }
interface PinmonySessionBatchFields { fields: string; }
interface PinmonySessionBatchRequest { uri: string; method: string; params: PinmonySessionBatchFields; }
interface PinmonySessionAccountRequest { options: PinmonySessionListOptions | PinmonyAccountSwitchOptions | PinmonySessionBatchOptions; context: Record<string, string>; }
export const ACCOUNT_FIELDS: string = 'partner.biz_ownership_email,partner.business_name,partner.contact_email,partner.contact_phone,partner.contact_phone_country(),partner.enable_profile_address,partner.enable_profile_message,partner.is_boost_a_pin_partner,partner.is_linked_business,partner.profile_place(),place.country,place.extra_street,place.locality,place.postal_code,place.region,place.street,user.businesses(),user.email,user.fast_advertiser_info_has_any_managed_advertisers,user.full_name,user.id,user.image_medium_url,user.owners(),user.partner(),user.username';

// All account data is transient and belongs to the captured website session.
export class PinmonySessionAccounts {
  private revision: number = 0;
  private sequence: number = 0;
  private unknownLogout: string = '';
  private logoutPending: boolean = false;
  private logoutAccounts: PinmonySessionAccount[] = [];
  private jobs: string[] = [];
  private uncertainSession: PinmonyBusinessSessionContext | undefined = undefined;
  private readonly store: PinmonySettingsStore;
  private readonly ports: PinmonySessionAccountsPorts;
  constructor(store: PinmonySettingsStore, ports: PinmonySessionAccountsPorts) { this.store = store; this.ports = ports; }
  private same(captured: PinmonyBusinessSessionContext): boolean {
    const now: PinmonyBusinessSessionContext = this.ports.session();
    return this.ports.active() && now.authenticated && captured.authenticated && now.generation === captured.generation &&
      now.accountId === captured.accountId && now.origin === captured.origin;
  }
  private current(captured: PinmonyBusinessSessionContext, revision: number, token: number): boolean {
    return this.same(captured) && this.ports.visible() && revision === this.revision && token === this.store.token;
  }
  pause(): void {
    this.revision++;
    this.jobs.forEach((id: string): void => this.ports.network().cancel(id)); this.jobs = [];
    if (this.uncertainSession) { this.store.sessionSwitchUncertain = true; this.store.busy = false; this.store.sessionAccountError = PinmonyI18n.message(this.logoutPending ? 'pm_session_logout_unknown' : 'pm_session_switch_unknown'); }
    this.store.sessionAccountsLoading = false;
  }
  reset(): void { this.pause(); this.logoutPending = false; this.logoutAccounts = []; this.uncertainSession = undefined; this.store.sessionSwitchUncertain = false; }
  private async request(captured: PinmonyBusinessSessionContext, revision: number, token: number,
      resource: string, options: PinmonySessionListOptions | PinmonyAccountSwitchOptions | PinmonySessionBatchOptions, switching: boolean = false): Promise<PinmonySessionAccountEnvelope> {
    const source: string = '/switch_account/';
    const id: string = 'native_account_switch_' + (++this.sequence).toString(); this.jobs.push(id);
    const job: PinmonyNetworkJob = { id: id, epoch: captured.generation, page: captured.origin + source,
      url: captured.origin + '/resource/' + resource + '/create/', method: 'POST',
      body: 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} } as PinmonySessionAccountRequest)),
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/switch_account.js',
        'X-Pinterest-Source-Url': source, 'X-Pinterest-AppState': 'active' } };
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().request(job, (): PinmonyNetworkContext => ({
        authenticated: this.current(captured, revision, token), epoch: captured.generation, page: job.page, userAgent: captured.userAgent }));
      if (!this.current(captured, revision, token)) throw new Error('stale');
      if (reply.error || reply.status !== 200 || reply.body.length > 2097152) throw new Error(reply.error || 'response');
      const body: PinmonySessionAccountEnvelope = JSON.parse(reply.body) as PinmonySessionAccountEnvelope;
      if (body.resource_response?.status !== 'success' || body.resource_response.error ||
          body.resource_response.code !== undefined && body.resource_response.code !== 0 ||
          (!switching && body.client_context?.is_authenticated !== true || switching && body.client_context?.is_authenticated === false) || !/^[1-9]\d{0,39}$/.test(body.client_context?.user?.id || '') ||
          !/^[A-Za-z0-9_]{1,100}$/.test(body.client_context?.user?.username || '')) throw new Error('business');
      return body;
    } finally { this.jobs = this.jobs.filter((jobId: string): boolean => jobId !== id); }
  }
  async read(): Promise<void> {
    if (!this.ports.visible() || !this.ports.active() || this.store.busy || this.uncertainSession || this.store.sessionAccountsLoading) return;
    const session: PinmonyBusinessSessionContext = this.ports.session(); if (!session.authenticated) return;
    const revision: number = ++this.revision, token: number = this.store.token;
    this.store.sessionAccountsLoading = true; this.store.sessionAccountError = ''; this.store.sessionAccountsReady = false;
    try {
      const listOptions: PinmonySessionListOptions = { session_accounts: true };
      const body: PinmonySessionAccountEnvelope = await this.request(session, revision, token, 'UserSessionResource', listOptions);
      const data: PinmonySessionAccountData = body.resource_response!.data as PinmonySessionAccountData;
      const viewer: PinmonySessionAccountUser = body.client_context!.user!;
      if (data?.success !== true || !data.session_accounts || Array.isArray(data.session_accounts) || typeof data.session_accounts !== 'object') throw new Error('accounts');
      if (this.ports.profile() !== session.origin + '/' + viewer.username + '/') throw new Error('identity');
      const ids: string[] = Object.keys(data.session_accounts);
      if (!ids.length || ids.length > 20 || !ids.includes(viewer.id!) || ids.some((id: string): boolean => !/^[1-9]\d{0,39}$/.test(id) || typeof data.session_accounts![id]?.logged_in !== 'boolean') || data.session_accounts[viewer.id!].logged_in !== true) throw new Error('accounts');
      const requests: PinmonySessionBatchRequest[] = ids.map((id: string): PinmonySessionBatchRequest => ({ uri: 'v3/users/' + id + '/', method: 'GET', params: { fields: ACCOUNT_FIELDS } }));
      const batchOptions: PinmonySessionBatchOptions = { url: '/v3/batch/', data: { requests: JSON.stringify(requests) } };
      const profiles: PinmonySessionAccountEnvelope = await this.request(session, revision, token, 'ApiResource', batchOptions);
      if (profiles.resource_response?.endpoint_name !== 'v3_batch_handler' || profiles.client_context?.user?.id !== viewer.id) throw new Error('identity');
      const rows: Record<string, PinmonySessionAccountBatch> = profiles.resource_response.data as Record<string, PinmonySessionAccountBatch>;
      if (!rows || Array.isArray(rows) || Object.keys(rows).length !== ids.length) throw new Error('profiles');
      const accounts: PinmonySessionAccount[] = ids.map((id: string): PinmonySessionAccount => {
        const row: PinmonySessionAccountBatch = rows['GET:v3/users/' + id + '/'];
        const user: PinmonySessionAccountUser | undefined = row?.data;
        if (row?.status !== 'success' || row.code !== 0 || row.endpoint_name !== 'v3_get_user_handler' || user?.id !== id ||
            !/^[A-Za-z0-9_]{1,100}$/.test(user.username || '')) throw new Error('profile');
        const current: boolean = id === viewer.id;
        if (current && user.username !== viewer.username) throw new Error('identity');
        const email: string = current ? (typeof user.email === 'string' ? user.email : typeof viewer.email === 'string' ? viewer.email : '') : '';
        const avatar: string = typeof user.image_medium_url === 'string' && /^https:\/\/(?:[a-z0-9-]+\.)?pinimg\.com\//i.test(user.image_medium_url) ? user.image_medium_url.slice(0, 2048) : '';
        return { id: id, username: user.username!, name: typeof user.full_name === 'string' && user.full_name ? user.full_name.slice(0, 200) : user.username!,
          avatar: avatar, email: email.slice(0, 320), business: !!user.partner && typeof user.partner === 'object', current: current, loggedIn: data.session_accounts![id].logged_in! };
      });
      if (!this.current(session, revision, token)) return;
      if (!accounts.some((account: PinmonySessionAccount): boolean => account.current && !!account.email)) throw new Error('email');
      this.store.sessionAccounts = accounts; this.store.sessionAccountsReady = true;
      this.store.rememberAccountEntry(accounts.filter((account: PinmonySessionAccount): boolean => account.loggedIn).length > 1);
    } catch (_) {
      if (this.current(session, revision, token)) { this.store.sessionAccounts = []; this.store.sessionAccountError = PinmonyI18n.message('pm_session_accounts_failed'); }
    } finally { if (revision === this.revision) this.store.sessionAccountsLoading = false; }
  }
  async switchTo(id: string): Promise<void> {
    if (this.store.screen !== 'sessionAccounts' || !this.store.sessionAccountsReady || this.store.busy || this.store.sessionAccountsLoading || this.uncertainSession) return;
    const target: PinmonySessionAccount | undefined = this.store.sessionAccounts.find((account: PinmonySessionAccount): boolean => account.id === id && !account.current && account.loggedIn);
    if (!target) return;
    const session: PinmonyBusinessSessionContext = this.ports.session(); if (!this.same(session) || !this.ports.visible()) return;
    const revision: number = ++this.revision, token: number = this.store.token;
    this.store.busy = true; this.store.sessionAccountError = ''; this.store.sessionSwitchUncertain = false; this.uncertainSession = session;
    this.ports.beginSwitch();
    try {
      const options: PinmonyAccountSwitchOptions = {
        get_user: true, switch_account: id, app_type_from_client: 6, ui_component: 'undefined.SwitchAccountPage',
        handler: 'www/switch_account.js', visited_pages_before_login: '[]', arkoseSessionToken: null, recaptchaV3Token: null };
      const reply: PinmonySessionAccountEnvelope = await this.request(session, revision, token, 'UserSessionResource', options, true);
      const data: PinmonySessionAccountData = reply.resource_response!.data as PinmonySessionAccountData;
      if (data?.success !== true || data.switch_account !== true || data.user?.id !== id || reply.client_context?.user?.id !== id) throw new Error('unconfirmed');
      await this.verify(target.username, session, revision, token);
    } catch (_) {
      if (this.current(session, revision, token)) { this.store.sessionSwitchUncertain = true; this.store.sessionAccountError = PinmonyI18n.message('pm_session_switch_unknown'); }
    } finally { if (revision === this.revision) this.store.busy = false; }
  }
  async logoutSelected(id: string): Promise<void> {
    if (!PIN_LOGOUT_API_ENABLED || !this.ports.loggedOut || this.store.screen !== 'sessionAccounts' ||
        !this.store.sessionAccountsReady || this.store.busy || this.store.loading || this.store.sessionAccountsLoading || this.uncertainSession) return;
    const target: PinmonySessionAccount | undefined = this.store.sessionAccounts.find((account: PinmonySessionAccount): boolean => account.id === id && account.loggedIn);
    if (!target) return;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if (!this.same(session) || !this.ports.visible()) return;
    const operation: string = session.origin + ':' + session.accountId + ':' + session.generation.toString() + ':' + id;
    if (this.unknownLogout === operation) return;
    const accounts: PinmonySessionAccount[] = this.store.sessionAccounts.map((account: PinmonySessionAccount): PinmonySessionAccount => ({
      id: account.id, username: account.username, name: account.name, avatar: account.avatar, email: '',
      business: account.business, current: account.id === id, loggedIn: account.loggedIn }));
    const revision: number = ++this.revision, token: number = this.store.token;
    this.logoutAccounts = accounts; this.logoutPending = true;
    this.store.busy = true; this.store.sessionAccountError = ''; this.uncertainSession = session;
    this.ports.beginSwitch();
    try {
      if (!target.current) {
        const options: PinmonyAccountSwitchOptions = {
          get_user: true, switch_account: id, app_type_from_client: 6, ui_component: 'undefined.SwitchAccountPage',
          handler: 'www/switch_account.js', visited_pages_before_login: '[]', arkoseSessionToken: null, recaptchaV3Token: null };
        const envelope: PinmonySessionAccountEnvelope = await this.request(session, revision, token, 'UserSessionResource', options, true);
        const data: PinmonySessionAccountData = envelope.resource_response!.data as PinmonySessionAccountData;
        if (data?.success !== true || data.switch_account !== true || data.user?.id !== id || envelope.client_context?.user?.id !== id) throw new Error('unconfirmed');
      }
      // Do not delete until a read-only probe proves the selected identity owns the active cookies.
      const verified: PinmonySessionVerificationResult | undefined = await this.verify(target.username, session, revision, token, false);
      if (!verified || !this.current(session, revision, token)) return;
      if (verified.status === 'unauthenticated') return;
      this.uncertainSession = session;
      const jobId: string = 'native_session_logout_' + (++this.sequence).toString() + '_' + Date.now().toString();
      const job: PinmonyNetworkJob = { id: jobId, epoch: session.generation, page: session.origin + '/',
        url: session.origin + '/resource/UserSessionResource/delete/', method: 'POST', body: logoutRequestBody(),
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded',
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/settings.js' } };
      this.jobs.push(jobId); this.unknownLogout = operation;
      let reply: PinmonyNetworkReply;
      try {
        reply = await this.ports.network().request(job, (): PinmonyNetworkContext => ({
          authenticated: this.current(session, revision, token), epoch: session.generation, page: job.page, userAgent: session.userAgent }));
      } finally { this.jobs = this.jobs.filter((pending: string): boolean => pending !== jobId); }
      if (!this.current(session, revision, token)) return;
      if (reply.error || !logoutResponseSucceeded(reply.status, reply.body)) {
        if (['request-unavailable', 'background'].includes(reply.error)) this.unknownLogout = '';
        throw new Error('logout-unconfirmed');
      }
      this.logoutAccounts = []; this.logoutPending = false; this.unknownLogout = ''; this.uncertainSession = undefined; this.store.sessionSwitchUncertain = false;
      this.ports.loggedOut(accounts, session.origin);
    } catch (_) {
      if (this.current(session, revision, token)) {
        this.store.sessionSwitchUncertain = true; this.store.sessionAccountError = PinmonyI18n.message('pm_session_logout_unknown');
      }
    } finally { if (revision === this.revision) this.store.busy = false; }
  }
  private async verify(expectedUsername: string, session: PinmonyBusinessSessionContext, revision: number, token: number, notify: boolean = true): Promise<PinmonySessionVerificationResult | undefined> {
    const id: string = 'session_probe_' + (1000000 + (++this.sequence)).toString(); this.jobs.push(id);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().verifySession(session.origin, session.userAgent, session.generation, id,
        (): boolean => this.current(session, revision, token));
      if (!this.current(session, revision, token)) throw new Error('stale');
      const result: PinmonySessionVerificationResult = parseSessionVerification(session.origin, reply.status, reply.body);
      if (!reply.error && result.status === 'unauthenticated') {
        if (this.logoutPending && this.ports.loggedOut) {
          const accounts: PinmonySessionAccount[] = this.logoutAccounts;
          this.logoutAccounts = []; this.logoutPending = false; this.uncertainSession = undefined; this.store.sessionSwitchUncertain = false;
          this.ports.loggedOut(accounts, session.origin);
        } else if (notify) { this.uncertainSession = undefined; this.ports.expired(); }
        return result;
      }
      if (reply.error || result.status !== 'authenticated' || expectedUsername && result.profileUrl !== session.origin + '/' + expectedUsername + '/') throw new Error('unconfirmed');
      if (notify) {
        this.logoutAccounts = []; this.logoutPending = false;
        this.uncertainSession = undefined; this.store.sessionSwitchUncertain = false;
        this.ports.confirmed(result);
      }
      return result;
    } finally { this.jobs = this.jobs.filter((jobId: string): boolean => jobId !== id); }
  }
  async verifyUncertain(): Promise<void> {
    const session: PinmonyBusinessSessionContext | undefined = this.uncertainSession;
    if (!session || this.store.busy || !this.same(session) || !this.ports.visible()) return;
    const revision: number = ++this.revision, token: number = this.store.token;
    this.store.busy = true;
    try { await this.verify('', session, revision, token); }
    catch (_) { if (this.current(session, revision, token)) this.store.sessionAccountError = PinmonyI18n.message(this.logoutPending ? 'pm_session_logout_unknown' : 'pm_session_switch_unknown'); }
    finally { if (revision === this.revision) this.store.busy = false; }
  }
}
