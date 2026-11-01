const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const runtime = require('./home-controller-harness.cjs').createHomeRuntime(ts);
const source = fs.readFileSync('entry/src/main/ets/app/PinmonyHomeNativeReads.ets', 'utf8');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const rootRequest = index.match(/  private requestRootPage\(index: number\): void \{[^\n]+\}/);
assert(rootRequest, 'cover the actual root-read dispatcher');
const visibilityStart = index.indexOf('  private onRootPageVisible(');
const visibilityEnd = index.indexOf('\n  private ', visibilityStart + 1);
assert(visibilityStart >= 0 && visibilityEnd > visibilityStart);
const Root = vm.runInNewContext(ts.transpileModule('class Root {' + rootRequest[0] +
  index.slice(visibilityStart, visibilityEnd) + '} Root;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
function reader(master, local) {
  const exports = {};
  const code = source.replace('PIN_NATIVE_HOME_READS_ROLLOUT_ENABLED: boolean = true;',
    'PIN_NATIVE_HOME_READS_ROLLOUT_ENABLED: boolean = ' + local + ';');
  vm.runInNewContext(ts.transpileModule(code, {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: withLocalMessages(name => name === 'common_network' ?
    { PIN_BUSINESS_PIN_READ_ENABLED: master } : { PinmonyRuntimeLog: { info() {} } }) });
  return exports.PinmonyHomeNativeReads;
}
async function disabled(master, local) {
  const Native = reader(master, local), store = new runtime.Store();
  store.home = { kind: 'state', session: 0, pageKey: 'https://www.pinterest.com/',
    pins: [{ id: '12' }], tabs: [{ id: 'tab:7', enabled: true, selected: false }], dataSource: 'api' };
  store.homeError = 'retained-error'; store.homeSourceWarning = 'retained-warning';
  let reads = 0;
  const native = new Native({ store: () => store, active: () => true,
    session: () => { reads++; throw Error('disabled service must stop before reading session'); },
    username: () => { throw Error('disabled username'); },
    network: () => { throw Error('disabled transport'); },
    committed: () => { throw Error('disabled commit'); }, saved: () => false });
  const before = JSON.stringify(store);
  await native.demand(); await native.refresh(); await native.retry(); await native.select('tab:7'); await native.more();
  assert.equal(reads, 0); assert.equal(JSON.stringify(store), before, 'disabled reads preserve existing presentation');
  const host = new Root(), scheduled = [];
  Object.assign(host, { homeStore: store, homeNativeReads: native, nativeBusinessRoutesEnabled: true,
    authStatus: 'authenticated', activeTab: 0, nativeRootOnly: true, offlinePreviewMode: false,
    currentHomePageKey: () => store.home.pageKey,
    runSessionScript() { throw Error('unexpected Web script'); },
    ensureRootActionContext() { throw Error('unexpected Web context preparation'); },
    loadSessionDocument() { throw Error('unexpected Web navigation'); },
    rejectOfflineAction: () => false,
    tabRequestToken: 1, nativeRootTabsVisible: () => true,
    pagePerformance: { mark() {} }, markRootPerformance() {},
    coordinatorTasks: { timeout(fn) { scheduled.push(fn); } },
    rootContextCoordinator: { requestRootPage() { throw Error('unexpected legacy root request'); } } });
  const controller = runtime.bindIndex(host, true);
  controller.expectHome(); controller.refreshHome(); await controller.loadMoreHome();
  await controller.selectHomeTab('tab:7'); host.requestRootPage(0);
  host.onRootPageVisible(0, true);
  assert.equal(scheduled.length, 1, 'home visibility uses only the native read scheduler');
  scheduled[0]();
  assert.equal(JSON.stringify(store), before, 'actual Index ports do not fall back or start loading when disabled');
  controller.updateHome(JSON.stringify({ kind: 'state', session: 99, pageKey: store.home.pageKey,
    pins: [{ id: '99' }], tabs: [] }));
  assert.equal(store.home.pins[0].id, '12', 'late Web content cannot replace native presentation');
  store.homeLoading = true; store.homeRefreshing = true; store.pendingHomeTab = 'tab:7';
  native.pause();
  assert.equal(store.homeLoading, false); assert.equal(store.homeRefreshing, false); assert.equal(store.pendingHomeTab, '');
  native.reset(); assert.equal(store.home, undefined, 'session reset still clears disabled home content');
}
(async () => {
  await disabled(true, false); await disabled(false, true); await disabled(false, false);
  console.log('Home feature isolation: local/master disabled, no session reads or Web fallback, preserved presentation, late Web rejection and unconditional cleanup passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
