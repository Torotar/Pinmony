const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const flush = () => new Promise(resolve => setImmediate(resolve));
const url = id => `https://www.pinterest.com/pin/${id}/`;
const pin = id => ({ id: String(id), type: 'pin', title: 'Verified title', aggregated_pin_id: '303',
  reaction_by_me: 0, reaction_counts: { '1': 0 },
  images: { '736x': { url: 'https://i.pinimg.com/example.jpg', width: 736, height: 1000 } } });
const response = id => JSON.stringify({ client_context: { ignored: 'not retained' },
  resource_response: { status: 'success', data: { ...pin(id), ignored_auth_field: 'not retained' } } });
const log = { info() {}, warn() {} };
function compile(path, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: deps, console, setTimeout, clearTimeout });
  return exports;
}
const { PinmonyDetailPrefetch } = compile('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets',
  () => ({ PinmonyRuntimeLog: log }));
const requests = [], cookies = [];
let reply, finish;
const rcp = { Request: class { constructor(url, method, headers) { Object.assign(this, { url, method, headers }); } },
  createSession: () => ({ fetch: async request => { requests.push(request); return await reply; }, cancel() {}, close() {} }) };
class Credentials { async read() { return 'synthetic'; } async update(_url, value, current) {
  assert(current()); cookies.push(value);
} }
const { PinmonyNativeNetwork, acceptsNetworkJob } = compile('common_network/src/main/ets/PinmonyNativeNetwork.ets', name =>
  name === 'common_session' ? { PinmonySessionCredentials: Credentials } : name === 'common_foundation' ?
    { PinmonyRuntimeLog: log } : { rcp });
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) { const begin = index.indexOf(`  private ${name}`); const end = index.indexOf('\n  private ', begin + 1); return index.slice(begin, end); }
const context = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: true,
  PINTEREST_URL: 'https://www.pinterest.com/', acceptsNetworkJob,
  PinmonyRuntimeLog: log, readRelatedPresentation: () => undefined, setTimeout() {}, clearTimeout() {} };
