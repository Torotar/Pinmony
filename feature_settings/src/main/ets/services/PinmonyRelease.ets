import { PinmonyI18n } from 'common_foundation';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PinmonyRuntimeLog } from 'common_foundation';

export class PinmonyReleaseFailure extends Error {
  feedback: string;
  status: number;
  constructor(feedback: string, status: number = 0) { super(feedback); this.feedback = feedback; this.status = status; }
}

function decodeEntities(value: string): string {
  return value.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, '&');
}

export function parseReleaseFeed(source: string): PinmonyRelease | undefined {
  return parseReleaseHistory(source)[0];
}

export function parseReleaseHistory(source: string): PinmonyRelease[] {
  if (!/<feed\b/.test(source) || !/<\/feed>/.test(source)) throw new Error('Invalid release feed');
  const entries = source.match(/<entry>[\s\S]*?<\/entry>/g) || [];
  const releases: PinmonyRelease[] = [];
  for (const entry of entries) {
    const link = entry.match(/<link\b[^>]*href="(https:\/\/github\.com\/Torotar\/Pinmony\/releases\/tag\/([vV]?\d+\.\d+\.\d+))"[^>]*\/>/);
    if (!link) continue;
    const content = entry.match(/<content\b[^>]*>([\s\S]*?)<\/content>/);
    const html: string = decodeEntities(content ? content[1] : '');
    const notes: string = decodeEntities(html.replace(/<\/?(?:p|h[1-6]|ul|ol|li|br)\b[^>]*>/gi, '\n')
      .replace(/<[^>]*>/g, '')).replace(/\n{3,}/g, '\n\n').trim().slice(0, 60000);
    const release: PinmonyRelease = { tag_name: link[2], html_url: link[1], body: notes, draft: false, prerelease: false };
    if (!releases.some((item: PinmonyRelease) => !isNewerRelease(item.tag_name, release.tag_name) && !isNewerRelease(release.tag_name, item.tag_name))) releases.push(release);
  }
  return releases.sort((a: PinmonyRelease, b: PinmonyRelease) => isNewerRelease(a.tag_name, b.tag_name) ? -1 : isNewerRelease(b.tag_name, a.tag_name) ? 1 : 0);
}

export interface PinmonyRelease {
  tag_name: string;
  html_url: string;
  body: string;
  draft: boolean;
  prerelease: boolean;
}

export function isNewerRelease(tag: string, installed: string): boolean {
  const pattern: RegExp = /^[vV]?(\d+)\.(\d+)\.(\d+)$/;
  const latest = tag.match(pattern);
  const current = installed.match(pattern);
  if (!latest || !current) return false;
  for (let index: number = 1; index <= 3; index++) {
    if (Number(latest[index]) !== Number(current[index])) return Number(latest[index]) > Number(current[index]);
  }
  return false;
}

interface ReleaseSnapshot {
  installed: string;
  expiresAt: number;
  release: PinmonyRelease | undefined;
  releases: PinmonyRelease[];
}

interface PendingRelease {
  installed: string;
  sequence: number;
  promise: Promise<ReleaseSnapshot>;
  worker: PinmonyReleaseClient;
  readers: number;
}

function copyRelease(release: PinmonyRelease): PinmonyRelease {
  return { tag_name: release.tag_name, html_url: release.html_url, body: release.body,
    draft: release.draft, prerelease: release.prerelease };
}

