const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function compiled(file, requireFn = () => ({})) {
  const exports = {};
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { exports, require: requireFn });
  return exports;
}
const api = compiled('feature_settings/src/main/ets/services/PinmonyLogout.ets');
const { acceptsNetworkJob, PinmonyNativeNetwork } = compiled('common_network/src/main/ets/PinmonyNativeNetwork.ets',
  name => name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {}, warn() {} } } :
    name === 'common_session' ? { PinmonySessionCredentials: class {} } : {});
const origin = 'https://' + (process.env.PINMONY_TEST_REGION === 'uk' ? 'uk' : 'www') + '.pinterest.com';
const page = origin + '/sample/', login = 'https://www.pinterest.com/login/';
const state = { authenticated: true, epoch: 7, page, userAgent: 'synthetic' };
const job = { id: 'session_logout_1', epoch: 7, page, method: 'POST',
  url: origin + '/resource/UserSessionResource/delete/', body: api.logoutRequestBody(),
  headers: { 'X-Pinterest-Pws-Handler': 'www/settings.js' } };
assert.equal(acceptsNetworkJob(job, state), true);
for (const change of [{ method: 'GET' }, { epoch: 6 }, { page: page + 'other/' },
  { url: job.url.replace('/delete/', '/create/') }, { url: job.url.replace('/delete/', '/get/') },
  { body: job.body + '&extra=true' }, { body: job.body.replace('%2Fsettings%2F', '%2Flogin%2F') },
  { headers: { 'X-Pinterest-Pws-Handler': 'www/index.js' } },
  { body: 'source_url=%2Fsettings%2F&data=' + encodeURIComponent(JSON.stringify({ options: {
    disable_auth_failure_redirect: true, password: 'synthetic' }, context: {} })) }]) {
  assert.equal(acceptsNetworkJob({ ...job, ...change }, state), false, 'only the observed logout contract is permitted');
}
const confirmedBody = JSON.stringify({ resource_response: { status: 'success', http_status: 200, data: { success: true } },
  client_context: { is_authenticated: true } });
