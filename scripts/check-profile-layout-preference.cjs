const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
let disk = new Map(), fail = false, flushes = 0;
function boot(legacyDefault = false) {
  const state = new Map([['profileLegacyLayout',legacyDefault]]), pending = new Map(disk), exports = {};
  const storage = { getSync: (key, fallback) => pending.has(key) ? pending.get(key) : fallback,
    putSync: (key, value) => pending.set(key,value), flushSync: () => { if(fail)throw Error('disk');disk = new Map(pending);flushes++; } };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_foundation/src/main/ets/services/PinmonyProfileLayoutPreference.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
    {exports,require: name => name === '@kit.ArkData' ? {preferences:{getPreferencesSync:()=>storage}} : {PinmonyRuntimeLog:{info(){},warn(){}}},AppStorage:{get:key=>state.get(key),setOrCreate:(key,value)=>state.set(key,value)}});
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
fail=false;disk.delete('legacyLayout');run=boot(true);assert.equal(run.state.get('profileLegacyLayout'),true,'existing global preference migrates as the initial fallback');
assert(run.preference.saveLegacyLayout(true));run=boot(false);assert.equal(run.state.get('profileLegacyLayout'),true,'native saved legacy preference overrides an early false default after restart');
assert(run.preference.saveLegacyLayout(false));run=boot(true);assert.equal(run.state.get('profileLegacyLayout'),false,'return to modern layout survives restart');
fail=true;assert.equal(run.preference.saveLegacyLayout(true),false);assert.equal(run.state.get('profileLegacyLayout'),false,'failed persistence does not publish a layout change');
fail=false;assert(run.preference.saveAvatarRight(true));run=boot();assert.equal(run.state.get('profileLegacyLayout'),false,'another successful flush must not persist the failed legacy write');
const settings=fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets','utf8');assert(settings.includes('PinmonyProfileLayoutPreference.saveLegacyLayout(value)'));
console.log('Legacy layout preference: migration, both restart directions, early defaults and failed-flush isolation passed');
