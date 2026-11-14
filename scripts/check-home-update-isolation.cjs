const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = process.argv[3] || '.';
const read = path => fs.readFileSync(root + '/' + path, 'utf8');
const compile = (code, env = {}) => vm.runInNewContext(ts.transpileModule(code, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, env);
const storeSource = read('feature_home/src/main/ets/stores/PinmonyHomeStore.ets');
const Store = compile(storeSource.replace(/^import .*;\r?\n/gm, '').replace(/@Observed\s*/g, '')
  .replace(/export /g, '') + '\nPinmonyHomeStore;');
const store = new Store();
store.cachedHome = { pageKey: 'home', tabs: [{ id: 'all', selected: true }] };
let writes = 0;
const observed = new Proxy(store, { set(target, key, value) { writes++; target[key] = value; return true; } });
for (let i = 0; i < 240; i++) observed.rememberCategoryScroll('home', 'all', i * 9);
assert.equal(writes, 0, 'scroll bookkeeping must not write observed top-level state');
assert.equal(observed.cachedHomeScrollOffset, 2151);
assert.equal(observed.categoryScrollOffset('home', 'all'), 2151);
observed.rememberCategoryScroll('home', 'board', 321);
assert.equal(observed.cachedHomeScrollOffset, 2151, 'hidden category must not replace selected offset');
assert.equal(observed.categoryScrollOffset('home', 'board'), 321);
observed.rememberCategoryScroll('other', 'all', 123);
assert.equal(observed.cachedHomeScrollOffset, 2151, 'old page must not replace current offset');
for (const offset of [NaN, Infinity, -Infinity]) observed.rememberCategoryScroll('home', 'all', offset);
assert.equal(observed.cachedHomeScrollOffset, 2151);
observed.rememberCategoryScroll('home', 'all', -5);
assert.equal(observed.cachedHomeScrollOffset, 0);
observed.cachedHomeScrollOffset = 67;
assert.equal(observed.cachedHomeScrollOffset, 67, 'existing controller setter remains compatible');
const epoch = observed.homePresentationEpoch;
observed.clearCategoryPositions();
assert.equal(observed.cachedHomeScrollOffset, 0);
assert.equal(observed.categoryScrollOffset('home', 'board'), undefined);
assert.equal(observed.homePresentationEpoch, epoch + 1, 'explicit reset still invalidates presentation');

const page = read('feature_home/src/main/ets/components/PinmonyHomePage.ets');
const ast = ts.createSourceFile('page.ts', page.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const members = [];
const names = ['categoryTitleBuilder', 'cachedTitleBarMode', 'cachedTitleBarOptions', 'homeTitleBarOptions'];
function visit(node) {
  if ((ts.isMethodDeclaration(node) || ts.isPropertyDeclaration(node)) && names.includes(node.name?.getText(ast))) members.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast);
let effects = 0;
const Host = compile('class Host {' + members.join('\n') + '} Host;', {
  BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 3 },
  PinmonyImmersiveLight: { effect: mode => { effects++; return mode; } }
});
const host = new Host();
host.immersiveLightMode = 'immersive';
let label = '中文', drawn;
host.categoryButtons = () => { drawn = label; };
const original = host.homeTitleBarOptions();
for (let i = 0; i < 240; i++) assert.equal(host.homeTitleBarOptions(), original);
assert.equal(effects, 1, 'scroll must reuse title material/options');
original.content.stackBuilder(); assert.equal(drawn, '中文');
label = 'English'; original.content.stackBuilder(); assert.equal(drawn, 'English', 'stable builder reads current state');
host.systemDarkMode = true;
assert.equal(host.homeTitleBarOptions(), original, 'resource-backed title options remain valid across theme changes');
for (const mode of ['off', 'gentle', 'exquisite', 'immersive']) {
  host.immersiveLightMode = mode;
  const next = host.homeTitleBarOptions();
  assert.notEqual(next, original);
  assert.equal(next.style.thermoCtrl, mode !== 'off');
  assert.equal(next.content.stackBuilder, original.content.stackBuilder);
  assert.equal(host.homeTitleBarOptions(), next);
}
console.log('Home update isolation passed: scroll writes, category/page separation, invalid input, reset, compatible setter, stable title options and live builder.');
