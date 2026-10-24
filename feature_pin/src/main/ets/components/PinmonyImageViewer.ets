import { ImageFlightRect, imageContainRect } from '../services/PinmonyImageTransition';
import { curves } from '@kit.ArkUI';
import { PinmonyDetailSnapshot, PinmonyDetailAction } from '../models/PinmonyDetail';
import { AnimatorResult } from '@kit.ArkUI';
import { imagePanBounds, imageFling, imageFlingDistance } from '../services/PinmonyImageMotion';

@Component
export struct PinmonyImageViewer {
  @Prop detail: PinmonyDetailSnapshot;
  @Prop imageUrl: string = '';
  @Prop previewUrl: string = '';
  @Prop origin: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  @Prop @Watch('transitionChanged') closing: boolean = false;
  onClosed?: () => void;
  onReady?: () => void;
  @State private frameX: number = 0;
  @State private frameY: number = 0;
  @State private frameWidth: number = 360;
  @State private frameHeight: number = 720;
  @State private frameRadius: number = 18;
  @State private backdrop: number = 0;
  @State private transitioning: boolean = true;
  private transitionVersion: number = 0;
  private transitionTimer: number = -1;
  private transitionStarted: boolean = false;
  private mounted: boolean = false;
  private viewportMeasured: boolean = false;
  private naturalWidth: number = 0;
  private naturalHeight: number = 0;
  private originalDecoded: boolean = false;
  aboutToAppear(): void {
    this.mounted = true;
    this.setFrame(this.origin.width > 0 && this.origin.height > 0 ? this.origin : this.containRect());
  }
  private imageDecoded(status: number, original: boolean, width: number = 0, height: number = 0): void {
    if (!this.mounted || status !== 1) return;
    if (!this.transitionStarted && width > 0 && height > 0) { this.naturalWidth = width; this.naturalHeight = height; }
    if (original) {
      this.originalDecoded = true;
      if (!this.previewReady || !this.transitioning) this.originalReady = true;
    } else this.previewReady = true;
    this.beginTransition();
  }
  private beginTransition(): void {
    if (!this.mounted || !this.viewportMeasured || this.transitionStarted || (!this.previewReady && !this.originalReady)) return;
    this.transitionStarted = true; this.onReady?.();
    this.transitionTimer = setTimeout(() => { if (this.mounted) this.transitionChanged(); }, 0);
  }
  private containRect(): ImageFlightRect {
    return imageContainRect(this.viewportWidth, this.viewportHeight, this.naturalWidth || this.detail.imageWidth, this.naturalHeight || this.detail.imageHeight);
  }
  private setFrame(rect: ImageFlightRect): void {
    this.frameX = rect.x; this.frameY = rect.y;
    this.frameWidth = rect.width; this.frameHeight = rect.height;
  }
  private transitionChanged(): void {
    if (!this.mounted) return;
    clearTimeout(this.transitionTimer);
    if (!this.previewReady && !this.originalReady) {
      if (this.closing) this.onClosed?.();
      return;
    }
    const version: number = ++this.transitionVersion;
    this.transitioning = true;
    this.stopInertia();
    const closing: boolean = this.closing;
    const target: ImageFlightRect = closing && this.origin.width > 0 && this.origin.height > 0 ? this.origin : this.containRect();
    this.getUIContext().animateTo({ duration: closing ? 400 : 420,
      curve: curves.springMotion(closing ? 0.42 : 0.34, 0.9),
      onFinish: () => {
        if (!this.mounted || version !== this.transitionVersion) return;
        if (!closing) {
          this.transitioning = false;
          if (this.originalDecoded) this.originalReady = true;
          return;
        }
        if (this.closing) this.onClosed?.();
      } }, () => {
      this.setFrame(target); this.frameRadius = closing ? 18 : 0;
      this.backdrop = closing ? 0 : 1;
      this.scaleValue = 1; this.dx = 0; this.dy = 0;
    });
  }
  @Prop actionsReady: boolean = false;
  @State private controls: boolean = true;
  @State private scaleValue: number = 1;
  @State private dx: number = 0;
  @State private dy: number = 0;
  @State private previewReady: boolean = false;
  @State private originalReady: boolean = false;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 720;
  private startScale: number = 1;
  private startX: number = 0;
  private startY: number = 0;
  private multiTouch: boolean = false;
  private touchMoved: boolean = false;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private inertia: AnimatorResult | undefined = undefined;
  private motionVersion: number = 0;
  @Prop @Watch('activeChanged') active: boolean = true;
  private activeChanged(): void { if (!this.active) this.stopInertia(); }
  aboutToDisappear(): void { this.mounted = false; this.transitionVersion++; clearTimeout(this.transitionTimer); this.stopInertia(); }
  onControlsChange?: (visible: boolean) => void;
  onClose?: () => void;
  onAction?: (id: string, kind: string) => void;
  onDownload?: () => void;
  onSave?: () => void;

  private action(kind: string): PinmonyDetailAction | undefined {
    return this.detail.actions.find((a: PinmonyDetailAction): boolean => a.kind === kind);
  }

  private closeViewer(): void {
    if (this.multiTouch || this.touchMoved) return;
    this.stopInertia();
    if (this.onClose) this.onClose();
  }

