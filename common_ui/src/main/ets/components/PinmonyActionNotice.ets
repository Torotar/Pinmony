import { HdsSnackBar, SnackBarIconType, SnackBarOperationType } from '@kit.UIDesignKit';

class PinmonyActionNoticeLease {
  static serial: number = 0;
  static close: (() => void) | undefined = undefined;
}

// Lifecycle adapter only. All visible content is rendered by the official HDS component.
@Component
export struct PinmonyActionNotice {
  @Prop @Watch('syncNotice') message: string = '';
  @Prop @Watch('syncNotice') actionText: string = '';
  @Prop @Watch('syncNotice') actionEnabled: boolean = true;
  @Prop @Watch('syncNotice') active: boolean = true;
  @Prop @Watch('syncNotice') scope: string = '';
  onAction?: () => void;
  private mounted: boolean = false;
  private snack: HdsSnackBar | undefined = undefined;
  private shownKey: string = '';
  private closedKey: string = '';
  private generation: number = 0;
  private lease: number = -1;

  aboutToAppear(): void { this.mounted = true; this.syncNotice(); }
  aboutToDisappear(): void { this.mounted = false; this.dismissNotice(); }
  private dismissNotice(): void {
    this.generation++;
    if (this.lease === PinmonyActionNoticeLease.serial) {
      this.snack?.dismiss();
      PinmonyActionNoticeLease.close = undefined;
    }
    this.lease = -1;
    this.shownKey = '';
  }
  private syncNotice(): void {
    const key: string = this.scope + ':' + this.message + ':' + this.actionText + ':' + this.actionEnabled;
    if (!this.mounted || !this.active || !this.message) { this.closedKey = ''; this.dismissNotice(); return; }
    if (key === this.shownKey || key === this.closedKey) return;
    this.dismissNotice();
    PinmonyActionNoticeLease.close?.();
    this.lease = ++PinmonyActionNoticeLease.serial;
    this.shownKey = key;
    PinmonyActionNoticeLease.close = () => { this.closedKey = this.shownKey; this.dismissNotice(); };
    const generation: number = this.generation;
    if (!this.snack) this.snack = new HdsSnackBar(this.getUIContext());
    const canAct: boolean = !!this.actionText && this.actionEnabled;
    const close = (): void => {
      if (generation !== this.generation || !this.mounted) return;
      this.closedKey = key;
      this.dismissNotice();
    };
    this.snack.show({ icon: $r('sys.symbol.exclamationmark_circle'), iconType: SnackBarIconType.NORMAL },
      { title: this.message }, {
        operationType: canAct ? SnackBarOperationType.TEXT_WITH_CLOSE : SnackBarOperationType.CLOSE_BUTTON_ONLY,
        content: canAct ? this.actionText : undefined,
        contentAccessibilityText: canAct ? this.actionText : undefined,
        onContentClick: () => {
          if (generation !== this.generation || !this.mounted || !this.active || !this.actionEnabled) return;
          close(); this.onAction?.();
        },
        onCloseButtonClick: close
      }, { duration: 4000, pressBackCallback: close });
  }
  build() {
    Blank().width(0).height(0).accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
  }
}
