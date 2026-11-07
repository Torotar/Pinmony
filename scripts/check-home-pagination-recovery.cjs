const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, {});
const { PinmonyHomePaginationWindow: Window } = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomePaginationWindow.ets');
const policy = new Window();
policy.observe('feed', 22, true, false, 1000);
policy.observe('feed', 33, false, false, 4800);
policy.viewport(7, 5000); policy.viewport(11, 5500);
assert.equal(policy.reserve(4, 12, 5500), 34, 'slow read and forward consumption start the next page earlier');
assert.equal(policy.diagnostic(5500), ' readMs=3800 pinsPerSecond=8.0');
assert.equal(policy.reserve(4, 12, 8000), 12, 'idle viewport does not retain a stale fast scroll rate');
assert.equal(policy.diagnostic(8000), ' readMs=3800 pinsPerSecond=0.0');
policy.viewport(40, 8100); policy.viewport(60, 8200);
assert.equal(policy.reserve(20, 12, 8200), 36, 'lookahead has a hard bound');
policy.observe('feed', 33, true, false, 8300);
policy.observe('feed', 33, false, false, 20000);
assert.equal(policy.readMs, 3800, 'cancelled/no-progress requests never train the successful read estimate');
policy.observe('feed', 33, true, false, 21000);
policy.observe('feed', 44, false, true, 27000);
assert.equal(policy.readMs, 3800, 'failed pages never train the estimate');
policy.pause(); assert.equal(policy.reserve(4, 12, 28000), 12);
policy.observe('other-account-or-category', 10, false, false, 29000);
assert.equal(policy.readMs, 1800, 'scope changes reset estimates');
policy.viewport(3, 30000); policy.viewport(4, 30020); policy.viewport(5, 30100);
assert.equal(policy.pinsPerSecond, 20, 'coalesced callbacks retain the complete advanced distance');
policy.viewport(2, 30200); assert.equal(policy.pinsPerSecond, 0, 'backward scrolling resets forward consumption');

const source = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
function method(name) {
  const match = source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\n  \\}'));
  assert(match, name); return match[0];
}
let now = 10000, serial = 0, allowed = true;
const timers = new Map();
const methods = ['onPrefetchAvailabilityChanged', 'prefetchNextScreen', 'loadNearEnd', 'loadNextPageAtEnd',
  'resumePendingEnd', 'scheduleDetailPrefetch', 'prefetchVisibleDetails', 'scheduleViewportFill', 'fillShortViewport'];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.map(method).join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
  Date: { now: () => now }, allowsSpeculativeReads: () => allowed,
  setTimeout(fn, delay) { const id = ++serial; timers.set(id, { fn, delay }); return id; },
  clearTimeout(id) { timers.delete(id); }
});
function drain() { for (let i = 0; timers.size && i < 8; i++) {
  const batch = [...timers]; timers.clear(); for (const [, t] of batch) t.fn();
} assert.equal(timers.size, 0); }
function fixture() {
  const h = new Host(), calls = [];
  Object.assign(h, { paneMounted: true, paneActive: true, feedActive: true, paginationWasActive: false,
    actionsReady: true, paginationReady: true, restoreDone: true, restoringScroll: false,
    visibleFirst: 4, visibleLast: 11, prefetchNotBefore: 0, prefetchTimer: -1,
    detailPrefetchTimer: -1, viewportFillTimer: -1, viewportHeight: 0, pendingEnd: false,
    home: { dataSource: 'api', pageKey: 'https://www.pinterest.com/', session: 1, selectedTab: 'all',
      pins: Array.from({ length: 22 }, (_, i) => ({ id: String(i) })), loadingMore: false },
    paginationWindow: new Window(), paginationTrace() {}, retryRecoveredImages() {},
    onPrefetchPins() {}, onPrefetchMore() { calls.push('prefetch'); }, onLoadMore() { calls.push('demand'); },
    feedScroller: { isAtEnd: () => false } });
  return { h, calls };
}
const f = fixture(); f.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(f.calls.length, 1);
f.h.onPrefetchAvailabilityChanged(); drain(); assert.equal(f.calls.length, 1, 'same snapshot is deduplicated');
f.h.home.loadingMore = true; f.h.feedActive = false; f.h.onPrefetchAvailabilityChanged();
f.h.home.loadingMore = false; f.h.feedActive = true; f.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(f.calls.length, 2, 'return after cancelled append retries the same count without another scroll');
f.h.home.loadingMore = true; f.h.feedActive = false; f.h.onPrefetchAvailabilityChanged();
f.h.feedActive = true; f.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(f.calls.length, 2, 'return while original request is in flight never duplicates it');
f.h.home.loadingMore = false; f.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(f.calls.length, 3, 'late cancellation completion releases the retry');

for (const block of ['sourceError', 'endReached']) {
  const g = fixture(); g.h.home[block] = true; g.h.onPrefetchAvailabilityChanged(); drain();
  assert.equal(g.calls.length, 0, block + ' is not automatically replayed');
}
allowed = false;
const disabled = fixture(); disabled.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(disabled.calls.length, 0, 'request protection disables speculative reads'); allowed = true;
for (const hidden of ['paneActive', 'paneMounted', 'feedActive', 'actionsReady', 'paginationReady']) {
  const g = fixture(); g.h[hidden] = false; g.h.onPrefetchAvailabilityChanged(); drain();
  assert.equal(g.calls.length, 0, hidden + ' blocks background prefetch');
}
const stale = fixture(); stale.h.prefetchNotBefore = now + 900;
stale.h.onPrefetchAvailabilityChanged();
stale.h.paneMounted = false; stale.h.paneActive = false; now += 1000; drain();
assert.equal(stale.calls.length, 0, 'deferred tasks cannot dispatch after disposal');
const hiddenTimer = fixture(); hiddenTimer.h.prefetchNotBefore = now + 900;
hiddenTimer.h.feedActive = false; hiddenTimer.h.prefetchNextScreen();
assert.equal(timers.size, 0, 'hidden feed cannot arm a delayed prefetch timer');
const short = fixture(); short.h.viewportHeight = 600;
short.h.feedScroller = { isAtEnd: () => true, currentOffset: () => ({ yOffset: 0 }) };
short.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(short.calls.filter(c => c === 'demand').length, 1, 'short retained viewport fills on activation');
short.h.feedActive = false; short.h.onPrefetchAvailabilityChanged();
short.h.feedActive = true; short.h.onPrefetchAvailabilityChanged(); drain();
assert.equal(short.calls.filter(c => c === 'demand').length, 2, 'cancelled short-viewport fill becomes eligible on return');
const near = fixture(); near.h.loadNearEnd(); near.h.loadNearEnd();
assert.deepEqual(near.calls, ['demand'], 'near-end is independently deduplicated');
near.h.feedActive = false; near.h.onPrefetchAvailabilityChanged();
near.h.feedActive = true; near.h.onPrefetchAvailabilityChanged(); near.h.loadNearEnd();
assert.equal(near.calls.filter(c => c === 'demand').length, 2, 'activation releases cancelled near-end suppression');
near.h.feedActive = false; near.h.onPrefetchAvailabilityChanged(); drain();
assert(source.includes('this.paginationWindow.viewport(this.visibleLast, Date.now())'));
assert(source.includes('this.onPrefetchAvailabilityChanged();\n    this.scheduleViewportFill();'), 'snapshot changes observe completion and resume scheduling');
console.log('Home pagination recovery: same-cursor return, late cancellation, in-flight deduplication, adaptive bounded lookahead, idle/backward/scope reset, failures, request protection and disposed tasks passed');
