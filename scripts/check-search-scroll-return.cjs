const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const timers = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  method('restoreResultsScroll') + method('reportResultsScroll') + method('imageBudgetWidthChanged') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { setTimeout: fn => timers.push(fn), console });
function fixture(query = '') {
  const host = new Host(), saved = [];
  let position = 0;
  const scroller = { offset: () => ({ yOffset: position }), scrollTo: opts => { position = opts.yOffset; } };
  Object.assign(host, { pagePresent: true, active: true, activePage: 'root', snapshot: { pageKey: 'root', query },
    initialResultsScrollOffset: 620, scrollRestoreRevision: 0, restoringResultsScroll: false,
    discoveryScroller: scroller, resultsScroller: scroller, updateSearchHeaderSurface() {},
    onResultsScrollPosition: (page, offset) => { saved.push([page, offset]); host.initialResultsScrollOffset = offset; } });
  return { host, saved, move: offset => { position = offset; }, position: () => position };
}
for (const query of ['', 'art']) {
  const f = fixture(query);
  f.host.restoreResultsScroll();
  f.host.reportResultsScroll();
  assert.equal(f.saved.length, 0, 'initial zero-offset layout cannot overwrite the cached return position');
  timers.shift()();
  assert.equal(f.position(), 620, 'discovery and results restore the saved position');
  f.host.reportResultsScroll();
  assert.equal(f.saved[0][1], 620);
  f.move(740); f.host.reportResultsScroll();
  assert.equal(f.saved.at(-1)[1], 740, 'user scrolling resumes persistence after restoration');
  f.host.active = false; f.move(0); f.host.reportResultsScroll();
  assert.equal(f.saved.at(-1)[1], 740, 'hidden teardown cannot overwrite position');
}
const stale = fixture();
stale.host.restoreResultsScroll();
stale.host.snapshot = { pageKey: 'next', query: 'new' };
stale.host.activePage = 'next'; stale.host.initialResultsScrollOffset = 140;
stale.host.restoreResultsScroll();
timers.shift()(); assert.equal(stale.position(), 0, 'old route restoration cannot move the new route');
timers.shift()(); assert.equal(stale.position(), 140);
stale.host.restoreResultsScroll(); stale.host.pagePresent = false;
timers.shift()(); assert.equal(stale.position(), 140, 'disposed page ignores delayed restoration');
for (const kind of ['hero', 'idea', 'ideaSection']) {
  const action = source.indexOf(`this.onExploreAction(${kind === 'hero' ? 'hero.id' : kind === 'idea' ? 'item.id' : 'section.actionId'}, '${kind}')`);
  assert(action >= 0 && source.slice(action - 260, action).includes('this.reportResultsScroll();'),
    kind + ' saves the current offset before navigating');
}
console.log('Search scroll return: zero-layout protection, discovery/results restoration, user scroll, hidden/disposed pages, stale routes and discovery navigation capture passed');
