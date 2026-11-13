const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets', 'utf8');
const ast = ts.createSourceFile('material.ts', source, 99, true);
let method;
function visit(node) {
  if (ts.isMethodDeclaration(node) && node.name.getText(ast) === 'effect') method = node.getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast); assert(method);
for (const api of [24, 25, 26]) for (const modern of [true, false, 'error']) {
  for (const hds of [true, false, 'error']) for (const gate of [true, false]) {
    let probes = 0, hdsProbes = 0;
    const Host = vm.runInNewContext(ts.transpileModule(`class Host {${method}} Host;`, {
      compilerOptions: { target: ts.ScriptTarget.ES2021 }
    }).outputText, {
      deviceInfo: gate ? { apiAvailable(version) { assert.equal(version, '26.0.0'); return api >= 26; } } : {},
      uiMaterial: { isImmersiveMaterialSupported() {
        assert(api >= 26 && gate, 'old runtime must not access the new API'); probes++;
        if (modern === 'error') throw Error('unavailable'); return modern;
      } },
      hdsMaterial: { MaterialType: { ADAPTIVE: 'adaptive', IMMERSIVE: 'immersive' },
        MaterialLevel: { SMOOTH: 'smooth', GENTLE: 'gentle', EXQUISITE: 'exquisite' },
        getSystemMaterialTypes() { hdsProbes++; if (hds === 'error') throw Error('unavailable'); return hds ? ['immersive'] : []; } }
    });
    for (const mode of ['off', 'gentle', 'immersive', 'exquisite', 'off', 'immersive']) {
      const before = [probes, hdsProbes];
      const result = Host.effect(mode);
      if (mode === 'off') { assert.equal(result, undefined); assert.deepEqual([probes,hdsProbes],before); continue; }
      if (mode === 'gentle') { assert.equal(result.materialType, 'adaptive'); assert.equal(result.materialLevel, 'smooth'); assert.deepEqual([probes,hdsProbes],before); continue; }
      const api26 = api >= 26 && gate;
      const active = hds === true && (!api26 || modern === true);
      assert.equal(result.materialType, active ? 'immersive' : 'adaptive');
      assert.equal(result.materialLevel, api26 && !active ? 'smooth' : mode === 'exquisite' ? 'exquisite' : 'gentle');
      assert.deepEqual(Object.keys(result).sort(), ['materialLevel','materialType']);
    }
    if (api < 26 || !gate) assert.equal(probes, 0);
  }
}
let callers = 0;
function walk(dir) {
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, item.name);
    if (item.isDirectory()) walk(file);
    else if (file.endsWith('.ets')) {
      const text = fs.readFileSync(file, 'utf8');
      if (text.includes('PinmonyImmersiveLight.effect(')) callers++;
    }
  }
}
for (const root of fs.readdirSync('.').filter(name => /^(feature_|entry$|common_ui$)/.test(name))) walk(path.join(root,'src'));
assert(callers >= 20);
for (const file of ['entry/src/main/ets/pages/Index.ets','feature_board/src/main/ets/components/PinmonyBoardPage.ets']) {
  const text = fs.readFileSync(file,'utf8');
  assert(text.includes('systemMaterialEffect:') && text.includes('PinmonyImmersiveLight.effect(this.immersiveLightMode)'));
  assert(!text.includes('.systemMaterial('), 'do not apply material to the full page');
}
console.log(`HDS API26: API24/25/26, missing gate, capability failures, four modes and live switches passed; ${callers} shared callers. Device appearance unverified.`);
