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
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('gestureBarHeightPx') private gestureBarHeightPx: number = 0;
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @StorageLink('pinmonyUpdateUnread') private updateUnread: boolean = false;
  @State private exportingLog: boolean = false;
  private restoringRootScroll: boolean = false;
  private restoreRevision: number = 0;
  private logoutConfirmOpen: boolean = false;
  private pageVisible: boolean = false;
  @ObjectLink store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onEditProfile?: () => void;
  onBack?: () => void;
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
    if (this.exportingLog) return;
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
  private readonly contentScroller: Scroller = new Scroller();
  private readonly options: string[] = ['profile', 'account', 'visibility', 'recommend', 'display', 'social', 'notifications', 'logout', 'logs', 'help', 'terms', 'privacy', 'about'];
  private optionLabel(id: string): string {
    const labels: string[] = ['编辑个人资料', '帐户管理', '个人资料可见性', '优化你的推荐', '显示设置', 'pm_social_title', '通知', '退出账号', '日志', 'pm_settings_help_center', 'pm_settings_terms_of_service', 'pm_settings_privacy_policy', '关于'];
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
      enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } }
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
        if (this.store.error) {
          ListItem() {
            Text(PinmonyI18n.render(this.store.error, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
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
            .enabled(!this.store.busy && !this.store.loading && (id !== 'logs' || !this.exportingLog))
            .onClick(() => { this.captureRootScroll(); if (id === 'profile' && this.onEditProfile) this.onEditProfile();
              if (id === 'notifications') { this.store.screen = 'notifications'; if (this.onRequest) this.onRequest('notifications', ''); }
              if (id === 'social') { this.store.screen = 'social'; if (this.onRequest) this.onRequest('socialRead', ''); }
              if (id === 'display') { this.store.screen = 'display'; if (this.onRequest) this.onRequest('read', ''); }
              if (id === 'recommend' || id === 'visibility') { this.store.screen = id === 'recommend' ? 'recommend' : 'visibility'; if (this.onRequest) this.onRequest(id === 'recommend' ? 'aiRead' : 'read', ''); }
              if (id === 'account') { this.store.screen = 'account'; if (this.onRequest) this.onRequest('read', ''); }
              if (id === 'logout') this.confirmLogout();
              if (id === 'logs') this.exportLog();
              if (id === 'help' && this.onOpenExternalLink) this.onOpenExternalLink('https://www.pinterest.com/_/_/help/?source=gear_menu_web');
              if (id === 'terms' && this.onOpenExternalLink) this.onOpenExternalLink('https://www.pinterest.com/_/_/policy/terms-of-service/');
              if (id === 'privacy' && this.onOpenExternalLink) this.onOpenExternalLink('https://www.pinterest.com/_/_/policy/privacy-policy/');
              if (id === 'about') this.store.screen = 'about'; })
            .accessibilityText(id === 'logs' && this.exportingLog ? this.uiText("pm_exporting_logs_2a89f720") : this.optionLabel(id))
          }
        }, (id: string) => id + this.uiLanguage) }
      }
      .width('100%').height('100%')
      .onAppear(() => this.restoreRootScroll())
      .onDidScroll(() => this.captureRootScroll())
      .contentEndOffset(this.getUIContext().px2vp(this.gestureBarHeightPx) + 12)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.contentScroller])
    .onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    if (this.store.screen === 'boardRecovery') {
      PinmonyBoardRecoveryPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else if (this.store.screen === 'about') {
      PinmonyAboutPage({ onBack: this.onBack, onOpenExternalLink: this.onOpenExternalLink })
    } else if (this.store.screen.startsWith('social')) {
      PinmonySocialPermissionsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else if (this.store.screen === 'notifications') {
      PinmonyNotificationsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack, onRetry: () => { if (this.onRequest) this.onRequest('notifications', ''); } })
    } else if (['display', 'theme', 'recommend', 'visibility'].includes(this.store.screen)) {
      PinmonyPreferencesPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else if (this.store.screen !== 'root') {
      PinmonyAccountPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else {
    HdsNavigation(this.pathStack) {
      Column().width('100%').height('100%')
    }
    .width('100%').height('100%')
    .hideTitleBar(true)
    .navDestination(this.destination)
    .backgroundColor($r('app.color.page_background'))
    }
  }
}

