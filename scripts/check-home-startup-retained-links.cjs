const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, {
  common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} }, CACHE_TTL: { homeFeed: 300000 },
    buildCacheKey: (account, kind, params) => account + ':' + kind + ':' + params.pageKey },
  common_network: { PIN_BUSINESS_PIN_READ_ENABLED: true }
});
const { PinmonyHomeStore: Store } = loader.loadFile('feature_home/src/main/ets/stores/PinmonyHomeStore.ets');
const { PinmonyHomeNativeReads: Reader } = loader.loadFile('entry/src/main/ets/app/PinmonyHomeNativeReads.ets');
const { writeHomeCache, readHomeCache, readHomeImageConnectionSeed } = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeCache.ets');
const page = 'https://www.pinterest.com/';
const snapshot = () => ({ kind: 'state', session: 0, pageKey: page, selectedTab: 'All',
  tabs: [{ id: 'tab:all', label: 'All', selected: true, enabled: true }], dataSource: 'api',
  pins: [{ id: '1', pinUrl: page + 'pin/1/', imageUrl: 'https://i.pinimg.com/474x/previous.jpg',
    imageWidth: 474, imageHeight: 700, title: 'Previous card' }] });
let now = 0;
const values = new Map();
const cache = {
  put(key, value, ttl) { values.set(key, { value, ttl, at: now }); },
  getWithMetadata(key, maxAge) {
    const entry = values.get(key), ageMs = entry ? now - entry.at : 0;
    // Cold disk lookup uses the persisted file age and the caller's maxAge.
    const valid = entry && ageMs <= maxAge;
    return { value: valid ? entry.value : null, status: valid ? 'disk' : entry ? 'expired' : 'miss', ageMs };
  }, remove(key) { values.delete(key); }
};
let stored = 0;
writeHomeCache(cache, 'account-a', snapshot(), () => stored++);
assert.equal(stored, 1);
now = 4 * 60 * 1000;
const restored = readHomeCache(cache, 'account-a', page, 'test');
assert.equal(restored.pins[0].imageUrl, snapshot().pins[0].imageUrl, 'existing short-lived presentation cache remains unchanged');
assert.equal(readHomeCache(cache, 'account-b', page, 'test'), undefined, 'another account cannot read these links');
assert.equal(readHomeCache(cache, 'account-a', page + 'other/', 'test'), undefined);
now = 12 * 60 * 60 * 1000;
assert.equal(readHomeImageConnectionSeed(cache, 'account-a', page), snapshot().pins[0].imageUrl, 'an older link can only prepare the downloader');
assert.equal(readHomeCache(cache, 'account-a', page, 'test'), undefined, 'older content cannot become the live home feed');
assert.equal(readHomeImageConnectionSeed(cache, 'account-b', page), '');
assert.equal(readHomeImageConnectionSeed(cache, 'account-a', page + 'other/'), '');
now = 24 * 60 * 60 * 1000 + 1;
assert.equal(readHomeImageConnectionSeed(cache, 'account-a', page), '', 'connection seed age remains bounded');
function fixture(saved = snapshot()) {
  const store = new Store(), jobs = [], commits = [];
  let active = true, account = 'account-a', generation = 1;
  store.home = saved; store.cachedHome = saved; store.diskCacheRestored = !!saved;
  const reader = new Reader({ store: () => store, active: () => active, username: () => 'fixture', saved: () => false,
    session: () => ({ authenticated: true, generation, accountId: account, origin: page.slice(0, -1) }),
    network: () => ({ cancel() {}, requestBusinessHomeRead: job => new Promise(resolve => jobs.push({ job,
      resolve(body, status = 200) { resolve({ body, status, error: '' }); } })) }),
    committed: (value, kind) => commits.push({ value, kind }) });
  return { store, reader, jobs, commits, hide() { active = false; }, switchAccount() { account = 'account-b'; generation++; } };
}
const categories = JSON.stringify({ resource_response: { status: 'success', data: [] } });
const feed = ids => JSON.stringify({ resource_response: { status: 'success', bookmark: 'next', data: ids.map(id => ({
  type: 'pin', id: String(id), images: { '474x': { url: 'https://i.pinimg.com/474x/new-' + id + '.jpg', width: 474, height: 700 } }
})) } });
async function run() {
  const cached = fixture(), old = cached.store.home;
  const startup = cached.reader.demand();
  assert.equal(cached.jobs.length, 2, 'startup still fetches the current list and categories');
  assert.equal(cached.store.home, old); assert.equal(cached.store.cachedHome, old);
  assert(!cached.store.homeActionsReady && !cached.store.homeNativeReadsReady, 'display cache cannot authorize writes/pagination');
  cached.jobs[0].resolve(feed([2])); cached.jobs[1].resolve(categories); await startup;
  assert.equal(cached.store.home.pins[0].id, '2', 'new startup data replaces the old presentation without waiting for images');
  assert(!cached.store.diskCacheRestored && cached.store.homeNativeReadsReady);
  await cached.reader.demand(); assert.equal(cached.jobs.length, 2, 'repeated demand reuses the current validated feed');
  const live = cached.store.home;
  const refresh = cached.reader.refresh();
  assert.equal(cached.store.home, live, 'manual refresh retains the current cards while reading');
  cached.jobs[2].resolve(feed([8])); await refresh;
  assert.equal(cached.store.home.pins[0].id, '8'); assert.equal(cached.reader.bookmark, 'next');
  assert(!cached.store.diskCacheRestored && cached.store.homeNativeReadsReady);
  const failed = fixture(), retained = failed.store.home;
  const request = failed.reader.demand();
  failed.jobs[0].resolve('', 503); failed.jobs[1].resolve(categories); await request;
  assert.equal(failed.store.home, retained); assert(failed.store.homeError); assert(failed.store.diskCacheRestored);
  const retry = failed.reader.retry(); failed.jobs[2].resolve(feed([3])); await retry;
  assert.equal(failed.store.home.pins[0].id, '3');
  const cold = fixture(undefined); cold.store.home = undefined; cold.store.cachedHome = undefined; cold.store.diskCacheRestored = false;
  const initial = cold.reader.demand(); cold.jobs[0].resolve(feed([4])); cold.jobs[1].resolve(categories); await initial;
  assert.equal(cold.store.home.pins[0].id, '4', 'no saved content still reads immediately');
  const switched = fixture(); const priorAccount = switched.reader.demand(); switched.switchAccount();
  const next = switched.reader.demand(); assert.equal(switched.store.home, undefined, 'account change removes the previous account presentation');
  switched.jobs[0].resolve(feed([9])); switched.jobs[1].resolve(categories); await priorAccount;
  switched.jobs[2].resolve(feed([5])); switched.jobs[3].resolve(categories); await next;
  assert.equal(switched.store.home.pins[0].id, '5');
  const hidden = fixture(); hidden.hide(); await hidden.reader.demand(); assert.equal(hidden.jobs.length, 0);
  const cancelled = fixture();
  const interrupted = cancelled.reader.demand(); cancelled.reader.pause();
  cancelled.jobs[0].resolve(feed([9])); cancelled.jobs[1].resolve(categories); await interrupted;
  assert.equal(cancelled.store.home.pins[0].id, '1', 'cancelled refresh cannot replace the retained startup links');
  const boardSnapshot = snapshot(); boardSnapshot.tabs = [
    { id: 'tab:all', label: 'All', selected: false, enabled: true },
    { id: 'tab:123', label: 'Saved board', selected: true, enabled: true }];
  boardSnapshot.selectedTab = 'Saved board';
  const board = fixture(boardSnapshot); const boardStart = board.reader.demand();
  assert.equal(board.reader.board, '123'); assert.equal(board.jobs.length, 3, 'last selected category fetches current feed, summary and categories');
  board.jobs[0].resolve(feed([4])); board.jobs[1].resolve('{}'); board.jobs[2].resolve(categories); await boardStart;
  const selected = board.reader.select('tab:all');
  assert.equal(board.jobs.length, 4, 'switching category starts a current-session read');
  board.jobs[3].resolve(feed([6])); await selected;
  assert.equal(board.store.home.pins[0].id, '6'); assert.equal(board.reader.board, '');
  assert(!board.store.diskCacheRestored && board.store.homeNativeReadsReady);
  const wrongPage = fixture({ ...snapshot(), pageKey: 'https://www.pinterest.com/other/' });
  const corrected = wrongPage.reader.demand();
  assert(wrongPage.jobs.length > 0, 'a mismatched page cannot suppress the actual home read');
  wrongPage.jobs[0].resolve(feed([7])); wrongPage.jobs[1].resolve(categories); await corrected;
  assert.equal(wrongPage.store.home.pageKey, page);
  const empty = fixture({ ...snapshot(), pins: [] }); const pending = empty.reader.demand();
  empty.jobs[0].resolve(feed([])); empty.jobs[1].resolve(categories); await pending;
  assert.equal(empty.store.home.pins.length, 0, 'an empty cache never blocks current validation');
  console.log('Home startup image links: separate downloader seed/short-lived display cache, fresh startup feed, refresh/retry, category switch, no cache, empty, hidden, cancellation and account isolation passed');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
