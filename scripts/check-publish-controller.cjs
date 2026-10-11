const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const timers = new Map(); let timerId = 0;
const { PinmonyPublishController } = require('./publish-controller-harness.cjs').create(ts, {
  setTimeout: fn => { timers.set(++timerId, fn); return timerId; }, clearTimeout: id => timers.delete(id)
});
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness() {
  let auth = true, foreground = true, visible = false, document = 'synthetic-profile', prepared;
  let refreshes = 0, returns = 0, photos = 0;
  const reads = [], writes = [], messages = [], scripts = [];
  const store = { profile: { profileUrl: document, session: 2 }, profileSession: 2, profileUrl: document,
    publishRequestToken: 0, publishFlowToken: 0, publishOptions: [], profileActionsReady: true,
    profileCache: { clear() { store.cleared = true; } } };
  const controller = new PinmonyPublishController(store, {
    authenticated: () => auth, foreground: () => foreground, activeProfileTab: () => true,
    menuVisible: () => visible, sheetAvailable: () => !visible, setMenuVisible: value => { visible = value; },
    profileAddress: () => 'synthetic-profile', documentMatches: profile => document === profile,
    currentDocument: () => document, normalizeProfile: address => address,
    prepareContext: () => new Promise(resolve => { prepared = resolve; }), nativeEnabled: () => true,
    publishScript: () => '', runScript: script => {
      scripts.push(script);
      if (script.includes('PinmonyPublishApi.read')) return new Promise((resolve, reject) => reads.push({ resolve, reject }));
      if (script.includes('PinmonyPublishApi.action') && !script.includes('"close"')) return new Promise((resolve, reject) => writes.push({ resolve, reject }));
      return Promise.resolve('true');
    }, jsonText: value => value, captureBoardReturn() {}, hasBoardReturn: () => false,
    restoreBoard: () => returns++, syncMotion() {}, suppressChildBack() {}, refreshProfile: () => refreshes++,
    pickPhotos: async () => { photos++; }, feedback: value => messages.push(value), traceEntry() {}
  });
  return { controller, store, reads, writes, messages, scripts, ready: value => prepared(value),
    auth: value => { auth = value; }, foreground: value => { foreground = value; }, document: value => { document = value; },
    hideSheet: () => { visible = false; },
    flow() { store.publishFlowToken = 3; store.publishFlow = { token: 3, page: document, profile: 'synthetic-profile', kind: 'website',
      phase: 'website', pins: [], boards: [], selectedIds: [], loading: false, busy: false, uncertain: false, completed: 0 }; },
    reply(extra = {}) { return JSON.stringify({ ...store.publishFlow, ...extra }); },
    refreshes: () => refreshes, returns: () => returns, photos: () => photos
  };
}
(async () => {
  const hidden = harness(); hidden.controller.openMenu(); hidden.hideSheet(); hidden.controller.dismissMenu();
  assert.equal(hidden.store.publishLoading, false);
  assert.equal(hidden.store.publishPreparing, false);
  hidden.ready(true); await flush();
  assert(!hidden.scripts.some(script => script.includes('PublishDiscover')), 'dismissed hidden sheet cannot dispatch');
  hidden.controller.openMenu(); assert.equal(hidden.store.publishLoading, true, 'hidden sheet cleanup allows reopening');
  hidden.controller.dismissMenu(); hidden.ready(true); await flush();
  const menu = harness(); menu.controller.openMenu(); menu.controller.openMenu();
  assert.equal(menu.store.publishRequestToken, 1); menu.controller.dismissMenu(); menu.ready(true); await flush();
  assert(!menu.scripts.some(script => script.includes('PublishDiscover')), 'closed preparation cannot dispatch discovery');
  const failed = harness(); failed.controller.openMenu(); failed.ready(false); await flush();
  assert.equal(failed.store.publishLoading, false); assert.equal(failed.messages.length, 1);
  failed.controller.dismissMenu();
  const paused = harness(); paused.controller.openMenu(); paused.controller.pause(); paused.foreground(false);
  paused.ready(true); await flush(); assert.equal(paused.store.publishPreparing, false);
  assert(!paused.scripts.some(script => script.includes('PublishDiscover')));
  paused.foreground(true); paused.controller.resume(); await flush();
  assert(paused.scripts.some(script => script.includes('PublishDiscover'))); paused.controller.dismissMenu();
  const flow = harness(); flow.flow(); flow.controller.poll(3, 'synthetic-profile'); flow.controller.poll(3, 'synthetic-profile');
  assert.equal(flow.reads.length, 1);
  flow.controller.pause(); flow.foreground(false); flow.reads[0].resolve(flow.reply({ phase: 'done', completed: 1 })); await flush();
  assert(flow.store.publishFlow); assert.equal(flow.messages.length, 0); assert.equal(timers.size, 0);
  flow.foreground(true); flow.controller.resume(); assert.equal(flow.reads.length, 2);
  flow.reads[1].resolve(flow.reply({ phase: 'done', completed: 1 })); await flush();
  assert.equal(flow.store.publishFlow, undefined); assert.equal(flow.refreshes(), 1); assert.equal(flow.returns(), 1);
  assert.equal(flow.messages.length, 1); assert.equal(flow.store.cleared, true);
  const write = harness(); write.flow(); write.controller.action('create', 'synthetic'); write.controller.action('create', 'synthetic');
  assert.equal(write.writes.length, 1); write.controller.close(); assert(write.store.publishFlow);
  write.controller.pause(); write.controller.resume(); assert.equal(write.writes.length, 1, 'resume only reads, never writes');
  write.writes[0].reject(Error('transport')); await flush(); assert.equal(write.store.publishFlow.uncertain, true);
  write.controller.action('create', 'synthetic'); assert.equal(write.writes.length, 1);
  write.controller.close(); write.reads[0].resolve(write.reply({ phase: 'done', completed: 1 })); await flush();
  assert.equal(write.store.publishFlow, undefined, 'late state cannot revive a closed flow');
  const invalid = harness(); invalid.flow(); invalid.store.publishFlow.busy = true;
  invalid.controller.poll(3, 'synthetic-profile'); invalid.reads[0].resolve(invalid.reply({ pins: null })); await flush();
  assert.equal(invalid.store.publishFlow.uncertain, true); assert.equal(invalid.store.publishFlow.busy, false);
  invalid.controller.close();
  const photo = harness(); photo.controller.openMenu(); photo.ready(true); await flush();
  photo.store.publishOptions = [{ id: 'synthetic', kind: 'photo', enabled: true }];
  await photo.controller.select('synthetic'); assert.equal(photo.photos(), 1); assert.equal(photo.reads.length, 1);
  photo.controller.close(true); photo.reads[0].resolve('{}'); await flush(); assert.equal(timers.size, 0);
  const route = harness(); route.flow(); route.controller.poll(3, 'synthetic-profile'); route.document('other');
  route.reads[0].resolve(route.reply({ phase: 'done', completed: 1 })); await flush(); assert(route.store.publishFlow);
  assert.equal(route.messages.length, 0); route.controller.pause();
  console.log('Publish controller: preparation cancellation, single read, pause/resume, completion, write no-replay, uncertain failure, photos and stale route passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
