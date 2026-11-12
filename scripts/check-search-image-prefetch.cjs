const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/services/PinmonySearchImagePrefetch.ets', 'utf8');
const leases = [], out = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: out, require: () => ({ acceptsSoftwareJpeg: url => url.endsWith('.jpg'),
  PinmonyJpegDecode: { acquire(url, active, priority) {
    const lease = { url, active, priority, releases: 0, changes: [],
      release() { this.releases++; }, setActive(value) { this.active = value; this.changes.push(value); } };
    lease.ready = new Promise((resolve, reject) => Object.assign(lease, { resolve, reject }));
    leases.push(lease); return lease;
  } } }) });
(async () => {
  const p = new out.PinmonySearchImagePrefetch();
  p.update(['a.jpg', 'a.jpg', 'b.webp', 'b.jpg']);
  assert.equal(leases.length, 2); assert(leases.every(x => !x.active && x.priority === 0));
  p.setActive(true); p.setActive(true); assert(leases.every(x => x.changes.length === 1));
  p.update(['a.jpg', 'b.jpg']); assert.equal(leases.length, 2, 'unchanged visible range reuses leases');
  p.update(['b.jpg', 'c.jpg']); assert.equal(leases[0].releases, 1); assert.equal(leases[1].releases, 0);
  assert.equal(leases.length, 3); assert.equal(leases[2].active, true);
  p.setActive(false); assert(leases.slice(1).every(x => !x.active));
  leases[0].resolve({ stale: true }); leases[2].reject(Error('offline'));
  for (let i = 0; i < 8; i++) await Promise.resolve();
  assert.equal(leases.length, 3, 'late callbacks and failures cannot retry or update the page');
  p.update(Array.from({ length: 20 }, (_, i) => i + '.jpg'));
  assert.equal(p.leases.size, 8, 'window has a bounded eight-image lease budget');
  p.clear(); p.clear(); assert.equal(p.leases.size, 0); assert(leases.every(x => x.releases === 1));
  p.setActive(true); p.update(['a.jpg']); assert.equal(leases.at(-1).active, true);
  assert.equal(leases.length, 12, 'new page/session can reuse the same URL after clear'); p.clear();
  assert(!source.match(/@State|@Prop|Image\(|setTimeout|setInterval/), 'headless service cannot trigger rendering or timers');
  const page = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
  assert(page.includes('private upcomingImageUrls:') && !page.includes('@State private upcomingImageUrls'));
  const material = page.slice(page.indexOf('  private searchMaterialContent('), page.indexOf('  private searchTitleBarOptions('));
  assert(!material.includes('upcomingImageUrls'), 'scrolling must not update a hidden image subtree beside Refresh');
  assert(page.includes("@Prop @Watch('syncImagePrefetchActivity') mediaActive"));
  assert(page.includes("@Prop @Watch('syncImagePrefetchActivity') automaticLoadingEnabled"));
  assert(page.includes('this.imagePrefetch?.clear();') && page.includes('this.imagePrefetch.clear();'));
  console.log('Search headless prefetch: no UI state/nodes, overlap reuse, priority, eight-lease bound, pause/resume, failure, late completion and route/disposal clear passed');
})().catch(e => { console.error(e); process.exitCode = 1; });
