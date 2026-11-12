const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const files = [
  'feature_profile/src/main/ets/components/PinmonyOrganizePage.ets',
  'feature_profile/src/main/ets/components/PinmonyPublishPage.ets',
  'feature_profile/src/main/ets/components/PinmonyPublishPhotoEditor.ets',
  'feature_profile/src/main/ets/components/PinmonyPublishBoardPage.ets',
  'feature_inbox/src/main/ets/components/PinmonyInboxPage.ets',
  'feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets',
  'feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets',
  'feature_inbox/src/main/ets/components/PinmonyBoardInvitationList.ets',
  'feature_search/src/main/ets/components/PinmonyPhotoHistoryPage.ets',
  'feature_board/src/main/ets/components/PinmonyBoardSectionPage.ets',
  'feature_pin/src/main/ets/components/PinmonyDetailPage.ets'
];
function objectAt(source, offset) {
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, true, ts.LanguageVariant.Standard, source.slice(offset));
  let depth = 0, start = -1;
  for (let token = scanner.scan(); token !== ts.SyntaxKind.EndOfFileToken; token = scanner.scan()) {
    if (token === ts.SyntaxKind.OpenBraceToken) { if (start < 0) start = scanner.getTokenPos(); depth++; }
    if (token === ts.SyntaxKind.CloseBraceToken && --depth === 0 && start >= 0) return source.slice(offset + start, offset + scanner.getTextPos());
  }
  throw new Error('Unterminated blur style');
}
let count = 0;
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  assert(!source.includes('immersiveLightEnabled'), file);
  if (file.endsWith('PinmonyDetailPage.ets')) {
    assert(source.includes(".bindToScrollable(this.imageLayer === 'search' ? [] : [this.detailScroller])"));
    assert(source.includes('top: this.titleContentInset() + 8'));
    assert.equal((source.match(/enableComponentSafeArea:\s*true/g) || []).length, 0, 'detail owns its scrolling title inset without adding a second component inset');
    assert.match(source, /if \(this\.imageLayer === 'search'\)[\s\S]*?avoidLayoutSafeArea: true, enableComponentSafeArea: false/,
      'specialized image search retains its existing title inset ownership');
  } else if (source.includes('PinmonyHdsTitleBar.modalStyle(')) {
    assert(source.includes('avoidLayoutSafeArea: false, enableComponentSafeArea: true'), file + ': MODAL owns title safe area');
    assert(source.includes('top: 12, bottom: 28'), file + ': MODAL form has no manual title spacer');
  } else assert(!/enableComponentSafeArea:\s*true/.test(source), file + ': scrolling must reach title backdrop');
  assert(source.includes('scrollBarMargin'), file + ': scrollbar avoids title');
  const matches = [...source.matchAll(/style:\s*\{\s*blurStrategy:/g)];
  assert(matches.length > 0 || source.includes('PinmonyHdsTitleBar.modalStyle('), file);
  // Shared MODAL style and close behavior are executed by check-panel-style-consistency.cjs.
  for (const match of matches) {
    const imageSearch = file.endsWith('PinmonyDetailPage.ets') && match === matches[0];
    const expression = objectAt(source, match.index);
    const evaluate = vm.runInNewContext(ts.transpileModule('function style() { return ' + expression + '; } style;',
      { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
      BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 3 },
      PinmonyImmersiveLight: { effect: m => m }, Color: { Transparent: 'transparent' }, $r: s => s
    });
    for (const mode of ['immersive', 'gentle', 'exquisite', 'off']) {
      const style = evaluate.call({ immersiveLightMode: mode, state: { phase: 'select' }, snapshot: { screen: 'chat' } });
      assert.equal(style.blurStrategy, imageSearch || mode === 'off' ? 0 : 1, file);
      assert.equal(style.scrollEffectOpts.enableScrollEffect, !imageSearch && mode !== 'off', file);
      if (imageSearch) assert.equal(style.originalStyle.backgroundStyle.blurRadius, 0, 'image search keeps its plain title bar');
      else assert.equal(style.scrollEffectOpts.scrollEffectType, 3, file);
    }
    if (file.endsWith('PinmonyOrganizePage.ets')) {
      for (const phase of ['boards', 'create']) {
        const style = evaluate.call({ immersiveLightMode: 'immersive', state: { phase } });
        assert.equal(style.blurStrategy, phase === 'boards' ? 0 : 1, 'save picker blur exception');
        assert.equal(style.scrollEffectOpts.enableScrollEffect, phase !== 'boards');
        if (phase === 'boards') {
          assert.equal(style.originalStyle.backgroundStyle.blurRadius, 0);
          assert.equal(style.originalStyle.backgroundStyle.backgroundColor, 'app.color.page_background');
          assert.equal(style.systemMaterialEffect, 'immersive', 'organize picker buttons follow the shared material preference');
        }
      }
    }
    if (file.endsWith('PinmonyOrganizePage.ets')) {
      for (const mode of ['immersive','gentle','exquisite','off']) {
        const style = evaluate.call({immersiveLightMode:mode,state:{phase:'boards'}});
        assert.equal(style.systemMaterialEffect,mode,'picker material updates in all four modes');
        for(const content of [style.originalStyle.contentStyle,style.scrollEffectStyle.contentStyle]) {
          assert.equal(content.backIconStyle.backgroundColor,mode==='off'||mode==='gentle'?'transparent':undefined);
          assert.equal(content.menuStyle.backgroundColor,mode==='off'||mode==='gentle'?'transparent':undefined);
          assert.equal(content.backIconStyle.iconColor,'app.color.primary_text');
        }
      }
    }
    if (file.endsWith('PinmonyInboxFlowPage.ets')) {
      for (const mode of ['immersive', 'gentle', 'exquisite', 'off']) {
        const style = evaluate.call({ immersiveLightMode: mode, snapshot: { screen: 'compose' } });
        assert.equal(style.blurStrategy, 0);
        assert.equal(style.scrollEffectOpts.enableScrollEffect, false);
        assert.equal(style.originalStyle.backgroundStyle.backgroundColor, 'app.color.page_background');
        assert.equal(style.scrollEffectStyle.backgroundStyle.blurRadius, 0);
        assert.equal(style.systemMaterialEffect, mode, 'compose buttons reuse the shared material preference');
        for (const content of [style.originalStyle.contentStyle, style.scrollEffectStyle.contentStyle]) {
          const transparent = mode === 'off' || mode === 'gentle' ? 'transparent' : undefined;
          assert.equal(content.backIconStyle.backgroundColor, transparent, 'back button retains material surface');
          assert.equal(content.menuStyle.backgroundColor, transparent, 'next button retains material surface');
          assert.equal(content.menuStyle.iconColor, 'app.color.primary_text');
        }
      }
    }
    count++;
  }
  if (process.argv.includes('--compiled')) {
    const generated = fs.readFileSync('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/' + file.replace(/\.ets$/, '.ts'), 'utf8');
    assert(!generated.includes('immersiveLightEnabled'), file + ': compiled getter');
    assert(generated.includes('scrollBarMargin'), file + ': compiled scrollbar');
  }
}
const editor = fs.readFileSync(files[2], 'utf8');
assert(editor.includes('.barOverlap(true)'), 'product tab content extends behind the fixed bar');
assert(editor.includes("phase === 'products' || phase === 'productSearch' ? [this.productScroller,this.productLinkScroller]"), 'search binds its actual result scroller');
const inbox = fs.readFileSync(files[6], 'utf8');
assert(inbox.includes('this.titleContentInset() + this.flowHeaderHeight'), 'chat/compose header inset remains in scrolling content');
const history = fs.readFileSync(files[8], 'utf8');
assert.match(history, /margin:\s*\{\s*top:\s*this\.titleContentInset\(\)\s*\+\s*16\s*,\s*bottom:\s*32\s*\}/,
  'history waterfall retains its title inset, section gap and bottom spacing');
console.log('Flow title blur: ' + files.length + ' components, ' + count + ' title styles, four modes, fixed controls and scrollbar margins passed');
