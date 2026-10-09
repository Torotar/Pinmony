const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = index.indexOf('  private tryRestoreAuthenticatedHome(');
const end = index.indexOf('\n  private restoreHomeDiskCache(', start);
const context = { PinWebRuntimeLog: { info() {} } };
vm.runInNewContext(ts.transpileModule('class Native {' + index.slice(start, end) +
  '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
const native = new context.Native(), restores = [];
Object.assign(native, { authStatus: 'authenticated', activeTab: 0, pinStore: {}, boardStore: {},
  restoreHomeDiskCache: (...args) => restores.push(args) });
native.tryRestoreAuthenticatedHome('', '/');
assert.equal(restores.length, 0);
native.tryRestoreAuthenticatedHome('account-a', '/');
native.tryRestoreAuthenticatedHome('account-a', '/');
assert.equal(restores.length, 1, 'late identity restores once per account and page');
native.homeStartupFeedCommitted = true;
native.tryRestoreAuthenticatedHome('account-b', '/');
assert.equal(restores.length, 1, 'new network content cannot be replaced by cache');
native.homeStartupFeedCommitted = false;
native.activeTab = 1;
native.tryRestoreAuthenticatedHome('account-b', '/');
assert.equal(restores.length, 1, 'another visible root is not replaced');
const source = fs.readFileSync('feature_profile/src/main/ets/services/PinWebProfileApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
async function profileCase(boardsFirst) {
  const requests = [], window = { PinWebProfileApiEnabled: true, PinWebHomeUsername: 'sample' };
  window.top = window;
  const profile = 'https://www.pinterest.com/sample/';
  vm.runInNewContext(script, { window, URL, AbortController, Date,
    location: { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/sample/' },
    setTimeout: () => 1, clearTimeout() {}, console,
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })) });
  const api = window.PinWebProfileApi, changed = () => {}, current = () => true;
  api.read(profile, changed, current);
  assert.equal(api.prefetchSaved(profile, 'saved', current), true);
  assert.equal(requests.length, 2, 'saved request starts before profile finishes');
  assert.equal(api.prefetchSaved(profile, 'saved', current), false, 'duplicate preparation is joined');
  const user = () => requests[0].resolve({ ok: true, json: async () => ({ resource_response: {
    status: 'success', data: { type: 'user', id: '123', username: 'sample', pin_count: 406 }
  }, client_context: { user: { id: '123' } } }) });
  const boards = () => requests[1].resolve({ ok: true, json: async () => ({ resource_response: {
    status: 'success', bookmark: '-end-', data: [{ type: 'story', id: '10', story_type: 'all_pins',
      title: { format: '所有 Pin 图' }, action: { url: '/users/123/pins/' }, objects: [] }]
  } }) });
  if (boardsFirst) { boards(); await flush(); assert.equal(api.read(profile, changed, current).kind, 'loading'); }
  user(); await flush();
  api.readContent(profile, 'saved', changed, current);
  assert.equal(requests.length, 2, 'prepared response does not cause another request');
  if (!boardsFirst) boards();
  await flush();
  assert.equal(api.readContent(profile, 'saved', changed, current).items[0].pinCount, '406 张 Pin 图');
  api.reset(); api.read(profile, changed, current);
  assert.equal(api.prefetchSaved(profile, 'saved', current), true);
  api.suspend();
  assert.equal(requests.at(-1).options.signal.aborted, true, 'leaving cancels saved preparation');
  api.reset(); window.PinWebHomeUsername = 'someone-else'; api.read(profile, changed, current);
  assert.equal(api.prefetchSaved(profile, 'saved', current), false, 'foreign profiles do not speculate');
  assert.equal(api.prefetchSaved(profile, 'created', current), false, 'created feed waits for confirmed owner');
  api.reset();
}
Promise.resolve().then(() => profileCase(true)).then(() => profileCase(false))
  .then(() => console.log('Root startup readiness checks passed'))
  .catch(error => { console.error(error); process.exitCode = 1; });
