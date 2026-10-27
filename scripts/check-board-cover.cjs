const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const ts = require(process.argv[2] || 'typescript');
const {withLocalMessages} = require('./local-message-test-fixture.cjs');
const timers = new Map();let timerId = 0;
function load(file, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
    {exports,require:withLocalMessages(name => deps(name)),setTimeout:fn => {timers.set(++timerId,fn);return timerId;},clearTimeout:id => timers.delete(id),console});
  return exports;
}
const geometry = load('feature_board/src/main/ets/services/PinmonyBoardCoverGeometry.ets');
const {PinmonyBoardCoverNativeFlow:Flow} = load('entry/src/main/ets/app/PinmonyBoardCoverNativeFlow.ets',n=>n==='feature_board'?geometry:{});
const {PinmonyNativeNetwork:Network} = load('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const origin='https://www.pinterest.com',page=origin+'/synthetic/board/',image='https://i.pinimg.com/236x/synthetic.jpg';
const sourcePin=(id='11',w=236,h=513)=>({id,type:'pin',images:{'236x':{url:image,width:w,height:h}}});
const board={id:'100',type:'board',owner:{id:'42'},access:['write','delete'],image_cover_url:'https://i.pinimg.com/200x150/old.jpg'};
const body=(data,endpoint='v3_get_board',bookmark)=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data,bookmark},resource:{options:{bookmarks:[bookmark||'-end-']}},client_context:{user:{id:'42'}}});
const options=job=>JSON.parse(new URLSearchParams(job.method==='POST'?job.body:new URL(job.url).search).get('data')).options;
const flush=()=>new Promise(setImmediate);
function fixture() {
  let state={phase:'edit',loading:false,busy:false,uncertain:false,error:'',description:'Retained draft',privacy:'public',recommend:false,invites:false,requests:false,pins:[],targets:[],saved:[],hasMore:false};
  let identity={page,boardId:'100',viewerId:'42',ownerId:'42',intent:9};
  let session={origin,authenticated:true,accountId:'synthetic',generation:1,userAgent:'synthetic'};
  const requests=[],confirmed=[],cancelled=[];
  const flow=new Flow({state:()=>state,identity:()=>identity,session:()=>session,changed:f=>state=f,confirmed:u=>confirmed.push(u),
    network:()=>({cancel:id=>cancelled.push(id),requestBusinessBoardCover:(job,...args)=>new Promise(resolve=>requests.push({job,current:args.at(-1),args,resolve:(b,status=200,error='')=>resolve({body:b,status,error})}))})});
  return {flow,requests,confirmed,cancelled,state:()=>state,identity:()=>identity,session:()=>session,setSession:s=>session=s,setIdentity:i=>identity=i};
}
async function open(f,rows=[sourcePin()],cursor='next') {
  const p=f.flow.handle('coverOpen');assert.match(f.requests.at(-1).job.url,/BoardResource/);
  f.requests.at(-1).resolve(body(board));await flush();assert.match(f.requests.at(-1).job.url,/BoardFeedResource/);
  assert.equal(options(f.requests.at(-1).job).filter_section_pins,false);
  f.requests.at(-1).resolve(body(rows,'v3_board_pins',cursor));await p;
}
function savedBoard(crop,extra={}) {return {...board,image_cover_url:'https://i.pinimg.com/custom_covers/200x150/synthetic.jpg',cover_pin:{pin_id:crop.pinId,custom_cover:true,crop:[crop.cropX,crop.cropY],size:[crop.width,crop.height],scale:crop.scale,...extra}};}
async function main() {
  const pin={id:'11',imageWidth:236,imageHeight:513};
  let crop=geometry.boardCoverCrop(pin,-5,999);assert.equal(crop.cropX,0);assert.equal(crop.cropY,277);assert.equal(crop.width,236);assert.equal(crop.scale,1);
  crop=geometry.boardCoverCrop({...pin,imageWidth:474,imageHeight:236},999,20);assert.equal(crop.cropX,238);assert.equal(crop.cropY,0);
  crop=geometry.boardCoverCrop({...pin,imageWidth:118,imageHeight:236},0,9);assert.equal(crop.scale,2);assert.equal(crop.width,118);
  const hd=fixture(),hdPin=sourcePin();hdPin.images['474x']={url:'https://i.pinimg.com/474x/synthetic.jpg',width:474,height:1030};hdPin.images.orig={url:'https://i.pinimg.com/originals/wrong.jpg',width:2000,height:2000};
  await open(hd,[hdPin]);const hdResult=hd.state().cover.pins[0];assert.equal(hdResult.previewImageUrl,hdPin.images['474x'].url);assert.equal(hdResult.imageUrl,image);assert.equal(hdResult.imageWidth,236);assert.equal(hdResult.imageHeight,513);
  const positioned=geometry.boardCoverPreview(hdResult,0,100,236,236,236);assert.equal(positioned.imageUrl,hdPin.images['474x'].url);assert.equal(positioned.top,(-100*100/236)+'%');assert.equal(geometry.boardCoverPreview(hdResult,0,999,236,236),undefined);
  const f=fixture();await open(f,[sourcePin(),sourcePin(),{id:'story',type:'story'},sourcePin('12',0,2)]);
  assert.equal(f.state().coverImage,'','automatic collage is not a user-selected cover');
  assert.equal(f.state().cover.pins.length,1);assert.equal(f.state().description,'Retained draft');
  let p=f.flow.handle('coverMore');assert.deepEqual(options(f.requests.at(-1).job).bookmarks,['next']);
  const pagingCount=f.requests.length;await f.flow.handle('coverMore');assert.equal(f.requests.length,pagingCount,'scroll callbacks cannot overlap page requests');
  f.requests.at(-1).resolve(body([{type:'story'}],'v3_board_pins'));await p;assert(!f.state().cover.hasMore);
  await f.flow.handle('coverSelect','11');assert.equal(f.state().cover.selected.cropY,139);
  await f.flow.handle('coverCrop',JSON.stringify({pinId:'99',cropX:0,cropY:0}));assert.equal(f.state().cover.selected.pinId,'11');
  await f.flow.handle('coverCrop',JSON.stringify({pinId:'11',cropX:0,cropY:52}));crop=f.state().cover.selected;
  p=f.flow.handle('coverSave');const job=f.requests.at(-1).job;assert.equal(job.method,'POST');assert.equal(options(job).crop_y,52);
  const count=f.requests.length;await f.flow.handle('coverSave');await f.flow.handle('coverBack');assert.equal(f.requests.length,count);assert(f.state().busy);
  f.requests.at(-1).resolve(body({task_id:'synthetic-task'},'v3_set_board_cover'));await flush();
  assert.equal(f.confirmed.length,0,'task acceptance is not completion');
  f.requests.at(-1).resolve(body(board));await flush();assert.equal(f.confirmed.length,0,'old cover is not completion');
  const timer=[...timers.entries()][0];assert(timer);timers.delete(timer[0]);timer[1]();await flush();
  f.requests.at(-1).resolve(body(savedBoard(crop)));await p;
  assert.equal(f.confirmed.length,1);assert.equal(f.state().cover,undefined);assert.equal(f.state().description,'Retained draft');
  // Transport uncertainty and close/reopen never replay a sent write. GET can reconcile it.
  const u=fixture();await open(u);await u.flow.handle('coverSelect','11');const uncertainCrop=u.state().cover.selected;
  p=u.flow.handle('coverSave');u.requests.at(-1).resolve('',0,'transport');await p;assert(u.state().uncertain);
  await u.flow.handle('coverBack');assert(!u.state().cover);await open(u);assert.equal(u.state().cover.status,'uncertain');
  const writes=u.requests.filter(r=>r.job.method==='POST').length;await u.flow.handle('coverSave');await u.flow.handle('coverSelect','11');assert.equal(u.requests.filter(r=>r.job.method==='POST').length,writes);
  p=u.flow.handle('coverCheck');u.requests.at(-1).resolve(body(savedBoard(uncertainCrop)));await p;assert.equal(u.confirmed.length,1);
  // Cancellation and an account change discard late success, including while waiting between reads.
  const late=fixture();await open(late);await late.flow.handle('coverSelect','11');p=late.flow.handle('coverSave');late.flow.pause();assert(late.state().uncertain);assert(late.cancelled.length);
  late.requests.at(-1).resolve(body({task_id:'late'},'v3_set_board_cover'));await p;assert.equal(late.confirmed.length,0);
  const changed=fixture();await open(changed);await changed.flow.handle('coverSelect','11');p=changed.flow.handle('coverSave');changed.setSession({...changed.session(),generation:2});changed.requests.at(-1).resolve(body({task_id:'late'},'v3_set_board_cover'));await p;assert.equal(changed.confirmed.length,0);
  const denied=fixture();denied.setIdentity({...denied.identity(),ownerId:'99'});await denied.flow.handle('coverOpen');assert.equal(denied.requests.length,0);
  const bad=fixture();p=bad.flow.handle('coverOpen');bad.requests.at(-1).resolve(body({...board,id:'999'}));await p;assert(bad.state().cover.error);assert.equal(bad.requests.length,1);
  const wrong=fixture();await open(wrong);await wrong.flow.handle('coverSelect','11');p=wrong.flow.handle('coverSave');wrong.requests.at(-1).resolve(body({task_id:'wrong'},'v3_edit_board'));await p;assert(wrong.state().uncertain);assert.equal(wrong.confirmed.length,0);
  const timeout=fixture();await open(timeout);await timeout.flow.handle('coverSelect','11');p=timeout.flow.handle('coverSave');timeout.requests.at(-1).resolve(body({task_id:'timeout'},'v3_set_board_cover'));await flush();
  for(let i=0;i<11;i++){timeout.requests.at(-1).resolve(body(board));await flush();if(i<10){const [id,fn]=[...timers.entries()][0];timers.delete(id);fn();await flush();}}
  await p;assert(timeout.state().uncertain);assert.equal(timeout.requests.filter(r=>r.job.method==='POST').length,1);assert.equal(timeout.confirmed.length,0);
  p=timeout.flow.handle('coverCheck');timeout.requests.at(-1).resolve(body(board));await flush();assert(timers.size);timeout.flow.pause();await p;assert.equal(timers.size,0);assert(!timeout.state().busy);
  // Validate the actual network whitelist independently of the controller fixture.
  let active=true,session={origin,authenticated:true,accountId:'synthetic',generation:1};const contexts=[];
  const network=Object.create(Network.prototype);network.request=async (job,context)=>{contexts.push(context);return {error:context().authenticated?'':'blocked'};};
  const send=(candidate=job,overrides={})=>network.requestBusinessBoardCover(candidate,()=>session,'100','42',overrides.owner||'42',overrides.pin||'11',overrides.image||image,236,513,()=>active);
  assert.equal((await send()).error,'');assert(contexts.at(-1)().authenticated);active=false;assert(!contexts.at(-1)().authenticated);active=true;
  const mutate=(fn)=>{const c=structuredClone(job),d=options(c);fn(d);c.body='source_url='+encodeURIComponent('/synthetic/board/')+'&data='+encodeURIComponent(JSON.stringify({options:d,context:{}}));return c;};
  for(const change of [o=>o.crop_y=-1,o=>o.crop_y=278,o=>o.crop_y=NaN,o=>o.scale=2,o=>o.width=237,o=>o.pin_id='99',o=>o.extra=true,o=>o.url='https://example.com/image'])assert((await send(mutate(change))).error);
  assert((await send(job,{owner:'99'})).error);assert((await send(job,{pin:'99'})).error);
  assert((await send({...job,url:origin+'/resource/BoardResource/delete/'})).error);
  const feed=f.requests.find(r=>r.job.url.includes('BoardFeedResource')).job;assert.equal((await send(feed)).error,'');
  const badFeed={...feed,url:feed.url.replace('images_only_item','react_grid_pin')};assert((await send(badFeed)).error);
  await send();const ctx=contexts.at(-1);session={...session,generation:2};assert(!ctx().authenticated);
  // Source wiring: nested back, retained edit fields, native-only entry and resource-based copy.
  const pageSource=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');
  assert.match(pageSource,/if\(this.snapshot.flow\?\.cover\)\{this.act\('coverBack'\)/);
  assert.match(pageSource,/snapshot.nativeReadsReady === true/);
  assert.match(pageSource,/if \(!this.snapshot.flow\?\.cover && !this.organizeLoading\(\)/,'outer spinner must not duplicate cover status');
  assert.match(pageSource,/pm_board_cover_placeholder/);
  assert.match(pageSource,/if \(this.snapshot.flow\?\.cover\) \{[\s\S]*?this.act\('coverMore'\)/);
  const component=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardCoverContent.ets','utf8');
  assert(!component.includes('pm_board_cover_more'),'no load-more button');
  assert(!component.includes('pm_board_cover_empty'),'empty candidate content remains hidden');
  assert.match(component,/if\(this.cover.pins.length > 0\)/);
  assert.match(component,/onVisibleAreaChange\(\[0,1\]/,'visible page boundary loads automatically');
  await integration();
  console.log('Board cover passed: geometry, filtering/pagination, independent save, readback confirmation, uncertainty/reopen lock, cancellation/account guards, exact network whitelist and nested UI back.');
}
async function integration() {
  function native(file){return load(file,n=>n.startsWith('./')?native(path.resolve(path.dirname(file),n)+'.ets'):n==='feature_board'?geometry:n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){}},isProductPin:()=>false}:{});}
  const Reader=native('entry/src/main/ets/app/PinmonyBoardNativeReads.ets').PinmonyBoardNativeReads;
  const requests=[],store={boardDetail:{pageKey:page,pins:[]},collaboratorsToken:0};let active=true,invalidations=0;
  const session={origin,authenticated:true,accountId:'synthetic',generation:1,userAgent:'synthetic'};
  const send=(job,...args)=>new Promise(resolve=>requests.push({job,current:args.at(-1),resolve:b=>resolve({body:b,status:200,error:''})}));
  const reader=new Reader({store:()=>store,session:()=>session,active:()=>active,network:()=>({cancel(){},requestBusinessBoardRead:send,requestBusinessBoardAuxRead:send,requestBusinessBoardCover:send}),
    install(){},bridge(){},committed(){},openPin(){},invalidateProfile(){invalidations++;},document(){throw Error('Unexpected Web context read');},documentEpoch(){throw Error('Unexpected Web epoch read');}});
  const b={...board,url:'/synthetic/board/',name:'Board',privacy:'public',pin_count:1,section_count:0,owner:{id:'42',username:'synthetic'}};
  let p=reader.demand();requests.at(-1).resolve(body(b));await flush();requests.at(-1).resolve(body([sourcePin()],'v3_board_pins'));await p;
  const action=(a,value='')=>reader.handle('flow',JSON.stringify({action:a,value}));
  p=action('edit');requests.at(-1).resolve(body({...b,description:'Existing description'}));await p;
  assert.equal(store.boardDetail.flow.coverImage,'','edit read must not display an automatic board preview as a selected cover');
  p=action('coverOpen');requests.at(-1).resolve(body(b));await flush();requests.at(-1).resolve(body([sourcePin()],'v3_board_pins'));await p;
  assert(store.boardDetail.flow.cover);assert.equal(store.boardDetail.flow.description,'Existing description');
  await action('close');assert.equal(store.boardDetail.flow.phase,'edit');assert(!store.boardDetail.flow.cover);
  p=action('coverOpen');requests.at(-1).resolve(body(b));await flush();requests.at(-1).resolve(body([sourcePin()],'v3_board_pins'));await p;
  await action('coverSelect','11');const crop=store.boardDetail.flow.cover.selected;p=action('coverSave');assert(requests.at(-1).current());requests.at(-1).resolve(body({task_id:'integration'},'v3_set_board_cover'));await flush();requests.at(-1).resolve(body({...savedBoard(crop),owner:b.owner}));await p;
  assert.equal(invalidations,1);assert.equal(store.boardDetail.flow.phase,'edit');assert(!store.boardDetail.flow.cover);assert.equal(store.boardDetail.flow.description,'Existing description');reader.pause();
}
main().catch(e=>{console.error(e);process.exitCode=1;});
