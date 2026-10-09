import { PinWebVideoCard } from 'common_ui';
import { PinWebSearchQuizPanel } from './PinWebSearchQuizPanel';
import { Chip, ChipSize } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavigation } from '@kit.UIDesignKit';
import { PinWebSearchCategory, PinWebSearchResult, PinWebSearchSnapshot,
  PinWebSearchQuiz, PinWebSearchSuggestion, PinWebSearchHero, PinWebSearchIdea, PinWebSearchIdeaSection } from '../models/PinWebSearch';

@Component
export struct PinWebSearchPage {
  @Prop automaticLoadingEnabled: boolean = true;
  @Prop @Watch('onSnapshotChanged') snapshot: PinWebSearchSnapshot = {} as PinWebSearchSnapshot;
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageProp('gestureBarHeightPx') private gestureBarHeightPx: number = 0;
  @Prop mediaActive: boolean = false;
  @Prop loading: boolean = false;
  @Prop refreshing: boolean = false;
  onRefresh?: () => void;
  @Prop error: string = '';
  @Prop actionsReady: boolean = true;
  @Prop interactionReady: boolean = true;
  @Prop historyActionsReady: boolean = false;
  @Prop initialResultsScrollOffset: number = 0;
  @State private query: string = '';
  @State private quizSheetOpen: boolean = false;
  @State private entryQuiz: PinWebSearchQuiz | undefined = undefined;
  private readonly flowSections: WaterFlowSections = new WaterFlowSections();
  private flowShape: string = '';
  @State private contentWidth: number = 360;
  @State private failedImages: string[] = [];
  @State private currentHeroIndex: number = 0;
  private readonly inputController: SearchController = new SearchController();
  private readonly searchPathStack: NavPathStack = new NavPathStack();
  private readonly swiperController: SwiperController = new SwiperController();
  private readonly discoveryScroller: Scroller = new Scroller();
  private readonly resultsScroller: Scroller = new Scroller();
  private restoringResultsScroll: boolean = false;
  private resultsOffset: number = 0;
  private activeSession: number = 0;
  private activePage: string = '';
  private lastSnapshotQuery: string = '';
  @State private inputEditing: boolean = false;
  private initialFillCount: number = 0;
  private initialFillScheduled: boolean = false;
  onQueryChange?: (value: string, refreshSuggestions?: boolean) => void;
  onSubmit?: (value: string) => void;
  onInputFocusChange?: (focused: boolean, stopEditing: () => void) => void;
  onCategory?: (id: string) => void;
  onSuggestion?: (id: string) => void;
  onDeleteHistory?: (id: string) => void;
  onResult?: (targetUrl: string) => void;
  onExploreAction?: (id: string, kind: string) => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onBack?: () => void;
  onFilters?: () => void;
  onQuizAction?: (kind: string, id: string) => void;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onResultsScrollPosition?: (pageKey: string, offset: number) => void;

  aboutToAppear(): void {
    this.restoringResultsScroll = this.initialResultsScrollOffset > 0;
    this.searchPathStack.clear();
    this.searchPathStack.pushPath({ name: 'pin-web-search' }, false);
    this.activeSession = this.snapshot.session;
    this.activePage = this.snapshot.pageKey;
    this.query = this.committedQuery();
    this.lastSnapshotQuery = this.snapshot.query || '';
    this.syncQuizPresentation();
    this.fillInitialViewport();
  }

