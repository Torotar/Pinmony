const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const files = new Map(), timers = new Map(); let destinations = [], opens = 0, closes = 0, next = 0, fail = false, partial = false;
let delayedRead;
const io = {
  OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4, APPEND: 8 },
  async readText(path, options) { if (delayedRead) { const waiting=delayedRead;delayedRead=undefined;await waiting; } if (!files.has(path)) throw Error('missing');return Buffer.from(files.get(path)).subarray(0,options?.length).toString('utf8'); },
  async copyFile(src, dst) { if (!files.has(src)) throw Error('missing'); files.set(dst, files.get(src)); },
  async open(path, mode) { if (fail) throw Error('disk unavailable'); opens++; if (mode & 4) files.set(path, ''); return { fd: { path, mode } }; },
  async write(fd, bytes) { const data = Buffer.from(bytes); const count = partial ? Math.min(7, data.length) : data.length;
    files.set(fd.path, Buffer.concat([Buffer.from(files.get(fd.path) || '', 'utf8'), data.subarray(0, count)]).toString('utf8')); return count; },
  async close() { closes++; },
  openSync() { throw Error('Sync file I/O forbidden'); },
  writeSync() { throw Error('Sync file I/O forbidden'); }, closeSync() { throw Error('Sync file I/O forbidden'); }
};
function compile(path, requireFn) { const exports = {}; vm.runInNewContext(ts.transpileModule(fs.readFileSync(path, 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, {
  exports, require: requireFn, console: { info() {}, warn() {} }, Date,
  setTimeout(fn, delay) { if (delay === 0) { queueMicrotask(fn); return ++next; } timers.set(++next, fn); return next; }, clearTimeout(id) { timers.delete(id); }
}); return exports; }
const buffer = compile('common_foundation/src/main/ets/services/PinmonyLogBuffer.ets', () => ({}));
const { PinmonyRuntimeLog: log } = compile('common_foundation/src/main/ets/services/PinmonyRuntimeLog.ets', name =>
  name.includes('LogBuffer') ? buffer : { fileIo: io, picker: { DocumentViewPicker: class { async save() { return destinations; } } },
    util: { TextEncoder: class { encodeInto(text) { return new Uint8Array(Buffer.from(text)); } } } });
(async () => {
  assert.match(log.savedStatus(), /尚未成功/); log.initialize('/internal'); await log.flush(); assert.match(log.savedStatus(), /已自动保存/);
  const before = opens;
  log.info('cookie=secret token=hidden https://example.test/?csrf=private account_id=1234567890123');
  assert.equal(opens, before, 'record performs no synchronous or immediate disk I/O'); await log.flush();
  assert(!/secret|hidden|private|1234567890123/.test(files.get('/internal/pinweb-runtime.log')));
  log.initialize('/internal'); await log.flush(); assert(files.get('/internal/pinweb-session-previous.log').includes('[credential]'));
  const batchOpens = opens; for (let i = 0; i < 450; i++) log.info('event ' + i); await log.flush();
  assert(opens - batchOpens < 10, 'hundreds of records share batch writes');
  assert(files.get('/internal/pinweb-session-current.log').includes('event 0'));
  assert.equal(await log.export({}), false); destinations = ['/export.txt'];
  log.info('latest-before-export'); const exporting = log.export({}); assert.equal(await log.export({}), false, 'duplicate picker suppressed'); assert.equal(await exporting, true);
  assert(files.get('/export.txt').includes('event 449')); assert(files.get('/export.txt').includes('latest-before-export'));
  assert(files.get('/export.txt').includes('Previous session'));
  await log.flush();let releaseSnapshot;delayedRead=new Promise(resolve=>releaseSnapshot=resolve);
  const lockedExport=log.export({});await new Promise(resolve=>setImmediate(resolve));
  assert.equal(delayedRead,undefined,'export is reading its snapshot');
  const frozenSession=files.get('/internal/pinweb-session-current.log');
  log.info('during-locked-export');const queuedWrite=log.flush();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(files.get('/internal/pinweb-session-current.log'),frozenSession,'snapshot read blocks session append/rotation');
  releaseSnapshot();await Promise.all([lockedExport,queuedWrite]);
  assert(!files.get('/export.txt').includes('during-locked-export'));assert(files.get('/internal/pinweb-session-current.log').includes('during-locked-export'));
  log.MAX_SESSION_BYTES = 20000;
  for (let group = 0; group < 10; group++) { for (let i = 0; i < 150; i++) log.info('rotation ' + (group * 150 + i) + ' ' + 'x'.repeat(100)); await log.flush(); }
  assert(files.get('/internal/pinweb-session-previous.log').length > 0);
  assert(files.get('/internal/pinweb-session-current.log').includes('rotation 1499'));
  assert.equal(files.get('/internal/pinweb-runtime.log').trim().split('\n').length, 1000);
  const unicode='x'.repeat(65535)+'😀中文'+'z'.repeat(70000);
  await log.writeFile('/unicode.txt',unicode,false);assert.equal(files.get('/unicode.txt'),unicode,'chunk boundaries preserve surrogate pairs and UTF-8');
  assert.equal(opens, closes, 'every asynchronous handle is closed including exports');
  let release;delayedRead=new Promise(resolve=>release=resolve);
  const restoring=log.initialize('/internal');log.info('during-async-restore');release();await restoring;await log.flush();
  const restored=files.get('/internal/pinweb-runtime.log');assert(restored.includes('rotation 1499'));assert(restored.indexOf('during-async-restore')>restored.indexOf('rotation 1499'),'new events follow restored history');
  partial = true; log.info('ascii-partial-write'); await log.flush(); assert(files.get('/internal/pinweb-session-current.log').includes('ascii-partial-write')); partial = false;
  fail = true; log.info('disk-failure-memory-event'); await log.flush(); assert.match(log.savedStatus(), /尚未成功/);
  fail = false; await log.export({}); assert(files.get('/export.txt').includes('disk-failure-memory-event'), 'failed persistence exports retained memory');
  await log.flush();
  for (let i = 0; i < 1300; i++) log.info('bounded-queue ' + i); await log.flush();
  assert(files.get('/internal/pinweb-session-current.log').includes('dropped=300'));
  assert.equal(timers.size, 0);
  console.log('Runtime log: async batching, privacy, order, partial writes, bounded queue, rotation, failure and export passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
