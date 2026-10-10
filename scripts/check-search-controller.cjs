const assert = require('node:assert/strict');
const { createSearchRuntime } = require('./search-controller-harness.cjs');
const ts = require(process.argv[2] || 'typescript');
const timers = new Map(); let timerId = 0;
const runtime = createSearchRuntime(ts, { setTimeout: (fn, ms) => {
  const id = ++timerId; timers.set(id, { fn, ms }); return id;
}, clearTimeout: id => timers.delete(id) });
const page = 'https://www.pinterest.com/search/pins/?q=art';
const pin = { id: '123', kind: 'pin', title: 'art', targetUrl: 'https://www.pinterest.com/pin/123/', imageUrl: 'https://i.pinimg.com/art.jpg' };
const snapshot = fields => ({ kind: 'state', session: 2, pageKey: page, query: 'art', categories: [], suggestions: [],
  results: [pin], heroes: [], ideaSections: [], api: true, inputReady: true, apiActive: true, ...fields });
async function main() {
  const h = runtime.harness();
  h.controller.updateSearch(JSON.stringify(snapshot()));
  assert.equal(h.store.search.results.length, 1);
  assert.equal(h.store.searchActionsReady, true);
  assert.equal(h.store.searchInputReady, true);
  h.controller.updateSearch(JSON.stringify(snapshot({ session: 1, results: [] })));
  assert.equal(h.store.search.results.length, 1, 'older sessions cannot replace confirmed content');
  h.controller.updateSearch(JSON.stringify(snapshot({ pageKey: page + '&other=1', results: [] })));
  assert.equal(h.store.search.results.length, 1, 'full route mismatch is rejected');
  h.controller.updateSearch(JSON.stringify(snapshot({ kind: 'loading', apiBusy: true, results: [] })));
  assert.equal(h.store.search.results.length, 1, 'same-context loading retains content');
  assert.equal(h.store.searchActionsReady, false, 'retained content never enables result actions');
  h.controller.updateSearch(JSON.stringify(snapshot({ apiError: 'failed', results: [] })));
  assert.equal(h.store.search.results.length, 1);
  assert.equal(h.store.searchError, 'failed');
  h.controller.updateSearch(JSON.stringify(snapshot({ results: [] })));
  assert.equal(h.store.search.results.length, 0, 'confirmed empty results replace prior content');
  h.store.searchScrollOffset = 250;
  h.controller.clearSearch();
  assert.equal(h.store.search, undefined);
  assert.equal(h.controller.restoreRetainedSearch(page), true);
  assert.equal(h.store.searchScrollOffset, 250);
  assert.equal(h.store.searchActionsReady, false);
  assert.equal(h.store.searchInputReady, false);

  let readyQuery;
  const preparingQuery = runtime.harness({ ensureContext: () => new Promise(resolve => { readyQuery = resolve; }) });
  preparingQuery.store.search = snapshot();
  const freshInput = preparingQuery.controller.updateSearchQuery('fresh input');
  preparingQuery.controller.clearSearch();
  preparingQuery.controller.updateSearch(JSON.stringify(snapshot({ session: 22 })));
  readyQuery(true); await freshInput;
  assert.match(preparingQuery.events.find(e => e[0] === 'js')[1], /PinmonySearchQuery\(22,.*fresh input/,
    'document reset during the intended preparation preserves input and uses the fresh session');
  preparingQuery.controller.invalidatePending();

  let rejectRefresh;
  const late = runtime.harness({ runScript: () => new Promise((_, reject) => { rejectRefresh = reject; }) });
  late.store.search = snapshot();
  const pending = late.controller.refreshSearch();
  late.controller.invalidatePending();
  late.store.searchError = 'new page';
  rejectRefresh(Error('old request'));
  await pending;
  assert.equal(late.store.searchError, 'new page', 'suspended/disposed refresh cannot write a late failure');

  let resolveContext;
  const closed = runtime.harness({ ensureContext: () => new Promise(resolve => { resolveContext = resolve; }) });
  closed.store.search = snapshot(); closed.store.searchActionsReady = true;
  const query = closed.controller.updateSearchQuery('obsolete');
  closed.controller.invalidatePending();
  resolveContext(true); await query;
  assert.equal(closed.events.length, 0, 'invalidated input intent never dispatches after context preparation');

  let readCalls = 0;
  const filter = runtime.harness({ runScript: async script => {
    if (script.includes('PinmonySearchReadFilters')) { readCalls++; return JSON.stringify({ loading: true, error: '', options: [] }); }
    return 'true';
  } });
  filter.store.search = snapshot(); filter.store.searchActionsReady = true;
  const opening = filter.controller.openSearchFilters();
  await new Promise(setImmediate);
  assert.equal(filter.ports.sheetKind(), 'searchFilter');
  assert.equal(timers.size > 0, true);
  filter.controller.invalidatePending();
  await opening;
  assert.equal(readCalls, 0, 'disposed delay cannot start a filter read');
  assert.equal(filter.store.searchFilterLoading, false, 'canceled filter does not leave a permanent spinner');
  assert.match(filter.store.searchFilterError, /取消/);
  assert.equal(timers.size, 0, 'controller releases its own timers and settles waiting promises');
  let readyFilter;
  const canceledOpen = runtime.harness({ ensureContext: () => new Promise(resolve => { readyFilter = resolve; }) });
  canceledOpen.store.search = snapshot(); canceledOpen.store.searchActionsReady = true;
  const preparing = canceledOpen.controller.openSearchFilters();
  canceledOpen.controller.invalidatePending(); readyFilter(true); await preparing;
  assert.equal(canceledOpen.ports.sheetKind(), '', 'closed context preparation cannot open a filter panel');
  for (const test of [h, late, closed, filter, canceledOpen]) test.controller.invalidatePending();
  console.log('Search controller: real Store, route/session rejection, retained/empty/error content, cache readiness and lifecycle cancellation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
