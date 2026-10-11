const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript'), exported = {}, events = [];
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyControllerLifecycle.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText,
{ exports: exported, require: () => ({ PinmonyRuntimeLog: { warn: message => events.push(message) } }) });
const registry = new exported.PinmonyControllerLifecycle([
  { name: 'failed', pause() { throw Error('failed'); } },
  { name: 'read', pause() { events.push('pause'); }, resume() { events.push('read-result'); } }
]);
registry.pause(); registry.resume(); assert.equal(events.at(-1), 'read-result'); assert(events.includes('pause'));
const native = {}, pauses = [], resumes = [];
for (const name of ['boardCollaborators','publish','boardInvitation','boardState','postPanels','profileRead','profileActions','inboxRead','detail','detailRead','detailOperations','sharePanels','settings','inboxActions']) {
  native[name + 'Controller'] = { pause() { pauses.push(name); }, resume() { resumes.push(name); } };
}
require('./controller-lifecycle-harness.cjs').bind(native, ts);
native.rootPullKind='search';native.finishRootPull=kind=>{assert.equal(kind,'search');native.rootPullKind='';};
native.homeStore.customHomeMenu={};native.dismissShareSheet=()=>{native.homeStore.customHomeMenu=undefined;};
native.coordinatorTasks.timeout(()=>{throw Error('stale timer');},1000);
native.controllerLifecycle().pause(); native.controllerLifecycle().resume();
assert.equal(native.coordinatorTasks.pendingCount(),0);assert.equal(native.rootPullKind,'');assert.equal(native.homeStore.customHomeMenu,undefined);
assert.equal(pauses.length, 14); assert.equal(resumes.length, 7);
assert(!resumes.includes('boardCollaborators'), 'collaborators retain their existing explicit result poll');
assert.equal(native.controllerLifecycle(), native.controllerLifecycle(), 'one registry per Index instance');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const product = ['Navigation','Session'].map(name => fs.readFileSync('entry/src/main/ets/app/Pinmony'+name+'Coordinator.ets','utf8')).join('\n');
assert.equal((source.match(/this\.controllerLifecycle\(\)\.pause\(\)/g) || []).length + (product.match(/this\.ports\.controllerLifecycle\(\)\.pause\(\)/g)||[]).length,5);
console.log('Controller lifecycle: real Index registration, order, failure isolation and result-only resume hooks passed');
