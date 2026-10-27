import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

export class PinmonyProfileLayoutPreference {
  private static storage: preferences.Preferences | undefined = undefined;
  static initialize(context: common.Context): void {
    try {
      PinmonyProfileLayoutPreference.storage = preferences.getPreferencesSync(context, {name:'pinmony_profile_layout'});
      const value: preferences.ValueType = PinmonyProfileLayoutPreference.storage.getSync('avatarRight', false);
      AppStorage.setOrCreate('profileAvatarRight', value === true);
      const density: preferences.ValueType = PinmonyProfileLayoutPreference.storage.getSync('pinDensity', 1);
      AppStorage.setOrCreate('pinmonyProfilePinDensity', typeof density === 'number' && Number.isInteger(density) && density >= 0 && density <= 2 ? density : 1);
      const boardDensity: preferences.ValueType = PinmonyProfileLayoutPreference.storage.getSync('boardDensity', 1);
      AppStorage.setOrCreate('pinmonyBoardDensity', typeof boardDensity === 'number' && Number.isInteger(boardDensity) && boardDensity >= 0 && boardDensity <= 2 ? boardDensity : 1);
      PinmonyRuntimeLog.info('ProfileLayoutTrace: event=restored avatarRight=' + (value === true).toString());
    } catch (_) { PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=restore-failed'); }
  }
  static savePinDensity(value: number): boolean {
    if (!Number.isInteger(value) || value < 0 || value > 2) return false;
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('pinDensity', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('pinmonyProfilePinDensity', value);
      return true;
    } catch (_) {
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=pin-density-save-failed');
      return false;
    }
  }
  static saveBoardDensity(value: number): boolean {
    if (!Number.isInteger(value) || value < 0 || value > 2) return false;
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('boardDensity', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('pinmonyBoardDensity', value);
      return true;
    } catch (_) {
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=board-density-save-failed');
      return false;
    }
  }
  static saveAvatarRight(value: boolean): boolean {
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('avatarRight', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('profileAvatarRight', value);
      PinmonyRuntimeLog.info('ProfileLayoutTrace: event=saved avatarRight=' + value.toString());
      return true;
    } catch (_) {
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=save-failed');
      return false;
    }
  }
}
