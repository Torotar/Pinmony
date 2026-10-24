const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]);
const s=fs.readFileSync('feature_settings/src/main/ets/components/PinmonySettingsPage.ets','utf8');
const methods=s.slice(s.indexOf('  private captureRootScroll('),s.indexOf('  private async exportLog('));
const tasks=[];const Type=vm.runInNewContext(ts.transpileModule('class Page {'+methods+'} Page;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{setTimeout:f=>tasks.push(f)});
const p=new Type();let offset=280;Object.assign(p,{pageVisible:true,restoreRevision:0,restoringRootScroll:false,store:{screen:'root',rootScrollOffset:0},contentScroller:{currentOffset:()=>({yOffset:offset}),scrollTo:v=>{offset=v.yOffset}}});
p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280);p.store.screen='display';offset=0;p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280);
p.store.screen='root';p.restoreRootScroll();p.captureRootScroll();assert.equal(p.store.rootScrollOffset,280,'new list zero offset cannot overwrite saved position');tasks.shift()();assert.equal(offset,280);assert(!p.restoringRootScroll);
p.restoreRootScroll();p.store.screen='notifications';offset=0;tasks.shift()();assert.equal(offset,0,'late restore cannot scroll a child page');
p.store.screen='root';p.restoreRootScroll();tasks.shift()();assert.equal(offset,280);
console.log('Settings scroll: child round-trip, new-list zero offset and late restore isolation passed');

const {createArktsLoader}=require('./arkts-module-loader.cjs');const {PinmonySettingsStore}=createArktsLoader(ts,{}).loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets');const store=new PinmonySettingsStore();store.rootScrollOffset=280;store.reset(true);assert.equal(store.rootScrollOffset,280);store.reset();assert.equal(store.rootScrollOffset,0,'account/session reset clears scroll');
