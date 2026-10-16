import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

@Component
export struct PinmonyBoardSectionPage {
  @Prop ready: boolean = false;
  onClose: () => void = () => {};
  onCreate: (name: string) => Promise<string> = async () => '当前操作不可用';
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
      TextInput({ placeholder: '区块名称', text: this.name }).maxLength(100)
        .enabled(!this.busy && !this.submitted)
        .accessibilityText('图板区块名称').onChange((value: string) => { this.name = value; })
      Button('下一步').width('100%').height(48).backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.detail_on_accent')).enabled(this.ready && !!this.name.trim() && !this.busy && !this.submitted)
        .onClick(async () => {
          if (!this.ready || this.busy || this.submitted || !this.name.trim()) return;
          this.busy = true; this.submitted = true;
          try { this.error = await this.onCreate(this.name.trim()); }
          catch (_) { this.error = '创建结果未确认，请关闭后刷新核对，勿重复提交'; }
          finally { this.busy = false; }
          if (this.error && !this.error.includes('未确认')) this.submitted = false;
          if (!this.error) { this.visible = false; this.onClose(); }
        })
      if (this.busy) { LoadingProgress().width(24).height(24) }
      if (!this.ready && !this.busy && !this.error) { Text('正在恢复图板，请稍候').fontColor($r('app.color.secondary_text')).fontSize(14) }
      if (this.error) { Text(this.error).fontColor($r('app.color.secondary_text')).fontSize(14) }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }
  @Builder
  private sectionSheet() {
    HdsNavigation() {
      Scroll(this.scroller) { this.sectionForm() }
        .width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MODAL).bindToScrollable([this.scroller])
      .titleBar({ enableComponentSafeArea: true,
        style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: {
          backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
        content: { title: { mainTitle: '添加图板区块' }, menu: { value: [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          type: IconStyleMode.SMALL, isEnabled: !this.busy, label: '关闭', action: () => { if (!this.busy) { this.visible = false; this.onClose(); } }
        } }] } } })
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    Column().width('100%').height('100%').backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.visible, this.sectionSheet(), {
        height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM], dragBar: true, showClose: false,
        backgroundColor: $r('app.color.page_background'),
        onWillDismiss: (action: DismissSheetAction) => {
          if (this.busy) return;
          this.visible = false; this.onClose(); action.dismiss();
        }
      })
  }
}
