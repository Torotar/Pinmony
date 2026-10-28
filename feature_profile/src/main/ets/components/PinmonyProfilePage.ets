import { PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n, PinmonyProfileLayoutPreference } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, HdsNavigationTitleMode, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonyBoard, PinmonyCreatedPin, PinmonyProfileAction, PinmonyProfileSnapshot } from '../models/PinmonyProfile';
import { PinmonyOrganizePage } from './PinmonyOrganizePage';
import { PinmonyBoardCoverImage } from './PinmonyBoardCoverImage';


@Component
export struct PinmonyProfilePage {
  @StorageLink('pinmonyRootScrollTop3') @Watch('onRootScrollTop') private rootScrollTop: number = 0;
  private onRootScrollTop(): void {
    if (!this.interactionReady || this.profile.isOwn === false || this.modern() && !this.hubPane) return;
    try {
      const scroller: Scroller = this.scroller;
      const offset: number = scroller.offset()?.yOffset || 0;
      if (offset <= 1) {
        if (!(this.refreshing || this.loading || this.profile.contentLoading) && this.onRefresh) this.onRefresh();
      } else {
        scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
      }
    } catch (_) {}
  }

  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  onHubScrollerReady?: (scroller: Scroller) => void;
  @State private hubPaneScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller()];
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop automaticLoadingEnabled: boolean = true;
  @Prop @Watch('onProfileChanged') profile: PinmonyProfileSnapshot = {} as PinmonyProfileSnapshot;
  @Prop loading: boolean = false;
  @Prop hubPane: boolean = false;
  @Prop denseHubPins: boolean = false;
  @State private hubSearchPosition: number = 0;
  @State private hubChromeOffset: number = 0;
  private hubChromeScrollDistance: number = 0;
  @Prop hubChromeOffsetVp: number = 0;
  onHubScroll?: (offset: number, state: ScrollState, position: number) => void;
  @State private hubSnapshots: PinmonyProfileSnapshot[] = [];
  private readonly hubSwiper: SwiperController = new SwiperController();
  @Prop readsReady: boolean = false;
  @Prop actionsReady: boolean = true;
  @Prop @Watch('interactionChanged') interactionReady: boolean = true;
  @Prop refreshing: boolean = false;
  @Prop syncError: string = '';
  @Prop initialScrollOffset: number = 0;
  private restoringScroll: boolean = false;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onScrollPosition?: (profileUrl: string, section: string, offset: number) => void;
  @State private contentWidth: number = 360;
  private activeProfile: string = '';
  private activeSection: string = '';
  private backRequested: boolean = false;
  private readonly compactTitleBuilder: () => void = (): void => { this.compactTitle(); };
  private readonly rootCompactTitleBuilder: () => void = (): void => { this.rootCompactTitle(); };
  private readonly scroller: Scroller = new Scroller();
  onTab?: (section: string) => void;
  onBack?: () => void;
  onUser?: (url: string) => void;
  onWebsite?: (url: string) => void;
  private readonly profilePaths: NavPathStack = new NavPathStack();
  private profileNameBottom: number = 0;
  @State private compactHeader: boolean = false;
  @State private aboutVisible: boolean = false;
  @State private sectionMotion: number = 0;
  onAction?: (id: string, kind: string) => void;
  onBoard?: (id: string) => void;
  onPin?: (id: string) => void;
  onPinMore?: (id: string) => void;
  onSearch?: () => void;
  onPublish?: () => void;
  onBoardSort?: (value: string) => void;
  @State private sortVisible: boolean = false;
  @StorageLink('pinmonyBoardOrderVisible') private customOrderVisible: boolean = false;
  private pendingVisibility: boolean | undefined = undefined;
  onBoardVisibility?: (value?: boolean) => void;
  private recoveryRequested: boolean = false;
  onBoardRecovery?: () => void;
  @StorageLink('pinmonyUpdateUnread') private updateUnread: boolean = false;
  onSettings?: () => void;
  onShare?: () => void;
  @Prop followingBusy: boolean = false;
  onMenu?: () => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  onOrganize?: (action: string, value: string, secret: boolean) => void;

  @StorageLink('profileAvatarRight') private avatarRight: boolean = false;
  @StorageLink('profileLegacyLayout') @Watch('layoutChanged') private legacyProfile: boolean = false;
  @State private collageDrafts: boolean = false;
  @State private collageCreated: boolean = false;
  @State private densePins: boolean = false;
  @StorageLink('pinmonyProfilePinDensity') private pinDensity: number = 1;
  @State private draftPinDensity: number = 1;
  @State private pinViewOpen: boolean = false;
  private pinViewPage: string = '';
  private pinViewSession: number = -1;
  @State private hubTab: string = 'boards';
  @State private hubIndicatorPosition: number = -1;
  @State private hubTabBarWidth: number = 0;
  @State private favoriteFilter: boolean = false;
  @State private createdFilter: boolean = false;
  @State private boardFilter: string = '';
  private hubRequested: boolean = false;
  private modern(): boolean { return !this.legacyProfile && this.profile.isOwn === true && !this.onBack; }
  private hubHeaderInset(): number {
    return this.getUIContext().px2vp(this.statusBarHeightPx) + 80;
  }
  private hubChromeHeight(): number { return this.hubTab === 'collages' ? 52 : 112; }
  private hubCollapseHeight(): number { return this.hubChromeHeight(); }
  private hubHeaderBackgroundOpacity(): number {
    return 1 - Math.max(0, Math.min(1, this.hubChromeOffset / this.hubCollapseHeight()));
  }
  private hubChromeVisibleHeight(): number {
    return Math.max(0, this.hubCollapseHeight() - this.hubChromeOffsetVp);
  }
  private hubContentInset(): number {
    if (!this.modern() || !this.hubPane) return 0;
    return this.hubHeaderInset() + this.hubCollapseHeight();
  }
  private profileBodyTopInset(): number {
    if (!this.onBack && !this.modern()) return this.getUIContext().px2vp(this.statusBarHeightPx) + 56;
    return this.hubContentInset();
  }
  private updateHubChrome(offset: number, state: ScrollState, position: number): void {
    if (!this.modern() || !this.interactionReady || this.refreshing || this.loading || this.sortVisible) return;
    if (position <= 1) {
      this.hubChromeScrollDistance = 0;
      this.setHubChromeCollapsed(false);
      return;
    }
    if (state !== ScrollState.Scroll || !Number.isFinite(offset) || Math.abs(offset) < 0.1) return;
    if (this.hubChromeScrollDistance * offset < 0) this.hubChromeScrollDistance = 0;
    this.hubChromeScrollDistance += offset;
    if (Math.abs(this.hubChromeScrollDistance) < 10) return;
    const collapsed: boolean = this.hubChromeScrollDistance > 0;
    this.hubChromeScrollDistance = 0;
    this.setHubChromeCollapsed(collapsed);
  }
  private registerHubScroller(tab: string, scroller: Scroller): void {
    const index: number = ['pins','boards','collages'].indexOf(tab);
    if (index < 0 || this.hubPaneScrollers[index] === scroller) return;
    const scrollers: Scroller[] = this.hubPaneScrollers.slice();
    scrollers[index] = scroller;
    this.hubPaneScrollers = scrollers;
  }
  private setHubChromeCollapsed(collapsed: boolean): void {
    this.hubChromeScrollDistance = 0;
    const target: number = collapsed ? this.hubCollapseHeight() : 0;
    if (this.hubChromeOffset === target) return;
    this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.hubChromeOffset = target;
    });
  }
  private layoutChanged(): void {
    if(this.hubPane)return;
    this.hubRequested = false;
    if(this.modern())this.requestHub();else if(this.profile.hubMode && this.onTab)this.onTab('saved');
  }
  private retainHubSnapshot(): void {
    if(this.hubPane || !this.modern() || !this.profile.hubMode)return;
    const tab: string = ['boards','groups','secret'].includes(this.profile.hubMode) ? 'boards' : this.profile.hubMode === 'drafts' ? 'collages' : this.profile.hubMode;
    this.hubSnapshots = this.hubSnapshots.filter((p: PinmonyProfileSnapshot): boolean => {
      const oldTab: string = ['boards','groups','secret'].includes(p.hubMode || '') ? 'boards' : p.hubMode === 'drafts' ? 'collages' : p.hubMode || '';
      return oldTab !== tab && p.profileUrl === this.profile.profileUrl && p.session === this.profile.session;
    }).concat([this.profile]);
  }
  private hubSnapshot(tab: string): PinmonyProfileSnapshot {
    const saved: PinmonyProfileSnapshot | undefined = this.hubSnapshots.find((p: PinmonyProfileSnapshot): boolean => {
      const oldTab: string = ['boards','groups','secret'].includes(p.hubMode || '') ? 'boards' : p.hubMode === 'drafts' ? 'collages' : p.hubMode || '';
      return oldTab === tab && p.profileUrl === this.profile.profileUrl && p.session === this.profile.session;
    });
    if(saved)return saved;
    const pending: PinmonyProfileSnapshot = JSON.parse(JSON.stringify(this.profile)) as PinmonyProfileSnapshot;
    pending.hubMode = tab;pending.section = tab === 'boards' ? 'saved' : 'created';
    pending.boards = [];pending.createdPins = [];pending.unorganizedPins = [];pending.suggestions = [];
    pending.contentLoading = true;pending.contentError = '';pending.contentHasMore = false;
    return pending;
  }
  @Builder
  private hubPager() {
    Column() {
      Stack({alignContent:Alignment.TopStart}) {
      Swiper(this.hubSwiper) {
        ForEach(['pins','boards','collages'], (tab: string) => {
          PinmonyProfilePage({
            onHubScrollerReady: (scroller: Scroller) => this.registerHubScroller(tab, scroller),
            hubPane:true,hubChromeOffsetVp:this.hubChromeOffset,denseHubPins:this.densePins,profile:this.hubSnapshot(tab),interactionReady:this.interactionReady && this.hubTab === tab,
            readsReady:this.readsReady && this.hubTab === tab,actionsReady:this.actionsReady && this.hubTab === tab,
            automaticLoadingEnabled:this.automaticLoadingEnabled && this.hubTab === tab,
            refreshing:this.refreshing && this.hubTab === tab,initialScrollOffset:0,
            onBoard:this.onBoard,onPin:this.onPin,onPinMore:this.onPinMore,onOrganize:this.onOrganize,onSearch:this.onSearch,onPublish:this.onPublish,
            onRetry:this.onRetry,onRefresh:this.onRefresh,onLoadMore:this.onLoadMore,
            onContentScroll:this.onContentScroll,
            onHubScroll:(offset: number,state: ScrollState,position: number) => {
              if(this.hubTab === tab)this.updateHubChrome(offset,state,position);
            },
            onScrollPosition:this.onScrollPosition,
            onBoardSort:this.onBoardSort,onBoardVisibility:this.onBoardVisibility,onBoardRecovery:this.onBoardRecovery,
            onTab:(section: string) => {
              if(section.startsWith('hub:')) {
                const parts: string[] = section.split(':');
                if(parts[1] === 'pins'){this.favoriteFilter = parts[2] === '1';this.createdFilter = parts[3] === '1';}
                if(['boards','groups','secret'].includes(parts[1]))this.boardFilter = parts[1] === 'boards' ? '' : parts[1];
                if(['collages','drafts'].includes(parts[1]))this.collageDrafts = parts[1] === 'drafts';
              }
              if(this.onTab)this.onTab(section);
            }
          }).width('100%').height('100%')
        }, (tab: string): string => tab)
      }.index(['pins','boards','collages'].indexOf(this.hubTab))
        .loop(false).indicator(false).itemSpace(16).duration(280).cachedCount(2)
        .disableSwipe(!this.interactionReady || this.profile.suggestionWriting || this.sortVisible)
        .onChange((index: number) => {
          const tab: string = ['pins','boards','collages'][index];
          if(tab && this.hubTab !== tab){this.setHubChromeCollapsed(false);this.sortVisible = false;this.hubTab = tab;this.requestHub();}
        })
        .onContentDidScroll((selectedIndex: number,index: number,position: number,_mainAxisLength: number) => {
          if(index === selectedIndex)this.hubIndicatorPosition = Math.max(0,Math.min(2,index - position));
          if(index === 1)this.hubSearchPosition = Math.max(-1,Math.min(0,position));
        })
        .onAnimationEnd((index: number) => {this.hubIndicatorPosition = index;this.hubSearchPosition = index === 2 ? -1 : 0;})
        .width('100%').height('100%')
      }.width('100%').layoutWeight(1).clip(true)
        .onAreaChange((_old: Area,area: Area) => {const width: number = Number(area.width);if(width > 0)this.contentWidth = width;})
    }.width('100%').height('100%')
  }
  private requestHub(): void {
    if(!this.modern() || !this.onTab)return;
    this.hubRequested = true;
    const mode: string = this.hubTab === 'boards' ? this.boardFilter || 'boards' : this.hubTab === 'collages' && this.collageDrafts ? 'drafts' : this.hubTab;
    this.onTab('hub:' + mode + ':' + (this.favoriteFilter ? '1' : '0') + ':' + (this.createdFilter ? '1' : '0'));
  }
  aboutToAppear(): void {
    if (this.hubPane && this.onHubScrollerReady) this.onHubScrollerReady(this.scroller);
    this.retainHubSnapshot();
    if (this.onBack) this.profilePaths.pushPath({ name: 'user-profile' }, false);
    if(this.profile.hubMode) {
      this.hubTab = ['groups','secret','boards'].includes(this.profile.hubMode) ? 'boards' : this.profile.hubMode === 'drafts' ? 'collages' : this.profile.hubMode;
      this.collageDrafts = this.profile.hubMode === 'drafts';
      this.boardFilter = ['groups','secret'].includes(this.profile.hubMode) ? this.profile.hubMode : '';
      this.favoriteFilter = this.profile.hubFavorite === true;this.createdFilter = this.profile.hubCreated === true;
    }
    if(!this.hubPane)this.hubSearchPosition = this.hubTab === 'collages' ? -1 : 0;
    this.restoringScroll = this.initialScrollOffset > 0;
    this.activeProfile = this.profile.profileUrl;
    this.activeSection = this.profile.section;
    if(!this.hubPane && this.modern() && !this.profile.hubMode)this.requestHub();
  }

  private interactionChanged(): void {
    if (!this.interactionReady) { this.sortVisible = false;this.pinViewOpen = false;this.recoveryRequested = false; }
  }
  private onProfileChanged(): void {
    if(this.sortVisible) PinmonyRuntimeLog.info('ProfileSortTrace: phase=panel-update hasSort=' + (!!this.profile.boardSort).toString() + ' busy=' + (!!this.profile.boardSortBusy).toString() + ' error=' + (!!this.profile.boardSortError).toString());
    this.retainHubSnapshot();
    if(this.hubPane && this.profile.hubMode){this.hubTab = ['boards','groups','secret'].includes(this.profile.hubMode) ? 'boards' : this.profile.hubMode === 'drafts' ? 'collages' : this.profile.hubMode;this.boardFilter = ['groups','secret'].includes(this.profile.hubMode) ? this.profile.hubMode : '';this.favoriteFilter = this.profile.hubFavorite === true;this.createdFilter = this.profile.hubCreated === true;this.collageDrafts = this.profile.hubMode === 'drafts';}
    if(!this.hubPane && this.legacyProfile && this.profile.hubMode && !this.profile.suggestionWriting && this.onTab)this.onTab('saved');
    if(!this.hubPane && this.modern() && !this.profile.hubMode && !this.hubRequested)this.requestHub();
    if (this.pendingVisibility !== undefined && this.profile.showAllPins === this.pendingVisibility && !this.profile.visibilityError) {
      this.pendingVisibility = undefined;
      this.sortVisible = false;
    } else if (this.profile.visibilityError) this.pendingVisibility = undefined;
    if (this.activeProfile !== this.profile.profileUrl) { this.backRequested = false; this.profileNameBottom = 0; this.compactHeader = false; }
    if (this.activeProfile !== this.profile.profileUrl || this.activeSection !== this.profile.section) {
      this.sortVisible = false;
      this.activeProfile = this.profile.profileUrl;
      this.activeSection = this.profile.section;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    }
  }

  private restoreScroll(): void {
    setTimeout(() => {
      try { this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.initialScrollOffset), animation: false }); }
      catch (_) { console.warn('Pinmony: profile scroll restoration unavailable'); }
      this.updateCompactHeader();
      this.restoringScroll = false;
    }, 0);
  }

  private measureProfileName(area: Area): void {
    const bottom: number = Number(area.position.y) + Number(area.height);
    if (!Number.isFinite(bottom) || bottom <= 0) return;
    this.profileNameBottom = bottom;
    this.updateCompactHeader();
  }

  private updateCompactHeader(): void {
    const offset: number = this.scroller.offset()?.yOffset || 0;
    this.compactHeader = this.profileNameBottom > 0 && offset >= this.profileCoverHeight() + this.profileNameBottom;
  }

  private reportScroll(): void {
    if (this.restoringScroll) return;
    try {
      const offset: number = Math.max(0, this.scroller.offset()?.yOffset || 0);
      if (this.onScrollPosition) this.onScrollPosition(this.profile.profileUrl, this.profile.section, offset);
    } catch (_) { console.warn('Pinmony: profile scroll position unavailable'); }
  }

  private action(kind: string): PinmonyProfileAction | undefined {
    return this.profile.actions.find((item: PinmonyProfileAction): boolean => item.kind === kind);
  }

  private boardReady(board: PinmonyBoard): boolean {
    return !!board.targetUrl;
  }

  private perform(kind: string): void {
    if ((kind === 'followers' || kind === 'following' || kind === 'edit') && this.onAction) { this.onAction('', kind); return; }
    const item: PinmonyProfileAction | undefined = this.action(kind);
    if (item && item.enabled && this.onAction) this.onAction(item.id, kind);
  }

  private openSettings(): void {
    if (this.onSettings) this.onSettings();
  }

  private compactPinView(): boolean {
    return this.modern() && this.hubTab === 'pins' && this.pinDensity === 2;
  }
  private contentColumns(): number {
    if(this.modern() && this.hubTab === 'pins' && this.pinDensity === 0) return Math.max(1,Math.floor(this.contentWidth / 360));
    if(this.compactPinView()) return Math.max(3,Math.floor(this.contentWidth / 122));
    return Math.max(this.modern() && (this.densePins || this.denseHubPins) && this.hubTab !== 'boards' ? 3 : 2, Math.floor((this.contentWidth - 20) / 192));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let index: number = 0; index < this.contentColumns(); index++) slots.push(index);
    return slots;
  }

  private contentColumnsTemplate(): string {
    return this.columnSlots().map((): string => '1fr').join(' ');
  }

  private rowStarts(length: number): number[] {
    const starts: number[] = [];
    for (let index: number = 0; index < length; index += this.contentColumns()) starts.push(index);
    return starts;
  }

  private pinHeight(pin: PinmonyCreatedPin): number {
    const cardWidth: number = Math.max(this.modern() && this.hubTab === 'pins' ? 1 : 130, (this.contentWidth - 32 - (this.contentColumns() - 1) * 12) / this.contentColumns());
    if (pin.imageWidth <= 0 || pin.imageHeight <= 0) return cardWidth * 1.15;
    if(this.modern() && this.hubTab === 'pins') return cardWidth * pin.imageHeight / pin.imageWidth;
    return Math.max(160, Math.min(280, cardWidth * pin.imageHeight / pin.imageWidth));
  }

  @Builder
  private titleAction(icon: Resource, description: string, enabled: boolean, callback: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(icon)
        .fontSize(26)
        .fontColor([$r('app.color.primary_text')])
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(enabled)
    .opacity(enabled ? 1 : 0.4)
    .onClick(callback)
    .accessibilityText(description)
  }

  @Builder
  private sectionTab(section: string, nameKey: string) {
    Column({ space: 6 }) {
      Text(PinmonyI18n.text(nameKey, this.uiLanguage))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
      Column()
        .width(54)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.profile.section === section ? $r('app.color.primary_text') : Color.Transparent)
        .animation({ duration: 180, curve: Curve.EaseInOut })
    }
    .height(48)
    .justifyContent(FlexAlign.End)
    .onClick(() => {
      if (!this.interactionReady || !this.onTab || this.profile.section === section) return;
      this.sectionMotion = section === 'saved' ? 18 : -18;
      this.onTab(section);
      setTimeout(() => { this.sectionMotion = 0; }, 180);
    })
    .accessibilityText(PinmonyI18n.text(nameKey, this.uiLanguage))
    .accessibilitySelected(this.profile.section === section)
  }

  @Builder
  private profileHeader() {
    Column({ space: 9 }) {
      if (this.profile.business || this.profile.isOwn === false) {
        Row({ space: 16 }) {
          PinmonyUserAvatar({ image: this.profile.avatarUrl, name: this.profile.displayName || this.profile.handle, avatarSize: 72 }).onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); })
          Column({ space: 4 }) {
            Text(this.profile.displayName || this.profile.handle).fontSize(this.profile.isOwn === false ? 20 : 24).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).width('100%')
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.profile.handle) {
              Text(this.profile.handle).fontSize(14).fontColor($r('app.color.secondary_text'))
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').onAreaChange((_old: Area, area: Area) => this.measureProfileName(area))
      } else {
      PinmonyUserAvatar({ image: this.profile.avatarUrl, name: this.profile.displayName || this.profile.handle, avatarSize: 108 })
      .width(108)
      .height(108)
      .accessibilityText(this.uiText("pm_profile_picture_5c814f4f")).onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); })

      Text(this.profile.displayName || this.profile.handle)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onAreaChange((_old: Area, area: Area) => { if (!this.profile.handle) this.measureProfileName(area); })
      if (this.profile.handle) {
        Text(this.profile.handle).fontSize(14).fontColor($r('app.color.secondary_text'))
          .onAreaChange((_old: Area, area: Area) => this.measureProfileName(area))
      }
      if (this.profile.website || this.profile.about) {
        Text() {
          if (this.profile.website) {
            Span(this.profile.website.replace(/^https?:\/\//i, '').replace(/\/$/, ''))
              .fontWeight(FontWeight.Bold)
              .onClick(() => { if (this.onWebsite) this.onWebsite(this.profile.website || ''); })
          }
          if (this.profile.website && this.profile.about) { Span(' · ') }
          if (this.profile.about) { Span(this.profile.about) }
        }
        .width('100%').fontSize(14).fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
      }
      }
      Row({ space: 7 }) {
        if (this.profile.followers.length > 0) {
          Text(PinmonyI18n.render(this.profile.followers, this.uiLanguage))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .onClick(() => this.perform('followers'))
        }
        if (this.profile.followers.length > 0 && this.profile.following.length > 0) {
          Text('·')
            .fontSize(16)
            .fontColor($r('app.color.primary_text'))
        }
        if (this.profile.following.length > 0) {
          Text(PinmonyI18n.render(this.profile.following, this.uiLanguage))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .onClick(() => this.perform('following'))
        }
      }
      .margin({ top: 3 })

      if (this.profile.isOwn === false && this.profile.about) {
        Text(this.profile.about).fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
      } else if (this.profile.business && this.profile.isOwn !== false) {
        Text() {
          Span(this.profile.about || this.uiText("pm_about_this_account_581b25c0")).fontColor($r('app.color.secondary_text'))
          Span(this.uiText("pm_more_5a6d7865")).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        }.maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => { this.aboutVisible = true; })
      }
      if ((this.profile.business || this.profile.isOwn === false) && this.profile.website) {
        Row({ space: 8 }) {
          Image($r('app.media.lucide_globe')).width(20).height(20).fillColor($r('app.color.primary_text'))
          Text(this.profile.website.replace(/^https?:\/\//i, '').replace(/\/$/, '')).fontColor($r('app.color.primary_text')).fontSize(14)
            .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%').onClick(() => { if (this.onWebsite) this.onWebsite(this.profile.website || ''); })
          .accessibilityText(this.uiText("pm_open_website_in_browser_b91ebfa8"))
      }
      Row({ space: 10 }) {
        if (this.profile.isOwn === false) {
          Button(PinmonyI18n.render(this.action('follow')?.label || '', this.uiLanguage) || this.uiText("pm_follow_eb137dee"), { type: ButtonType.Normal }).height(44).padding({ left: 18, right: 18 }).borderRadius(16)
            .backgroundColor($r('app.color.detail_accent')).fontColor($r('app.color.detail_on_accent')).enabled(!this.followingBusy && !!this.action('follow') && this.action('follow')!.enabled).onClick(() => this.perform('follow'))
          if (this.action('contact') || this.action('message')) {
            Button(PinmonyI18n.render((this.action('contact') || this.action('message'))!.label, this.uiLanguage), { type: ButtonType.Normal })
              .height(44).padding({ left: 18, right: 18 }).borderRadius(16)
              .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text')).onClick(() => {})
          }
        }
        if (this.action('edit')) {
          if (!this.profile.business) {
          Button(this.uiText("pm_share_7e564575"), { type: ButtonType.Normal })
            .height(44)
            .padding({ left: 21, right: 21 })
            .borderRadius(16)
            .backgroundColor($r('app.color.surface_muted'))
            .fontColor($r('app.color.primary_text'))
            .enabled(this.action('edit')!.enabled)
            .onClick(() => { if (this.onShare) this.onShare(); })
          }
          Button(PinmonyI18n.render(this.action('edit')!.label, this.uiLanguage), { type: ButtonType.Normal })
            .height(44)
            .padding({ left: 21, right: 21 })
            .borderRadius(16)
            .backgroundColor($r('app.color.surface_muted'))
            .fontColor($r('app.color.primary_text'))
            .enabled(this.action('edit')!.enabled)
            .onClick(() => this.perform('edit'))
        }
      }
      .margin({ top: 8 })
      .justifyContent(this.profile.business || this.profile.isOwn === false ? FlexAlign.Start : FlexAlign.Center)
    }
    .width('100%')
    .alignItems(this.profile.business || this.profile.isOwn === false ? HorizontalAlign.Start : HorizontalAlign.Center)
    .padding({ left: 20, right: 20, top: 16 })

  }

  @Builder
  private aboutSheet() {
    Column({ space: 24 }) {
      Text(this.uiText("pm_about_e499019e") + this.profile.displayName).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      if (this.profile.about) { Text(this.profile.about).fontColor($r('app.color.primary_text')) }
      if (this.profile.website) {
        Row({ space: 16 }) {
          Image($r('app.media.lucide_globe')).width(24).height(24).fillColor($r('app.color.primary_text'))
          Text(this.profile.website).fontColor($r('app.color.primary_text')).layoutWeight(1)
        }.width('100%').constraintSize({ minHeight: 48 })
        .onClick(() => { if (this.onWebsite) this.onWebsite(this.profile.website || ''); })
        .accessibilityText(this.uiText("pm_open_website_in_browser_b91ebfa8"))
      }
      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.person_badge_plus')).fontSize(24).fontColor([$r('app.color.primary_text')])
        Text() {
          Span(PinmonyI18n.render(this.profile.followers, this.uiLanguage)).fontWeight(FontWeight.Bold)
          if (this.profile.monthlyViews !== undefined) {
            Span(' · ' + this.profile.monthlyViews.toString() + this.uiText("pm_monthly_views_39c13292"))
          }
        }.fontColor($r('app.color.primary_text')).layoutWeight(1)
      }.width('100%').constraintSize({ minHeight: 48 })
      .onClick(() => { this.aboutVisible = false; this.perform('followers'); })
      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.person_2')).fontSize(24).fontColor([$r('app.color.primary_text')])
        Text(PinmonyI18n.render(this.profile.following, this.uiLanguage)).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      }.width('100%').constraintSize({ minHeight: 48 })
      .onClick(() => { this.aboutVisible = false; this.perform('following'); })
      Blank().layoutWeight(1)
      if (this.profile.isOwn) {
        Button(this.uiText("pm_edit_profile_3b0b2bb8"), { type: ButtonType.Normal })
          .width('100%').height(48).borderRadius(16)
          .backgroundColor($r('app.color.surface_muted'))
          .fontColor($r('app.color.primary_text'))
          .onClick(() => { this.aboutVisible = false; this.perform('edit'); })
      }
    }.width('100%').height('100%').padding(24).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private boardCover(board: PinmonyBoard) {
    Stack({alignContent:Alignment.TopStart}) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface_muted'))
      if (board.covers.length === 1) {
        PinmonyBoardCoverImage({urls:board.coverAlternatives || [board.covers[0]]})
          .width('100%')
          .height('100%')
      } else if (board.covers.length > 1) {
        Row({ space: 2 }) {
          PinmonyBoardCoverImage({urls:board.coverAlternatives || [board.covers[0]]})
            .height('100%')
            .layoutWeight(2)
          Column({ space: 2 }) {
            Image(board.covers[1])
              .width('100%')
              .layoutWeight(1)
              .objectFit(ImageFit.Cover)
            if (board.covers.length > 2) {
              Image(board.covers[2])
                .width('100%')
                .layoutWeight(1)
                .objectFit(ImageFit.Cover)
            }
          }
          .height('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }
      if(board.secret) {
        Stack({alignContent:Alignment.Center}) {
          Image($r('app.media.board_private_lock')).width(16).height(16).fillColor($r('app.color.primary_text'))
        }.width(30).height(30).borderRadius(this.modern() ? 9 : 15).backgroundColor($r('app.color.page_background'))
          .margin({left:10,top:10}).accessibilityText(this.uiText('pm_secret_board_afc1422a'))
      }
    }
    .width('100%')
    .height(this.modern() ? Math.max(100,(this.contentWidth - 32 - (this.contentColumns() - 1) * 12) / this.contentColumns() * 0.66) : 158)
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private boardCard(board: PinmonyBoard) {
    Column({ space: 7 }) {
      this.boardCover(board)
      Row({ space: 6 }) {
        Text(PinmonyI18n.render(board.title, this.uiLanguage))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (board.collaboratorAvatars?.length) {
          Row() {
            ForEach(board.collaboratorAvatars || [], (avatar: string, index: number) => {
              Image(avatar).width(18).height(18).borderRadius(9).margin({ left: index > 0 ? -6 : 0 })
            }, (avatar: string) => avatar)
          }.constraintSize({ maxWidth: 54 }).clip(true).flexShrink(0)
        }
      }.width('100%')
      if (board.pinCount.length > 0 || board.updated.length > 0) {
        Text(PinmonyI18n.render(board.pinCount + (board.pinCount.length > 0 && board.updated.length > 0 ? ' · ' : '') + board.updated, this.uiLanguage))
          .fontSize(13)
          .fontColor($r('app.color.secondary_text'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    // A validated board route remains actionable while the profile content
    // refresh is still settling. Profile write actions have a separate gate.
    .enabled(this.boardReady(board))
    .onClick(() => { if (this.boardReady(board) && this.onBoard) this.onBoard(board.id); })
    .accessibilityText(board.title + (board.pinCount ? '，' + PinmonyI18n.render(board.pinCount, this.uiLanguage) : ''))
  }

  @Builder
  private createdPinCard(pin: PinmonyCreatedPin) {
    Column({ space: 7 }) {
      Image(pin.imageUrl)
        .width('100%')
        .height(this.pinHeight(pin))
        .objectFit(ImageFit.Cover)
        .borderRadius(16)
        .border({width:0.5,color:$r('app.color.surface_muted'),radius:16})
        .id('pinmony-profile-photo-' + pin.id)
        .onClick(() => { if (!pin.collageDraft && this.interactionReady && this.onPin) this.onPin(pin.id); })
      if (!this.compactPinView()) {
      Row({ space: 4 }) {
        if (pin.title.length > 0) {
          Text(PinmonyI18n.render(pin.title, this.uiLanguage))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .onClick(() => { if (!pin.collageDraft && this.interactionReady && this.onPin) this.onPin(pin.id); })
        } else {
          Blank().layoutWeight(1)
        }
        if(this.modern() && typeof pin.favorite === 'boolean') {
          SymbolGlyph(pin.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star')).fontSize(22).fontColor([$r('app.color.primary_text')])
            .accessibilityText(this.uiText('pm_profile_hub_favorites')).accessibilitySelected(pin.favorite)
        }
        if (pin.targetUrl) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(20).height(20).objectFit(ImageFit.Contain)
          }
          .width(32).height(32).padding(0).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onPinMore) this.onPinMore(pin.id); }).accessibilityText(this.uiText("pm_more_options_c611656f"))
        }
      }
      .width('100%')
      }
    }
    .layoutWeight(1)
    .enabled(this.interactionReady)
    .accessibilityText(pin.collageDraft ? this.uiText('pm_profile_hub_in_progress') : pin.title.length > 0 ? pin.title : this.uiText("pm_open_original_pin_42977656"))
  }

  @Builder
  private boardGroup(boards: PinmonyBoard[]) {
    ForEach(this.rowStarts(boards.length), (start: number) => {
      Row({ space: 12 }) {
        ForEach(this.columnSlots(), (column: number) => {
          if (start + column < boards.length) {
            this.boardCard(boards[start + column])
          } else {
            Blank().layoutWeight(1)
          }
        }, (column: number) => column.toString())
      }.width('100%').alignItems(VerticalAlign.Top).margin({ bottom: 24 })
    }, (start: number) => this.contentColumns().toString() + ':' + start.toString() + ':' + boards[start].id + ':' + this.uiLanguage + ':' + JSON.stringify(boards.slice(start, start + this.contentColumns())))
  }

  @Builder
  private profileContent() {
    if ((this.syncError || this.profile.contentError) && (this.profile.boards.length > 0 || this.profile.createdPins.length > 0)) {
      Column({ space: 8 }) {
        PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.syncError || this.profile.contentError || '', this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
      }.width('100%').margin({ bottom: 16 })
    }
    if (this.loading || this.profile.contentLoading) {
      Column({ space: 10 }) {
        LoadingProgress().color($r('app.color.accent')).width(32).height(32)
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if ((this.syncError || this.profile.contentError) && this.profile.boards.length === 0 && this.profile.createdPins.length === 0) {
      Column({ space: 12 }) {
        PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.syncError || this.profile.contentError || '', this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
    } else if (this.profile.section === 'saved' && this.profile.boards.length > 0) {
      this.boardGroup(this.profile.boards.filter((board: PinmonyBoard) => !board.protectedBoard))
      if (this.profile.boards.some((board: PinmonyBoard) => board.protectedBoard === true)) {
        Column({ space: 6 }) {
          Text(this.uiText('pm_profile_protected_boards_title'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          Text(this.uiText('pm_profile_protected_boards_description'))
            .fontSize(14).fontColor($r('app.color.secondary_text'))
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 8, bottom: 16 })
        this.boardGroup(this.profile.boards.filter((board: PinmonyBoard) => board.protectedBoard === true))
      }
    } else if (this.profile.section === 'created' && this.profile.createdPins.length > 0) {
      ForEach([this.contentColumnsTemplate()], (columns: string) => {
      WaterFlow() {
        ForEach(this.profile.createdPins, (pin: PinmonyCreatedPin) => {
          FlowItem() {
            this.createdPinCard(pin)
          }
          .width('100%')
        }, (pin: PinmonyCreatedPin) => pin.id + ':' + this.uiLanguage + ':' + JSON.stringify(pin))
      }
      .width('100%')
      .columnsTemplate(columns)
      .columnsGap(12)
      .rowsGap(14)
      }, (columns: string): string => columns)
    } else if(this.modern() && !this.profile.contentHasMore && !this.profile.contentError && !this.syncError) {
      this.hubEmptyState()
    } else {
      Column({ space: 12 }) {
        Text(this.modern() ? this.profile.contentHasMore ? this.uiText('pm_load_more_af90a08f') : this.uiText(this.favoriteFilter ? 'pm_profile_hub_favorite_empty' : 'pm_profile_hub_empty') : this.profile.section === 'saved' ? this.uiText("pm_no_saved_pins_yet_24c645e0") : this.uiText("pm_no_created_pins_yet_3a38cb23"))
          .fontSize(17)
          .fontColor($r('app.color.primary_text'))
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    if(this.modern() && this.hubTab === 'pins' && (this.favoriteFilter || this.createdFilter) && !this.profile.contentHasMore && !this.profile.contentLoading && !this.profile.contentError && this.profile.createdPins.length > 0) {
      Text(PinmonyI18n.format('pm_profile_hub_result_count',[this.profile.createdPins.length.toString(),String(Number(this.favoriteFilter) + Number(this.createdFilter))],this.uiLanguage))
        .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).margin({top:28,bottom:28})
    }
    if(this.modern() && this.profile.contentHasMore && !this.profile.contentLoadingMore) {
      Button(this.uiText('pm_load_more_af90a08f')).onClick(() => {if(this.onLoadMore)this.onLoadMore();})
    }
    if (this.profile.contentLoadingMore) {
      LoadingProgress().color($r('app.color.accent')).width(28).height(28)
    }
  }

  private requestProfileBack(): void {
    if (this.backRequested || !this.onBack) return;
    this.backRequested = true;
    this.onBack();
  }

  private profileCoverHeight(): number {
    return this.profile.coverUrl && this.profile.isOwn === false ? Math.min(260, this.contentWidth * 0.52) : 0;
  }

  private profileTitleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: {
          backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
          menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
          titleStyle: { mainTitleColor: $r('app.color.primary_text') }
        } },
        originalStyle: { contentStyle: {
          backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
          menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
          titleStyle: { mainTitleColor: $r('app.color.primary_text') }
        }, backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
      content: { title: { mainTitle: '' }, stackBuilder: this.compactTitleBuilder,
        backIcon: { isEnabled: true, action: () => this.requestProfileBack() },
        menu: { value: [{ content: { icon: $r('app.media.lucide_share_2'), label: this.uiText("pm_share_profile_6cc3a1d5"), action: () => { if (this.onShare) this.onShare(); } } }] } } };
  }
  @Builder
  private compactTitle() {
    if (this.compactHeader) {
      Row({ space: 10 }) {
        PinmonyUserAvatar({ image: this.profile.avatarUrl, name: this.profile.displayName || this.profile.handle, avatarSize: 32 }).onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); })
        Text(this.profile.displayName || this.profile.handle).fontSize(18).fontWeight(FontWeight.Bold)
          .maxFontSize(18).minFontSize(12).heightAdaptivePolicy(TextHeightAdaptivePolicy.LAYOUT_CONSTRAINT_FIRST)
          .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }.padding({ left: 64, right: 72 }).width('100%').constraintSize({ maxHeight: 48 })
    }
  }
  @Builder
  private profileDestination(_name?: string, _param?: Object) {
    HdsNavDestination() { this.profileBody() }
      .titleBar(this.profileTitleOptions()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => { this.requestProfileBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (this.profile.organize) {
      PinmonyOrganizePage({ state: this.profile.organize,
          suggestionTitle: this.profile.suggestionTitle || '', pins: this.profile.unorganizedPins || [],
        pinsLoading: this.profile.unorganizedLoading === true, pinsError: this.profile.unorganizedError || '',
        pinsHasMore: this.profile.unorganizedHasMore === true,
        onAction: (action: string, value: string, secret: boolean) => {
          if (this.onOrganize) this.onOrganize(action, value, secret);
        } })
    } else if (this.onBack) {
      HdsNavigation(this.profilePaths) { Column().width('100%').height('100%') }
        .width('100%').height('100%').hideTitleBar(true).navDestination(this.profileDestination)
    } else {
      Stack({alignContent:Alignment.TopStart}) {
      if (this.modern() && !this.hubPane) {
      HdsNavigation() { this.profileBody() }
        .width('100%').height('100%')
        .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
        .titleBar(this.hubTitleBarOptions())
        .bindToScrollable([this.hubPaneScrollers[Math.max(0, ['pins','boards','collages'].indexOf(this.hubTab))]])
        .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
          { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .clip(false)
      Column().width('100%').height(this.hubHeaderInset())
        .backgroundColor($r('app.color.page_background'))
        .opacity(this.hubHeaderBackgroundOpacity())
        .position({x:0,y:0})
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
      Column() { this.hubHeader() }.width('100%').height(80)
        .position({x:0,y:this.getUIContext().px2vp(this.statusBarHeightPx)})
      } else if (!this.modern()) { this.legacyProfileNavigation() } else { this.profileBody() }
      }
        .width('100%').height('100%')
        .bindSheet($$this.sortVisible, this.boardSortSheet(), {
      height: SheetSize.FIT_CONTENT, showClose: true, backgroundColor: $r('app.color.page_background'),
      onWillAppear: () => { PinmonyRuntimeLog.info('ProfileSortTrace: phase=panel-appear hasSort=' + (!!this.profile.boardSort).toString() + ' busy=' + (!!this.profile.boardSortBusy).toString()); },
      onDisappear: () => {
        this.sortVisible = false;
        PinmonyRuntimeLog.info('ProfileSortTrace: phase=panel-disappear');
        if (!this.recoveryRequested) return;
        this.recoveryRequested = false;
        if (this.interactionReady && this.profile.isOwn === true && this.onBoardRecovery) this.onBoardRecovery();
      }
    })
    }
  }

  @Builder
  private rootCompactTitle() {
    if (this.compactHeader) {
      Row({ space: 10 }) {
        PinmonyUserAvatar({ image: this.profile.avatarUrl, name: this.profile.displayName || this.profile.handle, avatarSize: 32 }).onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); })
        Text(this.profile.displayName || this.profile.handle)
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 64 }).constraintSize({ maxHeight: 48 })
    }
  }

  @Builder
  private legacyProfileNavigation() {
    HdsNavigation() { this.profileBody() }
      .width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
      .titleBar(this.rootTitleBarOptions())
      .bindToScrollable([this.scroller])
      .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
        { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .clip(false)
  }

  private rootTitleBarOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
        style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'),
          scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'),
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
          systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
          originalStyle: {
            backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 },
            contentStyle: {
              menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
              titleStyle: { mainTitleColor: $r('app.color.primary_text') }
            }
          }
        },
        content: { title: { mainTitle: '' }, stackBuilder: this.rootCompactTitleBuilder,
          menu: { value: [{ content: { icon: $r('sys.symbol.gearshape'), label: this.uiText("pm_settings_df3d58c7"), action: () => this.openSettings() }, badge: this.updateUnread ? { value: '', accessibilityText: this.uiText('pm_new_version_available_596dd46c') } : undefined }] } }
      };
  }
  @Builder
  private boardSortOption(value: string, label: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(this.uiText(label)).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
        if (this.profile.boardSortBusy && this.profile.boardSortPending === value) {
          LoadingProgress().width(20).height(20).color($r('app.color.accent'))
        } else if (!this.profile.boardSortBusy && this.profile.boardSort === value) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(24).fontColor([$r('app.color.detail_accent')])
        }
      }.width('100%').padding({ left: 24, right: 20, top: 14, bottom: 14 })
    }.width('100%').padding(0).backgroundColor(Color.Transparent)
    .enabled(true)
    .accessibilityText(this.uiText(label)).accessibilitySelected(this.profile.boardSort === value)
    .onClick(() => { if (this.interactionReady && !this.profile.boardSortBusy && !this.profile.visibilityBusy && !this.profile.boardSortError && !!this.profile.boardSort) { if (value === 'custom') { this.sortVisible = false; this.customOrderVisible = true; } else if (this.onBoardSort) this.onBoardSort(value); } })
  }

  @Builder
  private boardSortSheet() {
    Column({ space: 0 }) {
      Text(this.uiText('pm_profile_board_sort')).fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start).padding({ left:24, right:64, top:16, bottom:16 })
      Text(this.uiText('pm_profile_sort_heading')).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.secondary_text')).width('100%').padding({ left:24, top:16, bottom:6 })
      if (this.profile.boardSortError) {
        PinmonyActionNotice({ active: this.interactionReady, message: this.uiText(this.profile.boardSortError || 'pm_profile_sort_load_error'), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => { if (this.onBoardSort) this.onBoardSort(''); }, actionEnabled: !this.profile.boardSortBusy })
      }
      if (!this.profile.boardSort && !this.profile.boardSortError && !this.profile.boardSortBusy) {
        LoadingProgress().width(24).height(24).color($r('app.color.accent')).margin(16)
      }
      this.boardSortOption('alphabetical', 'pm_profile_sort_name')
      this.boardSortOption('custom', 'pm_profile_sort_custom')
      this.boardSortOption('last_pinned_to', 'pm_profile_sort_recent')
      Text(this.uiText('pm_profile_layout_heading')).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.secondary_text')).width('100%').padding({ left:24, top:16, bottom:6 })
      this.boardVisibilityControl()
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Text(this.uiText('pm_board_recovery_title')).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text')).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.secondary_text')])
        }.width('100%').padding({ left: 24, right: 20, top: 14, bottom: 14 })
      }.width('100%').padding(0).backgroundColor(Color.Transparent)
        .enabled(true)
        .accessibilityText(this.uiText('pm_board_recovery_title'))
        .onClick(() => { if (this.interactionReady && !this.profile.boardSortBusy && !this.profile.visibilityBusy) { this.recoveryRequested = true; this.sortVisible = false; } })
    }.width('100%').padding({ bottom: 20 })
  }
  @Builder
  private boardVisibilityControl() {
    Column({ space:16 }) {
      Row({ space:16 }) {
        Column({ space:6 }) {
          Text(this.uiText('pm_profile_edit_board_visibility')).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
          Text(this.uiText('pm_profile_show_all_pins_description')).fontSize(14).fontColor($r('app.color.secondary_text'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.profile.visibilityBusy) {
          LoadingProgress().color($r('app.color.accent')).width(40).height(24)
        } else if (typeof this.profile.showAllPins === 'boolean') {
          Checkbox().select(this.profile.showAllPins === true).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12)
            .enabled(true)
            .onChange((value: boolean) => { if (this.interactionReady && !this.profile.visibilityBusy && !this.profile.visibilityError && value !== this.profile.showAllPins && this.onBoardVisibility) { this.pendingVisibility = value; this.onBoardVisibility(value); } })
            .accessibilityText(this.uiText('pm_profile_show_all_pins'))
        }
      }.width('100%')
      if (this.profile.visibilityError) {
        PinmonyActionNotice({ active: this.interactionReady, message: this.uiText(this.profile.visibilityError), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => { if (this.onBoardVisibility) this.onBoardVisibility(); } })
      }
    }.width('100%').padding({ left:24, right:20, top:14, bottom:14 }).backgroundColor(Color.Transparent)
  }

  @Builder
  private contentToolbar() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Image($r('app.media.inbox_search_outline')).width(20).height(20).fillColor($r('app.color.primary_text'))
          Text(this.uiText('pm_profile_content_search')).fontSize(16).fontColor($r('app.color.secondary_text'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }.width('100%').padding({ left: 14, right: 14 })
      }.layoutWeight(1).height(48).borderRadius(18).backgroundColor($r('app.color.input_surface'))
        .enabled(this.interactionReady).accessibilityText(this.uiText('pm_profile_search_your_pins'))
        .onClick(() => { if (this.onSearch) this.onSearch(); })
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.profile_sliders')).width(26).height(26).fillColor($r('app.color.primary_text'))
      }.width(48).height(48).backgroundColor($r('app.color.input_surface'))
        .enabled(this.interactionReady && this.readsReady && this.profile.section === 'saved')
        .accessibilityText(this.uiText('pm_profile_board_sort'))
        .onClick(() => { this.sortVisible = true; if (this.onBoardSort) this.onBoardSort(''); })
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus')).fontSize(28).fontColor([$r('app.color.primary_text')])
      }.width(48).height(48).backgroundColor($r('app.color.input_surface')).enabled(this.interactionReady)
        .accessibilityText(this.uiText('pm_publish_b61f333b'))
        .onClick(() => { if (this.onPublish) this.onPublish(); })
    }.width('100%').padding({ left: 16, right: 16 }).margin({ bottom: 18 })
  }
  private emptyKind(): string {
    if(this.hubTab === 'collages')return this.collageDrafts ? 'collage_drafts' : 'collages';
    if(this.hubTab === 'boards')return this.boardFilter === 'groups' ? 'groups' : 'boards';
    return this.favoriteFilter && this.createdFilter ? 'combined' : this.favoriteFilter ? 'favorites' : 'created';
  }
  private emptyIllustration(): Resource {
    const kind: string = this.emptyKind();
    if(kind === 'groups')return $r('app.media.profile_empty_groups');
    if(kind === 'collages' || kind === 'collage_drafts')return $r('app.media.profile_empty_collages');
    if(kind === 'favorites')return $r('app.media.profile_empty_favorites');
    if(kind === 'combined')return $r('app.media.profile_empty_combined');
    return $r('app.media.profile_empty_created');
  }
  @Builder
  private hubEmptyState() {
    Column({space:16}) {
      Image(this.emptyIllustration()).width(Math.min(240,this.contentWidth * 0.60)).height(Math.min(240,this.contentWidth * 0.60)).objectFit(ImageFit.Contain)
        .accessibilityLevel('no')
      Text(this.uiText('pm_profile_empty_' + this.emptyKind() + '_title')).fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center).margin({top:12})
      Text(this.uiText('pm_profile_empty_' + this.emptyKind() + '_body')).fontSize(17).fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center).constraintSize({maxWidth:340})
      if(this.emptyKind() === 'groups' || this.hubTab === 'collages') {
        Button(this.uiText(this.emptyKind() === 'groups' ? 'pm_profile_invite_collaborators' : 'pm_profile_create_collage'))
          .fontSize(18).fontWeight(FontWeight.Bold).height(50).borderRadius(18).backgroundColor($r('app.color.detail_accent')).fontColor(Color.White)
      }
    }.width('100%').padding({top:24,left:20,right:20,bottom:44})
  }
  private async createSuggestedBoard(board: PinmonyBoard): Promise<void> {
    if(!this.interactionReady || this.profile.contentLoadingMore)return;
    if(this.onTab)this.onTab('hub-create:' + board.id);
  }
  @Builder
  private hubSuggestions() {
    if((this.profile.suggestions || []).length > 0) {
      Column({space:12}) {
        Text(this.uiText('pm_profile_hub_suggestions')).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Scroll() {
          Row({space:12}) {
            ForEach(this.profile.suggestions || [], (board: PinmonyBoard) => {
              Column({space:6}) {
                Stack() {
                  Image(board.covers[0]).width(170).height(112).objectFit(ImageFit.Cover).borderRadius(18)
                  Button(this.uiText('pm_create_cde2cd07'), {type:ButtonType.Normal}).borderRadius(14).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
                    .enabled(this.interactionReady && !this.profile.contentLoadingMore && !this.profile.suggestionWriting && !(this.profile.suggestionUnavailableIds || []).includes(board.id)).onClick(() => this.createSuggestedBoard(board))
                }
                Text(board.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
                Text(PinmonyI18n.format('pm_value_pins_d1922567',[board.pinCount],this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
              }.alignItems(HorizontalAlign.Start).width(170)
            }, (board: PinmonyBoard): string => board.id + ':' + this.uiLanguage + ':' + JSON.stringify(board))
          }.constraintSize({minWidth:'100%'}).justifyContent(FlexAlign.Start).alignItems(VerticalAlign.Top)
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').align(Alignment.TopStart)
      }.alignItems(HorizontalAlign.Start).width('100%').margin({bottom:24})
    }
    if(this.profile.suggestionError) {
      PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.profile.suggestionError,this.uiLanguage), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => {if(this.onRetry)this.onRetry();} })
    }
  }
  private hubSelected(kind: string): boolean {
    if(kind === 'favorite')return this.favoriteFilter;
    if(kind === 'created')return this.createdFilter;
    if(kind === 'groups' || kind === 'secret')return this.boardFilter === kind;
    return kind === 'collage-drafts' ? this.collageDrafts : this.collageCreated;
  }
  @Builder
  private hubStateButton(label: string, kind: string) {
    Toggle({type:ToggleType.Button,isOn:this.hubSelected(kind)}) {
      Row({space:6}) {
        if(kind === 'favorite') {
          SymbolGlyph($r('sys.symbol.star_fill')).fontSize(18)
            .fontColor([this.hubSelected(kind) ? $r('app.color.page_background') : $r('app.color.primary_text')])
        }
        Text(this.uiText(label)).fontSize(16).fontWeight(FontWeight.Medium).maxLines(1)
          .fontColor(this.hubSelected(kind) ? $r('app.color.page_background') : $r('app.color.primary_text'))
      }.padding({left:16,right:16}).hitTestBehavior(HitTestMode.None)
    }.height(40).borderRadius(16)
      .backgroundColor(this.hubSelected(kind) ? $r('app.color.primary_text') : $r('app.color.surface_muted')).selectedColor($r('app.color.primary_text'))
      .accessibilityText(this.uiText(label)).accessibilitySelected(this.hubSelected(kind))
      .enabled(this.interactionReady && !this.profile.suggestionWriting)
      .onClick(() => {
        if(!this.interactionReady || this.profile.suggestionWriting)return;
        const value: boolean = !this.hubSelected(kind);
        if(kind === 'favorite')this.favoriteFilter = value;
        else if(kind === 'created')this.createdFilter = value;
        else if(kind === 'groups' || kind === 'secret')this.boardFilter = value ? kind : '';
        else {
          this.collageDrafts = kind === 'collage-drafts' && value;
          this.collageCreated = kind === 'collage-created' && value;
        }
        this.requestHub();
      })
  }
  private selectPinView(value: number): void {
    if(!this.pinViewOpen || !this.pinViewPage || this.pinViewPage!==this.profile.profileUrl || this.pinViewSession!==this.profile.session || !this.modern() || this.hubTab!=='pins' || !this.interactionReady || this.profile.suggestionWriting)return;
    PinmonyProfileLayoutPreference.savePinDensity(value);
    this.draftPinDensity=value;this.pinDensity=value;this.densePins=value===2;
  }
  private closePinView(): void {
    this.pinViewPage='';this.pinViewSession=-1;this.pinViewOpen=false;
  }
  @Builder
  private pinViewOption(key: string, value: number) {
    Button({type:ButtonType.Normal}) {
      Row() {
        Text(this.uiText(key)).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
        Checkbox().select(this.draftPinDensity===value).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text')).mark({strokeColor:Color.White})
          .width(24).height(24).margin(0).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }.width('100%')
    }.width('100%').height(48).backgroundColor(Color.Transparent).stateEffect(false).hoverEffect(HoverEffect.None).accessibilityChecked(this.draftPinDensity===value)
      .onClick(()=>{this.selectPinView(value);})
  }
  @Builder
  private pinViewSheet() {
    Column({space:0}) {
      Text(this.uiText('pm_board_view_density')).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%').margin({bottom:4})
      this.pinViewOption('pm_board_view_wide',0)
      this.pinViewOption('pm_board_view_default',1)
      this.pinViewOption('pm_board_view_compact',2)
    }.width('100%').padding({left:24,right:24,top:8,bottom:20})
  }

  @Builder
  private hubFilters() {
      Row({space:8}) {
        if(this.hubTab === 'pins') {
          Button({type:ButtonType.Normal}) {
            SymbolGlyph($r('sys.symbol.square_grid_2x2')).fontSize(22).fontColor([$r('app.color.primary_text')])
          }.width(40).height(40).borderRadius(14).backgroundColor($r('app.color.surface_muted'))
            .accessibilityText(this.uiText('pm_profile_layout_heading'))
            .enabled(this.interactionReady && !this.profile.suggestionWriting)
            .onClick(() => {this.pinViewPage=this.profile.profileUrl;this.pinViewSession=this.profile.session;this.draftPinDensity=this.pinDensity;this.pinViewOpen=true;})
            .bindSheet($$this.pinViewOpen,this.pinViewSheet(),{height:SheetSize.FIT_CONTENT,showClose:true,
              title:{title:this.uiText('pm_profile_layout_heading')},backgroundColor:$r('app.color.page_background'),
              onDisappear:()=>{this.closePinView();}})
          this.hubStateButton('pm_profile_hub_favorites','favorite')
          this.hubStateButton('pm_profile_hub_created','created')


        } else if(this.hubTab === 'boards') {
          Button({type:ButtonType.Normal}) {
            Row({space:6}) {
              Image($r('app.media.profile_sliders')).width(22).height(22).fillColor($r('app.color.primary_text'))
            }
          }.width(58).height(40).borderRadius(14).backgroundColor($r('app.color.surface_muted'))
            .accessibilityText(this.uiText('pm_profile_board_sort')).enabled(this.interactionReady && !this.boardFilter && !this.profile.suggestionWriting)
            .onClick(() => {this.sortVisible = true;if(this.onBoardSort)this.onBoardSort('');})
          this.hubStateButton('pm_profile_hub_groups','groups')
          this.hubStateButton('pm_profile_hub_secret','secret')
        } else {
          this.hubStateButton('pm_profile_hub_created','collage-created')
          this.hubStateButton('pm_profile_hub_in_progress','collage-drafts')
        }
      }.width('100%').padding({left:16,right:16,bottom:12})
  }
  @Builder
  private hubSearch() {

      Row({space:12}) {
        Button({type:ButtonType.Normal}) {
          Row({space:10}) {
            SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(22).fontColor([$r('app.color.primary_text')])
            Text(this.uiText('pm_search_your_pins_e0d101c6')).fontSize(17).fontColor($r('app.color.secondary_text')).layoutWeight(1)
          }.width('100%').padding({left:16,right:16})
        }.layoutWeight(1).height(48).backgroundColor(Color.Transparent).border({width:1,color:$r('app.color.secondary_text')}).borderRadius(18)
          .onClick(() => {if(this.onSearch)this.onSearch();}).enabled(this.interactionReady && !this.profile.suggestionWriting)
        Button({type:ButtonType.Circle}) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(30).fontColor([$r('app.color.primary_text')])
        }.width(44).height(44).backgroundColor($r('app.color.input_surface')).accessibilityText(this.uiText('pm_publish_b61f333b'))
          .onClick(() => {if(this.onPublish)this.onPublish();}).enabled(this.interactionReady && !this.profile.suggestionWriting)
      }.width('100%').padding({left:16,right:16,bottom:12})
  }
  @Builder
  private hubAvatar() {
    Image(this.profile.avatarUrl).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover)
      .accessibilityText(this.uiText('pm_settings_df3d58c7')).onClick(() => this.openSettings())
  }
  @Builder
  private hubHeader() {
    Column({space:12}) {
      Row({space:12}) {
        if (!this.avatarRight) { this.hubAvatar() }
        Stack({alignContent:Alignment.BottomStart}) {
        Row() {
          ForEach(['pins','boards','collages'], (tab: string) => {
            Button({type:ButtonType.Normal, stateEffect:false}) {
              Column({space:12}) {
                Text(this.uiText('pm_profile_hub_' + tab)).fontSize(18).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text'))
                Row().height(2).width('100%').backgroundColor(Color.Transparent)
              }.padding({top:12,bottom:12})
            }.layoutWeight(1).height(64).backgroundColor(Color.Transparent).hoverEffect(HoverEffect.None)
              .accessibilitySelected(this.hubTab === tab)
              .enabled(this.interactionReady && !this.profile.suggestionWriting)
              .onClick(() => {
                if(this.interactionReady && !this.profile.suggestionWriting && this.hubTab !== tab){
                  this.hubSearchPosition = tab === 'collages' ? -1 : 0;
                  this.setHubChromeCollapsed(false);
                  this.hubIndicatorPosition = ['pins','boards','collages'].indexOf(tab);
                  this.hubTab = tab;this.requestHub();
                }
              })
          }, (tab: string): string => tab + ':' + this.uiLanguage)
        }.width('100%').height(64)
        Row().height(2).width(24).backgroundColor($r('app.color.primary_text'))
          .translate({x:(this.hubIndicatorPosition < 0 ? ['pins','boards','collages'].indexOf(this.hubTab) : this.hubIndicatorPosition) * this.hubTabBarWidth / 3 + (this.hubTabBarWidth / 3 - 24) / 2,y:-12})
          .hitTestBehavior(HitTestMode.None)
        }.layoutWeight(1).height(64)
          .onAreaChange((_old: Area,area: Area) => {this.hubTabBarWidth = Number(area.width);})
        if (this.avatarRight) { this.hubAvatar() }
      }.width('100%')

    }.width('100%').padding({left:16,right:16,top:12,bottom:4})
  }
  private hubTitleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: {
        originalStyle: { backgroundStyle: { maskExtraHeight: 24 } },
        scrollEffectStyle: { backgroundStyle: { maskExtraHeight: 24 } },
        blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
        thermoCtrl: (this.immersiveLightMode !== 'off'),
        scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'),
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)
      },
      content: { title: { mainTitle: '' } }
    };
  }
  @Builder
  private profileRefreshIndicator() {
    Column() {
      LoadingProgress().width(24).height(24).color($r('app.color.accent'))
        .visibility(this.refreshing || this.profileRefreshState === RefreshStatus.Drag ||
          this.profileRefreshState === RefreshStatus.OverDrag ? Visibility.Visible : Visibility.Hidden)
    }.width('100%').height(64).justifyContent(FlexAlign.Center)
      .offset({ y: this.hubContentInset() })
      .hitTestBehavior(HitTestMode.None)
  }

  @State private profileRefreshState: RefreshStatus = RefreshStatus.Inactive;

  @Builder
  private profileBody() {

    Stack({alignContent:Alignment.TopStart}) {
    Column() {
      if(this.modern() && !this.hubPane) { this.hubPager() } else {
      Refresh({ refreshing: this.refreshing, builder: this.profileRefreshIndicator }) {
      Scroll(this.scroller) {
        Column() {
          if(this.modern()) { if(!this.hubPane)this.hubHeader() } else {
          if (this.profileCoverHeight() > 0) {
            Image(this.profile.coverUrl).width('100%').height(this.profileCoverHeight()).objectFit(ImageFit.Cover)
              .accessibilityText(this.uiText("pm_profile_cover_0ecaa53c"))
          }
          Column() {
            this.profileHeader()
          }.width('100%').constraintSize({ maxWidth: 760 })
          Row({ space: 38 }) {
            this.sectionTab('created', "pm_created_80bfa30d")
            this.sectionTab('saved', "pm_saved_471dd4d7")
          }
          .width('100%')
          .height(72)
          .margin({ top: this.profile.isOwn === false ? 16 : 34, bottom: this.profile.isOwn === true && !this.onBack ? 8 : 24 })
          .justifyContent(FlexAlign.Center)
          if (this.profile.isOwn === true && !this.onBack) { this.contentToolbar() }
          }
          Column() {
            if(this.modern() && this.hubTab === 'pins' && !this.favoriteFilter && !this.createdFilter) {
              this.hubSuggestions()
              Text(this.uiText('pm_profile_hub_saved')).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%').margin({top:12,bottom:16})
            }
            this.profileContent()
            if (this.profile.section === 'saved' && (!this.modern() || this.hubTab === 'boards' && !this.boardFilter)) { this.unorganizedContent() }
          }
          .width('100%')
          .translate({ x: this.sectionMotion })
          .opacity(this.sectionMotion === 0 ? 1 : 0.72)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .padding({ left: 16, right: 16, bottom: 116 })
        }
        .width('100%')
        .padding({top:this.profileBodyTopInset()})
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          const width: number = Number(newArea.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
        })
      }
      .height('100%')
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .clipContent(ContentClipMode.BOUNDARY)
      .clip(false)

      .onAppear(() => this.restoreScroll())
      .onDidScroll((_xOffset: number, offset: number, state: ScrollState) => {
          if(this.hubPane && !this.restoringScroll && this.interactionReady && this.onHubScroll) {
            this.onHubScroll(offset,state,this.scroller.offset()?.yOffset || 0);
          }
          this.updateCompactHeader();
          this.reportScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
      .onReachEnd(() => { if (this.automaticLoadingEnabled && (this.readsReady || this.actionsReady) && this.onLoadMore) this.onLoadMore(); })
      }
      .width('100%').layoutWeight(1)
      .pullToRefresh(this.interactionReady && !this.refreshing && !this.loading)
      .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
      .onStateChange((state: RefreshStatus) => { this.profileRefreshState = state; })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.aboutVisible, this.aboutSheet(), {
      radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
      onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyProfilePage.aboutVisible radius=four-corners-32vp'); },
      height: '75%', showClose: true, backgroundColor: $r('app.color.page_background') })
      if(this.modern() && this.hubPane) {
        Column({space:0}) {
          Column({space:0}) {
          if(this.hubTab !== 'collages') {
            Column() { this.hubSearch() }.width('100%').height(60)
          }
          Column() { this.hubFilters() }.width('100%').height(52)
          }.width('100%').height(this.hubCollapseHeight())
            .backgroundColor($r('app.color.page_background'))
        }.width('100%').height(this.hubChromeHeight())
          .position({x:0,y:this.hubHeaderInset()})
          .opacity(this.hubChromeVisibleHeight() / this.hubChromeHeight())
          .clip(true)
          .hitTestBehavior(this.hubChromeVisibleHeight() <= 0 ? HitTestMode.None : HitTestMode.Default)
          .accessibilityLevel(this.hubChromeVisibleHeight() <= 0 ? 'no-hide-descendants' : 'auto')
      }
    }.width('100%').height('100%')
  }

  @Builder
  private unorganizedContent() {
    if ((this.profile.unorganizedPins || []).length || this.profile.unorganizedLoading || this.profile.unorganizedError) {
      Column({ space: 16 }) {
        Divider()
        Row() {
          Text(this.uiText("pm_unorganized_ideas_0e240c35")).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text')).layoutWeight(1)
          Button(this.uiText("pm_organize_ff093473"), {type:ButtonType.Normal}).borderRadius(16).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .enabled((this.profile.unorganizedPins || []).length > 0 && !this.profile.unorganizedLoading)
            .onClick(() => { if (this.onOrganize) this.onOrganize('open', '', false); })
        }.width('100%')
        ForEach(this.rowStarts(Math.min(4, (this.profile.unorganizedPins || []).length)), (start: number) => {
          Row({ space: 12 }) {
            ForEach(this.columnSlots(), (column: number) => {
              if (start + column < Math.min(4, (this.profile.unorganizedPins || []).length)) {
                this.createdPinCard((this.profile.unorganizedPins || [])[start + column])
              } else { Blank().layoutWeight(1) }
            }, (column: number) => column.toString())
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (start: number) => this.contentColumns().toString() + ':' + start.toString())
        if (this.profile.unorganizedLoading) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
        else if (this.profile.unorganizedError) {
          PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.profile.unorganizedError, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onOrganize) this.onOrganize('retryPins', '', false); } })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 16 })
    }
  }
}
