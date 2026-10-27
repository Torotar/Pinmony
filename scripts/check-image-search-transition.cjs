const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/components/PinmonyImageSearchView.ets', 'utf8');
const sf = ts.createSourceFile('search.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['beginTransition', 'closeTransition', 'runTransition', 'aboutToDisappear', 'photoWidth', 'photoHeight', 'photoX', 'photoY'];
const methods = [];
function visit(n) { if (ts.isMethodDeclaration(n) && names.includes(n.name.getText(sf))) methods.push(n.getText(sf)); ts.forEachChild(n, visit); }
visit(sf);
const timers = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: 99 }
}).outputText, { PinmonyRuntimeLog: {info(){}}, Curve: { EaseOut: 0 }, setTimeout: fn => { timers.push(fn); return timers.length; }, clearTimeout: () => {} });
const animations = []; let ready = 0, closed = 0;
const x = new Host();
Object.assign(x, { animatePhoto: true, alive: true, measured: true, decoded: false, started: false,
  widthValue: 360, heightValue: 720, imageWidth: 600, imageHeight: 800, originX: 18, originY: 200,
  originWidth: 324, originHeight: 432, closing: false, transitionVersion: 0, sheetVisible: false,
  onTransitionReady: () => ready++, onTransitionClosed: () => closed++, getUIContext: () => ({
    px2vp: n => n, getComponentUtils: () => ({ getRectangleById: () => ({ windowOffset: { x: 0, y: 100 } }) }),
    animateTo: (opts, fn) => { animations.push(opts); fn(); }
  }) });
x.beginTransition(); assert.equal(ready, 0, 'wait for decoded handoff');
x.decoded = true; x.beginTransition(); assert.equal(ready, 1); assert.equal(x.frameY, 100);
timers.shift()(); assert.equal(x.frameWidth, 324); assert.equal(x.frameY, 0); assert.equal(x.backdrop, 1);
assert.equal(x.sheetVisible, true, 'result sheet opens concurrently with photo flight');
assert.equal(animations.at(-1).duration, 240);
x.closing = true; x.closeTransition(); const oldClose = animations.at(-1);
assert.equal(x.frameY, 100); assert.equal(x.frameRadius, 18); assert.equal(x.backdrop, 0);
assert.equal(animations.at(-1).duration, 200);
x.closing = false; x.closeTransition(); oldClose.onFinish(); assert.equal(closed, 0, 'reopen cancels stale close');
animations.at(-1).onFinish(); assert.equal(x.sheetVisible, true); assert.equal(x.chrome, 1);
x.closing = true; x.closeTransition(); animations.at(-1).onFinish(); assert.equal(closed, 1);
x.runTransition(false); const late = animations.at(-1); x.aboutToDisappear(); late.onFinish();
assert.equal(closed, 1); assert.equal(x.alive, false);
const early = new Host(); Object.assign(early, { animatePhoto: true, alive: true, closing: true, started: false,
  onTransitionClosed: () => closed++ }); early.closeTransition(); assert.equal(closed, 2, 'back before decode cannot trap page');
console.log('Image search transition: decode handoff, window coordinates, sheet sequencing, reverse, rapid reopen, early back and stale callbacks passed');

const completed = source.match(/\.onComplete\(\(event\) => \{([\s\S]*?)\n        \}\)/);
assert(completed,'flight image completion handler');
for(const status of [0,1]) {
 const host={decoded:false,starts:0,beginTransition(){this.starts++;}};
 const callback=new Function('event','PinmonyRuntimeLog',ts.transpile(completed[1]));
 callback.call(host,{loadingStatus:status},{info(){}});
 assert(host.decoded);assert.equal(host.starts,1,'data-ready and render-ready both unblock transition');
}
console.log('Image search readiness: data-ready unblocks hidden flight without waiting for render passed');

const detailPage=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
assert.match(detailPage,/PinmonyVisualSearchView\(\{ pin: this.detail.pinUrl, imageUrl: this.detail.imageUrl \|\| this.detail.originalImageUrl/,'search entry must reuse the displayed image before requesting original size');
console.log('Visual search entry reuses displayed detail image passed');
