const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const code = name => Function('return ' + fs.readFileSync('feature_profile/src/main/ets/services/' + name + '.ets', 'utf8').match(/SCRIPT: string = (`[\s\S]*`);/)[1])();
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  let now = 1000, serial = 0;
  class Clock extends Date { static now() { return now; } }
  const requests = [], timers = new Map(), events = {}, messages = [];
  const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/sample/', href: 'https://www.pinterest.com/sample/' };
  const window = { PinmonyProfileApiEnabled: true, PinmonyProfileOrganizeEnabled: true,
    PinmonySpeculativeReadsEnabled: false, setInterval() {},
    addEventListener(name, fn) { (events[name] ||= []).push(fn); },
    PinmonyShareBridge: { profileState: raw => messages.push(JSON.parse(raw)) } }; window.top = window;
  const context = vm.createContext({ window, location, navigator: { language: 'zh' }, URL, Date: Clock, AbortController, console,
    setTimeout(fn, delay) { const id = ++serial; timers.set(id, { fn, delay }); return id; }, clearTimeout(id) { timers.delete(id); },
    fetch(url, options) { return new Promise((resolve, reject) => requests.push({ url, options, resolve, reject })); } });
  for (const name of ['PinmonyProfileApiScript', 'PinmonyProfileOrganizeScript', 'PinmonyProfileScript']) vm.runInContext(code(name), context);
  const tick = () => { for (const [id, timer] of [...timers]) if (timer.delay === 0) { timers.delete(id); timer.fn(); } };
  const reply = async (index, data, bookmark = 'next') => {
    requests[index].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0, data, bookmark }, client_context: { user: { id: '123' } } }) });
    await flush();
  };
  tick(); assert.equal(requests.length, 1, 'profile starts without DOMContentLoaded or MutationObserver');
  await reply(0, { type: 'user', id: '123', username: 'sample' }); tick();
  assert.equal(requests.length, 3, 'boards and unorganized pins load independently after verified identity');
  await reply(1, [{ type: 'board', id: '42', name: 'Board', url: '/sample/board/' }]);
  await reply(2, []); tick();
  const api = window.PinmonyProfileApi, page = location.href, read = section => api.readContent(page, section, () => {}, () => true);
  const oldId = read('saved').items[0].id;
  read('created'); api.readUnorganized(page, 'created', () => {}, () => true);
  await reply(3, []); assert.equal(read('created').ready, true);
  assert.equal(read('saved').ready, true); assert.equal(api.open(oldId), false);
  assert.equal(read('created').ready, true); assert.equal(read('saved').ready, true);
  api.readUnorganized(page, 'saved', () => {}, () => true);
  assert.equal(requests.length, 4, 'both completed sections and empty unorganized list survive section switches');
  now += 300001;
  read('created'); assert.equal(read('saved').loading, true, 'cache expires from successful read time');
  const canceledIndex = requests.length - 1;
  requests[canceledIndex].reject({ pinmonyCancelled: true }); await flush();
  assert.equal(read('saved').error, ''); assert.equal(requests.length, canceledIndex + 2, 'canceled content resumes on fresh demand');
  events.pagehide.forEach(fn => fn());
  assert.equal(requests.at(-1).options.signal.aborted, true);
  api.reset();
  console.log('Profile loading: DOM-independent start, parallel feeds, section cache/IDs/expiry, empty retention and cancellation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
