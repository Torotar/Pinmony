const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
let disk = new Map(), fail = false, flushes = 0;
function boot() {
  const state = new Map(), pending = new Map(disk), exports = {};
  const storage = { getSync: (key, fallback) => pending.has(key) ? pending.get(key) : fallback,
    putSync: (key, value) => pending.set(key,value), flushSync: () => { if(fail)throw Error('disk');disk = new Map(pending);flushes++; } };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_foundation/src/main/ets/services/PinmonyProfileLayoutPreference.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
    {exports,require: name => name === '@kit.ArkData' ? {preferences:{getPreferencesSync:()=>storage}} : {PinmonyRuntimeLog:{info(){},warn(){}}},AppStorage:{setOrCreate:(key,value)=>state.set(key,value)}});
  const preference = exports.PinmonyProfileLayoutPreference;preference.initialize({});return {preference,state};
}
let run=boot();assert.equal(run.state.get('profileAvatarRight'),false);
assert(run.preference.saveAvatarRight(true));assert.equal(flushes,1);
run=boot();assert.equal(run.state.get('profileAvatarRight'),true,'fresh runtime restores enabled preference');
assert(run.preference.saveAvatarRight(false));run=boot();assert.equal(run.state.get('profileAvatarRight'),false,'disabled preference also survives restart');
fail=true;assert.equal(run.preference.saveAvatarRight(true),false);assert.equal(run.state.get('profileAvatarRight'),false,'failed flush does not publish success');
run=boot();assert.equal(run.state.get('profileAvatarRight'),false);
console.log('Profile layout preference: default off, enable/disable across fresh runtimes and failed flush passed');

fail=false;
for(const density of [0,2,1]){run=boot();assert(run.preference.savePinDensity(density));run=boot();assert.equal(run.state.get('pinmonyProfilePinDensity'),density,'Pin view survives a fresh runtime');}
assert.equal(run.preference.savePinDensity(3),false);assert.equal(run.preference.savePinDensity(0.5),false);
disk.set('pinDensity','invalid');run=boot();assert.equal(run.state.get('pinmonyProfilePinDensity'),1,'invalid preference uses default view');
console.log('Pin view preference: wide/default/compact restart persistence and invalid-value fallback passed');

fail=false;
for(const density of [0,2,1]){run=boot();assert(run.preference.saveBoardDensity(density));run=boot();assert.equal(run.state.get('pinmonyBoardDensity'),density,'Board view survives a fresh runtime');}
assert.equal(run.preference.saveBoardDensity(3),false);
fail=true;assert.equal(run.preference.saveBoardDensity(0),false);assert.equal(run.state.get('pinmonyBoardDensity'),1);
console.log('Board view preference: restart persistence, validation and failed flush passed');
