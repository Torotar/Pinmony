const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
// Pass the bundled DevEco TypeScript module path as the first argument.
const ts = require(process.argv[2] || 'typescript');
const root = path.join(__dirname, '..');
const indexSource = readSourceFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const retentionSource = readSourceFileSync(path.join(root, 'entry/src/main/ets/services/PinWebHomeRetention.ets'), 'utf8');
const pageSource = readSourceFileSync(path.join(root, 'entry/src/main/ets/components/PinWebHomePage.ets'), 'utf8');
function method(name) {
  const marker = new RegExp('  private (?:async )?' + name + '\\(');
  const start = indexSource.search(marker);
  assert.ok(start >= 0, name);
  const rest = indexSource.slice(start);
  const end = rest.slice(1).search(/\n  (?:private |@Builder)/) + 1;
  return rest.slice(0, end);
}
const timers = [];
const context = { console, PIN_HOME_API_ENABLED: true, PIN_POST_API_ENABLED: true,
  PinWebRuntimeLog: { warn: message => assert.fail(message) },
  setTimeout: callback => { timers.push(callback); return timers.length; } };
const helper = retentionSource.replace(/^import .*;\s*/m, '').replace('export function', 'function');
const methods = ['prepareHomeForPageBegin', 'expectHome', 'clearHome', 'normalizeHomeBoard', 'updateHome', 'selectHomeTab',
  'loadMoreHome', 'refreshHome', 'updateHomePinTitle', 'requestHomeTitles', 'homeMenuReady'].map(method).join('\n');
const compiled = ts.transpile(helper + '\nclass Coordinator {\n' + methods + '\n}\nglobalThis.Coordinator = Coordinator;',
  { target: ts.ScriptTarget.ES2020 });
vm.runInNewContext(compiled, context);
const pin = (id, title = '') => ({ id, pinUrl: 'https://www.pinterest.com/pin/' + id + '/',
  imageUrl: 'https://i.pinimg.com/' + id + '.jpg', imageWidth: 200, imageHeight: 300, title, hasMore: false });
const pageKey = 'https://www.pinterest.com/';
const tabs = [{ id: 'tab:all', label: '所有', selected: true, enabled: true },
  { id: 'tab:anime', label: '动漫', selected: false, enabled: true }];
const snapshot = (session, pins) => ({ kind: 'state', session, pageKey, selectedTab: '所有', tabs, pins });
const saved = snapshot(9, [pin('123', '原标题'), pin('456')]);
const coordinator = new context.Coordinator();
const menuCoordinator = new context.Coordinator();
Object.assign(menuCoordinator, { authStatus: 'authenticated', activeTab: 0, home: saved,
  currentHomePageKey: () => pageKey, homeActionsReady: false, homeLoading: false,
  homeRefreshing: false, pendingHomeTab: 'tab:all', retainingHomeFeed: true });
assert.equal(menuCoordinator.homeMenuReady(), true, 'restoring the displayed feed must not wait for category confirmation');
menuCoordinator.retainingHomeFeed = false;
assert.equal(menuCoordinator.homeMenuReady(), false, 'a user category switch still blocks stale Pin actions');
menuCoordinator.retainingHomeFeed = true;
menuCoordinator.currentHomePageKey = () => '';
assert.equal(menuCoordinator.homeMenuReady(), false, 'the detail route cannot operate home Pins');
menuCoordinator.currentHomePageKey = () => pageKey;
menuCoordinator.authStatus = 'unauthenticated';
assert.equal(menuCoordinator.homeMenuReady(), false);
const notices = [];
let refreshes = 0;
Object.assign(coordinator, {
  confirmedSaves: { isSaved: () => false },
  traceAction() {},
  rootTabAddresses: new Map(),
  homeRequestToken: 0, homeMoreRequestToken: 0, homeRefreshToken: 0,
  retainingHomeFeed: false, homeRefreshing: false, homeActionsReady: false,
  cachedHome: saved, cachedHomeScrollOffset: 400, knownSearchPinTitles: new Map(), pendingHomeTab: '',
  homePageKeyFromAddress: url => url === pageKey ? pageKey : '',
  currentHomePageKey: () => pageKey,
  pinIdentity: url => (url.match(/\/pin\/(\d+)/) || [])[1] || '',
  hasMeaningfulSearchPinTitle: title => !!title && title !== 'Pin 图',
  updateSearchPinTitle: (url, title) => coordinator.knownSearchPinTitles.set(coordinator.pinIdentity(url), title),
  showMessage: message => notices.push(message),
  controller: { refresh: () => { refreshes++; }, runJavaScript: async () => 'true' }
});
coordinator.prepareHomeForPageBegin(pageKey);
assert.equal(coordinator.home, saved);
assert.equal(coordinator.pendingHomeTab, 'tab:all');
coordinator.updateHome(JSON.stringify(snapshot(1, [pin('789'), pin('456', '网页真实标题')])));
assert.deepEqual(Array.from(coordinator.home.pins, item => item.id), ['123', '456'],
  'returning webpage snapshots do not replace the saved feed');
