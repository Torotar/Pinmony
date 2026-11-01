const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  private onRootPageVisible(');
const end = source.indexOf('\n  private ', start + 1);
assert(start >= 0 && end > start);
const context = { PIN_NATIVE_PROFILE_READS_ENABLED: true, PIN_NATIVE_INBOX_UPDATES_ENABLED: false,
  PIN_NATIVE_INBOX_MESSAGES_ENABLED: false, PIN_NATIVE_SEARCH_DISCOVERY_ENABLED: false };
vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} globalThis.Host = Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText, context);
function harness() {
  const host = new context.Host(), tasks = [];
  let reads = 0, pauses = 0;
  Object.assign(host, { activeTab: 3, tabRequestToken: 1, visible: true,
    nativeRootTabsVisible() { return this.visible; }, usesNativeProfileReads: () => true,
    profileStore: {}, pagePerformance: { mark() {} }, markRootPerformance() {},
    coordinatorTasks: { timeout(callback, delay) { tasks.push({ callback, delay }); } },
    profileNativeReads: { demand() { reads++; }, pause() { pauses++; } } });
  return { host, tasks, reads: () => reads, pauses: () => pauses };
}
const current = harness(); current.host.onRootPageVisible(3, true);
assert.equal(current.reads(), 0, 'request stays outside visibility callback');
assert.equal(current.tasks.length, 1); assert.equal(current.tasks[0].delay, 0);
current.tasks[0].callback(); assert.equal(current.reads(), 1);
for (const change of [h => { h.activeTab = 0; }, h => { h.tabRequestToken++; }, h => { h.visible = false; }]) {
  const stale = harness(); stale.host.onRootPageVisible(3, true); change(stale.host);
  stale.tasks[0].callback(); assert.equal(stale.reads(), 0, 'stale visibility cannot dispatch');
}
const hidden = harness(); hidden.host.onRootPageVisible(3, false);
assert.equal(hidden.tasks.length, 0); assert.equal(hidden.pauses(), 1);
console.log('Profile visible demand: zero-delay async start and tab/token/visibility guards passed');
