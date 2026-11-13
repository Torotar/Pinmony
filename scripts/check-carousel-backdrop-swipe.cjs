const fs = require('node:fs');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const carousel = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
assert(carousel.includes('private slotNeedsBackdrop('), 'each slide must own its backdrop instead of replacing one shared image');
const ast = ts.createSourceFile('carousel.ts', carousel.replace(/\bstruct\b/g, 'class'), 99, true);
let method;
function visit(n) {
  if (ts.isMethodDeclaration(n) && n.name.getText(ast) === 'slotNeedsBackdrop') method = n.getText(ast);
  ts.forEachChild(n, visit);
}
visit(ast);
const Host = vm.runInNewContext(ts.transpileModule(`class Host { ${method} } Host`, { compilerOptions: { target: 99 } }).outputText);
const h = new Host();
h.contentWidth = 400; h.mediaHeight = () => 500;
const tall = { imageWidth: 300, imageHeight: 1000 };
assert.equal(h.slotNeedsBackdrop(tall), true);
assert.equal(h.slotNeedsBackdrop({ imageWidth: 1000, imageHeight: 300 }), false);
assert.equal(h.slotNeedsBackdrop({ imageWidth: 0, imageHeight: 0 }), false);
assert.equal(h.slotNeedsBackdrop({ ...tall, video: {} }), false);
for (const selected of [0, 1, 2, 1, 0]) {
  h.page = selected;
  assert.equal(h.slotNeedsBackdrop(tall), true, 'a retained slide backdrop cannot depend on selected index');
}
const swiper = carousel.slice(carousel.indexOf('Swiper(this.controller)'));
assert.match(swiper, /if \(this\.slotNeedsBackdrop\(item\)\)[\s\S]*?url: item\.imageUrl/);
assert.match(swiper, /blur\(28 \* this\.entryBackdropProgress \* \(1 - this\.viewerBackdropProgress\)\)/);
assert.match(swiper, /opacity\(this\.entryPhotoHidden \|\| this\.imageHidden \? 0 : 1\)/);
assert(!swiper.includes('.id(this.sourceId).opacity(this.imageHidden'), 'viewer must hide foreground without abruptly removing blur');
const backdropSource = page.slice(page.indexOf('private backdropImageUrl()'), page.indexOf('private needsCoverBackdrop()'));
assert(!backdropSource.includes('carouselBackdropIndex'), 'retained entry cover never swaps URL when paging');
assert(page.includes('(this.coverBackdropVisible() ? 1 : 0)'), 'retained cover yields to an actually rendered carousel backdrop');
for (const prop of ['entryBackdropProgress', 'viewerBackdropProgress', 'entryPhotoHidden']) {
  assert(page.includes(`${prop}: this.${prop}`), `forward ${prop} from existing animation`);
}
console.log('Carousel blur: stable slide ownership, mixed aspect ratios/video, rapid reverse swipes, foreground separation and entry/viewer progress passed');

const names = ['slotKey', 'backdropRenderKey', 'backdropLoadingActive', 'retryImage', 'notifyBackdropReady'];
const methods = [];
function findAuditMethods(n) {
  if (ts.isMethodDeclaration(n) && names.includes(n.name.getText(ast))) methods.push(n.getText(ast));
  ts.forEachChild(n, findAuditMethods);
}
findAuditMethods(ast);
assert.equal(methods.length, names.length, 'retain backgrounds across language changes and unrelated retries');
const AuditHost = vm.runInNewContext(ts.transpileModule(`class AuditHost { ${methods.join('\n')} } AuditHost`, { compilerOptions: { target: 99 } }).outputText);
const audit = new AuditHost();
const items = Array.from({ length: 7 }, (_, index) => ({ id: 'slot-' + index, imageUrl: 'image-' + index }));
Object.assign(audit, { alive: true, identity: 'pin', carousel: { pinId: 'pin', items }, active: true,
  page: 0, failed: ['slot-2'], revision: 0, uiLanguage: 'zh', backdropRetryVersions: new Map() });
