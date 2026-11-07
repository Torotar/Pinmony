import { PinmonyHdsTitleBar } from 'common_ui';
import { PinmonyCdnImage } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyImageSearchSelection } from 'common_ui';
import { ImageFlightRect, imageContainRect } from '../services/PinmonyImageTransition';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyImageViewer } from './PinmonyImageViewer';
import { PinmonyShuffleCanvas } from './PinmonyShuffleCanvas';
import { PinmonyShuffleHitMasks } from '../services/PinmonyShuffleHitMasks';
import { PinmonyShuffleItem } from '../models/PinmonyShuffle';
import { splitDescriptionTags, PinmonyDescriptionPart } from '../services/PinmonyDescriptionTags';
import { PinmonyVisualSearchView } from './PinmonyVisualSearchView';
import { PinmonyImageCrop, PinmonyVisualResult, emptyVisualResult } from '../models/PinmonyVisualSearch';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyDetailAction, PinmonyDetailSnapshot, PinmonyRelatedPin, PinmonyRelatedTopic, PinmonyCarouselItem } from '../models/PinmonyDetail';
import { PinmonyCarouselView } from './PinmonyCarouselView';
import { PinmonyVideoPlayer } from './PinmonyVideoPlayer';
import { PinmonyDetailHero, DetailHeroSource } from './PinmonyDetailHero';
import { PinmonyDetailEntryPhoto } from '../services/PinmonyImageTransition';
import { PinmonyDetailEntryMotion } from './PinmonyDetailEntryMotion';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { SmartImage, getRecommendCardWidth, getRecommendColumnCount, RECOMMEND_CARD_RADIUS_VP,
  RECOMMEND_PHONE_GAP_VP, RECOMMEND_WIDE_GAP_VP } from 'common_ui';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';

interface PinmonyDetailFlowRow {
  key: string;
  kind: string;
  pin?: PinmonyRelatedPin;
  fingerprint: string;
}

class PinmonyDetailFlowSource implements IDataSource {
  private readonly trace: ((message: string) => void) | undefined;
  constructor(trace: ((message: string) => void) | undefined = undefined) { this.trace = trace; }
  private generation: number = 0;
  private keyTraceCount: number = 0;
  private rows: PinmonyDetailFlowRow[] = [];
  private listeners: DataChangeListener[] = [];
  totalCount(): number { return this.rows.length; }
  getData(index: number): PinmonyDetailFlowRow { return this.rows[index]; }
  renderKey(row: PinmonyDetailFlowRow, index: number): string {
    if (this.trace && this.keyTraceCount < 16) {
      this.keyTraceCount++;
      this.trace('phase=key generation=' + this.generation.toString() + ' index=' + index.toString() +
        ' total=' + this.rows.length.toString() + ' matches=' + (this.rows[index]?.key === row.key).toString() +
        ' firstIndex=' + this.rows.findIndex((item: PinmonyDetailFlowRow): boolean => item.key === row.key).toString());
    }
    return row.key;
  }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener);
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) this.listeners.splice(index, 1);
  }
  update(rows: PinmonyDetailFlowRow[]): void {
    const previous: PinmonyDetailFlowRow[] = this.rows;
    if (previous.length === rows.length && previous.every((row: PinmonyDetailFlowRow, index: number): boolean =>
      row.key === rows[index].key && row.fingerprint === rows[index].fingerprint)) {
      this.rows = rows;
      return;
    }
    this.generation++;
    this.keyTraceCount = 0;
    let prefix: number = 0;
    while (prefix < previous.length && prefix < rows.length && previous[prefix].key === rows[prefix].key) prefix++;
    let suffix: number = 0;
    while (suffix < previous.length - prefix && suffix < rows.length - prefix &&
      previous[previous.length - 1 - suffix].key === rows[rows.length - 1 - suffix].key) suffix++;
    if (this.trace) this.trace('phase=update generation=' + this.generation.toString() +
      ' previous=' + previous.length.toString() + ' total=' + rows.length.toString() +
      ' prefix=' + prefix.toString() + ' suffix=' + suffix.toString() +
      ' listeners=' + this.listeners.length.toString());
    // One LazyForEach must use a single notification family for its lifetime.
    // Capability detection cannot make onDatasetChange safe after legacy calls.
    // Keep the legacy family for inserts, removals, content changes and reloads;
    // each callback below observes the corresponding intermediate snapshot.
    if (prefix + suffix === previous.length && rows.length > previous.length) {
      this.rows = previous.slice();
      for (let i: number = prefix; i < rows.length - suffix; i++) {
        this.rows.splice(i, 0, rows[i]);
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataAdd(i));
      }
    } else if (prefix + suffix === rows.length && previous.length > rows.length) {
      this.rows = previous.slice();
      for (let i: number = previous.length - suffix - 1; i >= prefix; i--) {
        this.rows.splice(i, 1);
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataDelete(i));
      }
    } else if (prefix !== previous.length || prefix !== rows.length) {
      this.rows = rows;
      this.listeners.forEach((listener: DataChangeListener): void => listener.onDataReloaded());
      return;
    }
    this.rows = rows;
    for (let i: number = 0; i < prefix; i++) {
      if (previous[i].fingerprint !== rows[i].fingerprint) this.listeners.forEach((listener: DataChangeListener): void => listener.onDataChange(i));
    }
    for (let i: number = 0; i < suffix; i++) {
      const nextIndex: number = rows.length - suffix + i;
      if (previous[previous.length - suffix + i].fingerprint !== rows[nextIndex].fingerprint)
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataChange(nextIndex));
    }
  }
}

