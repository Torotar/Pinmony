import { PinmonyUserAvatar, PinmonyHdsTitleBar } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyBoardRecoveryPage } from './PinmonyBoardRecoveryPage';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyNotificationsPage } from './PinmonyNotificationsPage';
import { PinmonySocialPermissionsPage } from './PinmonySocialPermissionsPage';
import { PinmonyPreferencesPage } from './PinmonyPreferencesPage';
import { PinmonyAccountPage } from './PinmonyAccountPage';
import { PinmonyAboutPage } from './PinmonyAboutPage';
import { common } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';

@Component
export struct PinmonySettingsPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('gestureBarHeightPx') private gestureBarHeightPx: number = 0;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @StorageLink('pinmonyUpdateUnread') private updateUnread: boolean = false;
  @State private exportingLog: boolean = false;
  @State private clearingLog: boolean = false;
  private clearLogConfirmOpen: boolean = false;
  private suppressLogClick: boolean = false;
  private restoringRootScroll: boolean = false;
  private restoreRevision: number = 0;
  private logoutConfirmOpen: boolean = false;
  private pageVisible: boolean = false;
  @ObjectLink store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onEditProfile?: () => void;
  onViewProfile?: () => void;
  @Prop profileName: string = '';
  @Prop profileUrl: string = '';
  @Prop profileAvatar: string = '';
  @Prop profileAvatarColorIndex: number = 0;
  @StorageLink('profileLegacyLayout') private legacyProfile: boolean = false;
  onBack?: () => void;
  onPin?: (id: string) => void;
  onOpenExternalLink?: (url: string) => Promise<void>;

  private captureRootScroll(): void {
    if (this.restoringRootScroll || this.store.screen !== 'root') return;
    try { this.store.rootScrollOffset = Math.max(0, this.contentScroller.currentOffset().yOffset); } catch (_) {}
  }
  private restoreRootScroll(): void {
    this.restoringRootScroll = true;
    const revision: number = ++this.restoreRevision;
    setTimeout((): void => {
      if (revision !== this.restoreRevision || !this.pageVisible || this.store.screen !== 'root') return;
      try { this.contentScroller.scrollTo({ xOffset: 0, yOffset: this.store.rootScrollOffset, animation: false }); } catch (_) {}
      this.restoringRootScroll = false;
    }, 0);
  }
  private async exportLog(): Promise<void> {
    if (this.suppressLogClick) { this.suppressLogClick = false; return; }
    if (this.exportingLog || this.clearingLog || this.clearLogConfirmOpen) return;
    this.exportingLog = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (await PinmonyRuntimeLog.export(context)) {
        this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_logs_exported_2e45dbce"), duration: 4000 });
      }
    } catch (_) {
      PinmonyRuntimeLog.error('Runtime: log export failed');
      try { this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_export_logs_please_retry_2a73568e"), duration: 4000 }); }
      catch (_) { PinmonyRuntimeLog.warn('Runtime: log export feedback unavailable'); }
    } finally { this.exportingLog = false; }
  }
  private readonly pathStack: NavPathStack = new NavPathStack();
  private confirmClearLog(): void {
    if (this.exportingLog || this.clearingLog || this.clearLogConfirmOpen || !this.pageVisible) return;
    this.suppressLogClick = true;
    this.clearLogConfirmOpen = true;
    this.getUIContext().showAlertDialog({
      title: this.uiText('pm_clear_logs'), message: this.uiText('pm_clear_logs_confirm'),
      primaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: () => {
        this.clearLogConfirmOpen = false; this.suppressLogClick = false;
      } },
      secondaryButton: { value: this.uiText('pm_clear_logs'), action: () => {
        this.clearLogConfirmOpen = false; this.suppressLogClick = false;
        if (this.pageVisible && this.store.screen === 'root') this.clearLog();
      } },
      cancel: () => { this.clearLogConfirmOpen = false; this.suppressLogClick = false; }
    });
  }
  private async clearLog(): Promise<void> {
    if (this.exportingLog || this.clearingLog) return;
    this.clearingLog = true;
    try {
      const cleared: boolean = await PinmonyRuntimeLog.clear();
      if (this.pageVisible) {
        try {
          this.getUIContext().getPromptAction().showToast({
            message: this.uiText(cleared ? 'pm_logs_cleared' : 'pm_logs_clear_failed'), duration: 3000
          });
        } catch (_) { /* page may disappear while the log operation completes */ }
      }
    } finally { this.clearingLog = false; }
  }
  private readonly contentScroller: Scroller = new Scroller();
  private readonly options: string[] = ['profile', 'account', 'visibility', 'recommend', 'display', 'social', 'notifications', 'logout', 'logs', 'about'];
  private optionLabel(id: string): string {
    const labels: string[] = ['编辑个人资料', '帐户管理', '个人资料可见性', '优化你的推荐', '显示设置', 'pm_social_title', '通知', '退出账号', '日志', '关于'];
    return this.uiText(labels[this.options.indexOf(id)] || '');
  }

  aboutToAppear(): void {
    this.pageVisible = true;
    this.pathStack.clear();
    this.pathStack.pushPath({ name: 'pin-web-settings' }, false);
  }
  aboutToDisappear(): void { this.pageVisible = false; }
  private confirmLogout(): void {
    if (this.logoutConfirmOpen || this.store.busy || this.store.loading || !this.onRequest) return;
    const token: number = this.store.token;
    this.logoutConfirmOpen = true;
    this.getUIContext().showAlertDialog({
      title: this.uiText("pm_log_out_e7677436"), message: this.uiText("pm_log_out_of_this_account_ad88739b"),
      primaryButton: { value: this.uiText("pm_cancel_2cd0f3be"), action: () => { this.logoutConfirmOpen = false; } },
      secondaryButton: { value: this.uiText("pm_log_out_e7677436"), action: () => {
        this.logoutConfirmOpen = false;
        if (this.pageVisible && this.store.screen === 'root' && token === this.store.token &&
            !this.store.busy && !this.store.loading && this.onRequest) this.onRequest('logout', '');
      } },
      cancel: () => { this.logoutConfirmOpen = false; }
    });
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'),
        scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } }
      },
      content: {
        title: { mainTitle: this.uiText("pm_settings_df3d58c7") },
        backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } }
      }
    };
  }

  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      List({ space: 0, scroller: this.contentScroller }) {
        ListItem() {
          Row().width('100%').height(this.getUIContext().px2vp(this.statusBarHeightPx) + 56)
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
        if(!this.legacyProfile && this.onViewProfile) {
          ListItem() {
            Button({type:ButtonType.Normal}) {
              Row({space:16}) {
                PinmonyUserAvatar({ profileUrl: this.profileUrl, image: this.profileAvatar, name: this.profileName, colorIndex: this.profileAvatarColorIndex, avatarSize: 48 })
                Column({space:4}) {
                  Text(this.profileName).fontSize(20).fontColor($r('app.color.primary_text'))
                  Text(this.uiText('pm_settings_view_profile')).fontSize(16).fontColor($r('app.color.secondary_text'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.secondary_text')])
              }.width('100%').padding({left:20,right:20,top:20,bottom:24})
            }.width('100%').backgroundColor(Color.Transparent)
              .onClick(() => {this.captureRootScroll();if(this.onViewProfile)this.onViewProfile();})
          }
        }
        if (this.store.error) {
          ListItem() {
            PinmonyActionNotice({ message: PinmonyI18n.render(this.store.error, this.uiLanguage) })
          }
        }
        if (!this.store.loading) { ForEach(this.options, (id: string) => {
          ListItem() {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 16 }) {
                Text(id === 'logout' && this.store.busy ? this.uiText("pm_logging_out_0ae60dd3") : id === 'logs' && this.exportingLog ? this.uiText("pm_exporting_logs_2a89f720") : this.optionLabel(id))
                  .fontSize(17)
                  .fontColor($r('app.color.primary_text'))
                  .layoutWeight(1)
                Badge({ value: '', position: BadgePosition.Right,
                  style: { badgeSize: id === 'about' && this.updateUnread ? 6 : 0, fontSize: 0 } }) {
                  Row().width(1).height(16)
                }.accessibilityLevel('no')
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([$r('app.color.secondary_text')])
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 18, bottom: 18 })
              .constraintSize({ minHeight: 60 })
            }
            .width('100%')
            .backgroundColor(Color.Transparent)
            .enabled(!this.store.busy && !this.store.loading && (id !== 'logs' || (!this.exportingLog && !this.clearingLog)))
            .gesture(LongPressGesture({ repeat: false }).onAction(() => {
              if (id === 'logs') this.confirmClearLog();
            }))
            .onClick(() => { this.captureRootScroll(); if (id === 'profile' && this.onEditProfile) this.onEditProfile();
              if (id === 'notifications') { this.store.screen = 'notifications'; if (this.onRequest) this.onRequest('notifications', ''); }
              if (id === 'social') { this.store.screen = 'social'; if (this.onRequest) this.onRequest('socialRead', ''); }
              if (id === 'display') { this.store.screen = 'display'; if (this.onRequest) this.onRequest('read', ''); }
              if (id === 'recommend' || id === 'visibility') { this.store.screen = id === 'recommend' ? 'recommend' : 'visibility'; if (this.onRequest) this.onRequest(id === 'recommend' ? this.store.recommendationTab === 'boards' ? 'recommendBoardsRead' : this.store.recommendationTab === 'activity' ? 'activityRead' : 'aiRead' : 'read', ''); }
              if (id === 'account') { this.store.screen = 'account'; if (this.onRequest) this.onRequest('read', ''); }
              if (id === 'logout') this.confirmLogout();
              if (id === 'logs') this.exportLog();
              if (id === 'about') this.store.screen = 'about'; })
            .accessibilityText(id === 'logs' && this.exportingLog ? this.uiText("pm_exporting_logs_2a89f720") : this.optionLabel(id))
          }
        }, (id: string) => id + this.uiLanguage) }
      }
      .width('100%').height('100%')
      .scrollBarMargin({ start: LengthMetrics.vp(this.getUIContext().px2vp(this.statusBarHeightPx) + 56) })
      .onAppear(() => this.restoreRootScroll())
      .onDidScroll(() => this.captureRootScroll())
      .contentEndOffset(this.getUIContext().px2vp(this.gestureBarHeightPx) + 12)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }
    .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleBarOptions(), this.hdsDarkMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.contentScroller])
    .onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private settingsSubpage(screen: string) {
    if (this.store.screen === 'boardRecovery') {
      PinmonyBoardRecoveryPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else if (this.store.screen === 'about') {
      PinmonyAboutPage({ onBack: this.onBack, onOpenExternalLink: this.onOpenExternalLink })
    } else if (this.store.screen.startsWith('social')) {
      PinmonySocialPermissionsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else if (this.store.screen === 'notifications') {
      PinmonyNotificationsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack, onRetry: () => { if (this.onRequest) this.onRequest('notifications', ''); } })
    } else if (['display', 'theme', 'recommend', 'visibility'].includes(this.store.screen)) {
      PinmonyPreferencesPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack, onPin: this.onPin })
    } else if (this.store.screen !== 'root') {
      PinmonyAccountPage({ store: this.store, retainedAccount: screen === 'account' && this.store.screen === 'personal', onRequest: this.onRequest, onBack: this.onBack })
    }
  }

  build() {
    Stack() {
    HdsNavigation(this.pathStack) {
      Column().width('100%').height('100%')
    }
    .width('100%').height('100%')
    .hideTitleBar(true)
    .navDestination(this.destination)
    .backgroundColor($r('app.color.page_background'))
    .hitTestBehavior(this.store.screen === 'root' ? HitTestMode.Default : HitTestMode.None)
    .accessibilityLevel(this.store.screen === 'root' ? 'auto' : 'no-hide-descendants')
    ForEach(this.store.screen === 'root' ? [] : this.store.screen === 'personal' ? ['account', 'personal'] : [this.store.screen.startsWith('social') ? 'social' : this.store.screen], (_screen: string) => {
      Column() { this.settingsSubpage(_screen) }.width('100%').height('100%')
        .hitTestBehavior(_screen === 'account' && this.store.screen === 'personal' ? HitTestMode.None : HitTestMode.Default)
        .accessibilityLevel(_screen === 'account' && this.store.screen === 'personal' ? 'no-hide-descendants' : 'auto')
        .backgroundColor($r('app.color.page_background'))
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.translate({x:'100%'}).animation({duration:180,curve:Curve.EaseOut}),
          TransitionEffect.translate({x:'100%'}).animation({duration:150,curve:Curve.EaseIn})))
    }, (screen: string): string => screen)
    }.width('100%').height('100%')
  }
}

