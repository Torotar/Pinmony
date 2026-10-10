const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts;
try { ts = require('typescript'); } catch (_) { ts = require(process.argv[2]); }
const source = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert.ok(start >= 0);
  const end = source.indexOf('\n  private ', start + 1);
  return source.slice(start, end);
}
const names = ['nativeDisplayAddress', 'boardUrlFromAddress', 'currentBoardUrl', 'syncBoardRoute', 'nativeBoardVisible', 'openProfileBoard', 'backFromBoard', 'pinIdentity', 'isCurrentBoardMenuPin', 'openBoardPinMore', 'shareCurrentBoard'];
const code = ts.transpileModule('class Native {' + names.map(method).join('\n') + '} globalThis.Native = Native;',
  { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const timers = [], context = { PIN_BOARD_API_ENABLED: true, PIN_POST_API_ENABLED: true, setTimeout: fn => timers.push(fn),
  PinmonyRuntimeLog: { info() {}, warn() {} } };
vm.runInNewContext(code, context);
const from = 'https://www.pinterest.com/sample/_saved/', target = 'https://www.pinterest.com/sample/board/';
function harness(destination = target, failNavigation = false) {
  const native = new context.Native();
  const aliases = JSON.parse(fs.readFileSync('scripts/feature-state-aliases.json', 'utf8'));
  for (const [name, alias] of Object.entries(aliases)) {
    native[alias.store] ||= {};
    Object.defineProperty(native, name, { get() { return this[alias.store][alias.field]; },
      set(value) { this[alias.store][alias.field] = value; } });
  }
  let address = from;
  const navigations = [];
  const backTargets = [];
  Object.assign(native, { loadFailed: false, pendingBoardUrl: '', pendingBoardSource: '', boardOpeningToken: 0,
    authStatus: 'authenticated', activeTab: 3, tabRequestToken: 0, rootTabAddresses: new Map(),
    profileStore: { origins: [], profileCache: { put() {} } }, clearRootTabGuard() {},
    cancelledBoardPins: new Set(),
    boardReturnUrl: '', boardReturnPage: '', backOnePage: (fallback, override) => backTargets.push(override || fallback),
    pageHistory: { key: url => url.split(/[?#]/)[0], visit() {}, cancelBack() {} }, controller: { getUrl: () => address, loadUrl: url => {
      assert.equal(native.nativeBoardVisible(), true, 'native cover exists before opening the board');
      if (failNavigation) throw new Error('navigation unavailable');
      navigations.push(url);
    } },
    currentProfileUrl: () => 'https://www.pinterest.com/sample/', showMessage() {}, traceAction() {},
    extractPinUrl: url => /\/pin\/\d+\//.test(url) ? url : '',
    profileUrlFromAddress: url => url === from || url === 'https://www.pinterest.com/sample/' ? 'https://www.pinterest.com/sample/' : '',
    nativeRootPageAddress: () => '',
    boardOperation(method, value) { this.lastBoardAction = JSON.parse(value).action; },
    profile: { profileUrl: 'https://www.pinterest.com/sample/', boards: [{ id: 'card', title: 'Board',
      targetUrl: destination, pinCount: '2 张 Pin 图' }] }, handleBack() { backTargets.push('generic-history'); } });
  // Returning to the source clears the opening cover before dispatch.
  const loadUrl = native.controller.loadUrl;
  native.controller.loadUrl = url => url === from ? navigations.push(url) : loadUrl(url);
  require('./board-state-controller-harness.cjs').bind(native, ts, { setTimeout: () => 0, clearTimeout() {} });
  const r = require('./return-coordinator-harness.cjs').runtime(ts);
  const { PinmonyBoardInvitationController } = r.compile('feature_inbox/src/main/ets/controllers/PinmonyBoardInvitationController.ets', () => r.foundation);
  native.inboxStore.boardInvitationToken = 0;
  native.boardInvitationController = new PinmonyBoardInvitationController(native.inboxStore, {});
  return { native, backTargets, navigations, navigate: url => { address = url; } };
}
async function main() {
  const menu = harness();
  menu.navigate(target);
  menu.native.authStatus = 'authenticated';
  const pin = { id: '101', pinUrl: 'https://www.pinterest.com/pin/101/' };
  menu.native.boardStore.boardDetail = { session: 1, ready: true, pageKey: target, pins: [pin] };
  const menus = [];
  menu.native.openCustomHomeMenu = (url, page) => menus.push({ url, page });
  menu.native.openBoardPinMore('101');
  assert.deepEqual(menus, [{ url: pin.pinUrl, page: target }], 'card menu uses its board route');
  const shares = [];
  menu.native.controller.runJavaScript = async script => { shares.push(script); return 'true'; };
  menu.native.boardStore.boardDetail.title = '图板';
  await menu.native.shareCurrentBoard();
  assert.equal(shares.length, 1);
  assert(shares[0].includes('PinmonyNativeShareApiOpen(' + JSON.stringify(target) + ')'), 'share opens the existing native panel for the current board');
  menu.native.openBoardPinMore('999');
  assert.equal(menus.length, 1, 'unknown card cannot open a menu');
  menu.native.boardStore.boardDetail.flow = { phase: 'targets', busy: false };
  menu.native.openBoardPinMore('101');
  assert.equal(menus.length, 1, 'move selection cannot open a card menu');
  menu.native.boardStore.boardDetail.flow = { phase: 'ideas', busy: false, pins: [pin] };
  menu.native.openBoardPinMore('101');
  assert.equal(menus.length, 2, 'recommendation card uses the same menu');
  menu.navigate('https://www.pinterest.com/sample/other/');
  menu.native.shareCurrentBoard();
  assert.equal(shares.length, 1, 'stale board cannot be shared');
  menu.native.openBoardPinMore('101');
  assert.equal(menus.length, 2, 'stale board cannot operate a card');
  const h = harness();
  const opening = h.native.openProfileBoard('card');
  assert.equal(h.native.boardDetail.title, 'Board');
  h.native.syncBoardRoute(from);
  assert.equal(h.native.nativeBoardVisible(), true, 'late source-page callback cannot expose the website');
  h.native.syncBoardRoute(target);
  assert.equal(h.native.nativeBoardVisible(), true, 'page-begin before getUrl must retain the cover');
  assert.equal(h.native.pendingBoardUrl, target);
  h.navigate(target); h.native.syncBoardRoute(target);
  assert.equal(h.native.pendingBoardUrl, '');
  assert.equal(h.native.nativeBoardVisible(), true, 'handoff to the current board has no visibility gap');
  assert.deepEqual(h.navigations, [target], 'validated board route uses direct background navigation');
  await opening;
  h.navigate('https://www.pinterest.com/pin/123/'); h.native.syncBoardRoute('https://www.pinterest.com/pin/123/');
  assert.equal(h.native.nativeBoardVisible(), true, 'board stays mounted beneath its child Pin');
  assert.equal(h.native.boardStore.presentationOnly, true);
  assert.equal(h.native.boardDetail.session, 0, 'departed board controls cannot be reused');
  const failure = harness(target, true); await failure.native.openProfileBoard('card');
  assert.equal(failure.native.pendingBoardUrl, ''); assert.equal(failure.native.boardDetail, undefined);
  const back = harness(); const interrupted = back.native.openProfileBoard('card');
  back.native.backFromBoard(); await interrupted;
  assert.deepEqual(back.navigations, [target, from], 'cancelled opening returns to its source');
  assert.equal(back.native.pendingBoardUrl, ''); assert.equal(back.native.nativeBoardVisible(), false);
  timers.forEach(fn => fn());
  assert.equal(back.native.boardDetail, undefined, 'cancelled timer cannot restore a cover');
  for (const destination of [target, 'https://www.pinterest.com/sample/pins/']) {
    const returned = harness(destination); const opened = returned.native.openProfileBoard('card');
    returned.navigate(destination); returned.native.syncBoardRoute(destination);
    await opened;
    assert.equal(returned.native.pendingBoardSource, '', 'transient opening source is released');
    returned.navigate('https://www.pinterest.com/pin/123/');
    returned.native.syncBoardRoute('https://www.pinterest.com/pin/123/');
    returned.navigate(destination); returned.native.syncBoardRoute(destination);
    returned.native.backFromBoard();
    assert.deepEqual(returned.backTargets, [from], 'board and all-pins return to the exact My origin even after a Pin visit');
    returned.navigate('https://www.pinterest.com/sample/other/');
    returned.native.syncBoardRoute('https://www.pinterest.com/sample/other/'); returned.native.backFromBoard();
    assert.equal(returned.backTargets.at(-1), 'generic-history', 'another board cannot reuse the stored origin');
  }
  console.log('Board opening handoff checks passed');
  const nested = harness(); nested.native.boardDetail = { flow: { phase: 'targets', busy: false } };
  nested.native.backFromBoard(); assert.equal(nested.native.lastBoardAction, 'select');
  nested.native.boardDetail.flow.phase = 'ideas'; nested.native.backFromBoard();
  assert.equal(nested.native.lastBoardAction, 'close');
  nested.native.boardDetail.flow.phase = 'targets'; nested.native.boardDetail.flow.uncertain = true;
  nested.native.backFromBoard(); assert.equal(nested.native.lastBoardAction, 'close', 'unknown move can close for refresh');
  nested.native.boardDetail.flow.busy = true; nested.native.lastBoardAction = '';
  nested.native.backFromBoard(); assert.equal(nested.native.lastBoardAction, '', 'write locks system back');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
