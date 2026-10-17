const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
function method(name){const a=source.indexOf('  private '+name+'(');assert(a>=0);const b=source.indexOf('\n  private ',a+1);return source.slice(a,b);}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('updateCategories')+method('selectTab')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const h=new Host(),calls=[];Object.assign(h,{home:{tabs:['all','art','icons'].map((id,index)=>({id,label:id,selected:index===1,enabled:index!==2}))},pendingTabId:'',interactionReady:true,onTab:id=>calls.push(id)});
h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),1);
h.selectTab(h.categories[1]);h.selectTab(h.categories[2]);assert.equal(calls.length,0);
h.selectTab(h.categories[0]);assert.deepEqual(calls,['all']);
h.pendingTabId='all';h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),0);
h.interactionReady=false;h.selectTab(h.categories[1]);assert.equal(calls.length,1);
h.pendingTabId='';h.updateCategories();assert.equal(h.categories.findIndex(tab=>tab.selected),1,'failure restores confirmed selection');
h.home.tabs=[];h.updateCategories();assert.equal(h.categories.length,0);
assert(source.includes('type: ButtonType.Capsule'));assert(source.includes('.accessibilitySelected(tab.selected)'));assert(!source.includes('CapsuleSegmentButtonV2')); assert(source.includes('.scrollable(ScrollDirection.Horizontal)')); assert(!source.includes('Chip('));
console.log('Home subtabs: confirmed/pending selection, unavailable and interaction gates passed');
