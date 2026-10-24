const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const searchRuntime=require('./search-controller-harness.cjs').createSearchRuntime(ts);
const src=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(name){const a=src.indexOf('  private '+name);assert(a>=0);return src.slice(a,src.indexOf('\n  private ',a+1)).replace('private ','');}
const logs=[];const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('async submitSearch(')+method('async selectSearchFilter(')+'}\nHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info:m=>logs.push(m)}});
async function main(){
const PrepareHost=vm.runInNewContext(ts.transpileModule('class Host {'+method('prepareSearchNavigation(')+'}\nHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Date});
const preparing=new PrepareHost();preparing.searchStore=new searchRuntime.Store();searchRuntime.bindIndex(preparing);
preparing.rootTabAddresses=new Map();preparing.tabRequestToken=0;preparing.waitForWebTabConfirmation=()=>{};
preparing.syncFloatingTabsMotion=()=>{};
const target='https://www.pinterest.com/search/pins/?q='+encodeURIComponent('插画');
preparing.prepareSearchNavigation(target);
assert.equal(preparing.searchStore.search.pageKey,target);assert.equal(preparing.searchStore.search.query,'插画');
assert.equal(preparing.searchStore.search.kind,'loading');assert.equal(preparing.searchStore.searchLoading,true);
assert.equal(preparing.searchStore.searchActionsReady,false);assert.equal(preparing.searchStore.searchInputReady,false);
const h=new Host(), events=[],page='https://www.pinterest.com/search/pins/?q=art';
h.searchStore={search:{session:1,pageKey:page},searchActionsReady:true,searchQueryToken:0,searchRequestToken:0,searchFilterToken:1,searchFilterOptions:[{id:'video',enabled:true,selected:false}]};
h.searchStore=Object.assign(new searchRuntime.Store(),h.searchStore);searchRuntime.bindIndex(h);h.authStatus='authenticated';h.activeTab=1;h.ensureRootActionContext=async()=>true;h.currentSearchPageKey=()=>page;h.clearRootTabGuard=()=>{};h.traceAction=()=>{};h.pageHistory={visit(){}};
h.nativeBusinessRoutesEnabled=false;h.prepareSearchNavigation=url=>events.push(['prepare',url]);h.controller={loadUrl:url=>events.push(['load',url]),runJavaScript:async()=>JSON.stringify('https://www.pinterest.com/search/videos/?q=art&rs=content_type_filter')};
await h.submitSearch('插画');assert.equal(events[0][0],'prepare');assert.equal(events[1][1],'https://www.pinterest.com/search/pins/?q='+encodeURIComponent('插画'));
const before=events.length;await h.submitSearch(' ');assert.equal(events.length,before);
h.activeSheetKind='searchFilter';h.dismissSearchFilters=()=>{h.activeSheetKind='';h.searchStore.searchFilterToken++;};
await h.selectSearchFilter('video');assert.equal(events.at(-2)[0],'prepare');assert.equal(events.at(-1)[1],'https://www.pinterest.com/search/videos/?q=art&rs=content_type_filter');assert.equal(h.showNativeSheet,false,'closing starts the Sheet disappearance before clearing its kind');
h.activeSheetKind='searchFilter';h.controller.runJavaScript=async()=>{h.searchStore.searchFilterToken++;return JSON.stringify('https://www.pinterest.com/search/videos/?q=art');};
const count=events.length;await h.selectSearchFilter('video');assert.equal(events.length,count,'closed or obsolete filter callback cannot navigate');
h.ensureRootActionContext=async()=>false;await h.submitSearch('denied');assert.equal(events.length,count);
console.log('Native search submit/type filter target registration, cancellation and readiness checks passed');}
main().catch(e=>{console.error(e);process.exitCode=1});
