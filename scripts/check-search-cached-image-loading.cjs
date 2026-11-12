const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync(process.argv[3] || 'feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const image = fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets', 'utf8');
const cardStart = page.indexOf('  private pinCard(');
const card = page.slice(cardStart, page.indexOf('\n  @Builder', cardStart + 1));
const start = card.indexOf('PinmonyCdnImage({');
assert(start >= 0, 'use the production result image host');
const end = card.indexOf('})', start);
const result = { imageUrl: 'synthetic.jpg' };
function options(active, mediaActive, quizSheetOpen) {
  let captured;
  const body = card.slice(start, end + 2);
  const run = vm.runInNewContext('(function(result){' + body + '})', {
    PinmonyCdnImage: config => { captured = config; }, ImageFit: { Cover: 'cover' }
  });
  run.call({ active, mediaActive, quizSheetOpen, markImageFailed() {} }, result);
  return captured;
}
function method(name) {
  const match = image.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
  assert(match, name); return match[0];
}
const leases = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['release', 'reload', 'loadingChanged', 'canRenderImage'].map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { acceptsSoftwareJpeg: url => url.endsWith('.jpg'), PinmonyJpegDecode: {
  acquire(url, active, priority) {
    const lease = { url, active, priority, released: false,
      setActive(value) { this.active = value; }, setPriority(value) { this.priority = value; },
      release() { this.released = true; } };
    lease.ready = new Promise((resolve, reject) => Object.assign(lease, { resolve, reject }));
    leases.push(lease); return lease;
  }
} });
function host(url) {
  const h = new Host();
  Object.assign(h, options(true, true, false), { url, useSharedDecode: true, visible: true,
    inViewport: false, generation: 0, tracePhases: new Set(), uiCommits: { clear() {} } });
  h.reload(); return h;
}
const flush = async () => { for (let i = 0; i < 8; i++) await Promise.resolve(); };
(async () => {
  const h = host('synthetic.jpg'), lease = leases.at(-1);
  assert.equal(lease.active, true, 'cached JPEG starts before it enters the viewport');
  h.inViewport = true; h.loadingChanged(); h.inViewport = false; h.loadingChanged();
  assert.equal(lease.active, true, 'scrolling beyond the screen must not pause a mounted cached image');
  for (const state of [[false, true, false], [true, false, false], [true, true, true]]) {
    Object.assign(h, options(...state)); h.loadingChanged();
    assert.equal(lease.active, false, 'hidden page, background or quiz pauses new work');
  }
  Object.assign(h, options(true, true, false)); h.loadingChanged();
  assert.equal(lease.active, true, 'resume without viewport reentry');
  const bitmap = { decoded: true }; lease.resolve(bitmap); await flush();
  assert.equal(h.bitmap, bitmap); assert.equal(h.canRenderImage(), true);
  h.loadingActive = false; h.loadingChanged(); assert.equal(h.bitmap, bitmap, 'retain decoded pixels under a cover');
  const native = host('synthetic.webp');
  assert.equal(native.canRenderImage(), true, 'cached non-JPEG starts through the established native fallback offscreen');
  native.loadingActive = false; native.loadingChanged();
  assert.equal(native.canRenderImage(), true, 'retain admitted native node when backgrounded');
  const failed = host('fallback.jpg'); leases.at(-1).reject(Error('unsupported decode')); await flush();
  assert.equal(failed.canRenderImage(), true, 'software failure uses native fallback even while cached offscreen');
  const stale = host('old.jpg'), old = leases.at(-1);
  stale.url = 'new.jpg'; stale.reload(); assert.equal(old.released, true);
  old.resolve({ stale: true }); await flush(); assert.equal(stale.bitmap, undefined, 'old source cannot overwrite new source');
  const current = leases.at(-1); stale.visible = false; stale.generation++; stale.release();
  current.resolve({ disposed: true }); await flush(); assert.equal(stale.bitmap, undefined);
  assert.equal(current.released, true, 'lazy recycling releases ownership');
  assert(page.includes('.cachedCount(this.cachedImageCount(), true)'), 'retain adaptive bounded WaterFlow cache');
  assert(page.includes('this.imagePrefetch.update(urls, this.imagePrefetchCount())') && !page.includes('@State private upcomingImageUrls'),
    'retain headless prefetch without scroll-driven page invalidation');
  console.log('Search cached images: start/continue offscreen, page/background/quiz gates, resume, JPEG/native fallback, retained pixels, stale source/disposal and bounded cache passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