  private restoreResultsScroll(): void {
    const offset: number = Math.max(0, this.initialResultsScrollOffset);
    setTimeout(() => {
      try {
        const scroller: Scroller = this.snapshot.query ? this.resultsScroller : this.discoveryScroller;
        scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
      } catch (error) {
        console.warn('PinWeb: search scroll restoration unavailable');
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
      console.warn('PinWeb: search scroll position unavailable');
    }
  }

  aboutToDisappear(): void {
    this.searchPathStack.clear();
  }

  private onSnapshotChanged(): void {
    if (this.activeSession !== this.snapshot.session || this.activePage !== this.snapshot.pageKey) {
      this.activeSession = this.snapshot.session;
      this.activePage = this.snapshot.pageKey;
      this.entryQuiz = undefined;
      this.failedImages = [];
      this.currentHeroIndex = 0;
      this.initialFillCount = 0;
    }
    const nextQuery: string = this.snapshot.query || '';
    if (nextQuery !== this.lastSnapshotQuery) {
      this.lastSnapshotQuery = nextQuery;
      if (!this.inputEditing) this.query = this.committedQuery();
    }
    if (this.currentHeroIndex >= this.snapshot.heroes.length) this.currentHeroIndex = 0;
    this.syncQuizPresentation();
    this.fillInitialViewport();
  }

  private syncQuizPresentation(): void {
    const quiz: PinWebSearchQuiz | undefined = this.snapshot.quiz;
    if (!quiz) this.entryQuiz = undefined;
    else if (quiz.mode === 'entry') this.entryQuiz = quiz;
    this.quizSheetOpen = !!quiz && quiz.mode !== 'entry';
    const shape: string = (this.entryQuiz ? '1:' : '0:') + this.snapshot.results.length.toString();
    if (shape !== this.flowShape) {
      this.flowShape = shape;
      const sections: SectionOptions[] = [];
      if (this.entryQuiz) sections.push({ itemsCount: 1, crossCount: 1, margin: { left: 0, right: 0, bottom: 12 } });
      sections.push({ itemsCount: this.snapshot.results.length, crossCount: 2, columnsGap: 12, rowsGap: 12 });
      this.flowSections.splice(0, this.flowSections.length(), sections);
    }
  }

  @Builder
  private quizSheet() {
    if (this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry') {
      PinWebSearchQuizPanel({ quiz: this.snapshot.quiz,
        onAction: (kind: string, id: string) => { if (this.onQuizAction) this.onQuizAction(kind, id); },
        onPin: (url: string) => { if (this.onResult) this.onResult(url); } })
    }
  }

  @Builder
  private inspirationEntry() {
    if (this.entryQuiz) {
      PinWebSearchQuizPanel({ quiz: this.entryQuiz,
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
      this.snapshot.results.length > 0 && this.snapshot.results.length < 20;
    if (!needsMore || !this.onLoadMore) return;
    this.initialFillCount++;
    this.initialFillScheduled = true;
    const page: string = this.snapshot.pageKey;
    setTimeout(() => {
      this.initialFillScheduled = false;
      if (this.automaticLoadingEnabled && this.snapshot.pageKey === page && this.actionsReady && !this.loading && this.onLoadMore) this.onLoadMore();
    }, 0);
  }

  private imageFailed(url: string): boolean {
    return !url || this.failedImages.indexOf(url) >= 0;
  }

  private markImageFailed(url: string): void {
    if (url && this.failedImages.indexOf(url) < 0) {
      this.failedImages = [...this.failedImages, url];
    }
  }

  private imageHeight(result: PinWebSearchResult): number {
    const width: number = Math.max(130, (this.contentWidth - 12) / 2);
    if (result.imageWidth <= 0 || result.imageHeight <= 0) return width * 1.2;
    return width * Math.max(0.55, Math.min(3.2, result.imageHeight / result.imageWidth));
  }

  private allPins(): boolean {
    return this.snapshot.results.length > 0 && this.snapshot.results.every((result: PinWebSearchResult): boolean =>
      result.kind === 'pin');
  }

  private visibleCategories(): PinWebSearchCategory[] {
    return this.snapshot.categories.filter((item: PinWebSearchCategory): boolean =>
      !/^(?:show |all )?(?:filters?|显示筛选器|筛选器|顯示篩選器|篩選器)$/i.test(item.label.trim()));
  }

  @Builder
  private categoryChip(item: PinWebSearchCategory) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        if (item.imageUrl) { Image(item.imageUrl).width(44).height(44).objectFit(ImageFit.Cover) }
        Text(item.label).fontSize(14).fontColor($r('app.color.primary_text')).padding({ right: 12, left: item.imageUrl ? 0 : 12 })
      }.height(44)
    }.padding(0).borderRadius(14).clip(true).backgroundColor($r('app.color.surface_muted'))
      .accessibilityText(item.label).accessibilitySelected(item.selected)
      .enabled(this.interactionReady && item.enabled && !this.loading)
      .onClick(() => { if (this.onCategory) this.onCategory(item.id); })
  }

  @Builder
  private suggestionChip(item: PinWebSearchSuggestion) {
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
      accessibilityDescription: `搜索${item.label}`
    })
  }

