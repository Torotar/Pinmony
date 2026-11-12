const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const BlurStyle = { COMPONENT_ULTRA_THICK: 6 };
const BlurStrategy = { ENABLE: 1 };
const lifecycle = require('./snackbar-lifecycle-harness.cjs').loadSnackBarLifecycle(ts, { warn() {} });

for (const duration of [0, 4000]) for (const themeColorMode of [undefined, 'light', 'dark']) {
  let shown;
  let actions = 0;
  let backs = 0;
  let closes = 0;
  const icon = { icon: 'icon' };
  const message = { title: '中文 / English' };
  const operation = { content: 'undo', onContentClick() { actions++; }, onCloseButtonClick() { closes++; } };
  const theme = {};
  const style = { duration, themeColorMode, theme, keyboardDownAvoidHeight: 24, pressBackCallback() { backs++; } };
  const snack = { show(...args) { shown = args; }, dismiss() {} };
  lifecycle.show(snack, icon, message, operation, style);
  assert.equal(shown[0], icon);
  assert.equal(shown[1], message);
  assert.equal(shown[2], operation);
  assert.equal(shown[3], style);
  assert.equal(style.backgroundBlurStyle, BlurStyle.COMPONENT_ULTRA_THICK);
  assert.equal(style.blurStrategy, BlurStrategy.ENABLE);
  assert.equal(style.duration, duration);
  assert.equal(style.themeColorMode, themeColorMode);
  assert.equal(style.theme, theme);
  assert.equal(style.keyboardDownAvoidHeight, 24);
  assert(!Object.hasOwn(style, 'backgroundColor'), 'retain the official theme-aware background color');
  assert(!Object.hasOwn(style, 'systemMaterial'), 'do not invent an unsupported HDS material field');
  operation.onContentClick();
  assert.equal(actions, 1);
  style.pressBackCallback();
  assert.equal(backs, 1);
  operation.onCloseButtonClick();
  assert.equal(closes, 0, 'native close after back cannot trigger a second callback');
}

let direct = 0;
let shared = 0;
let constructors = 0;
function check(file) {
  const source = fs.readFileSync(file, 'utf8');
  constructors += (source.match(/new HdsSnackBar\(/g) || []).length;
  shared += (source.match(/PinmonySnackBarLifecycle\.show\(/g) || []).length;
  const ast = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true);
  function visit(node) {
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) &&
        /this\.(savedSnack|errorSnack)\.show/.test(node.expression.getText(ast))) {
      const style = node.arguments[3];
      assert(style && ts.isObjectLiteralExpression(style), file + ': explicit official style options');
      const result = vm.runInNewContext(ts.transpileModule('const style = ' + style.getText(ast) + '; style;', {
        compilerOptions: { target: ts.ScriptTarget.ES2021 }
      }).outputText, { BlurStyle, BlurStrategy });
      assert.equal(result.backgroundBlurStyle, BlurStyle.COMPONENT_ULTRA_THICK, file);
      assert.equal(result.blurStrategy, BlurStrategy.ENABLE, file);
      assert.equal(result.duration, 4000, file + ': preserve existing timed dismissal');
      assert(!Object.hasOwn(result, 'backgroundColor'), file + ': retain official theme background');
      assert(!Object.hasOwn(result, 'systemMaterial'), file + ': only supported HDS options');
      direct++;
    }
    ts.forEachChild(node, visit);
  }
  visit(ast);
}
function walk(dir) {
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, item.name);
    if (item.isDirectory()) { if (!['build', 'oh_modules'].includes(item.name)) walk(file); }
    else if (file.endsWith('.ets')) check(file);
  }
}
for (const root of fs.readdirSync('.')) {
  if ((root === 'entry' || root === 'common_ui' || root.startsWith('feature_')) && fs.existsSync(path.join(root, 'src'))) {
    walk(path.join(root, 'src'));
  }
}
assert.equal(constructors, 7, 'audit every official snackbar owner');
assert.equal(direct, 5, 'board saved feedback and four settings error callers');
assert.equal(shared, 10, 'common action notice plus nine Index action entry points');
console.log('Snackbar background blur: 7 owners, 15 show sites, official blur options, theme preservation, timed/persistent notices and action/back callbacks passed');
