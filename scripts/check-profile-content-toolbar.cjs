const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:withLocalMessages(deps),setTimeout,clearTimeout,console});return exports;}
const {PinmonyProfileCache:Cache}=load('feature_profile/src/main/ets/services/PinmonyProfileCache.ets');
const sortTraces=[];
const {PinmonyProfileNativeReads:Reader}=load('entry/src/main/ets/app/PinmonyProfileNativeReads.ets',n=>n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(message){sortTraces.push(message);}}}:{});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',page=origin+'/sample/',avatar='https://i.pinimg.com/synthetic.jpg';
const user={type:'user',id:'42',username:'sample',full_name:'Sample',profile_cover:{source:'image',images:{'736x':{url:avatar,width:736,height:414}}},image_large_url:avatar,follower_count:12,following_count:3,pin_count:2};
const pin=id=>({type:'pin',id:String(id),grid_title:'Pin '+id,images:{'736x':{url:avatar,width:100,height:200}},pinner:{id:'42'}});
const board=id=>({type:'board',id:String(id),name:'Board '+id,url:'/sample/board'+id+'/',images:{'236x':[{url:avatar}]},pin_count:5,is_collaborative:true,owner:{id:'42',image_small_url:avatar},collaborating_users:[{id:'42',image_small_url:avatar},{id:'43',image_small_url:avatar}]});
const body=(data,bookmark='-end-',extra={})=>JSON.stringify({resource_response:{status:'success',code:0,data,bookmark},...extra});
const userBody=(extra={})=>body(user,'',{client_context:{user:{id:'42'}},...extra});
const flush=()=>new Promise(r=>setImmediate(r));
function fixture(){let session={authenticated:true,accountId:'cache-hash',generation:1,origin,userAgent:'synthetic'},target=page,active=true,selected=true,document=origin+'/',epoch=7;
const store={profileSession:0,profileActionsReady:false,profileSessionReady:false,profileScrollOffset:0,profileCache:new Cache(),origins:[]},requests=[],cancelled=[],addresses=[];
const reader=new Reader({store:()=>store,session:()=>session,page:()=>target,selected:()=>selected,active:()=>active,network:()=>({cancel:id=>cancelled.push(id),requestBusinessProfileSort:(job,s,id,viewer,owns)=>{assert(owns());return new Promise(resolve=>requests.push({job,userId:id,resolve:(payload,status=200,error='')=>resolve({...job,body:payload,status,error})}));},requestBusinessProfileRead:(job,s,p,id,owns)=>{assert(owns());return new Promise(resolve=>requests.push({job,userId:id,resolve:(payload,status=200,error='')=>resolve({...job,body:payload,status,error})}));}}),settled(){store.profilePullRefreshing=false},recordAddress:a=>addresses.push(a),document:()=>document,documentEpoch:()=>epoch});
return {reader,store,requests,cancelled,addresses,getSession:()=>session,setSession:s=>session=s,setPage:p=>target=p,setActive:v=>active=v,setSelected:v=>selected=v,setDocument:d=>document=d,setEpoch:v=>epoch=v};}
function options(job){return JSON.parse(new URL(job.url).searchParams.get('data')).options;}
function endpoint(job){return new URL(job.url).pathname;}
async function first(f,boards=[board(1)],cursor='next',unorganized=[pin(3)]){const pending=f.reader.demand();f.reader.demand();assert.equal(f.requests.length,1);assert.equal(endpoint(f.requests[0].job),'/resource/UserResource/get/');f.requests[0].resolve(userBody());await flush();assert.equal(f.requests.length,2);assert.equal(endpoint(f.requests[1].job),'/resource/BoardsFeedResource/get/');f.requests[1].resolve(body(boards,cursor));await flush();assert.equal(f.requests.length,3);assert.equal(endpoint(f.requests[2].job),'/resource/BoardlessPinsResource/get/');f.requests[2].resolve(body(unorganized));await pending;}

