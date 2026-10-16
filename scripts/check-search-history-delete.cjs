const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('feature_search/src/main/ets/services/PinmonySearchUiApiScript.ets','utf8');
const tick=String.fromCharCode(96),script=Function('return '+source.slice(source.indexOf(tick),source.lastIndexOf(tick)+1))();
const flush=()=>new Promise(r=>setImmediate(r));
async function main(){
 const requests=[];const env={URL,URLSearchParams,AbortController,setTimeout,clearTimeout,PinmonySearchUiApiEnabled:true,location:{hostname:'www.pinterest.com',origin:'https://www.pinterest.com',pathname:'/search/',search:'',href:'https://www.pinterest.com/search/'},fetch:(url,init)=>new Promise(resolve=>requests.push({url,init,resolve}))};env.window=env;env.top=env;vm.runInNewContext(script,env);
 const api=env.PinmonySearchUiApi,page=env.location.href,read=()=>api.readSuggestions(page,'',true,()=>{});
 const reply=async(i,resource)=>{requests[i].resolve({ok:true,json:async()=>({resource_response:resource})});await flush();};
 read();await new Promise(r=>setTimeout(r,280));
 const items=[{query:'raw-query',display_query:'Display text',type:'recent_query',vertical:'pins'},{query:'personal',display_query:'Personal',type:'recent_personal_searches',vertical:'personal'}];
 await reply(0,{status:'success',data:{items}});let values=read().items;assert.equal(values[0].deletable,true);assert.equal(values[1].deletable,false);
 assert.equal(await api.deleteHistory(page,values[1].id),false);assert.equal(await api.deleteHistory(page+'old',values[0].id),false);
 let pending=api.deleteHistory(page,values[0].id);assert.equal(read().items[0].deleting,true);assert.equal(await api.deleteHistory(page,values[0].id),false);
 assert.equal(requests[1].url,'/resource/ApiResource/delete/');assert.equal(requests[1].init.method,'POST');
 assert.deepEqual(JSON.parse(new URLSearchParams(requests[1].init.body).get('data')).options,{url:'/v3/search/recent/',data:{query:'raw-query',vertical:'PIN'}});
 await reply(1,{status:'success',code:1,endpoint_name:'v3_recent_search_delete',data:null});assert.equal(await pending,false);assert.equal(read().items.length,2);assert.match(read().error,/未能确认/);assert.equal(requests.length,2);
 pending=api.deleteHistory(page,values[0].id);await reply(2,{status:'success',code:0,endpoint_name:'v3_recent_search_delete',data:null});assert.equal(await pending,true);assert.equal(read().items.length,1);assert.equal(requests.length,4);
 await reply(3,{status:'success',data:{items}});values=read().items;
 pending=api.deleteHistory(page,values[0].id);api.reset();assert.equal(requests[4].init.signal.aborted,true);await reply(4,{status:'success',code:0,endpoint_name:'v3_recent_search_delete',data:null});assert.equal(await pending,false);assert.equal(requests.length,5);api.reset();
 api.readSuggestions(page,'',false,()=>{});await reply(5,{status:'success',data:{items}});
 api.refreshSuggestions();assert.equal(read().busy,false);assert.equal(read().items.length,2);
 assert.equal(requests.length,6,'opening empty input reuses current-document history without clearing or rereading it');
 api.reset();read();assert.equal(read().busy,true);assert.equal(requests.length,7,'new document still reads fresh history');
 await reply(6,{status:'success',data:{items:[]}});assert.equal(read().items.length,0);api.reset();
 console.log('search history delete and refresh: passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
