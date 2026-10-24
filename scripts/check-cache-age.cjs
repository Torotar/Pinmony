const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
let now = 299000, savedAt = 0, saved = { value: 'old' };
function load(file, require) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require, Date: { now: () => now } });
  return exports;
}
const lru = load('common_foundation/src/main/ets/cache/LruCache.ets');
class Disk {
  getWithMetadata(key, maxAge) {
    const ageMs = now - savedAt;
    return ageMs >= maxAge ? { value: null, status: 'expired', ageMs } : { value: saved, status: 'hit', ageMs };
  }
  put(key, value) { saved = value; savedAt = now; }
}
const { ApiCache } = load('common_foundation/src/main/ets/cache/ApiCache.ets', name =>
  name === './LruCache' ? lru : name === './DiskCache' ? { DiskCache: Disk } : { PinmonyRuntimeLog: { info() {} } });
(async () => {
  let cache = new ApiCache('/cache');
  assert.equal(cache.getWithMetadata('key', 300000).status, 'disk');
  now = 299999; assert.equal(cache.getWithMetadata('key', 300000).status, 'memory');
  now = 300001; assert.equal(cache.getWithMetadata('key', 300000).status, 'expired', 'disk-to-memory promotion cannot renew TTL');
  now = 100000; cache = new ApiCache('/cache'); cache.getWithMetadata('key', 300000);
  assert.equal(cache.getWithMetadata('key', 50000).status, 'expired', 'a stricter caller age applies to original creation time');
  now = 299000; cache = new ApiCache('/cache');
  let resolve;
  const pending = new Promise(done => resolve = done);
  assert.equal((await cache.readThrough('key', 300000, () => pending)).value, 'old');
  now = 300001; assert.equal(cache.getWithMetadata('key', 300000).status, 'expired', 'readThrough uses remaining disk lifetime too');
  resolve({ value: 'fresh' }); await new Promise(done => setImmediate(done));
  assert.equal(cache.getWithMetadata('key', 300000).value.value, 'fresh');
  console.log('Cache age: disk promotion expiry, tighter age limits, readThrough and fresh network renewal passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
