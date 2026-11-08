import { ImageFlightRect, imageContainRect } from '../services/PinmonyImageTransition';
import { curves } from '@kit.ArkUI';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyDetailSnapshot, PinmonyDetailAction, PinmonyCarouselItem } from '../models/PinmonyDetail';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { AnimatorResult } from '@kit.ArkUI';
import { imagePanBounds, imageFling, imageFlingDistance } from '../services/PinmonyImageMotion';

interface PinmonyViewerPhoto extends PinmonyCarouselItem {
  revision: number;
}

@Component
export struct PinmonyImageViewer {
  @Prop detail: PinmonyDetailSnapshot;
  @Prop imageUrl: string = '';
  @Prop previewUrl: string = '';
  @Prop origin: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  @Prop originRadius: number = 18;
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
  private previewRendered: boolean = false;
  @State private originalDataReady: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @State private photos: PinmonyViewerPhoto[] = [];
  @State private photoIndex: number = 0;
  @State private loadedPhotos: string[] = [];
  @State private failedPhotos: string[] = [];
  private paging: boolean = false;
  onImageChange?: (url: string) => void;

  private initializePhotos(): void {
    this.photos = (this.detail.carousel?.items || [])
      .filter((item: PinmonyCarouselItem): boolean => !item.video && !!item.imageUrl)
      .map((item: PinmonyCarouselItem): PinmonyViewerPhoto => ({ id: item.id, imageUrl: item.imageUrl,
        imageWidth: item.imageWidth, imageHeight: item.imageHeight, title: item.title, revision: 0 }));
    const selected: number = this.photos.findIndex((item: PinmonyCarouselItem): boolean => item.imageUrl === this.imageUrl);
    this.photoIndex = Math.max(0, selected);
    if (selected >= 0) {
      this.naturalWidth = this.photos[selected].imageWidth; this.naturalHeight = this.photos[selected].imageHeight;
    }
  }

  private selectPhoto(index: number): void {
    if (!this.mounted || !this.active || this.closing || this.transitioning || index === this.photoIndex ||
        index < 0 || index >= this.photos.length) return;
    this.stopInertia();
    this.photoIndex = index;
    const photo: PinmonyCarouselItem = this.photos[index];
    this.naturalWidth = photo.imageWidth; this.naturalHeight = photo.imageHeight;
    this.scaleValue = 1; this.dx = 0; this.dy = 0;
    this.originalDecoded = this.loadedPhotos.includes(photo.imageUrl);
    this.originalDataReady = this.originalDecoded;
    this.originalReady = this.originalDecoded;
    this.previewReady = false; this.previewRendered = false;
    this.setFrame(this.containRect());
    this.onImageChange?.(photo.imageUrl);
  }

  private transitionPhotos(): PinmonyCarouselItem[] {
    if (this.photos.length > 1) return [this.photos[this.photoIndex]];
    return [{ id: 'single', imageUrl: this.imageUrl || this.detail.imageUrl,
      imageWidth: this.detail.imageWidth, imageHeight: this.detail.imageHeight, title: '' }];
  }

  private retryPhoto(photo: PinmonyViewerPhoto): void {
    if (!this.active || this.closing || this.transitioning) return;
    this.failedPhotos = this.failedPhotos.filter((url: string): boolean => url !== photo.imageUrl);
    this.photos = this.photos.map((item: PinmonyViewerPhoto): PinmonyViewerPhoto => item.id === photo.id ?
      { id: item.id, imageUrl: item.imageUrl, imageWidth: item.imageWidth, imageHeight: item.imageHeight,
        title: item.title, revision: item.revision + 1 } : item);
  }

  private photoSettled(photo: PinmonyViewerPhoto, status: number, failed: boolean = false): void {
    if (!this.mounted || !this.photos.some((item: PinmonyViewerPhoto): boolean =>
      item.id === photo.id && item.imageUrl === photo.imageUrl && item.revision === photo.revision)) return;
    if (failed) {
      if (!this.failedPhotos.includes(photo.imageUrl)) this.failedPhotos = this.failedPhotos.concat(photo.imageUrl);
    } else if (status === 1) {
      if (!this.loadedPhotos.includes(photo.imageUrl)) this.loadedPhotos = this.loadedPhotos.concat(photo.imageUrl);
      // A hidden preloaded page cannot release the source image during entry.
      if (this.transitionStarted && !this.transitioning && this.photos[this.photoIndex]?.imageUrl === photo.imageUrl) {
        this.imageDecoded(1, true, photo.imageWidth, photo.imageHeight);
      }
    }
  }

