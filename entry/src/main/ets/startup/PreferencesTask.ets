import { StartupTask, common } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { PinmonyI18n, PinmonyPublishAnchor } from 'common_foundation';
import { PinmonySessionHistory } from 'common_session';

@Sendable
export default class PreferencesTask extends StartupTask {
  async init(context: common.AbilityStageContext): Promise<string> {
    const startedAt: number = Date.now();
    try { PinmonyI18n.initialize(context); }
    catch (_) { PinmonyRuntimeLog.warn('LanguagePreference: restore failed'); PinmonyI18n.syncSystemLanguage(); }
    PinmonyRuntimeLog.info('LanguagePreference: restored=' + (AppStorage.get<string>('pinmonyLanguagePreference') || 'system') +
      ' effective=' + (AppStorage.get<string>('pinmonyLanguage') || 'unknown'));
    PersistentStorage.persistProp('themePreference', 'system');
    PinmonyPublishAnchor.initialize(context);
    PersistentStorage.persistProp('immersiveLightEnabled', true);
    PersistentStorage.persistProp('immersiveLightMode', AppStorage.get<boolean>('immersiveLightEnabled') === false ? 'off' : 'immersive');
    PersistentStorage.persistProp('screenOrientationPreference', 'system');
    PersistentStorage.persistProp('pinmonySessionOrigin', 'https://www.pinterest.com');
    PinmonySessionHistory.initialize(context);
    PinmonyRuntimeLog.info('NativeSession: history restored confirmed=' +
      (AppStorage.get<boolean>('pinmonySessionConfirmed') === true).toString());
    try {
      const preference: string = AppStorage.get<string>('themePreference') || 'system';
      context.getApplicationContext().setColorMode(preference === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : preference === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      PinmonyRuntimeLog.warn('StartupTask: color mode unavailable');
    }
    PersistentStorage.persistProp('bottomBarScrollCollapseEnabled', true);
    PersistentStorage.persistProp('pinwebHomeOfflineMarker', '');
    PinmonyRuntimeLog.info('StartupTask: PreferencesTask complete elapsedMs=' + (Date.now() - startedAt).toString());
    return 'PreferencesTask';
  }
  onDependencyCompleted(_name: string, _result: Object): void {}
}
