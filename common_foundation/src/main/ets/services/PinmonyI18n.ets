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
  private static traditionalChinese: resourceManager.ResourceManager | undefined = undefined;
  private static english: resourceManager.ResourceManager | undefined = undefined;
  private static englishUk: resourceManager.ResourceManager | undefined = undefined;
  private static japanese: resourceManager.ResourceManager | undefined = undefined;
  private static korean: resourceManager.ResourceManager | undefined = undefined;
  private static russian: resourceManager.ResourceManager | undefined = undefined;
  private static brazilianPortuguese: resourceManager.ResourceManager | undefined = undefined;
  private static resourceColorMode: number = -2;
  private static accountLanguage: string = '';
  static resolve(preference: string, systemLanguage: string): string {
    if (preference === 'zh' || preference === 'zh_TW' || preference === 'en' || preference === 'en_GB' || preference === 'ja' || preference === 'ko' || preference === 'ru' || preference === 'pt_BR') return preference;
    if (/^zh[-_]TW(?:[-_]|$)/i.test(systemLanguage)) return 'zh_TW';
    if (/^zh(?:[-_]|$)/i.test(systemLanguage)) return 'zh';
    if (/^ja(?:[-_]|$)/i.test(systemLanguage)) return 'ja';
    if (/^ko(?:[-_]|$)/i.test(systemLanguage)) return 'ko';
    if (/^ru(?:[-_]|$)/i.test(systemLanguage)) return 'ru';
    if (/^pt(?:[-_]|$)/i.test(systemLanguage)) return 'pt_BR';
    return /^en[-_]GB(?:[-_]|$)/i.test(systemLanguage) ? 'en_GB' : 'en';
  }

  static translationAcceptLanguage(language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    switch (language) {
      case 'zh_TW': return 'zh-TW,zh;q=0.9';
      case 'en': return 'en-US,en;q=0.9';
      case 'en_GB': return 'en-GB,en;q=0.9';
      case 'ja': return 'ja-JP,ja;q=0.9';
      case 'ko': return 'ko-KR,ko;q=0.9';
      case 'ru': return 'ru-RU,ru;q=0.9';
      case 'pt_BR': return 'pt-BR,pt;q=0.9';
      default: return 'zh-CN,zh;q=0.9';
    }
  }

  static initialize(context: common.Context): void {
    PinmonyI18n.resourceColorMode = -2;
    const chineseConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    chineseConfig.locale = 'zh-CN';
    const traditionalChineseConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    traditionalChineseConfig.locale = 'zh-TW';
    const englishConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    englishConfig.locale = 'en-US';
    const englishUkConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    englishUkConfig.locale = 'en-GB';
    const japaneseConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    japaneseConfig.locale = 'ja-JP';
    const koreanConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    koreanConfig.locale = 'ko-KR';
    const russianConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    russianConfig.locale = 'ru-RU';
    const brazilianPortugueseConfig: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
    brazilianPortugueseConfig.locale = 'pt-BR';
    PinmonyI18n.chinese = context.resourceManager.getOverrideResourceManager(chineseConfig);
    PinmonyI18n.traditionalChinese = context.resourceManager.getOverrideResourceManager(traditionalChineseConfig);
    PinmonyI18n.english = context.resourceManager.getOverrideResourceManager(englishConfig);
    PinmonyI18n.englishUk = context.resourceManager.getOverrideResourceManager(englishUkConfig);
    PinmonyI18n.japanese = context.resourceManager.getOverrideResourceManager(japaneseConfig);
    PinmonyI18n.korean = context.resourceManager.getOverrideResourceManager(koreanConfig);
    PinmonyI18n.russian = context.resourceManager.getOverrideResourceManager(russianConfig);
    PinmonyI18n.brazilianPortuguese = context.resourceManager.getOverrideResourceManager(brazilianPortugueseConfig);
    // Read disk before any component can create the AppStorage defaults.
    const previous: string = AppStorage.get<string>('pinmonyLanguagePreference') || 'account';
    let saved: preferences.ValueType;
    let account: preferences.ValueType;
    try {
      PinmonyI18n.storage = preferences.getPreferencesSync(context, { name: 'pinmony_local_display' });
      saved = PinmonyI18n.storage.getSync('language', previous);
      account = PinmonyI18n.storage.getSync('accountLanguage', '');
    } catch (_) { throw new Error('language-storage-read-unavailable'); }
    const value: string = typeof saved === 'string' && ['account', 'zh', 'zh_TW', 'en', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR'].includes(saved) ? saved : 'account';
    PinmonyI18n.accountLanguage = typeof account === 'string' && ['zh', 'zh_TW', 'en', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR'].includes(account) ? account : '';
    AppStorage.setOrCreate('pinmonyLanguagePreference', value);
    PinmonyI18n.syncSystemLanguage();
  }

  static syncSystemLanguage(): void {
    const preference: string = AppStorage.get<string>('pinmonyLanguagePreference') || 'account';
    const language: string = (preference === 'account' || preference === 'system') && PinmonyI18n.accountLanguage ?
      PinmonyI18n.accountLanguage : PinmonyI18n.resolve(preference, i18n.System.getSystemLanguage());
    AppStorage.setOrCreate('pinmonyLanguage', language);
  }

  // Locale overrides copy the full Configuration, including its color mode.
  // Keep those long-lived snapshots in sync when the application mode changes.
  static syncResourceColorMode(context: common.Context): void {
    try {
      const mode: number = context.resourceManager.getConfigurationSync().colorMode;
      if (mode !== resourceManager.ColorMode.DARK && mode !== resourceManager.ColorMode.LIGHT) return;
      if (mode === PinmonyI18n.resourceColorMode) return;
      const managers: (resourceManager.ResourceManager | undefined)[] = [PinmonyI18n.chinese,
        PinmonyI18n.traditionalChinese, PinmonyI18n.english, PinmonyI18n.englishUk,
        PinmonyI18n.japanese, PinmonyI18n.korean, PinmonyI18n.russian, PinmonyI18n.brazilianPortuguese];
      const locales: string[] = ['zh-CN', 'zh-TW', 'en-US', 'en-GB', 'ja-JP', 'ko-KR', 'ru-RU', 'pt-BR'];
      managers.forEach((manager: resourceManager.ResourceManager | undefined, index: number): void => {
        if (!manager) return;
        const configuration: resourceManager.Configuration = context.resourceManager.getConfigurationSync();
        configuration.locale = locales[index];
        manager.updateOverrideConfiguration(configuration);
      });
      PinmonyI18n.resourceColorMode = mode;
    } catch (_) { console.warn('LanguagePreference: resource configuration sync unavailable'); }
  }

  static select(preference: string): void {
    const value: string = preference === 'system' ? 'account' : preference;
    if (!['account', 'zh', 'zh_TW', 'en', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR'].includes(value)) return;
    if (!PinmonyI18n.storage) throw new Error('Language storage unavailable');
    let previous: preferences.ValueType = 'account';
    let hasPrevious: boolean = false;
    try {
      previous = PinmonyI18n.storage.getSync('language', 'account');
      hasPrevious = true;
      PinmonyI18n.storage.putSync('language', value);
      PinmonyI18n.storage.flushSync();
    } catch (_) {
      if (hasPrevious) try { PinmonyI18n.storage.putSync('language', previous); } catch (_) {}
      throw new Error('language-storage-write-unavailable');
    }
    AppStorage.setOrCreate('pinmonyLanguagePreference', value);
    PinmonyI18n.syncSystemLanguage();
  }

  // Account locale drives only the account-following preference, never manual choices.
  // Unknown account locales deliberately fall back to US English; an absent
  // locale is left untouched so a partial settings response cannot reset UI.
  static syncAccountLanguage(locale: string): void {
    if (!locale || locale.length > 16 || !/^[A-Za-z]{2,3}(?:[-_][A-Za-z]{2,4})?$/.test(locale)) return;
    const normalized: string = locale.replace('_', '-').toLowerCase();
    const preference: string = normalized === 'zh-cn' || normalized === 'zh' ? 'zh' :
      normalized === 'zh-tw' ? 'zh_TW' : normalized === 'en-gb' ? 'en_GB' :
      normalized === 'en-us' || normalized === 'en' ? 'en' : normalized === 'ja-jp' || normalized === 'ja' ? 'ja' :
      normalized === 'ko-kr' || normalized === 'ko' ? 'ko' : normalized === 'ru-ru' || normalized === 'ru' ? 'ru' :
      normalized === 'pt-br' || normalized === 'pt' ? 'pt_BR' : 'en';
    if (PinmonyI18n.accountLanguage !== preference) {
      PinmonyI18n.accountLanguage = preference;
      try {
        PinmonyI18n.storage?.putSync('accountLanguage', preference);
        PinmonyI18n.storage?.flushSync();
      } catch (_) { console.warn('LanguagePreference: account locale cache unavailable'); }
    }
    PinmonyI18n.syncSystemLanguage();
  }

  static clearAccountLanguage(): void {
    if (!PinmonyI18n.accountLanguage) return;
    PinmonyI18n.accountLanguage = '';
    try {
      PinmonyI18n.storage?.putSync('accountLanguage', '');
      PinmonyI18n.storage?.flushSync();
    } catch (_) { console.warn('LanguagePreference: account locale cache reset unavailable'); }
    PinmonyI18n.syncSystemLanguage();
  }

  static text(source: string, language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    if (source.includes('\uE000')) return PinmonyI18n.render(source, language);
    const key: string = PINMONY_LOCAL_COPY_KEYS[source] || source;
    const manager: resourceManager.ResourceManager | undefined = language === 'pt_BR' ? PinmonyI18n.brazilianPortuguese : language === 'ru' ? PinmonyI18n.russian : language === 'ko' ? PinmonyI18n.korean : language === 'ja' ? PinmonyI18n.japanese : language === 'zh_TW' ? PinmonyI18n.traditionalChinese : language === 'en_GB' ? PinmonyI18n.englishUk : language === 'en' ? PinmonyI18n.english : PinmonyI18n.chinese;
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
      'home-system-share': 'pm_share_7e564575',
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
