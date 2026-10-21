const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:withLocalMessages(deps),setTimeout,clearTimeout,console});return exports;}
const {PinmonyPinMenuNative:Menu,PIN_NATIVE_PIN_MENUS_ENABLED}=load('entry/src/main/ets/app/PinmonyPinMenuNative.ets',n=>n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='feature_pin'?{PIN_EDIT_API_ENABLED:true,PIN_POST_API_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',pin=origin+'/pin/11/',image='https://i.pinimg.com/menu-original.jpg';
const raw={id:'11',is_repin:false,pinner:{id:'42'},images:{orig:{url:image}},ai_disclosures:[1],tracking_params:'synthetic-track',through_id:'11',rec_reason_type:4,source:9};
const body=(data,endpoint_name='',code=0)=>JSON.stringify({resource_response:{status:'success',code,data,endpoint_name},client_context:{user:{id:'42'}}});
const requests=[],cancelled=[],flush=()=>new Promise(setImmediate);
function fixture(){let session={authenticated:true,accountId:'synthetic-cache',generation:1,origin,userAgent:'test'},route=pin,sheet='',active=true;const jobs=[],messages=[],effects=[],store={detail:{pinUrl:pin},moreSession:0,moreOptions:[],shareSession:0};
const net=new Network();net.cancel=id=>cancelled.push(id);net.request=(job,current)=>{assert(acceptsNetworkJob(job,current()),'transport must accept the exact production job');return new Promise(resolve=>{const item={job,current,resolve:(value,status=200,error='')=>resolve({...job,body:value,status,error})};jobs.push(item);requests.push(item);});};
let menu;const ports={store:()=>store,session:()=>session,network:()=>net,active:()=>active,route:()=>route,owns:p=>p===pin&&active,sheet:()=>sheet,show:()=>sheet='more',dismiss:()=>{sheet='';menu.pause();},download:url=>effects.push(['download',url]),help:url=>effects.push(['help',url]),edit:async p=>effects.push(['edit',p]),share:async p=>effects.push(['contacts',p]),message:m=>messages.push(m),undoSnack:(m,p)=>effects.push(['undo',p])};menu=new Menu(ports);
return {menu,store,jobs,effects,messages,network:net,setSheet:s=>sheet=s,setRoute:p=>route=p,setSession:s=>session=s,getSession:()=>session,setActive:v=>active=v};}
const options=job=>JSON.parse(new URLSearchParams(job.method==='GET'?new URL(job.url).search:job.body).get('data')).options;
async function open(f,r=raw){const p=f.menu.open();assert.equal(f.jobs.at(-1).job.method,'GET');f.jobs.at(-1).resolve(body(r));await p;assert.equal(f.store.moreLoading,false);}
async function main(){
assert(PIN_NATIVE_PIN_MENUS_ENABLED);const f=fixture();await open(f);assert(f.store.moreOptions.some(o=>o.id==='detail-edit'));assert(f.store.moreOptions.some(o=>o.id==='detail-ai-help'));
await f.menu.action('detail-download');assert.deepEqual(f.effects.at(-1),['download',image]);await f.menu.action('detail-ai-help');assert(f.effects.at(-1)[1].endsWith('/gen-ai-labels'));
const effectsBeforeShare=f.effects.length;await f.menu.action('detail-share');assert.equal(f.effects.length,effectsBeforeShare);assert.equal(f.jobs.length,1);
const saveCopy=fixture();await open(saveCopy,{...raw,is_repin:true});assert(saveCopy.store.moreOptions.some(o=>o.id==='detail-edit'),'owned saved copy can open restricted editor');
const foreign=fixture();await open(foreign,{...raw,pinner:{id:'99'}});assert(!foreign.store.moreOptions.some(o=>o.id==='detail-edit'));
await foreign.menu.action('detail-edit');assert.equal(foreign.effects.length,0,'forged edit action cannot edit another owner');
const unclassified=fixture();await open(unclassified,{...raw,is_repin:undefined});assert(unclassified.store.moreOptions.some(o=>o.id==='detail-edit'),'unknown content classification does not hide an owned editor');
const photoEdit=fixture();photoEdit.store.shareSession=7;photoEdit.setSheet('share');let photoRead=photoEdit.menu.photoRead(7,pin);photoEdit.jobs.at(-1).resolve(body(raw));
const photoState=await photoRead;assert(photoState.actions.some(o=>o.id==='home-edit'&&o.enabled));await photoEdit.menu.action('home-edit');assert.deepEqual(photoEdit.effects.at(-1),['edit',pin]);
const missingIdentity=fixture();let missingRead=missingIdentity.menu.open();missingIdentity.jobs.at(-1).resolve(JSON.stringify({resource_response:{status:'success',data:raw}}));await missingRead;
assert(missingIdentity.store.moreError,'missing viewer identity reports a read error instead of silently removing edit');
const less=fixture();await open(less);let p=less.menu.action('detail-see-less');assert.deepEqual(JSON.parse(JSON.stringify(options(less.jobs.at(-1).job))),{url:'/v3/pfy/11/feedback/',data:{pin:'11',client_tracking_params:'synthetic-track',feedback_type:10}});less.jobs.at(-1).resolve(body({id:'11'},'v3_provide_pfy_pin_feedback'));await p;assert.equal(less.messages.at(-1),'已提交查看更少反馈');
const more=fixture();await open(more);p=more.menu.action('detail-see-more');assert.equal(options(more.jobs.at(-1).job).data.source,9);await more.menu.action('detail-see-more');assert.equal(more.jobs.length,2);more.jobs[1].resolve(body({id:'11'},'v3_pin_see_more_user_feedback'));await p;assert.equal(more.store.feedbackUndoPin,pin);
p=more.menu.undoFeedback();assert.equal(options(more.jobs[2].job).url,'/v3/pin/11/feedback/see_more/undo/');assert.equal(options(more.jobs[2].job).data.source,5);more.jobs[2].resolve(body({id:'11'},'v3_pin_see_more_undo_user_feedback'));await p;assert.equal(more.store.feedbackUndoPin,'');assert.equal(more.messages.at(-1),'已撤销查看更多反馈');
// Explicit rejection and proven pre-dispatch failures allow a deliberate retry, while uncertain results stay locked.
for(const failure of ['request-unavailable','background','rejected']){const retry=fixture();await open(retry);p=retry.menu.action('detail-see-more');retry.jobs.at(-1).resolve(failure==='rejected'?JSON.stringify({resource_response:{status:'failure',code:7}}):'',failure==='rejected'?200:0,failure==='rejected'?'':failure);await p;assert(retry.messages.at(-1).includes('请重试'));await open(retry);assert(retry.store.moreOptions.find(o=>o.id==='detail-see-more').enabled);p=retry.menu.action('detail-see-more');retry.jobs.at(-1).resolve(body({id:'11'},'v3_pin_see_more_user_feedback'));await p;assert.equal(retry.store.feedbackUndoPin,pin);}
await open(more);assert(more.store.moreOptions.find(o=>o.id==='detail-see-more').enabled,'confirmed undo allows a new deliberate feedback');
const unknown=fixture();await open(unknown);p=unknown.menu.action('detail-see-more');unknown.jobs[1].resolve(body({id:'12'},'v3_pin_see_more_user_feedback'));await p;assert(unknown.messages.at(-1).includes('未确认'));await open(unknown);assert.equal(unknown.store.moreOptions.find(o=>o.id==='detail-see-more').enabled,false);const count=unknown.jobs.length;await unknown.menu.action('detail-see-more');assert.equal(unknown.jobs.length,count,'uncertain write cannot replay on reopen');
const stale=fixture();p=stale.menu.open();stale.setRoute(origin+'/other/');stale.menu.pause();stale.jobs[0].resolve(body(raw));await p;assert.equal(stale.store.moreOptions.length,0);
const account=fixture();p=account.menu.open();const current=account.jobs[0].current;account.setSession({...account.getSession(),accountId:'new-account',generation:2});assert.equal(current().authenticated,false);account.jobs[0].resolve(body(raw));await p;assert.equal(account.store.moreOptions.length,0);
const photo=fixture();photo.store.shareSession=7;photo.setSheet('share');photo.setRoute(origin+'/');p=photo.menu.photoRead(7,pin);photo.jobs[0].resolve(body({...raw,source:undefined}));const state=await p;assert.equal(state.actions.length,5);assert(state.actions.some(o=>o.id==='home-edit'));p=photo.menu.action('home-see-more');assert.equal(options(photo.jobs[1].job).data.source,undefined,'home feedback must not invent a source');photo.jobs[1].resolve(body({id:'11'},'v3_pin_see_more_user_feedback'));await p;
const badImage=fixture();await open(badImage,{...raw,images:{orig:{url:'https://example.com/photo.jpg'}}});assert(!badImage.store.moreOptions.some(o=>o.id==='detail-download'));
// The real allowlist rejects cross-Pin endpoints, extra fields, hidden methods and expired account ownership.
const valid=more.jobs[1].job,net=new Network();let sends=0,session=more.getSession();net.request=async(job,current)=>{if(!acceptsNetworkJob(job,current()))return{error:'rejected'};sends++;return{error:''};};
const mutate=fn=>{const data=new URLSearchParams(valid.body),payload=JSON.parse(data.get('data'));fn(payload.options);data.set('data',JSON.stringify(payload));return{...valid,body:data.toString()};};
for(const job of [{...valid,page:origin+'/pin/12/'},{...valid,method:'DELETE'},mutate(o=>o.url='/v3/pin/12/feedback/see_more/'),mutate(o=>o.data.extra=true),mutate(o=>o.data.pin='12'),mutate(o=>o.data.source='5')])assert((await net.requestBusinessPinMenu(job,()=>session,pin,()=>true)).error);
assert.equal(sends,0);assert.equal((await net.requestBusinessPinMenu(valid,()=>session,pin,()=>true)).error,'');assert.equal(sends,1);
console.log('Native menus: real request allowlist, photo/detail options, owned edit, native contacts/download/help, confirmed feedback and undo, duplicate/uncertain locks, stale route/account cancellation passed');
}
main().then(productionMenus).then(legacySuppression).then(()=>console.log('Native menu production bindings, photo menu permissions/close, native share/download, stale suppression and legacy dispatch suppression passed')).catch(e=>{console.error(e);process.exitCode=1});

async function productionMenus(){
  const registry=load('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets').PinmonyTaskRegistry;
  const foundation={PinmonyTaskRegistry:registry,PinmonyRuntimeLog:{info(){},warn(){}}};
  const Gate=load('entry/src/main/ets/app/PinmonyReadinessGate.ets',()=>foundation).PinmonyReadinessGate;
  const Photo=load('entry/src/main/ets/app/PinmonyPhotoMenuCoordinator.ets',n=>n.includes('PinmonyReadinessGate')?{PinmonyReadinessGate:Gate}:n==='feature_board'?load('feature_board/src/main/ets/services/PinmonyBoardPresentation.ets'):foundation).PinmonyPhotoMenuCoordinator;
  const Panels=load('feature_pin/src/main/ets/controllers/PinmonySharePanelsController.ets',n=>n==='common_foundation'?foundation:{PIN_EDIT_API_ENABLED:true,PIN_POST_API_ENABLED:true}).PinmonySharePanelsController;
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  function method(name){const start=index.search(new RegExp('  private (?:async )?'+name+'\\(')),end=index.indexOf('\n  private ',start+1);assert(start>=0);return index.slice(start,end);}
  function field(name){const start=index.indexOf('  private readonly '+name+':'),end=index.indexOf('\n  private ',start+1);assert(start>=0);return index.slice(start,end).trim().replace(/^private readonly /,'this.').replace(/: [A-Za-z]+ = /,' = ');}
  const context={PinmonyPinMenuNative:Menu,PinmonyPhotoMenuCoordinator:Photo,PinmonySharePanelsController:Panels,PIN_NATIVE_PIN_MENUS_ENABLED:true,PIN_NATIVE_SHARE_PUBLISH_ENABLED:true,PIN_NATIVE_BOARD_READS_ENABLED:true,PinmonyRuntimeLog:foundation.PinmonyRuntimeLog};
  const out={};vm.runInNewContext(ts.transpileModule('export class Host{'+['dismissShareSheet','dismissMoreSheet','openApiDetailMore','performMoreAction','openCustomHomeMenu','performCustomHomeAction','shareDetailPinAfterMenu','dismissPhotoMenuAfterAction','notifyDetailSystemShareClosed'].map(method).join('\n')+'} export function bind(){'+['pinMenuNative','photoMenuCoordinator','sharePanelsController'].map(field).join('\n')+'}',{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:out,...context,setTimeout,clearTimeout});
  const f=fixture(),h=new out.Host(),effects=[],frames=[];let route=origin+'/',web=0;
  h.getUIContext=()=>({postFrameCallback:callback=>frames.push(callback)});
  Object.assign(h,{pinStore:f.store,homeStore:{customHomeMenuToken:0},inboxStore:{},boardStore:{},authStatus:'authenticated',businessSuspended:false,activeSheetKind:'',showNativeSheet:false,nativeNetwork:f.network,
    nativeBusinessSessionContext:f.getSession,nativeDisplayAddress:()=>route,isCurrentMorePin:p=>p===pin && (route===pin || h.homeStore.homeMenuPin===p),pinIdentity:p=>p.match(/\/pin\/(\d+)/)?.[1]||'',currentPinUrl:()=>pin,currentProfileUrl:()=>'',currentBoardUrl:()=>route,currentHomePageKey:()=>origin+'/',currentInboxUrl:()=>origin+'/conversation/1/',
    isCurrentBoardMenuPin:(p,page)=>page===route&&!!h.boardStore.boardDetail,isCurrentSearchMenuPin:()=>false,cancelledBoardPins:new Set(),dismissPostSnack(){},lastRootBackAt:0,rootContextCoordinator:{notify(){}},
    shareNativeFlow:{pause(){},close(){},open:async(mode,p)=>effects.push(['contacts',mode,p])},systemActions:{openLink:async u=>effects.push(['help',u]),copyText:async()=>{},downloadImage:async u=>effects.push(['download',u])},
    sharePinUrl:async u=>effects.push(['system-share',u]),openEditPin:async p=>effects.push(['edit',p]),showMessage:m=>effects.push(['message',m]),showUndoSnack(){},
    controller:{runJavaScript(){web++;throw Error('hidden menu JS');},loadUrl(){web++;throw Error('hidden navigation');},startDownload:u=>effects.push(['download',u])},rejectOfflineAction:()=>false,clearRootTabGuard(){},traceAction(){},
    boardNativeReads:{cancelSavedPin:async()=>''},coordinatorTasks:{},boardOperation(){},setRetainedBoardContent(){},retainedBoardContent:undefined,
  });
  out.bind.call(h);
  let pending=h.openCustomHomeMenu(pin,origin+'/');f.jobs.at(-1).resolve(body(raw));await pending;
  assert.equal(h.homeStore.customHomeMenu.options.length,0);assert(h.homeStore.customHomeMenu.actions.some(o=>o.id==='home-system-share'));assert.equal(web,0);
  await h.performCustomHomeAction('home-download');assert.equal(effects.at(-1)[0],'download');
  pending=h.performCustomHomeAction('home-system-share');assert.equal(h.showNativeSheet,false);assert(h.homeStore.customHomeMenu,'home menu retained until disappearance');assert.notEqual(effects.at(-1)[0],'system-share');h.notifyDetailSystemShareClosed();await flush();frames.shift().onIdle();await pending;assert.equal(effects.at(-1)[0],'system-share');assert.equal(web,0);
  route=origin+'/visitor/board/';h.boardStore.boardDetail={pageKey:route,editable:false,pins:[{id:'11',pinUrl:pin}]};pending=h.openCustomHomeMenu(pin,route);f.jobs.at(-1).resolve(body(raw));await pending;
  assert(!h.homeStore.customHomeMenu.actions.some(o=>o.id==='board-menu-move'));assert(h.homeStore.customHomeMenu.actions.every(o=>o.enabled));
  assert(!h.homeStore.customHomeMenu.actions.some(o=>o.id==='home-edit'),'board menu excludes edit even for an owned Pin');
  assert.equal(h.homeStore.customHomeMenu.actions.find(o=>o.id==='home-system-share').label,'系统分享');
  const boardShares=effects.filter(e=>e[0]==='system-share').length;
  pending=h.performCustomHomeAction('home-system-share');assert.equal(h.showNativeSheet,false);
  assert.equal(effects.filter(e=>e[0]==='system-share').length,boardShares,'board share waits for menu disappearance');
  assert.equal(h.activeSheetKind,'share');assert(h.homeStore.customHomeMenu,'keep board menu mounted during exit');
  h.notifyDetailSystemShareClosed();await flush();assert.equal(effects.filter(e=>e[0]==='system-share').length,boardShares);
  frames.shift().onIdle();await pending;assert.deepEqual(effects.at(-1),['system-share',pin]);
  const sharesBeforeRouteChange=effects.filter(e=>e[0]==='system-share').length;
  pending=h.openCustomHomeMenu(pin,route);f.jobs.at(-1).resolve(body(raw));await pending;
  pending=h.performCustomHomeAction('home-system-share');h.notifyDetailSystemShareClosed();await flush();
  const originalRoute=route;route=origin+'/other/board/';frames.shift().onIdle();await pending;
  assert.equal(effects.filter(e=>e[0]==='system-share').length,sharesBeforeRouteChange,'route change during menu dismissal cancels system share');route=originalRoute;
  h.boardStore.boardDetail={pageKey:route,editable:true,pins:[{id:'11',pinUrl:pin}]};pending=h.openCustomHomeMenu(pin,route);f.jobs.at(-1).resolve(body(raw));await pending;
  assert(!h.homeStore.customHomeMenu.actions.some(o=>o.id==='home-edit'),'owned board menu excludes edit');
  const edits=effects.filter(e=>e[0]==='edit').length;await h.performCustomHomeAction('home-edit');assert.equal(effects.filter(e=>e[0]==='edit').length,edits,'hidden edit cannot be dispatched');
  pending=h.performCustomHomeAction('board-menu-cancel-save');await flush();assert.equal(h.showNativeSheet,false);assert.equal(h.activeSheetKind,'share','unsave keeps builder during mask exit');assert(h.homeStore.customHomeMenu,'unsave retains menu through disappearance');h.notifyDetailSystemShareClosed();await pending;assert.equal(h.showNativeSheet,false,'confirmed unsave closes sheet mask');assert.equal(h.activeSheetKind,'');assert.equal(h.homeStore.customHomeMenu,undefined);assert(h.cancelledBoardPins.has(pin));
  h.boardStore.boardDetail={pageKey:route,editable:true,pins:[],flow:{phase:'section',pins:[{id:'11',pinUrl:pin}]}};pending=h.openCustomHomeMenu(pin,route);f.jobs.at(-1).resolve(body(raw));await pending;
  assert(h.homeStore.customHomeMenu.actions.every(o=>o.enabled));assert(!h.homeStore.customHomeMenu.actions.some(o=>o.id==='home-edit'));assert(h.homeStore.customHomeMenu.actions.some(o=>o.id==='board-menu-move'));h.dismissShareSheet();
  h.boardStore.boardDetail=undefined;route=pin;pending=h.openApiDetailMore();f.jobs.at(-1).resolve(body(raw));await pending;assert(h.pinStore.moreOptions.some(o=>o.id==='detail-see-more'));assert(!h.pinStore.moreOptions.some(o=>o.id==='detail-share'));
  const shareCount=effects.filter(e=>e[0]==='system-share').length;
  h.dismissMoreSheet();h.activeSheetKind='share';h.showNativeSheet=true;pending=h.shareDetailPinAfterMenu(pin,'',true);
  assert.equal(h.activeSheetKind,'share');assert.equal(h.showNativeSheet,false);
  assert.equal(effects.filter(e=>e[0]==='system-share').length,shareCount,'system panel must wait for actual Sheet disappearance');
  await h.shareDetailPinAfterMenu(pin);
  h.notifyDetailSystemShareClosed();await flush();assert.equal(h.activeSheetKind,'');
  assert.equal(effects.filter(e=>e[0]==='system-share').length,shareCount,'wait for idle frame after Sheet teardown');
  frames.shift().onIdle();await pending;
  assert.deepEqual(effects.at(-1),['system-share',pin]);assert.equal(web,0);
  const completed=effects.filter(e=>e[0]==='system-share').length;
  h.notifyDetailSystemShareClosed();assert.equal(effects.filter(e=>e[0]==='system-share').length,completed,'duplicate disappearance cannot reopen share');
  h.showNativeSheet=true;h.activeSheetKind='share';pending=h.shareDetailPinAfterMenu(pin,'',true);
  h.currentPinUrl=()=>'';h.notifyDetailSystemShareClosed();await flush();frames.shift().onIdle();await pending;
  assert.equal(effects.filter(e=>e[0]==='system-share').length,completed,'leaving the pin during dismissal cancels sharing');
  h.currentPinUrl=()=>pin;
  h.showNativeSheet=true;h.activeSheetKind='share';pending=h.shareDetailPinAfterMenu(pin,'',true);
  f.setSession({...f.getSession(),generation:2});h.notifyDetailSystemShareClosed();await flush();frames.shift().onIdle();await pending;
  assert.equal(effects.filter(e=>e[0]==='system-share').length,completed,'account generation change cancels sharing');
  f.setSession({...f.getSession(),generation:1});
  assert(index.includes('this.notifyDetailSystemShareClosed();'),'real Sheet disappearance is bound to completion');
  pending=h.openCustomHomeMenu(pin,origin+'/');h.dismissShareSheet();f.jobs.at(-1).resolve(body(raw));await pending;assert.equal(h.homeStore.customHomeMenu,undefined,'late menu read cannot reopen a closed sheet');
  const before=f.jobs.length;await h.openCustomHomeMenu(pin,origin+'/conversation/1/','share');assert.equal(f.jobs.length,before);assert.equal(effects.at(-1)[0],'contacts');assert.equal(web,0);
}
function legacySuppression(){
  let fetches=0;const window={PinmonyPostApiEnabled:true,PinmonyPostExtensionsEnabled:true,PinmonyNativePinMenusEnabled:true,addEventListener(){}};window.top=window;window.fetch=()=>{fetches++;throw Error('legacy network');};class XHR{open(){}send(){}setRequestHeader(){}addEventListener(){}}
  const ctx={window,location:{hostname:'www.pinterest.com',origin,pathname:'/',href:origin+'/'},document:{addEventListener(){}},URL,URLSearchParams,Headers,AbortController,XMLHttpRequest:XHR,setTimeout,clearTimeout,fetch:window.fetch};
  vm.runInNewContext(load('feature_pin/src/main/ets/services/PinmonyPostApiScript.ets').PIN_POST_API_SCRIPT,ctx);
  vm.runInNewContext(load('feature_pin/src/main/ets/services/PinmonyPostExtensionsScript.ets').PIN_POST_EXTENSIONS_SCRIPT,ctx);
  assert.equal(window.PinmonyPostApi.homeMenuOpen(1,pin,origin+'/'),false);assert.equal(window.PinmonyPostApi.detailMoreOpen(1,pin),false);assert.equal(window.PinmonyPostApi.moreAction(1,pin,'detail-see-more',()=>{}),false);assert.equal(window.PinmonyPostApi.feedbackUndo(pin,1),false);assert.equal(fetches,0);
}
