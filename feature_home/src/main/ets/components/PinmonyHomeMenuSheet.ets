import { PinmonyI18n } from 'common_foundation';
import { PinmonyHomeMenuOption, PinmonyHomeMenuState } from '../models/PinmonyHomeMenu';

@Component
export struct PinmonyHomeMenuSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop menu: PinmonyHomeMenuState = {} as PinmonyHomeMenuState;
  @State private shareColumns: number = 4;
  onAction?: (id: string) => void;
  onRetry?: () => void;

  private sharePages(): PinmonyHomeMenuOption[][] {
    const pages: PinmonyHomeMenuOption[][] = [];
    for (let index: number = 0; index < this.menu.options.length; index += this.shareColumns) {
      pages.push(this.menu.options.slice(index, index + this.shareColumns));
    }
    return pages;
  }

  private emptySlots(count: number): number[] {
    const slots: number[] = [];
    for (let index: number = count; index < this.shareColumns; index++) slots.push(index);
    return slots;
  }

  private platformIcon(label: string): Resource {
    if (label === 'Messenger') return $r('app.media.share_messenger');
    if (label === 'WhatsApp') return $r('app.media.share_whatsapp');
    if (label === '短信') return $r('app.media.share_messages');
    if (label === 'Facebook') return $r('app.media.share_facebook');
    return $r('app.media.share_x');
  }

  build() {
    Column({ space: 16 }) {
      if (this.menu.options.length > 0) {
      Swiper() {
        ForEach(this.sharePages(), (page: PinmonyHomeMenuOption[]) => {
          Row({ space: 8 }) {
          ForEach(page, (option: PinmonyHomeMenuOption) => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 8 }) {
                Image(this.platformIcon(option.label)).width(56).height(56).objectFit(ImageFit.Contain)
                Text(option.label === '短信' ? this.uiText("消息") : option.label)
                  .fontSize(13).fontColor($r('app.color.primary_text')).maxLines(1)
              }.width('100%')
            }
            .layoutWeight(1).height(88).padding(0)
            .backgroundColor(Color.Transparent)
            .enabled(option.enabled && !this.menu.busy)
            .onClick(() => { if (this.onAction) this.onAction(option.id); })
            .accessibilityText(this.uiText("分享到") + option.label)
          }, (option: PinmonyHomeMenuOption) => option.id + this.uiLanguage)
          ForEach(this.emptySlots(page.length), (slot: number) => {
            Blank().layoutWeight(1)
          }, (slot: number) => slot.toString())
          }.width('100%').height(88)
        }, (page: PinmonyHomeMenuOption[]) => page.map((option: PinmonyHomeMenuOption) => option.id).join(':'))
      }
      .width('100%').height(88).loop(false).indicator(false)
      .onSizeChange((_oldSize: SizeOptions, newSize: SizeOptions) => {
        this.shareColumns = Math.max(1, Math.min(5, Math.floor(Number(newSize.width) / 80)));
      })
      Divider().color($r('app.color.input_surface'))
      }
      if (this.menu.loading) {
        LoadingProgress().width(28).height(28)
      } else if (this.menu.error) {
        Text(PinmonyI18n.render(this.menu.error, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
        if (!/取消收藏|收藏校验/.test(this.menu.error)) {
          Button(this.uiText("重试")).onClick(() => { if (this.onRetry) this.onRetry(); })
        }
      } else {
        Column() {
        ForEach(this.menu.actions, (option: PinmonyHomeMenuOption) => {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 14 }) {
              if (option.id === 'board-menu-move') {
                SymbolGlyph($r('sys.symbol.arrow_right'))
                  .fontSize(28).fontColor([$r('app.color.primary_text')]).width(28).height(28)
              } else {
              Image(option.id === 'home-save' || option.id === 'board-menu-cancel-save' ? $r('app.media.lucide_bookmark') :
                option.id === 'home-edit' ? $r('app.media.lucide_pencil') :
                option.id === 'home-download' ? $r('app.media.lucide_download') :
                option.id === 'home-see-more' ? $r('app.media.lucide_heart') :
                option.id === 'home-system-share' ? $r('app.media.lucide_share_2') : $r('app.media.lucide_eye_off'))
                .width(28).height(28).objectFit(ImageFit.Contain)
              }
              Text(PinmonyI18n.optionLabel(option.id, option.label, this.uiLanguage)).fontSize(17).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.primary_text')).layoutWeight(1).maxLines(2)
            }.width('100%').padding({ left: 24, right: 20, top: 14, bottom: 14 })
          }
          .width('100%').padding(0).backgroundColor(Color.Transparent)
          .enabled(option.enabled && !this.menu.busy)
          .onClick(() => { if (this.onAction) this.onAction(option.id); })
        }, (option: PinmonyHomeMenuOption) => option.id + ':' + option.enabled.toString())
        }.width('100%')
      }
      if (this.menu.busy) { LoadingProgress().width(24).height(24) }
      if (this.menu.feedback) {
        Text(PinmonyI18n.render(this.menu.feedback, this.uiLanguage)).fontSize(13).fontColor($r('app.color.secondary_text'))
      }
    }.width('100%').padding({ left: this.menu.options.length > 0 ? 20 : 0,
      right: this.menu.options.length > 0 ? 20 : 0, top: this.menu.options.length > 0 ? 16 : 0, bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
  }
}
