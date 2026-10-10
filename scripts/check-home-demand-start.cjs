const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function script(file) { return Function('return `' + fs.readFileSync(file, 'utf8').match(/`([\s\S]*?)`;/)[1] + '`')(); }
const api = script('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets');
const bridge = script('feature_home/src/main/ets/services/PinmonyHomeScript.ets');
const fixture = JSON.parse(fs.readFileSync('scripts/fixtures/home-api.json', 'utf8'));
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness() {
  let ready = false, selected = true;
  const requests = [], timers = [], messages = [], events = {};
  const location = { href: 'https://www.pinterest.com/', origin: 'https://www.pinterest.com',
    hostname: 'www.pinterest.com', pathname: '/' };
  const main = { querySelectorAll: () => ready ? [all, category] : [] };
  function tab(name, id) {
    return { id, isConnected: true, parentElement: main, textContent: name, innerText: name,
      getAttribute: key => key === 'aria-selected' ? String(id === 'homefeed' && selected) : '',
      getBoundingClientRect: () => ({ width: ready ? 70 : 0, height: ready ? 36 : 0, top: 50 }),
      querySelector: () => null, closest: () => null };
  }
  let all = tab('全部', 'homefeed');
  const category = tab('设计', 'category');
  main.querySelectorAll = selector => selector === 'a[href*="/pin/"]' ? [] : ready ? [all, category] : [];
  const window = { PinmonyHomeApiEnabled: true, PinmonyShareBridge: { homeState: data => messages.push(JSON.parse(data)) },
    addEventListener(name, callback) { events[name] = callback; }, setInterval() {} }; window.top = window;
  const document = { documentElement: {}, body: main,
    getElementById: id => id === 'homefeed' ? all : null,
    querySelector: () => main, querySelectorAll: () => [], addEventListener() {} };
  const context = { window, document, location, URL, AbortController, innerHeight: 800, innerWidth: 400,
    getComputedStyle: () => ({ display: 'block', visibility: 'visible', opacity: '1' }),
    MutationObserver: class { observe() {} }, console: { warn() {} }, clearTimeout() {},
    setTimeout: callback => { timers.push(callback); return timers.length; },
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })) };
  vm.runInNewContext(api + bridge, context);
  function sync() { window.PinmonyHomeRefresh(); timers.splice(0).filter(fn => fn.name === 'sync').forEach(fn => fn()); }
  return { window, location, requests, messages, events, sync, layout: () => { ready = true; },
    replaceNode: () => { all.isConnected = false; all = tab('全部', 'homefeed'); }, deselect: () => { selected = false; } };
}
async function main() {
  const h = harness(); h.sync();
  assert.equal(h.requests.length, 0, 'document startup alone cannot issue authenticated home demand');
  assert.equal(h.window.PinmonyHomeDemand('https://www.pinterest.com/pin/1/'), false);
  assert.equal(h.requests.length, 0, 'wrong-page demand is rejected');
  h.window.PinmonyHomeDemand(h.location.href);
  assert.equal(h.requests.length, 1, 'selected homefeed starts its current-page request before layout');
  assert.equal(h.messages.length, 0, 'unlaid-out controls do not produce fake tabs or actionable snapshots');
  h.sync(); assert.equal(h.requests.length, 1, 'repeated demand checks do not duplicate the request');
  h.replaceNode();
  h.requests[0].resolve({ ok: true, json: async () => fixture }); await flush();
  h.layout(); h.sync();
  assert.equal(h.requests.length, 1, 'normal control binding adopts the same validated request without refetch');
  assert.equal(h.messages.at(-1).kind, 'state');
  assert.equal(h.messages.at(-1).dataSource, 'api');
  assert.equal(h.messages.at(-1).pins.length, 21);
  assert.equal(h.messages.at(-1).tabs[0].label, '全部', 'labels still come from actual controls');
  const messagesBeforeFreeze = h.messages.length;
  h.events.pagehide({ persisted: true }); h.events.pageshow({ persisted: true }); h.sync();
  assert.equal(h.messages.length, messagesBeforeFreeze, 'frozen document cannot enable old controls before auth rebind');
  h.window.PinmonyHomeDemand(h.location.href); h.sync();
  assert.equal(h.requests.length, 1, 'restored document keeps completed home data instead of repeating first-page GET');
  assert.equal(h.messages.at(-1).kind, 'state');
  assert.equal(h.messages.at(-1).pins.length, 21);
  assert.ok(h.messages.length > messagesBeforeFreeze, 'resume republishes current controls even when feed is unchanged');
  const interrupted = harness(); interrupted.window.PinmonyHomeDemand(interrupted.location.href);
  interrupted.events.pagehide({ persisted: true });
  assert.equal(interrupted.requests[0].options.signal.aborted, true, 'freeze cancels incomplete read');
  interrupted.events.pageshow({ persisted: true }); interrupted.window.PinmonyHomeDemand(interrupted.location.href);
  assert.equal(interrupted.requests.length, 2, 'incomplete first page starts one fresh read after rebind');
  interrupted.requests[0].resolve({ ok: true, json: async () => fixture }); await flush();
  interrupted.layout(); interrupted.sync();
  assert.equal(interrupted.messages.filter(message => message.kind === 'state').length, 0, 'pre-freeze reply cannot supply restored data');
  interrupted.requests[1].resolve({ ok: true, json: async () => fixture }); await flush(); interrupted.sync();
  assert.equal(interrupted.messages.at(-1).pins.length, 21);
  const absent = harness(); absent.deselect(); absent.window.PinmonyHomeDemand(absent.location.href);
  assert.equal(absent.requests.length, 0, 'no request is guessed without explicit selected homefeed evidence');
  const left = harness(); left.window.PinmonyHomeDemand(left.location.href);
  left.location.href += 'pin/2/'; left.location.pathname = '/pin/2/'; left.sync();
  left.requests[0].resolve({ ok: true, json: async () => fixture }); await flush();
  assert.equal(left.messages.filter(value => value.kind === 'state').length, 0, 'late response after leaving cannot publish home');
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const start = source.indexOf('  private prefetchHomePinDetails(');
  const method = source.slice(start, source.indexOf('\n  private ', start + 1));
  const context = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: true };
  vm.runInNewContext(ts.transpile('class Native {' + method + '} globalThis.Native=Native;', { target: ts.ScriptTarget.ES2020 }), context);
  const native = new context.Native();
  Object.assign(native, { homeStore: { home: { pageKey: 'https://www.pinterest.com/' }, homeActionsReady: true },
    pinStore: { detailOpeningPin: 'https://www.pinterest.com/pin/1/', videoForeground: true,
      detailPrefetch: { offer() { throw Error('opening detail restarted speculative reads'); } } },
    activeTab: 0, nativeNetworkContext: () => ({ authenticated: true }) });
  native.prefetchHomePinDetails(0, 5);
  assert.match(method, /!this\.pinStore\.detailOpeningPin/, 'in-flight prefetch also rejects an opening detail');
  assert.match(source, /feedActive:[^\n]*!this\.pinStore\.detailOpeningPin/, 'component callbacks stop as soon as opening begins');
  console.log('Home demand start: explicit session trigger, selected node, before-layout request, one request handoff, DOM labels, stale reply and detail-opening prefetch gates passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
