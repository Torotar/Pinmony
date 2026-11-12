const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
const title = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfileHubTitle.ets', 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
function member(name) {
  let result;
  function visit(node) {
    if ((ts.isMethodDeclaration(node) || ts.isPropertyDeclaration(node)) && node.name?.getText(ast) === name) result = node.getText(ast);
    ts.forEachChild(node, visit);
  }
  visit(ast); assert(result, name); return result;
}
let creates = 0, updates = 0, disposals = 0;
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + [
  'hubTopTitleContent', 'hubTopTitleKey', 'hubTitleSettings', 'hubTitleTabSelected', 'hubControlMaterials', 'hubMaterialConfiguration',
  'updateHubTitleContent', 'aboutToDisappear'
].map(member).join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
  ComponentContent: class {
    constructor(_ctx, _builder, options) { creates++; this.options = options; }
    update(options) { assert(!this.disposed); updates++; this.options = options; }
    dispose() { assert(!this.disposed); this.disposed = true; disposals++; }
  }, wrapBuilder: builder => builder, buildPinmonyProfileHubTitle() {}
});
let offset = 0, settings = 0, changedIndex = -1, animatedIndicator = -1, stopped = 0;
const page = Object.assign(new Host(), {
  profile: { profileUrl: 'profile-a', avatarUrl: 'avatar-a', avatarColorIndex: 3,
    displayName: 'A', handle: 'a', session: 1, suggestionWriting: false },
  hubTab: 'boards', hubIndicatorPosition: -1, interactionReady: true, statusBarHeightPx: 24,
  getUIContext: () => ({ px2vp: px => px }), hubHeaderBackgroundOpacity: () => 1 - offset / 112,
  stopHubChromeAnimation() { stopped++; }, openSettings() { settings++; },
  animateProfileIndicator(target) { animatedIndicator = target; },
  hubSwiper: { changeIndex(target, animated) { assert.equal(animated, true); changedIndex = target; } }
});
page.updateHubTitleContent(); const retained = page.hubTopTitleContent;
for (let frame = 0; frame < 100; frame++) page.updateHubTitleContent();
assert.equal(creates, 1); assert.equal(updates, 0, 'unchanged title reevaluation must not update avatar props');
for (const target of [112, 0, 112, 0]) {
  const start = offset;
  for (let frame = 1; frame <= 20; frame++) {
    offset = start + (target - start) * frame / 20;
    page.updateHubTitleContent();
    assert.equal(page.hubTopTitleContent, retained, 'every collapse, expansion and reversal retains the same entity');
    assert.equal(retained.options.avatarUrl, 'avatar-a');
    assert.equal(retained.options.backdropOpacity, 1 - offset / 112);
  }
}
assert.equal(creates, 1); assert.equal(updates, 80);
for (const [key, value] of [['avatarUrl', 'avatar-b'], ['avatarColorIndex', 7], ['displayName', 'B'], ['profileUrl', 'profile-b'], ['session', 2]]) {
  page.profile[key] = value; page.updateHubTitleContent();
  assert.equal(page.hubTopTitleContent, retained, 'validated profile changes update the retained content');
}
page.hubIndicatorPosition = 0.5; page.updateHubTitleContent(); assert.equal(retained.options.indicatorPosition, 0.5);
retained.options.onTabSelected('collages'); assert.equal(changedIndex, 2); assert.equal(animatedIndicator, 2);
assert.equal(page.hubIndicatorClickTarget, 2); assert.equal(page.hubPagerAnimationTarget, -1);
changedIndex = -1;
for (const tab of ['boards', 'unknown']) retained.options.onTabSelected(tab);
assert.equal(changedIndex, -1, 'current and invalid tabs do not navigate');
page.profile.suggestionWriting = true; retained.options.onTabSelected('pins'); assert.equal(changedIndex, -1);
page.profile.suggestionWriting = false;
page.interactionReady = false; page.updateHubTitleContent();
assert.equal(retained.options.interactionEnabled, false);
retained.options.onTabSelected('pins'); retained.options.onSettings();
assert.equal(changedIndex, -1); assert.equal(settings, 0, 'covered title callbacks cannot act');
page.interactionReady = true; page.updateHubTitleContent(); retained.options.onSettings(); assert.equal(settings, 1);
page.hubControlMaterials.set('publish',{});page.hubMaterialConfiguration='immersive:false';
page.aboutToDisappear(); assert.equal(disposals, 1); assert.equal(stopped, 1);
assert.equal(page.hubControlMaterials.size,0);assert.equal(page.hubMaterialConfiguration,'','disposed pages release retained material objects');
assert.equal(page.hubTopTitleContent, undefined); assert.equal(page.hubTopTitleKey, '');
page.updateHubTitleContent(); assert.equal(creates, 2, 'new lifetime creates fresh content after disposal');
assert(source.includes('stackBuilderComponent: this.hubTopTitleContent'));
assert(!source.includes('stackBuilder: this.hubTopTitleBuilder'));
assert(source.includes('this.updateHubTitleContent();\n    return {'));
assert(title.includes("@StorageLink('pinmonyLanguage')"));
assert(title.includes("tab + ':' + this.uiLanguage"), 'language updates tab labels without replacing avatar ancestry');
assert(title.includes("@StorageLink('profileAvatarRight')") && title.includes("@StorageLink('pinmonyUpdateUnread')"));
assert(title.includes(".backgroundColor($r('app.color.page_background'))"));
assert(title.includes('.height(56).clip(false)') && title.includes("}.width('100%').height(80)"));
assert(title.includes('image: this.avatarUrl') && title.includes('profileUrl: this.profileUrl'));
assert(!title.includes('.animation('), 'frame props must not acquire a second animation');
console.log('Profile header retention: unchanged reevaluation, frame updates, profile/session changes, tab routing, input guards and disposal passed.');
