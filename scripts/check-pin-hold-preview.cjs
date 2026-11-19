const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const read = (module, component) => fs.readFileSync(`${module}/src/main/ets/components/${component}.ets`, 'utf8');
const shared = read('common_ui', 'PinmonyPinHoldPreview');
const frameSource = shared.slice(shared.indexOf('export class'), shared.indexOf('@Component'));
const exportsObject = {};
new Function('exports', ts.transpileModule(frameSource, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText)(exportsObject);
const Frame = exportsObject.PinmonyPinHoldFrame;
const boardLabels = new Frame();
boardLabels.board = true;
assert.equal(boardLabels.label(1), 'pm_share_pin_d85b11f9');
assert.equal(boardLabels.label(3), 'pm_edit_pin_f9119bcf');
assert.equal(boardLabels.label(4), 'pm_profile_board_hold_reorder');
assert.equal(new Frame().label(1), 'pm_share_7e564575');
// A stable ForEach item must observe selection in the actual visual attributes, not a Builder boolean snapshot.
assert.doesNotMatch(shared, /private option\(index: number, active: boolean\)/);
assert.match(shared, /\.backgroundColor\(this\.tint\(this\.selectedIndex === index\)\)/);
assert.match(shared, /\.scale\(\{ x: this\.selectedIndex === index \? 1\.14 : 1, y: this\.selectedIndex === index \? 1\.14 : 1 \}\)/);
assert.match(shared, /this\.icon\(index, this\.selectedIndex === index\)/);
assert.match(shared, /this\.frame\.label\(this\.selectedIndex\)/);
const rect = (x, y, width, height) => ({ windowOffset: { x, y }, size: { width, height } });
const ui = { px2vp: px => px / 2, getComponentUtils: () => ({ getRectangleById: id => id === 'host' ? rect(20, 40, 800, 1440) : id === 'pin' ? rect(20, 40, 800, 1440) : undefined }) };
assert.equal(Frame.measure(ui, 'host', 'missing', 40, 50, false), undefined);
assert.equal(Frame.measure(ui, 'host', 'pin', 9, 50, false), undefined);
const labelFrame = new Frame();
labelFrame.hostHeight = 720;
labelFrame.hostWidth = 400;
labelFrame.left = 12;
labelFrame.right = 192;
assert.equal(labelFrame.labelOnRight(), true);
labelFrame.left = 208;
labelFrame.right = 388;
assert.equal(labelFrame.labelOnRight(), false);
assert.match(shared, /\.justifyContent\(this\.frame\.labelOnRight\(\) \? FlexAlign\.End : FlexAlign\.Start\)/);
const profile = read('feature_profile', 'PinmonyProfilePage');
assert.match(profile, /PinmonyPinHoldPreview\(\{ frame: this\.boardHoldFrame/);
assert.match(profile, /const choice = frame\.choice\(this\.boardHoldPointerX, this\.boardHoldPointerY\)/);
assert.doesNotMatch(profile, /private boardHoldButton[XY]\(/);
labelFrame.top = 226;
assert.equal(labelFrame.labelTop(0), 174);
assert.equal(labelFrame.labelTop(72), 174);
labelFrame.top = 112;
assert.equal(labelFrame.labelTop(72), 84);
assert.equal(labelFrame.labelTop(140), 152);
assert.match(shared, /SymbolGlyph\(\$r\('sys\.symbol\.circle_viewfinder'\)\)\.fontSize\(24\)/);
assert.match(read('feature_pin', 'PinmonyDetailPage'), /SymbolGlyph\(\$r\('sys\.symbol\.circle_viewfinder'\)\)\.fontSize\(24\)/);
assert.match(shared, /pin_hold_save/);
for (const name of ['pin_hold_save']) {
  const svg = fs.readFileSync(`common_ui/src/main/resources/base/media/${name}.svg`, 'utf8');
  assert.match(svg, /<path fill="#111111" fill-rule="evenodd"/);
  assert.doesNotMatch(svg, /fill="none"|<circle/);
}
for (const [board, profileBoard, chromeBottom] of [[false, false, 72], [true, false, 0], [false, true, 0]]) {
  for (const [x, y] of [[12, 22], [408, 22], [12, 738], [408, 738], [210, 380]]) {
    const frame = Frame.measure(ui, 'host', 'pin', x, y, board, profileBoard, chromeBottom);
    assert.equal(frame.choice(x - 10, y - 20), -1);
    for (let index = 0; index < (board ? 5 : 3); index++) {
      const bx = frame.buttonX(index), by = frame.buttonY(index);
      assert.ok(bx >= 34 - 1e-8 && bx <= 366 + 1e-8 && by >= Math.max(44, chromeBottom + 34) - 1e-8 && by <= 662 + 1e-8);
      assert.ok(Math.hypot(bx - frame.anchorX, by - frame.anchorY) >= 40);
      assert.equal(frame.choice(bx, by), index);
      {
        for (let other = 0; other < index; other++) {
          const centerGap = Math.hypot(bx - frame.buttonX(other), by - frame.buttonY(other));
          // A 54vp normal circle and a 1.14x highlighted circle leave at least 8vp between edges.
          assert.ok(centerGap - 27 - 27 * 1.14 >= 8, 'Board hold options are too close');
        }
      }
    }
  }
}
const at = (x, y, profileBoard = false) => Frame.measure(ui, 'host', 'pin', x, y, false, profileBoard);
const first = at(190, 510);
const second = at(200, 530);
assert.notEqual(first.buttonX(0), second.buttonX(0));
assert.notEqual(first.buttonY(0), second.buttonY(0));
for (let i = 0; i < first.optionCount(); i++) {
  assert.equal(first.buttonX(i), at(190, 510, true).buttonX(i));
  assert.equal(first.buttonY(i), at(190, 510, true).buttonY(i));
}
for (const [module, component] of [['feature_home', 'PinmonyHomeFeedPane'], ['feature_board', 'PinmonyBoardPage']]) {
  const source = read(module, component);
  assert.match(source, /\.onTouch\(\(event: TouchEvent\) => this\.trackPinHold\(event, pin\)\)/);
  assert.match(source, /\.priorityGesture\(LongPressGesture\(\{ duration: 450, repeat: false \}\)/);
  assert.match(source, /PinmonyPinHoldPreview\(\{ frame: this\.pinHoldFrame/);
  const lifecycle = ['canPreviewPinHold', 'beginPinHold', 'endPinHold', 'trackPinHold', 'pinHoldBlocksClick'];
  for (const name of lifecycle) assert.ok(source.includes(`private ${name}(`), name);
  const behavior = source.slice(source.indexOf('  private canPreviewPinHold('), source.indexOf('\n  @Builder', source.indexOf('  private canPreviewPinHold('))).replace(/\r/g, '');
  assert.doesNotMatch(behavior, /this\.(onPin|onAction|onShare|onMore|act)\s*\(/);
  assert.match(behavior, /TouchType\.Cancel \|\| event\.touches\.length !== 1/);
  assert.match(behavior, /this\.pinHoldFrame = undefined/);
  const isolated = behavior.replace(/private /g, '');
  const Fixture = new Function('TouchType', ts.transpileModule('class Fixture {\n' + isolated + '\n}\nreturn Fixture;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText);
  const TouchType = { Down: 0, Move: 1, Up: 2, Cancel: 3 };
  const pane = new (Fixture(TouchType))();
  const frame = Frame.measure(ui, 'host', 'pin', 210, 380, module === 'feature_board');
  const pin = { id: 'pin' };
  const opened = [];
  pane.canPreviewPinHold = () => true;
  pane.onHoldAction = (id, selected) => opened.push([id, selected]);
  pane.snapshot = { editable: true };
  const event = (type, x, y) => {
    const touch = { windowX: x + frame.originX, windowY: y + frame.originY };
    return { type, touches: type === TouchType.Up ? [] : [touch], changedTouches: [touch] };
  };
  pane.pinHoldFrame = frame;
  pane.pinHoldCoverDimmed = false;
  pane.trackPinHold(event(TouchType.Move, frame.buttonX(1), frame.buttonY(1)), pin);
  assert.equal(pane.pinHoldSelection, 1);
  assert.equal(pane.pinHoldCoverDimmed, true);
  pane.trackPinHold(event(TouchType.Move, frame.anchorX, frame.anchorY), pin);
  assert.equal(pane.pinHoldSelection, -1);
  assert.equal(pane.pinHoldCoverDimmed, true);
  pane.trackPinHold(event(TouchType.Cancel, frame.anchorX, frame.anchorY), pin);
  assert.equal(pane.pinHoldFrame, undefined);
  assert.equal(pane.pinHoldCoverDimmed, false);
  assert.equal(pane.pinHoldSelection, -1);
  assert.deepEqual(opened, []);
  pane.pinHoldFrame = frame;
  pane.trackPinHold(event(TouchType.Up, frame.anchorX, frame.anchorY), pin);
  assert.deepEqual(opened, []);
  pane.pinHoldFrame = frame;
  const release = event(TouchType.Up, frame.buttonX(0), frame.buttonY(0));
  pane.trackPinHold(release, pin);
  pane.releasePinHold(pin, release.changedTouches[0].windowX, release.changedTouches[0].windowY);
  assert.deepEqual(opened, [['pin', 0]]);
  if (module === 'feature_board') {
    pane.pinHoldFrame = frame;
    pane.snapshot.editable = false;
    pane.trackPinHold(release, pin);
    assert.deepEqual(opened, [['pin', 0]]);
  }
  if (module === 'feature_board') assert.match(source, /Image\(pin\.imageUrl\)\s*\.draggable\(false\)/);
  else assert.match(source, /PinmonyVideoCard\(\{[\s\S]*?allowImageDrag: false/);
}
const profileFrame = Frame.measure(ui, 'host', 'pin', 210, 380, false, true);
assert.equal(profileFrame.label(0), 'pm_profile_board_hold_reorder');
assert.equal(profileFrame.label(2), 'pm_edit_05183656');
assert.match(shared, /pin_hold_pencil_light[\s\S]*?pin_hold_pencil_dark/);
assert.equal(boardLabels.label(0), 'pm_move_to_another_board_62574b0d');
const app = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert.ok(app.includes("if (selection === 0) this.photoMenuCoordinator.openSinglePinMove(pin.pinUrl, board)"));
assert.ok(app.includes("await this.detailOperationsController.openImageLayer('search')"));
const holdRoutes = app.slice(app.indexOf('private async openHomeHoldAction'), app.indexOf('private openBoardPinMore'));
assert.doesNotMatch(holdRoutes, /this\.openHomePin\(|this\.boardOperation\('open'|finishHoldImageSearch/);
assert.match(holdRoutes, /this\.beginDetailOpening\(pin, source\);\s*const tab = this\.tabRequestToken/);
assert.match(holdRoutes, /detailOpeningToken !== token/);
assert.match(app, /this\.buildHoldImageSearch\(_identity\)\s*\}\s*else\s*\{\s*PinmonyDetailPage/);
assert.match(app, /!this\.holdBoardPage \|\|\s*this\.holdBoardChoice === 2 && this\.boardStore\.boardDetail\.flow\?\.phase === 'edit'/);
assert.match(app, /PinmonyBoardOrderPage\([\s\S]*?\.transition\(NATIVE_PAGE_TRANSITION\)/);
assert.match(holdRoutes, /this\.returnToNativeProfile\(this\.boardStore\.boardReturnUrl\)/);
const boardReads = fs.readFileSync('entry/src/main/ets/app/PinmonyBoardNativeReads.ets', 'utf8');
assert.match(boardReads, /sectionAction\(\{action:'sectionOrganize'\}, false\)/);
assert.match(holdRoutes, /openCardContactShare\(pin\.pinUrl, home\.pageKey\)/);
assert.match(holdRoutes, /openCardContactShare\(pin\.pinUrl, board\.pageKey\)/);
assert.doesNotMatch(holdRoutes, /this\.sharePinUrl\(/);
assert.match(app, /if \(cardContactShare\) \{\s*await this\.sharePinUrl\(pin\)/);
const sharing = fs.readFileSync('entry/src/main/ets/app/PinmonyShareNativeFlow.ets', 'utf8');
assert.match(sharing, /id: 'native-system-share'.*enabled: true/);
const searchScene = app.slice(app.indexOf('private buildHoldImageSearch'), app.indexOf('private buildMainScene'));
assert.doesNotMatch(searchScene, /\bButton\(/);
assert.match(searchScene, /LoadingProgress\(/);
assert.match(app, /this\.closeHoldImageSearch\(\); return true;/);
const photoMenu = fs.readFileSync('entry/src/main/ets/app/PinmonyPhotoMenuCoordinator.ets', 'utf8');
assert.ok(photoMenu.includes("{ action: 'sectionSingleMove', value: pin.id } : { action: 'targets', value: [pin.id] }"));
assert.ok(photoMenu.includes('this.openSinglePinMove(pin.pinUrl, board)'));
console.log('Pin hold preview: bounds, neutral touch, all options, gesture wiring and cancellation passed');
