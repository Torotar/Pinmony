const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyProfileApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
new Function(script);
const bridgeSource = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyProfileScript.ets'), 'utf8');
new Function(Function('return `' + bridgeSource.match(/`([\s\S]*?)`;/)[1] + '`')());
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness() {
  const requests = [];
  const window = { PinmonyProfileApiEnabled: true };
  window.top = window;
  let current = true, updates = 0;
  vm.runInNewContext(script, { window, URL, location: { hostname: 'www.pinterest.com', pathname: '/sample/' },
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })),
    AbortController, setTimeout, clearTimeout, console: { warn() {} } });
  const read = (name = 'sample') => window.PinmonyProfileApi.read('https://www.pinterest.com/' + name + '/',
    () => updates++, () => current);
  const respond = async (index, user, status = 200) => {
    requests[index].resolve({ ok: status === 200, json: async () => ({ resource_response: { status: 'success', data: user } }) });
    await flush();
  };
  return { window, requests, read, respond, invalidate: () => { current = false; }, updates: () => updates };
}
async function main() {
  const testing = harness();
  testing.window.PinmonySpeculativeReadsEnabled = false;
  testing.read();
  assert.equal(testing.window.PinmonyProfileApi.prefetchSaved('https://www.pinterest.com/sample/', 'saved', () => true), false);
  assert.equal(testing.requests.length, 1, 'debug mode keeps required profile read but skips saved prefetch');
  testing.invalidate();
  const user = { type: 'user', username: 'sample', full_name: 'Sample', follower_count: 0,
    following_count: 12, image_large_url: 'https://i.pinimg.com/avatar.jpg' };
  const h = harness();
  assert.equal(h.read().kind, 'loading');
  h.read();
  assert.equal(h.requests.length, 1, 'polling does not repeat requests');
  const url = new URL(h.requests[0].url, 'https://www.pinterest.com');
  assert.equal(url.pathname, '/resource/UserResource/get/');
  assert.equal(JSON.parse(url.searchParams.get('data')).options.username, 'sample');
  assert.equal(h.requests[0].options.credentials, 'same-origin');
  assert.equal(h.requests[0].options.headers.Cookie, undefined);
  await h.respond(0, user);
  assert.equal(h.read().info.followers, 0, 'zero is real data');
  assert.equal(h.read().info.name, 'Sample');
  assert.equal(h.updates(), 1);
  h.window.PinmonyProfileApi.reset();
  h.read();
  h.read('other');
  assert.equal(h.requests[1].options.signal.aborted, true, 'navigation cancels old request');
  await h.respond(1, user);
  assert.equal(h.read('other').kind, 'loading', 'late account response is discarded');
  await h.respond(2, user);
  assert.equal(h.read('other').kind, 'failed', 'wrong username is rejected');
  assert.equal(h.requests.length, 3);
  const stale = harness();
  stale.read(); stale.invalidate(); await stale.respond(0, user);
  assert.equal(stale.updates(), 0, 'response after leaving page never notifies');
  const failure = harness();
  failure.read(); await failure.respond(0, null, 403);
  assert.equal(failure.read().kind, 'failed', 'failure reports API error without DOM fallback');
  assert.equal(failure.requests.length, 1);
  failure.window.PinmonyProfileApi.reset(); failure.read();
  await failure.respond(1, { ...user, follower_count: -1, following_count: 'unknown', image_large_url: 'javascript:bad' });
  assert.equal(failure.read().info.followers, null);
  assert.equal(failure.read().info.following, null);
  assert.equal(failure.read().info.avatar, '');
  failure.window.PinmonyProfileApiEnabled = false;
  assert.equal(failure.read(), null, 'rollback switch clears API data');
  console.log('Profile API checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });

