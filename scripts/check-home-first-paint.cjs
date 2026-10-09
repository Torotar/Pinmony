const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const page = fs.readFileSync('feature_home/src/main/ets/components/PinWebHomePage.ets', 'utf8');
const store = fs.readFileSync('feature_home/src/main/ets/stores/PinWebHomeStore.ets', 'utf8');
const auth = fs.readFileSync('common_session/src/main/ets/models/PinWebAuth.ets', 'utf8');
assert.match(page, /lastHomePinCount: number = 0/, 'home tracks the initial API pin count');
assert.match(page, /const firstApiSnapshot: boolean = this\.home\.dataSource === 'api'/,
  'home identifies the first non-empty API snapshot');
assert.match(page, /if \(firstApiSnapshot\) this\.prefetchNotBefore = Date\.now\(\) \+ 900;/,
  'home delays pagination after the first card snapshot');
assert.match(page, /if \(this\.chromeScrollDistance >= 6\)/,
  'home chrome collapses after a short same-direction scroll');
assert.match(page, /this\.homeChromeCollapsed && direction < 0 \? 18 : 6/,
  'home chrome uses hysteresis before expanding on a slow reverse scroll');
assert.match(page, /if \(direction !== this\.chromeScrollDirection\)[\s\S]*?this\.chromeScrollDistance = 0;/,
  'reversing scroll direction resets the collapse distance');
function method(source, name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const tail = source.slice(start);
  const end = tail.slice(1).search(/\n  (?:private |@Builder|build\()/) + 1;
  return tail.slice(0, end);
}
const code = auth.replace(/export /g, '') + '\n' +
  store.replace(/^import .*;\s*$/gm, '').replace('@Observed', '').replace('export class', 'class') +
  '\nclass Native {\n' + ['homePageKeyFromAddress', 'isHomeRootAddress', 'homePresentationPageKey',
    'prepareHomeForPageBegin', 'expectHome', 'clearHome', 'clearRootTabCaches'].map(name => method(index, name)).join('\n') + '\n}\n' +
  'class Feed {\n' + method(page, 'canShowFeed') + '\n}\n' +
  'globalThis.Store=PinWebHomeStore;globalThis.Native=Native;globalThis.Feed=Feed;';
const root = 'https://www.pinterest.com/';
const timers = [];
const context = { PINTEREST_URL: root, PinWebRuntimeLog: { info() {}, warn() {} },
  setTimeout: callback => { timers.push(callback); return timers.length; } };
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);

const saved = { kind: 'state', session: 9, pageKey: root, selectedTab: '所有',
  tabs: [{ id: 'tab:all', label: '所有', selected: true }], pins: [{ id: '123' }] };
const home = new context.Store();
home.cachedHome = saved;
assert.equal(home.homeForPresentation(root), saved, 'return displays matching runtime cache before live data arrives');
assert.equal(home.homeForPresentation(root + 'today/'), undefined, 'another page cannot reuse a cached feed');
home.home = { ...saved, kind: 'loading', pins: [] };
assert.equal(home.homeForPresentation(root), home.home, 'explicit new loading state is not silently replaced by old Pins');
home.home = { ...saved, pins: [] };
assert.equal(home.homeForPresentation(root).pins.length, 0, 'a confirmed empty response remains empty');
home.home = undefined;

let address = root + 'inbox/';
const native = new context.Native();
Object.assign(native, { homeStore: home, authStatus: 'authenticated', activeTab: 0, currentWebTab: 2,
  pendingWebTab: 0, loadFailed: false, profileSettingsVisible: false, pinStore: {}, boardStore: {},
  profileStore: { origins: [], profileCache: { clear() {} } },
  inboxStore: { inboxCache: { clear() {} } }, searchStore: { searchCache: { clear() {} } },
  rootTabAddresses: new Map([[0, root]]), nativeDisplayAddress: () => address,
  clearSearch() {}, clearProfile() {}, clearInbox() {} });
assert.equal(native.homePresentationPageKey(), root, 'pending home tab is presented while Web still shows inbox');
native.rootTabAddresses.set(0, 'https://other.example/');
assert.equal(native.homePresentationPageKey(), '', 'untrusted retained routes cannot expose a cached page');
native.rootTabAddresses.set(0, root);
native.authStatus = 'checking';
assert.equal(native.homePresentationPageKey(), '', 'cache cannot bypass login evidence');
native.authStatus = 'authenticated';
native.pinStore.detailOpeningPin = root + 'pin/123/';
assert.equal(native.homePresentationPageKey(), '', 'home cannot cover an opening detail page');
native.pinStore.detailOpeningPin = '';
native.activeTab = 1;
assert.equal(native.homePresentationPageKey(), '', 'quick tab switches do not leave home visible');
native.activeTab = 0; native.pendingWebTab = -1; native.currentWebTab = 0; address = root + 'login/';
assert.equal(native.homePresentationPageKey(), root, 'confirmed login can present a native shell before home document starts');
native.clearRootTabCaches();
assert.equal(home.homeForPresentation(root), undefined, 'session reset removes cache from presentation');
native.prepareHomeForPageBegin(root);
assert.equal(home.homeLoading, true, 'first home navigation starts a skeleton before bridge data');
timers.shift()();
assert.ok(home.homeError, 'first load does not leave a skeleton spinning forever');
home.cachedHome = saved;
native.prepareHomeForPageBegin(root);
assert.equal(home.home, saved, 'the same page restores completed cards immediately');
assert.equal(home.homeLoading, false, 'cache synchronization does not become a full-page loader');
timers.shift()();
assert.ok(home.homeError, 'failed cache synchronization reports a bounded, retryable error');
assert.equal(home.home, saved, 'synchronization timeout keeps visible cards');
native.prepareHomeForPageBegin(root);
home.homeActionsReady = true;
timers.shift()();
assert.equal(home.homeError, '', 'a completed synchronization ignores its old timeout');
native.prepareHomeForPageBegin(root);
native.clearRootTabCaches();
timers.shift()();
assert.equal(home.homeError, '', 'a cleared session cannot receive a delayed loading error');

const feed = new context.Feed();
Object.assign(feed, { home: saved, pendingTabId: '', loading: true, synchronizing: true, error: '' });
assert.equal(feed.canShowFeed(), true, 'background loading does not blank completed cards');
feed.error = 'refresh failed';
assert.equal(feed.canShowFeed(), true, 'refresh failure keeps cards with an error notice');
feed.pendingTabId = 'tab:all';
assert.equal(feed.canShowFeed(), true, 'restoring the same category keeps its cards');
feed.pendingTabId = 'tab:other';
assert.equal(feed.canShowFeed(), false, 'switching categories never presents old cards under a new selection');
feed.home = { ...saved, pins: [] }; feed.pendingTabId = '';
assert.equal(feed.canShowFeed(), false, 'first load and empty results do not invent content');
console.log('Home first paint: runtime cache, early shell, auth/route guards, category isolation and failure retention passed');
