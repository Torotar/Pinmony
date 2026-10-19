import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { PinmonyBoard, PinmonyCreatedPin, PinmonyProfileAction, PinmonyProfileSnapshot } from '../models/PinmonyProfile';
import { PinmonyOrganizePage } from './PinmonyOrganizePage';

@Component
export struct PinmonyProfilePage {
  @Prop automaticLoadingEnabled: boolean = true;
  @Prop @Watch('onProfileChanged') profile: PinmonyProfileSnapshot = {} as PinmonyProfileSnapshot;
  @Prop loading: boolean = false;
  @Prop readsReady: boolean = false;
  @Prop actionsReady: boolean = true;
  @Prop interactionReady: boolean = true;
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
  private readonly scroller: Scroller = new Scroller();
  onTab?: (section: string) => void;
  onBack?: () => void;
  onUser?: (url: string) => void;
  onWebsite?: (url: string) => void;
  private readonly profilePaths: NavPathStack = new NavPathStack();
  @State private headerHeight: number = 180;
  @State private compactHeader: boolean = false;
  @State private aboutVisible: boolean = false;
  @State private sectionMotion: number = 0;
  onAction?: (id: string, kind: string) => void;
  onBoard?: (id: string) => void;
  onPin?: (id: string) => void;
  onPinMore?: (id: string) => void;
  onPublish?: () => void;
  onSettings?: () => void;
  onShare?: () => void;
  @Prop followingBusy: boolean = false;
  onMenu?: () => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  onOrganize?: (action: string, value: string, secret: boolean) => void;

  aboutToAppear(): void {
    if (this.onBack) this.profilePaths.pushPath({ name: 'user-profile' }, false);
    this.restoringScroll = this.initialScrollOffset > 0;
    this.activeProfile = this.profile.profileUrl;
    this.activeSection = this.profile.section;
  }

  private onProfileChanged(): void {
    if (this.activeProfile !== this.profile.profileUrl) this.backRequested = false;
    if (this.activeProfile !== this.profile.profileUrl || this.activeSection !== this.profile.section) {
      this.activeProfile = this.profile.profileUrl;
      this.activeSection = this.profile.section;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    }
  }

