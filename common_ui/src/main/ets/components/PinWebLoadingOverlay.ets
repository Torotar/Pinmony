@Component
export struct PinWebLoadingOverlay {
  @Prop message: string = '正在加载，请稍候…';

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
