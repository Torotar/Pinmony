const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets';
const source = fs.readFileSync(file, 'utf8');
const start = source.indexOf('  private options()');
const end = source.indexOf('  @Builder', start);
assert(start >= 0 && end > start);
const context = { $r: value => value, Color: { Transparent: 'transparent' }, BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 1 },
  hdsMaterial: { MaterialType: { IMMERSIVE: 1, NONE: 0, ADAPTIVE: 100 }, getSystemMaterialTypes: () => [1], MaterialLevel: { GENTLE: 1, SMOOTH: 2, EXQUISITE: 0 } } };
const helper = fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets', 'utf8').replace(/^import .*;\r?\n/m, '').replace(/export /g, '');
vm.runInNewContext(ts.transpileModule(helper + '; globalThis.PinmonyImmersiveLight = PinmonyImmersiveLight;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
for (const support of [true, false, 'error']) {
  context.hdsMaterial.getSystemMaterialTypes = () => { if (support === 'error') throw Error('unsupported'); return support ? [1] : []; };
  assert.equal(context.PinmonyImmersiveLight.effect('off'), undefined);
  for (const mode of ['gentle', 'immersive', 'exquisite']) {
    const effect = context.PinmonyImmersiveLight.effect(mode);
    assert.equal(effect.materialType, mode === 'gentle' || support !== true ? 100 : 1);
    assert.equal(effect.materialLevel, mode === 'gentle' ? 2 : mode === 'exquisite' ? 0 : 1);
  }
}
context.hdsMaterial.getSystemMaterialTypes = () => [1];
vm.runInNewContext(ts.transpileModule('class Page {' + source.slice(start, end) + '} globalThis.Page = Page;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const page = new context.Page();
page.store = { busy: false }; page.title = () => 'display';
for (const mode of ['immersive', 'off', 'gentle', 'exquisite', 'immersive']) {
  const enabled = mode !== 'off';
  page.immersiveLightMode = mode;
  page.immersiveLightEnabled = enabled;
  const options = page.options();
  assert.equal(options.style.scrollEffectOpts.enableScrollEffect, enabled);
  assert.equal(options.style.systemMaterialEffect?.materialType, enabled ? mode === 'gentle' ? 100 : 1 : undefined);
  assert.equal(options.style.systemMaterialEffect?.materialLevel, enabled ? mode === 'gentle' ? 2 : mode === 'exquisite' ? 0 : 1 : undefined);
  assert.equal(options.style.blurStrategy, enabled ? 1 : 0);
  assert.equal(options.style.thermoCtrl, enabled);
  assert.equal(options.style.originalStyle.contentStyle.backIconStyle.backgroundColor, !enabled || mode === 'gentle' ? 'transparent' : undefined);
  assert.equal(options.style.originalStyle.backgroundStyle.backgroundColor, 'transparent');
  assert.equal(options.style.scrollEffectStyle.backgroundStyle.backgroundColor, 'app.color.immersive_title_scrolled');
  assert.equal(options.avoidLayoutSafeArea, true);
}
let components = 0;
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (file.endsWith('.ets')) {
      const text = fs.readFileSync(file, 'utf8');
      if (!text.includes('PinmonyImmersiveLight.effect(this.immersiveLightMode)')) continue;
      components++;
      assert(text.includes("@StorageLink('immersiveLightMode')"), file);
      assert(!text.includes('materialType: hdsMaterial.MaterialType.IMMERSIVE'), file);
    }
  }
}
for (const root of fs.readdirSync('.').filter(name => /^(feature_|entry$|common_ui$)/.test(name))) walk(path.join(root, 'src'));
assert(components >= 20);
assert(fs.readFileSync('entry/src/main/ets/startup/PreferencesTask.ets', 'utf8')
  .includes("PersistentStorage.persistProp('immersiveLightMode', AppStorage.get<boolean>('immersiveLightEnabled') === false ? 'off' : 'immersive')"));
console.log('Immersive light: four material modes, scroll effect, safe area, global bindings and persisted migration passed');
