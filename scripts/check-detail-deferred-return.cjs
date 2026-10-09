const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = index.indexOf('  private ' + name);
  assert(start >= 0, name);
  return index.slice(start, index.indexOf('\n  private ', start + 1));
}
const pin = 'https://www.pinterest.com/pin/101/';
function compile(file, deps = () => ({}), globals = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: deps, ...globals });
  return exports;
}
const host = { PINTEREST_URL: 'https://www.pinterest.com/', PIN_POST_API_ENABLED: true,
  PIN_POST_EXTENSIONS_ENABLED: true, PinWebRuntimeLog: { info() {}, warn() {} },
  setTimeout, isPinterestAuthRoute: () => false };
vm.runInNewContext(ts.transpileModule(`class Native {
  ${method('backOnePage')}
  ${method('loadReturnTarget')}
  ${method('async ensureDetailActionContext')}
  ${method('async performDetailAction')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, host);
async function main() {
  const native = new host.Native(), calls = [], marks = [];
  const cached = { kind: 'cached', pinUrl: pin, actions: [{ id: 'cached-old', kind: 'like', enabled: false }] };
  Object.assign(native, { authStatus: 'authenticated', pinStore: { detail: cached, detailPin: pin,
    detailOpeningToken: 1, detailActionsReady: false, videoForeground: true, detailPrefetch: { pause() {} } },
    pageHistory: { isPending: () => false, prepareBackTo: value => value, visit() {}, cancelBack() {} },
    nativeNetwork: { invalidate() {} }, pageBackToken: 0,
    detailReturnJourney: { mark: value => marks.push(value) }, detailJourney: { mark: value => marks.push(value) },
    pinIdentity: value => String(value || '').match(/\/pin\/(\d+)/)?.[1] || '',
    restoreRetainedSearch() {}, searchUrlFromAddress: () => '',
    presentNativeBackTarget(target) { this.nativeBackTarget = target; this.pinStore.detail = cached; },
    controller: { runJavaScript: async value => { calls.push(value); return 'true'; },
      loadUrl: value => { throw Error('cached return attempted navigation: ' + value); } },
    traceAction() {}, rejectOfflineAction: () => false, showMessage() {} });
  assert.equal(native.backOnePage('', pin), true);
  assert.equal(native.pinStore.detailPresentationOnly, true);
  assert.equal(native.pinStore.detailActionsReady, false);
  assert.equal(native.nativeBackTarget, '');
  assert(marks.includes('return.cache.presentation.only'));
  assert(calls.every(value => value.includes('PinWebDetailPause')), 'return only pauses the departed document');

  native.beginDetailOpening = value => {
    native.pinStore.detailPresentationOnly = false; native.pinStore.detailOpeningToken++;
    native.pinStore.detailPin = value; native.pinStore.detailApiError = '';
  };
  native.currentPinUrl = () => pin;
  const fresh = { kind: 'state', pinUrl: pin, session: 7, imageStageReady: true,
    actions: [{ id: 'fresh-like', kind: 'like', enabled: true }] };
  native.controller.loadUrl = () => { native.pinStore.detail = fresh; native.pinStore.detailActionsReady = true; };
  calls.length = 0;
  await native.performDetailAction('cached-old', 'like');
  assert.equal(calls.length, 1);
  assert(calls[0].includes('"fresh-like"') && !calls[0].includes('cached-old'), 'action uses only the newly confirmed control ID');
  assert.equal(native.pinStore.detailPreparing, false);
  native.pinStore.detailPresentationOnly = true;
  native.pinStore.detailActionsReady = false;
  fresh.actions[0].enabled = false; calls.length = 0;
  await native.performDetailAction('cached-old', 'like');
  assert.equal(calls.length, 0, 'current disabled operation is never dispatched');
  native.pinStore.detailPresentationOnly = true;
  native.controller.loadUrl = () => { native.authStatus = 'unauthenticated'; };
  assert.equal(await native.ensureDetailActionContext(), false);
  assert.equal(calls.length, 0, 'account loss cancels the pending user intent');
  native.authStatus = 'authenticated';
  native.pinStore.detailPresentationOnly = true;
  native.rejectOfflineAction = () => true;
  native.controller.loadUrl = () => { throw Error('offline intention started navigation'); };
  assert.equal(await native.ensureDetailActionContext(), false, 'offline intentions do not prepare network context');
  assert.equal(native.pinStore.detailPresentationOnly, true);
  native.rejectOfflineAction = () => false;
  native.pageBackToken = 5; native.returnLoadToken = -1;
  let loads = 0; native.controller.loadUrl = () => loads++;
  native.loadReturnTarget(pin, 4); native.loadReturnTarget(pin, 5); native.loadReturnTarget(pin, 5);
  assert.equal(loads, 1, 'fallback cannot load the same return target twice or revive an old return');
  const home = 'https://www.pinterest.com/';
  native.webPageLoading = true;
  native.isHomeRootAddress = value => value === home;
  native.returnToHistoryEntry = () => { throw Error('native root return must not start competing Web history'); };
  native.presentNativeBackTarget = target => { native.nativeBackTarget = target; native.pinStore.detail = undefined; };
  native.pinStore.detailPin = pin;
  native.backOnePage(home, home);
  assert.equal(loads, 2, 'root return loads exactly one explicit native destination');
  assert(marks.includes('return.native.route.direct'));

  const { readRelatedPresentation } = compile('feature_pin/src/main/ets/services/PinWebRelatedPresentation.ets');
  const body = JSON.stringify({ resource_response: { status: 'success', data: [
    { type: 'pin', id: '102', title: 'A', images: { '474x': { url: 'https://i.pinimg.com/2.jpg', width: 474, height: 900 } } },
    { type: 'advertisement', id: '103', images: {} }
  ], bookmark: 'next' } });
  const related = readRelatedPresentation(body, pin);
  assert.equal(related.pins.length, 1); assert.equal(related.pins[0].imageHeight, 900);
  assert.equal(related.ended, false);
  assert.equal(readRelatedPresentation('{"resource_response":{"status":"failure","data":[]}}', pin), undefined);
  assert.equal(readRelatedPresentation(body, 'https://example.com/pin/101/'), undefined);
  const { PinWebDetailCache } = compile('feature_pin/src/main/ets/services/PinWebDetailCache.ets', undefined, { Date });
  const cache = new PinWebDetailCache();
  cache.put('101', { ...fresh, title: 'A', related: [], description: '', creator: '', creatorAvatar: '', sourceLabel: '' }, 42);
  const entry = cache.get('101');
  assert(entry.expiresAt - Date.now() > 290000);
  entry.expiresAt = Date.now() - 1;
  assert.equal(cache.get('101'), undefined, 'expired presentation is never restored');
  console.log('Deferred return: no automatic reads/navigation, current control IDs, disabled/account guards, one fallback load, native related parsing and bounded presentation cache passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
