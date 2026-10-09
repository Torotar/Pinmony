const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function moduleFrom(path) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(readSourceFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports });
  return exports;
}
const { PIN_AUTH_BRIDGE_SCRIPT } = moduleFrom('entry/src/main/ets/services/PinWebAuthScript.ets');
const { acceptsAuthMessage } = moduleFrom('entry/src/main/ets/models/PinWebAuth.ets');
function harness(url, initial) {
  const location = new URL(url), messages = [];
  const node = initial ? { textContent: JSON.stringify(initial) } : null;
  let nextBody = {}, nextUrl = location.origin + '/resource/UserResource/get/';
  class XHR {
    addEventListener(_, fn) { this.listener = fn; }
    send() { this.listener(); }
  }
  const context = { URL, location, XMLHttpRequest: XHR,
    document: { getElementById: () => node, addEventListener() {} },
    PinWebShareBridge: { authState(value) { messages.push(JSON.parse(value)); } },
    fetch: async () => ({ url: nextUrl, clone() { return { json: async () => nextBody }; } }) };
  context.window = context; context.top = context;
  vm.runInNewContext(PIN_AUTH_BRIDGE_SCRIPT, context);
  return { context, messages, location,
    setResponse(body, url = location.origin + '/resource/UserResource/get/') { nextBody = body; nextUrl = url; } };
}
async function flush() { await new Promise(resolve => setImmediate(resolve)); }
async function check() {
  const guest = harness('https://www.pinterest.com/login/', { initialReduxState: { session: { isAuthenticated: false } } });
  guest.context.PinWebAuthSync(1);
  assert.equal(guest.messages.at(-1).status, 'unauthenticated');
  guest.setResponse({ client_context: { is_authenticated: true, user: { id: '123', username: 'sample' } } });
  await guest.context.fetch('/resource/UserResource/get/'); await flush();
  assert.equal(guest.messages.at(-1).status, 'authenticated');
  guest.context.PinWebAuthSync(1);
  assert.equal(guest.messages.at(-1).status, 'authenticated', 'old login-page initial data cannot undo successful login');
  assert.equal(guest.messages.at(-1).profileUrl, 'https://www.pinterest.com/sample/');

  const unknown = harness('https://www.pinterest.com/', null);
  unknown.context.PinWebAuthSync(2);
  assert.equal(unknown.messages.length, 0, 'homepage URL alone is not login evidence');
  const account = harness('https://www.pinterest.com/', { initialReduxState: { session: {
    isAuthenticated: true, user: { id: '123', username: 'sample' }
  } } });
  account.context.PinWebAuthSync(3);
  assert.equal(account.messages.at(-1).status, 'authenticated');
  account.location.href = 'https://www.pinterest.com/login/';
  account.context.PinWebAuthSync(3);
  assert.equal(account.messages.at(-1).status, 'unauthenticated', 'SPA logout cannot reuse old authenticated initial props');
  account.location.href = 'https://www.pinterest.com/';
  account.context.PinWebAuthSync(3);
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
    'performSearchAction', 'performDetailAction', 'authWebVisible', 'updateAuthState'];
  const context = { PIN_PROFILE_API_ENABLED: true, PIN_INBOX_CONVERSATIONS_API_ENABLED: true,
    PinWebRuntimeLog: { info() {}, warn() {} },
    PIN_POST_API_ENABLED: true, PIN_POST_EXTENSIONS_ENABLED: true,
    PINTEREST_LOGIN_URL: 'https://www.pinterest.com/login/',
    isPinterestAuthRoute: moduleFrom('entry/src/main/ets/models/PinWebAuth.ets').isPinterestAuthRoute };
  context.acceptsAuthMessage = acceptsAuthMessage;
  context.PINTEREST_URL = 'https://www.pinterest.com/';
  vm.runInNewContext(ts.transpileModule('class Native {' + names.map(method).join('\n') +
    '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
  const native = new context.Native();
  let effects = 0;
  native.rejectOfflineAction = () => false;
  Object.assign(native, { traceAction() {}, traceAuth() {}, profileStore: { profileActionsReady: true, profile: { profileUrl: 'https://www.pinterest.com/sample/', createdPins: [] } }, pinStore: { detailActionsReady: true, detail: { pinUrl: 'https://www.pinterest.com/pin/123/' } }, searchStore: { search: { pageKey: 'https://www.pinterest.com/search/', discoveryApi: false } }, inboxStore: {}, controller: { runJavaScript() { effects++; return Promise.resolve('true'); } },
    showMessage() { effects++; }, profileActionsReady: true,
    profile: { profileUrl: 'https://www.pinterest.com/sample/', createdPins: [] },
    currentProfileUrl: () => 'https://www.pinterest.com/sample/',
    detail: { pinUrl: 'https://www.pinterest.com/pin/123/' }, detailActionsReady: true,
    currentPinUrl: () => 'https://www.pinterest.com/pin/123/', pinIdentity: value => value,
    search: { pageKey: 'https://www.pinterest.com/search/', discoveryApi: false },
    currentSearchPageKey: () => 'https://www.pinterest.com/search/' });
  const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
  native.searchStore = Object.assign(new searchRuntime.Store(), native.searchStore);
  searchRuntime.bindIndex(native);
  await native.selectSearchFilter('filter'); await native.selectProfilePublish('publish');
  await native.performProfileAction('settings'); await native.performInboxAction('dom-update');
  await native.performSearchAction('hero', 'hero'); await native.performDetailAction('source', 'source');
  assert.equal(effects, 0, 'unintegrated controls cause no request, navigation or feedback');
  Object.assign(native, { authStatus: 'authenticated', navigationAddress: 'https://www.pinterest.com/login/' });
  assert.equal(native.authWebVisible(), false, 'authenticated state never exposes website UI');
  native.authStatus = 'unauthenticated'; assert.equal(native.authWebVisible(), true);
  native.navigationAddress = 'https://www.pinterest.com/'; assert.equal(native.authWebVisible(), false);
  let resetCount = 0, currentUrl = message.pageUrl;
  const loaded = [];
  Object.assign(native, { authEpoch: 3, authStatus: 'authenticated', authCheckTimer: -1,
    controller: { getUrl: () => currentUrl, loadUrl: url => loaded.push(url), runJavaScript: async () => 'true' },
    homeCacheAccountIdFromProfileUrl: value => value || '', homePageKeyFromAddress: () => '',
    tryRestoreAuthenticatedHome() {}, profileUrlFromAddress: value => value || '',
    resetAuthenticatedContent() { resetCount++; }, configureDocumentRetention() {}, bindNativeNetwork() {}, tabsController: { changeIndex() {} },
    pageHistory: { reset() {} }, isHomeRootAddress: () => false });
  native.updateAuthState(JSON.stringify({ ...message, epoch: 2, status: 'unauthenticated' }));
  assert.equal(native.authStatus, 'authenticated'); assert.equal(resetCount, 0);
  native.updateAuthState(JSON.stringify({ ...message, status: 'unauthenticated' }));
  assert.equal(resetCount, 1); assert.equal(native.authStatus, 'unauthenticated');
  assert.equal(loaded.at(-1), context.PINTEREST_LOGIN_URL);
  currentUrl = context.PINTEREST_LOGIN_URL;
  native.updateAuthState(JSON.stringify({ ...message, pageUrl: currentUrl }));
  assert.equal(native.authStatus, 'authenticated'); assert.equal(loaded.at(-1), context.PINTEREST_URL);
  let clearedDetails = 0, clearedCache = 0, clearedPrefetch = 0;
  Object.assign(native, { homeCacheAccountId: 'old-account', clearOfflineHomeMarker() {}, clearRootTabCaches() {},
    nativeNetwork: { invalidate() {} }, clearDetail() { clearedDetails++; },
    pinStore: { detailCache: { clear() { clearedCache++; } }, clearDetailOrigins() {},
      detailPrefetch: { clear() { clearedPrefetch++; } }, confirmedSaves: { clear() {} } } });
  native.detailCache = native.pinStore.detailCache;
  native.detailPrefetch = native.pinStore.detailPrefetch;
  native.confirmedSaves = native.pinStore.confirmedSaves;
  native.updateAuthState(JSON.stringify({ ...message, pageUrl: currentUrl, profileUrl: 'https://www.pinterest.com/new-account/' }));
  assert.equal(clearedDetails, 1, 'account switch discards old detail state and pending intentions');
  assert.equal(clearedCache, 1, 'account switch discards old cached presentation');
  assert.equal(clearedPrefetch, 1, 'account switch discards old prefetch data');
  assert.match(source, /\.hitTestBehavior\(this.authWebVisible\(\) \? HitTestMode.Default : HitTestMode.None\)/);
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
  assert.ok(build.indexOf('this.buildRootTabs()') < build.indexOf('PinWebSettingsPage({'),
    'secondary pages cover Tabs rather than placing an empty overlay above them');
  console.log('Auth gate, session evidence, stale responses, hidden host and unsupported-action checks passed');
}
check().catch(error => { console.error(error); process.exitCode = 1; });
