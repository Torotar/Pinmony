import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyCreatedPin, PinmonyOrganizeSnapshot } from '../models/PinmonyProfile';
import { PinmonyOrganizePage } from './PinmonyOrganizePage';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

// Publish owns this entry point so its board flow can evolve independently
// from the profile's ordinary "整理到图板" flow.
@Component
export struct PinmonyPublishBoardPage {
  @Prop @Watch('syncCreate') state: PinmonyPublishFlow = {} as PinmonyPublishFlow;
  @State private createVisible: boolean = false;
  @State private name: string = '';
  @State private secret: boolean = false;
  private readonly createScroller: Scroller = new Scroller();
  @Prop pins: PinmonyCreatedPin[] = [];
  @Prop pinsLoading: boolean = false;
  onAction: (action: string, value: string, secret: boolean) => void = () => {};

  aboutToAppear(): void { this.syncCreate(); }
  private syncCreate(): void { this.createVisible = this.state.phase === 'create'; }
  private closeCreate(): void {
    this.onAction(this.state.kind === 'board' || this.state.uncertain ? 'close' : 'boards', '', false);
  }
  @Builder
  private createForm() {
    Column({ space: 20 }) {
      TextInput({ placeholder: '图板名称', text: this.name }).maxLength(100)
        .enabled(!this.state.busy).onChange((value: string) => { this.name = value; })
      Row() {
        Text('设为私密图板').fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.secret }).enabled(!this.state.busy)
          .onChange((value: boolean) => { this.secret = value; })
      }.width('100%')
      if (this.state.error) { Text(this.state.error).fontColor($r('app.color.secondary_text')) }
      if (this.state.loading || this.state.busy) { LoadingProgress().width(28).height(28) }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }

  @Builder
  private createButton() {
      Button('创建图板').width('100%').height(48).backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.detail_on_accent'))
        .enabled(!!this.name.trim() && !this.state.loading && !this.state.busy && !this.state.uncertain)
        .onClick(() => this.onAction('create', this.name.trim(), this.secret))
  }
  @Builder
  private createSheet() {
    HdsNavigation() {
      Column() {
        Scroll(this.createScroller) { this.createForm() }
          .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
        Column() { this.createButton() }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }.width('100%').height('100%')
    }.width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MODAL).bindToScrollable([this.createScroller])
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
        content: { title: { mainTitle: '创建图板' }, menu: { value: [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          type: IconStyleMode.SMALL, label: '关闭', isEnabled: !this.state.busy,
          action: () => { if (!this.state.busy) { this.createVisible = false; this.closeCreate(); } }
        } }] } } })
      .backgroundColor($r('app.color.page_background'))
  }

  build() {
    if (this.state.phase === 'create') {
      Column().width('100%').height('100%').backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.None)
        .bindSheet($$this.createVisible, this.createSheet(), {
          radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
          onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyPublishBoardPage.createVisible radius=four-corners-32vp'); },
          height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM], dragBar: true, showClose: false,
          backgroundColor: $r('app.color.page_background'),
          onWillDismiss: (action: DismissSheetAction) => {
            if (this.state.busy) return;
            this.createVisible = false; this.closeCreate(); action.dismiss();
          }
        })
    } else {
      PinmonyOrganizePage({ state: this.state, pins: this.pins, pinsLoading: this.pinsLoading,
        publishing: true, standaloneBoard: false, onAction: this.onAction })
    }
  }
}
