const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
let now = 100000, timerId = 0;
const timers = new Map(), logs = [];
const loader = createArktsLoader(ts, {
  common_foundation: { PinmonyRuntimeLog: { info: s => logs.push(s), warn: s => logs.push(s) } },
  common_network: { PIN_BUSINESS_PIN_READ_ENABLED: true }, feature_pin: {}
}, {
  Date: class extends Date { static now() { return now; } },
  setTimeout(callback, delay) { const id = ++timerId; timers.set(id, { callback, delay }); return id; },
  clearTimeout(id) { timers.delete(id); }
});
const { PinmonyDetailNativeReads: Reads } = loader.loadFile('entry/src/main/ets/app/PinmonyDetailNativeReads.ets');
const pin = 'https://www.pinterest.com/pin/1/';
const reply = (wifi = true, cellular = false, viewer = '7') => ({ status: 200, error: '', body: JSON.stringify({
  resource_response: { status: 'success', code: 0, data: { id: viewer,
    autoplay_videos_on_wifi_enabled: wifi, autoplay_videos_on_cellular_enabled: cellular } },
  client_context: { user: { id: viewer } }
}) });
function fixture() {
  let session = { authenticated: true, origin: 'https://www.pinterest.com', accountId: 'synthetic', generation: 1 };
  let foreground = true, applied = 0, calls = 0, openedAt = now;
  const store = { detailOpeningToken: 1, detailPin: pin, detailOpeningPin: pin };
  const read = new Reads({ pinStore: () => store, session: () => session, foreground: () => foreground,
    rootOnly: () => false, backTarget: () => '', openedAt: () => openedAt, network: () => ({ cancel() {} }) });
  function bind() { read.pin = pin; read.opening = store.detailOpeningToken; read.sessionGeneration = session.generation; }
  bind(); read.commentViewer = '7'; read.apply = () => applied++;
  let request = () => Promise.resolve(reply());
  read.request = () => { calls++; return request(); };
  return { read, bind, store, calls: () => calls, applied: () => applied, session: () => session,
    setSession: value => { session = value; }, setForeground: value => { foreground = value; },
    setOpenedAt: value => { openedAt = value; }, setRequest: value => { request = value; } };
}
async function main() {
  // A slow base has already spent the entry budget; a fast hit waits only its remainder.
  for (const [elapsed, expected] of [[0, 280], [100, 180], [279, 1], [280, 0], [900, 0]]) {
    const f = fixture(); f.setOpenedAt(now - elapsed);
    const wait = f.read.waitForEntryBudget();
    assert.equal(timers.size, expected ? 1 : 0);
    if (expected) { const [id, timer] = [...timers][0]; assert.equal(timer.delay, expected); timers.delete(id); timer.callback(); }
    await wait;
  }
  const cancelled = fixture(), wait = cancelled.read.waitForEntryBudget();
  cancelled.read.pause(); await wait; assert.equal(timers.size, 0, 'pause releases and clears pending entry wait');

  const f = fixture(); await f.read.readAutoplay();
  assert.equal(f.calls(), 1); assert.equal(f.read.autoplayWifi, true);
  f.read.pause(); f.bind(); await f.read.readAutoplay();
  assert.equal(f.calls(), 1, 'ordinary detail return reuses verified preferences');
  now += 59999; await f.read.readAutoplay(); assert.equal(f.calls(), 1);
  now++; await f.read.readAutoplay(); assert.equal(f.calls(), 2, 'TTL boundary revalidates');
  f.read.invalidateAutoplay(); f.setRequest(() => Promise.resolve(reply(false, true)));
  await f.read.readAutoplay(); assert.equal(f.calls(), 3); assert.equal(f.read.autoplayWifi, false);
  assert.equal(f.read.autoplayCellular, true, 'settings invalidation cannot reuse an earlier enabled value');
  f.setForeground(false); f.read.pause(); f.setForeground(true); f.bind(); await f.read.readAutoplay();
  assert.equal(f.calls(), 4, 'foreground return revalidates');
  f.setSession({ ...f.session(), generation: 2, accountId: 'other-synthetic' });
  f.read.pause(); f.bind(); await f.read.readAutoplay(); assert.equal(f.calls(), 5, 'account switch clears cache');
  f.setSession({ ...f.session(), authenticated: false }); f.read.pause();
  assert.equal(f.read.retainedAutoplay, undefined, 'logout clears account data');

  const missing = fixture();
  // JSON omits the field; a partial response cannot authorize an enabled default or enter cache.
  missing.setRequest(() => Promise.resolve({ status: 200, body: JSON.stringify({ resource_response: {
    status: 'success', code: 0, data: { id: '7', autoplay_videos_on_wifi_enabled: false }
  }, client_context: { user: { id: '7' } } }) }));
  await missing.read.readAutoplay(); await missing.read.readAutoplay();
  assert.equal(missing.calls(), 2); assert.equal(missing.read.retainedAutoplay, undefined);
  assert.equal(missing.read.autoplayCellular, undefined);

  const failed = fixture(); failed.setRequest(() => Promise.reject(Error('synthetic')));
  await failed.read.readAutoplay(); failed.setRequest(() => Promise.resolve(reply())); await failed.read.readAutoplay();
  assert.equal(failed.calls(), 2, 'failure is not cached and explicit later demand can read');
  const foreign = fixture(); foreign.setRequest(() => Promise.resolve(reply(true, true, '8')));
  await foreign.read.readAutoplay(); assert.equal(foreign.applied(), 0); assert.equal(foreign.read.retainedAutoplay, undefined);

  const pending = fixture(); let resolveOld, resolveNew;
  pending.setRequest(() => new Promise(resolve => { resolveOld = resolve; }));
  const old = pending.read.readAutoplay(); await pending.read.readAutoplay();
  assert.equal(pending.calls(), 1, 'same detail coalesces concurrent preference demand');
  pending.read.invalidateAutoplay();
  pending.setRequest(() => new Promise(resolve => { resolveNew = resolve; }));
  const next = pending.read.readAutoplay(); resolveOld(reply(true, true)); await old;
  assert.equal(pending.applied(), 0, 'invalidated response cannot restore old values');
  await pending.read.readAutoplay(); assert.equal(pending.calls(), 2, 'old completion cannot release new request slot');
  resolveNew(reply(false, false)); await next; assert.equal(pending.applied(), 1);

  const stale = fixture(); let resolveStale;
  stale.setRequest(() => new Promise(resolve => { resolveStale = resolve; }));
  const late = stale.read.readAutoplay(); stale.read.pause(); stale.bind();
  resolveStale(reply()); await late; assert.equal(stale.applied(), 0); assert.equal(stale.read.retainedAutoplay, undefined);
  const changed = fixture(); let resolveChanged;
  changed.setRequest(() => new Promise(resolve => { resolveChanged = resolve; }));
  const oldOwner = changed.read.readAutoplay(); changed.setSession({ ...changed.session(), accountId: 'other' });
  resolveChanged(reply()); await oldOwner; assert.equal(changed.applied(), 0, 'owner changes reject late settings even within the same generation');

  const host = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert(host.includes('openedAt: (): number => this.detailOpenedAt'));
  assert.match(host, /nativeRequest: \(action: string,value: string\): Promise<void> => \{\s*this\.detailNativeReads\.invalidateAutoplay\(\);\s*return this\.settingsNativeFlow\.requestAction\(action,value\)/);
  assert.match(host, /nativePause: \(\): void => this\.settingsNativeFlow\.pause\(\)/);
  assert.match(host, /name: 'detail-autoplay', pause: \(\): void => this\.detailNativeReads\.invalidateAutoplay\(\),\s*reset: \(\): void => this\.detailNativeReads\.invalidateAutoplay\(\)/);
  // Exercise the real host callbacks: ordinary route pause must preserve this
  // cache even though the controller registry also pauses the settings flow.
  const integrated = fixture(); await integrated.read.readAutoplay();
  const hostFixture = { detailNativeReads: integrated.read, nativeBusinessRoutesEnabled: true,
    settingsNativeFlow: { pause() {}, requestAction() { return Promise.resolve(); } } };
  const settingsStart = host.indexOf('private readonly settingsController:');
  const settingsSource = host.slice(host.indexOf('nativeEnabled:', settingsStart), host.indexOf('    authenticated:', settingsStart));
  const settingsCallbacks = vm.runInNewContext(ts.transpileModule('(function(){return {' + settingsSource + '};})',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText).call(hostFixture);
  settingsCallbacks.nativePause(); integrated.read.pause(); integrated.bind(); await integrated.read.readAutoplay();
  assert.equal(integrated.calls(), 1, 'actual settings pause does not undo ordinary detail reuse');
  await settingsCallbacks.nativeRequest('autoplayWifi', 'false');
  assert.equal(integrated.read.retainedAutoplay, undefined, 'actual settings action invalidates immediately');
  await integrated.read.readAutoplay();
  const hookSource = host.match(/\{ name: 'detail-autoplay',[\s\S]*?reset:.*? \}/)[0];
  const hook = vm.runInNewContext(ts.transpileModule('(function(){return (' + hookSource + ');})',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText).call(hostFixture);
  const { PinmonyControllerLifecycle } = loader.loadFile('entry/src/main/ets/app/PinmonyControllerLifecycle.ets');
  const lifecycle = new PinmonyControllerLifecycle([{ name: 'detail', pause: () => integrated.read.pause() }], [hook]);
  lifecycle.background(); assert.equal(integrated.read.retainedAutoplay, undefined, 'background invalidates before foreground flags change');
  integrated.bind(); await integrated.read.readAutoplay(); lifecycle.resetHost();
  assert.equal(integrated.read.retainedAutoplay, undefined, 'host reset clears preferences');
  assert(logs.some(s => s === 'VideoAutoplayTrace: preferences=retained'));
  assert.equal(timers.size, 0);
  console.log('Detail loading: remaining entry budget, cancellation, preference TTL/coalescing, settings/background/account invalidation, incomplete/error/foreign/stale responses passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
