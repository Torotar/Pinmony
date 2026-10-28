import { PinmonyActionNotice } from 'common_ui';
import { BlurStrategy, HdsNavigation, HdsNavigationTitleBarOptions, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyImmersiveLight, PinmonyVideoCard } from 'common_ui';
import { connection } from '@kit.NetworkKit';
import { allowsSpeculativeReads, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyHomeBoard, PinmonyHomePin, PinmonyHomeSnapshot, PinmonyHomeTab, PinmonyHomeImageRecovery } from '../models/PinmonyHome';
import { PinmonyHomeSkeleton } from './PinmonyHomeSkeleton';

@Component
export struct PinmonyHomePage {
  @StorageLink('pinmonyRootScrollTop0') @Watch('onRootScrollTop') private rootScrollTop: number = 0;
  private onRootScrollTop(): void {
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
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
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
    if (!recovery) { this.recoveredSources = {}; this.recoveredRevisions = {}; this.lastImageRecovery = 0; return; }
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
  }
  private retryImage(url: string, reason: string = 'manual-retry'): void {
    if (this.offlinePreview || this.failedImages.indexOf(url) < 0) return;
    const revisions: Record<string, number> = {};
    Object.keys(this.recoveredRevisions).forEach((key: string): void => { revisions[key] = this.recoveredRevisions[key]; });
    revisions[url] = (revisions[url] || 0) + 1;
    this.recoveredRevisions = revisions;
    this.failedImages = this.failedImages.filter((failed: string): boolean => failed !== url);
    PinmonyRuntimeLog.info('HomeImageTrace: phase=' + reason + ' revision=' + revisions[url].toString());
  }
  @Prop @Watch('onHomeChanged') home: PinmonyHomeSnapshot = {} as PinmonyHomeSnapshot;
  @Prop @Watch('onPendingTabChanged') pendingTabId: string = '';
  @Prop mediaActive: boolean = false;
  @Prop prefetchedImageUrls: string[] = [];
  @Prop @Watch('onPrefetchAvailabilityChanged') feedActive: boolean = false;
  @Prop @Watch('onPrefetchAvailabilityChanged') loading: boolean = false;
  @Prop synchronizing: boolean = false;
  @Prop @Watch('onOfflinePreviewChanged') offlinePreview: boolean = false;
  @State private offlineCategoryId: string = '';
  @Prop @Watch('onPrefetchAvailabilityChanged') refreshing: boolean = false;
  @Prop @Watch('onPrefetchAvailabilityChanged') paginationReady: boolean = true;
  @Prop @Watch('onPrefetchAvailabilityChanged') actionsReady: boolean = true;
  @Prop menuReady: boolean = true;
  @Prop navigationReady: boolean = true;
  @Prop interactionReady: boolean = true;
  @Prop initialScrollOffset: number = 0;
  @Prop menuLoadingId: string = '';
  @Prop error: string = '';
  @State private contentWidth: number = 360;
  @State private failedImages: string[] = [];
  @State private categories: PinmonyHomeTab[] = [];
  @State private categoryDirection: number = 1;
  @State private homeChromeCollapsed: boolean = false;
  private activeSession: number = 0;
  private activeTab: string = '';
  private activePageKey: string = '';

  private readonly feedScroller: Scroller = new Scroller();
  private lastReportedScrollOffset: number = 0;
  private lastChromeScrollOffset: number = 0;
  private chromeScrollDirection: number = 0;
  private chromeScrollDistance: number = 0;
  private restoringScroll: boolean = false;
  private visibleFirst: number = 0;
  private visibleLast: number = -1;
  private prefetchKey: string = '';
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
  private lastHomePinCount: number = 0;
  private paginationTraceAt: number = 0;
  private imageTraceCount: number = 0;
  private imageTraceStartedAt: number = Date.now();
  private paginationTrace(reason: string): void {
    const now: number = Date.now();
    if (now - this.paginationTraceAt < 1000) return;
    this.paginationTraceAt = now;
    PinmonyRuntimeLog.info('HomePaginationTrace: phase=ui reason=' + reason +
      ' count=' + this.home.pins.length + ' first=' + this.visibleFirst + ' last=' + this.visibleLast);
  }
  onTab?: (id: string) => void;
  onBoard?: (id: string) => void;
  onPrefetchMore?: () => void;
  onPin?: (id: string) => void;
  onMore?: (id: string) => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onScrollPosition?: (pageKey: string, offset: number) => void;
  onVisiblePins?: (first: number, last: number) => void;
  onPrefetchPins?: (first: number, last: number) => void;

