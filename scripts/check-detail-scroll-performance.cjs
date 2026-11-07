const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const read = file => fs.readFileSync(file, 'utf8');
function compile(source, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: name => dependencies[name] || {}, Observed: value => value, Date });
  return exports;
}
function method(source, name) {
  const ast = ts.createSourceFile('fixture.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
  let result;
  function visit(node) {
    if (ts.isMethodDeclaration(node) && node.name.getText(ast) === name) result = node.getText(ast);
    ts.forEachChild(node, visit);
  }
  visit(ast); assert(result, name); return result;
}
const { PinmonyDetailCache } = compile(read('feature_pin/src/main/ets/services/PinmonyDetailCache.ets'));
class EmptyService {}
const storeText = read('feature_pin/src/main/ets/stores/PinmonyPinStore.ets');
const { PinmonyPinStore } = compile(storeText, {
  '../models/PinmonyVisualSearch': { emptyVisualResult: () => ({}) },
  '../services/PinmonyDetailCache': { PinmonyDetailCache },
  '../services/PinmonyConfirmedSaves': { PinmonyConfirmedSaves: EmptyService },
  '../services/PinmonyDetailPrefetch': { PinmonyDetailPrefetch: EmptyService }
});
const hostText = read('entry/src/main/ets/pages/Index.ets');
const { Host } = compile('export class Host {' + method(hostText, 'saveDetailScrollPosition') + '}');
const pin = 'https://www.pinterest.com/pin/11/';
const raw = new PinmonyPinStore(); raw.detailPin = pin;
raw.detailCache.put('11', { pinUrl: pin, actions: [], related: [], shuffle: { id: '22', items: [] } }, 0);
// A shallow observer sees top-level writes. Live scroll recording must only
// mutate its unobserved holder, while lifecycle assignments remain available.
const writes = [];
const store = new Proxy(raw, { set(target, key, value) {
  writes.push(String(key)); return Reflect.set(target, key, value);
} });
const host = new Host();host.pinStore = store;
host.pinIdentity = value => value.match(/\/pin\/(\d+)/)?.[1] || '';
for (let offset = 8; offset <= 2400; offset += 8) host.saveDetailScrollPosition(pin, offset);
assert.deepEqual(writes, [], '300 live scroll samples do not assign observable store fields');
assert.equal(store.detailScrollOffset, 2400, 'navigation can immediately read the newest position, without waiting for scroll stop');
assert.equal(store.detailCache.get('11').scrollOffset, 2400, 'retained parent position stays current during a fling');
host.saveDetailScrollPosition('https://www.pinterest.com/pin/99/', 900);
host.saveDetailScrollPosition('', 900);
assert.equal(store.detailScrollOffset, 2400, 'late callbacks from a different Pin cannot overwrite position');
store.recordDetailScrollOffset(NaN);store.recordDetailScrollOffset(Infinity);
assert.equal(store.detailScrollOffset, 2400, 'invalid coordinates cannot poison restoration');
store.recordDetailScrollOffset(-12);assert.equal(store.detailScrollOffset, 0);
store.recordDetailScrollOffset(321);store.detailScrollOffset = 0;
assert.equal(store.detailScrollOffset, 0, 'existing navigation and session reset assignments still clear position');
assert.deepEqual(writes, ['detailScrollOffset']);
for (let entry = 0; entry < 20; entry++) {
  store.detailScrollOffset = 0;
  raw.detailCache.put('11', { pinUrl: pin, actions: [], related: [], shuffle: { id: '22', items: [] } }, 0);
  writes.length = 0;
  for (let offset = 8; offset <= 800; offset += 8) host.saveDetailScrollPosition(pin, offset);
  assert.deepEqual(writes, [], 'reopening a cached Pin does not restore per-frame observable writes');
  assert.equal(raw.detailCache.get('11').scrollOffset, 800);
  assert.equal(raw.detailCache.size(), 1, 'repeated entry does not accumulate duplicate cache entries');
}
raw.detailCache.clear();host.saveDetailScrollPosition(pin, 456);
assert.equal(raw.detailCache.size(), 0, 'late scroll recording does not recreate cleared cache entries');
const page = read('feature_pin/src/main/ets/components/PinmonyDetailPage.ets');
assert.match(page, /\.onScrollStop\(\(\) => this\.reportScrollPosition\(true\)\)/, 'final precise sample remains enabled');
assert.match(page, /\.cachedCount\(12, true\)/, 'detail recommendations prepare the native image cache window');
assert(!method(page, 'recommendDensity').includes('getDefaultDisplaySync'));
assert.match(storeText, /interface PinmonyDetailScrollPosition/);
assert(!storeText.includes('@Observed\ninterface PinmonyDetailScrollPosition'));
console.log('Detail scroll: unobserved live bookkeeping, exact cache position, stale Pin guard, reset and offscreen preloading passed');
