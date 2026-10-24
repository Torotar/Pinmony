import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

// Presentation hint only. This flag never grants access or replaces server verification.
export class PinmonySessionHistory {
  private static storage: preferences.Preferences | undefined = undefined;

  static initialize(context: common.Context): void {
    try {
      PinmonySessionHistory.storage = preferences.getPreferencesSync(context, { name: 'pinmony_session_history' });
      const confirmed: preferences.ValueType = PinmonySessionHistory.storage.getSync('confirmed', false);
      AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', confirmed === true);
    } catch (_) {
      PinmonySessionHistory.storage = undefined;
      AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', false);
    }
  }

  static save(confirmed: boolean): boolean {
    AppStorage.setOrCreate<boolean>('pinmonySessionConfirmed', confirmed);
    try {
      if (!PinmonySessionHistory.storage) return false;
      PinmonySessionHistory.storage.putSync('confirmed', confirmed);
      PinmonySessionHistory.storage.flushSync();
      return true;
    } catch (_) { return false; }
  }
}
