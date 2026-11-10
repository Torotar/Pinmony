import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsSnackBar, SnackBarIconType, SnackBarOperationType } from '@kit.UIDesignKit';
import { PinmonySnackBarLifecycle } from '../services/PinmonySnackBarLifecycle';
import { PinmonyUiCommitQueue } from '../services/PinmonyUiCommitQueue';

class PinmonyActionNoticeLease {
  static serial: number = 0;
  static close: (() => void) | undefined = undefined;
}

// Lifecycle adapter only. All visible content is rendered by the official HDS component.
@Component
export struct PinmonyActionNotice {
  private readonly uiCommits: PinmonyUiCommitQueue = new PinmonyUiCommitQueue();
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
  private expiresAt: number = 0;

  aboutToAppear(): void { this.uiCommits.activate(); this.mounted = true; this.syncNotice(); }
  aboutToDisappear(): void { this.mounted = false; this.uiCommits.dispose(); this.dismissNotice(); }
  private dismissNotice(nativeClosed: boolean = false): void {
    this.generation++;
    const owns: boolean = this.lease === PinmonyActionNoticeLease.serial;
    const snack: HdsSnackBar | undefined = this.snack;
    const shouldDismiss: boolean = owns && !nativeClosed && Date.now() < this.expiresAt;
    // Revoke ownership before calling HDS: close callbacks may be synchronous.
    if (owns) PinmonyActionNoticeLease.close = undefined;
    this.lease = -1; this.shownKey = ''; this.expiresAt = 0; this.snack = undefined;
    if (shouldDismiss && snack) {
      PinmonyRuntimeLog.info('AsyncAction: stage=notice-dismiss');
      PinmonySnackBarLifecycle.dismiss(snack);
    }
  }
  private syncNotice(): void {
    if (!this.mounted) return;
    this.uiCommits.post('notice-state', (): void => { if (this.mounted) this.commitNotice(); });
  }
  private commitNotice(): void {
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
    const close = (nativeClosed: boolean = false): void => {
      if (generation !== this.generation || !this.mounted) return;
      this.closedKey = key;
      this.dismissNotice(nativeClosed);
    };
    this.expiresAt = Date.now() + 4000;
    PinmonyRuntimeLog.info('AsyncAction: stage=notice-show');
    try { PinmonySnackBarLifecycle.show(this.snack, { icon: $r('sys.symbol.exclamationmark_circle'), iconType: SnackBarIconType.NORMAL },
      { title: this.message }, {
        operationType: canAct ? SnackBarOperationType.TEXT_WITH_CLOSE : SnackBarOperationType.CLOSE_BUTTON_ONLY,
        content: canAct ? this.actionText : undefined,
        contentAccessibilityText: canAct ? this.actionText : undefined,
        onContentClick: () => {
          if (generation !== this.generation || !this.mounted || !this.active || !this.actionEnabled) return;
          close(); this.onAction?.();
        },
        onCloseButtonClick: (): void => close(true)
      }, { duration: 4000, pressBackCallback: (): void => close(true) });
    } catch (_) { this.closedKey = key; this.dismissNotice(true); PinmonyRuntimeLog.warn('ActionNotice: show-failed'); }
  }
  build() {
    Blank().width(0).height(0).accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
  }
}
