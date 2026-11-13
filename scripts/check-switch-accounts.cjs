const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, { common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }, '@kit.RemoteCommunicationKit': { rcp: {} }, '@kit.BasicServicesKit': {} });
const { PinmonySessionAccounts } = loader.loadFile('feature_settings/src/main/ets/services/PinmonySessionAccounts.ets');
const { acceptsNetworkJob } = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const { isPinterestAuthRoute } = loader.loadFile('common_session/src/main/ets/models/PinmonyAuth.ets');
const origin = 'https://' + (process.env.PINMONY_TEST_REGION === 'uk' ? 'uk' : 'www') + '.pinterest.com';
function fixture(count = 2) {
  let active = true, visible = true, target = 'fixture_a', failure = '', delayed, probeFailure = false, expired = false;
  const state = { authenticated: true, generation: 1, accountId: 'synthetic-partition', origin, userAgent: 'synthetic' };
  const store = { token: 1, screen: 'sessionAccounts', busy: false, sessionAccounts: [], sessionAccountsLoading: false, sessionAccountsReady: false, sessionAccountError: '', sessionSwitchUncertain: false, sessionAccountSwitchMode: false, rememberAccountEntry(value) { this.sessionAccountSwitchMode = value; } };
  const jobs = [], confirmed = [], canceled = []; let begins = 0, probes = 0, expiries = 0;
  const user = (id) => ({ id, username: id === '101' ? 'fixture_a' : 'fixture_b', full_name: id === '101' ? 'Current fixture' : 'Other fixture', image_medium_url: 'https://i.pinimg.com/fixture.png', partner: null, email: id === '101' ? 'current@example.invalid' : 'other@example.invalid' });
  const response = data => ({ status: 200, error: '', body: JSON.stringify(data) });
  const context = () => ({ is_authenticated: true, user: user('101') });
  const network = {
    cancel(id) { canceled.push(id); },
    async request(job, current) {
      assert(acceptsNetworkJob(job, current()), 'actual service request must pass native transport admission');
      jobs.push(job); const o = JSON.parse(new URLSearchParams(job.body).get('data')).options;
      if (delayed) return delayed(job, o, current);
      if (o.session_accounts) {
        const accounts = { '101': { logged_in: true }, ...(count > 1 ? { '202': { logged_in: true } } : {}) };
        return response({ resource_response: { status: failure === 'read' ? 'error' : 'success', http_status: 200, data: { success: true, session_accounts: count === 0 ? {} : accounts } }, client_context: context() });
      }
      if (o.url === '/v3/batch/') {
        const data = {}; for (const req of JSON.parse(o.data.requests)) {
          const id = req.uri.split('/')[2]; data['GET:' + req.uri] = { status: 'success', code: 0, endpoint_name: 'v3_get_user_handler', data: user(id) };
        }
        if (failure === 'batch') data['GET:v3/users/202/'].data.id = '303';
        return response({ resource_response: { status: 'success', code: 0, endpoint_name: 'v3_batch_handler', data }, client_context: context() });
      }
      assert.equal(o.switch_account, '202'); target = 'fixture_b';
      if (failure === 'switch') throw Error('synthetic connection loss');
      // The captured switch response has user evidence but omits is_authenticated.
      return response({ resource_response: { status: 'success', http_status: 200, data: { success: true, switch_account: true, user: user('202') } }, client_context: { user: user('202') } });
    },
    async verifySession(site, ua, epoch, id, current) {
      probes++; assert(current()); assert.equal(site, origin);
      if (expired) return response({ client_context: { is_authenticated: false, user: {} }, resource_response: { status: 'success' } });
      if (probeFailure) return { status: 503, error: 'synthetic', body: '' };
      const idValue = target === 'fixture_b' ? '202' : '101';
      return response({ client_context: { is_authenticated: true, user: { id: idValue, username: target }, app_version: 'fixture.1' }, resource_response: { status: 'success', code: 0, endpoint_name: 'v3_get_user_settings', data: { type: 'user_settings', id: idValue, username: target, locale: 'en-US' } } });
    }
  };
  const service = new PinmonySessionAccounts(store, { session: () => ({ ...state }), profile: () => origin + '/fixture_a/', network: () => network, active: () => active, visible: () => visible, beginSwitch() { begins++; }, expired() { expiries++; }, confirmed: result => confirmed.push(result) });
  return { service, store, state, jobs, confirmed, canceled, failure(v) { failure = v; }, delay(fn) { delayed = fn; }, active(v) { active = v; }, visible(v) { visible = v; }, probeFailure(v) { probeFailure = v; }, expire() { expired = true; }, expiries: () => expiries, begins: () => begins, probes: () => probes };
}
function method(file, start, end, params, globals = {}) {
  const source = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n'); const text = source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));
  const body = text.slice(text.indexOf('{') + 1, text.lastIndexOf('}'));
  const exports = {}; vm.runInNewContext(ts.transpileModule('exports.run = ' + params + '{' + body + '};', { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, { ...globals, exports }); return exports.run;
}
async function main() {
  const { PIN_ADD_ACCOUNT_LOGIN_SCRIPT } = loader.loadFile('common_session/src/main/ets/services/PinmonyAddAccountLogin.ets');
  function runRouteState(url, initial, topLevel = true, fail = false) {
    let writes = 0;
    const history = { state: initial, replaceState(next, title) { if (fail) throw Error('synthetic history failure'); assert.equal(title, ''); this.state = next; writes++; } };
    const window = {}; window.top = topLevel ? window : {};
    const location = new URL(url);
    vm.runInNewContext(PIN_ADD_ACCOUNT_LOGIN_SCRIPT, { window, history, location });
    return { history, writes };
  }
  for (const initial of [null, {}, { usr: { next: '/fixture/', switch_account: 'false' }, key: 'synthetic-route', idx: 3 }]) {
    const before = JSON.stringify(initial);
    const state = runRouteState(origin + '/login/', initial);
    assert.equal(state.writes, 1);
    assert.equal(state.history.state.usr.switch_account, 'true');
    assert.equal(state.history.state.usr.secondary_account, 'true');
    assert.equal(JSON.stringify(initial), before, 'do not mutate prior router state');
    if (initial?.key) { assert.equal(state.history.state.key, initial.key); assert.equal(state.history.state.idx, 3); assert.equal(state.history.state.usr.next, '/fixture/'); }
    const repeated = runRouteState(origin + '/login/', state.history.state);
    assert.equal(JSON.stringify(repeated.history.state), JSON.stringify(state.history.state), 'initialization is idempotent');
  }
  for (const url of [origin + '/', origin + '/add-account/', origin + '/signup/', 'https://example.com/login/', 'https://www.pinterest.com.example.invalid/login/']) {
    assert.equal(runRouteState(url, null).writes, 0, 'scope excludes business and third-party routes');
  }
  assert.equal(runRouteState(origin + '/login/', null, false).writes, 0, 'no iframe state writes');
  assert.equal(runRouteState(origin + '/login/', null, true, true).writes, 0, 'history failure does not break website initialization');
  for (const n of [1, 2]) {
    const f = fixture(n); await f.service.read(); assert(f.store.sessionAccountsReady); assert.equal(f.store.sessionAccounts.length, n);
    assert.equal(f.store.sessionAccounts[0].email, 'current@example.invalid');
    if (n > 1) assert.equal(f.store.sessionAccounts[1].email, '', 'never retain other-account email in display data');
    assert.equal(f.begins(), 0); assert.equal(f.probes(), 0);
  }
  for (const bad of ['read', 'batch']) { const f = fixture(); f.failure(bad); await f.service.read(); assert(!f.store.sessionAccountsReady); assert(f.store.sessionAccountError); }
  const empty = fixture(0); await empty.service.read(); assert(!empty.store.sessionAccountsReady, 'missing current identity is failure, not an empty account list');
  const f = fixture(); await f.service.read(); const readJob = f.jobs[0], batchJob = f.jobs[1];
  await f.service.switchTo('101'); await f.service.switchTo('999'); assert.equal(f.jobs.length, 2, 'current or unlisted account cannot switch');
  await f.service.switchTo('202'); assert.equal(f.confirmed.length, 1); assert.equal(f.probes(), 1); assert.equal(f.confirmed[0].profileUrl, origin + '/fixture_b/'); assert.equal(f.begins(), 1);
  const writeJob = f.jobs[2];
  for (const original of [readJob, batchJob, writeJob]) {
    const context = { authenticated: true, epoch: 1, page: original.page, userAgent: 'synthetic' };
    assert(acceptsNetworkJob(original, context));
    assert(!acceptsNetworkJob(original, { ...context, epoch: 2 }));
    assert(!acceptsNetworkJob({ ...original, headers: { ...original.headers, 'X-Pinterest-Pws-Handler': 'www/index.js' } }, context));
    const e = JSON.parse(new URLSearchParams(original.body).get('data')); e.options.unconfirmed_extra = true;
    assert(!acceptsNetworkJob({ ...original, body: 'source_url=%2Fswitch_account%2F&data=' + encodeURIComponent(JSON.stringify(e)) }, context));
  }
  const unknown = fixture(); await unknown.service.read(); unknown.failure('switch'); await unknown.service.switchTo('202');
  assert(unknown.store.sessionSwitchUncertain); assert.equal(unknown.confirmed.length, 0); const writeCount = unknown.jobs.length;
  await unknown.service.switchTo('202'); await unknown.service.read(); assert.equal(unknown.jobs.length, writeCount, 'unknown writes are never replayed or hidden by list refresh');
  await unknown.service.verifyUncertain(); assert.equal(unknown.jobs.length, writeCount); assert.equal(unknown.confirmed.length, 1); assert.equal(unknown.probes(), 1);
  const probe = fixture(); await probe.service.read(); probe.probeFailure(true); await probe.service.switchTo('202'); assert(probe.store.sessionSwitchUncertain); assert(!probe.confirmed.length);
  for (const cancel of ['background', 'account', 'close']) {
    const late = fixture(); let resolve; late.delay(() => new Promise(r => { resolve = r; })); const read = late.service.read();
    if (cancel === 'background') { late.active(false); late.service.pause(); } else if (cancel === 'account') late.state.generation++; else { late.visible(false); late.store.token++; }
    resolve({ status: 200, error: '', body: '{}' }); await read; assert(!late.store.sessionAccountsReady); assert.equal(late.confirmed.length, 0);
  }
  const paused = fixture(); await paused.service.read(); let finish; paused.delay(() => new Promise(r => { finish = r; }));
  const switching = paused.service.switchTo('202'); paused.service.pause(); assert(paused.store.sessionSwitchUncertain); assert(paused.store.sessionAccountError);
  finish({ status: 200, error: '', body: '{}' }); await switching; assert(!paused.confirmed.length); assert(paused.canceled.length); paused.delay(undefined);
  await paused.service.verifyUncertain(); assert.equal(paused.confirmed.length, 1, 'returning from background can only verify the actual current session');
  const expiredSession = fixture(); await expiredSession.service.read(); expiredSession.failure('switch'); await expiredSession.service.switchTo('202'); expiredSession.expire(); await expiredSession.service.verifyUncertain(); assert.equal(expiredSession.expiries(), 1); assert(!expiredSession.confirmed.length);
  const ui = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySwitchAccountPage.ets', 'utf8');
  const addGuard = ui.match(/if \((this\.store\.sessionAccountsReady && !this\.store\.sessionAccountsLoading)\) \{\s*(?:ListItem\(\) \{ Row\(\) \{ )?Button\(this\.text\('pm_add_account'\)/);
  assert(addGuard, 'add account is only mounted after successful list loading');
  for (const ready of [false, true]) for (const loading of [false, true]) {
    assert.equal(vm.runInNewContext(addGuard[1].replaceAll('this.store.', 'store.'), { store: { sessionAccountsReady: ready, sessionAccountsLoading: loading } }), ready && !loading);
  }
  assert(/if \(this\.store\.sessionAccountsLoading \|\| this\.store\.busy\) \{\s*PinmonyLoadingOverlay\(\{ showMessage: false \}\)/.test(ui), 'reads and account switch use the shared blocking gray overlay');
  assert(ui.includes('if (!this.store.busy && this.onBack) this.onBack();'), 'ordinary list loading retains back navigation');
  assert(ui.includes('$$.account.current && $$.account.email')); assert(ui.includes("Button(this.text('pm_add_account')"));
  assert(ui.includes('PinmonyImmersiveLight.effect(this.immersiveLightMode)')); assert(ui.includes('.bindToScrollable([this.scroller])'));
  assert(ui.includes('Checkbox().select(true).width(24).height(24).margin(0).shape(CheckBoxShape.CIRCLE)'), 'current account uses native circular checkbox');
  assert(ui.includes(".selectedColor($r('app.color.accent')).hitTestBehavior(HitTestMode.None).focusable(false)"), 'current indicator uses shared theme and cannot toggle');
  assert(!ui.includes("SymbolGlyph($r('sys.symbol.checkmark'))"), 'standalone checkmark glyph replaced');
  const root = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySettingsPage.ets', 'utf8');
  assert(root.includes("'sessionAccounts', 'logout'")); assert(root.includes("'pm_log_out_e7677436'"));
  const label = method('feature_settings/src/main/ets/components/PinmonySettingsPage.ets', '  private optionLabel(', '\n  aboutToAppear', 'function(id: string)');
  const options = ['profile','account','visibility','recommend','display','social','notifications','sessionAccounts','logout','logs','about'];
  const scope = { options, uiText: key => key, store: { sessionAccountSwitchMode: false, sessionAccountsReady: false, sessionAccounts: [] } };
  assert.equal(label.call(scope, 'sessionAccounts'), 'pm_add_account');
  scope.store.sessionAccountSwitchMode = true;
  assert.equal(label.call(scope, 'sessionAccounts'), 'pm_switch_accounts', 'remembered label survives cleared session list');
  assert.equal(label.call(scope, 'logout'), 'pm_log_out_e7677436');
  assert(root.includes("if (!this.store.sessionAccountSwitchMode) { this.onRequest('addAccount', ''); }"));
  const appear = root.slice(root.indexOf('  aboutToAppear()'), root.indexOf('  aboutToDisappear()'));
  assert(!appear.includes('onRequest('), 'opening settings never reads accounts');
  const { PinmonySettingsStore } = loader.loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets');
  const memoryStore = new PinmonySettingsStore(); const saves = [];
  memoryStore.onAccountEntryChange = value => saves.push(value);
  memoryStore.rememberAccountEntry(true); memoryStore.reset(); assert(memoryStore.sessionAccountSwitchMode, 'ordinary settings reset retains entry mode');
  memoryStore.rememberAccountEntry(false); memoryStore.reset(); assert(!memoryStore.sessionAccountSwitchMode); assert.deepEqual(saves, [true, false]);
  const disk = new Map();
  const preferences = { getPreferencesSync() { return { getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback, putSync: (key, value) => disk.set(key, value), flushSync() {} }; } };
  const freshMemory = () => createArktsLoader(ts, { '@kit.AbilityKit': {}, '@kit.ArkData': { preferences }, common_foundation: { PinmonyRuntimeLog: { warn() {} } } }).loadFile('feature_settings/src/main/ets/services/PinmonyAccountEntryMemory.ets').PinmonyAccountEntryMemory;
  let memory = freshMemory(); assert.equal(memory.initialize({}), false); memory.save(true);
  memory = freshMemory(); assert.equal(memory.initialize({}), true, 'entry mode survives process restart'); memory.save(false);
  memory = freshMemory(); assert.equal(memory.initialize({}), false, 'confirmed logout stays add mode after restart'); assert.deepEqual([...disk.keys()], ['switchMode'], 'only presentation boolean is stored');
  const oneAccount = fixture(1); await oneAccount.service.read(); assert.equal(oneAccount.store.sessionAccountSwitchMode, false);
  const manyAccounts = fixture(2); await manyAccounts.service.read(); assert.equal(manyAccounts.store.sessionAccountSwitchMode, true);
  manyAccounts.failure('read'); await manyAccounts.service.read(); assert.equal(manyAccounts.store.sessionAccountSwitchMode, true, 'failed read never changes remembered mode');
  assert(ui.includes('.enabled($$.account.current || (!this.store.busy && !this.store.sessionSwitchUncertain))'), 'current account keeps normal theme colors');
  assert(ui.includes('if ($$.account.current) return;'), 'current account cannot trigger an operation');
  assert(ui.includes("Button(this.text('pm_add_account'), { type: ButtonType.Normal") && ui.includes('.height(48).borderRadius(16)'), 'add action matches existing settings button corners');
  const request = method('entry/src/main/ets/pages/Index.ets', '  private async requestAccountSettings(', '\n  @Builder\n  private boardRecoverySheet', 'async function(action: string, value: string)');
  const calls = []; const host = { nativeLoginEnabled: true, authStatus: 'authenticated', businessSuspended: false, profileSettingsVisible: true, settingsStore: { busy: false, sessionSwitchUncertain: false }, accountSwitchPending: false, authenticatedProfileUrl: origin + '/fixture_a/', resetAuthenticatedContent() { calls.push('reset'); }, openNativeLogin(value) { calls.push(['login', value]); } };
  await request.call(host, 'addAccount', ''); assert.equal(host.nativeAddingAccountProfile, origin + '/fixture_a/'); assert.deepEqual(calls, ['reset', ['login', undefined]]);
  calls.length = 0; host.settingsStore.sessionSwitchUncertain = true; await request.call(host, 'addAccount', ''); assert.equal(calls.length, 0);
  assert(isPinterestAuthRoute(origin + '/add-account/'));
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert(index.includes('this.nativeAddAccountFlow || this.loggedOutAccounts.active ? this.addAccountLoginScripts : this.loginScripts'), 'explicit add login and confirmed logout install secondary-account state');
  assert(index.includes("addAccountLoginScripts: ScriptItem[] = [{ script: PIN_ADD_ACCOUNT_LOGIN_SCRIPT, scriptRules: ['*'] },"), 'route initializer runs before auth and website scripts');
  assert(index.includes('...this.loginScripts]'), 'add login preserves normal auth and unsupported-provider guards');

  const logout = index.slice(index.indexOf('  private completeLogout()'), index.indexOf('  private startOpeningDetailRead('));
  assert(logout.includes('this.settingsStore.rememberAccountEntry(false);'), 'only confirmed logout resets presentation');
  const close = index.slice(index.indexOf('  private closeProfileSettings()'), index.indexOf('  private rootExitBackAt'));
  assert(!close.includes('sessionAccounts.read()'), 'settings return never rereads the account list');
  assert(index.includes('if (addedAccount) this.settingsStore.rememberAccountEntry(true);'), 'verified new account directly remembers switch mode');
  const differentAccount = method('entry/src/main/ets/pages/Index.ets', '  private isDifferentAddingAccount(', '\n  private startNativeVerification()', 'function(profileUrl: string)');
  const identityScope = { nativeAddingAccountProfile: origin + '/fixture_a/' };
  for (const candidate of ['', origin + '/fixture_a/', 'https://uk.pinterest.com/FIXTURE_A/', 'https://example.com/fixture_b/']) assert.equal(differentAccount.call(identityScope, candidate), false);
  assert.equal(differentAccount.call(identityScope, origin + '/fixture_b/'), true);
  function accountCallback(name) {
    const text = index.match(new RegExp(name + ': \\(message: PinmonyAuthMessage\\): void => \\{([\\s\\S]*?)\\n    \\},'))[1];
    const exports = {}; vm.runInNewContext(ts.transpileModule('exports.run = function(message: PinmonyAuthMessage) {' + text + '};', { compilerOptions: { target: 99, module: 1 } }).outputText, { exports, PinmonyRuntimeLog: { info() {} } }); return exports.run;
  }
  const webEvidence = accountCallback('verifyLoginEvidence'), nativeEvidence = accountCallback('accept');
  for (const pageUrl of [origin + '/login/', origin + '/add-account/', origin + '/']) {
    for (const profileUrl of ['', origin + '/fixture_a/', 'https://uk.pinterest.com/FIXTURE_A/', origin + '/fixture_b/']) {
      let starts = 0, accepted = 0;
      const h = { nativeAddAccountFlow: true, loginHostMounted: true, nativeAddingAccountProfile: origin + '/fixture_a/',
        isDifferentAddingAccount: differentAccount, authEpoch: 1, authStatus: 'unauthenticated', loginPageVisible: true,
        startNativeVerification() { starts++; }, sessionCoordinator: { updateAuthState() { accepted++; } } };
      const newIdentity = profileUrl.endsWith('/fixture_b/');
      webEvidence.call(h, { status: 'authenticated', profileUrl, pageUrl });
      assert.equal(starts, newIdentity ? 1 : 0, 'old, partial and redirected Web evidence cannot finish adding an account');
      h.loginPageVisible = false; h.authStatus = 'checking';
      nativeEvidence.call(h, { status: 'authenticated', profileUrl, pageUrl });
      assert.equal(accepted, newIdentity ? 1 : 0, 'native readback must also prove a different account');
      if (!newIdentity) { assert(h.loginPageVisible); assert.equal(h.authStatus, 'unauthenticated'); }
      h.loginHostMounted = false;
      nativeEvidence.call(h, { status: 'authenticated', profileUrl: origin + '/fixture_a/', pageUrl });
      assert.equal(accepted, newIdentity ? 2 : 1, 'explicit Back can restore the original account');
    }
  }
  const release = method('entry/src/main/ets/pages/Index.ets', '  private async releaseNativeLogin(', '\n  private handleNativeSessionExpired(', 'async function()', {
    webview: { WebCookieManager: { saveCookieAsync: async () => {} } }, AppStorage: { setOrCreate() {} },
    PinmonySessionHistory: { save: () => true }, PinmonyRuntimeLog: { info() {}, warn() {} }
  });
  for (const scenario of ['regular', 'canceled', 'same', 'added', 'backBeforeAdded', 'backBeforeSame', 'lateLogout', 'lateAccount', 'lateEpoch', 'background']) {
    let reads = 0, opens = 0; const tasks = [];
    const h = { isDifferentAddingAccount: differentAccount, nativeLoginEnabled: true, authStatus: 'authenticated', nativeSessionEpoch: 1, authEpoch: 1,
      nativeBusinessSessionContext: () => ({ authenticated: true, origin, generation: 1 }),
      nativeAddAccountFlow: scenario !== 'regular', nativeAddingAccountProfile: !['regular','canceled'].includes(scenario) ? origin + '/fixture_a/' : '',
      authenticatedProfileUrl: origin + (!['regular','canceled','same','backBeforeSame'].includes(scenario) ? '/fixture_b/' : '/fixture_a/'),
      settingsStore: { sessionAccountSwitchMode: false, rememberAccountEntry(value) { this.sessionAccountSwitchMode = value; } },
      coordinatorTasks: { timeout: task => tasks.push(task) }, openProfileSettings() { opens++; }, sessionAccounts: { read() { reads++; } } };
    if (['backBeforeAdded','backBeforeSame'].includes(scenario)) {
      const back = method('entry/src/main/ets/pages/Index.ets', '  onBackPress(): boolean', '\n  private handleRootExitBack()', 'function()');
      Object.assign(h, { authStatus: 'checking', sessionVerification: { cancel() {}, demand: async () => {} } });
      assert.equal(back.call(h), true);
      assert.equal(h.nativeAddingAccountProfile, origin + '/fixture_a/', 'Back retains original identity while final native probe owns the result');
      h.authStatus = 'authenticated';
    }
    await release.call(h);
    assert.equal(h.settingsStore.sessionAccountSwitchMode, !['regular','canceled','same','backBeforeSame'].includes(scenario), 'actual added identity updates memory without waiting for network');
    if (scenario === 'lateLogout') { h.authStatus = 'unauthenticated'; h.settingsStore.rememberAccountEntry(false); }
    if (scenario === 'lateAccount') h.authenticatedProfileUrl = origin + '/fixture_c/';
    if (scenario === 'lateEpoch') h.nativeSessionEpoch++;
    if (scenario === 'background') h.businessSuspended = true;
    tasks.forEach(task => task());
    assert.equal(reads, 0, 'settings presentation never triggers a session-account read');
    assert.equal(opens, ['canceled','same','added','backBeforeAdded','backBeforeSame'].includes(scenario) ? 1 : 0, 'stale and background callbacks cannot reopen settings');
    if (scenario === 'lateLogout') assert.equal(h.settingsStore.sessionAccountSwitchMode, false, 'late task cannot overwrite logout memory');
  }
  assert(index.includes('if (this.accountSwitchPending) context.authenticated = false;'));
  const openLogin = method('entry/src/main/ets/pages/Index.ets', '  private openNativeLogin(', '\n  private async releaseNativeLogin(', 'function()', {
    PinmonySessionHistory: { save() { return true; } }, PinmonyRuntimeLog: { info() {}, warn() {} },
    webview: { WebviewController: class {} }
  });
  for (const mounted of [false, true]) {
    const loaded = [], canceled = [];
    const login = { nativeLoginEnabled: true, nativeSessionOrigin: origin, nativeSessionEpoch: 3, authEpoch: 4,
      loginHostMounted: mounted, nativeAddAccountFlow: true, nativeAddingAccountProfile: origin + '/fixture_a/',
      sessionVerification: { cancel(reason) { canceled.push(reason); } }, loadSessionDocument(url) { loaded.push(url); },
      sessionAccounts: { read() { assert.fail('opening login must not read existing accounts'); } } };
    openLogin.call(login);
    assert.equal(login.loginStartUrl, origin + '/login/'); assert.equal(login.navigationAddress, origin + '/login/');
    assert.equal(login.loginPageVisible, true); assert.equal(login.loginDocumentLoading, true);
    assert.equal(login.loginHostMounted, true); assert.equal(login.authStatus, 'unauthenticated');
    assert.equal(login.nativeAddAccountFlow, true); assert.equal(login.nativeAddingAccountProfile, origin + '/fixture_a/');
    assert.deepEqual(loaded, mounted ? [origin + '/login/'] : []); assert.deepEqual(canceled, ['login-required']);
    assert.equal(login.nativeSessionEpoch, 4); assert.equal(login.authEpoch, 5);
  }
  assert(index.includes('this.nativeAddAccountFlow && this.loginHostMounted && !this.isDifferentAddingAccount(message.profileUrl)'));
  assert(index.includes("this.sessionVerification.cancel('add-account-back')"));
  console.log('Switch accounts: captured list/batch/write contracts, current email privacy, single/multiple entry, verified switch, unknown/no replay, background/cancellation, add-login and native layout passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