  aboutToAppear(): void {
    this.mounted = true;
    this.initializePhotos();
    this.setFrame(this.origin.width > 0 && this.origin.height > 0 ? this.origin : this.containRect());
  }
  private imageDecoded(status: number, original: boolean, width: number = 0, height: number = 0): void {
    // Data readiness exposes an image for rendering, but cannot hide its source.
    if (!this.mounted || (status !== 0 && status !== 1)) return;
    const first: boolean = original ? status === 1 ? !this.originalDecoded : !this.originalDataReady : status === 1 ? !this.previewRendered : !this.previewReady;
    if (first) PinmonyRuntimeLog.info('ViewerMotionTrace: image=' + (original ? 'original' : 'preview') +
      ' event=' + (status === 1 ? 'rendered' : 'data-ready'));
    if (!this.transitionStarted && width > 0 && height > 0) { this.naturalWidth = width; this.naturalHeight = height; }
    if (original) {
      this.originalDataReady = true;
      if (status === 1) {
        this.originalDecoded = true;
        if (!this.previewReady || !this.transitioning) this.originalReady = true;
      }
    } else {
      this.previewReady = true;
      if (status === 1) this.previewRendered = true;
    }
    this.beginTransition();
  }
  private beginTransition(): void {
    if (!this.mounted || !this.viewportMeasured || this.transitionStarted || (!this.previewRendered && !this.originalDecoded)) return;
    // Match the visible image bounds, excluding letterboxing and carousel controls.
    this.setFrame(this.sourceRect());
    this.frameRadius = this.sourceRadius();
    this.transitionStarted = true; this.onReady?.();
    PinmonyRuntimeLog.info('ViewerMotionTrace: event=source-ready');
    this.transitionTimer = setTimeout(() => { if (this.mounted) this.transitionChanged(); }, 32);
  }
  private containRect(): ImageFlightRect {
    return imageContainRect(this.viewportWidth, this.viewportHeight, this.naturalWidth || this.detail.imageWidth, this.naturalHeight || this.detail.imageHeight);
  }
  private sourceRect(): ImageFlightRect {
    if (this.origin.width <= 0 || this.origin.height <= 0) return this.containRect();
    const image: ImageFlightRect = imageContainRect(this.origin.width, this.origin.height,
      this.naturalWidth || this.detail.imageWidth, this.naturalHeight || this.detail.imageHeight);
    return { x: this.origin.x + image.x, y: this.origin.y + image.y, width: image.width, height: image.height };
  }
  private sourceRadius(): number {
    const image: ImageFlightRect = this.sourceRect();
    // Contain images with letterboxing do not reach the rounded container corners.
    return this.origin.width > 0 && this.origin.height > 0 &&
      Math.abs(image.width - this.origin.width) < 0.5 && Math.abs(image.height - this.origin.height) < 0.5 ? this.originRadius : 0;
  }
  private setFrame(rect: ImageFlightRect): void {
    this.frameX = rect.x; this.frameY = rect.y;
    this.frameWidth = rect.width; this.frameHeight = rect.height;
  }
  private transitionChanged(): void {
    if (!this.mounted) return;
    clearTimeout(this.transitionTimer);
    if (!this.previewReady && !this.originalReady && !this.transitionStarted) {
      if (this.closing) this.onClosed?.();
      return;
    }
    const version: number = ++this.transitionVersion;
    this.transitioning = true;
    this.paging = false;
    this.stopInertia();
    const closing: boolean = this.closing;
    const target: ImageFlightRect = closing ? this.sourceRect() : this.containRect();
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
      this.setFrame(target); this.frameRadius = closing ? this.sourceRadius() : 0;
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
  @State private multiTouch: boolean = false;
  private touchMoved: boolean = false;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private inertia: AnimatorResult | undefined = undefined;
  private motionVersion: number = 0;
  @Prop @Watch('activeChanged') active: boolean = true;
  private activeChanged(): void { if (!this.active) { this.paging = false; this.stopInertia(); } }
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
    if (!this.active || this.transitioning || this.paging || this.multiTouch || this.touchMoved) return;
    this.stopInertia();
    if (this.onClose) this.onClose();
  }

