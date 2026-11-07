const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function compile(source, deps = () => ({}), globals = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText,
    { exports, require: deps, console, ...globals });
  return exports;
}
const read = file => fs.readFileSync(file, 'utf8');
function method(source, name) {
  const start = source.search(new RegExp('^  (?:private )?' + name + '\\(', 'm'));
  assert(start >= 0, name);
  const tail = source.slice(start);
  const end = tail.slice(1).search(/\r?\n  (?:private |static |@|on[A-Z]|aboutTo|build\()/);
  return tail.slice(0, end < 0 ? tail.lastIndexOf('\n}') : end + 1);
}
const { PinmonyListDataSource: DataSource } = compile(read('common_ui/src/main/ets/services/PinmonyListDataSource.ets'));
const source = new DataSource(), events = [];
const listener = { onDataAdd: index => events.push(['add', index]), onDataDelete: index => events.push(['delete', index]), onDataReloaded: () => events.push(['reload']) };
source.registerDataChangeListener(listener); source.registerDataChangeListener(listener);
source.update([{ id: 'a' }, { id: 'footer' }], ['a', 'footer']); events.length = 0;
source.update([{ id: 'a' }, { id: 'b' }, { id: 'footer' }], ['a', 'b', 'footer']);
assert.deepEqual(events, [['add', 1]], 'appending before footer preserves existing nodes');
events.length = 0; source.update([{ id: 'a' }, { id: 'footer' }], ['a', 'footer']);
assert.deepEqual(events, [['delete', 1]]);
events.length = 0; source.update([{ id: 'changed' }, { id: 'footer' }], ['changed', 'footer']);
assert.deepEqual(events, [['reload']], 'content changes notify the consumer');
events.length = 0; source.update([{ id: 'changed' }, { id: 'footer' }], ['changed', 'footer']);
assert.equal(events.length, 0, 'loading-only updates do not invalidate nodes');
assert.equal(source.totalCount(), 2); assert.equal(source.getData(0).id, 'changed');
source.unregisterDataChangeListener(listener); source.update([], []); assert.equal(events.length, 0);
assert.throws(() => source.update([{}], []), /list-key-count/);

const { LruCache } = compile(read('common_foundation/src/main/ets/cache/LruCache.ets'));
let evictions = 0;
const cache = new LruCache(10, 10000, () => evictions++, 8, value => value.length * 2);
cache.put('a', 'aa'); cache.put('b', 'bb'); cache.get('a'); cache.put('c', 'cc');
assert.equal(cache.get('b'), null); assert.equal(cache.get('a'), 'aa'); assert.equal(evictions, 1);
cache.remove('a'); assert.equal(cache.totalWeight, 4);
cache.put('c', 'c'); assert.equal(cache.totalWeight, 2, 'replacement removes previous weight');
cache.put('oversized', '12345'); assert.equal(cache.get('oversized'), null);
cache.put('expired', 'a', 1, 10); assert.equal(cache.get('expired'), null); assert.equal(cache.totalWeight, 2);
cache.clear(); assert.equal(cache.totalWeight, 0);

const home = read('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets');
const { Feed } = compile('export class Feed {' + method(home, 'syncFeedRows') + '}');
const feed = new Feed(); Object.assign(feed, { feedRows: new DataSource(), home: { pins: [{ id:'1', imageUrl:'image', title:'title' }], pageKey:'home' }, categoryId:'all', recoveredRevisions:{} });
feed.syncFeedRows(); assert.equal(feed.feedRows.totalCount(), 3, 'both original footer cells are retained');
const firstKey = feed.feedRows.getData(0).key; feed.recoveredRevisions.image = 1; feed.syncFeedRows();
assert.notEqual(feed.feedRows.getData(0).key, firstKey, 'image recovery changes the affected card key');
assert(home.includes('LazyForEach(this.feedRows'));
assert(method(home, 'retryImage').includes('this.syncFeedRows()'), 'manual retry publishes the changed lazy card key');
const search = read('feature_search/src/main/ets/components/PinmonySearchPage.ets');
const { Search } = compile('export class Search {' + method(search, 'syncResultRows') + '}');
const searchHost = new Search(); Object.assign(searchHost, { resultRows:new DataSource(), uiLanguage:'zh', entryQuiz:{}, snapshot:{ pageKey:'search', results:[{id:'1', kind:'pin', title:'title'}] } });
searchHost.syncResultRows(); assert.equal(searchHost.resultRows.totalCount(), 2, 'inspiration is a lazy header row');
searchHost.entryQuiz = undefined; searchHost.syncResultRows(); assert.equal(searchHost.resultRows.totalCount(), 1);
const searchKey = searchHost.resultRows.getData(0).key; searchHost.uiLanguage = 'en'; searchHost.syncResultRows();
assert.notEqual(searchHost.resultRows.getData(0).key, searchKey, 'localized controls invalidate in place');
assert.equal((search.match(/LazyForEach\(this.resultRows/g) || []).length, 3);

let densityReads = 0;
const smart = read('common_ui/src/main/ets/components/SmartImage.ets');
const { ImageHost, pickCoverImageTier } = compile(smart.slice(0, smart.indexOf('@Component')) + 'export class ImageHost {' + method(smart, 'resetImage') + method(smart, 'displayHeightPx') + '}',
  () => ({ display:{ getDefaultDisplaySync(){ densityReads++; return {densityPixels:2}; } } }));
const imageHost = new ImageHost(); Object.assign(imageHost, { images:{'474x':{url:'image'}}, widthVp:200, imageRevision:0 });
imageHost.resetImage(); assert.equal(densityReads, 1, 'one source selection reads density once');
const imageRevision = imageHost.imageRevision; imageHost.resetImage(); assert.equal(imageHost.imageRevision, imageRevision);
const beforeTarget=densityReads,audits=[];
const targeted=new ImageHost();Object.assign(targeted,{images:{'474x':{url:'small'},'736x':{url:'large'}},widthVp:200,heightVp:220,targetPx:400,imageRevision:0,onAudit:(...args)=>audits.push(args)});
targeted.resetImage();assert.equal(targeted.sourceTier,'474x');assert.equal(audits[0][1],400);assert.equal(audits[0][2],440);
targeted.targetPx=600;targeted.resetImage();assert.equal(targeted.sourceTier,'736x','density changes select a sufficiently sharp source');
const targetRevision=targeted.imageRevision;targeted.resetImage();assert.equal(targeted.imageRevision,targetRevision);
assert.equal(densityReads,beforeTarget,'provided pixel targets avoid synchronous display reads, including diagnostics');
assert.equal(pickCoverImageTier({'474x':{url:'image'}},200,NaN),'474x','invalid target keeps the legacy density fallback');

const storage = new Map(), levels = { MEMORY_LEVEL_MODERATE:0, MEMORY_LEVEL_LOW:1, MEMORY_LEVEL_CRITICAL:2, MEMORY_LEVEL_UI_HIDDEN:3 };
const { Ability } = compile('export class Ability {' + method(read('entry/src/main/ets/entryability/EntryAbility.ets'), 'onMemoryLevel') + '}', () => ({}),
  { AbilityConstant:{MemoryLevel:levels}, AppStorage:{get:key=>storage.get(key),setOrCreate:(key,value)=>storage.set(key,value)}, PinmonyRuntimeLog:{info(){}} });
const ability = new Ability(); ability.onMemoryLevel(0); ability.onMemoryLevel(3); assert.equal(storage.size, 0);
ability.onMemoryLevel(1); ability.onMemoryLevel(2); assert.equal(storage.get('pinmonyMemoryPressureSequence'), 2);
const { Product } = compile('export class Product {' + method(read('entry/src/main/ets/pages/Index.ets'), 'trimPresentationMemory') + '}', () => ({}), { PinmonyRuntimeLog:{info(){}} });
const product = new Product(), trims = [];
Object.assign(product, {homeApiCache:{trimMemory:()=>trims.push('home')},detailReadCache:{trimMemory:()=>trims.push('responses')},detailNativeReads:{trimMemory:()=>trims.push('related')},pinStore:{detailPin:'active',detailOpeningPin:'',detailPrefetch:{clear:()=>trims.push('prefetch')},prefetchedImageUrls:['image'],detail:{title:'retained'}}});
product.trimPresentationMemory(); assert.deepEqual(trims, ['home','responses','related']); assert.equal(product.pinStore.detail.title, 'retained');
product.pinStore.detailPin = ''; product.trimPresentationMemory(); assert(trims.includes('prefetch'));
assert.equal(product.pinStore.prefetchedImageUrls.length, 0);
console.log('Global performance: lazy append/delete/update, weighted cache eviction, image selection, pressure dispatch and active presentation preservation passed');
