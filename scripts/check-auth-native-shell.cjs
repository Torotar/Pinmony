const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function moduleFrom(path) {
  const exports = {};
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(readSourceFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports });
  return exports;
}
const { PIN_AUTH_BRIDGE_SCRIPT } = moduleFrom('entry/src/main/ets/services/PinmonyAuthScript.ets');
const { acceptsAuthMessage } = moduleFrom('entry/src/main/ets/models/PinmonyAuth.ets');
function harness(url, initial, acknowledge = true) {
  const location = new URL(url), messages = [];
  const node = initial ? { textContent: JSON.stringify(initial) } : null;
  let nextBody = {}, nextUrl = location.origin + '/resource/UserResource/get/';
  class XHR {
    addEventListener(_, fn) { this.listener = fn; }
    send() { this.listener(); }
  }
  const context = { URL, location, XMLHttpRequest: XHR,
    document: { getElementById: () => node, addEventListener() {} },
    PinmonyShareBridge: { authState(value) {
      messages.push(JSON.parse(value));
      if (acknowledge) context.PinmonyAuthAcknowledge(value);
    } },
    fetch: async () => ({ url: nextUrl, clone() { return { json: async () => nextBody }; } }) };
  context.window = context; context.top = context;
  require('./product-coordination-harness.cjs').run(ts,PIN_AUTH_BRIDGE_SCRIPT, context);
  return { context, messages, location,
    setResponse(body, url = location.origin + '/resource/UserResource/get/') { nextBody = body; nextUrl = url; } };
}
async function flush() { await new Promise(resolve => setImmediate(resolve)); }
async function check() {
  const metadata = harness('https://www.pinterest.com/', { client_context: { is_authenticated: true,
    user: { id: '7', username: 'fixture' }, app_version: 'fixture.1' } });
  metadata.context.PinmonyAuthSync(1); assert.equal(metadata.messages.at(-1).appVersion, 'fixture.1');
  const invalidMetadata = harness('https://www.pinterest.com/', { client_context: { is_authenticated: true,
    user: { id: '7', username: 'fixture' }, app_version: 'invalid version' } });
  invalidMetadata.context.PinmonyAuthSync(1); assert.equal(invalidMetadata.messages.at(-1).appVersion, '');
  const unacknowledged = harness('https://www.pinterest.com/', {client_context: {is_authenticated: true}}, false);
  unacknowledged.context.PinmonyAuthSync(1);
  unacknowledged.context.PinmonyAuthSync(1);
  assert.equal(unacknowledged.messages.length, 2, 'native rejection or missing acknowledgement permits explicit resync');
  const oldEvidence = JSON.stringify(unacknowledged.messages.at(-1));
  unacknowledged.context.PinmonyAuthAcknowledge(oldEvidence);
  unacknowledged.context.PinmonyAuthSync(1);
  assert.equal(unacknowledged.messages.length, 2, 'acknowledged identical evidence is coalesced');
  unacknowledged.context.PinmonyAuthSync(2);
  unacknowledged.context.PinmonyAuthAcknowledge(oldEvidence);
  unacknowledged.context.PinmonyAuthSync(2);
  assert.equal(unacknowledged.messages.length, 4, 'late acknowledgement cannot accept a newer epoch');
  const guest = harness('https://www.pinterest.com/login/', { initialReduxState: { session: { isAuthenticated: false } } });
  guest.context.PinmonyAuthSync(1);
  assert.equal(guest.messages.at(-1).status, 'unauthenticated');
  guest.setResponse({ client_context: { is_authenticated: true, user: { id: '123', username: 'sample' } } });
  await guest.context.fetch('/resource/UserResource/get/'); await flush();
  assert.equal(guest.messages.at(-1).status, 'authenticated');
  guest.context.PinmonyAuthSync(1);
  assert.equal(guest.messages.at(-1).status, 'authenticated', 'old login-page initial data cannot undo successful login');
  const syncCount = guest.messages.length;
  guest.context.PinmonyAuthSync(1);
  assert.equal(guest.messages.length, syncCount, 'same epoch and evidence are published only once');
  guest.context.PinmonyAuthSync(2);
  assert.equal(guest.messages.length, syncCount + 1, 'new document epoch still gets current evidence');
  assert.equal(guest.messages.at(-1).profileUrl, 'https://www.pinterest.com/sample/');

  const unknown = harness('https://www.pinterest.com/', null);
  unknown.context.PinmonyAuthSync(2);
  assert.equal(unknown.messages.length, 0, 'homepage URL alone is not login evidence');
  const account = harness('https://www.pinterest.com/', { initialReduxState: { session: {
    isAuthenticated: true, user: { id: '123', username: 'sample' }
  } } });
  account.context.PinmonyAuthSync(3);
  assert.equal(account.messages.at(-1).status, 'authenticated');
  account.location.href = 'https://www.pinterest.com/login/';
  account.context.PinmonyAuthSync(3);
  assert.equal(account.messages.at(-1).status, 'unauthenticated', 'SPA logout cannot reuse old authenticated initial props');
  account.location.href = 'https://www.pinterest.com/';
  account.context.PinmonyAuthSync(3);
  account.setResponse({ client_context: { is_authenticated: false, user: { id: '123' } } });
  await account.context.fetch('/resource/ApiResource/get/'); await flush();
  assert.equal(account.messages.at(-1).status, 'unauthenticated', 'explicit logout wins over a user ID');
  const before = account.messages.length;
  account.setResponse({ client_context: { is_authenticated: true } }, 'https://example.com/');
  await account.context.fetch('https://example.com/'); await flush();
  assert.equal(account.messages.length, before, 'third-party responses cannot authenticate');
  account.setResponse({ client_context: { is_authenticated: true } });
  const request = account.context.fetch('/resource/ApiResource/get/');
  account.location.href = 'https://www.pinterest.com/search/';
  await request; await flush();
  assert.equal(account.messages.length, before, 'old-route response cannot authenticate the new route');

  const message = { status: 'authenticated', epoch: 3, pageUrl: 'https://www.pinterest.com/', profileUrl: '' };
  assert.equal(acceptsAuthMessage(message, message.pageUrl, 3), true);
  assert.equal(acceptsAuthMessage(message, message.pageUrl, 4), false);
  assert.equal(acceptsAuthMessage(message, 'https://www.pinterest.com/login/', 3), false);
  assert.equal(acceptsAuthMessage({ ...message, status: 'error' }, message.pageUrl, 3), false);

  const source = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  function method(name) {
    const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
    assert.ok(start >= 0, name);
    return source.slice(start, source.indexOf('\n  private ', start + 1));
  }
  const names = ['selectSearchFilter', 'selectProfilePublish', 'performProfileAction', 'performInboxAction',
    'performSearchAction', 'performDetailAction', 'authWebVisible', 'updateAuthState', 'retryLogin', 'confirmBusinessSession'];
  const context = { PIN_PROFILE_API_ENABLED: true, PIN_INBOX_CONVERSATIONS_API_ENABLED: true,
    PinmonyRuntimeLog: { info() {}, warn() {} },
    PIN_POST_API_ENABLED: true, PIN_POST_EXTENSIONS_ENABLED: true,
    PINTEREST_LOGIN_URL: 'https://www.pinterest.com/login/',
    isPinterestAuthRoute: moduleFrom('entry/src/main/ets/models/PinmonyAuth.ets').isPinterestAuthRoute };
  context.acceptsAuthMessage = acceptsAuthMessage;
  context.PINTEREST_URL = 'https://www.pinterest.com/';
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native {' + names.map(method).join('\n') +
    '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
  const native = require('./product-coordination-harness.cjs').createHost(context.Native, ts);
  let effects = 0;
  native.rejectOfflineAction = () => false;
  Object.assign(native, {
    traceAction() { }, traceAuth() { },
    inboxStore: Object.assign(native.inboxStore, {}),
    controller: { runJavaScript() { effects++; return Promise.resolve('true'); } },
    showMessage() { effects++; },
    currentProfileUrl: () => 'https://www.pinterest.com/sample/',
    currentPinUrl: () => 'https://www.pinterest.com/pin/123/', pinIdentity: value => value,
    boardUrlFromAddress: () => '', currentSearchPageKey: () => 'https://www.pinterest.com/search/',
    profileStore: Object.assign(native.profileStore, { profileActionsReady: true, profile: { profileUrl: 'https://www.pinterest.com/sample/', createdPins: [] } }, {
        profileActionsReady: true,
        profile: { profileUrl: 'https://www.pinterest.com/sample/', createdPins: [] }
    }),
    pinStore: Object.assign(native.pinStore, { detailActionsReady: true, detail: { pinUrl: 'https://www.pinterest.com/pin/123/' } }, {
        detail: { pinUrl: 'https://www.pinterest.com/pin/123/' },
        detailActionsReady: true
    }),
    searchStore: Object.assign(native.searchStore, { search: { pageKey: 'https://www.pinterest.com/search/', discoveryApi: false, heroes: [] } }, {
        search: { pageKey: 'https://www.pinterest.com/search/', discoveryApi: false, heroes: [] }
    })
});
  const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
  native.searchStore = Object.assign(new searchRuntime.Store(), native.searchStore);
  searchRuntime.bindIndex(native);
  require('./publish-controller-harness.cjs').bind(native, ts);
  const { PinmonyDetailController } = moduleFrom('feature_pin/src/main/ets/controllers/PinmonyDetailController.ets');
  native.detailController = new PinmonyDetailController({ store: native.pinStore, traceAction() {},
    isOffline: () => false, isAuthenticated: () => true, pinIdentity: value => value,
    currentPinUrl: native.currentPinUrl, postApiEnabled: () => true, postExtensionsEnabled: () => true });
  await native.selectSearchFilter('filter'); await native.selectProfilePublish('publish');
  await native.performProfileAction('settings'); await native.performInboxAction('dom-update');
  await native.performSearchAction('hero', 'hero'); await native.performDetailAction('unsupported', 'unsupported');
  assert.equal(effects, 0, 'unintegrated controls cause no request, navigation or feedback');
  Object.assign(native, {
    authStatus: 'authenticated', navigationAddress: 'https://www.pinterest.com/login/'
});
  assert.equal(native.authWebVisible(), false, 'authenticated state never exposes website UI');
  native.authStatus = 'unauthenticated'; assert.equal(native.authWebVisible(), true);
  native.navigationAddress = 'https://www.pinterest.com/'; assert.equal(native.authWebVisible(), false);
  let resetCount = 0, currentUrl = message.pageUrl;
  const loaded = [];
  Object.assign(native, {
    authEpoch: 3, authStatus: 'authenticated', authCheckTimer: -1,
    controller: { getUrl: () => currentUrl, loadUrl: url => loaded.push(url), runJavaScript: async () => 'true' },
    homeCacheAccountIdFromProfileUrl: value => value || '', homePageKeyFromAddress: () => '',
    tryRestoreAuthenticatedHome() { }, profileUrlFromAddress: value => value || '',
    resetAuthenticatedContent() { resetCount++; }, configureDocumentRetention() { }, bindNativeNetwork() { }, tabsController: { changeIndex() { } },
    pageHistory: { reset() { } }, isHomeRootAddress: () => false
});
  native.updateAuthState(JSON.stringify({ ...message, epoch: 2, status: 'unauthenticated' }));
  assert.equal(native.authStatus, 'authenticated'); assert.equal(resetCount, 0);
  native.updateAuthState(JSON.stringify({ ...message, status: 'unauthenticated' }));
  assert.equal(resetCount, 1); assert.equal(native.authStatus, 'unauthenticated');
  assert.equal(loaded.at(-1), context.PINTEREST_LOGIN_URL);
  currentUrl = context.PINTEREST_LOGIN_URL;
  native.updateAuthState(JSON.stringify({ ...message, pageUrl: currentUrl }));
  assert.equal(native.authStatus, 'authenticated'); assert.equal(loaded.at(-1), context.PINTEREST_URL);
  let clearedDetails = 0, clearedCache = 0, clearedPrefetch = 0;
  Object.assign(native, {
    homeCacheAccountId: 'old-account', clearOfflineHomeMarker() { }, clearRootTabCaches() { },
    nativeNetwork: { invalidate() { } }, clearDetail() { clearedDetails++; },
    pinStore: Object.assign(native.pinStore, { detailCache: { clear() { clearedCache++; } }, clearDetailOrigins() { },
        detailPrefetch: { clear() { clearedPrefetch++; } }, confirmedSaves: { clear() { } } })
});
  native.pinStore.detailCache = native.pinStore.detailCache;
  native.detailPrefetch = native.pinStore.detailPrefetch;
  native.pinStore.confirmedSaves = native.pinStore.confirmedSaves;
  native.updateAuthState(JSON.stringify({ ...message, pageUrl: currentUrl, profileUrl: 'https://www.pinterest.com/new-account/' }));
  assert.equal(clearedDetails, 1, 'account switch discards old detail state and pending intentions');
  assert.equal(clearedCache, 1, 'account switch discards old cached presentation');
  assert.equal(clearedPrefetch, 1, 'account switch discards old prefetch data');
  Object.assign(native, {
    authStatus: 'error', webPageLoading: false, lastLoginRetryAt: -1, showNetworkNotice() { }
});
  const beforeRetry = loaded.length;
  native.retryLogin(); native.retryLogin();
  assert.equal(loaded.length, beforeRetry + 1, 'rapid manual retry loads the session page once');
  assert.match(fs.readFileSync('entry/src/main/ets/components/PinmonyLoginPage.ets', 'utf8'), /\.hitTestBehavior\(view.visible \? HitTestMode.Default : HitTestMode.None\)/);
  const tabsStart = source.indexOf('  private buildRootTabs()');
  const tabsEnd = source.indexOf('  build()', tabsStart);
  assert.ok(tabsStart >= 0 && tabsEnd > tabsStart);
  const tabs = source.slice(tabsStart, tabsEnd);
  assert.equal((tabs.match(/TabContent\(\)/g) || []).length, 4);
  for (const name of ['Home', 'Search', 'Inbox', 'Profile']) {
    assert.ok(tabs.includes('this.build' + name + 'RootContent()'), name + ' is carried by Tabs');
  }
  assert.match(tabs, /\.height\('100%'\)/);
  assert.match(tabs, /\.barHeight\(56\)[\s\S]*?barBottomMargin: 28/);
  assert.match(tabs, /\.animationDuration\(0\)/);
  assert.ok(!tabs.includes('HitTestMode.None'), 'collapsed bar must not disable root content touch');
  const build = source.slice(tabsEnd);
  assert.ok(build.indexOf('this.buildRootTabs()') < build.indexOf('PinmonySettingsPage({'),
    'secondary pages cover Tabs rather than placing an empty overlay above them');
  // This suite checks authentication shell behavior; native business reads execute in focused suites.
  native.usesNativeProfileReads = () => false;
  for(const field of ['boardNativeReads','profileNativeReads','searchNativeReads','searchDiscoveryNativeReads','inboxUpdatesNativeReads','inboxMessagesNativeReads'])native[field] = {demand:async()=>{},pause(){},reset(){},eligible:()=>false,selected:()=>false};
  console.log('Auth gate, session evidence, stale responses, hidden host and unsupported-action checks passed');
}
check().catch(error => { console.error(error); process.exitCode = 1; });
