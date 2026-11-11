const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const names=['hubChromeHeight','hubCollapseHeight','hubHeaderBackgroundOpacity','hubPaneChromeOffset','switchHubTab','updateHubPagerPosition','startHubPagerAnimation','hubScrollBinding','hubTitlePosition'];
const ast=ts.createSourceFile('profile.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true),methods=[];
function visit(node){if(ts.isMethodDeclaration(node)&&names.includes(node.name.getText(ast)))methods.push(node.getText(ast));ts.forEachChild(node,visit);}visit(ast);assert.equal(methods.length,names.length);
const motionLogs=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(message){motionLogs.push(message);}}});
const scrollers=[{currentOffset:()=>({yOffset:500})},{currentOffset:()=>({yOffset:0})},{currentOffset:()=>({yOffset:200})}];
let requests=0;
const h=Object.assign(new Host(),{hubTab:'pins',hubChromeOffset:112,hubPaneChromeOffsets:new Map(),hubPagerPosition:-1,hubPaneScrollers:scrollers,sortVisible:false,hubChromeScrollDistance:7,stopHubChromeAnimation(){},requestHub:()=>requests++});
assert.equal(h.hubHeaderBackgroundOpacity(),0,'initial scrolled pins has transparent header');
for(const progress of [0,.1,.25,.5,.75,.9,1]){
 h.updateHubPagerPosition(0,0,-progress);
 assert(Math.abs(h.hubHeaderBackgroundOpacity()-progress)<1e-9,'background follows live pins to boards progress');
 assert.equal(h.hubPaneChromeOffset('pins'),112,'source controls stay collapsed');
 assert.equal(h.hubPaneChromeOffset('boards'),0,'target controls retain their own expanded state');
 if(progress>0&&progress<1)assert.equal(h.hubScrollBinding()[0],scrollers[0],'material stays bound to visible scrolled source');
}
assert.equal(requests,0,'drag presentation does not commit business navigation');
h.switchHubTab('boards');assert.equal(h.hubChromeOffset,0);assert.equal(requests,1);
assert.equal(h.hubPaneChromeOffsets.get('pins'),112,'remember collapsed pins when leaving');
assert.equal(h.hubHeaderBackgroundOpacity(),1,'selection handoff does not jump opacity');
h.hubPagerPosition=-1;assert.equal(h.hubScrollBinding()[0],scrollers[1]);
for(const progress of [.1,.5,.9]){h.updateHubPagerPosition(1,1,progress);assert(Math.abs(h.hubHeaderBackgroundOpacity()-(1-progress))<1e-9);assert.equal(h.hubScrollBinding()[0],scrollers[0],'return binds scrolled destination before selection');}
h.updateHubPagerPosition(1,1,0);assert.equal(h.hubHeaderBackgroundOpacity(),1,'cancel restores boards');
h.updateHubPagerPosition(1,1,1);h.switchHubTab('pins');h.hubPagerPosition=-1;
assert.equal(h.hubChromeOffset,112,'return restores original collapsed state, not screenshot-three expanded controls');
assert.equal(h.hubHeaderBackgroundOpacity(),0);
assert.equal(h.hubPaneChromeOffset('boards'),0);
h.switchHubTab('collages');h.hubChromeOffset=52;h.switchHubTab('pins');
h.updateHubPagerPosition(0,0,-1.5);assert.equal(h.hubPaneChromeOffset('collages'),52);assert.equal(h.hubHeaderBackgroundOpacity(),.5,'different collapse heights are normalized per pane');
const position=h.hubPagerPosition;h.updateHubPagerPosition(0,1,.2);h.updateHubPagerPosition(0,0,NaN);assert.equal(h.hubPagerPosition,position);
const count=requests;h.switchHubTab('pins');h.switchHubTab('invalid');assert.equal(requests,count);
for(const [tab,start,target,frames,expected] of [
 ['boards',.35,1,[.7,.99,1.08,1.02,.995,1],[.7,.99,1,1,1,1]],
 ['pins',.7,0,[.4,.02,-.08,.02,0],[.4,.02,0,0,0]],
 ['boards',1.7,1,[1.3,1.01,.92,1.02,1],[1.3,1.01,1,1,1]],
 ['pins',.4,0,[.3,.1,-.05,.02,0],[.3,.1,0,0,0]]
]){
 const settling=Object.assign(new Host(),{hubTab:tab,hubChromeOffset:0,hubPaneChromeOffsets:new Map(),hubPagerPosition:start,hubPagerAnimationStart:start,hubPagerAnimationTarget:target,hubPagerOvershootReported:false});
 settling.startHubPagerAnimation(Math.round(start),target);
 const before=motionLogs.length;
 for(let i=0;i<frames.length;i++){
  settling.updateHubPagerPosition(target,target,target-frames[i]);
  assert.equal(settling.hubTitlePosition(),expected[i],'settling filter row cannot overshoot or rebound after reaching its target');
 }
 assert.equal(motionLogs.length,before+1,'only the first bounded frame is logged for an animation');
 settling.hubPagerAnimationTarget=-1;
 for(const progress of [.6,.3,.5]){
  settling.updateHubPagerPosition(0,0,-progress);
  assert.equal(settling.hubTitlePosition(),progress,'finger-driven reversal remains unrestricted');
 }
}
const endStart=source.indexOf('.onAnimationEnd(',source.indexOf('  private hubPager()'));
const endCallback=source.slice(endStart+'.onAnimationEnd('.length,source.indexOf("\n        .width('100%')",endStart)).trim().replace(/\)\s*$/,'');
const Completion=vm.runInNewContext(ts.transpileModule('class Completion extends Host { end = '+endCallback+'; } Completion;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Host});
for(const [from,to,progress] of [['pins','boards',.95],['boards','pins',.05]]){
 const active=Object.assign(new Completion(),{hubTab:from,hubChromeOffset:0,hubPaneChromeOffsets:new Map(),hubPagerPosition:progress,hubIndicatorClickTarget:-1,hubPaneScrollers:scrollers,stopHubChromeAnimation(){},requestHub(){}});
 const oldIndex=['pins','boards','collages'].indexOf(from),targetIndex=['pins','boards','collages'].indexOf(to);
 active.switchHubTab(to);
 active.updateHubPagerPosition(oldIndex,oldIndex,0);
 assert.equal(active.hubTitlePosition(),progress,'old-page zero frame must not rewind the filter row while completion is still pending');
 active.updateHubPagerPosition(oldIndex,oldIndex,.00001);
 assert.equal(active.hubTitlePosition(),progress,'near-zero outgoing frame also stays ignored');
 active.updateHubPagerPosition(targetIndex,targetIndex,0);
 assert.equal(active.hubTitlePosition(),targetIndex,'destination terminal frame can finish the row');
 active.end(targetIndex);assert.equal(active.hubTitlePosition(),targetIndex);
}
const pending=Object.assign(new Completion(),{hubTab:'pins',hubChromeOffset:0,hubPaneChromeOffsets:new Map(),hubPagerPosition:.99,hubIndicatorClickTarget:-1,hubPaneScrollers:scrollers,stopHubChromeAnimation(){},requestHub(){}});
pending.end(1);
assert.equal(pending.hubTitlePosition(),1,'completion must commit the destination before releasing progress, even if onChange arrives later');
pending.updateHubPagerPosition(0,0,0);
assert.equal(pending.hubTitlePosition(),1,'trailing idle frame from the old page cannot snap filters back');
pending.updateHubPagerPosition(0,0,-1);
assert.equal(pending.hubPagerPosition,-1,'trailing terminal frame cannot disable settled filter input');
pending.switchHubTab('boards');assert.equal(pending.hubTitlePosition(),1,'late onChange remains idempotent');
pending.hubPagerPosition=.01;pending.end(0);assert.equal(pending.hubTitlePosition(),0,'reverse handoff is stable');
pending.hubPagerPosition=.4;pending.end(0);assert.equal(pending.hubTitlePosition(),0,'cancelled drag returns to the selected filters');
pending.hubIndicatorClickTarget=2;pending.hubPagerPosition=1.4;pending.end(1);
assert.equal(pending.hubPagerPosition,1.4,'intermediate end during a direct click cannot settle the wrong page');
pending.end(2);assert.equal(pending.hubTitlePosition(),2,'direct click settles the intended destination');
pending.hubIndicatorClickTarget=-1;pending.hubPagerPosition=1.3;pending.switchHubTab('boards');pending.end(1);
assert.equal(pending.hubTitlePosition(),1,'onChange before animation end also keeps its destination');
assert(!source.includes('this.setHubChromeCollapsed(false);this.sortVisible = false;this.hubTab = tab'),'selection cannot force expansion');
assert(!source.includes('hubChromeOffsetVp:'),'title frame changes cannot propagate an unused prop to all retained panes');
assert(source.includes('.bindToScrollable(this.hubScrollBinding())'));
assert(source.includes('this.updateHubPagerPosition(selectedIndex,index,position);'));
assert(source.includes('if(this.hubPagerPosition < 0)this.hubPagerPosition = index'),'release preserves current drag progress');
assert(source.includes('this.startHubPagerAnimation(index, targetIndex);'),'settling uses the actual Swiper target');
assert(source.includes('this.hubPaneChromeOffsets.clear(); this.hubChromeOffset = 0; this.hubPagerPosition = -1;'),'identity change clears presentation cache');
console.log('Profile hub transition: per-tab retained chrome, live opacity, early native blur binding, reverse/cancel, collage height, selection handoff and callback wiring passed');
