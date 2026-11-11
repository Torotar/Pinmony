const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
function fixture(failureAt = '') {
  const events = [], logs = [], timers = new Map(), ready = new Map(), failed = new Map();
  let serial = 0;
  const download = {
    CacheStrategy: { FORCE: 0 },
    onDownloadSuccess(url, fn) { events.push('on-success'); ready.set(url, fn); },
    onDownloadError(url, fn) { events.push('on-error'); if (failureAt === 'subscribe') throw Error('unsupported'); failed.set(url, fn); },
    offDownloadSuccess(url, fn) { assert.equal(ready.get(url), fn); ready.delete(url); },
    offDownloadError(url, fn) { if (failed.has(url)) assert.equal(failed.get(url), fn); failed.delete(url); },
    download(url, options) { events.push(['download', url, options]); if (failureAt === 'download') throw Error('offline'); }
  };
  const loader = createArktsLoader(ts, { '@kit.BasicServicesKit': { cacheDownload: download },
    common_foundation: { PinmonyRuntimeLog: { info: line => logs.push(line) } } }, {
    setTimeout(fn) { const id = ++serial; timers.set(id, fn); return id; }, clearTimeout(id) { timers.delete(id); }
  });
  const { PinmonyHomeImageWarmup } = loader.loadFile('entry/src/main/ets/app/PinmonyHomeImageWarmup.ets');
  return { warm: new PinmonyHomeImageWarmup(), another: () => new PinmonyHomeImageWarmup(),
    events, logs, timers, ready, failed };
}
const url = 'https://i.pinimg.com/474x/aa/bb/thumbnail.jpg';
const f = fixture();
for (const invalid of ['', 'http://i.pinimg.com/474x/x.jpg', 'https://other.example/474x/x.jpg',
  'https://user:secret@i.pinimg.com/474x/x.jpg', 'https://i.pinimg.com/originals/x.jpg',
  url + '?token=secret', url + '#fragment']) f.warm.prepare(invalid);
assert.equal(f.events.length, 0, 'only a validated public finite thumbnail can warm the native downloader');
assert.equal(f.warm.prepare(url), undefined, 'warmup is synchronous dispatch, with no awaited feed gate');
assert.deepEqual(JSON.parse(JSON.stringify(f.events)), ['on-success', 'on-error', ['download', url, { cacheStrategy: 0 }]]);
f.warm.prepare(url); f.another().prepare(url);
assert.equal(f.events.length, 3, 'at most one network warmup per process, including multiple page hosts');
const late = f.ready.get(url); late();
assert.equal(f.ready.size + f.failed.size + f.timers.size, 0);
const count = f.logs.length; late(); assert.equal(f.logs.length, count, 'duplicate callback cannot resettle');
assert(f.logs.some(line => line.includes('connectionReuseConfirmed=false')));
assert(f.logs.every(line => !line.includes('pinimg.com') && !line.includes('secret')));
for (const phase of ['subscribe', 'download']) {
  const unavailable = fixture(phase); assert.doesNotThrow(() => unavailable.warm.prepare(url));
  assert.equal(unavailable.ready.size + unavailable.failed.size + unavailable.timers.size, 0);
}
const failed = fixture(); failed.warm.prepare(url); failed.failed.get(url)({ errorCode: 32 });
assert.equal(failed.ready.size + failed.failed.size + failed.timers.size, 0);
const hidden = fixture(); hidden.warm.prepare(url); const queued = hidden.ready.get(url);
hidden.warm.dispose(); const before = hidden.logs.length; queued();
assert.equal(hidden.logs.length, before, 'hidden/logout/disposed host rejects queued callbacks');
assert.equal(hidden.ready.size + hidden.failed.size + hidden.timers.size, 0);
const timeout = fixture(); timeout.warm.prepare(url); [...timeout.timers.values()][0]();
assert.equal(timeout.ready.size + timeout.failed.size + timeout.timers.size, 0);
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const restore = index.slice(index.indexOf('  private restoreHomeDiskCache('), index.indexOf('  private beginOffline', index.indexOf('  private restoreHomeDiskCache(')));
assert(restore.indexOf('this.homeImageWarmup.prepare(') < restore.indexOf('readHomeCache('), 'warm before the short-lived display cache lookup can expire the seed');
assert.match(restore, /trigger === 'authenticated-identity'.*authStatus === 'authenticated'/);
assert.match(restore, /!this.businessSuspended/); assert.match(restore, /!this.offlinePreviewMode/);
for (const name of ['onPageHide():', 'aboutToDisappear():', 'private clearRootTabCaches(']) {
  const block = index.slice(index.indexOf(name), index.indexOf('\n  }', index.indexOf(name)));
  assert(block.includes('this.homeImageWarmup.dispose()'), name + ' detaches listeners and timer');
}
const source = fs.readFileSync('entry/src/main/ets/app/PinmonyHomeImageWarmup.ets', 'utf8');
assert.doesNotMatch(source, /cacheDownload\.(?:cancel|clearMemoryCache|clearFileCache|setGlobal)/);
assert.doesNotMatch(source, /NetworkManager|createSession|WebviewController|Cookie|Range\s*:/);
console.log('Home native image warmup: exact system downloader, once-only, no feed gate, validation, failure, timeout, cancellation isolation and lifecycle passed');
