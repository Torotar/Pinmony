const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');const exportsSession={};
let sourceY=10,measurements=0;
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageViewerSession.ets','utf8'),{compilerOptions:{target:99,module:ts.ModuleKind.CommonJS,experimentalDecorators:true}}).outputText,
 {exports:exportsSession,Observed:v=>v,require:name=>name==='common_foundation'?{PinmonyRuntimeLog:{info(){},warn(){}}}:{measureImageFlightOrigin:()=>{measurements++;return{x:0,y:sourceY,width:100,height:200};}}});
const Session=exportsSession.PinmonyImageViewerSession,flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){const session=new Session();let valid=true;const events=[];
 session.open({owner:'photo',imageUrl:'image',isCurrent:()=>valid,sourceId:()=>'',onReady(){},onClose:()=>events.push('close'),onClosed:()=>events.push('closed')});
 session.measure({},session.revision);session.rendered(session.revision);return{session,events,invalidate:()=>valid=false};}
async function main(){
 const {session,events}=fixture();let finishLayout,preparations=0;
 session.beforeReturn=()=>{preparations++;return new Promise(resolve=>finishLayout=resolve);};
 const initial=measurements;session.close();session.close();assert.equal(preparations,1);assert.equal(session.closing,false);assert.equal(measurements,initial);
 sourceY=42;finishLayout();await flush();assert.equal(session.origin.y,42,'destination uses restored status-bar layout');assert.equal(session.closing,true);assert.deepEqual(events,['close']);
 session.finish(session.revision);assert.deepEqual(events,['close','closed']);
 const old=fixture();let finishOld;old.session.beforeReturn=()=>new Promise(resolve=>finishOld=resolve);old.session.close();old.session.cancel();
 old.session.open({owner:'new',imageUrl:'image',isCurrent:()=>true,onClosed(){}});finishOld();await flush();assert.equal(old.session.closing,false);assert.equal(old.session.request.owner,'new');
 const invalid=fixture();let finishInvalid;invalid.session.beforeReturn=()=>new Promise(resolve=>finishInvalid=resolve);invalid.session.close();invalid.invalidate();finishInvalid();await flush();assert.equal(invalid.session.closing,false);
 const rejected=fixture();rejected.session.beforeReturn=()=>Promise.reject(Error('native'));rejected.session.close();await flush();assert.equal(rejected.session.closing,true,'failure cannot trap the viewer');
 const host=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyImageViewerHost.ets','utf8');
 assert(!host.includes('this.session.beforeReturn = async'),'unchanged safe area needs no early bar restore or return layout wait');
 const method=host.match(/private onViewerTransition\(expanded: number\): void \{([\s\S]*?)\n  \}/);
 assert(method,'host provides transition handler');
 const hostExports={},barEvents=[];
 vm.runInNewContext(ts.transpileModule('exports.handle = function(expanded: number) {'+method[1]+'};',{compilerOptions:{target:99,module:ts.ModuleKind.CommonJS}}).outputText,
  {exports:hostExports,PinmonyViewerSystemBars:{release:(owner,context)=>barEvents.push(['release',owner,context])}});
 let current=true;const context={},forwarded=[];
 const target={hostRevision:7,systemBarOwner:12,systemBarContext:context,session:{current:revision=>current&&revision===7,transition:(revision,expanded)=>forwarded.push([revision,expanded])}};
 hostExports.handle.call(target,1);assert.equal(barEvents.length,0,'opening retains status cover');
 hostExports.handle.call(target,0);assert.equal(barEvents.length,1,'return start restores status without waiting for finish');
 assert.equal(barEvents[0][1],12);assert.equal(barEvents[0][2],context);assert.equal(target.systemBarOwner,0);
 hostExports.handle.call(target,0);assert.equal(barEvents.length,1,'duplicate return does not release twice');
 assert.deepEqual(forwarded,[[7,1],[7,0],[7,0]],'blur transition continues in the same callback');
 current=false;target.systemBarOwner=13;hostExports.handle.call(target,0);
 assert.equal(barEvents.length,1);assert.equal(forwarded.length,3,'stale host cannot restore or animate current viewer');
 console.log('Viewer return: status restore at transition start, duplicate return, stale host, blur forwarding, cancellation/reopen and rejected preparation passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
