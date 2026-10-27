import { PinmonyI18n } from 'common_foundation';
import { PIN_NATIVE_DETAIL_READS_ENABLED } from './PinmonyDetailNativeReads';
import { mapPrefetchedDetail, readRelatedPresentation, RelatedPresentation } from 'feature_pin';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyDetailTrace, PinmonyDetailReadCache } from 'feature_pin';
import { PinmonyHomeStore } from 'feature_home';
import { PinmonyNativeNetwork, PinmonyNetworkContext, PinmonyNetworkJob, PinmonyNetworkReply, PIN_NATIVE_NETWORK_ENABLED } from 'common_network';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyAuthStatus, PinmonyBusinessSessionContext } from 'common_session';
import { allowsSpeculativeReads } from 'common_foundation';
import { PinmonyDetailSnapshot } from 'feature_pin';
import { PinmonyDetailPrefetch } from 'feature_pin';
import { PIN_DETAIL_API_ENABLED } from 'feature_pin';
import { PinmonyHomePin, PinmonyHomeSnapshot } from 'feature_home';
interface PinmonyDetailReadData { options: PinmonyDetailReadOptions; }
interface PinmonyDetailReadOptions { id: string; field_set_key: string; }
export interface PinmonyDetailOpeningCoordinatorPorts {
  activeSheetKind: () => string;
  activeTab: () => number;
  authStatus: () => PinmonyAuthStatus;
  coordinatorTasks: () => PinmonyTaskRegistry;
  currentHomePageKey: () => string;
  detailJourney: () => PinmonyDetailTrace;
  detailOpenedAt: () => number;
  detailPrefetchTimer: () => number;
  setDetailPrefetchTimer: (value: number) => number;
  detailReadCache: () => PinmonyDetailReadCache;
  detailReadNetwork: () => PinmonyNativeNetwork;
  detailRequestOwners: () => Map<string, number>;
  homeStore: () => PinmonyHomeStore;
  nativeBackTarget: () => string;
  nativeNetworkContext: () => PinmonyNetworkContext;
  nativeBusinessSessionContext: () => PinmonyBusinessSessionContext;
  startNativeReads: (pin: string, token: number, body: string) => Promise<PinmonyNetworkReply>;
  openingRelated: () => Promise<PinmonyNetworkReply> | undefined;
  setOpeningRelated: (value: Promise<PinmonyNetworkReply> | undefined) => Promise<PinmonyNetworkReply> | undefined;
  openingRelatedToken: () => number;
  setOpeningRelatedToken: (value: number) => number;
  pageTasks: () => PinmonyTaskRegistry;
  pinIdentity: (value: string) => string;
  pinStore: () => PinmonyPinStore;
}
export class PinmonyDetailOpeningCoordinator {
  private shufflePreviewScope: string = '';
  private readonly shufflePrefetch: PinmonyDetailPrefetch = new PinmonyDetailPrefetch('detail_prefetch_shuffle_');
  pauseShufflePreviews(): void { this.shufflePrefetch.clear(); }
  prefetchShufflePins(urls: string[], scope: string, visible: () => boolean,
    ready: (detail: PinmonyDetailSnapshot) => void): void {
    const captured: PinmonyBusinessSessionContext = this.ports.nativeBusinessSessionContext();
    const nextScope: string = scope + captured.origin + captured.accountId + captured.generation.toString();
    if (nextScope !== this.shufflePreviewScope) { this.shufflePrefetch.clear(); this.shufflePreviewScope = nextScope; }
    const current = (): boolean => {
      const now: PinmonyBusinessSessionContext = this.ports.nativeBusinessSessionContext();
      return captured.authenticated && now.authenticated && now.generation === captured.generation &&
        now.accountId === captured.accountId && this.pinStore.videoForeground && visible();
    };
    this.shufflePrefetch.onReady = (detail: PinmonyDetailSnapshot): void => { if (current()) ready(detail); };
    urls.forEach((url: string) => {
      const cached: PinmonyDetailSnapshot | undefined = this.shufflePrefetch.get(url);
      if (cached && current()) ready(cached);
    });
    this.shufflePrefetch.offer(urls, scope + ':' + captured.generation.toString(),
      async (url: string, id: string, ownerCurrent: () => boolean): Promise<string> => {
        if (!ownerCurrent()) throw new Error('stale-shuffle-preview');
        const pinId: string = (JSON.parse(decodeURIComponent(url.match(/[?&]data=([^&]+)/)![1])) as PinmonyDetailReadData).options.id;
        const pin: string = captured.origin + '/pin/' + pinId + '/';
        const job: PinmonyNetworkJob = {id:id,epoch:captured.generation,page:pin,url:url,method:'GET',body:'',
          headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/pin/[id].js'}};
        const reply: PinmonyNetworkReply = await this.ports.detailReadNetwork().requestBusinessPinRead(job,
          (): PinmonyBusinessSessionContext => this.ports.nativeBusinessSessionContext(), pin, ownerCurrent,
          (): PinmonyNetworkContext => this.ports.nativeNetworkContext());
        if (!ownerCurrent() || reply.error || reply.status !== 200) throw new Error('shuffle-preview-unavailable');
        return reply.body;
      }, current, (id: string) => this.ports.detailReadNetwork().cancel(id));
  }
  private readonly homeStore: PinmonyHomeStore;
  private readonly pinStore: PinmonyPinStore;
  private readonly ports: PinmonyDetailOpeningCoordinatorPorts;
  constructor(ports: PinmonyDetailOpeningCoordinatorPorts) { this.ports = ports; this.homeStore = ports.homeStore(); this.pinStore = ports.pinStore(); }
startOpeningDetailRead(pinUrl: string, token: number): void {
    this.ports.setOpeningRelated(undefined);
    this.ports.setOpeningRelatedToken(token);
    this.ports.detailJourney().mark('base.request.or.takeover');
    const captured: PinmonyBusinessSessionContext = this.ports.nativeBusinessSessionContext();
    const current = (): boolean => captured.authenticated && this.ports.nativeBusinessSessionContext().generation === captured.generation && this.ports.authStatus() === 'authenticated' && this.pinStore.videoForeground &&
        token === this.pinStore.detailOpeningToken && (this.pinStore.detailOpeningPin === pinUrl || this.pinStore.detailPin === pinUrl) && !this.ports.nativeBackTarget();
    this.ports.coordinatorTasks().timeout(() => {
        if (current() && !this.pinStore.detailActionsReady && !this.pinStore.detailNativeReadsReady)
            this.pinStore.detailApiError = PinmonyI18n.message("pm_pin_loading_timed_out_please_retry_b940342e");
    }, 12000);
    this.pinStore.detailPrefetch.open(pinUrl, async (url: string, id: string, ownerCurrent: () => boolean): Promise<string> => {
        this.ports.detailRequestOwners().set(id, this.ports.detailJourney().current());
        const job: PinmonyNetworkJob = { id: id, epoch: captured.generation, page: pinUrl, url: url,
            method: 'GET', body: '', headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
                'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
        const reply: PinmonyNetworkReply = await this.ports.detailReadNetwork().requestBusinessPinRead(job, (): PinmonyBusinessSessionContext => this.ports.nativeBusinessSessionContext(), pinUrl, ownerCurrent, (): PinmonyNetworkContext => this.ports.nativeNetworkContext());
        this.ports.detailRequestOwners().delete(id);
        if (!ownerCurrent() || reply.error || reply.status !== 200) {
            const failure: Error = new Error(reply.error === 'network-unavailable' ? 'network-unavailable' : 'detail-unavailable');
            if (reply.error === 'cancelled' || reply.error === 'stale' || !ownerCurrent()) failure.name = 'AbortError';
            throw failure;
        }
        return reply.body;
    }, current, (id: string) => this.ports.detailReadNetwork().cancel(id)).then((body: string) => {
        if (!current()) return;
        const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detailPrefetch.get(pinUrl) || (PIN_NATIVE_DETAIL_READS_ENABLED ? mapPrefetchedDetail(body,pinUrl,true) : undefined);
        if (detail && !this.pinStore.detailActionsReady && this.pinStore.detail?.kind !== 'cached') {
            this.pinStore.detailPin = pinUrl;
            this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.ports.pinIdentity(pinUrl), detail);
        }
        this.pinStore.detailApiError = '';
        this.ports.detailJourney().mark('base.validated');
        if (PIN_NATIVE_DETAIL_READS_ENABLED) {
            this.ports.setOpeningRelated(this.ports.startNativeReads(pinUrl, token, body).catch((): PinmonyNetworkReply => {
                return { id: '', epoch: captured.generation, page: pinUrl, status: 0, body: '', url: '', error: 'cancelled', headers: {} };
            }));
            return;
        }
        if (this.pinStore.detailActionsReady) return;
        const context: PinmonyBusinessSessionContext = this.ports.nativeBusinessSessionContext();
        const id: string = this.ports.pinIdentity(pinUrl);
        const options: string = JSON.stringify({ pin_id: id, page_size: 12, context_pin_ids: [],
            homefeed_source_sig: false, search_query: '', source: 'feed_home', top_level_source: 'feed_home',
            top_level_source_depth: 1, is_pdp: false, additional_fields: ['pin.gen_ai_topics'] });
        const url: string = context.origin + '/resource/RelatedModulesResource/get/?source_url=' +
            encodeURIComponent('/pin/' + id + '/') + '&data=' + encodeURIComponent('{"options":' + options + ',"context":{}}');
        const job: PinmonyNetworkJob = { id: 'opening_related_' + token.toString(), epoch: captured.generation,
            page: pinUrl, url: url, method: 'GET', body: '', headers: { 'Accept': 'application/json',
                'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
        this.ports.detailJourney().mark('related.opening.request');
        const retainedRelated: PinmonyNetworkReply | undefined = this.ports.detailReadCache().retained(job);
        this.ports.setOpeningRelated(retainedRelated ? Promise.resolve(retainedRelated) : this.ports.detailReadNetwork().requestBusinessPinRead(job, (): PinmonyBusinessSessionContext => this.ports.nativeBusinessSessionContext(), pinUrl, (): boolean => this.ports.authStatus() === 'authenticated' && this.pinStore.videoForeground &&
            token === this.pinStore.detailOpeningToken && !this.ports.nativeBackTarget() &&
            this.ports.pinIdentity(this.pinStore.detailPin) === id, (): PinmonyNetworkContext => this.ports.nativeNetworkContext()).then((reply: PinmonyNetworkReply): PinmonyNetworkReply => {
            if (token !== this.pinStore.detailOpeningToken || this.ports.authStatus() !== 'authenticated' || this.ports.nativeBackTarget() ||
                this.pinStore.detailPresentationOnly || this.pinStore.detailActionsReady || this.pinStore.detailPin !== pinUrl || reply.error || reply.status !== 200)
                return reply;
            const related: RelatedPresentation | undefined = readRelatedPresentation(reply.body, pinUrl);
            const base: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
            if (related && base) {
                this.pinStore.detailCache.put(id, base, this.pinStore.detailScrollOffset);
                const presentation: PinmonyDetailSnapshot | undefined = this.pinStore.detailCache.get(id)?.detail;
                if (presentation) {
                    presentation.related = related.pins;
                    presentation.relatedEnded = related.ended;
                    presentation.relatedLoading = false;
                    presentation.relatedRetained = true;
                    this.pinStore.detail = presentation;
                    this.ports.detailJourney().mark('related.native.presentation');
                }
            }
            return reply;
        }));
        PinmonyRuntimeLog.info('DetailTrace: base ready openId=' + token.toString() + ' elapsedMs=' + (Date.now() - this.ports.detailOpenedAt()).toString());
    }).catch((error: Error) => {
        if (error.name === 'AbortError') {
            if (current()) this.ports.detailJourney().mark('base.cancelled.await-document');
            return;
        }
        if (current())
            this.ports.detailJourney().mark('base.failed');
        if (current())
            this.pinStore.detailApiError = error.message === 'network-unavailable' ?
                PinmonyI18n.message("pm_connection_failed_pin_could_not_load_please_retry_3ed4ae9b") : PinmonyI18n.message("pm_unable_to_load_pin_please_retry_252ec41d");
    });
}

prefetchHomePinDetails(first: number, last: number): void {
    if (!allowsSpeculativeReads())
        return;
    // Prefetch remains gated by !this.pinStore.detailOpeningPin; an opening detail has priority.
    if (this.pinStore.detailOpeningPin)
        return;
    if (this.ports.detailPrefetchTimer() !== -1)
        return;
    this.ports.setDetailPrefetchTimer(this.ports.pageTasks().timeout(() => {
        this.ports.setDetailPrefetchTimer(-1);
        this.prefetchHomePinDetailsNow(first, last);
    }, 700));
}

prefetchHomePinDetailsNow(first: number, last: number): void {
    if (!allowsSpeculativeReads())
        return;
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    const captured: PinmonyNetworkContext = this.ports.nativeNetworkContext();
    if (!PIN_DETAIL_API_ENABLED || !PIN_NATIVE_NETWORK_ENABLED || !home || !captured.authenticated ||
        this.ports.activeTab() !== 0 || !this.pinStore.videoForeground || this.ports.activeSheetKind() || this.pinStore.detail || this.pinStore.detailOpeningPin ||
        !this.homeStore.homeActionsReady || this.homeStore.homeLoading || this.homeStore.homeRefreshing ||
        this.homeStore.pendingHomeTab || home.pageKey !== this.ports.currentHomePageKey())
        return;
    const session: number = home.session;
    const tab: string = home.selectedTab;
    const current = (): boolean => {
        const now: PinmonyNetworkContext = this.ports.nativeNetworkContext();
        return now.authenticated && now.epoch === captured.epoch && now.page === captured.page &&
            this.ports.activeTab() === 0 && this.pinStore.videoForeground && !this.ports.activeSheetKind() && !this.pinStore.detail && !this.pinStore.detailOpeningPin &&
            this.homeStore.homeActionsReady && !this.homeStore.homeLoading && !this.homeStore.homeRefreshing &&
            !this.homeStore.pendingHomeTab && this.homeStore.home?.session === session && this.homeStore.home?.selectedTab === tab;
    };
    const urls: string[] = home.pins.slice(Math.max(0, first), Math.min(home.pins.length, first + 6, last + 1))
        .map((pin: PinmonyHomePin): string => pin.pinUrl);
    this.pinStore.detailPrefetch.onReady = (_detail: PinmonyDetailSnapshot) => {
        if (!current())
            return;
        this.pinStore.prefetchedImageUrls = urls.map((url: string): string => this.pinStore.detailPrefetch.get(url)?.imageUrl || '').filter((url: string): boolean => !!url);
    };
    this.pinStore.prefetchedImageUrls = urls.map((url: string): string => this.pinStore.detailPrefetch.get(url)?.imageUrl || '').filter((url: string): boolean => !!url);
    this.pinStore.detailPrefetch.offer(urls, captured.epoch.toString() + ':' + captured.page + ':' + session.toString() + ':' + tab, async (url: string, id: string, ownerCurrent: () => boolean): Promise<string> => {
        if (!ownerCurrent())
            throw new Error('stale-prefetch');
        const job: PinmonyNetworkJob = { id: id, epoch: captured.epoch, page: captured.page, url: url,
            method: 'GET', body: '', headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
                'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
        const pinId: string = (JSON.parse(decodeURIComponent(url.match(/[?&]data=([^&]+)/)![1])) as PinmonyDetailReadData).options.id;
        const reply: PinmonyNetworkReply = await this.ports.detailReadNetwork().requestPinRead(job, (): PinmonyNetworkContext => this.ports.nativeNetworkContext(), captured.page.slice(0, captured.page.indexOf('/', 8)) + '/pin/' + pinId + '/', ownerCurrent);
        if (!ownerCurrent() || reply.error || reply.status !== 200)
            throw new Error('prefetch-unavailable');
        return reply.body;
    }, current, (id: string) => this.ports.detailReadNetwork().cancel(id));
}
}
