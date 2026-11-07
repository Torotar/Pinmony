import { PinmonyI18n } from 'common_foundation';
import { display } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { PinmonyJpegDecode, PinmonyJpegLease, acceptsSoftwareJpeg } from 'common_network';

/** A Pinterest image candidate keyed by the size name returned by Pinterest. */
export interface PinImageSource {
  url: string;
}

export type PinImageSources = Record<string, PinImageSource>;

// These values already belong to the detail recommendation layout. Keeping them
// here lets the width helper and the page use the same layout contract.
export const RECOMMEND_HORIZONTAL_PADDING_VP: number = 18;
export const RECOMMEND_PHONE_GAP_VP: number = 12;
export const RECOMMEND_WIDE_GAP_VP: number = 16;
export const RECOMMEND_WIDE_THRESHOLD_VP: number = 600;
export const RECOMMEND_CARD_RADIUS_VP: number = 18;

interface ImageTier {
  key: string;
  width: number;
}

const FINITE_COVER_TIERS: ImageTier[] = [
  { key: '170x', width: 170 },
  { key: '236x', width: 236 },
  { key: '474x', width: 474 },
  { key: '564x', width: 564 },
  { key: '736x', width: 736 }
];

function currentDensityPixels(): number {
  try {
    const value: number = Number(display.getDefaultDisplaySync().densityPixels);
    return value > 0 && isFinite(value) ? value : 1;
  } catch (_) {
    return 1;
  }
}

function validImageUrl(images: PinImageSources | undefined, key: string): string {
  if (!images) return '';
  const candidate: PinImageSource | undefined = images[key];
  if (!candidate || typeof candidate.url !== 'string' || candidate.url.trim().length === 0) return '';
  return candidate.url.trim();
}

function validImageTier(images: PinImageSources | undefined, key: string): boolean {
  return validImageUrl(images, key).length > 0;
}

/**
 * Returns the recommendation card width in vp.
 *
 * 1. Read the current physical display width and density from the system.
 * 2. Convert the physical width to vp, so the breakpoint is independent of
 *    the device density.
 * 3. Use the existing detail layout's 18vp side padding and its 12vp/16vp
 *    column gap. Phones remain two columns; widths above 600vp use three.
 * 4. Subtract the occupied padding and gaps before dividing by the column
 *    count. The display is queried on every call, so rotation and fold state
 *    changes are reflected after the page re-renders.
 */
export function getRecommendCardWidth(): number {
  try {
    const currentDisplay = display.getDefaultDisplaySync();
    const density: number = Number(currentDisplay.densityPixels);
    const widthPx: number = Number(currentDisplay.width);
    if (!(density > 0) || !(widthPx > 0) || !isFinite(density) || !isFinite(widthPx)) return 0;
    const screenWidthVp: number = widthPx / density;
    const columnCount: number = screenWidthVp > RECOMMEND_WIDE_THRESHOLD_VP ? 3 : 2;
    const columnGapVp: number = columnCount === 3 ? RECOMMEND_WIDE_GAP_VP : RECOMMEND_PHONE_GAP_VP;
    const availableWidthVp: number = screenWidthVp - RECOMMEND_HORIZONTAL_PADDING_VP * 2 -
      columnGapVp * (columnCount - 1);
    return Math.max(0, availableWidthVp / columnCount);
  } catch (_) {
    return 0;
  }
}

/** Returns the same two/three-column decision used by getRecommendCardWidth. */
export function getRecommendColumnCount(): number {
  try {
    const currentDisplay = display.getDefaultDisplaySync();
    const density: number = Number(currentDisplay.densityPixels);
    const widthPx: number = Number(currentDisplay.width);
    if (!(density > 0) || !(widthPx > 0) || !isFinite(density) || !isFinite(widthPx)) return 2;
    return widthPx / density > RECOMMEND_WIDE_THRESHOLD_VP ? 3 : 2;
  } catch (_) {
    return 2;
  }
}

/**
 * Chooses the smallest Pinterest Cover source that is at least as wide as the
 * rendered card.
 *
 * 1. Convert the card width from vp to physical pixels with the current
 *    display density.
 * 2. Check finite Pinterest tiers from small to large, which minimizes decode
 *    work while still avoiding an undersized Cover source.
 * 3. Use orig (conceptually Infinity wide) only when no finite tier qualifies.
 * 4. If orig is absent, return the largest valid finite tier; if no candidate
 *    is valid, return an empty string so the caller can show its error state.
 */
export function pickCoverImageUrl(images: PinImageSources | undefined, cardWidthVp: number): string {
  return validImageUrl(images, pickCoverImageTier(images, cardWidthVp));
}