assert.equal(coordinator.home.pins[1].title, '网页真实标题');
assert.equal(coordinator.home.session, 1, 'controls use the new document session');
assert.equal(coordinator.pendingHomeTab, '');
assert.equal(coordinator.cachedHomeScrollOffset, 400);
coordinator.updateHome(JSON.stringify(snapshot(2, [pin('789')])));
assert.deepEqual(Array.from(coordinator.home.pins, item => item.id), ['123', '456']);
coordinator.updateHomePinTitle('https://www.pinterest.com/pin/123/', '详情真实标题');
assert.equal(coordinator.cachedHome.pins[0].title, '详情真实标题');
coordinator.updateHome(JSON.stringify({ ...snapshot(2, []), kind: 'failed', error: '首页更新失败，请重试' }));
assert.equal(coordinator.home.pins.length, 2, 'failed synchronization keeps the completed feed visible');
assert.equal(coordinator.homeError, '首页更新失败，请重试', 'cached content exposes its update failure');
coordinator.updateHome(JSON.stringify({ ...snapshot(2, []), kind: 'loading' }));
assert.equal(coordinator.homeError, '', 'a real retry clears the previous update error');
assert.equal(coordinator.home.pins.length, 2, 'retrying does not blank the displayed feed');
coordinator.updateHome(JSON.stringify(snapshot(2, [pin('789')])));
coordinator.updateHome(JSON.stringify({ kind: 'title', session: 2, pageKey,
  pinUrl: 'https://www.pinterest.com/pin/456/', title: '后台读取的真实标题' }));
assert.equal(coordinator.home.pins[1].title, '后台读取的真实标题');
coordinator.updateHome(JSON.stringify({ kind: 'title', session: 1, pageKey,
  pinUrl: 'https://www.pinterest.com/pin/456/', title: '旧会话标题' }));
assert.equal(coordinator.home.pins[1].title, '后台读取的真实标题');
coordinator.updateHomePinTitle('https://www.pinterest.com/pin/999/', '别的 Pin');
assert.equal(coordinator.cachedHome.pins[0].title, '详情真实标题');
coordinator.loadMoreHome();
coordinator.updateHome(JSON.stringify(snapshot(2, [pin('789')])));
assert.deepEqual(Array.from(coordinator.home.pins, item => item.id), ['123', '456', '789'],
  'loading more appends without replacing the saved prefix');
coordinator.refreshHome();
assert.equal(refreshes, 1, 'pull refresh reloads the real webpage');
assert.equal(coordinator.homeRefreshing, true);
coordinator.refreshHome();
assert.equal(refreshes, 1, 'overlapping refresh gestures are ignored');
coordinator.updateHome(JSON.stringify(snapshot(2, [pin('999')])));
assert.equal(coordinator.home.pins[0].id, '123', 'old document events cannot finish a refresh');
coordinator.prepareHomeForPageBegin(pageKey);
coordinator.updateHome(JSON.stringify(snapshot(1, [pin('999', '刷新后的标题')])));
assert.deepEqual(Array.from(coordinator.home.pins, item => item.id), ['999'],
  'only an explicit refresh replaces the retained feed');
