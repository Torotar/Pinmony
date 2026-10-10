const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const rest = source.slice(start);
  const end = rest.slice(1).search(/\n  (?:private |@Builder)/) + 1;
  return rest.slice(0, end);
}
function bridge(name) {
  const start = source.indexOf('    this.shareBridge.' + name + ' =');
  return source.slice(start, source.indexOf('\n    };', start) + 7);
}
const names = ['rootPresentationAddress', 'selectNativeRootTab', 'rootReadInFlight', 'requestRootPage', 'prepareRootPageRead',
  'clearDetail', 'closeImageLayer',
  'scheduleInterruptedHomeRecovery',
  'clearRootTabGuard', 'nativeRootPageAddress', 'nativeDisplayAddress', 'currentPinUrl', 'currentHomePageKey',
  'updateDetail', 'updateBoard', 'syncNativeReturnRoute', 'recordPageNavigation',
  'protectedDetailAddress', 'ignoreSupersededDetailDocument'];
const setup = ['onNavigation', 'onPageNavigation'].map(bridge).join('\n');
const beginStart = source.indexOf('.onPageBegin((event) => {');
const beginEnd = source.indexOf('\n            .onPageEnd(', beginStart);
const begin = source.slice(beginStart, beginEnd).replace(/^\.onPageBegin\(/, 'this.pageBegin = ').replace(/\)\s*$/, ';');
const context = { PINTEREST_URL: 'https://www.pinterest.com/', isPinterestAuthRoute: url => /\/login\//.test(url),
  PinmonyRuntimeLog: { info() {}, warn() {} } };
