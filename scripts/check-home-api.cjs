const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyHomeApiScript.ets'), 'utf8');
const template = source.match(/`([\s\S]*?)`;/)[1];
const script = Function('return `' + template + '`')();
new Function(script);
const fixture = JSON.parse(readSourceFileSync(path.join(__dirname, 'fixtures/home-api.json'), 'utf8'));
const categoryFixture = JSON.parse(readSourceFileSync(path.join(__dirname, 'fixtures/category-api.json'), 'utf8').replace(/^\uFEFF/, ''));
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness(enabled = true, initial = null) {
  const requests = [];
  let valid = true;
  const window = { PinmonyHomeApiEnabled: enabled };
  window.top = window;
  vm.runInNewContext(script, { window, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/' },
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })),
    AbortController, setTimeout, clearTimeout, console: { warn() {} } });
  const read = (key = '1:/全部', eligible = true, boardId = '') => window.PinmonyHomeApi.read(key, eligible, () => {}, () => valid, boardId);
  const respond = async (index, value, status = 200) => {
    requests[index].resolve({ ok: status === 200, status, json: async () => value });
    await flush();
  };
  return { api: window.PinmonyHomeApi, requests, read, respond, invalidate: () => { valid = false; } };
}
async function main() {
  const h = harness();
  assert.equal(h.read().active, false, 'first page waits for valid API data');
  h.read();
  assert.equal(h.requests.length, 1, 'only one first-page request');
  const request = new URL(h.requests[0].url, 'https://www.pinterest.com');
  assert.equal(request.pathname, '/resource/UserHomefeedResource/get/');
  assert.equal(request.searchParams.get('source_url'), '/');
  const data = JSON.parse(request.searchParams.get('data'));
  assert.equal(data.options.field_set_key, 'hf_grid');
  assert.equal(data.options.bookmarks, undefined, 'initial request does not reuse captured account cursors');
  assert.equal(h.requests[0].options.credentials, 'same-origin');
  assert.equal(h.requests[0].options.headers.Cookie, undefined);
  await h.respond(0, fixture);
  const first = h.read();
  assert.equal(first.active, true);
  assert.equal(fixture.resource_response.data.length, 25);
  assert.equal(first.pins.length, 21, 'four nonnumeric sponsored presentation IDs cannot be used as Pin URLs');
  assert.equal(first.pins[0].title, '', 'blank title is not invented');
  assert.equal(first.pins[0].imageWidth, 474);
  assert.equal(first.pins[0].imageHeight, 712);
  assert.equal(first.pins[0].id, fixture.resource_response.data[0].id);
  assert.equal(h.api.loadMore(), true);
  assert.equal(h.api.loadMore(), false, 'concurrent pagination is blocked');
  const pageData = JSON.parse(new URL(h.requests[1].url, 'https://www.pinterest.com').searchParams.get('data'));
  assert.equal(pageData.options.bookmarks[0], 'fixture-page-2');
  const newPin = { ...fixture.resource_response.data[0], id: '99999' };
  await h.respond(1, { resource_response: { status: 'success', data: [fixture.resource_response.data[0], newPin], bookmark: 'fixture-page-3' } });
  assert.equal(h.read().pins.length, 22, 'pagination deduplicates IDs');
  h.api.loadMore();
  await h.respond(2, {}, 403);
  assert.equal(h.read().pins.length, 22, 'failed pagination preserves feed');
  assert.ok(h.read().error);
  assert.equal(h.api.loadMore(), true, 'failed page can be retried');
  await h.respond(3, { resource_response: { status: 'success', data: [newPin], bookmark: 'fixture-page-3' } });
  assert.equal(h.read().ended, true, 'unchanged cursor ends pagination');
  assert.equal(h.api.loadMore(), false);
  h.api.reset();
  h.read('2:/全部');
  assert.equal(h.requests.length, 5, 'refresh resets first-page probe');
  h.read('3:/动漫', false);
  assert.equal(h.requests[4].options.signal.aborted, true);
  await h.respond(4, fixture);
  assert.equal(h.api.isActive(), false, 'late category response is discarded');
  const failed = harness();
  const stalePrefetch = harness();
  stalePrefetch.read();
  await stalePrefetch.respond(0, fixture);
  stalePrefetch.invalidate();
  assert.equal(stalePrefetch.api.loadMore(), false, 'an invalidated page cannot start speculative pagination');
  assert.equal(stalePrefetch.requests.length, 1, 'stale prefetch does not dispatch network traffic');
  failed.read();
  await failed.respond(0, {}, 401);
  assert.equal(failed.read().active, false);
  assert.ok(failed.read().error, 'first-page failure reports an API error');
  assert.equal(failed.requests.length, 1, 'failure does not loop requests');
  const disabled = harness(false);
  assert.equal(disabled.read(), null);
  assert.equal(disabled.requests.length, 0, 'rollback switch makes no API requests');
  const stale = harness();
  stale.read(); stale.invalidate();
  await stale.respond(0, fixture);
  assert.equal(stale.api.isActive(), false, 'navigation invalidates response before state delivery');
  const malformed = harness();
  malformed.read();
  await malformed.respond(0, { resource_response: { status: 'success', data: [{ type: 'pin', id: '1', images: {} }] } });
  assert.equal(malformed.read().active, false, 'unusable image data cannot activate API feed');
  const exhausted = harness();
  exhausted.read(); await exhausted.respond(0, fixture); exhausted.api.loadMore();
  await exhausted.respond(1, { resource_response: { status: 'success', data: [], bookmark: '-end-' } });
  assert.equal(exhausted.read().ended, true);
  assert.equal(exhausted.read().pins.length, 21);
  const refresh = harness();
  refresh.read(); await refresh.respond(0, fixture);
  refresh.api.loadMore();
  assert.equal(refresh.api.refresh(), true);
  assert.equal(refresh.api.refresh(), false, 'repeated refresh joins existing work without restarting');
  assert.equal(refresh.requests.length, 3, 'repeated refresh does not send another request');
  assert.equal(refresh.requests[1].options.signal.aborted, true, 'refresh cancels old pagination');
  assert.equal(refresh.read().pins.length, 21, 'refresh retains API cards while waiting');
  assert.equal(refresh.read().refreshing, true);
  await refresh.respond(1, { resource_response: { status: 'success', data: [newPin], bookmark: 'stale' } });
  assert.equal(refresh.read().pins.length, 21, 'late pagination cannot overwrite refreshing feed');
  await refresh.respond(2, {}, 403);
  assert.equal(refresh.read().active, true, 'failed refresh stays on the API source');
  assert.equal(refresh.read().pins.length, 21);
  assert.equal(refresh.read().refreshing, false);
  refresh.api.refresh();
  await refresh.respond(3, { resource_response: { status: 'success', data: [newPin], bookmark: 'new-page' } });
  assert.deepEqual(Array.from(refresh.read().pins, pin => pin.id), ['99999']);
  const category = harness();
  category.api.setUsername('sample');
  category.api.initialTabs();
  assert.equal(category.requests.length, 1, 'saved board categories are requested first');
  const savedRequest = new URL(category.requests[0].url, 'https://www.pinterest.com');
  assert.equal(savedRequest.pathname, '/resource/BoardsFeedResource/get/');
  assert.equal(savedRequest.searchParams.get('source_url'), '/sample/');
  assert.deepEqual(JSON.parse(savedRequest.searchParams.get('data')).options,
    { field_set_key: 'profile_grid_item', filter_stories: false, sort: 'last_pinned_to', username: 'sample' });
  await category.respond(0, { resource_response: { status: 'success', data: [
    ...categoryFixture.tabs.slice().reverse().map(tab => ({ type: 'board', id: tab.aux_data.board_id, name: tab.name }))
  ] } });
  assert.deepEqual(Array.from(category.api.initialTabs(), tab => tab.name),
    ['图形', '品牌', '包装', '动漫', '用户界面设计'], 'saved board response order defines category order');
  const boardId = category.api.initialTabs()[1].boardId;
  const readCategory = () => category.read('2:/动漫', true, boardId);
  readCategory();
  const categoryRequest = new URL(category.requests[1].url, 'https://www.pinterest.com');
  assert.equal(categoryRequest.pathname, '/resource/BoardContentRecommendationResource/get/');
  assert.equal(categoryRequest.searchParams.get('source_url'), '/?tabId=' + boardId);
  assert.deepEqual(JSON.parse(categoryRequest.searchParams.get('data')).options,
    { type: 'board', id: boardId, __track__referrer: 19 });
  await category.respond(1, categoryFixture.first);
  const boardRequest = new URL(category.requests[2].url, 'https://www.pinterest.com');
  assert.equal(boardRequest.pathname, '/resource/BoardResource/get/');
  assert.equal(boardRequest.searchParams.get('source_url'), '/?tabId=' + boardId);
  const boardData = { resource_response: { status: 'success', code: 0,
    endpoint_name: 'v3_get_board', data: { id: boardId, name: '动漫', pin_count: 3,
      image_cover_url: 'https://i.pinimg.com/200x150/fixture.jpg' } } };
  await category.respond(2, boardData);
  assert.equal(readCategory().board.id, boardId);
  assert.equal(readCategory().board.name, '动漫');
  assert.equal(readCategory().board.pinCount, 3);
  assert.equal(readCategory().board.thumbnailUrl, 'https://i.pinimg.com/200x150/fixture.jpg');
  assert.equal(readCategory().pins.length,
    categoryFixture.first.resource_response.data.filter(pin => pin.type === 'pin' && /^\d+$/.test(pin.id)).length,
    'story modules and sponsored presentation IDs do not become recommendation cards');
  category.api.loadMore();
  const categoryPage = JSON.parse(new URL(category.requests[3].url, 'https://www.pinterest.com').searchParams.get('data'));
  assert.deepEqual(categoryPage.options.bookmarks, ['category-page-2']);
  await category.respond(3, categoryFixture.next);
  assert.equal(readCategory().ended, true, 'captured nonadvancing category cursor stops pagination');
  assert.ok(readCategory().pins.length > 0);
  category.api.refresh();
  category.read('3:/包装', true, category.api.initialTabs()[2].boardId);
  await category.respond(4, categoryFixture.first);
  assert.equal(category.api.isActive(), false, 'late category refresh is discarded after switching boards');
  await category.respond(6, categoryFixture.first);
  assert.equal(category.api.isActive(), true);
  assert.equal(harness(false).api.initialTabs().length, 0, 'rollback also disables saved categories');
  assert.doesNotMatch(source, /document\.|getElementById|__PWS_INITIAL_PROPS__/,
    'category username and order do not come from homepage DOM');
  console.log('home API: 25-Pin fixture, mapping, session credentials, pagination, retries, cancellation and rollback OK');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