  private toggleZoom(x: number = this.viewportWidth / 2, y: number = this.viewportHeight / 2): void {
    if (this.multiTouch || this.touchMoved) return;
    this.stopInertia();
    const target: number = this.scaleValue > 1 ? 1 : 2.4;
    const ratio: number = target / this.scaleValue;
    const targetX: number = (x - this.viewportWidth / 2) * (1 - ratio) + this.dx * ratio;
    const targetY: number = (y - this.viewportHeight / 2) * (1 - ratio) + this.dy * ratio;
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
      this.scaleValue = target;
      if (target === 1) { this.dx = 0; this.dy = 0; }
      else this.moveImage(targetX, targetY);
    });
  }

  private trackTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) this.stopInertia();
    if (event.touches.length > 1) this.multiTouch = true;
    else if (event.type === TouchType.Down && event.touches.length === 1) {
      this.multiTouch = false; this.touchMoved = false;
      this.touchStartX = event.touches[0].x; this.touchStartY = event.touches[0].y;
    }
    if (event.type === TouchType.Move || event.type === TouchType.Up) {
      for (const touch of event.touches) {
        if (Math.abs(touch.x - this.touchStartX) > 5 || Math.abs(touch.y - this.touchStartY) > 5) this.touchMoved = true;
      }
    }
    if (event.type === TouchType.Cancel) this.touchMoved = true;
  }

  private stopInertia(): void {
    this.motionVersion++;
    const old: AnimatorResult | undefined = this.inertia;
    this.inertia = undefined;
    if (old) old.cancel();
  }

  private moveImage(x: number, y: number): void {
    const bounds = imagePanBounds(this.viewportWidth, this.viewportHeight,
      this.detail.imageWidth, this.detail.imageHeight, this.scaleValue);
    this.dx = Math.max(-bounds.x, Math.min(bounds.x, x));
    this.dy = Math.max(-bounds.y, Math.min(bounds.y, y));
  }

  private startInertia(x: number, y: number): void {
    this.stopInertia();
    if (!this.active || this.multiTouch || this.scaleValue <= 1) return;
    const fling = imageFling(x, y);
    if (!fling.seconds) return;
    const version: number = this.motionVersion;
    const fromX: number = this.dx, fromY: number = this.dy;
    const animation: AnimatorResult = this.getUIContext().createAnimator({ duration: Math.ceil(fling.seconds * 1000),
      easing: 'linear', direction: 'normal', delay: 0, fill: 'forwards', iterations: 1, begin: 0, end: fling.seconds });
    this.inertia = animation;
    animation.onFrame = (seconds: number): void => {
      if (version !== this.motionVersion || !this.active) return;
      const beforeX: number = this.dx, beforeY: number = this.dy;
      this.moveImage(fromX + imageFlingDistance(fling.x, fling.decay, seconds),
        fromY + imageFlingDistance(fling.y, fling.decay, seconds));
      if (seconds > 0 && this.dx === beforeX && this.dy === beforeY) this.stopInertia();
    };
    animation.onFinish = (): void => { if (version === this.motionVersion) this.inertia = undefined; };
    animation.play();
  }

  @Builder
  private imageContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background')).opacity(this.previewReady || this.originalReady ? this.backdrop : 0)
        .hitTestBehavior(HitTestMode.None)
      Stack() {
      Image(this.previewUrl || this.detail.imageUrl).width('100%').height('100%').objectFit(ImageFit.Cover).syncLoad(true)
        .scale({ x: this.scaleValue, y: this.scaleValue }).translate({ x: this.dx, y: this.dy })
        .opacity(this.previewReady && !this.originalReady ? 1 : 0)
        .onComplete((event) => this.imageDecoded(event?.loadingStatus ?? -1, false, event?.width || 0, event?.height || 0))
      Image(this.imageUrl || this.detail.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain)
        .scale({ x: this.scaleValue, y: this.scaleValue }).translate({ x: this.dx, y: this.dy })
        .opacity(this.originalReady ? 1 : 0)
        .onComplete((event) => this.imageDecoded(event?.loadingStatus ?? -1, true, event?.width || 0, event?.height || 0))
      }.width(this.frameWidth).height(this.frameHeight).position({ x: this.frameX, y: this.frameY })
        .borderRadius(this.frameRadius).clip(this.transitioning)
    }.width('100%').height('100%').clip(true)
      // Keep gesture coordinates in the untransformed viewport, independent of image scale.
      .gesture(GestureGroup(GestureMode.Parallel,
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 }).onAction((e: GestureEvent) => {
              if (e.fingerList.length > 0) this.toggleZoom(e.fingerList[0].localX, e.fingerList[0].localY);
            }),
            TapGesture({ count: 1 }).onAction(() => this.closeViewer())
          ),
          PinchGesture().onActionStart(() => { this.stopInertia(); this.multiTouch = true; this.startScale = this.scaleValue; })
            .onActionUpdate((e: GestureEvent) => {
              this.scaleValue = Math.max(1, Math.min(8, this.startScale * e.scale));
              if (this.scaleValue === 1) { this.dx = 0; this.dy = 0; }
              else this.moveImage(this.dx, this.dy);
            }),
          PanGesture().onActionStart(() => { this.stopInertia(); this.touchMoved = true; this.startX = this.dx; this.startY = this.dy; })
            .onActionUpdate((e: GestureEvent) => {
              if (this.scaleValue > 1) this.moveImage(this.startX + e.offsetX, this.startY + e.offsetY);
            })
            .onActionEnd((e: GestureEvent) => this.startInertia(e.velocityX, e.velocityY))
            .onActionCancel(() => this.stopInertia())
        ))
      .onTouch((event: TouchEvent) => this.trackTouch(event))
      .onAreaChange((_old: Area, area: Area) => {
        this.stopInertia(); this.viewportWidth = Number(area.width); this.viewportHeight = Number(area.height);
        this.viewportMeasured = true;
        if (!this.transitionStarted) this.beginTransition();
        else this.transitionChanged();
      })
  }

  build() { this.imageContent() }
}
