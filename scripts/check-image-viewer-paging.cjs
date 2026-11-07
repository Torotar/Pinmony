const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_pin/src/main/ets/components/PinmonyImageViewer.ets';
const source = fs.readFileSync(file, 'utf8');
function hostOf(text, names, globals = {}) {
  const tree = ts.createSourceFile('host.ts', text.replace(/\bstruct\b/g, 'class'), 99, true), methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(tree))) methods.push(node.getText(tree));
    ts.forEachChild(node, visit);
  }
  visit(tree);
  assert.equal(methods.length, names.length);
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: 99 }
  }).outputText, globals);
}
const Host = hostOf(source, ['initializePhotos', 'selectPhoto', 'transitionPhotos', 'photoSettled', 'retryPhoto', 'activeChanged', 'toggleZoom', 'trackTouch'],
  { Curve: { EaseInOut: 'ease-in-out' }, TouchType: { Down: 0, Up: 1, Move: 2, Cancel: 3 } });
const photos = [
  { id: 'wide', imageUrl: 'wide.jpg', imageWidth: 800, imageHeight: 400, title: 'wide' },
  { id: 'video', imageUrl: 'poster.jpg', imageWidth: 800, imageHeight: 400, title: 'video', video: {} },
  { id: 'tall', imageUrl: 'tall.jpg', imageWidth: 400, imageHeight: 800, title: 'tall' },
  { id: 'empty', imageUrl: '', imageWidth: 0, imageHeight: 0, title: '' },
  { id: 'square', imageUrl: 'square.jpg', imageWidth: 500, imageHeight: 500, title: 'square' }
];
function fixture(imageUrl = 'tall.jpg') {
  const h = new Host(), selected = [], decoded = [];
  Object.assign(h, { detail: { carousel: { pinId: 'pin', items: photos } }, imageUrl,
    mounted: true, active: true, closing: false, transitioning: false, transitionStarted: true,
    loadedPhotos: [], failedPhotos: [], scaleValue: 1, dx: 0, dy: 0,
    stopInertia() { h.stopped = (h.stopped || 0) + 1; }, containRect: () => ({ width: h.naturalWidth, height: h.naturalHeight }),
    setFrame(rect) { h.frame = rect; }, onImageChange(url) { selected.push(url); },
    imageDecoded(...args) { decoded.push(args); }
  });
  h.initializePhotos(); return { h, selected, decoded };
}
const { h, selected, decoded } = fixture();
assert.equal(h.photos.length, 3, 'only photos participate; skip video posters and empty sources');
assert.equal(h.photoIndex, 1, 'open the tapped photo, including non-first and mixed-media entries');
assert.equal(h.naturalWidth, 400); assert.equal(h.naturalHeight, 800);
const wide = h.photos[0];
h.photoSettled(wide, 1); assert.equal(h.loadedPhotos.includes('wide.jpg'), true);
assert.equal(decoded.length, 0, 'preloading a neighbor must not overwrite current-photo readiness');
h.scaleValue = 3; h.dx = 100; h.dy = -40;
h.selectPhoto(0);
assert.equal(h.scaleValue, 1); assert.equal(h.dx, 0); assert.equal(h.dy, 0);
assert.equal(h.originalReady, true); assert.equal(h.previewReady, false);
assert.equal(h.frame.width, 800); assert.equal(h.frame.height, 400);
assert.deepEqual(selected, ['wide.jpg']);
assert.equal(h.transitionPhotos()[0].imageUrl, 'wide.jpg', 'return animation follows the selected photo');
for (const index of [-1, 3, 0]) h.selectPhoto(index);
assert.equal(selected.length, 1, 'boundaries do not wrap or republish unchanged selection');
for (const gate of ['closing', 'transitioning']) {
  h[gate] = true; h.selectPhoto(2); h[gate] = false;
  assert.equal(h.photoIndex, 0, `${gate} blocks late page events`);
}
h.active = false; h.selectPhoto(2); h.active = true;
h.mounted = false; h.selectPhoto(2); h.mounted = true;
assert.equal(h.photoIndex, 0);
h.selectPhoto(2); assert.equal(h.originalReady, false); assert.equal(h.previewReady, false);
const square = h.photos[2];
h.photoSettled(square, -1, true); assert.equal(h.failedPhotos.includes(square.imageUrl), true);
h.retryPhoto(square); assert.equal(h.failedPhotos.includes(square.imageUrl), false);
assert.equal(h.photos[2].revision, 1);
h.photoSettled(square, -1, true); h.photoSettled(square, 1);
assert.equal(h.failedPhotos.length, 0, 'old retry errors cannot overwrite a new image attempt');
assert.equal(h.loadedPhotos.includes(square.imageUrl), false, 'old retry completions are discarded');
h.photoSettled(h.photos[2], 0); assert.equal(decoded.length, 0);
h.photoSettled(h.photos[2], 1); assert.equal(decoded.length, 1);
h.mounted = false; h.photoSettled(h.photos[1], 1);
assert.equal(h.loadedPhotos.includes('tall.jpg'), false, 'disposed preload completion is ignored');
const entry = fixture(); entry.h.transitionStarted = false; entry.h.transitioning = true;
entry.h.photoSettled(entry.h.photos[1], 1);
assert.equal(entry.decoded.length, 0, 'hidden Swiper readiness cannot release the entry source');
const single = fixture(); single.h.detail = { imageUrl: 'only.jpg', imageWidth: 50, imageHeight: 100 };
single.h.imageUrl = 'original.jpg'; single.h.initializePhotos();
assert.equal(single.h.photos.length, 0); assert.equal(single.h.transitionPhotos()[0].imageUrl, 'original.jpg');
h.paging = true; h.active = false; h.activeChanged(); assert.equal(h.paging, false);
assert.match(source, /\.index\(this.photoIndex\)\.loop\(false\)\.autoPlay\(false\)\.indicator\(false\)/);
// Emulate the native index setter being reapplied when zoom changes trigger a render.
// Reading the actual binding catches a stale initial index resetting zoom through onChange.
const binding = source.match(/\.index\(this\.(\w+)\)/)[1];
for (const initial of ['wide.jpg', 'tall.jpg']) {
  const { h: zoom, selected: changes } = fixture(initial);
  Object.assign(zoom, { viewportWidth: 360, viewportHeight: 720, multiTouch: false, touchMoved: false, paging: false,
    moveImage(x, y) { zoom.dx = x; zoom.dy = y; } });
  let nativeIndex = zoom.photoIndex;
  const render = () => {
    const requestedIndex = zoom[binding];
    if (requestedIndex !== nativeIndex) { nativeIndex = requestedIndex; zoom.selectPhoto(nativeIndex); }
  };
  zoom.getUIContext = () => ({ animateTo(options, change) { change(); render(); } });
  zoom.selectPhoto(2); nativeIndex = 2; zoom.paging = false;
  zoom.trackTouch({ type: 0, touches: [{ x: 150, y: 320 }] });
  zoom.toggleZoom(150, 320);
  assert.equal(nativeIndex, 2, 'double tap after swiping must retain the displayed photo');
  assert.equal(zoom.photoIndex, 2); assert.equal(zoom.scaleValue, 2.4, 'onChange must not reset the requested zoom');
  zoom.photoSettled(zoom.photos[2], 1); render();
  assert.equal(nativeIndex, 2, 'image render completion also retains the current index');
  zoom.trackTouch({ type: 0, touches: [{ x: 150, y: 320 }] });
  zoom.toggleZoom(150, 320);
  assert.equal(nativeIndex, 2); assert.equal(zoom.scaleValue, 1, 'double tap again shrinks the same photo');
  zoom.selectPhoto(1); nativeIndex = 1; render();
  zoom.toggleZoom(); assert.equal(nativeIndex, 1); assert.equal(zoom.scaleValue, 2.4, 'paging back then zooming retains that photo');
  assert.deepEqual(changes, ['square.jpg', 'tall.jpg'], 'zoom never reports a spurious return to the opening photo');
}
assert.match(source, /\.disableSwipe\(!this.active \|\| this.transitioning \|\| this.closing \|\| this.scaleValue > 1 \|\| this.multiTouch\)/);
assert.match(source, /\.gesture\(GestureGroup\(GestureMode.Exclusive/);
assert.match(source, /\.parallelGesture\(GestureGroup\(GestureMode.Parallel/);
assert.match(source, /this.previewReady \|\| this.originalReady \|\| this.transitionStarted \? this.backdrop : 0/, 'backdrop stays opaque during an unloaded page');
assert.match(source, /this.naturalWidth \|\| this.detail.imageWidth, this.naturalHeight \|\| this.detail.imageHeight, this.scaleValue/, 'zoom bounds follow the selected aspect ratio');
const carousel = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
const Carousel = hostOf(carousel, ['viewerPhotoChanged']);
const c = new Carousel(), positions = [], pages = [], offsets = [];
Object.assign(c, { alive: true, viewerImageUrl: 'square.jpg', carousel: { items: photos }, contentWidth: 324,
  controller: { changeIndex(...args) { pages.push(args); } },
  productScroller: { scrollTo(pos) { positions.push(pos); } }, onProductOffset: x => offsets.push(x) });
c.viewerPhotoChanged(); assert.equal(c.page, 4); assert.deepEqual(pages[0], [4, false]);
c.carousel.freeScroll = true; c.viewerPhotoChanged();
const maximum = photos.length * (324 * .82 + 6) - 6 - 324;
assert.equal(positions[0].xOffset, maximum); assert.equal(positions[0].animation, false);
assert.equal(offsets[0], maximum, 'product gallery retains the new close position');
c.viewerImageUrl = 'missing'; c.viewerPhotoChanged(); assert.equal(positions.length, 1);
c.alive = false; c.viewerImageUrl = 'wide.jpg'; c.viewerPhotoChanged(); assert.equal(positions.length, 1);
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
assert.match(page, /onImageChange: \(url: string\) => \{ this.zoomImageUrl = url; \}/);
assert.match(page, /viewerImageUrl: this.zoomImageUrl/);
console.log('Viewer paging: initial photo, mixed media, aspect ratios, boundaries, lifecycle, retry generations, preload handoff, zoom arbitration and both carousel return paths passed');
