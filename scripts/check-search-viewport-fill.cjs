const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const timers = [], logs = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['fillInitialViewport', 'resultsReachEnd', 'resultsAreaChanged'].map(method).join('\n') + '} Host;',
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
console.log('Search viewport: full/short content, deduplication, busy/end/error, generation, hidden and scroll pagination passed');
