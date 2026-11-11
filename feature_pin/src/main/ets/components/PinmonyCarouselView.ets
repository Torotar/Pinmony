import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyCarousel, PinmonyCarouselItem } from '../models/PinmonyDetail';
import { PinmonyVideoPlayer } from './PinmonyVideoPlayer';

@Component
export struct PinmonyCarouselView {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  private uiFormat(source: string, values: (string | number)[]): string { return PinmonyI18n.format(source, values, this.uiLanguage); }
  @Prop @Watch('onCarouselChanged') carousel: PinmonyCarousel;
  @Prop contentWidth: number = 324;
  @Prop mediaHeightVp: number = 0;
  @Prop maxMediaHeightVp: number = 0;
  @Prop sourceId: string = '';
  @Prop previewUrl: string = '';
  @Prop imageHidden: boolean = false;
  @Prop hiddenImageUrl: string = '';
  @Prop @Watch('viewerPhotoChanged') viewerImageUrl: string = '';
  @Prop productOffset: number = 0;
  onProductOffset?: (offset: number) => void;
  private productScroller: Scroller = new Scroller();
  private productPositionRestored: boolean = false;
  @Prop active: boolean = true;
  @Prop sessionReady: boolean = false;
  @Prop mediaOwner: string = '';
  @Prop openId: number = 0;
  @Prop autoplayWifi: boolean = false;
  @Prop autoplayCellular: boolean = false;
  @State private page: number = 0;
  @State private failed: string[] = [];
  @State private revision: number = 0;
  @State private firstRenderedKey: string = '';
  onImageTap?: (imageUrl: string) => void;
  onPageChanged?: (index: number) => void;
  onFirstImageSettled?: (failed: boolean) => void;
  private identity: string = '';
  private alive: boolean = false;
  private controller: SwiperController = new SwiperController();
  private indicatorController: IndicatorComponentController = new IndicatorComponentController();

  aboutToAppear(): void { this.alive = true; this.identity = this.carousel.pinId; }
  aboutToDisappear(): void { this.alive = false; }

  private firstImageKey(item: PinmonyCarouselItem): string {
    return this.carousel.pinId + ':' + item.id + ':' + item.imageUrl + ':' + this.revision.toString();
  }

  private settleFirstImage(item: PinmonyCarouselItem, index: number, status: number, failed: boolean = false): void {
    if (!this.alive || index !== 0 || this.identity !== this.carousel.pinId ||
        this.carousel.items[0]?.id !== item.id || this.carousel.items[0]?.imageUrl !== item.imageUrl ||
        !failed && status !== 1) return;
    if (!failed) this.firstRenderedKey = this.firstImageKey(item);
    this.onFirstImageSettled?.(failed);
  }

  private onCarouselChanged(): void {
    if (this.identity === this.carousel.pinId) return;
    this.identity = this.carousel.pinId;
    this.page = 0;
    this.failed = [];
    this.firstRenderedKey = '';
    this.controller.changeIndex(0, false);
  }

  private viewerPhotoChanged(): void {
    if (!this.alive || !this.viewerImageUrl) return;
    const index: number = this.carousel.items.findIndex((item: PinmonyCarouselItem): boolean => item.imageUrl === this.viewerImageUrl);
    if (index < 0) return;
    if (this.carousel.freeScroll) {
      const stride: number = this.contentWidth * 0.82 + 6;
      const maximum: number = Math.max(0, this.carousel.items.length * stride - 6 - this.contentWidth);
      const target: number = Math.min(maximum, index * stride);
      this.productScroller.scrollTo({ xOffset: target, yOffset: 0, animation: false });
      this.onProductOffset?.(target);
    } else {
      this.page = index;
      this.onPageChanged?.(index);
      this.controller.changeIndex(index, false);
    }
  }

  private mediaHeight(): number {
    if (this.carousel.freeScroll) {
      const first: PinmonyCarouselItem = this.carousel.items[0];
      const height: number = Math.max(220, Math.min(620, this.contentWidth * 0.82 * first.imageHeight / Math.max(1, first.imageWidth)));
      return this.maxMediaHeightVp > 0 ? Math.min(height, this.maxMediaHeightVp) : height;
    }
    if (this.mediaHeightVp > 0) return this.mediaHeightVp;
    const item: PinmonyCarouselItem = this.carousel.items[0];
    return Math.max(220, Math.min(620, this.contentWidth * item.imageHeight / item.imageWidth));
  }

  private photoRadius(item: PinmonyCarouselItem): number {
    if (item.video || this.carousel.freeScroll || item.imageWidth <= 0 || item.imageHeight <= 0) return 18;
    const sideInset: number = (this.contentWidth - this.mediaHeight() * item.imageWidth / item.imageHeight) / 2;
    return sideInset < 18 ? 18 : 0;
  }

  private videoSlotMounted(index: number): boolean {
    // Keep both sides of an ordinary swipe mounted before they become visible.
    // Only the selected slot is active; bound retained surfaces to three slots.
    return index >= 0 && index < this.carousel.items.length && Math.abs(index - this.page) <= 1;
  }

