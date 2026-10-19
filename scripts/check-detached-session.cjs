const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const events = [], storage = new Map();
const log = { info: m => events.push(m), warn: m => events.push(m) };
function load(path, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: deps, console }); return exports;
}
const session = { ...load('common_session/src/main/ets/models/PinmonyAuth.ets'),
  ...load('common_session/src/main/ets/models/PinmonySessionVerification.ets') };
const { PinmonyBusinessSession } = load('common_session/src/main/ets/services/PinmonyBusinessSession.ets');
const { PinmonySessionEnvironment } = load('common_session/src/main/ets/services/PinmonySessionEnvironment.ets');
const { PinmonySessionVerification } = load('entry/src/main/ets/app/PinmonySessionVerification.ets', name =>
  name === 'common_session' ? session : { PinmonyRuntimeLog: log });
const { PinmonySessionCoordinator } = load('entry/src/main/ets/app/PinmonySessionCoordinator.ets', name =>
  name === 'common_session' ? session : { PinmonyRuntimeLog: log });
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(source.includes('private readonly nativeLoginEnabled: boolean = PIN_NATIVE_LOGIN_LIFECYCLE_ENABLED && this.nativeBusinessRoutesEnabled;'),
  'ArkUI must receive an initialized field; a struct getter is stripped by its compiler');
const home = 'https://www.pinterest.com/', login = home + 'login/';
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\(')); assert(start >= 0, name);
  const rest = source.slice(start); const end = rest.slice(1).search(/\n  (?:private |@Builder)/) + 1;
  return rest.slice(0, end);
}
const rawCalls = [];
class Controller {
  constructor() { this.url = login; }
  getUrl() { rawCalls.push('url'); return this.url; }
  loadUrl(url) { rawCalls.push('load'); this.url = url; }
  runJavaScript() { rawCalls.push('script'); return Promise.resolve(''); }
}
let saveCookies = () => Promise.resolve();
let online = true;
const globals = { connection: {hasDefaultNetSync: () => online}, webview: { WebviewController: Controller, WebCookieManager: {saveCookieAsync: () => saveCookies()} }, PinmonyRuntimeLog: log,
  PINTEREST_LOGIN_URL: login, PIN_NATIVE_HOME_READS_ENABLED: false, PIN_NATIVE_SEARCH_DISCOVERY_ENABLED: false,
  AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) } };
const names = ['sessionDocumentUrl','runSessionScript','loadSessionDocument','startNativeVerification',
  'openNativeLogin','releaseNativeLogin','handleNativeSessionExpired','updateAuthState','syncAuthentication',
  'retryLogin','confirmBusinessSession','nativeBusinessSessionContext','enterAuthenticatedRoot'];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + names.map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, globals);
