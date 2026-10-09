import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PinWebDetailSnapshot } from '../main/ets/models/PinWebDetail';
import { PinWebDetailCache } from '../main/ets/services/PinWebDetailCache';
import { PinWebNavigationHistory } from '../main/ets/services/PinWebNavigationHistory';
import { PinWebSearchCache } from '../main/ets/services/PinWebSearchCache';
import { PinWebSearchSnapshot } from '../main/ets/models/PinWebSearch';
import { PinWebSearchResult } from '../main/ets/models/PinWebSearch';
import { retainSearchResults, mergeSearchFeedResults, findSearchResult } from '../main/ets/services/PinWebSearchRetention';

function searchPin(id: string, pinId: string): PinWebSearchResult {
  return { id: id, kind: 'pin', title: 'Pin ' + pinId, subtitle: '',
    targetUrl: 'https://www.pinterest.com/pin/' + pinId + '/',
    imageUrl: 'https://i.pinimg.com/' + pinId + '.jpg', imageWidth: 640,
    imageHeight: 960, enabled: true };
}

function searchSnapshot(pageKey: string, query: string): PinWebSearchSnapshot {
  return { kind: 'state', session: 1, pageKey: pageKey, query: query, placeholder: '',
    selectedCategory: '', categories: [], suggestions: [], heroes: [], ideaSections: [],
    results: query ? [searchPin('result', '123')] : [] };
}