  build() {
    Column() {
      if (this.carousel.freeScroll) {
        Scroll(this.productScroller) {
          Row({ space: 6 }) {
            ForEach(this.carousel.items, (item: PinmonyCarouselItem, index: number) => {
              Stack() {
                if (this.failed.includes(item.id)) {
                  Column({ space: 12 }) {
                    PinmonyActionNotice({ active: this.active, message: this.uiText("pm_image_failed_to_load_572993f5"), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => {
                      this.failed = this.failed.filter((id: string): boolean => id !== item.id);
                      this.revision++;
                    } })
                  }
                } else {
                  Image(item.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain).syncLoad(true)
                    .onComplete((event) => this.settleFirstImage(item, index, event?.loadingStatus ?? -1))
                    .onError(() => {
                      if (!this.alive || this.carousel.items[index]?.id !== item.id ||
                          this.carousel.items[index]?.imageUrl !== item.imageUrl) return;
                      this.settleFirstImage(item, index, -1, true);
                      if (!this.failed.includes(item.id)) this.failed = this.failed.concat(item.id);
                    })
                    .onClick(() => this.onImageTap?.(item.imageUrl))
                    .accessibilityText(this.uiFormat("pm_image_value_of_value_value_66dd48e8", [index + 1, this.carousel.items.length, item.title]))
                }
              }.width(this.contentWidth * 0.82).height(this.mediaHeight()).borderRadius(18).clip(true)
                .id(this.sourceId + '-' + index.toString())
                .opacity(this.imageHidden && item.imageUrl === this.hiddenImageUrl ? 0 : 1)
            }, (item: PinmonyCarouselItem): string => this.carousel.pinId + ':' + item.id + ':' + item.imageUrl + ':' + this.revision.toString() + ':' + this.uiLanguage)
          }.height(this.mediaHeight())
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width('100%').height(this.mediaHeight())
          .onAreaChange(() => {
            if (!this.productPositionRestored) {
              this.productPositionRestored = true;
              this.productScroller.scrollTo({ xOffset: this.productOffset, yOffset: 0 });
            }
          })
          .onDidScroll((_xOffset: number, _yOffset: number, _state: ScrollState) => {
            if (this.productPositionRestored) this.onProductOffset?.(this.productScroller.currentOffset().xOffset);
          })
      } else {
      Swiper(this.controller) {
        ForEach(this.carousel.items, (item: PinmonyCarouselItem, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            // Keep the already decoded entry cover under the first slot until
            // the actual carousel image has produced a drawable frame.
            if (index === 0 && !item.video && !this.failed.includes(item.id) && this.previewUrl &&
                this.firstRenderedKey !== this.firstImageKey(item)) {
              Image(this.previewUrl).width('100%').height('100%').objectFit(ImageFit.Contain).syncLoad(true)
                .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
            }
            if (item.video && this.videoSlotMounted(index)) {
              PinmonyVideoPlayer({ video: item.video, poster: item.imageUrl,
                entryPreview: index === 0 ? this.previewUrl : '',
                active: this.active && index === this.page, sessionReady: this.sessionReady,
                mediaOwner: this.mediaOwner + ':' + item.id, openId: this.openId,
                autoplayWifi: this.autoplayWifi, autoplayCellular: this.autoplayCellular,
                onPosterSettled: (failed: boolean) => {
                  this.settleFirstImage(item, index, 1, failed);
                } }).width('100%').height('100%')
            } else if (this.failed.includes(item.id)) {
              Column({ space: 12 }) {
                PinmonyActionNotice({ active: this.active, message: this.uiText("pm_image_failed_to_load_572993f5"), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => {
                  this.failed = this.failed.filter((id: string): boolean => id !== item.id);
                  this.revision++;
                } })
              }
            } else {
              Image(item.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain).syncLoad(index === 0).borderRadius(this.photoRadius(item)).clip(true)
                .onComplete((event) => this.settleFirstImage(item, index, event?.loadingStatus ?? -1))
                .onError(() => {
                  if (!this.alive || this.carousel.items[index]?.id !== item.id ||
                      this.carousel.items[index]?.imageUrl !== item.imageUrl) return;
                  this.settleFirstImage(item, index, -1, true);
                  if (!this.failed.includes(item.id)) this.failed = this.failed.concat(item.id);
                })
                .onClick(() => { if (!item.video && this.onImageTap) this.onImageTap(item.imageUrl); })
                .accessibilityText(this.uiFormat("pm_image_value_of_value_value_66dd48e8", [index + 1, this.carousel.items.length, item.title]))
            }
          }.width('100%').height('100%')
        }, (item: PinmonyCarouselItem): string => (`${this.carousel.pinId}:${item.id}:${item.imageUrl}:${this.revision}`) + ':' + this.uiLanguage)
      }
      .width('100%').height(this.mediaHeight()).loop(false).autoPlay(false)
      .indicator(this.indicatorController)
      .borderRadius(this.carousel.items[this.page] ? this.photoRadius(this.carousel.items[this.page]) : 18).clip(true)
      .id(this.sourceId).opacity(this.imageHidden ? 0 : 1)
      .onChange((index: number) => { this.page = index; this.onPageChanged?.(index); })
      .accessibilityText(this.uiFormat("pm_image_value_of_value_2349ba46", [this.page + 1, this.carousel.items.length]))
      IndicatorComponent(this.indicatorController)
        .count(this.carousel.items.length)
        .style(Indicator.dot().itemWidth(7).itemHeight(7).selectedItemWidth(7).selectedItemHeight(7)
          .color($r('app.color.secondary_text')).selectedColor($r('app.color.primary_text')))
        .width('100%').height(28)
      }
    }.width('100%').height(this.mediaHeight() + (this.carousel.freeScroll ? 0 : 28)).justifyContent(FlexAlign.Start)
  }
}
