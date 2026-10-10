const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname,
  '../entry/src/main/ets/services/PinmonySearchUiApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*)`;/)[1] + '`')();
new Function(script);
const filterData = [{ type: 'filter', title: null, filter_options: [
  { type: 'filteroption', id: '1', label: '所有 Pin 图', is_selected: true },
  { type: 'filteroption', id: '2', label: '视频' },
  { type: 'filteroption', id: '3', label: '个人资料' }
] }];
const controls = [ { id: 'web-all', label: '所有 Pin 图', group: '', enabled: true },
  { id: 'web-video', label: '视频', group: '', enabled: true } ];
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness() {
  const requests = [];
  class XHR {
    open(method, url) { this.method = method; this.url = url; }
    send(body) { this.body = body; }
    addEventListener(_event, callback) { this.callback = callback; }
    respond(payload) { this.status = 200; this.responseText = JSON.stringify(payload); this.callback(); }
  }
  let updated = 0;
  const env = { PinmonySearchUiApiEnabled: true, URL, URLSearchParams, AbortController,
    XMLHttpRequest: XHR, setTimeout, clearTimeout,
    location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com',
      pathname: '/search/pins/', search: '?q=garden', href: 'https://www.pinterest.com/search/pins/?q=garden' },
    document: { cookie: 'csrftoken=test-csrf' },
    fetch: (url, init) => new Promise(resolve => requests.push({ url, init, resolve })) };
  env.window = env; env.top = env;
  vm.runInNewContext(script, env);
  const api = env.PinmonySearchUiApi;
  return { env, api, requests, get updates() { return updated; },
    page: () => env.location.origin + env.location.pathname + env.location.search,
    hint() { return api.readHint(this.page(), () => updated++); },
    filters() { return api.readFilters(this.page(), controls); },
    async respond(index, data, status = 200) {
      const payload = { resource_response: { status: 'success', data } };
      const response = { ok: status === 200, json: async () => payload, clone: () => response };
      requests[index].resolve(response); await flush();
    },
    observe(bookmark, query = 'garden') {
      const xhr = new env.XMLHttpRequest();
      xhr.open('POST', '/resource/BaseSearchResource/get/');
      xhr.send(new URLSearchParams({ source_url: '/search/pins/' + env.location.search,
        data: JSON.stringify({ options: { query } }) }).toString());
      if (xhr.callback) xhr.respond({ resource_response: { status: 'success', bookmark, data: { results: [] } } });
    },
    filterRequest(bookmark) {
      const xhr = new env.XMLHttpRequest();
      xhr.open('POST', '/resource/ApiResource/get/');
      xhr.send(new URLSearchParams({ source_url: '/search/pins/' + env.location.search,
        data: JSON.stringify({ options: { url: '/v3/filters/', data: { bookmark_string: bookmark } } }) }).toString());
      return xhr;
    }
  };
}
async function main() {
  const h = harness();
  assert.equal(h.hint(), ''); h.hint(); assert.equal(h.requests.length, 1);
  const hintOptions = JSON.parse(new URL(h.requests[0].url, h.env.location.origin).searchParams.get('data')).options;
  assert.equal(hintOptions.url, '/v3/search/ghost_queries/');
  assert.equal(h.requests[0].init.credentials, 'same-origin');
  await h.respond(0, [{ text: '搜索', query_type: 'SEASONAL' }]);
  assert.equal(h.hint(), '搜索');
  assert.equal(h.filters().loading, true, 'wait for current search cursor');
  h.observe('cursor-1');
  assert.equal(h.filters().loading, true);
  const filterRequest = h.requests[1];
  assert.equal(filterRequest.url, '/resource/ApiResource/get/');
  assert.equal(filterRequest.init.method, 'POST');
  assert.equal(filterRequest.init.headers['X-CSRFToken'], 'test-csrf');
  const filterOptions = JSON.parse(new URLSearchParams(filterRequest.init.body).get('data')).options;
  assert.equal(filterOptions.url, '/v3/filters/');
  assert.equal(filterOptions.data.bookmark_string, 'cursor-1');
  await h.respond(1, filterData);
  let snapshot = h.filters();
  assert.equal(snapshot.options[0].label, '所有 Pin 图');
  assert.equal(snapshot.options[0].selected, true);
  assert.match(snapshot.options[0].id, /^api-filter-/);
  assert.equal(snapshot.options[2].enabled, true, 'API list does not depend on pre-rendered DOM controls');
  const oldOptionId = snapshot.options[1].id;
  assert.equal(h.api.filterOption(h.page(), oldOptionId).label, '视频');
  h.api.selectedFilter();
  assert.equal(h.api.filterOption(h.page(), oldOptionId), null, 'old option identities expire on selection');
  assert.equal(h.filters().loading, true, 'selection waits for a fresh resource response');
  h.observe('wrong-cursor', 'old-query'); assert.equal(h.requests.length, 2);
  h.observe('cursor-2'); h.filters();
  await h.respond(2, [], 403);
  assert.match(h.filters().error, /接口读取失败/); h.filters();
  assert.equal(h.requests.length, 3, 'no automatic failure retry');
  h.api.retryFilters(); h.filters(); await h.respond(3, []);
  assert.equal(h.filters().options.length, 0); assert.equal(h.filters().error, '');
  assert.equal(h.filters().status, 'empty', 'only a successful empty response is classified empty');
  h.api.retryFilters(); h.filters();
  h.env.location.search = '?q=another'; h.env.location.href = h.page(); h.hint();
  assert.equal(h.requests[4].init.signal.aborted, true);
  await h.respond(4, filterData); assert.equal(h.filters().loading, true, 'old filter response discarded');
  await h.respond(5, [{ text: '新提示' }]); assert.equal(h.hint(), '新提示');
  h.api.reset(); h.hint();
  h.env.location.search = '?q=third'; h.env.location.href = h.page(); h.hint();
  await h.respond(6, [{ text: '旧提示' }]); assert.equal(h.hint(), '');
  await h.respond(7, [{ text: '   ' }]); assert.equal(h.hint(), '', 'missing hint uses generic native fallback');
  const fields = new URLSearchParams({ source_url: '/search/pins/?q=third', data: JSON.stringify({ options: { query: 'third' } }) });
  const observedFetch = h.env.fetch('/resource/BaseSearchResource/get/', { body: fields.toString() });
  const payload = { resource_response: { status: 'success', bookmark: 'fetch-cursor', data: { results: [] } } };
  const response = { ok: true, json: async () => payload, clone: () => response };
  h.requests[8].resolve(response); assert.equal(await observedFetch, response); await flush();
  h.filters();
  assert.equal(JSON.parse(new URLSearchParams(h.requests[9].init.body).get('data')).options.data.bookmark_string, 'fetch-cursor');
  await h.respond(9, filterData);
  const cursorHarness = harness();
  cursorHarness.hint(); await cursorHarness.respond(0, [{ text: '搜索' }]);
  let latestCursor = 'first';
  cursorHarness.env.PinmonySearchApi = { context: () => ({ page: cursorHarness.page(), bookmark: latestCursor }) };
  assert.equal(cursorHarness.filters().status, 'loading');
  latestCursor = 'second'; cursorHarness.filters();
  assert.equal(cursorHarness.requests[1].init.signal.aborted, true, 'a new API cursor cancels old filter request');
  assert.equal(JSON.parse(new URLSearchParams(cursorHarness.requests[2].init.body).get('data')).options.data.bookmark_string, 'second');
  await cursorHarness.respond(1, []);
  assert.equal(cursorHarness.filters().status, 'loading', 'old empty response cannot replace the current request');
  await cursorHarness.respond(2, filterData);
  assert.equal(cursorHarness.filters().status, 'ready');
  assert.equal(cursorHarness.api.readFilters('https://www.pinterest.com/search/pins/?q=old').status, 'error');
  const websiteData = [{ ...filterData[0], aux_data: { entered_query: 'garden' }, filter_options: [
    ...filterData[0].filter_options.slice(0, 2), { type: 'filteroption', label: '图板' },
    filterData[0].filter_options[2], { type: 'filteroption', label: '产品' }
  ] }];
  const websiteHarness = harness();
  websiteHarness.hint(); await websiteHarness.respond(0, [{ text: '搜索' }]);
  websiteHarness.env.PinmonySearchApi = { context: () => ({ page: websiteHarness.page(), bookmark: 'rebuilt-search-cursor' }) };
  websiteHarness.filters();
  const websiteRequest = websiteHarness.filterRequest('actual-website-filter-cursor');
  websiteRequest.respond({ resource_response: { status: 'success', data: websiteData } });
  assert.equal(websiteHarness.requests[1].init.signal.aborted, true);
  assert.equal(websiteHarness.filters().options.length, 5, 'website filter JSON supplies all five options without DOM');
  const typeOptions = websiteHarness.filters().options;
  for (const [label, scope] of [['所有 Pin 图','pins'],['视频','videos'],['图板','boards'],['个人资料','users'],['产品','buyable_pins']]) {
    const option = typeOptions.find(value => value.label === label);
    if (option.selected) assert.equal(websiteHarness.api.filterTarget(websiteHarness.page(), option.id), '');
    else assert.equal(websiteHarness.api.filterTarget(websiteHarness.page(), option.id), 'https://www.pinterest.com/search/' + scope + '/?q=garden&rs=content_type_filter');
  }
  assert.equal(websiteHarness.api.filterTarget(websiteHarness.page()+'old', typeOptions[1].id), '', 'stale filter target is rejected');
  await websiteHarness.respond(1, []);
  assert.equal(websiteHarness.filters().status, 'ready', 'late empty reconstructed request cannot erase website filter JSON');
  websiteHarness.api.prepareFilters();
  assert.equal(websiteHarness.filters().options.length, 5, 'opening the sheet preserves valid website API cache');
  websiteHarness.api.retryFilters(); websiteHarness.filters();
  assert.equal(JSON.parse(new URLSearchParams(websiteHarness.requests[2].init.body).get('data')).options.data.bookmark_string,
    'actual-website-filter-cursor', 'retry replays the observed filter request, not a different search bookmark');
  await websiteHarness.respond(2, websiteData);
  const lateFilterRequest = websiteHarness.filterRequest('late-cursor');
  websiteHarness.api.selectedFilter();
  websiteHarness.env.PinmonySearchApi = { context: () => ({ page: '', bookmark: '' }) };
  lateFilterRequest.respond({ resource_response: { status: 'success', data: websiteData } });
  assert.equal(websiteHarness.filters().status, 'waiting-search', 'pre-selection website filter response is rejected');
  const initialHarness = harness();
  initialHarness.hint(); await initialHarness.respond(0, [{ text: '搜索' }]);
  const initialNode = { textContent: JSON.stringify({ initialReduxState: { resources: { ApiResource: {
    filters: { data: websiteData }
  } } } }) };
  initialHarness.env.document.getElementById = () => initialNode;
  assert.equal(initialHarness.filters().options.length, 0, 'embedded DOM JSON no longer supplies filters');
  assert.equal(initialHarness.requests.length, 1, 'hydration reads API cache, not another synthetic request');
  initialHarness.api.selectedFilter();
  assert.equal(initialHarness.filters().status, 'waiting-search', 'old initial JSON is not re-adopted after selecting a filter');
  const requestHarness=harness();
  const websiteBody=new URLSearchParams({source_url:'/search/pins/?q=garden',data:JSON.stringify({options:{query:'garden',scope:'pins'},context:{}})}).toString();
  const requestObject={url:'https://www.pinterest.com/resource/BaseSearchResource/get/',clone:()=>({text:async()=>websiteBody})};
  const responsePromise=requestHarness.env.fetch(requestObject);
  await requestHarness.respond(0,{results:[{type:'pin',id:'123'}]});await responsePromise;await flush();
  assert.equal(requestHarness.api.readSearch(requestHarness.page()).resource.data.results.length,1,'Request-body first page is captured');
  const initialVersion=requestHarness.api.readSearch(requestHarness.page()).version;
  const pagingXhr=new requestHarness.env.XMLHttpRequest();pagingXhr.open('POST','/resource/BaseSearchResource/get/');
  pagingXhr.send(new URLSearchParams({source_url:'/search/pins/?q=garden',data:JSON.stringify({options:{query:'garden',bookmarks:['next']}})}).toString());
  pagingXhr.respond({resource_response:{status:'success',data:{results:[]},bookmark:'-end-'}});
  assert.equal(requestHarness.api.readSearch(requestHarness.page()).version,initialVersion,'empty pagination is not treated as an empty first page');
  h.env.PinmonySearchUiApiEnabled = false; assert.equal(h.filters(), null); assert.equal(h.hint(), null);
  const suggestions = harness();
  const endedSearch = harness();
  endedSearch.env.PinmonySearchApi = { context: () => ({ page: endedSearch.page(), bookmark: '-end-', filterBookmark: 'current-session-cursor' }) };
  assert.equal(endedSearch.filters().loading, true);
  assert.equal(endedSearch.requests.length, 1, 'finished pagination can still request filters');
  assert.equal(JSON.parse(new URLSearchParams(endedSearch.requests[0].init.body).get('data')).options.data.bookmark_string,
    'current-session-cursor');
  await endedSearch.respond(0, filterData);
  assert.equal(endedSearch.filters().options.length, 3);
  const getSuggestions = term => suggestions.api.readSuggestions(suggestions.page(), term, true, () => {});
  getSuggestions('海'); getSuggestions('海报');
  await new Promise(resolve => setTimeout(resolve, 280));
  assert.equal(suggestions.requests.length, 1, 'debounce only sends the latest query');
  const suggestionRequest = suggestions.requests[0];
  const opts = JSON.parse(new URL(suggestionRequest.url, suggestions.env.location.origin).searchParams.get('data')).options;
  assert.equal(opts.term, '海报'); assert.equal(opts.pin_scope, 'pins');
  assert.equal(new URL(suggestionRequest.url, suggestions.env.location.origin).pathname, '/resource/AdvancedTypeaheadResource/get/');
  getSuggestions('风景');
  assert.equal(suggestionRequest.init.signal.aborted, true);
  await suggestions.respond(0, { items: [{ query: '过期海报' }] });
  assert.equal(getSuggestions('风景').items.length, 0, 'old query suggestions are ignored');
  await new Promise(resolve => setTimeout(resolve, 280));
  await suggestions.respond(1, { items: [{ query: '风景', type: 'recent_query' }, { query: '风景' }, { label: 42 }] });
  assert.equal(getSuggestions('风景').items.length, 1, 'valid suggestions are bounded and deduplicated');
  getSuggestions(''); await new Promise(resolve => setTimeout(resolve, 280));
  suggestions.api.reset(); await suggestions.respond(2, { items: [{ query: '旧账号历史' }] });
  assert.equal(suggestions.api.readSuggestions(suggestions.page(), 'art', false, () => {}).items.length, 0, 'result route does not fetch historical suggestions');
  console.log('Search hint/filter API contracts, mapping, retry, fetch/XHR cursor and stale-response checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
