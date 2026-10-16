const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyProfileApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const requests = [], window = { PinmonyProfileApiEnabled: true }; window.top = window;
  const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/sample/' };
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout,
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })), console });
  const api = window.PinmonyProfileApi, profile = 'https://www.pinterest.com/sample/';
  const changed = () => {}, current = () => true;
  const respond = async (index, data, bookmark, ok = true) => {
    requests[index].resolve({ ok, json: async () => ({ resource_response: { status: 'success', data, bookmark } }) });
    await flush();
  };
  api.read(profile, changed, current);
  requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success',
    data: { type: 'user', id: '123', username: 'sample', pin_count: 406,
      last_pin_save_time: new Date(Date.now() - 21 * 86400000).toUTCString() } }, client_context: { user: { id: '123' } } }) });
  await flush();
  const read = section => api.readContent(profile, section, changed, current);
  assert.equal(read('saved').loading, true);
  const savedRequest = new URL(requests[1].url, location.origin);
  assert.equal(savedRequest.pathname, '/resource/BoardsFeedResource/get/');
  assert.equal(JSON.parse(savedRequest.searchParams.get('data')).options.sort, 'last_pinned_to');
  assert.equal(requests[1].options.credentials, 'same-origin');
  await respond(1, [
    { type: 'story', id: '10', story_type: 'all_pins', title: { format: '所有 Pin 图' },
      action: { url: '/users/123/pins/' }, objects: [{ image_medium_url: 'https://i.pinimg.com/a.jpg' }] },
    { type: 'board', id: '11', name: 'Board', url: '/sample/board/', pin_count: 0, section_count: 1,
      board_order_modified_at: new Date(Date.now() - 21 * 86400000).toUTCString(),
      images: { '236x': [{ url: 'https://i.pinimg.com/b.jpg' }] } }
  ], 'next');
  assert.equal(read('saved').items.length, 2);
  assert.equal(read('saved').items[1].pinCount, '0 张 Pin 图 · 1 个图板区块');
  assert.equal(read('saved').items[1].updated, '3 周前');
  assert.equal(read('saved').items[0].pinCount, '406 张 Pin 图', 'all-pins count comes from the viewed profile');
  assert.equal(read('saved').items[0].updated, '3 周前', 'all-pins uses the viewed profile last save time');
  const allId = read('saved').items[0].id;
  assert.equal(api.open(allId), true);
  assert.equal(location.href, profile + 'pins/', 'internal action becomes the HAR-confirmed public collection route');
  assert.equal(read('saved').items[0].targetUrl, profile + 'pins/', 'native opening cover uses the public route');
  const oldId = read('saved').items[1].id;
  assert.equal(api.open(oldId), true);
  assert.equal(location.href, profile + 'board/');
  api.more(profile, 'saved', changed, current);
  assert.equal(JSON.parse(new URL(requests[2].url, location.origin).searchParams.get('data')).options.bookmarks[0], 'next');
  await respond(2, null, '', false);
  assert.equal(read('saved').items.length, 2, 'pagination failure preserves cards');
  assert.ok(read('saved').error);
  api.retryContent(profile, 'saved', changed, current);
  assert.equal(JSON.parse(new URL(requests[3].url, location.origin).searchParams.get('data')).options.bookmarks[0], 'next');
  await respond(3, [{ type: 'board', id: '11', name: 'Board', url: '/sample/board/' }], '-end-');
  assert.equal(read('saved').items.length, 2, 'duplicate cards are discarded');
  assert.equal(read('saved').hasMore, false);
  read('created');
  assert.equal(api.open(oldId), false, 'old section actions are invalidated');
  const createdOptions = JSON.parse(new URL(requests[4].url, location.origin).searchParams.get('data')).options;
  assert.equal(createdOptions.user_id, '123');
  assert.equal(createdOptions.is_own_profile_pins, true);
  await respond(4, [], '-end-');
  assert.equal(read('created').ready, true);
  assert.equal(read('created').items.length, 0, 'successful empty feed is ready');
  const cachedSaved = read('saved');
  assert.equal(cachedSaved.items.length, 2);
  assert.equal(api.open(oldId), false, 'cached sections receive new action identifiers');
  assert.equal(api.open(cachedSaved.items[1].id), true);
  assert.equal(read('created').ready, true, 'successful empty section is cached');
  assert.equal(requests.length, 5, 'section switching reuses completed feeds');
  api.invalidateContent();
  read('saved'); read('created');
  assert.equal(requests[5].options.signal.aborted, true);
  await respond(5, [{ type: 'board', id: '99', name: 'Stale', url: '/sample/stale/' }], '-end-');
  assert.equal(read('created').loading, true, 'late response cannot overwrite another section');
  await respond(6, [{ type: 'pin', id: '567', title: '', images: { '736x': {
    url: 'https://i.pinimg.com/p.jpg', width: 736, height: 1040 } } }], '-end-');
  assert.equal(read('created').items[0].title, '');
  assert.equal(read('created').items[0].imageHeight, 1040);
  assert.equal(api.open(read('created').items[0].id), true);
  assert.equal(location.href, location.origin + '/pin/567/');
  api.reset(); api.read(profile, changed, current);
  await respond(7, { type: 'user', id: '123', username: 'sample' });
  read('saved'); await respond(8, { unexpected: [] }, '-end-');
  assert.equal(read('saved').ready, false, 'malformed data is never an empty success');
  assert.ok(read('saved').error);
  api.reset();
  api.read(profile, changed, current);
  requests[9].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success',
    data: { type: 'user', id: '123', username: 'sample', pin_count: 0 } }, client_context: { user: { id: '456' } } }) });
  await flush();
  read('saved');
  await respond(10, [{ type: 'story', id: '10', story_type: 'all_pins', title: { format: '所有 Pin 图' },
    action: { url: '/users/123/pins/' }, objects: [] }], '-end-');
  assert.equal(read('saved').ready, true);
  assert.equal(read('saved').items.length, 0, 'zero-pin placeholder does not hide the empty state');
  read('created');
  assert.equal(JSON.parse(new URL(requests[11].url, location.origin).searchParams.get('data')).options.is_own_profile_pins, false);
  await respond(11, [], '-end-');
  api.reset();
  console.log('Profile feed checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
