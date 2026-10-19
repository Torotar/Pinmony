import { PinmonyI18n } from 'common_foundation';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyNotificationsPage } from './PinmonyNotificationsPage';
import { PinmonyPreferencesPage } from './PinmonyPreferencesPage';
import { PinmonyAccountPage } from './PinmonyAccountPage';
import { PinmonyAboutPage } from './PinmonyAboutPage';
import { common } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';

@Component
export struct PinmonySettingsPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @State private exportingLog: boolean = false;
  private logoutConfirmOpen: boolean = false;
  private pageVisible: boolean = false;
  @ObjectLink store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onEditProfile?: () => void;
  onBack?: () => void;
  onOpenExternalLink?: (url: string) => Promise<void>;

  private async exportLog(): Promise<void> {
    if (this.exportingLog) return;
    this.exportingLog = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (await PinmonyRuntimeLog.export(context)) {
        this.getUIContext().getPromptAction().showToast({ message: this.uiText("运行日志已导出"), duration: 4000 });
      }
    } catch (_) {
      PinmonyRuntimeLog.error('Runtime: log export failed');
      try { this.getUIContext().getPromptAction().showToast({ message: this.uiText("日志导出失败，请重试"), duration: 4000 }); }
      catch (_) { PinmonyRuntimeLog.warn('Runtime: log export feedback unavailable'); }
    } finally { this.exportingLog = false; }
  }
  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly contentScroller: Scroller = new Scroller();
  private readonly options: string[] = ['profile', 'account', 'visibility', 'recommend', 'display', 'notifications', 'logout', 'logs', 'about'];
  private optionLabel(id: string): string {
    const labels: string[] = ['编辑个人资料', '帐户管理', '个人资料可见性', '优化你的推荐', '显示设置', '通知', '退出账号', '日志', '关于'];
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
      title: this.uiText("退出账号"), message: this.uiText("确定要退出当前账号吗？"),
      primaryButton: { value: this.uiText("取消"), action: () => { this.logoutConfirmOpen = false; } },
      secondaryButton: { value: this.uiText("退出账号"), action: () => {
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
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: {
          backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0
        } }
      },
      content: {
        title: { mainTitle: this.uiText("设置") },
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
                Text(id === 'logout' && this.store.busy ? this.uiText("正在退出…") : id === 'logs' && this.exportingLog ? this.uiText("正在导出日志…") : this.optionLabel(id))
                  .fontSize(17)
                  .fontColor($r('app.color.primary_text'))
                  .layoutWeight(1)
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
            .onClick(() => { if (id === 'profile' && this.onEditProfile) this.onEditProfile();
              if (id === 'notifications') { this.store.screen = 'notifications'; if (this.onRequest) this.onRequest('notifications', ''); }
              if (id === 'display') this.store.screen = 'display';
              if (id === 'recommend' || id === 'visibility') { this.store.screen = id === 'recommend' ? 'recommend' : 'visibility'; if (this.onRequest) this.onRequest(id === 'recommend' ? 'aiRead' : 'read', ''); }
              if (id === 'account') { this.store.screen = 'account'; if (this.onRequest) this.onRequest('read', ''); }
              if (id === 'logout') this.confirmLogout();
              if (id === 'logs') this.exportLog();
              if (id === 'about') this.store.screen = 'about'; })
            .accessibilityText(id === 'logs' && this.exportingLog ? this.uiText("正在导出日志…") : this.optionLabel(id))
          }
        }, (id: string) => id + this.uiLanguage) }
      }
      .width('100%').height('100%')
      .padding({ bottom: 28 })
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
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    if (this.store.screen === 'about') {
      PinmonyAboutPage({ onBack: this.onBack, onOpenExternalLink: this.onOpenExternalLink })
    } else if (this.store.screen === 'notifications') {
      PinmonyNotificationsPage({ store: this.store, onBack: this.onBack, onRetry: () => { if (this.onRequest) this.onRequest('notifications', ''); } })
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

