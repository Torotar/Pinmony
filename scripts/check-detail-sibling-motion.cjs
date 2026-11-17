const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailSiblingMotion.ets', 'utf8');
const timers = new Map(); let serial = 0, now = 0;
const context = { exports: {}, require: () => ({}), setTimeout(fn, delay) { timers.set(++serial, { fn, at: now + delay }); return serial; }, clearTimeout(id) { timers.delete(id); } };
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { target: 99, module: ts.ModuleKind.CommonJS } }).outputText, context);
const Motion = context.exports.PinmonyDetailSiblingMotion;
function fixture(width = 360) {
  timers.clear(); now = 0;
  let pin = 'A', visible = true, allowed = true, resolve, reject, releases = 0, captures = 0;
  const frames = [], animations = [], commits = [], covers = [];
  const bitmap = { release() { releases++; return Promise.resolve(); } };
  const capture = new Promise((yes, no) => { resolve = yes; reject = no; });
  const motion = new Motion({ ready: () => allowed, visible: () => visible, pin: () => pin, width: () => width,
    capture: () => { captures++; return capture; }, cover: value => covers.push(value),
    frame: (current, previous) => frames.push([current, previous]),
    animate: (duration, update, finish) => { update(); animations.push({ duration, finish }); },
    commit: step => commits.push(step) });
  return { motion, frames, animations, commits, covers, bitmap, releases: () => releases, captures: () => captures,
    pin: value => pin = value, visible: value => visible = value, allowed: value => allowed = value,
    async captured() { resolve(bitmap); await Promise.resolve(); await Promise.resolve(); },
    async failed() { reject(Error('snapshot unavailable')); await Promise.resolve(); await Promise.resolve(); },
    tick(ms) { const end = now + ms; while (true) { const next = [...timers].filter(([,v]) => v.at <= end).sort((a,b) => a[1].at-b[1].at)[0]; if (!next) break; timers.delete(next[0]); now = next[1].at; next[1].fn(); } now=end; }
  };
}
(async () => {
  for (const width of [360, 720]) for (const step of [-1, 1]) {
    const f=fixture(width); f.motion.start(step);
    assert(f.motion.busy); assert.deepEqual(f.frames.at(-1), [0,0]);
    assert.equal(f.commits.length, 0, 'keep current content until captured old body is displayed');
    f.motion.start(step); await f.captured();
    const cover=f.covers.at(-1); assert.equal(cover.bitmap,f.bitmap);
    assert.equal(f.commits.length,0, 'capture completion alone does not navigate');
    f.motion.covered(cover.identity); f.motion.covered(cover.identity);
    assert.deepEqual(f.commits,[step], 'one navigation after old body image is ready');
    f.motion.present(); assert.equal(f.animations.length,0,'same old Pin cannot start motion');
    f.pin('B'); f.motion.present();
    assert.deepEqual(f.frames.at(-1),[step*width,0]);
    f.motion.covered(cover.identity); assert.equal(f.commits.length,1,'duplicate image callback during incoming cannot navigate twice');
    f.tick(16); assert.equal(f.animations[0].duration,280);
    assert.deepEqual(f.frames.at(-1),[0,-step*width]);
    for (const progress of [0,0.1,0.25,0.5,0.75,0.95,1]) {
      const current=step*width*(1-progress), previous=-step*width*progress;
      assert(Math.abs(Math.abs(current-previous)-width)<0.001, 'both pages remain exactly adjacent for entire push');
      const spans=[[current,current+width],[previous,previous+width]].sort((a,b)=>a[0]-b[0]);
      assert(spans[0][0]<=0 && spans[1][1]>=width && Math.abs(spans[0][1]-spans[1][0])<0.001,'paired frames cover viewport with no blank seam');
    }
    f.animations.shift().finish(); assert.equal(f.motion.busy,false); assert.equal(f.covers.at(-1),undefined);
    f.tick(32); assert.equal(f.releases(),1,'release only temporary old-page bitmap after detach');
  }
  for (const reason of ['hidden','deleted','replacement','cancel']) {
    const f=fixture(); f.motion.start(1);
    if(reason==='hidden')f.visible(false);
    if(reason==='deleted')f.allowed(false);
    if(reason==='replacement')f.pin('external');
    if(reason==='cancel')f.motion.cancel();
    await f.captured(); assert.equal(f.commits.length,0); assert.equal(f.motion.busy,false); assert.equal(f.releases(),1,'late/invalid capture is released');
  }
  const failed=fixture(); failed.motion.start(1); await failed.failed(); assert.deepEqual(failed.commits,[1]); assert.equal(failed.motion.busy,false,'capture failure preserves actual navigation');
  const coveredLate=fixture(); coveredLate.motion.start(1); await coveredLate.captured(); const retired=coveredLate.covers.at(-1); coveredLate.allowed(false); coveredLate.motion.covered(retired.identity); assert.equal(coveredLate.commits.length,0,'source invalidated between capture and image readiness cannot navigate'); coveredLate.tick(32); assert.equal(coveredLate.releases(),1);
  const resized=fixture(0); resized.motion.start(1); await resized.captured(); resized.motion.covered(resized.covers.at(-1).identity); resized.pin('B'); resized.motion.present(); assert.equal(resized.animations.length,0,'missing width cannot generate a zero-width push'); resized.tick(32); assert.equal(resized.releases(),1);
  const timeout=fixture(); timeout.motion.start(-1); timeout.tick(400); assert.deepEqual(timeout.commits,[-1]); await timeout.captured(); assert.equal(timeout.releases(),1,'late timed-out bitmap is released without another navigation');
  const pending=fixture(); pending.motion.start(1); pending.tick(400); pending.pin('B'); pending.motion.start(1);
  assert.equal(pending.captures(),1,'do not accumulate native captures while an older timed-out request remains pending');
  assert.deepEqual(pending.commits,[1,1],'a slow capture does not block later valid sibling navigation');
  await pending.captured(); assert.equal(pending.releases(),1);
  const imageTimeout=fixture(); imageTimeout.motion.start(1); await imageTimeout.captured(); const oldCover=imageTimeout.covers.at(-1); imageTimeout.tick(400); imageTimeout.motion.covered(oldCover.identity); assert.equal(imageTimeout.commits.length,1); imageTimeout.tick(32); assert.equal(imageTimeout.releases(),1);
  const rejected=fixture(); rejected.motion.start(1); await rejected.captured(); rejected.motion.covered(rejected.covers.at(-1).identity); rejected.tick(600); assert.equal(rejected.motion.busy,false,'rejected navigation removes cover'); rejected.tick(32); assert.equal(rejected.releases(),1);
  const late=fixture(); late.motion.start(1); await late.captured(); late.motion.covered(late.covers.at(-1).identity); late.pin('B'); late.motion.present(); late.motion.cancel(); late.tick(16); assert.equal(late.animations.length,0,'teardown cancels delayed push'); late.tick(16); assert.equal(late.releases(),1);
  const mid=fixture(); mid.motion.start(1); await mid.captured(); mid.motion.covered(mid.covers.at(-1).identity); mid.pin('B'); mid.motion.present(); mid.tick(16); const stale=mid.animations.shift(); mid.motion.cancel(); mid.motion.start(-1); stale.finish(); assert.equal(mid.motion.busy,true,'late finish cannot cancel new transition');
  const page=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
  assert.match(page,/getComponentSnapshot\(\)\.get\('pinmony-sibling-body-'/);
  assert.match(page,/\.id\('pinmony-sibling-body-' \+ this\.traceId\)/);
  assert.match(page,/\.onComplete\(\(\) => this\.siblingMotion\.covered\(cover\.identity\)\)/);
  assert.match(page,/ForEach\(this\.siblingMotionCovers/);
  assert.match(page,/\(cover: PinmonyDetailSiblingCover\): string => cover\.identity\.toString\(\)/);
  assert.match(page,/\.translate\(\{ x: this\.siblingPreviousOffset \}\)/);
  assert.match(page,/curves\.interpolatingSpring\(-1, 1, 328, 34\)/);
  assert.match(page,/if \(!this\.pageActive\) this\.siblingMotion\.cancel\(\)/);
  assert.match(page,/aboutToDisappear\(\)[\s\S]{0,120}this\.siblingMotion\.cancel\(\)/);
  assert(!page.includes('siblingMotionOpacity') && !source.includes('opacity'));
  const home=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
  assert.match(home,/itemSpace\(0\)\.duration\(280\)/);
  console.log('Sibling full push: 280ms paired full-width pages, both directions and widths, snapshot readiness, no transparent/gap phase, duplicate/late events, failed capture fallback, rejection and bitmap cleanup passed');
})().catch(error=>{ console.error(error); process.exitCode=1; });
