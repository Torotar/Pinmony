const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const PinmonyHdsTitleBar=require('./modal-style-test-fixture.cjs')(ts);
const read=p=>fs.readFileSync(p,'utf8');
const modal=read('common_ui/src/main/ets/components/PinmonyModalNavigation.ets');
const methods=modal.slice(modal.indexOf('  private titleOptions('),modal.indexOf('\n  build()'));
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods+'} Host;',{}).outputText,{
  $r:name=>name,PinmonyHdsTitleBar,PinmonyI18n:{text:(key,lang)=>key+':'+lang},
  PinmonyImmersiveLight:{effect:mode=>mode==='off'?undefined:{mode}},
  SymbolGlyphModifier:class{fontColor(){return this;}},IconStyleMode:{SMALL:1},BlurStrategy:{DISABLE:0,ADAPTIVE:2},ScrollEffectType:{GRADIENT_BLUR:3}
});
const h=new Host();let closed=0;h.onClose=()=>closed++;h.closeEnabled=true;
for(const mode of ['off','gentle','immersive','exquisite'])for(const lang of ['zh','en']){
 Object.assign(h,{materialMode:mode,uiLanguage:lang,titleText:'title:'+lang});
 const opts=h.titleOptions();assert.equal(opts.content.title.mainTitle,'title:'+lang);
 assert.equal(opts.style.originalStyle.backgroundStyle.backgroundColor,'app.color.page_background');
 assert.equal(opts.style.originalStyle.backgroundStyle.blurRadius,0);assert.equal(opts.style.scrollEffectOpts.enableScrollEffect,false);
 assert.equal(opts.style.scrollEffectOpts.scrollEffectType,2,'official gradient enum matches installed SDK');
 assert.equal(opts.style.blurStrategy,mode==='off'?0:2,'enabled material follows system policy');
 assert.equal(opts.style.systemMaterialEffect===undefined,mode==='off');
 const close=opts.content.menu.value[0].content;assert.equal(close.label,'pm_close_3fd47edc:'+lang);close.action();
}
assert.equal(closed,8);h.closeEnabled=false;const disabled=h.titleOptions().content.menu.value[0].content;assert.equal(disabled.isEnabled,false);disabled.action();assert.equal(closed,8);
assert(modal.includes('.titleMode(HdsNavigationTitleMode.MODAL)'));
assert.equal(disabled.icon,undefined,'MODAL + SMALL uses the official default close icon');
for(const mode of ['off','gentle','immersive','exquisite'])for(const lang of ['zh','en']){
 Object.assign(h,{materialMode:mode,uiLanguage:lang,immersiveScroll:true});
 const opts=h.titleOptions(),enabled=mode!=='off';
 assert.equal(opts.style.scrollEffectOpts.enableScrollEffect,enabled);
 assert.equal(opts.style.scrollEffectOpts.scrollEffectType,3);
 assert.equal(opts.style.originalStyle.backgroundStyle.blurRadius,enabled?18:0);
 assert.equal(opts.style.scrollEffectStyle.backgroundStyle.blurRadius,enabled?18:0);
 assert.equal(opts.style.originalStyle.backgroundStyle.backgroundColor,enabled?undefined:'app.color.page_background');
 assert.equal(opts.style.blurStrategy,enabled?1:0);
 assert.equal(opts.style.thermoCtrl,enabled);
 assert.equal(opts.enableComponentSafeArea,false,'scrolling comments extend behind the title; the list owns its initial inset');
 assert.equal(opts.content.menu.value[0].content.isEnabled,false,'immersion retains the close gate');
 assert.equal(opts.content.menu.value[0].content.label,'pm_close_3fd47edc:'+lang);
}
h.immersiveScroll=false;
assert(modal.includes('PinmonyHdsTitleBar.resolve('));
const index=read('entry/src/main/ets/pages/Index.ets');
const start=index.indexOf('  private nativeSheetUsesThemedModal()'),end=index.indexOf('\n  private nativeModalLabel',start);
const Gate=vm.runInNewContext(ts.transpileModule('class Gate {'+index.slice(start,end)+'} Gate;',{}).outputText);
const g=new Gate();g.homeStore={};g.pinStore={editResult:{phase:'edit'}};
for(const kind of ['publish','share','save','more','edit','comments','searchFilter','profileMenu'])for(const card of [false,true]){
 g.activeSheetKind=kind;g.homeStore.customHomeMenu=card?{}:undefined;
 assert.equal(g.nativeSheetUsesThemedModal(),['publish','comments','searchFilter','profileMenu','edit'].includes(kind));
 assert.equal(g.nativeSheetHasHdsTitle(),['publish','share','save','more','edit','comments','searchFilter','profileMenu'].includes(kind));
}
g.activeSheetKind='edit';g.pinStore.editResult.phase='boards';assert.equal(g.nativeSheetUsesThemedModal(),false);assert.equal(g.nativeSheetHasHdsTitle(),true);
assert(index.includes('.bindSheet($$this.showNativeSheet, this.buildPresentedNativeSheet()'));
assert(index.includes('onClose: () => this.closeNativeModal()'));
assert(index.includes('this.sheetMaterialMode, !this.nativeSheetHasHdsTitle()'));
console.log('Modal HDS theme: explicit theme backdrop, four modes, localized native close and all shared host branches passed');

