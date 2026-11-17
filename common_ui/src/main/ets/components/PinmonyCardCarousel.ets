import { PinmonyCardImage } from '../models/PinmonyCardCarousel';
import { PinmonyCdnImage } from './PinmonyCdnImage';

@Component
export struct PinmonyCardCarousel {
  @Prop images: PinmonyCardImage[] = [];
  @Prop photoHeight: number = 200;
  @Prop photoId: string = '';
  @Prop loadingActive: boolean = true;
  @Prop interactionActive: boolean = true;
  @Prop savedCaption: string = '';
  @Prop initialIndex: number = 0;
  @Prop errorText: string = '';
  @Prop retryText: string = '';
  @Prop retryAllowed: boolean = true;
  @State private selectedIndex: number = 0;
  @State private failedUrls: string[] = [];
  @State private decodedUrls: string[] = [];
  @State private cardInViewport: boolean = false;
  private readonly indicatorController: IndicatorComponentController = new IndicatorComponentController();
  onOpen?: (url: string) => void;
  onDecoded?: () => void;
  onFailure?: (code: number) => void;
  onSelect?: (url: string) => void;

  aboutToAppear(): void {
    this.selectedIndex = Math.max(0, Math.min(this.images.length - 1, this.initialIndex));
  }

  private canLoadPhoto(index: number): boolean {
    if (!this.loadingActive || !this.cardInViewport || Math.abs(index - this.selectedIndex) > 1) return false;
    const current: PinmonyCardImage | undefined = this.images[this.selectedIndex];
    return index === this.selectedIndex || !!current && this.decodedUrls.indexOf(current.url) >= 0;
  }

  @Builder
  private savedMask() {
    if (this.savedCaption) {
      Column() {
        Text(this.savedCaption).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 16 })
        Blank()
      }.width('100%').height(this.photoHeight).backgroundColor('#55000000')
        .borderRadius(18).clip(true).hitTestBehavior(HitTestMode.None)
    }
  }

  build() {
    Column() {
      // The viewport, rather than each moving slide, owns the visible corners.
      Stack() {
      Swiper() {
        ForEach(this.images, (photo: PinmonyCardImage, index: number) => {
          Column() {
          Stack() {
            if (this.failedUrls.indexOf(photo.url) >= 0) {
              Column({ space: 8 }) {
                Text(this.errorText).fontSize(14).fontColor($r('app.color.secondary_text')).textAlign(TextAlign.Center)
                if (this.retryAllowed) {
                  Button(this.retryText).fontSize(14).fontColor($r('app.color.primary_text')).backgroundColor(Color.Transparent)
                    .enabled(this.interactionActive)
                    .onClick(() => {
                      this.failedUrls = this.failedUrls.filter((url: string): boolean => url !== photo.url);
                    })
                }
              }.padding(12)
            } else {
              PinmonyCdnImage({ url: photo.url, fit: ImageFit.Cover,
                allowImageDrag: false,
                loadingActive: this.canLoadPhoto(index), viewportOnly: false,
                loadPriority: index === this.selectedIndex ? 1 : 0,
                onDecoded: () => {
                  if (this.decodedUrls.indexOf(photo.url) < 0) this.decodedUrls = [...this.decodedUrls, photo.url];
                  this.onDecoded?.();
                }, onFailure: (code: number) => {
                  if (this.failedUrls.indexOf(photo.url) < 0) this.failedUrls = [...this.failedUrls, photo.url];
                  this.onFailure?.(code);
                } })
                .width('100%').height(this.photoHeight)
            }
            this.savedMask()
          }.width('100%').height(this.photoHeight).backgroundColor($r('app.color.surface_muted'))
            .borderRadius(18).clip(true)
            .id(index === this.selectedIndex ? this.photoId : this.photoId + '-slide-' + index)
            .parallelGesture(TapGesture({ count: 1, distanceThreshold: 8 }).onAction(() => {
              if (this.interactionActive && index === this.selectedIndex && this.failedUrls.indexOf(photo.url) < 0) {
                this.onOpen?.(photo.url);
              }
            }))
          }.width('100%').height('100%')
        }, (photo: PinmonyCardImage, index: number): string => index + ':' + photo.id + ':' + photo.url)
      }
      .width('100%').height(this.photoHeight)
      .index(this.selectedIndex).loop(false).autoPlay(false)
      .cachedCount(1)
      .indicator(this.indicatorController)
      .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
      .disableSwipe(!this.interactionActive)
      .onChange((index: number) => {
        const photo: PinmonyCardImage | undefined = this.images[index];
        if (!photo) return;
        this.selectedIndex = index;
        this.onSelect?.(photo.url);
      })
      }.width('100%').height(this.photoHeight).borderRadius(18).clip(true)
      // Keep the native stretching dots outside the fixed photo clipping area.
      IndicatorComponent(this.indicatorController)
        .style(Indicator.dot().bottom(4)
          .itemWidth(7).itemHeight(7).selectedItemWidth(9).selectedItemHeight(9)
          .color($r('app.color.secondary_text')).selectedColor($r('app.color.primary_text')).maxDisplayCount(7))
        .width('100%').height(38)
        .hitTestBehavior(this.interactionActive ? HitTestMode.Default : HitTestMode.None)
    }.width('100%')
      .onVisibleAreaChange([0, 0.01], (visible: boolean, ratio: number) => {
        this.cardInViewport = visible && ratio > 0;
      })
  }
}
