const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const timers = new Map(); let timerId = 0;
const { PinmonyPublishController } = require('./publish-controller-harness.cjs').create(ts, {
  setTimeout: fn => { timers.set(++timerId, fn); return timerId; }, clearTimeout: id => timers.delete(id)
});
const flush = () => new Promise(resolve => setImmediate(resolve));
function harness(native = false) {
  let auth = true, foreground = true, visible = false, document = 'synthetic-profile', prepared;
  let refreshes = 0, returns = 0, photos = 0, suppressed = 0, sections = 0, boardReturn = false, closeSheet;
  const reads = [], writes = [], messages = [], scripts = [], restoreModes = [];
  const store = { profile: { profileUrl: document, session: 2 }, profileSession: 2, profileUrl: document,
    publishRequestToken: 0, publishFlowToken: 0, publishOptions: [], profileActionsReady: true, profileSessionReady: true,
    profileCache: { clear() { store.cleared = true; } } };
  const controller = new PinmonyPublishController(store, {
    authenticated: () => auth, foreground: () => foreground, activeProfileTab: () => true,
    menuVisible: () => visible, sheetAvailable: () => !visible, setMenuVisible: value => { visible = value; },
    waitMenuClosed: () => new Promise(resolve => { closeSheet = resolve; }),
    profileAddress: () => 'synthetic-profile', documentMatches: profile => document === profile,
    currentDocument: () => document, normalizeProfile: address => address,
    prepareContext: () => new Promise(resolve => { prepared = resolve; }), nativeEnabled: () => true,
    nativeFlow: () => native,
    nativeAction: async action => {
      if(action === 'back') {
        assert(suppressed > 0, 'child back must suppress root propagation before changing phase');
        store.publishFlow.phase = 'select';
      }
    },
    publishScript: () => '', runScript: script => {
      scripts.push(script);
      if (script.includes('PinmonyPublishApi.read')) return new Promise((resolve, reject) => reads.push({ resolve, reject }));
      if (script.includes('PinmonyPublishApi.action') && !script.includes('"close"')) return new Promise((resolve, reject) => writes.push({ resolve, reject }));
      return Promise.resolve('true');
    }, jsonText: value => value, captureBoardReturn() {}, hasBoardReturn: () => boardReturn,
    openSection() { sections++; },
    restoreBoard: refresh => {returns++;restoreModes.push(!!refresh);}, syncMotion() {}, suppressChildBack() { suppressed++; }, refreshProfile: () => refreshes++,
    pickPhotos: async () => { photos++; }, feedback: value => messages.push(value), traceEntry() {}
  });
  return { controller, store, reads, writes, messages, scripts, restoreModes, ready: value => prepared(value),
    auth: value => { auth = value; }, foreground: value => { foreground = value; }, document: value => { document = value; },
    hideSheet: () => { visible = false; },
    disappear: value => closeSheet(value),
    flow() { store.publishFlowToken = 3; store.publishFlow = { token: 3, page: document, profile: 'synthetic-profile', kind: 'website',
      phase: 'website', pins: [], boards: [], selectedIds: [], loading: false, busy: false, uncertain: false, completed: 0 }; },
    reply(extra = {}) { return JSON.stringify({ ...store.publishFlow, ...extra }); },
    refreshes: () => refreshes, returns: () => returns, photos: () => photos, suppressed: () => suppressed,
    boardReturn: value => { boardReturn = value; }, sections: () => sections
  };
}
(async () => {
  const uncertainBack=harness(true);uncertainBack.flow();uncertainBack.store.publishFlow.uncertain=true;
  uncertainBack.controller.action('back','website');assert.equal(uncertainBack.store.publishFlow,undefined,'uncertain flow closes without another write');
  for(const phase of ['topics','products','advanced','boards']) {
    const childBack=harness(true);childBack.flow();childBack.store.publishFlow.kind='photo';childBack.store.publishFlow.phase=phase;
    childBack.controller.action('back');assert.equal(childBack.store.publishFlow.phase,'select');assert.equal(childBack.suppressed(),1);assert.equal(childBack.returns(),0,'child return must retain publish flow');
    childBack.controller.action('back',phase);assert.equal(childBack.store.publishFlow.phase,'select','a late back from the old destination cannot close the editor');
    childBack.controller.action('close');assert.equal(childBack.store.publishFlow.draftExitRequested,true,'unsaved photo editor requests confirmation');
    childBack.controller.action('cancelDraftExit');assert.equal(childBack.store.publishFlow,undefined,'cancel exits without saving');
  }
  const cancelledPublish = harness();cancelledPublish.flow();cancelledPublish.controller.close();assert.deepEqual(cancelledPublish.restoreModes,[false],'cancelled publish preserves board');
  const completedPublish = harness();completedPublish.flow();completedPublish.store.publishFlow.completed = 1;completedPublish.controller.close();assert.deepEqual(completedPublish.restoreModes,[true],'completed publish revalidates board');
  const unknownPublish = harness();unknownPublish.flow();unknownPublish.store.publishFlow.uncertain = true;unknownPublish.controller.close();assert.deepEqual(unknownPublish.restoreModes,[true],'unknown write revalidates without replay');

  const closing = harness(); closing.controller.openMenu();
  closing.store.publishOptions = [{id:'board',kind:'board',label:'Board',enabled:true}];
  closing.store.publishLoading = false;
  const closingOptions = closing.store.publishOptions;
  closing.hideSheet(); closing.controller.dismissMenu();
  assert.equal(closing.store.publishOptions, closingOptions, 'dismissal retains rendered options during Sheet exit');
  assert.equal(closing.store.publishLoading, false, 'dismissal releases business loading state');
  closing.controller.openMenu();
  assert.equal(closing.store.publishOptions.length, 0, 'next opening clears the old menu before reading');
  const hidden = harness(); hidden.controller.openMenu(); hidden.hideSheet(); hidden.controller.dismissMenu();
  assert.equal(hidden.store.publishLoading, false);
  assert.equal(hidden.store.publishPreparing, false);
  assert.equal(hidden.suppressed(), 1, 'dismissal consumes the child back event');
  hidden.ready(true); await flush();
  assert(!hidden.scripts.some(script => script.includes('PublishDiscover')), 'dismissed hidden sheet cannot dispatch');
  hidden.controller.openMenu(); assert.equal(hidden.store.publishLoading, true, 'hidden sheet cleanup allows reopening');
  hidden.controller.dismissMenu(); hidden.ready(true); await flush();
  const menu = harness(); menu.controller.openMenu(); menu.controller.openMenu();
  assert.equal(menu.store.publishRequestToken, 1); menu.controller.dismissMenu(); menu.ready(true); await flush();
  const independentMenu = harness(); independentMenu.store.profileActionsReady = false;
  independentMenu.controller.openMenu(); independentMenu.ready(true); await flush();
  assert(independentMenu.scripts.some(script => script.includes('PublishDiscover')), 'confirmed session opens menu without waiting for retained list');
  independentMenu.controller.dismissMenu();
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
  const selectingPhoto = photo.controller.select('synthetic');
  assert.equal(photo.store.publishFlow, undefined, 'child cannot mount under a closing sheet');
  assert.equal(photo.photos(), 0, 'system picker waits for sheet disappearance');
  await photo.controller.select('synthetic');
  photo.disappear(true); await selectingPhoto;
  assert.equal(photo.photos(), 1); assert.equal(photo.reads.length, 1);
  photo.controller.close(true); photo.reads[0].resolve('{}'); await flush(); assert.equal(timers.size, 0);
  for (const kind of ['website', 'board']) {
    const child = harness(); child.controller.openMenu(); child.ready(true); await flush();
    child.store.publishOptions = [{ id: kind, kind, enabled: true }];
    const selected = child.controller.select(kind);
    assert.equal(child.store.publishFlow, undefined);
    assert.equal(child.returns(), 0, 'selection must not navigate back while closing menu');
    child.disappear(true); await selected;
    assert.equal(child.store.publishFlow.kind, kind);
    child.controller.close(true); child.reads[0].resolve('{}'); await flush();
  }
  const cancelledChild = harness(); cancelledChild.controller.openMenu(); cancelledChild.ready(true); await flush();
  cancelledChild.store.publishOptions = [{ id: 'website', kind: 'website', enabled: true }];
  const cancelledSelection = cancelledChild.controller.select('website');
  cancelledChild.controller.dismissMenu(); cancelledChild.disappear(true); await cancelledSelection;
  assert.equal(cancelledChild.store.publishFlow, undefined, 'back during closing cancels deferred child');
  assert(!cancelledChild.scripts.some(script => script.includes('PinmonyPublishApi.open')));
  const stuck = harness(); stuck.controller.openMenu(); stuck.ready(true); await flush();
  stuck.store.publishOptions = [{ id: 'board', kind: 'board', enabled: true }];
  const stuckSelection = stuck.controller.select('board'); stuck.disappear(false); await stuckSelection;
  assert.equal(stuck.store.publishFlow, undefined, 'missing disappearance cannot open a child');
  assert.equal(stuck.returns(), 1);
  const section = harness(); section.boardReturn(true); section.controller.openMenu(); section.ready(true); await flush();
  const enteringSection = section.controller.selectSection();
  assert.equal(section.sections(), 0, 'section waits for old menu disappearance');
  assert.equal(section.returns(), 0, 'section retains its board until closing');
  section.disappear(true); await enteringSection;
  assert.equal(section.sections(), 1);
  assert(!section.scripts.some(script => script.includes('PinmonyPublishApi.open')), 'unconnected section cannot dispatch publish');
  const cancelledSection = harness(); cancelledSection.boardReturn(true); cancelledSection.controller.openMenu(); cancelledSection.ready(true); await flush();
  const pendingSection = cancelledSection.controller.selectSection();
  cancelledSection.controller.dismissMenu(); cancelledSection.disappear(true); await pendingSection;
  assert.equal(cancelledSection.sections(), 0, 'back cancels deferred section');
  const route = harness(); route.flow(); route.controller.poll(3, 'synthetic-profile'); route.document('other');
  route.reads[0].resolve(route.reply({ phase: 'done', completed: 1 })); await flush(); assert(route.store.publishFlow);
  assert.equal(route.messages.length, 0); route.controller.pause();
  console.log('Publish controller: preparation cancellation, single read, pause/resume, completion, write no-replay, uncertain failure, photos and stale route passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
