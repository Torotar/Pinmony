const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(name){const match=new RegExp('^  private (?:async )?'+name+'\\(','m').exec(source);assert(match,name);const start=match.index;const end=source.indexOf('\n  private ',start+1);return source.slice(start,end);}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('openPhotoMenuSave')+method('finishPhotoMenuSave')+method('dismissShareSheet')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){}}});
function context(){const h=new Host(),menu={pinUrl:'pin',actions:[]},events=[];Object.assign(h,{homeStore:{customHomeMenu:menu},activeSheetKind:'share',showNativeSheet:true,authStatus:'authenticated',businessSuspended:false,authEpoch:1,nativeDisplayAddress:()=> 'home',dismissShareSheet(){events.push('dismiss');this.homeStore.customHomeMenu=undefined;this.activeSheetKind='';},async openApiBoards(pin){assert.equal(this.homeStore.customHomeMenu,menu,'card permission context retained');assert.equal(this.activeSheetKind,'','old host is closed before save starts');events.push(pin);this.activeSheetKind='save';this.showNativeSheet=true;}});return {h,menu,events};}
(async()=>{
 let {h,menu,events}=context();await h.openPhotoMenuSave('pin');await h.openPhotoMenuSave('pin');
 assert.equal(h.showNativeSheet,false);assert.equal(h.activeSheetKind,'share');assert.equal(h.homeStore.customHomeMenu,menu);assert.equal(events.length,0,'do not replace builder while options Sheet remains mounted');
 await h.finishPhotoMenuSave();await h.finishPhotoMenuSave();assert.deepEqual(events,['pin']);assert.equal(h.activeSheetKind,'save');
 for(const stale of ['account','route','suspended','menu']){
  ({h,events}=context());await h.openPhotoMenuSave('pin');
  if(stale==='account')h.authEpoch++;
  if(stale==='route')h.nativeDisplayAddress=()=> 'other';
  if(stale==='suspended')h.businessSuspended=true;
  if(stale==='menu')h.homeStore.customHomeMenu={pinUrl:'new'};
  await h.finishPhotoMenuSave();assert(!events.includes('pin'),'stale '+stale+' cannot reopen save');
 }
 ({h,events}=context());await h.openPhotoMenuSave('wrong');assert.equal(h.showNativeSheet,true);assert.equal(events.length,0);
 ({h,events}=context());h.openApiBoards=async()=>{};await h.openPhotoMenuSave('pin');await h.finishPhotoMenuSave();assert.deepEqual(events,['dismiss'],'rejected opening cleans ownership context');
 ({h,events}=context());Object.assign(h,{pinIdentity:p=>p,shareNativeFlow:{async open(kind,pin,id){assert.equal(kind,'pin');assert.equal(pin,'pin');assert.equal(id,'pin');assert.equal(h.homeStore.customHomeMenu,undefined);assert.equal(h.homeStore.homeMenuPin,'pin');events.push('contacts');h.activeSheetKind='share';h.showNativeSheet=true;}}});
 await h.openPhotoMenuSave('pin',true);assert.equal(events.length,0);await h.finishPhotoMenuSave();await h.finishPhotoMenuSave();assert.deepEqual(events,['dismiss','contacts'],'card share opens existing contacts flow once after menu exit');
 assert(source.includes('shareBoardPinAfterMenu: (pin: string, page: string): Promise<void> => this.openPhotoMenuSave(pin, true)'));
 ({h,events}=context());await h.openPhotoMenuSave('pin');Object.assign(h,{sharePanelsController:{pause(){}},nativeBusinessRoutesEnabled:true,shareNativeFlow:{close(){}},pinStore:{},dismissPostSnack(){},rootContextCoordinator:{notify(){}}});
 Host.prototype.dismissShareSheet.call(h);assert.equal(h.pendingPhotoSaveMenu,undefined,'forced close cancels pending reopen');await h.finishPhotoMenuSave();assert.equal(events.length,0);
 assert(source.includes("openApiBoards: (requestedPin?: string): Promise<void> => this.openPhotoMenuSave(requestedPin || '')"));
 assert(source.includes('if (this.pendingPhotoSaveMenu) this.finishPhotoMenuSave().catch(() => {});'),'transition starts from disappearance callback');
 console.log('Card save title: options exit before HDS picker, retained ownership, duplicate requests, stale account/route/menu and rejected open passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
