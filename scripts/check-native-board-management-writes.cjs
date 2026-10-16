const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function load(file, deps = () => ({})) {
  const exports = {}; vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
    {exports,require:deps,setTimeout,clearTimeout,console});return exports;
}
const logs=[], log={PinmonyRuntimeLog:{info:s=>logs.push(s)}};
const management=load('entry/src/main/ets/app/PinmonyBoardManagementNativeWrites.ets',n=>n==='common_foundation'?log:{}), Writer=management.PinmonyBoardManagementNativeWrites;
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com', page=origin+'/sample/board/';
const board={type:'board',id:'100',name:'Board',url:'/sample/board/',privacy:'public',owner:{id:'42',username:'sample'},pin_count:2,section_count:0};
const edit={name:'Renamed',description:'New description',privacy:'secret',recommend:false,invites:true,requests:false};
const result=(data,endpoint='',viewer='42')=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data},client_context:{user:{id:viewer}}});
const flush=()=>new Promise(setImmediate);
function fixture(action='editSave') {
  const member=['leave','unfollow'].includes(action);let state={phase:action==='archive'?'archive':action==='unfollow'?'':'edit',loading:false,busy:false,uncertain:false,error:'',description:'',privacy:'public',recommend:true,invites:true,requests:true,pins:[],targets:[],saved:[],hasMore:false};
  let identity={page,boardId:'100',ownerId:'42',ownerUsername:'sample',viewerId:member?'43':'42',member,followed:true,intent:7};
  let session={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'synthetic'};const requests=[],cancelled=[],commits=[],snapshots=[];
  const writer=new Writer({state:()=>state,page:()=>page,identity:()=>identity,session:()=>session,network:()=>({cancel:id=>cancelled.push(id),requestBusinessBoardManagementWrite(job,s,b,v,o,m,current){assert(current());return new Promise(resolve=>requests.push({job,b,v,o,m,current,resolve:(body,status=200,error='')=>resolve({body,status,error})}));}}),changed:f=>{snapshots.push(f);state=f},confirmed:(...args)=>commits.push(args)});
  return {writer,requests,cancelled,commits,snapshots,state:()=>state,identity:()=>identity,session:()=>session,setState:f=>state=f,setIdentity:i=>identity=i,setSession:s=>session=s,
    submit:(value=edit)=>writer.submit(JSON.stringify({action,value}))};
}
const endpoints={editSave:'v3_edit_board',delete:'v3_delete_board',archive:'v3_archive_board',leave:'v3_remove_board_collaborators',unfollow:'v3_unfollow_board'};
function success(action) {return action==='editSave'?{...board,name:edit.name,privacy:edit.privacy,url:'/sample/renamed/'}:action==='leave'?{...board,collaborated_by_me:false}:null;}
async function main(){
  const jobs={};
  for(const action of Object.keys(endpoints)) {
    const f=fixture(action),old=f.state(),pending=f.submit();assert.equal(f.state().busy,true);assert.notEqual(f.state(),old);await f.submit();assert.equal(f.requests.length,1);
    jobs[action]=f.requests[0].job;const q=new URLSearchParams(jobs[action].body),o=JSON.parse(q.get('data')).options;
    if(action==='editSave'){assert.equal(o.name,edit.name);assert.equal(o.sensitivity,null);assert.equal(q.get('source_url'),'/board/100/edit/');assert.equal(Object.keys(o).length,8);}
    if(action==='leave')assert.equal(o.url,'/v3/boards/100/collaborators/43/');
    if(action==='unfollow')assert.equal(o.url,'/v3/boards/100/follow/');
    if(action==='archive'){assert.equal(o.url,'/v3/boards/100/archive/');assert.equal(jobs[action].headers['X-Pinterest-Pws-Handler'],'www/[username]/[slug].js');}
    f.requests[0].resolve(result(success(action),endpoints[action],f.identity().viewerId));await pending;assert.equal(f.commits.length,1);assert.equal(f.state().busy,false);assert.equal(f.state().uncertain,false);
    if(action==='editSave')assert.equal(f.commits[0][2],origin+'/sample/renamed/');
  }
  // Role, phase, loading, previous uncertain result and input gate reject before dispatch.
  for(const action of Object.keys(endpoints))for(const change of [f=>f.setState({...f.state(),busy:true}),f=>f.setState({...f.state(),loading:true}),f=>f.setState({...f.state(),uncertain:true}),f=>f.setState({...f.state(),phase:'ideas'}),f=>f.setIdentity({...f.identity(),viewerId:'99',member:false}),f=>f.setSession({...f.session(),authenticated:false})]) {
    const f=fixture(action);change(f);await f.submit();assert.equal(f.requests.length,0,action);
  }
  for(const v of [{...edit,name:' '},{...edit,privacy:'unknown'},{...edit,description:5},{...edit,invites:1}]){const f=fixture();await f.submit(v);assert.equal(f.requests.length,0);}
  const off=fixture('unfollow');off.setIdentity({...off.identity(),followed:false});await off.submit();assert.equal(off.requests.length,0);
  for(const action of ['leave','unfollow']){const f=fixture(action);f.setIdentity({...f.identity(),viewerId:'42',member:true});await f.submit();assert.equal(f.requests.length,0);}
  // Foreign responses and rename routes never confirm, never automatically repeat the write.
  const wrong=[{...success('editSave'),id:'999'},{...success('editSave'),owner:{id:'99'}},{...success('editSave'),name:'Other'},{...success('editSave'),privacy:'public'},
    {...success('editSave'),url:'https://uk.pinterest.com/sample/renamed/'},{...success('editSave'),url:'/other/renamed/'},{...success('editSave'),url:'/sample/pins/'},{...success('editSave'),url:'/sample/%2Fbad/'},{...success('editSave'),url:'/sample/renamed/?q=x'}];
  for(const data of wrong){const f=fixture(),p=f.submit();f.requests[0].resolve(result(data,'v3_edit_board'));await p;assert.equal(f.state().uncertain,true);assert.equal(f.commits.length,0);await f.submit();assert.equal(f.requests.length,1);}
  for(const [action,data,endpoint,viewer] of [['delete',{},'v3_delete_board','42'],['unfollow',{},'v3_unfollow_board','43'],['leave',{...board,collaborated_by_me:true},endpoints.leave,'43'],['archive',{...board,id:'99'},endpoints.archive,'42'],['editSave',success('editSave'),'wrong','42'],['editSave',success('editSave'),endpoints.editSave,'99']]) {
    const f=fixture(action),p=f.submit();f.requests[0].resolve(result(data,endpoint,viewer));await p;assert(f.state().uncertain);assert.equal(f.commits.length,0);
  }
  for(const [status,error,body] of [[503,'','{}'],[0,'cancelled',''],[200,'','not-json']]){const f=fixture(),p=f.submit();f.requests[0].resolve(body,status,error);await p;assert(f.state().uncertain);}
  const cancelled=fixture(),c=cancelled.submit();cancelled.setIdentity(undefined);cancelled.writer.pause();assert(cancelled.state().uncertain);assert(!cancelled.state().busy);assert.equal(cancelled.cancelled.length,1);cancelled.requests[0].resolve(result(success('editSave'),endpoints.editSave));await c;assert.equal(cancelled.commits.length,0);
  for(const change of [f=>f.setIdentity({...f.identity(),intent:8}),f=>f.setIdentity({...f.identity(),page:origin+'/sample/other/'}),f=>f.setIdentity({...f.identity(),ownerId:'99'}),f=>f.setSession({...f.session(),accountId:'other'}),f=>f.setSession({...f.session(),generation:2})]) {const f=fixture(),p=f.submit();change(f);f.requests[0].resolve(result(success('editSave'),endpoints.editSave));await p;assert.equal(f.commits.length,0);}
  const net=new Network();let session=fixture().session(),owner=true,sent=0,context;
  net.request=async(job,current)=>{context=current;const okay=acceptsNetworkJob(job,current());if(okay)sent++;return {error:okay?'':'rejected'}};
  const send=(job,viewer='42',member=false)=>net.requestBusinessBoardManagementWrite(job,()=>session,'100',viewer,'42',member,()=>owner);
  for(const action of Object.keys(jobs))assert.equal((await send(jobs[action],['leave','unfollow'].includes(action)?'43':'42',['leave','unfollow'].includes(action))).error,'',action);
  function mutate(job,fn){const q=new URLSearchParams(job.body),e=JSON.parse(q.get('data'));fn(e);q.set('data',JSON.stringify(e));return {...job,body:q.toString()};}
  const prior=sent;
  for(const j of [{...jobs.editSave,method:'GET'},{...jobs.editSave,id:'bridge'},{...jobs.editSave,page:origin+'/sample/pins/'},{...jobs.editSave,epoch:99},{...jobs.editSave,body:jobs.editSave.body+'&extra=1'},
    mutate(jobs.editSave,e=>e.options.board_id='99'),mutate(jobs.editSave,e=>e.options.name=' '),mutate(jobs.editSave,e=>e.options.description='x'.repeat(501)),mutate(jobs.editSave,e=>e.options.sensitivity='x'),mutate(jobs.editSave,e=>e.options.extra=true),mutate(jobs.editSave,e=>e.context=[]),
    {...jobs.editSave,headers:{...jobs.editSave.headers,'X-Pinterest-Pws-Handler':'www/index.js'}},mutate(jobs.archive,e=>e.options.url='/v3/boards/999/archive/'),mutate(jobs.delete,e=>e.options.pin_id='1')])assert((await send(j)).error,JSON.stringify(j));
  assert((await send(jobs.editSave,'43',true)).error);assert((await send(jobs.delete,'43',true)).error);assert((await send(jobs.leave,'43',false)).error);assert((await send(jobs.unfollow,'42',true)).error);
  assert((await send(mutate(jobs.leave,e=>e.options.data={user_id:'99'}),'43',true)).error);assert.equal(sent,prior);
  session={...session,origin:'https://uk.pinterest.com'};assert.equal((await send({...jobs.editSave,page:jobs.editSave.page.replace(origin,session.origin),url:jobs.editSave.url.replace(origin,session.origin)})).error,'');owner=false;assert.equal(context().authenticated,false);
  await integration();await webAndDialogs();
  assert(!logs.some(s=>s.includes('sample/board')||s.includes(edit.description)));
  console.log('Native board management passed: five exact POST contracts, role/phase gates, rename ownership, cancellation/unknown protection, native cache/route commits, old-read rejection, dialog intents and zero Web submit.');
}
async function integration(){
  const Reader=load('entry/src/main/ets/app/PinmonyBoardNativeReads.ets',n=>n === './PinmonyBoardContentNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardContentNativeWrites.ets', n => n === 'common_foundation' ? {PinmonyRuntimeLog:{info(){}}} : {}) : n==='./PinmonyBoardManagementNativeWrites'?management:n==='./PinmonyBoardPinNativeWrites'?load('entry/src/main/ets/app/PinmonyBoardPinNativeWrites.ets',n=>n==='common_foundation'?log:{}):n==='./PinmonyBoardCollaboratorsNativeWrites'?load('entry/src/main/ets/app/PinmonyBoardCollaboratorsNativeWrites.ets',n=>n==='common_foundation'?log:{}):n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?log:{}).PinmonyBoardNativeReads;
  const rawPin=id=>({type:'pin',id,images:{'736x':{url:'https://i.pinimg.com/synthetic.jpg',width:100,height:200}},board:{id:'100'}});
  for(const action of Object.keys(endpoints)){
    let active=true,session={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'synthetic'},viewer=['leave','unfollow'].includes(action)?'43':'42';const req=[],cancelled=[],exits=[],renames=[],feedback=[];let invalidations=0;
    const store={boardDetail:{kind:'state',session:0,pageKey:page,pins:[],ready:false},collaboratorsToken:0};
    const send=(job,...args)=>new Promise(resolve=>req.push({job,current:args.at(-1),resolve:body=>resolve({body,status:200,error:''})}));
    const reader=new Reader({store:()=>store,session:()=>session,active:()=>active,network:()=>({cancel:id=>cancelled.push(id),requestBusinessBoardRead:send,requestBusinessBoardAuxRead:send,requestBusinessBoardManagementWrite:send}),
      document:()=>{throw Error('Web document dependency')},documentEpoch:()=>{throw Error('Web epoch')},prepareDocument:()=>{throw Error('Web navigation')},runScript:()=>{throw Error('Web submission')},jsonText:s=>s,install(){},bridge(){},committed(){},openPin(){},
      invalidateProfile:()=>invalidations++,renamed:(...args)=>renames.push(args),exited:a=>exits.push(a),feedback:s=>feedback.push(s)});
    const source={...board,collaborated_by_me:viewer==='43',followed_by_me:true};const respond=(i,data,endpoint='')=>req[i].resolve(result(data,endpoint,viewer));
    let p=reader.demand();respond(0,source);await flush();req[1].resolve(JSON.stringify({resource_response:{status:'success',code:0,data:[rawPin('1'),rawPin('2')],bookmark:'next'},client_context:{user:{id:viewer}}}));await p;
    const act=(action,value)=>reader.handle('flow',JSON.stringify({action,value}));
    if(action==='archive')await act('archiveConfirm');else if(action!=='unfollow'){p=act('edit');respond(req.length-1,{...source,description:'Old'});await p;}
    const oldRead=reader.more(),oldIndex=req.length-1;
    p=act(action,edit);const writeIndex=req.length-1;assert.equal(req[writeIndex].job.method,'POST',action);assert(store.boardDetail.flow.busy);const count=req.length;await act('close');await reader.refresh();await act(action,edit);assert.equal(req.length,count);
    respond(writeIndex,success(action),endpoints[action]);await p;assert.equal(invalidations,1);assert(cancelled.includes(req[oldIndex].job.id));
    if(action==='editSave'){assert.equal(store.boardDetail.pageKey,origin+'/sample/renamed/');assert.equal(store.boardDetail.title,'Renamed');assert.equal(store.boardDetail.session,0);assert.deepEqual(renames,[[page,origin+'/sample/renamed/']]);}
    if(action==='delete'||action==='leave'){assert.deepEqual(exits,[action]);assert.equal(store.boardDetail.pins.length,0);}
    if(action==='archive'){assert.equal(store.boardDetail.flow.phase,'archived');assert.equal(req.length,count,'archive retains confirmed state until closed');await act('archive');assert.equal(req.length,count);}
    if(action==='unfollow')assert.deepEqual(feedback,['已取消关注']);
    respond(oldIndex,[rawPin('9')]);await oldRead;assert(!store.boardDetail.pins.some(p=>p.id==='9'),'old read cannot restore cards');
    if(action==='editSave'||action==='unfollow'){
      const read=req.length-1;assert.equal(req[read].job.method,'GET');respond(read,action==='editSave'?success(action):{...source,followed_by_me:undefined});await flush();respond(req.length-1,[rawPin('1')]);await flush();
      const before=req.length;await act('unfollow');assert.equal(req.length,before,'owner or already-unfollowed cannot submit');
    }
    reader.pause();
  }
  // A native background cancellation releases the displayed busy state and cannot auto-replay on resume.
  let active=true;const req=[],store={boardDetail:{pageKey:page,pins:[]},collaboratorsToken:0};
  const send=job=>new Promise(resolve=>req.push({job,resolve:body=>resolve({body,status:200,error:''})}));const reader=new Reader({store:()=>store,session:()=>fixture().session(),active:()=>active,network:()=>({cancel(){},requestBusinessBoardRead:send,requestBusinessBoardManagementWrite:send}),install(){},committed(){},bridge(){},openPin(){}});
  let p=reader.demand();req[0].resolve(result(board));await flush();req[1].resolve(result([]));await p;await reader.handle('flow',JSON.stringify({action:'archiveConfirm'}));p=reader.handle('flow',JSON.stringify({action:'archive'}));active=false;reader.pause();assert(store.boardDetail.flow.uncertain);assert(!store.boardDetail.flow.busy);req[2].resolve(result(null,endpoints.archive));await p;active=true;await reader.demand();assert.equal(req.length,3);assert(store.boardDetail.flow.uncertain);
}
async function webAndDialogs(){
  const script=load('feature_board/src/main/ets/services/PinmonyBoardApiScript.ets').PIN_BOARD_API_SCRIPT;let fetches=0;const states=[];
  const window={PinmonyNativeBoardReadsEnabled:true,PinmonyNativeBoardAuxReadsEnabled:true,PinmonyNativeBoardManagementWritesEnabled:true,PinmonyBoardApiEnabled:true,PinmonyNativeNetworkEnabled:true,PinmonyNetwork:{isReady:()=>true,documentEpoch:()=>7},PinmonyShareBridge:{boardState:s=>states.push(JSON.parse(s))},addEventListener(){},setInterval(){}};window.top=window;
  vm.runInNewContext(script,{window,location:{hostname:'www.pinterest.com',origin,pathname:'/sample/board/',href:page},URL,AbortController,console,setTimeout,clearTimeout,fetch(){fetches++;throw Error('Web POST')}});
  let version=1;const flow={phase:'edit',loading:false,busy:true,uncertain:false,error:'',description:'',privacy:'public',recommend:true,invites:true,requests:true,pins:[],targets:[],saved:[],hasMore:false};
  const adopt=f=>window.PinmonyBoardApi.installNative(page,board,'42',{kind:'state',session:0,pageKey:page,title:'Board',pins:[],ready:true,nativeReadsReady:true,nativeVersion:version++,flow:f},'',{flowOwned:true,sourcePins:[],selectedIds:[],targetBookmark:''});
  assert(adopt(flow));assert(adopt({...flow,busy:false}));assert.equal(states.at(-1).flow.busy,false);for(const action of Object.keys(endpoints))assert.equal(window.PinmonyBoardApi.flow(states.at(-1).session,page,JSON.stringify({action,value:edit})),false);assert.equal(fetches,0);
  const source=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');function method(name){const start=source.indexOf('  private '+name+'(');assert(start>=0);const next=source.indexOf('\n  private ',start+1);return source.slice(start,next).replace(/\n  @Builder\s*$/,'');}
  const View=vm.runInNewContext(ts.transpileModule('class View {'+['confirmationKey','confirmDelete','confirmLeave','confirmArchive'].map(method).join('\n')+'} View;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{});
  for(const name of ['confirmDelete','confirmLeave','confirmArchive'])for(const change of ['web','account','intent','page']){
    const dialogs=[],actions=[],view=new View();view.snapshot={session:0,pageKey:page,title:'Board',collaborator:true,editable:false,nativeAccountGeneration:1,nativeWriteIntent:7,flow:{...flow,phase:name==='confirmArchive'?'archive':'edit',busy:false}};
    view.phase=()=>view.snapshot.flow.phase;view.getUIContext=()=>({showAlertDialog:d=>dialogs.push(d)});view.act=a=>actions.push(a);view[name]();assert.equal(dialogs.length,1);
    if(change==='web')view.snapshot.session=99;else if(change==='account')view.snapshot.nativeAccountGeneration++;else if(change==='intent')view.snapshot.nativeWriteIntent++;else view.snapshot.pageKey=origin+'/sample/other/';
    dialogs[0].secondaryButton.action();assert.equal(actions.length,change==='web'?1:0,name+':'+change);
  }
  // Execute the actual product rename/exit ports, native route selector, and old-Web route guard.
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');function indexMethod(name){const i=index.indexOf('  private '+name+'(');assert(i>=0);return index.slice(i,index.indexOf('\n  private ',i+1));}
  const rename=index.match(/    renamed: \(previous: string, next: string\): void => \{([\s\S]*?)\n    \},/)[1],exit=index.match(/    exited: \(action: string\): void => \{([\s\S]*?)\n    \},/)[1];
  const Host=vm.runInNewContext(ts.transpileModule('class Host {rename(previous:string,next:string){'+rename+'} exit(action:string){'+exit+'}'+['currentBoardUrl','syncBoardRoute'].map(indexMethod).join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_BOARD_READS_ENABLED:true});
  const n=new Host(),next=origin+'/sample/renamed/';let back=0,sync=0,loads=0;
  Object.assign(n,{nativeRootOnly:false,pinStore:{},boardStore:{boardDetail:{pageKey:next,nativeReadsReady:false,nativeVersion:1},boardReturnPage:page},cancelledBoardPins:new Set(),returnCoordinator:{cancel(){}},pageBackToken:0,pageHistory:{visit(){}},boardUrlFromAddress:s=>s,controller:{getUrl:()=>page,loadUrl(){loads++}},backFromBoard(){back++},showMessage(){},boardStateController:{syncRoute(){sync++}},boardNativeReads:{eligible:()=>true,demand(){},pause(){}},pagePerformance:{beginSecondary(){}}});
  n.rename(page,next);assert.equal(n.currentBoardUrl(),next);assert.equal(n.boardStore.boardReturnPage,next);n.syncBoardRoute(page);assert.equal(sync,0);assert.equal(loads,0);n.exit('leave');assert.equal(back,1);
  assert(index.includes('window.PinmonyNativeBoardManagementWritesEnabled')===false);assert(fs.readFileSync('entry/src/main/ets/app/PinmonyScriptRegistry.ets','utf8').includes('window.PinmonyNativeBoardManagementWritesEnabled'));
}
const watchdog=setTimeout(()=>{console.error('native board management check timed out');process.exit(1)},15000);main().then(()=>clearTimeout(watchdog)).catch(e=>{clearTimeout(watchdog);console.error(e);process.exitCode=1});
