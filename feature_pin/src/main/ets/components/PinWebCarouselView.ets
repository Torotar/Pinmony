import { PinWebCarousel, PinWebCarouselItem } from '../models/PinWebDetail';

@Component
export struct PinWebCarouselView {
  @Prop @Watch('onCarouselChanged') carousel: PinWebCarousel;
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
    const item: PinWebCarouselItem = this.carousel.items[0];
    return Math.max(220, Math.min(620, this.contentWidth * item.imageHeight / item.imageWidth));
  }

  build() {
    Column() {
      Swiper(this.controller) {
        ForEach(this.carousel.items, (item: PinWebCarouselItem, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            if (this.failed.includes(item.id)) {
              Column({ space: 12 }) {
                Text('图片加载失败').fontColor($r('app.color.primary_text'))
                Button('重试').onClick(() => {
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
                .accessibilityText(`第 ${index + 1} 张，共 ${this.carousel.items.length} 张。${item.title}`)
            }
          }.width('100%').height('100%')
        }, (item: PinWebCarouselItem): string => `${this.carousel.pinId}:${item.id}:${this.revision}`)
      }
      .width('100%').height(this.mediaHeight()).loop(false).autoPlay(false)
      .indicator(Indicator.dot().bottom(14)
        .itemWidth(7).itemHeight(7).selectedItemWidth(7).selectedItemHeight(7)
        .color('#66000000').selectedColor('#EEFFFFFF'))
      .borderRadius(18).clip(true)
      .onChange((index: number) => { this.page = index; })
      .accessibilityText(`当前第 ${this.page + 1} 张，共 ${this.carousel.items.length} 张`)
    }.width('100%')
  }
}
