const assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const {createArktsLoader}=require('./arkts-module-loader.cjs');
const loader=createArktsLoader(ts,{'common_foundation':{PinmonyI18n:{message:k=>k},PinmonyRuntimeLog:{info(){},warn(){}},PinmonyTaskRegistry:class{}},'common_network':{PIN_BUSINESS_PIN_READ_ENABLED:true},'common_session':{},'@kit.RemoteCommunicationKit':{rcp:{}},'@kit.BasicServicesKit':{}});
const {PinmonySettingsNativeFlow}=loader.loadFile('entry/src/main/ets/app/PinmonySettingsNativeFlow.ets');
const {PinmonyNativeNetwork}=loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const {PinmonySettingsStore}=loader.loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets');
const origin='https://www.pinterest.com',page=origin+'/sample/';
function fixture(){
 const store=new PinmonySettingsStore();store.screen='boardRecovery';
 const session={authenticated:true,accountId:'synthetic',generation:1,origin};
 let boards=[{id:'301',name:'Synthetic board',pin_count:3,section_count:1,image_cover_url:'https://i.pinimg.com/synthetic.jpg'}],bad=false,hold;
 const network=Object.create(PinmonyNativeNetwork.prototype),requests=[],denied=[];network.cancel=()=>{};
 network.request=async(job,context)=>{
  if(!context().authenticated){denied.push(job);return {error:'denied',status:0};}
  const form=job.method==='GET'?new URL(job.url).searchParams:new URLSearchParams(job.body),o=JSON.parse(form.get('data')).options;requests.push({job,o});
  let data,endpoint;
  if(job.url.includes('/UserResource/get/'))data={id:'1',type:'user',username:'sample'};
  else if(o.url==='/v3/users/me/boards/soft_deleted/'){data=boards;endpoint='v3_get_soft_deleted_boards_for_user';}
  else if(o.url==='/v3/boards/301/restore/'){
   if(hold)return await hold;
   boards=[];data=null;endpoint=bad?'wrong_endpoint':'v3_restore_board';
  }else throw Error('unexpected request');
  return {status:200,body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data},client_context:{user:{id:'1'}}})};
 };
 const flow=new PinmonySettingsNativeFlow({store:()=>store,session:()=>session,network:()=>network,active:()=>true,page:()=>page});
 return {store,flow,requests,denied,session,network,bad:()=>bad=true,hold:p=>hold=p};
}
(async()=>{
 let f=fixture();await f.flow.requestAction('boardRecoveryRead','');assert(f.store.boardRecoveryReady);assert.equal(f.store.recoverableBoards.length,1);assert(!f.store.busy);
 await f.flow.requestAction('boardRecoveryRestore','999');assert(!f.requests.some(r=>r.o.url?.endsWith('/restore/')),'unlisted target never writes');
 await f.flow.requestAction('boardRecoveryRead','');await f.flow.requestAction('boardRecoveryRestore','301');assert(f.store.recoverableBoards[0].restored);assert(!f.store.writeUncertain);assert.equal(f.denied.length,0);
 const write=f.requests.find(r=>r.o.url?.endsWith('/restore/'));const count=f.requests.length;await f.flow.requestAction('boardRecoveryRestore','301');assert(!f.requests.slice(count).some(r=>r.o.url?.endsWith('/restore/')));
 const form=new URLSearchParams(write.job.body);form.set('data',JSON.stringify({options:{url:'/v3/boards/999/restore/'},context:{}}));
 assert((await f.network.requestBusinessProfileSettings({...write.job,body:form.toString()},()=>f.session,page,'1','1',['restore-board:301'],['own'],()=>true)).error,'transport blocks unlisted ID');
 f=fixture();await f.flow.requestAction('boardRecoveryRead','');f.bad();await f.flow.requestAction('boardRecoveryRestore','301');assert(f.store.writeUncertain);assert(!f.store.recoverableBoards[0].restored);const n=f.requests.length;await f.flow.requestAction('boardRecoveryRestore','301');assert.equal(f.requests.length,n,'unknown outcome never replays');
 f=fixture();await f.flow.requestAction('boardRecoveryRead','');let resolve;f.hold(new Promise(r=>resolve=r));const pending=f.flow.requestAction('boardRecoveryRestore','301');for(let i=0;i<8;i++)await new Promise(r=>setImmediate(r));assert(f.store.busy);f.flow.pause();await pending;assert(f.store.writeUncertain);resolve({status:200,body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_restore_board',data:null}})});await new Promise(r=>setImmediate(r));assert(!f.store.recoverableBoards[0].restored,'late success cannot commit');
 f.store.busy=false;f.store.back();assert.equal(f.store.screen,'display');f.store.reset();assert.equal(f.store.recoverableBoards.length,0);
 console.log('Board recovery: list, identity/transport guards, confirmed restore, unknown/no replay, cancellation/late response and back/reset passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
