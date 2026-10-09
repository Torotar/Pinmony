const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_inbox/src/main/ets/components/PinWebInboxPage.ets', 'utf8');
const root = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(source, name) {
  const start = source.search(new RegExp('  (?:private )?' + name + '\\('));
  assert(start >= 0, name);
  const rest = source.slice(start);
  const end = rest.slice(1).search(/\n  (?:private |@Builder|build\()/) + 1;
  return rest.slice(0, end);
}
const timers = [], context = { Number, setTimeout: callback => timers.push(callback),
  ScrollState: { Scroll: 1, Fling: 2 }, HdsAnimationMode: { SCROLL_ANIMATION: 'scroll' } };
const start = page.indexOf('.onDidScroll('), end = page.indexOf('\n        .onScrollStop(', start);
const scroll = page.slice(start, end).replace(/^\.onDidScroll\(/, 'this.didScroll = ').replace(/\)\s*$/, ';');
const code = 'class Page {' + ['aboutToAppear', 'onSnapshotChanged', 'restoreScroll',
  'contentOverflowsViewport', 'reportScrollAvailability', 'releaseScrollMeasurements'].map(name => method(page, name)).join('\n') +
  ' attach() {' + scroll + '} } class Root {' +
  ['setBottomBarHidden', 'updateInboxScrollAvailability', 'handleRootContentScroll'].map(name => method(root, name)).join('\n') +
  '} globalThis.Page = Page; globalThis.Root = Root;';
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
const coordinator = new context.Root(), motions = [];
Object.assign(coordinator, { activeTab: 2, inboxContentScrollable: false,
  rootTabsScrollHidden: [false, false, false, false], childBottomBarRootTab: -1,
  bottomBarScrollCollapseEnabled: true, floatingTabsMounted: true, floatingTabsHidden: false, authStatus: 'authenticated', pinStore: {},
  nativeRootTabsVisible: () => true, tabsController: {
    applyHideAnimation: mode => motions.push({ hidden: true, mode }),
    applyShowAnimation: mode => motions.push({ hidden: false, mode }) } });
const view = new context.Page();
Object.assign(view, { snapshot: { section: 'updates' }, initialScrollOffset: 0,
  contentHeight: 0, viewportHeight: 0, scroller: { scrollTo() {} }, reportScroll() {},
  onScrollAvailability: value => coordinator.updateInboxScrollAvailability(value),
  onContentScroll: (offset, state) => coordinator.handleRootContentScroll(offset, state) });
view.attach(); view.aboutToAppear();
function resize(content, viewport) {
  view.contentHeight = content; view.viewportHeight = viewport; view.reportScrollAvailability();
}
function swipe(offset, state = context.ScrollState.Scroll) { view.didScroll(0, offset, state); }
for (const section of ['updates', 'messages']) {
  view.snapshot = { section }; view.onSnapshotChanged(); timers.splice(0).forEach(callback => callback());
  for (const content of [0, 400, 600, 600.5, Number.NaN]) {
    resize(content, 600); motions.length = 0; swipe(20); swipe(-20);
    assert.equal(motions.length, 0, section + ': short content/bounce does not animate the bar');
    assert.equal(coordinator.rootTabsScrollHidden[2], false);
  }
  resize(900, 600); motions.length = 0; swipe(20);
  assert.equal(motions.at(-1).hidden, true, section + ': overflowing content can collapse on upward swipe');
  assert.equal(coordinator.rootTabsScrollHidden[2], true);
  swipe(-20); assert.equal(motions.at(-1).hidden, false);
  motions.length = 0; swipe(20, context.ScrollState.Fling);
  assert.equal(motions.length, 0, 'inertial motion preserves the existing contract');
  swipe(20); resize(400, 600);
  assert.equal(coordinator.rootTabsScrollHidden[2], false, 'shrunken content clears remembered collapse');
  assert.equal(motions.at(-1).hidden, false);
}
resize(900, 600); swipe(20);
view.snapshot = { section: 'updates' }; view.onSnapshotChanged();
assert.equal(coordinator.rootTabsScrollHidden[2], false, 'changing segment expands before scroll restoration');
motions.length = 0; swipe(20); assert.equal(motions.length, 0, 'programmatic restoration cannot collapse');
timers.splice(0).forEach(callback => callback());
resize(900, 1000); assert.equal(coordinator.inboxContentScrollable, false, 'larger viewport removes overflow');
coordinator.childBottomBarRootTab = 2; coordinator.childBottomBarRestoreHidden = true;
view.releaseScrollMeasurements();
assert.equal(coordinator.childBottomBarRestoreHidden, false, 'loading/error removal cannot restore stale collapsed state');
coordinator.nativeRootTabsVisible = () => false; motions.length = 0;
coordinator.updateInboxScrollAvailability(false);
assert.equal(motions.length, 0, 'a child page remains hidden');
coordinator.nativeRootTabsVisible = () => true; coordinator.activeTab = 0;
motions.length = 0; coordinator.handleRootContentScroll(20, context.ScrollState.Scroll);
assert.equal(motions.at(-1).hidden, true, 'other roots retain their existing behavior');
assert.match(page, /this\.contentHeight = Number\(newArea\.height\)/);
assert.match(page, /this\.viewportHeight = Number\(newArea\.height\)/);
assert.match(root, /onScrollAvailability:.*updateInboxScrollAvailability/);
console.log('Inbox bottom bar: both segments, short content/bounce, overflow, shrink/resize, restoration and child/other-root boundaries passed');
