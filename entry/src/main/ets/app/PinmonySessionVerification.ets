import { PinmonyNativeNetwork, PinmonyNetworkReply } from 'common_network';
import { PinmonyAuthStatus, PinmonyAuthMessage, PinmonySessionVerificationResult, parseSessionVerification, isPinterestAuthRoute, acceptsAuthMessage } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';

export const PIN_NATIVE_SESSION_VERIFICATION_ENABLED: boolean = true;
export const PIN_NATIVE_LOGIN_LIFECYCLE_ENABLED: boolean = true;

export interface PinmonySessionVerificationPorts {
  detached?: () => boolean;
  origin?: () => string;
  unavailable?: () => void;
  network: () => PinmonyNativeNetwork;
  status: () => PinmonyAuthStatus;
  profile: () => string;
  epoch: () => number;
  page: () => string;
  userAgent: () => string;
  active: () => boolean;
  accept: (message: PinmonyAuthMessage) => void;
}

// The Web observer may prove authentication before it knows the account identity.
// Keep the probe until full current identity arrives, without accepting stale data.
export class PinmonySessionVerification {
  private readonly ports: PinmonySessionVerificationPorts;
  private revision: number = 0;
  private sequence: number = 0;
  private key: string = '';
  private job: string = '';
  private partialLogged: boolean = false;

  constructor(ports: PinmonySessionVerificationPorts) { this.ports = ports; }

  cancel(reason: string = 'cancelled'): void {
    if (this.job) PinmonyRuntimeLog.info('SessionVerification: phase=cancelled reason=' + reason);
    this.revision++;
    if (this.job) this.ports.network().cancel(this.job);
    this.job = '';
    this.key = '';
    this.partialLogged = false;
  }

  observeWebEvidence(value: string): void {
    if (!this.job) return;
    try {
      const message: PinmonyAuthMessage = JSON.parse(value) as PinmonyAuthMessage;
      if (!acceptsAuthMessage(message, this.ports.page(), this.ports.epoch())) return;
      if (message.status === 'unauthenticated' && this.ports.status() === 'unauthenticated') {
        this.cancel('web-unauthenticated');
      } else if (message.status === 'authenticated' && this.ports.status() === 'authenticated') {
        const origin: RegExpMatchArray | null = message.pageUrl.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
        if (origin && message.profileUrl === this.ports.profile() && message.profileUrl.startsWith(origin[0] + '/') &&
            /^\/[A-Za-z0-9_]{1,100}\/$/.test(message.profileUrl.slice(origin[0].length))) {
          this.cancel('web-identity-confirmed');
        } else if (!this.partialLogged) {
          this.partialLogged = true;
          PinmonyRuntimeLog.info('SessionVerification: phase=waiting reason=web-identity-pending');
        }
      }
    } catch (_) { /* Invalid Web messages cannot cancel a valid probe. */ }
  }

  private eligible(): boolean {
    return this.ports.status() === 'checking' || this.ports.status() === 'authenticated' && !this.ports.profile();
  }

  async demand(): Promise<void> {
    if (!PIN_NATIVE_SESSION_VERIFICATION_ENABLED || !this.ports.active() || !this.eligible()) return;
    let page: string;
    let ua: string;
    const detached: boolean = this.ports.detached?.() === true;
    try { page = detached ? (this.ports.origin?.() || '') + '/' : this.ports.page(); ua = this.ports.userAgent(); } catch (_) { return; }
    const match: RegExpMatchArray | null = page.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
    // Do not race the website while credentials or a challenge are being entered.
    if (!match || isPinterestAuthRoute(page) || !/^\/(?:[?#].*)?$/.test(page.slice(match[0].length)) || !ua) return;
    const epoch: number = this.ports.epoch();
    const key: string = epoch.toString() + ':' + page;
    if (this.key === key) return;
    this.cancel('superseded');
    this.key = key;
    const revision: number = this.revision;
    const id: string = 'session_probe_' + (++this.sequence).toString();
    this.job = id;
    const startedAt: number = Date.now();
    PinmonyRuntimeLog.info('SessionVerification: phase=started');
    const current = (): boolean => {
      try { return revision === this.revision && this.ports.active() && this.eligible() &&
        this.ports.epoch() === epoch && (detached ? (this.ports.origin?.() || '') + '/' : this.ports.page()) === page; } catch (_) { return false; }
    };
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().verifySession(match[0], ua, epoch, id, current);
      if (!current()) {
        if (revision === this.revision) PinmonyRuntimeLog.info('SessionVerification: phase=discarded reason=owner-changed');
        return;
      }
      const result: PinmonySessionVerificationResult = detached && reply.error === 'missing-session' ?
        { status: 'unauthenticated', profileUrl: '', appVersion: '' } : reply.error ?
        { status: 'unknown', profileUrl: '', appVersion: '' } : parseSessionVerification(match[0], reply.status, reply.body);
      PinmonyRuntimeLog.info('SessionVerification: result=' + result.status + ' elapsedMs=' + (Date.now() - startedAt).toString());
      if (result.status === 'unknown') { if (detached) this.ports.unavailable?.(); return; }
      if (result.status === 'unauthenticated' && this.ports.status() === 'authenticated') {
        PinmonyRuntimeLog.warn('SessionVerification: phase=discarded reason=web-auth-conflict');
        return;
      }
      const message: PinmonyAuthMessage = { status: result.status, profileUrl: result.profileUrl,
        appVersion: result.appVersion, epoch: epoch, pageUrl: page };
      this.job = '';
      PinmonyRuntimeLog.info('SessionVerification: phase=accepted source=native');
      this.ports.accept(message);
    } catch (_) {
      if (current()) PinmonyRuntimeLog.warn('SessionVerification: result=unknown');
      if (current() && detached) this.ports.unavailable?.();
    } finally {
      if (revision === this.revision) this.job = '';
    }
  }
}
