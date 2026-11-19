import { PinmonyDetailSources, PinmonyDetailSourceCard } from '../services/PinmonyDetailSource';
import { PinmonyModalNavigation } from './PinmonyModalNavigation';
import { PinmonyBackToTopButton } from './PinmonyBackToTopButton';
import { PinmonyImmersiveLight } from '../services/PinmonyImmersiveLight';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from './PinmonyActionNotice';
import { PinmonyImageSearchSelection } from './PinmonyImageSearchSelection';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyImageCrop, PinmonyVisualResult, PinmonyRelatedPin, PinmonyImageSearchOrigin } from '../models/PinmonyImageSearch';


@Component
export struct PinmonyImageSearchView {
  @StorageProp('pinmonySheetWindowWidthVp') private sheetWindowWidthVp: number = 0;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop pin: string = '';
  @Prop imageUrl: string = '';
  @Prop imageWidth: number = 1;
  @Prop imageHeight: number = 1;
  @Prop uploadedPhoto: boolean = false;
  @Prop @Watch('presentationChanged') presentationActive: boolean = true;
  private relatedOpening: boolean = false;
  private resumeRelatedSheet: boolean = false;
  @State private sheetAppearing: boolean = false;
  private resultScrollOffset: number = 0;
  @State private backToTopVisible: boolean = false;
  @State private backToTopOffset: number = 0;
  @StorageProp('gestureBarHeightPx') private gestureBarHeightPx: number = 0;

  private canBackToTop(): boolean {
    return this.alive && this.presentationActive && this.sheetVisible && !this.closing &&
      !this.relatedOpening && !this.sheetAppearing && !this.closeRequested;
  }

