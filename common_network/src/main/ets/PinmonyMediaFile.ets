import { rcp } from '@kit.RemoteCommunicationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { url } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { NetworkManager, Priority } from './PinmonyNativeNetwork';

const MAX_MEDIA_BYTES: number = 32 * 1024 * 1024;
let nextMediaFile: number = 0;
let sweptMediaFiles: boolean = false;
const MEDIA_RECOVERY_BUDGET_MS: number = 12000;

interface MediaFileResponse { statusCode: number; headers: rcp.ResponseHeaders; }

function mediaHeader(response: MediaFileResponse, name: string): string | undefined {
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
    let activeHttp: http.HttpRequest | undefined;
    let activeAttempt: number = -1;
    const cancelTransfer = (): void => {
      if (activeRequest && activeSession) { try { activeSession.cancel(activeRequest); } catch (_) {} }
      if (activeHttp) { try { activeHttp.destroy(); } catch (_) {} activeHttp = undefined; }
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
      let completed: MediaFileResponse | undefined;
      for (let attempt: number = 0; attempt < 2; attempt++) {
        if (!current() || failure) throw new Error('media-cancelled');
        const remaining: number = MEDIA_RECOVERY_BUDGET_MS - (Date.now() - started);
        if (remaining <= 0) { failure = 'timeout'; throw new Error('media-timeout'); }
        activeAttempt = attempt; status = 0;
        if (attempt === 1) {
          const client: http.HttpRequest = http.createHttp();
          activeHttp = client;
          this.trace('event=connection-start host=' + host + ' profile=networkkit-http11 remainingMs=' + remaining.toString());
          try {
            const transfer: Promise<http.HttpResponse> = NetworkManager.enqueue(Priority.NORMAL, async (): Promise<http.HttpResponse> => {
              if (!current() || failure || activeAttempt !== attempt) throw new Error('media-cancelled');
              const budget: number = MEDIA_RECOVERY_BUDGET_MS - (Date.now() - started);
              if (budget <= 0) { failure = 'timeout'; throw new Error('media-timeout'); }
              return client.request(source, { method: http.RequestMethod.GET,
                header: { Accept: 'video/mp4, application/octet-stream', 'Accept-Encoding': 'identity' },
                usingProxy: true, usingProtocol: http.HttpProtocol.HTTP1_1, usingCache: false,
                maxRedirects: 0, expectDataType: http.HttpDataType.ARRAY_BUFFER, maxLimit: MAX_MEDIA_BYTES,
                connectTimeout: budget, readTimeout: budget });
            });
            const response = await Promise.race([transfer, cancelled]);
            if (!current() || failure || activeAttempt !== attempt) throw new Error('media-cancelled');
            const native: http.HttpResponse = response as http.HttpResponse;
            status = native.responseCode;
            if (status !== 200) { failure = 'http'; throw new Error('media-http'); }
            if (!(native.result instanceof ArrayBuffer)) { failure = 'content-type'; throw new Error('media-type'); }
            if (native.result.byteLength > MAX_MEDIA_BYTES) { failure = 'size-limit'; throw new Error('media-size'); }
            if (!file) throw new Error('media-cancelled');
            if (fs.writeSync(file.fd, native.result) !== native.result.byteLength) { failure = 'file-write'; throw new Error('media-write'); }
            bytes = native.result.byteLength;
            completed = { statusCode: status, headers: native.header as rcp.ResponseHeaders };
            this.trace('event=connection-ready host=' + host + ' profile=networkkit-http11 status=' + status.toString());
            break;
          } catch (error) {
            const code: number = Number.isFinite((error as BusinessError).code) ? (error as BusinessError).code : 0;
            if (code === 2300060) failure = 'certificate-validation';
            this.trace('event=connection-failed host=' + host + ' profile=networkkit-http11 status=' + status.toString() +
              ' code=' + code.toString() + ' bytes=' + bytes.toString());
            throw error as Error;
          } finally {
            activeAttempt = -1;
            if (activeHttp === client) { activeHttp = undefined; try { client.destroy(); } catch (_) {} }
          }
        }
        let tlsPending: boolean = false;
        const connectionLimit: number = 5000;
        const profile: string = 'system';
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
          const received: rcp.Response = await Promise.race([transfer, cancelled]);
          completed = { statusCode: received.statusCode, headers: received.headers };
          break;
        } catch (error) {
          const code: number = Number.isFinite((error as BusinessError).code) ? (error as BusinessError).code : 0;
          this.trace('event=connection-failed host=' + host + ' profile=' + profile + ' status=' + status.toString() +
            ' code=' + code.toString() + ' bytes=' + bytes.toString());
          const tlsTimeout: boolean = code === 1007900028 && tlsPending;
          const certificateFailure: boolean = code === 1007900060;
          if (MEDIA_RECOVERY_BUDGET_MS - (Date.now() - started) < 4000 || attempt !== 0 ||
              (code !== 1007900035 && !tlsTimeout && !certificateFailure) || status !== 0 || bytes !== 0 || !current() || failure) {
            if (certificateFailure) failure = 'certificate-validation';
            throw error as Error;
          }
          // The alternate native stack must independently pass platform certificate validation.
          this.trace('event=transport-compatibility reason=' + (certificateFailure ? 'certificate-validation' : tlsTimeout ? 'tls-timeout' : 'ssl-connect') + ' next=networkkit-http11');
        } finally {
          // Reject callbacks from a closed attempt before allowing another profile to write the file.
          activeAttempt = -1; activeRequest = undefined; activeSession = undefined;
          try { session.close(); } catch (_) {}
        }
      }
      if (!completed) throw new Error('media-unavailable');
      const response: MediaFileResponse = completed;
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
