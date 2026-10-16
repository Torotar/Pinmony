const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const {createArktsLoader}=require('./arkts-module-loader.cjs');
const loader=createArktsLoader(ts,{'common_network':{PIN_BUSINESS_PIN_READ_ENABLED:true},'common_session':{PinmonySessionCredentials:class{}},'common_foundation':{PinmonyRuntimeLog:{info(){},warn(){},error(){}}},'feature_search':{PIN_SEARCH_QUIZ_API_ENABLED:true},'feature_inbox':{},'@kit.RemoteCommunicationKit':{rcp:{}},'@kit.BasicServicesKit':{}});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const {PinmonySearchNativeAuxiliary:Search}=loader.loadFile('entry/src/main/ets/app/PinmonySearchNativeAuxiliary.ets');
const {PinmonyInboxMenuNative:Menu}=loader.loadFile('entry/src/main/ets/app/PinmonyInboxMenuNative.ets');
const {PinmonyBoardInvitationNative:Invites}=loader.loadFile('entry/src/main/ets/app/PinmonyBoardInvitationNative.ets');
const {PinmonySearchNativeReads:Reader}=loader.loadFile('entry/src/main/ets/app/PinmonySearchNativeReads.ets');
const origin='https://www.pinterest.com',searchPage=origin+'/search/pins/?q=art',inbox=origin+'/inbox/',boardPage=origin+'/peer/art/';
const user={id:'41',username:'viewer'},peer={id:'42',username:'peer'},pin=id=>({type:'pin',id:String(id),images:{'474x':{url:'https://i.pinimg.com/'+id+'.jpg',width:474,height:650}}});
const flush=async()=>{for(let i=0;i<5;i++)await new Promise(setImmediate);};
function fixture(page=searchPage){
 let session={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'synthetic'},active=true;const jobs=[],cancelled=[],messages=[],states=[];const store={inboxSession:0,boardInvitationToken:0,searchCache:{put(){},get(){},clear(){}},searchScrollOffset:0};
 const net=Object.create(Network.prototype);net.cancel=id=>cancelled.push(id);net.request=(job,current)=>{assert(acceptsNetworkJob(job,current()),'actual general request policy');const options=JSON.parse(new URLSearchParams(job.method==='GET'?job.url.split('?')[1]:job.body).get('data')).options;return new Promise(resolve=>jobs.push({job,options,current,reply:(data,endpoint='',extra={},status='success',code=0)=>resolve({status:200,error:'',body:JSON.stringify({resource_response:{status,code,endpoint_name:endpoint,data,...extra},client_context:{user}})}),raw:(body,status=200,error='')=>resolve({body,status,error})}));};
 const ports={session:()=>session,network:()=>net,store:()=>store,page:()=>page,active:()=>active,username:()=>user.username,avatar:()=>'',feedback:m=>messages.push(m)};
 return {store,jobs,cancelled,messages,net,ports,states,page:v=>page=v,account:()=>session={...session,accountId:'new',generation:session.generation+1},active:v=>active=v,getSession:()=>session};
}
const placement={'1000269':{display_data:{quiz:{title:'Taste',picker_title:'Pick',picker_see_results_button_copy:'Results'},related_query_items:[{query:'art topic',cover_pin_url:'https://i.pinimg.com/topic.jpg'}]}}};
async function search(){
 const f=fixture(),s=new Search(f.ports,()=>f.states.push(s.snapshot()));let p=s.demand();assert.deepEqual(JSON.parse(JSON.stringify(f.jobs[0].options)),{placement_ids:[1000269],extra_context:{search_query:'art'}});f.jobs[0].reply(placement);await p;assert.equal(s.snapshot().topics.length,1);
 p=s.action('topic','0');assert.equal(f.jobs.at(-1).options.query,'art topic');f.jobs.at(-1).reply({results:Array.from({length:11},(_,i)=>pin(i+1))},'',{bookmark:'cursor'});await p;
 for(let i=1;i<=11;i++)await s.action('select',String(i));assert.equal(s.snapshot().count,10);
 p=s.action('more');assert.deepEqual(Array.from(f.jobs.at(-1).options.bookmarks),['cursor']);f.jobs.at(-1).reply({results:[pin(11),pin(12)]},'',{bookmark:'cursor'});await p;assert.equal(s.snapshot().cards.length,12);assert(!s.snapshot().canMore);
 p=s.action('submit');assert.equal(f.jobs.at(-1).options.url,'/v3/batch/related/pins/');assert.equal(f.jobs.at(-1).options.data.pin_ids.length,10);f.jobs.at(-1).reply([pin(70)]);await p;assert.equal(s.snapshot().mode,'results');assert.equal(s.snapshot().cards[0].targetUrl,origin+'/pin/70/');assert(f.states.length>5);
 await s.action('back');assert.equal(s.snapshot().mode,'entry');
 p=s.action('topic','0');const stale=f.jobs.at(-1);s.pause();stale.reply({results:[pin(99)]});await p;assert(!s.snapshot().cards.some(p=>p.id==='99'));
 f.account();assert.equal(s.snapshot(),undefined);
 const h=fixture(),history=new Search(h.ports,()=>{});p=history.deleteHistory('old',()=>true);assert.equal(h.jobs.at(-1).options.data.vertical,'PIN');h.jobs.at(-1).reply(null,'v3_recent_search_delete');assert.equal(await p,true);assert(!history.historyLocked('old'));
 p=history.deleteHistory('unknown',()=>true);h.jobs.at(-1).raw('{}');await assert.rejects(p);assert(history.historyLocked('unknown'));const n=h.jobs.length;assert.equal(await history.deleteHistory('unknown',()=>true),false);assert.equal(h.jobs.length,n);
 for(const failure of ['request-unavailable','rejected']){p=history.deleteHistory(failure,()=>true);if(failure==='rejected')h.jobs.at(-1).reply(null,'','', 'failure',7);else h.jobs.at(-1).raw('',0,failure);await assert.rejects(p);assert(!history.historyLocked(failure));}
 // Real suggestion mapper, current term and source proof, not a manually enabled deletion button.
 const r=fixture(origin+'/search/'),reader=new Reader({...r.ports,navigate:v=>r.page(v),settled(){}});
 p=reader.input('',true);r.jobs.at(-1).reply({items:[{query:'old',type:'recent_query',vertical:'pins',display_query:'old'},{query:'remote',type:'query',vertical:'pins'}]});await p;assert(r.store.search.suggestions[0].deletable);assert(!r.store.search.suggestions[1].deletable);
 p=reader.deleteHistory(r.store.search.suggestions[0].id);assert.equal(r.jobs.at(-1).options.data.query,'old');r.jobs.at(-1).reply(null,'v3_recent_search_delete');await p;assert.equal(r.store.search.suggestions.length,1);
}
async function news(){
 const restored=fixture(inbox),restoredMenu=new Menu({...restored.ports,find:()=>({newsId:'500',notificationPinId:'70',notificationMuted:true}),confirmed(){}});await restoredMenu.open('news-menu:restored');assert(restored.store.inboxFlow.unsubscribedPin);await restoredMenu.action('unsubscribePin');assert.equal(restored.jobs.length,0,'server-confirmed unsubscribe cannot be submitted again');
 const f=fixture(inbox);const target={newsId:'501',notificationPinId:'71'},visibility=[],muted=[];let exists=true;
 const m=new Menu({...f.ports,find:id=>exists&&id==='news-menu:row'?target:undefined,confirmed:(id,hidden)=>visibility.push([id,hidden]),unsubscribed:id=>muted.push(id)});
 assert(await m.open('news-menu:row'));assert.equal(f.jobs.length,0);let p=m.action('hideNews');await m.action('hideNews');assert.equal(f.jobs.length,1);assert.equal(f.jobs[0].options.data.should_hide,true);f.jobs[0].reply(null,'v3_hide_batch_by_news_ids');await p;assert.deepEqual(visibility,[['501',true]]);assert(f.store.inboxFlow.newsHidden);
 await m.action('back');assert.equal(f.store.inboxFlow,undefined);p=m.undoNews('501');f.jobs.at(-1).reply(null,'v3_hide_batch_by_news_ids');await p;assert.deepEqual(visibility.at(-1),['501',false]);
 assert.equal(f.store.inboxFlow,undefined,'undo restores the root without leaving an updates menu mounted');await m.open('news-menu:row');
 p=m.action('unsubscribePin');assert.deepEqual(Array.from(f.jobs.at(-1).options.data.object_ids_to_unsubscribe),['71']);f.jobs.at(-1).reply({'71':false},'v3_update_object_subscriptions_for_notifications');await p;assert(f.store.inboxFlow.unsubscribedPin);assert.deepEqual(muted,['501']);
 await m.action('back');assert.equal(f.store.inboxFlow,undefined);await m.open('news-menu:row');assert(f.store.inboxFlow.unsubscribedPin);
 p=m.action('hideNews');f.jobs.at(-1).reply({},'v3_hide_batch_by_news_ids');await p;assert(f.store.inboxFlow.writeUncertain);await m.action('back');await m.open('news-menu:row');const n=f.jobs.length;await m.action('hideNews');assert.equal(f.jobs.length,n);
 f.account();await m.open('news-menu:row');assert(!f.store.inboxFlow.writeUncertain);p=m.action('hideNews');const late=f.jobs.at(-1);m.pause();late.reply(null,'v3_hide_batch_by_news_ids');await p;assert.equal(visibility.length,2);
 const ctx=late.current();assert(!ctx.authenticated);exists=false;await m.action('back');await m.open('news-menu:row');assert.equal(f.store.inboxFlow,undefined);
}
async function newsUndoFailure(){const f=fixture(inbox),m=new Menu({...f.ports,find:()=>({newsId:'601',notificationPinId:'71'}),confirmed:()=>{}});await m.open('news-menu:row');let pending=m.action('hideNews');f.jobs.at(-1).reply(null,'v3_hide_batch_by_news_ids');await pending;await m.action('back');pending=m.undoNews('601');f.jobs.at(-1).raw('{}');const error=await pending;assert(error&&error.includes('未确认'));assert.equal(f.store.inboxFlow,undefined,'failed undo cannot leave an invisible child mounted');assert.equal(f.store.flowDismissed,true);pending=m.undoNews('601');const attempts=f.jobs.length;await pending;assert.equal(f.jobs.length,attempts,'unknown undo is never automatically replayed');}
const rawInvite={board:{id:'81',url:'/peer/art/',name:'Art'},invited_by_user:peer,invited_user:user,status:'new'};
async function invites(){
 const f=fixture(inbox),i=new Invites(f.ports);let p=i.open(false);assert.equal(f.jobs.at(-1).options.current_user,true);f.jobs.at(-1).reply([rawInvite,{...rawInvite,invited_user:peer}]);await p;assert.equal(f.store.boardInvitations.items.length,1);
 f.store.boardInvitationPreview=f.store.boardInvitations.items[0];f.store.invitationBannerVisible=true;f.page(boardPage);p=i.open(true);assert.equal(f.jobs.at(-1).options.field_set_key,'boardEdit');f.jobs.at(-1).reply(rawInvite);await p;assert(!f.store.invitationBusy);
 p=i.accept();await i.accept();assert.equal(f.jobs.filter(j=>j.job.method==='POST').length,1);f.jobs.at(-1).reply({...rawInvite,status:'accepted'},'v3_accept_board_collaborator_invite');await p;assert.equal(f.store.boardInvitationPreview.status,'accepted');assert(!f.store.invitationBannerVisible);assert(f.messages.at(-1).includes('已加入'));
 f.store.boardInvitationPreview.status='new';f.store.invitationBannerVisible=true;p=i.open(true);f.jobs.at(-1).reply(rawInvite);await p;p=i.accept();f.jobs.at(-1).reply(rawInvite,'wrong');await p;assert(f.store.invitationBusy);p=i.open(true);f.jobs.at(-1).reply(rawInvite);await p;const n=f.jobs.length;await i.accept();assert.equal(f.jobs.length,n,'read new is not proof that a previously sent acceptance failed');
 p=i.open(true);const late=f.jobs.at(-1);f.account();late.reply({...rawInvite,status:'accepted'});await p;assert.equal(f.store.boardInvitationPreview.status,'new');
}
async function policies(){
 const f=fixture(),s=new Search(f.ports,()=>{});const p=s.demand(),job=f.jobs[0].job;f.jobs[0].reply(placement);await p;let dispatched=0;const net=Object.create(Network.prototype);net.request=async(j,c)=>{if(c().authenticated&&acceptsNetworkJob(j,c()))dispatched++;return {error:c().authenticated?'':'rejected'};};
 const mutate=fn=>{const fields=new URLSearchParams(job.url.split('?')[1]),e=JSON.parse(fields.get('data'));fn(e);fields.set('data',JSON.stringify(e));return {...job,url:job.url.split('?')[0]+'?'+fields};};
 for(const bad of [{...job,id:'bridge_1'},{...job,epoch:9},{...job,method:'POST'},{...job,page:inbox},mutate(e=>e.options.extra_context.search_query='other'),mutate(e=>e.options.placement_ids=[9]),mutate(e=>e.context.secret=true),mutate(e=>e.options.extra=true),{...job,url:job.url.replace(origin,'https://evil.test')}])assert((await net.requestBusinessAuxiliary(bad,f.ports.session,'quiz','',()=>true)).error);
 assert.equal(dispatched,0);assert.equal((await net.requestBusinessAuxiliary(job,f.ports.session,'quiz','',()=>true)).error,'');assert.equal(dispatched,1);
 const uk={...job,url:job.url.replace(origin,'https://uk.pinterest.com'),page:job.page.replace(origin,'https://uk.pinterest.com')};assert.equal((await net.requestBusinessAuxiliary(uk,()=>({...f.getSession(),origin:'https://uk.pinterest.com'}),'quiz','',()=>true)).error,'');
}
async function legacy(){
 for(const [file,flag] of [['feature_search/src/main/ets/services/PinmonySearchQuizApiScript.ets','PinmonyNativeSearchReadsEnabled'],['feature_inbox/src/main/ets/services/PinmonyBoardInvitationScript.ets','PinmonyNativeInboxUpdatesEnabled']]){
  const exp={},window={[flag]:true};window.top=window;vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:exp});vm.runInNewContext(Object.values(exp).find(v=>typeof v==='string'),{window,location:{hostname:'www.pinterest.com'},fetch(){throw Error('legacy request');}});
  assert.equal(window.PinmonySearchQuizApi,undefined);assert.equal(window.PinmonyBoardInvitations,undefined);
 }
}
search().then(news).then(newsUndoFailure).then(invites).then(policies).then(legacy).then(()=>console.log('Remaining native business: real contracts/allowlist, quiz selection/paging, history deletion, updates hide/undo/unsubscribe, invitation identity/acceptance, unknown locks, region/account/route cancellation and old script suppression passed')).catch(e=>{console.error(e);process.exitCode=1});
