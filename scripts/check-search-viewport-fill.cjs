const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const timers = [], logs = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['fillInitialViewport', 'discoveryPrefetch', 'discoveryEndVisible', 'resultsReachEnd', 'resultsAreaChanged', 'resultsVisible'].map(method).join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { setTimeout: fn => timers.push(fn), PinmonyRuntimeLog: { info: value => logs.push(value) } });
function harness(atEnd, offset = 0) {
  const h = new Host(); let calls = 0;
  Object.assign(h, { automaticLoadingEnabled: true, actionsReady: true, loading: false,
    initialFillCount: 0, initialFillScheduled: false, initialFillResultsCount: -1, fillGeneration: 0,
    resultsViewportReady: true, restoringResultsScroll: false,
    snapshot: { pageKey: 'synthetic-search', query: 'test', api: true, results: [1, 2, 3] },
    resultsScroller: { isAtEnd: () => atEnd, offset: () => ({ yOffset: offset }) },
    onLoadMore: () => calls++ });
  return { h, calls: () => calls };
}
const flush = () => timers.splice(0).forEach(fn => fn());
const ahead = harness(false, 120);
ahead.h.committedQuery = () => 'test'; ahead.h.upcomingImageUrls = []; ahead.h.lastPrefetchResultCount = -1;
ahead.h.snapshot.results = Array.from({length:20}, (_, index) => ({imageUrl:'https://i.pinimg.com/'+index+'.jpg'}));
ahead.h.resultsVisible(0,5); assert.equal(ahead.calls(),0); assert.equal(ahead.h.upcomingImageUrls.length,8);
ahead.h.resultsVisible(4,9); assert.equal(ahead.calls(),1,'next page starts before the last card');
ahead.h.resultsVisible(10,15); assert.equal(ahead.calls(),1,'visible callbacks do not repeat the same prefetch');
ahead.h.snapshot.results.push({imageUrl:'next'}); ahead.h.snapshot.apiBusy=true;
ahead.h.resultsVisible(12,18); assert.equal(ahead.calls(),1,'busy read cannot start another page');
ahead.h.snapshot.apiBusy=false; ahead.h.automaticLoadingEnabled=false;
ahead.h.resultsVisible(12,18); assert.equal(ahead.calls(),1,'hidden search cannot prefetch');
const full = harness(false); full.h.fillInitialViewport(); flush();
assert.equal(full.calls(), 0, 'three results that fill the viewport must not fetch three extra pages');
const short = harness(true); short.h.fillInitialViewport(); short.h.resultsReachEnd(); flush();
assert.equal(short.calls(), 1, 'layout and end callbacks share one fill');
short.h.fillInitialViewport(); flush(); assert.equal(short.calls(), 1, 'unchanged count cannot loop');
short.h.snapshot.results.push(4); short.h.resultsScroller.isAtEnd = () => false;
short.h.fillInitialViewport(); flush(); assert.equal(short.calls(), 1, 'filled viewport stops immediately');
const scrolled = harness(true, 120); scrolled.h.fillInitialViewport(); flush();
assert.equal(scrolled.calls(), 0, 'scrolled content never initiates first viewport fill');
scrolled.h.resultsReachEnd(); assert.equal(scrolled.calls(), 1, 'user end pagination remains available');
for (const field of ['apiBusy', 'apiEnded', 'apiError']) {
  const blocked = harness(true); blocked.h.fillInitialViewport(); blocked.h.snapshot[field] = true;
  flush(); blocked.h.resultsReachEnd(); assert.equal(blocked.calls(), 0, field);
}
const stale = harness(true); stale.h.fillInitialViewport(); stale.h.fillGeneration++; flush();
assert.equal(stale.calls(), 0, 'old generation cannot paginate');
const hidden = harness(true); hidden.h.fillInitialViewport(); hidden.h.automaticLoadingEnabled = false; flush();
assert.equal(hidden.calls(), 0, 'hidden page cannot paginate');
const unmeasured = harness(true); unmeasured.h.resultsViewportReady = false;
unmeasured.h.fillInitialViewport(); flush(); assert.equal(unmeasured.calls(), 0);
unmeasured.h.resultsAreaChanged({ width: 360, height: 640 }); flush(); assert.equal(unmeasured.calls(), 1);
assert(logs.some(value => value.includes('source=viewport-fill')));
assert(logs.some(value => value.includes('source=scroll-end')));
function discovery(remaining = 600) {
  const sample = harness(false);
  Object.assign(sample.h, { active: true, inputEditing: false, discoveryReadsReady: true,
    actionsReady: false, lastPrefetchDiscoveryCount: -1, discoveryViewportHeight: 800,
    discoveryContentHeight: 1600 + remaining,
    discoveryScroller: { offset: () => ({ yOffset: 800 }) },
    snapshot: { query: '', discoveryApi: true, discoveryActive: true, ideaSections: Array(12).fill({}) } });
  return sample;
}
const early = discovery(); early.h.discoveryPrefetch();
assert.equal(early.h.discoveryEndVisible(), false);
early.h.snapshot.discoveryEnded = true;
assert.equal(early.h.discoveryEndVisible(), true, 'confirmed end with retained topics shows footer');
for (const field of ['discoveryBusy', 'discoveryError']) {
  early.h.snapshot[field] = true; assert.equal(early.h.discoveryEndVisible(), false);
  early.h.snapshot[field] = false;
}
early.h.snapshot.ideaSections = []; assert.equal(early.h.discoveryEndVisible(), false, 'empty keeps its own state');
early.h.snapshot.ideaSections = Array(12).fill({}); early.h.snapshot.discoveryEnded = false;
assert.equal(early.calls(), 1, 'discovery requests with 600vp remaining, before the end');
early.h.discoveryPrefetch(); early.h.discoveryPrefetch(true);
assert.equal(early.calls(), 1, 'scroll and end callbacks cannot duplicate the same page');
early.h.snapshot.ideaSections.push({}); early.h.discoveryPrefetch();
assert.equal(early.calls(), 2, 'appended content permits the next page');
const far = discovery(801); far.h.discoveryPrefetch(); assert.equal(far.calls(), 0);
far.h.discoveryPrefetch(true); assert.equal(far.calls(), 1, 'reach-end fallback retained');
for (const field of ['active', 'automaticLoadingEnabled', 'discoveryReadsReady']) {
  const sample = discovery(); sample.h[field] = false; sample.h.discoveryPrefetch();
  assert.equal(sample.calls(), 0, field);
}
for (const field of ['loading', 'inputEditing', 'restoringResultsScroll']) {
  const sample = discovery(); sample.h[field] = true; sample.h.discoveryPrefetch(true);
  assert.equal(sample.calls(), 0, field);
}
for (const field of ['discoveryBusy', 'discoveryError', 'discoveryEnded', 'query']) {
  const sample = discovery(); sample.h.snapshot[field] = 'blocked'; sample.h.discoveryPrefetch();
  assert.equal(sample.calls(), 0, field);
}
for (const field of ['discoveryApi', 'discoveryActive']) {
  const sample = discovery(); sample.h.snapshot[field] = false; sample.h.discoveryPrefetch();
  assert.equal(sample.calls(), 0, field);
}
const top = discovery(); top.h.discoveryScroller.offset = () => ({ yOffset: 0 });
top.h.discoveryPrefetch(); assert.equal(top.calls(), 0, 'layout alone does not prefetch');
const missing = discovery(); missing.h.discoveryViewportHeight = 0;
missing.h.discoveryPrefetch(); assert.equal(missing.calls(), 0, 'wait for actual viewport measurement');
assert(source.includes('if (offset > 0) this.discoveryPrefetch();'));
assert(source.includes('.onReachEnd(() => this.discoveryPrefetch(true))'));
assert(logs.some(value => value.includes('source=discovery-ahead') && value.includes('remaining=600')));
console.log('Search viewport: full/short content, deduplication, busy/end/error, generation, hidden and scroll pagination passed');
