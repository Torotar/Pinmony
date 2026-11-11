const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const sheet=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyMoreSheet.ets','utf8');
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function compile(body,globals={}) {return vm.runInNewContext(ts.transpileModule('class Host {'+body+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,globals);}
const Title=compile(sheet.slice(sheet.indexOf('  private titleOptions()'),sheet.indexOf('  build()')),
 {$r:x=>x,SymbolGlyphModifier:class{fontColor(){return this;}},BlurStrategy:{ENABLE:1,DISABLE:0},ScrollEffectType:{IMMERSIVE_GRADIENT_BLUR:2},IconStyleMode:{SMALL:1},Color:{Transparent:'transparent'},PinmonyImmersiveLight:{effect:mode=>mode==='off'?undefined:{mode}}});
for(const mode of ['off','gentle','immersive','exquisite'])for(const language of ['zh','en']){
 let closed=0;const h=new Title();Object.assign(h,{immersiveLightMode:mode,uiText:key=>language+':'+key,onClose(){closed++;}});
 const o=h.titleOptions();assert.equal(o.enableComponentSafeArea,true);assert.equal(o.avoidLayoutSafeArea,false);
 assert.equal(o.style.scrollEffectOpts.enableScrollEffect,mode!=='off');assert.equal(o.style.scrollEffectOpts.scrollEffectType,2);
 assert.equal(o.style.scrollEffectStyle.backgroundStyle.blurRadius,mode==='off'?0:18);
 assert.equal(o.style.blurStrategy,mode==='off'?0:1);assert.equal(o.content.title.mainTitle,language+':pm_options_bb7486f4');
 o.content.menu.value[0].content.action();assert.equal(closed,1);
}
assert(sheet.includes('Scroll(this.menuScroller)')&&sheet.includes('.bindToScrollable([this.menuScroller])'));
assert(sheet.includes('.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })')&&sheet.includes('.clip(false)'));
assert.equal((sheet.match(/Scroll\(/g)||[]).length,1,'loading, empty, error and menu share the same scroll scope');
assert(sheet.includes('.titleMode(HdsNavigationTitleMode.MODAL)'));
const Measurement=compile(sheet.slice(sheet.indexOf('  private bodyHeight()'),sheet.indexOf("  @StorageLink('pinmonyLanguage')")));
const measured=new Measurement();measured.menuContentHeight=92;
for(const [content,expected] of [[180,180],[420,420],[850,520],[92,92],[20,20]]){
 measured.updateContentHeight({height:content});assert.equal(measured.bodyHeight(),expected,'grows and shrinks with actual menu content');
}
measured.updateContentHeight({height:NaN});assert.equal(measured.bodyHeight(),20,'invalid measurements cannot break layout');
assert(sheet.includes('.height(this.bodyHeight() + 64)')&&sheet.includes('.height(this.bodyHeight())'));
assert(sheet.includes('this.updateContentHeight(current)'),'measure the intrinsic body, not the constrained HDS root');
const controller=fs.readFileSync('feature_pin/src/main/ets/controllers/PinmonySharePanelsController.ets','utf8');
const Pause=compile(controller.slice(controller.indexOf('  pause('),controller.indexOf('  private current(')),{PinmonyI18n:{message:key=>key}});
const Closing=compile(index.slice(index.indexOf('  private requestMoreSheetClose()'),index.indexOf('  private async openApiDetailMore()')));
const close=new Closing(),store={moreLoading:true,moreError:'',moreOptions:[{id:'detail-download',enabled:true}]};let invalidations=0,nativePauses=0;
const pause=new Pause();Object.assign(pause,{store,generation:1,searchToken:1,refreshToken:1,tasks:{invalidate(){invalidations++;}},searchTasks:{invalidate(){invalidations++;}},ports:{nativeMenu:()=>true,nativeMenuPause(){nativePauses++;},activeSheetKind:()=>close.activeSheetKind}});
Object.assign(close,{activeSheetKind:'more',showNativeSheet:true,pinStore:store,sharePanelsController:pause});const before=JSON.stringify(store.moreOptions);
close.requestMoreSheetClose();assert.equal(close.showNativeSheet,false);assert.equal(close.activeSheetKind,'more');assert.equal(store.moreLoading,true);assert.equal(store.moreError,'');assert.equal(JSON.stringify(store.moreOptions),before);assert.equal(nativePauses,1);assert.equal(invalidations,2);
close.requestMoreSheetClose();assert.equal(nativePauses,1,'repeated close cannot recancel or clear content');
pause.pause();assert.equal(store.moreLoading,false);assert(store.moreError,'background pause still offers retry');
assert(index.includes("if (!this.showNativeSheet && this.activeSheetKind === 'more') this.dismissMoreSheet();"));
assert(index.includes('onClose: () => this.requestMoreSheetClose()'));
assert(index.includes("else if (this.activeSheetKind === 'more') this.requestMoreSheetClose();"));
const reboundStart=index.indexOf('      onWillSpringBackWhenDismiss: (action: SpringBackAction)');
assert(reboundStart>index.indexOf('.bindSheet($$this.showNativeSheet'),'hook belongs to the shared native Sheet');
const reboundEnd=index.indexOf('      onWillDismiss:',reboundStart);
const rebound=compile('handle(action: SpringBackAction): void {'+index.slice(index.indexOf('{',reboundStart)+1,index.lastIndexOf('},',reboundEnd))+'}');
const handler=new rebound();let springs=0;
handler.pinStore={editResult:{busy:false,picker:{busy:false},phase:'edit'},saveResult:{busy:false}};
for(const kind of ['more','save','edit','comments','share','publish','searchFilter']){
 handler.activeSheetKind=kind;const before=springs;handler.handle({springBack(){springs++;}});
 assert.equal(springs-before,0,'ordinary dismissal bypasses the default pre-dismiss rebound');
}
handler.activeSheetKind='edit';handler.pinStore.editResult.busy=true;handler.handle({springBack(){springs++;}});assert.equal(springs,1,'blocked edit rebounds');
handler.activeSheetKind='save';handler.pinStore.saveResult.busy=true;handler.handle({springBack(){springs++;}});assert.equal(springs,2,'blocked save rebounds');
console.log('More menu: HDS mode/theme/language configuration, actual scroll binding, short-content spring, close state retention and ordinary pause passed');
