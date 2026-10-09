const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const page = fs.readFileSync('feature_search/src/main/ets/components/PinWebSearchPage.ets', 'utf8');
const panel = fs.readFileSync('feature_search/src/main/ets/components/PinWebSearchQuizPanel.ets', 'utf8');
function method(name) {
  const start = page.indexOf('  private ' + name);
  assert(start >= 0);
  return page.slice(start, page.indexOf('\n  @Builder', start)).replace('private ', '');
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method('syncQuizPresentation()') + '}',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText + '\nHost;');
const host = new Host();
let sections = [], updates = 0;
host.flowSections = { length: () => sections.length, splice: (_start, _count, next) => { sections = next; updates++; } };
host.flowShape = '';
const entry = { mode: 'entry', title: '灵感', topics: [{ id: '0' }] };
host.snapshot = { quiz: entry, results: Array(25).fill({}) };
host.syncQuizPresentation();
assert.equal(host.quizSheetOpen, false);
assert.equal(sections[0].crossCount, 1, 'entry spans the result flow width');
assert.equal(sections[1].itemsCount, 25);
host.snapshot.quiz = { mode: 'picker', cards: [] };
host.syncQuizPresentation();
assert.equal(host.quizSheetOpen, true, 'picker opens a sheet');
assert.equal(host.entryQuiz, entry, 'picker preserves the underlying inspiration header');
assert.equal(updates, 1, 'selection snapshots do not replace flow sections or reset scroll');
host.snapshot.quiz = { mode: 'results' };
host.syncQuizPresentation();
assert.equal(host.quizSheetOpen, true);
host.snapshot.quiz = entry;
host.syncQuizPresentation();
assert.equal(host.quizSheetOpen, false, 'return dismisses the sheet');
host.snapshot.quiz = undefined;
host.syncQuizPresentation();
assert.equal(sections.length, 1, 'dismiss removes only the entry section');
assert.equal(sections[0].itemsCount, 25, 'ordinary results survive dismissal');
assert.match(page, /\.bindSheet\(\$\$this\.quizSheetOpen/);
assert.match(page, /height: '85%', preferType: SheetType\.BOTTOM/);
assert.match(page, /WaterFlow\(\{ scroller: this\.resultsScroller, sections: this\.flowSections \}\)[\s\S]*?FlowItem\(\) \{ this\.inspirationEntry\(\)/);
const picker = panel.slice(panel.indexOf('private selectionContent()'), panel.indexOf('\n  build()'));
assert(!picker.includes('quiz.topics'), 'candidate topics are absent from picker UI');
assert(!panel.includes('更多创意'));
assert.match(picker, /Button\('查看结果'\)/);
assert.match(picker, /\.onReachEnd\(/);
assert.match(page, /title: \{ title: .*选择灵感（最多10张）/);
assert(!picker.includes('pickerTitle'), 'sheet header owns the title instead of duplicating it in the body');
assert.match(picker, /Stack\(\{ alignContent: Alignment.Center \}\)/);
assert.match(picker, /if \(this.quiz.busy && this.quiz.cards.length === 0\) \{\s*LoadingProgress/);
assert.match(picker, /footer: this.paginationFooter/, 'pagination loader belongs to the scrolling flow footer');
assert.match(panel, /private paginationFooter\(\)[\s\S]*?this.quiz.busy && this.quiz.cards.length > 0/);
assert.match(picker, /objectFit\(ImageFit.Contain\)/, 'selection previews never crop the source image');
const geometryStart = panel.indexOf('  private cardWidth()');
const geometry = panel.slice(geometryStart, panel.indexOf('\n  @Builder', geometryStart));
const Geometry = vm.runInNewContext(ts.transpileModule('class Geometry {' + geometry + '}',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText + '\nGeometry;');
const metrics = new Geometry();
for (const width of [200, 328, 600]) {
  metrics.contentWidth = width;
  assert.equal(metrics.cardWidth() * 2 + 8, width, 'two images and their gap fit the measured flow width');
  for (const [imageWidth, imageHeight] of [[800, 200], [200, 1000], [236, 310]]) {
    assert.equal(metrics.cardHeight({ imageWidth, imageHeight }) / metrics.cardWidth(), imageHeight / imageWidth,
      'portrait and landscape previews keep the complete source aspect ratio');
  }
}
console.log('Quiz sheet transitions, underlying scroll sections, dismissal, picker content and result action checks passed');
