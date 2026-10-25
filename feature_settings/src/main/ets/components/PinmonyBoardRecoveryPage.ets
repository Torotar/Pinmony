import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardPlaceholder } from 'common_ui';
import { PinmonySettingsStore, PinmonyRecoverableBoard } from '../stores/PinmonySettingsStore';

@Component
export struct PinmonyBoardRecoveryPage {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  @ObjectLink store: PinmonySettingsStore;
  @Prop panelMode: boolean = false;
  @State private selected: string = '';
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private text(key: string): string { return PinmonyI18n.text(key,this.language); }
  aboutToAppear(): void { if (!this.panelMode) this.paths.pushPath({name:'boardRecovery'},false); }
  private canRestore(): boolean {
    return this.store.boardRecoveryReady && !this.store.loading && !this.store.busy && !this.store.writeUncertain && !this.store.error &&
      this.store.recoverableBoards.some((b: PinmonyRecoverableBoard): boolean => b.id === this.selected && !b.restored);
  }
  private options(): HdsNavigationTitleBarOptions {
    return {avoidLayoutSafeArea:true,enableComponentSafeArea:true,
      style:{scrollEffectOpts:{enableScrollEffect:false},
        originalStyle:{backgroundStyle:{backgroundColor:$r('app.color.page_background'),maskExtraHeight:0},
          contentStyle:{backIconStyle:{iconColor:$r('app.color.primary_text')},titleStyle:{mainTitleColor:$r('app.color.primary_text')},menuStyle:{iconColor:$r('app.color.primary_text'),textColor:$r('app.color.primary_text')}}},
        scrollEffectStyle:{backgroundStyle:{backgroundColor:$r('app.color.page_background'),maskExtraHeight:0},
          contentStyle:{backIconStyle:{iconColor:$r('app.color.primary_text')},titleStyle:{mainTitleColor:$r('app.color.primary_text')},menuStyle:{iconColor:$r('app.color.primary_text'),textColor:$r('app.color.primary_text')}}}},
      content:{title:{mainTitle:this.text('pm_board_recovery_title')},backIcon:{isEnabled:!this.store.busy,action:() => this.onBack?.()},
        menu:{value:[{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label:this.text('pm_board_recovery_submit'),isEnabled:this.canRestore(),action:() => {if(this.canRestore())this.onRequest?.('boardRecoveryRestore',this.selected);}}}]}}};
  }
  @Builder
  private boardRow(board: PinmonyRecoverableBoard) {
    Button({type:ButtonType.Normal}) {
      Row({space:12}) {
        SymbolGlyph(this.selected === board.id && !board.restored ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
          .fontSize(24).fontColor([this.selected === board.id && !board.restored ? $r('app.color.detail_accent') : $r('app.color.secondary_text')])
        if(board.imageUrl) { Image(board.imageUrl).width(56).height(56).objectFit(ImageFit.Cover).borderRadius(12) }
        else { PinmonyBoardPlaceholder() }
        Column({space:6}) {
          Text(board.name + (board.restored ? ' ' + this.text('pm_board_recovery_restored') : '')).fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text')).maxLines(2).width('100%')
          Text(this.text('pm_board_recovery_counts').replace('{pins}',board.pinCount.toString()).replace('{sections}',board.sectionCount.toString()))
            .fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
    }.width('100%').padding({top:12,bottom:12}).backgroundColor(Color.Transparent)
      .enabled(!board.restored && !this.store.busy && !this.store.loading && !this.store.writeUncertain)
      .opacity(board.restored ? 0.5 : 1).onClick(() => { this.selected = this.selected === board.id ? '' : board.id; })
      .accessibilityText(board.name + ' ' + this.text(board.restored ? 'pm_board_recovery_restored' : this.selected === board.id ? 'pm_board_recovery_selected' : 'pm_board_recovery_select'))
  }
  @Builder
  private recoveryContent() {
      Scroll(this.scroller) {
        Column({space:16}) {
          Text(this.text('pm_board_recovery_description')).fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
          if(this.store.error) {
            Text(PinmonyI18n.render(this.store.error,this.language)).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
            Button(this.text('pm_retry_b8784c8d')).enabled(!this.store.busy && !this.store.loading)
              .onClick(() => {this.selected = '';this.onRequest?.('boardRecoveryRead','');})
          }
          if(this.store.loading || this.store.busy) { LoadingProgress().width(32).height(32) }
          if(this.store.boardRecoveryReady) {
            if (this.store.recoverableBoards.length > 0) {
              Text(this.text('pm_board_recovery_total').replace('{count}',this.store.recoverableBoards.length.toString()))
                .fontSize(17).fontColor($r('app.color.primary_text')).width('100%')
            }
            ForEach(this.store.recoverableBoards,(board:PinmonyRecoverableBoard) => {this.boardRow(board)},
              (board:PinmonyRecoverableBoard) => board.id + ':' + board.restored.toString() + ':' + this.language)
            if(!this.store.recoverableBoards.length && !this.store.error && !this.store.loading) {
              Column() {
                Text(this.text('pm_board_recovery_empty')).fontSize(15).fontColor($r('app.color.secondary_text'))
              }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            }
          }
        }.width('100%').padding({left:20,right:20,top:16,bottom:32}).alignItems(HorizontalAlign.Start)
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
  }
  @Builder
  private destination() {
    HdsNavDestination() {
      this.recoveryContent()
    }.titleBar(this.options()).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .onBackPressed(() => {if(!this.store.busy)this.onBack?.();return true;})
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],[LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (this.panelMode) {
      Column() {
        Text(this.text('pm_board_recovery_title')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .width('100%').padding({left:24,right:64,top:16,bottom:16})
        this.recoveryContent()
        Button(this.text('pm_board_recovery_submit'), { type: ButtonType.Normal })
          .width('90%').height(48).borderRadius(16).enabled(this.canRestore())
          .onClick(() => {if(this.canRestore())this.onRequest?.('boardRecoveryRestore',this.selected);}).margin({top:8,bottom:20})
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    } else {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
    }
  }
}
