const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_profile/src/main/ets/components/PinmonyProfilePage.ets';
const source = fs.readFileSync(file, 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
function method(name) {
  let found;
  function visit(node) {
    if (ts.isMethodDeclaration(node) && node.name.getText(ast) === name) found = node;
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert(found, `Missing profile method: ${name}`);
  return found;
}
const button = method('hubStateButton');
const versionBranch = button.body.statements[0];
assert(ts.isIfStatement(versionBranch));
assert.equal(versionBranch.expression.getText(ast), "deviceInfo.apiAvailable('26.0.0')");
const native = versionBranch.thenStatement.getText(ast);
const fallback = versionBranch.elseStatement.getText(ast);
const material = native.match(/\.systemMaterial\(([\s\S]*?)\)\s*\.shadow\(/);
const shadow = native.match(/\.shadow\(([\s\S]*?)\)\s*\.accessibilityText\(/);
assert(material && shadow, 'Read the actual material and shadow expressions from the button');
assert(!material[1].includes('!this.hubSelected'), 'Selecting a filter must not disable immersive material');
assert(!shadow[1].includes('!this.hubSelected'), 'Selecting a filter must retain its material shadow');
assert(!/systemMaterial|uiMaterial\.|ColorMetrics/.test(fallback), 'API 24/25 keep the original Toggle path');
assert(fallback.includes('Toggle({type:ToggleType.Button,isOn:this.hubSelected(kind)})'));
assert(fallback.includes(".selectedColor($r('app.color.detail_save_accent'))"));
for (const branch of [native, fallback]) {
  assert(branch.includes('.accessibilitySelected(this.hubSelected(kind))'));
  assert(branch.includes('.enabled(this.interactionReady && !this.profile.suggestionWriting)'));
  assert(branch.includes("this.hubSelected(kind) ? Color.White : $r('app.color.primary_text')"));
}
const clickMatches = [...button.getText(ast).matchAll(/\.onClick\((\(\) => \{[\s\S]*?\n      \})\)/g)];
assert.equal(clickMatches.length, 2, 'Exercise both native and fallback click handlers');
const kinds = ['favorite', 'created', 'groups', 'secret', 'following', 'collage-drafts', 'collage-created'];
function boot(api, supported = true, failColor = false, rgb = [230, 0, 35]) {
  let probes = 0, colors = 0;
  const empty = Symbol('empty');
  const code = 'class Host {' + ['hubSelected', 'hubStateMaterialColor'].map(n => method(n).getText(ast)).join('\n') +
    `\nrender(kind) { if (${versionBranch.expression.getText(ast)}) return { material: ${material[1]}, shadow: ${shadow[1]} }; return undefined; }\n` +
    clickMatches.map((match, index) => `click${index}(kind) { return (${match[1]})(); }`).join('\n') + '\n} Host;';
  const Host = vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
    deviceInfo: { apiAvailable: version => { assert.equal(version, '26.0.0'); return api >= 26; } },
    uiMaterial: { Material: { empty }, ImmersiveStyle: { THICK: 3, REGULAR: 2 },
      isImmersiveMaterialSupported() { probes++; assert(api >= 26); return supported; },
      ImmersiveMaterial: class { constructor(options) { Object.assign(this, options); } } },
    $r: key => key,
    ColorMetrics: {
      resourceColor(key) { colors++; assert.equal(key, 'app.color.detail_save_accent'); if (failColor) throw Error('color unavailable'); return { red: rgb[0], green: rgb[1], blue: rgb[2] }; },
      rgba: (r, g, b, a) => ({ color: `rgba(${r},${g},${b},${a})` })
    }
  });
  const host = new Host();
  Object.assign(host, { immersiveLightMode: 'immersive', hdsDarkMode: false, favoriteFilter: false, createdFilter: false,
    boardFilter: '', collageDrafts: false, collageCreated: false, interactionReady: true, profile: { suggestionWriting: false },
    requests: 0, requestHub() { this.requests++; } });
  return { host, empty, probes: () => probes, colors: () => colors };
}
for (const api of [24, 25]) {
  const h = boot(api);
  for (const kind of kinds) for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
    h.host.immersiveLightMode = mode;
    assert.equal(h.host.render(kind), undefined);
  }
  assert.equal(h.probes(), 0); assert.equal(h.colors(), 0);
}
for (const dark of [false, true]) {
  const rgb = dark ? [255, 70, 100] : [230, 0, 35];
  for (const mode of ['gentle', 'immersive', 'exquisite']) for (const kind of kinds) {
    const h = boot(26, true, false, rgb), host = h.host;
    host.immersiveLightMode = mode; host.hdsDarkMode = dark;
    const before = host.render(kind);
    assert.equal(before.material.materialColor, undefined);
    host.click0(kind);
    assert.equal(host.hubSelected(kind), true);
    const selected = host.render(kind);
    assert.notEqual(selected.material, h.empty, `${kind}: selected material stays enabled`);
    assert.equal(selected.material.materialColor, `rgba(${rgb.join(',')},0.9)`);
    assert.equal(selected.material.style, mode === 'gentle' ? 3 : 2);
    assert.equal(selected.material.colorInvert, false);
    assert.equal(selected.material.interactive, true);
    assert.equal(selected.material.applyShadow, false);
    assert.deepEqual(Object.keys(selected.material.lightEffect), []);
    assert.equal(selected.shadow.radius, 4);
    assert.equal(selected.shadow.color, dark ? '#30000000' : '#18000000');
    host.immersiveLightMode = 'off';
    const off = host.render(kind);
    assert.equal(off.material, h.empty); assert.equal(off.shadow.radius, 0);
    host.immersiveLightMode = mode;
    assert.notEqual(host.render(kind).material, h.empty, 'Changing mode restores material on retained selection');
    host.click0(kind);
    assert.equal(host.hubSelected(kind), false);
    assert.equal(host.render(kind).material.materialColor, undefined, 'Deselection removes the accent tint');
    assert.equal(host.requests, 2);
  }
}
for (const kind of kinds) {
  const h = boot(26, false);
  h.host.click0(kind);
  assert.equal(h.host.render(kind).material, h.empty);
  assert.equal(h.host.render(kind).shadow.radius, 0);
  assert.equal(h.colors(), 0, 'Unsupported devices do not resolve tint');
}
const failed = boot(26, true, true);
failed.host.click0('favorite');
assert.equal(failed.host.render('favorite').material.materialColor, 'app.color.detail_save_accent');
for (const index of [0, 1]) {
  for (const kind of kinds) {
    const { host } = boot(26);
    host.interactionReady = false; host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), false); assert.equal(host.requests, 0);
    host.interactionReady = true; host.profile.suggestionWriting = true; host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), false); assert.equal(host.requests, 0);
    host.profile.suggestionWriting = false; host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), true); assert.equal(host.requests, 1);
    host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), false); assert.equal(host.requests, 2);
  }
}
const pins = boot(26).host;
pins.click0('favorite'); pins.click0('created');
assert(pins.favoriteFilter && pins.createdFilter, 'Favorite and created filters may be combined');
for (const kind of ['groups', 'secret', 'following']) {
  pins.click0(kind); assert.equal(pins.boardFilter, kind);
}
pins.click0('collage-drafts'); pins.click0('collage-created');
assert(pins.collageCreated && !pins.collageDrafts, 'Collage modes remain mutually exclusive');
const filters = method('hubFilters').getText(ast);
for (const kind of kinds) assert(filters.includes(`,'${kind}')`), `Missing filter entry: ${kind}`);
console.log('Profile filter material passed: seven kinds, selected/unselected tint, four modes, theme colors, off/reset, capability fallback, API 24/25 gates, click guards and filter combinations.');
