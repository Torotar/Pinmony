const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const pages = [
  ['feature_home', 'PinmonyHomePage', ['homeTitleBarOptions']],
  ['feature_search', 'PinmonySearchPage', ['searchTitleBarOptions']],
  ['feature_profile', 'PinmonyProfilePage', ['hubTitleBarOptions', 'profileTitleOptions']]
];
function extract(code, name) {
  const start = code.indexOf('private ' + name + '(');
  assert(start >= 0, name);
  const text = code.slice(start);
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, true, ts.LanguageVariant.Standard, text);
  let depth = 0, opened = false;
  for (let token = scanner.scan(); token !== ts.SyntaxKind.EndOfFileToken; token = scanner.scan()) {
    if (token === ts.SyntaxKind.OpenBraceToken) { depth++; opened = true; }
    if (token === ts.SyntaxKind.CloseBraceToken && --depth === 0 && opened) return text.slice(0, scanner.getTextPos());
  }
  throw new Error('Unterminated method ' + name);
}
for (const [module, page, methods] of pages) {
  const source = fs.readFileSync(`${module}/src/main/ets/components/${page}.ets`, 'utf8');
  assert(!source.includes('immersiveLightEnabled'), page + ': custom struct accessor must not gate blur');
  const output = ts.transpileModule('class Host {' + methods.map(name => extract(source, name)).join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
  const Host = vm.runInNewContext(output, {
    BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 3 },
    PinmonyImmersiveLight: { effect: mode => mode }, Color: { Transparent: 'transparent' }, $r: name => name
  });
  for (const mode of ['immersive', 'gentle', 'exquisite', 'off']) {
    const host = new Host();
    Object.assign(host, { immersiveLightMode: mode, inputEditing: false, visibleCategories: () => ['pins'], uiText: name => name });
    for (const method of methods) {
      const style = host[method]().style;
      assert.equal(style.blurStrategy, mode === 'off' ? 0 : 1, `${page}.${method}: strategy ${mode}`);
      assert.equal(style.thermoCtrl, mode !== 'off');
      assert.equal(style.scrollEffectOpts.enableScrollEffect, mode !== 'off');
      if (method === 'profileTitleOptions') {
        assert.equal(style.originalStyle.backgroundStyle.blurRadius, mode === 'off' ? 0 : 18);
        assert.equal(style.scrollEffectStyle.backgroundStyle.blurRadius, mode === 'off' ? 0 : 18);
      }
    }
  }
  if (process.argv.includes('--compiled')) {
    const generated = fs.readFileSync(`entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/${module}/src/main/ets/components/${page}.ts`, 'utf8');
    assert(!generated.includes('immersiveLightEnabled'), page + ': stale getter references in compiled output');
    for (const method of methods) assert(extract(generated, method).includes("this.immersiveLightMode !== 'off'"));
  }
}
console.log('Root title blur: home/search/profile configuration gates, profile radius and optional compiled-output checks passed');
