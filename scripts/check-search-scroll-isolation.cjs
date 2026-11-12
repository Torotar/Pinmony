const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript'), out = {}, cached = [];
const source = fs.readFileSync('feature_search/src/main/ets/stores/PinmonySearchStore.ets', 'utf8');
vm.runInNewContext(ts.transpileModule(source.replace('@Observed', ''), { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
} }).outputText, { exports: out, require: () => ({ PinmonySearchCache: class {
  updateScrollOffset(page, offset) { cached.push([page, offset]); }
} }) });
const writes = [];
const store = new Proxy(new out.PinmonySearchStore(), { set(target, key, value) {
  writes.push(key); return Reflect.set(target, key, value);
} });
store.search = { pageKey: 'results' }; store.retainedSearch = { pageKey: 'root' }; writes.length = 0;
for (let i = 1; i <= 120; i++) store.rememberScrollPosition('results', i * 0.5);
assert.equal(writes.length, 0, 'per-pixel persistence must not assign observable Store properties');
assert.equal(store.searchScrollOffset, 60); assert.equal(store.retainedSearchScrollOffset, 0);
assert.equal(cached.length, 120, 'live return position is persisted without throttling');
store.rememberScrollPosition('root', 640); assert.equal(store.retainedSearchScrollOffset, 640);
store.rememberScrollPosition('stale', 900); assert.equal(store.searchScrollOffset, 60);
store.searchScrollOffset = 12; store.retainedSearchScrollOffset = 25;
assert.equal(store.searchScrollOffset, 12); assert.equal(store.retainedSearchScrollOffset, 25);
assert.deepEqual(writes, ['searchScrollOffset', 'retainedSearchScrollOffset'], 'explicit route restoration/reset assignments retain their existing API');
store.search = { pageKey: 'root' }; store.rememberScrollPosition('root', 700);
assert.equal(store.searchScrollOffset, 700); assert.equal(store.retainedSearchScrollOffset, 700);
const root = fs.readFileSync('entry/src/main/ets/components/PinmonySearchRootContent.ets', 'utf8');
const callback = root.slice(root.indexOf('onResultsScrollPosition:'), root.indexOf('loading: view.searchStore.searchLoading'));
assert(callback.includes('view.searchStore.rememberScrollPosition(pageKey, offset)'));
assert(!callback.includes('searchScrollOffset =') && !callback.includes('retainedSearchScrollOffset ='));
assert(callback.includes('view.currentSearchPageKey() !== pageKey') && callback.includes('view.pinStore.detail'));
console.log('Search scroll isolation: 120 per-pixel saves without top-level Store writes, current/retained/stale routing, restoration setters and root callback guards passed');
