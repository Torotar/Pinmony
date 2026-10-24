const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=source.indexOf('  onBackPress(): boolean'),end=source.indexOf('\n  @Builder',start);
let now=10000,exits=0;const messages=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Date:{now:()=>now},PinmonyI18n:{message:x=>x},PinmonyRuntimeLog:{warn:()=>{}}});
function host(){const h=new Host();h.rootExitBackAt=0;h.showMessage=m=>messages.push(m);h.getUIContext=()=>({getHostContext:()=>({terminateSelf:()=>{exits++;return Promise.resolve();}})});h.navigationCoordinator={onBackPress:()=>h.handleRootExitBack()};return h;}
for(const tab of [0,1,2,3]){const h=host();h.activeTab=tab;const count=exits;assert.equal(h.onBackPress(),true);assert.equal(exits,count);now+=100;h.onBackPress();assert.equal(exits,count+1);}
let h=host();h.onBackPress();now+=2001;const count=exits;h.onBackPress();assert.equal(exits,count);now+=100;h.onBackPress();assert.equal(exits,count+1);
h=host();h.onBackPress();h.navigationCoordinator.onBackPress=()=>true;h.onBackPress();assert.equal(h.rootExitBackAt,0);h.navigationCoordinator.onBackPress=()=>h.handleRootExitBack();const before=exits;h.onBackPress();assert.equal(exits,before);
assert.match(source,/onPageHide\(\): void \{\s*this.rootExitBackAt = 0;/);
console.log('Root exit: four tabs, first notice, second exit, timeout, child handling and background reset passed');
