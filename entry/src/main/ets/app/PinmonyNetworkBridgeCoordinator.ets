import { PinmonyPinStore, PinmonyDetailTrace, PinmonyDetailReadCache } from 'feature_pin';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyNativeNetwork, PinmonyNetworkContext, PinmonyNetworkJob, PinmonyNetworkReply, PIN_NATIVE_NETWORK_ENABLED, acceptsNetworkJob, NetworkManager } from 'common_network';
import { webview } from '@kit.ArkWeb';
import { PinmonyNavigationHistory } from '../app/PinmonyNavigationHistory';

interface PinmonyDetailReadData { options: PinmonyDetailReadOptions; }
interface PinmonyDetailReadOptions { id: string; field_set_key: string; }

export interface PinmonyNetworkBridgeCoordinatorPorts {
  nativeNetworkContext: () => PinmonyNetworkContext;
  controller: () => webview.WebviewController;
  businessSuspended: () => boolean;
  setBusinessSuspended: (value: boolean) => void;
  extractPinUrl: (value: string) => string;
  pinStore: () => PinmonyPinStore;
  nativeBackTarget: () => string;
  setNativeBackTarget: (value: string) => void;
  pageHistory: () => PinmonyNavigationHistory;
  detailReturnedToRoot: () => boolean;
  nativeRootOnly: () => boolean;
  pinIdentity: (value: string) => string;
  detailReadCache: () => PinmonyDetailReadCache;
  detailJourney: () => PinmonyDetailTrace;
  detailRequestOwners: () => Map<string, number>;
  showNetworkNotice: (message?: string) => void;
  clearNetworkNotice: () => void;
  nativeNetwork: () => PinmonyNativeNetwork;
  openingRelated: () => Promise<PinmonyNetworkReply> | undefined;
  setOpeningRelated: (value: Promise<PinmonyNetworkReply> | undefined) => void;
  openingRelatedToken: () => number;
  sharedDetailRequestId: () => string;
  setSharedDetailRequestId: (value: string) => void;
  currentPinUrl: () => string;
  detailReadNetwork: () => PinmonyNativeNetwork;
}

export class PinmonyNetworkBridgeCoordinator {
  private readonly ports: PinmonyNetworkBridgeCoordinatorPorts;
  constructor(ports: PinmonyNetworkBridgeCoordinatorPorts) { this.ports = ports; }

  private get nativeNetworkContext(): () => PinmonyNetworkContext { return this.ports.nativeNetworkContext; }
  private get controller(): webview.WebviewController { return this.ports.controller(); }
  private get businessSuspended(): boolean { return this.ports.businessSuspended(); }
  private set businessSuspended(value: boolean) { this.ports.setBusinessSuspended(value); }
  private get extractPinUrl(): (value: string) => string { return this.ports.extractPinUrl; }
  private get pinStore(): PinmonyPinStore { return this.ports.pinStore(); }
  private get nativeBackTarget(): string { return this.ports.nativeBackTarget(); }
  private set nativeBackTarget(value: string) { this.ports.setNativeBackTarget(value); }
  private get pageHistory(): PinmonyNavigationHistory { return this.ports.pageHistory(); }
  private get detailReturnedToRoot(): boolean { return this.ports.detailReturnedToRoot(); }
  private get nativeRootOnly(): boolean { return this.ports.nativeRootOnly(); }
  private get pinIdentity(): (value: string) => string { return this.ports.pinIdentity; }
  private get detailReadCache(): PinmonyDetailReadCache { return this.ports.detailReadCache(); }
  private get detailJourney(): PinmonyDetailTrace { return this.ports.detailJourney(); }
  private get detailRequestOwners(): Map<string, number> { return this.ports.detailRequestOwners(); }
  private get showNetworkNotice(): (message?: string) => void { return this.ports.showNetworkNotice; }
  private get clearNetworkNotice(): () => void { return this.ports.clearNetworkNotice; }
  private get nativeNetwork(): PinmonyNativeNetwork { return this.ports.nativeNetwork(); }
  private get openingRelated(): Promise<PinmonyNetworkReply> | undefined { return this.ports.openingRelated(); }
  private set openingRelated(value: Promise<PinmonyNetworkReply> | undefined) { this.ports.setOpeningRelated(value); }
  private get openingRelatedToken(): number { return this.ports.openingRelatedToken(); }
  private get sharedDetailRequestId(): string { return this.ports.sharedDetailRequestId(); }
  private set sharedDetailRequestId(value: string) { this.ports.setSharedDetailRequestId(value); }
  private get currentPinUrl(): () => string { return this.ports.currentPinUrl; }
  private get detailReadNetwork(): PinmonyNativeNetwork { return this.ports.detailReadNetwork(); }

