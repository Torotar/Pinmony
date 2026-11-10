// Validate the version gates emitted by Hvigor, without mocking apiAvailable.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = 'entry/build/default/cache/default/default@CompileArkTS/esmodule/release/';
function load(relative, names, version, supported = true) {
  const source = fs.readFileSync(root + relative, 'utf8');
  const ast = ts.createSourceFile('compiled.ts', source, ts.ScriptTarget.Latest, true);
  const chunks = ast.statements.filter(n => ts.isFunctionDeclaration(n) || ts.isClassDeclaration(n) && names.includes(n.name?.text))
    .map(n => n.getText(ast).replace(/^export /, ''));
  const calls = [], effects = [], empty = {};
  const hosts = vm.runInNewContext(ts.transpileModule(chunks.join('\n') + '\n[' + names.join(',') + '];', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { deviceInfo: { sdkApiVersion: version, distributionOSApiVersion: version >= 26 ? 260000 : 60101 },
    Color: { Transparent: 'transparent', White: 'white' }, PinmonyRuntimeLog: { info() {} },
    uiMaterial: { isImmersiveMaterialSupported: () => supported, Material: { empty },
      ImmersiveStyle: { THICK: 3, REGULAR: 2, ULTRA_THIN: 1 },
      ImmersiveMaterial: class { constructor(options) { effects.push(options); } } },
    ColorMetrics: { resourceColor: () => ({ red: 230, green: 0, blue: 35 }), rgba: () => ({ color: 'tint' }) }
  });
  return { hosts, calls, effects, empty, target: { systemMaterial: v => calls.push(v), backgroundColor() {} } };
}
for (const version of [24, 25, 26]) {
  const home = load('feature_home/src/main/ets/components/PinmonyHomeCategoryMaterial.ts', ['PinmonyHomeCategoryMaterial'], version);
  new home.hosts[0]('immersive', true).applyNormalAttribute(home.target);
  assert.equal(home.effects.length, version >= 26 ? 1 : 0);
  for (const supported of [false, true]) for (const mode of ['off', 'gentle', 'immersive']) {
    const search = load('feature_search/src/main/ets/components/PinmonySearchPhotoMaterial.ts',
      ['PinmonySearchHeaderMaterial', 'PinmonySearchButtonMaterial', 'PinmonySearchPhotoMenuMaterial'], version, supported);
    new search.hosts[1](mode, false).applyNormalAttribute(search.target);
    assert.equal(search.calls.length, version >= 26 ? 1 : 0);
    assert.equal(search.effects.length, version >= 26 && supported && mode !== 'off' ? 1 : 0);
    const callback = () => {}, base = { onDisappear: callback };
    const options = search.hosts[2].options(mode, base);
    assert.equal(options, base); assert.equal(options.onDisappear, callback);
    assert.equal(!!options.systemMaterial, version >= 26);
    if (version >= 26 && mode === 'off') assert.equal(options.systemMaterial, search.empty);
  }
}
const page = fs.readFileSync(root + 'feature_search/src/main/ets/components/PinmonySearchPage.ts', 'utf8');
assert(page.includes('PinmonySearchPhotoMenuMaterial.options(this.immersiveLightMode'));
assert(page.includes('new PinmonySearchButtonMaterial(this.immersiveLightMode, this.hdsDarkMode)'));
console.log('Compiled Release material: real Hvigor gates on API 24/25/26, support/modes, actual button modifier and native menu callbacks passed.');
