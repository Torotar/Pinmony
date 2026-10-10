const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const code = ts.transpileModule(fs.readFileSync('common_network/src/main/ets/PinmonyMediaFile.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText;
const source = 'https://v1.pinimg.com/videos/synthetic.mp4';
const mp4 = Buffer.alloc(24); mp4.writeUInt32BE(24); mp4.write('ftyp', 4); mp4.write('isom', 8);
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness(config = {}) {
  const files = new Map(), handles = new Map(), traces = [], requests = [], timers = new Map(), queued = [], sessions = [];
  let serial = 0, timerId = 0, cancellations = 0, owner = true, now = 0;
  const io = { OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4, READ_ONLY: 8 },
    listFileSync: () => Array.from(files.keys()).map(path => path.split('/').at(-1)),
    openSync(path, mode) {
      if (mode & 4) files.set(path, Buffer.alloc(0));
      assert(files.has(path)); const handle = { fd: ++serial, path }; handles.set(handle.fd, handle); return handle;
    },
    closeSync(file) { assert(handles.delete(file.fd ?? file), 'file descriptor closes only once'); },
    writeSync(fd, chunk) { const handle = handles.get(fd); assert(handle, 'writes cannot touch a closed file');
      files.set(handle.path, Buffer.concat([files.get(handle.path), Buffer.from(chunk)])); return chunk.byteLength; },
    readSync(fd, target) { const bytes = files.get(handles.get(fd).path); Buffer.from(target).set(bytes.subarray(0, target.byteLength)); return Math.min(bytes.length, target.byteLength); },
    unlinkSync: path => files.delete(path) };
  function createSession() {
    const session = { closed: false, fetch(request) {
    const plan = config.attempts?.[requests.length] ?? config;
    const response = { statusCode: plan.error && !plan.partialError ? 0 : plan.status ?? 200,
      headers: plan.headers ?? { 'Content-Type': 'video/mp4', 'Content-Length': String(mp4.length) } };
    requests.push(request);
    request.configuration.tracing.httpEventsHandler.onStatusCodeReceive(response.statusCode);
    if (plan.pending) return new Promise((resolve, reject) => { request.resolve = resolve; request.reject = reject; });
    return Promise.resolve().then(() => {
      now += plan.elapsed ?? 0;
      request.configuration.tracing.httpEventsHandler.onTimeInfo({ nameLookupTimeMs: 8, connectTimeMs: 10,
        tlsHandshakeTimeMs: plan.error ? 0 : 30, startTransferTimeMs: plan.error ? 0 : 40 });
      if (plan.error && !plan.partialError) throw plan.error;
      for (const chunk of plan.chunks ?? [mp4.subarray(0, 5), mp4.subarray(5)])
        request.destination(Uint8Array.from(chunk).buffer);
      if (plan.error) throw plan.error;
      if (plan.staleAfterBody) owner = false;
      return response;
    });
    }, cancel() { cancellations++; }, close() { assert(!session.closed); session.closed = true; } };
    sessions.push(session); return session;
  }
  class Request { constructor(url, method, headers) { Object.assign(this, { url, method, headers }); } }
  const exports = {};
  vm.runInNewContext(code, { exports, URL, Date: class extends Date { static now() { return now; } },
    setTimeout(fn, ms) { const id = ++timerId; timers.set(id, { fn, ms }); return id; },
    clearTimeout: id => timers.delete(id),
    require: name => name.includes('RemoteCommunication') ? { rcp: { Request, createSession } } :
      name.includes('CoreFile') ? { fileIo: io } : name.includes('ArkTS') ? { url: { URL } } :
      name.includes('PinmonyNativeNetwork') ? { Priority: { NORMAL: 1 },
        NetworkManager: { enqueue: (_priority, task) => config.queue ? new Promise((resolve, reject) =>
          queued.push(() => Promise.resolve().then(task).then(resolve, reject))) : task(),
          getSession() { throw Error('media must not use the business session'); } } } : {} });
  const reader = new exports.PinmonyMediaFile(event => traces.push(event));
  return { reader, exports, files, handles, traces, requests, timers, sessions,
    read: () => reader.read(source, '/cache', () => owner),
    invalidate: () => owner = false,
    cancellations: () => cancellations,
    async runQueue() { for (const task of queued) await task(); },
    timeout() { for (const { fn, ms } of Array.from(timers.values())) if (ms === 20000) fn(); } };
}
async function main() {
  const h = harness();
  h.files.set('/cache/pinmony-video-100-1.mp4', Buffer.alloc(12));
  h.files.set('/cache/other-cache-file.mp4', Buffer.alloc(12));
  const lease = await h.read();
  assert.equal(lease.size, 24); assert(h.handles.has(lease.fd));
  assert(!h.files.has('/cache/pinmony-video-100-1.mp4')); assert(h.files.has('/cache/other-cache-file.mp4'));
  const request = h.requests[0];
  assert.equal(request.method, 'GET'); assert.equal(request.configuration.proxy, 'system');
  assert.equal(request.configuration.transfer.autoRedirect, false);
  assert.equal(request.configuration.security, undefined, 'platform TLS verification is preserved');
  assert(!Object.keys(request.headers).some(key => /cookie|authorization|csrf/i.test(key)));
  assert.equal(h.timers.size, 0); lease.release(); lease.release(); assert.equal(h.handles.size, 0);
  assert(h.sessions.every(session => session.closed), 'media session closes after reading, while file lease remains independent');
  assert.equal(h.files.size, 1, 'only the unrelated cache file remains');
  for (const invalid of ['http://v1.pinimg.com/videos/a.mp4', 'https://pinimg.com.attacker.test/videos/a.mp4',
    'https://user:password@v1.pinimg.com/videos/a.mp4', 'https://v1.pinimg.com:8443/videos/a.mp4',
    'https://v1.pinimg.com/images/a.mp4', 'https://v1.pinimg.com/videos/a.m3u8',
    'https://v1.pinimg.com/videos/../secret.mp4', source + '#fragment']) assert(!h.exports.acceptsMediaFileUrl(invalid));
  assert(h.exports.acceptsMediaFileUrl(source + '?signed=synthetic'));
  const invalidResponses = [ { status: 403 }, { status: 302 }, { status: 206 },
    { headers: { 'content-type': 'text/html' } },
    { headers: { 'content-type': 'video/mp4', 'content-length': '25' } },
    { headers: { 'content-type': 'video/mp4', 'content-encoding': 'gzip' } },
    { chunks: [Buffer.alloc(24)] }, { chunks: [mp4.subarray(0, 4)] },
    { chunks: [Buffer.alloc(32 * 1024 * 1024 + 1)] }, { staleAfterBody: true },
    { error: { code: 1007900035, message: 'SECRET_URL_COOKIE' } } ];
  for (const config of invalidResponses) {
    const bad = harness(config); await assert.rejects(bad.read());
    assert.equal(bad.files.size, 0); assert.equal(bad.handles.size, 0); assert.equal(bad.timers.size, 0);
    assert(bad.traces.some(event => /event=download-failed/.test(event)));
    assert(bad.traces.every(event => !/https:|SECRET|signed=/.test(event)), 'diagnostics exclude URLs, arbitrary errors and credentials');
  }
  const cancelled = harness({ pending: true }); const pending = cancelled.read();
  cancelled.reader.cancel(); await assert.rejects(pending); assert.equal(cancelled.cancellations(), 1);
  assert.equal(cancelled.handles.size, 0); assert.equal(cancelled.files.size, 0);
  assert.throws(() => cancelled.requests[0].destination(mp4.buffer), /cancelled/);
  cancelled.requests[0].resolve({ statusCode: 200, headers: { 'content-type': 'video/mp4' } }); await flush();
  assert.equal(cancelled.handles.size, 0, 'late response cannot recreate a cancelled file');
  const timeout = harness({ pending: true }); const timed = timeout.read(); timeout.timeout(); await assert.rejects(timed);
  assert.equal(timeout.cancellations(), 1); assert.equal(timeout.files.size, 0); assert.equal(timeout.handles.size, 0);
  assert(timeout.traces.some(event => /reason=timeout/.test(event)));
  const duplicate = harness({ pending: true }); const old = duplicate.read(), replacement = duplicate.read();
  await assert.rejects(old); duplicate.reader.cancel(); await assert.rejects(replacement);
  assert.equal(duplicate.handles.size, 0); assert.equal(duplicate.files.size, 0);
  const queued = harness({ queue: true }); const queuedRead = queued.read(); queued.reader.cancel();
  await assert.rejects(queuedRead); await queued.runQueue();
  assert.equal(queued.requests.length, 0, 'cancelled queued media must never reach the network');
  assert.equal(queued.files.size, 0); assert.equal(queued.handles.size, 0);
  const ssl = harness({ attempts: [{ error: { code: 1007900035 }, elapsed: 17000 }, {}] });
  const recovered = await ssl.read();
  assert.equal(ssl.requests.length, 2);
  assert.equal(ssl.requests[0].configuration.security, undefined);
  assert.equal(ssl.requests[1].configuration.security.tlsRange.min, 'TlsV1.2');
  assert.equal(ssl.requests[1].configuration.security.tlsRange.max, 'TlsV1.2');
  assert.equal(ssl.requests[1].configuration.security.skipCertificatesValidation, undefined, 'compatibility keeps certificate verification');
  assert.equal(ssl.requests[1].configuration.transfer.timeout.transferMs, 3000, 'compatibility uses remaining overall budget');
  assert(ssl.traces.some(event => /event=connection-time host=v1.pinimg.com profile=tls12 dnsMs=8/.test(event)));
  assert(ssl.traces.some(event => /event=tls-compatibility/.test(event)));
  assert(ssl.sessions.every(session => session.closed)); recovered.release();
  assert.throws(() => ssl.requests[0].destination(Uint8Array.from(mp4).buffer), /cancelled/, 'closed profile cannot write to the new file lease');
  for (const config of [{ error: { code: 1007900035 } }, { error: { code: 1007900007 } },
    { error: { code: 1007900035 }, partialError: true, chunks: [mp4.subarray(0, 5)] },
    { error: { code: 1007900035 }, elapsed: 20001 }]) {
    const failed = harness(config); await assert.rejects(failed.read());
    assert.equal(failed.requests.length, config.error.code === 1007900035 && !config.partialError && !config.elapsed ? 2 : 1);
    assert(failed.sessions.every(session => session.closed)); assert.equal(failed.handles.size, 0); assert.equal(failed.files.size, 0);
  }
  const compatibilityPending = harness({ attempts: [{ error: { code: 1007900035 } }, { pending: true }] });
  const compat = compatibilityPending.read(); await flush(); compatibilityPending.reader.cancel(); await assert.rejects(compat);
  assert.equal(compatibilityPending.requests.length, 2); assert.equal(compatibilityPending.cancellations(), 1);
  assert(compatibilityPending.sessions.every(session => session.closed)); assert.equal(compatibilityPending.files.size, 0);
  const compatTimeout = harness({ attempts: [{ error: { code: 1007900035 } }, { pending: true }] });
  const compatTimed = compatTimeout.read(); await flush(); assert.equal(compatTimeout.timers.size, 1, 'one deadline spans both profiles');
  compatTimeout.timeout(); await assert.rejects(compatTimed); assert(compatTimeout.sessions.every(session => session.closed));
  assert.equal(compatTimeout.files.size, 0);
  console.log('Video file: system proxy, verified bounded MP4, HTTP/type/signature/length guards, cancellation, deadline and temporary-file cleanup passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
