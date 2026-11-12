const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const commits = require('./ui-commit-harness.cjs').createUiCommitHarness(ts);
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const a = source.indexOf('  private ' + name + '('), b = source.indexOf('\n  private ', a + 1);
  assert(a >= 0); return source.slice(a, b);
}
const appearStart = source.indexOf('  aboutToAppear(): void {');
const appearEnd = source.indexOf('  private restoreResultsScroll', appearStart);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['ensureSearchDestination', 'activeChanged', 'syncImagePrefetchActivity'].map(method).join('\n') +
  source.slice(appearStart, appearEnd) + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {});
(async () => {
  const h = new Host(), paths = [];
  h.uiCommits = new commits.Queue();
  Object.assign(h, { pagePresent: false, active: false, initialResultsScrollOffset: 0,
    snapshot: { session: 0, pageKey: 'https://www.pinterest.com/search/', query: '' },
    rememberDiscoverySnapshot() {}, committedQuery: () => '', closePhotoSearch() {}, restoreHeroPosition() {}, syncQuizPresentation() {},
    fillInitialViewport() {}, tracePresentation() {},
    searchPathStack: { size: () => paths.length, pushPath: p => paths.push(p), clear: () => paths.splice(0) } });
  h.aboutToAppear(); assert.equal(h.pagePresent, true); assert.equal(paths.length, 0, 'inactive cached page starts without a destination');
  h.active = true; h.activeChanged(); assert.equal(paths.length, 1);
  h.activeChanged(); assert.equal(paths.length, 1, 'updates never duplicate destinations');
  h.active = false; h.activeChanged(); commits.flush(); await Promise.resolve();
  assert.equal(paths.length, 0, 'inactive search releases its destination after the retained-presentation guard');
  h.active = true; h.activeChanged(); assert.equal(paths.length, 1, 'reactivation restores cleared navigation');
  h.pagePresent = false; paths.length = 0; h.activeChanged(); commits.flush(); await Promise.resolve();
  assert.equal(paths.length, 0, 'late callbacks do not resurrect disposed pages');
  const root = fs.readFileSync('entry/src/main/ets/components/PinmonySearchRootContent.ets', 'utf8');
  assert(root.includes('active: view.nativeSearchPageVisible()'));
  const appear = source.slice(appearStart, appearEnd);
  assert(appear.includes('this.pagePresent = true;') && appear.includes('this.ensureSearchDestination();'));
  console.log('Search destination lifecycle: reactivation, duplicate suppression, deferred inactive cleanup and disposed callbacks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
