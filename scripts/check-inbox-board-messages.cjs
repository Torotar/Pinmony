const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/services/PinmonyInboxConversationScript.ets', 'utf8');
const code = vm.runInNewContext(source.slice(source.indexOf('`'), source.lastIndexOf('`') + 1));
const origin = 'https://uk.pinterest.com', inbox = origin + '/inbox/', target = origin + '/sample/board/';
const me = { id: '1', full_name: 'Self' }, peer = { id: '2', full_name: 'Peer' };
const sample = { id: '123', name: 'Sample board', url: '/sample/board/', pin_count: 48, section_count: 1,
  pin_thumbnail_urls: [1, 2, 3, 4].map(i => 'https://i.pinimg.com/sample-' + i + '.jpg'),
  cover_images: { '400x300': { url: 'https://i.pinimg.com/cover.jpg' } } };
const requests = [], events = [], location = { hostname: 'uk.pinterest.com', origin, pathname: '/inbox/' };
const window = { PinmonyInboxConversationsEnabled: true, PinmonyShareBridge: { inboxState: v => events.push(JSON.parse(v)) } };
window.top = window;
vm.runInNewContext(code, { window, location, URL, URLSearchParams, AbortController, setTimeout, clearTimeout,
  document: { cookie: '' }, fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
const api = window.PinmonyInboxConversations, flush = () => new Promise(resolve => setImmediate(resolve));
async function reply(endpoint, data, bookmark = '-end-') {
  requests.at(-1).resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0,
    endpoint_name: endpoint, data, bookmark }, client_context: { user: me } }) });
  await flush();
}
const message = (id, sender, board = sample) => ({ id, sender, board, text: '', created_at: '2026-10-13T10:00:00Z' });

