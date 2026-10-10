const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function compiled(file, requireFn = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { exports, require: requireFn });
  return exports;
}
const api = compiled('feature_settings/src/main/ets/services/PinmonyLogout.ets');
const { acceptsNetworkJob, PinmonyNativeNetwork } = compiled('common_network/src/main/ets/PinmonyNativeNetwork.ets',
  name => name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {}, warn() {} } } :
    name === 'common_session' ? { PinmonySessionCredentials: class {} } : {});
const page = 'https://www.pinterest.com/sample/', login = 'https://www.pinterest.com/login/';
const state = { authenticated: true, epoch: 7, page, userAgent: 'synthetic' };
const job = { id: 'session_logout_1', epoch: 7, page, method: 'POST',
  url: 'https://www.pinterest.com/resource/UserSessionResource/delete/', body: api.logoutRequestBody(),
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
const context = { ...api, Date, PINTEREST_URL: 'https://www.pinterest.com/', PINTEREST_LOGIN_URL: login,
  PIN_NATIVE_NETWORK_ENABLED: true, PinmonyRuntimeLog: { info() {}, warn() {} } };
vm.runInNewContext(ts.transpile('class Native {' + method + '} globalThis.Native=Native;',
  { target: ts.ScriptTarget.ES2021 }), context);
function harness() {
  const native = new context.Native(), calls = [], loads = []; let resolve;
  Object.assign(native, { authStatus: 'authenticated', authEpoch: 7, profileSettingsVisible: true,
    settingsStore: { screen: 'root', busy: false, loading: false, token: 1, error: '' },
    nativeNetworkContext: () => state, nativeNetwork: { request(request) { calls.push(request); return new Promise(done => { resolve = done; }); } },
    resetAuthenticatedContent() { this.cleared = true; this.settingsStore.token++; this.settingsStore.busy = false; },
    controller: { loadUrl(url) { loads.push(url); } } });
  return { native, calls, loads, reply(value) { resolve(value); } };
}
async function main() {
  const success = harness(); const pending = success.native.logoutAccount();
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
  }
  const stale = harness(); const request = stale.native.logoutAccount(); stale.native.authEpoch++;
  stale.reply({ status: 200, body: confirmedBody, error: '' }); await request;
  assert.equal(stale.native.cleared, undefined); assert.deepEqual(stale.loads, [], 'late response cannot log out another session');
  const disabled = harness(); context.PIN_LOGOUT_API_ENABLED = false; await disabled.native.logoutAccount();
  assert.deepEqual(disabled.calls, []); context.PIN_LOGOUT_API_ENABLED = true;
  const missing = harness(); missing.native.authStatus = 'unauthenticated'; await missing.native.logoutAccount(); assert.deepEqual(missing.calls, []);
  assert.ok(!method.includes('setTimeout'), 'no scheduled write replay');
  const settingsSource = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySettingsPage.ets', 'utf8');
  const confirmMethod = settingsSource.match(/  private confirmLogout\([\s\S]*?(?=\r?\n  private )/)[0];
  const confirmContext = {};
  vm.runInNewContext(ts.transpileModule('class Confirm {' + confirmMethod + '} globalThis.Confirm=Confirm;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, confirmContext);
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
