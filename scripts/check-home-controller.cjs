const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createHomeRuntime } = require('./home-controller-harness.cjs');
let now = 1000, serial = 0;
const timers = new Map(), logs = [];
const globals = { Date: { now: () => now },
  PinmonyRuntimeLog: { info: line => logs.push(line), warn: line => logs.push(line) },
  setTimeout: (fn, delay) => { const id = ++serial; timers.set(id, { fn, due: now + delay }); return id; },
  clearTimeout: id => timers.delete(id) };
const runtime = createHomeRuntime(ts, globals);
const root = 'https://www.pinterest.com/';
const pin = id => ({ id, pinUrl: root + 'pin/' + id + '/', imageUrl: 'https://i.pinimg.com/' + id + '.jpg',
  imageWidth: 200, imageHeight: 300, title: 'title-' + id, hasMore: true });
const tabs = [{ id: 'all', label: '所有', selected: true, enabled: true },
  { id: 'board', label: 'Board', selected: false, enabled: true }];
const snapshot = (session, pins = [pin('123')], changes = {}) => ({ kind: 'state', session, pageKey: root,
  selectedTab: '所有', tabs, pins, dataSource: 'api', ...changes });
const update = (h, message) => h.controller.updateHome(JSON.stringify(message));
const flush = () => new Promise(resolve => setImmediate(resolve));
function tick(ms) {
  now += ms;
  for (const [id, timer] of [...timers]) if (timer.due <= now) { timers.delete(id); timer.fn(); }
}
const defer = () => { let resolve, reject; const promise = new Promise((a,b) => {resolve=a; reject=b;}); return {promise, resolve, reject}; };
async function main() {
  const initial = runtime.harness();
  initial.controller.prepareHomeForPageBegin(root);
  assert(initial.store.homeLoading);
  tick(20000);
  assert.equal(initial.store.homeError, '无法读取当前 Pinterest 首页');
  initial.controller.clearHome();
  initial.controller.expectHome();
  const queued = [...timers.values()][0].fn;
  initial.controller.invalidatePending();
  queued();
  assert.equal(initial.store.homeError, '', 'already queued timer cannot write after cancellation');
  assert.equal(timers.size, 0);

  const retained = runtime.harness({ knownPinTitle: id => id === '456' ? 'confirmed title' : '', isSaved: id => id === '123' });
  const saved = snapshot(9, [pin('123'), pin('456')]);
  retained.store.cachedHome = saved; retained.store.cachedHomeScrollOffset = 400;
  retained.controller.prepareHomeForPageBegin(root);
  assert.equal(retained.store.home, saved);
  assert.equal(retained.store.homeActionsReady, false);
  update(retained, snapshot(1, [pin('789'), pin('456')]));
  assert.deepEqual(Array.from(retained.store.home.pins, item => item.id), ['123','456']);
  assert.equal(retained.store.home.session, 1);
  assert.equal(retained.store.cachedHomeScrollOffset, 400);
  assert.equal(retained.store.home.pins[1].title, 'confirmed title');
  update(retained, snapshot(0, [pin('999')]));
  assert.equal(retained.store.home.session, 1, 'older live sessions cannot replace ready state');
  const kept = retained.store.home;
  update(retained, snapshot(2, [], { kind: 'failed', error: 'real failure' }));
  assert.equal(retained.store.home, kept);
  assert.equal(retained.store.homeError, 'real failure');
  assert.equal(retained.store.homeActionsReady, false);
  update(retained, snapshot(2, [], { kind: 'loading' }));
  assert.equal(retained.store.home, kept);
  await retained.controller.loadMoreHome();
  // The context rebind must use the latest session, never the snapshot read before awaiting.
  retained.ports.ensureContext = async () => { retained.store.homeActionsReady = true; return true; };
  await retained.controller.loadMoreHome();
  update(retained, snapshot(2, [pin('789')]));
  assert.deepEqual(Array.from(retained.store.home.pins, item => item.id), ['123','456','789']);
  retained.controller.refreshHome();
  update(retained, snapshot(3, [pin('777')]));
  assert.deepEqual(Array.from(retained.store.home.pins, item => item.id), ['777'], 'refresh replaces the retained feed');
  retained.controller.invalidatePending();

  const gate = runtime.harness();
  gate.setAccepted(false); update(gate, snapshot(1)); assert.equal(gate.store.home, undefined);
  gate.setAccepted(true); update(gate, snapshot(1, [], { pageKey: root + 'today/' })); assert.equal(gate.store.home, undefined);
  gate.controller.updateHome('{invalid'); assert.equal(gate.store.home, undefined);
  update(gate, snapshot(2, [])); assert.equal(gate.store.home.pins.length, 0);
  assert.equal(gate.store.homeActionsReady, true, 'normal empty state is loaded');
  gate.setPage(''); update(gate, { kind: 'closed', session: 2, pageKey: root }); assert.equal(gate.store.home, undefined);

  const disk = runtime.harness();
  disk.controller.restoreCacheSnapshot(snapshot(0));
  assert.equal(disk.store.homeActionsReady, false);
  update(disk, snapshot(3, []));
  assert.equal(disk.store.home.pins.length, 0, 'current empty response replaces disk presentation');
  assert.equal(disk.store.diskCacheRestored, false);
  assert.equal(disk.store.startupFeedCommitted, true);
  assert.equal(disk.store.diskCacheRestoredAt, 0);

  const contextWait = defer(), waiting = runtime.harness({ ensureContext: () => contextWait.promise });
  update(waiting, snapshot(1));
  const action = waiting.controller.selectHomeTab('board');
  waiting.controller.invalidatePending(); contextWait.resolve(true); await action;
  assert(!waiting.events.some(event => event[0] === 'js'), 'cancelled context cannot dispatch category');

  const preparation = runtime.harness(); update(preparation, snapshot(1));
  preparation.ports.ensureContext = async (_data, current) => {
    preparation.controller.clearHome(); update(preparation, snapshot(8)); return current();
  };
  await preparation.controller.selectHomeTab('board');
  assert(preparation.events.find(event => event[0] === 'js')[1].includes('PinmonyHomeTab(8,'), 'document reset preserves waiting intent and uses fresh session');
  preparation.controller.invalidatePending();

  const scriptWait = defer(), late = runtime.harness({ runScript: () => scriptWait.promise });
  update(late, snapshot(1)); const lateAction = late.controller.selectHomeTab('board'); await flush();
  late.controller.invalidatePending(); const timerCount = timers.size;
  scriptWait.resolve('true'); await lateAction;
  assert.equal(timers.size, timerCount, 'late dispatch result cannot create timers after disposal');
  assert.equal(late.store.pendingHomeTab, '');

  const retryWait = defer(), retry = runtime.harness({ runScript: () => retryWait.promise });
  update(retry, snapshot(1, [pin('123')], { categorySourceFailure: true }));
  retry.controller.refreshHome(); retry.controller.clearHome(); update(retry, snapshot(3));
  retryWait.reject(new Error('old category read')); await flush();
  assert.equal(retry.store.homeError, '', 'late category retry failure cannot overwrite new state');
  assert.equal(retry.store.home.session, 3);

  const pagination = runtime.harness(); update(pagination, snapshot(1)); pagination.store.homeActionsReady = false;
  pagination.ports.ensureContext = async () => { update(pagination, snapshot(9)); return true; };
  await pagination.controller.loadMoreHome();
  assert(pagination.events.find(event => event[0] === 'js')[1].includes('PinmonyHomeLoadMore(9,'));
  await pagination.controller.openHomePin('123');
  assert.deepEqual(pagination.events.at(-1), ['pin',root+'pin/123/',root]);
  assert.equal(pagination.store.cachedHome.pins[0].id, '123');

  const normalized = runtime.cache.normalizeHomeCacheRecord({snapshot:snapshot(99,[pin('123'),{...pin('456'),imageWidth:0}])},root);
  assert.equal(normalized.snapshot.session,0); assert.equal(normalized.snapshot.pins.length,1);
  assert.equal(normalized.snapshot.pins[0].hasMore,false);
  assert.equal(runtime.cache.normalizeHomeCacheRecord({snapshot:snapshot(1,[],{pageKey:root+'today/'})},root),undefined);
  assert.equal(runtime.cache.normalizeHomeBoard({id:'42',name:' Board ',pinCount:3.8,thumbnailUrl:''}).pinCount,3);
  assert.equal(runtime.cache.normalizeHomeBoard({id:'42',name:'Board',pinCount:3,thumbnailUrl:'https://other.invalid/a.jpg'}),undefined);
  const reads=[],writes=[],removed=[];
  let cached={snapshot:snapshot(99)};
  const cache={getWithMetadata(key,ttl){reads.push([key,ttl]);return{value:cached,status:'disk',ageMs:100};},
    put(key,value,ttl){writes.push([key,value,ttl]);},remove(key){removed.push(key);}};
  assert(runtime.cache.readHomeCache(cache,'partition-one',root,'test'));
  assert.equal(reads[0][1],300000);
  let markers=0;
  runtime.cache.writeHomeCache(cache,'partition-one',snapshot(4),()=>markers++);
  runtime.cache.writeHomeCache(cache,'partition-two',snapshot(4),()=>markers++);
  assert.notEqual(writes[0][0],writes[1][0]); assert.equal(markers,2);
  cached={snapshot:snapshot(1,[],{dataSource:'dom'})};
  assert.equal(runtime.cache.readHomeCache(cache,'partition-one',root,'test'),undefined);
  assert.equal(removed.length,1);
  assert.equal(writes[0][1].snapshot.session,0, 'disk cache never persists action session IDs');

  // Exercise the actual Index capability bindings and its remaining auth/persistence gate.
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  function method(name) { const start=index.indexOf('  private '+name+'('); return index.slice(start,index.indexOf('\n  }',start)+4); }
  const Host=require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Host {'+['restoreHomeDiskCache','persistHomeDiskCache','tryRestoreAuthenticatedHome'].map(method).join('\n')+'} Host;',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{...runtime.cache,PinmonyRuntimeLog:globals.PinmonyRuntimeLog});
  cached={snapshot:snapshot(7)};
  const host=new Host(); Object.assign(host,{homeStore:new runtime.Store(),homeApiCache:cache,homeCacheAccountId:'partition-one',
    authStatus:'checking',activeTab:0,pinStore:{confirmedSaves:{isSaved:()=>false}},boardStore:{},searchStore:{knownSearchPinTitles:new Map()},
    rootTabAddresses:new Map(),pinIdentity:url=>url.match(/\/pin\/(\d+)/)?.[1]||'',currentHomePageKey:()=>root,initializeHomeApiCache(){},saveOfflineHomeMarker(){markers++;}});
  runtime.bindIndex(host);
  const priorWrites=writes.length; host.persistHomeDiskCache(snapshot(1)); assert.equal(writes.length,priorWrites);
  host.authStatus='authenticated'; assert(host.restoreHomeDiskCache('partition-one',root,'test'));
  assert.equal(host.homeStore.homeActionsReady,false);
  host.homeController.updateHome(JSON.stringify(snapshot(8)));
  assert.equal(host.homeStore.homeActionsReady,true); assert.equal(writes.length,priorWrites+1);
  const priorReads=reads.length; host.tryRestoreAuthenticatedHome('partition-two',root); assert.equal(reads.length,priorReads);

  assert.doesNotMatch(fs.readFileSync('feature_home/src/main/ets/controllers/PinmonyHomeController.ets','utf8'), /this\.(controller|activeTab|pinStore|searchStore|navigationAddress)\b/);
  for(const signature of ['onPageHide():','aboutToDisappear():']) {
    const start=index.indexOf(signature), end=index.indexOf('\n  }',start); assert(index.slice(start,end).includes('this.homeController.invalidatePending()'));
  }
  for(const name of ['Navigation','Session']) assert(fs.readFileSync('entry/src/main/ets/app/Pinmony'+name+'Coordinator.ets','utf8').includes('this.ports.homeController().invalidatePending()'));
  assert.equal((index.match(/new PinmonyHomeStore\(\)/g)||[]).length,1);
  assert(index.indexOf('homeStore: PinmonyHomeStore = new PinmonyHomeStore()')<index.indexOf('new PinmonyHomeController(this.homeStore'));
  console.log('Home controller: real Store/product binding, retention/refresh/empty states, current-session gates, cancellation, late results, fresh pagination and validated account-scoped cache passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
