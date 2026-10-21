import { PinmonySearchStore, PinmonySearchPage, PinmonySearchSnapshot, PinmonySearchResult } from 'feature_search';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyAuthStatus } from 'common_session';

export interface PinmonySearchRootView {
  photoSearch: (onSelected?: (uri: string) => void) => Promise<PinmonySearchResult[] | undefined>;
  cancelPhotoSearch: () => void;
  openPhotoResult: (id: string) => void;
  searchStore: PinmonySearchStore;
  shouldKeepSearchRootMounted: () => boolean;
  pinStore: PinmonyPinStore;
  loadFailed: boolean;
  activeTab: number;
  authStatus: PinmonyAuthStatus;
  nativeRootOnly: boolean;
  rootContentInteracted: boolean;
  activeSheetKind: string;
  currentPinUrl: () => string;
  handleRootContentScroll: (offset: number, state: ScrollState) => void;
  searchPlaceholder: () => PinmonySearchSnapshot;
  currentSearchPageKey: () => string;
  syncFloatingTabsMotion: () => void;
  updateSearchQuery: (value: string, refreshSuggestions?: boolean) => Promise<void>;
  submitSearch: (value: string) => Promise<void>;
  performSearchAction: (id: string, kind: string) => Promise<void>;
  openSearchPinMenu: (pinUrl: string) => Promise<void>;
  loadMoreSearch: () => void;
  refreshSearch: () => Promise<void>;
  rootPullKind: string;
  pullRefreshRoot: (kind: string) => Promise<void>;
  returnFromSearchQuiz: () => boolean;
  backFromSearch: () => void;
  performSearchQuizAction: (kind: string, id: string) => Promise<void>;
  openSearchFilters: () => Promise<void>;
  shouldKeepSearchPageMounted: () => boolean;
  nativeSearchPageVisible: () => boolean;
  onTouch: (event: TouchEvent) => void;
  onContentInteracted: () => void;
}

@Builder
export function PinmonyBuildSearchRootContent(view: PinmonySearchRootView) {
          if (view.shouldKeepSearchRootMounted() && !view.pinStore.detail && !view.loadFailed) {
            PinmonySearchPage({
              onPhotoSearch: view.photoSearch,
              onPhotoCancel: view.cancelPhotoSearch,
              onPhotoResult: view.openPhotoResult,
              onPhotoVisibilityChange: (visible: boolean) => {
                view.searchStore.photoSearchVisible = visible;
                view.syncFloatingTabsMotion();
              },
              active: view.nativeSearchPageVisible(),
              interactionReady: view.activeTab === 1 && view.authStatus === 'authenticated',
              automaticLoadingEnabled: view.activeTab === 1 && (!view.nativeRootOnly || view.rootContentInteracted),
              mediaActive: view.activeTab === 1 && view.pinStore.videoForeground && !view.activeSheetKind && !view.pinStore.detail && !view.currentPinUrl(),
              onContentScroll: (offset: number, state: ScrollState) => view.handleRootContentScroll(offset, state),
              snapshot: view.searchStore.search || view.searchPlaceholder(),
              initialHeroId: view.searchStore.searchCache.heroPosition(view.searchStore.search?.pageKey || ''),
              onHeroPosition: (pageKey: string, id: string) => {
                const snapshot: PinmonySearchSnapshot | undefined = view.searchStore.search;
                if (snapshot?.pageKey === pageKey) view.searchStore.searchCache.rememberHero(snapshot, id);
              },
              resultsReadsReady: view.activeTab === 1 && view.searchStore.searchNativeReadsReady,
              discoveryReadsReady: view.activeTab === 1 && view.searchStore.searchDiscoveryReadsReady,
              actionsReady: view.activeTab === 1 && view.searchStore.searchActionsReady &&
                view.searchStore.search?.pageKey === view.currentSearchPageKey(),
              initialResultsScrollOffset: view.searchStore.searchScrollOffset,
              onResultsScrollPosition: (pageKey: string, offset: number) => {
                if (view.currentSearchPageKey() !== pageKey || view.currentPinUrl() || view.pinStore.detail) return;
                view.searchStore.searchCache.updateScrollOffset(pageKey, offset);
                if (view.searchStore.search?.pageKey === pageKey) view.searchStore.searchScrollOffset = offset;
                if (view.searchStore.retainedSearch?.pageKey === pageKey) view.searchStore.retainedSearchScrollOffset = offset;
              },
              loading: view.searchStore.searchLoading,
              error: view.searchStore.searchError,
              onQueryChange: (value: string, refreshSuggestions?: boolean) => view.updateSearchQuery(value, refreshSuggestions === true),
              onSubmit: (value: string) => view.submitSearch(value),
              onCategory: (id: string) => view.performSearchAction(id, 'category'),
              onSuggestion: (id: string) => view.performSearchAction(id, 'suggestion'),
              historyActionsReady: view.activeTab === 1 && view.authStatus === 'authenticated' && (view.searchStore.searchNativeInputReady || view.searchStore.searchInputReady || view.searchStore.searchActionsReady),
              onDeleteHistory: (id: string) => view.performSearchAction(id, 'deleteHistory'),
              onClearProductFilter: (kind: string) => view.performSearchAction(kind, 'clearProductFilter'),
              onFollowUser: (id: string) => view.performSearchAction(id, 'followUser'),
              onFollowBoard: (id: string) => view.performSearchAction(id, 'followBoard'),
              onResult: (id: string) => view.performSearchAction(id, 'result'),
              onMore: (url: string) => view.openSearchPinMenu(url),
              onExploreAction: (id: string, kind: string) => view.performSearchAction(id, kind),
              onLoadMore: () => { view.onContentInteracted(); view.loadMoreSearch(); },
              onRetry: () => view.refreshSearch(),
              refreshing: view.rootPullKind === 'search',
              onRefresh: () => view.pullRefreshRoot('search'),
              onBack: () => {
                if (!view.returnFromSearchQuiz()) view.backFromSearch();
              },
              onQuizAction: (kind: string, id: string) => view.performSearchQuizAction(kind, id),
              onFilters: () => view.openSearchFilters(),
              onInputFocusChange: (focused: boolean, stopEditing: () => void) => {
                const visible: boolean = view.shouldKeepSearchPageMounted();
                view.searchStore.searchInputFocused = visible && focused;
                view.searchStore.searchInputStopEditing = visible && focused ? stopEditing : undefined;
                view.syncFloatingTabsMotion();
              },
              onHistoryReturnReady: (openHistory?: () => void) => {
                view.searchStore.searchOpenHistory = openHistory;
              }
            })
            .width('100%')
            .height('100%')
            .visibility(view.nativeSearchPageVisible() ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(view.nativeSearchPageVisible() ? HitTestMode.Default : HitTestMode.None)
            .onTouch((event: TouchEvent) => view.onTouch(event))
          }


}
