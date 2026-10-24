const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(path) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports });
  return exports;
}
const { PinmonySessionEnvironment } = load('common_session/src/main/ets/services/PinmonySessionEnvironment.ets');
const { PinmonyBusinessSession } = load('common_session/src/main/ets/services/PinmonyBusinessSession.ets');
const environment = new PinmonySessionEnvironment();
assert.equal(environment.userAgent(), ''); assert.equal(environment.capture('fixture-agent'), true);
for (const agent of ['', 'x'.repeat(4097), 'bad\r\nagent']) assert.equal(environment.capture(agent), false);
assert.equal(environment.userAgent(), 'fixture-agent', 'bad captures cannot discard valid runtime metadata');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const host = fs.readFileSync('entry/src/main/ets/components/PinmonyLoginPage.ets', 'utf8');
assert(!index.includes('Web({'), 'Web layout belongs to the login host');
for (const expected of ['.opacity(view.visible ? 1 : 0)', '.accessibilityLevel(view.visible', '.hitTestBehavior(view.visible',
  '.javaScriptProxy(', '.runJavaScriptOnDocumentStart(view.scripts)', '.onErrorReceive(', '.onOverrideUrlLoading(', '.onLoadIntercept('])
  assert(host.includes(expected), expected);
const calls = [];
const view = { captureEnvironment: () => calls.push('metadata'), lifecycle: { controllerAttached: () => calls.push('attach'),
  pageBegin: url => calls.push(url), pageEnd: () => calls.push('end') } };
for (const event of ['onControllerAttached', 'onPageBegin', 'onPageEnd']) {
  const callback = host.match(new RegExp('\\.' + event + '\\(([^\\n]+)\\)'))[1];
  const fn = vm.runInNewContext('(' + callback + ')', { view }); fn({ url: 'fixture-page' });
}
assert.deepEqual(calls, ['metadata', 'attach', 'metadata', 'fixture-page', 'metadata', 'end']);
const confirm = index.match(/  private confirmBusinessSession\([\s\S]*?(?=\n  private nativeBusinessSessionContext)/)[0];
assert(!confirm.includes('this.controller'), 'business session confirmation no longer calls the Web controller');
const native = { authStatus: 'authenticated', sessionEnvironment: environment, businessSession: new PinmonyBusinessSession(),
  homeCacheAccountId: 'synthetic-account', authenticatedProfileUrl: 'https://uk.pinterest.com/fixture_user/',
  controller: { getUserAgent() { throw Error('controller detached'); } } };
vm.runInNewContext(ts.transpileModule('function confirm(appVersion: string = "") {' + confirm.split('{').slice(1).join('{').replace(/}\s*$/, '') + '}', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText + ';confirm.call(native, "fixture.1");', { native, PinmonyI18n:require('./local-message-test-fixture.cjs').rawLocalMessages, PIN_NATIVE_HOME_READS_ENABLED: false, PIN_NATIVE_SEARCH_DISCOVERY_ENABLED: false });
assert.equal(native.businessSession.context('authenticated').userAgent, 'fixture-agent');
assert.equal(native.businessSession.context('authenticated').appVersion, 'fixture.1');
console.log('Login host: hidden/accessibility contract, lifecycle capture and controller-independent business confirmation passed');
