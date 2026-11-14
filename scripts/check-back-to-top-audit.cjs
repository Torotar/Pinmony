const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const homeFile = 'feature_home/src/main/ets/components/PinmonyHomePage.ets';
const searchFile = 'feature_search/src/main/ets/components/PinmonySearchPage.ets';
const boardFile = 'feature_board/src/main/ets/components/PinmonyBoardPage.ets';
const detailFile = 'feature_pin/src/main/ets/components/PinmonyDetailPage.ets';
const imageFile = 'common_ui/src/main/ets/components/PinmonyImageSearchView.ets';
function host(file, names, globals = {}) {
  const source = fs.readFileSync(file, 'utf8');
  const methods = names.map(name => {
    const start = source.indexOf('  private ' + name + '('); assert(start >= 0, name);
    return source.slice(start, source.indexOf('\n  }', start) + 4);
  }).join('\n');
  return new (vm.runInNewContext(ts.transpileModule('class Host {' + methods + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { console, PinmonyRuntimeLog: { warn() {}, info() {} }, ...globals }))();
}
function scroller(actual = 0) {
  return { actual, requests: [], currentOffset() { return { yOffset: this.actual }; },
    offset() { return { yOffset: this.actual }; }, scrollTo(options) { this.requests.push(options); } };
}
const home = host(homeFile, ['registerScroller']); const hs = scroller();
Object.assign(home, { presentationEpoch: 3, selectedId: 'all', paneScrollers: new Map(),
  paneKey: id => id, initialOffset: () => 600, scrollerRevision: 0 });
home.registerScroller('all', hs, 3);
assert.equal(home.backToTopVisible, false, 'Home restored offset clamps to top: requested offset must not show button');
hs.actual = 500; home.registerScroller('all', hs, 3); assert.equal(home.backToTopVisible, true);
home.registerScroller('all', undefined, 3); assert.equal(home.backToTopVisible, false);

const queue = [];
const search = host(searchFile, ['restoreResultsScroll'], { setTimeout: fn => queue.push(fn) });
Object.assign(search, { pagePresent: true, scrollRestoreRevision: 0, snapshot: { pageKey: 'page', query: 'cats' },
  initialResultsScrollOffset: 600, resultsScroller: scroller(), updateSearchHeaderSurface() {}, imageBudgetWidthChanged() {} });
search.restoreResultsScroll(); queue.shift()();
assert.equal(search.backToTopVisible, false, 'Search uses actual clamped offset after restoration');
search.resultsScroller.actual = 500; search.restoreResultsScroll(); queue.shift()(); assert.equal(search.backToTopVisible, true);
search.restoreResultsScroll(); search.snapshot.pageKey = 'other'; search.backToTopVisible = false; queue.shift()();
assert.equal(search.backToTopVisible, false, 'Late restoration cannot change a new page');

const detail = host(detailFile, ['restoreScrollPosition'], { setTimeout: fn => queue.push(fn) });
Object.assign(detail, { initialScrollOffset: 600, detailScroller: scroller(), displayedDetail: () => ({ pinUrl: 'pin' }), revealShuffleReturn() {} });
detail.restoreScrollPosition(); queue.shift()(); assert.equal(detail.backToTopVisible, false, 'Detail uses actual clamped offset');
detail.detailScroller.actual = 500; detail.restoreScrollPosition(); queue.shift()(); assert.equal(detail.backToTopVisible, true);

const board = host(boardFile, ['restoreContentScroll'], { setTimeout: fn => queue.push(fn) }); const bs = scroller();
Object.assign(board, { snapshot: {}, scrollScope: () => 'board', visibleScrollScope: '', scrollRestoreToken: 0,
  scrollOffsets: new Map(), initialContentOffset: 600, phase: () => '', contentScroll: () => bs });
board.restoreContentScroll(); queue.shift()(); assert.equal(board.headerScrolled, false, 'Board uses actual clamped offset');

const homeClick = host(homeFile, ['backToTop']); const hc = scroller();
Object.assign(homeClick, { interactionReady: true, presentationActive: false, pagerMoving: false,
  selectedId: 'all', paneKey: id => id, paneScrollers: new Map([['all', hc]]) });
homeClick.backToTop(); assert.equal(hc.requests.length, 0, 'Covered home must reject stale clicks');
homeClick.presentationActive = true; homeClick.backToTop(); assert.equal(hc.requests.length, 1);

const image = host(imageFile, ['canBackToTop', 'backToTop', 'reportResultsPosition']); const is = scroller(500);
Object.assign(image, { alive: true, presentationActive: true, sheetVisible: true, resultScroller: is });
image.reportResultsPosition(); assert.equal(image.backToTopVisible, true); assert.equal(image.resultScrollOffset, 500);
image.sheetAppearing = true; is.actual = 0; image.reportResultsPosition();
assert.equal(image.resultScrollOffset, 500, 'Sheet layout callbacks before restoration must preserve the saved return position');
image.sheetAppearing = false; is.actual = 500;
image.backToTop(); assert.equal(is.requests.length, 1);
for (const key of ['closing', 'relatedOpening', 'sheetAppearing', 'closeRequested']) {
  image[key] = true; image.backToTop(); assert.equal(is.requests.length, 1); image[key] = false;
}
image.presentationActive = false; image.backToTop(); assert.equal(is.requests.length, 1);
image.presentationActive = true; is.actual = 0; image.reportResultsPosition(); assert.equal(image.backToTopVisible, false);
assert.equal(image.resultScrollOffset, 0, 'Reopening image search after returning to top must restore top');
const root = fs.readFileSync('entry/src/main/ets/components/PinmonyHomeRootContent.ets', 'utf8');
assert.match(root, /presentationActive:.*!view\.activeSheetKind.*!view\.pinStore\.detail/);
assert(fs.readFileSync(imageFile, 'utf8').includes('PinmonyBackToTopButton({'));
console.log('Back-to-top audit passed: actual restored offsets, unavailable controller, home coverage and image-search result return lifecycle.');
