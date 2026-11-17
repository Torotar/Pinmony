const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const cdnImageSource = fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets', 'utf8');
assert.match(cdnImageSource, /@Prop allowImageDrag: boolean = true;/, 'other image callers retain their existing default');
assert.match(cdnImageSource, /Image\(this\.bitmap \|\| this\.url\)[\s\S]*?\.draggable\(this\.allowImageDrag\)/, 'native image disables drag for bitmap and URL rendering');
for (const [file, imageCall] of [
  ['common_ui/src/main/ets/components/PinmonyCardCarousel.ets', /PinmonyCdnImage\(\{ url: photo\.url,[\s\S]*?allowImageDrag: false/],
  ['feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', /PinmonyCdnImage\(\{ url: this\.recoveredSources\[pin\.imageUrl\][\s\S]*?allowImageDrag: false/]
]) assert.match(fs.readFileSync(file, 'utf8'), imageCall, 'single and multi-photo cards disable system pickup');
const loader = require('./arkts-module-loader.cjs').createArktsLoader(ts, {
  common_network: { PIN_BUSINESS_PIN_READ_ENABLED: true },
  common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }
});
const { pinmonyCardCarouselImages: parse, normalizeCardCarouselImages: normalize } = loader.loadFile('common_ui/src/main/ets/models/PinmonyCardCarousel.ets');
const { PinmonyHomeNativeReads } = loader.loadFile('entry/src/main/ets/app/PinmonyHomeNativeReads.ets');
const native = Object.create(PinmonyHomeNativeReads.prototype);
native.origin = 'https://www.pinterest.com'; native.ports = { saved: () => false };
const image = n => ({ url: 'https://i.pinimg.com/474x/test' + n + '.jpg', width: 474, height: 700 });
const raw = { carousel_slots: [0, 1, 2].map(n => ({ id: String(n), images: { '474x': image(n) } })) };
const plain = value => JSON.parse(JSON.stringify(value));
assert.deepEqual(plain(parse(raw)).map(p => p.url), [0, 1, 2].map(n => image(n).url));
const script = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets').PIN_HOME_API_SCRIPT;
const start = script.indexOf('  function cardCarouselImages(');
const end = script.indexOf('  function mapPins(', start);
const webParse = vm.runInNewContext(script.slice(start, end) + '\ncardCarouselImages;', { URL });
for (const value of [undefined, null, {}, { carousel_slots: [] }, { carousel_slots: [raw.carousel_slots[0]] }, raw,
  { carousel_slots: [null, raw.carousel_slots[1]] },
  { carousel_slots: [{ images: { '474x': { ...image(1), url: 'https://evil.test/image.jpg' } } }, raw.carousel_slots[1]] },
  { carousel_slots: [{ images: { '474x': { ...image(1), width: 0 } } }, raw.carousel_slots[1]] },
  { carousel_slots: Array.from({ length: 101 }, () => raw.carousel_slots[0]) }]) {
  assert.deepEqual(plain(parse(value)), plain(webParse(value)), 'native and Web mapping agree');
}
const pins = native.mapPins([{ id: '101', type: 'pin', images: { '474x': image(0) }, carousel_data: raw }]);
assert.equal(pins[0].carouselImages.length, 3);
assert.equal(pins[0].mediaCount, 3);
assert.deepEqual(plain(normalize(pins[0].carouselImages)), plain(parse(raw)));
assert.equal(normalize([{ ...plain(parse(raw))[0], url: 'http://i.pinimg.com/test.jpg' }, plain(parse(raw))[1]]).length, 0);
const { normalizeHomeCacheRecord } = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeCache.ets');
const cached = normalizeHomeCacheRecord({ snapshot: { kind: 'state', dataSource: 'api', pageKey: native.origin + '/',
  selectedTab: 'all', tabs: [{ id: 'all', label: 'all', selected: true, enabled: true }], pins } }, native.origin + '/');
assert.deepEqual(plain(cached.snapshot.pins[0].carouselImages), plain(pins[0].carouselImages));
const { retainHomePins } = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeRetention.ets');
assert.equal(retainHomePins(pins, [{ ...pins[0], title: 'updated' }], false)[0].carouselImages, pins[0].carouselImages);
const page = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
const card = page.slice(page.indexOf('  private pinCard('), page.indexOf('  private uniquePrefetchImages('));
assert(card.indexOf('PinmonyCardCarousel({') < card.indexOf('Row({ space: 4 })'), 'dots precede title and options, including empty titles');
assert.match(card, /interactionActive: this.interactionReady/);
assert.match(card, /this\.onPin\(pin.id, url\)/, 'tap opens the currently displayed image');
const component = fs.readFileSync('common_ui/src/main/ets/components/PinmonyCardCarousel.ets', 'utf8');
assert.match(component, /\.loop\(false\)\.autoPlay\(false\)/);
assert.match(component, /IndicatorComponent\(this.indicatorController\)[\s\S]*?\.height\(38\)/, 'native dots reserve space below the photo');
assert.match(component, /\.indicator\(this.indicatorController\)/, 'native indicator shares the Swiper controller and transition');
assert.match(component, /\}\s*\.width\('100%'\)\.height\(this.photoHeight\)\.borderRadius\(18\)\.clip\(true\)\s*\/\/ Keep the native/, 'stationary viewport clips every animation frame before the separate indicator');
assert.match(component, /\.cachedCount\(1\)/, 'cache only the immediate neighboring slides');
assert.match(component, /\.id\(index === this.selectedIndex \? this.photoId :/, 'detail source geometry follows only the active photo, excluding dots');
assert.doesNotMatch(component, /Row\(\{ space: 5 \}\)|\.indicator\(false\)/, 'no manually switched dots');
assert.match(component, /\.maxDisplayCount\(7\)/, 'large galleries keep a bounded animated dot strip');
assert.match(component, /\.nestedScroll\(SwiperNestedScrollMode.SELF_ONLY\)/, 'inner image swipe owns horizontal gesture');
const search = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
for (const token of ['Indicator.dot().bottom(4)', '.itemWidth(7).itemHeight(7).selectedItemWidth(9).selectedItemHeight(9)',
  ".color($r('app.color.secondary_text')).selectedColor($r('app.color.primary_text'))"]) {
  assert(component.includes(token) && search.includes(token), 'same native animated indicator configuration as search: ' + token);
}
assert.match(component, /PinmonyCdnImage/);
assert.match(component, /loadingActive: this.canLoadPhoto\(index\), viewportOnly: false/);
assert.match(component, /loadPriority: index === this.selectedIndex \? 1 : 0/, 'neighbor preloads are lower priority than visible content');
assert.match(component, /this.cardInViewport = visible && ratio > 0/);
const loadMethod = component.match(/private canLoadPhoto\(index: number\): boolean \{([\s\S]*?)\n  \}/);
assert(loadMethod);
const canLoad = vm.runInNewContext(ts.transpileModule('(function(index: number) {' + loadMethod[1] + '})', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const loadingHost = { loadingActive: true, cardInViewport: true, selectedIndex: 1, images: parse(raw), decodedUrls: [] };
assert.equal(canLoad.call(loadingHost, 1), true, 'current photo starts before neighbors');
assert.equal(canLoad.call(loadingHost, 0), false, 'neighbors wait for current photo decode');
loadingHost.decodedUrls = [image(1).url];
assert.equal(canLoad.call(loadingHost, 0), true);
assert.equal(canLoad.call(loadingHost, 2), true, 'both adjacent photos preload without waiting to become visible');
loadingHost.selectedIndex = 0;
assert.equal(canLoad.call(loadingHost, 2), false, 'distant photos remain paused');
loadingHost.cardInViewport = false;
assert.equal(canLoad.call(loadingHost, 0), false, 'offscreen cards pause');
loadingHost.cardInViewport = true; loadingHost.loadingActive = false;
assert.equal(canLoad.call(loadingHost, 0), false, 'covered/background pages pause');
loadingHost.loadingActive = true;
assert.equal(canLoad.call(loadingHost, 0), true, 'return resumes current photo');
assert.doesNotMatch(component, /\.overlay\(/, 'saved mask must be a non-intercepting Stack child, not an overlay host');
assert.match(component, /this\.savedMask\(\)\s*\}\s*\.width/);
assert.match(component, /hitTestBehavior\(HitTestMode.None\)/, 'saved mask never receives touches');
assert.doesNotMatch(component, /swiping|onGestureSwipe|onAnimationStart|onAnimationEnd/, 'tap availability cannot depend on unmatched animation callbacks');
assert.match(component, /parallelGesture\(TapGesture\(\{ count: 1, distanceThreshold: 8 \}\)/, 'photo host recognizes taps alongside native swiper, rejecting drags');
const photoClick = component.match(/\.onAction\(\(\) => \{([\s\S]*?)\n            \}\)/);
assert(photoClick, 'every photo host uses the same detail-entry callback');
const opened = [];
for (const [index, photo] of parse(raw).entries()) {
  const click = vm.runInNewContext('(function() {' + photoClick[1] + '})', { photo, index });
  const host = { interactionActive: true, selectedIndex: index, failedUrls: [], onOpen: url => opened.push(url) };
  click.call(host);
  host.selectedIndex = -1; click.call(host);
  host.selectedIndex = index; host.failedUrls = [photo.url]; click.call(host);
  host.failedUrls = []; host.interactionActive = false; click.call(host);
}
assert.deepEqual(opened, [0, 1, 2].map(n => image(n).url), 'all active photos open detail; inactive slides, failed images and hidden pages do not');
const retry = component.slice(component.indexOf('Button(this.retryText)'), component.indexOf('} else {', component.indexOf('Button(this.retryText)')));
assert.doesNotMatch(retry, /onOpen/, 'retry never opens detail');
assert.match(component, /failedUrls.*filter/, 'explicit retry remounts only a failed photo');
assert.match(card, /if \(!pin.video &&/, 'playable video retains its existing renderer');
const change = component.match(/\.onChange\(\(index: number\) => \{([\s\S]*?)\n      \}\)/);
assert(change);
const select = vm.runInNewContext(ts.transpileModule('(function(index: number) {' + change[1] + '})', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const selected = [], host = { selectedIndex: 0, images: parse(raw), onSelect: url => selected.push(url) };
select.call(host, 2); assert.equal(host.selectedIndex, 2); assert.equal(selected[0], image(2).url);
select.call(host, 1); assert.equal(host.selectedIndex, 1); assert.equal(selected[1], image(1).url);
select.call(host, 99); assert.equal(selected.length, 2, 'obsolete index cannot publish an invalid image');
assert.equal(host.selectedIndex, 1, 'obsolete index cannot corrupt the active slide');
for (const index of [-1, 3, 1.5, NaN, Infinity]) {
  select.call(host, index);
  assert.equal(host.selectedIndex, 1, 'invalid native callback preserves selected photo');
}
assert.equal(selected.length, 2);
for (const index of [0, 1, 2, 1, 0, 2, 0]) select.call(host, index);
assert.deepEqual(selected.slice(2), [0, 1, 2, 1, 0, 2, 0].map(n => image(n).url), 'rapid forward/back and dot jumps retain the selected source');
const appear = component.match(/aboutToAppear\(\): void \{([\s\S]*?)\n  \}/);
const restoreIndex = vm.runInNewContext('(function() {' + appear[1] + '})');
for (const [initialIndex, expected] of [[0, 0], [2, 2], [-1, 0], [9, 2]]) {
  const restored = { initialIndex, images: parse(raw), selectedIndex: -1 };
  restoreIndex.call(restored);
  assert.equal(restored.selectedIndex, expected, 'retained return index is restored within current gallery bounds');
}
for (const selectedIndex of [0, 1, 2, 1, 0]) {
  Object.assign(loadingHost, { selectedIndex, cardInViewport: true, loadingActive: true,
    decodedUrls: [0, 1, 2].map(n => image(n).url) });
  assert.equal(canLoad.call(loadingHost, selectedIndex), true);
  assert([0, 1, 2].filter(index => canLoad.call(loadingHost, index)).length <= 3);
  loadingHost.loadingActive = false;
  for (const index of [0, 1, 2]) assert.equal(canLoad.call(loadingHost, index), false);
  loadingHost.loadingActive = true;
  assert.equal(canLoad.call(loadingHost, selectedIndex), true, 'each retained slide resumes without resetting decoded history');
}
const retryBody = retry.match(/\.onClick\(\(\) => \{([\s\S]*?)\n                    \}\)/);
assert(retryBody);
const failedPhoto = parse(raw)[1];
const retryPhoto = vm.runInNewContext(ts.transpileModule('(function() {' + retryBody[1] + '})', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { photo: failedPhoto });
const retryHost = { failedUrls: [image(0).url, failedPhoto.url] };
retryPhoto.call(retryHost);
assert.deepEqual(Array.from(retryHost.failedUrls), [image(0).url], 'retry only remounts the requested failed photo');
assert.match(card, /this\.carouselSources\.set\(pin.id, url\); this\.stageDetailSource\(\); this\.onPin\(pin.id, url\)/, 'detail staging and navigation use the same selected photo');
assert.match(page, /initialIndex: Math.max\(0, \(pin.carouselImages \|\| \[\]\).findIndex/, 'row remount restores retained carousel source');
assert.doesNotMatch(component, /http\.createHttp|new Date|Date\.now|setTimeout/);
for (const token of ['app.color.primary_text', 'app.color.secondary_text', 'savedCaption']) assert(component.includes(token));
console.log('Feed carousel: native/Web parity, invalid URLs/slots, order, cache, retained return, external dots, title/menu order and gesture guards passed');
