import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

@Component
export struct PinmonyBoardSectionPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop ready: boolean = false;
  onClose: () => void = () => {};
  onCreate: (name: string) => Promise<string> = async () => this.uiText("当前操作不可用");
  @State private busy: boolean = false;
  @State private submitted: boolean = false;
  @State private error: string = '';
  @State private name: string = '';
  @State private visible: boolean = false;
  private readonly scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.visible = true; }
  @Builder
  private sectionForm() {
    Column({ space: 20 }) {
      TextInput({ placeholder: this.uiText("区块名称"), text: this.name }).maxLength(100)
        .enabled(!this.busy && !this.submitted)
        .accessibilityText(this.uiText("图板区块名称")).onChange((value: string) => { this.name = value; })
      if (this.busy) { LoadingProgress().width(24).height(24) }
      if (!this.ready && !this.busy && !this.error) { Text(this.uiText("正在恢复图板，请稍候")).fontColor($r('app.color.secondary_text')).fontSize(14) }
      if (this.error) { Text(PinmonyI18n.render(this.error, this.uiLanguage)).fontColor($r('app.color.secondary_text')).fontSize(14) }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }
  @Builder
  private nextButton() {
      Button(this.uiText("下一步")).width('100%').height(48).backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.detail_on_accent')).enabled(this.ready && !!this.name.trim() && !this.busy && !this.submitted)
        .onClick(async () => {
          if (!this.ready || this.busy || this.submitted || !this.name.trim()) return;
          this.busy = true; this.submitted = true;
          try { this.error = await this.onCreate(this.name.trim()); }
          catch (_) { this.error = PinmonyI18n.message("创建结果未确认，请关闭后刷新核对，勿重复提交"); }
          finally { this.busy = false; }
          if (this.error && !PinmonyI18n.isUnconfirmed(this.error)) this.submitted = false;
          if (!this.error) { this.visible = false; this.onClose(); }
        })
  }
  @Builder
  private sectionSheet() {
    HdsNavigation() {
      Column() {
        Scroll(this.scroller) { this.sectionForm() }
          .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
        Column() { this.nextButton() }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }.width('100%').height('100%')
    }.width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MODAL).bindToScrollable([this.scroller])
      .titleBar({ enableComponentSafeArea: true,
        style: {
          scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
          originalStyle: {
            backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
            contentStyle: {
              menuStyle: { iconColor: $r('app.color.primary_text') },
              titleStyle: { mainTitleColor: $r('app.color.primary_text') }
            }
          },
          scrollEffectStyle: {
            contentStyle: {
              menuStyle: { iconColor: $r('app.color.primary_text') },
              titleStyle: { mainTitleColor: $r('app.color.primary_text') }
            }
          }
        },
        content: { title: { mainTitle: this.uiText("添加图板区块") }, menu: { value: [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          type: IconStyleMode.SMALL, isEnabled: !this.busy, label: this.uiText("关闭"), action: () => { if (!this.busy) { this.visible = false; this.onClose(); } }
        } }] } } })
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    Column().width('100%').height('100%').backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.visible, this.sectionSheet(), {
        radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
        onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyBoardSectionPage.visible radius=four-corners-32vp'); },
        height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM], dragBar: true, showClose: false,
        backgroundColor: $r('app.color.page_background'),
        onWillDismiss: (action: DismissSheetAction) => {
          if (this.busy) return;
          this.visible = false; this.onClose(); action.dismiss();
        }
      })
  }
}
