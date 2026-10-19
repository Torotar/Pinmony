const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
function method(name){const a=source.indexOf('  private '+name+'(');assert(a>=0);const b=source.indexOf('\n  private ',a+1);return source.slice(a,b).replace(/@Builder\s*$/,'');}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('updateHomeChrome')+method('emptyFeedMessage')+method('canShowFeed')+method('onOfflinePreviewChanged')+method('updateCategories')+method('selectTab')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Curve:{EaseInOut:'ease',EaseOut:'out'},ScrollState:{Idle:0,Scroll:1},animateTo:(_options,change)=>change()});
const h=new Host(),calls=[];Object.assign(h,{home:{tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===1,enabled:index!==2}))},categoryViewportWidth:0,categoryWidths:new Map(),alignedCategory:'',pendingTabId:'',interactionReady:true,onTab:id=>calls.push(id)});
h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),1);
h.selectTab(h.categories[1]);h.selectTab(h.categories[2]);assert.equal(calls.length,0);
h.selectTab(h.categories[0]);assert.deepEqual(calls,['all']);
h.pendingTabId='all';h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),0);
h.interactionReady=false;h.selectTab(h.categories[1]);assert.equal(calls.length,1);
h.pendingTabId='';h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),1,'failure restores confirmed selection');
h.home.tabs=[];h.updateCategories();assert.equal(h.categories.length,0);
assert(source.includes('.height(this.homeChromeCollapsed ? 0 : 68)'));
assert(source.includes(".accessibilityLevel(this.homeChromeCollapsed ? 'no-hide-descendants' : 'auto')"));
Object.assign(h,{offlinePreview:true,interactionReady:false,offlineCategoryId:'',pendingTabId:'',home:{kind:'state',pins:[{id:'1'}],tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===1,enabled:true}))}});
h.updateCategories();const priorCalls=calls.length;h.selectTab(h.categories[2]);assert.equal(calls.length,priorCalls,'offline category selection makes no request');assert.equal(h.categories[2].selected,true);assert.equal(h.canShowFeed(),false,'do not show another category cache');assert.match(h.emptyFeedMessage(),/当前离线/);
h.selectTab(h.categories[1]);assert.equal(h.canShowFeed(),true,'return to cached category preserves photos');
h.offlinePreview=false;h.onOfflinePreviewChanged();assert.equal(h.offlineCategoryId,'');
Object.assign(h,{offlinePreview:false,interactionReady:true,pendingTabId:'',home:{kind:'state',pins:[],tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===0,enabled:true}))}});
h.updateCategories();let selectionAtDispatch=-1;h.onTab=id=>{selectionAtDispatch=h.categories.findIndex(tab=>tab.selected);};h.selectTab(h.categories[2]);assert.equal(selectionAtDispatch,2,'selection changes before dispatch');
console.log('Home categories: selection, offline isolation and board summary scroll behavior passed');
let scrollOffset=0;Object.assign(h,{home:{board:{id:'7'}},homeChromeCollapsed:false,restoringScroll:false,getUIContext:()=>({animateTo:(_options,change)=>change()}),feedScroller:{currentOffset:()=>({yOffset:scrollOffset})}});scrollOffset=40;h.updateHomeChrome(40,1);assert.equal(h.homeChromeCollapsed,true,'scroll hides board summary');scrollOffset=20;h.updateHomeChrome(-20,1);assert.equal(h.homeChromeCollapsed,true,'threshold gap prevents layout oscillation');scrollOffset=0;h.updateHomeChrome(-20,1);assert.equal(h.homeChromeCollapsed,false,'top restores summary');h.restoringScroll=true;scrollOffset=100;h.updateHomeChrome(100,1);assert.equal(h.homeChromeCollapsed,false,'restoring viewport does not drive user animation');

h.restoringScroll=false;h.homeChromeCollapsed=true;scrollOffset=0;h.updateHomeChrome(0,0);assert.equal(h.homeChromeCollapsed,false,'scroll stop at top expands summary');scrollOffset=100;h.updateHomeChrome(0,0);assert.equal(h.homeChromeCollapsed,false,'idle viewport alone does not collapse summary');

assert(source.includes("tab.selected.toString() + ':' + tab.enabled.toString()"),'button identity must update with selected and enabled state');
assert(source.includes('if (current) this.selectTab(current);'),'click reads latest category state');
Object.assign(h,{offlinePreview:false,interactionReady:true,pendingTabId:'',home:{tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===0,enabled:true}))}});h.updateCategories();const selections=[];h.onTab=id=>selections.push(h.categories.find(tab=>tab.selected).id);h.selectTab(h.categories[1]);h.selectTab(h.categories[2]);h.selectTab(h.categories[0]);assert.deepEqual(selections,['art','icons','all'],'each online click updates selection before request dispatch');
