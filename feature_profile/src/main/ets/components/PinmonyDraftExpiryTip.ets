import { PinmonyI18n } from 'common_foundation';

export interface PinmonyDraftExpiryTipOptions { source: string; }

@Component
struct PinmonyDraftExpiryTip {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  source: string = '';
  build() {
    Text(PinmonyI18n.text(this.source, this.language))
      .fontSize(16).fontColor($r('app.color.primary_text'))
      .padding(16).constraintSize({ maxWidth: 300 })
  }
}

@Builder
export function buildPinmonyDraftExpiryTip(options: PinmonyDraftExpiryTipOptions) {
  PinmonyDraftExpiryTip({ source: options.source })
}
