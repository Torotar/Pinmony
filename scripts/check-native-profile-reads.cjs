const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:withLocalMessages(deps),setTimeout,clearTimeout,console});return exports;}
const {PinmonyProfileCache:Cache}=load('feature_profile/src/main/ets/services/PinmonyProfileCache.ets');
const settingsClient=load('entry/src/main/ets/app/PinmonyProfileSettingsClient.ets',n=>n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{});
const {PinmonyProfileNativeReads:Reader}=load('entry/src/main/ets/app/PinmonyProfileNativeReads.ets',n=>n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:n==='./PinmonyProfileSettingsClient'?settingsClient:{});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',page=origin+'/sample/',avatar='https://i.pinimg.com/synthetic.jpg';
const user={type:'user',id:'42',username:'sample',full_name:'Sample',profile_cover:{source:'image',images:{'736x':{url:avatar,width:736,height:414}}},image_large_url:avatar,follower_count:12,following_count:3,pin_count:2};
const pin=id=>({type:'pin',id:String(id),grid_title:'Pin '+id,images:{'736x':{url:avatar,width:100,height:200}},pinner:{id:'42'}});
const board=id=>({type:'board',id:String(id),name:'Board '+id,url:'/sample/board'+id+'/',images:{'236x':[{url:avatar}]},pin_count:5,is_collaborative:true,owner:{id:'42',image_small_url:avatar},collaborating_users:[{id:'42',image_small_url:avatar},{id:'43',image_small_url:avatar}]});
const body=(data,bookmark='-end-',extra={})=>JSON.stringify({resource_response:{status:'success',code:0,data,bookmark},...extra});
const userBody=(extra={})=>body(user,'',{client_context:{user:{id:'42'}},...extra});
const flush=()=>new Promise(r=>setImmediate(r));
function fixture(mergeRequest){let session={authenticated:true,accountId:'cache-hash',generation:1,origin,userAgent:'synthetic'},target=page,active=true,selected=true,document=origin+'/',epoch=7;
const store={profileSession:0,profileActionsReady:false,profileSessionReady:false,profileScrollOffset:0,profileCache:new Cache(),origins:[]},requests=[],cancelled=[],addresses=[];
const reader=new Reader({store:()=>store,session:()=>session,page:()=>target,selected:()=>selected,active:()=>active,network:()=>({requestBusinessProfileInitialSort:(job,session,live)=>{assert(live());return new Promise(resolve=>requests.push({job,resolve:(payload,status=200,error='')=>resolve({...job,body:payload,status,error})}));},requestBusinessProfileSettings:(job,session,page,user,viewer,allowed,permissions,live)=>{assert(live());return new Promise(resolve=>requests.push({job,resolve:(payload,status=200,error='')=>resolve({...job,body:payload,status,error})}));},requestBusinessBoardManagementWrite: (...args)=>mergeRequest(...args),requestBusinessProfileSort:(job,session,user,viewer,live)=>{assert(live());return new Promise(resolve=>requests.push({job,resolve:(payload,status=200,error='')=>resolve({...job,body:payload,status,error})}));},cancel:id=>cancelled.push(id),requestBusinessProfileRead:(job,s,p,id,owns)=>{assert(owns());return new Promise(resolve=>requests.push({job,userId:id,resolve:(payload,status=200,error='')=>resolve({...job,body:payload,status,error})}));}}),settled(){store.profilePullRefreshing=false},recordAddress:a=>addresses.push(a),document:()=>document,documentEpoch:()=>epoch});
return {reader,store,requests,cancelled,addresses,getSession:()=>session,setSession:s=>session=s,setPage:p=>target=p,setActive:v=>active=v,setSelected:v=>selected=v,setDocument:d=>document=d,setEpoch:v=>epoch=v};}
function options(job){return JSON.parse(new URL(job.url).searchParams.get('data')).options;}
function endpoint(job){return new URL(job.url).pathname;}
async function first(f,boards=[board(1)],cursor='next',unorganized=[pin(3)]){const pending=f.reader.demand();f.reader.demand();assert.equal(f.requests.length,1);assert.equal(endpoint(f.requests[0].job),'/resource/UserResource/get/');f.requests[0].resolve(userBody());await flush();assert.equal(f.requests.length,2,'main list starts before unorganized content');assert.equal(endpoint(f.requests[1].job),'/resource/BoardsFeedResource/get/');f.requests[1].resolve(body(boards,cursor));await flush();assert.equal(f.requests.length,3);assert.equal(endpoint(f.requests[2].job),'/resource/BoardlessPinsResource/get/');f.requests[2].resolve(body(unorganized));await pending;}
async function main(){
const layered=fixture();const layeredInitial=layered.reader.demand();
layered.requests[0].resolve(userBody());await flush();
layered.requests[1].resolve(body([board(1)],'next'));await flush();
assert.equal(layered.reader.busy,false,'auxiliary does not hold main list lock');
assert(layered.store.profileCache.get(page,'saved'),'main presentation is cached before auxiliary completes');
const layeredMore=layered.reader.more();assert.equal(layered.requests.length,4,'pagination starts while auxiliary is pending');
layered.requests[2].resolve(body([]));await layeredInitial;
assert.equal(layered.reader.busy,true,'old auxiliary completion cannot clear newer pagination lock');
layered.requests[3].resolve(body([board(2)],'-end-'));await layeredMore;

const empty=fixture();await first(empty,[],'-end-',[]);
const emptyHubBody=()=>body([],'-end-',{resource_response:{status:'success',code:0,data:[],bookmark:'-end-',endpoint_name:'v3_get_user_filtered_pins_handler'}});
let pendingEmpty=empty.reader.select('hub:pins:1:0');await flush();
const emptyRequest=empty.requests.at(-1);const beforeEmpty=empty.requests.length;
await empty.reader.select('hub:pins:1:0');await empty.reader.demand();
assert.equal(empty.requests.length,beforeEmpty,'same in-flight empty filter is coalesced');
emptyRequest.resolve(emptyHubBody());await pendingEmpty;
assert(empty.reader.hubFeed.emptyUntil>Date.now());
await empty.reader.select('saved');await empty.reader.select('hub:pins:1:0');
assert.equal(empty.requests.length,beforeEmpty,'short-lived empty result survives filter round trip');
empty.reader.hubFeed.emptyUntil=Date.now()-1;
pendingEmpty=empty.reader.demand();assert.equal(empty.requests.length,beforeEmpty+1,'expired emptiness is revalidated');
empty.requests.at(-1).resolve(emptyHubBody());await pendingEmpty;
pendingEmpty=empty.reader.refresh();assert.equal(empty.requests.length,beforeEmpty+2,'explicit refresh bypasses empty cache');
empty.requests.at(-1).resolve(userBody());await flush();empty.requests.at(-1).resolve(emptyHubBody());await pendingEmpty;
empty.reader.invalidateContent();assert.equal(empty.reader.hubFeeds.size,0,'confirmed mutations invalidate filtered emptiness');
const emptyFollowing=fixture();await first(emptyFollowing);
let followingEmpty=emptyFollowing.reader.select('hub:following:0:0');await flush();
emptyFollowing.requests.at(-1).resolve(body([],'-end-',{resource_response:{status:'success',code:0,endpoint_name:'v3_get_boards_following_handler',data:[],bookmark:'-end-'}}));await followingEmpty;
const followingCount=emptyFollowing.requests.length;await emptyFollowing.reader.select('saved');await emptyFollowing.reader.select('hub:following:0:0');
assert.equal(emptyFollowing.requests.length,followingCount,'following empty cache also prevents immediate reread');
console.log('Profile empty cache: in-flight dedupe, filter identity, TTL, explicit refresh and mutation invalidation passed');

const followed=fixture(); await first(followed); const initialCount=followed.requests.length;
const followingRead=followed.reader.select('hub:following:0:0'); await flush();
assert.equal(followed.requests.length,initialCount+1); const followJob=followed.requests[initialCount].job;
assert.equal(followJob.method,'POST'); assert.equal(endpoint(followJob),'/resource/ApiResource/get/');
const followOptions=JSON.parse(new URLSearchParams(followJob.body).get('data')).options;
assert.equal(followOptions.url,'/v3/users/sample/boards/following/'); assert.equal(followOptions.data.page_size,12);
followed.requests[initialCount].resolve(body([board(91)],'next',{resource_response:{status:'success',code:0,endpoint_name:'v3_get_boards_following_handler',data:[board(91)],bookmark:'next'}})); await followingRead;
assert.equal(followed.store.profile.hubMode,'following'); assert.equal(followed.store.profile.section,'saved');
assert.equal(followed.store.profile.boards[0].title,'Board 91'); assert.equal(followed.store.profile.contentHasMore,true);
const nextFollowing=followed.reader.more(); await flush(); const nextReq=followed.requests[initialCount+1];
assert.deepEqual(JSON.parse(new URLSearchParams(nextReq.job.body).get('data')).options.bookmarks,['next']);
const guarded=Object.create(Network.prototype); let allowed=false;
guarded.request=async (job,context)=>{allowed=context().authenticated; return {status:0,error:'synthetic'};};
await guarded.requestBusinessProfileSettings(nextReq.job,followed.getSession,page,'42','42',[],['own'],()=>true); assert(allowed,'captured cursor form is accepted');
for (const bad of [[],[''],['x'.repeat(4097)],['a','b']]) {
 const job={...nextReq.job,headers:{...nextReq.job.headers}}, form=new URLSearchParams(job.body), env=JSON.parse(form.get('data'));
 env.options.bookmarks=bad; form.set('data',JSON.stringify(env)); job.body=form.toString();
 await guarded.requestBusinessProfileSettings(job,followed.getSession,page,'42','42',[],['own'],()=>true); assert(!allowed,'invalid cursor must be rejected');
}

nextReq.resolve(body([board(92)],'-end-',{resource_response:{status:'success',code:0,endpoint_name:'v3_get_boards_following_handler',data:[board(92)],bookmark:'-end-'}})); await nextFollowing;
assert.equal(followed.store.profile.boards.length,2); assert.equal(followed.store.profile.contentHasMore,false);
const profileView=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
assert(profileView.indexOf("hubStateButton('pm_profile_hub_secret','secret')") < profileView.indexOf("hubStateButton('pm_following_7dfa5d8f','following')"));
console.log('Following boards: own-session read, profile card mapping and filter order passed');

const initialHub=fixture();initialHub.reader.ports.initialBoardsHub=()=>true;
const hubDone=initialHub.reader.demand();assert.equal(initialHub.requests.length,2,'identity and initial metadata start concurrently');initialHub.requests[0].resolve(userBody());await flush();
assert.equal(initialHub.store.profile.hubMode,'boards','choose modern root before identity publication');
assert.equal(initialHub.requests.length,2,'auxiliary waits for the visible boards');
assert(!initialHub.requests.some(r=>endpoint(r.job)==='/resource/BoardsFeedResource/get/'));
const sameRoute=initialHub.reader.select('hub:boards:0:0');await sameRoute;
assert.equal(initialHub.requests.length,2);assert.equal(initialHub.cancelled.length,0,'UI confirmation does not cancel initial reads');
const preference=initialHub.requests.find(r=>r.job.id.startsWith('native_profile_sort_initial_'));
preference.resolve(body({most_recent_board_sort_order:'alphabetical'},'',{resource_response:{status:'success',code:0,endpoint_name:'v3_user_metdata_get',data:{most_recent_board_sort_order:'alphabetical'}},client_context:{user:{id:'42'}}}));
await flush();
assert.equal(initialHub.requests.length,3);assert.equal(endpoint(initialHub.requests[2].job),'/resource/BoardsResource/get/');
initialHub.requests[2].resolve(body([board(1)],'-end-',{resource_response:{status:'success',code:0,endpoint_name:'v3_user_profile_boards_feed',data:[board(1)],bookmark:'-end-'}}));await flush();
assert.equal(initialHub.store.profile.boards.length,1,'main list publishes before auxiliary completes');
initialHub.requests.find(r=>endpoint(r.job)==='/resource/BoardlessPinsResource/get/').resolve(body([]));await hubDone;
assert.equal(initialHub.store.profile.boards.length,1);assert.equal(initialHub.cancelled.length,0);
initialHub.reader.invalidateContent();
assert.equal(initialHub.store.profile,undefined,'mutated content must not remain visible as current');
const contentReread=initialHub.reader.demand();
assert.equal(endpoint(initialHub.requests[4].job),'/resource/UserResource/get/','identity and counts are refreshed');
initialHub.requests[4].resolve(userBody());await flush();
assert.equal(initialHub.requests.length,6,'confirmed sort avoids another metadata round trip');
assert.equal(endpoint(initialHub.requests[5].job),'/resource/BoardsResource/get/');
initialHub.requests[5].resolve(body([board(2)],'-end-',{resource_response:{status:'success',code:0,endpoint_name:'v3_user_profile_boards_feed',data:[board(2)],bookmark:'-end-'}}));
await flush();initialHub.requests[6].resolve(body([]));await contentReread;
assert.equal(initialHub.store.profile.boards[0].title,'Board 2','only refreshed content is published');
initialHub.reader.invalidateContent();
initialHub.setSession({...initialHub.getSession(),generation:2});
const changed=initialHub.reader.demand();initialHub.requests[7].resolve(userBody());await flush();
assert(initialHub.requests.slice(8).some(r=>r.job.id.startsWith('native_profile_sort_initial_')),'new session cannot reuse previous ordering');
initialHub.reader.pause();
for(const request of initialHub.requests.slice(8))request.resolve(body([]));
await changed;

// Bootstrap is read-only and never publishes ordering before identity proof.
const preferenceBody=(viewer='42',sort='alphabetical')=>body(null,'',{
 resource_response:{status:'success',code:0,endpoint_name:'v3_user_metdata_get',data:{most_recent_board_sort_order:sort}},
 client_context:{user:{id:viewer}}
});
for(const metadataFirst of [true,false]) {
 const boot=fixture();boot.reader.ports.initialBoardsHub=()=>true;
 const done=boot.reader.demand();assert.equal(boot.requests.length,2);
 if(metadataFirst){boot.requests[1].resolve(preferenceBody());await flush();assert.equal(boot.requests.length,2);assert.equal(boot.reader.boardSort,'');}
 boot.requests[0].resolve(userBody());await flush();
 if(!metadataFirst){assert.equal(boot.requests.length,2);boot.requests[1].resolve(preferenceBody());await flush();}
 const boards=boot.requests.find(r=>endpoint(r.job)==='/resource/BoardsResource/get/');assert(boards);
 assert.equal(options(boards.job).sort,'alphabetical');
 boards.resolve(body([board(1)],'-end-',{resource_response:{status:'success',code:0,endpoint_name:'v3_user_profile_boards_feed',data:[board(1)],bookmark:'-end-'}}));await flush();boot.requests.find(r=>endpoint(r.job)==='/resource/BoardlessPinsResource/get/').resolve(body([]));await done;
 assert.equal(boot.store.profile.boards.length,1);
}
for(const payload of [preferenceBody('99'),preferenceBody('', 'alphabetical'),preferenceBody('42','unsupported'),'{']) {
 const boot=fixture();boot.reader.ports.initialBoardsHub=()=>true;
 const done=boot.reader.demand();boot.requests[1].resolve(payload);boot.requests[0].resolve(userBody());await flush();
 await done;
 assert(!boot.requests.some(r=>endpoint(r.job)==='/resource/BoardsResource/get/'));
 assert.equal(boot.reader.boardSort,'');assert(boot.store.profile.contentError,'invalid bootstrap remains an explicit error');
}
const rejectedIdentity=fixture();rejectedIdentity.reader.ports.initialBoardsHub=()=>true;
const rejectedDone=rejectedIdentity.reader.demand();rejectedIdentity.requests[0].resolve(userBody({client_context:{user:{id:'99'}}}));await rejectedDone;
assert(rejectedIdentity.cancelled.includes(rejectedIdentity.requests[1].job.id));
rejectedIdentity.requests[1].resolve(preferenceBody());await flush();assert.equal(rejectedIdentity.reader.boardSort,'');assert.equal(rejectedIdentity.requests.length,2);
const bootCancelled=fixture();bootCancelled.reader.ports.initialBoardsHub=()=>true;
const bootCancelledDone=bootCancelled.reader.demand();bootCancelled.reader.pause();
assert.equal(bootCancelled.cancelled.length,2,'pause cancels both bootstrap reads');
bootCancelled.requests[1].resolve(preferenceBody());bootCancelled.requests[0].resolve(userBody());await bootCancelledDone;
assert.equal(bootCancelled.reader.boardSort,'');
const bootFailure=fixture();bootFailure.reader.ports.initialBoardsHub=()=>true;
const failedBootDone=bootFailure.reader.demand();bootFailure.requests[1].resolve('',503);await flush();
assert.equal(bootFailure.requests.length,2,'early metadata failure does not dispatch another request');
bootFailure.requests[0].resolve(userBody());await flush();
await failedBootDone;
assert.equal(bootFailure.requests.length,2);assert(bootFailure.store.profile.contentError);
const bootVisitor=fixture();bootVisitor.reader.ports.initialBoardsHub=()=>true;bootVisitor.reader.ports.visitor=()=>true;
const visitorDone=bootVisitor.reader.demand();assert.equal(bootVisitor.requests.length,1,'visitor does not bootstrap own metadata');
bootVisitor.reader.pause();bootVisitor.requests[0].resolve(userBody());await visitorDone;

const bootstrapNetwork=new Network();let bootstrapSent=0,bootstrapContext;
bootstrapNetwork.request=async(job,current)=>{bootstrapContext=current;if(!acceptsNetworkJob(job,current()))return{error:'rejected'};bootstrapSent++;return{error:''};};
const bootstrapJob=initialHub.requests[1].job;
let bootstrapSession=initialHub.getSession();bootstrapSession={...bootstrapSession,generation:bootstrapJob.epoch};
assert.equal((await bootstrapNetwork.requestBusinessProfileInitialSort(bootstrapJob,()=>bootstrapSession,()=>true)).error,'');
const bootstrapMutate=fn=>{const u=new URL(bootstrapJob.url),e=JSON.parse(u.searchParams.get('data'));fn(e);u.searchParams.set('data',JSON.stringify(e));return {...bootstrapJob,url:u.toString()};};
for(const bad of [{...bootstrapJob,method:'POST'}, {...bootstrapJob,body:'write'}, {...bootstrapJob,id:'native_profile_other'},
 {...bootstrapJob,page:origin+'/other/'}, {...bootstrapJob,epoch:99},
 bootstrapMutate(e=>e.options.url='/v3/users/me/metadata/'),bootstrapMutate(e=>e.options.data={most_recent_board_sort_order:'custom'}),
 bootstrapMutate(e=>e.options.extra=true),bootstrapMutate(e=>e.context={extra:true})]) {
 assert((await bootstrapNetwork.requestBusinessProfileInitialSort(bad,()=>bootstrapSession,()=>true)).error);
}
assert.equal(bootstrapSent,1,'bootstrap cannot authorize writes, other paths or extra fields');
assert((await bootstrapNetwork.requestBusinessProfileInitialSort(bootstrapJob,()=>bootstrapSession,()=>false)).error);
await bootstrapNetwork.requestBusinessProfileInitialSort(bootstrapJob,()=>bootstrapSession,()=>true);
bootstrapSession={...bootstrapSession,accountId:'changed'};assert.equal(bootstrapContext().authenticated,false);
assert((await bootstrapNetwork.requestBusinessProfileInitialSort(bootstrapJob,()=>({...bootstrapSession,authenticated:false}),()=>true)).error);
console.log('Profile cold start: parallel metadata/identity, viewer proof, failure, cancellation, visitor and narrow read-only transport passed');

// Visible content commits before auxiliary Pins are dispatched.
const concurrent=fixture(),layeredDone=concurrent.reader.demand();
concurrent.requests[0].resolve(userBody());await flush();
assert.equal(concurrent.requests.length,2);
concurrent.requests[1].resolve(body([board(1)]));await flush();
assert.equal(concurrent.store.profile.boards.length,1);
assert.equal(concurrent.requests.length,3);
assert.equal(concurrent.store.profile.contentLoading,false);
concurrent.requests[2].resolve(body([pin(3)]));await layeredDone;
assert.equal(concurrent.reader.unorganized.pins.length,1);
const parallelCancel=fixture(),cancelDone=parallelCancel.reader.demand();
parallelCancel.requests[0].resolve(userBody());await flush();
parallelCancel.reader.pause();
for(const request of parallelCancel.requests.slice(1)){
 assert(parallelCancel.cancelled.includes(request.job.id),'pause cancels both pending reads');
 request.resolve(body([board(99)]));
}
await cancelDone;assert.equal(parallelCancel.store.profile.boards.length,0,'late responses remain discarded');
const auxiliaryFailure=fixture(),failureDone=auxiliaryFailure.reader.demand();
auxiliaryFailure.requests[0].resolve(userBody());await flush();
auxiliaryFailure.requests[1].resolve(body([board(1)]));await flush();auxiliaryFailure.requests[2].resolve('',503);
await failureDone;assert.equal(auxiliaryFailure.store.profile.boards.length,1);
assert(auxiliaryFailure.reader.unorganized.error,'auxiliary failure remains independently visible');


const alphabetic=fixture();await first(alphabetic,[board(1)],'-end-');alphabetic.reader.boardSort='alphabetical';
const orderedRead=alphabetic.reader.read(false,false);assert.equal(options(alphabetic.requests.at(-1).job).sort,'alphabetical');assert.equal(alphabetic.requests.at(-1).job.headers['X-Pinterest-Pws-Handler'],'www/[username].js');assert.equal(alphabetic.requests.at(-1).job.headers['X-Pinterest-Source-Url'],'/sample/');assert.equal(alphabetic.requests.at(-1).job.headers['X-Pinterest-AppState'],'active');
alphabetic.requests.at(-1).resolve(body([{...board(1),name:'人物'},{...board(2),name:'包装'}],'alphabet-page2'));await orderedRead;
assert.deepEqual(Array.from(alphabetic.store.profile.boards,b=>b.title),['人物','包装'],'A-Z preserves server collation instead of applying local pinyin collation');
const alphabetMore=alphabetic.reader.more();assert.equal(options(alphabetic.requests.at(-1).job).sort,'alphabetical');assert.equal(options(alphabetic.requests.at(-1).job).bookmarks[0],'alphabet-page2');
alphabetic.requests.at(-1).resolve(body([{...board(2),name:'包装'},{...board(3),name:'插画'}]));await alphabetMore;
assert.deepEqual(Array.from(alphabetic.store.profile.boards,b=>b.title),['人物','包装','插画'],'pagination keeps server order and deduplicates overlapping boards');
console.log('Alphabetical board order preserves server collation and pagination');


const mismatch=fixture();await first(mismatch);mismatch.reader.boardSort='alphabetical';let mismatchRead=mismatch.reader.read(false,false);mismatch.requests.at(-1).resolve(body([board(2)],'-end-',{resource:{options:{sort:'last_pinned_to'}}}));await mismatchRead;assert(mismatch.store.profile.contentError,'reject mismatched echoed order');assert.equal(mismatch.store.profile.boards[0].id,'profile-api-native-1');

const coverFixture=fixture();
const customCover='https://i.pinimg.com/custom_covers/200x150/synthetic-cover.jpg',alternateCover='https://i.pinimg.com/custom_covers/236x/synthetic-cover.jpg';
const sourceSignature='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sourceCover='https://i.pinimg.com/236x/aa/aa/aa/'+sourceSignature+'.jpg';
const remainingCover='https://i.pinimg.com/236x/remaining.jpg';
await first(coverFixture,[{...board(1),has_custom_cover:true,cover_images:{'236x':{url:alternateCover,width:236,height:null},'200x150':{url:customCover,width:200,height:150}},image_cover_url:customCover,image_cover_hd_url:sourceCover,
  cover_pin:{custom_cover:true,image_url:sourceCover,image_signature:sourceSignature},images:{'236x':[{url:sourceCover},{url:remainingCover},{url:avatar}]}},board(2)]);
assert.equal(JSON.stringify(coverFixture.store.profile.boards[0].covers),JSON.stringify([customCover,remainingCover,avatar]),'custom cover occupies the large left tile and other Pins remain on the right without duplicating the cover source');
assert.equal(JSON.stringify(coverFixture.store.profile.boards[1].covers),JSON.stringify([avatar]),'ordinary board retains its automatic preview');
assert.equal(JSON.stringify(coverFixture.store.profile.boards[0].coverAlternatives),JSON.stringify([customCover,alternateCover]),'standard generated cover before nullable-height 236x tier');
const imageSource=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyBoardCoverImage.ets','utf8');
const logic=imageSource.slice(0,imageSource.indexOf('  build()')).replace('@Component','').replace('export struct','export class').replace(/@Prop @Watch\('resetImages'\) /g,'').replace(/@State /g,'')+'}';
const logicExports={};vm.runInNewContext(ts.transpileModule(logic,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:logicExports});
const imageView=new logicExports.PinmonyBoardCoverImage();imageView.urls=[customCover,alternateCover];assert.equal(imageView.visibleUrls()[0],customCover);imageView.failImage(customCover);assert.equal(imageView.visibleUrls()[0],alternateCover);imageView.failImage(customCover);assert.equal(imageView.failedUrls.length,1);imageView.failImage(alternateCover);assert.equal(imageView.visibleUrls().length,0);imageView.resetImages();assert.equal(imageView.visibleUrls()[0],customCover);imageView.urls=[avatar];imageView.failImage(customCover);assert.equal(imageView.visibleUrls()[0],avatar,'late errors cannot poison a replaced board image');
assert.match(imageSource,/onError\(.*failImage/);
console.log('Board cover card: custom cover is the large left tile, other Pins retained, cover source excluded');

const mergeBoards=[{...board(1),access:['write','delete']},{...board(2),access:['write','delete']}];
let mergeJob, resolveMerge, mergeCalls=0;
const mergeFixture=fixture((job,session,source,viewer,owner,member,live,targets)=>{
  mergeCalls++; mergeJob=job; assert.equal(source,'1');assert.equal(viewer,'42');assert.equal(owner,'42');assert(live());assert.equal(JSON.stringify(targets),'["2"]');
  return new Promise(resolve=>{resolveMerge=resolve;});
});
await first(mergeFixture,mergeBoards);assert(mergeFixture.store.profile.boards.every(b=>b.mergeable));
assert.equal(await mergeFixture.reader.mergeBoards('profile-api-native-1','profile-api-native-1'),'unavailable');assert.equal(mergeCalls,0);
const mergePending=mergeFixture.reader.mergeBoards('profile-api-native-1','profile-api-native-2');
assert.equal(JSON.parse(new URLSearchParams(mergeJob.body).get('data')).options.url,'/v3/boards/1/merge/2/');
resolveMerge({status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_board_merge',data:{type:'board',id:'2'}}})});
await flush();assert.equal(mergeFixture.requests.length,4);mergeFixture.requests[3].resolve(body([mergeBoards[1]]));
assert.equal(await mergePending,'confirmed');assert.equal(mergeFixture.store.profile.boards.length,1);
const unknownMerge=fixture(()=>Promise.resolve({status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_board_merge',data:{type:'board',id:'99'}}})}));
await first(unknownMerge,mergeBoards);assert.equal(await unknownMerge.reader.mergeBoards('profile-api-native-1','profile-api-native-2'),'uncertain');
assert.equal(unknownMerge.store.profile.boards.length,2);assert.equal(await unknownMerge.reader.mergeBoards('profile-api-native-1','profile-api-native-2'),'uncertain');
const staleMerge=fixture(()=>new Promise(resolve=>{resolveMerge=resolve;}));await first(staleMerge,mergeBoards);
const stalePending=staleMerge.reader.mergeBoards('profile-api-native-1','profile-api-native-2');staleMerge.reader.pause();resolveMerge({status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_board_merge',data:{type:'board',id:'2'}}})});
assert.equal(await stalePending,'uncertain');assert.equal(staleMerge.store.profile.boards.length,2);
console.log('Profile drag merge: confirmed target, same-board rejection, response identity, no replay and stale response passed');

const sorted=fixture();await first(sorted,[board(1),board(2)]);sorted.reader.boardSort='alphabetical';
let saving=sorted.reader.reorderBoards(['2','1']);assert.equal(sorted.requests.length,4);
const sortReply=(endpoint,data=null)=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data},client_context:{user:{id:'42'}}});
sorted.requests[3].resolve(sortReply('v3_partial_reorder_boards_handler'));await flush();
assert.equal(sorted.store.profile.boardSort,'alphabetical','do not confirm custom before preference is saved');
assert.equal(sorted.store.profile.boardSortPending,'custom');
assert.equal(JSON.parse(new URLSearchParams(sorted.requests[4].job.body).get('data')).options.data.most_recent_board_sort_order,'custom');
sorted.requests[4].resolve(sortReply('v3_user_metdata_set'));await flush();sorted.requests[5].resolve(body([board(2),board(1)]));await saving;
assert.equal(sorted.store.profile.boardSort,'custom');assert.equal(sorted.store.profile.boardSortBusy,false);
let reread=sorted.reader.sortBoards('');sorted.requests[6].resolve(sortReply('v3_user_metdata_get',{most_recent_board_sort_order:'custom'}));await reread;assert.equal(sorted.store.profile.boardSort,'custom','reopened sort panel retains confirmed custom preference');
const rejectedSort=fixture();await first(rejectedSort);rejectedSort.reader.boardSort='last_pinned_to';saving=rejectedSort.reader.reorderBoards(['1']);
rejectedSort.requests[3].resolve(sortReply('v3_partial_reorder_boards_handler'));await flush();rejectedSort.requests[4].resolve('invalid');await saving;
assert.equal(rejectedSort.store.profile.boardSort,'last_pinned_to');assert(rejectedSort.store.profile.boardSortError);assert.equal(rejectedSort.requests.length,5);
console.log('Custom order preference: persist after reorder, pending state, reopened panel and failed preference validation passed');
const sectionFixture=fixture();await first(sectionFixture,[{...board(1),pin_count:2,section_count:1},{...board(2),pin_count:0,section_count:0}]);assert.equal(sectionFixture.store.profile.boards[0].pinCount,'2 张 Pin 图 · 1 个图板区块');assert.equal(sectionFixture.store.profile.boards[1].pinCount,'0 张 Pin 图');

const f=fixture();await first(f);assert(f.store.profileNativeReadsReady);assert.equal(f.store.profile.coverUrl,avatar,'cover mapped from verified current UserResource without extra requests');assert.equal(f.store.profileActionsReady,false);assert.equal(f.store.profileSessionReady,false);assert.equal(f.store.profile.boards.length,1);assert.equal(f.store.profile.boards[0].collaboratorAvatars.length,2);assert.equal(f.store.profile.unorganizedPins[0].targetUrl,origin+'/pin/3/');assert.equal(f.store.profile.followers,'12 粉丝');
f.store.profileScrollOffset=81;f.reader.pause();f.store.profile=undefined;f.store.profileScrollOffset=0;await f.reader.demand();assert.equal(f.store.profileScrollOffset,81);assert.equal(f.requests.length,3,'hidden home document cannot force another read');
let pending=f.reader.more();f.reader.more();assert.equal(f.requests.length,4);assert.deepEqual(options(f.requests[3].job).bookmarks,['next']);f.requests[3].resolve('bad');await pending;assert(f.store.profile.contentError);assert.equal(f.store.profile.boards.length,1);await f.reader.demand();assert.equal(f.requests.length,4,'failed main read does not poll or fall back');
pending=f.reader.more();f.requests[4].resolve(body([board(1),board(2)],'next'));await pending;assert.equal(f.store.profile.boards.length,2);assert.equal(f.store.profile.contentHasMore,false);await f.reader.more();assert.equal(f.requests.length,5);
pending=f.reader.select('created');assert.equal(f.store.profile.section,'created');assert.equal(f.requests.length,6);assert.equal(options(f.requests[5].job).user_id,'42');assert.equal(new URL(f.requests[5].job.url).searchParams.get('source_url'),'/sample/_created/');f.requests[5].resolve(body([pin(7),pin(7)]));await pending;assert.equal(f.store.profile.createdPins.length,1);f.store.profileScrollOffset=24;await f.reader.select('saved');assert.equal(f.requests.length,6);assert.equal(f.store.profileScrollOffset,81);await f.reader.select('created');assert.equal(f.store.profileScrollOffset,24);assert.equal(f.requests.length,6);
const current=f.store.profile;for(const message of [{kind:'state',session:4,profileUrl:page,section:'created',createdPins:[],boards:[]},{kind:'state',nativeOwn:true,nativeVersion:current.nativeVersion,contextEpoch:6,session:4,profileUrl:page,section:'created'}])f.reader.updateBridge(JSON.stringify(message));assert.equal(f.store.profileActionsReady,false);assert.equal(f.store.profile.createdPins.length,1);
f.setDocument(page);f.reader.updateBridge(JSON.stringify({kind:'nativeContext',nativeOwn:true,contextEpoch:7,session:8,profileUrl:page,section:'saved'}));assert(f.store.profileSessionReady);assert.equal(f.store.profileActionsReady,false);assert.equal(f.store.profile.section,'created');
f.reader.updateBridge(JSON.stringify({kind:'state',nativeOwn:true,nativeVersion:current.nativeVersion,contextEpoch:7,session:8,profileUrl:page,section:'created',boards:[board(99)],createdPins:[pin(99)]}));assert(f.store.profileActionsReady);assert.equal(f.store.profile.createdPins[0].targetUrl,origin+'/pin/7/','Web feed cannot replace native main data');
f.reader.updateBridge(JSON.stringify({kind:'nativeContext',nativeOwn:true,contextEpoch:7,session:2,profileUrl:page,section:'saved'}));assert.equal(f.store.profileSession,8);
pending=f.reader.refresh(true);assert(f.store.profilePullRefreshing);assert.equal(f.store.profileActionsReady,false);f.reader.updateBridge(JSON.stringify({kind:'state',nativeOwn:true,nativeVersion:current.nativeVersion,contextEpoch:7,session:8,profileUrl:page,section:'created'}));assert.equal(f.store.profileActionsReady,false,'old native version cannot authorize after refresh');f.requests[6].resolve(userBody());await flush();f.requests[7].resolve(body([]));await pending;assert.equal(f.store.profile.createdPins.length,0);assert.equal(f.store.profilePullRefreshing,false);
for(const revoke of [g=>g.reader.pause(),g=>g.setActive(false),g=>g.setSelected(false),g=>g.setPage(origin+'/other/'),g=>g.setSession({...g.getSession(),accountId:'other',generation:2})]){const g=fixture(),p=g.reader.demand();revoke(g);g.requests[0].resolve(userBody());await p;assert.equal(g.requests.length,1);assert.equal(g.store.profile?.displayName||'','');}
for(const invalid of [userBody({client_context:{user:{id:'99'}}}),userBody({client_context:{}}),body({...user,username:'other'},'',{client_context:{user:{id:'42'}}})]){const g=fixture(),p=g.reader.demand();g.requests[0].resolve(invalid);await p;assert(g.store.profileError);await g.reader.demand();assert.equal(g.requests.length,1,'identity failure requires explicit retry');}
const g=fixture();await first(g);g.setSession({...g.getSession(),accountId:'new-cache-hash',generation:2});pending=g.reader.demand();assert.equal(g.store.profile.boards.length,0);assert.equal(g.store.profileCache.get(page,'saved'),undefined);g.requests[3].resolve(userBody());await flush();g.requests[4].resolve(body([]));await flush();g.requests[5].resolve(body([]));await pending;assert.equal(g.store.profile.boards.length,0);
const story={type:'story',id:'all',story_type:'all_pins',title:{text:'所有 Pin'},action:{url:'/users/42/pins/'},objects:[{image_medium_url:avatar}]};const s=fixture();await first(s,[story]);assert.equal(s.store.profile.boards[0].targetUrl,page+'pins/');const invalidStory=fixture();pending=invalidStory.reader.demand();invalidStory.requests[0].resolve(userBody());await flush();invalidStory.requests[1].resolve(body([{...story,action:{url:'/users/99/pins/'}}]));await pending;assert(invalidStory.store.profile.contentError);await invalidStory.reader.demand();assert.equal(invalidStory.requests.length,2);
const write=fixture();await first(write);write.setDocument(page);pending=write.reader.more();
const mutation={kind:'state',nativeOwn:true,nativeVersion:write.store.profile.nativeVersion,nativeInvalidation:1,contextEpoch:7,session:1,profileUrl:page,section:'saved'};
write.reader.updateBridge(JSON.stringify(mutation));assert.equal(write.requests.length,4,'confirmed invalidation coalesces with the current GET');write.requests[3].resolve(body([board(1)],'-end-'));await pending;assert.equal(write.requests.length,5,'finish current GET then re-read, never replay the write');
write.reader.updateBridge(JSON.stringify(mutation));assert.equal(write.requests.length,5);write.requests[4].resolve(userBody());await flush();write.requests[5].resolve(body([board(2)]));await flush();write.requests[6].resolve(body([]));await flush();assert.equal(write.store.profile.boards[0].title,'Board 2');assert(write.requests.every(r=>r.job.method==='GET'));
const afterRead=fixture();await first(afterRead);afterRead.setDocument(page);
const adoptedSnapshot={kind:'state',nativeOwn:true,nativeVersion:afterRead.store.profile.nativeVersion,contextEpoch:7,session:1,profileUrl:page,section:'saved'};afterRead.reader.updateBridge(JSON.stringify(adoptedSnapshot));pending=afterRead.reader.more();afterRead.requests[3].resolve(body([board(1)],'-end-'));await pending;
afterRead.reader.updateBridge(JSON.stringify({...adoptedSnapshot,nativeInvalidation:1,boards:[board(99)]}));assert.equal(afterRead.requests.length,5,'confirmed write finishing after newer GET still refreshes');assert.equal(afterRead.store.profile.boards[0].title,'Board 1');afterRead.requests[4].resolve(userBody());await flush();afterRead.requests[5].resolve(body([board(3)]));await flush();afterRead.requests[6].resolve(body([]));await flush();assert.equal(afterRead.store.profile.boards[0].title,'Board 3');
const identity=fixture();await first(identity);pending=identity.reader.refresh();identity.requests[3].resolve(userBody({client_context:{user:{id:'99'}}}));await pending;assert.equal(identity.store.profile.displayName,'Sample');assert.equal(identity.store.profileNativeReadsReady,false);assert.equal(identity.reader.installScript(),'');assert(identity.store.profileError);
const cancel=fixture();await first(cancel);pending=cancel.reader.select('created');const late=cancel.requests[3];await cancel.reader.select('saved');late.resolve(body([pin(99)]));await pending;assert.equal(cancel.store.profile.section,'saved');assert.equal(cancel.store.profile.boards.length,1);assert(cancel.cancelled.length);
const uk=fixture();uk.setSession({...uk.getSession(),origin:'https://uk.pinterest.com'});uk.setPage('https://uk.pinterest.com/sample/');await first(uk,[board(1)]);assert.equal(uk.store.profile.profileUrl,'https://uk.pinterest.com/sample/');
const net=new Network();let sent=0,context,session=f.getSession();net.request=async(job,current)=>{context=current;if(!acceptsNetworkJob(job,current()))return{error:'rejected'};sent++;return{error:''};};for(const req of f.requests){assert.equal((await net.requestBusinessProfileRead(req.job,()=>session,page,req.userId,()=>true)).error,'');}
const valid=f.requests[1],mutate=fn=>{const u=new URL(valid.job.url),p=JSON.parse(u.searchParams.get('data'));fn(p.options);u.searchParams.set('data',JSON.stringify(p));return{...valid.job,url:u.href}};
const before=sent;for(const bad of [{...valid.job,method:'POST'},{...valid.job,page:origin+'/other/'},{...valid.job,id:'bridge_1'},mutate(o=>o.username='other'),mutate(o=>o.bookmarks=['a','b']),mutate(o=>o.field_set_key='admin'),mutate(o=>o.extra=true)])assert((await net.requestBusinessProfileRead(bad,()=>session,page,'42',()=>true)).error);assert.equal(sent,before);await net.requestBusinessProfileRead(valid.job,()=>session,page,'42',()=>true);session={...session,accountId:'changed'};assert.equal(context().authenticated,false);
// Real Web adapters suppress the migrated GETs; adoption leaves organize contracts intact.
const apiScript=load('feature_profile/src/main/ets/services/PinmonyProfileApiScript.ets').PIN_PROFILE_API_SCRIPT,organizeScript=load('feature_profile/src/main/ets/services/PinmonyProfileOrganizeScript.ets').PIN_PROFILE_ORGANIZE_SCRIPT,bridgeScript=load('feature_profile/src/main/ets/services/PinmonyProfileScript.ets').PIN_PROFILE_BRIDGE_SCRIPT;
let fetches=0;const timers=[],states=[];const location={hostname:'www.pinterest.com',origin,pathname:'/sample/',href:page};const window={PinmonyNativeProfileReadsEnabled:true,PinmonyProfileApiEnabled:true,PinmonyProfileOrganizeEnabled:true,PinmonyHomeUsername:'sample',PinmonyNetwork:{documentEpoch:()=>7,isReady:()=>true,isForeground:()=>true},PinmonyShareBridge:{profileState:s=>states.push(JSON.parse(s))},addEventListener(){},setInterval(){}};window.top=window;
const ctx={window,location,navigator:{language:'zh'},document:{cookie:''},URL,AbortController,setTimeout:fn=>{timers.push(fn);return timers.length},clearTimeout(){},fetch(){fetches++;throw Error('duplicate migrated Web read')},console};vm.runInNewContext(apiScript+organizeScript+bridgeScript,ctx);while(timers.length)timers.shift()();assert.equal(states.at(-1).kind,'nativeContext');assert.equal(fetches,0);await f.reader.select('saved');window.PinmonyHomeUsername='';window.PinmonyHomeApi={setUsername:value=>{window.PinmonyHomeUsername=value;}};vm.runInNewContext(f.reader.installScript(),ctx);assert.equal(window.PinmonyHomeUsername,'sample','validated own-profile identity initializes a fresh document');while(timers.length)timers.shift()();assert.equal(states.at(-1).kind,'state');assert.equal(states.at(-1).nativeOwn,true);assert.equal(states.at(-1).nativeVersion,f.store.profile.nativeVersion);assert.equal(fetches,0);assert.equal(window.PinmonyProfileApi.more(page,'saved',()=>{},()=>true),false);assert.equal(window.PinmonyProfileApi.installNative('https://uk.pinterest.com/sample/',{},'saved',{},''),false);assert.equal(window.PinmonyProfileApi.organizeAction('open','',false),true,'native unorganized Pin IDs feed the original organize flow');while(timers.length)timers.shift()();assert.equal(states.at(-1).organize.phase,'select');assert.equal(fetches,0);
// A pause revokes action readiness, but a fresh install must publish the current native version.
const retainedBoardCount=f.store.profile.boards.length;f.reader.pause(); f.setDocument(page); window.PinmonyShareBridge.profileState=value=>f.reader.updateBridge(value);
vm.runInNewContext(f.reader.installScript()+'window.PinmonyProfileSync();',ctx);while(timers.length)timers.shift()();
assert.equal(f.store.profileSessionReady,true,'paused own-profile recovers a document session');
assert.equal(f.store.profileActionsReady,true,'current-version install must be accepted by the real native receiver');
assert.equal(f.store.profile.boards.length,retainedBoardCount,'handshake preserves native feed');
const publishMessages=[];window.PinmonyShareBridge.profilePublish=value=>publishMessages.push(JSON.parse(value));
assert.equal(window.PinmonyProfilePublishDiscover(f.store.profileSession,page),true,'actual publish discover accepts the recovered session');
assert.equal(publishMessages.length,1);assert.equal(publishMessages[0].options.length,3);assert.equal(publishMessages[0].session,f.store.profileSession);
assert.equal(window.PinmonyProfileApi.organizeAction('open','',false),true,'actual organize opens with the recovered document context');
while(timers.length)timers.shift()();assert.equal(f.store.profile.organize.phase,'select');

// Execute the actual Index read entrypoints while hidden Web stays on home.
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');function method(name){const start=index.search(new RegExp('  private (?:async )?'+name+'\\(')),end=index.indexOf('\n  private ',start+1);assert(start>=0,name);return index.slice(start,end);}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+['usesNativeProfileReads','currentProfileUrl','refreshProfile','loadMoreProfile','prepareProfileInteraction','onRootPageVisible'].map(method).join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_PROFILE_READS_ENABLED:true, PinmonyRuntimeLog:{info(){},warn(){}}});
const host=new Host();let nativeCalls=0;Object.assign(host,{nativeBusinessRoutesEnabled:true,profileStore:{origins:[]},authStatus:'authenticated',profileNativeReads:{eligible:()=>true,refresh:()=>nativeCalls++,more:()=>nativeCalls++},authenticatedProfileUrl:page,profileUrlFromAddress:a=>a,controller:{getUrl(){throw Error('hidden Web must not gate own root')}},profileReadController:{refresh(){throw Error('legacy read')},loadMore(){throw Error('legacy paging')}}});assert.equal(host.currentProfileUrl(),page);host.refreshProfile(true);host.loadMoreProfile();assert.equal(nativeCalls,2);
let legacyReads=0,visibleDemands=0;Object.assign(host,{activeTab:3,tabRequestToken:1,nativeRootTabsVisible:()=>true,pagePerformance:{mark(){}},markRootPerformance(){},requestRootPage(){legacyReads++},coordinatorTasks:{timeout:fn=>fn()}});
host.profileNativeReads.demand=()=>{visibleDemands++};host.onRootPageVisible(3,true);assert.equal(visibleDemands,1);assert.equal(legacyReads,0,'waiting for business identity never prepares hidden Web');
// Reusing a profile document on the other segment must install before waiting for its session.
window.PinmonyShareBridge.profileState=value=>f.reader.updateBridge(value);await f.reader.select('created');
let installed=false;host.profileNativeReads=f.reader;host.profileStore=f.store;
host.ensureRootActionContext=async(index,data)=>{while(timers.length)timers.shift()();assert(installed,'adopt the selected native section before waiting for an old document');return data?f.store.profileActionsReady:f.store.profileSessionReady;};
Object.assign(host,{businessSuspended:false,activeSheetKind:'',pinStore:{},nativeBusinessSessionContext:()=>({generation:1})});
host.bindNativeNetwork=()=>{window.PinmonyNetwork.isReady=()=>true;};
host.controller={getUrl:()=>page,runJavaScript:async script=>{installed=true;vm.runInNewContext(script,ctx);return 'true';}};
host.sessionDocumentUrl = () => page; host.runSessionScript = script => host.controller.runJavaScript(script); host.loadSessionDocument = () => { throw Error('unexpected navigation'); }; host.coordinatorTasks.wait = async () => true;
assert.equal(await host.prepareProfileInteraction(),true);assert(f.store.profileActionsReady);assert.equal(f.store.profile.section,'created');assert.equal(f.store.profile.session,f.store.profileSession);

const beforeSync = states.length;
window.PinmonyShareBridge.profileState=value=>states.push(JSON.parse(value));
window.PinmonyProfileSync();
assert.equal(states.length, beforeSync + 1, 'explicit handshake publishes without hidden document timers');
assert.equal(states.at(-1).kind, 'state');
console.log('Native own profile: identity, boards/all-Pins/collaborators, created/unorganized Pins, paging/error/retry, segments/scroll, region/account/route cancellation, transport restrictions, current-document write handshake, stale Web isolation, organize adoption and Index native reads passed');}
const completion=setTimeout(()=>{throw Error('Native profile check did not complete');},15000);
main().then(()=>clearTimeout(completion)).catch(e=>{clearTimeout(completion);console.error(e);process.exitCode=1});
