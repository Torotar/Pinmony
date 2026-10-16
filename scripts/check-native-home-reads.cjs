const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
function load(file,deps){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:deps||(()=>({})),console});return exports;}
const {PinmonyHomeNativeReads}=load('entry/src/main/ets/app/PinmonyHomeNativeReads.ets', name=>name==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:name==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{});
const flush=()=>new Promise(r=>setImmediate(r));
const pins=(ids,cursor)=>JSON.stringify({resource_response:{status:'success',data:ids.map(id=>({id:String(id),type:'pin',grid_title:'grid',title:'other',images:{'474x':{url:'https://i.pinimg.com/'+id+'.jpg',width:474,height:700}}})),bookmark:cursor}});
const categories=JSON.stringify({resource_response:{status:'success',data:[{type:'board',id:'7',name:'Board'},{type:'board',id:'8',name:'Other'}]}});
function fixture(){
 let session={authenticated:true,generation:1,accountId:'account',origin:'https://www.pinterest.com',userAgent:'fixture'}, active=true;
 const store={homeSourceWarning:'',homeActionsReady:false,cachedHomeScrollOffset:123},jobs=[],canceled=[],commits=[];
 const controller=new PinmonyHomeNativeReads({store:()=>store,session:()=>session,username:()=> 'reader',active:()=>active,saved:()=>false,
 network:()=>({cancel:id=>canceled.push(id),requestBusinessHomeRead(job,getSession,user,board,current){assert(current());assert.equal(job.page,session.origin+'/');return new Promise(resolve=>jobs.push({job,board,current,resolve:body=>resolve({status:current()?200:0,error:current()?'':'cancelled',body})}));}}),committed:snapshot=>commits.push(snapshot)});
 return {controller,store,jobs,canceled,commits,setSession:value=>session=value,session:()=>session,setActive:value=>active=value};
}
async function ready(f){const read=f.controller.demand();assert.match(f.jobs[0].job.url,/UserHomefeedResource/);assert.match(f.jobs[1].job.url,/BoardsFeedResource/);f.jobs[0].resolve(pins([1,2],'next'));await read;f.jobs[1].resolve(categories);await flush();}
async function main(){
 const f=fixture();await ready(f);
 assert.equal(f.store.homeNativeReadsReady,true);assert.equal(f.store.homeActionsReady,false,'native reads never grant Web writes');assert.equal(f.store.home.session,0);
 assert.equal(f.store.home.pins[0].title,'grid');assert.equal(f.store.home.tabs.length,3);assert.equal(f.store.cachedHomeScrollOffset,123);
 const more=f.controller.more();f.controller.more();assert.equal(f.jobs.length,3);assert.equal(JSON.parse(new URL(f.jobs[2].job.url).searchParams.get('data')).options.bookmarks[0],'next');
 f.jobs[2].resolve(pins([2,3],'next'));await more;assert.equal(f.store.home.pins.length,3);assert.equal(f.store.home.endReached,true);
 let refresh=f.controller.refresh();f.jobs[3].resolve('bad');await refresh;assert.equal(f.store.home.pins.length,3);assert(f.store.homeError);
 refresh=f.controller.refresh();f.jobs[4].resolve(pins([],''));await refresh;assert.equal(f.store.home.pins.length,0);assert.equal(f.store.home.endReached,true);
 const board=f.controller.select('tab:7');assert.match(f.jobs[5].job.url,/BoardContentRecommendationResource/);assert.match(f.jobs[6].job.url,/BoardResource/);
 f.jobs[6].resolve(JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_get_board',data:{id:'7',name:'Board',pin_count:12}}}));await flush();
 f.jobs[5].resolve(pins([4],'board-next'));await board;assert.equal(f.store.home.board.id,'7');assert.equal(f.store.home.selectedTab,'Board');
 await f.controller.select('tab:all');assert.equal(f.jobs.length,7,'category return uses cursor cache');assert.equal(f.store.home.pins.length,0);
 await f.controller.select('tab:7');const page=f.controller.more();assert.equal(JSON.parse(new URL(f.jobs[7].job.url).searchParams.get('data')).options.bookmarks[0],'board-next');
 f.jobs[7].resolve(pins([5],'-end-'));await page;assert.equal(f.store.home.pins.length,2);
 f.controller.pause();f.setActive(false);await f.controller.demand();assert.equal(f.jobs.length,8);f.setActive(true);await f.controller.demand();assert.equal(f.jobs.length,8,'root switch reuses retained feed');
 for(const revoke of [g=>g.controller.pause(),g=>g.setActive(false),g=>g.setSession({...g.session(),accountId:'other',generation:2}),g=>g.setSession({...g.session(),generation:2})]){
   const g=fixture();const read=g.controller.demand();revoke(g);g.jobs[0].resolve(pins([99],''));g.jobs[1].resolve(categories);await read;await flush();assert(!g.store.home?.pins.some(pin=>pin.id==='99'));
 }
 const reset=fixture();await ready(reset);reset.controller.reset();assert.equal(reset.store.home,undefined);assert.equal(reset.store.homeNativeReadsReady,false);assert.equal(reset.store.cachedHomeScrollOffset,0);
 const changed=fixture();await ready(changed);changed.setSession({...changed.session(),accountId:'other',generation:2});const replacement=changed.controller.demand();assert.equal(changed.store.home,undefined,'account change clears previous presentation');changed.jobs[2].resolve(pins([8],''));changed.jobs[3].resolve(categories);await replacement;
 const failed=fixture();const first=failed.controller.demand();failed.jobs[0].resolve(pins([1],''));failed.jobs[1].resolve('bad');await first;await flush();assert(failed.store.homeSourceWarning);assert.equal(failed.store.home.pins.length,1);
 const retry=failed.controller.refresh();failed.jobs[2].resolve(pins([2],''));failed.jobs[3].resolve(categories);await retry;await flush();assert.equal(failed.store.homeSourceWarning,'');
 const apiSource=fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets','utf8');const script=Function('return `'+apiSource.match(/= `([\s\S]*?)`;/)[1]+'`')();
 const window={PinmonyNativeHomeReadsEnabled:true};window.top=window;
 vm.runInNewContext(script,{window,location:{hostname:'www.pinterest.com'},fetch(){throw Error('duplicate Web read')}});assert.equal(window.PinmonyHomeApi,undefined);
 const bridgeSource=fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeScript.ets','utf8');
 const bridgeScript=Function('return `'+bridgeSource.match(/= `([\s\S]*?)`;/)[1]+'`')();
 const messages=[]; let webReady=false;
 const web={PinmonyNativeHomeReadsEnabled:true,PinmonyNetwork:{isReady:()=>webReady,documentEpoch:()=>5},PinmonyShareBridge:{homeState:value=>messages.push(JSON.parse(value))},addEventListener(){}};web.top=web;
 vm.runInNewContext(bridgeScript,{window:web,location:{hostname:'www.pinterest.com',pathname:'/',origin:'https://www.pinterest.com'},document:{readyState:'complete'}});
 assert.equal(messages.length,0);webReady=true;web.PinmonyHomeDemand();assert.equal(messages[0].kind,'context');
 const runtime=require('./home-controller-harness.cjs').createHomeRuntime(ts);let reads=0;
 const legacy=runtime.harness({documentEpoch:()=>5,nativeReads:()=>true,nativeRefresh:async()=>reads++,nativeMore:async()=>reads++,nativeSelect:async()=>reads++,nativeDemand:async()=>reads++});
 legacy.controller.refreshHome();await legacy.controller.loadMoreHome();await legacy.controller.selectHomeTab('tab:7');legacy.controller.expectHome();assert.equal(reads,4);assert.equal(legacy.events.length,0,'native home actions never call Web/context gates');
 legacy.store.home={kind:'state',session:0,pageKey:'https://www.pinterest.com/',pins:[],tabs:[]};legacy.store.homeNativeReadsReady=true;
 legacy.controller.updateHome(JSON.stringify({kind:'state',session:99,pageKey:'https://www.pinterest.com/',pins:[{id:'stale'}],tabs:[]}));
 assert.equal(legacy.store.home.pins.length,0,'legacy Web data cannot overwrite native home');assert.equal(legacy.store.homeActionsReady,false);
 legacy.controller.updateHome(JSON.stringify({...messages[0],contextEpoch:4}));assert.equal(legacy.store.homeActionsReady,false,'stale document acknowledgement cannot grant actions');
 legacy.controller.updateHome(JSON.stringify(messages[0]));assert.equal(legacy.store.homeActionsReady,true,'operations still require ready current Web document acknowledgement');
 console.log('Native home: account ownership, first feed before categories, cursor/dedupe, empty/error/retry, category cache, board race, cancellation and Web suppression passed');
}
main().catch(error=>{console.error(error);process.exitCode=1});
