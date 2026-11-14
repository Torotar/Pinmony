const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function runtime(name, disk = new Map(), initial = {}) {
  const state = new Map(Object.entries(initial)), cache = new Map(disk), fault = {}, exports = {};
  const storage = {getSync:(key,fallback)=>cache.has(key)?cache.get(key):fallback,
    putSync:(key,value)=>cache.set(key,value), flushSync:()=>{if(fault.flush)throw Error('flush');disk.clear();for(const pair of cache)disk.set(...pair);}};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_foundation/src/main/ets/services/'+name+'.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
    {exports,AppStorage:{get:key=>state.get(key),setOrCreate:(key,value)=>state.set(key,value)},require:key=>key==='@kit.ArkData'?{preferences:{getPreferencesSync:()=>{if(fault.open)throw Error('open');return storage;}}}:{PinmonyRuntimeLog:{info(){},warn(){}}}});
  const service=exports[name];service.initialize({});return {service,state,fault,disk};
}
const layout='PinmonyProfileLayoutPreference';
const choices=[['saveLegacyLayout',true,'profileLegacyLayout'],['saveAvatarRight',true,'profileAvatarRight'],['savePinDensity',2,'pinmonyProfilePinDensity'],['saveBoardDensity',0,'pinmonyBoardDensity']];
for(const [method,value,key] of choices){
  const host=runtime(layout),previous=host.state.get(key);host.fault.flush=true;
  assert.equal(host.service[method](value),false);assert.equal(host.state.get(key),previous);
  host.fault.flush=false;
  const other=choices.find(choice=>choice[0]!==method);assert(host.service[other[0]](other[1]));
  assert.equal(runtime(layout,host.disk).state.get(key),previous,method+': later successful save must not commit failed choice');
}
const migrated=runtime(layout,new Map(),{profileLegacyLayout:true});
assert.equal(runtime(layout,migrated.disk).state.get('profileLegacyLayout'),true,'legacy fallback must migrate durably without another user change');
for(const [name,method,value] of [[layout,'saveAvatarRight',true],['PinmonyDetailDisplayPreference','savePhotoFit',true]]){
  for(const stage of ['open','flush']){
    const host=runtime(name);host.fault[stage]=true;host.service.initialize({});host.fault[stage]=false;
    assert.equal(host.service[method](value),false,name+': failed reinitialization must disable stale store');
    host.service.initialize({});assert(host.service[method](value),'successful reinitialization recovers');
  }
}
console.log('Settings persistence audit: four failed-write isolation paths, legacy migration, stale initialization and recovery passed');
