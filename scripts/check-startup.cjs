const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const profile = JSON.parse(fs.readFileSync('entry/src/main/resources/base/profile/startup_config.json', 'utf8'));
const state = new Map([['immersiveLightEnabled', false], ['themePreference', 'dark']]);
const events = [];
const logs = [];
const context = { filesDir: '/private', getApplicationContext: () => ({ setColorMode: mode => events.push('theme:' + mode) }) };
let languageFails = false;
const modules = {
  common_session: { PinmonySessionHistory: { initialize: () => state.set('pinmonySessionConfirmed', false) } },
  '@kit.AbilityKit': { StartupTask: class {}, ConfigurationConstant: { ColorMode: { COLOR_MODE_DARK: 0, COLOR_MODE_LIGHT: 1, COLOR_MODE_NOT_SET: -1 } } },
  common_foundation: {
    PinmonyRuntimeLog: { initialize: () => { events.push('log'); return new Promise(() => {}); }, info: x => logs.push(x), warn: x => logs.push(x) },
    PinmonyI18n: { initialize: () => { if (languageFails) throw Error(); events.push('language'); }, syncSystemLanguage: () => events.push('language-fallback') },
    PinmonyPublishAnchor: { initialize: () => events.push('anchor') }
  },
  '@kit.ArkWeb': { webview: { BackForwardCacheSupportedFeatures: class {}, WebviewController: {
    setWebDebuggingAccess: value => assert.equal(value, false),
    enableBackForwardCache: features => { assert.equal(features.nativeEmbed, false); assert.equal(features.mediaTakeOver, false); events.push('retention'); },
    initializeWebEngine: () => events.push('engine')
  } } }
};
function load(task) {
  const source = fs.readFileSync('entry/src/main/' + task.srcEntry, 'utf8').replace('@Sendable', '');
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText, {
    exports, require: name => { assert(name in modules); return modules[name]; },
    AppStorage: { get: key => state.get(key) },
    PersistentStorage: { persistProp: (key, value) => { if (!state.has(key)) state.set(key, value); } }
  });
  return new exports.default();
}
(async () => {
  const done = new Set();
  for (const task of profile.startupTasks) {
    assert.equal(task.runOnThread, 'mainThread', 'UI state stays on main thread');
    task.dependencies.forEach(name => assert(done.has(name), 'dependency must precede task'));
    await load(task).init(context);
    done.add(task.name);
  }
  assert.deepEqual(events, ['log', 'language', 'anchor', 'theme:0', 'retention', 'engine']);
  assert.equal(state.get('immersiveLightMode'), 'off', 'legacy disabled setting survives migration');
  assert.equal(state.get('themePreference'), 'dark', 'saved preference survives default registration');
  assert.equal(state.get('pinmonySessionConfirmed'), false);
  languageFails = true;
  await load(profile.startupTasks[1]).init(context);
  assert(events.includes('language-fallback'));
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert(!index.slice(index.indexOf('aboutToAppear()'), index.indexOf('aboutToDisappear()')).includes('PinmonyUpdateNotice.start'));
  assert(index.includes("this.authStatus === 'authenticated' && !snapshot.sourceError && !this.businessSuspended"));
  console.log('Startup: dependency order, nonblocking log restore, saved preferences, language fallback and Web engine setup passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
