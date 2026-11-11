const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const carousel = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const height = carousel.slice(carousel.indexOf('  private mediaHeight():'), carousel.indexOf('  build()'));
const origin = page.slice(page.indexOf('  private measureViewerOrigin():'), page.indexOf('  @Prop visualResult'));
const geometry = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets', 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
const measureImageFlightOrigin = vm.runInNewContext(ts.transpileModule(geometry + ';measureImageFlightOrigin;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const context = { exports: {}, measureImageFlightOrigin };
vm.runInNewContext(ts.transpileModule('export class Layout { displayedDetail() { return this.detail; }' + height + origin + '}', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, context);
const x = new context.exports.Layout();
x.contentWidth = 400; x.mediaHeightVp = 1200;
x.carousel = { freeScroll: true, items: [{ imageWidth: 736, imageHeight: 1378 }] };
assert.equal(x.mediaHeight(), Math.min(620, 400 * 0.82 * 1378 / 736));
x.carousel.freeScroll = false; assert.equal(x.mediaHeight(), 1200, 'ordinary carousel retains its height');
x.traceId = 7; x.zoomImageUrl = 'second';
x.detail = { carousel: { freeScroll: true, items: [{ imageUrl: 'first' }, { imageUrl: 'second' }] } };
const measured = [];
x.getUIContext = () => ({ px2vp: n => n / 2,
  getFrameNodeById: id => ({ getPositionToWindowWithTransform: () => id.includes('root') ?
    { x: 5, y: 10 } : { x: -25, y: 110 } }),
  getComponentUtils: () => ({ getRectangleById: id => {
  measured.push(id);
  return id.includes('root') ? { windowOffset: { x: 10, y: 20 } } :
    { windowOffset: { x: -50, y: 220 }, size: { width: 656, height: 1240 } };
} }) });
const rect = x.measureViewerOrigin();
assert.equal(measured[0], 'pinmony-photo-source-7-1');
assert.equal(rect.x, -30); assert.equal(rect.y, 100); assert.equal(rect.width, 328);
assert.equal(rect.height, 620);
const validUi = x.getUIContext();
x.getUIContext = () => ({ ...validUi, getFrameNodeById: () => undefined });
assert.equal(x.measureViewerOrigin().width, 0, 'missing frame node cannot supply stale return geometry');
x.getUIContext = () => validUi;
assert(carousel.includes(".opacity(this.imageHidden && item.imageUrl === this.hiddenImageUrl ? 0 : 1)"));
assert(page.includes('hiddenImageUrl: this.zoomImageUrl'));
assert(!page.includes('.translate({ x: this.displayedDetail().carousel?.freeScroll'));
assert(page.includes('.margin({ left: this.displayedDetail().carousel?.freeScroll && !this.wideDetail() ? -18 : 0,'));
console.log('Product gallery: card-based height, selected-card return rect, scroll offset and decoded visibility handoff passed');
