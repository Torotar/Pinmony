const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const origin = 'https://www.pinterest.com';
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
const defer = () => { let resolve; const promise = new Promise(r => resolve = r); return { promise, resolve }; };
const turn = () => new Promise(setImmediate);

function recoveryFixture() {
  let now = Date.now(), serial = 0, active = true, ready = true;
  const timers = new Map(), events = [], logs = [];
  const session = { authenticated: true, accountId: 'account-a', generation: 7, origin, userAgent: 'test' };
  const loader = createArktsLoader(ts, { common_foundation: { hashCacheString: hash,
    PinmonyRuntimeLog: { info: text => logs.push(text), warn: text => logs.push(text) } } }, {
    PinmonyTestTransportOnly: true, Date: { now: () => now },
    setTimeout(fn, ms) { const id = ++serial; timers.set(id, { fn, at: now + ms }); return id; },
    clearTimeout(id) { timers.delete(id); }
  });
  const { PinmonyPageRecovery: Recovery } = loader.loadFile('entry/src/main/ets/app/PinmonyPageRecovery.ets');
  const state = { version: 1, savedAt: now, account: hash(session.accountId), origin, tab: 1,
    root: origin + '/search/pins/?q=cat', routes: [{ kind: 'board', page: origin + '/user/board/', offset: 120 },
      { kind: 'pin', page: origin + '/pin/123/', offset: 420 }], homeOffset: 10, searchOffset: 20,
    inboxOffset: 30, profileOffset: 40, homeCategory: '', inboxSection: 'messages', profileSection: 'saved', searchDraft: 'draft' };
  const ports = { session: () => session, active: () => active,
    root: value => events.push(['root', value.tab]), rootReady: () => ready,
    rootPosition: value => events.push(['root-position', value.searchOffset, value.searchDraft]),
    open: (route, parent) => { events.push(['open', route.page, parent]); return true; },
    ready: () => ready, position: route => events.push(['position', route.page, route.offset]) };
  return { Recovery, state, ports, session, events, logs, instance: new Recovery(),
    active: value => active = value, ready: value => ready = value,
    tick() { now += 100; const due = [...timers.entries()].filter(([, task]) => task.at <= now); due.forEach(([id, task]) => { timers.delete(id); task.fn(); }); },
    receive(value = state, recovered = true, extra = {}) { Recovery.receive({ [Recovery.parameterKey()]: JSON.stringify(value), ...extra }, recovered); }
  };
}
function checkRecovery() {
  assert.match(fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8'), /committed: \(snapshot: PinmonyHomeSnapshot, kind:/,
    'home commit callback retains its two-argument feed/metadata contract');
  const f = recoveryFixture(); f.state.searchDraft = 'private search input'; f.Recovery.bind(() => f.state);
  const saved = f.Recovery.save(); assert(saved.length > 0 && saved.length < 32768);
  assert(!saved.includes('account-a'), 'only an account digest is backed up');
  f.receive(); assert(f.instance.start(f.ports)); for (let i = 0; i < 4; i++) f.tick();
  assert.deepEqual(f.events.map(e => e[0]), ['root', 'root-position', 'open', 'position', 'open', 'position']);
  assert.equal(f.events[4][2], f.state.routes[0].page, 'nested route retains its parent');
  assert.equal(f.instance.start(f.ports), false, 'one consumption per system backup');
  assert(f.logs.some(line => line.includes('phase=snapshot-ready') && line.includes('depth=2')));
  for (const phase of ['received', 'start', 'root-positioned', 'route-open', 'route-positioned', 'completed'])
    assert(f.logs.some(line => line.includes('phase=' + phase)), phase + ' has diagnostic evidence');
  assert(f.logs.some(line => line.includes('phase=completed') && line.includes('frameConfirmed=false')));
  for (const secret of [f.session.accountId, f.state.account, f.state.origin, f.state.searchDraft, '/pin/123/'])
    assert(!f.logs.some(line => line.includes(secret)), 'recovery logs do not contain ' + secret);
  const empty = recoveryFixture(); empty.Recovery.save();
  assert(empty.logs.some(line => line.includes('reason=no-provider')));
  empty.Recovery.bind(() => undefined); empty.Recovery.save();
  assert(empty.logs.some(line => line.includes('reason=no-state')));
  empty.Recovery.bind(() => { throw Error('private payload'); }); empty.Recovery.save();
  assert(empty.logs.some(line => line.includes('phase=save-failed')));
  assert(!empty.logs.join().includes('private payload'));
  empty.Recovery.bind(() => ({ ...empty.state, version: 2 })); empty.Recovery.save();
  assert(empty.logs.some(line => line.includes('phase=save-rejected')));
  const timeout = recoveryFixture(); timeout.ready(false); timeout.receive(); timeout.instance.start(timeout.ports);
  for (let i = 0; i < 202; i++) timeout.tick();
  assert(timeout.logs.some(line => line.includes('reason=ready-timeout')));
  const refused = recoveryFixture(); refused.ports.open = () => false; refused.receive(); refused.instance.start(refused.ports);
  assert(refused.logs.some(line => line.includes('reason=route-unavailable')));
  const mismatch = recoveryFixture(); mismatch.receive(); mismatch.session.accountId = 'another'; mismatch.instance.start(mismatch.ports);
  assert(mismatch.logs.some(line => line.includes('reason=owner-or-origin-mismatch')));
  for (const bad of [{ ...f.state, account: hash('other') }, { ...f.state, origin: 'https://example.com' },
    { ...f.state, savedAt: 0 }, { ...f.state, root: origin + '/login/' },
    { ...f.state, routes: [{ kind: 'pin', page: 'https://example.com/pin/123/', offset: 0 }] },
    { ...f.state, searchOffset: -1 }, { ...f.state, routes: Array(13).fill(f.state.routes[0]) }]) {
    const t = recoveryFixture(); t.receive(bad); assert.equal(t.instance.start(t.ports), false);
  }
  const ordinary = recoveryFixture(); ordinary.receive(ordinary.state, false); assert.equal(ordinary.instance.start(ordinary.ports), false);
  const notice = recoveryFixture(); notice.receive(notice.state, true, { pinmonyMessageNotice: 'notice-token' }); assert.equal(notice.instance.start(notice.ports), false);
  const waiting = recoveryFixture(); waiting.ready(false); waiting.receive(); waiting.active(false);
  assert.equal(waiting.instance.start(waiting.ports), false); waiting.active(true); assert(waiting.instance.start(waiting.ports));
  waiting.session.generation++; waiting.ready(true); waiting.tick(); assert.equal(waiting.events.length, 1, 'late data from old session never opens a child');
  const cancelled = recoveryFixture(); cancelled.ready(false); cancelled.receive(); cancelled.instance.start(cancelled.ports);
  cancelled.Recovery.clear(); cancelled.ready(true); cancelled.tick(); assert.equal(cancelled.events.length, 1, 'new intent/user navigation cancels recovery');
  const gone = recoveryFixture(); gone.receive(); gone.instance.start(gone.ports); gone.instance.cancel(); gone.tick(); assert.equal(gone.events.filter(e => e[0] === 'open').length, 1);
  const invalid = recoveryFixture(); invalid.Recovery.receive({ [invalid.Recovery.parameterKey()]: '{broken' }, true); assert.equal(invalid.instance.start(invalid.ports), false);
  invalid.Recovery.unbind(); assert.equal(invalid.Recovery.save(), '');
  const profile = recoveryFixture();
  profile.receive({ ...profile.state, routes: [{ kind: 'profile', page: origin + '/another/_created/', offset: 80 }] });
  assert(profile.instance.start(profile.ports)); profile.tick();
  assert.equal(profile.events.find(e => e[0] === 'open')[1], origin + '/another/', 'created section is restored on the canonical profile route');
}
async function checkNetwork() {
  const calls = [], cookies = [], updates = []; let fetch = async () => response(200, 'ok');
  const response = (status, text) => ({ statusCode: status, body: new Uint8Array(Buffer.from(text)).buffer,
    headers: { 'set-cookie': ['a=b; Path=/; Secure; HttpOnly'] }, toString: () => text });
  const rcp = { Request: class { constructor(url, method, headers, body, a, b, configuration) { Object.assign(this, { url, method, headers, body, configuration }); } },
    MultipartForm: class { constructor(fields) { this.fields = fields; } } };
  const loader = createArktsLoader(ts, {
    '@kit.RemoteCommunicationKit': { rcp }, '@kit.BasicServicesKit': {},
    common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } },
    common_session: { PinmonySessionCredentials: class { async read(url) { cookies.push(url); return 'csrftoken=synthetic'; }
      async update(...args) { updates.push(args); } } }
  }, { PinmonyTestTransportOnly: true });
  const core = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
  const { PinmonyBusinessNetwork } = loader.loadFile('entry/src/main/ets/app/PinmonyBusinessNetwork.ets');
  assert.equal(typeof core.PinmonyNativeNetwork.prototype.requestBusinessHomeRead, 'undefined');
  const net = new PinmonyBusinessNetwork();
  for (const group of ['profile', 'search', 'board', 'pin', 'inbox', 'home', 'settings']) {
    const name = 'Pinmony' + group[0].toUpperCase() + group.slice(1) + 'Network';
    const client = loader.loadPackage('feature_' + group)[name];
    for (const method of Object.getOwnPropertyNames(client.prototype).filter(n => n !== 'constructor' && n !== 'uploadPhoto')) {
      assert.equal(typeof net[method], 'function', 'production facade wires ' + method);
    }
    const source = fs.readFileSync(`feature_${group}/src/main/ets/services/${name}.ets`, 'utf8');
    assert(!source.includes('rcp.') && !source.includes('this.credentials'), 'feature owns contracts, not native transport');
  }
  core.NetworkManager.enqueue = async (_, action) => action(); core.NetworkManager.requestRemainingMs = () => 0;
  core.NetworkManager.getSession = () => ({ fetch: async request => { calls.push(request); return fetch(request); } });
  const job = { id: 'upload', url: origin + '/upload-profile-image/', method: 'POST', page: origin + '/user/',
    userAgent: 'ua', authenticated: true, headers: {}, file: { field: 'img', bytes: new ArrayBuffer(12), mime: 'image/jpeg', name: 'avatar.jpg' },
    timeoutMs: 20000, maxBytes: 65536 };
  await net.transfer(job, () => true);
  assert.deepEqual(cookies, [job.url]); assert.equal(calls[0].headers['X-CSRFToken'], 'synthetic'); assert.equal(updates[0][1][0], 'a=b; Path=/; Secure; HttpOnly');
  await net.transfer({ ...job, id: 's3', authenticated: false, url: 'https://pinterest-media-upload.s3.amazonaws.com/' }, () => true);
  assert.equal(calls.at(-1).headers.Cookie, undefined); assert.equal(calls.at(-1).headers['X-CSRFToken'], undefined);
  await assert.rejects(net.transfer({ ...job, id: 'unsafe', url: 'https://example.com/' }, () => true));
  await assert.rejects(net.transfer({ ...job, id: 'unsafe', authenticated: true, url: 'https://u.pinimg.com/' }, () => true));
  const gate = defer(); fetch = () => gate.promise;
  const pending = net.transfer({ ...job, id: 'race' }, () => true); await turn(); net.cancel('race');
  fetch = async () => response(200, 'new'); const replacement = net.transfer({ ...job, id: 'race' }, () => true);
  gate.resolve(response(200, 'old')); await assert.rejects(pending); await replacement;
  assert(!net.pending.has('race') && !net.jobs.has('race'), 'replacement task releases its own resources');
  fetch = async () => { throw Error('network'); }; const before = calls.length;
  await assert.rejects(net.transfer({ ...job, id: 'write-once' }, () => true)); assert.equal(calls.length - before, 1, 'write failure is never replayed');
  net.setForeground(false); await assert.rejects(net.transfer({ ...job, id: 'background' }, () => true));
}
async function checkCodec() {
  const tasks = []; let release;
  const gate = new Promise(resolve => release = resolve);
  const loader = createArktsLoader(ts, { '@kit.ArkTS': {
    util: { TextEncoder: class { encodeInto(text) { return new Uint8Array(Buffer.from(text)); } } },
    taskpool: { Priority: { LOW: 1 }, Task: class { constructor(fn, ...args) { this.fn = fn; this.args = args; } },
      execute: async task => { tasks.push(task); await gate; return task.fn(...task.args); } }
  } });
  const codec = loader.loadFile('common_foundation/src/main/ets/cache/CacheCodec.ets');
  let complete = false; const write = codec.stringifyCacheJson({ text: '中文' }).then(value => { complete = true; return value; });
  await turn(); assert.equal(complete, false, 'UI caller can yield while codec task waits'); release();
  const bytes = await write; const decoded = await codec.parseCacheJson(Buffer.from(bytes).toString()); assert.equal(decoded.text, '中文');
  await assert.rejects(codec.parseCacheJson('{broken'));
  await assert.rejects(codec.stringifyCacheJson('x'.repeat(2 * 1024 * 1024)));
  assert(tasks.length >= 4);
}
async function checkRecoverySaveCallbacks() {
  const ability = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
  const start = ability.indexOf('  onSaveState('), end = ability.indexOf('  onForeground()', start);
  assert(start >= 0 && end > start);
  const logs = [];
  let snapshot = 'test-state', calls = 0;
  const context = { PinmonyPageRecovery: { save: () => { calls++; return snapshot; }, parameterKey: () => 'recovery' },
    PinmonyRuntimeLog: { info: text => logs.push(text) }, AbilityConstant: { OnSaveResult: { ALL_AGREE: 0 } } };
  vm.runInNewContext(ts.transpileModule('class Ability {\n' + ability.slice(start, end) + '\n}\nglobalThis.Ability = Ability;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, context);
  const instance = new context.Ability();
  const sync = {}, async = {};
  assert.equal(instance.onSaveState(1, sync), 0);
  assert.equal(await instance.onSaveStateAsync(1, async), 0);
  assert.equal(calls, 2, 'each callback captures once through the shared implementation');
  assert.equal(sync.recovery, snapshot); assert.equal(async.recovery, snapshot);
  for (const mode of ['sync', 'async']) assert(logs.some(line => line.includes('phase=save-return mode=' + mode) &&
    line.includes('attached=true') && line.includes('systemCommitConfirmed=false')));
  snapshot = ''; const missing = {}; await instance.onSaveStateAsync(1, missing);
  assert.equal(Object.keys(missing).length, 0);
  assert(logs.some(line => line.includes('attached=false')));
  assert(!logs.join().includes('test-state'), 'callback logs never include saved content');
}
(async () => { checkRecovery(); await checkRecoverySaveCallbacks(); await checkNetwork(); await checkCodec();
  console.log('Framework completion: production feature composition, managed transfer, write-once/cancel/account guards, worker codec and system page recovery passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
