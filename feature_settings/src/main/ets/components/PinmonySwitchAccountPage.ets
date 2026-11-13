import { PinmonyUserAvatar, PinmonyHdsTitleBar, PinmonyActionNotice, PinmonyLoadingOverlay, PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { BlurStrategy, ScrollEffectType, HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonySessionAccount } from '../models/PinmonySessionAccount';
interface PinmonySessionAccountRow { account: PinmonySessionAccount; }
@Component
export struct PinmonySwitchAccountPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @ObjectLink store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  private appearance: number = 0;
  private pageVisible: boolean = false;
  private logoutConfirmOpen: boolean = false;
  private paths: NavPathStack = new NavPathStack();
  private scroller: ListScroller = new ListScroller();
  private text(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  aboutToAppear(): void { this.appearance++; this.pageVisible = true; this.paths.pushPath({ name: 'sessionAccounts' }, false); }
  aboutToDisappear(): void { this.appearance++; this.pageVisible = false; this.logoutConfirmOpen = false; this.closeSwipe(); }
  private closeSwipe(): void { try { this.scroller.closeAllSwipeActions(); } catch (_) {} }
  private canLogout(account: PinmonySessionAccount): boolean {
    return this.pageVisible && this.store.screen === 'sessionAccounts' && this.store.sessionAccountsReady &&
      !this.store.busy && !this.store.loading && !this.store.sessionAccountsLoading && !this.store.sessionSwitchUncertain && account.loggedIn &&
      this.store.sessionAccounts.some((row: PinmonySessionAccount): boolean => row.id === account.id && row.username === account.username && row.loggedIn);
  }
  private confirmAccountLogout(account: PinmonySessionAccount): void {
    if (this.logoutConfirmOpen || !this.onRequest || !this.canLogout(account)) return;
    this.closeSwipe();
    const appearance: number = this.appearance;
    const token: number = this.store.token;
    const accounts: PinmonySessionAccount[] = this.store.sessionAccounts;
    this.logoutConfirmOpen = true;
    this.getUIContext().showAlertDialog(PinmonyImmersiveLight.alertOptions({
      title: this.text('pm_session_logout_title'), message: this.text('pm_session_logout_message'),
      primaryButton: { value: this.text('pm_cancel_2cd0f3be'), action: () => { this.logoutConfirmOpen = false; } },
      secondaryButton: { value: this.text('pm_session_logout_action'), action: () => {
        this.logoutConfirmOpen = false;
        if (appearance === this.appearance && token === this.store.token && accounts === this.store.sessionAccounts && this.canLogout(account)) this.request('logoutSessionAccount', account.id);
      } },
      cancel: () => { this.logoutConfirmOpen = false; }
    }));
  }
  @Builder
  private logoutSwipe($$: PinmonySessionAccountRow) {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([$r('app.color.detail_on_accent')])
      }.width(40).height(40).padding(0).backgroundColor($r('app.color.detail_save_accent'))
        .accessibilityText(this.text('pm_session_logout_action')).enabled(this.canLogout($$.account))
        .onClick(() => { this.confirmAccountLogout($$.account); })
    }.width(80).height(72).justifyContent(FlexAlign.Center).backgroundColor($r('app.color.input_surface'))
  }
  @Builder
  private accountItem($$: PinmonySessionAccountRow) {
    ListItem() { this.accountRow({ account: $$.account }) }
      .swipeAction({ end: this.canLogout($$.account) ? { builder: () => { this.logoutSwipe({ account: $$.account }); } } : undefined,
        edgeEffect: SwipeEdgeEffect.Spring })
  }
  private request(action: string, value: string = ''): void { this.closeSwipe(); if (this.onRequest) void this.onRequest(action, value); }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
      content: { title: { mainTitle: this.text('pm_switch_accounts') }, backIcon: { isEnabled: !this.store.busy, action: () => { this.closeSwipe(); if (!this.store.busy && this.onBack) this.onBack(); } } } };
  }

  @Builder
  private accountRow($$: PinmonySessionAccountRow) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row({ space: 16 }) {
        PinmonyUserAvatar({ profileUrl: '', userId: $$.account.id, username: $$.account.username,
          image: $$.account.avatar, name: $$.account.name, avatarSize: 56 })
        Column({ space: 5 }) {
          Text($$.account.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          Text(this.text($$.account.business ? 'pm_session_business' : 'pm_session_personal')).fontSize(15).fontColor($r('app.color.secondary_text'))
          if ($$.account.current && $$.account.email) {
            Text($$.account.email).fontSize(15).fontColor($r('app.color.secondary_text')).wordBreak(WordBreak.BREAK_ALL)
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if ($$.account.current) {
          Checkbox().select(true).width(24).height(24).margin(0).shape(CheckBoxShape.CIRCLE)
            .selectedColor($r('app.color.accent')).hitTestBehavior(HitTestMode.None).focusable(false)
            .accessibilityText(this.text('pm_session_current'))
        }
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }.width('100%').backgroundColor(Color.Transparent)
      .enabled($$.account.current || (!this.store.busy && !this.store.sessionSwitchUncertain))
      .onClick(() => { if ($$.account.current) return; this.request($$.account.loggedIn ? 'switchAccount' : 'addAccount', $$.account.id); })
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        List({ space: 12, scroller: this.scroller }) {
            ListItem() { Text(this.text('pm_session_accounts_description')).fontSize(16).fontColor($r('app.color.primary_text')) }.padding({ left: 20, right: 20 })
            if (this.store.sessionAccountError) {
              ListItem() { PinmonyActionNotice({ message: PinmonyI18n.render(this.store.sessionAccountError, this.uiLanguage),
                actionText: this.text(this.store.sessionSwitchUncertain ? 'pm_session_verify' : 'pm_reload_df7392cc'),
                actionEnabled: !this.store.busy && !this.store.sessionAccountsLoading,
                onAction: () => { this.request(this.store.sessionSwitchUncertain ? 'verifySwitchAccount' : 'sessionAccounts'); } }) }.padding({ left: 20, right: 20 })
            }
            if (this.store.sessionAccountsReady) {
              ListItem() { Text(this.text('pm_session_current')).fontSize(14).fontColor($r('app.color.secondary_text')) }.padding({ left: 20, right: 20 }).margin({ top: 12 })
              ForEach(this.store.sessionAccounts.filter((account: PinmonySessionAccount): boolean => account.current), (account: PinmonySessionAccount) => {
                this.accountItem({ account: account })
              }, (account: PinmonySessionAccount): string => account.id)
              if (this.store.sessionAccounts.length > 1) {
                ListItem() { Text(this.text('pm_session_other')).fontSize(14).fontColor($r('app.color.secondary_text')) }.padding({ left: 20, right: 20 }).margin({ top: 12 })
                ForEach(this.store.sessionAccounts.filter((account: PinmonySessionAccount): boolean => !account.current), (account: PinmonySessionAccount) => {
                  this.accountItem({ account: account })
                }, (account: PinmonySessionAccount): string => account.id)
              }
            }
            if (this.store.sessionAccountsReady && !this.store.sessionAccountsLoading) {
              ListItem() { Row() { Button(this.text('pm_add_account'), { type: ButtonType.Normal, stateEffect: false })
                .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor($r('app.color.accent'))
                .padding({ left: 24, right: 24 }).height(48).borderRadius(16).margin({ top: 24 }).alignSelf(ItemAlign.Center)
                .enabled(!this.store.busy && !this.store.sessionSwitchUncertain).onClick(() => { this.request('addAccount'); })
              }.width('100%').justifyContent(FlexAlign.Center) }
            }
        }.width('100%').height('100%').align(Alignment.TopStart)
          .padding({ top: this.getUIContext().px2vp(this.statusBarHeightPx) + 72, bottom: 32 })
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        if (this.store.sessionAccountsLoading || this.store.busy) {
          PinmonyLoadingOverlay({ showMessage: false })
        }
      }.width('100%').height('100%')
    }.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.options(), this.hdsDarkMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => { this.closeSwipe(); if (!this.store.busy && this.onBack) this.onBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }.mode(NavigationMode.Stack)
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
