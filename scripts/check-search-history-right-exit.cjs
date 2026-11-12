const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync(process.argv[3] || 'feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, 'missing lifecycle method: ' + name);
  const end = source.indexOf('\n  private ', start + 1);
  return source.slice(start, end < 0 ? source.lastIndexOf('\n}') : end);
}
// This probe also executes on the original backup, before new lifecycle methods exist.
const Entry = vm.runInNewContext(ts.transpileModule('class Entry {' + method('openSearchHistory') + '} Entry;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const entry = new Entry(), entryPaths = ['pin-web-search'];
Object.assign(entry, {
  inputFocusRevision: 0, inputController: { stopEditing() {} }, displayInputController: { stopEditing() {} },
  searchPathStack: { getAllPathName: () => entryPaths.slice() }, setCategoriesCollapsed() {},
  showSearchHistoryDestination(animated) {
    assert.equal(animated, false);
    entryPaths.push('search-history'); entry.historyBodyDestination = 'search-history';
  }
});
entry.openSearchHistory();
assert.deepEqual(entryPaths, ['pin-web-search', 'search-history'], 'direct theme history must have a destination to animate out');
const methods = ['handleSearchBack', 'openSearchHistory', 'committedQuery', 'closeInputPanel',
  'showingSearchHistory', 'showSearchHistoryDestination', 'closeSearchHistoryDestination', 'finishSearchHistoryClose'];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.map(method).join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
function create(retained = false) {
  const host = new Host(), paths = ['pin-web-search'], events = [];
  let focused = false, stop, rootReturns = 0;
  if (retained) paths.push('search-history');
  Object.assign(host, {
    active: true, pagePresent: true, inputEditing: false, inputFocusRevision: 0,
    snapshot: { pageKey: 'https://www.pinterest.com/search/pins/?q=theme', query: 'theme', session: 4 },
    inputController: { stopEditing() {} }, displayInputController: { stopEditing() {} },
    ensureSearchDestination() {}, setCategoriesCollapsed() {}, onQueryChange() {},
    onInputFocusChange(value, callback) { focused = value; stop = callback; },
    searchPathStack: {
      getAllPathName: () => paths.slice(),
      pushPath(info, animated) { paths.push(info.name); events.push(['push', animated]); },
      pop(animated) { events.push(['pop', animated]); paths.pop(); }
    }
  });
  // Same callback contract as Index.backFromSearch, including system back.
  host.onBack = () => {
    if (!focused) { host.openSearchHistory(); return; }
    if (stop(true)) return;
    rootReturns++;
    host.snapshot = { ...host.snapshot, pageKey: 'https://www.pinterest.com/search/', query: '' };
  };
  return { host, paths, events, returns: () => rootReturns };
}
for (const retained of [false, true]) {
  for (const systemBack of [false, true]) {
    const { host, paths, events, returns } = create(retained);
    host.handleSearchBack();
    assert.equal(host.inputEditing, true);
    assert.equal(host.pendingInputFocus, false);
    assert.equal(host.showingSearchHistory('search-history'), true);
    assert.deepEqual(paths, ['pin-web-search', 'search-history']);
    assert.deepEqual(events, retained ? [] : [['push', false]], 'results to history has no entry animation');
    if (systemBack) host.onBack(); else host.handleSearchBack();
    assert.deepEqual(events.at(-1), ['pop', true], 'history exits with the native pop animation');
    assert.equal(returns(), 0, 'route restoration must wait for native completion');
    assert.equal(host.inputEditing, true, 'keep outgoing history and search title intact');
    assert.equal(host.historyDestinationRetained, true);
    assert.equal(host.showingSearchHistory('search-history'), true);
    assert.equal(host.snapshot.query, 'theme');
    const count = events.length;
    host.handleSearchBack(); host.onBack();
    assert.equal(events.length, count, 'repeated toolbar/system back cannot double-pop');
    host.finishSearchHistoryClose();
    assert.equal(returns(), 1);
    assert.equal(host.inputEditing, false);
    assert.equal(host.historyDestinationRetained, false);
    host.finishSearchHistoryClose();
    assert.equal(returns(), 1, 'completion dispatches once');
  }
}
for (const invalidation of ['session', 'page', 'disposed', 'covered']) {
  const { host, returns } = create();
  host.handleSearchBack(); host.handleSearchBack();
  if (invalidation === 'session') host.snapshot.session++;
  if (invalidation === 'page') host.snapshot.pageKey += '&different=1';
  if (invalidation === 'disposed') host.pagePresent = false;
  if (invalidation === 'covered') host.active = false;
  host.finishSearchHistoryClose();
  assert.equal(returns(), 0, invalidation + ' must not restore another route');
}
const photo = create();
photo.paths.push('photo-search');
photo.host.closeSearchHistoryDestination(true);
assert.equal(photo.paths.at(-1), 'photo-search');
const business = create(true);
business.host.inputEditing = true;
business.host.closeInputPanel(false, true);
assert.equal(!!business.host.historyRootReturnPending, false, 'ordinary submit/reset callbacks do not request root return');
assert.equal(business.host.inputEditing, false);
business.host.finishSearchHistoryClose();
assert.equal(business.returns(), 0);
assert(source.includes(".onDisAppear(() => { if (name === 'search-history') this.finishSearchHistoryClose(); })"));
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(index.includes('this.searchStore.searchInputStopEditing(true)) return;'), 'host back respects deferred native exit');
console.log('Recommended result -> history -> root: toolbar/system exit, retained content, duplicate back, stale completion and photo isolation passed');
