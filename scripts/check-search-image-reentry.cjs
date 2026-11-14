const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
let transfers = 0;
let decodes = 0;
let bytes = 1024;
const released = [];
const exportsObject = {};
class Download {
  cancel() {}
  async read(url) { transfers++; return { data: { url, bytes }, extension: 'jpg' }; }
}
const kit = {
  AllocatorType: { SHARE_MEMORY: 2 }, DecodingDynamicRange: { SDR: 1 },
  createImageSource(data) {
    return { getImageInfo: async () => ({ size: { width: 100, height: 100 } }),
      createPixelMapUsingAllocator: async () => {
        decodes++;
        return { url: data.url, getPixelBytesNumber: () => data.bytes,
          release: async () => { released.push(data.url); } };
      }, release: async () => {} };
  }
};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(process.argv[3] || 'common_network/src/main/ets/PinmonyJpegDecode.ets', 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, { exports: exportsObject, require(name) {
  if (name === '@kit.ImageKit') return { image: kit };
  if (name === 'common_foundation') return { PinmonyRuntimeLog: { info() {} } };
  if (name === './PinmonyNativeNetwork') return { Priority: { HIGH: 0, NORMAL: 1, LOW: 2 } };
  return { PinmonyImageDownload: Download, acceptsImageDownloadUrl: value => /^https:\/\/i\.pinimg\.com\//.test(value) };
} });
const api = exportsObject.PinmonyJpegDecode;
const url = key => 'https://i.pinimg.com/564x/synthetic-' + key + '.jpg';
async function load(key) { const lease = api.acquire(url(key)); await lease.ready; return lease; }
(async () => {
  // Retained roots/prefetch can own more than 48 entries. They are not idle cache.
  const held = [];
  for (let i = 0; i < 50; i++) held.push(await load('held-' + i));
  const original = held[0].bitmap || await held[0].ready;
  held[0].release();
  const before = { transfers, decodes };
  const returned = api.acquire(url('held-0'));
  assert.equal(returned.bitmap, original, 'recycled card must synchronously recover pixels with >48 live entries');
  await returned.ready;
  assert.deepEqual({ transfers, decodes }, before, 'scroll return must not redownload or decode the retained image');
  returned.setActive(false); returned.setActive(true);
  assert.equal(returned.bitmap, original, 'pause/resume retains the decoded source');
  returned.release(); held.slice(1).forEach(lease => lease.release());
  assert(released.includes(url('held-0')), 'idle count remains bounded by LRU eviction');
  const recent = api.acquire(url('held-49'));
  assert(recent.bitmap, 'most recent idle entry survives count eviction'); recent.release();
  api.clearUnused();
  bytes = 28 * 1024 * 1024;
  const large = await load('large-live');
  bytes = 1024 * 1024;
  const small = await load('small'); const pixels = await small.ready; small.release();
  const hit = api.acquire(url('small'));
  assert.equal(hit.bitmap, pixels, 'live bytes cannot consume idle-cache allowance'); hit.release();
  assert(!released.includes(url('large-live')), 'live bitmap is never released by trimming');
  large.release();
  assert(released.includes(url('large-live')), 'oversized idle bitmap is evicted');
  api.clearUnused();
  bytes = 10 * 1024 * 1024;
  for (let i = 0; i < 3; i++) { const lease = await load('budget-' + i); lease.release(); }
  assert(released.includes(url('budget-0')), 'idle bytes remain bounded at 24 MiB');
  const newest = api.acquire(url('budget-2')); assert(newest.bitmap);
  api.clear();
  assert(!released.includes(url('budget-2')), 'session clear keeps active pixels alive until owner leaves');
  newest.release(); assert(released.includes(url('budget-2')));
  const fresh = api.acquire(url('budget-2')); assert.equal(fresh.bitmap, undefined, 'new session cannot reuse cleared pixels');
  await fresh.ready; fresh.release(); api.clearUnused();
  console.log('Search image reentry: live/idle budgets, synchronous reuse, no extra transfer/decode, pause/resume, bounded LRU and session reset passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
