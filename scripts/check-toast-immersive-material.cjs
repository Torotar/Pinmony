const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets', 'utf8');
const ast = ts.createSourceFile('material.ts', source, ts.ScriptTarget.Latest, true);
let method;
function find(node) {
  if (ts.isMethodDeclaration(node) && node.name.getText(ast) === 'toastOptions') method = node.getText(ast);
  ts.forEachChild(node, find);
}
find(ast);
assert(method, 'Toast must use the common material adapter');
for (const api26 of [false, true]) for (const supported of [false, true]) {
  let mode;
  let capabilityCalls = 0;
  let preferenceCalls = 0;
  const empty = {};
  const effects = [];
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, {
    deviceInfo: { apiAvailable(version) { assert.equal(version, '26.0.0'); return api26; } },
    AppStorage: { get(key) { assert.equal(key, 'immersiveLightMode'); preferenceCalls++; return mode; } },
    uiMaterial: {
      Material: { empty }, ImmersiveStyle: { THICK: 3 },
      isImmersiveMaterialSupported() { capabilityCalls++; assert(api26); return supported; },
      ImmersiveMaterial: class { constructor(options) { assert(api26 && supported); effects.push(options); this.options = options; } }
    }
  });
  // Read live settings on every display, including a default and an on/off round trip.
  for (const nextMode of [undefined, 'off', 'gentle', 'immersive', 'exquisite', 'off', 'immersive']) {
    mode = nextMode;
    const options = { message: '中文 / English', duration: 3000, bottom: 48, alignment: 1, offset: { dx: 2, dy: 3 } };
    const offset = options.offset;
    const before = JSON.stringify(options);
    const queriesBefore = capabilityCalls;
    const effectCount = effects.length;
    assert.equal(Host.toastOptions(options), options);
    assert.equal(options.offset, offset);
    const { systemMaterial, ...originalFields } = options;
    assert.equal(JSON.stringify(originalFields), before, 'message, duration, placement and other options are retained');
    if (!api26) {
      assert(!Object.hasOwn(options, 'systemMaterial'), 'API24 never accesses API26 material');
      assert.equal(preferenceCalls, 0);
      assert.equal(capabilityCalls, 0);
    } else if (nextMode === 'off' || !supported) {
      assert.equal(systemMaterial, empty, 'off/unsupported uses the official empty material');
      assert.equal(effects.length, effectCount);
      if (nextMode === 'off') assert.equal(capabilityCalls, queriesBefore, 'off bypasses capability lookup');
    } else {
      assert.equal(systemMaterial.options.style, 3, 'Toast retains the official THICK material');
      assert.equal(systemMaterial.options.colorInvert, false);
      assert.equal(systemMaterial.options.applyShadow, true);
    }
  }
  const defaultOptions = { message: 'default duration' };
  Host.toastOptions(defaultOptions);
  assert(!Object.hasOwn(defaultOptions, 'duration'), 'system default duration remains unchanged');
}
let entries = 0;
function walk(dir) {
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, item.name);
    if (item.isDirectory()) { if (!['build', 'oh_modules'].includes(item.name)) walk(file); }
    else if (file.endsWith('.ets')) {
      const text = fs.readFileSync(file, 'utf8');
      const calls = text.match(/\.showToast\(/g) || [];
      const wrapped = text.match(/\.showToast\(PinmonyImmersiveLight\.toastOptions\(/g) || [];
      assert.equal(wrapped.length, calls.length, file + ': every Toast must follow the shared setting');
      entries += calls.length;
    }
  }
}
for (const root of fs.readdirSync('.')) {
  if (root === 'entry' || root === 'common_ui' || root.startsWith('feature_')) {
    if (fs.existsSync(path.join(root, 'src'))) walk(path.join(root, 'src'));
  }
}
assert.equal(entries, 8, 'audit all current Toast callers');
console.log('Toast material: 8 entries, API24 isolation, official THICK, capability fallback, live switch and original options passed');
