const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { PinmonyInboxActionsController } = createArktsLoader(ts).loadFile('feature_inbox/src/main/ets/controllers/PinmonyInboxActionsController.ets');
const { Store, PinmonyInboxReadController } = require('./inbox-read-controller-harness.cjs').create(ts);
const inbox = 'https://www.pinterest.com/inbox/';
(async () => {
  for (const rebound of [false, true]) {
    const store = new Store(), scripts = []; store.inboxSession = 7;
    const flow = { kind: 'nativeFlow', pageUrl: inbox, session: rebound ? 7 : 3, screen: 'chat', conversationId: '100',
      messages: [], users: [], selectedIds: [], loading: true, error: 'Read failed' };
    store.inboxFlow = flow; store.retainedChat = flow; store.chatReturnConversation = '100';
    const ports = { allowed: () => true, epoch: () => 1, document: () => inbox, currentInbox: () => inbox,
      enabled: () => true, prepare: async () => true, feedback() {}, runScript: async s => { scripts.push(s); return 'true'; } };
    const actions = new PinmonyInboxActionsController(store, ports);
    await actions.action('back');
    assert.equal(store.inboxFlow, undefined); assert.equal(store.retainedChat, undefined);
    assert.equal(store.chatReturnConversation, ''); assert.equal(store.flowDismissed, true);
    assert.equal(scripts.length, rebound ? 1 : 0, 'cached return never needs Web session synchronization');
    if (rebound) assert(scripts[0].includes('.close(7,"100")'), 'cleanup cannot publish compose/chat over the native root');
    const read = new PinmonyInboxReadController(store, { authenticated: () => true, foreground: () => true,
      document: () => inbox, currentInbox: () => inbox, rootOnly: () => false, interacted: () => true,
      backTarget: () => '', inboxAddress: () => inbox });
    read.update(JSON.stringify({ ...flow, session: 7, loading: false, error: '' }));
    assert.equal(store.inboxFlow, undefined, 'late restore callback cannot reopen dismissed chat');
    store.inboxActionsReady = true; store.inboxUrl = inbox; store.inbox = { items: [] };
    await actions.open('conversation:100'); assert.equal(store.flowDismissed, false, 'explicit new entry re-enables flow delivery');
  }
  const ui = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', 'utf8');
  assert(ui.includes('stackBuilder: this.conversationTitleBuilder'), 'title builder has stable identity during scrolling');
  const declaration = ui.split('\n').find(line => line.includes('private readonly conversationTitleBuilder:'));
  assert(declaration);
  const callback = declaration.slice(declaration.indexOf(' = ') + 3).trim().replace(/;$/, '');
  const vm = require('node:vm'), context = {};
  vm.runInNewContext(ts.transpileModule('class Page { snapshot = {screen:"chat"}; calls=0; conversationTitle(){this.calls++; if(this.snapshot.screen!=="chat")throw Error("wrong receiver");} conversationTitleBuilder=' + callback + '; } globalThis.Page=Page;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
  const page = new context.Page(), builder = page.conversationTitleBuilder;
  builder.call({snapshot:undefined}); builder(); assert.equal(page.calls,2,'HDS receiver and standalone callback must both retain the page context');
  assert.equal(builder,page.conversationTitleBuilder,'scroll changes cannot replace callback identity');
  assert(!ui.includes('this.flowPathStack.clear(false)'), 'removal must not expose an empty navigation destination in the final frame');
  const title = ui.slice(ui.indexOf('private conversationTitle()'), ui.indexOf('private avatar('));
  assert(!title.includes('ForEach('), 'single title avatar is not reconciled as a dynamic keyed list');
  const scroll = ui.slice(ui.indexOf('.onDidScroll('), ui.indexOf("if (this.snapshot.screen === 'chat') {", ui.indexOf('.onDidScroll(')));
  assert(!scroll.includes('this.onOffset('), 'scroll frames do not rebuild parent title configuration');
  assert(ui.includes('scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR'));
  assert(ui.includes('systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)'));
  console.log('PASS chat dismissal/title: retained and rebound back, late callback suppression, explicit reopen, stable avatar builder and no parent writes per scroll frame');
})().catch(error => { console.error(error); process.exitCode = 1; });
