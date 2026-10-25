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
  @Prop sourceId: string = '';
  @Prop imageHidden: boolean = false;
  @Prop hiddenImageUrl: string = '';
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
  onImageTap?: (imageUrl: string) => void;
  onFirstImageSettled?: (failed: boolean) => void;
  private identity: string = '';
  private controller: SwiperController = new SwiperController();
  private indicatorController: IndicatorComponentController = new IndicatorComponentController();

  aboutToAppear(): void { this.identity = this.carousel.pinId; }

  private onCarouselChanged(): void {
    if (this.identity === this.carousel.pinId) return;
    this.identity = this.carousel.pinId;
    this.page = 0;
    this.failed = [];
    this.controller.changeIndex(0, false);
  }

  private mediaHeight(): number {
    if (this.carousel.freeScroll) {
      const first: PinmonyCarouselItem = this.carousel.items[0];
      return Math.max(220, Math.min(620, this.contentWidth * 0.82 * first.imageHeight / Math.max(1, first.imageWidth)));
    }
    if (this.mediaHeightVp > 0) return this.mediaHeightVp;
    const item: PinmonyCarouselItem = this.carousel.items[0];
    return Math.max(220, Math.min(620, this.contentWidth * item.imageHeight / item.imageWidth));
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
                    Text(this.uiText("pm_image_failed_to_load_572993f5")).fontColor($r('app.color.primary_text'))
                    Button(this.uiText("pm_retry_b8784c8d")).onClick(() => {
                      this.failed = this.failed.filter((id: string): boolean => id !== item.id);
                      this.revision++;
                    })
                  }
                } else {
                  Image(item.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain).syncLoad(true)
                    .onComplete(() => { if (index === 0) this.onFirstImageSettled?.(false); })
                    .onError(() => {
                      if (index === 0) this.onFirstImageSettled?.(true);
                      if (!this.failed.includes(item.id)) this.failed = this.failed.concat(item.id);
                    })
                    .onClick(() => this.onImageTap?.(item.imageUrl))
                    .accessibilityText(this.uiFormat("pm_image_value_of_value_value_66dd48e8", [index + 1, this.carousel.items.length, item.title]))
                }
              }.width(this.contentWidth * 0.82).height(this.mediaHeight()).borderRadius(18).clip(true)
                .id(this.sourceId + '-' + index.toString())
                .opacity(this.imageHidden && item.imageUrl === this.hiddenImageUrl ? 0 : 1)
            }, (item: PinmonyCarouselItem): string => this.carousel.pinId + ':' + item.id + ':' + this.uiLanguage)
          }.height(this.mediaHeight())
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width('100%').height(this.mediaHeight())
          .onAreaChange(() => {
            if (!this.productPositionRestored) {
              this.productPositionRestored = true;
              this.productScroller.scrollTo({ xOffset: this.productOffset, yOffset: 0 });
            }
          })
          .onScroll(() => {
            if (this.productPositionRestored) this.onProductOffset?.(this.productScroller.currentOffset().xOffset);
          })
      } else {
      Swiper(this.controller) {
        ForEach(this.carousel.items, (item: PinmonyCarouselItem, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            if (item.video && index === this.page) {
              PinmonyVideoPlayer({ video: item.video, poster: item.imageUrl,
                active: this.active && index === this.page, sessionReady: this.sessionReady,
                mediaOwner: this.mediaOwner + ':' + item.id, openId: this.openId,
                autoplayWifi: this.autoplayWifi, autoplayCellular: this.autoplayCellular,
                onPosterSettled: (failed: boolean) => {
                  if (index === 0 && this.carousel.items[0]?.id === item.id) this.onFirstImageSettled?.(failed);
                } }).width('100%').height('100%')
            } else if (this.failed.includes(item.id)) {
              Column({ space: 12 }) {
                Text(this.uiText("pm_image_failed_to_load_572993f5")).fontColor($r('app.color.primary_text'))
                Button(this.uiText("pm_retry_b8784c8d")).onClick(() => {
                  this.failed = this.failed.filter((id: string): boolean => id !== item.id);
                  this.revision++;
                })
              }
            } else {
              Image(item.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain).borderRadius(18).clip(true)
                .onComplete(() => {
                  if (index === 0 && this.carousel.items[0]?.id === item.id &&
                      this.carousel.items[0]?.imageUrl === item.imageUrl && this.onFirstImageSettled) this.onFirstImageSettled(false);
                })
                .onError(() => {
                  if (index === 0 && this.carousel.items[0]?.id === item.id &&
                      this.carousel.items[0]?.imageUrl === item.imageUrl && this.onFirstImageSettled) this.onFirstImageSettled(true);
                  if (!this.failed.includes(item.id)) this.failed = this.failed.concat(item.id);
                })
                .onClick(() => { if (!item.video && this.onImageTap) this.onImageTap(item.imageUrl); })
                .accessibilityText(this.uiFormat("pm_image_value_of_value_value_66dd48e8", [index + 1, this.carousel.items.length, item.title]))
            }
          }.width('100%').height('100%')
        }, (item: PinmonyCarouselItem): string => (`${this.carousel.pinId}:${item.id}:${this.revision}`) + ':' + this.uiLanguage)
      }
      .width('100%').height(this.mediaHeight()).loop(false).autoPlay(false)
      .indicator(this.indicatorController)
      .borderRadius(18).clip(true)
      .id(this.sourceId).opacity(this.imageHidden ? 0 : 1)
      .onChange((index: number) => { this.page = index; })
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
