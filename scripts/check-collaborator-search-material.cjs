const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardCollaboratorsPage.ets', 'utf8');
const helper = fs.readFileSync('common_ui/src/main/ets/services/PinmonySearchControlMaterial.ets', 'utf8');
const source = helper.replace(/^import .*;\r?\n/gm, '');
for (const api of [24, 25, 26]) for (const support of [false, true]) for (const dark of [false, true]) {
  const context = { exports: {}, $r: x => x, deviceInfo: { apiAvailable: () => api >= 26 }, uiMaterial: {
    isImmersiveMaterialSupported: () => { assert(api >= 26); return support; }, Material: { empty: 'empty' },
    ImmersiveStyle: { THICK: 'thick', ULTRA_THIN: 'thin' }, ImmersiveMaterial: class { constructor(options) { Object.assign(this, options); } }
  } };
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, context);
  for (const mode of ['immersive', 'off', 'gentle', 'exquisite', 'off']) {
    const active = api >= 26 && support && mode !== 'off';
    assert.equal(context.exports.PinmonySearchControlMaterial.active(mode), active);
    const calls = [];
    new context.exports.PinmonySearchControlModifier(mode, dark).applyNormalAttribute({ systemMaterial: value => calls.push(value) });
    assert.equal(calls.length, api >= 26 ? 1 : 0);
    if (active) {
      assert.equal(calls[0].style, mode === 'gentle' ? 'thick' : 'thin');
      assert.equal(calls[0].materialColor, dark ? '#301C2022' : '#30FFFFFF');
      assert.equal(calls[0].interactive, true);
      assert.equal(calls[0].applyShadow, false);
      assert.equal(calls[0].lightEffect.color, 'app.color.immersive_interaction_light');
    } else if (api >= 26) assert.equal(calls[0], 'empty');
  }
}
assert(page.includes("@StorageLink('immersiveLightMode')"));
assert(page.includes("@StorageLink('systemDarkMode')"));
assert(!page.includes('MaterialScope'));
assert(page.includes("bottomBuilder: this.snapshot.phase === 'invite' ? { builder: this.invitationSearchBuilder, height: 76 } : undefined"));
assert(page.includes('.attributeModifier(new PinmonySearchControlModifier(this.immersiveLightMode, this.hdsDarkMode))'));
assert(page.includes("PinmonySearchControlMaterial.active(this.immersiveLightMode) ? Color.Transparent : $r('app.color.surface_muted')"));
assert(page.includes('.onChange((value: string) => { this.query = value; })'));
assert(page.includes("(user.name + ' ' + user.username).toLowerCase().includes(this.query.trim().toLowerCase())"));
assert(page.includes('pm_search_by_name_or_username_59fb9fda'));
assert(page.includes(".width('100%').height(44)"));
assert(page.includes(".height(76).padding({ left: 24, right: 24, top: 16, bottom: 16 })"));
assert(page.includes('.borderRadius(24)'));
assert(page.includes("color: this.hdsDarkMode ? '#33000000' : '#14000000'"));
assert(page.includes("(this.snapshot.phase === 'invite' ? 76 : 0)"));
assert(!helper.includes('Navigation()'));
assert(page.includes("user.status === 'owner' || user.status === 'accepted' ? Color.Transparent : $r('app.color.surface_muted')"));
console.log('Collaborator search material: API24/25 fallback, API26 capability, modes and resets, themes, title scope, query and filtering passed.');

// Compare both consumers through their actual shared implementation, including mode resets.
const following = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyFollowingSegmentMaterial.ets', 'utf8');
assert(following.includes("import { PinmonySearchControlModifier } from 'common_ui'"));
assert(following.includes('extends PinmonySearchControlModifier'));
const followingPage = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets', 'utf8');
const reference = followingPage.slice(followingPage.indexOf('private searchTitleInput()'), followingPage.indexOf('private searchDestination()'));
const target = page.slice(page.indexOf('@Builder private invitationSearch()'), page.indexOf('@Builder private permissionOption'));
for (const pattern of [/\.borderRadius\(24\)/, /radius: this\.getUIContext\(\)\.vp2px\(6\)/, /offsetX: 0, offsetY: this\.getUIContext\(\)\.vp2px\(1\)/, /height\(44\)/, /height\(76\)/]) {
  assert(pattern.test(reference) && pattern.test(target), 'Both search fields use the same geometry and shadow: ' + pattern);
}
const callback = page.match(/private readonly invitationSearchBuilder: \(\) => void = (\(\): void => \{ this\.invitationSearch\(\); \});/);
assert(callback);
const bind = vm.runInNewContext(ts.transpileModule('function bind() { return ' + callback[1] + '; } bind;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const host = {called:false, invitationSearch(){this.called=true;}};
bind.call(host).call({}); assert(host.called, 'HDS builder retains component owner');
console.log('Following and invitation share one material implementation, HDS bottomBuilder, sizing, shadow and owning callback.');

// HDS bottomBuilder already reserves search padding; invitation body adds no extra gap.
const bodyPadding = page.match(/top:this\.titleContentInset\(\) \+ (\(this\.snapshot\.phase === 'invite' \? 0 : 20\)),bottom:20/);
assert(bodyPadding, 'Invite body must not retain the old additional 20vp gap');
const bodyGap = vm.runInNewContext('(function () { return ' + bodyPadding[1] + '; })');
for (const phase of ['invite', 'members', 'permissions']) {
  assert.equal(bodyGap.call({snapshot:{phase}}), phase === 'invite' ? 0 : 20, 'Only invitation gap changes');
}
console.log('Invitation body no longer adds 20vp beneath HDS search; members and permissions retain original padding.');
