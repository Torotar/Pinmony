const { readSourceFileSync } = require('./source-files.cjs');
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

(async()=>{
 const h=harness();const modules=[{action:{type:'contenttypefiltermoduleaction',title:'筛选器',filters:[
 {type:'filteroption',display:{display_text:'所有 Pin 图'},action:{type:'onebarmoduleaction',feed_url:'/search/pins/?q=garden&rs=content_type_filter'},is_selected:true},
 {type:'filteroption',display:{display_text:'视频'},action:{type:'onebarmoduleaction',feed_url:'/search/videos/?q=garden&rs=content_type_filter'}},
 {type:'filteroption',display:{display_text:'禁用'},action:{type:'onebarmoduleaction',feed_url:'/search/boards/?q=garden'},disabled:true},
 {type:'filteroption',display:{display_text:'跨域'},action:{type:'onebarmoduleaction',feed_url:'https://example.com/search/pins/?q=garden'}},
 {type:'filteroption',display:{display_text:'旧关键词'},action:{type:'onebarmoduleaction',feed_url:'/search/users/?q=old'}}
 ]}}];
 let native={page:h.page(),filterModules:modules};h.env.PinmonySearchApi={context:()=>native};
 let state=h.filters();assert.equal(state.status,'ready');assert.equal(state.options.length,5);assert.equal(h.requests.length,0);
 assert.equal(state.options[0].selected,true);assert.equal(state.options[1].enabled,true);assert.equal(state.options[2].enabled,false);assert.equal(state.options[3].enabled,false);assert.equal(state.options[4].enabled,false);
 assert.equal(h.api.filterTarget(h.page(),state.options[1].id),'https://www.pinterest.com/search/videos/?q=garden&rs=content_type_filter');
 const old=state.options[1].id;native={page:h.page(),filterModules:[]};state=h.filters();assert.equal(state.status,'empty');assert.equal(state.options.length,0);assert.equal(h.api.filterTarget(h.page(),old),'');assert.equal(h.requests.length,0);
 native={page:h.page(),filterModules:null};h.api.retryFilters();state=h.filters();assert.equal(state.status,'unavailable');assert.equal(h.requests.length,0);
 native={page:h.page(),filterModules:modules};h.filters();h.env.location.search='?q=new';assert.equal(h.api.filterTarget(h.page(),old),'');
 console.log('Search response filters: no obsolete request, real feed URL, selection/disabled, unsafe targets, empty/unavailable and stale ids passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
