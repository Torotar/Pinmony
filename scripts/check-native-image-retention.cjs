const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function harness(path, smart) {
  const source = fs.readFileSync(path, 'utf8');
  const names = smart ? ['releaseDecode', 'loadDecodedImage', 'loadingChanged', 'canRenderImage', 'decodeModeChanged'] :
    ['release', 'reload', 'loadingChanged', 'canRenderImage'];
  const methods = names.map(name => {
    const match = source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
    assert(match, name); return match[0];
  });
  const leases = [];
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;',
    { compilerOptions: { target: 99 } }).outputText, {
    acceptsSoftwareJpeg: () => true, PinmonyJpegDecode: { acquire() {
      const lease = { releases: 0, states: [], release() { this.releases++; }, setActive(active) { this.states.push(active); } };
      lease.ready = new Promise(resolve => { lease.resolve = resolve; }); leases.push(lease); return lease;
    } }
  });
  const node = new Host();
  node.uiCommits = new (require('./ui-commit-harness.cjs').createUiCommitHarness(ts).Queue)();
  node.tracePhases = new Set();
  Object.assign(node, { visible: true, imageVisible: true, loadingActive: true, viewportOnly: false, inViewport: true,
    useSharedDecode: false, nativeSourceAdmitted: false, url: 'source-a', sourceUrl: 'source-a', generation: 0,
    imageRevision: 1, softwareAttemptedRevision: -1, traceImage() {} });
  const load = () => smart ? node.loadDecodedImage() : node.reload();
  const version = () => smart ? node.imageRevision : node.generation;
  const replace = url => { node.url = url; node.sourceUrl = url; node.imageRevision++; load(); };
  assert.match(source, /if \(this\.canRenderImage\(\)\)/, 'tested admission predicate controls the actual Image branch');
  return { node, load, version, replace, leases };
}
async function verify(path, smart) {
  const h = harness(path, smart), n = h.node;
  h.load(); assert.equal(n.canRenderImage(), true); assert.equal(h.leases.length, 0);
  let mounted = false, creates = 0, disposes = 0;
  function reconcile() {
    const present = n.canRenderImage();
    if (present && !mounted) creates++;
    if (!present && mounted) disposes++;
    mounted = present;
  }
  reconcile(); const revision = h.version();
  for (const reason of ['detail preparation', 'detail visible', 'return flight', 'Sheet', 'other tab', 'background']) {
    n.loadingActive = false; n.inViewport = false; n.loadingChanged(); reconcile();
    assert.equal(n.loadAllowed, false, reason + ': do not admit new images');
    assert.equal(n.canRenderImage(), true, reason + ': preserve already admitted Image, including an in-flight native load');
    n.loadingActive = true; n.inViewport = true; n.loadingChanged(); reconcile();
    assert.equal(h.version(), revision, reason + ': keep image generation and node identity');
  }
  assert.equal(creates, 1); assert.equal(disposes, 0, 'cover/return must not destroy and recreate native Image');
  n.loadingActive = false; n.loadingChanged(); h.replace('source-b');
  assert.equal(n.nativeSourceAdmitted, false); assert.equal(n.canRenderImage(), false, 'changed source cannot inherit old admission while covered');
  n.loadingActive = true; n.loadingChanged(); assert.equal(n.canRenderImage(), true, 'return admits the new source');
  const gated = harness(path, smart), g = gated.node;
  g.loadingActive = false; gated.load(); assert.equal(g.canRenderImage(), false, 'fresh covered cell starts no native image');
  g.loadingActive = true; g.viewportOnly = true; g.inViewport = false; g.loadingChanged();
  assert.equal(g.canRenderImage(), false, 'fresh viewport-gated image waits until admitted');
  g.inViewport = true; g.loadingChanged(); assert.equal(g.canRenderImage(), true);
  g.inViewport = false; g.loadingChanged(); assert.equal(g.canRenderImage(), true, 'leaving viewport retains admitted native image');
  const shared = harness(path, smart), s = shared.node;
  s.useSharedDecode = true; shared.load(); const lease = shared.leases[0];
  assert.equal(s.nativeSourceAdmitted, false); assert.equal(s.canRenderImage(), false);
  s.loadingActive = false; s.loadingChanged(); assert.equal(lease.states.at(-1), false, 'shared queue still pauses');
  s.loadingActive = true; s.loadingChanged(); assert.equal(lease.states.at(-1), true, 'shared queue resumes');
  s.loadingActive = false; s.loadingChanged(); lease.resolve({ ready: true });
  for (let i = 0; i < 6; i++) await Promise.resolve();
  assert.equal(s.canRenderImage(), true, 'a ready shared bitmap remains displayed while covered');
  const stale = harness(path, smart), old = stale.node;
  old.useSharedDecode = true; stale.load(); const retired = stale.leases[0];
  old.loadingActive = false; old.loadingChanged(); old.useSharedDecode = false;
  if (smart) old.decodeModeChanged(); else stale.load();
  assert.equal(retired.releases, 1); assert.equal(old.canRenderImage(), false);
  retired.resolve({ stale: true }); for (let i = 0; i < 6; i++) await Promise.resolve();
  assert.equal(old.canRenderImage(), false, 'late shared decode cannot restore a replaced native source');
  old.loadingActive = true; old.loadingChanged(); assert.equal(old.canRenderImage(), true);
  if (smart) old.releaseDecode(); else old.release();
  assert.equal(old.nativeSourceAdmitted, false, 'source disposal clears admission');
}
(async () => {
  await verify('common_ui/src/main/ets/components/PinmonyCdnImage.ets', false);
  await verify('common_ui/src/main/ets/components/SmartImage.ets', true);
  console.log('Native Image retention: stable cover/return node, pending images, source replacement, inactive/viewport admission, shared pause/ready retention and stale lease cleanup passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
