const fs=require('node:fs'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const {runtime,bind}=require('./pin-priority-controller-harness.cjs');
const pin='https://www.pinterest.com/pin/101/';
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function harness(){
 const r=runtime(ts),store=new r.PinmonyPinStore(),calls=[],pending=[];
 store.detail={pinUrl:pin,actions:[],related:[]};store.detailActionsReady=true;
 const native={pinStore:store,homeStore:{},profileStore:{},authStatus:'authenticated',businessSuspended:false,activeSheetKind:'',showNativeSheet:false,
  isCurrentMorePin:value=>value===pin,webJsonText:s=>s,controller:{getUrl:()=>pin,runJavaScript:s=>{calls.push(s);return new Promise((resolve,reject)=>pending.push({resolve,reject}));}}};
 bind(native,ts,{},['sharePanels']);return{native,store,calls,pending};
}
async function main(){
 const h=harness(),opening=h.native.sharePanelsController.openApiDetailMore();
 assert(h.store.moreLoading);assert.equal(h.native.activeSheetKind,'more');
 h.pending.shift().resolve('true');await flush();
 assert(h.calls[0].includes('detailMoreOpen'));assert(h.calls[1].includes('detailMoreRead'));
 h.pending.shift().resolve(JSON.stringify({session:1,pin,options:[{id:'download',label:'下载',enabled:true}]}));await opening;
 assert.equal(h.store.moreOptions[0].id,'download');assert.equal(h.store.moreLoading,false);
 assert(!h.calls.some(s=>s.includes('PinmonyDetailMore(')||s.includes('.click(')),'API reader must not dispatch historical DOM controls');
 const invalid=harness(),reading=invalid.native.sharePanelsController.openApiDetailMore();invalid.pending.shift().resolve('true');await flush();
 invalid.pending.shift().resolve(JSON.stringify({session:2,pin,options:[{id:'wrong',label:'wrong'}]}));await reading;
 assert.equal(invalid.store.moreOptions.length,0);assert(invalid.store.moreError);
 const failure=harness(),failed=failure.native.sharePanelsController.openApiDetailMore();failure.pending.shift().resolve('false');await failed;
 assert.equal(failure.calls.length,1);assert(failure.store.moreError);assert.equal(failure.store.moreOptions.length,0);
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 assert(index.includes('await this.sharePanelsController.openApiDetailMore()'));
 assert(fs.readFileSync('entry/src/main/ets/app/PinmonyPhotoMenuCoordinator.ets','utf8').includes('window.PinmonyPostApi.homeMenuOpen('),'custom photo menu keeps its confirmed resource flow');
 console.log('Detail menu: real API open/read, validated session/object, explicit failure, no automatic DOM fallback and custom photo menu binding passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
