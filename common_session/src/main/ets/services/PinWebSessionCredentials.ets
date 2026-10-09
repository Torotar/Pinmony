import { webview } from '@kit.ArkWeb';

// Credentials are read per request, never exported over the JS bridge or persisted.
export class PinWebSessionCredentials {
  async read(url: string): Promise<string> {
    if (!url.startsWith('https://www.pinterest.com/')) throw new Error('invalid-origin');
    const cookie: string = await webview.WebCookieManager.fetchCookie(url);
    if (!cookie || /[\r\n]/.test(cookie)) throw new Error('missing-session');
    return cookie;
  }

  async update(url: string, cookies: string[], current: () => boolean): Promise<void> {
    if (!url.startsWith('https://www.pinterest.com/')) throw new Error('invalid-origin');
    for (const value of cookies) {
      if (!current()) throw new Error('stale');
      if (!value || value.length > 8192 || /[\r\n]/.test(value)) throw new Error('invalid-cookie');
      await webview.WebCookieManager.configCookie(url, value, false, true);
    }
  }
}
