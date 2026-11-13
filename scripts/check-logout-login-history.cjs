const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const disk = new Map(), memory = new Map();
let failStorage = false;
const preference = {
  getSync(key, fallback) { return disk.has(key) ? disk.get(key) : fallback; },
  putSync(key, value) { if (failStorage) throw Error('synthetic write failure'); disk.set(key, value); },
  flushSync() { if (failStorage) throw Error('synthetic flush failure'); }
};
const AppStorage = { get: key => memory.get(key), setOrCreate: (key, value) => memory.set(key, value) };
function history() {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_session/src/main/ets/services/PinmonySessionHistory.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, AppStorage, require: () => ({ preferences: { getPreferencesSync: () => preference } }) });
  exports.PinmonySessionHistory.initialize({});
  return exports.PinmonySessionHistory;
}
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0);
  const tail = source.slice(start);
  return tail.slice(0, tail.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { PinmonyLoggedOutAccounts } = createArktsLoader(ts).loadFile('feature_settings/src/main/ets/services/PinmonyLoggedOutAccounts.ets');
let SessionHistory = history();
const globals = {
  AppStorage, PinmonySessionHistory: { requireManualLogin: () => SessionHistory.requireManualLogin(), save: value => SessionHistory.save(value) },
  PinmonyRuntimeLog: { info() {}, warn() {} }, connection: { hasDefaultNetSync: () => true },
  PINTEREST_LOGIN_URL: 'https://www.pinterest.com/login/',
  webview: { WebviewController: class {} }
};
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + ['startNativeVerification', 'openNativeLogin', 'completeLogout'].map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, globals);
function fixture() {
  let demands = 0;
  const host = new Host();
  host.loggedOutAccounts = new PinmonyLoggedOutAccounts({ available: () => true, epoch: () => 1, userAgent: () => 'fixture', network: () => ({}), confirmed() { throw Error('passive authentication forbidden'); } });
  Object.assign(host, {
    nativeLoginEnabled: true, businessSuspended: false, nativeVerificationPending: false,
    nativeSessionEpoch: 1, authEpoch: 1, authStatus: 'authenticated', nativeSessionOrigin: 'https://www.pinterest.com',
    loginHostMounted: false, nativeAddAccountFlow: false,
    sessionVerification: { cancel() {}, demand() { demands++; return Promise.resolve(); } },
    settingsStore: { rememberAccountEntry() {} }, resetAuthenticatedContent() {},
    sessionEnvironment: { userAgent: () => 'fixture' }, coordinatorTasks: { timeout() {} }
  });
  return { host, demands: () => demands };
}
SessionHistory.save(true);
const loggedOut = fixture(); loggedOut.host.completeLogout();
assert.equal(disk.get('manual_login_required'), true);
assert.equal(disk.get('confirmed'), false);
assert.equal(loggedOut.host.authStatus, 'unauthenticated');
// A new JS/module instance and empty process memory model a restart with website cookies still present.
memory.clear(); SessionHistory = history();
const restarted = fixture(); restarted.host.startNativeVerification();
assert.equal(restarted.demands(), 0, 'explicit logout cannot silently probe and log in to remaining cookies');
assert.equal(restarted.host.authStatus, 'unauthenticated');
assert.equal(restarted.host.loginStartUrl, 'https://www.pinterest.com/login/');
assert.equal(restarted.host.loggedOutAccounts.active, true);
assert.equal(restarted.host.loggedOutAccounts.acceptsWebLogin(), false, 'passive website evidence remains blocked after restart');
restarted.host.loggedOutAccounts.allowManualLogin();
assert.equal(restarted.host.loggedOutAccounts.acceptsWebLogin(), true);
assert.equal(disk.get('manual_login_required'), true, 'touching the login form cannot clear the persistent intent');
SessionHistory.save(false); memory.clear(); SessionHistory = history();
assert.equal(memory.get('pinmonyManualLoginRequired'), true, 'loading login or another restart retains the intent');
SessionHistory.save(true); memory.clear(); SessionHistory = history();
assert.equal(memory.get('pinmonyManualLoginRequired'), false, 'confirmed login restores ordinary startup reuse');
assert.equal(memory.get('pinmonySessionConfirmed'), true);
const signedIn = fixture(); signedIn.host.startNativeVerification(); assert.equal(signedIn.demands(), 1);
disk.delete('manual_login_required'); disk.set('confirmed', false); memory.clear(); SessionHistory = history();
assert.equal(memory.get('pinmonyManualLoginRequired'), true, 'legacy unconfirmed history defaults to explicit login');
disk.set('manual_login_required', false); disk.set('confirmed', false); memory.clear(); SessionHistory = history();
assert.equal(memory.get('pinmonyManualLoginRequired'), true, 'unconfirmed history wins over a stale false manual-login marker');
const contradictory = fixture(); contradictory.host.startNativeVerification();
assert.equal(contradictory.demands(), 0); assert.equal(contradictory.host.loggedOutAccounts.acceptsWebLogin(), false);
failStorage = true; assert.equal(SessionHistory.requireManualLogin(), false);
assert.equal(SessionHistory.save(true), false);
assert.equal(memory.get('pinmonySessionConfirmed'), false, 'a failed save cannot advertise reusable confirmed history');
assert.equal(memory.get('pinmonyManualLoginRequired'), true, 'storage failure must still keep the current process gated');
assert([...disk.keys()].every(key => ['confirmed', 'manual_login_required'].includes(key)), 'only non-credential booleans are persisted');
console.log('PASS explicit logout history: process restart, passive auth gate, login route, manual interaction, confirmed login, legacy migration and storage failure');
