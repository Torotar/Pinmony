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
      exports: {}, deviceInfo: { apiAvailable: () => api >= 26 }, Color: { White: 'white' },
      uiMaterial: { isImmersiveMaterialSupported: () => supported, Material: { empty },
        ImmersiveStyle: { THICK: 3, ULTRA_THIN: 1 }, ImmersiveMaterial: class { constructor(value) { effects.push(value); } } }
    });
    new Host(mode, dark).applyNormalAttribute({ systemMaterial: value => calls.push(value) });
    assert.equal(calls.length, api >= 26 ? 1 : 0, 'older API never receives material calls');
    if (api >= 26 && mode !== 'off' && supported) {
      assert.equal(effects[0].style, mode === 'gentle' ? 3 : 1);
      assert.equal(effects[0].interactive, true); assert.equal(effects[0].applyShadow, false);
      assert.equal(effects[0].materialColor, dark ? '#301C2022' : '#30FFFFFF');
    } else { assert.equal(effects.length, 0); if (api >= 26) assert.equal(calls[0], empty); }
  }
}
console.log('Search photo material: actual shared Button modifier, API 24/25/26, support, themes, modes, anchor, action and readiness passed.');

assert(button.includes('.shadow({ radius: PinmonySearchHeaderMaterial.active'), 'photo button has compact shadow');
assert.equal((page.match(/\.shadow\(\{ radius: PinmonySearchHeaderMaterial.active/g)||[]).length,2, 'only search field and photo button gain shadows');
