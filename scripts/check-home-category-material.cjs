const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_home/src/main/ets/components/PinmonyHomeCategoryMaterial.ets';
const source = fs.readFileSync(file, 'utf8');
const page = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets', 'utf8');
function boot(deviceInfo, failColor = false) {
  const effects = [], calls = [];
  const uiMaterial = { ImmersiveStyle: { REGULAR: 2, THICK: 3 },
    ImmersiveMaterial: class { constructor(options) { effects.push(options); this.options = options; } } };
  const code = source.replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
  const Host = vm.runInNewContext(ts.transpileModule(code + '\nPinmonyHomeCategoryMaterial;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { deviceInfo, uiMaterial, $r: key => key,
    ColorMetrics: { resourceColor: key => { if (failColor) throw Error('resource unavailable'); assert.equal(key, 'app.color.detail_save_accent'); return { red: 230, green: 0, blue: 35 }; },
      rgba: (r, g, b, a) => ({ color: `rgba(${r},${g},${b},${a})` }) } });
  const button = { systemMaterial: value => calls.push(['material', value]),
    backgroundColor: value => calls.push(['background', value]) };
  return { Host, button, calls, effects };
}
for (const device of [{ apiAvailable: () => false }]) {
  const h = boot(device);
  for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) new h.Host(mode, true).applyNormalAttribute(h.button);
  assert.equal(h.calls.length, 0, 'API 24/25 must never access new material methods');
  assert.equal(h.effects.length, 0);
}
let capabilityChecks = 0;
const h = boot({ apiAvailable: version => { capabilityChecks++; assert.equal(version, '26.0.0'); return true; } });
for (const mode of ['gentle', 'immersive', 'exquisite']) {
  for (const selected of [true, false]) {
    new h.Host(mode, selected).applyNormalAttribute(h.button);
    const effect = h.effects.at(-1);
    assert.equal(effect.style, mode === 'gentle' ? 3 : 2);
    assert.equal(effect.materialColor, selected ? 'rgba(230,0,35,0.9)' : undefined);
    assert.equal(effect.interactive, true); assert.equal(effect.applyShadow, false);
    assert.equal(effect.lightEffect.color, 'app.color.immersive_interaction_light');
  }
}
for (const selected of [true, false]) {
  new h.Host('off', selected).applyNormalAttribute(h.button);
  assert.equal(h.calls.at(-2)[0], 'material'); assert.equal(h.calls.at(-2)[1], undefined);
  assert.deepEqual(h.calls.at(-1), ['background', selected ? 'app.color.detail_save_accent' : 'app.color.input_surface']);
}
const failedColor = boot({ apiAvailable: () => true }, true);
assert.equal(capabilityChecks, 8, 'each material application has a direct API version guard recognized by the compiler');
new failedColor.Host('immersive', true).applyNormalAttribute(failedColor.button);
assert.equal(failedColor.effects.length, 0);
assert.equal(failedColor.calls[0][1], undefined);
assert.deepEqual(failedColor.calls[1], ['background', 'app.color.detail_save_accent']);
assert(page.includes('.attributeModifier(this.categoryMaterial(id))'));
assert(page.includes('.enabled((this.interactionReady || this.offlinePreview) && this.currentCategory(id).enabled)'));
assert(page.includes('.accessibilitySelected(this.categorySelected(id))'));
const profile = fs.readFileSync('build-profile.json5', 'utf8');
assert(profile.includes('"compileSdkVersion": "26.0.0"'));
assert(profile.includes('"compatibleSdkVersion": "6.1.1(24)"'));
assert(profile.includes('"targetSdkVersion": "6.1.1(24)"'));
console.log('Home category material passed: API 24/25 fallback, API 26 modes, selected tint, live off/reset and existing readiness/accessibility binding.');

// A material belongs to one stable button; repeat application must still reach native attributes.
const reuse = new h.Host('immersive', true, false);
const beforeReuse = h.effects.length;
for (let i = 0; i < 120; i++) reuse.applyNormalAttribute(h.button);
assert.equal(h.effects.length, beforeReuse + 1);
const firstMaterial = h.calls.at(-1)[1];
assert.equal(h.calls.at(-2)[1], firstMaterial);
for (const [mode, selected, dark] of [['gentle',true,false],['exquisite',true,false],['immersive',false,false],['immersive',false,true],['immersive',true,true]]) {
  const count = h.effects.length;
  reuse.update(mode, selected, dark); reuse.applyNormalAttribute(h.button);
  assert.equal(h.effects.length, count + 1, 'mode, selection and theme invalidate per-button material');
  reuse.update(mode, selected, dark); reuse.applyNormalAttribute(h.button);
  assert.equal(h.effects.length, count + 1, 'equivalent inputs reuse material');
}
reuse.update('off', true, true); reuse.applyNormalAttribute(h.button);
assert.equal(h.calls.at(-2)[1], undefined);
const count = h.effects.length;
reuse.update('immersive', true, true); reuse.applyNormalAttribute(h.button);
assert.equal(h.effects.length, count + 1, 'off to on recreates material');
