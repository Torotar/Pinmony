import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

export class PinmonyProfileLayoutPreference {
  private static storage: preferences.Preferences | undefined = undefined;
  static initialize(context: common.Context): void {
    PinmonyProfileLayoutPreference.storage = undefined;
    try {
      const storage: preferences.Preferences = preferences.getPreferencesSync(context, {name:'pinmony_profile_layout'});
      const legacy: preferences.ValueType = storage.getSync('legacyLayout', AppStorage.get<boolean>('profileLegacyLayout') === true);
      const value: preferences.ValueType = storage.getSync('avatarRight', false);
      const density: preferences.ValueType = storage.getSync('pinDensity', 1);
      const boardDensity: preferences.ValueType = storage.getSync('boardDensity', 1);
      storage.putSync('legacyLayout', legacy === true);
      storage.flushSync();
      PinmonyProfileLayoutPreference.storage = storage;
      AppStorage.setOrCreate('profileLegacyLayout', legacy === true);
      AppStorage.setOrCreate('profileAvatarRight', value === true);
      AppStorage.setOrCreate('pinmonyProfilePinDensity', typeof density === 'number' && Number.isInteger(density) && density >= 0 && density <= 2 ? density : 1);
      AppStorage.setOrCreate('pinmonyBoardDensity', typeof boardDensity === 'number' && Number.isInteger(boardDensity) && boardDensity >= 0 && boardDensity <= 2 ? boardDensity : 1);
      PinmonyRuntimeLog.info('ProfileLayoutTrace: event=restored avatarRight=' + (value === true).toString() + ' legacy=' + (legacy === true).toString());
    } catch (_) { PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=restore-failed'); }
  }
  static saveLegacyLayout(value: boolean): boolean {
    const previous: boolean = AppStorage.get<boolean>('profileLegacyLayout') === true;
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('legacyLayout', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('profileLegacyLayout', value);
      PinmonyRuntimeLog.info('ProfileLayoutTrace: event=saved legacy=' + value.toString());
      return true;
    } catch (_) {
      try {
        PinmonyProfileLayoutPreference.storage?.putSync('legacyLayout', previous);
        PinmonyProfileLayoutPreference.storage?.flushSync();
      } catch (_) {}
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=legacy-save-failed');
      return false;
    }
  }
  static savePinDensity(value: number): boolean {
    if (!Number.isInteger(value) || value < 0 || value > 2) return false;
    const previous: number = AppStorage.get<number>('pinmonyProfilePinDensity') ?? 1;
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('pinDensity', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('pinmonyProfilePinDensity', value);
      return true;
    } catch (_) {
      try {
        PinmonyProfileLayoutPreference.storage?.putSync('pinDensity', previous);
        PinmonyProfileLayoutPreference.storage?.flushSync();
      } catch (_) {}
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=pin-density-save-failed');
      return false;
    }
  }
  static saveBoardDensity(value: number): boolean {
    if (!Number.isInteger(value) || value < 0 || value > 2) return false;
    const previous: number = AppStorage.get<number>('pinmonyBoardDensity') ?? 1;
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('boardDensity', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('pinmonyBoardDensity', value);
      return true;
    } catch (_) {
      try {
        PinmonyProfileLayoutPreference.storage?.putSync('boardDensity', previous);
        PinmonyProfileLayoutPreference.storage?.flushSync();
      } catch (_) {}
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=board-density-save-failed');
      return false;
    }
  }
  static saveAvatarRight(value: boolean): boolean {
    const previous: boolean = AppStorage.get<boolean>('profileAvatarRight') === true;
    try {
      if (!PinmonyProfileLayoutPreference.storage) throw new Error('storage');
      PinmonyProfileLayoutPreference.storage.putSync('avatarRight', value);
      PinmonyProfileLayoutPreference.storage.flushSync();
      AppStorage.setOrCreate('profileAvatarRight', value);
      PinmonyRuntimeLog.info('ProfileLayoutTrace: event=saved avatarRight=' + value.toString());
      return true;
    } catch (_) {
      try {
        PinmonyProfileLayoutPreference.storage?.putSync('avatarRight', previous);
        PinmonyProfileLayoutPreference.storage?.flushSync();
      } catch (_) {}
      PinmonyRuntimeLog.warn('ProfileLayoutTrace: event=save-failed');
      return false;
    }
  }
}
