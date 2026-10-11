const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { PIN_POST_EXTENSIONS_SCRIPT } = createArktsLoader(ts).loadFile('feature_pin/src/main/ets/services/PinmonyPostExtensionsScript.ets');
const { PinmonyConfirmedSaves } = createArktsLoader(ts).loadFile('feature_pin/src/main/ets/services/PinmonyConfirmedSaves.ets');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private async ' + name + '(');
  assert(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const code = ts.transpileModule(`class Native {
  ${['performDetailAction', 'cancelDetailSave', 'handlePostResult'].map(method).join('\n')}
} Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
const pin = 'https://www.pinterest.com/pin/101/';
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness(encoded = false) {
  let now = 1000, account = '77';
  const timers = [], requests = [], traces = [], notices = [], calls = [], writes = [], cache = [];
  const location = { href: pin };
  const api = { reset() {}, currentPin: value => value === location.href, sessionUserId: () => account,
    resourceRequest: (p, name, verb, options, valid) => new Promise((resolve, reject) => requests.push({ p, name, verb, options, valid, resolve, reject })) };
  const window = { PinmonyPostApi: api, PinmonyPostExtensionsEnabled: true };
  require('./product-coordination-harness.cjs').run(ts,PIN_POST_EXTENSIONS_SCRIPT, { window, location, console: { info() {} } });
  const Native = require('./product-coordination-harness.cjs').run(ts,code, { PIN_POST_API_ENABLED: true, PIN_POST_EXTENSIONS_ENABLED: true,
    PinmonyRuntimeLog: { info() {} }, Date: { now: () => now }, setTimeout: (fn, ms) => timers.push({ fn, ms }) });
  const native = new Native();
  const saves = new PinmonyConfirmedSaves(); saves.confirm('101', true, '802');
  Object.assign(native, { authEpoch: 1, authStatus: 'authenticated', businessSuspended: false,
    pinStore: { saveCancelToken: 0, viewerSaveBusy: false, detailSession: 2, detailActionsReady: true,
      confirmedSaves: saves, detailScrollOffset: 9, detailCache: { put: (...args) => cache.push(args) },
      detail: { pinUrl: pin, kind: 'state', actions: [{ id: 'api-save', kind: 'save', enabled: true, selected: true }],
        imageStageReady: true, commentLoading: false } },
    currentPinUrl: () => location.href, pinIdentity: p => p.match(/\/pin\/(\d+)/)?.[1] || '',
    isCurrentMorePin: p => p === location.href && native.pinStore.detail.pinUrl === p,
    rejectOfflineAction: () => false, traceAction() {}, detailJourney: { mark: event => traces.push(event) },
    webJsonText: value => { try { const parsed = JSON.parse(value); return typeof parsed === 'string' ? parsed : value; } catch { return value; } },
    showMessage: value => notices.push(value), showUndoSnack: value => notices.push(value),
    controller: { runJavaScript: async script => {
      calls.push(script);
      const result = require('./product-coordination-harness.cjs').run(ts,script, { window, JSON });
      // Model an ArkWeb bridge that does not await the Promise returned by page JavaScript.
      const text = result && typeof result.then === 'function' ? '{}' : String(result);
      return encoded ? JSON.stringify(text) : text;
    } } });
  window.PinmonyShareBridge = { postState: value => { writes.push(JSON.parse(value)); native.handlePostResult(value); } };
  async function tick() { const timer = timers.shift(); if (timer) { now += timer.ms; timer.fn(); } await flush(); }
  async function finish(pending) { await flush(); for (let i = 0; i < 8 && timers.length; i++) await tick(); await pending; }
  const click = () => native.performDetailAction('api-save', 'save');
  require('./pin-priority-controller-harness.cjs').bind(native, ts, {
    Date: { now: () => now }, setTimeout: (fn, ms) => timers.push({ fn, ms })
  });
  return { native, api, location, requests, traces, notices, calls, writes, cache, click, tick, finish,
    changeAccount: () => { account = '88'; } };
}
async function confirmedOnce(encoded) {
  const h = harness(encoded), pending = h.click(); await flush();
  assert.equal(h.requests.length, 1); assert.equal(h.requests[0].verb, 'get');
  assert.equal(h.native.pinStore.viewerSaveBusy, true);
  await h.click(); assert.equal(h.requests.length, 1, 'duplicate click does not repeat ownership read');
  h.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await flush(); await h.tick();
  assert.equal(h.requests.length, 2, 'the first click continues automatically into deletion');
  assert.equal(h.requests[1].options.id, '802'); assert.equal(h.requests[1].verb, 'delete');
  assert.equal(h.native.pinStore.viewerSaveBusy, true, 'lock remains until business confirmation');
  assert.equal(h.native.pinStore.detail.actions[0].selected, true, 'dispatch cannot update saved state');
  await h.click(); assert.equal(h.requests.length, 2, 'pending write cannot be replayed by another click');
  h.requests[1].resolve({ data: null, code: 0, endpoint_name: 'v3_delete_pin_handler' }); await h.finish(pending);
  assert.equal(h.writes.length, 1); assert.equal(h.writes[0].kind, 'saveUndone');
  assert.equal(h.native.pinStore.detail.actions[0].selected, false);
  assert.equal(h.native.pinStore.confirmedSaves.copyId('101'), '');
  assert.equal(h.cache.at(-1)[1].actions[0].selected, false);
  assert.equal(h.native.pinStore.detail.imageStageReady, true);
  assert.equal(h.native.pinStore.viewerSaveBusy, false);
  assert(h.traces.includes('save.cancel.confirmed'));
  assert(!h.calls.some(s => /\.savedRestore\(/.test(s)), 'native bridge must not compare an async Promise with true');
}
async function main() {
  await confirmedOnce(false); await confirmedOnce(true);
  const denied = harness(), deniedPending = denied.click(); await flush();
  denied.requests[0].resolve({ data: { id: '802', pinner: { id: '88' } } }); await denied.finish(deniedPending);
  assert.equal(denied.requests.length, 1); assert.equal(denied.writes.length, 0);
  assert.equal(denied.native.pinStore.detail.actions[0].selected, true);
  assert.equal(denied.native.pinStore.viewerSaveBusy, false);
  for (const change of ['pin', 'account', 'reset', 'foreground']) {
    const h = harness(), pending = h.click(); await flush();
    if (change === 'pin') { h.location.href = 'https://www.pinterest.com/pin/999/'; h.native.pinStore.detailSession++; }
    if (change === 'account') h.changeAccount();
    if (change === 'reset') h.api.reset();
    if (change === 'foreground') h.native.businessSuspended = true;
    h.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await h.finish(pending);
    assert.equal(h.requests.length, 1, change + ' must suppress delete'); assert.equal(h.writes.length, 0);
  }
  const timeout = harness(), timed = timeout.click(); await flush();
  for (let i = 0; i < 80 && timeout.native.pinStore.viewerSaveBusy; i++) await timeout.tick();
  await timed;
  assert.equal(timeout.native.pinStore.viewerSaveBusy, false, 'ownership timeout ends loading');
  timeout.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await flush();
  assert.equal(timeout.api.savedRead(pin), null, 'closed ownership read cannot restore capability late');
  assert.equal(timeout.requests.length, 1, 'timeout never starts or replays deletion');
  const failed = harness(), pending = failed.click(); await flush();
  failed.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await flush(); await failed.tick();
  failed.requests[1].resolve({ code: 0, endpoint_name: 'wrong_endpoint' }); await failed.finish(pending);
  assert.equal(failed.native.pinStore.detail.actions[0].selected, true, 'HTTP success with wrong business endpoint preserves saved state');
  assert.equal(failed.requests.length, 2); assert.equal(failed.native.pinStore.viewerSaveBusy, false);
  assert.equal(failed.notices.length, 1, 'failed deletion gives one feedback message');
  const writeTimeout = harness(), waiting = writeTimeout.click(); await flush();
  writeTimeout.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await flush(); await writeTimeout.tick();
  for (let i = 0; i < 105 && writeTimeout.native.pinStore.viewerSaveBusy; i++) await writeTimeout.tick();
  await waiting;
  assert.equal(writeTimeout.native.pinStore.viewerSaveBusy, false, 'unconfirmed deletion has a bounded loading state');
  assert.equal(writeTimeout.native.pinStore.detail.actions[0].selected, true);
  await writeTimeout.click();
  assert.equal(writeTimeout.requests.length, 2, 'an outstanding sent write stays locked and is never replayed');
  const changedOwner = harness(), ownerPending = changedOwner.click(); await flush();
  changedOwner.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await flush();
  changedOwner.changeAccount(); await changedOwner.finish(ownerPending);
  assert.equal(changedOwner.requests.length, 1, 'verified old-account copy cannot be deleted after account change');
  const address = harness(), addressPending = address.click(); await flush();
  address.location.href = pin + '?changed=true';
  address.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await address.finish(addressPending);
  assert.equal(address.requests.length, 1, 'full address change invalidates ownership result');
  const late = harness(), old = late.click(); await flush();
  late.native.pinStore.saveCancelToken++; late.native.pinStore.viewerSaveBusy = true;
  late.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await late.finish(old);
  assert.equal(late.native.pinStore.viewerSaveBusy, true, 'old finally cannot unlock a newer operation');
  const departing = harness(), departingPending = departing.click(); await flush();
  departing.requests[0].resolve({ data: { id: '802', pinner: { id: '77' } } }); await flush(); await departing.tick();
  departing.api.reset(); departing.native.pinStore.detailSession++;
  departing.requests[1].resolve({ code: 0, endpoint_name: 'v3_delete_pin_handler' }); await departing.finish(departingPending);
  assert.equal(departing.writes.length, 0, 'late sent-write result cannot update a reset document');
  console.log('Async save cancellation: single-click ownership/delete, bridge encoding, full write lock, cache update, rejection/timeout/reset/account/departure and late-finally guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
