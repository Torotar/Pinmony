const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { TextEncoder } = require('node:util');
const ts = require(process.argv[2] || 'typescript');
function load(file, require, globals = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require, ...globals });
  return exports;
}
async function main() {
  let available = true, creates = 0, rejectedHash = false;
  const cryptoFramework = { createMd(algorithm) {
    creates++;
    if (rejectedHash) throw Error('hash-failed');
    assert.equal(algorithm, 'MD5');
    const hash = crypto.createHash('md5');
    return { updateSync: blob => hash.update(blob.data), digestSync: () => ({ data: hash.digest() }) };
  } };
  class Encoder { encodeInto(text) { return new TextEncoder().encode(text); } }
  const keys = load('common_foundation/src/main/ets/cache/CacheKey.ets', name =>
    name === '@kit.CryptoArchitectureKit' ? { cryptoFramework } : { util: { TextEncoder: Encoder } }, {
    canIUse: capability => { assert.equal(capability, 'SystemCapability.Security.CryptoFramework.MessageDigest'); return available; }
  });
  assert.equal(keys.hashCacheString('Pinmony'), crypto.createHash('md5').update('Pinmony').digest('hex'));
  assert.equal(keys.stableSerialize({ b: 1, a: 2 }), '{"a":2,"b":1}');
  available = false;
  assert.throws(() => keys.hashCacheString('unsupported'), /cache-hash-unavailable/);
  assert.equal(creates, 1, 'unsupported devices never invoke the digest API');
  available = true; rejectedHash = true;
  assert.throws(() => keys.hashCacheString('failed'), /cache-hash-unavailable/);
  let throwOnCreate = false, rejectTask = false;
  class Task {
    constructor(fn, value) { if (throwOnCreate) throw Error('constructor-failed'); this.fn = fn; this.value = value; }
  }
  const taskpool = { Task, Priority: { LOW: 0 }, execute: async task => {
    if (rejectTask) throw Error('execution-failed');
    return task.fn(task.value);
  } };
  const codec = load('common_foundation/src/main/ets/cache/CacheCodec.ets', () => ({ taskpool, util: { TextEncoder: Encoder } }), {
    Concurrent: fn => fn
  });
  assert.equal((await codec.parseCacheJson('{"ok":true}')).ok, true);
  assert.equal(Buffer.from(await codec.stringifyCacheJson({ ok: true })).toString(), '{"ok":true}');
  await assert.rejects(codec.parseCacheJson('{'), /cache-json-decode-failed/);
  for (const constructorFailure of [false, true]) {
    throwOnCreate = constructorFailure; rejectTask = !constructorFailure;
    await assert.rejects(codec.parseCacheJson('{}'), /cache-json-decode-failed/);
    await assert.rejects(codec.stringifyCacheJson({}), /cache-json-encode-failed/);
  }
  const ability = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
  assert(ability.includes("catch (_) { PinmonyRuntimeLog.warn('PageRecovery: restore-enable-unavailable'); }"));
  console.log('Build warning guards: stable MD5, absent capability, digest failure, task construction/rejection, JSON round-trip and startup recovery handling passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
