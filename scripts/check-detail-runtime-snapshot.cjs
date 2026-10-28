const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const ast = ts.createSourceFile('page.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const methods = [];
function visit(node) {
  assert(!ts.isGetAccessor(node), 'V1 detail component must not depend on getters discarded by ArkUI');
  if (ts.isMethodDeclaration(node) && ['displayedDetail', 'fallbackDetail', 'immersiveLightEnabled'].includes(node.name.getText(ast))) methods.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast);
assert.equal(methods.length, 3);
assert(!/this\.detail\b/.test(source), 'every detail read must use the explicit snapshot method');
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', { compilerOptions: { target: 99 } }).outputText);
const host = new Host();
assert.equal(host.displayedDetail().kind, 'loading', 'absent transitional snapshot remains renderable');
assert.equal(host.displayedDetail().actions.length, 0);
const normal = { pinUrl: 'normal', imageWidth: 100, actions: [] };
host.currentDetail = normal;
assert.equal(host.displayedDetail(), normal, 'ordinary Pin uses its own snapshot');
const parent = { pinUrl: 'parent', shuffle: { items: [] } };
host.shuffleParentDetail = parent;
assert.equal(host.displayedDetail(), parent, 'collage remains mounted while a child loads');
host.shuffleFullDetail = true;
assert.equal(host.displayedDetail(), normal, 'full child detail replaces the collage presentation');
host.immersiveLightMode = 'off'; assert.equal(host.immersiveLightEnabled(), false);
host.immersiveLightMode = 'immersive'; assert.equal(host.immersiveLightEnabled(), true);
if (process.argv[3]) {
  const compiled = fs.readFileSync(process.argv[3], 'utf8');
  assert(/displayedDetail\(\)/.test(compiled));
  assert(/return current \|\| this.shuffleParentDetail \|\| this.fallbackDetail\(\)/.test(compiled), 'compiled snapshot method retains its fallback');
  assert(/immersiveLightEnabled\(\).*return this.immersiveLightMode/s.test(compiled));
  assert(!/this\.detail\b/.test(compiled), 'compiled UI never reads the missing getter');
}
console.log('Detail runtime snapshot: normal Pin, transition, collage, full child and compiled method guards passed');
