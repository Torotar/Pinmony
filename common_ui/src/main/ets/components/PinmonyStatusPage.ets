@Component
export struct PinmonyStatusPage {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop loading: boolean = false;
  @Prop showBack: boolean = false;
  onRetry: () => void = () => {};
  onBack: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color($r('app.color.accent'))
      }
      Text(this.title).fontSize(18).fontColor($r('app.color.primary_text'))
      if (this.message) {
        Text(this.message).fontSize(14).fontColor($r('app.color.secondary_text'))
          .textAlign(TextAlign.Center).maxLines(4).margin({ left: 24, right: 24 })
      }
      if (!this.loading) {
        Button('重试').onClick(() => this.onRetry())
      }
      if (this.showBack) {
        Button('返回').onClick(() => this.onBack())
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