function createDetail(pinId: string): PinWebDetailSnapshot {
  return {
    kind: 'state',
    session: 1,
    pinUrl: `https://www.pinterest.com/pin/${pinId}/`,
    imageUrl: 'https://i.pinimg.com/originals/sample.jpg',
    imageWidth: 640,
    imageHeight: 960,
    title: `Pin ${pinId}`,
    description: 'Cached description',
    creator: 'Creator',
    creatorAvatar: 'https://i.pinimg.com/avatars/sample.jpg',
    sourceLabel: 'Source',
    actions: [{ id: `live-action-${pinId}`, kind: 'like', label: '赞', countText: '12',
      enabled: true, selected: false }],
    related: [{ id: `live-related-${pinId}`, pinUrl: 'https://www.pinterest.com/pin/999/',
      imageUrl: 'https://i.pinimg.com/originals/related.jpg', title: 'Related',
      imageWidth: 640, imageHeight: 960 }]
  };
}

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('cachesDisplayDataWithNonExecutableActionIds', 0, () => {
      const cache: PinWebDetailCache = new PinWebDetailCache();
      const detail: PinWebDetailSnapshot = createDetail('123');
      cache.put('123', detail, 48);
      const entry = cache.get('123');
      expect(entry !== undefined).assertTrue();
      if (entry) {
        expect(entry.detail.title).assertEqual('Pin 123');
        expect(entry.scrollOffset).assertEqual(48);
        expect(entry.detail.session).assertEqual(0);
        expect(entry.detail.actions[0].id === detail.actions[0].id).assertFalse();
        expect(entry.detail.actions[0].enabled).assertFalse();
        expect(entry.detail.related[0].id === detail.related[0].id).assertFalse();
      }
    });

    it('evictsLeastRecentlyUsedEntryAfterTenPins', 0, () => {
      const cache: PinWebDetailCache = new PinWebDetailCache();
      for (let index: number = 1; index <= 10; index++) {
        cache.put(index.toString(), createDetail(index.toString()), 0);
      }
      cache.get('1');
      cache.put('11', createDetail('11'), 0);
      expect(cache.size()).assertEqual(10);
      expect(cache.get('2') === undefined).assertTrue();
      expect(cache.get('1') !== undefined).assertTrue();
      expect(cache.get('11') !== undefined).assertTrue();
    });

    it('updatesScrollPositionAndStartsEmptyForNewRuntime', 0, () => {
      const cache: PinWebDetailCache = new PinWebDetailCache();
      cache.put('123', createDetail('123'), 0);
      cache.updateScrollOffset('123', 256);
      const entry = cache.get('123');
      expect(entry !== undefined).assertTrue();
      if (entry) expect(entry.scrollOffset).assertEqual(256);
      expect(new PinWebDetailCache().size()).assertEqual(0);
    });

    it('returnsThroughSearchProfileBoardAndPinOnePageAtATime', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      const pages: string[] = ['https://www.pinterest.com/',
        'https://www.pinterest.com/search/', 'https://www.pinterest.com/search/pins/?q=art',
        'https://www.pinterest.com/creator/', 'https://www.pinterest.com/creator/art/',
        'https://www.pinterest.com/pin/123/'];
      pages.forEach((page: string) => history.visit(page));
      for (let index: number = pages.length - 2; index >= 0; index--) {
        const target: string = history.prepareBack();
        expect(target).assertEqual(pages[index]);
        history.visit(target);
      }
      expect(history.prepareBack()).assertEqual('');
    });

    it('retainsParentUntilBackConfirmsAndRejectsRepeatedBack', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      history.visit('https://www.pinterest.com/inbox/');
      history.visit('https://www.pinterest.com/messages/42/');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/inbox/');
      expect(history.prepareBack()).assertEqual('');
      history.cancelBack();
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/inbox/');
      history.visit('https://www.pinterest.com/inbox/');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/');
    });

    it('doesNotAddReloadsRedirectParametersOrReversedPopRoutes', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      history.visit('https://www.pinterest.com/search/');
      history.visit('https://www.pinterest.com/pin/123/?source=search');
      history.visit('https://www.pinterest.com/pin/123/');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/search/');
      history.visit('https://www.pinterest.com/search/', 'pop');
      history.visit('https://www.pinterest.com/search/pins/?q=old');
      history.visit('https://www.pinterest.com/search/pins/?q=new', 'replace');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/search/');
    });

    it('clearsOldChildrenWhenNavigatingToHome', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      history.visit('https://www.pinterest.com/creator/');
      history.visit('https://www.pinterest.com/settings/');
      history.visit('https://www.pinterest.com/');
      expect(history.prepareBack()).assertEqual('');
      history.visit('https://www.pinterest.com/search/');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/');
    });

    it('retainsParentWhenRouterReplacesAPathWithAChildPage', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      history.visit('https://www.pinterest.com/creator/');
      history.visit('https://www.pinterest.com/creator/art/', 'replace');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/creator/');
    });

    it('ignoresOldPinCallbacksDuringAndAfterReturningToResults', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      const landing: string = 'https://www.pinterest.com/search/';
      const results: string = 'https://www.pinterest.com/search/pins/?q=art';
      const pin: string = 'https://www.pinterest.com/pin/123/';
      history.visit(landing, 'load');
      history.visit(results, 'push');
      for (let index: number = 0; index < 2; index++) {
        history.visit(pin, 'push');
        expect(history.prepareBack()).assertEqual(results);
        history.visit(pin, 'observe');
        history.visit(pin, 'load');
        expect(history.isPending()).assertTrue();
        history.visit(results, 'load');
        history.visit(pin, 'observe');
        expect(history.isPending()).assertFalse();
      }
      expect(history.prepareBackTo(landing)).assertEqual(landing);
      history.visit(results, 'observe');
      history.visit(landing, 'load');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/');
    });

    it('returnsToSearchLandingWithoutARecordedLandingAncestor', 0, () => {
      const history: PinWebNavigationHistory = new PinWebNavigationHistory();
      const results: string = 'https://www.pinterest.com/search/pins/?q=art';
      const landing: string = 'https://www.pinterest.com/search/';
      history.visit(results, 'load');
      history.visit('https://www.pinterest.com/pin/123/', 'load');
      expect(history.prepareBack()).assertEqual(results);
      history.visit(results, 'pop');
      expect(history.prepareBackTo(landing)).assertEqual(landing);
      history.visit(landing, 'load');
      expect(history.prepareBack()).assertEqual('https://www.pinterest.com/');
    });

    it('keepsSearchLandingAndResultsAsSeparateRuntimeSnapshots', 0, () => {
      const cache: PinWebSearchCache = new PinWebSearchCache();
      const landing: PinWebSearchSnapshot = searchSnapshot('https://www.pinterest.com/search/', '');
      const results: PinWebSearchSnapshot = searchSnapshot('https://www.pinterest.com/search/pins/?q=art', 'art');
      cache.put(landing, 128);
      cache.put(results, 640);
      cache.updateScrollOffset(landing.pageKey, 256);
      const cachedLanding = cache.get(landing.pageKey);
      const cachedResults = cache.get(results.pageKey);
      expect(cachedLanding !== undefined).assertTrue();
      expect(cachedResults !== undefined).assertTrue();
      if (cachedLanding) {
        expect(cachedLanding.snapshot.query).assertEqual('');
        expect(cachedLanding.scrollOffset).assertEqual(256);
      }
      if (cachedResults) {
        expect(cachedResults.snapshot.results[0].targetUrl).assertEqual(results.results[0].targetUrl);
        expect(cachedResults.scrollOffset).assertEqual(640);
      }
      expect(new PinWebSearchCache().get(landing.pageKey) === undefined).assertTrue();
    });

    it('doesNotOverwriteSearchCacheWithLoadingAndEvictsOldestRoute', 0, () => {
      const cache: PinWebSearchCache = new PinWebSearchCache();
      const landing: PinWebSearchSnapshot = searchSnapshot('https://www.pinterest.com/search/', '');
      cache.put(landing, 128);
      const loading: PinWebSearchSnapshot = searchSnapshot(landing.pageKey, '');
      loading.kind = 'loading';
      cache.put(loading, 0);
      expect(cache.get(landing.pageKey)?.scrollOffset).assertEqual(128);
      for (let index: number = 1; index <= 10; index++) {
        cache.put(searchSnapshot('https://www.pinterest.com/search/pins/?q=' + index.toString(), index.toString()), 0);
      }
      expect(cache.get(landing.pageKey) === undefined).assertTrue();
    });

    it('keepsSearchOrderAndArtworkWhileRebindingFreshControls', 0, () => {
      const previous: PinWebSearchResult[] = [searchPin('old-a', '1'), searchPin('old-b', '2')];
      const live: PinWebSearchResult[] = [searchPin('new-b', '2'), searchPin('new-a', '1'), searchPin('new-c', '3')];
      live[1].imageUrl = 'https://i.pinimg.com/changed.jpg';
      const retained = retainSearchResults(previous, live);
      expect(retained.length).assertEqual(2);
      expect(retained[0].targetUrl).assertEqual(previous[0].targetUrl);
      expect(retained[0].imageUrl).assertEqual(previous[0].imageUrl);
      expect(retained[0].id).assertEqual('new-a');
      expect(retained[1].id).assertEqual('new-b');
    });

    it('keepsMissingSearchPinsWithNonLiveIdsForUrlNavigation', 0, () => {
      const retained = retainSearchResults([searchPin('old-a', '1'), searchPin('old-b', '2')], []);
      expect(retained.length).assertEqual(2);
      expect(retained[0].id.startsWith('cached-search:')).assertTrue();
      expect(retained[0].enabled).assertTrue();
      expect(retained[1].targetUrl).assertEqual('https://www.pinterest.com/pin/2/');
    });

    it('keepsUpperPostsWhenTheWebpageUnmountsAnEntireWindow', 0, () => {
      const previous: PinWebSearchResult[] = [searchPin('old-a', '1'), searchPin('old-b', '2')];
      const nextWindow = mergeSearchFeedResults(previous, [searchPin('new-c', '3'), searchPin('new-d', '4')]);
      expect(nextWindow.length).assertEqual(4);
      expect(nextWindow[0].targetUrl).assertEqual(previous[0].targetUrl);
      expect(nextWindow[0].id.startsWith('cached-search:')).assertTrue();
      expect(nextWindow[0].enabled).assertTrue();
      expect(nextWindow[3].targetUrl).assertEqual('https://www.pinterest.com/pin/4/');
      const emptyWindow = mergeSearchFeedResults(nextWindow, []);
      expect(emptyWindow.length).assertEqual(4);
      const remounted = mergeSearchFeedResults(emptyWindow, [searchPin('remount-a', '1')]);
      expect(remounted.length).assertEqual(4);
      expect(remounted[0].id).assertEqual('remount-a');
    });

    it('opensPostsByLinkEvenWhenTheDomControlIsDisabled', 0, () => {
      const item: PinWebSearchResult = searchPin('not-ready-node', '1');
      item.enabled = false;
      const merged = mergeSearchFeedResults([], [item]);
      expect(merged[0].enabled).assertTrue();
      expect(merged[0].targetUrl).assertEqual('https://www.pinterest.com/pin/1/');
    });

    it('deduplicatesPinTrackingUrlsAndKeepsDifferentSearchLinks', 0, () => {
      const original: PinWebSearchResult = searchPin('old', '1');
      const tracked: PinWebSearchResult = searchPin('new', '1');
      tracked.targetUrl += '?source=search';
      const firstSearch: PinWebSearchResult = searchPin('query-a', '2');
      firstSearch.kind = 'other';
      firstSearch.targetUrl = 'https://www.pinterest.com/search/pins/?q=art';
      const secondSearch: PinWebSearchResult = searchPin('query-b', '3');
      secondSearch.kind = 'other';
      secondSearch.targetUrl = 'https://www.pinterest.com/search/pins/?q=design';
      const merged = mergeSearchFeedResults([original, firstSearch], [tracked, secondSearch]);
      expect(merged.length).assertEqual(3);
      expect(merged[0].id).assertEqual('new');
    });

    it('resolvesCardClicksByLinkAfterItsControlIdChanges', 0, () => {
      const original: PinWebSearchResult = searchPin('old-dom-id', '123');
      const live: PinWebSearchResult = searchPin('new-dom-id', '123');
      const merged = mergeSearchFeedResults([original], [live]);
      const target = findSearchResult(merged, original.targetUrl);
      expect(target !== undefined).assertTrue();
      if (target) expect(target.id).assertEqual('new-dom-id');
      const tracked = findSearchResult(merged, original.targetUrl + '?source=old-card');
      expect(tracked !== undefined).assertTrue();
    });

    it('correctsCachedTitlesWhileKeepingTheCardPosition', 0, () => {
      const original: PinWebSearchResult = searchPin('old', '123');
      original.title = 'Incorrect neighboring title';
      const live: PinWebSearchResult = searchPin('new', '123');
      live.title = 'Title from this Pin';
      const merged = mergeSearchFeedResults([original, searchPin('other', '456')], [live]);
      expect(merged[0].title).assertEqual('Title from this Pin');
      expect(merged[1].targetUrl).assertEqual('https://www.pinterest.com/pin/456/');
      live.title = '标题暂不可用';
      expect(mergeSearchFeedResults(merged, [live])[0].title).assertEqual('Title from this Pin');
    });
  });
}