assert.equal(api.logoutResponseSucceeded(200, confirmedBody), true, 'operation success wins over pre-logout client_context');
for (const [status, body] of [[429, confirmedBody], [200, '{}'], [200, '<html>'],
  [200, JSON.stringify({ resource_response: { status: 'success', http_status: 200, data: { success: false } } })]]) {
  assert.equal(api.logoutResponseSucceeded(status, body), false, 'HTTP alone cannot confirm logout');
}
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const method = source.match(/  private async logoutAccount\([\s\S]*?(?=\r?\n  private )/)[0];
const complete = source.match(/  private completeLogout\([\s\S]*?(?=\r?\n  private )/)[0];
const binding = source.match(/new PinmonyLogoutCoordinator\(this.settingsStore, \{([\s\S]*?)\} as PinmonyLogoutPorts\);/);
assert(binding, 'Index binds the real logout coordinator through explicit ports');
const coordinator = require('./arkts-module-loader.cjs').createArktsLoader(ts, {
  common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }
}).loadFile('entry/src/main/ets/app/PinmonyLogoutCoordinator.ets');
const context = { ...api, ...coordinator, Date, PINTEREST_LOGIN_URL: login,
  PIN_NATIVE_NETWORK_ENABLED: true, PinmonyRuntimeLog: { info() {}, warn() {} } };
require('./product-coordination-harness.cjs').run(ts,ts.transpile('class Native {' + method + complete +
  ' bindLogout(){this.logoutCoordinator=new PinmonyLogoutCoordinator(this.settingsStore,{' + binding[1] + '});}} globalThis.Native=Native;',
  { target: ts.ScriptTarget.ES2021 }), context);
function harness() {
  context.Native.prototype.uiText = require('./local-message-test-fixture.cjs').rawLocalMessages.text;
  const native = new context.Native(), calls = [], loads = []; let resolve, reject;
  Object.assign(native, { authStatus: 'authenticated', authEpoch: 7, profileSettingsVisible: true,
    settingsStore: { screen: 'root', busy: false, loading: false, token: 1, error: '' },
    nativeBusinessSessionContext: () => ({authenticated:native.authStatus === 'authenticated',accountId:'synthetic',generation:native.authEpoch,origin,userAgent:'synthetic'}), nativeNetworkContext: () => { throw Error('hidden document must not gate logout'); }, nativeNetwork: { request(request) { calls.push(request); return new Promise((done, fail) => { resolve = done; reject = fail; }); } },
    resetAuthenticatedContent() { this.cleared = true; this.settingsStore.token++; this.settingsStore.busy = false; },
    controller: { loadUrl(url) { loads.push(url); } } });
  native.bindLogout();
  return { native, calls, loads, reply(value) { resolve(value); }, fail() { reject(Error('synthetic network failure')); } };
}
async function main() {
  const success = harness(); const pending = success.native.logoutAccount();
  assert.equal(success.calls[0].url,origin+'/resource/UserSessionResource/delete/');
  await success.native.logoutAccount(); assert.equal(success.calls.length, 1, 'repeated click cannot dispatch another write');
  assert.equal(success.native.authStatus, 'authenticated', 'dispatch is not logout success');
  success.reply({ status: 200, body: confirmedBody, error: '' }); await pending;
  assert.equal(success.native.cleared, true); assert.equal(success.native.authStatus, 'unauthenticated');
  assert.deepEqual(success.loads, [login]);
  for (const response of [{ status: 200, body: '{}', error: '' }, { status: 429, body: '', error: '' },
    { status: 0, body: '', error: 'network-unavailable' }]) {
    const failed = harness(); const request = failed.native.logoutAccount(); failed.reply(response); await request;
    assert.equal(failed.calls.length, 1); assert.equal(failed.native.authStatus, 'authenticated');
    assert.equal(failed.native.cleared, undefined); assert.deepEqual(failed.loads, []);
    assert.equal(failed.native.settingsStore.busy, false); assert.ok(failed.native.settingsStore.error);
    await failed.native.logoutAccount();assert.equal(failed.calls.length,1,'unconfirmed logout cannot be replayed on another click');
  }
  const stale = harness(); const request = stale.native.logoutAccount(); stale.native.authEpoch++;
  stale.reply({ status: 200, body: confirmedBody, error: '' }); await request;
  assert.equal(stale.native.cleared, undefined); assert.deepEqual(stale.loads, [], 'late response cannot log out another session');
  const disabled = harness(); context.PIN_LOGOUT_API_ENABLED = false; await disabled.native.logoutAccount();
  assert.deepEqual(disabled.calls, []); context.PIN_LOGOUT_API_ENABLED = true;
  const missing = harness(); missing.native.authStatus = 'unauthenticated'; await missing.native.logoutAccount(); assert.deepEqual(missing.calls, []);
  assert.ok(!fs.readFileSync('entry/src/main/ets/app/PinmonyLogoutCoordinator.ets', 'utf8').includes('setTimeout'), 'no scheduled write replay');
  for (const change of [host => { host.settingsStore.token++; },
    host => { host.nativeBusinessSessionContext = () => ({ authenticated: true, accountId: 'another', generation: host.authEpoch, origin }); },
    host => { host.nativeBusinessSessionContext = () => ({ authenticated: true, accountId: 'synthetic', generation: host.authEpoch, origin: origin === 'https://www.pinterest.com' ? 'https://uk.pinterest.com' : 'https://www.pinterest.com' }); }]) {
    const changed = harness(); const pending = changed.native.logoutAccount(); change(changed.native);
    changed.reply({ status: 200, body: confirmedBody, error: '' }); await pending;
    assert.equal(changed.native.cleared, undefined, 'stale token, account or origin cannot confirm logout');
  }
  for (const error of ['request-unavailable', 'background']) {
    const unsent = harness(); const pending = unsent.native.logoutAccount(); unsent.reply({ status: 0, body: '', error }); await pending;
    const retry = unsent.native.logoutAccount(); assert.equal(unsent.calls.length, 2, 'only a known unsent write permits manual retry');
    unsent.reply({ status: 200, body: confirmedBody, error: '' }); await retry;
  }
  const unavailable = harness(); unavailable.native.controller.loadUrl = () => { throw Error('synthetic login load failure'); };
  const loginPending = unavailable.native.logoutAccount(); unavailable.reply({ status: 200, body: confirmedBody, error: '' }); await loginPending;
  assert.equal(unavailable.native.authStatus, 'error'); assert.ok(unavailable.native.failureDetails);
  const rejected = harness(); const rejectedPending = rejected.native.logoutAccount();
  rejected.fail(); await rejectedPending;
  assert.equal(rejected.native.authStatus, 'authenticated'); assert.ok(rejected.native.settingsStore.error);
  await rejected.native.logoutAccount(); assert.equal(rejected.calls.length, 1, 'thrown transport error does not replay a possibly sent write');
  const staleFailure = harness(); const stalePending = staleFailure.native.logoutAccount(); staleFailure.native.authEpoch++;
  staleFailure.fail(); await stalePending;
  assert.equal(staleFailure.native.settingsStore.error, '', 'late transport rejection cannot write an error into a later session');

  const settingsSource = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySettingsPage.ets', 'utf8');
  const confirmMethod = settingsSource.match(/  private confirmLogout\([\s\S]*?(?=\r?\n  private )/)[0];
  const confirmContext = {};
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Confirm {' + confirmMethod + '} globalThis.Confirm=Confirm;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, confirmContext);
  confirmContext.Confirm.prototype.uiText=require('./local-message-test-fixture.cjs').rawLocalMessages.text;
  const confirm = new confirmContext.Confirm(), dialogs = [], confirmedWrites = [];
  confirm.store = { screen: 'root', token: 1, loading: false, busy: false };
  confirm.pageVisible = true; confirm.logoutConfirmOpen = false;
  confirm.getUIContext = () => ({ showAlertDialog: options => dialogs.push(options) });
  confirm.onRequest = action => confirmedWrites.push(action);
  confirm.confirmLogout(); confirm.confirmLogout();
  assert.equal(dialogs.length, 1); assert.equal(confirmedWrites.length, 0);
  dialogs[0].primaryButton.action(); assert.equal(confirmedWrites.length, 0, 'cancel sends no logout');
  confirm.confirmLogout(); dialogs[1].secondaryButton.action(); assert.deepEqual(confirmedWrites, ['logout']);
  confirm.confirmLogout(); confirm.store.token++; dialogs[2].secondaryButton.action();
  assert.equal(confirmedWrites.length, 1, 'stale confirmation cannot log out a changed session');
  console.log('Logout API: exact contract, duplicate guard, business success, failure retention, stale session and no write replay passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
