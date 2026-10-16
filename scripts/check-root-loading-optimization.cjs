const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = 'https://www.pinterest.com/';
const fixture = JSON.parse(fs.readFileSync('scripts/fixtures/home-api.json', 'utf8'));
function script(file) { return Function('return `' + fs.readFileSync(file, 'utf8').match(/`([\s\S]*?)`;/)[1] + '`')(); }
function home(pathname = '/') {
  const requests = [], messages = [], timers = [];
  const window = { PinmonyHomeApiEnabled: true, addEventListener() {},
    PinmonyShareBridge: { homeState: value => messages.push(JSON.parse(value)) } };
  window.top = window;
  const location = { origin: root.slice(0, -1), hostname: 'www.pinterest.com', pathname, href: root.slice(0, -1) + pathname };
  const context = { window, location, URL, AbortController, Date, console: { warn() {}, info() {} },
    setTimeout: callback => { timers.push(callback); return timers.length; }, clearTimeout() {}, setInterval() {},
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })) };
  require('./product-coordination-harness.cjs').run(ts,script('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets') +
    script('feature_home/src/main/ets/services/PinmonyHomeScript.ets'), context);
  const publish = () => { const pending = timers.splice(0); pending.filter(callback => callback.name === 'publish').forEach(callback => callback()); };
  return { window, requests, messages, publish };
}
async function respond(request, payload, ok = true) {
  request.resolve({ ok, status: ok ? 200 : 503, json: async () => payload });
  await new Promise(resolve => setImmediate(resolve));
}
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  const rest = source.slice(start);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
let now = 1000;
const context = { Date: { now: () => now }, PinmonyRuntimeLog: { info() {}, warn(message) { assert.fail(message); } } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native {' +
  ['prepareSearchNavigation', 'rootReadInFlight', 'requestRootPage', 'updateHome'].map(method).join('\n') +
  '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
function native() {
  const n = new context.Native(), loads = [];
  let document = root, ready = false;
  Object.assign(n, { authStatus: 'authenticated', activeTab: 1, tabRequestToken: 1,
    webPageLoading: false,
    searchController: { searchPlaceholder: pageKey => ({ pageKey, results: [] }) }, syncFloatingTabsMotion() {},
    pendingWebTab: -1, rootReadToken: -1, rootTabAddresses: new Map([[1, root + 'search/']]), searchStore: {}, pinStore: {},
    pageHistory: { key: value => value || '' }, rootPresentationAddress: index => n.rootTabAddresses.get(index),
    rootTabIndexFromAddress: value => value.startsWith(root + 'search/') ? 1 : -1,
    rootActionContextReady: () => ready,
    controller: { getUrl: () => document, loadUrl: value => loads.push(value) },
    showMessage() {}, clearRootTabGuard() {}, expectSearch() {}, waitForWebTabConfirmation() {} });
  return { n, loads, document(value) { document = value; }, ready() { ready = true; } };
}
(async () => {
  const h = home(); h.publish();
  assert.equal(h.requests.length, 0, 'feed waits for authenticated identity');
  h.window.PinmonyHomeSetUsername('sample'); h.publish();
  assert.equal(h.requests.length, 2, 'categories and All feed start before either response');
  const categories = h.requests.find(item => item.url.includes('BoardsFeedResource'));
  const feed = h.requests.find(item => item.url.includes('UserHomefeedResource'));
  await respond(feed, fixture); h.publish();
  assert.equal(h.messages.at(-1).kind, 'state', 'All feed commits while categories are pending');
  assert.equal(h.messages.at(-1).pins.length, 21);
  await respond(categories, {}, false); h.publish();
  const presentation = new context.Native(); presentation.markRootPerformance=()=>{};
  Object.assign(presentation, { homeStore: { homeRequestToken: 0, homeRefreshToken: 0 },
    searchStore: { knownSearchPinTitles: new Map() }, pinStore: { confirmedSaves: { isSaved: () => false } },
    currentHomePageKey: () => root, normalizeHomeBoard: () => undefined,
    pinIdentity: value => /\/pin\/(\d+)/.exec(value)?.[1] || '',
    homeTraceCardsPageKey: root, homeDiskCacheRestoredAt: 0, rootTabAddresses: new Map(), persistHomeDiskCache() {} });
  require('./home-controller-harness.cjs').createHomeRuntime(ts, context).bindIndex(presentation);
  presentation.updateHome(JSON.stringify(h.messages.at(-1)));
  assert.equal(presentation.homeStore.home.pins.length, 21, 'native coordinator preserves current feed on category failure');
  assert.equal(presentation.homeStore.home.categorySourceFailure, true);
  assert.match(presentation.homeStore.homeError, /分类读取失败/);
  assert.equal(presentation.homeStore.homeActionsReady, true, 'current validated feed remains ready independently of categories');
  assert.equal(h.messages.at(-1).kind, 'state', 'category failure cannot replace successful feed');
  assert.equal(h.messages.at(-1).categorySourceFailure, true);
  assert.equal(h.messages.at(-1).pins.length, 21);
  assert.equal(h.window.PinmonyHomeRetryCategories(root), true); h.publish();
  assert.equal(h.requests.filter(item => item.url.includes('UserHomefeedResource')).length, 1,
    'category retry does not reload feed');
  await respond(h.requests.at(-1), { resource_response: { status: 'success', data: [{ type: 'board', id: '42', name: 'Design' }] } });
  h.publish();
  assert.equal(h.messages.at(-1).categorySourceFailure, false);
  assert.deepEqual(h.messages.at(-1).tabs.map(tab => tab.label), ['所有', 'Design']);
  presentation.updateHome(JSON.stringify(h.messages.at(-1)));
  assert.equal(presentation.homeStore.homeError, '', 'successful category retry clears only its error');
  presentation.updateHome(JSON.stringify({ ...h.messages.at(-1), kind: 'failed', pins: [],
    categorySourceFailure: true, error: 'feed unavailable' }));
  assert.equal(presentation.homeStore.home.pins.length, 21, 'simultaneous feed/category failures preserve previously displayed cards');
  assert.equal(presentation.homeStore.homeActionsReady, false, 'failed feed disables old operations');
  for (const path of ['/search/', '/inbox/', '/sample/']) {
    const other = home(path); other.window.PinmonyHomeSetUsername('sample'); other.publish();
    assert.equal(other.requests.length, 0, 'non-home documents never issue home category reads');
  }
  const h2 = home(); h2.window.PinmonyHomeSetUsername('sample'); h2.publish();
  await respond(h2.requests.find(item => item.url.includes('BoardsFeedResource')),
    { resource_response: { status: 'success', data: [] } }); h2.publish();
  await respond(h2.requests.find(item => item.url.includes('UserHomefeedResource')), {}, false); h2.publish();
  assert.equal(h2.messages.at(-1).kind, 'failed', 'feed failures remain independent from category success');
  const profileReuse = native();
  const profile = root + 'sample/';
  const synchronized = [];
  profileReuse.n.activeTab = 3;
  profileReuse.document(profile);
  profileReuse.n.rootTabAddresses.set(3, profile);
  profileReuse.n.profileUrlFromAddress = value => value === profile ? profile : '';
  profileReuse.n.rootTabIndexFromAddress = value => value === profile ? 3 : -1;
  profileReuse.n.expectProfile = () => {};
  profileReuse.n.syncAuthentication = () => {};
  profileReuse.n.controller.runJavaScript = async code => { synchronized.push(code); return 'true'; };
  profileReuse.n.requestRootPage(3); await new Promise(setImmediate);
  assert.equal(profileReuse.loads.length, 0, 'current profile document is synchronized without navigation');
  assert(synchronized[0].includes('PinmonyProfileSync'));
  const missingBridge = native(); missingBridge.n.activeTab = 3; missingBridge.document(profile);
  missingBridge.n.rootTabAddresses.set(3, profile);
  missingBridge.n.profileUrlFromAddress = profileReuse.n.profileUrlFromAddress;
  missingBridge.n.rootTabIndexFromAddress = profileReuse.n.rootTabIndexFromAddress;
  missingBridge.n.expectProfile = () => {};
  missingBridge.n.controller.runJavaScript = async () => 'false';
  missingBridge.n.requestRootPage(3); await new Promise(setImmediate);
  assert.deepEqual(missingBridge.loads, [profile], 'missing profile bridge still navigates once');
  const read = native(); read.n.requestRootPage(1); const token = read.n.tabRequestToken;
  read.n.requestRootPage(1);
  read.n.pendingWebTab = -1; read.n.requestRootPage(1);
  assert.equal(read.loads.length, 1, 'prepare callers join even after navigation clears pending tab');
  assert.equal(read.n.tabRequestToken, token, 'joining preserves the waiting intent generation');
  read.n.pendingWebTab = -1; read.n.retainedRootTabPending = -1;
  assert.equal(read.n.rootReadInFlight(1, root + 'search/'), false, 'released intent cannot reuse a different live document');
  read.n.retainedRootTabPending = 1;
  read.n.rootTabAddresses.set(1, root + 'search/pins/?q=latest'); read.n.requestRootPage(1);
  assert.equal(read.loads.length, 2, 'different complete query address starts a new read');
  read.n.tabRequestToken++; read.n.requestRootPage(1);
  assert.equal(read.loads.length, 3, 'tab generation change cannot reuse old preparation');
  now += 12001; read.n.requestRootPage(1);
  assert.equal(read.loads.length, 4, 'expired preparation allows explicit retry');
  read.n.loadFailed = true; read.n.requestRootPage(1);
  assert.equal(read.loads.length, 5, 'failed preparation allows explicit retry');
  const search = native(), target = root + 'search/pins/?q=topic';
  search.n.prepareSearchNavigation(target); search.n.controller.loadUrl(target);
  search.n.pendingWebTab = -1; search.n.requestRootPage(1);
  assert.deepEqual(search.loads, [target], 'search target is registered before input/context preparation');
  assert.equal(search.n.searchStore.searchActionsReady, false, 'navigation never enables old search session');
  search.ready(); search.n.requestRootPage(1);
  assert.equal(search.loads.length, 2, 'completed context does not suppress explicit reload');
  const submitted = native();
  submitted.document(root + 'search/'); submitted.n.webPageLoading = true;
  submitted.n.lastDocumentBeginUrl = root + 'search/'; submitted.n.lastDocumentBeginAt = now;
  submitted.n.requestRootPage(1);
  assert.equal(submitted.loads.length, 0, 'current loading JS document is adopted without reloading');
  now += 12001; submitted.n.requestRootPage(1);
  assert.equal(submitted.loads.length, 1, 'a stuck loading document does not suppress explicit retry forever');
  console.log('Root loading optimization: parallel authenticated home reads, isolated failure/retry, non-home suppression and exact-target preparation joining passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