  bindNativeNetwork(): void {
    const context: PinmonyNetworkContext = this.nativeNetworkContext();
    if (!context.authenticated) return;
    try { this.controller.onActive(); } catch (_) { PinmonyRuntimeLog.warn('WebActivity: update unavailable'); }
    try { this.controller.runJavaScript('window.PinmonyNetwork && window.PinmonyNetwork.setForeground(' + (!this.businessSuspended).toString() + ');' +
      'window.PinmonyNetwork && window.PinmonyNetwork.bind(' +
      context.epoch.toString() + ',' + JSON.stringify(context.page) + ');' +
      'window.PinmonyHomeDemand && window.PinmonyHomeDemand(' + JSON.stringify(context.page) + ');' +
      ['Profile', 'Search', 'Inbox', 'Detail', 'Board'].map((kind: string): string => 'window.Pinmony' + kind + 'Demand && window.Pinmony' + kind + 'Demand(' + JSON.stringify(context.page) + ');').join('') +
      'window.PinmonyNetwork ? "transport-present" : "transport-missing"')
      .then((state: string) => {
        if (state.includes('transport-missing')) PinmonyRuntimeLog.warn('NetworkTrace: transport initialization missing');
        else if (state.includes('transport-present')) PinmonyRuntimeLog.info('NetworkTrace: transport binding applied');
      })
      .catch(() => PinmonyRuntimeLog.warn('Pinmony: native transport binding unavailable'));
    } catch (_) { PinmonyRuntimeLog.warn('Pinmony: native transport binding unavailable'); }
  }

