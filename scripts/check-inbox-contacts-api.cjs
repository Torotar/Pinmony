const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
'use strict';
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const extract=p=>{const s=readSourceFileSync(p,'utf8');return vm.runInNewContext(s.slice(s.indexOf('`'),s.lastIndexOf('`')+1));};
const code=extract('entry/src/main/ets/services/PinmonyInboxContactsApiScript.ets');
new vm.Script(extract('entry/src/main/ets/services/PinmonyInboxScript.ets'));
const requests=[]; const w={PinmonyInboxContactsApiEnabled:true};w.top=w;
vm.runInNewContext(code,{window:w,location:{hostname:'uk.pinterest.com'},URL,URLSearchParams,AbortController,setTimeout,clearTimeout,
fetch:(url,init)=>new Promise((resolve,reject)=>requests.push({url,init,resolve,reject}))});
const api=w.PinmonyInboxContactsApi,page='https://uk.pinterest.com/inbox/';let count=0,current=true;
const changed=()=>count++,guard=()=>current,flush=()=>new Promise(r=>setImmediate(r));
function reply(n,data,extra={}){requests[n].resolve({ok:true,json:async()=>({resource_response:{status:'success',code:0,endpoint_name:'v3_user_contacts_suggestion',data,...extra}})});}
const user={id:'90071992547409930',type:'user_share_suggestion',username:'tester',full_name:'Test contact',image_medium_url:'https://i.pinimg.com/test.png'};
(async()=>{
let s=api.read(page,changed,guard);assert.equal(s.kind,'loading');assert.equal(api.read(page,changed,guard),s);assert.equal(requests.length,1);
assert.equal(requests[0].init.credentials,'same-origin');assert(!requests[0].init.headers.Cookie);
const q=new URL(requests[0].url,page).searchParams;assert.equal(q.get('source_url'),'/inbox/');assert.deepEqual(JSON.parse(q.get('data')),{options:{field_set_key:'default',hide_group_conversations:true},context:{}});
reply(0,[user,user]);await flush();assert.equal(s.kind,'ready');assert.equal(s.items.length,1);assert.equal(s.items[0].userId,user.id);assert.equal(s.items[0].title,'Test contact');assert.equal(s.items[0].subtitle,'@tester');assert.equal(s.items[0].enabled,false);
api.reset();s=api.read(page,changed,guard);reply(1,[]);await flush();assert.equal(s.kind,'ready');assert.equal(s.items.length,0);
api.reset();s=api.read(page,changed,guard);reply(2,[{...user,id:123}]);await flush();assert.equal(s.kind,'failed');assert.equal(s.items.length,0);
api.reset();s=api.read(page,changed,guard);reply(3,[user],{endpoint_name:'v3_create_conversation'});await flush();assert.equal(s.kind,'failed');
api.reset();s=api.read(page,changed,guard);requests[4].reject(new Error('network'));await flush();assert.equal(s.kind,'failed');
api.reset();s=api.read(page,changed,guard);reply(5,[user]);await flush();assert.equal(s.kind,'ready');
api.reset();s=api.read(page,changed,guard);const prior=count;api.reset();assert(requests[6].init.signal.aborted);reply(6,[user]);await flush();assert.equal(count,prior);assert.equal(s.kind,'loading');
s=api.read(page,changed,guard);current=false;reply(7,[user]);await flush();assert.equal(s.kind,'loading');api.reset();current=true;
w.PinmonyInboxContactsApiEnabled=false;assert.equal(api.read(page,changed,guard),null);assert.equal(requests.length,8);
console.log('PASS contacts API: same-origin contract, string identity, dedup, real labels, empty/error, retry, wrong endpoint, cancelled/stale response, manual flag; bridge syntax');
})().catch(e=>{console.error(e);process.exitCode=1;api.reset()});
