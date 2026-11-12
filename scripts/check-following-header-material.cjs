const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets', 'utf8');
const helper = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyFollowingSegmentMaterial.ets', 'utf8');
for (const api26 of [false, true]) for (const supported of [false, true]) {
  const material = { empty: 'empty' };
  const context = { exports: {}, Color: { Transparent: 'transparent', White: 'white' }, $r: v => v,
    ColorMetrics: { resourceColor: v => v }, deviceInfo: { apiAvailable: () => api26 },
    uiMaterial: { Material: material, isImmersiveMaterialSupported: () => supported,
      ImmersiveStyle: { THICK: 'thick', REGULAR: 'regular', ULTRA_THIN: 'ultraThin' }, ImmersiveMaterial: class { constructor(options) { Object.assign(this, options); } } } };
  const code = ts.transpileModule(helper.replace(/^import .*;\r?\n/gm, ''), { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText;
  vm.runInNewContext(code, context);
  const cls = context.exports.PinmonyFollowingSegmentMaterial;
  for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
    assert.equal(cls.enabled(mode), api26 && supported && mode !== 'off');
    const result = cls.create(mode);
    if (!api26) assert.equal(result, undefined);
    else if (!supported || mode === 'off') assert.equal(result, 'empty');
    else { assert.equal(result.style, mode === 'gentle' ? 'thick' : 'regular'); assert.equal(result.interactive, true); }
    for (const dark of [false, true]) {
      let applied;
      new context.exports.PinmonyFollowingSearchMaterial(mode, dark).applyNormalAttribute({systemMaterial: value => { applied = value; }});
      if (!api26) assert.equal(applied, undefined);
      else if (!supported || mode === 'off') assert.equal(applied, 'empty');
      else {
        assert.equal(applied.style, mode === 'gentle' ? 'thick' : 'ultraThin');
        assert.equal(applied.materialColor, dark ? '#301C2022' : '#30FFFFFF');
        assert.equal(applied.colorInvert, false);
        assert.equal(applied.applyShadow, false);
        assert.equal(applied.lightEffect.color, 'app.color.immersive_interaction_light');
      }
    }
    assert.equal(cls.background(), 'app.color.surface_muted');
    if (result && typeof result === 'object') assert.equal(result.lightEffect.color, 'app.color.immersive_interaction_light', 'Match Inbox interaction light');
  }
}
assert(page.includes('enableComponentSafeArea: false'));
assert(page.includes('.bindToScrollable([this.scroller])'));
assert(page.includes("top: this.contentTopInset() + (this.snapshot.mode === 'following' ? 48 : 0) + 16"));
assert(page.includes(".offset({ y: this.contentTopInset() + (this.snapshot.mode === 'following' ? 48 : 0) }).hitTestBehavior"));
assert(page.includes("bottomBuilder: this.snapshot.mode === 'following' ? { builder: this.followingSegmentBuilder, height: 48 } : undefined"));
assert(!page.slice(page.indexOf('private panelDestination()')).includes('this.followingSegmentBar()'));
assert(page.includes('private readonly followingSegmentBuilder: () => void = (): void => { this.followingSegmentBar(); };'));
assert(page.includes("if (deviceInfo.apiAvailable('26.0.0'))"));
assert.equal((page.match(/buttonBackgroundBlurStyle: BlurStyle.NONE/g) || []).length, 2);
assert(page.includes('$selectedIndex: (index: number): void => this.selectFollowingSection'));
assert(page.includes('onItemClicked: (index: number): void => this.selectFollowingSection'));
console.log('Following header: scroll backdrop, refresh offset, API24/26 gates, material capability and four modes passed');

const segment = page.slice(page.indexOf('private followingSegmentBar()'), page.indexOf('private panelDestination()'));
const inbox = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', 'utf8');
const shadow = /\.borderRadius\(24\)\s*\.shadow\(\{ radius: this\.getUIContext\(\)\.vp2px\(6\),\s*color: this\.hdsDarkMode \? '#33000000' : '#14000000',\s*offsetX: 0, offsetY: this\.getUIContext\(\)\.vp2px\(1\) \}\)/g;
assert.equal((segment.match(shadow) || []).length, 2, 'Both API branches match Inbox soft shadow');
assert((inbox.match(shadow) || []).length >= 2, 'Inbox reference retains the same shadow');
console.log('Following capsule: both runtime branches match Inbox light/dark soft shadows');

const search = page.slice(page.indexOf('private searchTitleInput()'));
const searchOptions = page.slice(page.indexOf('private searchOptions()'), page.indexOf('private panelItem('));
assert(searchOptions.includes('systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)'));
assert(searchOptions.includes("enableScrollEffect: this.immersiveLightMode !== 'off'"));
assert(search.includes('.attributeModifier(new PinmonyFollowingSearchMaterial(this.immersiveLightMode, this.hdsDarkMode))'));
assert(!search.includes('.backgroundBlurStyle('), 'No ordinary blur over the search system material');
assert(!search.includes(".backgroundColor($r('app.color.page_background')).zIndex(1)"), 'No opaque search backdrop');
assert.equal((search.match(shadow) || []).length, 1, 'Search input matches Inbox soft shadow');
assert(search.includes('.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })'), 'Short and empty search lists rebound');
assert(search.includes('.bindToScrollable([this.searchScroller])'));
console.log('Profile search: title material, input blur and soft shadow, real scroller and always-enabled spring passed');

assert(search.includes('Search({ value: this.followerQuery'), 'Official Search replaces generic TextInput');
assert(!search.includes('TextInput({ text: this.followerQuery'));
assert(!page.includes('PinmonyFollowingSearchMaterialScope'));
assert(searchOptions.includes('bottomBuilder: { builder: this.searchTitleInputBuilder, height: 76 }'));
assert(helper.includes('AttributeModifier<SearchAttribute>'));
assert(!helper.includes('Navigation()'));
assert(search.includes(".height(76).padding({ left: 24, right: 24, top: 16, bottom: 16 })"));

console.log('Profile search: official Search and supported custom-title interactive material scope passed');

const inputBuilder = page.match(/private readonly searchTitleInputBuilder: \(\) => void = (\(\): void => \{ this\.searchTitleInput\(\); \});/);
assert(inputBuilder, 'HDS callback retains owning component context like Inbox and profile builders');
const boundHost = { searchTitleInput() { this.called = true; } };
const boundFactory = vm.runInNewContext(ts.transpileModule('function bind() { return ' + inputBuilder[1] + '; } bind;', { compilerOptions: {target: ts.ScriptTarget.ES2021} }).outputText);
const builder = boundFactory.call(boundHost);
builder.call({});
assert.equal(boundHost.called, true, 'HDS invoking with foreign this must still render the owning search input');
console.log('Profile search: title callback keeps component context under foreign HDS receiver');

assert(segment.includes('PinmonyFollowingSegmentMaterial.enabled(this.immersiveLightMode) ? undefined : PinmonyFollowingSegmentMaterial.background()'));
console.log('Following capsule: Inbox palette, no double blur, bound HDS title builder and material defaults passed');
