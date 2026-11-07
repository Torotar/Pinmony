const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const Store = require('./arkts-module-loader.cjs').createArktsLoader(ts).loadFile('feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets').PinmonyInboxStore;
const output = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxUnreadNativeReads.ets', 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021}
}).outputText, {exports: output, console, require: name => name === 'feature_inbox' ? {} :
  name.includes('UpdatesNativeReads') ? {PIN_NATIVE_INBOX_UPDATES_ENABLED: true, INBOX_UPDATE_FIELDS: []} :
  name.includes('MessagesNativeReads') ? {PIN_NATIVE_INBOX_MESSAGES_ENABLED: false} :
  name === 'common_foundation' ? {PinmonyRuntimeLog: {info() {}}} : {}});
const item = (id, updatedAt = 'v1') => ({id: 'inbox-news-api-1-' + id, updatedAt, unread: true, enabled: true});
const snapshot = items => ({kind: 'state', section: 'updates', dataSource: 'api', apiError: '', items});
async function main() {
  const store = new Store(); const callbacks = [];
  store.onUnreadChange = (...args) => callbacks.push(args);
  store.inbox = snapshot([item('1')]); store.inboxUpdatesUnreadCount = 1; store.inboxMessagesUnreadCount = 3;
  store.acknowledgeInboxUpdates();
  assert.equal(store.inboxUpdatesUnreadCount, 0); assert.equal(store.inboxMessagesUnreadCount, 3);
  assert.equal(store.inbox.items[0].unread, true, 'local reminder acknowledgement cannot invent a server read');
  assert.equal(callbacks.at(-1)[0], false, 'top and bottom update indicators receive immediate clear');
  assert.equal(store.isUnseenUpdate(item('1').id, 'v1'), false);
  assert.equal(store.isUnseenUpdate(item('1').id, 'v2'), true, 'a newer update under the same id remains new');
  store.inbox = snapshot([item('dated', '2026-11-07T06:00:00Z')]); store.acknowledgeInboxUpdates();
  assert.equal(store.isUnseenUpdate(item('dated').id, '2026-11-07T05:00:00Z'), false, 'an older version cannot restore a viewed reminder');
  assert.equal(store.isUnseenUpdate(item('dated').id, ''), false, 'a reply without version evidence cannot restore a viewed reminder');
  assert.equal(store.isUnseenUpdate(item('dated').id, '2026-11-07T07:00:00Z'), true);
  store.inbox = snapshot([item('2')]); store.inboxUpdatesUnreadCount = 1;
  for (const state of [{inboxLoading: true}, {inboxError: 'failed'}]) {
    Object.assign(store, state); store.acknowledgeInboxUpdates(); assert.equal(store.inboxUpdatesUnreadCount, 1);
    store.inboxLoading = false; store.inboxError = '';
  }
  store.inbox = {...snapshot([item('2')]), apiError: 'failed'}; store.acknowledgeInboxUpdates(); assert.equal(store.inboxUpdatesUnreadCount, 1);
  store.inbox = {...snapshot([item('2')]), section: 'messages'}; store.acknowledgeInboxUpdates(); assert.equal(store.inboxUpdatesUnreadCount, 1);
  const requests = []; const session = {authenticated: true, accountId: 'synthetic', generation: 1, origin: 'https://www.pinterest.com'};
  const reader = new output.PinmonyInboxUnreadNativeReads({store: () => store, session: () => session, active: () => true,
    network: () => ({cancel() {}, requestBusinessInboxUpdatesRead: () => new Promise(resolve => requests.push(resolve))})});
  const reply = rows => ({status: 200, error: '', body: JSON.stringify({resource_response: {
    status: 'success', endpoint_name: 'v3_get_news_hub_feed', data: rows
  }})});
  let pending = reader.poll();
  store.inbox = snapshot([item('2')]); store.acknowledgeInboxUpdates();
  requests[0](reply([{id: '1', unread: true, last_updated_at: 'v1'}, {id: '2', unread: true, last_updated_at: 'v1'},
    {id: '3', unread: true, last_updated_at: 'v1'}])); await pending;
  assert.equal(store.inboxUpdatesUnreadCount, 1, 'an in-flight old reply cannot restore viewed reminders, but a new id still counts');
  reader.lastPoll.clear(); pending = reader.poll(); requests[1](reply([{id: '1', unread: true, last_updated_at: 'v2'}])); await pending;
  assert.equal(store.inboxUpdatesUnreadCount, 1, 'same id with a newer version reappears');
  reader.reset(); assert.equal(store.isUnseenUpdate(item('1').id, 'v1'), true, 'session reset clears viewed memory');
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const controller = fs.readFileSync('feature_inbox/src/main/ets/controllers/PinmonyInboxReadController.ets', 'utf8');
  assert(index.includes('index <= 3 && !this.inboxStore.inboxFlow && !this.inboxStore.listSection) this.inboxStore.acknowledgeInboxUpdates()'));
  assert(controller.includes("if (section === 'messages') this.store.acknowledgeInboxUpdates()"));
  const sectionStart = controller.indexOf('  async selectSection(');
  const sectionEnd = controller.indexOf('\n  }', sectionStart) + 4;
  const tabStart = index.indexOf('  private selectNativeRootTab(');
  const tabEnd = index.indexOf('\n  }', tabStart) + 4;
  const Hosts = vm.runInNewContext(ts.transpileModule('class SectionHost {' + controller.slice(sectionStart, sectionEnd) +
    '} class TabHost {' + index.slice(tabStart, tabEnd) + '} ({SectionHost,TabHost});', {
    compilerOptions: {target: ts.ScriptTarget.ES2021}
  }).outputText);
  const sectionHost = Object.assign(new Hosts.SectionHost(), {store, preparation: 0, allowed: () => true,
    ports: {activeTab: () => 2, nativeUpdatesSelect: async () => {
      assert.equal(store.inboxUpdatesUnreadCount, 0, 'section departure clears before awaiting the next native page'); return true;
    }}});
  store.inbox = snapshot([item('section')]); store.inboxUpdatesUnreadCount = 1;
  await sectionHost.selectSection('messages'); assert.equal(store.inboxUpdatesUnreadCount, 0);
  store.inbox = snapshot([item('root')]); store.inboxUpdatesUnreadCount = 1;
  const tabHost = Object.assign(new Hosts.TabHost(), {inboxStore: store, authStatus: 'authenticated', activeTab: 2,
    restoreInboxNewsSearchRoot() {}, navigationCoordinator: {selectNativeRootTab() {assert.equal(store.inboxUpdatesUnreadCount, 0);}}});
  tabHost.selectNativeRootTab(0); assert.equal(store.inboxUpdatesUnreadCount, 0);
  const list = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets', 'utf8');
  assert(list.includes(".width('100%').constraintSize({ maxWidth: 360 })"));
  assert(list.includes('.padding({ left: 20, right: 20, top: 12, bottom: 12 })'));
  console.log('Update reminders: immediate local acknowledgement, unchanged server flags, failed/unseen states, old replies, new id/version, session reset and wider list segments passed');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
