const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function load(file, dependencies) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: name => dependencies[name] || {} });
  return exports;
}
const configFile = 'entry/src/main/ets/app/PinmonyTranslationDiagnosticConfig.ets';
assert.equal(load(configFile, { BuildProfile: { default: { DEBUG: false } } }).PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED, false);
assert.equal(load(configFile, { BuildProfile: { default: { DEBUG: true } } }).PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED, false,
  'normal debug package also disables the temporary host and remote debugging');
for (const enabled of [false, true]) {
  const { PinmonyTranslationDiagnostics: diagnostic } = load('entry/src/main/ets/app/PinmonyTranslationDiagnostics.ets', {
    './PinmonyTranslationDiagnosticConfig': { PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED: enabled }
  });
  const writes = [];
  let url = 'about:blank';
  const controller = { getUrl: () => url, runJavaScript: script => { writes.push(script); return Promise.resolve(''); } };
  diagnostic.attach(controller);
  const first = diagnostic.begin('https://www.pinterest.com/pin/123/', '456', 'zh-CN,zh;q=0.9');
  if (!enabled) { assert.equal(first, 0); assert.equal(writes.length, 0); continue; }
  assert(first > 0);
  assert.equal(diagnostic.begin('https://evil.test/pin/123/', '456', 'en'), 0);
  assert.equal(diagnostic.begin('https://www.pinterest.com/pin/123/', '4x', 'en'), 0);
  const sample = () => { const script = writes.at(-1); return JSON.parse(script.slice(script.indexOf('=') + 1, -1)); };
  assert.deepEqual(Object.keys(sample()).sort(), ['commentId','language','nativeShape','page','task']);
  diagnostic.finish(first, 'null'); assert.equal(sample().nativeShape, 'null');
  const second = diagnostic.begin('https://www.pinterest.com/pin/124/', '457', 'en-US');
  diagnostic.finish(first, 'string'); assert.equal(sample().task, second); assert.equal(sample().nativeShape, 'pending');
  diagnostic.detach({}); diagnostic.finish(second, 'string'); assert.equal(sample().nativeShape, 'string');
  url = 'https://www.pinterest.com.evil.test/';
  const count = writes.length; diagnostic.publish(); assert.equal(writes.length, count);
  assert.equal(diagnostic.allowsPage('http://www.pinterest.com/'), false);
  diagnostic.detach(controller); diagnostic.finish(second, 'null'); assert.equal(writes.length, count);
  diagnostic.attach(controller); url = 'about:blank'; diagnostic.publish(); assert.equal(sample(), null);
  const third = diagnostic.begin('https://www.pinterest.com/pin/125/', '458', 'en');
  diagnostic.finish(second, 'null'); assert.equal(sample().task, third); assert.equal(sample().nativeShape, 'pending');
  assert.equal(diagnostic.begin('https://www.pinterest.com/pin/125/', '458', 'x'.repeat(65)), 0);
}
const host = fs.readFileSync('entry/src/main/ets/components/PinmonyTranslationDiagnosticHost.ets', 'utf8');
assert(host.includes("src: 'about:blank'"));
assert(host.includes('.opacity(0)') && host.includes('HitTestMode.None') && host.includes("'no-hide-descendants'"));
assert(!host.includes('.javaScriptProxy(') && !host.includes('fetch('));
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(index.includes("PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED && this.authStatus === 'authenticated'"));
for (const enabled of [false, true]) {
  const settings = [];
  const exports = {};
  const source = fs.readFileSync('entry/src/main/ets/startup/WebEngineTask.ets', 'utf8')
    .replace('@Sendable', '').replace(/import lazy \{/g, 'import {');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  } }).outputText, { exports, require: name => ({
    '@kit.AbilityKit': { StartupTask: class {} },
    common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } },
    '../app/PinmonyTranslationDiagnosticConfig': { PINMONY_TRANSLATION_DIAGNOSTIC_ENABLED: enabled },
    '@kit.ArkWeb': { webview: { BackForwardCacheSupportedFeatures: class {}, WebviewController: {
      setWebDebuggingAccess: value => settings.push(value), enableBackForwardCache() {}, initializeWebEngine() {}
    } } }
  })[name] });
  new exports.default().init({});
  assert.deepEqual(settings, enabled ? [false, true] : [false]);
}
console.log('Translation diagnostics: disabled/release gate, passive context, validation, late result, detach, new session, external-page isolation, hidden host passed');