  private toggleZoom(x: number = this.viewportWidth / 2, y: number = this.viewportHeight / 2): void {
    if (!this.active || this.transitioning || this.paging || this.multiTouch || this.touchMoved) return;
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
      this.naturalWidth || this.detail.imageWidth, this.naturalHeight || this.detail.imageHeight, this.scaleValue);
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
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background')).opacity(this.previewReady || this.originalReady || this.transitionStarted ? this.backdrop : 0)
        .hitTestBehavior(HitTestMode.None)
      ForEach(this.transitionPhotos(), (photo: PinmonyCarouselItem) => {
      Stack() {
      Image(this.photos.length > 1 ? photo.imageUrl : this.previewUrl || this.detail.imageUrl).width('100%').height('100%').objectFit(ImageFit.Cover).syncLoad(true)
        .scale({ x: this.scaleValue, y: this.scaleValue }).translate({ x: this.dx, y: this.dy })
        .opacity(this.previewReady && !this.originalReady ? 1 : 0)
        .onComplete((event) => { if (this.transitionPhotos()[0].imageUrl === photo.imageUrl) this.imageDecoded(event?.loadingStatus ?? -1, false, event?.width || 0, event?.height || 0); })
      Image(photo.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain)
        .scale({ x: this.scaleValue, y: this.scaleValue }).translate({ x: this.dx, y: this.dy })
        // Keep the rendered preview underneath until the full image renders.
        .opacity(this.originalReady || this.originalDataReady && (!this.transitioning || !this.previewReady) ? 1 : 0)
        .onComplete((event) => { if (this.transitionPhotos()[0].imageUrl === photo.imageUrl) this.imageDecoded(event?.loadingStatus ?? -1, true, event?.width || 0, event?.height || 0); })
      }.width(this.frameWidth).height(this.frameHeight).position({ x: this.frameX, y: this.frameY })
        .borderRadius(this.frameRadius).clip(this.transitioning)
        .opacity(this.photos.length > 1 && !this.transitioning && !this.closing ? 0 : 1)
        .hitTestBehavior(HitTestMode.None)
      }, (photo: PinmonyCarouselItem): string => photo.id + ':' + photo.imageUrl)
      if (this.photos.length > 1) {
        Swiper() {
          ForEach(this.photos, (photo: PinmonyViewerPhoto, index: number) => {
            Stack() {
              if (this.failedPhotos.includes(photo.imageUrl)) {
                PinmonyActionNotice({ active: this.active && !this.transitioning && !this.closing && index === this.photoIndex,
                  scope: photo.id + ':' + photo.revision,
                  message: PinmonyI18n.text('pm_image_failed_to_load_572993f5', this.uiLanguage),
                  actionText: PinmonyI18n.text('pm_retry_b8784c8d', this.uiLanguage),
                  onAction: () => this.retryPhoto(photo) })
              } else {
                if (!this.loadedPhotos.includes(photo.imageUrl)) {
                  LoadingProgress().width(32).height(32).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
                }
                Image(photo.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain).syncLoad(true)
                  .scale({ x: index === this.photoIndex ? this.scaleValue : 1, y: index === this.photoIndex ? this.scaleValue : 1 })
                  .translate({ x: index === this.photoIndex ? this.dx : 0, y: index === this.photoIndex ? this.dy : 0 })
                  .onComplete((event) => this.photoSettled(photo, event?.loadingStatus ?? -1))
                  .onError(() => this.photoSettled(photo, -1, true))
                  .accessibilityText(PinmonyI18n.format('pm_image_value_of_value_value_66dd48e8', [index + 1, this.photos.length, photo.title], this.uiLanguage))
              }
            }.width('100%').height('100%').clip(true)
          }, (photo: PinmonyViewerPhoto): string => photo.id + ':' + photo.imageUrl + ':' + photo.revision + ':' + this.uiLanguage)
        }.width('100%').height('100%').index(this.photoIndex).loop(false).autoPlay(false).indicator(false)
          .disableSwipe(!this.active || this.transitioning || this.closing || this.scaleValue > 1 || this.multiTouch)
          .onChange((index: number) => this.selectPhoto(index))
          .onAnimationStart(() => { if (this.mounted && this.active && !this.closing && !this.transitioning) { this.paging = true; this.touchMoved = true; } })
          .onAnimationEnd(() => { this.paging = false; })
          .opacity(!this.transitioning && !this.closing ? 1 : 0)
          .hitTestBehavior(!this.transitioning && !this.closing && this.active ? HitTestMode.Default : HitTestMode.None)
          .accessibilityLevel(!this.transitioning && !this.closing && this.active ? 'auto' : 'no-hide-descendants')
      }
    }.width('100%').height('100%').clip(true)
      // Keep gesture coordinates in the untransformed viewport, independent of image scale.
      .gesture(GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 }).onAction((e: GestureEvent) => {
              if (e.fingerList.length > 0) this.toggleZoom(e.fingerList[0].localX, e.fingerList[0].localY);
            }),
            TapGesture({ count: 1 }).onAction(() => this.closeViewer())
          ))
      .parallelGesture(GestureGroup(GestureMode.Parallel,
          PinchGesture().onActionStart(() => { this.stopInertia(); this.multiTouch = true; this.startScale = this.scaleValue; })
            .onActionUpdate((e: GestureEvent) => {
              if (!this.active || this.transitioning || this.closing || this.paging) return;
              this.scaleValue = Math.max(1, Math.min(8, this.startScale * e.scale));
              if (this.scaleValue === 1) { this.dx = 0; this.dy = 0; }
              else this.moveImage(this.dx, this.dy);
            }),
          PanGesture().onActionStart(() => { this.stopInertia(); this.touchMoved = true; this.startX = this.dx; this.startY = this.dy; })
            .onActionUpdate((e: GestureEvent) => {
              if (this.active && !this.transitioning && !this.closing && this.scaleValue > 1) this.moveImage(this.startX + e.offsetX, this.startY + e.offsetY);
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
