import { BlurStrategy, HdsNavigation, HdsNavigationTitleBarOptions, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyImmersiveLight, PinmonyBackToTopButton } from 'common_ui';
import { PinmonyHomeSnapshot, PinmonyHomeTab, PinmonyHomeImageRecovery } from '../models/PinmonyHome';
import { PinmonyHomeFeedPane } from './PinmonyHomeFeedPane';
import { PinmonyHomeCategoryMaterial } from './PinmonyHomeCategoryMaterial';

@Observed
class PinmonyHomeBackdropState {
  opacity: number = 0;
  moving: boolean = false;
}

// The parent observes only replacement of this holder's first-level field.
// Frame updates belong to its nested observed child, consumed through @ObjectLink.
class PinmonyHomeChromeState {
  backdrop: PinmonyHomeBackdropState = new PinmonyHomeBackdropState();
}

@Component
struct PinmonyHomeCategoryBackdrop {
  @ObjectLink state: PinmonyHomeBackdropState;
  @Prop topInset: number = 0;

  build() {
    Column().width('100%').height(this.topInset + 48)
      .backgroundColor($r('app.color.page_background'))
      .opacity(this.state.opacity)
      .animation({ duration: this.state.moving ? 0 : 180, curve: Curve.EaseOut })
      .position({ x: 0, y: -this.topInset })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }
}

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
  @Prop presentationActive: boolean = true;
  @Prop imageLoadingActive: boolean = true;
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
  // Raw frame progress is bookkeeping, observed only by the small backdrop child.
  private pagerPosition: number = -1;
  @State private pagerChromeIndex: number = -1;
  @State private pagerBindingRevision: number = 0;
  private pagerBindingKey: string = '';
  @State private chromeState: PinmonyHomeChromeState = new PinmonyHomeChromeState();
  private readonly categoryMaterials: Map<string, PinmonyHomeCategoryMaterial> = new Map();
  private readonly emptyPrefetchedImageUrls: string[] = [];
  @State private suppressSwipeClick: boolean = false;
  @State private homeChromeCollapsed: boolean = false;
  @State private backToTopVisible: boolean = false;
  @State private backToTopOffset: number = 0;
  private feedScroller: Scroller = new Scroller();
  @State private scrollerRevision: number = 0;
  private readonly categorySwiper: SwiperController = new SwiperController();
  private readonly paneScrollers: Map<string, Scroller> = new Map<string, Scroller>();
  @State private paneChrome: Map<string, boolean> = new Map<string, boolean>();
  private readonly paneOffsets: Map<string, number> = new Map<string, number>();
  onTab?: (id: string) => void;
  onBoard?: (id: string) => void;
  onPrefetchMore?: () => void;
  onPin?: (id: string, imageUrl?: string) => void;
  onMore?: (id: string) => void;
  onHoldAction?: (id: string, selection: number) => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onBackToTop?: () => void;
  onScrollPosition?: (pageKey: string, offset: number, categoryId: string) => void;
  onVisiblePins?: (first: number, last: number) => void;
  onPrefetchPins?: (first: number, last: number, limit?: number) => void;


  private categoryId(snapshot: PinmonyHomeSnapshot): string {
    return snapshot.tabs?.find((tab: PinmonyHomeTab): boolean => tab.selected)?.id ||
      (snapshot.board ? 'tab:' + snapshot.board.id : 'tab:all');
  }

  private paneKey(id: string): string { return this.home.pageKey + '|' + id; }

  private retainedContentSignature: string = '';

  private retainSnapshot(): void {
    if (!this.home.pageKey) return;
    const id: string = this.categoryId(this.home);
    if (this.home.kind === 'loading' && this.snapshots.some((item: PinmonyHomeSnapshot): boolean =>
      item.pageKey === this.home.pageKey && this.categoryId(item) === id && item.pins.length > 0)) return;
    // @Prop may receive an equivalent copied snapshot after an unrelated host
    // update. Do not replace every retained pane's input in that case.
    const signature: string = JSON.stringify(this.home);
    if (signature === this.retainedContentSignature && this.snapshots.length > 0) return;
    this.retainedContentSignature = signature;
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
    for (const key of this.categoryMaterials.keys()) {
      if (!this.home.tabs?.some((tab: PinmonyHomeTab): boolean => tab.id === key)) this.categoryMaterials.delete(key);
    }
    const tabs: PinmonyHomeTab[] = this.home.tabs?.length ? this.home.tabs :
      [{ id: this.categoryId(this.home), label: this.home.selectedTab || '', selected: true, enabled: true }];
    if (tabs.length === this.categories.length && tabs.every((tab: PinmonyHomeTab, index: number): boolean =>
      tab.id === this.categories[index].id && tab.label === this.categories[index].label &&
      tab.enabled === this.categories[index].enabled && (tab.id === id) === this.categories[index].selected)) return;
    this.categories = tabs.map((tab: PinmonyHomeTab): PinmonyHomeTab => {
      return { id: tab.id, label: tab.label, enabled: tab.enabled, selected: tab.id === id };
    });
  }

  aboutToAppear(): void {
    this.selectedId = this.pendingTabId || this.categoryId(this.home);
    this.retainSnapshot();
    this.syncCategories();
    this.syncPagerChrome();
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
    this.syncPagerChrome();
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
    this.syncPagerChrome();
    const index: number = this.pageTabs().findIndex((tab: PinmonyHomeTab): boolean => tab.id === this.selectedId);
    if (index >= 0 && index !== this.pagerIndex) { this.pagerIndex = index; this.categorySwiper.changeIndex(index, false); }
  }

  private onOfflinePreviewChanged(): void { this.onHomeChanged(); }

  private onPresentationReset(): void {
    this.backToTopVisible = false;
    this.retainedContentSignature = '';
    this.snapshots = [];
    this.paneScrollers.clear(); this.paneChrome.clear(); this.paneOffsets.clear();
    this.selectedId = this.pendingTabId || this.categoryId(this.home);
    this.pagerMoving = false;
    this.pagerPosition = -1;
    this.categoryMaterials.clear();
    this.scrollerRevision = 0;
    this.syncCategories();
    this.syncPagerChrome();
  }

  private rememberPosition(id: string, pageKey: string, offset: number, epoch: number = this.presentationEpoch): void {
    if (epoch !== this.presentationEpoch) return;
    this.paneOffsets.set(pageKey + '|' + id, offset);
    if (pageKey === this.home.pageKey && id === this.selectedId) {
      this.backToTopOffset = offset;
      this.backToTopVisible = this.backToTopOffset > 0;
    }
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
    if (!scroller) {
      this.paneScrollers.delete(this.paneKey(id)); this.scrollerRevision++;
      if (id === this.selectedId) this.backToTopVisible = false;
      return;
    }
    this.paneScrollers.set(this.paneKey(id), scroller);
    if (id === this.selectedId) {
      this.feedScroller = scroller;
      try { this.backToTopOffset = scroller.currentOffset().yOffset; this.backToTopVisible = this.backToTopOffset > 0; }
      catch (_) { this.backToTopVisible = false; }
    }
    this.scrollerRevision++;
  }

  private bindCurrentScroller(): void {
    const scroller: Scroller | undefined = this.paneScrollers.get(this.paneKey(this.selectedId));
    if (scroller) { this.feedScroller = scroller; this.scrollerRevision++; }
    this.homeChromeCollapsed = this.paneChrome.get(this.paneKey(this.selectedId)) || false;
    try { this.backToTopOffset = (scroller?.currentOffset().yOffset || 0); this.backToTopVisible = this.backToTopOffset > 0; }
    catch (_) { this.backToTopVisible = false; }
  }

  private backToTop(): void {
    if (this.presentationActive === false || (!this.interactionReady && !this.offlinePreview) || this.pagerMoving) return;
    const scroller: Scroller | undefined = this.paneScrollers.get(this.paneKey(this.selectedId));
    if (!scroller) return;
    scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
    this.onBackToTop?.();
  }

  private canShowFeed(): boolean { return this.snapshotFor(this.selectedId).pins.length > 0; }

  private scrollBinding(): Scroller[] {
    const bindingRevision: number = this.pagerBindingRevision;
    if (this.scrollerRevision <= 0 || bindingRevision < 0) return [];
    if (this.pagerPosition < 0) return [this.feedScroller];
    // HDS derives material activation from the bound vertical scroller, not blurRadius.
    // Bind an already scrolled visible pane during the drag, before onChange commits it.
    const tabs: PinmonyHomeTab[] = this.pageTabs();
    const first: number = Math.floor(this.pagerPosition), last: number = Math.ceil(this.pagerPosition);
    let candidate: Scroller | undefined = undefined;
    let greatestOffset: number = -1;
    for (let index: number = first; index <= last; index++) {
      const tab: PinmonyHomeTab | undefined = tabs[index];
      if (!tab) continue;
      const scroller: Scroller | undefined = this.paneScrollers.get(this.paneKey(tab.id));
      if (!scroller) continue;
      let offset: number = this.initialOffset(tab.id);
      try { offset = scroller.currentOffset().yOffset; } catch (_) { }
      if (!candidate || offset > greatestOffset) {
        candidate = scroller;
        greatestOffset = offset;
      }
    }
    return [candidate ?? this.feedScroller];
  }

  private activePane(id: string): boolean {
    return id === this.selectedId && id === this.categoryId(this.home) && !this.pagerMoving;
  }

  private requestCategory(id: string): void {
    if (!id || id === this.selectedId) return;
    this.captureCurrentPosition();
    this.selectedId = id;
    this.syncCategories();
    this.bindCurrentScroller(); this.syncPagerChrome();
    if (!this.offlinePreview && this.onTab) this.onTab(id);
  }

  private selectTab(tab: PinmonyHomeTab): void {
    if ((!this.interactionReady && !this.offlinePreview) || !tab.enabled || tab.selected) return;
    const index: number = this.pageTabs().findIndex((item: PinmonyHomeTab): boolean => item.id === tab.id);
    if (index < 0) return;
    this.categorySwiper.changeIndex(index, true);
  }

  private paneChromeOpacity(id: string): number {
    const collapsed: boolean = this.paneChrome.get(this.paneKey(id)) ??
      (id === this.selectedId ? this.homeChromeCollapsed : false);
    return collapsed ? 0 : 1;
  }

  private updatePaneChrome(id: string, collapsed: boolean): void {
    if (this.paneChrome.get(this.paneKey(id)) === collapsed &&
      (id !== this.selectedId || this.homeChromeCollapsed === collapsed)) return;
    // Animate only the chrome attributes, never the scrolling feed transaction.
    this.paneChrome.set(this.paneKey(id), collapsed);
    if (id === this.selectedId) this.homeChromeCollapsed = collapsed;
    this.syncPagerChrome();
  }

  private categoryBackdropAnimation(): AnimateParam {
    // Horizontal paging supplies its own frame progress; do not ease it again.
    return { duration: this.pagerPosition >= 0 ? 0 : 180, curve: Curve.EaseOut };
  }

  private paneBackdropOpacity(index: number): number {
    const tab: PinmonyHomeTab | undefined = this.pageTabs()[index];
    if (!tab) return 0;
    const snapshot: PinmonyHomeSnapshot = this.snapshotFor(tab.id);
    return snapshot.board && snapshot.pins.length > 0 ? this.paneChromeOpacity(tab.id) : 0;
  }

  private categoryBackdropOpacity(): number {
    const tabs: PinmonyHomeTab[] = this.pageTabs();
    if (!tabs.length) return 0;
    const selected: number = Math.max(0,tabs.findIndex((tab: PinmonyHomeTab): boolean => tab.id === this.selectedId));
    const position: number = Math.max(0,Math.min(tabs.length - 1,this.pagerPosition < 0 ? selected : this.pagerPosition));
    const first: number = Math.floor(position), next: number = Math.ceil(position), progress: number = position - first;
    return this.paneBackdropOpacity(first) * (1 - progress) + this.paneBackdropOpacity(next) * progress;
  }

  private updatePagerBackdrop(selected: number, index: number, position: number): void {
    if (index !== selected || !Number.isFinite(position)) return;
    this.pagerPosition = Math.max(0,Math.min(this.pageTabs().length - 1,index - position));
    this.syncPagerChrome();
    if (Math.abs(position) > 0.001 && Math.abs(position) < 0.999) { this.pagerMoving = true; this.suppressSwipeClick = true; }
  }

  private categoryTabSelected(index: number, tab: PinmonyHomeTab): boolean {
    if (this.pagerChromeIndex >= 0) {
      return index === this.pagerChromeIndex;
    }
    return tab.selected;
  }

  private syncPagerChrome(): void {
    const position: number = this.pagerPosition;
    const chromeIndex: number = position < 0 ? -1 : Math.round(position);
    if (this.pagerChromeIndex !== chromeIndex) this.pagerChromeIndex = chromeIndex;
    const bindingKey: string = position < 0 ? '' : Math.floor(position).toString() + ':' + Math.ceil(position).toString();
    if (bindingKey !== this.pagerBindingKey) {
      this.pagerBindingKey = bindingKey;
      this.pagerBindingRevision++;
    }
    this.chromeState.backdrop.moving = position >= 0;
    this.chromeState.backdrop.opacity = this.categoryBackdropOpacity();
  }

  private currentCategory(id: string): PinmonyHomeTab {
    return this.categories.find((tab: PinmonyHomeTab): boolean => tab.id === id) ??
      { id: id, label: '', selected: false, enabled: false };
  }

  private categorySelected(id: string): boolean {
    return this.categoryTabSelected(this.pageTabs().findIndex((tab: PinmonyHomeTab): boolean => tab.id === id),
      this.currentCategory(id));
  }

  private categoryMaterial(id: string): PinmonyHomeCategoryMaterial {
    let modifier: PinmonyHomeCategoryMaterial | undefined = this.categoryMaterials.get(id);
    if (!modifier) {
      modifier = new PinmonyHomeCategoryMaterial(this.immersiveLightMode, this.categorySelected(id), this.systemDarkMode);
      this.categoryMaterials.set(id, modifier);
    } else {
      modifier.update(this.immersiveLightMode, this.categorySelected(id), this.systemDarkMode);
    }
    return modifier;
  }

  @Builder
  private categoryButton(id: string) {
    Button(PinmonyI18n.render(this.currentCategory(id).label, this.uiLanguage), { type: ButtonType.Capsule })
      .height(36).padding({ left: 20, right: 20 }).fontSize(14).fontWeight(FontWeight.Medium)
      .backgroundColor(this.categorySelected(id) ? $r('app.color.detail_save_accent') : $r('app.color.input_surface'))
      .fontColor(this.categorySelected(id) ? Color.White : $r('app.color.primary_text'))
      .attributeModifier(this.categoryMaterial(id))
      .shadow({ radius: this.getUIContext().vp2px(6), color: this.systemDarkMode ? '#33000000' : '#14000000',
        offsetX: 0, offsetY: this.getUIContext().vp2px(1) })
      .enabled((this.interactionReady || this.offlinePreview) && this.currentCategory(id).enabled)
      .accessibilitySelected(this.categorySelected(id))
      .onClick(() => {
        const current: PinmonyHomeTab | undefined = this.categories.find((item: PinmonyHomeTab): boolean => item.id === id);
        if (current) this.selectTab(current);
      })
  }

  @Builder
  private categoryButtons() {
    Stack({alignContent:Alignment.TopStart}) {
      PinmonyHomeCategoryBackdrop({ state: this.chromeState.backdrop, topInset: this.homeTopInset() })
    Column() {
      if (this.categories.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.categories, (tab: PinmonyHomeTab) => {
              this.categoryButton(tab.id)
            }, (tab: PinmonyHomeTab) => tab.id)
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
          chromeOpacity: this.paneChromeOpacity(tab.id),
          paneActive: this.activePane(tab.id), suppressPinClick: this.suppressSwipeClick,
          imageRecovery: this.imageRecovery,
          mediaActive: this.mediaActive && this.activePane(tab.id),
          imageLoadingActive: this.imageLoadingActive && this.activePane(tab.id),
          prefetchedImageUrls: this.activePane(tab.id) ? this.prefetchedImageUrls : this.emptyPrefetchedImageUrls,
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
            this.updatePaneChrome(tab.id, collapsed);
          },
          onScrollPosition: (pageKey: string, offset: number, epoch: number) => this.rememberPosition(tab.id, pageKey, offset, epoch),
          onContentScroll: (offset: number, state: ScrollState) => {
            if (this.activePane(tab.id) && this.onContentScroll) this.onContentScroll(offset, state);
          },
          onPin: this.onPin, onMore: this.onMore, onHoldAction: this.onHoldAction, onBoard: this.onBoard,
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
      .onAnimationStart((index: number) => { if(this.pagerPosition < 0)this.pagerPosition = index; this.syncPagerChrome(); this.pagerMoving = true; this.suppressSwipeClick = true; })
      .onAnimationEnd(() => { this.pagerMoving = false; this.pagerPosition = -1; this.bindCurrentScroller(); this.syncPagerChrome(); })
      .onContentDidScroll((selected: number, index: number, position: number) => {
        this.updatePagerBackdrop(selected,index,position);
      })
      .onTouch((event: TouchEvent) => { if (event.type === TouchType.Down) this.suppressSwipeClick = false; })
      .width('100%').height('100%').clip(true)
  }

  private readonly categoryTitleBuilder: () => void = (): void => { this.categoryButtons(); };
  private cachedTitleBarMode: string = '';
  private cachedTitleBarOptions: HdsNavigationTitleBarOptions | undefined = undefined;

  private homeTitleBarOptions(): HdsNavigationTitleBarOptions {
    if (this.cachedTitleBarOptions && this.cachedTitleBarMode === this.immersiveLightMode) {
      return this.cachedTitleBarOptions;
    }
    this.cachedTitleBarMode = this.immersiveLightMode;
    const options: HdsNavigationTitleBarOptions = {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      style: {
        blurStrategy: this.immersiveLightMode !== 'off' ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
        thermoCtrl: this.immersiveLightMode !== 'off',
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightMode !== 'off',
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        // Radius sets the material appearance; scrollBinding activates it during a swipe.
        originalStyle: { backgroundStyle: { maskExtraHeight: 0, blurRadius: this.immersiveLightMode !== 'off' ? 18 : 0 } },
        scrollEffectStyle: { backgroundStyle: { maskExtraHeight: 0, blurRadius: this.immersiveLightMode !== 'off' ? 18 : 0 } },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)
      },
      content: { stackBuilder: this.categoryTitleBuilder }
    };
    this.cachedTitleBarOptions = options;
    return options;
  }


  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HdsNavigation() { this.categoryFeed() }
        .mode(NavigationMode.Stack)
        .width('100%').height('100%')
        .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
        .titleBar(this.homeTitleBarOptions())
        .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
          { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
        .bindToScrollable(this.scrollBinding())
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .clip(false)
      PinmonyBackToTopButton({ scrollOffsetVp: this.backToTopOffset, showButton: this.backToTopVisible && this.presentationActive && !this.pagerMoving &&
        (this.interactionReady || this.offlinePreview), onBackToTop: () => this.backToTop() })
    }.width('100%').height('100%').clip(true)
      .backgroundColor($r('app.color.page_background'))
  }
}
