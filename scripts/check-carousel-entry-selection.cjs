const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { carouselEntryIndex } = require('./arkts-module-loader.cjs').createArktsLoader(ts)
  .loadFile('feature_pin/src/main/ets/services/PinmonyCarouselEntry.ets');
const photo = (size, n, ext = 'jpg') => `https://i.pinimg.com/${size}/aa/bb/cc/photo${n}.${ext}`;
const items = [0, 1, 2].map(n => ({ id: String(n), imageUrl: photo('1200x', n), imageWidth: 1200, imageHeight: 1800 }));
const carousel = { pinId: '123', items };
for (const n of [0, 1, 2]) {
  for (const size of ['474x', '736x', 'originals']) {
    assert.equal(carouselEntryIndex(carousel, 'https://www.pinterest.com/pin/123/', photo(size, n)), n);
  }
}
assert.equal(carouselEntryIndex(carousel, '/pin/123/', photo('474x', 2, 'webp') + '?size=1'), 2);
assert.equal(carouselEntryIndex(carousel, '/pin/456/', photo('474x', 2)), -1, 'old Pin entry cannot select the next Pin');
assert.equal(carouselEntryIndex(carousel, '/pin/123/', photo('474x', 9)), -1);
assert.equal(carouselEntryIndex(undefined, '/pin/123/', photo('474x', 1)), -1, 'pending metadata is safe');
assert.equal(carouselEntryIndex({ ...carousel, freeScroll: true }, '/pin/123/', photo('474x', 1)), -1, 'product gallery retains its own offset lifecycle');
for (const url of ['', 'https://evil.test/474x/aa/bb/cc/photo2.jpg', 'https://i.pinimg.com.evil.test/474x/aa/bb/cc/photo2.jpg']) {
  assert.equal(carouselEntryIndex(carousel, '/pin/123/', url), -1);
}
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
const ast = ts.createSourceFile('carousel.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['aboutToAppear', 'aboutToDisappear', 'entryPreviewUrl', 'firstImageKey', 'settleFirstImage', 'onCarouselChanged', 'notifyBackdropReady', 'viewerPhotoChanged'];
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast);
assert.equal(methods.length, names.length);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: 99 }
}).outputText, { carouselEntryIndex });
const pages = [], settled = [], jumps = [];
let backgrounds = 0;
const host = new Host();
Object.assign(host, { carousel, entryPinUrl: '/pin/123/', entryImageUrl: photo('474x', 2), previewUrl: photo('474x', 0),
  revision: 0, failed: [], backdropRetryVersions: new Map(), firstRenderedKey: '',
  controller: { changeIndex: (index, animate) => jumps.push([index, animate]) },
  onPageChanged: index => pages.push(index), onFirstImageSettled: failed => settled.push(failed),
  onFirstBackdropReady: () => backgrounds++ });
host.aboutToAppear();
assert.equal(host.page, 2); assert.equal(host.entryPage, 2); assert.equal(pages[0], 2);
assert.equal(host.entryPreviewUrl(), photo('474x', 2), 'selected cached thumbnail bridges to its high-resolution slot');
host.settleFirstImage(items[0], 0, 1); assert.equal(settled.length, 0, 'first slot cannot release selected-slot readiness');
host.settleFirstImage(items[2], 2, 0); assert.equal(settled.length, 0, 'data-ready is not a rendered image');
host.settleFirstImage(items[2], 2, 1); assert.deepEqual(settled, [false]);
host.notifyBackdropReady(items[0], 0); assert.equal(backgrounds, 0);
host.notifyBackdropReady(items[2], 2); assert.equal(backgrounds, 1);
host.page = 1; host.onCarouselChanged();
assert.equal(host.page, 1, 'same-Pin metadata update never resets user swipes to the entry photo');
host.viewerImageUrl = items[0].imageUrl; host.viewerPhotoChanged();
assert.equal(host.page, 0, 'viewer return still restores its own selected photo');
host.carousel = { pinId: '456', items }; host.onCarouselChanged();
assert.equal(host.page, 0); assert.equal(host.entryPage, 0);
assert.equal(host.entryPreviewUrl(), host.previewUrl, 'sibling Pin cannot reuse the old selected thumbnail');
host.settleFirstImage(items[2], 2, 1); assert.deepEqual(settled, [false]);
host.aboutToDisappear(); host.settleFirstImage(items[0], 0, 1); assert.deepEqual(settled, [false]);
assert.match(source, /\.index\(this.page\)/, 'selected entry is applied before the first Swiper render');
assert.doesNotMatch(source, /\.sort\(|\.reverse\(/, 'server slide order is unchanged');
const parent = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
assert(parent.includes("entryPinUrl: this.entryPhoto?.pinUrl || ''"));
assert(parent.includes("entryImageUrl: this.entryPhoto?.imageUrl || ''"));
const pageAst = ts.createSourceFile('page.ts', parent.replace(/\bstruct\b/g, 'class'), 99, true);
const pageMethods = [];
function visitPage(node) {
  if (ts.isMethodDeclaration(node) && ['heroImageSources', 'heroRenderKey', 'backdropImageUrl', 'coverBackdropVisible'].includes(node.name.getText(pageAst))) pageMethods.push(node.getText(pageAst));
  ts.forEachChild(node, visitPage);
}
visitPage(pageAst);
const Page = vm.runInNewContext(ts.transpileModule('class Page {' + pageMethods.join('\n') + '} Page;', {
  compilerOptions: { target: 99 }
}).outputText, { carouselEntryIndex });
const detail = { pinUrl: '/pin/123/', imageUrl: photo('1200x', 0), mediaKind: 'carousel' };
const page = new Page();
Object.assign(page, { displayedDetail: () => detail, heroRenderRevision: 0,
  entryPhoto: { pinUrl: '/pin/123/', imageUrl: photo('474x', 2) },
  carouselBackdropIndex: 2, carouselBackdropReady: false, needsPhotoBackdrop: () => true });
assert.equal(page.heroImageSources(detail.imageUrl, detail.pinUrl)[0].url, photo('474x', 2), 'pending metadata never replaces selected preview with first-photo cover');
assert.equal(page.backdropImageUrl(), photo('474x', 2));
detail.carousel = carousel;
assert.equal(page.coverBackdropVisible(), true, 'selected entry backdrop remains until its own rendered callback');
page.carouselBackdropReady = true; assert.equal(page.coverBackdropVisible(), false);
page.carouselBackdropReady = false; page.carouselBackdropIndex = 0;
assert.equal(page.coverBackdropVisible(), false, 'entry background cannot cover another photo after a swipe');
detail.pinUrl = '/pin/456/';
assert.equal(page.backdropImageUrl(), detail.imageUrl);
assert.equal(page.heroImageSources(detail.imageUrl, detail.pinUrl)[0].url, detail.imageUrl, 'old entry photo is isolated from sibling detail');
const root = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(root.includes('imageWidth: entryImage?.width || pin.imageWidth'));
console.log('Carousel selected entry: CDN matching, async metadata, selected preview/readiness, stable updates, Pin isolation, viewer return and fallback passed');
