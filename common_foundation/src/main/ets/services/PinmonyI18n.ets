import { i18n } from '@kit.LocalizationKit';
import { PINMONY_LOCAL_COPY_KEYS } from './PinmonyLocalCopyKeys';
import { resourceManager } from '@kit.LocalizationKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

// Only call text/format at the declaration of Pinmony-owned copy. Website
// responses and user content must never pass through this catalog.
export class PinmonyI18n {
  private static storage: preferences.Preferences | undefined = undefined;
  private static chinese: resourceManager.ResourceManager | undefined = undefined;
  private static english: resourceManager.ResourceManager | undefined = undefined;
  static resolve(preference: string, systemLanguage: string): string {
    if (preference === 'zh' || preference === 'en') return preference;
    return /^zh(?:[-_]|$)/i.test(systemLanguage) ? 'zh' : 'en';
  }

  static initialize(context: common.Context): void {
    const chineseConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    chineseConfig.locale = 'zh-CN';
    const englishConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    englishConfig.locale = 'en-US';
    PinmonyI18n.chinese = context.resourceManager.getOverrideResourceManager(chineseConfig);
    PinmonyI18n.english = context.resourceManager.getOverrideResourceManager(englishConfig);
    // Read disk before any component can create the AppStorage defaults.
    const previous: string = AppStorage.get<string>('pinmonyLanguagePreference') || 'system';
    let saved: preferences.ValueType;
    try {
      PinmonyI18n.storage = preferences.getPreferencesSync(context, { name: 'pinmony_local_display' });
      saved = PinmonyI18n.storage.getSync('language', previous);
    } catch (_) { throw new Error('language-storage-read-unavailable'); }
    const value: string = typeof saved === 'string' && ['system', 'zh', 'en'].includes(saved) ? saved : 'system';
    AppStorage.setOrCreate('pinmonyLanguagePreference', value);
    PinmonyI18n.syncSystemLanguage();
  }

  static syncSystemLanguage(): void {
    const preference: string = AppStorage.get<string>('pinmonyLanguagePreference') || 'system';
    const language: string = PinmonyI18n.resolve(preference, i18n.System.getSystemLanguage());
    AppStorage.setOrCreate('pinmonyLanguage', language);
  }

  static select(preference: string): void {
    if (!['system', 'zh', 'en'].includes(preference)) return;
    if (!PinmonyI18n.storage) throw new Error('Language storage unavailable');
    try {
      PinmonyI18n.storage.putSync('language', preference);
      PinmonyI18n.storage.flushSync();
    } catch (_) { throw new Error('language-storage-write-unavailable'); }
    AppStorage.setOrCreate('pinmonyLanguagePreference', preference);
    PinmonyI18n.syncSystemLanguage();
  }

  static text(source: string, language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    if (source.includes('\uE000')) return PinmonyI18n.render(source, language);
    const key: string = PINMONY_LOCAL_COPY_KEYS[source] || source;
    const manager: resourceManager.ResourceManager | undefined = language === 'en' ? PinmonyI18n.english : PinmonyI18n.chinese;
    if (!manager || !key.startsWith('pm_')) return source;
    try { return manager.getStringByNameSync(key); }
    catch (_) {
      console.warn('LanguagePreference: resource lookup unavailable');
      return source;
    }
  }

  // Stable local message tokens: never translate an unmarked website response.
  static message(source: string): string { return '\uE000' + (PINMONY_LOCAL_COPY_KEYS[source] || source) + '\uE001'; }

  static render(value: string, language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    return value.replace(/\uE000([^\uE000\uE001]*)\uE001/g, (_match: string, source: string): string =>
      PinmonyI18n.text(source, language));
  }

  static optionLabel(id: string, original: string, language: string): string {
    const labels: Record<string, string> = {
      'home-system-share': 'pm_system_share_13a1c63f',
      'home-save': "pm_save_60a53514", 'home-edit': "pm_edit_pin_f9119bcf", 'home-download': "pm_download_image_8894375c",
      'home-see-more': "pm_see_more_92b2b2de", 'home-see-less': "pm_see_less_9c80a8dc", 'home-share': "pm_share_7e564575",
      'board-menu-move': "pm_move_to_another_board_62574b0d", 'board-menu-cancel-save': "pm_unsave_dca60869",
      'board-menu-download': "pm_download_4673a230", 'board-menu-share': "pm_share_link_10ba6479", 'board-menu-more': "pm_see_more_92b2b2de",
      'detail-edit': "pm_edit_pin_f9119bcf", 'detail-download': "pm_download_image_8894375c", 'detail-see-more': "pm_see_more_92b2b2de",
      'detail-see-less': "pm_see_fewer_like_this_7904e8ad", 'detail-share': "pm_system_share_13a1c63f", 'detail-ai-help': "pm_learn_about_ai_labels_0794696e"
    };
    return labels[id] ? PinmonyI18n.text(labels[id], language) : original;
  }

  static format(source: string, values: (string | number)[], language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    const template: string = PinmonyI18n.text(source, language);
    // Replace in one pass so user text containing "{0}" remains literal.
    return template.replace(/\{(\d+)\}/g, (match: string, index: string): string => {
      const position: number = Number(index);
      return position < values.length ? values[position].toString() : match;
    });
  }

  static isText(value: string, source: string): boolean {
    value = PinmonyI18n.render(value, 'zh');
    return value === PinmonyI18n.text(source, 'zh') || value === PinmonyI18n.text(source, 'en');
  }

  static includesText(value: string, source: string): boolean {
    value = PinmonyI18n.render(value, 'zh');
    return value.includes(PinmonyI18n.text(source, 'zh')) || value.includes(PinmonyI18n.text(source, 'en'));
  }

  static isUnconfirmed(value: string): boolean {
    value = PinmonyI18n.render(value, 'zh');
    return value.includes('未确认') || value.includes('待确认') || /not confirmed|unconfirmed/i.test(value);
  }
}