const initialKeys = items.map(item => audit.backdropRenderKey(item));
for (const language of ['en', 'zh']) {
  audit.uiLanguage = language;
  assert.deepEqual(items.map(item => audit.backdropRenderKey(item)), initialKeys, 'language changes preserve all decoded backgrounds');
}
audit.retryImage(items[2], 2);
assert.equal(audit.revision, 1); assert.equal(audit.failed.length, 0);
for (let index = 0; index < items.length; index++) {
  assert.equal(audit.backdropRenderKey(items[index]) === initialKeys[index], index !== 2, 'retry replaces only the requested backdrop');
}
audit.retryImage(items[2], 2);
assert.equal(audit.revision, 1, 'duplicate retry is ignored once failure clears');
audit.failed = ['slot-2']; audit.alive = false; audit.retryImage(items[2], 2);
assert.equal(audit.revision, 1, 'disposed retry does not mutate state');
audit.alive = true; audit.retryImage({ ...items[2], imageUrl: 'stale' }, 2);
assert.equal(audit.revision, 1, 'replaced image source cannot retry the new slot');
audit.identity = 'previous'; audit.retryImage(items[2], 2);
assert.equal(audit.revision, 1, 'old Pin context cannot retry'); audit.identity = 'pin';
audit.failed = [];
for (const selected of [0, 1, 5, 6, 1]) {
  audit.page = selected;
  const admitted = items.map((_, index) => index).filter(index => audit.backdropLoadingActive(index));
  assert(admitted.length <= 3);
  assert(admitted.every(index => Math.abs(index - selected) <= 1));
  assert(admitted.includes(selected));
  assert.equal(audit.backdropLoadingActive(-1), false);
  assert.equal(audit.backdropLoadingActive(items.length), false);
}
audit.active = false;
assert(items.every((_, index) => !audit.backdropLoadingActive(index)), 'covered/background page cannot admit new background loads');
assert.match(swiper, /loadingActive: this\.backdropLoadingActive\(index\)/);
assert.match(swiper, /\(item: PinmonyCarouselItem\): string => this\.slotKey\(item\)/);
assert.match(swiper, /ForEach\(\[this\.revision\.toString\(\) \+ ':' \+ this\.uiLanguage\]/, 'localized retry content updates without replacing the slide');
assert.match(swiper, /IndicatorComponent\(this.indicatorController\)[\s\S]*?\.opacity\(this\.entryPhotoHidden \? 0 : 1\)/, 'entry retains the original indicator reveal timing');
console.log('Carousel audit: language retention, target-only retry, stale/disposed callbacks, bounded foreground admission and indicator entry timing passed');

let ready = 0;
audit.onFirstBackdropReady = () => ready++;
audit.notifyBackdropReady(items[1], 1); assert.equal(ready, 0);
audit.notifyBackdropReady({ ...items[0], imageUrl: 'replaced' }, 0); assert.equal(ready, 0);
audit.notifyBackdropReady(items[0], 0); assert.equal(ready, 1);
audit.alive = false; audit.notifyBackdropReady(items[0], 0); assert.equal(ready, 1);
audit.alive = true; audit.identity = 'old'; audit.notifyBackdropReady(items[0], 0); assert.equal(ready, 1);
const pageAst = ts.createSourceFile('detail.ts', page.replace(/\bstruct\b/g, 'class'), 99, true);
const pageNames = ['coverBackdropVisible', 'needsCoverBackdrop', 'backdropImageUrl'];
const pageMethods = [];
function findPageMethods(n) {
  if (ts.isMethodDeclaration(n) && pageNames.includes(n.name.getText(pageAst))) pageMethods.push(n.getText(pageAst));
  ts.forEachChild(n, findPageMethods);
}
findPageMethods(pageAst);
assert.equal(pageMethods.length, pageNames.length);
const PageHost = vm.runInNewContext(ts.transpileModule(`class PageHost { ${pageMethods.join('\n')} } PageHost`, { compilerOptions: { target: 99 } }).outputText);
const p = new PageHost();
const detail = { imageWidth: 300, imageHeight: 1000, imageUrl: 'cover' };
Object.assign(p, { displayedDetail: () => detail, detailMediaWidth: () => 400, heroHeight: () => 500,
  needsPhotoBackdrop: () => true, carouselBackdropReady: false, carouselBackdropIndex: 0 });
assert.equal(p.needsCoverBackdrop(), true); assert.equal(p.coverBackdropVisible(), true);
detail.carousel = { items };
assert.equal(p.needsCoverBackdrop(), true, 'metadata installation keeps the existing cover node eligible');
assert.equal(p.coverBackdropVisible(), true, 'cover remains visible until the new background actually renders');
p.carouselBackdropReady = true; assert.equal(p.coverBackdropVisible(), false);
p.carouselBackdropReady = false; p.carouselBackdropIndex = 2;
assert.equal(p.coverBackdropVisible(), false, 'entry cover cannot appear under a different selected image');
assert.equal(p.backdropImageUrl(), 'cover', 'paging does not change retained cover source');
p.carouselBackdropIndex = 0; p.needsPhotoBackdrop = () => false;
assert.equal(p.coverBackdropVisible(), false, 'fitting first slide needs no retained fill');
detail.carousel.freeScroll = true; assert.equal(p.needsCoverBackdrop(), false);
delete detail.carousel; detail.isVideo = true; assert.equal(p.needsCoverBackdrop(), false);
detail.isVideo = false; detail.imageWidth = 0; assert.equal(p.needsCoverBackdrop(), false);
assert(page.includes('onFirstBackdropReady: () => { this.carouselBackdropReady = true; }'));
assert(carousel.includes('onDecoded: () => this.notifyBackdropReady(item, index)'));
assert(!carousel.includes('onDataReady: () => this.notifyBackdropReady'), 'data-ready alone cannot remove the retained cover');
console.log('Carousel metadata handoff: retained cover, render-only readiness, mixed media, source replacement, Pin/disposal isolation passed');

// Exercise the real language guard against both invalid nesting variants.
// Mutations stay in memory; no source fixture is written into the workspace.
const path = require('node:path');
const checkLiveLanguage = require('./check-live-language.cjs');
const readFile = fs.readFileSync;
const carouselPath = path.resolve('feature_pin/src/main/ets/components/PinmonyCarouselView.ets');
checkLiveLanguage(ts);
try {
  for (const mutate of [
    text => text.replace("ForEach([this.revision.toString() + ':' + this.uiLanguage]", 'ForEach([this.revision.toString()]'),
    text => text.replace('// The immutable slide source', "Text(this.uiText('pm_retry_b8784c8d'))\n            // The immutable slide source")
  ]) {
    const mutated = mutate(carousel);
    assert.notEqual(mutated, carousel, 'negative language fixture must modify the intended source');
    fs.readFileSync = function(file, ...args) {
      return typeof file === 'string' && path.resolve(file) === carouselPath ? mutated : readFile.call(fs, file, ...args);
    };
    assert.throws(() => checkLiveLanguage(ts), /Localized list must invalidate/,
      'missing language key and unprotected sibling copy must still be rejected');
  }
} finally {
  fs.readFileSync = readFile;
}
console.log('Language nesting: stable media with keyed copy passes; missing key and unprotected sibling copy still fail');
