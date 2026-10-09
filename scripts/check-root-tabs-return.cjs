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
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const names = ['nativeDisplayAddress', 'nativeRootPageAddress', 'syncNativeReturnRoute', 'nativeRootTabsVisible', 'profileUrlFromAddress', 'boardUrlFromAddress', 'isHomeRootAddress', 'backFromDetail', 'protectedDetailAddress', 'ignoreSupersededDetailDocument'];
const code = ts.transpileModule('class Native {' + names.map(method).join('\n') + '} globalThis.Native=Native;',
  { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const context = { PIN_BOARD_API_ENABLED: true, PinWebRuntimeLog: { info() {}, warn() {}, error() {} } }; vm.runInNewContext(code, context);
const root = 'https://www.pinterest.com/sample/_created/', pin = 'https://www.pinterest.com/pin/123/',
  board = 'https://www.pinterest.com/sample/board/';
function harness() {
  const native = new context.Native(); let url = root, cleared = 0;
  Object.assign(native, { profileStore: { panel: undefined }, nativePinRoute: '', pendingBoardUrl: '', profileWebFlow: false, profileFlowLeftPage: false,
    inboxWebFlow: false, loadFailed: false, activeSheetKind: '', detailWebFlow: false, activeTab: 3, pendingWebTab: -1,
    rootTabAddresses: new Map(), searchUrlFromAddress: value => value.includes('/search/') ? value : '',
    controller: { getUrl: () => url }, pageHistory: { key: value => value.split('#')[0] }, tabsController: { changeIndex() {} },
    extractPinUrl: value => /\/pin\/\d+\//.test(value) ? value.split('?')[0] : '',
    pinIdentity: value => (value.match(/\/pin\/(\d+)/) || [])[1] || '',
    inboxUrlFromAddress: value => /\/inbox\//.test(value) ? value : '', currentPinUrl() { return this.extractPinUrl(url); },
    clearDetail() { cleared++; this.detail = undefined; this.detailOpeningPin = ''; this.detailWebFlow = false; } });
  native.profileStore.origins = [];
  for (const store of ['pinStore', 'boardStore', 'inboxStore', 'searchStore']) native[store] = native[store] || {};
  return { native, cleared: () => cleared, visit(value) { url = value; native.syncNativeReturnRoute(value); } };
}
const h = harness(); h.visit(root);
h.native.profileWebFlow = true; h.native.detailOpeningPin = pin;
h.native.syncNativeReturnRoute(root);
assert.equal(h.cleared(), 0, 'an unchanged source callback does not cancel a newly opening Pin');
h.visit(pin); h.native.detail = { pinUrl: pin }; h.native.detailWebFlow = true;
assert.equal(h.native.nativeRootTabsVisible(), false);
h.visit(root);
assert.equal(h.native.detail, undefined); assert.equal(h.native.detailWebFlow, false);
assert.equal(h.native.profileWebFlow, false, 'profile return clears flow before profile API becomes ready');
assert.equal(h.native.nativeRootTabsVisible(), true, 'SPA return restores the four tabs without a page-begin event');
assert.equal(h.native.activeTab, 3);
h.native.syncNativeReturnRoute(pin);
assert.equal(h.native.nativeRootTabsVisible(), true, 'late previous-Pin route cannot hide the tabs');
const b = harness(); b.native.profileWebFlow = true; b.visit(board);
b.visit(pin); b.native.detail = { pinUrl: pin }; b.visit(board);
assert.equal(b.native.detail, undefined); assert.equal(b.native.nativeRootTabsVisible(), false, 'board is a child page');
b.visit(root); assert.equal(b.native.nativeRootTabsVisible(), true, 'return from board restores profile tabs');
const allPins = 'https://www.pinterest.com/sample/pins/';
const all = harness(); all.visit(allPins);
assert.equal(all.native.boardUrlFromAddress(allPins), allPins, 'all-pins uses the native collection screen');
all.visit(pin); all.native.detail = { pinUrl: pin }; all.visit(allPins);
assert.equal(all.native.detail, undefined);
assert.equal(all.native.nativeRootTabsVisible(), false, 'return to all-pins stays in the collection child screen');
all.visit(root); assert.equal(all.native.nativeRootTabsVisible(), true);
for (const url of ['https://www.pinterest.com/', 'https://www.pinterest.com/search/', 'https://www.pinterest.com/inbox/']) {
  const r = harness(); r.visit(pin); r.native.detail = { pinUrl: pin }; r.visit(url);
  assert.equal(r.native.nativeRootTabsVisible(), true);
}
const sheet = harness(); sheet.visit(root); sheet.native.activeSheetKind = 'share';
assert.equal(sheet.native.nativeRootTabsVisible(), false, 'an active sheet still hides the tabs');
console.log('Root tabs after Pin and board return checks passed');
async function checkReturnOrigin() {
  const historySource = readSourceFileSync('entry/src/main/ets/services/PinWebNavigationHistory.ets', 'utf8');
  const historyCode = ts.transpileModule(historySource.replace('export class', 'class') +
    '\nglobalThis.History = PinWebNavigationHistory;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  vm.runInNewContext(historyCode, context);
  for (const origin of ['https://www.pinterest.com/', root, 'https://www.pinterest.com/sample/', board, allPins, 'https://www.pinterest.com/search/?q=art']) {
    const history = new context.History();
    history.visit(pin); // Reproduce a missed SPA profile entry: preceding entry is home.
    const native = new context.Native(); let target = '';
    Object.assign(native, { pinStore: { detailOrigin: () => '', leaveDetailOrigin() {} }, detailJourney: { current: () => '' },
      pinIdentity: value => (value || '').match(/\/pin\/(\d+)/)?.[1] || '', extractPinUrl: value => /\/pin\//.test(value) ? value : '',
      searchStore: {}, detailReturnUrl: origin, pageHistory: history, inboxUrlFromAddress: () => '', searchUrlFromAddress: url => url.includes('/search/?q=') ? url : '',
      backOnePage(fallback, override) { target = override ? history.prepareBackTo(override) : history.prepareBack(fallback); } });
    await native.backFromDetail();
    assert.equal(target, origin, 'Recorded origin overrides stale homepage history and preserves profile section');
  }
  assert.match(method('performProfileAction'), /profile\.section === 'created' \? profile\.profileUrl \+ '_created\/'/);
  console.log('Pin return origin and created section checks passed');
}
checkReturnOrigin().catch(error => { console.error(error); process.exitCode = 1; });
