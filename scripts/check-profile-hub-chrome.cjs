const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const ast=ts.createSourceFile('profile.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);
function method(name){let found;function visit(node){if(ts.isMethodDeclaration(node)&&node.name.getText(ast)===name)found=node.getText(ast);ts.forEachChild(node,visit);}visit(ast);assert(found);return found;}
const methods=['hubHeaderInset','hubChromeHeight','hubCollapseHeight','hubHeaderBackgroundOpacity','hubPaneChromeOffset','hubChromeVisibleHeight','hubContentInset','updateHubChrome','registerHubScroller','setHubChromeCollapsed','stopHubChromeAnimation','hubTitlePosition','hubTitleBottomHeight','switchHubTab'];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.map(method).join('')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{ScrollState:{Scroll:1},Curve:{EaseOut:1}});
let animations=0,autoComplete=true,latestAnimator;
function createAnimator(opts){
 assert.equal(opts.duration,260);assert.equal(opts.easing,'ease-out');animations++;
 const animation={opts,cancelled:false,play(){if(autoComplete){this.onFrame(opts.end);this.onFinish();}},cancel(){this.cancelled=true;}};
 latestAnimator=animation;return animation;
}
const h=new Host();Object.assign(h,{modern:()=>true,hubPane:true,interactionReady:true,refreshing:false,loading:false,sortVisible:false,hubTab:'boards',hubChromeOffset:0,hubChromeAnimationTarget:-1,hubChromeAnimationEpoch:0,hubPagerPosition:-1,hubPaneChromeOffsets:new Map(),hubChromeOffsetVp:0,hubChromeScrollDistance:0,statusBarHeightPx:24,requestHub(){},getUIContext:()=>({px2vp:n=>n,createAnimator})});
h.updateHubChrome(6,1,100);assert.equal(h.hubChromeOffset,0);
h.updateHubChrome(4,1,104);assert.equal(h.hubChromeOffset,112,'10vp triggers full eased collapse');
const count=animations;h.updateHubChrome(20,1,124);assert.equal(animations,count,'same target does not restart animation');
h.updateHubChrome(-6,1,118);assert.equal(h.hubChromeOffset,112);
h.updateHubChrome(-4,1,114);assert.equal(h.hubChromeOffset,0,'reverse 10vp triggers full eased expansion');
h.updateHubChrome(30,2,144);assert.equal(h.hubChromeOffset,0,'inertia cannot toggle chrome');
h.updateHubChrome(6,1,150);h.updateHubChrome(-6,1,144);assert.equal(h.hubChromeOffset,0,'direction reversal resets accumulation');
h.hubChromeScrollDistance=0;h.updateHubChrome(NaN,1,144);assert.equal(h.hubChromeScrollDistance,0);
h.updateHubChrome(10,1,154);h.updateHubChrome(0,0,0);assert.equal(h.hubChromeOffset,0,'top always expands');
for(const guard of ['refreshing','loading','sortVisible']){h[guard]=true;h.updateHubChrome(20,1,100);assert.equal(h.hubChromeOffset,0);h[guard]=false;}
h.interactionReady=false;h.updateHubChrome(20,1,100);assert.equal(h.hubChromeOffset,0);h.interactionReady=true;
const start=source.indexOf('.onDidScroll('),end=source.indexOf('.onReachEnd(',start);assert(start>=0&&end>start);
const callback=source.slice(start+'.onDidScroll('.length,end).trim().replace(/\)\s*$/,'');
const Pane=vm.runInNewContext(ts.transpileModule('class Pane { didScroll = '+callback+'; } Pane;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
let position=100,forwarded=0;const scroller={offset:()=>({yOffset:position})};
h.hubPaneScrollers=[{},{},{}];h.registerHubScroller('boards',scroller);assert.equal(h.hubPaneScrollers[1],scroller);
const registered=h.hubPaneScrollers;h.registerHubScroller('boards',scroller);assert.equal(h.hubPaneScrollers,registered);
const pane=new Pane();Object.assign(pane,{hubPane:true,restoringScroll:false,interactionReady:true,scroller,onHubScroll:(offset,state,current)=>h.updateHubChrome(offset,state,current),updateCompactHeader(){},reportScroll(){},onContentScroll(){forwarded++;}});
pane.didScroll(0,10,1);assert.equal(h.hubChromeOffset,112);
position=90;pane.didScroll(0,-10,1);assert.equal(h.hubChromeOffset,0);
pane.restoringScroll=true;pane.didScroll(0,20,1);assert.equal(h.hubChromeOffset,0);assert.equal(forwarded,3);
assert.equal(h.hubContentInset(),216);h.hubChromeOffsetVp=56;assert.equal(h.hubChromeVisibleHeight(),56);assert.equal(h.hubContentInset(),216,'only scrollable padding reserves title space while the viewport extends under blur');
h.hubChromeOffsetVp=112;assert.equal(h.hubChromeVisibleHeight(),0);assert.equal(h.hubContentInset(),216);
h.hubChromeOffset=0;assert.equal(h.hubHeaderBackgroundOpacity(),1);h.hubChromeOffset=56;assert.equal(h.hubHeaderBackgroundOpacity(),0.5);h.hubChromeOffset=112;assert.equal(h.hubHeaderBackgroundOpacity(),0);
autoComplete=false;
for(const tab of ['pins','boards','collages']){
 h.hubTab=tab;const range=tab==='collages'?52:112;
 for(const collapsed of [false,true]){
  h.hubChromeOffset=collapsed?0:range;
  h.setHubChromeCollapsed(collapsed);const animation=latestAnimator;
  assert.equal(h.hubChromeOffset,animation.opts.begin,'starting animation must not immediately commit the final background');
  const count=animations;h.setHubChromeCollapsed(collapsed);assert.equal(animations,count,'scroll callbacks cannot restart an active animation');
  for(const progress of [.1,.25,.5,.75,.9]){
   const offset=animation.opts.begin+(animation.opts.end-animation.opts.begin)*progress;
   animation.onFrame(offset);
   assert.equal(h.hubChromeOffset,offset);
   assert(Math.abs(h.hubHeaderBackgroundOpacity()-(1-offset/range))<1e-9,'background has intermediate opacity even if HDS rebuilds its nodes');
   assert(Math.abs(h.hubTitleBottomHeight()-(24+range-offset))<1e-9,'material host shares the exact same frame progress');
  }
  animation.onFinish();assert.equal(h.hubChromeOffset,animation.opts.end);
  animation.onFrame(animation.opts.begin);assert.equal(h.hubChromeOffset,animation.opts.end,'late frame after completion is ignored');
 }
}
h.hubTab='boards';h.hubChromeOffset=112;h.setHubChromeCollapsed(false);
const expanding=latestAnimator;expanding.onFrame(56);h.setHubChromeCollapsed(true);
const reversing=latestAnimator;assert(expanding.cancelled);assert.equal(reversing.opts.begin,56,'reverse starts at the displayed frame');
expanding.onFrame(0);expanding.onFinish();assert.equal(h.hubChromeOffset,56,'cancelled animation cannot overwrite reversal');
reversing.onFrame(84);h.switchHubTab('pins');assert(reversing.cancelled);
assert.equal(h.hubPaneChromeOffsets.get('boards'),112,'leaving a pane retains its intended collapse state');
reversing.onFrame(56);reversing.onFinish();assert.equal(h.hubChromeOffset,0,'old pane animation cannot affect the selected pane');
h.setHubChromeCollapsed(true);const hidden=latestAnimator;hidden.onFrame(40);h.stopHubChromeAnimation();
assert(hidden.cancelled);assert.equal(h.hubChromeOffset,112);hidden.onFrame(0);assert.equal(h.hubChromeOffset,112,'hidden page ignores cancelled frames');
h.setHubChromeCollapsed(false);const oldSession=latestAnimator;h.stopHubChromeAnimation(false);h.hubChromeOffset=0;
oldSession.onFrame(100);oldSession.onFinish();assert.equal(h.hubChromeOffset,0,'session reset rejects stale callbacks');
assert(/aboutToDisappear\(\): void \{\s*this\.stopHubChromeAnimation\(\);/.test(source));
assert(/if \(!this\.interactionReady\) \{\s*this\.stopHubChromeAnimation\(\);/.test(source));
h.hubTab='collages';assert.equal(h.hubCollapseHeight(),52);h.statusBarHeightPx=40;assert.equal(h.hubCollapseHeight(),52);
h.hubPane=false;assert.equal(h.hubContentInset(),0);h.hubPane=true;h.modern=()=>false;assert.equal(h.hubContentInset(),0);
console.log('Profile chrome: native 260ms frame animation, intermediate background/host values, reversal, stale callbacks, pane cancellation, 10vp threshold, inertia guards, fixed inset and actual scroll callback passed');
