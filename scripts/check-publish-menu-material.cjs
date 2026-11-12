const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'common_ui/src/main/ets/components/PinmonyDraggablePublishButton.ets';
const source = fs.readFileSync(file, 'utf8');
const compiled = process.argv.includes('--compiled');
const input = compiled ? fs.readFileSync('entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/common_ui/src/main/ets/components/PinmonyDraggablePublishButton.ts', 'utf8') : source;
const ast = ts.createSourceFile(file, input.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const methods = new Map(); let versionHelper = '';
function visit(node) {
  if (ts.isMethodDeclaration(node) && node.name) methods.set(node.name.getText(ast), node.getText(ast));
  if (ts.isFunctionDeclaration(node) && node.name?.text === '__mockApiAvailable') versionHelper = node.getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast);
const names = ['sourceMenuOptions', 'finishMenuClose', 'selectMenuItem', 'boundMenuItems', 'syncMenuAvailability', 'aboutToDisappear'];
for (const name of names) assert(methods.has(name), `Missing menu method: ${name}`);
assert(source.includes("@StorageLink('immersiveLightMode')"), 'Retained menus follow the current global material setting');
const build = source.slice(source.indexOf('  build()'));
assert(build.includes('.bindMenu(this.menuEnabled && this.menuOpen,this.boundMenuItems(),this.sourceMenuOptions())'));
assert(build.includes(".backgroundEffect({radius:20,saturation:1,brightness:1,color:$r('app.color.publish_button_glass')})"));
assert(!/systemMaterial|immersiveLightMode/.test(build), 'Floating button appearance remains independent from menu material');
function boot(api, mode = 'immersive', supported = true, fail = false) {
  let probes = 0;
  const empty = Symbol('empty');
  const Host = vm.runInNewContext(ts.transpileModule(versionHelper + '\nclass Host {' + names.map(name => methods.get(name)).join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, {
    deviceInfo: { distributionOSApiVersion: api * 10000, apiAvailable: version => { assert.equal(version, '26.0.0'); return api >= 26; } },
    uiMaterial: { Material: { empty }, ImmersiveStyle: { THICK: 3, REGULAR: 2 },
      isImmersiveMaterialSupported() { probes++; assert(api >= 26); if (fail) throw Error('lookup failed'); return supported; },
      ImmersiveMaterial: class { constructor(options) { assert(api >= 26); Object.assign(this, options); } } },
    $r: key => key, Color: { Transparent: 'transparent' }, BlurStyle: { NONE: 0, COMPONENT_ULTRA_THICK: 1 },
    PinmonyRuntimeLog: { info() {} }
  });
  const host = new Host();
  Object.assign(host, { immersiveLightMode: mode, mounted: true, menuEnabled: true, actionEnabled: true, menuOpen: true });
  return { host, empty, probes: () => probes };
}
function ordinary(options) {
  assert.equal(options.backgroundBlurStyle, 1);
  if (compiled) { assert.equal(options.backgroundColor.type, 10001); assert(options.backgroundColor.id > 0); }
  else assert.equal(options.backgroundColor, 'app.color.publish_source_button_glass');
}
for (const api of [24, 25, 26]) for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
  const h = boot(api, mode), options = h.host.sourceMenuOptions();
  if (api < 26) {
    assert(!Object.hasOwn(options, 'systemMaterial'), 'Old systems receive no API 26 option');
    assert.equal(h.probes(), 0); ordinary(options);
  } else if (mode === 'off') {
    assert.equal(options.systemMaterial, h.empty); assert.equal(h.probes(), 0); ordinary(options);
  } else {
    assert.equal(options.systemMaterial.style, mode === 'gentle' ? 3 : 2);
    assert.equal(options.systemMaterial.colorInvert, false);
    assert.equal(options.systemMaterial.applyShadow, true);
    assert.equal(options.systemMaterial.interactive, true);
    if (compiled) {
      assert.equal(options.systemMaterial.lightEffect.color.type, 10001);
      assert(options.systemMaterial.lightEffect.color.id > 0);
    } else assert.equal(options.systemMaterial.lightEffect.color, 'app.color.immersive_interaction_light');
    assert.equal(options.backgroundColor, 'transparent');
    assert.equal(options.backgroundBlurStyle, 0, 'The menu uses material blur without stacking the old blur');
  }
  assert.equal(h.host.menuOpen, true, 'Appearance updates cannot dismiss or reopen the menu');
  const next = h.host.sourceMenuOptions();
  assert.notEqual(next, options, 'Bindings own separate menu option objects');
  if (api === 26 && mode !== 'off') assert.notEqual(next.systemMaterial, options.systemMaterial);
}
for (const [supported, fail] of [[false, false], [true, true]]) {
  const h = boot(26, 'immersive', supported, fail), options = h.host.sourceMenuOptions();
  assert.equal(options.systemMaterial, h.empty); ordinary(options);
}
const noMenu = boot(26);
noMenu.host.menuEnabled = false;
const noMenuOptions = noMenu.host.sourceMenuOptions();
assert(!Object.hasOwn(noMenuOptions, 'systemMaterial'));
assert.equal(noMenu.probes(), 0, 'Board callers without a source menu never query new material support');
ordinary(noMenuOptions);
const h = boot(26);
const original = h.host.sourceMenuOptions();
h.host.immersiveLightMode = 'off';
const off = h.host.sourceMenuOptions();
assert.equal(off.systemMaterial, h.empty); ordinary(off);
assert.notEqual(original.systemMaterial, h.empty, 'Previously returned options are not mutated');
h.host.immersiveLightMode = 'gentle';
assert.equal(h.host.sourceMenuOptions().systemMaterial.style, 3);
let dispatched = 0;
h.host.selectMenuItem({ value: 'website', action: () => { dispatched++; } });
assert.equal(h.host.menuOpen, false); assert.equal(dispatched, 0, 'Navigation waits until native menu closes');
original.onAppear(); original.onDisappear(); original.onDisappear();
assert.equal(dispatched, 1, 'Material options retain close-before-navigation and single dispatch');
for (const cancel of [host => { host.actionEnabled = false; host.syncMenuAvailability(); }, host => { host.menuEnabled = false; host.syncMenuAvailability(); }, host => host.aboutToDisappear()]) {
  const h = boot(26), options = h.host.sourceMenuOptions();
  h.host.selectMenuItem({ value: 'photo', action: () => { dispatched++; } });
  cancel(h.host); options.onDisappear();
  assert.equal(dispatched, 1, 'Disabled, hidden or disposed menus cancel pending actions');
}
console.log(`Publish menu material${compiled ? ' (compiled)' : ''} passed: API 24/25/26, four modes, capability failure, live off/reset, independent instances, unchanged button and guarded close-before-navigation.`);
