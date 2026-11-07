import { HdsSnackBar, SnackBarIconOptions, SnackBarMessageOptions, SnackBarOperationOptions,
  SnackBarStyleOptions } from '@kit.UIDesignKit';
import { PinmonyRuntimeLog } from 'common_foundation';

// Keep the official HDS UI. Some native implementations may return a completion
// thenable despite the SDK's void signature. Observe it at the call boundary;
// synchronous try/catch alone cannot handle a later native close rejection.
export class PinmonySnackBarLifecycle {
  private static current: HdsSnackBar | undefined = undefined;
  private static expiresAt: number = 0;

  static isCurrent(snack: HdsSnackBar): boolean {
    return PinmonySnackBarLifecycle.current === snack && Date.now() < PinmonySnackBarLifecycle.expiresAt;
  }

  private static release(snack: HdsSnackBar): void {
    if (PinmonySnackBarLifecycle.current !== snack) return;
    PinmonySnackBarLifecycle.current = undefined;
    PinmonySnackBarLifecycle.expiresAt = 0;
  }

  static show(snack: HdsSnackBar, icon: SnackBarIconOptions, message: SnackBarMessageOptions,
    operation: SnackBarOperationOptions, style: SnackBarStyleOptions): void {
    const previous: HdsSnackBar | undefined = PinmonySnackBarLifecycle.current;
    if (previous) PinmonySnackBarLifecycle.dismiss(previous);
    PinmonySnackBarLifecycle.current = snack;
    const duration: number = style.duration ?? 4000;
    PinmonySnackBarLifecycle.expiresAt = duration <= 0 ? Number.POSITIVE_INFINITY : Date.now() + duration;
    const back: (() => void) | undefined = style.pressBackCallback;
    const close: (() => void) | undefined = operation.onCloseButtonClick;
    const content: (() => void) | undefined = operation.onContentClick;
    // Revoke global ownership before HDS notifies the page. The old page may
    // unmount later, after a different feature has already shown its notice.
    style.pressBackCallback = (): void => {
      if (PinmonySnackBarLifecycle.current !== snack) return;
      PinmonySnackBarLifecycle.release(snack); back?.();
    };
    operation.onCloseButtonClick = (): void => {
      if (PinmonySnackBarLifecycle.current !== snack) return;
      PinmonySnackBarLifecycle.release(snack); close?.();
    };
    operation.onContentClick = (): void => {
      if (PinmonySnackBarLifecycle.current !== snack || Date.now() >= PinmonySnackBarLifecycle.expiresAt) return;
      content?.();
    };
    try {
      Promise.resolve<void>(snack.show(icon, message, operation, style)).catch((): void => {
        PinmonySnackBarLifecycle.release(snack);
        PinmonyRuntimeLog.warn('SnackBarNative: operation=show outcome=rejected');
      });
    } catch (_) {
      PinmonySnackBarLifecycle.release(snack);
      PinmonyRuntimeLog.warn('SnackBarNative: operation=show outcome=threw');
    }
  }

  static dismiss(snack: HdsSnackBar): void {
    if (PinmonySnackBarLifecycle.current !== snack) return;
    const expired: boolean = Date.now() >= PinmonySnackBarLifecycle.expiresAt;
    PinmonySnackBarLifecycle.release(snack);
    if (expired) return;
    try {
      Promise.resolve<void>(snack.dismiss()).catch((): void => {
        PinmonyRuntimeLog.warn('SnackBarNative: operation=dismiss outcome=rejected');
      });
    } catch (_) {
      PinmonyRuntimeLog.warn('SnackBarNative: operation=dismiss outcome=threw');
    }
  }
}
