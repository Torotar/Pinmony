import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { PinmonyRuntimeLog } from 'common_foundation';

// One owner per shared viewer host. Serialize native updates so a late hide
// cannot win over return, cancellation or a newly presented viewer.
export class PinmonyViewerSystemBars {
  private static owners: Set<number> = new Set<number>();
  private static serial: number = 0;
  private static running: boolean = false;
  private static hidden: boolean = false;
  private static mainWindow: window.Window | undefined = undefined;
  private static pending: Promise<void> = Promise.resolve();

  static acquire(context: common.Context): number {
    const owner: number = ++PinmonyViewerSystemBars.serial;
    PinmonyViewerSystemBars.owners.add(owner);
    AppStorage.setOrCreate('pinmonyViewerPreserveStatusInset', true);
    PinmonyViewerSystemBars.requestSync(context);
    return owner;
  }

  static release(owner: number, context: common.Context): Promise<void> {
    if (!PinmonyViewerSystemBars.owners.delete(owner)) return PinmonyViewerSystemBars.pending;
    return PinmonyViewerSystemBars.requestSync(context);
  }

  private static requestSync(context: common.Context): Promise<void> {
    if (!PinmonyViewerSystemBars.running) PinmonyViewerSystemBars.pending = PinmonyViewerSystemBars.sync(context);
    return PinmonyViewerSystemBars.pending;
  }

  private static async sync(context: common.Context): Promise<void> {
    if (PinmonyViewerSystemBars.running) return;
    PinmonyViewerSystemBars.running = true;
    try {
      while (PinmonyViewerSystemBars.hidden !== (PinmonyViewerSystemBars.owners.size > 0)) {
        if (!PinmonyViewerSystemBars.mainWindow) {
          PinmonyViewerSystemBars.mainWindow = await window.getLastWindow(context);
        }
        const hide: boolean = PinmonyViewerSystemBars.owners.size > 0;
        if (hide === PinmonyViewerSystemBars.hidden) break;
        // Keep the bar enabled: its avoid area must not change under the viewer.
        // The full-screen viewer paints underneath transparent system chrome.
        AppStorage.setOrCreate('pinmonyViewerStatusCovered', hide);
        const contentColor: string = AppStorage.get<boolean>('systemDarkMode') === true ? '#F7F8FA' : '#1B1E25';
        await PinmonyViewerSystemBars.mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000', statusBarContentColor: hide ? '#00000000' : contentColor
        });
        PinmonyViewerSystemBars.hidden = hide;
      }
    } catch (_) {
      PinmonyRuntimeLog.warn('ViewerSystemBars: status update failed');
    } finally {
      PinmonyViewerSystemBars.running = false;
      AppStorage.setOrCreate('pinmonyViewerStatusCovered', PinmonyViewerSystemBars.hidden);
      if (!PinmonyViewerSystemBars.hidden && PinmonyViewerSystemBars.owners.size === 0) {
        AppStorage.setOrCreate('pinmonyViewerPreserveStatusInset', false);
      }
      if (!PinmonyViewerSystemBars.hidden) PinmonyViewerSystemBars.mainWindow = undefined;
    }
  }
}
