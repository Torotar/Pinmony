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

export class PinmonyReleaseClient {
  releases: PinmonyRelease[] = [];
  private pageReleases: PinmonyRelease[] = [];
  private request: http.HttpRequest | undefined = undefined;
  private revision: number = 0;
  cancel(): void { this.revision++; this.request?.destroy(); this.request = undefined; }
  async latest(installed: string = ''): Promise<PinmonyRelease | undefined> {
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
        if (cursors.includes(oldest.tag_name) || cursors.length >= 100) throw new PinmonyReleaseFailure('检查更新失败（历史版本读取不完整），点击重试');
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
      PinmonyRuntimeLog.warn('ReleaseCheck: event=failed stage=' + stage + ' status=' + status.toString() +
        ' code=' + code.toString() + ' timeout=' + timedOut.toString() + ' elapsedMs=' + (Date.now() - started).toString());
      const reason: string = timedOut ? '连接 GitHub 超过 12 秒' : status === 403 || status === 429 ? 'GitHub 访问受限，HTTP ' + status.toString() :
        status !== 0 && status !== 200 ? 'GitHub 返回 HTTP ' + status.toString() : stage !== 'request' ? '发布信息格式异常' :
        code !== 0 ? '网络错误 ' + code.toString() : '无法连接 GitHub';
      throw new PinmonyReleaseFailure('检查更新失败（' + reason + '），点击重试', status);
    } finally {
      if (deadline !== -1) clearTimeout(deadline);
      request.destroy();
      if (this.request === request) this.request = undefined;
    }
  }
}
