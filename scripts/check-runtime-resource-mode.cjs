const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('common_foundation/src/main/ets/services/PinmonyI18n.ets','utf8');
const managers=[],state=new Map(),warnings=[];let mode=1,fail=-1;
const host={resourceManager:{getConfigurationSync:()=>({locale:'system',colorMode:mode,direction:0}),
  getOverrideResourceManager:configuration=>{
    const index=managers.length;
    const manager={initial:{...configuration},updates:[],updateOverrideConfiguration(next){
      if(index===fail)throw Error('synthetic update failure');
      this.updates.push({...next});
    }};managers.push(manager);return manager;
  }}};
const output={};
vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{
  exports:output,require:name=>name==='@kit.LocalizationKit'?{resourceManager:{ColorMode:{DARK:0,LIGHT:1}},
    i18n:{System:{getSystemLanguage:()=> 'en-US'}}}:name==='@kit.ArkData'?{preferences:{getPreferencesSync:()=>({getSync:()=> 'system'})}}:{PINMONY_LOCAL_COPY_KEYS:{}},
  AppStorage:{get:key=>state.get(key),setOrCreate:(key,value)=>state.set(key,value)},console:{warn:line=>warnings.push(line)}
});
const api=output.PinmonyI18n;api.initialize(host);assert.equal(managers.length,8);
api.syncResourceColorMode(host);const locales=managers.map(manager=>manager.initial.locale);
mode=0;api.syncResourceColorMode(host);
managers.forEach((manager,index)=>{assert.equal(manager.updates.at(-1).colorMode,0);assert.equal(manager.updates.at(-1).locale,locales[index]);});
const count=managers[0].updates.length;api.syncResourceColorMode(host);assert.equal(managers[0].updates.length,count);
mode=-1;api.syncResourceColorMode(host);assert.equal(managers[0].updates.length,count,'unknown configuration does not overwrite a valid snapshot');
mode=1;fail=3;api.syncResourceColorMode(host);assert.equal(warnings.length,1);
fail=-1;api.syncResourceColorMode(host);assert.equal(managers[7].updates.at(-1).colorMode,1,'partial failure remains retryable');
const startup=fs.readFileSync('entry/src/main/ets/startup/PreferencesTask.ets','utf8');
assert(startup.indexOf('.setColorMode(')<startup.indexOf('PinmonyI18n.initialize(context)'));
const ability=fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8');
assert.match(ability,/onConfigurationUpdate\(newConfig: Configuration\): void \{\s*PinmonyI18n.syncResourceColorMode\(this.context\)/);
console.log('Resource mode: eight locales, light/dark, no-op, unknown mode, retry and startup ordering passed');
