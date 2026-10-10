const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const logs = [];
const foundation = { PinmonyRuntimeLog: { info: x => logs.push(x), warn: x => logs.push(x) } };
function compiled(file, requireFn) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: requireFn, Promise, setTimeout, clearTimeout, console });
  return exports;
}
const policyModule = compiled('common_network/src/main/ets/PinmonyRequestPolicy.ets', () => foundation);
const { PinmonyRequestPolicy } = policyModule;
let now = Date.parse('2030-01-01T00:00:00Z');
const policy = new PinmonyRequestPolicy(() => now);
function policyChecks() {
  const old = policy.acquire(true);
  policy.rateLimited({ 'Retry-After': '90' });
  assert.equal(policy.remainingMs(), 90000);
  assert.equal(policy.canSend(old), false, 'a concurrent old retry cannot bypass cooldown');
  assert.equal(policy.acquire(true).allowed, false);
  assert.equal(policy.allowsSpeculativeRequests(), false);
  now += 90000;
  assert.equal(policy.allowsSpeculativeRequests(), false, 'expiry does not restart anticipatory paging before recovery');
  assert.equal(policy.acquire(false).allowed, false, 'writes cannot probe recovery');
  assert.equal(policy.acquire(true, true).allowed, false, 'prefetch cannot probe recovery');
  const probe = policy.acquire(true);
  assert(probe.allowed && probe.probe);
  assert.equal(policy.acquire(true).allowed, false, 'only one probe is allowed');
  policy.rateLimited({ 'retry-after': '120' });
  policy.finish(probe, 200);
  assert.equal(policy.remainingMs(), 120000, 'late probe success cannot erase a newer limit');
  now += 120000;
  const failed = policy.acquire(true);
  policy.finish(failed, 0);
  assert(policy.remainingMs() > 0, 'failed or cancelled probe has a bounded retry interval');
  now += policy.remainingMs();
  policy.finish(policy.acquire(true), 200);
  assert.equal(policy.remainingMs(), 0);
  assert.equal(policy.allowsSpeculativeRequests(), true);
  assert(policy.acquire(false).allowed);
  policy.rateLimited({ 'RETRY-AFTER': new Date(now + 60000).toUTCString() });
  assert.equal(policy.remainingMs(), 60000, 'HTTP date is honored');
  const fallback = new PinmonyRequestPolicy(() => now);
  fallback.rateLimited({ 'Retry-After': 'garbage' });
  assert.equal(fallback.remainingMs(), 30000);
  now += 30000; fallback.rateLimited({ 'Retry-After': '0' });
  assert.equal(fallback.remainingMs(), 60000, 'repeated limits extend fallback');
  const long = new PinmonyRequestPolicy(() => now);
  long.rateLimited({ 'Retry-After': '86400' });
  assert.equal(long.remainingMs(), 86400000, 'server cooldown is not shortened to a client cap');
  const arrayHeader = new PinmonyRequestPolicy(() => now);
  arrayHeader.rateLimited({'Retry-After': ['90']});
  assert.equal(arrayHeader.remainingMs(), 90000, 'single-value RCP header arrays preserve server delay');
}
let fetches = 0, nextResponse;
const rcp = { Request: class { constructor(url, method, headers, body) { Object.assign(this, {url, method, headers, body}); } },
  createSession: () => ({ fetch: async () => { fetches++; return nextResponse; }, cancel() {}, close() {} }) };
const credentials = { PinmonySessionCredentials: class { async read() { return 'csrftoken=synthetic'; } async update() {} } };
const network = compiled('common_network/src/main/ets/PinmonyNativeNetwork.ets', name =>
  name === './PinmonyRequestPolicy' ? policyModule : name === 'common_session' ? credentials : name === 'common_foundation' ? foundation : {rcp});
