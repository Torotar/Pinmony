import { BlurStrategy, HdsNavigation, HdsNavigationTitleBarOptions, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyHomeSnapshot, PinmonyHomeTab, PinmonyHomeImageRecovery } from '../models/PinmonyHome';
import { PinmonyHomeFeedPane } from './PinmonyHomeFeedPane';

@Component
export struct PinmonyHomePage {
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private homeTopInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx); }
  @Prop imageRecovery: PinmonyHomeImageRecovery | undefined = undefined;
  @Prop @Watch('onHomeChanged') home: PinmonyHomeSnapshot = {} as PinmonyHomeSnapshot;
  @Prop @Watch('onPendingTabChanged') pendingTabId: string = '';
  @Prop mediaActive: boolean = false;
  @Prop prefetchedImageUrls: string[] = [];
  @Prop feedActive: boolean = false;
  @Prop loading: boolean = false;
  @Prop synchronizing: boolean = false;
  @Prop @Watch('onOfflinePreviewChanged') offlinePreview: boolean = false;
  @Prop refreshing: boolean = false;
  @Prop paginationReady: boolean = true;
  @Prop actionsReady: boolean = true;
  @Prop menuReady: boolean = true;
  @Prop navigationReady: boolean = true;
  @Prop interactionReady: boolean = true;
  @Prop initialScrollOffset: number = 0;
  @Prop menuLoadingId: string = '';
  @Prop error: string = '';
  @Prop @Watch('onPresentationReset') presentationEpoch: number = 0;
  scrollOffsetForCategory?: (pageKey: string, categoryId: string) => number | undefined;
  @State private categories: PinmonyHomeTab[] = [];
  @State private snapshots: PinmonyHomeSnapshot[] = [];
  @State private selectedId: string = '';
  @State private pagerIndex: number = 0;
  @State private pagerMoving: boolean = false;
  @State private suppressSwipeClick: boolean = false;
  @State private homeChromeCollapsed: boolean = false;
  private feedScroller: Scroller = new Scroller();
  @State private scrollerRevision: number = 0;
  private readonly categorySwiper: SwiperController = new SwiperController();
  private readonly paneScrollers: Map<string, Scroller> = new Map<string, Scroller>();
  private readonly paneChrome: Map<string, boolean> = new Map<string, boolean>();
  private readonly paneOffsets: Map<string, number> = new Map<string, number>();
  onTab?: (id: string) => void;
  onBoard?: (id: string) => void;
  onPrefetchMore?: () => void;
  onPin?: (id: string) => void;
  onMore?: (id: string) => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onScrollPosition?: (pageKey: string, offset: number, categoryId: string) => void;
  onVisiblePins?: (first: number, last: number) => void;
  onPrefetchPins?: (first: number, last: number) => void;


  private categoryId(snapshot: PinmonyHomeSnapshot): string {
    return snapshot.tabs?.find((tab: PinmonyHomeTab): boolean => tab.selected)?.id ||
      (snapshot.board ? 'tab:' + snapshot.board.id : 'tab:all');
  }

  private paneKey(id: string): string { return this.home.pageKey + '|' + id; }

  private retainSnapshot(): void {
    if (!this.home.pageKey) return;
    const id: string = this.categoryId(this.home);
    if (this.home.kind === 'loading' && this.snapshots.some((item: PinmonyHomeSnapshot): boolean =>
      item.pageKey === this.home.pageKey && this.categoryId(item) === id && item.pins.length > 0)) return;
    // Freeze category metadata: native read commits reuse cached snapshot objects.
    const copy: PinmonyHomeSnapshot = {
      kind: this.home.kind, session: this.home.session, contextEpoch: this.home.contextEpoch,
      pageKey: this.home.pageKey, selectedTab: this.home.selectedTab,
      tabs: this.home.tabs.map((tab: PinmonyHomeTab): PinmonyHomeTab => {
        return { id: tab.id, label: tab.label, selected: tab.selected, enabled: tab.enabled };
      }),
      board: this.home.board, pins: this.home.pins.slice(), error: this.home.error,
      dataSource: this.home.dataSource, loadingMore: this.home.loadingMore,
      refreshing: this.home.refreshing, endReached: this.home.endReached,
      sourceError: this.home.sourceError, categorySourceFailure: this.home.categorySourceFailure
    };
    const retained: PinmonyHomeSnapshot[] = this.snapshots.filter((item: PinmonyHomeSnapshot): boolean =>
      item.pageKey === copy.pageKey && this.categoryId(item) !== id);
    this.snapshots = retained.slice(-3).concat([copy]);
  }

  private snapshotFor(id: string): PinmonyHomeSnapshot {
    const cached: PinmonyHomeSnapshot | undefined = this.snapshots.find((item: PinmonyHomeSnapshot): boolean =>
      item.pageKey === this.home.pageKey && this.categoryId(item) === id);
    if (cached) return cached;
    return { kind: 'loading', session: this.home.session, pageKey: this.home.pageKey,
      selectedTab: '', tabs: this.categories.map((tab: PinmonyHomeTab): PinmonyHomeTab => {
        return { id: tab.id, label: tab.label, enabled: tab.enabled, selected: tab.id === id };
      }), pins: [], dataSource: this.home.dataSource };
  }

  private pageTabs(): PinmonyHomeTab[] { return this.categories.filter((tab: PinmonyHomeTab): boolean => tab.enabled); }

  private syncCategories(): void {
    const id: string = this.selectedId || this.pendingTabId || this.categoryId(this.home);
    const tabs: PinmonyHomeTab[] = this.home.tabs?.length ? this.home.tabs :
      [{ id: this.categoryId(this.home), label: this.home.selectedTab || '', selected: true, enabled: true }];
    this.categories = tabs.map((tab: PinmonyHomeTab): PinmonyHomeTab => {
      return { id: tab.id, label: tab.label, enabled: tab.enabled, selected: tab.id === id };
    });
  }

  aboutToAppear(): void {
    this.selectedId = this.pendingTabId || this.categoryId(this.home);
    this.retainSnapshot();
    this.syncCategories();
    this.pagerIndex = Math.max(0, this.pageTabs().findIndex((tab: PinmonyHomeTab): boolean => tab.id === this.selectedId));
  }

  private onHomeChanged(): void {
    this.retainSnapshot();
    const id: string = this.pendingTabId || this.categoryId(this.home);
    if (id !== this.selectedId) {
      this.captureCurrentPosition();
      this.selectedId = id;
      this.bindCurrentScroller();
    }
    this.syncCategories();
    const index: number = this.pageTabs().findIndex((tab: PinmonyHomeTab): boolean => tab.id === this.selectedId);
    if (index >= 0 && index !== this.pagerIndex) {
      this.pagerIndex = index;
      this.categorySwiper.changeIndex(index, false);
    }
  }

  private onPendingTabChanged(): void {
    if (!this.pendingTabId || this.pendingTabId === this.selectedId) return;
    this.captureCurrentPosition();
    this.selectedId = this.pendingTabId;
    this.syncCategories();
    this.bindCurrentScroller();
    const index: number = this.pageTabs().findIndex((tab: PinmonyHomeTab): boolean => tab.id === this.selectedId);
    if (index >= 0 && index !== this.pagerIndex) { this.pagerIndex = index; this.categorySwiper.changeIndex(index, false); }
  }

  private onOfflinePreviewChanged(): void { this.onHomeChanged(); }

  private onPresentationReset(): void {
    this.snapshots = [];
    this.paneScrollers.clear(); this.paneChrome.clear(); this.paneOffsets.clear();
    this.selectedId = this.pendingTabId || this.categoryId(this.home);
    this.pagerMoving = false;
    this.scrollerRevision = 0;
    this.syncCategories();
  }

  private rememberPosition(id: string, pageKey: string, offset: number, epoch: number = this.presentationEpoch): void {
    if (epoch !== this.presentationEpoch) return;
    this.paneOffsets.set(pageKey + '|' + id, offset);
    if (this.onScrollPosition) this.onScrollPosition(pageKey, offset, id);
  }

  private captureCurrentPosition(): void {
    const scroller: Scroller | undefined = this.paneScrollers.get(this.paneKey(this.selectedId));
    if (!scroller) return;
    try { this.rememberPosition(this.selectedId, this.home.pageKey, Math.max(0, scroller.currentOffset().yOffset)); } catch (_) { }
  }

  private initialOffset(id: string): number {
    const local: number | undefined = this.paneOffsets.get(this.paneKey(id));
    if (local !== undefined) return local;
    const saved: number | undefined = this.scrollOffsetForCategory?.(this.home.pageKey, id);
    if (saved !== undefined) return saved;
    return id === this.categoryId(this.home) ? this.initialScrollOffset : 0;
  }

  private registerScroller(id: string, scroller: Scroller | undefined, epoch: number): void {
    if (epoch !== this.presentationEpoch) return;
    if (!scroller) { this.paneScrollers.delete(this.paneKey(id)); return; }
    this.paneScrollers.set(this.paneKey(id), scroller);
    if (id === this.selectedId) { this.feedScroller = scroller; this.scrollerRevision++; }
  }

  private bindCurrentScroller(): void {
    const scroller: Scroller | undefined = this.paneScrollers.get(this.paneKey(this.selectedId));
    if (scroller) { this.feedScroller = scroller; this.scrollerRevision++; }
    this.homeChromeCollapsed = this.paneChrome.get(this.paneKey(this.selectedId)) || false;
  }

  private canShowFeed(): boolean { return this.snapshotFor(this.selectedId).pins.length > 0; }

  private scrollBinding(): Scroller[] { return this.scrollerRevision > 0 ? [this.feedScroller] : []; }

  private activePane(id: string): boolean {
    return id === this.selectedId && id === this.categoryId(this.home) && !this.pagerMoving;
  }

  private requestCategory(id: string): void {
    if (!id || id === this.selectedId) return;
    this.captureCurrentPosition();
    this.selectedId = id;
    this.syncCategories(); this.bindCurrentScroller();
    if (!this.offlinePreview && this.onTab) this.onTab(id);
  }

  private selectTab(tab: PinmonyHomeTab): void {
    if ((!this.interactionReady && !this.offlinePreview) || !tab.enabled || tab.selected) return;
    const index: number = this.pageTabs().findIndex((item: PinmonyHomeTab): boolean => item.id === tab.id);
    if (index < 0) return;
    this.categorySwiper.changeIndex(index, true);
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
  private categoryFeed() {
    Swiper(this.categorySwiper) {
      ForEach(this.pageTabs(), (tab: PinmonyHomeTab) => {
        PinmonyHomeFeedPane({
          home: this.snapshotFor(tab.id), categoryId: tab.id, presentationEpoch: this.presentationEpoch,
          initialChromeCollapsed: this.paneChrome.get(this.paneKey(tab.id)) || false,
          paneActive: this.activePane(tab.id), suppressPinClick: this.suppressSwipeClick,
          imageRecovery: this.imageRecovery,
          mediaActive: this.mediaActive && this.activePane(tab.id),
          prefetchedImageUrls: this.activePane(tab.id) ? this.prefetchedImageUrls : [],
          feedActive: this.feedActive && this.activePane(tab.id),
          loading: this.snapshotFor(tab.id).kind === 'loading' || this.loading && this.activePane(tab.id),
          synchronizing: this.synchronizing && this.activePane(tab.id),
          offlinePreview: this.offlinePreview,
          refreshing: this.refreshing && this.activePane(tab.id),
          paginationReady: this.paginationReady && this.activePane(tab.id),
          actionsReady: this.actionsReady && this.activePane(tab.id),
          menuReady: this.menuReady && this.activePane(tab.id),
          navigationReady: this.navigationReady && this.activePane(tab.id),
          interactionReady: this.interactionReady && this.activePane(tab.id),
          initialScrollOffset: this.initialOffset(tab.id), menuLoadingId: this.menuLoadingId,
          error: this.activePane(tab.id) ? this.error : '',
          onScrollerReady: (scroller: Scroller | undefined, epoch: number) => this.registerScroller(tab.id, scroller, epoch),
          onChromeChanged: (collapsed: boolean) => {
            this.paneChrome.set(this.paneKey(tab.id), collapsed);
            if (tab.id === this.selectedId) this.homeChromeCollapsed = collapsed;
          },
          onScrollPosition: (pageKey: string, offset: number, epoch: number) => this.rememberPosition(tab.id, pageKey, offset, epoch),
          onContentScroll: (offset: number, state: ScrollState) => {
            if (this.activePane(tab.id) && this.onContentScroll) this.onContentScroll(offset, state);
          },
          onPin: this.onPin, onMore: this.onMore, onBoard: this.onBoard,
          onLoadMore: this.onLoadMore, onPrefetchMore: this.onPrefetchMore,
          onRefresh: this.onRefresh, onRetry: this.onRetry,
          onVisiblePins: (first: number, last: number) => {
            if (this.activePane(tab.id) && this.onVisiblePins) this.onVisiblePins(first, last);
          },
          onPrefetchPins: this.onPrefetchPins
        }).width('100%').height('100%')
          .hitTestBehavior(tab.id === this.selectedId ? HitTestMode.Default : HitTestMode.None)
          .accessibilityLevel(tab.id === this.selectedId ? 'auto' : 'no-hide-descendants')
      }, (tab: PinmonyHomeTab): string => this.presentationEpoch.toString() + ':' + this.paneKey(tab.id))
    }.index(this.pagerIndex)
      .loop(false).indicator(false).itemSpace(0).duration(280).cachedCount(1)
      .disableSwipe(!this.interactionReady && !this.offlinePreview)
      .onChange((index: number) => {
        this.pagerIndex = index;
        this.requestCategory(this.pageTabs()[index]?.id || '');
      })
      .onAnimationStart(() => { this.pagerMoving = true; this.suppressSwipeClick = true; })
      .onAnimationEnd(() => { this.pagerMoving = false; this.bindCurrentScroller(); })
      .onContentDidScroll((_selected: number, _index: number, position: number) => {
        if (Math.abs(position) > 0.001 && Math.abs(position) < 0.999) { this.pagerMoving = true; this.suppressSwipeClick = true; }
      })
      .onTouch((event: TouchEvent) => { if (event.type === TouchType.Down) this.suppressSwipeClick = false; })
      .width('100%').height('100%').clip(true)
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
      HdsNavigation() { this.categoryFeed() }
        .width('100%').height('100%')
        .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
        .titleBar(this.homeTitleBarOptions())
        .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
          { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
        .bindToScrollable(this.scrollBinding())
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .clip(false)
    }.width('100%').height('100%').clip(true)
      .backgroundColor($r('app.color.page_background'))
  }
}
