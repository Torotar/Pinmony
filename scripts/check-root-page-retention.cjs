const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts;
try { ts = require('typescript'); } catch (_) { ts = require(process.argv[2]); }
const root = 'entry/src/main/ets/';
const source = readSourceFileSync(root + 'pages/Index.ets', 'utf8');
const flush = () => new Promise(resolve => setImmediate(resolve));
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const end = source.indexOf('\n  private ', start + 1);
  return source.slice(start, end);
}
function compile(code, context = {}) {
  vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
  return context;
}
function apiHarness(file, flags) {
  const src = readSourceFileSync(root + 'services/' + file, 'utf8');
  const script = Function('return `' + src.match(/`([\s\S]*?)`;/)[1] + '`')();
  const requests = [], window = { ...flags }; window.top = window;
  const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/inbox/', search: '' };
  vm.runInNewContext(script, { window, location, URL, URLSearchParams, AbortController, setTimeout, clearTimeout,
    document: { cookie: '' }, console,
    fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
  const respond = async (index, data, bookmark = 'next') => {
    requests[index].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0, data, bookmark } }) });
    await flush();
  };
  return { requests, window, respond };
}
async function main() {
  const caches = ['PinmonyInboxCache', 'PinmonySearchCache', 'PinmonyProfileCache'].map(name =>
    readSourceFileSync(root + 'services/' + name + '.ets', 'utf8').replace(/^import .*;\r?\n/m, '').replace(/export /g, '')).join('\n');
  const context = compile(caches + '\n' + 'class Native {' +
    ['inboxUrlFromAddress', 'clearInbox', 'restoreInbox', 'updateInbox', 'clearRootTabCaches']
      .map(method).join('\n') + '}\nglobalThis.Native=Native; globalThis.InboxCache=PinmonyInboxCache;' +
    'globalThis.SearchCache=PinmonySearchCache;globalThis.ProfileCache=PinmonyProfileCache;',
    { console, PinmonyRuntimeLog: { info() {} }, PINTEREST_URL: 'https://www.pinterest.com/', setTimeout: () => 0 });
  const native = new context.Native(), url = 'https://www.pinterest.com/inbox/';
  Object.assign(native, { finishRootPull() {}, inboxCache: new context.InboxCache(), searchCache: new context.SearchCache(),
    profileCache: new context.ProfileCache(), rootTabAddresses: new Map(), inboxRequestToken: 0,
    currentInboxUrl: () => url, inboxSession: 0, inboxActionsReady: true, inboxLoading: false,
    inboxError: '', inboxScrollOffset: 420, pendingInboxSection: '', restoringInboxSection: '',
    controller: { runJavaScript: async () => 'true' } });
  const snapshot = { kind: 'state', session: 9, pageUrl: url, section: 'updates',
    updateLabel: 'Updates', inboxLabel: 'Inbox', items: [{ id: 'old', title: 'Old', enabled: true }], contacts: [] };
  native.inbox = snapshot;
  native.clearInbox();
  assert(native.restoreInbox(url));
  assert.equal(native.inboxScrollOffset, 420);
  assert.equal(native.inboxActionsReady, false, 'cached controls are never immediately live');
  native.updateInbox(JSON.stringify({ ...snapshot, session: 1, kind: 'apiPending', items: [] }));
  assert.equal(native.inbox.items.length, 1, 'pending state retains completed cards');
  assert.equal(native.inboxLoading, false);
  native.updateInbox(JSON.stringify({ ...snapshot, session: 1, kind: 'apiFailed', items: [] }));
  assert.equal(native.inbox.items.length, 1);
  assert(native.inboxError);
  native.updateInbox(JSON.stringify({ ...snapshot, session: 1, items: [] }));
  assert.equal(native.inbox.items.length, 0, 'successful empty response replaces cached cards');
  assert.equal(native.inboxActionsReady, true);
  native.inboxCache.put(snapshot, 420);
  native.inboxCache.put({ ...snapshot, section: 'messages' }, 85);
  assert.equal(native.inboxCache.get(url, 'updates').scrollOffset, 420);
  assert.equal(native.inboxCache.get(url, 'messages').scrollOffset, 85);
  assert.equal(native.inboxCache.get('https://www.pinterest.com/messages/'), undefined, 'page keys remain isolated');

  require('node:child_process').execFileSync(process.execPath,
    ['scripts/check-native-root-switch.cjs', process.argv[2]], { stdio: 'inherit' });
  Object.assign(native, { clearHome() {}, clearSearch() {}, clearProfile() {}, clearInbox() {},
    clearRootTabGuard() {}, clearOfflineHomeMarker() {}, detailReturnReads: new Map(),
    homeStore: new (require('./home-controller-harness.cjs').createHomeRuntime(ts).Store)() });
  native.cachedHome = {}; native.retainedSearch = {};
  native.clearRootTabCaches();
  assert.equal(native.rootTabAddresses.size, 0);
  assert.equal(native.inboxCache.get(url), undefined);
  assert.equal(native.cachedHome, undefined);
  assert.equal(native.retainedSearch, undefined);

  const news = apiHarness('PinmonyInboxApiScript.ets', { PinmonyInboxApiEnabled: true });
  const api = news.window.PinmonyInboxApi, read = () => api.read(url, () => {}, () => true);
  read(); await news.respond(0, [{ type: 'news', id: 'sample', header_text: 'Sample' }]);
  api.more(() => {}, () => true); api.pause();
  assert.equal(news.requests[1].args.signal.aborted, true);
  await news.respond(1, []);
  assert.equal(read().items.length, 1, 'cancelled pagination cannot overwrite the retained list');
  assert.equal(news.requests.length, 2, 'return does not read first page again');
  assert(api.more(() => {}, () => true));
  const options = JSON.parse(new URL(news.requests[2].url, 'https://www.pinterest.com').searchParams.get('data')).options;
  assert.equal(options.bookmarks[0], 'next');
  await news.respond(2, [], '-end-'); api.reset();
  const home = apiHarness('PinmonyHomeApiScript.ets', { PinmonyHomeApiEnabled: true });
  const homeApi = home.window.PinmonyHomeApi;
  homeApi.read('home:all', true, () => {}, () => true);
  await home.respond(0, [{ type: 'pin', id: '123', images: { '474x': { url: 'https://i.pinimg.com/sample.jpg', width: 474, height: 700 } } }]);
  homeApi.pause();
  assert.equal(homeApi.read('home:all', true, () => {}, () => true).pins.length, 1);
  assert.equal(home.requests.length, 1);
  homeApi.reset();
  console.log('Four-tab retention: cached inbox states/scroll, control rebinding, empty/error, native tab switches, auth clearing and API pagination passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
