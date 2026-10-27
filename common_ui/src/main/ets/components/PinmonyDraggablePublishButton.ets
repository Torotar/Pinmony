import { PinmonyI18n, PinmonyRuntimeLog, PinmonyPublishAnchor } from 'common_foundation';

@Component
export struct PinmonyDraggablePublishButton {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop @Watch('resize') areaWidth: number = 0;
  @Prop @Watch('resize') areaHeight: number = 0;
  @Prop actionEnabled: boolean = true;
  onPublish?: () => void;
  @Prop menuEnabled: boolean = false;
  @Prop menuItems: MenuElement[] = [];
  @State private menuOpen: boolean = false;
  @State private x: number = 0;
  @State private y: number = 0;
  @StorageLink('pinmonyPublishAnchorMoved') private moved: boolean = false;
  @StorageLink('pinmonyPublishAnchorRight') private right: boolean = true;
  @StorageLink('pinmonyPublishAnchorXFraction') private xFraction: number = 1;
  @StorageLink('pinmonyPublishAnchorFraction') private fraction: number = 1;
  private dragging: boolean = false;
  private startX: number = 0;
  private startY: number = 0;
  private suppressClickUntil: number = 0;
  private layoutWidth: number = 0;
  private layoutHeight: number = 0;

  private left(): number { return Math.min(16, Math.max(0, (this.areaWidth - 56) / 2)); }
  private top(): number { return Math.min(16, Math.max(0, (this.areaHeight - 76) / 2)); }
  private maxX(): number { return Math.max(this.left(), this.areaWidth - 72); }
  private maxY(): number { return Math.max(this.top(), this.areaHeight - 76); }
  private clamp(value: number, min: number, max: number): number { return Math.max(min, Math.min(max, value)); }
  aboutToAppear(): void {
    this.xFraction = Number.isFinite(this.xFraction) ? this.clamp(this.xFraction,0,1) : (this.right ? 1 : 0);
    this.fraction = Number.isFinite(this.fraction) ? this.clamp(this.fraction, 0, 1) : 1; this.resize();
  }
  private resize(): void {
    if (!Number.isFinite(this.areaWidth) || !Number.isFinite(this.areaHeight) ||
      this.areaWidth < 56 || this.areaHeight < 56) return;
    if (this.dragging) this.remember(this.layoutWidth, this.layoutHeight);
    this.dragging = false;
    this.layoutWidth = this.areaWidth; this.layoutHeight = this.areaHeight;
    this.x = this.moved ? this.left() + (this.maxX() - this.left()) * this.clamp(this.xFraction,0,1) : Math.max(0, (this.areaWidth - 56) / 2);
    this.y = this.top() + (this.maxY() - this.top()) * this.fraction;
    PinmonyRuntimeLog.info('PublishAnchorTrace: event=restore moved=' + this.moved + ' right=' + this.right);
  }
  private remember(width: number, height: number): void {
    if (width < 56 || height < 56) return;
    const top = Math.min(16, Math.max(0, (height - 76) / 2));
    const bottom = Math.max(top, height - 76);
    const left = Math.min(16, Math.max(0, (width - 56) / 2));
    const end = Math.max(left,width - 72);
    this.right = this.x + 28 >= width / 2;
    this.xFraction = end > left ? this.clamp((this.x - left) / (end - left),0,1) : this.xFraction;
    this.fraction = bottom > top ? this.clamp((this.y - top) / (bottom - top), 0, 1) : this.fraction;
    this.moved = true;
    PinmonyPublishAnchor.save(this.right,this.fraction,this.xFraction);
  }
  private start(): void {
    if (!this.actionEnabled) return;
    this.dragging = true;
    this.suppressClickUntil = Date.now() + 400;
    this.startX = this.x; this.startY = this.y;
  }
  private move(event: GestureEvent): void {
    if (!this.dragging || !this.actionEnabled) return;
    this.x = this.clamp(this.startX + event.offsetX, this.left(), this.maxX());
    this.y = this.clamp(this.startY + event.offsetY, this.top(), this.maxY());
  }
  private settle(): void {
    if (!this.dragging) return;
    this.dragging = false;
    this.suppressClickUntil = Date.now() + 400;
    this.remember(this.layoutWidth, this.layoutHeight);
    PinmonyRuntimeLog.info('PublishAnchorTrace: event=save right=' + this.right);
  }
  build() {
    Button('+', {type:ButtonType.Normal}).width(56).height(56).fontSize(32)
      .backgroundColor(Color.Transparent)
      .backgroundEffect({radius:20,saturation:1,brightness:1,color:this.menuEnabled ? $r('app.color.publish_source_button_glass') : $r('app.color.publish_button_glass')})
      .border({width:this.menuEnabled ? 1 : 0,color:$r('app.color.publish_source_button_outline')})
      .borderRadius(16).clip(true).fontColor($r('app.color.primary_text'))
      .position({ x: this.x, y: this.y })
      .enabled(this.actionEnabled)
      .visibility(this.areaWidth >= 56 && this.areaHeight >= 56 ? Visibility.Visible : Visibility.Hidden)
      .accessibilityText(PinmonyI18n.text('pm_publish_b61f333b', this.uiLanguage))
      .onClick(() => {
        if (this.actionEnabled && !this.dragging && Date.now() >= this.suppressClickUntil) { if (this.menuEnabled) { this.menuOpen = true; PinmonyRuntimeLog.info('PublishMenuTrace: event=request items=' + this.menuItems.length.toString()); } else this.onPublish?.(); }
      })
      .bindMenu(this.menuOpen,this.menuItems,{backgroundColor:$r('app.color.publish_source_button_glass'),backgroundBlurStyle:BlurStyle.COMPONENT_ULTRA_THICK,onAppear:(): void => {PinmonyRuntimeLog.info('PublishMenuTrace: event=shown');},onDisappear:(): void => {this.menuOpen = false;PinmonyRuntimeLog.info('PublishMenuTrace: event=closed');}})
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.settle();
      })
      .gesture(GestureGroup(GestureMode.Sequence,
        LongPressGesture({ repeat: false, duration: 450 }).onAction(() => this.start()),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
          .onActionUpdate((event: GestureEvent) => this.move(event))
          .onActionEnd(() => this.settle())
      ).onCancel(() => this.settle()))
  }
}
