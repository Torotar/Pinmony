import { PinmonyI18n } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { NotificationGroup, NotificationCategory, NotificationChannel } from '../models/PinmonyNotifications';
@Component
export struct PinmonyNotificationsPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink store: PinmonySettingsStore;
  onBack?: () => void;
  onRetry?: () => void;
  @State private expanded: string = '';
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.stack.pushPath({ name: 'notifications' }, false); }
  @Builder
  private destination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.store.error) {
            Text(PinmonyI18n.render(this.store.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("重试")).onClick(() => { if (this.onRetry) this.onRetry(); })
          }
          ForEach(this.store.notifications, (group: NotificationGroup) => {
            Text(group.label).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).margin({ top: 16 })
            ForEach(group.categories, (category: NotificationCategory) => {
              Column({ space: 8 }) {
                Row() {
                  Text(category.label).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor([$r('app.color.secondary_text')])
                }.width('100%').onClick(() => { this.expanded = this.expanded === group.key + category.key ? '' : group.key + category.key; })
                Text(category.summary).fontSize(14).fontColor($r('app.color.secondary_text'))
                if (this.expanded === group.key + category.key) {
                  Text(category.description).fontSize(14).fontColor($r('app.color.secondary_text'))
                  ForEach(category.channels, (channel: NotificationChannel) => {
                    Row() {
                      Text(channel.label).fontColor($r('app.color.primary_text')).layoutWeight(1)
                      Toggle({ type: ToggleType.Switch, isOn: channel.value }).enabled(false)
                    }.width('100%')
                  })
                }
              }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8, bottom: 8 })
            })
          })
          if (!this.store.loading && !this.store.error && !this.store.notifications.length) { Text(this.uiText("暂无通知设置")).fontColor($r('app.color.secondary_text')) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, bottom: 28 })
      }.width('100%').height('100%').align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.uiText("通知") }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } })
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