  @Builder
  private heroSlide(hero: PinWebSearchHero) {
    Stack({ alignContent: Alignment.Top }) {
      if (this.imageFailed(hero.imageUrl)) {
        Column() {
          Text('图片加载失败')
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
            Text(hero.subtitle)
              .fontSize(14)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          Text(hero.title)
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
    .accessibilityText(hero.title + (hero.subtitle ? '，' + hero.subtitle : ''))
    .onClick(() => {
      if (hero.enabled && this.onExploreAction) this.onExploreAction(hero.id, 'hero');
    })
  }

  @Builder
  private heroCarousel() {
    Column() {
      Swiper(this.swiperController) {
        ForEach(this.snapshot.heroes, (hero: PinWebSearchHero) => {
          this.heroSlide(hero)
        }, (hero: PinWebSearchHero) => hero.id)
      }
      .width('100%')
      .height(390)
      .indicator(false)
      .autoPlay(this.snapshot.heroes.length > 1)
      .interval(4800)
      .loop(this.snapshot.heroes.length > 1)
      .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
      .onChange((index: number) => this.currentHeroIndex = index)

      Row({ space: 8 }) {
        ForEach(this.snapshot.heroes, (hero: PinWebSearchHero, index: number) => {
          Button({ type: ButtonType.Circle })
            .width(this.currentHeroIndex === index ? 9 : 7)
            .height(this.currentHeroIndex === index ? 9 : 7)
            .padding(0)
            .backgroundColor(this.currentHeroIndex === index ?
              $r('app.color.primary_text') : $r('app.color.secondary_text'))
            .onClick(() => {
              this.currentHeroIndex = index;
              this.swiperController.changeIndex(index, true);
            })
            .accessibilityText(`切换到第${index + 1}张推荐轮播图`)
            .accessibilitySelected(this.currentHeroIndex === index)
        }, (hero: PinWebSearchHero) => hero.id)
      }
      .width('100%')
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private ideaCard(item: PinWebSearchIdea) {
    Stack() {
      if (this.imageFailed(item.imageUrl)) {
        Column() {
          Text('图片加载失败')
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
    .accessibilityText(item.title + '，打开推荐点子')
    .onClick(() => {
      if (item.enabled && this.onExploreAction) this.onExploreAction(item.id, 'idea');
    })
  }

  private ideaEyebrowLabel(section: PinWebSearchIdeaSection): string {
    return section.eyebrow;
  }

  @Builder
  private ideaSection(section: PinWebSearchIdeaSection) {
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
        Text(section.title)
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
          .accessibilityText(`查看${section.title}全部内容`)
          .onClick(() => {
            if (this.onExploreAction) this.onExploreAction(section.actionId, 'ideaSection');
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Grid() {
        ForEach(section.items, (item: PinWebSearchIdea) => {
          GridItem() {
            this.ideaCard(item)
          }
          .height(176)
        }, (item: PinWebSearchIdea) => item.id)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(6)
      .rowsGap(0)
      .width('100%')
      .height(176)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 26 })
  }

  @Builder
  private discoveryEmpty() {
    Column({ space: 8 }) {
      Text('暂时没有可显示的探索内容')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
      Text('Pinterest 当前页面没有提供可识别的轮播或推荐点子')
        .fontSize(14)
        .fontColor($r('app.color.secondary_text'))
        .textAlign(TextAlign.Center)
      Button('重新读取')
        .height(40)
        .padding({ left: 18, right: 18 })
        .onClick(() => { if (this.onRetry) this.onRetry(); })
        .accessibilityText('重新读取 Pinterest 探索内容')
    }
    .width('100%')
    .height(240)
    .padding({ left: 24, right: 24 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private discoveryContent() {
    Scroll(this.discoveryScroller) {
      Column({ space: 0 }) {
        if (this.snapshot.heroes.length > 0) {
          this.heroCarousel()
        }
        ForEach(this.snapshot.ideaSections, (section: PinWebSearchIdeaSection) => {
          this.ideaSection(section)
        }, (section: PinWebSearchIdeaSection) => section.id)
        if (this.snapshot.discoveryApi) {
          Column({ space: 10 }) {
            if (this.snapshot.discoveryError) {
              Text(this.snapshot.discoveryError)
                .fontSize(14)
                .fontColor($r('app.color.secondary_text'))
              Button('重试')
                .onClick(() => {
                  if (this.snapshot.discoveryActive) {
                    if (this.onLoadMore) this.onLoadMore();
                  } else if (this.onRetry) this.onRetry();
                })
            } else if (this.snapshot.discoveryBusy) {
              LoadingProgress().width(28).height(28)
              Text('正在读取搜索主题…')
                .fontSize(14)
                .fontColor($r('app.color.secondary_text'))
            } else if (this.snapshot.discoveryActive && this.snapshot.ideaSections.length === 0) {
              Text('暂时没有推荐主题')
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
      if (this.automaticLoadingEnabled && this.actionsReady && this.snapshot.discoveryApi && !this.snapshot.discoveryBusy &&
          !this.snapshot.discoveryError && !this.snapshot.discoveryEnded && this.onLoadMore) this.onLoadMore();
    })
  }

  @Builder
  private pinCard(result: PinWebSearchResult) {
    Column({ space: 8 }) {
      if (result.video) {
        PinWebVideoCard({ video: result.video, poster: result.imageUrl, active: this.mediaActive && this.actionsReady && !this.quizSheetOpen })
          .width('100%').height(this.imageHeight(result))
          
      } else if (this.failedImages.indexOf(result.imageUrl) >= 0 || !result.imageUrl) {
        Column() {
          Text(result.imageUrl ? '图片加载失败' : '暂无预览图')
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height(this.imageHeight(result))
        .borderRadius(18)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
        .accessibilityText(result.title + (result.imageUrl ? '，图片加载失败' : '，暂无预览图'))
      } else {
        Image(result.imageUrl)
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
      Text(result.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(result.title + '，打开搜索结果')
    .onClick(() => { if (result.enabled && this.onResult) this.onResult(result.targetUrl); })
  }

  @Builder
  private resultRow(result: PinWebSearchResult) {
    Row({ space: 14 }) {
      if (result.imageUrl && this.failedImages.indexOf(result.imageUrl) < 0) {
        Image(result.imageUrl)
          .width(result.kind === 'profile' ? 58 : 74)
          .height(result.kind === 'profile' ? 58 : 74)
          .borderRadius(result.kind === 'profile' ? 29 : 14)
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
        .width(result.kind === 'profile' ? 58 : 74)
        .height(result.kind === 'profile' ? 58 : 74)
        .borderRadius(result.kind === 'profile' ? 29 : 14)
        .backgroundColor($r('app.color.surface_muted'))
        .justifyContent(FlexAlign.Center)
        .accessibilityLevel('no')
      }
      Column({ space: 4 }) {
        Text(result.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (result.subtitle) {
          Text(result.subtitle)
            .fontSize(13)
            .fontColor($r('app.color.secondary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('重试')
        .fontSize(24)
        .fontColor($r('app.color.secondary_text'))
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 10 })
    .opacity(result.enabled ? 1 : 0.45)
    .accessibilityText(result.title + (result.subtitle ? '，' + result.subtitle : ''))
    .onClick(() => { if (result.enabled && this.onResult) this.onResult(result.targetUrl); })
  }

  @Builder
  private searchStatus() {
    Column({ space: 14 }) {
      if (this.query.trim() && !/[?&]q=[^&#]+/i.test(this.snapshot.pageKey) && !this.loading) {
        Text('按搜索键查看结果').fontColor($r('app.color.secondary_text'))
      } else if (this.loading || this.snapshot.kind === 'loading' ||
          (this.snapshot.api && this.snapshot.apiActive === false && !this.error)) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在加载搜索结果…')
          .fontSize(15)
          .fontColor($r('app.color.secondary_text'))
      } else if (this.error) {
        Text(this.error)
          .fontSize(15)
          .fontColor($r('app.color.primary_text'))
          .textAlign(TextAlign.Center)
        Button('重新读取')
          .onClick(() => { if (this.onRetry) this.onRetry(); })
      } else if (this.query.trim()) {
        Text('没有读取到可显示的搜索结果')
          .fontSize(15)
          .fontColor($r('app.color.secondary_text'))
          .textAlign(TextAlign.Center)
      } else {
        Text('Pinterest 当前没有提供可显示的探索内容')
          .fontSize(16)
          .fontColor($r('app.color.secondary_text'))
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, bottom: 0 })
  }

  @Builder
  private searchHeader() {
    Row({ space: 8 }) {
      if (!this.inputEditing) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([$r('app.color.primary_text')])
      }.width(44).height(44).padding(0).backgroundColor($r('app.color.surface_muted'))
        .accessibilityText('返回搜索').onClick(() => this.handleSearchBack())
      }
        Search({ value: this.query, placeholder: this.snapshot.placeholder || '搜索 Pinterest',
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
          .onFocus(() => this.onInputFocus(true))
          .onBlur(() => { /* Keyboard focus does not dismiss the input panel. */ })
          .accessibilityText('搜索 Pinterest')
      if (this.inputEditing) {
        Button('取消').fontSize(14).fontColor($r('app.color.secondary_text'))
          .backgroundColor(Color.Transparent).onClick(() => { this.closeInputPanel(true); })
      } else if (this.committedQuery()) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.slider_horizontal_2'))
            .fontSize(24)
            .fontColor([$r('app.color.primary_text')])
        }
        .width(44)
        .height(44)
        .padding(0)

        .backgroundColor($r('app.color.surface_muted'))
        .enabled(this.interactionReady)
        .accessibilityText('显示筛选器')
        .onClick(() => { if (this.interactionReady && this.onFilters) this.onFilters(); })
      }

    }.width('100%').height(56).padding({ left: 8, right: 8 }).alignItems(VerticalAlign.Center)
  }

  @Builder
  private searchResultsContent() {
    Column() {
      if (this.visibleCategories().length > 0) {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.visibleCategories(), (item: PinWebSearchCategory) => {
              this.categoryChip(item)
            }, (item: PinWebSearchCategory) => item.id)
          }
          .padding({ left: 16, right: 8 })
        }
        .width('100%')
        .height(54)
        .scrollable(ScrollDirection.Horizontal)
        .align(Alignment.Start)
        .scrollBar(BarState.Off)
      }

      if (this.snapshot.api && this.snapshot.results.length > 0 && this.error) {
        Row({ space: 12 }) {
          Text(this.error)
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
            .layoutWeight(1)
          Button('重试')
            .onClick(() => {
              if (!this.actionsReady && this.onRetry) this.onRetry();
              else if (this.onLoadMore) this.onLoadMore();
            })
        }
        .width('100%')
        .padding(12)
      } else if (this.snapshot.api && this.snapshot.apiBusy && this.snapshot.results.length > 0) {
        LoadingProgress().width(24).height(24).margin(12)
      }
      if ((this.error && !(this.snapshot.api && this.snapshot.results.length > 0)) ||
          this.loading || this.snapshot.kind === 'loading' || this.snapshot.results.length === 0) {
        this.inspirationEntry()
        this.searchStatus()
      } else if (this.allPins()) {
        WaterFlow({ scroller: this.resultsScroller, sections: this.flowSections }) {
          if (this.entryQuiz) { FlowItem() { this.inspirationEntry() }.width('100%') }
          ForEach(this.snapshot.results, (item: PinWebSearchResult) => {
            FlowItem() {
              this.pinCard(item)
            }
            .width('100%')
          }, (item: PinWebSearchResult) => item.kind + ':' + item.targetUrl + ':' + item.title)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 0 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAppear(() => this.restoreResultsScroll())
        .onDidScroll((offset: number, state: ScrollState) => {
          this.reportResultsScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
        .onScrollStop(() => this.reportResultsScroll())
        .onReachEnd(() => { if (this.automaticLoadingEnabled && this.actionsReady && !this.loading && this.onLoadMore) this.onLoadMore(); })
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          const width: number = Number(newArea.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
        })
      } else {
        List({ scroller: this.resultsScroller }) {
          if (this.entryQuiz) { ListItem() { this.inspirationEntry() }.padding(12) }
          ForEach(this.snapshot.results, (item: PinWebSearchResult) => {
            ListItem() {
              this.resultRow(item)
            }
          }, (item: PinWebSearchResult) => item.kind + ':' + item.targetUrl + ':' + item.title)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: 0 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAppear(() => this.restoreResultsScroll())
        .onDidScroll((offset: number, state: ScrollState) => {
          this.reportResultsScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
        .onScrollStop(() => this.reportResultsScroll())
        .onReachEnd(() => { if (this.automaticLoadingEnabled && this.actionsReady && !this.loading && this.onLoadMore) this.onLoadMore(); })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private inputSuggestionsContent() {
    List() {
      if (this.snapshot.suggestionBusy) {
        ListItem() { Row({ space: 12 }) { LoadingProgress().width(20).height(20); Text('正在读取搜索建议').fontSize(14) }.padding(16) }
      }
      if (this.snapshot.suggestionError) {
        ListItem() { Text(this.snapshot.suggestionError).fontSize(14).fontColor($r('app.color.secondary_text')).padding(16) }
      }
      ForEach(this.snapshot.suggestions, (item: PinWebSearchSuggestion) => {
        ListItem() {
          Row({ space: 16 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(16).fontColor([$r('app.color.secondary_text')])
            Text(item.label).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1).maxLines(2)
            if (!this.query.trim()) {
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([$r('app.color.secondary_text')])
              }.width(32).height(32).padding(0).backgroundColor(Color.Transparent)
                .enabled(this.interactionReady && this.historyActionsReady && item.deletable === true && item.deleting !== true)
                .accessibilityText(item.deleting ? '正在删除搜索历史' : item.deletable ? '删除搜索历史' : '此类搜索历史暂不支持删除')
                .onClick(() => { if (this.interactionReady && this.historyActionsReady && item.deletable && !item.deleting && this.onDeleteHistory) this.onDeleteHistory(item.id); })
            }
          }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 20, right: 12 })
            .onClick(() => { if (this.interactionReady && item.enabled && this.onSuggestion) { this.closeInputPanel(false); this.onSuggestion(item.id); } })
        }
      }, (item: PinWebSearchSuggestion) => item.id)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  private searchDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Column() {
        // Lay out the compact search row directly; HDS stackBuilder reserves extra title-bar space.
        this.searchHeader()
        if (!this.inputEditing && !this.committedQuery() && this.visibleCategories().length > 0) {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.visibleCategories(), (item: PinWebSearchCategory) => {
                this.categoryChip(item)
              }, (item: PinWebSearchCategory) => item.id)
            }
            .padding({ left: 16, right: 8 })
          }
          .width('100%').height(54).scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
        }
        Refresh({ refreshing: this.refreshing }) {
        Column() {
          if (this.inputEditing) {
            this.inputSuggestionsContent()
          } else if (!this.committedQuery()) {
            if (this.error || this.loading || this.snapshot.kind === 'loading') {
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
        .width('100%').layoutWeight(1)
        .pullToRefresh(!this.inputEditing && !this.refreshing && !this.loading && !this.quizSheetOpen)
        .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.getUIContext().px2vp(this.statusBarHeightPx) })
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .onBackPressed(() => {
      this.handleSearchBack();
      return true;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    HdsNavigation(this.searchPathStack) {
      Column()
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .hideTitleBar(true)
    .navDestination(this.searchDestination)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.quizSheetOpen, this.quizSheet(), {
      height: '85%', preferType: SheetType.BOTTOM, dragBar: false, showClose: true,
      title: { title: this.snapshot.quiz?.mode === 'picker' ? '选择灵感（最多10张）' : '灵感结果' },
      backgroundColor: $r('app.color.page_background'), maskColor: '#66000000',
      onWillDismiss: (action: DismissSheetAction) => {
        action.dismiss();
        this.quizSheetOpen = false;
        if (this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry' && this.onQuizAction) this.onQuizAction('back', '');
      }
    })
  }

  private handleSearchBack(): void {
    if (this.inputEditing) { this.closeInputPanel(true); return; }
    if (this.snapshot.quiz && this.snapshot.quiz.mode !== 'entry' && this.onQuizAction) {
      this.onQuizAction('back', '');
    } else if (this.onBack) this.onBack();
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

  private onInputFocus(focused: boolean): void {
    this.inputEditing = focused;
    if (focused && this.onQueryChange) this.onQueryChange(this.query, true);
    if (this.onInputFocusChange) {
      this.onInputFocusChange(focused, () => this.closeInputPanel(false));
    }
  }

}