const modalBuild=modal.slice(modal.indexOf('  build()'));
assert(modalBuild.includes('HdsNavigation() {\n      if (this.fillContent)'), 'both sizing branches belong to the complete HDS navigation');
assert(!/HdsNavigation\(\)\s*\{\s*\}/.test(modalBuild),'no empty navigation used as a standalone header');
assert(!/\.height\(64\)|\.clip\(|\.zIndex\(|customTitle/.test(modalBuild),'no header cropping or sibling paint-order workaround');
assert(modalBuild.includes(".height(this.fillContent ? '100%' : this.contentHeight + 64)"), 'documented 64vp main-title backdrop is included once in total intrinsic navigation height');
const full=modalBuild.slice(modalBuild.indexOf('if (this.fillContent)'),modalBuild.indexOf('} else {'));
assert(!full.includes('Scroll('),'full-height content retains its own list, composer and footer layout');
assert(modalBuild.includes('Scroll(this.contentScroller)')&&modalBuild.includes('.bindToScrollable(this.fillContent ? this.scrollControllers : [this.contentScroller])'),'full-height bodies bind their actual external List; intrinsic menus retain their rendered Scroll');
assert(modal.includes('@Prop immersiveScroll: boolean = false;')&&modal.includes('scrollControllers: Scroller[] = [];'),'unrelated full-height hosts retain opt-out defaults');
assert(modalBuild.includes("}.width('100%').height('100%')"),'scroll viewport uses available content area instead of overflowing a short window');
assert(modalBuild.includes('.edgeEffect(EdgeEffect.None)'),'short and long menus do not gain spring damping');
assert(modalBuild.indexOf('.onAreaChange(')>modalBuild.indexOf('Column() { this.content() }',modalBuild.indexOf('Scroll(')),'measure unbounded intrinsic content inside Scroll, not the constrained navigation');
const Measurement=vm.runInNewContext(ts.transpileModule('class Measurement {'+modal.slice(modal.indexOf('  private updateContentHeight('),modal.indexOf('  private titleOptions('))+'} Measurement;',{}).outputText);
const measurement=new Measurement();measurement.contentHeight=1;
for(const height of [180,420,850,92,0,260]){
 measurement.updateContentHeight({height});assert.equal(measurement.contentHeight,height,'growth, shrinking, empty and reloaded content are retained');
}
for(const height of [NaN,Infinity,-1])measurement.updateContentHeight({height});
assert.equal(measurement.contentHeight,260,'invalid geometry cannot break panel sizing');
measurement.updateContentHeight({height:260.2});assert.equal(measurement.contentHeight,260,'subpixel changes do not cause relayout feedback');
console.log('Official MODAL structure: title and body share HDS navigation, default close, intrinsic growth/shrink and full-height branch passed; device shadow still unverified');
