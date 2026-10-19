const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
function load(path,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:withLocalMessages(deps)});return exports;}
const Writer=load('entry/src/main/ets/app/PinmonyBoardSectionNativeWrites.ets').PinmonyBoardSectionNativeWrites;
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',page=origin+'/sample/board/';
function fixture(phase='targets'){
 let state={phase,sectionId:'200',sectionTitle:'Section',pins:[],targets:[],saved:[],busy:false,loading:false,uncertain:false,error:''};
 let session={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'synthetic'};
 let identity={page,board:'100',section:'200',viewer:'42',owner:'42',intent:1,allIds:['1','2','3'],selectedIds:['1','3'],complete:true,targets:['100','300']};
 const requests=[],confirmed=[],cancelled=[],network=new Network();network.cancel=id=>cancelled.push(id);
 network.request=(job,ctx)=>{if(!acceptsNetworkJob(job,ctx()))return Promise.resolve({error:'reject',status:0,body:''});return new Promise(resolve=>requests.push({job,resolve:(endpoint,data=null,code=0)=>resolve({error:'',status:200,body:JSON.stringify({resource_response:{status:'success',code,endpoint_name:endpoint,data},client_context:{user:{id:'42'}}})})}));};
 const writer=new Writer({state:()=>state,identity:()=>identity,session:()=>session,network:()=>network,changed:f=>state=f,confirmed:a=>confirmed.push(a)});
 return {writer,requests,confirmed,cancelled,state:()=>state,setState:f=>state=f,identity:()=>identity,session:()=>session,setSession:s=>session=s};
}
async function main(){
 const cross=fixture();cross.identity().targets.push('section:300:400');const crossPending=cross.writer.submit('move','section:300:400');assert.equal(cross.requests.length,1);const crossJob=cross.requests[0].job;assert.deepEqual(JSON.parse(new URLSearchParams(crossJob.body).get('data')).options.data,{new_board_id:'300',old_section_id:'200',new_section_id:'400',exclude_pin_ids:['2']});cross.requests[0].resolve('v3_board_bulk_move');await crossPending;assert.deepEqual(cross.confirmed,['move']);
 const crossPolicy=new Network();crossPolicy.request=async(job,context)=>({error:acceptsNetworkJob(job,context())?'':'reject'});
 const crossAllowed=(job,targets=['100','300','section:300:400'])=>crossPolicy.requestBusinessBoardSectionWrite(job,()=>cross.session(),'100','200','42','42',['1','2','3'],['1','3'],true,targets,()=>true);
 assert.equal((await crossAllowed(crossJob)).error,'');assert((await crossAllowed(crossJob,['100','300'])).error);assert((await crossAllowed(crossJob,['100','section:300:400'])).error);
 const tamper=new URLSearchParams(crossJob.body),tampered=JSON.parse(tamper.get('data'));tampered.options.data.new_board_id='100';tamper.set('data',JSON.stringify(tampered));assert((await crossAllowed({...crossJob,body:tamper.toString()})).error);
 const sectionMove=fixture();sectionMove.identity().targets.push('section:400');let sectionPending=sectionMove.writer.submit('move','section:400');assert.equal(sectionMove.requests.length,1);const sectionJob=sectionMove.requests[0].job;
 assert.deepEqual(JSON.parse(new URLSearchParams(sectionJob.body).get('data')).options.data,{new_board_id:'100',old_section_id:'200',new_section_id:'400',exclude_pin_ids:['2']});
 await sectionMove.writer.submit('move','section:400');assert.equal(sectionMove.requests.length,1);sectionMove.requests[0].resolve('v3_board_bulk_move');await sectionPending;assert.deepEqual(sectionMove.confirmed,['move']);
 const sectionPolicy=new Network();sectionPolicy.request=async(job,context)=>({error:acceptsNetworkJob(job,context())?'':'reject'});
 const sectionAllowed=job=>sectionPolicy.requestBusinessBoardSectionWrite(job,()=>sectionMove.session(),'100','200','42','42',['1','2','3'],['1','3'],true,['100','300','section:400'],()=>true);
 assert.equal((await sectionAllowed(sectionJob)).error,'');
 for(const mutate of [d=>d.new_board_id='300',d=>d.new_section_id='200',d=>d.new_section_id='999',d=>d.exclude_pin_ids=[]]){const form=new URLSearchParams(sectionJob.body),e=JSON.parse(form.get('data'));mutate(e.options.data);form.set('data',JSON.stringify(e));assert((await sectionAllowed({...sectionJob,body:form.toString()})).error);}
 const self=fixture();self.identity().targets.push('section:200');await self.writer.submit('move','section:200');assert.equal(self.requests.length,0);
 const reads=new Network();reads.request=async(job,context)=>({error:acceptsNetworkJob(job,context())?'':'reject'});
 const context={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'synthetic'};
 const readJob=(resource,options,source,handler)=>({id:'native_board_section_read_1',epoch:1,page,url:origin+'/resource/'+resource+'/get/?source_url='+encodeURIComponent(source)+'&data='+encodeURIComponent(JSON.stringify({options,context:{}}))+'&_=1',method:'GET',body:'',headers:{Accept:'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':handler}});
 const toolFields=['boardtool.id','boardtool.type','boardtool.tool','boardtool.text','boardtool.icon','boardtool.link','boardtool.show_badge'];
 const readCases=[readJob('BoardSectionResource',{section_id:'200'},'/boardsection/200/organize/repin/','www/boardsection/[id]/organize/add.js'),readJob('ApiResource',{url:'/v3/boards/sections/200/tools/',data:{fields:toolFields}},'/sample/board/section/','www/[username]/[slug]/[section_slug].js'),readJob('BoardContentRecommendationResource',{id:'100',type:'board',__track__referrer:24},'/sample/board/section/_tools/more-ideas/?ideas_referrer=24','www/[username]/[slug]/[section_slug]/_tools/more-ideas.js')];
 for(const job of readCases){assert.equal((await reads.requestBusinessBoardSectionRead(job,()=>context,'100','200','/sample/board/section/',()=>true)).error,'');assert((await reads.requestBusinessBoardSectionRead({...job,method:'POST'},()=>context,'100','200','/sample/board/section/',()=>true)).error);assert((await reads.requestBusinessBoardSectionRead(job,()=>context,'100','201','/sample/board/other/',()=>true)).error);assert((await reads.requestBusinessBoardSectionRead(job,()=>context,'100','200','/sample/board/section/',()=>false)).error);}
 for(const title of ['', '   ', 'x'.repeat(101)]){const r=fixture('sectionEdit');await r.writer.submit('rename',title);assert.equal(r.requests.length,0);}
 const rename=fixture('sectionEdit');let renamed=rename.writer.submit('rename','New section');assert.equal(rename.requests.length,1);
 const renameJob=rename.requests[0].job,renameOptions=JSON.parse(new URLSearchParams(renameJob.body).get('data')).options;
 assert.equal(renameJob.url,origin+'/resource/ApiResource/update/');assert.equal(renameOptions.data.title,'New section');assert.equal(renameOptions.url,'/v3/board/sections/200/');
 rename.requests[0].resolve('v3_edit_section',{id:'200',title:'New section',type:'board_section',board:{id:'100'}});await renamed;assert.deepEqual(rename.confirmed,['rename']);
 for(const patch of [{id:'201'},{title:'Wrong'},{board:{id:'999'}},{type:'pin'}]){const r=fixture('sectionEdit');const p=r.writer.submit('rename','New section');r.requests[0].resolve('v3_edit_section',{id:'200',title:'New section',type:'board_section',board:{id:'100'},...patch});await p;assert(r.state().uncertain);assert.equal(r.confirmed.length,0);}
 const f=fixture();let pending=f.writer.submit('move','300');assert(f.state().busy);assert.equal(f.requests.length,1);
 let job=f.requests[0].job,form=new URLSearchParams(job.body),options=JSON.parse(form.get('data')).options;
 assert.equal(form.get('source_url'),'/boardsection/200/organize/repin/');assert.deepEqual(options,{url:'/v3/boards/100/bulk/',data:{new_board_id:'300',old_section_id:'200',exclude_pin_ids:['2']}});
 await f.writer.submit('move','300');assert.equal(f.requests.length,1);f.requests[0].resolve('v3_board_bulk_move');await pending;assert.deepEqual(f.confirmed,['move']);
 const policy=new Network();policy.request=async(job,ctx)=>({error:acceptsNetworkJob(job,ctx())?'':'reject'});
 const allowed=(job,complete=true,owner='42')=>policy.requestBusinessBoardSectionWrite(job,()=>f.session(),'100','200','42',owner,['1','2','3'],['1','3'],complete,['100','300'],()=>true);
 assert.equal((await allowed(job)).error,'');assert((await allowed(job,false)).error);assert((await allowed(job,true,'99')).error);
 for(const mutate of [o=>o.data.exclude_pin_ids=[],o=>o.data.new_board_id='999',o=>o.data.old_section_id='201',o=>o.data.extra=true]){const payload=JSON.parse(form.get('data'));mutate(payload.options);const bad=new URLSearchParams(job.body);bad.set('data',JSON.stringify(payload));assert((await allowed({...job,body:bad.toString()})).error);}
 for(const patch of [{complete:false},{selectedIds:[]},{selectedIds:['9']},{selectedIds:['1','1']},{owner:'99'}]){const g=fixture();Object.assign(g.identity(),patch);await g.writer.submit('move','300');assert.equal(g.requests.length,0);}
 const deletion=fixture('sectionEdit');pending=deletion.writer.submit('delete');assert.equal(deletion.requests.length,1);job=deletion.requests[0].job;assert.deepEqual(JSON.parse(new URLSearchParams(job.body).get('data')).options,{url:'/v3/board/sections/200/'});assert.equal((await allowed(job)).error,'');deletion.requests[0].resolve('v3_delete_board_section');await pending;assert.deepEqual(deletion.confirmed,['delete']);
 const unknown=fixture();pending=unknown.writer.submit('move','100');unknown.requests[0].resolve('wrong_endpoint');await pending;assert(unknown.state().uncertain);unknown.writer.pause();unknown.setState({...unknown.state(),busy:false,uncertain:false});await unknown.writer.submit('move','100');assert.equal(unknown.requests.length,1,'unknown writes never replay after close');
 const paused=fixture();pending=paused.writer.submit('move','300');paused.writer.pause();await pending;assert(paused.state().uncertain);assert.equal(paused.cancelled.length,1);paused.requests[0].resolve('v3_board_bulk_move');await Promise.resolve();assert.equal(paused.confirmed.length,0);
 const stale=fixture('sectionEdit');pending=stale.writer.submit('delete');stale.setSession({...stale.session(),generation:2});stale.requests[0].resolve('v3_delete_board_section');await pending;assert.equal(stale.confirmed.length,0);
 console.log('Board section writes: captured delete/bulk contracts, exact exclusion complement, full enumeration, ownership/targets, strict transport, duplicate/cancel/stale and unknown-result locks passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
