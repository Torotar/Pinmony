const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]);
const s=fs.readFileSync('feature_settings/src/main/ets/components/PinmonySettingsPage.ets','utf8');
// Loading belongs to the active child too. Removing retained root rows clamps
// its live List offset even though the saved offset is still correct.
const ast=ts.createSourceFile('Settings.ts',s,ts.ScriptTarget.Latest,true);
function checkRetainedRows(node,conditions=[]){
  const next=ts.isIfStatement(node)?conditions.concat(node.expression.getText(ast)):conditions;
  if(ts.isCallExpression(node)&&node.expression.getText(ast)==='ForEach'&&node.arguments[0]?.getText(ast)==='this.options'){
    assert(!conditions.some(condition=>condition.includes('this.store.loading')),'child loading must not remove settings root options');
  }
  ts.forEachChild(node,child=>checkRetainedRows(child,next));
}
checkRetainedRows(ast);
const methods=s.slice(s.indexOf('  private captureRootScroll('),s.indexOf('  private async exportLog('));
const tasks=[];const Type=vm.runInNewContext(ts.transpileModule('class Page {'+methods+'} Page;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{setTimeout:f=>tasks.push(f)});
const p=new Type();let offset=280;Object.assign(p,{pageVisible:true,restoreRevision:0,restoringRootScroll:false,store:{screen:'root',rootScrollOffset:0},contentScroller:{currentOffset:()=>({yOffset:offset}),scrollTo:v=>{offset=v.yOffset}}});
p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280);p.store.screen='display';offset=0;p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280);
p.store.screen='root';p.restoreRootScroll();p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280,'new list zero offset cannot overwrite saved position');tasks.shift()();assert.equal(offset,280);assert(!p.restoringRootScroll);
p.restoreRootScroll();p.store.screen='notifications';offset=0;tasks.shift()();assert.equal(offset,0,'late restore cannot scroll a child page');
assert.equal(p.restoringRootScroll,false,'abandoned root restore releases capture guard');
p.store.screen='root';p.restoreRootScroll();tasks.shift()();assert.equal(offset,280);
p.restoreRootScroll();const oldRestore=tasks.shift();p.restoreRootScroll();oldRestore();assert(p.restoringRootScroll,'stale task must not release newer restore guard');tasks.shift()();assert(!p.restoringRootScroll);
p.restoreRootScroll();p.pageVisible=false;tasks.shift()();assert(!p.restoringRootScroll,'hidden-page restore releases its guard');p.pageVisible=true;
for(const screen of ['account','visibility','recommend','display','social','notifications','sessionAccounts','about']){
  p.store.screen='root';p.store.loading=false;offset=280;p.captureRootScroll();
  p.store.screen=screen;p.store.loading=true;p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280,screen+' loading preserves root offset');
  p.store.loading=false;p.store.screen='root';p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280,screen+' retained List still holds offset on return');
}
console.log('Settings scroll: child round-trip, new-list zero offset and late restore isolation passed');

const {createArktsLoader}=require('./arkts-module-loader.cjs');const {PinmonySettingsStore}=createArktsLoader(ts,{}).loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets');const store=new PinmonySettingsStore();store.rootScrollOffset=280;store.reset(true);assert.equal(store.rootScrollOffset,280);store.reset();assert.equal(store.rootScrollOffset,0,'account/session reset clears scroll');
