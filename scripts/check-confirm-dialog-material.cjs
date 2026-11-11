const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets', 'utf8');
const ast = ts.createSourceFile('material.ts', source, ts.ScriptTarget.Latest, true);
let method;
function visit(n) { if (ts.isMethodDeclaration(n) && n.name.getText(ast) === 'alertOptions') method = n.getText(ast); ts.forEachChild(n, visit); }
visit(ast); assert(method);
for (const api26 of [false, true]) for (const supported of [false, true]) {
  let mode = 'off'; const empty = {}, effects = [];
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
    deviceInfo: { apiAvailable: () => api26 }, AppStorage: { get: () => mode },
    uiMaterial: { Material: { empty }, ImmersiveStyle: { THICK: 3, REGULAR: 2 }, isImmersiveMaterialSupported: () => supported,
      ImmersiveMaterial: class { constructor(options) { effects.push(options); } } }
  });
  for (const nextMode of ['off', 'gentle', 'immersive', 'exquisite', 'off']) {
    mode = nextMode; let confirmed = 0, cancelled = 0;
    const primaryButton = { value: 'cancel', action: () => { cancelled++; } }, secondaryButton = { value: 'confirm', action: () => { confirmed++; } };
    const options = { title: 'title', message: 'message', primaryButton, secondaryButton, cancel: () => { cancelled++; } };
    assert.equal(Host.alertOptions(options), options);
    assert.equal(options.primaryButton, primaryButton); assert.equal(options.secondaryButton, secondaryButton);
    options.primaryButton.action(); options.secondaryButton.action(); options.cancel();
    assert.equal(confirmed, 1); assert.equal(cancelled, 2);
    if (!api26) assert(!Object.hasOwn(options, 'systemMaterial'));
    else if (!supported || mode === 'off') assert.equal(options.systemMaterial, empty);
    else { assert.equal(effects.at(-1).style, mode === 'gentle' ? 3 : 2); assert.equal(effects.at(-1).applyShadow, true); }
  }
}
let count = 0;
for (const root of ['feature_settings', 'feature_inbox', 'feature_board', 'feature_pin', 'feature_profile', 'feature_search', 'feature_home', 'entry', 'common_ui']) {
  function walk(dir) { for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name); if (f.isDirectory()) walk(p); else if (p.endsWith('.ets')) {
      const s = fs.readFileSync(p, 'utf8');
      const calls = s.match(/showAlertDialog\(/g) || [], wrapped = s.match(/showAlertDialog\(PinmonyImmersiveLight\.alertOptions\(/g) || [];
      assert.equal(wrapped.length, calls.length, p + ' confirmation dialog must use the common material options'); count += calls.length;
    }
  } } walk(root + '/src');
}
assert.equal(count, 18);
console.log('Confirm dialog material: 18 entries, API24 isolation, mode changes, capabilities and unchanged callbacks passed');
