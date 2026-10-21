import { BlurStrategy, HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { SocialBlockedUser, SocialMessageGroup, SocialMessageChoice } from '../models/PinmonySocialPermissions';
@Component
export struct PinmonySocialPermissionsPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @ObjectLink store: PinmonySettingsStore;
  onBack?: () => void;
  onRequest?: (action: string, value: string) => void;
  @State private query: string = '';
  @State private confirming: boolean = false;
  private visible: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private uiText(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  aboutToAppear(): void { this.visible = true; this.stack.pushPath({ name: 'social' }, false); }
  aboutToDisappear(): void { this.visible = false; this.confirming = false; }
  private available(): boolean { return this.visible && !this.store.busy && !this.store.loading && !this.store.writeUncertain && !this.confirming; }
  private title(): string {
    const screens: string[] = ['social','socialMessages','socialBlocked','socialMentions','socialFriends','socialFollowers','socialFollowing','socialOthers'];
    const titles: string[] = ['pm_social_title','pm_social_messages','pm_social_blocked','pm_social_mentions','pm_social_friends','pm_social_followers','pm_social_following','pm_social_others'];
    return this.uiText(titles[screens.indexOf(this.store.screen)] || 'pm_social_title');
  }
  private open(screen: string): void {
    if (!this.visible || this.store.busy || this.store.loading || this.confirming) return;
    this.store.token++; this.store.screen = screen; this.store.error = '';
    if (this.onRequest) this.onRequest(screen === 'socialBlocked' ? 'socialBlocked' : 'socialRead','');
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }
  private groupId(): number { return this.store.screen === 'socialFriends' ? 0 : this.store.screen === 'socialFollowers' ? 1 : this.store.screen === 'socialFollowing' ? 2 : 4; }
  private group(id: number): SocialMessageGroup | undefined { return this.store.social.groups.find((g: SocialMessageGroup): boolean => g.id === id); }
  private levelLabel(level: number): string { return this.uiText(level === 0 ? 'pm_social_direct' : level === 1 ? 'pm_social_requests' : 'pm_social_ignore'); }
  private selectionKey(level: number): string {
    const selected: number = this.store.screen === 'socialMentions' ? this.store.social.mentions ?? -1 : this.group(this.groupId())?.selected ?? -1;
    return this.store.screen + ':' + level + ':' + this.store.token + ':' + selected + ':' + this.store.busy + ':' + this.store.loading + ':' + this.store.writeUncertain + ':' + this.store.social.ready + ':' + this.store.social.protected;
  }
  private choose(level: number): void {
    if (!this.available() || !this.store.social.ready || this.store.social.protected || !this.onRequest) return;
    if (this.store.screen === 'socialMentions') { if (level !== this.store.social.mentions) this.onRequest('socialMentions',String(level)); }
    else { const group: SocialMessageGroup | undefined = this.group(this.groupId()); if (group && group.selected !== level && group.levels.includes(level)) { const choice: SocialMessageChoice = { group: group.id, level: level }; this.onRequest('socialMessage',JSON.stringify(choice)); } }
  }
  private blocked(): SocialBlockedUser[] {
    const query: string = this.query.trim().toLowerCase();
    return this.store.social.blocked.filter((u: SocialBlockedUser): boolean => !query || (u.name + ' @' + u.username).toLowerCase().includes(query));
  }
  private unblock(user: SocialBlockedUser): void {
    if (!this.available() || this.store.screen !== 'socialBlocked') return;
    const token: number = this.store.token;
    this.confirming = true;
    this.getUIContext().showAlertDialog({
      title: PinmonyI18n.format('pm_social_unblock_title',[user.name],this.uiLanguage), message: this.uiText('pm_social_unblock_description'), alignment: DialogAlignment.Bottom,
      primaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: () => { this.confirming = false; } },
      secondaryButton: { value: this.uiText('pm_social_unblock'), fontColor: $r('app.color.accent'), action: () => {
        const current: boolean = this.confirming && this.visible && token === this.store.token && this.store.screen === 'socialBlocked'; this.confirming = false;
        if (current && this.available() && this.store.social.blocked.some((u: SocialBlockedUser): boolean => u.id === user.id) && this.onRequest) this.onRequest('socialUnblock',user.id);
      } }, cancel: () => { this.confirming = false; }
    });
  }
  @Builder
  private link(title: string, detail: string, target: string) {
    Button() {
      Column({ space: 6 }) {
        Row() { Text(this.uiText(title)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.secondary_text')])
        }.width('100%')
        if (detail) { Text(detail).fontSize(16).fontColor($r('app.color.secondary_text')).width('100%') }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top:12,bottom:12 })
    }.width('100%').backgroundColor(Color.Transparent).padding(0).enabled(!this.store.busy && !this.store.loading && !this.confirming).onClick(() => this.open(target))
  }
  @Builder
  private selection(label: string, value: number, selected: number) {
    Row() {
      Text(label).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Radio({ value: String(value), group: this.store.screen }).checked(selected === value)
        .enabled(this.available() && this.store.social.ready && !this.store.social.protected)
        .accessibilityText(label).onChange((checked: boolean) => { if (checked) this.choose(value); })
    }.width('100%').constraintSize({ minHeight:56 }).onClick(() => this.choose(value))
  }
  @Builder
  private body() {
    if (this.store.screen === 'social') {
      Text(this.uiText('pm_social_intro')).fontSize(16).fontColor($r('app.color.secondary_text'))
      this.link('pm_social_message_settings',this.uiText('pm_social_message_settings_detail'),'socialMessages')
      this.link('pm_social_blocked',this.uiText('pm_social_blocked_detail'),'socialBlocked')
      this.link('pm_social_mentions',this.uiText('pm_social_mentions_detail'),'socialMentions')
    } else if (this.store.screen === 'socialMessages') {
      Text(this.uiText('pm_social_message_intro')).fontSize(16).fontColor($r('app.color.primary_text'))
      if (this.store.social.ready && this.store.social.business) {
      Text(this.uiText('pm_social_business_messages')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      Text(this.uiText('pm_social_business_detail')).fontSize(16).fontColor($r('app.color.secondary_text'))
      Text(this.uiText('pm_social_unavailable')).fontSize(14).fontColor($r('app.color.secondary_text'))
      }
      Column({ space: 0 }) {
        this.link('pm_social_friends','', 'socialFriends')
        this.link('pm_social_followers','', 'socialFollowers')
        this.link('pm_social_following','', 'socialFollowing')
        this.link('pm_social_others','', 'socialOthers')
      }.width('100%')
    } else if (this.store.screen === 'socialBlocked') {
      Text(this.uiText('pm_social_blocked_intro')).fontSize(16).fontColor($r('app.color.secondary_text'))
      if (this.store.social.blocked.length) {
        Search({ value: this.query, placeholder: this.uiText('pm_social_search') }).onChange((value: string) => { this.query = value; }).width('100%')
        ForEach(this.blocked(), (user: SocialBlockedUser) => {
          Row({ space:12 }) {
            if (user.image) { Image(user.image).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover) }
            Column({ space:4 }) { Text(user.name).fontColor($r('app.color.primary_text')); Text('@' + user.username).fontColor($r('app.color.secondary_text')) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Button(this.uiText('pm_social_unblock')).enabled(this.available()).onClick(() => this.unblock(user))
          }.width('100%').padding({ top:12,bottom:12 })
        }, (user: SocialBlockedUser): string => user.id)
        if (!this.blocked().length) { Text(this.uiText('pm_social_no_matches')).fontColor($r('app.color.secondary_text')) }
      } else if (this.store.social.blockedReady && !this.store.loading && !this.store.error) { Text(this.uiText('pm_social_no_blocked')).width('100%').textAlign(TextAlign.Center).fontColor($r('app.color.secondary_text')).margin({ top:100 }) }
    } else if (this.store.screen === 'socialMentions') {
      Text(this.uiText('pm_social_mentions_detail')).fontSize(16).fontColor($r('app.color.primary_text'))
      Column({ space: 4 }) {
        ForEach([0,1,2], (level: number) => { this.selection(this.uiText(level === 0 ? 'pm_social_mentions_anyone' : level === 1 ? 'pm_social_mentions_following' : 'pm_social_mentions_off'),level,this.store.social.mentions === undefined ? -1 : this.store.social.mentions) }, (level: number): string => this.selectionKey(level))
      }.width('100%')
    } else {
      Text(this.uiText(this.groupId() === 0 ? 'pm_social_friends_detail' : this.groupId() === 1 ? 'pm_social_followers_detail' : this.groupId() === 2 ? 'pm_social_following_detail' : 'pm_social_others_detail')).fontSize(16).fontColor($r('app.color.primary_text'))
      Column({ space: 4 }) {
        ForEach(this.group(this.groupId())?.levels || [], (level: number) => { this.selection(this.levelLabel(level),level,this.group(this.groupId())!.selected) }, (level: number): string => this.selectionKey(level))
      }.width('100%')
    }
  }
  @Builder
  private destination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Scroll(this.scroller) {
          Column({ space:16 }) {
            if (this.store.error) { Text(PinmonyI18n.render(this.store.error,this.uiLanguage)).fontColor($r('app.color.secondary_text')); Button(this.uiText('pm_retry_b8784c8d')).enabled(!this.store.busy && !this.store.loading).onClick(() => { if (this.onRequest) this.onRequest(this.store.screen === 'socialBlocked' ? 'socialBlocked' : 'socialRead',''); }) }
            this.body()
          }.width('100%').alignItems(HorizontalAlign.Start).padding({ left:20,right:20,top:16,bottom:28 })
        }.width('100%').height('100%').align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
        if (this.store.loading || this.store.busy) { LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None) }
      }.width('100%').height('100%')
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.stack) {
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%').hideTitleBar(true).navDestination(this.destination)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.page_background'))
  }
}
