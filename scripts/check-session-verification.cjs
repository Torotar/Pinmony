const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function compile(path, requireFn = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, require: requireFn, setTimeout, clearTimeout, console, Error });
  return exports;
}
const events = [];
const log = { info(message) { events.push(message); }, warn(message) { events.push(message); } };
const session = { ...compile('common_session/src/main/ets/models/PinmonySessionVerification.ets'),
  ...compile('common_session/src/main/ets/models/PinmonyAuth.ets') };
const origin = 'https://www.pinterest.com';
function body() {
  return { client_context: { is_authenticated: true, user: { id: '123', username: 'fixture_user' }, app_version: 'fixture.1' },
    resource_response: { status: 'success', code: 0, endpoint_name: 'v3_get_user_settings',
      data: { type: 'user_settings', id: '123', username: 'fixture_user' } } };
}
const parse = (b, status = 200, site = origin) => session.parseSessionVerification(site, status, JSON.stringify(b));
assert.equal(parse(body()).status, 'authenticated');
assert.equal(parse(body(), 200, 'https://uk.pinterest.com').profileUrl, 'https://uk.pinterest.com/fixture_user/');
assert.equal(parse(body(), 200, 'https://example.com').status, 'unknown');
for (const status of [0, 302, 401, 403, 429, 500]) assert.equal(parse(body(), status).status, 'unknown');
for (const mutate of [
  b => delete b.client_context.is_authenticated,
  b => b.client_context.is_authenticated = 'true',
  b => b.resource_response.data.id = '456',
  b => b.resource_response.data.username = 'other',
  b => b.resource_response.data.type = 'user',
  b => b.resource_response.endpoint_name = 'public_profile',
  b => b.resource_response.code = 1,
  b => b.resource_response.error = {},
  b => b.client_context.user.id = '0',
  b => b.client_context.user.username = '../login'
]) { const b = body(); mutate(b); assert.equal(parse(b).status, 'unknown'); }
assert.equal(parse({ client_context: { is_authenticated: false }, resource_response: { status: 'failure' } }).status, 'unauthenticated');
const contradictory = body(); contradictory.client_context.is_authenticated = false;
assert.equal(parse(contradictory).status, 'unknown');
for (const text of ['null', '[]', '<html>challenge</html>', '{', 'x'.repeat(1048577)])
  assert.equal(session.parseSessionVerification(origin, 200, text).status, 'unknown');

let reads = 0, writes = 0, response, resolveFetch, missingCookie = false;
const sent = [];
class Credentials {
  async read() { reads++; if(missingCookie) throw new Error('missing-session'); return 'fixture_session=synthetic'; }
  async update(url, values, current) { assert(current()); writes += values.length; }
}
const rcp = { Request: class { constructor(url, method, headers, content, range, cookies, configuration) { Object.assign(this, { url, method, headers, configuration }); } },
  createSession() { return { fetch(request) { sent.push(request); return response ? Promise.resolve(response) :
    new Promise(resolve => { resolveFetch = resolve; }); }, cancel() {}, close() {} }; } };
const policy = compile('common_network/src/main/ets/PinmonyRequestPolicy.ets', () => ({ PinmonyRuntimeLog: log }));
const { PinmonyNativeNetwork, NetworkManager } = compile('common_network/src/main/ets/PinmonyNativeNetwork.ets', name =>
  name === 'common_session' ? { PinmonySessionCredentials: Credentials } : name === 'common_foundation' ?
    { PinmonyRuntimeLog: log } : name === './PinmonyRequestPolicy' ? policy : { rcp });
const { PinmonySessionVerification } = compile('entry/src/main/ets/app/PinmonySessionVerification.ets', name =>
  name === 'common_session' ? session : { PinmonyRuntimeLog: log });
const retryPolicies = [], originalRetry = NetworkManager.requestWithRetry;
NetworkManager.requestWithRetry = (...args) => { retryPolicies.push([args[2], args[3]]); return originalRetry(...args); };
const flush = () => new Promise(resolve => setImmediate(resolve));
function reply() { return { statusCode: 200, headers: { 'set-cookie': 'fixture=synthetic; Path=/; Secure' },
  toString: () => JSON.stringify(body()) }; }
