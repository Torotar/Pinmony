const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  const end = source.indexOf('\n  private ', start + 1);
  assert(start >= 0 && end > start);
  return source.slice(start, end);
}
const context = { PIN_NATIVE_HOME_READS_ENABLED: true, PIN_NATIVE_SEARCH_DISCOVERY_ENABLED: false,
  PIN_NATIVE_INBOX_UPDATES_ENABLED: false, PinmonyI18n: { isText: () => false } };
vm.runInNewContext(ts.transpileModule('class Host {' + method('confirmBusinessSession') + method('onRootPageVisible') +
  '} globalThis.Host = Host;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
function fixture() {
  const host = new context.Host(), tasks = []; let reads = 0, confirms = 0;
  Object.assign(host, { activeTab: 0, tabRequestToken: 1, visible: true, authStatus: 'authenticated',
    nativeBusinessRoutesEnabled: true, homeStore: {}, networkNotice: '',
    nativeRootTabsVisible() { return this.visible; },
    pagePerformance: { mark() {} }, markRootPerformance() {},
    businessSession: { confirm() { confirms++; } },
    coordinatorTasks: { timeout(callback, delay) { tasks.push({ callback, delay }); } },
    homeNativeReads: { demand() { reads++; } } });
  return { host, tasks, reads: () => reads, confirms: () => confirms };
}
for (const entry of ['auth', 'visible']) {
  const f = fixture();
  if (entry === 'auth') f.host.confirmBusinessSession(); else f.host.onRootPageVisible(0, true);
  assert.equal(f.tasks.length, 1); assert.equal(f.tasks[0].delay, 0);
  assert.equal(f.reads(), 0, 'read remains asynchronous');
  if (entry === 'auth') assert.equal(f.confirms(), 1, 'session confirmed before scheduling');
  f.tasks[0].callback(); assert.equal(f.reads(), 1);
}
for (const mutate of [h => { h.activeTab = 1; }, h => { h.tabRequestToken++; }, h => { h.visible = false; }]) {
  const f = fixture(); f.host.onRootPageVisible(0, true); mutate(f.host);
  f.tasks[0].callback(); assert.equal(f.reads(), 0);
}
const unauthenticated = fixture(); unauthenticated.host.authStatus = 'checking';
unauthenticated.host.confirmBusinessSession(); assert.equal(unauthenticated.tasks.length, 0);
const hidden = fixture(); hidden.host.onRootPageVisible(0, false); assert.equal(hidden.tasks.length, 0);
console.log('Home demand latency: async zero-delay auth/visible entry, session confirmation and stale visibility guards passed');
