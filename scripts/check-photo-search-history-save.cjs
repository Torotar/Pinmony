const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const transpile=s=>require('./native-network-test-fixture.cjs').transpile(ts, s,{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
function method(source,name){const tree=ts.createSourceFile('s.ts',source.replace(/\bstruct\b/g,'class'),99,true);let found;function visit(n){if(ts.isMethodDeclaration(n)&&n.name.getText(tree)===name)found=n.getText(tree);ts.forEachChild(n,visit);}visit(tree);assert(found,name);return found;}
const source=fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets','utf8');
const requests=[];let body={success:true,status:'success',code:0,endpoint_name:'v3_create_lens_history',data:{}};
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, {
  common_foundation: {PinmonyRuntimeLog:{info(){},warn(){}}},
  common_session: {PinmonySessionCredentials:class {}},
  '@kit.RemoteCommunicationKit': {rcp: {Request: class {constructor(url,method,headers,body){Object.assign(this,{url,method,headers,body});}}, MultipartForm: class {constructor(fields){this.fields=fields;}}}},
  '@kit.BasicServicesKit': {}
}, {PinmonyTestTransportOnly:true});
const core=loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
core.NetworkManager.enqueue=(_,call)=>call();core.NetworkManager.requestRemainingMs=()=>0;
core.NetworkManager.getSession=()=>({fetch:async request=>{requests.push(request);const text=JSON.stringify(body);return {statusCode:200,headers:{},body:new Uint8Array(Buffer.from(text)).buffer,toString:()=>text};}});
const {PinmonyBusinessNetwork:Network}=loader.loadFile('entry/src/main/ets/app/PinmonyBusinessNetwork.ets');
const session={authenticated:true,accountId:'test',generation:1,origin:'https://www.pinterest.com',userAgent:'test'};
const jpeg=new Uint8Array(24);jpeg[0]=255;jpeg[1]=216;
(async()=>{
 const net=new Network();Object.assign(net,{foreground:true,generation:1,pending:new Set(),cancelled:new Set(),jobs:new Map(),sentJobs:new Set(),credentials:{read:async()=> 'csrftoken=synthetic',update:async()=>{}}});
 const save=(owner=()=>true)=>net.saveUploadedPhotoHistory(jpeg.buffer,session.origin+'/search/',()=>session,owner,'native_photo_search_1');
 await save();assert.equal(requests.length,1);assert.equal(requests[0].method,'PUT');assert.equal(new URL(requests[0].url).pathname,'/upload-lens-image-history/');
 const fields=requests[0].body.fields;assert.deepEqual(Object.keys(fields).sort(),['image','source_type']);assert.equal(fields.source_type,'CAMERA_GALLERY');assert.equal(fields.image.remoteFileName,'lens-file-image');assert.equal(fields.image.contentOrPath.content,jpeg.buffer);
 await assert.rejects(save(()=>false));assert.equal(requests.length,1);
 for(const patch of [{success:false},{code:1},{endpoint_name:'other'},{data:null}]){body={success:true,status:'success',code:0,endpoint_name:'v3_create_lens_history',data:{},...patch};await assert.rejects(save());}
 const flowSource=fs.readFileSync('entry/src/main/ets/app/PinmonyPhotoSearchFlow.ets','utf8').replace(/^import .*;\r?\n/gm,'').replace(/export /g,'');
 const Flow=vm.runInNewContext(transpile(flowSource+'\nPinmonyPhotoSearchFlow;'),{parsePhotoSearch:()=>[{id:'one',targetUrl:session.origin+'/pin/1/'}]});
 let writes=0,failures=0,fail=false;const network={cancel(){},searchUploadedPhoto:async()=> '{}',saveUploadedPhotoHistory:async()=>{writes++;if(fail)throw Error('unconfirmed');}};
 const flow=new Flow({session:()=>session,page:()=>session.origin+'/search/',active:()=>true,pick:async()=> 'photo',read:async()=>jpeg.buffer,network:()=>network,historySaveFailed:()=>failures++});
 assert.equal((await flow.search()).length,1);assert.equal(writes,1);await flow.crop({x:0,y:0,w:1,h:1});assert.equal(writes,1,'crop does not duplicate history');
 fail=true;assert.equal((await flow.search()).length,1,'history failure preserves valid search results');await new Promise(setImmediate);assert.equal(failures,1);await flow.crop({x:0,y:0,w:1,h:1});assert.equal(writes,2,'unconfirmed write is never replayed');
 let rejectSave,saveOwner,saveId,activePhoto=true;const cancelled=[];let independentFailures=0;
 const independentNetwork={cancel:id=>cancelled.push(id),searchUploadedPhoto:async()=> '{}',saveUploadedPhotoHistory:(_bytes,_page,_session,owner,id)=>{saveOwner=owner;saveId=id;return new Promise((_resolve,reject)=>{rejectSave=reject;});}};
 const independent=new Flow({session:()=>session,page:()=>session.origin+'/search/',active:()=>activePhoto,pick:async()=> 'photo',read:async()=>jpeg.buffer,network:()=>independentNetwork,historySaveFailed:()=>independentFailures++});
 const immediate=await Promise.race([independent.search(),new Promise(resolve=>setTimeout(()=>resolve('blocked'),100))]);
 assert.equal(immediate.length,1,'valid results resolve while history write is still pending');assert(saveId);
 await independent.crop({x:0,y:0,w:1,h:1});assert(!cancelled.includes(saveId),'crop cannot cancel the independent history write');assert(saveOwner());
 activePhoto=false;assert(saveOwner(),'opening a Pin retains ownership of an already requested history save');rejectSave(Error('unconfirmed'));await new Promise(setImmediate);assert.equal(independentFailures,1);
 activePhoto=true;await independent.search();const oldOwner=saveOwner,oldReject=rejectSave,oldId=saveId;independent.cancel();assert(cancelled.includes(oldId));assert(!oldOwner());oldReject(Error('late'));await new Promise(setImmediate);assert.equal(independentFailures,1,'closing suppresses late history feedback');
 await independent.search();const changedOwner=saveOwner,changedReject=rejectSave;session.generation++;assert(!changedOwner());changedReject(Error('old-account'));await new Promise(setImmediate);assert.equal(independentFailures,1);session.generation--;
 const ui=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
 const Back=vm.runInNewContext(transpile('class Back {'+method(ui,'backPhotoSearch')+'} Back;'));
 const back=new Back(),paths=['search','photo-search'];let detailDepth=2,photoBacks=0;
 Object.assign(back,{active:false,retainPhotoSearch:true,onBack:()=>detailDepth--,closePhotoSearch:()=>{photoBacks++;paths.pop();}});
 // Model HDS: false invokes the default path pop; true consumes that default.
 const systemBack=()=>{if(!back.backPhotoSearch())paths.pop();};systemBack();assert.equal(detailDepth,1);assert.deepEqual(paths,['search','photo-search']);
 systemBack();assert.equal(detailDepth,0);assert.equal(photoBacks,0);back.active=true;systemBack();assert.equal(photoBacks,1);assert.deepEqual(paths,['search']);
 const historyUI=fs.readFileSync('feature_search/src/main/ets/components/PinmonyPhotoHistoryPage.ets','utf8');
 const HistoryBack=vm.runInNewContext(transpile('class HistoryBack {'+method(historyUI,'handleSystemBack')+'} HistoryBack;'));
 const historyBack=new HistoryBack();let delegated=0,historyPopped=0;Object.assign(historyBack,{interactionActive:false,onInactiveBack:()=>delegated++,back:()=>historyPopped++});assert.equal(historyBack.handleSystemBack(),true);assert.equal(delegated,1);assert.equal(historyPopped,0);historyBack.interactionActive=true;assert.equal(historyBack.handleSystemBack(),true);assert.equal(historyPopped,1);
 const callbackStart=ui.indexOf('if (this.onPhotoResult) this.onPhotoResult(id, origin);');assert(callbackStart>=0);const callback=ui.slice(callbackStart,callbackStart+130);assert(!callback.includes('closePhotoSearch'));
 const Active=vm.runInNewContext(transpile('class Active {'+method(ui,'activeChanged')+'} Active;'),{PinmonyRuntimeLog:{info(){}}});
 let closed=0,cleared=0;const active=new Active();Object.assign(active,{active:false,retainPhotoSearch:true,pagePresent:true,detailReturnPreview:false,closePhotoSearch:()=>closed++,searchPathStack:{clear:()=>cleared++},tracePresentation(){}});active.activeChanged();await Promise.resolve();assert.equal(closed,0);assert.equal(cleared,0);
 active.retainPhotoSearch=false;active.activeChanged();await Promise.resolve();assert.equal(closed,1);assert.equal(cleared,1);
 const shared=fs.readFileSync('common_ui/src/main/ets/components/PinmonyImageSearchView.ets','utf8');
 const Sheet=vm.runInNewContext(transpile('class Sheet {'+['presentationChanged','resultSheetDisappeared','updateSheetDetent'].map(n=>method(shared,n)).join('\n')+'} Sheet;'),{clearTimeout(){},SheetSize:{LARGE:'large'},PinmonyRuntimeLog:{info(){}}});
 const sheet=new Sheet();Object.assign(sheet,{alive:true,presentationActive:false,sheetVisible:true,relatedOpening:true});sheet.presentationChanged();assert.equal(sheet.sheetVisible,false,'hidden results cannot cover Pin detail');
 sheet.presentationActive=true;sheet.presentationChanged();assert.equal(sheet.sheetVisible,true,'return restores results Sheet');assert.equal(sheet.relatedOpening,false);
 let photoClosed=0;sheet.onClose=()=>photoClosed++;
 // Production click sets relatedOpening before requesting the Sheet dismissal.
 Object.assign(sheet,{relatedOpening:true,resultSheetMounted:true,sheetVisible:false,closeRequested:false,presentationActive:true});
 sheet.resultSheetDisappeared();assert.equal(photoClosed,0,'Sheet disappears before hidden prop arrives without closing photo search');
 sheet.presentationActive=false;sheet.presentationChanged();sheet.resultSheetDisappeared();assert.equal(photoClosed,0,'hidden Sheet disappearance preserves photo page');
 sheet.presentationActive=true;sheet.presentationChanged();assert.equal(sheet.sheetVisible,true);
 Object.assign(sheet,{relatedOpening:true,resultSheetMounted:true,sheetVisible:false,presentationActive:false});sheet.presentationChanged();
 sheet.presentationActive=true;sheet.presentationChanged();assert.equal(sheet.resumeRelatedSheet,true,'quick return waits for old Sheet dismissal');
 assert.equal(sheet.sheetVisible,false);sheet.resultSheetDisappeared();assert.equal(photoClosed,0);assert.equal(sheet.sheetVisible,true,'late disappearance reopens results rather than closing parent');
 sheet.resultSheetMounted=true;sheet.relatedOpening=false;sheet.sheetVisible=false;sheet.resultSheetDisappeared();assert.equal(photoClosed,1,'explicit dismissal still closes photo search');
 assert(shared.includes('this.presentationActive && !this.relatedOpening && !this.closing'),'programmatic result dismissal cannot close retained search');
 Object.assign(sheet,{sheetHeight:'40%',sheetAppearing:false,relatedOpening:false,presentationActive:true,closing:false,sheetVisible:true,heightValue:800,getUIContext:()=>({px2vp:n=>n/2})});
 sheet.updateSheetDetent(1500);assert.equal(sheet.sheetHeight,'large','user expands to large');
 sheet.relatedOpening=true;sheet.sheetVisible=false;sheet.updateSheetDetent(500);assert.equal(sheet.sheetHeight,'large','dismiss detent cannot replace large');
 sheet.presentationActive=false;sheet.updateSheetDetent(0);assert.equal(sheet.sheetHeight,'large');
 sheet.resultSheetMounted=false;sheet.presentationActive=true;sheet.presentationChanged();sheet.updateSheetDetent(600);assert.equal(sheet.sheetHeight,'large','initial reappear detent cannot replace saved height');
 sheet.sheetAppearing=false;sheet.updateSheetDetent(600);assert.equal(sheet.sheetHeight,'40%','user can collapse after reappear');
 sheet.relatedOpening=true;sheet.sheetVisible=false;sheet.updateSheetDetent(0);assert.equal(sheet.sheetHeight,'40%','default detent is retained too');
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 const preparation=index.match(/preparingDetailReturn: ([\s\S]*?),\r?\n      pinStore:/)[1];
 for(const detail of [undefined,{pinUrl:'pin'}]) {const host={pinStore:{detail},preservingSearchForPin:()=>false,searchEntryReturnPreparing:false,homeEntryClosing:true,homeEntryCardId:'pinmony-photo-result-one'};assert.equal(Function('return '+preparation).call(host),!!detail,'photo return preparation ends when detail is gone');}
 const Entry=vm.runInNewContext(transpile('class Entry {'+method(index,'openPhotoSearchPin')+'} Entry;'));
 const entry=new Entry();let openedMotion;
 Object.assign(entry,{pinStore:{detailScrollOffset:250},beginDetailOpening:(url,source)=>{openedMotion={url,source,photo:entry.homeEntryPhoto};assert.equal(entry.homeEntryClosing,false);assert.equal(entry.homeEntryBackCommitted,false);assert.equal(entry.searchEntryReturnPreparing,false);assert.equal(entry.searchEntryReturnAttempts,0);}});
 entry.openPhotoSearchPin('pin','search',{id:'one',imageUrl:'image'});assert.equal(openedMotion.photo.returnPageOnly,true);assert.equal(openedMotion.source,'search');assert.equal(entry.pinStore.detailScrollOffset,250,'ordinary page entry preserves cached scroll');
 Object.assign(entry,{homeEntryClosing:true,homeEntryBackCommitted:true,searchEntryReturnPreparing:true,searchEntryReturnAttempts:7});entry.openPhotoSearchPin('pin','search',{id:'one',imageUrl:'image'});assert.equal(openedMotion.photo.returnPageOnly,true,'same Pin reentry stays a page opening');
 Object.assign(entry,{homeEntryClosing:true,homeEntryBackCommitted:true,searchEntryReturnPreparing:true,searchEntryReturnAttempts:7});entry.openPhotoSearchPin('pin-two','search',{id:'two',imageUrl:'image-two'});assert.equal(openedMotion.url,'pin-two','a different Pin resets the previous exit too');
 for(const [w,h] of [[736,1118],[1200,800],[900,900]]) {entry.openPhotoSearchPin('ratio','search',{id:'ratio',imageUrl:'image',imageWidth:w,imageHeight:h});assert.equal(openedMotion.photo.imageWidth,w);assert.equal(openedMotion.photo.imageHeight,h);assert.equal(openedMotion.photo.returnPageOnly,true);const contentWidth=320;assert.equal(contentWidth*openedMotion.photo.imageHeight/openedMotion.photo.imageWidth,contentWidth*h/w,'opening receives original image ratio');}
 assert(shared.includes('detentSelection: this.sheetHeight'),'restore the selected detent, not just the height');
 const Click=vm.runInNewContext(transpile('class Click {'+['openRelated','resultSheetDisappeared','resultSheetAppeared'].map(n=>method(shared,n)).join('\n')+'} Click;'),{SheetSize:{LARGE:'large'},PinmonyRuntimeLog:{info(){}}});
 const click=new Click();let dispatches=0;Object.assign(click,{alive:true,presentationActive:true,relatedOpening:false,result:{loading:false},uploadedPhoto:true,sheetVisible:true,onRelated:()=>dispatches++});click.openRelated({id:'one'});assert.equal(dispatches,1,'open immediately without waiting for Sheet disappearance');assert.equal(click.sheetVisible,false);click.resultSheetDisappeared();assert.equal(dispatches,1,'late disappearance cannot open a duplicate detail');click.openRelated({id:'two'});assert.equal(dispatches,1,'duplicate tap is ignored');
 Object.assign(click,{relatedOpening:true,resumeRelatedSheet:true,sheetVisible:true,presentationActive:true,sheetAppearing:true});click.resultSheetAppeared();assert.equal(click.relatedOpening,false);assert.equal(click.resumeRelatedSheet,false);click.openRelated({id:'two'});assert.equal(dispatches,2,'visible restored Sheet can open another Pin even if opening lock remained');
 click.presentationActive=false;click.sheetVisible=false;click.resultSheetAppeared();assert.equal(click.relatedOpening,true,'late appear cannot unlock hidden detail visit');
 assert(index.includes("if (this.homeEntryCardId.startsWith('pinmony-photo-result-')) { this.homeEntryClosing = true; return; }"),'exit animates without waiting on hidden Sheet coordinates');
 console.log('Photo history save: captured multipart contract, business validation, single write, failure feedback and retained Pin return passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
