const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyVisualSearchApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', href: 'https://www.pinterest.com/pin/123/', pathname: '/pin/123/' };
const window = {}; window.top = window;
const jobs = [];
vm.runInNewContext(script, { window, location, AbortController, setTimeout, clearTimeout, Set,
  fetch: (url, init) => new Promise(resolve => jobs.push({url, init, resolve})) });
const api = window.PinmonyVisualSearchApi;
const crop = {x: .1, y: .1, w: .8, h: .8};
const pin = id => ({type: 'pin', id, images: {'736x': {url: 'https://i.pinimg.com/synthetic.jpg', width: 736, height: 1000}}});
const flush = () => new Promise(resolve => setImmediate(resolve));
async function reply(i, results, bookmark = '-end-', overrides = {}) {
  jobs[i].resolve({ok: true, json: async () => ({resource_response: {
    status: 'success', code: 0, endpoint_name: 'v3_unified_flashlight_handler', data: {results}, bookmark, ...overrides}})});
  await flush();
}
(async () => {
  assert.equal(api.start(location.href, {...crop, w: 1}, false, true), false);
  assert.equal(api.start(location.href, crop, false, true), true);
  const req = new URL(jobs[0].url, location.origin);
  assert.equal(jobs[0].init.headers['X-Pinterest-Pws-Handler'], 'www/pin/[id]/visual-search.js');
  assert.equal(jobs[0].init.credentials, 'same-origin');
  assert.equal(jobs[0].init.headers.Cookie, undefined);
  assert(req.searchParams.get('source_url').includes('/visual-search/?cropSource=5'));
  assert.equal(JSON.parse(req.searchParams.get('data')).options.bookmarks, undefined);
  await reply(0, [pin('1'), {type: 'story', title: 'shopping'}, pin('1')], 'synthetic-cursor');
  assert.equal(api.read(location.href).items.length, 1);
  assert.equal(api.start(location.href, crop, true, false), true);
  assert.equal(JSON.parse(new URL(jobs[1].url, location.origin).searchParams.get('data')).options.bookmarks[0], 'synthetic-cursor');
  await reply(1, [pin('1'), pin('2')]);
  assert.equal(api.read(location.href).items.length, 2);
  assert.equal(api.read(location.href).ended, true);
  assert.equal(api.start(location.href, crop, true, false), false);
  api.start(location.href, crop, false, false);
  api.start(location.href, {...crop, w:.4}, false, false);
  assert(jobs[2].init.signal.aborted);
  await reply(3, [pin('3')]); await reply(2, [pin('4')]);
  assert.equal(api.read(location.href).items[0].id, 'api:3');
  api.start(location.href, crop, false, false);
  await reply(4, [], '-end-', {status:'failure'});
  assert(api.read(location.href).error); assert(!api.read(location.href).loading);
  api.start(location.href, crop, false, false);
  location.href += '?changed';
  await reply(5, [pin('5')]); assert.equal(api.read('https://www.pinterest.com/pin/123/'), null);
  api.close(); assert(jobs[5].init.signal.aborted);
  console.log('visual search: contract, crop bounds, mixed results, deduplication, pagination, cancellation, stale responses and business failure OK');
})().catch(e => { console.error(e); process.exitCode = 1; });