  private restoreScroll(): void {
    setTimeout(() => {
      try { this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.initialScrollOffset), animation: false }); }
      catch (_) { console.warn('Pinmony: profile scroll restoration unavailable'); }
      this.restoringScroll = false;
    }, 0);
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

  private rowStarts(length: number): number[] {
    const starts: number[] = [];
    for (let index: number = 0; index < length; index += 2) starts.push(index);
    return starts;
  }

  private pinHeight(pin: PinmonyCreatedPin): number {
    const cardWidth: number = Math.max(130, (this.contentWidth - 44) / 2);
    if (pin.imageWidth <= 0 || pin.imageHeight <= 0) return cardWidth * 1.15;
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
  private sectionTab(section: string, name: string) {
    Column({ space: 6 }) {
      Text(name)
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
    .accessibilityText(name)
    .accessibilitySelected(this.profile.section === section)
  }

  @Builder
  private profileHeader() {
    Column({ space: 9 }) {
      if (this.profile.business || this.profile.isOwn === false) {
        Row({ space: 16 }) {
          if (this.profile.avatarUrl) { Image(this.profile.avatarUrl).width(72).height(72).borderRadius(36)
            .onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); }) }
          Column({ space: 4 }) {
            Text(this.profile.displayName || this.profile.handle).fontSize(this.profile.isOwn === false ? 20 : 24).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).width('100%')
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.profile.handle) {
              Text(this.profile.handle).fontSize(14).fontColor($r('app.color.secondary_text'))
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%')
      } else {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(108)
          .height(108)
          .backgroundColor($r('app.color.detail_accent'))
          .borderRadius(54)
        if (this.profile.avatarUrl.length > 0) {
          Image(this.profile.avatarUrl)
            .width(108)
            .height(108)
            .borderRadius(54)
            .objectFit(ImageFit.Cover)
        } else {
          Text((this.profile.displayName || this.profile.handle).slice(0, 1).toUpperCase())
            .fontSize(52)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.detail_on_accent'))
        }
      }
      .width(108)
      .height(108)
      .accessibilityText('个人头像').onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); })

      Text(this.profile.displayName || this.profile.handle)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.profile.handle) {
        Text(this.profile.handle).fontSize(14).fontColor($r('app.color.secondary_text'))
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
          Text(this.profile.followers)
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
          Text(this.profile.following)
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
          Span(this.profile.about || '关于此账户……').fontColor($r('app.color.secondary_text'))
          Span(' 更多').fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        }.maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => { this.aboutVisible = true; })
      }
      if ((this.profile.business || this.profile.isOwn === false) && this.profile.website) {
        Row({ space: 8 }) {
          Image($r('app.media.lucide_globe')).width(20).height(20).fillColor($r('app.color.primary_text'))
          Text(this.profile.website.replace(/^https?:\/\//i, '').replace(/\/$/, '')).fontColor($r('app.color.primary_text')).fontSize(14)
            .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%').onClick(() => { if (this.onWebsite) this.onWebsite(this.profile.website || ''); })
          .accessibilityText('在浏览器中打开网站')
      }
      Row({ space: 10 }) {
        if (this.profile.isOwn === false) {
          Button(this.action('follow')?.label || '关注', { type: ButtonType.Normal }).height(44).padding({ left: 18, right: 18 }).borderRadius(16)
            .backgroundColor($r('app.color.detail_accent')).fontColor($r('app.color.detail_on_accent')).enabled(!this.followingBusy && !!this.action('follow') && this.action('follow')!.enabled).onClick(() => this.perform('follow'))
          if (this.action('contact') || this.action('message')) {
            Button((this.action('contact') || this.action('message'))!.label, { type: ButtonType.Normal })
              .height(44).padding({ left: 18, right: 18 }).borderRadius(16)
              .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text')).onClick(() => {})
          }
        }
        if (this.action('edit')) {
          if (!this.profile.business) {
          Button('分享', { type: ButtonType.Normal })
            .height(44)
            .padding({ left: 21, right: 21 })
            .borderRadius(16)
            .backgroundColor($r('app.color.surface_muted'))
            .fontColor($r('app.color.primary_text'))
            .enabled(this.action('edit')!.enabled)
            .onClick(() => { if (this.onShare) this.onShare(); })
          }
          Button(this.action('edit')!.label, { type: ButtonType.Normal })
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
    .onAreaChange((_old: Area, area: Area) => { this.headerHeight = Number(area.height); })
  }

  @Builder
  private aboutSheet() {
    Column({ space: 24 }) {
      Text('关于 ' + this.profile.displayName).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      if (this.profile.about) { Text(this.profile.about).fontColor($r('app.color.primary_text')) }
      if (this.profile.website) {
        Row({ space: 16 }) {
          Image($r('app.media.lucide_globe')).width(24).height(24).fillColor($r('app.color.primary_text'))
          Text(this.profile.website).fontColor($r('app.color.primary_text')).layoutWeight(1)
        }.width('100%').constraintSize({ minHeight: 48 })
        .onClick(() => { if (this.onWebsite) this.onWebsite(this.profile.website || ''); })
        .accessibilityText('在浏览器中打开网站')
      }
      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.person_badge_plus')).fontSize(24).fontColor([$r('app.color.primary_text')])
        Text() {
          Span(this.profile.followers).fontWeight(FontWeight.Bold)
          if (this.profile.monthlyViews !== undefined) {
            Span(' · ' + this.profile.monthlyViews.toString() + ' 月浏览量')
          }
        }.fontColor($r('app.color.primary_text')).layoutWeight(1)
      }.width('100%').constraintSize({ minHeight: 48 })
      .onClick(() => { this.aboutVisible = false; this.perform('followers'); })
      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.person_2')).fontSize(24).fontColor([$r('app.color.primary_text')])
        Text(this.profile.following).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      }.width('100%').constraintSize({ minHeight: 48 })
      .onClick(() => { this.aboutVisible = false; this.perform('following'); })
      Blank().layoutWeight(1)
      if (this.profile.isOwn) {
        Button('编辑个人资料', { type: ButtonType.Normal })
          .width('100%').height(48).borderRadius(16)
          .backgroundColor($r('app.color.surface_muted'))
          .fontColor($r('app.color.primary_text'))
          .onClick(() => { this.aboutVisible = false; this.perform('edit'); })
      }
    }.width('100%').height('100%').padding(24).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private boardCover(board: PinmonyBoard) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface_muted'))
      if (board.covers.length === 1) {
        Image(board.covers[0])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else if (board.covers.length > 1) {
        Row({ space: 2 }) {
          Image(board.covers[0])
            .height('100%')
            .layoutWeight(2)
            .objectFit(ImageFit.Cover)
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
    }
    .width('100%')
    .height(158)
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private boardCard(board: PinmonyBoard) {
    Column({ space: 7 }) {
      this.boardCover(board)
      Row({ space: 6 }) {
        Text(board.title)
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
        Text(board.pinCount + (board.pinCount.length > 0 && board.updated.length > 0 ? ' · ' : '') + board.updated)
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
    .accessibilityText(board.title + (board.pinCount ? '，' + board.pinCount : ''))
  }

  @Builder
  private createdPinCard(pin: PinmonyCreatedPin) {
    Column({ space: 7 }) {
      Image(pin.imageUrl)
        .width('100%')
        .height(this.pinHeight(pin))
        .objectFit(ImageFit.Cover)
        .borderRadius(16)
        .onClick(() => { if (this.interactionReady && this.onPin) this.onPin(pin.id); })
      Row({ space: 4 }) {
        if (pin.title.length > 0) {
          Text(pin.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .onClick(() => { if (this.interactionReady && this.onPin) this.onPin(pin.id); })
        } else {
          Blank().layoutWeight(1)
        }
        if (pin.targetUrl) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(20).height(20).objectFit(ImageFit.Contain)
          }
          .width(32).height(32).padding(0).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onPinMore) this.onPinMore(pin.id); }).accessibilityText('更多选项')
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .enabled(this.interactionReady)
    .accessibilityText(pin.title.length > 0 ? pin.title : '打开原创 Pin')
  }

  @Builder
  private profileContent() {
    if (this.syncError || this.profile.contentError) {
      Column({ space: 8 }) {
        Text(this.syncError || this.profile.contentError || '')
          .fontSize(14).fontColor($r('app.color.secondary_text'))
        Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
      }.width('100%').margin({ bottom: 16 })
    }
    if (this.loading || this.profile.contentLoading) {
      Column({ space: 10 }) {
        LoadingProgress().width(32).height(32)
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.profile.contentError && this.profile.boards.length === 0 && this.profile.createdPins.length === 0) {
      Column({ space: 12 }) {
        Text(this.profile.contentError)
          .fontSize(17)
          .fontColor($r('app.color.primary_text'))
        Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
    } else if (this.profile.section === 'saved' && this.profile.boards.length > 0) {
      ForEach(this.rowStarts(this.profile.boards.length), (start: number) => {
        Row({ space: 12 }) {
          this.boardCard(this.profile.boards[start])
          if (start + 1 < this.profile.boards.length) {
            this.boardCard(this.profile.boards[start + 1])
          } else {
            Blank().layoutWeight(1)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: 24 })
      }, (start: number) => this.profile.boards[start].id + ':' +
        (start + 1 < this.profile.boards.length ? this.profile.boards[start + 1].id : ''))
    } else if (this.profile.section === 'created' && this.profile.createdPins.length > 0) {
      WaterFlow() {
        ForEach(this.profile.createdPins, (pin: PinmonyCreatedPin) => {
          FlowItem() {
            this.createdPinCard(pin)
          }
          .width('100%')
        }, (pin: PinmonyCreatedPin) => pin.id)
      }
      .width('100%')
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(14)
    } else {
      Column({ space: 12 }) {
        Text(this.profile.section === 'saved' ? '尚未收藏 Pin 图' : '尚未创建 Pin 图')
          .fontSize(17)
          .fontColor($r('app.color.primary_text'))
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    if (this.profile.contentLoadingMore) {
      LoadingProgress().width(28).height(28)
    } else if (this.profile.contentError && (this.profile.boards.length > 0 || this.profile.createdPins.length > 0)) {
      Button('加载更多失败，重试').onClick(() => { if (this.onRetry) this.onRetry(); })
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
      style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: {
        backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: '' }, stackBuilder: this.compactTitleBuilder,
        backIcon: { isEnabled: true, action: () => this.requestProfileBack() },
        menu: { value: [{ content: { icon: $r('app.media.lucide_share_2'), label: '分享个人资料', action: () => { if (this.onShare) this.onShare(); } } }] } } };
  }
  @Builder
  private compactTitle() {
    if (this.compactHeader) {
      Row({ space: 10 }) {
        if (this.profile.avatarUrl) { Image(this.profile.avatarUrl).width(32).height(32).borderRadius(16)
          .onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); }) }
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
      PinmonyOrganizePage({ state: this.profile.organize, pins: this.profile.unorganizedPins || [],
        pinsLoading: this.profile.unorganizedLoading === true, pinsError: this.profile.unorganizedError || '',
        pinsHasMore: this.profile.unorganizedHasMore === true,
        onAction: (action: string, value: string, secret: boolean) => {
          if (this.onOrganize) this.onOrganize(action, value, secret);
        } })
    } else if (this.onBack) {
      HdsNavigation(this.profilePaths) { Column().width('100%').height('100%') }
        .width('100%').height('100%').hideTitleBar(true).navDestination(this.profileDestination)
    } else { this.profileBody() }
  }

  @Builder
  private profileBody() {

    Column() {
      if (!this.onBack) {
      Row() {
        if (this.compactHeader) {
          if (this.profile.avatarUrl) { Image(this.profile.avatarUrl).width(32).height(32).borderRadius(16)
            .margin({ right: 10 })
            .onClick(() => { if (this.onUser) this.onUser(this.profile.profileUrl); }) }
          Text(this.profile.displayName || this.profile.handle).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text')).layoutWeight(1).maxLines(1)
        } else { Blank() }
        this.titleAction($r('sys.symbol.plus'), '发布', true, () => {
          if (this.onPublish) this.onPublish();
        })
        this.titleAction($r('sys.symbol.gearshape'), '设置', true,
          () => this.openSettings())
      }
      .height(56)
      .padding({ left: 18, right: 12 })
      .width('100%')

      }
      Refresh({ refreshing: this.refreshing }) {
      Scroll(this.scroller) {
        Column() {
          if (this.profileCoverHeight() > 0) {
            Image(this.profile.coverUrl).width('100%').height(this.profileCoverHeight()).objectFit(ImageFit.Cover)
              .accessibilityText('个人资料封面')
          }
          this.profileHeader()
          Row({ space: 38 }) {
            this.sectionTab('created', '已创建')
            this.sectionTab('saved', '已收藏')
          }
          .width('100%')
          .height(72)
          .margin({ top: this.profile.isOwn === false ? 16 : 34, bottom: 24 })
          .justifyContent(FlexAlign.Center)
          Column() {
            this.profileContent()
            if (this.profile.section === 'saved') { this.unorganizedContent() }
          }
          .width('100%')
          .translate({ x: this.sectionMotion })
          .opacity(this.sectionMotion === 0 ? 1 : 0.72)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .padding({ left: 16, right: 16, bottom: 116 })
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
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
      .onAppear(() => this.restoreScroll())
      .onDidScroll((_xOffset: number, offset: number, state: ScrollState) => {
          this.compactHeader = (this.scroller.offset()?.yOffset || 0) > this.headerHeight + this.profileCoverHeight();
          this.reportScroll();
          if (this.onContentScroll) this.onContentScroll(offset, state);
        })
      .onReachEnd(() => { if (this.automaticLoadingEnabled && (this.readsReady || this.actionsReady) && this.onLoadMore) this.onLoadMore(); })
      }
      .width('100%').layoutWeight(1)
      .pullToRefresh(this.interactionReady && !this.refreshing && !this.loading)
      .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.aboutVisible, this.aboutSheet(), {
      radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
      onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyProfilePage.aboutVisible radius=four-corners-32vp'); },
      height: '75%', showClose: true, backgroundColor: $r('app.color.page_background') })
  }

  @Builder
  private unorganizedContent() {
    if ((this.profile.unorganizedPins || []).length || this.profile.unorganizedLoading || this.profile.unorganizedError) {
      Column({ space: 16 }) {
        Divider()
        Row() {
          Text('未整理的点子').fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text')).layoutWeight(1)
          Button('整理').backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .enabled((this.profile.unorganizedPins || []).length > 0 && !this.profile.unorganizedLoading)
            .onClick(() => { if (this.onOrganize) this.onOrganize('open', '', false); })
        }.width('100%')
        ForEach(this.rowStarts(Math.min(4, (this.profile.unorganizedPins || []).length)), (start: number) => {
          Row({ space: 12 }) {
            this.createdPinCard((this.profile.unorganizedPins || [])[start])
            if (start + 1 < (this.profile.unorganizedPins || []).length) {
              this.createdPinCard((this.profile.unorganizedPins || [])[start + 1])
            } else { Blank().layoutWeight(1) }
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (start: number) => start.toString())
        if (this.profile.unorganizedLoading) { LoadingProgress().width(28).height(28) }
        else if (this.profile.unorganizedError) {
          Text(this.profile.unorganizedError).fontSize(14).fontColor($r('app.color.secondary_text'))
          Button('重试').onClick(() => { if (this.onOrganize) this.onOrganize('retryPins', '', false); })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 16 })
    }
  }
}
