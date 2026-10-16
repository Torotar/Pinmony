import { rcp } from '@kit.RemoteCommunicationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { url } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { NetworkManager, Priority } from './PinmonyNativeNetwork';

const MAX_MEDIA_BYTES: number = 32 * 1024 * 1024;
let nextMediaFile: number = 0;
let sweptMediaFiles: boolean = false;
const MEDIA_RECOVERY_BUDGET_MS: number = 12000;

function mediaHeader(response: rcp.Response, name: string): string | undefined {
  const keys: string[] = Object.keys(response.headers).filter((key: string): boolean => key.toLowerCase() === name);
  if (keys.length === 0) return undefined;
  if (keys.length !== 1) return '';
  const value: string | string[] | undefined = response.headers[keys[0]];
  return typeof value === 'string' ? value.trim() : Array.isArray(value) && value.length === 1 ? value[0].trim() : '';
}

export interface PinmonyMediaFileLease {
  fd: number;
  size: number;
  release: () => void;
}

export function acceptsMediaFileUrl(value: string): boolean {
  if (!value || value.length > 8192) return false;
  try {
    const parsed: url.URL = new url.URL(value);
    return parsed.protocol === 'https:' && /(^|\.)pinimg\.com$/.test(parsed.hostname) &&
      !parsed.username && !parsed.password && (!parsed.port || parsed.port === '443') &&
      !parsed.hash && /^\/videos\/.+\.mp4$/i.test(parsed.pathname);
  } catch (_) { return false; }
}

// Native-only public CDN reader. Never exposed through the JS request proxy or given Web credentials.
export class PinmonyMediaFile {
  private generation: number = 0;
  private abort: (() => void) | undefined;
  private readonly trace: (event: string) => void;
  constructor(trace: (event: string) => void) { this.trace = trace; }

  cancel(): void {
    this.generation++;
    const abort: (() => void) | undefined = this.abort; this.abort = undefined;
    if (abort) abort();
  }

