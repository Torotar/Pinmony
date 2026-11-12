const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts;
try { ts = require('typescript'); }
catch (_) {
  if (!process.argv[2]) throw new Error('Pass the DevEco TypeScript module path as the first argument');
  ts = require(process.argv[2]);
}
const source = readSourceFileSync('feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets', 'utf8');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert.match(source, /if \(item\.canTranslate && this\.onTranslate\)/);
assert(source.includes('message: PinmonyI18n.render(item.translationError, this.uiLanguage)'), 'official translation notice resolves resources in the current language');
assert(source.includes('message: PinmonyI18n.render(item.repliesError, this.uiLanguage)'), 'official reply notice resolves resource markers');
assert.match(source, /item\.translationVisible && this\.hasCurrentTranslation\(item\) \? \(item\.translatedText \|\| item\.text\) : item\.text/,
  'translations change display without overwriting the editable original');
assert.match(source, /\.enabled\(!item\.translationLoading && !this\.result\.loading && !this\.result\.busy && !this\.result\.uncertain\)/);
assert.match(index, /onTranslate: PIN_NATIVE_DETAIL_READS_ENABLED \? \(id: string\) => this\.commentApiAction\('commentTranslate', id\) : undefined/);
const keyboardExpression = index.match(/keyboardAvoidMode:\s*(this\.activeSheetKind === 'comments' \?[\s\S]*?SheetKeyboardAvoidMode\.TRANSLATE_AND_SCROLL),/);
assert(keyboardExpression, 'Native Sheet keeps an explicit keyboard strategy');
const keyboardModes = { TRANSLATE_AND_RESIZE: 1, RESIZE_ONLY: 2, TRANSLATE_AND_SCROLL: 3 };
const keyboardMode = new Function('SheetKeyboardAvoidMode', `return ${keyboardExpression[1]};`);
for (const width of [0, 360, 599, 600, 920, 1280]) {
  assert.equal(keyboardMode.call({ activeSheetKind: 'comments', nativeSheetWindowWidth: width }, keyboardModes),
    width >= 600 ? keyboardModes.TRANSLATE_AND_RESIZE : keyboardModes.RESIZE_ONLY,
    `Comment keyboard mode follows the CENTER sheet breakpoint at width ${width}`);
  for (const kind of ['save', 'edit', 'share', 'searchFilter']) {
    assert.equal(keyboardMode.call({ activeSheetKind: kind, nativeSheetWindowWidth: width }, keyboardModes),
      keyboardModes.TRANSLATE_AND_SCROLL, `Unrelated ${kind} sheet retains its keyboard mode`);
  }
}
assert(index.includes('preferType: this.nativeSheetWindowWidth >= 600 ? SheetType.CENTER :'),
  'Keyboard strategy uses the same breakpoint as CENTER presentation');
assert.match(source, /List\(\{ space: 18, scroller: this\.listScroller \}\)[\s\S]*?\.width\('100%'\)\.layoutWeight\(1\)/,
  'the comment list absorbs the reduced viewport');
assert.match(source, /this\.composer\(\)[\s\S]*?\.height\('100%'\)/,
  'composer remains outside the list in the bounded sheet');
