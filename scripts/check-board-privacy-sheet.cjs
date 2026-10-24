const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const src=fs.readFileSync('entry/src/main/ets/app/PinmonyBoardNativeReads.ets','utf8');
const start=src.indexOf('  async handle('),end=src.indexOf('\n  contentReady()',start);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+src.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_BOARD_READS_ENABLED:true});
function fixture(){const h=new Host(),writes=[];let finish,active=true;
 Object.assign(h,{bind:()=>true,current:()=>active,verified:true,ready:true,board:{name:'Current name',owner:{id:'42'}},viewer:'42',page:'board',revision:1,collection:()=>false,flow:undefined,
 readAuxiliary:async()=>{h.flow={phase:'edit',loading:true};await new Promise(r=>finish=r);if(h.flow.phase==='edit')Object.assign(h.flow,{loading:false,description:'Keep description',privacy:'public',recommend:true,invites:false,requests:true});},
 managementWrites:{submit:async value=>writes.push(JSON.parse(value))}});
 return {h,writes,finish:()=>finish(),leave:()=>active=false};}
(async()=>{
 const f=fixture(),p=f.h.handle('flow',JSON.stringify({action:'privacy',value:'secret'}));assert.equal(f.writes.length,0);f.finish();await p;
 assert.equal(f.writes.length,1);assert.deepEqual(f.writes[0],{action:'editSave',value:{name:'Current name',description:'Keep description',privacy:'secret',recommend:true,invites:false,requests:true}});
 const cancelled=fixture(),read=cancelled.h.handle('flow',JSON.stringify({action:'privacy',value:'secret'}));cancelled.h.flow.phase='';cancelled.finish();await read;assert.equal(cancelled.writes.length,0,'closing during read never writes');
 const left=fixture(),pending=left.h.handle('flow',JSON.stringify({action:'privacy',value:'secret'}));left.leave();left.finish();await pending;assert.equal(left.writes.length,0);
 const visitor=fixture();visitor.h.viewer='other';await visitor.h.handle('flow',JSON.stringify({action:'privacy',value:'secret'}));assert.equal(visitor.writes.length,0);
 console.log('Board privacy: fresh edit data, unchanged fields, owner-only write, close/leave cancellation passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
