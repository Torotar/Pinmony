const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets', 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
let now = 1000;
const ctx = { Date: { now: () => now }, PinmonyRuntimeLog: { info() {} } };
vm.runInNewContext(ts.transpile(source + '\nglobalThis.Prefetch = PinmonyDetailPrefetch; globalThis.mapDetail = mapPrefetchedDetail;',
  { target: ts.ScriptTarget.ES2020 }), ctx);
const url = id => 'https://www.pinterest.com/pin/' + id + '/';
const pin = id => ({ id: String(id), type: 'pin', images: { '736x': { url: 'https://i.pinimg.com/736x/' + id + '.jpg', width: 736, height: 900 } },
  closeup_unified_title: 'Detail title', closeup_unified_description: 'Full description', pinner: { full_name: 'Creator', username: 'creator' } });
const body = data => JSON.stringify({ resource_response: { status: 'success', data } });
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const mapped = ctx.mapDetail(body(pin(1)), url(1));
  assert.equal(mapped.title, 'Detail title');
  assert.equal(mapped.description, 'Full description');
  assert.equal(mapped.creator, 'Creator');
  assert.equal(mapped.session, 0);
  assert.equal(mapped.actions.length, 0, 'preload cannot invent live operation IDs');
  assert.equal(ctx.mapDetail(body(pin(2)), url(1)), undefined, 'Pin identity must match');
  assert.equal(ctx.mapDetail(JSON.stringify({ resource_response: { status: 'failure', data: pin(1) } }), url(1)), undefined);
  assert.equal(ctx.mapDetail(body({ ...pin(1), carousel_data: { carousel_slots: [{}] } }), url(1)), undefined, 'a carousel cover is not full media');
  assert.equal(ctx.mapDetail(body({ ...pin(1), story_pin_data: { pages: [{}, {}] } }), url(1)), undefined);
  assert.equal(ctx.mapDetail(body({ ...pin(1), is_video: true }), url(1)), undefined, 'video without a confirmed source is not displayed as an image');
  const video = ctx.mapDetail(body({ ...pin(1), is_video: true, videos: { video_list: { V_HLSV4: {
    url: 'https://v1.pinimg.com/videos/sample.m3u8', width: 720, height: 1280, duration: 1000 } } } }), url(1));
  assert.equal(video.video.sources[0].kind, 'hls');
  assert.equal(ctx.mapDetail(body({ ...pin(1), is_video: true, videos: { video_list: { V_HLSV4: {
    url: 'https://v1.pinimg.com.evil.test/videos/sample.m3u8' } } } }), url(1)), undefined);
  const cache = new ctx.Prefetch();
  const requests = [], cancellations = [];
  let current = true;
  const read = (target, id) => new Promise((resolve, reject) => requests.push({ target, id, resolve, reject }));
  const offer = (ids, scope = 'session:home:all') => cache.offer(ids.map(url), scope, read, () => current, id => cancellations.push(id));
  offer([1, 2, 3, 4, 5, 6, 7]);
  assert.equal(requests.length, 2, 'only two reads run concurrently');
  const options = JSON.parse(new URL(requests[0].target).searchParams.get('data')).options;
  assert.equal(options.field_set_key, 'auth_web_main_pin');
  assert.equal(options.id, '1');
  requests[0].resolve(body(pin(1))); await flush();
  assert.equal(cache.get(url(1)).title, 'Detail title', 'content is ready before navigation');
  assert.equal(requests.length, 3, 'one completion admits one queued read');
  requests[1].reject(new Error('offline')); await flush();
  const requestCount = requests.length;
  offer([1, 2]);
  assert.equal(requests.length, requestCount, 'cache hits and failed speculative reads do not loop');
  cache.pause();
  assert.ok(cancellations.length >= 2, 'navigation stops pending reads');
  requests[2].resolve(body(pin(3))); await flush();
  assert.equal(cache.get(url(3)), undefined, 'cancelled responses cannot populate cache');
  assert.ok(cache.get(url(1)), 'pause preserves completed same-account content for opening');
  cache.remove(url(1));
  assert.equal(cache.get(url(1)), undefined, 'authoritative detail removes the speculative copy before later edits');
  current = true;
  offer([1], 'session:home:again');
  requests[requests.length - 1].resolve(body(pin(1))); await flush();
  assert.ok(cache.get(url(1)));
  now += 120001;
  assert.equal(cache.get(url(1)), undefined, 'preloaded content expires');
  offer([4, 5], 'session:home:board');
  const latest = requests[requests.length - 1];
  current = false;
  latest.resolve(body(pin(5))); await flush();
  assert.equal(cache.get(url(5)), undefined, 'invalid page or category cannot update content');
  cache.clear();
  assert.equal(cache.get(url(1)), undefined, 'authentication reset clears completed content');
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const method = index.match(/  private restoreCachedDetail\(pinUrl: string\): boolean \{[\s\S]*?(?=\r?\n  private saveDetailScrollPosition)/)[0];
  const nativeCtx = { PIN_DETAIL_API_ENABLED: true, PinmonyRuntimeLog: { info() {} } };
  vm.runInNewContext(ts.transpile('class Native { ' + method + ' } globalThis.Native = Native;', { target: ts.ScriptTarget.ES2020 }), nativeCtx);
  const native = new nativeCtx.Native();
  Object.assign(native, { pinIdentity: value => value, pinStore: { detailImageFailedPin: '', detailCache: { get() {} },
    detailPrefetch: { get: () => mapped }, confirmedSaves: { apply: (_id, detail) => detail } } });
  assert.equal(native.restoreCachedDetail(url(1)), true);
  assert.equal(native.pinStore.detail.title, 'Detail title');
  assert.equal(native.pinStore.detailActionsReady, false, 'preloaded content does not enable stale controls');
  assert.match(index, /onPrefetchPins:.*prefetchHomePinDetails/);
  console.log('Detail prefetch: identity/media validation, bounded queue, expiry, cancellation, stale responses and immediate opening passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
