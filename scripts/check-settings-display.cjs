const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function method(source, name, endName) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0);
  const end = source.indexOf(endName, start + 1);
  assert(end > start);
  return source.slice(start, end);
}
const ability = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
const component = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyPreferencesPage.ets', 'utf8');
const selected = [];
let preference = 'system', resourceMode = 1;
const context = { ConfigurationConstant: { ColorMode: { COLOR_MODE_LIGHT: 1, COLOR_MODE_DARK: 0, COLOR_MODE_NOT_SET: -1 } },
  AppStorage: { get: () => preference, setOrCreate() {} }, hilog: { error() {} }, DOMAIN: 0 };
vm.runInNewContext(ts.transpileModule('class Theme {' + method(ability, 'syncSystemColorMode', '  onForeground(') +
  method(component, 'selectTheme', '  private options(') + '} globalThis.Theme = Theme;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const native = new context.Theme();
native.context = { resourceManager: { getConfigurationSync: () => ({ colorMode: resourceMode }) } };
native.mainWindow = { setWindowSystemBarProperties: properties => selected.push(properties) };
preference = 'system'; native.syncSystemColorMode(0); assert.equal(selected.at(-1).statusBarContentColor, '#F7F8FA');
native.syncSystemColorMode(1); assert.equal(selected.at(-1).navigationBarContentColor, '#1B1E25');
preference = 'dark'; native.syncSystemColorMode(1); assert.equal(selected.at(-1).statusBarContentColor, '#F7F8FA');
preference = 'light'; native.syncSystemColorMode(0); assert.equal(selected.at(-1).statusBarContentColor, '#1B1E25');
const changes = [], errors = [];
native.themePreference = 'system';
native.getUIContext = () => ({ getHostContext: () => ({ getApplicationContext: () => ({ setColorMode: mode => changes.push(mode) }) }), getPromptAction: () => ({ showToast: value => errors.push(value) }) });
native.selectTheme('dark'); assert.equal(native.themePreference, 'dark'); assert.equal(changes.at(-1), 0);
native.selectTheme('system'); assert.equal(changes.at(-1), -1);
native.getUIContext = () => ({ getHostContext: () => ({ getApplicationContext: () => ({ setColorMode() { throw Error('synthetic'); } }) }), getPromptAction: () => ({ showToast: value => errors.push(value) }) });
native.selectTheme('light'); assert.equal(native.themePreference, 'system'); assert.equal(errors.length, 1);
const storeSource = fs.readFileSync('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets', 'utf8').replace(/^@Observed\s*$/m, '');
const storeExports = {};
vm.runInNewContext(ts.transpileModule(storeSource, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { exports: storeExports });
const store = new storeExports.PinmonySettingsStore(); store.screen = 'visibility'; store.confirmOpen = true;
assert(store.back()); assert.equal(store.screen, 'visibility'); assert.equal(store.confirmOpen, false);
store.confirmOpen = true; store.busy = true; store.back(); assert.equal(store.confirmOpen, true);
store.busy = false; store.confirmOpen = false; store.back(); assert.equal(store.screen, 'root');
store.screen = 'theme'; store.themeReturn = 'account'; store.back(); assert.equal(store.screen, 'account');
console.log('Local theme: explicit/system color modes, system-bar contrast, failed switch restoration and confirmation return order passed');
