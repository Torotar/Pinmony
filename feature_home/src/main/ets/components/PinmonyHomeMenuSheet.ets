import { PinmonyHomeMenuOption, PinmonyHomeMenuState } from '../models/PinmonyHomeMenu';

@Component
export struct PinmonyHomeMenuSheet {
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
      Swiper() {
        ForEach(this.sharePages(), (page: PinmonyHomeMenuOption[]) => {
          Row({ space: 8 }) {
          ForEach(page, (option: PinmonyHomeMenuOption) => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 8 }) {
                Image(this.platformIcon(option.label)).width(56).height(56).objectFit(ImageFit.Contain)
                Text(option.label === '短信' ? '消息' : option.label)
                  .fontSize(13).fontColor($r('app.color.primary_text')).maxLines(1)
              }.width('100%')
            }
            .layoutWeight(1).height(88).padding(0)
            .backgroundColor(Color.Transparent)
            .enabled(option.enabled && !this.menu.busy)
            .onClick(() => { if (this.onAction) this.onAction(option.id); })
            .accessibilityText('分享到' + option.label)
          }, (option: PinmonyHomeMenuOption) => option.id)
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
      if (this.menu.loading) {
        LoadingProgress().width(28).height(28)
      } else if (this.menu.error) {
        Text(this.menu.error).fontSize(14).fontColor($r('app.color.secondary_text'))
        Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
      } else {
        ForEach(this.menu.actions, (option: PinmonyHomeMenuOption) => {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Image(option.id === 'home-save' ? $r('app.media.lucide_bookmark') :
                option.id === 'home-download' ? $r('app.media.lucide_download') :
                option.id === 'home-see-more' ? $r('app.media.lucide_heart') : $r('app.media.lucide_eye_off'))
                .width(22).height(22).objectFit(ImageFit.Contain)
              Text(option.label).fontSize(16).fontColor($r('app.color.primary_text')).layoutWeight(1)
            }.width('100%').height(48)
          }
          .width('100%').backgroundColor(Color.Transparent)
          .enabled(option.enabled && !this.menu.busy)
          .onClick(() => { if (this.onAction) this.onAction(option.id); })
        }, (option: PinmonyHomeMenuOption) => option.id + ':' + option.enabled.toString())
      }
      if (this.menu.busy) { LoadingProgress().width(24).height(24) }
      if (this.menu.feedback) {
        Text(this.menu.feedback).fontSize(13).fontColor($r('app.color.secondary_text'))
      }
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
}
