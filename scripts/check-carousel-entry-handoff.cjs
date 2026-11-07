const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const path = 'feature_pin/src/main/ets/components/PinmonyCarouselView.ets';
const source = fs.readFileSync(path, 'utf8');
const sf = ts.createSourceFile('carousel.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['aboutToAppear', 'aboutToDisappear', 'firstImageKey', 'settleFirstImage', 'onCarouselChanged'];
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(sf))) methods.push(node.getText(sf));
  ts.forEachChild(node, visit);
}
visit(sf);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;',
  { compilerOptions: { target: 99 } }).outputText);
const first = { id: 'slot-1', imageUrl: 'https://i.pinimg.com/first.jpg' };
const second = { id: 'slot-2', imageUrl: 'https://i.pinimg.com/second.jpg' };
const host = new Host(), events = [];
Object.assign(host, { carousel: { pinId: 'pin-1', items: [first, second] }, revision: 0,
  firstRenderedKey: '', failed: [], controller: { changeIndex() {} }, onFirstImageSettled: failed => events.push(failed) });
host.aboutToAppear();
host.settleFirstImage(first, 0, 0);
assert.equal(host.firstRenderedKey, '', 'data-ready must retain the cover');
assert.equal(events.length, 0, 'data-ready must not release the detail image gate');
host.settleFirstImage(second, 1, 1);
assert.equal(events.length, 0, 'prefetched later slots cannot release the first image gate');
host.settleFirstImage(first, 0, 1);
assert.equal(host.firstRenderedKey, host.firstImageKey(first));
assert.deepEqual(events, [false]);
host.revision++;
assert.notEqual(host.firstRenderedKey, host.firstImageKey(first), 'retry must restore the preview until a new frame');
host.settleFirstImage(first, 0, -1, true);
assert.deepEqual(events, [false, true], 'real errors release loading without pretending success');
host.carousel = { pinId: 'pin-1', items: [{ ...first, imageUrl: 'https://i.pinimg.com/updated.jpg' }, second] };
host.settleFirstImage(first, 0, 1);
assert.equal(events.length, 2, 'late old source cannot confirm a replacement image');
host.carousel = { pinId: 'pin-2', items: [second] };
host.onCarouselChanged();
assert.equal(host.firstRenderedKey, '', 'changing Pin clears the readiness state');
host.aboutToDisappear();
host.settleFirstImage(second, 0, 1);
assert.equal(events.length, 2, 'departed carousel cannot update the detail');
assert(source.includes('Image(this.previewUrl)') && source.includes('.syncLoad(index === 0)'), 'first slot reuses the decoded cover synchronously');
assert.equal((source.match(/event\?\.loadingStatus \?\? -1/g) || []).length, 2, 'both carousel modes gate on actual rendered status');
const parent = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
assert(parent.includes('previewUrl: this.displayedDetail().imageUrl'), 'detail passes its displayed cover into the carousel');
const insetExpression = parent.match(/bottomInset: (!this\.displayedDetail\(\)\.carousel\?\.freeScroll[\s\S]*?\? 28 : 0), closing:/)[1];
const inset = new Function('return ' + insetExpression);
assert.equal(inset.call({ displayedDetail: () => ({ mediaKind: 'carousel' }) }), 28, 'pending carousel reserves the same flight inset as loaded slots');
assert.equal(inset.call({ displayedDetail: () => ({ carousel: { items: [first] } }) }), 28);
assert.equal(inset.call({ displayedDetail: () => ({ carousel: { freeScroll: true } }) }), 0, 'free-scrolling product galleries have no indicator inset');
assert.equal(inset.call({ displayedDetail: () => ({}) }), 0, 'single image entry geometry is unchanged');
const video = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyVideoPlayer.ets', 'utf8');
const singleVideo = parent.slice(parent.indexOf('} else if (this.displayedDetail().video && this.displayedDetail().isVideo)'),
  parent.indexOf('} else if (this.displayedDetail().isVideo)'));
assert(singleVideo.includes('entryPreview: this.displayedDetail().imageUrl'),
  'single-video entry must reuse its decoded hero just like the first carousel video');
assert(singleVideo.includes('active: this.videoActive') && singleVideo.includes('sessionReady: this.actionsReady || this.readsReady'),
  'single-video entry preview preserves playback activation and session gates');
assert(source.includes("entryPreview: index === 0 ? this.previewUrl : ''"),
  'only the entry slot receives the decoded cover, never adjacent videos');
const previewLayer = video.match(/if \(!this\.state\.rendered\) \{([\s\S]*?)this\.posterImage\(this\.poster\)/)[1];
assert(previewLayer.includes("Image(this.entryPreview).width('100%').height('100%').objectFit(ImageFit.Contain).syncLoad(true)"),
  'entry preview is synchronously reused inside the existing poster layer until a video frame renders');
assert(previewLayer.includes('.hitTestBehavior(HitTestMode.None)'), 'preview cannot intercept play or swipe gestures');
assert(!previewLayer.includes('onComplete') && !previewLayer.includes('onError'),
  'preview decoding cannot release real poster readiness or control playback');
assert(video.indexOf('XComponent({') < video.indexOf('Image(this.entryPreview)') &&
  video.indexOf('Image(this.entryPreview)') < video.indexOf("if (this.state.phase === 'playing')"),
  'preview covers only the native surface, retaining controls and visibility gates');
assert(!video.includes('.opacity(') && !video.includes('.visibility('),
  'initial poster handoff must not hide the player or change its activation');
const posterMethod = video.slice(video.indexOf('  private posterImage('));
const posterComplete = posterMethod.match(/\.onComplete\(\(event\) => \{([^\n]*)\}\)/)[1];
const posterEvents = [], poster = { poster: 'poster', onPosterSettled: failed => posterEvents.push(failed) };
const complete = new Function('event', 'url', posterComplete);
complete.call(poster, { loadingStatus: 0 }, 'poster');
assert.equal(posterEvents.length, 0, 'mixed-carousel poster data-ready must not release entry');
complete.call(poster, { loadingStatus: 1 }, 'old-poster');
assert.equal(posterEvents.length, 0);
complete.call(poster, { loadingStatus: 1 }, 'poster');
assert.deepEqual(posterEvents, [false], 'mixed-carousel poster waits for its actual rendered frame');
console.log('Carousel entry: decoded cover handoff, render-only readiness, late source/Pin/disposal guards, retry and both carousel modes passed');
