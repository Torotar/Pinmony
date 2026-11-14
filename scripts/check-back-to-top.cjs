const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const paths = {
  home: 'feature_home/src/main/ets/components/PinmonyHomePage.ets',
  search: 'feature_search/src/main/ets/components/PinmonySearchPage.ets',
  board: 'feature_board/src/main/ets/components/PinmonyBoardPage.ets',
  detail: 'feature_pin/src/main/ets/components/PinmonyDetailPage.ets'
};
function host(kind, names) {
  const source = fs.readFileSync(paths[kind], 'utf8');
  const methods = names.map(name => {
    const start = source.indexOf('  private ' + name + '(');
    assert(start >= 0, `${kind}.${name} exists`);
    return source.slice(start, source.indexOf('\n  }', start) + 4);
  }).join('\n');
  return new (vm.runInNewContext(ts.transpileModule('class Host {' + methods + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { PinmonyRuntimeLog: { warn() {} }, console }))();
}
function scroller() {
  return { y: 600, calls: [], scrollTo(options) { this.calls.push(options); this.y = options.yOffset; },
    offset() { return { yOffset: this.y }; } };
}
function topOnly(s, count = 1) {
  assert.equal(s.calls.length, count);
  for (const call of s.calls) assert.deepEqual(JSON.parse(JSON.stringify(call)), { xOffset: 0, yOffset: 0, animation: true });
}
const home = host('home', ['backToTop', 'rememberPosition']);
const first = scroller(), second = scroller();
Object.assign(home, { interactionReady: true, pagerMoving: false, selectedId: 'one', home: { pageKey: 'home' },
  presentationEpoch: 2, paneOffsets: new Map(), paneScrollers: new Map([['home|one', first], ['home|two', second]]),
  paneKey: id => 'home|' + id });
home.backToTop(); topOnly(first); topOnly(second, 0);
home.selectedId = 'two'; home.backToTop(); topOnly(second);
home.pagerMoving = true; home.backToTop(); topOnly(second);
home.pagerMoving = false; home.interactionReady = false; home.backToTop(); topOnly(second);
home.offlinePreview = true; home.backToTop(); topOnly(second, 2);
home.rememberPosition('two', 'home', 240, 2); assert.equal(home.backToTopVisible, true);
for (const [id, page, epoch] of [['one', 'home', 2], ['two', 'old', 2], ['two', 'home', 1]]) {
  home.rememberPosition(id, page, 0, epoch); assert.equal(home.backToTopVisible, true);
}
home.rememberPosition('two', 'home', 0, 2); assert.equal(home.backToTopVisible, false);

const search = host('search', ['canBackToTop', 'backToTop', 'reportResultsScroll']);
const discovery = scroller(), results = scroller(); let query = '';
Object.assign(search, { pagePresent: true, active: true, activePage: 'page', snapshot: { pageKey: 'page', query: '' },
  discoveryScroller: discovery, resultsScroller: results, committedQuery: () => query,
  showingSearchHistory: () => false, updateSearchHeaderSurface() {} });
search.backToTop('search-root'); topOnly(discovery); topOnly(results, 0);
query = 'cats'; search.snapshot.query = query; search.historyDestinationRetained = true;
search.backToTop('search-root'); topOnly(results, 0);
search.backToTop('search-history'); topOnly(results);
for (const key of ['inputEditing', 'restoringResultsScroll', 'historyDestinationClosing', 'photoHistoryVisible', 'photoPreview', 'quizSheetOpen']) {
  search[key] = true; search.backToTop('search-history'); topOnly(results); search[key] = false;
}
search.active = false; search.backToTop('search-history'); topOnly(results); search.active = true;
search.showingSearchHistory = () => true; search.backToTop('search-history'); topOnly(results);
search.showingSearchHistory = () => false;
search.activePage = 'old'; search.backToTop('search-history'); topOnly(results); search.activePage = 'page';
search.activeSession = 'old'; search.backToTop('search-history'); topOnly(results); search.activeSession = undefined;
results.y = 500; search.reportResultsScroll(); assert.equal(search.backToTopVisible, true);
results.y = 0; search.reportResultsScroll(); assert.equal(search.backToTopVisible, false);

const board = host('board', ['canBackToTop', 'backToTop']);
const parent = scroller(), section = scroller(); let phase = '';
Object.assign(board, { headerScrolled: true, snapshot: {}, phase: () => phase,
  contentScroll: () => phase === 'section' ? section : parent });
board.backToTop(); topOnly(parent); phase = 'section'; board.backToTop(); topOnly(section);
for (const blocked of ['edit', 'targets', 'organize', 'archive']) {
  phase = blocked; assert.equal(board.canBackToTop(), false); board.backToTop(); topOnly(parent);
}
phase = 'ideas'; assert.equal(board.canBackToTop(), true);
board.snapshot.flow = { cover: {} }; assert.equal(board.canBackToTop(), false); board.snapshot.flow = undefined;
board.restoringScroll = true; assert.equal(board.canBackToTop(), false);

const detail = host('detail', ['canBackToTop', 'backToTop', 'reportScrollPosition']);
const detailScroll = scroller(), offsets = [];
Object.assign(detail, { pageActive: true, entryMotionComplete: false, detailScroller: detailScroll, displayedDetail: () => ({ pinUrl: 'pin' }),
  shuffleOverlayVisible: () => false, onScrollPosition: (...args) => offsets.push(args) });
assert.equal(detail.canBackToTop(), true, 'Direct detail without an entry photo remains supported');
detail.backToTop(); topOnly(detailScroll);
for (const key of ['restoringScroll', 'searchMounted', 'viewerMounted', 'entryClosing', 'shuffleFlightPreparing']) {
  detail[key] = true; detail.backToTop(); topOnly(detailScroll); detail[key] = false;
}
detail.imageLayer = 'search'; detail.backToTop(); topOnly(detailScroll); detail.imageLayer = '';
detail.pageActive = false; detail.backToTop(); topOnly(detailScroll); detail.pageActive = true;
detail.entryPhoto = {}; assert.equal(detail.canBackToTop(), false);
detail.entryMotionComplete = true; assert.equal(detail.canBackToTop(), true);
detailScroll.y = 500; detail.reportScrollPosition(); assert.equal(detail.backToTopVisible, true);
detailScroll.y = 0; detail.reportScrollPosition(true); assert.equal(detail.backToTopVisible, false);
assert.deepEqual(offsets.at(-1), ['pin', 0], 'Existing return-position persistence receives the actual top position');

const component = fs.readFileSync('common_ui/src/main/ets/components/PinmonyBackToTopButton.ets', 'utf8');
assert(component.includes("@StorageLink('pinmonyLanguage')"));
assert(component.includes("PinmonyI18n.text('pm_back_to_top', this.uiLanguage)"));
assert(component.includes('.enabled(this.showButton)'));
assert(component.includes('Visibility.Hidden'));
for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR', 'ar']) {
  const rows = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
  const labels = rows.filter(row => row.name === 'pm_back_to_top');
  assert.equal(labels.length, 1, locale); assert(labels[0].value.trim(), locale);
}
for (const [kind, file] of Object.entries(paths)) {
  const source = fs.readFileSync(file, 'utf8');
  assert(source.includes('PinmonyBackToTopButton({'), file);
  if (kind !== 'home') assert.match(source, /@State private restoring(?:Results)?Scroll: boolean/,
    'Restoration completion must refresh button availability without requiring another scroll');
}
console.log('Back to top passed: current panes, offline display, history/overlay gates, restoration, scroll persistence and ten locales.');
