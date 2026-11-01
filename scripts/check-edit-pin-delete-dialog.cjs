const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyEditPinSheet.ets', 'utf8')
  .replace('export struct PinmonyEditPinSheet', 'export class PinmonyEditPinSheet');
const tree = ts.createSourceFile('sheet.ts', source, ts.ScriptTarget.Latest, true);
const sheet = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'PinmonyEditPinSheet');
const methods = ['confirmDelete', 'cancelDelete', 'aboutToDisappear'].map(name =>
  sheet.members.find(n => ts.isMethodDeclaration(n) && n.name?.getText(tree) === name).getText(tree));
const scope = { exports: {} };
vm.runInNewContext(ts.transpileModule(`export class Sheet {${methods.join('\n')}}`, {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, scope);
function fixture() {
  const view = new scope.exports.Sheet(), calls = [];
  let dialog;
  Object.assign(view, { sheetVisible: true, deleteDialogOpen: false, deleteDialogEpoch: 0,
    result: { pin: 'pin-1', phase: 'edit', editableContent: true, loading: false, busy: false, error: '', uncertain: false, picker: { busy: false } },
    uiText: key => key, getUIContext: () => ({ showAlertDialog: options => { dialog = options; } }),
    act(method, args) { calls.push([method, args]); if (method === 'editPhase') this.result.phase = JSON.parse(args.slice(1)); }
  });
  return { view, calls, dialog: () => dialog };
}
const cancel = fixture(); cancel.view.confirmDelete();
assert.equal(cancel.dialog().title,'pm_delete_this_pin_bd01697d');
assert.equal(cancel.dialog().secondaryButton.value,'pm_delete_2f9daa82');
assert.deepEqual(cancel.calls, [['editPhase', ',"confirm"']]);
cancel.dialog().primaryButton.action();
assert.equal(cancel.view.result.phase, 'edit');
cancel.dialog().secondaryButton.action();
assert.equal(cancel.calls.filter(c => c[0] === 'editCommit').length, 0);
const confirmed = fixture(); confirmed.view.confirmDelete(); confirmed.dialog().secondaryButton.action(); confirmed.dialog().secondaryButton.action();
assert.equal(confirmed.calls.filter(c => c[0] === 'editCommit').length, 1);
const saved = fixture(); saved.view.result.editableContent = false; saved.view.confirmDelete();
assert.equal(saved.dialog().title,'pm_remove_saved_pin_confirm');
assert.equal(saved.dialog().secondaryButton.value,'pm_remove_saved_pin');
saved.dialog().secondaryButton.action();assert.equal(saved.calls.filter(c => c[0] === 'editCommit').length,1,'removal wording keeps the existing confirmed operation');
assert.match(source,/Text\(this\.uiText\(this\.result\.editableContent \? 'pm_delete_pin_e216e3fe' : 'pm_remove_saved_pin'\)\)/,'action label uses the verified original-versus-repin classification');
const dismissed = fixture(); dismissed.view.confirmDelete(); dismissed.dialog().cancel(); assert.equal(dismissed.view.result.phase, 'edit');
const stale = fixture(); stale.view.confirmDelete(); stale.view.aboutToDisappear(); stale.dialog().secondaryButton.action();
assert.equal(stale.calls.filter(c => c[0] === 'editCommit').length, 0);
const changed = fixture(); changed.view.confirmDelete(); changed.view.result.pin = 'pin-2'; changed.dialog().secondaryButton.action();
assert.equal(changed.calls.filter(c => c[0] === 'editCommit').length, 0);
console.log('Edit Pin deletion: system confirmation, cancel, dismiss, one-shot and stale identity passed');
