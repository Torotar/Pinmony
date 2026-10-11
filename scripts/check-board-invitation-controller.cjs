const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const timers = new Map(); let id = 0;
const r = require('./return-coordinator-harness.cjs').runtime(ts, {
  setTimeout: fn => { timers.set(++id, fn); return id; }, clearTimeout: key => timers.delete(key)
});
const { PinmonyBoardInvitationController: Controller } = r.compile('feature_inbox/src/main/ets/controllers/PinmonyBoardInvitationController.ets', () => r.foundation);
const flush = () => new Promise(resolve => setImmediate(resolve));
const item = { boardId: '1', invitedUser: '2', boardUrl: 'https://www.pinterest.com/sample/board/', boardName: 'synthetic',
  imageUrl: '', inviter: '', inviterAvatar: '', invitedAvatar: '', createdAt: '', status: 'new' };
if (process.env.PINMONY_TEST_REGION === 'uk') item.boardUrl=item.boardUrl.replace('www.pinterest.com','uk.pinterest.com');
function harness() {
  let page = item.boardUrl, auth = true, foreground = true;
  const store = { boardInvitationToken: 0, invitationReadPage: '', invitationBusy: false }, reads = [], writes = [], opens = [], messages = [];
  const controller = new Controller(store, { authenticated: () => auth, foreground: () => foreground, page: () => page,
    username: () => 'synthetic', avatar: () => '', script: () => '', jsonText: raw => raw, feedback: text => messages.push(text),
    runScript: script => new Promise((resolve, reject) => {
      (script.includes('.accept(') ? writes : script.includes('.read(') ? reads : opens).push({ resolve, reject });
    }) });
  return { controller, store, reads, writes, opens, messages, page: value => page = value, auth: value => auth = value,
    foreground: value => foreground = value,
    reply: extra => JSON.stringify({ token: store.boardInvitationToken, page, loading: false, busy: false, uncertain: false, error: '', feedback: '', items: [{ ...item }], ...extra }) };
}
async function preview(h) {
  assert(h.controller.preparePreview({ ...item }));
  const open = h.controller.open(true); h.opens[0].resolve('true'); await open;
  h.reads[0].resolve(h.reply()); await flush(); assert.equal(h.store.invitationBusy, false);
}
(async () => {
  const h = harness(); await preview(h);
  h.controller.accept(); h.controller.accept(); assert.equal(h.writes.length, 1, 'double tap cannot replay write');
  h.controller.pause(); h.foreground(false); h.writes[0].resolve('true'); await flush(); assert.equal(h.reads.length, 1);
  h.foreground(true); h.controller.resume(); h.controller.resume(); assert.equal(h.reads.length, 2, 'only one status read');
  h.reads[1].resolve(h.reply({ items: [{ ...item, status: 'accepted', invitedAvatar: 'https://example.invalid/avatar' }], feedback: 'confirmed' })); await flush();
  assert.equal(h.store.invitationBannerVisible, false); assert.equal(h.messages.length, 1); assert.equal(h.writes.length, 1);
  h.controller.resume(); h.reads[2].resolve(h.reply({ items: [{ ...item, status: 'accepted' }], feedback: 'confirmed' })); await flush(); assert.equal(h.messages.length, 1);
  const stale = harness(); await preview(stale); stale.controller.poll(stale.store.boardInvitationToken, true);
  stale.controller.clearPreview(); stale.reads[1].resolve(stale.reply({ items: [{ ...item, status: 'accepted' }], feedback: 'stale' })); await flush();
  assert.equal(stale.store.boardInvitationPreview, undefined); assert.equal(stale.messages.length, 0);
  const route = harness(); await preview(route); route.controller.poll(route.store.boardInvitationToken, true); route.page('https://www.pinterest.com/inbox/');
  route.reads[1].resolve(route.reply({ feedback: 'stale' })); await flush(); assert.equal(route.messages.length, 0);
  const race = harness(); await preview(race); race.controller.poll(race.store.boardInvitationToken, true); race.controller.accept();
  race.reads[1].resolve(race.reply()); await flush(); race.controller.accept(); assert.equal(race.writes.length, 1, 'pre-write read cannot clear submit guard'); race.controller.clearPreview();
  const uncertain = harness(); await preview(uncertain); uncertain.controller.accept(); uncertain.writes[0].reject(Error('unknown')); await flush();
  uncertain.controller.accept(); assert.equal(uncertain.writes.length, 1); assert.equal(uncertain.store.invitationBusy, true);
  const invalid = harness(); await preview(invalid); invalid.controller.poll(invalid.store.boardInvitationToken, true);
  invalid.reads[1].resolve(invalid.reply({ items: [{ ...item, boardId: '3', status: 'accepted' }], feedback: 'wrong' })); await flush();
  assert.equal(invalid.store.boardInvitationPreview.status, 'new'); assert.equal(invalid.store.invitationBusy, true);
  const delayed = harness(); delayed.controller.preparePreview(item); const opening = delayed.controller.open(true); delayed.controller.reset(); delayed.opens[0].resolve('true'); await opening;
  assert.equal(delayed.reads.length, 0); assert.equal(delayed.store.boardInvitationPreview, undefined);
  const loading = harness(); await preview(loading); loading.controller.poll(loading.store.boardInvitationToken, true);
  loading.reads[1].resolve(loading.reply({ loading: true })); await flush(); assert.equal(timers.size, 1); loading.controller.pause(); assert.equal(timers.size, 0);
  loading.foreground(false); loading.controller.accept(); loading.controller.resume(); assert.equal(loading.reads.length, 2);
  const denied = harness(); denied.auth(false); assert.equal(denied.controller.preparePreview(item), false); await denied.controller.open(); assert.equal(denied.opens.length, 0);
  console.log('Invitation controller: current identity/route, single read, timer cleanup, pause/resume, no write replay, confirmed acceptance and stale responses passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