  aboutToAppear(): void {
    this.watchImageNetwork();
    this.updateCategories();
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
    this.imageNetworkVisible = false;
    this.imageRecoveryPending = false;
    const monitor: connection.NetConnection | undefined = this.imageNetwork;
    this.imageNetwork = undefined;
    if (monitor) {
      try { monitor.unregister((): void => {}); } catch (_) { }
    }
  }

  private restoreScrollPosition(): void {
    const offset: number = Math.max(0, this.initialScrollOffset);
    if (!offset) return;
    setTimeout(() => {
      try {
        this.feedScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
        this.lastChromeScrollOffset = offset;
        this.homeChromeCollapsed = false;
        this.chromeScrollDirection = 0;
        this.chromeScrollDistance = 0;
      } catch (error) {
        console.warn('Pinmony: home scroll restoration unavailable');
      }
      this.restoringScroll = false;
    }, 0);
  }

  private reportScrollPosition(force: boolean = false): void {
    if (this.restoringScroll) return;
    try {
      const position = this.feedScroller.offset();
      if (!position) return;
      const offset: number = Math.max(0, position.yOffset);
      if (!force && Math.abs(offset - this.lastReportedScrollOffset) < 8) return;
      this.lastReportedScrollOffset = offset;
      if (this.onScrollPosition) this.onScrollPosition(this.home.pageKey, offset);
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
          this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
            this.homeChromeCollapsed = false;
          });
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
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.homeChromeCollapsed = collapsed;
      });
    } catch (_) { }
  }

  private onHomeChanged(): void {
    const firstApiSnapshot: boolean = this.home.dataSource === 'api' && this.lastHomePinCount === 0 &&
      this.home.pins.length > 0;
    this.updateCategories();
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
        this.homeChromeCollapsed = false;
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
    this.onImageRecovery();
    setTimeout(() => { this.resumePendingEnd(); this.fillShortViewport(); this.prefetchVisibleDetails(); this.prefetchNextScreen(); }, 0);
  }

  private prefetchNextScreen(): void {
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
    if (this.home.dataSource !== 'api' || !this.feedActive || !this.actionsReady || this.loading || this.refreshing ||
        this.pendingTabId || this.home.loadingMore || this.home.refreshing || this.home.endReached ||
        this.home.sourceError || this.visibleLast < 0 || !this.onLoadMore) return;
    const count: number = this.home.pins.length;
    // Leave two screens for the network to finish, with a bounded lookahead.
    const reserve: number = Math.min(36, Math.max(12, (this.visibleLast - this.visibleFirst + 1) * 2));
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
    this.retryRecoveredImages();
    if (this.refreshing) this.viewportFillKey = '';
    setTimeout(() => { this.resumePendingEnd(); this.prefetchVisibleDetails(); this.prefetchNextScreen(); }, 0);
  }

  private fillShortViewport(): void {
    if (this.viewportHeight <= 0 || this.offlinePreview || !this.feedActive || !this.paginationReady ||
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

  private resumePendingEnd(): void {
    if (!this.pendingEnd || !this.feedActive || !this.paginationReady || this.loading || this.refreshing ||
        this.pendingTabId || this.home.loadingMore || this.home.refreshing) return;
    this.pendingEnd = false;
    try { if (this.feedScroller.isAtEnd()) this.loadNextPageAtEnd(); } catch (_) {}
  }

  private loadNextPageAtEnd(): void {
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
    if (!allowsSpeculativeReads()) return;
    if (!this.feedActive || !this.actionsReady || this.loading || this.refreshing || this.pendingTabId ||
      this.home.refreshing || this.visibleLast < 0 || !this.onPrefetchPins) return;
    this.onPrefetchPins(this.visibleFirst, this.visibleLast);
  }

  private onPendingTabChanged(): void {
    this.updateCategories();
  }

  private onOfflinePreviewChanged(): void {
    this.offlineCategoryId = '';
    this.updateCategories();
  }

  private emptyFeedMessage(): string {
    if (this.offlinePreview) return this.uiText("pm_you_are_offline_this_category_has_no_cached_images_connect_and_r_a67bd3fa");
    if (this.error) return PinmonyI18n.render(this.error, this.uiLanguage);
    if (this.home.kind === 'loading') return this.uiText("pm_loading_interrupted_please_retry_6fe00867");
    return this.uiText("pm_no_pins_in_this_category_yet_3202c6eb");
  }

  private updateCategories(): void {
    const next: PinmonyHomeTab[] = (this.home.tabs || []).map((tab: PinmonyHomeTab): PinmonyHomeTab => {
      return { id: tab.id, label: tab.label, enabled: tab.enabled,
        selected: this.offlinePreview && this.offlineCategoryId ? tab.id === this.offlineCategoryId :
          this.pendingTabId ? tab.id === this.pendingTabId : tab.selected };
    });
    this.applyCategories(next);
  }

  private applyCategories(next: PinmonyHomeTab[]): void {
    const previous: number = this.categories.findIndex((tab: PinmonyHomeTab): boolean => tab.selected);
    const selected: number = next.findIndex((tab: PinmonyHomeTab): boolean => tab.selected);
    const previousId: string = this.categories[previous]?.id || '';
    const nextId: string = next[selected]?.id || '';
    // Initial load and same-category data/language refresh do not move the page.
    // Compare positions in the same list; a refreshed list is not navigation.
    const target: number = this.categories.findIndex((tab: PinmonyHomeTab): boolean => tab.id === nextId);
    if (!previousId || !nextId || previousId === nextId || target < 0) { this.categories = next; return; }
    // Update the mounted page's exit effect before animateTo replaces its key.
    this.categoryDirection = target > previous ? 1 : -1;
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseOut }, () => {
      this.categories = next;
    });
  }

  private categoryPageKey(): string {
    return this.categories.find((tab: PinmonyHomeTab): boolean => tab.selected)?.id || 'initial';
  }

  private selectTab(tab: PinmonyHomeTab): void {
    if ((!this.interactionReady && !this.offlinePreview) || !tab.enabled || tab.selected) return;
    if (this.offlinePreview) {
      this.offlineCategoryId = tab.id;
      this.updateCategories();
      return;
    }
    if (!this.onTab) return;
    this.applyCategories(this.categories.map((item: PinmonyHomeTab): PinmonyHomeTab => {
      return { id: item.id, label: item.label, enabled: item.enabled, selected: item.id === tab.id };
    }));
    this.onTab(tab.id);
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

  private suppressSwipeClick: boolean = false;

  private swipeCategory(offsetX: number, offsetY: number): void {
    if ((!this.interactionReady && !this.offlinePreview) || Math.abs(offsetX) < 48 ||
      Math.abs(offsetX) <= Math.abs(offsetY) * 1.5) return;
    const selected: number = this.categories.findIndex((tab: PinmonyHomeTab): boolean => tab.selected);
    if (selected < 0) return;
    const direction: number = offsetX < 0 ? 1 : -1;
    for (let index: number = selected + direction; index >= 0 && index < this.categories.length; index += direction) {
      if (!this.categories[index].enabled) continue;
      this.selectTab(this.categories[index]);
      return;
    }
  }

  private imageHeight(pin: PinmonyHomePin): number {
    const width: number = Math.max(130, (this.contentWidth - 24 - (this.contentColumns() - 1) * 12) / this.contentColumns());
    if (pin.imageWidth <= 0 || pin.imageHeight <= 0) return width * 1.2;
    return width * Math.max(0.55, Math.min(3.2, pin.imageHeight / pin.imageWidth));
  }

  private canShowFeed(): boolean {
    if (this.home.pins.length === 0) return false;
    if (this.offlinePreview && this.offlineCategoryId &&
      !this.home.tabs.some((tab: PinmonyHomeTab): boolean => tab.selected && tab.id === this.offlineCategoryId)) return false;
    // A category switch must not label the old category's cards as new data.
    return !this.pendingTabId || this.home.tabs.some((tab: PinmonyHomeTab): boolean =>
      tab.id === this.pendingTabId && tab.selected);
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
    .onClick(() => { if (!this.suppressSwipeClick && this.onBoard) this.onBoard(board.id); })
    .accessibilityText(this.uiFormat("pm_open_board_value_value_pins_134006a7", [board.name, board.pinCount]))
  }

  @Builder
  private pinCard(pin: PinmonyHomePin, imageRevision: number = 0, session: number = 0, pageKey: string = '') {
    Column({ space: 8 }) {
      if (pin.video) {
        PinmonyVideoCard({ video: pin.video, poster: pin.imageUrl, active: this.mediaActive && this.actionsReady })
          .width('100%').height(this.imageHeight(pin))
          .id('pinmony-home-photo-' + pin.id)
          .onClick(() => { if (!this.suppressSwipeClick && this.onPin) this.onPin(pin.id); })
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
        .onClick(() => { if (!this.suppressSwipeClick && this.onPin) this.onPin(pin.id); })
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.recoveredSources[pin.imageUrl] || pin.imageUrl)
            .onComplete((event) => {
              if (event?.loadingStatus !== 1 ||
                session !== this.home.session || pageKey !== this.home.pageKey ||
                imageRevision !== (this.recoveredRevisions[pin.imageUrl] || 0)) return;
              if (this.imageTraceCount++ < 40) PinmonyRuntimeLog.info('HomeImageTrace: phase=complete index=' +
                this.home.pins.findIndex((item: PinmonyHomePin): boolean => item.id === pin.id) +
                ' sincePageMs=' + (Date.now() - this.imageTraceStartedAt));
            })
            .width('100%')
            .height(this.imageHeight(pin))
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
            .clip(true)
            .accessibilityLevel('no')
            .onError((event) => {
              if (session !== this.home.session || pageKey !== this.home.pageKey) return;
              if (imageRevision !== (this.recoveredRevisions[pin.imageUrl] || 0)) return;
              if (this.failedImages.indexOf(pin.imageUrl) < 0) {
                PinmonyRuntimeLog.warn('HomeImageError: revision=' + imageRevision.toString() +
                  ' index=' + this.home.pins.findIndex((item: PinmonyHomePin): boolean => item.id === pin.id) +
                  ' code=' + (event?.error?.code || 0).toString());
                this.failedImages = [...this.failedImages, pin.imageUrl];
                this.onImageRecovery();
                this.retryRecoveredImages();
              }
            })
            .onClick(() => { if (!this.suppressSwipeClick && this.onPin) this.onPin(pin.id); })
          if (pin.saved === true) {
            Column() {
              Text(this.uiText("pm_saved_471dd4d7")).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .padding({ left: 14, right: 14, top: 16 })
              Blank()
            }.width('100%').height(this.imageHeight(pin)).backgroundColor('#55000000')
              .borderRadius(18).clip(true).hitTestBehavior(HitTestMode.None)
          }
        }.width('100%').height(this.imageHeight(pin)).borderRadius(18).clip(true)
          .id('pinmony-home-photo-' + pin.id)
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
            .onClick(() => { if (!this.suppressSwipeClick && this.onPin) this.onPin(pin.id); })
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
          if (!this.suppressSwipeClick && this.onMore) this.onMore(pin.id);
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
    const cardSources: Set<string> = new Set<string>();
    this.home.pins.forEach((pin: PinmonyHomePin): void => {
      cardSources.add(this.recoveredSources[pin.imageUrl] || pin.imageUrl);
    });
    const seen: Set<string> = new Set<string>();
    return this.prefetchedImageUrls.filter((url: string): boolean => {
      if (!url || seen.has(url) || cardSources.has(url)) return false;
      seen.add(url);
      return true;
    });
  }

  private selectedCategoryIndex(): number {
    return Math.max(0, this.categories.findIndex((tab: PinmonyHomeTab): boolean => tab.selected));
  }

  @Builder
  private homeRefreshIndicator() {
    Column() {
      LoadingProgress().width(24).height(24)
      .color($r('app.color.accent'))
      .visibility(this.refreshing || this.refreshGestureState === RefreshStatus.Drag ||
        this.refreshGestureState === RefreshStatus.OverDrag ? Visibility.Visible : Visibility.Hidden)
    }.width('100%').height(64).justifyContent(FlexAlign.Center)
      .offset({ y: this.homeTopInset() + 48 + (this.home.board ? 68 : 0) })
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private feedContent() {
    Column() {
      if (this.feedActive) {
        // Load detail-sized image resources through ArkUI's existing image cache.
        // This zero-height container has no input or accessibility semantics.
        Row() {
          ForEach(this.uniquePrefetchImages(), (url: string) => {
            Image(url).width(1).height(1).opacity(0).accessibilityLevel('no')
          }, (url: string) => url)
        }.height(0).clip(true).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }

      if (!this.canShowFeed()) {
        if (!this.offlinePreview && (this.loading || this.synchronizing) && !this.error) {
          PinmonyHomeSkeleton({ showCategories: this.categories.length === 0 })
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
              ForEach(this.home.pins, (pin: PinmonyHomePin) => {
                FlowItem() {
                  this.pinCard(pin, this.recoveredRevisions[pin.imageUrl] || 0, this.home.session, this.home.pageKey)
                }
                .width('100%')
              }, (pin: PinmonyHomePin) => pin.id + ':' + pin.imageUrl + ':' + pin.title + ':' + (this.recoveredRevisions[pin.imageUrl] || 0))
              FlowItem() {
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
              }
              .width('100%')
              FlowItem() {
                Column()
                  .height(100)
                  .accessibilityLevel('no')
              }
              .width('100%')
            }
            .columnsTemplate(this.contentColumnsTemplate())
            .columnsGap(12)
            .rowsGap(12)
            .width('100%')
            .height('100%')
            .padding({ left: 12, right: 12, top: this.homeTopInset() + (this.home.board ? 132 : 64) })
            .clipContent(ContentClipMode.BOUNDARY)
            .cachedCount(12, true)
            .clip(false)
            .scrollBar(BarState.Off)
            .onAppear(() => this.restoreScrollPosition())
            .onDidScroll((offset: number, state: ScrollState) => {
              this.updateHomeChrome(offset, state);
              this.reportScrollPosition();
              if (this.onContentScroll) this.onContentScroll(offset, state);
            })
            .onScrollIndex((first: number, last: number) => {
              this.visibleFirst = Math.max(0, first);
              this.visibleLast = Math.min(last, this.home.pins.length - 1);
              if (this.onVisiblePins) this.onVisiblePins(first, last);
              this.retryRecoveredImages();
              this.prefetchVisibleDetails();
              this.prefetchNextScreen();
              setTimeout(() => this.fillShortViewport(), 0);
            })
            .onScrollStop(() => {
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
              setTimeout(() => this.fillShortViewport(), 0);
              const width: number = Number(newArea.width);
              if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
            })
          }
          .width('100%')
          .height('100%')
          .clip(false)
          .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
          .onStateChange((state: RefreshStatus) => { this.refreshGestureState = state; })
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

  @Builder
  private categoryButtons() {
    Stack({alignContent:Alignment.TopStart}) {
      if (this.home.board && this.canShowFeed()) {
        Column().width('100%').height(this.homeTopInset() + 48)
          .backgroundColor($r('app.color.page_background'))
          .opacity(this.homeChromeCollapsed ? 0 : 1)
          .position({x:0,y:-this.homeTopInset()})
          .hitTestBehavior(HitTestMode.None)
          .accessibilityLevel('no')
      }
    Column() {
      if (this.categories.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.categories, (tab: PinmonyHomeTab) => {
              Button(PinmonyI18n.render(tab.label, this.uiLanguage), { type: ButtonType.Capsule })
                .height(36)
                .padding({ left: 20, right: 20 })
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(tab.selected ? $r('app.color.home_category_selected') : $r('app.color.input_surface'))
                .fontColor(tab.selected ? $r('app.color.page_background') : $r('app.color.primary_text'))
                .enabled((this.interactionReady || this.offlinePreview) && tab.enabled)
                .accessibilitySelected(tab.selected)
                .onClick(() => {
                  const current: PinmonyHomeTab | undefined = this.categories.find((item: PinmonyHomeTab): boolean => item.id === tab.id);
                  if (current) this.selectTab(current);
                })
            }, (tab: PinmonyHomeTab) => tab.id + ':' + tab.label + ':' + tab.selected.toString() + ':' + tab.enabled.toString() + ':' + this.uiLanguage)
          }
          .padding({ left: 24, right: 24 })
          .height(48)
        }
        .width('100%')
        .height(48)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
      }
    }.width('100%').height(48)
    .hitTestBehavior(HitTestMode.Transparent)
    }.width('100%').height(48).clip(false).hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private homeNavigation() {
    Stack({alignContent:Alignment.TopStart}) {
    HdsNavigation() { this.feedContent() }
      .width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .titleBar(this.homeTitleBarOptions())
      .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
        { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
      .bindToScrollable([this.feedScroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .clip(false)
      .onAreaChange((_oldArea: Area, area: Area) => this.traceLayout('navigation', area))
      if (this.home.board && this.canShowFeed()) {
        Column() {
          Column() { this.boardSummary(this.home.board) }.width('100%').height(68)
            .backgroundColor($r('app.color.page_background'))
        }.width('100%').height(68)
          .position({x:0,y:this.homeTopInset() + 48})
          .opacity(this.homeChromeCollapsed ? 0 : 1)
          .clip(true)
          .hitTestBehavior(this.homeChromeCollapsed ? HitTestMode.None : HitTestMode.Default)
          .accessibilityLevel(this.homeChromeCollapsed ? 'no-hide-descendants' : 'auto')
      }
    }.width('100%').height('100%')
  }

  private homeTitleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      style: {
        blurStrategy: this.immersiveLightMode !== 'off' ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
        thermoCtrl: this.immersiveLightMode !== 'off',
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightMode !== 'off',
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)
      },
      content: { stackBuilder: (): void => { this.categoryButtons(); } }
    };
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach([this.categoryPageKey()], (page: string) => {
          Column() { this.homeNavigation() }
            .width('100%').height('100%')
            .backgroundColor($r('app.color.page_background'))
            .hitTestBehavior(page === this.categoryPageKey() ? HitTestMode.Default : HitTestMode.None)
            .accessibilityLevel(page === this.categoryPageKey() ? 'auto' : 'no-hide-descendants')
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.translate({ x: this.categoryDirection * this.contentWidth }),
              TransitionEffect.translate({ x: -this.categoryDirection * this.contentWidth })))
        }, (page: string) => page)
      }
        .width('100%').height('100%').clip(false)
        .onAreaChange((_previous: Area, current: Area) => {
          const width: number = Number(current.width);
          if (Number.isFinite(width) && width > 0) this.contentWidth = width;
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) this.suppressSwipeClick = false;
        })
        .priorityGesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 12 })
            .onActionStart(() => { this.suppressSwipeClick = true; })
            .onActionEnd((event: GestureEvent) => this.swipeCategory(event.offsetX, event.offsetY))
        )
    }
    .width('100%').height('100%')
    .onAreaChange((_oldArea: Area, area: Area) => this.traceLayout('root', area))
  }

}
