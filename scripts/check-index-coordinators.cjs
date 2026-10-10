const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { runtime } = require('./return-coordinator-harness.cjs');
const timers = new Map(); let timerId = 0;
const r = runtime(ts, { setTimeout: fn => { timers.set(++timerId, fn); return timerId; }, clearTimeout: id => timers.delete(id) });
const flush = () => new Promise(resolve => setImmediate(resolve));
const runTimers = () => { const list = [...timers.values()]; timers.clear(); list.forEach(fn => fn()); };
function returnHarness() {
  let token = 1, pending = true, matches = false, loads = 0, history = 0;
  const scripts = [], confirms = [], marks = [];
  const coordinator = new r.PinmonyReturnCoordinator({
    isCurrent: value => value === token, isPending: () => pending,
    isHome: value => value === 'home', isBoard: value => value === 'board',
    documentMatches: () => matches,
    runScript: script => new Promise((resolve, reject) => scripts.push({ script, resolve, reject })),
    useHistory: () => { history++; return true; }, load: () => loads++,
    confirm: (target, bindDetail) => { pending = false; confirms.push([target, bindDetail]); },
    cancelHistory() {}, mark: value => marks.push(value)
  });
  return { coordinator, scripts, confirms, marks, loads: () => loads, history: () => history,
    supersede: () => token++, matches: value => { matches = value; } };
}
async function returns() {
  const h = returnHarness(); h.matches(true); h.coordinator.synchronize('home', 1, true, true);
  h.coordinator.cancel(); h.scripts[0].resolve('true'); await flush();
  assert.equal(h.confirms.length, 0, 'cancelled home probe cannot confirm'); assert.equal(timers.size, 0);
  const fallback = returnHarness(); fallback.coordinator.synchronize('profile', 1, false, false);
  runTimers(); assert.equal(fallback.scripts.length, 1);
  fallback.coordinator.cancel(); fallback.scripts[0].resolve('false'); await flush();
  assert.equal(fallback.loads(), 0, 'late history failure cannot load a departed page');
  const current = returnHarness(); current.coordinator.synchronize('profile', 1, false, false);
  runTimers(); current.matches(true); current.scripts[0].resolve('true'); await flush();
  assert.deepEqual(current.confirms, [['profile', true]]);
  const direct = returnHarness(); direct.coordinator.synchronize('board', 1, false, true);
  assert.equal(direct.history(), 0); assert.equal(direct.loads(), 1); assert.equal(timers.size, 0);
  const generation = returnHarness(); generation.coordinator.synchronize('profile', 1, false, false);
  assert.equal(timers.size, 1); generation.coordinator.synchronize('board', 1, false, true);
  assert.equal(timers.size, 0, 'new return removes old physical timer');
}
const { PinmonyBoardCollaboratorsController } = r.compile(
  'feature_board/src/main/ets/controllers/PinmonyBoardCollaboratorsController.ets', () => r.foundation);
function boardHarness() {
  let token = 0, state, foreground = true, page = 'synthetic-board';
  const reads = [], feedback = [], actions = [];
  const controller = new PinmonyBoardCollaboratorsController({
    board: () => ({ editable: true, ready: true, session: 1, pageKey: page }),
    currentPage: () => page, canOpen: () => foreground, foreground: () => foreground,
    state: () => state, setState: value => { state = value; }, token: () => token, nextToken: () => ++token,
    runScript: script => {
      if (script.includes('collaboratorsOpen')) return Promise.resolve('true');
      if (script.includes('collaboratorsRead')) return new Promise(resolve => reads.push(resolve));
      actions.push(script); return Promise.resolve('true');
    }, jsonText: value => value, feedback: value => feedback.push(value), trace() {}
  });
  return { controller, reads, feedback, actions, state: () => state,
    foreground: value => { foreground = value; }, page: value => { page = value; },
    reply: extra => JSON.stringify({ token, page, phase: 'members', users: [], suggestions: [],
      owner: true, busy: false, loading: false, uncertain: false, feedback: '', ...extra }) };
}
async function board() {
  const h = boardHarness(); await h.controller.open();
  assert.equal(h.reads.length, 1); h.controller.poll(h.state().token); assert.equal(h.reads.length, 1, 'one read in flight');
  h.controller.pause(); h.foreground(false); h.reads[0](h.reply({ feedback: 'late' })); await flush();
  assert.equal(h.feedback.length, 0); assert.equal(timers.size, 0, 'background never reschedules');
  h.foreground(true); h.controller.poll(h.state().token); assert.equal(h.reads.length, 2);
  h.reads[1](h.reply()); await flush(); assert.equal(timers.size, 1);
  h.controller.action('save', JSON.stringify({ permission: 3, invites: true })); assert.equal(h.actions.length, 0);
  h.controller.action('save', JSON.stringify({ permission: 1, invites: true })); assert.equal(h.actions.length, 1);
  h.controller.close(); assert.equal(h.state(), undefined); assert.equal(timers.size, 0);
  const late = boardHarness(); await late.controller.open(); late.controller.close();
  late.reads[0](late.reply()); await flush(); assert.equal(late.state(), undefined);
  const route = boardHarness(); await route.controller.open(); route.page('other');
  route.reads[0](route.reply()); await flush(); assert.equal(route.state().loading, true); assert.equal(timers.size, 0);
  const busy = boardHarness(); await busy.controller.open();
  busy.reads[0](busy.reply({ busy: true })); await flush();
  busy.controller.close(); assert(busy.state(), 'sent busy flow remains visible');
  busy.controller.pause(); assert.equal(timers.size, 0); assert.equal(busy.actions.length, 0, 'pause never replays a write');
}
(async () => {
  await returns(); await board();
  console.log('Index coordinators: cancelled/late returns, physical timer cleanup, single read, route gates, busy writes and permission validation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
