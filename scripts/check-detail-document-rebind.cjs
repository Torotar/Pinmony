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
  const window = { addEventListener() {}, fetch() {}, PinmonyNativeNetworkEnabled: true,
    PinmonyShareBridge: { networkRequest: raw => jobs.push(JSON.parse(raw)), cancelNetwork: id => cancels.push(id) } };
  window.top = window;
  vm.runInNewContext(script('common_network/src/main/ets/PinmonyNetworkScript.ets'), {
    window, location, URL, Headers, Response, Map, Promise, console, setTimeout() { return 1; }, clearTimeout() {} });
  const transport = window.PinmonyNetwork;
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

  const requests = [], apiTimers = [], apiWindow = { PinmonyDetailApiEnabled: true };
  apiWindow.top = apiWindow;
  const fetch = (url, init) => new Promise((resolve, reject) => requests.push({ url, init, resolve, reject }));
  apiWindow.fetch = fetch;
  vm.runInNewContext(script('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets'), {
    window: apiWindow, location: new URL(pin), URL, AbortController, fetch, console: { warn() {} },
    setTimeout(fn, delay) { apiTimers.push({ fn, delay }); return apiTimers.length; }, clearTimeout() {} });
  const api = apiWindow.PinmonyDetailApi;
  api.read(pin, () => {}, () => true);
  requests[0].reject(cancelled); await flush();
  apiTimers.findLast(timer => timer.delay === 0).fn(); await flush();
  assert.equal(requests.length, 2, 'current Pin read recovers immediately once after an explicit epoch change');
  requests[1].reject(cancelled); await flush();
  assert.equal(apiTimers.filter(timer => timer.delay === 0).length, 1, 'epoch recovery is bounded to one attempt');
  api.reset(); api.read(pin, () => {}, () => true);
  requests[2].reject(Object.assign(new Error('timeout'), { name: 'AbortError' })); await flush();
  assert.equal(apiTimers.filter(timer => timer.delay === 0).length, 1, 'ordinary timeout/cancellation does not auto replay the Pin read');

  const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailDocumentBinding.ets', 'utf8');
  const compiled = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports: compiled, require: () => ({}) });
  const PinmonyDetailDocumentBinding = compiled.PinmonyDetailDocumentBinding;
  function makeHarness(overrides = {}) {
    const state = { detailPin: pin, detailOpeningPin: pin, detailOpeningToken: 7, videoForeground: true,
      authenticated: true, page: pin, epoch: 1, rootTabGuardTarget: -1, result: 'true', ...overrides };
    const calls = [], timers = [], marks = [];
    const ports = { enabled: () => true, expectedPin: () => state.detailOpeningPin, detailPin: () => state.detailPin,
      pinIdentity: value => value.match(/\/pin\/(\d+)/)?.[1] || '', detailPresentationOnly: () => !!state.detailPresentationOnly,
      actionsReady: () => !!state.detailActionsReady, openingToken: () => state.detailOpeningToken,
      isAuthenticated: () => state.authenticated, isForeground: () => state.videoForeground,
      hasNativeBackTarget: () => !!state.nativeBackTarget, nativeRootOnly: () => !!state.nativeRootOnly,
      rootTabGuardTarget: () => state.rootTabGuardTarget, detailReturnedToRoot: () => !!state.detailReturnedToRoot,
      businessSuspended: () => !!state.businessSuspended,
      networkContext: () => ({ page: state.page, epoch: state.epoch, authenticated: state.authenticated }),
      runJavaScript: async value => { calls.push(value); if (state.throwSync) throw new Error('controller not ready'); return state.result; },
      schedule: (fn, delay) => { timers.push({ fn, delay }); return timers.length; }, cancel: () => {},
      markJourney: event => marks.push(event), warn: () => {}
    };
    return { state, calls, timers, marks, service: new PinmonyDetailDocumentBinding(ports) };
  }
  const first = makeHarness();
  first.service.bindCurrentDetailDocument(pin); first.service.bindCurrentDetailDocument(pin); await flush();
  assert.equal(first.calls.length, 1, 'same document binding is deduplicated');
  first.state.epoch = 2; first.service.bindCurrentDetailDocument(pin); await flush();
  assert.equal(first.calls.length, 2, 'new epoch creates a current binding');
  first.timers[0].fn(); await flush(); assert.equal(first.calls.length, 2, 'old binding callback cannot refresh a new epoch');
  first.state.detailActionsReady = true; first.timers[1].fn(); await flush();
  assert.equal(first.calls.length, 2, 'confirmed snapshot stops scheduled refreshes');
  first.state.epoch = 3; first.state.detailActionsReady = false; first.service.bindCurrentDetailDocument(pin); await flush();
  for (let index = 2; index < first.timers.length; index++) { first.timers[index].fn(); await flush(); }
  assert.equal(first.calls.length, 6, 'snapshot refresh has exactly three bounded follow-ups');
  first.state.detailPresentationOnly = true; first.state.epoch = 4; first.service.bindCurrentDetailDocument(pin);
  assert.equal(first.calls.length, 6, 'cached return never binds a hidden document');

  const probe = makeHarness({ detailOpeningToken: 9, page: 'https://www.pinterest.com/' });
  probe.service.probeDetailDocument(pin, 9, 0);
  assert.equal(probe.calls.length, 0, 'source document cannot bind the target Pin');
  assert.equal(probe.timers[0].delay, 200);
  probe.state.page = pin; probe.timers[0].fn(); await flush();
  assert.equal(probe.calls.length, 1, 'target binds without waiting for page-end when exact location is available');
  probe.state.detailActionsReady = true;
  const previousTimerCount = probe.timers.length;
  probe.service.probeDetailDocument(pin, 9, 2);
  assert.equal(probe.timers.length, previousTimerCount, 'current snapshot stops probing');
  probe.state.detailActionsReady = false; probe.state.detailPresentationOnly = true;
  probe.service.probeDetailDocument(pin, 9, 3);
  assert.equal(probe.timers.length, previousTimerCount, 'cached return never starts synchronization');
  probe.state.detailPresentationOnly = false; probe.state.businessSuspended = true;
  probe.service.probeDetailDocument(pin, 9, 3);
  assert.equal(probe.timers.length, previousTimerCount, 'background cannot probe');
  probe.state.businessSuspended = false; probe.service.probeDetailDocument(pin, 8, 3);
  assert.equal(probe.timers.length, previousTimerCount, 'stale opening cannot probe');
  probe.service.probeDetailDocument(pin, 9, 60);
  assert(probe.marks.includes('document.transport.wait.timeout'));
  assert.equal(probe.timers.length, previousTimerCount, 'probe deadline is bounded without reloading a route');

  const unavailable = makeHarness({ result: 'false' });
  unavailable.service.bindCurrentDetailDocument(pin); await flush();
  for (let i = 0; i < unavailable.timers.length; i++) { unavailable.timers[i].fn(); await flush(); }
  unavailable.service.clearBinding(); unavailable.state.result = 'true';
  unavailable.service.bindCurrentDetailDocument(pin); await flush();
  assert.equal(unavailable.calls.length, 5, 'a later valid ready event can bind after bounded false retries');
  const synchronous = makeHarness({ throwSync: true });
  assert.doesNotThrow(() => synchronous.service.bindCurrentDetailDocument(pin), 'synchronous Web controller failures are handled');
  for (let i = 0; i < synchronous.timers.length; i++) { synchronous.timers[i].fn(); await flush(); }
  console.log('Detail document rebind: old reads settle promptly, writes never replay, current Pin recovery once, no timeout replay, bounded snapshot refresh and stale/cache guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
