import { display } from '@kit.ArkUI';

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
export function pickCoverImageTier(images: PinImageSources | undefined, cardWidthVp: number): string {
  const targetPx: number = Math.max(0, cardWidthVp) * currentDensityPixels();
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

export interface SmartImageOptions {
  url?: string;
  images?: PinImageSources;
  widthVp: number;
  heightVp: number;
  targetPx: number;
  borderRadiusVp?: number;
  onLoaded?: () => void;
  onError?: () => void;
}

@Component
export struct SmartImage {
  @Prop @Watch('resetImage') url: string = '';
  @Prop @Watch('resetImage') images: PinImageSources = {};
  @Prop widthVp: number = 0;
  @Prop heightVp: number = 0;
  @Prop targetPx: number = 0;
  @Prop borderRadiusVp: number = RECOMMEND_CARD_RADIUS_VP;
  onLoaded?: () => void;
  onError?: () => void;
  onAudit?: (tier: string, targetPx: number, sourceHeightPx: number) => void;
  @State private phase: string = 'loading';
  @State private sourceUrl: string = '';
  @State private sourceTier: string = '';

  aboutToAppear(): void {
    this.resetImage();
  }

  private resetImage(): void {
    this.phase = 'loading';
    this.sourceTier = pickCoverImageTier(this.images, this.widthVp);
    this.sourceUrl = pickCoverImageUrl(this.images, this.widthVp) || this.url;
    if (this.sourceTier.length === 0 && this.sourceUrl.length > 0) this.sourceTier = 'fallback';
    if (this.onAudit && this.sourceUrl.length > 0) {
      this.onAudit(this.sourceTier, this.widthVp * currentDensityPixels(), this.displayHeightPx());
    }
  }

  private displayHeightPx(): number {
    return Math.max(1, this.heightVp * currentDensityPixels());
  }

  @Builder
  private imageBody() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.sourceUrl.length > 0) {
        Image(this.sourceUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          // The finite source tier already bounds decoding. A card-sized
          // sourceSize stretches the decoded bitmap before Cover can crop it.
          .opacity(this.phase === 'loaded' ? 1 : 0)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .onComplete(() => {
            this.phase = 'loaded';
            if (this.onLoaded) this.onLoaded();
          })
          .onError(() => {
            this.phase = 'failed';
            if (this.onError) this.onError();
          })
      }
      if (this.phase === 'failed') {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(24)
          .fontColor([$r('app.color.secondary_text')])
          .accessibilityText('图片加载失败')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F0F0')
    .borderRadius(this.borderRadiusVp)
    .clip(true)
  }

  build() {
    this.imageBody();
  }
}
