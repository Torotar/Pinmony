const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const match=source.match(/private returnToNativeProfile\(target: string\): boolean \{([\s\S]*?)\n  \}/);
const fn=new Function('target','PIN_NATIVE_PROFILE_READS_ENABLED',ts.transpile(match[1]));
const page='https://www.pinterest.com/sample/';
for(const [mode,favorite,created] of [['pins',false,false],['pins',true,false],['pins',true,true],['boards',false,false]]){
 let selection='';const profile={profileUrl:page,hubMode:mode,hubFavorite:favorite,hubCreated:created};
 const h={pagePerformance:{begin(){}},markReturnedHome(){},profileStore:{profile,origins:[],profileScrollOffset:160},profileUrlFromAddress:()=>page,returnCoordinator:{cancel(){}},pageHistory:{cancelBack(){},visit(){}},pageBackToken:0,clearDetail(){},boardNativeReads:{pause(){}},boardStore:{},tabsController:{changeIndex(){}},profileNativeReads:{select:value=>{selection=value;}},syncFloatingTabsMotion(){}};
 assert(fn.call(h,page+'_created/',true));assert.equal(selection,'hub:'+mode+':'+Number(favorite)+':'+Number(created));assert.equal(h.profileStore.profileScrollOffset,160);assert.equal(h.profileStore.profile,profile);
}
const ui=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const names=['hubInitialScrollOffset','reportHubScroll','restoreScroll','reportScroll'];
const methods=names.map(name=>{const start=ui.indexOf('  private '+name+'(');assert(start>=0);return ui.slice(start,ui.indexOf('\n  }',start)+4);}).join('\n');
const pending=[],scopeExports={};vm.runInNewContext(ts.transpileModule('export class ScrollView {'+methods+'}',{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{exports:scopeExports,setTimeout:fn=>pending.push(fn),console});
const v=new scopeExports.ScrollView();let offset=0,reports=[];Object.assign(v,{hubTab:'pins',initialScrollOffset:640,interactionReady:true,restoringScroll:true,profile:{profileUrl:page,section:'created'},scroller:{scrollTo:args=>{offset=args.yOffset;},offset:()=>({yOffset:offset})},updateCompactHeader(){},onScrollPosition:(url,section,y)=>reports.push(y)});
assert.equal(v.hubInitialScrollOffset('pins'),640);assert.equal(v.hubInitialScrollOffset('boards'),0);
v.reportScroll();assert.equal(reports.length,0,'restoring layout cannot overwrite the saved offset');
v.restoreScroll();pending.shift()();assert.equal(offset,640);assert.equal(v.restoringScroll,false);v.reportScroll();assert.equal(reports.at(-1),640);
v.reportHubScroll('boards',page,'saved',0);assert.equal(reports.length,1,'hidden tabs cannot reset the active Pin position');
v.reportHubScroll('pins',page,'created',720);assert.equal(reports.at(-1),720);
v.interactionReady=false;v.reportHubScroll('pins',page,'created',0);v.reportScroll();assert.equal(reports.at(-1),720,'hidden pages cannot report teardown offsets');
assert.match(ui,/initialScrollOffset:this\.hubInitialScrollOffset\(tab\)/);assert.equal((ui.match(/this\.reportScroll\(\); this\.onPin\(pin\.id\)/g)||[]).length,2,'both image and title capture their current position before detail entry');
console.log('Profile Pin return: retained tabs, filters, snapshot, child scroll restoration, hidden-tab isolation and pre-entry capture passed');
