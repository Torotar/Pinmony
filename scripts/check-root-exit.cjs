const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=source.indexOf('  onBackPress(): boolean'),end=source.indexOf('\n  @Builder',start);
let now=10000,exits=0;const messages=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Date:{now:()=>now},PinmonyI18n:{message:x=>x},PinmonyRuntimeLog:{warn:()=>{}}});
function host(){const h=new Host();h.rootExitBackAt=0;h.authStatus='authenticated';h.showMessage=m=>messages.push(m);h.getUIContext=()=>({getHostContext:()=>({terminateSelf:()=>{exits++;return Promise.resolve();}})});h.navigationCoordinator={onBackPress:()=>h.handleRootExitBack()};return h;}
for(const tab of [0,1,2,3]){const h=host();h.activeTab=tab;const count=exits;assert.equal(h.onBackPress(),true);assert.equal(exits,count);now+=100;h.onBackPress();assert.equal(exits,count+1);}
let h=host();h.onBackPress();now+=2001;const count=exits;h.onBackPress();assert.equal(exits,count);now+=100;h.onBackPress();assert.equal(exits,count+1);
h=host();h.onBackPress();h.navigationCoordinator.onBackPress=()=>true;h.onBackPress();assert.equal(h.rootExitBackAt,0);h.navigationCoordinator.onBackPress=()=>h.handleRootExitBack();const before=exits;h.onBackPress();assert.equal(exits,before);
h=host();h.authStatus='checking';h.offlinePreviewMode=false;h.authWebVisible=()=>false;h.navigationCoordinator.onBackPress=()=>{throw Error('session loading must not delegate back');};
let loadingExits=exits, notices=messages.length;assert.equal(h.onBackPress(),true);assert.equal(exits,loadingExits);assert.equal(messages.length,notices+1);now+=100;assert.equal(h.onBackPress(),true);assert.equal(exits,loadingExits+1);
h=host();h.authStatus='checking';h.offlinePreviewMode=false;h.authWebVisible=()=>false;h.onBackPress();now+=2001;loadingExits=exits;h.onBackPress();assert.equal(exits,loadingExits);now+=100;h.onBackPress();assert.equal(exits,loadingExits+1);
h=host();h.authStatus='error';h.offlinePreviewMode=false;h.authWebVisible=()=>false;h.navigationCoordinator.onBackPress=()=>{throw Error('session error must not delegate back');};loadingExits=exits;h.onBackPress();assert.equal(exits,loadingExits);now+=100;h.onBackPress();assert.equal(exits,loadingExits+1);
h=host();h.authStatus='checking';h.offlinePreviewMode=false;h.authWebVisible=()=>true;h.navigationCoordinator.onBackPress=()=>false;assert.equal(h.onBackPress(),false,'visible login retains existing back handling');
h=host();h.authStatus='checking';h.offlinePreviewMode=true;h.authWebVisible=()=>false;h.navigationCoordinator.onBackPress=()=>false;assert.equal(h.onBackPress(),false,'offline preview retains existing back handling');
assert.match(source,/onPageHide\(\): void \{\s*this.rootExitBackAt = 0;/);
console.log('Root exit: four tabs and session loading, first notice, second exit, timeout, login delegation, child handling and background reset passed');
