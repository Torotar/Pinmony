import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { MoreSheetOption } from '../models/PinmonySheets';
@Component
export struct PinmonyMoreSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink pinStore: PinmonyPinStore;
  onAction: (id: string) => void = (): void => {};
  onRetry: () => void = (): void => {};
  build() {
    Column() {
      if (this.pinStore.moreLoading) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(24)
            .height(24)
          Text(this.uiText("pm_loading_options_a22ab0b2"))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .height(72)
        .padding({ left: 20, right: 20 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.pinStore.moreOptions, (option: MoreSheetOption, index: number) => {
              if (index > 0 && option.group !== this.pinStore.moreOptions[index - 1].group) {
                Divider()
                  .color('#4D8A8A8A')
                  .margin({ left: 20, right: 20, top: 6, bottom: 6 })
              }
              Row({ space: 14 }) {
                if (/^detail-(download|see-more|see-less|share)$/.test(option.id)) {
                  Image(option.id === 'detail-download' ? $r('app.media.lucide_download') :
                    option.id === 'detail-see-more' ? $r('app.media.lucide_heart') :
                    option.id === 'detail-see-less' ? $r('app.media.lucide_eye_off') : $r('app.media.lucide_share_2'))
                    .width(28).height(28).objectFit(ImageFit.Contain)
                } else if (option.id === 'detail-favorite') {
                  SymbolGlyph($r('sys.symbol.star')).fontSize(28).fontColor([$r('app.color.primary_text')])
                } else if (option.id === 'detail-edit') {
                  Image($r('app.media.lucide_pencil')).width(28).height(28)
                    .objectFit(ImageFit.Contain)
                } else if (option.id === 'detail-ai-help') {
                  SymbolGlyph($r('sys.symbol.info_circle'))
                    .fontSize(28).fontColor([$r('app.color.primary_text')])
                } else if (option.icon) {
                  Image(option.icon)
                    .width(28)
                    .height(28)
                    .objectFit(ImageFit.Contain)
                }
                Column() {
                  Text(PinmonyI18n.optionLabel(option.id, option.label, this.uiLanguage))
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.primary_text'))
                    .maxLines(2)
                  if (option.subtitle && !/详细了解.*AI|learn more.*AI/i.test(option.label)) {
                    Text(PinmonyI18n.render(option.subtitle, this.uiLanguage))
                      .fontSize(12)
                      .fontColor($r('app.color.secondary_text'))
                      .maxLines(3)
                      .margin({ top: 3 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 24, right: 20, top: 14, bottom: 14 })
              .opacity(option.enabled ? 1 : 0.4)
              .accessibilityText(PinmonyI18n.optionLabel(option.id, option.label, this.uiLanguage))
              .onClick(() => {
                if (option.enabled) this.onAction(option.id);
              })
            }, (option: MoreSheetOption) => option.id + ':' + option.enabled.toString() + ':' + this.uiLanguage)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 520 })
      }
      if (this.pinStore.moreError) {
        Row({ space: 12 }) {
          Text(PinmonyI18n.render(this.pinStore.moreError, this.uiLanguage))
            .fontSize(14)
            .fontColor('#D94A4A')
            .layoutWeight(1)
          Button(this.uiText("pm_retry_b8784c8d"))
            .onClick(() => this.onRetry())
        }
        .margin({ left: 20, right: 20, top: 12 })
      }
    }
    .width('100%')
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
  }


}
