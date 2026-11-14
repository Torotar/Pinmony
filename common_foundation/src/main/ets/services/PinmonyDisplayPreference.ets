import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

// AppStorage is the live UI state; this file is the durable source on restart.
export class PinmonyDisplayPreference {
  private static storage: preferences.Preferences | undefined = undefined;

  private static validTheme(value: string): boolean {
    return value === 'system' || value === 'light' || value === 'dark';
  }

  private static validOrientation(value: string): boolean {
    return value === 'system' || value === 'auto' || value === 'portrait' || value === 'landscape';
  }

  static initialize(context: common.Context): void {
    PinmonyDisplayPreference.storage = undefined;
    try {
      const storage: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'pinmony_display' });
      const theme: preferences.ValueType = storage.getSync('themePreference', AppStorage.get<string>('themePreference') ?? 'system');
      const orientation: preferences.ValueType = storage.getSync('screenOrientationPreference', AppStorage.get<string>('screenOrientationPreference') ?? 'system');
      const collapse: preferences.ValueType = storage.getSync('bottomBarScrollCollapseEnabled', AppStorage.get<boolean>('bottomBarScrollCollapseEnabled') ?? true);
      const restoredTheme: string = typeof theme === 'string' && PinmonyDisplayPreference.validTheme(theme) ? theme : 'system';
      const restoredOrientation: string = typeof orientation === 'string' && PinmonyDisplayPreference.validOrientation(orientation) ? orientation : 'system';
      const restoredCollapse: boolean = typeof collapse === 'boolean' ? collapse : true;
      storage.putSync('themePreference', restoredTheme);
      storage.putSync('screenOrientationPreference', restoredOrientation);
      storage.putSync('bottomBarScrollCollapseEnabled', restoredCollapse);
      storage.flushSync();
      PinmonyDisplayPreference.storage = storage;
      AppStorage.setOrCreate('themePreference', restoredTheme);
      AppStorage.setOrCreate('screenOrientationPreference', restoredOrientation);
      AppStorage.setOrCreate('bottomBarScrollCollapseEnabled', restoredCollapse);
      PinmonyRuntimeLog.info('DisplayPreference: restored theme=' + restoredTheme + ' orientation=' + restoredOrientation + ' collapse=' + restoredCollapse.toString());
    } catch (_) { PinmonyRuntimeLog.warn('DisplayPreference: restore failed'); }
  }

  private static save(key: string, value: string | boolean, fallback: string | boolean): boolean {
    const storage: preferences.Preferences | undefined = PinmonyDisplayPreference.storage;
    if (!storage) return false;
    const previous: string | boolean = AppStorage.get<string | boolean>(key) ?? fallback;
    try {
      storage.putSync(key, value);
      storage.flushSync();
    } catch (_) {
      try { storage.putSync(key, previous); storage.flushSync(); } catch (_) {}
      PinmonyRuntimeLog.warn('DisplayPreference: save failed key=' + key);
      return false;
    }
    AppStorage.setOrCreate(key, value);
    PinmonyRuntimeLog.info('DisplayPreference: saved key=' + key + ' value=' + value.toString());
    return true;
  }

  static saveTheme(value: string): boolean {
    return PinmonyDisplayPreference.validTheme(value) && PinmonyDisplayPreference.save('themePreference', value, 'system');
  }

  static saveOrientation(value: string): boolean {
    return PinmonyDisplayPreference.validOrientation(value) && PinmonyDisplayPreference.save('screenOrientationPreference', value, 'system');
  }

  static saveCollapse(value: boolean): boolean {
    return PinmonyDisplayPreference.save('bottomBarScrollCollapseEnabled', value, true);
  }

  static applyTheme(context: common.Context, value: string): void {
    try {
      context.getApplicationContext().setColorMode(value === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        value === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_) {
      PinmonyRuntimeLog.warn('DisplayPreference: apply theme failed');
      throw new Error('theme configuration');
    }
    if (value !== 'system') AppStorage.setOrCreate('systemDarkMode', value === 'dark');
  }
}
