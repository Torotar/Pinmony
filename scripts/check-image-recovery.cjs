const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(file, names, globals = {}) {
  const source = fs.readFileSync(file, 'utf8');
  const methods = names.map(name => {
    const match = source.match(new RegExp('  (?:private )?' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
    assert(match, name); return match[0];
  });
  return vm.runInNewContext(ts.transpileModule('class Host { displayedDetail() { return this.detail; }' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { PinmonyRuntimeLog: { info() {}, warn() {} }, ...globals });
}
const Store = load('feature_home/src/main/ets/stores/PinmonyHomeStore.ets', ['recoverImage']);
const store = new Store();
store.recoverImage('https://evil.invalid/pin/1/', 'https://i.pinimg.com/a.jpg'); assert.equal(store.imageRecovery, undefined);
store.recoverImage('https://www.pinterest.com/pin/1/', 'https://i.pinimg.com/736x/success.jpg');
assert.equal(store.imageRecovery.revision, 1);
const Home = load('feature_home/src/main/ets/components/PinmonyHomePage.ets', ['onImageRecovery', 'retryImage', 'retryRecoveredImages']);
const home = new Home();
Object.assign(home, { home: { pins: [{ pinUrl: 'https://uk.pinterest.com/pin/1/', imageUrl: 'https://i.pinimg.com/236x/a.jpg' },
  { pinUrl: 'https://www.pinterest.com/pin/2/', imageUrl: 'https://i.pinimg.com/236x/b.jpg' }] },
  failedImages: ['https://i.pinimg.com/236x/a.jpg', 'https://i.pinimg.com/236x/b.jpg'],
  recoveredSources: {}, recoveredRevisions: {}, lastImageRecovery: 0, imageRecovery: store.imageRecovery });
home.onImageRecovery();
assert.deepEqual(Array.from(home.failedImages), ['https://i.pinimg.com/236x/b.jpg'], 'only the recovered Pin error is cleared');
assert.equal(home.recoveredSources['https://i.pinimg.com/236x/a.jpg'], store.imageRecovery.imageUrl, 'a working detail URL replaces the failed thumbnail source');
assert.equal(home.recoveredRevisions['https://i.pinimg.com/236x/a.jpg'], 1);
home.onImageRecovery(); assert.equal(home.recoveredRevisions['https://i.pinimg.com/236x/a.jpg'], 1, 'a success event is consumed once');
home.imageRecovery = undefined; home.onImageRecovery(); assert.equal(Object.keys(home.recoveredSources).length, 0);
home.offlinePreview = true; home.retryImage('https://i.pinimg.com/236x/b.jpg');
assert.equal(home.failedImages.length, 1, 'offline preview does not send image retries');
home.offlinePreview = false; home.retryImage('https://i.pinimg.com/236x/b.jpg');
assert.equal(home.failedImages.length, 0);
assert.equal(home.recoveredRevisions['https://i.pinimg.com/236x/b.jpg'], 1);
home.retryImage('https://i.pinimg.com/236x/b.jpg');
assert.equal(home.recoveredRevisions['https://i.pinimg.com/236x/b.jpg'], 1, 'duplicate retry does not replace a loading node');
Object.assign(home, { imageNetworkVisible: true, imageNetworkOnline: true, imageRecoveryPending: true,
  imageRecoveryAttempts: new Set(), feedActive: false, actionsReady: true, loading: false, refreshing: false,
  visibleFirst: 0, visibleLast: 0, failedImages: home.home.pins.map(pin => pin.imageUrl) });
home.retryRecoveredImages(); assert.equal(home.failedImages.length, 2, 'hidden feed cannot auto retry');
home.feedActive = true; home.retryRecoveredImages();
assert.deepEqual(Array.from(home.failedImages), ['https://i.pinimg.com/236x/b.jpg'], 'only visible failures retry');
home.failedImages.push(home.home.pins[0].imageUrl); home.retryRecoveredImages();
assert.equal(home.failedImages.length, 2, 'failed automatic retry cannot loop');
home.imageNetworkVisible = false; home.visibleLast = 1; home.retryRecoveredImages();
assert.equal(home.failedImages.length, 2, 'disposed page cannot issue retries');
home.imageNetworkVisible = true; home.imageRecoveryAttempts = new Set(); home.visibleFirst = 0; home.visibleLast = 19;
home.home.pins = Array.from({ length: 20 }, (_, i) => ({ imageUrl: 'https://i.pinimg.com/' + i + '.jpg' }));
home.failedImages = home.home.pins.map(pin => pin.imageUrl); home.retryRecoveredImages();
assert.equal(home.failedImages.length, 8, 'one network recovery retries at most twelve images');
const callbacks = {}; let online = false, retries = 0, unregistered = 0;
const monitor = { on: (name, fn) => callbacks[name] = fn, register: fn => fn(), unregister: fn => { unregistered++; fn(); } };
const NetworkHome = load('feature_home/src/main/ets/components/PinmonyHomePage.ets', ['watchImageNetwork', 'aboutToDisappear'], {
  connection: { hasDefaultNetSync: () => online, createNetConnection: () => monitor }
});
const watched = new NetworkHome(); watched.imageRecoveryAttempts = new Set(); watched.retryRecoveredImages = () => retries++;
watched.watchImageNetwork(); online = true; callbacks.netAvailable();
assert.equal(retries, 1); callbacks.netAvailable(); assert.equal(retries, 1, 'duplicate available events cannot rearm retries');
watched.aboutToDisappear(); callbacks.netAvailable(); assert.equal(retries, 1); assert.equal(unregistered, 1);
const Page = load('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', ['retryHeroImage', 'heroRenderKey']);
const page = new Page(); let reads = 0;
Object.assign(page, { heroVisible: true, detail: { imageUrl: 'https://i.pinimg.com/a.jpg', pinUrl: 'https://www.pinterest.com/pin/1/' },
  heroRenderRevision: 0, onContentRetry: () => reads++ });
const key = page.heroRenderKey(page.detail.imageUrl, page.detail.pinUrl);
page.retryHeroImage(key); assert.equal(reads, 1); assert.equal(page.heroRenderRevision, 1);
page.retryHeroImage(key); assert.equal(reads, 1, 'old retry control cannot restart a new generation');
page.heroVisible = false; page.retryHeroImage(page.heroRenderKey(page.detail.imageUrl, page.detail.pinUrl)); assert.equal(reads, 1);
const source = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets', 'utf8');
assert(source.includes('imageRevision !== (this.recoveredRevisions[pin.imageUrl] || 0)'), 'old thumbnail errors are rejected');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const callback = index.slice(index.indexOf('onImageLoaded: (pinUrl:'), index.indexOf('onImageLoaded: (pinUrl:') + 850);
assert(callback.indexOf('renderIdentity !==') < callback.indexOf('recoverImage(pinUrl, imageUrl)'), 'recovery only follows a current render confirmation');
console.log('Image recovery: fresh detail read/revision, decoded-success handoff, matching Pin/tier recovery, stale callback guard and cleanup passed');
