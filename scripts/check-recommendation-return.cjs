const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(name){const a=source.indexOf('  private '+name+'('),b=source.indexOf('\n  private ',a+1);assert(a>=0);return source.slice(a,b);}
const context={Date,PIN_NATIVE_DETAIL_READS_ENABLED:true,PIN_NATIVE_BOARD_READS_ENABLED:true,PIN_NATIVE_PROFILE_READS_ENABLED:true,PinmonyRuntimeLog:{info(){}}};
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('completeNativeBack')+method('closeProfileSettings')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,context);
for(const origin of ['https://www.pinterest.com','https://uk.pinterest.com']){
 const calls=[],page=origin+'/fixture/',h=new Host();const retained={screen:'recommend',recommendationTab:'activity',data:{page,activities:[{id:'123',recommendationClosed:true}]}};
 Object.assign(h,{profileSettingsVisible:true,settingsStore:retained,profileStore:{origins:[]},pageBackToken:2,nativeBackTarget:origin+'/old/board/',navigationAddress:origin+'/pin/123/',pinStore:{detail:{pinUrl:origin+'/pin/123/'}},boardStore:{boardDetail:{},pendingBoardUrl:'old',pendingBoardSource:'old'},nativeBusinessSessionContext:()=>({authenticated:true,origin}),returnCoordinator:{cancel:()=>calls.push('cancel')},boardNativeReads:{pause:()=>calls.push('pause')},clearDetail(){this.pinStore.detail=undefined;this.pinStore.detailOpeningPin='';},pageHistory:{cancelBack:()=>calls.push('history-cancel'),visit:p=>calls.push(p)},syncFloatingTabsMotion(){},currentProfileUrl:()=>page,returnToNativeProfile(){throw Error('settings cannot be treated as profile');}});
 assert(h.completeNativeBack(origin+'/edit/activity/'));assert.equal(h.navigationAddress,page);assert.equal(h.nativeBackTarget,'');assert.equal(h.boardStore.boardDetail,undefined);assert.equal(h.settingsStore,retained);assert.equal(h.settingsStore.recommendationTab,'activity');assert(h.nativeChildBackUntil>Date.now());assert.equal(h.pageBackToken,3);
 let back=0;h.pinStore.detail={};h.backFromDetail=()=>back++;h.closeProfileSettings();assert.equal(back,1);assert(h.profileSettingsVisible);
}
const exportsObject={};vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyRouteParser.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:exportsObject});
const parser=exportsObject.PinmonyRouteParser;
assert.equal(parser.boardUrlFromAddress('https://www.pinterest.com/edit/activity/'),'');assert.equal(parser.profileUrlFromAddress('https://www.pinterest.com/edit/'),'');assert.equal(parser.boardUrlFromAddress('https://www.pinterest.com/fixture/board/'),'https://www.pinterest.com/fixture/board/');
assert(source.indexOf('this.completeNativeBack(parent)')<source.indexOf('if(this.returnToNativeProfile(parent))'));
console.log('Recommendation return: retained activity, cleared stale board/return, duplicate lower-page back, regional origin and reserved routes passed');
