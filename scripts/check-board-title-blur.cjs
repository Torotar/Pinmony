const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function method(source, name) {
  const start = source.indexOf('private ' + name + '(');
  assert(start >= 0, name);
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, true, ts.LanguageVariant.Standard, source.slice(start));
  let depth = 0, opened = false;
  for (let token = scanner.scan(); token !== ts.SyntaxKind.EndOfFileToken; token = scanner.scan()) {
    if (token === ts.SyntaxKind.OpenBraceToken) { depth++; opened = true; }
    if (token === ts.SyntaxKind.CloseBraceToken && --depth === 0 && opened) return source.slice(start, start + scanner.getTextPos());
  }
  throw new Error(name);
}
for (const [page, names] of [
  ['PinmonyBoardPage', ['titleContentInset', 'titleBarOptions', 'phase', 'selectingPins', 'isDiscoveryBoard', 'boardTitleMenu']],
  ['PinmonyBoardCollaboratorsPage', ['titleContentInset', 'titleOptions']]
]) {
  const file = 'feature_board/src/main/ets/components/' + page + '.ets';
  const source = fs.readFileSync(file, 'utf8');
  assert(!source.includes('immersiveLightEnabled'), page);
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + names.map(n => method(source, n)).join('\n') + '} Host;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
    BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 3 },
    PinmonyImmersiveLight: { effect: m => m }, Color: { Transparent: 'transparent' }, $r: s => s,
    SymbolGlyphModifier: class { fontColor() { return this; } fontSize() { return this; } fontWeight() { return this; } },
    FontWeight: { Medium: 500 }, PinmonyI18n: { render: s => s }
  });
  for (const mode of ['immersive', 'gentle', 'exquisite', 'off']) {
    const host = new Host();
    Object.assign(host, { immersiveLightMode: mode, statusBarHeightPx: 84, getUIContext: () => ({ px2vp: n => n / 3.5 }),
      creatingTarget: false, creatingBoardTarget: false, snapshot: { title: 'Board', editable: false, phase: 'members', users: [] }, selectedIds: [], sectionEditName: '', uiText: s => s,
      modernBoardActions: () => false, canSave: () => false });
    assert.equal(host.titleContentInset(), 80);
    const flows = page === 'PinmonyBoardPage' ? [undefined, ...['section', 'edit', 'sectionEdit', 'organize', 'targets', 'ideas'].map(phase => ({ phase })), { phase: 'edit', cover: {} }] : ['members', 'invite', 'permissions'].map(phase => ({ phase }));
    for (const flow of flows) {
      host.snapshot.flow = flow;
      if (page === 'PinmonyBoardCollaboratorsPage') host.snapshot.phase = flow.phase;
      const options = host[names[1]]();
      assert.equal(options.enableComponentSafeArea, page === 'PinmonyBoardPage' && flow?.phase === 'targets');
      if (page === 'PinmonyBoardPage' && flow?.phase === 'targets') {
        assert.equal(host.titleContentInset(), 0, 'plain picker uses HDS safe area without duplicate inset');
        assert.equal(options.style.originalStyle.contentStyle.backIconStyle.backgroundColor, 'transparent');
        assert.equal(options.style.systemMaterialEffect, undefined);
      }
      const enabled = mode !== 'off' && !(page === 'PinmonyBoardPage' && flow?.phase === 'targets');
      assert.equal(options.style.blurStrategy, enabled ? 1 : 0);
      assert.equal(options.style.scrollEffectOpts.enableScrollEffect, enabled);
      if (!enabled) assert.equal(options.style.originalStyle.backgroundStyle.blurRadius, 0);
      assert.equal(options.style.scrollEffectOpts.scrollEffectType, 3);
    }
  }
  assert(source.includes('.scrollBarMargin({ start: LengthMetrics.vp('), page + ': scrollbar margin');
  if (process.argv.includes('--compiled')) {
    const generated = fs.readFileSync('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/' + file.replace(/\.ets$/, '.ts'), 'utf8');
    assert(!generated.includes('immersiveLightEnabled'), page + ': compiled getter');
    assert(generated.includes('scrollBarMargin'), page + ': compiled scrollbar');
  }
}
console.log('Board title blur: main/section/edit/organize/targets/ideas/cover, collaborators, four modes and scrollbar margins passed');
