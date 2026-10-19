const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  private closeNativeModal()');
const end = source.indexOf('\n  @Builder', start);
assert(start > 0 && end > start);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const page = new Host(), calls = [];
for (const method of ['dismissEditPin', 'dismissApiComments', 'dismissApiBoards', 'dismissProfilePublish',
  'dismissMoreSheet', 'dismissShareSheet', 'dismissSearchFilters', 'dismissProfileMenu']) {
  page[method] = () => calls.push(method);
}
page.pinStore = { editResult: { busy: false, picker: { busy: false }, phase: 'edit' } };
page.editPinAction = (...args) => calls.push(args);
for (const [kind, method] of Object.entries({ edit: 'dismissEditPin', comments: 'dismissApiComments',
  save: 'dismissApiBoards', publish: 'dismissProfilePublish', more: 'dismissMoreSheet',
  share: 'dismissShareSheet', searchFilter: 'dismissSearchFilters', profileMenu: 'dismissProfileMenu' })) {
  page.activeSheetKind = kind; page.closeNativeModal(); assert.equal(calls.pop(), method);
}
page.activeSheetKind = 'edit';
page.pinStore.editResult.busy = true; page.closeNativeModal(); assert.equal(calls.length, 0);
page.pinStore.editResult.busy = false; page.pinStore.editResult.picker.busy = true;
page.closeNativeModal(); assert.equal(calls.length, 0);
page.pinStore.editResult.picker.busy = false; page.pinStore.editResult.phase = 'boards';
page.closeNativeModal(); assert.deepEqual(calls.pop(), ['editPhase', ',"edit"']);
const title = fs.readFileSync('common_ui/src/main/ets/components/PinmonyModalTitle.ets', 'utf8');
assert(title.includes('HdsNavigationTitleMode.MODAL'));
assert(title.includes('hdsMaterial.MaterialType.IMMERSIVE'));
assert(title.includes('if (this.closeEnabled) this.onClose()'));
console.log('Modal title: native HDS material, close routing, edit/picker busy gates and child-phase back passed');
