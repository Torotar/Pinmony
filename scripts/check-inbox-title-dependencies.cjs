const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const path = 'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/feature_inbox/src/main/ets/components/PinmonyInboxPage.ts';
const generated = fs.readFileSync(path, 'utf8');
function method(name) {
  const start = generated.indexOf('    private ' + name + '(');
  assert(start >= 0, name);
  return generated.slice(start, generated.indexOf('\n    }', start) + 6);
}
const start = generated.indexOf('            HdsNavigation.create(');
const end = generated.indexOf('\n        }, HdsNavigation);', start);
assert(start >= 0 && end > start, 'inspect the actual compiled HDS update callback');
const bindingMethod = generated.includes('private titleContentScroller(') ? 'titleContentScroller' :
  generated.includes('HdsNavigation.bindToScrollable([this.activeContentScroller()])') ? 'activeContentScroller' : '';
const hostCode = 'class Host {' + method('inboxTitleBarOptions') + '\n' +
  (bindingMethod ? method(bindingMethod) : '') +
  '\n updateTitle() {' + generated.slice(start, end) + '\n} } Host;';
let configured = 0, bound;
const navigation = new Proxy({}, {get: (_object, key) => (...args) => {
  if (key === 'titleBar') configured++;
  if (key === 'bindToScrollable') bound = args[0];
}});
const Host = vm.runInNewContext(ts.transpileModule(hostCode, {compilerOptions: {target: ts.ScriptTarget.ES2021}}).outputText, {
  HdsNavigation: navigation, NavPathStack: class {}, HdsNavigationTitleMode: {MINI: 0},
  LayoutSafeAreaType: {SYSTEM: 0}, LayoutSafeAreaEdge: {TOP: 0},
  BlurStrategy: {ENABLE: 1, DISABLE: 0}, ScrollEffectType: {IMMERSIVE_GRADIENT_BLUR: 1},
  PinmonyImmersiveLight: {effect: mode => mode}, PinmonyHdsTitleBar: {resolve: (_ctx, options) => options}
});
const host = new Host(), reads = new Set();
const state = {snapshot: {section: 'updates', items: []}, segmentSelectedIndex: 0,
  immersiveLightMode: 'immersive', systemDarkMode: false, hdsDarkMode: false};
for (const key of Object.keys(state)) Object.defineProperty(host, key, {
  get() {reads.add(key); return state[key];}, set(value) {state[key] = value;}
});
Object.assign(host, {updatesScroller: {}, scroller: {}, inboxSegmentsBuilder: () => {}, getUIContext: () => ({})});
host.updateTitle();
assert(!reads.has('snapshot'), 'content snapshot must not subscribe the HDS title update node: ' + [...reads]);
assert(!reads.has('segmentSelectedIndex'), 'switching sections must not reconstruct the title containing the selection animation');
assert.equal(bound.length, 2); assert.equal(bound[0], host.updatesScroller); assert.equal(bound[1], host.scroller);
const dependencies = new Set(reads);
for (let i = 0; i < 100; i++) {
  state.snapshot = {...state.snapshot, items: [{unread: i % 2 === 0}], moreLoading: i % 3 === 0};
  if (dependencies.has('snapshot')) host.updateTitle();
}
assert.equal(configured, 1, 'content polling must not reconfigure the HDS title');
for (const selectedIndex of [1, 0, 1, 0]) {
  state.segmentSelectedIndex = selectedIndex;
  if (dependencies.has('segmentSelectedIndex')) host.updateTitle();
}
assert.equal(configured, 1, 'section switching must only update segment selection and body, not the HDS title');
for (const mode of ['gentle', 'exquisite', 'off', 'immersive']) {state.immersiveLightMode = mode; host.updateTitle();}
state.systemDarkMode = true; state.hdsDarkMode = true; host.updateTitle();
assert.equal(configured, 6, 'material/theme changes remain reactive');
console.log('Compiled inbox title: no snapshot/selection subscription, polling and switch isolation, both stable scroll bindings and material/theme updates passed');
