const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const name = 'PinmonyDisplaySelectMenuMaterial';
const source = fs.readFileSync('feature_settings/src/main/ets/components/' + name + '.ets', 'utf8');
const page = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets', 'utf8');
const compiled = process.argv.includes('--compiled');
let code = source.replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
if (compiled) {
  const emitted = fs.readFileSync('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/feature_settings/src/main/ets/components/' + name + '.ts', 'utf8');
  const ast = ts.createSourceFile('compiled.ts', emitted, ts.ScriptTarget.Latest, true);
  code = ast.statements.filter(node => ts.isFunctionDeclaration(node) || ts.isClassDeclaration(node) && node.name?.text === name)
    .map(node => node.getText(ast).replace(/^export /, '')).join('\n');
}
function boot(version, supported) {
  const calls = [], effects = [], empty = {};
  let capabilityQueries = 0;
  const deviceInfo = compiled ? { sdkApiVersion: version, distributionOSApiVersion: version >= 26 ? 260000 : 60101 } :
    { apiAvailable(api) { assert.equal(api, '26.0.0'); return version >= 26; } };
  const Host = vm.runInNewContext(ts.transpileModule(code + '\n' + name + ';', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { deviceInfo, $r: key => key, uiMaterial: {
    Material: { empty }, ImmersiveStyle: { THICK: 3, REGULAR: 2 },
    isImmersiveMaterialSupported() { capabilityQueries++; if (supported === 'error') throw Error('unavailable'); return supported; },
    ImmersiveMaterial: class { constructor(options) { effects.push(options); this.options = options; } }
  } });
  return { Host, calls, effects, empty, queries: () => capabilityQueries,
    select: { menuSystemMaterial(material) { calls.push(material); } } };
}
for (const version of [24, 25, 26]) for (const supported of [true, false, 'error']) {
  const h = boot(version, supported);
  for (const mode of ['immersive', 'gentle', 'exquisite', 'off', 'immersive', 'off']) {
    const previousQueries = h.queries(), previousEffects = h.effects.length;
    new h.Host(mode).applyNormalAttribute(h.select);
    if (version < 26) {
      assert.equal(h.calls.length, 0, 'older systems never access the new menu API');
      assert.equal(h.queries(), 0, 'older systems never query new material capability');
    } else if (mode === 'off' || supported !== true) {
      assert.equal(h.calls.at(-1), h.empty, 'off, unsupported or failed capability clears the previous menu material');
      assert.equal(h.effects.length, previousEffects);
      if (mode === 'off') assert.equal(h.queries(), previousQueries);
    } else {
      assert.equal(h.effects.length, previousEffects + 1);
      const effect = h.calls.at(-1).options;
      assert.equal(effect.style, mode === 'gentle' ? 3 : 2);
      assert.equal(effect.colorInvert, false); assert.equal(effect.interactive, true); assert.equal(effect.applyShadow, true);
      if (compiled) { assert.equal(effect.lightEffect.color.type, 10001); assert(effect.lightEffect.color.id > 0); }
      else assert.equal(effect.lightEffect.color, 'app.color.immersive_interaction_light');
    }
  }
  if (version >= 26 && supported === true) {
    new h.Host('immersive').applyNormalAttribute(h.select);
    const previous = h.calls.at(-1);
    new h.Host('immersive').applyNormalAttribute(h.select);
    assert.notEqual(h.calls.at(-1), previous, 'each menu receives a separate material instance');
  }
}
assert.equal((page.match(/Select\(\[/g) || []).length, 4);
assert.equal((page.match(/\.attributeModifier\(new PinmonyDisplaySelectMenuMaterial\(this\.immersiveLightMode\)\)/g) || []).length, 4,
  'language, theme, orientation and immersive-mode menus all observe the live preference');
assert.equal((page.match(/\.backgroundColor\(\$r\('app.color.display_settings_control'\)\)\.borderRadius\(16\)/g) || []).length, 4);
assert.equal((page.match(/\.selectedOptionBgColor\(\$r\('app.color.display_settings_control'\)\)/g) || []).length, 4);
assert.equal((page.match(/\}, \(language: string\): string => language\)/g) || []).length, 4, 'localized options retain language-aware keys');
assert(page.includes('this.selectTheme(') && page.includes('this.selectOrientation(index)') && page.includes('PinmonyI18n.select(value)'));
assert(page.includes("this.immersiveLightMode = ['off', 'gentle', 'immersive', 'exquisite'][index]"));
assert(!source.includes('.backgroundColor(') && !source.includes('.systemMaterial('), 'modifier only changes popup-menu material');
const profile = fs.readFileSync('build-profile.json5', 'utf8');
assert(profile.includes('"compileSdkVersion": "26.0.0"'));
assert(profile.includes('"compatibleSdkVersion": "6.1.1(24)"'));
console.log((compiled ? 'Compiled' : 'Source') + ' display Select menus: four entries, live modes/reset, independent materials, API24/25 gates, capability failure and original colors/actions passed.');
