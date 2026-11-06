const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
const ast=ts.createSourceFile('page.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true),names=['paneChromeOpacity','paneBackdropOpacity','categoryBackdropOpacity','updatePagerBackdrop','homeTitleBarOptions','scrollBinding','registerScroller'],methods=[];
function visit(node){if(ts.isMethodDeclaration(node)&&names.includes(node.name.getText(ast)))methods.push(node.getText(ast));ts.forEachChild(node,visit);}visit(ast);
assert.equal(methods.length,names.length);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{
  BlurStrategy:{ENABLE:1,DISABLE:0},ScrollEffectType:{IMMERSIVE_GRADIENT_BLUR:3},
  PinmonyImmersiveLight:{effect:mode=>mode}
});
const tabs=[{id:'all'},{id:'board'},{id:'other'}],snapshots={all:{pins:[{}]},board:{board:{id:'1'},pins:[{}]},other:{board:{id:'2'},pins:[{}]}};
const h=new Host();Object.assign(h,{pageTabs:()=>tabs,snapshotFor:id=>snapshots[id],paneKey:id=>id,paneChrome:new Map(),selectedId:'board',homeChromeCollapsed:false,pagerPosition:-1,pagerMoving:false,suppressSwipeClick:false});
assert.equal(h.categoryBackdropOpacity(),1,'expanded board keeps its normal solid header');
for(const progress of [0,.1,.25,.5,.75,.9,1]){h.updatePagerBackdrop(1,1,progress);assert(Math.abs(h.categoryBackdropOpacity()-(1-progress))<1e-9,'board to all tracks every intermediate frame');}
h.updatePagerBackdrop(0,0,-.25);assert.equal(h.categoryBackdropOpacity(),.25,'reverse swipe fades the solid header back in');
h.updatePagerBackdrop(0,0,-.75);assert.equal(h.categoryBackdropOpacity(),.75);
h.updatePagerBackdrop(0,0,0);assert.equal(h.categoryBackdropOpacity(),0,'cancelled gesture returns to the source background');
const position=h.pagerPosition;h.updatePagerBackdrop(0,1,.5);h.updatePagerBackdrop(0,0,NaN);assert.equal(h.pagerPosition,position,'neighbor notifications and invalid offsets cannot overwrite progress');
h.paneChrome.set('board',true);h.updatePagerBackdrop(0,0,-.5);assert.equal(h.categoryBackdropOpacity(),0,'two transparent endpoints never flash a solid header');
h.paneChrome.set('board',false);h.updatePagerBackdrop(1,1,-.5);assert.equal(h.categoryBackdropOpacity(),1,'two expanded boards stay solid during transition');
h.paneChrome.set('other',true);assert.equal(h.categoryBackdropOpacity(),.5,'retained target scroll chrome participates before selection commits');
h.selectedId='all';assert.equal(h.categoryBackdropOpacity(),.5,'selection callbacks do not jump the in-flight opacity');
h.pagerPosition=-1;assert.equal(h.categoryBackdropOpacity(),0,'settling restores the selected endpoint');
assert(source.includes('.opacity(this.categoryBackdropOpacity())'));
assert(source.includes('this.updatePagerBackdrop(selected,index,position);'));
assert(source.includes('if(this.pagerPosition < 0)this.pagerPosition = index'),'release animation preserves current drag progress');
assert(source.includes('this.pagerPosition = -1; this.bindCurrentScroller();'),'settle releases the interpolation and keeps native scroller binding');
for(const mode of ['immersive','gentle','exquisite','off']) {
  h.immersiveLightMode=mode;
  for(const progress of [0,.1,.5,.9,1]) {
    h.updatePagerBackdrop(1,1,progress);
    const style=h.homeTitleBarOptions().style,radius=mode==='off'?0:18;
    assert.equal(style.originalStyle.backgroundStyle.blurRadius,radius,'native gradient blur is already configured before scroll handoff');
    assert.equal(style.scrollEffectStyle.backgroundStyle.blurRadius,radius,'native gradient radius does not jump when selection/scroller commits');
    assert.equal(style.originalStyle.backgroundStyle.maskExtraHeight,0,'initial mask stops at the category title region instead of covering board metadata');
    assert.equal(style.scrollEffectStyle.backgroundStyle.maskExtraHeight,0,'scrolled mask keeps the same boundary throughout the transition');
    assert.equal(style.scrollEffectOpts.scrollEffectType,3,'keep HDS immersive gradient blur');
    assert.equal(style.blurStrategy,mode==='off'?0:1,'respect the user material preference');
  }
}
const scrollers={all:{currentOffset:()=>({yOffset:320})},board:{currentOffset:()=>({yOffset:0})},other:{currentOffset:()=>({yOffset:1500})}};
Object.assign(h,{scrollerRevision:0,presentationEpoch:4,paneScrollers:new Map(),initialOffset:()=>0,selectedId:'board',pagerPosition:-1});
assert.equal(h.scrollBinding().length,0,'no binding before a pane mounts');
h.registerScroller('board',scrollers.board,4);
h.registerScroller('all',scrollers.all,4);
h.registerScroller('other',scrollers.other,4);
assert.equal(h.scrollBinding()[0],scrollers.board,'settled board keeps its own scroller');
for(const progress of [.001,.1,.5,.9,.999,1]) {
  h.updatePagerBackdrop(1,1,progress);
  assert.equal(h.selectedId,'board','destination is not selected during this simulated drag');
  assert.equal(h.scrollBinding()[0],scrollers.all,'blur binds the visible scrolled target before onChange');
}
h.updatePagerBackdrop(1,1,0);
assert.equal(h.scrollBinding()[0],scrollers.board,'cancel returns to the unscrolled source');
h.selectedId='all';h.feedScroller=scrollers.all;
for(const progress of [.001,.5,.999]) {
  h.updatePagerBackdrop(0,0,-progress);
  assert.equal(h.scrollBinding()[0],scrollers.all,'reverse swipe retains blur until solid target covers it');
}
h.updatePagerBackdrop(0,0,-1);
assert.equal(h.scrollBinding()[0],scrollers.board,'completed unscrolled endpoint uses its actual scroller');
h.updatePagerBackdrop(1,1,.5);
const revision=h.scrollerRevision;
h.registerScroller('all',undefined,4);
assert(h.scrollerRevision>revision,'unmount invalidates the material binding');
assert.equal(h.scrollBinding()[0],scrollers.board,'unmounted target cannot remain bound');
h.registerScroller('all',scrollers.all,3);
assert(!h.paneScrollers.has('all'),'stale presentation cannot register a target');
h.registerScroller('all',scrollers.all,4);
assert.equal(h.scrollBinding()[0],scrollers.all,'late target mount participates before selection');
h.updatePagerBackdrop(1,1,-.5);
assert.equal(h.scrollBinding()[0],scrollers.other,'only visible neighbors participate, with actual scroll offsets');
h.pagerPosition=-1;h.feedScroller=scrollers.all;
assert.equal(h.scrollBinding()[0],scrollers.all,'settle releases the temporary binding');
assert(source.includes('.bindToScrollable(this.scrollBinding())'),'actual HDS navigation uses the progress-aware binding');
console.log('Home category backdrop: live opacity and native scroller binding before selection, reverse/cancel, late mount, stale/unmounted isolation and material modes passed');
