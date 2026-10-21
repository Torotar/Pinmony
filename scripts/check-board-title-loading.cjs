const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const start = source.indexOf('  private boardTitleMenu(');
const method = source.slice(start, source.indexOf('\n  private ', start + 1)).replace('private ', '');
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { $r: value => value, SymbolGlyphModifier: class { fontSize() { return this; } fontColor() { return this; } } });
const host = new Host();
Object.assign(host, { uiText: key => key, isDiscoveryBoard: () => false });
for (const editable of [undefined, false, true]) {
  host.snapshot = { ready: false, editable };
  const menu = host.boardTitleMenu();
  assert(menu.some(item => item.content.icon === 'app.media.lucide_ellipsis'));
  assert(!menu.some(item => item.content.icon instanceof Object));
  assert(menu.every(item => !item.content.isEnabled));
}
host.snapshot = { ready: true, editable: true };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'));
host.snapshot = { ready: true, editable: false };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'non-editable alone does not imply another user');
host.snapshot = { ready: true, editable: false, canFollow: false };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'own saved collection never shows follow');
host.snapshot = { ready: true, editable: true, canFollow: true };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'own board cannot show follow even with conflicting eligibility');
host.snapshot = { ready: true, editable: false, canFollow: true };
assert(!host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'));
host.snapshot = { ready: true, editable: false, canFollow: false, followBusy: true };
assert(!host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'pending follow retains its disabled control');
console.log('Board title: loading never infers follow permission; owned board keeps options; confirmed visitor behavior preserved');
for (const ready of [false, true]) {
  host.snapshot = { pageKey: 'https://www.pinterest.com/example/pins/', ready, editable: false, canFollow: true };
  assert.equal(host.boardTitleMenu().length, 0, 'all Pins collection has no title actions even during loading');
}
