const { readSourceFileSync } = require('./source-files.cjs');
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const script = name => Function('return `' + readSourceFileSync('entry/src/main/ets/services/' + name + '.ets', 'utf8').match(/= `([\s\S]*?)`;/)[1] + '`')();
const image = { url: 'https://i.pinimg.com/736x/sample.jpg', width: 736, height: 1308 };
const graph = id => ({ entityId: id, carouselData: { carouselSlots: Array.from({ length: 7 }, (_, n) => ({ slotId: String(n + 1), images_736x: image })) } });
function harness() {
  let cache = []; const requests = []; const window = { PinmonyCarouselApiEnabled: true }; window.top = window;
  vm.runInNewContext(script('PinmonyCarouselApiScript'), { window, URL,
    document: { cookie: 'csrftoken=current', querySelectorAll: () => cache },
    fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
  return { api: window.PinmonyCarouselApi, requests, cache: pin => {
    cache = [{ textContent: '__PWS_RELAY_REGISTER_COMPLETED_REQUEST__("x",' + JSON.stringify({ data: { v3GetPinQueryv2: { data: pin } } }) + ');' }];
  } };
}
async function main() {
  const h = harness(); h.cache(graph('123'));
  const resolve = (instance, pin, current = () => true) => instance.api.resolve(pin, '123', new AbortController().signal, current);
  const mapped = await resolve(h, { id: '123' });
  assert.equal(mapped.items.length, 7); assert.equal(mapped.items[6].id, '7'); assert.equal(h.requests.length, 0);
  assert.equal(h.api.detect({ id: '123' }, '123'), true);
  const other = harness(); other.cache(graph('999'));
  const request = resolve(other, { id: '123', carousel_data: { id: '1' } });
  assert.equal(other.requests.length, 1);
  assert.equal(JSON.parse(other.requests[0].args.body).variables.pinId, '123');
  assert.equal(other.requests[0].args.credentials, 'same-origin');
  other.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: graph('123') } } }) });
  assert.equal((await request).items[0].imageUrl, image.url);
  const stale = harness(); let current = true; const pending = resolve(stale, { id: '123' }, () => current); current = false;
  stale.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: graph('123') } } }) });
  await assert.rejects(pending, /stale/);
  const invalid = harness(); const bad = graph('123'); bad.carouselData.carouselSlots[0].images_736x = { ...image, url: 'https://other.test/a.jpg' };
  invalid.cache(bad); const failed = resolve(invalid, { id: '123' });
  invalid.requests[0].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: bad } } }) });
  await assert.rejects(failed, /carousel-source-missing/);
  console.log('Carousel API: ordered seven images, cache, current-session fetch, unsafe source and stale response guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
