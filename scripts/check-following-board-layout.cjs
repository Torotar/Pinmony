const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const names = ['profilePanelIdentity', 'profilePanelPresentations', 'profilePanelPresentation'];
const methods = names.map(name => {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
});
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const panel = { page: 'synthetic-profile', mode: 'following', section: 'boards', scrollOffset: 188 };
const h = Object.assign(new Host(), { profileStore: { panel }, profilePanelExitSnapshots: new Map() });
const identity = h.profilePanelIdentity(panel);
assert.equal(h.profilePanelPresentations()[0], panel);
h.followingBoardReturn = { panel }; h.profileStore.panel = undefined;
assert.equal(h.profilePanelPresentations().length, 1);
assert.equal(h.profilePanelPresentations()[0], panel, 'covered parent keeps the same mounted ForEach item');
assert.equal(h.profilePanelPresentation(panel), panel);
h.profileStore.panel = panel; h.followingBoardReturn = undefined;
assert.equal(h.profilePanelIdentity(h.profilePanelPresentations()[0]), identity, 'return cannot replay the parent entrance');
assert.equal(h.profilePanelPresentations()[0].scrollOffset, 188);
h.followingBoardReturn = { panel }; h.retainedProfilePanel = panel;
assert.equal(h.profilePanelPresentations().length, 1, 'overlapping retained contexts must not duplicate a page');
const boardLayer = source.slice(source.indexOf('if (this.boardStore.boardDetail && this.nativeBoardVisible())'), source.indexOf('if (this.boardStore.collaborators) {', source.indexOf('if (this.boardStore.boardDetail && this.nativeBoardVisible())')));
assert(boardLayer.includes('NATIVE_PAGE_TRANSITION : BOARD_PAGE_TRANSITION'));
assert(!boardLayer.includes('TransitionEffect.IDENTITY'), 'board return must animate');
assert(source.includes('const BOARD_PAGE_TRANSITION: TransitionEffect = NATIVE_PAGE_TRANSITION;'), 'board directly reuses the shared page transition');
const transition = source.match(/const NATIVE_PAGE_TRANSITION:[\s\S]*?\n\);/)[0];
assert.equal((transition.match(/duration: 180, curve: Curve.EaseOut/g) || []).length, 2, 'board entry and exit use the shared 180ms EaseOut timing');
const page = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets', 'utf8');
const grid = page.slice(page.indexOf('GridRow({'), page.indexOf('} else {', page.indexOf('GridRow({')));
const keyMatch = grid.match(/\}, \(item: PinmonyProfilePanelItem\)(?:: string)? => ([^\r\n]+)\)/);
assert(keyMatch, 'board card identity callback');
const cardIdentity = vm.runInNewContext('(function(item) { return ' + keyMatch[1] + '; })');
const itemBefore = { id: 'retained-board', following: true, canFollow: true };
const itemDuring = { ...itemBefore, canFollow: false };
assert.equal(cardIdentity.call({ uiLanguage: 'zh' }, itemBefore), cardIdentity.call({ uiLanguage: 'zh' }, itemDuring),
  'return permission validation must not rebuild board cover nodes');
assert.equal(cardIdentity.call({ uiLanguage: 'zh' }, itemBefore), cardIdentity.call({ uiLanguage: 'en' }, { ...itemBefore, following: false }),
  'follow state and language updates must preserve board cover identity');
