import { PinmonyI18n } from 'common_foundation';
@Component
export struct PinmonyLoadingOverlay {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop message: string = PinmonyI18n.message("pm_loading_please_wait_b6aaac70");

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 12 }) {
        LoadingProgress().width(48).height(48).color($r('app.color.detail_on_accent'))
          .accessibilityLevel('no')
        Text(this.message).fontSize(15).fontColor($r('app.color.detail_on_accent'))
          .textAlign(TextAlign.Center)
      }.padding(24)
    }.width('100%').height('100%').backgroundColor('#66000000')
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {})
      .accessibilityText(this.message)
      .accessibilityLevel('yes')
  }
}
