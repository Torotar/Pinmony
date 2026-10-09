const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const vm = require('vm');
const assert = require('assert');

const source = readSourceFileSync('entry/src/main/ets/services/PinWebInboxScript.ets', 'utf8');
assert(!/querySelector|MutationObserver|\.click\s*\(/.test(source), 'inbox bridge must not read or click DOM');
assert(!/dataSource:\s*['"]dom['"]|contactsDataSource:\s*['"]dom['"]/.test(source), 'inbox bridge must not publish DOM source');
const tick = String.fromCharCode(96);
const code = vm.runInNewContext(source.slice(source.indexOf(tick), source.lastIndexOf(tick) + 1));
const events = [];
const timers = [];
const w = {
  top: null, listeners: {}, PinWebInboxApiEnabled: true, PinWebInboxContactsApiEnabled: true,
  PinWebInboxConversationsEnabled: true,
  PinWebShareBridge: { inboxState: value => events.push(JSON.parse(value)) },
  addEventListener(name, fn) { this.listeners[name] = fn; },
  setInterval() {},
  setTimeout(fn) { timers.push(fn); }
};
w.top = w;
const api = { kind: 'loading', items: [], hasMore: false, moreLoading: false, moreError: '',
  read(page, changed) { this.changed = changed; return this; },
  reset() { this.kind = 'loading'; this.items = []; },
  more() { return true; } };
const contacts = { kind: 'loading', items: [], read(page, changed) { this.changed = changed; return this; },
  reset() { this.kind = 'loading'; this.items = []; } };
const conversations = { kind: 'loading', items: [], read(page, changed) { this.changed = changed; return this; },
  reset() { this.kind = 'loading'; this.items = []; },
  open(id) { return id === 'conversation:1' || id === 'compose' || id === 'contact:2' || id === 'news-menu:1'; } };
w.PinWebInboxApi = api; w.PinWebInboxContactsApi = contacts; w.PinWebInboxConversations = conversations;
const context = { window: w, setTimeout: w.setTimeout, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/inbox/' } };
vm.runInNewContext(code, context);
assert.equal(timers.length, 1);
timers.shift()();
assert.equal(events.at(-1).section, 'messages');
assert.equal(events.at(-1).kind, 'apiPending');
assert.equal(events.at(-1).dataSource, 'api');
assert.equal(events.at(-1).contactsDataSource, 'api');
conversations.kind = 'ready'; conversations.items = [{ id: 'conversation:1', title: 'A', subtitle: '', imageUrl: '', enabled: true }];
contacts.kind = 'ready'; contacts.items = [{ userId: '2', title: 'B', subtitle: '@b', imageUrl: '', enabled: false }];
w.PinWebInboxSelectApi('updates', events.at(-1).session);
assert.equal(timers.length, 1); timers.shift()();
assert.equal(events.at(-1).section, 'updates');
assert.equal(events.at(-1).kind, 'apiPending');
api.kind = 'ready'; api.items = [{ id: 'n1', title: 'N', subtitle: '', imageUrl: '', enabled: false }];
w.PinWebInboxSelectApi('updates', events.at(-1).session);
timers.shift()?.();
assert.equal(events.at(-1).items[0].enabled, true);
assert.equal(events.at(-1).items[0].moreId, 'news-menu:n1');
w.PinWebInboxSelectApi('messages', events.at(-1).session); timers.shift()?.();
assert.equal(w.PinWebInboxApiAction('conversation:1', events.at(-1).session), true);
context.location.pathname = '/pin/1/';
console.log('PASS inbox interface-only bridge: no DOM selectors/clicks, API source, API section switching, action routing');















