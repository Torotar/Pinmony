import { PinmonyNativeNetwork } from 'common_network';
import { PinmonyImageCrop } from 'common_ui';
import { util } from '@kit.ArkTS';
import { PinmonyPhotoHistoryItem, PinmonyPhotoHistoryPage, parsePhotoHistory } from 'feature_search';
import { PinmonyBusinessSessionContext } from 'common_session';
import { parsePhotoSearch, PinmonySearchResult } from 'feature_search';
interface PhotoPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  page: () => string;
  active: () => boolean;
  pick: () => Promise<string>;
  read: (uri: string) => Promise<ArrayBuffer>;
  jpeg: (bytes: ArrayBuffer) => Promise<ArrayBuffer>;
  open: (url: string, source: string) => void;
}
interface PhotoHistoryDeleteResource { status: string; code: number; endpoint_name: string; data: Object | null; }
interface PhotoHistoryDeleteReply { resource_response: PhotoHistoryDeleteResource; }
export class PinmonyPhotoSearchFlow {
  private revision: number = 0;
  private job: string = '';
  private results: PinmonySearchResult[] = [];
  private page: string = '';
  private account: string = '';
  private epoch: number = -1;
  private uri: string = '';
  private bytes: ArrayBuffer | undefined = undefined;
  private readingBytes: Promise<ArrayBuffer> | undefined = undefined;
  private historyItems: PinmonyPhotoHistoryItem[] = [];
  private historyWritePending: boolean = false;
  private readonly uncertainHistoryIds: Set<string> = new Set<string>();
  private sequence: number = Date.now();
  private readonly ports: PhotoPorts;
  constructor(ports: PhotoPorts) { this.ports = ports; }
  cancel(): void {
    this.revision++;
    if (this.job) this.ports.network().cancel(this.job);
    this.job = ''; this.results = [];
    this.uri = '';
    this.bytes = undefined;
    this.readingBytes = undefined;
    this.historyItems = [];
  }
  async search(onSelected?: (uri: string) => void): Promise<PinmonySearchResult[] | undefined> {
    this.cancel();
    const revision: number = this.revision, session: PinmonyBusinessSessionContext = this.ports.session();
    this.page = this.ports.page(); this.account = session.accountId; this.epoch = session.generation;
    const page: string = this.page, account: string = this.account, epoch: number = this.epoch;
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = this.ports.session();
      return revision === this.revision && this.ports.active() && actual.authenticated &&
        actual.accountId === account && actual.generation === epoch && actual.origin === session.origin && this.ports.page() === page;
    };
    if (!current() || page !== session.origin + '/search/') throw new Error('photo-unavailable');
    const uri: string = await this.ports.pick();
    if (!current() || !uri) return undefined;
    this.uri = uri;
    if (onSelected) onSelected(uri);
    const bytes: ArrayBuffer = await this.readPhoto(uri);
    if (!current()) return undefined;
    if (bytes.byteLength <= 4 * 1024 * 1024) this.bytes = bytes;
    this.job = 'native_photo_search_' + (++this.sequence).toString();
    const text: string = await this.ports.network().searchUploadedPhoto(bytes, page, this.ports.session, current, this.job);
    if (!current()) return undefined;
    this.results = parsePhotoSearch(text, session.origin);
    return this.results.slice();
  }
  async crop(crop: PinmonyImageCrop): Promise<PinmonySearchResult[] | undefined> {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if (!this.uri || !this.ports.active() || !session.authenticated || session.accountId !== this.account ||
      session.generation !== this.epoch || this.ports.page() !== this.page) return undefined;
    const uri: string = this.uri, revision: number = ++this.revision;
    if (this.job) this.ports.network().cancel(this.job);
    this.job = ''; this.results = [];
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = this.ports.session();
      return revision === this.revision && this.ports.active() && actual.authenticated &&
        actual.accountId === this.account && actual.generation === this.epoch &&
        actual.origin === session.origin && this.ports.page() === this.page;
    };
    const bytes: ArrayBuffer = await this.readPhoto(uri);
    if (!current()) return undefined;
    if (bytes.byteLength <= 4 * 1024 * 1024) this.bytes = bytes;
    this.job = 'native_photo_search_' + (++this.sequence).toString();
    const text: string = await this.ports.network().searchUploadedPhoto(bytes, this.page, this.ports.session, current, this.job,
      { x: crop.x, y: crop.y, w: crop.w, h: crop.h });
    if (!current()) return undefined;
    this.results = parsePhotoSearch(text, session.origin);
    return this.results.slice();
  }
  private readPhoto(uri: string): Promise<ArrayBuffer> {
    if (this.bytes) return Promise.resolve(this.bytes);
    if (this.readingBytes) return this.readingBytes;
    const pending: Promise<ArrayBuffer> = this.ports.read(uri).finally((): void => {
      if (this.readingBytes === pending) this.readingBytes = undefined;
    });
    this.readingBytes = pending;
    return pending;
  }
  open(id: string): void {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const item: PinmonySearchResult | undefined = this.results.find((p: PinmonySearchResult): boolean => p.id === id);
    if (!item || !this.ports.active() || !session.authenticated || session.accountId !== this.account ||
      session.generation !== this.epoch || this.ports.page() !== this.page) return;
    this.ports.open(item.targetUrl, this.page);
  }
  async history(cursor: string): Promise<PinmonyPhotoHistoryPage> {
    if (!cursor) { this.cancel(); const s: PinmonyBusinessSessionContext = this.ports.session();
      if (s.accountId !== this.account || s.generation !== this.epoch) this.uncertainHistoryIds.clear();
      this.account = s.accountId; this.epoch = s.generation; this.page = this.ports.page(); }
    const revision: number = this.revision;
    const live = (): boolean => revision === this.revision && this.ports.active() && this.ports.session().authenticated &&
      this.ports.session().accountId === this.account && this.ports.session().generation === this.epoch && this.ports.page() === this.page;
    if (!live()) throw new Error('history-stale');
    this.job = 'native_photo_history_' + (++this.sequence).toString();
    const bytes: ArrayBuffer = await this.ports.network().readPhotoHistory(cursor, '', this.ports.session, live, this.job);
    if (!live()) throw new Error('history-stale');
    const page: PinmonyPhotoHistoryPage = parsePhotoHistory(util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes)), cursor);
    this.historyItems = cursor ? this.historyItems.concat(page.items.filter((p: PinmonyPhotoHistoryItem): boolean => !this.historyItems.some((v: PinmonyPhotoHistoryItem): boolean => v.id === p.id))).slice(0, 1000) : page.items;
    return page;
  }
  async deleteHistory(ids: string[]): Promise<void> {
    if (this.historyWritePending || ids.length < 1 || ids.length > 1000 || new Set<string>(ids).size !== ids.length ||
      ids.some((id: string): boolean => this.uncertainHistoryIds.has(id) || !this.historyItems.some((item: PinmonyPhotoHistoryItem): boolean => item.id === id))) throw new Error('history-delete-unavailable');
    const revision: number = this.revision;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const page: string = this.page;
    const live = (): boolean => revision === this.revision && this.ports.active() && this.ports.session().authenticated &&
      this.ports.session().accountId === session.accountId && this.ports.session().generation === session.generation &&
      session.accountId === this.account && session.generation === this.epoch && this.ports.page() === page;
    if (!live()) throw new Error('history-delete-stale');
    this.historyWritePending = true;
    const job: string = 'native_photo_history_delete_' + (++this.sequence).toString();
    this.job = job;
    ids.forEach((id: string): void => { this.uncertainHistoryIds.add(id); });
    try {
      const bytes: ArrayBuffer = await this.ports.network().deletePhotoHistory(ids, page, this.ports.session, live, job);
      if (!live()) throw new Error('history-delete-stale');
      const response: PhotoHistoryDeleteReply = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes))) as PhotoHistoryDeleteReply;
      const resource: PhotoHistoryDeleteResource = response.resource_response;
      if (!resource || resource.status !== 'success' || resource.code !== 0 || resource.endpoint_name !== 'v3_delete_lens_histories' || resource.data !== null) throw new Error('history-delete-unconfirmed');
      this.historyItems = this.historyItems.filter((item: PinmonyPhotoHistoryItem): boolean => !ids.includes(item.id));
      ids.forEach((id: string): void => { this.uncertainHistoryIds.delete(id); });
    } finally { this.historyWritePending = false; if (this.job === job) this.job = ''; }
  }

  async selectHistory(id: string, onSelected: (uri: string) => void): Promise<PinmonySearchResult[] | undefined> {
    const item: PinmonyPhotoHistoryItem | undefined = this.historyItems.find((p: PinmonyPhotoHistoryItem): boolean => p.id === id);
    if (!item) return undefined;
    const revision: number = ++this.revision;
    const live = (): boolean => revision === this.revision && this.ports.active() && this.ports.session().authenticated &&
      this.ports.session().accountId === this.account && this.ports.session().generation === this.epoch && this.ports.page() === this.page;
    if (!live()) return undefined;
    // Present the selected photo before preparing upload bytes, as for the picker.
    this.bytes = undefined; this.readingBytes = undefined; this.uri = item.imageUrl; this.results = [];
    onSelected(item.imageUrl);
    if (!live()) return undefined;
    this.job = 'native_photo_history_' + (++this.sequence).toString();
    const data: ArrayBuffer = await this.ports.network().readPhotoHistory('', item.imageUrl, this.ports.session, live, this.job);
    if (!live()) return undefined;
    const bytes: ArrayBuffer = await this.ports.jpeg(data);
    if (!live()) return undefined;
    this.bytes = bytes; this.uri = item.imageUrl; this.results = [];
    this.job = 'native_photo_search_' + (++this.sequence).toString();
    const text: string = await this.ports.network().searchUploadedPhoto(bytes, this.page, this.ports.session, live, this.job);
    if (!live()) return undefined;
    this.results = parsePhotoSearch(text, this.ports.session().origin);
    return this.results.slice();
  }
}
