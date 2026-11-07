import { PinmonyI18n } from 'common_foundation';

// Gesture and row measurement belong to the native ListItem.
@Component
export struct PinmonyInboxConversationSwipe {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop active: boolean = false;
  onRemove: () => void = () => {};
  build() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash')).fontSize(22)
          .fontColor([$r('app.color.detail_on_accent')])
      }.width(40).height(40).padding(0)
        .backgroundColor($r('app.color.detail_save_accent'))
        .accessibilityText(PinmonyI18n.text('pm_remove_chat_window', this.uiLanguage))
        .enabled(this.active).onClick(() => { if (this.active) this.onRemove(); })
    }.width(80).height(72).justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.input_surface'))
  }
}
