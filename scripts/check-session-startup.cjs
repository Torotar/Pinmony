const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const home = 'https://www.pinterest.com/', login = home + 'login/';
const auth = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_session/src/main/ets/models/PinmonyAuth.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, { exports: auth });
const context = { ...auth, PINTEREST_URL: home, PINTEREST_LOGIN_URL: login,
  PinmonyRuntimeLog: { info() {}, warn() {} }, clearTimeout() {} };
vm.runInNewContext(ts.transpile('class Native {' + ['updateAuthState', 'retryLogin', 'authWebVisible', 'describeFailure'].map(method).join('\n') +
  '} globalThis.Native=Native;', { target: ts.ScriptTarget.ES2020 }), context);
function harness() {
  const native = new context.Native(), loads = [], scripts = [], effects = [];
  let current = home;
  Object.assign(native, { authStatus: 'checking', authEpoch: 1, authCheckTimer: -1, loginRedirectEpoch: -1,
    navigationAddress: '', controller: { getUrl: () => current, loadUrl: url => loads.push(url),
      runJavaScript: script => { scripts.push(script); return Promise.resolve(true); } },
    pageHistory: { reset() {} }, tabsController: { changeIndex() {} },
    isHomeRootAddress: url => url === home, profileUrlFromAddress: () => '',
    homeCacheAccountIdFromProfileUrl: () => '', homePageKeyFromAddress: url => url === home ? home : '',
    tryRestoreAuthenticatedHome() {},
    expectHome() { effects.push('home'); }, refreshWebNavigation() {}, bindNativeNetwork() { effects.push('bind'); },
    resetAuthenticatedContent() { effects.push('clear'); }, configureDocumentRetention() {} });
  return { native, loads, scripts, effects, setUrl(url) { current = url; native.navigationAddress = url; },
    emit(status, epoch = native.authEpoch) {
      native.updateAuthState(JSON.stringify({ status, epoch, pageUrl: current, profileUrl: '' }));
    } };
}
assert.ok(source.includes('Web({ src: PINTEREST_URL, controller: this.controller })'), 'cold start requests home, not login');
assert.ok(!source.includes('Web({ src: PINTEREST_LOGIN_URL'), 'no unconditional login document at startup');
const existing = harness();
assert.equal(existing.native.authWebVisible(), false, 'unknown startup never exposes the business website');
assert.equal(existing.native.authStatus, 'checking', 'home URL alone does not authenticate');
existing.emit('authenticated');
assert.equal(existing.native.authStatus, 'authenticated');
assert.deepEqual(existing.loads, [], 'current authenticated home needs no second navigation');
assert.ok(existing.effects.includes('home')); assert.ok(existing.effects.includes('bind'));
existing.emit('authenticated');
assert.deepEqual(existing.loads, [], 'duplicate confirmation cannot reopen login or home');
assert.equal(existing.scripts.filter(script => script.includes('PinmonyHomeRefresh')).length, 1, 'first native home sync is not repeated');
const guest = harness();
guest.emit('unauthenticated', 0); assert.deepEqual(guest.loads, [], 'old document evidence cannot open login');
guest.emit('unauthenticated'); guest.emit('unauthenticated'); guest.emit('unauthenticated');
assert.deepEqual(guest.loads, [login], 'explicit guest evidence queues one login navigation per document');
guest.setUrl(login); guest.native.authEpoch++;
guest.emit('unauthenticated'); assert.equal(guest.loads.length, 1, 'login document is already the destination');
assert.equal(guest.native.authWebVisible(), true, 'real login remains visible for the guest');
guest.emit('authenticated');
assert.deepEqual(guest.loads, [login, home], 'successful real login enters home once');
assert.equal(guest.native.loginRedirectEpoch, -1, 'successful session permits future real expiry handling');
guest.setUrl(home); guest.native.authEpoch++; guest.emit('unauthenticated');
assert.deepEqual(guest.loads, [login, home, login], 'new explicit session expiry still opens login');
assert.ok(guest.effects.includes('clear'), 'expired session clears native account content');
const failedHome = harness(); failedHome.native.authStatus = 'error'; failedHome.native.retryLogin();
assert.deepEqual(failedHome.loads, [home], 'unconfirmed home failure retries session reading, not login');
const failedLogin = harness(); failedLogin.setUrl(login); failedLogin.native.authStatus = 'error'; failedLogin.native.retryLogin();
assert.deepEqual(failedLogin.loads, [login], 'manual retry of an actual login failure retains login');
const explicitGuest = harness(); explicitGuest.native.authStatus = 'unauthenticated'; explicitGuest.native.retryLogin();
assert.deepEqual(explicitGuest.loads, [login], 'known guest retains the real login entry');
const loggingOut = harness(); loggingOut.native.authStatus = 'unauthenticated'; loggingOut.native.logoutAwaitingLogin = true;
loggingOut.emit('authenticated');
assert.equal(loggingOut.native.authStatus, 'unauthenticated', 'old document authentication cannot undo confirmed logout before login navigation');
assert.deepEqual(loggingOut.loads, []);
assert.match(explicitGuest.native.describeFailure(login, -113), /HTTPS 安全连接协商失败/, 'TLS error is described as a connection error, not login quota');
console.log('Session startup: home-first, explicit evidence, one login redirect, stored-session reuse, expiry and manual retry boundaries passed');
