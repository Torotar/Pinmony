const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript'), out = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyBottomBarCoordinator.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: out, require: () => ({ HdsAnimationMode: { CLICK_ANIMATION: 1, SCROLL_ANIMATION: 0 } }) });
let mounted = false, hidden = true, scroll = [true, true, true, true], child = true, root = 3, token = 1, visible = true;
const calls = [];
const coordinator = new out.PinmonyBottomBarCoordinator({ floatingTabsMounted: () => mounted,
  floatingTabsHidden: () => hidden, setFloatingTabsHidden: value => hidden = value,
  rootTabsScrollHidden: () => scroll, setRootTabsScrollHidden: value => scroll = value,
  childBottomBarRestoreHidden: () => child, setChildBottomBarRestoreHidden: value => child = value,
  childBottomBarRootTab: () => root, setChildBottomBarRootTab: value => root = value,
  floatingTabsMotionToken: () => token, setFloatingTabsMotionToken: value => token = value,
  authStatus: () => 'authenticated', nativeRootTabsVisible: () => visible,
  tabsController: () => ({ applyShowAnimation: () => calls.push('show'), applyHideAnimation: () => calls.push('hide') }) });
coordinator.resetForSession(); assert.equal(calls.length, 0, 'no platform animation before mounting');
assert.equal(scroll.every(x => x === false), true); assert.equal(child, null); assert.equal(root, -1);
mounted = true; hidden = false; coordinator.resetForSession();
assert.deepEqual(calls, ['show'], 'a reused controller gets an explicit show even when the local flag was false');
assert.equal(hidden, false);
visible = false; coordinator.resetForSession(); assert.equal(calls.length, 1, 'session reset cannot expose the bar over a child');
console.log('Bottom bar session: reset scroll/depth state, mounting, explicit platform show and child gate passed');
let active = 3, opening = false;
const tasks = [];
coordinator.ports.activeTab = () => active;
coordinator.ports.pinStore = () => ({ detailOpeningPin: opening });
coordinator.ports.coordinatorTasks = () => ({ timeout: task => tasks.push(task) });
visible = true; hidden = false; scroll[3] = true;
coordinator.resumeAfterForeground(); tasks.shift()();
assert.equal(scroll[3], false); assert.equal(calls.at(-1), 'show', 'foreground resends show even when local flag says visible');
visible = false; hidden = false;
coordinator.resumeAfterForeground(); tasks.shift()();
assert.equal(hidden, true); assert.equal(calls.at(-1), 'hide', 'foreground never exposes tabs over a board');
visible = true; opening = true;
coordinator.resumeAfterForeground(); tasks.shift()();
assert.equal(hidden, true, 'opening detail remains hidden');
opening = false; visible = true; hidden = true;
coordinator.resumeAfterForeground(); visible = false; tasks.shift()();
assert.equal(hidden, true, 'navigation between scheduling and reconciliation uses latest depth');
mounted = false; const count = calls.length;
coordinator.resumeAfterForeground(); tasks.shift()(); assert.equal(calls.length, count);
console.log('Bottom bar foreground: explicit reconciliation, scroll expansion, child/opening gates and unmounted controller passed');
