import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

export class PinmonyImmersiveLightPreference {
  private static storage: preferences.Preferences | undefined = undefined;

  private static valid(mode: string): boolean {
    return mode === 'off' || mode === 'gentle' || mode === 'immersive' || mode === 'exquisite';
  }

  static initialize(context: common.Context): void {
    PinmonyImmersiveLightPreference.storage = undefined;
    try {
      const storage: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'pinmony_immersive_light' });
      const saved: preferences.ValueType = storage.getSync('mode', '');
      const legacy: string = AppStorage.get<string>('immersiveLightMode') ??
        (AppStorage.get<boolean>('immersiveLightEnabled') === false ? 'off' : 'immersive');
      const restored: boolean = typeof saved === 'string' && PinmonyImmersiveLightPreference.valid(saved);
      const mode: string = restored && typeof saved === 'string' ? saved :
        PinmonyImmersiveLightPreference.valid(legacy) ? legacy : 'immersive';
      if (!restored) {
        storage.putSync('mode', mode);
        storage.flushSync();
      }
      PinmonyImmersiveLightPreference.storage = storage;
      AppStorage.setOrCreate('immersiveLightMode', mode);
      PinmonyRuntimeLog.info('ImmersiveLightPreference: restored mode=' + mode + ' source=' + (restored ? 'preferences' : 'legacy'));
    } catch (_) {
      PinmonyRuntimeLog.warn('ImmersiveLightPreference: restore failed');
    }
  }

  static save(mode: string): boolean {
    const storage: preferences.Preferences | undefined = PinmonyImmersiveLightPreference.storage;
    if (!PinmonyImmersiveLightPreference.valid(mode) || !storage) return false;
    const previous: string = AppStorage.get<string>('immersiveLightMode') ?? 'immersive';
    try {
      storage.putSync('mode', mode);
      storage.flushSync();
    } catch (_) {
      try { storage.putSync('mode', previous); storage.flushSync(); } catch (_) {}
      PinmonyRuntimeLog.warn('ImmersiveLightPreference: save failed');
      return false;
    }
    AppStorage.setOrCreate('immersiveLightMode', mode);
    PinmonyRuntimeLog.info('ImmersiveLightPreference: saved mode=' + mode);
    return true;
  }
}
