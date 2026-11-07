const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { withLocalMessages } = require('./local-message-test-fixture.cjs');
function load(file, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText,
    { exports, require: withLocalMessages(deps), setTimeout, clearTimeout, console });
  return exports;
}
const avatarSource = fs.readFileSync('common_ui/src/main/ets/components/PinmonyUserAvatar.ets', 'utf8');
const ast = ts.createSourceFile('avatar.ts', avatarSource.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const methods = [];
function visit(node) { if (ts.isMethodDeclaration(node) && ['fallbackInitial', 'fallbackBackground', 'resetImage'].includes(node.name.getText(ast))) methods.push(node.getText(ast)); ts.forEachChild(node, visit); }
visit(ast);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, { $r: x => x });
const host = Object.assign(new Host(), { websiteFallback: true, systemDarkMode: false, colorIndex: 9, name: '  test  ', failed: true });
assert.equal(host.fallbackInitial(), 'T'); host.name = '😀 user'; assert.equal(host.fallbackInitial(), '😀'); host.name = ''; assert.equal(host.fallbackInitial(), '?');
assert.equal(host.fallbackBackground(), '#FFE0CC'); host.systemDarkMode = true; assert.equal(host.fallbackBackground(), '#5C2500');
for (const color of [undefined, null, 0, 11, -1, 1.5, '9', NaN]) { host.colorIndex = color; assert.equal(host.fallbackBackground(), 'app.color.surface_muted'); }
for (const dark of [true, false]) for (let color = 1; color <= 10; color++) { host.systemDarkMode = dark; host.colorIndex = color; assert.match(host.fallbackBackground(), /^#[0-9A-F]{6}$/); }
host.websiteFallback = false; assert.equal(host.fallbackBackground(), 'app.color.surface_muted'); host.resetImage(); assert.equal(host.failed, false);
assert(avatarSource.includes('!this.failed')); assert(avatarSource.includes('/user\\/default')); assert(avatarSource.includes('this.websiteFallback ? 0.4 : 0.48'));
const page = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
assert(!page.includes('Image(this.profile.avatarUrl)'));
assert.equal((page.match(/websiteFallback: true/g) || []).length, 5, 'modern, legacy and compact profile headers share the same avatar');
const { PinmonyProfileCache: Cache } = load('feature_profile/src/main/ets/services/PinmonyProfileCache.ets');
const { PinmonyProfileNativeReads: Reader } = load('entry/src/main/ets/app/PinmonyProfileNativeReads.ets', name => name === 'common_network' ? { PIN_BUSINESS_PIN_READ_ENABLED: true } : name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {} } } : {});
const origin = 'https://www.pinterest.com', url = origin + '/sample/';
async function main() {
  for (const color of [1, 9, 10, undefined, null, -1, 11, 1.5, '9']) {
    const store = { profileSession: 0, profileCache: new Cache(), origins: [] };
    const reader = new Reader({ store: () => store, session: () => ({ authenticated: true, generation: 1, accountId: 'synthetic', origin, userAgent: 'synthetic' }), page: () => url, selected: () => true, active: () => true,
      network: () => ({ cancel() {}, requestBusinessProfileRead: async job => ({ ...job, status: 200, error: '', body: JSON.stringify({ resource_response: { status: 'success', code: 0, data: job.url.includes('/UserResource/') ? { type: 'user', id: '42', username: 'sample', full_name: 'Test', image_large_url: 'https://i.pinimg.com/user/default.jpg', avatar_color_index: color } : [], bookmark: '-end-' }, client_context: { user: { id: '42' } } }) }) }), settled() {}, recordAddress() {}, document: () => origin + '/', documentEpoch: () => 1 });
    await reader.demand();
    const expected = Number.isInteger(color) && color >= 1 && color <= 10 ? color : undefined;
    assert.equal(store.profile.avatarColorIndex, expected);
    store.profileCache.put(store.profile, 123);
    assert.equal(store.profileCache.get(url, 'saved').snapshot.avatarColorIndex, expected);
  }
  const { PIN_PROFILE_API_SCRIPT: api } = load('feature_profile/src/main/ets/services/PinmonyProfileApiScript.ets');
  const apiAst = ts.createSourceFile('api.js', api, ts.ScriptTarget.Latest, true, ts.ScriptKind.JS), functions = [];
  function find(node) { if (ts.isFunctionDeclaration(node) && node.name && ['clean', 'mapUser'].includes(node.name.text)) functions.push(node.getText(apiAst)); ts.forEachChild(node, find); } find(apiAst);
  const map = vm.runInNewContext(functions.join('\n') + '\nmapUser;');
  assert.equal(map({ type: 'user', username: 'sample', avatar_color_index: 9 }, 'sample').avatarColorIndex, 9);
  assert.equal(map({ type: 'user', username: 'sample', avatar_color_index: 11 }, 'sample').avatarColorIndex, undefined);
  const { PinmonyProfileReadController: Controller } = require('./profile-read-controller-harness.cjs').create(ts);
  const store = { profileSession: 0, profileScrollOffset: 0, origins: [], profileCache: new Cache() };
  const controller = new Controller(store, { authenticated: () => true, foreground: () => true, document: () => url, addressKey: x => x, profileAddress: () => url, currentProfile: () => url, rootOnly: () => false, interacted: () => false, backTarget: () => '', apiEnabled: () => true, activeTab: () => 3, pendingTab: () => -1, rootAddress: () => url, selectProfile() {}, confirmPending() {}, recordAddress() {}, clearProfile() {}, prepareRead: () => false, requestRead() {}, runScript: async () => 'true' });
  const snapshot = { kind: 'state', session: 1, profileUrl: url, section: 'saved', displayName: 'Test', avatarUrl: '', avatarColorIndex: 9, actions: [], boards: [], createdPins: [] };
  controller.update(JSON.stringify(snapshot)); assert.equal(store.profile.avatarColorIndex, 9);
  controller.update(JSON.stringify({ ...snapshot, session: 2, avatarColorIndex: 99 })); assert.equal(store.profile.avatarColorIndex, undefined);
  controller.update(JSON.stringify(snapshot)); assert.equal(store.profile.avatarColorIndex, undefined, 'stale bridge cannot restore old avatar colors');
  controller.pause();
  console.log('Profile website avatar: five headers unified; native/Web metadata, invalid values, cache retention, Unicode initials, theme colors and image error reset passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
