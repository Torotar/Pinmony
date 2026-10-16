const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyBoardApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
new Function(script);
const flush = () => new Promise(resolve => setImmediate(resolve));
const board = { type: 'board', id: '123', url: '/sample/board/', name: 'Board', pin_count: 2,
  owner: { id: '700', username: 'sample', full_name: 'Sample', image_medium_url: 'https://i.pinimg.com/avatar.jpg' } };
const pin = id => ({ type: 'pin', id, board: { id: '123' }, title: '', images: {
  '474x': { url: 'https://i.pinimg.com/' + id + '.jpg', width: 474, height: 700 } } });
function harness(pathname = '/sample/board/', readyState = 'complete') {
  const requests = [], messages = [];
  let tick;
  const window = { PinmonyBoardApiEnabled: true, addEventListener() {}, setInterval(fn) { tick = fn; },
    PinmonyShareBridge: { boardState(value) { messages.push(JSON.parse(value)); } } };
  window.top = window;
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname };
  const document = { readyState, getElementById() { throw new Error('DOM initial context must not be read'); } };
  const fetch = (url, options) => new Promise((resolve, reject) => {
    requests.push({ url, options, resolve });
    options.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
  });
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, document, fetch });
  const respond = async (index, data, bookmark, ok = true, viewerId = '700') => {
    requests[index].resolve({ ok, json: async () => ({ resource_response: { status: 'success', data, bookmark },
      client_context: { user: { id: viewerId } }, resource: { options: { bookmarks: bookmark ? [bookmark] : [] } } }) });
    await flush();
  };
  const state = () => messages.at(-1);
  const call = (method, id) => window.PinmonyBoardApi[method](state().session, state().pageKey, id);
  return { window, location, requests, state, respond, call, tick: () => tick() };
}
async function loadBoard(h, value = board, viewerId = '700', feed = [pin('111')]) {
  await flush();
  assert.equal(h.requests.length, 1);
  assert.equal(new URL(h.requests[0].url, h.location.origin).pathname, '/resource/BoardResource/get/');
  await h.respond(0, value, '', true, viewerId);
  assert.equal(h.requests.length, 2);
  assert.equal(new URL(h.requests[1].url, h.location.origin).pathname, '/resource/BoardFeedResource/get/');
  await h.respond(1, feed, '-end-', true, viewerId);
}
async function main() {
  const createSection = harness();
  await loadBoard(createSection, { ...board });
  assert.equal(createSection.call('sectionCreate', '  New section  '), 'pending');
  assert.equal(createSection.call('sectionCreate', 'Duplicate'), 'unavailable');
  const write = createSection.requests[2];
  assert.equal(new URL(write.url, createSection.location.origin).pathname, '/resource/BoardSectionResource/create/');
  assert.equal(write.options.method, 'POST');
  const body = new URLSearchParams(write.options.body);
  assert.equal(body.get('source_url'), '/board/123/create_section/');
  assert.equal(write.options.headers['X-Pinterest-Pws-Handler'], 'www/board/[id]/create_section.js');
  assert.deepEqual(JSON.parse(body.get('data')).options, { board_id: '123', initial_pins: [], name: 'New section' });
  await createSection.respond(2, { type: 'board_section', id: '456', title: 'New section', pin_count: null,
    board: { id: '123', section_count: 1 } });
  assert.equal(createSection.call('sectionCreateRead'), 'pending', 'wait for list refresh');
  await createSection.respond(3, [{ type: 'board_section', id: '456', title: 'New section', pin_count: 0 }]);
  assert.equal(createSection.call('sectionCreateRead'), 'created');
  assert.equal(createSection.state().sections[0].id, '456');
  const unconfirmed = harness();
  await loadBoard(unconfirmed);
  unconfirmed.call('sectionCreate', 'New section');
  await unconfirmed.respond(2, { type: 'board_section', id: '456', title: 'New section', board: { id: '999' } });
  assert.equal(unconfirmed.call('sectionCreateRead'), 'uncertain', 'wrong board cannot confirm success');
  assert.equal(unconfirmed.call('sectionCreate', 'New section'), 'unavailable', 'uncertain mutation cannot replay');
  const staleCreate = harness();
  await loadBoard(staleCreate);
  staleCreate.call('sectionCreate', 'New section');
  staleCreate.location.pathname = '/sample/other/';
  await staleCreate.respond(2, { type: 'board_section', id: '456', title: 'New section', board: { id: '123' } });
  assert.equal(staleCreate.call('sectionCreateRead'), 'uncertain', 'late response cannot update another board');
  const beforeDom = harness('/sample/board/', 'loading');
  assert.equal(beforeDom.requests.length, 1, 'board demand starts before DOMContentLoaded');
  await loadBoard(beforeDom);
  const own = harness();
  assert.equal(own.state().loading, true);
  await loadBoard(own, board, '700', [pin('111'), pin('222')]);
  assert.equal(own.state().pins.length, 2);
  assert.equal(own.state().editable, true);
  assert.equal(own.state().ownerName, '');
  assert.equal(own.state().pinCount, '2 张 Pin 图');
  assert.equal(own.call('open', '111'), true);
  const other = harness();
  await loadBoard(other, board, '701', [pin('111')]);
  assert.equal(other.state().ownerName, 'Sample');
  assert.equal(other.state().editable, false);
  assert.equal(other.state().ownerAvatar, 'https://i.pinimg.com/avatar.jpg');
  const malformed = harness();
  await flush();
  await malformed.respond(0, { invalid: true }, '', true, '700');
  assert.ok(malformed.state().error);
  const stale = harness();
  await flush();
  await stale.respond(0, board, '', true, '700');
  stale.location.pathname = '/sample/other/';
  stale.tick();
  assert.equal(stale.requests[1].options.signal.aborted, true);
  const all = harness('/sample/pins/');
  const owner = { type: 'user', id: '77', username: 'sample', pin_count: 25 };
  await flush();
  await all.respond(0, owner, '', true, '77');
  assert.equal(new URL(all.requests[1].url, all.location.origin).pathname, '/resource/UserPinsResource/get/');
  const options = JSON.parse(new URL(all.requests[1].url, all.location.origin).searchParams.get('data')).options;
  assert.equal(options.is_own_profile_pins, true);
  await all.respond(1, [pin('501')], 'all-next', true, '77');
  assert.equal(all.state().title, '所有 Pin 图');
  all.call('more');
  assert.equal(JSON.parse(new URL(all.requests[2].url, all.location.origin).searchParams.get('data')).options.bookmarks[0], 'all-next');
  await all.respond(2, [], '-end-', true, '77');
  assert.equal(all.state().hasMore, false);
  const unknown = harness('/sample/pins/');
  await flush();
  await unknown.respond(0, owner, '', true, '');
  assert.ok(unknown.state().error);
  console.log('Board API checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
