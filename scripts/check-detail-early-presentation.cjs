const assert = require('node:assert/strict');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const ts = require(process.argv[2] || 'typescript');
const pin = 'https://www.pinterest.com/pin/1/';
const payload = (data = [{ type: 'pin', id: '2', title: 'Synthetic', images: {
  '474x': { url: 'https://example.invalid/image.jpg', width: 474, height: 600 }
} }]) => ({ status: 200, error: '', body: JSON.stringify({ resource_response: {
  status: 'success', code: 0, data, bookmark: 'synthetic-next'
} }) });
const flush = async () => { await Promise.resolve(); await Promise.resolve(); };
function fixture() {
  let timerId = 0, resolveReply, foreground = true, rootOnly = false, backTarget = '';
  const timers = new Map(), requests = [], cancelled = [], marks = [], caches = [];
  const session = { authenticated: true, accountId: 'synthetic', origin: 'https://www.pinterest.com', generation: 1 };
  const store = { detailOpeningToken: 1, detailOpeningPin: pin, detailPin: pin, detailNativeReadsReady: false,
    detailActionsReady: false, detailScrollOffset: 0, detailCache: { put: (...args) => caches.push(args) },
    detail: { kind: 'opening', dataSource: 'api', pinUrl: pin, imageUrl: 'https://example.invalid/hero.jpg',
      title: 'Opening', actions: [], related: [] } };
  const deps = { common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } },
    common_network: { PIN_BUSINESS_PIN_READ_ENABLED: true, Priority: { HIGH: 0 } }, feature_pin: {} };
  const loader = createArktsLoader(ts, deps, {
    Date: class extends Date { static now() { return 1000; } },
    setTimeout(callback, delay) { const id = ++timerId; timers.set(id, { callback, delay }); return id; },
    clearTimeout(id) { timers.delete(id); }
  });
  deps.feature_pin.readRelatedPresentation = loader.loadFile('feature_pin/src/main/ets/services/PinmonyRelatedPresentation.ets').readRelatedPresentation;
  const { PinmonyDetailNativeReads: Reads } = loader.loadFile('entry/src/main/ets/app/PinmonyDetailNativeReads.ets');
  const reads = new Reads({ pinStore: () => store, session: () => session, foreground: () => foreground,
    rootOnly: () => rootOnly, backTarget: () => backTarget, openedAt: () => 1000,
    mark: event => marks.push(event), network: () => ({ cancel: id => cancelled.push(id),
      requestBusinessPinRead(job, _session, target, current) {
        assert(current()); assert.equal(target, pin); requests.push(job);
        return new Promise(resolve => { resolveReply = resolve; });
      } }) });
  async function dispatch() {
    reads.warmRelated(pin, 1);
    const early = reads.earlyRelated;
    assert.equal(requests.length, 0, 'hero entry budget remains protected');
    const [id, timer] = [...timers][0]; assert.equal(timer.delay, 280);
    timers.delete(id); timer.callback(); await flush(); assert.equal(requests.length, 1);
    return early;
  }
  return { reads, store, session, marks, requests, cancelled, caches, timers, dispatch,
    resolve: value => resolveReply(value), setForeground: value => { foreground = value; },
    setRoot: value => { rootOnly = value; }, setBack: value => { backTarget = value; } };
}
async function main() {
  const f = fixture(), early = await f.dispatch();
  f.resolve(payload()); await early.reply;
  assert.equal(f.store.detail.related.length, 1, 'slow base does not block valid recommendation presentation');
  assert.equal(f.store.detail.relatedPreview, true); assert.equal(f.store.detail.relatedRetained, true);
  assert.equal(f.store.detailNativeReadsReady, false); assert.equal(f.store.detailActionsReady, false);
  assert.equal(f.store.detail.actions.length, 0); assert.equal(f.caches.length, 0, 'preview grants no persistent/native cache ownership');
  assert(f.marks.includes('related.native.preview.presented'));
  assert(!f.marks.includes('related.native.committed'));
  const sourceLoader = createArktsLoader(ts, { common_foundation: {}, feature_pin: {} });
  const { PinmonyConfirmedSaves } = sourceLoader.loadFile('feature_pin/src/main/ets/services/PinmonyConfirmedSaves.ets');
  assert.equal(new PinmonyConfirmedSaves().apply('1', f.store.detail).relatedPreview, true, 'save overlays preserve preview identity');
  const { retainDetailPresentation, PinmonyDetailCache } = sourceLoader.loadFile('feature_pin/src/main/ets/services/PinmonyDetailCache.ets');
  const retained = retainDetailPresentation({ pinUrl: pin, actions: [], related: [] }, f.store.detail);
  assert.equal(retained.relatedPreview, true, 'same-opening response merging preserves the read-only preview marker');
  const cache = new PinmonyDetailCache(); cache.put('1', f.store.detail, 0);
  assert.equal(cache.get('1').detail.relatedPreview, undefined, 'later cached visits are not counted as a new network preview');

  // Drive the real base adoption and readRelated implementation with the same promise.
  f.reads.readAutoplay = () => Promise.resolve(); f.reads.readPreview = () => Promise.resolve();
  f.reads.readProduct = () => Promise.resolve(); f.reads.waitForEntryBudget = () => Promise.resolve();
  await f.reads.start(pin, 1, JSON.stringify({ resource_response: { status: 'success', data: { id: '1' } } }));
  assert.equal(f.requests.length, 1, 'base adoption never repeats the recommendation request');
  assert.equal(f.store.detail.relatedPreview, false); assert.equal(f.store.detail.relatedRetained, false);
  assert.equal(f.store.detailNativeReadsReady, true); assert.equal(f.reads.bookmark, 'synthetic-next');
  assert.equal(f.store.detail.related.length, 1); assert.equal(f.reads.earlyRelated, undefined);

  const baseFirst = fixture(), pending = await baseFirst.dispatch();
  baseFirst.reads.readAutoplay = () => Promise.resolve(); baseFirst.reads.readPreview = () => Promise.resolve();
  baseFirst.reads.readProduct = () => Promise.resolve(); baseFirst.reads.waitForEntryBudget = () => Promise.resolve();
  const complete = baseFirst.reads.start(pin, 1, JSON.stringify({ resource_response: { status: 'success', data: { id: '1' } } }));
  await flush(); baseFirst.resolve(payload()); await complete; await pending.reply;
  assert(!baseFirst.marks.includes('related.native.preview.presented'), 'ready native state is never downgraded to preview');
  assert.equal(baseFirst.store.detail.relatedPreview, false); assert.equal(baseFirst.requests.length, 1);

  for (const invalidate of [f => f.session.authenticated = false, f => f.session.accountId = 'other-synthetic',
    f => f.session.generation++, f => f.session.origin = 'https://uk.pinterest.com',
    f => f.store.detailOpeningToken++, f => { f.store.detailOpeningPin = ''; f.store.detailPin = ''; },
    f => f.store.detail.pinUrl = 'https://www.pinterest.com/pin/3/', f => f.setForeground(false),
    f => f.setRoot(true), f => f.setBack('root'), f => f.reads.pause(),
    f => f.reads.cancelEarlyRelated(pin, 1)]) {
    const f = fixture(), early = await f.dispatch(); invalidate(f); f.resolve(payload()); await early.reply;
    assert.equal(f.store.detail.related.length, 0, 'stale, cancelled or different-session response cannot publish');
    assert(!f.marks.includes('related.native.preview.presented')); assert.equal(f.caches.length, 0);
  }
  for (const reply of [{ ...payload(), status: 500 }, { ...payload(), error: 'network-unavailable' },
    { ...payload(), body: '{' }, { ...payload(), body: JSON.stringify({ resource_response: {
      status: 'failure', data: [] } }) }, payload([{ type: 'pin', id: 'invalid', images: {} }])]) {
    const f = fixture(), early = await f.dispatch(); f.resolve(reply); await early.reply;
    assert.equal(f.store.detail.related.length, 0); assert(!f.marks.includes('related.native.preview.presented'));
    assert.equal(f.requests.length, 1, 'invalid responses do not create retry loops');
  }
  const empty = fixture(), emptyEarly = await empty.dispatch(); empty.resolve(payload([])); await emptyEarly.reply;
  assert.equal(empty.store.detail.relatedEnded, true); assert.equal(empty.store.detail.relatedLoading, false);
  assert.equal(empty.store.detail.relatedPreview, true, 'validated empty is separate from pending/failure');
  const beforeBudget = fixture(); beforeBudget.reads.warmRelated(pin, 1); beforeBudget.reads.pause(); await flush();
  assert.equal(beforeBudget.timers.size, 0); assert.equal(beforeBudget.requests.length, 0);
  console.log('Early recommendation presentation: slow/fast base adoption, one request, read-only readiness, empty/error and session/cancel guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
