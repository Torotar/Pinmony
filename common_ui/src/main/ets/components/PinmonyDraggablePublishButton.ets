import { PinmonyI18n, PinmonyRuntimeLog, PinmonyPublishAnchor } from 'common_foundation';
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

@Component
export struct PinmonyDraggablePublishButton {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @Prop @Watch('resize') areaWidth: number = 0;
  @Prop @Watch('resize') areaHeight: number = 0;
  @Prop @Watch('syncMenuAvailability') actionEnabled: boolean = true;
  onPublish?: () => void;
  @Prop @Watch('syncMenuAvailability') menuEnabled: boolean = false;
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
  private mounted: boolean = false;
  private pendingMenuAction?: () => void;

  private left(): number { return Math.min(16, Math.max(0, (this.areaWidth - 56) / 2)); }
  private top(): number { return Math.min(16, Math.max(0, (this.areaHeight - 76) / 2)); }
  private maxX(): number { return Math.max(this.left(), this.areaWidth - 72); }
  private maxY(): number { return Math.max(this.top(), this.areaHeight - 76); }
  private clamp(value: number, min: number, max: number): number { return Math.max(min, Math.min(max, value)); }
  aboutToAppear(): void {
    this.mounted = true;
    this.xFraction = Number.isFinite(this.xFraction) ? this.clamp(this.xFraction,0,1) : (this.right ? 1 : 0);
    this.fraction = Number.isFinite(this.fraction) ? this.clamp(this.fraction, 0, 1) : 1; this.resize();
  }
  aboutToDisappear(): void {
    this.mounted = false;
    this.menuOpen = false;
    this.pendingMenuAction = undefined;
  }
  private syncMenuAvailability(): void {
    if (!this.menuEnabled || !this.actionEnabled) {
      this.menuOpen = false;
      this.pendingMenuAction = undefined;
    }
  }
  private selectMenuItem(item: MenuElement): void {
    if (!this.mounted || !this.menuOpen || this.pendingMenuAction || !this.menuEnabled ||
      !this.actionEnabled || item.enabled === false) return;
    this.pendingMenuAction = item.action;
    this.menuOpen = false;
    PinmonyRuntimeLog.info('PublishMenuTrace: event=selection-close');
  }
  private boundMenuItems(): MenuElement[] {
    return this.menuItems.map((item: MenuElement): MenuElement => ({
      value: item.value, icon: item.icon, symbolIcon: item.symbolIcon, enabled: item.enabled,
      action: (): void => this.selectMenuItem(item)
    }));
  }
  private finishMenuClose(): void {
    this.menuOpen = false;
    const action: (() => void) | undefined = this.pendingMenuAction;
    this.pendingMenuAction = undefined;
    PinmonyRuntimeLog.info('PublishMenuTrace: event=closed');
    if (this.mounted && this.menuEnabled && this.actionEnabled) action?.();
  }
  private sourceMenuOptions(): MenuOptions {
    const options: MenuOptions = {
      backgroundColor: $r('app.color.publish_source_button_glass'),
      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
      onAppear: (): void => { PinmonyRuntimeLog.info('PublishMenuTrace: event=shown'); },
      onDisappear: (): void => this.finishMenuClose()
    };
    if (!this.menuEnabled) return options;
    if (deviceInfo.apiAvailable('26.0.0')) {
      let active: boolean = false;
      if (this.immersiveLightMode !== 'off') {
        try { active = uiMaterial.isImmersiveMaterialSupported(); }
        catch (_) { /* Preserve the ordinary menu when capability lookup is unavailable. */ }
      }
      options.systemMaterial = active ? new uiMaterial.ImmersiveMaterial({
        style: this.immersiveLightMode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
        colorInvert: false, applyShadow: true, interactive: true,
        lightEffect: { color: $r('app.color.immersive_interaction_light') }
      }) : uiMaterial.Material.empty;
      if (active) {
        options.backgroundColor = Color.Transparent;
        options.backgroundBlurStyle = BlurStyle.NONE;
      }
    }
    return options;
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
      .backgroundEffect({radius:20,saturation:1,brightness:1,color:$r('app.color.publish_button_glass')})
      .borderRadius(16).clip(true).fontColor($r('app.color.primary_text'))
      .position({ x: this.x, y: this.y })
      .enabled(this.actionEnabled)
      .visibility(this.areaWidth >= 56 && this.areaHeight >= 56 ? Visibility.Visible : Visibility.Hidden)
      .accessibilityText(PinmonyI18n.text('pm_publish_b61f333b', this.uiLanguage))
      .onClick(() => {
        if (this.actionEnabled && !this.dragging && !this.pendingMenuAction && Date.now() >= this.suppressClickUntil) { if (this.menuEnabled) { this.menuOpen = true; PinmonyRuntimeLog.info('PublishMenuTrace: event=request items=' + this.menuItems.length.toString()); } else this.onPublish?.(); }
      })
      .bindMenu(this.menuEnabled && this.menuOpen,this.boundMenuItems(),this.sourceMenuOptions())
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
