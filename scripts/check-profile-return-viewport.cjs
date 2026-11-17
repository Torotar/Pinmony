const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = process.argv[3] || '.';
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const page = read('feature_profile/src/main/ets/components/PinmonyProfilePage.ets');
const entry = read('entry/src/main/ets/pages/Index.ets');
const bridge = read('entry/src/main/ets/components/PinmonyProfileRootContent.ets');
const ast = ts.createSourceFile('profile.ts', page.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && ['profileBodyHeight', 'updateProfileViewport'].includes(node.name.getText(ast))) methods.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast);
assert.equal(methods.length, 2);
const Host = vm.runInNewContext(ts.transpileModule(
  'const PinmonyRuntimeLog={info(){}};class Host{' + methods.join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const make = () => Object.assign(new Host(), {
  profile: { isOwn: true }, onBack: undefined, hubPane: false, legacyContentPane: false,
  profileViewportHeight: 0, rootViewportHeightVp: 817.1, legacyProfile: false
});
let host = make();
assert.equal(host.profileBodyHeight(), 817.1, 'recreated own profile must use retained tab height before its own area event');
for (let i = 0; i < 5; i++) {
  host = make();
  host.profile.isOwn = false;
  host.updateProfileViewport(817.1);
  assert.equal(host.profileViewportHeight, 0);
  assert.equal(host.profileBodyHeight(), '100%', 'visited profile keeps its native destination sizing');
  host.profile.isOwn = true;
  assert.equal(host.profileBodyHeight(), 817.1, 'restoring own snapshot must work without another area event');
}
for (const legacy of [true, false, true, false]) {
  host.legacyProfile = legacy;
  for (const height of [480, 900, 650]) {
    host.rootViewportHeightVp = height;
    host.profileViewportHeight = 817.1;
    assert.equal(host.profileBodyHeight(), height, 'live tab size wins over stale local height in both layouts');
  }
}
for (const field of ['onBack', 'hubPane', 'legacyContentPane']) {
  host[field] = true;
  assert.equal(host.profileBodyHeight(), '100%', field + ' must not inherit root sizing');
  host[field] = false;
}
for (const invalid of [0, -1, NaN, Infinity]) {
  host.rootViewportHeightVp = invalid;
  host.profileViewportHeight = 650;
  assert.equal(host.profileBodyHeight(), 650, 'standalone callers retain measured fallback');
  host.profileViewportHeight = 0;
  assert.equal(host.profileBodyHeight(), '100%');
}
assert(entry.includes('@State private profileRootViewportHeightVp: number = 0;'));
assert(entry.includes('rootViewportHeightVp: this.profileRootViewportHeightVp,'));
assert(bridge.includes('rootViewportHeightVp: number;'));
assert(bridge.includes('rootViewportHeightVp: view.rootViewportHeightVp,'));
assert(page.includes('@Prop rootViewportHeightVp: number = 0;'));
const start = entry.indexOf('this.buildProfileRootContent()');
const end = entry.indexOf('.onVisibleAreaChange', start);
const tabHost = entry.slice(start, end);
const callback = tabHost.match(/\.onAreaChange\((\(_old: Area, area: Area\): void => \{[\s\S]*?\n        \})\)/);
assert(callback, 'measurement belongs to persistent profile tab host outside conditional profile content');
const owner = { profileRootViewportHeightVp: 0 };
// Run the actual callback body with the tab owner as its receiver.
const measureOwner = vm.runInNewContext(ts.transpileModule(
  'const PinmonyRuntimeLog={info(){}};({measure(_old: Area, area: Area): void ' +
    callback[1].slice(callback[1].indexOf('{')) + '}).measure;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
for (const height of [817.1, 480, 900]) {
  measureOwner.call(owner, {}, { height });
  assert.equal(owner.profileRootViewportHeightVp, height, 'host updates while child is absent or covered');
}
for (const height of [0, -1, NaN, Infinity, 900.5]) {
  measureOwner.call(owner, {}, { height });
  assert.equal(owner.profileRootViewportHeightVp, 900, 'invalid/transient/duplicate sizes do not replace valid viewport');
}
console.log('Profile return viewport: retained host, snapshot restore, repeated visits, both layouts, resize, nested isolation and fallback passed.');
