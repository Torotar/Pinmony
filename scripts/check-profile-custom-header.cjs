const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const wanted = ['hubTitlePosition', 'hubTitlePaneVisible', 'hubTitleBottomHeight', 'hubTitleSearchOpacity', 'hubHeaderBackgroundOpacity', 'hubPaneChromeOffset', 'hubHeaderInset', 'hubChromeHeight', 'hubCollapseHeight', 'hubContentInset', 'profileBodyHeight'];
const methods = [];
function visit(node) { if (ts.isMethodDeclaration(node) && wanted.includes(node.name.getText(ast))) methods.push(node.getText(ast)); ts.forEachChild(node, visit); }
visit(ast); assert.equal(methods.length, wanted.length);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const h = new Host(); Object.assign(h, { hubTab: 'boards', hubPagerPosition: -1, hubChromeOffset: 0,
  hubPaneChromeOffsets: new Map([['pins', 112], ['collages', 52]]), statusBarHeightPx: 24,
  getUIContext: () => ({ px2vp: n => n }), modern: () => true, hubPane: true });
assert.equal(h.profileBodyHeight(), '100%');
h.hubPane = false;
for (const height of [650, 900, 480]) {
  h.profileViewportHeight = height;
  assert.equal(h.profileBodyHeight(), height, 'root body must use measured full viewport, not reduced HDS percentage constraint');
}
h.profileViewportHeight = 0; assert.equal(h.profileBodyHeight(), '100%');
h.hubPane = true;
assert(source.includes('.height(this.profileBodyHeight())'));
assert(source.includes('this.profileViewportHeight = height'));
assert.equal(h.hubTitlePosition(), 1);
assert.equal(h.hubTitlePaneVisible('boards'), true); assert.equal(h.hubTitlePaneVisible('pins'), false);
for (const position of [0.1, 0.5, 0.9]) {
  h.hubPagerPosition = position;
  assert.equal(h.hubTitlePaneVisible('pins'), true); assert.equal(h.hubTitlePaneVisible('boards'), true);
  assert.equal(h.hubTitlePaneVisible('collages'), false);
  assert.equal(-h.hubTitlePosition() * 800, -position * 800);
}
h.hubPagerPosition = 1.5; assert.equal(h.hubTitlePaneVisible('pins'), false); assert.equal(h.hubTitlePaneVisible('collages'), true);
h.hubPagerPosition = -1; assert.equal(h.hubTitlePosition(), 1, 'cancel returns to selected header');
assert.equal(h.hubContentInset(), 216); h.hubChromeOffset = 112; assert.equal(h.hubContentInset(), 216);
for (const tab of ['pins', 'boards', 'collages']) {
  h.hubTab = tab;
  for (const inset of [0, 24, 48]) {
    h.statusBarHeightPx = inset;
    assert.equal(h.hubContentInset(), inset + 80 + (tab === 'collages' ? 52 : 112), 'only scroll content reserves title space inside expanded viewport');
  }
}
h.hubTab = 'boards';
assert.equal(h.hubPaneChromeOffset('pins'), 112); assert.equal(h.hubPaneChromeOffset('collages'), 52);
for (const tab of ['pins', 'boards', 'collages']) {
  h.hubTab = tab;
  const range = tab === 'collages' ? 52 : 112;
  for (const offset of [0, range / 2, range]) {
    h.hubChromeOffset = offset;
    assert.equal(h.hubTitleBottomHeight(), 24 + range - offset, 'expanded controls retain their full host; collapse shrinks the backdrop');
  }
}
h.hubTab = 'boards'; h.hubChromeOffset = 0;
for (const position of [0, 0.25, 0.5, 0.75, 1]) {
  h.hubPagerPosition = position;
  assert.equal(h.hubTitleBottomHeight(), 24 + 112 * position, 'swipe interpolates retained pane heights');
}
h.hubPagerPosition = 1.5; assert.equal(h.hubTitleBottomHeight(), 80);
h.hubPagerPosition = -1; assert.equal(h.hubTitleBottomHeight(), 136, 'cancel restores selected expanded host');
h.hubPaneChromeOffsets.set('pins', 0);
for (const position of [0, 0.25, 0.5, 0.75, 1]) {
  h.hubPagerPosition = position;
  assert.equal(h.hubTitleSearchOpacity(), 1, 'shared search stays fully visible between expanded pins and boards');
}
let previousSearchOpacity = 1;
for (const position of [1, 1.25, 1.5, 1.75, 2]) {
  h.hubPagerPosition = position;
  const opacity = h.hubTitleSearchOpacity();
  assert(opacity >= 0 && opacity <= previousSearchOpacity, 'collage transition fades monotonically');
  previousSearchOpacity = opacity;
}
assert.equal(previousSearchOpacity, 0, 'collages retain their no-search layout');
h.hubPagerPosition = -1; h.hubChromeOffset = 56;
assert(h.hubTitleSearchOpacity() > 0 && h.hubTitleSearchOpacity() < 0.5, 'search fades early enough to fit the shrinking host');
for (const pinsOffset of [0, 28, 56, 84, 112]) for (const boardsOffset of [0, 28, 56, 84, 112]) for (const collageOffset of [0, 26, 52]) {
  h.hubPaneChromeOffsets.set('pins', pinsOffset);
  h.hubPaneChromeOffsets.set('collages', collageOffset);
  h.hubChromeOffset = boardsOffset;
  for (let position = 0; position <= 2; position += 0.025) {
    h.hubPagerPosition = Math.min(position, 2);
    const opacity = h.hubTitleSearchOpacity();
    if (opacity > 0) {
      const top = 24 * opacity;
      assert(top >= 0 && top + 60 <= h.hubTitleBottomHeight() + 1e-8, 'visible search/publish row must fit entirely inside the clipping host');
    }
  }
}
h.hubPagerPosition = -1;
h.hubPaneChromeOffsets.set('pins', 0); h.hubPaneChromeOffsets.set('collages', 52);
h.hubChromeOffset = 0;
const retainedTitle = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfileHubTitle.ets', 'utf8');
const begin = source.indexOf('  private hubCustomTitleBottom()');
const title = source.slice(begin, source.indexOf('  private profileRefreshIndicator()', begin));
assert(retainedTitle.includes('avatarSize: 44')); assert(title.includes('this.hubSearch()')); assert(title.includes('this.hubFilters(tab)'));
assert(title.includes(".accessibilityLevel(tab === this.hubTab")); assert(title.includes('.hitTestBehavior(tab === this.hubTab'));
assert(source.includes('stackBuilderComponent: this.hubTopTitleContent'));
assert(source.includes('bottomBuilder: { builder: this.hubBottomTitleBuilder, height: this.hubTitleBottomHeight() }'));
assert(retainedTitle.includes(".height(56).clip(false)"), 'retained MINI content must fit the 56vp title slot');
assert(title.includes('.position({ x: 0, y: 24 })'), '80vp top header continues 24vp into bottom custom region');
assert(source.slice(source.indexOf('  private hubTitleBarOptions()'), begin).includes('enableComponentSafeArea: true'));
assert(source.includes('.ignoreLayoutSafeArea(this.modern() && !this.hubPane ? [LayoutSafeAreaType.SYSTEM] : [], [LayoutSafeAreaEdge.TOP])'), 'expand only the modern root body under HDS safe area');
assert.equal(((title + retainedTitle).match(/backgroundColor\(\$r\('app.color.page_background'\)\)/g) || []).length, 3, 'top, shared search and filter rows retain their theme backdrop');
assert(retainedTitle.includes('.opacity(this.backdropOpacity)') && source.includes('backdropOpacity: this.hubHeaderBackgroundOpacity()'), 'top backdrop fades away with original scroll state');
assert(title.includes('.opacity(this.hubTitlePaneVisible(tab) ? 1 - this.hubPaneChromeOffset(tab)'), 'filter backdrop fades with its controls instead of remaining as a white block');
assert.equal(56 + 24, 80, 'collapsed HDS host ends with the original tab/avatar row');
assert(title.includes('.height(this.hubTitleBottomHeight())') && title.includes('.clip(true)'), 'expanded controls fit within the dynamic material host');
assert(retainedTitle.includes("Column().width('100%').height(this.statusInsetVp + 80)"));
assert(retainedTitle.includes('.position({ x: 0, y: -this.statusInsetVp })'), 'theme backdrop extends over the status bar without moving controls');
assert(!title.includes('.animation('), 'frame-driven values must not receive a second delayed property animation');
assert.equal((source.match(/this\.hubFilters\(/g) || []).length, 1, 'no per-pane filter overlays');
assert.equal((source.match(/this\.hubSearch\(\)/g) || []).length, 1, 'search lives only in custom title');
const searchStart = title.indexOf('Column() { this.hubSearch() }');
assert(searchStart > title.indexOf('.translate({ x: -this.hubTitlePosition() * this.contentWidth })'), 'shared search is outside the horizontally translated filter row');
const search = title.slice(searchStart, title.indexOf("}.width('100%').height(this.hubTitleBottomHeight())", searchStart));
assert(search.includes('.position({ x: 0, y: 24 * this.hubTitleSearchOpacity() })') && !search.includes('.translate('), 'shared search and publish rise with collapse and remain outside horizontal filter motion');
assert(search.includes("this.hubTab !== 'collages'") && search.includes("'no-hide-descendants'"), 'hidden shared search cannot receive input or accessibility focus');
assert(!source.includes(".position({x:0,y:this.getUIContext().px2vp(this.statusBarHeightPx)})"));
assert(source.includes('.bindToScrollable(this.hubScrollBinding())'));
const searchEntryStart = source.indexOf('  private hubSearch()');
const searchEntry = source.slice(searchEntryStart, source.indexOf('  private updateHubTitleContent()', searchEntryStart));
assert(searchEntry.includes("if (deviceInfo.apiAvailable('26.0.0'))"));
const legacySearch = searchEntry.slice(searchEntry.indexOf('} else {'));
assert(!legacySearch.includes('.systemMaterial('), 'API24 search keeps its original supported attributes');
assert.equal((searchEntry.match(/this\.hubSearchContent\(\)/g) || []).length, 2, 'both API branches reuse the same search label and icon');
assert.equal((searchEntry.match(/if\(this\.onSearch\)this\.onSearch\(\)/g) || []).length, 2, 'both versions retain the real search route');
assert.equal((searchEntry.match(/if\(this\.onPublish\)this\.onPublish\(\)/g) || []).length, 2, 'both versions retain the real publish route');
assert.equal((searchEntry.match(/\.width\(44\)\.height\(44\)/g) || []).length, 2, 'publish retains its circular dimensions');
assert.equal((searchEntry.match(/accessibilityText\(this\.uiText\('pm_publish_b61f333b'\)\)/g) || []).length, 2);
const filtersStart = source.indexOf('  private hubFilters(');
const filtersEnd = source.indexOf('  private hubSearchContent()', filtersStart);
const filterButtons = source.slice(filtersStart, filtersEnd);
assert.equal((filterButtons.match(/deviceInfo.apiAvailable/g) || []).length, 2);
const stateStart = source.indexOf('  private hubStateButton(');
const stateBlock = source.slice(stateStart, source.indexOf('  private selectPinView', stateStart));
const modernState = stateBlock.slice(0, stateBlock.indexOf('    } else {\n    Toggle('));
assert(modernState.includes('Button({type:ButtonType.Normal})') && !modernState.includes('Toggle('), 'API26 uses Button material host rather than Toggle button skin');
assert(modernState.includes('.padding(0)') && modernState.includes('.height(40)'), 'preserve filter geometry');
assert(stateBlock.includes('materialColor: this.hubStateMaterialColor(kind)'), 'selected filters retain their accent through material tint');
assert(!stateBlock.slice(stateBlock.indexOf('} else {')).includes('.systemMaterial('), 'legacy toggle has no new material attribute');
assert.equal((stateBlock.match(/this.requestHub\(\)/g) || []).length, 2, 'both toggle branches retain the filter request');
const materialExpressions = [];
function findMaterial(node) {
  if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.name.text === 'systemMaterial') materialExpressions.push(node.arguments[0].getText(ast));
  ts.forEachChild(node, findMaterial);
}
findMaterial(ast); assert.equal(materialExpressions.length, 5);
for (const [index, materialExpression] of materialExpressions.entries()) for (const supported of [false, true]) for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
  const empty = {}, effects = [];
  const evaluate = vm.runInNewContext('(function(){ return (' + materialExpression + '); })', {
    kind: 'favorite', uiMaterial: { Material: { empty }, ImmersiveStyle: { THICK: 3, ULTRA_THIN: 0, REGULAR: 2 },
      isImmersiveMaterialSupported: () => supported,
      ImmersiveMaterial: class { constructor(options) { effects.push(options); } } }
  });
  const result = evaluate.call({ immersiveLightMode: mode, hubSelected: () => false, hubStateMaterialColor: () => undefined });
  if (index === 0) {
    const selected = evaluate.call({ immersiveLightMode: mode, hubSelected: () => true, hubStateMaterialColor: () => 'accent-tint' });
    if (!supported || mode === 'off') assert.equal(selected, empty, 'off/unsupported clears selected material');
    else {
      assert.notEqual(selected, empty, 'selected filter retains immersive material');
      assert.equal(effects.at(-1).materialColor, 'accent-tint', 'selected material preserves the accent tint');
    }
  }
  if (!supported || mode === 'off') assert.equal(result, empty, 'off/unsupported clears the material');
  else {
    assert.equal(effects[0].style, mode === 'gentle' ? 3 : index === 3 ? 0 : 2);
    assert.equal(effects[0].interactive, true); assert.equal(effects[0].applyShadow, false);
    assert.equal(effects[0].colorInvert, false);
  }
}
console.log('Profile custom title passed: all header controls in HDS builder, drag/cancel positions, retained collapse, stable body inset, hidden pane touch/accessibility gates.');

assert.equal((source.match(/\.shadow\(\{ radius:/g)||[]).length,5, 'all five profile control surfaces use compact explicit shadows');

assert(!modernState.includes('.shadow({ radius: !this.hubSelected(kind) &&'), 'selected accent filters retain their material shadow');