assert(grid.includes('BreakpointsReference.ComponentSize'));
assert(grid.includes('GridCol({ span: 1 })'));
const cardBuilder = page.slice(page.indexOf('private boardCard('), page.indexOf('private searchPanelItem('));
assert(cardBuilder.includes('.aspectRatio(1.5)'));
assert(grid.includes('this.boardCard({ item: this.panelItem(item) })'));
const itemMethodStart = page.indexOf('  private panelItem(');
const itemMethodEnd = page.indexOf('\n  @Builder', itemMethodStart);
const ItemHost = vm.runInNewContext(ts.transpileModule('class ItemHost {' + page.slice(itemMethodStart, itemMethodEnd) + '} ItemHost;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const itemHost = Object.assign(new ItemHost(), { snapshot: { items: [itemBefore] } });
assert.equal(itemHost.panelItem(itemBefore), itemBefore);
itemHost.snapshot = { items: [itemDuring] };
assert.equal(itemHost.panelItem(itemBefore), itemDuring, 'stable card reads the current permission, not the captured original item');
const changedItem = { ...itemBefore, name: 'updated name', pinCount: '12', following: false, covers: ['new-cover'] };
itemHost.snapshot = { items: [changedItem] };
assert.equal(itemHost.panelItem(itemBefore), changedItem, 'real data changes still reach the retained card');
itemHost.snapshot = { items: [] };
assert.equal(itemHost.panelItem(itemBefore), itemBefore, 'departing row retains its last valid content');
for (const field of ['canFollow', 'following', 'covers', 'name', 'pinCount']) assert(cardBuilder.includes('$$.item.' + field), field + ' uses reactive Builder reference');
const searchRows = page.slice(page.indexOf('ForEach(this.visibleItems()'), page.indexOf('if (!this.snapshot.loading', page.indexOf('ForEach(this.visibleItems()')));
assert(searchRows.includes('this.searchPanelItem({ item: this.panelItem(item) })'));
const searchKeyMatch = searchRows.match(/\}, \(item: PinmonyProfilePanelItem\)(?:: string)? => ([^\r\n]+)\)/);
assert(searchKeyMatch);
const searchIdentity = vm.runInNewContext('(function(item) { return ' + searchKeyMatch[1] + '; })');
assert.equal(searchIdentity.call({ uiLanguage: 'zh' }, itemBefore), searchIdentity.call({ uiLanguage: 'en' }, itemDuring), 'search board image identity survives restore and language changes');
assert(!grid.includes("width('48%')") && !grid.includes('height(140)'));
const columns = vm.runInNewContext('(' + grid.match(/columns: (\{[^}]+\})/)[1] + ')');
const thresholds = [...grid.matchAll(/'(\d+)vp'/g)].map(match => Number(match[1]));
for (const width of [192, 240, 272, 319, 320, 360, 599, 600, 760, 839, 840, 920, 1439, 1440, 1920]) {
  const count = Object.values(columns)[thresholds.filter(value => width >= value).length];
  assert(count >= 2, 'at least two board columns at ' + width);
  if (width < 600) assert.equal(count, 2, 'narrow board grids stay two columns at ' + width);
  const cardWidth = (width - (count - 1) * 16) / count;
  assert(cardWidth > 0 && cardWidth <= 360, 'card width bounded at ' + width);
}
console.log('Following board: retained identity/state, duplicate prevention, symmetric board motion and responsive grid boundaries passed');
const syncStart = page.indexOf('  private syncUsername(): void {');
const syncEnd = page.indexOf('\n  onBack?', syncStart);
const PageHost = vm.runInNewContext(ts.transpileModule('class PageHost {' + page.slice(syncStart, syncEnd) + '} PageHost;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
let restores = 0;
const retainedPage = Object.assign(new PageHost(), { snapshot: { page: 'profile', mode: 'following', token: 8 },
  presentedPanelPage: 'profile', presentationMounted: true, presentationToken: 7, followerSearching: true,
  followerQuery: 'existing query', restorePresentation() { restores++; }, syncFollowingMotion() {}, scheduleFollowerEndCheck() {} });
retainedPage.syncUsername();
assert.equal(restores, 0, 'business token renewal must not pop an existing following search route or reset its scroll');
assert.equal(retainedPage.followerSearching, true); assert.equal(retainedPage.followerQuery, 'existing query');
assert.equal(retainedPage.presentationToken, 8);
retainedPage.presentedPanelPage = ''; retainedPage.syncUsername();
retainedPage.presentationToken = -1; retainedPage.syncUsername();
assert.equal(restores, 1, 'a fresh page still initializes presentation normally');
// Reuse the established network fixture, but execute only this task's real
// native close/restore/write lifecycle rather than unrelated settings cases.
const settingsSource = fs.readFileSync('scripts/check-native-profile-settings.cjs', 'utf8');
const createFixture = new Function('require', 'process', settingsSource.slice(0, settingsSource.indexOf('const draft=')) + '\nreturn fixture;')(require, process);
async function verifyRestore() {
  const f = createFixture();
  f.server.board.followed_by_me = true;
  await f.profile.open('following', 'boards');
  assert.equal(f.ps.panel.section, 'boards');
  const saved = f.ps.panel;
  const savedCard = saved.items[0];
  const savedCardIdentity = cardIdentity.call({ uiLanguage: 'zh' }, savedCard);
  const liveCard = Object.assign(new ItemHost(), { snapshot: saved });
  saved.scrollOffset = 188;
  const oldToken = saved.token;
  f.profile.close();
  const before = f.req.length;
  const restoring = f.profile.restore(saved);
  liveCard.snapshot = f.ps.panel;
  assert.equal(cardIdentity.call({ uiLanguage: 'zh' }, f.ps.panel.items[0]), savedCardIdentity, 'real restore keeps the cover node');
  assert.equal(liveCard.panelItem(savedCard).canFollow, false, 'retained card disables writes during real identity validation');
  assert.equal(f.ps.panel.scrollOffset, 188);
  assert.notEqual(f.ps.panel.token, oldToken, 'restore renews business token');
  assert(f.ps.panel.items.every(item => item.canFollow === false), 'writes wait for current identity');
  await restoring;
  liveCard.snapshot = f.ps.panel;
  assert.equal(cardIdentity.call({ uiLanguage: 'zh' }, f.ps.panel.items[0]), savedCardIdentity);
  assert.equal(liveCard.panelItem(savedCard).canFollow, true, 'retained card updates when real identity validation finishes');
  assert(f.ps.panel.items.every(item => item.canFollow === true), 'verified identity reactivates supported follow actions');
  assert(!f.req.slice(before).some(request => request.job.url.includes('/BoardsResource/')), 'return retains cards without reloading the board list');
  await f.profile.follow('300');
  liveCard.snapshot = f.ps.panel;
  assert.equal(cardIdentity.call({ uiLanguage: 'zh' }, f.ps.panel.items[0]), savedCardIdentity, 'confirmed follow change cannot rebuild the cover');
  assert.equal(liveCard.panelItem(savedCard).following, false, 'retained card receives the confirmed follow state');
  assert.equal(f.ps.panel.items[0].following, false, 'follow action remains functional after returning');
  console.log('Following board: actual native close/restore identity validation and confirmed follow write passed');
}
verifyRestore().catch(error => { console.error(error); process.exitCode = 1; });
