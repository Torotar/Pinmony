const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const flush = () => new Promise(resolve => setImmediate(resolve));
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
const requests = [], changes = [], timers = [], delays = [];
let finishMedia, failMedia;
const media = () => new Promise((resolve, reject) => { finishMedia = resolve; failMedia = reject; });
const window = { PinmonyDetailApiEnabled: true, PinmonyVideoApi: { resolve: media, nativeMode() {} } };
window.top = window;
vm.runInNewContext(script, { window, location: { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com' },
  AbortController, console, setTimeout(fn, delay) { timers.push(fn); delays.push(delay); return timers.length; },
  clearTimeout(id) { timers[id - 1] = null; }, fetch: (url, options) =>
    new Promise(resolve => requests.push({ url, options, resolve })) });
const pinUrl = 'https://www.pinterest.com/pin/101/';
const raw = { id: '101', type: 'pin', is_video: true, title: 'Base content', images: {
  '736x': { url: 'https://i.pinimg.com/poster.jpg', width: 736, height: 1100 } } };
const video = { pinId: '101', sources: [{ url: 'https://v1.pinimg.com/videos/example.m3u8', kind: 'hls' }] };
const api = window.PinmonyDetailApi;
const read = () => api.read(pinUrl, () => changes.push(true), () => true);
async function main() {
  read();
  requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: raw } }) });
  await flush();
  assert.equal(read().detail.title, 'Base content', 'slow media cannot withhold verified title/poster');
  assert.equal(read().mediaLoading, true); assert.equal(read().video, null); assert(changes.length);
  assert.equal(api.scheduleRelated(pinUrl), false, 'automatic related request is already in flight');
  assert.equal(api.loadMore(), false, 'scrolling cannot bypass stage order');
  assert.equal(api.settleImage(pinUrl, 'https://i.pinimg.com/wrong.jpg', 'loaded'), false);
  api.settleImage(pinUrl, raw.images['736x'].url, 'loaded');
  assert.equal(api.startRelated(pinUrl), false, 'verified detail related request is deduplicated');
  api.settleInteractions(pinUrl);
  api.scheduleRelated(pinUrl); api.scheduleRelated(pinUrl);
  assert.equal(timers.filter(Boolean).length, 2, 'media and recommendation request deadlines remain active');
  assert.equal(requests.length, 2, 'recommendations run alongside video resolution');
  requests[1].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: [], bookmark: '-end-' } }) });
  failMedia(new Error('synthetic failure')); await flush();
  assert.equal(read().mediaLoading, false); assert(read().videoError);
  assert.equal(read().detail.title, 'Base content', 'failed media retains base and independent recommendations');
  const count = requests.length;
  const retry = api.retryMedia(); await flush();
  assert.equal(retry, true, 'media retry returns synchronous acceptance');
  assert.equal(requests.length, count + 1, 'manual video retry fetches fresh PinResource only');
  requests.at(-1).resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: raw } }) }); await flush();
  finishMedia(video); await flush();
  assert.equal(read().video.pinId, '101'); assert.equal(read().videoError, '');
  const late = api.retryMedia(); await flush();
  requests.at(-1).resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: raw } }) }); await flush();
  api.reset(); finishMedia(video); await flush(); assert.equal(late, true);
  assert.equal(api.raw(pinUrl), null, 'late media cannot restore a closed Pin');
  assert.equal(requests.length, count + 2);
  // Explicit retry aborts the old base and refuses its late successful response.
  read(); const old = requests.at(-1);
  api.restart(pinUrl); const replacement = requests.at(-1);
  assert.notEqual(old, replacement); assert(old.options.signal.aborted);
  old.resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: { ...raw, title: 'Old' } } }) });
  await flush(); assert.equal(api.raw(pinUrl), null);
  replacement.resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: { ...raw, title: 'Replacement' } } }) });
  await flush(); assert.equal(read().detail.title, 'Replacement'); finishMedia(video); await flush(); api.reset();
  const dataSource = fs.readFileSync('feature_pin/src/main/ets/models/PinmonyRelatedDataSource.ets', 'utf8')
    .replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
  const ctx = {};
  vm.runInNewContext(ts.transpile(dataSource + '\nglobalThis.Source = PinmonyRelatedDataSource;',
    { target: ts.ScriptTarget.ES2021 }), ctx);
  const feed = new ctx.Source(), events = [];
  feed.registerDataChangeListener({ onDataAdd: index => events.push(index), onDataReloaded: () => events.push('reload') });
  const items = [{ id: 'a', title: 'first' }, { id: 'b', title: 'second' }];
  feed.update(items); events.length = 0;
  feed.update([...items, { id: 'c', title: 'third' }]);
  assert.deepEqual(events, [2], 'pagination appends without reloading mounted items');
  feed.update([...items, { id: 'c', title: 'third' }]); assert.deepEqual(events, [2]);
  feed.update([{ id: 'new', title: 'replacement' }]); assert.equal(events.at(-1), 'reload');
  console.log('Progressive detail: image/interaction gates, media-only retry, late reset and lazy append passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
