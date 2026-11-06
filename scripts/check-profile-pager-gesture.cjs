const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
let method;
function visit(node) {
  if (ts.isMethodDeclaration(node) && node.name.getText(ast) === 'judgeHubSwipe') method = node.getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast); assert(method);
class PanRecognizer {
  constructor(direction = 'horizontal', builtIn = true) { this.direction = direction; this.builtIn = builtIn; }
  isBuiltIn() { return this.builtIn; }
  getDirection() { return this.direction; }
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { PinmonyRuntimeLog: { info() {} }, PanRecognizer, PanDirection: { Horizontal: 'horizontal' }, GestureJudgeResult: { CONTINUE: 0, REJECT: 1 } });
const host = new Host();
for (const [x, y, reject] of [[3,20,true],[20,3,false],[20,20,true],[-20,3,false],[3,-20,true],[-3,-20,true],[0,20,true],[20,0,false],[0,0,false],[NaN,2,false],[2,NaN,false]]) {
  assert.equal(host.judgeHubSwipe({offsetX:x,offsetY:y},new PanRecognizer()),reject ? 1 : 0);
}
for (const recognizer of [new PanRecognizer('vertical'),new PanRecognizer('horizontal',false),{}]) {
  assert.equal(host.judgeHubSwipe({offsetX:2,offsetY:20},recognizer),0,'only the built-in horizontal pager is judged');
}
assert.match(source,/\.onGestureRecognizerJudgeBegin\([\s\S]*?return this\.judgeHubSwipe\(event, current\)/);
console.log('Profile pager: horizontal intent, diagonal/vertical rejection, reverse direction and child recognizer isolation passed');
