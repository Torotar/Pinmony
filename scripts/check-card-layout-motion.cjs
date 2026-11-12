const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const transitionSource=fs.readFileSync('common_ui/src/main/ets/services/PinmonyPinViewTransition.ets','utf8');
const transitionScope={exports:{},Curve:{EaseOut:'ease-out'},require:()=>({})};
vm.runInNewContext(ts.transpileModule(transitionSource,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,transitionScope);
const PinmonyPinViewTransition=transitionScope.exports.PinmonyPinViewTransition;
function host(file, names, extra = {}) {
  const source = fs.readFileSync(file, 'utf8').replace(/\bstruct (\w+)/g, 'class $1');
  const tree = ts.createSourceFile('view.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) &&
    names.every(name => node.members.some(member => ts.isMethodDeclaration(member) && member.name.getText(tree) === name)));
  assert(component, names.join(','));
  const methods = names.map(name => {
    const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert(method, name);return method.getText(tree);
  });
  const scope = { exports: {}, Curve: { EaseOut: 'ease-out' }, PinmonyPinViewTransition, ...extra };
  vm.runInNewContext(ts.transpileModule('export class View {' + methods.join('\n') + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, scope);
  const view = new scope.exports.View(), animations = [];
  view.getUIContext = () => ({ animateTo(options, change) { animations.push(options);change(); } });
  return { view, animations, source };
}
const publish = host('feature_profile/src/main/ets/components/PinmonyPublishPage.ets', ['syncDraftCards']);
const p = publish.view;
Object.assign(p, { draftCards: [], draftCardsToken: -1, draftLayoutRevision: 0,
  dismissDraftExpiryTip() {}, syncWebsiteRoute() {},
  state: { token: 1, phase: 'photo', drafts: [{ id: 'a' }, { id: 'b' }, { id: 'c' }] } });
p.syncDraftCards();assert.equal(publish.animations.length, 0, 'initial loading is not a delete animation');
p.state.busy = true;p.syncDraftCards();assert.equal(publish.animations.length, 0, 'clicking delete cannot remove or animate unconfirmed drafts');
p.state.busy = false;p.state.uncertain = true;p.syncDraftCards();assert.equal(p.draftCards.length, 3);assert.equal(publish.animations.length, 0);
p.state.uncertain = false;p.state.drafts = [{ id: 'a' }, { id: 'c' }];p.syncDraftCards();
assert.equal(publish.animations.length, 1);assert.equal(publish.animations[0].duration, 280);
assert.equal(p.draftLayoutRevision, 1);assert.deepEqual(Array.from(p.draftCards, d => d.id), ['a', 'c']);
p.state.drafts = [{ id: 'c' }];p.syncDraftCards();assert.equal(p.draftLayoutRevision, 2, 'consecutive confirmed removals reflow again');
p.state.token = 2;p.state.drafts = [];p.syncDraftCards();assert.equal(publish.animations.length, 2, 'new session does not animate old cards into another page');
assert.match(publish.source, /WaterFlow\(\{scroller:this\.scroller,sections:this\.draftSections\(\)\}\)/, 'keep the existing scroll container');
assert.match(publish.source, /draft\.id \+ ':' \+ this\.uiLanguage \+ ':' \+ this\.draftLayoutRevision/);
assert.match(publish.source, /geometryTransition\('pinmony-draft-layout-'.*follow: true/);
let savedPin = [], savedBoard = [];
const preference = { savePinDensity: n => savedPin.push(n), saveBoardDensity: n => savedBoard.push(n) };
const profile = host('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', ['selectPinView'], { PinmonyProfileLayoutPreference: preference });
Object.assign(profile.view, { pinViewOpen: true, pinViewPage: 'profile', pinViewSession: 1,
  profile: { profileUrl: 'profile', session: 1 }, modern: () => true, hubTab: 'pins', interactionReady: true, pinDensity: 1 });
profile.view.selectPinView(2);assert.deepEqual(savedPin, [2]);assert.equal(profile.view.pinDensity, 2);assert.equal(profile.animations.length, 1);
profile.view.selectPinView(2);assert.equal(profile.animations.length, 1, 'same layout does not restart animation');
profile.view.interactionReady = false;profile.view.selectPinView(0);assert.deepEqual(savedPin, [2]);
const board = host('feature_board/src/main/ets/components/PinmonyBoardPage.ets', ['selectBoardDensity'], { PinmonyProfileLayoutPreference: preference });
Object.assign(board.view, { density: 1, boardViewLive: () => true });board.view.selectBoardDensity(0);
assert.deepEqual(savedBoard, [0]);assert.equal(board.animations.length, 1);
board.view.boardViewLive = () => false;board.view.selectBoardDensity(2);assert.deepEqual(savedBoard, [0]);
assert(!profile.source.includes('pinmony-profile-density-'), 'retained Pin cards cannot also participate in shared geometry transitions');
assert(!board.source.includes('pinmony-board-density-'), 'board uses retained layout instead of duplicate shared-transition layers');
assert(!board.source.includes('ForEach([this.contentColumnsTemplate()'), 'board density cannot recreate its WaterFlow');
assert.match(board.source,/PinmonyPinViewTransition\.run\(this\.getUIContext\(\),/,'board uses the shared Pin transition');
assert.match(profile.source,/PinmonyPinViewTransition\.run\(this\.getUIContext\(\),/,'profile uses the same shared transition');
assert.match(board.source,/private viewOption\(\$\$: PinmonyBoardViewOption\)/,
  'Board view options must bind selected and enabled values by reference instead of retaining primitive builder arguments');
const boardTree=ts.createSourceFile('board.ts',board.source,ts.ScriptTarget.Latest,true);
const optionCalls=[];let optionBuilder;
function inspectOptions(node){
  if(ts.isMethodDeclaration(node)&&node.name.getText(boardTree)==='viewOption')optionBuilder=node.getText(boardTree);
  if(ts.isCallExpression(node)&&node.expression.getText(boardTree)==='this.viewOption'){
    assert.equal(node.arguments.length,1,'Reference builders take one object literal');
    assert(ts.isObjectLiteralExpression(node.arguments[0]),'Each option passes its current state directly');
    optionCalls.push(Object.fromEntries(node.arguments[0].properties.map(p=>[p.name.getText(boardTree),p.initializer.getText(boardTree)])));
  }
  ts.forEachChild(node,inspectOptions);
}inspectOptions(boardTree);
assert.equal(optionCalls.length,5,'Cover both filters and all three density choices');
for(const binding of ['.select($$.selected)','.enabled($$.enabled)','.accessibilityChecked($$.selected)','this.uiText($$.resourceKey)','$$.onSelect()'])
  assert(optionBuilder.includes(binding),'Actual builder must consume live binding: '+binding);
const filter=host('feature_board/src/main/ets/components/PinmonyBoardPage.ets',
  ['boardViewLive','boardViewFilterReady','selectBoardViewFavorites']);
let filterRequests=0;
Object.assign(filter.view,{viewOpen:true,viewPage:'board-a',viewScope:'scope-a',snapshot:{pageKey:'board-a',canFilterFavorites:true,favoriteOnly:false,loadingMore:false},
  scrollScope:()=> 'scope-a',modernBoardActions:()=>true,phase:()=>'',boardActionEnabled:()=>true,
  act(action){assert.equal(action,'favorites');filterRequests++;}});
const evaluate=(expression)=>vm.runInNewContext('(function(){return '+expression+';})').call(filter.view);
const all=optionCalls.find(o=>o.resourceKey==="'pm_all_pins_9a2e0270'");
const favorites=optionCalls.find(o=>o.resourceKey==="'pm_board_view_favorites'");
for(const favoriteOnly of [false,true,false,true,false]){
  filter.view.snapshot={...filter.view.snapshot,favoriteOnly};
  assert.equal(evaluate(all.selected),!favoriteOnly,'All Pins selection follows snapshot replacement');
  assert.equal(evaluate(favorites.selected),favoriteOnly,'Favorites selection follows snapshot replacement');
  filter.view.selectBoardViewFavorites(favoriteOnly);const before=filterRequests;
  evaluate(favoriteOnly?all.onSelect:favorites.onSelect)();assert.equal(filterRequests,before+1,'Changed choice dispatches once');
}
for(const blocked of ['loading','permission','page','scope','closed','phase','unavailable','action']){
 const previous={...filter.view.snapshot};const count=filterRequests;
 if(blocked==='loading')filter.view.snapshot.loadingMore=true;
 if(blocked==='permission')filter.view.snapshot.canFilterFavorites=false;
 if(blocked==='page')filter.view.snapshot.pageKey='board-b';
 if(blocked==='scope')filter.view.viewScope='scope-b';
 if(blocked==='closed')filter.view.viewOpen=false;
 if(blocked==='phase')filter.view.phase=()=> 'section';
 if(blocked==='unavailable')filter.view.modernBoardActions=()=>false;
 if(blocked==='action')filter.view.boardActionEnabled=()=>false;
 assert.equal(evaluate(favorites.enabled),false,'Live disablement: '+blocked);
 filter.view.selectBoardViewFavorites(true);assert.equal(filterRequests,count,'No request when blocked: '+blocked);
 filter.view.snapshot=previous;filter.view.viewScope='scope-a';filter.view.viewOpen=true;
 filter.view.phase=()=>'';filter.view.modernBoardActions=()=>true;filter.view.boardActionEnabled=()=>true;
}
assert.deepEqual(board.animations[0],profile.animations[0],'duration and curve are identical');
console.log('Card motion: confirmed draft reflow, stable scroller, density animation, live board option bindings, repeated filter selection, permission/loading/page/scope guards passed');