vm.runInNewContext(ts.transpileModule(`class Native {
  ${method('beginDetailOpening')}
  ${method('supersedeRootPreparationForDetail')}
  ${method('startOpeningDetailRead')}
  ${method('retryDetailApi')}
  ${method('cancelNativeNetwork')}
  ${method('detailReturnReadKey')}
  ${method('retainedDetailRead')}
  ${method('async detailNetworkReply', 'showNetworkNotice')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
async function main() {
  const cache = new PinmonyDetailPrefetch(), network = new PinmonyNativeNetwork();
  const state = { authenticated: true, epoch: 1, page: 'https://www.pinterest.com/', userAgent: 'synthetic' };
  const source = { ...state };
  let homeCurrent = true;
  const read = (target, id, current) => {
    const job = { id, epoch: state.epoch, page: state.page, url: target, method: 'GET', body: '', headers: {} };
    const options = JSON.parse(new URL(target).searchParams.get('data')).options;
    return network.requestPinRead(job, () => state, url(options.id), current).then(result => {
      if (result.error) throw Error(result.error); return result.body;
    });
  };
  reply = new Promise(resolve => { finish = resolve; });
  cache.offer([url(1)], 'home:1', read, () => homeCurrent, id => network.cancel(id));
  await flush(); assert.equal(requests.length, 1);
  const native = new context.Native();
  Object.assign(native, { authStatus: 'authenticated', nativeBackTarget: '', detailPrefetchTimer: -1,
    detailJourney: { begin() {}, mark() {}, current() { return 1; } },
    detailRequestOwners: new Map(), detailReturnReads: new Map(), detailReturnReadPin: '',
    pinStore: { detailPrefetch: cache, detailOpeningToken: 0, videoForeground: true, detailOpeningPin: '',
      rememberDetailOrigin() {}, detailOrigin: () => 'https://www.pinterest.com/',
      confirmedSaves: { apply: (_id, data) => data } }, homeStore: { home: { pins: [{ ...pin(1), pinUrl: url(1),
        imageUrl: pin(1).images['736x'].url, imageWidth: 736, imageHeight: 1000 }] } },
    pinIdentity: value => String(value || '').match(/\/pin\/(\d+)\//)?.[1] || '',
    closeImageLayer() {}, clearRootTabGuard() {}, pageHistory: { visit() {}, cancelBack() {} },
    clearDetail() { this.pinStore.detail = undefined; this.pinStore.detailActionsReady = false; this.pinStore.detailOpeningToken++; },
    restoreCachedDetail() {}, probeDetailDocument() {}, detailReadNetwork: network,
    detailReadCache: { retained() { return undefined; }, store() {}, clear() {}, reset() {} },
    detailImageStage: { reset() {} },
    nativeNetwork: { request() { throw Error('duplicate or unvalidated request reached regular network'); } },
    nativeNetworkContext: () => ({ ...state }), currentPinUrl: () => state.page });
  native.beginDetailOpening(url(1)); homeCurrent = false;
  assert.equal(native.pinStore.detail.kind, 'opening', 'clicked card is visible before network/document readiness');
  assert.equal(native.pinStore.detailActionsReady, false);
  state.page = url(1); state.epoch++;
  const job = { id: 'bridge_1', epoch: state.epoch, page: state.page, url: requests[0].url,
    method: 'GET', body: '', headers: {} };
  const delivered = native.detailNetworkReply(job);
  finish({ statusCode: 200, headers: { 'set-cookie': 'synthetic-new; Secure' }, toString: () => response(1) });
  const result = await delivered; await flush();
  assert.equal(result.status, 200); assert.equal(requests.filter(request => request.url.includes('/PinResource/')).length, 1, 'opening and bridge share the in-flight Pin read');
  assert.equal(requests.filter(request => request.url.includes('/RelatedModulesResource/')).length, 1, 'verified base starts one early related read');
  assert.equal(native.pinStore.detail.title, 'Verified title');
  assert.equal(native.pinStore.detailActionsReady, false, 'display does not grant live actions');
  assert.equal(JSON.parse(result.body).client_context, undefined);
  assert.equal(JSON.parse(result.body).resource_response.data.reaction_counts['1'], 0,
    'the shared base reply preserves authoritative zero reactions without waiting for website GraphQL');
  assert.equal(JSON.parse(result.body).resource_response.data.ignored_auth_field, undefined);
  assert.equal(cookies.length, 2, 'valid source-to-target ownership also guards Cookie synchronization');
  const relatedCount = requests.length;
  const relatedReply = await native.detailNetworkReply({ ...job, id: 'bridge_related', url: requests.find(request => request.url.includes('/RelatedModulesResource/')).url });
  assert.equal(relatedReply.status, 200);
  assert.equal(relatedReply.id, 'bridge_related');
  assert.equal(requests.length, relatedCount, 'bridge consumes the early related reply without a duplicate request');
  assert.equal(native.openingRelated, undefined, 'related handoff is single-use');
  assert.equal(cache.consume(url(1)), undefined, 'only one current document may consume a demand reply');

  native.pinStore.detailPin = url(1);
  const cachedJob = { ...job, id: 'return_comments', url: 'https://www.pinterest.com/resource/UnifiedCommentsPreviewResource/get/?data=synthetic' };
  const cachedReply = { ...cachedJob, status: 200, body: response(1), headers: {}, error: '' };
  native.detailReadCache = { retained: current => current.method === 'GET' && current.url === cachedJob.url ? cachedReply : undefined, store() {}, clear() {}, reset() {} };
  const cachedRead = native.detailReadCache.retained(cachedJob);
  assert.equal(cachedRead.id, cachedJob.id);
  assert.equal(Object.keys(cachedRead.headers).length, 0, 'cache never replays response headers or cookies');
  assert.equal(native.detailReadCache.retained({ ...cachedJob, method: 'POST' }), undefined);
  // Returning/cancelling is irrevocable even if the SDK delivers an HTTP 200 later.
  cache.pause(); network.invalidate();
  reply = new Promise(resolve => { finish = resolve; });
  const before = requests.length;
  const pending = cache.open(url(2), read, () => true, id => network.cancel(id));
  const settled = pending.catch(() => 'cancelled');
  await flush(); cache.pause(); network.invalidate();
  finish({ statusCode: 200, headers: { 'set-cookie': 'late' }, toString: () => response(2) });
  assert.equal(await settled, 'cancelled'); assert.equal(cache.get(url(2)), undefined);
  assert.equal(cookies.length, 2); assert.equal(requests.length, before + 1);

  // The exception is bounded: another target and writes never qualify.
  const captured = { ...state };
  reply = new Promise(resolve => { finish = resolve; });
  const target = 'https://www.pinterest.com/resource/PinResource/get/?data=' +
    encodeURIComponent(JSON.stringify({ options: { id: '3', field_set_key: 'auth_web_main_pin' } }));
  const readJob = { ...job, id: 'isolated_3', epoch: captured.epoch, page: captured.page, url: target };
  const moving = network.requestPinRead(readJob, () => state, url(3), () => true);
  await flush(); state.page = url(4); state.epoch++;
  finish({ statusCode: 200, headers: { 'set-cookie': 'wrong-pin' }, toString: () => response(3) });
  assert.equal((await moving).error, 'cancelled'); assert.equal(cookies.length, 2);
  const count = requests.length;
  const denied = await network.requestPinRead({ ...readJob, epoch: state.epoch, page: state.page,
    id: 'write_denied', method: 'POST' }, () => state, url(3), () => true);
  assert(denied.error); assert.equal(requests.length, count);
  // An old document abort during explicit retry must not cancel its replacement.
  cache.pause(); network.invalidate(); state.page = url(3);
  native.pinStore.detailPin = url(3); native.pinStore.detailOpeningPin = url(3);
  native.pinStore.detailActionsReady = false; native.pinStore.detailSession = 1; native.sharedDetailRequestId = 'old_bridge';
  native.nativeNetwork.cancel = () => {};
  native.controller = { runJavaScript: async () => { native.cancelNativeNetwork('old_bridge'); return 'true'; } };
  reply = new Promise(resolve => { finish = resolve; });
  native.retryDetailApi(); await flush();
  finish({ statusCode: 200, headers: {}, toString: () => response(3) }); await flush();
  assert.equal(native.pinStore.detail.title, 'Verified title', 'replacement survives the old bridge abort');
  assert(cache.get(url(3))); cache.pause(); network.invalidate();
  console.log('Detail opening: immediate card, in-flight transfer, one bridge read, field isolation, late cancellation and strict target/write guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
