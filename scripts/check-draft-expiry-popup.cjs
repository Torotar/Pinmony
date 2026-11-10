const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_profile/src/main/ets/components/PinmonyPublishPage.ets';
const source = fs.readFileSync(file, 'utf8');
const ast = ts.createSourceFile(file, source.replace('export struct PinmonyPublishPage', 'export class PinmonyPublishPage'), ts.ScriptTarget.Latest, true);
const view = ast.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'PinmonyPublishPage');
const methods = ['toggleDraftExpiryTip', 'dismissDraftExpiryTip'].map(name =>
  view.members.find(n => ts.isMethodDeclaration(n) && n.name?.getText(ast) === name).getText(ast)).join('\n');
let resolveOpen, opened, closed = 0, disposed = 0;
const prompt = { openPopup(content, target, options) {
  opened = { content, target, options }; return new Promise(resolve => { resolveOpen = resolve; });
}, async closePopup() { closed++; } };
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
  ComponentContent: class { dispose() { disposed++; } }, wrapBuilder: f => f,
  buildPinmonyDraftExpiryTip() {}, Placement: { BottomRight: 'below' }, $r: v => v
});
function fixture() { return Object.assign(new Host(), { mounted: true, state: { phase: 'photo' },
  websiteRouteOpen: false, showDraftExpiryTip: false, draftExpiryOpening: false,
  getUIContext: () => ({ getPromptAction: () => prompt }) }); }
(async () => {
  const h = fixture(), pending = h.toggleDraftExpiryTip();
  assert.equal(opened.target.id, 'pinmony-draft-expiry-info');
  assert.equal(opened.options.placement, 'below'); assert(opened.options.enableArrow && opened.options.autoCancel);
  await h.toggleDraftExpiryTip();
  opened.options.onStateChange({ isVisible: true }); resolveOpen(); await pending;
  assert.equal(h.showDraftExpiryTip, false, 'second click while opening cannot be undone by late visible callback');
  assert.equal(closed, 1);
  const leaving = fixture(), late = leaving.toggleDraftExpiryTip();
  leaving.mounted = false; await leaving.dismissDraftExpiryTip(); resolveOpen(); await late;
  assert.equal(disposed, 1); assert.equal(leaving.draftExpiryContent, undefined);
  const failed = fixture(); failed.getUIContext = () => ({ getPromptAction: () => ({ openPopup: async () => { throw Error('missing anchor'); }, closePopup: prompt.closePopup }) });
  await failed.toggleDraftExpiryTip(); assert.equal(failed.showDraftExpiryTip, false); assert.equal(failed.draftExpiryOpening, false);
  assert(source.includes("componentId: 'pinmony-draft-expiry-info'"));
  assert(!source.includes("if ($$.phase === 'photo' && this.showDraftExpiryTip)"), 'no page-top overlay');
  const tip = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyDraftExpiryTip.ets', 'utf8');
  assert(tip.includes('@StorageLink(\'pinmonyLanguage\')')); assert(tip.includes('maxWidth: 300'));
  assert(!tip.includes('maxLines('), 'long translations can wrap without truncation');
  console.log('Draft expiry popup: HDS anchor, downward placement, wrapping, live language, double-click, late opening cleanup and failure recovery passed; device geometry excluded.');
})().catch(error => { console.error(error); process.exitCode = 1; });
