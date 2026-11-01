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
const native = {}, pauses = [], resumes = [], hostEvents = [];
native.profileSearchReads = { pause() { hostEvents.push('search-pause'); },
  resume() { hostEvents.push('search-resume'); }, close() { hostEvents.push('search-close'); } };
native.inboxMenuNative = { pause() { hostEvents.push('menu-pause'); } };
native.boardInvitationNative = { pause() { hostEvents.push('invitation-pause'); } };
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
assert.deepEqual(hostEvents, [], 'ordinary route coordination does not pause host-only participants');
native.controllerLifecycle().background();
assert.deepEqual(hostEvents.splice(0), ['search-pause', 'menu-pause', 'invitation-pause']);
native.controllerLifecycle().resumeHost();
assert.deepEqual(hostEvents.splice(0), ['search-resume'], 'only explicitly resumable reads restart');
native.controllerLifecycle().resetHost();
assert.deepEqual(hostEvents.splice(0), ['search-close', 'menu-pause', 'invitation-pause'], 'account reset closes search');
native.controllerLifecycle().destroy();
assert.deepEqual(hostEvents.splice(0), ['search-pause', 'menu-pause', 'invitation-pause'], 'destruction cancels host work');
const isolated = [];
const hostRegistry = new exported.PinmonyControllerLifecycle([
  { name: 'regular', pause() { isolated.push('regular'); } }
], [
  { name: 'failed-host', pause() { throw Error('synthetic'); }, reset() { throw Error('synthetic'); } },
  { name: 'remaining-host', pause() { isolated.push('host'); }, reset() { isolated.push('reset'); } }
]);
hostRegistry.background(); hostRegistry.resetHost();
assert.deepEqual(isolated, ['host', 'regular', 'reset'], 'one failed participant cannot stop remaining cleanup');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const hide = source.slice(source.indexOf('  onPageHide():'), source.indexOf('  private pageBackToken:'));
const destroy = source.slice(source.indexOf('  aboutToDisappear():'), source.indexOf('  private ', source.indexOf('  aboutToDisappear():')));
assert(hide.includes('this.controllerLifecycle().background()'), 'background uses registered host cleanup');
assert(destroy.includes('this.controllerLifecycle().destroy()'), 'destruction uses registered host cleanup');
assert(!hide.includes('this.profileSearchReads.pause()') && !hide.includes('this.inboxMenuNative.pause()'),
  'host cleanup is registered once rather than duplicated in page callbacks');
console.log('Controller lifecycle: real Index registration, order, failure isolation and result-only resume hooks passed');
