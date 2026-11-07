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
const names = ['messageConfirmationKey', 'openMessageMenu', 'openBlockMenu', 'closeMessageMenu', 'messageMenuDisappeared', 'copyMessageText', 'snapshotChanged'];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + names.map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
function fixture() {
  return Object.assign(new Host(), {
    active: true, messageMenuClosing: false, showMessageMenu: false, messageMenuEpoch: 0,
    messageMenuContext: '', previousScreen: 'chat', lastBlockRevision: 0,
    snapshot: { pageUrl: 'synthetic', conversationId: '100', session: 1, screen: 'chat', messages: [] },
    prepareChatPosition() {}, positionChat() {}
  });
}
const message = {id: '300', text: 'synthetic', own: true, deleted: false};
async function main() {
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
  const sheetStart = source.indexOf('.bindSheet($$this.showMessageMenu');
  const sheet = source.slice(sheetStart, source.indexOf('if (this.snapshot.loading && this.snapshot.screen', sheetStart));
  assert(sheet.includes('onDisappear: (): void => this.messageMenuDisappeared()'));
  assert(sheet.includes('this.closeMessageMenu(); action.dismiss();'));
  assert(!sheet.includes('selectedMessage = undefined')); assert(!sheet.includes('blockTarget = undefined'));
  assert(source.includes("if (this.messageMenuKind === 'block') this.blockSheetContent();"));
  const menu = source.slice(source.indexOf('  private messageMenuContent()'), source.indexOf('  private blockSheetContent()'));
  assert(menu.includes('sys.symbol.trash'));
  assert.equal((menu.match(/height\(48\)\.padding\(\{ left: 8, right: 8 \}\)/g) || []).length, 2, 'copy and delete share row height and padding');
  assert(menu.includes('epoch === this.messageMenuEpoch && this.messageConfirmationKey() === intent'));
  assert(menu.includes('.enabled(this.active && !this.messageMenuClosing)'));
  console.log('Message Sheet: copy/delete row parity, deferred cleanup, close paths, block retention, reopen guard, clipboard failure/late result and session changes passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
