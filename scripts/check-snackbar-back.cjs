const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  private dismissPostSnack(): void');
const end = source.indexOf('  private async undoSavedPin()', start);
const shown = []; const events = [];
class HdsSnackBar {
  show(icon, message, operation, style) { shown.push({ operation, style }); }
  dismiss() { events.push('dismiss'); }
}
const context = { HdsSnackBar, SnackBarOperationType: { TEXT_WITH_CLOSE: 3, CLOSE_BUTTON_ONLY: 1 },
  PinWebRuntimeLog: { info() {} } };
vm.runInNewContext(ts.transpileModule('class Native { ' + source.slice(start, end) +
  ' } globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
const native = new context.Native(); let undo = 0, retry = 0;
Object.assign(native, { postSnackToken: 0, getUIContext: () => ({}),
  onBackPress: () => { events.push('page-back'); return true; },
  currentPinUrl: () => 'pin', pinIdentity: value => value,
  shareError: '分享链接尚未就绪，请重试', shareSession: 1, sharePin: 'pin', shareFeedback: '已发送',
  activeSheetKind: 'share', showNativeSheet: true, refreshShareSheet: () => retry++ });
native.showUndoSnack('已收藏', 'pin', () => undo++);
const first = shown.at(-1);
events.length = 0;
first.style.pressBackCallback();
assert.deepEqual(events, ['dismiss', 'page-back']);
first.style.pressBackCallback();
first.operation.onContentClick();
assert.equal(undo, 0);
assert.equal(events.filter(event => event === 'page-back').length, 1);
native.showUndoSnack('已收藏', 'pin', () => undo++);
shown.at(-1).operation.onCloseButtonClick();
assert.equal(undo, 0);
native.showUndoSnack('已收藏', 'pin', () => undo++);
shown.at(-1).operation.onContentClick();
assert.equal(undo, 1);
native.showShareLinkSnack();
assert.equal(shown.at(-1).style.duration, 4000);
shown.at(-1).style.pressBackCallback();
assert.equal(retry, 0);
native.showShareFeedbackSnack();
shown.at(-1).style.pressBackCallback();
assert.equal(events.filter(event => event === 'page-back').length, 3);
// An older snackbar cannot dismiss a newer one or return its page.
native.showUndoSnack('first', 'pin', () => undo++);
const old = shown.at(-1);
native.showUndoSnack('second', 'pin', () => undo++);
const before = events.length;
old.style.pressBackCallback();
assert.equal(events.length, before);
console.log('Snackbar back: dismiss before page return, duplicate/stale guards, close versus undo and share callbacks passed');
