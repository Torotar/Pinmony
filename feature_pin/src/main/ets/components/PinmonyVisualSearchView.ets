import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyImageCrop, PinmonyVisualResult } from '../models/PinmonyVisualSearch';
import { PinmonyRelatedPin } from '../models/PinmonyDetail';

@Component
export struct PinmonyVisualSearchView {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop pin: string = '';
  @Prop imageUrl: string = '';
  @Prop imageWidth: number = 1;
  @Prop imageHeight: number = 1;
  @Prop result: PinmonyVisualResult;
  @State private crop: PinmonyImageCrop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
  @State private widthValue: number = 360;
  @State private heightValue: number = 720;
  @State private sheetVisible: boolean = false;
  @State private sheetHeight: string | SheetSize = '40%';
  @State private expanded: boolean = false;
  private dragCorner: number = -2;
  private base: PinmonyImageCrop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
  private debounce: number = -1;
  private initial: number = -1;
  private alive: boolean = false;
  private readonly resultScroller: Scroller = new Scroller();
  onSearch?: (crop: PinmonyImageCrop, append: boolean, first: boolean) => void;
  onClose?: () => void;
  onRelated?: (id: string) => void;

  aboutToAppear(): void {
    this.alive = true;
    this.initial = setTimeout(() => {
      if (!this.alive) return;
      this.sheetVisible = true;
      if (this.onSearch) this.onSearch(this.crop, false, true);
    }, 100);
  }
  aboutToDisappear(): void { this.alive = false; clearTimeout(this.debounce); clearTimeout(this.initial); }
  private photoWidth(): number { return Math.min(this.widthValue, this.heightValue * 0.6 * this.imageWidth / this.imageHeight); }
  private photoHeight(): number { return this.photoWidth() * this.imageHeight / this.imageWidth; }
  private photoX(): number { return (this.widthValue - this.photoWidth()) / 2; }
  private photoY(): number { return (this.heightValue * 0.6 - this.photoHeight()) / 2; }
  private queueSearch(): void {
    clearTimeout(this.debounce);
    this.debounce = setTimeout(() => {
      if (this.alive && this.onSearch) this.onSearch(this.crop, false, false);
    }, 280);
  }
  private startDrag(): void { this.base = { x: this.crop.x, y: this.crop.y, w: this.crop.w, h: this.crop.h }; }
  private drag(e: GestureEvent, corner: number): void {
    const dx: number = e.offsetX / this.photoWidth();
    const dy: number = e.offsetY / this.photoHeight();
    let left: number = this.base.x;
    let top: number = this.base.y;
    let right: number = left + this.base.w;
    let bottom: number = top + this.base.h;
    if (corner < 0) {
      left = Math.max(0, Math.min(1 - this.base.w, left + dx));
      top = Math.max(0, Math.min(1 - this.base.h, top + dy));
      right = left + this.base.w; bottom = top + this.base.h;
    } else {
      if (corner === 0 || corner === 2) left = Math.max(0, Math.min(right - 0.08, left + dx));
      else right = Math.min(1, Math.max(left + 0.08, right + dx));
      if (corner === 0 || corner === 1) top = Math.max(0, Math.min(bottom - 0.08, top + dy));
      else bottom = Math.min(1, Math.max(top + 0.08, bottom + dy));
    }
    this.crop = { x: left, y: top, w: right - left, h: bottom - top };
    this.queueSearch();
  }
  @Builder
  private corner(index: number) {
    Image($r('app.media.image_crop_corner')).width(28).height(28)
      .rotate({ angle: index === 0 ? 0 : index === 1 ? 90 : index === 2 ? 270 : 180 })
      .position({ x: this.photoX() + (this.crop.x + (index === 1 || index === 3 ? this.crop.w : 0)) * this.photoWidth() - 14,
        y: this.photoY() + (this.crop.y + (index > 1 ? this.crop.h : 0)) * this.photoHeight() - 14 })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityText(this.uiText("调整搜索区域角点"))
  }
  @Builder
  private card(p: PinmonyRelatedPin) {
    Image(p.imageUrl).width('100%').height(Math.max(100, Math.min(430, (this.widthValue - 30) / 2 * p.imageHeight / p.imageWidth)))
      .objectFit(ImageFit.Cover).borderRadius(16)
      .onClick(() => { this.sheetVisible = false; if (this.onRelated) this.onRelated(p.id); })
      .accessibilityText(p.title || this.uiText("打开相关 Pin"))
  }
  @Builder
  private resultsPanel() {
    Column({ space: 12 }) {
      Scroll(this.resultScroller) {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Column({ space: 10 }) {
              ForEach(this.result.items.filter((_p: PinmonyRelatedPin, i: number): boolean => i % 2 === 0),
                (p: PinmonyRelatedPin) => { this.card(p) }, (p: PinmonyRelatedPin): string => p.id)
            }.layoutWeight(1)
            Column({ space: 10 }) {
              ForEach(this.result.items.filter((_p: PinmonyRelatedPin, i: number): boolean => i % 2 === 1),
                (p: PinmonyRelatedPin) => { this.card(p) }, (p: PinmonyRelatedPin): string => p.id)
            }.layoutWeight(1)
          }.width('100%').alignItems(VerticalAlign.Top)
          if (this.result.error) {
            Text(PinmonyI18n.render(this.result.error, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("重试")).onClick(() => { if (this.onSearch) this.onSearch(this.crop, this.result.items.length > 0, false); })
          } else if (!this.result.loading && this.result.items.length === 0) {
            Text(this.uiText("暂无相关图片")).fontColor($r('app.color.secondary_text')).fontSize(14)
          }
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .onReachEnd(() => {
          if (!this.result.loading && !this.result.error && !this.result.ended && this.result.items.length && this.onSearch)
            this.onSearch(this.crop, true, false);
        })
    }.padding({ left: 10, right: 10, top: 8, bottom: 16 }).width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
  @Builder
  private searchContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(this.imageUrl).width(this.photoWidth()).height(this.photoHeight()).objectFit(ImageFit.Contain)
        .position({ x: this.photoX(), y: this.photoY() }).hitTestBehavior(HitTestMode.None)
      Rect().fill('#77000000').width(this.photoWidth()).height(this.crop.y * this.photoHeight())
        .position({ x: this.photoX(), y: this.photoY() }).hitTestBehavior(HitTestMode.None)
      Rect().fill('#77000000').width(this.photoWidth()).height((1 - this.crop.y - this.crop.h) * this.photoHeight())
        .position({ x: this.photoX(), y: this.photoY() + (this.crop.y + this.crop.h) * this.photoHeight() }).hitTestBehavior(HitTestMode.None)
      Rect().fill('#77000000').width(this.crop.x * this.photoWidth()).height(this.crop.h * this.photoHeight())
        .position({ x: this.photoX(), y: this.photoY() + this.crop.y * this.photoHeight() }).hitTestBehavior(HitTestMode.None)
      Rect().fill('#77000000').width((1 - this.crop.x - this.crop.w) * this.photoWidth()).height(this.crop.h * this.photoHeight())
        .position({ x: this.photoX() + (this.crop.x + this.crop.w) * this.photoWidth(), y: this.photoY() + this.crop.y * this.photoHeight() }).hitTestBehavior(HitTestMode.None)
      Row().width(this.crop.w * this.photoWidth()).height(this.crop.h * this.photoHeight())
        .border({ width: 1, color: Color.White }).borderRadius(12).backgroundColor(Color.Transparent)
        .position({ x: this.photoX() + this.crop.x * this.photoWidth(), y: this.photoY() + this.crop.y * this.photoHeight() })
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText(this.uiText("移动搜索区域"))
      this.corner(0)
      this.corner(1)
      this.corner(2)
      this.corner(3)
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .onAreaChange((_old: Area, area: Area) => { this.widthValue = Number(area.width); this.heightValue = Number(area.height); })
      .onTouch((event: TouchEvent) => {
        if (event.type !== TouchType.Down || !event.touches.length) return;
        const x: number = event.touches[0].x;
        const y: number = event.touches[0].y;
        const left: number = this.photoX() + this.crop.x * this.photoWidth();
        const top: number = this.photoY() + this.crop.y * this.photoHeight();
        const right: number = left + this.crop.w * this.photoWidth();
        const bottom: number = top + this.crop.h * this.photoHeight();
        this.dragCorner = -2;
        if (Math.abs(x - left) <= 22 && Math.abs(y - top) <= 22) this.dragCorner = 0;
        else if (Math.abs(x - right) <= 22 && Math.abs(y - top) <= 22) this.dragCorner = 1;
        else if (Math.abs(x - left) <= 22 && Math.abs(y - bottom) <= 22) this.dragCorner = 2;
        else if (Math.abs(x - right) <= 22 && Math.abs(y - bottom) <= 22) this.dragCorner = 3;
        else if (x >= left && x <= right && y >= top && y <= bottom) this.dragCorner = -1;
      })
      .gesture(PanGesture().onActionStart(() => this.startDrag()).onActionUpdate((event: GestureEvent) => {
        if (this.dragCorner >= -1) this.drag(event, this.dragCorner);
      }))
  }
  build() {
    Column() { this.searchContent() }.width('100%').height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .bindSheet($$this.sheetVisible, this.resultsPanel, {
        radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
        onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyVisualSearchView.sheetVisible radius=four-corners-32vp'); },
        height: this.sheetHeight, detents: ['40%', SheetSize.LARGE], showClose: true, dragBar: true, title: { title: this.uiText("更多此类 Pin 图") },
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        backgroundColor: $r('app.color.page_background'), maskColor: Color.Transparent, enableOutsideInteractive: true,
        onHeightDidChange: (height: number) => { this.expanded = this.getUIContext().px2vp(height) > this.heightValue * 0.7; },
        onDetentsDidChange: (height: number) => {
          this.sheetHeight = this.getUIContext().px2vp(height) > this.heightValue * 0.7 ? SheetSize.LARGE : '40%';
        },
        onDisappear: () => { if (this.alive && this.onClose) this.onClose(); }
      })
  }
}
