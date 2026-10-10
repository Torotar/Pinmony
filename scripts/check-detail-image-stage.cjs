const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const timers = [], marks = [], calls = [];
const source = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailImageStage.ets', 'utf8');
const compiledExports = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: compiledExports, require: () => ({}) });
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const pin = 'https://www.pinterest.com/pin/101/';
  const detail = { pinUrl: pin, session: 2, imageUrl: 'https://i.pinimg.com/formal.jpg', imageStageReady: false };
  let openingToken = 1, actionsReady = false, nativeBackTarget = '';
  const ports = { enabled: () => true, detail: () => detail, actionsReady: () => actionsReady,
    openingToken: () => openingToken, hasNativeBackTarget: () => !!nativeBackTarget,
    runScript: async script => { calls.push(script); return 'true'; },
    schedule(fn, delay) { timers.push({ fn, delay, cancelled: false }); return timers.length; },
    cancel(id) { if (timers[id - 1]) timers[id - 1].cancelled = true; },
    markJourney: event => marks.push(event), setError: message => { detail.error = message; } };
  const stage = new compiledExports.PinmonyDetailImageStage(ports);
  const n = { sync: (loaded, failed) => stage.sync(loaded, failed), signal: value => stage.signal(value) };
  n.sync('https://i.pinimg.com/thumbnail.jpg', ''); assert.equal(calls.length, 0, 'opening cache cannot authorize interactions');
  actionsReady = true; n.sync('https://i.pinimg.com/thumbnail.jpg', '');
  assert.equal(calls.length, 0, 'a different thumbnail is not the formal image');
  n.sync(detail.imageUrl, ''); await flush();
  assert.equal(calls.length, 1); assert(calls[0].includes('"loaded"'));
  n.sync(detail.imageUrl, ''); await flush(); assert.equal(calls.length, 1, 'repeat completions are deduplicated');
  openingToken = 2; detail.imageUrl = 'https://i.pinimg.com/new.jpg'; detail.imageStageReady = false;
  n.sync('', ''); const deadline = timers.findLast(t => t.delay === 2500);
  n.sync('', detail.imageUrl); await flush();
  assert.equal(calls.length, 2); assert(calls[1].includes('"failed"'));
  openingToken = 3; detail.imageUrl = 'https://i.pinimg.com/slow.jpg'; detail.imageStageReady = false;
  n.sync('', ''); const currentDeadline = timers.findLast(t => t.delay === 2500);
  deadline.fn(); await flush(); assert.equal(calls.length, 2, 'old deadline cannot release another image');
  currentDeadline.fn(); await flush(); assert.equal(calls.length, 3); assert(calls[2].includes('"timeout"'));
  nativeBackTarget = 'https://www.pinterest.com/';
  n.signal('loaded'); await flush(); assert.equal(calls.length, 3);
  nativeBackTarget = ''; stage.reset(); ports.runScript = async () => 'false';
  n.sync(detail.imageUrl, '');
  for (let attempt = 0; attempt < 8; attempt++) {
    n.signal('loaded'); await flush();
    const retry = timers.findLast(t => t.delay === 250 && !t.cancelled && !t.ran);
    if (retry) { retry.ran = true; retry.fn(); await flush(); }
  }
  assert(detail.error);
  assert(marks.includes('main.image.bridge.unavailable'), 'unavailable bridge ends bounded automatic attempts with truthful error');
  stage.reset(); detail.error = ''; ports.runScript = () => { throw new Error('controller unavailable'); };
  n.sync('', '');
  assert.doesNotThrow(() => n.signal('loaded'));
  assert(marks.includes('main.image.bridge.failed'), 'synchronous Web controller failure is reported without escaping image callback');
  const apiSource = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets', 'utf8');
  const script = Function('return `' + apiSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  const requests = [], window = { PinmonyDetailApiEnabled: true }; window.top = window;
  vm.runInNewContext(script, { window, location: { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com' },
    AbortController, console, setTimeout() {}, clearTimeout() {}, fetch: () => new Promise(resolve => requests.push(resolve)) });
  const api = window.PinmonyDetailApi;
  api.read(pin, () => {}, () => true);
  requests[0]({ ok: true, json: async () => ({ resource_response: { status: 'success', data: {
    id: '101', type: 'pin', images: { '736x': { url: 'https://i.pinimg.com/formal.jpg', width: 736, height: 1000 } }
  } } }) }); await flush();
  const bridgeSource = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailScript.ets', 'utf8');
  const bridge = Function('return `' + bridgeSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  const imageFunction = bridge.match(/  window.PinmonyDetailImageStage = function[\s\S]*?\n  };/)[0];
  vm.runInNewContext(imageFunction, { window, session: 2, activePin: pin, pinUrl: () => pin });
  assert.equal(window.PinmonyDetailImageStage(1, pin, 'https://i.pinimg.com/formal.jpg', 'loaded'), false);
  assert.equal(window.PinmonyDetailImageStage(2, pin, 'https://i.pinimg.com/thumbnail.jpg', 'loaded'), false);
  assert.equal(window.PinmonyDetailImageStage(2, pin, 'https://i.pinimg.com/formal.jpg', 'timeout'), true);
  assert.equal(api.read(pin, () => {}, () => true).imageLoaded, false);
  assert.equal(window.PinmonyDetailImageStage(2, pin, 'https://i.pinimg.com/formal.jpg', 'loaded'), true);
  assert.equal(api.read(pin, () => {}, () => true).imageLoaded, true, 'actual completion after timeout upgrades image success');
  assert.equal(api.loadMore(), false, 'comment phase is still pending');
  api.reset(); assert.equal(window.PinmonyDetailImageStage(2, pin, 'https://i.pinimg.com/formal.jpg', 'loaded'), false);
  console.log('Detail image stage: formal/thumbnail distinction, repeat, error, bounded deadline, stale timer, return and bridge identity passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
