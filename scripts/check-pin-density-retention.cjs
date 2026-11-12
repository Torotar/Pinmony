const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const transitionSource = fs.readFileSync('common_ui/src/main/ets/services/PinmonyPinViewTransition.ets','utf8');
const transitionScope = {exports:{},Curve:{EaseOut:'ease-out'},require:()=>({})};
vm.runInNewContext(ts.transpileModule(transitionSource,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,transitionScope);
const PinmonyPinViewTransition = transitionScope.exports.PinmonyPinViewTransition;
const file = 'feature_profile/src/main/ets/components/PinmonyProfilePage.ets';
const source = fs.readFileSync(file, 'utf8');
const start = source.indexOf("} else if (this.profile.section === 'created' && this.profile.createdPins.length > 0)");
assert(start >= 0);
const block = source.slice(start, source.indexOf('} else if(this.modern()', start));
assert.match(block, /\{\s*WaterFlow\(\)/, 'Pin content keeps one WaterFlow instead of a density-keyed subtree');
assert.match(block, /\.columnsTemplate\(this\.contentColumnsTemplate\(\)\)/, 'update columns on the retained container');
assert(!block.includes('ForEach([this.contentColumnsTemplate()]'), 'density cannot destroy the image subtree');
const cardStart = source.indexOf('  private createdPinCard(');
const card = source.slice(cardStart, source.indexOf('  private boardGroup(', cardStart));
assert(cardStart >= 0);
assert(!card.includes('.geometryTransition('), 'one retained card must not produce outgoing/incoming shared-transition layers');
assert(!card.includes('.transition('), 'density must not add enter/exit image copies');
const key = block.match(/\(pin: PinmonyCreatedPin\) => ([^\n]+)\)/)[1];
assert(!/pinDensity|densePins|contentColumns/.test(key), 'density changes cannot invalidate card keys');
const methods = ['compactPinView', 'contentColumns', 'columnSlots', 'contentColumnsTemplate', 'selectPinView'].map(name => {
  const a = source.indexOf('  private ' + name + '('); assert(a >= 0, name);
  return source.slice(a, source.indexOf('\n  private ', a + 1));
});
const saves = [], animations = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { Curve: { EaseOut: 'ease-out' }, PinmonyPinViewTransition, PinmonyProfileLayoutPreference: { savePinDensity: n => saves.push(n) } });
const pins = [{ id: 'a', imageUrl: 'a.jpg' }, { id: 'b', imageUrl: 'b.jpg' }];
const h = Object.assign(new Host(), { modern: () => true, hubTab: 'pins', pinViewOpen: true,
  pinViewPage: 'profile', pinViewSession: 7, profile: { profileUrl: 'profile', session: 7, createdPins: pins },
  pinDensity: 1, interactionReady: true,
  getUIContext: () => ({ animateTo(options, change) { animations.push(options); change(); } }) });
for (const width of [360, 768, 1366]) {
  h.contentWidth = width;
  const columns = [];
  for (const density of [0, 1, 2, 1, 0, 2, 0]) {
    h.selectPinView(density); columns.push(h.contentColumns());
    assert.equal(h.profile.createdPins, pins, 'layout selection preserves the data and image URLs');
    assert.equal(h.contentColumnsTemplate().split(' ').length, h.contentColumns());
  }
  assert(columns[0] < columns[1] && columns[1] < columns[2]);
}
const count = saves.length; h.selectPinView(0); assert.equal(saves.length, count);
h.profile.session = 8; h.selectPinView(1); assert.equal(saves.length, count, 'stale panel cannot change layout');
assert(animations.every(options => options.duration === 280), 'retain the existing transition timing');
const boardSource=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');
const boardMethods=['contentColumns','columnSlots','contentColumnsTemplate','selectBoardDensity','pinCardKey'].map(name=>{
  const start=boardSource.indexOf('  private '+name+'(');assert(start>=0,name);
  return boardSource.slice(start,boardSource.indexOf('\n  }',start)+4);
});
const boardSaves=[],boardAnimations=[];
let boardHost;
const Board=vm.runInNewContext(ts.transpileModule('class Board {'+boardMethods.join('\n')+'} Board;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyPinViewTransition,
  PinmonyProfileLayoutPreference:{saveBoardDensity:value=>{boardSaves.push(value);boardHost.density=value;}}});
boardHost=Object.assign(new Board(),{density:1,snapshot:{pins},uiLanguage:'en',modernBoardActions:()=>true,
  boardViewLive:()=>true,getUIContext:()=>({animateTo(options,update){boardAnimations.push(options);update();}})});
const keys=pins.map(pin=>boardHost.pinCardKey(pin));
for(const width of [360,768,1366,360])for(const density of [0,1,2,1,0,2]) {
  boardHost.contentWidth=width;boardHost.selectBoardDensity(density);
  assert.equal(boardHost.snapshot.pins,pins);assert.deepEqual(pins.map(pin=>boardHost.pinCardKey(pin)),keys);
  assert.equal(boardHost.contentColumnsTemplate().split(' ').length,boardHost.contentColumns());
}
const saved=boardSaves.length;boardHost.selectBoardDensity(2);assert.equal(boardSaves.length,saved);
boardHost.boardViewLive=()=>false;boardHost.selectBoardDensity(0);assert.equal(boardSaves.length,saved);
assert(boardAnimations.every(options=>options.duration===280&&options.curve==='ease-out'));
console.log('Pin density retention: same WaterFlow, density-independent card keys, three modes at phone/tablet widths, unchanged data, duplicate and stale-session guards passed; device rendering excluded.');
