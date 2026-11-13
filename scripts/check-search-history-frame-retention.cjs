const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync(process.argv[3] || 'feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const a = source.indexOf('  private ' + name + '(');
  assert(a >= 0, 'Missing method: ' + name);
  const b = source.indexOf('\n  private ', a + 1);
  return source.slice(a, b < 0 ? source.lastIndexOf('\n}') : b).replace(/\s*@Builder\s*$/, '');
}
const destination = method('searchRootDestination');
const header = method('searchHeaderContent');
const filterCondition = [...header.slice(0, header.indexOf("SymbolGlyph($r('sys.symbol.slider_horizontal_2'))")).matchAll(/if \(([^\n]+)\) \{/g)].at(-1);
assert(filterCondition, 'result filter visibility condition must exist');
// Evaluate the actual builder condition across both underlying root and history hosts.
const filterVisible = new Function('editing', 'historyPage', 'return ' + filterCondition[1]);
for (const editing of [false, true]) {
  for (const historyPage of [false, true]) {
    for (const retained of [false, true]) {
      for (const query of ['', 'theme']) {
        assert.equal(filterVisible.call({ committedQuery: () => query, historyDestinationRetained: retained }, editing, historyPage),
          !editing && !!query && (historyPage || !retained),
          'only the current result header may show filters; retained discovery must not show camera and filters together');
      }
    }
  }
}
assert(destination.includes("if (name !== 'search-history') {"), 'landing must stay mounted through direct recommendation results');
assert(destination.includes('.visibility(this.rootDiscoveryVisible() ? Visibility.Visible : Visibility.Hidden)'), 'hide the retained landing without destroying its carousel');
assert(destination.includes(".onDisAppear(() => { if (name === 'search-history') this.finishSearchHistoryClose(); })"), 'root dispatch waits for outgoing destination removal');
assert(!destination.includes('.onHidden('), 'hidden notification must not replace an outgoing body');
assert(destination.includes("this.committedQuery() && (name === 'search-history' || !this.historyDestinationRetained)"), 'a retained root cannot flash stale results');
assert(source.includes('this.retainedDiscovery = undefined;'), 'dispose releases the account-scoped presentation snapshot');
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + [
  'discoverySnapshot', 'rememberDiscoverySnapshot', 'rootDiscoveryVisible', 'onSnapshotChanged',
  'committedQuery', 'handleSearchBack', 'openSearchHistory', 'closeInputPanel', 'showingSearchHistory',
  'showSearchHistoryDestination', 'closeSearchHistoryDestination', 'finishSearchHistoryClose', 'discoveryInitialLoading'
].map(method).join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const landing = { kind: 'state', session: 4, pageKey: 'https://www.pinterest.com/search/', query: '',
  heroes: [{ id: 'hero-a', imageUrl: 'retained-a' }, { id: 'hero-b', imageUrl: 'retained-b' }],
  ideaSections: [{ id: 'topic-a', items: [] }], categories: [], results: [], discoveryActive: true };
for (const retained of [false, true]) {
  const h = new Host(), paths = ['pin-web-search'];
  let focused = false, stop, rootRequests = 0;
  Object.assign(h, { snapshot: landing, pagePresent: true, active: true, loading: false, historyDestinationRetained: false,
    activePage: landing.pageKey, activeSession: 4, inputFocusRevision: 0, currentHeroIndex: 1,
    currentHeroId: 'hero-b', inputController: { stopEditing() {} }, displayInputController: { stopEditing() {} },
    imagePrefetch: { clear() {} }, setCategoriesCollapsed() {}, ensureSearchDestination() {},
    tracePresentation() {}, restoreResultsScroll() {}, closePhotoSearch() {}, restoreHeroPosition() {},
    syncQuizPresentation() {}, fillInitialViewport() {}, onQueryChange() {},
    onInputFocusChange(focus, callback) { focused = focus; stop = callback; },
    searchPathStack: { getAllPathName: () => paths.slice(), pushPath: info => paths.push(info.name), pop: () => paths.pop() }
  });
  h.rememberDiscoverySnapshot();
  assert.equal(h.discoverySnapshot(), landing);
  h.snapshot = { ...landing, pageKey: landing.pageKey + 'pins/?q=topic', query: 'topic', heroes: [], ideaSections: [], results: [{}] };
  h.onSnapshotChanged();
  assert.equal(h.discoverySnapshot(), landing, 'result commits cannot clear carousel data');
  assert.equal(h.currentHeroId, 'hero-b'); assert.equal(h.currentHeroIndex, 1);
  assert.equal(h.rootDiscoveryVisible(), false, 'result overlays the retained discovery node');
  if (retained) { paths.push('search-history'); h.historyDestinationRetained = true; }
  h.onBack = () => {
    if (!focused) { h.openSearchHistory(); return; }
    if (stop(true)) return;
    rootRequests++;
    // Keep a delayed parent route update to exercise the interval missing in earlier tests.
  };
  h.handleSearchBack(); h.handleSearchBack();
  assert.equal(rootRequests, 0); assert.equal(h.showingSearchHistory('search-history'), true);
  assert.equal(h.rootDiscoveryVisible(), true);
  assert.equal(h.discoverySnapshot().heroes[1].imageUrl, 'retained-b');
  h.finishSearchHistoryClose();
  assert.equal(rootRequests, 1);
  assert.equal(h.historyDestinationRetained, true, 'delay must never expose the old result destination');
  assert.equal(h.rootDiscoveryVisible(), true);
  h.snapshot = { ...landing, kind: 'loading', session: 0, heroes: [], ideaSections: [] };
  h.loading = true; h.onSnapshotChanged();
  assert.equal(h.historyDestinationRetained, false, 'actual root acknowledgment releases the route guard');
  assert.equal(h.rootDiscoveryVisible(), true);
  assert.equal(h.discoverySnapshot(), landing, 'temporary landing placeholder cannot erase decoded carousel source');
  assert.equal(h.discoveryInitialLoading(), false);
  h.snapshot = { ...landing, session: 5 }; h.loading = false; h.onSnapshotChanged();
  assert.equal(h.discoverySnapshot(), h.snapshot, 'current confirmed landing replaces the presentation snapshot');
  h.finishSearchHistoryClose(); assert.equal(rootRequests, 1);
  h.snapshot = { ...landing, heroes: [], ideaSections: [] }; h.onSnapshotChanged();
  assert.equal(h.discoverySnapshot().heroes.length, 0, 'confirmed empty landing is authoritative');
}
console.log('History exit frame retention: mounted discovery/carousel, delayed root acknowledgment, no result flash, hero identity, loading and confirmed-empty paths passed');
