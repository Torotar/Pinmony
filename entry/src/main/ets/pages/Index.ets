import { PinWebSystemActions } from '../app/PinWebSystemActions';
import { PinWebSearchController, PinWebSearchPorts } from 'feature_search';
import { pinWebDocumentStartScripts } from '../app/PinWebScriptRegistry';
import { readRelatedPresentation, RelatedPresentation } from 'feature_pin';
import { LruCache } from 'common_foundation';
import { PinWebPublishFlow, PinWebPublishPage, PIN_PUBLISH_API_SCRIPT, PinWebPublishPhoto, pickPublishPhotoUris, readPublishPhoto } from 'feature_profile';
import { PinWebImageCrop, PinWebVisualResult, emptyVisualResult, PIN_VISUAL_SEARCH_API_ENABLED, PIN_VISUAL_SEARCH_API_SCRIPT } from 'feature_pin';
import { PinWebProfilePanel, PinWebProfilePanelPage } from 'feature_profile';
import { PinWebPinStore } from 'feature_pin';
import { PinWebDetailTrace } from 'feature_pin';
import { PinWebBoardStore } from 'feature_board';
import { PinWebProfileStore } from 'feature_profile';
import { PinWebInboxStore } from 'feature_inbox';
import { PinWebSearchStore } from 'feature_search';
import { PinWebHomeStore } from 'feature_home';
import { ShareSheetOption, ShareSheetMessage, MoreSheetOption, MoreSheetMessage } from 'feature_pin';
import { PinWebNativeNetwork, PinWebNetworkContext, PinWebNetworkJob, PinWebNetworkReply, PIN_NATIVE_NETWORK_ENABLED, useNativeTransport, acceptsNetworkJob } from 'common_network';
import { PinWebShareBridge } from '../app/PinWebShareBridge';




import { ApiCache, buildCacheKey, CACHE_TTL, hashCacheString, PinWebRuntimeLog, PinWebTaskRegistry } from 'common_foundation';

import { webview } from '@kit.ArkWeb';
import { PinWebAuthMessage, PinWebAuthStatus, acceptsAuthMessage, isPinterestAuthRoute } from 'common_session';
import { PINTEREST_LOGIN_URL } from 'common_session';
import { PinWebStatusPage } from 'common_ui';
import { PIN_BOARD_API_ENABLED } from 'feature_board';
import { PinWebBoardDetail, PinWebBoardPin } from 'feature_board';
import { PinWebBoardPage } from 'feature_board';
import { PinWebSettingsPage, PinWebSettingsStore, PinWebAccountSettings, PIN_ACCOUNT_SETTINGS_SCRIPT, PIN_NOTIFICATIONS_READ_SCRIPT, NotificationResult } from 'feature_settings';
import { PIN_LOGOUT_API_ENABLED, logoutRequestBody, logoutResponseSucceeded } from 'feature_settings';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';


import { image } from '@kit.ImageKit';
import { HdsTabs, HdsTabsController, HdsAnimationMode, hdsMaterial, HdsSnackBar, SnackBarOperationType } from '@kit.UIDesignKit';
import { PinWebDetailPage } from 'feature_pin';
import { PinWebDetailAction, PinWebDetailSnapshot, PinWebRelatedPin } from 'feature_pin';

import { PIN_DETAIL_API_ENABLED } from 'feature_pin';


import { PIN_POST_API_ENABLED } from 'feature_pin';
import { PIN_POST_EXTENSIONS_ENABLED } from 'feature_pin';
import { PIN_EDIT_API_ENABLED } from 'feature_pin';
import { PinWebEditPinResult } from 'feature_pin';
import { PinWebEditPinSheet } from 'feature_pin';

import { PinWebCommentResult, PinWebPostResult, PinWebSaveResult } from 'feature_pin';
import { PinWebSaveSheet } from 'feature_pin';
import { PinWebHomeMenuOption, PinWebHomeMenuState } from 'feature_home';
import { PinWebHomeMenuSheet } from 'feature_home';
import { PinWebCommentsSheet } from 'feature_pin';
import { retainDetailPresentation } from 'feature_pin';
import { PinWebNavigationHistory } from '../app/PinWebNavigationHistory';

import { PinWebProfilePage } from 'feature_profile';


import { PinWebPublishSheet } from 'feature_profile';
import { PinWebProfileAction, PinWebBoard, PinWebCreatedPin, PinWebProfileSnapshot,
  PinWebOrganizeBoard, PinWebPublishOption, PinWebPublishSnapshot } from 'feature_profile';

import { PIN_PROFILE_API_ENABLED } from 'feature_profile';

import { PinWebHomeBoard, PinWebHomePin, PinWebHomeSnapshot, PinWebHomeTab } from 'feature_home';
import { PinWebHomePage } from 'feature_home';

import { PIN_HOME_API_ENABLED } from 'feature_home';
import { retainHomePins } from 'feature_home';
import { PinWebInboxPage } from 'feature_inbox';
import { PinWebInboxItem, PinWebInboxSnapshot } from 'feature_inbox';



import { PIN_INBOX_CONVERSATIONS_API_ENABLED } from 'feature_inbox';
import { PinWebInboxFlowSnapshot } from 'feature_inbox';
import { PinWebInboxFlowPage } from 'feature_inbox';
import { PinWebSearchPage } from 'feature_search';
import { PinWebSearchFilterOption, PinWebSearchResult, PinWebSearchSnapshot } from 'feature_search';








interface PinWebProfileSaveResult { pending?: boolean; ok?: boolean; duplicate?: boolean; message?: string; username?: string; }
interface PinWebDetailReadData { options: PinWebDetailReadOptions; }
interface PinWebDetailReadOptions { id: string; field_set_key: string; }

interface PendingDetailLike {
  id: string;
  pinUrl: string;
  session: number;
  selected: boolean;
  countText: string;
}

interface PinWebHomeCacheRecord {
  snapshot: PinWebHomeSnapshot;
}

interface PinWebHomeCacheKeyParams {
  pageKey: string;
}

interface PinWebOfflineHomeMarker {
  partitionId: string;
  pageKey: string;
  savedAtMs: number;
}

const PINWEB_HOME_OFFLINE_MARKER: string = 'pinwebHomeOfflineMarker';
const PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY: string = 'offline_home_marker';
const PINWEB_HOME_OFFLINE_MARKER_TTL: number = CACHE_TTL.userProfile;

const PINTEREST_URL: string = 'https://www.pinterest.com/';
// Secondary page insertion/removal only; root tabs and data refreshes do not animate.
const NATIVE_PAGE_TRANSITION: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut }),
  TransitionEffect.translate({ x: '100%' }).animation({ duration: 150, curve: Curve.EaseIn })
);
const BOARD_PAGE_TRANSITION: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.translate({ x: '100%' }).animation({ duration: 150, curve: Curve.EaseOut }),
  TransitionEffect.translate({ x: '100%' }).animation({ duration: 120, curve: Curve.EaseIn })
);

interface PinWebSaveIdentity { id: string; }

interface NativeCommentWrite {
  action: string;
  id: string;
  text: string;
  imageUri?: string;
  signature?: string;
}

@Entry
@Component
struct Index {
  private nativeChildBackUntil: number = 0;
  @State private exportingRuntimeLog: boolean = false;

  private traceAction(name: string, detail: string = ''): void {
    if (name !== 'root.tab') this.rootContentInteracted = true;
    if (/\.pin\.open$/.test(name)) this.detailClickedAt = Date.now();
    if (/^detail\.action\.(like|comment|save|share|more)$/.test(name)) this.detailJourney.mark(name + '.clicked', false);
    PinWebRuntimeLog.info('ActionTrace: click ' + name + (detail ? ' detailLength=' + detail.length.toString() : ''));
  }
  private readonly documentStartScripts: ScriptItem[] = pinWebDocumentStartScripts();
  private readonly nativeNetwork: PinWebNativeNetwork = new PinWebNativeNetwork();
  private readonly detailReadNetwork: PinWebNativeNetwork = new PinWebNativeNetwork();
  private readonly pageTasks: PinWebTaskRegistry = new PinWebTaskRegistry();
  private detailOpenedAt: number = 0;
  private detailClickedAt: number = 0;
  private readonly detailJourney: PinWebDetailTrace = new PinWebDetailTrace();
  private readonly detailReturnJourney: PinWebDetailTrace = new PinWebDetailTrace();
  private readonly detailRequestOwners: Map<string, number> = new Map<string, number>();
  private detailImageLoadedUrl: string = '';
  private detailImageFailedUrl: string = '';
  private detailImageBinding: string = '';
  private detailImageSignal: string = '';
  private detailImageBridgeAttempts: number = 0;
  private detailImageTimer: number = -1;
  private detailCommentsMeasured: boolean = false;
  private detailRelatedMeasured: boolean = false;
  private sharedDetailRequestId: string = '';
  private openingRelated: Promise<PinWebNetworkReply> | undefined = undefined;
  private openingRelatedToken: number = -1;
  private detailDocumentBinding: string = '';
  private detailDocumentProbeTimer: number = -1;
  private returnLoadToken: number = -1;
  private readonly detailReturnReads: LruCache<string> = new LruCache<string>(24, 300000);
  private detailReturnReadPin: string = '';
  @State private pinStore: PinWebPinStore = new PinWebPinStore();
  @State private boardStore: PinWebBoardStore = new PinWebBoardStore();
  @State private settingsStore: PinWebSettingsStore = new PinWebSettingsStore();
  @State private profileStore: PinWebProfileStore = new PinWebProfileStore();
  @State private inboxStore: PinWebInboxStore = new PinWebInboxStore();
  @State private searchStore: PinWebSearchStore = new PinWebSearchStore();
  @State private homeStore: PinWebHomeStore = new PinWebHomeStore();
  private pageLifecycleSequence: number = 0;
  private pageLifecycleStartedAt: number = 0;
  private pageLifecycleLastEventAt: number = 0;
  private homeApiCache: ApiCache | undefined = undefined;
  private homeCacheAccountId: string = '';
  private homeCacheIdentityEpoch: number = -1;
  private homeDiskCacheRestored: boolean = false;
  private homeDiskCacheRestoredAt: number = 0;
  private homeCacheRestoreAttemptKey: string = '';
  private homeStartupFeedCommitted: boolean = false;
  private homeCacheRestoreSkipReason: string = '';
  private offlineHomeMarker: PinWebOfflineHomeMarker | undefined = undefined;
  @State private offlinePreviewMode: boolean = false;
  @State private offlineCacheLoading: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private authStatus: PinWebAuthStatus = 'checking';
  private authEpoch: number = 0;
  private authCheckTimer: number = -1;
  private loginRedirectEpoch: number = -1;
  private logoutAwaitingLogin: boolean = false;
  private retainedHomeAwaitingAuth: boolean = false;
  private retainedHomeAwaitingFeed: boolean = false;
  private detailPrefetchTimer: number = -1;
  private authenticatedProfileUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private shareBridge: PinWebShareBridge = new PinWebShareBridge();
  private lastPageUrl: string = '';
  @State @Watch('syncFloatingTabsMotion') private navigationAddress: string = '';
  @State @Watch('syncFloatingTabsMotion') private nativeBackTarget: string = '';
  private backInProgress: boolean = false;
  private lastRootBackAt: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();
  private currentWebTab: number = 0;
  private pendingWebTab: number = -1;
  // Root-tab navigation can clear pendingWebTab before Web.onPageBegin fires.
  // Keep an independent route marker so a retained document is still guarded
  // and its native snapshot remains the first visible state.
  private retainedRootTabPending: number = -1;
  private retainedRootTabAddress: string = '';
  // A root-tab request can also be acknowledged by the hidden bridge before
  // the matching document begin arrives. Keep guarding late Pin callbacks
  // until the requested root document is observed or an explicit child/back
  // action supersedes the request.
  private rootTabGuardTarget: number = -1;
  private rootTabGuardAddress: string = '';
  private detailReturnedToRoot: boolean = false;
  @State private nativeRootOnly: boolean = false;
  private profilePublishPreparing: boolean = false;
  @State private rootContentInteracted: boolean = false;
  private retainedHomeDocumentPending: boolean = false;
  private retainedHomeDocumentAddress: string = '';
  private tabRequestToken: number = 0;
  private rootReadAddress: string = '';
  private rootReadToken: number = -1;
  private rootReadStartedAt: number = 0;
  @State private webPageLoading: boolean = false;
  @State private networkNotice: string = '';
  private networkNoticeTimer: number = -1;
  private webPageLoadFinishedAt: number = 0;
  private lastDocumentBeginUrl: string = '';
  private lastDocumentBeginAt: number = 0;
  private homeTracePageKey: string = '';
  private homeTraceCardsPageKey: string = '';
  private postSnack: HdsSnackBar | undefined = undefined;
  private postSnackToken: number = 0;
  @State private loadFailed: boolean = false;
  @State private failureDetails: string = '';
  @StorageLink('bottomBarScrollCollapseEnabled') @Watch('onBottomBarScrollSettingChanged')
  private bottomBarScrollCollapseEnabled: boolean = true;
  @State private floatingTabsHidden: boolean = false;
  @State private showNativeTabs: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private profileSettingsVisible: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private activeTab: number = 0;
  @State private showNativeSheet: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private activeSheetKind: string = '';
  @State private profileShareMode: boolean = false;
  @State private profileFollowingBusy: boolean = false;
  @State private profileSaving: boolean = false;
  private pendingDetailLike: PendingDetailLike | undefined = undefined;
  private readonly rootTabAddresses: Map<number, string> = new Map<number, string>();
  private nativePinRoute: string = '';
  @State private rootPullKind: string = '';
  private rootPullToken: number = 0;
  private readonly pageHistory: PinWebNavigationHistory = new PinWebNavigationHistory();

  private interruptedHomePage: string = '';
  private homeRecoveryAttempted: boolean = false;
  private homeRecoveryToken: number = 0;

  private logPageLifecycle(event: string, detail: string = ''): void {
    const now: number = Date.now();
    if (this.pageLifecycleStartedAt === 0) {
      this.pageLifecycleStartedAt = now;
      this.pageLifecycleLastEventAt = now;
    }
    const sinceStart: number = now - this.pageLifecycleStartedAt;
    const sincePrevious: number = now - this.pageLifecycleLastEventAt;
    this.pageLifecycleLastEventAt = now;
    this.pageLifecycleSequence++;
    const state: string = 'activeTab=' + this.activeTab.toString() +
      ' rootVisible=' + this.nativeRootTabsVisible().toString() +
      ' sheet=' + (this.activeSheetKind ? 'open' : 'closed') +
      ' detail=' + (!!this.pinStore.detail || !!this.pinStore.detailOpeningPin).toString() +
      ' inboxFlow=' + (!!this.inboxStore.inboxFlow).toString() +
      ' profileFlow=' + (!!this.profileStore.profileWebFlow || !!this.profileStore.panel).toString();
    PinWebRuntimeLog.info('PageLifecycle: event=' + event +
      ' sequence=' + this.pageLifecycleSequence.toString() +
      ' sinceStartMs=' + sinceStart.toString() +
      ' sincePreviousMs=' + sincePrevious.toString() + ' ' + state +
      (detail ? ' ' + detail : ''));
  }

  private businessSuspended: boolean = false;

  onPageShow(): void {
    this.logPageLifecycle('page-show');
    if (!this.pinStore.videoForeground) this.homeRecoveryAttempted = false;
    this.pinStore.videoForeground = true;
    if (this.businessSuspended) {
      this.businessSuspended = false;
      const readNeeded: boolean = this.nativeNetwork.setForeground(true);
      const detailReadNeeded: boolean = this.detailReadNetwork.setForeground(true);
      this.controller.runJavaScript('window.PinWebNetwork && window.PinWebNetwork.setForeground(true)').catch(() => {});
      PinWebRuntimeLog.info('BusinessLifecycle: resumed readNeeded=' + readNeeded.toString() + ' targetTab=' + this.activeTab.toString());
      if (this.authStatus === 'authenticated' && !this.activeSheetKind) {
        if (this.pinStore.detail && (readNeeded || detailReadNeeded)) this.retryDetailApi();
        else if (!this.pinStore.detail && !this.pinStore.detailOpeningPin && (readNeeded || !this.rootActionContextReady(this.activeTab))) { this.requestRootPage(this.activeTab); return; }
      }
    }
    this.scheduleInterruptedHomeRecovery();
  }
  onPageHide(): void {
    this.logPageLifecycle('page-hide', 'detailReadNetwork=invalidate');
    this.searchController.invalidatePending();
    this.pinStore.videoForeground = false;
    this.businessSuspended = true;
    this.nativeNetwork.setForeground(false); this.detailReadNetwork.setForeground(false);
    this.tabRequestToken++; this.rootReadToken = -1; this.pendingWebTab = -1;
    this.controller.runJavaScript('window.PinWebNetwork && window.PinWebNetwork.setForeground(false)').catch(() => {});
    PinWebRuntimeLog.info('BusinessLifecycle: suspended reads-cancelled=true writes-replay=false');
    this.pinStore.detailPrefetch.pause();
    this.detailReadNetwork.invalidate(); this.openingRelated = undefined;
    this.sharedDetailRequestId = '';
    this.homeRecoveryToken++;
  }
  private pageBackToken: number = 0;
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;

  private readonly searchController: PinWebSearchController = new PinWebSearchController(this.searchStore, {
    currentPageKey: (): string => this.currentSearchPageKey(),
    isActive: (): boolean => this.authStatus === 'authenticated' && this.activeTab === 1,
    preservingPinSearch: (): boolean => this.preservingSearchForPin(),
    runScript: (script: string): Promise<string> => this.controller.runJavaScript(script),
    ensureContext: (requireData: boolean, allowedSheet: string = '', isCurrent: () => boolean = (): boolean => true): Promise<boolean> =>
      this.ensureRootActionContext(1, requireData, allowedSheet, isCurrent),
    markInteracted: (): void => { this.rootContentInteracted = true; },
    clearTabGuard: (reason: string): void => this.clearRootTabGuard(reason),
    finishPull: (): void => this.finishRootPull('search'),
    recordPageKey: (pageKey: string): void => { this.rootTabAddresses.set(1, pageKey); },
    setDetailReturn: (pageKey: string): void => { this.pinStore.detailReturnUrl = pageKey; },
    navigateSearch: (target: string, source: string): void => {
      if (source) this.pageHistory.visit(source, 'load');
      this.prepareSearchNavigation(target);
      this.controller.loadUrl(target);
    },
    navigateResult: (target: string, source: string): void => {
      this.pageHistory.visit(source, 'load');
      this.beginDetailOpening(this.extractPinUrl(target), source);
      this.controller.loadUrl(this.extractPinUrl(target) || target);
    },
    cancelNavigation: (clearRetained: boolean): void => {
      this.rootReadToken = -1; this.pendingWebTab = -1;
      if (clearRetained) this.retainedRootTabPending = -1;
    },
    clearOpeningDetail: (): void => { this.pinStore.detailOpeningPin = ''; },
    sheetKind: (): string => this.activeSheetKind,
    setFilterVisible: (visible: boolean): void => {
      if (visible) { this.activeSheetKind = 'searchFilter'; this.showNativeSheet = true; }
      else { this.showNativeSheet = false; this.activeSheetKind = ''; }
    },
    prepareRead: (): boolean => this.nativeRootOnly && this.prepareRootPageRead(1),
    requestRead: (): void => this.requestRootPage(1),
    pinIdentity: (url: string): string => this.pinIdentity(url),
    traceAction: (name: string, detail: string = ''): void => this.traceAction(name, detail),
    showMessage: (message: string): void => this.showMessage(message)
  } as PinWebSearchPorts);

  private readonly systemActions: PinWebSystemActions = new PinWebSystemActions(
    (): common.UIAbilityContext => this.getUIContext().getHostContext() as common.UIAbilityContext,
    (message: string): void => this.showMessage(message)
  );


  aboutToAppear(): void {
    this.logPageLifecycle('about-to-appear', 'stores=7 bridge=bind');
    this.systemActions.activate();
    this.initializeHomeApiCache();
    this.initializeOfflineHomeMarker();
    this.inboxStore.onNavigationChange = () => this.syncFloatingTabsMotion();
    this.pinStore.onNavigationChange = () => this.syncFloatingTabsMotion();
    this.profileStore.onNavigationChange = () => this.syncFloatingTabsMotion();
    this.boardStore.onNavigationChange = () => this.syncFloatingTabsMotion();
    this.searchStore.onNavigationChange = () => this.syncFloatingTabsMotion();

    this.shareBridge.onNetworkRequest = (value: string) => this.requestNativeNetwork(value);
    const readTrace = (id: string, resource: string, event: string, duration: number, attempt: number): void => {
      if (this.detailRequestOwners.get(id) !== this.detailJourney.current() || !this.detailJourney.current()) return;
      this.detailJourney.mark(resource + '.attempt' + attempt.toString() + '.' + event, false, duration);
    };
    this.nativeNetwork.onReadTrace = readTrace;
    this.detailReadNetwork.onReadTrace = readTrace;
    this.nativeNetwork.onTransientRetry = (_resource: string, speculative: boolean) => {
      if (!speculative) this.showNetworkNotice('网络不稳定，正在重试…');
    };
    this.shareBridge.onCancelNetwork = (id: string) => this.cancelNativeNetwork(id);
    this.shareBridge.onAuthState = (value: string) => this.updateAuthState(value);
    this.shareBridge.onPageBack = () => {
      if (this.backInProgress) return;
      if (this.currentPinUrl()) this.backFromDetail();
      else if (this.currentSearchPageKey()) this.backFromSearch();
      else this.backOnePage();
    };
    this.shareBridge.onPageNavigation = (url: string, mode: string) => {
      if (this.nativeRootOnly && !isPinterestAuthRoute(url)) return;
      if (this.detailReturnedToRoot && this.extractPinUrl(url)) return;
      if (this.ignoreSupersededDetailDocument(url)) return;
      try {
        if (this.pageHistory.key(url) !== this.pageHistory.key(this.controller.getUrl())) return;
        if (this.logoutAwaitingLogin && !isPinterestAuthRoute(url)) return;
        if (this.nativeBackTarget && this.pageHistory.key(url) !== this.pageHistory.key(this.nativeBackTarget) ||
            this.pinStore.detailOpeningPin && this.pinIdentity(url) !== this.pinIdentity(this.pinStore.detailOpeningPin)) return;
        if (mode === 'restore') {
          this.authEpoch++;
          this.nativeNetwork.invalidate();
          this.webPageLoading = false;
          this.retainedHomeAwaitingAuth = !!this.homePageKeyFromAddress(url);
          this.retainedHomeAwaitingFeed = this.retainedHomeAwaitingAuth;
          this.homeStore.homeActionsReady = false;
          PinWebRuntimeLog.info('PinWebReturn: document restored from BFCache');
          this.detailReturnJourney?.mark('return.document.retained');
        }
        if (mode === 'ready') PinWebRuntimeLog.info('StartupTrace: document ready');
        this.recordPageNavigation(url, mode === 'ready' ? 'observe' : mode);
        this.bindCurrentDetailDocument(url);
        this.syncAuthentication();
      } catch (error) {
        PinWebRuntimeLog.warn('PinWeb: page navigation state unavailable');
      }
    };
    this.shareBridge.onShare = (targetUrl: string, pinUrl: string) => {
      if (this.authStatus !== 'authenticated') return;
      if (this.activeSheetKind === 'more') this.dismissMoreSheet();
      else this.dismissShareSheet();
      this.shareFromTarget(targetUrl, pinUrl);
    };
    this.shareBridge.onPostState = (value: string) => { if (this.authStatus === 'authenticated') this.handlePostResult(value); };
    this.shareBridge.onSheetState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateShareSheet(value);
    };
    this.shareBridge.onMoreState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateMoreSheet(value);
    };
    this.shareBridge.onDetailState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateDetail(value);
    };
    this.shareBridge.onProfileState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateProfile(value);
    };
    this.shareBridge.onBoardState = (value: string) => { if (this.authStatus === 'authenticated') this.updateBoard(value); };
    this.shareBridge.onProfilePublish = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateProfilePublish(value);
    };
    this.shareBridge.onHomeState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateHome(value);
    };
    this.shareBridge.onInboxState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateInbox(value);
    };
    this.shareBridge.onSearchState = (value: string) => {
      if (this.authStatus === 'authenticated') this.updateSearch(value);
    };
    this.shareBridge.onNavigation = (visible: boolean, index: number) => {
      if (this.authStatus !== 'authenticated') return;
      if (this.nativeRootOnly) return;
      try {
        const address: string = this.controller.getUrl();
        if (this.ignoreSupersededDetailDocument(address)) return;
        this.navigationAddress = address;
        this.syncNativeReturnRoute(this.navigationAddress);
        this.syncBoardRoute(this.navigationAddress);
      } catch (error) {
        this.navigationAddress = this.lastPageUrl;
      }
      this.showNativeTabs = visible || !!this.currentSearchPageKey();
      if (index >= 0 && index < 4) {
        if (this.currentInboxUrl() && !this.inboxStore.inbox &&
          !this.inboxStore.inboxLoading && !this.inboxStore.inboxError && !this.inboxStore.inboxWebFlow) this.expectInbox();
        if (index !== 2 && !this.currentInboxUrl() && this.pendingWebTab !== 2) this.clearInbox();
        const profileRoute: string = this.currentProfileUrl();
        if (this.profileStore.profileWebFlow && !profileRoute) this.profileStore.profileFlowLeftPage = true;
        if (this.profileStore.profileWebFlow && profileRoute && this.profileStore.profileFlowLeftPage) {
          this.profileStore.profileWebFlow = false;
          this.profileStore.profileFlowLeftPage = false;
        }
        if (profileRoute && this.profileStore.profileUrl && this.profileStore.profileUrl !== profileRoute) {
          this.clearProfile();
        }
        const profileConfirmed: boolean = !!profileRoute && (index === 3 ||
          this.profileStore.profileUrl === profileRoute && !!this.profileStore.profile || this.profileStore.profileLoading || !!this.profileStore.profileError);
        const searchConfirmed: boolean = !!this.currentSearchPageKey();
        const resolvedIndex: number = profileConfirmed ? 3 : searchConfirmed ? 1 :
          this.currentInboxUrl() ? 2 : this.isHomeRootAddress(this.navigationAddress) ? 0 : index;
        if (!profileRoute && resolvedIndex !== 3) {
          if ((this.profileStore.profileLoading || this.profileStore.profileError) && this.pendingWebTab === 3 &&
              !this.currentPinUrl()) return;
          this.clearProfile(this.profileStore.profileWebFlow);
        } else if (profileRoute && !this.profileStore.profile && !this.profileStore.profileLoading && !this.profileStore.profileError) {
          this.expectProfile();
          if (this.profileStore.profile) {
            this.controller.runJavaScript('window.PinWebProfileSync && window.PinWebProfileSync()')
              .catch(() => PinWebRuntimeLog.warn('PinWeb: retained profile sync unavailable'));
          } else {
            this.refreshProfile();
          }
        }
        if (profileRoute && this.profileStore.origins.length > 0) return;
        if (this.pendingWebTab !== -1 && this.pendingWebTab !== resolvedIndex) return;
        this.currentWebTab = resolvedIndex;
        if (this.pendingWebTab === resolvedIndex) this.pendingWebTab = -1;
        if (this.activeTab !== resolvedIndex) {
          this.activeTab = resolvedIndex;
          this.tabsController.changeIndex(resolvedIndex);
        }
        if (visible && resolvedIndex === 0 && this.currentHomePageKey() &&
            !this.homeStore.home && !this.homeStore.homeLoading && !this.homeStore.homeError) this.expectHome();
        if (resolvedIndex === 1 && this.currentSearchPageKey() &&
            !this.searchStore.search && !this.searchStore.searchLoading && !this.searchStore.searchError) this.expectSearch();
        if (resolvedIndex !== 1 && !this.currentSearchPageKey() &&
            (this.searchStore.search || this.searchStore.searchLoading || this.searchStore.searchError) && !this.preservingSearchForPin()) this.clearSearch();
      }
    };
  }

  aboutToDisappear(): void {
    this.logPageLifecycle('about-to-disappear', 'stores=7 bridge=unbind network=invalidate');
    this.systemActions.dispose();
    this.searchController.invalidatePending();
    const pendingBefore: number = this.pageTasks.invalidate();
    PinWebRuntimeLog.info('PageLifecycle: tasks-invalidated pendingBefore=' + pendingBefore.toString() +
      ' pendingAfter=' + this.pageTasks.pendingCount().toString());
    this.inboxStore.onNavigationChange = undefined;
    this.pinStore.onNavigationChange = undefined;
    this.profileStore.onNavigationChange = undefined;
    this.boardStore.onNavigationChange = undefined;
    this.searchStore.onNavigationChange = undefined;

    this.nativeNetwork.invalidate();
    this.shareBridge.onNetworkRequest = undefined;
    this.nativeNetwork.onReadTrace = undefined; this.detailReadNetwork.onReadTrace = undefined;
    this.detailJourney.close(); this.detailReturnJourney.close(); this.detailRequestOwners.clear();
    if (this.detailImageTimer !== -1) this.pageTasks.cancelTimeout(this.detailImageTimer);
    this.detailImageBinding = ''; this.detailImageSignal = ''; this.detailImageTimer = -1;
    this.detailReadNetwork.invalidate(); this.openingRelated = undefined; this.pinStore.detailPrefetch.pause();
    this.shareBridge.onCancelNetwork = undefined;
    PinWebRuntimeLog.info('PinWebReturn: root page disappeared');
    this.shareBridge.onAuthState = undefined;
    if (this.authCheckTimer !== -1) this.pageTasks.cancelTimeout(this.authCheckTimer);
    this.dismissPostSnack();
    this.homeStore.customHomeMenuToken++;
    this.homeStore.customHomeMenu = undefined;
    this.pinStore.commentToken++;
    this.shareBridge.onPostState = undefined;
    this.cancelHomeDetailMore();
    this.shareBridge.onPageBack = undefined;
    this.shareBridge.onPageNavigation = undefined;
    this.shareBridge.onShare = undefined;
    this.shareBridge.onNavigation = undefined;
    this.shareBridge.onSheetState = undefined;
    this.shareBridge.onMoreState = undefined;
    this.shareBridge.onDetailState = undefined;
    this.shareBridge.onProfileState = undefined;
    this.shareBridge.onBoardState = undefined;
    this.shareBridge.onProfilePublish = undefined;
    this.shareBridge.onHomeState = undefined;
    this.shareBridge.onInboxState = undefined;
    this.shareBridge.onSearchState = undefined;
  }

  private authWebVisible(): boolean {
    if (this.authStatus === 'authenticated' || this.authStatus === 'error' || this.loadFailed) return false;
    let url: string = this.navigationAddress || PINTEREST_URL;
    try { url = this.controller.getUrl() || url; } catch (_) {}
    return isPinterestAuthRoute(url) ||
      /^https:\/\/(?:accounts\.google\.com|(?:www|m)\.facebook\.com)\//i.test(url);
  }

  private nativeNetworkContext(): PinWebNetworkContext {
    let page: string = '', userAgent: string = '';
    try { page = this.controller.getUrl(); userAgent = this.controller.getUserAgent(); } catch (_) {}
    return { authenticated: this.authStatus === 'authenticated', epoch: this.authEpoch, page: page, userAgent: userAgent };
  }

  private bindNativeNetwork(): void {
    const context: PinWebNetworkContext = this.nativeNetworkContext();
    if (!context.authenticated) return;
    this.controller.runJavaScript('window.PinWebNetwork && window.PinWebNetwork.bind(' +
      context.epoch.toString() + ',' + JSON.stringify(context.page) + ');' +
      'window.PinWebHomeDemand && window.PinWebHomeDemand(' + JSON.stringify(context.page) + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: native transport binding unavailable'));
  }

  private requestNativeNetwork(value: string): void {
    if (!PIN_NATIVE_NETWORK_ENABLED || typeof value !== 'string' || value.length > 36 * 1024 * 1024) return;
    let job: PinWebNetworkJob;
    try { job = JSON.parse(value) as PinWebNetworkJob; if (!job || typeof job.id !== 'string') return; }
    catch (_) { return; }
    const traced: RegExpMatchArray | null = job.url.match(/\/resource\/(PinResource|UnifiedCommentsPreviewResource|RelatedModulesResource)\/get\//);
    if (traced && traced[1] !== 'PinResource' && this.extractPinUrl(job.page) &&
        (this.pinStore.detailPresentationOnly || this.nativeBackTarget || this.pageHistory.isPending() || this.detailReturnedToRoot || this.nativeRootOnly ||
         !this.pinStore.detail || this.pinIdentity(job.page) !== this.pinIdentity(this.pinStore.detailPin))) {
      // Native intent supersedes the old document before ArkWeb navigation
      // finishes. Reject late preview/recommendation jobs without RCP dispatch.
      const reply: PinWebNetworkReply = { id: job.id, epoch: job.epoch, page: job.page,
        url: job.url, status: 0, body: '', headers: {}, error: 'cancelled' };
      this.controller.runJavaScript('window.PinWebNetwork && window.PinWebNetwork.complete(' + JSON.stringify(reply) + ')')
        .catch(() => {});
      PinWebRuntimeLog.info('DetailTrace: departed document read rejected');
      return;
    }
    if (job.method !== 'GET' && !/\/resource\/[^/]+\/get\//.test(job.url)) this.detailReturnReads.clear();
    const journey: number = this.detailJourney.current();
    const requestAt: number = Date.now();
    if (traced && journey && job.page === this.pinStore.detailPin) {
      this.detailRequestOwners.set(job.id, journey);
      this.detailJourney.mark(traced[1] + '.request', false);
    }
    this.detailNetworkReply(job)
      .then((reply: PinWebNetworkReply) => {
        this.detailRequestOwners.delete(job.id);
        if (traced && journey && journey === this.detailJourney.current() && job.page === this.pinStore.detailPin) {
          this.detailJourney.mark(traced[1] + '.response=' + (reply.error ? 'failed' : reply.status.toString()), false, Date.now() - requestAt);
        }
        const cancelled: boolean = reply.error === 'cancelled' || reply.error === 'stale' ||
          reply.error === 'current=false';
        if (!cancelled && (reply.status === 0 || !!reply.error)) this.showNetworkNotice();
        else if (/\/resource\/UserHomefeedResource\/get\//.test(job.url)) this.clearNetworkNotice();
        const context: PinWebNetworkContext = this.nativeNetworkContext();
        if (context.epoch !== reply.epoch || context.page !== reply.page || !context.authenticated) return;
        if (reply.status === 200 && !reply.error && job.method === 'GET' && reply.body.length < 1000000 &&
            /\/resource\/(RelatedModulesResource|UnifiedCommentsPreviewResource)\/get\//.test(job.url)) {
          this.detailReturnReads.put(this.detailReturnReadKey(job.url), reply.body);
          this.detailJourney.mark('return.read.cache.stored');
        }
        this.controller.runJavaScript('window.PinWebNetwork && window.PinWebNetwork.complete(' + JSON.stringify(reply) + ')')
          .then((state: string) => {
            if (traced && journey && journey === this.detailJourney.current() && state.includes('delivered'))
              this.detailJourney.mark(traced[1] + '.bridge.delivered', false, Date.now() - requestAt);
            if (/^(?:"?)(delivered|no-job|stale)(?:"?)$/.test(state))
              PinWebRuntimeLog.info('NativeNetwork: bridge delivery ' + state);
          })
          .catch(() => {
            this.showNetworkNotice();
            PinWebRuntimeLog.warn('PinWeb: native response delivery unavailable');
          });
      }).catch(() => {
        this.showNetworkNotice();
        PinWebRuntimeLog.warn('PinWeb: native transport unavailable');
      });
  }

  private showNetworkNotice(message: string = '网络不稳定，正在重试…'): void {
    this.networkNotice = message;
    if (this.networkNoticeTimer !== -1) this.pageTasks.cancelTimeout(this.networkNoticeTimer);
    this.networkNoticeTimer = this.pageTasks.timeout(() => {
      this.networkNotice = '';
      this.networkNoticeTimer = -1;
    }, 4500);
  }

  private clearNetworkNotice(): void {
    this.networkNotice = '';
    if (this.networkNoticeTimer !== -1) {
      this.pageTasks.cancelTimeout(this.networkNoticeTimer);
      this.networkNoticeTimer = -1;
    }
  }

  private bindCurrentDetailDocument(url: string): void {
    const expected: string = this.pinStore.detailOpeningPin || this.pinStore.detail?.pinUrl || '';
    const context: PinWebNetworkContext = this.nativeNetworkContext();
    if (this.pinStore.detailPresentationOnly || !PIN_NATIVE_NETWORK_ENABLED || !context.authenticated || this.nativeRootOnly ||
        this.rootTabGuardTarget >= 0 || this.nativeBackTarget || !this.pinIdentity(expected) ||
        this.pinIdentity(url) !== this.pinIdentity(expected) || context.page !== url) return;
    // A retained authenticated session can bind its current Pin document before
    // website HTML/auth probing finishes. Each request still validates epoch,
    // full page, Cookie and response identity; no action is enabled by binding.
    const binding: string = this.pinStore.detailOpeningToken.toString() + ':' + context.epoch.toString() + ':' + url;
    if (this.detailDocumentBinding === binding) return;
    this.detailDocumentBinding = binding;
    this.refreshDetailDocumentBinding(url, context.epoch, this.pinStore.detailOpeningToken, binding, 0);
    this.detailJourney.mark('document.transport.bind');
  }

  private probeDetailDocument(url: string, token: number, attempt: number): void {
    if (token !== this.pinStore.detailOpeningToken || this.pinStore.detailPin !== url ||
        this.pinStore.detailPresentationOnly || this.pinStore.detailActionsReady || this.nativeBackTarget ||
        this.nativeRootOnly || this.detailReturnedToRoot || this.businessSuspended ||
        !this.pinStore.videoForeground || this.authStatus !== 'authenticated') return;
    this.detailDocumentProbeTimer = -1;
    // ArkWeb can expose the target before page-end/navigation bridge events.
    // Binding still verifies the exact JS location and does not authorize actions.
    const context: PinWebNetworkContext = this.nativeNetworkContext();
    if (context.page === url) this.bindCurrentDetailDocument(url);
    if (attempt >= 60) { this.detailJourney.mark('document.transport.wait.timeout'); return; }
    this.detailDocumentProbeTimer = this.pageTasks.timeout(() => this.probeDetailDocument(url, token, attempt + 1), 200);
  }

  private refreshDetailDocumentBinding(url: string, epoch: number, token: number, binding: string, attempt: number): void {
    const context: PinWebNetworkContext = this.nativeNetworkContext();
    if (attempt > 0 && this.pinStore.detailActionsReady) return;
    if (this.detailDocumentBinding !== binding || token !== this.pinStore.detailOpeningToken ||
        !context.authenticated || context.epoch !== epoch || context.page !== url ||
        this.pinStore.detailPresentationOnly || this.nativeBackTarget || this.nativeRootOnly || this.businessSuspended ||
        !this.pinStore.videoForeground || this.detailReturnedToRoot ||
        this.pinIdentity(url) !== this.pinIdentity(this.pinStore.detailPin)) return;
    const bindingFailed = (): void => {
      if (this.detailDocumentBinding !== binding || token !== this.pinStore.detailOpeningToken) return;
      if (attempt < 3) this.pageTasks.timeout(() => this.refreshDetailDocumentBinding(url, epoch, token, binding, attempt + 1), 250 * (attempt + 1));
      else {
        this.detailDocumentBinding = '';
        PinWebRuntimeLog.warn('PinWeb: detail document binding unavailable');
      }
    };
    try {
    this.controller.runJavaScript('location.href === ' + JSON.stringify(url) +
      ' && window.PinWebNetwork && window.PinWebDetailRefresh ? (window.PinWebNetwork.bind(' +
      epoch.toString() + ',' + JSON.stringify(url) + '), window.PinWebDetailRefresh(true), true) : false')
      .then((result: string) => {
        if (this.detailDocumentBinding !== binding || token !== this.pinStore.detailOpeningToken) return;
        if (result === 'true' || result === '"true"') this.detailJourney.mark('document.transport.confirmed');
        if (!this.pinStore.detailActionsReady && attempt < 3) {
          this.pageTasks.timeout(() => this.refreshDetailDocumentBinding(url, epoch, token, binding, attempt + 1), 250 * (attempt + 1));
        } else if (attempt === 3 && result !== 'true' && result !== '"true"') {
          // A pre-document attempt must not permanently deduplicate the later ready event.
          this.detailDocumentBinding = '';
          this.detailJourney.mark('document.transport.not-ready');
        }
      }).catch(bindingFailed);
    } catch (_) { bindingFailed(); }
  }

  private detailReturnReadKey(url: string): string {
    // Only the request cache-buster is non-business data. All other parameters remain exact.
    return url.replace(/([?&])_=[0-9]+(?=&|$)/g, '$1').replace(/[?&]$/, '').replace('?&', '?').replace(/&&/g, '&');
  }

  private retainedDetailRead(job: PinWebNetworkJob): PinWebNetworkReply | undefined {
    if (!this.detailReturnReadPin || this.detailReturnReadPin !== this.pinIdentity(this.pinStore.detailPin) ||
        this.authStatus !== 'authenticated' || this.nativeBackTarget || job.method !== 'GET' || job.body !== '' ||
        !/\/resource\/(RelatedModulesResource|UnifiedCommentsPreviewResource)\/get\//.test(job.url)) return undefined;
    const body: string | null = this.detailReturnReads.get(this.detailReturnReadKey(job.url));
    if (!body) return undefined;
    this.detailJourney.mark('return.read.cache.hit');
    return { id: job.id, epoch: job.epoch, page: job.page, url: job.url, status: 200, body: body, headers: {}, error: '' };
  }

  private async detailNetworkReply(job: PinWebNetworkJob): Promise<PinWebNetworkReply> {
    if (!acceptsNetworkJob(job, this.nativeNetworkContext()))
      return this.nativeNetwork.request(job, (): PinWebNetworkContext => this.nativeNetworkContext());
    const pin: string = this.pinStore.detailOpeningPin || this.pinStore.detailPin;
    const retained: PinWebNetworkReply | undefined = this.retainedDetailRead(job);
    if (retained) return retained;
    if (job.method === 'GET' && /\/resource\/RelatedModulesResource\/get\//.test(job.url) &&
        this.openingRelated && this.openingRelatedToken === this.pinStore.detailOpeningToken) {
      const encodedRelated: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      try {
      if (encodedRelated) {
        const data: Record<string, Object> = JSON.parse(decodeURIComponent(encodedRelated[1])) as Record<string, Object>;
        const options: Record<string, Object> = data['options'] as Record<string, Object>;
        if (options['pin_id'] === this.pinIdentity(pin) && !options['bookmarks']) {
          const pending: Promise<PinWebNetworkReply> = this.openingRelated;
          this.openingRelated = undefined;
          const token: number = this.pinStore.detailOpeningToken;
          const reply: PinWebNetworkReply = await pending;
          const actual: PinWebNetworkContext = this.nativeNetworkContext();
          const valid: boolean = actual.authenticated && actual.epoch === job.epoch && actual.page === job.page &&
            token === this.pinStore.detailOpeningToken && !this.nativeBackTarget;
          return { id: job.id, epoch: job.epoch, page: job.page, url: job.url, headers: reply.headers,
            status: valid ? reply.status : 0, body: valid ? reply.body : '', error: valid ? reply.error : 'cancelled' };
        }
      }
      } catch (_) {}
    }
    let shared: Promise<string> | undefined = undefined;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const options: PinWebDetailReadOptions = encoded ?
        (JSON.parse(decodeURIComponent(encoded[1])) as PinWebDetailReadData).options : {} as PinWebDetailReadOptions;
      if (job.method === 'GET' && /^https:\/\/www\.pinterest\.com\/resource\/PinResource\/get\/\?/.test(job.url) &&
          options.id === this.pinIdentity(pin) && options.field_set_key === 'auth_web_main_pin')
        shared = this.pinStore.detailPrefetch.consume(pin);
    } catch (_) {}
    if (!shared) return this.nativeNetwork.request(job, (): PinWebNetworkContext => this.nativeNetworkContext());
    const token: number = this.pinStore.detailOpeningToken;
    this.sharedDetailRequestId = job.id;
    let body: string = '', error: string = '';
    try { body = await shared; } catch (_) { error = 'network-unavailable'; }
    if (this.sharedDetailRequestId === job.id) this.sharedDetailRequestId = '';
    const actual: PinWebNetworkContext = this.nativeNetworkContext();
    if (!actual.authenticated || actual.epoch !== job.epoch || actual.page !== job.page ||
        token !== this.pinStore.detailOpeningToken || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) {
      body = ''; error = 'cancelled';
    }
    PinWebRuntimeLog.info('DetailTrace: demand reply ' + (error ? 'unavailable' : 'delivered'));
    return { id: job.id, epoch: job.epoch, page: job.page, status: error ? 0 : 200,
      body: body, url: job.url, error: error, headers: { 'content-type': 'application/json' } };
  }

  private cancelNativeNetwork(id: string): void {
    this.nativeNetwork.cancel(id);
    if (id === this.sharedDetailRequestId) {
      this.pinStore.detailPrefetch.pause(); this.detailReadNetwork.invalidate(); this.openingRelated = undefined; this.sharedDetailRequestId = '';
    }
  }

  private resetAuthenticatedContent(): void {
    this.searchController.invalidatePending();
    this.pinStore.detailPresentationOnly = false; this.pinStore.detailPreparing = false;
    this.detailReturnReads.clear(); this.detailReturnReadPin = '';
    this.detailReturnJourney?.close(); this.detailClickedAt = 0;
    this.retainedHomeAwaitingAuth = false;
    this.retainedHomeAwaitingFeed = false;
    this.configureDocumentRetention(false);
    try { this.controller.clearHistory(); } catch (_) {}
    this.interruptedHomePage = '';
    this.homeRecoveryAttempted = false;
    this.homeRecoveryToken++;
    this.closeImageLayer();
    this.nativeNetwork.invalidate();
    this.nativeBackTarget = '';
    this.closeProfilePanel();
    this.profileSettingsVisible = false;
    this.settingsStore.reset();
    this.cancelAccountSettings();
    this.showNativeSheet = false;
    this.activeSheetKind = '';
    this.dismissPostSnack();
    this.cancelHomeDetailMore();
    this.clearRootTabCaches();
    this.clearDetail();
    this.pinStore.detailCache.clear();
    this.pinStore.clearDetailOrigins();
    this.pinStore.detailPrefetch.clear();
    this.pinStore.prefetchedImageUrls = [];
    this.pinStore.confirmedSaves.clear();
    this.boardStore.boardDetail = undefined;
    this.boardStore.pendingBoardUrl = '';
    this.inboxStore.inboxFlow = undefined;
    this.pendingWebTab = -1;
    this.retainedRootTabPending = -1;
    this.retainedRootTabAddress = '';
    this.rootTabGuardTarget = -1;
    this.detailReturnedToRoot = false;
    this.rootTabGuardAddress = '';
    this.nativeRootOnly = false;
    this.rootContentInteracted = false;
    this.retainedHomeDocumentPending = false;
    this.retainedHomeDocumentAddress = '';
    this.tabRequestToken++;
    this.pinStore.commentToken++;
    this.pinStore.saveToken++;
    this.pinStore.editToken++;
    this.pinStore.shareSession = 0;
    this.pinStore.moreSession = 0;
    this.pinStore.moreApiMode = false;
    this.pinStore.shareOptions = [];
    this.pinStore.shareActions = [];
    this.pinStore.shareContacts = [];
    this.pinStore.moreOptions = [];
    this.profileStore.publishOptions = [];
    this.homeStore.customHomeMenu = undefined;
    this.pendingDetailLike = undefined;
    this.pinStore.detailReturnUrl = '';
    this.boardStore.boardReturnUrl = '';
    this.boardStore.boardReturnPage = '';
    this.nativePinRoute = '';
    this.pageBackToken++;
    this.pinStore.detailOpeningToken++;
    this.boardStore.boardOpeningToken++;
    this.pinStore.saveUndoPin = '';
    this.pinStore.feedbackUndoPin = '';
    this.authenticatedProfileUrl = '';
    this.activeTab = 0;
    this.currentWebTab = 0;
    this.tabsController.changeIndex(0);
    this.pageHistory.reset();
  }

  private updateAuthState(value: string): void {
    try {
      const message: PinWebAuthMessage = JSON.parse(value) as PinWebAuthMessage;
      const currentUrl: string = this.controller.getUrl();
      if (!acceptsAuthMessage(message, currentUrl, this.authEpoch)) return;
      if (this.logoutAwaitingLogin && !isPinterestAuthRoute(currentUrl)) return;
      if (message.status === 'unauthenticated') {
        this.offlineCacheLoading = false;
        if (this.authStatus === 'authenticated') this.resetAuthenticatedContent();
        this.authStatus = 'unauthenticated';
        this.loadFailed = false;
        this.failureDetails = '';
        if (!isPinterestAuthRoute(currentUrl) && this.loginRedirectEpoch !== this.authEpoch) {
          // Repeated evidence callbacks must not queue multiple login navigations.
          this.loginRedirectEpoch = this.authEpoch;
          PinWebRuntimeLog.info('StartupTrace: session unavailable, opening login');
          this.controller.loadUrl(PINTEREST_LOGIN_URL);
        }
        return;
      }
      const entering: boolean = this.authStatus !== 'authenticated';
      this.loginRedirectEpoch = -1;
      this.offlineCacheLoading = false;
      this.authStatus = 'authenticated';
      if (this.offlinePreviewMode) {
        this.offlinePreviewMode = false;
        PinWebRuntimeLog.info('OfflineCache: preview exited reason=current-session-confirmed');
      }
      this.retainedHomeAwaitingAuth = false;
      const accountId: string = this.homeCacheAccountIdFromProfileUrl(message.profileUrl);
      const accountChanged: boolean = !!this.homeCacheAccountId && !!accountId &&
        this.homeCacheAccountId !== accountId;
      if (accountChanged) {
        PinWebRuntimeLog.info('HomeCache: account identity changed; clearing memory and preserving disk partitions');
        this.clearOfflineHomeMarker();
        this.clearRootTabCaches(false);
        this.nativeNetwork.invalidate();
        this.clearDetail();
        this.pinStore.detailCache.clear();
        this.pinStore.clearDetailOrigins();
        this.pinStore.detailPrefetch.clear();
        this.pinStore.prefetchedImageUrls = [];
        this.pinStore.confirmedSaves.clear();
      }
      else if (!accountId && this.homeCacheAccountId && this.homeCacheIdentityEpoch !== message.epoch) {
        // A root-tab document transition can produce an auth callback before
        // the profile URL is available. That is not evidence of an account
        // change. Clearing the in-memory feed here made every tab return look
        // like a cold start and allowed a fresh feed response to replace the
        // content the user had just left.
        PinWebRuntimeLog.info('HomeCache: account identity unavailable; retaining memory epoch=' + message.epoch.toString());
      }
      if (accountId) this.homeCacheAccountId = accountId;
      this.homeCacheIdentityEpoch = message.epoch;
      const authenticatedHomePage: string = this.homePageKeyFromAddress(currentUrl);
      this.tryRestoreAuthenticatedHome(accountId, authenticatedHomePage);
      if (entering) this.configureDocumentRetention(true);
      if (entering) PinWebRuntimeLog.info('StartupTrace: authenticated session confirmed');
      this.loadFailed = false;
      this.failureDetails = '';
      if (this.authCheckTimer !== -1) this.pageTasks.cancelTimeout(this.authCheckTimer);
      if (message.profileUrl && this.profileUrlFromAddress(message.profileUrl) &&
          message.profileUrl.startsWith('https://www.pinterest.com/')) {
        this.authenticatedProfileUrl = message.profileUrl;
      }
      const authenticatedProfile: string = this.profileUrlFromAddress(this.authenticatedProfileUrl);
      const usernameMatch: RegExpMatchArray | null = authenticatedProfile.match(
        /^https:\/\/(?:www\.)?pinterest\.com\/([a-zA-Z0-9_]+)\//i);
      const homeUsername: string = usernameMatch ? usernameMatch[1] : '';
      this.controller.runJavaScript('window.PinWebHomeSetUsername && window.PinWebHomeSetUsername(' +
        JSON.stringify(homeUsername) + ')').catch(() => PinWebRuntimeLog.warn('PinWeb: home identity bridge unavailable'));
      this.bindNativeNetwork();
      if (entering) {
        this.activeTab = 0;
        this.tabsController.changeIndex(0);
        this.pageHistory.reset();
        if (!this.isHomeRootAddress(currentUrl)) this.controller.loadUrl(PINTEREST_URL);
        else {
          this.expectHome();
          this.controller.runJavaScript('window.PinWebHomeRefresh && window.PinWebHomeRefresh()')
            .catch(() => PinWebRuntimeLog.warn('PinWeb: initial home sync unavailable'));
          this.refreshWebNavigation();
        }
      } else if (accountChanged && authenticatedHomePage) {
        this.expectHome();
        this.controller.runJavaScript('window.PinWebHomeRefresh && window.PinWebHomeRefresh()')
          .catch(() => PinWebRuntimeLog.warn('PinWeb: account home sync unavailable'));
      }
    } catch (_) { PinWebRuntimeLog.warn('PinWeb: invalid authentication state'); }
  }

  private syncAuthentication(): void {
    const epoch: number = this.authEpoch;
    this.controller.runJavaScript('window.PinWebAuthSync && window.PinWebAuthSync(' + epoch.toString() + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: authentication bridge unavailable'));
    if (this.authCheckTimer !== -1) this.pageTasks.cancelTimeout(this.authCheckTimer);
    this.authCheckTimer = this.pageTasks.timeout(() => {
      if (epoch !== this.authEpoch || this.authStatus !== 'checking' || this.authWebVisible()) return;
      if (this.tryEnterOfflinePreview(this.navigationAddress || this.lastPageUrl || PINTEREST_URL, 'auth-timeout')) return;
      this.authStatus = 'error';
      this.failureDetails = '无法确认当前会话，请重试读取';
    }, 15000);
  }

  private retryLogin(): void {
    if (this.authStatus === 'checking' && this.webPageLoading) return;
    const target: string = this.authStatus === 'unauthenticated' || isPinterestAuthRoute(this.navigationAddress) ?
      PINTEREST_LOGIN_URL : PINTEREST_URL;
    this.authStatus = 'checking';
    this.offlineCacheLoading = false;
    this.loginRedirectEpoch = -1;
    this.loadFailed = false;
    this.failureDetails = '';
    this.navigationAddress = target;
    try { this.controller.loadUrl(target); }
    catch (_) {
      this.authStatus = 'error';
      this.failureDetails = '当前会话页面暂时无法加载，请重试';
    }
  }

  private updateShareSheet(value: string): void {
    if (this.homeStore.customHomeMenu) return;
    try {
      const message: ShareSheetMessage = JSON.parse(value) as ShareSheetMessage;
      if (!message || typeof message.session !== 'number' || message.session < 1) {
        return;
      }
      if ((message.kind === 'opening' || message.kind === 'state') && message.pinUrl &&
          !(this.profileShareMode ? message.pinUrl === this.currentProfileUrl() && this.profileStore.profileActionsReady : this.isCurrentMorePin(message.pinUrl))) return;
      if (message.kind === 'closed') {
        if (message.session === this.pinStore.shareSession) {
          if (this.activeSheetKind === 'share') {
            this.showNativeSheet = false;
            this.activeSheetKind = '';
          }
          this.pinStore.shareSession = 0;
          this.pinStore.ignoredShareSession = 0;
          this.pinStore.shareOpenRequestedSession = 0;
          this.pinStore.shareOptions = [];
          this.pinStore.shareActions = [];
          this.pinStore.shareContacts = [];
          this.pinStore.shareOnPinDetail = false;
          this.pinStore.shareTitle = '';
          this.pinStore.shareSectionLabel = '';
          this.pinStore.shareError = '';
          this.pinStore.shareFeedback = '';
          this.pinStore.shareLoading = false;
          if (this.pinStore.ignoredMoreSession && this.pinStore.morePin) {
            this.closeMoreWebPanel(this.pinStore.ignoredMoreSession, this.pinStore.morePin);
          }
        }
        return;
      }
      if (message.kind === 'opening') {
        if (message.session < this.pinStore.shareSession || message.session === this.pinStore.ignoredShareSession) return;
        this.suspendMoreForShare();
        if (message.session !== this.pinStore.shareSession) this.pinStore.shareOpenRequestedSession = 0;
        this.pinStore.shareSession = message.session;
        this.pinStore.sharePin = this.profileShareMode ? this.currentProfileUrl() : this.extractPinUrl(message.pinUrl || '');
        this.pinStore.shareOptions = [];
        this.pinStore.shareActions = [];
        this.pinStore.shareContacts = [];
        this.pinStore.shareOnPinDetail = !!message.pinDetail;
        this.pinStore.shareTitle = '';
        this.pinStore.shareSectionLabel = '';
        this.pinStore.shareSearchActive = false;
        this.pinStore.shareSearchId = '';
        this.pinStore.shareSendId = '';
        this.pinStore.shareError = '';
        this.pinStore.shareFeedback = '';
        this.pinStore.shareLoading = true;
        this.activeSheetKind = 'share';
        this.showNativeSheet = true;
        setTimeout(() => this.scheduleShareWebOpen(), 500);
        return;
      }
      if (message.kind === 'failed') {
        if (message.session === this.pinStore.shareSession && message.session !== this.pinStore.ignoredShareSession) {
          this.pinStore.shareLoading = false;
          this.showMessage('无法读取 Pinterest 分享面板，请重新打开分享');
          this.dismissShareSheet();
        }
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') || message.session === this.pinStore.ignoredShareSession ||
          message.session < this.pinStore.shareSession) {
        return;
      }
      if (message.session !== this.pinStore.shareSession) {
        this.pinStore.shareSession = message.session;
        this.pinStore.shareQuery = '';
        this.pinStore.shareError = '';
        this.pinStore.shareFeedback = '';
      }
      this.suspendMoreForShare();
      this.pinStore.sharePin = this.profileShareMode ? this.currentProfileUrl() : this.extractPinUrl(message.pinUrl || '');
      this.pinStore.shareOnPinDetail = !!message.pinDetail;
      this.pinStore.shareTitle = message.title || '';
      this.pinStore.shareSectionLabel = message.sectionLabel || '';
      this.pinStore.shareOptions = (message.options || []).filter((option: ShareSheetOption) => !!option.id && !!option.label);
      this.pinStore.shareActions = (message.actions || []).filter((option: ShareSheetOption) => !!option.id && !!option.label);
      const copyOptions: ShareSheetOption[] = this.pinStore.shareOptions.concat(this.pinStore.shareActions)
        .filter((option: ShareSheetOption) => this.isCopyLinkAction(option.label));
      this.pinStore.shareOptions = this.pinStore.shareOptions.filter((option: ShareSheetOption) => !this.isCopyLinkAction(option.label));
      if (copyOptions.length > 0) {
        this.pinStore.shareOptions.push(copyOptions[0]);
      }
      this.pinStore.shareActions = this.pinStore.shareActions.filter((option: ShareSheetOption) => !this.isCopyLinkAction(option.label));
      this.pinStore.shareContacts = (message.contacts || []).filter((option: ShareSheetOption) => !!option.id && !!option.label);
      this.pinStore.shareSearchId = message.searchId || '';
      this.pinStore.shareSearchLabel = message.searchLabel || '';
      this.pinStore.shareSendId = message.sendId || '';
      this.pinStore.shareSendLabel = message.sendLabel || '';
      const enteringSearch: boolean = !this.pinStore.shareSearchActive && !!message.searchActive;
      this.pinStore.shareSearchActive = !!message.searchActive;
      if (enteringSearch && typeof message.query === 'string') {
        this.pinStore.shareQuery = message.query;
      }
      this.pinStore.shareFeedback = message.feedback || '';
      this.pinStore.shareError = message.error || '';
      if (/Unexpected token|not valid JSON|JSON\.parse|Unexpected end of JSON/i.test(this.pinStore.shareError)) {
        this.pinStore.shareError = '无法读取分享数据，请重试';
      }
      this.pinStore.shareLoading = false;
      this.activeSheetKind = 'share';
      this.showNativeSheet = true;
      if (!this.pinStore.shareSearchActive && this.pinStore.shareOptions.length === 0 &&
          this.pinStore.shareActions.length === 0 && !this.pinStore.shareSearchId && this.pinStore.shareContacts.length === 0) {
        this.pinStore.shareError = '暂时无法读取分享选项';
      } else {
        this.pinStore.shareError = message.error || '';
      }
      this.showShareLinkSnack();
      this.showShareFeedbackSnack();
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid share sheet state');
    }
  }

  private dismissShareSheet(): void {
    this.pinStore.shareBackHandledUntil = Date.now() + 500;
    this.lastRootBackAt = 0;
    this.pinStore.shareSnackKey = '';
    this.dismissPostSnack();
    if (this.homeStore.customHomeMenu) {
      const session: number = this.homeStore.customHomeMenu.session;
      this.homeStore.customHomeMenuToken++;
      this.homeStore.customHomeMenu = undefined;
      this.showNativeSheet = false;
      this.activeSheetKind = '';
      this.homeStore.homeMenuPin = '';
      this.homeStore.homeMenuPage = '';
      this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.homeMenuClose(' + session + ')')
        .catch(() => PinWebRuntimeLog.warn('PinWeb: home menu close unavailable'));
      return;
    }
    if (!this.pinStore.shareSession || this.pinStore.ignoredShareSession === this.pinStore.shareSession) {
      if (this.activeSheetKind === 'share') {
        this.showNativeSheet = false;
        this.activeSheetKind = '';
        this.profileShareMode = false;
      }
      return;
    }
    const session: number = this.pinStore.shareSession;
    this.pinStore.ignoredShareSession = session;
    if (this.activeSheetKind === 'share') {
      this.showNativeSheet = false;
      this.activeSheetKind = '';
      this.profileShareMode = false;
    }
    this.pinStore.shareError = '';
    this.pinStore.shareLoading = false;
    this.controller.runJavaScript('window.PinWebNativeShareClose && window.PinWebNativeShareClose(' +
      session.toString() + ')').catch(() => {
      PinWebRuntimeLog.warn('PinWeb: could not close the web share panel');
    });
  }

  private scheduleShareWebOpen(): void {
    const session: number = this.pinStore.shareSession;
    if (!session || this.pinStore.shareOpenRequestedSession === session ||
        this.activeSheetKind !== 'share' || !this.pinStore.shareLoading ||
        this.pinStore.ignoredShareSession === session) return;
    this.pinStore.shareOpenRequestedSession = session;
    setTimeout(() => {
      if (session !== this.pinStore.shareSession || this.activeSheetKind !== 'share' ||
          this.pinStore.ignoredShareSession === session) return;
      this.controller.runJavaScript('window.PinWebNativeShareOpen && window.PinWebNativeShareOpen(' +
        session.toString() + ')').then((result: string) => {
        if (session === this.pinStore.shareSession && result !== 'true' && result !== '"true"') {
          this.showMessage('无法打开 Pinterest 分享选项，请重新打开分享');
          this.dismissShareSheet();
        }
      }).catch(() => {
        if (session === this.pinStore.shareSession) {
          this.showMessage('无法打开 Pinterest 分享选项，请重新打开分享');
          this.dismissShareSheet();
        }
      });
    }, 350);
  }

  private pinIdentity(value: string): string {
    const match: RegExpMatchArray | null = value.match(/\/pin\/(\d+)(?:\/|$)/i);
    return match ? match[1] : '';
  }

  private externalSourceUrl(value: string): string {
    const match: RegExpMatchArray | null = value.match(/^https:\/\/([^\/?#\s]+)(?:[\/?#]|$)/i);
    if (!match || /[@]/.test(match[1]) || /(^|\.)pinterest\.com$|(^|\.)pinimg\.com$|(^|\.)pin\.it$/i.test(match[1])) return '';
    return value;
  }

  private isCurrentMorePin(pin: string): boolean {
    const identity: string = this.pinIdentity(pin);
    return !!identity && (identity === this.pinIdentity(this.currentPinUrl()) ||
      this.inboxStore.inboxFlow?.screen === 'chat' && this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl() &&
      identity === this.pinIdentity(this.homeStore.homeMenuPin) &&
      this.inboxStore.inboxFlow.messages.some((message): boolean => this.pinIdentity(message.pinUrl || '') === identity) ||
      this.isCurrentBoardMenuPin(pin, this.homeStore.homeMenuPage) ||
      !!this.homeStore.home && this.activeTab === 0 && this.homeStore.home.pageKey === this.currentHomePageKey() &&
      identity === this.pinIdentity(this.homeStore.homeMenuPin));
  }

  private closeMoreWebPanel(session: number, pin: string): void {
    this.controller.runJavaScript('window.PinWebNativeMoreClose && window.PinWebNativeMoreClose(' +
      session.toString() + ',' + JSON.stringify(pin) + ')').catch(() => {
      PinWebRuntimeLog.warn('PinWeb: could not close the web Pin menu');
    });
  }

  private suspendMoreForShare(): void {
    if (this.activeSheetKind !== 'more' || !this.pinStore.moreSession) return;
    this.pinStore.ignoredMoreSession = this.pinStore.moreSession;
    this.pinStore.moreOptions = [];
    this.pinStore.moreError = '';
    this.pinStore.moreLoading = false;
  }

  private updateMoreSheet(value: string): void {
    if (this.homeStore.customHomeMenu || this.pinStore.moreApiMode) return;
    try {
      const message: MoreSheetMessage = JSON.parse(value) as MoreSheetMessage;
      if (!message || typeof message.session !== 'number' || message.session < 1 ||
          typeof message.pin !== 'string') return;
      if (message.kind === 'closeFailed') {
        if (message.session === this.pinStore.moreSession && message.pin === this.pinStore.morePin &&
            this.activeSheetKind !== 'share') {
          this.showMessage('无法关闭网页选项，请重试');
        }
        return;
      }
      if (message.kind === 'closed') {
        if (message.session === this.pinStore.moreSession && message.pin === this.pinStore.morePin) {
          if (this.activeSheetKind === 'more') {
            this.showNativeSheet = false;
            this.activeSheetKind = '';
          }
          this.pinStore.moreSession = 0;
          this.pinStore.moreApiMode = false;
          this.pinStore.ignoredMoreSession = 0;
          this.pinStore.morePin = '';
          this.homeStore.homeMenuPin = '';
          this.pinStore.moreTitle = '';
          this.pinStore.moreOptions = [];
          this.pinStore.moreError = '';
          this.pinStore.moreLoading = false;
        }
        return;
      }
      if (!this.isCurrentMorePin(message.pin) ||
          message.session < this.pinStore.moreSession || message.session === this.pinStore.ignoredMoreSession) return;
      if (message.kind === 'opening') {
        if (this.activeSheetKind === 'share') this.dismissShareSheet();
        this.pinStore.moreSession = message.session;
        this.pinStore.moreApiMode = false;
        this.pinStore.morePin = message.pin;
        this.pinStore.moreTitle = '';
        this.pinStore.moreOptions = [];
        this.pinStore.moreError = '';
        this.pinStore.moreLoading = true;
        this.activeSheetKind = 'more';
        this.showNativeSheet = false;
        return;
      }
      if (message.session !== this.pinStore.moreSession || message.pin !== this.pinStore.morePin) return;
      if (message.kind === 'failed') {
        if (this.pinIdentity(message.pin) === this.pinIdentity(this.homeStore.pendingHomeMorePin)) {
          this.cancelHomeDetailMore();
        }
        this.pinStore.moreLoading = false;
        this.pinStore.ignoredMoreSession = message.session;
        this.activeSheetKind = '';
        this.showNativeSheet = false;
        this.showMessage('无法读取 Pinterest 选项，请重新打开三点菜单');
        return;
      }
      if (message.kind !== 'state') return;
      if (this.pinIdentity(message.pin) === this.pinIdentity(this.homeStore.pendingHomeMorePin)) {
        this.cancelHomeDetailMore();
      }
      this.pinStore.moreTitle = message.title || '';
      this.pinStore.moreOptions = (message.options || []).filter((option: MoreSheetOption) =>
        !!option.id && !!option.label);
      this.pinStore.moreLoading = false;
      this.pinStore.moreError = this.pinStore.moreOptions.length > 0 ? '' : '暂时无法读取选项';
      this.activeSheetKind = 'more';
      this.showNativeSheet = true;
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid Pin menu state');
    }
  }

  private dismissMoreSheet(): void {
    if (!this.pinStore.moreSession || this.pinStore.ignoredMoreSession === this.pinStore.moreSession) {
      if (this.activeSheetKind === 'more') {
        this.showNativeSheet = false;
        this.activeSheetKind = '';
      }
      return;
    }
    const session: number = this.pinStore.moreSession;
    const pin: string = this.pinStore.morePin;
    this.pinStore.ignoredMoreSession = session;
    if (this.activeSheetKind === 'more') {
      this.showNativeSheet = false;
      this.activeSheetKind = '';
    }
    this.pinStore.moreError = '';
    this.pinStore.moreLoading = false;
    if (this.pinStore.moreApiMode) {
      this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.detailMoreClose(' +
        session.toString() + ',' + JSON.stringify(pin) + ')').catch(() => {});
    } else this.closeMoreWebPanel(session, pin);
  }

  private async openApiDetailMore(): Promise<void> {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || !this.pinStore.detailActionsReady || !this.isCurrentMorePin(detail.pinUrl)) return;
    const session: number = Math.max(1, this.pinStore.moreSession + 1);
    this.pinStore.moreSession = session;
    this.pinStore.moreApiMode = true;
    this.pinStore.morePin = detail.pinUrl;
    this.pinStore.moreTitle = '选项';
    this.pinStore.moreOptions = [];
    this.pinStore.moreError = '';
    this.pinStore.moreLoading = true;
    this.pinStore.ignoredMoreSession = 0;
    this.activeSheetKind = 'more';
    this.showNativeSheet = true;
    try {
      const opened: string = await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.detailMoreOpen(' +
        session.toString() + ',' + JSON.stringify(detail.pinUrl) + ')');
      if (session !== this.pinStore.moreSession || !this.pinStore.moreApiMode) return;
      if (opened !== 'true' && opened !== '"true"') throw new Error('open');
      let raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && window.PinWebPostApi.detailMoreRead(' +
        session.toString() + ',' + JSON.stringify(detail.pinUrl) + '))');
      if (session !== this.pinStore.moreSession || !this.pinStore.moreApiMode) return;
      const state: MoreSheetMessage | null = JSON.parse(this.webJsonText(raw)) as MoreSheetMessage | null;
      if (!state || state.session !== session || state.pin !== detail.pinUrl || !Array.isArray(state.options)) throw new Error('read');
      this.pinStore.moreOptions = state.options.filter((item: MoreSheetOption): boolean => !!item.id && !!item.label);
      this.pinStore.moreLoading = false;
      this.pinStore.moreError = this.pinStore.moreOptions.length ? '' : '暂时无法读取选项';
    } catch (_) {
      if (session !== this.pinStore.moreSession) return;
      this.pinStore.moreLoading = false;
      this.pinStore.moreError = '无法读取接口选项，请重试';
    }
  }

  private async performMoreAction(id: string): Promise<void> {
    this.traceAction('pin.more', id);
    if (this.rejectOfflineAction('more.action')) return;
    const option: MoreSheetOption | undefined = this.pinStore.moreOptions.find((item: MoreSheetOption): boolean => item.id === id);
    if (!PIN_POST_API_ENABLED || !option || !option.enabled ||
        !/下载|download|查看更多|see more|查看更少|see less|详细了解.*AI|learn more.*AI|编辑.*Pin|edit pin/i.test(option.label)) return;
    if (/编辑.*Pin|edit pin/i.test(option.label) && !PIN_EDIT_API_ENABLED) return;
    const session: number = this.pinStore.moreSession;
    const pin: string = this.pinStore.morePin;
    if (!id || !session || !this.isCurrentMorePin(pin)) {
      this.pinStore.moreError = '该选项不可用';
      return;
    }
    try {
      const result: string = this.pinStore.moreApiMode ? await this.controller.runJavaScript(
        'window.PinWebPostApi && window.PinWebPostApi.moreAction(' + session.toString() + ',' +
        JSON.stringify(pin) + ',' + JSON.stringify(id) + ',function(){} )') :
        await this.controller.runJavaScript('window.PinWebNativeMoreAction && ' +
          'window.PinWebNativeMoreAction(' + session.toString() + ',' + JSON.stringify(pin) + ',' +
          JSON.stringify(id) + ')');
      if (session === this.pinStore.moreSession && result !== 'true' && result !== '"true"') {
        this.pinStore.moreError = '操作未能发出，请重试';
      }
    } catch (error) {
      if (session === this.pinStore.moreSession) this.pinStore.moreError = '操作未能发出，请重试';
    }
  }

  private async refreshMoreSheet(): Promise<void> {
    if (this.rejectOfflineAction('more.refresh')) return;
    const session: number = this.pinStore.moreSession;
    const pin: string = this.pinStore.morePin;
    if (!session || !pin) return;
    this.pinStore.moreError = '';
    this.pinStore.moreLoading = true;
    try {
      if (this.pinStore.moreApiMode) {
        let raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && window.PinWebPostApi.detailMoreRead(' +
          session.toString() + ',' + JSON.stringify(pin) + '))');
        const state: MoreSheetMessage | null = JSON.parse(this.webJsonText(raw)) as MoreSheetMessage | null;
        if (session !== this.pinStore.moreSession) return;
        this.pinStore.moreOptions = state && Array.isArray(state.options) ? state.options.filter((item: MoreSheetOption): boolean => !!item.id && !!item.label) : [];
        this.pinStore.moreLoading = false;
        this.pinStore.moreError = this.pinStore.moreOptions.length ? '' : '暂时无法读取选项';
        return;
      }
      const result: string = await this.controller.runJavaScript('window.PinWebNativeMoreRefresh && ' +
        'window.PinWebNativeMoreRefresh(' + session.toString() + ',' + JSON.stringify(pin) + ')');
      if (session === this.pinStore.moreSession && result !== 'true' && result !== '"true"') {
        this.pinStore.moreLoading = false;
        this.pinStore.moreError = '无法重新读取选项，请关闭后重试';
      }
    } catch (error) {
      if (session === this.pinStore.moreSession) {
        this.pinStore.moreLoading = false;
        this.pinStore.moreError = '无法重新读取选项';
      }
    }
  }

  private async performShareAction(id: string): Promise<void> {
    this.traceAction('pin.share', id);
    if (this.rejectOfflineAction('share action')) return;
    if (this.profileShareMode) {
      if (!this.pinStore.sharePin || !this.profileStore.profileActionsReady) return;
      const session: number = this.pinStore.shareSession;
      const page: string = this.pinStore.sharePin;
      if (id.indexOf('profile-contact:') === 0) {
        try {
          const result: string = await this.controller.runJavaScript('window.PinWebNativeShareAction && window.PinWebNativeShareAction(' + session.toString() + ',' + JSON.stringify(id) + ')');
          if (result !== 'true' && result !== '"true"') this.pinStore.shareError = '发送失败，请重试';
        } catch (_) { this.pinStore.shareError = '发送失败，请重试'; }
        return;
      }
      if (id.indexOf('profile-share:') === 0) {
        const raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebProfilePanel && window.PinWebProfilePanel.shareLink(' + JSON.stringify(page) + ',' + session + '))');
        const link: string = this.webJsonText(raw);
        if (!/^https:\/\/pin\.it\/[A-Za-z0-9]+\/?$/.test(link)) { this.pinStore.shareError = '分享链接尚未就绪'; return; }
        const platform: string = id.slice('profile-share:'.length);
        await this.sharePinUrl(link, this.profileStore.profile?.displayName || this.profileStore.profile?.handle || 'Pinterest 个人资料');
        return;
      }
      if (id !== 'profile-copy') return;
      try {
        const raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebProfilePanel && window.PinWebProfilePanel.shareLink(' + JSON.stringify(page) + ',' + session + '))');
        const link: string = this.webJsonText(raw);
        if (session !== this.pinStore.shareSession || this.currentProfileUrl() !== page || this.activeSheetKind !== 'share' || !this.profileShareMode || this.authStatus !== 'authenticated') return;
        if (!/^https:\/\/pin\.it\/[A-Za-z0-9]+\/?$/.test(link)) { this.pinStore.shareError = '分享链接尚未就绪'; return; }
        await this.systemActions.copyText(link);
        if (session === this.pinStore.shareSession && this.profileShareMode && this.activeSheetKind === 'share') {
          this.pinStore.shareFeedback = '链接已复制'; this.showShareFeedbackSnack();
        }
      } catch (_) { this.pinStore.shareError = '复制链接失败，请重试'; }
      return;
    }
    if (!PIN_POST_API_ENABLED) return;
    if (!id || !this.pinStore.shareSession) {
      this.pinStore.shareError = '该分享选项不可用';
      return;
    }
    const session: number = this.pinStore.shareSession;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebNativeShareAction && ' +
        'window.PinWebNativeShareAction(' + session.toString() + ',' + JSON.stringify(id) + ')');
      if (session === this.pinStore.shareSession && result !== 'true' && result !== '"true"') {
        this.pinStore.shareError = '操作未能完成，请重试';
      }
    } catch (error) {
      if (session === this.pinStore.shareSession) {
        this.pinStore.shareError = '操作未能完成，请重试';
      }
    }
  }

  private async searchShareContacts(value: string): Promise<void> {
    if (this.rejectOfflineAction('share contact search')) return;
    this.pinStore.shareQuery = value;
    const session: number = this.pinStore.shareSession;
    if (!session) {
      return;
    }
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebNativeShareSearch && ' +
        'window.PinWebNativeShareSearch(' + session.toString() + ',' + JSON.stringify(value) + ')');
      if (session === this.pinStore.shareSession && result !== 'true' && result !== '"true"') {
        this.pinStore.shareError = '联系人搜索不可用';
      }
    } catch (error) {
      if (session === this.pinStore.shareSession) {
        this.pinStore.shareError = '联系人搜索不可用';
      }
    }
  }

  private async refreshShareSheet(): Promise<void> {
    if (this.rejectOfflineAction('share refresh')) return;
    this.pinStore.shareSnackKey = '';
    const session: number = this.pinStore.shareSession;
    if (!session) {
      return;
    }
    this.pinStore.shareError = '';
    this.pinStore.shareLoading = !(PIN_POST_API_ENABLED && this.pinStore.shareOnPinDetail);
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebNativeShareRefresh && ' +
        'window.PinWebNativeShareRefresh(' + session.toString() + ')');
      if (session === this.pinStore.shareSession && result !== 'true' && result !== '"true"') {
        this.pinStore.shareLoading = false;
        this.pinStore.shareError = '无法重新读取分享选项，请关闭后重试';
      }
    } catch (error) {
      this.pinStore.shareLoading = false;
      this.pinStore.shareError = '无法重新读取分享选项';
    }
  }

  private sharePlatformName(label: string): string {
    const chinese: RegExpMatchArray | null = label.match(/^通过\s*(.+?)\s*分享$/);
    const english: RegExpMatchArray | null = label.match(/^Share\s+(?:via|through|on)\s+(.+)$/i);
    const name: string = chinese ? chinese[1].trim() : english ? english[1].trim() : label.trim();
    if (/^(?:Facebook\s+)?Messenger$/i.test(name)) return 'Messenger';
    if (/^(?:消息|信息|短信|Message|Messages|SMS)$/i.test(name)) return '短信';
    if (/^(?:Twitter|X)$/i.test(name)) return 'X';
    return name;
  }

  private isCopyLinkAction(label: string): boolean {
    return /^(?:复制|Copy)\s*/i.test(label.trim()) && /(?:链接|link)/i.test(label);
  }

  private hasCarouselCopyLink(): boolean {
    return this.pinStore.shareOptions.some((option: ShareSheetOption) => this.isCopyLinkAction(option.label));
  }

  private shareOptionGlyph(label: string): string {
    if (this.isCopyLinkAction(label)) return '🔗';
    if (/^(?:Facebook)$/i.test(label)) return 'f';
    if (/^(?:WhatsApp)$/i.test(label)) return '☎';
    if (/^(?:X|Twitter)$/i.test(label)) return '𝕏';
    if (/^(?:短信|Messenger)$/i.test(label)) return '●';
    return label.slice(0, 1).toUpperCase();
  }

  private shareOptionColor(label: string): string {
    if (this.isCopyLinkAction(label)) return '#343537';
    if (/^Messenger$/i.test(label)) return '#7556EF';
    if (/^Facebook$/i.test(label)) return '#1877F2';
    if (label === '短信') return '#2870DD';
    if (/^(?:WhatsApp)$/i.test(label)) return '#078B18';
    if (/^(?:X|Twitter)$/i.test(label)) return '#111111';
    return '#E84057';
  }

  private inboxUrlFromAddress(address: string): string {
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/(messages|inbox|updates|notifications)\/?(?:[?#]|$)/i);
    return match ? match[1] + '/' + match[2] + '/' : '';
  }

  private currentInboxUrl(): string {
    const nativeAddress: string = this.nativeRootPageAddress(2);
    if (nativeAddress) return this.inboxUrlFromAddress(nativeAddress);
    try {
      return this.inboxUrlFromAddress(this.controller.getUrl());
    } catch (error) {
      return '';
    }
  }

  private clearInbox(): void {
    this.finishRootPull('inbox');
    this.inboxStore.inboxSectionReady = false;
    const inboxHasContent: boolean = !!this.inboxStore.inbox &&
      (this.inboxStore.inboxActionsReady || this.inboxStore.inbox.items.length > 0 ||
        this.inboxStore.inbox.contacts.length > 0);
    if (this.inboxStore.inbox && inboxHasContent) {
      this.inboxStore.inboxCache.put(this.inboxStore.inbox, this.inboxStore.inboxScrollOffset);
    }
    this.inboxStore.inboxActionsReady = false;
    this.inboxStore.inboxRetainedContent = false;
    this.inboxStore.inboxScrollOffset = 0;
    this.inboxStore.restoringInboxSection = '';
    this.inboxStore.inboxFlow = undefined;
    this.inboxStore.inboxRequestToken++;
    this.inboxStore.inbox = undefined;
    this.inboxStore.inboxSession = 0;
    this.inboxStore.inboxUrl = '';
    this.inboxStore.inboxLoading = false;
    this.inboxStore.inboxError = '';
    this.inboxStore.inboxWebFlow = false;
    this.inboxStore.pendingInboxSection = '';
  }

  private restoreInbox(address: string): boolean {
    this.inboxStore.inboxSectionReady = false;
    const url: string = this.inboxUrlFromAddress(address);
    const entry = this.inboxStore.inboxCache.get(url);
    if (!entry) return false;
    this.inboxStore.inbox = entry.snapshot;
    this.inboxStore.inboxUrl = url;
    this.inboxStore.inboxScrollOffset = entry.scrollOffset;
    this.inboxStore.inboxActionsReady = false;
    this.inboxStore.restoringInboxSection = entry.snapshot.section;
    this.inboxStore.inboxRetainedContent = true;
    this.inboxStore.inboxLoading = false;
    this.inboxStore.inboxError = '';
    return true;
  }

  private expectInbox(): void {
    if (this.inboxStore.inbox && this.inboxStore.inboxUrl === this.currentInboxUrl()) return;
    if (this.inboxStore.inbox && this.pendingWebTab === 2 &&
        this.inboxStore.inboxUrl === this.rootTabAddresses.get(2)) return;
    if (this.restoreInbox(this.currentInboxUrl())) return;
    if (this.pendingWebTab === 2 && this.restoreInbox(this.rootTabAddresses.get(2) || '')) return;
    this.inboxStore.inboxLoading = true;
    this.inboxStore.inboxError = '';
    this.inboxStore.inboxWebFlow = false;
    const token: number = ++this.inboxStore.inboxRequestToken;
    setTimeout(() => {
      if (this.inboxStore.inboxRequestToken !== token || !this.inboxStore.inboxLoading) return;
      this.inboxStore.inboxLoading = false;
      this.inboxStore.pendingInboxSection = '';
      if (this.currentInboxUrl()) this.inboxStore.inboxError = '无法读取当前 Pinterest 收件箱，请重试';
      else this.clearInbox();
    }, 8000);
  }

  private updateInbox(value: string): void {
    if (this.nativeRootOnly && !this.rootContentInteracted) return;
    if (this.nativeBackTarget) {
      try {
        if (this.pageHistory.key(this.controller.getUrl()) !== this.pageHistory.key(this.nativeBackTarget)) return;
      } catch (_) { return; }
    }
    try {
      const flow: PinWebInboxFlowSnapshot = JSON.parse(value) as PinWebInboxFlowSnapshot;
      if (flow.kind === 'nativeFlow') {
        if (flow.pageUrl !== this.currentInboxUrl() || flow.session !== this.inboxStore.inboxSession) return;
        if (flow.screen === 'closed') { this.inboxStore.inboxFlow = undefined; return; }
        if (!Array.isArray(flow.users) || !Array.isArray(flow.messages) || !Array.isArray(flow.selectedIds)) return;
        this.inboxStore.inboxFlow = flow;
        return;
      }
      const message: PinWebInboxSnapshot = JSON.parse(value) as PinWebInboxSnapshot;
      if (!message || typeof message.session !== 'number' || typeof message.pageUrl !== 'string') return;
      if (message.kind === 'closed') {
        if (this.currentInboxUrl()) return;
        if (message.pageUrl === this.inboxStore.inboxUrl && message.session >= this.inboxStore.inboxSession) this.clearInbox();
        return;
      }
      if (this.currentInboxUrl() !== message.pageUrl || message.session < this.inboxStore.inboxSession) return;
      if (message.kind === 'unavailable') {
        this.finishRootPull('inbox');
        this.inboxStore.inboxSectionReady = false;
        this.inboxStore.inboxSession = message.session;
        this.inboxStore.inboxUrl = message.pageUrl;
        this.inboxStore.inboxRequestToken++;
        this.inboxStore.inbox = undefined;
        this.inboxStore.inboxLoading = false;
        this.inboxStore.inboxError = '无法识别当前收件箱内容，请重试';
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') ||
        (message.section !== 'updates' && message.section !== 'messages') ||
        !message.updateLabel || !message.inboxLabel ||
        !Array.isArray(message.items) || !Array.isArray(message.contacts)) return;
      if (this.inboxStore.pendingInboxSection && this.inboxStore.pendingInboxSection !== message.section) return;
      if (this.inboxStore.restoringInboxSection && this.inboxStore.restoringInboxSection !== message.section) {
        const section: string = this.inboxStore.restoringInboxSection;
        this.inboxStore.restoringInboxSection = '';
        this.inboxStore.pendingInboxSection = section;
        this.inboxStore.inboxSession = message.session;
        this.controller.runJavaScript('window.PinWebInboxSelectApi && window.PinWebInboxSelectApi(' +
          JSON.stringify(section) + ',' + message.session.toString() + ')')
          .then((result: string) => {
            if (this.inboxStore.inboxSession !== message.session || this.currentInboxUrl() !== message.pageUrl) return;
            if (result !== 'true' && result !== '"true"') {
              this.inboxStore.pendingInboxSection = '';
              this.inboxStore.inboxError = '无法恢复收件箱分段，请重试';
            }
          }).catch(() => {
            if (this.inboxStore.inboxSession !== message.session || this.currentInboxUrl() !== message.pageUrl) return;
            this.inboxStore.pendingInboxSection = '';
            this.inboxStore.inboxError = '无法恢复收件箱分段，请重试';
          });
        setTimeout(() => {
          if (this.inboxStore.inboxSession !== message.session || this.currentInboxUrl() !== message.pageUrl ||
              this.inboxStore.pendingInboxSection !== section) return;
          this.inboxStore.pendingInboxSection = '';
          this.inboxStore.inboxError = '收件箱分段恢复超时，请重试';
        }, 8000);
        return;
      }
      this.inboxStore.restoringInboxSection = '';
      this.inboxStore.inboxSectionReady = true;
      const cachedInbox = this.inboxStore.inboxCache.get(message.pageUrl, message.section);
      const retainingInbox: boolean = !!cachedInbox && message.kind !== 'state';
      this.inboxStore.inboxRetainedContent = retainingInbox;
      if (this.inboxStore.inbox && this.inboxStore.inbox.section !== message.section) this.inboxStore.inboxScrollOffset = cachedInbox?.scrollOffset || 0;
      this.inboxStore.inboxSession = message.session;
      this.inboxStore.inboxUrl = message.pageUrl;
      this.inboxStore.inboxRequestToken++;
      this.inboxStore.pendingInboxSection = '';
      this.inboxStore.inboxLoading = false;
      this.inboxStore.inboxError = '';
      this.inboxStore.inboxWebFlow = false;
      this.inboxStore.inboxLoading = !retainingInbox && message.kind === 'apiPending';
      this.inboxStore.inboxError = message.kind === 'apiFailed' ? (message.apiError || (message.section === 'updates' ? '更新接口读取失败，请重试' : '会话列表读取失败，请重试')) : '';
      this.inboxStore.inbox = {
        kind: 'state', session: message.session, pageUrl: message.pageUrl, section: message.section,
        updateLabel: message.updateLabel, inboxLabel: message.inboxLabel,
        emptyTitle: message.emptyTitle || '', emptyDescription: message.emptyDescription || '',
        homeLabel: message.homeLabel || '', homeId: message.homeId || '',
        composeLabel: message.composeLabel || '', composeId: message.composeId || '',
        contactsLabel: message.contactsLabel || '',
        dataSource: message.dataSource, hasMore: message.hasMore, moreLoading: message.moreLoading, moreError: message.moreError,
        contactsDataSource: message.contactsDataSource, contactsLoading: message.contactsLoading,
        contactsError: message.contactsError,
        messagesLabel: message.messagesLabel, readLabel: message.readLabel, unreadLabel: message.unreadLabel,
        items: retainingInbox && cachedInbox ? cachedInbox.snapshot.items :
          message.items.filter((item: PinWebInboxItem): boolean => !!item.id && !!item.title),
        contacts: (message.contactsLoading || message.contactsError) && cachedInbox ?
          cachedInbox.snapshot.contacts.map((item: PinWebInboxItem): PinWebInboxItem => {
            return { id: item.id, title: item.title, subtitle: item.subtitle, imageUrl: item.imageUrl, enabled: false };
          }) :
          message.contacts.filter((item: PinWebInboxItem): boolean => !!item.id && !!item.title)
      };
      this.inboxStore.inboxActionsReady = message.kind === 'state';
      if (message.kind === 'apiFailed' || message.kind === 'state' &&
          (message.section === 'updates' || message.contactsLoading !== true)) this.finishRootPull('inbox');
      if (this.inboxStore.inboxActionsReady) {
        this.inboxStore.inboxCache.put(this.inboxStore.inbox, this.inboxStore.inboxScrollOffset);
        this.rootTabAddresses.set(2, message.pageUrl);
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid inbox state');
    }
  }

  private searchUrlFromAddress(address: string): string {
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com\/search(?:\/[^?#]*)?\/?(?:\?[^#]*)?)/i);
    return match ? match[1] : '';
  }

  private currentSearchPageKey(): string {
    const nativeAddress: string = this.nativeRootPageAddress(1);
    if (nativeAddress) return this.searchUrlFromAddress(nativeAddress);
    try {
      return this.searchUrlFromAddress(this.controller.getUrl());
    } catch (error) {
      return '';
    }
  }

  private pendingSearchPageKey(): string {
    if (this.activeTab !== 1 || (this.pendingWebTab !== 1 && this.retainedRootTabPending !== 1)) return '';
    const target: string = this.rootTabAddresses.get(1) || this.retainedRootTabAddress;
    return this.searchUrlFromAddress(target) || this.searchStore.search?.pageKey || '';
  }

  private nativeSearchPageVisible(): boolean {
    if (this.nativeRootOnly) return this.activeTab === 1 && !this.pinStore.detail && !this.loadFailed;
    const currentPage: string = this.searchUrlFromAddress(this.nativeDisplayAddress());
    const pendingPage: string = this.pendingSearchPageKey();
    const switchingToSearch: boolean = this.activeTab === 1 &&
      (this.pendingWebTab === 1 || this.retainedRootTabPending === 1);
    return this.activeTab === 1 && !!(currentPage || pendingPage) &&
      !!(this.searchStore.search || this.searchStore.searchLoading || this.searchStore.searchError) &&
      !this.pinStore.detail && (switchingToSearch ||
        !this.profileStore.profile && !this.profileStore.profileLoading && !this.profileStore.profileError) &&
      !this.inboxStore.inbox && !this.loadFailed;
  }

  private isHomeRootAddress(address: string): boolean {
    return /^https:\/\/(?:[^/]+\.)?pinterest\.com(?:\/(?:ideas|today)\/?)?\/?(?:[?#]|$)/i.test(address);
  }

  /**
   * A root-tab history move can emit a late Web.onPageBegin for the route that
   * was selected just before the latest tap. That document must not mutate the
   * native stores or auth epoch for the newer target. Keep this check limited
   * to an active root-tab request; detail and secondary-page navigations still
   * use the normal page lifecycle below.
   */
  private rootTabMatchesAddress(index: number, address: string): boolean {
    return this.rootTabIndexFromAddress(address) === index;
  }

  private rootTabIndexFromAddress(address: string): number {
    if (this.isHomeRootAddress(address)) return 0;
    if (this.searchUrlFromAddress(address)) return 1;
    if (this.inboxUrlFromAddress(address)) return 2;
    const profileRoute: string = this.profileUrlFromAddress(address);
    if (profileRoute) {
      const addressPath: string = address.split(/[?#]/, 1)[0].replace(/\/+$/, '');
      const profilePath: string = profileRoute.split(/[?#]/, 1)[0].replace(/\/+$/, '');
      if (addressPath === profilePath || /\/_saved$|\/_created$/i.test(addressPath)) return 3;
    }
    return -1;
  }

  private rootTabKindFromAddress(address: string): string {
    const index: number = this.rootTabIndexFromAddress(address);
    if (index === 0) return 'home';
    if (index === 1) return 'search';
    if (index === 2) return 'inbox';
    if (index === 3) return 'profile';
    return 'other';
  }

  private staleRootDocumentTarget(): number {
    if (this.retainedRootTabPending >= 0) return this.retainedRootTabPending;
    if (this.pendingWebTab >= 0) return this.pendingWebTab;
    return this.rootTabGuardTarget;
  }

  private clearRootTabGuard(reason: string): void {
    this.nativeRootOnly = false;
    if (reason === 'root-visible' && this.detailReturnedToRoot) return;
    this.detailReturnedToRoot = false;
    if (this.rootTabGuardTarget < 0) return;
    PinWebRuntimeLog.info('RootTabTrace: guard-cleared targetTab=' + this.rootTabGuardTarget.toString() +
      ' reason=' + reason);
    this.rootTabGuardTarget = -1;
    this.rootTabGuardAddress = '';
  }

  private effectiveRootDocumentTarget(): number {
    const pending: number = this.staleRootDocumentTarget();
    return pending >= 0 ? pending : this.activeTab;
  }

  private isStaleRootDocumentBegin(address: string): boolean {
    const pendingTarget: number = this.staleRootDocumentTarget();
    const target: number = this.effectiveRootDocumentTarget();
    if (isPinterestAuthRoute(address)) return false;
    const documentRoot: number = this.rootTabIndexFromAddress(address);
    // Detail, board, inbox-conversation and other secondary routes are not
    // root-tab documents. Let their normal lifecycle update stores and state.
    if (target < 0 || documentRoot < 0) return false;
    if (documentRoot !== target) return true;
    // Without a pending navigation, the active native root is the only
    // authority available. Do not compare against a stale route address.
    if (pendingTarget < 0) return false;
    const expected: string = this.rootTabGuardTarget === target && this.rootTabGuardAddress ? this.rootTabGuardAddress :
      this.retainedRootTabPending === target ? this.retainedRootTabAddress :
        (this.rootTabAddresses.get(target) || '');
    if (!expected) return false;
    return this.pageHistory.key(expected) !== this.pageHistory.key(address);
  }

  private rootTabsScrollHidden: boolean[] = [false, false, false, false];
  private inboxContentScrollable: boolean = false;
  private childBottomBarRestoreHidden: boolean | null = null;
  private childBottomBarRootTab: number = -1;
  private floatingTabsMounted: boolean = false;
  private floatingTabsMotionToken: number = 0;

  // Ported from Frogmark: HdsTabs owns the animation and layout stays stable.
  private setBottomBarHidden(hidden: boolean,
    mode: HdsAnimationMode = HdsAnimationMode.SCROLL_ANIMATION): void {
    if (!this.floatingTabsMounted || this.floatingTabsHidden === hidden) return;
    this.floatingTabsHidden = hidden;
    if (hidden) this.tabsController.applyHideAnimation(mode);
    else this.tabsController.applyShowAnimation(mode);
  }

  private onBottomBarScrollSettingChanged(): void {
    this.rootTabsScrollHidden = [false, false, false, false];
    if (this.childBottomBarRestoreHidden !== null) this.childBottomBarRestoreHidden = false;
    this.syncFloatingTabsMotion();
  }

  private updateInboxScrollAvailability(scrollable: boolean): void {
    this.inboxContentScrollable = scrollable;
    if (scrollable) return;
    this.rootTabsScrollHidden[2] = false;
    if (this.childBottomBarRootTab === 2) this.childBottomBarRestoreHidden = false;
    if (this.authStatus === 'authenticated' && this.activeTab === 2 && this.nativeRootTabsVisible()) {
      this.setBottomBarHidden(false, HdsAnimationMode.SCROLL_ANIMATION);
    }
  }

  private handleRootContentScroll(offset: number, state: ScrollState): void {
    if (this.activeTab === 2 && !this.inboxContentScrollable) return;
    if (!this.bottomBarScrollCollapseEnabled || state !== ScrollState.Scroll || offset === 0 ||
        !this.floatingTabsMounted || this.authStatus !== 'authenticated' ||
        this.pinStore.detailOpeningPin || !this.nativeRootTabsVisible()) return;
    const hidden: boolean = offset > 0;
    this.rootTabsScrollHidden[this.activeTab] = hidden;
    this.setBottomBarHidden(hidden);
  }

  private syncBottomBarForPageDepth(): void {
    if (this.authStatus !== 'authenticated') {
      this.rootTabsScrollHidden = [false, false, false, false];
      this.childBottomBarRestoreHidden = null;
      this.childBottomBarRootTab = -1;
      this.setBottomBarHidden(true, HdsAnimationMode.CLICK_ANIMATION);
      return;
    }
    if (this.pinStore.detailOpeningPin || !this.nativeRootTabsVisible()) {
      // Like Frogmark folder depth: capture once, never overwrite in children.
      if (this.childBottomBarRestoreHidden === null) {
        this.childBottomBarRootTab = this.activeTab;
        this.childBottomBarRestoreHidden = this.rootTabsScrollHidden[this.activeTab] || false;
      }
      this.setBottomBarHidden(true, HdsAnimationMode.CLICK_ANIMATION);
      return;
    }
    if (this.childBottomBarRestoreHidden !== null) {
      this.rootTabsScrollHidden[this.childBottomBarRootTab] = this.childBottomBarRestoreHidden;
      this.childBottomBarRestoreHidden = null;
      this.childBottomBarRootTab = -1;
    }
    this.setBottomBarHidden(this.rootTabsScrollHidden[this.activeTab] || false,
      HdsAnimationMode.CLICK_ANIMATION);
  }

  private syncFloatingTabsMotion(): void {
    const token: number = ++this.floatingTabsMotionToken;
    // Web route and native snapshot fields can change together in one turn.
    setTimeout(() => {
      if (token !== this.floatingTabsMotionToken || !this.floatingTabsMounted) return;
      this.syncBottomBarForPageDepth();
    }, 0);
  }

  private nativeRootTabsVisible(): boolean {
    if (this.profileStore.publishFlow || this.profileStore.publishPicking) return false;
    if (this.profileStore.origins.length > 0 || this.profileSettingsVisible || this.profileStore.panel) return false;
    if (this.inboxStore.inboxFlow) return false;
    if (this.searchStore.search && this.nativeSearchPageVisible() && this.searchStore.search.quiz && this.searchStore.search.quiz.mode !== 'entry') return false;
    if (this.profileStore.profile && this.profileStore.profile.organize) return false;
    if (this.boardStore.pendingBoardUrl) return false;
    if (this.boardUrlFromAddress(this.navigationAddress)) return false;
    if (this.activeSheetKind || this.pinStore.detail || this.pinStore.detailWebFlow ||
        this.extractPinUrl(this.nativeDisplayAddress()) || this.profileStore.profileWebFlow || this.inboxStore.inboxWebFlow) return false;
    if (this.nativeRootOnly) return true;
    if (typeof this.pendingWebTab === 'number' && this.pendingWebTab >= 0) return true;
    const address: string = this.navigationAddress;
    if (this.isHomeRootAddress(address)) return true;
    if (/^https:\/\/(?:[^/]+\.)?pinterest\.com\/search\/?(?:[?#]|$)/i.test(address)) {
      return !/[?&]q=[^&#]+/i.test(address);
    }
    if (this.inboxUrlFromAddress(address)) return true;
    const profileRoute: string = this.profileUrlFromAddress(address);
    return !!profileRoute && (this.activeTab === 3 ||
      this.profileStore.profileUrl === profileRoute && !!this.profileStore.profile || this.profileStore.profileLoading || !!this.profileStore.profileError);
  }

  private shouldKeepSearchPageMounted(): boolean {
    const searchPage: string = this.searchUrlFromAddress(this.nativeDisplayAddress()) || this.pendingSearchPageKey();
    // A hidden HdsNavigation still receives the system back gesture.
    // Retain search data in the runtime cache, not an inactive navigation tree.
    return this.activeTab === 1 && !!searchPage && !this.extractPinUrl(this.nativeDisplayAddress()) &&
      !this.pinStore.detail && !this.pinStore.detailWebFlow;
  }

  private shouldKeepSearchRootMounted(): boolean {
    const searchPage: string = this.searchStore.search?.pageKey || this.searchStore.retainedSearch?.pageKey || '';
    return !!searchPage && !this.pinStore.detail && !this.pinStore.detailWebFlow &&
      !this.extractPinUrl(this.nativeDisplayAddress());
  }

  private preservingSearchForPin(): boolean {
    return !!this.searchStore.search && !!this.searchStore.searchReturnPageKey &&
      this.searchStore.search.pageKey === this.searchStore.searchReturnPageKey && !!this.currentPinUrl();
  }

  private hasMeaningfulSearchPinTitle(value: string): boolean {
    return this.searchController.hasMeaningfulSearchPinTitle(value);
  }


  private clearSearch(): void {
    return this.searchController.clearSearch();
  }

  private searchPlaceholder(): PinWebSearchSnapshot {
    return this.searchController.searchPlaceholder();
  }

  private restoreRetainedSearch(pageKey: string): boolean {
    return this.searchController.restoreRetainedSearch(pageKey);
  }

  private backFromSearch(): void {
    if (this.pinStore.detail || this.currentPinUrl()) {
      this.backFromDetail();
      return;
    }
    if (!this.currentSearchPageKey()) return;
    if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    const pageKey: string = this.currentSearchPageKey();
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!/\/search\/[^?#/]+/i.test(pageKey) && !/[?&]q=[^&#]+/i.test(pageKey)) {
      if (search && search.query.trim()) {
        // The query suggestions are a state of the search landing route.
        // Navigating to that same URL cannot dismiss them.
        this.searchStore.retainedSearch = undefined;
        this.searchStore.searchQueryClearPage = pageKey;
        this.updateSearchQuery('');
        this.searchStore.search = { kind: 'state', session: search.session, pageKey: search.pageKey,
          query: '', placeholder: search.placeholder, selectedCategory: search.selectedCategory,
          categories: search.categories, suggestions: [], heroes: search.heroes,
          ideaSections: search.ideaSections, results: [] };
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '';
        this.searchStore.searchCache.put(this.searchStore.search, 0);
        return;
      }
      this.backFromSearchLanding();
      return;
    }
    const origin: string = pageKey.match(/^https:\/\/[^/]+/i)?.[0] || PINTEREST_URL.replace(/\/$/, '');
    const target: string = origin + '/search/';
    this.pageHistory.cancelBack();
    this.pageHistory.visit(pageKey, 'load');
    this.pageHistory.prepareBackTo(target);
    this.searchStore.retainedSearch = undefined;
    this.searchStore.searchQuizReturnPage = '';
    this.searchStore.searchQueryClearPage = '';
    this.searchStore.searchCache.put(this.searchStore.search || this.searchPlaceholder(), this.searchStore.searchScrollOffset);
    this.clearSearch();
    this.activeTab = 1;
    const token: number = ++this.pageBackToken;
    try {
      this.controller.loadUrl(target);
      setTimeout(() => { if (token === this.pageBackToken) this.pageHistory.cancelBack(); }, 2500);
    } catch (error) {
      this.pageHistory.cancelBack();
      this.showMessage('无法返回搜索页，请重试');
    }
  }

  private backFromSearchLanding(): void {
    if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    this.backOnePage(PINTEREST_URL, PINTEREST_URL);
  }


  private async openSearchFilters(): Promise<void> {
    return this.searchController.openSearchFilters();
  }


  private async retrySearchFilters(): Promise<void> {
    return this.searchController.retrySearchFilters();
  }

  private async selectSearchFilter(id: string): Promise<void> {
    return this.searchController.selectSearchFilter(id);
  }

  private dismissSearchFilters(): void {
    return this.searchController.dismissSearchFilters();
  }

  private expectSearch(): void {
    return this.searchController.expectSearch();
  }

  private updateSearch(value: string): void {
    if (this.nativeRootOnly && !this.rootContentInteracted) return;
    if (this.nativeBackTarget) {
      try {
        if (this.pageHistory.key(this.controller.getUrl()) !== this.pageHistory.key(this.nativeBackTarget)) return;
      } catch (_) { return; }
    }
    return this.searchController.updateSearch(value);
  }

  private async updateSearchQuery(value: string, refreshSuggestions: boolean = false): Promise<void> {
    return this.searchController.updateSearchQuery(value, refreshSuggestions);
  }

  private async submitSearch(value: string): Promise<void> {
    return this.searchController.submitSearch(value);
  }

  private async performSearchAction(id: string, kind: string): Promise<void> {
    return this.searchController.performSearchAction(id, kind);
  }

  private loadMoreSearch(): void {
    return this.searchController.loadMoreSearch();
  }

  private finishRootPull(kind: string): void {
    if (this.rootPullKind !== kind) return;
    this.rootPullKind = '';
    this.rootPullToken++;
  }

  private async pullRefreshRoot(kind: string): Promise<void> {
    if (this.rootPullKind || this.authStatus !== 'authenticated') return;
    if (this.nativeRootOnly && this.prepareRootPageRead(kind === 'search' ? 1 : 2)) return;
    const page: string = kind === 'search' ? this.currentSearchPageKey() : this.currentInboxUrl();
    if (!page) return;
    this.rootPullKind = kind;
    const token: number = ++this.rootPullToken;
    setTimeout(() => {
      if (token !== this.rootPullToken || this.rootPullKind !== kind) return;
      this.finishRootPull(kind);
      const current: string = kind === 'search' ? this.currentSearchPageKey() : this.currentInboxUrl();
      if (current !== page) return;
      if (kind === 'search') { this.searchStore.searchLoading = false; this.searchStore.searchError = '刷新超时，请重试'; }
      else { this.inboxStore.inboxLoading = false; this.inboxStore.inboxError = '刷新超时，请重试'; }
    }, 20000);
    if (kind === 'search') await this.refreshSearch();
    else await this.retryInbox();
    if (token !== this.rootPullToken) return;
    if (kind === 'search' ? !!this.searchStore.searchError : !!this.inboxStore.inboxError) this.finishRootPull(kind);
  }

  private async refreshSearch(): Promise<void> {
    return this.searchController.refreshSearch();
  }

  private inboxPlaceholder(): PinWebInboxSnapshot {
    return {
      kind: 'state', session: 0, pageUrl: '', section: 'updates',
      updateLabel: '更新', inboxLabel: '收件箱', emptyTitle: '', emptyDescription: '',
      homeLabel: '', homeId: '', composeLabel: '', composeId: '', contactsLabel: '',
      items: [], contacts: []
    };
  }

  private async selectInboxSection(section: string): Promise<void> {
    this.traceAction('inbox.section', section);
    if (section !== 'updates' && section !== 'messages') return;
    if (!await this.ensureRootActionContext(2, false)) return;
    if (!this.inboxStore.inboxSectionReady || !this.inboxStore.inbox || this.inboxStore.inboxSession !== this.inboxStore.inbox.session || this.inboxStore.inboxUrl !== this.currentInboxUrl() ||
      this.inboxStore.restoringInboxSection || this.inboxStore.pendingInboxSection) return;
    if (this.inboxStore.inboxActionsReady === false && this.inboxStore.inbox.dataSource !== 'api') return;
    if (this.inboxStore.inboxActionsReady && !this.inboxStore.inboxLoading && !this.inboxStore.inboxError) this.inboxStore.inboxCache.put(this.inboxStore.inbox, this.inboxStore.inboxScrollOffset);
    this.inboxStore.inboxScrollOffset = 0;
    if (!this.inboxStore.inbox || ((this.inboxStore.inboxLoading || !!this.inboxStore.inboxError) && this.inboxStore.inbox.dataSource !== 'api') ||
      section === this.inboxStore.inbox.section || this.inboxStore.inboxUrl !== this.currentInboxUrl()) return;
    const session: number = this.inboxStore.inboxSession;
    const token: number = ++this.inboxStore.inboxRequestToken;
    this.inboxStore.pendingInboxSection = section;
    this.inboxStore.inboxLoading = true;
    try {
      const result: string = await this.controller.runJavaScript(
        'window.PinWebInboxSelectApi && window.PinWebInboxSelectApi(' +
        JSON.stringify(section) + ',' + session.toString() + ')');
      if (result === 'true' || result === '"true"') {
        setTimeout(() => {
          if (this.inboxStore.inboxRequestToken !== token || this.inboxStore.pendingInboxSection !== section) return;
          this.inboxStore.pendingInboxSection = '';
          this.inboxStore.inboxLoading = false;
          this.showMessage('收件箱接口切换超时，请重试');
        }, 4500);
        return;
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: inbox section switch failed');
    }
    if (this.inboxStore.inboxRequestToken !== token) return;
    this.inboxStore.pendingInboxSection = '';
    this.inboxStore.inboxLoading = false;
    this.showMessage('当前分段不可用，请重试');
  }

  private async performInboxAction(id: string): Promise<void> {
    this.traceAction('inbox.action', id);
    if (!PIN_INBOX_CONVERSATIONS_API_ENABLED ||
        !(id === 'compose' || id === 'home' || /^(?:conversation:|contact:|news-menu:)/.test(id))) return;
    if (!await this.ensureRootActionContext(2)) return;
    if (this.inboxStore.inboxActionsReady === false) return;
    if (!id || !this.inboxStore.inbox || this.inboxStore.inboxUrl !== this.currentInboxUrl()) return;
    try {
      const result: string = await this.controller.runJavaScript(
        'window.PinWebInboxApiAction && window.PinWebInboxApiAction(' +
        JSON.stringify(id) + ',' + this.inboxStore.inboxSession.toString() + ')');
      if (result === 'true' || result === '"true"') {
        // Keep the native inbox overlay until the bridge reports that the page
        // has actually left the inbox root (route change or modal flow).
        return;
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: inbox action failed');
    }
    this.showMessage('收件箱接口入口不可用，请重试');
  }

  private async inboxFlowAction(action: string, value: string = ''): Promise<void> {
    if (!this.inboxStore.inboxFlow || this.inboxStore.inboxFlow.pageUrl !== this.currentInboxUrl()) return;
    PinWebRuntimeLog.info('PinWebInbox: action ' + action);
    try {
      await this.controller.runJavaScript('window.PinWebInboxConversations && window.PinWebInboxConversations.action(' +
        JSON.stringify(action) + ',' + JSON.stringify(value) + ',' + this.inboxStore.inboxSession.toString() + ')');
    } catch (error) { this.showMessage('当前消息操作不可用，请重试'); }
  }

  private async loadMoreInbox(): Promise<void> {
    if (this.inboxStore.inboxActionsReady === false) return;
    if (!this.inboxStore.inbox || this.inboxStore.inbox.section !== 'updates' || this.inboxStore.inboxUrl !== this.currentInboxUrl()) return;
    try { await this.controller.runJavaScript('window.PinWebInboxApiMore && window.PinWebInboxApiMore(' + this.inboxStore.inboxSession.toString() + ')'); }
    catch (error) { this.showMessage('无法加载更多更新，请重试'); }
  }
  private async retryInbox(): Promise<void> {
    if (this.nativeRootOnly && this.prepareRootPageRead(2)) return;
    if (!this.currentInboxUrl()) { this.requestRootPage(2); return; }
    this.inboxStore.inboxActionsReady = false;
    this.inboxStore.inboxError = '';
    this.inboxStore.restoringInboxSection = '';
    this.inboxStore.pendingInboxSection = '';
    this.expectInbox();
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebInboxApiRefresh && window.PinWebInboxApiRefresh()');
      if (result !== 'true' && result !== '"true"') {
        this.inboxStore.inboxLoading = false;
        this.inboxStore.inboxError = '无法重新读取收件箱，请稍后重试';
      }
    } catch (error) {
      this.inboxStore.inboxLoading = false;
      this.inboxStore.inboxError = '无法重新读取收件箱，请稍后重试';
    }
  }

  private async retryInboxContacts(): Promise<void> {
    if (!await this.ensureRootActionContext(2, false)) return;
    if (!this.inboxStore.inbox || this.inboxStore.inbox.section !== 'messages' || this.inboxStore.inboxUrl !== this.currentInboxUrl()) return;
    try {
      await this.controller.runJavaScript('window.PinWebInboxContactsApiRefresh && window.PinWebInboxContactsApiRefresh(' +
        this.inboxStore.inboxSession.toString() + ')');
    } catch (error) { this.showMessage('无法重新读取联系人，请重试'); }
  }

  private nativeSnapshotPageKey(index: number): string {
    if (index === 0) {
      const snapshot: PinWebHomeSnapshot | undefined = this.homeStore.home || this.homeStore.cachedHome;
      return this.homeStore.homeActionsReady && snapshot && this.isHomeRootAddress(snapshot.pageKey) &&
        (snapshot.kind === 'state' || snapshot.pins.length > 0) ? snapshot.pageKey : '';
    }
    if (index === 1) {
      const snapshot: PinWebSearchSnapshot | undefined = this.searchStore.search || this.searchStore.retainedSearch;
      return this.searchStore.searchActionsReady && snapshot ? this.searchUrlFromAddress(snapshot.pageKey) : '';
    }
    if (index === 2) {
      const snapshot: PinWebInboxSnapshot | undefined = this.inboxStore.inbox;
      return this.inboxStore.inboxActionsReady && snapshot ? this.inboxUrlFromAddress(snapshot.pageUrl) : '';
    }
    if (index === 3) {
      const snapshot: PinWebProfileSnapshot | undefined = this.profileStore.profile;
      return this.profileStore.profileActionsReady && snapshot ? this.profileUrlFromAddress(snapshot.profileUrl) : '';
    }
    return '';
  }

  private nativeRootPageAddress(index: number): string {
    if (this.nativeRootOnly) return '';
    if (this.nativeBackTarget || this.pendingWebTab >= 0 || this.pinStore.detail ||
        this.pinStore.detailOpeningPin || this.profileStore.origins.length > 0 ||
        this.inboxStore.inboxFlow || this.boardStore.pendingBoardUrl || this.activeTab !== index) return '';
    const address: string = this.rootTabAddresses.get(index) || '';
    // A displayed snapshot does not establish the hidden document session.
    try {
      if (this.pageHistory.key(address) !== this.pageHistory.key(this.controller.getUrl())) return '';
    } catch (_) { return ''; }
    if (index === 0) return this.isHomeRootAddress(address) ? address : '';
    if (index === 1) return this.searchUrlFromAddress(address);
    if (index === 2) return this.inboxUrlFromAddress(address);
    if (index === 3) return this.profileUrlFromAddress(address);
    return '';
  }

  private rootPresentationAddress(index: number): string {
    return this.rootTabAddresses.get(index) ||
      (index === 0 ? this.homeStore.home?.pageKey || PINTEREST_URL :
        index === 1 ? this.searchStore.search?.pageKey || PINTEREST_URL + 'search/' :
          index === 2 ? this.inboxStore.inbox?.pageUrl || PINTEREST_URL + 'inbox/' :
            this.authenticatedProfileUrl);
  }

  private selectNativeRootTab(index: number): void {
    if (this.authStatus !== 'authenticated' || index < 0 || index > 3) return;
    this.searchController.invalidatePending();
    this.traceAction('root.tab', index.toString());
    this.logPageLifecycle('root-tab-request', 'targetTab=' + index.toString());
    // Preserve the last completed profile snapshot before leaving a detail page.
    // The hidden Web document may take time to return to the profile route; the
    // native root can still present this account-scoped snapshot immediately.
    if (index === 3 && this.profileStore.profile) {
      const profileForCache: PinWebProfileSnapshot = this.profileStore.profile;
      this.profileStore.profileCache.put(profileForCache, this.profileStore.profileScrollOffset);
    }
    // Only ArkUI presentation changes here. Business reads belong to explicit
    // page refresh/actions, never to the bottom-bar selection.
    this.nativeRootOnly = true;
    this.rootContentInteracted = false;
    this.searchStore.searchIntentToken++;
    this.tabRequestToken++;
    this.pageBackToken++;
    this.pageHistory.cancelBack();
    this.nativeBackTarget = '';
    this.pendingWebTab = -1;
    this.retainedRootTabPending = -1;
    this.retainedRootTabAddress = '';
    this.retainedHomeDocumentPending = false;
    this.retainedHomeDocumentAddress = '';
    this.rootTabGuardTarget = index;
    this.rootTabGuardAddress = this.rootPresentationAddress(index);
    this.clearDetail(false, true);
    this.nativePinRoute = '';
    this.pinStore.detailReturnUrl = '';
    this.cancelHomeDetailMore();
    this.profileStore.origins = [];
    this.profileStore.profileWebFlow = false;
    this.inboxStore.inboxFlow = undefined;
    this.inboxStore.inboxWebFlow = false;
    this.boardStore.pendingBoardUrl = '';
    this.boardStore.pendingBoardSource = '';
    this.boardStore.boardOpeningToken++;
    this.boardStore.boardDetail = undefined;
    this.activeTab = index;
    this.tabsController.changeIndex(index);
    this.navigationAddress = this.rootTabGuardAddress;
    this.showNativeTabs = true;
    this.loadFailed = false;
    this.failureDetails = '';
    this.webPageLoading = false;
    const address: string = this.rootTabGuardAddress;
    if (index === 0) {
      const cachedHome: PinWebHomeSnapshot | undefined = this.homeStore.cachedHome;
      const homePageKey: string = this.homePageKeyFromAddress(address) || PINTEREST_URL;
      if (cachedHome && cachedHome.pageKey === homePageKey && cachedHome.pins.length > 0) {
        this.homeStore.home = cachedHome;
        this.homeStore.retainingHomeFeed = true;
        this.homeStore.homeActionsReady = false;
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = '';
        PinWebRuntimeLog.info('HomeCache: root presentation restored pins=' + cachedHome.pins.length.toString() +
          ' actionsReady=false');
      }
    }
    if (index === 1 && !this.searchStore.search) this.restoreRetainedSearch(address);
    if (index === 2 && !this.inboxStore.inbox) this.restoreInbox(address);
    if (index === 3 && this.profileStore.profile?.profileUrl !== this.profileUrlFromAddress(address)) {
      if (!this.restoreProfile(address)) {
        // Keep an existing same-session snapshot visible while the hidden
        // document catches up; current-session actions remain gated below.
        const existingProfile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
        const targetProfile: string = this.profileUrlFromAddress(address);
        if (!existingProfile || existingProfile.profileUrl !== targetProfile) {
          this.profileStore.profile = undefined;
          this.profileStore.profileUrl = '';
          this.profileStore.profileActionsReady = false;
          this.profileStore.profileScrollOffset = 0;
        }
      }
    }
    this.homeStore.homeRequestToken++;
    this.searchStore.searchRequestToken++;
    this.inboxStore.inboxRequestToken++;
    this.profileStore.profileRequestToken++;
    this.homeStore.homeRefreshToken++;
    this.homeStore.homeRefreshing = false;
    this.homeStore.homeRefreshAwaitingPage = false;
    this.profileStore.profilePullToken++;
    this.profileStore.profilePullRefreshing = false;
    this.rootPullToken++;
    this.rootPullKind = '';
    this.homeStore.homeLoading = false;
    this.searchStore.searchLoading = false;
    this.inboxStore.inboxLoading = false;
    this.profileStore.profileLoading = false;
    this.profileStore.profileSwitching = false;
    this.inboxStore.restoringInboxSection = '';
    this.inboxStore.pendingInboxSection = '';
    PinWebRuntimeLog.info('RootTabTrace: native-switch targetTab=' + index.toString() +
      ' mode=presentation-only webNavigation=false apiDemand=false');
    this.syncFloatingTabsMotion();
  }

  private rootPageHasReadState(index: number): boolean {
    if (index === 0) return !!this.homeStore.homeForPresentation(
      this.homePresentationPageKey() || this.retainedHomeRootPageKey()) ||
      this.homeStore.homeLoading || !!this.homeStore.homeError;
    if (index === 1) return !!this.searchStore.search || this.searchStore.searchLoading || !!this.searchStore.searchError;
    if (index === 2) return !!this.inboxStore.inbox || this.inboxStore.inboxLoading || !!this.inboxStore.inboxError;
    // A retained snapshot is a display state, never proof of operation readiness.
    return !!this.profileStore.profile || this.profileStore.profileLoading || !!this.profileStore.profileError;
  }

  // A visible page owns its first read; the bottom-bar handler only changes presentation.
  private onRootPageVisible(index: number, visible: boolean): void {
    if (!visible) return;
    const token: number = this.tabRequestToken;
    setTimeout(() => {
      if (this.authStatus !== 'authenticated' || this.activeTab !== index || token !== this.tabRequestToken ||
          !this.nativeRootOnly || !this.nativeRootTabsVisible() || this.pendingWebTab !== -1 || this.loadFailed ||
          this.rootPageHasReadState(index)) return;
      PinWebRuntimeLog.info('RootTabTrace: initial-page-read targetTab=' + index.toString() + ' reason=visible-empty');
      this.requestRootPage(index);
    }, 80);
  }

  private prepareSearchNavigation(address: string): void {
    this.loadFailed = false;
    this.rootTabAddresses.set(1, address);
    this.pendingWebTab = 1;
    this.retainedRootTabPending = 1;
    this.retainedRootTabAddress = address;
    this.rootTabGuardTarget = 1;
    this.rootTabGuardAddress = address;
    this.rootReadAddress = address;
    this.rootReadToken = ++this.tabRequestToken;
    this.rootReadStartedAt = Date.now();
    this.searchStore.searchActionsReady = false;
    this.searchStore.searchInputReady = false;
    this.searchStore.searchLoading = true;
    this.searchStore.searchError = '';
    this.waitForWebTabConfirmation(1, this.tabRequestToken, this.rootReadStartedAt);
  }

  private rootReadInFlight(index: number, address: string): boolean {
    if (this.loadFailed || this.rootActionContextReady(index)) return false;
    if (this.rootReadToken === this.tabRequestToken &&
        this.pageHistory.key(this.rootReadAddress) === this.pageHistory.key(address) &&
        Date.now() - this.rootReadStartedAt < 12000) return true;
    // JS search submission may start a document without a native loadUrl call.
    try {
      return this.webPageLoading && Date.now() - this.lastDocumentBeginAt < 12000 &&
        this.pageHistory.key(this.lastDocumentBeginUrl) === this.pageHistory.key(address) &&
        this.pageHistory.key(this.controller.getUrl()) === this.pageHistory.key(address);
    } catch (_) { return false; }
  }

  private requestRootPage(index: number): void {
    if (this.businessSuspended || this.authStatus !== 'authenticated' || this.activeTab !== index) return;
    if (this.pinStore.detail || this.pinStore.detailOpeningPin) return;
    const address: string = this.rootPresentationAddress(index);
    if (!address || this.rootTabIndexFromAddress(address) !== index) {
      this.showMessage('当前页面地址尚未确认，请稍后重试');
      return;
    }
    if (this.rootReadInFlight(index, address)) {
      PinWebRuntimeLog.info('RootTabTrace: page-read-joined targetTab=' + index.toString());
      return;
    }
    this.clearRootTabGuard('page-read');
    const reuseHomeDocument: boolean = index === 0 && !this.webPageLoading && !this.loadFailed &&
      !this.homeStore.homeError && this.pageHistory.key(this.controller.getUrl()) === this.pageHistory.key(address);
    const token: number = ++this.tabRequestToken;
    this.rootReadAddress = address;
    this.rootReadToken = token;
    this.rootReadStartedAt = Date.now();
    this.pendingWebTab = index;
    this.rootTabGuardTarget = index;
    this.rootTabGuardAddress = address;
    this.retainedRootTabPending = index;
    this.retainedRootTabAddress = address;
    this.rootTabAddresses.set(index, address);
    this.loadFailed = false;
    if (index === 0) this.expectHome();
    else if (index === 1) this.expectSearch();
    else if (index === 2) this.expectInbox();
    else this.expectProfile();
    PinWebRuntimeLog.info('RootTabTrace: page-read-request targetTab=' + index.toString());
    if (reuseHomeDocument) {
      // Confirm the live document and bridge before reusing it; the native
      // cached snapshot and getUrl() alone are not session evidence.
      this.controller.runJavaScript('location.href === ' + JSON.stringify(address) +
        ' && typeof window.PinWebHomeRefresh === "function" ? (window.PinWebHomeRefresh(), true) : false')
        .then((result: string) => {
          if (token !== this.tabRequestToken || this.activeTab !== 0) return;
          if (result === 'true' || result === '"true"') {
            PinWebRuntimeLog.info('HomeRecoveryTrace: phase=document-reused elapsedMs=' +
              (Date.now() - this.rootReadStartedAt).toString());
            this.syncAuthentication();
          } else {
            PinWebRuntimeLog.info('HomeRecoveryTrace: phase=document-load reason=bridge-unavailable');
            this.controller.loadUrl(address);
          }
        }).catch(() => {
          if (token !== this.tabRequestToken || this.activeTab !== 0) return;
          this.rootReadToken = -1;
          this.pendingWebTab = -1;
          this.homeStore.homeLoading = false;
          this.homeStore.homeError = '首页会话恢复失败，请重试';
          PinWebRuntimeLog.warn('HomeRecoveryTrace: phase=failed reason=document-reuse');
        });
      this.waitForWebTabConfirmation(index, token, this.rootReadStartedAt);
      return;
    }
    try {
      this.controller.loadUrl(address);
      this.waitForWebTabConfirmation(index, token, Date.now());
    } catch (_) {
      this.rootReadToken = -1;
      this.pendingWebTab = -1;
      this.retainedRootTabPending = -1;
      this.clearRootTabGuard('page-read-failed');
      this.loadFailed = true;
      this.failureDetails = '无法加载当前页面，请重试';
    }
  }

  private prepareRootPageRead(index: number): boolean {
    if (this.authStatus !== 'authenticated' || this.activeTab !== index) return true;
    const address: string = this.rootPresentationAddress(index);
    let document: string = '';
    try { document = this.controller.getUrl(); } catch (_) {}
    if (!address || this.pageHistory.key(address) !== this.pageHistory.key(document)) {
      this.requestRootPage(index);
      return true;
    }
    this.clearRootTabGuard('page-refresh');
    return false;
  }

  private rootActionContextReady(index: number, requireData: boolean = true): boolean {
    let document: string = '';
    try { document = this.controller.getUrl(); } catch (_) {}
    if (this.authStatus !== 'authenticated' || this.activeTab !== index ||
        this.pageHistory.key(document) !== this.pageHistory.key(this.rootPresentationAddress(index))) return false;
    if (index === 0) return this.homeStore.homeActionsReady && this.homeStore.home?.pageKey === this.currentHomePageKey();
    if (index === 1) return (requireData ? this.searchStore.searchActionsReady :
      this.searchStore.searchInputReady || this.searchStore.searchActionsReady) &&
      this.searchStore.search?.pageKey === this.currentSearchPageKey();
    if (index === 2) return this.inboxStore.inboxSectionReady &&
      (!requireData || this.inboxStore.inboxActionsReady) &&
      this.inboxStore.inboxSession === this.inboxStore.inbox?.session &&
      this.inboxStore.inboxUrl === this.currentInboxUrl();
    if (index === 3) return this.profileStore.profileActionsReady &&
      this.profileStore.profileSession === this.profileStore.profile?.session &&
      this.profileStore.profile?.profileUrl === this.currentProfileUrl();
    return false;
  }

  // Only explicit content intent may prepare a document. Never dispatch using a retained session.
  private async ensureRootActionContext(index: number, requireData: boolean = true, allowedSheet: string = '',
      isCurrent: () => boolean = (): boolean => true): Promise<boolean> {
    if (this.authStatus !== 'authenticated' || this.activeTab !== index || this.pinStore.detail ||
        this.pinStore.detailOpeningPin || (this.activeSheetKind && this.activeSheetKind !== allowedSheet) || !isCurrent()) return false;
    this.rootContentInteracted = true;
    if (this.rootActionContextReady(index, requireData)) {
      this.clearRootTabGuard('content-action');
      return true;
    }
    if (this.pendingWebTab !== index) this.requestRootPage(index);
    const token: number = this.tabRequestToken;
    const started: number = Date.now();
    while (Date.now() - started < 12000) {
      if (token !== this.tabRequestToken || this.authStatus !== 'authenticated' || this.activeTab !== index ||
          this.pinStore.detail || this.pinStore.detailOpeningPin ||
          (this.activeSheetKind && this.activeSheetKind !== allowedSheet) || !isCurrent()) return false;
      if (this.rootActionContextReady(index, requireData)) return true;
      if (this.loadFailed) break;
      await new Promise<void>((resolve) => setTimeout(resolve, 100));
    }
    if (token === this.tabRequestToken && this.activeTab === index) {
      PinWebRuntimeLog.warn('RootTabTrace: content-context unavailable targetTab=' + index.toString());
      this.showMessage('当前页面操作尚未就绪，请重试');
    }
    return false;
  }

  private async prepareProfileInteraction(): Promise<boolean> {
    if (this.profileStore.origins.length > 0) return this.authStatus === 'authenticated' &&
      this.profileStore.profileActionsReady && this.profileStore.profile?.profileUrl === this.currentProfileUrl();
    return this.ensureRootActionContext(3);
  }

  private profileDocumentMatches(url: string): boolean {
    let document: string = '';
    try { document = this.controller.getUrl(); } catch (_) {}
    const profileUrl: string = this.profileUrlFromAddress(url);
    return !!profileUrl && (this.profileUrlFromAddress(document) === profileUrl ||
      this.profileUrlFromAddress(this.rootTabAddresses.get(3) || '') === profileUrl);
  }

  private async performSearchQuizAction(kind: string, id: string): Promise<void> {
    if (kind === 'back' && this.returnFromSearchQuiz()) return;
    return this.searchController.performSearchQuizAction(kind, id);
  }

  private reuseRetainedWebDocument(target: string): number {
    try {
      const entries: webview.BackForwardList = this.controller.getBackForwardEntries();
      const currentIndex: number = entries.currentIndex;
      for (let index: number = 0; index < entries.size; index++) {
        if (index === currentIndex) continue;
        const item = entries.getItemAtIndex(index);
        if (!item || this.pageHistory.key(item.historyUrl) !== this.pageHistory.key(target)) continue;
        const delta: number = index - currentIndex;
        this.controller.backOrForward(delta);
        return delta;
      }
    } catch (_) {
      PinWebRuntimeLog.info('RootTabTrace: history-reuse unavailable');
    }
    return -1;
  }

  private clearRootTabCaches(clearPersistentCache: boolean = true): void {
    this.detailReturnReads.clear(); this.detailReturnReadPin = '';
    this.homeCacheRestoreAttemptKey = '';
    this.homeStartupFeedCommitted = false;
    this.homeCacheRestoreSkipReason = '';
    this.rootReadToken = -1;
    this.rootReadAddress = '';
    this.clearHome();
    this.clearSearch();
    this.clearProfile();
    this.clearInbox();
    this.rootTabAddresses.clear();
    this.clearRootTabGuard('cache-clear');
    this.inboxStore.inboxCache.clear();
    this.profileStore.profileCache.clear();
    this.searchStore.searchCache.clear();
    this.homeStore.cachedHome = undefined;
    this.homeStore.cachedHomeScrollOffset = 0;
    this.homeDiskCacheRestored = false;
    this.homeDiskCacheRestoredAt = 0;
    if (clearPersistentCache) {
      const filesRemoved: number = this.homeApiCache ? this.homeApiCache.clear() : -1;
      PinWebRuntimeLog.info('HomeCache: clear scope=memory-and-disk filesRemoved=' + filesRemoved.toString());
      this.homeCacheAccountId = '';
      this.homeCacheIdentityEpoch = -1;
      this.clearOfflineHomeMarker();
    }
    this.searchStore.retainedSearch = undefined;
    this.searchStore.retainedSearchScrollOffset = 0;
  }

  private waitForWebTabConfirmation(index: number, token: number, requestedAt: number): void {
    setTimeout(async () => {
      if (this.businessSuspended || this.tabRequestToken !== token || this.pendingWebTab !== index) return;
      if (this.loadFailed) {
        this.pendingWebTab = -1;
        return;
      }
      const now: number = Date.now();
      const pageEndGrace: boolean = this.webPageLoadFinishedAt > requestedAt &&
        now - this.webPageLoadFinishedAt < 1800;
      if (now - requestedAt >= 12000) {
        this.pendingWebTab = -1; this.rootReadToken = -1;
        PinWebRuntimeLog.warn('RootTabTrace: preparation-timeout targetTab=' + index.toString());
        this.showMessage('页面数据准备超时，请重试'); return;
      }
      if (this.webPageLoading || now - requestedAt < 6500 || pageEndGrace) {
        this.waitForWebTabConfirmation(index, token, requestedAt);
        return;
      }
      await this.refreshWebNavigation();
      if (this.tabRequestToken !== token || this.pendingWebTab !== index) return;
      if (this.currentWebTab === index) {
        this.pendingWebTab = -1;
        PinWebRuntimeLog.info('RootTabTrace: confirmed targetTab=' + index.toString() +
          ' elapsedMs=' + (Date.now() - requestedAt).toString());
        return;
      }
      this.pendingWebTab = -1;
      if (index === 3 && !this.currentProfileUrl()) this.clearProfile();
      this.showMessage('页面数据尚未准备好，请重试');
    }, 500);
  }

  private async refreshWebNavigation(): Promise<void> {
    try {
      await this.controller.runJavaScript(
        'window.PinWebNavigationRefresh && window.PinWebNavigationRefresh()');
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: navigation state refresh failed');
    }
  }

  private currentHomePageKey(): string {
    try {
      if (this.nativeRootOnly) return this.homePageKeyFromAddress(this.controller.getUrl());
      return this.homePageKeyFromAddress(this.nativeDisplayAddress());
    } catch (error) {
      return '';
    }
  }

  private initializeHomeApiCache(): void {
    if (this.homeApiCache) return;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.homeApiCache = new ApiCache(context.cacheDir);
    } catch (_) {
      PinWebRuntimeLog.warn('HomeCache: disk cache unavailable');
    }
  }

  private initializeOfflineHomeMarker(): void {
    this.initializeHomeApiCache();
    try {
      const raw: string = AppStorage.get<string>(PINWEB_HOME_OFFLINE_MARKER) || '';
      if (raw) {
        const marker: PinWebOfflineHomeMarker | undefined = this.parseOfflineHomeMarker(raw);
        if (marker) {
          this.offlineHomeMarker = marker;
          PinWebRuntimeLog.info('OfflineCache: marker loaded source=memory ageMs=' +
            Math.max(0, Date.now() - marker.savedAtMs).toString());
          return;
        }
        PinWebRuntimeLog.warn('OfflineCache: marker rejected reason=invalid-shape source=memory');
        try { AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, ''); } catch (_) {}
      }
      if (!this.homeApiCache) return;
      const diskResult = this.homeApiCache.getWithMetadata<PinWebOfflineHomeMarker>(
        PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY, PINWEB_HOME_OFFLINE_MARKER_TTL);
      PinWebRuntimeLog.info('OfflineCache: marker lookup status=' + diskResult.status +
        ' ageMs=' + diskResult.ageMs.toString());
      if (!diskResult.value) return;
      const marker: PinWebOfflineHomeMarker | undefined = this.parseOfflineHomeMarker(
        JSON.stringify(diskResult.value));
      if (!marker) {
        this.homeApiCache.remove(PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY);
        PinWebRuntimeLog.warn('OfflineCache: marker rejected reason=invalid-shape source=disk');
        return;
      }
      this.offlineHomeMarker = marker;
      try { AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, JSON.stringify(marker)); } catch (_) {}
      PinWebRuntimeLog.info('OfflineCache: marker loaded source=disk ageMs=' +
        Math.max(0, Date.now() - marker.savedAtMs).toString());
    } catch (_) {
      PinWebRuntimeLog.warn('OfflineCache: marker read failed');
    }
  }

  private parseOfflineHomeMarker(raw: string): PinWebOfflineHomeMarker | undefined {
    try {
      const marker: PinWebOfflineHomeMarker = JSON.parse(raw) as PinWebOfflineHomeMarker;
      if (!marker || !/^[a-f0-9]{32}$/i.test(marker.partitionId) ||
          !this.isHomeRootAddress(marker.pageKey) || !Number.isFinite(marker.savedAtMs) || marker.savedAtMs <= 0) {
        return undefined;
      }
      return marker;
    } catch (_) {
      return undefined;
    }
  }

  private saveOfflineHomeMarker(partitionId: string, pageKey: string): void {
    if (!/^[a-f0-9]{32}$/i.test(partitionId) || !this.isHomeRootAddress(pageKey)) return;
    const marker: PinWebOfflineHomeMarker = { partitionId: partitionId, pageKey: pageKey, savedAtMs: Date.now() };
    this.offlineHomeMarker = marker;
    try {
      if (this.homeApiCache) {
        this.homeApiCache.put(PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY, marker, PINWEB_HOME_OFFLINE_MARKER_TTL);
      }
      AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, JSON.stringify(marker));
      PinWebRuntimeLog.info('OfflineCache: marker saved source=' + (this.homeApiCache ? 'disk' : 'memory'));
    } catch (_) {
      PinWebRuntimeLog.warn('OfflineCache: marker save failed');
    }
  }

  private clearOfflineHomeMarker(): void {
    this.offlineHomeMarker = undefined;
    this.offlinePreviewMode = false;
    this.offlineCacheLoading = false;
    if (this.homeApiCache) this.homeApiCache.remove(PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY);
    try { AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, ''); } catch (_) {}
  }

  private homeCacheAccountIdFromProfileUrl(profileUrl: string): string {
    const match: RegExpMatchArray | null = profileUrl.match(
      /^https:\/\/(?:www\.)?pinterest\.com\/([a-zA-Z0-9_]+)\/?(?:[?#]|$)/i);
    return match ? hashCacheString(match[1].toLowerCase()) : '';
  }

  private homeCacheKey(accountId: string, pageKey: string): string {
    const params: PinWebHomeCacheKeyParams = { pageKey: pageKey };
    return buildCacheKey(accountId, 'home_feed', params);
  }

  private tryRestoreAuthenticatedHome(accountId: string, pageKey: string): void {
    const reason: string = this.authStatus !== 'authenticated' ? 'session-unconfirmed' :
      !accountId ? 'identity-pending' : !pageKey || this.activeTab !== 0 ||
      this.pinStore.detail || this.pinStore.detailOpeningPin || this.boardStore.pendingBoardUrl ? 'not-home' :
      this.homeStartupFeedCommitted ? 'network-committed' : '';
    if (reason) {
      if (reason !== this.homeCacheRestoreSkipReason) {
        this.homeCacheRestoreSkipReason = reason;
        PinWebRuntimeLog.info('HomeCache: restore skipped reason=' + reason);
      }
      return;
    }
    const attemptKey: string = accountId + ':' + pageKey;
    if (this.homeCacheRestoreAttemptKey === attemptKey) return;
    this.homeCacheRestoreAttemptKey = attemptKey;
    this.homeCacheRestoreSkipReason = '';
    PinWebRuntimeLog.info('HomeCache: restore attempted trigger=authenticated-identity');
    this.restoreHomeDiskCache(accountId, pageKey, 'authenticated-identity');
  }

  private restoreHomeDiskCache(accountId: string, pageKey: string, trigger: string): boolean {
    this.initializeHomeApiCache();
    if (!this.homeApiCache || !accountId || !pageKey) return false;
    try {
      const lookupStartedAt: number = Date.now();
      const result = this.homeApiCache.getWithMetadata<PinWebHomeCacheRecord>(
        this.homeCacheKey(accountId, pageKey), CACHE_TTL.homeFeed);
      const lookupElapsedMs: number = Date.now() - lookupStartedAt;
      PinWebRuntimeLog.info('HomeCache: lookup trigger=' + trigger + ' status=' + result.status +
        ' ageMs=' + result.ageMs.toString() + ' elapsedMs=' + lookupElapsedMs.toString());
      if (!result.value) {
        if (result.status === 'expired') PinWebRuntimeLog.info('OfflineCache: expired');
        return false;
      }
      const stored: PinWebHomeCacheRecord = result.value;
      const normalized: PinWebHomeCacheRecord | undefined = this.normalizeHomeCacheRecord(stored, pageKey);
      if (!normalized) {
        this.homeApiCache.remove(this.homeCacheKey(accountId, pageKey));
        PinWebRuntimeLog.warn('HomeCache: snapshot rejected reason=invalid-shape');
        return false;
      }
      this.homeStore.cachedHome = normalized.snapshot;
      this.homeStore.home = normalized.snapshot;
      this.homeStore.cachedHomeScrollOffset = 0;
      this.homeStore.retainingHomeFeed = true;
      this.homeStore.homeAppendRequested = false;
      this.homeStore.homeActionsReady = false;
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = '';
      this.homeDiskCacheRestored = true;
      this.homeDiskCacheRestoredAt = Date.now();
      this.rootTabAddresses.set(0, pageKey);
      PinWebRuntimeLog.info('HomeCache: snapshot restored source=' + result.status +
        ' pins=' + normalized.snapshot.pins.length.toString() + ' actionsReady=false');
      return true;
    } catch (_) {
      PinWebRuntimeLog.warn('HomeCache: disk snapshot read failed');
      return false;
    }
  }

  private tryEnterOfflinePreview(failedUrl: string, reason: string = 'network-failure'): boolean {
    const marker: PinWebOfflineHomeMarker | undefined = this.offlineHomeMarker;
    if (!marker || this.offlinePreviewMode || !this.isHomeRootAddress(failedUrl)) return false;
    if (this.offlineCacheLoading) return true;
    this.beginOfflineCacheRestore(failedUrl, reason);
    setTimeout(() => {
      if (!this.offlineCacheLoading || this.offlinePreviewMode || this.offlineHomeMarker !== marker) return;
      const restored: boolean = this.restoreHomeDiskCache(marker.partitionId, marker.pageKey, 'offline-start');
      this.offlineCacheLoading = false;
      if (!restored) {
        PinWebRuntimeLog.warn('OfflineCache: restore failed reason=cache-unavailable');
        if (this.homeDiskCacheRestoredAt === 0) this.clearOfflineHomeMarker();
        this.authStatus = 'error';
        this.loadFailed = true;
        this.failureDetails = '最近缓存不可用，请连接网络后重试';
        return;
      }
      this.offlinePreviewMode = true;
      this.authStatus = 'error';
      this.loadFailed = false;
      this.failureDetails = '';
      this.showNativeSheet = false;
      this.activeSheetKind = '';
      this.homeStore.customHomeMenuToken++;
      this.homeStore.customHomeMenu = undefined;
      this.pinStore.shareSession = 0;
      this.pinStore.moreSession = 0;
      this.pinStore.moreApiMode = false;
      this.activeTab = 0;
      this.currentWebTab = 0;
      this.pendingWebTab = -1;
      this.navigationAddress = marker.pageKey;
      this.lastPageUrl = marker.pageKey;
      this.rootTabAddresses.set(0, marker.pageKey);
      this.homeStore.homeError = '';
      this.homeStore.homeActionsReady = false;
      PinWebRuntimeLog.warn('OfflineCache: preview entered actionsReady=false');
    }, 0);
    return true;
  }

  private beginOfflineCacheRestore(failedUrl: string, reason: string): void {
    if (!this.offlineHomeMarker || this.offlinePreviewMode || !this.isHomeRootAddress(failedUrl)) return;
    this.offlineCacheLoading = true;
    PinWebRuntimeLog.info('OfflineCache: restore started reason=' + reason);
  }

  private normalizeHomeCacheRecord(record: PinWebHomeCacheRecord, pageKey: string): PinWebHomeCacheRecord | undefined {
    const saved: PinWebHomeSnapshot | undefined = record?.snapshot;
    if (!saved || saved.kind !== 'state' || saved.pageKey !== pageKey ||
        saved.dataSource !== 'api' ||
        typeof saved.selectedTab !== 'string' || !Array.isArray(saved.tabs) || !Array.isArray(saved.pins)) return undefined;
    const tabs: PinWebHomeTab[] = saved.tabs.filter((tab: PinWebHomeTab): boolean =>
      !!tab && typeof tab.id === 'string' && !!tab.id && typeof tab.label === 'string' && !!tab.label &&
      typeof tab.selected === 'boolean' && typeof tab.enabled === 'boolean');
    if (!tabs.length || !tabs.some((tab: PinWebHomeTab): boolean => tab.selected && tab.label === saved.selectedTab)) {
      return undefined;
    }
    const pins: PinWebHomePin[] = saved.pins.filter((pin: PinWebHomePin): boolean =>
      !!pin && typeof pin.id === 'string' && /^\d+$/.test(pin.id) && typeof pin.pinUrl === 'string' &&
      new RegExp('^https://(?:www\\.)?pinterest\\.com/pin/' + pin.id + '/?(?:[?#]|$)', 'i').test(pin.pinUrl) &&
      typeof pin.imageUrl === 'string' && /^https:\/\//i.test(pin.imageUrl) &&
      Number.isFinite(pin.imageWidth) && pin.imageWidth > 0 && Number.isFinite(pin.imageHeight) && pin.imageHeight > 0)
      .slice(0, 60).map((pin: PinWebHomePin): PinWebHomePin => ({
        id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
        imageWidth: pin.imageWidth, imageHeight: pin.imageHeight,
        title: typeof pin.title === 'string' ? pin.title.slice(0, 160) : '', hasMore: false
      }));
    const snapshot: PinWebHomeSnapshot = {
      kind: 'state', session: 0, pageKey: pageKey, selectedTab: saved.selectedTab,
      tabs: tabs, board: this.normalizeHomeBoard(saved.board), pins: pins, dataSource: saved.dataSource,
      loadingMore: false, refreshing: false, endReached: false
    };
    return { snapshot: snapshot };
  }

  private persistHomeDiskCache(snapshot: PinWebHomeSnapshot): void {
    if (!this.homeApiCache || !this.homeCacheAccountId || this.authStatus !== 'authenticated' ||
        snapshot.pageKey !== this.currentHomePageKey()) return;
    const key: string = this.homeCacheKey(this.homeCacheAccountId, snapshot.pageKey);
    const record: PinWebHomeCacheRecord | undefined = this.normalizeHomeCacheRecord({
      snapshot: snapshot
    }, snapshot.pageKey);
    if (!record) return;
    try {
      const writeStartedAt: number = Date.now();
      this.homeApiCache.put(key, record, CACHE_TTL.homeFeed);
      this.saveOfflineHomeMarker(this.homeCacheAccountId, snapshot.pageKey);
      PinWebRuntimeLog.info('HomeCache: snapshot persisted pins=' + record.snapshot.pins.length.toString() +
        ' elapsedMs=' + (Date.now() - writeStartedAt).toString() + ' ttlMs=' + CACHE_TTL.homeFeed.toString());
    } catch (_) {
      PinWebRuntimeLog.warn('HomeCache: disk snapshot write failed');
    }
  }

  private homePageKeyFromAddress(url: string): string {
    const match: RegExpMatchArray | null = url.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)(\/(?:ideas|today)(?:\/[^?#]*)?\/?|\/)(?=[?#]|$)/i);
    return match ? match[1] + match[2] : '';
  }

  private homePresentationPageKey(): string {
    if ((!this.offlinePreviewMode && this.authStatus !== 'authenticated') || this.activeTab !== 0 ||
        this.loadFailed && !this.offlinePreviewMode ||
        this.pinStore.detail || this.pinStore.detailOpeningPin || this.profileStore.origins.length > 0 ||
        this.profileSettingsVisible || this.profileStore.panel || this.inboxStore.inboxFlow ||
        this.boardStore.pendingBoardUrl) return '';
    if (this.offlinePreviewMode) return this.homeStore.home?.pageKey || this.offlineHomeMarker?.pageKey || '';
    const address: string = this.nativeDisplayAddress();
    if (this.pendingWebTab === 0) {
      const target: string = this.rootTabAddresses.get(0) || PINTEREST_URL;
      const origin: string = address.match(/^https:\/\/[^/]+/i)?.[0] || '';
      if (origin && target.startsWith(origin + '/') && this.isHomeRootAddress(target)) {
        return this.homePageKeyFromAddress(target);
      }
      return '';
    }
    const pageKey: string = this.homePageKeyFromAddress(address);
    if (pageKey) return pageKey;
    // Login evidence has been confirmed, but the initial home navigation may
    // not have reached Web.onPageBegin yet. Only present an empty native shell.
    if (this.currentWebTab === 0 && isPinterestAuthRoute(address)) return PINTEREST_URL;
    return '';
  }

  private retainedHomeRootPageKey(): string {
    const snapshot: PinWebHomeSnapshot | undefined = this.homeStore.home || this.homeStore.cachedHome;
    if (snapshot && this.isHomeRootAddress(snapshot.pageKey)) return snapshot.pageKey;
    const retainedAddress: string = this.rootTabAddresses.get(0) || '';
    return this.isHomeRootAddress(retainedAddress) ? this.homePageKeyFromAddress(retainedAddress) : '';
  }

  private prepareHomeForPageBegin(url: string, retainedDocument: boolean = false): void {
    const pageKey: string = this.homePageKeyFromAddress(url);
    if (!pageKey) {
      // A root-tab route change does not invalidate the native home snapshot.
      // Keep it available while the hidden Web document changes tabs;
      // detail/board/auth routes still use the existing clear path below.
      if (this.searchUrlFromAddress(url) || this.inboxUrlFromAddress(url) || this.profileUrlFromAddress(url)) {
        return;
      }
      this.clearHome();
      return;
    }
    this.homeStore.homeRefreshAwaitingPage = false;
    if (this.homeStore.homeRefreshing && !this.homeStore.cachedHome) {
      this.homeStore.homeActionsReady = false;
      return;
    }
    if (this.homeStore.cachedHome && this.homeStore.cachedHome.pageKey === pageKey &&
        (!this.homeStore.pendingHomeTab || this.homeStore.retainingHomeFeed || this.homeStore.homeRefreshing)) {
      if (!this.homeStore.homeRefreshing) this.homeStore.homeRequestToken++;
      this.homeStore.retainingHomeFeed = true;
      this.homeStore.homeAppendRequested = false;
      const selected: PinWebHomeTab | undefined = this.homeStore.cachedHome.tabs.find((tab: PinWebHomeTab): boolean => tab.selected);
      this.homeStore.pendingHomeTab = selected?.id || '';
      this.homeStore.homeTabNeedsRedispatch = !!this.homeStore.pendingHomeTab;
      this.homeStore.homeMoreRequestToken++;
      this.homeStore.homeMoreLoadingId = '';
      this.homeStore.homeMenuPin = '';
      this.homeStore.home = this.homeStore.cachedHome;
      this.homeStore.homeActionsReady = false;
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = '';
      if (!retainedDocument) this.expectHome();
      return;
    }
    if (!this.homeStore.pendingHomeTab) {
      this.clearHome();
      this.expectHome();
      return;
    }
    const token: number = ++this.homeStore.homeRequestToken;
    this.homeStore.homeMoreRequestToken++;
    this.homeStore.homeMoreLoadingId = '';
    this.homeStore.homeTabNeedsRedispatch = true;
    this.homeStore.homeMenuPin = '';
    this.homeStore.home = undefined;
    this.homeStore.homeLoading = true;
    this.homeStore.homeError = '';
    setTimeout(() => {
      if (token !== this.homeStore.homeRequestToken || !this.homeStore.pendingHomeTab || !this.homeStore.homeLoading) return;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = '分类内容加载超时，请重试';
    }, 30000);
  }

  private clearHome(): void {
    this.homeStore.homeRefreshToken++;
    this.homeDiskCacheRestored = false;
    this.homeStore.homeRefreshAwaitingPage = false;
    this.homeStore.retainingHomeFeed = false;
    this.homeStore.homeAppendRequested = false;
    this.homeStore.homeRefreshing = false;
    this.homeStore.homeRequestToken++;
    this.homeStore.homeMoreRequestToken++;
    this.homeStore.homeMoreLoadingId = '';
    this.homeStore.pendingHomeTab = '';
    this.homeStore.homeTabNeedsRedispatch = false;
    this.homeStore.homeMenuPin = '';
    this.homeStore.home = undefined;
    this.homeStore.homeActionsReady = false;
    this.homeStore.homeLoading = false;
    this.homeStore.homeError = '';
  }

  private homePlaceholder(): PinWebHomeSnapshot {
    return { kind: 'loading', session: 0, pageKey: this.homePresentationPageKey(),
      selectedTab: '', tabs: [], pins: [] };
  }

  private expectHome(): void {
    const token: number = ++this.homeStore.homeRequestToken;
    this.homeStore.homeLoading = !this.homeStore.home?.pins.length;
    this.homeStore.homeError = '';
    setTimeout(() => {
      if (token !== this.homeStore.homeRequestToken || this.homeStore.homeActionsReady || this.homeStore.homeError) return;
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = this.homeStore.home?.pins.length ?
        '首页内容同步超时，请重试' : '无法读取当前 Pinterest 首页';
    }, 20000);
  }

  private normalizeHomeBoard(value: PinWebHomeBoard | null | undefined): PinWebHomeBoard | undefined {
    if (!value || typeof value.id !== 'string' || !/^\d+$/.test(value.id) ||
        typeof value.name !== 'string' || !value.name.trim() ||
        typeof value.pinCount !== 'number' || !Number.isFinite(value.pinCount) ||
        value.pinCount < 0 || value.pinCount > 1000000000 ||
        typeof value.thumbnailUrl !== 'string') return undefined;
    if (value.thumbnailUrl && !/^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(value.thumbnailUrl)) return undefined;
    return { id: value.id, name: value.name.trim().slice(0, 160),
      pinCount: Math.floor(value.pinCount), thumbnailUrl: value.thumbnailUrl };
  }

  private updateHome(value: string): void {
    if (this.nativeRootOnly && !this.rootContentInteracted) return;
    if (this.retainedHomeAwaitingAuth) return;
    if (this.nativeBackTarget) {
      try {
        if (this.pageHistory.key(this.controller.getUrl()) !== this.pageHistory.key(this.nativeBackTarget)) return;
      } catch (_) { return; }
    }
    try {
      const message: PinWebHomeSnapshot = JSON.parse(value) as PinWebHomeSnapshot;
      if (!message || typeof message.session !== 'number' || typeof message.pageKey !== 'string') return;
      if (message.kind === 'closed') {
        if (!this.currentHomePageKey()) this.clearHome();
        return;
      }
      if (message.kind !== 'state' && message.kind !== 'loading' && message.kind !== 'failed' ||
          !Array.isArray(message.tabs) || !Array.isArray(message.pins) ||
          !message.pageKey || message.pageKey !== this.currentHomePageKey()) return;
      if (this.homeStore.homeRefreshing && this.homeStore.homeRefreshAwaitingPage) return;
      if (this.homeStore.homeActionsReady && this.homeStore.home && this.homeStore.home.pageKey === message.pageKey &&
          message.session < this.homeStore.home.session) return;
      const tabs: PinWebHomeTab[] = message.tabs.filter((tab: PinWebHomeTab): boolean =>
        !!tab.id && !!tab.label);
      if (!tabs.length || !tabs.some((tab: PinWebHomeTab): boolean => tab.selected)) return;
      const board: PinWebHomeBoard | undefined = this.normalizeHomeBoard(message.board);
      if (message.kind === 'failed') {
        this.homeStore.homeRefreshing = false;
        if (this.homeStore.home?.pins.length) {
          this.homeStore.homeActionsReady = false;
          this.homeStore.homeLoading = false;
          this.homeStore.pendingHomeTab = '';
          this.homeStore.homeError = message.error || '首页内容加载失败，请下拉重试';
          if (this.homeDiskCacheRestoredAt > 0) {
            PinWebRuntimeLog.warn('HomeCache: refresh failed snapshotRetained=true actionsReady=false');
          }
          return;
        }
        this.homeStore.home = { kind: 'state', session: message.session, pageKey: message.pageKey,
          selectedTab: message.selectedTab || '', tabs: tabs, board: board, pins: [] };
        this.homeStore.homeRequestToken++;
        this.homeStore.pendingHomeTab = '';
        this.homeStore.homeTabNeedsRedispatch = false;
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = message.error || '分类内容加载失败，请重试';
        return;
      }
      if (message.kind === 'loading') {
        const loadingPins: PinWebHomePin[] = message.pins.filter((pin: PinWebHomePin): boolean =>
          !!pin.id && !!this.pinIdentity(pin.pinUrl) && /^https:\/\//i.test(pin.imageUrl));
        if (this.homeStore.home?.pins.length) {
          this.homeStore.homeActionsReady = false;
          this.homeStore.homeLoading = !!this.homeStore.pendingHomeTab && !this.homeStore.retainingHomeFeed;
          this.homeStore.homeError = '';
          return;
        }
        this.homeStore.home = { kind: 'loading', session: message.session, pageKey: message.pageKey,
          selectedTab: message.selectedTab || '', tabs: tabs, board: board, pins: loadingPins,
          dataSource: message.dataSource };
        this.homeStore.homeLoading = true;
        this.homeStore.homeError = '';
        return;
      }
      let pins: PinWebHomePin[] = message.pins.filter((pin: PinWebHomePin): boolean =>
        !!pin.id && !!this.pinIdentity(pin.pinUrl) && /^https:\/\//i.test(pin.imageUrl))
        .map((pin: PinWebHomePin): PinWebHomePin => {
          return { id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
            imageWidth: pin.imageWidth, imageHeight: pin.imageHeight, video: pin.video,
            title: this.searchStore.knownSearchPinTitles.get(this.pinIdentity(pin.pinUrl)) || pin.title || '', hasMore: pin.hasMore,
            saved: this.pinStore.confirmedSaves.isSaved(this.pinIdentity(pin.pinUrl)) };
        });
      if (message.kind === 'state' && message.dataSource === 'api') this.homeStartupFeedCommitted = true;
      const restoredFromDisk: boolean = this.homeDiskCacheRestored;
      if (!restoredFromDisk && !this.homeStore.homeActionsReady && this.homeStore.home?.pins.length && !pins.length) return;
      if (restoredFromDisk) {
        this.homeDiskCacheRestored = false;
        this.homeStore.retainingHomeFeed = false;
        PinWebRuntimeLog.info('HomeCache: current session snapshot committed pins=' + pins.length.toString() +
          ' sinceRestoreMs=' + (Date.now() - this.homeDiskCacheRestoredAt).toString());
      }
      const confirmed: boolean = !this.homeStore.pendingHomeTab || tabs.some((tab: PinWebHomeTab): boolean =>
        tab.id === this.homeStore.pendingHomeTab && tab.selected);
      if (this.homeStore.homeRefreshing && confirmed && !message.refreshing) this.homeStore.retainingHomeFeed = false;
      const retained: PinWebHomeSnapshot | undefined = this.homeStore.retainingHomeFeed && !restoredFromDisk ?
        this.homeStore.cachedHome : undefined;
      const sameCategory: boolean = retained?.selectedTab === message.selectedTab;
      if (retained && (retained.dataSource === message.dataSource || this.homeStore.retainingHomeFeed)) {
        pins = retainHomePins(retained.pins, pins, sameCategory && this.homeStore.homeAppendRequested);
      }
      if (message.kind === 'state' && pins.length > 0 && this.homeTraceCardsPageKey !== message.pageKey) {
        this.homeTraceCardsPageKey = message.pageKey;
        const documentElapsed: number = this.homeTracePageKey === message.pageKey && this.lastDocumentBeginAt > 0 ?
          Date.now() - this.lastDocumentBeginAt : -1;
        const appElapsed: number = typeof PinWebRuntimeLog.sessionElapsedMs === 'function' ?
          PinWebRuntimeLog.sessionElapsedMs() : 0;
        if (typeof PinWebRuntimeLog.info === 'function') {
          PinWebRuntimeLog.info('StartupTrace: home cards state committed count=' + pins.length.toString() +
            ' retained=' + (!!retained).toString() +
            ' appElapsedMs=' + appElapsed.toString() +
            (documentElapsed >= 0 ? ' documentElapsedMs=' + documentElapsed.toString() : ''));
        }
      }
      if (!retained && (!this.homeStore.cachedHome || this.homeStore.cachedHome.pageKey !== message.pageKey ||
          this.homeStore.cachedHome.selectedTab !== message.selectedTab)) this.homeStore.cachedHomeScrollOffset = 0;
      this.homeStore.home = { kind: 'state', session: message.session, pageKey: message.pageKey,
        selectedTab: retained?.selectedTab || message.selectedTab || '',
        tabs: retained && !sameCategory ? retained.tabs : tabs,
        board: board || (retained && sameCategory ? retained.board : undefined),
        pins: pins,
        dataSource: message.dataSource, loadingMore: message.loadingMore, refreshing: message.refreshing,
        endReached: message.endReached, sourceError: message.sourceError,
        categorySourceFailure: message.categorySourceFailure === true };
      if (message.sourceError && message.sourceError !== this.homeStore.homeSourceWarning) {
        this.showMessage(message.sourceError);
      }
      this.homeStore.homeSourceWarning = message.sourceError || '';
      this.homeStore.cachedHome = this.homeStore.home;
      this.rootTabAddresses.set(0, message.pageKey);
      this.homeStore.homeActionsReady = !message.refreshing;
      if (this.homeStore.homeActionsReady && this.rootReadToken === this.tabRequestToken &&
          this.rootReadAddress === message.pageKey && this.rootReadStartedAt > 0) {
        PinWebRuntimeLog.info('HomeRecoveryTrace: phase=content-ready count=' + pins.length.toString() +
          ' elapsedMs=' + (Date.now() - this.rootReadStartedAt).toString());
      }
      if (this.homeDiskCacheRestoredAt > 0) {
        PinWebRuntimeLog.info('HomeCache: current session state actionsReady=' +
          this.homeStore.homeActionsReady.toString() + ' sinceRestoreMs=' +
          (Date.now() - this.homeDiskCacheRestoredAt).toString());
        if (this.homeStore.homeActionsReady) this.homeDiskCacheRestoredAt = 0;
      }
      if (this.homeStore.homeActionsReady && !message.sourceError) this.detailReturnJourney?.mark('return.home.feed.confirmed');
      if (this.homeStore.homeTabNeedsRedispatch && this.homeStore.pendingHomeTab) {
        const requestedId: string = this.homeStore.pendingHomeTab;
        const requestedTab: PinWebHomeTab | undefined = tabs.find((tab: PinWebHomeTab): boolean =>
          tab.id === requestedId);
        if (requestedTab && requestedTab.selected) {
          this.homeStore.homeTabNeedsRedispatch = false;
        } else if (requestedTab) {
          this.homeStore.homeTabNeedsRedispatch = false;
          setTimeout(() => {
            if (this.homeStore.pendingHomeTab === requestedId) {
              this.selectHomeTab(requestedId, true).catch(() => {
                PinWebRuntimeLog.warn('PinWeb: could not restore selected home category');
              });
            }
          }, 0);
          return;
        }
      }
      if (!this.homeStore.pendingHomeTab || tabs.some((tab: PinWebHomeTab): boolean =>
          tab.id === this.homeStore.pendingHomeTab && tab.selected)) {
        this.homeStore.homeRequestToken++;
        this.homeStore.pendingHomeTab = '';
        this.homeStore.homeLoading = false;
        this.homeStore.homeRefreshing = !!message.refreshing;
        this.homeStore.homeError = message.categorySourceFailure === true ? '已收藏图板分类读取失败，请重试' : '';
        const committedHome: PinWebHomeSnapshot | undefined = this.homeStore.home;
        if (message.kind === 'state' && confirmed && !message.refreshing && !message.loadingMore && !message.sourceError &&
            this.homeStore.homeActionsReady && committedHome) this.persistHomeDiskCache(committedHome);
        if (message.dataSource === 'api' && !message.refreshing && !message.sourceError) {
          if (this.retainedHomeAwaitingFeed) PinWebRuntimeLog.info('PinWebReturn: retained home feed confirmed');
          this.retainedHomeAwaitingFeed = false;
          if (this.interruptedHomePage) PinWebRuntimeLog.info('HomeRecovery: current home API state confirmed');
          this.interruptedHomePage = '';
          this.homeRecoveryAttempted = false;
          this.homeRecoveryToken++;
        }
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid home state');
    }
  }

  private async selectHomeTab(id: string, restoring: boolean = false): Promise<void> {
    this.traceAction(restoring ? 'home.tab.restore' : 'home.tab', id);
    if (this.rejectOfflineAction('home tab')) return;
    if (!restoring && !await this.ensureRootActionContext(0)) return;
    const home: PinWebHomeSnapshot | undefined = this.homeStore.home;
    if (!home || !this.homeStore.homeActionsReady || !id || home.pageKey !== this.currentHomePageKey()) return;
    const target: PinWebHomeTab | undefined = home.tabs.find((tab: PinWebHomeTab): boolean => tab.id === id);
    if (!target || !target.enabled || target.selected && !this.homeStore.pendingHomeTab) return;
    if (!restoring) {
      this.homeStore.retainingHomeFeed = false;
      this.homeStore.homeAppendRequested = false;
      this.homeStore.homeRefreshing = false;
    }
    const token: number = ++this.homeStore.homeRequestToken;
    this.homeStore.pendingHomeTab = id;
    this.homeStore.homeMoreRequestToken++;
    this.homeStore.homeMoreLoadingId = '';
    this.homeStore.homeMenuPin = '';
    this.homeStore.homeTabNeedsRedispatch = false;
    this.homeStore.homeLoading = !restoring;
    let dispatched: boolean = false;
    try {
      const latest: PinWebHomeSnapshot | undefined = this.homeStore.home;
      if (latest && latest.pageKey === this.currentHomePageKey()) {
        const result: string = await this.controller.runJavaScript('window.PinWebHomeTab && ' +
          'window.PinWebHomeTab(' + latest.session.toString() + ',' + JSON.stringify(latest.pageKey) + ',' +
          JSON.stringify(id) + ')');
        dispatched = result === 'true' || result === '"true"';
      }
    } catch (_) {
      PinWebRuntimeLog.warn('PinWeb: home API category request unavailable');
    }
    if (!dispatched) {
      if (token !== this.homeStore.homeRequestToken || this.homeStore.pendingHomeTab !== id) return;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.homeLoading = false;
      this.showMessage('分类暂不可用，请重试');
      return;
    }
    setTimeout(() => {
      if (token !== this.homeStore.homeRequestToken || this.homeStore.pendingHomeTab !== id) return;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.homeLoading = false;
      this.homeStore.homeRefreshing = false;
      if (restoring) this.showMessage('分类同步超时，请下拉重试');
      else this.homeStore.homeError = '分类内容加载超时，请重试';
    }, 30000);
  }

  private async openHomePin(id: string): Promise<void> {
    this.traceAction('home.pin.open', id);
    if (this.rejectOfflineAction('home pin')) return;
    const home: PinWebHomeSnapshot | undefined = this.homeStore.homeForPresentation(
      this.homePresentationPageKey() || this.retainedHomeRootPageKey());
    if (!home || this.authStatus !== 'authenticated' || this.activeTab !== 0) return;
    this.pinStore.detailReturnUrl = home.pageKey;
    const openingPin: PinWebHomePin | undefined = home.pins.find((pin: PinWebHomePin): boolean => pin.id === id);
    if (openingPin && this.pinIdentity(openingPin.pinUrl)) {
      // Keep the visible feed available if the WebView navigation for the Pin
      // fails before the native detail bridge responds.
      this.homeStore.cachedHome = home;
      this.beginDetailOpening(openingPin.pinUrl, home.pageKey);
    }
    try {
      if (openingPin && this.pinIdentity(openingPin.pinUrl)) this.controller.loadUrl(openingPin.pinUrl);
      else { this.pinStore.detailOpeningPin = ''; this.showMessage('无法打开 Pin 图，请重试'); }
    } catch (error) {
      this.pinStore.detailOpeningPin = '';
      this.showMessage('无法打开 Pin 图，请重试');
    }
  }

  private homeMenuReady(): boolean {
    const home: PinWebHomeSnapshot | undefined = this.homeStore.home;
    return this.authStatus === 'authenticated' && this.activeTab === 0 && !!home && !!home.pins.length &&
      this.rootTabIndexFromAddress(home.pageKey) === 0 && !this.homeStore.homeLoading && !this.homeStore.homeRefreshing &&
      (!this.homeStore.pendingHomeTab || this.homeStore.retainingHomeFeed) &&
      (PIN_POST_API_ENABLED || this.homeStore.homeActionsReady);
  }

  private async openHomeMore(id: string): Promise<void> {
    this.traceAction('home.pin.more', id);
    if (this.rejectOfflineAction('home menu')) return;
    if (!PIN_POST_API_ENABLED || !await this.ensureRootActionContext(0)) return;
    const home: PinWebHomeSnapshot | undefined = this.homeStore.home;
    if (!home || !this.homeMenuReady() || this.homeStore.homeMoreLoadingId) return;
    const pin: PinWebHomePin | undefined = home.pins.find((item: PinWebHomePin): boolean => item.id === id);
    if (!pin) {
      this.showMessage('Pin 已不可用，请刷新首页后重试');
      return;
    }
    if (!PIN_POST_API_ENABLED) return;
    this.openCustomHomeMenu(pin.pinUrl, home.pageKey);
  }

  private cancelHomeDetailMore(): void {
    this.homeStore.homeDetailMoreToken++;
    this.homeStore.pendingHomeMorePin = '';
  }

  private isCurrentInboxMessagePin(url: string): boolean {
    return this.inboxStore.inboxFlow?.screen === 'chat' && this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl() &&
      this.inboxStore.inboxFlow.messages.some((message): boolean => message.pinUrl === url);
  }

  private async openCustomHomeMenu(pinUrl: string, pageKey: string, inboxAction: string = '', profilePin: boolean = false): Promise<void> {
    if (this.rejectOfflineAction('share panel')) return;
    const token: number = ++this.homeStore.customHomeMenuToken;
    this.homeStore.homeMenuPin = pinUrl;
    this.homeStore.homeMenuPage = pageKey;
    this.pinStore.sharePin = pinUrl;
    this.pinStore.shareSession = token;
    this.pinStore.moreSession = token;
    this.pinStore.shareTitle = '分享';
    this.pinStore.shareSearchActive = false;
    this.activeSheetKind = 'share';
    this.homeStore.customHomeMenu = { session: token, pinUrl: pinUrl, loading: true, busy: false,
      error: '', feedback: '', options: [], actions: [] };
    this.showNativeSheet = true;
    try {
      const opened: string = await this.controller.runJavaScript('window.PinWebPostApi && ' +
        'window.PinWebPostApi.homeMenuOpen(' + token + ',' + JSON.stringify(pinUrl) + ',' + JSON.stringify(pageKey) + ')');
      if (token !== this.homeStore.customHomeMenuToken) return;
      if (opened !== 'true' && opened !== '"true"') throw new Error('menu unavailable');
      while (token === this.homeStore.customHomeMenuToken && this.homeStore.customHomeMenu &&
        (this.isCurrentBoardMenuPin(pinUrl, pageKey) || pageKey === this.currentHomePageKey() || !!inboxAction && this.inboxStore.inboxFlow?.screen === 'chat' &&
        pageKey.replace(/\/$/, '') === this.currentInboxUrl().replace(/\/$/, ''))) {
        let serialized: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && ' +
          'window.PinWebPostApi.homeMenuRead(' + token + ',' + JSON.stringify(pinUrl) + '))');
        if (token !== this.homeStore.customHomeMenuToken) return;
        if (serialized.startsWith('"')) serialized = JSON.parse(serialized) as string;
        const state: PinWebHomeMenuState = JSON.parse(serialized) as PinWebHomeMenuState;
        if (!state || state.session !== token || this.pinIdentity(state.pinUrl) !== this.pinIdentity(pinUrl)) break;
        if (inboxAction) state.actions = state.actions.filter((option: PinWebHomeMenuOption): boolean => option.id === 'home-save');
        if (profilePin) state.actions = state.actions.filter((option: PinWebHomeMenuOption): boolean => option.id !== 'home-see-more' && option.id !== 'home-see-less');
        this.homeStore.customHomeMenu = state;
        if (inboxAction === 'share' && !state.loading && !state.error) {
          this.homeStore.customHomeMenu = undefined;
          this.pinStore.shareLoading = true;
          const snapshot: string = JSON.stringify({ kind: 'state', session: token, pinUrl: pinUrl,
            title: '分享', options: state.options, actions: [], contacts: [], query: '' });
          await this.controller.runJavaScript('(function(){ var snapshot=' + snapshot +
            '; function publish(){ if (!window.PinWebPostApi || !window.PinWebShareBridge) return; ' +
            'window.PinWebShareBridge.sheetState(JSON.stringify(window.PinWebPostApi.shareSnapshot(snapshot,publish))); } publish(); ' +
            'window.PinWebPostApi.shareSearch(snapshot.session, ""); })()');
          return;
        }
        if (inboxAction === 'save' && !state.loading && !state.error) {
          await this.openApiBoards(pinUrl);
          return;
        }
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 350); });
      }
      if (token === this.homeStore.customHomeMenuToken) this.dismissShareSheet();
    } catch (error) {
      if (token !== this.homeStore.customHomeMenuToken || !this.homeStore.customHomeMenu) return;
      this.homeStore.customHomeMenu = { session: token, pinUrl: pinUrl, loading: false, busy: false,
        error: '无法读取帖子操作，请重试', feedback: '', options: [], actions: [] };
    }
  }

  private async performCustomHomeAction(id: string): Promise<void> {
    if (this.rejectOfflineAction('home menu action')) return;
    const menu: PinWebHomeMenuState | undefined = this.homeStore.customHomeMenu;
    if (!menu || menu.loading || menu.busy || !this.isCurrentMorePin(menu.pinUrl)) return;
    if (id === 'home-save') {
      if (!menu.actions.some((option: PinWebHomeMenuOption): boolean => option.id === id && option.enabled)) return;
      this.homeStore.customHomeMenuToken++;
      await this.openApiBoards(menu.pinUrl);
      return;
    }
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebPostApi && ' +
        'window.PinWebPostApi.homeMenuAction(' + menu.session + ',' + JSON.stringify(menu.pinUrl) + ',' + JSON.stringify(id) + ')');
      if (menu.session !== this.homeStore.customHomeMenu?.session) return;
      if (result !== 'true' && result !== '"true"') this.showMessage('该操作暂不可用，请重试');
    } catch (error) { this.showMessage('操作失败，请重试'); }
  }

  private async openProfilePinMenu(id: string): Promise<void> {
    if (!await this.prepareProfileInteraction()) return;
    if (this.rejectOfflineAction('profile menu')) return;
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile) return;
    const pin: PinWebCreatedPin | undefined = profile.createdPins.concat(profile.unorganizedPins || []).find((item: PinWebCreatedPin): boolean => item.id === id);
    if (!pin || !pin.targetUrl) return;
    this.openCustomHomeMenu(pin.targetUrl, profile.profileUrl, '', true);
  }

  private async openHomeMoreViaDetail(pinUrl: string, returnUrl: string): Promise<void> {
    this.clearRootTabGuard('home-more-detail');
    if (this.rejectOfflineAction && this.rejectOfflineAction('home menu detail')) return;
    const identity: string = this.pinIdentity(pinUrl);
    if (!identity) return;
    const token: number = ++this.homeStore.homeDetailMoreToken;
    this.homeStore.pendingHomeMorePin = pinUrl;
    this.pinStore.detailReturnUrl = returnUrl;
    let dispatched: boolean = false;
    try {
      this.controller.loadUrl(pinUrl);
      const deadline: number = Date.now() + 15000;
      while (token === this.homeStore.homeDetailMoreToken && Date.now() < deadline) {
        const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
        if (!dispatched && this.pinStore.detailActionsReady && detail &&
            this.pinIdentity(detail.pinUrl) === identity && this.pinIdentity(this.currentPinUrl()) === identity) {
          const more: PinWebDetailAction | undefined = detail.actions.find((action: PinWebDetailAction): boolean =>
            action.kind === 'more' && action.enabled);
          if (more) {
            if (detail.dataSource === 'api') await this.openApiDetailMore();
            else {
              const result: string = await this.controller.runJavaScript('window.PinWebDetailMore && ' +
                'window.PinWebDetailMore(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' +
                JSON.stringify(more.id) + ')');
              if (token !== this.homeStore.homeDetailMoreToken) return;
              dispatched = result === 'true' || result === '"true"';
            }
            if (token !== this.homeStore.homeDetailMoreToken) return;
            if (detail.dataSource === 'api') dispatched = this.activeSheetKind === 'more' && this.pinStore.moreApiMode;
          }
        }
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250); });
      }
      if (token !== this.homeStore.homeDetailMoreToken) return;
      this.cancelHomeDetailMore();
      if (dispatched) return;
      this.showMessage('这张 Pin 的网页选项未能加载，请在详情页重试');
    } catch (error) {
      if (token !== this.homeStore.homeDetailMoreToken) return;
      this.cancelHomeDetailMore();
      this.showMessage('无法加载这张 Pin 的详情选项，请重试');
    }
  }

  private async loadMoreHome(): Promise<void> {
    if (this.rejectOfflineAction('home load-more')) return;
    const home: PinWebHomeSnapshot | undefined = this.homeStore.home;
    if (!home || this.homeStore.homeLoading || home.pageKey !== (this.currentHomePageKey() || this.homePresentationPageKey())) return;
    if (this.homeStore.pendingHomeTab || this.homeStore.homeRefreshing) return;
    const requestPage: string = home.pageKey;
    if (!this.homeStore.homeActionsReady) {
      const ready: boolean = await this.ensureRootActionContext(0, true, '', (): boolean =>
        this.activeTab === 0 && this.homeStore.home?.pageKey === requestPage &&
        !this.homeStore.homeRefreshing && !this.homeStore.pendingHomeTab);
      if (!ready || !this.homeStore.home || !this.homeStore.homeActionsReady ||
          this.homeStore.home.pageKey !== requestPage) return;
    }
    this.homeStore.homeAppendRequested = true;
    const currentHome: PinWebHomeSnapshot | undefined = this.homeStore.home;
    if (!currentHome || this.activeTab !== 0 || currentHome.pageKey !== requestPage ||
        this.homeStore.homeRefreshing || this.homeStore.pendingHomeTab) return;
    this.controller.runJavaScript('window.PinWebHomeLoadMore && ' +
      'window.PinWebHomeLoadMore(' + currentHome.session.toString() + ',' + JSON.stringify(currentHome.pageKey) + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: home API pagination unavailable'));
  }

  private refreshHome(): void {
    if (this.offlinePreviewMode) {
      if (this.authStatus === 'checking' && this.webPageLoading) return;
      PinWebRuntimeLog.info('OfflineCache: recovery requested source=home-refresh');
      this.retryLogin();
      return;
    }
    if (this.nativeRootOnly && this.prepareRootPageRead(0)) return;
    const currentPageKey: string = this.currentHomePageKey();
    // A failed Web main-frame load can leave getUrl() temporarily empty while
    // the retained native snapshot still identifies the valid home route.
    // Use that route to make pull-to-refresh recover the session instead of
    // repeatedly stopping at page-or-state-unavailable.
    const retainedHome: PinWebHomeSnapshot | undefined = this.homeStore.cachedHome;
    const pageKey: string = currentPageKey || this.homePresentationPageKey() ||
      (retainedHome ? retainedHome.pageKey : '');
    if (pageKey && !this.homeStore.homeActionsReady && !this.homeStore.homeRefreshing &&
        !this.homeStore.pendingHomeTab && this.authStatus === 'authenticated') {
      PinWebRuntimeLog.info('HomeRecoveryTrace: phase=request source=refresh');
      this.requestRootPage(0);
      return;
    }
    if (!pageKey || this.homeStore.homeRefreshing || this.homeStore.pendingHomeTab && !this.homeStore.retainingHomeFeed) {
      PinWebRuntimeLog.info('ActionGate: home refresh blocked reason=page-or-state-unavailable');
      return;
    }
    if (this.homeStore.home?.categorySourceFailure ||
        this.homeStore.home?.kind === 'failed' && !this.homeStore.home.tabs.length) {
      this.homeStore.homeLoading = !this.homeStore.home?.pins.length;
      this.homeStore.homeError = '';
      this.controller.runJavaScript('window.PinWebHomeRetryCategories && window.PinWebHomeRetryCategories(' +
        JSON.stringify(pageKey) + ')').then((result: string) => {
        if (result === 'true' || result === '"true"') return;
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = '已收藏图板分类重试暂不可用，请重试';
      }).catch(() => {
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = '已收藏图板分类重试失败，请重试';
      });
      return;
    }
    const canRefreshApi: boolean = PIN_HOME_API_ENABLED && this.homeStore.home?.dataSource === 'api' &&
      this.homeStore.homeActionsReady;
    PinWebRuntimeLog.info('HomeRefresh: requested source=' + (canRefreshApi ? 'api' : 'web') +
      ' actionsReady=' + this.homeStore.homeActionsReady.toString());
    const token: number = ++this.homeStore.homeRefreshToken;
    this.homeStore.homeRequestToken++;
    this.homeStore.homeRefreshing = true;
    this.homeStore.homeRefreshAwaitingPage = true;
    this.homeStore.homeActionsReady = false;
    this.homeStore.homeLoading = !this.homeStore.home?.pins.length;
    this.homeStore.homeError = '';
    try {
      const home: PinWebHomeSnapshot | undefined = this.homeStore.home;
      if (canRefreshApi && home) {
        this.homeStore.homeRefreshAwaitingPage = false;
        this.controller.runJavaScript('window.PinWebHomeApiRefresh && window.PinWebHomeApiRefresh(' +
          home.session.toString() + ',' + JSON.stringify(home.pageKey) + ')').then((result: string) => {
          if (token !== this.homeStore.homeRefreshToken || result === 'true' || result === '"true"') return;
          // The retained native snapshot may be visible while the hidden Web
          // document is still on a child route or an older session. Rebind it
          // to the current home route before treating refresh as unavailable.
          this.homeStore.homeRefreshAwaitingPage = true;
          PinWebRuntimeLog.info('HomeRefresh: bridge-unavailable fallback=web-sync');
          try {
            this.controller.loadUrl(pageKey);
          } catch (_) {
            if (token !== this.homeStore.homeRefreshToken) return;
            this.homeStore.homeRefreshing = false;
            this.homeStore.homeRefreshAwaitingPage = false;
            this.homeStore.homeActionsReady = true;
            PinWebRuntimeLog.warn('HomeRefresh: failed reason=bridge-fallback-load');
            this.showMessage('首页刷新失败，请重试');
          }
        }).catch(() => {
          if (token !== this.homeStore.homeRefreshToken) return;
          this.homeStore.homeRefreshing = false;
          this.homeStore.homeActionsReady = true;
          PinWebRuntimeLog.warn('HomeRefresh: failed reason=bridge-error');
          this.showMessage('首页刷新失败，请重试');
        });
      } else if (currentPageKey === pageKey) {
        this.controller.refresh();
      } else {
        // A retained homepage may be visible while the failed Web document is still a Pin.
        this.controller.loadUrl(pageKey);
      }
    } catch (error) {
      this.homeStore.homeRefreshing = false;
      this.homeStore.homeRefreshAwaitingPage = false;
      this.homeStore.homeLoading = false;
      PinWebRuntimeLog.warn('HomeRefresh: failed reason=exception');
      this.showMessage('首页刷新失败，请重试');
    }
    setTimeout(() => {
      if (token !== this.homeStore.homeRefreshToken || !this.homeStore.homeRefreshing) return;
      this.homeStore.homeRefreshing = false;
      this.homeStore.homeRefreshAwaitingPage = false;
      this.homeStore.pendingHomeTab = '';
      if (this.homeStore.home?.pins.length) {
        PinWebRuntimeLog.warn('HomeRefresh: failed reason=timeout snapshotRetained=true');
        this.showMessage('首页刷新超时，请下拉重试');
      } else {
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = '无法读取当前 Pinterest 首页';
        PinWebRuntimeLog.warn('HomeRefresh: failed reason=timeout snapshotRetained=false');
      }
    }, 20000);
  }

  @Builder
  private buildNativeTab(label: string, symbol: Resource, index: number) {
    Column({ space: 2 }) {
      SymbolGlyph(symbol)
        .fontSize(24)
        .fontColor([this.activeTab === index ? $r('app.color.tab_text_primary') :
          $r('app.color.tab_text_secondary')])
      Text(label)
        .fontSize(11)
        .lineHeight(14)
        .height(14)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.activeTab === index ? $r('app.color.tab_text_primary') :
          $r('app.color.tab_text_secondary'))
    }
    .width('100%')
    .height(56)
    .padding({ top: 4, bottom: 4 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(label)
    .accessibilitySelected(this.activeTab === index)
  }

  private recordPageNavigation(url: string, mode: string = 'load'): void {
    if (this.ignoreSupersededDetailDocument(url)) return;
    if (this.pinStore.detailPresentationOnly && !isPinterestAuthRoute(url)) return;
    if (this.nativeRootOnly && !isPinterestAuthRoute(url)) return;
    if (this.detailReturnedToRoot && this.extractPinUrl(url)) return;
    if (this.logoutAwaitingLogin && !isPinterestAuthRoute(url)) return;
    if (isPinterestAuthRoute(url)) {
      this.navigationAddress = url;
      this.lastPageUrl = url;
      if (this.authStatus === 'authenticated') this.resetAuthenticatedContent();
      this.authStatus = 'checking';
      return;
    }
    if (/\/(?:login|logout|signup)(?:\/|[?#]|$)/i.test(url)) this.clearRootTabCaches();
    if (this.pinStore.detailOpeningPin && this.pinIdentity(this.extractPinUrl(url)) !==
        this.pinIdentity(this.pinStore.detailOpeningPin)) return;
    if (this.nativeBackTarget && this.pageHistory.key(url) !== this.pageHistory.key(this.nativeBackTarget)) return;
    if (this.nativeBackTarget) {
      this.nativeBackTarget = '';
      mode = 'load';
      PinWebRuntimeLog.info('PinWebReturn: destination route confirmed');
      this.detailReturnJourney?.mark('return.route.confirmed');
    }
    this.syncNativeReturnRoute(url);
    this.syncBoardRoute(url);
    if (this.searchStore.search && this.searchStore.search.pageKey !== this.searchUrlFromAddress(url)) {
      this.searchStore.searchCache.put(this.searchStore.search, this.searchStore.searchScrollOffset);
    }
    this.pageHistory.visit(url, mode);
    const searchPage: string = this.searchUrlFromAddress(url);
    if (searchPage && (!this.searchStore.search || this.searchStore.search.pageKey !== searchPage)) this.restoreRetainedSearch(searchPage);
    // SPA transitions also need to retain and restore the native home snapshot.
    if (this.homePageKeyFromAddress(url) && !this.homeStore.home) this.prepareHomeForPageBegin(url);
    if (this.inboxUrlFromAddress(url) && !this.inboxStore.inbox) this.restoreInbox(url);
    if (this.profileUrlFromAddress(url) && !this.profileStore.profile) this.restoreProfile(url);
  }

  private nativeDisplayAddress(): string {
    if (this.nativeBackTarget) return this.nativeBackTarget;
    if (this.nativeRootOnly) return this.rootPresentationAddress(this.activeTab);
    const nativeAddress: string = this.nativeRootPageAddress(this.activeTab);
    if (nativeAddress) return nativeAddress;
    try { return this.controller.getUrl(); } catch (_) { return this.navigationAddress; }
  }

  private presentNativeBackTarget(target: string): void {
    if (!this.pinStore.detail && !this.pinStore.detailOpeningPin) return;
    const pin: string = this.extractPinUrl(target);
    // A nested Pin can only be presented immediately when its cache exists.
    if (pin && !this.pinStore.detailCache.get(this.pinIdentity(pin))) return;
    this.clearRootTabGuard('back');
    const root: number = this.rootTabIndexFromAddress(target);
    if (root >= 0) {
      this.detailReturnedToRoot = true;
      this.rootTabGuardTarget = root;
      this.rootTabGuardAddress = target;
      this.rootReadAddress = target; this.rootReadToken = ++this.tabRequestToken;
      this.rootReadStartedAt = Date.now(); this.pendingWebTab = root;
      this.waitForWebTabConfirmation(root, this.tabRequestToken, this.rootReadStartedAt);
      PinWebRuntimeLog.info('RootTabTrace: return-preparation targetTab=' + root.toString());
    }
    this.detailReturnReadPin = this.pinIdentity(pin);
    this.nativeBackTarget = target;
    this.navigationAddress = target;
    this.clearDetail();
    this.nativePinRoute = this.pinIdentity(pin);
    this.homeStore.homeActionsReady = false;
    this.profileStore.profileActionsReady = false;
    this.inboxStore.inboxActionsReady = false;
    this.searchStore.searchActionsReady = false;
    this.searchStore.searchInputReady = false;
    if (pin) {
      this.pinStore.detailReturnUrl = this.pinStore.detailOrigin(this.pinIdentity(pin));
      this.restoreCachedDetail(pin);
      return;
    }
    const profile: string = this.profileUrlFromAddress(target);
    const inbox: string = this.inboxUrlFromAddress(target);
    const search: string = this.searchUrlFromAddress(target);
    if (profile) { if (this.profileStore.origins.length === 0) this.activeTab = 3; this.restoreProfile(target); }
    else if (inbox) { this.activeTab = 2; this.restoreInbox(target); }
    else if (search) { this.activeTab = 1; this.restoreRetainedSearch(search); }
    else if (this.isHomeRootAddress(target)) {
      this.activeTab = 0;
      this.prepareHomeForPageBegin(target);
    }
    this.tabsController.changeIndex(this.activeTab);
  }

  private returnToHistoryEntry(target: string): boolean {
    try {
      const entries: webview.BackForwardList = this.controller.getBackForwardEntries();
      for (let index: number = entries.currentIndex - 1; index >= 0; index--) {
        if (this.pageHistory.key(entries.getItemAtIndex(index).historyUrl) === this.pageHistory.key(target)) {
          this.controller.backOrForward(index - entries.currentIndex);
          return true;
        }
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: matching history entry unavailable');
    }
    return false;
  }

  private loadReturnTarget(target: string, token: number): void {
    if (this.businessSuspended || token !== this.pageBackToken || this.returnLoadToken === token) return;
    this.returnLoadToken = token;
    this.detailReturnJourney?.mark('return.target.load.once');
    this.controller.loadUrl(target);
  }

  private backOnePage(fallback: string = PINTEREST_URL, targetOverride: string = ''): boolean {
    if (this.pageHistory.isPending()) return true;
    try {
      const target: string = targetOverride ? this.pageHistory.prepareBackTo(targetOverride) :
        this.pageHistory.prepareBack(fallback);
      if (!target) return false;
      const token: number = ++this.pageBackToken;
      this.restoreRetainedSearch(this.searchUrlFromAddress(target));
      const canReuseHomeDocument: boolean = !this.webPageLoading && !this.pinStore.detailOpeningPin;
      const departedPin: string = this.pinStore.detailPin || this.pinStore.detailOpeningPin;
      if (departedPin) {
        this.controller.runJavaScript('window.PinWebDetailPause && window.PinWebDetailPause(' +
          JSON.stringify(departedPin) + ')').catch(() => {});
      }
      this.presentNativeBackTarget(target);
      this.nativeNetwork.invalidate();
      this.pinStore.detailPrefetch.pause();
      PinWebRuntimeLog.info('PinWebReturn: native destination presented');
      this.detailReturnJourney?.mark('return.native.presented');
      if (this.pinIdentity(target) && this.pinStore.detail?.kind === 'cached') {
        this.nativeBackTarget = '';
        this.pageHistory.visit(target, 'load');
        this.pageHistory.cancelBack();
        this.pinStore.detailPresentationOnly = true;
        this.pinStore.detailActionsReady = false;
        this.detailReturnJourney?.mark('return.cache.presentation.only');
        return true;
      }
      // Target navigation supersedes the child without stopping its Web document first.
      if (canReuseHomeDocument && this.isHomeRootAddress(target) && this.pageHistory.key(this.controller.getUrl()) === this.pageHistory.key(target)) {
        // getUrl alone does not prove the retained document is still the homepage.
        this.controller.runJavaScript('location.href === ' + JSON.stringify(target) +
          ' && typeof window.PinWebHomeRefresh === "function" ? (window.PinWebHomeRefresh(), true) : false')
          .then((result: string) => {
            if (token !== this.pageBackToken) return;
            if (result === 'true' || result === '"true"') {
              this.recordPageNavigation(target, 'observe');
              this.syncAuthentication();
              PinWebRuntimeLog.info('PinWebReturn: retained home document reused');
              this.detailReturnJourney?.mark('return.document.reused');
            } else this.loadReturnTarget(target, token);
          }).catch(() => { if (token === this.pageBackToken) this.loadReturnTarget(target, token); });
      } else if (departedPin && this.isHomeRootAddress(target)) {
        // Native Pin history can differ from the retained hidden Web history.
        // Use one explicit home navigation instead of history plus a timed reload.
        this.detailReturnJourney?.mark('return.native.route.direct');
        this.loadReturnTarget(target, token);
        this.lastRootBackAt = 0;
        return true;
      } else if (!this.returnToHistoryEntry(target)) {
        this.detailReturnJourney?.mark('return.history.missing');
        this.loadReturnTarget(target, token);
      } else this.detailReturnJourney?.mark('return.history.used');
      setTimeout(() => {
        if (token === this.pageBackToken && this.nativeBackTarget &&
            this.pageHistory.key(this.nativeBackTarget) === this.pageHistory.key(target)) {
          // A BackForwardList entry can accept backOrForward without producing a
          // usable page-begin event. Do not leave the native parent blocked for
          // ten seconds; load the already presented target and let route
          // confirmation clear nativeBackTarget.
          this.pageHistory.cancelBack();
          this.detailReturnJourney?.mark('return.history.fallback');
          this.controller.runJavaScript('location.href === ' + JSON.stringify(target))
            .then((result: string) => {
              if (token !== this.pageBackToken || !this.nativeBackTarget) return;
              if ((result === 'true' || result === '"true"') && this.pageHistory.key(this.controller.getUrl()) === this.pageHistory.key(target)) {
                this.recordPageNavigation(target, 'observe');
                this.bindCurrentDetailDocument(target);
                this.syncAuthentication();
                this.detailReturnJourney?.mark('return.document.confirmed');
              } else this.loadReturnTarget(target, token);
            }).catch(() => { if (token === this.pageBackToken && this.nativeBackTarget) this.loadReturnTarget(target, token); });
        }
      }, 600);
      this.lastRootBackAt = 0;
      return true;
    } catch (error) {
      this.pageHistory.cancelBack();
      this.showMessage('无法返回上一页，请重试');
      return true;
    }
  }

  private async backFromDetail(): Promise<void> {
    PinWebRuntimeLog.info('PinWebReturn: detail back sheet=' + this.activeSheetKind +
      ' pending=' + this.pageHistory.isPending().toString());
    if (Date.now() < this.pinStore.shareBackHandledUntil) return;
    if (this.showNativeSheet || this.activeSheetKind) {
      this.onBackPress();
      return;
    }
    this.lastRootBackAt = 0;
    if (this.backInProgress) return;
    const current: string = this.pinIdentity(this.pinStore.detail?.pinUrl || this.pinStore.detailOpeningPin);
    const parent: string = this.pinStore.detailOrigin(current) || this.pinStore.detailReturnUrl || PINTEREST_URL;
    // Another native back can supersede a still-loading cached parent document.
    // Commit that visible parent first, then invalidate its delayed callbacks.
    if (this.nativeBackTarget && this.pinIdentity(this.nativeBackTarget) === current) {
      this.pageHistory.visit(this.nativeBackTarget, 'load');
      this.pageHistory.cancelBack();
      this.nativeBackTarget = '';
      this.pageBackToken++;
    }
    if (this.pageHistory.isPending()) return;
    if (this.detailJourney.current()) this.detailReturnJourney.begin(this.detailJourney.current(), this.detailOpenedAt, 'back.clicked');
    // Native entry points record the actual origin even when SPA history omits it.
    // A fallback alone cannot override a stale preceding homepage entry.
    const origin: string = this.extractPinUrl(parent) || this.searchUrlFromAddress(parent) ||
      (this.profileUrlFromAddress(parent) || this.boardUrlFromAddress(parent) || this.isHomeRootAddress(parent) ? parent : '');
    this.pinStore.leaveDetailOrigin(current);
    this.backOnePage(parent || PINTEREST_URL, origin);
  }

  private returnFromSearchQuiz(): boolean {
    const current: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!current || current.pageKey !== this.currentSearchPageKey() || !current.quiz || current.quiz.mode === 'entry') return false;
    this.searchStore.searchQuizReturnPage = current.pageKey;
    this.searchStore.search = { kind: 'state', session: current.session, pageKey: current.pageKey,
      quiz: { mode: 'entry', title: current.quiz.entryTitle || current.quiz.title, eyebrow: current.quiz.eyebrow,
        pickerTitle: current.quiz.pickerTitle, submitLabel: current.quiz.submitLabel,
        topics: current.quiz.topics, cards: [], canMore: false, count: 0, busy: false, error: '' },
      api: current.api, apiError: current.apiError, apiBusy: current.apiBusy, apiActive: current.apiActive, apiEnded: current.apiEnded,
      discoveryApi: current.discoveryApi, discoveryBusy: current.discoveryBusy, discoveryError: current.discoveryError,
      discoveryActive: current.discoveryActive, discoveryEnded: current.discoveryEnded,
      query: current.query, placeholder: current.placeholder, selectedCategory: current.selectedCategory,
      categories: current.categories, suggestions: current.suggestions, heroes: current.heroes,
      ideaSections: current.ideaSections, results: current.results };
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    this.controller.runJavaScript('window.PinWebSearchQuizApi && window.PinWebSearchQuizApi.action(' +
      JSON.stringify(current.pageKey) + ',"back","")')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: quiz background cancellation unavailable'));
    return true;
  }

  private async handleBack(): Promise<void> {
    if (Date.now() < this.pinStore.shareBackHandledUntil) return;
    if (this.showNativeSheet || this.activeSheetKind) { this.onBackPress(); return; }
    if (this.pinStore.detail || this.currentPinUrl()) { this.backFromDetail(); return; }
    if (this.returnFromSearchQuiz()) return;
    if (this.homeStore.pendingHomeMorePin) this.cancelHomeDetailMore();
    if (this.backInProgress || this.pageHistory.isPending()) {
      return;
    }
    this.backInProgress = true;
    try {
      let handled: boolean = false;
      try {
        const result: string = await this.controller.runJavaScript('window.PinWebHandleBack ? window.PinWebHandleBack() : false');
        handled = result === 'true' || result === '"true"';
      } catch (error) {
        PinWebRuntimeLog.warn('PinWeb: could not inspect the open web panel');
      }
      if (this.showNativeSheet || this.activeSheetKind || this.pinStore.detail || this.currentPinUrl() ||
          Date.now() < this.pinStore.shareBackHandledUntil) {
        this.lastRootBackAt = 0;
        return;
      }
      if (handled) {
        this.lastRootBackAt = 0;
      } else if (this.backOnePage()) {
        this.lastRootBackAt = 0;
      } else {
        // A sheet/HDS back event can reach the root after its child has closed.
        // Root back must never turn that second delivery into ability termination.
        this.lastRootBackAt = 0;
        try {
          await this.controller.runJavaScript('window.PinWebDismissUnknownPanel && window.PinWebDismissUnknownPanel()');
        } catch (error) {
          PinWebRuntimeLog.warn('PinWeb: could not dismiss an unrecognized web panel');
        }
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: back navigation failed');
    } finally {
      this.backInProgress = false;
    }
  }

  private reload(): void {
    if (this.offlinePreviewMode) {
      this.offlinePreviewMode = false;
      this.offlineCacheLoading = false;
      PinWebRuntimeLog.info('OfflineCache: preview retry requested');
      PinWebRuntimeLog.info('OfflineCache: preview exited reason=manual-retry');
      this.retryLogin();
      return;
    }
    if (this.authStatus !== 'authenticated') { this.retryLogin(); return; }
    if (this.nativeRootOnly) { this.requestRootPage(this.activeTab); return; }
    this.loadFailed = false;
    this.failureDetails = '';
    try {
      this.controller.loadUrl(this.lastPageUrl || PINTEREST_URL);
    } catch (error) {
      this.loadFailed = true;
    }
  }

  private async openInBrowser(): Promise<void> {
    try {
      await this.systemActions.openLink(PINTEREST_URL);
    } catch (error) {
      PinWebRuntimeLog.error('PinWeb: failed to open Pinterest in browser');
      this.showMessage('无法打开浏览器');
    }
  }

  private showMessage(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: message unavailable');
    }
  }

  private rejectOfflineAction(action: string, message: string = '当前离线，暂不可操作'): boolean {
    if (!this.offlinePreviewMode) return false;
    PinWebRuntimeLog.info('ActionGate: ' + action + ' blocked reason=offline-preview');
    this.showMessage(message);
    return true;
  }

  private isCurrentPageFailure(url: string): boolean {
    if (this.nativeRootOnly && !isPinterestAuthRoute(url)) return false;
    if (this.logoutAwaitingLogin && !isPinterestAuthRoute(url)) return false;
    if (this.authStatus !== 'authenticated') return true;
    if (this.staleRootDocumentTarget() >= 0 && this.extractPinUrl(url) &&
        !this.pinStore.detailOpeningPin && !this.nativeBackTarget) {
      PinWebRuntimeLog.info('RootTabTrace: ignored-secondary-failure targetTab=' +
        this.staleRootDocumentTarget().toString());
      return false;
    }
    const failedRoot: number = this.rootTabIndexFromAddress(url);
    if (failedRoot >= 0 && failedRoot !== this.effectiveRootDocumentTarget()) {
      PinWebRuntimeLog.info('RootTabTrace: ignored-root-failure failedTab=' + failedRoot.toString() +
        ' activeTab=' + this.activeTab.toString() + ' pendingTarget=' + this.staleRootDocumentTarget().toString());
      return false;
    }
    const expected: string = this.nativeBackTarget || this.protectedDetailAddress() ||
      (this.rootReadToken >= 0 && this.rootReadToken === this.tabRequestToken ? this.rootReadAddress : '') ||
      this.navigationAddress;
    return !expected || url === expected;
  }

  /**
   * A root document can fail while its native snapshot is still usable. Keep
   * that snapshot visible and gate its actions instead of replacing the whole
   * root Tabs tree with the global load-failed page.
   */
  private retainRootSnapshotAfterFailure(failedRoot: number, url: string, code: number): boolean {
    const message: string = this.describeFailure(url, code);
    if (failedRoot === 0) {
      const pageKey: string = this.homePageKeyFromAddress(url);
      const snapshot: PinWebHomeSnapshot | undefined = this.homeStore.cachedHome?.pageKey === pageKey ?
        this.homeStore.cachedHome : this.homeStore.home?.pageKey === pageKey ? this.homeStore.home : undefined;
      if (!snapshot || snapshot.pins.length === 0) return false;
      this.homeStore.home = snapshot;
      this.homeStore.homeLoading = false;
      this.homeStore.homeRefreshing = false;
      this.homeStore.homeActionsReady = false;
      this.homeStore.homeError = message || '首页连接失败，请重试';
    } else if (failedRoot === 1) {
      const pageKey: string = this.searchUrlFromAddress(url);
      const snapshot: PinWebSearchSnapshot | undefined = this.searchStore.search?.pageKey === pageKey ?
        this.searchStore.search : this.searchStore.retainedSearch?.pageKey === pageKey ? this.searchStore.retainedSearch : undefined;
      if (!snapshot || (snapshot.results.length === 0 && snapshot.heroes.length === 0 && snapshot.ideaSections.length === 0)) return false;
      this.searchStore.search = snapshot;
      this.searchStore.searchLoading = false;
      this.searchStore.searchActionsReady = false;
      this.searchStore.searchInputReady = false;
      this.searchStore.searchError = message || '搜索连接失败，请重试';
    } else if (failedRoot === 2) {
      const pageUrl: string = this.inboxUrlFromAddress(url);
      const snapshot: PinWebInboxSnapshot | undefined = this.inboxStore.inbox?.pageUrl === pageUrl ?
        this.inboxStore.inbox : undefined;
      if (!snapshot || (snapshot.items.length === 0 && snapshot.contacts.length === 0)) return false;
      this.inboxStore.inboxLoading = false;
      this.inboxStore.inboxActionsReady = false;
      this.inboxStore.inboxRetainedContent = true;
      this.inboxStore.inboxError = message || '收件箱连接失败，请重试';
    } else if (failedRoot === 3) {
      const profileUrl: string = this.profileUrlFromAddress(url);
      const snapshot: PinWebProfileSnapshot | undefined = this.profileStore.profile?.profileUrl === profileUrl ?
        this.profileStore.profile : undefined;
      if (!snapshot || (snapshot.boards.length === 0 && snapshot.createdPins.length === 0 && !snapshot.displayName)) return false;
      this.profileStore.profileSwitching = false;
      this.profileStore.profileLoading = false;
      this.profileStore.profileActionsReady = false;
      this.profileStore.profileError = message || '资料连接失败，请重试';
    } else {
      return false;
    }
    PinWebRuntimeLog.warn('RootTabTrace: snapshot-retained-after-failure targetTab=' +
      failedRoot.toString() + ' actionsReady=false');
    return true;
  }

  private configureDocumentRetention(enabled: boolean): void {
    try {
      const options: webview.BackForwardCacheOptions = new webview.BackForwardCacheOptions();
      options.size = enabled ? 4 : 0;
      options.timeToLive = 300;
      this.controller.setBackForwardCacheOptions(options);
      PinWebRuntimeLog.info('RootTabTrace: document-retention size=' + options.size.toString() +
        ' ttlSeconds=' + options.timeToLive.toString());
    } catch (_) { PinWebRuntimeLog.warn('PinWebReturn: document retention configuration unavailable'); }
  }

  private scheduleInterruptedHomeRecovery(): void {
    if (this.nativeRootOnly) return;
    const page: string = this.interruptedHomePage;
    if (!page || this.homeRecoveryAttempted || !this.pinStore.videoForeground ||
        this.homePresentationPageKey() !== page || !this.isHomeRootAddress(page) ||
        this.homeStore.cachedHome?.pageKey !== page || this.showNativeSheet || this.homeStore.homeRefreshing) return;
    const token: number = ++this.homeRecoveryToken;
    const epoch: number = this.authEpoch;
    const backToken: number = this.pageBackToken;
    const requestToken: number = this.homeStore.homeRequestToken;
    // Coalesce the main-frame error burst emitted during a network handover.
    setTimeout(() => {
      if (token !== this.homeRecoveryToken || epoch !== this.authEpoch || backToken !== this.pageBackToken ||
          requestToken !== this.homeStore.homeRequestToken || this.authStatus !== 'authenticated' ||
          this.homeRecoveryAttempted || !this.pinStore.videoForeground || this.interruptedHomePage !== page ||
          this.homePresentationPageKey() !== page || this.showNativeSheet || this.homeStore.homeRefreshing ||
          this.homeStore.cachedHome?.pageKey !== page) return;
      this.homeRecoveryAttempted = true;
      this.pageBackToken++;
      this.pageHistory.cancelBack();
      this.nativeNetwork.invalidate();
      this.pinStore.detailPrefetch.pause();
      this.nativeBackTarget = page;
      this.navigationAddress = page;
      this.lastPageUrl = page;
      this.homeStore.homeActionsReady = false;
      this.expectHome();
      PinWebRuntimeLog.info('HomeRecovery: reloading interrupted home document');
      try {
        this.controller.loadUrl(page);
      } catch (_) {
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = '首页连接失败，请重试';
        PinWebRuntimeLog.warn('HomeRecovery: reload unavailable, manual retry retained');
      }
    }, 250);
  }

  private handleMainFrameFailure(url: string, code: number, info: string): void {
    if (!this.isCurrentPageFailure(url)) {
      PinWebRuntimeLog.info('PinWebReturn: ignored obsolete main frame failure, code ' + code.toString());
      return;
    }
    PinWebRuntimeLog.warn('NavigationFailureTrace: epoch=' + this.authEpoch + ' targetTab=' + this.effectiveRootDocumentTarget().toString() + ' preparing=' + (this.rootReadToken === this.tabRequestToken).toString() + ' foreground=' + (!this.businessSuspended).toString());
    this.showNetworkNotice(code === -200 ? '网站证书校验失败，请检查网络或代理后重试' : '网络不稳定，页面加载失败，请重试');
    this.pageHistory.cancelBack();
    this.webPageLoading = false;
    this.webPageLoadFinishedAt = Date.now();
    this.homeStore.homeRefreshToken++;
    this.homeStore.homeRefreshing = false;
    this.homeStore.homeRefreshAwaitingPage = false;
    this.homeStore.pendingHomeTab = '';
    if (code === -200) {
      this.homeRecoveryToken++;
      this.interruptedHomePage = '';
      this.homeRecoveryAttempted = true;
      PinWebRuntimeLog.warn('HomeRecovery: certificate failure; manual retry required');
    }
    if (this.authStatus !== 'authenticated') {
      if (this.tryEnterOfflinePreview(url, 'network-failure')) return;
      this.authStatus = 'error';
      this.loadFailed = true;
      this.failureDetails = this.describeFailure(url, code);
      return;
    }
    const failedPinIdentity: string = this.pinIdentity(url);
    const keepDetailForFailedPin: boolean = !!this.pinStore.detail && !!failedPinIdentity &&
      this.pinIdentity(this.pinStore.detail.pinUrl) === failedPinIdentity;
    const keepSearchAfterPinFailure: boolean = !!this.searchStore.search && !!this.searchStore.searchReturnPageKey &&
      this.searchStore.search.pageKey === this.searchStore.searchReturnPageKey && !!this.extractPinUrl(url);
    const keepSearchAfterReturnFailure: boolean = !!this.searchStore.retainedSearch &&
      this.searchStore.retainedSearch.pageKey === this.searchUrlFromAddress(url);
    const failedRoot: number = this.rootTabIndexFromAddress(url);
    const rootSnapshotRetained: boolean = this.retainRootSnapshotAfterFailure(failedRoot, url, code);
    if (rootSnapshotRetained) {
      if (this.pendingWebTab !== -1) {
        this.pendingWebTab = -1;
        this.tabRequestToken++;
      }
      this.failureDetails = '';
      this.loadFailed = false;
      PinWebRuntimeLog.error('PinWeb: main frame load failed, code ' + code + ', info ' + info);
      return;
    }
    // A failed Pin document has no home page key, but the feed is
    // still the valid parent screen and should remain visible.
    const cachedHome: PinWebHomeSnapshot | undefined = this.homeStore.cachedHome;
    const keepHomeAfterFailure: boolean = !!cachedHome &&
      (cachedHome.pageKey === this.homePageKeyFromAddress(url) || !!failedPinIdentity &&
        cachedHome.pageKey === this.homePageKeyFromAddress(this.pinStore.detailReturnUrl));
    if (this.pendingWebTab !== -1) {
      this.pendingWebTab = -1;
      this.tabRequestToken++;
    }
    if (keepDetailForFailedPin) {
      this.pinStore.detailActionsReady = false;
    } else {
      this.pinStore.detail = undefined;
      this.pinStore.detailActionsReady = false;
    }
    this.clearInbox();
    if (keepHomeAfterFailure && cachedHome) {
      PinWebRuntimeLog.warn('HomeRefresh: failed reason=main-frame-error snapshotRetained=true');
      this.homeStore.homeRefreshing = false;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.home = cachedHome;
      this.homeStore.homeActionsReady = false;
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = '首页连接失败，请重试';
      if (!keepDetailForFailedPin) {
        this.clearDetail();
        this.nativeBackTarget = cachedHome.pageKey;
        this.navigationAddress = this.nativeBackTarget;
        this.lastPageUrl = this.nativeBackTarget;
        this.activeTab = 0;
        this.tabsController.changeIndex(0);
      }
    } else {
      if (this.activeTab === 0 || this.homeStore.homeRefreshing) {
        PinWebRuntimeLog.warn('HomeRefresh: failed reason=main-frame-error snapshotRetained=false');
      }
      this.clearHome();
    }
    if (keepSearchAfterReturnFailure) this.restoreRetainedSearch(this.searchUrlFromAddress(url));
    else if (!keepSearchAfterPinFailure) this.clearSearch();
    PinWebRuntimeLog.error('PinWeb: main frame load failed, code ' + code +
      ', info ' + info);
    if (keepDetailForFailedPin || keepHomeAfterFailure || keepSearchAfterReturnFailure) {
      this.failureDetails = '';
      this.loadFailed = false;
    } else {
      this.failureDetails = this.describeFailure(url, code);
      this.loadFailed = true;
    }
    if (keepHomeAfterFailure && !keepDetailForFailedPin && this.isHomeRootAddress(url) &&
        (code === -21 || code === -103)) {
      this.interruptedHomePage = this.homePageKeyFromAddress(url);
      this.scheduleInterruptedHomeRecovery();
    }
  }

  private describeFailure(url: string, code: number): string {
    const path: string = url.split('?')[0].split('#')[0];
    const shortPath: string = path.length > 140 ? path.substring(0, 140) + '…' : path;
    const reason: string = code === -113 ? 'HTTPS 安全连接协商失败 · ' :
      code === -200 ? '网站证书校验失败，请检查网络或代理后重试 · ' : code === -100 ? '连接被关闭 · ' : '';
    return reason + '错误码 ' + code.toString() + ' · ' + shortPath;
  }


  private clearProfile(preserveWebFlow: boolean = false): void {
    this.closePublishFlow(true);
    this.finishProfilePull();
    const profileHasContent: boolean = !!this.profileStore.profile &&
      (this.profileStore.profileActionsReady || this.profileStore.profile.boards.length > 0 ||
        this.profileStore.profile.createdPins.length > 0 || !!this.profileStore.profile.displayName);
    if (this.profileStore.profile && profileHasContent) {
      this.profileStore.profileCache.put(this.profileStore.profile, this.profileStore.profileScrollOffset);
    }
    this.profileStore.profileActionsReady = false;
    this.profileStore.profileScrollOffset = 0;
    this.profileStore.profileRequestToken++;
    this.profileStore.profile = undefined;
    this.profileStore.profileSession = 0;
    this.profileStore.profileUrl = '';
    this.profileStore.profileLoading = false;
    this.profileStore.profileError = '';
    if (!preserveWebFlow) {
      this.profileStore.profileWebFlow = false;
      this.profileStore.profileFlowLeftPage = false;
    }
    this.profileStore.profileSwitching = false;
    this.profileStore.publishOptions = [];
    this.profileStore.publishTitle = '';
    this.profileStore.publishLoading = false;
    if (this.activeSheetKind === 'publish') {
      this.showNativeSheet = false;
      this.activeSheetKind = '';
    }
  }

  private restoreProfile(address: string): boolean {
    const url: string = this.profileUrlFromAddress(address);
    const section: string = /\/_created(?:\/|[?#]|$)/i.test(address) ? 'created' : 'saved';
    const entry = this.profileStore.profileCache.get(url, section);
    if (!entry) return false;
    this.profileStore.profile = entry.snapshot;
    this.profileStore.profileUrl = url;
    this.profileStore.profileScrollOffset = entry.scrollOffset;
    this.profileStore.profileActionsReady = false;
    this.profileStore.profileLoading = false;
    this.profileStore.profileError = '';
    return true;
  }

  private expectProfile(): void {
    let address: string = '';
    if (this.pendingWebTab === 3) address = this.rootTabAddresses.get(3) || '';
    else { try { address = this.controller.getUrl(); } catch (_) {} }
    if (this.restoreProfile(address)) return;
    if (this.pendingWebTab === 3 && this.restoreProfile(this.rootTabAddresses.get(3) || '')) return;
    this.profileStore.profileRequestToken++;
    const token: number = this.profileStore.profileRequestToken;
    this.profileStore.profileLoading = true;
    this.profileStore.profileError = '';
    setTimeout(() => {
      if (token !== this.profileStore.profileRequestToken || this.profileStore.profile || !this.profileStore.profileLoading) return;
      if (this.activeTab !== 3 && !this.currentProfileUrl()) {
        this.clearProfile();
        return;
      }
      this.profileStore.profileLoading = false;
      this.profileStore.profileError = this.currentProfileUrl() ? '无法读取当前 Pinterest 资料页' :
        '网页未进入资料页，请重试';
    }, 8000);
  }

  private profileUrlFromAddress(address: string): string {
    if (this.inboxUrlFromAddress(address)) return '';
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/([^/?#]+)(?:\/(_saved|_created))?\/?(?:[?#]|$)/i);
    if (match && !/^(pin|search|messages|inbox|login|signup|ideas|today|settings)$/i.test(match[2])) {
      return match[1] + '/' + match[2] + '/';
    }
    return '';
  }

  private currentProfileUrl(): string {
    const nativeAddress: string = this.nativeRootPageAddress(3);
    if (nativeAddress) return this.profileUrlFromAddress(nativeAddress);
    try {
      return this.profileUrlFromAddress(this.controller.getUrl());
    } catch (error) {
      return '';
    }
  }

  private boardUrlFromAddress(address: string): string {
    if (!PIN_BOARD_API_ENABLED) return '';
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/([^/?#]+)\/([^/?#]+)\/?(?:[?#]|$)/i);
    if (!match || /^_|^(pin|users|search|ideas|today|settings|messages|inbox|login|signup|business|explore)$/i.test(match[2]) ||
        /^_|^(followers|following)$/i.test(match[3])) return '';
    return match[1] + '/' + match[2] + '/' + match[3] + '/';
  }

  private currentBoardUrl(): string {
    try { return this.boardUrlFromAddress(this.controller.getUrl()); } catch (_) { return ''; }
  }

  private isCurrentBoardMenuPin(pinUrl: string, pageKey: string): boolean {
    const board: PinWebBoardDetail | undefined = this.boardStore.boardDetail;
    if (this.authStatus !== 'authenticated' || !board?.session || !board.ready ||
        board.pageKey !== pageKey || this.currentBoardUrl() !== pageKey || board.flow?.busy ||
        (board.flow?.phase && board.flow.phase !== 'ideas')) return false;
    const pins: PinWebBoardPin[] = board.flow?.phase === 'ideas' ? board.flow.pins : board.pins;
    return !!this.pinIdentity(pinUrl) && pins.some((pin: PinWebBoardPin): boolean => pin.pinUrl === pinUrl);
  }

  private openBoardPinMore(id: string): void {
    const board: PinWebBoardDetail | undefined = this.boardStore.boardDetail;
    if (!PIN_POST_API_ENABLED || !board) return;
    const pins: PinWebBoardPin[] = board.flow?.phase === 'ideas' ? board.flow.pins : board.pins;
    const pin: PinWebBoardPin | undefined = pins.find((item: PinWebBoardPin): boolean => item.id === id);
    if (pin && this.isCurrentBoardMenuPin(pin.pinUrl, board.pageKey)) this.openCustomHomeMenu(pin.pinUrl, board.pageKey);
  }

  private async shareCurrentBoard(): Promise<void> {
    const board: PinWebBoardDetail | undefined = this.boardStore.boardDetail;
    if (this.authStatus !== 'authenticated' || !board?.session || !board.ready || board.flow?.phase ||
        this.currentBoardUrl() !== board.pageKey) return;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebNativeShareApiOpen && ' +
        'window.PinWebNativeShareApiOpen(' + JSON.stringify(board.pageKey) + ')');
      if (result !== 'true' && result !== '"true"') this.showMessage('分享接口暂不可用，请重试');
    } catch (_) { this.showMessage('分享接口暂不可用，请重试'); }
  }

  private syncBoardRoute(address: string): void {
    if (this.nativeRootOnly) return;
    const page: string = this.boardUrlFromAddress(address);
    if (this.boardStore.pendingBoardUrl) {
      if (page === this.boardStore.pendingBoardUrl) {
        // onPageBegin can precede getUrl(); keep covering the old document until the target route is current.
        if (this.currentBoardUrl() !== page) return;
        this.boardStore.pendingBoardUrl = '';
        this.boardStore.pendingBoardSource = '';
        this.boardStore.boardOpeningToken++;
      } else if (this.pageHistory.key(address) === this.pageHistory.key(this.boardStore.pendingBoardSource)) {
        return;
      } else {
        this.boardStore.pendingBoardUrl = '';
        this.boardStore.pendingBoardSource = '';
        this.boardStore.boardOpeningToken++;
      }
    }
    if (page && this.boardStore.boardDetail?.pageKey === page) return;
    const collectionTitle: string = /\/pins\/$/i.test(page) ? '所有 Pin 图' : '图板';
    this.boardStore.boardDetail = page ? { kind: 'state', session: 0, pageKey: page, boardId: '', title: collectionTitle,
      pinCount: '', ownerName: '', ownerAvatar: '', loading: true, loadingMore: false,
      ready: false, error: '', hasMore: false, pins: [] } : undefined;
    if (page) {
      setTimeout(() => {
        if (this.currentBoardUrl() !== page || this.boardStore.boardDetail?.pageKey !== page || this.boardStore.boardDetail.session !== 0) return;
        const board: PinWebBoardDetail = this.boardStore.boardDetail;
        this.boardStore.boardDetail = { kind: board.kind, session: board.session, pageKey: board.pageKey,
          boardId: board.boardId, title: board.title, pinCount: board.pinCount,
          ownerName: board.ownerName, ownerAvatar: board.ownerAvatar, ownerUrl: board.ownerUrl, loading: false,
          loadingMore: board.loadingMore, ready: board.ready, error: '图板接口尚未就绪，请重试',
          hasMore: board.hasMore, pins: board.pins };
      }, 20000);
    }
  }

  private updateBoard(value: string): void {
    if (this.nativeRootOnly) return;
    if (this.nativeBackTarget && this.currentBoardUrl() !== this.nativeBackTarget) return;
    try {
      const message: PinWebBoardDetail = JSON.parse(value) as PinWebBoardDetail;
      if (!message || message.kind !== 'state' || typeof message.session !== 'number' ||
          message.pageKey !== this.currentBoardUrl() || !Array.isArray(message.pins)) return;
      if (typeof message.title !== 'string' || typeof message.pinCount !== 'string' ||
          typeof message.ownerName !== 'string' || typeof message.ownerAvatar !== 'string' ||
          typeof message.error !== 'string' || !message.pins.every((pin): boolean =>
            !!pin && /^\d+$/.test(pin.id) && typeof pin.title === 'string' &&
            /^https:\/\//i.test(pin.imageUrl) && pin.imageWidth > 0 && pin.imageHeight > 0)) return;
      if (message.privacy !== undefined && message.privacy !== 'public' && message.privacy !== 'secret') return;
      if (message.nextPage !== undefined && (typeof message.nextPage !== 'string' || message.nextPage.length > 2048)) return;
      if (message.memberAvatar !== undefined && (typeof message.memberAvatar !== 'string' || message.memberAvatar.length > 2048 ||
          !!message.memberAvatar && !/^https:\/\//i.test(message.memberAvatar))) return;
      if (message.revision !== undefined && (typeof message.revision !== 'number' || !Number.isFinite(message.revision) || message.revision < 0)) return;
      if (this.boardStore.boardDetail?.pageKey === message.pageKey && message.session < this.boardStore.boardDetail.session) return;
      if (message.flow && (!['', 'select', 'targets', 'ideas', 'edit', 'archive', 'archived', 'deleted'].includes(message.flow.phase) ||
          typeof message.flow.loading !== 'boolean' || typeof message.flow.busy !== 'boolean' ||
          typeof message.flow.uncertain !== 'boolean' || typeof message.flow.error !== 'string' || message.flow.error.length > 500 ||
          typeof message.flow.description !== 'string' || typeof message.flow.privacy !== 'string' ||
          !Array.isArray(message.flow.pins) || message.flow.pins.length > 500 ||
          !Array.isArray(message.flow.targets) || message.flow.targets.length > 500 ||
          !Array.isArray(message.flow.saved) || message.flow.saved.length > 500 ||
          !message.flow.pins.every((pin): boolean => !!pin && /^\d+$/.test(pin.id) &&
            typeof pin.title === 'string' && /^https:\/\//i.test(pin.imageUrl) && pin.imageWidth > 0 && pin.imageHeight > 0) ||
          !message.flow.targets.every((target): boolean => !!target && /^\d+$/.test(target.id) &&
            typeof target.title === 'string' && target.title.length <= 300 &&
            typeof target.imageUrl === 'string' && (!target.imageUrl || /^https:\/\//i.test(target.imageUrl))) ||
          !message.flow.saved.every((id): boolean => typeof id === 'string' && /^\d+$/.test(id)))) return;
      // The board bridge emits an initial loading snapshot before it has
      // resolved the collection owner. Keep the route-derived title during
      // that interval instead of briefly falling back to "图板".
      const existingTitle: string = this.boardStore.boardDetail?.title ||
        (/\/pins\/$/i.test(message.pageKey) ? '所有 Pin 图' : '图板');
      const changed: boolean = message.session === this.boardStore.boardDetail?.session &&
        (message.revision || 0) > (this.boardStore.boardDetail?.revision || 0);
      this.boardStore.boardDetail = { kind: message.kind, session: message.session,
        pageKey: message.pageKey, boardId: message.boardId, title: message.title || existingTitle,
        pinCount: message.pinCount, privacy: message.privacy, ownerName: message.ownerName, ownerAvatar: message.ownerAvatar, ownerUrl: this.profileUrlFromAddress(message.ownerUrl || ''),
        loading: message.loading, loadingMore: message.loadingMore, refreshing: message.refreshing,
        ready: message.ready, error: message.error, hasMore: message.hasMore, pins: message.pins,
        editable: message.editable, flow: message.flow, memberAvatar: message.memberAvatar, revision: message.revision };
      if (changed) {
        this.profileStore.profileActionsReady = false;
        this.clearProfile(); this.profileStore.profileCache.clear();
        this.controller.runJavaScript('window.PinWebProfileApi && window.PinWebProfileApi.reset()').catch(() => {});
      }
      if (message.flow?.phase === 'deleted') {
        this.boardStore.boardDetail.flow = undefined;
        this.backFromBoard();
        return;
      }
      if (message.nextPage && this.boardUrlFromAddress(message.nextPage) === message.nextPage &&
          message.nextPage.startsWith('https://www.pinterest.com/') && message.nextPage !== message.pageKey) {
        if (this.boardStore.boardReturnPage === message.pageKey) this.boardStore.boardReturnPage = message.nextPage;
        this.boardStore.pendingBoardUrl = message.nextPage;
        this.boardStore.pendingBoardSource = message.pageKey;
        this.controller.loadUrl(message.nextPage);
        return;
      }
      if (this.boardStore.pendingBoardUrl === message.pageKey) {
        this.boardStore.pendingBoardUrl = '';
        this.boardStore.pendingBoardSource = '';
        this.boardStore.boardOpeningToken++;
      }
    } catch (_) { PinWebRuntimeLog.warn('PinWeb: invalid board state'); }
  }

  private nativeBoardVisible(): boolean {
    return !this.loadFailed && !!this.boardStore.boardDetail &&
      (this.boardStore.pendingBoardUrl === this.boardStore.boardDetail.pageKey || this.boardUrlFromAddress(this.nativeDisplayAddress()) === this.boardStore.boardDetail.pageKey);
  }

  private syncNativeReturnRoute(address: string): void {
    if (this.ignoreSupersededDetailDocument(address)) return;
    if (this.nativeRootOnly) return;
    if (this.nativeBackTarget && this.pageHistory.key(address) !== this.pageHistory.key(this.nativeBackTarget)) return;
    try {
      if (this.pageHistory.key(address) !== this.pageHistory.key(this.controller.getUrl())) return;
    } catch (_) { return; }
    this.navigationAddress = address;
    const pin: string = this.extractPinUrl(address);
    const profile: string = this.profileUrlFromAddress(address);
    if (pin) {
      this.nativePinRoute = this.pinIdentity(pin);
      if (this.profileStore.profileWebFlow) this.profileStore.profileFlowLeftPage = true;
      return;
    }
    if (this.nativePinRoute) {
      this.nativePinRoute = '';
      this.clearDetail();
      this.pinStore.detailReturnUrl = '';
    }
    if (this.profileStore.profileWebFlow && !profile) this.profileStore.profileFlowLeftPage = true;
    const home: boolean = this.isHomeRootAddress(address);
    const inbox: string = this.inboxUrlFromAddress(address);
    const searchRoot: boolean = /^https:\/\/(?:[^/]+\.)?pinterest\.com\/search\/?(?:[?#]|$)/i.test(address) &&
      !/[?&]q=[^&#]+/i.test(address);
    if (this.profileStore.profileFlowLeftPage && (profile || home || inbox || searchRoot)) {
      this.profileStore.profileWebFlow = false;
      this.profileStore.profileFlowLeftPage = false;
    }
    if (profile && this.profileStore.origins.length > 0) return;
    if (profile || home || inbox || searchRoot) {
      if (!this.boardStore.pendingBoardUrl) {
        this.boardStore.boardReturnUrl = '';
        this.boardStore.boardReturnPage = '';
      }
      const index: number = profile ? 3 : inbox ? 2 : searchRoot ? 1 : 0;
      this.showNativeTabs = true;
      this.activeTab = index;
      this.currentWebTab = index;
      if (this.pendingWebTab === index) this.pendingWebTab = -1;
      this.tabsController.changeIndex(index);
    }
  }

  private async openProfileBoard(id: string): Promise<void> {
    this.traceAction('profile.board', id);
    const intent: number = this.tabRequestToken;
    if (!PIN_BOARD_API_ENABLED) {
      PinWebRuntimeLog.info('ActionTrace: profile.board disabled reason=api');
      return;
    }
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile) {
      PinWebRuntimeLog.info('ActionTrace: profile.board disabled reason=profile-unavailable');
      return;
    }
    if (this.boardStore.pendingBoardUrl) {
      PinWebRuntimeLog.info('ActionTrace: profile.board disabled reason=already-opening');
      return;
    }
    if (this.authStatus !== 'authenticated' ||
        (this.profileStore.origins.length === 0 ? this.activeTab !== 3 : this.currentProfileUrl() !== profile.profileUrl)) {
      PinWebRuntimeLog.info('ActionTrace: profile.board disabled reason=profile-url-mismatch');
      return;
    }
    let card: PinWebBoard | undefined = profile.boards.find((item: PinWebBoard): boolean => item.id === id);
    if (!card) {
      // A profile bridge update can replace the card array in the same frame
      // as the tap event. Re-read the current snapshot once before rejecting
      // the tap as stale.
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 80));
      if (intent !== this.tabRequestToken) return;
      const latest: PinWebProfileSnapshot | undefined = this.profileStore.profile;
      if (latest && latest.profileUrl === profile.profileUrl && this.currentProfileUrl() === latest.profileUrl) {
        card = latest.boards.find((item: PinWebBoard): boolean => item.id === id);
      }
    }
    if (!card) {
      PinWebRuntimeLog.info('ActionTrace: profile.board disabled reason=board-not-found');
      return;
    }
    const target: string = card?.targetUrl ? this.boardUrlFromAddress(card.targetUrl) : '';
    if (!target) {
      PinWebRuntimeLog.info('ActionTrace: profile.board disabled reason=board-target-invalid');
      return;
    }
    const token: number = ++this.boardStore.boardOpeningToken;
    this.clearRootTabGuard('board-open');
    this.boardStore.pendingBoardSource = profile.section === 'created' ? profile.profileUrl + '_created/' : profile.profileUrl;
    try {
      const source: string = this.controller.getUrl();
      const retained: string = this.rootTabAddresses.get(3) || '';
      if (this.profileUrlFromAddress(source) === profile.profileUrl) this.boardStore.pendingBoardSource = source;
      else if (this.profileStore.origins.length === 0 && this.profileUrlFromAddress(retained) === profile.profileUrl) {
        this.boardStore.pendingBoardSource = retained;
      }
    } catch (_) {}
    this.boardStore.boardReturnUrl = this.boardStore.pendingBoardSource;
    this.boardStore.boardReturnPage = target;
    this.boardStore.pendingBoardUrl = target;
    const initialTitle: string = /\/pins\/$/i.test(target) ? '所有 Pin 图' : (card!.title || '图板');
    this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: '', title: initialTitle,
      pinCount: card!.pinCount, ownerName: '', ownerAvatar: '', loading: true, loadingMore: false,
      ready: false, error: '', hasMore: false, pins: [] };
    let dispatched: boolean = false;
    try {
      // Board cards already carry a validated route. Keep navigation separate
      // from the profile business-action whitelist, which only opens Pins.
      this.controller.loadUrl(target);
      dispatched = true;
    } catch (_) {
      this.showMessage('无法打开图板，请重试');
    }
    if (!dispatched && token === this.boardStore.boardOpeningToken && this.boardStore.pendingBoardUrl === target) {
      this.boardStore.pendingBoardUrl = ''; this.boardStore.pendingBoardSource = ''; this.boardStore.boardDetail = undefined;
      this.boardStore.boardReturnUrl = ''; this.boardStore.boardReturnPage = '';
      return;
    }
    setTimeout(() => {
      if (!this.boardStore.boardDetail || this.boardStore.boardDetail.pageKey !== target || this.boardStore.boardDetail.session !== 0) return;
      const stillOpening: boolean = token === this.boardStore.boardOpeningToken && this.boardStore.pendingBoardUrl === target;
      const awaitingBridge: boolean = token + 1 === this.boardStore.boardOpeningToken && this.currentBoardUrl() === target;
      if (!stillOpening && !awaitingBridge) return;
      this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: '', title: initialTitle,
        pinCount: card!.pinCount, ownerName: '', ownerAvatar: '', loading: false, loadingMore: false,
        ready: false, error: stillOpening ? '网页尚未进入图板，请重试' : '图板接口尚未就绪，请重试', hasMore: false, pins: [] };
    }, 20000);
  }

  private backFromBoard(): void {
    if (this.boardStore.boardDetail?.flow?.busy) return;
    if (this.boardStore.boardDetail?.flow?.phase) {
      const phase: string = this.boardStore.boardDetail.flow.phase;
      this.boardOperation('flow', JSON.stringify({ action: phase === 'targets' && !this.boardStore.boardDetail.flow.uncertain ? 'select' : 'close' }));
      return;
    }
    if (this.boardStore.pendingBoardUrl) {
      const source: string = this.boardStore.pendingBoardSource;
      this.boardStore.pendingBoardUrl = ''; this.boardStore.pendingBoardSource = ''; this.boardStore.boardOpeningToken++;
      this.boardStore.boardReturnUrl = ''; this.boardStore.boardReturnPage = '';
      this.boardStore.boardDetail = undefined; this.profileStore.profileWebFlow = false;
      if (source) {
        try { this.controller.loadUrl(source); }
        catch (_) { this.showMessage('无法返回资料页，请重试'); }
      }
      return;
    }
    if (this.boardStore.boardReturnUrl && this.boardStore.boardReturnPage === this.currentBoardUrl()) {
      this.backOnePage(this.boardStore.boardReturnUrl, this.boardStore.boardReturnUrl);
      return;
    }
    this.handleBack();
  }

  private boardOperation(method: string, id: string = ''): void {
    const board: PinWebBoardDetail | undefined = this.boardStore.boardDetail;
    if (this.boardStore.pendingBoardUrl) {
      if (method === 'retry' && board) {
        try { this.controller.loadUrl(board.pageKey); }
        catch (_) { this.showMessage('无法重新打开图板，请重试'); }
      }
      return;
    }
    if (!board || this.currentBoardUrl() !== board.pageKey) return;
    if (method === 'refresh' && (board.refreshing || board.loading)) return;
    if (!board.session) { if (method === 'retry') this.reload(); return; }
    if (method === 'open') {
      this.pinStore.detailReturnUrl = board.pageKey;
      const target: PinWebBoardPin | undefined = board.pins.find((pin: PinWebBoardPin): boolean => pin.id === id);
      if (target) this.pinStore.rememberDetailOrigin(this.pinIdentity(target.pinUrl), board.pageKey);
    }
    this.controller.runJavaScript('window.PinWebBoardApi && window.PinWebBoardApi.' + method + '(' +
      board.session.toString() + ',' + JSON.stringify(board.pageKey) +
      (method === 'open' || method === 'flow' ? ',' + JSON.stringify(id) : '') + ')')
      .then((result: string) => {
        if (method === 'open' && result !== 'true' && result !== '"true"') this.showMessage('当前 Pin 图不可用，请重试');
      }).catch(() => this.showMessage('图板接口不可用，请重试'));
  }

  private updateProfile(value: string): void {
    if (this.nativeRootOnly && !this.rootContentInteracted) return;
    if (this.nativeBackTarget) {
      try {
        if (this.pageHistory.key(this.controller.getUrl()) !== this.pageHistory.key(this.nativeBackTarget)) return;
      } catch (_) { return; }
    }
    try {
      const message: PinWebProfileSnapshot = JSON.parse(value) as PinWebProfileSnapshot;
      if (!message || typeof message.session !== 'number' || typeof message.profileUrl !== 'string') return;
      if (PIN_PROFILE_API_ENABLED && (message.kind === 'apiPending' || message.kind === 'apiFailed')) {
        if (message.session < this.profileStore.profileSession || this.currentProfileUrl() !== message.profileUrl) return;
        this.profileStore.profileRequestToken++;
        this.profileStore.profileSession = message.session;
        this.profileStore.profileUrl = message.profileUrl;
        this.profileStore.profileActionsReady = false;
        if (!this.restoreProfile(message.profileUrl + (message.section === 'created' ? '_created/' : ''))) {
          this.profileStore.profile = undefined;
        }
        this.profileStore.profileLoading = !this.profileStore.profile && message.kind === 'apiPending';
        this.profileStore.profileError = message.kind === 'apiFailed' ? '用户资料接口读取失败，请重试' : '';
        if (message.kind === 'apiFailed') this.finishProfilePull();
        return;
      }
      if (message.kind === 'closed') {
        if (this.currentProfileUrl()) return;
        if (message.session >= this.profileStore.profileSession) this.clearProfile(this.profileStore.profileWebFlow);
        return;
      }
      if (message.kind === 'unavailable') {
        if (message.session >= this.profileStore.profileSession &&
            this.currentProfileUrl() === message.profileUrl) {
          this.profileStore.profileRequestToken++;
          this.profileStore.profile = undefined;
          this.profileStore.profileSession = message.session;
          this.profileStore.profileUrl = message.profileUrl;
          this.profileStore.profileLoading = false;
          this.profileStore.profileError = '无法读取当前 Pinterest 资料页';
          this.finishProfilePull();
        }
        return;
      }
      if (message.kind === 'flowClosed') {
        if (message.session === this.profileStore.profileSession && message.profileUrl === this.profileStore.profileUrl) {
          this.profileStore.profileWebFlow = false;
        }
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') || message.session < this.profileStore.profileSession ||
        (message.section !== 'saved' && message.section !== 'created') ||
        !Array.isArray(message.actions) || !Array.isArray(message.boards) ||
        !Array.isArray(message.createdPins) || this.currentProfileUrl() !== message.profileUrl) return;
      if (this.profileStore.profileFlowLeftPage) {
        this.profileStore.profileWebFlow = false;
        this.profileStore.profileFlowLeftPage = false;
      }
      this.profileStore.profileSession = message.session;
      this.profileStore.profileUrl = message.profileUrl;
      this.profileStore.profileRequestToken++;
      this.profileStore.profileLoading = false;
      this.profileStore.profileError = '';
      if (this.profileStore.origins.length === 0 && !this.nativeRootOnly) {
        this.currentWebTab = 3; this.activeTab = 3; this.tabsController.changeIndex(3);
      }
      if (this.pendingWebTab === 3) this.pendingWebTab = -1;
      this.profileStore.profileSwitching = false;
      const actions: PinWebProfileAction[] = message.actions.filter((item: PinWebProfileAction): boolean =>
        !!item.id && !!item.kind && (!!item.label || item.kind === 'settings'));
      const boards: PinWebBoard[] = message.boards.filter((item: PinWebBoard): boolean =>
        !!item.id && !!item.title && Array.isArray(item.covers));
      const createdPins: PinWebCreatedPin[] = message.createdPins.filter((item: PinWebCreatedPin): boolean =>
        !!item.id && !!item.imageUrl);
      const retained = this.profileStore.profileCache.get(message.profileUrl, message.section);
      const retainingContent: boolean = !!retained && (message.contentLoading === true || !!message.contentError);
      if (this.profileStore.profile && (this.profileStore.profile.profileUrl !== message.profileUrl || this.profileStore.profile.section !== message.section)) {
        this.profileStore.profileScrollOffset = 0;
      }
      this.profileStore.profile = {
        kind: 'state', session: message.session, profileUrl: message.profileUrl, section: message.section,
        displayName: message.displayName || '', handle: message.handle || '',
        avatarUrl: message.avatarUrl || '', followers: message.followers || '',
        following: message.following || '', actions: actions,
        business: message.business === true, isOwn: message.isOwn, about: typeof message.about === 'string' ? message.about.slice(0, 2000) : '',
        website: typeof message.website === 'string' && /^https?:\/\//.test(message.website) ? message.website.slice(0, 2000) : '',
        boards: retainingContent && retained ? retained.snapshot.boards : boards,
        createdPins: retainingContent && retained ? retained.snapshot.createdPins : createdPins,
        contentLoading: !retainingContent && message.contentLoading === true, contentLoadingMore: message.contentLoadingMore === true,
        contentError: message.contentError || '',
        unorganizedPins: Array.isArray(message.unorganizedPins) ? message.unorganizedPins.filter(
          (pin: PinWebCreatedPin): boolean => !!pin.id && !!pin.imageUrl) : [],
        unorganizedLoading: message.unorganizedLoading === true,
        unorganizedError: message.unorganizedError || '', unorganizedHasMore: message.unorganizedHasMore === true,
        unorganizedFeedback: message.unorganizedFeedback || '', organize: message.organize || undefined
      };
      this.profileStore.profileActionsReady = !retainingContent;
      if (this.profileStore.profileActionsReady && this.profileStore.origins.length === 0) this.rootTabAddresses.set(3,
        message.profileUrl + (message.section === 'created' ? '_created/' : ''));
      if (message.contentLoading !== true || !!message.contentError) this.finishProfilePull();
      if (this.profileStore.profileActionsReady) this.profileStore.profileCache.put(this.profileStore.profile, this.profileStore.profileScrollOffset);
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid profile state');
    }
  }

  private updateProfilePublish(value: string): void {
    try {
      const message: PinWebPublishSnapshot = JSON.parse(value) as PinWebPublishSnapshot;
      if (!message || message.kind !== 'state' || message.session !== this.profileStore.profileSession ||
        message.profileUrl !== this.profileStore.profileUrl || !Array.isArray(message.options) ||
        this.activeSheetKind !== 'publish') return;
      this.profileStore.publishOptions = message.options.filter((item: PinWebPublishOption): boolean =>
        !!item.id && !!item.kind && !!item.group && !!item.groupLabel && !!item.label);
      this.profileStore.publishTitle = message.title || '';
      this.profileStore.publishLoading = false;
      PinWebRuntimeLog.info(`PublishTrace: options received count=${this.profileStore.publishOptions.length}`);
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid publishing state');
    }
  }

  private async changeProfileTab(section: string): Promise<void> {
    if (!await this.prepareProfileInteraction()) return;
    if (this.profileStore.profileActionsReady === false) return;
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || this.profileStore.profileSwitching || section === profile.section) return;
    this.rootContentInteracted = true;
    this.profileStore.profileSwitching = true;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebProfileTab && ' +
        'window.PinWebProfileTab(' + profile.session.toString() + ',' +
        JSON.stringify(profile.profileUrl) + ',' + JSON.stringify(section) + ')');
      if (result === 'true' || result === '"true"') {
        setTimeout(() => {
          if (this.profileStore.profileSwitching && this.profileStore.profileSession === profile.session) {
            this.profileStore.profileSwitching = false;
            this.showMessage('资料接口尚未切换页签，请重试');
          }
        }, 2200);
        return;
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: profile tab unavailable');
    }
    this.profileStore.profileSwitching = false;
    this.showMessage('无法切换个人资料页签，请重试');
  }

  private async organizeProfile(action: string, value: string = '', secret: boolean = false): Promise<void> {
    if (!await this.prepareProfileInteraction()) return;
    if (this.profileStore.profileActionsReady === false) return;
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || profile.section !== 'saved' || this.currentProfileUrl() !== profile.profileUrl) return;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebProfileOrganizeAction && ' +
        'window.PinWebProfileOrganizeAction(' + profile.session.toString() + ',' + JSON.stringify(profile.profileUrl) +
        ',' + JSON.stringify(action) + ',' + JSON.stringify(value) + ',' + secret.toString() + ')');
      if (result !== 'true' && this.profileStore.profileSession === profile.session) this.showMessage('当前操作不可用，请刷新后重试');
    } catch (_) { this.showMessage('无法执行整理操作，请刷新后重试'); }
  }

  private openUserProfile(url: string): void {
    const page: string = this.profileUrlFromAddress(url);
    if (this.authStatus !== 'authenticated' || !page) return;
    if (page === this.currentProfileUrl()) { this.closeProfilePanel(); this.profileSettingsVisible = false; return; }
    if (this.profileStore.origins.length >= 12) return;
    this.clearRootTabGuard('profile-open');
    const source: string = this.controller.getUrl();
    this.profileStore.origins.push({ page: source, tab: this.activeTab, profile: this.profileStore.profile,
      scroll: this.profileStore.profileScrollOffset, panel: this.profileStore.panel });
    if (this.pinStore.detail) this.pinStore.detailCache.put(this.pinIdentity(this.pinStore.detail.pinUrl), this.pinStore.detail, this.pinStore.detailScrollOffset);
    if (this.activeSheetKind === 'comments') this.dismissApiComments();
    this.closeProfilePanel();
    this.clearDetail();
    this.clearProfile();

    this.pageHistory.visit(source, 'load');
    this.controller.loadUrl(page);
  }
  private backFromUserProfile(): void {
    const origin = this.profileStore.origins.pop();
    if (!origin) return;
    this.closeProfilePanel();
    this.clearProfile();
    this.activeTab = origin.tab; this.tabsController.changeIndex(origin.tab);
    if (origin.profile) {
      this.profileStore.profileCache.put(origin.profile, origin.scroll);
      this.profileStore.profile = origin.profile;
      this.profileStore.profileScrollOffset = origin.scroll;
      this.profileStore.profileActionsReady = false;
    }
    this.backOnePage(origin.page, origin.page);
    if (origin.panel && this.profileUrlFromAddress(origin.page)) {
      const mode: string = origin.panel.mode, section: string = origin.panel.section;
      setTimeout(() => { if (this.currentProfileUrl() === this.profileUrlFromAddress(origin.page)) this.openProfilePanel(mode, section); }, 500);
    }
  }

  private async followProfileUser(id: string = ''): Promise<void> {
    if (!id && !await this.prepareProfileInteraction()) return;
    const page: string = this.currentProfileUrl();
    const source: string = this.controller.getUrl();
    const token: number = this.profileStore.panelToken;
    if (!page || this.authStatus !== 'authenticated' || !this.profileStore.profileActionsReady || this.profileFollowingBusy) return;
    this.profileFollowingBusy = true;
    try {
      const started: string = await this.controller.runJavaScript('window.PinWebProfilePanel && window.PinWebProfilePanel.follow(' + JSON.stringify(page) + ',' + JSON.stringify(id) + ')');
      if (started !== 'true' && started !== '"true"') return;
      let status: string = 'pending';
      for (let i: number = 0; i < 65; i++) {
        if (this.authStatus !== 'authenticated' || this.controller.getUrl() !== source || this.profileStore.panelToken !== token) return;
        status = this.webJsonText(await this.controller.runJavaScript('JSON.stringify(window.PinWebProfilePanel.readFollow())'));
        if (status !== 'pending') break;
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250); });
      }
      if (status !== 'ok') { this.showMessage('关注操作结果未确认，请刷新核对'); return; }
      if (this.profileStore.panel) {
        const raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebProfilePanel.read())');
        if (this.profileStore.panelToken !== token || this.controller.getUrl() !== source) return;
        this.profileStore.panel = JSON.parse(this.webJsonText(raw)) as PinWebProfilePanel;
      }
      await this.controller.runJavaScript('window.PinWebProfileSync && window.PinWebProfileSync()');
    } catch (_) { this.showMessage('关注操作结果未确认，请刷新核对'); }
    finally { this.profileFollowingBusy = false; }
  }

  private closeProfilePanel(): void {
    this.profileStore.panelToken++;
    this.profileStore.panel = undefined;
    this.syncFloatingTabsMotion();
    try { this.controller.runJavaScript('window.PinWebProfilePanel && window.PinWebProfilePanel.close()'); } catch (_) {}
  }
  private async openProfilePanel(mode: string, section: string = 'users'): Promise<void> {
    if (!await this.prepareProfileInteraction()) return;
    const page: string = this.currentProfileUrl();
    if (this.authStatus !== 'authenticated' || !page) return;
    const token: number = ++this.profileStore.panelToken;
    this.profileStore.panel = { page, mode, section, token, loading: true, error: '', items: [],
      firstName: '', lastName: '', about: '', website: '', username: '', avatar: '' };
    this.syncFloatingTabsMotion();
    const source: string = this.controller.getUrl();
    try {
      await this.controller.runJavaScript('window.PinWebProfilePanel && window.PinWebProfilePanel.open(' +
        JSON.stringify(page) + ',' + JSON.stringify(mode) + ',' + JSON.stringify(section) + ',' + token + '); true');
      if (token !== this.profileStore.panelToken || this.authStatus !== 'authenticated' || this.controller.getUrl() !== source) return;
      let value: string = '';
      for (let attempt: number = 0; attempt < 65; attempt++) {
        if (token !== this.profileStore.panelToken || this.authStatus !== 'authenticated' || this.controller.getUrl() !== source) return;
        value = await this.controller.runJavaScript('JSON.stringify(window.PinWebProfilePanel && window.PinWebProfilePanel.read())');
        const pending: PinWebProfilePanel | null = JSON.parse(this.webJsonText(value)) as PinWebProfilePanel | null;
        if (!pending || !pending.loading) break;
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250); });
      }
      const result: PinWebProfilePanel = JSON.parse(this.webJsonText(value)) as PinWebProfilePanel;
      if (token !== this.profileStore.panelToken || !result || result.token !== token || result.page !== page ||
        result.mode !== mode || result.section !== section || !Array.isArray(result.items) || result.items.length > 100) return;
      if (result.loading) throw new Error('timeout');
      this.profileStore.panel = result;
    } catch (_) {
      if (token === this.profileStore.panelToken && this.profileStore.panel) {
        const panel: PinWebProfilePanel = this.profileStore.panel;
        panel.loading = false; panel.error = '读取失败';
        this.profileStore.panel = JSON.parse(JSON.stringify(panel)) as PinWebProfilePanel;
      }
    }
  }

  private async changeProfileAvatar(): Promise<void> {
    const panel: PinWebProfilePanel | undefined = this.profileStore.panel;
    const token: number = this.profileStore.panelToken;
    const page: string = panel?.page || '';
    const source: string = this.controller.getUrl();
    if (!panel || panel.mode !== 'edit' || panel.loading || this.profileSaving || this.authStatus !== 'authenticated') return;
    try {
      const uris: string[] = await pickPublishPhotoUris();
      if (!uris.length) return;
      if (token !== this.profileStore.panelToken || this.profileStore.panel?.page !== page || this.controller.getUrl() !== source || this.authStatus !== 'authenticated') return;
      const photo: PinWebPublishPhoto = await readPublishPhoto(uris[0]);
      if (token !== this.profileStore.panelToken || this.profileStore.panel?.page !== page || this.controller.getUrl() !== source || this.authStatus !== 'authenticated') return;
      const current: PinWebProfilePanel = JSON.parse(JSON.stringify(this.profileStore.panel)) as PinWebProfilePanel;
      current.avatarPreview = photo.data;
      current.avatarError = '已选择照片，但头像上传接口信息不完整，尚未上传或保存';
      this.profileStore.panel = current;
    } catch (error) {
      if (token === this.profileStore.panelToken && this.profileStore.panel?.page === page && this.controller.getUrl() === source) {
        const current: PinWebProfilePanel = JSON.parse(JSON.stringify(this.profileStore.panel)) as PinWebProfilePanel;
        current.avatarError = (error as Error).message || '无法选择此照片，请重试';
        this.profileStore.panel = current;
      }
    }
  }

  private async saveProfilePanel(inputText: string): Promise<void> {
    const panel: PinWebProfilePanel | undefined = this.profileStore.panel;
    if (!panel || panel.mode !== 'edit' || this.authStatus !== 'authenticated' || this.profileSaving) return;
    this.profileSaving = true;
    try {
      await this.controller.runJavaScript('if (window.PinWebProfilePanel) window.PinWebProfilePanel.update(' + JSON.stringify(panel.page) + ',' + panel.token.toString() + ',' + inputText + '); true');
      let result: PinWebProfileSaveResult | undefined = undefined;
      for (let attempt: number = 0; attempt < 80; attempt++) {
        if (this.profileStore.panel?.token !== panel.token || this.authStatus !== 'authenticated') return;
        const raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebProfilePanel && window.PinWebProfilePanel.readSave())');
        result = JSON.parse(this.webJsonText(raw)) as PinWebProfileSaveResult;
        if (result && !result.pending) break;
        await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 250); });
      }
      if (result && result.ok === true) {
        this.showMessage('修改完成');
        this.closeProfilePanel();
        if (result.username && /^\w+$/.test(result.username)) {
          const target: string = 'https://www.pinterest.com/' + result.username + '/';
          if (target !== panel.page) { this.clearProfile(); this.controller.loadUrl(target); }
          else this.refreshProfile(true);
        } else this.refreshProfile(true);
      }
      else if (result && result.duplicate === true) this.showMessage('用户名已被使用');
      else this.showMessage(result?.message || '保存结果未确认，请重新读取资料核对');
    } catch (_) { this.showMessage('资料保存失败，请重试'); }
    finally { this.profileSaving = false; }
  }
  private async performProfileAction(id: string): Promise<boolean> {
    this.traceAction('profile.action', id);
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || !id || this.authStatus !== 'authenticated' ||
        (this.profileStore.origins.length === 0 ? this.activeTab !== 3 : this.currentProfileUrl() !== profile.profileUrl)) return false;
    if (!PIN_PROFILE_API_ENABLED ||
        !profile.createdPins.concat(profile.unorganizedPins || []).some((pin: PinWebCreatedPin): boolean => pin.id === id)) return false;
    this.pinStore.detailReturnUrl = profile.section === 'created' ? profile.profileUrl + '_created/' : profile.profileUrl;
    const target: PinWebCreatedPin | undefined = profile.createdPins.concat(profile.unorganizedPins || [])
      .find((pin: PinWebCreatedPin): boolean => pin.id === id);
    const pinUrl: string = this.extractPinUrl(target?.targetUrl || '');
    if (!pinUrl || !this.pinIdentity(pinUrl)) return false;
    if (target) this.pinStore.rememberDetailOrigin(this.pinIdentity(target.targetUrl || ''), this.pinStore.detailReturnUrl);
    this.clearRootTabGuard('profile-pin-open');
    this.profileStore.profileFlowLeftPage = false;
    this.profileStore.profileWebFlow = false;
    try {
      this.beginDetailOpening(pinUrl, this.pinStore.detailReturnUrl);
      this.controller.loadUrl(pinUrl);
      return true;
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: profile action unavailable');
    }
    this.profileStore.profileWebFlow = false;
    this.showMessage('当前网页操作不可用，请重试');
    return false;
  }

  private async openProfileShare(): Promise<void> {
    if (!await this.prepareProfileInteraction()) return;
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || !profile.profileUrl || this.authStatus !== 'authenticated' || !this.profileStore.profileActionsReady || this.activeSheetKind) return;
    this.profileShareMode = true; this.pinStore.shareSession = 0; this.pinStore.ignoredShareSession = 0;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebNativeShareApiOpen && window.PinWebNativeShareApiOpen(' + JSON.stringify(profile.profileUrl) + ',true)');
      if (result !== 'true' && result !== '"true"') { this.profileShareMode = false; this.showMessage('分享数据尚未就绪，请重试'); }
    } catch (_) { this.profileShareMode = false; this.showMessage('分享数据读取失败，请重试'); }
  }

  private openProfileMenu(): void {
    if (!this.profileStore.profile || this.activeSheetKind || this.authStatus !== 'authenticated') return;
    this.activeSheetKind = 'profileMenu';
    this.showNativeSheet = true;
  }

  private dismissProfileMenu(): void {
    if (this.activeSheetKind === 'profileMenu') {
      this.showNativeSheet = false;
      this.activeSheetKind = '';
    }
  }

  @Builder
  private buildProfileMenuSheet() {
    Column({ space: 4 }) {
      Text('个人资料选项').fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).width('100%')
        .padding({ left: 24, right: 24, top: 18, bottom: 12 })
      Text('屏蔽').fontSize(17).fontColor($r('app.color.primary_text'))
        .width('100%').height(56).padding({ left: 24, right: 24 })
        .onClick(() => {}).accessibilityText('屏蔽')
      Text('关闭').fontSize(17).fontColor($r('app.color.primary_text'))
        .width('100%').height(56).padding({ left: 24, right: 24 })
        .onClick(() => this.dismissProfileMenu()).accessibilityText('关闭')
    }.width('100%').backgroundColor($r('app.color.page_background'))
      .alignItems(HorizontalAlign.Start)
  }

  private openProfilePublish(): void {
    this.traceAction('profile.publish');
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || this.activeSheetKind || this.profilePublishPreparing || this.profileStore.publishLoading &&
        this.profileStore.publishRequestToken > 0 || this.authStatus !== 'authenticated' || this.activeTab !== 3) {
      PinWebRuntimeLog.info(`PublishTrace: entry ignored profile=${!!profile} sheet=${!!this.activeSheetKind} authenticated=${this.authStatus === 'authenticated'} activeTab=${this.activeTab}`);
      return;
    }
    PinWebRuntimeLog.info(`PublishTrace: entry accepted session=${profile.session} actionsReady=${this.profileStore.profileActionsReady}`);
    this.profileStore.publishOptions = [];
    this.profileStore.publishTitle = '';
    this.profileStore.publishLoading = true;
    this.activeSheetKind = 'publish';
    this.showNativeSheet = true;
    const token: number = ++this.profileStore.publishRequestToken;
    this.profilePublishPreparing = true;
    const current = (): boolean => token === this.profileStore.publishRequestToken &&
      this.activeSheetKind === 'publish' && this.showNativeSheet && this.activeTab === 3;
    this.ensureRootActionContext(3, true, 'publish', current).then((ready: boolean) => {
      if (!current()) return;
      PinWebRuntimeLog.info(`PublishTrace: context ready=${ready} profileReady=${this.profileStore.profileActionsReady} documentMatches=${this.profileDocumentMatches(profile.profileUrl)}`);
      if (ready && this.profileStore.profile?.profileUrl === profile.profileUrl && this.profileDocumentMatches(profile.profileUrl)) {
        this.readProfilePublishWhenReady(profile.profileUrl, Date.now() + 8000, token);
      } else {
        PinWebRuntimeLog.warn('PublishTrace: context rejected before web discovery');
        this.profileStore.publishLoading = false;
        this.showMessage('发布入口尚未就绪，请关闭后重试');
      }
    }).finally(() => { if (token === this.profileStore.publishRequestToken) this.profilePublishPreparing = false; });
  }

  private readProfilePublishWhenReady(url: string, deadline: number, token: number): void {
    if (token !== this.profileStore.publishRequestToken || this.activeSheetKind !== 'publish' || !this.showNativeSheet || this.authStatus !== 'authenticated' ||
        this.activeTab !== 3 || this.profileStore.profile?.profileUrl !== url) return;
    if (!this.profileStore.profileActionsReady || !this.profileDocumentMatches(url)) {
      if (Date.now() >= deadline) {
        PinWebRuntimeLog.warn(`PublishTrace: discovery context timeout profileReady=${this.profileStore.profileActionsReady} documentMatches=${this.profileDocumentMatches(url)}`);
        this.profileStore.publishLoading = false;
        this.showMessage('发布入口尚未就绪，请关闭后重试');
        return;
      }
      setTimeout(() => this.readProfilePublishWhenReady(url, deadline, token), 150);
      return;
    }
    const session: number = this.profileStore.profile.session;
    this.controller.runJavaScript('window.PinWebProfilePublishDiscover && ' +
      'window.PinWebProfilePublishDiscover(' + session.toString() + ',' + JSON.stringify(url) + ')')
      .then((result: string) => {
        PinWebRuntimeLog.info(`PublishTrace: discover dispatched result=${result === 'true' || result === '"true"' ? 'accepted' : 'rejected'}`);
        if (token === this.profileStore.publishRequestToken && this.activeSheetKind === 'publish' && this.profileStore.profile?.profileUrl === url &&
            this.profileStore.profile.session === session && result !== 'true' && result !== '"true"') this.profileStore.publishLoading = false;
      }).catch(() => {
        PinWebRuntimeLog.warn('PublishTrace: discovery script failed');
        if (token === this.profileStore.publishRequestToken && this.activeSheetKind === 'publish' && this.profileStore.profile?.profileUrl === url &&
            this.profileStore.profile.session === session) this.profileStore.publishLoading = false;
      });
  }

  private dismissProfilePublish(): void {
    if (this.activeSheetKind !== 'publish') return;
    this.profileStore.publishRequestToken++;
    this.profilePublishPreparing = false;
    const session: number = this.profileStore.profileSession;
    const url: string = this.profileStore.profileUrl;
    this.showNativeSheet = false;
    this.activeSheetKind = '';
    this.profileStore.publishLoading = false;
    this.profileStore.publishOptions = [];
    this.profileStore.publishTitle = '';
    this.controller.runJavaScript('window.PinWebProfilePublishClose && ' +
      'window.PinWebProfilePublishClose(' + session.toString() + ',' + JSON.stringify(url) + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: could not close web publish menu'));
  }

  private async selectProfilePublish(id: string): Promise<void> {
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || this.activeSheetKind !== 'publish' || !this.showNativeSheet ||
        this.authStatus !== 'authenticated' || this.profileStore.publishFlow || !PIN_NATIVE_NETWORK_ENABLED) return;
    const option: PinWebPublishOption | undefined = this.profileStore.publishOptions.find(
      (item: PinWebPublishOption): boolean => item.id === id && item.enabled);
    if (!option || !['website', 'photo', 'board'].includes(option.kind)) return;
    const page: string = this.controller.getUrl();
    if (this.profileUrlFromAddress(page) !== this.profileUrlFromAddress(profile.profileUrl)) return;
    const token: number = ++this.profileStore.publishFlowToken;
    this.profileStore.publishFlow = { token: token, page: page, profile: profile.profileUrl, kind: option.kind,
      phase: option.kind === 'board' ? 'create' : option.kind === 'photo' ? 'photo' : 'website',
      pins: [], selectedIds: [], boards: [], loading: true, busy: false, error: '', feedback: '', hasMore: false,
      uncertain: false, completed: 0 };
    this.dismissProfilePublish();
    this.syncFloatingTabsMotion();
    try {
      const result: string = await this.controller.runJavaScript(useNativeTransport(PIN_PUBLISH_API_SCRIPT) +
        'window.PinWebPublishApi.open(' + JSON.stringify(profile.profileUrl) + ',' + JSON.stringify(option.kind) + ',' + token.toString() + ')');
      if (!this.isCurrentPublish(token, page)) return;
      if (result !== 'true' && result !== '"true"') throw new Error('unavailable');
      if (option.kind === 'photo') {
        const flow: PinWebPublishFlow = this.profileStore.publishFlow!;
        flow.loading = false;
        this.profileStore.publishFlow = JSON.parse(JSON.stringify(flow)) as PinWebPublishFlow;
        await this.pickPublishPhotos(token, page);
        return;
      }
      this.pollPublish(token, page);
    } catch (_) {
      if (this.isCurrentPublish(token, page)) {
        const flow: PinWebPublishFlow = this.profileStore.publishFlow!;
        flow.loading = false; flow.error = '发布接口不可用，请返回重试';
        this.profileStore.publishFlow = JSON.parse(JSON.stringify(flow)) as PinWebPublishFlow;
      }
    }
  }

  private prefetchHomePinDetails(first: number, last: number): void {
    // Prefetch remains gated by !this.pinStore.detailOpeningPin; an opening detail has priority.
    if (this.pinStore.detailOpeningPin) return;
    if (this.detailPrefetchTimer !== -1) return;
    this.detailPrefetchTimer = this.pageTasks.timeout(() => {
      this.detailPrefetchTimer = -1;
      this.prefetchHomePinDetailsNow(first, last);
    }, 700);
  }

  private prefetchHomePinDetailsNow(first: number, last: number): void {
    const home: PinWebHomeSnapshot | undefined = this.homeStore.home;
    const captured: PinWebNetworkContext = this.nativeNetworkContext();
    if (!PIN_DETAIL_API_ENABLED || !PIN_NATIVE_NETWORK_ENABLED || !home || !captured.authenticated ||
      this.activeTab !== 0 || !this.pinStore.videoForeground || this.activeSheetKind || this.pinStore.detail || this.pinStore.detailOpeningPin ||
      !this.homeStore.homeActionsReady || this.homeStore.homeLoading || this.homeStore.homeRefreshing ||
      this.homeStore.pendingHomeTab || home.pageKey !== this.currentHomePageKey()) return;
    const session: number = home.session;
    const tab: string = home.selectedTab;
    const current = (): boolean => {
      const now: PinWebNetworkContext = this.nativeNetworkContext();
      return now.authenticated && now.epoch === captured.epoch && now.page === captured.page &&
        this.activeTab === 0 && this.pinStore.videoForeground && !this.activeSheetKind && !this.pinStore.detail && !this.pinStore.detailOpeningPin &&
        this.homeStore.homeActionsReady && !this.homeStore.homeLoading && !this.homeStore.homeRefreshing &&
        !this.homeStore.pendingHomeTab && this.homeStore.home?.session === session && this.homeStore.home?.selectedTab === tab;
    };
    const urls: string[] = home.pins.slice(Math.max(0, first), Math.min(home.pins.length, first + 6, last + 1))
      .map((pin: PinWebHomePin): string => pin.pinUrl);
    this.pinStore.detailPrefetch.onReady = (_detail: PinWebDetailSnapshot) => {
      if (!current()) return;
      this.pinStore.prefetchedImageUrls = urls.map((url: string): string =>
        this.pinStore.detailPrefetch.get(url)?.imageUrl || '').filter((url: string): boolean => !!url);
    };
    this.pinStore.prefetchedImageUrls = urls.map((url: string): string =>
      this.pinStore.detailPrefetch.get(url)?.imageUrl || '').filter((url: string): boolean => !!url);
    this.pinStore.detailPrefetch.offer(urls, captured.epoch.toString() + ':' + captured.page + ':' + session.toString() + ':' + tab,
      async (url: string, id: string, ownerCurrent: () => boolean): Promise<string> => {
        if (!ownerCurrent()) throw new Error('stale-prefetch');
        const job: PinWebNetworkJob = { id: id, epoch: captured.epoch, page: captured.page, url: url,
          method: 'GET', body: '', headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
            'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
        const pinId: string = (JSON.parse(decodeURIComponent(url.match(/[?&]data=([^&]+)/)![1])) as PinWebDetailReadData).options.id;
        const reply: PinWebNetworkReply = await this.detailReadNetwork.requestPinRead(job,
          (): PinWebNetworkContext => this.nativeNetworkContext(), 'https://www.pinterest.com/pin/' + pinId + '/', ownerCurrent);
        if (!ownerCurrent() || reply.error || reply.status !== 200) throw new Error('prefetch-unavailable');
        return reply.body;
      }, current, (id: string) => this.detailReadNetwork.cancel(id));
  }

  private isCurrentPublish(token: number, page: string): boolean {
    return this.authStatus === 'authenticated' && token === this.profileStore.publishFlowToken &&
      this.profileStore.publishFlow?.token === token && this.controller.getUrl() === page;
  }

  private pollPublish(token: number, page: string): void {
    if (!this.isCurrentPublish(token, page)) return;
    this.controller.runJavaScript('JSON.stringify(window.PinWebPublishApi.read(' + token.toString() + '))')
      .then((raw: string) => {
        if (!this.isCurrentPublish(token, page)) return;
        const value: PinWebPublishFlow = JSON.parse(this.webJsonText(raw)) as PinWebPublishFlow;
        if (!value || value.token !== token || value.page !== page || value.profile !== this.profileStore.publishFlow?.profile ||
          !Array.isArray(value.pins) || value.pins.length > 100 || !Array.isArray(value.boards) || value.boards.length > 2000 ||
          !Array.isArray(value.selectedIds) || value.selectedIds.length > 100 || value.kind !== this.profileStore.publishFlow?.kind ||
          !['website', 'photo', 'select', 'boards', 'create', 'empty', 'done'].includes(value.phase) ||
          !Number.isInteger(value.completed) || value.completed < 0 || value.completed > 100 ||
          value.pins.some((pin: PinWebCreatedPin) => !pin || typeof pin.id !== 'string' || typeof pin.imageUrl !== 'string') ||
          value.boards.some((board: PinWebOrganizeBoard) => !board || !/^\d+$/.test(board.id) || typeof board.title !== 'string')) throw new Error('invalid');
        value.loading = value.loading || this.profileStore.publishPicking;
        this.profileStore.publishFlow = value;
        if (value.phase === 'done') {
          const completed: number = value.completed;
          const boardOnly: boolean = value.kind === 'board';
          this.closePublishFlow();
          if (completed > 0) {
            this.showMessage(boardOnly ? '图板已创建' : '已发布 ' + completed.toString() + ' 张 Pin 图'); }
          return;
        }
        if (value.phase === 'photo' && !value.loading && !value.error && !this.profileStore.publishPicking) {
          this.pickPublishPhotos(token, page);
        }
        setTimeout(() => this.pollPublish(token, page), value.loading || value.busy ? 250 : 500);
      }).catch(() => {
        if (!this.isCurrentPublish(token, page)) return;
        const flow: PinWebPublishFlow = this.profileStore.publishFlow!;
        flow.uncertain = flow.busy; flow.busy = false; flow.loading = false;
        flow.error = flow.uncertain ? '操作结果未确认，请关闭后刷新核对，勿重复提交' : '发布状态读取失败，请返回重试';
        this.profileStore.publishFlow = JSON.parse(JSON.stringify(flow)) as PinWebPublishFlow;
      });
  }

  private closePublishFlow(force: boolean = false): void {
    const flow: PinWebPublishFlow | undefined = this.profileStore.publishFlow;
    if (!flow && !this.profileStore.publishPicking) return;
    if (!force && (flow?.busy || this.profileStore.publishPicking)) return;
    this.profileStore.publishFlowToken++;
    this.profileStore.publishFlow = undefined;
    this.profileStore.publishPicking = false;
    this.nativeChildBackUntil = Date.now() + 300;
    this.syncFloatingTabsMotion();
    if (flow && (flow.completed > 0 || flow.uncertain)) {
      this.profileStore.profileCache.clear();
      if (!force) this.refreshProfile();
    }
    if (flow) this.controller.runJavaScript('window.PinWebPublishApi && window.PinWebPublishApi.action(' + flow.token.toString() + ',"close","",false)').catch(() => {});
  }

  private publishFlowAction(action: string, value: string = '', secret: boolean = false): void {
    const flow: PinWebPublishFlow | undefined = this.profileStore.publishFlow;
    if (!flow || this.profileStore.publishPicking || !this.isCurrentPublish(flow.token, flow.page)) return;
    if (action === 'close' || action === 'next' && flow.selectedIds.length === 0) { this.closePublishFlow(); return; }
    if (action === 'pickPhoto') { this.pickPublishPhotos(flow.token, flow.page); return; }
    if (flow.busy || flow.loading || flow.uncertain) return;
    const token: number = flow.token, page: string = flow.page;
    if (['move', 'create'].includes(action)) { flow.busy = true;
      this.profileStore.publishFlow = JSON.parse(JSON.stringify(flow)) as PinWebPublishFlow; }
    this.controller.runJavaScript('window.PinWebPublishApi.action(' + token.toString() + ',' + JSON.stringify(action) + ',' +
      JSON.stringify(value) + ',' + secret.toString() + ')').catch(() => {
        if (this.isCurrentPublish(token, page)) {
          flow.busy = false; flow.uncertain = ['move', 'create'].includes(action);
          flow.error = flow.uncertain ? '操作结果未确认，请关闭后刷新核对，勿重复提交' : '操作不可用，请返回重试';
          this.profileStore.publishFlow = JSON.parse(JSON.stringify(flow)) as PinWebPublishFlow;
        }
      });
  }

  private async pickPublishPhotos(token: number, page: string): Promise<void> {
    if (!this.isCurrentPublish(token, page) || this.profileStore.publishPicking) return;
    this.profileStore.publishPicking = true;
    try {
      const uris: string[] = await pickPublishPhotoUris();
      if (!this.isCurrentPublish(token, page)) return;
      if (!uris.length) { this.profileStore.publishPicking = false; this.closePublishFlow(); return; }
      for (const uri of uris) {
        if (!this.isCurrentPublish(token, page)) return;
        const photo: PinWebPublishPhoto = await readPublishPhoto(uri);
        for (let offset: number = 0; offset < photo.data.length; offset += 60000) {
          if (!this.isCurrentPublish(token, page)) return;
          const chunk: string = photo.data.slice(offset, offset + 60000);
          const result: string = await this.controller.runJavaScript('window.PinWebPublishApi.photoChunk(' + token.toString() + ',' +
            JSON.stringify(chunk) + ',' + JSON.stringify(photo.uri) + ',' + (offset + 60000 >= photo.data.length).toString() + ')');
          if (result !== 'true' && result !== '"true"') throw new Error('图片传输未完成');
        }
      }
    } catch (error) {
      if (this.isCurrentPublish(token, page)) {
        this.profileStore.publishPicking = false;
        this.closePublishFlow();
        this.showMessage((error as Error).message || '图片选择未完成，请重试');
      }
    } finally { if (token === this.profileStore.publishFlowToken) this.profileStore.publishPicking = false; }
  }

  private async refreshProfilePublish(): Promise<void> {
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || this.activeSheetKind !== 'publish') return;
    this.profileStore.publishLoading = true;
    this.profileStore.publishOptions = [];
    try {
      await this.controller.runJavaScript('window.PinWebProfilePublishClose && ' +
        'window.PinWebProfilePublishClose(' + profile.session.toString() + ',' +
        JSON.stringify(profile.profileUrl) + ')');
      const result: string = await this.controller.runJavaScript('window.PinWebProfilePublishDiscover && ' +
        'window.PinWebProfilePublishDiscover(' + profile.session.toString() + ',' +
        JSON.stringify(profile.profileUrl) + ')');
      if (result === 'true' || result === '"true"') return;
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: publish options retry unavailable');
    }
    this.profileStore.publishLoading = false;
  }

  private finishProfilePull(): void {
    this.profileStore.profilePullRefreshing = false;
    this.profileStore.profilePullToken++;
  }

  private refreshProfile(pull: boolean = false): void {
    if (this.nativeRootOnly && this.prepareRootPageRead(3)) return;
    if (this.profileStore.profilePullRefreshing) return;
    if (pull && (!this.profileStore.profile || this.profileStore.profileSwitching ||
        !this.profileStore.profileActionsReady && !this.profileStore.profileError && !this.profileStore.profile.contentError)) return;
    if (pull && this.profileStore.profile) this.profileStore.profileCache.put(this.profileStore.profile, this.profileStore.profileScrollOffset);
    else this.profileStore.profileCache.clear();
    this.profileStore.profileActionsReady = false;
    this.profileStore.profileError = '';
    if (!this.currentProfileUrl()) {
      this.requestRootPage(3);
      return;
    }
    if (pull) {
      this.profileStore.profilePullRefreshing = true;
      const token: number = ++this.profileStore.profilePullToken;
      const page: string = this.currentProfileUrl();
      setTimeout(() => {
        if (token !== this.profileStore.profilePullToken || !this.profileStore.profilePullRefreshing || this.currentProfileUrl() !== page) return;
        this.finishProfilePull();
        this.profileStore.profileError = '刷新超时，请重试';
      }, 20000);
    }
    if (!this.profileStore.profile && !this.profileStore.profileLoading) this.expectProfile();
    this.controller.runJavaScript('window.PinWebProfileRefresh && window.PinWebProfileRefresh(' + pull.toString() + ')')
      .catch(() => {
        this.finishProfilePull();
        this.profileStore.profileLoading = false;
        this.profileStore.profileError = '无法读取当前 Pinterest 资料页';
      });
  }

  private loadMoreProfile(): void {
    if (this.profileStore.profileActionsReady === false) return;
    const profile: PinWebProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile) return;
    this.controller.runJavaScript('window.PinWebProfileLoadMore && ' +
      'window.PinWebProfileLoadMore(' + profile.session.toString() + ',' + JSON.stringify(profile.profileUrl) + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: profile content loading unavailable'));
  }

  private async returnFromProfileWebFlow(): Promise<void> {
    await this.handleBack();
    if (this.profileStore.profile && this.currentProfileUrl() === this.profileStore.profile.profileUrl) {
      this.profileStore.profileWebFlow = false;
      this.controller.runJavaScript('window.PinWebProfileResume && window.PinWebProfileResume()')
        .catch(() => PinWebRuntimeLog.warn('PinWeb: could not refresh profile'));
    }
  }

  private clearDetail(preserveRead: boolean = false, localOnly: boolean = false): void {
    this.detailDocumentBinding = '';
    if (this.detailDocumentProbeTimer !== -1) this.pageTasks.cancelTimeout(this.detailDocumentProbeTimer);
    this.detailDocumentProbeTimer = -1;
    this.pinStore.detailPresentationOnly = false; this.pinStore.detailPreparing = false;
    this.detailRequestOwners.clear();
    this.detailJourney.close();
    if (this.detailImageTimer !== -1) this.pageTasks.cancelTimeout(this.detailImageTimer);
    this.detailImageTimer = -1; this.detailImageBinding = ''; this.detailImageSignal = '';
    this.detailImageLoadedUrl = ''; this.detailImageFailedUrl = '';
    this.sharedDetailRequestId = '';
    if (!preserveRead) { this.pinStore.detailPrefetch.pause(); this.detailReadNetwork.invalidate(); this.openingRelated = undefined; }
    this.closeImageLayer(localOnly);
    this.dismissPostSnack();
    this.pinStore.saveUndoPin = ''; this.pinStore.saveUndoId = '';
    if (localOnly) {
      this.pinStore.editToken++;
      this.pinStore.saveToken++;
      this.pinStore.commentToken++;
      this.showNativeSheet = false;
      this.activeSheetKind = '';
    } else {
      if (this.activeSheetKind === 'edit') this.dismissEditPin(true);
      if (this.activeSheetKind === 'save') this.dismissApiBoards();
      if (this.activeSheetKind === 'comments') this.dismissApiComments();
    }
    this.pinStore.feedbackUndoPin = '';
    this.pinStore.feedbackUndoBusy = false;
    this.pinStore.detailApiError = '';
    this.pinStore.detailApiRetryable = true;
    this.pinStore.detailMediaUnsupported = false;
    this.pinStore.detailOpeningPin = '';
    this.pinStore.detailOpeningToken++;
    this.pinStore.detail = undefined;
    this.pinStore.detailActionsReady = false;
    this.pinStore.detailWebFlow = false;
    this.pendingDetailLike = undefined;
    this.pinStore.detailSession = 0;
    this.pinStore.detailPin = '';
    this.pinStore.detailImageFailedPin = '';
    this.pinStore.detailScrollOffset = 0;
  }

  private supersedeRootPreparationForDetail(): void {
    this.tabRequestToken++; this.pageBackToken++; this.homeRecoveryToken++;
    this.rootReadToken = -1; this.rootReadAddress = ''; this.rootReadStartedAt = 0;
    this.pendingWebTab = -1; this.retainedRootTabPending = -1; this.retainedRootTabAddress = '';
    this.retainedHomeDocumentPending = false;
    PinWebRuntimeLog.info('DetailNavigation: root preparation superseded');
  }

  private protectedDetailAddress(): string {
    if (this.authStatus !== 'authenticated' || this.nativeBackTarget || this.nativeRootOnly ||
        this.detailReturnedToRoot || this.pinStore.detailWebFlow) return '';
    return this.pinStore.detailOpeningPin || this.pinStore.detail?.pinUrl || '';
  }

  private ignoreSupersededDetailDocument(url: string): boolean {
    const expected: string = this.protectedDetailAddress();
    if (!expected || isPinterestAuthRoute(url) || url === expected) return false;
    // Ignore stale presentation callbacks, but invalidate live controls if the
    // hidden document really changed. A cached display never authorizes writes.
    let actual: string = '';
    try { actual = this.controller.getUrl(); } catch (_) {}
    if (actual === url && this.pinStore.detailActionsReady) {
      this.authEpoch++; this.nativeNetwork.invalidate();
      this.pinStore.detailActionsReady = false;
      this.detailDocumentBinding = '';
      if (!this.pinStore.detailOpeningPin) this.pinStore.detailPresentationOnly = true;
      this.detailJourney.mark('document.superseded.actions.invalidated');
    }
    PinWebRuntimeLog.info('DetailNavigation: obsolete document ignored');
    return true;
  }

  private beginDetailOpening(pinUrl: string, returnUrl: string = ''): void {
    this.detailReturnJourney?.close();
    const clickAt: number = this.detailClickedAt > 0 && Date.now() - this.detailClickedAt < 20000 ? this.detailClickedAt : Date.now();
    this.detailClickedAt = 0;
    this.closeImageLayer();
    if (!this.pinIdentity(pinUrl)) return;
    this.clearRootTabGuard('detail-open');
    if (this.pinStore.detailOpeningPin === pinUrl) return;
    this.supersedeRootPreparationForDetail();
    const identity: string = this.pinIdentity(pinUrl);
    if (returnUrl && this.detailReturnReadPin !== identity) this.detailReturnReadPin = '';
    if (returnUrl) this.pinStore.rememberDetailOrigin(identity, returnUrl);
    else if (!this.pinStore.detailOrigin(identity)) {
      this.pinStore.rememberDetailOrigin(identity, this.pinStore.detailReturnUrl || PINTEREST_URL);
    }
    this.pinStore.detailReturnUrl = this.pinStore.detailOrigin(identity) || PINTEREST_URL;
    const card: PinWebHomePin | undefined = this.homeStore.home?.pins.find((item: PinWebHomePin): boolean => item.pinUrl === pinUrl);
    const relatedCard: PinWebRelatedPin | undefined = this.pinStore.detail?.related.find((item: PinWebRelatedPin): boolean => item.pinUrl === pinUrl);
    if (this.detailPrefetchTimer !== -1) this.pageTasks.cancelTimeout(this.detailPrefetchTimer);
    this.detailPrefetchTimer = -1;
    this.pinStore.detailPrefetch.cancelExcept(pinUrl);
    if (this.nativeBackTarget) {
      // Commit the visible native parent, then supersede its background return.
      this.pageHistory.visit(this.nativeBackTarget, 'load');
      this.pageHistory.cancelBack();
      this.nativeBackTarget = '';
      PinWebRuntimeLog.info('PinWebReturn: reopen superseded pending return');
    }
    // Record the native child immediately, before ArkWeb has a completed history entry.
    this.pageHistory.visit(pinUrl, 'push');
    this.clearDetail(true);
    this.pinStore.detailOpeningPin = pinUrl;
    this.pinStore.detailPin = pinUrl;
    this.restoreCachedDetail(pinUrl);
    const token: number = ++this.pinStore.detailOpeningToken;
    this.detailOpenedAt = clickAt;
    this.detailJourney.begin(token, clickAt);
    this.detailJourney.mark('opening.snapshot');
    this.detailCommentsMeasured = false;
    this.detailRelatedMeasured = false;
    PinWebRuntimeLog.info('DetailTrace: open openId=' + token.toString());
    if (PIN_DETAIL_API_ENABLED && !this.pinStore.detail) {
      const imageUrl: string = card?.imageUrl || relatedCard?.imageUrl || '';
      this.pinStore.detail = {
        kind: 'opening', dataSource: 'api', session: 0, pinUrl: pinUrl,
        imageUrl: imageUrl, imageWidth: card?.imageWidth || relatedCard?.imageWidth || 0,
        imageHeight: card?.imageHeight || relatedCard?.imageHeight || 0,
        title: card?.title || relatedCard?.title || '', description: '', creator: '', creatorAvatar: '', sourceLabel: '',
        actions: [], related: []
      };
    }
    if (PIN_DETAIL_API_ENABLED && PIN_NATIVE_NETWORK_ENABLED) this.startOpeningDetailRead(pinUrl, token);
    if (PIN_DETAIL_API_ENABLED && PIN_NATIVE_NETWORK_ENABLED) this.probeDetailDocument(pinUrl, token, 0);
    setTimeout(() => {
      if (token !== this.pinStore.detailOpeningToken) return;
      if (PIN_DETAIL_API_ENABLED) {
        // A restored detail cache is already a valid presentation. Do not
        // replace it with a retry screen while the background confirmation
        // request is slow or the Web history entry is missing.
        const hasCachedPresentation: boolean = !!this.pinStore.detail &&
          this.pinIdentity(this.pinStore.detail.pinUrl) === this.pinIdentity(pinUrl) &&
          (this.pinStore.detail.kind === 'cached' || this.pinStore.detail.relatedRetained === true ||
            this.pinStore.detail.imageStageReady === true);
        if (!this.pinStore.detailActionsReady && !hasCachedPresentation) {
          this.pinStore.detailApiError = '帖子加载超时，请重试';
        }
      } else this.pinStore.detailOpeningPin = '';
    }, 12000);
  }

  private restoreCachedDetail(pinUrl: string): boolean {
    const identity: string = this.pinIdentity(pinUrl);
    if (!identity || this.pinIdentity(this.pinStore.detailImageFailedPin) === identity) return false;
    const cached = this.pinStore.detailCache.get(identity);
    if (!cached || (PIN_DETAIL_API_ENABLED && cached.detail.dataSource !== 'api')) {
      const prefetched: PinWebDetailSnapshot | undefined = this.pinStore.detailPrefetch.get(pinUrl);
      if (!prefetched || !PIN_DETAIL_API_ENABLED) return false;
      this.pinStore.detailSession = 0;
      this.pinStore.detailPin = pinUrl;
      this.pinStore.detailScrollOffset = 0;
      this.pinStore.detailActionsReady = false;
      this.pinStore.detail = this.pinStore.confirmedSaves.apply(identity, prefetched);
      PinWebRuntimeLog.info('DetailPrefetch: cache hit on open');
      return true;
    }
    this.pinStore.detailSession = 0;
    this.pinStore.detailPin = cached.detail.pinUrl;
    this.pinStore.detailScrollOffset = cached.scrollOffset;
    this.pinStore.detailActionsReady = false;
    this.pinStore.detailWebFlow = false;
    this.pendingDetailLike = undefined;
    this.pinStore.detail = this.pinStore.confirmedSaves.apply(identity, cached.detail);
    return true;
  }

  private saveDetailScrollPosition(pinUrl: string, offset: number): void {
    const identity: string = this.pinIdentity(pinUrl);
    if (!identity || identity !== this.pinIdentity(this.pinStore.detailPin)) return;
    this.pinStore.detailScrollOffset = Math.max(0, offset);
    this.pinStore.detailCache.updateScrollOffset(identity, this.pinStore.detailScrollOffset);
  }

  private adjustedDetailCount(value: string, delta: number): string {
    const digits: string = value.replace(/,/g, '');
    if (!/^\d+$/.test(digits)) return value;
    const updated: number = Math.max(0, Number(digits) + delta);
    return updated.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  private withDetailLike(detail: PinWebDetailSnapshot, id: string,
    selected: boolean, countText: string): PinWebDetailSnapshot {
    const actions: PinWebDetailAction[] = detail.actions.map((item: PinWebDetailAction): PinWebDetailAction => {
      if (item.id !== id) return item;
      return { id: item.id, kind: item.kind, label: item.label,
        countText: countText, enabled: item.enabled, selected: selected };
    });
    return {
      kind: detail.kind, session: detail.session, pinUrl: detail.pinUrl,
      aiLabel: detail.aiLabel, originalImageUrl: detail.originalImageUrl,
      imageUrl: detail.imageUrl, imageWidth: detail.imageWidth, imageHeight: detail.imageHeight,
      title: detail.title, description: detail.description, creator: detail.creator,
      creatorAvatar: detail.creatorAvatar, creatorUrl: detail.creatorUrl, sourceLabel: detail.sourceLabel, sourceUrl: detail.sourceUrl,
      actions: actions, related: detail.related, dataSource: detail.dataSource,
      relatedLoading: detail.relatedLoading, relatedError: detail.relatedError,
      relatedEnded: detail.relatedEnded, commentPreview: detail.commentPreview,
      commentLoading: detail.commentLoading, commentError: detail.commentError, commentsAvailable: detail.commentsAvailable,
      commentEmpty: detail.commentEmpty, imageStageReady: detail.imageStageReady, imageLoaded: detail.imageLoaded, interactionsSettled: detail.interactionsSettled,
      mediaLoading: detail.mediaLoading, mediaError: detail.mediaError, mediaKind: detail.mediaKind,
      carousel: detail.carousel, isVideo: detail.isVideo, video: detail.video, videoError: detail.videoError
    };
  }

  private updateSearchPinTitle(pinUrl: string, value: string): void {
    const identity: string = this.pinIdentity(pinUrl);
    const title: string = (value || '').trim().replace(/\s+/g, ' ').slice(0, 180);
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!identity || !this.hasMeaningfulSearchPinTitle(title)) return;
    this.searchStore.knownSearchPinTitles.set(identity, title);
    if (this.searchStore.knownSearchPinTitles.size > 100) {
      const oldest: string = this.searchStore.knownSearchPinTitles.keys().next().value;
      this.searchStore.knownSearchPinTitles.delete(oldest);
    }
    if (!search) return;
    let changed: boolean = false;
    const results: PinWebSearchResult[] = search.results.map((item: PinWebSearchResult): PinWebSearchResult => {
      if (item.kind !== 'pin' || this.pinIdentity(item.targetUrl) !== identity || item.title === title) return item;
      changed = true;
      return { id: item.id, kind: item.kind, title: title, subtitle: item.subtitle,
        targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
        imageHeight: item.imageHeight, video: item.video, enabled: item.enabled };
    });
    if (!changed) return;
    this.searchStore.search = { kind: search.kind, session: search.session, pageKey: search.pageKey,
      query: search.query, placeholder: search.placeholder,
      selectedCategory: search.selectedCategory, categories: search.categories,
      suggestions: search.suggestions, heroes: search.heroes, ideaSections: search.ideaSections,
      results: results };
    if (this.searchStore.retainedSearch?.pageKey === search.pageKey) this.searchStore.retainedSearch = this.searchStore.search;
  }

  private updateHomePinTitle(pinUrl: string, value: string): void {
    const identity: string = this.pinIdentity(pinUrl);
    const title: string = (value || '').trim().replace(/\s+/g, ' ').slice(0, 160);
    if (!identity || !this.hasMeaningfulSearchPinTitle(title)) return;
    const saved: PinWebHomeSnapshot | undefined = this.homeStore.cachedHome;
    if (!saved || saved.dataSource === 'api') return;
    const pins: PinWebHomePin[] = saved.pins.map((pin: PinWebHomePin): PinWebHomePin => {
      return { id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
        imageWidth: pin.imageWidth, imageHeight: pin.imageHeight, video: pin.video,
        title: this.pinIdentity(pin.pinUrl) === identity ? title : pin.title, hasMore: pin.hasMore, saved: pin.saved };
    });
    this.homeStore.cachedHome = { kind: saved.kind, session: saved.session, pageKey: saved.pageKey,
      selectedTab: saved.selectedTab, tabs: saved.tabs, board: saved.board, pins: pins,
      dataSource: saved.dataSource, loadingMore: saved.loadingMore, refreshing: saved.refreshing,
      endReached: saved.endReached, sourceError: saved.sourceError };
    if (this.homeStore.home?.pageKey === saved.pageKey && this.homeStore.home.selectedTab === saved.selectedTab) {
      this.homeStore.home = this.homeStore.cachedHome;
    }
  }

  private updateDetail(value: string): void {
    if (this.pinStore.detailPresentationOnly) return;
    if (this.nativeRootOnly || this.detailReturnedToRoot) return;
    if (this.nativeBackTarget) {
      try {
        if (this.pageHistory.key(this.controller.getUrl()) !== this.pageHistory.key(this.nativeBackTarget)) return;
      } catch (_) { return; }
    }
    try {
      const message: PinWebDetailSnapshot = JSON.parse(value) as PinWebDetailSnapshot;
      if (!message || typeof message.session !== 'number' || typeof message.pinUrl !== 'string') return;
      if (message.kind === 'timing') {
        if (message.session === this.pinStore.detailSession && message.pinUrl === this.pinStore.detailPin &&
            message.pinUrl === this.currentPinUrl() && typeof message.timingEvent === 'string' &&
            /^(comments|related|base|interactions)\.[a-z.]{1,64}$/.test(message.timingEvent) && typeof message.timingDuration === 'number' &&
            message.timingDuration >= 0 && message.timingDuration <= 60000)
          this.detailJourney.mark(message.timingEvent, false, message.timingDuration);
        return;
      }
      if (this.pinStore.detailOpeningPin &&
          this.pinIdentity(message.pinUrl) !== this.pinIdentity(this.pinStore.detailOpeningPin)) return;
      if (PIN_DETAIL_API_ENABLED && message.kind === 'apiPending') {
        if (this.pinIdentity(message.pinUrl) !== this.pinIdentity(this.currentPinUrl()) ||
            message.session < this.pinStore.detailSession) return;
        this.pinStore.detailSession = message.session;
        this.nativePinRoute = this.pinIdentity(message.pinUrl);
        this.pinStore.detailPin = message.pinUrl;
        if (!this.pinStore.detail) this.pinStore.detailOpeningPin = message.pinUrl;
        this.pinStore.detailApiError = message.error || '';
        this.pinStore.detailApiRetryable = message.retryable !== false;
        this.pinStore.detailMediaUnsupported = message.mediaUnsupported === true;
        return;
      }
      if (message.kind === 'flowClosed') {
        if (message.session === this.pinStore.detailSession && message.pinUrl === this.pinStore.detailPin) {
          this.pinStore.detailWebFlow = false;
        }
        return;
      }
      if (message.kind === 'actionUnchanged') {
        if (message.session === this.pinStore.detailSession && message.pinUrl === this.pinStore.detailPin) {
          this.pendingDetailLike = undefined;
          if (PIN_DETAIL_API_ENABLED) {
            this.showMessage(message.error || '尚未确认点赞生效，请重试');
            this.controller.runJavaScript('window.PinWebDetailRefresh && window.PinWebDetailRefresh()')
              .catch(() => PinWebRuntimeLog.warn('PinWeb: detail refresh unavailable'));
            return;
          }
          this.pinStore.detailImageFailedPin = message.pinUrl;
          this.pinStore.detail = undefined;
          this.pinStore.detailActionsReady = false;
          this.showMessage('点赞未生效，已切回网页详情');
        }
        return;
      }
      if (message.kind === 'unsupported') {
        const identity: string = this.pinIdentity(message.pinUrl);
        if (identity && identity === this.pinIdentity(this.currentPinUrl())) {
          if (this.pinStore.detail && this.pinIdentity(this.pinStore.detail.pinUrl) === identity && !this.pinStore.detailActionsReady) {
            this.pinStore.detailSession = Math.max(this.pinStore.detailSession, message.session);
            this.pinStore.detailPin = message.pinUrl;
            return;
          }
          if (this.restoreCachedDetail(message.pinUrl)) {
            this.pinStore.detailSession = message.session;
            return;
          }
        }
      }
      if (message.kind === 'closed' || message.kind === 'unsupported') {
        if (message.kind === 'closed' && this.currentPinUrl()) return;
        if (!message.pinUrl || this.pinIdentity(message.pinUrl) === this.pinIdentity(this.currentPinUrl())) {
          if (message.pinUrl && (this.profileStore.profile || this.profileStore.profileLoading || this.profileStore.profileError)) this.clearProfile();
          this.pendingDetailLike = undefined;
          if (this.pinStore.detailPin !== message.pinUrl) this.pinStore.detailImageFailedPin = '';
          this.pinStore.detail = undefined;
          this.pinStore.detailActionsReady = false;
          this.pinStore.detailWebFlow = false;
          this.pinStore.detailPin = message.pinUrl;
          this.pinStore.detailSession = message.session;
        }
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') || !this.pinIdentity(message.pinUrl)) return;
      if (PIN_DETAIL_API_ENABLED && message.dataSource !== 'api') return;
      if (this.pinIdentity(message.pinUrl) !== this.pinIdentity(this.currentPinUrl())) {
        setTimeout(() => {
          this.controller.runJavaScript('window.PinWebDetailRefresh && window.PinWebDetailRefresh()')
            .catch(() => PinWebRuntimeLog.warn('PinWeb: detail refresh unavailable'));
        }, 250);
        return;
      }
      if (message.session < this.pinStore.detailSession || !message.imageUrl ||
          !/^https:\/\//i.test(message.imageUrl) ||
          !Array.isArray(message.actions) || !Array.isArray(message.related)) return;
      this.nativePinRoute = this.pinIdentity(message.pinUrl);
      if (this.profileStore.profile || this.profileStore.profileLoading || this.profileStore.profileError) this.clearProfile();
      if (this.pinStore.detailPin && this.pinIdentity(message.pinUrl) !== this.pinIdentity(this.pinStore.detailPin)) {
        this.pendingDetailLike = undefined;
        this.pinStore.detailWebFlow = false;
        this.pinStore.detailImageFailedPin = '';
      }
      this.pinStore.detailSession = message.session;
      this.pinStore.detailPin = message.pinUrl;
      const actions: PinWebDetailAction[] = message.actions.filter((item: PinWebDetailAction): boolean =>
        !!item.id && !!item.kind && !!item.label);
      const related: PinWebRelatedPin[] = message.related.filter((item: PinWebRelatedPin): boolean =>
        !!item.id && !!item.pinUrl && !!item.imageUrl);
      const sourceUrl: string = this.externalSourceUrl(message.sourceUrl || '');
      let nextDetail: PinWebDetailSnapshot = {
        kind: 'state', session: message.session, pinUrl: message.pinUrl,
        aiLabel: message.aiLabel === '由 AI 修改' ? message.aiLabel : '',
        originalImageUrl: /^https:\/\/i\.pinimg\.com\//.test(message.originalImageUrl || '') ? message.originalImageUrl : message.imageUrl,
        imageUrl: message.imageUrl, imageWidth: message.imageWidth || 0,
        imageHeight: message.imageHeight || 0, title: message.title || '',
        description: message.description || '', creator: message.creator || '',
        creatorAvatar: message.creatorAvatar || '', creatorUrl: this.profileUrlFromAddress(message.creatorUrl || ''),
        sourceLabel: sourceUrl ? (message.sourceLabel || '') : '', sourceUrl: sourceUrl || undefined,
        actions: actions, related: related, dataSource: message.dataSource,
        relatedLoading: message.relatedLoading, relatedError: message.relatedError,
        relatedEnded: message.relatedEnded, commentPreview: message.commentPreview,
        commentLoading: message.commentLoading === true, commentError: message.commentError || '',
        commentsAvailable: message.commentsAvailable === true,
        commentEmpty: message.commentEmpty === true, imageStageReady: message.imageStageReady === true, imageLoaded: message.imageLoaded === true,
        interactionsSettled: message.interactionsSettled === true,
        mediaLoading: message.mediaLoading === true, mediaError: message.mediaError || '',
        mediaKind: message.mediaKind === 'video' || message.mediaKind === 'carousel' ? message.mediaKind : '',
        carousel: message.carousel && message.carousel.pinId === this.pinIdentity(message.pinUrl) &&
          Array.isArray(message.carousel.items) && message.carousel.items.length > 0 &&
          message.carousel.items.every((item): boolean => !!item.id &&
            /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(item.imageUrl) &&
            item.imageWidth > 0 && item.imageHeight > 0) ? message.carousel : undefined,
        isVideo: message.isVideo === true, videoError: message.videoError || '',
        video: message.video && message.video.pinId === this.pinIdentity(message.pinUrl) &&
          Array.isArray(message.video.sources) && message.video.sources.length > 0 &&
          message.video.sources.every((source): boolean => typeof source.url === 'string' &&
            /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/videos\//i.test(source.url) &&
            (source.kind === 'hls' || source.kind === 'mp4')) ? message.video : undefined
      };
      nextDetail = retainDetailPresentation(nextDetail, this.pinStore.detail);
      const pending: PendingDetailLike | undefined = this.pendingDetailLike;
      if (pending) {
        if (pending.session !== message.session || pending.pinUrl !== message.pinUrl) {
          this.pendingDetailLike = undefined;
        } else {
          const like: PinWebDetailAction | undefined = actions.find((item: PinWebDetailAction): boolean =>
            item.id === pending.id && item.kind === 'like');
          if (like && like.selected === pending.selected) {
            this.pendingDetailLike = undefined;
          } else if (like) {
            nextDetail = this.withDetailLike(nextDetail, pending.id, pending.selected, pending.countText);
          } else {
            this.pendingDetailLike = undefined;
          }
        }
      }
      nextDetail.actions = this.pinStore.confirmedSaves.actions(this.pinIdentity(message.pinUrl), nextDetail.actions);
      if (PIN_DETAIL_API_ENABLED && this.detailOpenedAt > 0) {
        const timing: string = ' openId=' + this.pinStore.detailOpeningToken.toString() + ' elapsedMs=' +
          (Date.now() - this.detailOpenedAt).toString();
        if (!this.detailCommentsMeasured && !nextDetail.commentsRetained &&
            nextDetail.commentsAvailable && !nextDetail.commentLoading) {
          this.detailCommentsMeasured = true;
          PinWebRuntimeLog.info('DetailTrace: comments ' + (nextDetail.commentError ? 'failed' : 'ready') + timing);
        }
        if (!this.detailRelatedMeasured && !nextDetail.relatedRetained && !nextDetail.relatedLoading &&
            (nextDetail.relatedError || nextDetail.relatedEnded || nextDetail.related.length > 0)) {
          this.detailRelatedMeasured = true;
          PinWebRuntimeLog.info('DetailTrace: related ' + (nextDetail.relatedError ? 'failed' : 'ready') + timing +
            ' count=' + nextDetail.related.length.toString());
        }
      }
      // The native Image completion callback is the authoritative visual
      // result. Preserve it when the validated snapshot reuses the same URL;
      // the Web bridge may arrive later or be unavailable after navigation.
      if (!nextDetail.imageLoaded && this.detailImageLoadedUrl === nextDetail.imageUrl &&
          this.pinIdentity(nextDetail.pinUrl) === this.pinIdentity(this.pinStore.detailPin)) {
        nextDetail.imageStageReady = true;
        nextDetail.imageLoaded = true;
        PinWebRuntimeLog.info('DetailTrace: main image visual state reused openId=' +
          this.pinStore.detailOpeningToken.toString());
      }
      this.pinStore.detail = nextDetail;
      if (PIN_DETAIL_API_ENABLED && nextDetail.imageWidth > 0 && nextDetail.imageHeight > 0) {
        const ratio: number = nextDetail.imageHeight / nextDetail.imageWidth;
        PinWebRuntimeLog.info('DetailTrace: main image metrics openId=' +
          this.pinStore.detailOpeningToken.toString() + ' width=' + nextDetail.imageWidth.toString() +
          ' height=' + nextDetail.imageHeight.toString() + ' ratio=' + ratio.toFixed(4));
      }
      this.pinStore.detailApiError = '';
      this.pinStore.detailOpeningPin = '';
      if (!this.pinStore.detailActionsReady) PinWebRuntimeLog.info('DetailTrace: current actions ready openId=' + this.pinStore.detailOpeningToken.toString() + ' elapsedMs=' +
        (Date.now() - this.detailOpenedAt).toString());
      this.pinStore.detailActionsReady = true;
      this.detailJourney.mark('current.snapshot.committed');
      if (nextDetail.imageStageReady) {
        this.detailJourney.mark('interactions.started');
        const like: PinWebDetailAction | undefined = nextDetail.actions.find((item: PinWebDetailAction): boolean => item.kind === 'like');
        this.detailJourney.mark(like && like.countText ? 'like.count.confirmed' : 'like.count.unavailable');
        if (like?.enabled) this.detailJourney.mark('like.action.ready');
      }
      if (nextDetail.commentLoading) this.detailJourney.mark('comments.loading');
      else if (!nextDetail.commentsRetained && nextDetail.commentsAvailable) this.detailJourney.mark(nextDetail.commentError ? 'comments.failed' :
        nextDetail.commentEmpty ? 'comments.empty' : 'comments.committed');
      if (nextDetail.interactionsSettled) this.detailJourney.mark('interactions.settled');
      if (nextDetail.relatedLoading) this.detailJourney.mark('related.loading');
      else if (message.relatedError || message.relatedEnded || related.length > 0)
        this.detailJourney.mark(message.relatedError ? 'related.failed' : related.length ? 'related.committed' : 'related.empty');
      this.syncDetailImageStage();
      this.pinStore.detailCache.put(this.pinIdentity(message.pinUrl), nextDetail, this.pinStore.detailScrollOffset);
      this.pinStore.detailPrefetch.remove(message.pinUrl);
      this.updateSearchPinTitle(message.pinUrl, nextDetail.title);
      this.updateHomePinTitle(message.pinUrl, nextDetail.title);
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid Pin detail state');
    }
  }

  private closeImageLayer(localOnly: boolean = false): void {
    this.pinStore.imageLayer = '';
    this.pinStore.visualToken++;
    if (localOnly) return;
    this.controller.runJavaScript('window.PinWebVisualSearchApi && window.PinWebVisualSearchApi.close()').catch(() => {});
  }

  private async searchImage(crop: PinWebImageCrop, append: boolean, first: boolean): Promise<void> {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!PIN_VISUAL_SEARCH_API_ENABLED || !detail || this.pinStore.imageLayer !== 'search' || !this.pinStore.detailActionsReady ||
        append && (this.pinStore.visualResult.loading || this.pinStore.visualResult.ended)) return;
    const pin: string = detail.pinUrl;
    const epoch: number = this.authEpoch;
    const token: number = ++this.pinStore.visualToken;
    const current = (): boolean => token === this.pinStore.visualToken && this.authEpoch === epoch &&
      this.authStatus === 'authenticated' && this.pinStore.imageLayer === 'search' && this.pinStore.detail?.pinUrl === pin;
    this.pinStore.visualResult = { pin: pin, loading: true, error: '', ended: false,
      items: append ? this.pinStore.visualResult.items : [] };
    try {
      const started: string = await this.controller.runJavaScript(useNativeTransport(PIN_VISUAL_SEARCH_API_SCRIPT) +
        'window.PinWebVisualSearchApi.start(' + JSON.stringify(pin) + ',' + JSON.stringify(crop) + ',' + append + ',' + first + ')');
      if (!current()) return;
      if (started !== 'true' && started !== '"true"') throw new Error('Unavailable');
      const until: number = Date.now() + 18000;
      const poll = async (): Promise<void> => {
        if (!current()) return;
        try {
          const value: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebVisualSearchApi.read(' + JSON.stringify(pin) + '))');
          if (!current()) return;
          const result: PinWebVisualResult | null = JSON.parse(this.webJsonText(value)) as PinWebVisualResult | null;
          if (!result || result.pin !== pin || !Array.isArray(result.items) || result.items.length > 400) throw new Error('Invalid');
          this.pinStore.visualResult = result;
          if (!result.loading) return;
          if (Date.now() > until) throw new Error('Timeout');
          setTimeout(() => { poll(); }, 180);
        } catch (_) {
          if (current()) this.pinStore.visualResult = { pin: pin, loading: false, error: '图片搜索未完成，请重试',
            ended: false, items: this.pinStore.visualResult.items };
        }
      };
      poll();
    } catch (_) {
      if (current()) this.pinStore.visualResult = { pin: pin, loading: false, error: '图片搜索暂不可用，请重试', ended: false, items: [] };
    }
  }

  private async openImageRelated(id: string): Promise<void> {
    if (this.rejectOfflineAction('related pin')) return;
    if (this.authStatus !== 'authenticated' || this.businessSuspended ||
        !this.pinStore.videoForeground || this.pinStore.detailPreparing) return;
    if (this.pinStore.detailPresentationOnly) {
      const parent: string = this.pinStore.detail?.pinUrl || '';
      const target: string = this.pinStore.detail?.related.find((item: PinWebRelatedPin): boolean => item.id === id)?.pinUrl || '';
      // A retained card supplies a validated read-only route, not a live control ID.
      // Present the target card before its own confirmation; do not reload the parent.
      if (!/^https:\/\/www\.pinterest\.com\/pin\/\d+\/$/.test(parent) ||
          !/^https:\/\/www\.pinterest\.com\/pin\/\d+\/$/.test(target) ||
          this.pinStore.detailPin !== parent || target === parent || this.pinStore.detailOpeningPin === target) return;
      this.beginDetailOpening(target, parent);
      this.detailJourney.mark('related.cached.route.opened');
      this.controller.loadUrl(target); return;
    }
    if (this.authStatus !== 'authenticated' || !this.pinStore.detailActionsReady) return;
    const result: PinWebVisualResult = this.pinStore.visualResult;
    const item: PinWebRelatedPin | undefined = result.items.find((p: PinWebRelatedPin): boolean => p.id === id);
    if (!item || result.pin !== this.pinStore.detail?.pinUrl) { this.openRelatedDetail(id); return; }
    if (!/^https:\/\/www\.pinterest\.com\/pin\/\d+\/$/.test(item.pinUrl)) return;
    this.pinStore.detailReturnUrl = result.pin;
    this.beginDetailOpening(item.pinUrl, result.pin);
    this.controller.loadUrl(item.pinUrl);
  }

  private async downloadViewerImage(): Promise<void> {
    if (this.rejectOfflineAction('photo download')) return;
    const pin: string = this.pinStore.detail?.pinUrl || '';
    if (!pin || this.pinStore.imageLayer !== 'zoom' || !this.pinStore.detailActionsReady) {
      PinWebRuntimeLog.info('ActionGate: photo download blocked reason=detail-not-ready');
      return;
    }
    PinWebRuntimeLog.info('PhotoDownload: requested');
    try {
      const value: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && window.PinWebPostApi.downloadUrl(' + JSON.stringify(pin) + '))');
      if (this.pinStore.detail?.pinUrl !== pin || this.pinStore.imageLayer !== 'zoom') return;
      const url: string = JSON.parse(this.webJsonText(value)) as string;
      if (/^https:\/\/i\.pinimg\.com\//.test(url)) {
        this.controller.startDownload(url);
        PinWebRuntimeLog.info('PhotoDownload: dispatched');
      } else {
        PinWebRuntimeLog.warn('PhotoDownload: blocked reason=invalid-media-url');
        this.showMessage('当前图片暂时无法下载');
      }
    } catch (_) {
      PinWebRuntimeLog.warn('PhotoDownload: failed reason=resolve-error');
      this.showMessage('下载未能开始，请重试');
    }
  }

  private async saveViewerImage(): Promise<void> {
    if (this.rejectOfflineAction('save')) return;
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    const action: PinWebDetailAction | undefined = detail?.actions.find((a: PinWebDetailAction): boolean => a.kind === 'save');
    if (!detail || !action || !action.enabled || this.pinStore.imageLayer !== 'zoom' || !this.pinStore.detailActionsReady || this.pinStore.viewerSaveBusy) {
      PinWebRuntimeLog.info('ActionGate: save blocked reason=detail-not-ready');
      return;
    }
    if (!action.selected) { this.performDetailAction(action.id, action.kind); return; }
    const pin: string = detail.pinUrl;
    const epoch: number = this.authEpoch;
    const current = (): boolean => this.authEpoch === epoch && this.authStatus === 'authenticated' &&
      this.pinStore.imageLayer === 'zoom' && this.pinStore.detail?.pinUrl === pin;
    this.pinStore.viewerSaveBusy = true;
    try {
      const value: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi.savedRead(' + JSON.stringify(pin) + '))');
      if (!current()) return;
      const saved: PinWebSaveIdentity | null = JSON.parse(this.webJsonText(value)) as PinWebSaveIdentity | null;
      if (saved && /^\d+$/.test(saved.id)) {
        this.pinStore.saveUndoPin = pin; this.pinStore.saveUndoId = saved.id;
        await this.undoSavedPin();
        return;
      }
      // For older saved Pins, the existing edit reader verifies current-account ownership before deletion.
      await this.controller.runJavaScript('window.PinWebPostApi.editStart(' + JSON.stringify(pin) + ')');
      let sent: boolean = false;
      const until: number = Date.now() + 20000;
      while (current() && Date.now() < until) {
        const read: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi.editRead(' + JSON.stringify(pin) + '))');
        if (!current()) return;
        const result: PinWebEditPinResult | null = JSON.parse(this.webJsonText(read)) as PinWebEditPinResult | null;
        if (!result || result.error || result.uncertain) throw new Error('Unconfirmed');
        if (result.done === 'deleted') {
          this.pinStore.confirmedSaves.confirm(this.pinIdentity(pin), false);
          if (this.pinStore.detail) this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.pinIdentity(pin), this.pinStore.detail);
          this.pinStore.detailCache.remove(this.pinIdentity(pin));
          this.showMessage('已取消收藏'); return;
        }
        if (!result.loading && !result.busy && !sent) {
          sent = true;
          await this.controller.runJavaScript('window.PinWebPostApi.editPhase(' + JSON.stringify(pin) + ',"confirm") && window.PinWebPostApi.editCommit(' + JSON.stringify(pin) + ',true); true');
        }
        await new Promise<void>((resolve) => { setTimeout(resolve, 200); });
      }
      if (current()) throw new Error('Timeout');
    } catch (_) { if (current()) this.showMessage('取消收藏未确认，请重新读取后检查'); }
    finally { this.pinStore.viewerSaveBusy = false; }
  }

  private async ensureDetailActionContext(): Promise<boolean> {
    if (this.rejectOfflineAction('detail preparation')) return false;
    const pin: string = this.pinStore.detail?.pinUrl || '';
    if (!this.pinIdentity(pin) || this.authStatus !== 'authenticated' || this.pinStore.detailPreparing) return false;
    if (!this.pinStore.detailPresentationOnly) return this.pinStore.detailActionsReady;
    this.beginDetailOpening(pin);
    this.pinStore.detailPreparing = true;
    const token: number = this.pinStore.detailOpeningToken;
    this.detailJourney.mark('action.context.requested');
    try {
      this.controller.loadUrl(pin);
      for (let attempt: number = 0; attempt < 80; attempt++) {
        if (token !== this.pinStore.detailOpeningToken || this.authStatus !== 'authenticated' ||
            this.pinStore.detailPin !== pin || !this.pinStore.videoForeground) return false;
        if (this.pinStore.detailActionsReady && this.pinStore.detail?.imageStageReady &&
            !this.pinStore.detail.actionsRetained && this.currentPinUrl() === pin) {
          this.detailJourney.mark('action.context.confirmed'); return true;
        }
        if (this.pinStore.detailApiError) return false;
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 150); });
      }
      this.pinStore.detailApiError = '当前帖子状态尚未确认，请重试';
      return false;
    } catch (_) {
      if (token === this.pinStore.detailOpeningToken) this.pinStore.detailApiError = '当前帖子状态准备失败，请重试';
      return false;
    } finally {
      if (token === this.pinStore.detailOpeningToken) this.pinStore.detailPreparing = false;
    }
  }

  private async performDetailAction(id: string, kind: string): Promise<void> {
    this.traceAction('detail.action.' + kind, id);
    if (this.rejectOfflineAction('detail.' + kind)) return;
    if (this.authStatus !== 'authenticated') return;
    if (this.pinStore.detailPresentationOnly) {
      if (!await this.ensureDetailActionContext()) return;
      const fresh: PinWebDetailAction | undefined = this.pinStore.detail?.actions.find((item: PinWebDetailAction): boolean => item.kind === kind);
      if (!fresh?.enabled) return;
      id = fresh.id;
    }
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || detail.kind === 'cached' || !this.pinStore.detailActionsReady || !id ||
        this.pinIdentity(detail.pinUrl) !== this.pinIdentity(this.currentPinUrl())) return;
    if (PIN_POST_API_ENABLED && kind === 'comment') { this.openApiComments(); return; }
    if (PIN_POST_API_ENABLED && PIN_POST_EXTENSIONS_ENABLED && kind === 'save') { this.openApiBoards(); return; }
    if (PIN_POST_API_ENABLED && kind === 'share') {
      try {
        const result: string = await this.controller.runJavaScript('window.PinWebNativeShareApiOpen && ' +
          'window.PinWebNativeShareApiOpen(' + JSON.stringify(detail.pinUrl) + ')');
        if (result !== 'true' && result !== '"true"') this.showMessage('分享接口暂不可用，请重试');
      } catch (_) { this.showMessage('分享接口暂不可用，请重试'); }
      return;
    }
    if (PIN_POST_API_ENABLED && kind === 'more') { await this.openApiDetailMore(); return; }
    if (PIN_POST_API_ENABLED && kind === 'source') {
      const source: string = this.externalSourceUrl(detail.sourceUrl || '');
      if (!source) { this.showMessage('当前来源链接不可用'); return; }
      try {
        const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await context.openLink(source);
      } catch (_) { this.showMessage('无法打开来源链接，请重试'); }
      return;
    }
    if (!PIN_POST_API_ENABLED || kind !== 'like') return;
    // Only API-backed reaction or native-menu presentation may use this bridge.
    // Source links and unfinished website-only flows intentionally have no handler.
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebDetailAction && ' +
        'window.PinWebDetailAction(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' +
        JSON.stringify(id) + ')');
      if (result !== 'true' && result !== '"true"') this.showMessage('当前操作暂不可用，请重试');
    } catch (_) { this.showMessage('当前操作暂不可用，请重试'); }
  }

  private async handlePostResult(value: string): Promise<void> {
    try {
      const result: PinWebPostResult = JSON.parse(value) as PinWebPostResult;
      if (!result || !this.isCurrentMorePin(result.pinUrl)) return;
      if (result.scope === 'share' && (result.session !== this.pinStore.shareSession || this.activeSheetKind !== 'share')) return;
      if (result.scope === 'more' && (result.session !== this.pinStore.moreSession ||
          this.activeSheetKind !== 'more' && !this.homeStore.customHomeMenu)) return;
      if (result.kind === 'editOpen' && this.activeSheetKind === 'more') {
        this.dismissMoreSheet();
        this.openEditPin(result.pinUrl);
      } else if (result.kind === 'feedbackReady') {
        this.pinStore.saveUndoPin = ''; this.pinStore.saveUndoId = '';
        this.pinStore.feedbackUndoPin = result.pinUrl;
        this.pinStore.feedbackUndoSession = result.session;
        if (this.activeSheetKind === 'more') this.dismissMoreSheet();
        this.showUndoSnack('将为你显示更多此类 Pin', result.pinUrl, () => this.undoMoreFeedback());
      } else if (result.kind === 'saveReady' && result.objectId && this.activeSheetKind === 'save' &&
          this.pinStore.saveResult.pin === result.pinUrl) {
        this.pinStore.confirmedSaves.confirm(this.pinIdentity(result.pinUrl), true);
        if (this.pinStore.detail) {
          this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.pinIdentity(result.pinUrl), this.pinStore.detail);
          this.pinStore.detailCache.put(this.pinIdentity(result.pinUrl), this.pinStore.detail, this.pinStore.detailScrollOffset);
        }
        this.pinStore.saveUndoPin = result.pinUrl; this.pinStore.saveUndoId = result.objectId;
        this.dismissApiBoards();
        this.showUndoSnack(result.value, result.pinUrl, () => this.undoSavedPin());
      } else if ((result.kind === 'saveUndone' || result.kind === 'saveUndoError') &&
          this.pinStore.saveUndoPin === result.pinUrl && this.pinStore.saveUndoId === result.objectId) {
        if (result.kind === 'saveUndone') {
          this.pinStore.confirmedSaves.confirm(this.pinIdentity(result.pinUrl), false);
          if (this.pinStore.detail) {
            this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.pinIdentity(result.pinUrl), this.pinStore.detail);
            this.pinStore.detailCache.put(this.pinIdentity(result.pinUrl), this.pinStore.detail, this.pinStore.detailScrollOffset);
          }
          this.pinStore.saveUndoPin = ''; this.pinStore.saveUndoId = ''; this.showMessage(result.value);
        } else this.showUndoSnack(result.value, result.pinUrl, () => this.undoSavedPin());
      } else if ((result.kind === 'feedbackUndone' || result.kind === 'feedbackUndoError') &&
          result.pinUrl === this.pinStore.feedbackUndoPin && result.session === this.pinStore.feedbackUndoSession) {
        this.pinStore.feedbackUndoBusy = false;
        if (result.kind === 'feedbackUndone') this.pinStore.feedbackUndoPin = '';
        if (result.kind === 'feedbackUndoError') this.showUndoSnack(result.value, result.pinUrl, () => this.undoMoreFeedback());
        else this.showMessage(result.value);
      } else if (result.kind === 'help' && result.value === 'https://help.pinterest.com/en/article/gen-ai-labels') {
        const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await context.openLink(result.value);
      }
      if (result.kind === 'copy' && (/^https:\/\/pin\.it\/[A-Za-z0-9]+$/.test(result.value) ||
          /^https:\/\/(?:[^/]+\.)?pinterest\.com\/pin\/\d+\/$/.test(result.value) &&
          this.pinIdentity(result.value) === this.pinIdentity(result.pinUrl))) {
        await this.systemActions.copyText(result.value);
        if (result.session === this.pinStore.shareSession && this.activeSheetKind === 'share') {
          this.pinStore.shareFeedback = '链接已复制';
          this.showShareFeedbackSnack();
        }
      } else if (result.kind === 'download' && /^https:\/\/i\.pinimg\.com\//.test(result.value)) {
        this.controller.startDownload(result.value);
      } else if (result.kind === 'systemShare' && (/^https:\/\/pin\.it\/[A-Za-z0-9]+$/.test(result.value) ||
          /^https:\/\/(?:[^/]+\.)?pinterest\.com\/pin\/\d+\/$/.test(result.value) &&
          this.pinIdentity(result.value) === this.pinIdentity(result.pinUrl)) &&
          /^(?:Facebook|Messenger|X|WhatsApp|短信)$/.test(result.platform || '')) {
        const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        if (result.targetUrl && /^https:\/\/(?:[^/]+\.)?(?:twitter\.com|x\.com|facebook\.com|messenger\.com)\//.test(result.targetUrl)) {
          try {
            await context.openLink(result.targetUrl, { appLinkingOnly: true });
            return;
          } catch (error) { /* Resolve installed share providers below when App Linking has no handler. */ }
        }
        if (result.session !== this.pinStore.shareSession || this.activeSheetKind !== 'share' ||
            !this.isCurrentMorePin(result.pinUrl)) return;
        this.showMessage('请在系统分享中选择 ' + result.platform);
        await this.sharePinUrl(result.value, result.title || 'Pinterest Pin');
      } else if (result.kind === 'external' && /^https:\/\/(?:[^/]+\.)?(?:twitter\.com|x\.com|facebook\.com|messenger\.com|whatsapp\.com)\//.test(result.value)) {
        const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await context.openLink(result.value);
      } else if (result.kind === 'message') {
        this.showMessage(result.value);
      }
    } catch (error) { this.showMessage('操作失败，请重试'); }
  }

  private webJsonText(value: string): string {
    // ArkWeb may encode a JavaScript string result as a JSON string once more.
    const decoded: string = JSON.parse(value) as string;
    return typeof decoded === 'string' ? decoded : value;
  }

  private async openApiComments(): Promise<void> {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || this.pinIdentity(detail.pinUrl) !== this.pinIdentity(this.currentPinUrl())) return;
    const token: number = ++this.pinStore.commentToken;
    const pin: string = detail.pinUrl;
    this.pinStore.commentResult = { pin: pin, loading: true, error: '', items: [] };
    this.activeSheetKind = 'comments';
    this.showNativeSheet = true;
    try {
      await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.commentsStart(' + JSON.stringify(pin) + ')');
      const poll = async (): Promise<void> => {
        if (token !== this.pinStore.commentToken || this.activeSheetKind !== 'comments' ||
            this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
        try {
          const value: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && window.PinWebPostApi.commentsRead(' + JSON.stringify(pin) + '))');
          if (token !== this.pinStore.commentToken || this.activeSheetKind !== 'comments' ||
              this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
          const result: PinWebCommentResult | null = JSON.parse(this.webJsonText(value)) as PinWebCommentResult | null;
          if (!result || result.pin !== pin) throw new Error('Unavailable');
          this.pinStore.commentResult = result;
          setTimeout(() => { poll(); }, result.loading ? 250 : 500);
        } catch (error) {
          if (token === this.pinStore.commentToken) this.pinStore.commentResult = { pin: pin, loading: false, error: '评论加载失败，请重试', items: [] };
        }
      };
      poll();
    } catch (error) {
      if (token === this.pinStore.commentToken) this.pinStore.commentResult = { pin: pin, loading: false, error: '评论接口不可用', items: [] };
    }
  }

  private dismissApiComments(): void {
    this.pinStore.commentToken++;
    this.showNativeSheet = false;
    this.activeSheetKind = '';
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.commentsClose()').catch(() => {});
  }

  private commentApiAction(method: string, id: string = ''): void {
    const pin: string = this.pinStore.commentResult.pin;
    if (this.activeSheetKind !== 'comments' || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.' + method + '(' +
      JSON.stringify(pin) + (id ? ',' + JSON.stringify(id) : '') + ')')
      .catch(() => this.showMessage('评论操作失败，请重试'));
  }

  private async pickCommentImage(): Promise<string> {
    const token: number = this.pinStore.commentToken;
    if (this.activeSheetKind !== 'comments' || this.pinStore.commentResult.busy) return '';
    try {
      const selectedUri: string = await this.systemActions.pickImage();
      if (token !== this.pinStore.commentToken || this.activeSheetKind !== 'comments') return '';
      return selectedUri;
    } catch (_) { this.showMessage('图片选择未完成'); return ''; }
  }

  private async writeComment(encoded: string): Promise<void> {
    const pin: string = this.pinStore.commentResult.pin;
    const token: number = this.pinStore.commentToken;
    if (this.activeSheetKind !== 'comments' || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl()) ||
        this.pinStore.commentResult.busy || this.pinStore.commentResult.uncertain) return;
    let value: NativeCommentWrite;
    try { value = JSON.parse(encoded) as NativeCommentWrite; } catch (_) { return; }
    if (!value || !['create', 'reply', 'edit', 'delete', 'photo'].includes(value.action) ||
        typeof value.text !== 'string' || value.text.length > 5000 || typeof value.id !== 'string') return;
    const current = (): boolean => token === this.pinStore.commentToken && this.activeSheetKind === 'comments' &&
      this.pinIdentity(pin) === this.pinIdentity(this.currentPinUrl()) && this.authStatus === 'authenticated';
    if (value.action === 'photo') {
      if (!value.imageUri || !/^file:\/\/media\//.test(value.imageUri)) return;
      try {
        const started: string = await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.commentPhotoBegin(' + JSON.stringify(pin) + ')');
        if (!current() || (started !== 'true' && started !== '"true"')) return;
        const bytes: ArrayBuffer = await this.systemActions.readJpeg(value.imageUri);
        if (!current()) return;
        value.signature = await this.nativeNetwork.uploadCommentImage(bytes, pin, (): PinWebNetworkContext => {
          const context: PinWebNetworkContext = this.nativeNetworkContext();
          context.authenticated = context.authenticated && current(); return context;
        });
        value.imageUri = undefined;
      } catch (_) {
        if (current()) await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.commentPhotoFail(' + JSON.stringify(pin) + ')').catch(() => {});
        return;
      }
    }
    if (!current()) return;
    try {
      await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.commentWrite(' +
        JSON.stringify(pin) + ',' + JSON.stringify(JSON.stringify(value)) + ')');
    } catch (_) { if (current()) this.showMessage('评论提交结果未确认，请重新读取核对'); }
  }

  private async openApiBoards(requestedPin: string = ''): Promise<void> {
    const pin: string = requestedPin || (this.activeSheetKind === 'save' ? this.pinStore.saveResult.pin : this.pinStore.detail?.pinUrl || '');
    if (!pin || !this.isCurrentMorePin(pin)) return;
    const token: number = ++this.pinStore.saveToken;
    this.pinStore.saveCreating = false;
    this.pinStore.saveResult = { pin: pin, loading: true, busy: false, error: '', feedback: '',
      items: [], shortlist: [], savedId: '', savedBoard: '' };
    this.activeSheetKind = 'save';
    this.showNativeSheet = true;
    try {
      await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.boardsStart(' + JSON.stringify(pin) + ')');
      const poll = async (): Promise<void> => {
        if (token !== this.pinStore.saveToken || this.activeSheetKind !== 'save' || !this.isCurrentMorePin(pin)) return;
        try {
          const value: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && window.PinWebPostApi.boardsRead(' + JSON.stringify(pin) + '))');
          if (token !== this.pinStore.saveToken || this.activeSheetKind !== 'save' || !this.isCurrentMorePin(pin)) return;
          const result: PinWebSaveResult | null = JSON.parse(this.webJsonText(value)) as PinWebSaveResult | null;
          if (!result || result.pin !== pin || !Array.isArray(result.items) || !Array.isArray(result.shortlist)) throw new Error('Unavailable');
          this.pinStore.saveResult = result;
          setTimeout(() => { poll(); }, result.loading || result.busy ? 250 : 500);
        } catch (_) {
          if (token === this.pinStore.saveToken) this.pinStore.saveResult = { pin: pin, loading: false, busy: false,
            error: '图板接口不可用，请重试', feedback: '', items: [], shortlist: [], savedId: '', savedBoard: '' };
        }
      };
      poll();
    } catch (_) { this.showMessage('图板接口不可用，请重试'); }
  }

  private saveApiAction(method: string, args: string = ''): void {
    const pin: string = this.pinStore.saveResult.pin;
    if (this.activeSheetKind !== 'save' || this.pinStore.saveResult.busy || !this.isCurrentMorePin(pin)) return;
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.' + method + '(' +
      JSON.stringify(pin) + args + ')').catch(() => this.showMessage('图板操作失败，请重试'));
  }

  private dismissApiBoards(): void {
    PinWebRuntimeLog.info('PinWebReturn: save sheet dismissed');
    this.pinStore.shareBackHandledUntil = Date.now() + 500;
    this.lastRootBackAt = 0;
    this.pinStore.saveCreating = false;
    this.pinStore.saveToken++;
    this.showNativeSheet = false;
    this.activeSheetKind = '';
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.boardsClose()').catch(() => {});
    if (this.homeStore.customHomeMenu) { this.dismissShareSheet(); return; }
    this.controller.runJavaScript('window.PinWebDetailRefresh && window.PinWebDetailRefresh()').catch(() => {});
  }

  private async openEditPin(pin: string): Promise<void> {
    if (!this.isCurrentMorePin(pin) || this.pinStore.editResult.busy || this.pinStore.editResult.picker.busy) return;
    this.pinStore.saveCreating = false;
    const token: number = ++this.pinStore.editToken;
    this.pinStore.editResult = { pin: pin, loading: true, busy: false, error: '', phase: 'edit', imageUrl: '', title: '', description: '', ai: false,
      uncertain: false, done: '', board: { id: '', name: '', imageUrl: '', enabled: false, secret: false },
      picker: { pin: pin, loading: false, busy: false, error: '', feedback: '', items: [], shortlist: [], savedId: '', savedBoard: '' } };
    this.activeSheetKind = 'edit'; this.showNativeSheet = true;
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.editStart(' + JSON.stringify(pin) + ')')
      .catch(() => { if (token === this.pinStore.editToken) { this.pinStore.editResult.loading = false; this.pinStore.editResult.error = '编辑接口不可用，请重新读取'; } });
    const poll = async (): Promise<void> => {
      if (token !== this.pinStore.editToken || this.activeSheetKind !== 'edit' || !this.isCurrentMorePin(pin)) return;
      try {
        const value: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebPostApi && window.PinWebPostApi.editRead(' + JSON.stringify(pin) + '))');
        if (token !== this.pinStore.editToken || this.activeSheetKind !== 'edit' || !this.isCurrentMorePin(pin)) return;
        const result: PinWebEditPinResult | null = JSON.parse(this.webJsonText(value)) as PinWebEditPinResult | null;
        if (!result || result.pin !== pin || !result.board || !result.picker) throw new Error('Unavailable');
        this.pinStore.editResult = result;
        if (result.done === 'saved' || result.done === 'deleted') {
          const deleted: boolean = result.done === 'deleted';
          if (deleted) this.pinStore.confirmedSaves.confirm(this.pinIdentity(pin), false);
          this.pinStore.detailCache.remove(this.pinIdentity(pin));
          this.dismissEditPin();
          if (deleted) {
            this.pinStore.detail = undefined;
            await this.handleBack();
          }
          this.controller.runJavaScript('window.PinWebProfileRefresh && window.PinWebProfileRefresh(); window.PinWebBoardRefresh && window.PinWebBoardRefresh(); window.PinWebDetailRefresh && window.PinWebDetailRefresh()').catch(() => {});
          this.showMessage(deleted ? '已从你的图板移除 Pin 图' : '已保存修改');
          return;
        }
        setTimeout(() => { poll(); }, result.loading || result.busy || result.picker.loading || result.picker.busy ? 250 : 500);
      } catch (_) {
        if (token === this.pinStore.editToken) { this.pinStore.editResult.loading = false; this.pinStore.editResult.error = '编辑信息读取失败，请重新读取'; }
      }
    };
    poll();
  }

  private editPinAction(method: string, args: string): void {
    if (this.activeSheetKind !== 'edit' || this.pinStore.editResult.busy || this.pinStore.editResult.picker.busy ||
        !this.isCurrentMorePin(this.pinStore.editResult.pin)) return;
    const token: number = this.pinStore.editToken;
    const pin: string = this.pinStore.editResult.pin;
    if (method === 'editPhase' || method === 'editSelect') this.pinStore.saveCreating = false;
    if (method === 'editCommit') this.pinStore.editResult.busy = true;
    if (method === 'boardsCreate') this.pinStore.editResult.picker.busy = true;
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.' + method + '(' +
      JSON.stringify(this.pinStore.editResult.pin) + args + ')').catch(() => {
        if (token !== this.pinStore.editToken || this.activeSheetKind !== 'edit' || !this.isCurrentMorePin(pin)) return;
        this.pinStore.editResult.busy = false;
        this.pinStore.editResult.picker.busy = false;
        this.pinStore.editResult.error = '操作未确认，请重新读取后检查结果';
      });
  }

  private dismissEditPin(force: boolean = false): void {
    if (!force && (this.pinStore.editResult.busy || this.pinStore.editResult.picker.busy)) return;
    this.pinStore.editToken++; this.showNativeSheet = false; this.activeSheetKind = '';
    this.pinStore.editResult.busy = false;
    this.pinStore.editResult.picker.busy = false;
    this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.editClose()').catch(() => {});
  }

  private dismissPostSnack(): void {
    this.postSnackToken++;
    if (this.postSnack) this.postSnack.dismiss();
  }

  private handlePostSnackBack(token: number): void {
    // HdsSnackBar receives system back while visible, before the page does.
    // Consume this instance once, then use the normal sheet/page return flow.
    if (token !== this.postSnackToken) return;
    PinWebRuntimeLog.info('PinWebReturn: snackbar system back');
    this.dismissPostSnack();
    this.onBackPress();
  }

  private showShareLinkSnack(): void {
    if (this.pinStore.shareError !== '分享链接尚未就绪，请重试') return;
    const session: number = this.pinStore.shareSession;
    const pin: string = this.pinStore.sharePin;
    const key: string = session.toString() + ':' + pin + ':' + this.pinStore.shareError;
    if (this.pinStore.shareSnackKey === key) return;
    this.pinStore.shareSnackKey = key;
    this.dismissPostSnack();
    const token: number = this.postSnackToken;
    if (!this.postSnack) this.postSnack = new HdsSnackBar(this.getUIContext());
    this.postSnack.show({}, { title: this.pinStore.shareError }, {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: '重试',
      contentAccessibilityText: '重新读取分享链接', closeButtonAccessibilityText: '关闭提示',
      onContentClick: () => {
        if (token !== this.postSnackToken || session !== this.pinStore.shareSession || pin !== this.pinStore.sharePin ||
            this.activeSheetKind !== 'share' || !this.showNativeSheet) return;
        this.dismissPostSnack();
        this.refreshShareSheet();
      },
      onCloseButtonClick: () => { if (token === this.postSnackToken) this.dismissPostSnack(); }
    }, { duration: 4000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showShareFeedbackSnack(): void {
    if (!this.pinStore.shareFeedback) {
      this.pinStore.shareFeedbackSnackKey = '';
      return;
    }
    const key: string = this.pinStore.shareSession.toString() + ':' + this.pinStore.sharePin + ':feedback:' + this.pinStore.shareFeedback;
    if (this.pinStore.shareFeedbackSnackKey === key) return;
    this.pinStore.shareFeedbackSnackKey = key;
    this.dismissPostSnack();
    const token: number = this.postSnackToken;
    if (!this.postSnack) this.postSnack = new HdsSnackBar(this.getUIContext());
    this.postSnack.show({}, { title: this.pinStore.shareFeedback }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: '关闭提示',
      onCloseButtonClick: () => { if (token === this.postSnackToken) this.dismissPostSnack(); }
    }, { duration: 5000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showUndoSnack(message: string, pin: string, undo: () => void): void {
    PinWebRuntimeLog.info('PinWebReturn: undo snackbar shown');
    this.dismissPostSnack();
    const token: number = this.postSnackToken;
    if (!this.postSnack) this.postSnack = new HdsSnackBar(this.getUIContext());
    this.postSnack.show({}, { title: message }, {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: '撤销',
      contentAccessibilityText: '撤销本次操作', closeButtonAccessibilityText: '关闭提示',
      onContentClick: () => {
        if (token !== this.postSnackToken || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
        PinWebRuntimeLog.info('PinWebReturn: snackbar undo clicked');
        this.dismissPostSnack(); undo();
      }, onCloseButtonClick: () => {
        PinWebRuntimeLog.info('PinWebReturn: snackbar close clicked');
        if (token === this.postSnackToken) this.dismissPostSnack();
      }
    }, { duration: 8000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showInboxUndoSnack(newsId: string): void {
    PinWebRuntimeLog.info('PinWebInbox: update hidden, undo snackbar shown');
    this.dismissPostSnack();
    const token: number = this.postSnackToken;
    if (!this.postSnack) this.postSnack = new HdsSnackBar(this.getUIContext());
    this.postSnack.show({}, { title: '已删除更新' }, {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: '撤销',
      contentAccessibilityText: '撤销删除更新', closeButtonAccessibilityText: '关闭提示',
      onContentClick: () => {
        if (token !== this.postSnackToken || !this.inboxStore.inboxFlow ||
            this.inboxStore.inboxFlow.newsId !== newsId || !this.inboxStore.inboxFlow.newsHidden) return;
        PinWebRuntimeLog.info('PinWebInbox: update undo clicked');
        this.dismissPostSnack();
        this.inboxFlowAction('undoNews');
      },
      onCloseButtonClick: () => { if (token === this.postSnackToken) this.dismissPostSnack(); }
    }, { duration: 8000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showInboxRestoredSnack(): void {
    this.dismissPostSnack();
    const token: number = this.postSnackToken;
    if (!this.postSnack) this.postSnack = new HdsSnackBar(this.getUIContext());
    this.postSnack.show({}, { title: '已撤销删除更新' }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: '关闭提示',
      onCloseButtonClick: () => { if (token === this.postSnackToken) this.dismissPostSnack(); }
    }, { duration: 4000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private async undoSavedPin(): Promise<void> {
    const pin: string = this.pinStore.saveUndoPin;
    const copyId: string = this.pinStore.saveUndoId;
    if (!pin || !copyId || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.saveUndo(' +
        JSON.stringify(pin) + ',' + JSON.stringify(copyId) + ')');
      if (result !== 'true' && result !== '"true"') this.showUndoSnack('撤销未完成，请重试', pin, () => this.undoSavedPin());
    } catch (_) { this.showUndoSnack('撤销失败，请重试', pin, () => this.undoSavedPin()); }
  }

  private async undoMoreFeedback(): Promise<void> {
    const pin: string = this.pinStore.feedbackUndoPin;
    if (!pin || this.pinStore.feedbackUndoBusy || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
    this.pinStore.feedbackUndoBusy = true;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebPostApi && window.PinWebPostApi.feedbackUndo(' +
        JSON.stringify(pin) + ',' + this.pinStore.feedbackUndoSession.toString() + ')');
      if (result !== 'true' && result !== '"true"') {
        this.pinStore.feedbackUndoBusy = false;
        this.showUndoSnack('撤销未完成，请重试', pin, () => this.undoMoreFeedback());
      }
    } catch (_) {
      this.pinStore.feedbackUndoBusy = false;
      this.showUndoSnack('撤销失败，请重试', pin, () => this.undoMoreFeedback());
    }
  }

  private async openRelatedDetail(id: string): Promise<void> {
    if (this.rejectOfflineAction('related pin')) return;
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || !this.pinStore.detailActionsReady || !id ||
        this.pinIdentity(detail.pinUrl) !== this.pinIdentity(this.currentPinUrl())) return;
    this.pinStore.detailReturnUrl = detail.pinUrl;
    const related: PinWebRelatedPin | undefined = detail.related.find((pin: PinWebRelatedPin): boolean => pin.id === id);
    const targetPinUrl: string = related?.pinUrl || '';
    if (related) this.beginDetailOpening(targetPinUrl, detail.pinUrl);
    else this.pinStore.detail = undefined;
    try {
      const result: string = await this.controller.runJavaScript('window.PinWebDetailRelated && ' +
        'window.PinWebDetailRelated(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' +
        JSON.stringify(id) + ')');
      if (result !== 'true' && result !== '"true"') {
        // The old document may reject after the native opening state has
        // replaced the visible detail. Keep the new Pin opening state alive;
        // restoring `detail` here would paint the previous Pin over it.
        if (targetPinUrl && this.pinStore.detailOpeningPin === targetPinUrl) {
          this.controller.loadUrl(targetPinUrl);
        } else {
          this.showMessage('无法打开相关 Pin');
        }
      }
    } catch (error) {
      if (targetPinUrl && this.pinStore.detailOpeningPin === targetPinUrl) {
        try {
          this.controller.loadUrl(targetPinUrl);
        } catch (_) {
          this.pinStore.detailOpeningPin = '';
          this.showMessage('无法打开相关 Pin');
        }
      } else {
        this.showMessage('无法打开相关 Pin');
      }
    }
  }

  private loadMoreRelated(): void {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || !this.pinStore.detailActionsReady ||
        (!PIN_DETAIL_API_ENABLED && !detail.related.length)) return;
    this.controller.runJavaScript('window.PinWebDetailLoadMore && ' +
      'window.PinWebDetailLoadMore(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: related Pin loading unavailable'));
  }

  private retryDetailPreview(): void {
    if (!this.pinStore.detailActionsReady || !this.pinStore.detail?.commentError ||
        this.pinStore.detail.commentLoading || this.nativeBackTarget ||
        this.pinIdentity(this.currentPinUrl()) !== this.pinIdentity(this.pinStore.detailPin)) return;
    this.detailCommentsMeasured = false;
    this.controller.runJavaScript('window.PinWebDetailPreviewRetry && window.PinWebDetailPreviewRetry(' +
      this.pinStore.detailSession.toString() + ',' + JSON.stringify(this.pinStore.detailPin) + ')')
      .catch(() => PinWebRuntimeLog.warn('DetailTrace: comments retry unavailable'));
  }

  private syncDetailImageStage(): void {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!PIN_DETAIL_API_ENABLED || !detail || !this.pinStore.detailActionsReady ||
        (detail.imageStageReady && this.detailImageLoadedUrl !== detail.imageUrl)) return;
    const binding: string = this.pinStore.detailOpeningToken.toString() + ':' + detail.session.toString() + ':' + detail.imageUrl;
    if (binding !== this.detailImageBinding) {
      this.detailImageBinding = binding;
      this.detailImageSignal = '';
      this.detailImageBridgeAttempts = 0;
      this.detailJourney.mark('main.image.bound');
      if (this.detailImageTimer !== -1) this.pageTasks.cancelTimeout(this.detailImageTimer);
      // A missing native image callback must not hold comments and related pins
      // for the full network timeout. Timeout remains a truthful image outcome.
      this.detailImageTimer = this.pageTasks.timeout(() => {
        if (binding === this.detailImageBinding && !this.pinStore.detail?.imageStageReady) this.signalDetailImageStage('timeout');
      }, 2500);
    }
    if (this.detailImageLoadedUrl === detail.imageUrl) this.signalDetailImageStage('loaded');
    else if (this.detailImageFailedUrl === detail.imageUrl) this.signalDetailImageStage('failed');
  }

  private detailRenderIdentity(): string {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail) return '';
    return detail.pinUrl + '|' + detail.imageUrl + '|' + detail.kind + '|' + detail.session.toString() +
      '|' + this.pinStore.detailOpeningToken.toString();
  }

  // Keep the detail page root mounted while one Pin moves from cached to
  // current content. Volatile snapshot/session fields belong to the page
  // props and image nodes, not to the root ForEach key.
  private detailRootIdentity(): string {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    return this.pinIdentity(detail?.pinUrl || this.pinStore.detailOpeningPin);
  }

  private signalDetailImageStage(outcome: string): void {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || !this.pinStore.detailActionsReady || this.nativeBackTarget || (detail.imageStageReady && outcome !== 'loaded') ||
        this.detailImageSignal === this.detailImageBinding + ":" + outcome || !this.detailImageBinding) return;
    const binding: string = this.detailImageBinding;
    const token: number = this.pinStore.detailOpeningToken;
    this.detailImageSignal = binding + ":" + outcome;
    this.detailImageBridgeAttempts++;
    const bridgeFailed = (): void => {
      if (token !== this.pinStore.detailOpeningToken || binding !== this.detailImageBinding) return;
      this.detailImageSignal = ''; this.detailJourney.mark('main.image.bridge.failed');
      this.pinStore.detailApiError = '详情连接暂不可用，请重试';
    };
    try {
    this.controller.runJavaScript('window.PinWebDetailImageStage && window.PinWebDetailImageStage(' +
      detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' + JSON.stringify(detail.imageUrl) + ',' + JSON.stringify(outcome) + ')')
      .then((result: string) => {
        if (token !== this.pinStore.detailOpeningToken || binding !== this.detailImageBinding) return;
        if (result === 'true' || result === '"true"') {
          this.detailJourney.mark('main.image.stage=' + outcome);
          if (this.detailImageTimer !== -1) this.pageTasks.cancelTimeout(this.detailImageTimer);
          this.detailImageTimer = -1;
        } else {
          this.detailImageSignal = '';
          if (this.detailImageBridgeAttempts < 8)
            setTimeout(() => { if (token === this.pinStore.detailOpeningToken && binding === this.detailImageBinding) this.signalDetailImageStage(outcome); }, 250);
          else {
            this.detailJourney.mark('main.image.bridge.unavailable');
            this.pinStore.detailApiError = '详情连接尚未就绪，请重试';
          }
        }
      }).catch(bridgeFailed);
    } catch (_) { bridgeFailed(); }
  }

  private retryDetailApi(): void {
    if (this.pinStore.detailPresentationOnly) { this.ensureDetailActionContext(); return; }
    this.detailReturnReadPin = ''; this.detailReturnReads.clear();
    this.detailImageSignal = ''; this.detailImageBridgeAttempts = 0;
    this.pinStore.detailApiError = '';
    this.pinStore.detailImageFailedPin = '';
    const pin: string = this.pinStore.detailPin || this.pinStore.detailOpeningPin;
    const restart: boolean = !this.pinStore.detailActionsReady;
    if (!this.pinStore.detailActionsReady && this.pinIdentity(pin) && PIN_NATIVE_NETWORK_ENABLED) {
      this.sharedDetailRequestId = '';
      this.pinStore.detailPrefetch.pause(); this.detailReadNetwork.invalidate(); this.openingRelated = undefined;
      this.pinStore.detailOpeningPin = pin;
      this.startOpeningDetailRead(pin, ++this.pinStore.detailOpeningToken);
    }
    this.controller.runJavaScript('window.PinWebDetailApiRetry && window.PinWebDetailApiRetry(' +
      this.pinStore.detailSession.toString() + ',' + JSON.stringify(this.pinStore.detailPin) + ',' + restart.toString() + ');' +
      'window.PinWebDetailRefresh && window.PinWebDetailRefresh()')
      .catch(() => { this.pinStore.detailApiError = '帖子接口不可用，请重新进入'; });
  }

  private async returnFromDetailWebFlow(): Promise<void> {
    const detail: PinWebDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail) {
      this.pinStore.detailWebFlow = false;
      this.backFromDetail();
      return;
    }
    try {
      await this.controller.runJavaScript('window.PinWebHandleBack ? window.PinWebHandleBack() : false');
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: could not close detail web panel');
    }
    if (this.pinIdentity(this.currentPinUrl()) === this.pinIdentity(detail.pinUrl)) {
      this.pinStore.detailWebFlow = false;
      this.controller.runJavaScript('window.PinWebDetailResume && window.PinWebDetailResume()')
        .catch(() => PinWebRuntimeLog.warn('PinWeb: could not refresh detail'));
    } else {
      this.backFromDetail();
    }
  }

  private currentPinUrl(): string {
    if (this.pinStore.detailPresentationOnly) return '';
    if (this.nativeRootOnly || this.detailReturnedToRoot) return '';
    try {
      return this.extractPinUrl(this.controller.getUrl());
    } catch (error) {
      return '';
    }
  }

  private extractPinUrl(value: string): string {
    let decoded: string = value;
    for (let attempt: number = 0; attempt < 3; attempt++) {
      const full: RegExpMatchArray | null = decoded.match(/https?:\/\/(?:[a-z0-9-]+\.)?pinterest\.com\/pin\/\d+\/?/i);
      if (full) {
        return full[0];
      }
      const short: RegExpMatchArray | null = decoded.match(/https?:\/\/(?:www\.)?pin\.it\/[a-z0-9]+/i);
      if (short) {
        return short[0];
      }
      try {
        const next: string = decodeURIComponent(decoded);
        if (next === decoded) {
          break;
        }
        decoded = next;
      } catch (error) {
        break;
      }
    }
    return '';
  }

  private shareFromTarget(targetUrl: string, pinUrl: string): void {
    const url: string = this.extractPinUrl(targetUrl) || this.extractPinUrl(pinUrl) ||
      this.pinStore.sharePin || this.currentPinUrl();
    if (!url) {
      this.showMessage('无法获取这张 Pin 的链接');
      return;
    }
    this.sharePinUrl(url);
  }

  private async sharePinUrl(url: string, title: string = 'Pinterest Pin'): Promise<void> {
    try {
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: url,
        title: title
      });
      const shareController: systemShare.ShareController = new systemShare.ShareController(data);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await shareController.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (error) {
      PinWebRuntimeLog.error('PinWeb: system share failed');
      this.showMessage('分享面板打开失败');
    }
  }

  private isExternalShareTarget(url: string): boolean {
    return /^(sms:|fb-messenger:\/\/|facebook-messenger:\/\/|whatsapp:\/\/)/i.test(url) ||
      /^https?:\/\/(?:[^/]+\.)?(?:twitter\.com|x\.com|facebook\.com|fb\.com|messenger\.com|whatsapp\.com|wa\.me)(?:\/|\?|$)/i.test(url);
  }

  private handleExternalShareTarget(url: string): boolean {
    if (!this.isExternalShareTarget(url)) {
      return false;
    }
    const pinUrl: string = this.extractPinUrl(url) || this.currentPinUrl();
    if (!pinUrl) {
      return false;
    }
    this.sharePinUrl(pinUrl);
    return true;
  }


  private installDownloadDelegate(): void {
    this.systemActions.installDownloadDelegate(this.controller);
  }

  private cancelAccountSettings(): void {
    try { this.controller.runJavaScript('window.PinWebAccountSettings && window.PinWebAccountSettings.close()').catch(() => {}); } catch (_) {}
  }
  private async readNotifications(): Promise<void> {
    if (this.authStatus !== 'authenticated' || !this.profileSettingsVisible || this.settingsStore.loading) return;
    const token: number = ++this.settingsStore.token;
    const page: string = this.controller.getUrl();
    this.settingsStore.loading = true; this.settingsStore.error = ''; this.settingsStore.notifications = [];
    try {
      await this.controller.runJavaScript(useNativeTransport(PIN_NOTIFICATIONS_READ_SCRIPT));
      for (let attempt: number = 0; attempt < 80; attempt++) {
        if (token !== this.settingsStore.token || this.authStatus !== 'authenticated' || this.controller.getUrl() !== page ||
          !this.profileSettingsVisible || this.settingsStore.screen !== 'notifications') return;
        const raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebNotificationsResult)');
        const result = JSON.parse(this.webJsonText(raw)) as NotificationResult | null;
        if (result) { this.settingsStore.notifications = result.groups; this.settingsStore.error = result.error; return; }
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250); });
      }
      this.settingsStore.error = '通知设置读取超时，请重试';
    } catch (_) { if (token === this.settingsStore.token) this.settingsStore.error = '通知设置读取失败，请重试'; }
    finally { if (token === this.settingsStore.token) this.settingsStore.loading = false; }
  }

  private async logoutAccount(): Promise<void> {
    if (!PIN_LOGOUT_API_ENABLED || !PIN_NATIVE_NETWORK_ENABLED || this.authStatus !== 'authenticated' ||
        !this.profileSettingsVisible || this.settingsStore.screen !== 'root' || this.settingsStore.busy || this.settingsStore.loading) return;
    const context: PinWebNetworkContext = this.nativeNetworkContext();
    if (!context.page.startsWith(PINTEREST_URL)) return;
    const token: number = ++this.settingsStore.token;
    this.settingsStore.busy = true;
    this.settingsStore.error = '';
    PinWebRuntimeLog.info('SessionLogout: request started');
    try {
      const job: PinWebNetworkJob = { id: 'session_logout_' + token.toString() + '_' + Date.now().toString(),
        epoch: context.epoch, page: context.page, url: PINTEREST_URL + 'resource/UserSessionResource/delete/',
        method: 'POST', body: logoutRequestBody(), headers: { 'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/settings.js' } };
      const reply: PinWebNetworkReply = await this.nativeNetwork.request(job, (): PinWebNetworkContext => this.nativeNetworkContext());
      if (token !== this.settingsStore.token || this.authStatus !== 'authenticated' ||
          this.authEpoch !== context.epoch || this.nativeNetworkContext().page !== context.page) return;
      if (reply.error || !logoutResponseSucceeded(reply.status, reply.body)) {
        this.settingsStore.error = '退出结果未确认，请稍后重试';
        PinWebRuntimeLog.warn('SessionLogout: result not confirmed');
        return;
      }
      PinWebRuntimeLog.info('SessionLogout: server confirmed');
      this.resetAuthenticatedContent();
      this.authEpoch++;
      this.authStatus = 'unauthenticated';
      this.logoutAwaitingLogin = true;
      this.loginRedirectEpoch = this.authEpoch;
      this.navigationAddress = PINTEREST_LOGIN_URL;
      this.lastPageUrl = PINTEREST_LOGIN_URL;
      this.loadFailed = false;
      this.failureDetails = '';
      this.controller.loadUrl(PINTEREST_LOGIN_URL);
    } catch (_) {
      if (this.authStatus === 'unauthenticated') {
        this.authStatus = 'error';
        this.failureDetails = '已退出，登录页面暂时无法加载，请重试';
      } else if (token === this.settingsStore.token) this.settingsStore.error = '退出结果未确认，请稍后重试';
      PinWebRuntimeLog.warn('SessionLogout: operation unavailable');
    } finally {
      if (token === this.settingsStore.token) this.settingsStore.busy = false;
    }
  }

  private startOpeningDetailRead(pinUrl: string, token: number): void {
    this.openingRelated = undefined;
    this.openingRelatedToken = token;
    this.detailJourney.mark('base.request.or.takeover');
    const captured: PinWebNetworkContext = this.nativeNetworkContext();
    const current = (): boolean => this.authStatus === 'authenticated' && this.pinStore.videoForeground &&
      token === this.pinStore.detailOpeningToken && this.pinStore.detailOpeningPin === pinUrl && !this.nativeBackTarget;
    setTimeout(() => {
      if (current() && !this.pinStore.detailActionsReady) this.pinStore.detailApiError = '帖子加载超时，请重试';
    }, 12000);
    this.pinStore.detailPrefetch.open(pinUrl,
      async (url: string, id: string, ownerCurrent: () => boolean): Promise<string> => {
        this.detailRequestOwners.set(id, this.detailJourney.current());
        const job: PinWebNetworkJob = { id: id, epoch: captured.epoch, page: captured.page, url: url,
          method: 'GET', body: '', headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
            'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
        const reply: PinWebNetworkReply = await this.detailReadNetwork.requestPinRead(job,
          (): PinWebNetworkContext => this.nativeNetworkContext(), pinUrl, ownerCurrent);
        this.detailRequestOwners.delete(id);
        if (!ownerCurrent() || reply.error || reply.status !== 200) throw new Error('detail-unavailable');
        return reply.body;
      }, current, (id: string) => this.detailReadNetwork.cancel(id)).then(() => {
        if (!current() || this.pinStore.detailActionsReady) return;
        const detail: PinWebDetailSnapshot | undefined = this.pinStore.detailPrefetch.get(pinUrl);
        if (detail && this.pinStore.detail?.kind !== 'cached') {
          this.pinStore.detailPin = pinUrl;
          this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.pinIdentity(pinUrl), detail);
        }
        this.pinStore.detailApiError = '';
        this.detailJourney.mark('base.validated');
        const context: PinWebNetworkContext = this.nativeNetworkContext();
        const id: string = this.pinIdentity(pinUrl);
        const options: string = JSON.stringify({ pin_id: id, page_size: 12, context_pin_ids: [],
          homefeed_source_sig: false, search_query: '', source: 'feed_home', top_level_source: 'feed_home',
          top_level_source_depth: 1, is_pdp: false, additional_fields: ['pin.gen_ai_topics'] });
        const url: string = 'https://www.pinterest.com/resource/RelatedModulesResource/get/?source_url=' +
          encodeURIComponent('/pin/' + id + '/') + '&data=' + encodeURIComponent('{"options":' + options + ',"context":{}}');
        const job: PinWebNetworkJob = { id: 'opening_related_' + token.toString(), epoch: context.epoch,
          page: context.page, url: url, method: 'GET', body: '', headers: { 'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
        this.detailJourney.mark('related.opening.request');
        const retainedRelated: PinWebNetworkReply | undefined = this.retainedDetailRead(job);
        this.openingRelated = retainedRelated ? Promise.resolve(retainedRelated) : this.detailReadNetwork.requestPinRead(job,
          (): PinWebNetworkContext => this.nativeNetworkContext(), pinUrl,
          (): boolean => this.authStatus === 'authenticated' && this.pinStore.videoForeground &&
            token === this.pinStore.detailOpeningToken && !this.nativeBackTarget &&
            this.pinIdentity(this.pinStore.detailPin) === id).then((reply: PinWebNetworkReply): PinWebNetworkReply => {
            if (token !== this.pinStore.detailOpeningToken || this.authStatus !== 'authenticated' || this.nativeBackTarget ||
                this.pinStore.detailPresentationOnly || this.pinStore.detailActionsReady || this.pinStore.detailPin !== pinUrl || reply.error || reply.status !== 200) return reply;
            const related: RelatedPresentation | undefined = readRelatedPresentation(reply.body, pinUrl);
            const base: PinWebDetailSnapshot | undefined = this.pinStore.detail;
            if (related && base) {
              this.pinStore.detailCache.put(id, base, this.pinStore.detailScrollOffset);
              const presentation: PinWebDetailSnapshot | undefined = this.pinStore.detailCache.get(id)?.detail;
              if (presentation) {
                presentation.related = related.pins; presentation.relatedEnded = related.ended;
                presentation.relatedLoading = false; presentation.relatedRetained = true;
                this.pinStore.detail = presentation;
                this.detailJourney.mark('related.native.presentation');
              }
            }
            return reply;
          });
        PinWebRuntimeLog.info('DetailTrace: base ready openId=' + token.toString() + ' elapsedMs=' + (Date.now() - this.detailOpenedAt).toString());
      }).catch(() => {
        if (current()) this.detailJourney.mark('base.failed');
        if (current()) this.pinStore.detailApiError = '帖子加载失败，请重试';
      });
  }

  private async requestAccountSettings(action: string, value: string): Promise<void> {
    if (action === 'logout') { await this.logoutAccount(); return; }
    if (action === 'notifications') { await this.readNotifications(); return; }
    if (this.authStatus !== 'authenticated' || !this.profileSettingsVisible || this.settingsStore.busy || this.settingsStore.loading) return;
    let page: string = '';
    const token: number = ++this.settingsStore.token;
    const write: boolean = ['birthdate', 'gender', 'customGender', 'country', 'aiTopic', 'aiAll', 'activityClose', 'privateProfile', 'searchPrivacy'].includes(action);
    this.settingsStore.busy = write; this.settingsStore.loading = !write; this.settingsStore.error = '';
    try {
      const current = (): boolean => token === this.settingsStore.token && this.profileSettingsVisible;
      if (!await this.ensureRootActionContext(3, true, '', current)) {
        if (current()) this.settingsStore.error = '当前资料会话尚未就绪，请重试';
        return;
      }
      if (!current()) return;
      page = this.controller.getUrl();
      if (!this.currentProfileUrl() || this.profileUrlFromAddress(page) !== this.currentProfileUrl()) {
        this.settingsStore.error = '当前资料会话尚未就绪，请重试'; return;
      }
      await this.controller.runJavaScript(useNativeTransport(PIN_ACCOUNT_SETTINGS_SCRIPT) +
        '\nwindow.PinWebAccountSettings.start(' + JSON.stringify(page) + ',' + token.toString() + ',' + JSON.stringify(action) + ',' + JSON.stringify(value) + '); true');
      for (let attempt: number = 0; attempt < 70; attempt++) {
        if (token !== this.settingsStore.token || this.authStatus !== 'authenticated' || !this.profileSettingsVisible || this.controller.getUrl() !== page) return;
        const raw: string = await this.controller.runJavaScript('JSON.stringify(window.PinWebAccountSettings.read())');
        const result: PinWebAccountSettings = JSON.parse(this.webJsonText(raw)) as PinWebAccountSettings;
        if (!result || result.token !== token || result.page !== page) throw new Error('stale');
        if (!result.loading) {
          if (!Array.isArray(result.countries) || result.countries.length > 400 || typeof result.email !== 'string' || result.email.length > 320 || typeof result.birthdate !== 'string' || typeof result.gender !== 'string' || typeof result.customGender !== 'string' || result.customGender.length > 500) throw new Error('shape');
          if (token !== this.settingsStore.token || this.authStatus !== 'authenticated' || this.controller.getUrl() !== page) return;
          this.settingsStore.data = result; this.settingsStore.error = result.error;
          return;
        }
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250); });
      }
      throw new Error('timeout');
    } catch (_) {
      if (token === this.settingsStore.token) this.settingsStore.error = write ? '保存结果未确认，请重新读取核对；不会自动重试保存' : '读取失败，请重试';
    } finally {
      if (token === this.settingsStore.token) { this.settingsStore.busy = false; this.settingsStore.loading = false; }
    }
  }
  private closeProfileSettings(): void {
    this.nativeChildBackUntil = Date.now() + 220;
    if (this.settingsStore.back()) { if (!this.settingsStore.busy) this.cancelAccountSettings(); return; }
    this.cancelAccountSettings(); this.settingsStore.reset();
    this.nativeChildBackUntil = Date.now() + 220;
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.profileSettingsVisible = false; });
  }

  private async exportRuntimeLog(): Promise<void> {
    if (this.exportingRuntimeLog) return;
    this.exportingRuntimeLog = true;
    try {
      if (await this.systemActions.exportRuntimeLog()) this.showMessage('运行日志已导出到所选位置');
    } catch (_) { this.showMessage('日志导出失败，请重试'); }
    finally { this.exportingRuntimeLog = false; }
  }

  onBackPress(): boolean {
    PinWebRuntimeLog.info('PinWebReturn: root back sheet=' + this.activeSheetKind +
      ' detail=' + (!!this.pinStore.detail).toString() + ' pending=' + this.pageHistory.isPending().toString());
    if (Date.now() < this.nativeChildBackUntil) return true;
    if (this.profileStore.publishFlow) {
      const flow: PinWebPublishFlow = this.profileStore.publishFlow;
      if (!flow.busy && !this.profileStore.publishPicking) this.publishFlowAction(flow.uncertain || flow.kind === 'board' || ['website', 'photo', 'select'].includes(flow.phase) ? 'close' : 'back');
      return true;
    }
    if (this.pinStore.imageLayer && !this.activeSheetKind) { this.closeImageLayer(); return true; }
    if (this.profileStore.panel) { this.closeProfilePanel(); return true; }
    if (this.activeSheetKind === 'profileMenu') { this.dismissProfileMenu(); return true; }
    if (this.profileSettingsVisible) { this.closeProfileSettings(); return true; }
    if (this.currentProfileUrl() && this.profileStore.origins.length > 0) { this.backFromUserProfile(); return true; }
    if (Date.now() < this.pinStore.shareBackHandledUntil) return true;
    if (this.inboxStore.inboxFlow) {
      this.nativeChildBackUntil = Date.now() + 300;
      this.inboxFlowAction('back'); return true;
    }
    if (this.profileStore.profile && this.profileStore.profile.organize) {
      if (!this.profileStore.profile.organize.busy) {
        const phase: string = this.profileStore.profile.organize.phase;
        this.organizeProfile(phase === 'select' ? 'close' : phase === 'create' ? 'boards' : 'back');
      }
    } else if (this.activeSheetKind === 'edit') {
      if (!this.pinStore.editResult.busy && !this.pinStore.editResult.picker.busy) {
        if (this.pinStore.editResult.phase !== 'edit') this.editPinAction('editPhase', ',"edit"');
        else this.dismissEditPin();
      }
    } else if (this.activeSheetKind === 'comments') {
      this.dismissApiComments();
    } else if (this.activeSheetKind === 'save') {
      this.dismissApiBoards();
    } else if (this.activeSheetKind === 'publish') {
      this.dismissProfilePublish();
    } else if (this.activeSheetKind === 'profileMenu') {
      this.dismissProfileMenu();
    } else if (this.activeSheetKind === 'more') {
      this.dismissMoreSheet();
    } else if (this.activeSheetKind === 'share') {
      this.dismissShareSheet();
    } else if (this.activeSheetKind === 'searchFilter') {
      this.dismissSearchFilters();
    } else if (this.authStatus !== 'authenticated' || this.nativeRootTabsVisible()) {
      PinWebRuntimeLog.info('PinWebReturn: root back delegated to system');
      return false;
    } else if (this.searchStore.search && this.nativeSearchPageVisible() && this.searchStore.search.quiz && this.searchStore.search.quiz.mode !== 'entry') {
      this.handleBack();
    } else if (this.searchStore.searchInputFocused && !!this.currentSearchPageKey() &&
        !this.pinStore.detail && !this.currentPinUrl()) {
      if (this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
      this.searchStore.searchInputFocused = false;
      this.searchStore.searchInputStopEditing = undefined;
      this.backFromSearch();
    } else if (this.pinStore.detailWebFlow) {
      this.returnFromDetailWebFlow();
    } else if (this.boardStore.pendingBoardUrl || this.currentBoardUrl()) {
      this.backFromBoard();
    } else if (this.profileStore.profileWebFlow) {
      this.returnFromProfileWebFlow();
    } else if (this.pinStore.detail) {
      this.backFromDetail();
    } else if (this.currentPinUrl()) {
      this.backFromDetail();
    } else if (this.currentSearchPageKey()) {
      this.backFromSearch();
    } else {
      this.handleBack();
    }
    this.nativeChildBackUntil = Date.now() + 300;
    return true;
  }

  @Builder
  private buildShareActionRow(option: ShareSheetOption) {
    Column() {
      Text(option.label)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .maxLines(3)
      if (option.subtitle) {
        Text(option.subtitle)
          .fontSize(12)
          .fontColor($r('app.color.secondary_text'))
          .maxLines(4)
          .margin({ top: 3 })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 20, top: 14, bottom: 14 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .opacity(option.enabled ? 1 : 0.4)
    .accessibilityText(option.label)
    .onClick(() => {
      if (option.enabled) this.performShareAction(option.id);
    })
  }

  @Builder
  private buildShareContactRow(contact: ShareSheetOption) {
    Row({ space: 12 }) {
      Stack() {
        Text(contact.label.slice(0, 1))
          .fontSize(17)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width(42)
          .height(42)
          .borderRadius(21)
          .backgroundColor('#71839D')
        if (contact.icon) {
          Image(contact.icon)
            .width(42)
            .height(42)
            .borderRadius(21)
            .objectFit(ImageFit.Cover)
        }
      }
      .width(42)
      .height(42)
      Text(contact.label)
        .fontSize(16)
        .fontColor($r('app.color.primary_text'))
        .layoutWeight(1)
        .maxLines(2)
    }
    .width('100%')
    .height(60)
    .padding({ left: 20, right: 20 })
    .opacity(contact.enabled ? 1 : 0.4)
    .accessibilityText(contact.label)
    .onClick(() => {
      if (contact.enabled) this.performShareAction(contact.id);
    })
  }

  @Builder
  private buildShareSheet() {
    Column() {
      if (this.pinStore.shareLoading) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(24)
            .height(24)
          Text('正在读取分享选项…')
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .height(72)
        .padding({ left: 20, right: 20 })
      }
      if (this.pinStore.shareOptions.length > 0) {
        Scroll() {
          Row({ space: 20 }) {
            ForEach(this.pinStore.shareOptions, (option: ShareSheetOption) => {
              Column({ space: 8 }) {
                Stack() {
                  if (this.isCopyLinkAction(option.label)) {
                    Image($r('app.media.copy_link'))
                      .width(64)
                      .height(64)
                      .objectFit(ImageFit.Contain)
                  } else if (this.sharePlatformName(option.label) === 'Messenger') {
                    Image($r('app.media.share_messenger'))
                      .width(64)
                      .height(64)
                      .objectFit(ImageFit.Contain)
                  } else if (/^Facebook$/i.test(this.sharePlatformName(option.label))) {
                    Image($r('app.media.share_facebook'))
                      .width(64)
                      .height(64)
                  } else if (/^(?:X|Twitter)$/i.test(this.sharePlatformName(option.label))) {
                    Image($r('app.media.share_x'))
                      .width(64)
                      .height(64)
                  } else if (/WhatsApp/i.test(this.sharePlatformName(option.label))) {
                    Image($r('app.media.share_whatsapp'))
                      .width(64)
                      .height(64)
                  } else if (this.sharePlatformName(option.label) === '短信') {
                    Image($r('app.media.share_messages'))
                      .width(64)
                      .height(64)
                  } else if (option.icon) {
                    Image(option.icon).width(64).height(64).objectFit(ImageFit.Contain)
                  } else {
                    Text(this.shareOptionGlyph(this.sharePlatformName(option.label)))
                      .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  }
                }
                .width(64)
                .height(64)
                .borderRadius(32)
                .backgroundColor(this.shareOptionColor(this.sharePlatformName(option.label)))
                Text(this.sharePlatformName(option.label))
                  .fontSize(13)
                  .fontColor($r('app.color.primary_text'))
                  .maxLines(2)
                  .textAlign(TextAlign.Center)
              }
              .width(82)
              .opacity(option.enabled ? 1 : 0.4)
              .accessibilityText(this.sharePlatformName(option.label))
              .onClick(() => {
                if (option.enabled) this.performShareAction(option.id);
              })
            }, (option: ShareSheetOption) => option.id)
          }
          .padding({ left: 20, right: 20, top: 12, bottom: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      if (!this.pinStore.shareLoading && (this.pinStore.shareSectionLabel || this.pinStore.shareSearchId || this.pinStore.shareSearchActive ||
          this.pinStore.shareSendId || this.pinStore.shareContacts.length > 0)) {
        Divider()
          .color('#4D8A8A8A')
          .margin({ left: 20, right: 20, top: 8, bottom: 18 })
        if (this.pinStore.shareSectionLabel) {
          Text(this.pinStore.shareSectionLabel)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text'))
            .margin({ left: 20, right: 20, bottom: 14 })
        }
        if (this.pinStore.shareSearchActive) {
          TextInput({ text: this.pinStore.shareQuery, placeholder: this.pinStore.shareSearchLabel })
            .width('90%')
            .height(48)
            .margin({ bottom: 12 })
            .onChange((value: string) => {
              this.searchShareContacts(value);
            })
          Scroll() {
            Column() {
              ForEach(this.pinStore.shareContacts, (contact: ShareSheetOption) => {
                this.buildShareContactRow(contact)
              }, (contact: ShareSheetOption) => contact.id)
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
          }
          .align(Alignment.TopStart)
          .height(280)
          .width('100%')
        } else {
          if (this.pinStore.shareSearchId) {
            Row({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(24)
                .fontColor([$r('app.color.primary_text')])
                .width(48)
                .height(48)
                .borderRadius(14)
                .backgroundColor('#338A8A8A')
              Text(this.pinStore.shareSearchLabel)
                .fontSize(16)
                .fontColor($r('app.color.primary_text'))
            }
            .width('100%')
            .height(64)
            .padding({ left: 20, right: 20 })
            .accessibilityText(this.pinStore.shareSearchLabel)
            .onClick(() => this.performShareAction(this.pinStore.shareSearchId))
          }
          ForEach(this.pinStore.shareContacts, (contact: ShareSheetOption) => {
            this.buildShareContactRow(contact)
          }, (contact: ShareSheetOption) => contact.id)
        }
        if (this.pinStore.shareSendId && this.pinStore.shareSendLabel) {
          Button(this.pinStore.shareSendLabel)
            .width('90%')
            .margin({ top: 12, bottom: 12 })
            .onClick(() => this.performShareAction(this.pinStore.shareSendId))
        }
      }

      if (!this.pinStore.shareLoading && this.pinStore.shareActions.some((option: ShareSheetOption) =>
          !this.pinStore.shareOnPinDetail || !this.hasCarouselCopyLink() || !this.isCopyLinkAction(option.label))) {
        Divider()
          .color('#4D8A8A8A')
          .margin({ left: 20, right: 20, top: 12, bottom: 10 })
        ForEach(this.pinStore.shareActions.filter((option: ShareSheetOption) =>
          !this.pinStore.shareOnPinDetail || !this.hasCarouselCopyLink() ||
          !this.isCopyLinkAction(option.label)), (option: ShareSheetOption) => {
          this.buildShareActionRow(option)
        }, (option: ShareSheetOption) => option.id)
      }

      if (this.pinStore.shareError && this.pinStore.shareError !== '分享链接尚未就绪，请重试') {
        Row({ space: 12 }) {
          Text(this.pinStore.shareError)
            .fontSize(14)
            .fontColor('#D94A4A')
            .layoutWeight(1)
          Button('重试')
            .onClick(() => this.refreshShareSheet())
        }
        .margin({ left: 20, right: 20, top: 12 })
      }
    }
    .width('100%')
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
    .onAppear(() => this.scheduleShareWebOpen())
  }

  @Builder
  private buildMoreSheet() {
    Column() {
      if (this.pinStore.moreLoading) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(24)
            .height(24)
          Text('正在读取选项…')
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .height(72)
        .padding({ left: 20, right: 20 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.pinStore.moreOptions, (option: MoreSheetOption, index: number) => {
              if (index > 0 && option.group !== this.pinStore.moreOptions[index - 1].group) {
                Divider()
                  .color('#4D8A8A8A')
                  .margin({ left: 20, right: 20, top: 6, bottom: 6 })
              }
              Row({ space: 14 }) {
                if (option.icon) {
                  Image(option.icon)
                    .width(28)
                    .height(28)
                    .objectFit(ImageFit.Contain)
                }
                Column() {
                  Text(option.label)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.primary_text'))
                    .maxLines(2)
                  if (option.subtitle && !/详细了解.*AI|learn more.*AI/i.test(option.label)) {
                    Text(option.subtitle)
                      .fontSize(12)
                      .fontColor($r('app.color.secondary_text'))
                      .maxLines(3)
                      .margin({ top: 3 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 24, right: 20, top: 14, bottom: 14 })
              .opacity(option.enabled ? 1 : 0.4)
              .accessibilityText(option.label)
              .onClick(() => {
                if (option.enabled) this.performMoreAction(option.id);
              })
            }, (option: MoreSheetOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 520 })
      }
      if (this.pinStore.moreError) {
        Row({ space: 12 }) {
          Text(this.pinStore.moreError)
            .fontSize(14)
            .fontColor('#D94A4A')
            .layoutWeight(1)
          Button('重试')
            .onClick(() => this.refreshMoreSheet())
        }
        .margin({ left: 20, right: 20, top: 12 })
      }
    }
    .width('100%')
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private buildProfileStatus() {
    Column() {
      Column({ space: 18 }) {
        if (this.profileStore.profileLoading) {
          LoadingProgress().width(36).height(36)
          Text('正在加载个人资料…')
            .fontSize(15)
            .fontColor($r('app.color.secondary_text'))
        } else {
          Text(this.profileStore.profileError)
            .fontSize(16)
            .fontColor($r('app.color.primary_text'))
          Button('重新读取')
            .onClick(() => this.refreshProfile())
        }
        Text(PinWebRuntimeLog.savedStatus()).fontSize(13).fontColor($r('app.color.secondary_text'))
          .textAlign(TextAlign.Center).margin({ left: 24, right: 24 })
        Button(this.exportingRuntimeLog ? '正在导出…' : '导出运行日志')
          .enabled(!this.exportingRuntimeLog).onClick(() => { this.exportRuntimeLog(); })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 100 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private buildSearchFilterSheet() {
    Column() {
      if (this.searchStore.searchFilterLoading) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(24)
            .height(24)
          Text('正在读取筛选选项…')
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height(72)
        .padding({ left: 24, right: 24 })
      }
      if (this.searchStore.searchFilterError) {
        Text(this.searchStore.searchFilterError)
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .padding({ left: 24, right: 24, top: 18, bottom: 18 })
          .width('100%')
        Button('重试读取')
          .height(42)
          .margin({ left: 24, right: 24, bottom: 12 })
          .onClick(() => this.retrySearchFilters())
      }
      if (this.searchStore.searchFilterOptions.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.searchStore.searchFilterOptions, (option: PinWebSearchFilterOption, index: number) => {
              if (option.group && (index === 0 ||
                  option.group !== this.searchStore.searchFilterOptions[index - 1].group)) {
                Text(option.group)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.secondary_text'))
                  .padding({ left: 24, right: 24, top: 18, bottom: 6 })
                  .width('100%')
              }
              Row({ space: 12 }) {
                Text(option.label)
                  .fontSize(17)
                  .fontColor($r('app.color.primary_text'))
                  .layoutWeight(1)
                  .maxLines(2)
                if (option.selected) {
                  Text('✓')
                    .fontSize(20)
                    .fontColor($r('app.color.detail_accent'))
                }
              }
              .width('100%')
              .height(56)
              .padding({ left: 24, right: 24 })
              .opacity(option.enabled && !this.searchStore.searchFilterLoading ? 1 : 0.45)
              .accessibilityText(option.label + (option.selected ? '，已选中' : ''))
              .accessibilitySelected(option.selected)
              .onClick(() => {
                if (option.enabled && !this.searchStore.searchFilterLoading) this.selectSearchFilter(option.id);
              })
            }, (option: PinWebSearchFilterOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 520 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private buildNativeSheet() {
    if (this.homeStore.customHomeMenu && this.activeSheetKind === 'share') {
      PinWebHomeMenuSheet({ menu: this.homeStore.customHomeMenu,
        onAction: (id: string) => this.performCustomHomeAction(id),
        onRetry: () => {
          const menu: PinWebHomeMenuState | undefined = this.homeStore.customHomeMenu;
          if (menu && this.isCurrentMorePin(menu.pinUrl)) this.openCustomHomeMenu(menu.pinUrl, this.homeStore.homeMenuPage);
        } })
    } else if (this.activeSheetKind === 'edit') {
      PinWebEditPinSheet({ result: this.pinStore.editResult,
        onAction: (method: string, args: string) => this.editPinAction(method, args),
        onRetry: () => this.openEditPin(this.pinStore.editResult.pin), onClose: () => this.dismissEditPin(),
        onCreatingChange: (creating: boolean) => { this.pinStore.saveCreating = creating; } })
    } else if (this.activeSheetKind === 'comments') {
      PinWebCommentsSheet({ onUser: (url: string) => this.openUserProfile(url), result: this.pinStore.commentResult, onRetry: () => this.openApiComments(),
        onMore: () => this.commentApiAction('commentsMore'),
        onReplies: (id: string) => this.commentApiAction('commentReplies', id),
        onWrite: (value: string) => this.writeComment(value), onPickImage: () => this.pickCommentImage(),
        onClose: () => this.dismissApiComments(),
        onLike: (id: string) => this.commentApiAction('commentLike', id) })
    } else if (this.activeSheetKind === 'save') {
      PinWebSaveSheet({ result: this.pinStore.saveResult, onRetry: () => this.openApiBoards(),
        onCreatingChange: (creating: boolean) => this.pinStore.saveCreating = creating,
        onSave: (id: string) => this.saveApiAction('boardsSave', ',' + JSON.stringify(id)),
        onCreate: (name: string, secret: boolean) => this.saveApiAction('boardsCreate', ',' + JSON.stringify(name) + ',' + secret.toString()),
        onRemove: () => this.saveApiAction('boardsRemove') })
    } else if (this.activeSheetKind === 'publish') {
      PinWebPublishSheet({
        options: this.profileStore.publishOptions,
        loading: this.profileStore.publishLoading,
        onSelect: (id: string) => this.selectProfilePublish(id),
        onRetry: () => this.refreshProfilePublish()
      })
    } else if (this.activeSheetKind === 'profileMenu') {
      this.buildProfileMenuSheet()
    } else if (this.activeSheetKind === 'more') {
      this.buildMoreSheet()
    } else if (this.activeSheetKind === 'searchFilter') {
      this.buildSearchFilterSheet()
    } else {
      this.buildShareSheet()
    }
  }

  @Builder
  private buildHomeRootContent() {
          if ((this.homePresentationPageKey() || this.retainedHomeRootPageKey()) &&
              (!this.nativeRootOnly || this.homeStore.home || this.homeStore.cachedHome)) {
            PinWebHomePage({
              prefetchedImageUrls: this.pinStore.prefetchedImageUrls,
              feedActive: (!this.nativeRootOnly || this.rootContentInteracted) && this.activeTab === 0 && this.pinStore.videoForeground && !this.activeSheetKind && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.currentPinUrl(),
              mediaActive: this.activeTab === 0 && this.pinStore.videoForeground && !this.activeSheetKind && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.currentPinUrl(),
              onContentScroll: (offset: number, state: ScrollState) => this.handleRootContentScroll(offset, state),
              home: this.homeStore.homeForPresentation(this.homePresentationPageKey() || this.retainedHomeRootPageKey()) || this.homePlaceholder(),
              actionsReady: this.activeTab === 0 && this.homeStore.homeActionsReady && this.pendingWebTab !== 0 &&
                this.currentHomePageKey() === (this.homePresentationPageKey() || this.retainedHomeRootPageKey()),
              navigationReady: this.activeTab === 0 && !!this.homeStore.homeForPresentation(
                this.homePresentationPageKey() || this.retainedHomeRootPageKey()) &&
                this.authStatus === 'authenticated',
              interactionReady: this.activeTab === 0 && this.authStatus === 'authenticated',
              menuReady: this.homeMenuReady(),
              initialScrollOffset: this.homeStore.cachedHomeScrollOffset,
              pendingTabId: this.homeStore.pendingHomeTab,
              menuLoadingId: this.homeStore.homeMoreLoadingId,
              loading: this.homeStore.homeLoading ||
                !this.homeStore.homeForPresentation(this.homePresentationPageKey() || this.retainedHomeRootPageKey()) && !this.homeStore.homeError,
              // A retained snapshot is immediately usable for display while
              // the hidden Web document re-confirms the current session. Keep
              // controls gated by actionsReady, but do not replace visible
              // cards with a recovery banner on every root-tab return.
              synchronizing: this.activeTab !== 0 || !!this.homeStore.pendingHomeTab ||
                ((this.pendingWebTab === 0 || !this.homeStore.homeActionsReady) &&
                  !this.homeStore.homeForPresentation(this.homePresentationPageKey() || this.retainedHomeRootPageKey())),
              offlinePreview: this.offlinePreviewMode,
              refreshing: this.homeStore.homeRefreshing,
              error: this.homeStore.homeError,
              onTab: (id: string) => this.selectHomeTab(id),
              onPin: (id: string) => this.openHomePin(id),
              onMore: (id: string) => this.openHomeMore(id),
              onLoadMore: () => this.loadMoreHome(),
              onRefresh: () => this.refreshHome(),
              onPrefetchPins: (first: number, last: number) => this.prefetchHomePinDetails(first, last),
              onScrollPosition: (pageKey: string, offset: number) => {
                if (this.homeStore.cachedHome?.pageKey === pageKey) this.homeStore.cachedHomeScrollOffset = offset;
              },
              onRetry: () => this.refreshHome()
            })
            .width('100%')
            .height('100%')
            .visibility(this.activeTab === 0 ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(this.activeTab === 0 ? HitTestMode.Default : HitTestMode.None)
            .onTouch((event: TouchEvent) => {
              if (this.activeTab === 0 && event.type === TouchType.Move) this.rootContentInteracted = true;
            })
          }

  }

  @Builder
  private buildOfflinePreviewContent() {
    Stack() {
      this.buildHomeRootContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private buildSearchRootContent() {
          if ((this.searchStore.search || this.searchStore.searchLoading || this.searchStore.searchError) &&
              this.shouldKeepSearchRootMounted() && !this.pinStore.detail && !this.loadFailed) {
            PinWebSearchPage({
              interactionReady: this.activeTab === 1 && this.authStatus === 'authenticated',
              automaticLoadingEnabled: this.activeTab === 1 && (!this.nativeRootOnly || this.rootContentInteracted),
              mediaActive: this.activeTab === 1 && this.pinStore.videoForeground && !this.activeSheetKind && !this.pinStore.detail && !this.currentPinUrl(),
              onContentScroll: (offset: number, state: ScrollState) => this.handleRootContentScroll(offset, state),
              snapshot: this.searchStore.search || this.searchPlaceholder(),
              actionsReady: this.activeTab === 1 && this.searchStore.searchActionsReady &&
                this.searchStore.search?.pageKey === this.currentSearchPageKey(),
              initialResultsScrollOffset: this.searchStore.searchScrollOffset,
              onResultsScrollPosition: (pageKey: string, offset: number) => {
                if (this.currentSearchPageKey() !== pageKey || this.currentPinUrl() || this.pinStore.detail) return;
                this.searchStore.searchCache.updateScrollOffset(pageKey, offset);
                if (this.searchStore.search?.pageKey === pageKey) this.searchStore.searchScrollOffset = offset;
                if (this.searchStore.retainedSearch?.pageKey === pageKey) this.searchStore.retainedSearchScrollOffset = offset;
              },
              loading: this.searchStore.searchLoading,
              error: this.searchStore.searchError,
              onQueryChange: (value: string, refreshSuggestions?: boolean) => this.updateSearchQuery(value, refreshSuggestions === true),
              onSubmit: (value: string) => this.submitSearch(value),
              onCategory: (id: string) => this.performSearchAction(id, 'category'),
              onSuggestion: (id: string) => this.performSearchAction(id, 'suggestion'),
              historyActionsReady: this.activeTab === 1 && this.authStatus === 'authenticated' && (this.searchStore.searchInputReady || this.searchStore.searchActionsReady),
              onDeleteHistory: (id: string) => this.performSearchAction(id, 'deleteHistory'),
              onResult: (id: string) => this.performSearchAction(id, 'result'),
              onExploreAction: (id: string, kind: string) => this.performSearchAction(id, kind),
              onLoadMore: () => { this.rootContentInteracted = true; this.loadMoreSearch(); },
              onRetry: () => this.refreshSearch(),
              refreshing: this.rootPullKind === 'search',
              onRefresh: () => this.pullRefreshRoot('search'),
              onBack: () => {
                if (!this.returnFromSearchQuiz()) this.backFromSearch();
              },
              onQuizAction: (kind: string, id: string) => this.performSearchQuizAction(kind, id),
              onFilters: () => this.openSearchFilters(),
              onInputFocusChange: (focused: boolean, stopEditing: () => void) => {
                const visible: boolean = this.shouldKeepSearchPageMounted();
                this.searchStore.searchInputFocused = visible && focused;
                this.searchStore.searchInputStopEditing = visible && focused ? stopEditing : undefined;
              }
            })
            .width('100%')
            .height('100%')
            .visibility(this.nativeSearchPageVisible() ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(this.nativeSearchPageVisible() ? HitTestMode.Default : HitTestMode.None)
            .onTouch((event: TouchEvent) => {
              if (this.activeTab === 1 && event.type === TouchType.Move) this.rootContentInteracted = true;
            })
          }

  }

  @Builder
  private buildInboxRootContent() {
          if ((this.inboxStore.inbox || this.inboxStore.inboxLoading || this.inboxStore.inboxError) && !this.inboxStore.inboxWebFlow &&
              !this.pinStore.detail && !this.activeSheetKind && !this.loadFailed) {
            PinWebInboxPage({ onUser: (url: string) => this.openUserProfile(url),
              interactionReady: this.activeTab === 2 && this.authStatus === 'authenticated',
              onScrollAvailability: (scrollable: boolean) => this.updateInboxScrollAvailability(scrollable),
              onContentScroll: (offset: number, state: ScrollState) => this.handleRootContentScroll(offset, state),
              snapshot: this.inboxStore.inbox || this.inboxPlaceholder(),
              actionsReady: this.activeTab === 2 && this.inboxStore.inboxActionsReady &&
                this.inboxStore.inbox?.pageUrl === this.currentInboxUrl(),
              sectionReady: this.activeTab === 2 && this.inboxStore.inboxSectionReady &&
                this.inboxStore.inbox?.pageUrl === this.currentInboxUrl(),
              retainedContent: this.inboxStore.inboxRetainedContent,
              initialScrollOffset: this.inboxStore.inboxScrollOffset,
              onScrollPosition: (url: string, section: string, offset: number) => {
                if (!this.inboxStore.inbox || this.inboxStore.inbox.pageUrl !== url || this.inboxStore.inbox.section !== section ||
                    this.currentInboxUrl() !== url) return;
                this.inboxStore.inboxScrollOffset = offset;
                if (this.inboxStore.inboxActionsReady && !this.inboxStore.inboxLoading && !this.inboxStore.inboxError) this.inboxStore.inboxCache.put(this.inboxStore.inbox, offset);
              },
              loading: this.inboxStore.inboxLoading,
              error: this.inboxStore.inboxError,
              onSection: (section: string) => this.selectInboxSection(section),
              onLoadMore: () => this.loadMoreInbox(),
              onContactsRetry: () => this.retryInboxContacts(),
              onAction: (id: string) => this.performInboxAction(id),
              onHome: () => this.selectNativeRootTab(0),
              onRetry: () => this.retryInbox(),
              refreshing: this.rootPullKind === 'inbox',
              onRefresh: () => this.pullRefreshRoot('inbox')
            })
            .width('100%')
            .height('100%')
            .visibility(this.activeTab === 2 ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(this.activeTab === 2 ? HitTestMode.Default : HitTestMode.None)
          }

  }

  @Builder
  private buildProfileRootContent() {
    if (this.profileStore.origins.length === 0) { this.buildProfileContent() }
  }

  private showInboxBlockSnack(blocked: boolean, userName: string): void {
    this.dismissPostSnack();
    const token: number = this.postSnackToken;
    if (!this.postSnack) this.postSnack = new HdsSnackBar(this.getUIContext());
    this.postSnack.show({}, { title: blocked ? '已屏蔽 ' + userName : '已取消屏蔽 ' + userName }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: '关闭提示',
      onCloseButtonClick: () => { if (token === this.postSnackToken) this.dismissPostSnack(); }
    }, { duration: 4000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  @Builder
  private buildProfileContent() {
          if ((this.profileStore.profile || this.profileStore.profileLoading || this.profileStore.profileError) &&
              !this.profileStore.profileWebFlow && !this.pinStore.detail && !this.loadFailed) {
            Stack() {
              if (this.profileStore.profile && !this.profileStore.profileWebFlow && !this.pinStore.detail && !this.loadFailed) {
                PinWebProfilePage({
                  interactionReady: this.authStatus === 'authenticated' &&
                    (this.activeTab === 3 || this.profileStore.origins.length > 0),
                  automaticLoadingEnabled: (!this.nativeRootOnly || this.rootContentInteracted) &&
                    (this.activeTab === 3 || this.profileStore.origins.length > 0),
              onContentScroll: (offset: number, state: ScrollState) => this.handleRootContentScroll(offset, state),
                  profile: this.profileStore.profile,
                  onUser: (url: string) => this.openUserProfile(url),
                  onBack: this.profileStore.origins.length > 0 ? () => this.backFromUserProfile() : undefined,
                  actionsReady: this.profileStore.profileActionsReady &&
                    this.profileStore.profile?.profileUrl === this.currentProfileUrl(),
                  syncError: this.profileStore.profileError,
                  initialScrollOffset: this.profileStore.profileScrollOffset,
                  onScrollPosition: (url: string, section: string, offset: number) => {
                    if (!this.profileStore.profile || this.profileStore.profile.profileUrl !== url || this.profileStore.profile.section !== section ||
                        this.currentProfileUrl() !== url) return;
                    this.profileStore.profileScrollOffset = offset;
                    if (this.profileStore.profileActionsReady) this.profileStore.profileCache.put(this.profileStore.profile, offset);
                  },
                  loading: this.profileStore.profileSwitching,
                  onTab: (section: string) => this.changeProfileTab(section),
                  onAction: (id: string, kind: string) => { if (kind === 'edit' || kind === 'followers' || kind === 'following') this.openProfilePanel(kind); else if (kind === 'follow') this.followProfileUser(); else this.performProfileAction(id); },
                  onBoard: (id: string) => this.openProfileBoard(id),
                  onPin: (id: string) => { this.traceAction('profile.pin.open'); this.performProfileAction(id); },
                  onPinMore: (id: string) => this.openProfilePinMenu(id),
                  onPublish: () => this.openProfilePublish(),
                  onSettings: () => {
                    if (this.authStatus === 'authenticated') {
                      this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => { this.profileSettingsVisible = true; });
                    }
                  },
                  followingBusy: this.profileFollowingBusy, onShare: () => this.openProfileShare(),
                  onMenu: () => this.openProfileMenu(),
                  onLoadMore: () => { this.rootContentInteracted = true; this.loadMoreProfile(); },
                  onRetry: () => this.refreshProfile(),
                  onRefresh: () => this.refreshProfile(true),
                  refreshing: this.profileStore.profilePullRefreshing,
                  onOrganize: (action: string, value: string, secret: boolean) => this.organizeProfile(action, value, secret)
                })
                .width('100%')
                .height('100%')
              } else if ((this.profileStore.profileLoading || this.profileStore.profileError) && !this.profileStore.profileWebFlow &&
                         !this.pinStore.detail && !this.loadFailed) {
                this.buildProfileStatus()
              }
            }
            .width('100%')
            .height('100%')
            .visibility(this.profileStore.origins.length > 0 || this.activeTab === 3 ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(this.profileStore.origins.length > 0 || this.activeTab === 3 ? HitTestMode.Default : HitTestMode.None)
            .onTouch((event: TouchEvent) => {
              if (this.activeTab === 3 && event.type === TouchType.Move) this.rootContentInteracted = true;
            })
          }

  }

  @Builder
  private buildRootStatus(index: number) {
    if (!this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.extractPinUrl(this.nativeDisplayAddress())) {
            PinWebStatusPage({ title: ['主页', '搜索', '收件箱', '我的'][index],
              message: this.nativeRootOnly ? '正在准备内容…' :
                this.webPageLoading || this.pendingWebTab !== -1 ? '正在加载内容…' : '尚未取得此页面的原生内容',
              loading: this.nativeRootOnly || this.webPageLoading || this.pendingWebTab !== -1,
              showBack: !this.nativeRootTabsVisible(),
              onRetry: () => this.requestRootPage(index), onBack: () => this.backOnePage(),
              logStatus: PinWebRuntimeLog.savedStatus(), exportingLog: this.exportingRuntimeLog,
              onExportLog: () => { this.exportRuntimeLog(); } })
    }

  }

  @Builder
  private buildRootError(index: number) {
          if (this.loadFailed) {
            Column({ space: 16 }) {
              Text(['主页', '搜索', '收件箱', '我的'][index] + '加载失败')
                .fontSize(16)
                .fontColor($r('app.color.primary_text'))
              Text(this.failureDetails)
                .fontSize(12)
                .fontColor($r('app.color.secondary_text'))
                .textAlign(TextAlign.Center)
                .maxLines(3)
                .margin({ left: 24, right: 24 })
              Button($r('app.string.retry'))
                .onClick(() => {
                  this.reload();
                })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.page_background'))
          }
  }

  @Builder
  private buildRootTabs() {
    HdsTabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.activeTab }) {
      TabContent() {
        Stack() {
          this.buildRootStatus(0)
          this.buildHomeRootContent()
          this.buildRootError(0)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(0, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab('主页', $r('sys.symbol.house'), 0))
      TabContent() {
        Stack() {
          this.buildRootStatus(1)
          this.buildSearchRootContent()
          this.buildRootError(1)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(1, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab('搜索', $r('sys.symbol.magnifyingglass'), 1))
      TabContent() {
        Stack() {
          this.buildRootStatus(2)
          this.buildInboxRootContent()
          this.buildRootError(2)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(2, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab('收件箱', $r('sys.symbol.ellipsis_bubble'), 2))
      TabContent() {
        Stack() {
          this.buildRootStatus(3)
          this.buildProfileRootContent()
          this.buildRootError(3)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(3, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab('我的', $r('sys.symbol.person'), 3))
    }
            .width('100%')
            .height('100%')
            .onAppear(() => {
              this.floatingTabsMounted = true;
              this.floatingTabsHidden = false;
              this.logPageLifecycle('root-tabs-appear', 'tabsMounted=true');
              this.syncFloatingTabsMotion();
            })
            .onDisAppear(() => {
              this.floatingTabsMounted = false;
              ++this.floatingTabsMotionToken;
              this.logPageLifecycle('root-tabs-disappear', 'tabsMounted=false');
            })
            .vertical(false)
            .scrollable(false)
            .barOverlap(true)
            .barHeight(56)
            .barFloatingStyle({
              barBottomMargin: 28,
              systemMaterialEffect: {
                materialType: hdsMaterial.MaterialType.IMMERSIVE,
                materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
              }
            })
            .animationDuration(0)
            .onTabBarClick((index: number) => {
              this.logPageLifecycle('root-tab-click', 'targetTab=' + index.toString());
              this.selectNativeRootTab(index);
            })
            .onContentWillChange((_currentIndex: number, comingIndex: number): boolean =>
              comingIndex === this.activeTab)
            .backgroundColor(Color.Transparent)
  }

  @Builder
  private networkNoticeView() {
    Row({ space: 8 }) {
      Text('!').fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.detail_on_accent'))
      Text(this.networkNotice).fontSize(14).fontColor($r('app.color.detail_on_accent'))
        .maxLines(2).layoutWeight(1)
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.accent'))
    .borderRadius(10)
    .margin({ bottom: 18 })
    .visibility(this.networkNotice.length > 0 ? Visibility.Visible : Visibility.None)
    .accessibilityText(this.networkNotice)
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Bottom }) {
        // Keep the session host mounted; hiding its parent does not destroy Cookie/session state.
        Stack() {
          Web({ src: PINTEREST_URL, controller: this.controller })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .darkMode(WebDarkMode.Auto)
            .forceDarkAccess(true)
            .javaScriptProxy({
              object: this.shareBridge,
              name: 'PinWebShareBridge',
              methodList: ['authState', 'postState', 'share', 'navigation', 'pageNavigation', 'pageBack', 'sheetState', 'moreState', 'detailState',
                'profileState', 'profilePublish', 'boardState', 'inboxState', 'homeState', 'searchState', 'networkRequest', 'cancelNetwork'],
              controller: this.controller
            })
            .runJavaScriptOnDocumentStart(this.documentStartScripts)
            .onControllerAttached(() => {
              this.installDownloadDelegate();
              this.configureDocumentRetention(this.authStatus === 'authenticated');
            })
            .onPageBegin((event) => {
              if (this.ignoreSupersededDetailDocument(event.url)) return;
              if (this.nativeRootOnly && !isPinterestAuthRoute(event.url)) {
                // Keep the selected screen, but a real hidden document change
                // still invalidates controls and in-flight session reads.
                try {
                  if (this.pageHistory.key(event.url) === this.pageHistory.key(this.controller.getUrl())) {
                    this.authEpoch++;
                    this.nativeNetwork.invalidate();
                    this.homeStore.homeActionsReady = false;
                    this.searchStore.searchActionsReady = false;
                    this.searchStore.searchInputReady = false;
                    this.inboxStore.inboxActionsReady = false;
                    this.inboxStore.inboxSectionReady = false;
                    this.profileStore.profileActionsReady = false;
                  }
                } catch (_) {}
                PinWebRuntimeLog.info('RootTabTrace: background-page-begin ignored mode=presentation-only');
                return;
              }
              if (this.pinStore.detailPresentationOnly && !isPinterestAuthRoute(event.url)) {
                PinWebRuntimeLog.info('PinWebReturn: background navigation ignored for cached parent');
                return;
              }
              const beginAt: number = Date.now();
              const documentKind: string = isPinterestAuthRoute(event.url) ? 'auth' :
                this.rootTabKindFromAddress(event.url);
              const documentRoot: number = this.rootTabIndexFromAddress(event.url);
              const targetPinUrlAtBegin: string = this.extractPinUrl(event.url);
              const rootRequestTarget: number = this.staleRootDocumentTarget();
              const rootGuardConfirmed: boolean = this.rootTabGuardTarget >= 0 &&
                this.rootTabGuardTarget === documentRoot;
              const explicitDetailOpening: boolean = !!this.pinStore.detailOpeningPin ||
                (!!this.homeStore.pendingHomeMorePin && !!targetPinUrlAtBegin &&
                  this.pinIdentity(this.homeStore.pendingHomeMorePin) === this.pinIdentity(targetPinUrlAtBegin));
              const staleSecondaryDocument: boolean = rootRequestTarget >= 0 &&
                !!targetPinUrlAtBegin && !explicitDetailOpening && !this.nativeBackTarget;
              const staleRootDocument: boolean = this.isStaleRootDocumentBegin(event.url);
              this.logPageLifecycle('web-page-begin', 'kind=' + documentKind +
                (staleRootDocument ? ' staleRoot=true' : staleSecondaryDocument ? ' staleSecondary=true' : ''));
              // A root-tab request can leave one late Pin document callback in
              // the WebView history. It is not a new user action; accepting it
              // would reopen the previous detail over the selected root tab.
              if (staleSecondaryDocument) {
                PinWebRuntimeLog.info('RootTabTrace: stale-secondary-page-begin ignored targetTab=' +
                  this.staleRootDocumentTarget().toString());
                return;
              }
              if (staleRootDocument) {
                PinWebRuntimeLog.info('RootTabTrace: stale-page-begin ignored targetTab=' +
                  this.effectiveRootDocumentTarget().toString() + ' kind=' + documentKind +
                  ' documentTab=' + documentRoot.toString());
                return;
              }
              if (documentRoot >= 0) {
                PinWebRuntimeLog.info('RootTabTrace: root-visible targetTab=' + documentRoot.toString() +
                  ' kind=' + documentKind + ' pendingTarget=' + this.staleRootDocumentTarget().toString());
              }
              const duplicateBegin: boolean = this.lastDocumentBeginUrl === event.url &&
                beginAt - this.lastDocumentBeginAt < 1500;
              PinWebRuntimeLog.info('StartupTrace: document begin ' +
                (this.isHomeRootAddress(event.url) ? 'home' : isPinterestAuthRoute(event.url) ? 'auth' : 'other') +
                ' duplicate=' + duplicateBegin.toString() + ' epoch=' + this.authEpoch.toString());
              this.lastDocumentBeginUrl = event.url;
              this.lastDocumentBeginAt = beginAt;
              if (this.isHomeRootAddress(event.url)) {
                this.homeTracePageKey = this.homePageKeyFromAddress(event.url);
                this.homeTraceCardsPageKey = '';
              } else {
                this.homeTracePageKey = '';
                this.homeTraceCardsPageKey = '';
              }
              if (duplicateBegin && this.webPageLoading) return;
              if (this.logoutAwaitingLogin) {
                if (!isPinterestAuthRoute(event.url)) return;
                this.logoutAwaitingLogin = false;
              }
              if (this.authStatus !== 'authenticated') {
              }
              if (!isPinterestAuthRoute(event.url) && this.nativeBackTarget &&
                  this.pageHistory.key(event.url) !== this.pageHistory.key(this.nativeBackTarget)) {
                PinWebRuntimeLog.info('PinWebReturn: ignored late source navigation');
                return;
              }
              if (!isPinterestAuthRoute(event.url) && this.pinStore.detailOpeningPin &&
                  this.pinIdentity(this.extractPinUrl(event.url)) !== this.pinIdentity(this.pinStore.detailOpeningPin)) return;
              this.authEpoch++;
              this.retainedHomeAwaitingAuth = false;
              this.retainedHomeAwaitingFeed = false;
              this.nativeNetwork.invalidate();
              if (this.authCheckTimer !== -1) this.pageTasks.cancelTimeout(this.authCheckTimer);
              if (isPinterestAuthRoute(event.url)) {
                if (this.authStatus === 'authenticated') this.resetAuthenticatedContent();
                this.authStatus = 'checking';
              }
            const loadingEpoch: number = this.authEpoch;
            if (this.authStatus !== 'authenticated') {
              this.authCheckTimer = this.pageTasks.timeout(() => {
                if (this.authEpoch !== loadingEpoch || !this.webPageLoading) return;
                if (this.tryEnterOfflinePreview(event.url, 'page-timeout')) return;
                this.authStatus = 'error';
                this.failureDetails = '当前会话页面加载超时，请重试';
              }, 20000);
            }
              this.syncBoardRoute(event.url);
              this.homeStore.customHomeMenuToken++;
              this.homeStore.customHomeMenu = undefined;
              this.webPageLoading = true;
              this.webPageLoadFinishedAt = 0;
              const targetSearchPage: string = this.searchUrlFromAddress(event.url);
               const targetPinUrl: string = targetPinUrlAtBegin;
              if (this.homeStore.pendingHomeMorePin &&
                  this.pinIdentity(targetPinUrl) !== this.pinIdentity(this.homeStore.pendingHomeMorePin)) {
                this.cancelHomeDetailMore();
              }
              this.recordPageNavigation(event.url);
              const keepSearchForTargetPin: boolean = !!targetPinUrl && !!this.searchStore.search &&
                this.searchStore.searchReturnPageKey === this.searchStore.search.pageKey;
              if (targetPinUrl && !this.extractPinUrl(this.lastPageUrl) && !this.pinStore.detailReturnUrl) {
                this.pinStore.detailReturnUrl = this.lastPageUrl || PINTEREST_URL;
              }
              const expectedProfile: boolean = this.profileStore.profileLoading &&
                (this.activeTab === 3 || this.pendingWebTab === 3) || this.profileStore.profileWebFlow;
              if (this.profileStore.profileWebFlow && !this.profileUrlFromAddress(event.url)) {
                this.profileStore.profileFlowLeftPage = true;
              }
              if (targetPinUrl) this.beginDetailOpening(targetPinUrl);
              else this.clearDetail();
              this.clearProfile(this.profileStore.profileWebFlow && !this.profileUrlFromAddress(event.url));
              if (/\/(?:login|logout|signup)(?:\/|[?#]|$)/i.test(event.url)) this.profileStore.profileCache.clear();
              this.restoreProfile(event.url);
              this.clearInbox();
              this.restoreInbox(event.url);
              const retainingRootDocument: boolean = this.retainedRootTabPending >= 0 &&
                this.retainedRootTabPending === documentRoot &&
                (this.retainedRootTabPending === this.pendingWebTab || rootGuardConfirmed) &&
                this.pageHistory.key(event.url) === this.pageHistory.key(this.retainedRootTabAddress);
              const retainingHomeDocument: boolean = this.retainedHomeDocumentPending &&
                this.isHomeRootAddress(event.url) && !!this.homeStore.cachedHome?.pins.length &&
                this.homeStore.cachedHome?.pageKey === this.homePageKeyFromAddress(event.url) &&
                this.pageHistory.key(event.url) === this.pageHistory.key(this.retainedHomeDocumentAddress);
              if (retainingRootDocument) {
                PinWebRuntimeLog.info('RootTabTrace: retained-document targetTab=' +
                  this.retainedRootTabPending.toString());
                this.retainedRootTabPending = -1;
                this.retainedRootTabAddress = '';
              }
              if (rootGuardConfirmed) this.clearRootTabGuard('root-visible');
              if (retainingHomeDocument) {
                this.retainedHomeDocumentPending = false;
                this.retainedHomeDocumentAddress = '';
              }
              this.prepareHomeForPageBegin(event.url, retainingHomeDocument);
              if (retainingHomeDocument) {
                // The native home snapshot is already visible while ArkWeb
                // restores the hidden route. Pause the new document's home
                // observer/API demand so a fresh feed cannot replace the
                // returned cards before the user explicitly refreshes.
                this.controller.runJavaScript('window.PinWebHomePauseForReturn && window.PinWebHomePauseForReturn()')
                  .then(() => PinWebRuntimeLog.info('RootTabTrace: retained-home-guarded'))
                  .catch(() => PinWebRuntimeLog.warn('RootTabTrace: retained-home-guard-unavailable'));
              }
              if (targetSearchPage) {
                if (!this.searchStore.search || this.searchStore.search.pageKey !== targetSearchPage) this.restoreRetainedSearch(targetSearchPage);
                const hasCachedSearch: boolean = !!this.searchStore.search && this.searchStore.search.pageKey === targetSearchPage;
                if (hasCachedSearch) {
                  this.searchStore.searchLoading = false;
                  this.searchStore.searchError = '';
                } else {
                  this.clearSearch();
                  this.searchStore.searchLoading = true;
                  this.searchStore.searchError = '';
                }
                this.showNativeTabs = true;
                if (!hasCachedSearch) setTimeout(() => this.expectSearch(), 350);
              } else if (keepSearchForTargetPin) {
                this.searchStore.searchLoading = false;
                this.searchStore.searchError = '';
              } else {
                this.clearSearch();
              }
              if (this.inboxUrlFromAddress(event.url)) this.expectInbox();
              if (/\/(?:login|logout|signup)(?:\/|[?#]|$)/i.test(event.url)) this.clearRootTabCaches();
              if (this.profileUrlFromAddress(event.url) &&
                  (expectedProfile || /\/_(?:saved|created)(?:\/|[?#]|$)/i.test(event.url))) {
                this.expectProfile();
              }
              const keepPublish: boolean = this.profilePublishPreparing && this.activeSheetKind === 'publish' &&
                this.pendingWebTab === 3 && !!this.profileUrlFromAddress(event.url);
              if (!keepPublish) {
                this.showNativeSheet = false;
                this.activeSheetKind = '';
              }
              this.pinStore.shareSession = 0;
              this.pinStore.ignoredShareSession = 0;
              this.pinStore.shareOpenRequestedSession = 0;
              this.pinStore.sharePin = '';
              this.pinStore.shareOptions = [];
              this.pinStore.shareActions = [];
              this.pinStore.shareContacts = [];
              this.pinStore.shareOnPinDetail = false;
              this.pinStore.shareTitle = '';
              this.pinStore.shareSectionLabel = '';
              this.pinStore.shareError = '';
              this.pinStore.shareFeedback = '';
              this.pinStore.shareLoading = false;
              this.pinStore.moreSession = 0;
              this.pinStore.moreApiMode = false;
              this.pinStore.ignoredMoreSession = 0;
              this.pinStore.morePin = '';
              this.pinStore.moreTitle = '';
              this.pinStore.moreOptions = [];
              this.pinStore.moreError = '';
              this.pinStore.moreLoading = false;
              this.lastPageUrl = event.url;
              this.navigationAddress = event.url;
              if (targetPinUrl) this.bindCurrentDetailDocument(event.url);
              this.loadFailed = false;
              this.failureDetails = '';
              if (event.url.includes('/pin/') || event.url.includes('/login') || event.url.includes('/signup')) {
                this.showNativeTabs = false;
              }
            })
            .onPageEnd(() => {
              this.logPageLifecycle('web-page-end');
              try {
                if (this.ignoreSupersededDetailDocument(this.controller.getUrl())) {
                  this.webPageLoading = false;
                  return;
                }
              } catch (_) {}
              if (this.nativeRootOnly) { this.syncAuthentication(); return; }
              this.webPageLoading = false;
              this.webPageLoadFinishedAt = Date.now();
              this.refreshWebNavigation();
              try { this.bindCurrentDetailDocument(this.controller.getUrl()); } catch (_) {}
              this.syncAuthentication();
            })
            .onConsole((event) => {
              if (!event) return false;
              const message: string = event.message.getMessage();
              if (/^PinWebNetworkDiagnostic: fetch observer failed (TypeError|SyntaxError|AbortError|Error|UnknownError)$/.test(message)) {
                PinWebRuntimeLog.warn(message);
              }
              if (/^PinWebDiagnostic: (save request|save confirmed|undo save request|undo save confirmed)$/.test(message)) {
                PinWebRuntimeLog.info('Web: ' + message);
              }
              return false;
            })
            .onErrorReceive((event) => {
              if (this.pinStore.detailPresentationOnly) return;
              if (event && event.request.isMainFrame()) {
                const errorInfo: string = event.error.getErrorInfo();
                const safeInfo: string = /^(?:ERR_[A-Z0-9_]+|[A-Za-z0-9_-]{1,32})$/.test(errorInfo) ? errorInfo : 'classified';
                PinWebRuntimeLog.warn('Web: main frame error code=' + event.error.getErrorCode().toString() +
                  ' info=' + safeInfo + ' urlKind=' +
                  (this.isHomeRootAddress(event.request.getRequestUrl()) ? 'home' :
                    isPinterestAuthRoute(event.request.getRequestUrl()) ? 'auth' : 'other'));
                this.handleMainFrameFailure(event.request.getRequestUrl() || this.lastPageUrl,
                  event.error.getErrorCode(), event.error.getErrorInfo());
              }
            })
            .onOverrideUrlLoading((request: WebResourceRequest) => {
              if (this.authStatus !== 'authenticated') return false;
              return this.handleExternalShareTarget(request.getRequestUrl());
            })
            .onLoadIntercept((event) => {
              if (!event || !event.data.isMainFrame() || this.authStatus !== 'authenticated') {
                return false;
              }
              return this.handleExternalShareTarget(event.data.getRequestUrl());
            })
            .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .accessibilityLevel(this.authWebVisible() ? 'auto' : 'no-hide-descendants')
        .opacity(this.authWebVisible() ? 1 : 0)
        .hitTestBehavior(this.authWebVisible() ? HitTestMode.Default : HitTestMode.None)

        if (this.authStatus === 'authenticated') {
          this.buildRootTabs()
          if (this.profileStore.origins.length > 0 && this.currentProfileUrl()) {
            this.buildProfileContent()
          }

          if (this.profileStore.publishFlow) {
            PinWebPublishPage({ state: this.profileStore.publishFlow,
              onAction: (action: string, value: string, secret: boolean) => this.publishFlowAction(action, value, secret) })
              .width('100%').height('100%').transition(NATIVE_PAGE_TRANSITION)
          }

          if (this.profileSettingsVisible) {
            PinWebSettingsPage({ store: this.settingsStore, onRequest: (action: string, value: string) => this.requestAccountSettings(action, value), onBack: () => this.closeProfileSettings(), onEditProfile: () => this.openProfilePanel('edit') })
              .width('100%').height('100%')
              .transition(NATIVE_PAGE_TRANSITION)
          }

          if (this.profileStore.panel) {
            PinWebProfilePanelPage({ snapshot: this.profileStore.panel, followingBusy: this.profileFollowingBusy, onFollow: (id: string) => this.followProfileUser(id), onAvatar: () => this.changeProfileAvatar(), saving: this.profileSaving, onSave: (input: string) => this.saveProfilePanel(input),
              onBoard: (url: string) => { const target: string = this.boardUrlFromAddress(url); if (target) {
                this.boardStore.boardReturnUrl = this.controller.getUrl(); this.closeProfilePanel(); this.controller.loadUrl(target); } }, onUser: (url: string) => this.openUserProfile(url), onBack: () => this.closeProfilePanel(),
              onSection: (section: string) => this.openProfilePanel('following', section) })
              .width('100%').height('100%').transition(NATIVE_PAGE_TRANSITION)
          }
          if (this.boardStore.boardDetail && this.nativeBoardVisible()) {
            PinWebBoardPage({ onUser: (url: string) => this.openUserProfile(url), snapshot: this.boardStore.boardDetail, onBack: () => this.backFromBoard(),
              onPin: (id: string) => { this.traceAction('board.pin.open'); this.boardOperation('open', id); },
              onMore: (id: string) => this.openBoardPinMore(id),
              onShare: () => this.shareCurrentBoard(),
              onLoadMore: () => this.boardOperation('more'), onRetry: () => this.boardOperation('retry'),
              onRefresh: () => this.boardOperation('refresh'),
              onAction: (value: string) => this.boardOperation('flow', value) })
              .width('100%').height('100%')
              .transition(BOARD_PAGE_TRANSITION)
          }

          if (this.inboxStore.inboxFlow && this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl()) {
            PinWebInboxFlowPage({ onUser: (url: string) => this.openUserProfile(url), snapshot: this.inboxStore.inboxFlow,
              onNewsHidden: (newsId: string) => this.showInboxUndoSnack(newsId),
              onNewsRestored: (_newsId: string) => this.showInboxRestoredSnack(),
              onBlockChanged: (blocked: boolean, userName: string) => this.showInboxBlockSnack(blocked, userName),
              onNotifications: () => {
                this.inboxFlowAction('back');
                this.settingsStore.screen = 'notifications'; this.profileSettingsVisible = true; this.readNotifications();
              },
              onPinAction: (action: string, url: string) => {
                if (!this.isCurrentInboxMessagePin(url)) return;
                this.openCustomHomeMenu(url, this.currentInboxUrl(), action);
              },
              onAction: (action: string, value: string) => this.inboxFlowAction(action, value) })
              .width('100%').height('100%')
          }

          if ((this.pinStore.detail || this.pinStore.detailOpeningPin) && !this.pinStore.detailWebFlow && !this.loadFailed) {
            Stack() {
              if (this.pinStore.detail && !this.pinStore.detailWebFlow && !this.loadFailed) {
                ForEach([this.detailRootIdentity()], (_identity: string) => {
                PinWebDetailPage({ onUser: (url: string) => this.openUserProfile(url),
                  detail: this.pinStore.detail,
                  renderIdentity: this.detailRenderIdentity(),
                  traceId: this.pinStore.detailOpeningToken,
                  contentError: this.pinStore.detailApiError,
                  contentRetryable: this.pinStore.detailApiRetryable,
                  onContentRetry: () => this.retryDetailApi(),
                  onPresented: () => {
                    this.detailJourney.mark('view.appeared'); this.detailJourney.mark('interaction.frame.appeared');
                    PinWebRuntimeLog.info('DetailTrace: view appeared openId=' + this.pinStore.detailOpeningToken.toString() + ' elapsedMs=' + (Date.now() - this.detailOpenedAt).toString());
                  },
                  onImageLoaded: (pinUrl: string, imageUrl: string, renderIdentity: string) => {
                    if (renderIdentity !== this.detailRenderIdentity() ||
                        pinUrl !== this.pinStore.detailPin || imageUrl !== this.pinStore.detail?.imageUrl) return;
                    this.pinStore.detailImageFailedPin = '';
                    this.detailImageLoadedUrl = imageUrl;
                    this.signalDetailImageStage('loaded');
                    const current: PinWebDetailSnapshot | undefined = this.pinStore.detail;
                    if (current && (!current.imageStageReady || !current.imageLoaded)) {
                      // Do not make visual display wait for a Web bridge ack.
                      // The bridge remains a best-effort session notification.
                      this.pinStore.detail = {
                        aiLabel: current.aiLabel,
                        originalImageUrl: current.originalImageUrl,
                        carousel: current.carousel,
                        isVideo: current.isVideo,
                        video: current.video,
                        videoError: current.videoError,
                        mediaLoading: current.mediaLoading,
                        mediaError: current.mediaError,
                        mediaKind: current.mediaKind,
                        dataSource: current.dataSource,
                        commentPreview: current.commentPreview,
                        commentLoading: current.commentLoading,
                        commentError: current.commentError,
                        commentsAvailable: current.commentsAvailable,
                        commentEmpty: current.commentEmpty,
                        imageStageReady: true, imageLoaded: true,
                        interactionsSettled: current.interactionsSettled,
                        timingEvent: current.timingEvent,
                        timingDuration: current.timingDuration,
                        error: current.error,
                        retryable: current.retryable,
                        mediaUnsupported: current.mediaUnsupported,
                        relatedLoading: current.relatedLoading,
                        relatedError: current.relatedError,
                        relatedEnded: current.relatedEnded,
                        actionsRetained: current.actionsRetained,
                        commentsRetained: current.commentsRetained,
                        relatedRetained: current.relatedRetained,
                        kind: current.kind,
                        session: current.session,
                        pinUrl: current.pinUrl,
                        imageUrl: current.imageUrl,
                        imageWidth: current.imageWidth,
                        imageHeight: current.imageHeight,
                        title: current.title,
                        description: current.description,
                        creator: current.creator,
                        creatorAvatar: current.creatorAvatar,
                        creatorUrl: current.creatorUrl,
                        sourceLabel: current.sourceLabel,
                        sourceUrl: current.sourceUrl,
                        actions: current.actions,
                        related: current.related
                      };
                      this.detailJourney.mark('main.image.stage=loaded');
                      if (this.detailImageTimer !== -1) this.pageTasks.cancelTimeout(this.detailImageTimer);
                      this.detailImageTimer = -1;
                    }
                    this.detailJourney.mark(this.pinStore.detailActionsReady ? 'main.image.loaded' : 'opening.image.loaded');
                    PinWebRuntimeLog.info('DetailTrace: image loaded openId=' + this.pinStore.detailOpeningToken.toString() + ' elapsedMs=' + (Date.now() - this.detailOpenedAt).toString());
                  },
                  onRelatedImageLoaded: (pinUrl: string) => {
                    if (pinUrl === this.pinStore.detailPin) this.detailJourney.mark(
                      this.pinStore.detail?.kind === 'cached' || this.pinStore.detail?.relatedRetained ?
                        'related.cached.image.loaded' : 'related.first.image.loaded');
                  },
                  imageLayer: this.pinStore.imageLayer,
                  visualResult: this.pinStore.visualResult,
                  onImageLayer: (layer: string) => {
                    if (!layer) this.closeImageLayer();
                    else if (this.pinStore.detailActionsReady && (layer !== 'search' || PIN_VISUAL_SEARCH_API_ENABLED)) {
                      this.pinStore.imageLayer = layer;
                      this.pinStore.visualResult = emptyVisualResult();
                    }
                  },
                  onVisualSearch: (crop: PinWebImageCrop, append: boolean, first: boolean) => this.searchImage(crop, append, first),
                  onDownload: () => this.downloadViewerImage(),
                  onViewerSave: () => this.saveViewerImage(),
                  videoActive: this.pinStore.videoForeground && !this.activeSheetKind && !this.pinStore.detailWebFlow,
                  onVideoRetry: () => {
                    this.controller.runJavaScript('window.PinWebDetailApi && window.PinWebDetailApi.retryMedia()')
                      .catch(() => this.showMessage('视频接口暂不可用，请重试'));
                  },
                  deferredActions: this.pinStore.detailPresentationOnly && !this.pinStore.detailPreparing && this.authStatus === 'authenticated',
                  actionsReady: this.pinStore.detailActionsReady,
                  initialScrollOffset: this.pinStore.detailScrollOffset,
                  onBack: () => this.backFromDetail(),
                  onAction: (id: string, kind: string) => this.performDetailAction(id, kind),
                  onRelated: (id: string) => { this.traceAction('related.pin.open'); this.openImageRelated(id); },
                  onImageError: (pinUrl: string) => {
                    if (this.pinIdentity(pinUrl) !== this.pinIdentity(this.pinStore.detailPin)) return;
                    this.pinStore.detailImageFailedPin = pinUrl;
                    this.detailImageFailedUrl = this.pinStore.detail?.imageUrl || '';
                    this.detailJourney.mark('main.image.failed');
                    this.syncDetailImageStage();
                    this.pinStore.detailCache.remove(this.pinIdentity(pinUrl));
                    PinWebRuntimeLog.info('DetailTrace: image failed; content retained');
                  },
                  onLoadMore: () => this.loadMoreRelated(),
                  onComments: async () => { if (await this.ensureDetailActionContext()) this.openApiComments(); },
                  onCommentsRetry: () => this.retryDetailPreview(),
                  canUndoMore: false,
                  undoMoreBusy: this.pinStore.feedbackUndoBusy,
                  onUndoMore: () => this.undoMoreFeedback(),
                  onScrollPosition: (pinUrl: string, offset: number) =>
                    this.saveDetailScrollPosition(pinUrl, offset)
                })
                .width('100%')
                .height('100%')
                }, (_identity: string) => _identity)
              }

              if (this.pinStore.detailOpeningPin && !this.pinStore.detail && !this.pinStore.detailWebFlow && !this.loadFailed) {
                Column({ space: 16 }) {
                  if (this.pinStore.detailApiError) {
                    Text(this.pinStore.detailApiError).fontSize(14).fontColor($r('app.color.secondary_text'))
                    if (this.pinStore.detailApiRetryable) {
                      Button('重试').onClick(() => this.retryDetailApi())
                    }
                    Button('返回').onClick(() => this.backFromDetail())
                  } else {
                    LoadingProgress().width(36).height(36).color($r('app.color.accent'))
                    Text('正在加载帖子…').fontSize(14).fontColor($r('app.color.secondary_text'))
                  }
                }
                .justifyContent(FlexAlign.Center)
                .width('100%')
                .height('100%')
                .backgroundColor($r('app.color.page_background'))
              }
            }
            .width('100%')
            .height('100%')
            .transition(NATIVE_PAGE_TRANSITION)
          }
          if (this.homeStore.pendingHomeMorePin && !this.loadFailed) {
            Column({ space: 16 }) {
              LoadingProgress().width(36).height(36).color($r('app.color.accent'))
              Text('正在读取 Pin 选项…')
                .fontSize(14)
                .fontColor($r('app.color.secondary_text'))
              Button('返回').onClick(() => {
                this.cancelHomeDetailMore();
                this.backFromDetail();
              })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.page_background'))
          }

        } else if (this.offlinePreviewMode) {
          this.buildOfflinePreviewContent()
        } else if (!this.authWebVisible()) {
          PinWebStatusPage({
            title: this.offlineCacheLoading ? '正在读取最近缓存…' :
              this.authStatus === 'error' ? '当前会话加载失败' : '正在读取已有会话…',
            message: this.offlineCacheLoading ? '' : this.authStatus === 'error' ? this.failureDetails : '',
            loading: this.offlineCacheLoading || this.authStatus !== 'error', onRetry: () => this.retryLogin(),
            logStatus: PinWebRuntimeLog.savedStatus(), exportingLog: this.exportingRuntimeLog,
            onExportLog: () => { this.exportRuntimeLog(); }
          })
        }
      }
      this.networkNoticeView()
    }
    .width('100%')
    .height('100%')
    .padding({ top: !!this.profileStore.publishFlow || (this.profileStore.origins.length > 0 && !!this.currentProfileUrl()) || !!this.profileStore.panel || this.profileSettingsVisible ||
      (!!this.inboxStore.inboxFlow && this.inboxStore.inboxFlow.screen !== 'updatesMenu') ||
      !!this.pinStore.detail || this.nativeSearchPageVisible() || this.nativeBoardVisible() ||
      (!this.pinStore.detail && !!this.profileStore.profile?.organize && !this.profileStore.profileWebFlow) ?
      0 : this.getUIContext().px2vp(this.statusBarHeightPx) })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.showNativeSheet, this.buildNativeSheet(), {
      height: this.activeSheetKind === 'save' || this.activeSheetKind === 'edit' && this.pinStore.editResult.phase === 'boards' ?
        SheetSize.LARGE : this.activeSheetKind === 'comments' ? SheetSize.LARGE : this.activeSheetKind === 'edit' ? SheetSize.FIT_CONTENT :
        this.activeSheetKind === 'share' && this.pinStore.shareSearchActive ? SheetSize.LARGE : SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: this.activeSheetKind !== 'comments',
      title: this.activeSheetKind === 'comments' ? undefined : { title: this.activeSheetKind === 'publish' ? (this.profileStore.publishTitle || '添加到个人资料') :
        this.activeSheetKind === 'edit' ? (this.pinStore.editResult.phase === 'boards' ? (this.pinStore.saveCreating ? '创建图板' : '收藏至图板') : '编辑 Pin 图') : this.activeSheetKind === 'comments' ? '你觉得怎么样？' : this.activeSheetKind === 'save' ?
          (this.pinStore.saveCreating ? '创建图板' : '收藏至图板') : this.activeSheetKind === 'more' ? '选项' :
          this.activeSheetKind === 'searchFilter' ? '筛选器' : this.pinStore.shareTitle },
      backgroundColor: $r('app.color.page_background'),
      maskColor: '#66000000',
      onWillDismiss: (action: DismissSheetAction) => {
        this.pinStore.shareBackHandledUntil = Date.now() + 500;
        this.lastRootBackAt = 0;
        if (this.activeSheetKind === 'edit') {
          if (this.pinStore.editResult.busy || this.pinStore.editResult.picker.busy) return;
          if (this.pinStore.editResult.phase !== 'edit') { this.editPinAction('editPhase', ',"edit"'); return; }
          this.dismissEditPin();
        } else if (this.activeSheetKind === 'comments') this.dismissApiComments();
        else if (this.activeSheetKind === 'save') this.dismissApiBoards();
        else if (this.activeSheetKind === 'publish') this.dismissProfilePublish();
        else if (this.activeSheetKind === 'more') this.dismissMoreSheet();
        else if (this.activeSheetKind === 'share') this.dismissShareSheet();
        else if (this.activeSheetKind === 'searchFilter') this.dismissSearchFilters();
        action.dismiss();
      }
    })
  }
}


