const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('feature_inbox/src/main/ets/services/PinmonyInboxConversationScript.ets', 'utf8');
const code = vm.runInNewContext(source.slice(source.indexOf('`'), source.lastIndexOf('`') + 1));
const requests = [], events = [], w = { PinmonyInboxConversationsEnabled: true }; w.top = w;
w.PinmonyShareBridge = { inboxState: value => events.push(JSON.parse(value)) };
vm.runInNewContext(code, { window: w, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/inbox/' },
  document: { cookie: '' }, URLSearchParams, AbortController, setTimeout, clearTimeout,
  fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
const api = w.PinmonyInboxConversations, me = { id: '1', full_name: 'Self' }, peer = { id: '2', full_name: 'Peer' };
const flush = () => new Promise(resolve => setImmediate(resolve));
const response = (request, endpoint, data, bookmark = '') => request.resolve({ ok: true, json: async () => ({
  resource_response: { status: 'success', endpoint_name: endpoint, data, bookmark }, client_context: { user: me } }) });
const message = reactions => ({ id: '300', text: 'hello', created_at: '2026-10-13T09:00:00Z', sender: peer, reactions });
(async () => {
  const key = 'https://www.pinterest.com/inbox/'; let changes = 0;
  api.read(key, () => changes++, () => true);
  response(requests.at(-1), 'v3_get_conversations', [{ id: '100', users: [me, peer] }]); await flush();
  const cached = api.read(key, () => changes++, () => true, true);
  const count = requests.length;
  assert.equal(cached.kind, 'ready');
  api.read(key, () => changes++, () => true, true); assert.equal(requests.length, count);
  response(requests.at(-1), 'v3_get_conversations', [{ id: '100', users: [me, peer], unread: true }]); await flush();
  assert(api.read(key, () => {}, () => true).items[0].unread);
  api.open('conversation:100', 7);
  response(requests.at(-1), 'v3_get_conversation', { id: '100', users: [me, peer] }); await flush();
  response(requests.at(-1), 'v3_get_conversation_messages', [message([])], 'older'); await flush();
  assert(!api.pollChat(8)); assert(api.pollChat(7)); assert(!api.pollChat(7));
  assert(!events.at(-1).loading);
  assert(requests.at(-1).url.includes('/get/')); assert(!requests.at(-1).args.method);
  response(requests.at(-1), 'v3_get_conversation_messages', [message([{ '2': '👍' }])], 'new-cursor'); await flush();
  assert.deepEqual(events.at(-1).messages[0].reactions, ['👍']);
  assert.equal(events.at(-1).bookmark, 'older');
  assert(api.pollChat(7)); const late = requests.at(-1);
  api.close(7, '100'); response(late, 'v3_get_conversation_messages', [message([{ '2': '👎' }])]);
  const before = events.length; await flush(); assert.equal(events.length, before);
  api.reset(); console.log('PASS live inbox: quiet cache replacement, duplicate-read guard, remote reactions, cursor retention, session/close guards and read-only polling');
})().catch(error => { api.reset(); console.error(error); process.exitCode = 1; });
