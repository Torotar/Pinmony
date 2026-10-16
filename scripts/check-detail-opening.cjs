const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const flush = () => new Promise(resolve => setImmediate(resolve));
const url = id => `https://www.pinterest.com/pin/${id}/`;
const pin = id => ({ id: String(id), type: 'pin', title: 'Verified title', aggregated_pin_data: { id: '303' },
  reaction_by_me: 0, reaction_counts: { '1': 0 },
  images: { '736x': { url: 'https://i.pinimg.com/example.jpg', width: 736, height: 1000 } } });
const response = id => JSON.stringify({ client_context: { ignored: 'not retained' },
  resource_response: { status: 'success', data: { ...pin(id), ignored_auth_field: 'not retained' } } });
const log = { info() {}, warn() {} };
function compile(path, deps = () => ({}), transform = source => source) {
  const exports = {};
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(transform(fs.readFileSync(path, 'utf8')), {
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
const { PinmonyRequestPolicy } = compile('common_network/src/main/ets/PinmonyRequestPolicy.ets', () => ({ PinmonyRuntimeLog: log }));
const { PinmonyNativeNetwork, acceptsNetworkJob } = compile('common_network/src/main/ets/PinmonyNativeNetwork.ets', name =>
  name === 'common_session' ? { PinmonySessionCredentials: Credentials } : name === 'common_foundation' ?
    { PinmonyRuntimeLog: log } : name.includes('PinmonyRequestPolicy') ? { PinmonyRequestPolicy } : { rcp });
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) { const begin = index.indexOf(`  private ${name}`); const end = index.indexOf('\n  private ', begin + 1); return index.slice(begin, end); }
const context = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: true, PIN_NATIVE_DETAIL_READS_ENABLED: true,
  PINTEREST_URL: 'https://www.pinterest.com/', acceptsNetworkJob,
  PinmonyRuntimeLog: log, readRelatedPresentation: () => undefined, setTimeout() {}, clearTimeout() {} };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Native {
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
  native.nativeBusinessSessionContext = () => ({ authenticated: state.authenticated, generation: 1,
    accountId: 'synthetic-account', origin: 'https://www.pinterest.com', userAgent: 'synthetic' });
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
    detailReadCache: { getPin() { return ''; }, retained() { return undefined; }, store() {}, clear() {}, reset() {} },
    detailImageStage: { reset() {} },
    nativeNetwork: { request() { throw Error('duplicate or unvalidated request reached regular network'); } },
    nativeNetworkContext: () => ({ ...state }), currentPinUrl: () => state.page });
  require('./medium-priority-controller-harness.cjs').bindWork(native, ts, context);
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
  assert.equal(JSON.parse(result.body).resource_response.data.aggregated_pin_data.id, '303', 'sanitized handoff preserves the captured comment identity');
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
  // Native account-owned reads survive arbitrary document changes, but a
  // late account reset must discard both the body and Set-Cookie.
  const { PinmonyBusinessSession } = compile('common_session/src/main/ets/services/PinmonyBusinessSession.ets');
  const business = new PinmonyBusinessSession();
  business.confirm('account-a', 'https://www.pinterest.com/account_a/', 'synthetic');
  const firstSession = business.context('authenticated');
  business.confirm('account-a', 'https://www.pinterest.com/account_a/', 'synthetic');
  assert.equal(business.context('authenticated').generation, firstSession.generation);
  const accountJob = { ...readJob, id: 'account_owned', epoch: firstSession.generation, page: url(3) };
  reply = new Promise(resolve => { finish = resolve; });
  let owned = true;
  const accountRead = network.requestBusinessPinRead(accountJob, () => business.context('authenticated'), url(3), () => owned);
  await flush(); state.page = url(999); state.epoch += 50;
  finish({ statusCode: 200, headers: {}, toString: () => response(3) });
  assert.equal((await accountRead).status, 200, 'Web navigation does not revoke the native session');
  reply = new Promise(resolve => { finish = resolve; });
  const cookieCount = cookies.length;
  const oldAccount = network.requestBusinessPinRead({ ...accountJob, id: 'old_account' }, () => business.context('authenticated'), url(3), () => owned);
  await flush(); business.reset(); business.confirm('account-b', 'https://www.pinterest.com/account_b/', 'synthetic');
  finish({ statusCode: 200, headers: { 'set-cookie': 'wrong-account' }, toString: () => response(3) });
  assert.equal((await oldAccount).error, 'cancelled'); assert.equal(cookies.length, cookieCount);
  const now = business.context('authenticated');
  const countBefore = requests.length;
  const ownerJob = { ...accountJob, epoch: now.generation, id: 'invalid_owner' };
  for (const [candidate, targetPin, current] of [
    [{ ...ownerJob, method: 'POST' }, url(3), () => true],
    [ownerJob, url(4), () => true],
    [ownerJob, url(3), () => false],
    [{ ...ownerJob, page: 'https://uk.pinterest.com/pin/3/' }, 'https://uk.pinterest.com/pin/3/', () => true]
  ]) assert((await network.requestBusinessPinRead(candidate, () => business.context('authenticated'), targetPin, current)).error);
  assert.equal(requests.length, countBefore);
  business.confirm('account-b', 'https://www.pinterest.com/account_b/', 'synthetic', 'fixture.1');
  const previewSession = business.context('authenticated');
  const previewJob = { ...ownerJob, id: 'native_preview_contract', epoch: previewSession.generation,
    headers: { 'X-App-Version': 'fixture.1', 'X-Pinterest-Pws-Handler': 'www/pin/[id].js' },
    url: 'https://www.pinterest.com/resource/UnifiedCommentsPreviewResource/get/?source_url=%2Fpin%2F3%2F&data=' +
      encodeURIComponent(JSON.stringify({ options: { aggregated_pin_id: '777' }, context: {} })) };
  reply = new Promise(resolve => { finish = resolve; });
  const previewRead = network.requestBusinessPinRead(previewJob, () => business.context('authenticated'), url(3), () => true, undefined, '777');
  await flush(); assert.equal(requests.at(-1).headers['X-App-Version'], 'fixture.1');
  assert.equal(requests.at(-1).headers.Referer, url(3));
  finish({ statusCode: 200, headers: {}, toString: () => response(3) }); assert.equal((await previewRead).status, 200);
  const listOptions = { aggregated_pin_id: '777', comment_featured_ids: [], page_size: 25, redux_normalize_feed: true, is_reversed: false };
  const listJob = { ...previewJob, id: 'native_comments_contract', url: 'https://www.pinterest.com/resource/UnifiedCommentsResource/get/?source_url=%2Fpin%2F3%2F&data=' + encodeURIComponent(JSON.stringify({ options: listOptions, context: {} })) };
  reply = new Promise(resolve => { finish = resolve; });
  const listRead = network.requestBusinessPinRead(listJob, () => business.context('authenticated'), url(3), () => true, undefined, '777');
  await flush(); assert.equal(requests.at(-1).headers.Referer, url(3));
  finish({ statusCode: 200, headers: {}, toString: () => response(3) }); assert.equal((await listRead).status, 200);
  const listBefore = requests.length;
  for (const options of [{ ...listOptions, aggregated_pin_id: '888' }, { ...listOptions, page_size: 10000 }, { ...listOptions, bookmarks: ['a','b'] }]) {
    const bad = { ...listJob, url: listJob.url.split('&data=')[0] + '&data=' + encodeURIComponent(JSON.stringify({ options, context: {} })) };
    assert((await network.requestBusinessPinRead(bad, () => business.context('authenticated'), url(3), () => true, undefined, '777')).error);
  }
  assert.equal(requests.length, listBefore, 'invalid comment list contracts never dispatch');
  const replyOptions = { isUnifiedComment: true, objectId: '21', redux_normalize_feed: true };
  const replyJob = { ...previewJob, id: 'native_replies_contract', url: 'https://www.pinterest.com/resource/AggregatedCommentReplyFeedResource/get/?source_url=%2Fpin%2F3%2F&data=' + encodeURIComponent(JSON.stringify({ options: replyOptions, context: {} })) };
  reply = new Promise(resolve => { finish = resolve; });
  const repliesRead = network.requestBusinessPinRead(replyJob, () => business.context('authenticated'), url(3), () => true, undefined, '777', '21');
  await flush(); finish({ statusCode: 200, headers: {}, toString: () => response(3) }); assert.equal((await repliesRead).status, 200);
  const replyBefore = requests.length;
  for (const options of [{ ...replyOptions, objectId: '22' }, { ...replyOptions, isUnifiedComment: false }, { ...replyOptions, bookmarks: ['unverified'] }]) {
    const bad = { ...replyJob, url: replyJob.url.split('&data=')[0] + '&data=' + encodeURIComponent(JSON.stringify({ options, context: {} })) };
    assert((await network.requestBusinessPinRead(bad, () => business.context('authenticated'), url(3), () => true, undefined, '777', '21')).error);
  }
  assert.equal(requests.length, replyBefore, 'reply owner and unconfirmed pagination rejected');
  const translateOptions = { url: '/v3/aggregated_comments/21/translate/' };
  const translateJob = { ...previewJob, id: 'native_translation_contract', url: 'https://www.pinterest.com/resource/ApiResource/get/?source_url=%2Fpin%2F3%2F&data=' + encodeURIComponent(JSON.stringify({ options: translateOptions, context: {} })) };
  reply = new Promise(resolve => { finish = resolve; });
  const translationRead = network.requestBusinessPinRead(translateJob, () => business.context('authenticated'), url(3), () => true, undefined, '777', '21');
  await flush(); finish({ statusCode: 200, headers: {}, toString: () => JSON.stringify({ resource_response: {
    status: 'success', code: 0, endpoint_name: 'v3_get_translation', data: null } }) });
  assert.equal((await translationRead).status, 200);
  const translateBefore = requests.length;
  for (const options of [{ url: '/v3/aggregated_comments/22/translate/' }, { url: '/v3/offsite/' },
    { ...translateOptions, data: {} }]) {
    const bad = { ...translateJob, url: translateJob.url.split('&data=')[0] + '&data=' + encodeURIComponent(JSON.stringify({ options, context: {} })) };
    assert((await network.requestBusinessPinRead(bad, () => business.context('authenticated'), url(3), () => true, undefined, '777', '21')).error);
  }
  for (const bad of [{ ...translateJob, method: 'POST' }, { ...translateJob, headers: {} }, { ...translateJob, id: 'unowned_translation' }])
    assert((await network.requestBusinessPinRead(bad, () => business.context('authenticated'), url(3), () => true, undefined, '777', '21')).error);
  assert((await network.requestBusinessPinRead(translateJob, () => business.context('authenticated'), url(3), () => false, undefined, '777', '21')).error);
  assert.equal(requests.length, translateBefore, 'translation is restricted to a current owned comment and an exact GET route');
  const homeOptions = { field_set_key: 'hf_grid', in_nux: false, in_news_hub: false, static_feed: false };
  const homeJob = { ...previewJob, id: 'native_home_contract', page: 'https://www.pinterest.com/', headers: { 'X-Pinterest-Pws-Handler': 'www/index.js' },
    url: 'https://www.pinterest.com/resource/UserHomefeedResource/get/?source_url=%2F&data=' + encodeURIComponent(JSON.stringify({ options: homeOptions, context: {} })) };
  reply = new Promise(resolve => { finish = resolve; });
  const homeRead = network.requestBusinessHomeRead(homeJob, () => business.context('authenticated'), 'account_b', '', () => true);
  await flush(); assert.equal(requests.at(-1).headers.Referer, homeJob.page);
  finish({ statusCode: 200, headers: {}, toString: () => response(3) }); assert.equal((await homeRead).status, 200);
  const homeBefore = requests.length;
  for (const candidate of [{ ...homeJob, method: 'POST' }, { ...homeJob, page: url(3) }, { ...homeJob, headers: {} },
    { ...homeJob, url: homeJob.url.replace('www.pinterest.com', 'uk.pinterest.com') }])
    assert((await network.requestBusinessHomeRead(candidate, () => business.context('authenticated'), 'account_b', '', () => true)).error);
  assert((await network.requestBusinessHomeRead(homeJob, () => business.context('authenticated'), 'account_b', '', () => false)).error);
  const invalidHome = { ...homeJob, url: homeJob.url.split('&data=')[0] + '&data=' + encodeURIComponent(JSON.stringify({ options: { ...homeOptions, bookmarks: ['a','b'] }, context: {} })) };
  assert((await network.requestBusinessHomeRead(invalidHome, () => business.context('authenticated'), 'account_b', '', () => true)).error);
  assert.equal(requests.length, homeBefore, 'home wrong origin/owner/method/cursor never dispatch');
  const beforeDenied = requests.length;
  for (const candidate of [{ ...previewJob, headers: {} }, { ...previewJob, headers: { ...previewJob.headers, 'X-App-Version': 'wrong' } }])
    assert((await network.requestBusinessPinRead(candidate, () => business.context('authenticated'), url(3), () => true, undefined, '777')).error);
  assert((await network.requestBusinessPinRead(previewJob, () => business.context('authenticated'), url(3), () => true, undefined, '888')).error);
  assert.equal(requests.length, beforeDenied);
  const rollbackModule = compile('common_network/src/main/ets/PinmonyNativeNetwork.ets', name =>
    name === 'common_session' ? { PinmonySessionCredentials: Credentials } : name === 'common_foundation' ?
      { PinmonyRuntimeLog: log } : name.includes('PinmonyRequestPolicy') ? { PinmonyRequestPolicy } : { rcp },
    source => source.replace('PIN_BUSINESS_PIN_READ_ENABLED: boolean = true', 'PIN_BUSINESS_PIN_READ_ENABLED: boolean = false'));
  const rollbackNetwork = new rollbackModule.PinmonyNativeNetwork();
  assert((await rollbackNetwork.requestBusinessPinRead(ownerJob, () => now, url(3), () => true)).error,
    'manual rollback requires a live legacy context');
  reply = new Promise(resolve => { finish = resolve; });
  const restored = rollbackNetwork.requestBusinessPinRead(ownerJob, () => now, url(3), () => true, () => state);
  await flush(); finish({ statusCode: 200, headers: {}, toString: () => response(3) });
  assert.equal((await restored).status, 200, 'manual rollback uses the protected original reader');
  rollbackNetwork.invalidate();
  business.context('unauthenticated');
  assert.equal(business.context('authenticated').authenticated, false, 'status alone cannot recreate a session');
  console.log('Detail opening: immediate card, in-flight transfer, one bridge read, field isolation, late cancellation and strict target/write guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
