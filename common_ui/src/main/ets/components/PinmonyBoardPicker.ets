import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardPlaceholder } from './PinmonyBoardPlaceholder';

@Component
export struct PinmonyBoardPickerRow {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  @Prop title: string = '';
  @Prop imageUrl: string = '';
  @Prop secret: boolean = false;
  @Prop hasSections: boolean = false;
  @Prop indented: boolean = false;
  @Prop quickSave: boolean = false;
  @Prop actionEnabled: boolean = true;
  onSelect?: () => void;
  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        if(this.imageUrl) { Image(this.imageUrl).width(56).height(56).borderRadius(16).objectFit(ImageFit.Cover) }
        else if(this.quickSave) {
          Stack() { Image($r('app.media.profile_quick_save')).width(28).height(28).fillColor($r('app.color.primary_text')) }
            .width(56).height(56).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
        } else { PinmonyBoardPlaceholder() }
        Text(PinmonyI18n.render(this.title,this.language)).fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text')).maxLines(2).layoutWeight(1)
        if(this.secret || this.hasSections) {
          Row({space:4}) {
            if(this.secret) { Image($r('app.media.board_private_lock')).width(18).height(18).fillColor($r('app.color.secondary_text')) }
            if(this.hasSections) { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.secondary_text')]) }
          }.alignItems(VerticalAlign.Center)
        }
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').constraintSize({minHeight:80}).padding({left:this.indented ? 24 : 0,right:0,top:8,bottom:8})
      .borderRadius(12).backgroundColor(Color.Transparent).enabled(this.actionEnabled)
      .opacity(this.actionEnabled ? 1 : 0.4).onClick(() => this.onSelect?.())
      .accessibilityText(PinmonyI18n.render(this.title,this.language) + (this.secret ? ' · ' + PinmonyI18n.text('pm_secret_board_afc1422a',this.language) : ''))
  }
}

@Component
export struct PinmonyBoardPickerFooter {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  @Prop labelKey: string = 'pm_create_board_513babc9';
  @Prop back: boolean = false;
  @Prop inset: number = 16;
  @Prop actionEnabled: boolean = true;
  onSelect?: () => void;
  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Stack({alignContent:Alignment.Center}) {
          SymbolGlyph(this.back ? $r('sys.symbol.chevron_left') : $r('sys.symbol.plus'))
            .fontSize(26).fontColor([$r('app.color.primary_text')])
        }.width(44).height(44).backgroundColor($r('app.color.surface_muted')).borderRadius(16)
        Text(PinmonyI18n.text(this.labelKey,this.language)).fontSize(19).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text')).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').height(76).padding({left:this.inset,right:this.inset,top:12,bottom:20})
      .borderRadius(0).backgroundColor($r('app.color.page_background')).enabled(this.actionEnabled).onClick(() => this.onSelect?.())
  }
}
