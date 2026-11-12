const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const ts = require(process.argv[2] || 'typescript');
const {withLocalMessages} = require('./local-message-test-fixture.cjs');
const timers = new Map();let timerId = 0;
function load(file, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
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
  const refreshed=fixture();await open(refreshed,[sourcePin()],'same-cursor');
  await refreshed.flow.handle('coverSelect','11');
  const selectedCrop=JSON.stringify(refreshed.state().cover.selected);
  let refreshing=refreshed.flow.handle('coverRefresh');
  assert(refreshed.state().cover.refreshing);assert(refreshed.state().cover.loading);
  assert.equal(refreshed.state().cover.pins.length,1,'retain visible candidates during refresh');
  const refreshCount=refreshed.requests.length;await refreshed.flow.handle('coverRefresh');await refreshed.flow.handle('coverMore');
  assert.equal(refreshed.requests.length,refreshCount,'refresh and pagination cannot overlap');
  refreshed.requests.at(-1).resolve(body(board));await flush();
  assert.equal(options(refreshed.requests.at(-1).job).bookmarks,undefined,'refresh restarts from the first page');
  refreshed.requests.at(-1).resolve(body([sourcePin(),sourcePin('12')],'v3_board_pins','same-cursor'));await refreshing;
  assert(!refreshed.state().cover.refreshing);assert(!refreshed.state().cover.loading);
  assert(refreshed.state().cover.hasMore,'reused cursor is valid after refreshing');
  assert.equal(JSON.stringify(refreshed.state().cover.selected),selectedCrop,'keep a still-present selected crop');
  refreshing=refreshed.flow.handle('coverRefresh');refreshed.requests.at(-1).resolve('',500);await refreshing;
  assert(refreshed.state().cover.error);assert(!refreshed.state().cover.refreshing);
  assert.equal(refreshed.state().cover.pins.length,2,'refresh failure retains existing images');
  refreshing=refreshed.flow.handle('coverRefresh');refreshed.requests.at(-1).resolve(body(board));await flush();
  refreshed.requests.at(-1).resolve(body([],'v3_board_pins','-end-'));await refreshing;
  assert.equal(refreshed.state().cover.pins.length,0);assert(!refreshed.state().cover.selected,'empty refresh clears unavailable selection');
  refreshing=refreshed.flow.handle('coverRefresh');const lateRefresh=refreshed.requests.at(-1);refreshed.flow.pause();
  assert(!refreshed.state().cover.refreshing);lateRefresh.resolve(body(board));await refreshing;
  assert.equal(refreshed.state().cover.pins.length,0,'cancelled refresh cannot repopulate stale results');
  assert.equal(refreshed.requests.filter(r=>r.job.method==='POST').length,0,'refresh never writes the cover');
  const refreshGuard=fixture();await open(refreshGuard);refreshGuard.state().cover.adjusting=true;
  let guardedCount=refreshGuard.requests.length;await refreshGuard.flow.handle('coverRefresh');assert.equal(refreshGuard.requests.length,guardedCount,'adjust-only mode cannot refresh candidates');
  refreshGuard.state().cover.adjusting=false;refreshGuard.state().uncertain=true;
  await refreshGuard.flow.handle('coverRefresh');assert.equal(refreshGuard.requests.length,guardedCount,'uncertain writes block candidate refresh');
  refreshGuard.state().uncertain=false;refreshGuard.setIdentity({...refreshGuard.identity(),ownerId:'another-owner'});
  await refreshGuard.flow.handle('coverRefresh');assert.equal(refreshGuard.requests.length,guardedCount,'non-owners cannot refresh');
  const refreshAccount=fixture();await open(refreshAccount);refreshing=refreshAccount.flow.handle('coverRefresh');
  const oldAccountRead=refreshAccount.requests.at(-1);guardedCount=refreshAccount.requests.length;
  refreshAccount.setSession({...refreshAccount.session(),accountId:'new-account',generation:2});
  oldAccountRead.resolve(body(board));await refreshing;
  assert.equal(refreshAccount.requests.length,guardedCount,'account change discards refresh before the next request');
  const pin={id:'11',imageWidth:236,imageHeight:513};
  let crop=geometry.boardCoverCrop(pin,-5,999);assert.equal(crop.cropX,0);assert.equal(crop.cropY,277);assert.equal(crop.width,236);assert.equal(crop.scale,1);
  crop=geometry.boardCoverCrop({...pin,imageWidth:474,imageHeight:236},999,20);assert.equal(crop.cropX,238);assert.equal(crop.cropY,0);
  crop=geometry.boardCoverCrop({...pin,imageWidth:118,imageHeight:236},0,9);assert.equal(crop.scale,2);assert.equal(crop.width,118);
  const hd=fixture(),hdPin=sourcePin();hdPin.images['474x']={url:'https://i.pinimg.com/474x/synthetic.jpg',width:474,height:1030};hdPin.images.orig={url:'https://i.pinimg.com/originals/wrong.jpg',width:2000,height:2000};
  await open(hd,[hdPin]);const hdResult=hd.state().cover.pins[0];assert.equal(hdResult.previewImageUrl,hdPin.images['474x'].url);assert.equal(hdResult.imageUrl,image);assert.equal(hdResult.imageWidth,236);assert.equal(hdResult.imageHeight,513);
  const positioned=geometry.boardCoverPreview(hdResult,0,100,236,236,236);assert.equal(positioned.imageUrl,hdPin.images['474x'].url);assert(Math.abs(parseFloat(positioned.top)-100*((1-5/3)/2-100*(5/3)/236))<1e-8);assert.equal(geometry.boardCoverPreview(hdResult,0,999,236,236),undefined);
  for(const source of [{imageWidth:236,imageHeight:513},{imageWidth:513,imageHeight:236},{imageWidth:236,imageHeight:236}])for(const aspect of [5/3,1,3/5]) {
    const side=Math.min(source.imageWidth,source.imageHeight),x=(source.imageWidth-side)/2,y=(source.imageHeight-side)/2;
    const rect=geometry.boardCoverPreview({...source,imageUrl:image},x,y,side,side,source.imageWidth,aspect);
    const shownWidth=parseFloat(rect.width)/100*aspect,shownHeight=parseFloat(rect.height)/100;
    assert(Math.abs(shownWidth/shownHeight-source.imageWidth/source.imageHeight)<1e-8,'displayed source retains its aspect ratio');
    const centerX=parseFloat(rect.left)/100*aspect+(x+side/2)*shownWidth/source.imageWidth;
    const centerY=parseFloat(rect.top)/100+(y+side/2)*shownHeight/source.imageHeight;
    assert(Math.abs(centerX-aspect/2)<1e-8 && Math.abs(centerY-.5)<1e-8,'saved crop center remains at the frame center');
  }
  assert.equal(geometry.boardCoverPreview(hdResult,0,100,236,236,236,0),undefined);
  const adjust=fixture(),existing={pinId:'11',cropX:0,cropY:100,width:236,height:236,scale:1};
  let adjustment=adjust.flow.handle('coverAdjust');adjust.requests.at(-1).resolve(body(savedBoard(existing)));await flush();
  adjust.requests.at(-1).resolve(body([sourcePin('12')],'v3_board_pins','more-adjust'));await flush();
  assert.equal(adjust.state().cover.loading,true,'saved-cover lookup remains loading between feed pages');
  assert.match(adjust.requests.at(-1).job.url,/BoardFeedResource/);assert.deepEqual(options(adjust.requests.at(-1).job).bookmarks,['more-adjust']);
  adjust.requests.at(-1).resolve(body([sourcePin()],'v3_board_pins','-end-'));await adjustment;
  assert.equal(adjust.state().cover.loading,false,'lookup finishes loading after the saved source is found');
  assert(adjust.state().cover.adjusting);assert.equal(JSON.stringify(adjust.state().cover.selected),JSON.stringify(existing),'adjust opens the saved image at its confirmed position');
  await adjust.flow.handle('coverSelect','12');assert.equal(adjust.state().cover.selected.pinId,'11','adjusting cannot replace the saved image');
  assert.equal(adjust.requests.filter(r=>r.job.method==='POST').length,0,'opening adjustment never writes');
  for(const y of [0,185,371]) {
    const wide=fixture(),saved=geometry.boardCoverCrop({...pin,id:'11'},0,y,5/3);
    const reopened=wide.flow.handle('coverAdjust');wide.requests.at(-1).resolve(body(savedBoard(saved)));await flush();
    wide.requests.at(-1).resolve(body([sourcePin()],'v3_board_pins','-end-'));await reopened;
    assert.equal(JSON.stringify(wide.state().cover.selected),JSON.stringify(saved),'wide top/middle/bottom crop restores without changing position');
    assert.equal(wide.requests.filter(r=>r.job.method==='POST').length,0,'restoring a wide crop remains read-only');
  }
  await adjust.flow.handle('coverBack');adjustment=adjust.flow.handle('coverOpen');adjust.requests.at(-1).resolve(body(savedBoard(existing)));await flush();adjust.requests.at(-1).resolve(body([sourcePin()],'v3_board_pins','-end-'));await adjustment;
  assert(!adjust.state().cover.adjusting);assert(!adjust.state().cover.selected,'change-image entry opens the picker without restoring an image');
  const missing=fixture();adjustment=missing.flow.handle('coverAdjust');missing.requests.at(-1).resolve(body(savedBoard(existing)));await flush();missing.requests.at(-1).resolve(body([sourcePin('12')],'v3_board_pins','-end-'));await adjustment;assert(missing.state().cover.error);assert(!missing.state().cover.selected,'missing saved source cannot silently select another Pin');
  const f=fixture();await open(f,[sourcePin(),sourcePin(),{id:'story',type:'story'},sourcePin('12',0,2)]);
  assert.equal(f.state().coverImage,'','automatic collage is not a user-selected cover');
  assert.equal(f.state().cover.pins.length,1);assert.equal(f.state().description,'Retained draft');
  let p=f.flow.handle('coverMore');assert.deepEqual(options(f.requests.at(-1).job).bookmarks,['next']);
  const pagingCount=f.requests.length;await f.flow.handle('coverMore');assert.equal(f.requests.length,pagingCount,'scroll callbacks cannot overlap page requests');
  f.requests.at(-1).resolve(body([{type:'story'}],'v3_board_pins'));await p;assert(!f.state().cover.hasMore);
  await f.flow.handle('coverSelect','11');assert.equal(f.state().cover.selected.cropY,186);assert.equal(f.state().cover.selected.height,142);
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
  for(const change of [o=>o.crop_y=-1,o=>o.crop_y=372,o=>o.crop_y=NaN,o=>o.scale=2,o=>o.width=237,o=>o.height=143,o=>o.pin_id='99',o=>o.extra=true,o=>o.url='https://example.com/image'])assert((await send(mutate(change))).error);
  assert.equal((await send(mutate(o=>o.crop_y=371))).error,'','wide crop reaches the bottom source edge');
  assert.equal((await send(mutate(o=>{o.height=236;o.crop_y=277;}))).error,'','legacy square crop remains accepted');
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
  assert.match(component,/\.width\('100%'\)\.aspectRatio\(5\/3\)\.clip\(true\)/,'picker uses the same 5:3 viewport as the edit cover');
  assert.match(component,/y:this\.previewTop\(source\)/,'picker applies source-specific crop placement during preview handoff');
  const previewAst=ts.createSourceFile('preview.ts',component.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);
  const previewMethodNames=['displayScale','displayLeft','displayTop','previewScale','previewLeft','previewTop','beginDrag','move','sourceKey','canDrag','previewComplete','syncCrop','finishDrag','cancelDrag','aboutToDisappear','previewPins','resizePreview'];
  const previewMethods=[];
  function collectPreview(node) {
    if(ts.isMethodDeclaration(node) && previewMethodNames.includes(node.name.getText(previewAst)))previewMethods.push(node.getText(previewAst));
    ts.forEachChild(node,collectPreview);
  }
  collectPreview(previewAst);assert.equal(previewMethods.length,previewMethodNames.length);
  const Preview=vm.runInNewContext(ts.transpileModule('class Preview {'+previewMethods.join('\n')+'} Preview;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{boardCoverCrop:geometry.boardCoverCrop});
  const stalePreview=new Preview();let activePin={id:'11',imageUrl:image,imageWidth:236,imageHeight:513};
  Object.assign(stalePreview,{frameSide:360,cropLeft:0,cropTop:0,cropWidth:236,cropHeight:142,locked:false,loaded:true,dragging:false,
    cover:{status:''},previewActive:true,previewRevision:0,onReady(){},selected:()=>activePin});
  stalePreview.previewId=stalePreview.sourceKey(activePin);
  const staleCommits=[];stalePreview.onAction=(action,value)=>staleCommits.push(JSON.parse(value));
  stalePreview.beginDrag();assert(stalePreview.dragging);activePin={...activePin,id:'12'};stalePreview.move(0,20,true);
  assert.equal(staleCommits.length,0,'an old gesture cannot submit crop coordinates to a newly selected Pin');
  for(const source of [{imageWidth:236,imageHeight:513},{imageWidth:513,imageHeight:236},{imageWidth:236,imageHeight:236}]) {
    for(const aspect of [1,5/3])for(const progress of [0,.5,1])for(const frameWidth of [236,360,600]) {
      const crop=geometry.boardCoverCrop(source,source.imageWidth*progress,source.imageHeight*progress,aspect);
      const x=crop.cropX,y=crop.cropY;
      const preview=new Preview();preview.frameSide=frameWidth;preview.cropLeft=x;preview.cropTop=y;preview.cropWidth=crop.width;preview.cropHeight=crop.height;preview.selected=()=>source;
      const rect=geometry.boardCoverPreview({...source,imageUrl:image},x,y,crop.width,crop.height,source.imageWidth);
      assert(Math.abs(preview.displayScale()*source.imageWidth-parseFloat(rect.width)/100*frameWidth)<1e-8,'picker and saved cover have identical image scale');
      assert(Math.abs(preview.displayTop()-parseFloat(rect.top)/100*frameWidth*3/5)<1e-8,'picker and saved cover have identical vertical crop at every drag boundary');
      assert(Math.abs(preview.displayLeft()-parseFloat(rect.left)/100*frameWidth)<1e-8,'picker and saved cover have identical horizontal crop');
      preview.loaded=true;preview.cover={status:''};preview.previewActive=true;preview.previewRevision=0;preview.previewId=preview.sourceKey(source);preview.onReady=()=>{};const commits=[];preview.onAction=(action,value)=>commits.push(JSON.parse(value));
      preview.beginDrag();preview.move(100000,100000,true);
      assert.equal(commits.at(-1).cropX,0);assert.equal(commits.at(-1).cropY,0);
      assert(Math.abs(preview.displayTop()) <= preview.displayScale()/2,'top source edge is reachable within source-pixel rounding');
      preview.beginDrag();preview.move(-100000,-100000,true);
      const end=commits.at(-1);assert.equal(end.cropX+end.width,source.imageWidth);assert.equal(end.cropY+end.height,source.imageHeight);
      const bottom=preview.displayTop()+source.imageHeight*preview.displayScale();
      assert(Math.abs(bottom-frameWidth*3/5)<=preview.displayScale()/2,'bottom source edge is reachable within source-pixel rounding');
      assert(Math.abs(preview.displayLeft()+source.imageWidth*preview.displayScale()-frameWidth)<=preview.displayScale()/2,'right source edge is reachable');
      const commitCount=commits.length;
      preview.locked=true;preview.move(100,100,true);assert.equal(commits.length,commitCount);
      preview.locked=false;preview.cover.status='uncertain';preview.move(100,100,true);assert.equal(commits.length,commitCount);
      preview.cover.status='';preview.loaded=false;preview.move(100,100,true);assert.equal(commits.length,commitCount);
    }
  }
  function previewFixture() {
    const pin={id:'11',imageUrl:image,imageWidth:236,imageHeight:513},saved=geometry.boardCoverCrop(pin,0,52,5/3);
    const host=new Preview(),ready=[],loading=[],commits=[];
    Object.assign(host,{frameSide:360,cover:{status:'',loading:false,selected:saved},locked:false,loaded:true,previewFailed:false,previewActive:true,
      previewRevision:0,previewId:'',dragging:false,dragSourceKey:'',selected:()=>pin,onReady:r=>ready.push(r),onPreviewLoading:r=>loading.push(r),
      onAction:(action,value)=>commits.push(JSON.parse(value))});
    host.syncCrop();host.previewComplete(host.previewId,true);
    return {host,pin,saved,ready,loading,commits};
  }
  const cancelled=previewFixture();cancelled.host.beginDrag();cancelled.host.move(0,40,false);cancelled.host.cancelDrag();
  assert.equal(cancelled.host.cropTop,52);assert.equal(cancelled.host.cropHeight,142);assert.equal(cancelled.commits.length,0);
  cancelled.host.finishDrag(0,40);assert.equal(cancelled.commits.length,0,'a cancelled gesture cannot submit a late end event');
  const invalid=previewFixture();invalid.host.beginDrag();
  for(const delta of [NaN,Infinity,-Infinity]){invalid.host.move(delta,0,true);invalid.host.move(0,delta,true);}
  assert.equal(invalid.commits.length,0);assert.equal(invalid.host.cropTop,52,'invalid offsets cannot poison preview coordinates');
  invalid.host.move(0,30,false);invalid.host.finishDrag(NaN,0);assert.equal(invalid.host.cropTop,52,'invalid end restores the committed crop');
  const blocked=previewFixture();
  for(const state of ['uncertain','saving','verifying']){blocked.host.cover.status=state;blocked.host.beginDrag();assert(!blocked.host.dragging);blocked.host.finishDrag(0,20);assert.equal(blocked.ready.at(-1),false);}
  blocked.host.cover.status='';blocked.host.beginDrag();blocked.host.locked=true;blocked.host.finishDrag(0,20);assert.equal(blocked.commits.length,0);assert.equal(blocked.ready.at(-1),false);
  blocked.host.locked=false;blocked.host.syncCrop();assert.equal(blocked.ready.at(-1),true,'unlocking restores readiness for an already decoded image');
  blocked.host.cover.loading=true;blocked.host.syncCrop();assert.equal(blocked.ready.at(-1),false);blocked.host.cover.loading=false;blocked.host.syncCrop();assert.equal(blocked.ready.at(-1),true);
  const resized=previewFixture();resized.host.beginDrag();resized.host.move(0,20,false);resized.host.resizePreview(600);resized.host.finishDrag(0,40);
  assert.equal(resized.commits.length,0);assert.equal(resized.host.cropTop,52);assert.equal(resized.host.frameSide,600,'resize cancels the old viewport gesture before updating geometry');
  resized.host.resizePreview(Infinity);resized.host.resizePreview(0);assert.equal(resized.host.frameSide,600);
  const completed=previewFixture();completed.host.beginDrag();completed.host.finishDrag(0,30);completed.host.finishDrag(0,60);assert.equal(completed.commits.length,1,'one gesture submits once');
  const retried=previewFixture(),oldSource=retried.host.previewPins()[0];
  retried.host.previewComplete(oldSource.key,false);retried.host.previewRevision++;retried.host.syncCrop();
  retried.host.previewComplete(oldSource.key,true);assert(!retried.host.loaded,'old retry success cannot mark the replacement image ready');
  const retrySource=retried.host.previewPins()[0];retried.host.previewComplete(retrySource.key,true);assert(retried.host.loaded);
  retried.host.previewComplete(oldSource.key,false);assert(retried.host.loaded,'old retry error cannot clear the replacement image');
  retried.host.beginDrag();retried.pin.previewImageUrl='https://i.pinimg.com/474x/replaced.jpg';retried.host.syncCrop();assert(!retried.host.dragging);assert(!retried.host.loaded);
  retried.host.previewComplete(retrySource.key,true);assert(!retried.host.loaded,'same Pin with a new source rejects late old-source callbacks');
  const disposed=previewFixture(),disposedKey=disposed.host.previewId;disposed.host.beginDrag();disposed.host.aboutToDisappear();disposed.host.finishDrag(0,50);disposed.host.previewComplete(disposedKey,true);
  assert.equal(disposed.commits.length,0);assert.equal(disposed.ready.at(-1),false);assert.equal(disposed.loading.at(-1),false);
  assert.equal(disposed.host.retainedPreview,undefined,'disposal releases retained preview metadata');
  const switching=previewFixture();let selected=switching.pin;switching.host.selected=()=>selected;
  const firstKey=switching.host.previewId,firstFrame=switching.host.previewPins()[0];
  selected={...switching.pin,id:'12'};switching.host.syncCrop();const secondKey=switching.host.previewId;
  assert.deepEqual(Array.from(switching.host.previewPins(),source=>source.key),[firstKey,secondKey],'keep decoded old image mounted while replacement loads');
  assert.equal(switching.loading.at(-1),false,'switching a visible cover must not flash the page loading overlay');
  assert.equal(switching.host.previewTop(firstFrame),switching.host.displayTop(),'retained crop has stable placement');
  selected=switching.pin;switching.host.syncCrop();assert(switching.host.loaded,'rapid return to the retained image does not wait for a callback that already fired');
  assert.equal(switching.host.previewPins().length,1);
  selected={...switching.pin,id:'13'};switching.host.syncCrop();const thirdKey=switching.host.previewId;
  switching.host.previewComplete(secondKey,true);assert(!switching.host.loaded,'intermediate success cannot replace the latest image');
  switching.host.previewComplete(thirdKey,false);assert.equal(switching.host.previewPins()[0].key,firstKey,'failure retains the displayed image with actions still gated');
  switching.host.previewComplete(thirdKey,true);assert(switching.host.loaded);assert.equal(switching.host.previewPins().length,1);
  const moved=previewFixture();let movedPin=moved.pin;moved.host.selected=()=>movedPin;
  const mounted=moved.host.previewPins()[0];moved.host.beginDrag();moved.host.finishDrag(0,-25);
  const oldTop=moved.host.displayTop();movedPin={...moved.pin,id:'14'};moved.host.syncCrop();
  assert.equal(moved.host.previewTop(mounted),oldTop,'a retained image node keeps the final dragged crop rather than its initial builder values');
  assert.match(component,/if\(!this.cover.adjusting\)\s*\{[\s\S]*?WaterFlow\(\{[^\n]*footer:this.candidateFooter/,'filtered empty pages retain the mounted masonry pagination footer');
  assert.match(component,/PinmonyCdnImage\(\{url:source.pin.previewImageUrl/,'preview uses shared decoded-image pipeline');
  assert.match(component,/onActionEnd\([\s\S]*?this\.finishDrag\(event.offsetX,event.offsetY\)/);
  assert.match(component,/onActionCancel\(\(\): void => \{this.cancelDrag\(\)/,'cancel uses the tested restoration path');
  assert(!component.includes('if(this.cover.loading) { LoadingProgress()'),'cover data loading must not render inside scroll content');
  assert(!component.includes('if(this.selected() && !this.loaded && !this.previewFailed) { LoadingProgress()'),'preview loading shares the page indicator');
  assert.match(pageSource,/this.snapshot.flow.cover.adjusting \|\| this.snapshot.flow.cover.pins.length === 0/,'background pagination does not start another entry spinner');
  assert(!component.includes('pm_board_cover_more'),'no load-more button');
  assert(!component.includes('pm_board_cover_empty'),'empty candidate content remains hidden');
  assert.match(component,/if\(!this.cover.adjusting\)/,'change-cover candidate list stays available even when empty');
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
  assert.equal(invalidations,1);assert.equal(store.boardDetail.flow.phase,'edit');assert(!store.boardDetail.flow.cover);assert.equal(store.boardDetail.flow.description,'Existing description');
  const confirmedPreview=JSON.stringify(store.boardDetail.flow.coverPreview);
  const saved={...savedBoard(crop,{image_url:image}),owner:b.owner,privacy:'public',name:b.name,url:b.url};
  await action('close');p=action('edit');requests.at(-1).resolve(body(saved));await p;
  assert.equal(JSON.stringify(store.boardDetail.flow.coverPreview),confirmedPreview,'closing and reopening edit preserves the confirmed cover viewport');
  p=action('coverAdjust');requests.at(-1).resolve(body(saved));await flush();requests.at(-1).resolve(body([sourcePin()],'v3_board_pins'));await p;
  assert.equal(JSON.stringify(store.boardDetail.flow.cover.selected),JSON.stringify(crop),'nested adjustment restores the saved wide crop');
  await action('coverBack');assert.equal(store.boardDetail.flow.phase,'edit');assert.equal(JSON.stringify(store.boardDetail.flow.coverPreview),confirmedPreview);reader.pause();
}
main().catch(e=>{console.error(e);process.exitCode=1;});
