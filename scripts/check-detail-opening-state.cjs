const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts);
const { mapPrefetchedDetail } = loader.loadPackage('feature_pin');
function methods(file, names, globals = {}) {
  const source = fs.readFileSync(file, 'utf8').replace(/\bstruct\b/g, 'class');
  const ast = ts.createSourceFile('host.ts', source, ts.ScriptTarget.Latest, true);
  const selected = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) selected.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert.equal(selected.length, names.length);
  return vm.runInNewContext(ts.transpileModule('class Host {' + selected.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, globals);
}
const Opening = methods(process.argv[3] || 'entry/src/main/ets/app/PinmonyDetailOpeningCoordinator.ets', ['startOpeningDetailRead'], {
  PIN_NATIVE_DETAIL_READS_ENABLED: true, mapPrefetchedDetail,
  PinmonyI18n: { message: key => key }
});
const Gate = methods('entry/src/main/ets/pages/Index.ets', ['canSwitchDetailSibling']);
const pin = 'https://www.pinterest.com/pin/1/';
const body = JSON.stringify({ resource_response: { status: 'success', data: {
  id: '1', type: 'pin', title: 'validated title', description: 'validated description',
  images: { orig: { url: 'https://i.pinimg.com/originals/synthetic.jpg', width: 300, height: 400 } }
} } });
const flush = async () => { for (let i = 0; i < 8; i++) await Promise.resolve(); };
function fixture(initial = true) {
  let resolve, reject, generation = 7, nativeStarts = 0;
  const response = new Promise((yes, no) => { resolve = yes; reject = no; });
  const h = new Opening(), g = new Gate(), timeouts = [];
  const session = () => ({ authenticated: true, generation });
  const store = { videoForeground: true, detailOpeningToken: 1, detailOpeningPin: pin, detailPin: pin,
    detailActionsReady: false, detailNativeReadsReady: false,
    detail: initial ? { kind: 'opening', pinUrl: pin, title: 'card', imageUrl: 'retained-preview',
      actions: [{ kind: 'save', selected: true }], related: [] } : undefined,
    confirmedSaves: { apply: (_id, detail) => detail },
    detailPrefetch: { open: () => response, get: () => undefined } };
  Object.assign(g, { pinStore: store, detailSiblings: { available: () => true, next: () => ({ pinUrl: 'next' }) },
    nativeBusinessSessionContext: session, authStatus: 'authenticated' });
  h.pinStore = store;
  h.ports = { setOpeningRelated() {}, setOpeningRelatedToken() {}, detailJourney: () => ({ mark() {} }),
    nativeBusinessSessionContext: session, authStatus: () => 'authenticated', nativeBackTarget: () => '',
    coordinatorTasks: () => ({ timeout: callback => timeouts.push(callback) }), pinIdentity: () => '1',
    startNativeReads: async () => {
      nativeStarts++;
      assert.equal(store.detail.kind, 'cached', 'publish mapped presentation kind before auxiliary reads');
      // Auxiliary/image publications clone the current snapshot, retaining its kind.
      store.detail = { ...store.detail, relatedLoading: true };
    } };
  h.startOpeningDetailRead(pin, 1);
  return { h, g, store, resolve, reject, timeouts, nativeStarts: () => nativeStarts,
    changeGeneration: () => { generation++; } };
}
(async () => {
  const f = fixture();
  assert.equal(f.g.canSwitchDetailSibling(), false, 'pending base blocks sibling gestures');
  f.resolve(body); await flush();
  assert.equal(f.store.detail.kind, 'cached', 'validated native base retires opening snapshot');
  assert.equal(f.store.detail.title, 'validated title');
  assert.equal(f.store.detail.imageUrl, 'retained-preview', 'keep mounted card image');
  assert.equal(f.store.detail.actions[0].selected, true, 'retain confirmed interactions');
  assert.equal(f.store.detailActionsReady, false, 'presentation state does not grant writes');
  assert.equal(f.store.detailNativeReadsReady, false, 'auxiliary readiness remains independent');
  assert.equal(f.nativeStarts(), 1);
  assert.equal(f.g.canSwitchDetailSibling(), true, 'subsequent swipe enabled after real base completion');
  const standalone = fixture(false); standalone.resolve(body); await flush();
  assert.equal(standalone.store.detail.kind, 'cached', 'no opening card publishes validated mapped state');
  for (const mutate of [f => f.changeGeneration(), f => f.store.detailOpeningToken++,
    f => { f.store.detailOpeningPin = 'other'; f.store.detailPin = 'other'; },
    f => { f.store.videoForeground = false; }]) {
    const stale = fixture(); mutate(stale); stale.resolve(body); await flush();
    assert.equal(stale.store.detail.kind, 'opening', 'late response cannot publish into new owner');
    assert.equal(stale.nativeStarts(), 0);
  }
  const failed = fixture(); failed.reject(Error('network-unavailable')); await flush();
  assert.ok(failed.store.detailApiError, 'real failure and retry state retained');
  assert.equal(failed.store.detail.kind, 'opening', 'failure does not pretend base succeeded');
  assert.equal(failed.g.canSwitchDetailSibling(), true, 'failed target can be left for adjacent card');
  failed.store.detailApiError = '';
  assert.equal(failed.g.canSwitchDetailSibling(), false, 'retry restores pending guard');
  const timeout = fixture(); timeout.timeouts[0]();
  assert.ok(timeout.store.detailApiError);
  assert.equal(timeout.g.canSwitchDetailSibling(), true, 'timed-out target does not trap gestures');
  const cancelled = fixture(); const abort = Error('cancelled'); abort.name = 'AbortError';
  cancelled.reject(abort); await flush();
  assert.equal(cancelled.store.detailApiError, undefined, 'cancellation is not a real failure');
  assert.equal(cancelled.g.canSwitchDetailSibling(), false, 'cancelled pending document remains guarded');
  console.log('Detail opening state: native completion, retained image/actions, swipe gate, failure/retry/timeout, stale owner and cancellation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