assert.equal(coordinator.homeRefreshing, false);
timers.forEach(callback => callback());
assert.equal(notices.length, 0, 'completed refresh cannot receive a late timeout');
assert.match(pageSource, /Refresh\(\{ refreshing: this\.refreshing \}\)/);
assert.match(pageSource, /\.onRefreshing\(\(\) => \{ if \(this\.onRefresh\)/);

const prefetchMethod = pageSource.slice(pageSource.indexOf('  private prefetchNextScreen()'),
  pageSource.indexOf('  private onPendingTabChanged()'));
vm.runInNewContext(ts.transpile('class Feed {\n' + prefetchMethod + '\n}\nglobalThis.Feed = Feed;',
  { target: ts.ScriptTarget.ES2020 }), context);
const feed = new context.Feed();
let prefetches = 0;
Object.assign(feed, { home: { ...saved, dataSource: 'api', pins: Array.from({ length: 21 }, (_, i) => pin(String(i))) },
  feedActive: true, actionsReady: true, loading: false, refreshing: false, pendingTabId: '', visibleFirst: 0, visibleLast: 5,
  prefetchKey: '', onLoadMore: () => prefetches++ });
feed.prefetchNextScreen();
assert.equal(prefetches, 0, 'enough cards ahead do not trigger unnecessary pagination');
feed.visibleFirst = 3; feed.visibleLast = 8;
feed.prefetchNextScreen(); feed.prefetchNextScreen();
assert.equal(prefetches, 1, 'two screens before the end triggers exactly one prefetch');
feed.prefetchKey = ''; feed.feedActive = false;
feed.prefetchNextScreen();
assert.equal(prefetches, 1, 'hidden roots, background and overlays do not prefetch');
feed.feedActive = true; feed.actionsReady = false;
feed.prefetchNextScreen();
assert.equal(prefetches, 1, 'cached controls cannot prefetch before current-session confirmation');
feed.actionsReady = true;
feed.onPrefetchAvailabilityChanged();
timers.pop()();
assert.equal(prefetches, 2, 'returning to a ready visible feed resumes prefetch without another scroll');
feed.home = { ...feed.home, pins: Array.from({ length: 100 }, (_, i) => pin(String(i))) };
feed.visibleFirst = 0; feed.visibleLast = 49;
feed.prefetchNextScreen();
assert.equal(prefetches, 2, 'large visible ranges keep lookahead bounded');
feed.home = { ...feed.home, pins: [pin('1'), pin('2')] };
feed.visibleFirst = 0; feed.visibleLast = 1;
feed.prefetchNextScreen();
assert.equal(prefetches, 3, 'a short first page automatically requests more');
for (const field of ['loadingMore', 'endReached', 'sourceError', 'refreshing']) {
  feed.prefetchKey = ''; feed.home[field] = true;
  feed.prefetchNextScreen();
  assert.equal(prefetches, 3, field + ' suppresses automatic requests');
  feed.home[field] = false;
}
feed.home.dataSource = 'dom'; feed.prefetchNextScreen();
assert.equal(prefetches, 3, 'other categories retain their original loading behavior');
assert.match(pageSource, /\.onReachEnd\(\(\) => \{\s*if \(this\.home\.dataSource === 'api'\) this\.prefetchNextScreen\(\)/,
  'reaching the end shares automatic deduplication and failure gates');

Promise.resolve().then(async () => {
  coordinator.home = { ...coordinator.home, dataSource: 'api' };
  coordinator.cachedHome = coordinator.home;
  coordinator.refreshHome();
  assert.equal(refreshes, 1, 'API refresh keeps the document and existing feed');
  coordinator.updateHome(JSON.stringify({ ...snapshot(1, [pin('999')]), dataSource: 'api', refreshing: true }));
  assert.equal(coordinator.homeRefreshing, true, 'in-flight API state cannot finish refresh');
  coordinator.updateHome(JSON.stringify({ ...snapshot(1, [pin('777')]), dataSource: 'api', refreshing: false }));
  assert.equal(coordinator.homeRefreshing, false);
  assert.equal(coordinator.home.pins[0].id, '777', 'successful API refresh replaces the feed');
  await coordinator.selectHomeTab('tab:anime');
  assert.equal(coordinator.retainingHomeFeed, false);
  assert.equal(coordinator.homeLoading, true);
  const animeTabs = tabs.map(tab => ({ ...tab, selected: tab.id === 'tab:anime' }));
  coordinator.updateHome(JSON.stringify({ ...snapshot(2, [pin('888')]), tabs: animeTabs, selectedTab: '动漫' }));
  assert.equal(coordinator.home.pins[0].id, '888', 'user category changes replace the feed');
  assert.equal(coordinator.homeLoading, false);
  console.log('home return retention, session rebinding, title backfill, pagination and pull refresh OK');
}).catch(error => { console.error(error); process.exitCode = 1; });
