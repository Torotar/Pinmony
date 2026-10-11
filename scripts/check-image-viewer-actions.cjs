const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=source.indexOf('  private async saveViewerImage()');
const method=source.slice(start,source.indexOf('  private async performDetailAction(',start));
const compiled=ts.transpileModule('class Native {'+method+'}; Native;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
const pin='https://www.pinterest.com/pin/123/';
async function scenario(kind){
  const scripts=[],messages=[],confirmed=[];
  let result={loading:false,busy:false,error:kind==='denied'?'ownership failed':'',uncertain:false,done:''};
  const api={savedRead:()=>kind==='copy'?{id:'456'}:null,saveUndo:()=>true,savedUndoRead:()=>({status:'done'}),savedRestoreClose(){},editStart:()=>true,editRead:()=>result,
    editPhase:()=>true,editCommit:()=>{result.done='deleted';return true;}};
  const Native=require('./product-coordination-harness.cjs').run(ts,compiled,{JSON,Promise,setTimeout:(fn)=>setTimeout(fn,0)});
  const native=new Native();
  native.authEpoch=1;native.authStatus='authenticated';
  native.pinStore={imageLayer:'zoom',detailActionsReady:true,viewerSaveBusy:false,saveCancelToken:0,
    detail:{pinUrl:pin,actions:[{id:'save',kind:'save',enabled:true,selected:kind!=='unsaved'}]},
    confirmedSaves:{copyId:()=>'',confirm:(...a)=>confirmed.push(a),apply:(_id,d)=>d},detailCache:{remove(){}}};
  native.detailJourney={mark(){}};native.currentPinUrl=()=>pin;
  native.rejectOfflineAction=()=>false;
  native.pinIdentity=()=> '123';native.webJsonText=v=>v;
  native.controller={runJavaScript:async text=>{scripts.push(text);return String(vm.runInNewContext(text,{window:{PinmonyPostApi:api},JSON}));}};
  native.showMessage=t=>messages.push(t);native.undoSavedPin=async()=>scripts.push('undo');
  native.performDetailAction=()=>scripts.push('save-picker');
  require('./pin-priority-controller-harness.cjs').bind(native,ts);
  await native.saveViewerImage();
  assert(!native.pinStore.viewerSaveBusy);
  if(kind==='copy'){assert.equal(scripts.filter(s=>s.includes('.saveUndo(')).length,1);assert.equal(native.pinStore.saveUndoId,'456');}
  if(kind==='denied'){assert(!scripts.some(s=>s.includes('editCommit')));assert.equal(confirmed.length,0);}
  if(kind==='owned'){assert.equal(scripts.filter(s=>s.includes('editCommit')).length,1);assert.equal(confirmed[0][1],false);}
  if(kind==='unsaved'){assert.deepEqual(scripts,['save-picker']);}
}
(async()=>{for(const k of ['copy','denied','owned','unsaved'])await scenario(k);console.log('viewer save: picker, confirmed copy identity, ownership failure and single delete dispatch passed');})().catch(e=>{console.error(e);process.exitCode=1;});
