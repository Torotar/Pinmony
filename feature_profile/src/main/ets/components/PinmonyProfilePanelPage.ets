import { PinmonyHdsTitleBar } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { PinmonyProfilePanel, PinmonyProfilePanelItem } from '../models/PinmonyProfilePanel';
import { PinmonyUserAvatar } from 'common_ui';
@Component
export struct PinmonyProfilePanelPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private editTitleInset(): number { return this.snapshot.mode === 'edit' ? this.getUIContext().px2vp(this.statusBarHeightPx) + 56 : 0; }
  private contentTopInset(): number { return this.snapshot.mode === 'following' ? 0 : this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') @Watch('syncFollowingLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('syncUsername') snapshot: PinmonyProfilePanel;
  @Prop active: boolean = true;
  @State private followerQuery: string = '';
  @State private followerSearching: boolean = false;
  @State private searchMotionOffset: string = '0%';
  private followerSearchClosing: boolean = false;
  @State private panelRefreshState: RefreshStatus = RefreshStatus.Inactive;
  @State private searchHeaderHeight: number = 0;
  private readonly followingSegments: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: this.uiText("pm_profiles_0d0e1a86") }, { text: this.uiText("pm_board_bd3f17ee") }
  ]);
  private syncFollowingLanguage(): void {
    this.followingSegments[0].text = this.uiText('pm_profiles_0d0e1a86');
    this.followingSegments[1].text = this.uiText('pm_board_bd3f17ee');
  }
  private displayedSection: string = '';
  private sectionMotionToken: number = 0;
  @State private sectionOffset: number = 0;
  private selectFollowingSection(section: string): void {
    if (this.snapshot.mode !== 'following' || this.snapshot.loading || this.followingBusy || this.saving ||
        section === this.snapshot.section || !this.onSection) return;
    this.onSection(section);
  }
  private swipeFollowingSection(offsetX: number, offsetY: number): void {
    if (Math.abs(offsetX) < 48 || Math.abs(offsetX) <= Math.abs(offsetY)) return;
    if (offsetX < 0 && this.snapshot.section === 'users') this.selectFollowingSection('boards');
    else if (offsetX > 0 && this.snapshot.section === 'boards') this.selectFollowingSection('users');
  }
  private syncFollowingMotion(): void {
    if (this.snapshot.mode !== 'following' || this.snapshot.loading || this.displayedSection === this.snapshot.section) return;
    const previous: string = this.displayedSection;
    this.displayedSection = this.snapshot.section;
    if (!previous) return;
    const token: number = ++this.sectionMotionToken;
    this.sectionOffset = this.snapshot.section === 'boards' ? 32 : -32;
    setTimeout(() => {
      if (token !== this.sectionMotionToken) return;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => { this.sectionOffset = 0; });
    }, 16);
  }
  @State private usernameDraft: string = '';
  @State private firstNameDraft: string = '';
  @State private lastNameDraft: string = '';
  @State private aboutDraft: string = '';
  @State private websiteDraft: string = '';
  @Prop saving: boolean = false;
  private usernameToken: number = -1;
  private usernameFocused: boolean = false;
  private followerEndCheckToken: number = 0;
  private presentationToken: number = -1;
  private presentationMounted: boolean = false;
  private scrollRestoreToken: number = 0;
  private rootRestorePending: boolean = false;
  private searchRestorePending: boolean = false;
  private revealUsernameUrl(): void {
    setTimeout(() => {
      if (this.usernameFocused && this.snapshot.mode === 'edit') this.scroller.scrollEdge(Edge.Bottom);
    }, 350);
  }
  aboutToDisappear(): void { this.presentationMounted = false; this.scrollRestoreToken++; this.usernameFocused = false; this.sectionMotionToken++; this.followerEndCheckToken++; this.onSearchBackChange?.(undefined); }
  private syncUsername(): void {
    if (this.snapshot.mode === 'followers') this.followerQuery = this.snapshot.query || '';
    if (this.presentationMounted && this.presentationToken !== this.snapshot.token) this.restorePresentation();
    this.syncFollowingMotion();
    this.scheduleFollowerEndCheck();
    if (this.snapshot.mode === 'edit' && !this.snapshot.loading && this.usernameToken !== this.snapshot.token) {
      this.usernameDraft = this.snapshot.username;
      this.firstNameDraft = this.snapshot.firstName;
      this.lastNameDraft = this.snapshot.lastName;
      this.aboutDraft = this.snapshot.about;
      this.websiteDraft = this.snapshot.website;
      this.usernameToken = this.snapshot.token;
    }
  }
  onBack?: () => void;
  onCoveredBack?: () => boolean;
  onBoard?: (url: string) => void;
  onUser?: (url: string) => void;
  onSection?: (section: string) => void;
  onSave?: (input: string) => void;
  onFollow?: (id: string) => void;
  onLoadMore?: () => void;
  onRefresh?: () => void;
  onSearch?: (query: string) => void;
  onPresentationChange?: (searchOpen: boolean, scrollOffset: number, searchScrollOffset: number) => void;
  onSearchBackChange?: (handler: (() => boolean) | undefined) => void;
  private loadNextPage(): void {
    if (!this.followerSearching) this.loadVisiblePage();
  }
  private loadVisiblePage(): void {
    if (this.active && !this.rootRestorePending && !this.searchRestorePending && !this.snapshot.loading && !this.snapshot.refreshing && !this.snapshot.moreLoading && this.snapshot.hasMore && !this.snapshot.moreError && !this.followingBusy && !this.saving) this.onLoadMore?.();
  }
  private loadSearchPage(): void {
    if (this.followerSearching) this.loadVisiblePage();
  }
  private retainPresentation(): void {
    if (!this.active || this.rootRestorePending || this.searchRestorePending) return;
    this.onPresentationChange?.(this.followerSearching, this.scroller.currentOffset().yOffset, this.followerSearching ? this.searchScroller.currentOffset().yOffset : 0);
  }
  private openPanelUser(url: string): void {
    if (!this.active) return;
    this.retainPresentation();
    this.onUser?.(url);
  }
  private restorePresentation(): void {
    this.presentationToken = this.snapshot.token;
    this.rootRestorePending = (this.snapshot.scrollOffset || 0) > 0;
    this.searchRestorePending = this.snapshot.searchOpen === true;
    const searching: boolean = this.snapshot.mode === 'followers' && this.snapshot.searchOpen === true;
    if (searching) this.searchMotionOffset = '0%';
    if (searching !== this.followerSearching) {
      this.followerSearching = searching;
      if (searching) this.paths.pushPath({ name: 'follower-search' }, false);
      else this.paths.pop(false);
    }
    this.restoreScrollOffsets();
  }
  private restoreScrollOffsets(): void {
    const token: number = ++this.scrollRestoreToken;
    setTimeout((): void => {
      if (!this.presentationMounted || !this.active || token !== this.scrollRestoreToken) return;
      if (this.rootRestorePending) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: this.snapshot.scrollOffset || 0, animation: false });
        this.rootRestorePending = false;
      }
      if (this.searchRestorePending && this.searchHeaderHeight > 0) {
        this.searchScroller.scrollTo({ xOffset: 0, yOffset: this.snapshot.searchScrollOffset || 0, animation: false });
        this.searchRestorePending = false;
      }
    }, 32);
  }
  private scheduleFollowerEndCheck(): void {
    const token: number = ++this.followerEndCheckToken;
    if (this.snapshot.mode !== 'followers' || this.snapshot.loading || this.snapshot.moreLoading || !this.snapshot.hasMore || this.snapshot.moreError) return;
    setTimeout(() => {
      if (token === this.followerEndCheckToken && !this.followerSearching && this.scroller.isAtEnd()) this.loadNextPage();
    }, 100);
  }
  onAvatar?: () => void;
  private visibleItems(): PinmonyProfilePanelItem[] {
    const query: string = this.normalizeFollowerSearch(this.followerQuery.trim());
    if (!query) return this.snapshot.items;
    return this.snapshot.items.filter((item: PinmonyProfilePanelItem): boolean =>
      this.normalizeFollowerSearch(item.name).includes(query) || this.normalizeFollowerSearch(item.username || '').includes(query));
  }
  private normalizeFollowerSearch(text: string): string {
    return text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase();
  }
  @Prop followingBusy: boolean = false;
  private readonly paths: NavPathStack = new NavPathStack();
  private readonly scroller: Scroller = new Scroller();
  private readonly searchScroller: Scroller = new Scroller();
  aboutToAppear(): void {
    this.paths.pushPath({ name: 'profile-panel' }, false); this.presentationMounted = true; this.syncUsername();
    this.onSearchBackChange?.((): boolean => { if (!this.followerSearching) return false; this.closeFollowerSearch(); return true; });
  }
  private openFollowerSearch(): void {
    if (!this.active || this.followerSearching || this.followerSearchClosing) return;
    this.followerSearching = true; this.paths.pushPath({ name: 'follower-search' }, true);
    this.onPresentationChange?.(true, this.scroller.currentOffset().yOffset, 0);
  }
  private closeFollowerSearch(): void {
    if (!this.active || !this.followerSearching || this.followerSearchClosing) return;
    this.followerSearchClosing = true;
    this.searchRestorePending = false;
    this.onPresentationChange?.(false, this.scroller.currentOffset().yOffset, 0);
    this.paths.pop(true);
  }
  private finishFollowerSearchClose(): void {
    if (!this.followerSearchClosing) return;
    this.followerSearchClosing = false;
    this.followerSearching = false;
    this.followerQuery = '';
    if (this.presentationMounted && this.active) this.onSearch?.('');
    this.retainPresentation();
  }
  private followerSearchTransition(from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    if (from.name !== 'follower-search' && to.name !== 'follower-search') return undefined;
    const closing: boolean = operation === NavigationOperation.POP;
    return {
      timeout: 400,
      transition: (proxy: NavigationTransitionProxy): void => {
        this.searchMotionOffset = closing ? '0%' : '100%';
        this.getUIContext().postFrameCallback({ onFrame: (): void => {}, onIdle: (): void => {
          if (!this.presentationMounted) { proxy.finishTransition(); return; }
          this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut,
            onFinish: (): void => { proxy.finishTransition(); } }, (): void => {
            this.searchMotionOffset = closing ? '100%' : '0%';
          });
        } });
      },
      onTransitionEnd: (_success: boolean): void => { if (closing) this.finishFollowerSearchClose(); }
    };
  }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: this.snapshot.mode === 'following',
      style: { blurStrategy: (this.immersiveLightMode !== 'off' && this.snapshot.mode !== 'followers') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off' && this.snapshot.mode !== 'followers'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off' && this.snapshot.mode !== 'followers'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode), scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
      content: { title: { mainTitle: this.snapshot.mode === 'edit' ? this.uiText("pm_edit_profile_3b0b2bb8") : this.snapshot.mode === 'followers' ? this.uiText("pm_followers_261c51c9") : this.uiText("pm_following_7dfa5d8f") },
        backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: this.snapshot.mode === 'edit' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_done_c0b3fbff"), isEnabled: !this.saving && !this.snapshot.loading && !this.snapshot.avatarBusy, action: () => { if (!this.saving && !this.snapshot.avatarBusy && this.onSave) this.onSave(JSON.stringify({ firstName: this.firstNameDraft, lastName: this.lastNameDraft, about: this.aboutDraft, websiteUrl: this.websiteDraft, username: this.usernameDraft })); } } }] : [{ content: { icon: $r('app.media.inbox_search_outline'), label: this.uiText('pm_search_44ce7ae9'), action: () => this.openFollowerSearch() } }] } } };
  }
  private searchOptions(): HdsNavigationTitleBarOptions {
    const options: HdsNavigationTitleBarOptions = this.options();
    options.enableComponentSafeArea = false;
    options.style = {
      blurStrategy: BlurStrategy.DISABLE,
      thermoCtrl: false,
      scrollEffectOpts: { enableScrollEffect: false },
      scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 },
        contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text') } } },
      originalStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 },
        contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text') } } }
    };
    options.content = { title: { mainTitle: this.uiText('pm_search_44ce7ae9') }, backIcon: { isEnabled: true, action: () => this.closeFollowerSearch() }, menu: { value: [] } };
    return options;
  }
  @Builder
  private field(label: string, value: string, placeholder: string = '') {
    Column({ space: 8 }) {
      Text(this.uiText(label)).fontSize(14).fontColor($r('app.color.secondary_text'))
      TextInput({ text: value, placeholder: placeholder }).width('100%').height(40).padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(0).fontSize(17)
        .placeholderColor($r('app.color.secondary_text')).fontColor($r('app.color.primary_text')).backgroundColor(Color.Transparent)
        .enabled(!this.saving)
        .onChange((text: string) => { if (label === '用户名') this.usernameDraft = text; else if (label === '名字') this.firstNameDraft = text; else if (label === '姓氏') this.lastNameDraft = text; else if (label === '网站') this.websiteDraft = text; })
        .onFocus(() => { if (label === '用户名') { this.usernameFocused = true; this.revealUsernameUrl(); } })
        .onBlur(() => { if (label === '用户名') this.usernameFocused = false; })
    }.width('100%').constraintSize({ minHeight: 92 }).padding({ left: 18, right: 18, top: 14, bottom: 14 })
      .alignItems(HorizontalAlign.Start).border({ width: 1, color: $r('app.color.surface_muted'), radius: 20 })
  }
  @Builder
  private destination(name?: string, _param?: Object) {
    if (name === 'follower-search') { this.searchDestination() } else { this.panelDestination() }
  }
  @Builder
  private panelRefreshIndicator() {
    Column() {
      LoadingProgress().width(24).height(24).color($r('app.color.accent'))
        .visibility(this.snapshot.refreshing || this.panelRefreshState === RefreshStatus.Drag || this.panelRefreshState === RefreshStatus.OverDrag ? Visibility.Visible : Visibility.Hidden)
    }.width('100%').height(64).justifyContent(FlexAlign.Center)
      .offset({ y: this.contentTopInset() }).hitTestBehavior(HitTestMode.None)
  }
  @Builder
  private panelDestination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
      Column() {
          if (this.snapshot.mode === 'following') {
            Row() {
              CapsuleSegmentButtonV2({ items: this.followingSegments, enableStateAnimation: true,
                selectedIndex: this.snapshot.section === 'boards' ? 1 : 0,
                onItemClicked: (index: number) => {
                  const section: string = index === 0 ? 'users' : 'boards';
                  this.selectFollowingSection(section);
                } }).width('100%')
            }.width('100%').height(48).padding({ left: 24, right: 24 }).justifyContent(FlexAlign.Center)
          }
      Refresh({ refreshing: this.snapshot.refreshing === true, builder: this.panelRefreshIndicator }) {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          Column({ space: 20 }) {
          if (!this.snapshot.loading && this.snapshot.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage) }) }
          else if (!this.snapshot.loading && this.snapshot.mode === 'edit') {
            PinmonyUserAvatar({ profileUrl: this.snapshot.page, image: this.snapshot.avatarPreview || this.snapshot.avatar, colorIndex: this.snapshot.avatarColorIndex || 0, name: this.firstNameDraft + ' ' + this.lastNameDraft, avatarSize: 120 })
            Button(this.snapshot.avatarBusy ? this.uiText("pm_processing_d3d21191") : this.snapshot.avatarAction === 'refresh' ? this.uiText("pm_refresh_profile_picture_96fa37f1") : this.snapshot.avatarAction === 'check' ? this.uiText("pm_check_status_7c5569c3") : this.uiText("pm_change_6b01fce4")).type(ButtonType.Normal).borderRadius(16).height(40).fontSize(16).fontColor($r('app.color.primary_text'))
              .backgroundColor($r('app.color.surface_muted')).enabled(!this.saving && !this.snapshot.avatarBusy).onClick(() => { if (!this.saving && !this.snapshot.avatarBusy && this.onAvatar) this.onAvatar(); })
            if (this.snapshot.avatarError) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.avatarError, this.uiLanguage) }) }
            this.field('名字', this.firstNameDraft)
            this.field('姓氏', this.lastNameDraft)
            Column({ space: 8 }) {
              Text(this.uiText("pm_about_52d25a9e")).fontSize(14).fontColor($r('app.color.secondary_text'))
              TextArea({ text: this.aboutDraft, placeholder: this.uiText("pm_tell_your_story_42ba0e47") }).width('100%').height(64).padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(0)
                .enabled(!this.saving).onChange((text: string) => { this.aboutDraft = text; })
                .fontSize(17).fontColor($r('app.color.primary_text')).placeholderColor($r('app.color.secondary_text'))
                .backgroundColor(Color.Transparent)
            }.width('100%').constraintSize({ minHeight: 128 }).padding(18).alignItems(HorizontalAlign.Start)
              .border({ width: 1, color: $r('app.color.surface_muted'), radius: 20 })
            this.field('网站', this.websiteDraft, 'https://')
            Text(this.uiText("pm_add_a_link_to_bring_visitors_to_your_website_82987d9c")).width('100%').fontSize(12).fontColor($r('app.color.secondary_text'))
            this.field('用户名', this.usernameDraft)
            Text('www.pinterest.com/' + this.usernameDraft).width('100%').fontSize(12).fontColor($r('app.color.secondary_text'))
          } else if (!this.snapshot.loading) {
            if (this.snapshot.items.length === 0) {
              Text(this.snapshot.mode === 'followers' && this.followerQuery.trim() ? this.uiText('pm_no_search_results_available_6025e7b5') : this.snapshot.mode === 'followers' ? this.uiText("pm_no_followers_yet_480f3c81") : this.snapshot.section === 'boards' ? this.uiText("pm_you_are_not_following_any_boards_yet_d8537a5c") : this.uiText("pm_you_are_not_following_anyone_yet_6289b8af")).fontColor($r('app.color.primary_text'))
            }
            if (this.snapshot.section === 'boards') {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              ForEach(this.snapshot.items, (item: PinmonyProfilePanelItem) => {
                Column({ space: 8 }) {
                  if (item.covers && item.covers.length > 0) {
                    Row({ space: 2 }) {
                      Image(item.covers[0]).height(140).layoutWeight(2).objectFit(ImageFit.Cover)
                      if (item.covers.length > 1) {
                        Column({ space: 2 }) {
                          Image(item.covers[1]).width('100%').layoutWeight(1).objectFit(ImageFit.Cover)
                          if (item.covers.length > 2) { Image(item.covers[2]).width('100%').layoutWeight(1).objectFit(ImageFit.Cover) }
                        }.height(140).layoutWeight(1)
                      }
                    }.width('100%').borderRadius(16).clip(true)
                    .onClick(() => { if (item.targetUrl && this.onBoard) this.onBoard(item.targetUrl); })
                  }
                  Text(PinmonyI18n.render(item.name, this.uiLanguage)).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                    .onClick(() => { if (item.targetUrl && this.onBoard) this.onBoard(item.targetUrl); })
                  Text(PinmonyI18n.render((item.pinCount || '') + (item.updated ? ' · ' + item.updated : ''), this.uiLanguage)).fontSize(13).fontColor($r('app.color.secondary_text'))
                  Button(item.following ? this.uiText("pm_following_7dfa5d8f") : this.uiText("pm_follow_eb137dee")).type(ButtonType.Normal).borderRadius(16).fontColor(item.following ? $r('app.color.primary_text') : Color.White).backgroundColor(item.following ? $r('app.color.surface_muted') : $r('app.color.accent'))
                    .enabled(!this.followingBusy && item.canFollow === true).onClick(() => { if(this.onFollow)this.onFollow(item.id); })
                }.width('48%').margin({ bottom: 24 }).alignItems(HorizontalAlign.Start)
              }, (item: PinmonyProfilePanelItem) => (item.id) + ':' + this.uiLanguage + ':' + item.following + ':' + item.canFollow)
              }.width('100%')
            } else {
            ForEach(this.snapshot.items, (item: PinmonyProfilePanelItem) => {
              Row({ space: 16 }) {
                PinmonyUserAvatar({ profileUrl: this.snapshot.section === 'boards' ? '' : item.profileUrl || '', username: this.snapshot.section === 'boards' ? '' : item.username || '', userId: this.snapshot.section === 'boards' ? '' : item.id, image: item.avatar || '', name: item.name, colorIndex: item.avatarColorIndex || 0, websiteFallback: this.snapshot.section !== 'boards', avatarSize: 48 })
                  .onClick(() => { if (item.profileUrl && this.onUser) this.openPanelUser(item.profileUrl); })
                Column({ space: 3 }) {
                  Row({ space: 4 }) {
                    Text(item.name).fontColor($r('app.color.primary_text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.privateProfile) { Image($r('app.media.board_private_lock')).width(14).height(14).fillColor($r('app.color.secondary_text')) }
                  }
                  if (item.followerCount !== undefined) { Text(item.followerCount.toString() + this.uiText('pm_followers_7c3af361')).fontSize(12).fontColor($r('app.color.secondary_text')) }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => { if (item.profileUrl && this.onUser) this.openPanelUser(item.profileUrl); })
                if (item.canFollow !== false) { Button(item.following ? this.uiText("pm_following_7dfa5d8f") : this.uiText("pm_follow_eb137dee")).type(ButtonType.Normal).borderRadius(16).fontColor(item.following ? $r('app.color.primary_text') : Color.White).backgroundColor(item.following ? $r('app.color.surface_muted') : $r('app.color.accent')).enabled(!this.followingBusy).onClick(() => { if (this.onFollow) this.onFollow(item.id); }) }
              }.width('100%')
            }, (item: PinmonyProfilePanelItem) => (item.id) + ':' + this.uiLanguage + ':' + item.following + ':' + item.canFollow)
            }
          }
          if (this.snapshot.moreLoading) { LoadingProgress().width(28).height(28).color($r('app.color.accent')) }
          if (this.snapshot.moreError) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.moreError, this.uiLanguage), actionText: this.uiText("pm_retry_loading_followers_db11cdc1"), actionEnabled: this.snapshot.hasMore === true && !this.snapshot.moreLoading && !this.followingBusy && !this.saving, onAction: () => { this.onLoadMore?.(); } }) }
          }.width('100%').translate({ x: this.snapshot.mode === 'following' ? this.sectionOffset : 0 })
        }.width('100%').padding({ left: 24, right: 24, top: this.contentTopInset() + 16, bottom: this.snapshot.mode === 'edit' ? 64 : 32 })
      }.width('100%').layoutWeight(1).align(Alignment.Top).clip(true)
        .onScrollEdge((side: Edge) => { if (side === Edge.Bottom) this.loadNextPage(); })
        .onReachEnd(() => this.loadNextPage())
        .onAppear(() => { if (this.rootRestorePending) this.restoreScrollOffsets(); })
        .scrollBarMargin({ start: LengthMetrics.vp(this.contentTopInset()) })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
          .onActionEnd((event: GestureEvent) => this.swipeFollowingSection(event.offsetX, event.offsetY)))
      }.width('100%').layoutWeight(1)
        .pullToRefresh(this.snapshot.mode !== 'edit' && !this.snapshot.loading && !this.snapshot.refreshing && !this.snapshot.moreLoading && !this.followingBusy && !this.saving)
        .onRefreshing(() => { this.onRefresh?.(); })
        .onStateChange((state: RefreshStatus) => { this.panelRefreshState = state; })
      }.width('100%').height('100%')
      if (this.snapshot.loading) {
        Stack({ alignContent: Alignment.Center }) {
          LoadingProgress().width(40).height(40).color($r('app.color.accent'))
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.options(), this.hdsDarkMode)).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => {
        if (!this.active) { this.onCoveredBack?.(); return true; }
        if (this.followerSearching) this.closeFollowerSearch();
        else this.onBack?.();
        return true;
      })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  @Builder
  private searchDestination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
        TextInput({ text: this.followerQuery, placeholder: this.uiText('pm_search_by_name_or_username_59fb9fda') })
          .maxLength(200)
          .height(44).fontColor($r('app.color.primary_text')).backgroundColor($r('app.color.surface_muted'))
          .onChange((query: string) => { this.followerQuery = query; this.onSearch?.(query); this.searchScroller.scrollTo({ xOffset: 0, yOffset: 0 }); })
          .margin({ left: 24, right: 24, top: 16, bottom: 16 })
        }.width('100%').margin({ top: this.getUIContext().px2vp(this.statusBarHeightPx) + 56 })
          .backgroundColor($r('app.color.page_background')).zIndex(1)
          .onAreaChange((_old: Area, area: Area) => { this.searchHeaderHeight = Number(area.height); if (this.searchRestorePending) this.restoreScrollOffsets(); })
        Scroll(this.searchScroller) {
          Column({ space: 20 }) {
            ForEach(this.visibleItems(), (item: PinmonyProfilePanelItem) => {
              Row({ space: 16 }) {
                PinmonyUserAvatar({ profileUrl: this.snapshot.section === 'boards' ? '' : item.profileUrl || '', username: this.snapshot.section === 'boards' ? '' : item.username || '', userId: this.snapshot.section === 'boards' ? '' : item.id, image: this.snapshot.section === 'boards' ? (item.covers?.[0] || item.avatar || '') : (item.avatar || ''), name: item.name, colorIndex: this.snapshot.section === 'boards' ? 0 : item.avatarColorIndex || 0, websiteFallback: this.snapshot.section !== 'boards', avatarSize: 48 })
                  .onClick(() => { if (this.snapshot.section === 'boards' && item.targetUrl) this.onBoard?.(item.targetUrl); else if (item.profileUrl) this.openPanelUser(item.profileUrl); })
                Text(item.name).fontColor($r('app.color.primary_text')).layoutWeight(1)
                  .onClick(() => { if (this.snapshot.section === 'boards' && item.targetUrl) this.onBoard?.(item.targetUrl); else if (item.profileUrl) this.openPanelUser(item.profileUrl); })
                if (item.canFollow !== false) {
                  Button(item.following ? this.uiText('pm_following_7dfa5d8f') : this.uiText('pm_follow_eb137dee'))
                    .type(ButtonType.Normal).borderRadius(16).fontColor(item.following ? $r('app.color.primary_text') : Color.White)
                    .backgroundColor(item.following ? $r('app.color.surface_muted') : $r('app.color.accent'))
                    .enabled(!this.followingBusy).onClick(() => this.onFollow?.(item.id))
                }
              }.width('100%')
            }, (item: PinmonyProfilePanelItem): string => item.id + ':' + this.uiLanguage + ':' + item.following + ':' + item.canFollow)
            if (this.snapshot.moreLoading) {
              LoadingProgress().width(32).height(32).color($r('app.color.accent'))
            }
            if (this.snapshot.moreError) {
              PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.moreError, this.uiLanguage), actionText: this.uiText('pm_retry_loading_followers_db11cdc1'), actionEnabled: !this.snapshot.moreLoading && !this.followingBusy && !this.saving, onAction: () => { this.onLoadMore?.(); } })
            }
            if (!this.snapshot.loading && !this.snapshot.moreLoading && !this.snapshot.moreError && this.visibleItems().length === 0) {
              Text(this.uiText('pm_no_search_results_available_6025e7b5')).fontColor($r('app.color.secondary_text'))
              if (this.snapshot.hasMore) {
                Button(this.uiText('pm_load_more_followers_76e47179'))
                  .enabled(this.active && !this.followingBusy && !this.saving)
                  .onClick(() => this.loadSearchPage())
              }
            }
          }.width('100%').padding({ left: 24, right: 24, top: this.getUIContext().px2vp(this.statusBarHeightPx) + 56 + this.searchHeaderHeight, bottom: 32 })
        }.width('100%').height('100%').align(Alignment.Top)
          .onReachEnd(() => this.loadSearchPage())
          .onScrollStop(() => this.retainPresentation())
          .onAppear(() => { if (this.searchRestorePending) this.restoreScrollOffsets(); })
          .scrollBarMargin({ start: LengthMetrics.vp(this.getUIContext().px2vp(this.statusBarHeightPx) + 56 + this.searchHeaderHeight) })
      }.width('100%').height('100%')
    }.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.searchOptions(), this.hdsDarkMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.searchScroller])
      .translate({ x: this.searchMotionOffset })
      .onBackPressed(() => { if (!this.active) { this.onCoveredBack?.(); return true; } this.closeFollowerSearch(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation) =>
        this.followerSearchTransition(from, to, operation))
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
