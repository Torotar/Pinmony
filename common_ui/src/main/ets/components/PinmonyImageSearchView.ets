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
  private sheetAppearing: boolean = false;
  private resultScrollOffset: number = 0;
  private openRelated(pin: PinmonyRelatedPin): void {
    if (!this.alive || this.presentationActive === false || this.relatedOpening || this.result.loading || pin.pinUrl === this.pin) return;
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
    if (this.presentationActive && !this.closing && this.sheetVisible) {
      try { this.resultScroller.scrollTo({ xOffset: 0, yOffset: this.resultScrollOffset, animation: false }); } catch (_) {}
    }
    this.sheetAppearing = false;
    if (this.presentationActive && !this.closing && this.sheetVisible) {
      this.relatedOpening = false;
      this.resumeRelatedSheet = false;
    }
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
  @Prop sourceSelectionBorder: boolean = false;
  @Prop originX: number = 0;
  @Prop originY: number = 0;
  @Prop originWidth: number = 0;
  @Prop originHeight: number = 0;
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
      if (!this.alive || this.presentationActive === false) return;
      if (!this.animatePhoto) this.sheetVisible = true;
      if (!this.uploadedPhoto && this.onSearch) this.onSearch(this.crop, false, true);
    }, 0);
  }
  aboutToDisappear(): void { this.alive = false; this.transitionVersion++; clearTimeout(this.transitionTimer); clearTimeout(this.debounce); clearTimeout(this.initial); }
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
    this.publishPhotoFrame(true);
    this.onPhotoSelection?.(this.crop);
    this.photoFlightActive = true;
    this.onPhotoFlight?.(true);
    this.onTransitionReady?.();
    this.transitionTimer = setTimeout(() => { if (this.alive) this.runTransition(this.closing); }, 32);
  }
  private closeTransition(): void {
    if (!this.animatePhoto || !this.alive) return;
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
      this.frameRadius = closing ? 18 : 0; this.backdrop = closing ? 0 : 1; this.chrome = closing ? 0 : 1;
    });
    // The host owns these animatable properties, so it starts its own transaction.
    this.publishPhotoFrame(closing, duration);
  }
  private publishPhotoFrame(source: boolean, duration: number = 0): void {
    if (!this.onPhotoFrame) return;
    if (source) {
      // The source belongs to the detail page before its title/safe-area change.
      this.onPhotoFrame(this.originX + (this.originWidth - this.sourceWidth) / 2,
        this.originY + (this.originHeight - this.sourceHeight) / 2, this.sourceWidth, this.sourceHeight, 18, duration, 0);
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
  private startDrag(): void { this.base = { x: this.crop.x, y: this.crop.y, w: this.crop.w, h: this.crop.h }; }
  private drag(e: GestureEvent, corner: number): void {
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
    this.queueSearch();
  }
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
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .onReachEnd(() => {
          if (this.alive && this.presentationActive && !this.relatedOpening && !this.sheetAppearing && !this.closing &&
            !this.result.loading && !this.result.error && !this.result.ended && this.result.items.length && this.onSearch)
            this.onSearch(this.crop, true, false);
        })
    }.padding({ left: 10, right: 10, top: 8, bottom: 16 }).width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
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
        .hitTestBehavior(HitTestMode.None)
    }.width('100%').height('100%').id('pinmony-search-flight-' + this.pin)
      .onAreaChange((_old: Area, area: Area) => {
        this.widthValue = Number(area.width); this.heightValue = Number(area.height);
        this.measured = this.widthValue > 0 && this.heightValue > 0; this.beginTransition();
      })
      .onTouch((event: TouchEvent) => {
        if (event.type !== TouchType.Down || !event.touches.length) return;
        const x: number = event.touches[0].x;
        const y: number = event.touches[0].y;
        const left: number = this.photoX() + this.crop.x * this.photoWidth();
        const top: number = this.photoY() + this.crop.y * this.photoHeight();
        const right: number = left + this.crop.w * this.photoWidth();
        const bottom: number = top + this.crop.h * this.photoHeight();
        this.dragCorner = -2;
        if (Math.abs(x - left) <= 22 && Math.abs(y - top) <= 22) this.dragCorner = 0;
        else if (Math.abs(x - right) <= 22 && Math.abs(y - top) <= 22) this.dragCorner = 1;
        else if (Math.abs(x - left) <= 22 && Math.abs(y - bottom) <= 22) this.dragCorner = 2;
        else if (Math.abs(x - right) <= 22 && Math.abs(y - bottom) <= 22) this.dragCorner = 3;
        else if (x >= left && x <= right && y >= top && y <= bottom) this.dragCorner = -1;
      })
      .gesture(PanGesture().onActionStart(() => this.startDrag()).onActionUpdate((event: GestureEvent) => {
        if (this.dragCorner >= -1) this.drag(event, this.dragCorner);
      }))
  }
  build() {
    Column() { this.searchContent() }.width('100%').height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .bindSheet($$this.sheetVisible, this.resultsPanel, {
      radius: LengthMetrics.vp(32),
      preferType: this.sheetWindowWidthVp >= 600 ? SheetType.CENTER : SheetType.BOTTOM,
        onWillAppear: (): void => { this.sheetAppearing = true; this.resultSheetMounted = true; PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyVisualSearchView.sheetVisible radius=uniform-32vp'); },
        onAppear: (): void => this.resultSheetAppeared(),
        height: this.sheetHeight, detents: ['40%', SheetSize.LARGE], showClose: true, dragBar: true, title: { title: this.uiText("pm_more_pins_like_this_6e224087") },
        detentSelection: this.sheetHeight,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        backgroundColor: $r('app.color.page_background'), maskColor: Color.Transparent, enableOutsideInteractive: true,
        onHeightDidChange: (height: number) => { this.expanded = this.getUIContext().px2vp(height) > this.heightValue * 0.7; },
        onDetentsDidChange: (height: number) => this.updateSheetDetent(height),
        onWillDismiss: (action: DismissSheetAction) => {
          action.dismiss();
          if (this.alive && this.presentationActive && !this.relatedOpening && !this.closing && !this.closeRequested) {
            this.closeRequested = true; this.onClose?.();
          }
        },
        onDisappear: () => this.resultSheetDisappeared()
      })
  }
}
