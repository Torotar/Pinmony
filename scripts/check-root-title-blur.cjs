const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const pages = [
  ['feature_home', 'PinmonyHomePage', ['homeTitleBarOptions']],
  ['feature_search', 'PinmonySearchPage', ['searchTitleBarOptions']],
  ['feature_profile', 'PinmonyProfilePage', ['hubTitleBarOptions', 'profileTitleOptions', 'rootTitleBarOptions']]
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
      const options = host[method]();
      const style = options.style;
      assert.equal(style.blurStrategy, mode === 'off' ? 0 : 1, `${page}.${method}: strategy ${mode}`);
      assert.equal(style.thermoCtrl, mode !== 'off');
      assert.equal(style.scrollEffectOpts.enableScrollEffect, mode !== 'off');
      if (method === 'profileTitleOptions') {
        assert.equal(style.originalStyle.backgroundStyle.blurRadius, mode === 'off' ? 0 : 18);
        assert.equal(style.scrollEffectStyle.backgroundStyle.blurRadius, mode === 'off' ? 0 : 18);
      }
      if (method === 'rootTitleBarOptions') {
        assert.equal(options.avoidLayoutSafeArea, true);
        assert.equal(options.enableComponentSafeArea, false, 'legacy content must scroll behind the HDS title region');
        assert.equal(style.scrollEffectOpts.scrollEffectType, 3);
        assert.equal(options.content.menu.value.length, 1, 'legacy settings action stays in the title bar');
      }
    }
  }
  if (process.argv.includes('--compiled')) {
    const generated = fs.readFileSync(`entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/${module}/src/main/ets/components/${page}.ts`, 'utf8');
    assert(!generated.includes('immersiveLightEnabled'), page + ': stale getter references in compiled output');
    for (const method of methods) assert(extract(generated, method).includes("this.immersiveLightMode !== 'off'"));
  }
}
const profileSource = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
const legacyNavigation = extract(profileSource, 'legacyProfileNavigation');
assert(legacyNavigation.includes('HdsNavigation() { this.profileBody() }'));
assert(legacyNavigation.includes('.bindToScrollable([this.scroller])'));
assert(!legacyNavigation.includes('.height(56)'), 'the legacy title bar is no longer an isolated fixed-height navigation');
assert(!profileSource.includes('this.rootTitleBar()'), 'the scrolling body cannot contain a duplicate legacy toolbar');
assert(profileSource.includes('.padding({top:this.profileBodyTopInset()})'), 'only scrollable content receives the initial title inset');
const InsetHost = vm.runInNewContext(ts.transpileModule('class InsetHost {' + extract(profileSource, 'profileBodyTopInset') + '} InsetHost;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const inset = new InsetHost();Object.assign(inset,{statusBarHeightPx:84,getUIContext:()=>({px2vp:n=>n/3.5}),modern:()=>false,hubContentInset:()=>216});
assert.equal(inset.profileBodyTopInset(),80,'legacy first frame preserves the status and title inset');
inset.onBack=()=>{};assert.equal(inset.profileBodyTopInset(),80,'secondary profile uses the same scrollable title inset as the legacy profile');
inset.onBack=undefined;inset.modern=()=>true;assert.equal(inset.profileBodyTopInset(),216,'modern profile geometry stays unchanged');
const indexSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(indexSource.includes('this.activeTab === 3 && !!this.profileStore.profile'), 'Index yields the legacy root safe area to HDS too');
console.log('Root title blur: home/search/profile configuration gates, profile radius and optional compiled-output checks passed');
