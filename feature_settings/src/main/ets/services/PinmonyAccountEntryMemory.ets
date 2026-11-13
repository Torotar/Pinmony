import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from 'common_foundation';

// Presentation only; never stores account identities or authorizes a switch.
export class PinmonyAccountEntryMemory {
  private static storage: preferences.Preferences | undefined = undefined;
  static initialize(context: common.Context): boolean {
    try {
      PinmonyAccountEntryMemory.storage = preferences.getPreferencesSync(context, { name: 'pinmony_account_entry' });
      return PinmonyAccountEntryMemory.storage.getSync('switchMode', false) === true;
    } catch (_) { PinmonyAccountEntryMemory.storage = undefined; return false; }
  }
  static save(switchMode: boolean): void {
    try {
      if (!PinmonyAccountEntryMemory.storage) return;
      PinmonyAccountEntryMemory.storage.putSync('switchMode', switchMode);
      PinmonyAccountEntryMemory.storage.flushSync();
    } catch (_) { PinmonyRuntimeLog.warn('AccountEntry: presentation preference unavailable'); }
  }
}
