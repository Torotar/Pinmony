const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts);
const { PinmonyDetailSources: Sources } = loader.loadPackage('common_ui');
const { PinmonyDetailSiblingNavigation: Navigation } = loader.loadFile('entry/src/main/ets/app/PinmonyDetailSiblingNavigation.ets');
const { PinmonyNavigationHistory: History } = loader.loadFile('entry/src/main/ets/app/PinmonyNavigationHistory.ets');
const { PinmonyDetailSwipe: Swipe } = loader.loadFile('feature_pin/src/main/ets/services/PinmonyDetailSwipe.ets');
const url = id => `https://www.pinterest.com/pin/${id}/`;
const card = id => ({ pinUrl: url(id), cardId: 'card-' + id, imageUrl: 'image-' + id, imageWidth: 300, imageHeight: 400 });
function fixture(ids = [1, 2, 3], identity = 'home:category-1') {
  let cards = ids.map(card), locateCount = 0;
  const source = { identity, pageUrl: 'https://www.pinterest.com/', session: 5,
    cards: () => cards, locate: () => { locateCount++; } };
  const nav = new Navigation();
  Sources.stage(source); nav.enter(url(ids[0]), 'card-' + ids[0], 7, false);
  return { nav, source, setCards: v => { cards = v; }, located: () => locateCount };
}
function hostMethods(file, names, globals = {}) {
  const source = fs.readFileSync(file, 'utf8').replace(/\bstruct\b/g, 'class');
  const ast = ts.createSourceFile('host.ts', source, ts.ScriptTarget.Latest, true);
  const methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast);
  return vm.runInNewContext(ts.transpileModule('class Host { ' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { ...globals, Date });
}
(async () => {
  const Opening = hostMethods('entry/src/main/ets/pages/Index.ets', ['beginDetailOpening'], { PIN_NATIVE_DETAIL_READS_ENABLED: true });
  const duplicateOpening = new Opening(), duplicateSource = fixture();
  Object.assign(duplicateOpening, { nativeBusinessRoutesEnabled: true,
    pinStore: { detailOpeningPin: url(1) }, detailSiblings: duplicateSource.nav,
    homeEntryCardId: 'card-1', nativeBusinessSessionContext: () => ({ generation: 7 }),
    selectDetailEntryMotion: () => { throw Error('duplicate opening must not reset presentation'); } });
  let duplicateError;
  try { duplicateOpening.beginDetailOpening(url(1)); } catch (error) { duplicateError = error; }
  assert.equal(duplicateSource.nav.next(url(1), 7)?.pinUrl, url(2), 'duplicate document opening preserves sibling source');
  assert.equal(duplicateError, undefined, 'duplicate document opening does not reset presentation');
  const twoWay = fixture();
  assert.equal(twoWay.nav.next(url(1), 7, -1), undefined, 'first source card has no previous sibling');
  assert.equal(twoWay.nav.advance(url(1), 7, 0), undefined, 'invalid direction cannot mutate context');
  twoWay.nav.advance(url(1), 7); twoWay.nav.advance(url(2), 7);
  assert.equal(twoWay.nav.next(url(3), 7), undefined, 'last source card cannot wrap forward');
  assert.equal(twoWay.nav.next(url(3), 7, -1).pinUrl, url(2));
  twoWay.nav.advance(url(3), 7, -1);
  let backwardMeasured = '';
  await twoWay.nav.prepareReturn(url(2), 7, id => { backwardMeasured = id;
    return twoWay.located() ? { x: 0, y: 120, width: 100, height: 100 } : undefined; }, async () => {});
  assert.equal(backwardMeasured, 'card-2', 'backward switch returns to its current card');
  assert.equal(twoWay.located(), 1, 'backward switch locates an offscreen card before measuring return');
  assert.equal(twoWay.nav.next(url(2), 8, -1), undefined, 'previous direction rejects a stale account generation');
  twoWay.nav.advance(url(2), 7, -1);
  assert.equal(twoWay.nav.context(url(1), 7).current.cardId, 'card-1', 'A-B-C-B-A remains in the original source');
  assert.equal(twoWay.nav.advance(url(1), 7, -1), undefined, 'first card cannot wrap backward');
  const repeated = fixture();
  const repeatedCard = { ...card(1), cardId: 'card-1-second' };
  repeated.setCards([card(1), card(2), repeatedCard, card(3)]);
  repeated.nav.advance(url(1), 7);
  repeated.nav.advance(url(2), 7);
  assert.equal(repeated.nav.context(url(1), 7).current.cardId, repeatedCard.cardId);
  assert.equal(repeated.nav.next(url(1), 7).pinUrl, url(3), 'repeated Pin advances from its actual card');
  assert.equal(repeated.nav.next(url(1), 7, -1).pinUrl, url(2), 'previous sibling uses the selected repeated occurrence');
  let returnedCard = '';
  await repeated.nav.prepareReturn(url(1), 7, id => { returnedCard = id; return { x: 0, y: 100, width: 100, height: 100 }; }, async () => {});
  assert.equal(returnedCard, repeatedCard.cardId, 'return measures the selected occurrence');
  repeated.setCards([card(1), card(2), card(3)]);
  assert.equal(repeated.nav.next(url(1), 7), undefined, 'deleted occurrence cannot borrow another card with the same Pin');
  assert.equal(await repeated.nav.prepareReturn(url(1), 7, () => { throw Error('deleted card measured'); }, async () => {}), undefined);
  Sources.stage({ ...repeated.source, cards: () => [card(1), repeatedCard, card(3)] });
  const selectedOccurrence = new Navigation(); selectedOccurrence.enter(url(1), repeatedCard.cardId, 7, false);
  assert.equal(selectedOccurrence.next(url(1), 7).pinUrl, url(3), 'entry binds the clicked card identity');
  const removedDuringLayout = fixture();
  removedDuringLayout.setCards([card(1), card(2), repeatedCard, card(3)]);
  removedDuringLayout.nav.advance(url(1), 7); removedDuringLayout.nav.advance(url(2), 7);
  assert.equal(await removedDuringLayout.nav.prepareReturn(url(1), 7, () => undefined, async () => {
    removedDuringLayout.setCards([card(1), card(2), card(3)]);
  }), undefined, 'layout wait rejects a deleted occurrence even when another copy remains');
  const f = fixture(), h = new History(); h.visit(url(1));
  for (const id of [2, 3]) {
    const current = url(id - 1);
    assert.equal(h.replaceSibling(current, url(id)), true);
    assert.equal(f.nav.advance(current, 7).pinUrl, url(id));
    assert.equal(f.nav.context(url(id), 7).current.cardId, 'card-' + id);
  }
  assert.equal(h.snapshot().length, 2, 'siblings replace one history entry');
  assert.equal(h.prepareBack(), f.source.pageUrl, 'A B C exits directly to source');
  assert.equal(f.nav.next(url(3), 7), undefined, 'end never loops or fetches');
  assert.equal(f.nav.next(url(3), 8), undefined, 'account generation isolated');
  const g = fixture([4, 5], 'search:query');
  assert.equal(g.nav.next(url(1), 7), undefined, 'source lists never mix');
  assert.equal(g.nav.next(url(4), 7).pinUrl, url(5));
  g.setCards([]); assert.equal(g.nav.next(url(4), 7), undefined, 'source replacement disables gesture');
  Sources.stage(f.source); const standalone = new Navigation(); standalone.enter(url(999), '', 7, false);
  assert.equal(standalone.next(url(999), 7), undefined);

  const r = fixture(); r.nav.advance(url(1), 7); r.nav.advance(url(2), 7);
  const rect = { x: 12, y: 120, width: 160, height: 210 };
  assert.equal(await r.nav.prepareReturn(url(3), 7, () => rect, async () => {}), rect);
  assert.equal(r.located(), 0, 'visible card keeps source scroll');
  let frames = 0;
  const measured = await r.nav.prepareReturn(url(3), 7, () => frames < 3 ? undefined : { ...rect, y: frames === 3 ? 140 : 120 }, async () => { frames++; });
  assert.equal(measured.y, 120); assert.ok(frames >= 5, 'recycled card waits for actual stable layout');
  assert.equal(r.located(), 1);
  r.setCards([card(1), card(2)]);
  assert.equal(await r.nav.prepareReturn(url(3), 7, () => rect, async () => {}), undefined, 'deleted card has no fake rectangle');
  const late = fixture(); late.nav.advance(url(1), 7);
  assert.equal(await late.nav.prepareReturn(url(2), 7, () => undefined, async () => late.nav.clear()), undefined, 'destroy/session clear rejects late return');
  const bounded = fixture(); bounded.nav.advance(url(1), 7); let waits = 0;
  assert.equal(await bounded.nav.prepareReturn(url(2), 7, () => undefined, async () => { waits++; }), undefined);
  assert.equal(waits, 24, 'unavailable card exits using bounded page transition');

  const swipe = new Swipe();
  const run = (dx, dy, allowed = true, elapsed = 120) => {
    swipe.start(100, 200, 'pin:1', allowed, 0); swipe.move(100 + dx, 200 + dy, elapsed);
    return swipe.end(100 + dx, 200 + dy, 'pin:1', true, elapsed);
  };
  assert.equal(run(48, 0), true); assert.equal(run(47, 0), false);
  assert.equal(run(60, 40), false); assert.equal(run(61, 40), true);
  assert.equal(run(-80, 0), true); assert.equal(run(80, 100), false);
  assert.equal(run(-48, 0), true); assert.equal(run(-47, 0), false);
  assert.equal(run(-60, 40), false); assert.equal(run(-61, 40), true);
  assert.equal(run(-80, 100), false); assert.equal(run(-80, 0, false), false);
  assert.equal(run(80, 0, false), false);
  assert.equal(run(80, 0, true, 500), true, 'a slow first move is not an arbitrary timeout');
  swipe.start(100, 200, 'pin:1', true, 0); swipe.move(120, 200, 100);
  swipe.move(180, 200, 700);
  assert.equal(swipe.end(180, 200, 'pin:1', true, 800), true, 'slow continuous right drag remains a swipe');
  swipe.start(100, 200, 'pin:1', true, 0); swipe.cancel();
  assert.equal(swipe.end(180, 200, 'pin:1', true, 120), false);
  swipe.start(100, 200, 'pin:1', true, 0);
  assert.equal(swipe.end(180, 200, 'pin:2', true, 120), false);
  assert.equal(swipe.end(180, 200, 'pin:2', true, 130), false, 'one switch per gesture');

  const Detail = hostMethods('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', ['siblingTouch', 'siblingSwipeReady', 'siblingCarouselBoundary', 'siblingPanEnd', 'siblingPanCancel'], {
    TouchType: { Down: 0, Move: 1, Up: 2, Cancel: 3 }, PinmonyI18n: { isRtl: lang => lang === 'ar' },
    PinmonyRuntimeLog: { info: () => {} }
  });
  let opened = 0;
  const detail = new Detail();
  const boundarySignals = [];
  detail.animateSiblingBoundary = step => boundarySignals.push(step);
  detail.siblingBoundaryVersion = 0;
  let liveAllowed = true;
  Object.assign(detail, { siblingMotion: { busy: false, start: step => detail.onSwitchSibling(step) }, siblingSwipe: new Swipe(), siblingSwipeAllowed: () => liveAllowed, pageActive: true, videoActive: true,
    imageLayer: '', viewerMounted: false, searchMounted: false, shuffleOverlayVisible: () => false,
    shuffleFlightActive: false, entryClosing: false, selectedDetailText: false, viewportWidth: 360,
    traceId: 1, carouselBackdropIndex: 0, productGalleryOffset: 0, titleContentInset: () => 80,
    displayedDetail: () => ({ pinUrl: url(1), carousel: { items: [{}, {}] } }),
    uiLanguage: 'zh', onSwitchSibling: () => opened++,
    getUIContext: () => ({ px2vp: n => n, getComponentUtils: () => ({ getRectangleById: id =>
      id.startsWith('pinmony-photo-root') ? { windowOffset: { x: 0, y: 0 } } : { windowOffset: { y: 100 }, size: { height: 300 } } }) }) });
  const rawTouch = (type, x, y, n = 1) => detail.siblingTouch({ type, changedTouches: [{ windowX: x, windowY: y }], touches: Array(n).fill({}) });
  let downX = 0, downY = 0;
  const touch = (type, x, y, n = 1) => {
    if (type === 0) { downX = x; downY = y; }
    rawTouch(type, x, y, n);
    if (type === 2) detail.siblingPanEnd({ offsetX: x - downX, offsetY: y - downY });
  };
  liveAllowed = false;
  assert.equal(detail.siblingSwipeReady(), false, 'opening frame is disabled');
  liveAllowed = true;

  assert.equal(detail.siblingSwipeReady(), true, 'retained page reads current host readiness without a prop refresh');
  touch(0, 100, 50); touch(2, 180, 50); assert.equal(opened, 0, 'title excluded');
  touch(0, 10, 200); touch(2, 100, 200); assert.equal(opened, 0, 'system edge excluded');
  detail.carouselBackdropIndex = 1;
  touch(0, 100, 200); detail.carouselBackdropIndex = 0; touch(2, 180, 200);
  assert.equal(opened, 0, 'carousel consumes its edge-reaching gesture');
  touch(0, 100, 200); touch(2, 180, 200); assert.equal(opened, 1, 'subsequent right swipe switches sibling');
  touch(0, 100, 500); touch(1, 180, 500, 2); touch(2, 180, 500); assert.equal(opened, 1, 'pinch excluded');
  touch(0, 100, 500); touch(3, 180, 500); touch(2, 180, 500); assert.equal(opened, 1);
  detail.uiLanguage = 'ar'; detail.carouselBackdropIndex = 1;
  touch(0, 100, 200); touch(2, 180, 200); assert.equal(opened, 2, 'physical right stays right in Arabic');
  detail.displayedDetail = () => ({ pinUrl: url(1), isVideo: true });
  touch(0, 100, 200); touch(2, 180, 200); assert.equal(opened, 2, 'player excluded');
  touch(0, 100, 500); touch(2, 180, 500); assert.equal(opened, 3, 'video body enabled');
  detail.viewerMounted = true; touch(0, 100, 500); touch(2, 180, 500); assert.equal(opened, 3);
  detail.viewerMounted = false; detail.selectedDetailText = true;
  touch(0, 100, 500); touch(2, 180, 500); assert.equal(opened, 3, 'selection excluded');
  detail.selectedDetailText = false;
  touch(0, 100, 500); touch(1, 180, 500);
  detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 4, 'native horizontal recognizer commits without relying on raw touch Up');
  touch(2, 180, 500); assert.equal(opened, 4, 'raw Up after native End cannot switch twice');
  touch(0, 100, 500); touch(2, 180, 500); detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 5, 'native End after raw Up cannot switch twice');
  touch(0, 10, 500); detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 5, 'native recognizer still excludes system edge');
  touch(0, 100, 50); detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 5, 'native recognizer still excludes header');
  touch(0, 100, 500); touch(1, 120, 560); detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 5, 'native recognizer cannot revive cancelled vertical intent');
  touch(0, 100, 500); touch(1, 120, 500, 2); detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 5, 'native recognizer cannot revive multi-touch');
  detail.uiLanguage = 'zh';
  detail.displayedDetail = () => ({ pinUrl: url(1), carousel: { items: [{}, {}] } });
  detail.carouselBackdropIndex = 1;
  touch(0, 100, 200); detail.carouselBackdropIndex = 0; detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 5, 'native recognizer cannot also switch when carousel reaches its boundary');
  touch(0, 100, 200); detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 6, 'native recognizer switches on the subsequent boundary gesture');

  rawTouch(0, 100, 500); rawTouch(2, 100, 500);
  assert.equal(opened, 6, 'raw Up never consumes the native completion');
  detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 7, 'native displacement survives an earlier raw Up with unchanged coordinates');
  rawTouch(0, 100, 500);
  detail.siblingTouch({ type: 2, changedTouches: [], touches: [] });
  detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 8, 'empty raw Up cannot cancel valid native completion');
  rawTouch(0, 100, 500); detail.siblingPanCancel();
  detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 8, 'native cancellation cannot commit');
  rawTouch(0, 100, 500); liveAllowed = false;
  detail.siblingPanEnd({ offsetX: 80, offsetY: 0 });
  assert.equal(opened, 8, 'live host changes are checked again at completion');
  liveAllowed = true;

  const directions = [];
  detail.onSwitchSibling = step => directions.push(step);
  detail.uiLanguage = 'zh';
  detail.displayedDetail = () => ({ pinUrl: url(1) });
  touch(0, 200, 500); touch(2, 120, 500);
  touch(0, 100, 500); touch(2, 180, 500);
  assert.deepEqual(directions, [1, -1], 'physical left selects next; physical right selects previous');
  touch(0, 200, 50); touch(2, 120, 50);
  touch(0, 350, 500); touch(2, 270, 500);
  touch(0, 200, 500); touch(1, 180, 560); touch(2, 120, 560);
  touch(0, 200, 500); touch(1, 150, 500, 2); touch(2, 120, 500);
  touch(0, 200, 500); touch(3, 120, 500); touch(2, 120, 500);
  assert.equal(directions.length, 2, 'left swipe respects header, system edge, vertical intent, multitouch and cancellation');
  detail.siblingSwipeAllowed = step => liveAllowed && step !== 1;
  touch(0, 200, 500); touch(2, 120, 500);
  assert.equal(directions.length, 2, 'no next card cannot use an available previous card');
  assert.equal(boundarySignals.at(-1), 1, 'end of source gives feedback without navigation');
  detail.siblingSwipeAllowed = () => liveAllowed;
  detail.displayedDetail = () => ({ pinUrl: url(1), carousel: { items: [{}, {}] } });
  detail.carouselBackdropIndex = 0;
  touch(0, 200, 200); detail.carouselBackdropIndex = 1; touch(2, 120, 200);
  assert.equal(directions.length, 2, 'left gesture reaching the last photo cannot also switch Pin');
  touch(0, 200, 200); touch(2, 120, 200);
  assert.equal(directions.at(-1), 1, 'subsequent left gesture at last photo switches next Pin');
  detail.uiLanguage = 'ar'; detail.carouselBackdropIndex = 0;
  const beforeRtl = directions.length;
  touch(0, 200, 200); touch(2, 120, 200);
  assert.equal(directions.length, beforeRtl + 1);
  assert.equal(directions.at(-1), 1, 'Arabic keeps physical left selecting next at its own carousel boundary');
  const beforeFree = directions.length;
  detail.uiLanguage = 'zh';
  detail.displayedDetail = () => ({ pinUrl: url(1), carousel: { freeScroll: true, items: [{}, {}] } });
  detail.productGalleryOffset = 0; detail.productGalleryAtStart = true; detail.productGalleryAtEnd = false;
  touch(0, 200, 200); detail.productGalleryOffset = 100;
  detail.productGalleryAtStart = false; detail.productGalleryAtEnd = true; touch(2, 120, 200);
  assert.equal(directions.length, beforeFree, 'product gallery reaching end consumes the gesture');
  touch(0, 200, 200); touch(2, 120, 200);
  assert.equal(directions.length, beforeFree + 1, 'product gallery end allows a subsequent left swipe');
  touch(0, 100, 200); touch(2, 180, 200);
  assert.equal(directions.length, beforeFree + 1, 'product gallery still consumes the opposite direction away from boundary');
  detail.productGalleryOffset = 0; detail.productGalleryAtStart = true; detail.productGalleryAtEnd = false;
  touch(0, 100, 200); touch(2, 180, 200);
  assert.equal(directions.at(-1), -1, 'product gallery start supports right swipe to previous');
  detail.uiLanguage = 'ar';
  const beforeRtlProduct = directions.length;
  touch(0, 200, 200); touch(2, 120, 200);
  assert.equal(directions.length, beforeRtlProduct + 1);
  assert.equal(directions.at(-1), 1, 'RTL product gallery start belongs to physical left selecting next');
  detail.productGalleryOffset = 100; detail.productGalleryAtStart = false; detail.productGalleryAtEnd = true;
  touch(0, 100, 200); touch(2, 180, 200);
  assert.equal(directions.length, beforeRtlProduct + 2);
  assert.equal(directions.at(-1), -1, 'RTL product gallery end belongs to physical right selecting previous');

  // Execute the real product switch and return methods, including rapid input
  // rejection, cached opening, a failed target, and source-card deletion.
  const Product = hostMethods('entry/src/main/ets/pages/Index.ets',
    ['canSwitchDetailSibling', 'switchDetailSibling', 'prepareSiblingCardReturn']);
  const product = new Product(), journey = fixture(), history = new History(), scheduled = [], cached = [], starts = [];
  history.visit(url(1));
  Object.assign(product, { detailSiblings: journey.nav, pageHistory: history, authStatus: 'authenticated', businessSuspended: false,
    pinStore: { detail: { pinUrl: url(1), kind: 'state' }, detailOpeningToken: 1, detailScrollOffset: 320,
      videoForeground: true, detailOrigin: () => journey.source.pageUrl, detailCache: { put: (...args) => cached.push(args) } },
    nativeBusinessSessionContext: () => ({ generation: 7 }), nativeBusinessRoutesEnabled: true,
    pinIdentity: value => value.match(/\/pin\/(\d+)/)?.[1] || '',
    coordinatorTasks: { timeout: action => scheduled.push(action) }, inboxNewsPinSlide: () => false,
    measureSiblingCard: () => rect,
    beginDetailOpening(pin, origin, returning, collage, sibling) {
      starts.push({ pin, origin, sibling }); this.pinStore.detail = { pinUrl: pin, kind: 'state' }; this.pinStore.detailOpeningToken++;
    } });
  product.switchDetailSibling(); assert.equal(product.pinStore.detail.pinUrl, url(2));
  product.switchDetailSibling(); assert.equal(starts.length, 1, 'rapid repeated gestures cannot skip an in-flight sibling');
  scheduled.shift()(); product.switchDetailSibling();
  assert.equal(product.pinStore.detail.pinUrl, url(3)); assert.equal(product.homeEntryCardId, 'card-3');
  assert.equal(cached.length, 2); assert.equal(starts[1].origin, journey.source.pageUrl); assert.equal(starts[1].sibling, true);
  assert.equal(history.snapshot().join(','), journey.source.pageUrl + ',' + url(3));
  scheduled.shift()();
  assert.equal(product.canSwitchDetailSibling(false, 1), false, 'last source card disables only the forward direction');
  assert.equal(product.canSwitchDetailSibling(), true, 'last source card retains backward swipe');
  product.switchDetailSibling(-1);
  assert.equal(product.pinStore.detail.pinUrl, url(2)); assert.equal(product.homeEntryCardId, 'card-2');
  assert.equal(history.snapshot().join(','), journey.source.pageUrl + ',' + url(2), 'backward switch replaces history instead of stacking');
  scheduled.shift()(); product.switchDetailSibling(1); scheduled.shift()();
  product.pinStore.detailApiError = 'real failed response';
  assert.equal(await product.prepareSiblingCardReturn(url(3)), false);
  assert.equal(product.homeEntryPhoto.pinUrl, url(3)); assert.equal(product.homeEntryPhoto.y, rect.y);
  assert.equal(product.pinStore.detailApiError, 'real failed response', 'return preparation does not clear failure/retry');
  assert.equal(product.homeEntryClosing, true);
  product.homeEntryClosing = false; product.siblingReturnPrepared = ''; journey.setCards([card(1)]);
  await product.prepareSiblingCardReturn(url(3)); assert.equal(product.homeEntryPhoto.returnPageOnly, true);

  // Run source-owned adapters against live list changes instead of asserting
  // only that a callback name appears in the page source.
  for (const kind of ['home', 'search', 'board', 'profile']) {
    const name = kind[0].toUpperCase() + kind.slice(1);
    const file = `feature_${kind}/src/main/ets/components/Pinmony${name}${kind === 'home' ? 'FeedPane' : 'Page'}.ets`;
    const Adapter = hostMethods(file, ['sourceIdentity', 'stageDetailSource', ...(kind === 'board' ? ['sourcePins'] : [])],
      { PinmonyDetailSources: Sources, ScrollAlign: { CENTER: 1 } });
    const adapter = new Adapter(), pins = [1, 2, 3].map(id => ({ ...card(id), id: String(id), targetUrl: url(id), enabled: true }));
    Object.assign(adapter, { sourceLifetime: 1, presentationEpoch: 2, hubTab: 'pins', carouselSources: new Map(),
      home: { pageKey: 'home', session: 5, pins }, snapshot: { pageKey: kind, session: 5, results: pins, pins },
      profile: { profileUrl: 'https://www.pinterest.com/user/', session: 5, section: 'created', createdPins: pins },
      phase: () => '', feedScroller: { scrollToIndex() {} }, resultsScroller: { scrollToIndex() {} } });
    adapter.stageDetailSource(pins[0]);
    const prefix = kind === 'search' ? 'pinmony-search-photo-' + url(1) : `pinmony-${kind}-photo-1`;
    const source = Sources.take(url(1), prefix);
    assert.ok(source, kind + ' exposes the clicked list'); assert.equal(source.cards()[1].pinUrl, url(2));
    adapter.sourceLifetime++; assert.equal(source.cards().length, 0, kind + ' discards destroyed source');
  }
  Sources.stage(f.source); await Promise.resolve();
  assert.equal(Sources.take(url(1), 'card-1'), undefined, 'rejected click source expires before an unrelated route');
  const sheetReturn = fixture(); sheetReturn.source.pageOnly = true; sheetReturn.nav.advance(url(1), 7);
  assert.equal(await sheetReturn.nav.prepareReturn(url(2), 7, () => rect, async () => {}), undefined);
  assert.equal(sheetReturn.located(), 1, 'dismissed result sheets restore their own target without stale flight geometry');

  const SheetAdapter = hostMethods('common_ui/src/main/ets/components/PinmonyImageSearchView.ets',
    ['stageDetailSource', 'sourceIdentity', 'sourceCardId', 'restoreSourceCard'], { PinmonyDetailSources: Sources });
  const sheet = new SheetAdapter(), positions = [];
  Object.assign(sheet, { sourceLifetime: 1, alive: true, pin: '', imageUrl: 'uploaded-photo', uploadedPhoto: true,
    crop: { x: 0, y: 0, w: 1, h: 1 }, presentationActive: false, sheetVisible: false, resultSheetMounted: false,
    result: { items: [card(1), card(2), card(3)].map((item, i) => ({ ...item, id: String(i + 1) })) },
    resultScroller: { currentOffset: () => ({ yOffset: 100 }), scrollTo: options => positions.push(options.yOffset) },
    getUIContext: () => ({ px2vp: n => n, getComponentUtils: () => ({ getRectangleById: id => ({
      windowOffset: { y: id.startsWith('pinmony-image-result-scroll') ? 300 : 600 }, size: { width: 160, height: 500 }
    }) }) }) });
  sheet.stageDetailSource(); const sheetNavigation = new Navigation();
  sheetNavigation.enter(url(1), 'pinmony-photo-result-1', 7, false); sheetNavigation.advance(url(1), 7);
  await sheetNavigation.prepareReturn(url(2), 7, () => rect, async () => {});
  assert.equal(sheet.sourceReturnPin, url(2)); assert.equal(positions.length, 0, 'dismissed Sheet never uses stale node coordinates');
  sheet.presentationActive = true; sheet.sheetVisible = true; sheet.resultSheetMounted = true; sheet.restoreSourceCard();
  assert.equal(positions[0], 384, 'result Sheet restores current card using its real mounted host and card');
  assert.equal(sheet.sourceReturnPin, '');
  const NewsAdapter = hostMethods('feature_inbox/src/main/ets/components/PinmonyInboxNewsPage.ets', ['stageDetailSource'],
    { PinmonyDetailSources: Sources });
  const news = new NewsAdapter(); Object.assign(news, { sourceLifetime: 1,
    snapshot: { pageUrl: 'news', session: 5, newsCards: [1, 2].map(id => ({ id: String(id), target: url(id), image: 'image', imageWidth: 1, imageHeight: 2 })) } });
  news.stageDetailSource(); assert.equal(Sources.take(url(1), 'pinmony-news-photo-1').cards()[1].pinUrl, url(2));

  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const detailSource = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
  assert.match(detailSource, /\.parallelGesture\(PanGesture\(\{ fingers: 1, direction: PanDirection.Horizontal, distance: 48 \}\)/);
  assert.match(detailSource, /\.onActionEnd\(\(event: GestureEvent\) => this\.siblingPanEnd\(event\)\)/);
  assert.match(detailSource, /\.onActionCancel\(\(\) => this\.siblingPanCancel\(\)\)/);
  assert.match(detailSource, /Column\(\) \{ this\.detailContent\(\) \}[\s\S]*?\.onTouch[\s\S]*?\.parallelGesture/,
    'native right pan observes the scroll container from its parent');
  assert.match(index, /siblingSwipeAllowed:.*=>.*canSwitchDetailSibling\(true, step\)/,
    'retained destination queries current product gates at event time');
  assert.match(index, /if \(!sibling\) this\.pageHistory\.visit\(pinUrl, 'push'\)/);
  assert.match(index, /beginDetailOpening\(next\.pinUrl, origin, false, false, true\)/);
  assert.match(index, /onSwitchSibling:.*switchDetailSibling\(step\)/);
  const carouselSource = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
  assert.match(carouselSource, /onProductEdges\?\.\(Math\.abs\(offset\) <= 0\.5, this\.productScroller\.isAtEnd\(\)\)/,
    'product gallery publishes actual native end state instead of guessing its width');
  assert.match(index, /!await this\.prepareSiblingCardReturn/);
  assert.match(index, /this\.detailSiblings\.clear\(\)/);
  for (const feature of ['home', 'search', 'board', 'profile']) {
    const name = feature[0].toUpperCase() + feature.slice(1);
    const file = `feature_${feature}/src/main/ets/components/Pinmony${name}${feature === 'home' ? 'FeedPane' : 'Page'}.ets`;
    const source = fs.readFileSync(file, 'utf8');
    assert.match(source, /this\.stageDetailSource\([^)]*\)/); assert.match(source, /this\.sourceLifetime\+\+/);
  }
  console.log('PASS detail sibling navigation, source isolation, return layout, gesture competition and lifecycle');
})().catch(error => { console.error(error); process.exitCode = 1; });
