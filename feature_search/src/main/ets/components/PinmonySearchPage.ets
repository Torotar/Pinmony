import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyImageSearchView, PinmonyImageSearchResult, PinmonyImageSearchItem, PinmonyImageCrop } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { effectKit } from '@kit.ArkGraphics2D';
import { PinmonyVideoCard } from 'common_ui';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonySearchQuizPanel } from './PinmonySearchQuizPanel';
import { ComponentContent } from '@kit.ArkUI';
import { buildPhotoMenu, PinmonyPhotoMenuOptions } from './PinmonyPhotoMenu';
import { PinmonyPhotoHistoryView } from './PinmonyPhotoHistoryPage';
import { PinmonyPhotoHistoryPage } from '../models/PinmonyPhotoHistory';
import { Chip, ChipSize } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavigation, HdsNavDestinationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySearchCategory, PinmonySearchResult, PinmonySearchSnapshot,
  PinmonySearchQuiz, PinmonySearchSuggestion, PinmonySearchHero, PinmonySearchIdea, PinmonySearchIdeaSection } from '../models/PinmonySearch';

@Component
export struct PinmonySearchPage {
  @State private photoMenuOpen: boolean = false;
  private photoMenuContent: ComponentContent<PinmonyPhotoMenuOptions> | undefined = undefined;
  @State private photoHistoryVisible: boolean = false;
  onPhotoHistory?: (cursor: string) => Promise<PinmonyPhotoHistoryPage>;
  onSelectPhotoHistory?: (id: string, onSelected: (uri: string) => void) => Promise<PinmonySearchResult[] | undefined>;
  private openPhotoHistory(): void {
    this.photoHistoryVisible = true;
    if (this.onPhotoVisibilityChange) this.onPhotoVisibilityChange(true);
    this.searchPathStack.pushPath({ name: 'photo-history' }, false);
  }
  private closePhotoHistory(): void {
    if (!this.photoHistoryVisible) return;
    this.photoHistoryVisible = false; this.photoGeneration++;
    if (this.searchPathStack.getAllPathName().includes('photo-history')) this.searchPathStack.pop(false);
    if (this.onPhotoCancel) this.onPhotoCancel();
    if (this.onPhotoVisibilityChange) this.onPhotoVisibilityChange(false);
  }
  private async selectPhotoHistory(id: string): Promise<void> {
    if (!this.onSelectPhotoHistory) return;
    const generation: number = ++this.photoGeneration;
    this.photoBusy = true; this.photoError = false; this.photoResults = [];
    try {
      const results: PinmonySearchResult[] | undefined = await this.onSelectPhotoHistory(id, (uri: string): void => {
        if (!this.active || generation !== this.photoGeneration) return;
        this.photoHistoryVisible = false; this.searchPathStack.pop(false);
        this.photoPreview = uri; this.searchPathStack.pushPath({ name: 'photo-search' }, false);
      });
      if (generation !== this.photoGeneration || !this.active) return;
      if (!results) throw new Error('history-selection');
      this.photoResults = results;
    } catch (error) {
      if (generation === this.photoGeneration && this.photoPreview) this.photoError = true;
      else throw new Error('history-selection');
    } finally { if (generation === this.photoGeneration) this.photoBusy = false; }
  }
  private async photoMenu(): Promise<void> {
    if (!this.active || !this.interactionReady || this.photoMenuOpen || this.photoBusy) return;
    this.photoMenuOpen = true;
    try {
      const options: PinmonyPhotoMenuOptions = { select: (index: number) => { this.selectPhotoMenu(index); } };
      if (!this.photoMenuContent) this.photoMenuContent = new ComponentContent(this.getUIContext(), wrapBuilder(buildPhotoMenu), options);
      await this.getUIContext().getPromptAction().openMenu(this.photoMenuContent, { id: 'pinmony-photo-search-menu' }, {
        onDisappear: () => { this.photoMenuOpen = false; }
      });
    } catch (_) { this.photoMenuOpen = false; }
  }
  private async selectPhotoMenu(index: number): Promise<void> {
    await this.dismissPhotoMenu();
    if (!this.active || !this.interactionReady || this.photoBusy) return;
    if (index === 0) this.startPhotoSearch();
    else if (index === 1) this.openPhotoHistory();
  }
  private async dismissPhotoMenu(): Promise<void> {
    if (this.photoMenuContent && this.photoMenuOpen) {
      try { await this.getUIContext().getPromptAction().closeMenu(this.photoMenuContent); }
      catch (_) { /* The system may already have dismissed the menu. */ }
    }
    this.photoMenuOpen = false;
  }
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  @State private photoPreview: string = '';
  @State private photoBusy: boolean = false;
  @State private photoError: boolean = false;
  @State private photoResults: PinmonySearchResult[] = [];
  private photoGeneration: number = 0;
  onPhotoSearch?: (onSelected?: (uri: string) => void) => Promise<PinmonySearchResult[] | undefined>;
  onPhotoCancel?: () => void;
  onPhotoResult?: (id: string) => void;
  onPhotoRegionSearch?: (crop: PinmonyImageCrop) => Promise<PinmonySearchResult[] | undefined>;

  private async searchPhotoRegion(crop: PinmonyImageCrop): Promise<void> {
    if (!this.active || !this.photoPreview || !this.onPhotoRegionSearch) return;
    const generation: number = ++this.photoGeneration;
    this.photoBusy = true; this.photoError = false; this.photoResults = [];
    try {
      const results: PinmonySearchResult[] | undefined = await this.onPhotoRegionSearch(crop);
      if (generation !== this.photoGeneration || !this.active) return;
      if (results) this.photoResults = results;
    } catch (_) {
      if (generation === this.photoGeneration && this.active) this.photoError = true;
    } finally {
      if (generation === this.photoGeneration) this.photoBusy = false;
    }
  }
  onPhotoVisibilityChange?: (visible: boolean) => void;

  private closePhotoSearch(): void {
    this.dismissPhotoMenu();
    if (this.photoHistoryVisible) this.closePhotoHistory();
    this.photoGeneration++;
    const wasVisible: boolean = !!this.photoPreview;
    this.photoPreview = '';
    if (wasVisible && this.onPhotoVisibilityChange) this.onPhotoVisibilityChange(false);
    if (wasVisible && this.searchPathStack.getAllPathName().includes('photo-search')) this.searchPathStack.pop(false);
    this.photoBusy = false;
    this.photoResults = [];
    if (this.onPhotoCancel) this.onPhotoCancel();
  }

  private async startPhotoSearch(): Promise<void> {
    if (!this.active || !this.interactionReady || this.photoBusy || !this.onPhotoSearch) return;
    const generation: number = ++this.photoGeneration;
    this.photoBusy = true; this.photoError = false; this.photoResults = [];
    try {
      const results: PinmonySearchResult[] | undefined = await this.onPhotoSearch((uri: string): void => {
        if (generation !== this.photoGeneration || !this.active) return;
        this.photoPreview = uri;
        if (this.onPhotoVisibilityChange) this.onPhotoVisibilityChange(true);
        this.searchPathStack.pushPath({ name: 'photo-search' }, false);
      });
      if (generation !== this.photoGeneration || !this.active) return;
      if (!results) { this.closePhotoSearch(); return; }
      this.photoResults = results;
    } catch (_) {
      if (generation === this.photoGeneration && this.active) this.photoError = true;
    } finally {
      if (generation === this.photoGeneration) this.photoBusy = false;
    }
  }

