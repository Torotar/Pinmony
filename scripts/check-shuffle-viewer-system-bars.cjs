const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const ast = ts.createSourceFile('detail.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['syncShuffleStatusBar', 'onShuffleStatusPresentedChanged', 'onShuffleStatusSelectionChanged',
  'onShuffleStatusDetailChanged', 'shuffleViewerVisible', 'aboutToDisappear'];
const methods = [];
function visit(n) {
  if (ts.isMethodDeclaration(n) && names.includes(n.name.getText(ast))) methods.push(n.getText(ast));
  ts.forEachChild(n, visit);
}
visit(ast);
assert.equal(methods.length, names.length, 'collage must reuse layout-safe status bar ownership');
let serial = 0;
const owners = new Set(), calls = [];
const bars = {
  acquire(context) { const id = ++serial; owners.add(id); calls.push(['hide', id, context]); return id; },
  release(id, context) { assert(owners.delete(id), 'lease released once'); calls.push(['restore', id, context]); }
};
const Host = vm.runInNewContext(ts.transpileModule(`class Host { ${methods.join('\n')} } Host`, {
  compilerOptions: { target: 99 }
}).outputText, { PinmonyViewerSystemBars: bars, setTimeout() {}, clearTimeout() {} });
const context = {};
function fixture() {
  return Object.assign(new Host(), { heroVisible: true, shuffleSelectedImage: 'photo', shuffleFullDetail: false,
    shuffleViewerPresented: false, shuffleFlightClosing: false, shuffleBackdropOpacity: 0,
    shuffleStatusBarOwner: 0, shuffleStatusBarContext: undefined, getUIContext: () => ({ getHostContext: () => context }),
    onShuffleViewerPresentedChanged() {}, onShuffleSelectionChanged() {}, onPinChanged() {},
    uiCommits: { dispose() {} }, viewerOwner: () => 'viewer', shuffleFlightRevision: 0,
    shuffleFlightActive: false, shuffleFlightTimer: -1, shuffleHitMasks: new Map() });
}
const h = fixture();
h.syncShuffleStatusBar(); assert.equal(calls.length, 0, 'preparing a photo does not cover the time bar early');
h.shuffleViewerPresented = true; h.onShuffleStatusPresentedChanged();
assert.equal(calls.length, 0, 'source frame preparation retains the original chrome');
h.shuffleBackdropOpacity = 1; h.syncShuffleStatusBar();
assert.equal(calls.at(-1)[0], 'hide'); const first = h.shuffleStatusBarOwner;
h.syncShuffleStatusBar(); assert.equal(h.shuffleStatusBarOwner, first); assert.equal(owners.size, 1);
h.shuffleFlightClosing = true; h.syncShuffleStatusBar();
assert.equal(calls.at(-1)[0], 'restore', 'return start restores chrome before the photo reaches its source');
assert.equal(h.shuffleViewerPresented, true, 'return restoration does not unmount the flight');
h.shuffleBackdropOpacity = 0; h.shuffleFlightClosing = false; h.syncShuffleStatusBar();
assert.equal(owners.size, 0, 'return completion cannot briefly re-hide the bar');
h.shuffleBackdropOpacity = 1; h.syncShuffleStatusBar(); assert.equal(owners.size, 1);
h.shuffleFullDetail = true; h.onShuffleStatusDetailChanged(); assert.equal(owners.size, 0);
h.shuffleFullDetail = false; h.onShuffleStatusDetailChanged(); assert.equal(owners.size, 1);
h.shuffleSelectedImage = ''; h.onShuffleStatusSelectionChanged(); assert.equal(owners.size, 0);
h.shuffleSelectedImage = 'next'; h.syncShuffleStatusBar(); assert.equal(owners.size, 1);
h.shuffleViewerPresented = false; h.onShuffleStatusPresentedChanged(); assert.equal(owners.size, 0, 'cancel/failure releases ownership');
h.shuffleViewerPresented = true; h.onShuffleStatusPresentedChanged(); assert.equal(owners.size, 1);
h.aboutToDisappear(); assert.equal(owners.size, 0, 'page disposal restores the time bar');
h.syncShuffleStatusBar(); assert.equal(owners.size, 0, 'late sync on a disposed page cannot hide the bar');
const unavailable = fixture(); unavailable.shuffleViewerPresented = true; unavailable.shuffleBackdropOpacity = 1;
unavailable.getUIContext = () => ({ getHostContext: () => undefined });
unavailable.syncShuffleStatusBar(); assert.equal(unavailable.shuffleStatusBarOwner, 0);
for (const [field, watcher] of [
  ['shuffleSelectedImage', 'onShuffleStatusSelectionChanged'], ['shuffleFullDetail', 'onShuffleStatusDetailChanged'],
  ['shuffleViewerPresented', 'onShuffleStatusPresentedChanged'], ['shuffleFlightClosing', 'syncShuffleStatusBar'],
  ['shuffleBackdropOpacity', 'syncShuffleStatusBar']
]) assert(new RegExp(`@Watch\\('${watcher}'\\)[^\\n]*\\b${field}\\b`).test(source), `wire ${field} into status ownership`);
assert(!source.includes('setSpecificSystemBarEnabled('), 'collage never changes layout safe areas');
console.log('Collage status bar: entry/return start, cancellation, full detail, repeat open, disposal, missing context and watcher wiring passed');
