const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const secondaryTimers = new Map(); let secondaryTimerId = 0;
async function advanceSecondary() { for (const [id, callback] of [...secondaryTimers]) { secondaryTimers.delete(id); callback(); } await flush(); }
function load(file, deps) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText,
    { exports, require: require('./local-message-test-fixture.cjs').withLocalMessages(deps || (() => ({}))), console, setTimeout(callback) { const id = ++secondaryTimerId; secondaryTimers.set(id, callback); return id; }, clearTimeout(id) { secondaryTimers.delete(id); } });
  return exports;
}
const { readRelatedPresentation } = load('feature_pin/src/main/ets/services/PinmonyRelatedPresentation.ets');
const { PinmonyDetailCache } = load('feature_pin/src/main/ets/services/PinmonyDetailCache.ets');
const translationEvents = [];
let translationLanguage = 'zh-CN,zh;q=0.9';
const { PinmonyDetailNativeReads } = load('entry/src/main/ets/app/PinmonyDetailNativeReads.ets', name =>
  name === './PinmonyTranslationDiagnostics' ? { PinmonyTranslationDiagnostics: { begin: () => 0, finish() {} } } :
  name === 'feature_pin' ? { readRelatedPresentation } : name === 'common_network' ? { PIN_BUSINESS_PIN_READ_ENABLED: true, Priority: { HIGH: 0 } } :
    name === 'common_foundation' ? { PinmonyI18n: { ...require('./local-message-test-fixture.cjs').rawLocalMessages, translationAcceptLanguage: () => translationLanguage }, PinmonyRuntimeLog: { info(message) { translationEvents.push(message); }, warn() {} } } : {});
const pinUrl = id => 'https://www.pinterest.com/pin/' + id + '/';
const related = (ids, bookmark) => JSON.stringify({ resource_response: { status: 'success', data: ids.map(id => ({
  id: String(id), type: 'pin', images: { '474x': { url: 'https://i.pinimg.com/' + id + '.jpg', width: 474, height: 700 } } })), bookmark } });
