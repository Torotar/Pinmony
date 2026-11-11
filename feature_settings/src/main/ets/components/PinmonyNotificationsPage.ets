import { PinmonyHdsTitleBar } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { common, ApplicationStateChangeCallback } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyNotificationCopy } from '../models/PinmonyNotificationCopy';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { NotificationChoice, NotificationGroup, NotificationCategory, NotificationChannel, notificationGlobal } from '../models/PinmonyNotifications';
@Component
export struct PinmonyNotificationsPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink @Watch('settingsChanged') store: PinmonySettingsStore;
  onBack?: () => void;
  onRetry?: () => void;
  onRequest?: (action: string, value: string) => void;
  @State private expanded: string[] = [];
  @State private confirmationOpen: boolean = false;
  @State private checkingSystemNotification: boolean = false;
  @State private systemNotificationEnabled: boolean = true;
  private applicationContext?: common.ApplicationContext;
  private applicationForeground: boolean = true;
  private pendingNotification?: NotificationChoice;
  private pendingNotificationToken: number = -1;
  private pendingCompletionQueued: boolean = false;
  private readonly applicationState: ApplicationStateChangeCallback = {
    onApplicationForeground: (): void => { this.applicationForeground = true; this.refreshSystemNotification(); },
    onApplicationBackground: (): void => { this.applicationForeground = false; this.notificationPermissionEpoch++; this.checkingSystemNotification = false; }
  };
  private notificationPermissionEpoch: number = 0;
  private pageVisible: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void {
    this.pageVisible = true;
    this.stack.pushPath({ name: 'notifications' }, false);
    this.applicationContext = this.getUIContext().getHostContext()?.getApplicationContext();
    this.applicationContext?.on('applicationStateChange', this.applicationState);
    this.refreshSystemNotification(true);
  }
  aboutToDisappear(): void {
    this.pageVisible = false; this.confirmationOpen = false; this.notificationPermissionEpoch++; this.checkingSystemNotification = false;
    this.pendingNotification = undefined;
    this.applicationContext?.off('applicationStateChange', this.applicationState);
    this.applicationContext = undefined;
  }
  private channelEnabled(channel: NotificationChannel): boolean {
    return channel.value;
  }
  private retry(): void {
    if (!this.pageVisible || this.store.screen !== 'notifications' || this.store.busy || this.store.loading || this.checkingSystemNotification || this.confirmationOpen) return;
    if (this.onRetry) this.onRetry();
    this.refreshSystemNotification(true);
  }
  private settingsChanged(): void {
    if (!this.pendingNotification || this.pendingCompletionQueued) return;
    this.pendingCompletionQueued = true;
    Promise.resolve().then((): void => {
      this.pendingCompletionQueued = false;
      this.completePendingNotification();
    });
  }
  private completePendingNotification(): void {
    const choice: NotificationChoice | undefined = this.pendingNotification;
    if (!choice) return;
    if (!this.pageVisible || this.store.screen !== 'notifications' || this.pendingNotificationToken !== this.store.token) {
      this.pendingNotification = undefined;
      return;
    }
    if (!this.applicationForeground || this.checkingSystemNotification || !this.systemNotificationEnabled || this.store.busy || this.store.loading || this.store.writeUncertain) return;
    this.pendingNotification = undefined;
    const channel: NotificationChannel | undefined = this.store.notifications.flatMap((group: NotificationGroup): NotificationCategory[] => group.categories)
      .flatMap((category: NotificationCategory): NotificationChannel[] => category.channels)
      .find((item: NotificationChannel): boolean => item.channel === choice.type && item.section === choice.section && item.option === choice.option && item.editable === true);
    if (channel && !channel.value && this.onRequest) this.onRequest('notificationSet', JSON.stringify(choice));
  }
  private async refreshSystemNotification(promptWhenDisabled: boolean = false): Promise<void> {
    if (!this.pageVisible || !this.applicationForeground || this.store.screen !== 'notifications') return;
    const token: number = this.store.token;
    const epoch: number = ++this.notificationPermissionEpoch;
    this.checkingSystemNotification = true;
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!this.pageVisible || !this.applicationForeground || this.store.screen !== 'notifications' || this.store.token !== token || this.notificationPermissionEpoch !== epoch) return;
      this.systemNotificationEnabled = enabled;
      if (!enabled) {
        this.pendingNotification = undefined;
        if (promptWhenDisabled) this.showSystemNotificationPrompt(token, epoch);
      }
    } catch (_) {
      if (this.pageVisible && this.applicationForeground && this.store.screen === 'notifications' && this.store.token === token && this.notificationPermissionEpoch === epoch) {
        this.pendingNotification = undefined;
        this.store.error = PinmonyI18n.message('pm_system_notifications_check_failed');
      }
    } finally {
      if (this.notificationPermissionEpoch === epoch) {
        this.checkingSystemNotification = false;
        this.completePendingNotification();
      }
    }
  }
  private change(channel: NotificationChannel, value: boolean): void {
    if (!this.pageVisible || this.confirmationOpen || this.checkingSystemNotification || value === this.channelEnabled(channel) || !channel.editable || this.store.busy || this.store.loading || this.store.writeUncertain) return;
    const choice: NotificationChoice = { type: channel.channel || '', section: channel.section || '', option: channel.option || '', value: value };
    if (choice.type === 'news' && value) { this.enableInAppNotification(choice); return; }
    if (!notificationGlobal(choice.type, choice.section, choice.option) || value) {
      if (this.onRequest) this.onRequest('notificationSet', JSON.stringify(choice));
      return;
    }
    const token: number = this.store.token;
    this.confirmationOpen = true;
    this.getUIContext().showAlertDialog(PinmonyImmersiveLight.alertOptions({
      title: this.uiText('pm_are_you_sure_8889016c'),
      message: this.uiText(choice.type === 'push' ? 'pm_notifications_disable_push' : choice.type === 'email' ? 'pm_notifications_disable_email' : 'pm_notifications_disable_news'),
      alignment: DialogAlignment.Bottom,
      primaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: () => { this.confirmationOpen = false; } },
      secondaryButton: { value: this.uiText('pm_notifications_turn_off_all'), fontColor: $r('app.color.accent'), action: () => {
        const owned: boolean = this.confirmationOpen && this.pageVisible && this.store.screen === 'notifications' && this.store.token === token;
        this.confirmationOpen = false;
        if (owned && !this.store.busy && !this.store.loading && !this.store.writeUncertain && this.onRequest) this.onRequest('notificationSet', JSON.stringify(choice));
      } },
      cancel: () => { this.confirmationOpen = false; }
    }));
  }
  private permissionCurrent(token: number, epoch: number): boolean {
    return this.permissionOwner(token, epoch) && !this.store.busy && !this.store.loading && !this.store.writeUncertain;
  }
  private permissionOwner(token: number, epoch: number): boolean {
    return this.pageVisible && this.applicationForeground && this.store.screen === 'notifications' && this.store.token === token &&
      this.notificationPermissionEpoch === epoch;
  }
  private showSystemNotificationPrompt(token: number, epoch: number, choice?: NotificationChoice): void {
    if (this.confirmationOpen || !this.permissionOwner(token, epoch)) return;
    this.confirmationOpen = true;
    this.getUIContext().showAlertDialog(PinmonyImmersiveLight.alertOptions({
      title: this.uiText('pm_system_notifications_off'),
      message: this.uiText('pm_system_notifications_enable_message'),
      alignment: DialogAlignment.Center,
      primaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: () => { this.confirmationOpen = false; } },
      secondaryButton: { value: this.uiText('pm_system_notifications_open_settings'), action: () => {
        const owned: boolean = this.confirmationOpen && (choice ? this.permissionCurrent(token, epoch) : this.permissionOwner(token, epoch));
        this.confirmationOpen = false;
        if (owned) {
          this.pendingNotification = choice;
          this.pendingNotificationToken = token;
          this.openSystemNotificationSettings(token, epoch);
        }
      } },
      cancel: () => { this.confirmationOpen = false; }
    }));
  }
  private async enableInAppNotification(choice: NotificationChoice): Promise<void> {
    const token: number = this.store.token;
    const epoch: number = ++this.notificationPermissionEpoch;
    this.checkingSystemNotification = true;
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!this.permissionCurrent(token, epoch)) return;
      this.systemNotificationEnabled = enabled;
      if (enabled) {
        if (this.onRequest) this.onRequest('notificationSet', JSON.stringify(choice));
        return;
      }
      this.showSystemNotificationPrompt(token, epoch, choice);
    } catch (_) {
      if (this.permissionCurrent(token, epoch)) this.store.error = PinmonyI18n.message('pm_system_notifications_check_failed');
    } finally {
      if (this.notificationPermissionEpoch === epoch) this.checkingSystemNotification = false;
    }
  }
  private async openSystemNotificationSettings(token: number, epoch: number): Promise<void> {
    const pending: NotificationChoice | undefined = this.pendingNotification;
    try {
      const context: common.UIAbilityContext | undefined = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (!context) throw new Error('context');
      await notificationManager.openNotificationSettings(context);
    } catch (_) {
      if (this.pendingNotification === pending && this.permissionOwner(token, epoch) && this.pendingNotificationToken === token) {
        this.pendingNotification = undefined;
        this.store.error = PinmonyI18n.message('pm_system_notifications_open_failed');
      }
    }
  }
  @Builder
  private destination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.store.error) {
            PinmonyActionNotice({ message: PinmonyI18n.render(this.store.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { this.retry(); }, actionEnabled: !this.store.busy && !this.store.loading && !this.checkingSystemNotification && !this.confirmationOpen })
          }
          ForEach(this.store.notifications, (group: NotificationGroup) => {
            Text(PinmonyNotificationCopy.group(group, this.uiLanguage)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).margin({ top: 16 })
            Column() {
            ForEach(group.categories, (category: NotificationCategory) => {
              Column({ space: 8 }) {
                Row() {
                  Text(PinmonyNotificationCopy.category(category, this.uiLanguage)).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
                  SymbolGlyph(this.expanded.includes(group.key + ':' + category.key) ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down')).fontSize(16).fontColor([$r('app.color.secondary_text')])
                }.width('100%').onClick(() => {
                  const key: string = group.key + ':' + category.key;
                  this.expanded = this.expanded.includes(key) ? this.expanded.filter((value: string): boolean => value !== key) : this.expanded.concat([key]);
                })
                if (this.expanded.includes(group.key + ':' + category.key)) {
                  if (category.description) { Text(PinmonyNotificationCopy.description(category, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text')) }
                  ForEach(category.channels, (channel: NotificationChannel) => {
                    Row() {
                      Text(PinmonyNotificationCopy.channel(channel, this.uiLanguage)).fontColor($r('app.color.primary_text')).layoutWeight(1)
                      Toggle({ type: ToggleType.Switch, isOn: this.channelEnabled(channel) })
                        .selectedColor($r('app.color.accent')).margin({ left: 12, right: 12, top: 8, bottom: 8 })
                        .enabled(channel.editable === true && !this.confirmationOpen && !this.checkingSystemNotification && !this.store.busy && !this.store.loading && !this.store.writeUncertain)
                        .accessibilityText(PinmonyNotificationCopy.category(category, this.uiLanguage) + ' ' + PinmonyNotificationCopy.channel(channel, this.uiLanguage))
                        .onChange((value: boolean) => {
                          this.change(channel, value);
                        })
                    }.width('100%')
                  }, (channel: NotificationChannel): string => ((channel.channel || channel.label) + ':' + (channel.section || '') + ':' + (channel.option || '') + ':' + channel.value + ':' + this.store.token + ':' + this.store.busy + ':' + this.confirmationOpen + ':' + this.checkingSystemNotification) + ':' + this.uiLanguage)
                } else {
                  Text(PinmonyNotificationCopy.summary(category, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
                }
              }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            }, (category: NotificationCategory): string => group.key + ':' + category.key + ':' + JSON.stringify(category) + ':' + this.uiLanguage)
            }.width('100%')
          }, (group: NotificationGroup): string => group.key + ':' + JSON.stringify(group) + ':' + this.uiLanguage)
          if (!this.store.loading && !this.store.error && !this.store.notifications.length) { Text(this.uiText("pm_no_notification_settings_available_b02ac445")).fontColor($r('app.color.secondary_text')) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: this.titleContentInset(), bottom: 28 })
      }.width('100%').height('100%').align(Alignment.TopStart)
        .opacity(this.store.loading ? 0.4 : 1).enabled(!this.store.loading)
        .scrollBarMargin({ start: LengthMetrics.vp(this.titleContentInset()) })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
      content: { title: { mainTitle: this.uiText('pm_notifications_4b6ded8a') }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } }, this.hdsDarkMode))
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