/** Returns the selected source key for diagnostics without exposing a URL. */
export function pickCoverImageTier(images: PinImageSources | undefined, cardWidthVp: number,
  requestedTargetPx: number = 0): string {
  const targetPx: number = Number.isFinite(requestedTargetPx) && requestedTargetPx > 0 ?
    requestedTargetPx : Math.max(0, cardWidthVp) * currentDensityPixels();
  let largestKey: string = '';
  let largestWidth: number = -1;
  for (const tier of FINITE_COVER_TIERS) {
    if (!validImageTier(images, tier.key)) continue;
    if (tier.width > largestWidth) {
      largestWidth = tier.width;
      largestKey = tier.key;
    }
    if (tier.width >= targetPx) return tier.key;
  }
  if (validImageTier(images, 'orig')) return 'orig';
  return largestKey;
}

// Use only an existing smaller rendition, once, after Image reports a final
// failure. Hardware warnings followed by a successful decode never enter here.
function pickCoverRecoveryTier(images: PinImageSources, currentTier: string, failedUrl: string): string {
  const current: ImageTier | undefined = FINITE_COVER_TIERS.find((tier: ImageTier): boolean => tier.key === currentTier);
  if (!current && currentTier !== 'orig') return '';
  const limit: number = current ? current.width : Number.POSITIVE_INFINITY;
  for (let index: number = FINITE_COVER_TIERS.length - 1; index >= 0; index--) {
    const tier: ImageTier = FINITE_COVER_TIERS[index];
    const candidate: string = validImageUrl(images, tier.key);
    if (tier.width < limit && candidate.length > 0 && candidate !== failedUrl) return tier.key;
  }
  return '';
}

export interface SmartImageOptions {
  url?: string;
  images?: PinImageSources;
  widthVp: number;
  heightVp: number;
  targetPx: number;
  borderRadiusVp?: number;
  onLoaded?: () => void;
  onError?: (code: number) => void;
}