function productionPorts(name, type) {
  const binding = source.match(new RegExp('private readonly ' + name + ': ' + type + ' = new ' + type + '\\(\\{([\\s\\S]*?)\\}\\)?(?: as ' + type + 'Ports)?\\);'));
  // Session coordinator has a cast inside its constructor; verification does not.
  const match = binding || source.match(new RegExp('private readonly ' + name + ': ' + type + ' = new ' + type + '\\(\\{([\\s\\S]*?)\\} as ' + type + 'Ports\\);'));
  assert(match, name); const out = {};
  vm.runInNewContext(ts.transpileModule('export function ports(){return {' + match[1] + '};}', {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports: out, ...globals }); return out.ports;
}
const sessionPorts = productionPorts('sessionCoordinator','PinmonySessionCoordinator');
const verificationPorts = productionPorts('sessionVerification','PinmonySessionVerification');
function fixture() {
  storage.set('pinmonySessionConfirmed', true);
  const host = new Host(), jobs = [], timers = [];
  const stores = ['home','profile','inbox','pin','board','settings'];
  for (const name of stores) host[name + 'Store'] = {};
  for (const name of ['boardNativeReads','profileNativeReads','inboxUpdatesNativeReads','inboxMessagesNativeReads','searchNativeReads']) host[name] = { reset() {} };
  Object.assign(host, { nativeLoginEnabled: true, nativeBusinessRoutesEnabled: true, loginHostMounted: false,
    authStatus: 'checking', authEpoch: 0, nativeSessionEpoch: 0, nativeVerificationPending: false,
    nativeLoginEvidenceKey: '', nativeSessionOrigin: 'https://www.pinterest.com', businessSuspended: false,
    controller: new Controller(), sessionEnvironment: new PinmonySessionEnvironment(), businessSession: new PinmonyBusinessSession(),
    homeCacheAccountId: '', authenticatedProfileUrl: '', authCheckTimer: -1, rootTabAddresses: new Map(),
    coordinatorTasks: { timeout(fn, delay) { timers.push({ fn, delay }); } }, pageTasks: { cancelTimeout() {} },
    tabsController: { changeIndex() {} }, pageHistory: { reset() {} }, bottomBarCoordinator: { resetForSession() {} },
    syncFloatingTabsMotion() {}, homePageKeyFromAddress: u => /^https:\/\/(?:www|uk)\.pinterest\.com\/$/.test(u) ? u : '',
    homeCacheAccountIdFromProfileUrl: u => u ? 'synthetic-account' : '', tryRestoreAuthenticatedHome() {},
    profileUrlFromAddress: u => /^https:\/\/(?:www|uk)\.pinterest\.com\/[A-Za-z0-9_]+\/$/.test(u) ? u : '',
    isHomeRootAddress: u => u === home, configureDocumentRetention() { throw Error('Web retention forbidden'); },
    bindNativeNetwork() { throw Error('document transport forbidden'); },
    resetAuthenticatedContent() { this.businessSession.reset(); this.authenticatedProfileUrl = ''; },
    nativeNetwork: { cancel() {}, verifySession(origin, ua, epoch, id, owner) {
      assert.equal(ua, 'fixture-agent'); assert(owner());
      return new Promise(resolve => jobs.push({ origin, epoch, owner, resolve }));
    } } });
  host.sessionEnvironment.capture('fixture-agent');
  host.sessionCoordinator = new PinmonySessionCoordinator(sessionPorts.call(host));
  host.sessionVerification = new PinmonySessionVerification(verificationPorts.call(host));
  return { host, jobs, timers };
}
const flush = () => new Promise(resolve => setImmediate(resolve));
function reply(status = 'authenticated') {
  return { status: 200, error: '', body: JSON.stringify({ client_context: { is_authenticated: status === 'authenticated',
    user: status === 'authenticated' ? { id: '123', username: 'fixture_user' } : undefined, app_version: 'fixture.2' },
    resource_response: { status: 'success', code: 0, endpoint_name: 'v3_get_user_settings',
      data: { id: '123', username: 'fixture_user', type: 'user_settings' } } }) };
}
async function main() {
  let guest = fixture(); storage.delete('pinmonySessionConfirmed'); guest.host.startNativeVerification();
  assert.equal(guest.jobs.length,0,'first use and legacy upgrades open login without relying on arbitrary visitor cookies');
  assert.equal(guest.host.loginHostMounted,true); assert.equal(guest.host.authStatus,'unauthenticated');
  assert.equal(storage.get('pinmonySessionConfirmed'),false);
  let f = fixture(); rawCalls.length = 0; f.host.startNativeVerification();
  f.host.authEpoch += 100; // Web document lifetime is unrelated to this attempt.
  f.jobs[0].resolve(reply()); await flush();
  assert.equal(f.host.authStatus, 'authenticated'); assert.equal(f.host.loginHostMounted, false);
  assert.equal(f.host.nativeRootOnly, true, JSON.stringify(events)); assert.equal(f.host.navigationAddress, home);
  assert.equal(rawCalls.length, 0, 'cold-start confirmation never reads or navigates a Web document');
  assert.equal(f.host.businessSession.context('authenticated').appVersion, 'fixture.2');
  assert(events.includes('NativeSession: cookie store saved'));
  assert.equal(storage.get('pinmonySessionConfirmed'),true,'only current validated identity and saved cookies establish startup reuse');
  f.host.updateAuthState(JSON.stringify({ status: 'unauthenticated', pageUrl: home, epoch: f.host.authEpoch }));
  assert.equal(f.host.authStatus, 'authenticated', 'a released host cannot change native authentication');
  f = fixture(); f.host.startNativeVerification(); f.jobs[0].resolve({ status: 0, error: 'missing-session', body: '' }); await flush();
  assert.equal(f.host.loginHostMounted, true); assert.equal(f.host.authStatus, 'unauthenticated');
  const firstController = f.host.controller;
  f.host.updateAuthState(JSON.stringify({ status: 'unauthenticated', pageUrl: login, epoch: f.host.authEpoch, profileUrl: '' }));
  assert.equal(f.host.controller, firstController, 'guest evidence on the login page does not reload/remount forever');
  f.host.updateAuthState(JSON.stringify({ status: 'authenticated', pageUrl: login, epoch: f.host.authEpoch, profileUrl: home + 'fixture_user/' }));
  assert.equal(f.host.authStatus, 'checking', 'Web success requires native confirmation');
  f.host.updateAuthState(JSON.stringify({ status: 'unauthenticated', pageUrl: login, epoch: f.host.authEpoch, profileUrl: '' }));
  assert.equal(f.host.authStatus, 'checking', 'late Web guest evidence cannot cancel the independent native confirmation');
  f.host.authEpoch++; f.host.controller.url = home; f.jobs[1].resolve(reply()); await flush();
  assert.equal(f.host.authStatus, 'authenticated'); assert.equal(f.host.loginHostMounted, false);
  const generation = f.host.nativeBusinessSessionContext().generation;
  f.host.handleNativeSessionExpired('https://www.pinterest.com', generation - 1);
  f.timers.filter(t => t.delay === 0).splice(0).forEach(t => t.fn()); assert.equal(f.host.loginHostMounted, false);
  f.host.handleNativeSessionExpired('https://www.pinterest.com', generation);
  f.timers.filter(t => t.delay === 0).forEach(t => t.fn()); assert.equal(f.host.loginHostMounted, true);
  assert.notEqual(f.host.controller, firstController, 'each login gets a distinct controller to reject retired host callbacks');
  assert.equal(storage.get('pinmonySessionConfirmed'),false,'explicit expiry returns future launches to login');
  f = fixture(); f.host.startNativeVerification(); f.jobs[0].resolve({ status: 0, error: 'network-unavailable', body: '' }); await flush();
  assert.equal(f.host.authStatus, 'error'); assert.equal(f.host.loginHostMounted, false, 'network failure is not logout or automatic Web fallback');
  f.host.retryLogin(); assert.equal(f.jobs.length, 2); f.jobs[1].resolve(reply()); await flush(); assert.equal(f.host.authStatus, 'authenticated');
  f = fixture(); f.host.startNativeVerification(); f.timers.find(t => t.delay === 15000).fn();
  assert.equal(f.host.authStatus, 'error'); assert.equal(f.jobs[0].owner(), false);
  f.jobs[0].resolve(reply()); await flush(); assert.equal(f.host.authStatus, 'error', 'timed-out identity cannot restore the account');
  let completeSave;
  saveCookies = () => new Promise(resolve => {completeSave = resolve;});
  f = fixture(); f.host.loginHostMounted = true; f.host.startNativeVerification();
  f.jobs[0].resolve(reply()); await flush();
  assert.equal(f.host.loginHostMounted,true,'keep the login host until ArkWeb cookie persistence completes');
  f.host.nativeSessionEpoch++; f.host.authStatus = 'unauthenticated'; completeSave(); await flush();
  assert.equal(f.host.loginHostMounted,true,'a stale save completion cannot release a newer login host');
  saveCookies = () => Promise.reject(Error('synthetic persistence error'));
  f = fixture(); storage.set('pinmonySessionConfirmed',false); f.host.loginHostMounted = true; f.host.startNativeVerification(); f.jobs[0].resolve(reply()); await flush();
  assert.equal(f.host.loginHostMounted,true,'failed persistence must not claim release success');
  assert.equal(storage.get('pinmonySessionConfirmed'),false,'failed persistence cannot enable silent reuse');
  assert(events.includes('NativeSession: cookie store save unavailable'));
  online = false; saveCookies = () => Promise.resolve(); f = fixture(); f.host.startNativeVerification();
  assert.equal(f.jobs.length,0,'offline startup does not dispatch a request or wait for timeout');
  assert.equal(f.host.authStatus,'error'); assert.equal(f.host.loginHostMounted,false);
  assert(f.host.failureDetails.includes('无网络'));
  online = true; f.host.retryLogin(); assert.equal(f.jobs.length,1); f.jobs[0].resolve(reply()); await flush();
  assert.equal(f.host.authStatus,'authenticated','manual retry after reconnect uses the existing Cookie store');
  console.log('Detached session: native startup, no Web calls, separate attempt epoch, login confirmation/release, missing cookies, network retry, expiry, persistence, offline and timeout passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
