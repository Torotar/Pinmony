const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const begin = source.search(new RegExp('^  private (?:async )?' + name + '\\(', 'm'));
  assert(begin >= 0, name);
  const rest = source.slice(begin);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
async function main() {
  for (const kind of ['search', 'inbox']) {
    const timers = [], requests = [];
    const timeout = (fn, ms) => { timers.push({ fn, ms }); return timers.length; };
    const runtime = require('./search-controller-harness.cjs').createSearchRuntime(ts, { setTimeout: timeout, clearTimeout() {} });
    const code = ts.transpileModule('class Native {' + ['finishRootPull', 'pullRefreshRoot', 'refreshSearch', 'retryInbox']
      .map(method).join('\n') + '} Native;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
    const Native = vm.runInNewContext(code, { setTimeout: timeout });
    const native = new Native(); let response = 'true';
    Object.assign(native, { authStatus: 'authenticated', rootPullKind: '', rootPullToken: 0,
      searchStore: new runtime.Store(), inboxStore: {},
      currentSearchPageKey: () => 'https://www.pinterest.com/search/?q=art',
      currentInboxUrl: () => 'https://www.pinterest.com/inbox/', expectInbox() {},
      controller: { runJavaScript: async script => { requests.push(script); return response; } } });
    native.searchStore.search = { session: 1, pageKey: native.currentSearchPageKey() };
    runtime.bindIndex(native);
    await native.pullRefreshRoot(kind);
    assert.equal(native.rootPullKind, kind, 'bridge acknowledgement does not finish the refresh');
    await native.pullRefreshRoot(kind);
    assert.equal(requests.length, 1, 'duplicate gestures do not repeat reads');
    assert.match(requests[0], kind === 'search' ? /PinmonySearchRefresh\(1,/ : /PinmonyInboxApiRefresh/);
    native.finishRootPull(kind); await native.pullRefreshRoot(kind);
    const pullTimers = timers.filter(t => t.ms === 20000);
    pullTimers[0].fn(); assert.equal(native.rootPullKind, kind, 'old timeout cannot stop a newer pull');
    pullTimers[1].fn(); assert.equal(native.rootPullKind, '');
    assert.match(kind === 'search' ? native.searchStore.searchError : native.inboxStore.inboxError, /超时/);
    response = 'false'; await native.pullRefreshRoot(kind);
    assert.equal(native.rootPullKind, '', 'rejected refresh ends animation');
    native.authStatus = 'signedOut'; const count = requests.length;
    await native.pullRefreshRoot(kind); assert.equal(requests.length, count);
    native.searchController.invalidatePending();
  }
  console.log('Search/inbox pull refresh dispatch, duplicate guard, failure, timeout and auth checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
