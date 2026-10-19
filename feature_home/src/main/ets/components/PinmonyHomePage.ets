import { PinmonyVideoCard } from 'common_ui';
import { allowsSpeculativeReads, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyHomeBoard, PinmonyHomePin, PinmonyHomeSnapshot, PinmonyHomeTab, PinmonyHomeImageRecovery } from '../models/PinmonyHome';
import { PinmonyHomeSkeleton } from './PinmonyHomeSkeleton';

@Component
export struct PinmonyHomePage {
  @Prop @Watch('onImageRecovery') imageRecovery: PinmonyHomeImageRecovery | undefined = undefined;
  @State private recoveredSources: Record<string, string> = {};
  @State private recoveredRevisions: Record<string, number> = {};
  private lastImageRecovery: number = 0;
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
    if (this.restoringScroll || !this.home.board) return;
    try {
      const position: number = Math.max(0, this.feedScroller.currentOffset().yOffset);
      // Idle callbacks may finish at the top without a final scrolling callback.
      if (state === ScrollState.Idle && position > 4) return;
      const collapsed: boolean = position > 32 ? true : position <= 4 ? false : this.homeChromeCollapsed;
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
        this.homeChromeCollapsed = false;
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
    setTimeout(() => { this.resumePendingEnd(); this.prefetchVisibleDetails(); this.prefetchNextScreen(); }, 0);
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
    setTimeout(() => { this.resumePendingEnd(); this.prefetchVisibleDetails(); this.prefetchNextScreen(); }, 0);
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
    if (this.offlinePreview) return '当前离线，此分类暂无可显示的缓存照片，请连接网络后重试';
    if (this.error) return this.error;
    if (this.home.kind === 'loading') return '内容加载已中断，请重试';
    return '当前分类暂无 Pin 图';
  }

  private updateCategories(): void {
    this.categories = (this.home.tabs || []).map((tab: PinmonyHomeTab): PinmonyHomeTab => {
      return { id: tab.id, label: tab.label, enabled: tab.enabled,
        selected: this.offlinePreview && this.offlineCategoryId ? tab.id === this.offlineCategoryId :
          this.pendingTabId ? tab.id === this.pendingTabId : tab.selected };
    });
  }

