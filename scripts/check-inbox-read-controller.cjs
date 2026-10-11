const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const timers = new Map(); let next = 0;
const { Store, PinmonyInboxReadController } = require('./inbox-read-controller-harness.cjs').create(ts, {
  setTimeout: (fn, ms) => { timers.set(++next, { fn, ms }); return next; }, clearTimeout: id => timers.delete(id)
});
const page = 'https://www.pinterest.com/inbox/';
let document = page, foreground = true, authenticated = true, response = async () => 'true', prepare = async () => true;
const store = new Store(), requests = [], feedback = [];
const controller = new PinmonyInboxReadController(store, {
  authenticated: () => authenticated, foreground: () => foreground, document: () => document, addressKey: a => a,
  inboxAddress: a => a.startsWith(page) ? page : '', currentInbox: () => page, activeTab: () => 2, pendingTab: () => -1,
  rootAddress: () => page, rootOnly: () => false, interacted: () => true, backTarget: () => '',
  runScript: script => { requests.push(script); return response(); }, finishPull() {}, readInvitations() {}, recordAddress() {},
  confirmed() {}, readStarted() {}, cancelled() {}, prepareContext: () => prepare(), prepareRead: () => false, requestRead() {}, feedback: message => feedback.push(message)
});
const message = (kind = 'state', section = 'messages', items = []) => ({ kind, section, session: 1, pageUrl: page,
  updateLabel: '更新', inboxLabel: '收件箱', items, contacts: [], dataSource: 'api', hasMore: true });
const update = (...args) => controller.update(JSON.stringify(message(...args)));
(async () => {
  controller.expect(); assert.equal(timers.size, 1); controller.pause(); assert.equal(timers.size, 0);
  update(); assert.equal(store.inboxActionsReady, true); assert.equal(store.inbox.items.length, 0, 'normal empty is authoritative');
  store.inboxScrollOffset = 140; store.inboxCache.put(store.inbox, 140); assert(controller.restore(page)); assert.equal(store.inboxScrollOffset, 140);
  assert.equal(store.inboxActionsReady, false, 'cache never enables controls');
  update('state', 'messages', [{ id: 'c', title: 'cached', enabled: true }]);
  update('apiFailed'); assert.equal(store.inbox.items[0].title, 'cached'); assert.equal(store.inboxActionsReady, false);
  await controller.selectSection('updates'); assert(requests.at(-1).includes('PinmonyInboxSelectApi'));
  const oldTimeout = [...timers.values()].find(t => t.ms === 4500).fn;
  controller.pause(); const oldError = store.inboxError; oldTimeout(); assert.equal(store.inboxError, oldError); assert.equal(feedback.length, 0);
  update('state', 'updates');
  let reject; response = () => new Promise((_, r) => { reject = r; });
  const refresh = controller.refresh(); update('state', 'updates'); reject(Error('late')); await refresh;
  assert.equal(store.inboxError, '', 'late refresh failure cannot overwrite newer state');
  response = async () => 'true'; update('state', 'updates');
  let resolve; response = () => new Promise(r => { resolve = r; });
  const more = controller.loadMore(); const count = requests.length; await controller.loadMore(); assert.equal(requests.length, count);
  resolve('true'); await more;
  const previous = store.inbox; document = page + '?document=changed';
  response = () => new Promise((_, r) => { reject = r; }); const contacts = controller.refresh();
  document = page + '?document=new'; reject(Error('late')); await contacts; assert.equal(store.inboxError, '');
  document = 'https://www.pinterest.com/pin/1/'; update(); assert.equal(store.inbox, previous, 'hidden foreign document cannot replace inbox');
  document = page; foreground = false; update(); assert.equal(store.inbox, previous);
  foreground = true; authenticated = false; await controller.refresh(); assert.equal(requests.length, count + 1);
  authenticated = true; update(); assert.equal(store.inbox.items.length, 0, 'fresh empty replaces retained content');
  let ready; prepare = () => new Promise(r => { ready = r; }); response = async () => 'true';
  const waiting = controller.refreshContacts(); controller.clear(); update(); ready(true); await waiting;
  assert(requests.at(-1).includes('PinmonyInboxContactsApiRefresh(1)'), 'document preparation keeps latest intent after old snapshot clear');
  const afterPrepare = requests.length, cancelled = controller.refreshContacts(); controller.pause(); ready(true); await cancelled;
  assert.equal(requests.length, afterPrepare, 'background cancellation discards waiting intent');
  prepare = async () => true; update('state','updates');
  await controller.refresh(); const beforeDuplicate = requests.length; await controller.refresh();
  assert.equal(requests.length, beforeDuplicate, 'acknowledgement alone does not unlock repeated refresh');
  const pendingTimer = [...timers.values()].find(t => t.ms === 20000); pendingTimer.fn();
  assert.match(store.inboxError, /超时/); await controller.refresh(); assert.equal(requests.length, beforeDuplicate + 1);
  controller.pause(); console.log('Inbox read: current context, cache/empty/error, single flight, cancellation and late responses passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
