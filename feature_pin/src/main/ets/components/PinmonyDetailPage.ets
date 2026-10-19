import { PinmonyImageViewer } from './PinmonyImageViewer';
import { splitDescriptionTags, PinmonyDescriptionPart } from '../services/PinmonyDescriptionTags';
import { PinmonyVisualSearchView } from './PinmonyVisualSearchView';
import { PinmonyImageCrop, PinmonyVisualResult, emptyVisualResult } from '../models/PinmonyVisualSearch';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyDetailAction, PinmonyDetailSnapshot, PinmonyRelatedPin } from '../models/PinmonyDetail';
import { PinmonyCarouselView } from './PinmonyCarouselView';
import { PinmonyVideoPlayer } from './PinmonyVideoPlayer';
import { PinmonyDetailHero, DetailHeroSource } from './PinmonyDetailHero';
import { display } from '@kit.ArkUI';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { SmartImage, getRecommendCardWidth, getRecommendColumnCount, RECOMMEND_CARD_RADIUS_VP,
  RECOMMEND_PHONE_GAP_VP, RECOMMEND_WIDE_GAP_VP } from 'common_ui';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';

@Component
export struct PinmonyDetailPage {
  @Prop @Watch('onPinChanged') detail: PinmonyDetailSnapshot = {} as PinmonyDetailSnapshot;
  @Prop @Watch('onRenderIdentityChanged') renderIdentity: string = '';
  @Prop traceId: number = 0;
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
  private onImageLayerChanged(): void { this.viewerControls = true; }
  @Prop visualResult: PinmonyVisualResult = emptyVisualResult();
  @State private zoomImageUrl: string = '';
  @State private searchLabelVisible: boolean = true;
  private searchLabelTimer: number = -1;
  onImageLayer?: (layer: string) => void;
  onVisualSearch?: (crop: PinmonyImageCrop, append: boolean, first: boolean) => void;
  onDownload?: () => void;
  onViewerSave?: () => void;
  onTagSearch?: (query: string, pin: string) => void;
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
  private readonly detailPathStack: NavPathStack = new NavPathStack();
  private lastReportedScrollOffset: number = 0;
  private lastRecommendAuditKey: string = '';
  private activePin: string = '';
  onBack?: () => void;
  onUser?: (url: string) => void;
  onAction?: (id: string, kind: string) => void;
  onRelated?: (id: string) => void;
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
    if (this.activePin !== this.detail.pinUrl) {
      this.activePin = this.detail.pinUrl;
      this.decodedHeroSource = undefined;
      this.expanded = false;
      this.zoomImageUrl = '';
      this.textOverflowing = false;
      this.videoFailure = ''; this.videoRetryRevision = 0;
      this.restoreScrollPosition();
      this.startSearchLabel();
      if (this.onImageLayer) this.onImageLayer('');
    }
    this.updateDetailLayout();
    this.auditRecommendationGate('detail-update');
  }

  private notifyImageLoaded(pinUrl: string, imageUrl: string): void {
    if (pinUrl === this.detail.pinUrl && imageUrl === this.detail.imageUrl) {
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
    this.activePin = this.detail.pinUrl;
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
    this.heroVisible = false;
    clearTimeout(this.searchLabelTimer);
  }

  private retryHeroImage(key: string): void {
    if (!this.heroVisible || !this.detail.imageUrl || key !== this.heroRenderKey(this.detail.imageUrl, this.detail.pinUrl)) return;
    this.heroRenderRevision = (this.heroRenderRevision + 1) % 2147483647;
    this.lastImageNotification = '';
    if (this.onContentRetry) this.onContentRetry();
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const share: PinmonyDetailAction | undefined = this.action('share');
    if (this.imageLayer === 'search') {
      return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        style: { scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }, scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
        content: { title: { mainTitle: '图片搜索' }, menu: { value: [] }, backIcon: { label: '返回', isEnabled: true,
          action: () => { if (this.onImageLayer) this.onImageLayer(''); } } } };
    }
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: {
          backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0
        } }
      },
      content: {
        title: { mainTitle: '' },
        backIcon: { isEnabled: true, label: '返回', action: () => { if (this.onBack) this.onBack(); } },
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

  private restoreScrollPosition(): void {
    const offset: number = Math.max(0, this.initialScrollOffset);
    const pin: string = this.detail.pinUrl;
    setTimeout(() => {
      if (this.detail.pinUrl !== pin) return;
      try {
        this.detailScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
      } catch (error) {
        PinmonyRuntimeLog.warn('Pinmony: detail scroll restoration unavailable');
      }
    }, 0);
  }

  private reportScrollPosition(force: boolean = false): void {
    try {
      const position = this.detailScroller.offset();
      if (!position) return;
      const offset: number = Math.max(0, position.yOffset);
      if (!force && Math.abs(offset - this.lastReportedScrollOffset) < 8) return;
      this.lastReportedScrollOffset = offset;
      if (this.onScrollPosition) this.onScrollPosition(this.detail.pinUrl, offset);
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: detail scroll position unavailable');
    }
  }

  private action(kind: string): PinmonyDetailAction | undefined {
    const item: PinmonyDetailAction | undefined = this.detail.actions.find((value: PinmonyDetailAction): boolean => value.kind === kind);
    if(!item && kind === 'share' && this.shareActionsReady)return {id:'native-share',kind:'share',label:'分享',countText:'',enabled:true,selected:false};
    return item;
  }

  private leftActions(): PinmonyDetailAction[] {
    const available: PinmonyDetailAction[] = this.detail.actions.filter((item: PinmonyDetailAction): boolean =>
      item.kind === 'like' || item.kind === 'comment' || item.kind === 'more');
    if (this.detail.dataSource !== 'api') return available;
    const kinds: string[] = ['like', 'comment'];
    const result: PinmonyDetailAction[] = kinds.map((kind: string): PinmonyDetailAction => {
      const real: PinmonyDetailAction | undefined = available.find((item: PinmonyDetailAction): boolean => item.kind === kind);
      if (real && (this.readsReady || this.detail.imageStageReady && (this.actionsReady || this.postActionsReady && kind === 'like' || this.commentActionsReady && kind === 'comment') ||
          this.detail.kind === 'cached' || this.detail.actionsRetained)) return real;
      return { id: 'pending-' + kind, kind: kind, label: kind === 'like' ? '点赞' : '评论',
        countText: '', enabled: false, selected: false };
    });
    return result.concat(available.filter((item: PinmonyDetailAction): boolean => item.kind === 'more'));
  }

  private actionIcon(action: PinmonyDetailAction): Resource {
    if (action.kind === 'like') {
      return action.selected ? $r('app.media.lucide_heart_filled') : $r('app.media.lucide_heart');
    }
    if (action.kind === 'comment') return $r('app.media.lucide_message_circle');
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
    return this.detail.dataSource !== 'api' || this.detail.imageStageReady === true;
  }

  private isCommentsReady(): boolean {
    return this.readsReady || this.detail.dataSource !== 'api' || this.detail.interactionsSettled === true;
  }

  private isRecommendReady(): boolean {
    return this.detail.kind === 'cached' || this.detail.relatedRetained === true ||
      this.detail.related.length > 0 || this.detail.relatedEnded === true || !!this.detail.relatedError;
  }

  private recommendCardHeight(cardWidth: number, pin: PinmonyRelatedPin): number {
    return this.imageHeight(cardWidth, pin.imageWidth, pin.imageHeight);
  }

  private recommendDensity(): number {
    try {
      const value: number = Number(display.getDefaultDisplaySync().densityPixels);
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
      ':' + (this.detail.imageStageReady === true ? '1' : '0') + ':' + (this.detail.interactionsSettled === true ? '1' : '0');
    if (key === this.lastRecommendAuditKey) return;
    this.lastRecommendAuditKey = key;
    PinmonyRuntimeLog.info('RecommendAudit: gate reason=' + reason + ' main=' +
      (this.isMainImageReady() ? 'ready' : 'pending') + ' interactions=' +
      (this.isCommentsReady() ? 'ready' : 'pending') + ' ready=' + (ready ? 'ready' : 'blocked') +
      ' presentation=' + (this.detail.kind === 'cached' || this.detail.relatedRetained ? 'cached' : 'current') +
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
      this.textOverflowing = !!this.detail.title || !!this.detail.description;
      if (!this.textMeasureWarned) PinmonyRuntimeLog.warn('DetailTrace: text measurement unavailable');
      this.textMeasureWarned = true;
    }
  }

  private measureTextOverflow(): void {
    const utils = this.getUIContext().getMeasureUtils();
    const width: string = this.detailPaneWidth().toString() + 'vp';
    const title = utils.measureTextSize({ textContent: this.detail.title, fontSize: '26fp',
      fontWeight: FontWeight.Bold, constraintWidth: width });
    const shortTitle = utils.measureTextSize({ textContent: this.detail.title, fontSize: '26fp',
      fontWeight: FontWeight.Bold, constraintWidth: width, maxLines: 2 });
    const description = utils.measureTextSize({ textContent: this.detail.description, fontSize: '16fp',
      lineHeight: '24vp', constraintWidth: width });
    const shortDescription = utils.measureTextSize({ textContent: this.detail.description, fontSize: '16fp',
      lineHeight: '24vp', constraintWidth: width, maxLines: 2 });
    this.textOverflowing = Number(title.height) > Number(shortTitle.height) + 1 ||
      Number(description.height) > Number(shortDescription.height) + 1;
  }

  private heroHeight(): number {
    const width: number = this.detailPaneWidth();
    if (this.detail.imageWidth <= 0 || this.detail.imageHeight <= 0) return width * 1.15;
    return Math.min(1200, width * this.detail.imageHeight / this.detail.imageWidth);
  }

  private acceptsActionIntent(item: PinmonyDetailAction): boolean {
    if (item.kind === 'save' && this.saveBusy || item.kind === 'like' && this.likeBlocked) return false;
    if (item.kind === 'share' && this.shareActionsReady) return true;
    if (item.kind === 'more' && this.menuActionsReady) return true;
    return (this.commentActionsReady && item.kind === 'comment') || (this.postActionsReady && (item.kind === 'save' || item.kind === 'like' && !item.selected)) || (this.actionsReady && item.enabled) ||
      (this.deferredActions && /^(like|comment|save|share|more|source)$/.test(item.kind));
  }

  private creatorFontSize(): number {
    try {
      const utils = this.getUIContext().getMeasureUtils();
      const width: string = Math.max(1, this.detailPaneWidth() - (this.detail.creatorAvatar ? 42 : 0)).toString() + 'vp';
      const full = utils.measureTextSize({ textContent: this.detail.creator, fontSize: '18fp',
        fontWeight: FontWeight.Medium, constraintWidth: width });
      const single = utils.measureTextSize({ textContent: this.detail.creator, fontSize: '18fp',
        fontWeight: FontWeight.Medium, constraintWidth: width, maxLines: 1 });
      return Number(full.height) > Number(single.height) + 1 ? 16 : 18;
    } catch (_) { return 18; }
  }

  private actionCountText(item: PinmonyDetailAction): string {
    const count: string = (item.countText || '').trim();
    if ((item.kind === 'like' || item.kind === 'comment') && count === '0') return '';
    return count;
  }

  @Builder
  private iconAction(item: PinmonyDetailAction) {
    Row({ space: 2 }) {
      Button({ type: ButtonType.Circle }) {
        Image(this.actionIcon(item))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .enabled(this.acceptsActionIntent(item))
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
          heightVp: this.recommendCardHeight(this.recommendCardWidth(), pin),
          targetPx: this.recommendCardWidth() * this.recommendDensity(), borderRadiusVp: RECOMMEND_CARD_RADIUS_VP,
          onLoaded: () => {
            if (this.onRelatedImageLoaded && this.detail.related.some((item: PinmonyRelatedPin): boolean =>
              item.id === pin.id && item.imageUrl === pin.imageUrl)) this.onRelatedImageLoaded(this.detail.pinUrl);
          }, onError: (code: number) => {
            PinmonyRuntimeLog.warn('RecommendImageError: code=' + code.toString());
          }, onTrace: (event: string, revision: number, tier: string, elapsedMs: number) => {
            PinmonyRuntimeLog.info('RecommendImageTrace: openId=' + this.traceId.toString() +
              ' index=' + this.detail.related.findIndex((item: PinmonyRelatedPin): boolean => item.id === pin.id) +
              ' event=' + event + ' revision=' + revision.toString() + ' tier=' + tier +
              ' elapsedMs=' + elapsedMs.toString());
          }, onAudit: (tier: string, targetPx: number, sourceHeightPx: number) =>
            this.auditRecommendationImage(tier, targetPx, sourceHeightPx) })
          .width('100%')
          .height(this.recommendCardHeight(this.recommendCardWidth(), pin))
        if (pin.title.length > 0) {
          Text(pin.title)
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
    .enabled(((this.readsReady || this.actionsReady && this.detail.kind !== 'cached' && !this.detail.relatedRetained) || this.deferredActions))
    .onClick(() => {
      if (((this.readsReady || this.actionsReady && this.detail.kind !== 'cached' && !this.detail.relatedRetained) || this.deferredActions) && this.onRelated)
        this.onRelated(pin.id);
    })
    .accessibilityText(pin.title.length > 0 ? pin.title : '打开相关 Pin')
  }

  private relatedColumn(index: number, columnCount: number): PinmonyRelatedPin[] {
    return this.detail.related.filter((_pin: PinmonyRelatedPin, pinIndex: number): boolean =>
      pinIndex % columnCount === index);
  }

  @Builder
  private relatedCards(index: number, columnCount: number) {
    Column({ space: 18 }) {
      // Include the image source in the reuse key so a reused Pin card cannot
      // retain the previous bitmap when its recommendation source changes.
      ForEach(this.relatedColumn(index, columnCount), (pin: PinmonyRelatedPin) => {
        this.relatedCard(pin)
      }, (pin: PinmonyRelatedPin) => pin.id + ':' + pin.imageUrl)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
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

  @Builder
  private detailMedia() {
    Column() {
          if (this.detail.carousel) {
            PinmonyCarouselView({ carousel: this.detail.carousel, contentWidth: this.detailPaneWidth(),
              onFirstImageSettled: (failed: boolean) => {
                if (failed) { if (this.onImageError) this.onImageError(this.detail.pinUrl); }
                else this.notifyImageLoaded(this.detail.pinUrl, this.detail.imageUrl);
              },
              onImageTap: (url: string) => { this.zoomImageUrl = url; if (this.onImageLayer) this.onImageLayer('zoom'); } })
          } else if (((this.detail.mediaLoading || this.mediaReadBusy) && !this.detail.video) || (this.detail.mediaKind === 'carousel' && !this.detail.carousel)) {
            Stack({ alignContent: Alignment.Center }) {
              if (this.detail.imageUrl) this.heroImage()
              if (this.detail.mediaLoading || this.mediaReadBusy) {
                LoadingProgress().width(28).height(28).color($r('app.color.accent'))
                  .accessibilityText('正在加载媒体内容')
              } else {
                Column({ space: 12 }) {
                  Text(this.detail.mediaError || '多图内容暂不可用').fontColor($r('app.color.primary_text'))
                  Button('重新读取媒体').onClick(() => { if (this.onVideoRetry) this.onVideoRetry(); })
                }.padding(16).borderRadius(12).backgroundColor($r('app.color.page_background'))
              }
            }.width('100%').height(this.heroHeight()).backgroundColor($r('app.color.surface_muted')).borderRadius(18).clip(true)
          } else if (this.detail.video && this.detail.isVideo) {
            PinmonyVideoPlayer({ video: this.detail.video, poster: this.detail.imageUrl, active: this.videoActive, openId: this.traceId,
              mediaOwner: this.detail.pinUrl + '|' + this.traceId.toString(),
              sessionReady: this.actionsReady || this.readsReady,
              readingAddress: this.detail.mediaLoading === true || this.mediaReadBusy,
              retryRevision: this.videoRetryRevision,
              onFailureChanged: (pinId: string, message: string) => {
                if (this.detail.video?.pinId === pinId) this.videoFailure = message;
              },
              onPosterSettled: (failed: boolean) => {
                if (failed) { if (this.onImageError) this.onImageError(this.detail.pinUrl); }
                else this.notifyImageLoaded(this.detail.pinUrl, this.detail.imageUrl);
              } })
          } else if (this.detail.isVideo) {
            Stack({ alignContent: Alignment.Center }) {
              Image(this.detail.imageUrl).width('100%')
                .height(this.heroHeight())
                .objectFit(ImageFit.Contain)
                .onComplete((event) => {
                  if (event?.loadingStatus === 1) this.notifyImageLoaded(this.detail.pinUrl, this.detail.imageUrl);
                })
                .onError(() => { if (this.onImageError) this.onImageError(this.detail.pinUrl); })
              Column({ space: 12 }) {
                Text(this.detail.videoError || '暂无可播放视频地址').fontColor($r('app.color.primary_text'))
                Button('重新读取视频').onClick(() => { if (this.onVideoRetry) this.onVideoRetry(); })
              }.padding(16).borderRadius(12).backgroundColor($r('app.color.page_background'))
            }.width('100%').borderRadius(18).clip(true)
          } else {
           Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.detail.imageUrl) {
            this.heroImage()
          }

            if (this.detail.aiLabel) {
              Row() {
                Text(this.detail.aiLabel).fontSize(14).fontColor(Color.White)
                  .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                  .backgroundColor('#B34B4F52').borderRadius(16)
                  .accessibilityText(this.detail.aiLabel)
              }.width('100%').justifyContent(FlexAlign.Start).padding(8)
                .hitTestBehavior(HitTestMode.None)
            }
            Button({ type: ButtonType.Normal }) {
              Row() {
                Text('搜索图片').fontSize(14).fontColor(Color.White)
                  .width(this.searchLabelVisible ? 64 : 0).opacity(this.searchLabelVisible ? 1 : 0)
                  .maxLines(1).clip(true).animation({ duration: 240, curve: Curve.EaseInOut })
                SymbolGlyph($r('sys.symbol.circle_viewfinder')).fontSize(24).fontColor([Color.White])
              }
            }.width(this.searchLabelVisible ? 108 : 44).height(44).padding({ left: 10, right: 10 })
              .animation({ duration: 240, curve: Curve.EaseInOut }).borderRadius(16).margin(8)
              .backgroundColor('#77303030').enabled(this.actionsReady || this.auxiliaryReady || this.deferredActions)
              .onClick(() => { if (this.onImageLayer) this.onImageLayer('search'); })
              .accessibilityText('搜索图片中的相关内容')
          }.width('100%').height(this.heroHeight()).backgroundColor($r('app.color.surface_muted')).borderRadius(18).clip(true)
          }

    }.width(this.detailPaneWidth())
  }

  @Builder
  private detailInformation() {
    Column({ space: 18 }) {
          if (this.contentError) {
            Text(this.contentError).fontSize(14).fontColor($r('app.color.secondary_text'))
            if (this.contentRetryable) Button('重试详情').onClick(() => { if (this.onContentRetry) this.onContentRetry(); })
          } else if (!this.actionsReady && !this.readsReady && !this.deferredActions) {
            Text(this.detail.kind === 'cached' ? '正在同步当前帖子状态…' : '正在确认帖子内容…')
              .fontSize(14).fontColor($r('app.color.secondary_text'))
          } else if ((this.detail.actionsRetained || this.detail.commentsRetained || this.detail.relatedRetained) &&
              (this.detail.commentLoading || this.detail.relatedLoading)) {
            Text('正在同步互动和推荐…').fontSize(14).fontColor($r('app.color.secondary_text'))
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
              Button(this.saveBusy ? '取消中' : this.action('save')!.label, { type: ButtonType.Normal })
                .height(44)
                .padding({ left: 18, right: 18 })
                .backgroundColor(this.action('save')!.selected ? $r('app.color.detail_saved_surface') : $r('app.color.detail_save_accent'))
                .fontColor(this.action('save')!.selected ? $r('app.color.primary_text') : Color.White)
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
                .accessibilityText(this.saveBusy ? '正在取消收藏' : this.action('save')!.label)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column({ space: 6 }) {
            if (this.detail.creator.length > 0) {
              Row({ space: 10 }) {
                if (this.detail.creatorAvatar.length > 0) {
                  Image(this.detail.creatorAvatar)
                    .width(32)
                    .height(32)
                    .borderRadius(16)
                    .objectFit(ImageFit.Cover)
                }
                Text(this.detail.creator)
                  .fontSize(this.creatorFontSize())
                  .layoutWeight(1)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.primary_text'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .onClick(() => {
                PinmonyRuntimeLog.info('DetailCreatorTrace: click target=' + (this.detail.creatorUrl ? 'ready' : 'missing'));
                if (this.detail.creatorUrl && this.onUser) this.onUser(this.detail.creatorUrl);
              })
            }
            if (this.detail.title.length > 0) {
              Text(this.detail.title)
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text'))
                .maxLines(this.expanded ? undefined : 2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            if (this.detail.description.length > 0) {
              Text() {
                ForEach(splitDescriptionTags(this.detail.description), (part: PinmonyDescriptionPart) => {
                  Span(part.text)
                    .fontColor(part.query ? $r('app.color.link_text') : $r('app.color.primary_text'))
                    .onClick(() => {
                      if (part.query && this.onTagSearch) this.onTagSearch(part.query, this.detail.pinUrl);
                    })
                })
              }
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
              Button(this.expanded ? '收起' : '查看更多')
                .height(32)
                .padding(0)
                .backgroundColor(Color.Transparent)
                .fontColor($r('app.color.primary_text'))
                .onClick(() => this.expanded = !this.expanded)
              }.width('100%')
            }
          if ((this.readsReady || this.actionsReady && this.detail.imageStageReady !== false ||
              this.detail.kind === 'cached' || this.detail.commentsRetained) && !this.detail.commentEmpty &&
              (this.detail.commentsAvailable || this.detail.commentPreview || this.detail.commentError)) {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 2 }) {
                if (this.detail.commentLoading && !this.detail.commentsRetained) {
                  Text('正在加载评论…').fontSize(13).fontColor($r('app.color.secondary_text'))
                } else if (this.detail.commentError) {
                  Text(this.detail.commentError).fontSize(13).fontColor($r('app.color.secondary_text'))
                }
                Text(this.detail.commentPreview || '').fontSize(13).lineHeight(18).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor($r('app.color.primary_text')).width('100%')
                Text('查看所有评论').fontSize(13).lineHeight(18).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text')).width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.width('100%').padding(0).borderRadius(0).backgroundColor(Color.Transparent)
              .enabled((this.readsReady || (this.actionsReady && this.detail.kind !== 'cached' && !this.detail.commentsRetained) || this.deferredActions))
              .onClick(() => { if (this.onComments) this.onComments(); })
            if (this.detail.commentError && !this.detail.commentLoading) {
              Button('重试评论预览')
                .height(32).padding(0).backgroundColor(Color.Transparent)
                .fontColor($r('app.color.primary_text'))
                .enabled((this.actionsReady || this.readsReady) && !this.detail.commentsRetained)
                .onClick(() => { if (this.onCommentsRetry) this.onCommentsRetry(); })
            }
          }
            if (this.detail.sourceLabel.length > 0 && this.action('source')) {
              Button('访问网站')
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
                .accessibilityText('访问网站，' + this.detail.sourceLabel)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.canUndoMore) {
            Row({ space: 12 }) {
              Text('已提交查看更多反馈').fontColor($r('app.color.primary_text')).layoutWeight(1)
              Button('撤销').enabled(!this.undoMoreBusy).onClick(() => { if (this.onUndoMore) this.onUndoMore(); })
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
  }

  @Builder
  private detailFooter() {
    Column({ space: 12 }) {
          if (this.detail.kind === 'cached' && !this.detail.relatedLoading && this.detail.relatedError) {
            Text(this.detail.relatedError)
              .fontSize(14).fontColor($r('app.color.secondary_text'))
            Button('加载推荐').enabled(this.deferredActions || this.readsReady || this.actionsReady)
              .onClick(() => { if (this.onLoadMore) this.onLoadMore(); })
          }
          if (this.detail.kind !== 'cached' && this.detail.dataSource === 'api' && (this.actionsReady || this.readsReady)) {
            if (!this.detail.relatedLoading && this.detail.relatedError) {
              Text(this.detail.relatedError).fontSize(14).fontColor($r('app.color.secondary_text'))
              Button('重试推荐').onClick(() => { if (this.onLoadMore) this.onLoadMore(); })
            } else if (this.detail.relatedEnded && this.detail.related.length === 0) {
              Text('暂无推荐内容').fontSize(14).fontColor($r('app.color.secondary_text'))
            }
          }

    }.width('100%').padding({ bottom: 42 })
  }

  @Builder
  private heroImage() {
    // Image lifecycle belongs to a component with a stable complete source key.
    Stack() {
    ForEach(this.heroImageSources(this.detail.imageUrl, this.detail.pinUrl), (source: DetailHeroSource) => {
      PinmonyDetailHero({ source: source, openId: this.traceId, heightVp: this.heroHeight(), label: this.detail.title,
        phase: this.detail.kind, blocked: !!this.contentError, renderIdentity: this.renderIdentity,
        stageReady: this.detail.imageStageReady === true, confirmedLoaded: this.detail.imageLoaded === true,
        previewAvailable: this.decodedHeroSource?.pinUrl === this.detail.pinUrl,
        onLoaded: (pin: string, image: string) => {
          if (!this.heroVisible || source.key !== this.heroRenderKey(this.detail.imageUrl, this.detail.pinUrl) ||
              pin !== this.detail.pinUrl || image !== this.detail.imageUrl) return;
          this.notifyImageLoaded(pin, image);
        },
        onFailed: (pin: string) => {
          if (!this.heroVisible || source.key !== this.heroRenderKey(this.detail.imageUrl, this.detail.pinUrl)) return;
        this.lastImageNotification = '';
          if (this.onImageError) this.onImageError(pin);
        }, onRetry: () => this.retryHeroImage(source.key),
        onTap: () => { this.zoomImageUrl = ''; if (this.onImageLayer) this.onImageLayer('zoom'); } })
    }, (source: DetailHeroSource): string => source.key)
    }.width('100%').height(this.heroHeight())
  }

  private heroImageSources(url: string, pinUrl: string): DetailHeroSource[] {
    const next: DetailHeroSource = { key: this.heroRenderKey(url, pinUrl), url: url, pinUrl: pinUrl, revision: this.heroRenderRevision };
    return this.decodedHeroSource?.pinUrl === pinUrl && this.decodedHeroSource.key !== next.key ?
      [this.decodedHeroSource, next] : [next];
  }

  private heroRenderKey(url: string, pinUrl: string): string {
    return pinUrl + ':' + url + ':' +
      this.heroRenderRevision.toString();
  }

  @Builder
  private detailContent() {
    Column() {
      Scroll(this.detailScroller) {
        Column({ space: 18 }) {
          this.detailHeader()
          if (this.detail.dataSource === 'api' && !this.isRecommendReady()) {
            Text('更多探索内容').fontSize(23).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).width('100%').margin({ top: 4 })
            this.recommendationSkeleton()
          } else if (this.detail.related.length > 0 && this.isRecommendReady()) {
            Text('更多探索内容')
              .fontSize(23)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text'))
              .width('100%')
              .margin({ top: 4 })
            Row({ space: RECOMMEND_PHONE_GAP_VP }) {
              ForEach(Array.from({ length: this.recommendColumnCount() }, (_value: number, index: number) => index), (index: number) => {
                this.relatedCards(index, this.recommendColumnCount())
              }, (index: number) => this.recommendColumnCount().toString() + ':' + index.toString())
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          this.detailFooter()
        }
        .padding({ left: 18, right: 18, top: 8, bottom: 42 })
        .width('100%')
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          const width: number = Number(newArea.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) {
            this.contentWidth = width;
            this.updateDetailLayout();
            this.auditRecommendationLayout();
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
      .edgeEffect(EdgeEffect.Spring)
      .onAppear(() => this.restoreScrollPosition())
      .onDidScroll(() => this.reportScrollPosition())
      .onScrollStop(() => this.reportScrollPosition(true))
      .onReachEnd(() => {
        if (!this.readsReady && (this.detail.kind === 'cached' || this.detail.relatedRetained)) {
          PinmonyRuntimeLog.info('RecommendAudit: pagination.blocked reason=cached-presentation');
          return;
        }
        if (!this.isRecommendReady()) {
          PinmonyRuntimeLog.info('RecommendAudit: pagination.blocked reason=recommend-not-ready');
          return;
        }
        if (!this.readsReady && !this.detail.interactionsSettled) {
          PinmonyRuntimeLog.info('RecommendAudit: pagination.blocked reason=interactions-pending');
          return;
        }
        if ((this.actionsReady || this.readsReady) && !this.detail.relatedError && this.onLoadMore) this.onLoadMore();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private videoRetryNotice() {
    if (!this.imageLayer && this.detail.isVideo && this.detail.video &&
        !this.mediaReadBusy && !this.detail.mediaLoading && (this.detail.videoError || this.videoFailure)) {
      Row({ space: 8 }) {
        Text(this.detail.videoError || this.videoFailure).fontSize(13)
          .fontColor($r('app.color.secondary_text')).maxLines(3).layoutWeight(1)
        Button('重试').fontSize(13).height(44).enabled(this.videoActive && (this.actionsReady || !!this.detail.videoError))
          .onClick(() => {
            if (this.detail.videoError) { if (this.onVideoRetry) this.onVideoRetry(); }
            else {
              this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0 });
              this.videoRetryRevision = (this.videoRetryRevision + 1) % 1000000;
            }
          })
        Button('重读地址').fontSize(13).height(44).enabled(this.videoActive && !!this.onVideoRetry)
          .accessibilityText('重新读取视频地址')
          .onClick(() => {
            PinmonyRuntimeLog.info('VideoTrace: openId=' + this.traceId.toString() + ' event=refresh-requested');
            if (this.onVideoRetry) this.onVideoRetry();
          })
      }.width('100%').padding(10)
        .backgroundColor($r('app.color.input_surface')).borderRadius(12)
    }
  }

  @Builder
  private detailDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack() {
        Column() { this.detailContent() }.width('100%').height('100%')
          .visibility(this.imageLayer === 'search' ? Visibility.Hidden : Visibility.Visible)
      if (this.imageLayer === 'search') {
        PinmonyVisualSearchView({ pin: this.detail.pinUrl, imageUrl: this.detail.originalImageUrl || this.detail.imageUrl,
          imageWidth: this.detail.imageWidth, imageHeight: this.detail.imageHeight, result: this.visualResult,
          onSearch: this.onVisualSearch,
          onClose: () => { if (this.onImageLayer) this.onImageLayer(''); },
          onRelated: (id: string) => {
            if (this.onImageLayer) this.onImageLayer('');
            if (this.onRelated) this.onRelated(id);
          } })
      }
      }.width('100%').height('100%')
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .hideTitleBar(false)
    .onBackPressed(() => {
      PinmonyRuntimeLog.info('PinmonyReturn: detail destination back');
      if (this.imageLayer && this.onImageLayer) this.onImageLayer('');
      else if (this.onBack) this.onBack();
      return true;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Stack() {
      HdsNavigation(this.detailPathStack) {
        Column().width('100%').height('100%')
      }
      .width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.detailDestination).backgroundColor($r('app.color.page_background'))
      .hitTestBehavior(this.imageLayer === 'zoom' ? HitTestMode.None : HitTestMode.Default)
      if (this.imageLayer === 'zoom') {
        PinmonyImageViewer({ detail: this.detail, imageUrl: this.zoomImageUrl || this.detail.originalImageUrl || this.detail.imageUrl,
          previewUrl: this.zoomImageUrl || this.detail.imageUrl,
          active: this.videoActive,
          actionsReady: this.actionsReady,
          onClose: () => { if (this.onImageLayer) this.onImageLayer(''); }, onAction: this.onAction,
          onDownload: this.onDownload, onSave: this.onViewerSave,
          onControlsChange: (visible: boolean) => { this.viewerControls = visible; } })
      }
    }.width('100%').height('100%')
      .onAreaChange((_old: Area, area: Area) => {
        const width: number = Number(area.width);
        const height: number = Number(area.height);
        if (width > 0 && height > 0) {
          this.viewportWidth = width;
          this.viewportHeight = height;
          this.updateDetailLayout();
        }
      }).backgroundColor($r('app.color.page_background'))
  }
}
