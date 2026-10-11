const assert=require('node:assert/strict'),fs=require('node:fs');
const ts=require(process.argv[2]||'typescript');
const {runtime,bind}=require('./pin-priority-controller-harness.cjs');
const pin='https://www.pinterest.com/pin/101/';
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function harness() {
 let now=0,id=0,page=pin; const timers=new Map(),calls=[],pending=[];
 const time={Date:{now:()=>now},setTimeout:(fn,ms)=>{timers.set(++id,{fn,at:now+ms});return id;},clearTimeout:id=>timers.delete(id)};
 const r=runtime(ts,time),store=new r.PinmonyPinStore();
 store.detail={kind:'state',session:1,pinUrl:pin,imageUrl:'https://i.pinimg.com/test.jpg',actions:[],related:[]};store.detailPin=pin;store.detailSession=1;store.detailActionsReady=true;store.detailOpeningToken=1;
 const native={pinStore:store,authStatus:'authenticated',authEpoch:1,businessSuspended:false,homeStore:{},profileStore:{},
  activeSheetKind:'share',showNativeSheet:true,profileShareMode:false,nativeRootOnly:false,detailReturnedToRoot:false,nativeBackTarget:'',
  detailOpenedAt:0,detailCommentsMeasured:false,detailRelatedMeasured:false,detailImageLoadedUrl:'',
  pageHistory:{key:s=>s},pinIdentity:s=>s.match(/\/pin\/(\d+)/)?.[1]||'',currentPinUrl:()=>page,
  extractPinUrl:s=>s,isCurrentMorePin:s=>s===page,externalSourceUrl:()=>'',profileUrlFromAddress:()=>'',rejectOfflineAction:()=>false,webJsonText:s=>s,
  detailJourney:{mark(){}},clearProfile(){},syncDetailImageStage(){},updateSearchPinTitle(){},updateHomePinTitle(){},restoreCachedDetail:()=>false,
  traceAction(){},showMessage:s=>calls.push(s),suspendMoreForShare(){},isCopyLinkAction:()=>false,showShareLinkSnack(){},showShareFeedbackSnack(){},
  dismissShareSheet(){native.sharePanelsController.pause();native.activeSheetKind='';store.ignoredShareSession=store.shareSession;},
  ensureDetailActionContext:async()=>true,
  controller:{getUrl:()=>page,runJavaScript:script=>{calls.push(script);return new Promise((resolve,reject)=>pending.push({resolve,reject}));}}
 };
 bind(native,ts,time);
 async function tick(ms=200){now+=ms;for(const [id,t]of [...timers])if(t.at<=now){timers.delete(id);t.fn();}await flush();}
 return {native,store,calls,pending,timers,tick,visit:s=>page=s,r};
}
async function main(){
 const h=harness(),registry=new h.r.PinmonyTaskRegistry();
 const waiting=registry.wait(5000);registry.invalidate();assert.equal(await waiting,false);assert.equal(registry.pendingCount(),0);
 const normal=registry.wait(100);await h.tick(100);assert.equal(await normal,true);
 h.store.imageLayer='search';
 const searching=h.native.searchImage?.({x:0,y:0,w:1,h:1},false,true) || h.native.detailOperationsController.searchImage({x:0,y:0,w:1,h:1},false,true);
 h.pending.shift().resolve('true');await searching;assert.equal(h.pending.length,1);
 const late=h.pending.shift();h.native.detailOperationsController.pause();late.resolve(JSON.stringify({pin,loading:false,error:'',ended:true,items:[{id:'old'}]}));await flush();
 assert.equal(h.store.visualResult.loading,false);assert.equal(h.store.visualResult.items.length,0);assert.equal(h.timers.size,0);
 const media=harness(),read=media.native.detailOperationsController.retryDetailMedia();await flush();media.pending.shift().resolve('true');await flush();
 media.pending.shift().resolve(JSON.stringify({operation:1,status:'pending'}));await flush();assert.equal(media.timers.size,1);
 media.native.detailOperationsController.pause();await read;assert.equal(media.store.detailMediaRetryBusy,false);assert.equal(media.timers.size,0);assert.equal(media.pending.length,0);
 const save=harness(),deleting=save.native.detailOperationsController.cancelDetailSave(pin);save.pending.shift().resolve(JSON.stringify({id:'802'}));await flush();
 save.pending.shift().resolve('true');await flush();save.pending.shift().resolve(JSON.stringify({status:'pending'}));await flush();
 assert.equal(save.store.viewerSaveBusy,true);save.native.detailOperationsController.pause();await deleting;
 assert.equal(save.store.viewerSaveBusy,false);assert.equal(save.timers.size,0);assert.equal(save.calls.filter(s=>s.includes('.saveUndo(')).length,1);
 const share=harness();Object.assign(share.store,{shareSession:1,sharePin:pin,shareOnPinDetail:true});
 const refresh=share.native.sharePanelsController.refreshShareSheet();await share.native.sharePanelsController.refreshShareSheet();assert.equal(share.pending.length,1);
 share.native.dismissShareSheet();share.store.shareSession=2;share.store.shareError='new panel';share.native.activeSheetKind='share';share.pending.shift().reject(Error('old failure'));await refresh;assert.equal(share.store.shareError,'new panel');
 const contact=harness();Object.assign(contact.store,{shareSession:1,sharePin:pin});
 const a=contact.native.sharePanelsController.searchShareContacts('a'),b=contact.native.sharePanelsController.searchShareContacts('b');
 await a;assert.equal(contact.pending.length,0,'typing waits before dispatch');await contact.tick(300);
 assert.equal(contact.pending.length,1,'only the latest query dispatches');
 assert(contact.calls.at(-1).includes('"b"'));contact.pending[0].resolve('true');await b;
 await contact.native.sharePanelsController.searchShareContacts('b');assert.equal(contact.pending.length,1,'same query is deduplicated');
 const cancelled=contact.native.sharePanelsController.searchShareContacts('closed');contact.native.sharePanelsController.pause();await cancelled;
 await contact.tick(300);assert.equal(contact.pending.length,1,'closing settles and cancels pending search');
 const more=harness();more.native.activeSheetKind='';const opening=more.native.sharePanelsController.openApiDetailMore();
 more.native.sharePanelsController.pause();more.native.activeSheetKind='';more.pending.shift().resolve('true');await opening;assert.equal(more.pending.length,0);assert.equal(more.store.moreOptions.length,0);
 const detail=harness();detail.native.detailReadController.updateDetail(JSON.stringify({...detail.store.detail,pinUrl:'https://www.pinterest.com/pin/202/',dataSource:'api'}));
 assert.equal(detail.timers.size,1);detail.visit(pin+'?other-document');await detail.tick(300);assert.equal(detail.pending.length,0);
 detail.visit(pin);detail.native.detailReadController.updateDetail(JSON.stringify({...detail.store.detail,dataSource:'api',actions:new Array(101).fill({id:'x',kind:'like',label:'x'})}));
 assert.equal(detail.store.detail.actions.length,0,'oversized payload cannot commit');
 detail.native.detailReadController.updateDetail(JSON.stringify({...detail.store.detail,dataSource:'api',title:'current title',actions:[{id:'like',kind:'like',label:'点赞',enabled:true}],related:[]}));
 assert.equal(detail.store.detail.title,'current title');assert.equal(detail.store.detailActionsReady,true);
 const panel=harness();panel.native.sharePanelsController.updateShareSheet(JSON.stringify({kind:'state',session:1,pinUrl:pin,pinDetail:true,
  options:[{id:'copy',label:'复制链接'}],actions:[],contacts:[{id:'contact',label:'Synthetic contact'}],searchId:'search'}));
 assert.equal(panel.store.shareContacts.length,1);assert.equal(panel.store.shareOptions.length,0);assert.equal(panel.store.shareSectionLabel,'发送给联系人');
 panel.native.sharePanelsController.updateShareSheet(JSON.stringify({kind:'opening',session:2,pinUrl:pin,pinDetail:true}));
 assert.equal(panel.timers.size,1);panel.native.sharePanelsController.pause();await panel.tick(1000);assert.equal(panel.pending.length,0);assert.equal(panel.store.shareLoading,false);
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 assert(!/private updateDetail\([^]*?JSON\.parse/.test(index.slice(index.indexOf('  private updateDetail('),index.indexOf('  private closeImageLayer('))));
 console.log('Pin priority: real Stores and Index ports, cancellable waits, visual late results, media/save cancellation without replay, stale share errors, latest query, closed more panel and detail document/bounds guards passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
