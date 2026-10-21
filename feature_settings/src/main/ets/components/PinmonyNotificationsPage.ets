import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { NotificationChoice, NotificationGroup, NotificationCategory, NotificationChannel, notificationGlobal } from '../models/PinmonyNotifications';
@Component
export struct PinmonyNotificationsPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink store: PinmonySettingsStore;
  onBack?: () => void;
  onRetry?: () => void;
  onRequest?: (action: string, value: string) => void;
  @State private expanded: string[] = [];
  @State private confirmationOpen: boolean = false;
  private pageVisible: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.pageVisible = true; this.stack.pushPath({ name: 'notifications' }, false); }
  aboutToDisappear(): void { this.pageVisible = false; this.confirmationOpen = false; }
  private change(channel: NotificationChannel, value: boolean): void {
    if (!this.pageVisible || this.confirmationOpen || value === channel.value || !channel.editable || this.store.busy || this.store.loading || this.store.writeUncertain) return;
    const choice: NotificationChoice = { type: channel.channel || '', section: channel.section || '', option: channel.option || '', value: value };
    if (!notificationGlobal(choice.type, choice.section, choice.option) || value) {
      if (this.onRequest) this.onRequest('notificationSet', JSON.stringify(choice));
      return;
    }
    const token: number = this.store.token;
    this.confirmationOpen = true;
    this.getUIContext().showAlertDialog({
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
    });
  }
  @Builder
  private destination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.store.error) {
            Text(PinmonyI18n.render(this.store.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("pm_retry_b8784c8d")).enabled(!this.store.busy && !this.store.loading).onClick(() => { if (this.onRetry) this.onRetry(); })
          }
          ForEach(this.store.notifications, (group: NotificationGroup) => {
            Text(group.label).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).margin({ top: 16 })
            ForEach(group.categories, (category: NotificationCategory) => {
              Column({ space: 8 }) {
                Row() {
                  Text(category.label).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor([$r('app.color.secondary_text')])
                }.width('100%').onClick(() => {
                  const key: string = group.key + ':' + category.key;
                  this.expanded = this.expanded.includes(key) ? this.expanded.filter((value: string): boolean => value !== key) : this.expanded.concat([key]);
                })
                if (this.expanded.includes(group.key + ':' + category.key)) {
                  ForEach(category.channels, (channel: NotificationChannel) => {
                    Row() {
                      Text(channel.label).fontColor($r('app.color.primary_text')).layoutWeight(1)
                      Toggle({ type: ToggleType.Switch, isOn: channel.value })
                        .enabled(channel.editable === true && !this.confirmationOpen && !this.store.busy && !this.store.loading && !this.store.writeUncertain)
                        .accessibilityText(category.label + ' ' + channel.label)
                        .onChange((value: boolean) => {
                          this.change(channel, value);
                        })
                    }.width('100%')
                  }, (channel: NotificationChannel): string => (channel.channel || channel.label) + ':' + (channel.section || '') + ':' + (channel.option || '') + ':' + channel.value + ':' + this.store.token + ':' + this.store.busy + ':' + this.confirmationOpen)
                }
              }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8, bottom: 8 })
            })
          })
          if (!this.store.loading && !this.store.error && !this.store.notifications.length) { Text(this.uiText("pm_no_notification_settings_available_b02ac445")).fontColor($r('app.color.secondary_text')) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, bottom: 28 })
      }.width('100%').height('100%').align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
      content: { title: { mainTitle: this.uiText("pm_notifications_4b6ded8a") }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } })
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
