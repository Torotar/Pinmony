const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const base = 'feature_settings/src/main/ets/components/';
for (const name of ['Settings', 'Account', 'DisplaySettings', 'RecommendationSettings', 'VisibilitySettings',
  'SocialPermissions', 'Notifications', 'BoardRecovery']) {
  const source = fs.readFileSync(base + 'Pinmony' + name + 'Page.ets', 'utf8');
  assert(source.includes("import { PinmonyLoadingOverlay } from 'common_ui'"), name);
  const ast = ts.createSourceFile(name + '.ts', source, ts.ScriptTarget.Latest, true);
  let branch;
  function visit(node) {
    if (ts.isIfStatement(node) && node.expression.getText(ast) === 'this.store.loading || this.store.busy') branch = node;
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert(branch && ts.isBlock(branch.thenStatement), name + ': retained read/write indicator host');
  const selection = branch.thenStatement.statements[0];
  assert(ts.isIfStatement(selection), name + ': separate read and write presentation');
  assert.equal(selection.expression.getText(ast), 'this.store.busy');
  assert(selection.thenStatement.getText(ast).includes('PinmonyLoadingOverlay({ showMessage: false })'), name);
  assert(!selection.thenStatement.getText(ast).includes('LoadingProgress('), name + ': one progress indicator during writes');
  assert(selection.elseStatement.getText(ast).includes('LoadingProgress('), name + ': retain ordinary read indicator');
  assert(!selection.elseStatement.getText(ast).includes('PinmonyLoadingOverlay('), name + ': reads do not add a grey mask');
  const outerGate = vm.runInNewContext('(function(){return ' + branch.expression.getText(ast) + ';})');
  const writeGate = vm.runInNewContext('(function(){return ' + selection.expression.getText(ast) + ';})');
  for (const [loading, busy, expected] of [[false, false, 'idle'], [true, false, 'read'], [false, true, 'write'], [true, true, 'write']]) {
    const host = { store: { loading, busy } };
    assert.equal(outerGate.call(host) ? writeGate.call(host) ? 'write' : 'read' : 'idle', expected, name);
  }
  const both = branch.getText(ast);
  assert.equal((both.match(/PinmonyLoadingOverlay\(/g) || []).length, 1, name + ': no duplicate write masks');
}
const visibility = fs.readFileSync(base + 'PinmonyVisibilitySettingsPage.ets', 'utf8');
const sheet = visibility.slice(visibility.indexOf('private presentedPrivacySheet()'), visibility.indexOf('\n  build()', visibility.indexOf('private presentedPrivacySheet()')));
assert(sheet.includes('Stack({ alignContent: Alignment.Center })'), 'privacy confirmation sheet owns its overlay host');
assert(sheet.includes('if (this.store.busy)'), 'private/public save mask follows the actual write');
assert(sheet.indexOf('PinmonyLoadingOverlay(') > sheet.indexOf('this.privacySheet()'), 'overlay covers the sheet content');
assert(sheet.includes('closeEnabled: !this.store.busy'), 'retain the existing sheet dismissal gate');
const recovery = fs.readFileSync(base + 'PinmonyBoardRecoveryPage.ets', 'utf8');
assert.equal((recovery.match(/this\.recoveryLoading\(\)/g) || []).length, 2, 'both recovery page and profile panel use the updated indicator');
const overlay = fs.readFileSync('common_ui/src/main/ets/components/PinmonyLoadingOverlay.ets', 'utf8');
assert(overlay.includes(".backgroundColor('#66000000')"), 'reuse the existing grey mask');
assert(overlay.includes('.hitTestBehavior(HitTestMode.Block)'), 'mask blocks repeated actions');
assert(overlay.includes('.width(\'100%\').height(\'100%\')'), 'mask fills its content host');
assert(overlay.includes('.accessibilityText(this.message)'), 'retain localized loading accessibility');
console.log('Settings write mask: 8 pages, privacy confirmation sheet, both recovery hosts, read/write/idle branches, touch blocking and existing localization passed');