  private selectTab(tab: PinmonyHomeTab): void {
    if ((!this.interactionReady && !this.offlinePreview) || !tab.enabled || tab.selected) return;
    if (this.offlinePreview) {
      this.offlineCategoryId = tab.id;
      this.updateCategories();
      return;
    }
    if (!this.onTab) return;
    this.categories = this.categories.map((item: PinmonyHomeTab): PinmonyHomeTab => {
      return { id: item.id, label: item.label, enabled: item.enabled, selected: item.id === tab.id };
    });
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
            Text(this.feedStatusText())
              .fontSize(13)
              .fontColor($r('app.color.secondary_text'))
              .maxLines(2)
              .layoutWeight(1)
            if (this.error) {
              Button('重试').fontSize(13)
                .onClick(() => { if (this.onRetry) this.onRetry(); })
            }
          }
          .width('100%')
        }
        if (this.offlinePreview) {
          Row({ space: 8 }) {
            Text('当前离线，仅显示最近缓存')
              .fontSize(13)
              .fontColor($r('app.color.secondary_text'))
              .maxLines(2)
              .layoutWeight(1)
            Button('重试').fontSize(13)
              .onClick(() => { if (this.onRetry) this.onRetry(); })
          }
          .width('100%')
          .accessibilityText('当前离线，仅显示最近缓存，可重试')
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
    if (this.offlinePreview) return '当前离线，仅显示最近缓存';
    if (this.error) return this.home.categorySourceFailure ? this.error : this.error + '，显示上次内容';
    if (this.refreshing || this.home.refreshing) return '正在刷新首页…';
    if (this.loading) return '正在加载首页…';
    return '正在恢复首页连接…';
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
        Text(board.name)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${board.pinCount} 张 Pin 图`)
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
    .onClick(() => { if (this.onBoard) this.onBoard(board.id); })
    .accessibilityText(`打开图板：${board.name}，${board.pinCount} 张 Pin 图`)
  }

  @Builder
  private pinCard(pin: PinmonyHomePin, imageRevision: number = 0, session: number = 0, pageKey: string = '') {
    Column({ space: 8 }) {
      if (pin.video) {
        PinmonyVideoCard({ video: pin.video, poster: pin.imageUrl, active: this.mediaActive && this.actionsReady })
          .width('100%').height(this.imageHeight(pin))
          .onClick(() => { if (this.onPin) this.onPin(pin.id); })
      } else if (this.failedImages.indexOf(pin.imageUrl) >= 0) {
        Column() {
          Text('图片加载失败')
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height(this.imageHeight(pin))
        .borderRadius(18)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
        .accessibilityText((pin.title || 'Pin 图') + '，图片加载失败，打开详情')
        .onClick(() => { if (this.onPin) this.onPin(pin.id); })
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
              }
            })
            .onClick(() => { if (this.onPin) this.onPin(pin.id); })
          if (pin.saved === true) {
            Column() {
              Text('已收藏').fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
                .padding({ left: 14, right: 14, top: 16 })
              Blank()
            }.width('100%').height(this.imageHeight(pin)).backgroundColor('#55000000')
              .borderRadius(18).clip(true).hitTestBehavior(HitTestMode.None)
          }
        }.width('100%').height(this.imageHeight(pin)).borderRadius(18).clip(true)
      }
      Row({ space: 4 }) {
        if (pin.title.trim().length > 0) {
          Text(pin.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .onClick(() => { if (this.onPin) this.onPin(pin.id); })
        } else {
          Blank()
        }
        Button({ type: ButtonType.Circle }) {
          if (this.menuLoadingId === pin.id) {
            LoadingProgress().width(20).height(20)
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
          if (this.onMore) this.onMore(pin.id);
        })
        .accessibilityText('更多选项')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .enabled(this.navigationReady)
    .accessibilityText(pin.title || '打开 Pin 图')
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
      if (this.home.board && this.canShowFeed()) {
        Column() {
          this.boardSummary(this.home.board)
        }
        .width('100%')
        .height(this.homeChromeCollapsed ? 0 : 68)
        .opacity(this.homeChromeCollapsed ? 0 : 1)
        .hitTestBehavior(this.homeChromeCollapsed ? HitTestMode.None : HitTestMode.Default)
        .accessibilityLevel(this.homeChromeCollapsed ? 'no-hide-descendants' : 'auto')
        .clip(true)
      }

      if (!this.canShowFeed()) {
        if (!this.offlinePreview && (this.loading || this.synchronizing) && !this.error) {
          PinmonyHomeSkeleton({ showCategories: this.categories.length === 0 })
            .width('100%')
            .layoutWeight(1)
        } else {
          Column({ space: 12 }) {
            Text(this.emptyFeedMessage())
              .width('100%')
              .textAlign(TextAlign.Center)
              .fontSize(16)
              .fontColor($r('app.color.primary_text'))
            Button(this.offlinePreview ? '连接后重试' : '重新读取')
              .onClick(() => { if (this.onRetry) this.onRetry(); })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 24, right: 24, bottom: 100 })
        }
      } else {
        Stack({ alignContent: Alignment.Top }) {
          Refresh({ refreshing: this.refreshing }) {
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
                      LoadingProgress().width(24).height(24)
                    } else if (this.home.sourceError) {
                      Button('重试加载')
                        .onClick(() => { if (this.onLoadMore) this.onLoadMore(); })
                    } else if (this.home.endReached) {
                      Text('暂无更多 Pin 图')
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
            .padding({ left: 12, right: 12, top: 16 })
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
              this.prefetchVisibleDetails();
              this.prefetchNextScreen();
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
              const width: number = Number(newArea.width);
              if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
            })
          }
          .width('100%')
          .height('100%')
          .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
          this.feedStatus()
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Column() {
      if (this.categories.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.categories, (tab: PinmonyHomeTab) => {
              Button(tab.label, { type: ButtonType.Capsule })
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
            }, (tab: PinmonyHomeTab) => tab.id + ':' + tab.label + ':' + tab.selected.toString() + ':' + tab.enabled.toString())
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
      this.feedContent()
    }
    .width('100%').height('100%')
  }
}
