const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const indexPath = 'entry/src/main/ets/pages/Index.ets';
const lifecyclePath = 'entry/src/main/ets/app/PinmonyWebLifecycleCoordinator.ets';
const events = [];
const globals = { PinmonyRuntimeLog: { info: text => events.push(text), warn: text => events.push(text) },
  PinmonySessionHistory: { save: () => true } };
function method(file, start, end, args) {
  const source = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
  const at = source.indexOf(start); assert(at >= 0, start);
  const until = source.indexOf(end, at + start.length); assert(until > at, end);
  const text = source.slice(at, until);
  const body = text.slice(text.indexOf('{') + 1, text.lastIndexOf('}'));
  const exports = {};
  vm.runInNewContext(ts.transpileModule('exports.run = function(' + args + ') {' + body + '};', {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, ...globals });
  return exports.run;
}
const failure = method(indexPath, '  private handleMainFrameFailure(', '\n  private describeFailure(', 'url: string, code: number, info: string');
const retry = method(indexPath, '  private retryLogin(', '\n  private updateShareSheet(', '');
const open = method(indexPath, '  private openNativeLogin(', '\n  private async releaseNativeLogin(', '');
const updateAuth = method(indexPath, '  private updateAuthState(', '\n  private syncAuthentication(', 'value: string');
for (const adding of [false, true]) {
  const loads = [], canceled = [], accepted = []; let probes = 0;
  const host = { nativeLoginEnabled: true, loginHostMounted: true, nativeAddAccountFlow: adding,
    nativeAddingAccountProfile: 'https://www.pinterest.com/fixture_previous/', nativeSessionOrigin: 'https://www.pinterest.com',
    loginStartUrl: 'https://www.pinterest.com/login/', nativeSessionEpoch: 2, authEpoch: 3,
    authStatus: 'unauthenticated', loginDocumentLoading: true, nativeVerificationPending: true,
    businessSuspended: false, sessionVerification: { cancel: reason => canceled.push(reason) },
    describeFailure: (url, code) => 'synthetic-code-' + code,
    loadSessionDocument: url => loads.push(url), startNativeVerification: () => probes++,
    sessionCoordinator: { updateAuthState: value => accepted.push(value) },
    openNativeLogin: open, handleMainFrameFailure: failure };
  failure.call(host, host.loginStartUrl, -337, 'ERR_HTTP2_PROTOCOL_ERROR');
  assert.equal(host.authStatus, 'error'); assert.equal(host.loadFailed, true);
  assert.equal(host.loginDocumentLoading, false); assert.equal(host.nativeVerificationPending, false);
  assert.equal(host.failureDetails, 'synthetic-code--337');
  assert.equal(host.nativeSessionEpoch, 3); assert.equal(host.authEpoch, 4);
  updateAuth.call(host, 'late old document evidence'); assert.equal(accepted.length, 0);
  retry.call(host); retry.call(host);
  assert.deepEqual(loads, ['https://www.pinterest.com/login/'], 'one manual GET navigation, no duplicate');
  assert.equal(probes, 0, 'retry must reload login, not verify the old session');
  assert.equal(host.authStatus, 'unauthenticated'); assert.equal(host.loadFailed, false);
  assert.equal(host.loginDocumentLoading, true); assert.equal(host.loginPageVisible, true);
  assert.equal(host.nativeSessionEpoch, 4); assert.equal(host.authEpoch, 5);
  assert.equal(host.nativeAddAccountFlow, adding);
  assert.equal(host.nativeAddingAccountProfile, 'https://www.pinterest.com/fixture_previous/');
  assert.deepEqual(canceled, ['login-document-failed', 'login-required']);
  updateAuth.call(host, 'current document evidence'); assert.equal(accepted.length, 1);
  host.loginDocumentLoading = false; host.authStatus = 'unauthenticated'; retry.call(host);
  assert.equal(loads.length, 1, 'no retry of a healthy form or submitted credentials');
  failure.call(host, host.loginStartUrl, -337, 'ERR_HTTP2_PROTOCOL_ERROR');
  host.businessSuspended = true; retry.call(host); assert.equal(loads.length, 1);
  host.businessSuspended = false; host.authStatus = 'authenticated'; retry.call(host); assert.equal(loads.length, 1);
  host.authStatus = 'error'; host.loadSessionDocument = () => { throw Error('synthetic navigation failure'); };
  retry.call(host); assert.equal(host.authStatus, 'error'); assert.equal(host.loadFailed, true);
  assert.equal(host.loginDocumentLoading, false, 'synchronous load failure stays retryable');
}
let detachedProbes = 0;
retry.call({ nativeLoginEnabled: true, loginHostMounted: false, authStatus: 'error', startNativeVerification() { detachedProbes++; } });
assert.equal(detachedProbes, 1, 'detached startup keeps native session verification');
let legacy = 0;
retry.call({ nativeLoginEnabled: false, sessionCoordinator: { retryLogin() { legacy++; } } }); assert.equal(legacy, 1);
let delegated = 0;
failure.call({ nativeLoginEnabled: true, loginHostMounted: false, failureRecoveryCoordinator: { handleMainFrameFailure() { delegated++; } } }, '', -337, 'synthetic');
assert.equal(delegated, 1, 'non-login failures retain existing handling');
const pageEnd = method(lifecyclePath, 'pageEnd(): void {', '\nconsoleMessage(', '');
const effects = [];
const ports = { nativeBusinessOnly: () => true, authStatus: () => 'error', loadFailed: () => true, logPageLifecycle() {}, setWebPageLoading: value => effects.push(['loading', value]),
  controller: () => ({ getUrl: () => 'https://www.pinterest.com/login/' }), ignoreSupersededDetailDocument: () => false,
  markRootDocumentReady: () => effects.push('ready'), nativeRootOnly: () => false,
  setWebPageLoadFinishedAt() {}, refreshWebNavigation() {}, bindCurrentDetailDocument() {}, syncAuthentication: () => effects.push('auth') };
pageEnd.call({ ports }); assert.deepEqual(effects, [['loading', false]], 'failed page-end never marks ready or authenticates');
ports.loadFailed = () => false; pageEnd.call({ ports }); assert(effects.includes('ready')); assert(effects.includes('auth'));
effects.length = 0; ports.loadFailed = () => true; ports.nativeBusinessOnly = () => false; pageEnd.call({ ports });
assert(effects.includes('ready')); assert(effects.includes('auth'), 'legacy lifecycle remains unchanged');
assert(events.includes('Web: failed document end ignored'));
assert(events.some(text => text.includes('LoginRetry: phase=failed code=-337')));
console.log('Login page retry: sticky error, failed page-end, stale evidence, manual reload, duplicate/background guards, add-account retention and detached startup passed');
