const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const pin = 'https://www.pinterest.com/pin/101/';
const flush = () => new Promise(resolve => setImmediate(resolve));
const source = file => fs.readFileSync(file, 'utf8');
const script = file => Function('return `' + source(file).match(/= `([\s\S]*?)`;/)[1] + '`')();
function method(text, name) {
  const start = text.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  return text.slice(start, text.indexOf('\n  private ', start + 1));
}
async function main() {
  const requests = [], timers = new Map(), listeners = {};
  let serial = 0, interval;
  const window = { PinmonyDetailApiEnabled: true, addEventListener: (name, fn) => { listeners[name] = fn; },
    setInterval: fn => { interval = fn; }, PinmonyShareBridge: { detailState() {} },
    PinmonyPostApi: { reset() {}, detailActions: () => [], previewRead: () => ({ loading: false, empty: true }) } };
  window.top = window;
  window.fetch = (url, args) => new Promise(resolve => requests.push({ url, args, resolve }));
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/pin/101/', href: pin };
  const context = vm.createContext({ window, location, URL, AbortController, console,
    document: { documentElement: null, addEventListener() {}, querySelectorAll: () => [] },
    setTimeout(fn, delay) { const id = ++serial; timers.set(id, { fn, delay }); return id; },
    clearTimeout(id) { timers.delete(id); }, fetch: (...args) => window.fetch(...args) });
  vm.runInContext(script('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets'), context);
  vm.runInContext(script('feature_pin/src/main/ets/services/PinmonyDetailScript.ets'), context);
  function tick(delay) {
    const entry = [...timers.entries()].find(([, timer]) => timer.delay === delay);
    assert(entry, 'expected timer ' + delay); timers.delete(entry[0]); entry[1].fn();
  }
  tick(0); assert.equal(requests.length, 1);
  requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: {
    type: 'pin', id: '101', images: { '736x': { url: 'https://i.pinimg.com/1.jpg', width: 736, height: 1000 } }
  } } }) }); await flush();
  assert(window.PinmonyDetailImageStage(1, pin, 'https://i.pinimg.com/1.jpg', 'loaded'));
  tick(0);
  const queuedRelated = [...timers.values()].find(timer => timer.delay === 0);
  assert(queuedRelated || requests.length > 1, 'comments settled and recommendations are scheduled or already in flight');
  const requestsBeforePause = requests.length;
  assert.equal(window.PinmonyDetailPause('https://www.pinterest.com/pin/999/'), false);
  assert.equal(window.PinmonyDetailPause(pin), true);
  if (queuedRelated) queuedRelated.fn(); interval(); window.PinmonyDetailRefresh(); await flush();
  assert.equal(requests.length, requestsBeforePause, 'paused old document cannot schedule another base/preview/recommendation read');
  assert.equal(window.PinmonyDetailApi.raw(pin), null);
  window.PinmonyDetailRefresh(true); tick(0);
  assert.equal(requests.length, requestsBeforePause + 1, 'native confirmed refresh explicitly resumes and revalidates the current document');
  window.PinmonyDetailPause(pin);
  requests[1].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: {
    type: 'pin', id: '101', images: { '736x': { url: 'https://i.pinimg.com/late.jpg', width: 736, height: 1000 } }
  } } }) }); await flush();
  assert.equal(window.PinmonyDetailApi.raw(pin), null, 'late HTTP 200 cannot revive a paused document');

  const index = source('entry/src/main/ets/pages/Index.ets');
  const host = { PIN_NATIVE_NETWORK_ENABLED: true, PinmonyRuntimeLog: { info() {} } };
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Native { ${method(index, 'requestNativeNetwork')} }
    globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, host);
  const native = new host.Native(), calls = [];
  Object.assign(native, { nativeBackTarget: 'https://www.pinterest.com/', pinStore: { detailPin: pin, detail: {} },
    pageHistory: { isPending: () => false },
    extractPinUrl: value => /\/pin\/\d+/.test(value) ? value : '',
    pinIdentity: value => String(value).match(/\/pin\/(\d+)/)?.[1] || '',
    controller: { runJavaScript: async value => { calls.push(value); } },
    detailNetworkReply() { throw Error('departed read reached RCP'); } });
  for (const resource of ['UnifiedCommentsPreviewResource', 'RelatedModulesResource']) {
    native.requestNativeNetwork(JSON.stringify({ id: resource, epoch: 1, page: pin,
      url: 'https://www.pinterest.com/resource/' + resource + '/get/', method: 'GET' }));
  }
  assert.equal(calls.length, 2);
  native.nativeBackTarget = ''; native.pageHistory.isPending = () => true;
  native.requestNativeNetwork(JSON.stringify({ id: 'uncached-parent-return', epoch: 1, page: pin,
    url: 'https://www.pinterest.com/resource/RelatedModulesResource/get/', method: 'GET' }));
  assert.equal(calls.length, 3, 'pending return is guarded even without a cached native parent');
  assert(calls.every(value => value.includes('"error":"cancelled"')));
  const returning=method(index,'backOnePage');
  assert(returning.indexOf('window.PinmonyDetailPause(') >= 0 && returning.indexOf('window.PinmonyDetailPause(') < returning.indexOf('this.presentNativeBackTarget(target);'),
    'pause is queued before target navigation invalidates the old requests');

  const page = source('feature_pin/src/main/ets/components/PinmonyDetailPage.ets');
  const componentHost = {};
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Page { ${method(page, 'notifyImageLoaded')} }
    globalThis.Page = Page;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, componentHost);
  const component = new componentHost.Page(), images = [];
  component.detail={pinUrl:'',imageUrl:''};component.renderIdentity = 'opening-1'; component.onImageLoaded = (...args) => images.push(args);
  for (let i = 0; i < 100; i++) component.notifyImageLoaded(pin, 'https://i.pinimg.com/1.jpg');
  assert.equal(images.length, 1);
  component.renderIdentity = 'state-1'; component.notifyImageLoaded(pin, 'https://i.pinimg.com/1.jpg');
  component.renderIdentity = 'opening-2'; component.notifyImageLoaded(pin, 'https://i.pinimg.com/1.jpg');
  component.notifyImageLoaded(pin, 'https://i.pinimg.com/2.jpg');
  assert.equal(images.length, 4, 'formal binding, reopening and image changes still each notify');
  const postScript = script('feature_pin/src/main/ets/services/PinmonyPostApiScript.ets');
  const actionsFunction = postScript.match(/detailActions: function[\s\S]*?(?=\n    like: function)/)[0];
  let base = { reaction_by_me: 0, reaction_counts: { '1': 0 } };
  const actionHost = { window: {}, raw: () => base, current: () => true, aggregate: () => '',
    reaction: null, likeBusy: false };
  require('./product-coordination-harness.cjs').run(ts,'globalThis.actions = ({' + actionsFunction + '}).detailActions;', actionHost);
  for (const count of [0, 12, -1, 1.5, Infinity, '2', undefined]) {
    base = { reaction_by_me: 0, reaction_counts: { '1': count } };
    const like = actionHost.actions(pin, [], () => {}).find(item => item.kind === 'like');
    assert.equal(like.countText, count === 0 || count === 12 ? String(count) : '',
      'only validated integer counts, including zero, can be displayed');
  }
  base = { reaction_data: { reaction_by_me: 0 }, reaction_counts: { '1': 12 } };
  assert.equal(actionHost.actions(pin, [], () => {}).find(item => item.kind === 'like').countText, '12',
    'nested selected-state metadata does not hide an authoritative top-level count');
  const jobs = [], netWindow = { addEventListener() {}, fetch: async () => { throw Error('Web replay'); },
    PinmonyNativeNetworkEnabled: true, PinmonyShareBridge: { networkRequest: value => jobs.push(JSON.parse(value)) } };
  netWindow.top = netWindow;
  const netContext = vm.createContext({ window: netWindow, location, URL, Headers, Response,
    console: { warn() {} }, setTimeout, clearTimeout });
  vm.runInContext(script('common_network/src/main/ets/PinmonyNetworkScript.ets'), netContext);
  netWindow.PinmonyNetwork.bind(1, pin);
  const cancelledRead = netWindow.PinmonyNetwork.fetch('/resource/RelatedModulesResource/get/');
  netWindow.PinmonyNetwork.complete({ ...jobs[0], error: 'cancelled' });
  await assert.rejects(cancelledRead, error => error.name === 'AbortError');
  console.log('Detail departure: queued/late reads, paused polling, BFCache resume, native dispatch barrier and identity-scoped image notifications passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
