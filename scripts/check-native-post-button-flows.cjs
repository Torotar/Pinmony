const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:deps,setTimeout,clearTimeout,console});return exports;}
const deps=n=>n==='feature_profile'?{PIN_PROFILE_ORGANIZE_ENABLED:true}:n==='feature_pin'?{PIN_POST_API_ENABLED:true,PIN_POST_EXTENSIONS_ENABLED:true,PIN_EDIT_API_ENABLED:true}:n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){},warn(){}},PinmonyTaskRegistry:class{invalidate(){}}}:{};
const Ops=load('entry/src/main/ets/app/PinmonyPostNativeOperations.ets',deps).PinmonyPostNativeOperations;
const Confirmed=load('feature_pin/src/main/ets/services/PinmonyConfirmedSaves.ets').PinmonyConfirmedSaves;
const Detail=load('feature_pin/src/main/ets/controllers/PinmonyDetailController.ets',deps).PinmonyDetailController;
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',pin=origin+'/pin/11/',flush=()=>new Promise(setImmediate);
const raw={id:'11',is_repin:true,pinner:{id:'99'},board:{id:'100'},tracking_params:'synthetic',reaction_by_me:0},saved={...raw,pinner:{id:'42'}};
const resource=(data,endpoint='')=>JSON.stringify({client_context:{user:{id:'42'}},resource_response:{status:'success',code:0,endpoint_name:endpoint,data}});
const captures=[];
function fixture(){
 let session={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'synthetic',appVersion:'synthetic'},owned=true,sheet='';
 const store={saveToken:0,editToken:0,viewerSaveBusy:false,detailNativeReadsReady:true,detail:{kind:'cached',dataSource:'api',session:0,pinUrl:pin,imageStageReady:true,actions:[],title:'Original',related:[]},
 confirmedSaves:new Confirmed(),saveResult:{pin:'',items:[],shortlist:[],loading:false,busy:false,error:''},editResult:{uncertain:false,picker:{busy:false}}};
 const requests=[],messages=[],cancelled=[],committed=[];
 const ops=new Ops({store:()=>store,session:()=>session,owns:p=>owned&&p===pin,active:()=>owned,originToken:()=>'',sheet:()=>sheet,show:s=>sheet=s,feedback:s=>messages.push(s),committed:(...args)=>committed.push(args),network:()=>({cancel:id=>cancelled.push(id),requestBusinessPost(job,...args){assert(args.at(-1)());return new Promise(resolve=>{const req={job,args,session:()=>session,resolve:(data,status=200,error='')=>resolve({body:data,status,error})};requests.push(req);captures.push(req);});}})});
 return {ops,store,requests,messages,cancelled,committed,session:()=>session,setSession:s=>session=s,setOwned:v=>owned=v,sheet:()=>sheet};
}
async function picker(f){const start=f.requests.length,p=f.ops.openSave(pin);f.requests[start].resolve(resource(raw));await flush();
 f.requests[start+1].resolve(resource({all_boards:[{id:'100',name:'Target',access:['write'],privacy:'public'}],boards_shortlist:[]}));await flush();
 f.requests[start+2].resolve(JSON.stringify({data:{}}));await p;
}
const ui=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
function method(name){const start=ui.search(new RegExp('  private '+name+'\\('));assert(start>=0);return ui.slice(start,ui.indexOf('\n  private ',start+1));}
const View=vm.runInNewContext(ts.transpileModule('class View {'+['action','acceptsActionIntent','titleBarOptions','leftActions'].map(method).join('\n')+'} View;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{$r:x=>x,SymbolGlyphModifier:class{fontColor(){return this;}},TextStyleMode:{NORMAL:0}});
function view(f){const v=new View();Object.assign(v,{detail:f.store.detail,imageLayer:'',shareActionsReady:true,postActionsReady:true,commentActionsReady:true,actionsReady:false,deferredActions:false,auxiliaryReady:true,likeBlocked:f.ops.likeBlocked(pin),saveBusy:false});return v;}
async function main(){
 // Actual UI menu -> actual Index native dispatch -> real DetailController; no Web control or document.
 const f=fixture(),v=view(f),index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 const arrow=index.match(/nativePostAction: (async [^\r\n]+),\r?\n/);assert(arrow);
 const ownStart=index.indexOf('  private ownsPostPin(');assert(ownStart>=0);
 const ownMethod=index.slice(ownStart,index.indexOf('\n  private ',ownStart+1));
 const Host=vm.runInNewContext(ts.transpileModule('class Host {'+ownMethod+' make(){return ('+arrow[1]+');} } Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_PIN_MENUS_ENABLED:true,PIN_NATIVE_SHARE_PUBLISH_ENABLED:true,PIN_NATIVE_COMMENT_WRITES_ENABLED:true});
 const h=new Host(),shares=[],calls=[];Object.assign(h,{pinStore:f.store,pinIdentity:p=>p.match(/\/pin\/(\d+)\//)?.[1]||'',shareNativeFlow:{open:async(...a)=>shares.push(a)},postNativeOperations:f.ops});
 const dc=new Detail({store:f.store,isOffline:()=>false,isAuthenticated:()=>true,traceAction(){},nativePostAction:h.make(),runScript(){throw Error('Web script')},loadDetailUrl(){throw Error('Web navigation')}});
 v.onAction=(id,kind)=>calls.push(dc.performAction(id,kind));
 let menu=v.titleBarOptions().content.menu.value;assert.equal(menu.length,1);assert(menu[0].content.isEnabled);menu[0].content.action();await Promise.all(calls);
 v.imageLayer='zoom';menu=v.titleBarOptions().content.menu.value;assert(menu[0].content.isEnabled);menu[0].content.action();await Promise.all(calls);
 assert.equal(shares.length,2);assert.equal(shares[0][0],'pin');assert.equal(shares[0][1],pin);
 v.detail.actions=[{id:'stale-share',kind:'share',label:'分享',enabled:false}];assert(v.acceptsActionIntent(v.action('share')),'native share overrides stale Web enabled state');
 v.shareActionsReady=false;assert(!v.acceptsActionIntent(v.action('share')),'separate gates cannot grant unrelated operations');
 // Current native detail may retain its opening marker because no legacy Web snapshot is committed.
 const opening=fixture(),owner=new Host();let nativeOwned=true;
 Object.assign(owner,{authStatus:'authenticated',businessSuspended:false,nativeRootOnly:false,homeStore:{},pinStore:opening.store,
   pinIdentity:p=>p.match(/\/pin\/(\d+)\//)?.[1]||'',detailNativeReads:{owned:()=>nativeOwned}});
 opening.store.detailPin=pin;opening.store.detailOpeningPin=pin;
 opening.store.detail.actions=[{id:'native-save',kind:'save',label:'收藏',enabled:true,selected:false}];
 opening.ops.ports.owns=p=>owner.ownsPostPin(p);
 assert(opening.ops.ready(),'verified native detail enables save before legacy opening marker clears');
 const saveView=view(opening);saveView.postActionsReady=opening.ops.ready();assert(saveView.acceptsActionIntent(saveView.action('save')));
 nativeOwned=false;assert(!opening.ops.ready(),'stale native ownership cannot enable opening detail');nativeOwned=true;
 opening.store.detailNativeReadsReady=false;assert(!opening.ops.ready());opening.store.detailNativeReadsReady=true;
 opening.store.detailOpeningPin=origin+'/pin/12/';assert(!opening.ops.ready());opening.store.detailOpeningPin=pin;
 owner.businessSuspended=true;assert(!opening.ops.ready());owner.businessSuspended=false;
 owner.nativeRootOnly=true;assert(!opening.ops.ready());owner.nativeRootOnly=false;
 const saveIntent=opening.ops.detailAction('save');assert.equal(opening.sheet(),'save');
 opening.requests[0].resolve(resource(raw));await flush();opening.requests[1].resolve(resource({all_boards:[],boards_shortlist:[]}));await flush();
 opening.requests[2].resolve(JSON.stringify({data:{}}));await saveIntent;assert.equal(opening.store.saveResult.loading,false);
 // The production native base mapper has no Web actions. Confirm writes and verify the actual displayed controls.
 const s=fixture();await picker(s);let p=s.ops.saveAction('boardsSave',',"100"');
 s.requests[3].resolve(resource({...saved,id:'77'},'v3_repin_handler'));await p;
 assert(s.store.confirmedSaves.isSaved('11'));let rendered=view(s);assert(rendered.action('save').selected);assert.equal(rendered.action('save').label,'已收藏');
 rendered.imageLayer='zoom';assert.equal(rendered.titleBarOptions().content.menu.value[2].content.label,'已收藏');
 p=s.ops.detailAction('save');s.requests[4].resolve(resource(raw));await flush();assert.match(s.requests[5].job.url,/PinResource\/get/);
 s.requests[5].resolve(resource({...saved,id:'77'}));await flush();assert.match(s.requests[6].job.url,/PinResource\/delete/);
 s.requests[6].resolve(resource(null,'v3_delete_pin_handler'));await p;assert(!view(s).action('save').selected);
 const liked=fixture();p=liked.ops.like(pin);liked.requests[0].resolve(resource(raw));await flush();liked.requests[1].resolve(resource({id:'11'}));await p;
 rendered=view(liked);assert(rendered.leftActions().find(x=>x.kind==='like').selected);assert(!rendered.acceptsActionIntent(rendered.action('like')));assert.equal(liked.store.detail.title,'Original');
 // Previously saved, current Pin itself is an owned repin; neither another person's Pin nor an original creation can be deleted.
 const old=fixture();p=old.ops.cancelSave(pin);old.requests[0].resolve(resource(saved));await flush();const deletion=old.requests[1];assert(deletion);
 assert.match(deletion.job.url,/PinResource\/delete/);assert.deepEqual(JSON.parse(new URLSearchParams(deletion.job.body).get('data')).options,{id:'11',client_tracking_params:'synthetic~0'});
 assert.equal(deletion.args[4],true);assert.equal(deletion.args[5],false);deletion.resolve(resource(null,'v3_delete_pin_handler'));await p;
 assert(!old.store.confirmedSaves.isSaved('11'));assert(old.messages.includes('已取消收藏'));

 p=old.ops.like(pin);old.requests[2].resolve(resource(saved));await flush();old.requests[3].resolve(resource({id:'11'}));await p;
 assert(!view(old).action('save').selected,'a stale owned-repin read cannot restore a locally confirmed cancellation');
 for(const denied of [raw,{...saved,is_repin:false},{...saved,pinner:undefined},{...saved,board:{id:'bad'}},{...saved,id:'different'}]){
  const g=fixture(),p=g.ops.cancelSave(pin);g.requests[0].resolve(resource(denied));await p;assert.equal(g.requests.filter(r=>r.job.method==='POST').length,0);
 }
 // Unknown result remains locked across another tap, close/pause, and a fresh but still-zero read.
 const u=fixture();p=u.ops.like(pin);u.requests[0].resolve(resource(raw));await flush();u.requests[1].resolve('bad');await p;
 assert(u.ops.likeBlocked(pin));assert(!view(u).acceptsActionIntent(view(u).action('like')));await u.ops.like(pin);assert.equal(u.requests.length,2);
 u.ops.pause();await u.ops.like(pin);assert.equal(u.requests.length,2);
 u.ops.observe(pin,resource(raw));assert(u.ops.likeBlocked(pin));await u.ops.like(pin);assert.equal(u.requests.length,2);
 u.ops.observe(pin,resource({...raw,reaction_by_me:1}));assert(!u.ops.likeBlocked(pin));assert(view(u).action('like').selected);assert.equal(u.requests.filter(r=>r.job.method==='POST').length,1);
 // Confirmed unknown locks belong to an account and Pin. Stale or failed reads never claim a write succeeded.
 const stale=fixture();p=stale.ops.like(pin);stale.requests[0].resolve(resource(raw));await flush();stale.ops.pause();await p;assert(stale.ops.likeBlocked(pin));
 stale.ops.observe(origin+'/pin/12/',resource({...raw,reaction_by_me:1}));assert(stale.ops.likeBlocked(pin));
 stale.setSession({...stale.session(),generation:2,accountId:'other'});stale.ops.observe(pin,resource(raw));assert(!stale.ops.likeBlocked(pin));assert(!view(stale).action('like').selected);
 const failed=fixture();p=failed.ops.like(pin);failed.requests[0].resolve('bad');await p;assert(!failed.ops.likeBlocked(pin));assert(!failed.requests.some(r=>r.job.method==='POST'));
 const cancel=fixture();p=cancel.ops.cancelSave(pin);cancel.requests[0].resolve(resource(saved));await flush();cancel.requests[1].resolve('bad');await p;
 await cancel.ops.cancelSave(pin);assert.equal(cancel.requests.filter(r=>r.job.method==='POST').length,1,'unknown cancellation cannot delete twice');
 await policy();console.log('Native post button flows passed: real title/zoom share dispatch, zero-Web controls, confirmed save/like presentation, save-to-cancel routing, historical repin ownership/delete, and durable unknown/stale/account isolation.');
}
async function policy(){
 const network=new Network();let sent=0;
 network.request=async(job,context)=>{if(!context().authenticated)return {error:'rejected'};assert(acceptsNetworkJob(job,context()));sent++;return {error:''};};
 const deletion=captures.find(r=>r.job.url.endsWith('/PinResource/delete/')&&JSON.parse(new URLSearchParams(r.job.body).get('data')).options.id==='11');
 assert(deletion);const args=deletion.args.slice();args[8]=()=>true;
 assert.equal((await network.requestBusinessPost(deletion.job,...args)).error,'');
 args[4]=false;assert.equal((await network.requestBusinessPost(deletion.job,...args)).error,'rejected','main-Pin deletion still requires server-verified ownership');
 assert.equal(sent,1);
}
const timer=setTimeout(()=>{console.error('post button flow timeout');process.exit(1)},20000);main().then(()=>clearTimeout(timer)).catch(e=>{clearTimeout(timer);console.error(e);process.exitCode=1});
