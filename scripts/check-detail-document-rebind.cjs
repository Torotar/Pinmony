const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const flush = () => new Promise(resolve => setImmediate(resolve));
function script(file) {
  const raw = fs.readFileSync(file, 'utf8').match(/SCRIPT: string = (`[\s\S]*?`);/)[1];
  return Function('return ' + raw)();
}
const pin = 'https://www.pinterest.com/pin/101/';
async function main() {
  const jobs = [], cancels = [], location = new URL(pin);
  const window = { addEventListener() {}, fetch() {}, PinWebNativeNetworkEnabled: true,
    PinWebShareBridge: { networkRequest: raw => jobs.push(JSON.parse(raw)), cancelNetwork: id => cancels.push(id) } };
  window.top = window;
  vm.runInNewContext(script('common_network/src/main/ets/PinWebNetworkScript.ets'), {
    window, location, URL, Headers, Response, Map, Promise, console, setTimeout() { return 1; }, clearTimeout() {} });
  const transport = window.PinWebNetwork;
  transport.bind(1, pin);
  const oldRead = transport.fetch('/resource/PinResource/get/').catch(error => error);
  const write = transport.fetch('/resource/RepinResource/create/', { method: 'POST', body: 'synthetic' });
  transport.bind(2, pin);
  const cancelled = await oldRead;
  assert.equal(cancelled.name, 'AbortError'); assert.equal(cancelled.pinWebEpochChanged, true);
  assert.deepEqual(cancels, [jobs[0].id], 'epoch rebind cancels old reads, not sent writes');
  assert.equal(jobs.length, 2, 'rebind never replays a write');
  assert.equal(transport.complete({ ...jobs[0], status: 200, headers: {}, body: '{}' }), 'no-job');
  transport.complete({ ...jobs[1], status: 200, headers: {}, body: '{}' }); await write;
  const freshRead = transport.fetch('/resource/PinResource/get/');
  assert.equal(jobs[2].epoch, 2);
  transport.complete({ ...jobs[2], status: 200, headers: {}, body: '{}' }); await freshRead;

  const requests = [], apiTimers = [], apiWindow = { PinWebDetailApiEnabled: true };
  apiWindow.top = apiWindow;
  const fetch = (url, init) => new Promise((resolve, reject) => requests.push({ url, init, resolve, reject }));
  apiWindow.fetch = fetch;
  vm.runInNewContext(script('feature_pin/src/main/ets/services/PinWebDetailApiScript.ets'), {
    window: apiWindow, location: new URL(pin), URL, AbortController, fetch, console: { warn() {} },
    setTimeout(fn, delay) { apiTimers.push({ fn, delay }); return apiTimers.length; }, clearTimeout() {} });
  const api = apiWindow.PinWebDetailApi;
  api.read(pin, () => {}, () => true);
  requests[0].reject(cancelled); await flush();
  apiTimers.findLast(timer => timer.delay === 0).fn(); await flush();
  assert.equal(requests.length, 2, 'current Pin read recovers immediately once after an explicit epoch change');
  requests[1].reject(cancelled); await flush();
  assert.equal(apiTimers.filter(timer => timer.delay === 0).length, 1, 'epoch recovery is bounded to one attempt');
  api.reset(); api.read(pin, () => {}, () => true);
  requests[2].reject(Object.assign(new Error('timeout'), { name: 'AbortError' })); await flush();
  assert.equal(apiTimers.filter(timer => timer.delay === 0).length, 1, 'ordinary timeout/cancellation does not auto replay the Pin read');

  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  function method(name) {
    const begin = source.indexOf('  private ' + name);
    return source.slice(begin, source.indexOf('\n  private ', begin + 1));
  }
  const host = { PIN_NATIVE_NETWORK_ENABLED: true, PinWebRuntimeLog: { warn() {} } };
  vm.runInNewContext(ts.transpileModule(`class Native {
    ${method('bindCurrentDetailDocument')}
    ${method('probeDetailDocument')}
    ${method('refreshDetailDocumentBinding')}
  } globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, host);
  const n = new host.Native(), calls = [], timers = [];
  let epoch = 1;
  Object.assign(n, { pinStore: { detailPin: pin, detailOpeningPin: pin, detailOpeningToken: 7, videoForeground: true },
    pinIdentity: value => value.match(/\/pin\/(\d+)/)?.[1] || '', rootTabGuardTarget: -1,
    nativeNetworkContext: () => ({ page: pin, epoch, authenticated: true }),
    controller: { runJavaScript: async value => { calls.push(value); return 'true'; } },
    pageTasks: { timeout: fn => timers.push(fn) }, detailJourney: { mark() {} } });
  n.bindCurrentDetailDocument(pin); n.bindCurrentDetailDocument(pin); await flush();
  assert.equal(calls.length, 1, 'same document binding is deduplicated');
  epoch = 2; n.bindCurrentDetailDocument(pin); await flush();
  assert.equal(calls.length, 2, 'new epoch creates a current binding');
  timers[0](); await flush(); assert.equal(calls.length, 2, 'old binding callback cannot refresh a new epoch');
  n.pinStore.detailActionsReady = true; timers[1](); await flush();
  assert.equal(calls.length, 2, 'confirmed snapshot stops scheduled refreshes');
  epoch = 3; n.pinStore.detailActionsReady = false; n.bindCurrentDetailDocument(pin); await flush();
  for (let index = 2; index < timers.length; index++) { timers[index](); await flush(); }
  assert.equal(calls.length, 6, 'snapshot refresh has exactly three bounded follow-ups');
  n.pinStore.detailPresentationOnly = true; epoch = 4; n.bindCurrentDetailDocument(pin);
  assert.equal(calls.length, 6, 'cached return never binds a hidden document');

  const probe = new host.Native(), probeTimers = [], probeCalls = [], probeMarks = [];
  let currentPage = 'https://www.pinterest.com/';
  Object.assign(probe, { pinStore: { detailPin: pin, detailOpeningPin: pin, detailOpeningToken: 9, videoForeground: true },
    authStatus: 'authenticated', rootTabGuardTarget: -1, pinIdentity: n.pinIdentity,
    nativeNetworkContext: () => ({ page: currentPage, epoch: 4, authenticated: true }),
    controller: { runJavaScript: async value => { probeCalls.push(value); return 'true'; } },
    pageTasks: { timeout(fn, delay) { probeTimers.push({ fn, delay }); return probeTimers.length; } },
    detailJourney: { mark: event => probeMarks.push(event) } });
  probe.probeDetailDocument(pin, 9, 0);
  assert.equal(probeCalls.length, 0, 'source document cannot bind the target Pin');
  assert.equal(probeTimers[0].delay, 200);
  currentPage = pin; probeTimers[0].fn(); await flush();
  assert.equal(probeCalls.length, 1, 'target binds without waiting for page-end when exact location is available');
  probe.pinStore.detailActionsReady = true;
  const previousTimerCount = probeTimers.length;
  probe.probeDetailDocument(pin, 9, 2);
  assert.equal(probeTimers.length, previousTimerCount, 'current snapshot stops probing');
  probe.pinStore.detailActionsReady = false; probe.pinStore.detailPresentationOnly = true;
  probe.probeDetailDocument(pin, 9, 3);
  assert.equal(probeTimers.length, previousTimerCount, 'cached return never starts synchronization');
  probe.pinStore.detailPresentationOnly = false; probe.businessSuspended = true;
  probe.probeDetailDocument(pin, 9, 3);
  assert.equal(probeTimers.length, previousTimerCount, 'background cannot probe');
  probe.businessSuspended = false;
  probe.probeDetailDocument(pin, 8, 3);
  assert.equal(probeTimers.length, previousTimerCount, 'stale opening cannot probe');
  probe.probeDetailDocument(pin, 9, 60);
  assert(probeMarks.includes('document.transport.wait.timeout'));
  assert.equal(probeTimers.length, previousTimerCount, 'probe deadline is bounded without reloading a route');

  probe.detailDocumentBinding = ''; probe.controller.runJavaScript = async () => 'false';
  probe.bindCurrentDetailDocument(pin); await flush();
  for (let i = previousTimerCount; i < probeTimers.length; i++) { probeTimers[i].fn(); await flush(); }
  assert.equal(probe.detailDocumentBinding, '', 'unavailable JS document does not permanently deduplicate later ready events');
  probe.controller.runJavaScript = async value => { probeCalls.push(value); return 'true'; };
  probe.bindCurrentDetailDocument(pin); await flush();
  assert.equal(probeCalls.length, 2, 'a later valid ready event can bind after earlier exhaustion');
  probe.detailDocumentBinding = ''; probe.controller.runJavaScript = () => { throw new Error('controller not ready'); };
  assert.doesNotThrow(() => probe.bindCurrentDetailDocument(pin), 'synchronous Web controller failures are handled');
  const synchronousRetryCount = probeTimers.length;
  for (let i = synchronousRetryCount - 1; i < probeTimers.length; i++) { probeTimers[i].fn(); await flush(); }
  assert.equal(probe.detailDocumentBinding, '', 'synchronous failures also release deduplication after bounded retries');
  console.log('Detail document rebind: old reads settle promptly, writes never replay, current Pin recovery once, no timeout replay, bounded snapshot refresh and stale/cache guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