const sortBody = (value,write=false) => JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:write?'v3_user_metdata_set':'v3_user_metdata_get',data:write?null:{most_recent_board_sort_order:value}}});
const dataOf = job => JSON.parse(new URLSearchParams(job.method==='POST'?job.body:new URL(job.url).search).get('data')).options;
async function main(){
 const f=fixture();await first(f);
 let p=f.reader.sortBoards('');assert(f.store.profile.boardSortBusy);f.requests[3].resolve(sortBody('alphabetical'));await flush();
 assert.equal(f.requests.length,4,'first opening reads metadata only, without reloading the board feed');await p;assert.equal(f.store.profile.boardSort,'alphabetical');assert.equal(f.store.profile.boards[0].title,'Board 1');assert(f.store.profile.contentHasMore,'opening options preserves pagination');
 p=f.reader.sortBoards('custom');assert.equal(f.store.profile.boardSortPending,'custom');assert.equal(f.store.profile.boardSort,'alphabetical','no optimistic success');
 await f.reader.sortBoards('last_pinned_to');assert.equal(f.requests.length,5,'concurrent writes locked');
 assert.equal(dataOf(f.requests[4].job).url,'/v3/users/me/metadata/','writes use current-user endpoint, not username read route');assert.equal(dataOf(f.requests[3].job).url,'/v3/users/sample/metadata/');assert.equal(dataOf(f.requests[4].job).data.most_recent_board_sort_order,'custom');f.requests[4].resolve(sortBody('',true));await flush();
 assert(f.store.profile.boardSortBusy,'sort indicator remains until list is loaded');assert.equal(f.store.profile.boardSortPending,'custom');assert.equal(dataOf(f.requests[5].job).sort,'custom');assert(!dataOf(f.requests[5].job).bookmarks,'old cursor discarded');f.requests[5].resolve(body([board(3)]));await p;
 assert.equal(f.store.profile.boardSort,'custom');assert.equal(f.store.profile.boards[0].title,'Board 3');
 p=f.reader.sortBoards('alphabetical');f.requests[6].resolve('{}');await p;assert(f.store.profile.boardSortError);assert.equal(f.store.profile.boardSort,'custom');
 await f.reader.sortBoards('alphabetical');assert.equal(f.requests.length,7,'unknown write outcome requires read first');
 p=f.reader.sortBoards('');f.requests[7].resolve(sortBody('custom'));await p;assert.equal(f.store.profile.boardSortError,'');
 p=f.reader.sortBoards('alphabetical');f.reader.pause();f.requests[8].resolve(sortBody('',true));await p;assert.equal(f.store.profile.boardSort,'custom','late write ignored');
 f.reader.reset();assert.equal(f.reader.boardSort,'');

 const panel=fixture();await first(panel,[board(2),board(1)]);panel.store.profileScrollOffset=175;
 for(const choice of ['alphabetical','alphabetical','last_pinned_to']) {
   const count=panel.requests.length,opening=panel.reader.sortBoards('');panel.requests[count].resolve(sortBody(choice));await opening;
   assert.equal(panel.requests.length,count+1,'opening and reopening only request metadata, even when server preference changed');
   assert.deepEqual(Array.from(panel.store.profile.boards,b=>b.title),['Board 2','Board 1']);assert(panel.store.profile.contentHasMore);assert.equal(panel.store.profileScrollOffset,175);assert(!panel.store.profile.contentLoading);assert(!panel.store.profile.contentLoadingMore);
 }
 const pageCount=panel.requests.length,pageMore=panel.reader.more();assert.equal(endpoint(panel.requests[pageCount].job),'/resource/BoardsFeedResource/get/','metadata read must not switch the cursor to a different resource');assert.equal(dataOf(panel.requests[pageCount].job).sort,'last_pinned_to');assert.deepEqual(dataOf(panel.requests[pageCount].job).bookmarks,['next']);panel.requests[pageCount].resolve(body([board(3)],'-end-'));await pageMore;
 const fresh=fixture(),story={type:'story',id:'all',story_type:'all_pins',title:{text:'All Pins'},action:{url:'/sample/pins/'},objects:[{image_medium_url:avatar}]};
 await first(fresh,[story,board(1)]);fresh.reader.boardSort='custom';
 let reload=fresh.reader.refresh(true);fresh.requests[3].resolve(userBody());await flush();
 assert.equal(endpoint(fresh.requests[4].job),'/resource/BoardsFeedResource/get/','refresh reloads story presence');
 fresh.requests[4].resolve(body([board(2)]));await flush();assert.equal(dataOf(fresh.requests[5].job).sort,'custom');
 fresh.requests[5].resolve(body([board(2)]));await flush();fresh.requests[6].resolve(body([]));await reload;
 assert.deepEqual(Array.from(fresh.store.profile.boards,b=>b.title),['Board 2'],'old all-Pins story is removed');
 reload=fresh.reader.refresh(true);fresh.requests[7].resolve(userBody());await flush();fresh.requests[8].resolve(body([story,board(3)]));await flush();fresh.requests[9].resolve(body([board(3)]));await flush();fresh.requests[10].resolve(body([]));await reload;
 assert.deepEqual(Array.from(fresh.store.profile.boards,b=>b.title),['All Pins','Board 3'],'fresh story can return without losing sort');
 const settings=(on,write=false)=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:write?'v3_edit_settings_handler':'v3_get_user_settings',data:{show_all_pins:on}}});
 reload=fresh.reader.loadBoardVisibility();fresh.requests[11].resolve(settings(true));await reload;
 reload=fresh.reader.loadBoardVisibility(false);fresh.requests[12].resolve(settings(false,true));await flush();fresh.requests[13].resolve(settings(false));await flush();
 assert(fresh.store.profile.visibilityBusy);assert.equal(fresh.store.profile.showAllPins,false,'only verified readback permits panel close');
 fresh.requests[14].resolve(userBody());await flush();assert.equal(endpoint(fresh.requests[15].job),'/resource/BoardsFeedResource/get/');fresh.requests[15].resolve(body([board(4)]));await flush();fresh.requests[16].resolve(body([board(4)]));await flush();fresh.requests[17].resolve(body([]));await reload;
 assert.deepEqual(Array.from(fresh.store.profile.boards,b=>b.title),['Board 4'],'visibility save refreshes all-Pins presence with sorting enabled');assert(!fresh.store.profile.visibilityBusy);

 const v=fixture();await first(v);const visibilityBody=(on,write=false)=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:write?'v3_edit_settings_handler':'v3_get_user_settings',data:{show_all_pins:on}}});
 let vp=v.reader.loadBoardVisibility();assert(v.store.profile.visibilityBusy);v.requests[3].resolve(visibilityBody(true));await vp;assert.equal(v.store.profile.showAllPins,true);
 vp=v.reader.loadBoardVisibility(false);assert.equal(v.store.profile.showAllPins,true,'wait for verified save');assert.deepEqual(dataOf(v.requests[4].job),{show_all_pins:false,surface_tag:'holistic_profile_prompt'});
 await v.reader.loadBoardVisibility(true);assert.equal(v.requests.length,5);v.requests[4].resolve(visibilityBody(false,true));await flush();assert.equal(v.requests[5].job.method,'GET');v.requests[5].resolve(visibilityBody(false));await flush();assert(v.store.profile.visibilityBusy,'busy through content refresh');assert.equal(endpoint(v.requests[6].job),'/resource/UserResource/get/');v.requests[6].resolve(userBody());await flush();assert(!dataOf(v.requests[7].job).bookmarks);v.requests[7].resolve(body([board(4)]));await flush();v.requests[8].resolve(body([]));await vp;assert(!v.store.profile.visibilityBusy);assert.equal(v.store.profile.boards[0].title,'Board 4');assert.equal(v.store.profile.showAllPins,false);
 vp=v.reader.loadBoardVisibility(true);v.requests[9].resolve('{}');await vp;assert(v.store.profile.visibilityError);await v.reader.loadBoardVisibility(true);assert.equal(v.requests.length,10,'no replay after unknown visibility write');
 vp=v.reader.loadBoardVisibility();v.requests[10].resolve(visibilityBody(true));await vp;assert.equal(v.store.profile.showAllPins,true);assert.equal(v.store.profile.visibilityError,'');
 vp=v.reader.loadBoardVisibility(false);v.reader.pause();v.requests[11].resolve(visibilityBody(false,true));await vp;assert.equal(v.requests.length,12,'no readback after leaving');assert.equal(v.store.profile.showAllPins,true);
 const net=new Network();let calls=0,context;net.request=async(job,current)=>{context=current;const permitted=acceptsNetworkJob(job,current());if(permitted)calls++;return {error:permitted?'':'rejected'};};
 let session={authenticated:true,accountId:'cache-hash',generation:1,origin,userAgent:'synthetic'};
 const read=f.requests[3].job;assert.equal((await net.requestBusinessProfileSort(read,()=>session,'42','42',()=>true)).error,'');assert.equal(calls,1);calls=0;
 const visibilityJob=v.requests[4].job;assert.equal((await net.requestBusinessProfileSort(visibilityJob,()=>session,'42','42',()=>true)).error,'');assert.equal(calls,1);calls=0;
 const visibilityRead=v.requests[3].job;assert.equal((await net.requestBusinessProfileSort(visibilityRead,()=>session,'42','42',()=>true)).error,'');assert.equal(calls,1);calls=0;
 const badVisibility={...visibilityJob,body:visibilityJob.body.replace('holistic_profile_prompt','settings')};assert((await net.requestBusinessProfileSort(badVisibility,()=>session,'42','42',()=>true)).error);
 const request=f.requests[4].job;assert.equal((await net.requestBusinessProfileSort(request,()=>session,'42','42',()=>true)).error,'');assert.equal(calls,1);
 const mutate = change => {const o=dataOf(request);change(o);return {...request,body:'source_url='+encodeURIComponent('/sample/')+'&data='+encodeURIComponent(JSON.stringify({options:o,context:{}}))};};
 for(const job of [{...request,page:origin+'/other/'},{...request,id:'bridge_1'},mutate(o=>o.url='/v3/users/other/metadata/'),mutate(o=>o.url='/v3/users/sample/metadata/'),mutate(o=>o.data.extra=true),mutate(o=>o.data.most_recent_board_sort_order='random')])assert((await net.requestBusinessProfileSort(job,()=>session,'42','42',()=>true)).error);
 assert((await net.requestBusinessProfileSort(request,()=>session,'42','99',()=>true)).error);assert.equal(calls,1);
 await net.requestBusinessProfileSort(request,()=>session,'42','42',()=>true);session={...session,generation:2};assert.equal(context().authenticated,false);
 const ui=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');const title=ui.slice(ui.indexOf('private rootTitleBarOptions()'),ui.indexOf('private boardSortOption('));assert(!title.includes('this.onSearch'));assert(!title.includes('this.onPublish'));assert(ui.includes('this.contentToolbar()'));assert(ui.includes('this.boardVisibilityControl()'));assert(!ui.includes('visibilityMode'));assert(!ui.includes('private boardVisibilitySheet'));const sortUI=ui.slice(ui.indexOf('private boardSortOption('),ui.indexOf('private contentToolbar('));assert(!sortUI.includes("backgroundColor($r('app.color.surface_muted'))"));assert(ui.includes("width(48).height(48).backgroundColor($r('app.color.input_surface'))"));assert(ui.includes('this.onBoardRecovery()'));assert(ui.includes('top: 14, bottom: 14'));assert(ui.includes('Column({ space: 0 })'));assert(!fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets','utf8').includes('pm_board_recovery_title'));assert(fs.readFileSync('common_ui/src/main/resources/base/media/profile_sliders.svg','utf8').includes('fill-rule="evenodd"'));
 const queued=fixture();await first(queued);
 queued.reader.busy=true;const queuedCount=queued.requests.length;
 await queued.reader.sortBoards('');await queued.reader.sortBoards('');
 assert.equal(queued.requests.length,queuedCount,'busy profile defers metadata read');
 assert.equal(queued.reader.pendingSortRead,true);
 queued.reader.busy=false;queued.reader.apply();
 assert.equal(queued.requests.length,queuedCount+1,'settled profile starts one coalesced read');
 queued.reader.pause();queued.requests[queuedCount].resolve(sortBody('custom'));await flush();
 assert.equal(queued.requests.length,queuedCount+1,'cancelled deferred read cannot start visibility request');
 queued.reader.busy=true;await queued.reader.sortBoards('');queued.reader.pause();queued.reader.apply();
 assert.equal(queued.reader.pendingSortRead,false,'pause retires deferred request');
 console.log('Profile sort queue: coalescing, dispatch after busy and cancellation passed');
 const diagnostic=fixture();await first(diagnostic);
 const validSort=()=>JSON.parse(sortBody('custom'));
 const missing=validSort();delete missing.resource_response.data.most_recent_board_sort_order;
 const unsupported=validSort();unsupported.resource_response.data.most_recent_board_sort_order='private-value-never-log';
 const endpointMismatch=validSort();endpointMismatch.resource_response.endpoint_name='private-endpoint-never-log';
 const viewerMismatch=validSort();viewerMismatch.client_context={user:{id:'private-account-never-log'}};
 const badCode=validSort();delete badCode.resource_response.code;
 for(const [payload,reason] of [['{','json-parse'],['null','response-shape'],['{}','resource-missing'],[JSON.stringify(missing),'sort-missing'],[JSON.stringify(unsupported),'sort-unsupported'],[JSON.stringify(endpointMismatch),'endpoint-mismatch'],[JSON.stringify(viewerMismatch),'viewer-mismatch'],[JSON.stringify(badCode),'business-code']]) {
   const before=diagnostic.requests.length;const pending=diagnostic.reader.sortBoards('');
   diagnostic.requests[before].resolve(payload);await pending;
   assert(diagnostic.store.profile.boardSortError);assert.equal(diagnostic.store.profile.boardSort,'');
   assert(sortTraces.some(line=>line.includes('phase=rejected write=false reason='+reason)),reason);
 }
 const diagnosticText=sortTraces.join('\n');
 for(const secret of ['private-value-never-log','private-endpoint-never-log','private-account-never-log'])assert(!diagnosticText.includes(secret));
 console.log('Profile sort diagnostics: rejected response stages and log redaction passed');
 console.log('Profile content toolbar: confirmed sort, cursor reset, no write replay, concurrency/stale cancellation, ownership and transport limits passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
