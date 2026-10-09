const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '('), rest = source.slice(start);
  assert.ok(start >= 0, name);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
const callback = source.match(/    this.shareBridge.onPageNavigation = [\s\S]*?(?=\r?\n    this.shareBridge.onShare)/)[0];
const home = 'https://www.pinterest.com/', pin = home + 'pin/123/';
const settings = [], events = [], auth = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_session/src/main/ets/models/PinWebAuth.ets', 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText, { exports: auth });
const context = { ...auth, PINTEREST_URL: home, PINTEREST_LOGIN_URL: home + 'login/',
  webview: { BackForwardCacheOptions: class {} }, clearTimeout() {},
  PinWebRuntimeLog: { info() {}, warn() {} }, retainHomePins: (_old, pins) => pins };
vm.runInNewContext(ts.transpile('class Native { constructor() { this.shareBridge={};' + callback + '} ' +
  ['configureDocumentRetention', 'updateAuthState', 'updateHome'].map(method).join('\n') + '} globalThis.Native=Native;',
  { target: ts.ScriptTarget.ES2021 }), context);
const native = new context.Native();
const cached = { pageKey: home, kind: 'state', session: 1, selectedTab: 'all', dataSource: 'api',
  tabs: [{ id: 'all', label: 'All', selected: true }, { id: 'board', label: 'Board' }],
  pins: [{ id: '123', pinUrl: pin, imageUrl: 'https://i.pinimg.com/a.jpg' }] };
Object.assign(native, { authStatus: 'authenticated', authEpoch: 9, authCheckTimer: -1, pinStore: { confirmedSaves: { isSaved: () => false } },
  homeStore: { home: cached, cachedHome: cached, homeActionsReady: true, homeRequestToken: 1 },
  searchStore: { knownSearchPinTitles: new Map() }, rootTabAddresses: new Map(), nativeBackTarget: home,
  controller: { getUrl: () => home, runJavaScript: async () => 'true', setBackForwardCacheOptions(options) { settings.push(options); } },
  pageHistory: { key: url => url }, homePageKeyFromAddress: url => url === home ? home : '',
  pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '',
  nativeNetwork: { invalidate() { events.push('invalidate'); } },
  recordPageNavigation() { this.nativeBackTarget = ''; events.push('route'); }, syncAuthentication() { events.push('auth'); },
  currentHomePageKey: () => home, bindNativeNetwork() { events.push('bind'); }, requestHomeTitles() {},
  normalizeHomeBoard: () => undefined, persistHomeDiskCache() {},
  profileUrlFromAddress: () => '', homeCacheAccountIdFromProfileUrl: () => '', tryRestoreAuthenticatedHome() {},
  ignoreSupersededDetailDocument: () => false, bindCurrentDetailDocument() {}, showMessage() {} });
native.configureDocumentRetention(true); native.configureDocumentRetention(false);
assert.deepEqual(settings.map(value => [value.size, value.timeToLive]), [[4, 300], [0, 300]], 'bounded retention is disabled at login/session loss');
native.shareBridge.onPageNavigation(home, 'restore');
assert.equal(native.authEpoch, 10); assert.equal(native.homeStore.homeActionsReady, false);
assert.equal(native.retainedHomeAwaitingAuth, true); assert.deepEqual(events, ['invalidate', 'route', 'auth']);
native.updateHome(JSON.stringify({ ...cached, session: 2 }));
assert.equal(native.homeStore.homeActionsReady, false, 'retained feed cannot enable before current auth rebind');
native.updateAuthState(JSON.stringify({ status: 'authenticated', epoch: 9, pageUrl: home, profileUrl: '' }));
assert.equal(native.retainedHomeAwaitingAuth, true, 'old epoch cannot resume controls');
native.updateAuthState(JSON.stringify({ status: 'authenticated', epoch: 10, pageUrl: home, profileUrl: '' }));
assert.equal(native.retainedHomeAwaitingAuth, false); assert.ok(events.includes('bind'));
native.updateHome(JSON.stringify({ ...cached, session: 2 }));
assert.equal(native.homeStore.homeActionsReady, true); assert.equal(native.retainedHomeAwaitingFeed, false);
native.nativeBackTarget = home; const epoch = native.authEpoch;
native.shareBridge.onPageNavigation(pin, 'restore'); assert.equal(native.authEpoch, epoch, 'obsolete restored child cannot replace home');
const reset = method('resetAuthenticatedContent');
assert.ok(reset.includes('this.configureDocumentRetention(false)') && reset.includes('this.controller.clearHistory()'), 'explicit logout/session loss prevents back into old account documents');
const ability = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
assert.ok(ability.indexOf('enableBackForwardCache(features)') < ability.indexOf('initializeWebEngine()'), 'platform requires enabling before engine initialization');
const navTemplate = fs.readFileSync('entry/src/main/ets/app/PinWebNavigationScript.ets', 'utf8').match(/`([\s\S]*?)`;/)[1];
const browserEvents = {}, notices = [];
const window = { top: null, PinWebShareBridge: { pageNavigation: (_url, mode) => notices.push(mode) },
  addEventListener(name, fn) { browserEvents[name] = fn; } }; window.top = window;
vm.runInNewContext(Function('return `' + navTemplate + '`')(), { window, location: { href: home },
  history: { pushState() {}, replaceState() {}, back() {}, go() {} }, document: { querySelectorAll: () => [], addEventListener() {} } });
browserEvents.pageshow({ persisted: true }); assert.equal(notices.at(-1), 'restore');
browserEvents.pageshow({ persisted: false }); assert.equal(notices.at(-1), 'observe');
console.log('Document retention: platform setup, bounded lifetime, real restore event, epoch/auth guards, current controls and logout history isolation passed');
