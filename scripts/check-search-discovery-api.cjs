const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('feature_search/src/main/ets/services/PinWebSearchDiscoveryApiScript.ets', 'utf8');
const script = Function('return ' + source.match(/SCRIPT: string = (\x60[\s\S]*\x60);/)[1])();
const requests = [], navigations = [];
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/search/', search: '', assign: v => navigations.push(v) };
Object.defineProperty(location, 'href', {get: () => location.origin + location.pathname + location.search});
const window = { PinWebSearchDiscoveryApiEnabled: true }; window.top = window;
vm.runInNewContext(script, { window, location, URL, URLSearchParams, AbortController, setTimeout, clearTimeout,
  fetch: (url, init) => new Promise(resolve => requests.push({ url, init, resolve })) });
const api = window.PinWebSearchDiscoveryApi;
const read = () => api.read(location.origin + location.pathname + location.search, () => {});
const payload = (bookmark = 'next', title = '海报') => ({ resource_response: { status: 'success', bookmark, data: [
  { id: 'header', story_type: 'slp_immersive_header', title: { format: '今日灵感' }, objects: [
    { type: 'board', name: '灵感图板', url: '/example/ideas/', image_cover_hd_url: 'https://i.pinimg.com/736x/cover.jpg' }] },
  { id: title, story_type: 'slp_search_recommendation', title: { format: title }, subtitle: { format: '为你推荐的点子' },
    action: { url: '/search/pins/?q=poster' }, objects: [0,1,2,3].map(i => ({ image_medium_url: 'https://i.pinimg.com/236x/' + i + '.jpg' })) },
  { id: 'unsafe', story_type: 'slp_search_recommendation', title: { format: 'Unsafe' }, action: { url: 'https://evil.example/' }, objects: [] }
] } });
async function respond(req, data, ok = true) { req.resolve({ ok, json: async () => data }); await new Promise(resolve => setImmediate(resolve)); }
async function main() {
  assert.equal(read().busy, true); const first = requests.at(-1);
  assert.equal(new URL(first.url, location.origin).pathname, '/resource/SearchTabResource/get/');
  assert.deepEqual(JSON.parse(new URL(first.url, location.origin).searchParams.get('data')).options, {});
  await respond(first, payload()); let state = read();
  assert.equal(state.heroes.length, 1); assert.equal(state.sections.length, 1); assert.equal(state.sections[0].items.length, 4);
  assert.equal(api.action(state.sections[0].items[0].id), true); assert.equal(navigations.at(-1), 'https://www.pinterest.com/search/pins/?q=poster');
  assert.equal(api.loadMore(), true); const second = requests.at(-1);
  assert.deepEqual(JSON.parse(new URL(second.url, location.origin).searchParams.get('data')).options.bookmarks, ['next']);
  await respond(second, payload('next', '排版')); assert.equal(read().sections.length, 2); assert.equal(read().ended, true);
  assert.equal(api.loadMore(), false);
  api.refresh(); const failed = requests.at(-1); await respond(failed, null, false);
  assert.equal(read().sections.length, 2); assert.match(read().error, /失败/);
  api.refresh(); const late = requests.at(-1); api.pause(); await respond(late, payload('-end-', '旧数据'));
  assert.equal(read().sections.length, 2, 'paused response cannot replace current data');
  api.refresh(); await respond(requests.at(-1), {resource_response:{status:'success',bookmark:'-end-',data:[]}});
  assert.equal(read().active, true); assert.equal(read().sections.length, 0);
  location.pathname='/login/'; assert.equal(read(), null);
  console.log('SearchTab resource mapping, carousel, pagination, empty/error and late-response checks passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
