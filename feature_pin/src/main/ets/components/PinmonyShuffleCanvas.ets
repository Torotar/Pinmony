import { PinmonyShuffleSnapshot, PinmonyShuffleItem } from '../models/PinmonyShuffle';

// The composite remains the visual source; static item geometry supplies hit regions.
@Component
export struct PinmonyShuffleCanvas {
  @Prop shuffle: PinmonyShuffleSnapshot;
  @Prop coverUrl: string = '';
  @Prop canvasWidthVp: number = 1;
  @Prop canvasHeightVp: number = 1;
  @Prop interactionReady: boolean = false;
  @Prop pinLabel: string = '';
  onPin?: (id: string) => void;

  private ratio(): number {
    return Math.min(this.canvasWidthVp / Math.max(1,this.shuffle.canvasWidth),this.canvasHeightVp / Math.max(1,this.shuffle.canvasHeight));
  }
  private measurable(item: PinmonyShuffleItem): boolean {
    return !item.hidden && item.alpha > 0 && item.imageWidth > 0 && item.imageHeight > 0 &&
      this.shuffle.canvasWidth > 0 && this.shuffle.canvasHeight > 0;
  }
  build() {
    Stack({alignContent:Alignment.TopStart}) {
      Image(this.coverUrl).width('100%').height('100%').objectFit(ImageFit.Contain).hitTestBehavior(HitTestMode.None)
      ForEach(this.shuffle.items, (item: PinmonyShuffleItem) => {
        if (this.measurable(item)) {
          Row().width(item.imageWidth * item.scale * this.ratio()).height(item.imageHeight * item.scale * this.ratio())
            .position({x:this.canvasWidthVp / 2 + item.offsetX * this.ratio() - item.imageWidth * item.scale * this.ratio() / 2,
              y:this.canvasHeightVp / 2 + item.offsetY * this.ratio() - item.imageHeight * item.scale * this.ratio() / 2})
            .rotate({angle:item.rotation})
            .hitTestBehavior(HitTestMode.Default)
            .accessibilityLevel(item.tappable ? 'yes' : 'no')
            .accessibilityText(this.pinLabel)
            .onClick(() => {
              if (this.interactionReady && item.tappable && item.pinId) this.onPin?.(item.id);
            }, 8)
        }
      }, (item: PinmonyShuffleItem): string => item.id)
    }.width(this.canvasWidthVp).height(this.canvasHeightVp).clip(true)
  }
}
