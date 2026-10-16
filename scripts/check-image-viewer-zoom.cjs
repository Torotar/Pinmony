const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyImageViewer.ets', 'utf8');
const methods = source.slice(source.indexOf('  private closeViewer()'), source.indexOf('  @Builder'));
const scope = { Curve: { EaseInOut: 'ease-in-out' }, TouchType: { Down: 0, Up: 1, Move: 2 } };
const motion = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageMotion.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: motion });
Object.assign(scope, motion);
vm.runInNewContext(ts.transpileModule('class Viewer {' + methods + '} globalThis.Viewer = Viewer;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, scope);
const changes = [], view = new scope.Viewer();
let closed = 0;
Object.assign(view, { scaleValue: 1, dx: 0, dy: 0, viewportWidth: 360, viewportHeight: 720,
  detail: { imageWidth: 360, imageHeight: 720 }, controls: true, onControlsChange: visible => changes.push(visible) });
view.motionVersion = 0;
view.onClose = () => closed++;
view.getUIContext = () => ({ animateTo(options, change) { assert.equal(options.duration, 240); change(); } });
view.toggleZoom(); assert.equal(view.scaleValue, 2.4); assert.equal(view.dx, 0); assert.equal(view.dy, 0);
view.toggleZoom();
view.toggleZoom(90, 180);
assert.equal(view.scaleValue, 2.4);
assert(Math.abs(view.dx - 126) < 1e-8 && Math.abs(view.dy - 252) < 1e-8);
assert(Math.abs((90 - 180) * view.scaleValue + view.dx - (90 - 180)) < 1e-8, 'tapped image point stays under the finger');
view.toggleZoom(90, 180); assert.equal(view.dx, 0); assert.equal(view.dy, 0);
assert.equal(changes.length, 0, 'double tap does not hide the title controls');
view.scaleValue = 4; view.dx = 100; view.dy = -100;
view.toggleZoom(); assert.equal(view.scaleValue, 1); assert.equal(view.dx, 0); assert.equal(view.dy, 0);
assert.equal(closed, 0, 'double tap does not exit the viewer');
view.closeViewer(); assert.deepEqual(changes, []); assert.equal(closed, 1); assert.equal(view.scaleValue, 1);
view.trackTouch({ type: 0, touches: [{}] });
view.trackTouch({ type: 0, touches: [{}, {}] });
view.trackTouch({ type: 1, touches: [{}] });
view.closeViewer(); view.toggleZoom();
assert.equal(closed, 1, 'lifting one finger after pinch cannot trigger single-tap exit');
assert.equal(view.scaleValue, 1, 'a multi-touch sequence cannot become a double tap');
view.trackTouch({ type: 0, touches: [{}] });
view.trackTouch({ type: 1, touches: [{}] });
view.closeViewer(); assert.equal(closed, 2, 'a new deliberate single tap still exits');
for (const [x, y] of [[30,0], [-30,0], [0,30], [0,-30]]) {
  view.trackTouch({ type: 0, touches: [{ x: 100, y: 100 }] });
  view.trackTouch({ type: 2, touches: [{ x: 100 + x, y: 100 + y }] });
  view.trackTouch({ type: 1, touches: [{ x: 100, y: 100 }] });
  view.closeViewer();
  assert.equal(closed, 2, 'a drag stays blocked even after returning to its starting point');
}
view.trackTouch({ type: 0, touches: [{ x: 100, y: 100 }] });
view.trackTouch({ type: 1, touches: [{ x: 102, y: 102 }] });
view.closeViewer(); assert.equal(closed, 3, 'small tap jitter still permits exit');
assert.equal(motion.imageFling(100, 0).seconds, 0, 'a slow release does not drift');
assert.equal(motion.imageFling(NaN, Infinity).seconds, 0);
for (const [speed, drag] of [[1000, .01], [4000, .02], [6000, .03], [12000, .03]]) {
  const fling = motion.imageFling(speed, 0);
  assert.equal(fling.x, speed, 'fast flick velocity is not artificially truncated');
  assert(Math.abs(fling.decay + Math.log(drag)) < 1e-12);
  assert(Math.abs(motion.imageFlingDistance(speed, fling.decay, 1) - speed * (1 - drag) / -Math.log(drag)) < 1e-8);
  assert(fling.seconds <= 3 && fling.seconds > 0);
}
assert(motion.imageFlingDistance(6000, motion.imageFling(6000, 0).decay, 1) > 1600, 'fast release retains the reference momentum');
assert.match(source, /clip\(true\)[\s\S]*?\.gesture\(GestureGroup/, 'gesture belongs to the fixed viewport');
assert.deepEqual(JSON.parse(JSON.stringify(motion.imagePanBounds(360, 720, 720, 360, 2))), { x: 180, y: 0 }, 'short landscape images cannot drift vertically');
const animations = [];
view.getUIContext = () => ({ createAnimator(options) {
  const animation = { options, cancelled: false, play() {}, cancel() { this.cancelled = true; } };
  animations.push(animation); return animation;
} });
Object.assign(view, { active: true, detail: { imageWidth: 360, imageHeight: 720 }, viewportWidth: 360, viewportHeight: 720,
  scaleValue: 4, multiTouch: false, dx: 0, dy: 0 });
for (const [vx, vy] of [[1000,0], [-1000,0], [0,1000], [0,-1000]]) {
  view.dx = 0; view.dy = 0; view.startInertia(vx, vy);
  const animation = animations.at(-1), positions = [];
  for (const time of [0.05, 0.1, 0.15, 0.2]) {
    animation.onFrame(time); positions.push(Math.abs(vx ? view.dx : view.dy));
  }
  assert(positions[1] > positions[0]);
  assert(positions[3] - positions[2] < positions[1] - positions[0], 'equal time steps travel less as friction slows movement');
  assert.equal(Math.sign(vx ? view.dx : view.dy), Math.sign(vx || vy));
  const stopped = [view.dx, view.dy];
  view.trackTouch({ type: 0, touches: [{ x: 0, y: 0 }] });
  assert(animation.cancelled); animation.onFrame(0.5);
  assert.deepEqual([view.dx, view.dy], stopped, 'a late frame cannot move the image after touch interruption');
}
view.scaleValue = 2; view.dx = 179; view.dy = 0;
view.startInertia(8000, 0); const edge = animations.at(-1); edge.onFrame(0.3); edge.onFrame(0.4);
assert.equal(view.dx, 180); assert(edge.cancelled, 'motion stops at the boundary');
view.multiTouch = true; const count = animations.length; view.startInertia(1000, 0); assert.equal(animations.length, count);
view.multiTouch = false; view.scaleValue = 1; view.startInertia(1000, 0); assert.equal(animations.length, count);
view.scaleValue = 3; view.startInertia(1000, 0); const background = animations.at(-1); view.active = false;
const previous = view.dx; background.onFrame(0.2); assert.equal(view.dx, previous); view.stopInertia(); assert(background.cancelled);
assert.match(source, /GestureGroup\(GestureMode.Exclusive,\s*TapGesture\(\{ count: 2 \}\)/);
assert(source.includes('PinchGesture()') && source.includes('PanGesture()'));
console.log('Viewer: four-way friction decay, bounds, interruption/stale frames, multi-touch protection, animated double tap and single-tap exit passed');
