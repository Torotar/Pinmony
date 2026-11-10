const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const disk = new Map(), values = new Map(); let failFlush = false;
function load() {
  const exports = {};
  const source = fs.readFileSync('common_foundation/src/main/ets/services/PinmonyDetailDisplayPreference.ets', 'utf8');
  vm.runInNewContext(ts.transpileModule(source, {compilerOptions:{target:99,module:ts.ModuleKind.CommonJS}}).outputText, {
    exports, require: name => name === '@kit.ArkData' ? {preferences:{getPreferencesSync:()=>({
      getSync:(key,fallback)=>disk.has(key)?disk.get(key):fallback,
      putSync:(key,value)=>disk.set(key,value), flushSync:()=>{if(failFlush)throw Error('disk');}
    })}} : {PinmonyRuntimeLog:{warn(){}}},
    AppStorage:{get:key=>values.get(key), setOrCreate:(key,value)=>values.set(key,value)}
  });
  return exports.PinmonyDetailDisplayPreference;
}
let prefs = load(); prefs.initialize({});
assert.equal(values.get('detailPhotoFitEnabled'), false);
assert(prefs.savePhotoFit(true)); assert.equal(values.get('detailPhotoFitEnabled'), true);
values.clear(); prefs = load(); prefs.initialize({}); assert.equal(values.get('detailPhotoFitEnabled'), true, 'restart restores enabled');
assert(prefs.savePhotoFit(false)); values.clear(); prefs = load(); prefs.initialize({}); assert.equal(values.get('detailPhotoFitEnabled'), false);
failFlush = true; assert.equal(prefs.savePhotoFit(true), false); assert.equal(values.get('detailPhotoFitEnabled'), false);
failFlush = false; disk.clear(); values.set('detailPhotoFitEnabled', true); prefs = load(); prefs.initialize({});
assert.equal(disk.get('photoFitEnabled'), true, 'existing universal preference migrates');
const settings = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets','utf8');
const display = settings.slice(settings.indexOf('private display()'), settings.indexOf('private theme()'));
const order = ['pm_language_9f6fee1a','pm_theme_788db1cf','pm_screen_orientation_60cc99cc','pm_immersive_light','pm_detail_photo_fit','pm_bottom_bar_collapse_animation_4b0bb564','pm_profile_legacy_layout'];
let previous = -1; for(const key of order) { const index=display.indexOf(key); assert(index>previous, key); previous=index; }
assert.equal((display.match(/\.selectedOptionBgColor/g)||[]).length,4);
assert.equal((display.match(/\.selectedOptionFontColor/g)||[]).length,4);
assert(display.includes('PinmonyDetailDisplayPreference.savePhotoFit(next)'));
const startup=fs.readFileSync('entry/src/main/ets/startup/PreferencesTask.ets','utf8');
assert(startup.indexOf('PinmonyDetailDisplayPreference.initialize(context)')>startup.indexOf("persistProp('detailPhotoFitEnabled'"));
const page=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
assert(page.includes('.blur(28 * this.entryBackdropProgress * (1 - this.viewerBackdropProgress))'));
assert(page.includes('.opacity(0.72 * this.entryBackdropProgress * (1 - this.viewerBackdropProgress))'));
console.log('Detail display: enabled/disabled restart, migration, failed save, grouped controls, all selected styles and viewer blur lifecycle passed');
