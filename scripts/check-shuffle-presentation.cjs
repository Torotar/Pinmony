const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyShufflePresentation.ets','utf8');
assert.match(source,/readShufflePresentation/);
assert.match(source,/is_tappable/);
assert.match(source,/motionEffect/);
console.log('Shuffle presentation parser: contract guards present');
function load(text, deps = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(text,{compilerOptions:{target:99,module:1}}).outputText,
    {exports,require:n=>deps[n] || {},console,JSON,Date,setTimeout,clearTimeout});
  return exports;
}
const {readShufflePresentation} = load(source);
const image = {url:'https://i.pinimg.com/736x/fixture.png',width:200,height:400};
const item = {id:'item-1',item_type:1,pin:{id:'202'},images:{'736x':image},settings:{is_tappable:true,scale:0.8,offset:{x:20,y:40},rotation:{z:Math.PI/2}}};
const body = (items=[item], id='303', extra={})=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_get_shuffle',data:{id,items},...extra}});
const result=readShufflePresentation(body(),'303',1080,1920);
assert.equal(result.items[0].pinId,'202');assert.equal(result.items[0].tappable,true);
assert.equal(result.items[0].rotation,90);assert.equal(result.canvasWidth,1080);
assert.equal(readShufflePresentation(body(),'304'),undefined);
assert.equal(readShufflePresentation(body([item],'303',{endpoint_name:'other'}),'303'),undefined);
assert.equal(readShufflePresentation(body([item],'303',{error:{}}),'303'),undefined);
assert.equal(readShufflePresentation(body(Array(201).fill(item)),'303'),undefined);
assert.equal(readShufflePresentation(body([{...item,item_type:3}]),'303').items[0].tappable,false);
assert.equal(readShufflePresentation(body([{...item,settings:{is_tappable:false}}]),'303').items[0].tappable,false);
assert.equal(readShufflePresentation(body([{...item,images:{'736x':{...image,url:'https://evil.invalid/image.png'}}}]),'303').items[0].imageUrl,undefined);
assert.equal(readShufflePresentation(body([{...item,settings:{scale:0}}]),'303'),undefined);
function method(file,name) {
  const text=fs.readFileSync(file,'utf8'), ast=ts.createSourceFile('test.ts',text.replace(/\bstruct\b/g,'class'),99,true);
  let found=''; function visit(n){if(ts.isMethodDeclaration(n)&&n.name.getText(ast)===name)found=n.getText(ast);ts.forEachChild(n,visit);} visit(ast);assert(found,name);return found;
}
const networkMethod=method('common_network/src/main/ets/PinmonyNativeNetwork.ets','requestBusinessShuffleRead');
// The production constant is injected only into this isolated read-policy fixture.
const compiled=ts.transpileModule('class Guard {'+networkMethod+'} Guard;',{compilerOptions:{target:99}}).outputText;
const GuardClass=vm.runInNewContext(compiled,{PIN_BUSINESS_PIN_READ_ENABLED:true});
const guard=new GuardClass();guard.request=async(job,context)=>context().authenticated;
const session=()=>({origin:'https://www.pinterest.com',authenticated:true,accountId:'fixture-account',generation:1,userAgent:''});
const pin='https://www.pinterest.com/pin/101/',path='/pin/101/';
const fields=['shuffle.{id,items,effect_data}','shuffleitem.{id,pin,shuffle_item_image(),settings,item_type,text,offset,scale,rotation,effect_data,mask,bitmap_mask,shuffle_asset,shuffle_item_image,images[236x,736x,736x(heic),750x,750x(heic)]}','shuffleasset.{id,cutout_images[originals],source_images[236x]}'];
const url=options=>'https://www.pinterest.com/resource/ApiResource/get/?source_url='+encodeURIComponent(path)+'&data='+encodeURIComponent(JSON.stringify({options,context:{}}))+'&_=1';
const options={url:'/v3/shuffles/303/',fetchPolicy:'store-or-network',data:{fields}};
const job={id:'native_detail_aux_shuffle_1',page:pin,epoch:1,method:'GET',body:'',url:url(options),headers:{'X-Pinterest-Pws-Handler':'www/pin/[id].js','X-Pinterest-Source-Url':path,'X-Requested-With':'XMLHttpRequest'}};
(async()=>{
 const {PinmonyDetailPrefetch}=load(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets','utf8'),{common_foundation:{PinmonyRuntimeLog:{info:()=>{}}}});
 const previews=new PinmonyDetailPrefetch('detail_prefetch_shuffle_');
 let visible=true;const waiting=[],ready=[];
 previews.onReady=d=>ready.push(d.pinUrl);
 const previewUrls=['601','602','603'].map(id=>'https://www.pinterest.com/pin/'+id+'/');
 previews.offer(previewUrls,'collage-session',async(url,id,current)=>{
   assert.match(id,/^detail_prefetch_shuffle_/);
   const pinId=JSON.parse(decodeURIComponent(url.match(/[?&]data=([^&]+)/)[1])).options.id;
   return new Promise(resolve=>waiting.push(()=>resolve(JSON.stringify({resource_response:{status:'success',data:{id:pinId,type:'pin',images:{'736x':image},title:'Preview '+pinId}}}))));
 },()=>visible,()=>{});
 assert.equal(waiting.length,2,'at most two speculative reads');
 waiting[0]();await new Promise(r=>setTimeout(r,0));
 assert.equal(ready[0],previewUrls[0]);assert.equal(waiting.length,3,'next preview starts only after one finishes');
 visible=false;waiting[1]();waiting[2]();await new Promise(r=>setTimeout(r,0));
 assert.equal(ready.length,1,'late preview must not update hidden collage');previews.clear();
 assert.equal(await guard.requestBusinessShuffleRead(job,session,pin,'303',()=>true),true);
 for(const patch of [{method:'POST'},{epoch:2},{page:pin+'wrong'},{url:url({...options,url:'/v3/shuffles/404/'})},{url:url({...options,data:{fields:['*']}})}])
   assert.equal(await guard.requestBusinessShuffleRead({...job,...patch},session,pin,'303',()=>true),false);
 assert.equal(await guard.requestBusinessShuffleRead(job,session,pin,'303',()=>false),false);
 const open=method('entry/src/main/ets/pages/Index.ets','openShufflePin');
 const Open=vm.runInNewContext(ts.transpileModule('class Open {'+open+'} Open;',{compilerOptions:{target:99}}).outputText);
 const owner=new Open(), opens=[];let cached='';
 owner.detailOpeningCoordinator={prefetchShufflePins:(urls)=>{owner.previewUrls=urls}};
 Object.assign(owner,{authStatus:'authenticated',businessSuspended:false,activeSheetKind:'',pinStore:{videoForeground:true,detailNativeReadsReady:true,detailPreparing:false,detailScrollOffset:30,detailOpeningPin:'',detail:{pinUrl:pin,shuffleId:'303',imageUrl:image.url,shuffle:result},detailCache:{put:(id)=>cached=id}},detailNativeReads:{owned:()=>true},currentPinUrl:()=>pin,nativeBusinessSessionContext:session,pinIdentity:s=>s.split('/pin/')[1].split('/')[0],beginDetailOpening:(...args)=>opens.push(args)});
 owner.openShufflePin('missing');assert.equal(opens.length,0);
 owner.openShufflePin('item-1');assert.equal(opens.length,1);assert.equal(opens[0][0],'https://www.pinterest.com/pin/202/');assert.equal(opens[0][1],pin);assert.equal(cached,'101');
 const second={...result.items[0],id:'item-2',pinId:'505'};
 owner.shuffleParentDetail.shuffle.items.push(second);
 owner.pinStore.detail={pinUrl:'https://www.pinterest.com/pin/202/'};
 owner.currentPinUrl=()=>owner.pinStore.detail.pinUrl;
 cached='';owner.openShufflePin('item-2');
 assert.equal(opens[1][0],'https://www.pinterest.com/pin/505/');
 assert.equal(opens[1][1],pin,'sibling return must remain the collage parent');
 assert.equal(cached,'','sibling must not overwrite parent scroll');
 assert.equal(owner.shuffleSelectedIndex,1);
 const page=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
 assert.match(page,/item.id === this.shuffleItems\[this.shuffleIndex\]\?\.id\) this.onBack\?\.\(\)/,'only the current photo single tap exits');
 assert.match(page,/Scroll\(\) \{ this.shuffleSelectedCard\(\) \}.width\('100%'\).height\(188\)/,'metadata must not move the photo');
 assert.equal(owner.previewUrls[0],'https://www.pinterest.com/pin/202/','adjacent card must be requested before selecting it');
 const canvas=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyShuffleCanvas.ets','utf8');
 assert.match(canvas,/\.onClick\([\s\S]*?\}, 8\)/);
 assert.doesNotMatch(canvas,/\.gesture\(/,'item clicks must yield to the parent scroll recognizer');
 const root=method('entry/src/main/ets/pages/Index.ets','detailRootIdentity');
 const Identity=vm.runInNewContext(ts.transpileModule('class Identity {'+root+'} Identity;',{compilerOptions:{target:99}}).outputText);
 const retained=new Identity();Object.assign(retained,{pinStore:{detail:{pinUrl:pin}},pinIdentity:s=>s,shuffleParentDetail:{pinUrl:'parent'},shuffleSelectedImage:image.url,collageDetailPinUrl:pin});
 const before=retained.detailRootIdentity();retained.pinStore.detail={pinUrl:'child2'};retained.collageDetailPinUrl='child2';
 assert.equal(retained.detailRootIdentity(),before,'sibling selection must not remount the carousel');
 owner.authStatus='anonymous';owner.openShufflePin('item-1');assert.equal(opens.length,2);
 const auxFile='entry/src/main/ets/app/PinmonyDetailNativeAuxiliary.ets';
 const Reader=vm.runInNewContext(ts.transpileModule('class Reader {'+method(auxFile,'readShuffle')+'} Reader;',{compilerOptions:{target:99}}).outputText,
   {PinmonyShufflePresentation:{},feature_pin_1:{readShufflePresentation},common_foundation_1:{PinmonyI18n:{message:key=>key}},readShufflePresentation,PinmonyI18n:{message:key=>key},JSON,Date});
 const reader=new Reader();let respond;
 const response=new Promise(resolve=>respond=resolve);
 Object.assign(reader,{store:{detail:{pinUrl:pin,shuffleId:'303',imageWidth:1080,imageHeight:1920}},pin,revision:1,sequence:0,requests:new Set(),ready:()=>true,ports:{session,network:()=>({requestBusinessShuffleRead:()=>response})}});
 const pending=reader.readShuffle({images:{orig:{width:1080,height:1920}}});
 assert.equal(reader.store.detail.shuffleLoading,true);
 reader.revision++;reader.store.detail={pinUrl:'https://www.pinterest.com/pin/404/',shuffleId:'404'};
 respond({status:200,body:body()});await pending;
 assert.equal(reader.store.detail.pinUrl,'https://www.pinterest.com/pin/404/');assert.equal(reader.store.detail.shuffle,undefined,'late parent response must not replace child');
 console.log('Shuffle: response identity, safe images, read allowlist, stale ownership and selected Pin navigation passed');
})().catch(e=>{console.error(e);process.exitCode=1});
