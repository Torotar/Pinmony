import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { PinmonyUiCommitQueue } from '../services/PinmonyUiCommitQueue';
import { PinmonyJpegDecode, PinmonyJpegLease, acceptsSoftwareJpeg } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyImageLoadTrace } from '../services/PinmonyImageLoadTrace';

let pinmonyImageTraceSerial: number = 0;

/** A single-image host; geometry, labels and interaction remain owned by its caller. */
@Component
export struct PinmonyCdnImage {
  @Prop @Watch('reload') url: string = '';
  @Prop @Watch('reload') useSharedDecode: boolean = true;
  @Prop fit: ImageFit = ImageFit.Cover;
  @Prop @Watch('loadingChanged') loadingActive: boolean = true;
  @Prop @Watch('loadingChanged') viewportOnly: boolean = false;
  @Prop @Watch('loadingChanged') loadPriority: number = 1;
  @Prop traceLoading: boolean = false;
  @Prop traceIndex: number = -1;
  onDecoded?: () => void;
  onDataReady?: () => void;
  onFailure?: (code: number) => void;
  onPhotoColor?: (red: number, green: number, blue: number) => void;
  @State private bitmap: image.PixelMap | undefined = undefined;
  @State private pending: boolean = false;
  private lease: PinmonyJpegLease | undefined = undefined;
  private visible: boolean = false;
  private inViewport: boolean = false;
  @State private loadAllowed: boolean = true;
  @State private nativeSourceAdmitted: boolean = false;
  @State private generation: number = 0;
  private readonly uiCommits: PinmonyUiCommitQueue = new PinmonyUiCommitQueue();
  private settledGeneration: number = -1;
  private readonly traceTask: number = ++pinmonyImageTraceSerial;
  private sourceStartedAt: number = 0;
  private tracePhases: Set<string> = new Set<string>();
  private readonly loadTrace: PinmonyImageLoadTrace = new PinmonyImageLoadTrace();

  aboutToAppear(): void { this.uiCommits.activate(); this.visible = true; this.reload(); }
  aboutToDisappear(): void { this.visible = false; this.uiCommits.dispose(); this.generation++; this.release(); }
  private release(): void {
    this.nativeSourceAdmitted = false;
    this.bitmap = undefined;
    this.pending = false;
    this.lease?.release();
    this.lease = undefined;
  }
  private reload(): void {
    this.uiCommits.clear();
    this.sourceStartedAt = Date.now();
    this.tracePhases.clear();
    const generation: number = ++this.generation;
    this.release();
    this.loadAllowed = this.loadingActive !== false && (this.viewportOnly !== true || this.inViewport);
    this.nativeSourceAdmitted = this.useSharedDecode === false && this.loadAllowed;
    if (!this.visible || this.useSharedDecode === false || !acceptsSoftwareJpeg(this.url)) return;
    const lease: PinmonyJpegLease = PinmonyJpegDecode.acquire(this.url, this.loadAllowed, this.loadPriority ?? 1);
    this.lease = lease;
    this.bitmap = lease.bitmap;
    this.pending = !this.bitmap;
    if (this.bitmap && this.onPhotoColor) this.samplePhotoColor(this.bitmap, generation);
    lease.ready.then((bitmap: image.PixelMap): void => {
      if (!this.visible || this.generation !== generation || this.lease !== lease) return;
      this.bitmap = bitmap;
      this.pending = false;
      if (!lease.bitmap && this.onPhotoColor) this.samplePhotoColor(bitmap, generation);
    }).catch((): void => {
      if (!this.visible || this.generation !== generation || this.lease !== lease) return;
      this.release();
    });
  }
  private async samplePhotoColor(bitmap: image.PixelMap, generation: number): Promise<void> {
    if (!this.onPhotoColor || !this.visible || this.generation !== generation) return;
    try {
      const picker = await effectKit.createColorPicker(bitmap);
      const color = await picker.getMainColor();
      if (!this.visible || this.generation !== generation) return;
      this.onPhotoColor?.(color.red, color.green, color.blue);
    } catch (_) {}
  }
  private loadingChanged(): void {
    this.loadAllowed = this.loadingActive !== false && (this.viewportOnly !== true || this.inViewport);
    // Admission pauses new work; it must not unmount a native Image already
    // shown beneath a detail transition, Sheet, another tab or background state.
    if (this.visible && this.useSharedDecode === false && this.loadAllowed) this.nativeSourceAdmitted = true;
    this.lease?.setPriority?.(this.loadPriority ?? 1);
    this.lease?.setActive?.(this.visible && this.loadAllowed);
    if (this.bitmap && this.loadAllowed && this.onPhotoColor) this.samplePhotoColor(this.bitmap, this.generation);
  }
  private canRenderImage(): boolean {
    return !this.pending && !!this.url && (this.loadAllowed || this.nativeSourceAdmitted || !!this.bitmap);
  }
  private queueImageEvent(generation: number, status: number, code: number = 0): void {
    this.uiCommits.post('image-' + status.toString(), (): void => {
      if (!this.visible || generation !== this.generation || this.settledGeneration === generation) return;
      if (status === 0) { this.auditImage('data-ready'); this.onDataReady?.(); return; }
      this.settledGeneration = generation;
      if (status === 1) { this.auditImage('decoded'); this.onDecoded?.(); }
      else { this.auditImage('failed', code); this.onFailure?.(code); }
    });
  }
  private auditImage(phase: string, code: number = 0, failureInfo?: RequestDownloadInfo): void {
    if (!this.traceLoading || !this.visible || this.tracePhases.has(phase)) return;
    this.tracePhases.add(phase);
    try {
      this.loadTrace.record(this.traceTask, this.generation, this.traceIndex, this.sourceStartedAt,
        this.url, phase, code, failureInfo);
    } catch (_) { PinmonyRuntimeLog.warn('ImageLoadTrace: diagnostics-unavailable'); }
  }
  @Builder
  private imageBody(generation: number) {
      if (this.canRenderImage()) {
        Image(this.bitmap || this.url).width('100%').height('100%').objectFit(this.fit)
          .onAppear(() => { if (this.visible && generation === this.generation) this.auditImage('node-mounted'); })
          .onComplete((event) => {
            if (!this.visible || generation !== this.generation) return;
            if (event?.loadingStatus === 0) this.auditImage('native-data-ready');
            if (event?.loadingStatus === 1) this.auditImage('native-decoded');
            if (event?.loadingStatus === 0) this.queueImageEvent(generation, 0);
            if (event?.loadingStatus === 1) this.queueImageEvent(generation, 1);
          })
          .onError((event) => {
            if (!this.visible || generation !== this.generation) return;
            this.auditImage('native-failed', event?.error?.code || 0, event?.downloadInfo);
            this.queueImageEvent(generation, -1, event?.error?.code || 0);
          })
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
