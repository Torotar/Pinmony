const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const root = process.argv[3] || '.';
const files = [
  ['feature_pin/src/main/ets/components/PinmonyDetailHero.ets', 'this.onTap', 1],
  ['feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'this.onImageTap', 2]
];
for (const [file, callbackName, expected] of files) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct\b/g, 'class');
  const ast = ts.createSourceFile('photo.ts', source, ts.ScriptTarget.Latest, true);
  const bindings = [];
  function visit(node) {
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) &&
      node.expression.name.text === 'onClick' && node.arguments[0]?.getText(ast).includes(callbackName)) bindings.push(node);
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert.equal(bindings.length, expected, file + ': cover every viewer photo entry');
  for (const binding of bindings) {
    assert.equal(binding.arguments.length, 2, file + ': photo click requires explicit movement threshold');
    const limit = Number(binding.arguments[1].getText(ast));
    assert.ok(Number.isFinite(limit) && limit > 0 && limit <= 12, 'tap slop must remain below the 48vp sibling swipe threshold');
    const factory = vm.runInNewContext(ts.transpileModule('(function() { return (' + binding.arguments[0].getText(ast) + '); })', {
      compilerOptions: { target: ts.ScriptTarget.ES2021 }
    }).outputText, { item: { imageUrl: 'synthetic-image', video: undefined } });
    // Check the SDK onClick distance contract against the real bound callbacks.
    // This models dispatch; native gesture recognition still requires device testing.
    let opened = 0;
    const host = { isCurrent: () => true, onTap: () => opened++, onImageTap: () => opened++ };
    const callback = factory.call(host);
    const fire = (dx, dy) => { if (Math.hypot(dx, dy) <= limit) callback.call(host); };
    fire(0, 0); fire(3, 2);
    assert.equal(opened, 2, 'tap and minor finger jitter still open viewer');
    for (const [dx, dy] of [[-276, 0], [167, 0], [-48, 0], [48, 0], [0, 100], [35, 35]]) fire(dx, dy);
    assert.equal(opened, 2, 'both sibling directions, carousel drags, vertical and diagonal drags cannot click');
    fire(0, 0);
    assert.equal(opened, 3, 'a subsequent real tap is not suppressed by a stale timer');
    if (callbackName === 'this.onTap') {
      host.isCurrent = () => false; fire(0, 0);
      assert.equal(opened, 3, 'retired hero cannot open viewer');
    }
  }
}
console.log('Detail photo taps: single hero, standard carousel and product gallery have bounded click slop; tap callbacks and drag exclusion contracts passed (native device recognition not simulated)');
