import { PinmonyPinStore } from 'feature_pin';
import { PinmonyHomeStore, PinmonyHomeSnapshot, PinmonyHomePage } from 'feature_home';
import { NetworkManager } from 'common_network';
import { PinmonyAuthStatus } from 'common_session';
import { PIN_NATIVE_PIN_MENUS_ENABLED } from '../app/PinmonyPinMenuNative';

export interface PinmonyHomeRootView {
  homePresentationPageKey: () => string;
  retainedHomeRootPageKey: () => string;
  nativeRootOnly: boolean;
  homeStore: PinmonyHomeStore;
  pinStore: PinmonyPinStore;
  rootContentInteracted: boolean;
  activeTab: number;
  activeSheetKind: string;
  currentPinUrl: () => string;
  handleRootContentScroll: (offset: number, state: ScrollState) => void;
  homePlaceholder: () => PinmonyHomeSnapshot;
  pendingWebTab: number;
  currentHomePageKey: () => string;
  authStatus: PinmonyAuthStatus;
  homeMenuReady: () => boolean;
  offlinePreviewMode: boolean;
  selectHomeTab: (id: string, restoring?: boolean) => Promise<void>;
  openHomePin: (id: string) => Promise<void>;
  openHomeBoard: (id: string) => void;
  openHomeMore: (id: string) => Promise<void>;
  loadMoreHome: () => Promise<void>;
  refreshHome: () => void;
  retryHome: () => void;
  prefetchHomePinDetails: (first: number, last: number) => void;
  onTouch: (event: TouchEvent) => void;
}

@Builder
export function PinmonyBuildHomeRootContent(view: PinmonyHomeRootView) {
          if ((view.homePresentationPageKey() || view.retainedHomeRootPageKey()) &&
              (!view.nativeRootOnly || view.homeStore.home || view.homeStore.cachedHome)) {
            PinmonyHomePage({
              imageRecovery: view.homeStore.imageRecovery,
              prefetchedImageUrls: view.pinStore.prefetchedImageUrls,
              feedActive: (view.homeStore.homeNativeReadsReady || !view.nativeRootOnly || view.rootContentInteracted) && view.activeTab === 0 && view.pinStore.videoForeground && !view.activeSheetKind && !view.pinStore.detail && !view.pinStore.detailOpeningPin && (view.homeStore.homeNativeReadsReady || !view.currentPinUrl()),
              mediaActive: view.activeTab === 0 && view.pinStore.videoForeground && !view.activeSheetKind && !view.pinStore.detail && !view.pinStore.detailOpeningPin && !view.currentPinUrl(),
              onContentScroll: (offset: number, state: ScrollState) => view.handleRootContentScroll(offset, state),
              home: view.homeStore.homeForPresentation(view.homePresentationPageKey() || view.retainedHomeRootPageKey()) || view.homePlaceholder(),
              actionsReady: view.activeTab === 0 && (view.homeStore.homeNativeReadsReady || view.homeStore.homeActionsReady && view.pendingWebTab !== 0 &&
                view.currentHomePageKey() === (view.homePresentationPageKey() || view.retainedHomeRootPageKey())),
              navigationReady: view.activeTab === 0 && !!view.homeStore.homeForPresentation(
                view.homePresentationPageKey() || view.retainedHomeRootPageKey()) &&
                view.authStatus === 'authenticated',
              interactionReady: view.activeTab === 0 && view.authStatus === 'authenticated',
              menuReady: view.homeMenuReady(),
              paginationReady: view.authStatus === 'authenticated' && !view.offlinePreviewMode &&
                (view.homeStore.homeNativeReadsReady || view.homeStore.homeActionsReady),
              initialScrollOffset: view.homeStore.cachedHomeScrollOffset,
              pendingTabId: view.homeStore.pendingHomeTab,
              menuLoadingId: PIN_NATIVE_PIN_MENUS_ENABLED ? '' : view.homeStore.homeMoreLoadingId,
              loading: view.homeStore.homeLoading ||
                !view.homeStore.homeForPresentation(view.homePresentationPageKey() || view.retainedHomeRootPageKey()) && !view.homeStore.homeError,
              // A retained snapshot is immediately usable for display while
              // the hidden Web document re-confirms the current session. Keep
              // controls gated by actionsReady, but do not replace visible
              // cards with a recovery banner on every root-tab return.
              synchronizing: view.activeTab !== 0 || !!view.homeStore.pendingHomeTab ||
                ((view.pendingWebTab === 0 || !view.homeStore.homeActionsReady) &&
                  !view.homeStore.homeForPresentation(view.homePresentationPageKey() || view.retainedHomeRootPageKey())),
              offlinePreview: view.offlinePreviewMode,
              refreshing: view.homeStore.homeRefreshing,
              error: view.homeStore.homeError,
              onTab: (id: string) => view.selectHomeTab(id),
              onPin: (id: string) => view.openHomePin(id),
              onBoard: (id: string) => view.openHomeBoard(id),
              onMore: (id: string) => view.openHomeMore(id),
              onLoadMore: () => view.loadMoreHome(),
              onPrefetchMore: () => {
                if (NetworkManager.allowsSpeculativeRequests()) view.loadMoreHome();
              },
              onRefresh: () => view.refreshHome(),
              onPrefetchPins: (first: number, last: number) => view.prefetchHomePinDetails(first, last),
              onScrollPosition: (pageKey: string, offset: number) => {
                if (view.homeStore.cachedHome?.pageKey === pageKey) view.homeStore.cachedHomeScrollOffset = offset;
              },
              onRetry: () => view.retryHome()
            })
            .width('100%')
            .height('100%')
            .visibility(view.activeTab === 0 ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(view.activeTab === 0 ? HitTestMode.Default : HitTestMode.None)
            .onTouch((event: TouchEvent) => view.onTouch(event))
          }


}