@Component
export struct PinmonyDetailPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('onPinChanged') currentDetail: PinmonyDetailSnapshot = {} as PinmonyDetailSnapshot;
  @Prop shuffleParentDetail: PinmonyDetailSnapshot | undefined = undefined;
  private fallbackDetail(): PinmonyDetailSnapshot {
    return { kind: 'loading', session: 0, pinUrl: '', imageUrl: '', imageWidth: 0, imageHeight: 0,
      title: '', description: '', creator: '', creatorAvatar: '', sourceLabel: '', actions: [], related: [] };
  }
  private displayedDetail(): PinmonyDetailSnapshot {
    const current: PinmonyDetailSnapshot | undefined = this.currentDetail;
    if (this.shuffleParentDetail && !this.shuffleFullDetail &&
      (!current || current.pinUrl !== this.shuffleParentDetail.pinUrl || !current.shuffle)) return this.shuffleParentDetail;
    return current || this.shuffleParentDetail || this.fallbackDetail();
  }
  @Prop @Watch('onRenderIdentityChanged') renderIdentity: string = '';
  @Prop traceId: number = 0;
  @Prop entryPhoto: PinmonyDetailEntryPhoto | undefined = undefined;
  @Prop entryResumed: boolean = false;
  @Prop entryClosing: boolean = false;
  @Prop disableImageZoom: boolean = false;
  @Prop @Watch('onShuffleSelectionChanged') shuffleSelectedImage: string = '';
  @Prop shuffleBackdrop: string = '';
  @Prop shuffleItems: PinmonyShuffleItem[] = [];
  @Prop shuffleIndex: number = 0;
  @Prop @Watch('onPinChanged') shuffleFullDetail: boolean = false;
  @Prop @Watch('onShuffleSelectionChanged') shuffleReturnItem: string = '';
  @State private shuffleReadyImages: string[] = [];
  @State private shuffleReadyBackdrop: string = '';
  @State @Watch('onShuffleViewerPresentedChanged') private shuffleViewerPresented: boolean = false;
  @State private shuffleFlightActive: boolean = false;
  @State private shuffleFlightClosing: boolean = false;
  @State private shuffleFlightPreparing: boolean = false;
  @State private shuffleBackdropOpacity: number = 0;
  @State private shuffleFlightFrame: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  @State private shuffleFlightRotation: number = 0;
  @State private shuffleFlightScale: number = 1;
  @State private shuffleFlightRadius: number = 0;
  @State private shuffleFlightImage: string = '';
  @State private shufflePressedItem: string = '';
  @State private shufflePressScale: number = 1;
  private shuffleFlightSource: ImageFlightRect | undefined = undefined;
  private shuffleFlightSourceRotation: number = 0;
  private shuffleFlightTarget: ImageFlightRect | undefined = undefined;
  private shuffleFlightTargetRotation: number = 0;
  @State private shuffleFlightStarted: boolean = false;
  private shuffleFlightQueued: boolean = false;
  private shuffleLayoutAttempts: number = 0;
  private shuffleOverlayVisible(): boolean {
    return this.shuffleFlightActive || this.shuffleViewerVisible() && !this.shuffleFlightPreparing;
  }
  private shuffleFlightItem: string = '';
  private shuffleFlightRevision: number = 0;
  private shuffleFlightTimer: number = -1;
  private shuffleSourceOnCanvas: boolean = false;

  private shufflePhotoUrl(item: PinmonyShuffleItem): string {
    return item.cutoutUrl || item.imageUrl || '';
  }

  private shuffleRect(componentId: string): ImageFlightRect | undefined {
    try {
      const ui = this.getUIContext();
      const source = ui.getComponentUtils().getRectangleById(componentId);
      const root = ui.getComponentUtils().getRectangleById('pinmony-photo-root-' + this.traceId);
      if (source.size.width <= 0 || source.size.height <= 0) return undefined;
      return { x: ui.px2vp(source.windowOffset.x - root.windowOffset.x),
        y: ui.px2vp(source.windowOffset.y - root.windowOffset.y),
        width: ui.px2vp(source.size.width), height: ui.px2vp(source.size.height) };
    } catch (_) { return undefined; }
  }

  private shuffleItemOrigin(item: PinmonyShuffleItem, canvas: boolean): ImageFlightRect | undefined {
    this.shuffleFlightSourceRotation = 0;
    // Both endpoints use the stable outer page root; HDS stays laid out underneath.
    if (!canvas) {
      const thumbnail: ImageFlightRect | undefined = this.shuffleRect('pinmony-shuffle-thumbnail-' + this.traceId + '-' + item.id);
      if (!thumbnail) return undefined;
      if (item.cutoutUrl && item.cutoutBounds && item.imageWidth > 0 && item.imageHeight > 0) {
        // Match the original thumbnail's Cover transform before extracting the
        // subject. Fitting a tight cutout into the whole frame enlarges it.
        const scale: number = Math.max(thumbnail.width / item.imageWidth, thumbnail.height / item.imageHeight);
        const fullWidth: number = item.imageWidth * scale;
        const fullHeight: number = item.imageHeight * scale;
        return { x: thumbnail.x + (thumbnail.width - fullWidth) / 2 + item.cutoutBounds.x * fullWidth,
          y: thumbnail.y + (thumbnail.height - fullHeight) / 2 + item.cutoutBounds.y * fullHeight,
          width: item.cutoutBounds.width * fullWidth, height: item.cutoutBounds.height * fullHeight };
      }
      const contained: ImageFlightRect = imageContainRect(thumbnail.width, thumbnail.height,
        item.cutoutUrl ? item.hitWidth || item.imageWidth : item.imageWidth,
        item.cutoutUrl ? item.hitHeight || item.imageHeight : item.imageHeight);
      return { x: thumbnail.x + contained.x, y: thumbnail.y + contained.y,
        width: contained.width, height: contained.height };
    }
    const frame: ImageFlightRect | undefined = this.shuffleRect('pinmony-shuffle-canvas-' + this.traceId);
    const scene = this.displayedDetail().shuffle;
    if (!frame || !scene || scene.canvasWidth <= 0 || scene.canvasHeight <= 0) return undefined;
    const scale: number = Math.min(frame.width / scene.canvasWidth, frame.height / scene.canvasHeight) *
      scene.canvasWidth / (scene.coordinateWidth || scene.canvasWidth);
    const width: number = (item.hitWidth ?? item.imageWidth) * item.scale * scale;
    const height: number = (item.hitHeight ?? item.imageHeight) * item.scale * scale;
    this.shuffleFlightSourceRotation = item.rotation;
    const origin: ImageFlightRect = { x: frame.x + frame.width / 2 + item.offsetX * scale - width / 2,
      y: frame.y + frame.height / 2 + item.offsetY * scale - height / 2, width, height };
    return origin;
  }

  private openShuffleItem(itemId: string, canvas: boolean): void {
    if (!this.videoActive || !this.readsReady || this.shuffleFlightActive || this.shuffleFlightPreparing || this.shuffleSelectedImage) return;
    const item: PinmonyShuffleItem | undefined = this.displayedDetail().shuffle?.items.find((entry: PinmonyShuffleItem): boolean => entry.id === itemId);
    if (!item || !item.tappable) return;
    this.shuffleFlightRevision++;
    this.shuffleLayoutAttempts = 0;
    this.shuffleBackdropOpacity = 0;
    this.shuffleReadyBackdrop = '';
    this.shuffleFlightItem = itemId;
    this.shuffleSourceOnCanvas = canvas;
    this.shuffleFlightImage = this.shufflePhotoUrl(item);
    this.shuffleFlightSource = this.shuffleItemOrigin(item, canvas);
    this.shuffleFlightPreparing = !!this.shuffleFlightSource;
    this.onShufflePin?.(itemId);
  }

  private onShuffleViewerPresentedChanged(): void {
    clearTimeout(this.shuffleFlightTimer);
    if (!this.shuffleViewerPresented || this.shuffleFlightActive) return;
    if (!this.shuffleFlightSource) {
      this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
        this.shuffleBackdropOpacity = 1;
      });
      return;
    }
    const revision: number = ++this.shuffleFlightRevision;
    this.shuffleFlightTimer = setTimeout(() => {
      if (revision !== this.shuffleFlightRevision || !this.shuffleViewerVisible()) return;
      const item: PinmonyShuffleItem | undefined = this.shuffleItems[this.shuffleIndex];
      const frame: ImageFlightRect | undefined = item ? this.shuffleRect('pinmony-shuffle-photo-' + this.traceId + '-' + item.id) : undefined;
      if (!item || item.id !== this.shuffleFlightItem || !this.shuffleFlightSource) return;
      if (!frame) {
        if (++this.shuffleLayoutAttempts < 12) this.onShuffleViewerPresentedChanged();
        else { this.shuffleFlightPreparing = false; this.shuffleFlightSource = undefined;
          this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseOut }, () => { this.shuffleBackdropOpacity = 1; }); }
        return;
      }
      this.shuffleFlightImage = this.shufflePhotoUrl(item) || this.shuffleFlightImage;
      const contained: ImageFlightRect = imageContainRect(frame.width, frame.height,
        item.cutoutUrl ? item.hitWidth || item.imageWidth : item.imageWidth,
        item.cutoutUrl ? item.hitHeight || item.imageHeight : item.imageHeight);
      const target: ImageFlightRect = { x: frame.x + contained.x, y: frame.y + contained.y, width: contained.width, height: contained.height };
      this.shuffleFlightFrame = this.shuffleFlightSource;
      this.shuffleFlightRadius = this.shuffleSourceOnCanvas ? 0 : 12;
      this.shuffleFlightRotation = this.shuffleFlightSourceRotation;
      this.shuffleFlightScale = 1;
      this.shuffleFlightTarget = target;
      this.shuffleFlightTargetRotation = 0;
      this.shuffleFlightStarted = false;
      this.shuffleFlightQueued = false;
      this.shuffleFlightActive = true;
      this.shuffleFlightPreparing = false;
      this.shuffleFlightClosing = false;
    // Keep the viewer hidden while its layout is measured.
    }, 32);
  }

  private queueShuffleFlight(): void {
    if (!this.shuffleFlightActive || this.shuffleFlightStarted || this.shuffleFlightQueued) return;
    this.shuffleFlightQueued = true;
    const revision: number = this.shuffleFlightRevision;
    // Commit the measured source frame before animateTo records its destination.
    this.shuffleFlightTimer = setTimeout(() => {
      if (revision !== this.shuffleFlightRevision) return;
      this.shuffleFlightQueued = false;
      this.startShuffleFlight();
    }, 32);
  }

  private shuffleFlightImageComplete(status: number): void {
    // Data-ready (0) is earlier than a drawable image. Keep the viewer underneath
    // until this new Image has rendered (1) and committed its source frame.
    if (status === 1) this.queueShuffleFlight();
  }

  private shuffleViewerContentVisible(): boolean {
    return this.shuffleViewerVisible() && !this.shuffleFlightPreparing &&
      (!this.shuffleFlightActive || this.shuffleFlightClosing && !this.shuffleFlightStarted);
  }

  private shufflePageOpacity(itemId: string): number {
    if (itemId === this.shuffleItems[this.shuffleIndex]?.id) return this.shuffleViewerContentVisible() ? 1 : 0;
    return this.shuffleBackdropOpacity;
  }

  private startShuffleFlight(): void {
    if (!this.shuffleFlightActive || this.shuffleFlightStarted || !this.shuffleFlightTarget) return;
    this.shuffleFlightStarted = true;
    const revision: number = this.shuffleFlightRevision;
    const closing: boolean = this.shuffleFlightClosing;
    const target: ImageFlightRect = this.shuffleFlightTarget;
    this.getUIContext().animateTo({ duration: closing ? 280 : 320, curve: Curve.EaseInOut, onFinish: () => {
      if (revision !== this.shuffleFlightRevision) return;
      this.shuffleFlightActive = false;
      this.shuffleFlightClosing = false;
      // Retain the exact artwork until the flight node is removed. Replacing
      // its source in the completion frame can briefly render the cutout.
      if (closing) { this.shuffleViewerPresented = false; this.onBack?.(); }
    } }, () => {
      this.shuffleFlightFrame = target; this.shuffleFlightRotation = this.shuffleFlightTargetRotation;
      this.shuffleFlightScale = 1;
      this.shuffleFlightRadius = closing && !this.shuffleSourceOnCanvas ? 12 : 0;
      this.shuffleBackdropOpacity = closing ? 0 : 1;
    });
  }

  private failShuffleFlight(): void {
    if (!this.shuffleFlightActive) return;
    const closing: boolean = this.shuffleFlightClosing;
    this.shuffleFlightRevision++;
    this.shuffleFlightActive = false;
    this.shuffleFlightClosing = false;
    this.shuffleFlightImage = '';
    this.shuffleBackdropOpacity = closing ? 0 : 1;
    if (closing) { this.shuffleViewerPresented = false; this.onBack?.(); }
  }

  private shufflePress(itemId: string, pressed: boolean): void {
    if (!this.videoActive || !this.readsReady || this.shuffleFlightActive) return;
    this.shufflePressedItem = itemId;
    this.getUIContext().animateTo({ duration: pressed ? 80 : 180, curve: Curve.EaseOut }, () => {
      this.shufflePressScale = pressed ? 0.94 : 1;
    });
  }
  private onShuffleSelectionChanged(): void {
    if (this.shuffleSelectedImage) {
      this.shuffleRevealedKey = '';
      return;
    }
    if (!this.shuffleSelectedImage) {
      clearTimeout(this.shuffleFlightTimer);
      if (!this.shuffleFlightActive) this.shuffleFlightRevision++;
      if (!this.shuffleFlightActive) this.shuffleFlightImage = '';
      if (!this.shuffleFlightActive) this.shuffleFlightClosing = false;
      this.shuffleViewerPresented = false;
      this.shuffleFlightPreparing = false;
      this.shuffleBackdropOpacity = 0;
      setTimeout(() => this.revealShuffleReturn(),0);
    }
  }
  private shuffleViewerVisible(): boolean {
    return !!this.shuffleSelectedImage && !this.shuffleFullDetail && this.shuffleViewerPresented;
  }
  private closeShuffleViewer(itemId: string): void {
    if (!this.videoActive || !this.shuffleViewerVisible() ||
      itemId !== this.shuffleItems[this.shuffleIndex]?.id) return;
    if (this.shuffleFlightActive) return;
    const item: PinmonyShuffleItem | undefined = this.shuffleItems[this.shuffleIndex];
    if (item && this.shuffleFlightSource && this.shuffleFlightItem === itemId) {
      // Reuse the position captured on tap. The detail layer is hidden during close,
      // so re-measuring its thumbnail can resolve to a different layout node.
      const target: ImageFlightRect | undefined = this.shuffleFlightSource;
      const frame: ImageFlightRect | undefined = this.shuffleRect('pinmony-shuffle-photo-' + this.traceId + '-' + itemId);
      if (target && frame) {
        this.shuffleFlightImage = this.shufflePhotoUrl(item);
        const contained: ImageFlightRect = imageContainRect(frame.width, frame.height,
          item.cutoutUrl ? item.hitWidth || item.imageWidth : item.imageWidth,
          item.cutoutUrl ? item.hitHeight || item.imageHeight : item.imageHeight);
        this.shuffleFlightFrame = { x: frame.x + contained.x, y: frame.y + contained.y, width: contained.width, height: contained.height };
        this.shuffleFlightRotation = 0;
        this.shuffleFlightScale = 1;
        this.shuffleFlightRadius = 0;
        this.shuffleFlightRevision++;
        this.shuffleFlightTarget = target;
        this.shuffleFlightTargetRotation = this.shuffleFlightSourceRotation;
        this.shuffleFlightStarted = false;
        this.shuffleFlightQueued = false;
        this.shuffleFlightActive = true;
        this.shuffleFlightClosing = true;
        return;
      }
    }
    // Retained hidden image nodes must never invoke the detail page's back action.
    this.shuffleViewerPresented = false;
    this.onBack?.();
  }
  private shuffleImageReady(key: string): void {
    if (!this.shuffleReadyImages.includes(key)) this.shuffleReadyImages = this.shuffleReadyImages.concat(key).slice(-64);
    const item: PinmonyShuffleItem | undefined = this.shuffleItems[this.shuffleIndex];
    if (this.shuffleSelectedImage && item && this.shuffleReadyBackdrop === (this.shuffleBackdrop || this.displayedDetail().imageUrl) &&
        this.shuffleReadyImages.includes('photo:' + this.shufflePhotoUrl(item)) &&
        this.shuffleReadyImages.includes('card:' + (item.imageUrl || ''))) this.shuffleViewerPresented = true;
  }
  private readonly shuffleStripScroller: Scroller = new Scroller();
  private readonly shuffleHitMasks: PinmonyShuffleHitMasks = new PinmonyShuffleHitMasks();
  private shuffleRevealedKey: string = '';
  @Prop shufflePreviews: PinmonyDetailSnapshot[] = [];
  onShufflePin?: (id: string) => void;
  onShuffleDetail?: (pin: string) => void;
  onShuffleRetry?: () => void;
  onEntryClosed?: () => void;
  @State private entryOpacity: number = 1;
  @State private entryScale: number = 1;
  @State private entryPhotoHidden: boolean = false;
  @State private entryMotionComplete: boolean = false;
  @Prop @Watch('updateDetailLayout') actionsReady: boolean = true;
  @Prop postActionsReady: boolean = false;
  @Prop shareActionsReady: boolean = false;
  @Prop likeBlocked: boolean = false;
  @Prop menuActionsReady: boolean = false;
  @Prop commentActionsReady: boolean = false;
  @Prop auxiliaryReady: boolean = false;
  @Prop readsReady: boolean = false;
  @Prop deferredActions: boolean = false;
  @Prop saveBusy: boolean = false;
  @Prop mediaReadBusy: boolean = false;
  @Prop videoActive: boolean = true;
  @Prop initialScrollOffset: number = 0;
  @Prop @Watch('onImageLayerChanged') imageLayer: string = '';
  @State private viewerControls: boolean = true;
  @State private viewerMounted: boolean = false;
  @State private viewerImageReady: boolean = false;
  @State private viewerClosing: boolean = false;
  @State private viewerOrigin: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  @State private searchMounted: boolean = false;
  @State private searchClosing: boolean = false;
  @State private searchImageReady: boolean = false;
  @State private searchOrigin: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  @State private searchFlightFrame: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  @State private searchFlightBaseWidth: number = 1;
  @State private searchFlightBaseHeight: number = 1;
  @State private searchFlightRadius: number = 18;
  @State private searchPhotoFlying: boolean = false;
  @State private searchFlightChrome: number = 0;
  @State private searchFlightCrop: PinmonyImageCrop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
  private updateSearchFlightFrame(x: number, y: number, width: number, height: number, radius: number, duration: number = 0, chrome: number = 0): void {
    try {
      const ui = this.getUIContext();
      const root = ui.getComponentUtils().getRectangleById('pinmony-photo-root-' + this.traceId.toString());
      const frame: ImageFlightRect = { x: x - ui.px2vp(root.windowOffset.x), y: y - ui.px2vp(root.windowOffset.y),
        width: width, height: height };
      if (duration > 0) {
        ui.animateTo({ duration: duration, curve: Curve.EaseOut }, () => {
          this.searchFlightFrame = frame; this.searchFlightRadius = radius;
          this.searchFlightChrome = chrome;
        });
      } else {
        this.searchFlightBaseWidth = Math.max(1, width);
        this.searchFlightBaseHeight = Math.max(1, height);
        this.searchFlightFrame = frame; this.searchFlightRadius = radius;
        this.searchFlightChrome = chrome;
      }
    } catch (_) {}
  }
  private onImageLayerChanged(): void {
    if (this.imageLayer === 'zoom' && (this.disableImageZoom || !!this.displayedDetail().shuffleId)) {
      this.onImageLayer?.('');
      return;
    }
    this.viewerControls = true;
    if (this.imageLayer === 'search') {
      if (!this.searchMounted) {
        try {
          const ui = this.getUIContext();
          const source = ui.getComponentUtils().getRectangleById('pinmony-photo-source-' + this.traceId.toString());
          this.searchOrigin = { x: ui.px2vp(source.windowOffset.x), y: ui.px2vp(source.windowOffset.y),
            width: ui.px2vp(source.size.width), height: ui.px2vp(source.size.height) };
        } catch (_) { this.searchOrigin = { x: 0, y: 0, width: 0, height: 0 }; }
        this.searchImageReady = false;
      }
      this.searchClosing = false; this.searchMounted = true;
    } else if (this.searchMounted) this.searchClosing = true;
    if (this.imageLayer === 'zoom') {
      if (!this.viewerMounted) this.viewerImageReady = false;
      this.viewerOrigin = this.measureViewerOrigin();
      this.viewerClosing = false; this.viewerMounted = true;
    } else if (this.viewerMounted) {
      this.viewerOrigin = this.prepareViewerReturn();
      this.viewerClosing = true;
    }
  }
  private prepareViewerReturn(): ImageFlightRect {
    const origin: ImageFlightRect = this.measureViewerOrigin();
    if (origin.width <= 0 || origin.height <= 0 || origin.y + origin.height <= 56 || origin.y >= this.viewportHeight) return origin;
    try {
      const position = this.detailScroller.offset();
      if (!position) return origin;
      const offset: number = Math.max(0, position.yOffset);
      if (offset <= 0) return origin;
      // Reset under the opaque viewer; target the post-scroll photo bounds even
      // before the next layout pass updates component measurements.
      this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
      this.lastReportedScrollOffset = 0;
      this.onScrollPosition?.(this.displayedDetail().pinUrl, 0);
      return { x: origin.x, y: origin.y + offset, width: origin.width, height: origin.height };
    } catch (_) { return origin; }
  }
  private measureViewerOrigin(): ImageFlightRect {
    try {
      const ui = this.getUIContext();
      const selectedIndex: number = this.displayedDetail().carousel?.freeScroll ?
        (this.displayedDetail().carousel?.items || []).findIndex((item: PinmonyCarouselItem): boolean => item.imageUrl === this.zoomImageUrl) : -1;
      const source = ui.getComponentUtils().getRectangleById('pinmony-photo-source-' + this.traceId.toString() +
        (selectedIndex >= 0 ? '-' + selectedIndex.toString() : ''));
      const root = ui.getComponentUtils().getRectangleById('pinmony-photo-root-' + this.traceId.toString());
      return { x: ui.px2vp(source.windowOffset.x - root.windowOffset.x),
        y: ui.px2vp(source.windowOffset.y - root.windowOffset.y),
        width: ui.px2vp(source.size.width), height: ui.px2vp(source.size.height) };
    } catch (_) { return { x: 0, y: 0, width: 0, height: 0 }; }
  }
  @Prop visualResult: PinmonyVisualResult = emptyVisualResult();
  @Prop pageActive: boolean = true;
  @State private zoomImageUrl: string = '';
  private productGalleryOffset: number = 0;
  @State private searchLabelVisible: boolean = true;
  private searchLabelTimer: number = -1;
  onImageLayer?: (layer: string) => void;
  onVisualSearch?: (crop: PinmonyImageCrop, append: boolean, first: boolean) => void;
  onVisualResult?: (id: string) => boolean;
  onDownload?: () => void;
  onViewerSave?: () => void;
  onTagSearch?: (query: string, pin: string) => void;
  onTextCopied?: () => void;
  @Prop contentError: string = '';
  @Prop contentRetryable: boolean = true;
  onContentRetry?: () => void;
  onImageLoaded?: (pinUrl: string, imageUrl: string, renderIdentity: string) => void;
  onRelatedImageLoaded?: (pinUrl: string) => void;
  onPresented?: () => void;
  private heroVisible: boolean = false;
  @State private heroRenderRevision: number = 0;
  @State private decodedHeroSource: DetailHeroSource | undefined = undefined;
  @State private textOverflowing: boolean = false;
  @State private videoFailure: string = '';
  @State private videoRetryRevision: number = 0;
  private lastImageNotification: string = '';
  private textMeasureWarned: boolean = false;

  private onRenderIdentityChanged(): void {
    // Session/snapshot changes update presentation without changing the hero source key.
    this.onPinChanged();
  }
  @State private expanded: boolean = false;
  @State private contentWidth: number = 360;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 800;
  private readonly detailScroller: Scroller = new Scroller();
  private readonly detailRows: PinmonyDetailFlowSource = new PinmonyDetailFlowSource((message: string): void => {
    PinmonyRuntimeLog.info('DetailListTrace: openId=' + this.traceId.toString() + ' ' + message);
  });
  private readonly detailSections: WaterFlowSections = new WaterFlowSections();
  private detailFlowShape: string = '';

  private syncDetailFlow(): void {
    const detail: PinmonyDetailSnapshot = this.displayedDetail();
    const pins: PinmonyRelatedPin[] = [];
    const seen: Set<string> = new Set<string>();
    if (this.isRecommendReady()) detail.related.forEach((pin: PinmonyRelatedPin): void => {
      const key: string = (pin.kind || 'pin') + ':' + (pin.pinUrl || pin.id);
      if (!seen.has(key)) { seen.add(key); pins.push(pin); }
    });
    // The header is a retained FlowItem, outside LazyForEach. Observable
    // detail props update its controls without recycling the hero and masks.
    const rows: PinmonyDetailFlowRow[] = [];
    pins.forEach((pin: PinmonyRelatedPin): void => {
      rows.push({ key: 'related:' + (pin.kind || 'pin') + ':' + (pin.pinUrl || pin.id), kind: 'related', pin: pin,
        fingerprint: JSON.stringify(pin) });
    });
    rows.push({ key: 'footer:' + detail.pinUrl, kind: 'footer', fingerprint: '' });
    this.detailRows.update(rows);
    const shape: string = pins.length.toString() + ':' + this.recommendColumnCount().toString();
    if (shape !== this.detailFlowShape) {
      this.detailFlowShape = shape;
      const sections: SectionOptions[] = [{ itemsCount: 1, crossCount: 1 }];
      if (pins.length > 0) sections.push({ itemsCount: pins.length, crossCount: this.recommendColumnCount(), columnsGap: 12, rowsGap: 18 });
      sections.push({ itemsCount: 1, crossCount: 1 });
      this.detailSections.splice(0, this.detailSections.length(), sections);
    }
  }
  private readonly detailPathStack: NavPathStack = new NavPathStack();
  private lastReportedScrollOffset: number = 0;
  private measuredHeaderHeight: number = 0;
  private lastRecommendAuditKey: string = '';
  private activePin: string = '';
  private restoredPaginationAllowed: boolean = true;
  private restoringScroll: boolean = false;
  onBack?: () => void;
  onCoveredBack?: () => boolean;
  onUser?: (url: string) => void;
  onAction?: (id: string, kind: string) => void;
  onRelated?: (id: string) => void;
  onRelatedTopic?: (moduleId: string, topicId: string, pinUrl: string) => void;
  onImageError?: (pinUrl: string) => void;
  onVideoRetry?: () => void;
  onLoadMore?: () => void;
  onComments?: () => void;
  onCommentsRetry?: () => void;
  onUndoMore?: () => void;
  @Prop canUndoMore: boolean = false;
  @Prop undoMoreBusy: boolean = false;
  onScrollPosition?: (pinUrl: string, offset: number) => void;

  private onPinChanged(): void {
    if (this.activePin !== this.displayedDetail().pinUrl) {
      this.viewerMounted = false; this.viewerClosing = false;
      this.searchMounted = false; this.searchImageReady = false; this.searchClosing = false;
      this.activePin = this.displayedDetail().pinUrl;
      this.decodedHeroSource = undefined;
      this.expanded = false;
      this.zoomImageUrl = '';
      this.productGalleryOffset = 0;
      this.textOverflowing = false;
      this.videoFailure = ''; this.videoRetryRevision = 0;
      this.restoreScrollPosition();
      this.startSearchLabel();
      if (this.onImageLayer) this.onImageLayer('');
    }
    this.syncDetailFlow();
    this.updateDetailLayout();
    this.auditRecommendationGate('detail-update');
  }

  private notifyImageLoaded(pinUrl: string, imageUrl: string): void {
    if (pinUrl === this.displayedDetail().pinUrl && imageUrl === this.displayedDetail().imageUrl) {
      const key: string = this.heroRenderKey(imageUrl, pinUrl);
      if (this.decodedHeroSource?.key !== key) this.decodedHeroSource = {
        key: key, url: imageUrl, pinUrl: pinUrl, revision: this.heroRenderRevision
      };
    }
    if (!this.onImageLoaded) return;
    const identity: string = this.renderIdentity + '|' + pinUrl + '|' + imageUrl;
    if (this.lastImageNotification === identity) return;
    this.lastImageNotification = identity;
    this.onImageLoaded(pinUrl, imageUrl, this.renderIdentity);
  }

  aboutToAppear(): void {
    this.heroVisible = true;
    if (this.entryPhoto && !this.entryResumed) this.entryOpacity = 0;
    if (this.entryResumed) this.entryMotionComplete = true;
    this.activePin = this.displayedDetail().pinUrl;
    this.syncDetailFlow();
    this.updateDetailLayout();
    this.auditRecommendationGate('appear');
    this.auditRecommendationLayout();
    this.startSearchLabel();
    this.detailPathStack.clear();
    this.detailPathStack.pushPath({ name: 'pin-web-detail' }, false);
    if (this.onPresented) this.onPresented();
  }

  private startSearchLabel(): void {
    clearTimeout(this.searchLabelTimer); this.searchLabelVisible = true;
    this.searchLabelTimer = setTimeout(() => { this.searchLabelVisible = false; }, 2500);
  }
  aboutToDisappear(): void {
    this.shuffleFlightRevision++;
    clearTimeout(this.shuffleFlightTimer);
    this.shuffleFlightActive = false;
    this.shuffleFlightClosing = false;
    this.shuffleHitMasks.clear();
    this.heroVisible = false;
    clearTimeout(this.searchLabelTimer);
  }

  private retryHeroImage(key: string): void {
    if (!this.heroVisible || !this.displayedDetail().imageUrl || key !== this.heroRenderKey(this.displayedDetail().imageUrl, this.displayedDetail().pinUrl)) return;
    this.heroRenderRevision = (this.heroRenderRevision + 1) % 2147483647;
    this.lastImageNotification = '';
    if (this.onContentRetry) this.onContentRetry();
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const share: PinmonyDetailAction | undefined = this.action('share');
    if (this.imageLayer === 'search') {
      return { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
        style: { blurStrategy: BlurStrategy.DISABLE, thermoCtrl: false, scrollEffectOpts: { enableScrollEffect: false },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 } } },
        content: { title: { mainTitle: this.uiText("pm_detail_photo_search") }, menu: { value: [] }, backIcon: { label: this.uiText("pm_back_572cf45b"), isEnabled: true,
          action: () => { if (this.onImageLayer) this.onImageLayer(''); } } } };
    }
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'),
        scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } }
      },
      content: {
        title: { mainTitle: '' },
        backIcon: { isEnabled: true, label: this.uiText("pm_back_572cf45b"), action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: share ? [{ content: {
          icon: $r('app.media.lucide_share_2'), label: share.label,
          isEnabled: this.acceptsActionIntent(share),
          action: () => {
            const item: PinmonyDetailAction | undefined = this.action('share');
            if (item && this.acceptsActionIntent(item) && this.onAction) this.onAction(item.id, item.kind);
          }
        } }] : [] }
      }
    };
  }

  private shuffleThumbnailWidth(item: PinmonyShuffleItem): number {
    return Math.max(20,Math.min(180,100 * item.imageWidth / Math.max(1,item.imageHeight)));
  }

  private shuffleReturnOffset(): number {
    let offset: number = 0;
    for (const item of this.displayedDetail().shuffle?.items || []) {
      if (!item.tappable || item.hidden || item.alpha <= 0 || !item.imageUrl) continue;
      if (item.id === this.shuffleReturnItem) return offset;
      offset += this.shuffleThumbnailWidth(item) + 12;
    }
    return -1;
  }

  private revealShuffleReturn(): void {
    const key: string = this.displayedDetail().pinUrl + ':' + this.shuffleReturnItem;
    if (!this.shuffleReturnItem || this.shuffleRevealedKey === key || this.shuffleSelectedImage || this.shuffleFullDetail || !this.videoActive) return;
    const offset: number = this.shuffleReturnOffset();
    if (offset < 0) return;
    try {
      const ui = this.getUIContext();
      const strip = ui.getComponentUtils().getRectangleById('pinmony-shuffle-strip-' + this.traceId.toString());
      const root = ui.getComponentUtils().getRectangleById('pinmony-photo-root-' + this.traceId.toString());
      if (strip.size.width <= 0 || root.size.height <= 0) return;
      const item: PinmonyShuffleItem | undefined = this.displayedDetail().shuffle?.items.find((candidate: PinmonyShuffleItem): boolean => candidate.id === this.shuffleReturnItem);
      if (!item) return;
      const stripWidth: number = ui.px2vp(strip.size.width);
      const currentX: number = this.shuffleStripScroller.offset()?.xOffset || 0;
      const itemRight: number = offset + this.shuffleThumbnailWidth(item);
      const nextX: number = offset < currentX ? offset : itemRight > currentX + stripWidth ? itemRight - stripWidth : currentX;
      if (Math.abs(nextX - currentX) > 1) {
        this.shuffleStripScroller.scrollTo({ xOffset: Math.max(0, nextX), yOffset: 0,
          animation: { duration: 480, curve: Curve.EaseInOut } });
      }
      const visibleTop: number = ui.px2vp(root.windowOffset.y) + this.titleContentInset() + 8;
      const visibleBottom: number = ui.px2vp(root.windowOffset.y + root.size.height) - 16;
      const stripTop: number = ui.px2vp(strip.windowOffset.y);
      const stripBottom: number = ui.px2vp(strip.windowOffset.y + strip.size.height);
      const overflow: number = stripTop < visibleTop ? stripTop - visibleTop : Math.max(0, stripBottom - visibleBottom);
      if (Math.abs(overflow) > 1) {
        const position = this.detailScroller.offset();
        this.detailScroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, (position?.yOffset || 0) + overflow),
          animation: { duration: 480, curve: Curve.EaseInOut } });
      }
      this.shuffleRevealedKey = key;
    } catch (_) {}
  }

  private restoreScrollPosition(): void {
    const offset: number = Math.max(0, this.initialScrollOffset);
    this.restoredPaginationAllowed = offset <= 0;
    this.restoringScroll = true;
    const pin: string = this.displayedDetail().pinUrl;
    setTimeout(() => {
      if (this.displayedDetail().pinUrl !== pin) return;
      try {
        this.detailScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
        this.lastReportedScrollOffset = offset;
        this.shuffleRevealedKey = '';
        this.revealShuffleReturn();
      } catch (error) {
        PinmonyRuntimeLog.warn('Pinmony: detail scroll restoration unavailable');
      }
      this.restoringScroll = false;
    }, 0);
  }

  private reportScrollPosition(force: boolean = false): void {
    if (this.restoringScroll) return;
    try {
      const position = this.detailScroller.offset();
      if (!position) return;
      const offset: number = Math.max(0, position.yOffset);
      if (!force && Math.abs(offset - this.lastReportedScrollOffset) < 8) return;
      this.lastReportedScrollOffset = offset;
      if (this.onScrollPosition) this.onScrollPosition(this.displayedDetail().pinUrl, offset);
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: detail scroll position unavailable');
    }
  }

  private action(kind: string): PinmonyDetailAction | undefined {
    const snapshot: PinmonyDetailSnapshot = this.shuffleSelectedImage && !this.shuffleFullDetail ? this.currentDetail : this.displayedDetail();
    const item: PinmonyDetailAction | undefined = snapshot.actions.find((value: PinmonyDetailAction): boolean => value.kind === kind);
    if(!item && kind === 'share' && this.shareActionsReady)return {id:'native-share',kind:'share',label:this.uiText("pm_share_7e564575"),countText:'',enabled:true,selected:false};
    return item;
  }

  private leftActions(): PinmonyDetailAction[] {
    const available: PinmonyDetailAction[] = this.displayedDetail().actions.filter((item: PinmonyDetailAction): boolean =>
      item.kind === 'like' || item.kind === 'comment' || item.kind === 'more');
    if (this.displayedDetail().dataSource !== 'api') return available;
    const kinds: string[] = ['like', 'comment'];
    const result: PinmonyDetailAction[] = kinds.map((kind: string): PinmonyDetailAction => {
      const real: PinmonyDetailAction | undefined = available.find((item: PinmonyDetailAction): boolean => item.kind === kind);
      if (real && (this.readsReady || this.displayedDetail().imageStageReady && (this.actionsReady || this.postActionsReady && kind === 'like' || this.commentActionsReady && kind === 'comment') ||
          this.displayedDetail().kind === 'cached' || this.displayedDetail().actionsRetained)) return real;
      return { id: 'pending-' + kind, kind: kind, label: kind === 'like' ? this.uiText("pm_like_aced5d7f") : this.uiText("pm_comments_6849b825"),
        countText: '', enabled: false, selected: false };
    });
    return result.concat(available.filter((item: PinmonyDetailAction): boolean => item.kind === 'more'));
  }

  private actionIcon(action: PinmonyDetailAction): Resource {
    if (action.kind === 'comment') return $r('app.media.detail_comment_outline');
    return $r('app.media.lucide_ellipsis');
  }

  private imageHeight(width: number, imageWidth: number, imageHeight: number): number {
    if (imageWidth <= 0 || imageHeight <= 0) return width * 1.15;
    return Math.max(220, Math.min(620, width * imageHeight / imageWidth));
  }

  private recommendCardWidth(): number {
    return Math.max(0, (this.contentWidth - 36 - (this.recommendColumnCount() - 1) * 12) / this.recommendColumnCount());
  }

  private recommendColumnCount(): number {
    return Math.max(2, Math.floor((this.contentWidth - 24) / 192));
  }

  private isMainImageReady(): boolean {
    return this.displayedDetail().dataSource !== 'api' || this.displayedDetail().imageStageReady === true;
  }

  private isCommentsReady(): boolean {
    return this.readsReady || this.displayedDetail().dataSource !== 'api' || this.displayedDetail().interactionsSettled === true;
  }

  private isRecommendReady(): boolean {
    return this.displayedDetail().kind === 'cached' || this.displayedDetail().relatedRetained === true ||
      this.displayedDetail().related.length > 0 || this.displayedDetail().relatedEnded === true || !!this.displayedDetail().relatedError;
  }

  private recommendCardHeight(cardWidth: number, pin: PinmonyRelatedPin): number {
    return this.imageHeight(cardWidth, pin.imageWidth, pin.imageHeight);
  }

  private recommendDensity(): number {
    try {
      // Card creation runs during scrolling. Use this window's conversion
      // rather than synchronously querying the physical display per card.
      const value: number = this.getUIContext().vp2px(1);
      return value > 0 && isFinite(value) ? value : 1;
    } catch (_) {
      return 1;
    }
  }

  private auditRecommendationGate(reason: string): void {
    const ready: boolean = this.isRecommendReady();
    const columns: number = this.recommendColumnCount();
    const width: number = this.recommendCardWidth();
    const key: string = reason + ':' + (ready ? '1' : '0') + ':' + columns.toString() + ':' + width.toFixed(2) +
      ':' + (this.displayedDetail().imageStageReady === true ? '1' : '0') + ':' + (this.displayedDetail().interactionsSettled === true ? '1' : '0');
    if (key === this.lastRecommendAuditKey) return;
    this.lastRecommendAuditKey = key;
    PinmonyRuntimeLog.info('RecommendAudit: gate reason=' + reason + ' main=' +
      (this.isMainImageReady() ? 'ready' : 'pending') + ' interactions=' +
      (this.isCommentsReady() ? 'ready' : 'pending') + ' ready=' + (ready ? 'ready' : 'blocked') +
      ' presentation=' + (this.displayedDetail().relatedPreview ? 'preview' :
        this.displayedDetail().kind === 'cached' || this.displayedDetail().relatedRetained ? 'cached' : 'current') +
      ' columns=' + columns.toString() + ' cardWidthVp=' + width.toFixed(2));
  }

  private auditRecommendationLayout(): void {
    const columns: number = this.recommendColumnCount();
    const width: number = this.recommendCardWidth();
    const key: string = 'layout:' + columns.toString() + ':' + width.toFixed(2);
    if (key === this.lastRecommendAuditKey) return;
    this.lastRecommendAuditKey = key;
    PinmonyRuntimeLog.info('RecommendAudit: layout columns=' + columns.toString() + ' cardWidthVp=' + width.toFixed(2));
  }

  private auditRecommendationImage(tier: string, targetPx: number, sourceHeightPx: number): void {
    const density: number = this.recommendDensity();
    PinmonyRuntimeLog.info('RecommendAudit: image tier=' + tier + ' cardWidthVp=' +
      (targetPx / density).toFixed(2) + ' cardHeightVp=' + (sourceHeightPx / density).toFixed(2) +
      ' targetPx=' + Math.round(targetPx).toString() +
      ' decode=source-aspect');
  }

  private updateDetailLayout(): void {
    if (!this.heroVisible) return;
    try {
      this.measureTextOverflow();
    } catch (_) {
      // A transient unavailable UI context must not interrupt image/state setup.
      this.textOverflowing = !!this.displayedDetail().title || !!this.displayedDetail().description;
      if (!this.textMeasureWarned) PinmonyRuntimeLog.warn('DetailTrace: text measurement unavailable');
      this.textMeasureWarned = true;
    }
  }

  private measureTextOverflow(): void {
    const utils = this.getUIContext().getMeasureUtils();
    const width: string = this.detailPaneWidth().toString() + 'vp';
    const title = utils.measureTextSize({ textContent: this.displayedDetail().title, fontSize: '22fp',
      fontWeight: FontWeight.Bold, constraintWidth: width });
    const shortTitle = utils.measureTextSize({ textContent: this.displayedDetail().title, fontSize: '22fp',
      fontWeight: FontWeight.Bold, constraintWidth: width, maxLines: 2 });
    const description = utils.measureTextSize({ textContent: this.displayedDetail().description, fontSize: '16fp',
      lineHeight: '24vp', constraintWidth: width });
    const shortDescription = utils.measureTextSize({ textContent: this.displayedDetail().description, fontSize: '16fp',
      lineHeight: '24vp', constraintWidth: width, maxLines: 2 });
    this.textOverflowing = Number(title.height) > Number(shortTitle.height) + 1 ||
      Number(description.height) > Number(shortDescription.height) + 1;
  }

  private heroHeight(): number {
    const width: number = this.detailPaneWidth();
    if (this.displayedDetail().imageWidth <= 0 || this.displayedDetail().imageHeight <= 0) return width * 1.15;
    const height: number = width * this.displayedDetail().imageHeight / this.displayedDetail().imageWidth;
    return this.displayedDetail().isVideo || this.displayedDetail().mediaKind === 'carousel' || !!this.displayedDetail().carousel ? Math.min(1200, height) : height;
  }

  private acceptsActionIntent(item: PinmonyDetailAction): boolean {
    if (item.kind === 'source' && this.readsReady && item.enabled) return true;
    if (item.kind === 'save' && this.saveBusy || item.kind === 'like' && this.likeBlocked) return false;
    if (item.kind === 'share' && this.shareActionsReady) return true;
    if (item.kind === 'more' && this.menuActionsReady) return true;
    return (this.commentActionsReady && item.kind === 'comment') || (this.postActionsReady && (item.kind === 'save' || item.kind === 'like' && !item.selected)) || (this.actionsReady && item.enabled) ||
      (this.deferredActions && /^(like|comment|save|share|more|source)$/.test(item.kind));
  }

  private creatorFontSize(): number {
    try {
      const utils = this.getUIContext().getMeasureUtils();
      const width: string = Math.max(1, this.detailPaneWidth() - (this.displayedDetail().creator ? 42 : 0)).toString() + 'vp';
      const full = utils.measureTextSize({ textContent: this.displayedDetail().creator, fontSize: '18fp',
        fontWeight: FontWeight.Medium, constraintWidth: width });
      const single = utils.measureTextSize({ textContent: this.displayedDetail().creator, fontSize: '18fp',
        fontWeight: FontWeight.Medium, constraintWidth: width, maxLines: 1 });
      return Number(full.height) > Number(single.height) + 1 ? 16 : 18;
    } catch (_) { return 18; }
  }

  private actionCountText(item: PinmonyDetailAction): string {
    const count: string = (item.countText || '').trim();
    if ((item.kind === 'like' || item.kind === 'comment') && count === '0') return '';
    return count;
  }

  private actionButtonEnabled(item: PinmonyDetailAction): boolean {
    // Confirmed likes remain fully colored; the click handler still rejects
    // unsupported repeat reactions through acceptsActionIntent.
    return item.kind === 'like' && item.selected || this.acceptsActionIntent(item);
  }

  @Builder
  private iconAction(item: PinmonyDetailAction) {
    Row({ space: 2 }) {
      Button({ type: ButtonType.Circle }) {
        if (item.kind === 'like') {
          SymbolGlyph(item.selected ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(24)
            .fontColor([item.selected ? $r('app.color.accent') : $r('app.color.primary_text')])
        } else {
          Image(this.actionIcon(item))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.primary_text'))
        }
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .enabled(this.actionButtonEnabled(item))
      .opacity((item.kind === 'like' && item.selected) || (this.acceptsActionIntent(item)) ? 1 : 0.4)
      .onClick(() => {
        if (!this.acceptsActionIntent(item)) return;
        if (this.onAction) this.onAction(item.id, item.kind);
      })
      .accessibilityText(this.actionCountText(item) ? `${item.label}，${this.actionCountText(item)}` : item.label)

      if (this.actionCountText(item) && (item.kind === 'like' || item.kind === 'comment')) {
        Text(this.actionCountText(item))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private relatedCard(pin: PinmonyRelatedPin) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 8 }) {
        SmartImage({ images: pin.images || {}, url: pin.imageUrl, widthVp: this.recommendCardWidth(),
          loadingActive: this.videoActive, useSharedDecode: false, viewportOnly: false, loadPriority: 2,
          heightVp: this.recommendCardHeight(this.recommendCardWidth(), pin),
          targetPx: this.recommendCardWidth() * this.recommendDensity(), borderRadiusVp: RECOMMEND_CARD_RADIUS_VP,
          onLoaded: () => {
            if (this.onRelatedImageLoaded && this.displayedDetail().related.some((item: PinmonyRelatedPin): boolean =>
              item.id === pin.id && item.imageUrl === pin.imageUrl)) this.onRelatedImageLoaded(this.displayedDetail().pinUrl);
          }, onError: (code: number) => {
            PinmonyRuntimeLog.warn('RecommendImageError: code=' + code.toString());
          }, onTrace: (event: string, revision: number, tier: string, elapsedMs: number) => {
            PinmonyRuntimeLog.info('RecommendImageTrace: openId=' + this.traceId.toString() +
              ' index=' + this.displayedDetail().related.findIndex((item: PinmonyRelatedPin): boolean => item.id === pin.id) +
              ' event=' + event + ' revision=' + revision.toString() + ' tier=' + tier +
              ' elapsedMs=' + elapsedMs.toString());
          }, onAudit: (tier: string, targetPx: number, sourceHeightPx: number) =>
            this.auditRecommendationImage(tier, targetPx, sourceHeightPx) })
          .width('100%')
          .height(this.recommendCardHeight(this.recommendCardWidth(), pin))
          .id('pinmony-related-photo-' + this.displayedDetail().pinUrl + '-' + pin.pinUrl)
        if (pin.title.length > 0) {
          Text(PinmonyI18n.render(pin.title, this.uiLanguage))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .padding(0)
    .width('100%')
    .backgroundColor(Color.Transparent)
    // Session preparation gates the action, not the colors of cached photographs.
    .stateEffect(((this.readsReady || this.actionsReady && this.displayedDetail().kind !== 'cached' && !this.displayedDetail().relatedRetained) || this.deferredActions))
    .onClick(() => {
      if (((this.readsReady || this.actionsReady && this.displayedDetail().kind !== 'cached' && !this.displayedDetail().relatedRetained) || this.deferredActions) && this.onRelated)
        this.onRelated(pin.pinUrl);
    })
    .accessibilityText(pin.title.length > 0 ? pin.title : this.uiText("pm_open_related_pin_e1e5dfc7"))
  }

  private relatedColumn(index: number, columnCount: number): PinmonyRelatedPin[] {
    return this.displayedDetail().related.filter((_pin: PinmonyRelatedPin, pinIndex: number): boolean =>
      pinIndex % columnCount === index);
  }

  @Builder
  private relatedCards(index: number, columnCount: number) {
    Column({ space: 18 }) {
      // Include the image source in the reuse key so a reused Pin card cannot
      // retain the previous bitmap when its recommendation source changes.
      ForEach(this.relatedColumn(index, columnCount), (pin: PinmonyRelatedPin) => {
        if (pin.kind === 'topics') {
          this.relatedTopicModule(pin)
        } else {
          this.relatedCard(pin)
        }
      }, (pin: PinmonyRelatedPin) => pin.pinUrl || pin.id)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private relatedTopicModule(module: PinmonyRelatedPin) {
    Column({ space: 10 }) {
      Text(module.title).fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).width('100%')
      ForEach(module.topics || [], (topic: PinmonyRelatedTopic) => {
        Button({ type: ButtonType.Normal }) {
          Stack() {
            SmartImage({ url: topic.imageUrl, images: {}, widthVp: this.recommendCardWidth(),
              loadingActive: this.videoActive, useSharedDecode: false, viewportOnly: false, loadPriority: 2,
              heightVp: 96, targetPx: this.recommendCardWidth() * this.recommendDensity(), borderRadiusVp: 16 })
              .width('100%').height(96)
            Column().width('100%').height(96).backgroundColor('#66000000')
            Text(topic.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center).padding(10)
          }.width('100%').height(96).borderRadius(16).clip(true)
        }.width('100%').padding(0).backgroundColor(Color.Transparent).borderRadius(16)
          .enabled(this.videoActive && !this.contentError)
          .onClick(() => {
            if (this.videoActive && !this.contentError && this.onRelatedTopic) this.onRelatedTopic(module.id, topic.id, this.displayedDetail().pinUrl);
          }).accessibilityText(topic.title)
      }, (topic: PinmonyRelatedTopic) => topic.id + ':' + topic.imageUrl + ':' + topic.targetUrl)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private recommendationSkeleton() {
    Row({ space: RECOMMEND_PHONE_GAP_VP }) {
      ForEach(Array.from({ length: this.recommendColumnCount() }), () => {
        Column({ space: 18 }) {
          Column().width('100%').height(260).backgroundColor('#F0F0F0')
            .borderRadius(RECOMMEND_CARD_RADIUS_VP)
          Column().width('82%').height(16).backgroundColor('#F0F0F0').borderRadius(8)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      })
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  private wideDetail(): boolean {
    return this.viewportWidth >= 840 && this.viewportWidth > this.viewportHeight;
  }

  private detailPaneWidth(): number {
    return Math.max(1, this.wideDetail() ? (this.contentWidth - 56) / 2 : this.contentWidth - 36);
  }
  private detailMediaWidth(): number {
    return this.displayedDetail().carousel?.freeScroll && !this.wideDetail() ? this.contentWidth : this.detailPaneWidth();
  }

  @Builder
  private detailMedia() {
    Column() {
          if (this.displayedDetail().carousel) {
            PinmonyCarouselView({ carousel: this.displayedDetail().carousel, contentWidth: this.detailMediaWidth(), mediaHeightVp: this.heroHeight(),
              previewUrl: this.displayedDetail().imageUrl,
              productOffset: this.productGalleryOffset,
              onProductOffset: (offset: number) => { this.productGalleryOffset = offset; },
              sourceId: 'pinmony-photo-source-' + this.traceId.toString(),
              imageHidden: this.viewerMounted && this.viewerImageReady || this.searchMounted && this.searchImageReady,
              hiddenImageUrl: this.zoomImageUrl,
              viewerImageUrl: this.zoomImageUrl,
              active: this.videoActive && !this.imageLayer,
              sessionReady: this.actionsReady || this.readsReady,
              mediaOwner: this.displayedDetail().pinUrl + '|' + this.traceId.toString(), openId: this.traceId,
              autoplayWifi: this.displayedDetail().autoplayWifi === true, autoplayCellular: this.displayedDetail().autoplayCellular === true,
              onFirstImageSettled: (failed: boolean) => {
                if (failed) { if (this.onImageError) this.onImageError(this.displayedDetail().pinUrl); }
                else this.notifyImageLoaded(this.displayedDetail().pinUrl, this.displayedDetail().imageUrl);
              },
              onImageTap: (url: string) => { if (!this.disableImageZoom && !this.displayedDetail().shuffleId) { this.zoomImageUrl = url; if (this.onImageLayer) this.onImageLayer('zoom'); } } })
          } else if (((this.displayedDetail().mediaLoading || this.mediaReadBusy) && !this.displayedDetail().video) || (this.displayedDetail().mediaKind === 'carousel' && !this.displayedDetail().carousel)) {
            Stack({ alignContent: Alignment.Center }) {
              if (this.displayedDetail().imageUrl) this.heroImage()
              if (this.displayedDetail().mediaLoading || this.mediaReadBusy) {
                LoadingProgress().width(28).height(28).color($r('app.color.accent'))
                  .accessibilityText(this.uiText("pm_loading_media_01cf18eb"))
              } else {
                Column({ space: 12 }) {
                  PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.displayedDetail().mediaError ?? '', this.uiLanguage) || this.uiText("pm_carousel_unavailable_093874a4"), actionText: this.uiText("pm_reload_media_57dfcd7b"), onAction: () => { if (this.onVideoRetry) this.onVideoRetry(); } })
                }.padding(16).borderRadius(12).backgroundColor($r('app.color.page_background'))
              }
            }.width('100%').height(this.heroHeight()).backgroundColor($r('app.color.surface_muted')).borderRadius(18).clip(true)
            if (this.displayedDetail().mediaKind === 'carousel') {
              // Reserve the indicator row before the validated slots are ready.
              Row().width('100%').height(28)
            }
          } else if (this.displayedDetail().video && this.displayedDetail().isVideo) {
            PinmonyVideoPlayer({ video: this.displayedDetail().video, poster: this.displayedDetail().imageUrl, active: this.videoActive, openId: this.traceId,
              entryPreview: this.displayedDetail().imageUrl,
              autoplayWifi: this.displayedDetail().autoplayWifi === true, autoplayCellular: this.displayedDetail().autoplayCellular === true,
              mediaOwner: this.displayedDetail().pinUrl + '|' + this.traceId.toString(),
              sessionReady: this.actionsReady || this.readsReady,
              readingAddress: this.displayedDetail().mediaLoading === true || this.mediaReadBusy,
              retryRevision: this.videoRetryRevision,
              onFailureChanged: (pinId: string, message: string) => {
                if (this.displayedDetail().video?.pinId === pinId) this.videoFailure = message;
              },
              onPosterSettled: (failed: boolean) => {
                if (failed) { if (this.onImageError) this.onImageError(this.displayedDetail().pinUrl); }
                else this.notifyImageLoaded(this.displayedDetail().pinUrl, this.displayedDetail().imageUrl);
              } })
          } else if (this.displayedDetail().isVideo) {
            Stack({ alignContent: Alignment.Center }) {
              Image(this.displayedDetail().imageUrl).width('100%')
                .height(this.heroHeight())
                .objectFit(ImageFit.Contain)
                .onComplete((event) => {
                  if (event?.loadingStatus === 1) this.notifyImageLoaded(this.displayedDetail().pinUrl, this.displayedDetail().imageUrl);
                })
                .onError(() => { if (this.onImageError) this.onImageError(this.displayedDetail().pinUrl); })
              Column({ space: 12 }) {
                PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.displayedDetail().videoError ?? '', this.uiLanguage) || this.uiText("pm_no_playable_video_url_available_a548116d"), actionText: this.uiText("pm_reload_video_1472e7f1"), onAction: () => { if (this.onVideoRetry) this.onVideoRetry(); } })
              }.padding(16).borderRadius(12).backgroundColor($r('app.color.page_background'))
            }.width('100%').borderRadius(18).clip(true)
          } else {
           Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.displayedDetail().imageUrl) {
            this.heroImage()
          }

            if (this.displayedDetail().aiLabel) {
              Row() {
                Text(this.displayedDetail().aiLabel).fontSize(14).fontColor(Color.White)
                  .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                  .backgroundColor('#B34B4F52').borderRadius(16)
                  .accessibilityText(this.displayedDetail().aiLabel)
              }.width('100%').justifyContent(FlexAlign.Start).padding(8)
                .hitTestBehavior(HitTestMode.None)
            }
            Button({ type: ButtonType.Normal }) {
              Row() {
                Text(this.uiText("pm_search_image_8f938fb8")).fontSize(14).fontColor(Color.White)
                  .width(this.searchLabelVisible ? 64 : 0).opacity(this.searchLabelVisible ? 1 : 0)
                  .maxLines(1).clip(true).animation({ duration: 240, curve: Curve.EaseInOut })
                SymbolGlyph($r('sys.symbol.circle_viewfinder')).fontSize(24).fontColor([Color.White])
              }
            }.width(this.searchLabelVisible ? 108 : 44).height(44).padding({ left: 10, right: 10 })
              .animation({ duration: 240, curve: Curve.EaseInOut }).borderRadius(16).margin(8)
              .backgroundColor('#77303030').enabled(this.actionsReady || this.auxiliaryReady || this.deferredActions)
              .onClick(() => { if (this.onImageLayer) this.onImageLayer('search'); })
              .accessibilityText(this.uiText("pm_find_related_content_in_this_image_20372b79"))
          }.width('100%').height(this.heroHeight()).backgroundColor($r('app.color.surface_muted')).borderRadius(18).clip(true)
          }

    }.width(this.detailMediaWidth()).id('pinmony-entry-target-' + this.traceId.toString())
      .opacity(this.entryPhotoHidden ? 0 : 1)
      .margin({ left: this.displayedDetail().carousel?.freeScroll && !this.wideDetail() ? -18 : 0,
        right: this.displayedDetail().carousel?.freeScroll && !this.wideDetail() ? -18 : 0 })
  }

  @Builder
  private detailInformation() {
    Column({ space: 18 }) {
          if (this.displayedDetail().shuffleError) {
            PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.displayedDetail().shuffleError || '',this.uiLanguage), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => this.onShuffleRetry?.(), actionEnabled: this.videoActive && !this.displayedDetail().shuffleLoading })
          }
          if (this.displayedDetail().shuffle) {
            Scroll(this.shuffleStripScroller) {
              Row({space:12}) {
                ForEach(this.displayedDetail().shuffle?.items || [], (item: PinmonyShuffleItem) => {
                  if (item.tappable && !item.hidden && item.alpha > 0 && item.imageUrl) {
                    Image(item.imageUrl).width(this.shuffleThumbnailWidth(item))
                      .height(100).objectFit(ImageFit.Cover).borderRadius(12)
                      // Keep the border width stable so selecting a Pin does not move the strip.
                      .border({ width: 2,
                        color: item.id === (this.shuffleSelectedImage ? this.shuffleItems[this.shuffleIndex]?.id : this.shuffleReturnItem) ? $r('app.color.accent') : Color.Transparent,
                        radius: 12 })
                      .id('pinmony-shuffle-thumbnail-' + this.traceId + '-' + item.id)
                      .scale({ x: this.shufflePressedItem === item.id ? this.shufflePressScale : 1,
                        y: this.shufflePressedItem === item.id ? this.shufflePressScale : 1 })
                      .onTouch((event: TouchEvent) => {
                        if(event.type === TouchType.Down)this.shufflePress(item.id, true);
                        else if(event.type === TouchType.Up || event.type === TouchType.Cancel)this.shufflePress(item.id, false);
                      })
                      .accessibilityText(this.uiText('pm_open_original_pin_42977656'))
                      .onClick(() => this.openShuffleItem(item.id, false))
                  }
                }, (item: PinmonyShuffleItem): string => item.id + ':' + this.uiLanguage)
              }
            }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).align(Alignment.TopStart)
              .id('pinmony-shuffle-strip-' + this.traceId.toString())
              .onAreaChange(() => this.revealShuffleReturn())
          }
          if (this.contentError) {
            PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.contentError, this.uiLanguage), actionText: this.uiText("pm_retry_loading_details_94912123"), onAction: () => { if (this.onContentRetry) this.onContentRetry(); }, actionEnabled: this.contentRetryable })
          } else if (this.displayedDetail().kind !== 'cached' && !this.actionsReady && !this.readsReady && !this.deferredActions) {
            Text(this.displayedDetail().kind === 'cached' ? this.uiText("pm_syncing_pin_status_e1429d05") : this.uiText("pm_verifying_pin_content_cbcfd002"))
              .fontSize(14).fontColor($r('app.color.secondary_text'))
          } else if (this.displayedDetail().kind !== 'cached' && (this.displayedDetail().actionsRetained || this.displayedDetail().commentsRetained || this.displayedDetail().relatedRetained) &&
              (this.displayedDetail().commentLoading || this.displayedDetail().relatedLoading)) {
            Text(this.uiText("pm_syncing_interactions_and_recommendations_d5a043fa")).fontSize(14).fontColor($r('app.color.secondary_text'))
          }

          this.videoRetryNotice()
          Row() {
            Row({ space: 6 }) {
              ForEach(this.leftActions(), (item: PinmonyDetailAction) => {
                this.iconAction(item)
              }, (item: PinmonyDetailAction) =>
                `${item.id}:${item.selected ? '1' : '0'}:${item.countText}:${item.enabled ? '1' : '0'}:${this.actionsReady ? '1' : '0'}`)
            }
            Blank()
            if (this.action('save')) {
              Button({ type: ButtonType.Normal }) {
                Text(this.action('save')!.selected ? PinmonyI18n.render(this.action('save')!.label, this.uiLanguage) : this.uiText("pm_save_60a53514"))
                  .fontColor(Color.White).fontSize(16).fontWeight(FontWeight.Medium)
                  .wordBreak(WordBreak.BREAK_ALL)
                  .maxLines(2).textAlign(TextAlign.Center).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
                .height('auto')
                .constraintSize({ minHeight: 44, maxWidth: '42%' })
                .padding({ left: 18, right: 18, top: 10, bottom: 10 })
                .backgroundColor($r('app.color.detail_save_accent'))
                .fontColor(Color.White)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .borderRadius(16)
                .enabled(!this.saveBusy && this.acceptsActionIntent(this.action('save')!))
                .onClick(() => {
                  const item: PinmonyDetailAction | undefined = this.action('save');
                  if (item && this.acceptsActionIntent(item) && this.onAction) {
                    this.onAction(item.id, item.kind);
                  }
                })
                .accessibilityText(this.action('save')!.selected ? PinmonyI18n.render(this.action('save')!.label, this.uiLanguage) : this.uiText("pm_save_60a53514"))
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column({ space: 6 }) {
            if (this.displayedDetail().creator.length > 0) {
              Row({ space: 10 }) {
                PinmonyUserAvatar({ image: this.displayedDetail().creatorAvatar, name: this.displayedDetail().creator, avatarSize: 32 })
                Text(this.displayedDetail().creator)
                  .fontSize(this.creatorFontSize())
                  .constraintSize({ maxWidth: '80%' })
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.primary_text'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.displayedDetail().creatorVerified) {
                  Image($r('app.media.pinmony_verified_badge')).width(16).height(16)
                    .accessibilityText(this.uiText('pm_verified_9a64637b'))
                }
              }
              .width('100%')
              .onClick(() => {
                PinmonyRuntimeLog.info('DetailCreatorTrace: click target=' + (this.displayedDetail().creatorUrl ? 'ready' : 'missing'));
                if (this.displayedDetail().creatorUrl && this.onUser) this.onUser(this.displayedDetail().creatorUrl || '');
              })
            }
            if (this.displayedDetail().title.length > 0) {
              Text(PinmonyI18n.render(this.displayedDetail().title, this.uiLanguage))
                .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                .copyOption(CopyOptions.LocalDevice)
                .onCopy(() => { if (this.onTextCopied) this.onTextCopied(); })
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text'))
                .maxLines(this.expanded ? undefined : 2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            if (this.displayedDetail().sourceName && this.displayedDetail().sourceName !== this.displayedDetail().creator) {
              Text(this.displayedDetail().sourceName).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
            }
            if (this.displayedDetail().priceText) {
              Text(this.displayedDetail().priceText).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).width('100%')
            }
            if (this.displayedDetail().affiliateDisclosure) {
              Text(this.displayedDetail().affiliateDisclosure).fontSize(13)
                .fontColor($r('app.color.secondary_text')).width('100%')
            }
            if (this.displayedDetail().description.length > 0) {
              Text() {
                ForEach(splitDescriptionTags(this.displayedDetail().description), (part: PinmonyDescriptionPart) => {
                  Span(part.text)
                    .fontColor(part.query ? $r('app.color.link_text') : $r('app.color.primary_text'))
                    .onClick(() => {
                      if (part.query && this.onTagSearch) this.onTagSearch(part.query, this.displayedDetail().pinUrl);
                    })
                })
              }
                .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                .copyOption(CopyOptions.LocalDevice)
                .onCopy(() => { if (this.onTextCopied) this.onTextCopied(); })
                .fontSize(16)
                .lineHeight(24)
                .fontColor($r('app.color.primary_text'))
                .maxLines(this.expanded ? undefined : 2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            if (this.expanded || this.textOverflowing) {
              Row() {
                Blank()
              Button(this.expanded ? this.uiText("pm_show_less_afd4b783") : this.uiText("pm_see_more_92b2b2de"))
                .height(32)
                .padding(0)
                .backgroundColor(Color.Transparent)
                .fontColor($r('app.color.primary_text'))
                .onClick(() => this.expanded = !this.expanded)
              }.width('100%')
            }
            if (this.displayedDetail().richDescription && this.displayedDetail().richDescription !== this.displayedDetail().description) {
              Text(this.displayedDetail().richDescription).fontSize(16).lineHeight(24)
                .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                .copyOption(CopyOptions.LocalDevice)
                .onCopy(() => { if (this.onTextCopied) this.onTextCopied(); })
                .fontColor($r('app.color.secondary_text')).width('100%')
            }
          if ((this.readsReady || this.actionsReady && this.displayedDetail().imageStageReady !== false ||
              this.displayedDetail().kind === 'cached' || this.displayedDetail().commentsRetained) && !this.displayedDetail().commentEmpty &&
              !!this.displayedDetail().commentPreview?.trim()) {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 2 }) {
                Text(this.displayedDetail().commentPreview || '').fontSize(13).lineHeight(18).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor($r('app.color.primary_text')).width('100%')
                Text(this.uiText("pm_view_all_comments_11ef17e2")).fontSize(13).lineHeight(18).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text')).width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.width('100%').padding(0).borderRadius(0).backgroundColor(Color.Transparent)
              .enabled((this.readsReady || (this.actionsReady && this.displayedDetail().kind !== 'cached' && !this.displayedDetail().commentsRetained) || this.deferredActions))
              .onClick(() => { if (this.onComments) this.onComments(); })

          }
            if (this.displayedDetail().sourceLabel.length > 0 && this.action('source')) {
              Button(this.uiText("pm_visit_website_04913c22"))
                .width('100%')
                .height(50)
                .backgroundColor($r('app.color.surface_muted'))
                .fontColor($r('app.color.primary_text'))
                .fontSize(17)
                .borderRadius(25)
                .enabled(this.acceptsActionIntent(this.action('source')!))
                .onClick(() => {
                  const item: PinmonyDetailAction | undefined = this.action('source');
                  if (item && this.acceptsActionIntent(item) && this.onAction) {
                    this.onAction(item.id, item.kind);
                  }
                })
                .accessibilityText(this.uiText("pm_visit_website_ac9d562e") + this.displayedDetail().sourceLabel)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.canUndoMore) {
            Row({ space: 12 }) {
              Text(this.uiText("pm_see_more_feedback_submitted_a391370a")).fontColor($r('app.color.primary_text')).layoutWeight(1)
              Button(this.uiText("pm_undo_926a50b9")).enabled(!this.undoMoreBusy).onClick(() => { if (this.onUndoMore) this.onUndoMore(); })
            }.width('100%')
          }
    }.width(this.detailPaneWidth()).alignItems(HorizontalAlign.Start)
      .margin({ top: this.wideDetail() ? 0 : 18 })
  }

  @Builder
  private detailHeader() {
    Flex({ direction: this.wideDetail() ? FlexDirection.Row : FlexDirection.Column,
      alignItems: ItemAlign.Start, justifyContent: FlexAlign.SpaceBetween }) {
      this.detailMedia()
      this.detailInformation()
    }.width('100%').padding({ top: 8, bottom: 18 })
      .onAreaChange((_old: Area, area: Area) => this.preserveRelatedAnchor(Number(area.height)))
  }

  private preserveRelatedAnchor(height: number): void {
    if (!Number.isFinite(height) || height <= 0) return;
    const previous: number = this.measuredHeaderHeight;
    this.measuredHeaderHeight = height;
    if (previous <= 0 || this.restoringScroll || Math.abs(height - previous) < 1) return;
    try {
      const position = this.detailScroller.offset();
      if (!position) return;
      const offset: number = position.yOffset;
      if (offset <= previous) return;
      const next: number = Math.max(0, offset + height - previous);
      this.detailScroller.scrollTo({ xOffset: 0, yOffset: next, animation: false });
      this.lastReportedScrollOffset = next;
      this.onScrollPosition?.(this.displayedDetail().pinUrl, next);
      PinmonyRuntimeLog.info('DetailScrollTrace: related-anchor adjusted=true');
    } catch (_) { PinmonyRuntimeLog.warn('DetailScrollTrace: related-anchor unavailable'); }
  }

  @Builder
  private detailFooter() {
    Column({ space: 12 }) {
          if (this.displayedDetail().kind === 'cached' && !this.displayedDetail().relatedLoading && this.displayedDetail().relatedError) {
            PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.displayedDetail().relatedError || '', this.uiLanguage), actionText: this.uiText("pm_load_recommendations_08df83f8"), actionEnabled: this.deferredActions || this.readsReady || this.actionsReady, onAction: () => { this.onLoadMore?.(); } })
          }
          if (this.displayedDetail().kind !== 'cached' && this.displayedDetail().dataSource === 'api' && (this.actionsReady || this.readsReady)) {
            if (!this.displayedDetail().relatedLoading && this.displayedDetail().relatedError) {
              PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.displayedDetail().relatedError || '', this.uiLanguage), actionText: this.uiText("pm_retry_recommendations_83cd903e"), onAction: () => { if (this.onLoadMore) this.onLoadMore(); } })
            } else if (this.displayedDetail().relatedEnded && this.displayedDetail().related.length === 0) {
              Text(this.uiText("pm_no_recommendations_yet_841e1d2f")).fontSize(14).fontColor($r('app.color.secondary_text'))
            }
          }

    }.width('100%')
  }

  @Builder
  private heroImage() {
    // Image lifecycle belongs to a component with a stable complete source key.
    Stack() {
    // Keep the decoded hero mounted when late collage metadata arrives.
    if (this.displayedDetail().imageUrl) {
      PinmonyCdnImage({ url: this.displayedDetail().imageUrl, useSharedDecode: false }).width('100%').height(this.heroHeight())
        .blur(28).opacity(0.72).hitTestBehavior(HitTestMode.None)
    }
    ForEach(this.heroImageSources(this.displayedDetail().imageUrl, this.displayedDetail().pinUrl), (source: DetailHeroSource) => {
      PinmonyDetailHero({ source: source, openId: this.traceId, heightVp: this.heroHeight(), label: this.displayedDetail().title,
        phase: this.displayedDetail().kind, blocked: !!this.contentError, renderIdentity: this.renderIdentity,
        stageReady: this.displayedDetail().imageStageReady === true, confirmedLoaded: this.displayedDetail().imageLoaded === true,
        previewAvailable: this.decodedHeroSource?.pinUrl === this.displayedDetail().pinUrl,
        onLoaded: (pin: string, image: string) => {
          this.completeHeroSource(source, pin, image);
        },
        onFailed: (pin: string) => {
          if (!this.heroVisible || source.key !== this.heroRenderKey(this.displayedDetail().imageUrl, this.displayedDetail().pinUrl)) return;
        this.lastImageNotification = '';
          if (this.onImageError) this.onImageError(pin);
        }, onRetry: () => this.retryHeroImage(source.key),
        onTap: () => { if (!this.disableImageZoom && !this.displayedDetail().shuffleId) { this.zoomImageUrl = ''; if (this.onImageLayer) this.onImageLayer('zoom'); } } })
    }, (source: DetailHeroSource): string => source.key)
    if (this.displayedDetail().shuffle) {
      PinmonyShuffleCanvas({shuffle:this.displayedDetail().shuffle,hitMasks:this.shuffleHitMasks,coverUrl:this.displayedDetail().imageUrl,coverProvided:true,canvasWidthVp:this.detailMediaWidth(),canvasHeightVp:this.heroHeight(),
        interactionReady:this.videoActive && this.readsReady && !this.contentError,pinLabel:this.uiText('pm_open_original_pin_42977656'),onPin:(id: string) => this.openShuffleItem(id, true)})
        .id('pinmony-shuffle-canvas-' + this.traceId)
    }
    if (this.displayedDetail().shuffleLoading) {
      LoadingProgress().width(28).height(28).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
    }
    }.width('100%').height(this.heroHeight()).borderRadius(18).clip(true)
      .id('pinmony-photo-source-' + this.traceId.toString())
      .opacity(this.viewerMounted && this.viewerImageReady || this.searchMounted && this.searchImageReady ? 0 : 1)
  }

  private heroImageSources(url: string, pinUrl: string): DetailHeroSource[] {
    const next: DetailHeroSource = { key: this.heroRenderKey(url, pinUrl), url: url, pinUrl: pinUrl, revision: this.heroRenderRevision };
    if (this.decodedHeroSource?.pinUrl === pinUrl) {
      return this.decodedHeroSource.key !== next.key ? [this.decodedHeroSource, next] : [next];
    }
    // The base response can upgrade the source before the card preview draws.
    // Keep that native preview mounted even when it has not reported ready yet.
    if (this.entryPhoto?.pinUrl === pinUrl && this.entryPhoto.imageUrl && this.entryPhoto.imageUrl !== url) {
      return [{ key: this.heroRenderKey(this.entryPhoto.imageUrl, pinUrl), url: this.entryPhoto.imageUrl,
        pinUrl: pinUrl, revision: this.heroRenderRevision }, next];
    }
    return [next];
  }

  private completeHeroSource(source: DetailHeroSource, pinUrl: string, imageUrl: string): void {
    if (!this.heroVisible || pinUrl !== this.displayedDetail().pinUrl || source.pinUrl !== pinUrl ||
      source.url !== imageUrl || source.key !== this.heroRenderKey(imageUrl, pinUrl)) return;
    const currentKey: string = this.heroRenderKey(this.displayedDetail().imageUrl, pinUrl);
    if (source.key === currentKey) {
      this.notifyImageLoaded(pinUrl, imageUrl);
    } else if (this.entryPhoto?.pinUrl === pinUrl && this.entryPhoto.imageUrl === imageUrl &&
      this.decodedHeroSource?.key !== currentKey) {
      this.decodedHeroSource = source;
    }
  }

  private heroRenderKey(url: string, pinUrl: string): string {
    return pinUrl + ':' + url + ':' +
      this.heroRenderRevision.toString();
  }

  private shufflePreview(item: PinmonyShuffleItem | undefined): PinmonyDetailSnapshot | undefined {
    return item?.pinId ? this.shufflePreviews.find((entry: PinmonyDetailSnapshot): boolean =>
      entry.pinUrl.split('/pin/')[1]?.split('/')[0] === item.pinId) : undefined;
  }

  @Builder
  private shuffleSelectedCard(item: PinmonyShuffleItem) {
    Column({space:12}) {
      Row({space:12}) {
        Image(item.imageUrl || '').width(64).height(88).objectFit(ImageFit.Cover).borderRadius(10)
          .onComplete(() => this.shuffleImageReady('card:' + (item.imageUrl || '')))
          .onError(() => this.shuffleImageReady('card:' + (item.imageUrl || '')))
        Column({space:6}) {
          Text((item.id === this.shuffleItems[this.shuffleIndex]?.id ? this.currentDetail.title : '') || this.shufflePreview(item)?.title || '').fontSize(16).fontWeight(FontWeight.Medium).maxLines(2)
            .fontColor($r('app.color.primary_text')).textOverflow({overflow:TextOverflow.Ellipsis})
          Text((item.id === this.shuffleItems[this.shuffleIndex]?.id ? this.currentDetail.creator : '') || this.shufflePreview(item)?.creator || '').fontSize(13).maxLines(1).fontColor($r('app.color.secondary_text'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').height(88)
        .scale({ x: this.shufflePressedItem === item.id ? this.shufflePressScale : 1,
          y: this.shufflePressedItem === item.id ? this.shufflePressScale : 1 })
        .onTouch((event: TouchEvent) => {
          if(event.type === TouchType.Down)this.shufflePress(item.id, true);
          else if(event.type === TouchType.Up || event.type === TouchType.Cancel)this.shufflePress(item.id, false);
        })
        .accessibilityText(this.uiText('pm_open_original_pin_42977656'))
        .onClick(() => {
          if (this.videoActive && this.readsReady && item.id === this.shuffleItems[this.shuffleIndex]?.id) this.onShuffleDetail?.(this.currentDetail.pinUrl);
        }, 8)
      if (item.id === this.shuffleItems[this.shuffleIndex]?.id && this.contentError) {
        PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.contentError,this.uiLanguage), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => this.onContentRetry?.(), actionEnabled: this.contentRetryable })
      }
      Row({space:12}) {
          Button({type:ButtonType.Normal}) {
            Text(item.id === this.shuffleItems[this.shuffleIndex]?.id && this.action('save')?.selected ? PinmonyI18n.render(this.action('save')!.label,this.uiLanguage) : this.uiText('pm_save_60a53514'))
              .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .maxLines(2).textAlign(TextAlign.Center).textOverflow({overflow:TextOverflow.Ellipsis})
          }
            .height('auto').constraintSize({ minHeight: 44 }).padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .layoutWeight(1).borderRadius(16).backgroundColor($r('app.color.detail_save_accent')).fontColor(Color.White)
            .accessibilityText(item.id === this.shuffleItems[this.shuffleIndex]?.id && this.action('save')?.selected ? PinmonyI18n.render(this.action('save')!.label,this.uiLanguage) : this.uiText('pm_save_60a53514'))
            .enabled(this.videoActive)
            .onClick(() => {
              const action: PinmonyDetailAction | undefined = this.action('save');
              if (item.id === this.shuffleItems[this.shuffleIndex]?.id && action && !this.saveBusy && this.acceptsActionIntent(action)) this.onAction?.(action.id,action.kind);
            })
        if ((item.id === this.shuffleItems[this.shuffleIndex]?.id && this.currentDetail.sourceUrl && this.action('source')) ||
            this.shufflePreview(item)?.sourceUrl) {
          Button(this.uiText('pm_visit_website_04913c22'),{type:ButtonType.Normal})
            .height(44).layoutWeight(1).borderRadius(16).backgroundColor($r('app.color.shuffle_visit_background')).fontColor($r('app.color.primary_text'))
            .enabled(this.videoActive)
            .onClick(() => {
              const action: PinmonyDetailAction | undefined = this.action('source');
              if (item.id === this.shuffleItems[this.shuffleIndex]?.id && action && this.acceptsActionIntent(action)) this.onAction?.(action.id,action.kind);
            })
        }
      }.width('100%').height(44)
    }.width('100%').constraintSize({minHeight:188}).padding(16).borderRadius(18)
      .backgroundEffect({radius:28 * this.shuffleBackdropOpacity,saturation:1,brightness:1,color:$r('app.color.shuffle_card_glass')})
  }

  @Builder
  private shuffleViewerContent() {
      Stack() {
        Swiper() {
          ForEach(this.shuffleItems, (item: PinmonyShuffleItem) => {
            Column({space:16}) {
              Image(this.shufflePhotoUrl(item)).width('100%').layoutWeight(1).objectFit(ImageFit.Contain)
                .opacity(this.shufflePageOpacity(item.id))
                .id('pinmony-shuffle-photo-' + this.traceId + '-' + item.id)
                .alt(item.imageUrl || '')
                .onComplete(() => this.shuffleImageReady('photo:' + this.shufflePhotoUrl(item)))
                .onError(() => this.shuffleImageReady('photo:' + this.shufflePhotoUrl(item)))
                .onClick(() => {
                  this.closeShuffleViewer(item.id);
                }, 8)
              Scroll() { this.shuffleSelectedCard(item) }.width('100%').height(188)
                .opacity(this.shuffleBackdropOpacity)
            }.width('100%').height('100%').padding({top:16,bottom:16})
          }, (item: PinmonyShuffleItem): string => item.id + ':' + this.uiLanguage)
        }.width('100%').height('100%').index(this.shuffleIndex).loop(false).indicator(false)
          .prevMargin(20).nextMargin(20).itemSpace(12)
          .disableSwipe(!this.videoActive || this.shuffleFlightActive)
          .onChange((index: number) => {
            if (index !== this.shuffleIndex && this.videoActive && this.shuffleViewerVisible() && this.shuffleItems[index] &&
              this.shuffleItems[index].id !== this.shuffleFlightItem) {
              const item: PinmonyShuffleItem = this.shuffleItems[index];
              this.shuffleFlightItem = item.id;
              this.shuffleFlightSource = this.shuffleItemOrigin(item, this.shuffleSourceOnCanvas);
              this.onShufflePin?.(this.shuffleItems[index].id);
            }
          })
      }.width('100%').height('100%').clip(true)
  }

  @Builder
  private shuffleOverlay() {
    Stack() {
      // Keep filter strength and the filtered Image's own alpha on the same
      // flight progress, including the committed source and return endpoint.
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
        .opacity(this.shuffleBackdropOpacity).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Image(this.shuffleBackdrop || this.displayedDetail().imageUrl).width('100%').height('100%')
          .objectFit(ImageFit.Cover).blur(80 * this.shuffleBackdropOpacity)
          .opacity(0.5 * this.shuffleBackdropOpacity)
          .onComplete((event) => {
            if (event?.loadingStatus !== 0 && event?.loadingStatus !== 1) return;
            this.shuffleReadyBackdrop = this.shuffleBackdrop || this.displayedDetail().imageUrl;
            this.shuffleImageReady('backdrop');
          })
          .onError(() => {
            this.shuffleReadyBackdrop = this.shuffleBackdrop || this.displayedDetail().imageUrl;
            this.shuffleImageReady('backdrop');
          })
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      if (this.shuffleSelectedImage && this.shuffleItems.length > 0) {
        Column() { this.shuffleViewerContent() }.width('100%').height('100%')
          .opacity(this.shuffleViewerVisible() && !this.shuffleFlightPreparing ? 1 : 0)
          .hitTestBehavior(this.shuffleViewerVisible() && !this.shuffleFlightActive && !this.shuffleFlightPreparing ? HitTestMode.Default : HitTestMode.None)
          .accessibilityLevel(this.shuffleViewerVisible() && !this.shuffleFlightActive && !this.shuffleFlightPreparing ? 'auto' : 'no-hide-descendants')
      }
      if (this.shuffleSelectedImage && !this.shuffleFullDetail && !this.shuffleViewerVisible()) {
        LoadingProgress().width(28).height(28).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
      }
      if (this.shuffleFlightActive) {
        Image(this.shuffleFlightImage).objectFit(ImageFit.Contain)
          .width(this.shuffleFlightFrame.width).height(this.shuffleFlightFrame.height)
          .borderRadius(this.shuffleFlightRadius).clip(true)
          .position({ x: this.shuffleFlightFrame.x, y: this.shuffleFlightFrame.y })
          .rotate({ angle: this.shuffleFlightRotation })
          .scale({ x: this.shuffleFlightScale, y: this.shuffleFlightScale })
          .onComplete((event) => this.shuffleFlightImageComplete(event?.loadingStatus ?? -1))
          .onError(() => this.failShuffleFlight())
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
    }.width('100%').height('100%').clip(true)
      .hitTestBehavior(this.shuffleOverlayVisible() ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.shuffleOverlayVisible() ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  private detailContent() {
    Stack() {
    Column() {
      WaterFlow({ scroller: this.detailScroller, sections: this.detailSections }) {
        // Keep the media subtree alive when scrolling into recommendations.
        // It still scrolls as the first section, using the same Scroller.
        FlowItem() {
          Column({ space: 18 }) {
            this.detailHeader()
            if (this.displayedDetail().dataSource === 'api' && !this.isRecommendReady()) {
              Text(this.uiText("pm_more_to_explore_f7cba896")).fontSize(23).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).width('100%').margin({ top: 4 })
              this.recommendationSkeleton()
            } else if (this.displayedDetail().related.length > 0 && this.isRecommendReady()) {
              Text(this.uiText("pm_more_to_explore_f7cba896")).fontSize(23).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).width('100%').margin({ top: 4 })
            }
          }.width('100%').padding({ top: this.titleContentInset() + 8, bottom: 18 })
        }.width('100%')
        LazyForEach(this.detailRows, (row: PinmonyDetailFlowRow) => {
          FlowItem() {
            if (row.kind === 'footer') {
              this.detailFooter()
            } else if (row.pin) {
              if (row.pin.kind === 'topics') this.relatedTopicModule(row.pin)
              else this.relatedCard(row.pin)
            }
          }.width('100%')
        }, (row: PinmonyDetailFlowRow, index: number): string => this.detailRows.renderKey(row, index))
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .scrollBarMargin({ start: LengthMetrics.vp(this.titleContentInset()) })
      .padding({ left: 18, right: 18 })
      // Draw nearby cached items so native Image can prepare them before entry.
      // Keep the stateful header and stable recommendation keys retained.
      .cachedCount(12, true)
      .edgeEffect(EdgeEffect.Spring)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width: number = Number(newArea.width);
        if (width > 0 && Math.abs(width - this.contentWidth) > 1) {
          this.contentWidth = width;
          this.syncDetailFlow();
          this.updateDetailLayout();
          this.auditRecommendationLayout();
        }
      })
      .onAppear(() => this.restoreScrollPosition())
      .onScrollFrameBegin((offset: number, state: ScrollState) => {
        if (!this.restoringScroll && state === ScrollState.Scroll && offset > 0) this.restoredPaginationAllowed = true;
        return { offsetRemain: offset };
      })
      .onDidScroll(() => this.reportScrollPosition())
      .onScrollStop(() => this.reportScrollPosition(true))
      .onReachEnd(() => {
        if (!this.restoredPaginationAllowed) return;
        if (!this.readsReady && (this.displayedDetail().kind === 'cached' || this.displayedDetail().relatedRetained)) {
          PinmonyRuntimeLog.info('RecommendAudit: pagination.blocked reason=cached-presentation');
          return;
        }
        if (!this.isRecommendReady()) {
          PinmonyRuntimeLog.info('RecommendAudit: pagination.blocked reason=recommend-not-ready');
          return;
        }
        if (!this.readsReady && !this.displayedDetail().interactionsSettled) {
          PinmonyRuntimeLog.info('RecommendAudit: pagination.blocked reason=interactions-pending');
          return;
        }
        if ((this.actionsReady || this.readsReady) && !this.displayedDetail().relatedError && this.onLoadMore) this.onLoadMore();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    // Retain the collage beneath the fading background; interaction stays isolated.
    .hitTestBehavior(this.shuffleOverlayVisible() ? HitTestMode.None : HitTestMode.Default)
    .accessibilityLevel(this.shuffleOverlayVisible() ? 'no-hide-descendants' : 'auto')
    }.width('100%').height('100%').id('pinmony-shuffle-motion-root-' + this.traceId)
  }

  @Builder
  private videoRetryNotice() {
    if (!this.imageLayer && this.displayedDetail().isVideo && this.displayedDetail().video &&
        !this.mediaReadBusy && !this.displayedDetail().mediaLoading && (this.displayedDetail().videoError || this.videoFailure)) {
      Row({ space: 8 }) {
        PinmonyActionNotice({ active: this.videoActive, message: PinmonyI18n.render(this.displayedDetail().videoError || this.videoFailure, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => {
            if (this.displayedDetail().videoError) { if (this.onVideoRetry) this.onVideoRetry(); }
            else {
              this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0 });
              this.videoRetryRevision = (this.videoRetryRevision + 1) % 1000000;
            }
          }, actionEnabled: this.videoActive && (this.actionsReady || !!this.displayedDetail().videoError) })
        PinmonyActionNotice({ active: this.videoActive, message: this.uiText("pm_reload_url_84763306"), actionText: this.uiText("pm_reload_url_84763306"), onAction: () => {
            PinmonyRuntimeLog.info('VideoTrace: openId=' + this.traceId.toString() + ' event=refresh-requested');
            if (this.onVideoRetry) this.onVideoRetry();
          }, actionEnabled: this.videoActive && !!this.onVideoRetry })
      }.width('100%').padding(10)
        .backgroundColor($r('app.color.input_surface')).borderRadius(12)
    }
  }

  @Builder
  private detailDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack() {
        Column() { this.detailContent() }.width('100%').height('100%')
          .hitTestBehavior(this.searchMounted ? HitTestMode.None : HitTestMode.Default)
      if (this.searchMounted) {
        Column() {
        PinmonyVisualSearchView({ pin: this.displayedDetail().pinUrl, imageUrl: this.displayedDetail().imageUrl || this.displayedDetail().originalImageUrl,
          imageWidth: this.displayedDetail().imageWidth, imageHeight: this.displayedDetail().imageHeight, result: this.visualResult,
          presentationActive: this.pageActive,
          animatePhoto: true, originX: this.searchOrigin.x, originY: this.searchOrigin.y,
          originWidth: this.searchOrigin.width, originHeight: this.searchOrigin.height, closing: this.searchClosing,
          onPhotoFrame: (x: number, y: number, width: number, height: number, radius: number, duration: number, chrome: number) => {
            this.updateSearchFlightFrame(x, y, width, height, radius, duration, chrome);
          },
          onPhotoSelection: (crop: PinmonyImageCrop) => { this.searchFlightCrop = crop; },
          onPhotoFlight: (active: boolean) => { this.searchPhotoFlying = active; },
          onTransitionReady: () => { this.searchImageReady = true; },
          onTransitionClosed: () => { this.searchMounted = false; this.searchImageReady = false; this.searchClosing = false; this.searchPhotoFlying = false; },
          onSearch: this.onVisualSearch,
          onClose: () => { if (this.onImageLayer) this.onImageLayer(''); },
          onRelated: (id: string) => {
            if (this.onVisualResult) return this.onVisualResult(id);
            if (this.onRelated) this.onRelated(id);
            return true;
          } })
        }.width('100%').height('100%').padding({ top: this.titleContentInset() })
      }
      }.width('100%').height('100%')
    }
    .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleBarOptions(), this.hdsDarkMode))
    .bindToScrollable(this.imageLayer === 'search' ? [] : [this.detailScroller])
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    // Keep the title-bar geometry stable while the image is flying in or out.
    .hideTitleBar(false)
    .onBackPressed(() => {
      if (!this.pageActive) { this.onCoveredBack?.(); return true; }
      PinmonyRuntimeLog.info('PinmonyReturn: detail destination back');
      if (this.searchMounted && this.searchClosing) return true;
      if (this.shuffleFlightActive) return true;
      if (this.shuffleViewerVisible()) {
        this.closeShuffleViewer(this.shuffleItems[this.shuffleIndex]?.id || '');
        return true;
      }
      if (this.imageLayer && this.onImageLayer) this.onImageLayer('');
      else if (this.onBack) this.onBack();
      return true;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], this.imageLayer === 'search' ?
      [LayoutSafeAreaEdge.TOP] : [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Stack() {
      HdsNavigation(this.detailPathStack) {
        Column().width('100%').height('100%')
      }
      .width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.detailDestination).backgroundColor($r('app.color.page_background'))
      .hitTestBehavior(this.viewerMounted || this.shuffleOverlayVisible() ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(this.shuffleOverlayVisible() ? 'no-hide-descendants' : 'auto')
      .opacity(this.entryOpacity)
      .scale({ x: this.entryScale, y: this.entryScale })
      if (this.searchMounted) {
        // Fixed local artwork: only its common parent transforms during flight.
        Stack({ alignContent: Alignment.TopStart }) {
        Image(this.displayedDetail().imageUrl || this.displayedDetail().originalImageUrl)
          .width(this.searchFlightBaseWidth).height(this.searchFlightBaseHeight).objectFit(ImageFit.Contain)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        PinmonyImageSearchSelection({ photoWidth: this.searchFlightBaseWidth, photoHeight: this.searchFlightBaseHeight,
          crop: this.searchFlightCrop })
          .opacity(this.searchFlightChrome)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }.width(this.searchFlightBaseWidth).height(this.searchFlightBaseHeight)
          .borderRadius(this.searchFlightRadius).clip(true)
          .position({ x: 0, y: 0 })
          .scale({ x: this.searchFlightFrame.width / this.searchFlightBaseWidth,
            y: this.searchFlightFrame.height / this.searchFlightBaseHeight, centerX: 0, centerY: 0 })
          .translate({ x: this.searchFlightFrame.x, y: this.searchFlightFrame.y })
          .opacity(this.searchImageReady && this.searchPhotoFlying ? 1 : 0)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      if (this.shuffleSelectedImage && !this.shuffleFullDetail) {
        this.shuffleOverlay()
      }
      if (this.entryPhoto && (!this.entryMotionComplete || this.entryClosing)) {
        PinmonyDetailEntryMotion({ photo: this.entryPhoto,
          targetId: 'pinmony-entry-target-' + this.traceId.toString(),
          rootId: 'pinmony-photo-root-' + this.traceId.toString(),
          imageWidth: this.displayedDetail().imageWidth, imageHeight: this.displayedDetail().imageHeight,
          restoredOffset: this.initialScrollOffset,
          bottomInset: !this.displayedDetail().carousel?.freeScroll &&
            (this.displayedDetail().mediaKind === 'carousel' || !!this.displayedDetail().carousel) ? 28 : 0, closing: this.entryClosing,
          onReveal: (closing: boolean, pageExit: boolean) => {
            this.entryPhotoHidden = !pageExit;
            this.getUIContext().animateTo({ duration: closing ? 200 : 240, curve: Curve.EaseOut }, () => {
              this.entryScale = closing && pageExit ? 0.97 : 1;
              this.entryOpacity = closing ? 0 : 1;
            });
          },
          onOpened: () => { this.entryOpacity = 1; this.entryScale = 1; this.entryPhotoHidden = false; this.entryMotionComplete = true; },
          onClosed: () => { this.entryPhotoHidden = false; this.onEntryClosed?.(); } })
          .hitTestBehavior(HitTestMode.None)
      }
      if (this.viewerMounted) {
        PinmonyImageViewer({ detail: this.displayedDetail(), imageUrl: this.zoomImageUrl || this.displayedDetail().originalImageUrl || this.displayedDetail().imageUrl,
          previewUrl: this.zoomImageUrl || this.displayedDetail().imageUrl,
          onImageChange: (url: string) => { this.zoomImageUrl = url; },
          origin: this.viewerOrigin, closing: this.viewerClosing,
          onReady: () => { this.viewerImageReady = true; },
          onClosed: () => {
            // The close animation can finish before the parent receives the new layer prop.
            // `viewerClosing` is the local source of truth for that transition, so the
            // carousel (including its indicator) is always restored after the viewer exits.
            if (this.imageLayer !== 'zoom' || this.viewerClosing) {
              this.viewerMounted = false;
              this.viewerImageReady = false;
              this.viewerClosing = false;
            }
          },
          active: this.videoActive,
          actionsReady: this.actionsReady,
          onClose: () => { if (this.onImageLayer) this.onImageLayer(''); }, onAction: this.onAction,
          onDownload: this.onDownload, onSave: this.onViewerSave,
          onControlsChange: (visible: boolean) => { this.viewerControls = visible; } })
      }
    }.width('100%').height('100%').id('pinmony-photo-root-' + this.traceId.toString())
      .onAreaChange((_old: Area, area: Area) => {
        const width: number = Number(area.width);
        const height: number = Number(area.height);
        if (width > 0 && height > 0) {
          this.viewportWidth = width;
          this.viewportHeight = height;
          this.updateDetailLayout();
        }
      }).backgroundColor(this.entryPhoto ? Color.Transparent : $r('app.color.page_background'))
  }

}
