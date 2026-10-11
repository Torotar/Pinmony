const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const home = 'https://www.pinterest.com/';
const pin = id => home + 'pin/' + id + '/';
const identity = value => String(value || '').match(/\/pin\/(\d+)/)?.[1] || '';
function compile(source, requireDep = () => ({}), globals = {}) {
  const exports = {};
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(source.replace(/^@Observed\s*$/gm, ''), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: requireDep, ...globals });
  return exports;
}
const cacheModule = compile(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailCache.ets', 'utf8'));
const { PinmonyDetailCache, retainDetailPresentation } = cacheModule;
const { PinmonyPinStore } = compile(fs.readFileSync('feature_pin/src/main/ets/stores/PinmonyPinStore.ets', 'utf8'), () => ({
  emptyVisualResult: () => ({}), PinmonyConfirmedSaves: class {}, PinmonyDetailCache,
  PinmonyDetailPrefetch: class {}
}));
const store = new PinmonyPinStore();
const loaded = { kind: 'state', dataSource: 'api', session: 7, pinUrl: pin(1), imageUrl: 'https://i.pinimg.com/1.jpg',
  imageWidth: 736, imageHeight: 1000, title: 'parent', description: '', creator: '', creatorAvatar: '', sourceLabel: '',
  imageStageReady: true, interactionsSettled: true, commentPreview: 'checked preview', commentsAvailable: true,
  commentEmpty: false, actions: [{ id: 'old-like', kind: 'like', label: '点赞', countText: '12', enabled: true, selected: true }],
  related: [{ id: 'old-related', pinUrl: pin(2), imageUrl: 'https://i.pinimg.com/2.jpg', title: 'child', imageWidth: 236, imageHeight: 400 }] };
store.detailCache.put('1', loaded, 246);
const cached = store.detailCache.get('1');
assert.equal(cached.scrollOffset, 246);
assert.equal(cached.detail.commentPreview, 'checked preview');
assert(cached.detail.imageStageReady && cached.detail.interactionsSettled);
assert.equal(cached.detail.actions[0].enabled, false);
assert.equal(cached.detail.session, 0);
const fresh = () => ({ ...loaded, session: 8, imageStageReady: false, interactionsSettled: false,
  commentPreview: '', commentsAvailable: false, commentEmpty: false, related: [], relatedEnded: false,
  actions: [{ id: 'live-like', kind: 'like', label: '点赞', countText: '', enabled: true, selected: false }] });
const first = retainDetailPresentation(fresh(), cached.detail);
assert(first.actionsRetained && first.commentsRetained && first.relatedRetained);
assert.equal(first.actions[0].countText, '12');
assert.equal(first.actions[0].enabled, false, 'old IDs remain read-only even after current snapshot binding');
assert.equal(first.imageStageReady, false, 'cached display cannot complete the new image lifecycle');
assert.equal(first.interactionsSettled, false, 'cached comments cannot authorize current pagination');
const afterImage = retainDetailPresentation({ ...fresh(), imageStageReady: true }, first);
assert.equal(afterImage.actions[0].id, 'live-like');
assert.equal(afterImage.commentPreview, 'checked preview');
const empty = retainDetailPresentation({ ...fresh(), imageStageReady: true, interactionsSettled: true,
  commentsAvailable: true, commentEmpty: true, relatedEnded: true }, afterImage);
assert.equal(empty.commentPreview, '');
assert.equal(empty.related.length, 0, 'authoritative empty replaces retained content');
assert.equal(empty.commentsRetained, undefined);
assert.equal(retainDetailPresentation({ ...fresh(), pinUrl: pin(9) }, cached.detail).related.length, 0);

// The same Pin can occur twice in one navigation chain without losing its root origin.
store.rememberDetailOrigin('1', home);
store.rememberDetailOrigin('2', pin(1));
store.rememberDetailOrigin('1', pin(2));
assert.equal(store.detailOrigin('1'), pin(2));
store.leaveDetailOrigin('1');
assert.equal(store.detailOrigin('2'), pin(1));
store.leaveDetailOrigin('2');
assert.equal(store.detailOrigin('1'), home);
store.rememberDetailOrigin('1', home + 'search/pins/?q=test');
assert.equal(store.detailOrigin('1'), home + 'search/pins/?q=test', 'new root entry replaces prior chain');
store.clearDetailOrigins(); assert.equal(store.detailOrigin('1'), '');
for (let i = 1; i <= 70; i++) store.rememberDetailOrigin(String(i), i === 1 ? home : pin(i - 1));
assert.equal(store.detailOrigin('1'), '', 'origin history is bounded');

const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const documentBinding = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailDocumentBinding.ets', 'utf8');
function method(name) {
  const start = index.indexOf('  private ' + name);
  assert(start >= 0, name);
  return index.slice(start, index.indexOf('\n  private ', start + 1));
}
const context = { PINTEREST_URL: home, PIN_NATIVE_NETWORK_ENABLED: true,
  PinmonyRuntimeLog: { info() {}, warn() {} } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Native {
  ${method('async backFromDetail')}
  ${method('bindCurrentDetailDocument')}
  ${method('clearRootTabGuard')}
  ${method('currentPinUrl')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
async function main() {
  store.clearDetailOrigins(); store.rememberDetailOrigin('1', home); store.rememberDetailOrigin('2', pin(1));
  const targets = [], events = [];
  let pending = false;
  const n = new context.Native();
  Object.assign(n, { pinStore: store, activeSheetKind: '', nativeBackTarget: '', pageBackToken: 0,
    searchStore: { searchReturnPageKey: home + 'search/' }, pinIdentity: identity,
    extractPinUrl: value => identity(value) ? pin(identity(value)) : '', searchUrlFromAddress: () => '',
    profileUrlFromAddress: () => '', boardUrlFromAddress: () => '', isHomeRootAddress: value => value === home,
    pageHistory: { isPending: () => pending, visit: (url, mode) => { events.push([url, mode]); pending = false; },
      cancelBack: () => { pending = false; } },
    detailJourney: { current: () => 0, mark() {} },
    backOnePage(fallback, target) { targets.push(target || fallback); pending = true; this.nativeBackTarget = target;
      this.pinStore.detail = identity(target) ? { ...cached.detail, pinUrl: target } : undefined; },
    controller: { getUrl: () => pin(2) }, rootTabGuardTarget: -1, rootTabGuardAddress: '',
    detailDocumentBindingService: { bindCurrentDetailDocument(url) { calls.push('bound:' + url); } } });
  store.detail = { ...loaded, pinUrl: pin(2) };
  await n.backFromDetail(); assert.equal(targets[0], pin(1));
  await n.backFromDetail(); assert.equal(targets[1], home, 'second back supersedes pending parent without going to stale search');
  assert.equal(events[0][0], pin(1)); assert.equal(n.pageBackToken, 1);
  n.detailReturnedToRoot = true; n.rootTabGuardTarget = 0; n.rootTabGuardAddress = home;
  n.clearRootTabGuard('root-visible'); assert.equal(n.rootTabGuardTarget, 0);
  assert.equal(n.currentPinUrl(), '', 'late Web URL cannot advertise a Pin over the returned root');
  n.clearRootTabGuard('detail-open'); assert.equal(n.rootTabGuardTarget, -1);

  const calls = [];
  store.detail = cached.detail; store.detailPin = pin(1); store.detailOpeningPin = pin(1); store.detailActionsReady = false;
  let networkContext = { authenticated: true, epoch: 9, page: pin(1) };
  n.nativeBackTarget = ''; n.nativeNetworkContext = () => networkContext;
  n.pageTasks = { timeout() {} };
  n.controller.runJavaScript = async script => { calls.push(script); return 'true'; };
  n.bindCurrentDetailDocument(pin(1));
  assert.equal(calls.length, 1, 'matching authenticated document binds without page-end or another auth probe');
  assert.equal(calls[0], 'bound:' + pin(1)); assert.equal(store.detailActionsReady, false);
  assert.match(documentBinding, /context\.authenticated/);
  assert.match(documentBinding, /context\.page !== url/);
  assert.match(documentBinding, /hasNativeBackTarget\(\)/);
  assert.match(documentBinding, /rootTabGuardTarget\(\) >= 0/);
  assert.match(index, /detailReturnedToRoot && this\.extractPinUrl\(url\)/);
  assert.match(documentBinding, /document\.transport\.confirmed/);
  assert.match(documentBinding, /document\.transport\.wait\.timeout/);
  assert.match(fs.readFileSync('entry/src/main/ets/app/PinmonyDetailOpeningCoordinator.ets','utf8'), /if \(detail && this\.pinStore\.detail\?\.kind !== 'cached'\)/,
    'a late base-only read cannot wipe a full parent cache');
  assert(fs.readFileSync('entry/src/main/ets/app/PinmonyNetworkBridgeCoordinator.ets','utf8').includes('this.detailReadCache.store(job, reply)'), 'successful current replies populate the return cache');
  assert(fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets','utf8').includes('this.ports.detailReadCache().setPin(pin)'), 'return target enables Pin-scoped read reuse');
  console.log('Detail return: complete read-only cache, partial refresh, authoritative empty, cyclic origins, continuous back and early document binding passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
