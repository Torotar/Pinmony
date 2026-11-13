const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, { common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }, '@kit.RemoteCommunicationKit': { rcp: {} }, '@kit.BasicServicesKit': {} });
const { PinmonySessionAccounts } = loader.loadFile('feature_settings/src/main/ets/services/PinmonySessionAccounts.ets');
const { acceptsNetworkJob } = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const origin = 'https://' + (process.env.PINMONY_TEST_REGION === 'uk' ? 'uk' : 'www') + '.pinterest.com';
const response = data => ({ status: 200, error: '', body: JSON.stringify(data) });
function fixture() {
  const accounts = ['101', '202', '303'].map((id, i) => ({ id, username: 'fixture_' + i, name: 'Fixture ' + i, avatar: '', email: '', business: false, current: i === 0, loggedIn: true }));
  const store = { token: 1, screen: 'sessionAccounts', sessionAccounts: accounts, sessionAccountsReady: true, sessionAccountsLoading: false, busy: false, loading: false, sessionSwitchUncertain: false, sessionAccountError: '' };
  const state = { authenticated: true, accountId: 'synthetic-partition', generation: 1, origin, userAgent: 'synthetic' };
  const events = [], confirmed = [], loggedOut = [], canceled = [];
  let active = true, visible = true, selected = accounts[0], fail = '', held, heldStage = 'delete', wrongIdentity = false;
  const network = {
    cancel(id) { canceled.push(id); },
    async request(job, current) {
      assert(acceptsNetworkJob(job, current()), 'real native transport must accept the existing contract');
      const payload = JSON.parse(new URLSearchParams(job.body).get('data'));
      if (job.url.endsWith('/delete/')) {
        events.push('delete');
        assert.deepEqual(payload, { options: { disable_auth_failure_redirect: true }, context: {} });
        assert.equal(new URLSearchParams(job.body).get('source_url'), '/settings/');
        if (held && heldStage === 'delete') return held(job);
        if (fail === 'delete') return { status: 503, body: '', error: 'timeout' };
        return response({ resource_response: { status: 'success', http_status: 200, data: { success: true } } });
      }
      events.push('switch');
      selected = accounts.find(a => a.id === payload.options.switch_account);
      assert(selected);
      assert.deepEqual(payload.options, { get_user: true, switch_account: selected.id, app_type_from_client: 6, ui_component: 'undefined.SwitchAccountPage', handler: 'www/switch_account.js', visited_pages_before_login: '[]', arkoseSessionToken: null, recaptchaV3Token: null });
      if (held && heldStage === 'switch') return held(job);
      if (fail === 'switch') throw Error('synthetic unknown switch');
      return response({ resource_response: { status: 'success', data: { success: true, switch_account: true, user: { id: selected.id } } }, client_context: { user: { id: selected.id, username: selected.username } } });
    },
    async verifySession(site, ua, epoch, id, current) {
      assert(current()); events.push('verify');
      if (held && heldStage === 'verify') return held();
      if (fail === 'expired') return response({ client_context: { is_authenticated: false, user: {} }, resource_response: { status: 'success' } });
      if (fail === 'verify') return { status: 503, error: 'timeout', body: '' };
      const user = wrongIdentity ? accounts[0] : selected;
      return response({ client_context: { is_authenticated: true, user: { id: user.id, username: user.username }, app_version: 'fixture.1' }, resource_response: { status: 'success', code: 0, endpoint_name: 'v3_get_user_settings', data: { type: 'user_settings', id: user.id, username: user.username, locale: 'en-US' } } });
    }
  };
  const service = new PinmonySessionAccounts(store, { session: () => ({ ...state }), network: () => network, profile: () => origin + '/fixture_0/', active: () => active, visible: () => visible, beginSwitch() { events.push('block'); }, expired() { events.push('expired'); }, confirmed(result) { confirmed.push(result); }, loggedOut(rows, site) { loggedOut.push({ rows, site }); } });
  return { service, store, state, events, confirmed, loggedOut, canceled, fail(v) { fail = v; }, wrong() { wrongIdentity = true; }, hold(fn, stage = 'delete') { held = fn; heldStage = stage; }, visible(v) { visible = v; }, active(v) { active = v; } };
}
function uiMethod(start, end, params) {
  const source = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySwitchAccountPage.ets', 'utf8');
  const section = source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));
  const body = section.slice(section.indexOf('{') + 1, section.lastIndexOf('}'));
  const exports = {};
  vm.runInNewContext(ts.transpileModule('exports.run = ' + params + '{' + body + '}', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, { exports, PinmonyImmersiveLight: { alertOptions: o => o } });
  return exports.run;
}
async function main() {
  const current = fixture(); await current.service.logoutSelected('101');
  assert.deepEqual(current.events, ['block', 'verify', 'delete']);
  assert.equal(current.loggedOut.length, 1); assert.equal(current.confirmed.length, 0);
  const other = fixture(); await other.service.logoutSelected('202');
  assert.deepEqual(other.events, ['block', 'switch', 'verify', 'delete']);
  assert.equal(other.loggedOut[0].site, origin);
  assert.deepEqual(other.loggedOut[0].rows.filter(a => !a.current).map(a => a.id), ['101', '303']);
  assert(other.loggedOut[0].rows.every(a => a.email === ''));
  for (const failure of ['switch', 'verify', 'delete']) {
    const f = fixture(); f.fail(failure); await f.service.logoutSelected('202');
    assert.equal(f.loggedOut.length, 0); assert(f.store.sessionSwitchUncertain);
    const before = [...f.events]; await f.service.logoutSelected('202'); assert.deepEqual(f.events, before);
    if (failure !== 'delete') assert(!f.events.includes('delete'));
    f.fail(''); await f.service.verifyUncertain(); assert.equal(f.confirmed.length, 1);
    assert.equal(f.loggedOut.length, 0, 'read-only recovery must not resume a pending logout');
    assert.equal(f.events.filter(e => e === 'delete').length, failure === 'delete' ? 1 : 0);
  }
  for (const selected of ['101', '202']) {
    const expired = fixture(); expired.fail('expired'); await expired.service.logoutSelected(selected);
    assert.equal(expired.loggedOut.length, 1, 'explicit logout with authoritative unauthenticated evidence still completes the logout-intent path');
    assert(!expired.events.includes('delete')); assert(!expired.events.includes('expired'), 'ordinary session expiry must not bypass explicit logout persistence');
    assert.equal(expired.loggedOut[0].rows.find(a => a.current).id, selected);
  }
  const expiredRecovery = fixture(); expiredRecovery.fail('delete'); await expiredRecovery.service.logoutSelected('202');
  assert(expiredRecovery.store.sessionSwitchUncertain); expiredRecovery.fail('expired'); await expiredRecovery.service.verifyUncertain();
  assert.equal(expiredRecovery.loggedOut.length, 1); assert.equal(expiredRecovery.loggedOut[0].rows.find(a => a.current).id, '202');
  assert.equal(expiredRecovery.events.filter(e => e === 'delete').length, 1, 'read-only unauthenticated recovery completes logout without replay');
  assert.equal(expiredRecovery.confirmed.length, 0);
  const mismatch = fixture(); mismatch.wrong(); await mismatch.service.logoutSelected('202'); assert(!mismatch.events.includes('delete'));
  for (const alter of [f => { f.store.busy = true; }, f => { f.store.sessionAccountsLoading = true; }, f => { f.store.loading = true; }, f => { f.store.sessionAccountsReady = false; }, f => { f.store.screen = 'root'; }, f => f.visible(false), f => f.active(false), f => { f.store.sessionAccounts[1].loggedIn = false; }]) {
    const f = fixture(); alter(f); await f.service.logoutSelected('202'); assert.equal(f.events.length, 0);
  }
  const duplicate = fixture(); let finish;
  duplicate.hold(() => new Promise(resolve => { finish = resolve; }));
  const pending = duplicate.service.logoutSelected('101'); await new Promise(setImmediate);
  await duplicate.service.logoutSelected('101'); assert.equal(duplicate.events.filter(e => e === 'delete').length, 1);
  duplicate.service.pause(); finish(response({ resource_response: { status: 'success', http_status: 200, data: { success: true } } }));
  await pending; assert.equal(duplicate.loggedOut.length, 0); assert(duplicate.canceled.length); assert(duplicate.store.sessionSwitchUncertain);
  for (const stage of ['switch', 'verify']) {
    const f = fixture(); let release;
    f.hold(() => new Promise(resolve => { release = resolve; }), stage);
    const task = f.service.logoutSelected('202'); await new Promise(setImmediate);
    f.service.pause(); release(response({})); await task;
    assert(!f.events.includes('delete'), 'pausing during ' + stage + ' must prevent logout');
    assert.equal(f.loggedOut.length, 0); assert(f.store.sessionSwitchUncertain);
  }
  const invalid = fixture(); await invalid.service.logoutSelected('404'); assert.equal(invalid.events.length, 0);
  const stale = fixture(); stale.hold(async () => { stale.state.generation++; return response({ resource_response: { status: 'success', http_status: 200, data: { success: true } } }); });
  await stale.service.logoutSelected('101'); assert.equal(stale.loggedOut.length, 0);
  const confirm = uiMethod('  private confirmAccountLogout(', '\n  @Builder', 'function(account: Object)');
  const canLogout = uiMethod('  private canLogout(', '\n  private confirmAccountLogout', 'function(account: Object)');
  for (const invalidate of [null, s => { s.pageVisible = false; }, s => { s.appearance++; }, s => { s.store.token++; }, s => { s.store.sessionAccounts = [...s.store.sessionAccounts]; }, s => { s.store.busy = true; }, s => { s.store.sessionAccounts[0].loggedIn = false; }]) {
    let dialog; const calls = [], f = fixture();
    const scope = { store: f.store, appearance: 1, pageVisible: true, logoutConfirmOpen: false, onRequest() {}, closeSwipe() {}, text: s => s, getUIContext: () => ({ showAlertDialog(o) { dialog = o; } }), request(...args) { calls.push(args); }, canLogout(account) { return canLogout.call(this, account); } };
    confirm.call(scope, f.store.sessionAccounts[0]); assert(dialog); assert.equal(dialog.message, 'pm_session_logout_message', 'confirmation contains only the localized sentence'); assert.equal(calls.length, 0);
    if (invalidate) invalidate(scope); dialog.secondaryButton.action(); assert.equal(calls.length, invalidate ? 0 : 1);
  }
  let dialog; const canceledCalls = []; const canceled = fixture();
  const scope = { store: canceled.store, appearance: 1, pageVisible: true, logoutConfirmOpen: false, onRequest() {}, closeSwipe() {}, canLogout: () => true, text: s => s, getUIContext: () => ({ showAlertDialog(o) { dialog = o; } }), request(...args) { canceledCalls.push(args); } };
  confirm.call(scope, canceled.store.sessionAccounts[0]); dialog.primaryButton.action(); assert.equal(canceledCalls.length, 0);
  const ui = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySwitchAccountPage.ets', 'utf8');
  assert(ui.includes('List({ space: 12, scroller: this.scroller })')); assert(ui.includes('.swipeAction({ end: this.canLogout($$.account)'));
  assert(ui.includes('.padding({ top: this.getUIContext().px2vp(this.statusBarHeightPx) + 72, bottom: 32 })'), 'the List viewport keeps no horizontal inset that could clip swipe actions');
  assert(ui.includes("}.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })"), 'account content retains the existing inset inside the full-width row');
  assert(ui.includes("SymbolGlyph($r('sys.symbol.trash'))")); assert(ui.includes('this.scroller.closeAllSwipeActions()'));
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert(index.includes("if (action === 'logoutSessionAccount') { await this.sessionAccounts.logoutSelected(value); return; }"));
  assert(/loggedOut: \(accounts:[\s\S]*?this\.loggedOutAccounts\.stage\(accounts, origin\);[\s\S]*?this\.completeLogout\(\)/.test(index));
  console.log('PASS swipe account logout: current/other, identity, confirmation, cancellation, stale/background, no replay, ' + origin);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
