const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinWebPostApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
const extensionSource = fs.readFileSync('feature_pin/src/main/ets/services/PinWebPostExtensionsScript.ets', 'utf8');
const extension = Function('return `' + extensionSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
const pin = 'https://www.pinterest.com/pin/101/';
const handler = 'www/pin/[id].js';
function harness() {
  const requests = [], timers = new Map(); let nextTimer = 0;
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/pin/101/', href: pin };
  const document = { cookie: '', getElementById: () => null, querySelectorAll: () => [] };
  class XHR { open() {} send() {} setRequestHeader() {} addEventListener() {} }
  const window = { PinWebPostApiEnabled: true, PinWebPostExtensionsEnabled: true,
    PinWebDetailApi: { raw: () => ({ id: '101', aggregated_pin_id: '202' }) } };
  window.top = window;
  window.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }));
  const context = vm.createContext({ window, document, location, URL, URLSearchParams, Headers, AbortController,
    XMLHttpRequest: XHR, fetch: (...args) => window.fetch(...args),
    setTimeout(fn, delay) { const id = ++nextTimer; timers.set(id, { fn, delay }); return id; },
    clearTimeout(id) { timers.delete(id); } });
  vm.runInContext(script, context); vm.runInContext(extension, context);
  function metadata({ origin = location.origin, id = '101', version = 'synthetic-current', route = handler } = {}) {
    const xhr = new XHR();
    xhr.open('GET', origin + '/resource/PinResource/get/?source_url=' + encodeURIComponent('/pin/' + id + '/'));
    xhr.setRequestHeader('X-App-Version', version);
    xhr.setRequestHeader('X-Pinterest-Pws-Handler', route);
    xhr.send();
  }
  async function tick() {
    const entry = [...timers.entries()].find(([, timer]) => timer.delay === 50);
    assert(entry, 'metadata wait must be bounded by a short cancellable poll');
    timers.delete(entry[0]); entry[1].fn(); await flush();
  }
  const api = window.PinWebPostApi;
  const preview = valid => api.resourceRequest(pin, 'UnifiedCommentsPreviewResource', 'get',
    { aggregated_pin_id: '202' }, valid || (() => true));
  const reply = (index, status = 200) => requests[index].resolve({ ok: status === 200, status,
    json: async () => { if (status !== 200) throw new Error('not-json');
      return { resource_response: { status: 'success', code: 0, data: [] } }; } });
  return { requests, timers, location, document, window, api, metadata, tick, preview, reply };
}
async function main() {
  const delayed = harness();
  const pending = delayed.preview();
  assert.equal(delayed.requests.length, 0, 'missing metadata must not send a partial preview request');
  delayed.metadata({ route: 'www/index.js' }); await delayed.tick();
  assert.equal(delayed.requests.length, 0, 'an index handler cannot bind a Pin preview');
  delayed.metadata({ id: '999' }); await delayed.tick();
  assert.equal(delayed.requests.length, 0, 'a previous Pin handler cannot bind the current read');
  delayed.metadata(); await delayed.tick();
  assert.equal(delayed.requests.length, 1);
  const request = delayed.requests[0];
  assert.equal(request.options.headers['X-App-Version'], 'synthetic-current');
  assert.equal(request.options.headers['X-Pinterest-Pws-Handler'], handler);
  assert.equal(Object.keys(request.options.headers).length, 6);
  assert.equal(request.options.headers.Cookie, undefined);
  assert.equal(request.options.credentials, 'same-origin');
  delayed.reply(0); await pending;
  assert.equal(delayed.timers.size, 0);

  const viaFetch = harness();
  const fetchWait = viaFetch.preview();
  viaFetch.window.fetch('/resource/PinResource/get/?source_url=%2Fpin%2F101%2F', {
    headers: { 'X-App-Version': 'synthetic-fetch', 'X-Pinterest-Pws-Handler': handler } });
  await viaFetch.tick();
  assert.equal(viaFetch.requests.length, 2, 'fetch metadata releases only the one pending preview');
  assert.equal(viaFetch.requests[1].options.headers['X-App-Version'], 'synthetic-fetch');
  viaFetch.reply(0); viaFetch.reply(1); await fetchWait;
  viaFetch.window.fetch('/resource/ShareSuggestionsResource/get/?source_url=%2Fpin%2F101%2F', {
    headers: { 'X-Pinterest-Pws-Handler': 'www/index.js', 'X-App-Version': 'invalid/version' } });
  const isolated = viaFetch.preview();
  assert.equal(viaFetch.requests[3].options.headers['X-Pinterest-Pws-Handler'], handler,
    'later generic share headers cannot replace the confirmed detail-read handler');
  assert.equal(viaFetch.requests[3].options.headers['X-App-Version'], 'synthetic-fetch',
    'invalid captured versions cannot replace the validated current-document version');
  viaFetch.reply(2); viaFetch.reply(3); await isolated;

  const ready = harness(); ready.metadata();
  const immediate = ready.preview();
  assert.equal(ready.requests.length, 1, 'ready metadata introduces no extra timer');
  ready.reply(0, 403); await assert.rejects(immediate, /HTTP 403/);
  assert.equal(ready.requests.length, 1, '403 does not automatically replay the request');

  const stale = harness();
  const old = stale.preview().catch(error => error);
  stale.api.reset(); stale.metadata(); await stale.tick();
  assert.match((await old).message, /stale/);
  assert.equal(stale.requests.length, 0, 'reset invalidates a pending metadata wait');

  const moved = harness();
  const movedRead = moved.preview().catch(error => error);
  moved.location.href = pin + '?changed=1'; moved.metadata(); await moved.tick();
  assert.match((await movedRead).message, /stale/);
  assert.equal(moved.requests.length, 0, 'full-page changes invalidate the wait even for the same Pin');

  const cancelled = harness(); let current = true;
  const cancelledRead = cancelled.preview(() => current).catch(error => error);
  current = false; cancelled.metadata(); await cancelled.tick();
  assert.match((await cancelledRead).message, /stale/); assert.equal(cancelled.requests.length, 0);

  const absent = harness();
  const unavailable = absent.preview().catch(error => error);
  absent.metadata({ origin: 'https://example.com' });
  for (let i = 0; i < 160; i++) await absent.tick();
  assert.match((await unavailable).message, /请求信息尚未就绪/);
  assert.equal(absent.requests.length, 0, 'timeout and foreign-origin metadata cannot create a request');
  assert.equal(absent.timers.size, 0);

  const fromProps = harness();
  fromProps.document.getElementById = () => ({ textContent: JSON.stringify({ client_context: { app_version: 'synthetic-props' } }) });
  fromProps.metadata({ version: 'invalid/version' });
  const propsRead = fromProps.preview();
  assert.equal(fromProps.requests[0].options.headers['X-App-Version'], 'synthetic-props');
  fromProps.reply(0); await propsRead;
  const retry = harness(); retry.metadata();
  retry.api.previewRead(pin); retry.reply(0, 403); await flush();
  assert(retry.api.previewRead(pin, true).error);
  assert.equal(retry.api.previewRetry(pin), true);
  assert.equal(retry.api.previewRetry(pin), false, 'double retry cannot duplicate a preview read');
  assert.equal(retry.requests.length, 2);
  assert(retry.requests.every(item => /UnifiedCommentsPreviewResource/.test(item.url)),
    'preview-only retry does not fetch base content or recommendations');
  retry.reply(1); await flush();
  assert.equal(retry.api.previewRead(pin, true).error, '');
  assert.equal(retry.api.previewRead(pin, true).loading, false);
  assert.equal(retry.api.previewRetry(pin), false, 'a confirmed empty preview is not an error');
  console.log('Detail metadata: immediate/delayed fetch and XHR, scoped handler, timeout, cancellation, no 403 replay and preview-only retry passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
