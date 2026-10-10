const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert.ok(start >= 0, name);
  const rest = source.slice(start);
  const end = rest.slice(1).search(/\n  (?:private |@Builder)/) + 1;
  return rest.slice(0, end);
}
const home = 'https://www.pinterest.com/', pin = home + 'pin/123/', other = home + 'pin/456/';
const context = { PIN_HOME_API_ENABLED: true, PINTEREST_URL: home, Date, setTimeout() {},
  isPinterestAuthRoute: url => /\/login\//.test(url), PinmonyRuntimeLog: { info() {}, warn() {}, error() {} } };
vm.runInNewContext(ts.transpile('class Native {' + ['isCurrentPageFailure', 'handleMainFrameFailure',
  'homePresentationPageKey', 'refreshHome', 'selectNativeRootTab', 'rootPresentationAddress',
  'staleRootDocumentTarget', 'effectiveRootDocumentTarget', 'rootTabIndexFromAddress',
  'retainRootSnapshotAfterFailure', 'protectedDetailAddress'].map(method).join('\n') + '} globalThis.Native = Native;',
  { target: ts.ScriptTarget.ES2020 }), context);
function harness() {
  const native = new context.Native(), effects = [], loads = [];
  const cached = { pageKey: home, pins: [{ id: '123' }], dataSource: 'api' };
  let webUrl = pin;
  Object.assign(native, { authStatus: 'authenticated', activeTab: 0, pendingWebTab: -1,
    navigationAddress: home, nativeBackTarget: home, lastPageUrl: home, webPageLoading: true,
    retainedRootTabPending: -1, rootTabGuardTarget: -1, rootTabAddresses: new Map(),
    homeStore: { home: cached, cachedHome: cached, homeActionsReady: false, homeRequestToken: 1, homeRefreshToken: 1 },
    pinStore: { detailReturnUrl: home }, searchStore: {}, profileStore: { origins: [] }, inboxStore: {}, boardStore: {},
    boardUrlFromAddress: () => '',
    pageHistory: { key: url => url.split('#')[0], cancelBack() { effects.push('cancel'); } },
    showNetworkNotice() { effects.push('notice'); }, showMessage() {}, clearInbox() { effects.push('inbox'); },
    clearHome() { this.homeStore.home = undefined; effects.push('clearHome'); }, clearSearch() {},
    clearDetail() { this.pinStore.detail = undefined; this.pinStore.detailOpeningPin = ''; },
    pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '', extractPinUrl: url => /\/pin\//.test(url) ? url : '',
    homePageKeyFromAddress: url => url === home ? home : '', searchUrlFromAddress: () => '',
    inboxUrlFromAddress: () => '', profileUrlFromAddress: () => '', rejectOfflineAction: () => false,
    finishProfilePull() {}, tryEnterOfflinePreview: () => false, homeRecoveryToken: 0,
    nativeDisplayAddress() { return this.nativeBackTarget || webUrl; }, isHomeRootAddress: url => url === home,
    currentHomePageKey: () => webUrl === home ? home : '', tabsController: { changeIndex() {} },
    describeFailure: (_url, code) => 'error ' + code,
    requestRootPage(index) { assert.equal(index,0); loads.push(home); },
    controller: { loadUrl(url) { loads.push(url); } } });
  native.searchStore = Object.assign(new searchRuntime.Store(), native.searchStore);
  searchRuntime.bindIndex(native);
  require('./home-controller-harness.cjs').createHomeRuntime(ts, context).bindIndex(native);
  return { native, cached, effects, loads, setWeb: url => { webUrl = url; } };
}
const returned = harness();
returned.native.handleMainFrameFailure(pin, -2, 'ERR_FAILED');
assert.deepEqual(returned.effects, [], 'abandoned Pin failure cannot cancel home return or clear any current state');
assert.equal(returned.native.homeStore.home, returned.cached);
assert.equal(returned.native.webPageLoading, true);
assert.equal(returned.native.authStatus, 'authenticated');
assert.equal(returned.native.homePresentationPageKey(), home);
const confirmed = harness();
confirmed.native.nativeBackTarget = ''; confirmed.setWeb(home);
confirmed.native.handleMainFrameFailure(pin, -2, 'ERR_FAILED');
assert.deepEqual(confirmed.effects, [], 'late failure remains obsolete after home route confirmation');
const reopened = harness();
reopened.native.nativeBackTarget = ''; reopened.native.pinStore.detailOpeningPin = other;
reopened.native.navigationAddress = other; reopened.setWeb(other);
reopened.native.handleMainFrameFailure(pin, -2, 'ERR_FAILED');
assert.deepEqual(reopened.effects, [], 'failure from Pin A cannot erase newly opened Pin B');
assert.equal(reopened.native.pinStore.detailOpeningPin, other);
const failedHome = harness();
failedHome.native.handleMainFrameFailure(home, -2, 'ERR_FAILED');
assert.ok(failedHome.effects.includes('notice'), 'actual target failure remains visible');
assert.equal(failedHome.native.homeStore.home, failedHome.cached);
assert.equal(failedHome.native.homeStore.homeActionsReady, false);
assert.equal(failedHome.native.homeStore.homeError, 'error -2', 'retained root reports the current classified failure');
assert.equal(failedHome.native.loadFailed, false);
assert.equal(failedHome.native.homePresentationPageKey(), home, 'home remains presented despite Web still reporting Pin');
failedHome.native.refreshHome();
assert.deepEqual(failedHome.loads, [home], 'manual retry loads visible home instead of refreshing failed Pin');
const failedPin = harness();
failedPin.native.nativeBackTarget = ''; failedPin.native.navigationAddress = pin;
failedPin.native.pinStore.detailOpeningPin = pin;
failedPin.native.handleMainFrameFailure(pin, -2, 'ERR_FAILED');
assert.equal(failedPin.native.pinStore.detailOpeningPin, '');
assert.equal(failedPin.native.homePresentationPageKey(), home, 'failed uncached detail leaves a visible parent, not an orphaned Pin route');
assert.equal(failedPin.native.authStatus, 'authenticated', 'transport failure is not logout');
const firstLogin = harness(); firstLogin.native.authStatus = 'checking';
firstLogin.native.handleMainFrameFailure(home + 'login/', -2, 'ERR_FAILED');
assert.equal(firstLogin.native.authStatus, 'error');
assert.equal(firstLogin.native.loadFailed, true, 'real initial login failure retains its error state');
for (const index of [0, 2]) {
  const next = harness(); next.native.handleMainFrameFailure(home, -2, 'ERR_FAILED');
  const target = index === 0 ? home : home + 'inbox/';
  Object.assign(next.native, { currentWebTab: 0, tabRequestToken: 0, pageBackToken: 0,
    rootTabAddresses: new Map([[index, target]]), traceAction() {}, expectInbox() {},
    inboxUrlFromAddress: url => url === home + 'inbox/' ? url : '', waitForWebTabConfirmation() {} });
  next.native.pageHistory.visit = () => {};
  next.native.controller.getUrl = () => pin;
  Object.assign(next.native, { logPageLifecycle() {}, cancelHomeDetailMore() {}, syncFloatingTabsMotion() {},
    restoreInbox() {}, boardStore: { boardOpeningToken: 0 } });
  next.native.selectNativeRootTab(index);
  assert.equal(next.native.nativeBackTarget, '', 'tab selection supersedes failed return presentation');
  assert.deepEqual(next.loads, [], 'home reselect and another root tab only change native presentation');
  assert.equal(next.native.pageBackToken, 1, 'superseded return timer cannot affect the selected tab');
}
const status = source.slice(source.indexOf('  private buildRootStatus('), source.indexOf('  private buildRootError('));
assert.ok(status.includes('this.extractPinUrl(this.nativeDisplayAddress())'), 'root status follows native presentation, not abandoned Web Pin');
console.log('Home return failure: obsolete callbacks, rapid reopen, retained feed, real error, manual retry and login boundary passed');