export class PinmonyReleaseClient {
  private static cache: ReleaseSnapshot | undefined = undefined;
  private static pending: PendingRelease | undefined = undefined;
  private static sequence: number = 0;
  releases: PinmonyRelease[] = [];
  private pageReleases: PinmonyRelease[] = [];
  private request: http.HttpRequest | undefined = undefined;
  private revision: number = 0;
  private shared: PendingRelease | undefined = undefined;
  cancel(): void {
    this.revision++; this.request?.destroy(); this.request = undefined;
    const shared: PendingRelease | undefined = this.shared;
    this.shared = undefined;
    if (shared) {
      shared.readers--;
      if (shared.readers === 0 && PinmonyReleaseClient.pending === shared) {
        PinmonyReleaseClient.pending = undefined;
        if (shared.sequence === PinmonyReleaseClient.sequence) PinmonyReleaseClient.sequence++;
        shared.worker.cancel();
      }
    }
  }
  async latest(installed: string = '', force: boolean = false): Promise<PinmonyRelease | undefined> {
    this.cancel();
    const revision: number = this.revision;
    let snapshot: ReleaseSnapshot | undefined = PinmonyReleaseClient.cache;
    if (force || !snapshot || snapshot.installed !== installed || Date.now() >= snapshot.expiresAt) {
      let pending: PendingRelease | undefined = PinmonyReleaseClient.pending;
      if (!pending || pending.installed !== installed) {
        const sequence: number = ++PinmonyReleaseClient.sequence;
        const worker: PinmonyReleaseClient = new PinmonyReleaseClient();
        const promise: Promise<ReleaseSnapshot> = worker.readLatest(installed).then((release): ReleaseSnapshot => {
          const result: ReleaseSnapshot = { installed: installed, expiresAt: Date.now() + 300000,
            release: release ? copyRelease(release) : undefined, releases: worker.releases.map(copyRelease) };
          if (sequence === PinmonyReleaseClient.sequence) PinmonyReleaseClient.cache = result;
          return result;
        }).finally((): void => {
          if (PinmonyReleaseClient.pending?.sequence === sequence) PinmonyReleaseClient.pending = undefined;
        });
        pending = { installed: installed, sequence: sequence, promise: promise, worker: worker, readers: 0 };
        PinmonyReleaseClient.pending = pending;
      } else PinmonyRuntimeLog.info('ReleaseCheck: event=joined');
      this.shared = pending;
      pending.readers++;
      try { snapshot = await pending.promise; }
      finally {
        if (this.shared === pending) { this.shared = undefined; pending.readers--; }
      }
    } else PinmonyRuntimeLog.info('ReleaseCheck: event=cache-hit');
    if (revision !== this.revision) throw new Error('Release check cancelled');
    this.releases = snapshot.releases.map(copyRelease);
    return snapshot.release ? copyRelease(snapshot.release) : undefined;
  }

