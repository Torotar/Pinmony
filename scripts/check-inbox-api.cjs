const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('assert');
function script(p){const s=readSourceFileSync(p,'utf8');return vm.runInNewContext(s.slice(s.indexOf('`'),s.lastIndexOf('`')+1));}
const code=script('entry/src/main/ets/services/PinWebInboxApiScript.ets');
new vm.Script(script('entry/src/main/ets/services/PinWebInboxScript.ets'));
let requests=[],resolve;const window={PinWebInboxApiEnabled:true};window.top=window;
const context={window,location:{hostname:'uk.pinterest.com'},URLSearchParams,AbortController,setTimeout,clearTimeout,fetch:(url,init)=>{requests.push({url,init});return new Promise(r=>resolve=r)}};
vm.runInNewContext(code,context);
const api=window.PinWebInboxApi;let changes=0;const changed=()=>changes++,current=()=>true;
const flush=()=>new Promise(r=>setImmediate(r));
function response(data,bookmark=''){resolve({ok:true,json:async()=>({resource_response:{status:'success',code:0,endpoint_name:'v3_get_news_hub_feed',data,bookmark}})});}
(async()=>{
let state=api.read('page',changed,current);assert.equal(state.kind,'loading');assert.equal(requests[0].init.credentials,'same-origin');
const options=JSON.parse(new URL(requests[0].url,'https://uk.pinterest.com').searchParams.get('data')).options;assert.equal(options.url,'/v3/news_hub/feed/');assert.equal(options.data.field_set_key,'unauthed');
const row={unread:false,last_updated_at:'Wed, 30 Sep 2026 04:30:31 +0000',type:'news',id:'1',header_text:'探索 {search}',text_mapping:{search:{t:'设计'}},header_icon_image_url:'https://i.pinimg.com/x.png'};
response([row],'cursor');await flush();assert.equal(state.items[0].title,'探索 设计');assert.equal(state.kind,'ready');assert(state.hasMore);assert.equal(state.items[0].unread,false);assert.equal(state.items[0].updatedAt,row.last_updated_at);
assert(api.more(changed,current));assert(!api.more(changed,current));assert.deepEqual(JSON.parse(new URL(requests[1].url,'https://uk.pinterest.com').searchParams.get('data')).options.bookmarks,['cursor']);response([row],'-end-');await flush();assert.equal(state.items.length,1);assert(!state.hasMore);
api.reset();state=api.read('other',changed,current);response([{type:'news',id:'2',header_text:'{unknown}'}]);await flush();assert.equal(state.kind,'failed');
api.reset();state=api.read('empty',changed,current);response([]);await flush();assert.equal(state.kind,'ready');assert.equal(state.items.length,0);
api.reset();state=api.read('stale',changed,current);api.reset();response([row]);await flush();assert.equal(state.kind,'loading');
window.PinWebInboxApiEnabled=false;assert.equal(api.read('off',changed,current),null);
console.log('PASS inbox API: contract, mapping, pagination, malformed/empty, stale response, feature switch; bridge syntax');
})().catch(e=>{console.error(e);process.exitCode=1});

