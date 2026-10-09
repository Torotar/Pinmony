import { PinWebDetailSnapshot, PinWebDetailAction } from '../models/PinWebDetail';

@Component
export struct PinWebImageViewer {
  @Prop detail: PinWebDetailSnapshot;
  @Prop imageUrl: string = '';
  @Prop actionsReady: boolean = false;
  @State private controls: boolean = true;
  @State private scaleValue: number = 1;
  @State private dx: number = 0;
  @State private dy: number = 0;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 720;
  private startScale: number = 1;
  private startX: number = 0;
  private startY: number = 0;
  onControlsChange?: (visible: boolean) => void;
  onClose?: () => void;
  onAction?: (id: string, kind: string) => void;
  onDownload?: () => void;
  onSave?: () => void;

  private action(kind: string): PinWebDetailAction | undefined {
    return this.detail.actions.find((a: PinWebDetailAction): boolean => a.kind === kind);
  }

  @Builder
  private tool(icon: Resource, label: string, click: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon).width(24).height(24).objectFit(ImageFit.Contain)
    }.width(44).height(44).backgroundColor('#55303030').onClick(click).accessibilityText(label)
  }

  @Builder
  private imageContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(this.imageUrl || this.detail.imageUrl).width('100%').height('100%').objectFit(ImageFit.Contain)
        .scale({ x: this.scaleValue, y: this.scaleValue }).translate({ x: this.dx, y: this.dy })
        .onClick(() => { this.controls = !this.controls; if (this.onControlsChange) this.onControlsChange(this.controls); })
        .gesture(GestureGroup(GestureMode.Parallel,
          PinchGesture().onActionStart(() => { this.startScale = this.scaleValue; })
            .onActionUpdate((e: GestureEvent) => {
              this.scaleValue = Math.max(1, Math.min(6, this.startScale * e.scale));
              if (this.scaleValue === 1) { this.dx = 0; this.dy = 0; }
            }),
          PanGesture().onActionStart(() => { this.startX = this.dx; this.startY = this.dy; })
            .onActionUpdate((e: GestureEvent) => {
              if (this.scaleValue > 1) { this.dx = Math.max(-this.viewportWidth * (this.scaleValue - 1) / 2, Math.min(this.viewportWidth * (this.scaleValue - 1) / 2, this.startX + e.offsetX));
                this.dy = Math.max(-this.viewportHeight * (this.scaleValue - 1) / 2, Math.min(this.viewportHeight * (this.scaleValue - 1) / 2, this.startY + e.offsetY)); }
            })
        ))
    }.width('100%').height('100%').backgroundColor('#171717').clip(true)
      .onAreaChange((_old: Area, area: Area) => { this.viewportWidth = Number(area.width); this.viewportHeight = Number(area.height); })
  }

  build() { this.imageContent() }
}
