const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const start = source.indexOf('  private titleBarOptions(');
assert(start >= 0);
const method = source.slice(start, source.indexOf('\n  private ', start + 1));
class SymbolIcon {
  constructor(resource) { this.resource = resource; }
  fontSize(size) { this.size = size; return this; }
  fontWeight(weight) { return this; }
  fontColor(colors) { this.colors = colors; return this; }
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, {
  $r: resource => resource, SymbolGlyphModifier: SymbolIcon,
  FontWeight: { Medium: 'Medium' }, BlurStrategy: { ENABLE: 1, DISABLE: 0 },
  ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 1 }, Color: { Transparent: 'transparent' },
  PinmonyImmersiveLight: { effect() {} }
});
const host = new Host();
Object.assign(host, {
  phase: () => 'sectionSelect', selectingPins: () => true, isDiscoveryBoard: () => false,
  uiText: key => key, immersiveLightMode: 'off', snapshot: { flow: {} }
});
for (const ids of [[], ['selected-pin']]) {
  host.selectedIds = ids;
  for (const gate of ['', 'busy', 'uncertain', 'loadingMore']) {
    host.snapshot = { flow: { busy: gate === 'busy', uncertain: gate === 'uncertain' }, loadingMore: gate === 'loadingMore' };
    const item = host.titleBarOptions().content.menu.value[0].content;
    assert.equal(item.icon.resource, 'sys.symbol.checkmark');
    assert.equal(item.icon.size, 24);
    assert.deepEqual(Array.from(item.icon.colors), ['app.color.primary_text']);
    assert.equal(item.label, ids.length ? 'pm_done_c0b3fbff' : 'pm_skip_fc50a99c');
    assert.equal(item.isEnabled, gate === '');
    const calls = [];
    host.onAction = value => calls.push(JSON.parse(value));
    if (item.isEnabled || gate === 'busy' || gate === 'uncertain') item.action();
    assert.equal(calls.length, gate === '' ? 1 : 0);
    if (calls.length) assert.deepEqual(calls[0], { action: 'sectionCreate', value: ids });
  }
}
host.phase = () => 'select';
host.snapshot = { flow: {} };
host.selectedIds = ['selected-pin'];
const next = host.titleBarOptions().content.menu.value[0].content;
assert.equal(next.icon.resource, 'sys.symbol.checkmark');
assert.equal(next.label, 'pm_next_acfc4e74');
assert.equal(next.isEnabled, true);
console.log('Board section title icon: Done/Skip, theme color, disabled gates, selected IDs and adjacent Next branch passed');
