const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', 'utf8');
const start = source.indexOf('  private snapshotChanged('), end = source.indexOf('\n  private ', start + 1);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
function fixture(snapshot) {
  const h = new Host(), calls = [];
  Object.assign(h, { snapshot, prepareChatPosition() {}, positionChat() {}, previousScreen: 'updatesMenu',
    showUpdatesMenu: true, presentedNewsId: '501', lastHiddenNewsId: '', lastRestoredNewsId: '',
    lastBlockRevision: 0, historyPending: false, onNewsHidden: () => calls.push('hidden'),
    onNewsRestored: () => calls.push('restored') });
  return {h, calls};
}
const hidden = fixture({screen:'updatesMenu',newsId:'501',newsHidden:true});
hidden.h.snapshotChanged(); assert.equal(hidden.h.showUpdatesMenu, false);
assert.deepEqual(hidden.calls, [], 'feedback waits for Sheet dismissal');
const unsubscribed = fixture({screen:'updatesMenu',newsId:'501',unsubscribedPin:true});
unsubscribed.h.snapshotChanged(); assert.equal(unsubscribed.h.showUpdatesMenu, false);
const undo = fixture({screen:'updatesMenu',newsId:'501',newsUndoing:true,newsHidden:false});
undo.h.presentedNewsId = ''; undo.h.lastHiddenNewsId = '501'; undo.h.showUpdatesMenu = false;
undo.h.snapshotChanged(); assert.equal(undo.h.showUpdatesMenu, false); assert.deepEqual(undo.calls, []);
console.log('Inbox menu: confirmed hide/unsubscribe close Sheet before feedback; undo never reopens Sheet');