  requestNativeNetwork(value: string): void {
    if (!PIN_NATIVE_NETWORK_ENABLED || typeof value !== 'string' || value.length > 36 * 1024 * 1024) return;
    let job: PinmonyNetworkJob;
    try { job = JSON.parse(value) as PinmonyNetworkJob; if (!job || typeof job.id !== 'string') return; }
    catch (_) { return; }
    const traced: RegExpMatchArray | null = job.url.match(/\/resource\/(PinResource|UnifiedCommentsPreviewResource|RelatedModulesResource)\/get\//);
    if (traced && traced[1] !== 'PinResource' && this.extractPinUrl(job.page) &&
        (this.pinStore.detailPresentationOnly || this.nativeBackTarget || this.pageHistory.isPending() || this.detailReturnedToRoot || this.nativeRootOnly ||
         !this.pinStore.detail || this.pinIdentity(job.page) !== this.pinIdentity(this.pinStore.detailPin))) {
      // Native intent supersedes the old document before ArkWeb navigation
      // finishes. Reject late preview/recommendation jobs without RCP dispatch.
      const reply: PinmonyNetworkReply = { id: job.id, epoch: job.epoch, page: job.page,
        url: job.url, status: 0, body: '', headers: {}, error: 'cancelled' };
      this.controller.runJavaScript('window.PinmonyNetwork && window.PinmonyNetwork.complete(' + JSON.stringify(reply) + ')')
        .catch(() => {});
      PinmonyRuntimeLog.info('DetailTrace: departed document read rejected');
      return;
    }
    if (job.method !== 'GET' && !/\/resource\/[^/]+\/get\//.test(job.url)) this.detailReadCache.clear();
    const journey: number = this.detailJourney.current();
    const requestAt: number = Date.now();
    if (traced && journey && job.page === this.pinStore.detailPin) {
      this.detailRequestOwners.set(job.id, journey);
      this.detailJourney.mark(traced[1] + '.request', false);
    }
    this.detailNetworkReply(job)
      .then((reply: PinmonyNetworkReply) => {
        this.detailRequestOwners.delete(job.id);
        if (traced && journey && journey === this.detailJourney.current() && job.page === this.pinStore.detailPin) {
          this.detailJourney.mark(traced[1] + '.response=' + (reply.error ? 'failed' : reply.status.toString()), false, Date.now() - requestAt);
        }
        const cancelled: boolean = reply.error === 'cancelled' || reply.error === 'stale' ||
          reply.error === 'current=false';
        if (!cancelled && reply.error !== 'rate-limited' && (reply.status === 0 || !!reply.error)) this.showNetworkNotice();
        else if (!reply.error && NetworkManager.requestRemainingMs() === 0 &&
          /\/resource\/UserHomefeedResource\/get\//.test(job.url)) this.clearNetworkNotice();
        const context: PinmonyNetworkContext = this.nativeNetworkContext();
        if (context.epoch !== reply.epoch || context.page !== reply.page || !context.authenticated) return;
        if (reply.status === 200 && !reply.error && job.method === 'GET' && reply.body.length < 1000000 &&
            /\/resource\/(RelatedModulesResource|UnifiedCommentsPreviewResource)\/get\//.test(job.url)) {
          this.detailReadCache.store(job, reply);
        }
        const deliveryAt: number = Date.now();
        const boardRead: boolean = /\/resource\/(BoardResource|BoardFeedResource)\/get\//.test(job.url);
        if (boardRead) PinmonyRuntimeLog.info('BoardReadTrace: phase=bridge-start responseMs=' + (deliveryAt - requestAt).toString());
        this.controller.runJavaScript('window.PinmonyNetwork && window.PinmonyNetwork.complete(' + JSON.stringify(reply) + ')')
          .then((state: string) => {
            if (boardRead) PinmonyRuntimeLog.info('BoardReadTrace: phase=bridge-finish elapsedMs=' + (Date.now() - deliveryAt).toString());
            if (traced && journey && journey === this.detailJourney.current() && state.includes('delivered'))
              this.detailJourney.mark(traced[1] + '.bridge.delivered', false, Date.now() - requestAt);
            if (/^(?:"?)(delivered|no-job|stale)(?:"?)$/.test(state))
              PinmonyRuntimeLog.info('NativeNetwork: bridge delivery ' + state);
          })
          .catch(() => {
            this.showNetworkNotice();
            PinmonyRuntimeLog.warn('Pinmony: native response delivery unavailable');
          });
      }).catch(() => {
        this.showNetworkNotice();
        PinmonyRuntimeLog.warn('Pinmony: native transport unavailable');
      });
  }

  async detailNetworkReply(job: PinmonyNetworkJob): Promise<PinmonyNetworkReply> {
    if (!acceptsNetworkJob(job, this.nativeNetworkContext()))
      return this.nativeNetwork.request(job, (): PinmonyNetworkContext => this.nativeNetworkContext());
    const pin: string = this.pinStore.detailOpeningPin || this.pinStore.detailPin;
    const retained: PinmonyNetworkReply | undefined = this.detailReadCache.retained(job);
    if (retained) return retained;
    if (job.method === 'GET' && /\/resource\/RelatedModulesResource\/get\//.test(job.url) &&
        this.openingRelated && this.openingRelatedToken === this.pinStore.detailOpeningToken) {
      const encodedRelated: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      try {
      if (encodedRelated) {
        const data: Record<string, Object> = JSON.parse(decodeURIComponent(encodedRelated[1])) as Record<string, Object>;
        const options: Record<string, Object> = data['options'] as Record<string, Object>;
        if (options['pin_id'] === this.pinIdentity(pin) && !options['bookmarks']) {
          const pending: Promise<PinmonyNetworkReply> = this.openingRelated;
          this.openingRelated = undefined;
          const token: number = this.pinStore.detailOpeningToken;
          const reply: PinmonyNetworkReply = await pending;
          const actual: PinmonyNetworkContext = this.nativeNetworkContext();
          const valid: boolean = actual.authenticated && actual.epoch === job.epoch && actual.page === job.page &&
            token === this.pinStore.detailOpeningToken && !this.nativeBackTarget;
          return { id: job.id, epoch: job.epoch, page: job.page, url: job.url, headers: reply.headers,
            status: valid ? reply.status : 0, body: valid ? reply.body : '', error: valid ? reply.error : 'cancelled' };
        }
      }
      } catch (_) {}
    }
    let shared: Promise<string> | undefined = undefined;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const options: PinmonyDetailReadOptions = encoded ?
        (JSON.parse(decodeURIComponent(encoded[1])) as PinmonyDetailReadData).options : {} as PinmonyDetailReadOptions;
      if (job.method === 'GET' && /^https:\/\/(?:www|uk)\.pinterest\.com\/resource\/PinResource\/get\/\?/.test(job.url) &&
          options.id === this.pinIdentity(pin) && options.field_set_key === 'auth_web_main_pin')
        shared = this.pinStore.detailPrefetch.consume(pin);
    } catch (_) {}
    if (!shared) return this.nativeNetwork.request(job, (): PinmonyNetworkContext => this.nativeNetworkContext());
    const token: number = this.pinStore.detailOpeningToken;
    this.sharedDetailRequestId = job.id;
    let body: string = '', error: string = '';
    try { body = await shared; } catch (_) { error = 'network-unavailable'; }
    if (this.sharedDetailRequestId === job.id) this.sharedDetailRequestId = '';
    const actual: PinmonyNetworkContext = this.nativeNetworkContext();
    if (!actual.authenticated || actual.epoch !== job.epoch || actual.page !== job.page ||
        token !== this.pinStore.detailOpeningToken || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) {
      body = ''; error = 'cancelled';
    }
    PinmonyRuntimeLog.info('DetailTrace: demand reply ' + (error ? 'unavailable' : 'delivered'));
    return { id: job.id, epoch: job.epoch, page: job.page, status: error ? 0 : 200,
      body: body, url: job.url, error: error, headers: { 'content-type': 'application/json' } };
  }

  cancelNativeNetwork(id: string): void {
    this.nativeNetwork.cancel(id);
    if (id === this.sharedDetailRequestId) {
      this.pinStore.detailPrefetch.pause(); this.detailReadNetwork.invalidate(); this.openingRelated = undefined; this.sharedDetailRequestId = '';
    }
  }
}
