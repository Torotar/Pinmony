const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const src=fs.readFileSync('entry/src/main/ets/app/PinmonyBoardNativeReads.ets','utf8');
const start=src.indexOf('  async refresh()'),end=src.indexOf('\n  async more()',start);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+src.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){}}});
(async()=>{
  const h=new Host();let reads=0;
  Object.assign(h,{bind:()=>true,busy:true,store:{boardDetail:{}},pause(){this.refreshQueued=false;},read:async()=>{reads++;}});
  await h.refresh();await h.refresh();assert.equal(reads,0);assert.equal(h.refreshQueued,true);
  assert(src.includes('if(this.refreshQueued){this.refreshQueued = false;this.refresh();}'),'read completion consumes one queued refresh');
  h.busy=false;await h.refresh();assert.equal(reads,1);
  h.store.boardDetail.flow={busy:true};await h.refresh();assert.equal(reads,1,'pending writes cannot be cancelled by refresh');
  h.store.boardDetail.flow={};h.flow={phase:'section',sectionId:'456',loading:false};let sectionReads=0;h.readSection=async(id,append,refresh)=>{assert.equal(id,'456');assert.equal(append,false);assert.equal(refresh,true);sectionReads++;};await h.refresh();assert.equal(sectionReads,1);assert.equal(reads,1,'section refresh must not navigate to board root');h.flow.loading=true;await h.refresh();assert.equal(sectionReads,1,'coalesce active section refresh');
  console.log('Board refresh: busy reads retain one refresh intent; pending writes remain protected');
})().catch(e=>{console.error(e);process.exitCode=1;});

const file=ts.createSourceFile('board.ts',src,99,true);let confirmed='';
function visit(n){if(ts.isMethodDeclaration(n)&&n.name.getText(file)==='pinWriteConfirmed')confirmed=n.getText(file);ts.forEachChild(n,visit);}visit(file);
const Confirmed=vm.runInNewContext(ts.transpileModule('class Confirmed {'+confirmed+'} Confirmed;',{compilerOptions:{target:99}}).outputText);
for(const action of ['move','moveSection','deleteSelected']){
 const host=new Confirmed(),calls=[];Object.assign(host,{current:()=>true,board:{pin_count:5},sectionSource:{sectionId:'456'},flow:{phase:'targets'},pins:[{id:'11'},{id:'12'}],sections:[{id:'456'}],ports:{},count:x=>x,emptyFlow:()=>({}),syncAuxiliary(){},pause(){calls.push('cancel-old');},revalidateSectionAfterWrite(source,ids){assert.equal(source.sectionId,'456');assert.equal(ids[0],'11');calls.push('revalidate');}});
 host.pinWriteConfirmed(action,['11'],'');assert.equal(host.pins.length,1);assert.equal(host.sections.length,1);assert.equal(host.sectionSource,undefined);assert.equal(host.sectionsReady,false);assert.deepEqual(calls,['cancel-old','revalidate']);
}
console.log('Confirmed section moves: source retained, old reads cancelled, source content and previews revalidated passed');
const boardPage=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');
assert(boardPage.includes("this.phase() === 'section' ? JSON.stringify(this.snapshot.flow?.pins || []) : ''"),'section list identity tracks the updated Pin snapshot');

