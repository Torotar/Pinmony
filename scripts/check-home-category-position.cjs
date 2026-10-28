const { rawLocalMessages } = require('./local-message-test-fixture.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(name){const a=source.indexOf('  private '+name+'(');assert(a>=0);const b=source.indexOf('\n  private ',a+1);return source.slice(a,b).replace(/@Builder\s*$/,'');}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('updateHomeChrome')+method('emptyFeedMessage')+method('canShowFeed')+method('onOfflinePreviewChanged')+method('updateCategories')+method('applyCategories')+method('categoryPageKey')+method('selectTab')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Curve:{EaseInOut:'ease',EaseOut:'out'},ScrollState:{Idle:0,Scroll:1},animateTo:(_options,change)=>change()});
const h=new Host(),calls=[];Object.assign(h,{categories:[],getUIContext:()=>({animateTo:(_options,change)=>change()}),uiText:rawLocalMessages.text,home:{tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===1,enabled:index!==2}))},categoryViewportWidth:0,categoryWidths:new Map(),alignedCategory:'',pendingTabId:'',interactionReady:true,onTab:id=>calls.push(id)});
h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),1);
h.selectTab(h.categories[1]);h.selectTab(h.categories[2]);assert.equal(calls.length,0);
h.selectTab(h.categories[0]);assert.deepEqual(calls,['all']);
h.pendingTabId='all';h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),0);
h.interactionReady=false;h.selectTab(h.categories[1]);assert.equal(calls.length,1);
h.pendingTabId='';h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),1,'failure restores confirmed selection');
h.home.tabs=[];h.updateCategories();assert.equal(h.categories.length,0);
assert(source.includes('.opacity(this.homeChromeCollapsed ? 0 : 1)'));
assert(source.includes(".accessibilityLevel(this.homeChromeCollapsed ? 'no-hide-descendants' : 'auto')"));
Object.assign(h,{offlinePreview:true,interactionReady:false,offlineCategoryId:'',pendingTabId:'',home:{kind:'state',pins:[{id:'1'}],tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===1,enabled:true}))}});
h.updateCategories();const priorCalls=calls.length;h.selectTab(h.categories[2]);assert.equal(calls.length,priorCalls,'offline category selection makes no request');assert.equal(h.categories[2].selected,true);assert.equal(h.canShowFeed(),false,'do not show another category cache');assert.match(h.emptyFeedMessage(),/当前离线/);
h.selectTab(h.categories[1]);assert.equal(h.canShowFeed(),true,'return to cached category preserves photos');
h.offlinePreview=false;h.onOfflinePreviewChanged();assert.equal(h.offlineCategoryId,'');
Object.assign(h,{offlinePreview:false,interactionReady:true,pendingTabId:'',home:{kind:'state',pins:[],tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===0,enabled:true}))}});
h.updateCategories();let selectionAtDispatch=-1;h.onTab=id=>{selectionAtDispatch=h.categories.findIndex(tab=>tab.selected);};h.selectTab(h.categories[2]);assert.equal(selectionAtDispatch,2,'selection changes before dispatch');
console.log('Home categories: selection, offline isolation and board summary scroll behavior passed');
let scrollOffset=0;Object.assign(h,{home:{board:{id:'7'}},homeChromeCollapsed:false,chromeScrollDistance:0,feedActive:true,refreshing:false,restoringScroll:false,getUIContext:()=>({animateTo:(_options,change)=>change()}),feedScroller:{offset:()=>({yOffset:scrollOffset})}});scrollOffset=40;h.updateHomeChrome(40,1);assert.equal(h.homeChromeCollapsed,true,'scroll hides board summary');scrollOffset=20;h.updateHomeChrome(-5,1);assert.equal(h.homeChromeCollapsed,true,'sub-threshold direction changes do not toggle chrome');scrollOffset=0;h.updateHomeChrome(-20,1);assert.equal(h.homeChromeCollapsed,false,'top restores summary');h.restoringScroll=true;scrollOffset=100;h.updateHomeChrome(100,1);assert.equal(h.homeChromeCollapsed,false,'restoring viewport does not drive user animation');

h.restoringScroll=false;h.homeChromeCollapsed=true;scrollOffset=0;h.updateHomeChrome(0,0);assert.equal(h.homeChromeCollapsed,false,'scroll stop at top expands summary');scrollOffset=100;h.updateHomeChrome(0,0);assert.equal(h.homeChromeCollapsed,false,'idle viewport alone does not collapse summary');

