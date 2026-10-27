import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { SmartImage, RECOMMEND_CARD_RADIUS_VP, RECOMMEND_PHONE_GAP_VP } from 'common_ui';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonyPhotoHistoryItem, PinmonyPhotoHistoryPage } from '../models/PinmonyPhotoHistory';
@Component
export struct PinmonyPhotoHistoryView {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  @StorageProp('systemDarkMode') private dark: boolean = false;
  @State private items: PinmonyPhotoHistoryItem[] = [];
  @State private selected: string = '';
  @State private busy: boolean = false;
  @State private failed: boolean = false;
  @State private confirming: boolean = false;
  @State private widthValue: number = 360;
  private cursor: string = '';
  private ended: boolean = false;
  private alive: boolean = false;
  private readonly scroller: Scroller = new Scroller();
  private readonly sections: WaterFlowSections = new WaterFlowSections();
  private columns(): number { return Math.max(2, Math.floor((this.widthValue + RECOMMEND_PHONE_GAP_VP) / 192)); }
  private cardWidth(): number { return Math.max(1, (this.widthValue - (this.columns() - 1) * RECOMMEND_PHONE_GAP_VP) / this.columns()); }
  private cardHeight(item: PinmonyPhotoHistoryItem): number { return this.cardWidth() * item.height / item.width; }
  private syncSections(): void {
    this.sections.splice(0, this.sections.length(), [{ itemsCount: this.items.length, crossCount: this.columns() }]);
  }
  onLoad?: (cursor: string) => Promise<PinmonyPhotoHistoryPage>;
  onConfirm?: (id: string) => Promise<void>;
  onClose?: () => void;
  private text(key: string): string { return PinmonyI18n.text(key, this.language); }
  private selectPhoto(id: string): void {
    if (this.confirming) return;
    if (this.selected === id) { this.selected = ''; return; }
    if (this.selected) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: this.text('pm_photo_history_single_only') });
      } catch (_) {
        // The page may already be leaving while the selection callback runs.
      }
      return;
    }
    this.selected = id;
  }
  aboutToAppear(): void { this.alive = true; this.load(); }
  aboutToDisappear(): void { this.alive = false; }
  private async load(): Promise<void> {
    if (this.busy || this.ended || !this.onLoad) return;
    this.busy = true; this.failed = false;
    try {
      const page: PinmonyPhotoHistoryPage = await this.onLoad(this.cursor);
      if (!this.alive) return;
      this.items = this.items.concat(page.items.filter((p: PinmonyPhotoHistoryItem): boolean => !this.items.some((v: PinmonyPhotoHistoryItem): boolean => v.id === p.id)));
      this.syncSections();
      this.cursor = page.cursor; this.ended = page.ended || this.items.length >= 1000;
    } catch (_) { if (this.alive) this.failed = true; }
    finally { if (this.alive) this.busy = false; }
  }
  private async confirm(): Promise<void> {
    if (!this.selected || this.busy || this.confirming || !this.onConfirm) return;
    this.confirming = true; this.failed = false;
    try { await this.onConfirm(this.selected); }
    catch (_) { if (this.alive) this.failed = true; }
    finally { if (this.alive) this.confirming = false; }
  }
  private deleteLoadedHistory(): void {
    if (this.busy || this.confirming || !this.items.length) return;
    this.getUIContext().showAlertDialog({
      title: this.text('pm_delete_search_history_80b537e5'),
      message: this.text('pm_this_cannot_be_undone_55d5e34b'),
      primaryButton: { value: this.text('pm_cancel_2cd0f3be'), action: () => {} },
      secondaryButton: { value: this.text('pm_delete_search_history_80b537e5'), action: () => {
        this.items = []; this.selected = ''; this.cursor = ''; this.ended = true; this.syncSections();
      } }
    });
  }
  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        Row() {
          Blank().layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([$r('app.color.primary_text')])
          }.width(44).height(44).backgroundColor($r('app.color.input_surface'))
            .enabled(!this.busy && !this.confirming && this.items.length > 0)
            .accessibilityText(this.text('pm_delete_search_history_80b537e5'))
            .onClick(() => this.deleteLoadedHistory())
        }.width('100%').height(44)
        if (this.items.length > 0) {
        WaterFlow({ scroller: this.scroller, sections: this.sections }) {
          ForEach(this.items, (item: PinmonyPhotoHistoryItem) => {
            FlowItem() {
              Stack({ alignContent: Alignment.TopEnd }) {
                SmartImage({ url: item.imageUrl, widthVp: this.cardWidth(), heightVp: this.cardHeight(item),
                  borderRadiusVp: RECOMMEND_CARD_RADIUS_VP })
                if (this.selected === item.id) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(28).fontColor([$r('app.color.accent')])
                    .backgroundColor($r('app.color.page_background')).borderRadius(20).margin(8)
                }
              }.width(this.cardWidth()).height(this.cardHeight(item))
                .border({ width: 2, color: this.selected === item.id ? $r('app.color.primary_text') : Color.Transparent, radius: RECOMMEND_CARD_RADIUS_VP })
                .accessibilityText(this.text('pm_photo_history_select')).accessibilitySelected(this.selected === item.id)
                .onClick(() => this.selectPhoto(item.id))
            }.width(this.cardWidth()).height(this.cardHeight(item))
          }, (item: PinmonyPhotoHistoryItem) => item.id + ':' + this.language)
        }.columnsGap(RECOMMEND_PHONE_GAP_VP).rowsGap(RECOMMEND_PHONE_GAP_VP)
          .layoutWeight(1).width('100%')
          .onReachEnd(() => { if (!this.failed) this.load(); }).scrollBar(BarState.Off)
          .onAreaChange((_old: Area, area: Area) => {
            const width: number = Number(area.width);
            if (width > 0 && Math.abs(width - this.widthValue) > 1) { this.widthValue = width; this.syncSections(); }
          })
        }
        if (this.busy || this.confirming) { LoadingProgress().width(30).height(30) }
        if (this.failed) {
          PinmonyActionNotice({ message: this.text('pm_photo_history_error'), actionText: this.text('pm_retry_b8784c8d'), onAction: () => this.load() })
        } else if (!this.busy && !this.items.length) {
          Column({ space: 8 }) {
            Text(this.text('pm_photo_history_empty')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            Text(this.text('pm_photo_history_empty_hint')).fontSize(15).fontColor($r('app.color.secondary_text')).textAlign(TextAlign.Center)
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }
      }.width('100%').height('100%').padding(16)
    }.titleMode(HdsNavDestinationTitleMode.MINI)
      .systemBarStyle({ statusBarContentColor: this.dark ? '#F7F8FA' : '#1B1E25' }, { statusBarContentColor: this.dark ? '#F7F8FA' : '#1B1E25' })
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
        content: { title: { mainTitle: this.text('pm_photo_history') }, backIcon: { action: () => { if (this.onClose) this.onClose(); } },
          menu: { value: [{ content: { icon: $r('sys.symbol.checkmark'), label: this.text('pm_photo_history_confirm'),
            isEnabled: !!this.selected && !this.busy && !this.confirming, action: () => { this.confirm(); } } }] } } })
      .bindToScrollable([this.scroller])
      .onBackPressed(() => { if (this.onClose) this.onClose(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor($r('app.color.page_background'))
  }
}