  async read(source: string, cacheDir: string, ownerCurrent: () => boolean): Promise<PinmonyMediaFileLease> {
    this.cancel();
    if (!acceptsMediaFileUrl(source) || !cacheDir || !ownerCurrent()) throw new Error('media-unavailable');
    const generation: number = this.generation;
    const current = (): boolean => generation === this.generation && ownerCurrent();
    // Remove only this reader's files left by a previous process, once before creating any new lease.
    if (!sweptMediaFiles) {
      sweptMediaFiles = true;
      try {
        fs.listFileSync(cacheDir).filter((name: string): boolean => /^pinmony-video-\d+-\d+\.mp4$/.test(name))
          .forEach((name: string) => { try { fs.unlinkSync(cacheDir + '/' + name); } catch (_) {} });
      } catch (_) {}
    }
    const path: string = cacheDir + '/pinmony-video-' + Date.now().toString() + '-' + (++nextMediaFile).toString() + '.mp4';
    let file: fs.File | undefined;
    let bytes: number = 0;
    let status: number = 0;
    let failure: string = '';
    let deadline: number = -1;
    const started: number = Date.now();
    const host: string = new url.URL(source).hostname;
    let activeRequest: rcp.Request | undefined;
    let activeSession: rcp.Session | undefined;
    let activeAttempt: number = -1;
    const cancelTransfer = (): void => {
      if (activeRequest && activeSession) { try { activeSession.cancel(activeRequest); } catch (_) {} }
    };
    try {
      file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      this.trace('event=download-start proxy=system host=' + host + ' session=isolated');
      const cancelled: Promise<rcp.Response> = new Promise<rcp.Response>((_resolve, reject) => {
        this.abort = () => { failure = failure || 'cancelled'; cancelTransfer(); reject(new Error('media-cancelled')); };
        deadline = setTimeout(() => {
          failure = 'timeout'; cancelTransfer(); reject(new Error('media-timeout'));
        }, MEDIA_RECOVERY_BUDGET_MS);
      });
      let completed: rcp.Response | undefined;
      for (let attempt: number = 0; attempt < 2; attempt++) {
        if (!current() || failure) throw new Error('media-cancelled');
        const remaining: number = MEDIA_RECOVERY_BUDGET_MS - (Date.now() - started);
        if (remaining <= 0) { failure = 'timeout'; throw new Error('media-timeout'); }
        activeAttempt = attempt; status = 0;
        let tlsPending: boolean = false;
        const connectionLimit: number = attempt === 0 ? 5000 : remaining;
        const profile: string = attempt === 0 ? 'system' : 'tls12';
        const session: rcp.Session = rcp.createSession();
        const request: rcp.Request = new rcp.Request(source, 'GET', {
          Accept: 'video/mp4, application/octet-stream', 'Accept-Encoding': 'identity' });
        activeSession = session; activeRequest = request;
        request.configuration = { proxy: 'system', transfer: { autoRedirect: false,
          timeout: { connectMs: Math.min(connectionLimit, remaining), transferMs: remaining } },
          tracing: { collectTimeInfo: true, httpEventsHandler: {
            onStatusCodeReceive: (value: number) => { if (activeAttempt === attempt && current()) status = value; },
            onTimeInfo: (value: rcp.TimeInfo) => {
              if (activeAttempt !== attempt || !current()) return;
              tlsPending = Number.isFinite(value.connectTimeMs) && Number.isFinite(value.nameLookupTimeMs) &&
                value.connectTimeMs > value.nameLookupTimeMs && value.tlsHandshakeTimeMs === 0 && value.startTransferTimeMs === 0;
              const metric = (number: number): string => Number.isFinite(number) && number >= 0 ? number.toString() : 'unknown';
              this.trace('event=connection-time host=' + host + ' profile=' + profile +
                ' dnsMs=' + metric(value.nameLookupTimeMs) + ' connectMs=' + metric(value.connectTimeMs) +
                ' tlsMs=' + metric(value.tlsHandshakeTimeMs) + ' firstByteMs=' + metric(value.startTransferTimeMs));
            }
          } } };
        if (attempt === 1) request.configuration.security = { tlsRange: { min: 'TlsV1.2', max: 'TlsV1.2' } };
        request.destination = (chunk: ArrayBuffer): void => {
          if (!current() || failure || activeAttempt !== attempt) throw new Error('media-cancelled');
          if (status !== 200) { failure = 'http'; throw new Error('media-http'); }
          if (bytes + chunk.byteLength > MAX_MEDIA_BYTES) { failure = 'size-limit'; throw new Error('media-size'); }
          if (!file) throw new Error('media-cancelled');
          if (fs.writeSync(file.fd, chunk) !== chunk.byteLength) { failure = 'file-write'; throw new Error('media-write'); }
          bytes += chunk.byteLength;
        };
        this.trace('event=connection-start host=' + host + ' profile=' + profile + ' remainingMs=' + remaining.toString());
        try {
          const transfer: Promise<rcp.Response> = NetworkManager.enqueue(Priority.NORMAL, async (): Promise<rcp.Response> => {
            if (!current() || failure || activeAttempt !== attempt) throw new Error('media-cancelled');
            const budget: number = MEDIA_RECOVERY_BUDGET_MS - (Date.now() - started);
            if (budget <= 0) { failure = 'timeout'; throw new Error('media-timeout'); }
            request.configuration!.transfer!.timeout = { connectMs: Math.min(connectionLimit, budget), transferMs: budget };
            return session.fetch(request);
          });
          completed = await Promise.race([transfer, cancelled]);
          break;
        } catch (error) {
          const code: number = Number.isFinite((error as BusinessError).code) ? (error as BusinessError).code : 0;
          this.trace('event=connection-failed host=' + host + ' profile=' + profile + ' status=' + status.toString() +
            ' code=' + code.toString() + ' bytes=' + bytes.toString());
          const tlsTimeout: boolean = code === 1007900028 && tlsPending;
          if (MEDIA_RECOVERY_BUDGET_MS - (Date.now() - started) < 4000 || attempt !== 0 ||
              (code !== 1007900035 && !tlsTimeout) || status !== 0 || bytes !== 0 || !current() || failure) throw error as Error;
          this.trace('event=tls-compatibility reason=' + (tlsTimeout ? 'tls-timeout' : 'ssl-connect') + ' next=tls12');
        } finally {
          // Reject callbacks from a closed attempt before allowing another profile to write the file.
          activeAttempt = -1; activeRequest = undefined; activeSession = undefined;
          try { session.close(); } catch (_) {}
        }
      }
      if (!completed) throw new Error('media-unavailable');
      const response: rcp.Response = completed;
      if (!current() || failure) throw new Error('media-cancelled');
      status = response.statusCode;
      if (status !== 200 || bytes < 12) { failure = 'http-or-empty'; throw new Error('media-http'); }
      const type: string | undefined = mediaHeader(response, 'content-type');
      if (typeof type !== 'string' || !/^(video\/mp4|application\/octet-stream)(?:;|$)/i.test(type)) {
        failure = 'content-type'; throw new Error('media-type');
      }
      const encoding: string | undefined = mediaHeader(response, 'content-encoding');
      if (encoding !== undefined && encoding.toLowerCase() !== 'identity' || mediaHeader(response, 'content-range') !== undefined) {
        failure = 'content-encoding'; throw new Error('media-encoding');
      }
      const length: string | undefined = mediaHeader(response, 'content-length');
      if (length !== undefined && (typeof length !== 'string' || !/^\d+$/.test(length) || Number(length) !== bytes)) {
        failure = 'incomplete'; throw new Error('media-incomplete');
      }
      fs.closeSync(file); file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const header: ArrayBuffer = new ArrayBuffer(12);
      const read: number = fs.readSync(file.fd, header);
      const signature: Uint8Array = new Uint8Array(header);
      if (read !== 12 || signature[4] !== 102 || signature[5] !== 116 || signature[6] !== 121 || signature[7] !== 112) {
        failure = 'signature'; throw new Error('media-format');
      }
      const retained: fs.File = file; file = undefined;
      let released: boolean = false;
      this.trace('event=download-ready status=200 bytes=' + bytes.toString() + ' elapsedMs=' + (Date.now() - started).toString());
      return { fd: retained.fd, size: bytes, release: (): void => {
        if (released) return; released = true;
        try { fs.closeSync(retained); } catch (_) {}
        try { fs.unlinkSync(path); } catch (_) {}
      } };
    } catch (error) {
      const code: number = Number.isFinite((error as BusinessError).code) ? (error as BusinessError).code : 0;
      this.trace('event=download-failed status=' + status.toString() + ' code=' + code.toString() +
        ' reason=' + (failure || 'transport') + ' bytes=' + bytes.toString() + ' elapsedMs=' + (Date.now() - started).toString());
      throw error as Error;
    } finally {
      if (deadline >= 0) clearTimeout(deadline);
      if (generation === this.generation) this.abort = undefined;
      if (file) {
        try { fs.closeSync(file); } catch (_) {}
        try { fs.unlinkSync(path); } catch (_) {}
      }
    }
  }
}
