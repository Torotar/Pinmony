import { PinmonyI18n } from 'common_foundation';
import { PinmonyCreatedPin, PinmonyOrganizeSnapshot, PinmonyOrganizeBoard } from '../models/PinmonyProfile';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyBoardPlaceholder, PinmonyLoadingOverlay } from 'common_ui';

@Component
export struct PinmonyOrganizePage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop state: PinmonyOrganizeSnapshot = {} as PinmonyOrganizeSnapshot;
  @Prop pins: PinmonyCreatedPin[] = [];
  @Prop pinsLoading: boolean = false;
  @Prop pinsError: string = '';
  @Prop pinsHasMore: boolean = false;
  @Prop publishing: boolean = false;
  @Prop standaloneBoard: boolean = false;
  @State private name: string = '';
  @State private secret: boolean = false;
  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly contentScroller: Scroller = new Scroller();
  onAction: (action: string, value: string, secret: boolean) => void = () => {};

  aboutToAppear(): void {
    this.pathStack.clear();
    this.pathStack.pushPath({ name: 'pin-web-organize' }, false);
  }

  private blockingLoading(): boolean {
    return this.state.loading || this.state.busy || (this.pinsLoading && this.pins.length === 0);
  }

  private back(): void {
    if (this.state.busy) return;
    this.act(this.standaloneBoard || this.state.uncertain ? 'close' : this.state.phase === 'select' ? 'close' : this.state.phase === 'create' ? 'boards' : 'back');
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        scrollEffectStyle: { contentStyle: {
          backIconStyle: { iconColor: $r('app.color.primary_text') },
          menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
          titleStyle: { mainTitleColor: $r('app.color.primary_text') }
        } },

        originalStyle: { contentStyle: {
          backIconStyle: { iconColor: $r('app.color.primary_text') },
          menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
          titleStyle: { mainTitleColor: $r('app.color.primary_text') }
        }, backgroundStyle: {
          backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0
        } }
      },
      content: {
        title: { mainTitle: this.state.phase === 'select' ? (this.publishing ? this.uiText("pm_select_pins_46854e37") : this.uiText("pm_organize_into_boards_ce266233")) :
          this.state.phase === 'create' ? this.uiText("pm_create_board_513babc9") : this.uiText("pm_save_to_board_0233a416") },
        backIcon: {
          icon: new SymbolGlyphModifier(this.state.phase === 'select' ?
            $r('sys.symbol.xmark') : $r('sys.symbol.chevron_left'))
            .fontColor([$r('app.color.primary_text')]),
          label: this.state.phase === 'select' ? (this.publishing ? this.uiText("pm_close_publisher_06b27c24") : this.uiText("pm_close_organizer_a3fa0809")) : this.uiText("pm_back_572cf45b"),
          isEnabled: !this.state.busy,
          action: () => this.back()
        },
        menu: { value: this.state.phase === 'select' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            .fontColor([$r('app.color.primary_text')]),
          label: this.publishing ? (this.state.selectedIds.length ? this.uiText("pm_done_c0b3fbff") : this.uiText("pm_skip_fc50a99c")) : this.uiText("pm_next_acfc4e74"),
          isEnabled: (this.publishing || this.state.selectedIds.length > 0) && !this.pinsLoading && !this.state.busy && !this.state.uncertain,
          action: () => {
            if ((this.publishing || this.state.selectedIds.length > 0) && !this.pinsLoading && !this.state.busy && !this.state.uncertain) this.act('next');
          }
        } }] : [] }
      }
    };
  }

  private act(action: string, value: string = ''): void {
    this.onAction(action, value, this.secret);
  }

  private selected(pin: PinmonyCreatedPin): boolean { return this.state.selectedIds.includes(pin.id); }

  @State private contentWidth: number = 360;

  private contentColumns(): number {
    return Math.max(3, Math.floor((this.contentWidth - 32 + 12) / 122));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.contentColumns(); i++) slots.push(i);
    return slots;
  }

  private contentColumnsTemplate(): string {
    return this.columnSlots().map((): string => '1fr').join(' ');
  }

  private rows(): number[] {
    const result: number[] = [];
    for (let i: number = 0; i < this.pins.length; i += this.contentColumns()) result.push(i);
    return result;
  }

  @Builder
  private thumb(pin: PinmonyCreatedPin) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image(pin.imageUrl).width('100%').aspectRatio(pin.imageWidth > 0 && pin.imageHeight > 0 ?
        Math.max(0.5, Math.min(1.4, pin.imageWidth / pin.imageHeight)) : 0.7).objectFit(ImageFit.Cover)
      if (this.selected(pin)) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18)
            .fontColor([$r('app.color.detail_on_accent')]).accessibilityLevel('no')
        }.width(30).height(30).backgroundColor($r('app.color.accent')).borderRadius(15).margin(6)
      }
    }
    .borderRadius(12).clip(true)
    .border({ width: this.selected(pin) ? 2 : 0, color: $r('app.color.primary_text') })
    .layoutWeight(1)
    .onClick(() => { if (!this.state.busy && !this.state.loading && !this.state.uncertain) this.act('toggle', pin.id); })
    .accessibilityText(pin.title || this.uiText("pm_select_pins_09909cdf"))
    .accessibilitySelected(this.selected(pin))
  }

  @Builder
  private selection() {
    Column({ space: 16 }) {
      Button(this.state.selectedIds.length === this.pins.length ? this.uiText("pm_deselect_all_f4d4bae5") : this.uiText("pm_select_all_3a5040b6"))
        .height(36).padding(0).fontSize(17).fontWeight(FontWeight.Bold)
        .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
        .enabled(!this.state.busy && !this.state.loading && !this.state.uncertain)
        .onClick(() => this.act('all'))
      ForEach(this.rows(), (start: number) => {
        Row({ space: 12 }) {
          this.thumb(this.pins[start])
          if (start + 1 < this.pins.length) { this.thumb(this.pins[start + 1]) }
          else { Blank().layoutWeight(1) }
          if (start + 2 < this.pins.length) { this.thumb(this.pins[start + 2]) }
          else { Blank().layoutWeight(1) }
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (start: number) => this.contentColumns().toString() + ':' + start.toString())
      if (this.pinsLoading && this.pins.length > 0) { LoadingProgress().width(28).height(28) }
      else if (this.pinsError) {
        Text(PinmonyI18n.render(this.pinsError, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
        Button(this.uiText("pm_retry_b8784c8d")).onClick(() => this.act('retryPins'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private boardRow(board: PinmonyOrganizeBoard) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        if (board.imageUrl) {
          Image(board.imageUrl).width(56).height(56).objectFit(ImageFit.Cover).borderRadius(16)
        } else {
          PinmonyBoardPlaceholder()
        }
        Text(board.title).fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text')).layoutWeight(1).maxLines(2)
        if (board.secret) {
          SymbolGlyph($r('sys.symbol.lock')).fontSize(18).fontColor([$r('app.color.secondary_text')])
        }
      }.width('100%')
    }.width('100%').constraintSize({ minHeight: 72 }).padding(0)
    .backgroundColor(Color.Transparent).borderRadius(12)
    .enabled(board.enabled && !this.state.busy && !this.state.uncertain && !this.state.loading)
    .opacity(board.enabled ? 1 : 0.4)
    .onClick(() => this.act('move', board.id))
    .accessibilityText(board.title + (board.secret ? this.uiText("pm_secret_board_a61a7ae3") : ''))
  }

  @Builder
  private boardList() {
    Column({ space: 8 }) {
      if (!this.state.loading || this.state.boards.length > 0) {
        Text(this.uiText("pm_all_boards_f1847589")).fontSize(17).fontColor($r('app.color.primary_text')).width('100%')
      }
      ForEach(this.state.boards, (board: PinmonyOrganizeBoard) => { this.boardRow(board) },
        (board: PinmonyOrganizeBoard) => board.id)
      if (!this.state.loading && this.state.error && !this.state.uncertain) {
        Button(this.uiText("pm_reload_boards_c3e7cfa5")).enabled(!this.state.busy).onClick(() => this.act('retryBoards'))
      } else if (!this.state.loading && !this.state.boards.length && !this.state.error) {
        Text(this.uiText("pm_no_boards_yet_43790af9")).fontColor($r('app.color.secondary_text'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private createForm() {
    Column({ space: 20 }) {
      TextInput({ placeholder: this.uiText("pm_board_name_dd9a7122"), text: this.name }).maxLength(100)
        .onChange((value: string) => { this.name = value; })
      Row({ space: 14 }) {
        Text(this.uiText("pm_make_secret_228cf25e")).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.secret }).enabled(!this.state.busy)
          .onChange((value: boolean) => { this.secret = value; })
      }.width('100%')
      Button(this.uiText("pm_create_board_513babc9")).width('100%').height(48).backgroundColor($r('app.color.accent')).fontColor($r('app.color.detail_on_accent'))
        .enabled(!!this.name.trim() && !this.state.busy && !this.state.uncertain)
        .onClick(() => this.act('create', this.name.trim()))
    }.width('100%')
  }

  @Builder
  private organizeContent() {
    Column() {
      if (this.state.selectedIds.length && this.state.phase !== 'create') {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.pins.filter((pin: PinmonyCreatedPin): boolean => this.selected(pin)), (pin: PinmonyCreatedPin) => {
              Image(pin.imageUrl).width(42).height(58).objectFit(ImageFit.Cover).borderRadius(8)
            }, (pin: PinmonyCreatedPin) => pin.id)
          }.padding(12)
        }.scrollable(ScrollDirection.Horizontal).width('100%').height(82).scrollBar(BarState.Off)
          .align(Alignment.TopStart)
      }
      if (this.state.phase === 'boards') {
        Divider().color($r('app.color.secondary_text')).opacity(0.15).margin({ left: 16, right: 16 })
      }
      if (this.state.error || this.state.feedback) {
        Text(PinmonyI18n.render(this.state.error || this.state.feedback, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text')).padding(12)
      }
      Scroll(this.contentScroller) {
        Column() {
          if (this.state.phase === 'select') { this.selection() }
          else if (this.state.phase === 'create') { this.createForm() }
          else { this.boardList() }
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
      .onReachEnd(() => {
        if (this.state.busy || this.state.uncertain) return;
        if (this.state.phase === 'select' && this.pinsHasMore && !this.pinsLoading && !this.pinsError) {
          this.act('morePins');
        } else if (this.state.phase === 'boards' && this.state.hasMore && !this.state.loading && !this.state.error) {
          this.act('moreBoards');
        }
      })
      if (this.state.phase === 'boards') {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Text('+').fontSize(26).width(44).height(44).textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(10)
              .fontColor($r('app.color.primary_text'))
            Text(this.uiText("pm_create_board_513babc9")).fontSize(19).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1)
          }.width('100%')
        }.width('calc(100% + 24vp)').height(76).margin({ left: -12, right: -12 }).padding({ left: 16, right: 16, top: 12, bottom: 20 }).borderRadius(0)
          .backgroundColor($r('app.color.page_background'))
          .enabled(!this.state.busy && !this.state.uncertain && !this.state.loading)
          .onClick(() => this.act('createForm'))
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private organizeDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      this.organizeContent()
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.contentScroller])
    .onBackPressed(() => { this.back(); return true; })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      HdsNavigation(this.pathStack) {
        Column().width('100%').height('100%')
      }
      .width('100%').height('100%')
      .hideTitleBar(true)
      .navDestination(this.organizeDestination)
      .backgroundColor($r('app.color.page_background'))
      .accessibilityLevel(this.blockingLoading() ? 'no-hide-descendants' : 'auto')
      if (this.blockingLoading()) {
        PinmonyLoadingOverlay({ message: this.state.busy ? this.uiText("pm_submitting_please_wait_e7f123ba") :
          this.state.phase === 'boards' ? this.uiText("pm_loading_saved_boards_4262c72d") : this.uiText("pm_loading_please_wait_b6aaac70") })
      }
    }.width('100%').height('100%')
  }
}
