const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const methods = ['fitPhotoToScreen', 'heroHeight', 'wideDetail', 'detailPaneWidth', 'detailMediaWidth', 'needsPhotoBackdrop', 'detailPhotoRadius', 'photoFitReservedHeight', 'measurePhotoFitActions'].map(name => {
  const start = source.indexOf(`  private ${name}(`);
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  }', start) + 4);
}).join('\n');
const deviceInfo = { deviceType: 'tablet' };
const Host = vm.runInNewContext(ts.transpileModule(`class Host { ${methods} } Host`, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { deviceInfo });
const page = new Host();
let detail = { imageWidth: 1000, imageHeight: 3000 };
page.displayedDetail = () => detail;
page.titleContentInset = () => 80;
page.getUIContext = () => ({ px2vp: px => px / 2 });
page.gestureBarHeightPx = 48;
page.photoFitActionBottom = 64;
let fitAudits = 0;
page.queuePhotoFitAudit = () => fitAudits++;
for (const [width, height] of [[1200, 800], [900, 650], [800, 1200], [650, 700], [400, 700]]) {
  Object.assign(page, { contentWidth: width, viewportWidth: width, viewportHeight: height });
  for (const [iw, ih] of [[1000, 3000], [3000, 1000], [1000, 1000], [1000, 15000], [0, 0]]) {
    detail = { imageWidth: iw, imageHeight: ih };
    page.detailPhotoFitEnabled = false;
    const original = page.heroHeight();
    page.detailPhotoFitEnabled = true;
    const fitted = page.heroHeight();
    assert(fitted > 0 && fitted <= height - 80 - 24 - 32);
    assert(fitted <= original);
    assert(fitted + 80 + 24 + page.photoFitReservedHeight() <= height,
      'photo, full action row, spacing and safe areas fit the first viewport');
    // Contain rendering must fit both dimensions, including very tall photos.
    if (iw && ih) {
      const scale = Math.min(page.detailPaneWidth() / iw, fitted / ih);
      assert(ih * scale <= fitted + 1e-8);
      assert(iw * scale <= page.detailPaneWidth() + 1e-8);
    }
    detail.isVideo = true;
    page.detailPhotoFitEnabled = false;
    const videoHeight = page.heroHeight();
    page.detailPhotoFitEnabled = true;
    assert.equal(page.heroHeight(), videoHeight, 'video layout stays unchanged');
  }
}
// Measured prefix includes notices above the row and a two-line save label.
page.contentWidth = page.viewportWidth = 400; page.viewportHeight = 700;
page.detailPhotoFitEnabled = true;
detail = { imageWidth: 1000, imageHeight: 4000 };
page.measurePhotoFitActions({ position: { y: 36 }, height: 68 });
assert.equal(page.photoFitActionBottom, 104);
assert.equal(page.heroHeight(), 700 - 80 - 24 - 32 - 18 - 104);
page.measurePhotoFitActions({ position: { y: 36 }, height: 68 });
page.measurePhotoFitActions({ position: { y: 0 }, height: 0 });
assert.equal(fitAudits, 1, 'stable or invalid measurements do not cause layout feedback');
detail.carousel = { items: [] };
assert.equal(page.heroHeight(), 700 - 80 - 24 - 32 - 18 - 104 - 28,
  'carousel indicator also fits above the action row');
detail.carousel.freeScroll = true;
assert.equal(page.heroHeight(), 700 - 80 - 24 - 32 - 18 - 104,
  'free-scroll gallery has no separate indicator');
page.contentWidth = page.viewportWidth = 1200; page.viewportHeight = 800;
assert.equal(page.photoFitReservedHeight(), 32, 'side-by-side information does not consume photo height');
detail.carousel.freeScroll = false;
assert.equal(page.photoFitReservedHeight(), 60, 'wide carousel still reserves its indicator');
page.photoFitActionBottom = 64;
assert(source.includes('.onAreaChange((_old: Area, area: Area) => this.measurePhotoFitActions(area))'));
page.contentWidth = page.viewportWidth = 400; page.viewportHeight = 700;
detail = { imageWidth: 1000, imageHeight: 4000 };
const loadingHeight = page.heroHeight();
const auditsBeforeReady = fitAudits;
for (const rowHeight of [44, 54, 64, 44]) {
  page.measurePhotoFitActions({ position: { y: 0 }, height: rowHeight });
  assert.equal(page.heroHeight(), loadingHeight,
    'loading placeholder, ready actions and two-line save keep the same fitted photo height');
}
assert.equal(fitAudits, auditsBeforeReady, 'ordinary loading completion never starts a new fit layout');
page.measurePhotoFitActions({ position: { y: 0 }, height: 80 });
assert.equal(page.heroHeight(), loadingHeight - 16, 'larger accessibility controls still reserve their real height');
page.measurePhotoFitActions({ position: { y: 0 }, height: 44 });
assert.equal(page.heroHeight(), loadingHeight, 'font-size change can restore the stable base allowance');
const info = source.slice(source.indexOf('  private detailInformation()'), source.indexOf('  private detailHeader()'));
const measuredActions = info.indexOf('.onAreaChange((_old: Area, area: Area) => this.measurePhotoFitActions(area))');
assert(measuredActions >= 0);
assert.match(info.slice(0, measuredActions), /if \(!this\.fitPhotoToScreen\(\)\) \{\s*this\.detailStateNotices\(\)/,
  'disabled fit and video retain their existing notice order');
assert.match(info.slice(measuredActions), /if \(this\.fitPhotoToScreen\(\)\) \{\s*this\.detailStateNotices\(\)/,
  'fitted photo status notices sit after the measured actions and cannot change their vertical origin');
console.log('Photo fit loading stability: loading/ready/two-line controls, large text and notice placement passed');
deviceInfo.deviceType = 'phone';
detail = { imageWidth: 1000, imageHeight: 3000 };
page.contentWidth = page.viewportWidth = 900; page.viewportHeight = 650;
page.detailPhotoFitEnabled = true;
assert(page.heroHeight() <= 650 - 80 - 24 - 32, 'ordinary phones fit photo');
assert(page.heroHeight() <= 650 - 80 - 24 - 32, 'expanded foldable fits photo');
page.contentWidth = page.viewportWidth = 400;
assert(page.heroHeight() <= 650 - 80 - 24 - 32, 'compact phone and folded window fit photo');
page.detailPhotoFitEnabled = false;
assert.equal(page.heroHeight(), page.detailPaneWidth() * 3, 'disabled phone retains original layout');
const settings = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets', 'utf8');
const startup = fs.readFileSync('entry/src/main/ets/startup/PreferencesTask.ets', 'utf8');
assert(settings.includes("@StorageLink('detailPhotoFitEnabled')"));
assert(!settings.includes("this.uiText('pm_detail_photo_fit_description')"),'photo-fit row has no subtitle');
const settingsAst=ts.createSourceFile('settings.ts',settings.replace(/\bstruct\b/g,'class'),99,true);
let fitRowFound=false;
function checkFitRow(node,deviceGuard=false){
  const guarded=deviceGuard || ts.isIfStatement(node)&&node.expression.getText(settingsAst).includes('supportsOrientation');
  if(ts.isStringLiteral(node)&&node.text==='pm_detail_photo_fit'){assert(!guarded,'photo-fit setting is visible on ordinary phones');fitRowFound=true;}
  ts.forEachChild(node,child=>checkFitRow(child,guarded));
}
checkFitRow(settingsAst);assert(fitRowFound);
assert(source.includes("@StorageProp('detailPhotoFitEnabled')"));
assert(startup.includes("PersistentStorage.persistProp('detailPhotoFitEnabled', false)"));
assert(fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailHero.ets', 'utf8').includes('fit: ImageFit.Contain'));
const carouselSource = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
const start = carouselSource.indexOf('  private mediaHeight(');
const Carousel = vm.runInNewContext(ts.transpileModule(`class Carousel { ${carouselSource.slice(start, carouselSource.indexOf('\n  }', start) + 4)} } Carousel`, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const carousel = new Carousel();
carousel.contentWidth = 900;
carousel.carousel = { freeScroll: true, items: [{ imageWidth: 1000, imageHeight: 9000 }] };
carousel.maxMediaHeightVp = 0;
assert.equal(carousel.mediaHeight(), 620);
carousel.maxMediaHeightVp = 180;
assert.equal(carousel.mediaHeight(), 180, 'free-scroll gallery respects available height even below old minimum');
carousel.carousel.freeScroll = false;
carousel.mediaHeightVp = 180;
assert.equal(carousel.mediaHeight(), 180);
for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
  const strings = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
  for (const key of ['pm_detail_photo_fit', 'pm_detail_photo_fit_description']) {
    assert.equal(strings.filter(row => row.name === key).length, 1);
    assert(strings.find(row => row.name === key).value.trim());
  }
}
console.log('Detail photo fit passed: portrait/landscape, tall/wide/unknown dimensions, resize, disabled, phone, foldable, video and preference wiring');

page.carouselBackdropIndex=0;page.detailPhotoFitEnabled=true;
page.contentWidth=page.viewportWidth=400;page.viewportHeight=700;
detail={imageWidth:1000,imageHeight:700};
assert.equal(page.needsPhotoBackdrop(),false);assert.equal(page.detailPhotoRadius(),18,'fully fitting photo keeps rounded corners');
detail={imageWidth:1000,imageHeight:4000};
assert.equal(page.needsPhotoBackdrop(),true);assert.equal(page.detailPhotoRadius(),0,'height-constrained tall photo uses blur and square corners');
page.detailPhotoFitEnabled=false;
assert.equal(page.needsPhotoBackdrop(),false);assert.equal(page.detailPhotoRadius(),18,'full-width uncompressed photo needs no side fill');
page.detailPhotoFitEnabled=true;detail={imageWidth:0,imageHeight:0};
assert.equal(page.needsPhotoBackdrop(),false,'unknown dimensions cannot justify blur');
detail={imageWidth:1000,imageHeight:700,carousel:{items:[{imageWidth:1000,imageHeight:700},{imageWidth:1000,imageHeight:4000}]}};
assert.equal(page.detailPhotoRadius(),18);page.carouselBackdropIndex=1;assert.equal(page.detailPhotoRadius(),0,'carousel uses current photo dimensions');
detail.carousel.freeScroll=true;assert.equal(page.detailPhotoRadius(),18,'product gallery retains independent corners');
console.log('Adaptive photo corners: fitting/tall/unknown, fit switch and carousel slide geometry passed');

const radiusStart = carouselSource.indexOf('  private photoRadius(');
const RadiusCarousel = vm.runInNewContext(ts.transpileModule(`class RadiusCarousel {
  ${carouselSource.slice(radiusStart, carouselSource.indexOf('\n  }', radiusStart) + 4)}
} RadiusCarousel`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const radiusCarousel = new RadiusCarousel();
radiusCarousel.carousel = { freeScroll: false };
page.carouselBackdropIndex = 0;
// Construct exact rendered side insets around the 18vp outer corner arc.
for (const [viewportWidth, viewportHeight] of [[400,700],[800,1200],[1200,800]]) {
  page.contentWidth = page.viewportWidth = viewportWidth; page.viewportHeight = viewportHeight;
  detail = { imageWidth: 1000, imageHeight: 10000 };
  const availableHeight = page.heroHeight();
  const mediaWidth = page.detailMediaWidth();
  for (const inset of [0.25, 2, 8, 17.9, 18.1, 32, 64]) {
    detail = { imageWidth: mediaWidth - inset * 2, imageHeight: availableHeight };
    const expectedRadius = inset < 18 ? 18 : 0;
    assert.equal(page.needsPhotoBackdrop(), true, 'even narrow side fill keeps its animated backdrop');
    assert.equal(page.detailPhotoRadius(), expectedRadius, 'single photo clips within the corner arc when side fill is narrow');
    detail.carousel = { items: [{ imageWidth: detail.imageWidth, imageHeight: detail.imageHeight }], freeScroll: true };
    assert.equal(page.detailPhotoRadius(), 18, 'product gallery keeps independent rounded cards');
    detail.carousel.freeScroll = false;
    // The ordinary carousel also reserves its own indicator row.
    const carouselHeight = page.heroHeight();
    detail.carousel.items[0] = { imageWidth: mediaWidth - inset * 2, imageHeight: carouselHeight };
    assert.equal(page.detailPhotoRadius(), expectedRadius, 'detail transition uses the selected carousel photo geometry');
    radiusCarousel.contentWidth = mediaWidth;
    radiusCarousel.mediaHeight = () => carouselHeight;
    assert.equal(radiusCarousel.photoRadius(detail.carousel.items[0]), expectedRadius,
      'carousel image and Swiper clip agree with detail entry and viewer endpoints');
  }
}
radiusCarousel.carousel.freeScroll = true;
assert.equal(radiusCarousel.photoRadius({imageWidth:100,imageHeight:1000}),18);
radiusCarousel.carousel.freeScroll = false;
for (const item of [{imageWidth:0,imageHeight:0},{video:{},imageWidth:100,imageHeight:1000}]) {
  assert.equal(radiusCarousel.photoRadius(item),18,'unknown images and video retain existing corners');
}
assert(source.includes('sourceRadius: this.detailPhotoRadius()'));
assert(source.includes('targetRadius: this.detailPhotoRadius()'));
assert(carouselSource.includes('.borderRadius(this.photoRadius(item)).clip(true)'));
console.log('Narrow backdrop corners: phone/tablet/wide, selected carousel slot, corner-arc boundary and entry/viewer radius parity passed');