const modal = fs.readFileSync('common_ui/src/main/ets/components/PinmonyModalNavigation.ets', 'utf8');
assert(index.includes('private readonly commentsScroller: Scroller = new Scroller();'), 'Comment scroller survives ordinary snapshots and keyboard relayout');
assert(index.includes("immersiveScroll: this.activeSheetKind === 'comments'"), 'Only comments opt into title scroll immersion');
assert(index.includes("scrollControllers: this.activeSheetKind === 'comments' ? [this.commentsScroller] : []"), 'Comment title binds the retained actual controller');
assert(index.includes('PinmonyCommentsSheet({ listScroller: this.commentsScroller,'), 'Comment list and title receive the identical controller');
assert(source.includes('listScroller: Scroller = new Scroller();'), 'Standalone comments retain a valid list controller');
assert(modal.includes('enableComponentSafeArea: !this.immersiveScroll'), 'Comment title must not exclude scrolling content from its blur backdrop');
assert(source.includes('.contentStartOffset(this.titleBackdropHeight + 12)'), 'Title clearance belongs inside the scrolling List, not a fixed content padding');
assert(source.includes('.scrollBarMargin({ start: LengthMetrics.vp(this.titleBackdropHeight) })'), 'List scrollbar starts below the title');
assert(source.includes('private readonly titleBackdropHeight: number = 64;'), 'Single main-title inset uses documented MODAL backdrop metrics');
assert(!source.includes('padding({ left: 16, right: 16, top: 12, bottom: 20 })'), 'No fixed outer top gap prevents the list reaching the title');
assert.equal((source.match(/List\(\{ space: 18, scroller: this\.listScroller \}\)/g)||[]).length,1,'All loading, empty, error and loaded states use one persistent List');
assert(!source.includes('Blank().layoutWeight(1)'), 'Initial loading no longer swaps out the bound scrolling container');
assert(index.includes("keyboardAvoidedBySheet: this.activeSheetKind === 'comments'"), 'Only comments opt into the already-resized Sheet viewport');
assert(modal.includes('@Prop keyboardAvoidedBySheet: boolean = false;'), 'Other shared modal callers retain their default keyboard behavior');
assert(source.includes('.expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])'), 'Comment content does not avoid the keyboard a second time');
assert.match(modal,/if \(this\.keyboardAvoidedBySheet\)\s*\{\s*Column\(\) \{ this\.content\(\) \}\.width\('100%'\)\.height\('100%'\)\s*\.expandSafeArea\(\[SafeAreaType.KEYBOARD\], \[SafeAreaEdge.BOTTOM\]\)/, 'The complete content ancestor chain shares the Sheet keyboard ownership');
assert(modal.includes('[SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD, SafeAreaType.CUTOUT]'), 'Unrelated modal navigation retains the documented Navigation safe-area defaults');
const tree = ts.createSourceFile('comments.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const selectedMethods=[];
function visit(node){
  if(ts.isMethodDeclaration(node)&&['ageLabel','commentKey'].includes(node.name.getText(tree)))selectedMethods.push(node.getText(tree));
  ts.forEachChild(node,visit);
}visit(tree);
assert.equal(selectedMethods.length,2,'Extract only actual presentation methods, not intervening storage decorators');
const methods = selectedMethods.join('\n');
const compiled = ts.transpileModule('class Presentation {' + methods + '} Presentation;',
  { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const now = Date.parse('2026-10-01T06:30:00Z');
const Presentation = vm.runInNewContext(compiled, { Date: { now: () => now, parse: Date.parse }, JSON, Number, Math });
const view = new Presentation();
const copy = Object.fromEntries(JSON.parse(fs.readFileSync('common_foundation/src/main/resources/base/element/string.json', 'utf8')).string.map(row => [row.name, row.value]));
view.uiLanguage = 'zh';
view.uiText = key => copy[key];
assert.equal(view.ageLabel('Thu, 01 Oct 2026 06:29:30 +0000'), '刚刚');
assert.equal(view.ageLabel('2026-10-01T04:30:00Z'), '2小时');
assert.equal(view.ageLabel('2026-08-01T06:30:00Z'), '2个月');
assert.equal(view.ageLabel('2024-12-17T08:29:26Z'), '1年');
assert.equal(view.ageLabel('invalid'), '');
assert.equal(view.ageLabel('2026-10-02T06:30:00Z'), '刚刚');
const item = { id: '301', repliesOpen: false, repliesLoading: false, replies: [] };
const closed = view.commentKey(item);
assert.equal(view.commentKey(JSON.parse(JSON.stringify(item))), closed, 'Unchanged polling snapshots reuse rows');
item.repliesOpen = true; item.repliesLoading = true;
const loading = view.commentKey(item);
assert.notEqual(loading, closed, 'Opening a fold must invalidate the retained ForEach closure');
item.repliesLoading = false; item.replies = [{ id: '401', text: 'reply', liked: false }];
const ready = view.commentKey(item);
assert.notEqual(ready, loading, 'Loaded reply content must replace the loading row');
item.replies[0].liked = true;
assert.notEqual(view.commentKey(item), ready, 'Nested reply reactions invalidate the parent snapshot');
console.log('comments: compact age labels, stable unchanged rows, fold/loading/content/reaction refresh OK');
