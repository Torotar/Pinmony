const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(path, name) {
  const exports = {};
  const source = fs.readFileSync(path, 'utf8').replace(/^import .*;\r?\n/gm, '');
  vm.runInNewContext(ts.transpileModule(source, {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText, {exports});
  return exports[name];
}
const List = load('common_ui/src/main/ets/services/PinmonyListDataSource.ets', 'PinmonyListDataSource');
const Related = load('feature_pin/src/main/ets/models/PinmonyRelatedDataSource.ets', 'PinmonyRelatedDataSource');
const ids = source => Array.from({length:source.totalCount()}, (_, i) => source.getData(i).id);
const items = keys => keys.map(id => ({id}));
const source = new List();
const update = keys => source.update(items(keys), keys);
update(['a','footer']);
const observed = [[],[]];
const listeners = observed.map(log => ({
  onDataAdd: i => { assert.equal(source.key(i), source.getData(i).id); log.push(['add',i,ids(source)]); },
  onDataDelete: i => log.push(['delete',i,ids(source)]),
  onDataReloaded: () => log.push(['reload',ids(source)])
}));
listeners.forEach(listener => source.registerDataChangeListener(listener));
source.registerDataChangeListener(listeners[0]);
update(['a','b','c','footer']);
const additions = [['add',1,['a','b','footer']],['add',2,['a','b','c','footer']]];
observed.forEach(log => assert.deepEqual(log, additions));
observed.forEach(log => {log.length=0;});
update(['a','footer']);
observed.forEach(log => assert.deepEqual(log,[['delete',2,['a','b','footer']],['delete',1,['a','footer']]]));
observed.forEach(log => {log.length=0;});
update(['footer','a']);
observed.forEach(log => assert.deepEqual(log,[['reload',['footer','a']]]));
observed.forEach(log => {log.length=0;});
update(['footer','a']);
observed.forEach(log => assert.deepEqual(log,[]));
source.unregisterDataChangeListener(listeners[0]);
update([]);
assert.equal(observed[0].length,0,'unregistered listeners receive nothing');
assert.equal(source.totalCount(),0);
assert.throws(() => source.update([], ['bad']), /list-key-count/);
const related = new Related();
related.update(items(['a']));
const relatedLogs = [[],[]];
relatedLogs.forEach(log => related.registerDataChangeListener({
  onDataAdd: i => log.push(['add',i,ids(related)]),
  onDataReloaded: () => log.push(['reload',ids(related)])
}));
related.update(items(['a','b','c']));
relatedLogs.forEach(log => assert.deepEqual(log,[['add',1,['a','b']],['add',2,['a','b','c']]]));
related.update(items(['c']));
relatedLogs.forEach(log => assert.deepEqual(log.at(-1),['reload',['c']]));
console.log('List snapshots: batch add/delete, footer, reorder, clear, multiple listeners and related append passed');
