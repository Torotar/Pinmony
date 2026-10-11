const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = name => Function('return `' + readSourceFileSync('entry/src/main/ets/services/' + name + '.ets', 'utf8').match(/= `([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
const hls = 'https://v1.pinimg.com/videos/iht/hls/sample.m3u8';
const mp4 = 'https://v1.pinimg.com/videos/iht/expMp4/sample_720w.mp4';
const graph = id => ({ entityId: id, videos: { videoList: { vHLSV4: { url: hls, width: 720, height: 1280, duration: 4600 }, v720P: { url: mp4, width: 720, height: 1280, duration: 4600 } } } });
function harness() {
  const requests = [], events = {}, traces = [], window = { PinmonyVideoApiEnabled: true, PinmonyDetailApiEnabled: true }; window.top = window;
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/pin/123/' };
  let current = true, cached = [];
  vm.runInNewContext(script('PinmonyVideoApiScript'), { window, location, URL, console: { info: event => traces.push(event) },
    document: { cookie: 'csrftoken=runtime', addEventListener: (name, callback) => events[name] = callback,
      querySelectorAll: selector => selector.startsWith('script') ? cached : [] },
    fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
  const api = window.PinmonyVideoApi;
  const resolve = (pin = { id: '123' }) => api.resolve(pin, '123', new AbortController().signal, () => current);
  return { api, resolve, requests, location, events, window, traces, cache: pin => { cached = [{ textContent: 'window.__PWS_RELAY_REGISTER_COMPLETED_REQUEST__("x",' + JSON.stringify({ data: { v3GetPinQueryv2: { data: pin } } }) + ');' }]; }, invalidate: () => current = false };
}
async function main() {
  const direct = harness();
  const source = await direct.resolve({ id: '123', videos: { video_list: { V_HLSV4: { url: hls }, V_720P: { url: mp4 } } } });
  assert.equal(source.sources[0].kind, 'hls'); assert.equal(source.sources[1].kind, 'mp4'); assert.equal(direct.requests.length, 0);
  assert(direct.traces.some(event => event.endsWith('source=resource')));
  assert(direct.traces.every(event => !event.includes('https:') && !event.includes('csrftoken')), 'source diagnostics stay sanitized');
  assert.equal(direct.api.detect({ id: '123', videos: { video_list: {} } }, '123'), false, 'empty video metadata must not classify an image as video');
  assert.equal(direct.api.detect({ id: '123', videos: { video_list: { V_720P: { url: mp4 } } } }, '123'), true, 'real video source does not require is_video flag');
  assert.equal(direct.api.detect({ id: '123', videos: null }, '123'), false);
  const cached = harness(); cached.cache(graph('123'));
  assert.equal((await cached.resolve()).duration, 4600); assert.equal(cached.requests.length, 0);
  assert.equal(cached.api.detect({ id: '123', is_video: false }, '123'), true, 'matching Relay source identifies saved video');
  assert.equal(cached.api.detect({ id: '999' }, '999'), false, 'another Pin cache cannot classify this Pin');
  const fetched = harness(); fetched.cache(graph('999')); const result = fetched.resolve();
  assert.equal(fetched.requests.length, 1, 'cached other Pin cannot supply playback URL');
  assert.equal(JSON.parse(fetched.requests[0].args.body).variables.pinId, '123');
  assert.equal(fetched.requests[0].args.credentials, 'same-origin'); assert.equal(fetched.requests[0].args.headers['X-CSRFToken'], 'runtime');
  fetched.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: graph('123') } } }) });
  assert.equal((await result).pinId, '123');
  assert(fetched.traces.some(event => event.endsWith('source=graphql')));
  const freshOnly = harness(); freshOnly.cache(graph('123'));
  const freshRead = freshOnly.api.resolve({ id: '123' }, '123', new AbortController().signal, () => true, true);
  assert.equal(freshOnly.requests.length, 1, 'manual refresh skips matching old Relay metadata');
  freshOnly.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: graph('123') } } }) });
  await freshRead; assert(freshOnly.traces.some(event => event.endsWith('source=graphql')));
  const invalid = harness(); const bad = invalid.resolve();
  invalid.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: graph('999') } } }) });
  await assert.rejects(bad, /video-source-missing/);
  const unsafe = harness(); const noSource = unsafe.resolve({ id: '123', videos: { video_list: { V_HLSV4: { url: 'https://attacker.test/videos/a.m3u8' } } } });
  unsafe.requests[0].resolve({ ok: false }); await assert.rejects(noSource);
  const late = harness(); const old = late.resolve(); late.invalidate();
  late.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: graph('123') } } }) });
  await assert.rejects(old, /stale/);
  let pauses = 0; const siteVideo = { tagName: 'VIDEO', closest: () => true, pause: () => pauses++ };
  fetched.api.nativeMode('123', true); fetched.events.play({ target: siteVideo }); assert.equal(pauses, 1);
  fetched.location.pathname = '/'; fetched.events.play({ target: siteVideo }); assert.equal(pauses, 1, 'website suppression is confined to the current native Pin page');
  fetched.api.nativeMode('123', false); fetched.location.pathname = '/pin/123/'; fetched.events.play({ target: siteVideo }); assert.equal(pauses, 1);
  // Exercise actual detail loading with video resolver enabled; legacy tests cover the disabled switch.
  const requests = [], window = { PinmonyDetailApiEnabled: true, PinmonyVideoApi: { resolve: async () => source, nativeMode() {} } }; window.top = window;
  vm.runInNewContext(script('PinmonyDetailApiScript'), { window, location: { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com' },
    URL, AbortController, setTimeout, clearTimeout, console, fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
  const read = () => window.PinmonyDetailApi.read('https://www.pinterest.com/pin/123/', () => {}, () => true);
  const release = () => { window.PinmonyDetailApi.settleImage('https://www.pinterest.com/pin/123/', read().image.url, 'loaded');
    window.PinmonyDetailApi.settleInteractions('https://www.pinterest.com/pin/123/'); };
  read();
  requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: { id: '123', type: 'pin', is_video: true, images: { '474x': { url: 'https://i.pinimg.com/cover.jpg', width: 474, height: 800 } } } } }) });
  await flush(); release(); window.PinmonyDetailApi.startRelated('https://www.pinterest.com/pin/123/');
  requests[1].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: [] } }) }); await flush();
  assert.equal(read().mediaUnsupported, false); assert.equal(read().detail.is_video, true); assert.equal(read().video.sources.length, 2);
  assert.equal(read().isVideo, true);
  assert.equal(read().video.readRevision, 0);
  const beforeRetryRequests = requests.length;
  assert.equal(window.PinmonyDetailApi.retryMedia(), true, 'native acceptance is synchronous');
  assert.equal(requests.length, beforeRetryRequests + 1, 'manual video reread requests fresh PinResource');
  assert.equal(read().mediaLoading, true);
  requests[beforeRetryRequests].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0,
    data: { id: '123', type: 'pin', is_video: true } } }) }); await flush();
  assert.equal(read().video.readRevision, 1, 'manual media reread advances revision even with identical URLs');
  assert.equal(requests.length, beforeRetryRequests + 1, 'video reread does not request recommendations');
  window.PinmonyDetailApi.reset(); read();
  requests[3].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: { id: '123', type: 'pin',
    videos: { video_list: { V_HLSV4: { url: hls } } }, images: { '474x': { url: 'https://i.pinimg.com/cover.jpg', width: 474, height: 800 } } } } }) });
  await flush(); release(); window.PinmonyDetailApi.startRelated('https://www.pinterest.com/pin/123/');
  requests[4].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: [] } }) }); await flush();
  assert.equal(read().isVideo, true, 'missing boolean flag still produces native video state');
  assert.equal(read().video.sources[0].kind, 'hls');
  console.log('Video API: current Pin sources, GraphQL/cache, safe URLs, stale guards and native detail integration passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
