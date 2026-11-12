import { PinmonyHdsTitleBar, PinmonyImmersiveLight } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyBoardPickerRow, PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyCreatedPin, PinmonyOrganizeSnapshot, PinmonyOrganizeBoard } from '../models/PinmonyProfile';
import { PinmonyOrganizePage } from './PinmonyOrganizePage';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';

// Publish owns this entry point so its board flow can evolve independently
// from the profile's ordinary "整理到图板" flow.
@Component
export struct PinmonyPublishBoardPage {
  @StorageProp('pinmonySheetWindowWidthVp') private sheetWindowWidthVp: number = 0;
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('syncCreate') state: PinmonyPublishFlow = {} as PinmonyPublishFlow;
  @State private createVisible: boolean = false;
  @State private createClosing: boolean = false;
  private createCloseToken: number = -1;
  private createClosePage: string = '';
  private createCloseDispatched: boolean = false;
  @State private name: string = '';
  @State private secret: boolean = false;
  private readonly sectionPaths: NavPathStack = new NavPathStack();
  private readonly sectionsScroller: Scroller = new Scroller();
  private readonly createScroller: Scroller = new Scroller();
  @Prop pins: PinmonyCreatedPin[] = [];
  @Prop pinsLoading: boolean = false;
  onAction: (action: string, value: string, secret: boolean) => void = () => {};

