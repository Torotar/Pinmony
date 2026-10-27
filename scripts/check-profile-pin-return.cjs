const assert=require('node:assert/strict'),fs=require('node:fs'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const match=source.match(/private returnToNativeProfile\(target: string\): boolean \{([\s\S]*?)\n  \}/);
const fn=new Function('target','PIN_NATIVE_PROFILE_READS_ENABLED',ts.transpile(match[1]));
const page='https://www.pinterest.com/sample/';
for(const [mode,favorite,created] of [['pins',false,false],['pins',true,false],['pins',true,true],['boards',false,false]]){
 let selection='';const profile={profileUrl:page,hubMode:mode,hubFavorite:favorite,hubCreated:created};
 const h={profileStore:{profile,origins:[],profileScrollOffset:160},profileUrlFromAddress:()=>page,returnCoordinator:{cancel(){}},pageHistory:{cancelBack(){},visit(){}},pageBackToken:0,clearDetail(){},boardNativeReads:{pause(){}},boardStore:{},tabsController:{changeIndex(){}},profileNativeReads:{select:value=>{selection=value;}},syncFloatingTabsMotion(){}};
 assert(fn.call(h,page+'_created/',true));assert.equal(selection,'hub:'+mode+':'+Number(favorite)+':'+Number(created));assert.equal(h.profileStore.profileScrollOffset,160);assert.equal(h.profileStore.profile,profile);
}
console.log('Profile Pin return: retained tabs, combined filters, snapshot and scroll passed');
