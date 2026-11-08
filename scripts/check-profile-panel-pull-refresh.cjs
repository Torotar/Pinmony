const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets', 'utf8');
const ast = ts.createSourceFile('panel.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const names = ['canPullPanelRefresh', 'showPanelRefreshIndicator', 'requestPanelRefresh'], methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast);
assert.equal(methods.length, names.length);
const RefreshStatus = { Inactive: 0, Drag: 1, OverDrag: 2, Refresh: 3, Done: 4 };
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { RefreshStatus });
let requests = 0;
function fixture(mode = 'followers') {
  return Object.assign(new Host(), { active: true, rootRestorePending: false, searchRestorePending: false,
    saving: false, followingBusy: false, snapshot: { mode, loading: false, refreshing: false, moreLoading: false },
    panelRefreshState: RefreshStatus.Inactive, onRefresh: () => requests++ });
}
for (const state of Object.values(RefreshStatus)) for (const refreshing of [false, true]) {
  const h = fixture('edit'); h.panelRefreshState = state; h.snapshot.refreshing = refreshing;
  assert.equal(h.canPullPanelRefresh(), false);
  assert.equal(h.showPanelRefreshIndicator(), false, 'edit must hide gesture and retained refresh states');
  const before = requests; h.requestPanelRefresh(); assert.equal(requests, before, 'edit never reloads drafts');
}
for (const mode of ['followers', 'following']) {
  const h = fixture(mode);
  for (const state of Object.values(RefreshStatus)) {
    h.panelRefreshState = state;
    assert.equal(h.showPanelRefreshIndicator(), state === RefreshStatus.Drag || state === RefreshStatus.OverDrag);
  }
  const before = requests; h.requestPanelRefresh(); assert.equal(requests, before + 1);
  h.snapshot.refreshing = true; h.panelRefreshState = RefreshStatus.Inactive;
  assert(h.showPanelRefreshIndicator(), 'actual list refresh remains visible after release');
  h.requestPanelRefresh(); assert.equal(requests, before + 1, 'in-flight refresh cannot repeat');
  h.snapshot.refreshing = false; assert.equal(h.showPanelRefreshIndicator(), false);
  for (const key of ['active', 'rootRestorePending', 'searchRestorePending', 'saving', 'followingBusy', 'loading', 'moreLoading']) {
    const blocked = fixture(mode);
    if (['loading', 'moreLoading'].includes(key)) blocked.snapshot[key] = true;
    else blocked[key] = key !== 'active';
    blocked.panelRefreshState = RefreshStatus.OverDrag;
    assert.equal(blocked.canPullPanelRefresh(), false, key);
    assert.equal(blocked.showPanelRefreshIndicator(), false, key);
    const count = requests; blocked.requestPanelRefresh(); assert.equal(requests, count, key);
  }
  h.snapshot.refreshing = true; h.active = false;
  assert.equal(h.showPanelRefreshIndicator(), false, 'covered page hides retained spinner');
}
assert(source.includes('.pullToRefresh(this.canPullPanelRefresh())'));
assert(source.includes('.onRefreshing(() => this.requestPanelRefresh())'));
assert(source.includes('.visibility(this.showPanelRefreshIndicator() ? Visibility.Visible : Visibility.Hidden)'));
assert(source.includes('.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })'), 'retain scroll rebound');
assert(source.includes("else if (this.snapshot.mode === 'edit') {"), 'edit form must remain mounted during initial loading');
assert(!source.includes("else if (!this.snapshot.loading && this.snapshot.mode === 'edit')"), 'loading cannot exclude its own placeholder branch');
assert(/if \(this.snapshot.loading\) \{\s*Image\(\$r\('app.media.profile_avatar_loading'\)\)/.test(source), 'loading retains avatar placeholder');
assert(source.includes(".opacity(this.snapshot.mode === 'edit' && this.snapshot.loading ? 0.4 : 1)"), 'loading form stays dimmed');
assert(source.includes(".enabled(this.snapshot.mode !== 'edit' || !this.snapshot.loading)"), 'loading form cannot accept edits');
assert(/if \(this.snapshot.loading\) \{\s*Stack\([\s\S]*?LoadingProgress\(\)\.width\(40\)/.test(source), 'initial loading indicator remains');
assert(source.includes('private field($$: PinmonyProfileEditFieldOptions)'), 'fields need one typed reference argument');
assert(source.includes('TextInput({ text: $$.text, placeholder: $$.placeholder })'));
for (const [label, draft] of [['pm_first_name_67733104', 'firstNameDraft'], ['pm_last_name_b85f26df', 'lastNameDraft'], ['pm_website_fb8d739d', 'websiteDraft'], ['pm_username_1a3f0617', 'usernameDraft']]) {
  assert(source.includes("this.field({ label: '" + label + "', text: this." + draft + ', placeholder:'), draft);
}
let syncMethod;
function findSync(node) {
  if (ts.isMethodDeclaration(node) && node.name.getText(ast) === 'syncUsername') syncMethod = node.getText(ast);
  ts.forEachChild(node, findSync);
}
findSync(ast); assert(syncMethod);
const DraftHost = vm.runInNewContext(ts.transpileModule('class DraftHost {' + syncMethod + '} DraftHost;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const draftHost = Object.assign(new DraftHost(), { snapshot: { mode: 'edit', loading: true, token: 8,
  firstName: '', lastName: '', username: '', about: '', website: '' }, usernameToken: -1,
  presentationMounted: false, syncFollowingMotion() {}, scheduleFollowerEndCheck() {} });
draftHost.syncUsername(); assert.equal(draftHost.usernameToken, -1, 'loading cannot consume initialization token');
Object.assign(draftHost.snapshot, { loading: false, firstName: 'Given', lastName: 'Family', username: 'sample', about: 'Bio', website: 'https://example.com' });
draftHost.syncUsername();
for (const [draft, field] of [['firstNameDraft', 'firstName'], ['lastNameDraft', 'lastName'], ['usernameDraft', 'username'], ['aboutDraft', 'about'], ['websiteDraft', 'website']]) {
  assert.equal(draftHost[draft], draftHost.snapshot[field], draft + ' receives loaded data');
  draftHost[draft] = 'edited';
}
draftHost.syncUsername(); assert.equal(draftHost.usernameDraft, 'edited', 'same token preserves user draft');
draftHost.snapshot.token++; draftHost.snapshot.username = 'next'; draftHost.syncUsername();
assert.equal(draftHost.usernameDraft, 'next', 'new panel receives new identity');
console.log('Profile panel: refresh guards, loading background, typed field references and async draft initialization/preservation passed');
