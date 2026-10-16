const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const scripts = require('./product-coordination-harness.cjs').runtime(ts)
  .loadFile('entry/src/main/ets/app/PinmonyScriptRegistry.ets').pinWebDocumentStartScripts();
const classifier = scripts[0].script.split('window.PinmonySpeculativeReadsEnabled')[0];
function host(pathname) {
  const events = {}, states = [], calls = [];
  const location = { pathname, href: 'https://www.pinterest.com' + pathname };
  const window = { addEventListener: (name, fn) => { events[name] = fn; },
    PinmonyShareBridge: { sheetState: value => states.push(JSON.parse(value)) },
    PinmonyBoardApi: { shareInfo: page => page === location.href ? { board: true } : null },
    PinmonyProfilePanel: {
      shareCurrent: page => page === location.href,
      shareOpen(page, session, notify) { calls.push('open'); this.callback = notify; notify({ kind: 'state', session, pinUrl: page }); return true; },
      shareSearch: () => { calls.push('search'); return true; },
      shareContact: () => { calls.push('contact'); return true; },
      shareClose: () => calls.push('close')
    }
  };
  window.top = window;
  const context = vm.createContext({ window, location });
  Object.defineProperty(context, 'document', { get() { throw Error('board accessed DOM'); } });
  vm.runInContext(classifier, context);
  return { context, window, location, events, states, calls };
}
for (const path of ['/sample/board/', '/sample/pins/']) {
  const h = host(path);
  assert.equal(h.window.PinmonyBoardDocument, true);
  // Execute the real registered legacy scripts with every DOM access forbidden.
  for (const index of [3, 5, 6, 8, scripts.length - 1]) vm.runInContext(scripts[index].script, h.context);
  assert.equal(h.window.PinmonyNativeShareApiOpen(h.location.href), true);
  assert.equal(h.window.PinmonyNativeShareApiOpen(h.location.href), false);
  const session = h.states[0].session;
  assert.equal(h.window.PinmonyNativeShareSearch(session, 'test'), true);
  assert.equal(h.window.PinmonyNativeShareAction(session, 'contact'), true);
  assert.equal(h.window.PinmonyNativeShareAction(session - 1, 'contact'), false);
  assert.equal(h.window.PinmonyNativeShareClose(session), true);
  assert.equal(h.states.at(-1).kind, 'closed');
  assert.equal(h.window.PinmonyNativeShareApiOpen(h.location.href), true);
  const late = h.window.PinmonyProfilePanel.callback, count = h.states.length;
  h.events.pagehide(); late({ kind: 'state', session: h.states.at(-1).session });
  assert.equal(h.states.length, count, 'departed callbacks are discarded');
}
for (const path of ['/', '/sample/', '/sample/_saved/', '/search/pins/', '/pin/123/', '/login/']) {
  assert.equal(host(path).window.PinmonyBoardDocument, false, 'other documents keep their existing scripts');
}
const share = fs.readFileSync('feature_board/src/main/ets/services/PinmonyBoardShareScript.ets', 'utf8');
assert(!/querySelector|MutationObserver|getElementById|document\./.test(share));
console.log('Board no-DOM: real registry, legacy scripts skipped, API sharing, stale session and pagehide guards passed');
