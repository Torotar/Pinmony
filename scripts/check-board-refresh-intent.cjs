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
  console.log('Board refresh: busy reads retain one refresh intent; pending writes remain protected');
})().catch(e=>{console.error(e);process.exitCode=1;});
