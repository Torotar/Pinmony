const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:deps,console});return exports;}
const {PinmonySearchUserFollow:Follow}=load('entry/src/main/ets/app/PinmonySearchUserFollow.ets');
const {PinmonyNativeNetwork:Network}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',name=>name==='common_session'?{PinmonySessionCredentials:class{}}:name==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{});
function fixture(){
 let active=true,session={authenticated:true,accountId:'fixture',generation:1,origin:'https://www.pinterest.com',userAgent:'test'},profile=session.origin+'/fixture/';
 const calls=[],messages=[],confirmed=[],net=new Network();
 net.request=async(job,context)=>{assert.equal(context().authenticated,true);return new Promise(resolve=>calls.push({job,resolve}));};
 const flow=new Follow({session:()=>session,profile:()=>profile,network:()=>net,changed(){},feedback:m=>messages.push(m),confirmed:(...args)=>confirmed.push(args)});
 const item={id:'api-board-123',kind:'user',userId:'123',targetUrl:profile,following:false};
 return {flow,item,calls,messages,confirmed,net,owner:()=>active,session:()=>session,profile:()=>profile,leave(){active=false;flow.pause();},switchAccount(){session={...session,accountId:'other',generation:2};flow.reset();}};
}
function reply(call,desired=true,extra={}){return {...call.job,error:'',status:200,body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:desired?'v3_follow_user_method':'v3_unfollow_user_method',data:{id:'123',type:'user',username:'fixture'},...extra},client_context:{user:{id:'22'}}})};}
async function main(){
 let f=fixture(),p=f.flow.submit(f.item,'22',f.owner);assert.equal(f.calls.length,1);assert(f.flow.busy('123'));await f.flow.submit(f.item,'22',f.owner);assert.equal(f.calls.length,1);
 const job=f.calls[0].job;assert.equal(job.url,f.session().origin+'/resource/ApiResource/update/');assert.equal(job.headers['X-Pinterest-Pws-Handler'],'www/[username].js');
 assert.deepEqual(JSON.parse(new URLSearchParams(job.body).get('data')),{options:{url:'/v3/users/123/follow/',data:{}},context:{}});
 f.calls[0].resolve(reply(f.calls[0]));await p;assert.deepEqual(f.confirmed,[['123',true]]);assert(!f.flow.locked('123'));
 f.item.following=true;p=f.flow.submit(f.item,'22',f.owner);assert(f.calls[1].job.url.endsWith('/delete/'));f.calls[1].resolve(reply(f.calls[1],false));await p;assert.deepEqual(f.confirmed[1],['123',false]);
 f=fixture();p=f.flow.submit(f.item,'22',f.owner);f.calls[0].resolve(reply(f.calls[0],true,{data:{id:'999',type:'user',username:'fixture'}}));await p;assert(f.flow.locked('123'));assert.equal(f.confirmed.length,0);await f.flow.submit(f.item,'22',f.owner);assert.equal(f.calls.length,1);f.flow.reconcile('123',false);assert(f.flow.locked('123'));f.flow.reconcile('123',true);assert(!f.flow.locked('123'));
 f=fixture();p=f.flow.submit(f.item,'22',f.owner);f.calls[0].resolve(reply(f.calls[0],true,{status:'failure',code:9}));await p;assert(!f.flow.locked('123'));assert.equal(f.confirmed.length,0);
 f=fixture();p=f.flow.submit(f.item,'22',f.owner);f.leave();await p;assert(f.flow.locked('123'));f.calls[0].resolve(reply(f.calls[0]));await Promise.resolve();assert.equal(f.confirmed.length,0);
 f=fixture();p=f.flow.submit(f.item,'22',f.owner);f.switchAccount();await p;f.calls[0].resolve(reply(f.calls[0]));await Promise.resolve();assert.equal(f.confirmed.length,0);
 f=fixture();await f.flow.submit({...f.item,following:undefined},'22',f.owner);await f.flow.submit(f.item,'',f.owner);assert.equal(f.calls.length,0);
 f=fixture();await f.flow.submit({...f.item,blocked:true},'22',f.owner);await f.flow.submit({...f.item,userId:'22'},'22',f.owner);assert.equal(f.calls.length,0);
 f=fixture();p=f.flow.submit(f.item,'22',f.owner);f.calls[0].resolve(reply(f.calls[0],true,{data:null}));await p;assert(f.flow.locked('123'));
 f=fixture();p=f.flow.submit(f.item,'22',f.owner);const wrong=reply(f.calls[0]);const wrongBody=JSON.parse(wrong.body);wrongBody.client_context.user.id='99';wrong.body=JSON.stringify(wrongBody);f.calls[0].resolve(wrong);await p;assert(f.flow.locked('123'));assert.equal(f.confirmed.length,0);
 const safeJob=fixture();p=safeJob.flow.submit(safeJob.item,'22',safeJob.owner);const base=safeJob.calls[0].job;const gate=new Network();gate.request=async(job,context)=>({allowed:context().authenticated});
 const probe=job=>gate.requestBusinessSearchUserFollow(job,safeJob.session,safeJob.profile(),'123','22',()=>true);
 assert.equal((await probe(base)).allowed,true);
 assert.equal((await probe({...base,headers:{...base.headers,'X-Pinterest-Pws-Handler':'www/search/[scope].js'}})).allowed,false);
 assert.equal((await probe({...base,body:base.body.replace('source_url=%2Ffixture%2F','source_url=%2Fother%2F')})).allowed,false);
 const parts=new URLSearchParams(base.body);const env=JSON.parse(parts.get('data'));env.options.data=1;const invalid={...base,body:'source_url='+encodeURIComponent('/fixture/')+'&data='+encodeURIComponent(JSON.stringify(env))};assert.equal((await probe(invalid)).allowed,false);
 safeJob.leave();await p;
 const page=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');assert(page.includes('this.onFollowUser(result.id)'));assert(page.includes('result.followBusy'));assert(page.includes('result.canFollow === true'));
 console.log('Search user follow: existing transport contract, follow/unfollow confirmation, double click, unknown locks, rejection, cancellation, account change and UI wiring passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
