const { readSourceFileSync } = require('./source-files.cjs');
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
const code = ts.transpileModule('class Native {' + method('usesNativeProfileReads') + method('finishProfilePull') + method('refreshProfile') +
  '} globalThis.Native=Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
async function main() {
  const timers = [], context = { PIN_NATIVE_PROFILE_READS_ENABLED: false, setTimeout: fn => timers.push(fn) }; require('./product-coordination-harness.cjs').run(ts,code, context);
  const native = require('./product-coordination-harness.cjs').createHost(context.Native, ts); const requests = [];
  native.profileStore = Object.assign(native.profileStore, { profileRequestToken: 0, profileSession: 0, origins: [] });
  native.authStatus = 'authenticated';
  // Exercise the retained legacy read controller; native reads have their own contract test.
  native.profileNativeReads = { eligible: () => false };
  const profile = { profileUrl: 'https://www.pinterest.com/sample/', section: 'saved', boards: [{ id: '1' }] };
  Object.assign(native, {
    currentProfileUrl: () => profile.profileUrl,
    controller: { getUrl: () => profile.profileUrl, runJavaScript: async (script) => requests.push(script) },
    profileStore: Object.assign(native.profileStore, {
        profile: profile,
        profilePullRefreshing: false,
        profilePullToken: 0,
        profileActionsReady: false,
        profileCache: { put() { }, clear() { } }
    })
});
  require('./profile-read-controller-harness.cjs').bind(native, ts, { setTimeout: fn => timers.push(fn), clearTimeout() {} });
  native.refreshProfile(true);
  assert.equal(native.profileStore.profilePullRefreshing, true, 'retained profile can refresh before business actions become ready');
  native.profileStore.profileActionsReady = true; // A cached snapshot can become ready while the request is pending.
  native.refreshProfile(true);
  assert.equal(requests.length, 1, 'programmatic refreshing callback cannot start another request');
  native.finishProfilePull();
  assert.equal(native.profileStore.profilePullRefreshing, false);
  native.refreshProfile(true);
  timers[0]();
  assert.equal(native.profileStore.profilePullRefreshing, true, 'expired timeout cannot stop a newer pull');
  timers[1]();
  assert.equal(native.profileStore.profilePullRefreshing, false);
  assert.match(native.profileStore.profileError, /超时/);
  assert.equal(native.profileStore.profile, profile, 'timeout preserves existing cards');
  native.controller.runJavaScript = async () => { throw new Error('bridge failure'); };
  native.refreshProfile(true); await new Promise(resolve => setImmediate(resolve));
  assert.equal(native.profileStore.profilePullRefreshing, false, 'bridge rejection ends the spinner');
  const pageSource = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
  assert(pageSource.includes('.pullToRefresh(this.interactionReady && !this.refreshing && !this.loading)'),
    'gesture availability follows visible interaction instead of stale action readiness');
  console.log('Profile pull refresh duplicate, completion, stale timeout and failure checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
