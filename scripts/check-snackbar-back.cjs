const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
let source = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const releaseStart = source.indexOf('  private releasePostSnack(');
const start = releaseStart >= 0 ? releaseStart : source.indexOf('  private dismissPostSnack(): void');
const end = source.indexOf('  private async undoSavedPin()', start);
const shown = []; const events = []; const logs = [];
let now = 1000;
const deferredBack=[];
const drainBack=()=>{while(deferredBack.length)deferredBack.shift()();};
let reentrantDismiss;
let failDismiss = false;
class HdsSnackBar {
  show(icon, message, operation, style) {
    assert(!this.shown, 'each presentation owns a fresh HDS instance');
    this.shown = true;
    this.expiresAt = now + style.duration;
    shown.push({ operation, style, instance: this });
  }
  dismiss() {
    events.push('dismiss');
    assert(!this.closed, 'must not dismiss an already closed dialog');
    assert(now < this.expiresAt, 'must not dismiss an automatically expired dialog');
    this.closed = true;
    if (reentrantDismiss) reentrantDismiss();
    if (failDismiss) throw new Error('native close failed');
  }
}
const context = { $r:value=>value,SnackBarIconType:{NORMAL:0},HdsSnackBar, SnackBarOperationType: { TEXT_WITH_CLOSE: 3, CLOSE_BUTTON_ONLY: 1 },
  Date: { now: () => now },
  PinmonyRuntimeLog: { info: line => logs.push(line), warn: line => logs.push(line) } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native { ' + source.slice(start, end) +
  source.slice(source.indexOf('  private showInboxBlockSnack('),
    source.indexOf('\n  @Builder', source.indexOf('  private showInboxBlockSnack('))) +
  ' } globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
// Model native-owned closure before and after its notification callback.
// Application callbacks must never issue a second dismiss in either order.
function nativeCallback(presentation, callback, closeBefore = true) {
  const nativeClose = () => { presentation.instance.closed = true; events.push('native-close'); };
  if (closeBefore) nativeClose();
  callback();
  if (!closeBefore) nativeClose();
  drainBack();
}
function close(presentation) { nativeCallback(presentation, () => presentation.operation.onCloseButtonClick()); }
function back(presentation, closeBefore = true) { nativeCallback(presentation, () => presentation.style.pressBackCallback(), closeBefore); }
const native = require('./product-coordination-harness.cjs').createHost(context.Native, ts); let undo = 0, retry = 0;
Object.assign(native, {
    postSnackToken: 0, coordinatorTasks: {timeout:fn=>deferredBack.push(fn)}, getUIContext: () => ({}),
    onBackPress: () => { events.push('page-back'); return true; },
    currentPinUrl: () => 'pin', pinIdentity: value => value,
    activeSheetKind: 'share', showNativeSheet: true, refreshShareSheet: () => retry++,
    pinStore: Object.assign(native.pinStore, {
        shareError: '分享链接尚未就绪，请重试',
        shareSession: 1,
        sharePin: 'pin',
        shareFeedback: '已发送'
    })
});
native.showUndoSnack('已收藏', 'pin', () => undo++);
const first = shown.at(-1);
events.length = 0;
back(first);
assert.deepEqual(events, ['native-close', 'page-back']);
first.style.pressBackCallback();
first.operation.onContentClick();
assert.equal(undo, 0);
assert.equal(events.filter(event => event === 'page-back').length, 1);
native.showUndoSnack('已收藏', 'pin', () => undo++);
close(shown.at(-1));
assert.equal(undo, 0);
native.showUndoSnack('已收藏', 'pin', () => undo++);
shown.at(-1).operation.onContentClick();
assert.equal(undo, 1);
native.showShareLinkSnack();
assert.equal(shown.at(-1).style.duration, 4000);
back(shown.at(-1));
assert.equal(retry, 0);
native.showShareFeedbackSnack();
shown.at(-1).style.pressBackCallback();drainBack();
assert.equal(events.filter(event => event === 'page-back').length, 3);
// An older snackbar cannot dismiss a newer one or return its page.
native.showUndoSnack('first', 'pin', () => undo++);
const old = shown.at(-1);
native.showUndoSnack('second', 'pin', () => undo++);
const before = events.length;
old.style.pressBackCallback();
old.operation.onCloseButtonClick();
old.operation.onContentClick();
assert.equal(events.length, before);
assert.equal(undo, 1);
// Closing, switching roots, resetting auth and disposing can all clear the same owner.
native.dismissPostSnack();
const cleared = events.length;
for (let i = 0; i < 8; i++) native.dismissPostSnack();
assert.equal(events.length, cleared, 'repeated cleanup must not touch HDS');
assert.equal(native.postSnack, undefined);
assert.equal(native.postSnackExpiresAt, 0);

// A positive HDS timeout already closes its native dialog. Late callbacks cannot act.
native.showUndoSnack('expired', 'pin', () => undo++);
const expired = shown.at(-1);
now += expired.style.duration;
const expiredEvents = events.length, expiredUndo = undo;
expired.operation.onContentClick();
expired.operation.onCloseButtonClick();
expired.style.pressBackCallback();
native.dismissPostSnack();
assert.equal(events.length, expiredEvents);
assert.equal(undo, expiredUndo);
assert.equal(native.postSnack, undefined);
assert(logs.some(line => line.includes('reason=expired')));
native.showUndoSnack('fresh', 'pin', () => undo++);
assert.notEqual(shown.at(-1).instance, expired.instance);

// Release before native close, even if close reenters page cleanup or throws.
reentrantDismiss = () => native.dismissPostSnack();
const reentrantEvents = events.length;
native.dismissPostSnack();
assert.equal(events.length, reentrantEvents + 1);
reentrantDismiss = undefined;
native.showUndoSnack('callback before close', 'pin', () => undo++);
const callbackBefore = shown.at(-1);
const callbackEvents = events.length;
back(callbackBefore, false);
assert.deepEqual(events.slice(callbackEvents), ['native-close', 'page-back']);
native.showUndoSnack('close fails', 'pin', () => undo++);
failDismiss = true;
assert.doesNotThrow(() => native.dismissPostSnack());
failDismiss = false;
assert.equal(native.postSnack, undefined);
assert(logs.some(line => line.startsWith('PostSnack: dismiss-threw snackSeq=')));
assert(!logs.some(line => /PostSnack:.*token=/.test(line)));
const preparedSeqs = logs.filter(line => line.startsWith('PostSnack: prepared ')).map(line => /snackSeq=(\d+)/.exec(line)[1]);
assert.equal(new Set(preparedSeqs).size, preparedSeqs.length);
const failedEvents = events.length;
native.dismissPostSnack();
assert.equal(events.length, failedEvents);

// Preserve the inbox entry points that share the same cleanup owner.
let inboxUndo = 0;
native.inboxStore.inboxFlow = { newsId: 'news', newsHidden: true };
native.inboxFlowAction = action => { assert.equal(action, 'undoNews'); inboxUndo++; };
native.showInboxUndoSnack('news');
assert.equal(shown.at(-1).style.duration, 4000);
shown.at(-1).operation.onCloseButtonClick();
assert.equal(inboxUndo, 0);
native.showInboxUndoSnack('news');
shown.at(-1).operation.onContentClick();
shown.at(-1).operation.onContentClick();
assert.equal(inboxUndo, 1);
native.showInboxRestoredSnack();
assert.equal(shown.at(-1).style.duration, 4000);
shown.at(-1).operation.onCloseButtonClick();
native.showInboxBlockSnack(true, 'not-for-logs');
assert.equal(shown.at(-1).style.duration, 4000);
shown.at(-1).operation.onCloseButtonClick();
assert(!logs.join('\n').includes('not-for-logs'));

// Retry still dispatches once while the same share context is current.
// Retry still dispatches once while the same share context is current.
native.pinStore.shareSnackKey = '';
native.showShareLinkSnack();
const retrySnack = shown.at(-1);
retrySnack.operation.onContentClick();
retrySnack.operation.onContentClick();
assert.equal(retry, 1);
native.pinStore.shareSnackKey = '';
native.showShareLinkSnack();
native.pinStore.shareSession++;
const otherSessionEvents = events.length;
shown.at(-1).operation.onContentClick();
assert.equal(retry, 1);
assert.equal(events.length, otherSessionEvents);
native.dismissPostSnack();
console.log('Snackbar lifecycle: back/close/undo, six entry points, duplicate/reentrant cleanup, automatic expiry, stale callbacks and close failure passed');

native.showShareFeedbackSnack();const staleBack=shown.at(-1);staleBack.style.pressBackCallback();const beforeStale=events.filter(x=>x==='page-back').length;native.showUndoSnack('new owner','pin',()=>{});drainBack();assert.equal(events.filter(x=>x==='page-back').length,beforeStale,'replacement invalidates deferred return');
console.log('Deferred snackbar back: native closure precedes page return and new owner cancels stale return passed');
