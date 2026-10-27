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
  h.store.boardDetail.flow={};h.flow={phase:'section',sectionId:'456',loading:false};let sectionReads=0;h.readSection=async(id,append)=>{assert.equal(id,'456');assert.equal(append,false);sectionReads++;};await h.refresh();assert.equal(sectionReads,1);assert.equal(reads,1,'section refresh must not navigate to board root');h.flow.loading=true;await h.refresh();assert.equal(sectionReads,1,'coalesce active section refresh');
  console.log('Board refresh: busy reads retain one refresh intent; pending writes remain protected');
})().catch(e=>{console.error(e);process.exitCode=1;});

const file=ts.createSourceFile('board.ts',src,99,true);let confirmed='';
function visit(n){if(ts.isMethodDeclaration(n)&&n.name.getText(file)==='pinWriteConfirmed')confirmed=n.getText(file);ts.forEachChild(n,visit);}visit(file);
const Confirmed=vm.runInNewContext(ts.transpileModule('class Confirmed {'+confirmed+'} Confirmed;',{compilerOptions:{target:99}}).outputText);
for(const action of ['move','moveSection','deleteSelected']){
 const host=new Confirmed(),calls=[];Object.assign(host,{current:()=>true,board:{pin_count:5},sectionSource:{sectionId:'456'},flow:{phase:'targets'},pins:[{id:'11'},{id:'12'}],sections:[{id:'456'}],ports:{},count:x=>x,emptyFlow:()=>({}),syncAuxiliary(){},pause(){calls.push('cancel-old');},readSection(id,append){assert.equal(append,false);calls.push('section:'+id);},readSections(force){assert.equal(force,true);calls.push('sections');},read(){throw Error('must retain section destination');}});
 host.pinWriteConfirmed(action,['11'],'');assert.equal(host.pins.length,1);assert.equal(host.sections.length,1);assert.equal(host.sectionSource,undefined);assert.equal(host.sectionsReady,false);assert.deepEqual(calls,['cancel-old','section:456','sections']);
}
console.log('Confirmed section moves: source retained, old reads cancelled, source content and previews revalidated passed');
