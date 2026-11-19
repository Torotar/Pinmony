const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { createSearchRuntime } = require('./search-controller-harness.cjs');
const { runtime } = require('./product-coordination-harness.cjs');
const { parseBoardPermalink } = createArktsLoader(ts).loadFile('common_network/src/main/ets/PinmonyBoardInviteLink.ets');
const { PinmonyNavigationCoordinator } = runtime(ts).loadFile('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets');
const page = 'https://www.pinterest.com/search/';
const board = 'https://www.pinterest.com/sample_user/my-board/';
assert.equal(parseBoardPermalink('https://uk.pinterest.com/sample_user/my-board?tracking=example#top'), board);
assert.equal(parseBoardPermalink('https://pinterest.com/sample_user/%E5%9B%BE%E6%9D%BF/'), 'https://www.pinterest.com/sample_user/%E5%9B%BE%E6%9D%BF/');
for (const input of [board + '?%69nvite_code=invalid', 'https://evil.test/sample_user/my-board/',
  'https://pinterest.com.evil.test/sample_user/my-board/', 'https://user@pinterest.com/sample_user/my-board/',
  'https://www.pinterest.com/search/pins/', 'https://www.pinterest.com/sample_user/_saved/',
  'https://www.pinterest.com/sample_user/%2e%2e/', 'https://www.pinterest.com/sample_user/%2Fextra/', board + 'section/']) {
  assert.equal(parseBoardPermalink(input), '', input);
}
function back({ focused = false, root = false, route = page, pendingBoard = '' } = {}) {
  const events = [];
  const nav = Object.create(PinmonyNavigationCoordinator.prototype);
  Object.assign(nav, { profileStore: { origins: [] }, inboxStore: {}, boardStore: { pendingBoardUrl: pendingBoard },
    pinStore: {}, searchStore: { searchInputFocused: focused }, ports: new Proxy({
      pageHistory: () => ({ isPending: () => false }), nativeChildBackUntil: () => 0, authStatus: () => 'authenticated',
      activeTab: () => 1, nativeRootTabsVisible: () => root, nativeSearchPageVisible: () => !pendingBoard,
      currentSearchPageKey: () => route, rootBack: () => { events.push('exit'); return true; },
      backFromSearch: () => events.push('search'), backFromBoard: () => events.push('board')
    }, { get: (target, key) => target[key] || (() => '') }) });
  assert.equal(nav.onBackPress(), true);
  return events;
}
assert.deepEqual(back(), ['exit']);
assert.deepEqual(back({ root: true, focused: true }), ['search']);
assert.deepEqual(back({ root: true, route: page + 'pins/?q=art' }), ['search']);
assert.deepEqual(back({ pendingBoard: board }), ['board']);
async function main() {
  const opened = [];
  const h = createSearchRuntime(ts).harness({ resolver: undefined, nativeSearch: () => true,
    openSubmittedPin: () => assert.fail('board is not a Pin'),
    openSubmittedBoard: (target, source) => { opened.push([target, source]); return true; },
    resolveSubmittedLink: async () => ({ kind: 'board', boardUrl: board }) });
  const source = 'https://www.pinterest.com/search/pins/?q=art';
  h.store.search = { kind: 'state', session: 2, pageKey: source, query: 'art', categories: [], suggestions: [], results: [], heroes: [], ideaSections: [] };
  h.store.searchNativeInputReady = true;
  await h.controller.submitSearch(board + '?tracking=example');
  await h.controller.submitSearch('https://pin.it/Example');
  h.store.search = undefined;
  h.store.searchNativeInputReady = false;
  await h.controller.submitSearch(board);
  assert.deepEqual(opened, [[board, source], [board, source], [board, source]]);
  const index = require('node:fs').readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert.match(index, /if \(!PIN_NATIVE_SEARCH_READS_ENABLED && [^\n]*currentSearchPageKey\(\)[\s\S]*?this.searchStore.searchOpenHistory\(\)/);
  assert.equal(h.events.some(e => e[0] === 'search'), false);
  const own = createSearchRuntime(ts).harness({ nativeSearch: () => true, openSubmittedPin: () => assert.fail(),
    resolveSubmittedLink: async () => ({ kind: 'own-shared-board', boardUrl: board }),
    openSubmittedBoard: (url, source, ownShare) => {
      assert.deepEqual([url, source, ownShare], [board, page, true]); return false;
    } });
  own.setPage(page);
  await own.controller.submitSearch('https://pin.it/Example');
  assert.equal(own.store.failedSubmittedLinkPage, page, 'owner gate rejection stays in the search failure state');
  assert.match(index, /if \(ownShare\) \{\s*const profile: string = searchProfileLink\(this.authenticatedProfileUrl\);\s*if \(!profile \|\| !permalink.toLowerCase\(\).startsWith\(profile.toLowerCase\(\)\)\) return false;/);
  const searchPage = require('node:fs').readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
  assert.match(searchPage, /if \(editing \|\| this.showingSubmittedLinkResult\(\) \|\|/);
  assert.match(searchPage, /if \(this.showingSubmittedLinkResult\(\) && !this.inputEditing\) \{\s*this.onRootBack\?\.\(\);/);
  assert.match(searchPage, /private beginSearchInput\(\): void \{\s*if \([^\n]*this.showingSubmittedLinkResult\(\)\) return;/);
  const failing = createSearchRuntime(ts).harness({ nativeSearch: () => true, openSubmittedPin: () => assert.fail('unresolved link must not open'),
    resolveSubmittedLink: async () => { throw Error('unresolved'); } });
  failing.setPage(page);
  await failing.controller.submitSearch('https://pin.it/Example');
  assert.equal(failing.store.submittedPinLoading, false);
  assert.equal(failing.store.failedSubmittedLinkPage, page, 'failure is visible after loading ends');
  assert.equal(failing.controller.consumeFailedSubmittedLinkBack(), true, 'failed link owns the next back');
  assert.equal(failing.store.failedSubmittedLinkPage, '', 'back clears the visible failure');
  assert.equal(failing.controller.consumeFailedSubmittedLinkBack(), false, 'ordinary root back resumes afterwards');
  await failing.controller.submitSearch('https://pin.it/Example');
  failing.controller.invalidatePending();
  assert.equal(failing.controller.consumeFailedSubmittedLinkBack(), false, 'navigation invalidates old failure');
  assert.equal(h.controller.consumeFailedSubmittedLinkBack(), false, 'successful link does not intercept back');
  assert.match(index, /if \(this.backFromFailedSearchLink\(\)\) return true;\s*const handled: boolean = this.navigationCoordinator.onBackPress\(\)/);
  assert.match(searchPage, /bottomBuilder: \{ builder: this.showingSubmittedLinkResult\(\)/);
  console.log('Search board permalink and root/input/result/board back dispatch passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
