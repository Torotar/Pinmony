import { StartupTask, common } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { PinmonyI18n, PinmonyPublishAnchor, PinmonyProfileLayoutPreference, PinmonyDetailDisplayPreference } from 'common_foundation';
import { PinmonySessionHistory } from 'common_session';
import { preferences } from '@kit.ArkData';
import lazy { PinmonyInboxHiddenConversations } from 'feature_inbox';

PinmonyRuntimeLog.info('StartupBoundary: preferences-module-evaluated');

@Sendable
export default class PreferencesTask extends StartupTask {
  async init(context: common.AbilityStageContext): Promise<string> {
    const startedAt: number = Date.now();
    PinmonyRuntimeLog.info('StartupBoundary: preferences-init-enter');
    // Apply the persisted theme before creating locale resource managers.
    PersistentStorage.persistProp('themePreference', 'system');
    try {
      const preference: string = AppStorage.get<string>('themePreference') || 'system';
      context.getApplicationContext().setColorMode(preference === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : preference === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_) {
      PinmonyRuntimeLog.warn('StartupTask: color mode unavailable');
    }
    try { PinmonyI18n.initialize(context); }
    catch (_) { PinmonyRuntimeLog.warn('LanguagePreference: restore failed'); PinmonyI18n.syncSystemLanguage(); }
    PinmonyRuntimeLog.info('LanguagePreference: restored=' + (AppStorage.get<string>('pinmonyLanguagePreference') || 'system') +
      ' effective=' + (AppStorage.get<string>('pinmonyLanguage') || 'unknown'));
    PersistentStorage.persistProp('profileLegacyLayout', false);
    PinmonyProfileLayoutPreference.initialize(context);
    const inboxStartedAt: number = Date.now();
    try {
      const inboxStorage: preferences.Preferences = preferences.getPreferencesSync(context, {name:'pinmony_hidden_chats'});
      const hiddenChats: preferences.ValueType = inboxStorage.getSync('conversations','[]');
      PinmonyInboxHiddenConversations.initialize(typeof hiddenChats === 'string' ? hiddenChats : '[]', (value: string): boolean => {
        const previous: preferences.ValueType = inboxStorage.getSync('conversations','[]');
        try { inboxStorage.putSync('conversations',value);inboxStorage.flushSync();return true; }
        catch (_) { try {inboxStorage.putSync('conversations',previous);} catch (_) {} return false; }
      });
    } catch (_) { PinmonyRuntimeLog.warn('InboxLocalList: storage unavailable'); }
    PinmonyRuntimeLog.info('StartupTask: preferences-inbox elapsedMs=' + (Date.now() - inboxStartedAt).toString());
    PinmonyPublishAnchor.initialize(context);
    PersistentStorage.persistProp('immersiveLightEnabled', true);
    PersistentStorage.persistProp('immersiveLightMode', AppStorage.get<boolean>('immersiveLightEnabled') === false ? 'off' : 'immersive');
    PersistentStorage.persistProp('screenOrientationPreference', 'system');
    PersistentStorage.persistProp('detailPhotoFitEnabled', false);
    PinmonyDetailDisplayPreference.initialize(context);
    PersistentStorage.persistProp('pinmonySessionOrigin', 'https://www.pinterest.com');
    PinmonySessionHistory.initialize(context);
    PinmonyRuntimeLog.info('StartupTask: preferences-restored elapsedMs=' + (Date.now() - startedAt).toString());
    PinmonyRuntimeLog.info('NativeSession: history restored confirmed=' +
      (AppStorage.get<boolean>('pinmonySessionConfirmed') === true).toString());
    PersistentStorage.persistProp('bottomBarScrollCollapseEnabled', true);
    PersistentStorage.persistProp('pinwebHomeOfflineMarker', '');
    PinmonyRuntimeLog.info('StartupTask: PreferencesTask complete elapsedMs=' + (Date.now() - startedAt).toString());
    return 'PreferencesTask';
  }
  onDependencyCompleted(_name: string, _result: Object): void {}
}