const code = 'class Native {' + names.map(method).join('\n') + '\nsetup() {' + setup + begin + '} } globalThis.Native = Native;';
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
const home = context.PINTEREST_URL, pin = home + 'pin/123/', profile = home + 'sample/';
function harness() {
  const native = new context.Native(), requests = [], indices = [], confirmations = [];
  let document = pin;
  Object.assign(native, { authStatus: 'authenticated', authEpoch: 10, nativeNetwork: { invalidate() {} },
    activeTab: 0, pendingWebTab: 3, tabRequestToken: 0,
    pageBackToken: 0, nativeBackTarget: home, rootTabAddresses: new Map(), authenticatedProfileUrl: profile,
    profileStore: { origins: [], profileRequestToken: 0, profile: { profileUrl: profile }, profileScrollOffset: 420,
      profileCache: { put() {} } },
    homeStore: { homeRequestToken: 0, home: { pageKey: home, pins: [{ id: '123' }] } },
    searchStore: { searchRequestToken: 0, search: { pageKey: home + 'search/' }, searchScrollOffset: 88 },
    inboxStore: { inboxRequestToken: 0, inbox: { pageUrl: home + 'inbox/' } },
    pinStore: { detail: { pinUrl: pin }, detailOpeningPin: pin, detailReturnUrl: home },
    boardStore: { boardOpeningToken: 0 }, shareBridge: {},
    tabsController: { changeIndex: index => indices.push(index) },
    pageHistory: { key: url => (url || '').split('#')[0], cancelBack() {} },
    traceAction() {}, logPageLifecycle() {}, syncFloatingTabsMotion() {}, cancelHomeDetailMore() {},
    detailRequestOwners: new Map(), detailJourney: { close() {} }, detailImageTimer: -1,
    pageTasks: { cancelTimeout() {} }, detailReadNetwork: { invalidate() {} }, dismissPostSnack() {},
    restoreRetainedSearch() {}, restoreInbox() {}, restoreProfile() {},
    expectHome() {}, expectSearch() {}, expectInbox() {}, expectProfile() {}, showMessage() {},
    rootActionContextReady: () => false,
    waitForWebTabConfirmation: index => confirmations.push(index),
    rootTabIndexFromAddress: url => url === home ? 0 : url === home + 'search/' ? 1 : url === home + 'inbox/' ? 2 : url === profile ? 3 : -1,
    extractPinUrl: url => /\/pin\//.test(url) ? url : '',
    isHomeRootAddress: url => url === home, homePageKeyFromAddress: url => url === home ? home : '',
    searchUrlFromAddress: url => url.includes('/search/') ? url : '', inboxUrlFromAddress: url => url.includes('/inbox/') ? url : '',
    profileUrlFromAddress: url => url === profile ? url : '',
    controller: { getUrl: () => document, loadUrl: url => requests.push(['load', url]),
      runJavaScript: code => { requests.push(['js', code]); return Promise.resolve('true'); },
      backOrForward: delta => requests.push(['history', delta]) } });
  native.pinStore.detailPrefetch = { pause() {} };
  native.searchStore = Object.assign(new searchRuntime.Store(), native.searchStore);
  searchRuntime.bindIndex(native);
  require('./home-controller-harness.cjs').createHomeRuntime(ts, context).bindIndex(native);
  native.setup();
  return { native, requests, indices, confirmations, visit: url => { document = url; } };
}
const h = harness(), retained = h.native.profileStore.profile;
for (const index of [3, 1, 2, 0, 3, 3]) {
  h.native.selectNativeRootTab(index);
  assert.equal(h.native.activeTab, index);
  assert.equal(h.indices.at(-1), index);
  assert.equal(h.native.pendingWebTab, -1);
  assert.equal(h.native.pinStore.detail, undefined);
  assert.equal(h.native.nativeBackTarget, '');
  assert.equal(h.native.currentPinUrl(), '', 'hidden Pin cannot become the visible root');
}
assert.equal(h.native.nativeDisplayAddress(), profile);
assert.equal(h.native.nativeRootPageAddress(3), '', 'displayed profile cannot impersonate current Web session');
assert.equal(h.native.currentHomePageKey(), '', 'displayed root cannot enable Home controls on a Pin document');
assert.equal(h.native.profileStore.profile, retained);
assert.equal(h.native.profileStore.profileScrollOffset, 420);
assert.equal(h.native.searchStore.searchScrollOffset, 88);
assert.deepEqual(h.requests, [], 'tab clicks perform no JS, Web navigation or history move');
assert.deepEqual(h.confirmations, [], 'tab clicks never wait for Web confirmation');
h.native.shareBridge.onNavigation(true, 0);
h.native.shareBridge.onPageNavigation(pin, 'restore');
h.native.pageBegin({ url: pin });
assert.equal(h.native.authEpoch, 11, 'a real hidden document change invalidates the session epoch without taking over the screen');
assert.equal(h.native.profileStore.profileActionsReady, false);
h.native.pageBegin({ url: home });
assert.equal(h.native.authEpoch, 11, 'an obsolete page callback cannot advance the epoch');
h.native.updateDetail('{}'); h.native.updateBoard('{}');
h.native.syncNativeReturnRoute(pin); h.native.recordPageNavigation(pin);
h.native.scheduleInterruptedHomeRecovery();
assert.equal(h.native.activeTab, 3, 'late Web callbacks cannot steal the selected native tab');
assert.equal(h.native.pinStore.detail, undefined);
assert.deepEqual(h.requests, []);
assert.equal(h.native.prepareRootPageRead(3), true);
assert.deepEqual(h.requests, [['load', profile]], 'explicit page retry alone starts the correct hidden route');
assert.deepEqual(h.confirmations, [3]);
const ready = harness(); ready.visit(profile); ready.native.selectNativeRootTab(3);
assert.equal(ready.native.prepareRootPageRead(3), false);
assert.equal(ready.native.nativeRootOnly, false);
assert.deepEqual(ready.requests, [], 'a refresh on the current document can reuse its business handler');
const blocked = harness(); blocked.native.authStatus = 'checking'; blocked.native.selectNativeRootTab(3);
assert.equal(blocked.native.activeTab, 0);
blocked.native.authStatus = 'authenticated'; blocked.native.selectNativeRootTab(9);
assert.equal(blocked.native.activeTab, 0);
const foreign = harness(); foreign.native.profileStore.profile = { profileUrl: home + 'another/' };
foreign.native.profileStore.origins = [{ profile: retained }];
foreign.native.selectNativeRootTab(3);
assert.equal(foreign.native.profileStore.profile, undefined, 'My never displays a retained foreign profile when its own cache is absent');
assert.equal(foreign.native.nativeDisplayAddress(), profile);
assert.deepEqual(foreign.requests, []);
assert(!/runJavaScript|loadUrl|backOrForward|expectHome|expectSearch|expectInbox|expectProfile|waitForWebTabConfirmation/.test(method('selectNativeRootTab')));
assert.match(source, /\.animationDuration\(0\)/);
const search = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
assert.match(search, /if \(!this\.automaticLoadingEnabled\) return/);
assert.equal((search.match(/onReachEnd\([\s\S]*?automaticLoadingEnabled/g) || []).length, 3);
const profileSource = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
for (const component of [search, profileSource]) {
  for (const match of component.matchAll(/\.onReachEnd\((\(\) => \{[^{}]*\})\)/g)) {
    let reads = 0;
    const host = { automaticLoadingEnabled: false, actionsReady: true, loading: false,
      snapshot: { discoveryApi: true }, onLoadMore() { reads++; } };
    vm.runInNewContext('(function () { const callback = ' + match[1] + '; callback(); }).call(host)', { host });
    assert.equal(reads, 0, 'activation/reach-end cannot issue pagination after a pure tab switch');
    host.automaticLoadingEnabled = true;
    vm.runInNewContext('(function () { const callback = ' + match[1] + '; callback(); }).call(host)', { host });
    assert.equal(reads, 1, 'page scrolling can resume pagination after interaction');
  }
}
console.log('Native root switch: all tabs, preserved snapshots/scroll, zero navigation/demand/wait, late callbacks, manual reads and session gate passed');
