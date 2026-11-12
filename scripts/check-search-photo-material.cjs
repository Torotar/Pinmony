const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPhotoMaterial.ets', 'utf8');
const start = page.indexOf(".id('pinmony-photo-search-menu')");
assert(start > 0);
const button = page.slice(start, page.indexOf('\n        }', start));
assert(button.includes('.backgroundColor(this.searchControlBackground())'));
assert(button.includes('.attributeModifier(new PinmonySearchButtonMaterial(this.immersiveLightMode, this.hdsDarkMode))'));
assert(button.includes('.enabled(this.interactionReady && !this.photoBusy)'));
assert(button.includes('.onClick(() => { this.photoMenu(); })'));
assert(button.includes(".accessibilityText(this.uiText('pm_photo_search'))"));
assert(page.includes('PinmonySearchPhotoMenuMaterial.options(this.immersiveLightMode'));
const helper = source.slice(0, source.indexOf('// As in PuraPily')).replace(/^import .*;\r?\n/gm, '');
for (const api of [24, 25, 26]) for (const supported of [false, true]) for (const dark of [false, true]) {
  for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
    const effects = [], calls = [], empty = {};
    const Host = vm.runInNewContext(ts.transpileModule(helper + '\nPinmonySearchButtonMaterial;', {
      compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.None }
    }).outputText.replace(/^export /gm, ''), {
      exports: {}, $r: key => key, deviceInfo: { apiAvailable: () => api >= 26 }, Color: { White: 'white' },
      uiMaterial: { isImmersiveMaterialSupported: () => supported, Material: { empty },
        ImmersiveStyle: { THICK: 3, ULTRA_THIN: 1 }, ImmersiveMaterial: class { constructor(value) { effects.push(value); } } }
    });
    new Host(mode, dark).applyNormalAttribute({ systemMaterial: value => calls.push(value) });
    assert.equal(calls.length, api >= 26 ? 1 : 0, 'older API never receives material calls');
    if (api >= 26 && mode !== 'off' && supported) {
      assert.equal(effects[0].style, mode === 'gentle' ? 3 : 1);
      assert.equal(effects[0].interactive, true); assert.equal(effects[0].applyShadow, false);
      assert.equal(effects[0].materialColor, dark ? '#301C2022' : '#30FFFFFF');
      assert.equal(effects[0].lightEffect.color, 'app.color.immersive_interaction_light');
    } else { assert.equal(effects.length, 0); if (api >= 26) assert.equal(calls[0], empty); }
  }
}
console.log('Search photo material: actual shared Button modifier, API 24/25/26, support, themes, modes, anchor, action and readiness passed.');

const header = page.slice(page.indexOf('private searchHeaderContent('), page.indexOf('private searchResultsContent('));
const controls = header.split(/if \(editing\) \{|if \(!editing && [^\r\n]*\) \{/);
assert.equal(controls.length, 4, 'submit, photo and filter remain separate control branches');
assert(controls[1].includes(".id('pinmony-search-submit')"), 'editing branch contains the submit button');
assert(controls[2].includes(".id('pinmony-photo-search-menu')"), 'photo branch contains the photo menu');
assert(controls[3].includes('pm_show_filters_12e6eb18'), 'result branch contains the filter control');
const softShadow = '.shadow({ radius: this.getUIContext().vp2px(6),';
assert.equal((header.match(/\.shadow\(/g) || []).length, 4, 'each requested control has exactly one shadow without a later override');
assert.equal((header.match(/\.shadow\(\{ radius: this\.getUIContext\(\)\.vp2px\(6\),/g) || []).length, 4,
  'search field, back, photo and filter use the density-aware soft shadow');
assert.equal((controls[0].match(/\.shadow\(/g) || []).length, 2, 'back and search field both have shadows');
assert(!controls[1].includes('.shadow('), 'submit button retains its existing appearance');
for (const control of [controls[2], controls[3]]) assert(control.includes(softShadow), 'photo and filter have shadows');
assert.equal((header.match(/color: this\.hdsDarkMode \? '#33000000' : '#14000000'/g) || []).length, 4,
  'all requested controls update shadow color with the theme');
assert.equal((header.match(/offsetX: 0, offsetY: this\.getUIContext\(\)\.vp2px\(1\)/g) || []).length, 4,
  'all requested controls retain the same subtle downward offset');