  private backToTop(): void {
    if (!this.canBackToTop()) return;
    this.resultScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  private reportResultsPosition(): void {
    if (!this.canBackToTop()) return;
    try {
      this.resultScrollOffset = Math.max(0, this.resultScroller.offset()?.yOffset || 0);
      this.backToTopOffset = this.resultScrollOffset; this.backToTopVisible = this.backToTopOffset > 0;
    } catch (_) { this.backToTopVisible = false; }
  }

  private sourceLifetime: number = 0;
  private sourceReturnPin: string = '';
  private sourceReturnAttempts: number = 0;
  private sourceIdentity(): string { return this.pin + ':' + this.imageUrl + ':' + this.crop.x + ':' + this.crop.y + ':' + this.crop.w + ':' + this.crop.h; }
  private sourceCardId(pin: PinmonyRelatedPin): string {
    return (this.uploadedPhoto ? 'pinmony-photo-result-' : 'pinmony-visual-result-' + this.pin + '-') + pin.id;
  }
  private stageDetailSource(): void {
    const identity: string = this.sourceIdentity();
    const lifetime: number = this.sourceLifetime;
    PinmonyDetailSources.stage({ identity: 'image-search:' + identity, pageUrl: this.pin, session: lifetime, pageOnly: true,
      cards: (): PinmonyDetailSourceCard[] => lifetime === this.sourceLifetime && identity === this.sourceIdentity() ?
        this.result.items.filter((item: PinmonyRelatedPin): boolean => item.pinUrl !== this.pin).map((item: PinmonyRelatedPin): PinmonyDetailSourceCard => ({ pinUrl: item.pinUrl,
          cardId: this.sourceCardId(item), entryCardId: 'pinmony-photo-result-' + item.id,
          imageUrl: item.imageUrl, imageWidth: item.imageWidth, imageHeight: item.imageHeight })) : [],
      locate: (card: PinmonyDetailSourceCard): void => {
        this.sourceReturnPin = card.pinUrl; this.sourceReturnAttempts = 0;
        this.restoreSourceCard();
      } });
  }
  private restoreSourceCard(): void {
    if (!this.sourceReturnPin || !this.alive || !this.presentationActive || !this.sheetVisible || !this.resultSheetMounted) return;
    const pin: PinmonyRelatedPin | undefined = this.result.items.find((item: PinmonyRelatedPin): boolean => item.pinUrl === this.sourceReturnPin);
    if (!pin) { this.sourceReturnPin = ''; return; }
    try {
      const ui = this.getUIContext();
      const rect = ui.getComponentUtils().getRectangleById(this.sourceCardId(pin));
      const host = ui.getComponentUtils().getRectangleById('pinmony-image-result-scroll-' + this.pin + '-' + this.uploadedPhoto);
      if (rect.size.width <= 0 || host.size.height <= 0) {
        if (++this.sourceReturnAttempts < 12) this.initial = setTimeout((): void => this.restoreSourceCard(), 16);
        return;
      }
      const target: number = Math.max(0, this.resultScroller.currentOffset().yOffset + ui.px2vp(rect.windowOffset.y - host.windowOffset.y) - 16);
      this.resultScrollOffset = target;
      this.resultScroller.scrollTo({ xOffset: 0, yOffset: target, animation: false });
      this.sourceReturnPin = '';
    } catch (_) {
      if (++this.sourceReturnAttempts < 12) this.initial = setTimeout((): void => this.restoreSourceCard(), 16);
    }
  }

  private openRelated(pin: PinmonyRelatedPin): void {
    if (!this.alive || this.presentationActive === false || this.relatedOpening || this.result.loading || pin.pinUrl === this.pin) return;
    this.stageDetailSource();
    this.relatedOpening = true;
    try { this.resultScrollOffset = Math.max(0, this.resultScroller.offset()?.yOffset || 0); } catch (_) {}
    this.sheetVisible = false;
    PinmonyRuntimeLog.info('PhotoResultMotion: event=open-request immediate=true');
    if (this.onRelated?.(pin.id) === false) {
      this.relatedOpening = false;
      this.sheetVisible = true;
    }
  }
  private resultSheetAppeared(): void {
    this.restoreSourceCard();
    if (this.presentationActive && !this.closing && this.sheetVisible) {
      try { this.resultScroller.scrollTo({ xOffset: 0, yOffset: this.resultScrollOffset, animation: false }); } catch (_) {}
    }
    this.sheetAppearing = false;
    if (this.presentationActive && !this.closing && this.sheetVisible) {
      this.relatedOpening = false;
      this.resumeRelatedSheet = false;
    }
    this.reportResultsPosition();
    PinmonyRuntimeLog.info('PhotoSheetTrace: event=appeared detent=' + (this.sheetHeight === SheetSize.LARGE ? 'large' : 'default'));
  }
  private updateSheetDetent(height: number): void {
    if (this.sheetAppearing || this.relatedOpening || this.presentationActive === false || this.closing || !this.sheetVisible) return;
    this.sheetHeight = this.getUIContext().px2vp(height) > this.heightValue * 0.7 ? SheetSize.LARGE : '40%';
  }
  private presentationChanged(): void {
    if (!this.alive) return;
    if (this.presentationActive && !this.closing) {
      this.sheetAppearing = true;
      if (this.relatedOpening && this.resultSheetMounted) {
        this.resumeRelatedSheet = true;
        return;
      }
      this.relatedOpening = false;
      this.sheetVisible = true;
    } else {

      this.resumeRelatedSheet = false;
      clearTimeout(this.debounce);
      this.sheetVisible = false;
    }
  }
  @Prop animatePhoto: boolean = false;
  @Prop pageEntryDelay: number = 0;
  @Prop sourceSelectionBorder: boolean = false;
  @Prop originX: number = 0;
  @Prop originY: number = 0;
  @Prop originWidth: number = 0;
  @Prop originHeight: number = 0;
  @Prop originRadius: number = 18;
  @Prop @Watch('closeTransition') closing: boolean = false;
  onTransitionClosed?: () => void;
  onTransitionReady?: () => void;
  // Window-space photo frame for a host whose flight plane is outside HDS.
  onPhotoFrame?: (x: number, y: number, width: number, height: number, radius: number, duration: number, chrome: number) => void;
  onPhotoSelection?: (crop: PinmonyImageCrop) => void;
  onPhotoFlight?: (active: boolean) => void;
  @State private photoFlightActive: boolean = false;
  @State private frameX: number = 0;
  @State private frameY: number = 0;
  @State private frameWidth: number = 1;
  @State private frameHeight: number = 1;
  @State private frameRadius: number = 18;
  @State private backdrop: number = 0;
  @State private chrome: number = 0;
  private measured: boolean = false;
  private decoded: boolean = false;
  private started: boolean = false;
  private transitionVersion: number = 0;
  private transitionTimer: number = -1;
  private sourceX: number = 0;
  private sourceY: number = 0;
  private sourceWidth: number = 1;
  private sourceHeight: number = 1;
  private closeRequested: boolean = false;
  private resultSheetMounted: boolean = false;
  private returnPhotoFinished: boolean = false;
  private returnCompleted: boolean = false;
  private reopenAfterSheet: boolean = false;
  @State private intrinsicWidth: number = 1;
  @State private intrinsicHeight: number = 1;
  @Prop result: PinmonyVisualResult;
  @State private crop: PinmonyImageCrop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
  @State private widthValue: number = 360;
  @State private heightValue: number = 720;
  @State private resultContentWidth: number = 340;
  @State private sheetVisible: boolean = false;
  @State private sheetHeight: string | SheetSize = '40%';
  @State private expanded: boolean = false;
  private dragCorner: number = -2;
  private base: PinmonyImageCrop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
  private debounce: number = -1;
  private initial: number = -1;
  private alive: boolean = false;
  private readonly resultScroller: Scroller = new Scroller();
  onSearch?: (crop: PinmonyImageCrop, append: boolean, first: boolean) => void;
  onClose?: () => void;
  onRelated?: (id: string, origin?: PinmonyImageSearchOrigin) => boolean | void;

  aboutToAppear(): void {
    this.alive = true;
    if (this.uploadedPhoto) this.crop = { x: 0, y: 0, w: 1, h: 1 };
    // Network work does not depend on the photo transition or Sheet delay.
    this.initial = setTimeout(() => {
      if (!this.alive || this.presentationActive === false || this.closing) return;
      if (!this.animatePhoto) this.sheetVisible = true;
      if (!this.uploadedPhoto && this.onSearch) this.onSearch(this.crop, false, true);
    }, this.pageEntryDelay);
  }
  aboutToDisappear(): void { this.sourceLifetime++; this.sourceReturnPin = ''; this.alive = false; this.transitionVersion++; clearTimeout(this.transitionTimer); clearTimeout(this.debounce); clearTimeout(this.initial); }
  private beginTransition(): void {
    if (!this.animatePhoto || this.started || !this.measured || !this.decoded || !this.alive) return;
    this.started = true;
    PinmonyRuntimeLog.info('ImageSearchTrace: phase=transition-start');
    try {
      const ui = this.getUIContext();
      const root = ui.getComponentUtils().getRectangleById('pinmony-search-flight-' + this.pin);
      const ratio: number = this.imageWidth / Math.max(1, this.imageHeight);
      this.sourceWidth = Math.min(this.originWidth, this.originHeight * ratio);
      this.sourceHeight = this.sourceWidth / ratio;
      this.sourceX = this.originX - ui.px2vp(root.windowOffset.x) + (this.originWidth - this.sourceWidth) / 2;
      this.sourceY = this.originY - ui.px2vp(root.windowOffset.y) + (this.originHeight - this.sourceHeight) / 2;
    } catch (_) { this.sourceX = this.photoX(); this.sourceY = this.photoY(); this.sourceWidth = this.photoWidth(); this.sourceHeight = this.photoHeight(); }
    if (this.sourceWidth <= 0 || this.sourceHeight <= 0) {
      this.sourceX = this.photoX(); this.sourceY = this.photoY(); this.sourceWidth = this.photoWidth(); this.sourceHeight = this.photoHeight();
    }
    this.frameX = this.sourceX; this.frameY = this.sourceY;
    this.frameWidth = this.sourceWidth; this.frameHeight = this.sourceHeight;
    this.frameRadius = this.originRadius;
    this.publishPhotoFrame(true);
    this.onPhotoSelection?.(this.crop);
    this.photoFlightActive = true;
    this.onPhotoFlight?.(true);
    this.onTransitionReady?.();
    this.transitionTimer = setTimeout(() => { if (this.alive) this.runTransition(this.closing); }, 32);
  }
  private closeTransition(): void {
    if (!this.alive) return;
    if (!this.animatePhoto) {
      if (this.closing) {
        clearTimeout(this.initial); clearTimeout(this.debounce);
        this.closeRequested = true;
        this.returnPhotoFinished = true;
        this.sheetVisible = false;
        this.finishReturn();
      }
      return;
    }
    if (!this.closing) {
      this.transitionVersion++;
      this.reopenAfterSheet = this.resultSheetMounted && this.closeRequested;
      if (this.started && !this.reopenAfterSheet) this.runTransition(false);
      return;
    }
    clearTimeout(this.initial); clearTimeout(this.debounce); clearTimeout(this.transitionTimer);
    this.closeRequested = true;
    this.returnPhotoFinished = false;
    this.returnCompleted = false;
    this.reopenAfterSheet = false;
    if (!this.started) { this.sheetVisible = false; this.onTransitionClosed?.(); return; }
    // Hand off both photo and selection before the HDS content origin changes.
    this.transitionVersion++;
    this.photoFlightActive = true;
    this.onPhotoSelection?.(this.crop);
    this.onPhotoFlight?.(true);
    this.scheduleReturnPhoto();
  }
  private scheduleReturnPhoto(): void {
    clearTimeout(this.transitionTimer);
    const version: number = this.transitionVersion;
    // Commit the visible host photo at its current frame before changing bounds.
    this.transitionTimer = setTimeout(() => {
      if (this.alive && this.closing && version === this.transitionVersion) {
        this.sheetVisible = false;
        PinmonyRuntimeLog.info('ImageSearchTrace: phase=close-together');
        this.runTransition(true);
      }
    }, 32);
  }
  private resultSheetDisappeared(): void {
    this.resultSheetMounted = false;
    if (!this.alive) return;
    PinmonyRuntimeLog.info('ImageSearchTrace: phase=sheet-closed');
    if (!this.closing && (this.relatedOpening || this.presentationActive === false)) {
      if (this.resumeRelatedSheet && this.presentationActive) {
        this.resumeRelatedSheet = false;
        this.relatedOpening = false;
        this.sheetAppearing = true;
        this.sheetVisible = true;
      }
      return;
    }
    if (this.reopenAfterSheet && !this.closing) {
      this.reopenAfterSheet = false; this.runTransition(false);
      return;
    }
    if (this.closing) { this.finishReturn(); return; }
    if (!this.closing && !this.closeRequested) {
      this.closeRequested = true; this.onClose?.();
    }
  }
  private finishReturn(): void {
    if (!this.alive || !this.closing || this.returnCompleted || !this.returnPhotoFinished || this.resultSheetMounted) return;
    this.returnCompleted = true;
    this.photoFlightActive = false; this.onPhotoFlight?.(false);
    this.onTransitionClosed?.();
  }
  private runTransition(closing: boolean): void {
    const version: number = ++this.transitionVersion;
    this.photoFlightActive = true;
    this.onPhotoFlight?.(true);
    if (!closing) { this.closeRequested = false; this.sheetVisible = true; }
    PinmonyRuntimeLog.info('ImageSearchTrace: phase=' + (closing ? 'close-photo-start' : 'open-photo-start'));
    // Preserve the original photo timing; native Sheet lifecycle only gates cleanup.
    const duration: number = closing ? 200 : 240;
    this.getUIContext().animateTo({ duration: duration, curve: Curve.EaseOut,
      onFinish: () => {
        if (!this.alive || version !== this.transitionVersion) return;
        PinmonyRuntimeLog.info('ImageSearchTrace: phase=' + (closing ? 'close-photo-end' : 'open-photo-end'));
        if (closing) { this.returnPhotoFinished = true; this.finishReturn(); }
        else { this.photoFlightActive = false; this.onPhotoFlight?.(false); }
      } }, () => {
      this.frameX = closing ? this.sourceX : this.photoX(); this.frameY = closing ? this.sourceY : this.photoY();
      this.frameWidth = closing ? this.sourceWidth : this.photoWidth(); this.frameHeight = closing ? this.sourceHeight : this.photoHeight();
      this.frameRadius = closing ? this.originRadius : 0; this.backdrop = closing ? 0 : 1; this.chrome = closing ? 0 : 1;
    });
    // The host owns these animatable properties, so it starts its own transaction.
    this.publishPhotoFrame(closing, duration);
  }
  private publishPhotoFrame(source: boolean, duration: number = 0): void {
    if (!this.onPhotoFrame) return;
    if (source) {
      // The source belongs to the detail page before its title/safe-area change.
      this.onPhotoFrame(this.originX + (this.originWidth - this.sourceWidth) / 2,
        this.originY + (this.originHeight - this.sourceHeight) / 2, this.sourceWidth, this.sourceHeight, this.originRadius, duration, 0);
      return;
    }
    try {
      const ui = this.getUIContext();
      const root = ui.getComponentUtils().getRectangleById('pinmony-search-flight-' + this.pin);
      this.onPhotoFrame(ui.px2vp(root.windowOffset.x) + this.photoX(), ui.px2vp(root.windowOffset.y) + this.photoY(),
        this.photoWidth(), this.photoHeight(), 0, duration, 1);
    } catch (_) {}
  }
  private photoWidth(): number { return Math.min(this.widthValue, this.heightValue * 0.6 * (this.uploadedPhoto ? this.intrinsicWidth / this.intrinsicHeight : this.imageWidth / this.imageHeight)); }
  private photoHeight(): number { return this.photoWidth() * (this.uploadedPhoto ? this.intrinsicHeight / this.intrinsicWidth : this.imageHeight / this.imageWidth); }
  private photoX(): number { return (this.widthValue - this.photoWidth()) / 2; }
  private photoY(): number { return (this.heightValue * 0.6 - this.photoHeight()) / 2; }
  private queueSearch(): void {
    clearTimeout(this.debounce);
    this.debounce = setTimeout(() => {
      if (this.alive && this.onSearch) this.onSearch(this.crop, false, false);
    }, 280);
  }
  private canAdjustCrop(): boolean {
    return this.alive && this.presentationActive && !this.closing && !this.closeRequested &&
      !this.relatedOpening && !this.photoFlightActive && (!this.animatePhoto || this.started) &&
      this.photoWidth() > 0 && this.photoHeight() > 0;
  }
  private cropTouchWidth(corner: number): number {
    const width: number = this.crop.w * this.photoWidth();
    return corner < 0 ? width : 22 + Math.min(22, width / 2);
  }
  private cropTouchHeight(corner: number): number {
    const height: number = this.crop.h * this.photoHeight();
    return corner < 0 ? height : 22 + Math.min(22, height / 2);
  }
  private cropTouchX(corner: number): number {
    const left: number = this.photoX() + this.crop.x * this.photoWidth();
    if (corner < 0) return left;
    return corner === 1 || corner === 3 ? left + this.crop.w * this.photoWidth() -
      Math.min(22, this.crop.w * this.photoWidth() / 2) : left - 22;
  }
  private cropTouchY(corner: number): number {
    const top: number = this.photoY() + this.crop.y * this.photoHeight();
    if (corner < 0) return top;
    return corner > 1 ? top + this.crop.h * this.photoHeight() -
      Math.min(22, this.crop.h * this.photoHeight() / 2) : top - 22;
  }
  private startDrag(corner: number): void {
    this.dragCorner = -2;
    const allowed: boolean = this.canAdjustCrop() && corner >= -1 && corner <= 3;
    PinmonyRuntimeLog.info('ImageSearchCropTrace: phase=start corner=' + corner.toString() + ' allowed=' + allowed.toString());
    if (!allowed) return;
    this.dragCorner = corner;
    this.base = { x: this.crop.x, y: this.crop.y, w: this.crop.w, h: this.crop.h };
  }
  private finishDrag(cancelled: boolean): void {
    if (this.dragCorner >= -1) PinmonyRuntimeLog.info('ImageSearchCropTrace: phase=' +
      (cancelled ? 'cancel' : 'end') + ' changed=' + (this.crop.x !== this.base.x ||
        this.crop.y !== this.base.y || this.crop.w !== this.base.w || this.crop.h !== this.base.h).toString());
    this.dragCorner = -2;
  }
  private drag(e: GestureEvent, corner: number): void {
    if (!this.canAdjustCrop() || corner < -1) return;
    const dx: number = e.offsetX / this.photoWidth();
    const dy: number = e.offsetY / this.photoHeight();
    let left: number = this.base.x;
    let top: number = this.base.y;
    let right: number = left + this.base.w;
    let bottom: number = top + this.base.h;
    if (corner < 0) {
      left = Math.max(0, Math.min(1 - this.base.w, left + dx));
      top = Math.max(0, Math.min(1 - this.base.h, top + dy));
      right = left + this.base.w; bottom = top + this.base.h;
    } else {
      if (corner === 0 || corner === 2) left = Math.max(0, Math.min(right - 0.08, left + dx));
      else right = Math.min(1, Math.max(left + 0.08, right + dx));
      if (corner === 0 || corner === 1) top = Math.max(0, Math.min(bottom - 0.08, top + dy));
      else bottom = Math.min(1, Math.max(top + 0.08, bottom + dy));
    }
    this.crop = { x: left, y: top, w: right - left, h: bottom - top };
    this.onPhotoSelection?.(this.crop);
    this.queueSearch();
  }
  @Builder
  private cropTouchTarget(corner: number) {
    // These are real native hit targets above the passive photo/selection plane.
    // Opposite targets split at the center of narrow crops instead of overlapping.
    Row().width(this.cropTouchWidth(corner)).height(this.cropTouchHeight(corner))
      .position({ x: this.cropTouchX(corner), y: this.cropTouchY(corner) })
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(this.canAdjustCrop() ? HitTestMode.Block : HitTestMode.None)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) PinmonyRuntimeLog.info('ImageSearchCropTrace: phase=down corner=' + corner.toString());
      })
      .gesture(PanGesture({ fingers: 1, distance: 1 }).onActionStart(() => this.startDrag(corner))
        .onActionUpdate((event: GestureEvent) => { if (this.dragCorner === corner) this.drag(event, corner); })
        .onActionEnd(() => this.finishDrag(false)).onActionCancel(() => this.finishDrag(true)))
      .accessibilityLevel('no')
  }
  @StorageLink('immersiveLightMode') private sheetMaterialMode: string = 'immersive';

  @Builder
  private card(p: PinmonyRelatedPin) {
    Image(p.imageUrl).width('100%').height(Math.max(100, Math.min(430,
      (this.resultContentWidth - (this.resultColumnCount() - 1) * 10) / this.resultColumnCount() * p.imageHeight / p.imageWidth)))
      .id((this.uploadedPhoto ? 'pinmony-photo-result-' : 'pinmony-visual-result-' + this.pin + '-') + p.id)
      .objectFit(ImageFit.Cover).borderRadius(16)
      .onClick(() => this.openRelated(p))
      .accessibilityText(p.title || this.uiText("pm_open_related_pin_e1e5dfc7"))
  }
  private resultColumnCount(): number { return this.widthValue > this.heightValue ? 3 : 2; }
  private resultColumns(): number[] { return this.resultColumnCount() === 3 ? [0, 1, 2] : [0, 1]; }
  @Builder
  private resultsPanel() {
    Stack({ alignContent: Alignment.BottomEnd }) {
    Column({ space: 12 }) {
      Scroll(this.resultScroller) {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            ForEach(this.resultColumns(), (column: number) => {
              Column({ space: 10 }) {
                ForEach(this.result.items.filter((_p: PinmonyRelatedPin, i: number): boolean => i % this.resultColumnCount() === column),
                  (p: PinmonyRelatedPin) => { this.card(p) }, (p: PinmonyRelatedPin): string => p.id)
              }.layoutWeight(1)
            }, (column: number): string => this.resultColumnCount().toString() + ':' + column.toString())
          }.width('100%').alignItems(VerticalAlign.Top)
            .onAreaChange((_old: Area, area: Area) => {
              const width: number = Number(area.width);
              if (width > 0 && Math.abs(width - this.resultContentWidth) > 1) this.resultContentWidth = width;
            })
          if (this.result.error) {
            PinmonyActionNotice({ message: PinmonyI18n.render(this.result.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onSearch) this.onSearch(this.crop, this.result.items.length > 0, false); }, actionEnabled: !this.uploadedPhoto })
          } else if (this.result.loading) {
            LoadingProgress().color($r('app.color.accent')).width(36).height(36)
            Text(this.uiText('pm_photo_search_loading')).fontColor($r('app.color.secondary_text'))
          } else if (this.result.items.length === 0) {
            Text(this.uiText("pm_no_related_images_8c34996f")).fontColor($r('app.color.secondary_text')).fontSize(14)
          }
        }.width('100%').padding({ top: 72, bottom: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .id('pinmony-image-result-scroll-' + this.pin + '-' + this.uploadedPhoto)
        .onDidScroll(() => this.reportResultsPosition())
        .onScrollStop(() => this.reportResultsPosition())
        .onReachEnd(() => {
          if (this.alive && this.presentationActive && !this.relatedOpening && !this.sheetAppearing && !this.closing &&
            !this.result.loading && !this.result.error && !this.result.ended && this.result.items.length && this.onSearch)
            this.onSearch(this.crop, true, false);
        })
    }.padding({ left: 10, right: 10 }).width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      PinmonyBackToTopButton({ scrollOffsetVp: this.backToTopOffset, showButton: this.backToTopVisible && this.canBackToTop(),
        bottomInset: 16 + this.getUIContext().px2vp(this.gestureBarHeightPx),
        onBackToTop: () => this.backToTop() })
    }.width('100%').height('100%')
  }
  @Builder
  private searchContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
        .opacity(this.animatePhoto ? this.backdrop : 1).hitTestBehavior(HitTestMode.None)
      Stack({ alignContent: Alignment.TopStart }) {
      Image(this.imageUrl).width(this.photoWidth())
        .height(this.photoHeight()).objectFit(ImageFit.Contain)
        .onComplete((event) => {
          if (this.uploadedPhoto && event && event.width > 0 && event.height > 0) {
            this.intrinsicWidth = event.width; this.intrinsicHeight = event.height;
          }
          // Data readiness must not wait for rendering of the hidden flight image.
          if (event?.loadingStatus === 0 || event?.loadingStatus === 1) {
            this.decoded = true;
            PinmonyRuntimeLog.info('ImageSearchTrace: phase=image-ready rendered=' + (event.loadingStatus === 1).toString());
            this.beginTransition();
          }
        })
        .onError(() => { this.decoded = true; this.beginTransition(); })
        .opacity(this.onPhotoFrame && this.photoFlightActive || this.animatePhoto && !this.started ? 0 : 1).hitTestBehavior(HitTestMode.None)
      PinmonyImageSearchSelection({ photoWidth: this.photoWidth(), photoHeight: this.photoHeight(), crop: this.crop })
        .opacity(this.animatePhoto ? this.chrome : 1)
        .visibility(this.onPhotoFrame && this.photoFlightActive ? Visibility.Hidden : Visibility.Visible)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText(this.uiText("pm_move_search_area_e4eb45c8"))
      }.width(this.photoWidth()).height(this.photoHeight())
        .border({ width: this.sourceSelectionBorder ? 2 * (1 - this.chrome) : 0, color: $r('app.color.primary_text') })
        .borderRadius(this.animatePhoto ? this.frameRadius : 0).clip(true)
        .scale({ x: this.animatePhoto ? this.frameWidth / this.photoWidth() : 1,
          y: this.animatePhoto ? this.frameHeight / this.photoHeight() : 1, centerX: 0, centerY: 0 })
        .translate({ x: this.animatePhoto ? this.frameX : this.photoX(), y: this.animatePhoto ? this.frameY : this.photoY() })
        .opacity(this.animatePhoto && !this.started || this.onPhotoFrame && this.photoFlightActive ? 0 : 1)
        .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
      this.cropTouchTarget(-1)
      this.cropTouchTarget(0)
      this.cropTouchTarget(1)
      this.cropTouchTarget(2)
      this.cropTouchTarget(3)
    }.width('100%').height('100%').id('pinmony-search-flight-' + this.pin)
      .backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.Default)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) PinmonyRuntimeLog.info('ImageSearchCropTrace: phase=canvas-down allowed=' +
          this.canAdjustCrop().toString() + ' flight=' + this.photoFlightActive.toString() +
          ' active=' + this.presentationActive.toString());
      })
      .onAreaChange((_old: Area, area: Area) => {
        this.widthValue = Number(area.width); this.heightValue = Number(area.height);
        this.measured = this.widthValue > 0 && this.heightValue > 0; this.beginTransition();
      })
  }
  @Builder
  private presentedResultsPanel() {
    PinmonyModalNavigation({ titleText: this.uiText("pm_more_pins_like_this_6e224087"), fillContent: true,
      immersiveScroll: true, scrollControllers: [this.resultScroller],
      closeEnabled: true, onClose: () => { this.sheetVisible = false; if (this.alive && this.presentationActive && !this.relatedOpening && !this.closing && !this.closeRequested) { this.closeRequested = true; this.onClose?.(); } } }) {
      this.resultsPanel()
    }
  }

  build() {
    Column() { this.searchContent() }.width('100%').height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .bindSheet($$this.sheetVisible, this.presentedResultsPanel(), PinmonyImmersiveLight.sheetOptions({
      radius: LengthMetrics.vp(32),
      preferType: this.sheetWindowWidthVp >= 600 ? SheetType.CENTER : SheetType.BOTTOM,
        onWillAppear: (): void => { this.sheetAppearing = true; this.resultSheetMounted = true; PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyVisualSearchView.sheetVisible radius=uniform-32vp'); },
        onAppear: (): void => this.resultSheetAppeared(),
        height: this.sheetHeight, detents: ['40%', SheetSize.LARGE], showClose: false, dragBar: true,
        // Overlay the native handle on HDS chrome instead of reserving an opaque strip above it.
        enableFloatingDragBar: true,
        detentSelection: this.sheetHeight,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        backgroundColor: $r('app.color.page_background'), maskColor: Color.Transparent, enableOutsideInteractive: true,
        onHeightDidChange: (height: number) => { this.expanded = this.getUIContext().px2vp(height) > this.heightValue * 0.7; },
        onDetentsDidChange: (height: number) => this.updateSheetDetent(height),
        onWillSpringBackWhenDismiss: (_action: SpringBackAction): void => {},
        onWillDismiss: (action: DismissSheetAction) => {
          action.dismiss();
          if (this.alive && this.presentationActive && !this.relatedOpening && !this.closing && !this.closeRequested) {
            this.closeRequested = true; this.onClose?.();
          }
        },
        onDisappear: () => this.resultSheetDisappeared()
      }, this.sheetMaterialMode, false))
  }
}
