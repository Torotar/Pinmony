const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const context = { Date, setTimeout, PinmonyRuntimeLog: { info() {}, warn() {} } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native {' +
  ['rootReadInFlight', 'ensureRootActionContext', 'restorePublishBoard', 'boardOperation', 'clearProfile', 'nativeBoardVisible'].map(method).join('\n') +
  '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
(async () => {
  const n = new context.Native();
  const root = 'https://www.pinterest.com/sample/', board = root + 'board/';
  let document = board, ready = false, reads = 0, loads = [];
  Object.assign(n, { authStatus: 'authenticated', activeTab: 3, activeSheetKind: 'publish', pinStore: {},
    rootReadToken: 6, tabRequestToken: 7, rootReadAddress: root, rootReadStartedAt: Date.now(),
    pendingWebTab: 3, webPageLoading: false, pageHistory: { key: value => value }, controller: { getUrl: () => document },
    rootActionContextReady: () => ready, clearRootTabGuard() {},
    requestRootPage() { reads++; document = root; ready = true; },
    boardStore: { boardDetail: { pageKey: board, session: 1, pins: [{ id: '1', pinUrl: 'pin1' }] } },
    cancelledBoardPins: new Set(['pin1']), currentBoardUrl: () => board,
    publishBoardReturn: board, pageBackToken: 0, loadReturnTarget: target => loads.push(target) });
  assert.equal(n.rootReadInFlight(3, root), false, 'stale profile read cannot be joined from board');
  document = root; n.rootReadToken = 7;
  assert.equal(n.rootReadInFlight(3, root), true, 'same-document pending read can be joined');
  document = board; n.rootReadToken = 6;
  assert.equal(await n.ensureRootActionContext(3, true, 'publish'), true);
  assert.equal(reads, 1, 'pending tab marker must not skip context preparation');
  n.boardOperation('open', '1'); // no controller dispatch method: cancelled card must return first
  const dispatches = [];
  n.controller.runJavaScript = async code => { dispatches.push(code); return 'true'; };
  n.singlePinMovePage = board;
  n.boardOperation('flow', JSON.stringify({ action: 'select' }));
  assert(dispatches[0].includes('close'), 'single Pin menu returns to board');
  assert.equal(n.singlePinMovePage, '');
  await new Promise(setImmediate);
  n.boardOperation('flow', JSON.stringify({ action: 'select' }));
  assert(dispatches[1].includes('select'), 'organize flow retains selection return');
  n.restorePublishBoard(); n.restorePublishBoard();
  assert.deepEqual(loads, [board], 'publish returns to original board exactly once');
  const preparing = new context.Native();
  Object.assign(preparing, {
    activeSheetKind: 'publish', showNativeSheet: true, nativeRootOnly: true,
    publishBoardReturn: board, loadFailed: false,
    boardStore: { boardDetail: { pageKey: board }, presentationPage: board },
    boardUrlFromAddress: () => '', nativeDisplayAddress: () => root,
    profileReadController: { pause() {} }, profileActionsController: { reset() {} },
    closePublishFlow() {}, finishProfilePull() {},
    profileStore: { publishPreparing: true, publishLoading: true, profileRequestToken: 0 }
  });
  assert.equal(preparing.nativeBoardVisible(), true, 'background profile preparation cannot hide retained board');
  preparing.clearProfile();
  assert.equal(preparing.showNativeSheet, true, 'profile reset preserves preparing menu');
  assert.equal(preparing.activeSheetKind, 'publish');
  assert.equal(preparing.profileStore.publishLoading, true);
  preparing.profileStore.publishPreparing = false;
  preparing.clearProfile();
  assert.equal(preparing.showNativeSheet, false, 'ordinary profile reset still clears old menu');
  console.log('Board publish context: stale read, pending tab, cancelled navigation and board restoration passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
