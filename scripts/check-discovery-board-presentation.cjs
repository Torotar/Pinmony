const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function compile(file, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: deps });
  return exports;
}
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name);
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1)).replace('private ', '');
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['snapshotChanged(', 'isDiscoveryBoard(', 'phase(', 'selectingPins(', 'boardTitleMenu(', 'titleBarOptions('].map(method).join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { Color: { Transparent: 'transparent' }, $r: value => value,
  SymbolGlyphModifier: class { fontColor() { return this; } } });
const header = (discoveryBoard, profileBoard, featured, editable = true) => {
  const host = new Host();
  Object.assign(host, { discoveryBoard, profileBoard, snapshot: { title: 'Board', ready: true, featured, editable } });
  return host.titleBarOptions();
};
for (const [discovery, profile, featured] of [[true, false, true], [true, true, false], [false, false, true]]) {
  const options = header(discovery, profile, featured);
  assert.equal(options.content.title.mainTitle, '');
  assert.equal(options.content.menu.value.length, 1);
  assert.equal(options.content.menu.value[0].content.label, '图板选项');
  assert.equal(options.style.originalStyle.contentStyle.backIconStyle.backgroundColor, 'transparent');
  assert.equal(options.style.originalStyle.contentStyle.menuStyle.backgroundColor, 'transparent');
  assert.equal(options.avoidLayoutSafeArea, true); assert.equal(options.enableComponentSafeArea, true);
}
for (const [profile, featured] of [[true, false], [true, true], [false, false]]) {
  const options = header(false, profile, featured);
  assert.equal(options.content.title.mainTitle, 'Board');
  assert.equal(options.content.menu.value.length, 2, 'ordinary/profile board keeps its existing title actions');
  assert.equal(options.style.originalStyle.contentStyle, undefined);
}
for (const discovery of [true,false]) for (const editable of [false,undefined]) {
  const options=header(discovery,true,false,editable === undefined ? null : editable);
  assert.equal(options.content.menu.value[0].content.label,'分享图板');assert(!options.content.menu.value.some(item=>item.content.label==='图板选项'));
}
const selectionHost = new Host();
Object.assign(selectionHost, { snapshot: { pageKey: 'board', nativeAccountGeneration: 2, flow: { phase: 'select' } }, contentScroll() {}, restoreContentScroll() {}, updateSavedFeedback() {}, syncEditValues() {} });
selectionHost.snapshotChanged();selectionHost.selectedIds = ['1'];selectionHost.snapshot.flow.phase = 'targets';selectionHost.snapshotChanged();
assert.equal(selectionHost.selectedIds[0], '1', 'targets retain selected preview');
selectionHost.creatingTarget = true;selectionHost.targetName = 'New';selectionHost.snapshot.flow.busy = true;selectionHost.snapshotChanged();
assert.equal(selectionHost.creatingTarget, true, 'submission retains name page');
assert.equal(selectionHost.titleBarOptions().content.title.mainTitle, '添加图板区块');
assert(selectionHost.titleBarOptions().content.menu.value[0].content.icon,'add-section title action must supply its checkmark icon');
assert.equal(selectionHost.titleBarOptions().content.menu.value[0].content.isEnabled, false);
selectionHost.snapshot.nativeAccountGeneration++;selectionHost.snapshotChanged();assert.equal(selectionHost.selectedIds.length, 0);
const presentation = compile('feature_board/src/main/ets/services/PinmonyBoardPresentation.ets');
const { PinmonyBoardOperationsController } = compile('feature_board/src/main/ets/controllers/PinmonyBoardOperationsController.ets', () => presentation);
const pin = id => ({ id, pinUrl: 'https://www.pinterest.com/pin/' + id + '/', title: 'Pin', imageUrl: 'https://i.pinimg.com/fixture.jpg', imageWidth: 236, imageHeight: 420 });
async function main() {
  const board = { session: 1, ready: true, pageKey: 'https://www.pinterest.com/fixture/board/', pins: [pin('111')], sections: [{ pins: [pin('222'), pin('111')] }] };
  assert.deepEqual(Array.from(presentation.boardVisiblePins(board), item => item.id), ['111', '222']);
  const calls = [], store = { boardDetail: board };
  let cancelled = false;
  const ports = { foreground: () => true, epoch: () => 1, document: () => board.pageKey,
    currentBoard: () => board.pageKey, movePage: () => '', hasDetail: () => false,
    cancelled: () => cancelled, retain: () => {}, rememberPin: url => calls.push(url),
    runScript: async script => { calls.push(script); return 'true'; }, feedback: message => { throw Error(message); } };
  const controller = new PinmonyBoardOperationsController(store, ports);
  controller.operate('open', '222'); await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls[0], pin('222').pinUrl, 'inline section Pin preserves the correct detail-return target');
  assert(calls[1].includes('PinmonyBoardApi.open'));
  cancelled = true; controller.operate('open', '222'); assert.equal(calls.length, 2, 'cancelled section Pin cannot open');
  board.flow = { phase: 'section', pins: [pin('333')] };
  assert.deepEqual(Array.from(presentation.boardVisiblePins(board), item => item.id), ['333']);
  console.log('Discovery/ordinary title contracts, HDS safe area, inline Pin opening and cancellation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