@Component
export struct SmartImage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('resetImage') url: string = '';
  @Prop @Watch('decodeModeChanged') useSharedDecode: boolean = true;
  @Prop @Watch('resetImage') images: PinImageSources = {};
  @Prop @Watch('resetImage') widthVp: number = 0;
  @Prop heightVp: number = 0;
  @Prop @Watch('resetImage') targetPx: number = 0;
  @Prop borderRadiusVp: number = RECOMMEND_CARD_RADIUS_VP;
  @Prop @Watch('loadingChanged') loadingActive: boolean = true;
  @Prop @Watch('loadingChanged') viewportOnly: boolean = false;
  @Prop loadPriority: number = 1;
  private inViewport: boolean = false;
  @State private loadAllowed: boolean = true;
  @State private nativeSourceAdmitted: boolean = false;
  onLoaded?: () => void;
  onError?: (code: number) => void;
  onAudit?: (tier: string, targetPx: number, sourceHeightPx: number) => void;
  onTrace?: (event: string, revision: number, tier: string, elapsedMs: number) => void;
  @State private phase: string = 'loading';
  @State private sourceUrl: string = '';
  @State private sourceTier: string = '';
  @State private imageRevision: number = 0;
  private imageVisible: boolean = false;
  private imageStartedAt: number = 0;
  private requestedSourceUrl: string = '';
  private recoveryAttempted: boolean = false;
  @State private decodedBitmap: image.PixelMap | undefined = undefined;
  @State private softwarePending: boolean = false;
  private decodeLease: PinmonyJpegLease | undefined = undefined;
  private softwareAttemptedRevision: number = -1;

  aboutToAppear(): void {
    this.imageVisible = true;
    this.resetImage();
  }

  aboutToDisappear(): void {
    this.imageVisible = false;
    this.releaseDecode();
    this.softwareAttemptedRevision = -1;
  }

  private releaseDecode(): void {
    this.nativeSourceAdmitted = false;
    this.decodedBitmap = undefined;
    this.decodeLease?.release();
    this.decodeLease = undefined;
    this.softwarePending = false;
  }

  private decodeModeChanged(): void {
    if (!this.imageVisible) return;
    this.releaseDecode();
    this.softwareAttemptedRevision = -1;
    this.imageRevision++;
    this.loadDecodedImage();
  }

  private loadDecodedImage(): void {
    if (!this.imageVisible || this.softwareAttemptedRevision === this.imageRevision) return;
    this.loadAllowed = this.loadingActive !== false && (this.viewportOnly !== true || this.inViewport);
    this.releaseDecode();
    this.softwareAttemptedRevision = this.imageRevision;
    this.nativeSourceAdmitted = this.useSharedDecode === false && this.loadAllowed;
    if (this.useSharedDecode === false || !acceptsSoftwareJpeg(this.sourceUrl)) return;
    const revision: number = this.imageRevision;
    const lease: PinmonyJpegLease = PinmonyJpegDecode.acquire(this.sourceUrl, this.loadAllowed, this.loadPriority ?? 1);
    this.decodeLease = lease;
    if (lease.taskId > 0) this.traceImage('pipeline-task-' + lease.taskId.toString());
    this.decodedBitmap = lease.bitmap;
    this.softwarePending = !this.decodedBitmap;
    lease.ready.then((bitmap: image.PixelMap): void => {
      if (!this.imageVisible || revision !== this.imageRevision || this.decodeLease !== lease) return;
      this.decodedBitmap = bitmap;
      this.softwarePending = false;
      this.traceImage('software-ready');
    }).catch((): void => {
      if (!this.imageVisible || revision !== this.imageRevision || this.decodeLease !== lease) return;
      this.releaseDecode();
      // A failed download or unsupported payload still uses the existing native
      // Image error/recovery path. Never issue an unbounded same-URL retry loop.
      this.traceImage('native-fallback');
    });
  }

  private loadingChanged(): void {
    this.loadAllowed = this.loadingActive !== false && (this.viewportOnly !== true || this.inViewport);
    if (this.imageVisible && this.useSharedDecode === false && this.loadAllowed) this.nativeSourceAdmitted = true;
    this.decodeLease?.setActive?.(this.imageVisible && this.loadAllowed);
  }
  private canRenderImage(): boolean {
    return this.sourceUrl.length > 0 && !this.softwarePending &&
      (this.loadAllowed || this.nativeSourceAdmitted || !!this.decodedBitmap);
  }

  private resetImage(): void {
    // The owner already supplies the window's pixel target. Reuse it rather
    // than doing synchronous display queries while lazy cards are created.
    const target: number = Number.isFinite(this.targetPx) && this.targetPx > 0 ? this.targetPx : 0;
    const nextTier: string = pickCoverImageTier(this.images, this.widthVp, target);
    const nextUrl: string = validImageUrl(this.images, nextTier) || this.url;
    // Snapshot object identity and layout updates do not invalidate a decoded source.
    if (this.imageRevision > 0 && nextUrl === this.requestedSourceUrl) {
      if (this.imageVisible && !this.decodeLease && this.phase !== 'failed') this.loadDecodedImage();
      return;
    }
    this.requestedSourceUrl = nextUrl;
    this.recoveryAttempted = false;
    this.imageRevision++;
    this.imageStartedAt = Date.now();
    this.phase = 'loading';
    this.sourceTier = nextTier;
    this.sourceUrl = nextUrl;
    this.loadDecodedImage();
    if (this.sourceTier.length === 0 && this.sourceUrl.length > 0) this.sourceTier = 'fallback';
    if (this.onAudit && this.sourceUrl.length > 0) {
      this.onAudit(this.sourceTier, target || this.widthVp * currentDensityPixels(), this.displayHeightPx());
    }
  }

  private traceImage(event: string): void {
    if (this.onTrace) this.onTrace(event, this.imageRevision, this.sourceTier,
      Math.max(0, Date.now() - this.imageStartedAt));
  }

  private completeImage(revision: number, status: number): void {
    if (!this.imageVisible || revision !== this.imageRevision || status !== 1 || this.phase === 'loaded') return;
    this.phase = 'loaded';
    this.traceImage('decoded');
    if (this.onLoaded) this.onLoaded();
  }

  private failImage(revision: number, code: number): void {
    if (!this.imageVisible || revision !== this.imageRevision || this.phase === 'loaded' || this.phase === 'failed') return;
    const recoveryTier: string = this.recoveryAttempted ? '' : pickCoverRecoveryTier(this.images, this.sourceTier, this.sourceUrl);
    if (recoveryTier.length > 0) {
      this.recoveryAttempted = true;
      this.imageRevision++;
      this.sourceTier = recoveryTier;
      this.sourceUrl = validImageUrl(this.images, recoveryTier);
      this.loadDecodedImage();
      this.traceImage('fallback');
      return;
    }
    this.phase = 'failed';
    this.traceImage('failed');
    if (this.onError) this.onError(Number.isFinite(code) ? code : 0);
  }

  private displayHeightPx(): number {
    const density: number = this.widthVp > 0 && Number.isFinite(this.targetPx) && this.targetPx > 0 ?
      this.targetPx / this.widthVp : currentDensityPixels();
    return Math.max(1, this.heightVp * density);
  }

  @Builder
  private imageBody(revision: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.canRenderImage()) {
        Image(this.decodedBitmap || this.sourceUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          // The finite source tier already bounds decoding. A card-sized
          // sourceSize stretches the decoded bitmap before Cover can crop it.
          .opacity(this.phase === 'loaded' ? 1 : 0)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .onComplete((event) => this.completeImage(revision, event?.loadingStatus ?? -1))
          .onError((event) => this.failImage(revision, event?.error?.code || 0))
      }
      if (this.phase === 'failed') {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(24)
          .fontColor([$r('app.color.secondary_text')])
          .accessibilityText(this.uiText("pm_image_failed_to_load_572993f5"))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F0F0')
    .borderRadius(this.borderRadiusVp)
    .clip(true)
    .onVisibleAreaChange([0, 0.01], (visible: boolean, ratio: number) => {
      this.inViewport = visible && ratio > 0;
      this.loadingChanged();
    })
  }

  build() {
    ForEach([this.imageRevision], (revision: number) => {
      this.imageBody(revision);
    }, (revision: number) => revision.toString())
  }
}
