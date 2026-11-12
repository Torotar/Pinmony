const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(') >= 0 ? source.indexOf('  private ' + name + '(') : source.indexOf('  private async ' + name + '(');
  assert(start >= 0, name);
  const next = source.slice(start).search(/\n  (?:private |@Builder|aboutTo)/);
  assert(next > 0, name);
  return source.slice(start, start + next);
}
const names = ['messageConfirmationKey', 'canReactToMessage', 'chooseReaction', 'toggleReaction', 'activeChanged', 'openMessageMenu', 'openBlockMenu', 'closeMessageMenu', 'messageMenuDisappeared', 'copyMessageText', 'updateConversationTitle', 'snapshotChanged', 'openSharedProfile'];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + names.map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
function fixture() {
  return Object.assign(new Host(), {
    active: true, messageMenuClosing: false, showMessageMenu: false, messageMenuEpoch: 0,
    messageMenuContext: '', reactionMessageId: '', reactionContext: '', previousScreen: 'chat', lastBlockRevision: 0,
    snapshot: { pageUrl: 'synthetic', conversationId: '100', session: 1, screen: 'chat', messages: [] },
    prepareChatPosition() {}, positionChat() {}
  });
}
const message = {id: '300', text: 'synthetic', own: true, deleted: false};
async function main() {
  const kinds = [{text:'hello'}, {text:'❤️'}, {image:'photo'}, {image:'pin',pinUrl:'/pin/1/'},
    {pinUrl:'/pin/1/'}, {board:{id:'20'}}, {profile:{id:'2'}}];
  for (const own of [true, false]) for (const kind of kinds) {
    const h = fixture(), item = {...message, ...kind, own}, actions = [];
    h.snapshot.messages = [item]; h.act = (...args) => actions.push(args);
    assert(h.canReactToMessage(item.id), JSON.stringify({kind,own}));
    h.toggleReaction(item); assert.equal(h.reactionMessageId,item.id);
    h.chooseReaction(item.id,'👍',h.reactionContext);
    assert.deepEqual(actions,[['react','300|👍']]); assert.equal(h.reactionMessageId,'');
    h.openMessageMenu(item); h.chooseReaction(item.id,'❤️',h.messageMenuContext);
    assert.deepEqual(actions.at(-1),['react','300|❤️']);
    item.deleted = true; assert(!h.canReactToMessage(item.id));
    h.chooseReaction(item.id,'😂',h.messageMenuContext); assert.equal(actions.length,2);
  }
  for (const state of [{active:false},{screen:'settings'},{loading:true},{messageBusy:true},{sending:true},
      {writeUncertain:true},{error:'failed'},{sendError:'failed'}]) {
    const h=fixture(); h.snapshot.messages=[message]; h.act=()=>assert.fail('blocked reaction');
    if ('active' in state) h.active=state.active; else Object.assign(h.snapshot,state);
    assert(!h.canReactToMessage(message.id)); h.chooseReaction(message.id,'👍',h.messageConfirmationKey());
  }
  for (const change of ['session','conversationId','pageUrl','deleted','removed']) {
    const h=fixture(); h.snapshot.messages=[{...message}]; h.act=()=>assert.fail('stale reaction');
    h.toggleReaction(message); const context=h.reactionContext;
    if (change==='deleted') h.snapshot.messages[0].deleted=true;
    else if (change==='removed') h.snapshot.messages=[];
    else h.snapshot[change]+='new';
    h.snapshotChanged(); assert.equal(h.reactionMessageId,'');
    h.chooseReaction(message.id,'👍',context);
  }
  const hidden=fixture(); hidden.snapshot.messages=[message]; hidden.toggleReaction(message);
  hidden.active=false; hidden.activeChanged(); assert.equal(hidden.reactionMessageId,'');
  for (const reason of ['close button', 'outside tap', 'back', 'drag', 'reaction', 'delete confirmation']) {
    const h = fixture(); h.openMessageMenu(message); h.closeMessageMenu();
    assert.equal(h.showMessageMenu, false, reason);
    assert.equal(h.selectedMessage, message, reason + ': preserve FIT_CONTENT model until exit finishes');
    assert.equal(h.messageMenuClosing, true);
    h.openMessageMenu({...message, id: '301'});
    assert.equal(h.selectedMessage.id, '300', 'cannot reopen or change row during exit');
    h.messageMenuDisappeared();
    assert.equal(h.selectedMessage, undefined); assert.equal(h.messageMenuClosing, false);
    h.openMessageMenu({...message, id: '301'}); assert.equal(h.selectedMessage.id, '301');
  }
  const block = fixture(), user = {id: '2', name: 'Peer'};
  block.openBlockMenu(user); block.closeMessageMenu(); assert.equal(block.blockTarget, user);
  block.messageMenuDisappeared(); assert.equal(block.blockTarget, undefined);
  for (const failure of [true, false]) {
    const h = fixture(); h.openMessageMenu(message); h.onCopyText = async () => !failure;
    await h.copyMessageText(); assert.equal(h.showMessageMenu, failure);
    assert.equal(h.selectedMessage, message, 'successful copy must not collapse the content before exit');
  }
  const late = fixture(); let finish;
  late.openMessageMenu(message); late.onCopyText = () => new Promise(resolve => { finish = resolve; });
  const pending = late.copyMessageText(); late.closeMessageMenu(); late.messageMenuDisappeared();
  late.openMessageMenu({...message, id: '301'}); finish(true); await pending;
  assert.equal(late.showMessageMenu, true, 'late clipboard result cannot close a new menu');
  assert.equal(late.selectedMessage.id, '301');
  const changed = fixture(); changed.openMessageMenu(message);
  changed.snapshot = {...changed.snapshot, session: 2}; changed.snapshotChanged();
  assert.equal(changed.showMessageMenu, false); assert.equal(changed.selectedMessage, message);
  changed.messageMenuDisappeared(); assert.equal(changed.selectedMessage, undefined);
  const profile = {...message, profile: {profileUrl: '/synthetic/'}}, taps = [];
  const card = fixture(); card.snapshot.messages = [profile];
  card.captureChatOffset = () => taps.push('scroll'); card.onUser = url => taps.push(url);
  card.openSharedProfile(profile.id); assert.deepEqual(taps, ['scroll', '/synthetic/'], 'short tap still opens the shared profile');
  taps.length = 0; card.openMessageMenu(profile); card.openSharedProfile(profile.id);
  assert.deepEqual(taps, [], 'long-press menu suppresses late profile click');
  card.closeMessageMenu(); card.openSharedProfile(profile.id);
  assert.deepEqual(taps, [], 'menu dismissal suppresses late profile click');
  card.messageMenuDisappeared(); card.openSharedProfile(profile.id);
  assert.deepEqual(taps, ['scroll', '/synthetic/'], 'profile tap restored after dismissal');
  const image = source.slice(source.indexOf('Image(message.image)'), source.indexOf('if (message.deleted)', source.indexOf('Image(message.image)')));
  assert(image.includes('.draggable(false)'), 'Pin image cannot start system photo drag');
  assert(image.includes('if (!this.active || this.showMessageMenu || this.messageMenuClosing) return;'), 'late Pin click cannot navigate over its menu');
  assert(source.includes('Image(url).draggable(false)'), 'shared profile preview images cannot start system drag');
  assert(source.includes('.priorityGesture(LongPressGesture({ repeat: false }).onAction(() => this.openMessageMenu(message)))'), 'message long press takes priority over card/child taps');
  assert(!source.includes('.parallelGesture(LongPressGesture()'), 'long press is not dispatched in parallel with card taps');
  const sideActions = method('messageSideActions');
  assert.match(sideActions, /Button\(\{ type: ButtonType.Circle, stateEffect: false \}\) \{\s*if \(message\.reactions\?\.length\) \{\s*Text\(message\.reactions\.join\(' '\)\)[\s\S]*?\} else \{\s*Row\(\) \{\s*SymbolGlyph\(\$r\('sys.symbol.face_smiling'\)\)/, 'confirmed reactions replace the empty smile-plus entry content');
  assert.equal((sideActions.match(/Text\(message\.reactions\.join/g) || []).length, 1, 'reactions render once inside the entry, not below it');
  assert(method('toggleReaction').includes("this.reactionMessageId === message.id ? '' : message.id"), 'reaction entry remains clickable after feedback');
  assert(!sideActions.includes('!message.board') && !sideActions.includes('!message.profile'), 'all card types expose reaction entry');
  assert(source.includes('if (message.own && !message.deleted) { this.messageSideActions(message) }'));
  assert(source.includes('if (!message.own && !message.deleted) { this.messageSideActions(message) }'));
  assert(sideActions.includes('.bindPopup(this.reactionMessageId === message.id'), 'confirmed reactions retain the existing picker');
  const sheetStart = source.indexOf('.bindSheet($$this.showMessageMenu');
  const sheet = source.slice(sheetStart, source.indexOf('if (this.snapshot.loading && this.snapshot.screen', sheetStart));
  assert(sheet.includes('onDisappear: (): void => this.messageMenuDisappeared()'));
  assert(sheet.includes('this.closeMessageMenu(); action.dismiss();'));
  assert(!sheet.includes('selectedMessage = undefined')); assert(!sheet.includes('blockTarget = undefined'));
  assert(source.includes("if (this.messageMenuKind === 'block') this.blockSheetContent();"));
  const menu = source.slice(source.indexOf('  private messageMenuContent()'), source.indexOf('  private blockSheetContent()'));
  assert(!menu.includes('!this.selectedMessage?.board') && !menu.includes('!this.selectedMessage?.profile'), 'long-press picker supports all card types');
  assert(menu.includes('sys.symbol.trash'));
  assert.equal((menu.match(/height\(48\)\.padding\(\{ left: 8, right: 8 \}\)/g) || []).length, 4, 'copy, save, share and delete share row height and padding');
  const actionRows = menu.match(/Button\(\{ type: ButtonType.Normal, stateEffect: false \}\) \{[\s\S]*?\.accessibilityText\(this\.uiText\("[^"]+"\)\)/g) || [];
  assert.equal(actionRows.length, 4, 'all four action rows disable press feedback');
  for (const key of ['pm_copy_63d90d97', 'pm_save_60a53514', 'pm_share_7e564575', 'pm_delete_2f9daa82']) {
    const row = actionRows.find(item => item.includes(key));
    assert(row, key + ': action row exists');
    assert(row.includes('Row({ space: 10 })'), key + ': icon and label spacing matches delete');
    assert(row.includes(".width('100%').justifyContent(FlexAlign.Start)"), key + ': left aligned');
    assert(row.includes('.fontSize(18).fontWeight(FontWeight.Medium)'), key + ': label style matches delete');
  }
  for (const action of ['save', 'share']) {
    assert(menu.includes("this.onPinAction('" + action + "', this.selectedMessage.pinUrl); this.closeMessageMenu();"), action + ': original action and dismissal preserved');
  }
  assert(menu.includes('epoch === this.messageMenuEpoch && this.messageConfirmationKey() === intent'));
  assert(menu.includes('.enabled(this.active && !this.messageMenuClosing)'));
  console.log('Message Sheet: copy/save/share/delete row parity and no press feedback, deferred cleanup, close paths, block retention, reopen guard, clipboard failure/late result and session changes passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
