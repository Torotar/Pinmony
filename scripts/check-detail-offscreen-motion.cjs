const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailEntryMotion.ets', 'utf8');
const ast = ts.createSourceFile('motion.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['aboutToAppear', 'aboutToDisappear', 'openWithoutPhoto', 'target', 'heroVisible', 'begin', 'imageComplete', 'closeChanged', 'move'];
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast);
const geometry = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets', 'utf8').replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
const imageContainRect = vm.runInNewContext(ts.transpileModule(geometry + ';imageContainRect;', { compilerOptions: { target: 99 } }).outputText);
const timers = new Map(); let nextTimer = 0;
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', { compilerOptions: { target: 99 } }).outputText, {
  imageContainRect, Curve: { EaseOut: 0 }, PinmonyRuntimeLog: { info() {} },
  setTimeout(fn, delay) { const id = ++nextTimer; timers.set(id, { fn, delay }); return id; },
  clearTimeout(id) { timers.delete(id); }
});
function fixture({ closing = false, offset = 0, restored = 0, top = 120, decoded = false } = {}) {
  const state = { offset, top, nativeAvailable: true, events: [], animations: [] };
  const host = new Host();
  Object.assign(host, { photo: { x: 20, y: 200, width: 160, height: 240 }, targetId: 'target', rootId: 'root',
    imageWidth: 400, imageHeight: 600, bottomInset: 28, targetRadius: 18, restoredOffset: restored,
    mediaContentTop: 120, visibleTopInset: 104, currentScrollOffset: () => state.offset,
    closing, decoded, rendered: decoded, measured: true, started: false, showing: false, version: 0,
    sourcePrepared: false, preparationExpired: false, layoutAttempts: 0,
    frame: { x: 0, y: 0, width: 1, height: 1 },
    onReveal: (back, page) => state.events.push({ back, page }),
    onOpened: () => state.events.push('opened'), onClosed: () => state.events.push('closed'),
    getUIContext: () => ({ px2vp: n => n, getComponentUtils: () => ({ getRectangleById: id => {
      if (id === 'root') return { windowOffset: { x: 0, y: 0 }, size: { width: 360, height: 800 } };
      if (!state.nativeAvailable) throw Error('recycled header');
      return { windowOffset: { x: 18, y: state.top }, size: { width: 324, height: 514 } };
    } }), animateTo: (options, fn) => { state.animations.push(options); fn(); } })
  });
  host.aboutToAppear(); return { host, state };
}
function tick(delay) {
  for (const [id, timer] of [...timers]) if (timer.delay === delay && timers.delete(id)) timer.fn();
}
for (const closing of [false, true]) {
  const { host, state } = fixture({ closing, offset: 900 });
  assert.equal(host.heroVisible(), false, 'actual offset rejects a cached header rectangle that looks visible');
  host.begin(); assert.equal(host.showing, false, 'offscreen photo cannot flash while waiting for decode');
  tick(32); assert.equal(state.events[0].page, true); assert.equal(state.events[0].back, closing);
  assert.equal(state.animations[0].duration, closing ? 200 : 240);
  assert.equal(host.showing, false); state.animations[0].onFinish();
  assert.equal(state.events.at(-1), closing ? 'closed' : 'opened'); host.aboutToDisappear();
}
const queued = fixture({ restored: 900 });
assert.equal(queued.host.heroVisible(), false, 'opening uses intended offset before restoration commits');
queued.host.begin(); tick(32); assert.equal(queued.state.events[0].page, true); queued.host.aboutToDisappear();
for (const offset of [0, 28, 160]) {
  const { host, state } = fixture({ closing: true, restored: 900, offset, decoded: true });
  assert.equal(host.heroVisible(), true, 'return uses current offset and retains partially visible photo');
  host.begin(); tick(32); assert.equal(state.events[0].page, false); host.aboutToDisappear();
}
const lateScroll = fixture({ decoded: true });
lateScroll.host.begin(); lateScroll.state.offset = 900; tick(32);
assert.equal(lateScroll.state.events[0].page, true, 'visibility rechecked immediately before movement');
assert.equal(lateScroll.host.showing, false); lateScroll.host.aboutToDisappear();
for (const closing of [false, true]) {
  const { host, state } = fixture({ closing, offset: 900 }); state.nativeAvailable = false;
  host.begin(); for (let i = 0; i < 12; i++) tick(16);
  assert.equal(state.events[0].page, true, 'recycled target still animates page after bounded measurement retries');
  state.animations[0].onFinish(); assert.equal(state.events.at(-1), closing ? 'closed' : 'opened'); host.aboutToDisappear();
}
const dead = fixture({ offset: 900 }); dead.host.begin(); dead.host.aboutToDisappear(); tick(32);
assert.equal(dead.state.events.length, 0, 'disposed pending movement cannot reveal another page');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
assert(page.includes('currentScrollOffset: (): number => this.detailScroller.offset()?.yOffset ?? this.initialScrollOffset'));
assert(page.includes('mediaContentTop: this.titleContentInset() + 16, visibleTopInset: this.titleContentInset()'));
console.log('Detail offscreen motion: stale WaterFlow geometry, pending restore, entry/return without decode, current top/partial visibility, late scroll, recycled target and disposal passed');
