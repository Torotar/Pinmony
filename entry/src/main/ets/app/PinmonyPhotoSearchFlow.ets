import { PinmonyNativeNetwork } from 'common_network';
import { PinmonyImageCrop } from 'common_ui';
import { PinmonyBusinessSessionContext } from 'common_session';
import { parsePhotoSearch, PinmonySearchResult } from 'feature_search';
interface PhotoPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  page: () => string;
  active: () => boolean;
  pick: () => Promise<string>;
  read: (uri: string) => Promise<ArrayBuffer>;
  open: (url: string, source: string) => void;
}
export class PinmonyPhotoSearchFlow {
  private revision: number = 0;
  private job: string = '';
  private results: PinmonySearchResult[] = [];
  private page: string = '';
  private account: string = '';
  private epoch: number = -1;
  private uri: string = '';
  private readonly ports: PhotoPorts;
  constructor(ports: PhotoPorts) { this.ports = ports; }
  cancel(): void {
    this.revision++;
    if (this.job) this.ports.network().cancel(this.job);
    this.job = ''; this.results = [];
    this.uri = '';
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
    const bytes: ArrayBuffer = await this.ports.read(uri);
    if (!current()) return undefined;
    this.job = 'native_photo_search_' + Date.now().toString();
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
    const bytes: ArrayBuffer = await this.ports.read(uri);
    if (!current()) return undefined;
    this.job = 'native_photo_search_' + Date.now().toString();
    const text: string = await this.ports.network().searchUploadedPhoto(bytes, this.page, this.ports.session, current, this.job,
      { x: crop.x, y: crop.y, w: crop.w, h: crop.h });
    if (!current()) return undefined;
    this.results = parsePhotoSearch(text, session.origin);
    return this.results.slice();
  }
  open(id: string): void {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const item: PinmonySearchResult | undefined = this.results.find((p: PinmonySearchResult): boolean => p.id === id);
    if (!item || !this.ports.active() || !session.authenticated || session.accountId !== this.account ||
      session.generation !== this.epoch || this.ports.page() !== this.page) return;
    this.ports.open(item.targetUrl, this.page);
  }
}