const preview = text => JSON.stringify({ resource_response: { status: 'success', data: text === null ? [] : [{ unified_comment: { text } }] } });
const base = id => JSON.stringify({ resource_response: { status: 'success', data: { id: String(id), aggregated_pin_id: '777', reaction_data:{reaction_by_me:0,reaction_counts:{'1':12}},comment_count:3 } } });
const flush = () => new Promise(resolve => setImmediate(resolve));
function fixture(expectedAggregate = '777', initialPin = pinUrl(1)) {
  let session = { authenticated: true, generation: 1, accountId: 'fixture', origin: 'https://www.pinterest.com', userAgent: 'synthetic', appVersion: 'fixture.1' };
  let foreground = true, root = false;
  const store = { detailOpeningToken: 1, detailPin: pinUrl(1), detailOpeningPin: pinUrl(1), detailActionsReady: false,
    detailCache: new PinmonyDetailCache(), detailScrollOffset: 42,
    detail: { kind: 'cached', session: 0, pinUrl: pinUrl(1), imageUrl: 'https://i.pinimg.com/1.jpg', title: 'base', actions: [], related: [] } };
  store.detailPin = initialPin; store.detailOpeningPin = initialPin; store.detail.pinUrl = initialPin;
  const published = []; let commentResult = { pin: '', loading: false, error: '', items: [] };
  Object.defineProperty(store, 'commentResult', { get: () => commentResult, set: value => {
    // ArkUI's parent observes a root property change; nested plain-object
    // mutation and assignment of the same reference do not publish a snapshot.
    if (value !== commentResult) published.push(JSON.parse(JSON.stringify(value)));
    commentResult = value;
  } });
  const requests = [], autoplayRequests = [], canceled = [], marks = [];
  const network = { cancel(id) { canceled.push(id); }, requestBusinessPinRead(job, context, pin, current, legacy, aggregate) {
    assert.equal(job.page, pin); assert(['', expectedAggregate].includes(aggregate)); assert(current());
    if (job.id.startsWith('native_autoplay_')) {
      autoplayRequests.push(job);
      return Promise.resolve({ status: 200, error: '', body: JSON.stringify({ resource_response: {
        status: 'success', code: 0, data: { id: '7', autoplay_videos_on_wifi_enabled: true, autoplay_videos_on_cellular_enabled: false }
      }, client_context: { user: { id: '7' } } }) });
    }
    return new Promise(resolve => requests.push({ job, resolve: body => resolve({ ...job, status: current() ? 200 : 0, body,
      error: current() ? '' : 'cancelled', headers: {} }) }));
  } };
  const controller = new PinmonyDetailNativeReads({ pinStore: () => store, session: () => session, network: () => network,
    legacyContext: () => { throw Error('Web context must not be read'); }, foreground: () => foreground, rootOnly: () => root,
    backTarget: () => '', mark: event => marks.push(event) });
  return { controller, store, requests, autoplayRequests, canceled, marks, published, setSession(value) { session = value; }, getSession() { return session; },
    setForeground(value) { foreground = value; }, setRoot(value) { root = value; } };
}
async function checkCapturedTranslations(harPath) {
  const entries = JSON.parse(fs.readFileSync(harPath, 'utf8')).log.entries;
  const body = entry => {
    const content = entry.response.content;
    const text = content.encoding === 'base64' ? Buffer.from(content.text, 'base64').toString('utf8') : content.text;
    return JSON.parse(text);
  };
  const records = [];
  for (const entry of entries) {
    const url = new URL(entry.request.url);
    if (!['/resource/ApiResource/get/', '/resource/UnifiedCommentsResource/get/', '/resource/AggregatedCommentReplyFeedResource/get/'].includes(url.pathname)) continue;
    try { records.push({ entry, url, options: JSON.parse(url.searchParams.get('data')).options, payload: body(entry) }); } catch {}
  }
  const translations = records.filter(record => /^\/v3\/aggregated_comments\/\d+\/translate\/$/.test(record.options?.url || '') &&
    typeof record.payload.resource_response?.data === 'string');
  assert(translations.length > 0, 'HAR must contain actual successful translation samples');
  for (const capture of translations) {
    const commentId = capture.options.url.match(/aggregated_comments\/(\d+)\//)[1];
    const source = capture.url.searchParams.get('source_url');
    assert(/^\/pin\/\d+\/$/.test(source), 'captured translation must have a Pin source');
    const replies = records.find(record => record.url.pathname === '/resource/AggregatedCommentReplyFeedResource/get/' &&
      record.url.origin === capture.url.origin && record.url.searchParams.get('source_url') === source &&
      Array.isArray(record.payload.resource_response?.data) && record.payload.resource_response.data.some(item => item.id === commentId));
    const parentId = replies?.options.objectId || commentId;
    const comments = records.find(record => record.url.pathname === '/resource/UnifiedCommentsResource/get/' &&
      record.url.origin === capture.url.origin && record.url.searchParams.get('source_url') === source &&
      Array.isArray(record.payload.resource_response?.data) && record.payload.resource_response.data.some(item => item.id === parentId));
    assert(comments, 'captured translation must match a captured comment in the same Pin');
    const pin = capture.url.origin + source, aggregate = comments.options.aggregated_pin_id;
    const f = fixture(aggregate, pin);
    const initial = { resource_response: { status: 'success', data: { id: source.match(/\d+/)[0],
      aggregated_pin_id: aggregate } }, client_context: comments.payload.client_context };
    const begin = f.controller.start(pin, 1, JSON.stringify(initial));
    await advanceSecondary();
    f.requests[0].resolve(preview(null)); await flush(); f.requests[1].resolve(related([], '-end-')); await begin;
    f.store.commentToken = 1;
    const read = f.controller.readComments(false, () => true);
    f.requests[2].resolve(JSON.stringify(comments.payload)); await read;
    assert(!f.store.commentResult.error, 'actual captured comments must pass native mapping');
    const parent = f.store.commentResult.items.find(value => value.id === parentId);
    if (replies) {
      const readingReplies = f.controller.readReplies(parentId, () => true);
      f.requests.at(-1).resolve(JSON.stringify(replies.payload)); await readingReplies;
      assert(!parent.repliesError, 'actual captured replies must pass native mapping');
    }
    const item = replies ? parent.replies.find(value => value.id === commentId) : parent;
    assert(item?.canTranslate, 'captured target must retain translation eligibility');
    const originalText = item.text;
    const beforeTranslation = f.requests.length;
    const translating = f.controller.translateComment(commentId, () => true);
    assert(f.requests.length === beforeTranslation + 1, 'actual captured comment dispatches one native translation');
    const requested = JSON.parse(new URL(f.requests.at(-1).job.url).searchParams.get('data'));
    assert(requested.options.url === capture.options.url, 'native route must match the captured route exactly');
    f.requests.at(-1).resolve(JSON.stringify(capture.payload)); await translating;
    assert(item.translatedText === capture.payload.resource_response.data.trim(), 'captured translation must be preserved');
    assert(item.translationVisible && !item.translationLoading && !item.translationError, 'captured result must be visible and settled');
    assert(item.text === originalText, 'captured original remains intact');
    assert(f.published.at(-1).items.some(value => value.id === commentId && value.translationVisible ||
      value.replies?.some(reply => reply.id === commentId && reply.translationVisible)), 'actual result reaches presentation snapshot');
    f.controller.pause();
  }
  console.log('Captured HAR translation: ' + translations.length + ' actual comment mapping, exact route, response parsing and visible snapshot cases passed; no online request performed');
}
async function main() {
  const eligibility = fixture();
  for (const flag of [true, false, undefined, null, 'true', 1]) {
    const raw = { id: '21', type: 'aggregatedcomment', text: 'sample', is_translatable: flag };
    assert.equal(eligibility.controller.mapComment(raw).canTranslate, flag === true,
      'only an explicit server true enables translation, without local language guessing');
  }
  for (const raw of [{ id: '21', type: 'aggregatedcomment', text: '  ', is_translatable: true },
    { id: '21', type: 'userdiditdata', details: 'photo', is_translatable: true }]) {
    assert.equal(eligibility.controller.mapComment(raw).canTranslate, false);
  }
  const fastBase = fixture(); fastBase.controller.warmRelated(pinUrl(1), 1);
  const fastRead = fastBase.controller.start(pinUrl(1), 1, base(1));
  assert.equal(fastBase.requests.length, 0);
  await advanceSecondary();
  assert.equal(fastBase.requests.length, 2, 'fast base retains the original budget timer and coalesces reads');
  fastBase.requests.find(r => r.job.id.startsWith('native_related_')).resolve(related([2], 'next'));
  await fastRead;
  fastBase.requests.find(r => r.job.id.startsWith('native_preview_')).resolve(preview('preview'));
  await flush(); fastBase.controller.pause();
  // Early recommendations are display-only; PinResource remains the readiness gate.
  for (const completeBeforeBase of [false, true]) {
    const early = fixture();
    early.controller.warmRelated(pinUrl(1), 1);
    assert.equal(early.requests.length, 0, 'main image budget precedes the early read');
    await advanceSecondary();
    assert.equal(early.requests.length, 1);
    assert(early.requests[0].job.id.startsWith('native_related_early_'));
    assert.equal(early.requests[0].job.priority, 0);
    if (completeBeforeBase) { early.requests[0].resolve(related([2], 'next')); await flush(); }
    assert.equal(early.store.detail.related.length, completeBeforeBase ? 1 : 0, 'validated early response may present before base validation');
    if (completeBeforeBase) {
      assert.equal(early.store.detail.relatedPreview, true);
      assert.equal(early.store.detail.relatedRetained, true, 'preview retains the existing read-only interaction gate');
      assert.equal(early.store.detailActionsReady, false);
    }
    assert.equal(early.store.detailNativeReadsReady, undefined, 'early read does not authorize actions');
    const pending = early.controller.start(pinUrl(1), 1, base(1));
    await advanceSecondary();
    assert.equal(early.requests.length, 2, 'validated start adds preview and reuses the early recommendation');
    if (!completeBeforeBase) early.requests[0].resolve(related([2], 'next'));
    await pending;
    assert.equal(early.store.detail.related.length, 1);
    assert.equal(early.store.detail.relatedPreview, false, 'base adoption promotes the existing presentation');
    assert.equal(early.controller.earlyRelated, undefined, 'consumed response is released');
    early.requests[1].resolve(preview('preview')); await flush();
    early.controller.pause();
  }
  for (const revoke of [f => f.controller.pause(), f => f.setSession({...f.getSession(),generation:2}),
    f => f.setSession({...f.getSession(),accountId:'another'}), f => f.setSession({...f.getSession(),authenticated:false}),
    f => f.store.detailOpeningToken++, f => { f.store.detailPin = pinUrl(2); f.store.detailOpeningPin = pinUrl(2); },
    f => f.setForeground(false), f => f.setRoot(true)]) {
    const early = fixture(); early.controller.warmRelated(pinUrl(1), 1);
    revoke(early); await advanceSecondary();
    assert.equal(early.requests.length, 0, 'retired early reads never dispatch'); early.controller.pause();
    const inflight = fixture(); inflight.controller.warmRelated(pinUrl(1), 1); await advanceSecondary();
    revoke(inflight); inflight.requests[0].resolve(related([2], 'next')); await flush();
    assert.equal(inflight.store.detail.related.length, 0, 'late early response never publishes'); inflight.controller.pause();
  }
  const invalidBase = fixture(); invalidBase.controller.warmRelated(pinUrl(1), 1);
  await advanceSecondary();
  await assert.rejects(invalidBase.controller.start(pinUrl(1), 1, base(2)), /invalid-native-base/);
  assert(invalidBase.canceled.includes(invalidBase.requests[0].job.id));
  invalidBase.requests[0].resolve(related([2], 'next')); await flush();
  assert.equal(invalidBase.controller.earlyRelated, undefined);
  const failedEarly = fixture(); failedEarly.controller.warmRelated(pinUrl(1), 1); await advanceSecondary();
  failedEarly.requests[0].resolve('{}'); await flush();
  const failedRead = failedEarly.controller.start(pinUrl(1), 1, base(1)); await advanceSecondary(); await failedRead;
  assert.equal(failedEarly.requests.length, 2, 'failed early read is not silently replayed');
  assert(failedEarly.store.detail.relatedError);
  failedEarly.requests[1].resolve(preview('preview')); await flush(); failedEarly.controller.pause();
  const scopedCancel = fixture(); scopedCancel.controller.warmRelated(pinUrl(1), 1);
  scopedCancel.controller.cancelEarlyRelated(pinUrl(2), 2);
  assert(scopedCancel.controller.earlyRelated, 'old opening failure cannot cancel another opening');
  scopedCancel.controller.pause(); await flush();
  assert.equal(secondaryTimers.size, 0);
  for (const revoke of [f => f.controller.pause(), f => f.setSession({...f.getSession(),generation:2}), f => f.store.detailOpeningToken++]) {
    const waiting=fixture();const pending=waiting.controller.start(pinUrl(1),1,base(1)).catch(()=> 'cancelled');
    assert.equal(waiting.requests.length,0);revoke(waiting);await advanceSecondary();
    assert.equal(await pending,'cancelled');assert.equal(waiting.requests.length,0,'retired entry must not dispatch deferred requests');
  }
  assert.equal(secondaryTimers.size,0,'pause clears deferred timers');

  const parallel = fixture();
  const parallelRead = parallel.controller.start(pinUrl(1), 1, base(1));
  assert.equal(parallel.requests.length, 0, 'noncritical reads wait through the entry budget');
  await advanceSecondary();
  assert.equal(parallel.requests.length, 2, 'both independent reads start before either response');
  parallel.requests[1].resolve(related([2], '-end-')); await parallelRead;
  assert.equal(parallel.store.detail.related.length, 1, 'recommendations publish while preview is pending');
  assert.equal(parallel.store.detail.commentLoading, true);
  parallel.requests[0].resolve(preview('late successful preview')); await flush();
  assert.equal(parallel.store.detail.commentPreview, 'late successful preview');
  assert.equal(parallel.controller.retainedRelated.get(pinUrl(1)).previewText, 'late successful preview', 'retained state includes a later preview');
  const retained = fixture();
  let retaining = retained.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
  retained.requests[0].resolve(preview('preview')); await flush();
  retained.requests[1].resolve(related([2, 3], 'retained-next')); await retaining;
  retained.controller.pause();
  assert.equal(retained.controller.resume(pinUrl(1), 1), true);
  await flush();
  assert.equal(retained.autoplayRequests.length, 1, 'native back reuses current-session confirmed preferences');
  assert.equal(retained.store.detail.autoplayWifi, true, 'self settings work without PinResource viewer');
  assert.equal(retained.requests.length, 2, 'native back resumes without base, preview or recommendation reads');
  assert.equal(retained.store.detail.commentPreview, 'preview');
  retained.controller.pause();
  retaining = retained.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
  assert.equal(retained.store.detail.relatedLoading, false);
  assert.equal(retained.store.detail.commentPreview, 'preview', 'revalidation keeps the existing preview until the response replaces it');
  assert.equal(retained.store.detail.commentsRetained, true);
  retained.requests[2].resolve(preview('fresh preview')); await retaining;
  assert.equal(retained.requests.length, 3, 'return retains recommendations without fetching their first page');
  retained.controller.loadMore();
  assert.equal(JSON.parse(new URL(retained.requests[3].job.url).searchParams.get('data')).options.bookmarks[0], 'retained-next');
  retained.requests[3].resolve(related([4], '-end-')); await flush();
  retained.setSession({ ...retained.getSession(), generation: 2, accountId: 'other' });
  assert.equal(retained.controller.resume(pinUrl(1), 1), false, 'account changes reject native back state');
  retaining = retained.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
  retained.requests[4].resolve(preview('other preview')); await flush();
  assert.equal(retained.requests.length, 6, 'new account generation cannot reuse retained recommendations');
  retained.requests[5].resolve(related([], '-end-')); await retaining;
  // The captured PinResource shape has aggregated_pin_data.id only. Exercise
  // preview and full list, not just successful base/related reads.
  for (const data of [ { id: '1', aggregated_pin_data: { id: '777' } },
    { id: '1', aggregated_pin_id: 'invalid', aggregated_pin_data: { id: '777' } } ]) {
    const nested = fixture();
    const started = nested.controller.start(pinUrl(1), 1, JSON.stringify({ resource_response: { status: 'success', data } }));
  await advanceSecondary();
    assert.match(nested.requests[0].job.url, /UnifiedCommentsPreviewResource/);
    assert.equal(JSON.parse(new URL(nested.requests[0].job.url).searchParams.get('data')).options.aggregated_pin_id, '777');
    nested.requests[0].resolve(preview('nested preview')); await flush();
    nested.requests[1].resolve(related([], '-end-')); await started;
    nested.store.commentToken = 1;
    const list = nested.controller.readComments(false, () => true);
    assert.match(nested.requests[2].job.url, /UnifiedCommentsResource/);
    nested.requests[2].resolve(JSON.stringify({ resource_response: { status: 'success', data: [{ id: '21', type: 'aggregatedcomment', text: 'nested list' }] } })); await list;
    assert.equal(nested.store.commentResult.items[0].text, 'nested list');
    assert.equal(nested.store.detailActionsReady, false);
  }
  for (const data of [ { id: '1' }, { id: '1', aggregated_pin_data: { id: 'invalid' } } ]) {
    const missing = fixture();
    const started = missing.controller.start(pinUrl(1), 1, JSON.stringify({ resource_response: { status: 'success', data } }));
  await advanceSecondary();
    await flush(); assert.equal(missing.requests.length, 1); assert.match(missing.requests[0].job.url, /RelatedModulesResource/);
    assert.equal(missing.store.detail.commentsAvailable, false); assert.match(missing.store.detail.commentError, /缺少评论标识/);
    assert.equal(missing.store.detail.commentEmpty, false, 'missing identity is not an empty comment feed');
    assert.equal(missing.controller.retryPreview(), false, 'missing identity requires a fresh validated base read');
    missing.requests[0].resolve(related([], '-end-')); await started;
    missing.store.commentToken = 1; await missing.controller.readComments(false, () => true);
    assert.equal(missing.requests.length, 1, 'never substitute Pin ID for aggregate');
    assert.equal(missing.store.commentResult.loading, false); assert.match(missing.store.commentResult.error, /评论标识/);
    assert(missing.marks.includes('comments.native.identity.missing'));
  }
  const f = fixture();
  const first = f.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
  assert.equal(f.store.detail.actions.find(a=>a.kind==='like').countText,'12');
  assert.equal(f.store.detail.actions.find(a=>a.kind==='comment').countText,'3');
  assert(f.store.detail.actions.some(a=>a.kind==='save'));
  assert(f.store.detail.actions.some(a=>a.kind==='more'));
  assert.equal(f.requests.length, 2, 'preview and related are dispatched without serial waiting'); assert.match(f.requests[0].job.url, /UnifiedCommentsPreviewResource/);
  assert.equal(f.requests[0].job.headers['X-App-Version'], 'fixture.1');
  assert.equal(f.requests[0].job.headers['X-Pinterest-Pws-Handler'], 'www/pin/[id].js');
  assert.equal(f.store.detailActionsReady, false, 'native reads never grant mutation permission');
  f.requests[0].resolve(preview('confirmed preview')); await flush();
  assert.equal(f.requests.length, 2, 'preview completion does not duplicate related reads');
  f.requests[1].resolve(related([2,3], 'next')); await first;
  assert.equal(f.store.detail.commentPreview, 'confirmed preview'); assert.equal(f.store.detail.related.length, 2);
  assert.equal(f.store.detailNativeReadsReady, true);
  assert.equal(f.store.detailCache.get('1').detail.related.length, 2, 'return cache includes native recommendations');
  assert.equal(f.store.detailCache.get('1').scrollOffset, 42);
  assert.equal(f.store.detailCache.get('1').detail.session, 0, 'cache never grants an operation session');
  f.store.detail = { ...f.store.detail, commentPreview: 'stale bridge', related: [] };
  f.controller.apply(); assert.equal(f.store.detail.commentPreview, 'confirmed preview'); assert.equal(f.store.detail.related.length, 2);
  f.controller.loadMore(); f.controller.loadMore(); assert.equal(f.requests.length, 3, 'pagination is coalesced');
  assert.equal(JSON.parse(new URL(f.requests[2].job.url).searchParams.get('data')).options.bookmarks[0], 'next');
  f.requests[2].resolve(related([3,4], 'next')); await flush();
  assert.equal(f.store.detail.related.length, 3); assert.equal(f.store.detail.relatedEnded, true, 'repeated cursor terminates');
  assert.equal(f.store.detailCache.get('1').detail.related.length, 3, 'pagination updates the parent presentation');
  f.controller.loadMore(); assert.equal(f.requests.length, 3);

  f.store.commentToken = 1;
  const commentsBody = (ids, bookmark) => JSON.stringify({ client_context: {user: {id:'42'}}, resource_response: { status: 'success', data: ids.map(id => ({ id: String(id), type: 'aggregatedcomment', text: 'text', user: { id: '42', username: 'reader' } })), bookmark } });
  let reading = f.controller.readComments(false, () => true);
  assert.match(f.requests[3].job.url, /UnifiedCommentsResource/);
  f.requests[3].resolve(commentsBody([11,12], 'c-next')); await reading;
  assert.equal(f.store.commentResult.items.length, 2); assert.equal(f.store.commentResult.items[0].canEdit, true);
  assert.equal(f.published.at(-1).loading, false, 'completed list publishes a new result to end the UI loading state');
  assert.equal(f.published.at(-1).items.length, 2, 'completed list items reach the UI snapshot');
  reading = f.controller.readComments(true, () => true); f.controller.readComments(true, () => true);
  assert.equal(f.requests.length, 5);
  assert.equal(JSON.parse(new URL(f.requests[4].job.url).searchParams.get('data')).options.bookmarks[0], 'c-next');
  f.requests[4].resolve('bad'); await reading; assert(f.store.commentResult.error); assert.equal(f.store.commentResult.items.length, 2);
  assert.equal(f.published.at(-1).loading, false); assert(f.published.at(-1).error, 'failure is published to the retry UI');
  reading = f.controller.readComments(true, () => true); f.requests[5].resolve(commentsBody([12,13], 'c-next')); await reading;
  assert.equal(f.store.commentResult.items.length, 3); assert.equal(f.store.commentResult.ended, true);
  reading = f.controller.readComments(false, () => true); f.store.commentToken++; f.controller.cancelComments();
  f.requests[6].resolve(commentsBody([99], '')); await reading;
  assert(!f.store.commentResult.items.some(item => item.id === '99')); assert(f.canceled.some(id => id.startsWith('native_comments_')));
  assert.equal(f.published.at(-1).loading, false); assert.match(f.published.at(-1).error, /已中断/, 'cancellation exits loading');
  reading = f.controller.readComments(false, () => true); f.requests[7].resolve(commentsBody([], '')); await reading;
  assert.equal(f.store.commentResult.items.length, 0); assert.equal(f.store.commentResult.ended, true);
  reading = f.controller.readComments(false, () => true); f.requests[8].resolve(commentsBody([21], '')); await reading;
  f.store.commentResult.items[0].replyCount = 2;
  reading = f.controller.readReplies('21', () => true); f.controller.readReplies('21', () => true);
  assert.equal(f.requests.length, 10, 'reply reads coalesce per parent');
  assert.match(f.requests[9].job.url, /AggregatedCommentReplyFeedResource/);
  assert.deepEqual(JSON.parse(new URL(f.requests[9].job.url).searchParams.get('data')).options,
    { isUnifiedComment: true, objectId: '21', redux_normalize_feed: true });
  f.requests[9].resolve(commentsBody([31,31,32], '-end-')); await reading;
  assert.equal(f.store.commentResult.items[0].replies.length, 2);
  assert.equal(f.published.at(-1).items[0].repliesLoading, false); assert.equal(f.published.at(-1).items[0].replies.length, 2);
  await f.controller.readReplies('21', () => true); assert.equal(f.store.commentResult.items[0].repliesOpen, false);
  await f.controller.readReplies('21', () => true); assert.equal(f.requests.length, 10, 'reopen reuses replies');
  f.store.commentResult.items[0].repliesError = 'retry';
  reading = f.controller.readReplies('21', () => true); f.requests[10].resolve('bad-json'); await reading;
  assert(f.store.commentResult.items[0].repliesError); assert.equal(f.store.commentResult.items[0].replies.length, 2);
  reading = f.controller.readReplies('21', () => true); f.requests[11].resolve(commentsBody([], '-end-')); await reading;
  assert.equal(f.store.commentResult.items[0].replies.length, 0); assert.equal(f.store.commentResult.items[0].repliesError, '');
  f.store.commentResult.items[0].repliesError = 'retry';
  reading = f.controller.readReplies('21', () => true); f.store.commentToken++; f.controller.cancelComments();
  f.requests[12].resolve(commentsBody([99], '')); await reading;
  assert(!f.store.commentResult.items[0].replies.some(item => item.id === '99'));
  assert(f.canceled.some(id => id.startsWith('native_replies_')));
  f.store.commentResult.items[0].repliesLoading = false;
  reading = f.controller.readReplies('21', () => true); f.requests[13].resolve(commentsBody([33], 'unconfirmed-next')); await reading;
  assert.match(f.store.commentResult.items[0].repliesError, /分页接口尚未确认/);
  await f.controller.readReplies('999', () => true); assert.equal(f.requests.length, 14, 'unknown parent cannot dispatch');
  f.store.commentResult.items[0].type = 'userdiditdata';
  f.store.commentResult.items[0].repliesError = 'retry';
  reading = f.controller.readReplies('21', () => true);
  assert(f.requests.at(-1).job.url.includes('/resource/DidItCommentsResource/get/'));
  f.requests.at(-1).resolve(commentsBody([88], '-end-')); await reading;
  assert.equal(f.store.commentResult.items[0].replies[0].id, '88');


  for (const revoke of [g => g.controller.pause(), g => g.setForeground(false), g => g.setRoot(true),
    g => g.setSession({ ...g.getSession(), accountId: 'other', generation: 2 }), g => { g.store.detailOpeningToken++; }]) {
    const g = fixture(); const started = g.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
    g.requests[0].resolve(preview(null)); await flush(); g.requests[1].resolve(related([], '-end-')); await started;
    g.store.commentToken = 1; const list = g.controller.readComments(false, () => true);
    g.requests[2].resolve(commentsBody([21], '')); await list;
    const pendingReply = g.controller.readReplies('21', () => true); revoke(g);
    g.requests[3].resolve(commentsBody([99], '')); await pendingReply;
    assert(!g.store.commentResult.items[0].replies.some(item => item.id === '99'), 'revoked reply ownership cannot commit');
  }
  const failed = fixture(); const initial = failed.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
  failed.requests[0].resolve(preview(null)); await flush();
  failed.requests[1].resolve('bad-json'); await initial;
  assert(failed.store.detail.relatedError); assert.equal(failed.store.detail.commentEmpty, true);
  assert(failed.store.detailCache.get('1').detail.relatedError, 'return preserves failure rather than a silent blank');
  failed.controller.loadMore(); assert.equal(failed.requests.length, 3);
  failed.requests[2].resolve(related([2], '-end-')); await flush();
  assert.equal(failed.store.detail.relatedError, ''); assert.equal(failed.store.detail.related.length, 1);

  const metadata = fixture(); metadata.setSession({ ...metadata.getSession(), appVersion: '' });
  const metadataRead = metadata.controller.start(pinUrl(1), 1, base(1)); await flush();
  await advanceSecondary();
  assert.equal(metadata.requests.length, 1); assert.match(metadata.requests[0].job.url, /RelatedModulesResource/);
  assert.match(metadata.store.detail.commentError, /请求信息/); assert.equal(metadata.store.detail.commentLoading, false);
  metadata.requests[0].resolve(related([], '-end-')); await metadataRead;
  metadata.setSession({ ...metadata.getSession(), appVersion: 'fixture.2' });
  metadata.controller.retryPreview(); metadata.controller.retryPreview(); assert.equal(metadata.requests.length, 2);
  metadata.requests[1].resolve(preview('retry')); await flush(); assert.equal(metadata.store.detail.commentPreview, 'retry');

  for (const revoke of [f => f.controller.pause(), f => f.setSession({ ...f.getSession(), generation: 2, accountId: 'other' }),
    f => { f.store.detailOpeningToken++; }, f => f.setRoot(true), f => f.setForeground(false)]) {
    const stale = fixture(); const pending = stale.controller.start(pinUrl(1), 1, base(1)).catch(() => 'cancelled');
  await advanceSecondary();
    revoke(stale); stale.requests[0].resolve(preview('late')); stale.requests[1].resolve(related([99], '-end-')); await pending;
    assert.equal(stale.requests.length, 2, 'revoked parallel reads cannot dispatch additional reads');
    assert(!stale.store.detail.related.some(item => item.id === '99'), 'revoked recommendations cannot publish');
    assert.notEqual(stale.store.detail.commentPreview, 'late'); assert.equal(stale.controller.owned(), false);
    assert.notEqual(stale.store.detailCache.get('1')?.detail.commentPreview, 'late', 'revoked reads cannot update return cache');
  }
  const wrong = fixture(); await assert.rejects(wrong.controller.start(pinUrl(1), 1, base(2)));
  assert.equal(wrong.requests.length, 0);
  const t = fixture();
  const translationBase = JSON.parse(base(1));
  translationBase.client_context = { user: { id: '7' } };
  const begin = t.controller.start(pinUrl(1), 1, JSON.stringify(translationBase));
  await advanceSecondary();
  t.requests[0].resolve(preview(null)); await flush(); t.requests[1].resolve(related([], '-end-')); await begin;
  const original = { id: '21', type: 'aggregatedcomment', text: 'Bonjour', canTranslate: true, replies: [] };
  t.store.commentToken = 1;
  t.store.commentResult = { pin: pinUrl(1), loading: false, error: '', items: [original] };
  const translation = (data, context, http_status) => JSON.stringify({ resource_response: { status: 'success', code: 0, endpoint_name: 'v3_get_translation', data, http_status }, client_context: context });
  await t.controller.translateComment('99', () => true);
  assert.equal(t.requests.length, 2, 'unowned comments do not dispatch translation');
  original.canTranslate = false;
  await t.controller.translateComment('21', () => true);
  assert.equal(t.requests.length, 2, 'ineligible comments do not dispatch even through a direct action');
  const blockedReply = { id: '22', type: 'aggregatedcomment', text: 'reply', canTranslate: false };
  original.replies.push(blockedReply);
  await t.controller.translateComment('22', () => true);
  assert.equal(t.requests.length, 2, 'ineligible nested replies do not dispatch');
  original.canTranslate = true;
  const pending = t.controller.translateComment('21', () => true);
  assert.equal(original.translationLoading, true);
  await t.controller.translateComment('21', () => true);
  assert.equal(t.requests.length, 3, 'duplicate translation is blocked');
  const options = JSON.parse(decodeURIComponent(t.requests[2].job.url.match(/[?&]data=([^&]+)/)[1])).options;
  assert.deepEqual(options, { url: '/v3/aggregated_comments/21/translate/' });
  assert.equal(t.requests[2].job.method, 'GET');
  assert.equal(t.requests[2].job.headers['Accept'], 'application/json, text/javascript, */*, q=0.01');
  assert.equal(t.requests[0].job.headers['Accept'], 'application/json', 'AJAX Accept is scoped to translation');
  assert.equal(t.requests[2].job.headers['Accept-Language'], 'zh-CN,zh;q=0.9');
  assert.equal(t.requests[2].job.headers['Cache-Control'], 'no-cache');
  assert.equal(t.requests[2].job.headers['Pragma'], 'no-cache');
  const firstNonce = new URL(t.requests[2].job.url).searchParams.get('_');
  assert.match(firstNonce, /^\d+$/);
  assert.equal(t.requests[0].job.headers['Cache-Control'], undefined);
  assert.equal(t.requests[0].job.headers['Pragma'], undefined);
  assert.equal(new URL(t.requests[0].job.url).searchParams.has('_'), false);
  assert.equal(t.requests[0].job.headers['Accept-Language'], undefined, 'unrelated reads do not gain a translation language');
  t.requests[2].resolve(translation(null, { locale: 'en-US', is_authenticated: true,
    user: { id: '7', locale: 'zh-CN' } }, 200)); await pending;
  assert.notEqual(t.getSession().accountId, '7', 'business cache identity is distinct from website viewer id');
  assert(translationEvents.some(message => /phase=context task=\d+ authenticated=true account=match locale=en-US userLocale=zh-CN upstreamStatus=200$/.test(message)));
  assert.equal(original.translationError, '暂无可用译文');
  assert(translationEvents.includes('CommentsTranslationTrace: phase=response shape=null textLength=0'));
  assert(translationEvents.includes('CommentsTranslationTrace: phase=empty'));
  assert.equal(t.published.at(-1).items[0].translationLoading, false); assert.equal(t.published.at(-1).items[0].translationError, '暂无可用译文');
  assert.equal(original.translatedText, ''); assert.equal(original.translationLoading, false);
  const retry = t.controller.translateComment('21', () => true);
  assert.notEqual(new URL(t.requests[3].job.url).searchParams.get('_'), firstNonce, 'manual retry has a fresh cache nonce');
  t.store.commentResult = { ...t.store.commentResult, items: [original, { id: '22', text: 'other' }] };
  // A plain-text success is synthetic branch coverage, not a captured online result.
  t.requests[3].resolve(translation('你好', { locale: 'untrusted-locale-marker', is_authenticated: false,
    user: { id: 'untrusted-account-marker', locale: 'untrusted-user-locale-marker' } })); await retry;
  assert(translationEvents.some(message => message.includes('authenticated=false account=mismatch locale=other userLocale=other upstreamStatus=unknown')));
  assert(!translationEvents.some(message => message.includes('untrusted-')), 'context diagnostics never log raw unknown locale or account values');
  assert.equal(original.translatedText, '你好');
  assert(translationEvents.includes('CommentsTranslationTrace: phase=committed'));
  assert(!translationEvents.some(message => message.includes('Bonjour') || message.includes('你好')), 'translation diagnostics exclude original and translated text'); assert.equal(original.translationVisible, true);
  assert.equal(t.store.commentResult.items.length, 2, 'pagination remains intact while a translation completes');
  assert.equal(original.text, 'Bonjour', 'the editable original is never overwritten');
  await t.controller.translateComment('21', () => true); assert.equal(original.translationVisible, false);
  await t.controller.translateComment('21', () => true); assert.equal(original.translationVisible, true);
  assert.equal(t.requests.length, 4, 'display toggles do not re-request translation');
  translationLanguage = 'en-US,en;q=0.9';
  const unconfirmed = t.controller.translateComment('21', () => true);
  assert.equal(t.requests[4].job.headers['Accept-Language'], 'en-US,en;q=0.9');
  assert.equal(original.translatedText, '', 'changing language cannot reuse the previous translation');
  assert.equal(original.translationLanguage, translationLanguage);
  t.requests[4].resolve(translation({ text: 'unconfirmed object format' })); await unconfirmed;
  assert(translationEvents.some(message => message.includes('authenticated=unknown account=unknown locale=absent userLocale=absent upstreamStatus=unknown')));
  assert.equal(original.translationError, '暂无法识别译文格式');
  const closed = t.controller.translateComment('21', () => true);
  t.controller.cancelComments(); assert.equal(original.translationLoading, false);
  assert(t.canceled.some(id => id.startsWith('native_translation_')));
  t.requests[5].resolve(translation('late')); await closed;
  assert.notEqual(original.translatedText, 'late');
  const staleTranslation = t.controller.translateComment('21', () => true);
  t.setSession({ ...t.getSession(), accountId: 'other', generation: 2 });
  t.requests[6].resolve(translation('other account')); await staleTranslation;
  assert.notEqual(original.translatedText, 'other account');
  translationLanguage = 'zh-CN,zh;q=0.9';
  const observed = fixture(); const baseRead = observed.controller.start(pinUrl(1), 1, base(1));
  await advanceSecondary();
  observed.requests[0].resolve(preview(null)); await flush(); observed.requests[1].resolve(related([], '-end-')); await baseRead;
  observed.store.commentToken = 1;
  const abandoned = observed.controller.readComments(false, () => true);
  observed.controller.cancelComments();
  const fresh = observed.controller.readComments(false, () => true);
  const beforeLate = observed.published.length;
  observed.requests[2].resolve(commentsBody([99], '')); await abandoned;
  assert.equal(observed.published.length, beforeLate, 'late cancelled response cannot publish or finish the new loader');
  assert.equal(observed.store.commentResult.loading, true);
  observed.requests[3].resolve(commentsBody([21,22], '')); await fresh;
  const leftReply = observed.controller.readReplies('21', () => true);
  const rightReply = observed.controller.readReplies('22', () => true);
  observed.requests[5].resolve(commentsBody([32], '-end-')); await rightReply;
  observed.requests[4].resolve(commentsBody([31], '-end-')); await leftReply;
  assert.equal(observed.published.at(-1).items[0].replies[0].id, '31');
  assert.equal(observed.published.at(-1).items[1].replies[0].id, '32', 'publishing one parent preserves concurrent replies');
  observed.store.commentResult.items[0].repliesError = 'retry';
  const cancelledReply = observed.controller.readReplies('21', () => true);
  observed.controller.cancelComments(); const afterCancel = observed.published.length;
  observed.requests[6].resolve(commentsBody([99], '-end-')); await cancelledReply;
  assert.equal(observed.published.length, afterCancel, 'reply cancellation works even without changing the panel token');
  const malformed = observed.controller.readComments(false, () => true);
  observed.requests[7].resolve(JSON.stringify({ resource_response: { status: 'success', data: [{ unexpected: true }] } })); await malformed;
  assert.match(observed.published.at(-1).error, /格式无法识别/); assert.equal(observed.published.at(-1).loading, false);
  const scriptSource = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets', 'utf8');
  const script = Function('return `' + scriptSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  const webRequests = [];
  const web = { PinmonyDetailApiEnabled: true, PinmonyNativeDetailReadsEnabled: true }; web.top = web;
  vm.runInNewContext(script, { window: web, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com' },
    AbortController, setTimeout, clearTimeout, console: { warn() {} }, fetch: () => new Promise(resolve => webRequests.push(resolve)) });
  web.PinmonyDetailApi.read(pinUrl(1), () => {}, () => true);
  webRequests[0]({ ok: true, json: async () => ({ resource_response: { status: 'success', data: {
    id: '1', type: 'pin', images: { '474x': { url: 'https://i.pinimg.com/1.jpg', width: 474, height: 700 } } } } }) });
  await flush(); assert.equal(webRequests.length, 1, 'Web base cannot start a duplicate recommendation read');
  const extensionSource = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyPostExtensionsScript.ets', 'utf8');
  const extension = Function('return `' + extensionSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  const post = { reset() {}, resourceRequest() { throw Error('duplicate preview'); } };
  vm.runInNewContext(extension, { window: { PinmonyPostApi: post, PinmonyPostExtensionsEnabled: true, PinmonyNativeDetailReadsEnabled: true } });
  assert.equal(post.previewRead(pinUrl(1)), null, 'Web preview delegates to native ownership');
  const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8').replaceAll('this.displayedDetail()', 'this.detail');
  const visibility = page.match(/if \(\((this\.readsReady \|\| this\.actionsReady && this\.detail\.imageStageReady[^]*?)\) \{/)[1];
  const shows = view => !!vm.runInNewContext('(function(){return ((' + visibility + ');}).call(view)', { view });
  const view = { readsReady: true, actionsReady: false, detail: { kind: 'state', imageStageReady: false, commentsAvailable: true, commentEmpty: false, commentPreview: 'preview' } };
  assert.equal(shows(view), true, 'native preview does not wait for Web mutation/image readiness');
  view.detail.commentsAvailable = false; view.detail.commentError = 'missing metadata';
  assert.equal(shows(view), true, 'retained text remains visible while metadata is unavailable');
  view.detail.commentError = ''; view.detail.commentPreview = ''; assert.equal(shows(view), false);
  view.detail.commentsAvailable = true; view.detail.commentEmpty = true; assert.equal(shows(view), false);
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const retryStart = index.indexOf('  private retryDetailPreview(): void');
  const retrySource = index.slice(retryStart, index.indexOf('\n  private ', retryStart + 1));
  const Retry = vm.runInNewContext(ts.transpileModule('class Retry {' + retrySource + '} Retry;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
    { PIN_NATIVE_DETAIL_READS_ENABLED: true });
  const previewRetry = new Retry(); let freshReads = 0;
  previewRetry.pinStore = { detail: {} }; previewRetry.detailNativeReads = { owned: () => true, retryPreview: () => false };
  previewRetry.retryDetailApi = () => freshReads++; previewRetry.retryDetailPreview();
  assert.equal(freshReads, 1, 'missing aggregate retry reacquires the verified base');
  previewRetry.detailNativeReads.retryPreview = () => true; previewRetry.retryDetailPreview();
  assert.equal(freshReads, 1, 'normal preview retry does not restart base');
  const relatedCard = page.slice(page.indexOf('private relatedCard('), page.indexOf('private relatedColumn('));
  assert(!relatedCard.includes('.enabled('), 'cached photographs must retain their colors while session actions prepare');
  const cardStart = page.indexOf('.stateEffect(((this.readsReady');
  const clickStart = page.indexOf('.onClick(() => {', cardStart) + '.onClick(() => {'.length;
  const clickBody = page.slice(clickStart, page.indexOf('})', clickStart));
  let navigations = 0;
  const card = { readsReady: true, actionsReady: false, deferredActions: false, detail: { kind: 'cached', relatedRetained: false },
    onRelated(id) { assert.equal(id, pinUrl(2)); navigations++; } };
  vm.runInNewContext('(function(){' + clickBody + '}).call(card)', { card, pin: { id: 'api:2', pinUrl: pinUrl(2) } });
  assert.equal(navigations, 1, 'native read readiness enables related navigation without mutation readiness');
  card.readsReady = false;
  vm.runInNewContext('(function(){' + clickBody + '}).call(card)', { card, pin: { id: 'api:2', pinUrl: pinUrl(2) } });
  assert.equal(navigations, 1, 'unconfirmed presentation remains gated');
  assert(page.includes('@Prop readsReady: boolean = false;'));
  const mediaBinding = page.slice(page.indexOf('PinmonyVideoPlayer({'), page.indexOf('readingAddress:', page.indexOf('PinmonyVideoPlayer({')));
  const readyExpression = mediaBinding.match(/sessionReady: ([^,]+),/)[1];
  const ownerExpression = mediaBinding.match(/mediaOwner: ([^,]+),/)[1];
  const mediaView = { actionsReady: false, readsReady: true, traceId: 7, detail: { pinUrl: 'https://www.pinterest.com/pin/1/', session: 0 } };
  const evaluate = expression => vm.runInNewContext('(function(){return ' + expression + ';}).call(view)', { view: mediaView });
  assert.equal(evaluate(readyExpression), true, 'validated native base starts media before the Web action context');
  const owner = evaluate(ownerExpression); mediaView.detail.session = 99; mediaView.actionsReady = true;
  assert.equal(evaluate(ownerExpression), owner, 'later Web confirmation does not replace the current player owner');
  mediaView.readsReady = false; mediaView.actionsReady = false;
  assert.equal(evaluate(readyExpression), false, 'unconfirmed cached media cannot play');
  mediaView.traceId++; assert.notEqual(evaluate(ownerExpression), owner, 'new detail opening invalidates the previous player');
  assert(page.includes('if ((this.actionsReady || this.readsReady) && !this.detail.relatedError && this.onLoadMore)'));
  console.log('Native detail reads: early read coalescing, validated publication, timeout/cancellation isolation, parallel preview, metadata, pagination, errors/retry passed');
  if (process.argv[3]) await checkCapturedTranslations(process.argv[3]);
}
const deadline = setTimeout(() => { console.error('Native detail reads did not settle'); process.exit(1); }, 10000);
main().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => clearTimeout(deadline));
