const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname,
  '../entry/src/main/ets/services/PinmonySearchApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*)`;/)[1] + '`')();
new Function(script);
const fixture = { id: '123', type: 'pin', grid_title: '', title: 'Example',
  videos: { video_list: { V_HLSV4: { url: 'https://v1.pinimg.com/videos/test/sample.m3u8', width: 540, height: 960, duration: 4600 },
    V_720P: { url: 'https://untrusted.example/videos/sample.mp4', width: 720, height: 1280, duration: 4600 } } },
  images: { '474x': { url: 'https://i.pinimg.com/474x/sample.jpg', width: 474, height: 700 } } };
function harness() {
  const requests = [];
  const window = { PinmonySearchApiEnabled: true }; window.top = window;
  let page = 'https://www.pinterest.com/search/pins/?q=ip%E4%BA%BA%E7%89%A9&source_id=sample';
  let updates = 0;
  vm.runInNewContext(script, { window, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com' },
    document: { cookie: 'irrelevant=value; csrftoken=test-csrf' }, URL, URLSearchParams,
    AbortController, setTimeout, clearTimeout,
    fetch: (url, init) => new Promise(resolve => { requests.push({ url, init, resolve }); }) });
  const api = window.PinmonySearchApi;
  return { api, window, requests, get updates() { return updates; },
    setPage(value) { page = value; }, read() {
      const expected = page;
      return api.read(page, () => updates++, () => page === expected);
    }, async respond(index, pins, bookmark = '-end-', status = 200, rankedGuides = []) {
      requests[index].resolve({ ok: status === 200, json: async () => ({ resource_response: {
        status: 'success', data: { results: pins, rankedGuides }, bookmark } }) });
      await new Promise(resolve => setImmediate(resolve));
    } };
}
async function main() {
  const h = harness();
  assert.equal(h.read().busy, true);
  h.read(); assert.equal(h.requests.length, 1, 'no polling requests');
  const request = h.requests[0];
  assert.equal(request.url, '/resource/BaseSearchResource/get/');
  assert.equal(request.init.method, 'POST');
  assert.equal(request.init.credentials, 'same-origin');
  assert.equal(request.init.headers['X-CSRFToken'], 'test-csrf');
  assert.equal(request.init.headers.Cookie, undefined);
  const options = JSON.parse(new URLSearchParams(request.init.body).get('data')).options;
  assert.equal(options.page_size,25);
  assert.equal(options.query, 'ip人物'); assert.equal(options.scope, 'pins');
  assert.equal(options.bookmarks, undefined);
  const guide = { term: '角色插画 男&双人', display: '男', image_medium_url: 'https://i.pinimg.com/60x60/guide.jpg', dominant_color: '#aabbcc' };
  await h.respond(0, [fixture, fixture, { ...fixture, id: 'bad' }], 'next-page', 200,
    [guide, guide, { display: '无查询' }, { ...guide, term: '测试', image_medium_url: 'javascript:bad', dominant_color: 'bad' }]);
  assert.equal(h.read().categories.length, 2, 'ranked guides are validated and deduplicated');
  assert.equal(h.read().categories[0].label, '男');
  assert.equal(new URL(h.read().categories[0].targetUrl).searchParams.get('q'), guide.term);
  assert.equal(h.read().categories[0].imageUrl, guide.image_medium_url);
  assert.equal(h.read().categories[1].imageUrl, '', 'untrusted guide cover is rejected');
  assert.equal(h.read().categories[1].backgroundColor, '');
  assert.equal(h.read().results.length, 1);
  assert.equal(h.read().results[0].title, 'Example');
  assert.equal(h.read().results[0].video.duration, 4600);
  assert.equal(h.read().results[0].video.pinId, '123');
  assert.equal(h.read().results[0].video.sources.length, 1, 'untrusted CDN source is rejected');
  assert.equal(h.api.loadMore(), true);
  assert.equal(h.api.loadMore(), false, 'no simultaneous pagination');
  assert.equal(JSON.parse(new URLSearchParams(h.requests[1].init.body).get('data')).options.bookmarks[0], 'next-page');
  await h.respond(1, [fixture, { ...fixture, id: '456' }], 'next-page');
  assert.equal(h.read().categories.length, 2, 'pagination without guides preserves first-page categories');
  assert.equal(h.read().results.length, 2);
  assert.equal(h.read().ended, true, 'repeated cursor ends pagination');
  assert.equal(h.api.loadMore(), false);
  assert(h.api.context().filterBookmark && h.api.context().filterBookmark !== '-end-', 'filters retain a usable current-query cursor after pagination ends');
  h.api.refresh(); await h.respond(2, []);
  assert.equal(h.read().active, true); assert.equal(h.read().results.length, 0, 'valid empty search');
  h.api.refresh(); await h.respond(3, [], '', 403);
  assert.match(h.read().error, /接口读取失败/); h.read();
  assert.equal(h.requests.length, 4, 'failure requires explicit retry');
  h.api.refresh();
  h.setPage('https://www.pinterest.com/search/pins/?q=another'); h.read();
  assert.equal(h.read().categories.length, 0, 'category targets cannot leak to another route');
  assert.equal(h.requests[4].init.signal.aborted, true);
  const before = h.updates;
  await h.respond(4, [fixture]); assert.equal(h.updates, before, 'old response ignored');
  await h.respond(5, [{ ...fixture, images: { '474x': { url: 'javascript:bad', width: 1, height: 1 } } }]);
  assert.match(h.read().error, /接口读取失败/, 'malformed nonempty results fail');
  h.api.refresh(); await h.respond(6, [fixture], 'more');
  h.api.loadMore(); await h.respond(7, [], '', 403);
  assert.equal(h.read().results.length, 1, 'pagination failure preserves visible results');
  assert.match(h.read().error, /更多搜索结果/);
  h.api.suspend('https://www.pinterest.com/search/pins/?q=another');
  assert.equal(h.read().busy, true, 'filtered search waits for an API response rather than DOM');
  const observed = { page: 'https://www.pinterest.com/search/pins/?q=another', version: 1,
    options: { query: 'another', scope: 'pins', filter_genai: true, filters: 'verified-filter' },
    resource: { status: 'success', bookmark: 'filtered-next', data: { results: [fixture], rankedGuides: [guide] } } };
  h.window.PinmonySearchUiApi = { readSearch: page => page === observed.page ? observed : null };
  assert.equal(h.read().active, true);
  assert.equal(h.read().categories[0].label, '男', 'observed website first page supplies guides');
  assert.equal(h.read().results.length, 1);
  h.api.loadMore();
  const filteredOptions = JSON.parse(new URLSearchParams(h.requests[8].init.body).get('data')).options;
  assert.equal(filteredOptions.filters, 'verified-filter');
  assert.equal(filteredOptions.filter_genai, true);
  assert.equal(filteredOptions.bookmarks[0], 'filtered-next');
  await h.respond(8, [{ ...fixture, id: '456' }]);
  assert.equal(h.read().results.length, 2, 'observed initial page does not overwrite API pagination');
  h.setPage('https://www.pinterest.com/search/pins/?q=test&filter_genai=true');
  assert.equal(h.read().busy, true);
  assert.equal(h.read().results.length, 0, 'unsupported route has no DOM fallback');
  h.setPage('https://www.pinterest.com/search/'); assert.match(h.read().error, /探索推荐接口尚未接入/);
  for (const scope of ['videos', 'boards', 'users', 'buyable_pins']) {
    h.setPage('https://www.pinterest.com/search/' + scope + '/?q=test&rs=content_type_filter');
    h.read();
    const index = h.requests.length - 1;
    const submitted = JSON.parse(new URLSearchParams(h.requests[index].init.body).get('data')).options;
    assert.equal(submitted.scope, scope);
    if (scope === 'boards') {
      await h.respond(index, [{type:'board',id:'555',name:'真实图板',url:'/someone/design/',images:{'236x':[{url:'https://i.pinimg.com/a.jpg'}]}}]);
      assert.equal(h.read().results[0].kind, 'board');
      assert.equal(h.read().results[0].targetUrl, 'https://www.pinterest.com/someone/design/');
    } else await h.respond(index, []);
  }
  h.setPage('https://www.pinterest.com/search/pins/?q=no-title');h.read();
  await h.respond(h.requests.length-1,[{...fixture,title:'',description:'',grid_title:''}]);
  assert.equal(h.read().results.length,1,'titleless pins remain visible');
  assert.equal(h.read().results[0].title,'','never invent an unavailable title');
  const recovery=harness();recovery.read();await recovery.respond(0,[]);
  assert.equal(recovery.read().results.length,0);
  recovery.window.PinmonySearchUiApi={readSearch:()=>({version:1,options:{query:'ip人物',scope:'pins'},resource:{status:'success',data:{results:[fixture]},bookmark:'-end-'}})};
  assert.equal(recovery.read().results.length,1,'website first page replaces an early native empty result');
  const race=harness();race.read();
  race.window.PinmonySearchUiApi={readSearch:()=>({version:1,options:{query:'ip人物',scope:'pins'},resource:{status:'success',data:{results:[fixture]},bookmark:'-end-'}})};
  assert.equal(race.read().results.length,1);assert.equal(race.requests[0].init.signal.aborted,true);
  await race.respond(0,[]);assert.equal(race.read().results.length,1,'late empty native response cannot erase website results');
  h.window.PinmonySearchApiEnabled = false;
  assert.equal(h.read(), null);
  console.log('Search API request, pagination, empty, error, race and filter checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
