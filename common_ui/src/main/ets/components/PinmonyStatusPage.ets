import { PinmonyActionNotice } from './PinmonyActionNotice';
import { PinmonyI18n } from 'common_foundation';
@Component
export struct PinmonyStatusPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
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
      if (this.loading) {
      Text(PinmonyI18n.render(this.title, this.uiLanguage)).fontSize(18).fontColor($r('app.color.primary_text'))
      if (this.message) {
        Text(PinmonyI18n.render(this.message, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
          .textAlign(TextAlign.Center).maxLines(4).margin({ left: 24, right: 24 })
      }
      }
      if (!this.loading) {
        PinmonyActionNotice({ message: PinmonyI18n.render(this.message || this.title, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.onRetry() })
      }
      if (this.showBack) {
        Button(this.uiText("pm_back_572cf45b")).onClick(() => this.onBack())
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
