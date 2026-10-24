const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const rest = source.slice(start);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
const names = ['rootActionContextReady', 'ensureRootActionContext', 'updateSearchQuery', 'submitSearch',
  'openHomePin', 'prepareSearchNavigation', 'performSearchAction', 'performInboxAction'];
const context = { PIN_NATIVE_DETAIL_READS_ENABLED:true, PIN_NATIVE_INBOX_MESSAGES_ENABLED:false, PIN_NATIVE_INBOX_UPDATES_ENABLED:false, setTimeout, Date, PIN_INBOX_CONVERSATIONS_API_ENABLED: true,
  PinmonyRuntimeLog: { info() {}, warn() {} } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native {' + names.map(method).join('\n') +
  '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
const roots = ['https://www.pinterest.com/', 'https://www.pinterest.com/search/',
  'https://www.pinterest.com/inbox/'];
const pinUrl = roots[0] + 'pin/123/';
function harness(index) {
  const native = new context.Native(), requests = [], notices = [];
  let document = roots[0] + 'sample/';
  Object.assign(native, { authStatus: 'authenticated', activeTab: index, tabRequestToken: 1,
    inboxMessagesNativeReads:{open:async()=>false,installScript:()=>''}, inboxUpdatesNativeReads:{installScript:()=>''},
    rootSearchIntentToken: 0, pendingWebTab: -1, rootContentInteracted: false,
    homeStore: { homeActionsReady: false, homeForPresentation: () => ({ pageKey: roots[0],
      pins: [{ id: '123', pinUrl }] }) },
    searchStore: { searchActionsReady: false, searchQueryToken: 0, searchRequestToken: 0,
      search: { pageKey: roots[1], session: 1 } },
    inboxStore: { inboxSectionReady: false, inboxActionsReady: false,
      inboxSession: 1, inboxUrl: roots[2], inbox: { pageUrl: roots[2], session: 1 } }, pinStore: {},
    pageHistory: { key: url => url || '' }, rootPresentationAddress: i => roots[i],
    currentHomePageKey: () => document, currentSearchPageKey: () => document, currentInboxUrl: () => document,
    homePresentationPageKey: () => roots[0], retainedHomeRootPageKey: () => '',
    traceAction() {}, rejectOfflineAction: () => false, clearRootTabGuard() {},
    showMessage: message => notices.push(message), pinIdentity: url => url === pinUrl ? '123' : '',
    beginDetailOpening: (url, origin) => requests.push(['detail', url, origin]),
    requestRootPage(i) { if(native.pendingWebTab===i)return; requests.push(['prepare', i]); native.pendingWebTab = i; native.tabRequestToken++; },
    controller: { getUrl: () => document, loadUrl: url => requests.push(['load', url]),
      runJavaScript: code => { requests.push(['js', code]); return Promise.resolve('true'); } } });
  native.searchStore = Object.assign(new searchRuntime.Store(), native.searchStore);
  searchRuntime.bindIndex(native);
  require('./medium-priority-controller-harness.cjs').bind(native,ts,context,['inboxActions']);
  require('./home-controller-harness.cjs').createHomeRuntime(ts, context).bindIndex(native);
  return { native, requests, notices, ready() {
    document = roots[index];
    if (index === 1) { native.searchStore.searchActionsReady = true; native.searchStore.search.session = 22; }
    if (index === 2) { native.inboxStore.inboxSectionReady = native.inboxStore.inboxActionsReady = true;
      native.inboxStore.inboxSession = native.inboxStore.inbox.session = 22; }
    native.rootContextCoordinator?.notify();
  } };
}
(async () => {
  const home = harness(0);
  await home.native.openHomePin('123');
  assert.deepEqual(home.requests, [['detail', pinUrl, roots[0]]],
    'retained native Pin opens directly from a different hidden root');
  home.requests.length = 0;
  await home.native.openHomePin('missing');
  assert.deepEqual(home.requests, [], 'missing retained Pin cannot navigate');
  const query = harness(1);
  const first = query.native.updateSearchQuery('first');
  const last = query.native.updateSearchQuery('latest');
  assert.deepEqual(query.requests, [['prepare', 1]], 'input intents coalesce context preparation');
  query.ready();
  await Promise.all([first, last]);
  const calls = query.requests.filter(item => item[0] === 'js');
  assert.equal(calls.length, 1, 'only latest query is dispatched');
  assert.match(calls[0][1], /PinmonySearchQuery\(22,.*"latest"/,
    'fresh session replaces the retained session');
  const canceled = harness(2);
  const action = canceled.native.performInboxAction('compose');
  await new Promise(resolve=>setImmediate(resolve));
  canceled.native.activeTab = 0;
  canceled.native.tabRequestToken++;
  canceled.ready();
  await action;
  assert.deepEqual(canceled.requests, [['prepare', 2]], 'switching tabs cancels pending business intent');
  const inbox = harness(2);
  const compose = inbox.native.performInboxAction('compose');
  assert.equal(inbox.requests.some(item => item[0] === 'js'), false, 'retained inbox session is never dispatched');
  inbox.ready();
  await compose;
  assert.match(inbox.requests.at(-1)[1], /PinmonyInboxApiAction\("compose",22\)/);
  const locked = harness(1); locked.native.authStatus = 'checking';
  await locked.native.updateSearchQuery('blocked');
  assert.deepEqual(locked.requests, [], 'login gate remains unchanged');
  const loadingInput = harness(1); loadingInput.ready();
  loadingInput.native.searchStore.searchActionsReady = false;
  loadingInput.native.searchStore.searchInputReady = true;
  await loadingInput.native.updateSearchQuery('during-discovery');
  assert.equal(loadingInput.requests.filter(item => item[0] === 'prepare').length, 0,
    'input-ready bridge does not reload a document while discovery is pending');
  assert.match(loadingInput.requests.at(-1)[1], /during-discovery/);
  assert.equal(loadingInput.native.rootActionContextReady(1), false,
    'input readiness does not enable result operations');
  for (const [feature, component] of [['home', 'Home'], ['search', 'Search'], ['inbox', 'Inbox']]) {
    const ui = fs.readFileSync(`feature_${feature}/src/main/ets/components/Pinmony${component}Page.ets`, 'utf8');
    assert.match(ui, /@Prop interactionReady: boolean/);
    assert.match(ui, /this\.interactionReady/, 'content accepts user intent independently of transport readiness');
  }
  console.log('Root content actions: retained Pin navigation, lazy context, fresh sessions, latest input, canceled intents and login gate passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
