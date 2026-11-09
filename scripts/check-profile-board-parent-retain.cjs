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
assert(source.includes('.hitTestBehavior(this.profileChatActive || this.retainProfileBoardParent() || this.retainProfilePinParent() ? HitTestMode.None'));
assert(source.includes(".accessibilityLevel(this.profileChatActive || this.retainProfileBoardParent() || this.retainProfilePinParent() ? 'no-hide-descendants'"));
assert(source.includes('.zIndex(!this.retainProfileBoardParent() && !this.retainProfilePinParent() && this.detailProfileTransition'), 'parent stays below board');
for (const prop of ['backActive', 'interactionReady', 'automaticLoadingEnabled']) {
  assert(content.includes(prop + ': !view.coveredByBoard &&'), prop + ' blocked when covered');
}
assert(content.includes('if (view.coveredByBoard || view.coveredByPin || !view.profileStore.profile'), 'covered scroll callbacks cannot replace saved position');
assert(source.includes('coveredByBoard: this.retainProfileBoardParent()'));
assert(source.includes('TransitionEffect.IDENTITY) : BOARD_PAGE_TRANSITION)'), 'new board retains its entry and return transition');
console.log('Profile board parent: matching route retention, created tab, invalid context cleanup, covered gates, scroll preservation and board animation passed');
