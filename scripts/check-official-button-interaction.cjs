const fs = require('node:fs'), assert = require('node:assert/strict');
// Static wiring regression only: no claim about device rendering or official position support.
const files = [
  'common_ui/src/main/ets/components/PinmonyBackToTopButton.ets',
  'common_ui/src/main/ets/components/PinmonyDraggablePublishButton.ets',
  'feature_profile/src/main/ets/components/PinmonyPublishPage.ets',
  'feature_board/src/main/ets/components/PinmonyBoardPage.ets'
];
const baseline = process.env.PINMONY_BUTTON_BASELINE;
const read = file => fs.readFileSync(baseline ? baseline + '/' + file : file, 'utf8');
for (const file of files) {
  const source = read(file);
  assert(!source.includes('PinmonyButtonInteractionModifier'), file + ': remove material implicated by screenshot regression');
  const marker = '.stateEffect(false)';
  assert.equal(source.split(marker).length - 1, 1, file + ': preserve exactly one blur-only control');
  const at = source.indexOf(marker);
  const before = source.slice(Math.max(0, at - 900), at);
  const after = source.slice(at, source.indexOf('.onClick(', at));
  assert(before.includes('.backgroundEffect(') && before.includes('publish_button_glass'), file + ': retain original theme glass');
  assert(before.includes('primary_text'), file + ': retain explicit theme icon color');
  assert(after.includes('.enabled('), file + ': preserve disabled guard');
  assert(source.includes('.onClick('), file + ': preserve business action');
}
assert(!read('common_ui/Index.ets').includes('PinmonyButtonInteractionModifier'), 'unused material is not exported');
const back = read(files[0]);
assert(!/\.(?:scale|translate|opacity)\(/.test(back), 'no replacement deformation or fading');
assert(back.includes('.margin({ right: 20, bottom: this.bottomInset })'));
assert(back.includes('.hitTestBehavior(HitTestMode.Block)'));
const publish = read(files[1]);
assert(publish.includes('options.systemMaterial = active ? new uiMaterial.ImmersiveMaterial'), 'preserve separate source menu material');
assert(publish.includes("lightEffect: { color: $r('app.color.immersive_interaction_light') }"), 'preserve unified menu light color');
assert(publish.includes('this.remember(this.layoutWidth, this.layoutHeight)'), 'preserve publish drag persistence');
const board = read(files[3]);
assert(board.includes("this.snapshot.flow?.saved.includes(pin.id) ? Color.White : $r('app.color.primary_text')"));
assert(board.includes("this.snapshot.flow?.saved.includes(pin.id) ? $r('app.color.accent') : $r('app.color.publish_button_glass')"));
assert(board.includes("this.snapshot.flow?.sectionId ? 'saveParentIdea' : 'save'"), 'preserve both ideas save entries');
for (const file of ['feature_home/src/main/ets/components/PinmonyHomePage.ets','feature_search/src/main/ets/components/PinmonySearchPage.ets',files[3],'feature_pin/src/main/ets/components/PinmonyDetailPage.ets','common_ui/src/main/ets/components/PinmonyImageSearchView.ets']) {
  assert.equal(read(file).split('PinmonyBackToTopButton({').length - 1, 1, file + ': shared back-to-top entry');
}
for (const theme of ['base', 'dark']) {
  const colors = JSON.parse(read('common_ui/src/main/resources/' + theme + '/element/color.json')).color;
  for (const name of ['publish_button_glass','immersive_interaction_light','primary_text','accent']) assert(colors.some(item => item.name === name && item.value), theme + ': ' + name);
}
console.log('Button visual regression wiring passed: four original blur controls, explicit theme icons, disabled/actions, saved tint, five back-to-top entries, separate menu and unified light color. Device rendering remains unverified.');
