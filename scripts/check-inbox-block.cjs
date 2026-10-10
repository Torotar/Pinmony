const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const source = fs.readFileSync('feature_inbox/src/main/ets/services/PinmonyInboxConversationScript.ets', 'utf8');
const code = vm.runInNewContext(source.slice(source.indexOf('`'), source.lastIndexOf('`') + 1));
const requests = [];
const events = [];
const window = { PinmonyInboxConversationsEnabled: true };
window.top = window;
window.PinmonyShareBridge = { inboxState: value => events.push(JSON.parse(value)) };

vm.runInNewContext(code, {
  window,
  location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/inbox/' },
  document: { cookie: 'csrftoken=fixture' },
  URLSearchParams,
  AbortController,
  setTimeout,
  clearTimeout,
  fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve }))
});

const api = window.PinmonyInboxConversations;
const flush = () => new Promise(resolve => setImmediate(resolve));
const latest = () => events.at(-1);
const self = { id: '1', full_name: 'Self' };
const other = { id: '2', full_name: 'Other' };
function reply(endpoint, data) {
  requests.at(-1).resolve({ ok: true, json: async () => ({
    resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data },
    client_context: { user: self }
  }) });
}

(async () => {
  api.read('https://www.pinterest.com/inbox/', () => {}, () => true);
  reply('v3_get_conversations', [{ id: '100', users: [self, other] }]);
  await flush();
  api.open('conversation:100', 7);
  reply('v3_get_conversation', { id: '100', users: [self, other] });
  await flush();
  reply('v3_get_conversation_messages', []);
  await flush();

  assert(api.action('settings', '', 7));
  assert.equal(latest().screen, 'settings');
  assert(api.action('blockUser', '2', 7));
  assert(!api.action('blockUser', '2', 7), 'duplicate block is rejected while pending');
  const blockRequest = requests.at(-1);
  assert(blockRequest.url.includes('/resource/ApiResource/update/'));
  const blockData = JSON.parse(new URLSearchParams(blockRequest.args.body).get('data'));
  assert.deepEqual(blockData.options, { url: '/v3/users/2/block/' });
  reply('v3_block_user', null);
  await flush();
  assert.equal(latest().blocked, true);
  assert.equal(latest().blockedUserId, '2');
  assert.equal(latest().blockRevision, 1);

  assert(api.action('unblockUser', '2', 7));
  const unblockRequest = requests.at(-1);
  assert(unblockRequest.url.includes('/resource/ApiResource/delete/'));
  const unblockData = JSON.parse(new URLSearchParams(unblockRequest.args.body).get('data'));
  assert.deepEqual(unblockData.options, { url: '/v3/users/2/block/' });
  reply('v3_unblock_user', null);
  await flush();
  assert.equal(latest().blocked, false);
  assert.equal(latest().blockRevision, 2);

  api.reset();
  console.log('PASS inbox block: confirmed update/delete contracts, duplicate guard and state revisions');
})().catch(error => {
  api.reset();
  console.error(error);
  process.exitCode = 1;
});