  aboutToAppear(): void { this.syncCreate(); }
  private syncCreate(): void {
    if (this.createClosing && (this.createCloseToken !== this.state.token || this.createClosePage !== this.state.page || this.state.phase !== 'create')) {
      this.createClosing = false; this.createCloseDispatched = false;
    }
    this.createVisible = !this.createClosing && this.state.phase === 'create';
    if (this.state.phase === 'sections' && !this.sectionPaths.size()) this.sectionPaths.pushPath({name:'sections'});
  }
  private requestCreateClose(): void {
    if (this.state.busy || this.createClosing || this.state.phase !== 'create') return;
    this.createCloseToken = this.state.token;
    this.createClosePage = this.state.page;
    this.createCloseDispatched = false;
    this.createClosing = true;
    this.createVisible = false;
  }
  private finishCreateClose(): void {
    if (this.createVisible || !this.createClosing || this.createCloseDispatched) return;
    const current: boolean = this.createCloseToken === this.state.token && this.createClosePage === this.state.page && this.state.phase === 'create';
    if (current && !this.state.busy) { this.createCloseDispatched = true; this.closeCreate(); }
  }
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
      if (this.state.loading || this.state.busy) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }

  @Builder
  private createButton() {
      Button(this.uiText("pm_create_board_513babc9")).width('100%').height(48).backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.detail_on_accent'))
        .enabled(!!this.name.trim() && !this.state.loading && !this.state.busy && !this.state.uncertain && !this.createClosing)
        .onClick(() => this.onAction('create', this.name.trim(), this.secret))
  }
  @Builder
  private createSheet() {
    HdsNavigation() {
      Column() {
        Scroll(this.createScroller) { this.createForm() }
          .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
          .scrollBarMargin({start:LengthMetrics.vp(0)})
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        Column() { this.createButton() }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }.width('100%').height('100%')
    }.mode(NavigationMode.Stack).width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MODAL).bindToScrollable([this.createScroller])
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), { avoidLayoutSafeArea: false, enableComponentSafeArea: true,
        style: PinmonyHdsTitleBar.modalStyle(this.immersiveLightMode),
        content: { title: { mainTitle: this.uiText("pm_create_board_513babc9") }, menu: { value: [{ content: {
          type: IconStyleMode.SMALL, label: this.uiText("pm_close_3fd47edc"), isEnabled: !this.state.busy,
          action: () => this.requestCreateClose()
        } }] } } }, this.hdsDarkMode))
      .backgroundColor($r('app.color.page_background')).enabled(!this.createClosing)
  }

  @Builder
  private sectionsDestination() {
    HdsNavDestination() {
      Scroll(this.sectionsScroller) {
        Column({space:8}) {
          if (this.state.loading) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
          else if (this.state.error) {
            PinmonyActionNotice({message:PinmonyI18n.render(this.state.error,this.uiLanguage),actionText:this.uiText('pm_retry_b8784c8d'),onAction:() => this.onAction('retrySections','',false)})
          } else {
            PinmonyBoardPickerRow({title:this.state.boards.find((board: PinmonyOrganizeBoard) => board.id === this.state.sectionBoardId)?.title || this.uiText('pm_save_to_board_0233a416'),imageUrl:this.state.boards.find((board: PinmonyOrganizeBoard) => board.id === this.state.sectionBoardId)?.imageUrl || '',secret:this.state.boards.find((board: PinmonyOrganizeBoard) => board.id === this.state.sectionBoardId)?.secret === true,actionEnabled:!this.state.busy,onSelect:() => this.onAction('chooseSection','',false)})
            ForEach(this.state.sections || [], (section: PinmonyOrganizeBoard) => {
              PinmonyBoardPickerRow({title:section.title,imageUrl:section.imageUrl,secret:section.secret,indented:true,actionEnabled:!this.state.busy,onSelect:() => this.onAction('chooseSection',section.id,false)})
            }, (section: PinmonyOrganizeBoard) => section.id + ':' + this.uiLanguage)
          }
        }.width('100%').padding({left:20,right:20,top:this.titleContentInset() + 12,bottom:28})
      }.width('100%').height('100%').align(Alignment.TopStart)
        .scrollBarMargin({start:LengthMetrics.vp(this.titleContentInset())})
    }.width('100%').height('100%').titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.sectionsScroller])
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), {avoidLayoutSafeArea:true,enableComponentSafeArea:false,style:{blurStrategy:(this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,thermoCtrl:(this.immersiveLightMode !== 'off'),systemMaterialEffect:PinmonyImmersiveLight.effect(this.immersiveLightMode),scrollEffectOpts:{enableScrollEffect:(this.immersiveLightMode !== 'off'),scrollEffectType:ScrollEffectType.IMMERSIVE_GRADIENT_BLUR},scrollEffectStyle:{backgroundStyle:{backgroundColor:$r('app.color.immersive_title_scrolled'),maskExtraHeight:0,blurRadius:(this.immersiveLightMode !== 'off') ? 18 : 0},contentStyle:{titleStyle:{mainTitleColor:$r('app.color.primary_text')},backIconStyle:{iconColor:$r('app.color.primary_text')}}},originalStyle:{backgroundStyle:{backgroundColor:Color.Transparent,maskExtraHeight:0,blurRadius:(this.immersiveLightMode !== 'off') ? 18 : 0},contentStyle:{titleStyle:{mainTitleColor:$r('app.color.primary_text')},backIconStyle:{iconColor:$r('app.color.primary_text')}}}},content:{title:{mainTitle:this.uiText('pm_select_section_c87be634')},backIcon:{action:() => this.onAction('back','',false)}}}, this.hdsDarkMode))
      .onBackPressed(() => {this.onAction('back','',false);return true;})
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],[LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  @Builder
  private sectionsPage() {
    HdsNavigation(this.sectionPaths) { Column().width('100%').height('100%') }.mode(NavigationMode.Stack)
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.sectionsDestination)
  }
  build() {
    if (this.state.phase === 'sections') { this.sectionsPage() }
    else
    if (this.state.phase === 'create') {
      Column().width('100%').height('100%').backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.None)
        .bindSheet($$this.createVisible, this.createSheet(), PinmonyImmersiveLight.sheetOptions({
      radius: LengthMetrics.vp(32),
      preferType: this.sheetWindowWidthVp >= 600 ? SheetType.CENTER : undefined,
          onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyPublishBoardPage.createVisible radius=uniform-32vp'); },
          height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM], dragBar: true, showClose: false,
          backgroundColor: $r('app.color.page_background'),
          onWillSpringBackWhenDismiss: (action: SpringBackAction): void => { if (this.state.busy) action.springBack(); },
          onDisappear: (): void => this.finishCreateClose(),
          onWillDismiss: (action: DismissSheetAction) => {
            if (this.state.busy) return;
            this.requestCreateClose(); action.dismiss();
          }
        }, this.immersiveLightMode, false))
    } else {
      PinmonyOrganizePage({ state: this.state, pins: this.pins, pinsLoading: this.pinsLoading,
        publishing: true, standaloneBoard: false, onAction: this.onAction })
    }
  }
}
