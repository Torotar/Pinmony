const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  private backFromSearch():');
const method = source.slice(start, source.indexOf('\n  private backFromSearchLanding', start));
const timers = [], home = 'https://www.pinterest.com/', target = home + 'search/';
const Native = vm.runInNewContext(ts.transpileModule('class Native {' + method + '} Native;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { PINTEREST_URL: home, PinmonyRuntimeLog: { info() {} }, setTimeout: fn => timers.push(fn) });
for (const cached of [true, false]) {
  const n = new Native(), loads = [];
  Object.assign(n, { pinStore: {}, searchStore: { search: { pageKey: target + '?q=test', query: 'test' },
    searchCache: { put() {} }, searchScrollOffset: 180, searchActionsReady: true, searchInputReady: true },
    rootTabAddresses: new Map(), pageBackToken: 0,
    currentPinUrl: () => '', currentSearchPageKey: () => target + '?q=test',
    pageHistory: { cancelBack() {}, visit() {}, prepareBackTo() {} },
    clearSearch() { this.searchStore.search = undefined; this.searchStore.searchActionsReady = false; this.searchStore.searchInputReady = false; },
    clearRootTabGuard() {}, restoreRetainedSearch() {
      if (cached) { this.searchStore.search = { pageKey: target, query: 'old', suggestions: [1], results: [2], heroes: [3] };
        this.searchStore.searchScrollOffset = 420; this.searchStore.searchLoading = false; }
      return cached;
    }, controller: { loadUrl: value => loads.push(value) }, showMessage() {} });
  n.backFromSearch();
  assert.equal(n.nativeBackTarget, target);
  assert.equal(n.searchStore.search.query, '');
  assert.equal(n.searchStore.searchActionsReady, false);
  assert.equal(n.searchStore.searchInputReady, false);
  assert.equal(n.searchStore.searchLoading, !cached);
  if (cached) { assert.equal(n.searchStore.search.heroes.length, 1); assert.equal(n.searchStore.search.suggestions.length, 0); assert.equal(n.searchStore.searchScrollOffset, 420); }
  timers.splice(0).forEach(fn => fn());
  assert.deepEqual(loads, [target]);
}
console.log('Search landing return: cached discovery/scroll, cleared editing intent, loading miss and gated actions passed');
