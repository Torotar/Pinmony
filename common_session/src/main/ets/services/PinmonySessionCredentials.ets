import { webview } from '@kit.ArkWeb';

// Credentials are read per request, never exported over the JS bridge or persisted.
export class PinmonySessionCredentials {
  async read(url: string): Promise<string> {
    if (!/^https:\/\/(?:www|uk)\.pinterest\.com\//.test(url)) throw new Error('invalid-origin');
    let cookie: string;
    try { cookie = await webview.WebCookieManager.fetchCookie(url); }
    catch (_) { throw new Error('session-cookie-read-unavailable'); }
    if (!cookie || /[\r\n]/.test(cookie)) throw new Error('missing-session');
    return cookie;
  }

  async update(url: string, cookies: string[], current: () => boolean): Promise<void> {
    if (!/^https:\/\/(?:www|uk)\.pinterest\.com\//.test(url)) throw new Error('invalid-origin');
    for (const value of cookies) {
      if (!current()) throw new Error('stale');
      if (!value || value.length > 8192 || /[\r\n]/.test(value)) throw new Error('invalid-cookie');
      try { await webview.WebCookieManager.configCookie(url, value, false, true); }
      catch (_) { throw new Error('session-cookie-update-unavailable'); }
    }
  }
}
