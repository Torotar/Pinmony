import { PinmonyScrollRecovery } from 'common_foundation';
import { PinmonyActionNotice, PinmonyListDataSource, PinmonyCdnImage, PinmonyVideoSource } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyVideoCard } from 'common_ui';
import { connection } from '@kit.NetworkKit';
import { allowsSpeculativeReads, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyHomeBoard, PinmonyHomePin, PinmonyHomeSnapshot, PinmonyHomeTab, PinmonyHomeImageRecovery } from '../models/PinmonyHome';
import { PinmonyHomeSkeleton } from './PinmonyHomeSkeleton';
import { PinmonyHomePaginationWindow } from '../services/PinmonyHomePaginationWindow';

interface PinmonyHomeFeedRow {
  pin?: PinmonyHomePin;
  key: string;
  footer: boolean;
}

@Component
export struct PinmonyHomeFeedPane {
  @StorageLink('pinmonyRecoveryScrollRevision') @Watch('applyRecoveredPosition') private recoveryScrollRevision: number = 0;
  private applyRecoveredPosition(): void {
    if (!this.paneActive) return;
    const offset: number | undefined = PinmonyScrollRecovery.offset('home', this.home.pageKey);
    if (offset !== undefined) { this.initialScrollOffset = offset; this.restoreDone = false; this.restoreAwaitingPinCount = -1; this.restoreScrollPosition(); }
  }

