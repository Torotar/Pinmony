const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  const rest = source.slice(start);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
const timers = [], logs = [];
const context = { PIN_NATIVE_PROFILE_READS_ENABLED:false, PIN_NATIVE_HOME_READS_ENABLED:false, PIN_NATIVE_SEARCH_READS_ENABLED:false, PIN_NATIVE_SEARCH_DISCOVERY_ENABLED:false, PIN_NATIVE_INBOX_UPDATES_ENABLED:false, PIN_NATIVE_INBOX_MESSAGES_ENABLED:false, setTimeout: callback => timers.push(callback),
  PinmonyRuntimeLog: { info: message => logs.push(message) } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Page {' +
  ['usesNativeProfileReads', 'rootPageHasReadState', 'onRootPageVisible', 'rootStatusError', 'rootStatusLoading', 'failRootPreparation'].map(method).join('\n') +
  '\n} globalThis.Page = Page;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
function harness(index) {
  const native = new context.Page(), requests = [];
  Object.assign(native, { activeTab: index, authStatus: 'authenticated', tabRequestToken: 1,
    nativeRootOnly: true, pendingWebTab: -1, loadFailed: false,
    nativeRootTabsVisible: () => true,
    // This checks the manual rollback path. Native visibility reads have dedicated checks.
    inboxMessagesNativeReads:{selected:()=>false}, inboxUpdatesNativeReads:{eligible:()=>false}, searchNativeReads:{eligible:()=>false}, searchDiscoveryNativeReads:{eligible:()=>false},
    homeStore: { homeForPresentation: () => undefined }, searchStore: {}, inboxStore: {}, profileStore: {},
    homePresentationPageKey: () => '/', retainedHomeRootPageKey: () => '/',
    requestRootPage(i) { requests.push(i); native.tabRequestToken++; native.pendingWebTab = i; } });
  native.pagePerformance = {mark(){}}; native.markRootPerformance=()=>{};
  return { native, requests };
}
function flush() { while (timers.length) timers.shift()(); }
for (let index = 0; index < 4; index++) {
  const h = harness(index);
  assert.equal(h.native.rootStatusLoading(index), true, 'empty root shows loading before the deferred read starts');
  h.native.onRootPageVisible(index, true);
  h.native.onRootPageVisible(index, true);
  assert.deepEqual(h.requests, [], 'presentation completes before document preparation');
  flush();
  assert.deepEqual(h.requests, [index], 'each empty root reads once on becoming visible');
  h.native.nativeRootOnly = false; h.native.pendingWebTab = -1;
  assert.equal(h.native.rootStatusLoading(index), true, 'document confirmation gap keeps the loading state');
  h.native.rootContextCoordinator = { failDocument() {} };
  h.native.failRootPreparation(index, 'timeout');
  assert.equal(h.native.rootStatusLoading(index), false, 'bounded preparation failure exposes retry');
  assert.equal(h.native.rootStatusError(index), 'timeout');
  const cached = harness(index);
  if (index === 0) cached.native.homeStore.homeForPresentation = () => ({ pins: [] });
  if (index === 1) cached.native.searchStore.search = { results: [] };
  if (index === 2) cached.native.inboxStore.inbox = { items: [] };
  if (index === 3) {
    cached.native.profileStore.profile = { pins: [], session: 7 };
    cached.native.profileStore.profileSession = 7;
    cached.native.profileStore.profileActionsReady = true;
  }
  cached.native.onRootPageVisible(index, true); flush();
  assert.deepEqual(cached.requests, [], 'cached and valid empty snapshots do not trigger unsolicited reads');
}
const retainedProfile = harness(3);
retainedProfile.native.profileStore.profile = { pins: [], session: 7 };
retainedProfile.native.profileStore.profileSession = 6;
retainedProfile.native.profileStore.profileActionsReady = false;
retainedProfile.native.onRootPageVisible(3, true);
retainedProfile.native.onRootPageVisible(3, true);
assert.equal(retainedProfile.native.profileStore.profile.pins.length, 0, 'unconfirmed profile cache remains available for immediate presentation');
flush();
assert.deepEqual(retainedProfile.requests, [], 'visible profile cache does not reload its document merely to confirm actions');
assert.equal(retainedProfile.native.profileStore.profileActionsReady, false, 'presentation never enables stale actions');
const canceled = harness(1);
canceled.native.onRootPageVisible(1, true);
canceled.native.activeTab = 2; canceled.native.tabRequestToken++;
flush(); assert.deepEqual(canceled.requests, [], 'fast switch cancels queued preparation');
for (const change of [h => h.native.authStatus = 'checking', h => h.native.loadFailed = true,
  h => h.native.searchStore.searchError = 'failed', h => h.native.searchStore.searchLoading = true,
  h => h.native.nativeRootTabsVisible = () => false]) {
  const h = harness(1); change(h); h.native.onRootPageVisible(1, true); flush();
  assert.deepEqual(h.requests, [], 'login, child, loading and errors prevent automatic retry');
}
const hidden = harness(2); hidden.native.onRootPageVisible(2, false); flush();
assert.deepEqual(hidden.requests, [], 'hidden roots never prepare');
assert.equal((source.match(/\.onVisibleAreaChange\(\[0\.01\], \(visible: boolean\) => this\.onRootPageVisible\([0-3], visible\)\)/g) || []).length, 4);
console.log('Root initial loading: four visible empty roots, deferred/coalesced demand, retained snapshots, cancellation and failure/login/child gates passed');