function fixture() {
  let status = 'checking', epoch = 1, page = origin + '/', active = true, profile = '';
  const accepted = [], network = new PinmonyNativeNetwork();
  const verifier = new PinmonySessionVerification({ network: () => network, status: () => status, profile: () => profile,
    epoch: () => epoch, page: () => page, userAgent: () => 'fixture-agent', active: () => active,
    accept: m => { accepted.push(m); status = m.status; } });
  return { verifier, network, accepted, setStatus: s => status = s, setEpoch: e => epoch = e,
    setPage: p => page = p, setActive: a => active = a, setProfile: p => profile = p,
    web(status, profileUrl = '', overrides = {}) {
      verifier.observeWebEvidence(JSON.stringify({ status, profileUrl, epoch, pageUrl: page, ...overrides }));
    } };
}
async function main() {
  response = reply();
  let f = fixture(); await f.verifier.demand();
  assert.equal(f.accepted.length, 1, 'startup checking does not require prior authenticated business state');
  assert.equal(f.accepted[0].appVersion, 'fixture.1');
  const request = sent.at(-1), url = new URL(request.url), envelope = JSON.parse(url.searchParams.get('data'));
  assert.equal(request.method, 'GET'); assert.equal(envelope.options.url, '/v3/users/settings/');
  assert.equal(url.pathname, '/resource/ApiResource/get/'); assert.equal(url.searchParams.get('source_url'), '/settings/');
  assert.equal(request.headers['X-Pinterest-Pws-Handler'], 'www/settings.js');
  assert.equal(request.headers.Cookie, 'fixture_session=synthetic');
  assert.equal(request.configuration.transfer.timeout.connectMs, 3000);
  assert.equal(request.configuration.transfer.timeout.transferMs, 5000);
  assert.deepEqual(retryPolicies[0], [1, 100], 'session probe gets one retry with a shorter backoff');
  assert.equal(envelope.options.field_sets.length, 34); assert.equal(Object.keys(envelope.context).length, 0);
  const before = reads;
  for (const args of [['https://example.com', 'fixture', 1, 'session_probe_1'], [origin, 'fixture', 1, 'wrong'],
    [origin, 'bad\r\nagent', 1, 'session_probe_1'], [origin, 'fixture', -1, 'session_probe_1']])
    await assert.rejects(f.network.verifySession(...args, () => true));
  await assert.rejects(f.network.verifySession(origin, 'fixture', 1, 'session_probe_9', () => false));
  assert.equal(reads, before, 'invalid contracts cannot even read credentials');
  for (const change of [x => x.setEpoch(2), x => x.setPage(origin + '/search/'),
    x => { x.setStatus('authenticated'); x.setProfile(origin + '/fixture_user/'); }, x => x.setStatus('unauthenticated'),
    x => { x.setActive(false); x.verifier.cancel(); }, x => x.network.invalidateDocument()]) {
    response = undefined; f = fixture(); const pending = f.verifier.demand(); await flush();
    const beforeWrites = writes; change(f); resolveFetch(reply()); await pending;
    assert.equal(f.accepted.length, 0); assert.equal(writes, beforeWrites, 'stale evidence cannot update Cookie store');
  }
  response = undefined; f = fixture(); const pending = f.verifier.demand(); await flush();
  const count = sent.length; await f.verifier.demand(); assert.equal(sent.length, count, 'same document probe is single-flight');
  resolveFetch(reply()); await pending;
  response = undefined; f = fixture(); const partial = f.verifier.demand(); await flush();
  f.setStatus('authenticated'); f.web('authenticated');
  const partialWrites = writes; resolveFetch(reply()); await partial;
  assert.equal(f.accepted.length, 1, 'partial Web authentication keeps native identity verification alive');
  assert(writes > partialWrites); assert(events.some(x => x.includes('web-identity-pending')));
  response = undefined; f = fixture(); const known = f.verifier.demand(); await flush();
  f.setStatus('authenticated'); f.setProfile(origin + '/fixture_user/'); f.web('authenticated', origin + '/fixture_user/');
  const knownWrites = writes; resolveFetch(reply()); await known;
  assert.equal(f.accepted.length, 0); assert.equal(writes, knownWrites);
  assert(events.some(x => x.includes('reason=web-identity-confirmed')));
  response = undefined; f = fixture(); const stale = f.verifier.demand(); await flush();
  f.web('unauthenticated', '', { epoch: 0 }); f.web('authenticated', 'https://example.com/fixture_user/');
  resolveFetch(reply()); await stale; assert.equal(f.accepted.length, 1, 'stale or foreign Web evidence cannot cancel the probe');
  response = undefined; f = fixture(); const conflict = f.verifier.demand(); await flush(); f.setStatus('authenticated');
  resolveFetch({ statusCode: 200, headers: {}, toString: () => JSON.stringify({ client_context: { is_authenticated: false }, resource_response: {} }) });
  await conflict; assert.equal(f.accepted.length, 0, 'older native guest response cannot log out a Web-authenticated account');
  assert(events.some(x => x.includes('reason=web-auth-conflict')));
  response = { statusCode: 200, headers: {}, toString: () => '<html>challenge</html>' };
  f = fixture(); await f.verifier.demand(); assert.equal(f.accepted.length, 0);
  f.setEpoch(2); response = reply(); await f.verifier.demand(); assert.equal(f.accepted.length, 1);
  response = { statusCode: 200, headers: {}, toString: () => JSON.stringify({ client_context: { is_authenticated: false }, resource_response: {} }) };
  f = fixture(); await f.verifier.demand(); assert.equal(f.accepted[0].status, 'unauthenticated');
  response = reply(); f = fixture(); f.setPage(origin + '/login/');
  const loginCount = sent.length; await f.verifier.demand(); assert.equal(sent.length, loginCount, 'never probe while entering credentials');
  f.setPage(origin + '/challenge/'); await f.verifier.demand(); assert.equal(sent.length, loginCount, 'only the startup root may probe');
  // Execute the production Index port binding and actual SessionCoordinator sync.
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const binding = index.match(/private readonly sessionCoordinator: PinmonySessionCoordinator = new PinmonySessionCoordinator\(\{([\s\S]*?)\} as PinmonySessionCoordinatorPorts\);/)[1];
  const out = {};
  vm.runInNewContext(ts.transpileModule('export function ports(){return {' + binding + '};}', {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports: out });
  f = fixture(); const host = { sessionVerification: f.verifier, controller: { runJavaScript: () => Promise.resolve() },
    authEpoch: 1, authCheckTimer: -1, pageTasks: { timeout() { return 1; }, cancelTimeout() {} } };
  const { PinmonySessionCoordinator } = compile('entry/src/main/ets/app/PinmonySessionCoordinator.ets', name =>
    name === 'common_session' ? session : { PinmonyRuntimeLog: log });
  new PinmonySessionCoordinator(out.ports.call(host)).syncAuthentication(); await flush();
  assert.equal(f.accepted.length, 1, 'production startup synchronization actually invokes native verification');
  const expiry = [], transport = new PinmonyNativeNetwork();
  transport.onSessionExpired = (site, epoch) => expiry.push({site, epoch});
  for(const [index, value] of [
    { client_context: { is_authenticated: false }, resource_response: {} },
    { client_context: { is_authenticated: false, user: { id: '123' } }, resource_response: {} },
    { client_context: { is_authenticated: true }, resource_response: {} },
    { client_context: { is_authenticated: false } }
  ].entries()) {
    response = {statusCode:200,headers:{},toString:()=>JSON.stringify(value)};
    await transport.verifySession(origin,'fixture-agent',7,'session_probe_'+(900+index),()=>true);
  }
  assert.equal(expiry.length,1,'only explicit noncontradictory current-session failure expires the account');
  assert.equal(expiry[0].site,origin); assert.equal(expiry[0].epoch,7);
  response = {statusCode:403,headers:{},toString:()=>JSON.stringify({client_context:{is_authenticated:false},resource_response:{}})};
  await transport.verifySession(origin,'fixture-agent',7,'session_probe_910',()=>true);
  assert.equal(expiry.length,1,'HTTP errors alone never expire a session');
  missingCookie=true;
  assert.equal((await transport.verifySession(origin,'fixture-agent',8,'session_probe_911',()=>true)).error,'missing-session');
  missingCookie=false;
  NetworkManager.destroy();
  console.log('Session verification: parser, restricted native GET, Cookie lifecycle, races and cancellation passed.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