  private async readLatest(installed: string): Promise<PinmonyRelease | undefined> {
    this.cancel();
    const revision: number = this.revision;
    this.releases = [];
    this.pageReleases = [];
    let release: PinmonyRelease | undefined = undefined;
    let usedFeed: boolean = false;
    try { release = await this.load(false); }
    catch (error) {
      if (revision !== this.revision || !(error instanceof PinmonyReleaseFailure) || (error.status !== 403 && error.status !== 429)) throw error as Error;
      PinmonyRuntimeLog.info('ReleaseCheck: event=feed-fallback reason=api-denied');
      release = await this.load(true);
      usedFeed = true;
    }
    if (installed && release && isNewerRelease(release.tag_name, installed)) {
      if (!usedFeed) await this.load(true);
      const history: PinmonyRelease[] = [];
      const cursors: string[] = [];
      while (this.pageReleases.length > 0) {
        if (revision !== this.revision) throw new Error('Release check cancelled');
        for (const item of this.pageReleases) {
          if (isNewerRelease(item.tag_name, installed) && !history.some((existing: PinmonyRelease) => existing.tag_name.toLowerCase() === item.tag_name.toLowerCase())) history.push(item);
        }
        const oldest: PinmonyRelease = this.pageReleases[this.pageReleases.length - 1];
        if (!isNewerRelease(oldest.tag_name, installed)) break;
        if (cursors.includes(oldest.tag_name) || cursors.length >= 100) throw new PinmonyReleaseFailure(PinmonyI18n.message("pm_update_check_failed_incomplete_release_history_tap_to_retry_59646f2e"));
        cursors.push(oldest.tag_name);
        await this.load(true, oldest.tag_name);
      }
      if (!history.some((item: PinmonyRelease) => item.tag_name.toLowerCase() === release!.tag_name.toLowerCase())) history.push(release);
      this.releases = history.sort((a: PinmonyRelease, b: PinmonyRelease) => isNewerRelease(a.tag_name, b.tag_name) ? -1 : 1);
    } else this.releases = release ? [release] : [];
    return release;
  }
  private async load(feed: boolean, after: string = ''): Promise<PinmonyRelease | undefined> {
    const request = http.createHttp();
    this.request = request;
    let deadline: number = -1;
    const started: number = Date.now();
    let stage: string = 'request';
    let status: number = 0;
    let timedOut: boolean = false;
    PinmonyRuntimeLog.info('ReleaseCheck: event=start source=' + (feed ? 'atom' : 'api') + ' proxy=system protocol=http11 budgetMs=12000');
    try {
      const pending: Promise<http.HttpResponse> = request.request(feed ? 'https://github.com/Torotar/Pinmony/releases.atom' + (after ? '?after=' + encodeURIComponent(after) : '') : 'https://api.github.com/repos/Torotar/Pinmony/releases/latest', {
        method: http.RequestMethod.GET,
        header: { 'Accept': feed ? 'application/atom+xml' : 'application/vnd.github+json', 'User-Agent': 'Pinmony' },
        usingProxy: true, usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: 10000, readTimeout: 10000, usingCache: false,
        expectDataType: http.HttpDataType.STRING
      });
      const timeout: Promise<http.HttpResponse> = new Promise<http.HttpResponse>((_resolve, reject) => {
        deadline = setTimeout(() => { timedOut = true; reject(new Error('Release check timed out')); }, 12000);
      });
      const response: http.HttpResponse = await Promise.race([pending, timeout]);
      status = response.responseCode;
      PinmonyRuntimeLog.info('ReleaseCheck: event=response status=' + status.toString() + ' elapsedMs=' + (Date.now() - started).toString());
      if (response.responseCode === 404 && !feed) return undefined;
      if (response.responseCode !== 200 || typeof response.result !== 'string' || response.result.length > 262144) {
        throw new Error('Release request failed');
      }
      stage = 'parse';
      if (feed) {
        this.pageReleases = parseReleaseHistory(response.result);
        const release = this.pageReleases[0];
        PinmonyRuntimeLog.info('ReleaseCheck: event=success source=atom elapsedMs=' + (Date.now() - started).toString());
        return release;
      }
      const release = JSON.parse(response.result) as PinmonyRelease;
      stage = 'validate';
      if (typeof release.tag_name !== 'string' || !/^[vV]?\d+\.\d+\.\d+$/.test(release.tag_name) ||
        typeof release.html_url !== 'string' || !/^https:\/\/github\.com\/Torotar\/Pinmony\/releases\/tag\/[^/?#]+$/.test(release.html_url) ||
        release.draft !== false || release.prerelease !== false ||
        (release.body !== null && typeof release.body !== 'string')) throw new Error('Invalid release');
      release.body = (release.body || '').slice(0, 60000);
      PinmonyRuntimeLog.info('ReleaseCheck: event=success elapsedMs=' + (Date.now() - started).toString());
      return release;
    } catch (error) {
      const rawCode: number = (error as BusinessError).code;
      const code: number = Number.isFinite(rawCode) ? rawCode : 0;
      if (!feed && (status === 403 || status === 429)) {
        // latest() handles this branch through the existing public Atom feed.
        PinmonyRuntimeLog.info('ReleaseCheck: event=api-denied status=' + status.toString() + ' recovery=atom');
      } else {
        PinmonyRuntimeLog.warn('ReleaseCheck: event=failed stage=' + stage + ' status=' + status.toString() +
          ' code=' + code.toString() + ' timeout=' + timedOut.toString() + ' elapsedMs=' + (Date.now() - started).toString());
      }
      const reason: string = timedOut ? PinmonyI18n.message('pm_github_connection_exceeded_12_seconds_f13449d8') : status === 403 || status === 429 ? PinmonyI18n.message('pm_github_access_restricted_http_f36de88e') + status.toString() :
        status !== 0 && status !== 200 ? PinmonyI18n.message('pm_github_returned_http_8ae4d6ab') + status.toString() : stage !== 'request' ? PinmonyI18n.message('pm_invalid_release_information_1050d6f8') :
        code !== 0 ? PinmonyI18n.message('pm_network_error_d8e20c2f') + code.toString() : PinmonyI18n.message('pm_unable_to_connect_to_github_a30d0dd6');
      throw new PinmonyReleaseFailure(PinmonyI18n.message("pm_update_check_failed_eaae93d1") + reason + PinmonyI18n.message("pm_tap_to_retry_66897f19"), status);
    } finally {
      if (deadline !== -1) clearTimeout(deadline);
      request.destroy();
      if (this.request === request) this.request = undefined;
    }
  }
}
