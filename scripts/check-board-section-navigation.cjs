const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const transition = source.match(/const BOARD_ORGANIZE_PAGE_TRANSITION[\s\S]*?;\s*\n/);
assert(transition && /x: '100%'[^\n]*duration: 180, curve: Curve\.EaseOut/.test(transition[0]) &&
  /x: '100%'[^\n]*duration: 150, curve: Curve\.EaseIn/.test(transition[0]), 'both entry and exit slide right');
assert.equal((source.match(/\.transition\(BOARD_ORGANIZE_PAGE_TRANSITION\)/g) || []).length, 4,
  'organize, destination, edit and cover pages use the same transition');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1)).replace(/\s*@Builder\s*$/, '');
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['snapshotChanged', 'modernBoardActions', 'boardActionEnabled', 'back', 'phase'].map(method).join('\n') +
  '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const LayerHost = vm.runInNewContext(ts.transpileModule('class LayerHost {' +
  ['organizing', 'targeting', 'editing', 'covering', 'dispatch'].map(method).join('\n') +
  '} LayerHost;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const layers = new LayerHost(), dispatched = [];
Object.assign(layers, { snapshot: { pageKey: 'board', flow: { phase: 'section', pins: [{ id: '1' }] } },
  singlePinMove: false, onAction: value => dispatched.push(value) });
layers.dispatch(JSON.stringify({ action: 'sectionOrganize' }));
layers.snapshot.flow.phase = 'select'; layers.snapshot.flow.pins.pop();
assert(layers.organizing());
assert.equal(layers.retainedBoard.flow.phase, 'section');
assert.equal(layers.retainedBoard.flow.pins.length, 1, 'source remains stable while the organize view changes');
layers.dispatch(JSON.stringify({ action: 'targets', value: ['1'] }));
layers.snapshot.flow.phase = 'targets';
assert(layers.targeting(), 'bulk move opens a separate target page');
assert.equal(layers.retainedSelection.flow.phase, 'select');
assert.equal(layers.targetSelectedIds[0], '1');
layers.dispatch(JSON.stringify({ action: 'select' }));
assert.equal(layers.retainedBoard.flow.phase, 'section', 'returning from targets keeps the original underlay');
layers.singlePinMove = true; assert.equal(layers.organizing(), false);
layers.singlePinMove = false; layers.snapshot.pageKey = 'other'; assert.equal(layers.organizing(), false);
assert.equal(dispatched.length, 3);
const editLayer = new LayerHost(), editActions = [];
Object.assign(editLayer, { snapshot: { pageKey: 'board', nativeAccountGeneration: 1, flow: { phase: '' } },
  singlePinMove: false, onAction: value => editActions.push(value) });
editLayer.dispatch(JSON.stringify({ action: 'edit' })); editLayer.snapshot.flow.phase = 'edit';
assert(editLayer.editing()); assert.equal(editLayer.retainedBoard.flow.phase, '');
editLayer.dispatch(JSON.stringify({ action: 'coverAdjust' })); editLayer.snapshot.flow.cover = { selected: 'cover' };
assert(editLayer.covering()); assert.equal(editLayer.retainedEdit.flow.cover, undefined);
editLayer.snapshot.flow.cover = undefined; assert.equal(editLayer.covering(), false); assert(editLayer.editing());
editLayer.snapshot.nativeAccountGeneration = 2; assert.equal(editLayer.editing(), false);
assert.equal(editActions.length, 2);
const host = new Host(), actions = [];
Object.assign(host, {
  snapshot: { pageKey: 'synthetic', session: 1, ready: true, editable: true, pins: [],
    flow: { phase: 'targets', sectionId: '500', pins: [{ id: '88' }], targets: [] } },
  contentScroll() {}, restoreContentScroll() {}, updateSavedFeedback() {}, syncEditValues() {},
  isDiscoveryBoard: () => false, act: action => actions.push(action),
  boardCreateSubmitted: true, boardCreateStarted: false, creatingBoardTarget: true,
  boardTargetName: 'New board', boardTargetSecret: true
});
host.snapshotChanged();
assert(host.creatingBoardTarget, 'preparation snapshots must not close the creation form');
host.snapshot.flow.busy = true; host.snapshotChanged();
host.snapshot.flow.busy = false; host.snapshot.flow.error = 'failure'; host.snapshotChanged();
assert(host.creatingBoardTarget); assert.equal(host.boardTargetName, 'New board');
host.boardCreateSubmitted = true; host.snapshot.flow.error = ''; host.snapshot.flow.busy = true; host.snapshotChanged();
host.snapshot.flow.busy = false; host.snapshot.flow.uncertain = true; host.snapshotChanged();
assert(host.creatingBoardTarget, 'unknown creation retains its feedback');
host.snapshot.flow.uncertain = false; host.snapshotChanged();
assert.equal(host.creatingBoardTarget, false);
host.snapshot.flow.phase = 'section';
assert(host.modernBoardActions()); assert(host.boardActionEnabled(0), 'section Pins enable organize despite an empty parent feed');
host.legacyProfile = true; assert.equal(host.modernBoardActions(), false);
host.legacyProfile = false; host.snapshot.editable = false; assert.equal(host.modernBoardActions(), false);
host.snapshot.editable = true;
for (const phase of ['select', 'ideas', 'sectionEdit']) {
  host.snapshot.flow.phase = phase; host.back(); assert.equal(actions.pop(), 'sectionReturn');
}
host.snapshot.flow.phase = 'targets'; host.snapshot.flow.targetBoardId = '200'; host.back();
assert.equal(actions.pop(), 'sectionTargetBack');
host.snapshot.flow.targetBoardId = ''; host.back(); assert.equal(actions.pop(), 'select');
assert.equal(host.phase(), 'targets', 'bulk move presents a target page');
host.singlePinMove = true;
assert.equal(host.phase(), 'section', 'single-pin move retains its source section beneath the sheet');
host.back(); assert.equal(actions.pop(), 'close');
host.snapshot.flow.sectionId = '';
assert.equal(host.phase(), '', 'single-pin move retains its source board beneath the sheet');
host.snapshotChanged(); assert.equal(host.moveSheetOpen, true);
host.snapshot.flow.phase = ''; host.snapshotChanged(); assert.equal(host.moveSheetOpen, false);
console.log('Board section navigation: creation lifecycle, retained errors/unknown results, modern/legacy permissions and nested returns passed');
