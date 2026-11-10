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
  assert(ui.includes('stackBuilderComponent: this.conversationTitleContent'), 'HDS uses retained title content');
  assert(!ui.includes('stackBuilder: this.conversationTitleBuilder'), 'scroll builder no longer owns avatar nodes');
  const vm = require('node:vm');
  const titleMethods = ui.slice(ui.indexOf('  private conversationTitleContent:'), ui.indexOf('  aboutToAppear(): void'));
  let creates = 0, updates = 0;
  const context = {
    ComponentContent: class { constructor(_ctx, _builder, options) { creates++; this.options = options; }
      update(options) { updates++; this.options = options; } },
    wrapBuilder: builder => builder, buildPinmonyChatTitle() {},
    PinmonyI18n: { render: value => value }
  };
  const Page = vm.runInNewContext(ts.transpileModule('class Page { visible=true; active=true; snapshot={screen:"chat",conversationId:"1",title:"Chat",users:[{id:"2",profileUrl:"peer",avatar:"avatar.jpg",name:"Peer"}]}; getUIContext(){return {};} uiText(){return "Chat";} captureChatOffset(){} ' + titleMethods + '} Page;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
  const page = new Page(); page.updateConversationTitle();
  const retained = page.conversationTitleContent;
  for (let i=0;i<100;i++) page.updateConversationTitle();
  assert.equal(creates,1,'scroll reevaluation cannot recreate title component');
  assert.equal(updates,0,'identical peer/title cannot trigger avatar property updates');
  page.snapshot.title='Renamed'; page.updateConversationTitle();
  assert.equal(page.conversationTitleContent,retained); assert.equal(updates,1);
  page.snapshot.users[0].avatar='new.jpg'; page.updateConversationTitle();
  assert.equal(page.conversationTitleContent,retained); assert.equal(updates,2);
  assert.equal(retained.options.avatar,'new.jpg');
  page.snapshot.screen='settings';page.updateConversationTitle();assert.equal(retained.options.visible,false);
  page.snapshot.screen='chat';page.updateConversationTitle();assert.equal(retained.options.visible,true);
  let opened='';page.onUser=url=>opened=url;page.openTitleUser.call({});assert.equal(opened,'peer');
  page.active=false;opened='';page.openTitleUser();assert.equal(opened,'','covered chat cannot navigate');
  assert(ui.includes("@Watch('updateConversationTitle')"),'live language refreshes retained title');
  assert(ui.includes('this.conversationTitleContent?.dispose()'),'page disappearance disposes retained title');
  assert(!ui.includes('this.flowPathStack.clear(false)'), 'removal must not expose an empty navigation destination in the final frame');
  const title = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyChatTitle.ets','utf8');
  assert(!title.includes('ForEach('), 'title avatar is not a dynamic list');
  assert(title.includes('left: 80, right: 72'),'keep confirmed title spacing');
  const scroll = ui.slice(ui.indexOf('.onDidScroll('), ui.indexOf("if (this.snapshot.screen === 'chat') {", ui.indexOf('.onDidScroll(')));
  assert(!scroll.includes('this.onOffset('), 'scroll frames do not rebuild parent title configuration');
  assert(ui.includes('scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR'));
  assert(ui.includes('systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)'));
  console.log('PASS chat dismissal/title: retained and rebound back, late callback suppression, explicit reopen, retained avatar content, unchanged-input deduplication, live peer updates and no parent writes per scroll frame');
})().catch(error => { console.error(error); process.exitCode = 1; });
