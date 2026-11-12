const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const { PinmonyHomeStore } = require('./arkts-module-loader.cjs').createArktsLoader(ts)
  .loadFile('feature_home/src/main/ets/stores/PinmonyHomeStore.ets');
const source = fs.readFileSync('entry/src/main/ets/app/PinmonyHomeNativeReads.ets', 'utf8');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, { exports: exportsObject, console, require: withLocalMessages(name =>
  name === 'common_network' ? { PIN_BUSINESS_PIN_READ_ENABLED: true } :
    { PinmonyRuntimeLog: { info() {} } }) });
const { PinmonyHomeNativeReads } = exportsObject;
const response = (ids, bookmark = 'next') => JSON.stringify({ resource_response: {
  status: 'success', bookmark, data: ids.map(id => ({ type: 'pin', id: String(id),
    images: { '474x': { url: 'https://i.pinimg.com/474x/' + id + '.jpg', width: 474, height: 700 } } }))
} });
const categories = JSON.stringify({ resource_response: { status: 'success', data: [] } });
const flush = () => new Promise(resolve => setImmediate(resolve));
function fixture() {
  let active = true, session = { authenticated: true, generation: 1, accountId: 'fixture', origin: 'https://www.pinterest.com' };
  const store = new PinmonyHomeStore(), jobs = [], commits = [];
  const reader = new PinmonyHomeNativeReads({ store: () => store, session: () => session,
    username: () => 'reader', active: () => active, saved: () => false,
    network: () => ({ cancel() {}, requestBusinessHomeRead: job => new Promise(resolve => jobs.push({ job,
      resolve: (body, status = 200) => resolve({ status, error: '', body }) })) }),
    committed: (snapshot, kind) => commits.push({ snapshot, kind }) });
  return { store, jobs, commits, reader, setActive: value => active = value,
    changeAccount: () => session = { ...session, generation: 2, accountId: 'other' } };
}
async function initial(f) {
  const pending = f.reader.demand();
  f.jobs[0].resolve(response([1])); f.jobs[1].resolve(categories); await pending;
}
async function main() {
  const f = fixture(); await initial(f);
  const retained = f.store.home;
  const refresh = f.reader.refresh();
  assert.equal(f.store.home, retained, 'retains cached cards while the feed request is pending');
  assert(f.store.homeRefreshing);
  assert.equal(f.reader.bookmark, 'next');
  f.jobs[2].resolve(response([2, 3, 4, 5, 6, 7], 'new-cursor'));
  await flush();
  assert.equal(f.store.home.pins[0].id, '2', 'validated new list commits without any image completion callback');
  assert.equal(f.store.home.pins.length, 6, 'a slow or failed image cannot withhold the whole batch');
  assert.equal(f.reader.bookmark, 'new-cursor', 'cursor and feed commit together');
  assert.equal(f.store.homeRefreshing, false); await refresh;
  const more = f.reader.more(); f.jobs[3].resolve(response([8], 'next-page')); await more;
  assert.equal(f.store.home.pins.length, 7, 'pagination remains incremental');
  for (const revoke of [g => g.reader.pause(), g => g.setActive(false), g => g.changeAccount(),
    g => g.store.cachedHomeScrollOffset += 10]) {
    const g = fixture(); await initial(g); const old = g.store.home;
    const pending = g.reader.refresh(); revoke(g); g.jobs[2].resolve(response([9], 'uncommitted'));
    await pending;
    assert.equal(g.store.home, old, 'cancelled, hidden, changed-account or scrolled reads retain the prior feed');
    assert.equal(g.reader.bookmark, 'next');
  }
  const failed = fixture(); await initial(failed); const old = failed.store.home;
  const pending = failed.reader.refresh(); failed.jobs[2].resolve('unavailable', 503); await pending;
  assert.equal(failed.store.home, old); assert(failed.store.homeError); assert(!failed.store.homeRefreshing);
  assert.equal(failed.reader.bookmark, 'next');
  const retry = failed.reader.retry(); failed.jobs[3].resolve(response([8], 'retry-next')); await retry;
  assert.equal(failed.store.home.pins[0].id, '8'); assert.equal(failed.reader.bookmark, 'retry-next');
  const empty = failed.reader.refresh(); failed.jobs[4].resolve(response([], '-end-')); await empty;
  assert.equal(failed.store.home.pins.length, 0, 'validated empty result is not replaced by stale cache');
  assert.equal(failed.store.home.endReached, true);
  const disk = fixture();
  disk.store.home = { kind: 'state', session: 0, pageKey: 'https://www.pinterest.com/', selectedTab: '',
    tabs: [], pins: [{ id: 'old', imageUrl: 'https://i.pinimg.com/474x/old.jpg' }], dataSource: 'api' };
  disk.store.cachedHome = disk.store.home; disk.store.diskCacheRestored = true;
  const startup = disk.reader.demand(); const cached = disk.store.home;
  assert.equal(disk.store.home, cached);
  assert.equal(disk.jobs.length, 2, 'startup reads the current feed and categories instead of staying on old content');
  assert.equal(disk.store.homeNativeReadsReady, false, 'cached presentation does not grant current feed actions');
  disk.jobs[0].resolve(response([10])); disk.jobs[1].resolve(categories); await startup;
  assert.equal(disk.store.home.pins[0].id, '10'); assert.equal(disk.store.diskCacheRestored, false);
  for (const path of ['entry/src/main/ets/app/PinmonyHomeNativeReads.ets', 'entry/src/main/ets/pages/Index.ets', 'common_ui/Index.ets']) {
    assert.doesNotMatch(fs.readFileSync(path, 'utf8'), /PinmonyImageRefreshPreparation|prepareImages|HomeRefreshImageTrace/,
      'removed batch gate has no remaining producer, port or export: ' + path);
  }
  assert(!fs.existsSync('common_ui/src/main/ets/services/PinmonyImageRefreshPreparation.ets'));
  const pane = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
  assert.match(pane, /PinmonyCdnImage\(\{ url: url, useSharedDecode: false, viewportOnly: false,/,
    'home hidden prefetch uses native Image cache, not RCP/shared JPEG decode');
  assert.match(pane, /useSharedDecode: false, viewportOnly: false/,
    'cached cards allow offscreen admission with independent decode/failure callbacks');
  console.log('Home refresh images: progressive immediate commit, disk cache, independent photos, cursor, pagination, empty, read failure/retry, scroll/cancel/account isolation and native prefetch passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
