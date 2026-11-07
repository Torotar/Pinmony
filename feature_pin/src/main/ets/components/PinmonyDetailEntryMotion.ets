import { ImageFlightRect, PinmonyDetailEntryPhoto, imageContainRect } from '../services/PinmonyImageTransition';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyCdnImage } from 'common_ui';

@Component
export struct PinmonyDetailEntryMotion {
  @Prop photo: PinmonyDetailEntryPhoto;
  @Prop targetId: string = '';
  @Prop rootId: string = '';
  @Prop imageWidth: number = 1;
  @Prop imageHeight: number = 1;
  @Prop bottomInset: number = 0;
  @Prop restoredOffset: number = 0;
  @Prop @Watch('closeChanged') closing: boolean = false;
  onReveal?: (closing: boolean, pageExit: boolean) => void;
  onOpened?: () => void;
  onClosed?: () => void;
  @State private frame: ImageFlightRect = { x: 0, y: 0, width: 1, height: 1 };
  @State private showing: boolean = false;
  private source: ImageFlightRect = { x: 0, y: 0, width: 1, height: 1 };
  private alive: boolean = false;
  private decoded: boolean = false;
  private rendered: boolean = false;
  private measured: boolean = false;
  private started: boolean = false;
  private version: number = 0;
  private timer: number = -1;
  private layoutAttempts: number = 0;
  private preparationTimer: number = -1;
  private preparationExpired: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    // A cold preview must not keep the entire detail transparent on network IO.
    this.preparationTimer = setTimeout(() => this.openWithoutPhoto(), 80);
  }
  aboutToDisappear(): void {
    this.alive = false; this.version++; clearTimeout(this.timer); clearTimeout(this.preparationTimer);
  }
  private openWithoutPhoto(): void {
    if (!this.alive || this.closing || this.started) return;
    this.preparationExpired = true;
    PinmonyRuntimeLog.info('DetailMotionTrace: event=preview-wait-ended');
    this.begin();
  }
  private target(): ImageFlightRect | undefined {
    try {
      const ui = this.getUIContext();
      const root = ui.getComponentUtils().getRectangleById(this.rootId);
      const target = ui.getComponentUtils().getRectangleById(this.targetId);
      const width: number = ui.px2vp(target.size.width);
      const height: number = ui.px2vp(target.size.height) - this.bottomInset;
      if (width <= 0 || height <= 0) return undefined;
      const contained: ImageFlightRect = imageContainRect(width, height, this.imageWidth, this.imageHeight);
      this.source = { x: this.photo.x - ui.px2vp(root.windowOffset.x), y: this.photo.y - ui.px2vp(root.windowOffset.y),
        width: this.photo.width, height: this.photo.height };
      return { x: ui.px2vp(target.windowOffset.x - root.windowOffset.x) + contained.x,
        y: ui.px2vp(target.windowOffset.y - root.windowOffset.y) + contained.y,
        width: contained.width, height: contained.height };
    } catch (_) { return undefined; }
  }
  private heroVisible(): boolean {
    try {
      const ui = this.getUIContext();
      const root = ui.getComponentUtils().getRectangleById(this.rootId);
      const hero = ui.getComponentUtils().getRectangleById(this.targetId);
      const top: number = ui.px2vp(hero.windowOffset.y - root.windowOffset.y);
      const height: number = ui.px2vp(hero.size.height) - this.bottomInset;
      const viewport: number = ui.px2vp(root.size.height);
      const visible: number = Math.max(0, Math.min(top + height, viewport) - Math.max(top, 56));
      return height > 0 && visible > 0;
    } catch (_) { return false; }
  }
  private begin(): void {
    if (!this.alive || this.started || !this.measured) return;
    const pageOnly: boolean = this.photo.returnPageOnly === true || !this.closing &&
      (this.restoredOffset > 0 || this.preparationExpired);
    if (!pageOnly && !this.decoded) return;
    const target: ImageFlightRect | undefined = this.target();
    if (!target) {
      if (++this.layoutAttempts < 12) {
        clearTimeout(this.timer);
        this.timer = setTimeout(() => this.begin(), 16);
      } else {
        this.started = true;
        clearTimeout(this.preparationTimer);
        PinmonyRuntimeLog.info('DetailMotionTrace: event=layout-unavailable');
        if (this.closing) this.move(true); else this.onOpened?.();
      }
      return;
    }
    this.frame = this.closing ? target : this.source;
    this.showing = !pageOnly && this.heroVisible();
    // Data readiness may arrive before this Image has a drawable frame. Make
    // the photo visible at its source first, then wait for its render callback.
    // Page-only transitions do not display this Image and need no render wait.
    if (this.showing && !this.rendered) return;
    this.started = true;
    clearTimeout(this.preparationTimer);
    // Commit the source frame before starting the destination animation.
    this.timer = setTimeout(() => { if (this.alive) this.move(this.closing); }, 32);
  }
  private imageComplete(status: number): void {
    if (!this.alive || this.started || status !== 0 && status !== 1) return;
    this.decoded = true;
    if (status === 1) this.rendered = true;
    PinmonyRuntimeLog.info('DetailMotionTrace: event=' + (status === 1 ? 'photo-rendered' : 'photo-data-ready'));
    this.begin();
  }
  private closeChanged(): void {
    if (!this.closing || !this.alive) return;
    clearTimeout(this.timer);
    clearTimeout(this.preparationTimer);
    if (!this.started || !this.decoded) { this.onClosed?.(); return; }
    this.move(true);
  }
  private move(closing: boolean): void {
    const measuredTarget: ImageFlightRect | undefined = this.target();
    if (!measuredTarget && !closing) { this.onOpened?.(); return; }
    const target: ImageFlightRect = measuredTarget || this.frame;
    const version: number = ++this.version;
    const pageExit: boolean = !measuredTarget || this.photo.returnPageOnly === true || !this.heroVisible() ||
      !this.rendered || !closing && (this.restoredOffset > 0 || this.preparationExpired);
    if (!this.showing) this.frame = target;
    this.showing = !pageExit;
    PinmonyRuntimeLog.info('DetailMotionTrace: event=' + (closing ? 'close-start' : 'open-start'));
    PinmonyRuntimeLog.info('DetailMotionTrace: phase=' + (closing ? 'close' : 'open') +
      ' mode=' + (pageExit ? 'page' : 'photo') + ' restored=' + (this.restoredOffset > 0).toString());
    this.onReveal?.(closing, pageExit);
    this.getUIContext().animateTo({ duration: closing ? 200 : 240, curve: Curve.EaseOut,
      onFinish: () => {
        if (!this.alive || version !== this.version) return;
        this.showing = false;
        PinmonyRuntimeLog.info('DetailMotionTrace: event=' + (closing ? 'close-end' : 'open-end'));
        if (closing) this.onClosed?.(); else this.onOpened?.();
      } }, () => { this.frame = closing ? this.source : target; });
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PinmonyCdnImage({ url: this.photo.imageUrl, fit: ImageFit.Cover, useSharedDecode: false,
        onDataReady: () => this.imageComplete(0),
        onDecoded: () => this.imageComplete(1),
        onFailure: (_code: number) => { if (!this.alive || this.started) return;
          if (this.closing) this.onClosed?.(); else this.openWithoutPhoto(); } })
        .width(this.frame.width).height(this.frame.height)
        .borderRadius(18).clip(true).position({ x: this.frame.x, y: this.frame.y })
        .opacity(this.showing ? 1 : 0).accessibilityLevel('no')
    }.width('100%').height('100%').clip(true).hitTestBehavior(HitTestMode.None)
      .onAreaChange(() => { this.measured = true; this.begin(); })
  }
}
