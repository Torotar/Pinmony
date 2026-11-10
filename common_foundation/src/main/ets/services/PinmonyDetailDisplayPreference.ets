import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

export class PinmonyDetailDisplayPreference {
  private static storage: preferences.Preferences | undefined = undefined;

  static initialize(context: common.Context): void {
    try {
      const storage: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'pinmony_detail_display' });
      const fallback: boolean = AppStorage.get<boolean>('detailPhotoFitEnabled') === true;
      const saved: preferences.ValueType = storage.getSync('photoFitEnabled', fallback);
      const enabled: boolean = typeof saved === 'boolean' ? saved : fallback;
      storage.putSync('photoFitEnabled', enabled);
      storage.flushSync();
      PinmonyDetailDisplayPreference.storage = storage;
      AppStorage.setOrCreate('detailPhotoFitEnabled', enabled);
    } catch (_) { PinmonyRuntimeLog.warn('DetailDisplayPreference: restore failed'); }
  }

  static savePhotoFit(enabled: boolean): boolean {
    const previous: boolean = AppStorage.get<boolean>('detailPhotoFitEnabled') === true;
    const storage: preferences.Preferences | undefined = PinmonyDetailDisplayPreference.storage;
    if (!storage) return false;
    try {
      storage.putSync('photoFitEnabled', enabled);
      storage.flushSync();
      AppStorage.setOrCreate('detailPhotoFitEnabled', enabled);
      return true;
    } catch (_) {
      try { storage.putSync('photoFitEnabled', previous); storage.flushSync(); } catch (_) {}
      PinmonyRuntimeLog.warn('DetailDisplayPreference: save failed');
      return false;
    }
  }
}