  private photoResult(): PinmonyImageSearchResult {
    return { pin: '', loading: this.photoBusy,
      error: this.photoError ? this.uiText('pm_photo_search_unconfirmed') : '', ended: true,
      items: this.photoResults.map((item: PinmonySearchResult): PinmonyImageSearchItem => ({ id: item.id, pinUrl: item.targetUrl,
        imageUrl: item.imageUrl, title: item.title, imageWidth: item.imageWidth, imageHeight: item.imageHeight })) };
  }
  @Builder
  private searchDestination(name?: string, param?: Object) {
    if (name === 'photo-history') {
      PinmonyPhotoHistoryView({ onLoad: this.onPhotoHistory,
        onConfirm: (id: string) => this.selectPhotoHistory(id), onClose: () => this.closePhotoHistory() })
    } else if (name === 'photo-search') {
      HdsNavDestination() {
        PinmonyImageSearchView({ imageUrl: this.photoPreview, uploadedPhoto: true, result: this.photoResult(),
          onSearch: (crop: PinmonyImageCrop) => { this.searchPhotoRegion(crop); },
          onClose: () => this.closePhotoSearch(),
          onRelated: (id: string) => {
            if (this.onPhotoResult) this.onPhotoResult(id);
            this.closePhotoSearch();
          }
        })
      }
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
        { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        content: { title: { mainTitle: this.uiText('pm_photo_search') },
          backIcon: { isEnabled: true, action: () => this.closePhotoSearch() } } })
      .onBackPressed(() => { this.closePhotoSearch(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor($r('app.color.page_background'))
    } else {
      this.searchRootDestination(name, param)
    }
  }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private searchPlaceholder(): string {
    const value: string = this.snapshot.placeholder || '';
    // Generic control copy follows app language; website ghost queries stay original.
    return !value || value === '搜索' || value === 'Search' ? this.uiText('pm_search_44ce7ae9') : PinmonyI18n.render(value, this.uiLanguage);
  }
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  private uiFormat(source: string, values: (string | number)[]): string { return PinmonyI18n.format(source, values, this.uiLanguage); }
  @Prop @Watch('activeChanged') active: boolean = true;
  @Prop automaticLoadingEnabled: boolean = true;
  @Prop @Watch('onSnapshotChanged') snapshot: PinmonySearchSnapshot = {} as PinmonySearchSnapshot;
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageProp('gestureBarHeightPx') private gestureBarHeightPx: number = 0;
  @Prop mediaActive: boolean = false;
  @Prop loading: boolean = false;
  @Prop refreshing: boolean = false;
  onRefresh?: () => void;
  @Prop error: string = '';
  @Prop resultsReadsReady: boolean = false;
  @Prop actionsReady: boolean = true;
  @Prop discoveryReadsReady: boolean = false;
  @Prop interactionReady: boolean = true;
  @Prop historyActionsReady: boolean = false;
  @Prop initialResultsScrollOffset: number = 0;
  @State private query: string = '';
  @State private quizSheetOpen: boolean = false;
  @State private entryQuiz: PinmonySearchQuiz | undefined = undefined;
  private readonly flowSections: WaterFlowSections = new WaterFlowSections();
  private flowShape: string = '';
  @State private contentWidth: number = 360;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 800;
  @State private failedImages: string[] = [];
  @State private upcomingImageUrls: string[] = [];
  private lastPrefetchResultCount: number = -1;
  @State private currentHeroIndex: number = 0;
  @Prop initialHeroId: string = '';
  private currentHeroId: string = '';
  onHeroPosition?: (pageKey: string, id: string) => void;
  private readonly inputController: SearchController = new SearchController();
  private readonly searchPathStack: NavPathStack = new NavPathStack();
  private pagePresent: boolean = false;
  private presentationTrace: string = '';

  private ensureSearchDestination(): void {
    if (!this.pagePresent || !this.active) return;
    if (this.searchPathStack.size() === 0) this.searchPathStack.pushPath({ name: 'pin-web-search' }, false);
  }

  private activeChanged(): void {
    if (!this.active) this.closePhotoSearch();
    if (!this.pagePresent) return;
    if (this.active) { this.restoreHeroPosition(); this.ensureSearchDestination(); }
    else this.searchPathStack.clear(false);
    this.tracePresentation();
  }

  private tracePresentation(): void {
    const state: string = 'active=' + this.active.toString() + ' stack=' + this.searchPathStack.size().toString() +
      ' kind=' + this.snapshot.kind + ' query=' + (!!this.committedQuery()).toString() +
      ' heroes=' + this.snapshot.heroes.length.toString() + ' sections=' + this.snapshot.ideaSections.length.toString() +
      ' results=' + this.snapshot.results.length.toString() + ' loading=' + this.loading.toString();
    if (state === this.presentationTrace) return;
    this.presentationTrace = state;
    PinmonyRuntimeLog.info('SearchUITrace: ' + state);
  }

  private readonly swiperController: SwiperController = new SwiperController();
  private readonly discoveryScroller: Scroller = new Scroller();
  private readonly resultsScroller: Scroller = new Scroller();
  private restoringResultsScroll: boolean = false;
  private resultsOffset: number = 0;
  private activeSession: number = 0;
  private activePage: string = '';
  private lastSnapshotQuery: string = '';
  @State private inputEditing: boolean = false;
  @State private categoriesCollapsed: boolean = false;
  private categoryScrollDistance: number = 0;

  private updateCategoriesOnScroll(offset: number, state: ScrollState): void {
    if (!this.active || this.inputEditing || this.restoringResultsScroll || this.refreshing ||
      !this.committedQuery() || state !== ScrollState.Scroll) return;
    const position = this.resultsScroller.offset();
    if (!position) return;
    if (position.yOffset <= 1) {
      this.categoryScrollDistance = 0;
      if (this.categoriesCollapsed) {
        this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.categoriesCollapsed = false;
        });
      }
      return;
    }
    if (!Number.isFinite(offset) || Math.abs(offset) < 0.1) return;
    if (this.categoryScrollDistance * offset < 0) this.categoryScrollDistance = 0;
    this.categoryScrollDistance += offset;
    if (Math.abs(this.categoryScrollDistance) < 20) return;
    const collapsed: boolean = this.categoryScrollDistance > 0;
    this.categoryScrollDistance = 0;
    if (collapsed === this.categoriesCollapsed) return;
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.categoriesCollapsed = collapsed;
    });
  }
  private initialFillCount: number = 0;
  private initialFillScheduled: boolean = false;
  private resultsViewportReady: boolean = false;
  private initialFillResultsCount: number = -1;
  private fillGeneration: number = 0;
  onQueryChange?: (value: string, refreshSuggestions?: boolean) => void;
  onSubmit?: (value: string) => void;
  onInputFocusChange?: (focused: boolean, stopEditing: () => void) => void;
  onHistoryReturnReady?: (openHistory?: () => void) => void;
  onCategory?: (id: string) => void;
  onSuggestion?: (id: string) => void;
  onDeleteHistory?: (id: string) => void;
  onResult?: (targetUrl: string) => void;
  onMore?: (targetUrl: string) => void;
  onExploreAction?: (id: string, kind: string) => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onBack?: () => void;
  onClearProductFilter?: (kind: string) => void;
  onFollowUser?: (id: string) => void;
  onFollowBoard?: (id: string) => void;
  onFilters?: () => void;
  onQuizAction?: (kind: string, id: string) => void;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onResultsScrollPosition?: (pageKey: string, offset: number) => void;

  aboutToAppear(): void {
    if (this.onHistoryReturnReady) this.onHistoryReturnReady(() => this.openSearchHistory());
    this.restoreHeroPosition();
    this.restoringResultsScroll = this.initialResultsScrollOffset > 0;
    this.pagePresent = true;
    this.ensureSearchDestination();
    this.activeSession = this.snapshot.session;
    this.activePage = this.snapshot.pageKey;
    this.query = this.committedQuery();
    this.lastSnapshotQuery = this.snapshot.query || '';
    this.syncQuizPresentation();
    this.fillInitialViewport();
    this.tracePresentation();
  }

  private restoreResultsScroll(): void {
    const offset: number = Math.max(0, this.initialResultsScrollOffset);
    setTimeout(() => {
      try {
        const scroller: Scroller = this.snapshot.query ? this.resultsScroller : this.discoveryScroller;
        scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
      } catch (error) {
        console.warn('Pinmony: search scroll restoration unavailable');
      }
      this.restoringResultsScroll = false;
    }, 0);
  }

  private reportResultsScroll(): void {
    if (this.restoringResultsScroll) return;
    try {
      const scroller: Scroller = this.snapshot.query ? this.resultsScroller : this.discoveryScroller;
      const position = scroller.offset();
      if (!position) return;
      this.resultsOffset = Math.max(0, position.yOffset);
      if (this.onResultsScrollPosition) this.onResultsScrollPosition(this.snapshot.pageKey, this.resultsOffset);
    } catch (error) {
      console.warn('Pinmony: search scroll position unavailable');
    }
  }

  aboutToDisappear(): void {
    this.closePhotoSearch();
    if (this.onHistoryReturnReady) this.onHistoryReturnReady(undefined);
    this.pagePresent = false;
    this.fillGeneration++;
    this.resultsViewportReady = false;
    this.initialFillScheduled = false;
    this.searchPathStack.clear();
  }

  private onSnapshotChanged(): void {
    this.ensureSearchDestination();
    this.tracePresentation();
    if (this.activeSession !== this.snapshot.session || this.activePage !== this.snapshot.pageKey) {
      const changedPage: boolean = this.activePage !== this.snapshot.pageKey;
      this.activeSession = this.snapshot.session;
      this.activePage = this.snapshot.pageKey;
      this.categoriesCollapsed = false;
      this.categoryScrollDistance = 0;
      if (changedPage) {
        this.closePhotoSearch();
        // A committed route replaces the editing intent, even while HDS stays mounted.
        if (this.inputEditing) this.closeInputPanel(false);
        this.upcomingImageUrls = [];
        this.lastPrefetchResultCount = -1;
        this.entryQuiz = undefined;
        this.failedImages = [];
        this.currentHeroIndex = 0;
        this.currentHeroId = '';
      }
      this.initialFillCount = 0;
      this.fillGeneration++;
      this.initialFillScheduled = false;
      this.resultsViewportReady = false;
      this.initialFillResultsCount = -1;
    }
    const nextQuery: string = this.snapshot.query || '';
    if (nextQuery !== this.lastSnapshotQuery) {
      this.lastSnapshotQuery = nextQuery;
      if (!this.inputEditing) this.query = this.committedQuery();
    }
    if (this.currentHeroIndex >= this.snapshot.heroes.length) this.currentHeroIndex = 0;
    this.restoreHeroPosition();
    this.syncQuizPresentation();
    this.fillInitialViewport();
  }

  private syncQuizPresentation(): void {
    const quiz: PinmonySearchQuiz | undefined = this.snapshot.quiz;
    if (!quiz) this.entryQuiz = undefined;
    else if (quiz.mode === 'entry') this.entryQuiz = quiz;
    this.quizSheetOpen = !!quiz && quiz.mode !== 'entry';
    const shape: string = (this.entryQuiz ? '1:' : '0:') + this.snapshot.results.length.toString() + ':' + this.contentColumns().toString();
    if (shape !== this.flowShape) {
      this.flowShape = shape;
      const sections: SectionOptions[] = [];
      if (this.entryQuiz) sections.push({ itemsCount: 1, crossCount: 1, margin: { left: 0, right: 0, bottom: 12 } });
      sections.push({ itemsCount: this.snapshot.results.length, crossCount: this.contentColumns(), columnsGap: 12, rowsGap: 12 });
      this.flowSections.splice(0, this.flowSections.length(), sections);
    }
  }

  @Builder
  private quizSheet() {
    if (this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry') {
      PinmonySearchQuizPanel({ quiz: this.snapshot.quiz,
        onAction: (kind: string, id: string) => { if (this.onQuizAction) this.onQuizAction(kind, id); },
        onPin: (url: string) => { if (this.onResult) this.onResult(url); } })
    }
  }

  @Builder
  private inspirationEntry() {
    if (this.entryQuiz) {
      PinmonySearchQuizPanel({ quiz: this.entryQuiz,
        onAction: (kind: string, id: string) => { if (this.onQuizAction) this.onQuizAction(kind, id); } })
    }
  }

  private fillInitialViewport(): void {
    if (!this.automaticLoadingEnabled) return;
    if (this.initialFillScheduled || this.initialFillCount >= 3 || this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry') return;
    const discovery: boolean = !this.snapshot.query.trim();
    const needsMore: boolean = discovery ? this.snapshot.discoveryApi === true &&
      this.snapshot.discoveryActive === true && !this.snapshot.discoveryBusy && !this.snapshot.discoveryEnded &&
      !this.snapshot.discoveryError && this.snapshot.ideaSections.length < 6 : this.snapshot.api === true &&
      !this.snapshot.apiBusy && !this.snapshot.apiEnded && !this.snapshot.apiError &&
      this.snapshot.results.length > 0 && this.resultsViewportReady &&
      this.initialFillResultsCount !== this.snapshot.results.length;
    if (!needsMore || !this.onLoadMore) return;
    this.initialFillScheduled = true;
    const page: string = this.snapshot.pageKey;
    const generation: number = this.fillGeneration;
    setTimeout(() => {
      if (generation !== this.fillGeneration) return;
      this.initialFillScheduled = false;
      if (!this.automaticLoadingEnabled || this.snapshot.pageKey !== page || !(this.actionsReady || this.resultsReadsReady || discovery && this.discoveryReadsReady) ||
          this.loading || this.restoringResultsScroll || !this.onLoadMore) return;
      if (!discovery) {
        if (this.snapshot.apiBusy || this.snapshot.apiEnded || this.snapshot.apiError || !this.resultsViewportReady) return;
        try {
          const position = this.resultsScroller.offset();
          if (!position || !this.resultsScroller.isAtEnd() || position.yOffset > 1) return;
        } catch (_) { return; }
        this.initialFillResultsCount = this.snapshot.results.length;
      }
      this.initialFillCount++;
      PinmonyRuntimeLog.info('SearchPagination: source=viewport-fill count=' + this.initialFillCount.toString() +
        ' results=' + this.snapshot.results.length.toString());
      this.onLoadMore();
    }, 32);
  }

  private resultsReachEnd(): void {
    if (!this.automaticLoadingEnabled || !(this.actionsReady || this.resultsReadsReady) || this.loading || this.snapshot.apiBusy ||
        this.snapshot.apiEnded || this.snapshot.apiError || this.restoringResultsScroll || !this.onLoadMore) return;
    try {
      const position = this.resultsScroller.offset();
      if (!position) return;
      if (position.yOffset <= 1) { this.fillInitialViewport(); return; }
      if (!this.resultsScroller.isAtEnd()) return;
    } catch (_) { return; }
    PinmonyRuntimeLog.info('SearchPagination: source=scroll-end results=' + this.snapshot.results.length.toString());
    this.onLoadMore();
  }

  private resultsVisible(first: number, last: number): void {
    if (!this.automaticLoadingEnabled || !this.committedQuery() || !(this.actionsReady || this.resultsReadsReady) || this.restoringResultsScroll) return;
    const cardLast: number = Math.max(0, last - (this.entryQuiz ? 1 : 0));
    const urls: string[] = this.snapshot.results.slice(cardLast + 1, cardLast + 9)
      .filter((item: PinmonySearchResult): boolean => !!item.imageUrl && !item.video)
      .map((item: PinmonySearchResult): string => item.imageUrl);
    if (urls.join('|') !== this.upcomingImageUrls.join('|')) this.upcomingImageUrls = urls;
    if (this.loading || this.snapshot.apiBusy || this.snapshot.apiEnded || this.snapshot.apiError ||
        !this.onLoadMore || first < 0 || this.snapshot.results.length - cardLast - 1 > 4 ||
        this.lastPrefetchResultCount === this.snapshot.results.length) return;
    this.lastPrefetchResultCount = this.snapshot.results.length;
    this.onLoadMore();
  }

  private resultsAreaChanged(area: Area): void {
    const width: number = Number(area.width);
    if (width > 0 && Math.abs(width - this.contentWidth) > 1) {
      this.contentWidth = width;
      this.syncQuizPresentation();
    }
    this.resultsViewportReady = Number(area.width) > 0 && Number(area.height) > 0;
    this.fillInitialViewport();
  }

  private imageFailed(url: string): boolean {
    return !url || this.failedImages.indexOf(url) >= 0;
  }

  private markImageFailed(url: string): void {
    if (url && this.failedImages.indexOf(url) < 0) {
      this.failedImages = [...this.failedImages, url];
    }
  }

  private wideDiscoveryLayout(): boolean {
    return this.viewportWidth >= 600;
  }

  private discoveryColumns(): number {
    return !this.wideDiscoveryLayout() ? 1 : Math.max(2, Math.floor(this.contentWidth / 520));
  }

  private discoverySlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.discoveryColumns(); i++) slots.push(i);
    return slots;
  }

  private discoveryRows(): number[] {
    const rows: number[] = [];
    for (let i: number = 0; i < this.snapshot.ideaSections.length; i += this.discoveryColumns()) rows.push(i);
    return rows;
  }

  @State private heroBackgrounds: Record<string, string> = {};
  private heroColorPending: Set<string> = new Set<string>();

  private heroBackground(hero: PinmonySearchHero): ResourceColor {
    return this.heroBackgrounds[hero.imageUrl] || $r('app.color.surface_muted');
  }

  private heroTextColor(hero: PinmonySearchHero): ResourceColor {
    return this.heroBackgrounds[hero.imageUrl] ? '#1B1E25' : $r('app.color.primary_text');
  }

  private async updateHeroBackground(hero: PinmonySearchHero): Promise<void> {
    const url: string = hero.imageUrl;
    if (!this.active || this.heroBackgrounds[url] || this.heroColorPending.has(url)) return;
    this.heroColorPending.add(url);
    try {
      const pixels = await this.getUIContext().getComponentSnapshot().get('search-hero-' + hero.id);
      try {
        const picker = await effectKit.createColorPicker(pixels);
        const color = await picker.getMainColor();
        if (!this.active || !this.snapshot.heroes.some((item: PinmonySearchHero): boolean => item.imageUrl === url)) return;
        const red: number = Math.round(color.red * 0.24 + 255 * 0.76);
        const green: number = Math.round(color.green * 0.24 + 255 * 0.76);
        const blue: number = Math.round(color.blue * 0.24 + 255 * 0.76);
        const next: Record<string, string> = {};
        this.snapshot.heroes.slice(0, 80).forEach((item: PinmonySearchHero): void => {
          if (this.heroBackgrounds[item.imageUrl]) next[item.imageUrl] = this.heroBackgrounds[item.imageUrl];
        });
        next[url] = '#' + red.toString(16).padStart(2, '0') + green.toString(16).padStart(2, '0') + blue.toString(16).padStart(2, '0');
        this.heroBackgrounds = next;
      } finally { await pixels.release(); }
    } catch (_) {
      // Keep the theme surface when the rendered image cannot be sampled.
    } finally { this.heroColorPending.delete(url); }
  }

  private wideHeroImageSize(): number {
    return Math.max(1, Math.min(this.heroCarouselHeight() - 36, this.contentWidth * (this.viewportWidth > this.viewportHeight ? 0.36 : 0.45)));
  }

  private heroCarouselHeight(): number {
    return !this.wideDiscoveryLayout() ? 390 : Math.min(600, this.contentWidth * (this.viewportWidth > this.viewportHeight ? 0.38 : 0.50) + (this.viewportWidth > this.viewportHeight ? 0 : 24));
  }

  private contentColumns(): number {
    return Math.max(2, Math.floor((this.contentWidth - 32 + 12) / 192));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.contentColumns(); i++) slots.push(i);
    return slots;
  }

  private contentColumnsTemplate(): string {
    return this.columnSlots().map((): string => '1fr').join(' ');
  }

  private imageHeight(result: PinmonySearchResult): number {
    const width: number = Math.max(130, (this.contentWidth - 32 - (this.contentColumns() - 1) * 12) / this.contentColumns());
    if (result.imageWidth <= 0 || result.imageHeight <= 0) return width * 1.2;
    return width * Math.max(0.55, Math.min(3.2, result.imageHeight / result.imageWidth));
  }

  private allPins(): boolean {
    return this.snapshot.results.length > 0 && this.snapshot.results.every((result: PinmonySearchResult): boolean =>
      result.kind === 'pin');
  }

  private visibleCategories(): PinmonySearchCategory[] {
    return this.snapshot.categories.filter((item: PinmonySearchCategory): boolean =>
      !/^(?:show |all )?(?:filters?|显示筛选器|筛选器|顯示篩選器|篩選器)$/i.test(item.label.trim()));
  }

  @Builder
  private categoryChip(item: PinmonySearchCategory) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        if (item.imageUrl) { Image(item.imageUrl).width(44).height(44).objectFit(ImageFit.Cover) }
        Text(PinmonyI18n.render(item.label, this.uiLanguage)).fontSize(14).fontColor($r('app.color.primary_text')).padding({ right: 12, left: item.imageUrl ? 0 : 12 })
      }.height(44)
    }.padding(0).borderRadius(16).clip(true).backgroundColor($r('app.color.surface_muted'))
      .accessibilityText(item.label).accessibilitySelected(item.selected)
      .enabled(this.interactionReady && item.enabled && !this.loading)
      .onClick(() => { if (this.onCategory) this.onCategory(item.id); })
  }

  @Builder
  private suggestionChip(item: PinmonySearchSuggestion) {
    Chip({
      label: { text: item.label, fontSize: 14 },
      size: ChipSize.NORMAL,
      allowClose: false,
      activated: false,
      backgroundColor: $r('app.color.surface_muted'),
      borderRadius: 18,
      onClicked: () => {
        if (this.interactionReady && item.enabled && !this.loading && this.onSuggestion) this.onSuggestion(item.id);
      },
      accessibilityDescription: this.uiFormat("pm_search_value_1c227be4", [item.label])
    })
  }

  @Builder
  private heroSlide(hero: PinmonySearchHero) {
    Stack() {
      if (this.wideDiscoveryLayout()) {
        Row() {
          Column() {
            if (this.imageFailed(hero.imageUrl)) {
              Text(this.uiText("pm_image_failed_to_load_572993f5")).fontSize(14).fontColor($r('app.color.secondary_text'))
            } else {
              Image(hero.imageUrl).id('search-hero-' + hero.id).width('100%').height('100%').objectFit(ImageFit.Cover)
                .onComplete((event) => { if (event?.loadingStatus === 1) this.updateHeroBackground(hero); })
                .accessibilityText(hero.title).onError(() => this.markImageFailed(hero.imageUrl))
            }
          }.width(this.wideHeroImageSize()).height(this.wideHeroImageSize())
            .borderRadius(32).clip(true).justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.surface_muted'))
          Column({ space: 12 }) {
            if (hero.subtitle) {
              Text(PinmonyI18n.render(hero.subtitle, this.uiLanguage)).fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(this.heroTextColor(hero)).textAlign(TextAlign.Center).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            Text(PinmonyI18n.render(hero.title, this.uiLanguage)).fontSize(26).fontWeight(FontWeight.Bold)
              .fontColor(this.heroTextColor(hero)).textAlign(TextAlign.Center).maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).padding({ left: 32, right: 32 })
            .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        }.width('100%').height('100%').padding({ left: this.contentWidth * 0.04, right: this.contentWidth * 0.04 })
          .alignItems(VerticalAlign.Center).backgroundColor(this.heroBackground(hero))
      } else {
    Stack({ alignContent: Alignment.Top }) {
      if (this.imageFailed(hero.imageUrl)) {
        Column() {
          Text(this.uiText("pm_image_failed_to_load_572993f5"))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
      } else {
        Image(hero.imageUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .accessibilityText(hero.title)
          .onError(() => this.markImageFailed(hero.imageUrl))
      }
      Column({ space: 6 }) {
          if (hero.subtitle) {
            Text(PinmonyI18n.render(hero.subtitle, this.uiLanguage))
              .fontSize(14)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          Text(PinmonyI18n.render(hero.title, this.uiLanguage))
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 26, right: 26 })
        .backgroundColor('rgba(0, 0, 0, 0.30)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .clip(true)
      }
    }.width('100%').height('100%').clip(true)
    .accessibilityText(hero.title + (hero.subtitle ? '，' + hero.subtitle : ''))
    .onClick(() => {
      if (hero.enabled && this.onExploreAction) {
        this.selectHeroPosition(this.snapshot.heroes.findIndex((item: PinmonySearchHero): boolean => item.id === hero.id));
        this.onExploreAction(hero.id, 'hero');
      }
    })
  }

  private restoreHeroPosition(): void {
    const id: string = this.currentHeroId || this.initialHeroId;
    const index: number = this.snapshot.heroes.findIndex((hero: PinmonySearchHero): boolean => hero.id === id);
    this.currentHeroIndex = index >= 0 ? index : Math.max(0, Math.min(this.currentHeroIndex, this.snapshot.heroes.length - 1));
    // Keep the identity through transient empty loading snapshots.
    if (this.snapshot.heroes.length > 0) this.currentHeroId = this.snapshot.heroes[this.currentHeroIndex].id;
  }

  private selectHeroPosition(index: number): void {
    if (!this.active || !Number.isInteger(index) || index < 0 || index >= this.snapshot.heroes.length) return;
    this.currentHeroIndex = index;
    this.currentHeroId = this.snapshot.heroes[index].id;
    if (this.onHeroPosition) this.onHeroPosition(this.snapshot.pageKey, this.currentHeroId);
  }

  @Builder
  private heroCarousel() {
    Swiper(this.swiperController) {
      ForEach(this.snapshot.heroes, (hero: PinmonySearchHero) => {
        Column() {
          Column() { this.heroSlide(hero) }.width('100%').height(this.heroCarouselHeight())
        }.width('100%').height('100%')
      }, (hero: PinmonySearchHero) => hero.id)
    }
    .width('100%')
    .height(this.heroCarouselHeight() + 38)
    // Native stretching dots match the multi-image Pin indicator.
    // Reserve 38vp below the image for the indicator.
    .index(this.currentHeroIndex)
    .indicator(Indicator.dot().bottom(4)
      .itemWidth(7).itemHeight(7).selectedItemWidth(9).selectedItemHeight(9)
      .color($r('app.color.secondary_text')).selectedColor($r('app.color.primary_text')))
    .autoPlay(this.active && this.snapshot.heroes.length > 1)
    .interval(4800)
    .loop(this.snapshot.heroes.length > 1)
    .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
    .onChange((index: number) => this.selectHeroPosition(index))
    .accessibilityText(this.uiText("pm_image_6fd6014d") + (this.currentHeroIndex + 1) + this.uiText("pm_of_0cad3498") + this.snapshot.heroes.length + this.uiText("pm_featured_images_0c27f683"))
  }

  @Builder
  private ideaCard(item: PinmonySearchIdea) {
    Stack() {
      if (this.imageFailed(item.imageUrl)) {
        Column() {
          Text(this.uiText("pm_image_failed_to_load_572993f5"))
            .fontSize(10)
            .fontColor($r('app.color.secondary_text'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(176)
        .borderRadius(8)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
      } else {
        Image(item.imageUrl)
          .width('100%')
          .height(176)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .clip(true)
          .accessibilityLevel('no')
          .onError(() => this.markImageFailed(item.imageUrl))
      }
    }
    .width('100%')
    .height(176)
    .accessibilityText(item.title + this.uiText("pm_open_recommended_idea_cfa1d1fd"))
    .onClick(() => {
      if (item.enabled && this.onExploreAction) this.onExploreAction(item.id, 'idea');
    })
  }

  private ideaEyebrowLabel(section: PinmonySearchIdeaSection): string {
    return section.eyebrow;
  }

  @Builder
  private ideaSection(section: PinmonySearchIdeaSection) {
    Column({ space: 8 }) {
      if (this.ideaEyebrowLabel(section)) {
        Text(this.ideaEyebrowLabel(section))
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Row({ space: 8 }) {
        Text(PinmonyI18n.render(section.title, this.uiLanguage))
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (section.actionId) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_chevron_left'))
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
              .scale({ x: -1, y: 1 })
          }
          .width(34)
          .height(34)
          .padding(0)
          .backgroundColor($r('app.color.surface_muted'))
          .accessibilityText(this.uiFormat("pm_view_all_of_value_946da294", [section.title]))
          .onClick(() => {
            if (this.onExploreAction) this.onExploreAction(section.actionId, 'ideaSection');
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Grid() {
        ForEach(section.items, (item: PinmonySearchIdea) => {
          GridItem() {
            this.ideaCard(item)
          }
          .height(176)
        }, (item: PinmonySearchIdea) => item.id)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(6)
      .rowsGap(12)
      .width('100%')
      .height(Math.max(0, Math.ceil(section.items.length / 4) * 188 - 12))
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 26 })
  }

  @Builder
  private discoveryEmpty() {
    Column({ space: 8 }) {
      Text(this.uiText("pm_no_discovery_content_available_6ab3cb41"))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
      Text(this.uiText("pm_the_current_pinterest_page_has_no_supported_featured_images_or_r_e04c587f"))
        .fontSize(14)
        .fontColor($r('app.color.secondary_text'))
        .textAlign(TextAlign.Center)
      Button(this.uiText("pm_reload_df7392cc"))
        .height(40)
        .padding({ left: 18, right: 18 })
        .onClick(() => { if (this.onRetry) this.onRetry(); })
        .accessibilityText(this.uiText("pm_reload_pinterest_discovery_content_f7efbeaf"))
    }
    .width('100%')
    .height(240)
    .padding({ left: 24, right: 24 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private searchLoadingState() {
    Column({ space: 12 }) {
      LoadingProgress().width(32).height(32).color($r('app.color.accent'))
      Text(this.uiText("pm_loading_search_content_41fcd6d9")).fontSize(14).fontColor($r('app.color.secondary_text'))
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private discoveryContent() {
    if (this.discoveryInitialLoading()) {
      this.searchLoadingState()
    } else {
    Scroll(this.discoveryScroller) {
      Column({ space: 0 }) {
        if (this.snapshot.heroes.length > 0) {
          this.heroCarousel()
        }
        ForEach(this.discoveryRows(), (start: number) => {
          Row() {
            ForEach(this.discoverySlots(), (slot: number) => {
              Column() {
                if (start + slot < this.snapshot.ideaSections.length) {
                  this.ideaSection(this.snapshot.ideaSections[start + slot])
                }
              }.layoutWeight(1)
            }, (slot: number) => slot.toString())
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (start: number) => this.discoveryColumns().toString() + ':' + start.toString())
        if (this.snapshot.discoveryApi) {
          Column({ space: 10 }) {
            if (this.snapshot.discoveryError) {
              Text(PinmonyI18n.render(this.snapshot.discoveryError, this.uiLanguage))
                .fontSize(14)
                .fontColor($r('app.color.secondary_text'))
              Button(this.uiText("pm_retry_b8784c8d"))
                .onClick(() => {
                  if (this.snapshot.discoveryActive) {
                    if (this.onLoadMore) this.onLoadMore();
                  } else if (this.onRetry) this.onRetry();
                })
            } else if (!this.snapshot.discoveryBusy && this.snapshot.discoveryActive && this.snapshot.ideaSections.length === 0) {
              Text(this.uiText("pm_no_suggested_topics_yet_15697bb3"))
                .fontSize(14)
                .fontColor($r('app.color.secondary_text'))
            }
          }
          .width('100%')
          .padding(16)
        } else if (this.snapshot.heroes.length === 0 && this.snapshot.ideaSections.length === 0) {
          this.discoveryEmpty()
        }
      }
      .width('100%')
      .padding({ top: this.snapshot.heroes.length === 0 ? 72 : 0, bottom: 112 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onAppear(() => this.restoreResultsScroll())
    .onDidScroll((_xOffset: number, offset: number, state: ScrollState) => {
          this.reportResultsScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
    .onScrollStop(() => this.reportResultsScroll())
    .onReachEnd(() => {
      if (this.automaticLoadingEnabled && (this.actionsReady || this.discoveryReadsReady) && this.snapshot.discoveryApi && !this.snapshot.discoveryBusy &&
          !this.snapshot.discoveryError && !this.snapshot.discoveryEnded && this.onLoadMore) this.onLoadMore();
    })
    }
  }

  private discoveryInitialLoading(): boolean {
    if (this.discoveryReadsReady && !this.snapshot.discoveryBusy) return false;
    if (this.snapshot.heroes.length > 0 || this.snapshot.ideaSections.length > 0 ||
        this.error || this.snapshot.discoveryError || this.snapshot.apiError) return false;
    return this.loading || this.snapshot.kind === 'loading' || this.snapshot.session === 0 ||
      this.snapshot.discoveryBusy === true ||
      (this.snapshot.discoveryApi === true && this.snapshot.discoveryActive !== true);
  }

  private pinCardHeight(result: PinmonySearchResult): number {
    let height: number = this.imageHeight(result);
    if (result.title && result.title !== '标题暂不可用') height += 8 + 40;
    if (result.merchant) height += 8 + 18;
    if (result.price) height += 8 + 20;
    if (result.kind === 'pin') height += 8 + 32;
    return height;
  }

  @Builder
  private pinCard(result: PinmonySearchResult) {
    Column({ space: 8 }) {
      if (result.video) {
        PinmonyVideoCard({ video: result.video, poster: result.imageUrl, active: this.mediaActive && (this.actionsReady || this.resultsReadsReady) && !this.quizSheetOpen })
          .width('100%').height(this.imageHeight(result))
          .id('pinmony-search-photo-' + result.targetUrl)
          .onClick(() => {
            if (this.interactionReady && result.enabled && this.onResult) this.onResult(result.targetUrl);
          })
      } else if (this.failedImages.indexOf(result.imageUrl) >= 0 || !result.imageUrl) {
        Column() {
          Text(result.imageUrl ? this.uiText("pm_image_failed_to_load_572993f5") : this.uiText("pm_no_preview_image_baafb7eb"))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height(this.imageHeight(result))
        .borderRadius(18)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
        .accessibilityText(result.title + (result.imageUrl ? this.uiText("pm_image_failed_to_load_75349c88") : this.uiText("pm_no_preview_image_c39e69a8")))
      } else {
        Image(result.imageUrl)
          .id('pinmony-search-photo-' + result.targetUrl)
          .width('100%')
          .height(this.imageHeight(result))
          .objectFit(ImageFit.Cover)
          .borderRadius(18)
          .clip(true)
          .accessibilityLevel('no')
          .onError(() => {
            if (this.failedImages.indexOf(result.imageUrl) < 0) {
              this.failedImages = [...this.failedImages, result.imageUrl];
            }
          })
      }
      if (result.title && result.title !== '标题暂不可用') {
      Text(PinmonyI18n.render(result.title, this.uiLanguage))
        .fontSize(15)
        .height(40).lineHeight(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      }
      if (result.merchant) {
        Text(result.merchant).height(18).lineHeight(18).fontSize(13).fontColor($r('app.color.secondary_text')).width('100%').maxLines(1)
      }
      if (result.price) {
        Row({ space: 6 }) {
          Text(result.price).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          if (result.standardPrice && result.standardPrice !== result.price) {
            Text(result.standardPrice).fontSize(13).decoration({ type: TextDecorationType.LineThrough }).fontColor($r('app.color.secondary_text'))
          }
        }.width('100%').height(20)
      }
      if (result.kind === 'pin') {
        Row() {
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(20).height(20)
              .fillColor($r('app.color.primary_text'))
          }.width(32).height(32).backgroundColor(Color.Transparent)
            .enabled(this.interactionReady && result.enabled)
            .onClick(() => {
              if (this.onMore) this.onMore(result.targetUrl);
            }).accessibilityText(this.uiText("pm_pin_options_7227a477"))
        }.width('100%').height(32).flexShrink(0)
      }
    }
    .width('100%')
    .height(this.pinCardHeight(result))
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(result.title + this.uiText("pm_open_search_result_143231c5"))
    .onClick(() => { if (result.enabled && this.onResult) this.onResult(result.targetUrl); })
  }

  @Builder
  private boardResult(result: PinmonySearchResult) {
    Column({ space: 8 }) {
      Row({ space: 2 }) {
        if (result.imageUrl) {
          Image(result.boardImages?.[0] || result.imageUrl).layoutWeight(2).height('100%').objectFit(ImageFit.Cover)
        }
        if ((result.boardImages?.length || 0) > 1) {
          Column({ space: 2 }) {
            Image(result.boardImages![1]).width('100%').layoutWeight(1).objectFit(ImageFit.Cover)
            if ((result.boardImages?.length || 0) > 2) {
              Image(result.boardImages![2]).width('100%').layoutWeight(1).objectFit(ImageFit.Cover)
            }
          }.layoutWeight(1).height('100%')
        }
      }.width('100%').aspectRatio(1.5).borderRadius(14).clip(true).backgroundColor($r('app.color.surface_muted'))
      Text(PinmonyI18n.render(result.title, this.uiLanguage)).fontSize(16).fontWeight(FontWeight.Bold).maxLines(2)
        .fontColor($r('app.color.primary_text'))
      if (result.ownerName) {
        Text(result.ownerName).fontSize(13).fontColor($r('app.color.primary_text')).maxLines(1)
      }
      if (result.subtitle || result.updated) {
        Text(PinmonyI18n.render([result.subtitle, result.updated].filter((value: string | undefined): boolean => !!value).join(' · '), this.uiLanguage)).fontSize(13).fontColor($r('app.color.secondary_text')).maxLines(2)
      }
      Button(result.followBusy ? this.uiText("pm_processing_d3d21191") : result.following === true ? this.uiText("pm_following_7dfa5d8f") : this.uiText("pm_follow_eb137dee"), { type: ButtonType.Normal })
        .border({ width: 0 })
        .height(36).borderRadius(16).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
        .enabled(this.interactionReady && result.canFollow === true && !result.followBusy)
        .accessibilityText(result.followBusy ? this.uiText("pm_submitting_board_follow_action_882403f9") : result.following ? this.uiText("pm_unfollow_board_ac069feb") : this.uiText("pm_follow_board_3813420f"))
        .onClick(() => { if (this.interactionReady && result.canFollow && this.onFollowBoard) this.onFollowBoard(result.id); })
    }.width('100%').alignItems(HorizontalAlign.Start)
      .onClick(() => { if (this.interactionReady && result.enabled && this.onResult) this.onResult(result.targetUrl); })
  }

  @Builder
  private resultRow(result: PinmonySearchResult) {
    Row({ space: 14 }) {
      if (result.kind === 'profile' || result.kind === 'user') {
        PinmonyUserAvatar({ image: result.imageUrl, name: result.title, avatarSize: 58 }).accessibilityLevel('no')
      } else if (result.imageUrl && this.failedImages.indexOf(result.imageUrl) < 0) {
        Image(result.imageUrl)
          .width((result.kind === 'profile' || result.kind === 'user') ? 58 : 74)
          .height((result.kind === 'profile' || result.kind === 'user') ? 58 : 74)
          .borderRadius((result.kind === 'profile' || result.kind === 'user') ? 29 : 14)
          .objectFit(ImageFit.Cover)
          .accessibilityLevel('no')
          .onError(() => {
            if (this.failedImages.indexOf(result.imageUrl) < 0) {
              this.failedImages = [...this.failedImages, result.imageUrl];
            }
          })
      } else {
        Column() {
          Text(result.title.slice(0, 1))
            .fontSize(22)
            .fontColor($r('app.color.secondary_text'))
        }
        .width((result.kind === 'profile' || result.kind === 'user') ? 58 : 74)
        .height((result.kind === 'profile' || result.kind === 'user') ? 58 : 74)
        .borderRadius((result.kind === 'profile' || result.kind === 'user') ? 29 : 14)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
        .accessibilityLevel('no')
      }
      Column({ space: 4 }) {
        Text(PinmonyI18n.render(result.title, this.uiLanguage))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (result.kind === 'user' && result.followerCount !== undefined) {
          Text(result.followerCount.toString() + this.uiText("pm_followers_b06be4eb")).fontSize(13).fontColor($r('app.color.secondary_text'))
        } else if (result.subtitle) {
          Text(PinmonyI18n.render(result.subtitle, this.uiLanguage))
            .fontSize(13)
            .fontColor($r('app.color.secondary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(result.followBusy ? this.uiText("pm_processing_d3d21191") : result.following ? this.uiText("pm_following_7dfa5d8f") : this.uiText("pm_follow_eb137dee"), { type: ButtonType.Normal })
        .border({ width: 0 }).borderRadius(16)
        .height(44).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
        .enabled(this.interactionReady && result.kind === 'user' && result.canFollow === true)
        .accessibilityText(result.followBusy ? this.uiText("pm_submitting_profile_follow_action_9167e789") : result.following ? this.uiText("pm_unfollow_profile_16f4c576") : this.uiText("pm_follow_profile_655e46b4"))
        .onClick(() => { if (this.interactionReady && result.canFollow && this.onFollowUser) this.onFollowUser(result.id); })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 10 })
    .opacity(result.enabled ? 1 : 0.45)
    .accessibilityText(result.title + (result.subtitle ? '，' + result.subtitle : ''))
    .onClick(() => { if (result.enabled && this.onResult) this.onResult(result.targetUrl); })
  }

  private hasProductFilter(kind: string): boolean {
    return kind === 'price' ? /[?&]price_(?:min|max)=[^&#]+/.test(this.snapshot.pageKey) : /[?&]domains=[^&#]+/.test(this.snapshot.pageKey);
  }

  @Builder
  private filteredEmptyState() {
    Column({ space: 12 }) {
      if (/\/search\/videos\//.test(this.snapshot.pageKey)) {
        Image($r('app.media.search_video_empty')).width(200).height(200).objectFit(ImageFit.Contain).accessibilityLevel('no')
        Text(this.uiText("pm_that_does_not_seem_to_work_59c83091")).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(this.uiText("pm_no_results_match_the_selected_filters_try_changing_your_filters_59447648"))
          .fontSize(16).fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center)
      } else {
        Image($r('app.media.search_product_empty')).width(200).height(200).objectFit(ImageFit.Contain).accessibilityLevel('no')
        Text(this.uiText("pm_adjust_your_search_72f85b23")).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(this.uiText("pm_no_pins_match_your_search_try_changing_or_removing_filters_7e39c540"))
          .fontSize(16).fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center)
        if (this.hasProductFilter('price') || this.hasProductFilter('merchant')) {
          Row({ space: 12 }) {
            if (this.hasProductFilter('price')) {
              Button(this.uiText("pm_remove_price_94a31c30")).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
                .enabled(this.interactionReady).onClick(() => { if (this.onClearProductFilter) this.onClearProductFilter('price'); })
            }
            if (this.hasProductFilter('merchant')) {
              Button(this.uiText("pm_remove_retailers_3b034b33")).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
                .enabled(this.interactionReady).onClick(() => { if (this.onClearProductFilter) this.onClearProductFilter('merchant'); })
            }
          }.margin({ top: 32 })
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Center)
  }

  private profileSearchEmpty(): boolean {
    return !this.loading && !this.error && !this.snapshot.apiBusy && !this.snapshot.apiError &&
      this.snapshot.apiActive === true && this.snapshot.apiEnded === true && this.snapshot.results.length === 0 &&
      !!this.snapshot.query.trim() && /\/search\/users\//.test(this.snapshot.pageKey);
  }

  @Builder
  private searchStatus() {
    Column({ space: 14 }) {
      if (this.query.trim() && !/[?&]q=[^&#]+/i.test(this.snapshot.pageKey) && !this.loading) {
        Text(this.uiText("pm_press_search_to_see_results_9e79a655")).fontColor($r('app.color.secondary_text'))
      } else if (this.loading || this.snapshot.kind === 'loading' ||
          (this.snapshot.api && this.snapshot.apiActive === false && !this.error)) {
        this.searchLoadingState()
      } else if (this.error) {
        Text(PinmonyI18n.render(this.error, this.uiLanguage))
          .fontSize(15)
          .fontColor($r('app.color.primary_text'))
          .textAlign(TextAlign.Center)
        Button(this.uiText("pm_reload_df7392cc"))
          .onClick(() => { if (this.onRetry) this.onRetry(); })
      } else if (this.profileSearchEmpty()) {
        Text(this.uiText("pm_we_could_not_find_anyone_named_a06407b4") + this.snapshot.query.trim() + this.uiText("pm_text_c74084fe"))
          .fontSize(15).fontColor($r('app.color.primary_text')).width('100%')
          .textAlign(TextAlign.Start).margin({ top: 20 })
        Text(this.uiText("pm_sorry_we_could_not_find_any_pins_for_this_search_80dcc4da"))
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .width('100%').textAlign(TextAlign.Center).margin({ top: 60 })
      } else if (this.query.trim() && this.snapshot.apiActive === true && this.snapshot.apiEnded === true && /\/search\/(videos|buyable_pins)\//.test(this.snapshot.pageKey)) {
        this.filteredEmptyState()
      } else if (this.query.trim()) {
        Text(this.uiText("pm_no_search_results_available_6025e7b5")).fontSize(15).fontColor($r('app.color.secondary_text')).textAlign(TextAlign.Center)
      } else {
        Text(this.uiText("pm_no_pinterest_discovery_content_available_557fb101"))
          .fontSize(16)
          .fontColor($r('app.color.secondary_text'))
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(this.profileSearchEmpty() ? FlexAlign.Start : FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, bottom: 0 })
  }

  @Builder
  private searchHeader() {
    Row({ space: 8 }) {
        Search({ value: this.query, placeholder: this.searchPlaceholder(),
          controller: this.inputController })
          .layoutWeight(1)
          .height(44)
          .fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.input_surface'))
          .borderRadius(22)
          .enterKeyType(EnterKeyType.Search)
          .cancelButton({ style: CancelButtonStyle.INPUT })
          .onChange((value: string) => {
            if (this.query !== value) this.query = value;
            if (this.onQueryChange) this.onQueryChange(value);
          })
          .onSubmit((value: string) => {
            if (this.interactionReady && this.onSubmit) { this.closeInputPanel(false); this.onSubmit(value); }
          })
          .onClick(() => this.beginSearchInput())
          .onFocus(() => {
            PinmonyRuntimeLog.info('SearchInputTrace: event=focus active=' + this.active.toString() + ' editing=' + this.inputEditing.toString());
          })
          .onBlur(() => { /* Keyboard focus does not dismiss the input panel. */ })
          .accessibilityText(this.uiText("pm_search_pinterest_3a2ae4e9"))
    }.width('100%').height(56).flexShrink(0)
      .hitTestBehavior(HitTestMode.Transparent)
      .margin({ top: this.getUIContext().px2vp(this.statusBarHeightPx) })
      .padding({ left: this.searchBackVisible() ? 60 : 8, right: !this.inputEditing ? 60 : 8 }).alignItems(VerticalAlign.Center)
  }

  @Builder
  private searchResultsContent() {
    Column() {
      if (this.snapshot.api && this.snapshot.results.length > 0 && this.error) {
        Row({ space: 12 }) {
          Text(PinmonyI18n.render(this.error, this.uiLanguage))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
            .layoutWeight(1)
          Button(this.uiText("pm_retry_b8784c8d"))
            .onClick(() => {
              if (!(this.actionsReady || this.resultsReadsReady) && this.onRetry) this.onRetry();
              else if (this.onLoadMore) this.onLoadMore();
            })
        }
        .width('100%')
        .padding(12)
      }
      if (this.snapshot.results.length === 0) {
        this.searchStatus()
      } else if (this.allPins()) {
        WaterFlow({ scroller: this.resultsScroller, sections: this.flowSections }) {
          if (this.entryQuiz) { FlowItem() { this.inspirationEntry() }.width('100%') }
          ForEach(this.snapshot.results, (item: PinmonySearchResult) => {
            FlowItem() {
              this.pinCard(item)
            }
            .width('100%')
            .height(this.pinCardHeight(item))
          }, (item: PinmonySearchResult) => item.kind + ':' + item.targetUrl + ':' + item.title)
        }
        .columnsTemplate(this.contentColumnsTemplate())
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16, bottom: 0 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAppear(() => this.restoreResultsScroll())
        .onDidScroll((offset: number, state: ScrollState) => {
          this.updateCategoriesOnScroll(offset, state);
          this.reportResultsScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
        .onScrollStop(() => this.reportResultsScroll())
        .onReachEnd(() => this.resultsReachEnd())
        .onScrollIndex((first: number, last: number) => this.resultsVisible(first, last))
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.resultsAreaChanged(newArea);
          const width: number = Number(newArea.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
        })
      } else if (this.snapshot.results.every((item: PinmonySearchResult): boolean => item.kind === 'board')) {
        WaterFlow({ scroller: this.resultsScroller }) {
          ForEach(this.snapshot.results, (item: PinmonySearchResult) => {
            FlowItem() { this.boardResult(item) }.width('100%')
          }, (item: PinmonySearchResult) => item.id)
        }.columnsTemplate(this.contentColumnsTemplate()).columnsGap(12).rowsGap(24)
          .width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: 16 })
          .scrollBar(BarState.Off).onAppear(() => this.restoreResultsScroll())
          .onDidScroll((offset: number, state: ScrollState) => {
            this.updateCategoriesOnScroll(offset, state);
            this.reportResultsScroll();
            if (this.onContentScroll) this.onContentScroll(offset, state);
          })
          .onScrollStop(() => this.reportResultsScroll())
          .onReachEnd(() => this.resultsReachEnd())
          .onAreaChange((_old: Area, area: Area) => this.resultsAreaChanged(area))
      } else {
        List({ scroller: this.resultsScroller }) {
          if (this.entryQuiz) { ListItem() { this.inspirationEntry() }.padding(12) }
          ForEach(this.snapshot.results, (item: PinmonySearchResult) => {
            ListItem() {
              this.resultRow(item)
            }
          }, (item: PinmonySearchResult) => item.kind + ':' + item.targetUrl + ':' + item.title)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: 0 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAppear(() => this.restoreResultsScroll())
        .onDidScroll((offset: number, state: ScrollState) => {
          this.updateCategoriesOnScroll(offset, state);
          this.reportResultsScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
        .onScrollStop(() => this.reportResultsScroll())
        .onReachEnd(() => this.resultsReachEnd())
        .onAreaChange((_oldArea: Area, newArea: Area) => this.resultsAreaChanged(newArea))
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private inputSuggestionsContent() {
    List() {
      if (this.snapshot.suggestionBusy) {
        ListItem() { Row({ space: 12 }) { LoadingProgress().width(20).height(20); Text(this.uiText("pm_loading_search_suggestions_4ff5d4ed")).fontSize(14) }.padding(16) }
      }
      if (this.snapshot.suggestionError) {
        ListItem() { Text(PinmonyI18n.render(this.snapshot.suggestionError, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text')).padding(16) }
      }
      ForEach(this.snapshot.suggestions, (item: PinmonySearchSuggestion) => {
        ListItem() {
          Row({ space: 16 }) {
            Row({ space: 16 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(16).fontColor([$r('app.color.secondary_text')])
            Text(PinmonyI18n.render(item.label, this.uiLanguage)).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1).maxLines(2)
            }.layoutWeight(1).constraintSize({ minHeight: 48 })
              .onClick(() => { if (this.interactionReady && item.enabled && !item.deleting && this.onSuggestion) { this.closeInputPanel(false); this.onSuggestion(item.id); } })
            if (!this.query.trim()) {
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([$r('app.color.secondary_text')])
              }.width(32).height(32).padding(0).backgroundColor(Color.Transparent)
                .enabled(this.interactionReady && this.historyActionsReady && item.deletable === true && item.deleting !== true)
                .accessibilityText(item.deleting ? this.uiText("pm_deleting_search_history_2674b330") : item.deletable ? this.uiText("pm_delete_search_history_80b537e5") : this.uiText("pm_this_type_of_search_history_cannot_be_deleted_yet_00762b84"))
                .onClick(() => { if (this.interactionReady && this.historyActionsReady && item.deletable && !item.deleting && this.onDeleteHistory) this.onDeleteHistory(item.id); })
            }
          }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 20, right: 12 })

        }
      }, (item: PinmonySearchSuggestion) => (item.id) + ':' + this.uiLanguage)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  private searchRootDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Column() {

        if (this.automaticLoadingEnabled && this.committedQuery()) {
          Row() {
            ForEach(this.upcomingImageUrls, (url: string) => {
              Image(url).width(1).height(1).opacity(0).accessibilityLevel('no')
            }, (url: string) => url)
          }.height(0).clip(true).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
        if (!this.inputEditing && this.visibleCategories().length > 0) {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.visibleCategories(), (item: PinmonySearchCategory) => {
                this.categoryChip(item)
              }, (item: PinmonySearchCategory) => item.id)
            }
            .padding({ left: 16, right: 8 })
          }
          .width('100%').height(this.categoriesCollapsed && !this.inputEditing ? 0 : 54)
          .flexShrink(0)
          .opacity(this.categoriesCollapsed && !this.inputEditing ? 0 : 1)
          .clip(true)
          .hitTestBehavior(this.categoriesCollapsed && !this.inputEditing ? HitTestMode.None : HitTestMode.Default)
          .accessibilityLevel(this.categoriesCollapsed && !this.inputEditing ? 'no-hide-descendants' : 'auto')
          .scrollable(ScrollDirection.Horizontal)
          .align(Alignment.Start).scrollBar(BarState.Off)
        }
        Refresh({ refreshing: this.refreshing }) {
        Column() {
          if (this.inputEditing) {
            this.inputSuggestionsContent()
          } else if (!this.committedQuery()) {
            if (this.error && this.snapshot.heroes.length === 0 && this.snapshot.ideaSections.length === 0) {
              this.searchStatus()
            } else {
              this.discoveryContent()
            }
          } else {
            this.searchResultsContent()
          }
        }
        .width('100%')
        .height('100%')
        }
        .width('100%').layoutWeight(1).clip(true)
        .pullToRefresh(!this.inputEditing && !this.refreshing && !this.loading && !this.quizSheetOpen)
        .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
      }
      .width('100%')
      .height('100%')

    }
    .hideTitleBar(false)
    .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
        { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(!this.searchBackVisible())
    .titleBar({
      avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') } }, backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') } } }
      },
      content: {
        title: { mainTitle: '' },
        backIcon: { isEnabled: true, action: () => this.handleSearchBack() },
        menu: { value: !this.inputEditing && !!this.committedQuery() ? [{ content: {
          icon: $r('sys.symbol.slider_horizontal_2'), label: this.uiText('pm_show_filters_12e6eb18'),
          isEnabled: this.interactionReady,
          action: () => { if (this.interactionReady && this.onFilters) this.onFilters(); }
        } }] : !this.inputEditing && !this.committedQuery() ? [{ content: {
          icon: $r('sys.symbol.camera'), label: this.uiText('pm_photo_search'),
          componentId: 'pinmony-photo-search-menu',
          isEnabled: this.interactionReady && !this.photoBusy,
          action: () => { this.photoMenu(); }
        } }] : [] }
      }
    })
    .bindToScrollable([this.committedQuery() ? this.resultsScroller : this.discoveryScroller])
    .onBackPressed(() => {
      this.handleSearchBack();
      return true;
    })
    // HDS owns the status/title inset; retain the system bottom safe area
    // so the final card menu reaches a visible, tappable position before pagination finishes.
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
    HdsNavigation(this.searchPathStack) {
      Column()
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .onAreaChange((_old: Area, area: Area) => {
      const width: number = Number(area.width);
      const height: number = Number(area.height);
      if (width > 0 && height > 0) {
        this.viewportWidth = width;
        this.viewportHeight = height;
      }
      if (width > 0 && Math.abs(width - this.contentWidth) > 1) {
        this.contentWidth = width;
        this.syncQuizPresentation();
      }
    })
    .navDestination(this.searchDestination)
    .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
        { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
    // Interactive input is above the HDS title controls, outside its stack builder.
    if (!this.photoPreview && !this.photoHistoryVisible) { this.searchHeader() }
    }.width('100%').height('100%')
    .bindSheet($$this.quizSheetOpen, this.quizSheet(), {
      radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
      onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonySearchPage.quizSheetOpen radius=four-corners-32vp'); },
      height: '85%', preferType: SheetType.BOTTOM, dragBar: false, showClose: true,
      title: { title: this.snapshot.quiz?.mode === 'picker' ? this.uiText("pm_choose_inspiration_up_to_10_images_19ae0263") : this.uiText("pm_inspiration_results_ffbd36b2") },
      backgroundColor: $r('app.color.page_background'), maskColor: '#66000000',
      onWillDismiss: (action: DismissSheetAction) => {
        action.dismiss();
        this.quizSheetOpen = false;
        if (this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry' && this.onQuizAction) this.onQuizAction('back', '');
      }
    })
  }

  private searchBackVisible(): boolean {
    return this.inputEditing || !!this.committedQuery();
  }

  private handleSearchBack(): void {
    if (this.inputEditing) {
      if (this.committedQuery() && this.onBack) {
        // The parent must consume the history intent before focus is cleared.
        this.onBack();
        // HDS keeps this destination mounted; do not rely on a parent stop callback.
        this.closeInputPanel(false);
      } else this.closeInputPanel(true);
      return;
    }
    if (this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry' && this.onQuizAction) {
      this.onQuizAction('back', '');
    } else if (this.committedQuery()) this.openSearchHistory();
    else if (this.onBack) this.onBack();
  }

  private openSearchHistory(): void {
    this.inputController.stopEditing();
    this.query = '';
    this.inputEditing = true;
    this.categoriesCollapsed = false;
    this.categoryScrollDistance = 0;
    if (this.onQueryChange) this.onQueryChange('', true);
    if (this.onInputFocusChange) this.onInputFocusChange(true, () => this.closeInputPanel(false));
  }

  private committedQuery(): string {
    const match: RegExpMatchArray | null = (this.snapshot.pageKey || '').match(/[?&]q=([^&#]*)/);
    try { return match ? decodeURIComponent(match[1].replace(/\+/g, ' ')).trim() : ''; } catch (_) { return ''; }
  }

  private closeInputPanel(restore: boolean): void {
    this.inputEditing = false;
    this.inputController.stopEditing();
    this.query = this.committedQuery();
    this.lastSnapshotQuery = this.snapshot.query || '';
    if (restore && this.onQueryChange) this.onQueryChange(this.query);
    if (this.onInputFocusChange) this.onInputFocusChange(false, () => this.closeInputPanel(false));
  }

  private beginSearchInput(): void {
    if (!this.active || this.inputEditing) return;
    PinmonyRuntimeLog.info('SearchInputTrace: event=user-edit');
    this.onInputFocus(true);
  }

  private onInputFocus(focused: boolean): void {
    this.inputEditing = focused;
    if (focused && this.onQueryChange) this.onQueryChange(this.query, true);
    if (this.onInputFocusChange) {
      this.onInputFocusChange(focused, () => this.closeInputPanel(false));
    }
  }

}
