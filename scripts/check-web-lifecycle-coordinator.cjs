const assert = require('node:assert/strict'), fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const harness = require('./product-coordination-harness.cjs');
const logs = [], calls = [], timers = [];
const globals = { PinmonyRuntimeLog: { info: s => logs.push(s), warn: s => logs.push(s), error: s => logs.push(s) } };
const native = harness.createHost(class Fixture {}, ts, globals);
const root = 'https://www.pinterest.com/', search = root + 'search/pins/?q=design';
let document = search, urlFailure = false, obsolete = false, reads = 0;
Object.assign(native, {
  returnCoordinator: { navigationBegun(url) { calls.push(['navigation-begin', url]); } },
  authStatus: 'authenticated', authEpoch: 2, activeTab: 1, nativeRootOnly: false, businessSuspended: false,
  authCheckTimer: -1, tabRequestToken: 4, rootTabGuardTarget: -1, staleRootDocumentTarget: () => -1,
  retainedRootTabPending: -1, retainedRootTabAddress: '', retainedHomeDocumentPending: false,
  nativeBackTarget: '', logoutAwaitingLogin: false, lastPageUrl: root, webPageLoading: false,
  pageHistory: { key: v => v }, nativeNetwork: { invalidate() { calls.push('invalidate'); } },
  controller: { getUrl() { if (urlFailure) throw Error('unavailable'); return document; } },
  pageTasks: { timeout(fn, delay) { timers.push({ fn, delay }); return timers.length; }, cancelTimeout() {} },
  coordinatorTasks: { timeout(fn, delay) { timers.push({ fn, delay }); return timers.length; } },
  photoMenuCoordinator: { notify() { calls.push('menu-notify'); } },
  ignoreSupersededDetailDocument: () => obsolete, isStaleRootDocumentBegin: () => false,
  rootTabKindFromAddress: () => 'search', rootTabIndexFromAddress: () => 1,
  extractPinUrl: () => '', pinIdentity: v => v, effectiveRootDocumentTarget: () => 1,
  searchUrlFromAddress: v => v === search ? v : '', inboxUrlFromAddress: () => '', profileUrlFromAddress: () => '',
  isHomeRootAddress: v => v === root, homePageKeyFromAddress: v => v,
  clearDetail() { this.pinStore.detail = undefined; }, clearProfile() { this.profileStore.profile = undefined; },
  clearInbox() { this.inboxStore.inbox = undefined; }, clearSearch() { this.searchStore.search = undefined; },
  restoreProfile: () => false, restoreInbox: () => false, restoreRetainedSearch: () => false,
  clearRootTabCaches() {}, clearRootTabGuard() {}, syncBoardRoute() {}, prepareHomeForPageBegin() {},
  recordPageNavigation() {}, cancelHomeDetailMore() {}, resetAuthenticatedContent() {}, tryEnterOfflinePreview: () => false,
  expectSearch() { reads++; }, expectInbox() {}, expectProfile() {},
  logPageLifecycle: event => calls.push(event), configureDocumentRetention: v => calls.push(['retention', v]),
  installDownloadDelegate: () => calls.push('download-delegate'), markRootDocumentReady: () => calls.push('ready'),
  bindCurrentDetailDocument: () => calls.push('detail-document'), refreshWebNavigation: async () => calls.push('navigation'),
  syncAuthentication: () => calls.push('auth'), handleExternalShareTarget: url => { calls.push(['external', url]); return true; },
  handleMainFrameFailure: (url, code) => calls.push(['failure', url, code])
});
harness.bind(native, ts, globals, ['WebLifecycle']);
const coordinator = native.webLifecycleCoordinator;
const stores = ['homeStore', 'searchStore', 'inboxStore', 'profileStore', 'pinStore'];
for (const key of stores) assert.equal(coordinator[key], native[key], 'same actual Store: ' + key);
coordinator.controllerAttached();
assert(calls.includes('download-delegate'));
assert(calls.some(v => Array.isArray(v) && v[0] === 'retention' && v[1] === true));
obsolete = true;
const epoch = native.authEpoch;
coordinator.pageBegin(search);
assert.equal(native.authEpoch, epoch, 'obsolete page begin cannot clear controls or advance epoch');
obsolete = false;
native.nativeRootOnly = true;
native.homeStore.homeActionsReady = true;
coordinator.pageBegin(search);
assert.equal(native.homeStore.homeActionsReady, false);
assert.equal(native.activeTab, 1, 'hidden document change keeps selected native screen');
native.nativeRootOnly = false;
coordinator.pageBegin(search);
assert.equal(native.webPageLoading, true);
assert(calls.includes('menu-notify'), 'document begin immediately wakes closed menu waiters');
const timer = timers.find(v => v.delay === 350);
assert(timer, 'search demand remains deferred');
native.authEpoch++;
timer.fn();
assert.equal(reads, 0, 'departed authentication epoch cannot dispatch');
coordinator.pageBegin(search);
assert.equal(timers.length, 1, 'duplicate begin cannot schedule another read');
native.webPageLoading = false;
coordinator.pageBegin(search);
urlFailure = true;
assert.doesNotThrow(() => timers.at(-1).fn());
assert.equal(reads, 0, 'unavailable document cannot be treated as current');
urlFailure = false;
native.webPageLoading = false; coordinator.pageBegin(search);
document = search + '&page=2'; timers.at(-1).fn();
assert.equal(reads, 0, 'full search URL is required');
document = search; native.webPageLoading = false; coordinator.pageBegin(search); timers.at(-1).fn();
assert.equal(reads, 1);
obsolete = true; calls.length = 0; coordinator.pageEnd();
assert(!calls.includes('auth'), 'obsolete document end cannot authenticate current page');
obsolete = false; coordinator.pageEnd();
assert(calls.includes('auth') && calls.includes('ready'));
assert.equal(native.webPageLoading, false);
assert.equal(coordinator.overrideUrl(root), true);
assert.equal(coordinator.interceptLoad(root, false), false);
native.authStatus = 'unauthenticated';
assert.equal(coordinator.overrideUrl(root), false);
coordinator.consoleMessage('Cookie: must-never-appear');
coordinator.consoleMessage('x'.repeat(2000));
coordinator.consoleMessage('RequestPolicy: read-merged');
coordinator.mainFrameError(root, -200, 'private response text');
assert(!calls.some(v => Array.isArray(v) && v[0] === 'failure' && v[2] === -200), 'old document errors cannot fail the current route');
document = root;
coordinator.mainFrameError(root, -200, 'private response text');
assert(calls.some(v => Array.isArray(v) && v[0] === 'failure' && v[2] === -200));
assert(logs.some(v => v.includes('info=classified')));
assert(!logs.some(v => /https:|must-never|private response/.test(v)));
const source = fs.readFileSync('scripts/product-coordination-harness.cjs', 'utf8');
assert(!source.includes('Object.defineProperty'));
assert(!source.includes('feature-state-aliases'));
for (const key of Object.keys(require('./feature-store-access-contracts.json'))) assert(!Object.hasOwn(native, key), 'fixture cannot expose old page field: ' + key);
console.log('Web lifecycle: real Index ports, shared Stores, stale begin/end, deferred epoch/document guards, menu wakeup, errors and bounded diagnostics passed');
