const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/components/SmartImage.ets', 'utf8');
const recovery = vm.runInNewContext(ts.transpileModule(source.slice(0, source.indexOf('export interface SmartImageOptions'))
  .replace(/^import[^\n]*\n/gm, '') + '\npickCoverRecoveryTier;', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, { exports: {} });
const methods = ['completeImage', 'failImage', 'traceImage', 'resetImage', 'displayHeightPx'].map(name => {
  const match = source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
  assert(match); return match[0];
});
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { pickCoverImageTier: images => images.tier,
  validImageUrl: (images, key) => images[key]?.url || images.url,
  pickCoverImageUrl: images => images.url, currentDensityPixels: () => 3,
  pickCoverRecoveryTier: recovery });
let loaded = 0, errors = [];
const image = new Host();
image.loadDecodedImage = () => {};
Object.assign(image, { imageVisible: true, imageRevision: 1, phase: 'loading',
  onLoaded: () => loaded++, onError: code => errors.push(code) });
image.completeImage(1, 0);
assert.equal(image.phase, 'loading', 'download completion must preserve loading feedback');
assert.equal(loaded, 0);
image.failImage(1, 123);
assert.equal(image.phase, 'failed', 'decode failure after data-ready must remain a failure');
assert.deepEqual(errors, [123]);
image.failImage(1, 123); assert.equal(errors.length, 1);
image.imageRevision = 2; image.phase = 'loading';
image.completeImage(1, 1); image.failImage(1, 456);
assert.equal(image.phase, 'loading', 'callbacks from a replaced image cannot settle the new source');
image.completeImage(2, 1); image.completeImage(2, 1); image.failImage(2, 456);
assert.equal(loaded, 1); assert.equal(image.phase, 'loaded'); assert.equal(errors.length, 1);
image.imageVisible = false; image.imageRevision = 3; image.phase = 'loading';
image.completeImage(3, 1); image.failImage(3, 789);
assert.equal(image.phase, 'loading', 'disposed image cannot notify or mutate presentation');
Object.assign(image, { imageVisible: true, images: { tier: '564x', url: 'synthetic-a' },
  sourceUrl: '', imageRevision: 0, widthVp: 180, heightVp: 220 });
image.resetImage(); const firstRevision = image.imageRevision;
image.completeImage(firstRevision, 1);
image.images = { tier: '564x', url: 'synthetic-a' }; image.resetImage();
assert.equal(image.imageRevision, firstRevision, 'equivalent snapshots retain the decoded node');
assert.equal(image.phase, 'loaded');
image.images = { tier: '736x', url: 'synthetic-b' }; image.resetImage();
assert.equal(image.imageRevision, firstRevision + 1, 'a changed selected source creates a new generation');
assert.equal(image.phase, 'loading');
// Exercise the real rendition selector and callbacks, including stale failures
// and unchanged snapshots arriving during/after recovery.
const candidates = { tier: '564x', url: 'full', '564x': {url:'full'}, '474x': {url:'smaller'}, '236x': {url:'smallest'} };
Object.assign(image, { images:candidates, sourceUrl:'full', requestedSourceUrl:'full', sourceTier:'564x',
  imageRevision:10, phase:'loading', recoveryAttempted:false });
const beforeErrors=errors.length, beforeLoaded=loaded;
image.failImage(10, 123);
assert.equal(image.sourceUrl,'smaller');assert.equal(image.imageRevision,11);
assert.equal(image.phase,'loading');assert.equal(errors.length,beforeErrors);
image.failImage(10, 123);assert.equal(image.imageRevision,11,'old source error cannot consume recovery');
image.resetImage();assert.equal(image.imageRevision,11,'snapshot refresh cannot restart the failed source');
image.completeImage(11,1);assert.equal(loaded,beforeLoaded+1);
image.resetImage();assert.equal(image.sourceUrl,'smaller','successful recovery survives equivalent snapshots');
Object.assign(image,{phase:'loading',imageRevision:12,recoveryAttempted:true});
image.failImage(12,456);image.failImage(12,456);
assert.equal(image.phase,'failed');assert.equal(errors.length,beforeErrors+1,'only terminal failure is reported once');
assert.equal(recovery(candidates,'564x','full'),'474x');
assert.equal(recovery({'474x':{url:'full'}},'564x','full'),'','same URL is never replayed');
assert.equal(recovery(candidates,'fallback','full'),'','unknown source is not rewritten');
const home = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
assert.match(home, /PinmonyCdnImage\(\{[\s\S]*?onDecoded: \(\) =>/);
assert.match(fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets', 'utf8'), /event\?\.loadingStatus === 1/);
assert.match(home, /session !== this\.home\.session \|\| pageKey !== this\.home\.pageKey/);
const prefetch = home.match(/  private uniquePrefetchImages\([\s\S]*?\r?\n  \}/)[0];
const Prefetch = vm.runInNewContext(ts.transpileModule('class Prefetch {' + prefetch + '} Prefetch;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const queue = new Prefetch();
Object.assign(queue, { firstImageSettled: true, paneActive: true, feedActive: true, imageLoadingActive: true,
  home: { pins: [{ imageUrl: 'card' }, { imageUrl: 'old' }] },
  recoveredSources: { old: 'recovered' }, prefetchedImageUrls: ['card', 'detail', 'detail', 'recovered', 'other', ''] });
assert.deepEqual(Array.from(queue.uniquePrefetchImages()), ['detail', 'other'],
  'prefetch excludes current card/recovery sources and duplicates while retaining distinct detail tiers');
console.log('Image callbacks: data-ready versus decoded, failure, source replacement, disposal and duplicate callbacks passed');
