const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const file = ts.createSourceFile('board.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && ['beginTargetCreate', 'closeTargetCreate', 'finishTargetCreateClose'].includes(node.name.getText(file))) methods.push(node.getText(file));
  ts.forEachChild(node, visit);
}
visit(file);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', { compilerOptions: { target: 99 } }).outputText, { PinmonyRuntimeLog: { info: () => {} } });
const host = new Host();
Object.assign(host, { snapshot: { flow: {} }, singlePinMove: false });
for (const board of [true, false]) {
  host.beginTargetCreate(board);
  assert.equal(host.targetCreateSheetOpen, true, 'both target creation entries open a panel');
  assert.equal(host.creatingBoardTarget, board);
  assert.equal(host.creatingTarget, !board);
  host.snapshot.flow.busy = true; host.closeTargetCreate();
  assert.equal(host.targetCreateSheetOpen, true, 'pending write blocks dismissal');
  host.snapshot.flow.busy = false; host.snapshot.flow.uncertain = true; host.closeTargetCreate();
  assert.equal(host.targetCreateSheetOpen, true, 'unknown write result retains the form');
  host.snapshot.flow.uncertain = false; host.closeTargetCreate();
  assert.equal(host.targetCreateSheetOpen, false);
  assert.equal(host.creatingBoardTarget || host.creatingTarget, true, 'closing sheet retains its content until disappearance');
  host.beginTargetCreate(!board);
  assert.equal(host.targetCreateSheetOpen, false, 'rapid reopen cannot overlap the closing sheet');
  assert.equal(host.creatingBoardTarget, board, 'late close cannot switch or clear the outgoing form');
  host.finishTargetCreateClose();
  assert.equal(host.creatingBoardTarget || host.creatingTarget, false, 'disappearance releases form state');
}
host.singlePinMove = true; host.beginTargetCreate(true);
assert.equal(host.targetCreateSheetOpen, false, 'single-Pin move reuses its existing panel');
for (const gate of ['busy', 'loading', 'uncertain']) {
  host.closeTargetCreate(); host.snapshot.flow[gate] = true; host.beginTargetCreate(false);
  assert.equal(host.creatingTarget, false, gate + ' cannot open another form');
  host.snapshot.flow[gate] = false;
}
assert(source.includes('.bindSheet($$this.targetCreateSheetOpen, this.presentedTargetCreateForm()'));
assert(/private presentedTargetCreateForm\(\)[\s\S]*?this\.targetCreateForm\(\)/.test(source), 'HDS wrapper retains the existing target form');
assert(/Column\(\)\.width\(0\)\.height\(0\)\s*\.bindSheet\(\$\$this\.targetCreateSheetOpen/.test(source), 'create panel owns a stable independent binding node');
assert(/\}, this\.sheetMaterialMode, false\)\)\s*\}\.width\('100%'\)\.height\('100%'\)\.backgroundColor\([^\n]+\)\s*\.bindSheet\(\$\$this\.moveSheetOpen/.test(source), 'move panel stays on the parent after the wrapped create options, without overriding creation binding');
for (const event of ['request', 'will-appear', 'appear', 'disappear']) assert(source.includes('event=' + event + ' source=board-target-create'), 'panel lifecycle logs ' + event);
assert(source.includes('if (targetSheet && (this.creatingBoardTarget || this.creatingTarget))'), 'full-page target list never renders a create form');
const form = source.slice(source.indexOf('private targetCreateForm()'), source.indexOf('private organizeContent('));
assert(!form.includes('pm_back_to_boards_dcf21f0d'), 'create panels have no separate return button');
assert(source.includes('onDisappear: (): void => this.finishTargetCreateClose()'), 'native disappearance releases the presentation lock');
const save = fs.readFileSync('feature_pin/src/main/ets/components/PinmonySaveSheet.ets', 'utf8');
for (const key of ['pm_back_to_boards_dcf21f0d', 'pm_create_cde2cd07']) {
  assert(new RegExp('Button\\(this\\.uiText\\("' + key + '"\\), \\{ type: ButtonType.Normal \\}\\)[^\\n]+borderRadius\\(20\\)').test(save), 'save buttons retain the current normal 20vp corners');
}
assert(save.includes(".backgroundColor($r('app.color.detail_save_accent'))"), 'create retains its themed accent');
assert(save.includes('.enabled(!!this.name.trim() && !this.result.busy && !this.result.loading)'), 'empty name and pending reads or writes disable creation');
console.log('Board target panels: no return button, closing-content retention, rapid-reopen isolation, write guards and save button styling passed');
