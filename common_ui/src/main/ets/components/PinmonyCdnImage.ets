import { image } from '@kit.ImageKit';
import { PinmonyJpegDecode, PinmonyJpegLease, acceptsSoftwareJpeg } from 'common_network';

/** A single-image host; geometry, labels and interaction remain owned by its caller. */
@Component
export struct PinmonyCdnImage {
  @Prop @Watch('reload') url: string = '';
  @Prop @Watch('reload') useSharedDecode: boolean = true;
  @Prop fit: ImageFit = ImageFit.Cover;
  @Prop @Watch('loadingChanged') loadingActive: boolean = true;
  @Prop @Watch('loadingChanged') viewportOnly: boolean = false;
  @Prop loadPriority: number = 1;
  onDecoded?: () => void;
  onDataReady?: () => void;
  onFailure?: (code: number) => void;
  @State private bitmap: image.PixelMap | undefined = undefined;
  @State private pending: boolean = false;
  private lease: PinmonyJpegLease | undefined = undefined;
  private visible: boolean = false;
  private inViewport: boolean = false;
  @State private loadAllowed: boolean = true;
  @State private nativeSourceAdmitted: boolean = false;
  @State private generation: number = 0;

  aboutToAppear(): void { this.visible = true; this.reload(); }
  aboutToDisappear(): void { this.visible = false; this.generation++; this.release(); }
  private release(): void {
    this.nativeSourceAdmitted = false;
    this.bitmap = undefined;
    this.pending = false;
    this.lease?.release();
    this.lease = undefined;
  }
  private reload(): void {
    const generation: number = ++this.generation;
    this.release();
    this.loadAllowed = this.loadingActive !== false && (this.viewportOnly !== true || this.inViewport);
    this.nativeSourceAdmitted = this.useSharedDecode === false && this.loadAllowed;
    if (!this.visible || this.useSharedDecode === false || !acceptsSoftwareJpeg(this.url)) return;
    const lease: PinmonyJpegLease = PinmonyJpegDecode.acquire(this.url, this.loadAllowed, this.loadPriority ?? 1);
    this.lease = lease;
    this.bitmap = lease.bitmap;
    this.pending = !this.bitmap;
    lease.ready.then((bitmap: image.PixelMap): void => {
      if (!this.visible || this.generation !== generation || this.lease !== lease) return;
      this.bitmap = bitmap;
      this.pending = false;
    }).catch((): void => {
      if (!this.visible || this.generation !== generation || this.lease !== lease) return;
      this.release();
    });
  }
  private loadingChanged(): void {
    this.loadAllowed = this.loadingActive !== false && (this.viewportOnly !== true || this.inViewport);
    // Admission pauses new work; it must not unmount a native Image already
    // shown beneath a detail transition, Sheet, another tab or background state.
    if (this.visible && this.useSharedDecode === false && this.loadAllowed) this.nativeSourceAdmitted = true;
    this.lease?.setActive?.(this.visible && this.loadAllowed);
  }
  private canRenderImage(): boolean {
    return !this.pending && !!this.url && (this.loadAllowed || this.nativeSourceAdmitted || !!this.bitmap);
  }
  @Builder
  private imageBody(generation: number) {
      if (this.canRenderImage()) {
        Image(this.bitmap || this.url).width('100%').height('100%').objectFit(this.fit)
          .onComplete((event) => {
            if (!this.visible || generation !== this.generation) return;
            if (event?.loadingStatus === 0) this.onDataReady?.();
            if (event?.loadingStatus === 1) this.onDecoded?.();
          })
          .onError((event) => { if (this.visible && generation === this.generation) this.onFailure?.(event?.error?.code || 0); })
      }
  }
  build() {
    Stack() {
      ForEach([this.generation], (generation: number) => { this.imageBody(generation); }, (generation: number) => generation.toString())
    }.width('100%').height('100%')
      .onVisibleAreaChange([0, 0.01], (visible: boolean, ratio: number) => {
        this.inViewport = visible && ratio > 0;
        this.loadingChanged();
      })
  }
}
