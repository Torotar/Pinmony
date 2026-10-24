const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), ts = require(process.argv[2]);
const pageSource = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
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
const historySource=fs.readFileSync('feature_search/src/main/ets/components/PinmonyPhotoHistoryPage.ets','utf8');
const selectStart=historySource.indexOf('  private selectPhoto(');
const selectEnd=historySource.indexOf('\n  aboutToAppear',selectStart);
const Selection=vm.runInNewContext(ts.transpileModule('class Selection {'+historySource.slice(selectStart,selectEnd)+'}\nSelection;',
 {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const selection=new Selection();let warnings=0;
selection.selected='';selection.confirming=false;selection.text=key=>key;
selection.getUIContext=()=>({getPromptAction:()=>({showToast:()=>warnings++})});
selection.selectPhoto('first');assert.equal(selection.selected,'first');
selection.selectPhoto('second');assert.equal(selection.selected,'first');assert.equal(warnings,1);
selection.selectPhoto('first');assert.equal(selection.selected,'');
selection.selectPhoto('second');assert.equal(selection.selected,'second');
selection.confirming=true;selection.selectPhoto('second');assert.equal(selection.selected,'second');
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
 {exports:{},util:{TextDecoder:{create:()=>({decodeWithStream:bytes=>Buffer.from(bytes).toString('utf8')})}},parsePhotoHistory:parse,parsePhotoSearch:()=>[]});
(async()=>{
 const origin='https://www.pinterest.com',session={authenticated:true,accountId:'test',generation:1,origin};
 let sent=0,preview='',pending;
 const text=Buffer.from(JSON.stringify({resource_response:resource}));
 const buffer=text.buffer.slice(text.byteOffset,text.byteOffset+text.byteLength);
 const network={cancel(){},readPhotoHistory:async(cursor,url)=>url?new ArrayBuffer(12):buffer,
   searchUploadedPhoto:async()=>{sent++;return '{}';}};
 const ports={session:()=>session,network:()=>network,page:()=>origin+'/search/',active:()=>true,jpeg:async b=>b};
 const flow=new Flow(ports);await flow.history('');
 await flow.selectHistory('unknown',()=>{});assert.equal(sent,0);
 await flow.selectHistory('history-test',uri=>{preview=uri;});assert.equal(sent,1);assert.equal(preview,pin.image_urls['736x']);
 await flow.history('');session.generation++;await flow.selectHistory('history-test',()=>{});assert.equal(sent,1);
 session.generation++;network.readPhotoHistory=()=>new Promise(resolve=>{pending=resolve;});
 const late=flow.history('');flow.cancel();pending(buffer);await assert.rejects(late);
 console.log('History selection identity, session change and cancelled read checks passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
