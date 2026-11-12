const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(file, requireDependency = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: requireDependency });
  return exports;
}
const lru = load('common_foundation/src/main/ets/cache/LruCache.ets');
function deferred() {
  let resolve, reject;
  const promise = new Promise((done, fail) => { resolve = done; reject = fail; });
  return { promise, resolve, reject };
}
function fixture() {
  const records = new Map(), writes = [], reads = [];
  class Disk {
    async getWithMetadataAsync(key, maxAge, current) { return current() ? this.getWithMetadata(key, maxAge) : { value: null, status: 'miss', ageMs: -1 }; }
  async putAsync(key, value, current) { if (!current()) throw Error('invalidated'); this.put(key, value); }
  getWithMetadata(key) {
      reads.push(key);
      return records.has(key) ? { value: records.get(key), status: 'hit', ageMs: 0 } :
        { value: null, status: 'miss', ageMs: -1 };
    }
    put(key, value) { records.set(key, value); writes.push([key, value]); }
    remove(key) { records.delete(key); }
    clear() { const size = records.size; records.clear(); return size; }
  }
  const { ApiCache } = load('common_foundation/src/main/ets/cache/ApiCache.ets', name =>
    name === './LruCache' ? lru : name === './DiskCache' ? { DiskCache: Disk } :
      { PinmonyRuntimeLog: { info() {} } });
  return { cache: new ApiCache('/synthetic-cache'), records, writes, reads };
}
const turn = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  {
    const { cache, reads } = fixture(), fresh = deferred(); let calls = 0;
    const first = cache.readThrough('key', 10000, () => { calls++; return fresh.promise; });
    const second = cache.readThrough('key', 10000, () => { throw Error('duplicate fetch'); });
    await turn(); assert.equal(calls, 1); assert.deepEqual(reads, ['key'], 'joined reads must not repeat synchronous disk lookup');
    fresh.resolve('shared'); assert.equal(await first, 'shared'); assert.equal(await second, 'shared');
  }
  for (const invalidate of ['clear', 'remove', 'put']) {
    const { cache, records, writes } = fixture(), old = deferred(), notifications = [];
    const first = cache.readThrough('account:home', 10000, () => old.promise, value => notifications.push(value));
    await turn();
    if (invalidate === 'clear') cache.clear();
    else if (invalidate === 'remove') cache.remove('account:home');
    else cache.put('account:home', 'confirmed-new', 10000);
    const rejected = assert.rejects(first, /cache-invalidated/);
    old.resolve('stale'); await rejected;
    assert.deepEqual(notifications, [], 'invalidated reads cannot notify their old consumer');
    assert.deepEqual(writes, invalidate === 'put' ? [['account:home', 'confirmed-new']] : []);
    assert.equal(records.get('account:home'), invalidate === 'put' ? 'confirmed-new' : undefined);
  }
  {
    const { cache, writes } = fixture(), old = deferred(), fresh = deferred(); let calls = 0;
    const first = cache.readThrough('key', 10000, () => { calls++; return old.promise; });
    await turn(); cache.remove('key');
    const second = cache.readThrough('key', 10000, () => { calls++; return fresh.promise; });
    await turn();
    const rejected = assert.rejects(first, /cache-invalidated/); old.resolve('old'); await rejected;
    const joined = cache.readThrough('key', 10000, () => { throw Error('old cleanup deleted the new flight'); });
    fresh.resolve('new');
    assert.equal(await second, 'new'); assert.equal(await joined, 'new'); assert.equal(calls, 2);
    assert.deepEqual(writes, [['key', 'new']], 'old completion cannot overwrite or detach the replacement read');
  }
  {
    const { cache } = fixture(), first = deferred(), other = deferred();
    const a = cache.readThrough('a', 10000, () => first.promise);
    const b = cache.readThrough('b', 10000, () => other.promise);
    await turn(); cache.remove('a');
    const rejected = assert.rejects(a, /cache-invalidated/);
    first.resolve('a'); other.resolve('b'); await rejected;
    assert.equal(await b, 'b', 'key invalidation must not discard unrelated reads');
  }
  {
    const { cache, writes } = fixture(); let calls = 0;
    const read = cache.readThrough('key', 10000, async () => { calls++; return 'old'; });
    cache.clear(); await assert.rejects(read, /cache-invalidated/);
    assert.equal(calls, 0, 'invalidated work must not start its deferred fetch'); assert.deepEqual(writes, []);
  }
  for (const source of ['memory', 'disk']) {
    const { cache, records, writes } = fixture(), old = deferred(), notifications = [];
    if (source === 'memory') cache.put('key', 'cached', 10000);
    else records.set('key', 'cached');
    writes.length = 0;
    assert.equal(await cache.readThrough('key', 10000, () => old.promise,
      (value, from) => notifications.push([value, from])), 'cached');
    cache.clear(); old.resolve('stale'); await turn();
    assert.deepEqual(notifications, [['cached', source]]);
    assert.deepEqual(writes, [], 'invalidated background refresh must not resurrect disk state');
    assert.equal(cache.get('key', 10000), null);
  }
  {
    const { cache } = fixture(); let calls = 0;
    cache.put('key', 'cached', 10000);
    await cache.readThrough('key', 10000, async () => { calls++; return 'fresh'; }, () => cache.clear());
    await turn(); assert.equal(calls, 0, 'invalidation in the cache-hit callback must prevent refresh dispatch');
  }
  {
    const { cache } = fixture(), pending = deferred();
    cache.put('key', 'cached', 10000);
    await cache.readThrough('key', 10000, () => pending.promise);
    pending.reject(Error('synthetic network failure')); await turn();
    assert.equal(cache.get('key', 10000), 'cached', 'a failed background read retains valid cached content');
  }
  console.log('Cache invalidation: clear/remove/put, late commits and callbacks, replacement-flight ownership, unrelated keys, dispatch guards and background failures passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
