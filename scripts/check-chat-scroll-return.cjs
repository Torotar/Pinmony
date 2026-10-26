const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts);
const { PinmonyChatScrollPosition } = loader.loadFile('feature_inbox/src/main/ets/services/PinmonyChatScrollPosition.ets');
const p = new PinmonyChatScrollPosition();
p.begin('100', 850);
assert.equal(p.record(0, false), false, 'mount-time zero cannot overwrite the return offset');
assert.equal(p.layout(0, 500), undefined); assert.equal(p.layout(2000, 0), undefined);
assert.equal(p.layout(700, 500), 200, 'temporary short layout may clamp');
assert.equal(p.record(200, false), false, 'clamping cannot replace the original target');
p.begin('100', -1); assert.equal(p.layout(2200, 500), 850, 'clearing retained snapshot cannot switch to bottom');
assert.equal(p.layout(2600, 500), 850, 'late image layout restores the same target');
assert.equal(p.canLoadHistory(), false, 'initial positioning never fetches older messages');
assert.equal(p.record(800, true), true); assert.equal(p.layout(2800, 500), undefined, 'user scroll wins over restoration');
assert.equal(p.canLoadHistory(), true);
p.restore(850); assert.equal(p.record(0, false), false);
assert.equal(p.layout(2800, 500), 850, 'an existing chat beneath Pin resumes its saved target');
p.latest(); assert.equal(p.layout(2800, 500), 2300, 'newly confirmed sends go to latest');
p.begin('101', -1); assert.equal(p.layout(1500, 500), 1000, 'different conversation starts at latest');

const ui = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', 'utf8');
const methods = ['prepareChatPosition', 'snapshotChanged'].map(name => {
  const start = ui.indexOf('  private ' + name + '('); assert(start >= 0);
  return ui.slice(start, ui.indexOf('\n  private ', start + 1));
});
const context = {};
vm.runInNewContext(ts.transpileModule('class Page {' + methods.join('\n') + '} globalThis.Page = Page;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const page = new context.Page(), scroll = new PinmonyChatScrollPosition();
Object.assign(page, { snapshot: { screen: 'chat', conversationId: '100', sentRevision: 2, messages: [], users: [] },
  presentedConversation: '', sentRevision: 0, restoreOffset: 850, chatPosition: scroll, draft: 'retained draft' });
page.prepareChatPosition(); page.snapshotChanged();
assert.equal(scroll.layout(2200, 500), 850, 'cached send revision cannot replay scroll-to-bottom');
page.snapshot.sentRevision = 0; page.snapshotChanged();
page.snapshot.sentRevision = 1; page.snapshotChanged();
assert.equal(scroll.layout(2200, 500), 1700); assert.equal(page.draft, '');
assert(ui.includes('.height(this.messageImageWidth(message) / this.messageImageRatio(message))'), 'Pin size exists before decode');
assert(!ui.includes('}, 30)'), 'no timed initial scroll guesses');
assert(ui.includes('this.visible && this.active && this.snapshot.screen'), 'covered chat cannot save hidden offsets');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(index.includes('restoreOffset: this.inboxStore.chatReturnConversation ==='), 'return intent survives fresh read clearing the retained snapshot');

const { Store, PinmonyInboxReadController } = require('./inbox-read-controller-harness.cjs').create(ts);
const inbox = 'https://www.pinterest.com/inbox/', store = new Store(), scripts = [];
store.inboxSession = 7;
const controller = new PinmonyInboxReadController(store, {
  authenticated: () => true, foreground: () => true, document: () => inbox, addressKey: v => v,
  inboxAddress: v => v === inbox ? inbox : '', currentInbox: () => inbox, activeTab: () => 2,
  rootOnly: () => false, interacted: () => true, backTarget: () => '',
  runScript: v => { scripts.push(v); return Promise.resolve('true'); }
});
const old = { id: '299', text: 'Older', image: '', pinUrl: '', own: false, createdAt: '2026-10-13T00:00:00Z' };
const current = { id: '300', text: 'Current', image: '', pinUrl: '', own: true, createdAt: '2026-10-13T01:00:00Z' };
const flow = messages => ({ kind: 'nativeFlow', pageUrl: inbox, session: 7, screen: 'chat', conversationId: '100',
  users: [], messages, selectedIds: [], loading: false, error: '', hasMore: true });
store.retainedChat = flow([old, current]); store.chatScrollOffset = 850; store.chatReturnConversation = '100';
controller.update(JSON.stringify(flow([current])));
assert.deepEqual(store.inboxFlow.messages.map(m => m.id), ['299', '300']);
assert.equal(store.chatScrollOffset, 850); assert.equal(store.retainedChat, undefined);
assert.equal(store.chatReturnConversation, '100');
assert(scripts.at(-1).includes('retainHistory(7,"100"'), 'read cache restored in current script without writing');
store.retainedChat = flow([old, current]);
controller.update(JSON.stringify({ ...flow([]), error: 'Read failed' }));
assert.equal(store.inboxFlow.messages.length, 2); assert(store.retainedChat, 'failure cannot erase history or return intent');
controller.update(JSON.stringify({ ...flow([]), hasMore: false }));
assert.equal(store.inboxFlow.messages.length, 0, 'confirmed empty remains authoritative');
controller.update(JSON.stringify({ ...flow([]), screen: 'closed' }));
assert.equal(store.chatReturnConversation, '', 'explicit chat close clears return intent');

const bridgeSource = fs.readFileSync('feature_inbox/src/main/ets/services/PinmonyInboxConversationScript.ets', 'utf8');
const bridge = vm.runInNewContext(bridgeSource.slice(bridgeSource.indexOf('`'), bridgeSource.lastIndexOf('`') + 1));
const window = { PinmonyInboxConversationsEnabled: true }, events = [], requests = [];
window.top = window; window.PinmonyShareBridge = { inboxState: v => events.push(JSON.parse(v)) };
vm.runInNewContext(bridge, { window, location: { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/inbox/' },
  document: { cookie: '' }, URL, URLSearchParams, AbortController, setTimeout, clearTimeout,
  fetch: (url, args) => new Promise(resolve => requests.push({ url, args, resolve })) });
const api = window.PinmonyInboxConversations, me = { id: '1', full_name: 'Self' }, peer = { id: '2', full_name: 'Peer' };
const flush = () => new Promise(resolve => setImmediate(resolve));
async function reply(endpoint, data, bookmark = '-end-') {
  requests.at(-1).resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data, bookmark }, client_context: { user: me } }) });
  await flush();
}
(async () => {
  api.read(inbox, () => {}, () => true); await reply('v3_get_conversations', [{ id: '100', users: [me, peer] }]);
  api.open('conversation:100', 7); await reply('v3_get_conversation', { id: '100', users: [me, peer] });
  await reply('v3_get_conversation_messages', [{ id: '300', text: 'Current', sender: me, created_at: current.createdAt,
    pin: { id: '200', images: { '236x': { url: 'https://i.pinimg.com/sample.jpg', width: 236, height: 472 } } } }], 'next');
  assert.equal(events.at(-1).messages[0].imageHeight, 472);
  const count = requests.length;
  assert.equal(api.retainHistory(6, '100', [old]), false); assert.equal(api.retainHistory(7, '101', [old]), false);
  assert.equal(api.retainHistory(7, '100', [old, old, current]), true);
  assert.equal(requests.length, count, 'restoring history issues no request');
  api.action('settings', '', 7); api.action('back', '', 7);
  assert.deepEqual(events.at(-1).messages.map(m => m.id), ['299', '300']);
  api.action('retry', '', 7);
  await reply('v3_get_conversation', { id: '100', users: [me, peer] });
  await reply('v3_get_conversation_messages', [{ id: '300', text: 'Current edited', sender: me, created_at: current.createdAt }], 'next');
  assert.deepEqual(events.at(-1).messages.map(m => m.id), ['299', '300'], 'later message reads preserve restored older history');
  assert.equal(events.at(-1).messages[1].text, 'Current edited', 'fresh server content wins');
  const closedEvents = events.length;
  assert.equal(api.close(6, '100'), false); assert.equal(api.close(7, '100'), true);
  assert.equal(events.length, closedEvents, 'native close does not publish an old compose page');
  assert.equal(api.action('back', '', 7), false);
  api.reset(); assert.equal(api.retainHistory(7, '100', [old]), false, 'departed flow cannot be restored');
  console.log('PASS chat scroll return: layout races, clamping, user control, send revisions, Pin geometry, retained history, empty/error and script session guards');
})().catch(error => { console.error(error); process.exitCode = 1; api.reset(); });

