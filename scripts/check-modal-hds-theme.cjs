const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const read=p=>fs.readFileSync(p,'utf8');
const modal=read('common_ui/src/main/ets/components/PinmonyModalNavigation.ets');
const methods=modal.slice(modal.indexOf('  private titleOptions('),modal.indexOf('\n  build()'));
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods+'} Host;',{}).outputText,{
  $r:name=>name,PinmonyI18n:{text:(key,lang)=>key+':'+lang},
  PinmonyImmersiveLight:{effect:mode=>mode==='off'?undefined:{mode}},
  SymbolGlyphModifier:class{fontColor(){return this;}},IconStyleMode:{SMALL:1},BlurStrategy:{DISABLE:0}
});
const h=new Host();let closed=0;h.onClose=()=>closed++;h.closeEnabled=true;
for(const mode of ['off','gentle','immersive','exquisite'])for(const lang of ['zh','en']){
 Object.assign(h,{materialMode:mode,uiLanguage:lang,titleText:'title:'+lang});
 const opts=h.titleOptions();assert.equal(opts.content.title.mainTitle,'title:'+lang);
 assert.equal(opts.style.originalStyle.backgroundStyle.backgroundColor,'app.color.page_background');
 assert.equal(opts.style.originalStyle.backgroundStyle.blurRadius,0);assert.equal(opts.style.scrollEffectOpts.enableScrollEffect,false);
 assert.equal(opts.style.systemMaterialEffect===undefined,mode==='off');
 const close=opts.content.menu.value[0].content;assert.equal(close.label,'pm_close_3fd47edc:'+lang);close.action();
}
assert.equal(closed,8);h.closeEnabled=false;const disabled=h.titleOptions().content.menu.value[0].content;assert.equal(disabled.isEnabled,false);disabled.action();assert.equal(closed,8);
assert(modal.includes('.titleMode(HdsNavigationTitleMode.MODAL)'));assert(!/Scroll\(|edgeEffect\(|customTitle/.test(modal));
assert(modal.includes('.height(64)'));assert(!modal.includes('onAreaChange'),'natural body must not depend on a constrained measurement feedback loop');assert(modal.includes('PinmonyHdsTitleBar.resolve('));
const index=read('entry/src/main/ets/pages/Index.ets');
const start=index.indexOf('  private nativeSheetUsesThemedModal()'),end=index.indexOf('\n  private nativeModalLabel',start);
const Gate=vm.runInNewContext(ts.transpileModule('class Gate {'+index.slice(start,end)+'} Gate;',{}).outputText);
const g=new Gate();g.homeStore={};g.pinStore={editResult:{phase:'edit'}};
for(const kind of ['publish','share','save','more','edit','comments','searchFilter','profileMenu'])for(const card of [false,true]){
 g.activeSheetKind=kind;g.homeStore.customHomeMenu=card?{}:undefined;
 assert.equal(g.nativeSheetUsesThemedModal(),['publish','comments','searchFilter','profileMenu','edit'].includes(kind)||kind==='share'&&card);
 assert.equal(g.nativeSheetHasHdsTitle(),['publish','share','save','more','edit','comments','searchFilter','profileMenu'].includes(kind));
}
g.activeSheetKind='edit';g.pinStore.editResult.phase='boards';assert.equal(g.nativeSheetUsesThemedModal(),false);assert.equal(g.nativeSheetHasHdsTitle(),true);
assert(index.includes('.bindSheet($$this.showNativeSheet, this.buildPresentedNativeSheet()'));
assert(index.includes('onClose: () => this.closeNativeModal()'));
assert(index.includes('this.sheetMaterialMode, !this.nativeSheetHasHdsTitle()'));
console.log('Modal HDS theme: explicit theme backdrop, four modes, localized close, natural body and all shared host branches passed; no body damping');
