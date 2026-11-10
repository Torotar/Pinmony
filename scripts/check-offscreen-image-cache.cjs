const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const read = path => fs.readFileSync(path, 'utf8');
function method(source, name) {
  const match = source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'));
  assert(match, name); return match[0];
}
async function verifyHost(path, methods, mounted, pending, bitmap, load, sharedFlag) {
  const source = read(path), leases = [];
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.map(name => method(source, name)).join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { acceptsSoftwareJpeg: () => true, PinmonyJpegDecode: { acquire: () => {
    const lease = { releases: 0, release() { this.releases++; } };
    lease.ready = new Promise(resolve => { lease.resolve = resolve; });
    leases.push(lease); return lease;
  } } });
  const host = new Host();
  host.uiCommits = new (require('./ui-commit-harness.cjs').createUiCommitHarness(ts).Queue)();
  host.tracePhases = new Set();
  Object.assign(host, { [mounted]: true, loadingActive: true, viewportOnly: false, inViewport: false,
    useSharedDecode: false, url: 'synthetic.jpg', sourceUrl: 'synthetic.jpg', imageRevision: 1,
    softwareAttemptedRevision: -1, generation: 0, phase: 'loading', traceImage() {} });
  host[load]();
  assert.equal(host.loadAllowed, true, 'offscreen native source is enabled before any viewport callback');
  assert(!host[pending], 'native cache path is not hidden behind the shared pipeline');
  assert.equal(leases.length, 0, 'native list images do not wait for application download/decode slots');
  host.loadingActive = false; host.loadingChanged();
  assert.equal(host.loadAllowed, false, 'covered/background page disables admission of new sources');
  assert.equal(host.canRenderImage(), true, 'pausing loading retains the native Image node already admitted');
  host.loadingActive = true; host.loadingChanged();
  assert.equal(host.loadAllowed, true, 'return resumes without requiring viewport re-entry');
  host.useSharedDecode = true; host.softwareAttemptedRevision = -1; host[load]();
  assert.equal(leases.length, 1, 'default shared hero/transition path remains available');
  const lease = leases[0];
  host.useSharedDecode = false;
  if (sharedFlag === 'decodeLease') host.decodeModeChanged();
  else host[load]();
  assert.equal(lease.releases, 1, 'switching away releases the old shared lease');
  lease.resolve({ stale: true });
  for (let i = 0; i < 8; i++) await Promise.resolve();
  assert.equal(host[bitmap], undefined, 'late shared decode cannot replace the native source');
}
(async () => {
  await verifyHost('common_ui/src/main/ets/components/PinmonyCdnImage.ets', ['release', 'reload', 'loadingChanged', 'canRenderImage'],
    'visible', 'pending', 'bitmap', 'reload', 'lease');
  await verifyHost('common_ui/src/main/ets/components/SmartImage.ets', ['releaseDecode', 'loadDecodedImage', 'loadingChanged', 'decodeModeChanged', 'canRenderImage'],
    'imageVisible', 'softwarePending', 'decodedBitmap', 'loadDecodedImage', 'decodeLease');
  const home = read('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets');
  const detail = read('feature_pin/src/main/ets/components/PinmonyDetailPage.ets');
  const search = read('feature_search/src/main/ets/components/PinmonySearchPage.ets');
  assert(home.includes('loadingActive: this.imageLoadingActive && this.paneActive, useSharedDecode: false, viewportOnly: false'));
  assert.equal((detail.match(/loadingActive: this.videoActive, useSharedDecode: false, viewportOnly: false/g) || []).length, 2);
  assert.equal((home.match(/cachedCount\(12, true\)/g) || []).length, 1);
  assert.equal((detail.match(/cachedCount\(12, true\)/g) || []).length, 1);
  assert.equal((search.match(/cachedCount\(12, true\)/g) || []).length, 2);
  assert(search.includes('Image(result.imageUrl)') && search.includes('Image(result.boardImages?.[0] || result.imageUrl)'));
  const video = read('common_ui/src/main/ets/components/PinmonyVideoCard.ets');
  assert(video.includes('useSharedDecode: false, viewportOnly: false'));
  assert(video.includes('const enabled: boolean = this.active && this.visible;'), 'poster preload never starts offscreen playback');
  assert(search.includes('loadingActive: this.active && this.mediaActive && !this.quizSheetOpen'));
  console.log('Offscreen image cache: native source before visibility, no shared queue, cover/return, stale lease, retained shared path, all feed branches and poster-only preloading passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
