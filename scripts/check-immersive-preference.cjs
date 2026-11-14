const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_foundation/src/main/ets/services/PinmonyImmersiveLightPreference.ets', 'utf8');
const compiled = ts.transpileModule(source, {compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText;
const disk = new Map();
let failOpen = false, failPut = false, failFlush = false;
function boot(initial = 'immersive', legacyEnabled = true) {
  const values = new Map([['immersiveLightMode', initial], ['immersiveLightEnabled', legacyEnabled]]);
  const cache = new Map(disk), events = [], logs = [], exports = {};
  const store = {
    getSync: (key, fallback) => cache.has(key) ? cache.get(key) : fallback,
    putSync: (key, value) => { events.push('put'); if (failPut) throw Error('put'); cache.set(key, value); },
    flushSync: () => { events.push('flush'); if (failFlush) throw Error('flush'); disk.clear(); for (const [key,value] of cache) disk.set(key,value); }
  };
  vm.runInNewContext(compiled, {exports, require: name => name === '@kit.ArkData' ? {preferences:{getPreferencesSync: (_ctx, options) => {
    assert.equal(options.name, 'pinmony_immersive_light'); if (failOpen) throw Error('open'); return store;
  }}} : name === './PinmonyRuntimeLog' ? {PinmonyRuntimeLog:{info: message=>logs.push(message),warn:message=>logs.push(message)}} : {},
    AppStorage: {get:key=>values.get(key),setOrCreate:(key,value)=>{ events.push('publish'); assert.equal(disk.get('mode'),value,'publish only after durable flush'); values.set(key,value); }}
  });
  return {Preference:exports.PinmonyImmersiveLightPreference,values,events,logs};
}
const display = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets', 'utf8');
const section = display.slice(display.indexOf("Text(this.uiText('pm_immersive_light'))"));
const selection = section.match(/\.onSelect\(\(index: number\) => \{([\s\S]*?)\n        \}\)/);
assert(selection, 'actual settings callback exists');
function select(host, index) {
  const SelectHost = vm.runInNewContext(ts.transpileModule('class SelectHost { apply(index: number): void {'+selection[1]+'} } SelectHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
    {PinmonyImmersiveLightPreference:host.Preference});
  const ui = new SelectHost(); let reports = 0;
  ui.logMaterialMode = () => reports++;
  // StorageLink updates global UI state only: it deliberately does NOT write disk.
  Object.defineProperty(ui,'immersiveLightMode',{get:()=>host.values.get('immersiveLightMode'),set:value=>host.values.set('immersiveLightMode',value)});
  ui.apply(index); return reports;
}
const modes = ['off','gentle','immersive','exquisite'];
for (const mode of modes) {
  disk.clear(); let host = boot(mode); host.Preference.initialize({});
  assert.equal(disk.get('mode'), mode, 'migrate every legacy mode');
  const index = modes.indexOf(mode); assert.equal(select(host,index),1);
  assert.equal(disk.get('mode'),mode); assert.equal(host.values.get('immersiveLightMode'),mode);
  host = boot(mode === 'immersive' ? 'off' : 'immersive', false);
  host.Preference.initialize({});
  assert.equal(host.values.get('immersiveLightMode'),mode,'real service restores dedicated saved mode over conflicting legacy/default state');
  assert(host.logs.includes('ImmersiveLightPreference: restored mode='+mode+' source=preferences'));
  assert.equal(host.events.includes('flush'),false,'saved valid value is not overwritten during restore');
}
// Reproduce the reported precise switch then immediate process restart.
disk.clear(); let host = boot(); host.Preference.initialize({}); host.events.length=0;
assert.equal(select(host,3),1); assert.equal(host.values.get('immersiveLightMode'),'exquisite');
assert.deepEqual(host.events,['put','flush','publish']);
host = boot('immersive'); host.Preference.initialize({}); assert.equal(host.values.get('immersiveLightMode'),'exquisite');
for (const index of [-1,4,0.5,NaN]) { const old = disk.get('mode'); assert.equal(select(host,index),0); assert.equal(disk.get('mode'),old); }
assert.equal(host.Preference.save('invalid'),false); assert.equal(disk.get('mode'),'exquisite');
for (const failure of ['put','flush']) {
  failPut=failure==='put'; failFlush=failure==='flush';
  assert.equal(select(host,0),0,'failed save does not report success');
  assert.equal(host.values.get('immersiveLightMode'),'exquisite','failed save preserves UI value');
  assert.equal(disk.get('mode'),'exquisite','failed save preserves durable value');
  failPut=false; failFlush=false;
  const restarted=boot('immersive'); restarted.Preference.initialize({}); assert.equal(restarted.values.get('immersiveLightMode'),'exquisite');
}
assert.equal(host.Preference.save('gentle'),true,'saving recovers after storage error');
failOpen=true; host.Preference.initialize({}); assert.equal(host.Preference.save('off'),false,'failed reinitialize invalidates stale handle'); failOpen=false;
host.Preference.initialize({}); assert.equal(host.values.get('immersiveLightMode'),'gentle');
const uninitialized=boot(); assert.equal(uninitialized.Preference.save('off'),false);
for (const failure of ['put','flush']) {
  disk.clear(); failPut=failure==='put'; failFlush=failure==='flush';
  const failed=boot('exquisite'); failed.Preference.initialize({});
  assert.equal(failed.Preference.save('off'),false,'failed migration cannot leave a writable handle');
  assert.equal(disk.has('mode'),false,'failed initialization does not invent a durable value');
  failPut=false; failFlush=false;
  failed.Preference.initialize({}); assert.equal(failed.Preference.save('exquisite'),true,'initialization can recover');
}
for (const saved of ['invalid',true,42]) {disk.set('mode',saved);const repaired=boot('gentle');repaired.Preference.initialize({});assert.equal(disk.get('mode'),'gentle');}
for (const enabled of [true,false]) {disk.clear();const migrated=boot(undefined,enabled);migrated.values.delete('immersiveLightMode');migrated.Preference.initialize({});assert.equal(disk.get('mode'),enabled?'immersive':'off');}
const startup = fs.readFileSync('entry/src/main/ets/startup/PreferencesTask.ets','utf8');
assert(startup.includes('PinmonyImmersiveLightPreference.initialize(context)'));
assert(startup.indexOf("PersistentStorage.persistProp('immersiveLightMode'") < startup.indexOf('PinmonyImmersiveLightPreference.initialize(context)'),'dedicated saved value overrides only legacy fallback');
const tasks=JSON.parse(fs.readFileSync('entry/src/main/resources/base/profile/startup_config.json','utf8')).startupTasks;
assert(tasks.find(task=>task.name==='PreferencesTask').waitOnMainThread);
assert(fs.readFileSync('common_foundation/Index.ets','utf8').includes('export { PinmonyImmersiveLightPreference }'));
console.log('Immersive durable preference: actual service + Select callback, flush-before-publish, four modes, exact exquisite restart, legacy conflict/migration, invalid mode/index, write/flush/open failures and recovery passed');
