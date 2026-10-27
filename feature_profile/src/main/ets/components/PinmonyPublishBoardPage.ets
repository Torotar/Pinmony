import { PinmonyBoardPickerRow, PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyCreatedPin, PinmonyOrganizeSnapshot, PinmonyOrganizeBoard } from '../models/PinmonyProfile';
import { PinmonyOrganizePage } from './PinmonyOrganizePage';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

// Publish owns this entry point so its board flow can evolve independently
// from the profile's ordinary "整理到图板" flow.
@Component
export struct PinmonyPublishBoardPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('syncCreate') state: PinmonyPublishFlow = {} as PinmonyPublishFlow;
  @State private createVisible: boolean = false;
  @State private name: string = '';
  @State private secret: boolean = false;
  private readonly sectionPaths: NavPathStack = new NavPathStack();
  private readonly sectionsScroller: Scroller = new Scroller();
  private readonly createScroller: Scroller = new Scroller();
  @Prop pins: PinmonyCreatedPin[] = [];
  @Prop pinsLoading: boolean = false;
  onAction: (action: string, value: string, secret: boolean) => void = () => {};

  aboutToAppear(): void { this.syncCreate(); }
  private syncCreate(): void { this.createVisible = this.state.phase === 'create'; if (this.state.phase === 'sections' && !this.sectionPaths.size()) this.sectionPaths.pushPath({name:'sections'}); }
  private closeCreate(): void {
    this.onAction(this.state.kind === 'board' || this.state.uncertain ? 'close' : 'boards', '', false);
  }
  @Builder
  private createForm() {
    Column({ space: 20 }) {
      TextInput({ placeholder: this.uiText("pm_board_name_dd9a7122"), text: this.name }).maxLength(100)
        .enabled(!this.state.busy).onChange((value: string) => { this.name = value; })
      Row() {
        Text(this.uiText("pm_make_secret_228cf25e")).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Checkbox().select(this.secret).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12).enabled(!this.state.busy)
          .onChange((value: boolean) => { this.secret = value; })
      }.width('100%')
      if (this.state.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.state.error, this.uiLanguage) }) }
      if (this.state.loading || this.state.busy) { LoadingProgress().width(28).height(28) }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }

  @Builder
  private createButton() {
      Button(this.uiText("pm_create_board_513babc9")).width('100%').height(48).backgroundColor($r('app.color.accent'))
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
        style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
          scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
          systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
          originalStyle: {
            backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
            contentStyle: {
              menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
              titleStyle: { mainTitleColor: $r('app.color.primary_text') }
            }
          },
          scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
            contentStyle: {
              menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
              titleStyle: { mainTitleColor: $r('app.color.primary_text') }
            }
          }
        },
        content: { title: { mainTitle: this.uiText("pm_create_board_513babc9") }, menu: { value: [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          type: IconStyleMode.SMALL, label: this.uiText("pm_close_3fd47edc"), isEnabled: !this.state.busy,
          action: () => { if (!this.state.busy) { this.createVisible = false; this.closeCreate(); } }
        } }] } } })
      .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private sectionsDestination() {
    HdsNavDestination() {
      Scroll(this.sectionsScroller) {
        Column({space:8}) {
          if (this.state.loading) { LoadingProgress().width(28).height(28) }
          else if (this.state.error) {
            PinmonyActionNotice({message:PinmonyI18n.render(this.state.error,this.uiLanguage),actionText:this.uiText('pm_retry_b8784c8d'),onAction:() => this.onAction('retrySections','',false)})
          } else {
            PinmonyBoardPickerRow({title:this.state.boards.find((board: PinmonyOrganizeBoard) => board.id === this.state.sectionBoardId)?.title || this.uiText('pm_save_to_board_0233a416'),imageUrl:this.state.boards.find((board: PinmonyOrganizeBoard) => board.id === this.state.sectionBoardId)?.imageUrl || '',secret:this.state.boards.find((board: PinmonyOrganizeBoard) => board.id === this.state.sectionBoardId)?.secret === true,actionEnabled:!this.state.busy,onSelect:() => this.onAction('chooseSection','',false)})
            ForEach(this.state.sections || [], (section: PinmonyOrganizeBoard) => {
              PinmonyBoardPickerRow({title:section.title,imageUrl:section.imageUrl,secret:section.secret,indented:true,actionEnabled:!this.state.busy,onSelect:() => this.onAction('chooseSection',section.id,false)})
            }, (section: PinmonyOrganizeBoard) => section.id + ':' + this.uiLanguage)
          }
        }.width('100%').padding({left:20,right:20,top:12,bottom:28})
      }.width('100%').height('100%').align(Alignment.TopStart)
    }.width('100%').height('100%').titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.sectionsScroller])
      .titleBar({avoidLayoutSafeArea:true,enableComponentSafeArea:true,style:{scrollEffectOpts:{enableScrollEffect:false},originalStyle:{backgroundStyle:{backgroundColor:$r('app.color.page_background'),maskExtraHeight:0},contentStyle:{titleStyle:{mainTitleColor:$r('app.color.primary_text')},backIconStyle:{iconColor:$r('app.color.primary_text')}}}},content:{title:{mainTitle:this.uiText('pm_select_section_c87be634')},backIcon:{action:() => this.onAction('back','',false)}}})
      .onBackPressed(() => {this.onAction('back','',false);return true;})
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],[LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  @Builder
  private sectionsPage() {
    HdsNavigation(this.sectionPaths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.sectionsDestination)
  }
  build() {
    if (this.state.phase === 'sections') { this.sectionsPage() }
    else
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
