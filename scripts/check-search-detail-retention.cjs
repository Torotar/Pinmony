const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const commits = require('./ui-commit-harness.cjs').createUiCommitHarness(ts);
const page = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const ast = ts.createSourceFile('search.ts', page.replace(/\bstruct\b/g, 'class'), 99, true);
const methods = [];
let back;
function visit(n) {
  if (ts.isMethodDeclaration(n) && ['ensureSearchDestination', 'activeChanged', 'syncImagePrefetchActivity'].includes(n.name.getText(ast))) methods.push(n.getText(ast));
  if (ts.isCallExpression(n) && n.expression.getText(ast).endsWith('.onBackPressed') && n.arguments[0]?.getText(ast).includes('this.detailReturnPreview')) back = n.arguments[0].getText(ast);
  ts.forEachChild(n, visit);
}
visit(ast);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '\nback = ' + back + ';} Host;', { compilerOptions: { target: 99 } }).outputText);
async function main() {
const paths = [{ name: 'pin-web-search' }], destination = paths[0];
let detailBack = 0, searchBack = 0;
const h = new Host(); h.uiCommits = new commits.Queue();
const prefetchActivity = []; h.imagePrefetch = { setActive: active => prefetchActivity.push(active) };
Object.assign(h, { active: true, mediaActive: true, automaticLoadingEnabled: true, detailReturnPreview: false, pagePresent: true, resultsOffset: 1420, categoriesCollapsed: true,
  searchPathStack: { size: () => paths.length, pushPath: p => paths.push(p), clear: () => { paths.length = 0; } },
  closePhotoSearch() {}, restoreHeroPosition() {}, tracePresentation() {}, onBack: () => detailBack++, handleSearchBack: () => searchBack++ });
for (let i = 0; i < 3; i++) {
  h.detailReturnPreview = true; h.active = false; h.activeChanged(); commits.flush();
  assert.equal(paths[0], destination, 'detail entry retains the original destination');
  assert.equal(h.back(), true, 'system back must not pop the retained search destination');
  h.active = true; h.detailReturnPreview = false; h.activeChanged(); commits.flush();
  assert.equal(paths[0], destination, 'detail return keeps the same WaterFlow owner');
  assert.equal(h.resultsOffset, 1420); assert.equal(h.categoriesCollapsed, true);
}
assert.equal(detailBack, 3); assert.equal(searchBack, 0);
assert.deepEqual(prefetchActivity, [false, true, false, true, false, true], 'retained detail cover pauses and resumes image prefetch without dropping page state');
h.active = false; h.detailReturnPreview = false; h.activeChanged(); commits.flush();
await Promise.resolve();
assert.equal(paths.length, 0, 'ordinary inactive roots still release navigation');
assert.equal(h.back(), false);
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(index.includes('preparingDetailReturn: this.preservingSearchForPin() ||'), 'retain from entry through return, rather than reconstructing only on back');
console.log('Search detail retention: repeated entry/return preserves destination, offset and header; system back delegates to detail; inactive roots release navigation');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
