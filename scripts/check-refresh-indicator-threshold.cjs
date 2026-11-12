const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const RefreshStatus = { Inactive: 0, Drag: 1, OverDrag: 2, Refresh: 3, Done: 4 };
function host(file, names) {
  const source = fs.readFileSync(file, 'utf8');
  const ast = ts.createSourceFile('page.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
  const methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert.equal(methods.length, names.length, file);
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { RefreshStatus });
  return { instance: new Host(), source };
}
for (const [file, visible, suppress, stateKey] of [
  ['feature_search/src/main/ets/components/PinmonySearchPage.ets', 'searchPullIndicatorVisible', 'suppressSearchContentLoading', 'searchRefreshState'],
  ['feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', 'showInboxRefreshIndicator', 'suppressContentLoading', 'inboxRefreshState']
]) {
  const { instance: h, source } = host(file, [visible, suppress]);
  assert(source.includes('.visibility(this.' + visible + '() ? Visibility.Visible : Visibility.Hidden)'), file + ': builder uses tested predicate');
  for (const refreshing of [false, true]) for (const state of Object.values(RefreshStatus)) {
    Object.assign(h, { refreshing, [stateKey]: state });
    assert.equal(h[visible](), refreshing || state === RefreshStatus.OverDrag || state === RefreshStatus.Refresh);
    assert.equal(h[suppress](), refreshing || [RefreshStatus.Drag, RefreshStatus.OverDrag, RefreshStatus.Refresh].includes(state),
      file + ': hiding ordinary-drag feedback must not reintroduce a central spinner');
  }
  h.refreshing = false;
  for (const state of [RefreshStatus.Drag, RefreshStatus.Inactive, RefreshStatus.Drag, RefreshStatus.Done]) {
    h[stateKey] = state;
    assert.equal(h[visible](), false, file + ': immediate scroll after reaching the top stays quiet');
  }
  h[stateKey] = RefreshStatus.OverDrag; assert.equal(h[visible](), true);
  h[stateKey] = RefreshStatus.Drag; assert.equal(h[visible](), false, 'retreat below the threshold hides the spinner');
  h.refreshing = true; assert.equal(h[visible](), true, 'actual refresh stays visible after release');
  h.refreshing = false; h[stateKey] = RefreshStatus.Done; assert.equal(h[visible](), false);
}
// Audit the other custom refresh hosts as well, so ordinary Drag cannot silently return.
for (const [file, method] of [
  ['feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'showRefreshIndicator'],
  ['feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'showProfileRefreshIndicator'],
  ['feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets', 'showPanelRefreshIndicator'],
  ['feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'showSectionRefreshIndicator']
]) {
  const { instance } = host(file, [method]);
  assert(!instance[method].toString().includes('RefreshStatus.Drag'), file + ': visibility must not depend on ordinary Drag');
}
const board = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
assert.match(board, /boardRefreshActive = state === RefreshStatus\.OverDrag \|\| state === RefreshStatus\.Refresh/);
console.log('Refresh thresholds: all six hosts audited; search/inbox drag, threshold, retreat, actual refresh, completion and duplicate-body suppression passed.');
