import { PinmonyHdsTitleBar, PinmonyImmersiveLight } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit';

@Component
export struct PinmonyBoardSectionPage {
  @StorageProp('pinmonySheetWindowWidthVp') private sheetWindowWidthVp: number = 0;
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop ready: boolean = false;
  @Prop @Watch('backRequested') closeRequest: number = 0;
  private backRequested(): void { if (this.closeRequest > 0) this.requestClose(); }
  onClose: () => void = () => {};
  onCreate: (name: string) => Promise<string> = async () => this.uiText("pm_this_action_is_unavailable_f3ea5b4e");
  @State private busy: boolean = false;
  @State private submitted: boolean = false;
  @State private error: string = '';
  @State private name: string = '';
  @State private visible: boolean = false;
  @State private closePending: boolean = false;
  private readonly scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.visible = true; }
  private requestClose(): void {
    if (this.busy || this.closePending) return;
    this.closePending = true;
    this.visible = false;
  }
  private finishClose(): void {
    if (this.visible || !this.closePending) return;
    this.closePending = false;
    this.onClose();
  }
  @Builder
  private sectionForm() {
    Column({ space: 20 }) {
      TextInput({ placeholder: this.uiText("pm_section_name_e63b3281"), text: this.name }).maxLength(100)
        .enabled(!this.busy && !this.submitted)
        .accessibilityText(this.uiText("pm_section_name_0e25c295")).onChange((value: string) => { this.name = value; })
      if (this.busy) { LoadingProgress().color($r('app.color.accent')).width(24).height(24) }
      if (!this.ready && !this.busy && !this.error) { Text(this.uiText("pm_restoring_board_please_wait_9e819a8a")).fontColor($r('app.color.secondary_text')).fontSize(14) }
      if (this.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.error, this.uiLanguage) }) }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }
  @Builder
  private nextButton() {
      Button(this.uiText("pm_next_acfc4e74")).width('100%').height(48).backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.detail_on_accent')).enabled(this.ready && !!this.name.trim() && !this.busy && !this.submitted && !this.closePending)
        .onClick(async () => {
          if (!this.ready || this.busy || this.submitted || this.closePending || !this.name.trim()) return;
          this.busy = true; this.submitted = true;
          try { this.error = await this.onCreate(this.name.trim()); }
          catch (_) { this.error = PinmonyI18n.message("pm_creation_not_confirmed_close_and_refresh_to_check_before_submitt_99e27f05"); }
          finally { this.busy = false; }
          if (this.error && !PinmonyI18n.isUnconfirmed(this.error)) this.submitted = false;
          if (!this.error) this.requestClose();
        })
  }
  @Builder
  private sectionSheet() {
    HdsNavigation() {
      Column() {
        Scroll(this.scroller) { this.sectionForm() }
          .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
          .scrollBarMargin({start:LengthMetrics.vp(0)})
        Column() { this.nextButton() }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }.width('100%').height('100%')
    }.mode(NavigationMode.Stack).width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MODAL).bindToScrollable([this.scroller])
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), { avoidLayoutSafeArea: false, enableComponentSafeArea: true,
        style: PinmonyHdsTitleBar.modalStyle(this.immersiveLightMode),
        content: { title: { mainTitle: this.uiText("pm_add_section_779008ec") }, menu: { value: [{ content: {
          type: IconStyleMode.SMALL, isEnabled: !this.busy, label: this.uiText("pm_close_3fd47edc"), action: () => this.requestClose()
        } }] } } }, this.hdsDarkMode))
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    Column().width('100%').height('100%').backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.visible, this.sectionSheet(), PinmonyImmersiveLight.sheetOptions({
      radius: LengthMetrics.vp(32),
      preferType: this.sheetWindowWidthVp >= 600 ? SheetType.CENTER : undefined,
        onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyBoardSectionPage.visible radius=uniform-32vp'); },
        height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM], dragBar: true, showClose: false,
        backgroundColor: $r('app.color.page_background'),
        onWillSpringBackWhenDismiss: (action: SpringBackAction): void => { if (this.busy) action.springBack(); },
        onDisappear: (): void => this.finishClose(),
        onWillDismiss: (action: DismissSheetAction) => {
          if (this.busy) return;
          this.requestClose(); action.dismiss();
        }
      }, this.immersiveLightMode, false))
  }
}
