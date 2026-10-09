const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const method = name => source.match(new RegExp('  private ' + name + '\\([\\s\\S]*?(?=\\r?\\n  private )'))[0];
const timers = [], marks = [], calls = [];
const context = { PIN_DETAIL_API_ENABLED: true,
  setTimeout(fn, delay) { timers.push({ fn, delay }); return timers.length; }, clearTimeout() {} };
vm.runInNewContext(ts.transpileModule(`class Native {
  ${method('syncDetailImageStage')}
  ${method('signalDetailImageStage')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const n = new context.Native();
  const pin = 'https://www.pinterest.com/pin/101/';
  Object.assign(n, { pinStore: { detailPin: pin, detailOpeningToken: 1, detailActionsReady: false,
    detail: { pinUrl: pin, session: 2, imageUrl: 'https://i.pinimg.com/formal.jpg', imageStageReady: false } },
    pageTasks: { timeout(fn, delay) { timers.push({ fn, delay }); return timers.length; }, cancelTimeout() {} },
    nativeBackTarget: '', detailImageTimer: -1, detailImageBinding: '', detailImageSignal: '',
    detailImageLoadedUrl: 'https://i.pinimg.com/thumbnail.jpg', detailImageFailedUrl: '',
    detailJourney: { mark: event => marks.push(event) },
    controller: { runJavaScript: async script => { calls.push(script); return 'true'; } } });
  n.syncDetailImageStage(); assert.equal(calls.length, 0, 'opening cache cannot authorize interactions');
  n.pinStore.detailActionsReady = true; n.syncDetailImageStage();
  assert.equal(calls.length, 0, 'a different thumbnail is not the formal image');
  n.detailImageLoadedUrl = n.pinStore.detail.imageUrl; n.syncDetailImageStage(); await flush();
  assert.equal(calls.length, 1); assert(calls[0].includes('"loaded"'));
  n.syncDetailImageStage(); await flush(); assert.equal(calls.length, 1, 'repeat completions are deduplicated');
  n.pinStore.detailOpeningToken = 2; n.pinStore.detail.imageUrl = 'https://i.pinimg.com/new.jpg';
  n.syncDetailImageStage(); const deadline = timers.findLast(t => t.delay === 2500);
  n.detailImageFailedUrl = n.pinStore.detail.imageUrl; n.syncDetailImageStage(); await flush();
  assert.equal(calls.length, 2); assert(calls[1].includes('"failed"'));
  n.pinStore.detailOpeningToken = 3; n.pinStore.detail.imageUrl = 'https://i.pinimg.com/slow.jpg';
  n.syncDetailImageStage(); const currentDeadline = timers.findLast(t => t.delay === 2500);
  deadline.fn(); await flush(); assert.equal(calls.length, 2, 'old deadline cannot release another image');
  currentDeadline.fn(); await flush(); assert.equal(calls.length, 3); assert(calls[2].includes('"timeout"'));
  n.nativeBackTarget = 'https://www.pinterest.com/'; n.detailImageSignal = '';
  n.signalDetailImageStage('loaded'); await flush(); assert.equal(calls.length, 3);
  n.nativeBackTarget = ''; n.detailImageSignal = ''; n.detailImageBridgeAttempts = 0;
  n.controller.runJavaScript = async () => 'false';
  for (let attempt = 0; attempt < 8; attempt++) { n.signalDetailImageStage('loaded'); await flush(); }
  assert.equal(n.detailImageBridgeAttempts, 8); assert(n.pinStore.detailApiError);
  assert(marks.includes('main.image.bridge.unavailable'), 'unavailable bridge ends bounded automatic attempts with truthful error');
  n.detailImageSignal = ''; n.controller.runJavaScript = () => { throw new Error('controller unavailable'); };
  assert.doesNotThrow(() => n.signalDetailImageStage('loaded'));
  assert(marks.includes('main.image.bridge.failed'), 'synchronous Web controller failure is reported without escaping image callback');
  const apiSource = fs.readFileSync('feature_pin/src/main/ets/services/PinWebDetailApiScript.ets', 'utf8');
  const script = Function('return `' + apiSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  const requests = [], window = { PinWebDetailApiEnabled: true }; window.top = window;
  vm.runInNewContext(script, { window, location: { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com' },
    AbortController, console, setTimeout() {}, clearTimeout() {}, fetch: () => new Promise(resolve => requests.push(resolve)) });
  const api = window.PinWebDetailApi;
  api.read(pin, () => {}, () => true);
  requests[0]({ ok: true, json: async () => ({ resource_response: { status: 'success', data: {
    id: '101', type: 'pin', images: { '736x': { url: 'https://i.pinimg.com/formal.jpg', width: 736, height: 1000 } }
  } } }) }); await flush();
  const bridgeSource = fs.readFileSync('feature_pin/src/main/ets/services/PinWebDetailScript.ets', 'utf8');
  const bridge = Function('return `' + bridgeSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  const imageFunction = bridge.match(/  window.PinWebDetailImageStage = function[\s\S]*?\n  };/)[0];
  vm.runInNewContext(imageFunction, { window, session: 2, activePin: pin, pinUrl: () => pin });
  assert.equal(window.PinWebDetailImageStage(1, pin, 'https://i.pinimg.com/formal.jpg', 'loaded'), false);
  assert.equal(window.PinWebDetailImageStage(2, pin, 'https://i.pinimg.com/thumbnail.jpg', 'loaded'), false);
  assert.equal(window.PinWebDetailImageStage(2, pin, 'https://i.pinimg.com/formal.jpg', 'timeout'), true);
  assert.equal(api.read(pin, () => {}, () => true).imageLoaded, false);
  assert.equal(window.PinWebDetailImageStage(2, pin, 'https://i.pinimg.com/formal.jpg', 'loaded'), true);
  assert.equal(api.read(pin, () => {}, () => true).imageLoaded, true, 'actual completion after timeout upgrades image success');
  assert.equal(api.loadMore(), false, 'comment phase is still pending');
  api.reset(); assert.equal(window.PinWebDetailImageStage(2, pin, 'https://i.pinimg.com/formal.jpg', 'loaded'), false);
  console.log('Detail image stage: formal/thumbnail distinction, repeat, error, bounded deadline, stale timer, return and bridge identity passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
