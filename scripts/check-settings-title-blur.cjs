const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const settings = 'feature_settings/src/main/ets/components/';
const pages = ['Account', 'About', 'Notifications', 'DisplaySettings', 'RecommendationSettings',
  'VisibilitySettings', 'SocialPermissions', 'BoardRecovery'].map(name => [settings + 'Pinmony' + name + 'Page.ets', false]);
pages.push(['feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets', true]);
function objectAt(source, offset) {
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, true, ts.LanguageVariant.Standard, source.slice(offset));
  let depth = 0, start = -1;
  for (let token = scanner.scan(); token !== ts.SyntaxKind.EndOfFileToken; token = scanner.scan()) {
    if (token === ts.SyntaxKind.OpenBraceToken) { if (start < 0) start = scanner.getTokenPos(); depth++; }
    if (token === ts.SyntaxKind.CloseBraceToken && --depth === 0 && start >= 0)
      return source.slice(offset + start, offset + scanner.getTextPos());
  }
  throw new Error('Unterminated title options');
}
for (const [file, profile] of pages) {
  const source = fs.readFileSync(file, 'utf8');
  assert(!source.includes('immersiveLightEnabled'), file + ': avoid omitted struct getters');
  const offset = source.includes('private options()') ? source.indexOf('return {', source.indexOf('private options()')) : source.indexOf('.titleBar({');
  assert(offset >= 0, file);
  const expression = objectAt(source, offset);
  const evaluate = vm.runInNewContext(ts.transpileModule('function options() { return ' + expression + '; } options;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
    BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 3 },
    PinmonyImmersiveLight: { effect: mode => mode }, Color: { Transparent: 'transparent' },
    SymbolGlyphModifier: class { fontColor() { return this; } }, $r: name => name
  });
  for (const mode of ['immersive', 'gentle', 'exquisite', 'off']) {
    const host = { immersiveLightMode: mode, snapshot: { mode: 'edit' }, store: { screen: 'account' },
      title: () => '', text: () => '', uiText: () => '', canSave: () => false, canRestore: () => false };
    const options = evaluate.call(host);
    assert.equal(options.enableComponentSafeArea, false, file);
    assert.equal(options.style.blurStrategy, mode === 'off' ? 0 : 1, file);
    assert.equal(options.style.scrollEffectOpts.enableScrollEffect, mode !== 'off', file);
    assert.equal(options.style.scrollEffectOpts.scrollEffectType, 3, file);
    assert.equal(options.style.originalStyle.backgroundStyle.blurRadius, mode === 'off' ? 0 : 18, file);
    if (profile) {
      host.snapshot.mode = 'following';
      assert.equal(evaluate.call(host).enableComponentSafeArea, true, 'unrelated profile lists keep their geometry');
    }
  }
  assert(source.includes('.scrollBarMargin({ start: LengthMetrics.vp('), file + ': scrollbar clears title');
  assert(source.includes('.bindToScrollable([this.scroller])'), file);
  if (process.argv.includes('--compiled')) {
    const generated = fs.readFileSync('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/' + file.replace(/\.ets$/, '.ts'), 'utf8');
    assert(!generated.includes('immersiveLightEnabled'), file + ': compiled getter references');
    assert(generated.includes('scrollBarMargin'), file + ': compiled scrollbar margin');
  }
}
const social = fs.readFileSync(settings + 'PinmonySocialPermissionsPage.ets', 'utf8');
assert(social.includes('LengthMetrics.vp(this.titleContentInset() + 52)'), 'message scrollbar clears fixed tabs');
const recovery = fs.readFileSync(settings + 'PinmonyBoardRecoveryPage.ets', 'utf8');
assert(recovery.includes('return this.panelMode ? 0 :'), 'sheet mode has no full-page title inset');
console.log('Settings title blur: nine page configurations, four modes, edit-only scope, scrollbar margins and optional compiled checks passed');
