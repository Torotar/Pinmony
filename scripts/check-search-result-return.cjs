const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=source.indexOf('  private backFromSearch():');
const method=source.slice(start,source.indexOf('\n  private ',start+1)).replace('private ','');
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method+'}',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText+'\nHost;',{PINTEREST_URL:'https://www.pinterest.com/',setTimeout:()=>{},PinmonyRuntimeLog:{info(){}}});
for(const page of ['https://uk.pinterest.com/search/pins/?q=design','https://uk.pinterest.com/search/?q=design','https://www.pinterest.com/search/videos/?q=design']){
const host=new Host(),calls=[];host.pinStore={}; host.searchStore={search:{query:'design'},searchScrollOffset:0,searchCache:{put:()=>{}}};
host.currentPinUrl=()=>'';host.currentSearchPageKey=()=>page;host.search={query:'design'};
host.rootTabAddresses=new Map();host.clearRootTabGuard=()=>{};
host.searchInputFocused=true;host.searchInputStopEditing=()=>calls.push('blur');
host.pageHistory={cancelBack:()=>calls.push('cancel'),visit:()=>{},prepareBackTo:target=>calls.push(target),isPending:()=>true};
host.searchCache={put:()=>{}};host.clearSearch=()=>{host.search=undefined;host.searchStore.search=undefined};host.searchPlaceholder=()=>({});host.controller={loadUrl:target=>calls.push(target)};
host.restoreRetainedSearch=()=>false;
host.backFromSearch();const expected=new URL(page).origin+'/search/';assert.equal(calls.at(-1),expected);
assert.ok(calls.includes('cancel'));assert.equal(host.search,undefined);assert.equal(host.activeTab,1);
assert.equal(host.nativeBackTarget,expected);assert.equal(host.rootTabAddresses.get(1),expected);
assert.equal(host.searchStore.search.pageKey,expected);assert.equal(host.searchStore.searchLoading,true);
}
console.log('Search results return with focused input, stale history and root-query routes passed');
