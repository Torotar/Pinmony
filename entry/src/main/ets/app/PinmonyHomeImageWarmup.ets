import { cacheDownload } from '@kit.BasicServicesKit';
import { PinmonyRuntimeLog } from 'common_foundation';

let pinmonyHomeImageWarmupAttempted: boolean = false;

/** Prepare the native Image downloader independently of the live home feed. */
export class PinmonyHomeImageWarmup {
  private source: string = '';
  private generation: number = 0;
  private timer: number = -1;
  private success: (() => void) | undefined = undefined;
  private failure: ((error: cacheDownload.DownloadError) => void) | undefined = undefined;

  prepare(url: string): void {
    // Only reuse an actual, public finite thumbnail URL; never rewrite it or
    // send a credential, business request, partial-image request or fake URL.
    if (pinmonyHomeImageWarmupAttempted || url.length > 2048 ||
        !/^https:\/\/i\.pinimg\.com\/(?:170|236|474|564|736)x\/[a-zA-Z0-9/_-]+\.(?:jpe?g|png|webp)$/i.test(url)) return;
    pinmonyHomeImageWarmupAttempted = true;
    const generation: number = ++this.generation;
    const startedAt: number = Date.now();
    this.source = url;
    const finish = (phase: string): void => {
      if (generation !== this.generation || this.source !== url) return;
      this.detach();
      PinmonyRuntimeLog.info('HomeImageWarmup: phase=' + phase +
        ' elapsedMs=' + (Date.now() - startedAt).toString() + ' connectionReuseConfirmed=false');
    };
    this.success = (): void => finish('data-ready');
    this.failure = (_error: cacheDownload.DownloadError): void => finish('failed');
    try {
      cacheDownload.onDownloadSuccess(url, this.success);
      cacheDownload.onDownloadError(url, this.failure);
      this.timer = setTimeout((): void => finish('observer-expired'), 15000);
      PinmonyRuntimeLog.info('HomeImageWarmup: phase=dispatched feedBlocked=false');
      // LAZY could hit a local file and leave the downloader connection cold.
      // One FORCE request uses the same system cache/download path as Image.
      // Do not await it, gate the list on it, or clear the image cache.
      cacheDownload.download(url, { cacheStrategy: cacheDownload.CacheStrategy.FORCE });
    } catch (_) { finish('unavailable'); }
  }

  dispose(): void {
    this.generation++;
    this.detach();
  }

  private detach(): void {
    if (this.timer >= 0) clearTimeout(this.timer);
    this.timer = -1;
    try { if (this.success) cacheDownload.offDownloadSuccess(this.source, this.success); } catch (_) {}
    try { if (this.failure) cacheDownload.offDownloadError(this.source, this.failure); } catch (_) {}
    this.success = undefined;
    this.failure = undefined;
    this.source = '';
    // Cancellation is URL-wide. Never cancel an Image or another page's
    // request just to detach this observer; an already issued read may finish.
  }
}
