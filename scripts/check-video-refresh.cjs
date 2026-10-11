const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts);
const detailScript = loader.loadFile('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets').PIN_DETAIL_API_SCRIPT;
const videoScript = loader.loadFile('feature_pin/src/main/ets/services/PinmonyVideoApiScript.ets').PIN_VIDEO_API_SCRIPT;
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = index.indexOf('  private async retryDetailMedia(');
const method = index.slice(start, index.indexOf('\n  private ', start + 1));
const nativeCode = ts.transpileModule('class Native {' + method + '} Native;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
const pin = 'https://www.pinterest.com/pin/123/';
const source = label => ({ V_HLSV4: { url: 'https://v1.pinimg.com/videos/' + label + '.m3u8' }, V_720P: { url: 'https://v1.pinimg.com/videos/' + label + '.mp4' } });
const raw = label => ({ type: 'pin', id: '123', title: label, is_video: true, videos: { video_list: source(label) },
  images: { '736x': { url: 'https://i.pinimg.com/poster.jpg', width: 736, height: 1000 } } });
const flush = () => new Promise(resolve => setImmediate(resolve));
async function harness(encoded = false) {
  let now = 1000, nextTimer = 0, active = true;
  const timers = new Map(), requests = [], traces = [], notices = [], nativeTraces = [], bridgeCalls = [];
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/pin/123/', href: pin };
  const time = { setTimeout(fn, ms) { const id = ++nextTimer; timers.set(id, { at: now + ms, fn }); return id; }, clearTimeout(id) { timers.delete(id); } };
  const window = { PinmonyVideoApiEnabled: true, PinmonyDetailApiEnabled: true }; window.top = window;
  window.fetch = (url, args) => new Promise((resolve, reject) => requests.push({ url, args, resolve, reject }));
  const doc = { cookie: 'csrftoken=synthetic-test-only', addEventListener() {}, querySelectorAll: () => [] };
  const ctx = vm.createContext({ window, location, document: doc, URL, AbortController, Date: { now: () => now }, ...time,
    console: { info: msg => traces.push(msg), warn() {} }, fetch: (...args) => window.fetch(...args) });
  vm.runInContext(videoScript, ctx); vm.runInContext(detailScript, ctx);
  const Native = require('./product-coordination-harness.cjs').run(ts,nativeCode, { ...time, Date: { now: () => now }, PinmonyRuntimeLog: { info() {} } });
  const native = new Native();
  Object.assign(native, { authEpoch: 1, authStatus: 'authenticated', businessSuspended: false,
    pinStore: { detailMediaRetryBusy: false, detailMediaRetryToken: 0, detailPresentationOnly: false,
      detailSession: 2, detailOpeningToken: 7, detailActionsReady: true },
    pinIdentity: p => p.match(/\/pin\/(\d+)/)?.[1] || '', currentPinUrl: () => location.href,
    rejectOfflineAction: () => false, ensureDetailActionContext: async () => true,
    detailJourney: { mark: msg => nativeTraces.push(msg) }, showMessage: msg => notices.push(msg),
    webJsonText: value => { const parsed = JSON.parse(value); return typeof parsed === 'string' ? parsed : value; },
    controller: { runJavaScript: async script => {
      bridgeCalls.push(script); const result = vm.runInContext(script, ctx);
      const text = result && typeof result.then === 'function' ? '{}' : String(result);
      return encoded ? JSON.stringify(text) : text;
    } } });
  require('./pin-priority-controller-harness.cjs').bind(native, ts, { ...time, Date: { now: () => now } });
  const api = window.PinmonyDetailApi;
  const read = () => api.read(pin, update, () => active);
  function update() { const value = read(); native.pinStore.detail = { pinUrl: pin, ...value.detail,
    video: value.video, isVideo: value.isVideo, mediaLoading: value.mediaLoading, videoError: value.videoError }; }
  function respond(i, data, status = 'success') { requests[i].resolve({ ok: true, json: async () => ({ resource_response: { status, code: 0, data } }) }); }
  update(); respond(0, raw('old')); await flush(); respond(1, []); await flush();
  async function tick(ms = 200) {
    now += ms;
    for (const [id, timer] of Array.from(timers)) if (timer.at <= now) { timers.delete(id); timer.fn(); }
    await flush();
  }
  const refresh = () => native.retryDetailMedia();
  return { native, api, read, refresh, respond, requests, traces, notices, nativeTraces, bridgeCalls, location, tick,
    invalidate: () => { active = false; native.pinStore.detailSession++; } };
}
async function success(encoded) {
  const h = await harness(encoded), original = h.read().video;
  const pending = h.refresh(); await flush();
  assert.equal(h.requests.length, 3, 'one click fetches fresh PinResource');
  assert(h.requests[2].url.includes('/resource/PinResource/get/'));
  assert.equal(h.requests[2].args.credentials, 'same-origin');
  const options = JSON.parse(new URLSearchParams(new URL(h.requests[2].url, pin).search).get('data')).options;
  assert.equal(options.noCache, true); assert.equal(options.id, '123');
  assert.equal(h.read().mediaLoading, true); assert.equal(h.read().video, original, 'existing media is retained during refresh');
  await h.refresh(); assert.equal(h.requests.length, 3, 'duplicate native click is suppressed');
  assert.equal(h.api.retryMedia(pin, 999), false, 'duplicate page read is suppressed');
  assert.equal(h.native.pinStore.detailMediaRetryBusy, true);
  h.respond(2, raw('new')); await flush(); await h.tick(); await pending;
  assert(h.read().video.sources[0].url.includes('/new.m3u8')); assert.equal(h.read().video.readRevision, 1);
  assert.equal(h.read().detail.title, 'old', 'media reread does not replace visible base content');
  assert.equal(h.requests.length, 3, 'no comments or recommendations are reread');
  assert.equal(h.native.pinStore.detailMediaRetryBusy, false); assert.equal(h.notices.length, 0);
  assert(h.nativeTraces.includes('video.address.read.confirmed'));
  const same = h.refresh(); await flush(); h.respond(3, raw('new')); await flush(); await h.tick(); await same;
  assert.equal(h.read().video.readRevision, 2, 'fresh success with unchanged URLs still rebuilds the player');
  assert(h.traces.includes('PinmonyDiagnostic: video.refresh.address.ready changed=false'));
  assert(h.traces.every(msg => !msg.includes('https:') && !msg.includes('synthetic-test-only')), 'diagnostics do not contain URLs or credentials');
}
async function main() {
  await success(false); await success(true);
  const invalid = await harness(), original = invalid.read().video, failed = invalid.refresh(); await flush();
  invalid.respond(2, { ...raw('wrong'), id: '999' }); await flush(); await invalid.tick(); await failed;
  assert.equal(invalid.read().video, original); assert.equal(invalid.read().video.readRevision, 0);
  assert(invalid.read().videoError); assert.equal(invalid.read().mediaLoading, false);
  const retry = invalid.refresh(); await flush(); invalid.respond(3, raw('correct')); await flush(); await invalid.tick(); await retry;
  assert.equal(invalid.read().video.readRevision, 1, 'failed reads do not advance playback revision');
  const graph = await harness(), graphRead = graph.refresh(); await flush();
  graph.respond(2, { ...raw('missing'), videos: null }); await flush();
  assert.equal(graph.requests.length, 4); assert.equal(graph.requests[3].url, '/_/graphql/');
  graph.requests[3].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: { entityId: '123', videos: { videoList: {
    vHLSV4: { url: 'https://v1.pinimg.com/videos/fresh-graph.m3u8' } } } } } } }) });
  await flush(); await graph.tick(); await graphRead; assert(graph.read().video.sources[0].url.includes('fresh-graph'));
  const timeout = await harness(), timed = timeout.refresh(); await flush();
  await timeout.tick(15000); await timeout.tick(); await timed;
  assert.equal(timeout.read().mediaLoading, false); assert(timeout.read().videoError.includes('超时'));
  assert.equal(timeout.requests[2].args.signal.aborted, true);
  timeout.respond(2, raw('late')); await flush(); assert.equal(timeout.read().video.readRevision, 0);
  for (const change of ['reset', 'page', 'account', 'foreground']) {
    const h = await harness(), old = h.refresh(); await flush(); const before = h.read().video;
    if (change === 'reset') { h.api.reset(); h.invalidate(); }
    if (change === 'page') { h.location.href = pin + '?changed=true'; h.invalidate(); }
    if (change === 'account') { h.native.authEpoch++; h.invalidate(); }
    if (change === 'foreground') { h.native.businessSuspended = true; h.invalidate(); }
    h.respond(2, raw('late')); await flush(); await h.tick(); await old;
    assert(!h.nativeTraces.includes('video.address.read.confirmed'), change + ' rejects late completion');
    assert.equal(h.notices.length, 0, change + ' does not notify the new screen');
    if (change !== 'reset') assert.equal(h.read().video, before);
  }
  console.log('Video refresh: real fresh resource, synchronous bridge acceptance, duplicate lock, media-only update, fresh GraphQL, same-URL revision, failures/timeouts and stale guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
