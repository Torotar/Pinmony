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
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') @Watch('syncFollowingLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('syncUsername') snapshot: PinmonyProfilePanel;
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
  private revealUsernameUrl(): void {
    setTimeout(() => {
      if (this.usernameFocused && this.snapshot.mode === 'edit') this.scroller.scrollEdge(Edge.Bottom);
    }, 350);
  }
  aboutToDisappear(): void { this.usernameFocused = false; this.sectionMotionToken++; }
  private syncUsername(): void {
    this.syncFollowingMotion();
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
  onBoard?: (url: string) => void;
  onUser?: (url: string) => void;
  onSection?: (section: string) => void;
  onSave?: (input: string) => void;
  onFollow?: (id: string) => void;
  onLoadMore?: () => void;
  onAvatar?: () => void;
  @Prop followingBusy: boolean = false;
  private readonly paths: NavPathStack = new NavPathStack();
  private readonly scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.syncUsername(); this.paths.pushPath({ name: 'profile-panel' }, false); }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode), scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
      content: { title: { mainTitle: this.snapshot.mode === 'edit' ? this.uiText("pm_edit_profile_3b0b2bb8") : this.snapshot.mode === 'followers' ? this.uiText("pm_followers_261c51c9") : this.uiText("pm_following_7dfa5d8f") },
        backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: this.snapshot.mode === 'edit' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_done_c0b3fbff"), isEnabled: !this.saving && !this.snapshot.loading && !this.snapshot.avatarBusy, action: () => { if (!this.saving && !this.snapshot.avatarBusy && this.onSave) this.onSave(JSON.stringify({ firstName: this.firstNameDraft, lastName: this.lastNameDraft, about: this.aboutDraft, websiteUrl: this.websiteDraft, username: this.usernameDraft })); } } }] : [] } } };
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
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          if (this.snapshot.mode === 'following') {
            Row() {
              CapsuleSegmentButtonV2({ items: this.followingSegments, enableStateAnimation: true,
                selectedIndex: this.snapshot.section === 'boards' ? 1 : 0,
                onItemClicked: (index: number) => {
                  const section: string = index === 0 ? 'users' : 'boards';
                  this.selectFollowingSection(section);
                } }).width(280).constraintSize({ maxWidth: '100%' })
            }.width('100%').height(48).justifyContent(FlexAlign.Center)
          }
          Column({ space: 20 }) {
          if (!this.snapshot.loading && this.snapshot.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage) }) }
          else if (!this.snapshot.loading && this.snapshot.mode === 'edit') {
            PinmonyUserAvatar({ image: this.snapshot.avatarPreview || this.snapshot.avatar, name: this.firstNameDraft + ' ' + this.lastNameDraft, avatarSize: 120 })
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
              Text(this.snapshot.mode === 'followers' ? this.uiText("pm_no_followers_yet_480f3c81") : this.snapshot.section === 'boards' ? this.uiText("pm_you_are_not_following_any_boards_yet_d8537a5c") : this.uiText("pm_you_are_not_following_anyone_yet_6289b8af")).fontColor($r('app.color.primary_text'))
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
                  Button(item.following ? this.uiText("pm_following_7dfa5d8f") : this.uiText("pm_follow_eb137dee")).type(ButtonType.Normal).borderRadius(16).fontColor($r('app.color.primary_text')).backgroundColor($r('app.color.surface_muted'))
                    .enabled(!this.followingBusy && item.canFollow === true).onClick(() => { if(this.onFollow)this.onFollow(item.id); })
                }.width('48%').margin({ bottom: 24 }).alignItems(HorizontalAlign.Start)
              }, (item: PinmonyProfilePanelItem) => (item.id) + ':' + this.uiLanguage)
              }.width('100%')
            } else {
            ForEach(this.snapshot.items, (item: PinmonyProfilePanelItem) => {
              Row({ space: 16 }) {
                PinmonyUserAvatar({ image: item.avatar || '', name: item.name, avatarSize: 48 })
                  .onClick(() => { if (item.profileUrl && this.onUser) this.onUser(item.profileUrl); })
                Text(PinmonyI18n.render(item.name, this.uiLanguage)).layoutWeight(1).fontColor($r('app.color.primary_text'))
                Button(item.following ? this.uiText("pm_following_7dfa5d8f") : this.uiText("pm_follow_eb137dee")).type(ButtonType.Normal).borderRadius(16).enabled(!this.followingBusy && item.canFollow !== false).onClick(() => { if (this.onFollow) this.onFollow(item.id); })
              }.width('100%')
            }, (item: PinmonyProfilePanelItem) => (item.id) + ':' + this.uiLanguage)
            }
          }
          if (this.snapshot.mode === 'followers' && this.snapshot.hasMore && !this.snapshot.moreError) {
            Button(this.snapshot.moreLoading ? this.uiText("pm_loading_4927a53b") : this.snapshot.moreError ? this.uiText("pm_retry_loading_followers_db11cdc1") : this.uiText("pm_load_more_followers_76e47179")).type(ButtonType.Normal).borderRadius(16)
              .enabled(!this.snapshot.moreLoading && !this.followingBusy && !this.saving)
              .onClick(() => { if(this.onLoadMore)this.onLoadMore(); })
          }
          if (this.snapshot.moreError) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.moreError, this.uiLanguage), actionText: this.uiText("pm_retry_loading_followers_db11cdc1"), actionEnabled: this.snapshot.mode === 'followers' && this.snapshot.hasMore && !this.snapshot.moreLoading && !this.followingBusy && !this.saving, onAction: () => { this.onLoadMore?.(); } }) }
          }.width('100%').translate({ x: this.snapshot.mode === 'following' ? this.sectionOffset : 0 })
        }.width('100%').padding({ left: 24, right: 24, top: this.snapshot.mode === 'following' ? 0 : 16, bottom: this.snapshot.mode === 'edit' ? 64 : 32 })
      }.width('100%').height('100%').align(Alignment.Top).clip(true)
        .edgeEffect(this.snapshot.mode === 'edit' ? EdgeEffect.Spring : EdgeEffect.None, { alwaysEnabled: true })
        .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
          .onActionEnd((event: GestureEvent) => this.swipeFollowingSection(event.offsetX, event.offsetY)))
      if (this.snapshot.loading) {
        LoadingProgress().width(40).height(40).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(this.options()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
