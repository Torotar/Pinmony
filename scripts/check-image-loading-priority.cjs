const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_network/src/main/ets/PinmonyJpegDecode.ets', 'utf8');
const flush = async () => { for (let n = 0; n < 48; n++) await Promise.resolve(); };
function harness() {
  const downloads = [], decodes = [], logs = [], leases = [];
  let activeDownloads = 0, activeDecodes = 0, peakDownloads = 0, peakDecodes = 0;
  class Download {
    cancel() { this.reject?.(Error('cancelled')); }
    async read(url, current, priority) {
      assert(current()); activeDownloads++; peakDownloads = Math.max(peakDownloads, activeDownloads);
      try { return await new Promise((resolve, reject) => {
        this.reject = reject; downloads.push({ url, priority, done: () => resolve({ data: { url }, extension: 'jpg' }) });
      }); } finally { activeDownloads--; this.reject = undefined; }
    }
  }
  const kit = { AllocatorType: { SHARE_MEMORY: 2 }, DecodingDynamicRange: { SDR: 1 },
    createImageSource: data => ({ getImageInfo: async () => ({ size: { width: 500, height: 500 } }),
      createPixelMapUsingAllocator: async (_options, allocator) => {
        assert.equal(allocator, 2); activeDecodes++; peakDecodes = Math.max(peakDecodes, activeDecodes);
        try { return await new Promise(resolve => decodes.push({ url: data.url,
          done: () => resolve({ getPixelBytesNumber: () => 1000000, release: async () => {} }) })); }
        finally { activeDecodes--; }
      }, release: async () => {} }) };
  const output = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText,
    { exports: output, require: name => name === '@kit.ImageKit' ? { image: kit } : name === './PinmonyNativeNetwork' ?
      { Priority: { HIGH: 0, NORMAL: 1, LOW: 2 } } : name === 'common_foundation' ?
      { PinmonyRuntimeLog: { info: line => logs.push(line) } } :
      { PinmonyImageDownload: Download, acceptsImageDownloadUrl: url => /^https:\/\/i\.pinimg\.com\//.test(url) } });
  const api = output.PinmonyJpegDecode, url = key => 'https://i.pinimg.com/564x/' + key + '.jpg';
  return { api, downloads, decodes, logs, url,
    start(key, active = true, priority = 1) { const lease = api.acquire(url(key), active, priority); lease.ready.catch(() => {}); leases.push(lease); return lease; },
    download(key) { const task = downloads.find(item => item.url === url(key)); assert(task, 'download started: ' + key); task.done(); },
    decode(key) { const task = decodes.find(item => item.url === url(key)); assert(task, 'decode started: ' + key); task.done(); },
    async cleanup() { api.clear(); for (const task of decodes) task.done(); for (const lease of leases) lease.release();
      await flush(); assert.equal(api.downloads, 0); assert.equal(api.decodes, 0); assert.equal(api.buffered, 0);
      assert.equal(api.downloadQueue.length, 0); assert.equal(api.decodeQueue.length, 0);
      assert(peakDownloads <= 4); assert(peakDecodes <= 2); }
  };
}
(async () => {
  const h = harness();
  for (const key of ['a', 'b', 'c', 'd', 'normal']) h.start(key);
  h.start('visible', true, 2); await flush(); assert.equal(h.downloads.length, 4);
  for (const key of ['a', 'b', 'c', 'd']) h.download(key);
  await flush(); assert.equal(h.decodes.length, 2, 'download completion does not bypass the two-decode bound');
  assert.equal(h.downloads.length, 4, 'four total in-flight payloads bound memory');
  h.decode('a'); await flush(); assert.equal(h.downloads[4].url, h.url('visible'), 'visible image overtakes queued ordinary work');
  assert.equal(h.downloads[4].priority, 0, 'visible priority reaches the network scheduler');
  assert(h.logs.some(line => line.includes('phase=download-queue')));
  assert(h.logs.some(line => line.includes('phase=decode-queue')));
  assert(h.logs.some(line => line.includes('phase=decode')));
  assert(h.logs.every(line => !line.includes('pinimg') && !line.includes('https://')), 'timings contain no image URLs');
  await h.cleanup();

  const paused = harness();
  const card = paused.start('retained-home', false); await flush(); assert.equal(paused.downloads.length, 0);
  const visible = paused.start('retained-home', true, 2); await flush();
  assert.equal(card.ready, visible.ready, 'visible owner promotes an existing URL without another transfer');
  assert.equal(paused.downloads.length, 1); card.setActive(false); paused.download('retained-home');
  await flush(); paused.decode('retained-home'); const bitmap = await visible.ready;
  visible.release(); assert.equal(paused.start('retained-home').bitmap, bitmap, 'return keeps decoded cache');
  const queued = paused.start('offscreen', false); await flush(); assert.equal(paused.downloads.length, 1);
  queued.setActive(true); await flush(); assert.equal(paused.downloads.length, 2, 'scrolling into view resumes the same task');
  await paused.cleanup();

  const race = harness();
  const reserved = race.start('covered-before-transfer'); reserved.setActive(false); await flush();
  assert.equal(race.downloads.length, 0, 'covering between reservation and continuation pauses before network starts');
  reserved.setActive(true); await flush(); assert.equal(race.downloads.length, 1);
  await race.cleanup();

  const bg = harness();
  bg.start('prefetch-a', true, 0); bg.start('prefetch-b', true, 0); await flush();
  assert.equal(bg.downloads.length, 1, 'prefetch leaves foreground capacity available');
  const offscreen = bg.start('offscreen', false); const rejected = assert.rejects(offscreen.ready, /unavailable/);
  offscreen.release(); await rejected; assert.equal(bg.downloads.length, 1, 'cancelled queued work does not reach network');
  bg.start('foreground', true, 2); await flush(); assert.equal(bg.downloads.length, 2);
  assert.equal(bg.downloads[1].url, bg.url('foreground'));
  await bg.cleanup();

  const drain = harness();
  const active = ['a', 'b', 'c', 'd'].map(key => drain.start(key)); await flush();
  for (const key of ['a', 'b', 'c', 'd']) drain.download(key);
  await flush(); active.forEach(lease => lease.setActive(false)); drain.start('new-detail', true, 2);
  drain.decode('a'); drain.decode('b'); await flush();
  assert(drain.downloads.some(task => task.url === drain.url('new-detail')), 'paused buffered images cannot deadlock a new page');
  await drain.cleanup();

  // Execute component activation methods rather than assuming UI visibility changes lease state.
  for (const [path, leaseName, mountedName] of [
    ['common_ui/src/main/ets/components/SmartImage.ets', 'decodeLease', 'imageVisible'],
    ['common_ui/src/main/ets/components/PinmonyCdnImage.ets', 'lease', 'visible']
  ]) {
    const text = fs.readFileSync(path, 'utf8'), method = text.match(/  private loadingChanged\([\s\S]*?\r?\n  \}/)[0];
    const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
    const host = new Host(), states = [];
    const retained = {};
    Object.assign(host, { [leaseName]: { setActive: active => states.push(active) }, [mountedName]: true,
      loadingActive: true, viewportOnly: true, inViewport: false, bitmap: retained, decodedBitmap: retained });
    host.loadingChanged(); host.inViewport = true; host.loadingChanged(); host.loadingActive = false; host.loadingChanged();
    assert.deepEqual(states, [false, true, false], 'viewport entry and page covering update existing lease');
    assert.equal(host.bitmap, retained); assert.equal(host.decodedBitmap, retained, 'covering retains displayed bitmap');
  }
  const root = fs.readFileSync('entry/src/main/ets/components/PinmonyHomeRootContent.ets', 'utf8');
  const expression = root.match(/imageLoadingActive: ([^\r\n]+),/)[1];
  const visibleHome = Function('view', 'return ' + expression);
  const view = { activeTab: 0, pinStore: { videoForeground: true }, activeSheetKind: '',
    nativeRootOnly: true, homeStore: { homeNativeReadsReady: false }, rootContentInteracted: false };
  assert.equal(visibleHome(view), true, 'offline cached home images do not wait for business API readiness');
  view.pinStore.detailOpeningPin = 'synthetic'; assert.equal(visibleHome(view), false);
  view.pinStore.detailOpeningPin = ''; view.activeTab = 1; assert.equal(visibleHome(view), false);
  view.activeTab = 0; view.pinStore.videoForeground = false; assert.equal(visibleHome(view), false);
  const page = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets', 'utf8');
  const feed = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
  assert(page.includes('imageLoadingActive: this.imageLoadingActive && this.activePane(tab.id)'));
  assert(feed.includes('loadingActive: this.imageLoadingActive && this.paneActive'));
  console.log('Image scheduling: visible priority, 4 payload/2 decode bounds, prefetch reservation, shared promotion, pause/resume, buffered drain, cancellation, reset and private timings passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
