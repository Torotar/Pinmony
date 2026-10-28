import { vibrator } from '@kit.SensorServiceKit';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonyBoardPlaceholder, PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoard } from '../models/PinmonyProfile';

@Component
export struct PinmonyBoardOrderPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop boards: PinmonyBoard[] = [];
  onDone?: (ids: string[]) => void;
  onBack?: () => void;
  @Prop @Watch('requestBack') backRequest: number = 0;
  private savedOrder: string[] = [];
  private leaveDialogOpen: boolean = false;
  onBusyChanged?: (busy: boolean) => void;
  onMerge?: (source: string, target: string) => Promise<string>;
  @State private dragOffset: number = 0;
  @State private mergeTarget: number = -1;
  @State private insertSlot: number = -1;
  @State private busy: boolean = false;
  @State private blocked: boolean = false;
  @State private error: string = '';
  private alive: boolean = true;
  aboutToDisappear(): void { this.alive = false; }
  @State private ordered: PinmonyBoard[] = [];
  @State private dragging: number = -1;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private dragStartIndex: number = -1;
  private hapticLanding: string = '';
  private hapticAt: number = 0;
  private async vibrateDrag(): Promise<void> {
    try { await vibrator.startVibration({ type: 'time', duration: 12 }, { usage: 'touch' }); }
    catch (_) { /* Touch feedback is optional and must not interrupt dragging. */ }
  }
  private dragFeedback(landing: string): void {
    if (landing === this.hapticLanding || !this.alive) return;
    this.hapticLanding = landing;
    const now: number = Date.now();
    if (now - this.hapticAt < 80) return;
    this.hapticAt = now;
    this.vibrateDrag();
  }
  private text(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  aboutToAppear(): void { this.ordered = this.boards.filter((board: PinmonyBoard): boolean => board.sortable === true); this.savedOrder = this.ordered.map((board: PinmonyBoard): string => board.id); this.paths.pushPath({ name: 'boardOrder' }, false); }
  private hasUnsavedOrder(): boolean {
    return this.savedOrder.join(',') !== this.ordered.map((board: PinmonyBoard): string => board.id).join(',');
  }
  private requestBack(): void {
    if (!this.alive || this.busy || this.leaveDialogOpen) return;
    this.resetDrag();
    if (!this.hasUnsavedOrder()) { this.onBack?.(); return; }
    this.leaveDialogOpen = true;
    this.getUIContext().showAlertDialog({ title: this.text('pm_order_discard_title'), message: this.text('pm_order_discard_message'),
      primaryButton: { value: this.text('pm_cancel_2cd0f3be'), action: () => { this.leaveDialogOpen = false; } },
      secondaryButton: { value: this.text('pm_order_discard_action'), action: () => {
        this.leaveDialogOpen = false;
        if (this.alive && !this.busy) this.onBack?.();
      } }, cancel: () => { this.leaveDialogOpen = false; } });
  }
  private move(_boardId: string, offsetY: number): void {
    if (this.dragging < 0 || this.busy || this.blocked) return;
    this.dragOffset = Math.max((-this.dragStartIndex - 0.5) * 92, Math.min((this.ordered.length - 0.5 - this.dragStartIndex) * 92, offsetY));
    const position: number = this.dragStartIndex + this.dragOffset / 92;
    const nearest: number = Math.round(position);
    this.mergeTarget = nearest !== this.dragStartIndex && Math.abs(position - nearest) < 0.28 &&
      this.ordered[this.dragStartIndex].mergeable === true && this.ordered[nearest]?.mergeable === true ? nearest : -1;
    this.insertSlot = this.mergeTarget >= 0 ? -1 : Math.max(0, Math.min(this.ordered.length, Math.ceil(position)));
    const insertion: number = this.insertSlot > this.dragStartIndex ? this.insertSlot - 1 : this.insertSlot;
    this.dragFeedback(this.mergeTarget >= 0 ? 'merge:' + this.ordered[this.mergeTarget].id : 'slot:' + insertion.toString());
  }
  private resetDrag(): void { this.dragging = -1; this.dragOffset = 0; this.mergeTarget = -1; this.insertSlot = -1; }
  private shift(index: number): number {
    if (this.dragging < 0 || this.mergeTarget >= 0 || this.insertSlot < 0 || index === this.dragging) return 0;
    if (this.insertSlot > this.dragStartIndex && index > this.dragStartIndex && index < this.insertSlot) return -92;
    if (this.insertSlot <= this.dragStartIndex && index >= this.insertSlot && index < this.dragStartIndex) return 92;
    return 0;
  }
  private finishDrag(): void {
    if (this.dragging < 0) return;
    const source: PinmonyBoard = this.ordered[this.dragStartIndex];
    const target: PinmonyBoard | undefined = this.mergeTarget >= 0 ? this.ordered[this.mergeTarget] : undefined;
    const slot: number = this.insertSlot;
    this.resetDrag();
    if (target) { this.confirmMerge(source, target); return; }
    if (slot < 0) return;
    const next: PinmonyBoard[] = this.ordered.slice();
    next.splice(this.dragStartIndex, 1);
    next.splice(slot > this.dragStartIndex ? slot - 1 : slot, 0, source);
    this.ordered = next;
  }
  private confirmMerge(source: PinmonyBoard, target: PinmonyBoard): void {
    this.getUIContext().showAlertDialog({ title: this.text('pm_merge_board_confirm_title'),
      message: this.text('pm_merge_board_confirm_message').replace('{source}', source.title).replace('{target}', target.title),
      primaryButton: { value: this.text('pm_cancel_2cd0f3be'), action: () => {} },
      secondaryButton: { value: this.text('pm_merge_board_confirm_action'), action: () => {
        if (this.alive && !this.busy && !this.blocked && this.ordered.some((b: PinmonyBoard): boolean => b.id === source.id) &&
          this.ordered.some((b: PinmonyBoard): boolean => b.id === target.id)) this.merge(source, target);
      } } });
  }
  private async merge(source: PinmonyBoard, target: PinmonyBoard): Promise<void> {
    if (!this.onMerge) return;
    this.busy = true; this.onBusyChanged?.(true); this.error = '';
    try {
      const result: string = await this.onMerge(source.id, target.id);
      if (!this.alive) return;
      if (result === 'confirmed') { this.savedOrder = this.savedOrder.filter((id: string): boolean => id !== source.id); this.ordered = this.ordered.filter((b: PinmonyBoard): boolean => b.id !== source.id).map((b: PinmonyBoard): PinmonyBoard => this.boards.find((fresh: PinmonyBoard): boolean => fresh.id === b.id) || b); }
      else { this.blocked = result === 'uncertain'; this.error = result === 'uncertain' ? 'pm_unconfirmed_c098e854' : 'pm_profile_sort_save_error'; }
    } catch (_) { if (this.alive) { this.blocked = true; this.error = 'pm_profile_sort_save_error'; } }
    finally { this.onBusyChanged?.(false); if (this.alive) this.busy = false; }
  }
  @Builder
  private destination() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 4 }) {
          if (this.busy) { LoadingProgress().color($r('app.color.accent')).width(32).height(32) }
          if (this.error) { PinmonyActionNotice({ message: this.text(this.error) }) }
          ForEach(this.ordered, (board: PinmonyBoard, index: number) => {
            Row({ space: 14 }) {
              if (board.covers.length) {
                Image(board.covers[0]).width(72).height(72).borderRadius(14).objectFit(ImageFit.Cover)
              } else { Column() { PinmonyBoardPlaceholder() }.width(72).height(72).justifyContent(FlexAlign.Center) }
              Column({ space: 4 }) {
                Text(PinmonyI18n.render(board.title, this.uiLanguage)).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).maxLines(1)
                Text(PinmonyI18n.render(board.pinCount, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text')).maxLines(2)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Row() {
                SymbolGlyph($r('sys.symbol.line_3_horizontal')).fontSize(26).fontColor([$r('app.color.secondary_text')])
              }.width(48).height(72).justifyContent(FlexAlign.Center)
                .enabled(!this.busy && !this.blocked)
                .accessibilityText(PinmonyI18n.render(board.title, this.uiLanguage))
                .gesture(PanGesture({ direction: PanDirection.Vertical }).onActionStart(() => {
                  this.dragStartIndex = this.ordered.findIndex((item: PinmonyBoard): boolean => item.id === board.id);
                  this.dragging = this.dragStartIndex; this.dragOffset = 0; this.insertSlot = this.dragStartIndex;
                  this.hapticLanding = ''; this.hapticAt = 0; this.dragFeedback('slot:' + this.dragStartIndex.toString());
                }).onActionUpdate((event: GestureEvent) => { this.move(board.id, event.offsetY); })
                  .onActionEnd(() => { this.finishDrag(); }).onActionCancel(() => { this.resetDrag(); }))
            }.width('100%').height(88).padding({ left: 20, right: 20, top: 8, bottom: 8 }).backgroundColor(this.dragging === index || this.mergeTarget === index ? $r('app.color.surface_muted') : Color.Transparent)
              .borderRadius(14)
              .border({ width: this.mergeTarget === index ? 2 : 0, color: $r('app.color.primary_text') })
              .zIndex(this.dragging === index ? 2 : 0)
              .translate({ y: this.dragging === index ? this.dragOffset : this.shift(index) })
              .animation({ duration: this.dragging < 0 || this.dragging === index ? 0 : 180, curve: Curve.EaseOut })
          }, (board: PinmonyBoard) => board.id + ':' + this.uiLanguage)
        }.width('100%').padding({ top: 12, bottom: 24 }).justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Auto).enableScrollInteraction(this.dragging < 0)
    }.titleMode(HdsNavDestinationTitleMode.MINI).titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: false },
        originalStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 }, contentStyle: { titleStyle: { mainTitleColor: $r('app.color.primary_text') }, backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text') } } },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 }, contentStyle: { titleStyle: { mainTitleColor: $r('app.color.primary_text') }, backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text') } } } },
      content: { title: { mainTitle: this.text('pm_profile_sort_custom') }, backIcon: { isEnabled: !this.busy, action: () => { this.requestBack(); } }, menu: { value: [{ content: { icon: $r('sys.symbol.checkmark'), label: this.text('pm_done_c0b3fbff'), isEnabled: !this.busy && !this.blocked && this.dragging < 0, action: () => { if (!this.busy && !this.blocked && this.dragging < 0 && this.onDone) this.onDone(this.ordered.map((board: PinmonyBoard): string => board.id.replace(/^profile-api-native-/, ''))); } } }] } } })
      .bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
      .onBackPressed(() => { this.requestBack(); return true; })
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination)
      .backgroundColor($r('app.color.page_background'))
  }
}
