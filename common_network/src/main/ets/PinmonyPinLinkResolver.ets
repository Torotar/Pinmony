import { rcp } from '@kit.RemoteCommunicationKit';
import { NetworkManager, Priority } from './PinmonyNativeNetwork';
import { PinmonyRuntimeLog } from 'common_foundation';

export function shortPinToken(value: string): string {
  if (value.length > 128) return '';
  const match: RegExpMatchArray | null = value.trim().match(/^https:\/\/(?:www\.)?pin\.it\/([a-z0-9]{1,64})\/?$/i);
  return match ? match[1] : '';
}

export function redirectedPinIdentity(value: string): string {
  if (value.length > 4096) return '';
  const match: RegExpMatchArray | null = value.match(
    /^https:\/\/(?:(?:www|uk|m)\.)?pinterest\.com\/pin\/([0-9]{1,30})(?:\/(?:sent\/)?)?(?:[?#][^\s\\]*)?$/i);
  return match ? match[1] : '';
}

// Public redirect resolution is isolated from authenticated website resources.
// No ArkWeb cookies, CSRF, sender/invite parameters, response HTML or tracking
// URLs are forwarded to a business request, logged, or persisted.
export class PinmonyPinLinkResolver {
  private generation: number = 0;
  private cancelTransfer: (() => void) | undefined = undefined;

  cancel(): void {
    this.generation++;
    if (this.cancelTransfer) PinmonyRuntimeLog.info('PinLinkTrace: resolve-cancelled');
    this.cancelTransfer?.();
    this.cancelTransfer = undefined;
  }

  async resolve(value: string, current: () => boolean): Promise<string> {
    this.cancel();
    const token: string = shortPinToken(value);
    if (!token || !current()) throw new Error('pin-link-invalid');
    PinmonyRuntimeLog.info('PinLinkTrace: resolve-start');
    const generation: number = this.generation;
    const live = (): boolean => generation === this.generation && current();
    let session: rcp.Session;
    try { session = rcp.createSession(); }
    catch (_) { throw new Error('pin-link-session-unavailable'); }
    let timer: number = -1;
    const interruption: Promise<rcp.Response> = new Promise<rcp.Response>((_resolve, reject): void => {
      this.cancelTransfer = (): void => {
        try { session.cancel(); } catch (_) {}
        reject(new Error('pin-link-cancelled'));
      };
      timer = setTimeout((): void => { this.cancelTransfer?.(); }, 15000);
    });
    try {
      let target: string = 'https://pin.it/' + token;
      for (let hop: number = 0; hop < 2; hop++) {
        if (!live()) throw new Error('pin-link-cancelled');
        const request: rcp.Request = new rcp.Request(target, 'GET', { 'Accept': 'text/html' });
        request.configuration = { proxy: 'system', transfer: {
          autoRedirect: false, timeout: { connectMs: 5000, transferMs: 10000 }
        } };
        let received: number = 0;
        request.destination = (chunk: ArrayBuffer): void => {
          received += chunk.byteLength;
          if (!live() || received > 65536) throw new Error('pin-link-response');
        };
        const response: rcp.Response = await Promise.race([
          NetworkManager.enqueue(Priority.NORMAL, (): Promise<rcp.Response> => {
            if (!live()) throw new Error('pin-link-cancelled');
            return session.fetch(request);
          }), interruption
        ]);
        if (!live()) throw new Error('pin-link-cancelled');
        PinmonyRuntimeLog.info('PinLinkTrace: redirect-response hop=' + hop.toString() + ' status=' + response.statusCode.toString());
        if (![301,302,303,307,308].includes(response.statusCode)) throw new Error('pin-link-response');
        const header: string | string[] | undefined = response.headers['location'] || response.headers['Location'];
        if (typeof header !== 'string') throw new Error('pin-link-location');
        const pin: string = redirectedPinIdentity(header);
        if (pin) { PinmonyRuntimeLog.info('PinLinkTrace: resolve-ready'); return pin; }
        // This exact intermediate path was observed for Pinterest shared links.
        // Never follow arbitrary hosts, relative links, query strings or redirects.
        const intermediate: string = 'https://api.pinterest.com/url_shortener/' + token + '/redirect/';
        if (hop !== 0 || header !== intermediate) throw new Error('pin-link-target');
        target = intermediate;
      }
      throw new Error('pin-link-unresolved');
    } finally {
      clearTimeout(timer);
      if (generation === this.generation) this.cancelTransfer = undefined;
      try { session.close(); } catch (_) {}
    }
  }
}
