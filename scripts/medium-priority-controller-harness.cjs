const fs=require('node:fs'),vm=require('node:vm');
const {createArktsLoader}=require('./arkts-module-loader.cjs');
function runtime(ts,globals={}) {
  return createArktsLoader(ts,{'@kit.CoreFileKit':{fileIo:{}},'@kit.ArkTS':{util:{}}},globals);
}
function bindWork(native,ts,globals={}) {
  native.sessionDocumentUrl ||= () => native.controller?.getUrl?.() || '';
  native.runSessionScript ||= script => native.controller.runJavaScript(script);
  const loader=runtime(ts,globals);
  native.coordinatorTasks ||= new (loader.loadFile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets').PinmonyTaskRegistry)();
  const Performance=loader.loadFile('common_foundation/src/main/ets/services/PinmonyPagePerformance.ets').PinmonyPagePerformance;
  const performance=new Performance(()=>Date.now(),()=>{});
  native.pagePerformance ||= performance;
  for(const name of ['beginSecondary','markSecondary']) native.pagePerformance[name] ||= performance[name].bind(performance);
}
function bind(native,ts,globals={},names=['settings','inboxActions']) {
  bindWork(native,ts,globals);
  const loader=runtime(ts,globals),index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  for(const name of names) {
    const feature=name==='settings'?'settings':'inbox',store=name==='settings'?'settingsStore':'inboxStore';
    const match=index.match(new RegExp('  private readonly '+name+'Controller: [^=]+ = new ([^(]+)\\(this\\.'+store+', \\{([\\s\\S]*?)\\} as [^;]+;'));
    if(!match)throw Error('Missing real Index binding '+name);
    const exported=loader.loadFile(`feature_${feature}/src/main/ets/controllers/${match[1]}.ets`);
    const result={};
    vm.runInNewContext(ts.transpileModule(`export function bind(){this.${name}Controller=new ${match[1]}(this.${store},{${match[2]}});}`,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,
      {PIN_NATIVE_INBOX_UPDATES_ENABLED:false,PIN_NATIVE_INBOX_MESSAGES_ENABLED:false,PIN_NATIVE_PROFILE_SETTINGS_ENABLED:false,...globals,...exported,exports:result,useNativeTransport:s=>s,PIN_ACCOUNT_SETTINGS_SCRIPT:'',PIN_NOTIFICATIONS_READ_SCRIPT:'',PIN_INBOX_CONVERSATIONS_API_ENABLED:true});
    result.bind.call(native);
  }
  return loader;
}
module.exports={runtime,bindWork,bind};
