// Runtime transport metadata captured by the login host. No credentials or
// account identity are stored here, and business confirmation needs no Web call.
export class PinmonySessionEnvironment {
  private agent: string = '';

  capture(userAgent: string): boolean {
    if (typeof userAgent !== 'string' || !userAgent || userAgent.length > 4096 || /[\r\n]/.test(userAgent)) return false;
    this.agent = userAgent;
    return true;
  }

  userAgent(): string { return this.agent; }
}
