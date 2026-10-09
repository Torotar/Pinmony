const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert.ok(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const code = ts.transpileModule('class Native {' + method('finishProfilePull') + method('refreshProfile') +
  '} globalThis.Native=Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
async function main() {
  const timers = [], context = { setTimeout: fn => timers.push(fn) }; vm.runInNewContext(code, context);
  const native = new context.Native(); const requests = [];
  const profile = { profileUrl: 'https://www.pinterest.com/sample/', section: 'saved', boards: [{ id: '1' }] };
  Object.assign(native, { profile, profilePullRefreshing: false, profilePullToken: 0, profileActionsReady: true,
    profileCache: { put() {}, clear() {} }, currentProfileUrl: () => profile.profileUrl,
    controller: { runJavaScript: async script => requests.push(script) } });
  native.refreshProfile(true);
  assert.equal(native.profilePullRefreshing, true);
  native.profileActionsReady = true; // A cached snapshot can become ready while the request is pending.
  native.refreshProfile(true);
  assert.equal(requests.length, 1, 'programmatic refreshing callback cannot start another request');
  native.finishProfilePull();
  assert.equal(native.profilePullRefreshing, false);
  native.refreshProfile(true);
  timers[0]();
  assert.equal(native.profilePullRefreshing, true, 'expired timeout cannot stop a newer pull');
  timers[1]();
  assert.equal(native.profilePullRefreshing, false);
  assert.match(native.profileError, /超时/);
  assert.equal(native.profile, profile, 'timeout preserves existing cards');
  native.controller.runJavaScript = async () => { throw new Error('bridge failure'); };
  native.refreshProfile(true); await new Promise(resolve => setImmediate(resolve));
  assert.equal(native.profilePullRefreshing, false, 'bridge rejection ends the spinner');
  console.log('Profile pull refresh duplicate, completion, stale timeout and failure checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
