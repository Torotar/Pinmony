// Only this component observes the collapse animation; result cards do not.
export class PinmonySearchCategoryBarController {
  private collapsed: boolean = false;
  private readonly listeners: Set<(collapsed: boolean) => void> = new Set<(collapsed: boolean) => void>();

  isCollapsed(): boolean { return this.collapsed; }

  bind(listener: (collapsed: boolean) => void): void {
    this.listeners.add(listener);
  }

  unbind(listener: (collapsed: boolean) => void): void {
    this.listeners.delete(listener);
  }

  setCollapsed(collapsed: boolean): void {
    if (this.collapsed === collapsed) return;
    this.collapsed = collapsed;
    this.listeners.forEach((listener: (collapsed: boolean) => void): void => listener(collapsed));
  }
}

@Component
export struct PinmonySearchCategoryBar {
  controller: PinmonySearchCategoryBarController = new PinmonySearchCategoryBarController();
  @BuilderParam content: () => void;
  @State private collapsed: boolean = false;
  private readonly updateCollapsed: (collapsed: boolean) => void = (collapsed: boolean): void => {
    if (this.collapsed === collapsed) return;
    this.collapsed = collapsed;
  };

  aboutToAppear(): void {
    // Restore before the first frame; mounting a retained title is not a scroll gesture.
    this.collapsed = this.controller.isCollapsed();
    this.controller.bind(this.updateCollapsed);
  }
  aboutToDisappear(): void { this.controller.unbind(this.updateCollapsed); }

  build() {
    Scroll() { this.content() }
      .width('100%').height(54)
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .align(Alignment.Start).clip(true)
      .opacity(this.collapsed ? 0 : 1)
      .translate({ y: this.collapsed ? -12 : 0 })
      .animation({ duration: 180, curve: Curve.EaseOut })
      .hitTestBehavior(this.collapsed ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(this.collapsed ? 'no-hide-descendants' : 'auto')
  }
}
