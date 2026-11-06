const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), ts = require(process.argv[2]);
const pageSource = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const photoPageSource = fs.readFileSync('feature_search/src/main/ets/components/PinmonyPhotoSearchPage.ets', 'utf8');
assert(!pageSource.includes('.bindMenu('), 'Root rendering must not execute the failing controlled menu binding');
assert(pageSource.includes('getPromptAction().openMenu('), 'Photo actions must use the native anchored menu after an explicit click');
assert(!pageSource.includes('showActionMenu('), 'Do not substitute a centered action dialog for the anchored menu');
assert(!pageSource.includes('placement: Placement.'), 'Do not depend on the failing root menu enum binding');
const source = fs.readFileSync('feature_search/src/main/ets/models/PinmonyPhotoHistory.ets', 'utf8').replace(/export /g, '');
const parse = vm.runInNewContext(ts.transpileModule(source + '\nparsePhotoHistory;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const pin = { id:'history-test',type:'lens_image',image_urls:{'736x':'https://i.pinimg.com/736x/test.jpg'},image_sizes:{'736x':{width:736,height:1000}} };
const resource = {status:'success',code:0,endpoint_name:'v3_get_lens_histories',data:[pin],bookmark:'next'};
const run = (r=resource,previous='') => parse(JSON.stringify({resource_response:r}),previous);
assert.equal(run().items[0].height,1000);
assert.equal(run().ended,false);
assert.equal(run(resource,'next').ended,true);
assert.equal(run({...resource,data:[],bookmark:'-end-'}).ended,true);
assert.equal(run({...resource,data:[pin,pin]}).items.length,1);
assert.throws(()=>run({...resource,status:'failure'}));
assert.throws(()=>run({...resource,endpoint_name:'wrong'}));
assert.throws(()=>run({...resource,data:[{...pin,image_urls:{'736x':'https://example.com/test.jpg'}}]}));
if(process.argv[3]) {
 const har=JSON.parse(fs.readFileSync(process.argv[3],'utf8')); let count=0;
 for(const e of har.log.entries){if(new URL(e.request.url).pathname!=='/resource/ApiResource/get/')continue;
  const q=e.request.queryString.find(p=>p.name==='data');if(!q)continue;
  const options=JSON.parse(decodeURIComponent(q.value)).options;
  if(options.url!=='/v3/visual_search/lens/history/')continue;
  const text=e.response.content.encoding==='base64'?Buffer.from(e.response.content.text,'base64').toString('utf8'):e.response.content.text;
  const page=parse(text,options.bookmarks?.[0]||'');assert(Array.isArray(page.items));count++;
 }
 assert(count>0); console.log('Captured history responses mapped:',count);
}
console.log('Photo history validation, original ratio, empty, pagination and deduplication passed');
const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const keyStart=indexSource.indexOf('  private detailPresentationKey(');
assert(keyStart>=0);
const keyEnd=indexSource.indexOf('\n  }',keyStart);
const DetailKey=vm.runInNewContext(ts.transpileModule('class DetailKey {'+indexSource.slice(keyStart,keyEnd+4)+'} DetailKey;',
 {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const detailKey=new DetailKey(), route='https://www.pinterest.com/pin/123/';
detailKey.detailEntryCards=new Map();detailKey.detailPresentation=()=>({pinUrl:route});
const ordinaryKey=detailKey.detailPresentationKey('123');
detailKey.detailEntryCards.set(route,'pinmony-photo-result-123');
const photoKey=detailKey.detailPresentationKey('123');
assert.notEqual(photoKey,ordinaryKey,'history/photo result gets its own Pin component instance even for the same Pin');
assert.equal(detailKey.detailPresentationKey('123'),photoKey,'snapshot updates retain the photo result instance');
assert(indexSource.includes('}, (_identity: string) => this.detailPresentationKey(_identity))'));
const detailSource=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
assert(detailSource.includes('mainTitle: this.uiText("pm_detail_photo_search")'));
assert(fs.readFileSync('feature_pin/src/main/ets/components/PinmonyVisualSearchView.ets','utf8').includes('PinmonyImageSearchView as PinmonyVisualSearchView'));
assert(photoPageSource.includes('PinmonyImageSearchView({'),'detail and uploaded photos use the same search content within separate page hosts');
for(const [locale,title] of [['zh_CN','搜索照片'],['en_US','Search photos']]){
 const strings=JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`,'utf8')).string;
 assert.equal(strings.find(item=>item.name==='pm_detail_photo_search').value,title);
}
console.log('Photo result Pin: independent stable instance, shared detail search content and localized title passed');
const historySource=fs.readFileSync('feature_search/src/main/ets/components/PinmonyPhotoHistoryPage.ets','utf8');
assert(!historySource.includes('sys.symbol.checkmark_circle_fill'),'history photo selection uses its border without a checkmark overlay');
const selectStart=historySource.indexOf('  private selectPhoto(');
const selectEnd=historySource.indexOf('\n  aboutToAppear',selectStart);
const Selection=vm.runInNewContext(ts.transpileModule('class Selection {'+historySource.slice(selectStart,selectEnd)+'}\nSelection;',
 {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const selection=new Selection();let openedPhotos=0;
Object.assign(selection,{selected:'',confirming:false,busy:false,deleting:false,managing:false,pendingIds:[],uncertainIds:[],confirm:()=>openedPhotos++});
selection.selectPhoto('first');assert.equal(selection.selected,'first');
assert.equal(openedPhotos,1,'photo tap opens search without a title-bar confirmation');
selection.selectPhoto('second');assert.equal(selection.selected,'second');
selection.confirming=true;selection.selectPhoto('second');assert.equal(selection.selected,'second');
selection.confirming=false;selection.managing=true;selection.selectPhoto('third');assert.equal(selection.selected,'second');
assert(!historySource.slice(historySource.indexOf(".titleBar({")).includes("sys.symbol.checkmark"),'history title has no checkmark confirmation');
assert(historySource.includes('.blur(this.pendingIds.includes(item.id) ? 18 : 0)'),'pending deletions retain a blurred card');
assert(historySource.includes('SmartImage({'), 'History must reuse the shared image component');
assert(historySource.includes('crossCount: this.columns()'), 'A single item must retain the waterfall column width');
assert(!historySource.includes('Math.min(440'), 'Image heights must not be cropped to a history-specific cap');
const methods=['columns','cardWidth','cardHeight'].map(name=>{
 const match=historySource.match(new RegExp('  private '+name+'\\([^\\n]+\\n?'));assert(match);return match[0];
}).join('\n');
const Layout=vm.runInNewContext(ts.transpileModule('class Layout {'+methods+'}\nLayout;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{RECOMMEND_PHONE_GAP_VP:12});
for(const width of [328,600,900]){
 const layout=new Layout();layout.widthValue=width;
 assert(layout.cardWidth()<width);
 assert(Math.abs(layout.cardWidth()*layout.columns()+12*(layout.columns()-1)-width)<.001);
 for(const ratio of [.2,1,2,5])assert(Math.abs(layout.cardHeight({width:100,height:100*ratio})/layout.cardWidth()-ratio)<.001);
}
console.log('History cards: shared image, fixed waterfall columns and uncropped aspect ratios passed');
const flowSource=fs.readFileSync('entry/src/main/ets/app/PinmonyPhotoSearchFlow.ets','utf8').replace(/^import .*;\r?\n/gm,'');
const Flow=vm.runInNewContext(ts.transpileModule(flowSource+'\nPinmonyPhotoSearchFlow;', {compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,
 {exports:{},util:{TextDecoder:{create:()=>({decodeWithStream:bytes=>Buffer.from(bytes).toString('utf8'),decodeToString:bytes=>Buffer.from(bytes).toString('utf8')})}},parsePhotoHistory:parse,parsePhotoSearch:()=>[]});
(async()=>{
 const loadStart=historySource.indexOf('  private async load('),loadEnd=historySource.indexOf('\n  }',loadStart);
 const Loader=vm.runInNewContext(ts.transpileModule('class Loader {'+historySource.slice(loadStart,loadEnd+4)+'} Loader;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
 const loader=new Loader();let hiddenReads=0;Object.assign(loader,{loadingActive:false,interactionActive:true,onLoad:async()=>{hiddenReads++;}});await loader.load();assert.equal(hiddenReads,0,'history covered by photo results cannot start reads that cancel those results');
 assert(!historySource.includes('padding({left:16,right:16,bottom:16})'),'no fixed history bottom gutter');
 assert(historySource.includes('.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])'),'history content extends under bottom system area');

 const navigationMethods=['selectPhotoHistory','closePhotoSearch','closePhotoHistory'].map(name=>{
  const start=pageSource.search(new RegExp('  private (?:async )?'+name+'\\('));assert(start>=0);
  const end=pageSource.indexOf('\n  }',start);assert(end>start);
  return pageSource.slice(start,end+4);
 }).join('\n');
 const Navigation=vm.runInNewContext(ts.transpileModule('class Navigation {'+navigationMethods+'}\nNavigation;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
 const nav=new Navigation(),paths=['search','photo-history'],visibility=[];
 let cancels=0,finishResults;
 Object.assign(nav,{active:true,photoGeneration:0,photoHistoryVisible:true,photoPreview:'',
  dismissPhotoMenu:()=>{},onPhotoCancel:()=>cancels++,onPhotoVisibilityChange:v=>visibility.push(v),
  searchPathStack:{getAllPathName:()=>paths.slice(),pushPath:p=>paths.push(p.name),pop:()=>paths.pop()},
  onSelectPhotoHistory:async(id,selected)=>{selected('history-image');return new Promise(resolve=>{finishResults=resolve;});}});
 const selecting=nav.selectPhotoHistory('history-test');
 assert.deepEqual(paths,['search','photo-history','photo-search']);
 nav.closePhotoSearch(true);
 assert.deepEqual(paths,['search','photo-history'],'back reveals the retained history destination');
 assert.equal(nav.photoHistoryVisible,true);assert.equal(cancels,0);assert.deepEqual(visibility,[]);
 finishResults([{id:'late'}]);await selecting;
 assert.equal(nav.photoResults.length,0,'late results cannot repopulate the closed search');
 nav.photoPreview='history-image';paths.push('photo-search');nav.closePhotoSearch();
 assert.deepEqual(paths,['search'],'full cleanup removes results before history');
 assert.equal(nav.photoHistoryVisible,false);assert.deepEqual(visibility,[false]);
 paths.push('photo-history');nav.photoHistoryVisible=true;
 const cardOrigin={x:12,y:150,width:158,height:240,imageWidth:316,imageHeight:480};
 const animated=nav.selectPhotoHistory('history-test',cardOrigin);
 assert.equal(nav.photoHistoryOrigin,cardOrigin);
 nav.closePhotoSearch(true);
 assert.equal(nav.photoClosing,true);assert.equal(paths.at(-1),'photo-search','reverse animation completes before popping');
 nav.closePhotoSearch(true);assert.equal(paths.at(-1),'photo-search','repeated back does not pop during flight');
 nav.photoHistoryOrigin=undefined;nav.closePhotoSearch(true);
 assert.deepEqual(paths,['search','photo-history']);assert.equal(nav.photoHistoryLifted,false);
 finishResults([{id:'late-animation'}]);await animated;assert.equal(nav.photoResults.length,0);
 assert(pageSource.includes('origin: this.photoHistoryOrigin, closing: this.photoClosing'));
 assert(photoPageSource.includes('animatePhoto: !!this.origin, closing: this.closing'));
 assert(photoPageSource.includes('NavDestinationMode.STANDARD'),'search owns a full page and a separate title bar');
 assert(!photoPageSource.includes('NavDestinationMode.DIALOG'),'the history title must not remain beneath a dialog destination');
 assert(historySource.includes(".id('pinmony-history-photo-' + item.id)"));
 assert(pageSource.includes('onBack: () => this.backPhotoSearch()'));
 assert(pageSource.includes('onClose: () => this.closePhotoSearch(true)'));
 assert(photoPageSource.includes('this.onClose?.();'));
 console.log('Photo history navigation: retained parent, system/title back, late results and full cleanup passed');
 const origin='https://www.pinterest.com',session={authenticated:true,accountId:'test',generation:1,origin};
 let sent=0,preview='',pending;
 const text=Buffer.from(JSON.stringify({resource_response:resource}));
 const buffer=text.buffer.slice(text.byteOffset,text.byteOffset+text.byteLength);
 const network={cancel(){},readPhotoHistory:async(cursor,url)=>url?new ArrayBuffer(12):buffer,
   searchUploadedPhoto:async()=>{sent++;return '{}';}};
 const ports={session:()=>session,network:()=>network,page:()=>origin+'/search/',active:()=>true,jpeg:async b=>b};
 const flow=new Flow(ports);let historyReads=0;const initialRead=network.readPhotoHistory;network.readPhotoHistory=async(...args)=>{historyReads++;return initialRead(...args);};await flow.history('');await flow.history('');assert.equal(historyReads,1,'same-session history reopen reuses the validated first page');
 await flow.selectHistory('unknown',()=>{});assert.equal(sent,0);
 await flow.selectHistory('history-test',uri=>{preview=uri;});assert.equal(sent,1);assert.equal(preview,pin.image_urls['736x']);
 const normalRead=network.readPhotoHistory;
 let downloaded,encoded,shown=0;
 network.readPhotoHistory=()=>new Promise(resolve=>{downloaded=resolve;});
 ports.jpeg=()=>new Promise(resolve=>{encoded=resolve;});
 const immediate=flow.selectHistory('history-test',()=>{shown++;});
 assert.equal(shown,1,'history preview opens before download finishes');assert.equal(sent,1);
 downloaded(new ArrayBuffer(12));await new Promise(resolve=>setImmediate(resolve));
 assert.equal(sent,1,'upload waits for JPEG preparation');assert.equal(shown,1);
 encoded(new ArrayBuffer(12));await immediate;assert.equal(sent,2);
 const cancelled=flow.selectHistory('history-test',()=>{shown++;});
 flow.cancel();downloaded(new ArrayBuffer(12));assert.equal(await cancelled,undefined);
 assert.equal(sent,2,'closing during preparation prevents upload');
 network.readPhotoHistory=normalRead;ports.jpeg=async b=>b;await flow.history('');
 network.readPhotoHistory=async()=>{throw new Error('download');};
 await assert.rejects(flow.selectHistory('history-test',()=>{shown++;}));
 assert.equal(shown,3,'download failure occurs after opening the preview');assert.equal(sent,2);
 network.readPhotoHistory=normalRead;
 const stopped=await flow.selectHistory('history-test',()=>flow.cancel());
 assert.equal(stopped,undefined);assert.equal(sent,2,'synchronous close cannot dispatch a download or upload');
 await flow.history('');session.generation++;await flow.selectHistory('history-test',()=>{});assert.equal(sent,2);
 session.generation++;network.readPhotoHistory=()=>new Promise(resolve=>{pending=resolve;});
 const late=flow.history('');flow.cancel();pending(buffer);await assert.rejects(late);
 console.log('History selection identity, session change and cancelled read checks passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
