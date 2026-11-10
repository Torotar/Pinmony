const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const output={},pending=[],calls=[],logs=[];let resolveWindow;
const mainWindow={setWindowSystemBarProperties:props=>{calls.push(props);return new Promise((resolve,reject)=>pending.push({resolve,reject}));}};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyViewerSystemBars.ets','utf8'),{compilerOptions:{target:99,module:ts.ModuleKind.CommonJS}}).outputText,
 {exports:output,AppStorage:{setOrCreate(){},get(){return false;}},require:name=>name==='@kit.ArkUI'?{window:{getLastWindow:()=>new Promise(resolve=>resolveWindow=resolve)}}:{PinmonyRuntimeLog:{warn:s=>logs.push(s)}}});
const bars=output.PinmonyViewerSystemBars,flush=()=>new Promise(resolve=>setImmediate(resolve));
async function main(){
 let owner=bars.acquire({});bars.release(owner,{});resolveWindow(mainWindow);await flush();assert.equal(calls.length,0,'closed before window lookup must not hide');
 owner=bars.acquire({});resolveWindow(mainWindow);await flush();assert.deepEqual(JSON.parse(JSON.stringify(calls[0])),{statusBarColor:'#00000000',statusBarContentColor:'#00000000'});
 const restored=bars.release(owner,{});let completed=false;restored.then(()=>completed=true);
 pending.shift().resolve();await flush();assert.equal(completed,false,'restoration promise waits for the native restore');
 assert.deepEqual(JSON.parse(JSON.stringify(calls[1])),{statusBarColor:'#00000000',statusBarContentColor:'#1B1E25'},'restore keeps native layout unchanged');
 const next=bars.acquire({});pending.shift().resolve();await flush();assert.deepEqual(JSON.parse(JSON.stringify(calls[2])),{statusBarColor:'#00000000',statusBarContentColor:'#00000000'},'new viewer wins over pending restore');pending.shift().resolve();await flush();
 bars.release(owner,{});await flush();assert.equal(calls.length,3,'stale host cannot restore new viewer');
 const second=bars.acquire({});bars.release(next,{});await flush();assert.equal(calls.length,3,'remaining viewer keeps bar hidden');
 bars.release(second,{});await flush();assert.deepEqual(JSON.parse(JSON.stringify(calls[3])),{statusBarColor:'#00000000',statusBarContentColor:'#1B1E25'});pending.shift().resolve();await flush();
 owner=bars.acquire({});resolveWindow(mainWindow);await flush();pending.shift().reject(Error('native'));await flush();assert.equal(logs.length,1);
 bars.release(owner,{});await flush();
 const host=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyImageViewerHost.ets','utf8');
 assert(host.includes('PinmonyViewerSystemBars.acquire(context)'));assert(host.includes('PinmonyViewerSystemBars.release(this.systemBarOwner, context)'));
 assert(host.includes('this.systemBarContext = context'));
 assert(!fs.readFileSync('feature_pin/src/main/ets/services/PinmonyViewerSystemBars.ets','utf8').includes('setSpecificSystemBarEnabled('),'viewer never changes system avoid areas');
 console.log('Viewer status bar: hide/restore, early return, late native completion, replacement owners, multiple leases, failed calls and shared host wiring passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
