const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const homePath = 'feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets';
const searchPath = 'feature_search/src/main/ets/components/PinmonySearchPage.ets';
const home = fs.readFileSync(homePath, 'utf8'), search = fs.readFileSync(searchPath, 'utf8');
function method(source, name) {
  const start = source.indexOf('  private ' + name + '(') >= 0 ? source.indexOf('  private ' + name + '(') : source.indexOf('  ' + name + '(');
  assert(start >= 0, name);
  const rest = source.slice(start), end = rest.slice(1).search(/\n  (?:private |@Builder|@State|@Prop)/);
  assert(end >= 0, 'method boundary: ' + name);
  return rest.slice(0, end + 1);
}
function host(source, names, globals = {}) {
  return vm.runInNewContext(ts.transpileModule('class Host {' + names.map(n => method(source, n)).join('\n') + '} Host;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, globals);
}
const Home = host(home, ['contentColumns', 'cachedImageCount', 'detailImagePrefetchCount', 'imageBudgetWidthChanged']);
const Search = host(search, ['contentColumns', 'cachedImageCount', 'imagePrefetchCount', 'imageBudgetWidthChanged', 'updateResultImagePrefetch', 'syncImagePrefetchActivity', 'aboutToDisappear', 'restoreResultsScroll'], { setTimeout: fn => restoreTimers.push(fn) });
const restoreTimers = [];
for (const Type of [Home, Search]) {
  const h = new Type();
  for (const [width, columns] of [[360, 2], [600, 3], [840, 4], [1200, 6], [1600, 8], [9900, 51], [360, 2]]) {
    h.contentWidth = width;
    assert.equal(h.contentColumns(), columns);
    assert.equal(h.cachedImageCount(), Math.min(48, columns * 6));
    if (h.detailImagePrefetchCount) assert.equal(h.detailImagePrefetchCount(), Math.min(18, columns * 3));
    else assert.equal(h.imagePrefetchCount(), Math.min(24, columns * 4));
  }
}
let homeRefreshes = 0;
const h = new Home(); h.prefetchVisibleDetails = () => homeRefreshes++; h.imageBudgetWidthChanged();
assert.equal(homeRefreshes, 1, 'home resize reuses the current gated visible-detail callback');
assert.equal((home.match(/\.cachedCount\(this.cachedImageCount\(\), true\)/g) || []).length, 1);
assert.equal((search.match(/\.cachedCount\(this.cachedImageCount\(\), true\)/g) || []).length, 2, 'both search grid variants adapt');
assert(home.includes("@State @Watch('imageBudgetWidthChanged') private contentWidth"));
assert(search.includes("@State @Watch('imageBudgetWidthChanged') private contentWidth"));
const leases = [], exportsSearch = {};
const prefetchSource = fs.readFileSync('feature_search/src/main/ets/services/PinmonySearchImagePrefetch.ets', 'utf8');
vm.runInNewContext(ts.transpileModule(prefetchSource, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText,
  { exports: exportsSearch, require: () => ({ acceptsSoftwareJpeg: u => u.endsWith('.jpg'), PinmonyJpegDecode: { acquire(url, active, priority) {
    const lease = { url, active, priority, releases: 0, ready: Promise.resolve(),
      release() { this.releases++; }, setActive(v) { this.active = v; } };
    leases.push(lease); return lease;
  } } }) });
const p = new exportsSearch.PinmonySearchImagePrefetch(), s = new Search();
Object.assign(s, { contentWidth: 360, imagePrefetchFirst: -1, imagePrefetchLast: -1, upcomingImageUrls: [],
  pagePresent: true,
  automaticLoadingEnabled: true, committedQuery: () => true, actionsReady: true, restoringResultsScroll: false,
  entryQuiz: false, imagePrefetch: p, snapshot: { results: Array.from({ length: 80 }, (_, i) => ({ imageUrl: i + '.jpg' })) } });
s.imageBudgetWidthChanged(); assert.equal(leases.length, 0, 'resize before any visible range admits nothing');
s.updateResultImagePrefetch(0, 5); assert.equal(p.leases.size, 8);
assert(leases.every(l => !l.active && l.priority === 0), 'hidden page leases remain inactive and low priority');
p.setActive(true); s.contentWidth = 840; s.imageBudgetWidthChanged();
assert.equal(p.leases.size, 16); assert.equal(leases.length, 16, 'growth preserves overlapping URL leases');
s.contentWidth = 1200; s.imageBudgetWidthChanged(); assert.equal(p.leases.size, 24);
s.contentWidth = 360; s.imageBudgetWidthChanged(); assert.equal(p.leases.size, 8);
assert(leases.slice(8).every(l => l.releases === 1), 'shrink releases every excess lease once');
assert(leases.slice(0, 8).every(l => l.releases === 0 && l.active), 'shrink retains phone budget and decoded ownership');
p.setActive(false); s.contentWidth = 840; s.imageBudgetWidthChanged();
assert(Array.from(p.leases.values()).every(l => !l.active), 'background resize cannot activate download leases');
for (const gate of ['automaticLoadingEnabled', 'actionsReady']) {
  s[gate] = false; const before = leases.length; s.contentWidth = 1200; s.imageBudgetWidthChanged();
  assert.equal(leases.length, before, gate + ' guards resize admission'); s[gate] = true;
}
s.restoringResultsScroll = true; s.contentWidth = 10000; s.imageBudgetWidthChanged(); assert.equal(p.leases.size, 16);
s.restoringResultsScroll = false; s.entryQuiz = true; s.updateResultImagePrefetch(1, 6);
assert.equal(Array.from(p.leases.keys())[0], '6.jpg', 'quiz row offsets still identify the next photo');
p.clear(); p.update(s.snapshot.results.map(r => r.imageUrl), 999); assert.equal(p.leases.size, 24);
for (const invalid of [NaN, Infinity, -1]) { p.update(s.snapshot.results.map(r => r.imageUrl), invalid); assert.equal(p.leases.size, 8); }
p.clear();
assert((search.match(/this.imagePrefetchFirst = -1;/g) || []).length >= 2, 'dispose and page/session reset forget the old range');
const detailSource = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets', 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
const ctx = { Date, PinmonyRuntimeLog: { info() {} } };
require('./product-coordination-harness.cjs').run(ts, ts.transpile(detailSource + '\nglobalThis.Prefetch = PinmonyDetailPrefetch;', { target: ts.ScriptTarget.ES2020 }), ctx);
const urls = Array.from({ length: 40 }, (_, i) => 'https://www.pinterest.com/pin/' + (i + 1) + '/');
for (const [limit, count] of [[undefined, 6], [12, 12], [18, 18], [999, 18], [NaN, 6]]) {
  const d = new ctx.Prefetch(), reads = [], cancelled = [];
  d.offer(urls, 'scope', (url, id) => new Promise(() => reads.push(id)), () => true, id => cancelled.push(id), limit);
  assert.equal(reads.length, 2, 'wide budget preserves two concurrent detail reads');
  assert.equal(d.queued.length, count - 2, 'budget reaches the actual waiting queue');
  d.offer(urls, 'scope', () => new Promise(() => {}), () => true, id => cancelled.push(id), 6);
  assert.equal(d.queued.length, 4, 'shrink replaces waiting detail work while existing reads finish');
  d.pause(); assert.equal(d.queued.length, 0); assert.equal(cancelled.length, 2);
}
const coordinator = fs.readFileSync('entry/src/main/ets/app/PinmonyDetailOpeningCoordinator.ets', 'utf8');
assert(coordinator.includes('this.prefetchHomePinDetailsNow(this.homeImagePrefetchFirst, this.homeImagePrefetchLast, this.homeImagePrefetchLimit)'));
assert(coordinator.includes('first + count, last + 1'), 'detail preparation stays bounded to visible Pins');
assert(coordinator.includes('this.ports.detailReadNetwork().cancel(id), count)'), 'coordinator passes the selected budget to the queue');
for (const [file, expected] of [
  ['feature_home/src/main/ets/components/PinmonyHomePage.ets', 'limit?: number'],
  ['entry/src/main/ets/components/PinmonyHomeRootContent.ets', 'first, last, limit'],
  ['entry/src/main/ets/pages/Index.ets', 'first, last, limit']]) {
  assert(fs.readFileSync(file, 'utf8').includes(expected), 'budget forwarded through ' + file);
}
// Exercise resume in the same owner rather than manually updating the service.
s.entryQuiz = false; s.contentWidth = 1200; s.active = true; s.mediaActive = true;
s.upcomingImageUrls = []; s.updateResultImagePrefetch(0, 5); s.syncImagePrefetchActivity();
assert.equal(p.leases.size, 24);
s.automaticLoadingEnabled = false; s.syncImagePrefetchActivity();
s.contentWidth = 360; s.imageBudgetWidthChanged(); assert.equal(p.leases.size, 24, 'disabled admission defers reconciliation');
const excess = Array.from(p.leases.values()).slice(8), activationCounts = excess.map(l => l.active);
assert(activationCounts.every(v => !v));
const activationLog = [];
for (const lease of excess) lease.setActive = value => { activationLog.push(value); lease.active = value; };
s.automaticLoadingEnabled = true; s.syncImagePrefetchActivity();
assert.equal(p.leases.size, 8, 'resume trims to the current narrow window without a scroll event');
assert.equal(activationLog.length, 0, 'excess leases are released before any reactivation');
assert(excess.every(l => l.releases === 1));
// A width change blocked by scroll restoration must reconcile when it finishes.
s.snapshot.pageKey = 'current-search'; s.snapshot.query = 'fixture'; s.scrollRestoreRevision = 0; s.initialResultsScrollOffset = 240;
s.resultsScroller = { scrollTo() {} }; s.updateSearchHeaderSurface = () => {};
s.restoreResultsScroll(); s.contentWidth = 840; s.imageBudgetWidthChanged();
assert.equal(p.leases.size, 8); restoreTimers.shift()(); assert.equal(p.leases.size, 16);
s.contentWidth = 1200; s.imageBudgetWidthChanged(); assert.equal(p.leases.size, 24);
s.automaticLoadingEnabled = false; s.syncImagePrefetchActivity(); s.restoreResultsScroll();
s.contentWidth = 360; s.imageBudgetWidthChanged(); s.automaticLoadingEnabled = true; s.syncImagePrefetchActivity();
assert.equal(p.leases.size, 8, 'resume also trims excess while range selection awaits scroll restoration');
restoreTimers.shift()(); assert.equal(p.leases.size, 8);
s.contentWidth = 840; s.imageBudgetWidthChanged();
// Reappearing with identical upcoming URLs must reacquire cleared leases.
Object.assign(s, { uiCommits: { dispose() {} }, closePhotoSearch() {}, searchPathStack: { clear() {} } });
s.aboutToDisappear(); assert.equal(p.leases.size, 0); assert.equal(s.upcomingImageUrls.length, 0);
s.updateResultImagePrefetch(0, 5); assert.equal(s.imagePrefetchFirst, -1, 'late disposed range cannot revive an owner');
s.pagePresent = true; s.updateResultImagePrefetch(0, 5); assert.equal(p.leases.size, 16);
const remembered = s.imagePrefetchFirst;
s.updateResultImagePrefetch(-1, -1); s.updateResultImagePrefetch(8, 4);
assert.equal(s.imagePrefetchFirst, remembered, 'invalid layout ranges cannot replace a valid prefetch window');
p.clear();
// Execute the actual delayed coordinator method: only the latest viewport is offered.
const start = coordinator.indexOf('prefetchHomePinDetails(first:');
const delayed = coordinator.slice(start, coordinator.indexOf('\nprefetchHomePinDetailsNow(', start));
const callbacks = [], dispatched = [];
const Coordinator = vm.runInNewContext(ts.transpileModule('class Host {' + delayed + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, { allowsSpeculativeReads: () => true });
const c = new Coordinator(); let timer = -1;
Object.assign(c, { pinStore: {}, ports: { detailPrefetchTimer: () => timer, setDetailPrefetchTimer: n => timer = n,
  pageTasks: () => ({ timeout(fn) { callbacks.push(fn); return callbacks.length; } }) },
  prefetchHomePinDetailsNow: (...args) => dispatched.push(args) });
c.prefetchHomePinDetails(0, 17, 18); c.prefetchHomePinDetails(20, 25, 6);
assert.equal(callbacks.length, 1, 'resize and scroll coalesce behind the existing delay'); callbacks.shift()();
assert.deepEqual(dispatched, [[20, 25, 6]], 'timer uses the latest range and latest budget together');
c.prefetchHomePinDetails(-1, -1, 18); assert.equal(callbacks.length, 0);
console.log('Adaptive image budgets: column caps, shrink/grow, real pause/resume ordering, restoration, remount, disposed/invalid callbacks, latest delayed viewport, queue concurrency and callback chain passed');
