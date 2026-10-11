const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name, lifecycle = false) {
  const start = source.indexOf('  ' + (lifecycle ? '' : 'private ') + name + '(');
  assert.ok(start >= 0, name);
  const rest = source.slice(start);
  const end = rest.slice(1).search(/\n  (?:private |onPage|@Storage|@Builder)/) + 1;
  return rest.slice(0, end);
}
const home = 'https://www.pinterest.com/', pin = home + 'pin/123/';
const timers = [];
const context = { Date, setTimeout(fn, delay) { timers.push({ fn, delay }); },
  PinmonyRuntimeLog: { info() {}, error() {}, warn() {}, flush() {return Promise.resolve();} }, retainHomePins: (_old, pins) => pins };
const methods = ['isCurrentPageFailure', 'protectedDetailAddress', 'handleMainFrameFailure', 'scheduleInterruptedHomeRecovery',
  'homePresentationPageKey', 'expectHome', 'updateHome'].map(name => method(name));
methods.push(method('onPageShow', true), method('onPageHide', true));
require('./product-coordination-harness.cjs').run(ts,ts.transpile('class Native {' + methods.join('\n') + '} globalThis.Native = Native;',
  { target: ts.ScriptTarget.ES2020 }), context);
function drainRecovery() {
  const pending = timers.splice(0);
  for (const timer of pending) if (timer.delay === 250) timer.fn();
}
function harness() {
  timers.length = 0;
  const native = new context.Native(), loads = [], effects = [];
  const cached = { pageKey: home, pins: [{ id: '123', pinUrl: pin, imageUrl: 'https://i.pinimg.com/a.jpg' }],
    selectedTab: 'feed', tabs: [{ id: 'feed', label: 'Feed', selected: true }, { id: 'other', label: 'Other' }], dataSource: 'api' };
  Object.assign(native, { authStatus: 'authenticated', authEpoch: 7, activeTab: 0, pendingWebTab: -1,
    navigationAddress: home, nativeBackTarget: '', pageBackToken: 0, homeRecoveryToken: 0,
    interruptedHomePage: '', homeRecoveryAttempted: false, loadFailed: false, rootTabAddresses: new Map(),
    homeStore: { home: cached, cachedHome: cached, homeActionsReady: true, homeRequestToken: 1 },
    pinStore: { videoForeground: true, detailPrefetch: { pause() { effects.push('pause'); } },
      confirmedSaves: { isSaved() { return false; } } },
    searchStore: { knownSearchPinTitles: new Map() }, profileStore: { origins: [] }, inboxStore: {}, boardStore: {},
    pageHistory: { key: url => url.split('#')[0], cancelBack() {} },
    nativeNetwork: { invalidate() { effects.push('invalidate'); } },
    staleRootDocumentTarget: () => -1, effectiveRootDocumentTarget: () => 0,
    rootTabIndexFromAddress: url => url === home ? 0 : -1,
    // This harness covers the existing fallback recovery; retained-root handling
    // is exercised with the real helper by check-home-return-failure.cjs.
    retainRootSnapshotAfterFailure: () => false,
    logPageLifecycle() {}, detailReadNetwork: { invalidate() {}, setForeground: () => false },
    rootActionContextReady: () => true,
    nativeDisplayAddress() { return this.nativeBackTarget || this.navigationAddress; },
    currentHomePageKey() { return this.navigationAddress === home ? home : ''; },
    homePageKeyFromAddress: url => url === home ? home : '', isHomeRootAddress: url => url === home,
    pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '', extractPinUrl: url => /\/pin\//.test(url) ? url : '',
    boardUrlFromAddress: () => '', searchUrlFromAddress: () => '', clearInbox() {}, clearSearch() {},
    clearHome() { this.homeStore.home = undefined; },
    clearDetail() { this.pinStore.detail = undefined; this.pinStore.detailOpeningPin = ''; },
    showNetworkNotice() {}, showMessage() {}, describeFailure: (_url, code) => 'error ' + code,
    requestHomeTitles() {}, tabsController: { changeIndex() {} },
    normalizeHomeBoard: () => undefined, persistHomeDiskCache() {},
    controller: { getUrl: () => home, loadUrl(url) { loads.push(url); }, runJavaScript: async () => 'true' } });
  native.searchStore = Object.assign(new searchRuntime.Store(), native.searchStore);
  searchRuntime.bindIndex(native);
  require('./home-controller-harness.cjs').createHomeRuntime(ts, context).bindIndex(native);
  require('./medium-priority-controller-harness.cjs').bindWork(native,ts,context);native.returnCoordinator={cancel(){}};require('./controller-lifecycle-harness.cjs').bind(native,ts);
  native.nativeNetwork.setForeground = () => false;
  return { native, cached, loads, effects };
}
const burst = harness();
for (let i = 0; i < 12; i++) burst.native.handleMainFrameFailure(home, i % 2 ? -21 : -103, 'handover');
assert.equal(burst.loads.length, 0, 'handover errors are debounced');
drainRecovery();
assert.deepEqual(burst.loads, [home], 'one read-only home navigation for a burst');
assert.equal(burst.native.homeStore.home, burst.cached, 'cards remain visible');
assert.equal(burst.native.homeStore.homeActionsReady, false, 'old controls remain disabled');
assert.ok(burst.effects.includes('invalidate'), 'old native reads are cancelled');
burst.native.handleMainFrameFailure(home, -103, 'still disconnected'); drainRecovery();
assert.equal(burst.loads.length, 1, 'failed recovery cannot loop');
assert.equal(burst.native.homeStore.homeError, '首页连接失败，请重试');
burst.native.onPageShow(); drainRecovery();
assert.equal(burst.loads.length, 1, 'duplicate show while foreground cannot rearm retries');
burst.native.onPageHide(); burst.native.onPageShow(); drainRecovery();
assert.equal(burst.loads.length, 2, 'a real foreground return allows one fresh recovery');

