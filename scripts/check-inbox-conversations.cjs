const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const s=readSourceFileSync('entry/src/main/ets/services/PinmonyInboxConversationScript.ets','utf8');const code=vm.runInNewContext(s.slice(s.indexOf('`'),s.lastIndexOf('`')+1));
const requests=[],events=[];const w={PinmonyInboxConversationsEnabled:true};w.top=w;w.PinmonyShareBridge={inboxState:x=>events.push(JSON.parse(x))};
vm.runInNewContext(code,{window:w,location:{hostname:'uk.pinterest.com',origin:'https://uk.pinterest.com',pathname:'/inbox/'},document:{cookie:'csrftoken=test-fixture'},URLSearchParams,AbortController,setTimeout,clearTimeout,
fetch:(url,args)=>new Promise(resolve=>requests.push({url,args,resolve}))});
const api=w.PinmonyInboxConversations,flush=()=>new Promise(r=>setImmediate(r));
const me={id:'1',full_name:'Self'},other={id:'2',full_name:'Other',image_medium_url:'https://i.pinimg.com/avatar.png'};
function reply(i,endpoint,data,bookmark='-end-'){requests[i].resolve({ok:true,json:async()=>({resource_response:{status:'success',code:0,endpoint_name:endpoint,data,bookmark},client_context:{user:me}})});}
const latest=()=>events.at(-1);
function checkContext(){assert.equal(requests[0].args.headers['X-Pinterest-AppState'],'active');assert.equal(requests[0].args.headers['X-Pinterest-Source-Url'],'/inbox/');assert.equal(requests[0].args.headers['X-Pinterest-Pws-Handler'],'www/index.js');assert.equal(requests[0].args.credentials,'same-origin');}
(async()=>{
let list=api.read('https://uk.pinterest.com/inbox/',()=>{},()=>true);reply(0,'v3_get_conversations',[{id:'100',users:[me,other],unread:1,last_message:{sender:me,pin:{id:'200'},created_at:'2026-10-01T12:00:00Z'}}]);await flush();assert.equal(list.kind,'ready');assert.equal(list.items[0].title,'Other');assert.equal(list.items[0].subtitle,'你发送了一张 Pin 图');assert.equal(list.items[0].unread,true);
assert(api.open('conversation:100',7));reply(1,'v3_get_conversation',{id:'100',users:[me,other]});await flush();reply(2,'v3_get_conversation_messages',[{id:'300',sender:other,created_at:'2026-10-01T12:00:00Z',pin:{id:'200',images:{'236x':{url:'https://i.pinimg.com/pin.png'}}}},{id:'301',sender:me,text:'hello',created_at:'2026-10-01T12:01:00Z'}]);await flush();assert.equal(latest().screen,'chat');assert.equal(latest().title,'Other');assert(!latest().messages[0].own);assert(latest().messages[1].own);assert.equal(latest().messages[0].image,'https://i.pinimg.com/pin.png');
assert(api.action('settings','',7));assert.equal(latest().screen,'settings');assert(api.action('back','',7));assert.equal(latest().screen,'chat');assert(!api.action('back','',8));
assert(api.open('compose',7));assert(api.action('search','other',7));reply(3,'v3_user_contacts_suggestion',[me]);reply(4,'v3_user_contacts_suggestion_search',{items:[other]});await flush();assert.equal(latest().users[0].id,'2');assert(api.action('select','2',7));assert(api.action('next','',7));assert(!api.action('next','',7));assert.equal(requests[5].args.method,'POST');assert.equal(requests[5].args.credentials,'same-origin');assert.equal(JSON.parse(new URLSearchParams(requests[5].args.body).get('data')).options.user_ids[0],'2');
reply(5,'v3_create_conversation',{id:'101'});await flush();reply(6,'v3_get_conversation',{id:'101',users:[me,other]});await flush();reply(7,'v3_get_conversation_messages',[]);await flush();assert.equal(latest().screen,'chat');api.action('settings','',7);api.action('back','',7);assert.equal(latest().screen,'chat');api.action('back','',7);assert.equal(latest().screen,'compose');api.action('back','',7);assert.equal(latest().screen,'closed');
api.open('compose',7);reply(8,'v3_user_contacts_suggestion',[other]);await flush();api.action('select','2',7);api.action('next','',7);api.action('back','',7);reply(9,'v3_create_conversation',{id:'102'});await flush();assert.equal(requests.length,10);assert.equal(latest().screen,'closed');
w.PinmonyInboxApi={find:id=>id==='known'?{}:null};assert(api.open('news-menu:known',7));assert.equal(latest().screen,'updatesMenu');assert(!api.open('news-menu:unknown',7));api.action('back','',7);
api.reset();list=api.read('https://uk.pinterest.com/inbox/',()=>{},()=>true);api.reset();assert(requests[10].args.signal.aborted);reply(10,'v3_get_conversations',[]);await flush();assert.equal(list.kind,'loading');
list=api.read('https://uk.pinterest.com/inbox/',()=>{},()=>true);
requests[11].resolve({ok:true,json:async()=>({resource_response:{status:'success',data:[]}})});await flush();assert.equal(list.kind,'ready');
api.reset();list=api.read('https://uk.pinterest.com/inbox/',()=>{},()=>true);
requests[12].resolve({ok:true,json:async()=>({resource_response:{status:'success',code:9,data:[]}})});await flush();assert.equal(list.kind,'failed');assert(list.error.includes('业务状态'));
api.reset();list=api.read('https://uk.pinterest.com/inbox/',()=>{},()=>true);
requests[13].resolve({ok:false,status:403});await flush();assert.equal(list.kind,'failed');assert(list.error.includes('HTTP 403'));
api.reset();list=api.read('https://uk.pinterest.com/inbox/',()=>{},()=>true);
requests[14].resolve({ok:true,json:async()=>{throw new SyntaxError('fixture')}});await flush();assert(list.error.includes('JSON'));api.reset();
const off={PinmonyInboxConversationsEnabled:false};off.top=off;vm.runInNewContext(code,{window:off,location:{hostname:'uk.pinterest.com'}});assert(!off.PinmonyInboxConversations);
console.log('PASS native inbox flows: list/participants/messages, sender identity, image, search races, creation confirmation, duplicate create guard, hierarchical back, cancelled response, menu identity, feature flag');
checkContext();
})().catch(e=>{console.error(e);process.exitCode=1;api.reset()});

