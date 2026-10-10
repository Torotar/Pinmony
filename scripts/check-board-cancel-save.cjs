const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('feature_board/src/main/ets/services/PinmonyBoardApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
async function harness(copy) {
  const requests = [], messages = [], writes = [];
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/u/b/' };
  const window = { PinmonyBoardApiEnabled: true, top: null, addEventListener() {}, setInterval() {},
    PinmonyShareBridge: { boardState: value => messages.push(JSON.parse(value)) },
    PinmonyPostApi: { resourceRequest: (pin, name, verb, options, current) => {
      writes.push({ pin, name, verb, options, current });
      return new Promise(resolve => { writes.at(-1).resolve = resolve; });
    } } }; window.top = window;
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout,
    document: { readyState: 'complete' }, fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })) });
  requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data:
    { type: 'board', id: '123', url: '/u/b/', owner: { id: '700', username: 'u' }, name: 'B', pin_count: 1 } }, client_context: { user: { id: '700' } } }) });
  await flush();
  requests[1].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', bookmark: '-end-', data:
    [{ type: 'pin', id: '111', board: { id: '123' }, images: { '474x': { url: 'https://i.pinimg.com/a.jpg', width: 474, height: 700 } } }] } }) });
  await flush();
  const api = window.PinmonyBoardApi, state = messages.at(-1), page = state.pageKey, pin = location.origin + '/pin/111/';
  assert.equal(api.cancelPinStart(state.session, page, '999'), false);
  assert.equal(api.cancelPinStart(state.session, page, '111'), true);
  assert.equal(api.cancelPinStart(state.session, page, '111'), false, 'duplicate request blocked');
  writes[0].resolve({ data: copy }); await flush();
  return { api, state, page, pin, writes, messages, location };
}
(async () => {
  const copy = { id: '111', is_repin: true, pinner: { id: '700' }, board: { id: '123' } };
  const h = await harness(copy);
  assert.equal(h.writes[1].verb, 'delete'); assert.equal(h.writes[1].options.id, '111');
  assert.equal(h.messages.at(-1).pins.length, 1, 'card remains until server confirms');
  h.writes[1].resolve({ code: 0, endpoint_name: 'v3_delete_pin_handler' }); await flush();
  assert.equal(h.api.cancelPinRead(h.state.session, h.page, h.pin).feedback, '已取消收藏');
  assert.equal(h.messages.at(-1).pins.length, 1, 'confirmed cancellation retains visible card until board exit');
  assert.equal(h.messages.at(-1).pinCount, '1 张 Pin 图');
  for (const bad of [{ ...copy, is_repin: false }, { ...copy, pinner: { id: '999' } }, { ...copy, board: { id: '999' } }]) {
    const b = await harness(bad); assert.equal(b.writes.length, 1, 'unverified copy cannot be deleted');
    assert.equal(b.messages.at(-1).pins.length, 1);
  }
  const rejected = await harness(copy);
  rejected.writes[1].resolve({ code: 1, endpoint_name: 'v3_delete_pin_handler' }); await flush();
  assert.match(rejected.api.cancelPinRead(rejected.state.session, rejected.page, rejected.pin).error, /结果未确认/);
  assert.equal(rejected.messages.at(-1).pins.length, 1);
  assert.equal(rejected.api.cancelPinStart(rejected.state.session, rejected.page, '111'), false);
  const stale = await harness(copy); stale.location.pathname = '/u/other/';
  stale.writes[1].resolve({ code: 0, endpoint_name: 'v3_delete_pin_handler' }); await flush();
  assert.equal(stale.api.cancelPinRead(stale.state.session, stale.page, stale.pin), null);
  console.log('Board cancel save: ownership/board/repin, duplicate lock, confirmed deletion, uncertain result and stale route passed');
})().catch(e => { console.error(e); process.exitCode = 1; });
