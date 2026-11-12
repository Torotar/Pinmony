const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  const end = source.indexOf('\n  }', start);
  return source.slice(start, end + 4);
}
assert(source.includes('.onStateChange((state: RefreshStatus) => { this.queueRefreshState(state); })'));
assert(!source.includes('.onStateChange((state: RefreshStatus) => { this.refreshGestureState = state; })'));
assert.match(source.slice(source.indexOf('  aboutToDisappear()'), source.indexOf('  private notifyChromeChanged')),
  /this\.cancelRefreshStateUpdate\(\)/);
const timers = new Map();
let serial = 0;
const context = { setTimeout: fn => { timers.set(++serial, fn); return serial; }, clearTimeout: id => timers.delete(id) };
vm.runInNewContext(ts.transpileModule('class Feed {\n' + method('cancelRefreshStateUpdate') + '\n' +
  method('queueRefreshState') + '\n}\nglobalThis.Feed = Feed;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, context);
const feed = new context.Feed();
Object.assign(feed, { refreshStateTimer: -1, refreshStateRevision: 0, paneMounted: true,
  home: { pageKey: 'home', session: 1 }, categoryId: 'all' });
let state = 0, writes = 0;
Object.defineProperty(feed, 'refreshGestureState', { get: () => state, set: value => { state = value; writes++; } });
function flush() { const callbacks = [...timers.values()]; timers.clear(); callbacks.forEach(fn => fn()); }
feed.queueRefreshState(3);
const late = [...timers.values()][0];
feed.queueRefreshState(4);
assert.equal(writes, 0, 'render-time callback must not write @State');
assert.equal(timers.size, 1, 'only the latest event remains scheduled');
late();
assert.equal(writes, 0, 'superseded callbacks cannot commit');
flush();
assert.equal(state, 4);
assert.equal(writes, 1);
feed.queueRefreshState(4); flush();
assert.equal(writes, 1, 'unchanged state does not trigger another render');
for (const next of [1, 2, 3, 4, 0]) {
  feed.queueRefreshState(next); assert.notEqual(state, next); flush(); assert.equal(state, next);
}
feed.queueRefreshState(2);
const destroyed = [...timers.values()][0];
feed.cancelRefreshStateUpdate(); feed.paneMounted = false;
assert.equal(timers.size, 0);
feed.paneMounted = true; destroyed();
assert.equal(state, 0, 'a callback from an old mount cannot update a new mount');
for (const change of [() => feed.home.session++, () => { feed.home.pageKey = 'other'; }, () => { feed.categoryId = 'other'; }]) {
  feed.queueRefreshState(2); change(); flush(); assert.equal(state, 0, 'changed feed identity rejects the queued event');
}
feed.paneMounted = false; feed.queueRefreshState(2);
assert.equal(timers.size, 0, 'unmounted pane does not schedule work');
console.log('Home refresh render safety: deferred commit, latest-event coalescing, all refresh states, lifecycle cleanup and stale-feed isolation passed');