function navigationChecks() {
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const start = index.indexOf('  private openInboxBoard(');
  const method = index.slice(start, index.indexOf('\n  private ', start + 1));
  const context = { PinmonyI18n:require('./local-message-test-fixture.cjs').rawLocalMessages, PIN_BOARD_API_ENABLED: true, PIN_NATIVE_BOARD_READS_ENABLED: false };
  vm.runInNewContext(ts.transpileModule('class Native {' + method + '} globalThis.Native = Native;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
  function harness() {
    const n = new context.Native(), loads = [], timers = [];
    Object.assign(n, { sessionDocumentUrl:()=>n.controller.getUrl(),loadSessionDocument:url=>n.controller.loadUrl(url),PinmonyI18n:require('./local-message-test-fixture.cjs').rawLocalMessages, authStatus: 'authenticated', activeTab: 2, businessSuspended: false, activeSheetKind: '',
      pinStore: {}, inboxMessagesNativeReads: {ownsFlow:()=>false}, boardStore: { boardOpeningToken: 0 }, inboxStore: { inboxSession: 7, chatScrollOffset: 321,
        inboxFlow: { screen: 'chat', pageUrl: inbox, session: 7, conversationId: '100',
          messages: [{ id: '301', board: { id: '123', title: 'Sample board', url: target, pinCount: 48 } }] } },
      currentInboxUrl: () => inbox, inboxUrlFromAddress: v => v === inbox ? inbox : '',
      controller: { getUrl: () => inbox, loadUrl: v => loads.push(v) }, nativeBoardVisible: () => false,
      boardUrlFromAddress: v => v === target ? target : '', rejectOfflineAction: () => false,
      traceAction() {}, returnCoordinator: { cancel() {} }, pageHistory: { cancelBack() {} }, pageBackToken: 0,
      pagePerformance: { beginSecondary() {} }, clearRootTabGuard() {}, syncFloatingTabsMotion() {},
      coordinatorTasks: { timeout: fn => timers.push(fn) }, currentBoardUrl: () => target, showMessage() {} });
    return { n, loads, timers };
  }
  const h = harness(); h.n.openInboxBoard('301');
  assert.deepEqual(h.loads, [target]); assert.equal(h.n.boardStore.rootTab, 2);
  assert.equal(h.n.boardStore.boardReturnUrl, inbox); assert.equal(h.n.inboxStore.retainedChat.conversationId, '100');
  assert.equal(h.n.inboxStore.chatScrollOffset, 321); assert.equal(h.n.boardStore.boardDetail.ready, false);
  h.n.openInboxBoard('301'); assert.equal(h.loads.length, 1, 'duplicate navigation is blocked');
  h.n.boardStore.boardOpeningToken += 5; h.timers[0]();
  assert.equal(h.n.boardStore.boardDetail.error, '', 'superseded timeout cannot mutate the board');
  for (const mutation of [n => n.inboxStore.inboxFlow.messages[0].deleted = true,
    n => n.inboxStore.inboxFlow.session = 6, n => n.activeTab = 1, n => n.authStatus = 'unknown',
    n => n.inboxStore.inboxFlow.messages[0].board.url = 'https://example.test/sample/board/',
    n => n.controller.getUrl = () => inbox + '?old-document']) {
    const invalid = harness(); mutation(invalid.n); invalid.n.openInboxBoard('301'); assert.equal(invalid.loads.length, 0);
  }
  const native = harness(); native.n.inboxMessagesNativeReads.ownsFlow = () => true; native.n.controller.getUrl = () => {throw Error('unused Web document');}; native.n.openInboxBoard('301'); assert.deepEqual(native.loads,[target],'validated native chat opens board without Web address');
  const failed = harness(); failed.n.controller.loadUrl = () => { throw Error('fixture'); };
  failed.n.openInboxBoard('301'); assert.equal(failed.n.boardStore.boardDetail, undefined);
  assert.equal(failed.n.inboxStore.retainedChat, undefined); assert.equal(failed.n.boardStore.pendingBoardUrl, '');
  assert(index.includes('&& !this.nativeBoardVisible() && this.inboxStore.inboxFlow'), 'chat cannot cover board');
  const navSource = fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets', 'utf8');
  const backStart = navSource.indexOf('onBackPress(): boolean');
  const backMethod = navSource.slice(backStart, navSource.lastIndexOf('\n}'));
  const backContext = { PinmonyRuntimeLog: { info() {} } };
  vm.runInNewContext(ts.transpileModule('class Back {' + backMethod + '} globalThis.Back = Back;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, backContext);
  const back = new backContext.Back(), actions = [];
  Object.assign(back, { inboxStore: { inboxFlow: {} }, boardStore: { pendingBoardUrl: target }, pinStore: {}, profileStore: {}, searchStore: {},
    ports: new Proxy({ backFromBoard: () => actions.push('board'), inboxFlowAction: () => actions.push('chat'),
      authStatus: () => 'authenticated', pageHistory: () => ({ isPending: () => false }) },
      { get: (obj, key) => obj[key] || (() => '') }) });
  assert.equal(back.onBackPress(), true); assert.deepEqual(actions, ['board'], 'system back closes the child board first');
  back.boardStore.pendingBoardUrl = ''; back.onBackPress(); assert.deepEqual(actions, ['board', 'chat']);
  back.ports.nativeBackTarget = () => inbox;
  back.inboxStore.inboxFlow.pageUrl = inbox;
  back.ports.inboxUrlFromAddress = value => value === inbox ? inbox : '';
  back.ports.currentBoardUrl = () => target;
  back.onBackPress(); assert.deepEqual(actions, ['board', 'chat', 'chat'], 'visible chat back wins while hidden Web remains on the old board');
}

(async () => {
  const list = api.read(inbox, () => {}, () => true);
  await reply('v3_get_conversations', [{ id: '100', users: [me, peer], last_message: message('301', me) },
    { id: '101', users: [me, peer], last_message: message('302', peer) }]);
  assert.equal(list.items[0].subtitle, '你发送了一个图板'); assert.equal(list.items[1].subtitle, '发送了一个图板');
  assert(api.open('conversation:100', 7)); await reply('v3_get_conversation', { id: '100', users: [me, peer] });
  await reply('v3_get_conversation_messages', [message('301', me), message('302', peer),
    { ...message('303', peer), deleted_by: '2' },
    message('304', peer, { ...sample, url: 'https://example.test/sample/board/' }),
    message('305', peer, { ...sample, pin_count: -1, section_count: '1', pin_thumbnail_urls: [], cover_images: {} }),
    message('306', peer, { ...sample, pin_count: 0, section_count: 0 }),
    message('307', peer, { ...sample, url: '/pin/123/' }),
    message('308', peer, { ...sample, url: '/sample/board/', pin_thumbnail_urls: ['javascript:bad', 'http://example.test/a', 'https://user:pass@example.test/a'] })], 'next');
  const rows = events.at(-1).messages;
  assert(rows[0].own && !rows[1].own); assert.equal(rows[0].board.url, target);
  assert.equal(rows[0].board.images.length, 3); assert.equal(rows[0].board.pinCount, 48); assert.equal(rows[0].board.sectionCount, 1);
  assert.equal(rows[0].board.cover, sample.cover_images['400x300'].url);
  assert(!rows[2].board && rows[2].deleted); assert.equal(rows[3].board.url, '');
  assert.equal(rows[4].board.pinCount, undefined); assert.equal(rows[4].board.sectionCount, undefined);
  assert.equal(rows[5].board.pinCount, 0); assert.equal(rows[5].board.sectionCount, 0);
  assert.equal(rows[6].board.url, ''); assert.equal(rows[7].board.images.length, 0);
  assert(api.action('more', '', 7));
  await reply('v3_get_conversation_messages', [message('301', me), message('300', peer)]);
  assert.equal(events.at(-1).messages.filter(m => m.id === '301').length, 1, 'pagination deduplicates board messages');
  assert(api.action('retry', '', 7)); const before = events.length;
  api.reset(); await reply('v3_get_conversation_messages', [message('399', peer)]);
  assert.equal(events.length, before, 'late messages cannot revive a closed conversation');
  navigationChecks();
  console.log('PASS inbox boards: sent/received mapping, collage/counts, missing fields, URL/deletion guards, pagination, late responses, opening and system back');
})().catch(error => { console.error(error); process.exitCode = 1; api.reset(); });
