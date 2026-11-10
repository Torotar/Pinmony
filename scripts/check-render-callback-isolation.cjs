const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const commits = require('./ui-commit-harness.cjs').createUiCommitHarness(ts);
function host(file, names) {
  const ast = ts.createSourceFile('host.ts', fs.readFileSync(file, 'utf8').replace(/\bstruct\b/g, 'class'), 99, true);
  const methods = [];
  function visit(n) {
    if (ts.isMethodDeclaration(n) && names.includes(n.name.getText(ast))) methods.push(n.getText(ast));
    ts.forEachChild(n, visit);
  }
  visit(ast); assert.equal(methods.length, names.length);
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {compilerOptions:{target:99}}).outputText);
  const h = new Host(); h.uiCommits = new commits.Queue(); return h;
}
const image = host('common_ui/src/main/ets/components/PinmonyCdnImage.ets', ['queueImageEvent']);
const events = [];
Object.assign(image, {visible:true, generation:1, settledGeneration:-1, auditImage(){},
  onDataReady:()=>events.push('data'), onDecoded:()=>events.push('decoded'), onFailure:()=>events.push('failed')});
image.queueImageEvent(1, 0); assert.equal(events.length, 0); commits.flush();
assert.deepEqual(events, ['data']);
image.queueImageEvent(1, 1); image.queueImageEvent(1, -1, 102013); commits.flush();
assert.deepEqual(events, ['data', 'decoded'], 'one terminal event per source generation');
image.generation = 2; image.queueImageEvent(2, 1); image.generation = 3; commits.flush();
assert.equal(events.length, 2, 'source replacement discards late decode');
image.queueImageEvent(3, 1); image.uiCommits.dispose(); commits.flush(); assert.equal(events.length, 2);
const inbox = host('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', ['queueRefreshState']);
Object.assign(inbox, {snapshot:{session:1}, inboxRefreshState:0});
inbox.queueRefreshState(1); inbox.queueRefreshState(2); assert.equal(inbox.inboxRefreshState, 0);
commits.flush(); assert.equal(inbox.inboxRefreshState, 2, 'latest refresh status wins');
inbox.queueRefreshState(3); inbox.snapshot.session = 2; commits.flush(); assert.equal(inbox.inboxRefreshState, 2);
const detail = host('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', ['onImageLayerChanged']);
let pin = 'a', owner = 'a', changes = 0;
Object.assign(detail, {heroVisible:true, displayedDetail:()=>({pinUrl:pin}), viewerOwner:()=>owner,
  commitImageLayerChange:()=>changes++});
detail.onImageLayerChanged(); assert.equal(changes, 0); commits.flush(); assert.equal(changes, 1);
detail.onImageLayerChanged(); pin = owner = 'b'; commits.flush(); assert.equal(changes, 1);
detail.onImageLayerChanged(); detail.heroVisible = false; commits.flush(); assert.equal(changes, 1);
detail.heroVisible = true; detail.onImageLayerChanged(); detail.uiCommits.dispose(); commits.flush(); assert.equal(changes, 1);
const shuffle = host('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', ['shuffleImageReady']);
let ready = 0;
Object.assign(shuffle, {heroVisible:true, displayedDetail:()=>({pinUrl:'a', imageUrl:'backdrop'}),
  shuffleSelectedImage:'photo-a', shuffleBackdrop:'backdrop', commitShuffleImageReady:()=>ready++});
shuffle.shuffleImageReady('backdrop', 'old-backdrop'); commits.flush(); assert.equal(ready, 0);
shuffle.shuffleImageReady('backdrop', 'backdrop'); assert.equal(ready, 0); commits.flush();
assert.equal(ready, 1); assert.equal(shuffle.shuffleReadyBackdrop, 'backdrop');
shuffle.shuffleImageReady('photo:a'); shuffle.shuffleSelectedImage = 'photo-b'; commits.flush(); assert.equal(ready, 1);
shuffle.shuffleImageReady('backdrop', 'backdrop'); shuffle.shuffleBackdrop = 'new-backdrop'; commits.flush(); assert.equal(ready, 1);
console.log('Render callback isolation: deferred image/refresh/viewer state, latest update, stale source/session/page and disposal passed');