const background = harness();
background.native.handleMainFrameFailure(home, -21, 'changed'); background.native.onPageHide(); drainRecovery();
assert.deepEqual(background.loads, [], 'hide cancels queued recovery');
background.native.handleMainFrameFailure(home, -103, 'background'); drainRecovery();
assert.deepEqual(background.loads, [], 'no background reload');
background.native.onPageShow(); drainRecovery(); assert.deepEqual(background.loads, [home]);

for (const mutate of [n => { n.activeTab = 1; }, n => { n.pinStore.detailOpeningPin = pin; },
  n => { n.authEpoch++; }, n => { n.authStatus = 'unauthenticated'; },
  n => { n.pageBackToken++; }, n => { n.homeStore.homeRequestToken++; },
  n => { n.showNativeSheet = true; }, n => { n.homeStore.homeRefreshing = true; },
  n => { n.homeStore.cachedHome = undefined; }]) {
  const changed = harness(); changed.native.handleMainFrameFailure(home, -21, 'changed');
  mutate(changed.native); drainRecovery(); assert.deepEqual(changed.loads, [], 'stale or obstructed target cannot reload');
}
for (const [url, code] of [[pin, -21], [pin, -103], [home, -2], [home, -200]]) {
  const ignored = harness(); ignored.native.handleMainFrameFailure(url, code, 'failure'); drainRecovery();
  assert.deepEqual(ignored.loads, [], 'obsolete Pin and unrelated errors retain existing handling');
}
const throwing = harness(); throwing.native.controller.loadUrl = () => { throw new Error('unavailable'); };
throwing.native.handleMainFrameFailure(home, -21, 'changed'); drainRecovery();
assert.equal(throwing.native.homeStore.home, throwing.cached);
assert.equal(throwing.native.homeStore.homeError, '首页连接失败，请重试');
assert.equal(throwing.native.authStatus, 'authenticated', 'network failure does not log out');

function snapshot(native, changes = {}) {
  native.updateHome(JSON.stringify({ ...native.homeStore.cachedHome, kind: 'state', session: 2,
    sourceError: '', refreshing: false, ...changes }));
}
const ready = harness(); ready.native.handleMainFrameFailure(home, -21, 'changed');
snapshot(ready.native, { sourceError: 'read failed' });
assert.equal(ready.native.interruptedHomePage, home, 'error-bearing data cannot confirm recovery');
snapshot(ready.native, { refreshing: true });
assert.equal(ready.native.interruptedHomePage, home, 'incomplete refresh cannot confirm recovery');
snapshot(ready.native);
assert.equal(ready.native.interruptedHomePage, '', 'validated current API data confirms recovery');
drainRecovery(); assert.deepEqual(ready.loads, [], 'successful snapshot cancels queued reload');
ready.native.handleMainFrameFailure(home, -21, 'new handover'); drainRecovery();
assert.deepEqual(ready.loads, [home], 'successful read rearms a future network-change episode');
const session=fs.readFileSync('entry/src/main/ets/app/PinmonySessionCoordinator.ets','utf8');
assert.match(session,/setInterruptedHomePage\(''\)/);assert.match(session,/setHomeRecoveryAttempted\(false\)/);assert.match(session,/setHomeRecoveryToken\(this\.ports\.homeRecoveryToken\(\) \+ 1\)/);
console.log('Home network recovery: error burst, foreground, bounded retry, retained feed, target/session guards and validated recovery passed');
