import { ImageFlightRect, PinmonyDetailEntryPhoto, imageContainRect } from '../services/PinmonyImageTransition';
import { PinmonyRuntimeLog } from 'common_foundation';

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
  private measured: boolean = false;
  private started: boolean = false;
  private version: number = 0;
  private timer: number = -1;
  private layoutAttempts: number = 0;

  aboutToAppear(): void { this.alive = true; }
  aboutToDisappear(): void { this.alive = false; this.version++; clearTimeout(this.timer); }
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
      return height > 0 && visible >= Math.min(height, viewport - 56) * 0.8;
    } catch (_) { return false; }
  }
  private begin(): void {
    if (!this.alive || this.started || !this.decoded || !this.measured) return;
    const target: ImageFlightRect | undefined = this.target();
    if (!target) {
      if (++this.layoutAttempts < 12) {
        clearTimeout(this.timer);
        this.timer = setTimeout(() => this.begin(), 16);
      } else {
        this.started = true;
        PinmonyRuntimeLog.info('DetailMotionTrace: event=layout-unavailable');
        this.onOpened?.();
      }
      return;
    }
    this.started = true;
    this.frame = this.closing ? target : this.source;
    this.showing = this.closing ? this.heroVisible() : this.restoredOffset <= 0 && this.heroVisible();
    // Commit the source frame before starting the destination animation.
    this.timer = setTimeout(() => { if (this.alive) this.move(this.closing); }, 32);
  }
  private closeChanged(): void {
    if (!this.closing || !this.alive) return;
    clearTimeout(this.timer);
    if (!this.started || !this.decoded) { this.onClosed?.(); return; }
    this.move(true);
  }
  private move(closing: boolean): void {
    const target: ImageFlightRect | undefined = this.target();
    if (!target) { if (closing) this.onClosed?.(); else this.onOpened?.(); return; }
    const version: number = ++this.version;
    const pageExit: boolean = !this.heroVisible() || !closing && this.restoredOffset > 0;
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
      Image(this.photo.imageUrl).width(this.frame.width).height(this.frame.height).objectFit(ImageFit.Cover)
        .borderRadius(18).clip(true).position({ x: this.frame.x, y: this.frame.y })
        .opacity(this.showing ? 1 : 0).accessibilityLevel('no')
        .onComplete((event) => { if (event?.loadingStatus === 1) { this.decoded = true; this.begin(); } })
        .onError(() => { if (this.closing) this.onClosed?.(); else this.onOpened?.(); })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      .onAreaChange(() => { this.measured = true; this.begin(); })
  }
}
