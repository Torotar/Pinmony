const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
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
  const scope = { exports: {}, Curve: { EaseOut: 'ease-out' }, ...extra };
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
assert.match(board.source, /geometryTransition\(this\..*density-.*follow: true/, 'retain existing board transition');
console.log('Card motion: confirmed draft reflow, failure/session isolation, stable scroller, density animation and interaction guards passed');
