const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const content = fs.readFileSync('entry/src/main/ets/components/PinmonyProfileRootContent.ets', 'utf8');
const ast = ts.createSourceFile('host.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
let method;
function visit(node) {
  if (ts.isMethodDeclaration(node) && node.name.getText(ast) === 'retainProfileBoardParent') method = node.getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast); assert(method);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const profile = 'https://www.pinterest.com/example/';
const board = profile + 'board/';
function fixture() {
  return Object.assign(new Host(), { profileStore: { origins: [{}], profile: { profileUrl: profile } },
    boardStore: { boardDetail: { pageKey: board }, boardReturnPage: board, boardReturnUrl: profile },
    nativeBoardVisible: () => true, profileUrlFromAddress: url => [profile, profile + '_created/'].includes(url) ? profile : '' });
}
const h = fixture(); assert(h.retainProfileBoardParent(), 'matching board keeps parent mounted');
h.boardStore.boardReturnUrl = profile + '_created/'; assert(h.retainProfileBoardParent(), 'created tab parent retained');
for (const invalidate of [
  h => { h.profileStore.origins = []; },
  h => { h.profileStore.profile = undefined; },
  h => { h.profileStore.profile.profileUrl = 'different'; },
  h => { h.boardStore.boardReturnPage = 'different'; },
  h => { h.boardStore.boardReturnUrl = 'different'; },
  h => { h.nativeBoardVisible = () => false; },
  h => { h.boardStore.boardDetail = undefined; }
]) { const f = fixture(); invalidate(f); assert.equal(f.retainProfileBoardParent(), false, 'unrelated or closed board cannot retain parent'); }
assert(source.includes('(this.currentProfileUrl() || this.retainProfileBoardParent() || this.retainProfilePinParent())'), 'board route cannot unmount parent');
const profileLayer = source.slice(source.indexOf('if (!this.chatProfileTransition && this.profileStore.origins.length > 0'), source.indexOf('ForEach(this.profilePanelPresentations()'));
const touchExpression = profileLayer.match(/\.hitTestBehavior\(([^\n]+)\)/)[1];
const accessibilityExpression = profileLayer.match(/\.accessibilityLevel\(([^\n]+)\)/)[1];
const zExpression = profileLayer.match(/\.zIndex\(([^\n]+)\)/)[1];
const touch = vm.runInNewContext('(function(){return '+touchExpression+';})', {HitTestMode:{None:'none',Default:'default'}});
const accessibility = new Function('return '+accessibilityExpression);
const z = new Function('return '+zExpression);
for (const state of [{}, {board:true}, {pin:true}, {chat:true}, {returning:true}]) {
  const context = {profileChatActive:!!state.chat,detailProfileReturning:!!state.returning,detailProfileTransition:true,
    pinStore:{detail:{}},retainProfileBoardParent:()=>!!state.board,retainProfilePinParent:()=>!!state.pin};
  const covered = !!(state.board || state.pin || state.chat || state.returning);
  assert.equal(touch.call(context),covered?'none':'default','covered profile cannot receive touch');
  assert.equal(accessibility.call(context),covered?'no-hide-descendants':'auto','covered profile cannot receive accessibility focus');
  assert.equal(z.call(context),state.board || state.pin?0:1,'profile stays below its child and above its returning detail');
}
for (const prop of ['backActive', 'interactionReady', 'automaticLoadingEnabled']) {
  assert(content.includes(prop + ': !view.coveredByBoard &&'), prop + ' blocked when covered');
}
assert(content.includes('if (view.coveredByBoard || view.coveredByPin || !view.profileStore.profile'), 'covered scroll callbacks cannot replace saved position');
assert(source.includes('coveredByBoard: this.retainProfileBoardParent()'));
assert(source.includes('NATIVE_PAGE_TRANSITION : BOARD_PAGE_TRANSITION)'), 'new board retains its entry and return transition');
console.log('Profile board parent: matching route retention, created tab, invalid context cleanup, covered gates, scroll preservation and board animation passed');
