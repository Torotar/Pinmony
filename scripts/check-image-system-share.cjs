const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const {createArktsLoader} = require('./arkts-module-loader.cjs');
const flush = () => new Promise(resolve => setImmediate(resolve));
function fixture() {
  const files = new Map(), records = [], downloads = [], notices = [], removed = [], logs = [], controllers = [];
  const context = {cacheDir:'/cache'};
  let read = async () => ({data:new Uint8Array([255,216,255,0,1]).buffer,extension:'jpg'});
  let videoReads=0,releases=0;
  let videoRead=async()=>{videoReads++;files.set('/transport-video',12);return {fd:'/transport-video',size:12,release(){releases++;files.delete('/transport-video');}};};
  let failShow = false, failWrite = false, onShow = () => {};
  let loadingVisible=false,loadingStarts=0,loadingCloses=0;
  const mocks = {
    '@kit.MediaLibraryKit':{},'@kit.BasicServicesKit':{},'@kit.ImageKit':{},
    '@kit.ArkWeb':{webview:{WebDownloadDelegate:class {}}},
    '@kit.ArkData':{uniformTypeDescriptor:{UniformDataType:{IMAGE:'image',VIDEO:'video'},
      getUniformDataTypeByFilenameExtension:(extension,type)=>{if(extension==='.mp4'){assert.equal(type,'video');return 'video/mp4';}assert.equal(type,'image');return extension==='.'+'jpg'?'image/jpeg':'';}}},
    '@kit.ShareKit':{systemShare:{SharedData:class {constructor(record){Object.assign(this,record);this.items=[record];}addRecord(record){this.items.push(record);}},
      SelectionMode:{SINGLE:0,BATCH:1},SharePreviewMode:{DETAIL:1},ShareAbilityName:{HARMONYSHARE:'SystemShare_HarmonyShare'},ShareController:class {
        constructor(record){this.record=record;this.events=new Map();controllers.push(this);}
        on(event,callback){this.events.set(event,callback);}
        off(event){this.events.delete(event);}
        async show(ctx,options){assert.equal(ctx,context);assert.equal(options.previewMode,1);
          if(failShow)throw Error('show');
          for(const item of this.record.items)assert(files.has(item.uri.slice(7)),'all files exist when handed to system');this.record.selectionMode=options.selectionMode;records.push(this.record);onShow();}
      }}},
    '@kit.CoreFileKit':{fileUri:{getUriFromPath:path=>'file://'+path},fileIo:{
      OpenMode:{CREATE:1,READ_WRITE:2,TRUNC:4},access:async path=>path==='/cache/pinmony-shared-images'||files.has(path),mkdir:async()=>{},
      stat:async path=>{if(!files.has(path))throw Error('missing');return {size:files.get(path)};},
      listFile:async()=>Array.from(files.keys()).map(path=>path.split('/').pop()),
      open:async path=>{files.set(path,0);return {fd:path};},close:async()=>{},
      write:async(path,bytes)=>{if(failWrite)throw Error('write');const size=Math.min(2,bytes.byteLength);files.set(path,files.get(path)+size);return size;},
      unlink:async path=>{removed.push(path);files.delete(path);}
      ,copyFile:async(fd,path)=>{if(failWrite)throw Error('copy');files.set(path,files.get(fd));}
    }},
    common_network:{acceptsImageDownloadUrl:url=>/^https:\/\/i\.pinimg\.com\//.test(url),
      acceptsMediaFileUrl:url=>/^https:\/\/v1\.pinimg\.com\/videos\/[^?#]+\.mp4$/.test(url),
      PinmonyMediaFile:class{read(...args){return videoRead(...args);}cancel(){this.cancelled=true;}},
      PinmonyImageDownload:class {constructor(){downloads.push(this);}read(...args){return read(...args);}cancel(){this.cancelled=true;}}},
    common_foundation:{PinmonyRuntimeLog:{info:line=>logs.push(line),warn:line=>logs.push(line)}}
  };
  const module=createArktsLoader(ts,mocks).loadFile('entry/src/main/ets/app/PinmonySystemActions.ets'),Type=module.PinmonySystemActions;
  return {actions:new Type(()=>context,value=>notices.push(value),()=>{loadingVisible=true;loadingStarts++;notices.push('loading');let closed=false;return ()=>{if(closed)return;closed=true;loadingVisible=false;loadingCloses++;};}),loadingVisible:()=>loadingVisible,loadingStarts:()=>loadingStarts,loadingCloses:()=>loadingCloses,preparationError:module.PinmonyMediaSharePreparationError,files,records,downloads,removed,notices,logs,controllers,
    videoReads:()=>videoReads,releases:()=>releases,setVideoRead:fn=>videoRead=fn,
    setRead:fn=>read=fn,setOnShow:fn=>onShow=fn,failShow:()=>failShow=true,failWrite:()=>failWrite=true};
}
async function main() {
  const image='https://i.pinimg.com/originals/synthetic.jpg';
  const video='https://v1.pinimg.com/videos/synthetic.mp4';
  const media=fixture();await media.actions.shareMedia([video,image],'Video',()=>true,'session');
  assert.equal(media.loadingVisible(),false);assert.equal(media.loadingCloses(),1);
  assert.equal(media.records[0].selectionMode,1);assert.equal(media.records[0].items[0].utd,'video/mp4');
  assert.equal(media.records[0].items[0].thumbnailUri,undefined,'video preview is delegated to the system');
  assert.equal(media.releases(),1,'transport lease is released after copying');
  assert(media.files.has(media.records[0].items[0].uri.slice(7)),'published video remains available');
  await media.actions.shareMedia([video],'Again',()=>true,'session');assert.equal(media.videoReads(),1,'video file cache is reused');
  assert.equal(media.loadingStarts(),1,'cache hit never opens a loading notice');
  assert.equal(media.records[1].selectionMode,0);
  await media.actions.shareMedia([video],'New session',()=>true,'other');assert.equal(media.videoReads(),2);
  const failedVideo=fixture();failedVideo.failWrite();await assert.rejects(failedVideo.actions.shareMedia([video],'Title',()=>true),failedVideo.preparationError);
  const failedPanel=fixture();failedPanel.failShow();await assert.rejects(failedPanel.actions.shareMedia([video],'Title',()=>true),error=>!(error instanceof failedPanel.preparationError));
  assert.equal(failedVideo.records.length,0);assert.equal(failedVideo.files.size,0);assert.equal(failedVideo.releases(),1);
  assert.equal(failedVideo.loadingVisible(),false);assert.equal(failedPanel.loadingVisible(),false);
  const partialMedia=fixture();partialMedia.setVideoRead(async()=>{throw Error('offline');});
  await assert.rejects(partialMedia.actions.shareMedia([image,video],'Title',()=>true));
  assert.equal(partialMedia.records.length,0);assert.equal(partialMedia.files.size,0,'mixed batch never publishes partial content');
  const invalidVideo=fixture();await assert.rejects(invalidVideo.actions.shareMedia(['https://evil.test/video.mp4'],'Title',()=>true));
  await assert.rejects(invalidVideo.actions.shareMedia(['https://v1.pinimg.com/videos/stream.m3u8'],'Title',()=>true));
  const cancelledVideo=fixture();let currentVideo=true,releaseVideo;
  cancelledVideo.setVideoRead(()=>new Promise(resolve=>{releaseVideo=resolve;}));
  const pendingVideo=cancelledVideo.actions.shareMedia([video],'Title',()=>currentVideo);
  while(!releaseVideo)await flush();
  assert.equal(cancelledVideo.loadingVisible(),true,'loading stays visible while the file is preparing');
  currentVideo=false;let releasedVideo=false;
  releaseVideo({fd:'unused',size:12,release(){releasedVideo=true;}});await pendingVideo;
  assert(releasedVideo);assert.equal(cancelledVideo.records.length,0);assert.equal(cancelledVideo.files.size,0);
  assert.equal(cancelledVideo.loadingVisible(),false,'stale request closes its notice');
  const oversizedVideo=fixture();let oversizedReleased=false;
  oversizedVideo.setVideoRead(async()=>({fd:'unused',size:32*1024*1024+1,release(){oversizedReleased=true;}}));
  await assert.rejects(oversizedVideo.actions.shareMedia([video],'Title',()=>true));
  assert(oversizedReleased);assert.equal(oversizedVideo.records.length,0);
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
  assert(f.logs.some(line=>line.includes('phase=panel-presented')));
  f.controllers[0].events.get('shareCompleted')({targetAbilityInfo:{name:'SystemShare_HarmonyShare'}});
  assert(f.logs.some(line=>line.includes('phase=target-returned harmonyShare=true')));
  assert.equal(f.actions.imageShareControllers.size,1,'controller retained through system handoff');
  f.controllers[0].events.get('dismiss')();
  assert.equal(f.actions.imageShareControllers.size,0,'dismiss releases controller and callbacks');
  assert.equal(f.controllers[0].events.size,0);
  assert(!f.logs.some(line=>line.includes('https://')||line.includes('/cache/')||line.includes('Original title')),'diagnostics contain no content or paths');
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
  stale.actions.dispose();assert.equal(stale.loadingVisible(),false,'host disposal closes loading before download finishes');finish({data:new ArrayBuffer(5),extension:'jpg'});await waiting;
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
  const corrupt=fixture();let corruptReads=0;
  corrupt.setRead(async()=>{corruptReads++;return {data:new ArrayBuffer(5),extension:'jpg'};});
  await corrupt.actions.shareImages([image],'',()=>true);
  corrupt.files.set(corrupt.records[0].uri.slice(7),0);
  await corrupt.actions.shareImages([image],'',()=>true);
  assert.equal(corruptReads,2,'truncated cache is redownloaded rather than handed to Huawei Share');
  assert.equal(corrupt.files.get(corrupt.records[1].uri.slice(7)),5);
  corrupt.actions.dispose();
  assert.equal(corrupt.actions.imageShareControllers.size,0,'disposal releases all retained controllers');
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
  const lifecycle=require('./snackbar-lifecycle-harness.cjs').loadSnackBarLifecycle(ts,{warn(){}});
  const helperNames=['showSystemShareLoading','syncSystemShareLoading','refreshSystemShareLoadingLanguage'];
  const helperCode=helperNames.map(name=>{const from=index.indexOf('  private '+name+'('),to=index.indexOf('\n  private ',from+1);assert(from>=0);return index.slice(from,to);}).join('\n');
  const NoticeHost=vm.runInNewContext(ts.transpileModule('class Host {'+helperCode+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
    {PinmonySnackBarLifecycle:lifecycle,$r:key=>key,SnackBarIconType:{NORMAL:1},SnackBarOperationType:{CLOSE_BUTTON_ONLY:1}});
  const notice=new NoticeHost(),titles=[];let noticeCloses=0;
  Object.assign(notice,{postSnackToken:0,systemShareLoadingToken:0,uiLanguage:'zh',uiText(key){return this.uiLanguage+':'+key;},
    preparePostSnack(duration){assert.equal(duration,Infinity);this.postSnackToken++;this.postSnack={show(_icon,message,_operation,style){assert.equal(style.duration,0);titles.push(message.title);},dismiss(){noticeCloses++;}};},
    isCurrentPostSnack(token){return token===this.postSnackToken&&!!this.postSnack;},
    dismissPostSnack(){lifecycle.dismiss(this.postSnack);this.postSnack=undefined;this.postSnackToken++;},handlePostSnackClose(){},handlePostSnackBack(){}});
  const finishNotice=notice.showSystemShareLoading();
  notice.uiLanguage='en';notice.refreshSystemShareLoadingLanguage();notice.uiLanguage='zh';notice.refreshSystemShareLoadingLanguage();
  assert.equal(titles.length,3);assert.equal(titles[0],titles[2]);assert.notEqual(titles[0],titles[1]);
  finishNotice();const closedCount=noticeCloses;finishNotice();assert.equal(noticeCloses,closedCount,'completion closes its notice once');
  const staleFinish=notice.showSystemShareLoading();notice.preparePostSnack( Infinity );const replacement=notice.postSnack;
  lifecycle.show(replacement,{},{},{},{duration:4000});const replacementCount=noticeCloses;
  staleFinish();assert.equal(noticeCloses,replacementCount,'old share completion cannot close a newer notice');
  const supersededFinish=notice.showSystemShareLoading();lifecycle.show({show(){},dismiss(){}},{},{},{},{duration:4000});
  const titleCount=titles.length;notice.uiLanguage='en';notice.refreshSystemShareLoadingLanguage();assert.equal(titles.length,titleCount,'language refresh cannot revive a superseded loading notice');supersededFinish();
  const start=index.indexOf('  private async shareDetailPinAfterMenu(');
  const end=index.indexOf('\n  private ',start+1);
  const Host=vm.runInNewContext(ts.transpileModule('class Host {'+index.slice(start,end)+'} Host;',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
    {PinmonyMediaSharePreparationError:media.preparationError,PinmonyRuntimeLog:{info(){}},PinmonyI18n:{message:value=>value},setTimeout,clearTimeout});
  for(const kind of ['photo','video','video-hls','video-prepare-failed','video-copy-failed','video-panel-failed','video-stale-failed','mixed','carousel','collage','loaded-collage','card-menu','root-card-share','board-card-share','card-missing-image','card-video','card-carousel','contacts','account-during-close','epoch-during-close','account-during-download','card-route-during-download','card-account-during-download','card-token-during-download']) {
    const host=new Host(), calls=[];
    let account='synthetic-account', route='synthetic-route';
    const collage=kind==='collage' || kind==='loaded-collage';
    const expectedImage=collage?'https://i.pinimg.com/originals/synthetic-collage.jpg':image;
    const pin='https://www.pinterest.com/pin/1/';
    Object.assign(host,{authStatus:'authenticated',authEpoch:1,businessSuspended:false,activeSheetKind:'share',
      homeStore:{customHomeMenuToken:0},pinStore:{sharePin:pin,detail:{pinUrl:pin,title:'Title',imageUrl:image,originalImageUrl:expectedImage,
        isVideo:kind.startsWith('video'),video:kind.startsWith('video')?{sources:[{kind:kind==='video-hls'?'hls':'mp4',url:video}]}:undefined,carousel:kind==='mixed'?{items:[{video:{sources:[{kind:'mp4',url:video}]}},{imageUrl:image}]}:kind==='carousel'?{items:[{imageUrl:image},{imageUrl:image+'?second'}]}:undefined,shuffleId:collage?'2':undefined,
        shuffle:kind==='loaded-collage'?{id:'2',items:[{imageUrl:'https://i.pinimg.com/synthetic-cutout.png'}]}:undefined}},
      nativeBusinessSessionContext:()=>({generation:1,accountId:account}),nativeDisplayAddress:()=>route,currentPinUrl:()=>pin,
      pinMenuNative:{shareImageSources:()=>['card-missing-image','card-video'].includes(kind)?[]:kind==='card-carousel'?[image,image+'?second']:[expectedImage],
        shareMediaSources:()=>kind==='card-video'?[video]:[],
        shareLinkOnly:()=>kind==='card-video'},
      pinIdentity:()=> '1',
      getUIContext:()=>({postFrameCallback:callback=>callback.onIdle()}),
      dismissShareSheet(){this.activeSheetKind='';},
      sharePinUrl:async()=>calls.push('link'),
      systemActions:{copyText:async(value)=>{assert.equal(value,pin,'fallback copies Pin link, never CDN URL');if(kind==='video-copy-failed')throw Error('clipboard');calls.push('copy');},shareMedia:async(sources,title,current,scope)=>{assert.deepEqual(Array.from(sources),kind==='mixed'?[video,image]:[video]);assert(current());assert.equal(scope,'1:1');if(kind==='video-panel-failed')throw Error('panel');if(kind==='video-stale-failed')account='changed';if(kind.endsWith('-failed'))throw new media.preparationError('download');calls.push('video');},shareImages:async(sources,title,current,scope)=>{assert.equal(scope,'1:1','all image share entries pass authentication and business session scope');assert.deepEqual(Array.from(sources),['carousel','card-carousel'].includes(kind)?[image,image+'?second']:[expectedImage],'all photos share in order; collage uses full composition');assert(current());
        if(kind==='account-during-download'){account='changed';assert.equal(current(),false);return;}
        if(kind==='card-route-during-download'){route='changed';assert.equal(current(),false);return;}
        if(kind==='card-account-during-download'){account='changed';assert.equal(current(),false);return;}
        if(kind==='card-token-during-download'){host.homeStore.customHomeMenuToken++;assert.equal(current(),false);return;}
        calls.push('image');}},
      isCurrentMorePin:()=>true,shareNativeFlow:{open:async()=>calls.push('contacts')},showMessage(message){calls.push(message==='pm_video_share_prepare_failed_link_copied'?'copied-feedback':message==='pm_video_share_prepare_failed_copy_failed'?'copy-failed-feedback':'error');}});
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
    assert.deepEqual(calls,kind.includes('-during-')||kind==='video-stale-failed'?[]:['video-hls','video-prepare-failed'].includes(kind)?['copy','copied-feedback']:kind==='video-copy-failed'?['copy-failed-feedback']:[['card-missing-image','video-panel-failed'].includes(kind)?'error':['video','card-video','mixed'].includes(kind)?'video':kind==='contacts'?'contacts':'image'],kind);
  }
  console.log('Media system share: photo/video/mixed files, complete batch cleanup, limits, previews, cache lifetime, cancellation, HLS rejection, collage routing and unchanged contacts passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
