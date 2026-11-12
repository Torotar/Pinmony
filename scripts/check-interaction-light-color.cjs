const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const key = 'immersive_interaction_light';
const colors = {};
for (const theme of ['base', 'dark']) {
  const entries = JSON.parse(fs.readFileSync(`common_ui/src/main/resources/${theme}/element/color.json`, 'utf8')).color;
  assert.equal(entries.filter(item => item.name === key).length, 1, `${theme}: exactly one shared light color`);
  const value = entries.find(item => item.name === key).value;
  assert(/^#[0-9A-F]{6}$/i.test(value));
  const rgb = value.slice(1).match(/../g).map(v => parseInt(v, 16));
  assert(rgb[0] > rgb[1] && rgb[0] > rgb[2], `${theme}: red light`);
  const saturation = (Math.max(...rgb) - Math.min(...rgb)) / Math.max(...rgb);
  assert(saturation > 0.15 && saturation < 0.5, `${theme}: restrained saturation`);
  colors[theme] = rgb;
}
assert(colors.dark.reduce((a,b) => a+b, 0) > colors.base.reduce((a,b) => a+b, 0), 'Dark mode uses a softer, brighter rose');
const controls = [];
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith('.ets')) {
      const source = fs.readFileSync(file, 'utf8');
      if (!source.includes('new uiMaterial.ImmersiveMaterial')) continue;
      const ast = ts.createSourceFile(file, source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
      function visit(node) {
        if (ts.isNewExpression(node) && node.expression.getText(ast) === 'uiMaterial.ImmersiveMaterial') {
          const options = node.arguments?.[0];
          assert(options && ts.isObjectLiteralExpression(options), `${file}: inspect actual material options`);
          const interactive = options.properties.find(p => p.name?.getText(ast) === 'interactive');
          if (interactive?.initializer?.kind === ts.SyntaxKind.TrueKeyword) {
            const light = options.properties.find(p => p.name?.getText(ast) === 'lightEffect');
            assert(light?.initializer?.getText(ast).includes("$r('app.color.immersive_interaction_light')"), `${file}: interactive material must use shared theme light`);
            controls.push(file);
          }
        }
        ts.forEachChild(node, visit);
      }
      visit(ast);
    }
  }
}
for (const dir of fs.readdirSync('.').filter(p => /^(entry|common_ui|feature_.*)$/.test(p))) walk(path.join(dir, 'src/main/ets'));
assert(controls.length >= 8, 'Cover all existing interactive materials including Inbox and Following');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(/\.barFloatingStyle\(\{\s*barBottomMargin: 28,\s*lightColor: \$r\('app.color.immersive_interaction_light'\),\s*systemMaterialEffect: PinmonyImmersiveLight.effect\(this.immersiveLightMode\)/.test(index), 'Shared four-tab HDS bar uses supported lightColor while retaining material switch and spacing');
console.log(`Interaction light: ${controls.length} interactive materials and shared four-tab bar, unique theme resources, restrained red saturation and dark-mode brightness passed.`);
// Exercise the actual Inbox helper across legacy runtimes and capability/mode changes.
const vm = require('node:vm');
const inboxSource = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxSegmentMaterial.ets', 'utf8');
for (const api of [24, 25, 26]) for (const supported of [false, true]) {
  const exports = {}, empty = Symbol('empty'); let probes = 0;
  vm.runInNewContext(ts.transpileModule(inboxSource.replace(/^import .*;\r?\n/gm, ''), {
    compilerOptions: {target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS}
  }).outputText, {exports, $r: name => name, deviceInfo: {apiAvailable: () => api >= 26}, uiMaterial: {
    Material: {empty}, ImmersiveStyle: {THICK: 3, REGULAR: 2},
    isImmersiveMaterialSupported() { probes++; return supported; },
    ImmersiveMaterial: class {constructor(options) {Object.assign(this, options);}}
  }});
  for (const mode of ['off', 'gentle', 'immersive', 'exquisite', 'off']) {
    const result = exports.PinmonyInboxSegmentMaterial.create(mode);
    if (api < 26) assert.equal(result, undefined);
    else if (mode === 'off' || !supported) assert.equal(result, empty);
    else {
      assert.equal(result.lightEffect.color, 'app.color.immersive_interaction_light');
      assert.equal(result.interactive, true); assert.equal(result.applyShadow, false);
      assert.equal(result.style, mode === 'gentle' ? 3 : 2);
    }
  }
  if (api < 26) assert.equal(probes, 0, 'Legacy runtime never probes the new material API');
}
console.log('Inbox interaction light: API24/25/26, supported/unsupported, four modes and off/reset passed.');