const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const names=['hubChromeHeight','hubCollapseHeight','hubHeaderBackgroundOpacity','hubPaneChromeOffset','switchHubTab','updateHubPagerPosition','hubScrollBinding'];
const ast=ts.createSourceFile('profile.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true),methods=[];
function visit(node){if(ts.isMethodDeclaration(node)&&names.includes(node.name.getText(ast)))methods.push(node.getText(ast));ts.forEachChild(node,visit);}visit(ast);assert.equal(methods.length,names.length);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const scrollers=[{currentOffset:()=>({yOffset:500})},{currentOffset:()=>({yOffset:0})},{currentOffset:()=>({yOffset:200})}];
let requests=0;
const h=Object.assign(new Host(),{hubTab:'pins',hubChromeOffset:112,hubPaneChromeOffsets:new Map(),hubPagerPosition:-1,hubPaneScrollers:scrollers,sortVisible:false,hubChromeScrollDistance:7,requestHub:()=>requests++});
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
assert(!source.includes('this.setHubChromeCollapsed(false);this.sortVisible = false;this.hubTab = tab'),'selection cannot force expansion');
assert(source.includes('hubChromeOffsetVp:this.hubPaneChromeOffset(tab)'));
assert(source.includes('.bindToScrollable(this.hubScrollBinding())'));
assert(source.includes('this.updateHubPagerPosition(selectedIndex,index,position);'));
assert(source.includes('if(this.hubPagerPosition < 0)this.hubPagerPosition = index'),'release preserves current drag progress');
assert(source.includes('this.hubPaneChromeOffsets.clear(); this.hubChromeOffset = 0; this.hubPagerPosition = -1;'),'identity change clears presentation cache');
console.log('Profile hub transition: per-tab retained chrome, live opacity, early native blur binding, reverse/cancel, collage height, selection handoff and callback wiring passed');
