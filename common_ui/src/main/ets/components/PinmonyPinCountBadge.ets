import { PinmonyCardMediaBadge } from './PinmonyCardMediaBadge';

export interface PinmonyCardCarouselData {
  carousel_slots?: Object[];
}

@Component
export struct PinmonyPinCountBadge {
  @Prop mediaCount: number = 0;

  build() {
    if (Number.isInteger(this.mediaCount) && this.mediaCount > 1) {
      PinmonyCardMediaBadge({ caption: this.mediaCount.toString() }).align(Alignment.TopStart).hitTestBehavior(HitTestMode.None)
    }
  }
}
