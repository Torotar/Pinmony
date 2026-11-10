const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const methods = ['fitPhotoToScreen', 'heroHeight', 'wideDetail', 'detailPaneWidth', 'detailMediaWidth', 'needsPhotoBackdrop', 'detailPhotoRadius'].map(name => {
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
