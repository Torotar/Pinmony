const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  private backSavePanelLevel(): boolean {');
const end = source.indexOf('  private dismissApiBoards(): void', start);
const context = { exports: {} };
vm.runInNewContext(ts.transpileModule('export class Back { ' + source.slice(start, end) + ' }', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, context);
const back = new context.exports.Back(); let actions = 0;
back.activeSheetKind = 'save'; back.pinStore = { saveResult: { targetBoardId: 'fixture' } };
back.saveApiAction = action => { assert.equal(action, 'boardsBack'); actions++; back.pinStore.saveResult.targetBoardId = undefined; };
assert.equal(back.backSavePanelLevel(), true); assert.equal(actions, 1);
assert.equal(back.backSavePanelLevel(), false, 'next back can close the board list');
for (const state of [{ busy: true }, { loading: true }]) {
  back.pinStore.saveResult = { targetBoardId: 'fixture', ...state };
  assert.equal(back.backSavePanelLevel(), true); assert.equal(actions, 1, 'in-flight operations are not abandoned');
}
back.activeSheetKind = 'comments'; assert.equal(back.backSavePanelLevel(), false);
assert.match(source, /action.reason === DismissReason.PRESS_BACK && this.backSavePanelLevel\(\)\) return/);
assert.match(source, /dismissApiBoards: \(\): void => \{ if \(!this.backSavePanelLevel\(\)\) this.dismissApiBoards\(\); \}/);
console.log('Save section back: first returns to boards, second dismisses, busy guard and both return entry points passed');
