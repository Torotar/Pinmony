const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function main(){
  const source=fs.readFileSync('feature_pin/src/main/ets/services/PinmonyPostApiScript.ets','utf8');
  const script=Function('return `'+source.match(/= `([\s\S]*?)`;/)[1]+'`')();
  const requests=[],listeners={},pin='https://www.pinterest.com/pin/101/';
  const location={href:pin,origin:'https://www.pinterest.com',hostname:'www.pinterest.com',pathname:'/pin/101/'};
  const window={PinmonyPostApiEnabled:true,addEventListener(k,fn){listeners[k]=fn;},
    PinmonyDetailApi:{raw:()=>({id:'101',tracking_params:'synthetic'})},
    PinmonyShareBridge:{postState(){}}};window.top=window;
  window.fetch=(url,options)=>new Promise((resolve,reject)=>{
    const record={url,options,resolve,aborted:false};requests.push(record);
    options.signal.addEventListener('abort',()=>{record.aborted=true;const e=Error('cancelled');e.name='AbortError';reject(e);},{once:true});
  });
  vm.runInNewContext(script,{window,location,document:{cookie:'csrftoken=synthetic'},URL,URLSearchParams,Headers,AbortController,
    XMLHttpRequest:class {open(){}setRequestHeader(){}send(){}},fetch:(...args)=>window.fetch(...args),setTimeout,clearTimeout,console});
  const api=window.PinmonyPostApi,snapshot={session:1,pinUrl:pin,pinDetail:true,options:[],actions:[]};
  api.shareSnapshot({...snapshot},()=>{});assert.equal(requests.length,1);
  api.shareSearch(1,'a');assert(requests[0].aborted,'new query cancels the older read');
  api.shareSearch(1,'gg');assert(requests[1].aborted,'in-flight typeahead is cancelled without replay');
  const last=requests[2];last.resolve({ok:true,status:200,json:async()=>({resource_response:{status:'success',code:0,
    data:{items:[{id:'22',username:'gg',full_name:'Latest'}]}}})});await flush();
  const accepted=api.shareSnapshot({...snapshot},()=>{});assert.equal(accepted.contacts.length,1);assert(accepted.contacts[0].label.includes('Latest'));
  api.shareSearch(1,'next');api.shareClose();await flush();assert(requests[3].aborted,'closing cancels the outstanding read');
  api.shareSnapshot({...snapshot,session:2},()=>{});listeners.pagehide();await flush();assert(requests[4].aborted,'departed document does not retain contact reads');
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  const method=index.match(/  private updateShareSheet\([\s\S]*?(?=\n  private dismissShareSheet)/)[0];
  const events=[];const exported={};
  vm.runInNewContext(ts.transpileModule('export class Fixture {'+method+'}',{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyI18n:require('./local-message-test-fixture.cjs').rawLocalMessages,exports:exported,PIN_NATIVE_SHARE_PUBLISH_ENABLED:false});
  const native=new exported.Fixture();native.pinStore={shareSession:1};native.activeSheetKind='share';native.businessSuspended=false;
  native.pagePerformance={beginSecondary(){},markSecondary(_page,_key,event){events.push(event);}};
  native.sharePanelsController={updateShareSheet(feedback){native.pinStore.shareFeedback=feedback;native.pinStore.shareLoading=false;native.pinStore.shareError='';}};
  native.updateShareSheet('正在加载联系人…');assert.equal(events.length,0,'shell visibility does not mark contact data ready');
  native.updateShareSheet('没有可用的联系人');assert.deepEqual(events,['content-ready'],'a confirmed empty response counts as ready');
  const ui=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyShareSheet.ets','utf8');
  assert(!ui.includes('.height(280)'));assert(ui.includes('.layoutWeight(1)'));
  console.log('Share contacts: old query cancellation, newest response, close/pagehide cleanup, real readiness adapter and flexible viewport contract passed; device geometry excluded');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