  private readonly feedRows: PinmonyListDataSource<PinmonyHomeFeedRow> = new PinmonyListDataSource<PinmonyHomeFeedRow>();
  private syncFeedRows(): void {
    const rows: PinmonyHomeFeedRow[] = (this.home.pins || []).map((pin: PinmonyHomePin): PinmonyHomeFeedRow => ({
      pin: pin, footer: false,
      key: this.home.pageKey + ':' + this.categoryId + ':' + pin.id + ':' + pin.imageUrl + ':' + pin.title + ':' + (pin.isVideo === true || !!pin.video) + ':' +
        (pin.video?.sources.map((source: PinmonyVideoSource): string => source.url).join('|') || '') + ':' + (pin.video?.duration || 0) + ':' +
        this.uiLanguage + ':' + (this.recoveredRevisions[pin.imageUrl] || 0)
    }));
    rows.push({ key: 'feed-footer', footer: true });
    rows.push({ key: 'feed-spacer', footer: false });
    this.feedRows.update(rows, rows.map((row: PinmonyHomeFeedRow): string => row.key));
  }
  @StorageLink('pinmonyRootScrollTop0') @Watch('onRootScrollTop') private rootScrollTop: number = 0;
  private onRootScrollTop(): void {
    if (!this.paneActive) return;
    try {
      const scroller: Scroller = this.feedScroller;
      const offset: number = scroller.offset()?.yOffset || 0;
      if (offset <= 1) {
        if (!(this.refreshing || this.loading) && this.onRefresh) this.onRefresh();
      } else {
        scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
      }
    } catch (_) {}
  }

  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private homeTopInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx); }
  @State private refreshGestureState: RefreshStatus = RefreshStatus.Inactive;
  private refreshStateTimer: number = -1;
  private refreshStateRevision: number = 0;

  private cancelRefreshStateUpdate(): void {
    this.refreshStateRevision++;
    if (this.refreshStateTimer !== -1) clearTimeout(this.refreshStateTimer);
    this.refreshStateTimer = -1;
  }

  private queueRefreshState(state: RefreshStatus): void {
    // Refresh can report its state while ArkUI is updating the component tree.
    // Commit on the next turn and retain only the latest event for this pane.
    this.cancelRefreshStateUpdate();
    if (!this.paneMounted) return;
    const revision: number = this.refreshStateRevision;
    const pageKey: string = this.home.pageKey;
    const session: number = this.home.session;
    const category: string = this.categoryId;
    this.refreshStateTimer = setTimeout((): void => {
      if (revision !== this.refreshStateRevision) return;
      this.refreshStateTimer = -1;
      if (!this.paneMounted || this.home.pageKey !== pageKey ||
        this.home.session !== session || this.categoryId !== category) return;
      if (this.refreshGestureState !== state) this.refreshGestureState = state;
    }, 0);
  }
  @StorageLink('pinmonyLanguage') @Watch('syncFeedRows') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  private uiFormat(source: string, values: (string | number)[]): string { return PinmonyI18n.format(source, values, this.uiLanguage); }
  @Prop @Watch('onImageRecovery') imageRecovery: PinmonyHomeImageRecovery | undefined = undefined;
  @State private recoveredSources: Record<string, string> = {};
  @State private recoveredRevisions: Record<string, number> = {};
  private lastImageRecovery: number = 0;
  private imageNetwork: connection.NetConnection | undefined = undefined;
  private imageNetworkOnline: boolean = true;
  private imageNetworkVisible: boolean = false;
  private imageRecoveryPending: boolean = false;
  private imageRecoveryAttempts: Set<string> = new Set<string>();

  private watchImageNetwork(): void {
    this.imageNetworkVisible = true;
    try {
      this.imageNetworkOnline = connection.hasDefaultNetSync();
      const monitor: connection.NetConnection = connection.createNetConnection();
      this.imageNetwork = monitor;
      monitor.on('netAvailable', (): void => {
        if (this.imageNetwork !== monitor || !this.imageNetworkVisible) return;
        const recovered: boolean = !this.imageNetworkOnline;
        this.imageNetworkOnline = true;
        if (recovered) {
          this.imageRecoveryAttempts.clear();
          this.imageRecoveryPending = true;
          this.retryRecoveredImages();
        }
      });
      monitor.on('netLost', (): void => {
        if (this.imageNetwork !== monitor || !this.imageNetworkVisible) return;
        try { this.imageNetworkOnline = connection.hasDefaultNetSync(); } catch (_) { return; }
        if (!this.imageNetworkOnline) this.imageRecoveryPending = false;
      });
      monitor.register((error): void => {
        if (error) PinmonyRuntimeLog.warn('HomeImageTrace: network-monitor unavailable');
      });
    } catch (_) { PinmonyRuntimeLog.warn('HomeImageTrace: network-monitor unavailable'); }
  }

  private retryRecoveredImages(): void {
    if (!this.imageNetworkVisible || !this.imageNetworkOnline || !this.imageRecoveryPending ||
      !this.feedActive || !this.actionsReady || this.offlinePreview || this.loading || this.refreshing ||
      this.synchronizing || this.visibleLast < this.visibleFirst) return;
    const pins: PinmonyHomePin[] = this.home.pins.slice(this.visibleFirst, this.visibleLast + 1);
    let count: number = 0;
    for (const pin of pins) {
      if (this.imageRecoveryAttempts.size >= 12) break;
      if (this.failedImages.indexOf(pin.imageUrl) < 0 || this.imageRecoveryAttempts.has(pin.imageUrl)) continue;
      this.imageRecoveryAttempts.add(pin.imageUrl);
      this.retryImage(pin.imageUrl, 'network-recovery');
      count++;
    }
    if (count > 0) PinmonyRuntimeLog.info('HomeImageTrace: phase=network-recovery count=' + count.toString());
  }
  private onImageRecovery(): void {
    const recovery: PinmonyHomeImageRecovery | undefined = this.imageRecovery;
    if (!recovery) { this.recoveredSources = {}; this.recoveredRevisions = {}; this.lastImageRecovery = 0; this.syncFeedRows(); return; }
    if (recovery.revision === this.lastImageRecovery || !this.home?.pins) return;
    const identity: string = recovery.pinUrl.match(/\/pin\/(\d+)\//)?.[1] || '';
    const pin: PinmonyHomePin | undefined = this.home.pins.find((item: PinmonyHomePin): boolean =>
      !!identity && item.pinUrl.match(/\/pin\/(\d+)\//)?.[1] === identity);
    if (!pin) return;
    if (this.failedImages.indexOf(pin.imageUrl) < 0) return;
    this.lastImageRecovery = recovery.revision;
    const sources: Record<string, string> = {};
    Object.keys(this.recoveredSources).forEach((key: string): void => { sources[key] = this.recoveredSources[key]; });
    sources[pin.imageUrl] = recovery.imageUrl; this.recoveredSources = sources;
    const revisions: Record<string, number> = {};
    Object.keys(this.recoveredRevisions).forEach((key: string): void => { revisions[key] = this.recoveredRevisions[key]; });
    revisions[pin.imageUrl] = (revisions[pin.imageUrl] || 0) + 1; this.recoveredRevisions = revisions;
    this.failedImages = this.failedImages.filter((url: string): boolean => url !== pin.imageUrl);
    this.syncFeedRows();
  }
  private retryImage(url: string, reason: string = 'manual-retry'): void {
    if (this.offlinePreview || this.failedImages.indexOf(url) < 0) return;
    const revisions: Record<string, number> = {};
    Object.keys(this.recoveredRevisions).forEach((key: string): void => { revisions[key] = this.recoveredRevisions[key]; });
    revisions[url] = (revisions[url] || 0) + 1;
    this.recoveredRevisions = revisions;
    this.syncFeedRows();
    this.failedImages = this.failedImages.filter((failed: string): boolean => failed !== url);
    PinmonyRuntimeLog.info('HomeImageTrace: phase=' + reason + ' revision=' + revisions[url].toString());
  }
  @Prop @Watch('onHomeChanged') home: PinmonyHomeSnapshot = {} as PinmonyHomeSnapshot;
  @Prop pendingTabId: string = '';
  @Prop mediaActive: boolean = false;
  @Prop imageLoadingActive: boolean = true;
  @Prop prefetchedImageUrls: string[] = [];
  @Prop @Watch('onPrefetchAvailabilityChanged') feedActive: boolean = false;
  @Prop @Watch('onPrefetchAvailabilityChanged') loading: boolean = false;
  @Prop synchronizing: boolean = false;
  @Prop offlinePreview: boolean = false;
  @Prop @Watch('onPrefetchAvailabilityChanged') refreshing: boolean = false;
  @Prop @Watch('onPrefetchAvailabilityChanged') paginationReady: boolean = true;
  @Prop @Watch('onPrefetchAvailabilityChanged') actionsReady: boolean = true;
  @Prop menuReady: boolean = true;
  @Prop navigationReady: boolean = true;
  @Prop interactionReady: boolean = true;
  @Prop initialScrollOffset: number = 0;
  @Prop menuLoadingId: string = '';
  @Prop error: string = '';
  @State @Watch('imageBudgetWidthChanged') private contentWidth: number = 360;
  private imageBudgetWidthChanged(): void { this.prefetchVisibleDetails(); }
  private cachedImageCount(): number { return Math.min(48, this.contentColumns() * 6); }
  private detailImagePrefetchCount(): number { return Math.min(18, this.contentColumns() * 3); }
  @State private failedImages: string[] = [];
  @State private homeChromeCollapsed: boolean = false;
  @Prop categoryId: string = '';
  @Prop presentationEpoch: number = 0;
  @Prop initialChromeCollapsed: boolean = false;
  @Prop chromeOpacity: number = 1;
  @Prop @Watch('onPaneActiveChanged') paneActive: boolean = false;
  @Prop suppressPinClick: boolean = false;
  onScrollerReady?: (scroller: Scroller | undefined, epoch: number) => void;
  onChromeChanged?: (collapsed: boolean) => void;
  private restoreDone: boolean = false;
  private restoreAttempts: number = 0;
  private restoreAwaitingPinCount: number = -1;
  private restoreTimer: number = -1;
  private paneMounted: boolean = false;
  private activeSession: number = 0;
  private activeTab: string = '';
  private activePageKey: string = '';

  private readonly feedScroller: Scroller = new Scroller();
  private lastReportedScrollOffset: number = 0;
  private lastMeasuredScrollOffset: number = 0;
  private lastChromeScrollOffset: number = 0;
  private chromeScrollDirection: number = 0;
  private chromeScrollDistance: number = 0;
  private restoringScroll: boolean = false;
  private visibleFirst: number = 0;
  private visibleLast: number = -1;
  private prefetchKey: string = '';
  private readonly paginationWindow: PinmonyHomePaginationWindow = new PinmonyHomePaginationWindow();
  private paginationWasActive: boolean = false;
  private pendingEnd: boolean = false;
  private viewportFillKey: string = '';
  private viewportHeight: number = 0;
  private readonly layoutTraceSizes: Map<string, string> = new Map<string, string>();
  private layoutTraceCount: number = 0;
  private traceLayout(node: string, area: Area): void {
    const top: number = Number(area.globalPosition.y);
    const height: number = Number(area.height);
    if (!Number.isFinite(top) || !Number.isFinite(height) || height <= 0) return;
    const geometry: string = ' top=' + top.toFixed(1) + ' height=' + height.toFixed(1) +
      ' bottom=' + (top + height).toFixed(1);
    if (this.layoutTraceCount >= 24 || this.layoutTraceSizes.get(node) === geometry) return;
    this.layoutTraceSizes.set(node, geometry);
    ++this.layoutTraceCount;
    PinmonyRuntimeLog.info('HomeLayoutTrace: node=' + node + geometry + ' componentSafeArea=false');
  }
  private prefetchNotBefore: number = 0;
  private prefetchTimer: number = -1;
  private detailPrefetchTimer: number = -1;
  private viewportFillTimer: number = -1;
  private lastHomePinCount: number = 0;
  private paginationTraceAt: number = 0;
  private paginationTraceKey: string = '';
  private imageTraceCount: number = 0;
  private imageTraceStartedAt: number = Date.now();
  @State private firstImageSettled: boolean = false;
  private firstImageSource: string = '';
  private syncFirstImagePriority(): void {
    const first: PinmonyHomePin | undefined = this.home.pins[0];
    const source: string = this.home.pageKey + ':' + this.home.selectedTab + ':' +
      (first ? first.id + ':' + first.imageUrl : '');
    if (source === this.firstImageSource) return;
    this.firstImageSource = source;
    this.firstImageSettled = false;
  }

  private settleFirstImage(pin: PinmonyHomePin): void {
    if (!this.paneMounted || this.firstImageSettled) return;
    const index: number = this.home.pins.findIndex((item: PinmonyHomePin): boolean =>
      item.id === pin.id && item.imageUrl === pin.imageUrl);
    if (index < this.visibleFirst || index > Math.max(this.visibleFirst, this.visibleLast)) return;
    // Both success and failure release speculative work; a failed card must
    // not leave pagination or retained detail preparation waiting forever.
    this.firstImageSettled = true;
    this.onPrefetchAvailabilityChanged();
  }

  private releaseUnobservableImagePriority(): void {
    if (!this.paneMounted || !this.paneActive || this.firstImageSettled || this.visibleLast < this.visibleFirst) return;
    const last: number = Math.min(this.visibleLast, this.home.pins.length - 1);
    if (last < this.visibleFirst) return;
    for (let index: number = this.visibleFirst; index <= last; index++) {
      const pin: PinmonyHomePin = this.home.pins[index];
      if (!pin.video && this.failedImages.indexOf(pin.imageUrl) < 0) return;
    }
    // Video posters and retained error cards have no image callback here.
    this.firstImageSettled = true;
    this.onPrefetchAvailabilityChanged();
  }
  private paginationTrace(reason: string): void {
    if (reason === 'speculative-disabled' && (!this.paneActive || this.home.pins.length === 0)) return;
    const key: string = reason + ':' + this.home.pins.length.toString() + ':' +
      this.visibleFirst.toString() + ':' + this.visibleLast.toString();
    if (key === this.paginationTraceKey) return;
    const now: number = Date.now();
    if (now - this.paginationTraceAt < 1000) return;
    this.paginationTraceAt = now;
    this.paginationTraceKey = key;
    PinmonyRuntimeLog.info('HomePaginationTrace: phase=ui reason=' + reason +
      ' count=' + this.home.pins.length + ' first=' + this.visibleFirst + ' last=' + this.visibleLast +
      ' remaining=' + Math.max(0, this.home.pins.length - this.visibleLast - 1).toString() +
      ' reserve=' + this.paginationWindow.reserve(this.visibleLast - this.visibleFirst + 1, 12, now).toString() +
      ' nearEndReserve=' + this.paginationWindow.reserve(this.visibleLast - this.visibleFirst + 1, 8, now).toString() +
      this.paginationWindow.diagnostic(now));
  }
  onTab?: (id: string) => void;
  onBoard?: (id: string) => void;
  onPrefetchMore?: () => void;
  onPin?: (id: string, imageUrl?: string) => void;
  onMore?: (id: string) => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onScrollPosition?: (pageKey: string, offset: number, epoch: number) => void;
  onVisiblePins?: (first: number, last: number) => void;
  onPrefetchPins?: (first: number, last: number, limit?: number) => void;

  aboutToAppear(): void {
    this.syncFirstImagePriority();
    this.syncFeedRows();
    this.paneMounted = true;
    if (this.paneActive) this.watchImageNetwork();
    this.homeChromeCollapsed = this.initialChromeCollapsed;
    this.notifyChromeChanged();
    this.activeSession = this.home.session;
    this.activeTab = this.home.selectedTab;
    this.activePageKey = this.home.pageKey;
    if (this.lastHomePinCount !== this.home.pins.length) PinmonyRuntimeLog.info('HomePaginationTrace: phase=ui-committed previous=' +
      this.lastHomePinCount + ' count=' + this.home.pins.length);
    this.lastHomePinCount = this.home.pins.length;
    this.restoringScroll = this.initialScrollOffset > 0;
    if (this.home.dataSource === 'api' && this.home.pins.length > 0) {
      // The first API snapshot can create this component directly, so there
      // may be no watched prop transition to arm the post-paint delay.
      this.prefetchNotBefore = Date.now() + 900;
    }
  }

  aboutToDisappear(): void {
    this.cancelRefreshStateUpdate();
    // The framework may already have detached the Scroller here. Persist the
    // last attached measurement rather than replacing the category offset with 0.
    if (this.restoreDone && this.onScrollPosition) {
      this.onScrollPosition(this.home.pageKey, this.lastMeasuredScrollOffset, this.presentationEpoch);
    }
    if (this.onScrollerReady) this.onScrollerReady(undefined, this.presentationEpoch);
    this.paneMounted = false;
    this.paginationWasActive = false;
    this.paginationWindow.pause();
    if (this.restoreTimer !== -1) clearTimeout(this.restoreTimer);
    if (this.prefetchTimer !== -1) clearTimeout(this.prefetchTimer);
    this.prefetchTimer = -1;
    if (this.detailPrefetchTimer !== -1) clearTimeout(this.detailPrefetchTimer);
    if (this.viewportFillTimer !== -1) clearTimeout(this.viewportFillTimer);
    this.detailPrefetchTimer = -1;
    this.viewportFillTimer = -1;
    this.imageNetworkVisible = false;
    this.imageRecoveryPending = false;
    const monitor: connection.NetConnection | undefined = this.imageNetwork;
    this.imageNetwork = undefined;
    if (monitor) {
      try { monitor.unregister((): void => {}); } catch (_) { }
    }
  }

  private notifyChromeChanged(): void {
    if (this.onChromeChanged) this.onChromeChanged(this.homeChromeCollapsed);
  }

  private setHomeChromeCollapsed(collapsed: boolean): void {
    if (this.homeChromeCollapsed === collapsed) return;
    this.homeChromeCollapsed = collapsed;
    this.notifyChromeChanged();
  }

  private onPaneActiveChanged(): void {
    if (!this.paneActive) this.reportScrollPosition(true);
    this.imageNetworkVisible = this.paneActive;
    if (this.paneActive) {
      if (!this.imageNetwork) this.watchImageNetwork();
      if (this.restoreDone && this.onScrollerReady) this.onScrollerReady(this.feedScroller, this.presentationEpoch);
      if (!this.restoreDone) {
        this.restoreAwaitingPinCount = -1;
        this.restoreScrollPosition();
      }
      this.notifyChromeChanged();
    }
    this.onPrefetchAvailabilityChanged();
  }

  // Restore only a newly mounted WaterFlow. Activation of a retained pane
  // must never seek its Scroller back to an initial or another category's offset.
  private restoreScrollPosition(): void {
    if (this.restoreDone || this.restoreTimer !== -1 || !this.paneMounted || !this.home.pins.length) return;
    if (this.restoreAwaitingPinCount === this.home.pins.length && !this.home.endReached && !this.home.sourceError) return;
    this.restoringScroll = true;
    const target: number = Math.max(0, this.initialScrollOffset);
    if (target <= 1) {
      let current: number = 0;
      try { current = Math.max(0, this.feedScroller.currentOffset().yOffset); } catch (_) { }
      if (current <= 1) {
        this.restoreDone = true;
        this.restoringScroll = false;
        this.lastChromeScrollOffset = current;
        if (this.onScrollerReady) this.onScrollerReady(this.feedScroller, this.presentationEpoch);
        return;
      }
    }
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1;
      if (!this.paneMounted) return;
      try {
        this.feedScroller.scrollTo({ xOffset: 0, yOffset: target, animation: false });
        this.lastChromeScrollOffset = target;
      } catch (_) { }
      this.restoreTimer = setTimeout((): void => {
        this.restoreTimer = -1;
        if (!this.paneMounted) return;
        let actual: number = 0;
        try { actual = Math.max(0, this.feedScroller.currentOffset().yOffset); } catch (_) { }
        if (Math.abs(actual - target) > 1 && ++this.restoreAttempts < 8) {
          this.restoreScrollPosition();
          return;
        }
        // An evicted category may initially have only its first network page.
        // Keep its saved target until the active feed has enough content;
        // use the existing guarded pagination path and never load inactive panes.
        if (actual < target - 1 && this.home.dataSource === 'api' && !this.offlinePreview &&
          !this.home.endReached && !this.home.sourceError) {
          this.restoreAwaitingPinCount = this.home.pins.length;
          this.restoreAttempts = 0;
          if (this.feedActive) this.loadNextPageAtEnd();
          return;
        }
        this.restoreDone = true;
        this.restoringScroll = false;
        this.lastChromeScrollOffset = actual;
        this.lastReportedScrollOffset = actual;
        this.lastMeasuredScrollOffset = actual;
        PinmonyRuntimeLog.info('HomeScrollTrace: phase=restored target=' + target.toFixed(1) + ' actual=' + actual.toFixed(1));
        if (this.onScrollerReady) this.onScrollerReady(this.feedScroller, this.presentationEpoch);
        this.notifyChromeChanged();
      }, 16);
    }, 0);
  }

  private reportScrollPosition(force: boolean = false): void {
    if (this.restoringScroll || !this.restoreDone) return;
    try {
      const position = this.feedScroller.offset();
      if (!position) return;
      const offset: number = Math.max(0, position.yOffset);
      this.lastMeasuredScrollOffset = offset;
      if (!force && Math.abs(offset - this.lastReportedScrollOffset) < 8) return;
      this.lastReportedScrollOffset = offset;
      if (this.onScrollPosition) this.onScrollPosition(this.home.pageKey, offset, this.presentationEpoch);
    } catch (error) {
      console.warn('Pinmony: home scroll position unavailable');
    }
  }

  private updateHomeChrome(offset: number, state: ScrollState): void {
    if (!this.feedActive || this.restoringScroll || !this.home.board || this.refreshing || this.home.refreshing) return;
    try {
      const position = this.feedScroller.offset();
      if (!position) return;
      if (position.yOffset <= 1) {
        this.chromeScrollDistance = 0;
        if (this.homeChromeCollapsed) {
          this.setHomeChromeCollapsed(false);
        }
        return;
      }
      // Match the search results: accumulate intentional scroll in one direction.
      if (state !== ScrollState.Scroll || !Number.isFinite(offset) || Math.abs(offset) < 0.1) return;
      if (this.chromeScrollDistance * offset < 0) this.chromeScrollDistance = 0;
      this.chromeScrollDistance += offset;
      if (Math.abs(this.chromeScrollDistance) < 20) return;
      const collapsed: boolean = this.chromeScrollDistance > 0;
      this.chromeScrollDistance = 0;
      if (collapsed === this.homeChromeCollapsed) return;
      this.setHomeChromeCollapsed(collapsed);
    } catch (_) { }
  }

  private onHomeChanged(): void {
    this.syncFirstImagePriority();
    if (this.lastHomePinCount > 0 && this.home.pins.length === 0) {
      this.reportScrollPosition(true);
      this.restoreDone = false;
      this.restoreAttempts = 0;
      this.restoreAwaitingPinCount = -1;
      this.restoringScroll = true;
      if (this.restoreTimer !== -1) clearTimeout(this.restoreTimer);
      this.restoreTimer = -1;
      if (this.onScrollerReady) this.onScrollerReady(undefined, this.presentationEpoch);
    }
    const firstApiSnapshot: boolean = this.home.dataSource === 'api' && this.lastHomePinCount === 0 &&
      this.home.pins.length > 0;
    if (this.activeSession !== this.home.session || this.activeTab !== this.home.selectedTab || this.activePageKey !== this.home.pageKey) {
      const sameFeed: boolean = this.activePageKey === this.home.pageKey && this.activeTab === this.home.selectedTab;
      this.activeSession = this.home.session;
      this.activeTab = this.home.selectedTab;
      this.activePageKey = this.home.pageKey;
      this.failedImages = [];
      // A new bridge session does not move the retained native viewport.
      // WaterFlow may not emit onScrollIndex when identical cards stay mounted.
      if (!sameFeed) {
        this.pendingEnd = false;
        this.viewportFillKey = '';
        this.setHomeChromeCollapsed(false);
        this.chromeScrollDistance = 0;
        this.recoveredSources = {}; this.recoveredRevisions = {}; this.lastImageRecovery = 0;
        this.visibleFirst = 0;
        this.visibleLast = -1;
      } else {
        this.visibleLast = Math.min(this.visibleLast, this.home.pins.length - 1);
        this.visibleFirst = Math.min(this.visibleFirst, Math.max(0, this.visibleLast));
      }
      this.prefetchKey = '';
      // Let the first card paint and the detail prefetch queue start before
      // asking the feed for another page.
      this.prefetchNotBefore = Date.now() + 900;
    }
    if (firstApiSnapshot) this.prefetchNotBefore = Date.now() + 900;
    this.lastHomePinCount = this.home.pins.length;
    if (!this.restoreDone) this.restoreScrollPosition();
    this.onImageRecovery();
    this.syncFeedRows();
    this.releaseUnobservableImagePriority();
    this.onPrefetchAvailabilityChanged();
    this.scheduleViewportFill();
  }

  private prefetchNextScreen(): void {
    if (!this.paneMounted || !this.paneActive || !this.feedActive) return;
    // Feed pagination runs alongside visible images. Only detail/image
    // prefetch waits for image settlement, never the next feed page.
    if (!allowsSpeculativeReads()) { this.paginationTrace('speculative-disabled'); return; }
    if (this.prefetchNotBefore > Date.now()) {
      if (this.prefetchTimer === -1) {
        const delay: number = Math.max(0, this.prefetchNotBefore - Date.now());
        this.prefetchTimer = setTimeout(() => {
          this.prefetchTimer = -1;
          this.prefetchNextScreen();
        }, delay);
      }
      return;
    }
    if (this.home.dataSource !== 'api' || !this.feedActive || !this.actionsReady || !this.paginationReady || this.loading || this.refreshing ||
        this.pendingTabId || this.home.loadingMore || this.home.refreshing || this.home.endReached ||
        this.home.sourceError || this.visibleLast < 0 || !this.onLoadMore) return;
    const count: number = this.home.pins.length;
    // Leave two screens for the network to finish, with a bounded lookahead.
    const reserve: number = this.paginationWindow.reserve(this.visibleLast - this.visibleFirst + 1, 12, Date.now());
    if (count - 1 - this.visibleLast > reserve) return;
    const key: string = this.home.session.toString() + ':' + this.home.selectedTab + ':' +
      count.toString() + ':' + (this.home.pins[0]?.id || '');
    if (key === this.prefetchKey) return;
    this.prefetchKey = key;
    this.paginationTrace('prefetch-dispatch');
    if (this.onPrefetchMore) this.onPrefetchMore();
    else this.onLoadMore();
  }

  private onPrefetchAvailabilityChanged(): void {
    const active: boolean = this.paneMounted && this.paneActive && this.feedActive;
    if (active !== this.paginationWasActive) {
      this.paginationWasActive = active;
      // A cancelled page must be eligible again when the retained pane returns.
      this.prefetchKey = ''; this.nearEndKey = ''; this.viewportFillKey = '';
      this.paginationWindow.pause();
      if (this.prefetchTimer !== -1) clearTimeout(this.prefetchTimer);
      this.prefetchTimer = -1;
    }
    if (!active) return;
    this.paginationWindow.observe(this.home.pageKey + ':' + this.home.session.toString() + ':' + this.home.selectedTab,
      this.home.pins.length, !!this.home.loadingMore, !!this.home.sourceError, Date.now());
    this.retryRecoveredImages();
    if (this.refreshing) this.viewportFillKey = '';
    setTimeout(() => { this.resumePendingEnd(); this.scheduleViewportFill(); this.scheduleDetailPrefetch(); this.prefetchNextScreen(); }, 0);
  }

  private fillShortViewport(): void {
    if (!this.paneMounted || !this.paneActive || this.viewportHeight <= 0 || this.offlinePreview || !this.feedActive || !this.paginationReady ||
      this.loading || this.refreshing || this.pendingTabId || this.home.loadingMore || this.home.refreshing ||
      this.home.endReached || !this.home.pins.length ||
      (this.error || this.home.sourceError) && !this.home.categorySourceFailure) return;
    try {
      if (!this.feedScroller.isAtEnd() || this.feedScroller.currentOffset().yOffset > 4) return;
      const key: string = this.home.pageKey + ':' + this.home.session.toString() + ':' + this.home.selectedTab + ':' +
        this.home.pins.length.toString() + ':' + (this.home.pins[0]?.id || '') + ':' + (this.home.pins[this.home.pins.length - 1]?.id || '');
      if (this.viewportFillKey === key) return;
      this.viewportFillKey = key;
      this.paginationTrace('short-viewport-fill');
      this.loadNextPageAtEnd();
    } catch (_) { }
  }

  private scheduleViewportFill(): void {
    if (!this.paneMounted || !this.paneActive || !this.feedActive) return;
    if (this.viewportFillTimer !== -1) return;
    this.viewportFillTimer = setTimeout((): void => {
      this.viewportFillTimer = -1;
      this.fillShortViewport();
    }, 80);
  }

  private scheduleDetailPrefetch(): void {
    if (!this.paneMounted || !this.paneActive || !this.feedActive) return;
    if (this.detailPrefetchTimer !== -1) return;
    this.detailPrefetchTimer = setTimeout((): void => {
      this.detailPrefetchTimer = -1;
      this.prefetchVisibleDetails();
    }, 80);
  }

  private resumePendingEnd(): void {
    if (!this.paneMounted || !this.paneActive || !this.pendingEnd || !this.feedActive || !this.paginationReady || this.loading || this.refreshing ||
        this.pendingTabId || this.home.loadingMore || this.home.refreshing) return;
    this.pendingEnd = false;
    try { if (this.feedScroller.isAtEnd()) this.loadNextPageAtEnd(); } catch (_) {}
  }

  private nearEndKey: string = '';
  private loadNearEnd(): void {
    if (!this.paneMounted || !this.paneActive || !this.restoreDone || this.restoringScroll || this.visibleFirst < 0 || this.visibleLast < 0 ||
        !this.feedActive || !this.paginationReady || this.loading || this.refreshing || this.pendingTabId ||
        this.home.loadingMore || this.home.refreshing) return;
    const reserve: number = this.paginationWindow.reserve(this.visibleLast - this.visibleFirst + 1, 8, Date.now());
    if (this.home.pins.length - this.visibleLast - 1 > reserve) return;
    if (this.home.dataSource !== 'api' || this.home.endReached ||
        (this.home.sourceError || this.error) && !this.home.categorySourceFailure) return;
    const key: string = this.home.pageKey + ':' + this.home.session.toString() + ':' + this.home.selectedTab + ':' +
      this.home.pins.length.toString() + ':' + (this.home.pins[0]?.id || '');
    if (this.nearEndKey === key) return;
    this.nearEndKey = key;
    this.loadNextPageAtEnd();
  }

  private loadNextPageAtEnd(): void {
    if (!this.paneMounted || !this.paneActive) return;
    this.paginationTrace(this.home.loadingMore ? 'end-busy' : !this.paginationReady ? 'end-session-pending' :
      this.home.endReached ? 'end-finished' : this.home.sourceError && !this.home.categorySourceFailure ? 'end-error' :
      !this.feedActive || this.loading || this.refreshing || !!this.pendingTabId ? 'end-inactive' : 'end-dispatch');
    if (this.home.dataSource !== 'api' || this.home.endReached ||
        (this.home.sourceError || this.error) && !this.home.categorySourceFailure) { this.pendingEnd = false; return; }
    if (this.home.loadingMore) { this.pendingEnd = true; return; }
    if (!this.feedActive || !this.paginationReady || this.loading || this.refreshing ||
        this.pendingTabId || this.home.loadingMore || this.home.refreshing) { this.pendingEnd = true; return; }
    this.pendingEnd = false;
    if (this.onLoadMore) this.onLoadMore();
  }

  private prefetchVisibleDetails(): void {
    if (!this.paneMounted || !this.paneActive) return;
    if (!this.firstImageSettled) return;
    if (!allowsSpeculativeReads()) return;
    if (!this.feedActive || !this.actionsReady || this.loading || this.refreshing || this.pendingTabId ||
      this.home.refreshing || this.visibleLast < 0 || !this.onPrefetchPins) return;
    this.onPrefetchPins(this.visibleFirst, this.visibleLast, this.detailImagePrefetchCount());
  }

  private emptyFeedMessage(): string {
    if (this.offlinePreview) return this.uiText("pm_you_are_offline_this_category_has_no_cached_images_connect_and_r_a67bd3fa");
    if (this.error) return PinmonyI18n.render(this.error, this.uiLanguage);
    if (this.home.kind === 'loading') return this.uiText("pm_loading_interrupted_please_retry_6fe00867");
    return this.uiText("pm_no_pins_in_this_category_yet_3202c6eb");
  }

  private contentColumns(): number {
    return Math.max(2, Math.floor((this.contentWidth - 24 + 12) / 192));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.contentColumns(); i++) slots.push(i);
    return slots;
  }

  private contentColumnsTemplate(): string {
    return this.columnSlots().map((): string => '1fr').join(' ');
  }

  private imageHeight(pin: PinmonyHomePin): number {
    const width: number = Math.max(130, (this.contentWidth - 24 - (this.contentColumns() - 1) * 12) / this.contentColumns());
    if (pin.imageWidth <= 0 || pin.imageHeight <= 0) return width * 1.2;
    return width * Math.max(0.55, Math.min(3.2, pin.imageHeight / pin.imageWidth));
  }

  private canShowFeed(): boolean {
    return this.home.pins.length > 0;
  }

  @Builder
  private feedStatus() {
    if (this.offlinePreview || this.error || this.loading || (this.synchronizing && this.home.pins.length === 0)) {
      Column({ space: 8 }) {
        if (!this.offlinePreview) {
          Row({ space: 8 }) {
            if (!this.error) {
              LoadingProgress().width(18).height(18).color($r('app.color.accent'))
            }
            if (!this.error) { Text(this.feedStatusText())
              .fontSize(13)
              .fontColor($r('app.color.secondary_text'))
              .maxLines(2)
              .layoutWeight(1) }
            if (this.error) {
              PinmonyActionNotice({ active: this.interactionReady, message: this.feedStatusText(), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
            }
          }
          .width('100%')
        }
        if (this.offlinePreview) {
          Row({ space: 8 }) {
            PinmonyActionNotice({ active: this.interactionReady, message: this.uiText("pm_offline_showing_recent_cache_5bff694a"), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          }
          .width('100%')
          .accessibilityText(this.uiText("pm_offline_showing_recent_cache_you_can_retry_236c20a9"))
        }
      }
      .width('calc(100% - 24vp)')
      .padding(10)
      .backgroundColor($r('app.color.input_surface'))
      .borderRadius(12)
      .margin({ top: 8 })
      .accessibilityText(this.feedStatusText())
    }
  }

  private feedStatusText(): string {
    if (this.offlinePreview) return this.uiText("pm_offline_showing_recent_cache_5bff694a");
    if (this.error) return PinmonyI18n.render(this.error, this.uiLanguage) +
      (this.home.categorySourceFailure ? '' : this.uiText("pm_showing_previous_content_f821f683"));
    if (this.refreshing || this.home.refreshing) return this.uiText("pm_refreshing_home_feed_eeb8a65d");
    if (this.loading) return this.uiText("pm_loading_home_feed_1d83a335");
    return this.uiText("pm_reconnecting_home_feed_58971515");
  }

  @Builder
  private boardSummary(board: PinmonyHomeBoard) {
    Row({ space: 12 }) {
      if (board.thumbnailUrl) {
        Image(board.thumbnailUrl)
          .width(48)
          .height(48)
          .objectFit(ImageFit.Cover)
          .borderRadius(24)
          .clip(true)
          .accessibilityLevel('no')
      } else {
        Blank()
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor($r('app.color.surface_muted'))
          .accessibilityLevel('no')
      }
      Column({ space: 4 }) {
        Text(PinmonyI18n.render(board.name, this.uiLanguage))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.uiFormat("pm_value_pins_d1922567", [board.pinCount]))
          .fontSize(13)
          .fontColor($r('app.color.secondary_text'))
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .enabled(this.interactionReady && !!board.boardUrl && !!this.onBoard)
    .onClick(() => { if (!this.suppressPinClick && this.onBoard) this.onBoard(board.id); })
    .accessibilityText(this.uiFormat("pm_open_board_value_value_pins_134006a7", [board.name, board.pinCount]))
  }

  @Builder
  private pinCard(pin: PinmonyHomePin, imageRevision: number = 0, session: number = 0, pageKey: string = '') {
    Column({ space: 8 }) {
      if (pin.video) {
        PinmonyVideoCard({ video: pin.video, poster: pin.imageUrl, active: this.mediaActive && this.actionsReady,
          loadingActive: this.imageLoadingActive && this.paneActive })
          .width('100%').height(this.imageHeight(pin))
          .id(this.paneActive ? 'pinmony-home-photo-' + pin.id : 'pinmony-home-photo-' + this.categoryId + '-' + pin.id)
          .onClick(() => { if (!this.suppressPinClick && this.onPin) this.onPin(pin.id); })
      } else if (this.failedImages.indexOf(pin.imageUrl) >= 0) {
        Column() {
          Text(this.uiText("pm_image_failed_to_load_572993f5"))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
          if (!this.offlinePreview) {
            PinmonyActionNotice({ active: this.interactionReady, message: this.uiText("pm_retry_b8784c8d"), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.retryImage(pin.imageUrl) })
          }
        }
        .width('100%')
        .height(this.imageHeight(pin))
        .borderRadius(18)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
        .accessibilityText((pin.title || this.uiText("pm_pin_234ff540")) + this.uiText("pm_image_failed_to_load_open_details_8406e8c5"))
        .onClick(() => { if (!this.suppressPinClick && this.onPin) this.onPin(pin.id); })
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          PinmonyCdnImage({ url: this.recoveredSources[pin.imageUrl] || pin.imageUrl, fit: ImageFit.Cover,
            traceLoading: true, traceIndex: this.home.pins.findIndex((item: PinmonyHomePin): boolean => item.id === pin.id),
            // Match search results: mounted WaterFlow cache items may load offscreen.
            loadingActive: this.imageLoadingActive && this.paneActive, useSharedDecode: false, viewportOnly: false,
            onDecoded: () => {
              if (session !== this.home.session || pageKey !== this.home.pageKey ||
                imageRevision !== (this.recoveredRevisions[pin.imageUrl] || 0)) return;
              this.settleFirstImage(pin);
              if (this.imageTraceCount++ < 40) PinmonyRuntimeLog.info('HomeImageTrace: phase=complete index=' +
                this.home.pins.findIndex((item: PinmonyHomePin): boolean => item.id === pin.id) +
                ' sincePageMs=' + (Date.now() - this.imageTraceStartedAt));
            },
            onFailure: (code: number) => {
              if (session !== this.home.session || pageKey !== this.home.pageKey) return;
              if (imageRevision !== (this.recoveredRevisions[pin.imageUrl] || 0)) return;
              this.settleFirstImage(pin);
              if (this.failedImages.indexOf(pin.imageUrl) < 0) {
                PinmonyRuntimeLog.warn('HomeImageError: revision=' + imageRevision.toString() +
                  ' index=' + this.home.pins.findIndex((item: PinmonyHomePin): boolean => item.id === pin.id) +
                  ' code=' + code.toString());
                this.failedImages = [...this.failedImages, pin.imageUrl];
                this.onImageRecovery();
                this.retryRecoveredImages();
              }
            } })
            .width('100%').height(this.imageHeight(pin)).borderRadius(18).clip(true)
            .accessibilityLevel('no')
            .onClick(() => { if (!this.suppressPinClick && this.onPin) this.onPin(pin.id, this.recoveredSources[pin.imageUrl] || pin.imageUrl); })
          if (pin.isVideo === true) {
            Text(this.uiText('pm_videos_c20f7618')).fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor('#111111').padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('#EFFFFFFF').borderRadius(7).margin({ left: 5, top: 5 })
              .hitTestBehavior(HitTestMode.None)
          }
          if (pin.saved === true) {
            Column() {
              Text(this.uiText("pm_saved_471dd4d7")).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .padding({ left: 14, right: 14, top: 16 })
              Blank()
            }.width('100%').height(this.imageHeight(pin)).backgroundColor('#55000000')
              .borderRadius(18).clip(true).hitTestBehavior(HitTestMode.None)
          }
        }.width('100%').height(this.imageHeight(pin)).borderRadius(18).clip(true)
          .id(this.paneActive ? 'pinmony-home-photo-' + pin.id : 'pinmony-home-photo-' + this.categoryId + '-' + pin.id)
      }
      Row({ space: 4 }) {
        if (pin.title.trim().length > 0) {
          Text(PinmonyI18n.render(pin.title, this.uiLanguage))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .onClick(() => { if (!this.suppressPinClick && this.onPin) this.onPin(pin.id, this.recoveredSources[pin.imageUrl] || pin.imageUrl); })
        } else {
          Blank()
        }
        Button({ type: ButtonType.Circle }) {
          if (this.menuLoadingId === pin.id) {
            LoadingProgress().color($r('app.color.accent')).width(20).height(20)
          } else {
            Image($r('app.media.lucide_ellipsis'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
          }
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .enabled(this.interactionReady && this.menuReady && !this.menuLoadingId)
        .onClick(() => {
          if (!this.suppressPinClick && this.onMore) this.onMore(pin.id);
        })
        .accessibilityText(this.uiText("pm_more_options_c611656f"))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .enabled(this.navigationReady)
    .accessibilityText(pin.title || this.uiText("pm_open_pin_e0bdd278"))
  }

  private uniquePrefetchImages(): string[] {
    if (!this.firstImageSettled || !this.paneActive || !this.feedActive || !this.imageLoadingActive ||
      this.loading || this.refreshing || this.home.refreshing || !!this.pendingTabId) return [];
    const cardSources: Set<string> = new Set<string>();
    this.home.pins.forEach((pin: PinmonyHomePin): void => {
      cardSources.add(this.recoveredSources[pin.imageUrl] || pin.imageUrl);
    });
    const seen: Set<string> = new Set<string>();
    return this.prefetchedImageUrls.slice(0, this.detailImagePrefetchCount()).filter((url: string): boolean => {
      if (!url || seen.has(url) || cardSources.has(url)) return false;
      seen.add(url);
      return true;
    });
  }

  private canPullRefresh(): boolean {
    return this.paneActive && this.feedActive && this.interactionReady && !this.offlinePreview &&
      !this.loading && !this.refreshing && !this.home.refreshing && !this.pendingTabId;
  }

  private showRefreshIndicator(): boolean {
    return this.paneActive && (this.refreshing || !!this.home.refreshing ||
      this.canPullRefresh() && this.refreshGestureState === RefreshStatus.OverDrag);
  }

  private requestPullRefresh(): void {
    if (this.canPullRefresh() && this.onRefresh) this.onRefresh();
  }

  @Builder
  private homeRefreshIndicator() {
    Column() {
      LoadingProgress().width(24).height(24)
      .color($r('app.color.accent'))
      .visibility(this.showRefreshIndicator() ? Visibility.Visible : Visibility.Hidden)
    }.width('100%').height(64).justifyContent(FlexAlign.Center)
      .offset({ y: this.homeTopInset() + 48 + (this.home.board ? 68 : 0) })
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private feedContent() {
    Column() {
      if (this.feedActive) {
        // Share detail-sized decodes with the eventual hero and entry motion.
        // This zero-height container has no input or accessibility semantics.
        Row() {
          ForEach(this.uniquePrefetchImages(), (url: string) => {
            // Use the same native Image cache path as visible cards, as in the
            // earlier home feed. Detail/hero shared decoding remains unchanged.
            PinmonyCdnImage({ url: url, useSharedDecode: false, viewportOnly: false,
              loadingActive: this.imageLoadingActive && this.paneActive })
              .width(1).height(1).opacity(0).accessibilityLevel('no')
          }, (url: string) => url)
        }.height(0).clip(true).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }

      if (!this.canShowFeed()) {
        if (!this.offlinePreview && (this.loading || this.synchronizing) && !this.error) {
          PinmonyHomeSkeleton({ showCategories: this.home.tabs.length === 0 })
            .padding({ top: this.homeTopInset() + 48 })
            .width('100%')
            .layoutWeight(1)
        } else {
          Column({ space: 12 }) {
            PinmonyActionNotice({ active: this.interactionReady, message: this.emptyFeedMessage(),
              actionText: this.offlinePreview ? this.uiText("pm_connect_and_retry_a25c5d3e") : this.uiText("pm_reload_df7392cc"),
              onAction: () => { if (this.onRetry) this.onRetry(); } })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 24, right: 24, top: this.homeTopInset() + 48, bottom: 100 })
        }
      } else {
        Stack({ alignContent: Alignment.Top }) {
          Refresh({ refreshing: this.refreshing, builder: this.homeRefreshIndicator }) {
            WaterFlow({ scroller: this.feedScroller }) {
              LazyForEach(this.feedRows, (row: PinmonyHomeFeedRow) => {
                FlowItem() {
                  if (row.pin) {
                    this.pinCard(row.pin, this.recoveredRevisions[row.pin.imageUrl] || 0, this.home.session, this.home.pageKey)
                  } else if (row.footer) {
                Column({ space: 8 }) {
                  if (this.home.dataSource === 'api') {
                    if (this.home.loadingMore) {
                      LoadingProgress().color($r('app.color.accent')).width(24).height(24)
                    } else if (this.home.sourceError) {
                      PinmonyActionNotice({ active: this.interactionReady, message: this.uiText("pm_retry_loading_8924c788"), actionText: this.uiText("pm_retry_loading_8924c788"), onAction: () => { if (this.onLoadMore) this.onLoadMore(); } })
                    } else if (this.home.endReached) {
                      Text(this.uiText("pm_no_more_pins_dda147ad"))
                        .fontSize(12)
                        .fontColor($r('app.color.secondary_text'))
                    }
                  }
                }
                .height(100)
                  } else {
                Column()
                  .height(100)
                  .accessibilityLevel('no')
                  }
                }
                .width('100%')
              }
              , (row: PinmonyHomeFeedRow): string => row.key)
            }
            .columnsTemplate(this.contentColumnsTemplate())
            .columnsGap(12)
            .rowsGap(12)
            .width('100%')
            .height('100%')
            .padding({ left: 12, right: 12, top: this.homeTopInset() + (this.home.board ? 132 : 64) })
            .clipContent(ContentClipMode.BOUNDARY)
            .cachedCount(this.cachedImageCount(), true)
            .edgeEffect(EdgeEffect.None)
            .clip(false)
            .scrollBar(BarState.Off)
            .onAppear(() => this.restoreScrollPosition())
            .onDidScroll((offset: number, state: ScrollState) => {
              if (!this.paneActive) return;
              if (state === ScrollState.Scroll && this.restoreAwaitingPinCount >= 0) {
                // A deliberate vertical gesture takes over from restoration.
                if (this.restoreTimer !== -1) clearTimeout(this.restoreTimer);
                this.restoreTimer = -1;
                this.restoreAwaitingPinCount = -1;
                this.restoreDone = true;
                this.restoringScroll = false;
                if (this.onScrollerReady) this.onScrollerReady(this.feedScroller, this.presentationEpoch);
              }
              this.updateHomeChrome(offset, state);
              this.reportScrollPosition();
              if (this.onContentScroll) this.onContentScroll(offset, state);
            })
            .onScrollIndex((first: number, last: number) => {
              this.visibleFirst = Math.max(0, first);
              this.visibleLast = Math.min(last, this.home.pins.length - 1);
              this.releaseUnobservableImagePriority();
              if (this.paneActive && this.feedActive) this.paginationWindow.viewport(this.visibleLast, Date.now());
              if (this.onVisiblePins) this.onVisiblePins(first, last);
              this.retryRecoveredImages();
              this.scheduleDetailPrefetch();
              this.loadNearEnd();
              this.prefetchNextScreen();
              this.scheduleViewportFill();
            })
            .onScrollStop(() => {
              if (!this.paneActive) return;
              this.updateHomeChrome(0, ScrollState.Idle);
              this.reportScrollPosition(true);
              try { if (this.feedScroller.isAtEnd()) this.loadNextPageAtEnd(); } catch (_) { }
            })
            .onReachEnd(() => {
              this.loadNextPageAtEnd();
            })
            .onAreaChange((_oldArea: Area, newArea: Area) => {
              this.traceLayout('waterflow', newArea);
              this.viewportHeight = Number(newArea.height);
              this.restoreScrollPosition();
              this.scheduleViewportFill();
              const width: number = Number(newArea.width);
              if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
            })
          }
          .width('100%')
          .height('100%')
          .clip(false)
          .pullToRefresh(this.canPullRefresh())
          .onRefreshing(() => this.requestPullRefresh())
          .onStateChange((state: RefreshStatus) => { this.queueRefreshState(state); })
          this.feedStatus()
        }
        .width('100%')
        .layoutWeight(1)
        .clip(false)
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
    .onAreaChange((_oldArea: Area, area: Area) => this.traceLayout('feed', area))
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.feedContent()
      if (this.home.board && this.canShowFeed()) {
        Column() {
          Column() { this.boardSummary(this.home.board) }
            .width('100%').height(68)
            .flexShrink(0)
            .opacity(this.chromeOpacity)
        }
          .width('100%').height(68 * this.chromeOpacity)
          .position({ x: 0, y: this.homeTopInset() + 48 })
          .backgroundColor($r('app.color.page_background'))
          .clip(true)
          .hitTestBehavior(this.homeChromeCollapsed ? HitTestMode.None : HitTestMode.Default)
          .accessibilityLevel(this.homeChromeCollapsed ? 'no-hide-descendants' : 'auto')
      }
    }.width('100%').height('100%').clip(true)
  }
}
