import { PinmonyAuthStatus } from '../models/PinmonyAuth';

export interface PinmonyBusinessSessionContext {
  authenticated: boolean;
  generation: number;
  accountId: string;
  origin: string;
  userAgent: string;
  appVersion?: string;
}

// Account lifetime is independent of ArkWeb document navigation. No credentials
// are retained here; the network layer reads the cookie store per request.
export class PinmonyBusinessSession {
  private generation: number = 0;
  private accountId: string = '';
  private origin: string = '';
  private userAgent: string = '';
  private appVersion: string = '';
  private authenticated: boolean = false;

  reset(): void {
    this.generation++;
    this.authenticated = false;
    this.accountId = ''; this.origin = ''; this.userAgent = ''; this.appVersion = '';
  }

  confirm(accountId: string, profileUrl: string, userAgent: string, appVersion: string = ''): void {
    if (!accountId || !profileUrl || !userAgent) { this.reset(); return; }
    const origin: RegExpMatchArray | null = profileUrl.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
    if (!accountId || !origin || !userAgent) { this.reset(); return; }
    const sameAccount: boolean = this.authenticated && this.accountId === accountId && this.origin === origin[0];
    if (!sameAccount) { this.generation++; this.appVersion = ''; }
    if (/^[A-Za-z0-9._-]{1,80}$/.test(appVersion)) this.appVersion = appVersion;
    this.accountId = accountId; this.origin = origin[0]; this.userAgent = userAgent;
    this.authenticated = true;
  }

  context(status: PinmonyAuthStatus): PinmonyBusinessSessionContext {
    if (status !== 'authenticated' && this.authenticated) this.reset();
    return { authenticated: status === 'authenticated' && this.authenticated,
      generation: this.generation, accountId: this.accountId, origin: this.origin, userAgent: this.userAgent, appVersion: this.appVersion };
  }
}
