const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const history = fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationHistory.ets', 'utf8').replace('export class', 'class');
const method = source.match(/  private backOnePage\([\s\S]*?(?=\r?\n  private async backFromDetail)/)[0];
const loadMethod = source.match(/  private loadReturnTarget\([\s\S]*?(?=\r?\n  private backOnePage)/)[0];
const timers = [];
const context = { PINTEREST_URL: 'https://www.pinterest.com/', setTimeout: callback => timers.push(callback),
  PinmonyRuntimeLog: { info() {}, warn() {} } };
vm.runInNewContext(ts.transpile(history + '\nclass Native {' + loadMethod + method + '} globalThis.Native = Native; globalThis.History = PinmonyNavigationHistory;',
  { target: ts.ScriptTarget.ES2020 }), context);
const home = 'https://www.pinterest.com/', pin = home + 'pin/123/';
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness(result = 'true') {
  const native = new context.Native(), events = [];
  const pageHistory = new context.History();
  pageHistory.visit(pin); // Native child exists before Web completes its history entry.
  Object.assign(native, { pageHistory, pageBackToken: 0, pinStore: { detail: { pinUrl: pin }, detailPrefetch: { pause() { events.push('pause'); } } },
    pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '', bindCurrentDetailDocument() {},
    searchUrlFromAddress: () => '', boardUrlFromAddress: () => '', restoreRetainedSearch() {}, isHomeRootAddress: url => url === home,
    nativeNetwork: { invalidate() { events.push('cancel'); } },
    presentNativeBackTarget(target) { events.push('present'); this.nativeBackTarget = target; this.pinStore.detail = undefined; },
    returnToHistoryEntry() { events.push('history'); return false; },
    controller: { stop() { events.push('stop'); }, getUrl: () => home,
      runJavaScript: async () => result, loadUrl: url => events.push('load:' + url) },
    recordPageNavigation(url) { pageHistory.visit(url, 'load'); this.nativeBackTarget = ''; },
    syncAuthentication() { events.push('auth'); }, showMessage(message) { events.push('notice'); } });
  require('./return-coordinator-harness.cjs').bind(native, ts, { setTimeout: fn => timers.push(fn), clearTimeout() {} });
  return { native, events };
}
async function main() {
  const reused = harness();
  assert.equal(reused.native.backOnePage(home, home), true);
  assert.equal(reused.native.pinStore.detail, undefined, 'return removes native detail before any asynchronous document inspection');
  assert.deepEqual(reused.events, ['present', 'cancel', 'pause']);
  assert.ok(!method.includes('this.controller.stop()'), 'native return must not abort the Web document before target navigation');
  await flush();
  assert.equal(reused.events.some(value => value.startsWith('load:')), false, 'confirmed retained home document avoids a reload');
  assert.equal(reused.native.nativeBackTarget, '');
  assert.equal(reused.native.pageHistory.isPending(), false);
  for (const pending of ['webPageLoading', 'detailOpeningPin']) {
    const unfinished = harness();
    if (pending === 'webPageLoading') unfinished.native.webPageLoading = true;
    else unfinished.native.pinStore.detailOpeningPin = pin;
    unfinished.native.backOnePage(home, home);
    assert.ok(unfinished.events.includes('load:' + home), 'unfinished child navigation must be superseded even if getUrl still reports home');
    assert.ok(!unfinished.events.includes('stop'));
  }
  const replaced = harness('false');
  replaced.native.backOnePage(home, home);
  assert.equal(replaced.native.pinStore.detail, undefined);
  await flush();
  assert.ok(replaced.events.includes('load:' + home), 'a mismatched document follows the real home navigation');
  timers.pop()();
  assert.equal(replaced.native.nativeBackTarget, home, 'timeout cannot resurrect the abandoned Pin');
  assert.equal(replaced.native.pinStore.detail, undefined);
  const superseded = harness('false');
  superseded.native.backOnePage(home, home);
  superseded.native.pageBackToken++;
  await flush();
  assert.equal(superseded.events.some(value => value.startsWith('load:')), false, 'a new navigation discards old inspection results');
  assert.match(source, /this\.nativeBackTarget &&\s*this\.pageHistory\.key\(event\.url\) !== this\.pageHistory\.key\(this\.nativeBackTarget\)/,
    'late page-begin callbacks cannot reopen the source');
  const nav = fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationScript.ets', 'utf8').match(/`([\s\S]*)`;/)[1];
  const domListeners = {}, observed = [];
  const window = { top: null, PinmonyShareBridge: { pageNavigation: (_url, mode) => observed.push(mode) }, addEventListener() {} };
  window.top = window;
  vm.runInNewContext(Function('return `' + nav + '`')(), { window, location: { href: home },
    history: { pushState() {}, replaceState() {}, back() {}, go() {} },
    document: { addEventListener(name, fn) { domListeners[name] = fn; }, querySelectorAll: () => [] } });
  domListeners.DOMContentLoaded();
  assert.equal(observed.at(-1), 'ready', 'auth binding can run at DOM readiness before page-end');
  const auth = fs.readFileSync('common_session/src/main/ets/services/PinmonyAuthScript.ets', 'utf8').match(/`([\s\S]*)`;/)[1];
  let initial = null, observerCallback, disconnected = false;
  const authMessages = [];
  const authWindow = { PinmonyShareBridge: { authState: value => authMessages.push(JSON.parse(value)) } };
  authWindow.top = authWindow;
  class Observer {
    constructor(callback) { observerCallback = callback; }
    observe() {}
    disconnect() { disconnected = true; }
  }
  vm.runInNewContext(Function('return `' + auth + '`')(), { window: authWindow, URL,
    location: { href: home, origin: home.slice(0, -1), hostname: 'www.pinterest.com', pathname: '/' },
    MutationObserver: Observer, document: { getElementById: () => initial, addEventListener() {} } });
  authWindow.PinmonyAuthSync(7);
  assert.equal(authMessages.length, 0, 'early binding still requires explicit login evidence');
  initial = { textContent: JSON.stringify({ initialReduxState: { session: { isAuthenticated: true,
    user: { id: '123', username: 'sample' } } } }) };
  observerCallback();
  assert.equal(authMessages.at(-1).status, 'authenticated', 'streamed initialization evidence can publish before page-end');
  assert.equal(authMessages.at(-1).epoch, 7);
  assert.equal(disconnected, true, 'evidence observation stops after confirmation');
  const page = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets', 'utf8');
  const pageMethods = ['onHomeChanged', 'onPrefetchAvailabilityChanged', 'prefetchVisibleDetails', 'feedStatusText'].map(name => {
    const start = page.indexOf('  private ' + name + '(');
    const rest = page.slice(start);
    const end = rest.slice(1).search(/\n  (?:private |@Builder)/) + 1;
    return rest.slice(0, end);
  }).join('\n');
  const allowsSpeculativeReads = () => true;
  const pageCtx = { allowsSpeculativeReads, setTimeout: callback => callback() };
  vm.runInNewContext(ts.transpile('class Feed { ' + pageMethods + '} globalThis.Feed = Feed;', { target: ts.ScriptTarget.ES2020 }), pageCtx);
  const feed = new pageCtx.Feed(), ranges = [];
  Object.assign(feed, { activeSession: 1, activePageKey: home, activeTab: 'all', visibleFirst: 10, visibleLast: 15,
    home: { session: 2, pageKey: home, selectedTab: 'all', pins: Array.from({ length: 30 }) }, feedActive: true, actionsReady: true,
    updateCategories() {}, prefetchNextScreen() {}, onPrefetchPins: (first, last) => ranges.push([first, last]) });
  feed.onHomeChanged();
  assert.deepEqual(ranges, [[10, 15]], 'session rebind resumes the retained viewport without another scroll event');
  assert.equal(feed.feedStatusText(), '正在恢复首页连接…');
  feed.refreshing = true;
  assert.equal(feed.feedStatusText(), '正在刷新首页…', 'route restoration is distinct from actual refresh');
  feed.refreshing = false;
  feed.home.selectedTab = 'board';
  feed.onHomeChanged();
  assert.equal(feed.visibleLast, -1, 'a different category waits for its own visible range');
  console.log('Home return timing: immediate dismissal, navigation cancellation, retained document reuse, stale guards, timeout and early auth trigger passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
