const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const disk = new Map();
let failFlush = false, failRead = false;
function boot(system = 'zh-CN') {
  const memory = new Map(), cache = new Map(disk);
  const storage = { getSync: (key, fallback) => { if (failRead) throw Error('read'); return cache.has(key) ? cache.get(key) : fallback; },
    putSync: (key, value) => cache.set(key, value),
    flushSync() { if (failFlush) throw Error('flush'); for (const [key, value] of cache) disk.set(key, value); } };
  const loader = createArktsLoader(ts, {
    '@kit.LocalizationKit': { i18n: { System: { getSystemLanguage: () => system } } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => storage } }, '@kit.AbilityKit': {}
  }, { AppStorage: { get: key => memory.get(key), setOrCreate: (key, value) => memory.set(key, value) }, console });
  const api = loader.loadFile('common_foundation/src/main/ets/services/PinmonyI18n.ets').PinmonyI18n;
  api.initialize({ resourceManager: { getConfigurationSync: () => ({}), getOverrideResourceManager: () => ({ getStringByNameSync: key => key }) } });
  return { api, memory, system(value) { system = value; } };
}
let f = boot();
assert.equal(f.memory.get('pinmonyLanguagePreference'), 'account', 'Fresh installations default to following the account');
assert.equal(f.memory.get('pinmonyLanguage'), 'zh', 'Before verified account data, use system language provisionally');
f.api.syncAccountLanguage('ja-JP');
assert.equal(f.memory.get('pinmonyLanguagePreference'), 'account', 'Account sync must never convert the mode to a manual language');
assert.equal(f.memory.get('pinmonyLanguage'), 'ja'); assert.equal(disk.get('accountLanguage'), 'ja');
f.system('en-GB'); f.api.syncSystemLanguage(); assert.equal(f.memory.get('pinmonyLanguage'), 'ja');
f = boot('en-US'); assert.equal(f.memory.get('pinmonyLanguage'), 'ja', 'Retain the last verified account language across offline restart');
for (const [locale, language] of Object.entries({ 'zh-CN': 'zh', zh_TW: 'zh_TW', en_US: 'en', 'en-GB': 'en_GB', 'ja-JP': 'ja', 'ko-KR': 'ko', 'ru-RU': 'ru', pt_BR: 'pt_BR' })) {
  f.api.syncAccountLanguage(locale); assert.equal(f.memory.get('pinmonyLanguage'), language);
  assert.equal(f.memory.get('pinmonyLanguagePreference'), 'account');
}
for (const language of ['zh', 'zh_TW', 'en', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
  f.api.select(language); f.api.syncAccountLanguage('ja-JP');
  assert.equal(f.memory.get('pinmonyLanguage'), language, 'Server updates preserve explicit manual selection');
  f = boot('zh-CN'); assert.equal(f.memory.get('pinmonyLanguagePreference'), language);
  assert.equal(f.memory.get('pinmonyLanguage'), language);
}
f.api.select('account'); assert.equal(f.memory.get('pinmonyLanguage'), 'ja', 'Switching back uses the latest account language immediately');
assert.equal(disk.get('language'), 'account');
f.api.syncAccountLanguage(''); f.api.syncAccountLanguage('<bad>'); f.api.syncAccountLanguage('x'.repeat(17));
assert.equal(f.memory.get('pinmonyLanguage'), 'ja', 'Missing or malformed fields cannot reset retained UI');
f.api.syncAccountLanguage('fr-FR'); assert.equal(f.memory.get('pinmonyLanguage'), 'en', 'Unsupported locales retain the established English fallback');
f.api.clearAccountLanguage(); assert.equal(f.memory.get('pinmonyLanguage'), 'zh');
assert.equal(disk.get('accountLanguage'), '', 'Account/session cleanup clears persisted account locale');
f = boot('ko-KR'); assert.equal(f.memory.get('pinmonyLanguage'), 'ko');
f.api.syncAccountLanguage('ru-RU'); f.api.select('en_GB'); f.api.clearAccountLanguage();
assert.equal(f.memory.get('pinmonyLanguage'), 'en_GB', 'Logout preserves the explicit manual language');
disk.set('language', 'system'); disk.set('accountLanguage', 'pt_BR');
f = boot('zh-CN'); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'account');
assert.equal(f.memory.get('pinmonyLanguage'), 'pt_BR', 'Legacy system mode migrates to account behavior');
f.api.select('account'); failFlush = true;
assert.throws(() => f.api.select('en'), /language-storage-write-unavailable/);
assert.equal(f.memory.get('pinmonyLanguagePreference'), 'account');
failFlush = false; f.api.syncAccountLanguage('ko-KR');
assert.equal(disk.get('language'), 'account', 'A later cache flush cannot persist a failed manual selection');
f = boot(); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'account'); assert.equal(f.memory.get('pinmonyLanguage'), 'ko');
failFlush = true; f.api.syncAccountLanguage('ja-JP');
assert.equal(f.memory.get('pinmonyLanguage'), 'ja', 'A verified account locale can update UI even if cache persistence fails');
failFlush = false;
f.api.select('en'); failRead = true;
assert.throws(() => f.api.select('zh'), /language-storage-write-unavailable/);
failRead = false; f.api.syncAccountLanguage('ru-RU');
f = boot(); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'en', 'Failed preference reads cannot stage an unrelated fallback value');
const page = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets', 'utf8');
const start = page.indexOf('Text(this.uiText("pm_language_9f6fee1a"))'), end = page.indexOf('}, (language: string): string => language)', start);
const selector = page.slice(start, end);
assert(selector.includes('pm_follow_account')); assert(!selector.includes('pm_follow_system_217cfe7d'));
assert.equal((selector.match(/\['account', 'zh'/g) || []).length, 2, 'Display index and selection action agree');
assert(page.includes("private languagePreference: string = 'account'"));
assert(page.includes('Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: this.uiText("pm_light_aa0819df") }'), 'Theme keeps its system label');
for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
  const rows = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
  assert(rows.find(row => row.name === 'pm_follow_account')?.value);
  assert(rows.find(row => row.name === 'pm_follow_system_217cfe7d')?.value);
}
const coordinator = fs.readFileSync('entry/src/main/ets/app/PinmonySessionCoordinator.ets', 'utf8');
assert(coordinator.includes("if (message.status === 'unauthenticated') {\n            PinmonyI18n.clearAccountLanguage();"));
assert(coordinator.includes('if (accountChanged) {\n            PinmonyI18n.clearAccountLanguage();'));
assert(coordinator.includes('resetAuthenticatedContent(): void {\n    PinmonyI18n.clearAccountLanguage();'));
const native = fs.readFileSync('entry/src/main/ets/app/PinmonySettingsNativeFlow.ets', 'utf8');
assert(native.includes('if (this.value.ready && !this.value.error) PinmonyI18n.syncAccountLanguage(this.value.accountLanguage)'));
assert(native.indexOf('if (!this.current(revision) || !this.value)') < native.indexOf('PinmonyI18n.syncAccountLanguage(this.value.accountLanguage)'));
const nativeAst = ts.createSourceFile('settings.ts', native, ts.ScriptTarget.Latest, true), nativeMethods = new Map();
function findNative(node) {
  if (ts.isMethodDeclaration(node) && node.name) nativeMethods.set(node.name.getText(nativeAst), node.getText(nativeAst));
  ts.forEachChild(node, findNative);
}
findNative(nativeAst);
const Native = vm.runInNewContext(ts.transpileModule('class Native {' + ['map', 'date', 'commit'].map(name => nativeMethods.get(name)).join('\n') + '} Native;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { PinmonyI18n: f.api });
const n = new Native();
Object.assign(n, { client: { viewer: '123' }, origin: 'https://www.pinterest.com', page: 'https://www.pinterest.com/fixture_user/', uncertain: new Map(), store: {}, current: () => true });
f.api.select('account');
for (const [locale, language] of Object.entries({ 'zh-TW': 'zh_TW', 'en-GB': 'en_GB', 'ru-RU': 'ru', pt_BR: 'pt_BR' })) {
  n.value = {}; n.map({ id: '123', username: 'fixture_user', locale }); n.commit(1);
  assert.equal(f.memory.get('pinmonyLanguage'), language, 'Native settings read feeds the actual account-following service');
}
n.current = () => false; n.value = {}; n.map({ id: '123', username: 'fixture_user', locale: 'ja-JP' }); n.commit(1);
assert.equal(f.memory.get('pinmonyLanguage'), 'pt_BR', 'Stale native responses cannot change current account language');
n.current = () => true; n.value.error = 'failed'; n.commit(1);
assert.equal(f.memory.get('pinmonyLanguage'), 'pt_BR', 'Failed settings cannot commit language');
assert.throws(() => n.map({ id: '456', username: 'other', locale: 'ja-JP' }), /identity/);
f.api.select('en'); n.value = {}; n.map({ id: '123', username: 'fixture_user', locale: 'ja-JP' }); n.commit(1);
assert.equal(f.memory.get('pinmonyLanguage'), 'en', 'Native settings updates preserve manual language');
console.log('Account language passed: fresh default, migration, all supported locales, manual override, live mode switching, restart/cache, session cleanup, persistence failures and isolated selector labels.');
