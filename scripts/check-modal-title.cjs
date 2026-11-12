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
  'requestMoreSheetClose', 'requestShareSheetClose', 'dismissSearchFilters', 'dismissProfileMenu']) {
  page[method] = () => calls.push(method);
}
page.pinStore = { editResult: { busy: false, picker: { busy: false }, phase: 'edit' } };
page.editPinAction = (...args) => calls.push(args);
for (const [kind, method] of Object.entries({ edit: 'dismissEditPin', comments: 'dismissApiComments',
  save: 'dismissApiBoards', publish: 'dismissProfilePublish', more: 'requestMoreSheetClose',
  share: 'requestShareSheetClose', searchFilter: 'dismissSearchFilters', profileMenu: 'dismissProfileMenu' })) {
  page.activeSheetKind = kind; page.closeNativeModal(); assert.equal(calls.pop(), method);
}
page.activeSheetKind = 'edit';
page.pinStore.editResult.busy = true; page.closeNativeModal(); assert.equal(calls.length, 0);
page.pinStore.editResult.busy = false; page.pinStore.editResult.picker.busy = true;
page.closeNativeModal(); assert.equal(calls.length, 0);
page.pinStore.editResult.picker.busy = false; page.pinStore.editResult.phase = 'boards';
page.closeNativeModal(); assert.deepEqual(calls.pop(), ['editPhase', ',"edit"']);
assert(source.includes("title: this.nativeSheetHasHdsTitle() ? undefined : { title: this.nativeModalLabel() }"));
assert(source.includes("showClose: !this.nativeSheetHasHdsTitle()")); // Save owns its HDS title; other Sheets keep native chrome.
assert(source.includes('PinmonyImmersiveLight.effect('));
assert(source.includes('private closeNativeModal()'));
console.log('Modal title: native HDS material, close routing, edit/picker busy gates and child-phase back passed');

const heightStart = source.indexOf('  private nativeModalHeight()');
const heightEnd = source.indexOf('\n  private nativeSheetUsesThemedModal(', heightStart);
assert(heightStart > 0 && heightEnd > heightStart);
const SheetSize = { LARGE: 'large', MEDIUM: 'medium', FIT_CONTENT: 'fit-content' };
const HeightHost = vm.runInNewContext(ts.transpileModule('class HeightHost {' + source.slice(heightStart, heightEnd) + '} HeightHost;', {}).outputText, { SheetSize });
const heightHost = new HeightHost();
for (const [width, height] of [[0, 0], [360, 800], [800, 360], [600, 960], [1280, 840], [360, 800]]) {
  Object.assign(heightHost, {activeSheetKind: 'comments', nativeSheetWindowWidth: width, nativeSheetWindowHeight: height});
  assert.equal(heightHost.nativeModalHeight(), SheetSize.LARGE, 'comments open at maximum detent across initial, portrait, landscape and resized windows');
}
for (const [kind, expected] of [['save', SheetSize.LARGE], ['edit', SheetSize.LARGE], ['more', SheetSize.FIT_CONTENT], ['publish', SheetSize.FIT_CONTENT], ['searchFilter', SheetSize.MEDIUM], ['profileMenu', SheetSize.FIT_CONTENT]]) {
  heightHost.activeSheetKind = kind;
  assert.equal(heightHost.nativeModalHeight(), expected, kind + ' height remains unchanged');
}
assert.match(source, /keyboardAvoidMode: this\.activeSheetKind === 'comments' \?\s*\(this\.nativeSheetWindowWidth >= 600 \? SheetKeyboardAvoidMode\.TRANSLATE_AND_RESIZE : SheetKeyboardAvoidMode\.RESIZE_ONLY\)/,
  'CENTER comments translate and resize; bottom comments retain resize-only avoidance');
assert(source.includes('height: this.nativeModalHeight()'), 'shared Sheet uses the checked height policy');
console.log('Comments height: default LARGE across window sizes; other panel heights and keyboard policy retained');
