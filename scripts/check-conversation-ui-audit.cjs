const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const read = path => fs.readFileSync(path, 'utf8').replace(/\r\n/g, '\n');
const profile = read('feature_profile/src/main/ets/components/PinmonyProfilePage.ets');
const draft = read('feature_profile/src/main/ets/components/PinmonyPublishPage.ets');
const board = read('feature_board/src/main/ets/components/PinmonyBoardPage.ets');
const back = read('common_ui/src/main/ets/components/PinmonyBackToTopButton.ets');
const publish = read('common_ui/src/main/ets/components/PinmonyDraggablePublishButton.ets');
const invite = read('feature_board/src/main/ets/components/PinmonyBoardCollaboratorsPage.ets');
function block(source, from, to) {
  const start = source.indexOf(from); assert(start >= 0, from);
  const end = source.indexOf(to, start + from.length); assert(end > start, to);
  return source.slice(start, end);
}
function effect(source) {
  const start = source.indexOf('.backgroundEffect('); assert(start >= 0, 'glass effect exists');
  const end = source.indexOf('})', start); assert(end > start);
  return source.slice(start + '.backgroundEffect('.length, end + 1);
}
function evaluate(expression, host = {}, globals = {}) {
  return vm.runInNewContext('(function(){return (' + expression + ');})', {
    $r: key => key, Color: { Transparent: 'transparent' }, ...globals
  }).call(host);
}
const draftControl = block(draft, "Button() { SymbolGlyph($r('sys.symbol.trash'))", 'if (draft.expiresAt)');
const ideaControl = block(board, "if (this.phase() === 'ideas') {\n        Button", "}.width('100%').borderRadius(this.selectingPins()");
const reference = JSON.parse(JSON.stringify(evaluate(effect(publish))));
for (const [name, source] of [['draft delete', draftControl], ['back-to-top', back], ['unsaved idea', ideaControl]]) {
  const actual = JSON.parse(JSON.stringify(evaluate(effect(source), {snapshot:{flow:{saved:[]}}}, {pin:{id:'pin'}})));
  assert.deepEqual(actual, reference, name + ' uses publish glass parameters');
  assert(source.includes('.backgroundColor(Color.Transparent)'));
  assert(source.includes('.clip(true)'));
}
assert.deepEqual(JSON.parse(JSON.stringify(evaluate(effect(ideaControl), {snapshot:{flow:{saved:['pin']}}}, {pin:{id:'pin'}}))), {...reference,color:'app.color.accent'}, 'saved idea preserves accent with same effect');
assert(ideaControl.includes("this.snapshot.flow?.sectionId ? 'saveParentIdea' : 'save'"));
assert(draftControl.includes('this.confirmDeleteDraft(draft.id)'));
for (const busy of [false,true]) for (const uncertain of [false,true]) for (const draftLoading of [false,true]) {
  const expression = draftControl.match(/\.enabled\(([^)]+)\)/)[1];
  assert.equal(evaluate(expression,{state:{busy,uncertain,draftLoading}}), !busy&&!uncertain&&!draftLoading);
}
for (const busy of [false,true]) for (const uncertain of [false,true]) {
  const expression = ideaControl.match(/\.enabled\(([^)]+)\)/)[1];
  assert.equal(evaluate(expression,{snapshot:{flow:{busy,uncertain}}}), !busy&&!uncertain);
}
const padding = profile.match(/\.padding\(\{ left: 16, right: 16, top: ([^\n]+), bottom: 116 \}\)/);
assert(padding,'modern board body spacing exists');
for (const modern of [false,true]) for (const hubPane of [false,true]) for (const hubTab of ['pins','boards','collages']) {
  assert.equal(evaluate(padding[1],{modern:()=>modern,hubPane,hubTab}),modern&&hubPane&&hubTab==='boards'?6:0);
}
for (const name of ['hubSearch','hubFilters']) {
  const section = block(profile, '  private '+name+'(', '\n  }');
  assert(section.includes('.padding({left:16,right:16,top:6,bottom:6})'),name+' retains symmetric 6vp spacing');
}
assert.equal(6+evaluate(padding[1],{modern:()=>true,hubPane:true,hubTab:'boards'}),12,'filter bottom plus grid top matches search/filter 12vp gap');
const statusColor = invite.match(/\.backgroundColor\((user\.status[^\n]+)\)/);
assert(statusColor);
for (const status of ['owner','accepted','invited','pending']) {
  assert.equal(evaluate(statusColor[1],{}, {user:{status}}),status==='owner'||status==='accepted'?'transparent':'app.color.surface_muted');
}
assert(invite.includes('pm_invited_b43e8a99')); assert(invite.includes('.borderRadius(16)'));
const following = read('feature_profile/src/main/ets/components/PinmonyFollowingSegmentMaterial.ets');
assert(following.includes('extends PinmonySearchControlModifier'));
assert(invite.includes('.attributeModifier(new PinmonySearchControlModifier(this.immersiveLightMode, this.hdsDarkMode))'));
assert(invite.includes("top:this.titleContentInset() + (this.snapshot.phase === 'invite' ? 0 : 20),bottom:20"));
for (const token of ['.translate(','.position(','PanGesture','LongPressGesture','pullX','pullY']) assert(!back.includes(token),'removed drag effect: '+token);
assert(back.includes('.stateEffect(false)'));
assert(!back.includes('.stateStyles({'), 'no project-authored pressed styles');
assert(!/\.(?:scale|opacity)\(/.test(back), 'no scale or fade press effect');
assert(back.includes('Stack({ alignContent: Alignment.BottomEnd })'));
assert(back.includes('.margin({ right: 20, bottom: this.bottomInset })'));
assert(back.includes('.responseRegion({ x: this.hitLeft(), y: this.hitTop(), width: 44, height: 44 })'));
assert(back.includes('event.stopPropagation()'));
for (const path of [
  'feature_home/src/main/ets/components/PinmonyHomePage.ets',
  'feature_search/src/main/ets/components/PinmonySearchPage.ets',
  'feature_board/src/main/ets/components/PinmonyBoardPage.ets',
  'feature_pin/src/main/ets/components/PinmonyDetailPage.ets',
  'common_ui/src/main/ets/components/PinmonyImageSearchView.ets'
]) assert(read(path).includes('PinmonyBackToTopButton({'), path+' retains shared control');
console.log('Conversation UI audit passed: shared search material, invited background, both spacing changes, three glass controls, saved/busy states, fixed back-to-top and removed drag visuals.');
