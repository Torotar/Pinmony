const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync(process.argv[3] || 'feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
const image = fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets', 'utf8');
const start = page.indexOf('PinmonyCdnImage({ url: this.recoveredSources[pin.imageUrl]');
assert(start >= 0, 'use production home photo configuration');
const optionsSource = page.slice(start, page.indexOf('onDecoded:', start)) + '})';
function options(imageLoadingActive, paneActive) {
  let captured;
  const run = vm.runInNewContext(ts.transpileModule('function config(pin) {' + optionsSource + '} config;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { PinmonyCdnImage: config => { captured = config; }, ImageFit: { Cover: 'cover' } });
  const pin = { id: 'fixture', imageUrl: 'fixture.jpg' };
  run.call({ imageLoadingActive, paneActive, recoveredSources: {}, home: { pins: [pin] } }, pin);
  return captured;
}
function method(name) {
  const match = image.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
  assert(match, name); return match[0];
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['release', 'reload', 'loadingChanged', 'canRenderImage'].map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, {
  acceptsSoftwareJpeg: () => true,
  PinmonyJpegDecode: { acquire() { throw Error('home must retain native image cache'); } }
});
function host(active, pane) {
  const h = new Host();
  Object.assign(h, options(active, pane), { visible: true, inViewport: false, generation: 0,
    tracePhases: new Set(), uiCommits: { clear() {} } });
  h.reload(); return h;
}
const cached = host(true, true);
assert.equal(cached.canRenderImage(), true, 'mounted offscreen photo starts before entering viewport');
cached.inViewport = true; cached.loadingChanged(); cached.inViewport = false; cached.loadingChanged();
assert.equal(cached.loadAllowed, true, 'scrolling offscreen keeps cached photo loading');
const generation = cached.generation;
for (const state of [[false, true], [true, false], [false, false]]) {
  const pending = host(...state);
  assert.equal(pending.canRenderImage(), false, 'hidden category or page/background admits no fresh image');
  Object.assign(pending, options(true, true)); pending.loadingChanged();
  assert.equal(pending.canRenderImage(), true, 'resume can start the cached image without viewport reentry');
  Object.assign(cached, options(...state)); cached.loadingChanged();
  assert.equal(cached.canRenderImage(), true, 'already admitted native node survives cover/background');
  assert.equal(cached.generation, generation, 'preserve source generation');
}
cached.url = 'replacement.jpg'; cached.reload();
assert.equal(cached.canRenderImage(), false, 'new source under cover cannot inherit old admission');
Object.assign(cached, options(true, true)); cached.loadingChanged();
assert.equal(cached.canRenderImage(), true);
cached.release(); assert.equal(cached.nativeSourceAdmitted, false, 'source disposal clears native admission');
assert(page.includes('.cachedCount(this.cachedImageCount(), true)'), 'keep adaptive bounded WaterFlow cache');
assert(page.includes('this.settleFirstImage(pin)'), 'retain first visible image gate for detail prefetch');
console.log('Home cached images: production options, offscreen start/continue, hidden category/background, resume, retained node, source replacement/disposal and bounded cache passed');
