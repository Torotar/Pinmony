const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, { common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }, '@kit.RemoteCommunicationKit': { rcp: {} }, '@kit.BasicServicesKit': {} });
const { PinmonyLoggedOutAccounts } = loader.loadFile('feature_settings/src/main/ets/services/PinmonyLoggedOutAccounts.ets');
const { PinmonyNativeNetwork, acceptsNetworkJob } = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const origin = 'https://' + (process.env.PINMONY_TEST_REGION === 'uk' ? 'uk' : 'www') + '.pinterest.com';
const row = (id, current = false, loggedIn = true) => ({ id, username: 'fixture_' + id, name: 'Fixture ' + id,
  avatar: '', email: 'private@example.invalid', business: false, current, loggedIn });
function fixture() {
  let active = true, epoch = 1, pending, fail = '', probe = '', probes = 0, readFail = '', readPending;
  const writes = [], confirmations = [], reads = [];
  const account = new PinmonyLoggedOutAccounts({ available: () => active, epoch: () => epoch, userAgent: () => 'fixture',
    network: () => ({
      async transfer(job, owner, dispatched) {
        assert(owner());
        if (job.id.startsWith('logged_out_accounts_read_')) {
          reads.push(job);
          const options = JSON.parse(new URLSearchParams(job.body).get('data')).options;
          if (readPending) await readPending();
          if (readFail === 'network') throw Error('network');
          const data = options.session_accounts ? { success: true, session_accounts: readFail === 'empty' ? {} : { '101': { logged_in: false }, '202': { logged_in: true }, '303': { logged_in: true } } } : Object.fromEntries(['202','303'].map(id => ['GET:v3/users/' + id + '/', { status: 'success', code: 0, endpoint_name: 'v3_get_user_handler', data: { id: readFail === 'identity' ? '999' : id, username: 'fixture_' + id, full_name: 'Fixture ' + id } }]));
          return { status: 200, text: JSON.stringify({ resource_response: { status: 'success', code: 0, endpoint_name: options.session_accounts ? '' : 'v3_batch_handler', data }, client_context: { is_authenticated: false } }) };
        }
        if (fail === 'unsent') throw Error('not dispatched');
        writes.push(job); dispatched();
        if (pending) await pending();
        if (fail === 'sent') throw Error('unknown');
        const id = JSON.parse(new URLSearchParams(job.body).get('data')).options.switch_account;
        return { status: 200, text: JSON.stringify({ resource_response: { status: 'success', code: 0,
          data: { success: fail !== 'business', switch_account: true, user: { id } } }, client_context: { user: { id } } }) };
      },
      async verifySession(site, agent, generation, id, owner) {
        return PinmonyNativeNetwork.prototype.verifySession.call({
          async request(job, current) {
            assert(acceptsNetworkJob(job, current()), 'actual constructed probe must pass transport admission');
            assert(/^session_probe_\d+$/.test(job.id));
        probes++; assert.equal(site, origin); assert(owner());
        const target = probe || '202';
        return { status: 200, error: target === 'error' ? 'network' : '', body: JSON.stringify({
          resource_response: { status: 'success', code: 0, endpoint_name: 'v3_get_user_settings',
            data: { type: 'user_settings', id: target, username: 'fixture_' + target, locale: 'en-US' } },
          client_context: { is_authenticated: target !== 'expired', user: target === 'expired' ? {} : { id: target, username: 'fixture_' + target } } }) };
          }
        }, site, agent, generation, id, owner);
      }
    }), confirmed: result => { confirmations.push(result); account.reset(); } });
  account.stage([row('101', true), row('202'), row('303'), row('404', false, false)], origin);
  return { account, writes, confirmations, reads, readFail(value) { readFail = value; }, readDelay(fn) { readPending = fn; }, active(value) { active = value; }, epoch() { epoch++; },
    delay(fn) { pending = fn; }, fail(value) { fail = value; }, probe(value) { probe = value; }, probes: () => probes };
}
function extract(file, name, end, params) {
  const source = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
  const start = source.indexOf(name); const block = source.slice(start, source.indexOf(end, start));
  const body = block.slice(block.indexOf('{') + 1, block.lastIndexOf('}'));
  const exports = {};
  vm.runInNewContext(ts.transpileModule('exports.run = ' + params + '{' + body + '};', {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, PinmonyI18n: { message: key => key } });
  return exports.run;
}
async function main() {
  await assert.rejects(() => PinmonyNativeNetwork.prototype.verifySession.call({ request() { throw Error('invalid probe must never dispatch'); } }, origin, 'fixture', 1, 'logged_out_account_probe_1', () => true), /session-probe-unavailable/);
  const restored = fixture(); restored.account.reset(); restored.account.arm();
  await restored.account.restore(origin);
  assert.deepEqual(Array.from(restored.account.accounts, a => a.id), ['202','303']);
  assert(restored.account.accounts.every(a => !a.current && a.email === ''));
  assert.equal(restored.writes.length, 0); assert.equal(restored.confirmations.length, 0);
  assert.equal(restored.account.acceptsWebLogin(), false, 'restart discovery never accepts passive login');
  await restored.account.restore(origin); assert.equal(restored.reads.length, 2, 'repeated page-end does not refetch candidates');
  for (const job of restored.reads) {
    const opts = JSON.parse(new URLSearchParams(job.body).get('data')).options;
    assert(!('switch_account' in opts) && !('get_user' in opts), 'discovery never switches accounts');
    assert.equal(job.page, origin + '/switch_account/'); assert(job.authenticated);
  }
  for (const failure of ['network', 'identity', 'empty']) {
    const f = fixture(); f.account.reset(); f.account.arm(); f.readFail(failure); await f.account.restore(origin);
    assert.equal(f.account.accounts.length, 0); assert.equal(f.account.busy, false);
    assert.equal(f.account.restoreFailed, failure !== 'empty');
    assert.equal(f.writes.length, 0); assert.equal(f.confirmations.length, 0);
    if (failure !== 'empty') { f.readFail(''); await f.account.retryRestore(); assert.equal(f.account.accounts.length, 2); }
  }
  for (const cancel of ['reset','epoch','background']) {
    const f = fixture(); f.account.reset(); f.account.arm(); let done;
    f.readDelay(() => new Promise(resolve => { done = resolve; }));
    const pending = f.account.restore(origin);
    if (cancel === 'reset') f.account.reset(); else if (cancel === 'epoch') f.epoch(); else f.active(false);
    done(); await pending;
    assert.equal(f.account.accounts.length, 0); assert.equal(f.reads.length, 1); assert.equal(f.confirmations.length, 0);
  }
  const initial = fixture();
  assert.equal(initial.account.accounts.length, 2);
  assert(initial.account.accounts.every(account => account.email === '' && !account.current));
  await initial.account.choose('202'); assert.equal(initial.writes.length, 0, 'staged accounts cannot log in before confirmed logout');
  initial.account.arm(); assert.equal(initial.account.acceptsWebLogin(), false, 'passive web and native evidence cannot log in automatically');
  assert.equal(initial.writes.length, 0, 'arming does not send a login');
  await initial.account.choose('101'); await initial.account.choose('404'); await initial.account.choose('999');
  assert.equal(initial.writes.length, 0, 'current, expired and arbitrary identities cannot be chosen');
  await initial.account.choose('202'); assert.equal(initial.writes.length, 1); assert.equal(initial.confirmations.length, 1);
  assert.equal(initial.probes(), 1, 'resource success is independently verified');
  assert.equal(initial.account.active, false); assert.equal(initial.account.accounts.length, 0);
  const job = initial.writes[0], payload = JSON.parse(new URLSearchParams(job.body).get('data'));
  assert.equal(job.url, origin + '/resource/UserSessionResource/create/');
  assert.equal(job.page, origin + '/switch_account/'); assert.equal(job.authenticated, true, 'current ArkWeb credentials are included at transport time');
  assert.deepEqual(payload, { options: { get_user: true, switch_account: '202', app_type_from_client: 6,
    ui_component: 'undefined.SwitchAccountPage', handler: 'www/switch_account.js', visited_pages_before_login: '[]',
    arkoseSessionToken: null, recaptchaV3Token: null }, context: {} });
  for (const failure of ['sent', 'business']) {
    const f = fixture(); f.account.arm(); f.fail(failure); await f.account.choose('202');
    assert.equal(f.account.uncertain, true); assert(f.account.error); assert.equal(f.confirmations.length, 0);
    await f.account.choose('303'); assert.equal(f.writes.length, 1, 'unknown login is never replayed or replaced');
    f.fail(''); await f.account.verifySelected(); assert.equal(f.writes.length, 1); assert.equal(f.confirmations.length, 1);
  }
  const recoverMismatch = fixture(); recoverMismatch.account.arm(); recoverMismatch.probe('303');
  await recoverMismatch.account.choose('202'); assert(recoverMismatch.account.uncertain);
  await recoverMismatch.account.verifySelected();
  assert.equal(recoverMismatch.account.uncertain, false, 'an authoritative different identity restores explicit login instead of an endless verify loop');
  assert.equal(recoverMismatch.account.acceptsWebLogin(), false, 'different identity must not log in automatically');
  assert.equal(recoverMismatch.confirmations.length, 0); assert.equal(recoverMismatch.writes.length, 1, 'read-only recovery never replays the switch');
  assert(recoverMismatch.account.error); recoverMismatch.account.allowManualLogin(); assert(recoverMismatch.account.acceptsWebLogin());
  const unsent = fixture(); unsent.account.arm(); unsent.fail('unsent'); await unsent.account.choose('202');
  assert.equal(unsent.account.uncertain, false); unsent.fail(''); await unsent.account.choose('202'); assert.equal(unsent.confirmations.length, 1);
  const mismatch = fixture(); mismatch.account.arm(); mismatch.probe('303'); await mismatch.account.choose('202');
  assert.equal(mismatch.confirmations.length, 0); assert(mismatch.account.uncertain);
  mismatch.probe('expired'); await mismatch.account.verifySelected(); assert.equal(mismatch.account.uncertain, false);
  assert.equal(mismatch.account.accounts.some(account => account.id === '202'), false, 'expired candidate removed after authoritative unauthenticated evidence');
  const last = fixture(); last.account.stage([row('202')], origin); last.account.arm(); last.probe('expired');
  await last.account.choose('202');
  assert.equal(last.account.accounts.length, 0); assert(last.account.error); assert.equal(last.account.uncertain, false);
  last.account.allowManualLogin(); assert(last.account.acceptsWebLogin(), 'last expired candidate permits manual login');
  const loginSource = fs.readFileSync('entry/src/main/ets/components/PinmonyLoginPage.ets', 'utf8');
  const footerSource = fs.readFileSync('entry/src/main/ets/components/PinmonyOtherAccountsLogin.ets', 'utf8');
  assert(loginSource.includes('view.otherAccounts.accounts.length > 0 || view.otherAccounts.error || view.otherAccounts.uncertain'), 'footer retains last-candidate error');
  assert(footerSource.includes('if (this.accounts.accounts.length > 0 || this.accounts.uncertain || this.accounts.restoreFailed)'), 'only actionable login, verify or retry buttons are shown');
  for (const cancel of ['background', 'epoch', 'reset']) {
    const late = fixture(); late.account.arm(); let done; late.delay(() => new Promise(resolve => { done = resolve; }));
    const pending = late.account.choose('202'); await late.account.choose('303'); assert.equal(late.writes.length, 1);
    if (cancel === 'background') late.active(false); else if (cancel === 'epoch') late.epoch(); else late.account.reset();
    done(); await pending; assert.equal(late.confirmations.length, 0); assert.equal(late.probes(), 0);
  }
  const manual = fixture(); manual.account.arm(); manual.account.allowManualLogin(); assert(manual.account.acceptsWebLogin());
  const passive = fixture(); passive.account.arm(); let verifications = 0, accepted = 0;
  const authHost = { loggedOutAccounts: passive.account, nativeAddAccountFlow: false, loginHostMounted: true,
    nativeVerificationPending: false, authEpoch: 1, authStatus: 'checking', loginPageVisible: false,
    startNativeVerification() { verifications++; }, sessionCoordinator: { updateAuthState() { accepted++; } } };
  const webEvidence = extract('entry/src/main/ets/pages/Index.ets', '    verifyLoginEvidence:', '\n    enterAuthenticatedRoot:', 'function(message: Object)');
  const nativeEvidence = extract('entry/src/main/ets/pages/Index.ets', '    accept: (message: PinmonyAuthMessage)', '\n  });', 'function(message: Object)');
  const message = { status: 'authenticated', profileUrl: origin + '/fixture_202/', pageUrl: origin + '/login/' };
  webEvidence.call(authHost, message); nativeEvidence.call(authHost, message);
  assert.equal(verifications, 0); assert.equal(accepted, 0); assert.equal(authHost.authStatus, 'unauthenticated');
  passive.account.allowManualLogin(); webEvidence.call(authHost, message); assert.equal(verifications, 1, 'explicit login interaction restores normal native verification');
  nativeEvidence.call(authHost, message); assert.equal(accepted, 1);
  const choose = extract('entry/src/main/ets/components/PinmonyOtherAccountsLogin.ets', '  private choose()', '\n  build()', 'function()');
  const ui = fixture(); ui.account.arm(); const dialogs = [], selected = [];
  ui.account.choose = async id => selected.push(id);
  const host = { mounted: true, appearance: 1, choosing: false, loading: false, accounts: ui.account, text: key => key,
    getUIContext: () => ({ showActionSheet: options => dialogs.push(options) }) };
  choose.call(host); assert.equal(dialogs.length, 1); assert.equal(selected.length, 0);
  dialogs[0].confirm.action(); assert.equal(selected.length, 0, 'cancel does not log in');
  choose.call(host); dialogs[1].sheets[1].action(); assert.deepEqual(selected, ['303']);
  choose.call(host); ui.account.reset(); dialogs[2].sheets[0].action(); assert.equal(selected.length, 1, 'stale dialog cannot select a new session');
  ui.account.stage([row('202'), row('303')], origin); ui.account.arm(); choose.call(host);
  host.appearance += 2; host.choosing = false; choose.call(host);
  dialogs[3].sheets[0].action(); assert.equal(selected.length, 1, 'old appearance cannot select after returning');
  assert(host.choosing, 'old action cannot release the new chooser lock');
  dialogs[3].cancel(); assert(host.choosing, 'old cancel cannot release the new chooser lock');
  dialogs[4].cancel(); assert.equal(host.choosing, false);
  ui.account.stage([row('202')], origin); ui.account.arm(); choose.call(host); assert.deepEqual(selected, ['303', '202'], 'single remaining account needs no chooser');
  const logout = extract('entry/src/main/ets/pages/Index.ets', '  private async logoutAccount()', '\n  private completeLogout', 'async function()');
  const calls = [], state = { token: 1, screen: 'root', busy: false, loading: false, sessionAccountsReady: true, sessionAccounts: [row('101', true), row('202')] };
  let done;
  const root = { authStatus: 'authenticated', profileSettingsVisible: true, nativeSessionEpoch: 1, settingsStore: state,
    sessionAccounts: { read: () => new Promise(resolve => { done = resolve; }) }, loggedOutAccounts: { stage: () => calls.push('stage'), reset() {}, active: false },
    nativeBusinessSessionContext: () => ({ origin }), logoutCoordinator: { logout: async () => calls.push('logout') } };
  let pending = logout.call(root); await logout.call(root); done(); await pending; assert.deepEqual(calls, ['stage', 'logout']);
  calls.length = 0; pending = logout.call(root); state.token++; done(); await pending; assert.equal(calls.length, 0, 'closing and reopening settings cancels logout preparation');
  pending = logout.call(root); state.sessionAccountsReady = false; state.sessionAccountError = 'read-failed'; done(); await pending;
  assert.equal(calls.length, 0); assert.equal(state.error, 'read-failed', 'read failure preserves current account');
  console.log('Logged-out accounts: no automatic login, exact switch contract, current/expired exclusion, chooser cancel, single/multiple, duplicate/late/background isolation, verified recovery and logout preparation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