let revalidate='';
function findRevalidate(n){if(ts.isMethodDeclaration(n)&&n.name.getText(file)==='revalidateSectionAfterWrite')revalidate=n.getText(file);ts.forEachChild(n,findRevalidate);}findRevalidate(file);
const Revalidate=vm.runInNewContext(ts.transpileModule('class Revalidate {'+revalidate+'} Revalidate;',{compilerOptions:{target:99}}).outputText,{PinmonyRuntimeLog:{info(){}},PinmonyI18n:{message:x=>x},setTimeout:cb=>setImmediate(cb)});
(async()=>{
 const host=new Revalidate(), calls=[];let finish;
 Object.assign(host,{revision:3,current:()=>true,readSection(id,append,refresh,operation){calls.push('section');assert.equal(id,'456');assert.equal(refresh,true);assert.equal(operation,true);return new Promise(resolve=>{finish=resolve;});},read(append,refresh,operation){calls.push('board');assert.equal(refresh,true);assert.equal(operation,true);}});
 const source={sectionId:'456',pins:[{id:'11'},{id:'12'}]};const pending=host.revalidateSectionAfterWrite(source,['11']);assert.equal(source.pins.length,1);assert.equal(source.pins[0].id,'12');assert.deepEqual(calls,['section']);finish();await pending;assert.deepEqual(calls,['section','board']);
 const stale=host.revalidateSectionAfterWrite(source,[]);host.revision++;finish();await stale;assert.deepEqual(calls,['section','board','section']);
 console.log('Post-move revalidation reads section then parent board and rejects stale callbacks');
})().catch(e=>{console.error(e);process.exitCode=1;});

(async()=>{
 const host=new Revalidate();let reads=0,boardReads=0,applied=[];
 Object.assign(host,{revision:1,sectionEpoch:1,version:0,current:()=>true,ports:{install(){}},installScript:()=>'',apply(){applied.push(host.flow.pins.map(p=>p.id).join(','));},async readSection(){reads++;host.flow.pins=[{id:'11'},{id:'12'}];},async read(){boardReads++;}});
 await host.revalidateSectionAfterWrite({sectionId:'456',pins:[{id:'11'},{id:'12'}]},['11']);
 assert.equal(reads,4,'stale reads have a bounded retry count');assert.equal(boardReads,1);
 assert.equal(host.flow.error,'pm_board_section_sync_pending');assert(applied.every(ids=>ids==='12'),'confirmed moved Pin stays removed from applied snapshots');
 console.log('Stale section reads retry within a bound and report pending synchronization');
})().catch(e=>{console.error(e);process.exitCode=1;});

let sectionRead='';
function findSection(n){if(ts.isMethodDeclaration(n)&&n.name.getText(file)==='readSection')sectionRead=n.getText(file);ts.forEachChild(n,findSection);}findSection(file);
const SectionReader=vm.runInNewContext(ts.transpileModule('class SectionReader {'+sectionRead+'} SectionReader;',{compilerOptions:{target:99}}).outputText,{PinmonyI18n:{message:x=>x}});
(async()=>{
 const h=new SectionReader(), pin={id:'1'};let finish, snapshots=[];
 Object.assign(h,{sections:[{id:'456',title:'Section'}],flow:{phase:'section',sectionId:'456',pins:[pin]},sectionEpoch:0,revision:0,sectionCursor:'old',refreshedCancelledIds:new Set(),ports:{install(){}} ,current:()=>true,cancelSection(){this.sectionEpoch++;},emptyFlow:()=>({pins:[],loading:false,error:''}),apply(){snapshots.push({loading:this.flow.loading,refreshing:this.flow.refreshing,pins:this.flow.pins.length});},request:()=>new Promise((resolve,reject)=>{finish={resolve,reject};}),mapPins:()=>[{id:'2'}],digits:v=>/^\d+$/.test(v),next:()=>'',installScript:()=>''});
 let pending=h.readSection('456',false,true);assert.equal(h.flow.pins[0].id,'1');assert.equal(h.flow.refreshing,true);finish.resolve({resource_response:{data:[{type:'pin',id:'2'}]}});await pending;assert.equal(h.flow.pins[0].id,'2');assert.equal(h.flow.refreshing,false);
 pending=h.readSection('456',false,true);finish.reject(Error('offline'));await pending;assert.equal(h.flow.pins[0].id,'2','failed refresh retains existing section content');assert(h.flow.error);assert.equal(h.flow.refreshing,false);console.log('Section refresh retains old content on failure and replaces it after a validated response');
})().catch(e=>{console.error(e);process.exitCode=1;});
