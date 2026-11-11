import { cacheDownload } from '@kit.BasicServicesKit';
import { PinmonyRuntimeLog } from 'common_foundation';

let pinmonyDownloadTraceEnabled: boolean = false;

/** Observes the existing Image pipeline. Never downloads, retries or changes its cache policy. */
export class PinmonyImageLoadTrace {
  private generation: number = -1;
  private mountedAt: number = -1;
  private rawDataAt: number = -1;
  private rawDecodedAt: number = -1;
  private rawFailedAt: number = -1;

  record(task: number, generation: number, index: number, sourceAt: number, url: string,
    phase: string, code: number = 0, failureInfo?: cacheDownload.DownloadInfo): void {
    const now: number = Date.now();
    if (this.generation !== generation) {
      this.generation = generation;
      this.mountedAt = -1;
      this.rawDataAt = -1;
      this.rawDecodedAt = -1;
      this.rawFailedAt = -1;
    }
    if (!pinmonyDownloadTraceEnabled) {
      try {
        cacheDownload.setDownloadInfoListSize(32);
        pinmonyDownloadTraceEnabled = true;
      } catch (_) {
        // Availability is reported below; no error text or URL enters logs.
      }
    }
    if (phase === 'node-mounted') this.mountedAt = now;
    if (phase === 'native-data-ready') this.rawDataAt = now;
    if (phase === 'native-decoded') this.rawDecodedAt = now;
    if (phase === 'native-failed') this.rawFailedAt = now;
    const rawAt: number = phase === 'data-ready' ? this.rawDataAt :
      phase === 'decoded' ? this.rawDecodedAt : phase === 'failed' ? this.rawFailedAt : -1;
    PinmonyRuntimeLog.info('ImageLoadTrace: task=' + task.toString() + ' generation=' + generation.toString() +
      ' index=' + index.toString() + ' phase=' + phase + ' sinceSourceMs=' + Math.max(0, now - sourceAt).toString() +
      ' sinceMountMs=' + (this.mountedAt < 0 ? -1 : Math.max(0, now - this.mountedAt)).toString() +
      ' sinceNativeDataMs=' + (this.rawDataAt < 0 ? -1 : Math.max(0, now - this.rawDataAt)).toString() +
      ' callbackQueueMs=' + (rawAt < 0 ? -1 : Math.max(0, now - rawAt)).toString() +
      ' code=' + (Number.isFinite(code) ? code : 0).toString() + ' frameConfirmed=false');
    if (phase === 'native-data-ready' || phase === 'native-failed') {
      this.downloadInfo(task, generation, index, url, phase, failureInfo);
    }
  }

  private downloadInfo(task: number, generation: number, index: number, url: string,
    phase: string, failureInfo?: cacheDownload.DownloadInfo): void {
    let info: cacheDownload.DownloadInfo | undefined = failureInfo;
    let availability: string = 'unavailable';
    const evidence: string = failureInfo ? 'error-callback' : 'latest-url-record';
    try {
      if (!info && /^https:\/\//i.test(url)) info = cacheDownload.getDownloadInfo(url);
      if (info) availability = 'available';
    } catch (_) { availability = 'query-failed'; }
    let metrics: string = '';
    if (info) {
      const perf: cacheDownload.PerformanceInfo = info.performance;
      metrics = ' bytes=' + this.metric(info.resource.size) + ' dnsMs=' + this.metric(perf.dnsTime) +
        ' connectMs=' + this.metric(perf.connectTime) + ' tlsMs=' + this.metric(perf.tlsTime) +
        ' firstSendMs=' + this.metric(perf.firstSendTime) + ' firstReceiveMs=' + this.metric(perf.firstReceiveTime) +
        ' totalMs=' + this.metric(perf.totalTime) + ' redirectMs=' + this.metric(perf.redirectTime);
    }
    // The URL lookup has no request ID or timestamp: it cannot prove this generation's download or a cache hit.
    PinmonyRuntimeLog.info('ImageDownloadTrace: task=' + task.toString() + ' generation=' + generation.toString() +
      ' index=' + index.toString() + ' phase=' + phase + ' availability=' + availability +
      ' evidence=' + evidence + ' currentRequestConfirmed=' + (!!failureInfo).toString() +
      ' proxyRoute=unknown cacheHit=unknown' + metrics);
  }

  private metric(amount: number): string {
    return Number.isFinite(amount) ? amount.toString() : 'unknown';
  }
}
