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
const editPattern = /else if \((!this\.snapshot\.loading && this\.snapshot\.mode === 'edit')\) \{/;
assert(!condition(profile, editPattern, { snapshot: { mode: 'edit', loading: true } }), 'do not create by-value field builders with empty loading drafts');
assert(condition(profile, editPattern, { snapshot: { mode: 'edit', loading: false } }), 'create the form after loaded drafts are available, matching the original backup');
assert(!condition(profile, editPattern, { snapshot: { mode: 'following', loading: false } }), 'other modes retain their own content');
const ts = require(process.argv[2] || 'typescript');
const syncStart = profile.indexOf('  private syncUsername()');
const syncEnd = profile.indexOf('  onBack?:', syncStart);
assert(syncStart >= 0 && syncEnd > syncStart);
const DraftHost = vm.runInNewContext(ts.transpileModule('class DraftHost {' + profile.slice(syncStart, syncEnd) + '} DraftHost;', { compilerOptions: { target: 99 } }).outputText);
const drafts = new DraftHost();
const loadedFields = { firstName: 'First', lastName: 'Last', about: 'About', website: 'https://example.com', username: 'sample' };
Object.assign(drafts, { snapshot: { mode: 'edit', token: 1, loading: true, ...loadedFields }, usernameToken: -1, syncFollowingMotion() {}, scheduleFollowerEndCheck() {} });
drafts.syncUsername();
assert(!condition(profile, editPattern, drafts), 'initial empty fields are not mounted during loading');
drafts.snapshot.loading = false;
drafts.syncUsername();
assert(condition(profile, editPattern, drafts), 'loaded form mounts without any scroll event');
for (const [name, value] of Object.entries(loadedFields)) assert.equal(drafts[name + 'Draft'], value, name + ' is ready before field creation');
drafts.firstNameDraft = 'Unsaved first';
drafts.aboutDraft = 'Unsaved about';
drafts.syncUsername();
assert.equal(drafts.firstNameDraft, 'Unsaved first');
assert.equal(drafts.aboutDraft, 'Unsaved about', 'same-session updates retain unsaved input');
drafts.snapshot.token = 2;
drafts.snapshot.firstName = 'Next';
drafts.syncUsername();
assert.equal(drafts.firstNameDraft, 'Next', 'next edit session initializes fresh profile data');
assert.equal((profile.match(/\.enabled\(!this\.saving && !this\.snapshot\.loading\)/g) || []).length, 2, 'single-line fields and about stay disabled');
assert(profile.includes('.enabled(!this.saving && !this.snapshot.loading && !this.snapshot.avatarBusy)'), 'avatar action stays disabled');
assert(!notifications.includes('loadingContent()'), 'notification loading never replaces real groups with invented placeholder categories');
const coldPattern = /if \((this\.store\.loading && !this\.store\.notifications\.length)\) \{ this\.coldLoadingBackground\(\) \}/;
for (const loading of [false, true]) {
  for (const rows of [[], [{ key: 'verified', categories: [] }]]) {
    for (const error of ['', 'failed']) {
      assert.equal(condition(notifications, coldPattern, { store: { loading, notifications: rows, error } }), loading && rows.length === 0,
        'cold/retry background exists only during loading without real rows; failure/empty completion never shows fake settings');
    }
  }
}
const coldBody = notifications.slice(notifications.indexOf('  private coldLoadingBackground()'), notifications.indexOf('  private destination()'));
assert(coldBody.includes(".accessibilityLevel('no-hide-descendants').hitTestBehavior(HitTestMode.None)"), 'cold background is decoration only');
assert(!/\b(?:Text|Toggle|Checkbox|Button)\(|\.on(?:Click|Change)\(|this\.(?:onRequest|change)\(/.test(coldBody), 'cold background invents no category copy, values or actions');
assert(coldBody.includes("$r('app.color.primary_text')") && coldBody.includes("$r('app.color.secondary_text')"), 'cold background follows light/dark theme colors');
assert(notifications.indexOf('this.coldLoadingBackground()') < notifications.indexOf('.opacity(this.store.loading ? 0.4 : 1)'), 'cold and real content share the existing dimmed body');
assert(notifications.includes('ForEach(this.store.notifications,'), 'verified notification content is retained during loading');
const native = read('entry/src/main/ets/app/PinmonySettingsNativeFlow.ets');
assert(!native.slice(native.indexOf("if (action === 'notifications') {")).split('return;')[0].includes('this.store.notifications = []'), 'notification refresh retains verified content until replacement response');
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
console.log('Settings loading: content backgrounds, cold/read/refresh/failure branches, retained account, disabled edits and real notification content retention passed');
