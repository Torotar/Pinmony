import { PinmonyI18n } from 'common_foundation';
import { PinmonyCarousel, PinmonyCarouselItem } from '../models/PinmonyDetail';

@Component
export struct PinmonyCarouselView {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  private uiFormat(source: string, values: (string | number)[]): string { return PinmonyI18n.format(source, values, this.uiLanguage); }
  @Prop @Watch('onCarouselChanged') carousel: PinmonyCarousel;
  @Prop contentWidth: number = 324;
  @State private page: number = 0;
  @State private failed: string[] = [];
  @State private revision: number = 0;
  onImageTap?: (imageUrl: string) => void;
  onFirstImageSettled?: (failed: boolean) => void;
  private identity: string = '';
  private controller: SwiperController = new SwiperController();

  aboutToAppear(): void { this.identity = this.carousel.pinId; }

  private onCarouselChanged(): void {
    if (this.identity === this.carousel.pinId) return;
    this.identity = this.carousel.pinId;
    this.page = 0;
    this.failed = [];
    this.controller.changeIndex(0, false);
  }

  private mediaHeight(): number {
    const item: PinmonyCarouselItem = this.carousel.items[0];
    return Math.max(220, Math.min(620, this.contentWidth * item.imageHeight / item.imageWidth));
  }

  build() {
    Column() {
      Swiper(this.controller) {
        ForEach(this.carousel.items, (item: PinmonyCarouselItem, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            if (this.failed.includes(item.id)) {
              Column({ space: 12 }) {
                Text(this.uiText("pm_image_failed_to_load_572993f5")).fontColor($r('app.color.primary_text'))
                Button(this.uiText("pm_retry_b8784c8d")).onClick(() => {
                  this.failed = this.failed.filter((id: string): boolean => id !== item.id);
                  this.revision++;
                })
              }
            } else {
              Image(item.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain)
                .onComplete(() => {
                  if (index === 0 && this.carousel.items[0]?.id === item.id &&
                      this.carousel.items[0]?.imageUrl === item.imageUrl && this.onFirstImageSettled) this.onFirstImageSettled(false);
                })
                .onError(() => {
                  if (index === 0 && this.carousel.items[0]?.id === item.id &&
                      this.carousel.items[0]?.imageUrl === item.imageUrl && this.onFirstImageSettled) this.onFirstImageSettled(true);
                  if (!this.failed.includes(item.id)) this.failed = this.failed.concat(item.id);
                })
                .onClick(() => { if (this.onImageTap) this.onImageTap(item.imageUrl); })
                .accessibilityText(this.uiFormat("pm_image_value_of_value_value_66dd48e8", [index + 1, this.carousel.items.length, item.title]))
            }
          }.width('100%').height('100%')
        }, (item: PinmonyCarouselItem): string => `${this.carousel.pinId}:${item.id}:${this.revision}`)
      }
      .width('100%').height(this.mediaHeight()).loop(false).autoPlay(false)
      .indicator(Indicator.dot().bottom(14)
        .itemWidth(7).itemHeight(7).selectedItemWidth(7).selectedItemHeight(7)
        .color('#66000000').selectedColor('#EEFFFFFF'))
      .borderRadius(18).clip(true)
      .onChange((index: number) => { this.page = index; })
      .accessibilityText(this.uiFormat("pm_image_value_of_value_2349ba46", [this.page + 1, this.carousel.items.length]))
    }.width('100%')
  }
}
