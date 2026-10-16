const fs=require('node:fs'),vm=require('node:vm');
const {createArktsLoader}=require('./arkts-module-loader.cjs');
function runtime(ts,globals={}) {
  const scope={setTimeout,clearTimeout,setInterval,clearInterval,useNativeTransport:s=>s,PIN_VISUAL_SEARCH_API_SCRIPT:'',PIN_POST_API_ENABLED:true,PIN_POST_EXTENSIONS_ENABLED:true,PIN_NATIVE_SHARE_PUBLISH_ENABLED:false,PIN_NATIVE_DETAIL_AUXILIARY_ENABLED:false,PIN_NATIVE_COMMENT_WRITES_ENABLED:false,PIN_NATIVE_POST_OPERATIONS_ENABLED:false,...globals};
  const loader=createArktsLoader(ts);
  const cache=loader.loadFile('feature_pin/src/main/ets/services/PinmonyDetailCache.ets');
  const deps={...cache,PinmonyRuntimeLog:{info(){},warn(){}},PIN_DETAIL_API_ENABLED:true,PIN_POST_API_ENABLED:true,PIN_EDIT_API_ENABLED:true,PIN_VISUAL_SEARCH_API_ENABLED:true};
  const compile=file=>{const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{...scope,exports,require:()=>deps});return exports;};
  Object.assign(deps,compile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets'));
  deps.PinmonyPinStore=loader.loadFile('feature_pin/src/main/ets/stores/PinmonyPinStore.ets').PinmonyPinStore;
  for(const n of ['Detail','DetailRead','DetailOperations','SharePanels'])Object.assign(deps,compile(`feature_pin/src/main/ets/controllers/Pinmony${n}Controller.ets`));
  return {...deps,scope};
}
function bind(native,ts,globals={},names=['detailRead','detailOperations','sharePanels']) {
  require('./medium-priority-controller-harness.cjs').bindWork(native, ts, globals);
  native.pinStore.visualResult ||= {pin:'',loading:false,error:'',ended:false,items:[]};
  if(native.controller && !native.controller.getUrl) native.controller.getUrl=()=>native.currentPinUrl?.() || native.pinStore.detail?.pinUrl || native.pinStore.sharePin || '';
  const r=runtime(ts,globals),index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  for(const name of names){
    const match=index.match(new RegExp('  private readonly '+name+'Controller: [^=]+ = new ([^(]+)\\(this\\.pinStore, \\{([\\s\\S]*?)\\} as [^;]+;'));
    if(!match)throw Error('Missing real Index binding: '+name);
    const exported={};
    vm.runInNewContext(ts.transpileModule(`export function bind() { this.${name}Controller = new ${match[1]}(this.pinStore, {${match[2]}}); }`,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{...r.scope,...r,exports:exported});
    exported.bind.call(native);
  }
  if(!native.detailController){
    const match=index.match(/new PinmonyDetailController\(\{([\s\S]*?)\} as PinmonyDetailPorts\)/);
    const exported={};
    vm.runInNewContext(ts.transpileModule(`export function bind() { this.detailController = new PinmonyDetailController({${match[1]}}); }`,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{...r.scope,...r,exports:exported});exported.bind.call(native);
  }
  return r;
}
module.exports={runtime,bind};
