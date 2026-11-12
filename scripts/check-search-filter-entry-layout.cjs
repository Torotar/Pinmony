const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const begin=source.indexOf('  private nativeModalHeight()');
const end=source.indexOf('  private nativeSheetUsesThemedModal()',begin);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(begin,end)+'} Host;',{}).outputText,{SheetSize:{MEDIUM:1,LARGE:2,FIT_CONTENT:3}});
const host=new Host();host.activeSheetKind='searchFilter';
for(const phase of ['loading','ready','error','empty']){host.searchStore={searchFilterLoading:phase==='loading',searchFilterOptions:phase==='ready'?[{}]:[]};assert.equal(host.nativeModalHeight(),1,'filter detent stays stable during '+phase);}
host.activeSheetKind='comments';assert.equal(host.nativeModalHeight(),2);
host.activeSheetKind='publish';assert.equal(host.nativeModalHeight(),3,'other intrinsic sheets are unchanged');
assert(source.includes("this.activeSheetKind === 'edit' || this.activeSheetKind === 'searchFilter'"),'filter uses full-content HDS branch, avoiding initial 1vp intrinsic measurement');
const sheet=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchFilterSheet.ets','utf8');
assert(sheet.includes('.layoutWeight(1)'),'options scroll inside bounded body');
assert(sheet.includes(".height('100%')"));assert(!sheet.includes('maxHeight: 520'));
console.log('Search filter entry: fixed detent across loading/ready/error/empty, bounded scrolling, other sheet sizing preserved');
