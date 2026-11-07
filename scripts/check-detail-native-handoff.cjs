const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function source(path) { return fs.readFileSync(path, 'utf8'); }
function host(path, names, globals = {}) {
  const file = ts.createSourceFile(path, source(path).replace(/\bstruct\b/g, 'class'), 99, true);
  const methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(file))) methods.push(node.getText(file));
    ts.forEachChild(node, visit);
  }
  visit(file);
  assert.equal(methods.length, names.length, 'execute every requested production method');
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;',
    { compilerOptions: { target: 99 } }).outputText, globals);
}
const motionPath = 'feature_pin/src/main/ets/components/PinmonyDetailEntryMotion.ets';
let time = 0, sequence = 0;
const timers = new Map(), animations = [], events = [];
const Motion = host(motionPath, ['aboutToAppear', 'aboutToDisappear', 'openWithoutPhoto',
  'begin', 'imageComplete', 'closeChanged', 'move'], {
  PinmonyRuntimeLog: { info() {} }, Curve: { EaseOut: 0 },
  setTimeout(fn, delay) { const id = ++sequence; timers.set(id, { at: time + delay, fn }); return id; },
  clearTimeout(id) { timers.delete(id); }
});
function advance(ms) {
  const end = time + ms;
  while (true) {
    const next = [...timers].filter(([, timer]) => timer.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
    if (!next) break;
    timers.delete(next[0]); time = next[1].at; next[1].fn();
  }
  time = end;
}
function fixture() {
  timers.clear(); animations.length = 0; events.length = 0;
  const node = new Motion();
  Object.assign(node, { alive: false, started: false, decoded: false, rendered: false, measured: true,
    preparationExpired: false, closing: false, version: 0, layoutAttempts: 0, restoredOffset: 0,
    photo: { returnPageOnly: false }, source: { x: 10 }, frame: {},
    target: () => ({ x: 100 }), heroVisible: () => true,
    onReveal: (closing, page) => events.push({ closing, page }),
    onOpened: () => events.push('opened'), onClosed: () => events.push('closed'),
    getUIContext: () => ({ animateTo(options, update) { animations.push(options); update(); } }) });
  node.aboutToAppear(); return node;
}
const cold = fixture(); cold.begin(); advance(79);
assert.equal(cold.started, false);
advance(1); assert.equal(cold.started, true, 'cold image stops gating entry at the preview deadline');
advance(32); assert.equal(events[0].page, true); assert.equal(animations[0].duration, 240);
const count = animations.length; cold.imageComplete(1);
assert.equal(animations.length, count, 'late image cannot restart the entry');
animations[0].onFinish(); assert.equal(events.at(-1), 'opened');
const warm = fixture(); warm.imageComplete(0); assert.equal(warm.started, false, 'data alone cannot fly');
warm.imageComplete(1); assert.equal(warm.started, true);
advance(32); assert.equal(events[0].page, false, 'drawable native preview retains photo motion');
advance(80); assert.equal(warm.preparationExpired, false, 'successful start cancels preparation deadline');
animations[0].onFinish(); warm.closing = true; warm.closeChanged();
assert.equal(animations.at(-1).duration, 200); animations.at(-1).onFinish(); assert.equal(events.at(-1), 'closed');
const pageOnly = fixture(); pageOnly.photo.returnPageOnly = true; pageOnly.begin();
assert.equal(pageOnly.started, true, 'page-only entry never waits for an invisible image');
advance(32); assert.equal(events[0].page, true);
const failed = fixture(); failed.openWithoutPhoto(); advance(32);
assert.equal(events[0].page, true, 'preview failure uses the same page animation');
const early = fixture(); early.closing = true; early.closeChanged(); advance(200);
assert.deepEqual(events, ['closed'], 'early back cancels pending preparation and cannot reopen detail');
const disposed = fixture(); disposed.aboutToDisappear(); advance(200); disposed.imageComplete(1);
assert.equal(events.length, 0, 'disposed page ignores deadline and image callbacks');
const interrupted = fixture(); interrupted.imageComplete(1); advance(32);
const staleFinish = animations[0].onFinish; interrupted.aboutToDisappear(); staleFinish();
assert(!events.includes('opened'), 'departed animation cannot reveal a replacement Pin');

const Page = host('feature_pin/src/main/ets/components/PinmonyDetailPage.ets',
  ['heroImageSources', 'heroRenderKey', 'completeHeroSource', 'notifyImageLoaded']);
const page = new Page(), loaded = [];
Object.assign(page, { heroVisible: true, heroRenderRevision: 0, detail: { pinUrl: 'pin', imageUrl: 'full' },
  entryPhoto: { pinUrl: 'pin', imageUrl: 'visible-preview' }, displayedDetail() { return this.detail; },
  onImageLoaded: (...args) => loaded.push(args) });
let sources = page.heroImageSources('full', 'pin');
assert.equal(sources.length, 2, 'API upgrade retains even an unfinished native preview');
const preview = sources[0], full = sources[1];
page.completeHeroSource(preview, 'other', preview.url); assert.equal(page.decodedHeroSource, undefined);
page.completeHeroSource(preview, 'pin', preview.url);
assert.equal(page.decodedHeroSource.key, preview.key); assert.equal(loaded.length, 0, 'preview does not fake full readiness');
assert.equal(page.heroImageSources('full', 'pin')[0].key, preview.key, 'ready preview node stays mounted');
page.completeHeroSource(full, 'pin', full.url);
assert.equal(page.heroImageSources('full', 'pin').length, 1); assert.equal(loaded.length, 1);
page.completeHeroSource(preview, 'pin', preview.url);
assert.equal(page.decodedHeroSource.key, full.key, 'late preview cannot replace ready full image');
page.heroRenderRevision++; page.completeHeroSource(full, 'pin', full.url); assert.equal(loaded.length, 1);
page.heroVisible = false; page.completeHeroSource(preview, 'pin', preview.url); assert.equal(loaded.length, 1);
assert.equal(page.heroImageSources('other-image', 'other-pin').length, 1, 'no preview crosses Pin identity');

const Index = host('entry/src/main/ets/pages/Index.ets', ['openHomePin']);
async function checkHome() {
  const node = new Index(); const calls = [];
  Object.assign(node, { authStatus: 'authenticated', businessSuspended: false, activeTab: 0,
    homePresentationPageKey: () => 'home', retainedHomeRootPageKey: () => 'home',
    homeStore: { homeForPresentation: () => ({ pins: [{ id: '1', pinUrl: 'pin', imageUrl: 'old', imageWidth: 400, imageHeight: 500 }] }) },
    homeController: { openHomePin: async id => calls.push(id) },
    getUIContext: () => ({ px2vp: n => n / 2, getComponentUtils: () => ({ getRectangleById: () =>
      ({ size: { width: 300, height: 400 }, windowOffset: { x: 20, y: 100 } }) }) }) });
  await node.openHomePin('1', 'recovered');
  assert.equal(node.homeEntryPhoto.imageUrl, 'recovered'); assert.equal(node.homeEntryPhoto.imageHeight, 500);
  assert.equal(calls.length, 1, 'actual cover capture preserves the original business action');
  await node.openHomePin('1'); assert.equal(node.homeEntryPhoto.imageUrl, 'old', 'existing callers remain compatible');
  node.businessSuspended = true; await node.openHomePin('1', 'stale'); assert.equal(node.homeEntryPhoto, undefined);
}
for (const file of [motionPath, 'feature_pin/src/main/ets/components/PinmonyDetailHero.ets'])
  assert.match(source(file), /PinmonyCdnImage\(\{[^\n]+useSharedDecode: false/, 'entry and hero use native cache');
assert.match(source('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets'), /this\.onPin\(pin\.id, this\.recoveredSources\[pin\.imageUrl\] \|\| pin\.imageUrl\)/);
assert.match(source('feature_home/src/main/ets/components/PinmonyHomePage.ets'), /onPin: this\.onPin/);
assert.match(source('entry/src/main/ets/components/PinmonyHomeRootContent.ets'), /view\.openHomePin\(id, imageUrl\)/);
assert.match(source('entry/src/main/ets/components/PinmonyHomeRootContent.ets'), /openHomePin: \(id: string, imageUrl\?: string\)/, 'root view contract carries the actual cover');
checkHome().then(() => console.log('Native detail handoff: bounded preparation, real render, late callbacks, early back, source upgrade and recovered home cover passed'));
