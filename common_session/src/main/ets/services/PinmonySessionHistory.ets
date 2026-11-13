import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

// Presentation hint only. This flag never grants access or replaces server verification.
export class PinmonySessionHistory {
  private static storage: preferences.Preferences | undefined = undefined;

  static initialize(context: common.Context): void {
    try {
      PinmonySessionHistory.storage = preferences.getPreferencesSync(context, { name: 'pinmony_session_history' });
      const confirmed: preferences.ValueType = PinmonySessionHistory.storage.getSync('confirmed', false);
      const manual: preferences.ValueType = PinmonySessionHistory.storage.getSync('manual_login_required', confirmed !== true);
      AppStorage.setOrCreate<boolean>('pinmonyManualLoginRequired', confirmed !== true || manual === true);
      AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', confirmed === true && manual !== true);
    } catch (_) {
      PinmonySessionHistory.storage = undefined;
      AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', false);
      AppStorage.setOrCreate<boolean>('pinmonyManualLoginRequired', true);
    }
  }

  // Persist user intent only, never an account identity or website credential.
  static requireManualLogin(): boolean {
    AppStorage.setOrCreate<boolean>('pinmonyManualLoginRequired', true);
    AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', false);
    try {
      if (!PinmonySessionHistory.storage) return false;
      PinmonySessionHistory.storage.putSync('manual_login_required', true);
      PinmonySessionHistory.storage.putSync('confirmed', false);
      PinmonySessionHistory.storage.flushSync();
      return true;
    } catch (_) { return false; }
  }

  static save(confirmed: boolean): boolean {
    if (!confirmed) AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', false);
    try {
      if (!PinmonySessionHistory.storage) return false;
      if (confirmed) PinmonySessionHistory.storage.putSync('manual_login_required', false);
      PinmonySessionHistory.storage.putSync('confirmed', confirmed);
      PinmonySessionHistory.storage.flushSync();
      AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', confirmed);
      if (confirmed) AppStorage.setOrCreate<boolean>('pinmonyManualLoginRequired', false);
      return true;
    } catch (_) { return false; }
  }
}
