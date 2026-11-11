const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
function method(name) {
  const match = source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
  assert(match, name);
  return match[0];
}
let allowed = true;
const methods = ['syncFirstImagePriority', 'settleFirstImage', 'releaseUnobservableImagePriority', 'prefetchNextScreen', 'loadNearEnd',
  'prefetchVisibleDetails', 'uniquePrefetchImages', 'loadNextPageAtEnd'];
const Host = vm.runInNewContext(ts.transpileModule('class Host { ' + methods.map(method).join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { Date, allowsSpeculativeReads: () => allowed });
const pin = { id: 'one', imageUrl: 'https://i.pinimg.com/474x/one.jpg' };
function fixture() {
  const h = new Host(), calls = [];
  Object.assign(h, { paneMounted: true, paneActive: true, feedActive: true, imageLoadingActive: true,
    firstImageSettled: false, firstImageSource: '', visibleFirst: 0, visibleLast: 1,
    home: { pageKey: 'home', session: 1, selectedTab: 'all', pins: [pin], dataSource: 'api' },
    prefetchedImageUrls: [pin.imageUrl, 'detail', 'detail'], recoveredSources: {}, failedImages: [],
    actionsReady: true, paginationReady: true, restoreDone: true, prefetchNotBefore: 0,
    paginationWindow: { reserve: () => 12 }, paginationTrace() {},
    onPrefetchAvailabilityChanged() { calls.push('resume'); }, onPrefetchPins() { calls.push('detail'); },
    onPrefetchMore() { calls.push('prefetch'); }, onLoadMore() { calls.push('demand'); } });
  h.syncFirstImagePriority();
  return { h, calls };
}
const cold = fixture();
cold.h.prefetchVisibleDetails();
assert.equal(cold.h.uniquePrefetchImages().length, 0);
assert.deepEqual(cold.calls, [], 'detail and image prefetch wait for a visible card to settle');
const pendingImages = fixture();
pendingImages.h.prefetchNextScreen(); pendingImages.h.prefetchNextScreen();
pendingImages.h.loadNearEnd(); pendingImages.h.loadNearEnd();
assert.deepEqual(pendingImages.calls, ['prefetch', 'demand'], 'feed pagination proceeds and deduplicates while photos are still pending');
assert.equal(pendingImages.h.firstImageSettled, false, 'pagination does not pretend a photo decoded');
pendingImages.h.prefetchVisibleDetails();
assert.equal(pendingImages.h.uniquePrefetchImages().length, 0, 'pending photos retain priority over image prefetch');
assert.deepEqual(pendingImages.calls, ['prefetch', 'demand'], 'pagination does not release detail prefetch');
cold.h.settleFirstImage({ id: 'old', imageUrl: pin.imageUrl });
assert.equal(cold.h.firstImageSettled, false, 'removed cards cannot release a new feed');
cold.h.settleFirstImage({ ...pin, imageUrl: 'replaced' });
assert.equal(cold.h.firstImageSettled, false, 'old source cannot release its replacement');
cold.h.visibleFirst = 1; cold.h.visibleLast = 1; cold.h.settleFirstImage(pin);
assert.equal(cold.h.firstImageSettled, false, 'a now offscreen completion does not release the visible screen');
cold.h.visibleFirst = 0; cold.h.settleFirstImage(pin); cold.h.settleFirstImage(pin);
assert.deepEqual(cold.calls, ['resume'], 'settlement resumes work once');
cold.h.prefetchNextScreen(); cold.h.prefetchVisibleDetails();
assert(cold.calls.includes('prefetch') && cold.calls.includes('detail'));
assert.deepEqual(Array.from(cold.h.uniquePrefetchImages()), ['detail'], 'retains source deduplication');
cold.h.home.session = 2; cold.h.syncFirstImagePriority();
assert.equal(cold.h.firstImageSettled, true, 'session rebind of retained cards does not await another callback');
cold.h.home = { ...cold.h.home, pins: [{ ...pin, imageUrl: 'new-source' }] };
cold.h.syncFirstImagePriority();
assert.equal(cold.h.firstImageSettled, false, 'new first source gets first-image priority again');
cold.h.firstImageSettled = true; cold.h.home.selectedTab = 'other'; cold.h.syncFirstImagePriority();
assert.equal(cold.h.firstImageSettled, false, 'category switch has an independent gate');
const demand = fixture(); demand.h.loadNextPageAtEnd();
assert.deepEqual(demand.calls, ['demand'], 'explicit end-of-list demand is never held behind images');
for (const flag of ['paneActive', 'feedActive', 'imageLoadingActive']) {
  const paused = fixture(); paused.h.firstImageSettled = true; paused.h[flag] = false;
  assert.equal(paused.h.uniquePrefetchImages().length, 0, flag + ' pauses hidden detail image admission');
}
for (const flag of ['loading', 'refreshing', 'pendingTabId']) {
  const refreshing = fixture(); refreshing.h.firstImageSettled = true; refreshing.h[flag] = flag === 'pendingTabId' ? 'tab:other' : true;
  assert.equal(refreshing.h.uniquePrefetchImages().length, 0, flag + ' defers speculative native image prefetch');
}
const snapshotRefreshing = fixture(); snapshotRefreshing.h.firstImageSettled = true; snapshotRefreshing.h.home.refreshing = true;
assert.equal(snapshotRefreshing.h.uniquePrefetchImages().length, 0, 'snapshot refresh also stops speculative image admission');
const disposed = fixture(); disposed.h.paneMounted = false; disposed.h.settleFirstImage(pin);
assert.deepEqual(disposed.calls, [], 'disposed callbacks cannot resume work');
const video = fixture(); video.h.home.pins = [{ ...pin, video: {} }];
video.h.releaseUnobservableImagePriority();
assert.equal(video.h.firstImageSettled, true, 'video-only viewport does not wait for a photo callback');
const failed = fixture(); failed.h.failedImages = [pin.imageUrl]; failed.h.releaseUnobservableImagePriority();
assert.equal(failed.h.firstImageSettled, true, 'retained failure cards do not block prefetch');
const mixed = fixture(); mixed.h.home.pins = [{ ...pin, video: {} }, { ...pin, id: 'photo' }];
mixed.h.releaseUnobservableImagePriority();
assert.equal(mixed.h.firstImageSettled, false, 'mixed viewport still gives its photo priority');
const empty = fixture(); empty.h.home.pins = []; empty.h.releaseUnobservableImagePriority();
assert.equal(empty.h.firstImageSettled, false, 'empty feed cannot dispatch speculative work');
const hidden = fixture(); hidden.h.home.pins = [{ ...pin, video: {} }]; hidden.h.paneActive = false;
hidden.h.releaseUnobservableImagePriority(); assert.deepEqual(hidden.calls, [], 'hidden video viewport cannot resume work');
allowed = false;
const disabled = fixture(); disabled.h.firstImageSettled = true;
disabled.h.prefetchNextScreen(); disabled.h.prefetchVisibleDetails();
assert.deepEqual(disabled.calls, [], 'existing speculative-read switch remains authoritative');
assert.match(source, /useSharedDecode: false, viewportOnly: true/, 'cards keep native decoding with viewport admission');
for (const event of ['onDecoded', 'onFailure']) {
  const callback = source.slice(source.indexOf(event + ': () =>') >= 0 ? source.indexOf(event + ': () =>') : source.indexOf(event + ': (code: number) =>'));
  assert(callback.indexOf('session !== this.home.session') < callback.indexOf('this.settleFirstImage(pin)'), 'session guard precedes ' + event);
  assert(callback.indexOf('imageRevision !==') < callback.indexOf('this.settleFirstImage(pin)'), 'source revision guard precedes ' + event);
}
console.log('Home first-image priority: parallel feed pagination, viewport admission, detail/image prefetch gating, success/failure wiring, source/category reset, retained session, hidden and disposed states passed');