// The native chat must be the explicit history target even with a stale home entry.
{
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 const match=index.match(/const origin: string = this.extractPinUrl\(parent\)[\s\S]*?;/);assert(match);
 const body=match[0].replace('const origin: string','const origin')+' return origin;';
 const target=new Function('parent',body).call({extractPinUrl:()=>'',searchUrlFromAddress:()=>'',inboxUrlFromAddress:v=>v.includes('/inbox/')?v:'',profileUrlFromAddress:()=>'',boardUrlFromAddress:()=>'',isHomeRootAddress:()=>false},'https://www.pinterest.com/inbox/');
 assert.equal(target,'https://www.pinterest.com/inbox/','chat return overrides stale home history');
 const a=index.indexOf('  private completeNativeBack('),b=index.indexOf('\n  private ',a+1);
 const Host=vm.runInNewContext(ts.transpileModule('class Host {'+index.slice(a,b)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_DETAIL_READS_ENABLED:true,PIN_NATIVE_BOARD_READS_ENABLED:true,PIN_NATIVE_PROFILE_READS_ENABLED:true,PIN_NATIVE_SEARCH_READS_ENABLED:true});
 const h=new Host(),chat={screen:'chat',conversationId:'100'},calls=[];
 Object.assign(h,{nativeBusinessSessionContext:()=>({authenticated:true,origin:'https://www.pinterest.com'}),profileSettingsVisible:false,returnToNativeProfile:()=>false,searchUrlFromAddress:()=>'',extractPinUrl:()=>'',boardUrlFromAddress:()=>'',rootTabIndexFromAddress:()=>2,returnCoordinator:{cancel(){}},pageHistory:{cancelBack(){},visit(){}},pageBackToken:0,inboxStore:{retainedChat:chat},presentNativeBackTarget(){},tabsController:{changeIndex:i=>calls.push(i)},rootTabAddresses:new Map(),boardStore:{},clearRootTabGuard:r=>calls.push(r),inboxMessagesNativeReads:{demand:()=>calls.push('demand')},syncFloatingTabsMotion(){}});
 assert(h.completeNativeBack(target));assert.equal(h.activeTab,2);assert.equal(h.inboxStore.inboxFlow,chat);assert.equal(h.inboxStore.retainedChat,undefined);assert.equal(h.nativeRootOnly,false);assert(calls.includes('chat-return'));assert(calls.includes('demand'));
 console.log('Chat Pin return: explicit inbox history target, active tab and native flow restoration passed');
}
