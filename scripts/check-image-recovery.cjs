const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(file, names) {
  const source = fs.readFileSync(file, 'utf8');
  const methods = names.map(name => {
    const match = source.match(new RegExp('  (?:private )?' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
    assert(match, name); return match[0];
  });
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, {});
}
const Store = load('feature_home/src/main/ets/stores/PinmonyHomeStore.ets', ['recoverImage']);
const store = new Store();
store.recoverImage('https://evil.invalid/pin/1/', 'https://i.pinimg.com/a.jpg'); assert.equal(store.imageRecovery, undefined);
store.recoverImage('https://www.pinterest.com/pin/1/', 'https://i.pinimg.com/736x/success.jpg');
assert.equal(store.imageRecovery.revision, 1);
const Home = load('feature_home/src/main/ets/components/PinmonyHomePage.ets', ['onImageRecovery']);
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
