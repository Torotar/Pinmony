const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const script = name => Function('return ' + fs.readFileSync('feature_search/src/main/ets/services/' + name + '.ets', 'utf8').match(/SCRIPT: string = (`[\s\S]*`);/)[1])();
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness(names, path = '/search/pins/', search = '?q=art') {
  const requests = [], timers = new Map(), events = {}, messages = []; let serial = 0;
  const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: path, search };
  Object.defineProperty(location, 'href', { get: () => location.origin + location.pathname + location.search });
  const window = { PinmonySearchApiEnabled: true, PinmonySearchUiApiEnabled: true, PinmonySearchDiscoveryApiEnabled: true,
    setInterval() {}, addEventListener(name, fn) { (events[name] ||= []).push(fn); },
    PinmonyShareBridge: { searchState: raw => messages.push(JSON.parse(raw)) } }; window.top = window;
  const env = { window, location, document: { cookie: '' }, URL, URLSearchParams, AbortController,
    setTimeout(fn, delay) { const id = ++serial; timers.set(id, { fn, delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    fetch(url, init) { return new Promise((resolve, reject) => requests.push({ url, init, resolve, reject })); } };
  for (const name of names) vm.runInNewContext(script(name), env);
  return { window, location, requests, timers, events, messages,
    tick() { for (const [id, timer] of [...timers]) if (timer.delay === 0) { timers.delete(id); timer.fn(); } } };
}
async function main() {
  const h = harness(['PinmonySearchApiScript', 'PinmonySearchUiApiScript', 'PinmonySearchDiscoveryApiScript', 'PinmonySearchScript']);
  let quizReads = 0; h.window.PinmonySearchQuizApi = { read() { quizReads++; return null; } };
  h.tick();
  assert.equal(h.requests.length, 1, 'result first page does not compete with ghost hint or quiz');
  assert.equal(quizReads, 0);
  const current = h.messages.at(-1);
  assert.equal(h.window.PinmonySearchRefresh(current.session, current.pageKey), true);
  assert.equal(h.requests.length, 1, 'refresh joins in-flight first page');
  assert.equal(h.requests[0].init.signal.aborted, false);
  h.requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: { results: [] } } }) });
  await flush(); h.tick(); assert.equal(quizReads, 1, 'quiz starts after confirmed results, including empty');
  h.window.PinmonySearchUiApi.readSuggestions(h.location.href, '', true, () => {});
  assert.equal(h.requests.length, 2, 'empty history starts without typing debounce');
  h.events.pagehide.forEach(fn => fn());
  assert.equal(h.requests[1].init.signal.aborted, true, 'hidden document cancels suggestion read');
  h.requests[1].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data: { items: [{ query: 'old' }] } } }) });
  await flush();
  h.window.PinmonySearchUiApi.readSuggestions(h.location.href, '', true, () => {});
  assert.equal(h.requests.length, 3, 'canceled suggestion can be read on next current demand');
  assert.equal(h.window.PinmonySearchUiApi.readSuggestions(h.location.href, '', true, () => {}).items.length, 0);
  h.window.PinmonySearchUiApi.reset();
  for (const name of ['PinmonySearchApiScript', 'PinmonySearchDiscoveryApiScript']) {
    const discovery = name.includes('Discovery');
    const c = harness([name], discovery ? '/search/' : '/search/pins/', discovery ? '' : '?q=art');
    const api = c.window[discovery ? 'PinmonySearchDiscoveryApi' : 'PinmonySearchApi'];
    const read = () => api.read(c.location.href, () => {}, () => true);
    read(); c.requests[0].reject({ pinmonyCancelled: true }); await flush();
    const retry = read(); assert.equal(retry.error, ''); assert.equal(c.requests.length, 2);
    assert.equal(api.refresh(), true); assert.equal(c.requests.length, 2, 'duplicate refresh does not restart request');
    api.pause();
  }
  console.log('Search loading: result priority, immediate history, refresh joining, document cancellation and fresh demand passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