assert(source.includes("tab.selected.toString() + ':' + tab.enabled.toString()"),'button identity must update with selected and enabled state');
assert(source.includes('if (current) this.selectTab(current);'),'click reads latest category state');
Object.assign(h,{offlinePreview:false,interactionReady:true,pendingTabId:'',home:{tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===0,enabled:true}))}});h.updateCategories();const selections=[];h.onTab=id=>selections.push(h.categories.find(tab=>tab.selected).id);h.selectTab(h.categories[1]);h.selectTab(h.categories[2]);h.selectTab(h.categories[0]);assert.deepEqual(selections,['art','icons','all'],'each online click updates selection before request dispatch');

const animations=[];h.getUIContext=()=>({animateTo:(options,change)=>{animations.push(options);change();}});
h.selectTab(h.categories[2]);assert.equal(h.categoryDirection,1,'later category enters from right');assert.equal(h.categoryPageKey(),'icons');
h.selectTab(h.categories[0]);assert.equal(h.categoryDirection,-1,'earlier category enters from left');assert.equal(h.categoryPageKey(),'all');
const animationCount=animations.length;h.pendingTabId='all';h.updateCategories();h.selectTab(h.categories[0]);assert.equal(animations.length,animationCount,'same-category snapshots and repeated selection never restart transition');
h.pendingTabId='art';h.updateCategories();assert.equal(h.categoryPageKey(),'art');assert.equal(h.categoryDirection,1,'external pending selection uses the same transition');
h.pendingTabId='';h.updateCategories();assert.equal(h.categoryPageKey(),'all');assert.equal(h.categoryDirection,-1,'failed selection restores confirmed category in reverse');
const homeNavigation=source.slice(source.indexOf('  private homeNavigation()'),source.indexOf('  build() {',source.indexOf('  private homeNavigation()')));
const titleOptionsStart=source.indexOf('  private homeTitleBarOptions()');
const titleOptionsMethod=source.slice(titleOptionsStart,source.indexOf('\n  build()',titleOptionsStart));
const TitleHost=vm.runInNewContext(ts.transpileModule('class TitleHost {'+titleOptionsMethod+'} TitleHost;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{BlurStrategy:{ENABLE:1,DISABLE:0},ScrollEffectType:{IMMERSIVE_GRADIENT_BLUR:3},PinmonyImmersiveLight:{effect:mode=>mode}});
for(const mode of ['immersive','gentle','exquisite','off']){const titleHost=new TitleHost();titleHost.immersiveLightMode=mode;const style=titleHost.homeTitleBarOptions().style;assert.equal(style.blurStrategy,mode==='off'?0:1);assert.equal(style.thermoCtrl,mode!=='off');assert.equal(style.scrollEffectOpts.enableScrollEffect,mode!=='off','runtime title options must not depend on an accessor omitted by the ArkUI struct compiler');}
assert(homeNavigation.includes('HdsNavigation() { this.feedContent() }'),'the HDS navigation owns the scrolling feed');
assert(homeNavigation.includes('stackBuilder: (): void => { this.categoryButtons(); }'),'all home categories are mounted in HDS stackBuilder');
assert(homeNavigation.includes('systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)'),'the HDS title bar owns its default material effect');
const homeTitleBarOptions=source.slice(source.indexOf('  private homeTitleBarOptions()'),source.indexOf('\n  build()',source.indexOf('  private homeTitleBarOptions()')));
assert(homeTitleBarOptions.includes('avoidLayoutSafeArea: true')&&homeTitleBarOptions.includes('enableComponentSafeArea: false'),'title controls avoid the system area without introducing a second component safe area into the manually inset feed');
assert(!homeNavigation.includes('maskExtraHeight')&&!homeNavigation.includes('blurRadius')&&!source.includes('linearGradientBlur('),'the home page does not tune or draw a separate blur layer');
assert(source.includes('top: this.homeTopInset() + (this.home.board ? 132 : 64) })'),'home feed does not add bottom scroll padding');
const rootTabs=indexSource.slice(indexSource.indexOf('  private buildRootTabs()'),indexSource.indexOf('  build()',indexSource.indexOf('  private buildRootTabs()')));
assert(rootTabs.includes('.barOverlap(true)'),'root tab bar keeps its original floating overlap layout');
assert(rootTabs.includes('barBottomMargin: 28'),'root tab floating margin stays unchanged');
assert(source.includes('ForEach([this.categoryPageKey()]')&&source.includes('this.homeNavigation()'),'title bar and feed move together with the selected category page');
assert(source.includes('TransitionEffect.asymmetric('));assert(source.includes('this.contentWidth }'));
console.log('Home category motion: both directions, rapid selection, pending and failure rollback, stable same-category updates passed');
