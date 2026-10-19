const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/components/SmartImage.ets', 'utf8');
const methods = ['completeImage', 'failImage', 'traceImage', 'resetImage', 'displayHeightPx'].map(name => {
  const match = source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
  assert(match); return match[0];
});
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { pickCoverImageTier: images => images.tier,
  pickCoverImageUrl: images => images.url, currentDensityPixels: () => 3 });
let loaded = 0, errors = [];
const image = new Host();
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
const home = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets', 'utf8');
assert.match(home, /event\?\.loadingStatus !== 1/);
assert.match(home, /session !== this\.home\.session \|\| pageKey !== this\.home\.pageKey/);
const prefetch = home.match(/  private uniquePrefetchImages\([\s\S]*?\r?\n  \}/)[0];
const Prefetch = vm.runInNewContext(ts.transpileModule('class Prefetch {' + prefetch + '} Prefetch;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const queue = new Prefetch();
Object.assign(queue, { home: { pins: [{ imageUrl: 'card' }, { imageUrl: 'old' }] },
  recoveredSources: { old: 'recovered' }, prefetchedImageUrls: ['card', 'detail', 'detail', 'recovered', 'other', ''] });
assert.deepEqual(Array.from(queue.uniquePrefetchImages()), ['detail', 'other'],
  'prefetch excludes current card/recovery sources and duplicates while retaining distinct detail tiers');
console.log('Image callbacks: data-ready versus decoded, failure, source replacement, disposal and duplicate callbacks passed');
