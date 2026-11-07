const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const read = name => fs.readFileSync(name, 'utf8');
const base = 'feature_settings/src/main/ets/components/';
const account = read(base + 'PinmonyAccountPage.ets');
const visibility = read(base + 'PinmonyVisibilitySettingsPage.ets');
const notifications = read(base + 'PinmonyNotificationsPage.ets');
const profile = read('feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets');
function condition(source, pattern, state) {
  const match = source.match(pattern);
  assert(match, 'content visibility condition exists');
  return vm.runInNewContext('(function(){return ' + match[1] + ';}).call(state)', { state });
}
const accountPattern = /if \((this\.store\.data\?\.ready[^\n]+)\) \{\s+if \(\(this\.retainedAccount/;
for (const screen of ['account', 'personal', 'country']) {
  for (const loading of [false, true]) {
    assert.equal(!!condition(account, accountPattern, { store: { screen, loading } }), loading && screen === 'account');
    assert(condition(account, accountPattern, { store: { screen, loading, data: { ready: true } } }), 'loaded content survives refresh');
  }
}
assert(condition(account, accountPattern, { retainedAccount: true, store: { screen: 'personal', loading: true } }), 'retained account remains visible');
assert(account.includes("this.store.data?.email || ''"), 'first-load account has no fabricated identity');
const visibilityPattern = /if \(([^\n]+)\) \{ this\.visibilityContent\(\) \}/;
assert(condition(visibility, visibilityPattern, { store: { loading: true } }), 'visibility fields appear on cold load');
assert(!condition(visibility, visibilityPattern, { store: { loading: false } }), 'failed cold load is not shown as valid settings');
assert(visibility.includes('!!this.store.data?.ready && !this.store.loading && !this.store.busy && !this.store.error'), 'visibility controls remain gated');
assert(profile.includes("else if (this.snapshot.mode === 'edit') {"), 'edit form is present while loading');
assert(!profile.includes("else if (!this.snapshot.loading && this.snapshot.mode === 'edit')"));
assert.equal((profile.match(/\.enabled\(!this\.saving && !this\.snapshot\.loading\)/g) || []).length, 2, 'single-line fields and about stay disabled');
assert(profile.includes('.enabled(!this.saving && !this.snapshot.loading && !this.snapshot.avatarBusy)'), 'avatar action stays disabled');
assert(notifications.includes('if (this.store.loading && !this.store.notifications.length) { this.loadingContent() }'), 'only cold notification reads use placeholders');
assert(notifications.includes('ForEach(this.store.notifications,'), 'verified notification content is retained during loading');
const placeholder = notifications.slice(notifications.indexOf('private loadingContent()'), notifications.indexOf('private destination()'));
assert(!/Toggle\(|onClick\(|onChange\(/.test(placeholder), 'placeholders do not fabricate switches or writes');
assert(placeholder.includes("accessibilityLevel('no-hide-descendants').hitTestBehavior(HitTestMode.None)"));
for (const source of [account, visibility, notifications]) assert(source.includes('if (this.store.loading || this.store.busy)'), 'loading and save indicators remain');
assert(profile.includes('if (this.snapshot.loading)'));
for (const name of ['PinmonyAccountPage.ets', 'PinmonyVisibilitySettingsPage.ets', 'PinmonyRecommendationSettingsPage.ets',
  'PinmonyDisplaySettingsPage.ets', 'PinmonySocialPermissionsPage.ets', 'PinmonyNotificationsPage.ets']) {
  const source = read(base + name);
  const dim = source.indexOf('.opacity(this.store.loading ? 0.4 : 1).enabled(!this.store.loading)');
  assert(dim >= 0, name + ' dims and disables the body during reads');
  assert(dim < source.indexOf('if (this.store.loading || this.store.busy)'), name + ' keeps the indicator outside dimmed body');
  assert(source.indexOf('.titleBar(', dim) > dim, name + ' keeps the title outside dimmed body');
}
assert(profile.includes(".opacity(this.snapshot.mode === 'edit' && this.snapshot.loading ? 0.4 : 1)"), 'only profile edit is dimmed, preserving following/followers presentation');
assert(profile.includes(".enabled(this.snapshot.mode !== 'edit' || !this.snapshot.loading)"));
const social = read(base + 'PinmonySocialPermissionsPage.ets');
const links = social.slice(social.indexOf('private link('), social.indexOf('private selection('));
assert(links.includes('Column() {') && !links.includes('Button()') && !links.includes('.stateStyles('), 'navigation entries use containers without intrinsic disabled button opacity');
assert(links.includes('.focusable(true).accessibilityGroup(true).accessibilityRole(AccessibilityRoleType.BUTTON)'), 'navigation entries retain focus and accessible button semantics');
assert(links.includes('.accessibilityText(this.uiText(title)'), 'navigation entries retain localized accessible labels');
assert(links.includes('.enabled(!this.store.busy && !this.store.loading && !this.confirming && (!requiresReady || this.store.social.ready))'), 'social entry write, loading, confirmation and permission guards remain');
console.log('Settings loading: four content backgrounds, cold/read/refresh/failure branches, retained account, disabled edits and noninteractive notification placeholders passed');
