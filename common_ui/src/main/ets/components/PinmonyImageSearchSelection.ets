import { PinmonyImageCrop } from '../models/PinmonyImageSearch';

// Passive selection artwork shared by the interactive search and its flight plane.
@Component
export struct PinmonyImageSearchSelection {
  @Prop photoWidth: number = 1;
  @Prop photoHeight: number = 1;
  @Prop crop: PinmonyImageCrop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };

  private selectionRadius(): number {
    return Math.min(12, this.crop.w * this.photoWidth / 2, this.crop.h * this.photoHeight / 2);
  }

  private maskCommands(): string {
    // Path commands use physical pixels; layout and the selection border use vp.
    const widthPx: number = this.getUIContext().vp2px(this.photoWidth);
    const heightPx: number = this.getUIContext().vp2px(this.photoHeight);
    const left: number = this.crop.x * widthPx;
    const top: number = this.crop.y * heightPx;
    const right: number = (this.crop.x + this.crop.w) * widthPx;
    const bottom: number = (this.crop.y + this.crop.h) * heightPx;
    const radius: number = this.getUIContext().vp2px(this.selectionRadius());
    const arc: string = ' A ' + radius + ' ' + radius + ' 0 0 0 ';
    // Opposite winding cuts a rounded transparent aperture out of the mask.
    return 'M 0 0 H ' + widthPx + ' V ' + heightPx + ' H 0 Z ' +
      'M ' + (left + radius) + ' ' + top + arc + left + ' ' + (top + radius) +
      ' V ' + (bottom - radius) + arc + (left + radius) + ' ' + bottom +
      ' H ' + (right - radius) + arc + right + ' ' + (bottom - radius) +
      ' V ' + (top + radius) + arc + (right - radius) + ' ' + top + ' Z';
  }

  @Builder
  private corner(index: number) {
    Image($r('app.media.image_crop_corner')).width(28).height(28)
      .rotate({ angle: index === 0 ? 0 : index === 1 ? 90 : index === 2 ? 270 : 180 })
      .position({ x: (this.crop.x + (index === 1 || index === 3 ? this.crop.w : 0)) * this.photoWidth - 14,
        y: (this.crop.y + (index > 1 ? this.crop.h : 0)) * this.photoHeight - 14 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Path().commands(this.maskCommands()).fill('#77000000').stroke(Color.Transparent)
        .width(this.photoWidth).height(this.photoHeight)
      Row().width(this.crop.w * this.photoWidth).height(this.crop.h * this.photoHeight)
        .border({ width: 1, color: Color.White }).borderRadius(this.selectionRadius()).backgroundColor(Color.Transparent)
        .position({ x: this.crop.x * this.photoWidth, y: this.crop.y * this.photoHeight })
      this.corner(0)
      this.corner(1)
      this.corner(2)
      this.corner(3)
    }.width(this.photoWidth).height(this.photoHeight).hitTestBehavior(HitTestMode.None)
  }
}
