const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const timers = [], log = [];
const home = 'https://www.pinterest.com/', board = home + 'sample/board/', pin = home + 'pin/101/';
const context = { PIN_BOARD_API_ENABLED: true, PINTEREST_URL: home, Date,
  setTimeout: fn => timers.push(fn),
  PinmonyRuntimeLog: { info: value => log.push(value), warn: value => log.push(value) } };
vm.runInNewContext(ts.transpileModule('class Native {' + ['boardUrlFromAddress', 'currentBoardUrl',
  'syncBoardRoute', 'nativeBoardVisible', 'presentNativeBackTarget', 'backOnePage', 'loadReturnTarget',
  'boardOperation', 'updateBoard', 'handleMainFrameFailure', 'backFromBoard'].map(method).join('\n') + '} globalThis.Native = Native;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
function harness() {
  const n = new context.Native(), loads = [];
  let address = board;
  const snapshot = { kind: 'state', session: 8, pageKey: board, title: 'Board', boardId: '1',
    pinCount: '1', ownerName: '', ownerAvatar: '', ready: true, loading: false, loadingMore: false,
    error: '', hasMore: true, pins: [{ id: '101', pinUrl: pin, title: '', imageUrl: 'https://example.test/image.jpg',
      imageWidth: 100, imageHeight: 100 }] };
  Object.assign(n, { authStatus: 'authenticated', activeTab: 3, nativeRootOnly: false, loadFailed: false,
    pinStore: { detail: { pinUrl: pin }, detailPin: pin, detailCache: { get() {} }, detailPrefetch: { pause() {} } },
    boardStore: { boardDetail: snapshot, rootTab: 3 }, homeStore: { homeRefreshToken: 0 },
    profileStore: {}, searchStore: {}, inboxStore: {}, pageBackToken: 0,
    extractPinUrl: value => /\/pin\/\d+\//.test(value) ? value : '',
    pinIdentity: value => String(value || '').match(/\/pin\/(\d+)\//)?.[1] || '',
    nativeDisplayAddress() { return this.nativeBackTarget || address; }, rootTabIndexFromAddress: () => -1,
    clearRootTabGuard() {}, clearDetail() { this.pinStore.detail = undefined; this.pinStore.detailOpeningPin = ''; },
    restoreRetainedSearch() {}, searchUrlFromAddress: () => '', profileUrlFromAddress: () => '', isHomeRootAddress: value => value === home,
    tabsController: { changeIndex() {} }, nativeNetwork: { invalidate() {} },
    detailReturnJourney: { mark: value => log.push(value) },
    pageHistory: { isPending: () => false, prepareBackTo: value => value, key: value => value, cancelBack() {}, visit() {} },
    returnToHistoryEntry() { throw Error('board return must not use Web history'); },
    controller: { getUrl: () => address, runJavaScript: async () => 'true', loadUrl: value => loads.push(value) },
    showMessage() {}, isCurrentPageFailure: value => value === address, effectiveRootDocumentTarget: () => 3,
    showNetworkNotice() {}, describeFailure: () => 'failure' });
  return { n, snapshot, loads, navigate: value => { address = value; } };
}
const h = harness();
h.n.syncBoardRoute(pin); h.navigate(pin);
assert.equal(h.n.boardStore.boardDetail, h.snapshot, 'keep the same board component input beneath the child');
assert.equal(h.n.nativeBoardVisible(), true);
assert.equal(h.snapshot.session, 0, 'old action session is invalidated');
assert.equal(h.n.backOnePage(board, board), true);
assert.equal(h.n.pinStore.detail, undefined);
assert.equal(h.n.activeTab, 3, 'return preserves My root');
assert.equal(h.n.nativeBoardVisible(), true, 'board covers the root before Web confirmation');
assert.deepEqual(h.loads, [board]);
for (const timer of timers.splice(0)) timer();
assert.deepEqual(h.loads, [board], 'timeouts never trigger a second navigation');
assert.match(h.snapshot.error, /超时/);
h.navigate(board); h.n.nativeBackTarget = '';
h.n.handleMainFrameFailure(board, -2, 'ERR_FAILED');
assert.equal(h.n.loadFailed, false);
assert.equal(h.n.boardStore.boardDetail, h.snapshot);
assert.equal(h.n.activeTab, 3);
assert.match(h.snapshot.error, /连接失败/);
h.n.boardOperation('more');
assert.deepEqual(h.loads, [board], 'cached pagination cannot use the departed session');
h.n.boardOperation('retry');
assert.deepEqual(h.loads, [board, board], 'manual retry performs one real navigation');
const message = { ...h.snapshot, session: 10, pins: [], loading: true, ready: false, error: '' };
h.n.updateBoard(JSON.stringify(message));
assert.equal(h.n.boardStore.boardDetail, h.snapshot, 'preparation cannot erase cached pins');
h.n.updateBoard(JSON.stringify({ ...message, loading: false, ready: true, hasMore: false }));
assert.equal(h.n.boardStore.presentationOnly, false);
assert.equal(h.n.boardStore.boardDetail.pins.length, 0, 'confirmed empty replaces stale content');
assert.equal(h.n.boardStore.boardDetail.session, 10);
h.n.updateBoard(JSON.stringify({ ...message, session: 9, ready: true }));
assert.equal(h.n.boardStore.boardDetail.session, 10, 'older session cannot replace confirmation');
const abandoned = harness(); abandoned.n.syncBoardRoute(pin); abandoned.navigate(pin);
abandoned.n.backOnePage(board, board); abandoned.n.pageBackToken++;
const before = abandoned.snapshot.error;
for (const timer of timers.splice(0)) timer();
assert.equal(abandoned.snapshot.error, before, 'superseded return timeout cannot mutate the next page');
const continuous = harness(); continuous.n.syncBoardRoute(pin); continuous.navigate(pin);
continuous.n.backOnePage(board, board);
continuous.n.boardStore.boardReturnUrl = home + 'sample/_saved/';
continuous.n.boardStore.boardReturnPage = board;
const parents = [];
continuous.n.backOnePage = (fallback, target) => parents.push(target);
continuous.n.backFromBoard();
assert.deepEqual(parents, [home + 'sample/_saved/'], 'second back uses the visible board origin while Web is still on the Pin');
assert.equal(continuous.n.nativeBackTarget, '');
const cold = harness(); cold.n.boardStore.boardDetail = undefined;
cold.n.backOnePage(board, board);
assert.equal(cold.n.nativeBoardVisible(), true, 'no snapshot immediately presents a native board loading page');
assert.equal(cold.n.boardStore.boardDetail.loading, true);
const dispatch = harness(); dispatch.n.syncBoardRoute(pin); dispatch.navigate(pin);
dispatch.n.controller.loadUrl = () => { throw Error('unavailable'); };
dispatch.n.backOnePage(board, board);
assert.equal(dispatch.n.nativeBoardVisible(), true);
assert.match(dispatch.snapshot.error, /无法同步/);
assert(source.includes('this.nativeBackTarget && this.pageHistory.key(address) !== this.pageHistory.key(this.nativeBackTarget)'));
console.log('Board detail return: continuous presentation, root ownership, one navigation, failure/retry, current session, empty and stale guards passed');
