const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const {createArktsLoader} = require('./arkts-module-loader.cjs');
const flush = () => new Promise(resolve => setImmediate(resolve));
function fixture() {
  const files = new Map(), records = [], downloads = [], notices = [], removed = [];
  const context = {cacheDir:'/cache'};
  let read = async () => ({data:new Uint8Array([255,216,255,0,1]).buffer,extension:'jpg'});
  let failShow = false, failWrite = false, onShow = () => {};
  const mocks = {
    '@kit.MediaLibraryKit':{},'@kit.BasicServicesKit':{},'@kit.ImageKit':{},
    '@kit.ArkWeb':{webview:{WebDownloadDelegate:class {}}},
    '@kit.ArkData':{uniformTypeDescriptor:{UniformDataType:{IMAGE:'image'},
      getUniformDataTypeByFilenameExtension:(extension,type)=>{assert.equal(type,'image');return extension==='.'+'jpg'?'image/jpeg':'';}}},
    '@kit.ShareKit':{systemShare:{SharedData:class {constructor(record){Object.assign(this,record);this.items=[record];}addRecord(record){this.items.push(record);}},
      SelectionMode:{SINGLE:0,BATCH:1},SharePreviewMode:{DETAIL:1},ShareController:class {
        constructor(record){this.record=record;}
        async show(ctx,options){assert.equal(ctx,context);assert.equal(options.previewMode,1);
          if(failShow)throw Error('show');
          for(const item of this.record.items)assert(files.has(item.uri.slice(7)),'all files exist when handed to system');this.record.selectionMode=options.selectionMode;records.push(this.record);onShow();}
      }}},
    '@kit.CoreFileKit':{fileUri:{getUriFromPath:path=>'file://'+path},fileIo:{
      OpenMode:{CREATE:1,READ_WRITE:2,TRUNC:4},access:async path=>path==='/cache/pinmony-shared-images'||files.has(path),mkdir:async()=>{},
      listFile:async()=>Array.from(files.keys()).map(path=>path.split('/').pop()),
      open:async path=>{files.set(path,0);return {fd:path};},close:async()=>{},
      write:async(path,bytes)=>{if(failWrite)throw Error('write');const size=Math.min(2,bytes.byteLength);files.set(path,files.get(path)+size);return size;},
      unlink:async path=>{removed.push(path);files.delete(path);}
    }},
    common_network:{acceptsImageDownloadUrl:url=>/^https:\/\/i\.pinimg\.com\//.test(url),
      PinmonyImageDownload:class {constructor(){downloads.push(this);}read(...args){return read(...args);}cancel(){this.cancelled=true;}}},
    common_foundation:{PinmonyRuntimeLog:{info(){},warn(){}}}
  };
  const Type=createArktsLoader(ts,mocks).loadFile('entry/src/main/ets/app/PinmonySystemActions.ets').PinmonySystemActions;
  return {actions:new Type(()=>context,value=>notices.push(value)),files,records,downloads,removed,notices,
    setRead:fn=>read=fn,setOnShow:fn=>onShow=fn,failShow:()=>failShow=true,failWrite:()=>failWrite=true};
}
async function main() {
  const image='https://i.pinimg.com/originals/synthetic.jpg';
  const f=fixture();f.files.set('/cache/pinmony-shared-images/pin-1000000000000-1.jpg',1);
  f.files.set('/cache/pinmony-shared-images/unrelated.jpg',1);
  await f.actions.shareImage(image,'Original title',()=>true);
  assert.equal(f.records.length,1);assert.equal(f.records[0].utd,'image/jpeg');
  assert.equal(f.records[0].selectionMode,0,'single image retains single selection');
  assert.equal(f.records[0].content,undefined,'share payload is a file, not a hyperlink');
  assert.equal(f.records[0].thumbnailUri,f.records[0].uri,'image preview uses the actual file URI');
  assert.equal(f.records[0].title,'Original title');assert.equal(f.files.get(f.records[0].uri.slice(7)),5,'partial writes complete');
  assert(f.files.has(f.records[0].uri.slice(7)),'published file remains for the receiving app');
  assert(f.files.has('/cache/pinmony-shared-images/unrelated.jpg'),'cleanup excludes unrelated files');
  assert.equal(f.removed.length,1,'only expired image share cache is removed');
  await assert.rejects(f.actions.shareImage('https://evil.test/image.jpg','',()=>true));
  for(const mode of ['download','write','show']) {
    const failure=fixture();
    if(mode==='download')failure.setRead(async()=>{throw Error('network');});
    if(mode==='write')failure.failWrite();
    if(mode==='show')failure.failShow();
    await assert.rejects(failure.actions.shareImage(image,'',()=>true));
    assert.equal(failure.records.length,0);assert.equal(failure.files.size,0,'failed unpublished file is removed');
    assert.equal(failure.actions.imageShareBusy,false,'failure permits retry');
  }
  let finish;const stale=fixture();stale.setRead(()=>new Promise(resolve=>finish=resolve));
  const waiting=stale.actions.shareImage(image,'',()=>true);await flush();
  await stale.actions.shareImage(image,'',()=>true);assert.equal(stale.records.length,0,'duplicate is suppressed');
  stale.actions.dispose();finish({data:new ArrayBuffer(5),extension:'jpg'});await waiting;
  assert.equal(stale.records.length,0);assert.equal(stale.files.size,0);assert(stale.downloads[1].cancelled);
  let finishRoute, live=true;
  const route=fixture();route.setRead(()=>new Promise(resolve=>finishRoute=resolve));
  const routePending=route.actions.shareImage(image,'',()=>live);await flush();live=false;
  finishRoute({data:new ArrayBuffer(5),extension:'jpg'});await routePending;
  assert.equal(route.records.length,0,'changed Pin or account cannot open a late panel');
  assert.equal(route.files.size,0,'obsolete download does not create a share file');
  const second=image+'?second';
  const multi=fixture(), order=[];
  multi.setRead(async source=>{order.push(source);return {data:new ArrayBuffer(5),extension:'jpg'};});
  await multi.actions.shareImages([image,second],'Album',()=>true);
  assert.deepEqual(order,[image,second]);assert.equal(multi.records.length,1,'one panel contains all photos');
  assert.equal(multi.records[0].selectionMode,1,'multi-photo share must use batch mode instead of choosing one record');
  assert.equal(multi.records[0].items.length,2);assert.notEqual(multi.records[0].items[0].uri,multi.records[0].items[1].uri);
  for(const item of multi.records[0].items){assert.equal(item.content,undefined);assert.equal(item.thumbnailUri,item.uri);assert(multi.files.has(item.uri.slice(7)));}
  const initialUris=multi.records[0].items.map(item=>item.uri);
  const loadingCount=multi.notices.length;
  await multi.actions.shareImages([image,second],'New title',()=>true);
  assert.deepEqual(order,[image,second],'reopening reuses all published images without downloading');
  assert.equal(multi.notices.length,loadingCount,'cache-only shares do not show loading');
  assert.deepEqual(multi.records[1].items.map(item=>item.uri),initialUris);
  assert.equal(multi.records[1].items[0].title,'New title','cached file does not cache presentation text');
  multi.files.delete(initialUris[1].slice(7));
  await multi.actions.shareImages([second,image],'',()=>true);
  assert.deepEqual(order,[image,second,second],'only evicted image is downloaded again');
  assert.equal(multi.records[2].items[1].uri,initialUris[0],'reordered album retains source identity');
  multi.failShow();
  await assert.rejects(multi.actions.shareImages([image],'',()=>true));
  assert(multi.files.has(initialUris[0].slice(7)),'failed reopening must preserve already published files');
  const mixed=fixture();
  await mixed.actions.shareImages([image],'',()=>true);
  const published=mixed.records[0].uri.slice(7);
  mixed.setRead(async()=>{throw Error('offline');});
  await assert.rejects(mixed.actions.shareImages([image,second],'',()=>true));
  assert(mixed.files.has(published),'partial cache failure retains the earlier published image');
  await mixed.actions.shareImages([image],'',()=>true);
  assert.equal(mixed.records.length,2,'cached image remains shareable while offline');
  const scoped=fixture();let scopedReads=0;
  scoped.setRead(async()=>{scopedReads++;return {data:new ArrayBuffer(5),extension:'jpg'};});
  await scoped.actions.shareImages([image],'',()=>true,'session-1');
  await scoped.actions.shareImages([image],'',()=>true,'session-1');
  assert.equal(scopedReads,1);
  await scoped.actions.shareImages([image],'',()=>true,'session-2');
  assert.equal(scopedReads,2,'account/session scope changes invalidate the index');
  scoped.actions.dispose();scoped.actions.activate();
  await scoped.actions.shareImages([image],'',()=>true,'session-2');
  assert.equal(scopedReads,3,'disposal clears the session index');
  const expired=fixture();let expiryReads=0;
  expired.setRead(async()=>{expiryReads++;return {data:new ArrayBuffer(5),extension:'jpg'};});
  await expired.actions.shareImages([image],'',()=>true);
  expired.actions.sharedImageFiles.get(image).createdAt-=86400001;
  await expired.actions.shareImages([image],'',()=>true);
  assert.equal(expiryReads,2,'expired cache downloads again');
  const background=fixture();let foreground=true, backgroundReads=0;
  background.setRead(async()=>{backgroundReads++;return {data:new ArrayBuffer(5),extension:'jpg'};});
  background.setOnShow(()=>{foreground=false;});
  await background.actions.shareImages([image],'',()=>foreground,'session');
  foreground=true;
  await background.actions.shareImages([image],'',()=>foreground,'session');
  assert.equal(backgroundReads,1,'system panel backgrounding after presentation retains prepared files');
  for(const mode of ['later-download','show','cancel','size']){
    const batch=fixture();let reads=0,valid=true;
    batch.setRead(async()=>{reads++;if(reads===2){if(mode==='later-download')throw Error('second');if(mode==='cancel')valid=false;}
      return {data:new ArrayBuffer(mode==='size'&&reads===2?32*1024*1024:5),extension:'jpg'};});
    if(mode==='show')batch.failShow();
    if(mode==='cancel')await batch.actions.shareImages([image,second],'',()=>valid);
    else await assert.rejects(batch.actions.shareImages([image,second],'',()=>true));
    assert.equal(batch.records.length,0);assert.equal(batch.files.size,0,'whole unpublished batch is cleaned after '+mode);
    assert.equal(batch.actions.imageShareBusy,false);
  }
  await assert.rejects(multi.actions.shareImages([],'',()=>true));
  await assert.rejects(multi.actions.shareImages(Array(101).fill(image),'',()=>true));
  await assert.rejects(multi.actions.shareImages([image,'https://evil.test/image.jpg'],'',()=>true));
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  const start=index.indexOf('  private async shareDetailPinAfterMenu(');
  const end=index.indexOf('\n  private ',start+1);
  const Host=vm.runInNewContext(ts.transpileModule('class Host {'+index.slice(start,end)+'} Host;',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
    {PinmonyRuntimeLog:{info(){}},PinmonyI18n:{message:value=>value},setTimeout,clearTimeout});
  for(const kind of ['photo','video','carousel','collage','loaded-collage','card-menu','root-card-share','board-card-share','card-missing-image','card-video','card-carousel','contacts','account-during-close','epoch-during-close','account-during-download','card-route-during-download','card-account-during-download','card-token-during-download']) {
    const host=new Host(), calls=[];
    let account='synthetic-account', route='synthetic-route';
    const collage=kind==='collage' || kind==='loaded-collage';
    const expectedImage=collage?'https://i.pinimg.com/originals/synthetic-collage.jpg':image;
    const pin='https://www.pinterest.com/pin/1/';
    Object.assign(host,{authStatus:'authenticated',authEpoch:1,businessSuspended:false,activeSheetKind:'share',
      homeStore:{customHomeMenuToken:0},pinStore:{sharePin:pin,detail:{pinUrl:pin,title:'Title',imageUrl:image,originalImageUrl:expectedImage,
        isVideo:kind==='video',carousel:kind==='carousel'?{items:[{imageUrl:image},{imageUrl:image+'?second'}]}:undefined,shuffleId:collage?'2':undefined,
        shuffle:kind==='loaded-collage'?{id:'2',items:[{imageUrl:'https://i.pinimg.com/synthetic-cutout.png'}]}:undefined}},
      nativeBusinessSessionContext:()=>({generation:1,accountId:account}),nativeDisplayAddress:()=>route,currentPinUrl:()=>pin,
      pinMenuNative:{shareImageSources:()=>['card-missing-image','card-video'].includes(kind)?[]:kind==='card-carousel'?[image,image+'?second']:[expectedImage],
        shareLinkOnly:()=>kind==='card-video'},
      pinIdentity:()=> '1',
      getUIContext:()=>({postFrameCallback:callback=>callback.onIdle()}),
      dismissShareSheet(){this.activeSheetKind='';},
      sharePinUrl:async()=>calls.push('link'),
      systemActions:{shareImages:async(sources,title,current,scope)=>{assert.equal(scope,'1:1','all image share entries pass authentication and business session scope');assert.deepEqual(Array.from(sources),['carousel','card-carousel'].includes(kind)?[image,image+'?second']:[expectedImage],'all photos share in order; collage uses full composition');assert(current());
        if(kind==='account-during-download'){account='changed';assert.equal(current(),false);return;}
        if(kind==='card-route-during-download'){route='changed';assert.equal(current(),false);return;}
        if(kind==='card-account-during-download'){account='changed';assert.equal(current(),false);return;}
        if(kind==='card-token-during-download'){host.homeStore.customHomeMenuToken++;assert.equal(current(),false);return;}
        calls.push('image');}},
      isCurrentMorePin:()=>true,shareNativeFlow:{open:async()=>calls.push('contacts')},showMessage(){calls.push('error');}});
    let visible=true;Object.defineProperty(host,'showNativeSheet',{get:()=>visible,set(value){visible=value;if(!value)queueMicrotask(()=>{
      if(kind==='account-during-close')account='changed';
      if(kind==='epoch-during-close')host.authEpoch++;
      host.detailSystemShareClosed?.();
    });}});
    if(kind==='card-menu') {
      host.activeSheetKind='more';
      host.dismissMoreSheet=function(){this.activeSheetKind='';};
    }
    if(kind==='root-card-share') host.currentPinUrl=()=>'';
    const card=kind==='board-card-share' || kind.startsWith('card-') && kind!=='card-menu';
    if(card) {host.pinStore.detail=undefined;host.dismissShareSheet=function(){this.activeSheetKind='';this.homeStore.customHomeMenuToken++;};}
    await host.shareDetailPinAfterMenu(pin,card?'https://www.pinterest.com/synthetic/board/':'',kind!=='card-menu',kind==='contacts');
    assert.deepEqual(calls,kind.includes('-during-')?[]:[kind==='card-missing-image'?'error':['video','card-video'].includes(kind)?'link':kind==='contacts'?'contacts':'image'],kind);
  }
  console.log('Image system share: ordered multi-photo payloads, complete batch cleanup, limits, preview, partial writes, cache lifetime, cancellation, single-photo/full-collage routing and unchanged contacts/video passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