async function networkChecks() {
  const { NetworkManager, PinmonyNativeNetwork } = network;
  NetworkManager.getSession();
  // Inject deterministic time into the real implementation, without sleeping or hitting a service.
  NetworkManager.shared.requestPolicy = new PinmonyRequestPolicy(() => now);
  const state = { authenticated: true, epoch: 1, page: 'https://www.pinterest.com/', userAgent: 'synthetic' };
  const job = { id: 'limit', epoch: 1, page: state.page, url: state.page + 'resource/UserResource/get/', method: 'GET', headers: {}, body: '' };
  const first = new PinmonyNativeNetwork(), second = new PinmonyNativeNetwork();
  nextResponse = { statusCode: 429, headers: {'Retry-After': '60'}, toString: () => '{}' };
  assert.equal((await first.request(job, () => state)).error, 'rate-limited');
  assert.equal(fetches, 1, '429 is returned without automatic retry');
  first.invalidate();
  assert.equal((await second.request({...job, id: 'other'}, () => state)).error, 'rate-limited');
  assert.equal(fetches, 1, 'cooldown covers all owners and survives page invalidation');
  now += 60000;
  assert.equal((await first.request({...job, id: 'detail_prefetch_synthetic'}, () => state)).error, 'rate-limited');
  assert.equal(fetches, 1);
  nextResponse = { statusCode: 200, headers: {}, toString: () => '{}' };
  assert.equal((await second.request({...job, id: 'probe'}, () => state)).status, 200);
  assert.equal(fetches, 2);
  nextResponse = { statusCode: 403, headers: {}, toString: () => 'denied' };
  assert.equal((await first.request({...job, id: 'denied'}, () => state)).status, 403);
  assert.equal(state.authenticated, true, '403 does not log out');
  nextResponse = { statusCode: 429, headers: {}, toString: () => '{}' };
  assert.equal((await first.request({...job, id: 'write', method: 'POST', url: state.page + 'resource/RepinResource/create/'}, () => state)).error, 'rate-limited');
  assert.equal(fetches, 4, 'write is sent once');
  now += NetworkManager.requestRemainingMs();
  let resolveProbe, current = true;
  const staleProbe = NetworkManager.requestWithRetry({fetch: () => new Promise(resolve => {resolveProbe = resolve;})},
    {method: 'GET'}, 0, 0, undefined, () => current);
  await assert.rejects(NetworkManager.requestWithRetry({fetch: () => {throw new Error('must not send');}}, {method: 'GET'}));
  current = false; resolveProbe({statusCode: 200, headers: {}});
  await assert.rejects(staleProbe);
  assert(NetworkManager.requestRemainingMs() > 0, 'cancelled recovery cannot reopen dispatch');
  NetworkManager.destroy();
}
const scriptModule = compiled('common_network/src/main/ets/PinmonyNetworkScript.ets', () => ({}));
async function mergeChecks() {
  const sent = [], cancels = [], location = {origin: 'https://www.pinterest.com', href: 'https://www.pinterest.com/'};
  const window = { addEventListener() {}, PinmonyNativeNetworkEnabled: true, fetch: () => {throw new Error('Web fallback');},
    PinmonyShareBridge: { networkRequest: raw => sent.push(JSON.parse(raw)), cancelNetwork: id => cancels.push(id) } };
  window.top = window;
  vm.runInNewContext(scriptModule.PIN_NATIVE_NETWORK_SCRIPT, {window, location, URL, Headers, Response, Map, Set, AbortController,
    Promise, setTimeout, clearTimeout, console: {info: x => logs.push(x), warn() {}}});
  const api = window.PinmonyNetwork, url = '/resource/UserResource/get/';
  api.bind(1, location.href);
  const finish = (index, error = '') => api.complete({...sent[index], status: 200, body: '{"value":1}', error});
  const a = new AbortController(), b = new AbortController();
  const first = api.fetch(url, {signal: a.signal}), second = api.fetch(url, {signal: b.signal});
  assert.equal(sent.length, 1);
  a.abort(); await assert.rejects(first, e => e.name === 'AbortError');
  assert.equal(cancels.length, 0, 'one subscriber cannot cancel another');
  finish(0); assert.equal((await (await second).json()).value, 1);
  const left = api.fetch(url), right = api.fetch(url);
  assert.equal(sent.length, 2); finish(1);
  const [l, r] = await Promise.all([left, right]);
  assert.notEqual(l, r); assert.equal((await l.json()).value, 1); assert.equal((await r.json()).value, 1);
  const c = new AbortController(), d = new AbortController();
  const third = api.fetch(url, {signal: c.signal}), fourth = api.fetch(url, {signal: d.signal});
  c.abort(); d.abort(); await Promise.all([assert.rejects(third), assert.rejects(fourth)]);
  assert.equal(cancels.length, 1, 'last subscriber cancels shared native job');
  const replacement = api.fetch(url); assert.equal(sent.length, 4); finish(3); await replacement;
  const old = api.fetch(url); api.bind(2, location.href);
  await assert.rejects(old, e => e.name === 'AbortError');
  const fresh = api.fetch(url); assert.equal(sent.length, 6); finish(5); await fresh;
  const post1 = api.fetch('/resource/RepinResource/create/', {method: 'POST', body: 'synthetic'});
  const post2 = api.fetch('/resource/RepinResource/create/', {method: 'POST', body: 'synthetic'});
  assert.equal(sent.length, 8, 'writes are not coalesced or replayed by transport');
  finish(6); finish(7); await Promise.all([post1, post2]);
  const limited = api.fetch(url); finish(8, 'rate-limited');
  await assert.rejects(limited, e => e.pinmonyRateLimited === true && /稍后/.test(e.message));
  let start = sent.length;
  const variants = [api.fetch(url + '?q=a'), api.fetch(url + '?q=b'), api.fetch(url, {headers: {Accept: 'a'}}),
    api.fetch(url, {headers: {Accept: 'b'}})];
  assert.equal(sent.length, start + 4, 'different URL parameters and headers are never combined');
  variants.forEach((_, i) => finish(start + i)); await Promise.all(variants);
  start = sent.length;
  const readPost1 = api.fetch(url, {method: 'POST', body: 'synthetic-read'});
  const readPost2 = api.fetch(url, {method: 'POST', body: 'synthetic-read'});
  assert.equal(sent.length, start + 1, 'confirmed POST resource reads can share without replay');
  finish(start); await Promise.all([readPost1, readPost2]);
  const background1 = api.fetch(url), background2 = api.fetch(url);
  api.setForeground(false);
  await Promise.all([assert.rejects(background1, e => e.name === 'AbortError'), assert.rejects(background2, e => e.name === 'AbortError')]);
  const beforeResume = sent.length; api.setForeground(true);
  assert.equal(sent.length, beforeResume, 'resume does not replay merged reads');
}
function modeChecks() {
  for (const debug of [true, false]) {
    const mode = compiled('common_foundation/src/main/ets/services/PinmonyRequestMode.ets', name =>
      name.includes('BuildProfile') ? {default: {DEBUG: debug}} : foundation);
    assert.equal(mode.allowsSpeculativeReads(), !debug);
  }
  const source = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets', 'utf8');
  function method(name) {
    const start = source.indexOf('  private ' + name + '(');
    const end = source.indexOf('\n  private ', start + 1);
    assert(start >= 0 && end > start);
    return source.slice(start, end);
  }
  for (const speculative of [false, true]) {
    const ctx = { allowsSpeculativeReads: () => speculative, Date, setTimeout };
    vm.runInNewContext(ts.transpileModule('class Home {' +
      method('prefetchNextScreen') + method('loadNextPageAtEnd') + '} globalThis.Home = Home;', {
      compilerOptions: {target: ts.ScriptTarget.ES2021}
    }).outputText, ctx);
    const home = new ctx.Home(); let pages = 0;
    Object.assign(home, {home: {dataSource: 'api', pins: [{id: 'synthetic'}], session: 1, selectedTab: 'all'},
      feedActive: true, actionsReady: true, visibleFirst: 0, visibleLast: 0, prefetchNotBefore: 0,
      onLoadMore: () => pages++});
    home.prefetchNextScreen();
    assert.equal(pages, speculative ? 1 : 0, 'debug suppresses lookahead, release retains it');
    home.loadNextPageAtEnd();
    assert.equal(pages, speculative ? 2 : 1, 'user reaches end: pagination remains enabled in both modes');
    home.home.loadingMore = true; home.loadNextPageAtEnd();
    assert.equal(pages, speculative ? 2 : 1, 'busy pagination never repeats');
  }
}
(async () => { policyChecks(); await networkChecks(); await mergeChecks(); modeChecks();
  assert(logs.some(x => x.includes('cooldown-start')));
  assert(logs.some(x => x.includes('recovery-complete')));
  console.log('request protection: cooldown, single probe, stale recovery, independent cancellation, read merging and build modes OK');
})().catch(error => { console.error(error); process.exitCode = 1; });
