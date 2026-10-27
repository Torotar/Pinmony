const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:withLocalMessages(deps),setTimeout,clearTimeout,console});return exports;}
const {PinmonyProfileCache:Cache}=load('feature_profile/src/main/ets/services/PinmonyProfileCache.ets');
const {PinmonyProfileNativeReads:Reader}=load('entry/src/main/ets/app/PinmonyProfileNativeReads.ets',n=>n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',page=origin+'/sample/',avatar='https://i.pinimg.com/synthetic.jpg';
const user={type:'user',id:'42',username:'sample',full_name:'Sample',profile_cover:{source:'image',images:{'736x':{url:avatar,width:736,height:414}}},image_large_url:avatar,follower_count:12,following_count:3,pin_count:2};
const pin=id=>({type:'pin',id:String(id),grid_title:'Pin '+id,images:{'736x':{url:avatar,width:100,height:200}},pinner:{id:'42'}});
const board=id=>({type:'board',id:String(id),name:'Board '+id,url:'/sample/board'+id+'/',images:{'236x':[{url:avatar}]},pin_count:5,is_collaborative:true,owner:{id:'42',image_small_url:avatar},collaborating_users:[{id:'42',image_small_url:avatar},{id:'43',image_small_url:avatar}]});
const body=(data,bookmark='-end-',extra={})=>JSON.stringify({resource_response:{status:'success',code:0,data,bookmark},...extra});
const userBody=(extra={})=>body(user,'',{client_context:{user:{id:'42'}},...extra});
const flush=()=>new Promise(r=>setImmediate(r));
function checkedBody(payload,job){let result;try{result=JSON.parse(payload)}catch{return payload}let r=result.resource_response;if(!r||r.endpoint_name)return payload;let o;try{o=JSON.parse(new URL(job.url).searchParams.get('data')).options}catch{return payload}let endpoint='';if(job.url.includes('UserActivityPinsResource'))endpoint='v3_get_bizpro_feed';if(job.url.includes('BoardsResource'))endpoint=o.filter_types?'v3_get_user_filtered_board_feed':'v3_user_profile_boards_feed';if(/^\/v3\/users\/profile\/pins\/cluster\/.+\/feed\/$/.test(o.url))endpoint='v3_get_user_profile_pins_cluster_feed';if(o.url==='/v3/users/profile/pins/clusters/')endpoint='v3_get_user_profile_pin_clusters';if(o.url==='/v3/users/me/shuffles/')endpoint='v3_get_user_collage_drawer_homefeed_pins';if(o.url==='/v3/users/me/filtered/pins/')endpoint='v3_get_user_filtered_pins_handler';if(endpoint)r.endpoint_name=endpoint;return JSON.stringify(result);}
function fixture(){let session={authenticated:true,accountId:'cache-hash',generation:1,origin,userAgent:'synthetic'},target=page,active=true,selected=true,document=origin+'/',epoch=7;
const store={profileSession:0,profileActionsReady:false,profileSessionReady:false,profileScrollOffset:0,profileCache:new Cache(),origins:[]},requests=[],cancelled=[],addresses=[];
const reader=new Reader({store:()=>store,session:()=>session,page:()=>target,selected:()=>selected,active:()=>active,network:()=>({requestBusinessProfileSuggestion:(job,session,cluster,name,owns)=>new Promise(resolve=>requests.push({job,resolve:(payload,status=200,error='')=>resolve({...job,body:checkedBody(payload,job),status,error})})),cancel:id=>cancelled.push(id),requestBusinessProfileSort:(job,s,id,viewer,owns)=>{assert(owns());return new Promise(resolve=>requests.push({job,userId:id,resolve:(payload,status=200,error='')=>resolve({...job,body:checkedBody(payload,job),status,error})}));},requestBusinessProfileRead:(job,s,p,id,owns)=>{assert(owns());return new Promise(resolve=>requests.push({job,userId:id,resolve:(payload,status=200,error='')=>resolve({...job,body:checkedBody(payload,job),status,error})}));}}),settled(){store.profilePullRefreshing=false},recordAddress:a=>addresses.push(a),document:()=>document,documentEpoch:()=>epoch});
return {reader,store,requests,cancelled,addresses,getSession:()=>session,setSession:s=>session=s,setPage:p=>target=p,setActive:v=>active=v,setSelected:v=>selected=v,setDocument:d=>document=d,setEpoch:v=>epoch=v};}
function options(job){return JSON.parse(new URL(job.url).searchParams.get('data')).options;}
function endpoint(job){return new URL(job.url).pathname;}
async function first(f,boards=[board(1)],cursor='next',unorganized=[pin(3)]){const pending=f.reader.demand();f.reader.demand();assert.equal(f.requests.length,1);assert.equal(endpoint(f.requests[0].job),'/resource/UserResource/get/');f.requests[0].resolve(userBody());await flush();assert.equal(f.requests.length,2);assert.equal(endpoint(f.requests[1].job),'/resource/BoardsFeedResource/get/');f.requests[1].resolve(body(boards,cursor));await flush();assert.equal(f.requests.length,3);assert.equal(endpoint(f.requests[2].job),'/resource/BoardlessPinsResource/get/');f.requests[2].resolve(body(unorganized));await pending;}


async function main(){
 const f=fixture();await first(f);let n=f.requests.length;
 let pending=f.reader.select('hub:pins:0:0');assert.equal(endpoint(f.requests[n].job),'/resource/ApiResource/get/');assert.equal(options(f.requests[n].job).url,'/v3/users/profile/pins/clusters/');
 f.requests[n++].resolve(body({type:'story',story_type:'user_organize_pin_groupings',objects:[{id:'cluster_sample',type:'pincluster',names:['Example'],pin_count:2,thumbnails:[{'236x':{url:avatar}}]}]}));await flush();
 assert.equal(options(f.requests[n].job).data.flag_filters,'');const allJob=f.requests[n].job;
 f.requests[n++].resolve(body([pin(11)],'page2'));await pending;assert.equal(f.store.profile.createdPins.length,1);assert.equal(f.store.profile.suggestions.length,1);
 pending=f.reader.select('hub:pins:1:0');assert.equal(options(f.requests[n].job).data.flag_filters,'FAVORITED');f.requests[n++].resolve(body([{...pin(12),favorited_by_me:true}]));await pending;assert.equal(f.store.profile.createdPins[0].favorite,true);
 pending=f.reader.select('hub:pins:1:1');const combinedJob=f.requests[n].job;assert.equal(options(f.requests[n].job).data.flag_filters,'FAVORITED,CREATED_BY_ME');f.requests[n++].resolve(body([pin(14)]));await pending;assert.equal(f.store.profile.createdPins.length,1);
 pending=f.reader.select('hub:pins:0:1');const createdJob=f.requests[n].job;assert.equal(options(f.requests[n].job).data.flag_filters,'CREATED_BY_ME');f.requests[n++].resolve(body([pin(14)]));await pending;
 pending=f.reader.select('hub:secret:0:0');const secretJob=f.requests[n].job;assert.equal(options(secretJob).filter_types,3);f.requests[n++].resolve(body([{...board(2),privacy:'secret'}]));await pending;assert.equal(f.store.profile.boards[0].secret,true);
 pending=f.reader.select('hub:groups:0:0');assert.equal(options(f.requests[n].job).filter_types,2);f.requests[n++].resolve(body([]));await pending;assert.equal(f.store.profile.boards.length,0);
 pending=f.reader.select('hub:collages:0:0');assert.equal(options(f.requests[n].job).data.is_draft,false);assert.equal(options(f.requests[n].job).data.transform_to_pins,true);f.requests[n++].resolve(body([]));await pending;
 pending=f.reader.select('hub:drafts:0:0');const draftJob=f.requests[n].job;assert.equal(options(f.requests[n].job).data.is_draft,true);assert.equal(options(f.requests[n].job).data.fields[0],'shuffle.id');f.requests[n++].resolve(body([]));await pending;
 await f.reader.select('hub:pins:1:0');assert.equal(f.requests.length,n,'cached favorite tab does not request again');assert.equal(f.store.profile.createdPins[0].id,'profile-api-native-12'); await f.reader.select('hub:groups:0:0');assert.equal(f.requests.length,n,'cached group tab does not request again'); pending=f.reader.select('hub:pins:0:0');await pending;const refreshing=f.reader.refresh(true);f.requests[n++].resolve(userBody());await flush();f.requests[n++].resolve(body({type:'story',story_type:'user_organize_pin_groupings',objects:[]}));await flush();const old=n++;const newer=f.reader.select('hub:groups:0:0');f.requests[n++].resolve(body([]));await newer;f.requests[old].resolve(body([pin(99)]));await refreshing;assert.equal(f.store.profile.hubMode,'groups');assert.equal(f.store.profile.createdPins.length,0);
 pending=f.reader.select('saved');await pending;assert(!f.store.profile.hubMode);assert.equal(f.store.profile.boards.length,1);

 const w=fixture();await first(w);let wi=w.requests.length;
 let wp=w.reader.select('hub:pins:0:0');w.requests[wi++].resolve(body({type:'story',story_type:'user_organize_pin_groupings',objects:[{id:'cluster_test',type:'pincluster',names:['Suggested'],pin_count:2,thumbnails:[{'236x':{url:avatar}}]}]}));await flush();w.requests[wi++].resolve(body([pin(1)]));await wp;
 wp=w.reader.select('hub-create:cluster_test');const clusterJob=w.requests[wi].job;
 assert.equal(clusterJob.method,'GET');assert.equal(w.store.profile.organize.loading,true);
 w.requests[wi++].resolve(body([{id:'1',images:pin(1).images}],'cluster-page2'));await flush();assert.deepEqual(options(w.requests[wi].job).bookmarks,['cluster-page2']);
 w.requests[wi++].resolve(body([{id:'2',images:pin(2).images}]));await wp;assert.equal(w.store.profile.organize.selectedIds.join(','),'1,2');
 await w.reader.unorganizedAction('all');assert.equal(w.store.profile.organize.selectedIds.length,0);
 await w.reader.unorganizedAction('next');assert.equal(w.requests.length,wi,'zero selection does not create');
 await w.reader.unorganizedAction('all');await w.reader.unorganizedAction('toggle','2');
 wp=w.reader.unorganizedAction('next');const createJob=w.requests[wi].job;assert.equal(endpoint(createJob),'/resource/BoardResource/create/');
 await w.reader.select('hub-create:cluster_test');assert.equal(w.requests.length,wi+1,'no duplicate creation');
 w.requests[wi++].resolve(body({...board(9),name:'Suggested',access:['write','delete']},'',{resource_response:{status:'success',code:0,endpoint_name:'v3_create_board',data:{...board(9),name:'Suggested',access:['write','delete']}}}));await flush();
 const moveJob=w.requests[wi].job;assert.equal(endpoint(moveJob),'/resource/ApiResource/update/');assert.equal(JSON.parse(new URLSearchParams(moveJob.body).get('data')).options.data.board_id,'9');
 w.requests[wi++].resolve('{}');await wp;assert(w.store.profile.organize.uncertain,'unknown move must not report success');assert.equal(JSON.parse(new URLSearchParams(moveJob.body).get('data')).options.data.deselected_pin_ids.join(','),'2');
 await w.reader.select('hub-create:cluster_test');assert.equal(w.requests.length,wi,'no replay after partial write');

 const success=fixture();await first(success);let si=success.requests.length;
 let sp=success.reader.select('hub:pins:0:0');success.requests[si++].resolve(body({type:'story',story_type:'user_organize_pin_groupings',objects:[{id:'cluster_ok',type:'pincluster',names:['Suggested'],pin_count:2,thumbnails:[{'236x':{url:avatar}}]}]}));await flush();success.requests[si++].resolve(body([pin(1)]));await sp;
 sp=success.reader.select('hub-create:cluster_ok');const abandoned=success.requests[si++];await success.reader.unorganizedAction('close');abandoned.resolve(body([pin(99)]));await sp;assert(!success.store.profile.organize,'late feed cannot reopen selection');sp=success.reader.select('hub-create:cluster_ok');success.requests[si++].resolve(body([pin(1),pin(2)]));await sp;await success.reader.unorganizedAction('close');assert(!success.store.profile.organize);sp=success.reader.select('hub-create:cluster_ok');success.requests[si++].resolve(body([pin(1),pin(2)]));await sp;sp=success.reader.unorganizedAction('next');success.requests[si++].resolve(JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_create_board',data:{...board(9),name:'Suggested',access:['write']}}}));await flush();
 success.requests[si++].resolve(JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_move_cluster_pins',data:null}}));await flush();
 assert.equal(options(success.requests[si].job).url,'/v3/users/profile/pins/clusters/');success.requests[si++].resolve(body({type:'story',story_type:'user_organize_pin_groupings',objects:[]}));await flush();success.requests[si++].resolve(body([]));await sp;assert.equal(success.store.profile.contentError,'');assert.equal(success.store.profile.suggestions.length,0);assert(!success.store.profile.suggestionWriting);
 const bad=success.reader.select('hub:pins:1:0');success.requests[si++].resolve(body([pin(3)],'',{resource_response:{status:'success',code:0,endpoint_name:'wrong_endpoint',data:[pin(3)]}}));await bad;assert(success.store.profile.contentError);assert.equal(success.store.profile.createdPins.length,0);
 const net=new Network();let calls=0;net.request=async(job,current)=>{const ok=current().authenticated;if(ok)calls++;return {error:ok?'':'rejected'};};const session={authenticated:true,accountId:'cache-hash',generation:1,origin,userAgent:'synthetic'};
 for(const job of [allJob,secretJob,combinedJob,createdJob,draftJob])assert.equal((await net.requestBusinessProfileRead(job,()=>session,page,'42',()=>true,'42')).error,'');assert.equal(calls,5);assert.equal((await net.requestBusinessProfileRead(clusterJob,()=>session,page,'42',()=>true,'42')).error,'');assert((await net.requestBusinessProfileRead(clusterJob,()=>session,page,'42',()=>true,'43',true)).error);
 const changed={...allJob,url:allJob.url.replace(encodeURIComponent('/v3/users/me/filtered/pins/'),encodeURIComponent('/v3/users/other/pins/'))};assert((await net.requestBusinessProfileRead(changed,()=>session,page,'42',()=>true,'42')).error);
 assert((await net.requestBusinessProfileRead(allJob,()=>session,page,'42',()=>true,'43',true)).error);
 assert((await net.requestBusinessProfileRead(secretJob,()=>session,page,'42',()=>false,'42')).error);
 const writeSession={authenticated:true,accountId:'cache-hash',generation:1,origin,userAgent:'synthetic'};
 assert.equal((await net.requestBusinessProfileSuggestion(createJob,()=>writeSession,'cluster_test','Suggested',()=>true)).error,'');
 assert.equal((await net.requestBusinessProfileSuggestion(moveJob,()=>writeSession,'cluster_test','Suggested',()=>true,['1','2'])).error,'');
 assert((await net.requestBusinessProfileSuggestion(moveJob,()=>writeSession,'other_cluster','Suggested',()=>true)).error);
 assert((await net.requestBusinessProfileSuggestion(createJob,()=>writeSession,'cluster_test','Wrong name',()=>true)).error);
 assert((await net.requestBusinessProfileSuggestion(moveJob,()=>writeSession,'cluster_test','Suggested',()=>true,['1'])).error);
 const drafts=fixture();await first(drafts);let di=drafts.requests.length;
 const draft={id:'501',images:{'736x':{url:avatar,width:736,height:920}},updated_at:'2026-10-26T12:00:00Z'};
 let dp=drafts.reader.select('hub:drafts:0:0');drafts.requests[di++].resolve(body([draft,draft]));await dp;
 assert.equal(drafts.store.profile.contentError,'');assert.equal(drafts.store.profile.createdPins.length,1);
 const card=drafts.store.profile.createdPins[0];assert.equal(card.collageDraft,true);assert.equal(card.id,'profile-collage-draft-501');assert.equal(card.imageUrl,avatar);assert.equal(card.targetUrl,undefined,'shuffle ids never become Pin routes');
 dp=drafts.reader.select('hub:collages:0:0');drafts.requests[di++].resolve(body([pin(501)]));await dp;
 assert.equal(drafts.store.profile.createdPins[0].id,'profile-api-native-501');assert(!drafts.store.profile.createdPins[0].collageDraft);
 await drafts.reader.select('hub:drafts:0:0');assert.equal(drafts.requests.length,di,'draft cache is independent from published collage cache');assert.equal(drafts.store.profile.createdPins[0].collageDraft,true);
 for(const invalid of [{...draft,id:'../pin/501'}, {...draft,images:{'736x':{url:'https://example.com/draft.png'}}},pin(501)])assert.equal(drafts.reader.collageDraft(invalid),undefined);
 dp=drafts.reader.refresh();drafts.requests[di++].resolve(userBody());await flush();drafts.requests[di++].resolve(body([{...draft,images:{}}]));await dp;assert(drafts.store.profile.contentError,'malformed drafts remain a failure, not empty success');
 const profileUi=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
 assert.equal((profileUi.match(/!pin.collageDraft && this.interactionReady && this.onPin/g)||[]).length,2,'both image and title decline unimplemented draft clicks');
 console.log('Profile hub: nonempty shuffle drafts, independent cache, malformed data, no Pin route, published collages, legacy restore, stale isolation and transport guards passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
