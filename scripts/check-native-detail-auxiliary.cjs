const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require: require('./local-message-test-fixture.cjs').withLocalMessages(deps),setTimeout,clearTimeout,console});return exports;}
const Aux=load('entry/src/main/ets/app/PinmonyDetailNativeAuxiliary.ets',n=>n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='feature_pin'?{PIN_VIDEO_API_ENABLED:true,PIN_CAROUSEL_API_ENABLED:true,PIN_VISUAL_SEARCH_API_ENABLED:true}:{}).PinmonyDetailNativeAuxiliary;
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',pin=origin+'/pin/11/',flush=()=>new Promise(setImmediate),crop={x:.1,y:.1,w:.8,h:.8};
const art=(url='https://i.pinimg.com/original.jpg')=>({url,width:736,height:1000});
const raw={id:'11',type:'pin',images:{orig:art()},title:'title'};
const response=data=>JSON.stringify({resource_response:{status:'success',code:0,data}});
const video={id:'11',videos:{video_list:{V_HLSV4:{...art('https://v.pinimg.com/videos/current.m3u8'),duration:3000},V_720P:art('https://v.pinimg.com/videos/current.mp4')}}};
const graph=()=>JSON.stringify({data:{v3GetPinQueryv2:{data:{entityId:'11',videos:{videoList:{v720P:art('https://v.pinimg.com/videos/fromgraph.mp4')}}}}}});
const visual=(ids,bookmark='next')=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_unified_flashlight_handler',bookmark,data:{results:ids.map(id=>({id:String(id),type:'pin',images:{'736x':art()},title:'Found'}))}}});
const captures=[];
function fixture(data=raw){
 let session={authenticated:true,generation:1,accountId:'synthetic',origin,userAgent:'synthetic',appVersion:'synthetic'},owned=true;
 const requests=[],cancelled=[],store={detailPin:pin,detailOpeningToken:1,detail:{pinUrl:pin,title:'body',related:[{id:'retained'}],actions:[{id:'save'}]},visualToken:0,visualResult:{pin:'',loading:false,error:'',items:[],ended:false},detailMediaRetryBusy:false,imageLayer:''};
 const aux=new Aux({store:()=>store,session:()=>session,owned:()=>owned,network:()=>({cancel:id=>cancelled.push(id),requestBusinessDetailAuxiliary(job,...args){assert(args.at(-1)());return new Promise(resolve=>{const entry={job,args,session:()=>session,resolve:(body,status=200,error='')=>resolve({body,status,error})};requests.push(entry);captures.push(entry);});}})});
 aux.start(pin,1,response(data));
 return {aux,store,requests,cancelled,session:()=>session,setSession:s=>session=s,setOwned:v=>owned=v};
}
async function main(){
 const mixedSlots=Array.from({length:15},(_,i)=>({id:'slot-'+i,images:{'736x':art()},
   videos:i<5?video.videos:null}));
 const mixedCarousel=fixture({...raw,is_video:false,videos:null,carousel_data:{carousel_slots:mixedSlots}});
 assert.equal(mixedCarousel.store.detail.carousel.items.length,15);
 assert.equal(mixedCarousel.store.detail.carousel.items.filter(item=>item.video).length,5);
 assert.deepEqual(Array.from(mixedCarousel.store.detail.carousel.items,item=>item.id),mixedSlots.map(item=>item.id));
 assert.equal(mixedCarousel.store.detail.carousel.items[0].video.sources.find(s=>s.kind==='mp4').url,video.videos.video_list.V_720P.url);
 assert.equal(mixedCarousel.requests.length,0,'mixed carousel is complete in the validated PinResource response');
 const carouselView=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets','utf8');
 assert(carouselView.includes('item.video && index === this.page'),'only the current video item mounts a player');
 assert(carouselView.includes("mediaOwner: this.mediaOwner + ':' + item.id"),'each slot owns a distinct player session');
 const returned=fixture();
 returned.store.detail.dataSource='api';returned.store.detail.imageUrl=raw.images.orig.url;
 const parent=JSON.parse(JSON.stringify(returned.store.detail));
 returned.aux.pause();returned.store.detailOpeningToken=3;returned.store.detail=parent;
 assert(!returned.aux.ready(),'departed viewer context is invalidated');
 assert(returned.aux.resume(pin,3),'matching native parent reads rebind the image viewer');
 await returned.aux.openLayer('zoom');assert.equal(returned.store.imageLayer,'zoom');
 assert.equal(returned.aux.downloadUrl(),raw.images.orig.url);assert.equal(returned.requests.length,0,'photo viewing after return does not reload content');
 await returned.aux.openLayer('search');assert.equal(returned.store.imageLayer,'search');
 returned.setOwned(false);assert(!returned.aux.resume(pin,3),'unconfirmed or old-account parent cannot resume viewer');
 returned.setOwned(true);assert(!returned.aux.resume(pin,2),'old opening token cannot resume viewer');
 returned.store.detail.pinUrl=origin+'/pin/12/';assert(!returned.aux.resume(pin,3),'different Pin cannot resume viewer');
 const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 assert(indexSource.includes('this.detailNativeAuxiliary.resume(pinUrl, token)'), 'native back restores both reads and viewer context');
 const f=fixture();assert(f.aux.ready());await f.aux.openLayer('zoom');assert.equal(f.aux.downloadUrl(),raw.images.orig.url);assert.equal(f.requests.length,0);
 await f.aux.openLayer('search');let p=f.aux.search(crop,false,true);assert.equal(f.requests.length,1);
 let options=JSON.parse(new URL(f.requests[0].job.url).searchParams.get('data')).options;
 assert.deepEqual(options,{pin_id:'11',crop,crop_source:5,is_shopping:false,entry_source:'flashlight',entrypoint:'closeup_cta'});
 const loadingResult=f.store.visualResult;f.requests[0].resolve(visual([2,2,3]));await p;assert.notEqual(f.store.visualResult,loadingResult,'completed search publishes a new observable root object');assert.equal(f.store.visualResult.items.length,2);assert.equal(f.store.visualResult.loading,false);
 p=f.aux.search(crop,true,false);await f.aux.search(crop,true,false);assert.equal(f.requests.length,2);assert.equal(JSON.parse(new URL(f.requests[1].job.url).searchParams.get('data')).options.bookmarks[0],'next');
 f.requests[1].resolve(visual([3,4],'next'));await p;assert.equal(f.store.visualResult.items.length,3);assert(f.store.visualResult.ended);await f.aux.search(crop,true,false);assert.equal(f.requests.length,2);
 p=f.aux.search(crop,false,false);f.requests[2].resolve('bad');await p;assert(f.store.visualResult.error);
 p=f.aux.search(crop,false,false);const old=f.requests[3];const newer=f.aux.search({...crop,x:0},false,false);assert(f.cancelled.includes(old.job.id));old.resolve(visual([99]));await p;assert(!f.store.visualResult.items.some(x=>x.id==='api:99'));
 f.requests[4].resolve(visual([5],'-end-'));await newer;assert.equal(f.store.visualResult.items[0].id,'api:5');
 for(const c of [{...crop,w:.01},{...crop,x:2},{...crop,y:NaN},{...crop,h:Infinity}])await f.aux.search(c,false,false);assert.equal(f.requests.length,5);
 const failPage=fixture();await failPage.aux.openLayer('search');p=failPage.aux.search(crop,false,true);failPage.requests[0].resolve(visual([8]));await p;
 p=failPage.aux.search(crop,true,false);failPage.requests[1].resolve('bad');await p;assert.equal(failPage.store.visualResult.items.length,1);assert(failPage.store.visualResult.error);
 for(const change of ['pin','account','token','close','pause']){
  const g=fixture();await g.aux.openLayer('search');const pending=g.aux.search(crop,false,true),r=g.requests[0];
  if(change==='pin'){g.setOwned(false);g.store.detailPin=origin+'/pin/12/';}
  if(change==='account')g.setSession({...g.session(),generation:2});
  if(change==='token')g.store.detailOpeningToken++;
  if(change==='close'){g.aux.cancelVisual();g.store.imageLayer='';}
  if(change==='pause')g.aux.pause();
  r.resolve(visual([99]));await pending;assert(!g.store.visualResult.items.some(x=>x.id==='api:99'));if(change==='pause'||change==='close')assert(g.cancelled.length);
 }
 const direct=fixture({...raw,...video});assert.equal(direct.requests.length,0);assert.equal(direct.store.detail.video.sources.length,2);assert.equal(direct.store.detail.mediaLoading,false);
 const retained=JSON.stringify(direct.store.detail.related);p=direct.aux.retryMedia();await direct.aux.retryMedia();assert.equal(direct.requests.length,1);
 direct.requests[0].resolve(response({...raw,...video}));await p;assert.equal(direct.store.detail.video.readRevision,1);assert.equal(JSON.stringify(direct.store.detail.related),retained);assert.equal(direct.store.detail.title,'body');
 const before=direct.store.detail.video.sources[0].url;p=direct.aux.retryMedia();direct.requests[1].resolve(response({id:'different'}));await p;assert.equal(direct.store.detail.video.sources[0].url,before);assert(direct.store.detail.videoError);assert(!direct.store.detailMediaRetryBusy);
 const missing=fixture({...raw,is_video:true});assert.equal(missing.requests.length,1);assert(missing.store.detail.mediaLoading);missing.requests[0].resolve(graph());await flush();assert.equal(missing.store.detail.video.sources[0].kind,'mp4');
 p=missing.aux.retryMedia();missing.requests[1].resolve(response({...raw,is_video:true}));await flush();assert.equal(missing.requests.length,3);missing.requests[2].resolve(graph());await p;assert.equal(missing.store.detail.video.readRevision,1);
 const wrong=fixture({...raw,is_video:true});wrong.requests[0].resolve(graph().replace('"11"','"99"'));await flush();assert(!wrong.store.detail.video);assert(wrong.store.detail.videoError);
 const carousel=fixture({...raw,carousel_data:{carousel_slots:[{id:'1',images:{'736x':art()}},{id:'2',images:{orig:art()}}]}});assert.equal(carousel.store.detail.carousel.items.length,2);assert.equal(carousel.requests.length,0);
 const badMedia=fixture({...raw,is_video:true,videos:{video_list:{V_720P:art('https://v.pinimg.com@evil.invalid/videos/current.mp4')}}});assert.equal(badMedia.requests.length,1);badMedia.requests[0].resolve(graph());await flush();assert(!badMedia.store.detail.video.sources[0].url.includes('evil'));
 const staleMedia=fixture({...raw,is_video:true});const r=staleMedia.requests[0];staleMedia.aux.pause();r.resolve(graph());await flush();assert(!staleMedia.store.detail.video);assert(staleMedia.cancelled.length);
 const mixed=fixture();await mixed.aux.openLayer('search');p=mixed.aux.search(crop,false,true);mixed.requests[0].resolve(JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_unified_flashlight_handler',data:{results:[{id:'20',type:'story',images:{orig:art()}},{id:'21',type:'pin',images:{orig:art('https://evil.invalid/x')}}]}}}));await p;assert.equal(mixed.store.visualResult.items.length,0);assert(mixed.store.visualResult.ended);

 const graphCarousel=fixture({...raw,carousel_data:{carousel_slots:[{id:'1'}]}});
 assert.equal(graphCarousel.requests.length,1);
 graphCarousel.requests[0].resolve(JSON.stringify({data:{v3GetPinQueryv2:{data:{entityId:'11',carouselData:{carouselSlots:[{slotId:'1',images_736x:art()},{slotId:'2',images_orig:art()}]}}}}}));
 await flush();assert.equal(graphCarousel.store.detail.carousel.items.length,2);
 direct.store.detail.video=undefined;direct.store.detail.title='retained body';direct.aux.apply();assert(direct.store.detail.video);assert.equal(direct.store.detail.title,'retained body');

 const changedCrop=fixture();await changedCrop.aux.openLayer('search');
 let changeRead=changedCrop.aux.search(crop,false,true);changedCrop.requests[0].resolve(visual([7]));await changeRead;
 changeRead=changedCrop.aux.search({...crop,x:0},false,false);changedCrop.requests[1].resolve('bad');await changeRead;
 await changedCrop.aux.search({...crop,x:0},true,false);assert.equal(changedCrop.requests.length,2,'failed new crop cannot reuse an older crop cursor');
 await policy();await wiring();
 console.log('Native detail auxiliary passed: crop/paging/cancel/stale isolation, video/carousel parsing, GraphQL/fresh media, same-URL revision, preserved content, strict policy and zero Web business execution.');
}
async function policy(){
 const network=new Network();let sent=0,context;
 network.request=async(job,ctx)=>{context=ctx;const c=ctx();if(!c.authenticated)return {error:'reject'};assert(acceptsNetworkJob(job,c));sent++;return {error:''};};
 for(const r of captures){
  const session=r.args[0],s=session();const send=job=>network.requestBusinessDetailAuxiliary(job,session,pin,()=>true);
  const valid=await send(r.job);if(s.generation!==r.job.epoch)continue;assert.equal(valid.error,'');
  const before=sent;for(const j of [{...r.job,page:origin+'/pin/99/'},{...r.job,epoch:99},{...r.job,id:'unknown'},{...r.job,headers:{...r.job.headers,'X-Pinterest-Pws-Handler':'bad'}},{...r.job,url:r.job.url.replace('pinterest.com','evil.invalid')}]){
   assert.equal((await send(j)).error,'reject');
  }
  if(r.job.method==='GET'){
   const url=new URL(r.job.url),body=JSON.parse(url.searchParams.get('data'));body.options.unexpected=true;url.searchParams.set('data',JSON.stringify(body));assert.equal((await send({...r.job,url:url.toString()})).error,'reject');
  }else {
   const q=JSON.parse(r.job.body);q.variables.isAuth=false;assert.equal((await send({...r.job,body:JSON.stringify(q)})).error,'reject');
  }
  assert.equal(sent,before);
 }
 const r=captures.find(x=>x.job.id.startsWith('native_detail_aux_visual_')),session={...r.session(),origin:'https://uk.pinterest.com',generation:r.job.epoch};
 const job={...r.job,url:r.job.url.replace(origin,session.origin),page:pin.replace(origin,session.origin)};
 assert.equal((await network.requestBusinessDetailAuxiliary(job,()=>session,job.page,()=>true)).error,'');
}
async function wiring(){
 const Ops=load('feature_pin/src/main/ets/controllers/PinmonyDetailOperationsController.ets',()=>({PinmonyTaskRegistry:class{invalidate(){}}})).PinmonyDetailOperationsController;
 const calls=[],controller=new Ops({visualToken:0,visualResult:{loading:false}},{
 nativeOpenLayer:async l=>calls.push(l),nativeSearch:async()=>calls.push('search'),nativeRetryMedia:async()=>calls.push('retry'),nativePause:()=>calls.push('pause'),nativeCancelVisual:()=>calls.push('cancel'),
 document(){throw Error('Web document')},runScript(){throw Error('Web script')},ensureDetailActionContext(){throw Error('Web prepare')}});
 await controller.openImageLayer('zoom');await controller.searchImage(crop,false,true);await controller.retryDetailMedia();controller.pause();assert.deepEqual(calls,['zoom','search','retry','pause','cancel']);
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');function method(name){const start=index.search(new RegExp('  private (?:async )?'+name+'\\('));assert(start>=0);return index.slice(start,index.indexOf('\n  private ',start+1));}
 const Host=vm.runInNewContext(ts.transpileModule('class Host {'+['openImageRelated','downloadViewerImage','closeImageLayer'].map(method).join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_DETAIL_AUXILIARY_ENABLED:true});
 const host=new Host(),routes=[],downloads=[];
 Object.assign(host,{pinStore:{detailPin:pin,detail:{pinUrl:pin},imageLayer:'',visualResult:{pin,items:[{id:'api:8',pinUrl:origin+'/pin/8/'}]},visualToken:0},detailNativeAuxiliary:{ready:()=>true,downloadUrl:()=>raw.images.orig.url},beginDetailOpening:(...args)=>routes.push(args),
 systemActions:{downloadImage:async u=>downloads.push(u)},controller:{startDownload(){throw Error('legacy Web download')},runJavaScript(){throw Error('Web script')},loadUrl(){throw Error('Web navigation')}},detailOperationsController:{cancelVisual(){}},rejectOfflineAction:()=>false,showMessage(){}});
 await host.openImageRelated('api:8');assert.equal(routes[0][0],origin+'/pin/8/');await host.downloadViewerImage();assert.deepEqual(downloads,[raw.images.orig.url]);host.closeImageLayer();
 const VisualScript=load('feature_pin/src/main/ets/services/PinmonyVisualSearchApiScript.ets').PIN_VISUAL_SEARCH_API_SCRIPT;
 const window={PinmonyNativeDetailAuxiliaryEnabled:true};window.top=window;vm.runInNewContext(VisualScript,{window,location:{origin,href:pin,pathname:'/pin/11/'}});assert.equal(window.PinmonyVisualSearchApi.start(pin,crop,false,true),false);
 const {mapPrefetchedDetail}=load('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets',()=>({PinmonyRuntimeLog:{info(){}}}));
 const base=response({...raw,is_video:true});assert.equal(mapPrefetchedDetail(base,pin),undefined);assert(mapPrefetchedDetail(base,pin,true),'demand reads can present a supported media Pin before GraphQL completes');
}
const timeout=setTimeout(()=>{console.error('native auxiliary test timeout');process.exit(1)},25000);main().then(()=>clearTimeout(timeout)).catch(e=>{clearTimeout(timeout);console.error(e);process.exitCode=1});
