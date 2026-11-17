import { PinmonyI18n } from 'common_foundation';

@Component
export struct PinmonyBackToTopButton {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop @Watch('availabilityChanged') showButton: boolean = false;
  @Prop @Watch('availabilityChanged') scrollOffsetVp: number = 0;
  @Prop bottomInset: number = 112;
  onBackToTop?: () => void;
  @State private hostWidth: number = 0;
  @State private hostHeight: number = 0;
  private mounted: boolean = false;
  private tracking: boolean = false;
  private touchId: number = -1;
  private startX: number = 0;
  private startY: number = 0;
  private pulled: boolean = false;
  private suppressClickUntil: number = 0;

  aboutToAppear(): void { this.mounted = true; }
  aboutToDisappear(): void {
    this.mounted = false;
    this.resetFeedback(true);
  }
  private availabilityChanged(): void {
    if (!this.shouldShow()) this.resetFeedback(true);
  }
  private shouldShow(): boolean {
    return this.showButton && Number.isFinite(this.scrollOffsetVp) && this.hostHeight > 0 &&
      this.scrollOffsetVp >= this.hostHeight * 2;
  }
  private resetFeedback(cancelled: boolean = false): void {
    if (cancelled || this.pulled) this.suppressClickUntil = Date.now() + 400;
    this.tracking = false;
    this.touchId = -1;
    this.pulled = false;
  }
  private updateHostArea(width: number, height: number): void {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width < 0 || height < 0) return;
    if (this.hostWidth !== width) this.hostWidth = width;
    if (this.hostHeight !== height) {
      this.hostHeight = height;
      this.availabilityChanged();
    }
  }
  private hitLeft(): number { return Math.max(0, this.hostWidth - 44 - 20); }
  private hitTop(): number { return Math.max(0, this.hostHeight - 44 - this.bottomInset); }
  private click(): void {
    if (this.mounted && this.shouldShow() && !this.pulled && Date.now() >= this.suppressClickUntil) {
      this.onBackToTop?.();
    }
  }
  private touch(event: TouchEvent): void {
    event.stopPropagation();
    if (!this.mounted || !this.shouldShow()) return;
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.resetFeedback(event.type === TouchType.Cancel);
      return;
    }
    if (event.touches.length !== 1) {
      this.resetFeedback(true);
      return;
    }
    const point: TouchObject = event.touches[0];
    if (!Number.isFinite(point.windowX) || !Number.isFinite(point.windowY)) return;
    if (event.type === TouchType.Down) {
      this.tracking = true;
      this.touchId = point.id;
      this.startX = point.windowX;
      this.startY = point.windowY;
      this.pulled = false;
    } else if (event.type === TouchType.Move && this.tracking && point.id === this.touchId) {
      const dx: number = point.windowX - this.startX;
      const dy: number = point.windowY - this.startY;
      if (Math.abs(dx) + Math.abs(dy) > 6) this.pulled = true;
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Button({ type: ButtonType.Circle }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(22)
            .fontColor([$r('app.color.primary_text')])
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      }.width(44).height(44).padding(0)
        .backgroundColor(Color.Transparent)
        .backgroundEffect({radius:20,saturation:1,brightness:1,color:$r('app.color.publish_button_glass')})
        .clip(true)
        .shadow({ radius: this.getUIContext().vp2px(8), color: '#26000000',
          offsetX: 0, offsetY: this.getUIContext().vp2px(2) })
        .stateEffect(false)
        .margin({ right: 20, bottom: this.bottomInset })
        .enabled(this.shouldShow())
        .accessibilityText(PinmonyI18n.text('pm_back_to_top', this.uiLanguage))
        .onClick(() => this.click())
        .onTouch((event: TouchEvent) => this.touch(event))
        .hitTestBehavior(HitTestMode.Block)
    }.width('100%').height('100%').direction(Direction.Ltr)
      .onAreaChange((_old: Area, area: Area) => this.updateHostArea(Number(area.width), Number(area.height)))
      .responseRegion({ x: this.hitLeft(), y: this.hitTop(), width: 44, height: 44 })
      .hitTestBehavior(HitTestMode.Default)
      .visibility(this.shouldShow() ? Visibility.Visible : Visibility.Hidden)
  }
}
