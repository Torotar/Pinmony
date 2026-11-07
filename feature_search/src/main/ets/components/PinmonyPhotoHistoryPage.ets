import { PinmonyHdsTitleBar } from 'common_ui';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { SmartImage, RECOMMEND_CARD_RADIUS_VP, RECOMMEND_PHONE_GAP_VP } from 'common_ui';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { PinmonyPhotoHistoryItem, PinmonyPhotoHistoryPage, PinmonyPhotoHistoryOrigin } from '../models/PinmonyPhotoHistory';
@Component
export struct PinmonyPhotoHistoryView {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') @Watch('syncSections') private statusBarHeightPx: number = 0;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  @StorageProp('systemDarkMode') private dark: boolean = false;
  @Prop photoLifted: boolean = false;
  @Prop interactionActive: boolean = true;
  @Prop loadingActive: boolean = true;
  @State private items: PinmonyPhotoHistoryItem[] = [];
  @State private selected: string = '';
  @State private busy: boolean = false;
  @State private failed: boolean = false;
  @State private confirming: boolean = false;
  @State private managing: boolean = false;
  @State private managementAnimating: boolean = false;
  @State private historyVisible: boolean = true;
  @State private managementVisible: boolean = false;
  private managementMotionVersion: number = 0;
  @State private deleting: boolean = false;
  @State private pendingIds: string[] = [];
  @State private uncertainIds: string[] = [];
  @State private actionError: string = '';
  @State private widthValue: number = 360;
  private cursor: string = '';
  private ended: boolean = false;
  private alive: boolean = false;
  private readonly scroller: Scroller = new Scroller();
  private readonly managementScroller: Scroller = new Scroller();
  private readonly sections: WaterFlowSections = new WaterFlowSections();
  private columns(): number { return Math.max(2, Math.floor((this.widthValue + RECOMMEND_PHONE_GAP_VP) / 192)); }
  private cardWidth(): number { return Math.max(1, (this.widthValue - (this.columns() - 1) * RECOMMEND_PHONE_GAP_VP) / this.columns()); }
  private cardHeight(item: PinmonyPhotoHistoryItem): number { return this.cardWidth() * item.height / item.width; }
  private syncSections(): void {
    this.sections.splice(0, this.sections.length(), [{ itemsCount: this.visibleItems().length, crossCount: this.columns(), margin:{top:this.titleContentInset() + 16} }]);
  }
  onLoad?: (cursor: string) => Promise<PinmonyPhotoHistoryPage>;
  onConfirm?: (id: string, origin?: PinmonyPhotoHistoryOrigin) => Promise<void>;
  onDelete?: (ids: string[]) => Promise<void>;
  onClose?: () => void;
  onInactiveBack?: () => void;
  private handleSystemBack(): boolean {
    if (!this.interactionActive) { this.onInactiveBack?.(); return true; }
    this.back();
    return true;
  }
  private text(key: string): string { return PinmonyI18n.text(key, this.language); }
  private selectPhoto(id: string): void {
    if (this.managementAnimating || this.confirming || this.busy || this.deleting || this.managing || this.pendingIds.includes(id) || this.uncertainIds.includes(id)) return;
    this.selected = id;
    this.confirm();
  }
  aboutToAppear(): void { this.alive = true; this.load(); }
  aboutToDisappear(): void {
    this.alive = false; this.managementMotionVersion++;
    this.managementAnimating = false; this.historyVisible = !this.managing; this.managementVisible = this.managing;
  }
  private async load(): Promise<void> {
    if (!this.loadingActive || !this.interactionActive || this.managementAnimating || this.busy || this.deleting || this.ended || !this.onLoad) return;
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
    try {
      const item: PinmonyPhotoHistoryItem | undefined = this.items.find((value: PinmonyPhotoHistoryItem): boolean => value.id === this.selected);
      let origin: PinmonyPhotoHistoryOrigin | undefined = undefined;
      if (item) {
        try {
          const ui = this.getUIContext();
          const rect = ui.getComponentUtils().getRectangleById('pinmony-history-photo-' + item.id);
          origin = { x: ui.px2vp(rect.windowOffset.x), y: ui.px2vp(rect.windowOffset.y),
            width: ui.px2vp(rect.size.width), height: ui.px2vp(rect.size.height), imageWidth: item.width, imageHeight: item.height };
        } catch (_) { /* A missing source keeps the existing nonanimated path. */ }
      }
      await this.onConfirm(this.selected, origin);
    }
    catch (_) { if (this.alive) this.failed = true; }
    finally { if (this.alive) this.confirming = false; }
  }
  private visibleItems(): PinmonyPhotoHistoryItem[] {
    return this.items;
  }
  private changeManagement(next: boolean, removedIds: string[] = []): void {
    if (!this.alive || this.managementAnimating || this.managing === next) return;
    const version: number = ++this.managementMotionVersion;
    this.managementAnimating = true;
    this.actionError = '';
    if (removedIds.length > 0) {
      this.items = this.items.filter((item: PinmonyPhotoHistoryItem): boolean => !removedIds.includes(item.id));
      this.pendingIds = []; this.selected = '';
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut, onFinish: () => {
      if (!this.alive || version !== this.managementMotionVersion) return;
      this.historyVisible = !next; this.managementVisible = next;
      this.managementAnimating = false;
    } }, () => {
      this.managing = next;
      if (next) this.managementVisible = true;
      else this.historyVisible = true;
      this.syncSections();
    });
  }

  private enterManagement(): void {
    if (this.busy || this.confirming || this.deleting || this.managementAnimating) return;
    this.changeManagement(true);
  }
  private async back(): Promise<void> {
    if (this.busy || this.confirming || this.deleting || this.managementAnimating) return;
    if (!this.managing) { if (this.onClose) this.onClose(); return; }
    if (this.uncertainIds.length > 0) { this.actionError = 'pm_photo_history_delete_unconfirmed'; return; }
    if (this.pendingIds.length === 0) { this.changeManagement(false); return; }
    if (!this.onDelete) return;
    const ids: string[] = this.pendingIds.slice();
    this.deleting = true; this.actionError = '';
    try {
      await this.onDelete(ids);
      if (!this.alive) return;
      this.changeManagement(false, ids);
    } catch (_) {
      if (this.alive) {
        this.uncertainIds = ids;
        this.actionError = 'pm_photo_history_delete_unconfirmed';
      }
    } finally { if (this.alive) this.deleting = false; }
  }
  private deletePhotos(ids: string[]): void {
    if (this.managementAnimating || !this.managing || !this.onDelete || this.deleting || this.busy || ids.length === 0 ||
      ids.some((id: string): boolean => this.pendingIds.includes(id) || this.uncertainIds.includes(id) ||
        !this.items.some((item: PinmonyPhotoHistoryItem): boolean => item.id === id))) return;
    this.pendingIds = this.pendingIds.concat(ids);
    this.actionError = ''; this.syncSections();
  }
  private restorePhoto(id: string): void {
    if (!this.managing || this.deleting || this.busy || this.uncertainIds.includes(id) || !this.pendingIds.includes(id)) return;
    this.pendingIds = this.pendingIds.filter((value: string): boolean => value !== id);
    this.actionError = ''; this.syncSections();
  }
  private async deleteAllPhotos(): Promise<void> {
    if (this.managementAnimating || !this.onLoad || !this.onDelete || this.busy || this.deleting || this.uncertainIds.length > 0) return;
    this.busy = true; this.actionError = '';
    try {
      // Enumerate all pages before sending the explicit ID list; never delete only the visible batch as "all".
      while (!this.ended && this.items.length < 1000) {
        const page: PinmonyPhotoHistoryPage = await this.onLoad(this.cursor);
        if (!this.alive) return;
        const previous: string = this.cursor;
        this.items = this.items.concat(page.items.filter((item: PinmonyPhotoHistoryItem): boolean => !this.items.some((value: PinmonyPhotoHistoryItem): boolean => value.id === item.id)));
        this.cursor = page.cursor; this.ended = page.ended;
        if (!this.ended && (!this.cursor || this.cursor === previous || page.items.length === 0)) throw new Error('history-incomplete');
      }
      this.syncSections();
      if (!this.ended || this.items.length > 1000) throw new Error('history-incomplete');
    } catch (_) { if (this.alive) this.actionError = 'pm_photo_history_delete_all_incomplete'; return; }
    finally { if (this.alive) this.busy = false; }
    if (!this.alive) return;
    this.deletePhotos(this.items.filter((item: PinmonyPhotoHistoryItem): boolean => !this.pendingIds.includes(item.id)).map((item: PinmonyPhotoHistoryItem): string => item.id));
  }
  private confirmDeleteAll(): void {
    if (this.managementAnimating || this.busy || this.deleting || !this.onDelete || this.uncertainIds.length > 0) return;
    this.getUIContext().showAlertDialog({
      title: this.text('pm_photo_history_delete_all'),
      message: this.text('pm_photo_history_delete_all_confirm'),
      primaryButton: { value: this.text('pm_cancel_2cd0f3be'), action: () => {} },
      secondaryButton: { value: this.text('pm_photo_history_delete_all'), action: () => { this.deleteAllPhotos(); } }
    });
  }
  @Builder
  private historyContent(management: boolean) {
      Stack({alignContent:Alignment.TopStart}) {
        if (this.items.length > 0) {
        WaterFlow({ scroller: management ? this.managementScroller : this.scroller, sections: this.sections }) {
          ForEach(this.items, (item: PinmonyPhotoHistoryItem) => {
            FlowItem() {
              Stack({ alignContent: Alignment.BottomEnd }) {
                SmartImage({ url: item.imageUrl, widthVp: this.cardWidth(), heightVp: this.cardHeight(item),
                  borderRadiusVp: RECOMMEND_CARD_RADIUS_VP })
                  .id('pinmony-history-photo-' + item.id)
                  .blur(this.pendingIds.includes(item.id) ? 18 : 0)
                if (management && this.pendingIds.includes(item.id)) {
                  Column({ space: 4 }) {
                    Text(this.text('pm_photo_history_pending_delete')).fontSize(16).fontColor(Color.White)
                    Button(this.text('pm_undo_926a50b9'), { type: ButtonType.Normal })
                      .height(32).padding(0).backgroundColor(Color.Transparent).fontColor(Color.White)
                      .enabled(!this.deleting && !this.busy && !this.uncertainIds.includes(item.id)).onClick(() => { this.restorePhoto(item.id); })
                  }.width('100%').height('100%').padding(14).alignItems(HorizontalAlign.Start)
                    .backgroundColor('#55000000')
                } else if (management) {
                  Button({ type: ButtonType.Circle }) {
                    SymbolGlyph($r('sys.symbol.trash')).fontSize(18).fontColor([$r('app.color.primary_text')])
                  }.width(32).height(32).margin(8).backgroundColor($r('app.color.input_surface'))
                    .enabled(!!this.onDelete && !this.busy && !this.deleting && !this.uncertainIds.includes(item.id))
                    .accessibilityText(this.text('pm_delete_2f9daa82')).onClick(() => { this.deletePhotos([item.id]); })
                }
              }.width(this.cardWidth()).height(this.cardHeight(item))
                .borderRadius(RECOMMEND_CARD_RADIUS_VP).clip(true)
                .opacity(this.photoLifted && this.selected === item.id ? 0 : 1)
                .border({ width: 2, color: !management && this.selected === item.id ? $r('app.color.primary_text') : Color.Transparent, radius: RECOMMEND_CARD_RADIUS_VP })
                .accessibilityText(this.text('pm_photo_history_select')).accessibilitySelected(this.selected === item.id)
                .onClick(() => this.selectPhoto(item.id))
            }.width(this.cardWidth()).height(this.cardHeight(item))
          }, (item: PinmonyPhotoHistoryItem) => item.id + ':' + this.language )
        }.columnsGap(RECOMMEND_PHONE_GAP_VP).rowsGap(RECOMMEND_PHONE_GAP_VP)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .height('100%').width('100%')
          .scrollBarMargin({start:LengthMetrics.vp(this.titleContentInset() + 16)})
          .onReachEnd(() => { if (!this.failed) this.load(); }).scrollBar(BarState.Off)
          .onAreaChange((_old: Area, area: Area) => {
            const width: number = Number(area.width);
            if (width > 0 && Math.abs(width - this.widthValue) > 1) { this.widthValue = width; this.syncSections(); }
          })
        }
        if (this.actionError) {
          PinmonyActionNotice({ message: this.text(this.actionError) })
        }
        if (this.failed) {
          PinmonyActionNotice({ message: this.text('pm_photo_history_error'), actionText: this.text('pm_retry_b8784c8d'), onAction: () => this.load() })
        } else if (!this.busy && !this.items.length) {
          Column({ space: 8 }) {
            Text(this.text('pm_photo_history_empty')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            Text(this.text('pm_photo_history_empty_hint')).fontSize(15).fontColor($r('app.color.secondary_text')).textAlign(TextAlign.Center)
          }.width('100%').height('100%').padding({top:this.titleContentInset()}).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }
      }.width('100%').height('100%').padding({left:16,right:16})
        .backgroundColor($r('app.color.page_background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .enabled(this.interactionActive && !this.managementAnimating && this.managing === management)
  }
  build() {
    HdsNavDestination() {
      Stack({alignContent:Alignment.Center}) {
      if (this.historyVisible) {
        Stack() { this.historyContent(false) }.width('100%').height('100%')
          .zIndex(this.managing ? 0 : 1)
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut }), TransitionEffect.IDENTITY))
      }
      if (this.managementVisible) {
        Stack() { this.historyContent(true) }.width('100%').height('100%')
          .zIndex(this.managing ? 1 : 0)
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut }), TransitionEffect.IDENTITY))
      }
      if (this.busy || this.confirming || this.deleting) {
        Stack({alignContent:Alignment.Center}) {
          LoadingProgress().color($r('app.color.accent')).width(30).height(30)
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.mode(NavDestinationMode.STANDARD)
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .hideTitleBar(false)
      .systemBarStyle({ statusBarContentColor: this.dark ? '#F7F8FA' : '#1B1E25' }, { statusBarContentColor: this.dark ? '#F7F8FA' : '#1B1E25' })
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
        style: { blurStrategy:this.immersiveLightMode !== 'off' ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,thermoCtrl:this.immersiveLightMode !== 'off',systemMaterialEffect:PinmonyImmersiveLight.effect(this.immersiveLightMode),scrollEffectOpts:{enableScrollEffect:this.immersiveLightMode !== 'off',scrollEffectType:ScrollEffectType.IMMERSIVE_GRADIENT_BLUR},originalStyle:{contentStyle:{titleStyle:{mainTitleColor:$r('app.color.primary_text')},backIconStyle:{iconColor:$r('app.color.primary_text')},menuStyle:{iconColor:$r('app.color.primary_text'),textColor:$r('app.color.primary_text')}},backgroundStyle:{backgroundColor:Color.Transparent,maskExtraHeight:0,blurRadius:this.immersiveLightMode !== 'off' ? 18 : 0}},scrollEffectStyle:{contentStyle:{titleStyle:{mainTitleColor:$r('app.color.primary_text')},backIconStyle:{iconColor:$r('app.color.primary_text')},menuStyle:{iconColor:$r('app.color.primary_text'),textColor:$r('app.color.primary_text')}},backgroundStyle:{backgroundColor:$r('app.color.immersive_title_scrolled'),maskExtraHeight:0,blurRadius:this.immersiveLightMode !== 'off' ? 18 : 0}} },
        content: { title: { mainTitle: this.text(this.managing ? 'pm_photo_history_manage' : 'pm_photo_history') }, backIcon: { action: () => this.back() },
          menu: { value: [{ content: {
            icon: new SymbolGlyphModifier($r('sys.symbol.trash')).fontColor([$r('app.color.primary_text')]),
            label: this.text(this.managing ? 'pm_photo_history_delete_all' : 'pm_photo_history_manage'),
            isEnabled: this.interactionActive && !this.managementAnimating && !this.busy && !this.confirming && !this.deleting &&
              (this.items.length > this.pendingIds.length || this.managing && !this.ended) &&
              !!this.onDelete && this.uncertainIds.length === 0,
            action: () => { if (this.managing) this.confirmDeleteAll(); else this.enterManagement(); }
          } }] }
        } }, this.hdsDarkMode))
      .bindToScrollable([this.managing ? this.managementScroller : this.scroller])
      .onBackPressed(() => this.handleSystemBack())
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .backgroundColor($r('app.color.page_background'))
  }
}
