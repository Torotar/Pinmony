import { i18n } from '@kit.LocalizationKit';
import { PINMONY_ENGLISH } from './PinmonyI18nCatalog';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

// Only call text/format at the declaration of Pinmony-owned copy. Website
// responses and user content must never pass through this catalog.
export class PinmonyI18n {
  private static storage: preferences.Preferences | undefined = undefined;
  static resolve(preference: string, systemLanguage: string): string {
    if (preference === 'zh' || preference === 'en') return preference;
    return /^zh(?:[-_]|$)/i.test(systemLanguage) ? 'zh' : 'en';
  }

  static initialize(context: common.Context): void {
    PinmonyI18n.storage = preferences.getPreferencesSync(context, { name: 'pinmony_local_display' });
    // Read disk before any component can create the AppStorage defaults.
    const previous: string = AppStorage.get<string>('pinmonyLanguagePreference') || 'system';
    const saved: preferences.ValueType = PinmonyI18n.storage.getSync('language', previous);
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
    PinmonyI18n.storage.putSync('language', preference);
    PinmonyI18n.storage.flushSync();
    AppStorage.setOrCreate('pinmonyLanguagePreference', preference);
    PinmonyI18n.syncSystemLanguage();
  }

  static text(source: string, language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    if (source.includes('\uE000')) return PinmonyI18n.render(source, language);
    return language === 'en' ? PINMONY_ENGLISH[source] || source : source;
  }

  // Stable local message tokens: never translate an unmarked website response.
  static message(source: string): string { return '\uE000' + source + '\uE001'; }

  static render(value: string, language: string = AppStorage.get<string>('pinmonyLanguage') || 'zh'): string {
    return value.replace(/\uE000([^\uE000\uE001]*)\uE001/g, (_match: string, source: string): string =>
      language === 'en' ? PINMONY_ENGLISH[source] || source : source);
  }

  static optionLabel(id: string, original: string, language: string): string {
    const labels: Record<string, string> = {
      'home-save': '收藏', 'home-edit': '编辑 Pin 图', 'home-download': '下载图片',
      'home-see-more': '查看更多', 'home-see-less': '查看更少', 'home-share': '分享',
      'board-menu-move': '移至其他图板', 'board-menu-cancel-save': '取消收藏',
      'board-menu-download': '下载', 'board-menu-share': '分享链接', 'board-menu-more': '查看更多',
      'detail-edit': '编辑 Pin 图', 'detail-download': '下载图片', 'detail-see-more': '查看更多',
      'detail-see-less': '减少推荐', 'detail-share': '系统分享', 'detail-ai-help': '详细了解 AI 标签'
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
    return value === source || value === PINMONY_ENGLISH[source];
  }

  static includesText(value: string, source: string): boolean {
    value = PinmonyI18n.render(value, 'zh');
    return value.includes(source) || !!PINMONY_ENGLISH[source] && value.includes(PINMONY_ENGLISH[source]);
  }

  static isUnconfirmed(value: string): boolean {
    return value.includes('未确认') || value.includes('待确认') || /not confirmed|unconfirmed/i.test(value);
  }
}
