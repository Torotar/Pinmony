const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const begin = source.indexOf('  private ' + name);
  assert(begin >= 0, name);
  return source.slice(begin, source.indexOf('\n  private ', begin + 1));
}
const context = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: true,
  PINTEREST_URL: 'https://www.pinterest.com/', setTimeout() {},
  PinmonyRuntimeLog: { info() {}, warn() {} } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Native {
  ${method('async openImageRelated')}
  ${method('beginDetailOpening')}
  ${method('supersedeRootPreparationForDetail')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
async function main() {
  const n = new context.Native(), loads = [], reads = [], origins = [], marks = [];
  const parent = 'https://www.pinterest.com/pin/101/';
  const target = 'https://www.pinterest.com/pin/102/';
  const card = { id: 'cached-card', pinUrl: target, imageUrl: 'https://i.pinimg.com/474x/target.jpg',
    imageWidth: 474, imageHeight: 900, title: 'Target title' };
  function restoreParent() {
    Object.assign(n.pinStore, { detailPresentationOnly: true, detailPreparing: false,
      detailOpeningPin: '', detailPin: parent, detailActionsReady: false,
      detail: { kind: 'cached', pinUrl: parent, related: [card] } });
  }
  Object.assign(n, { authStatus: 'authenticated', businessSuspended: false,
    pinStore: { videoForeground: true, detailOpeningToken: 3,
      detailPrefetch: { cancelExcept() {} }, rememberDetailOrigin: (id, url) => origins.push([id, url]),
      detailOrigin: () => parent }, homeStore: {}, detailPrefetchTimer: -1,
    pinIdentity: value => String(value || '').match(/\/pin\/(\d+)\//)?.[1] || '',
    rejectOfflineAction: () => false, closeImageLayer() {}, clearRootTabGuard() {},
    pageHistory: { visit() {} }, detailJourney: { begin() {}, mark: name => marks.push(name) },
    clearDetail() { this.pinStore.detail = undefined; this.pinStore.detailPresentationOnly = false; this.pinStore.detailActionsReady = false; },
    restoreCachedDetail() {}, startOpeningDetailRead: url => reads.push(url), probeDetailDocument() {},
    ensureDetailActionContext() { throw Error('cached navigation must not confirm parent'); },
    controller: { loadUrl(url) {
      assert.equal(n.pinStore.detail.pinUrl, target, 'target presentation exists before hidden navigation');
      assert.equal(n.pinStore.detail.imageUrl, card.imageUrl);
      assert.equal(n.pinStore.detail.imageHeight, card.imageHeight);
      assert.equal(n.pinStore.detailActionsReady, false, 'route does not authorize target writes');
      loads.push(url);
    } } });
  const {createArktsLoader}=require('./arkts-module-loader.cjs');
  const {PinmonyDetailReadCache}=createArktsLoader(ts).loadFile('feature_pin/src/main/ets/services/PinmonyDetailReadCache.ets');
  n.detailReadCache=new PinmonyDetailReadCache({ detailPin:()=>n.pinStore.detailPin, currentPin:()=>parent,
    pinIdentity:n.pinIdentity,isAuthenticated:()=>n.authStatus==='authenticated',hasNativeBackTarget:()=>false,markJourney(){} });
  require('./medium-priority-controller-harness.cjs').bindWork(n, ts, context);
  restoreParent(); await n.openImageRelated(card.id);
  assert.deepEqual(loads, [target]); assert.deepEqual(reads, [target]);
  assert.deepEqual(origins, [['102', parent]], 'back retains the native parent route');
  assert(marks.includes('related.cached.route.opened'));
  for (const blocked of ['unknown', 'invalid-url', 'wrong-parent', 'logged-out', 'background', 'preparing', 'offline']) {
    restoreParent(); n.authStatus = 'authenticated'; n.businessSuspended = false;
    n.rejectOfflineAction = () => false; card.pinUrl = target;
    if (blocked === 'invalid-url') card.pinUrl = 'https://example.com/pin/102/';
    if (blocked === 'wrong-parent') n.pinStore.detailPin = target;
    if (blocked === 'logged-out') n.authStatus = 'unauthenticated';
    if (blocked === 'background') n.businessSuspended = true;
    if (blocked === 'preparing') n.pinStore.detailPreparing = true;
    if (blocked === 'offline') n.rejectOfflineAction = () => true;
    await n.openImageRelated(blocked === 'unknown' ? 'unknown' : card.id);
    assert.equal(loads.length, 1, blocked + ' cannot start hidden navigation');
    assert.equal(reads.length, 1, blocked + ' cannot start a demand read');
  }
  console.log('Cached related navigation: immediate target card, target-only read/navigation, native parent history and session/background/offline guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
