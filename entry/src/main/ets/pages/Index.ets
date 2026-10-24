import { PinmonyUpdateNotice } from 'feature_settings';
import { PinmonySessionHistory } from 'common_session';
import { PinmonyProfileSearchPage, PinmonyProfileSearchPin } from 'feature_profile';
import { PinmonyProfileSearchNativeReads } from '../app/PinmonyProfileSearchNativeReads';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PIN_NATIVE_PROFILE_SETTINGS_ENABLED } from '../app/PinmonyProfileSettingsClient';
import { PinmonyProfileNativeActions, PinmonyProfileNativeActionsPorts } from '../app/PinmonyProfileNativeActions';
import { PinmonySettingsNativeFlow, PinmonySettingsNativePorts } from '../app/PinmonySettingsNativeFlow';
import { PinmonyPublishFlow } from 'feature_profile';
import { PIN_NATIVE_SHARE_PUBLISH_ENABLED } from '../app/PinmonySharePublishClient';
import { PinmonyPublishNativeFlow, PinmonyPublishNativePorts } from '../app/PinmonyPublishNativeFlow';
import { PinmonyShareNativeFlow, PinmonyShareNativePorts } from '../app/PinmonyShareNativeFlow';
import { PinmonyCommentNativeWrites, PIN_NATIVE_COMMENT_WRITES_ENABLED, PinmonyCommentNativePorts } from '../app/PinmonyCommentNativeWrites';
import { PinmonyInboxMenuNative, PinmonyInboxMenuNativePorts } from '../app/PinmonyInboxMenuNative';
import { PinmonyBoardInvitationNative, PinmonyBoardInvitationNativePorts } from '../app/PinmonyBoardInvitationNative';
import { PinmonyPinMenuNative, PinmonyPinMenuNativePorts, PIN_NATIVE_PIN_MENUS_ENABLED } from '../app/PinmonyPinMenuNative';
import { PinmonyPostNativeOperations, PIN_NATIVE_POST_OPERATIONS_ENABLED, PinmonyPostNativePorts } from '../app/PinmonyPostNativeOperations';
import { PinmonyBoardNativeReads, PinmonyBoardNativeReadsPorts, PIN_NATIVE_BOARD_READS_ENABLED } from '../app/PinmonyBoardNativeReads';
import { PinmonyProfileBoardOrigin, PinmonyFollowingBoardReturn } from '../app/PinmonyProfileBoardOrigin';
import { PinmonyProfileNativeReads, PinmonyProfileNativeReadsPorts, PIN_NATIVE_PROFILE_READS_ENABLED } from '../app/PinmonyProfileNativeReads';
import { PinmonyInboxMessagesNativeReads, PinmonyInboxMessagesNativeReadsPorts, PIN_NATIVE_INBOX_MESSAGES_ENABLED } from '../app/PinmonyInboxMessagesNativeReads';
import { PinmonyInboxUpdatesNativeReads, PinmonyInboxUpdatesNativeReadsPorts, PIN_NATIVE_INBOX_UPDATES_ENABLED } from '../app/PinmonyInboxUpdatesNativeReads';
import { PinmonySearchNativeReads, PinmonySearchNativeReadsPorts, PIN_NATIVE_SEARCH_READS_ENABLED } from '../app/PinmonySearchNativeReads';
import { PinmonySearchDiscoveryNativeReads, PinmonySearchDiscoveryNativeReadsPorts, PIN_NATIVE_SEARCH_DISCOVERY_ENABLED } from '../app/PinmonySearchDiscoveryNativeReads';
import { PinmonyHomeNativeReads, PinmonyHomeNativeReadsPorts, PIN_NATIVE_HOME_READS_ENABLED } from '../app/PinmonyHomeNativeReads';
import { descriptionTagSearchUrl } from 'feature_pin';
import { assembleControllerLifecycle, bindStoreNavigation, PinmonyProductControllers } from '../app/PinmonyControllerAssembly';
import { PinmonyBuildHomeRootContent } from '../components/PinmonyHomeRootContent';
import { PinmonyBuildSearchRootContent } from '../components/PinmonySearchRootContent';
import { PinmonyPhotoSearchFlow } from '../app/PinmonyPhotoSearchFlow';
import { PinmonyPhotoHistoryPage } from 'feature_search';
import { PinmonyBuildInboxRootContent } from '../components/PinmonyInboxRootContent';
import { PinmonyBuildProfileRootContent } from '../components/PinmonyProfileRootContent';
import { PinmonyNetworkBridgeCoordinator, PinmonyNetworkBridgeCoordinatorPorts } from '../app/PinmonyNetworkBridgeCoordinator';
import { PinmonyFailureRecoveryCoordinator, PinmonyFailureRecoveryCoordinatorPorts } from '../app/PinmonyFailureRecoveryCoordinator';
import { PinmonyBottomBarCoordinator, PinmonyBottomBarCoordinatorPorts } from '../app/PinmonyBottomBarCoordinator';
import { PinmonyRouteParser } from '../app/PinmonyRouteParser';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyWebLifecycleCoordinator, PinmonyWebLifecycleCoordinatorPorts } from '../app/PinmonyWebLifecycleCoordinator';
import { PinmonySearchFilterSheet, PinmonySearchController, PinmonySearchPorts, PinmonySearchStore,
  PinmonySearchSnapshot } from 'feature_search';
import { PinmonyMoreSheet, PinmonyShareSheet, PinmonySharePanelsController, PinmonySharePanelsControllerPorts,
  PinmonyDetailOperationsController, PinmonyDetailOperationsControllerPorts, PinmonyDetailReadController,
  PinmonyDetailReadControllerPorts, PinmonyPostPanelsController, PinmonyPostPanelsPorts,
  PinmonyImageCrop, PinmonyVisualResult, emptyVisualResult, PIN_VISUAL_SEARCH_API_ENABLED,
  PIN_VISUAL_SEARCH_API_SCRIPT, PinmonyPinStore, PinmonyDetailTrace, PinmonyDetailController,
  PinmonyDetailPorts, PinmonyDetailReadCache, PinmonyDetailReadCachePorts, PinmonyDetailImageStage,
  PinmonyDetailImageStagePorts, PinmonyDetailDocumentBinding, PinmonyDetailDocumentBindingPorts,
  PinmonyPostResult, ShareSheetOption, PinmonyDetailPage, PinmonyDetailAction, PinmonyDetailSnapshot, PinmonyRelatedPin,
  PIN_DETAIL_API_ENABLED, PIN_POST_API_ENABLED, PIN_POST_EXTENSIONS_ENABLED, PinmonyEditPinSheet,
  PinmonySaveSheet, PinmonyCommentsSheet } from 'feature_pin';

import { PinmonyBoardOperationsController, PinmonyBoardOperationsPorts, PinmonyBoardStateController,
  PinmonyBoardStatePorts, PinmonyBoardCollaboratorsController, PinmonyBoardCollaboratorsPorts,
  PinmonyBoardStore, PIN_BOARD_API_ENABLED, PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardPage, boardVisiblePins,
  PinmonyBoardCollaborators, PinmonyBoardCollaboratorsPage, PinmonyBoardSectionPage } from 'feature_board';
import { PinmonyBusinessResultsCoordinator, PinmonyBusinessResultsCoordinatorPorts } from '../app/PinmonyBusinessResultsCoordinator';
import { PinmonyDetailOpeningCoordinator, PinmonyDetailOpeningCoordinatorPorts } from '../app/PinmonyDetailOpeningCoordinator';
import { PinmonyPhotoMenuCoordinator, PinmonyPhotoMenuCoordinatorPorts } from '../app/PinmonyPhotoMenuCoordinator';
import { PinmonySessionCoordinator, PinmonySessionCoordinatorPorts } from '../app/PinmonySessionCoordinator';
import { PinmonyNavigationCoordinator, PinmonyNavigationCoordinatorPorts } from '../app/PinmonyNavigationCoordinator';
import { PinmonyRootContextCoordinator, PinmonyRootContextCoordinatorPorts } from '../app/PinmonyRootContextCoordinator';

import { PinmonyInboxReadController, PinmonyInboxReadPorts, PinmonyInboxActionsController,
  PinmonyInboxActionsPorts, PinmonyInboxStore, PinmonyBoardInvitationController,
  PinmonyBoardInvitationPorts, PinmonyBoardInvitation, PinmonyBoardInvitationList,
  PIN_BOARD_INVITATION_SCRIPT, PinmonyInboxSnapshot, PIN_INBOX_CONVERSATIONS_API_ENABLED,
  PinmonyInboxFlowSnapshot, PinmonyInboxFlowPage, PinmonyInboxListPage } from 'feature_inbox';
import { PinmonyControllerLifecycle } from '../app/PinmonyControllerLifecycle';
import { PinmonyPagePerformance, ApiCache, CACHE_TTL, hashCacheString, PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyProfileActionsController, PinmonyProfileActionsPorts, PinmonyProfileReadController,
  PinmonyProfileReadPorts, PinmonyPublishController, PinmonyPublishPorts, PinmonyPublishPage,
  PIN_PUBLISH_API_SCRIPT, PinmonyPublishPhoto, pickPublishPhotoUris, readPublishPhoto,
  PinmonyProfilePanel, PinmonyProfilePanelPage, PinmonyProfileStore, PinmonyPublishSheet, PinmonyBoard,
  PinmonyCreatedPin, PinmonyProfileSnapshot, PinmonyPublishOption, PinmonyPublishSnapshot,
  PIN_PROFILE_API_ENABLED } from 'feature_profile';

import { PinmonySystemActions } from '../app/PinmonySystemActions';

import { PinmonyReturnCoordinator, PinmonyReturnPorts } from '../app/PinmonyReturnCoordinator';

import { pinWebDocumentStartScripts } from '../app/PinmonyScriptRegistry';

import { PinmonyHomeController, PinmonyHomePorts, readHomeCache, writeHomeCache, PinmonyHomeStore,
  PinmonyHomeMenuState, PinmonyHomeMenuSheet, PinmonyHomePin, PinmonyHomeSnapshot } from 'feature_home';

import { PinmonyNativeNetwork, PinmonyNetworkContext, PinmonyNetworkJob, PinmonyNetworkReply,
  PIN_NATIVE_NETWORK_ENABLED, useNativeTransport } from 'common_network';
import { PinmonyBuildLoginPage } from '../components/PinmonyLoginPage';
import { PinmonyShareBridge } from '../app/PinmonyShareBridge';

import { webview } from '@kit.ArkWeb';
import { connection } from '@kit.NetworkKit';
import { PinmonyDetailNativeAuxiliary, PIN_NATIVE_DETAIL_AUXILIARY_ENABLED, PinmonyDetailNativeAuxiliaryPorts } from '../app/PinmonyDetailNativeAuxiliary';
import { PIN_NATIVE_DETAIL_READS_ENABLED, PinmonyDetailNativeReads, PinmonyDetailNativeReadsPorts } from '../app/PinmonyDetailNativeReads';
import { PinmonyBusinessSession, PinmonySessionEnvironment, PinmonyBusinessSessionContext, PinmonyAuthStatus, PinmonyAuthMessage, PIN_AUTH_BRIDGE_SCRIPT, PIN_GOOGLE_LOGIN_UNAVAILABLE_SCRIPT, isPinterestAuthRoute, PINTEREST_LOGIN_URL } from 'common_session';
import { PinmonySessionVerification, PIN_NATIVE_LOGIN_LIFECYCLE_ENABLED } from '../app/PinmonySessionVerification';

import { PinmonyStatusPage } from 'common_ui';

import { PinmonySettingsPage, PinmonySettingsStore, PinmonySettingsController, PinmonySettingsPorts,
  PIN_ACCOUNT_SETTINGS_SCRIPT, PIN_NOTIFICATIONS_READ_SCRIPT, PIN_LOGOUT_API_ENABLED, logoutRequestBody,
  logoutResponseSucceeded } from 'feature_settings';

import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';

import { image } from '@kit.ImageKit';
import { HdsTabs, HdsTabsController, HdsAnimationMode, hdsMaterial, HdsSnackBar, SnackBarIconType, SnackBarOperationType } from '@kit.UIDesignKit';

import { PinmonyNavigationHistory } from '../app/PinmonyNavigationHistory';

interface PinmonyProfileSaveResult { pending?: boolean; ok?: boolean; duplicate?: boolean; message?: string; username?: string; }

interface PendingDetailLike {
  id: string;
  pinUrl: string;
  session: number;
  selected: boolean;
  countText: string;
}

interface PinmonyOfflineHomeMarker {
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

interface PinmonySaveIdentity { id: string; }

interface NativeCommentWrite {
  action: string;
  id: string;
  text: string;
  imageUri?: string;
  signature?: string;
}

interface PinmonyBoardOperationAction {
  action: string;
}

@Entry
@Component
struct Index {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  private nativeChildBackUntil: number = 0;

  private traceAction(name: string, detail: string = ''): void {
    if (name !== 'root.tab') this.rootContentInteracted = true;
    if (/\.pin\.open$/.test(name)) this.detailClickedAt = Date.now();
    if (/^detail\.action\.(like|comment|save|share|more)$/.test(name)) this.detailJourney.mark(name + '.clicked', false);
    PinmonyRuntimeLog.info('ActionTrace: click ' + name + (detail ? ' detailLength=' + detail.length.toString() : ''));
  }
  private readonly loginScripts: ScriptItem[] = [{ script: PIN_AUTH_BRIDGE_SCRIPT, scriptRules: ['*'] },
    { script: PIN_GOOGLE_LOGIN_UNAVAILABLE_SCRIPT, scriptRules: ['*'] }];
  private readonly documentStartScripts: ScriptItem[] = pinWebDocumentStartScripts();
  private readonly nativeBusinessRoutesEnabled: boolean = PIN_NATIVE_POST_OPERATIONS_ENABLED && PIN_NATIVE_COMMENT_WRITES_ENABLED && PIN_NATIVE_DETAIL_AUXILIARY_ENABLED && PIN_NATIVE_SEARCH_DISCOVERY_ENABLED && PIN_NATIVE_DETAIL_READS_ENABLED && PIN_NATIVE_HOME_READS_ENABLED && PIN_NATIVE_SEARCH_READS_ENABLED && PIN_NATIVE_PROFILE_READS_ENABLED && PIN_NATIVE_INBOX_MESSAGES_ENABLED && PIN_NATIVE_INBOX_UPDATES_ENABLED && PIN_NATIVE_BOARD_READS_ENABLED && PIN_NATIVE_SHARE_PUBLISH_ENABLED && PIN_NATIVE_PROFILE_SETTINGS_ENABLED && PIN_NATIVE_PIN_MENUS_ENABLED;
  private readonly nativeNetwork: PinmonyNativeNetwork = new PinmonyNativeNetwork();
  private readonly photoSearchFlow: PinmonyPhotoSearchFlow = new PinmonyPhotoSearchFlow({
    jpeg: (bytes: ArrayBuffer) => this.systemActions.jpegFromBytes(bytes),
    session: () => this.nativeBusinessSessionContext(), network: () => this.nativeNetwork,
    page: () => this.currentSearchPageKey(),
    active: () => this.authStatus === 'authenticated' && this.activeTab === 1 && this.nativeSearchPageVisible(),
    pick: () => this.systemActions.pickImage(), read: (uri: string) => this.systemActions.readJpeg(uri),
    open: (url: string, source: string) => this.beginDetailOpening(url, source)
  });
  private readonly detailReadNetwork: PinmonyNativeNetwork = new PinmonyNativeNetwork();
  private readonly coordinatorTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly pageTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly returnCoordinator: PinmonyReturnCoordinator = new PinmonyReturnCoordinator({
    isCurrent: (token: number): boolean => !this.businessSuspended && token === this.pageBackToken,
    isPending: (target: string): boolean => !!this.nativeBackTarget &&
      this.pageHistory.key(this.nativeBackTarget) === this.pageHistory.key(target),
    isHome: (target: string): boolean => this.isHomeRootAddress(target),
    isBoard: (target: string): boolean => !!this.boardUrlFromAddress(target),
    documentMatches: (target: string): boolean => this.pageHistory.key(this.sessionDocumentUrl()) === this.pageHistory.key(target),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    useHistory: (target: string): boolean => this.returnToHistoryEntry(target),
    load: (target: string, token: number): void => this.loadReturnTarget(target, token),
    confirm: (target: string, bindDetail: boolean): void => {
      this.recordPageNavigation(target, 'observe');
      if (bindDetail) this.bindCurrentDetailDocument(target);
      this.syncAuthentication();
    },
    cancelHistory: (): void => this.pageHistory.cancelBack(),
    mark: (event: string): void => this.detailReturnJourney?.mark(event)
  } as PinmonyReturnPorts);
  private readonly boardCollaboratorsController: PinmonyBoardCollaboratorsController = new PinmonyBoardCollaboratorsController({
    board: (): PinmonyBoardDetail | undefined => this.boardStore.boardDetail,
    currentPage: (): string => this.currentBoardUrl(),
    canOpen: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended &&
      !this.boardStore.presentationOnly && !this.activeSheetKind,
    foreground: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended,
    state: (): PinmonyBoardCollaborators | undefined => this.boardStore.collaborators,
    setState: (state: PinmonyBoardCollaborators | undefined): void => { this.boardStore.collaborators = state; },
    token: (): number => this.boardStore.collaboratorsToken,
    nextToken: (): number => ++this.boardStore.collaboratorsToken,
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    jsonText: (value: string): string => this.webJsonText(value),
    feedback: (value: string): void => this.showMessage(value),
    trace: (): void => this.traceAction('board.collaborators')
  } as PinmonyBoardCollaboratorsPorts);
  private detailOpenedAt: number = 0;
  private detailClickedAt: number = 0;
  private readonly detailJourney: PinmonyDetailTrace = new PinmonyDetailTrace();
  private readonly detailReturnJourney: PinmonyDetailTrace = new PinmonyDetailTrace();
  private readonly detailRequestOwners: Map<string, number> = new Map<string, number>();
  private detailImageLoadedUrl: string = '';
  private detailImageFailedUrl: string = '';
  private readonly detailImageStage: PinmonyDetailImageStage = new PinmonyDetailImageStage({
    enabled: (): boolean => PIN_DETAIL_API_ENABLED,
    detail: (): PinmonyDetailSnapshot | undefined => this.pinStore.detail,
    actionsReady: (): boolean => this.pinStore.detailActionsReady,
    openingToken: (): number => this.pinStore.detailOpeningToken,
    hasNativeBackTarget: (): boolean => !!this.nativeBackTarget,
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    schedule: (callback: () => void, delayMs: number): number => this.pageTasks.timeout(callback, delayMs),
    cancel: (id: number): void => this.pageTasks.cancelTimeout(id),
    markJourney: (event: string): void => this.detailJourney.mark(event),
    setError: (message: string): void => { this.pinStore.detailApiError = message; }
  } as PinmonyDetailImageStagePorts);
  private detailCommentsMeasured: boolean = false;
  private detailRelatedMeasured: boolean = false;
  private sharedDetailRequestId: string = '';
  private openingRelated: Promise<PinmonyNetworkReply> | undefined = undefined;
  private openingRelatedToken: number = -1;
  private readonly detailDocumentBindingService: PinmonyDetailDocumentBinding = new PinmonyDetailDocumentBinding({
    enabled: (): boolean => PIN_DETAIL_API_ENABLED && PIN_NATIVE_NETWORK_ENABLED,
    expectedPin: (): string => this.pinStore.detailOpeningPin || this.pinStore.detail?.pinUrl || '',
    detailPin: (): string => this.pinStore.detailPin,
    pinIdentity: (url: string): string => this.pinIdentity(url),
    detailPresentationOnly: (): boolean => this.pinStore.detailPresentationOnly,
    actionsReady: (): boolean => this.pinStore.detailActionsReady,
    openingToken: (): number => this.pinStore.detailOpeningToken,
    isAuthenticated: (): boolean => this.authStatus === 'authenticated',
    isForeground: (): boolean => this.pinStore.videoForeground,
    hasNativeBackTarget: (): boolean => !!this.nativeBackTarget,
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    rootTabGuardTarget: (): number => this.rootTabGuardTarget,
    detailReturnedToRoot: (): boolean => this.detailReturnedToRoot,
    businessSuspended: (): boolean => this.businessSuspended,
    networkContext: (): PinmonyNetworkContext => this.nativeNetworkContext(),
    runJavaScript: (script: string): Promise<string> => this.runSessionScript(script),
    schedule: (callback: () => void, delayMs: number): number => this.pageTasks.timeout(callback, delayMs),
    cancel: (id: number): void => this.pageTasks.cancelTimeout(id),
    markJourney: (event: string): void => this.detailJourney.mark(event),
    warn: (message: string): void => PinmonyRuntimeLog.warn(message)
  } as PinmonyDetailDocumentBindingPorts);
  private returnLoadToken: number = -1;
  private readonly detailReadCache: PinmonyDetailReadCache = new PinmonyDetailReadCache({
    detailPin: (): string => this.pinStore.detailPin,
    currentPin: (): string => this.currentPinUrl(),
    pinIdentity: (url: string): string => this.pinIdentity(url),
    isAuthenticated: (): boolean => this.authStatus === 'authenticated',
    hasNativeBackTarget: (): boolean => !!this.nativeBackTarget,
    markJourney: (event: string): void => this.detailJourney.mark(event)
  } as PinmonyDetailReadCachePorts);
  @State private pinStore: PinmonyPinStore = new PinmonyPinStore();
  @State private boardStore: PinmonyBoardStore = new PinmonyBoardStore();
  @State private settingsStore: PinmonySettingsStore = new PinmonySettingsStore();
  @State private profileStore: PinmonyProfileStore = new PinmonyProfileStore();
  @State private inboxStore: PinmonyInboxStore = new PinmonyInboxStore();
  @State private searchStore: PinmonySearchStore = new PinmonySearchStore();
  @State private homeStore: PinmonyHomeStore = new PinmonyHomeStore();

  private readonly networkBridgeCoordinator: PinmonyNetworkBridgeCoordinator = new PinmonyNetworkBridgeCoordinator({
    nativeNetworkContext: (): PinmonyNetworkContext => this.nativeNetworkContext(),
    controller: (): webview.WebviewController => this.controller,
    businessSuspended: (): boolean => this.businessSuspended,
    setBusinessSuspended: (value: boolean): void => { this.businessSuspended = value; },
    extractPinUrl: (value: string): string => this.extractPinUrl(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
    nativeBackTarget: (): string => this.nativeBackTarget,
    setNativeBackTarget: (value: string): void => { this.nativeBackTarget = value; },
    pageHistory: (): PinmonyNavigationHistory => this.pageHistory,
    detailReturnedToRoot: (): boolean => this.detailReturnedToRoot,
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    pinIdentity: (value: string): string => this.pinIdentity(value),
    detailReadCache: (): PinmonyDetailReadCache => this.detailReadCache,
    detailJourney: (): PinmonyDetailTrace => this.detailJourney,
    detailRequestOwners: (): Map<string, number> => this.detailRequestOwners,
    showNetworkNotice: (message: string = PinmonyI18n.message("pm_connection_unstable_retrying_d0b9af7d")): void => this.showNetworkNotice(message),
    clearNetworkNotice: (): void => this.clearNetworkNotice(),
    nativeNetwork: (): PinmonyNativeNetwork => this.nativeNetwork,
    openingRelated: (): Promise<PinmonyNetworkReply> | undefined => this.openingRelated,
    setOpeningRelated: (value: Promise<PinmonyNetworkReply> | undefined): void => { this.openingRelated = value; },
    openingRelatedToken: (): number => this.openingRelatedToken,
    sharedDetailRequestId: (): string => this.sharedDetailRequestId,
    setSharedDetailRequestId: (value: string): void => { this.sharedDetailRequestId = value; },
    currentPinUrl: (): string => this.currentPinUrl(),
    detailReadNetwork: (): PinmonyNativeNetwork => this.detailReadNetwork,
  } as PinmonyNetworkBridgeCoordinatorPorts);

  private readonly failureRecoveryCoordinator: PinmonyFailureRecoveryCoordinator = new PinmonyFailureRecoveryCoordinator({
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    logoutAwaitingLogin: (): boolean => this.logoutAwaitingLogin,
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    setAuthStatus: (value: PinmonyAuthStatus): void => { if (value !== 'authenticated') this.businessSession.reset(); this.authStatus = value; },
    staleRootDocumentTarget: (): number => this.staleRootDocumentTarget(),
    extractPinUrl: (value: string): string => this.extractPinUrl(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
    nativeBackTarget: (): string => this.nativeBackTarget,
    setNativeBackTarget: (value: string): void => { this.nativeBackTarget = value; },
    rootTabIndexFromAddress: (address: string): number => this.rootTabIndexFromAddress(address),
    effectiveRootDocumentTarget: (): number => this.effectiveRootDocumentTarget(),
    activeTab: (): number => this.activeTab,
    setActiveTab: (value: number): void => { this.activeTab = value; },
    protectedDetailAddress: (): string => this.protectedDetailAddress(),
    rootReadToken: (): number => this.rootReadToken,
    tabRequestToken: (): number => this.tabRequestToken,
    setTabRequestToken: (value: number): void => { this.tabRequestToken = value; },
    rootReadAddress: (): string => this.rootReadAddress,
    navigationAddress: (): string => this.navigationAddress,
    setNavigationAddress: (value: string): void => { this.navigationAddress = value; },
    homePageKeyFromAddress: (url: string): string => this.homePageKeyFromAddress(url),
    homeStore: (): PinmonyHomeStore => this.homeStore,
    searchUrlFromAddress: (address: string): string => this.searchUrlFromAddress(address),
    searchStore: (): PinmonySearchStore => this.searchStore,
    inboxUrlFromAddress: (address: string): string => this.inboxUrlFromAddress(address),
    inboxStore: (): PinmonyInboxStore => this.inboxStore,
    profileUrlFromAddress: (address: string): string => this.profileUrlFromAddress(address),
    profileStore: (): PinmonyProfileStore => this.profileStore,
    interruptedHomePage: (): string => this.interruptedHomePage,
    setInterruptedHomePage: (value: string): void => { this.interruptedHomePage = value; },
    homeRecoveryAttempted: (): boolean => this.homeRecoveryAttempted,
    setHomeRecoveryAttempted: (value: boolean): void => { this.homeRecoveryAttempted = value; },
    homePresentationPageKey: (): string => this.homePresentationPageKey(),
    isHomeRootAddress: (address: string): boolean => this.isHomeRootAddress(address),
    showNativeSheet: (): boolean => this.showNativeSheet,
    homeRecoveryToken: (): number => this.homeRecoveryToken,
    setHomeRecoveryToken: (value: number): void => { this.homeRecoveryToken = value; },
    authEpoch: (): number => this.authEpoch,
    pageBackToken: (): number => this.pageBackToken,
    setPageBackToken: (value: number): void => { this.pageBackToken = value; },
    coordinatorTasks: (): PinmonyTaskRegistry => this.coordinatorTasks,
    pageHistory: (): PinmonyNavigationHistory => this.pageHistory,
    nativeNetwork: (): PinmonyNativeNetwork => this.nativeNetwork,
    lastPageUrl: (): string => this.lastPageUrl,
    setLastPageUrl: (value: string): void => { this.lastPageUrl = value; },
    expectHome: (): void => this.expectHome(),
    controller: (): webview.WebviewController => this.controller,
    businessSuspended: (): boolean => this.businessSuspended,
    setBusinessSuspended: (value: boolean): void => { this.businessSuspended = value; },
    showNetworkNotice: (message: string = PinmonyI18n.message("pm_connection_unstable_retrying_d0b9af7d")): void => this.showNetworkNotice(message),
    webPageLoading: (): boolean => this.webPageLoading,
    setWebPageLoading: (value: boolean): void => { this.webPageLoading = value; },
    webPageLoadFinishedAt: (): number => this.webPageLoadFinishedAt,
    setWebPageLoadFinishedAt: (value: number): void => { this.webPageLoadFinishedAt = value; },
    tryEnterOfflinePreview: (failedUrl: string, reason: string = 'network-failure'): boolean => this.tryEnterOfflinePreview(failedUrl, reason),
    loadFailed: (): boolean => this.loadFailed,
    setLoadFailed: (value: boolean): void => { this.loadFailed = value; },
    failureDetails: (): string => this.failureDetails,
    setFailureDetails: (value: string): void => { this.failureDetails = value; },
    boardUrlFromAddress: (address: string): string => this.boardUrlFromAddress(address),
    boardStore: (): PinmonyBoardStore => this.boardStore,
    pinIdentity: (value: string): string => this.pinIdentity(value),
    pendingWebTab: (): number => this.pendingWebTab,
    setPendingWebTab: (value: number): void => { this.pendingWebTab = value; },
    clearInbox: (): void => this.clearInbox(),
    clearDetail: (preserveRead: boolean = false, localOnly: boolean = false): void => this.clearDetail(preserveRead, localOnly),
    tabsController: (): HdsTabsController => this.tabsController,
    clearHome: (): void => this.clearHome(),
    restoreRetainedSearch: (pageKey: string): boolean => this.restoreRetainedSearch(pageKey),
    clearSearch: (): void => this.clearSearch(),
    rootContextCoordinator: (): PinmonyRootContextCoordinator => this.rootContextCoordinator,
  } as PinmonyFailureRecoveryCoordinatorPorts);

  private readonly bottomBarCoordinator: PinmonyBottomBarCoordinator = new PinmonyBottomBarCoordinator({
    searchResultsVisible: (): boolean => this.activeTab === 1 &&
      (this.searchStore.photoSearchVisible || this.searchStore.searchInputFocused ||
        /[?&]q=[^&#]+/i.test(this.searchStore.search?.pageKey || this.currentSearchPageKey())),
    floatingTabsMounted: (): boolean => this.floatingTabsMounted,
    setFloatingTabsMounted: (value: boolean): void => { this.floatingTabsMounted = value; },
    floatingTabsHidden: (): boolean => this.floatingTabsHidden,
    setFloatingTabsHidden: (value: boolean): void => { this.floatingTabsHidden = value; },
    tabsController: (): HdsTabsController => this.tabsController,
    rootTabsScrollHidden: (): boolean[] => this.rootTabsScrollHidden,
    setRootTabsScrollHidden: (value: boolean[]): void => { this.rootTabsScrollHidden = value; },
    childBottomBarRestoreHidden: (): boolean | null => this.childBottomBarRestoreHidden,
    setChildBottomBarRestoreHidden: (value: boolean | null): void => { this.childBottomBarRestoreHidden = value; },
    inboxContentScrollable: (): boolean => this.inboxContentScrollable,
    setInboxContentScrollable: (value: boolean): void => { this.inboxContentScrollable = value; },
    childBottomBarRootTab: (): number => this.childBottomBarRootTab,
    setChildBottomBarRootTab: (value: number): void => { this.childBottomBarRootTab = value; },
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    activeTab: (): number => this.activeTab,
    nativeRootTabsVisible: (): boolean => this.nativeRootTabsVisible(),
    bottomBarScrollCollapseEnabled: (): boolean => this.bottomBarScrollCollapseEnabled,
    setBottomBarScrollCollapseEnabled: (value: boolean): void => { this.bottomBarScrollCollapseEnabled = value; },
    pinStore: (): PinmonyPinStore => this.pinStore,
    floatingTabsMotionToken: (): number => this.floatingTabsMotionToken,
    setFloatingTabsMotionToken: (value: number): void => { this.floatingTabsMotionToken = value; },
    coordinatorTasks: (): PinmonyTaskRegistry => this.coordinatorTasks,
  } as PinmonyBottomBarCoordinatorPorts);
  private pageLifecycleSequence: number = 0;
  private pageLifecycleStartedAt: number = 0;
  private pageLifecycleLastEventAt: number = 0;
  private homeApiCache: ApiCache | undefined = undefined;
  private homeCacheAccountId: string = '';
  private homeCacheIdentityEpoch: number = -1;
  private homeCacheRestoreAttemptKey: string = '';
  private homeCacheRestoreSkipReason: string = '';
  private offlineHomeMarker: PinmonyOfflineHomeMarker | undefined = undefined;
  @State private offlinePreviewMode: boolean = false;
  @State private offlineCacheLoading: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private authStatus: PinmonyAuthStatus = 'checking';
  private authEpoch: number = 0;
  private readonly sessionEnvironment: PinmonySessionEnvironment = new PinmonySessionEnvironment();
  private readonly businessSession: PinmonyBusinessSession = new PinmonyBusinessSession();
  private authCheckTimer: number = -1;
  private loginRedirectEpoch: number = -1;
  private lastLoginRetryAt: number = -1;
  @State private loginHostMounted: boolean = false;
  @State private loginPageVisible: boolean = true;
  @State private loginStartUrl: string = PINTEREST_LOGIN_URL;
  private nativeSessionEpoch: number = 0;
  private nativeVerificationPending: boolean = false;
  private nativeLoginEvidenceKey: string = '';
  private nativeSessionOrigin: string = 'https://www.pinterest.com';
  private readonly nativeLoginEnabled: boolean = PIN_NATIVE_LOGIN_LIFECYCLE_ENABLED && this.nativeBusinessRoutesEnabled;
  private logoutAwaitingLogin: boolean = false;
  private logoutUnknownAccount: string = '';
  private retainedHomeAwaitingAuth: boolean = false;
  private retainedHomeAwaitingFeed: boolean = false;
  private detailPrefetchTimer: number = -1;
  private authenticatedProfileUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private shareBridge: PinmonyShareBridge = new PinmonyShareBridge();
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
  private publishBoardReturn: string = '';
  @State private boardSectionVisible: boolean = false;
  @State private boardSectionSubmitting: boolean = false;
  private boardSectionToken: number = 0;
  private singlePinMovePage: string = '';
  private retainedBoardContent: PinmonyBoardDetail | undefined = undefined;
  private cancelledBoardPins: Set<string> = new Set<string>();
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
  private postSnackExpiresAt: number = 0;
  @State private loadFailed: boolean = false;
  @State private failureDetails: string = '';
  @StorageLink('bottomBarScrollCollapseEnabled') @Watch('onBottomBarScrollSettingChanged')
  private bottomBarScrollCollapseEnabled: boolean = true;
  @State private floatingTabsHidden: boolean = false;
  @State private showNativeTabs: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private profileSettingsVisible: boolean = false;
  @State @Watch('syncFloatingTabsMotion') private activeTab: number = 0;
  @State private showNativeSheet: boolean = false;
  private postSheetClosed: (() => void) | undefined = undefined;
  private postSheetDismissed: boolean = false;
  private pendingSearchFilterTarget: string = '';
  private pendingSearchFilterSource: string = '';
  @State @Watch('syncFloatingTabsMotion') private activeSheetKind: string = '';
  @State private publishSheetClosing: boolean = false;
  private publishSheetClosed: ((closed: boolean) => void) | undefined = undefined;
  @State private profileShareMode: boolean = false;
  private pendingDetailLike: PendingDetailLike | undefined = undefined;
  private readonly rootTabAddresses: Map<number, string> = new Map<number, string>();
  private nativePinRoute: string = '';
  @State private rootPullKind: string = '';
  private rootPullToken: number = 0;
  private readonly pageHistory: PinmonyNavigationHistory = new PinmonyNavigationHistory();

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
    PinmonyRuntimeLog.info('PageLifecycle: event=' + event +
      ' sequence=' + this.pageLifecycleSequence.toString() +
      ' sinceStartMs=' + sinceStart.toString() +
      ' sincePreviousMs=' + sincePrevious.toString() + ' ' + state +
      (detail ? ' ' + detail : ''));
  }

  private readonly detailReadController: PinmonyDetailReadController = new PinmonyDetailReadController(this.pinStore, {
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    detailReturnedToRoot: (): boolean => this.detailReturnedToRoot,
    nativeBackTarget: (): string => this.nativeBackTarget,
    nativePinRoute: (): string => this.nativePinRoute,
    setNativePinRoute: (value: string): void => { this.nativePinRoute = value; },
    pendingDetailLike: (): PendingDetailLike | undefined => this.pendingDetailLike,
    setPendingDetailLike: (value: PendingDetailLike | undefined): void => { this.pendingDetailLike = value; },
    detailOpenedAt: (): number => this.detailOpenedAt,
    detailCommentsMeasured: (): boolean => this.detailCommentsMeasured,
    setDetailCommentsMeasured: (value: boolean): void => { this.detailCommentsMeasured = value; },
    detailRelatedMeasured: (): boolean => this.detailRelatedMeasured,
    setDetailRelatedMeasured: (value: boolean): void => { this.detailRelatedMeasured = value; },
    detailImageLoadedUrl: (): string => this.detailImageLoadedUrl,
    document: (): string => this.sessionDocumentUrl(),
    addressKey: (value: string): string => this.pageHistory.key(value),
    currentPinUrl: (): string => this.currentPinUrl(),
    mark: (event: string, once: boolean = true, duration: number = 0): void => {
      this.detailJourney.mark(event, once, duration);
      if (event === 'current.snapshot.committed' && this.pinStore.detail) this.pagePerformance.markSecondary('detail', this.pinStore.detail.pinUrl, 'content-ready');
    },
    pinIdentity: (value: string): string => this.pinIdentity(value),
    showMessage: (value: string): void => this.showMessage(value),
    restoreCachedDetail: (value: string): boolean => this.restoreCachedDetail(value),
    hasProfile: (): boolean => !!(this.profileStore.profile || this.profileStore.profileLoading || this.profileStore.profileError),
    clearProfile: (): void => this.clearProfile(),
    externalSourceUrl: (value: string): string => this.externalSourceUrl(value),
    profileUrlFromAddress: (value: string): string => this.profileUrlFromAddress(value),
    withDetailLike: (detail: PinmonyDetailSnapshot, id: string, selected: boolean, count: string): PinmonyDetailSnapshot => this.withDetailLike(detail, id, selected, count),
    syncDetailImageStage: (): void => this.syncDetailImageStage(),
    updateSearchPinTitle: (pin: string, title: string): void => this.updateSearchPinTitle(pin, title),
    updateHomePinTitle: (pin: string, title: string): void => this.updateHomePinTitle(pin, title),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    foreground: (): boolean => !this.businessSuspended && this.authStatus === 'authenticated',
  } as PinmonyDetailReadControllerPorts);

  private readonly detailOperationsController: PinmonyDetailOperationsController = new PinmonyDetailOperationsController(this.pinStore, {
    nativeOpenLayer: PIN_NATIVE_DETAIL_AUXILIARY_ENABLED ? (layer: string): Promise<void> => this.detailNativeAuxiliary.openLayer(layer) : undefined,
    nativeSearch: PIN_NATIVE_DETAIL_AUXILIARY_ENABLED ? (crop: PinmonyImageCrop, append: boolean, first: boolean): Promise<void> => this.detailNativeAuxiliary.search(crop,append,first) : undefined,
    nativeRetryMedia: PIN_NATIVE_DETAIL_AUXILIARY_ENABLED ? (): Promise<void> => this.detailNativeAuxiliary.retryMedia() : undefined,
    nativePause: (): void => this.detailNativeAuxiliary?.pause(),nativeCancelVisual: (): void => this.detailNativeAuxiliary?.cancelVisual(),
    authEpoch: (): number => this.authEpoch,
    authStatus: (): string => this.authStatus,
    businessSuspended: (): boolean => this.businessSuspended,
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    visualStart: (): string => useNativeTransport(PIN_VISUAL_SEARCH_API_SCRIPT),
    document: (): string => this.sessionDocumentUrl(),
    webJsonText: (value: string): string => this.webJsonText(value),
    mark: (event: string): void => this.detailJourney.mark(event),
    pinIdentity: (value: string): string => this.pinIdentity(value),
    currentPinUrl: (): string => this.currentPinUrl(),
    showMessage: (value: string): void => this.showMessage(value),
    ensureDetailActionContext: (): Promise<boolean> => this.ensureDetailActionContext(),
    rejectOfflineAction: (value: string): boolean => this.rejectOfflineAction(value),
  } as PinmonyDetailOperationsControllerPorts);

  private readonly sharePanelsController: PinmonySharePanelsController = new PinmonySharePanelsController(this.pinStore, {
    nativeMenu: (): boolean => PIN_NATIVE_PIN_MENUS_ENABLED,
    nativeMoreOpen: (): Promise<void> => this.pinMenuNative.open(),
    nativeMoreAction: (id: string): Promise<void> => this.pinMenuNative.action(id),
    nativeMenuPause: (): void => this.pinMenuNative.pause(),
    nativeShare: (): boolean => PIN_NATIVE_SHARE_PUBLISH_ENABLED,
    nativeSearch: (value: string): void => this.shareNativeFlow.search(value),
    nativeRefresh: (): Promise<void> => this.shareNativeFlow.refresh(),
    nativeAction: (id: string): Promise<void> => this.shareNativeFlow.action(id),
    nativePause: (): void => this.shareNativeFlow.pause(),
    copyText: (value: string): Promise<void> => this.systemActions.copyText(value),
    currentProfileUrl: (): string => this.currentProfileUrl(),
    profileTitle: (): string => this.profileStore.profile?.displayName || this.profileStore.profile?.handle || this.uiText("pm_pinterest_profile_ccf1ac90"),
    dismissMoreSheet: (): void => this.dismissMoreSheet(),
    sharePinUrl: (pin: string, title: string): Promise<void> => this.sharePinUrl(pin, title),
    traceAction: (name: string, id: string): void => this.traceAction(name, id),
    profileShareMode: (): boolean => this.profileShareMode,
    activeSheetKind: (): string => this.activeSheetKind,
    setActiveSheetKind: (value: string): void => { this.activeSheetKind = value; },
    showNativeSheet: (): boolean => this.showNativeSheet,
    setShowNativeSheet: (value: boolean): void => { this.showNativeSheet = value; },
    customMenu: (): boolean => !!this.homeStore.customHomeMenu,
    pendingHomeMorePin: (): string => this.homeStore.pendingHomeMorePin,
    clearHomeMenuPin: (): void => { this.homeStore.homeMenuPin = ''; },
    document: (): string => this.sessionDocumentUrl(),
    foreground: (): boolean => !this.businessSuspended && this.authStatus === 'authenticated',
    currentShareObjectUrl: (): string => this.currentShareObjectUrl(),
    shareObjectReady: (): boolean => this.shareObjectReady(),
    isCurrentMorePin: (value: string): boolean => this.isCurrentMorePin(value),
    closeMoreWebPanel: (session: number, pin: string): void => this.closeMoreWebPanel(session, pin),
    suspendMoreForShare: (): void => this.suspendMoreForShare(),
    extractPinUrl: (value: string): string => this.extractPinUrl(value),
    showMessage: (value: string): void => this.showMessage(value),
    dismissShareSheet: (): void => this.dismissShareSheet(),
    isCopyLinkAction: (value: string): boolean => this.isCopyLinkAction(value),
    showShareLinkSnack: (): void => this.showShareLinkSnack(),
    showShareFeedbackSnack: (): void => this.showShareFeedbackSnack(),
    pinIdentity: (value: string): string => this.pinIdentity(value),
    cancelHomeDetailMore: (): void => this.cancelHomeDetailMore(),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    webJsonText: (value: string): string => this.webJsonText(value),
    rejectOfflineAction: (value: string): boolean => this.rejectOfflineAction(value),
  } as PinmonySharePanelsControllerPorts);

  private readonly settingsController: PinmonySettingsController = new PinmonySettingsController(this.settingsStore, {
    nativeEnabled: (): boolean => PIN_NATIVE_PROFILE_SETTINGS_ENABLED,
    nativeRequest: (action: string,value: string): Promise<void> => this.settingsNativeFlow.requestAction(action,value),
    nativePause: (): void => this.settingsNativeFlow.pause(),
    authenticated: (): boolean => this.authStatus === 'authenticated', foreground: (): boolean => !this.businessSuspended,
    epoch: (): number => this.authEpoch, visible: (): boolean => this.profileSettingsVisible,
    document: (): string => this.sessionDocumentUrl(), currentProfile: (): string => this.currentProfileUrl(),
    profileAddress: (page: string): string => this.profileUrlFromAddress(page),
    prepare: (current: () => boolean): Promise<boolean> => this.ensureRootActionContext(3, true, '', current),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    accountScript: (): string => useNativeTransport(PIN_ACCOUNT_SETTINGS_SCRIPT),
    notificationsScript: (): string => useNativeTransport(PIN_NOTIFICATIONS_READ_SCRIPT), jsonText: (raw: string): string => this.webJsonText(raw)
  } as PinmonySettingsPorts);
  private readonly inboxActionsController: PinmonyInboxActionsController = new PinmonyInboxActionsController(this.inboxStore, {
    nativeOpen: (id: string): Promise<boolean> => PIN_NATIVE_INBOX_UPDATES_ENABLED && id.startsWith('news-menu:') ? this.inboxMenuNative.open(id) : this.inboxMessagesNativeReads.open(id),
    nativeAction: (action: string,value: string): Promise<boolean> => PIN_NATIVE_INBOX_UPDATES_ENABLED && this.inboxStore.inboxFlow?.screen === 'updatesMenu' ? this.inboxMenuNative.action(action) : this.inboxMessagesNativeReads.action(action,value),
    nativeWrites: (): boolean => this.inboxMessagesNativeReads.ownsFlow(),
    allowed: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 2,
    epoch: (): number => this.authEpoch, document: (): string => this.sessionDocumentUrl(), currentInbox: (): string => this.currentInboxUrl(),
    enabled: (): boolean => PIN_INBOX_CONVERSATIONS_API_ENABLED,
    prepare: (current: () => boolean): Promise<boolean> => this.ensureRootActionContext(2, true, '', current),
    runScript: (script: string): Promise<string> => this.runSessionScript(this.inboxUpdatesNativeReads.installScript() + this.inboxMessagesNativeReads.installScript() + script), feedback: (message: string): void => this.showMessage(message)
  } as PinmonyInboxActionsPorts);

  private readonly rootContextCoordinator: PinmonyRootContextCoordinator = new PinmonyRootContextCoordinator({
    profileUrlFromAddress: (address: string): string => this.profileUrlFromAddress(address),
    activeSheetKind: (): string => this.activeSheetKind,
    activeTab: (): number => this.activeTab,
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    businessSuspended: (): boolean => this.businessSuspended,
    clearRootTabGuard: (reason: string): void => this.clearRootTabGuard(reason),
    controller: (): webview.WebviewController => this.controller,
    coordinatorTasks: (): PinmonyTaskRegistry => this.coordinatorTasks,
    currentHomePageKey: (): string => this.currentHomePageKey(),
    currentInboxUrl: (): string => this.currentInboxUrl(),
    currentProfileUrl: (): string => this.currentProfileUrl(),
    currentSearchPageKey: (): string => this.currentSearchPageKey(),
    expectHome: (): void => this.expectHome(),
    expectInbox: (): void => this.expectInbox(),
    expectProfile: (): void => this.expectProfile(),
    expectSearch: (): void => this.expectSearch(),
    failureDetails: (): string => this.failureDetails,
    setFailureDetails: (value: string): string => { this.failureDetails = value; return value; },
    homeStore: (): PinmonyHomeStore => this.homeStore,
    inboxStore: (): PinmonyInboxStore => this.inboxStore,
    lastDocumentBeginAt: (): number => this.lastDocumentBeginAt,
    lastDocumentBeginUrl: (): string => this.lastDocumentBeginUrl,
    loadFailed: (): boolean => this.loadFailed,
    setLoadFailed: (value: boolean): boolean => { this.loadFailed = value; return value; },
    pageHistory: (): PinmonyNavigationHistory => this.pageHistory,
    pagePerformance: (): PinmonyPagePerformance => this.pagePerformance,
    pendingWebTab: (): number => this.pendingWebTab,
    setPendingWebTab: (value: number): number => { this.pendingWebTab = value; return value; },
    pinStore: (): PinmonyPinStore => this.pinStore,
    profileStore: (): PinmonyProfileStore => this.profileStore,
    retainedRootTabAddress: (): string => this.retainedRootTabAddress,
    setRetainedRootTabAddress: (value: string): string => { this.retainedRootTabAddress = value; return value; },
    retainedRootTabPending: (): number => this.retainedRootTabPending,
    setRetainedRootTabPending: (value: number): number => { this.retainedRootTabPending = value; return value; },
    rootContentInteracted: (): boolean => this.rootContentInteracted,
    setRootContentInteracted: (value: boolean): boolean => { this.rootContentInteracted = value; return value; },
    rootPresentationAddress: (index: number): string => this.rootPresentationAddress(index),
    rootReadAddress: (): string => this.rootReadAddress,
    setRootReadAddress: (value: string): string => { this.rootReadAddress = value; return value; },
    rootReadStartedAt: (): number => this.rootReadStartedAt,
    setRootReadStartedAt: (value: number): number => { this.rootReadStartedAt = value; return value; },
    rootReadToken: (): number => this.rootReadToken,
    setRootReadToken: (value: number): number => { this.rootReadToken = value; return value; },
    rootTabAddresses: (): Map<number, string> => this.rootTabAddresses,
    rootTabGuardAddress: (): string => this.rootTabGuardAddress,
    setRootTabGuardAddress: (value: string): string => { this.rootTabGuardAddress = value; return value; },
    rootTabGuardTarget: (): number => this.rootTabGuardTarget,
    setRootTabGuardTarget: (value: number): number => { this.rootTabGuardTarget = value; return value; },
    rootTabIndexFromAddress: (address: string): number => this.rootTabIndexFromAddress(address),
    searchStore: (): PinmonySearchStore => this.searchStore,
    showMessage: (message: string): void => this.showMessage(message),
    syncAuthentication: (): void => this.syncAuthentication(),
    tabRequestToken: (): number => this.tabRequestToken,
    setTabRequestToken: (value: number): number => { this.tabRequestToken = value; return value; },
    waitForWebTabConfirmation: (index: number, token: number, requestedAt: number): void => this.waitForWebTabConfirmation(index, token, requestedAt),
    webPageLoading: (): boolean => this.webPageLoading,
  } as PinmonyRootContextCoordinatorPorts);

  private readonly navigationCoordinator: PinmonyNavigationCoordinator = new PinmonyNavigationCoordinator({
    rootBack: (): boolean => this.handleRootExitBack(),
    rootPresented: (index: number): void => this.markReturnedHome?.(index),
    nativeBusinessOnly: (): boolean => this.nativeBusinessRoutesEnabled,
    activeSheetKind: (): string => this.activeSheetKind,
    activeTab: (): number => this.activeTab,
    setActiveTab: (value: number): number => { this.activeTab = value; return value; },
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    backFromBoard: (): void => this.backFromBoard(),
    backFromDetail: (): Promise<void> => this.backFromDetail(),
    backFromSearch: (): void => this.backFromSearch(),
    backFromUserProfile: (): void => this.backFromUserProfile(),
    backInProgress: (): boolean => this.backInProgress,
    setBackInProgress: (value: boolean): boolean => { this.backInProgress = value; return value; },
    backOnePage: (fallback?: string, targetOverride?: string): boolean => this.backOnePage(fallback, targetOverride),
    boardCollaboratorsAction: (action: string, value: string): void => this.boardCollaboratorsAction(action, value),
    boardStore: (): PinmonyBoardStore => this.boardStore,
    boardUrlFromAddress: (address: string): string => this.boardUrlFromAddress(address),
    cancelHomeDetailMore: (): void => this.cancelHomeDetailMore(),
    clearDetail: (preserveRead?: boolean, localOnly?: boolean): void => this.clearDetail(preserveRead, localOnly),
    clearRootTabGuard: (reason: string): void => this.clearRootTabGuard(reason),
    closeBoardCollaborators: (): void => this.closeBoardCollaborators(),
    closeImageLayer: (localOnly?: boolean): void => this.closeImageLayer(localOnly),
    closeProfilePanel: (): void => this.closeProfilePanel(),
    closeProfileSettings: (): void => this.closeProfileSettings(),
    controller: (): webview.WebviewController => this.controller,
    controllerLifecycle: (): PinmonyControllerLifecycle => this.controllerLifecycle(),
    currentBoardUrl: (): string => this.currentBoardUrl(),
    currentPinUrl: (): string => this.currentPinUrl(),
    currentProfileUrl: (): string => this.currentProfileUrl(),
    currentSearchPageKey: (): string => this.currentSearchPageKey(),
    currentWebTab: (): number => this.currentWebTab,
    setCurrentWebTab: (value: number): number => { this.currentWebTab = value; return value; },
    detailReadCache: (): PinmonyDetailReadCache => this.detailReadCache,
    detailReturnedToRoot: (): boolean => this.detailReturnedToRoot,
    setDetailReturnedToRoot: (value: boolean): boolean => { this.detailReturnedToRoot = value; return value; },
    dismissApiBoards: (): void => this.dismissApiBoards(),
    dismissApiComments: (): void => this.dismissApiComments(),
    dismissEditPin: (force?: boolean): void => this.dismissEditPin(force),
    dismissMoreSheet: (): void => this.dismissMoreSheet(),
    dismissProfileMenu: (): void => this.dismissProfileMenu(),
    dismissProfilePublish: (): void => this.dismissProfilePublish(),
    dismissSearchFilters: (): void => this.dismissSearchFilters(),
    dismissShareSheet: (): void => this.dismissShareSheet(),
    editPinAction: (method: string, args: string): void => this.editPinAction(method, args),
    extractPinUrl: (value: string): string => this.extractPinUrl(value),
    failureDetails: (): string => this.failureDetails,
    setFailureDetails: (value: string): string => { this.failureDetails = value; return value; },
    homeController: (): PinmonyHomeController => this.homeController,
    homePageKeyFromAddress: (url: string): string => this.homePageKeyFromAddress(url),
    homeStore: (): PinmonyHomeStore => this.homeStore,
    ignoreSupersededDetailDocument: (url: string): boolean => this.ignoreSupersededDetailDocument(url),
    inboxFlowAction: (action: string, value?: string): Promise<void> => this.inboxFlowAction(action, value),
    inboxStore: (): PinmonyInboxStore => this.inboxStore,
    inboxUrlFromAddress: (address: string): string => this.inboxUrlFromAddress(address),
    isHomeRootAddress: (address: string): boolean => this.isHomeRootAddress(address),
    lastRootBackAt: (): number => this.lastRootBackAt,
    setLastRootBackAt: (value: number): number => { this.lastRootBackAt = value; return value; },
    loadFailed: (): boolean => this.loadFailed,
    setLoadFailed: (value: boolean): boolean => { this.loadFailed = value; return value; },
    logPageLifecycle: (event: string, detail?: string): void => this.logPageLifecycle(event, detail),
    nativeBackTarget: (): string => this.nativeBackTarget,
    setNativeBackTarget: (value: string): string => { this.nativeBackTarget = value; return value; },
    nativeChildBackUntil: (): number => this.nativeChildBackUntil,
    setNativeChildBackUntil: (value: number): number => { this.nativeChildBackUntil = value; return value; },
    nativePinRoute: (): string => this.nativePinRoute,
    setNativePinRoute: (value: string): string => { this.nativePinRoute = value; return value; },
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    setNativeRootOnly: (value: boolean): boolean => { this.nativeRootOnly = value; return value; },
    nativeRootTabsVisible: (): boolean => this.nativeRootTabsVisible(),
    nativeSearchPageVisible: (): boolean => this.nativeSearchPageVisible(),
    navigationAddress: (): string => this.navigationAddress,
    setNavigationAddress: (value: string): string => { this.navigationAddress = value; return value; },
    organizeProfile: (action: string, value?: string, secret?: boolean): Promise<void> => this.organizeProfile(action, value, secret),
    pageBackToken: (): number => this.pageBackToken,
    setPageBackToken: (value: number): number => { this.pageBackToken = value; return value; },
    pageHistory: (): PinmonyNavigationHistory => this.pageHistory,
    pagePerformance: (): PinmonyPagePerformance => this.pagePerformance,
    pendingWebTab: (): number => this.pendingWebTab,
    setPendingWebTab: (value: number): number => { this.pendingWebTab = value; return value; },
    pinIdentity: (value: string): string => this.pinIdentity(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
    prepareHomeForPageBegin: (url: string, retainedDocument?: boolean): void => this.prepareHomeForPageBegin(url, retainedDocument),
    profileSettingsVisible: (): boolean => this.profileSettingsVisible,
    profileStore: (): PinmonyProfileStore => this.profileStore,
    profileUrlFromAddress: (address: string): string => this.profileUrlFromAddress(address),
    publishFlowAction: (action: string, value?: string, secret?: boolean): void => this.publishFlowAction(action, value, secret),
    restoreCachedDetail: (pinUrl: string): boolean => this.restoreCachedDetail(pinUrl),
    restoreInbox: (address: string): boolean => this.restoreInbox(address),
    restoreProfile: (address: string): boolean => this.restoreProfile(address),
    restoreRetainedSearch: (pageKey: string): boolean => this.restoreRetainedSearch(pageKey),
    retainedHomeDocumentAddress: (): string => this.retainedHomeDocumentAddress,
    setRetainedHomeDocumentAddress: (value: string): string => { this.retainedHomeDocumentAddress = value; return value; },
    retainedHomeDocumentPending: (): boolean => this.retainedHomeDocumentPending,
    setRetainedHomeDocumentPending: (value: boolean): boolean => { this.retainedHomeDocumentPending = value; return value; },
    retainedRootTabAddress: (): string => this.retainedRootTabAddress,
    setRetainedRootTabAddress: (value: string): string => { this.retainedRootTabAddress = value; return value; },
    retainedRootTabPending: (): number => this.retainedRootTabPending,
    setRetainedRootTabPending: (value: number): number => { this.retainedRootTabPending = value; return value; },
    returnCoordinator: (): PinmonyReturnCoordinator => this.returnCoordinator,
    returnFromDetailWebFlow: (): Promise<void> => this.returnFromDetailWebFlow(),
    returnFromProfileWebFlow: (): Promise<void> => this.returnFromProfileWebFlow(),
    returnFromSearchQuiz: (): boolean => this.returnFromSearchQuiz(),
    rootContentInteracted: (): boolean => this.rootContentInteracted,
    setRootContentInteracted: (value: boolean): boolean => { this.rootContentInteracted = value; return value; },
    rootPresentationAddress: (index: number): string => this.rootPresentationAddress(index),
    rootPullKind: (): string => this.rootPullKind,
    setRootPullKind: (value: string): string => { this.rootPullKind = value; return value; },
    rootPullToken: (): number => this.rootPullToken,
    setRootPullToken: (value: number): number => { this.rootPullToken = value; return value; },
    rootReadAddress: (): string => this.rootReadAddress,
    setRootReadAddress: (value: string): string => { this.rootReadAddress = value; return value; },
    rootReadStartedAt: (): number => this.rootReadStartedAt,
    setRootReadStartedAt: (value: number): number => { this.rootReadStartedAt = value; return value; },
    rootReadToken: (): number => this.rootReadToken,
    setRootReadToken: (value: number): number => { this.rootReadToken = value; return value; },
    rootTabGuardAddress: (): string => this.rootTabGuardAddress,
    setRootTabGuardAddress: (value: string): string => { this.rootTabGuardAddress = value; return value; },
    rootTabGuardTarget: (): number => this.rootTabGuardTarget,
    setRootTabGuardTarget: (value: number): number => { this.rootTabGuardTarget = value; return value; },
    rootTabIndexFromAddress: (address: string): number => this.rootTabIndexFromAddress(address),
    searchController: (): PinmonySearchController => this.searchController,
    searchStore: (): PinmonySearchStore => this.searchStore,
    searchUrlFromAddress: (address: string): string => this.searchUrlFromAddress(address),
    showNativeSheet: (): boolean => this.showNativeSheet,
    showNativeTabs: (): boolean => this.showNativeTabs,
    setShowNativeTabs: (value: boolean): boolean => { this.showNativeTabs = value; return value; },
    syncBoardRoute: (address: string): void => this.syncBoardRoute(address),
    syncFloatingTabsMotion: (): void => this.syncFloatingTabsMotion(),
    tabRequestToken: (): number => this.tabRequestToken,
    setTabRequestToken: (value: number): number => { this.tabRequestToken = value; return value; },
    tabsController: (): HdsTabsController => this.tabsController,
    traceAction: (name: string, detail?: string): void => this.traceAction(name, detail),
    waitForWebTabConfirmation: (index: number, token: number, requestedAt: number): void => this.waitForWebTabConfirmation(index, token, requestedAt),
    webPageLoading: (): boolean => this.webPageLoading,
    setWebPageLoading: (value: boolean): boolean => { this.webPageLoading = value; return value; },
  } as PinmonyNavigationCoordinatorPorts);

  private readonly sessionVerification: PinmonySessionVerification = new PinmonySessionVerification({
    detached: (): boolean => this.nativeLoginEnabled,
    origin: (): string => this.nativeSessionOrigin,
    unavailable: (): void => { if(this.nativeLoginEnabled){this.offlineCacheLoading = false;this.authStatus = 'error';this.failureDetails = PinmonyI18n.message("pm_unable_to_verify_the_session_retry_or_sign_in_again_fb5c22fa");} },
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    status: (): PinmonyAuthStatus => this.authStatus,
    profile: (): string => this.authenticatedProfileUrl,
    epoch: (): number => this.nativeLoginEnabled ? this.nativeSessionEpoch : this.authEpoch,
    page: (): string => this.sessionDocumentUrl(),
    userAgent: (): string => this.sessionEnvironment.userAgent(),
    active: (): boolean => !this.businessSuspended,
    accept: (message: PinmonyAuthMessage): void => this.sessionCoordinator.updateAuthState(JSON.stringify(message), this.nativeLoginEnabled),
  });

  private readonly sessionCoordinator: PinmonySessionCoordinator = new PinmonySessionCoordinator({
    nativeLogin: (): boolean => this.nativeLoginEnabled,
    nativeEpoch: (): number => this.nativeSessionEpoch,
    loginRequired: (): void => {if(!this.loginHostMounted)this.openNativeLogin();},
    releaseLogin: (): void => { void this.releaseNativeLogin(); },
    verifyLoginEvidence: (message: PinmonyAuthMessage): void => {
      const origin: RegExpMatchArray | null = message.pageUrl.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
      if(!origin)return;
      const key: string = this.authEpoch.toString() + ':' + message.profileUrl;
      if(this.nativeVerificationPending && key === this.nativeLoginEvidenceKey)return;
      this.loginPageVisible = false;
      this.nativeLoginEvidenceKey = key;this.nativeSessionOrigin = origin[0];
      this.nativeVerificationPending = false;
      this.startNativeVerification();
    },
    enterAuthenticatedRoot: (home: string): void => this.enterAuthenticatedRoot?.(home),
    verifySession: (): void => { void this.sessionVerification?.demand(); },
    activeSheetKind: (): string => this.activeSheetKind,
    setActiveSheetKind: (value: string): string => { this.activeSheetKind = value; return value; },
    activeTab: (): number => this.activeTab,
    setActiveTab: (value: number): number => { this.activeTab = value; return value; },
    authCheckTimer: (): number => this.authCheckTimer,
    setAuthCheckTimer: (value: number): number => { this.authCheckTimer = value; return value; },
    authEpoch: (): number => this.authEpoch,
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    setAuthStatus: (value: PinmonyAuthStatus): PinmonyAuthStatus => { if (value !== 'authenticated') this.businessSession.reset(); this.authStatus = value; return value; },
    authWebVisible: (): boolean => this.authWebVisible(),
    authenticatedProfileUrl: (): string => this.authenticatedProfileUrl,
    setAuthenticatedProfileUrl: (value: string): string => { this.authenticatedProfileUrl = value; return value; },
    bindNativeNetwork: (): void => this.bindNativeNetwork(),
    confirmBusinessSession: (appVersion: string): void => this.confirmBusinessSession(appVersion),
    boardStore: (): PinmonyBoardStore => this.boardStore,
    cancelAccountSettings: (): void => this.cancelAccountSettings(),
    cancelHomeDetailMore: (): void => this.cancelHomeDetailMore(),
    clearDetail: (preserveRead?: boolean, localOnly?: boolean): void => this.clearDetail(preserveRead, localOnly),
    clearOfflineHomeMarker: (): void => this.clearOfflineHomeMarker(),
    clearRootTabCaches: (clearPersistentCache?: boolean): void => this.clearRootTabCaches(clearPersistentCache),
    closeImageLayer: (localOnly?: boolean): void => this.closeImageLayer(localOnly),
    closeProfilePanel: (): void => this.closeProfilePanel(),
    configureDocumentRetention: (enabled: boolean): void => this.configureDocumentRetention(enabled),
    controller: (): webview.WebviewController => this.controller,
    controllerLifecycle: (): PinmonyControllerLifecycle => this.controllerLifecycle(),
    currentWebTab: (): number => this.currentWebTab,
    setCurrentWebTab: (value: number): number => { this.currentWebTab = value; return value; },
    detailClickedAt: (): number => this.detailClickedAt,
    setDetailClickedAt: (value: number): number => { this.detailClickedAt = value; return value; },
    detailReadCache: (): PinmonyDetailReadCache => this.detailReadCache,
    detailReturnJourney: (): PinmonyDetailTrace => this.detailReturnJourney,
    detailReturnedToRoot: (): boolean => this.detailReturnedToRoot,
    setDetailReturnedToRoot: (value: boolean): boolean => { this.detailReturnedToRoot = value; return value; },
    dismissPostSnack: (reason?: string): void => this.dismissPostSnack(reason),
    expectHome: (): void => this.expectHome(),
    failureDetails: (): string => this.failureDetails,
    setFailureDetails: (value: string): string => { this.failureDetails = value; return value; },
    homeCacheAccountId: (): string => this.homeCacheAccountId,
    setHomeCacheAccountId: (value: string): string => { if (value !== this.homeCacheAccountId) { this.businessSession.reset(); this.boardNativeReads.reset(); this.profileNativeReads.reset(); this.inboxUpdatesNativeReads.reset(); this.inboxMessagesNativeReads.reset(); if (PIN_NATIVE_SEARCH_DISCOVERY_ENABLED) this.searchDiscoveryNativeReads.reset(); this.searchNativeReads.reset(); if (PIN_NATIVE_HOME_READS_ENABLED && this.homeCacheAccountId) this.homeNativeReads.reset(); } this.homeCacheAccountId = value; return value; },
    homeCacheAccountIdFromProfileUrl: (profileUrl: string): string => this.homeCacheAccountIdFromProfileUrl(profileUrl),
    homeCacheIdentityEpoch: (): number => this.homeCacheIdentityEpoch,
    setHomeCacheIdentityEpoch: (value: number): number => { this.homeCacheIdentityEpoch = value; return value; },
    homeController: (): PinmonyHomeController => this.homeController,
    homePageKeyFromAddress: (url: string): string => this.homePageKeyFromAddress(url),
    homeRecoveryAttempted: (): boolean => this.homeRecoveryAttempted,
    setHomeRecoveryAttempted: (value: boolean): boolean => { this.homeRecoveryAttempted = value; return value; },
    homeRecoveryToken: (): number => this.homeRecoveryToken,
    setHomeRecoveryToken: (value: number): number => { this.homeRecoveryToken = value; return value; },
    homeStore: (): PinmonyHomeStore => this.homeStore,
    inboxStore: (): PinmonyInboxStore => this.inboxStore,
    interruptedHomePage: (): string => this.interruptedHomePage,
    setInterruptedHomePage: (value: string): string => { this.interruptedHomePage = value; return value; },
    isHomeRootAddress: (address: string): boolean => this.isHomeRootAddress(address),
    lastLoginRetryAt: (): number => this.lastLoginRetryAt,
    setLastLoginRetryAt: (value: number): number => { this.lastLoginRetryAt = value; return value; },
    lastPageUrl: (): string => this.lastPageUrl,
    loadFailed: (): boolean => this.loadFailed,
    setLoadFailed: (value: boolean): boolean => { this.loadFailed = value; return value; },
    loginRedirectEpoch: (): number => this.loginRedirectEpoch,
    setLoginRedirectEpoch: (value: number): number => { this.loginRedirectEpoch = value; return value; },
    logoutAwaitingLogin: (): boolean => this.logoutAwaitingLogin,
    nativeBackTarget: (): string => this.nativeBackTarget,
    setNativeBackTarget: (value: string): string => { this.nativeBackTarget = value; return value; },
    nativeNetwork: (): PinmonyNativeNetwork => this.nativeNetwork,
    nativePinRoute: (): string => this.nativePinRoute,
    setNativePinRoute: (value: string): string => { this.nativePinRoute = value; return value; },
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    setNativeRootOnly: (value: boolean): boolean => { this.nativeRootOnly = value; return value; },
    navigationAddress: (): string => this.navigationAddress,
    setNavigationAddress: (value: string): string => { this.navigationAddress = value; return value; },
    offlineCacheLoading: (): boolean => this.offlineCacheLoading,
    setOfflineCacheLoading: (value: boolean): boolean => { this.offlineCacheLoading = value; return value; },
    offlinePreviewMode: (): boolean => this.offlinePreviewMode,
    setOfflinePreviewMode: (value: boolean): boolean => { this.offlinePreviewMode = value; return value; },
    pageBackToken: (): number => this.pageBackToken,
    setPageBackToken: (value: number): number => { this.pageBackToken = value; return value; },
    pageHistory: (): PinmonyNavigationHistory => this.pageHistory,
    pageTasks: (): PinmonyTaskRegistry => this.pageTasks,
    pendingDetailLike: (): PendingDetailLike | undefined => this.pendingDetailLike,
    setPendingDetailLike: (value: PendingDetailLike | undefined): PendingDetailLike | undefined => { this.pendingDetailLike = value; return value; },
    pendingWebTab: (): number => this.pendingWebTab,
    setPendingWebTab: (value: number): number => { this.pendingWebTab = value; return value; },
    pinStore: (): PinmonyPinStore => this.pinStore,
    profileSettingsVisible: (): boolean => this.profileSettingsVisible,
    setProfileSettingsVisible: (value: boolean): boolean => { this.profileSettingsVisible = value; return value; },
    profileStore: (): PinmonyProfileStore => this.profileStore,
    profileUrlFromAddress: (address: string): string => this.profileUrlFromAddress(address),
    refreshWebNavigation: (): Promise<void> => this.refreshWebNavigation(),
    retainedHomeAwaitingAuth: (): boolean => this.retainedHomeAwaitingAuth,
    setRetainedHomeAwaitingAuth: (value: boolean): boolean => { this.retainedHomeAwaitingAuth = value; return value; },
    retainedHomeAwaitingFeed: (): boolean => this.retainedHomeAwaitingFeed,
    setRetainedHomeAwaitingFeed: (value: boolean): boolean => { this.retainedHomeAwaitingFeed = value; return value; },
    retainedHomeDocumentAddress: (): string => this.retainedHomeDocumentAddress,
    setRetainedHomeDocumentAddress: (value: string): string => { this.retainedHomeDocumentAddress = value; return value; },
    retainedHomeDocumentPending: (): boolean => this.retainedHomeDocumentPending,
    setRetainedHomeDocumentPending: (value: boolean): boolean => { this.retainedHomeDocumentPending = value; return value; },
    retainedRootTabAddress: (): string => this.retainedRootTabAddress,
    setRetainedRootTabAddress: (value: string): string => { this.retainedRootTabAddress = value; return value; },
    retainedRootTabPending: (): number => this.retainedRootTabPending,
    setRetainedRootTabPending: (value: number): number => { this.retainedRootTabPending = value; return value; },
    returnCoordinator: (): PinmonyReturnCoordinator => this.returnCoordinator,
    rootContentInteracted: (): boolean => this.rootContentInteracted,
    setRootContentInteracted: (value: boolean): boolean => { this.rootContentInteracted = value; return value; },
    rootTabGuardAddress: (): string => this.rootTabGuardAddress,
    setRootTabGuardAddress: (value: string): string => { this.rootTabGuardAddress = value; return value; },
    rootTabGuardTarget: (): number => this.rootTabGuardTarget,
    setRootTabGuardTarget: (value: number): number => { this.rootTabGuardTarget = value; return value; },
    searchController: (): PinmonySearchController => this.searchController,
    settingsStore: (): PinmonySettingsStore => this.settingsStore,
    showNativeSheet: (): boolean => this.showNativeSheet,
    setShowNativeSheet: (value: boolean): boolean => { this.showNativeSheet = value; return value; },
    showNetworkNotice: (message?: string): void => this.showNetworkNotice(message),
    tabRequestToken: (): number => this.tabRequestToken,
    setTabRequestToken: (value: number): number => { this.tabRequestToken = value; return value; },
    tabsController: (): HdsTabsController => this.tabsController,
    tryEnterOfflinePreview: (failedUrl: string, reason?: string): boolean => this.tryEnterOfflinePreview(failedUrl, reason),
    tryRestoreAuthenticatedHome: (accountId: string, pageKey: string): void => this.tryRestoreAuthenticatedHome(accountId, pageKey),
    webPageLoading: (): boolean => this.webPageLoading,
  } as PinmonySessionCoordinatorPorts);

  private readonly photoMenuCoordinator: PinmonyPhotoMenuCoordinator = new PinmonyPhotoMenuCoordinator({
    nativeMenu: (): boolean => PIN_NATIVE_PIN_MENUS_ENABLED,
    nativeRead: (token: number,pin: string): Promise<PinmonyHomeMenuState> => this.pinMenuNative.photoRead(token,pin),
    nativeAction: (id: string): Promise<void> => this.pinMenuNative.action(id),
    nativePause: (): void => this.pinMenuNative.pause(),
    nativeShare: async (pin: string): Promise<void> => {this.homeStore.homeMenuPin = pin;this.homeStore.homeMenuPage = this.currentInboxUrl();this.homeStore.customHomeMenu = undefined;await this.shareNativeFlow.open('pin',pin,this.pinIdentity(pin));},
    activeSheetKind: (): string => this.activeSheetKind,
    setActiveSheetKind: (value: string): string => { this.activeSheetKind = value; return value; },
    authEpoch: (): number => this.authEpoch,
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    boardOperation: (method: string, id?: string): void => this.boardOperation(method, id),
    boardStore: (): PinmonyBoardStore => this.boardStore,
    cancelledBoardPins: (): Set<string> => this.cancelledBoardPins,
    nativeBoardContentWrites: (): boolean => PIN_NATIVE_BOARD_READS_ENABLED,
    cancelBoardPin: (pin: string, current: () => boolean): Promise<string> => this.boardNativeReads.cancelSavedPin(this.pinIdentity(pin),current),
    dismissShareSheetAfterAction: (): Promise<void> => this.dismissPhotoMenuAfterAction(),
    clearRootTabGuard: (reason: string): void => this.clearRootTabGuard(reason),
    controller: (): webview.WebviewController => this.controller,
    coordinatorTasks: (): PinmonyTaskRegistry => this.coordinatorTasks,
    currentBoardUrl: (): string => this.currentBoardUrl(),
    currentHomePageKey: (): string => this.currentHomePageKey(),
    currentInboxUrl: (): string => this.currentInboxUrl(),
    currentPinUrl: (): string => this.currentPinUrl(),
    dismissShareSheet: (): void => this.dismissShareSheet(),
    homeStore: (): PinmonyHomeStore => this.homeStore,
    inboxStore: (): PinmonyInboxStore => this.inboxStore,
    isCurrentBoardMenuPin: (pinUrl: string, pageKey: string): boolean => this.isCurrentBoardMenuPin(pinUrl, pageKey),
    isCurrentMorePin: (pin: string): boolean => this.isCurrentMorePin(pin),
    isCurrentSearchMenuPin: (pinUrl: string, pageKey: string): boolean => this.isCurrentSearchMenuPin(pinUrl, pageKey),
    openApiBoards: (requestedPin?: string): Promise<void> => this.openApiBoards(requestedPin),
    openApiDetailMore: (): Promise<void> => this.openApiDetailMore(),
    pinIdentity: (value: string): string => this.pinIdentity(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
    rejectOfflineAction: (action: string, message?: string): boolean => this.rejectOfflineAction(action, message),
    retainedBoardContent: (): PinmonyBoardDetail | undefined => this.retainedBoardContent,
    setRetainedBoardContent: (value: PinmonyBoardDetail | undefined): PinmonyBoardDetail | undefined => { this.retainedBoardContent = value; return value; },
    shareBoardPinAfterMenu: (pin: string, page: string): Promise<void> => this.shareDetailPinAfterMenu(pin, page),
    sharePinUrl: (url: string, title?: string): Promise<void> => this.sharePinUrl(url, title),
    showMessage: (message: string): void => this.showMessage(message),
    showNativeSheet: (): boolean => this.showNativeSheet,
    setShowNativeSheet: (value: boolean): boolean => { this.showNativeSheet = value; return value; },
    singlePinMovePage: (): string => this.singlePinMovePage,
    setSinglePinMovePage: (value: string): string => { this.singlePinMovePage = value; return value; },
    webJsonText: (value: string): string => this.webJsonText(value),
  } as PinmonyPhotoMenuCoordinatorPorts);

  private readonly detailNativeReads: PinmonyDetailNativeReads = new PinmonyDetailNativeReads({
    pinStore: (): PinmonyPinStore => this.pinStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.detailReadNetwork,
    legacyContext: (): PinmonyNetworkContext => this.nativeNetworkContext(),
    foreground: (): boolean => !this.businessSuspended && this.pinStore.videoForeground,
    rootOnly: (): boolean => this.nativeRootOnly,
    backTarget: (): string => this.nativeBackTarget,
    mark: (event: string): void => this.detailJourney.mark(event)
  } as PinmonyDetailNativeReadsPorts);

  private readonly detailNativeAuxiliary: PinmonyDetailNativeAuxiliary = new PinmonyDetailNativeAuxiliary({
    store: (): PinmonyPinStore => this.pinStore, session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.detailReadNetwork, owned: (): boolean => this.detailNativeReads.owned()
  } as PinmonyDetailNativeAuxiliaryPorts);

  private readonly detailOpeningCoordinator: PinmonyDetailOpeningCoordinator = new PinmonyDetailOpeningCoordinator({
    activeSheetKind: (): string => this.activeSheetKind,
    activeTab: (): number => this.activeTab,
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    coordinatorTasks: (): PinmonyTaskRegistry => this.coordinatorTasks,
    currentHomePageKey: (): string => this.currentHomePageKey(),
    detailJourney: (): PinmonyDetailTrace => this.detailJourney,
    detailOpenedAt: (): number => this.detailOpenedAt,
    detailPrefetchTimer: (): number => this.detailPrefetchTimer,
    setDetailPrefetchTimer: (value: number): number => { this.detailPrefetchTimer = value; return value; },
    detailReadCache: (): PinmonyDetailReadCache => this.detailReadCache,
    detailReadNetwork: (): PinmonyNativeNetwork => this.detailReadNetwork,
    nativeBusinessSessionContext: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    startNativeReads: (pin: string, token: number, body: string): Promise<PinmonyNetworkReply> => {
      const pending: Promise<PinmonyNetworkReply> = this.detailNativeReads.start(pin,token,body);
      if(PIN_NATIVE_POST_OPERATIONS_ENABLED)this.postNativeOperations.observe(pin,body);
      if(PIN_NATIVE_DETAIL_AUXILIARY_ENABLED)this.detailNativeAuxiliary.start(pin,token,body);
      return pending;
    },
    detailRequestOwners: (): Map<string, number> => this.detailRequestOwners,
    homeStore: (): PinmonyHomeStore => this.homeStore,
    nativeBackTarget: (): string => this.nativeBackTarget,
    nativeNetworkContext: (): PinmonyNetworkContext => this.nativeNetworkContext(),
    openingRelated: (): Promise<PinmonyNetworkReply> | undefined => this.openingRelated,
    setOpeningRelated: (value: Promise<PinmonyNetworkReply> | undefined): Promise<PinmonyNetworkReply> | undefined => { this.openingRelated = value; return value; },
    openingRelatedToken: (): number => this.openingRelatedToken,
    setOpeningRelatedToken: (value: number): number => { this.openingRelatedToken = value; return value; },
    pageTasks: (): PinmonyTaskRegistry => this.pageTasks,
    pinIdentity: (value: string): string => this.pinIdentity(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
  } as PinmonyDetailOpeningCoordinatorPorts);

  private readonly businessResultsCoordinator: PinmonyBusinessResultsCoordinator = new PinmonyBusinessResultsCoordinator({
    foreground: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended,
    epoch: (): number => this.authEpoch, document: (): string => this.sessionDocumentUrl(),
    activeSheetKind: (): string => this.activeSheetKind,
    controller: (): webview.WebviewController => this.controller,
    dismissApiBoards: (): void => this.dismissApiBoards(),
    dismissMoreSheet: (): void => this.dismissMoreSheet(),
    getUIContext: (): UIContext => this.getUIContext(),
    hasMeaningfulSearchPinTitle: (value: string): boolean => this.hasMeaningfulSearchPinTitle(value),
    homeController: (): PinmonyHomeController => this.homeController,
    homeStore: (): PinmonyHomeStore => this.homeStore,
    isCurrentMorePin: (pin: string): boolean => this.isCurrentMorePin(pin),
    openEditPin: (pin: string): Promise<void> => this.openEditPin(pin),
    pinIdentity: (value: string): string => this.pinIdentity(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
    searchStore: (): PinmonySearchStore => this.searchStore,
    sharePinUrl: (url: string, title?: string): Promise<void> => this.sharePinUrl(url, title),
    showMessage: (message: string): void => this.showMessage(message),
    showShareFeedbackSnack: (): void => this.showShareFeedbackSnack(),
    showUndoSnack: (message: string, pin: string, undo: () => void): void => this.showUndoSnack(message, pin, undo),
    systemActions: (): PinmonySystemActions => this.systemActions,
    undoMoreFeedback: (): Promise<void> => this.undoMoreFeedback(),
    undoSavedPin: (): Promise<void> => this.undoSavedPin(),
  } as PinmonyBusinessResultsCoordinatorPorts);

  private readonly boardOperationsController: PinmonyBoardOperationsController = new PinmonyBoardOperationsController(this.boardStore, {
    foreground: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended,
    epoch: (): number => this.authEpoch, document: (): string => this.sessionDocumentUrl(), currentBoard: (): string => this.currentBoardUrl(),
    movePage: (): string => this.singlePinMovePage, clearMovePage: (): void => { this.singlePinMovePage = ''; },
    hasDetail: (): boolean => !!this.pinStore.detail || !!this.pinStore.detailOpeningPin,
    returnTarget: (page: string): void => { this.loadFailed = false; const token: number = ++this.pageBackToken; this.nativeBackTarget = page; this.loadReturnTarget(page, token); },
    load: (page: string): void => this.loadSessionDocument(page), reload: (): void => this.reload(),
    cancelled: (pin: string): boolean => this.cancelledBoardPins.has(pin), retain: (board: PinmonyBoardDetail): void => { this.retainedBoardContent = board; },
    rememberPin: (pin: string, page: string): void => { this.pinStore.detailReturnUrl = page; if (pin) { const identity: string = this.pinIdentity(pin); this.pinStore.rememberDetailOrigin(identity, page); this.pinStore.confirmedSaves.confirm(identity, true, '', this.boardStore.boardDetail?.pageKey === page ? this.boardStore.boardDetail.title : ''); } },
    runScript: (script: string): Promise<string> => this.runSessionScript(script), feedback: (message: string): void => this.showMessage(message)
  } as PinmonyBoardOperationsPorts);

  private readonly webLifecycleCoordinator: PinmonyWebLifecycleCoordinator = new PinmonyWebLifecycleCoordinator({
    nativeBusinessOnly: (): boolean => this.nativeBusinessRoutesEnabled,
    navigationBegun: (url: string): void => { this.updateLoginPresentation(url); this.returnCoordinator.navigationBegun(url); },
    notifyMenuStateChanged: (): void => this.photoMenuCoordinator.notify(),
    activeSheetKind: (): string => this.activeSheetKind,
    setActiveSheetKind: (value: string): string => { this.activeSheetKind = value; return value; },
    activeTab: (): number => this.activeTab,
    authCheckTimer: (): number => this.authCheckTimer,
    setAuthCheckTimer: (value: number): number => { this.authCheckTimer = value; return value; },
    authEpoch: (): number => this.authEpoch,
    setAuthEpoch: (value: number): number => { this.authEpoch = value; return value; },
    authStatus: (): PinmonyAuthStatus => this.authStatus,
    setAuthStatus: (value: PinmonyAuthStatus): PinmonyAuthStatus => { if (value !== 'authenticated') this.businessSession.reset(); this.authStatus = value; return value; },
    beginDetailOpening: (pinUrl: string, returnUrl?: string): void => this.beginDetailOpening(pinUrl, returnUrl),
    bindCurrentDetailDocument: (url: string): void => this.bindCurrentDetailDocument(url),
    businessSuspended: (): boolean => this.businessSuspended,
    cancelHomeDetailMore: (): void => this.cancelHomeDetailMore(),
    clearDetail: (preserveRead?: boolean, localOnly?: boolean): void => this.clearDetail(preserveRead, localOnly),
    clearInbox: (): void => this.clearInbox(),
    clearProfile: (preserveWebFlow?: boolean): void => this.clearProfile(preserveWebFlow),
    clearRootTabCaches: (clearPersistentCache?: boolean): void => this.clearRootTabCaches(clearPersistentCache),
    clearRootTabGuard: (reason: string): void => this.clearRootTabGuard(reason),
    clearSearch: (): void => this.clearSearch(),
    configureDocumentRetention: (enabled: boolean): void => this.configureDocumentRetention(enabled),
    controller: (): webview.WebviewController => this.controller,
    coordinatorTasks: (): PinmonyTaskRegistry => this.coordinatorTasks,
    effectiveRootDocumentTarget: (): number => this.effectiveRootDocumentTarget(),
    expectInbox: (): void => this.expectInbox(),
    expectProfile: (): void => this.expectProfile(),
    expectSearch: (): void => this.expectSearch(),
    extractPinUrl: (value: string): string => this.extractPinUrl(value),
    failureDetails: (): string => this.failureDetails,
    setFailureDetails: (value: string): string => { this.failureDetails = value; return value; },
    handleExternalShareTarget: (url: string): boolean => this.handleExternalShareTarget(url),
    handleMainFrameFailure: (url: string, code: number, info: string): void => this.handleMainFrameFailure(url, code, info),
    homePageKeyFromAddress: (url: string): string => this.homePageKeyFromAddress(url),
    homeStore: (): PinmonyHomeStore => this.homeStore,
    homeTraceCardsPageKey: (): string => this.homeTraceCardsPageKey,
    setHomeTraceCardsPageKey: (value: string): string => { this.homeTraceCardsPageKey = value; return value; },
    homeTracePageKey: (): string => this.homeTracePageKey,
    setHomeTracePageKey: (value: string): string => { this.homeTracePageKey = value; return value; },
    ignoreSupersededDetailDocument: (url: string): boolean => this.ignoreSupersededDetailDocument(url),
    inboxStore: (): PinmonyInboxStore => this.inboxStore,
    inboxUrlFromAddress: (address: string): string => this.inboxUrlFromAddress(address),
    installDownloadDelegate: (): void => this.installDownloadDelegate(),
    isHomeRootAddress: (address: string): boolean => this.isHomeRootAddress(address),
    isStaleRootDocumentBegin: (address: string): boolean => this.isStaleRootDocumentBegin(address),
    lastDocumentBeginAt: (): number => this.lastDocumentBeginAt,
    setLastDocumentBeginAt: (value: number): number => { this.lastDocumentBeginAt = value; return value; },
    lastDocumentBeginUrl: (): string => this.lastDocumentBeginUrl,
    setLastDocumentBeginUrl: (value: string): string => { this.lastDocumentBeginUrl = value; return value; },
    lastPageUrl: (): string => this.lastPageUrl,
    setLastPageUrl: (value: string): string => { this.lastPageUrl = value; return value; },
    loadFailed: (): boolean => this.loadFailed,
    setLoadFailed: (value: boolean): boolean => { this.loadFailed = value; return value; },
    logPageLifecycle: (event: string, detail?: string): void => this.logPageLifecycle(event, detail),
    logoutAwaitingLogin: (): boolean => this.logoutAwaitingLogin,
    setLogoutAwaitingLogin: (value: boolean): boolean => { this.logoutAwaitingLogin = value; return value; },
    markRootDocumentReady: (): void => this.markRootDocumentReady(),
    nativeBackTarget: (): string => this.nativeBackTarget,
    nativeNetwork: (): PinmonyNativeNetwork => this.nativeNetwork,
    nativeRootOnly: (): boolean => this.nativeRootOnly,
    navigationAddress: (): string => this.navigationAddress,
    setNavigationAddress: (value: string): string => { this.navigationAddress = value; return value; },
    pageHistory: (): PinmonyNavigationHistory => this.pageHistory,
    pageTasks: (): PinmonyTaskRegistry => this.pageTasks,
    pendingWebTab: (): number => this.pendingWebTab,
    pinIdentity: (value: string): string => this.pinIdentity(value),
    pinStore: (): PinmonyPinStore => this.pinStore,
    prepareHomeForPageBegin: (url: string, retainedDocument?: boolean): void => this.prepareHomeForPageBegin(url, retainedDocument),
    profileStore: (): PinmonyProfileStore => this.profileStore,
    profileUrlFromAddress: (address: string): string => this.profileUrlFromAddress(address),
    recordPageNavigation: (url: string, mode?: string): void => this.recordPageNavigation(url, mode),
    refreshWebNavigation: (): Promise<void> => this.refreshWebNavigation(),
    resetAuthenticatedContent: (): void => this.resetAuthenticatedContent(),
    restoreInbox: (address: string): boolean => this.restoreInbox(address),
    restoreProfile: (address: string): boolean => this.restoreProfile(address),
    restoreRetainedSearch: (pageKey: string): boolean => this.restoreRetainedSearch(pageKey),
    retainedHomeAwaitingAuth: (): boolean => this.retainedHomeAwaitingAuth,
    setRetainedHomeAwaitingAuth: (value: boolean): boolean => { this.retainedHomeAwaitingAuth = value; return value; },
    retainedHomeAwaitingFeed: (): boolean => this.retainedHomeAwaitingFeed,
    setRetainedHomeAwaitingFeed: (value: boolean): boolean => { this.retainedHomeAwaitingFeed = value; return value; },
    retainedHomeDocumentAddress: (): string => this.retainedHomeDocumentAddress,
    setRetainedHomeDocumentAddress: (value: string): string => { this.retainedHomeDocumentAddress = value; return value; },
    retainedHomeDocumentPending: (): boolean => this.retainedHomeDocumentPending,
    setRetainedHomeDocumentPending: (value: boolean): boolean => { this.retainedHomeDocumentPending = value; return value; },
    retainedRootTabAddress: (): string => this.retainedRootTabAddress,
    setRetainedRootTabAddress: (value: string): string => { this.retainedRootTabAddress = value; return value; },
    retainedRootTabPending: (): number => this.retainedRootTabPending,
    setRetainedRootTabPending: (value: number): number => { this.retainedRootTabPending = value; return value; },
    rootTabGuardTarget: (): number => this.rootTabGuardTarget,
    rootTabIndexFromAddress: (address: string): number => this.rootTabIndexFromAddress(address),
    rootTabKindFromAddress: (address: string): string => this.rootTabKindFromAddress(address),
    searchStore: (): PinmonySearchStore => this.searchStore,
    searchUrlFromAddress: (address: string): string => this.searchUrlFromAddress(address),
    showNativeSheet: (): boolean => this.showNativeSheet,
    setShowNativeSheet: (value: boolean): boolean => { this.showNativeSheet = value; return value; },
    showNativeTabs: (): boolean => this.showNativeTabs,
    setShowNativeTabs: (value: boolean): boolean => { this.showNativeTabs = value; return value; },
    staleRootDocumentTarget: (): number => this.staleRootDocumentTarget(),
    syncAuthentication: (): void => this.syncAuthentication(),
    syncBoardRoute: (address: string): void => this.syncBoardRoute(address),
    tabRequestToken: (): number => this.tabRequestToken,
    tryEnterOfflinePreview: (failedUrl: string, reason?: string): boolean => this.tryEnterOfflinePreview(failedUrl, reason),
    webPageLoadFinishedAt: (): number => this.webPageLoadFinishedAt,
    setWebPageLoadFinishedAt: (value: number): number => { this.webPageLoadFinishedAt = value; return value; },
    webPageLoading: (): boolean => this.webPageLoading,
    setWebPageLoading: (value: boolean): boolean => { this.webPageLoading = value; return value; },
  } as PinmonyWebLifecycleCoordinatorPorts);

  private lifecycleRegistry: PinmonyControllerLifecycle | undefined = undefined;
  private controllerLifecycle(): PinmonyControllerLifecycle {
    if (!this.lifecycleRegistry) {
      const controllers: PinmonyProductControllers = {
        boardCollaborators: this.boardCollaboratorsController, publish: this.publishController,
        boardInvitation: this.boardInvitationController, boardState: this.boardStateController,
        photoMenu: this.photoMenuCoordinator, rootContext: this.rootContextCoordinator,
        boardOperations: this.boardOperationsController, settings: this.settingsController,
        inboxActions: this.inboxActionsController, detail: this.detailController,
        detailRead: this.detailReadController, detailNativeReads: this.detailNativeReads, homeNativeReads: this.homeNativeReads, searchDiscoveryNativeReads: this.searchDiscoveryNativeReads, searchNativeReads: this.searchNativeReads, detailOperations: this.detailOperationsController,
        sharePanels: this.sharePanelsController, postPanels: this.postPanelsController,
        boardNativeReads: this.boardNativeReads, profileNativeReads: this.profileNativeReads, profileRead: this.profileReadController, profileActions: this.profileActionsController,
        inboxMessagesNativeReads: this.inboxMessagesNativeReads, inboxUpdatesNativeReads: this.inboxUpdatesNativeReads, inboxRead: this.inboxReadController
      };
      this.lifecycleRegistry = assembleControllerLifecycle(controllers, (): void => {
        this.coordinatorTasks.invalidate();
        if (this.rootPullKind) this.finishRootPull(this.rootPullKind);
        if (this.homeStore.customHomeMenu) this.dismissShareSheet();
      });
    }
    return this.lifecycleRegistry;
  }

  private markRootPerformance(index: number): void {
    this.rootContextCoordinator.notify();
    if (this.businessSuspended || this.authStatus !== 'authenticated' || this.activeTab !== index || !this.rootActionContextReady(index)) return;
    this.pagePerformance.mark(index, 'document-ready');
    const ready: boolean = index === 0 ? this.homeStore.homeActionsReady : index === 1 ? this.searchStore.searchActionsReady :
      index === 2 ? this.inboxStore.inboxActionsReady : this.profileStore.profileActionsReady;
    if (ready && (index !== 3 || (!!this.profileStore.profile && !this.profileStore.profile.contentLoading &&
        !this.profileStore.profile.contentError && !this.profileStore.profile.unorganizedLoading && !this.profileStore.profile.unorganizedError)))
      this.pagePerformance.mark(index, 'content-ready');
  }

  private markRootDocumentReady(): void {
    this.rootContextCoordinator.notify();
    if (this.businessSuspended || this.authStatus !== 'authenticated') return;
    try {
      const address: string = this.sessionDocumentUrl();
      if (this.rootTabIndexFromAddress(address) === this.activeTab &&
          this.pageHistory.key(address) === this.pageHistory.key(this.rootPresentationAddress(this.activeTab))) {
        this.pagePerformance.mark(this.activeTab, 'document-ready');
      }
    } catch (_) {}
  }

  private businessSuspended: boolean = false;

  onPageShow(): void {
    this.logPageLifecycle('page-show');
    if (!this.pinStore.videoForeground) this.homeRecoveryAttempted = false;
    this.pinStore.videoForeground = true;
    if (this.businessSuspended) {
      this.businessSuspended = false;
      this.bottomBarCoordinator.resumeAfterForeground();
      const readNeeded: boolean = this.nativeNetwork.setForeground(true);
      const detailReadNeeded: boolean = this.detailReadNetwork.setForeground(true);
      this.runSessionScript('window.PinmonyNetwork && window.PinmonyNetwork.setForeground(true)').catch(() => {});
      this.controllerLifecycle().resume();
      if (this.authStatus === 'checking' || this.authStatus === 'authenticated' && !this.authenticatedProfileUrl) this.syncAuthentication();
      PinmonyRuntimeLog.info('BusinessLifecycle: resumed readNeeded=' + readNeeded.toString() + ' targetTab=' + this.activeTab.toString());
      if (this.boardStore.collaborators) this.pollBoardCollaborators(this.boardStore.collaboratorsToken);
      if (this.authStatus === 'authenticated' && !this.activeSheetKind) {
        if (this.pinStore.detail && (readNeeded || detailReadNeeded || PIN_NATIVE_DETAIL_READS_ENABLED && !this.detailNativeReads.owned())) this.retryDetailApi();
        else if (!this.pinStore.detail && !this.pinStore.detailOpeningPin && (readNeeded ||
          (this.activeTab === 0 && PIN_NATIVE_HOME_READS_ENABLED ? !this.homeStore.homeNativeReadsReady : !this.rootActionContextReady(this.activeTab)))) { this.requestRootPage(this.activeTab); return; }
      }
    }
    this.profileSearchReads.resume();
    this.scheduleInterruptedHomeRecovery();
  }
  onPageHide(): void {
    this.rootExitBackAt = 0;
    this.profileSearchReads.pause();
    this.sessionVerification?.cancel('background');
    if(this.nativeLoginEnabled){this.nativeSessionEpoch++;this.nativeVerificationPending = false;}
    this.returnCoordinator.cancel();
    this.controllerLifecycle().pause();
    this.pagePerformance.cancel();
    this.homeController.invalidatePending();
    this.logPageLifecycle('page-hide', 'detailReadNetwork=invalidate');
    this.searchController.invalidatePending();
    this.pinStore.videoForeground = false;
    this.businessSuspended = true;
    this.inboxMenuNative.pause();this.boardInvitationNative.pause();
    this.nativeNetwork.setForeground(false); this.detailReadNetwork.setForeground(false);
    this.tabRequestToken++; this.rootReadToken = -1; this.pendingWebTab = -1;
    this.runSessionScript('window.PinmonyNetwork && window.PinmonyNetwork.setForeground(false)').catch(() => {});
    PinmonyRuntimeLog.info('BusinessLifecycle: suspended reads-cancelled=true writes-replay=false');
    this.pinStore.detailPrefetch.pause();
    this.detailReadNetwork.invalidate(); this.openingRelated = undefined;
    this.sharedDetailRequestId = '';
    this.homeRecoveryToken++;
    PinmonyRuntimeLog.flush();
  }
  private pageBackToken: number = 0;
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;

  private readonly pagePerformance: PinmonyPagePerformance = new PinmonyPagePerformance();
  private readonly inboxMenuNative: PinmonyInboxMenuNative = new PinmonyInboxMenuNative({
    store: (): PinmonyInboxStore => this.inboxStore,session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),network: (): PinmonyNativeNetwork => this.nativeNetwork,
    page: (): string => this.currentInboxUrl(),active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 2 && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.boardStore.boardDetail && !this.activeSheetKind,
    find: (id: string) => this.inboxUpdatesNativeReads.menuItem(id),confirmed: (id: string,hidden: boolean): void => this.inboxUpdatesNativeReads.confirmedVisibility(id,hidden),
    unsubscribed: (id: string): void => this.inboxUpdatesNativeReads.confirmedUnsubscribe(id)
  } as PinmonyInboxMenuNativePorts);
  private readonly boardInvitationNative: PinmonyBoardInvitationNative = new PinmonyBoardInvitationNative({
    store: (): PinmonyInboxStore => this.inboxStore,session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),network: (): PinmonyNativeNetwork => this.nativeNetwork,
    page: (): string => this.nativeDisplayAddress().split('#')[0],active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && !this.pinStore.detail && !this.pinStore.detailOpeningPin && (this.activeTab === 2 || !!this.boardStore.boardDetail),
    username: (): string => this.authenticatedProfileUrl.split('/')[3] || '',avatar: (): string => this.profileStore.profile?.avatarUrl || '',feedback: (message: string): void => this.showMessage(message)
  } as PinmonyBoardInvitationNativePorts);
  private readonly inboxUpdatesNativeReads: PinmonyInboxUpdatesNativeReads = new PinmonyInboxUpdatesNativeReads({
    store: (): PinmonyInboxStore => this.inboxStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    page: (): string => this.currentInboxUrl(),
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 2 && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.inboxStore.inboxFlow && !this.boardStore.boardDetail && !this.activeSheetKind,
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    settled: (): void => { this.finishRootPull('inbox'); this.markRootPerformance(2); this.rootContextCoordinator.notify(); }
  } as PinmonyInboxUpdatesNativeReadsPorts);

  private readonly inboxMessagesNativeReads: PinmonyInboxMessagesNativeReads = new PinmonyInboxMessagesNativeReads({
    username: (): string => this.authenticatedProfileUrl.match(/\/([A-Za-z0-9_]+)\/$/)?.[1] || '',
    store: (): PinmonyInboxStore => this.inboxStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    page: (): string => this.currentInboxUrl(),
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 2 && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.boardStore.boardDetail && !this.activeSheetKind,
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    settled: (): void => {this.finishRootPull('inbox'); this.markRootPerformance(2); this.rootContextCoordinator.notify();}
  } as PinmonyInboxMessagesNativeReadsPorts);

  private readonly inboxReadController: PinmonyInboxReadController = new PinmonyInboxReadController(this.inboxStore, {
    nativeMessages: (): boolean => this.authStatus === 'authenticated' && this.inboxMessagesNativeReads.selected(),
    nativeMessagesApply: (): void => this.inboxMessagesNativeReads.apply(),
    nativeMessagesDemand: (): Promise<void> => this.inboxMessagesNativeReads.demand(),
    nativeMessagesRefresh: (): Promise<void> => this.inboxMessagesNativeReads.refresh(),
    nativeMessagesContacts: (): Promise<void> => this.inboxMessagesNativeReads.refreshContacts(),
    nativeMessagesBridge: (flow: PinmonyInboxFlowSnapshot): boolean => this.inboxMessagesNativeReads.acceptBridge(flow),
    documentEpoch: (): number => this.authEpoch,
    nativeUpdates: (): boolean => this.inboxUpdatesNativeReads.eligible(),
    nativeUpdatesApply: (): void => this.inboxUpdatesNativeReads.apply(),
    nativeUpdatesSelect: async (section: string): Promise<boolean> => {
      if(section === 'messages') {await this.inboxUpdatesNativeReads.select(section); return this.inboxMessagesNativeReads.select(section);}
      await this.inboxMessagesNativeReads.select(section); return this.inboxUpdatesNativeReads.select(section);
    },
    nativeUpdatesDemand: (): Promise<void> => this.inboxUpdatesNativeReads.demand(),
    nativeUpdatesRefresh: (): Promise<void> => this.inboxUpdatesNativeReads.refresh(),
    nativeUpdatesMore: (): Promise<void> => this.inboxUpdatesNativeReads.more(),
    nativeUpdatesVisibility: (newsId: string,hidden: boolean): void => this.inboxUpdatesNativeReads.confirmedVisibility(newsId,hidden),
    authenticated: (): boolean => this.authStatus === 'authenticated', foreground: (): boolean => !this.businessSuspended,
    document: (): string => this.sessionDocumentUrl(), addressKey: (address: string): string => this.pageHistory.key(address),
    inboxAddress: (address: string): string => this.inboxUrlFromAddress(address), currentInbox: (): string => this.currentInboxUrl(),
    activeTab: (): number => this.activeTab, pendingTab: (): number => this.pendingWebTab, rootAddress: (): string => this.rootTabAddresses.get(2) || '',
    rootOnly: (): boolean => this.nativeRootOnly, interacted: (): boolean => this.rootContentInteracted, backTarget: (): string => this.nativeBackTarget,
    runScript: (script: string): Promise<string> => this.runSessionScript(script), finishPull: (): void => this.finishRootPull('inbox'),
    readInvitations: (): void => { this.readBoardInvitations(); }, recordAddress: (address: string): void => { this.rootTabAddresses.set(2, address); },
    confirmed: (): void => this.markRootPerformance(2), prepareContext: (): Promise<boolean> => this.ensureRootActionContext(2, false),
    readStarted: (): void => this.pagePerformance.count(2, 'read'),
    cancelled: (count: number): void => this.pagePerformance.count(2, 'cancel', count),
    prepareRead: (): boolean => this.prepareRootPageRead(2), requestRead: (): void => this.requestRootPage(2), feedback: (message: string): void => this.showMessage(message)
  } as PinmonyInboxReadPorts);

  private readonly settingsNativeFlow: PinmonySettingsNativeFlow = new PinmonySettingsNativeFlow({
    store: (): PinmonySettingsStore => this.settingsStore,session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.profileSettingsVisible,
    page: (): string => this.profileUrlFromAddress(this.authenticatedProfileUrl)
  } as PinmonySettingsNativePorts);
  private readonly profileNativeActions: PinmonyProfileNativeActions = new PinmonyProfileNativeActions({
    store: (): PinmonyProfileStore => this.profileStore,session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && (this.activeTab === 3 || this.profileStore.origins.length > 0) && !this.pinStore.detail && !this.boardStore.boardDetail,
    page: (): string => this.currentProfileUrl(),ownPage: (): string => this.profileUrlFromAddress(this.authenticatedProfileUrl),motion: (): void => this.syncFloatingTabsMotion(),feedback: (message: string): void => this.showMessage(message),
    avatarSaved: (page: string,avatar: string): void => this.profileNativeReads.confirmAvatar(page,avatar),
    saved: (page: string,username: string): void => this.nativeProfileSaved(page,username),refresh: (): void => {this.profileStore.profileCache.clear();this.profileNativeReads.refresh();},morePins: (action: string): Promise<boolean> => this.profileNativeReads.unorganizedAction(action)
  } as PinmonyProfileNativeActionsPorts);
  private readonly profileActionsController: PinmonyProfileActionsController = new PinmonyProfileActionsController(this.profileStore, {
    nativeEnabled: (): boolean => PIN_NATIVE_PROFILE_SETTINGS_ENABLED,
    nativeOpen: (mode: string,section: string): Promise<void> => this.profileNativeActions.open(mode,section),
    nativeClose: (): void => this.profileNativeActions.close(),nativePause: (): void => this.profileNativeActions.pause(),
    nativeFollow: (id: string): Promise<void> => this.profileNativeActions.follow(id),nativeSave: (input: string): Promise<void> => this.profileNativeActions.save(input),
    nativeOrganize: (action: string,value: string,secret: boolean): Promise<void> => this.profileNativeActions.organizeAction(action,value,secret),
    authenticated: (): boolean => this.authStatus === 'authenticated', foreground: (): boolean => !this.businessSuspended,
    visible: (): boolean => this.activeTab === 3 || this.profileStore.origins.length > 0,
    document: (): string => this.sessionDocumentUrl(), currentProfile: (): string => this.currentProfileUrl(),
    prepare: (): Promise<boolean> => this.prepareProfileInteraction(), runScript: (script: string): Promise<string> => this.runSessionScript(this.profileNativeReads.installScript() + script),
    jsonText: (raw: string): string => this.webJsonText(raw), feedback: (message: string): void => this.showMessage(message),
    syncMotion: (): void => this.syncFloatingTabsMotion(), markInteracted: (): void => { this.rootContentInteracted = true; },
    saved: (page: string, username: string): void => {
      const origin: RegExpMatchArray | null = page.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
      const target: string = username && origin ? origin[0] + '/' + username + '/' : page;
      if (target !== page) { this.clearProfile(); this.loadSessionDocument(target); }
      else this.refreshProfile(true);
    }
  } as PinmonyProfileActionsPorts);

  private readonly boardNativeReads: PinmonyBoardNativeReads = new PinmonyBoardNativeReads({
    store: (): PinmonyBoardStore => this.boardStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && !this.nativeRootOnly && !!this.boardStore.boardDetail && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.profileStore.publishFlow && !this.publishBoardReturn,
    document: (): string => this.sessionDocumentUrl(), documentEpoch: (): number => this.authEpoch,
    bridge: (value: string): void => this.boardStateController.update(value),
    install: (script: string): void => { if(script && !this.nativeBusinessRoutesEnabled) this.runSessionScript(script).catch((): void => {}); },
    committed: (): void => {const b: PinmonyBoardDetail | undefined = this.boardStore.boardDetail; if(b && !b.error) this.pagePerformance.markSecondary('board',b.pageKey,'content-ready');},
    prepareDocument: (): Promise<boolean> => this.prepareBoardNativeDocument(),
    invalidateProfile: (): void => {this.profileNativeReads.reset();this.profileStore.profileCache.clear();this.profileStore.profileActionsReady = false;},
    movePage: (): string => this.singlePinMovePage, clearMovePage: (): void => {this.singlePinMovePage = '';},
    renamed: (previous: string, next: string): void => {
      if(this.boardStore.boardReturnPage === previous)this.boardStore.boardReturnPage = next;
      this.retainedBoardContent = undefined;this.cancelledBoardPins.clear();this.singlePinMovePage = '';
      this.boardStore.presentationPage = next;this.boardStore.presentationOnly = false;
      this.boardStore.pendingBoardUrl = '';this.boardStore.pendingBoardSource = '';
      this.returnCoordinator.cancel();this.pageBackToken++;this.nativeBackTarget = next;this.navigationAddress = next;
      this.pageHistory.visit(next,'load');
    },
    exited: (action: string): void => {
      this.retainedBoardContent = undefined;this.cancelledBoardPins.clear();this.singlePinMovePage = '';
      if(action === 'leave')this.showMessage(PinmonyI18n.message("pm_left_board_af0547a0"));
      this.backFromBoard();
    },
    feedback: (message: string): void => this.showMessage(message),
    runScript: (script: string): Promise<string> => this.runSessionScript(script), jsonText: (value: string): string => this.webJsonText(value),
    openPin: (pin: PinmonyBoardPin, board: PinmonyBoardDetail): void => {
      if(this.cancelledBoardPins.has(pin.pinUrl))return;
      this.retainedBoardContent = board; this.pinStore.detailReturnUrl = board.pageKey;
      this.pinStore.rememberDetailOrigin(this.pinIdentity(pin.pinUrl),board.pageKey);
      this.pinStore.confirmedSaves.confirm(this.pinIdentity(pin.pinUrl),true,'',board.title);
      this.beginDetailOpening(pin.pinUrl,board.pageKey); if(!PIN_NATIVE_DETAIL_READS_ENABLED)this.loadSessionDocument(pin.pinUrl);
    }
  } as PinmonyBoardNativeReadsPorts);

  @State private immediateFollowingReturn: boolean = false;
  private followingBoardReturn: PinmonyFollowingBoardReturn | undefined = undefined;
  private readonly profileBoardOrigins: Map<number,PinmonyProfileBoardOrigin> = new Map<number,PinmonyProfileBoardOrigin>();
  private readonly profileNativeReads: PinmonyProfileNativeReads = new PinmonyProfileNativeReads({
    store: (): PinmonyProfileStore => this.profileStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    page: (): string => this.currentProfileUrl(),
    visitor: (): boolean => this.profileStore.origins.length > 0,
    selected: (): boolean => this.usesNativeProfileReads(),
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && (this.activeTab === 3 || this.profileStore.origins.length > 0) && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.boardStore.boardDetail && !this.boardStore.pendingBoardUrl && !this.profileStore.profileWebFlow,
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    document: (): string => this.sessionDocumentUrl(), documentEpoch: (): number => this.authEpoch,
    recordAddress: (address: string): void => {if(this.profileStore.origins.length > 0){this.navigationAddress = address;this.nativeBackTarget = address;}else this.rootTabAddresses.set(3,address);},
    settled: (): void => {this.finishProfilePull(); this.pagePerformance.mark(3,'content-ready'); this.rootContextCoordinator.notify();}
  } as PinmonyProfileNativeReadsPorts);

  private readonly profileReadController: PinmonyProfileReadController = new PinmonyProfileReadController(this.profileStore, {
    authenticated: (): boolean => this.authStatus === 'authenticated', foreground: (): boolean => !this.businessSuspended,
    document: (): string => this.sessionDocumentUrl(), addressKey: (address: string): string => this.pageHistory.key(address),
    profileAddress: (address: string): string => this.profileUrlFromAddress(address), currentProfile: (): string => this.currentProfileUrl(),
    rootOnly: (): boolean => this.nativeRootOnly, interacted: (): boolean => this.rootContentInteracted, backTarget: (): string => this.nativeBackTarget,
    apiEnabled: (): boolean => PIN_PROFILE_API_ENABLED, activeTab: (): number => this.activeTab, pendingTab: (): number => this.pendingWebTab,
    rootAddress: (): string => this.rootTabAddresses.get(3) || '',
    selectProfile: (): void => { this.currentWebTab = 3; this.activeTab = 3; this.tabsController.changeIndex(3); },
    confirmPending: (): void => { this.pendingWebTab = -1; }, recordAddress: (address: string): void => { this.rootTabAddresses.set(3, address); },
    clearProfile: (preserve: boolean): void => this.clearProfile(preserve), prepareRead: (): boolean => this.prepareRootPageRead(3),
    requestRead: (): void => this.requestRootPage(3), runScript: (script: string): Promise<string> => this.runSessionScript(script)
  } as PinmonyProfileReadPorts);

  private readonly postNativeOperations: PinmonyPostNativeOperations = new PinmonyPostNativeOperations({
    store: (): PinmonyPinStore => this.pinStore, session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended,
    originToken: (): string => this.activeTab.toString() + ':' + this.tabRequestToken.toString() + ':' + this.rootPresentationAddress(this.activeTab),
    owns: (pin: string): boolean => this.ownsPostPin(pin),
    sheet: (): string => this.activeSheetKind,
    show: (kind: string): void => {if(kind){this.postSheetClosed = undefined;this.postSheetDismissed = false;this.activeSheetKind = kind;this.showNativeSheet = true;}else {this.showNativeSheet = false;this.pinStore.shareBackHandledUntil = Date.now() + 500;}},
    saved: (pin: string, copy: string, message: string): void => {
      this.pinStore.saveUndoPin = pin;this.pinStore.saveUndoId = copy;
      const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
      this.postSheetClosed = (): void => {
        const current: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
        if(current.authenticated && current.accountId === session.accountId && current.generation === session.generation &&
            this.pinStore.saveUndoPin === pin && this.pinStore.saveUndoId === copy)this.showUndoSnack(message,pin,(): void => {this.undoSavedPin();});
      };
    },
    dismissed: (): void => {this.postSheetDismissed = true;},
    feedback: (message: string): void => this.showMessage(message),
    committed: (action: string, pin: string): void => {
      this.pinStore.detailCache.remove(this.pinIdentity(pin));
      if(action !== 'like'){this.profileNativeReads.reset();this.profileStore.profileCache.clear();this.profileStore.profileActionsReady = false;this.boardNativeReads.reset();}
      if(action === 'delete'){this.pinStore.detail = undefined;this.handleBack();}
    }
  } as PinmonyPostNativePorts);

  private readonly commentNativeWrites: PinmonyCommentNativeWrites = new PinmonyCommentNativeWrites({
    store: (): PinmonyPinStore => this.pinStore, session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.nativeNetwork, reads: (): PinmonyDetailNativeReads => this.detailNativeReads,
    readJpeg: (uri: string): Promise<ArrayBuffer> => this.systemActions.readJpeg(uri)
  } as PinmonyCommentNativePorts);

  private readonly postPanelsController: PinmonyPostPanelsController = new PinmonyPostPanelsController(this.pinStore, {
    nativePause: (): void => this.postNativeOperations?.pause(),
    cancelNativeCommentWrites: (): void => this.commentNativeWrites?.pause(),
    nativeCommentWrite: PIN_NATIVE_COMMENT_WRITES_ENABLED ? (encoded: string, current: () => boolean): Promise<void> => this.commentNativeWrites.write(encoded,current) : undefined,
    nativeCommentLike: PIN_NATIVE_COMMENT_WRITES_ENABLED ? (id: string, current: () => boolean): Promise<void> => this.commentNativeWrites.like(id,current) : undefined,
    nativeTranslate: PIN_NATIVE_DETAIL_READS_ENABLED ? (id: string, current: () => boolean): Promise<void> => this.detailNativeReads.translateComment(id, current) : undefined,
    nativeReplies: PIN_NATIVE_DETAIL_READS_ENABLED ? (id: string, current: () => boolean): Promise<void> => this.detailNativeReads.readReplies(id, current) : undefined,
    nativeComments: PIN_NATIVE_DETAIL_READS_ENABLED ? (append: boolean, current: () => boolean): Promise<void> => this.detailNativeReads.readComments(append, current) : undefined,
    cancelNativeComments: (): void => this.detailNativeReads.cancelComments(),
    adoptComments: async (): Promise<boolean> => {
      if (!await this.ensureDetailActionContext() || this.activeSheetKind !== 'comments') return false;
      const pin: string = this.pinStore.commentResult.pin;
      const raw: string = await this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.commentsAdopt(' + JSON.stringify(pin) + ',' + JSON.stringify(this.detailNativeReads.commentsSeed()) + ')');
      return this.webJsonText(raw) === 'true';
    },
    authenticated: (): boolean => this.authStatus === 'authenticated', foreground: (): boolean => !this.businessSuspended,
    document: (): string => this.sessionDocumentUrl(), sheet: (): string => this.activeSheetKind,
    show: (kind: string): void => {
      this.showNativeSheet = !!kind;
      if (kind) this.activeSheetKind = kind;
    },
    currentPin: (): string => PIN_NATIVE_DETAIL_READS_ENABLED && this.detailNativeReads.owned() ? this.pinStore.detailPin : this.currentPinUrl(), pinIdentity: (pin: string): string => this.pinIdentity(pin),
    moreCurrent: (pin: string): boolean => this.isCurrentMorePin(pin),
    runScript: (script: string): Promise<string> => this.runSessionScript(script), jsonText: (raw: string): string => this.webJsonText(raw),
    feedback: (message: string): void => this.showMessage(message),
    saveDismissed: (): void => {
      PinmonyRuntimeLog.info('PinmonyReturn: save sheet dismissed'); this.pinStore.shareBackHandledUntil = Date.now() + 500; this.lastRootBackAt = 0;
      if (this.homeStore.customHomeMenu) {
        const closingSave: boolean = this.activeSheetKind === 'save' && !this.showNativeSheet;
        this.dismissShareSheet();
        if (closingSave) this.activeSheetKind = 'save';
        return;
      }
      this.runSessionScript('window.PinmonyDetailRefresh && window.PinmonyDetailRefresh()').catch(() => {});
    },
    editCompleted: async (pin: string, deleted: boolean): Promise<void> => {
      if (deleted) this.pinStore.confirmedSaves.confirm(this.pinIdentity(pin), false);
      this.pinStore.detailCache.remove(this.pinIdentity(pin));
      if (deleted) { this.pinStore.detail = undefined; await this.handleBack(); }
      this.runSessionScript('window.PinmonyProfileRefresh && window.PinmonyProfileRefresh(); window.PinmonyBoardRefresh && window.PinmonyBoardRefresh(); window.PinmonyDetailRefresh && window.PinmonyDetailRefresh()').catch(() => {});
      this.showMessage(deleted ? this.uiText("pm_pin_removed_from_your_board_d44f44e2") : this.uiText("pm_changes_saved_1045a8e6"));
    },
    prepareComment: (encoded: string, pin: string, current: () => boolean): Promise<string> => this.prepareCommentWrite(encoded, pin, current)
  } as PinmonyPostPanelsPorts);

  private readonly boardStateController: PinmonyBoardStateController = new PinmonyBoardStateController(this.boardStore, {
    authenticated: (): boolean => this.authStatus === 'authenticated', foreground: (): boolean => !this.businessSuspended,
    rootOnly: (): boolean => this.nativeRootOnly, currentBoard: (): string => this.currentBoardUrl(),
    boardAddress: (address: string): string => this.boardUrlFromAddress(address),
    profileAddress: (address: string): string => this.profileUrlFromAddress(address),
    pinAddress: (address: string): string => this.extractPinUrl(address), addressKey: (address: string): string => this.pageHistory.key(address),
    publishReturn: (): string => this.publishBoardReturn, hasDetail: (): boolean => !!this.pinStore.detail || !!this.pinStore.detailOpeningPin,
    backTarget: (): string => this.nativeBackTarget, retainedContent: (): PinmonyBoardDetail | undefined => this.retainedBoardContent,
    movePage: (): string => this.singlePinMovePage, clearMovePage: (): void => { this.singlePinMovePage = ''; },
    confirmInvitation: (page: string): void => {
      if (this.inboxStore.boardInvitationPreview?.boardUrl === page && this.inboxStore.invitationReadPage !== page) this.readBoardInvitations(true);
    },
    invalidateProfile: (): void => {
      this.profileStore.profileActionsReady = false; this.clearProfile(); this.profileStore.profileCache.clear();
      this.runSessionScript('window.PinmonyProfileApi && window.PinmonyProfileApi.reset()').catch(() => {});
    },
    feedback: (message: string): void => this.showMessage(message), closeFlow: (): void => this.boardOperation('flow', JSON.stringify({ action: 'close' })),
    back: (): void => this.backFromBoard(), navigate: (page: string): void => this.loadSessionDocument(page)
  } as PinmonyBoardStatePorts);

  private readonly boardInvitationController: PinmonyBoardInvitationController = new PinmonyBoardInvitationController(this.inboxStore, {
    nativeEnabled: (): boolean => PIN_NATIVE_INBOX_UPDATES_ENABLED,
    nativeOpen: (preview: boolean): Promise<void> => this.boardInvitationNative.open(preview),nativePause: (): void => this.boardInvitationNative.pause(),nativeAccept: (): Promise<void> => this.boardInvitationNative.accept(),
    authenticated: (): boolean => this.authStatus === 'authenticated',
    foreground: (): boolean => !this.businessSuspended,
    page: (): string => PIN_NATIVE_INBOX_UPDATES_ENABLED ? this.nativeDisplayAddress().split('#')[0] : this.sessionDocumentUrl().split('#')[0],
    username: (): string => this.authenticatedProfileUrl.split('/')[3] || '',
    avatar: (): string => this.profileStore.profile?.avatarUrl || '',
    script: (): string => useNativeTransport(PIN_BOARD_INVITATION_SCRIPT),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    jsonText: (value: string): string => this.webJsonText(value),
    feedback: (message: string): void => this.showMessage(message)
  } as PinmonyBoardInvitationPorts);

  private readonly pinMenuNative: PinmonyPinMenuNative = new PinmonyPinMenuNative({
    store: (): PinmonyPinStore => this.pinStore, session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.nativeNetwork,active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended,
    route: (): string => this.nativeDisplayAddress(),owns: (pin: string): boolean => this.isCurrentMorePin(pin),sheet: (): string => this.activeSheetKind,
    show: (): void => {this.activeSheetKind = 'more';this.showNativeSheet = true;},
    dismiss: (): void => {if(this.homeStore.customHomeMenu)this.dismissShareSheet();else this.dismissMoreSheet();},
    download: (url: string): void => {this.systemActions.downloadImage(url);},
    help: (url: string): void => {this.systemActions.openLink(url).catch((): void => {});},
    edit: (pin: string): Promise<void> => this.openEditPin(pin),
    share: async (pin: string): Promise<void> => {await this.shareDetailPinAfterMenu(pin);},
    message: (value: string): void => this.showMessage(value),
    undoSnack: (value: string,pin: string): void => {this.pinStore.saveUndoPin = '';this.pinStore.saveUndoId = '';this.showUndoSnack(value,pin,(): void => {this.undoMoreFeedback();});}
  } as PinmonyPinMenuNativePorts);
  private readonly shareNativeFlow: PinmonyShareNativeFlow = new PinmonyShareNativeFlow({
    store: (): PinmonyPinStore => this.pinStore,session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),network: (): PinmonyNativeNetwork => this.nativeNetwork,
    current: (kind: string,page: string,id: string): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && (kind === 'pin' ? (this.pinStore.detail?.pinUrl === page && this.currentPinUrl() === page || this.homeStore.homeMenuPin === page && this.isCurrentMorePin(page)) : kind === 'board' ? this.boardStore.boardDetail?.pageKey === page && this.boardStore.boardDetail?.boardId === id && this.boardStore.boardDetail?.nativeAccountGeneration === this.nativeBusinessSessionContext().generation && this.boardStore.boardDetail?.nativeReadsReady === true && this.boardStore.boardDetail?.ready === true && this.currentBoardUrl() === page : (this.activeTab === 3 || this.profileStore.origins.length > 0) && this.profileStore.profile?.profileUrl === page && this.currentProfileUrl() === page && !this.pinStore.detail && !this.boardStore.boardDetail),
    visible: (): boolean => this.activeSheetKind === 'share' && this.showNativeSheet,
    show: (profile: boolean): void => {this.suspendMoreForShare();this.profileShareMode = profile;this.activeSheetKind = 'share';this.showNativeSheet = true;},
    feedback: (): void => this.showShareFeedbackSnack(),copy: (value: string): Promise<void> => this.systemActions.copyText(value),share: (value: string): Promise<void> => this.pinStore.shareOnPinDetail ? this.shareDetailPinAfterMenu(value, '', true) : this.sharePinUrl(value,this.profileStore.profile?.displayName || 'Pinterest')
  } as PinmonyShareNativePorts);
  private readonly publishNativeFlow: PinmonyPublishNativeFlow = new PinmonyPublishNativeFlow({
    store: (): PinmonyProfileStore => this.profileStore,session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && (this.activeTab === 3 || !!this.publishBoardReturn),foreground: (): boolean => !this.businessSuspended,
    page: (): string => this.profileUrlFromAddress(this.authenticatedProfileUrl),
    done: (): void => {const flow: PinmonyPublishFlow | undefined = this.profileStore.publishFlow;if(!flow)return;const count: number = flow.completed,board: boolean = flow.kind === 'board';this.closePublishFlow();if(count)this.showMessage(board ? this.uiText("pm_board_created_f7d22eaf") : this.uiText("pm_published_58e1bd74") + count.toString() + this.uiText("pm_pins_0a89904f"));}
  } as PinmonyPublishNativePorts);
  private readonly publishController: PinmonyPublishController = new PinmonyPublishController(this.profileStore, {
    nativeFlow: (): boolean => PIN_NATIVE_SHARE_PUBLISH_ENABLED,
    nativeMenu: (current: () => boolean): Promise<boolean> => this.publishNativeFlow.menu(current),
    nativeOpen: (): Promise<boolean> => this.publishNativeFlow.open(),
    nativeAction: (action: string,value: string,secret: boolean): Promise<void> => this.publishNativeFlow.action(action,value,secret),
    nativePause: (): void => this.publishNativeFlow.pause(),nativeClose: (): void => this.publishNativeFlow.close(),
    authenticated: (): boolean => this.authStatus === 'authenticated',
    foreground: (): boolean => !this.businessSuspended,
    activeProfileTab: (): boolean => this.activeTab === 3 || this.nativeBoardVisible() || !!this.publishBoardReturn,
    menuVisible: (): boolean => this.activeSheetKind === 'publish' && this.showNativeSheet,
    sheetAvailable: (): boolean => !this.activeSheetKind && !this.publishSheetClosing,
    setMenuVisible: (visible: boolean): void => {
      if (visible) { this.activeSheetKind = 'publish'; this.showNativeSheet = true; }
      else { this.publishSheetClosing = this.activeSheetKind === 'publish'; this.showNativeSheet = false; }
    },
    waitMenuClosed: (): Promise<boolean> => new Promise<boolean>((resolve): void => {
      this.publishSheetClosed = resolve;
      this.pageTasks.timeout((): void => {
        if (this.publishSheetClosed === resolve) { this.publishSheetClosed = undefined; resolve(false); }
      }, 2000);
    }),
    profileAddress: (): string => this.profileUrlFromAddress(this.authenticatedProfileUrl),
    openSection: (): void => this.openBoardSection(),
    documentMatches: (profile: string): boolean => this.profileDocumentMatches(profile),
    currentDocument: (): string => PIN_NATIVE_SHARE_PUBLISH_ENABLED ? this.profileUrlFromAddress(this.authenticatedProfileUrl) : this.sessionDocumentUrl(),
    normalizeProfile: (address: string): string => this.profileUrlFromAddress(address),
    prepareContext: (current: () => boolean): Promise<boolean> => this.prepareProfileInteraction('publish', current),
    nativeEnabled: (): boolean => PIN_NATIVE_NETWORK_ENABLED,
    publishScript: (): string => useNativeTransport(PIN_PUBLISH_API_SCRIPT),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    jsonText: (value: string): string => this.webJsonText(value),
    captureBoardReturn: (): void => {
      this.publishBoardReturn = this.nativeBoardVisible() ? this.boardStore.boardDetail?.pageKey || '' : '';
      if (this.publishBoardReturn) {
        this.nativeRootOnly = false;
        this.boardStore.presentationPage = this.publishBoardReturn;
        this.boardStore.presentationOnly = true;
        this.pagePerformance.cancel();
        this.detailReturnJourney.close();
      }
    },
    hasBoardReturn: (): boolean => !!this.publishBoardReturn,
    restoreBoard: (refresh?: boolean): void => this.restorePublishBoard(refresh),
    syncMotion: (): void => this.syncFloatingTabsMotion(),
    suppressChildBack: (): void => { this.nativeChildBackUntil = Date.now() + 300; },
    refreshProfile: (): void => this.refreshProfile(),
    pickPhotos: (token: number, page: string): Promise<void> => this.pickPublishPhotos(token, page),
    feedback: (value: string): void => this.showMessage(value),
    traceEntry: (): void => this.traceAction('profile.publish')
  } as PinmonyPublishPorts);

  private readonly profileSearchReads: PinmonyProfileSearchNativeReads = new PinmonyProfileSearchNativeReads({
    store: () => this.profileStore, session: () => this.nativeBusinessSessionContext(), network: () => this.nativeNetwork,
    active: () => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 3 && this.profileStore.searchVisible &&
      !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.activeSheetKind && !this.nativeBoardVisible() && this.profileStore.origins.length === 0
  });
  private readonly searchNativeReads: PinmonySearchNativeReads = new PinmonySearchNativeReads({
    profile: (): string => this.authenticatedProfileUrl,
    feedback: (message: string): void => this.showMessage(message),
    boardFollowConfirmed: (): void => { this.profileStore.profileCache.clear(); },
    store: (): PinmonySearchStore => this.searchStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    page: (): string => this.currentSearchPageKey(),
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 1 &&
      !this.pinStore.detail && !this.pinStore.detailOpeningPin && (!this.activeSheetKind || this.activeSheetKind === 'searchFilter') && !this.boardStore.pendingBoardUrl && !this.boardStore.boardDetail && !this.profileSettingsVisible && !this.profileStore.panel && !this.inboxStore.inboxFlow,
    navigate: (page: string): void => { this.searchDiscoveryNativeReads.pause(); this.searchController.invalidatePending(); this.returnCoordinator.cancel(); this.pageBackToken++; this.clearRootTabGuard('native-search-navigation'); this.rootTabAddresses.set(1,page); this.navigationAddress = page; this.nativeRootOnly = true; this.nativeBackTarget = ''; this.pendingWebTab = -1; this.retainedRootTabPending = -1; this.loadFailed = false; this.rootContentInteracted = true; this.syncFloatingTabsMotion(); },
    settled: (): void => { this.finishRootPull('search'); this.pagePerformance.mark(1,'content-ready'); this.rootContextCoordinator.notify(); }
  } as PinmonySearchNativeReadsPorts);

  private readonly searchDiscoveryNativeReads: PinmonySearchDiscoveryNativeReads = new PinmonySearchDiscoveryNativeReads({
    store: (): PinmonySearchStore => this.searchStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    page: (): string => this.currentSearchPageKey(),
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 1 &&
      !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.activeSheetKind && !this.boardStore.pendingBoardUrl &&
      !this.boardStore.boardDetail && !this.profileSettingsVisible && !this.profileStore.panel && !this.inboxStore.inboxFlow,
    committed: (page: string): void => { this.rootTabAddresses.set(1, page); this.pagePerformance.mark(1, 'content-ready'); },
    settled: (): void => { this.finishRootPull('search'); this.rootContextCoordinator.notify(); }
  } as PinmonySearchDiscoveryNativeReadsPorts);

  private readonly homeNativeReads: PinmonyHomeNativeReads = new PinmonyHomeNativeReads({
    store: (): PinmonyHomeStore => this.homeStore,
    session: (): PinmonyBusinessSessionContext => this.nativeBusinessSessionContext(),
    username: (): string => this.authenticatedProfileUrl.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/([A-Za-z0-9_]+)\/$/)?.[1] || '',
    network: (): PinmonyNativeNetwork => this.nativeNetwork,
    active: (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 0 &&
      !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.activeSheetKind && !this.profileStore.origins.length && !this.boardStore.pendingBoardUrl && !this.profileSettingsVisible && !this.profileStore.panel && !this.inboxStore.inboxFlow,
    saved: (id: string): boolean => this.pinStore.confirmedSaves.isSaved(id),
    committed: (snapshot: PinmonyHomeSnapshot, kind: 'feed' | 'pagination' | 'cache' | 'metadata' = 'feed'): void => {
      this.rootTabAddresses.set(0, snapshot.pageKey); this.retainedHomeAwaitingFeed = false; this.interruptedHomePage = '';
      this.homeRecoveryAttempted = false; this.homeRecoveryToken++;
      if (kind === 'feed') {
        if (this.authStatus === 'authenticated' && !snapshot.sourceError && !this.businessSuspended) {
          PinmonyUpdateNotice.start(this.getUIContext().getHostContext() as common.UIAbilityContext);
        }
        this.pagePerformance.mark(0, 'content-ready'); this.detailReturnJourney?.mark('return.home.feed.confirmed');
      }
      if (!snapshot.sourceError) this.persistHomeDiskCache(snapshot); this.rootContextCoordinator.notify();
      try { this.runSessionScript('window.PinmonyHomeDemand && window.PinmonyHomeDemand()').catch(() => {}); } catch (_) {}
    }
  } as PinmonyHomeNativeReadsPorts);

  private readonly homeController: PinmonyHomeController = new PinmonyHomeController(this.homeStore, {
    documentEpoch: (): number => this.authEpoch,
    nativeReads: (): boolean => PIN_NATIVE_HOME_READS_ENABLED,
    nativeDemand: (): Promise<void> => this.homeNativeReads.demand(),
    nativeSelect: (id: string): Promise<void> => this.homeNativeReads.select(id),
    nativeMore: (): Promise<void> => this.homeNativeReads.more(),
    nativeRefresh: (): Promise<void> => this.homeNativeReads.refresh(),
    canAcceptMessages: (): boolean => {
      if (this.nativeRootOnly && !this.rootContentInteracted || this.retainedHomeAwaitingAuth) return false;
      if (this.nativeBackTarget) {
        try { return this.pageHistory.key(this.sessionDocumentUrl()) === this.pageHistory.key(this.nativeBackTarget); }
        catch (_) { return false; }
      }
      return true;
    },
    currentPageKey: (): string => this.currentHomePageKey(),
    presentationPageKey: (): string => this.homePresentationPageKey(),
    retainedPageKey: (): string => this.retainedHomeRootPageKey(),
    pageKeyFromAddress: (url: string): string => this.homePageKeyFromAddress(url),
    isOtherRoot: (url: string): boolean => !!(this.searchUrlFromAddress(url) || this.inboxUrlFromAddress(url) || this.profileUrlFromAddress(url)),
    isActive: (): boolean => this.activeTab === 0,
    isAuthenticated: (): boolean => this.authStatus === 'authenticated',
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    ensureContext: (requireData: boolean, isCurrent: () => boolean): Promise<boolean> =>
      this.ensureRootActionContext(0, requireData, '', isCurrent),
    rejectOffline: (operation: string): boolean => this.rejectOfflineAction(operation),
    recoverOffline: (): boolean => {
      if (!this.offlinePreviewMode) return false;
      if (this.authStatus === 'checking' && this.webPageLoading) return true;
      PinmonyRuntimeLog.info('OfflineCache: recovery requested source=home-refresh');
      this.retryLogin();
      return true;
    },
    prepareRead: (): boolean => this.nativeRootOnly && this.prepareRootPageRead(0),
    requestRead: (): void => this.requestRootPage(0),
    reloadPage: (pageKey: string, refreshCurrent: boolean): void => {
      if (refreshCurrent) this.controller.refresh();
      else this.loadSessionDocument(pageKey);
    },
    pinIdentity: (url: string): string => this.pinIdentity(url),
    knownPinTitle: (identity: string): string => this.searchStore.knownSearchPinTitles.get(identity) || '',
    isSaved: (identity: string): boolean => this.pinStore.confirmedSaves.isSaved(identity),
    hasMeaningfulTitle: (title: string): boolean => this.hasMeaningfulSearchPinTitle(title),
    recordPageKey: (pageKey: string): void => { this.rootTabAddresses.set(0, pageKey); },
    persistSnapshot: (snapshot: PinmonyHomeSnapshot): void => this.persistHomeDiskCache(snapshot),
    cardsCommitted: (pageKey: string, count: number, retained: boolean): void => {
      if (count <= 0 || this.homeTraceCardsPageKey === pageKey) return;
      this.homeTraceCardsPageKey = pageKey;
      const documentElapsed: number = this.homeTracePageKey === pageKey && this.lastDocumentBeginAt > 0 ?
        Date.now() - this.lastDocumentBeginAt : -1;
      const appElapsed: number = typeof PinmonyRuntimeLog.sessionElapsedMs === 'function' ? PinmonyRuntimeLog.sessionElapsedMs() : 0;
      PinmonyRuntimeLog.info('StartupTrace: home cards state committed count=' + count.toString() +
        ' retained=' + retained.toString() + ' appElapsedMs=' + appElapsed.toString() +
        (documentElapsed >= 0 ? ' documentElapsedMs=' + documentElapsed.toString() : ''));
    },
    contentReady: (count: number): void => {
      if (this.rootReadToken === this.tabRequestToken && this.rootReadAddress === this.currentHomePageKey() && this.rootReadStartedAt > 0 && this.homeReadyToken !== this.rootReadToken) {
        this.homeReadyToken = this.rootReadToken;
        PinmonyRuntimeLog.info('HomeRecoveryTrace: phase=content-ready count=' + count.toString() +
          ' elapsedMs=' + (Date.now() - this.rootReadStartedAt).toString());
      }
    },
    markFeedConfirmed: (): void => { this.detailReturnJourney?.mark('return.home.feed.confirmed'); },
    finishRecovery: (): void => {
      if (this.retainedHomeAwaitingFeed) PinmonyRuntimeLog.info('PinmonyReturn: retained home feed confirmed');
      this.retainedHomeAwaitingFeed = false;
      if (this.interruptedHomePage) PinmonyRuntimeLog.info('HomeRecovery: current home API state confirmed');
      this.interruptedHomePage = '';
      this.homeRecoveryAttempted = false;
      this.homeRecoveryToken++;
    },
    openPin: (pinUrl: string, source: string): void => {
      this.pinStore.detailReturnUrl = source;
      if (pinUrl) this.beginDetailOpening(pinUrl, source);
      try {
        if (pinUrl && !PIN_NATIVE_DETAIL_READS_ENABLED) this.loadSessionDocument(pinUrl);
        else if(!pinUrl) { this.pinStore.detailOpeningPin = ''; this.showMessage(PinmonyI18n.message("pm_unable_to_open_pin_please_retry_1260c20b")); }
      } catch (_) { this.pinStore.detailOpeningPin = ''; this.showMessage(PinmonyI18n.message("pm_unable_to_open_pin_please_retry_1260c20b")); }
    },
    traceAction: (name: string, detail: string): void => this.traceAction(name, detail),
    showMessage: (message: string): void => this.showMessage(message)
  } as PinmonyHomePorts);

  private readonly searchController: PinmonySearchController = new PinmonySearchController(this.searchStore, {
    nativeSearch: (): boolean => this.searchNativeReads.eligible() && this.activeTab === 1 && (!this.searchStore.search?.quiz || this.searchStore.search.quiz.mode === 'entry'),
    nativeSearchApply: (): void => this.searchNativeReads.apply(),
    nativeSearchDemand: (): Promise<void> => this.searchNativeReads.demand(),
    nativeSearchMore: (): Promise<void> => this.searchNativeReads.more(),
    nativeSearchRefresh: (): Promise<void> => this.searchNativeReads.refresh(),
    nativeSearchInput: (term: string, immediate: boolean): Promise<void> => this.searchNativeReads.input(term,immediate),
    nativeSearchClearProductFilter: (kind: string): void => this.searchNativeReads.clearProductFilter(kind),
    nativeSearchFollowUser: (id: string): Promise<void> => this.searchNativeReads.followUser(id),
    nativeSearchFollowBoard: (id: string): Promise<void> => this.searchNativeReads.followBoard(id),
    nativeSearchDeleteHistory: (id: string): Promise<void> => this.searchNativeReads.deleteHistory(id),
    nativeSearchCancelFilters: (): void => this.searchNativeReads.cancelFilters(),
    nativeSearchFilters: (): Promise<void> => this.searchNativeReads.filters(),
    nativeSearchFilterTarget: (id: string): string => this.searchNativeReads.filterTarget(id),
    nativeDiscovery: (): boolean => this.searchDiscoveryNativeReads.eligible() && this.activeTab === 1,
    nativeDiscoveryApply: (): void => this.searchDiscoveryNativeReads.apply(),
    nativeDiscoveryDemand: (): Promise<void> => this.searchDiscoveryNativeReads.demand(),
    nativeDiscoveryMore: (): Promise<void> => this.searchDiscoveryNativeReads.more(),
    nativeDiscoveryRefresh: (): Promise<void> => this.searchDiscoveryNativeReads.refresh(),
    currentPageKey: (): string => this.currentSearchPageKey(),
    isActive: (): boolean => this.authStatus === 'authenticated' && this.activeTab === 1,
    preservingPinSearch: (): boolean => this.preservingSearchForPin(),
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    ensureContext: (requireData: boolean, allowedSheet: string = '', isCurrent: () => boolean = (): boolean => true): Promise<boolean> =>
      this.ensureRootActionContext(1, requireData, allowedSheet, isCurrent),
    markInteracted: (): void => { this.rootContentInteracted = true; },
    clearTabGuard: (reason: string): void => this.clearRootTabGuard(reason),
    finishPull: (): void => this.finishRootPull('search'),
    recordPageKey: (pageKey: string): void => { this.rootTabAddresses.set(1, pageKey); },
    setDetailReturn: (pageKey: string): void => { this.pinStore.detailReturnUrl = pageKey; },
    navigateSearch: (target: string, source: string): void => {
      if (source) this.pageHistory.visit(source, 'load');
      if (this.searchNativeReads.eligible() && (!this.searchStore.search?.quiz || this.searchStore.search.quiz.mode === 'entry')) { this.searchNativeReads.navigate(target); return; }
      this.prepareSearchNavigation(target);
      this.loadSessionDocument(target);
    },
    navigateResult: (target: string, source: string): void => {
      if(PIN_NATIVE_SEARCH_READS_ENABLED){this.openNativeSearchResult(target,source);return;}
      this.pageHistory.visit(source, 'load');
      this.beginDetailOpening(this.extractPinUrl(target), source);
      if(!PIN_NATIVE_DETAIL_READS_ENABLED)this.loadSessionDocument(this.extractPinUrl(target) || target);
    },
    cancelNavigation: (clearRetained: boolean): void => {
      this.rootReadToken = -1; this.pendingWebTab = -1;
      if (clearRetained) this.retainedRootTabPending = -1;
    },
    clearOpeningDetail: (): void => { this.pinStore.detailOpeningPin = ''; },
    sheetKind: (): string => this.activeSheetKind,
    navigateFilterAfterClose: (target: string, source: string): void => {
      this.pendingSearchFilterTarget = target; this.pendingSearchFilterSource = source;
      this.dismissSearchFilters();
    },
    setFilterVisible: (visible: boolean): void => {
      if (visible) { this.activeSheetKind = 'searchFilter'; this.showNativeSheet = true; }
      else { this.showNativeSheet = false; }
    },
    prepareRead: (): boolean => this.nativeRootOnly && this.prepareRootPageRead(1),
    requestRead: (): void => this.requestRootPage(1),
    pinIdentity: (url: string): string => this.pinIdentity(url),
    traceAction: (name: string, detail: string = ''): void => this.traceAction(name, detail),
    showMessage: (message: string): void => this.showMessage(message)
  } as PinmonySearchPorts);

  private readonly detailController: PinmonyDetailController = new PinmonyDetailController({
    store: this.pinStore,
    postApiEnabled: (): boolean => PIN_POST_API_ENABLED,
    nativePostAction: async (kind: string): Promise<boolean> => {if(PIN_NATIVE_PIN_MENUS_ENABLED && kind === 'more'){if(this.detailNativeReads.owned())await this.openApiDetailMore();return true;}if(PIN_NATIVE_COMMENT_WRITES_ENABLED && kind === 'comment'){if(this.detailNativeReads.owned())await this.openApiComments();return true;}if(PIN_NATIVE_SHARE_PUBLISH_ENABLED && kind === 'share'){const pin: string = this.pinStore.detail?.pinUrl || '';if(pin)await this.shareNativeFlow.open('pin',pin,this.pinIdentity(pin));return true;}return this.postNativeOperations ? this.postNativeOperations.detailAction(kind) : false;},
    postExtensionsEnabled: (): boolean => PIN_POST_EXTENSIONS_ENABLED,
    isAuthenticated: (): boolean => this.authStatus === 'authenticated',
    isForeground: (): boolean => this.pinStore.videoForeground,
    isOffline: (operation: string): boolean => this.rejectOfflineAction(operation),
    currentPinUrl: (): string => this.currentPinUrl(),
    pinIdentity: (url: string): string => this.pinIdentity(url),
    beginDetailOpening: (pin: string): void => this.beginDetailOpening(pin),
    loadDetailUrl: (pin: string): void => {if(!PIN_NATIVE_DETAIL_READS_ENABLED)this.loadSessionDocument(pin);},
    runScript: (script: string): Promise<string> => this.runSessionScript(script),
    markJourney: (event: string): void => this.detailJourney.mark(event),
    openComments: (): void => { this.openApiComments(); },
    cancelSave: (pin: string): Promise<void> => this.cancelDetailSave(pin),
    openBoards: (): Promise<void> => this.openApiBoards(),
    openShare: (pin: string): Promise<string> => this.runSessionScript('window.PinmonyNativeShareApiOpen && ' +
      'window.PinmonyNativeShareApiOpen(' + JSON.stringify(pin) + ')'),
    openMore: (): Promise<void> => this.openApiDetailMore(),
    externalSourceUrl: (url: string): string => this.externalSourceUrl(url),
    openExternalLink: (url: string): Promise<void> => this.systemActions.openLink(url),
    traceAction: (name: string, detail: string): void => this.traceAction(name, detail),
    showMessage: (message: string): void => this.showMessage(message)
  } as PinmonyDetailPorts);

  private readonly systemActions: PinmonySystemActions = new PinmonySystemActions(
    (): common.UIAbilityContext => this.getUIContext().getHostContext() as common.UIAbilityContext,
    (message: string): void => this.showMessage(message)
  );

  private inboxPollTimer: number = -1;
  private inboxPollPending: boolean = false;
  private inboxPollTick: number = 0;

  private pollVisibleInbox(): void {
    if (this.inboxUpdatesNativeReads.eligible()) {
      if (this.businessSuspended || this.authStatus !== 'authenticated' || this.activeTab !== 2 ||
          !this.nativeRootTabsVisible() || this.inboxStore.inboxLoading) return;
      this.inboxPollTick++;
      if (this.inboxPollTick % 3 === 0) this.inboxUpdatesNativeReads.poll();
      return;
    }
    if(this.inboxMessagesNativeReads.eligible()) {this.inboxPollTick++; if(this.inboxStore.inboxFlow || this.inboxPollTick % 3 === 0)this.inboxMessagesNativeReads.poll(); return;}
    if (this.inboxPollPending || this.businessSuspended || this.authStatus !== 'authenticated' || this.activeTab !== 2 ||
      this.nativeBoardVisible() || this.pinStore.detail || this.pinStore.detailOpeningPin || this.activeSheetKind ||
      !this.inboxStore.inboxActionsReady || this.inboxStore.inboxLoading) return;
    const flow: PinmonyInboxFlowSnapshot | undefined = this.inboxStore.inboxFlow;
    if (flow && (flow.screen !== 'chat' || flow.pageUrl !== this.currentInboxUrl())) return;
    if (!flow && !this.nativeRootTabsVisible()) return;
    this.inboxPollTick++;
    if (!flow && this.inboxPollTick % 3 !== 0) return;
    try {
      const script: string = 'window.PinmonyInboxPoll && window.PinmonyInboxPoll(' +
        JSON.stringify(this.sessionDocumentUrl()) + ',' + this.inboxStore.inboxSession.toString() + ',' + (!!flow).toString() + ')';
      this.inboxPollPending = true;
      this.runSessionScript(script).catch(() => {}).finally(() => { this.inboxPollPending = false; });
    } catch (_) { this.inboxPollPending = false; }
  }

  private startupBuildLogged: boolean = false;

  onDidBuild(): void {
    if (this.startupBuildLogged) return;
    this.startupBuildLogged = true;
    // Component build completion is not a physical display/first-frame timestamp.
    this.logStartupBoundary('index-first-build');
  }

  private logStartupBoundary(event: string): void {
    const now: number = Date.now();
    const createdAt: number = AppStorage.get<number>('pinmonyAbilityCreatedAt') || 0;
    const loadAt: number = AppStorage.get<number>('pinmonyContentLoadStartedAt') || 0;
    PinmonyRuntimeLog.info('StartupBoundary: ' + event +
      ' sinceAbilityMs=' + (createdAt > 0 ? now - createdAt : -1).toString() +
      ' sinceLoadContentMs=' + (loadAt > 0 ? now - loadAt : -1).toString());
  }

  aboutToAppear(): void {
    this.logStartupBoundary('index-about-to-appear');
    PinmonyRuntimeLog.info('NativeSession: lifecycle enabled=' + this.nativeLoginEnabled.toString());
    if(this.nativeLoginEnabled){
      try {this.sessionEnvironment.capture(webview.WebviewController.getDefaultUserAgent());}catch (_) {}
      const stored: string = AppStorage.get<string>('pinmonySessionOrigin') || '';
      if(/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(stored))this.nativeSessionOrigin = stored;
      this.coordinatorTasks.timeout((): void => {this.startNativeVerification();},0);
    }
    if (this.inboxPollTimer < 0) this.inboxPollTimer = setInterval(() => this.pollVisibleInbox(), 5000);
    this.logPageLifecycle('about-to-appear', 'stores=7 bridge=bind');
    this.systemActions.activate();
    this.initializeHomeApiCache();
    this.initializeOfflineHomeMarker();
    bindStoreNavigation([this.inboxStore, this.pinStore, this.profileStore, this.boardStore, this.searchStore],
      (): void => this.syncFloatingTabsMotion());

    this.shareBridge.onNetworkRequest = (value: string) => this.requestNativeNetwork(value);
    const readTrace = (id: string, resource: string, event: string, duration: number, attempt: number): void => {
      if (this.detailRequestOwners.get(id) !== this.detailJourney.current() || !this.detailJourney.current()) return;
      this.detailJourney.mark(resource + '.attempt' + attempt.toString() + '.' + event, false, duration);
    };
    this.nativeNetwork.onReadTrace = readTrace;
    this.detailReadNetwork.onReadTrace = readTrace;
    this.nativeNetwork.onTransientRetry = (_resource: string, speculative: boolean) => {
      if (!speculative) this.showNetworkNotice(PinmonyI18n.message("pm_connection_unstable_retrying_d0b9af7d"));
    };
    const rateLimited = (remainingMs: number): void => {
      this.pinStore.detailPrefetch.pause();
      this.showNetworkNotice(remainingMs > 0 ? this.uiText("pm_too_many_requests_retry_in_b763b85d") +
        Math.ceil(remainingMs / 1000).toString() + ' 秒后重试' : this.uiText("pm_checking_service_availability_please_retry_later_849dea59"));
    };
    this.nativeNetwork.onRateLimited = rateLimited;
    this.detailReadNetwork.onRateLimited = rateLimited;
    this.shareBridge.onCancelNetwork = (id: string) => this.cancelNativeNetwork(id);
    this.shareBridge.onAuthState = (value: string) => this.updateAuthState(value);
    this.shareBridge.onPageBack = () => {
      if(this.nativeBusinessRoutesEnabled)return;
      if (this.backInProgress) return;
      if (this.currentPinUrl()) this.backFromDetail();
      else if (this.currentSearchPageKey()) this.backFromSearch();
      else this.backOnePage();
    };
    this.shareBridge.onPageNavigation = (url: string, mode: string) => {
      if(this.nativeBusinessRoutesEnabled && this.authStatus === 'authenticated' && !isPinterestAuthRoute(url)){this.syncAuthentication();return;}
      if (this.nativeRootOnly && !isPinterestAuthRoute(url)) return;
      if (this.detailReturnedToRoot && this.extractPinUrl(url)) return;
      if (this.ignoreSupersededDetailDocument(url)) return;
      try {
        if (this.pageHistory.key(url) !== this.pageHistory.key(this.sessionDocumentUrl())) return;
        if (this.logoutAwaitingLogin && !isPinterestAuthRoute(url)) return;
        if (this.nativeBackTarget && this.pageHistory.key(url) !== this.pageHistory.key(this.nativeBackTarget) ||
            this.pinStore.detailOpeningPin && this.pinIdentity(url) !== this.pinIdentity(this.pinStore.detailOpeningPin)) return;
        if (mode === 'restore') {
          this.authEpoch++;
          this.nativeNetwork.invalidateDocument();
          this.webPageLoading = false;
          this.retainedHomeAwaitingAuth = !!this.homePageKeyFromAddress(url);
          this.retainedHomeAwaitingFeed = this.retainedHomeAwaitingAuth;
          this.homeStore.homeActionsReady = false;
          PinmonyRuntimeLog.info('PinmonyReturn: document restored from BFCache');
          this.detailReturnJourney?.mark('return.document.retained');
        }
        if (mode === 'ready') PinmonyRuntimeLog.info('StartupTrace: document ready');
        this.recordPageNavigation(url, mode === 'ready' ? 'observe' : mode);
        this.bindCurrentDetailDocument(url);
        this.syncAuthentication();
      } catch (error) {
        PinmonyRuntimeLog.warn('Pinmony: page navigation state unavailable');
      }
    };
    this.shareBridge.onShare = (targetUrl: string, pinUrl: string) => {
      if (this.authStatus !== 'authenticated') return;
      if (this.activeSheetKind === 'more') this.dismissMoreSheet();
      else this.dismissShareSheet();
      this.shareFromTarget(targetUrl, pinUrl);
    };
    this.shareBridge.onHomeMenuChanged = (session: number): void => this.photoMenuCoordinator.menuChanged(session);
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
      if(this.nativeBusinessRoutesEnabled)return;
      if (this.authStatus !== 'authenticated') return;
      if (this.nativeRootOnly) return;
      try {
        const address: string = this.sessionDocumentUrl();
        if (this.ignoreSupersededDetailDocument(address)) return;
        if (this.nativeBackTarget && this.pageHistory.key(address) !== this.pageHistory.key(this.nativeBackTarget)) return;
        this.navigationAddress = address;
        this.syncNativeReturnRoute(this.navigationAddress);
        this.syncBoardRoute(this.navigationAddress);
        // Secondary routes cannot replace the native root selected by their entry point.
        if (this.nativeBackTarget || this.boardUrlFromAddress(address) || this.extractPinUrl(address)) return;
      } catch (error) {
        this.navigationAddress = this.lastPageUrl;
      }
      this.showNativeTabs = visible || !!this.searchUrlFromAddress(this.navigationAddress);
      if (index >= 0 && index < 4) {
        if (this.currentInboxUrl() && !this.inboxStore.inbox &&
          !this.inboxStore.inboxLoading && !this.inboxStore.inboxError && !this.inboxStore.inboxWebFlow) this.expectInbox();
        if (index !== 2 && !this.currentInboxUrl() && this.pendingWebTab !== 2) this.clearInbox();
        const profileRoute: string = this.profileUrlFromAddress(this.navigationAddress);
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
        const searchConfirmed: boolean = !!this.searchUrlFromAddress(this.navigationAddress);
        const resolvedIndex: number = profileConfirmed ? 3 : searchConfirmed ? 1 :
          this.inboxUrlFromAddress(this.navigationAddress) ? 2 : this.isHomeRootAddress(this.navigationAddress) ? 0 : index;
        if (!profileRoute && resolvedIndex !== 3) {
          if ((this.profileStore.profileLoading || this.profileStore.profileError) && this.pendingWebTab === 3 &&
              !this.currentPinUrl()) return;
          this.clearProfile(this.profileStore.profileWebFlow);
        } else if (profileRoute && !this.profileStore.profile && !this.profileStore.profileLoading && !this.profileStore.profileError) {
          this.expectProfile();
          if (this.profileStore.profile) {
            this.runSessionScript('window.PinmonyProfileSync && window.PinmonyProfileSync()')
              .catch(() => PinmonyRuntimeLog.warn('Pinmony: retained profile sync unavailable'));
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
    this.sessionVerification?.cancel('destroy');
    if(this.nativeLoginEnabled){this.nativeSessionEpoch++;this.nativeVerificationPending = false;}
    if (this.inboxPollTimer >= 0) clearInterval(this.inboxPollTimer);
    this.inboxPollTimer = -1;
    this.returnCoordinator.cancel();
    this.controllerLifecycle().pause();
    this.pagePerformance.cancel();
    this.homeController.invalidatePending();
    this.logPageLifecycle('about-to-disappear', 'stores=7 bridge=unbind network=invalidate');
    this.systemActions.dispose();
    this.searchController.invalidatePending();
    const pendingBefore: number = this.pageTasks.invalidate();
    PinmonyRuntimeLog.info('PageLifecycle: tasks-invalidated pendingBefore=' + pendingBefore.toString() +
      ' pendingAfter=' + this.pageTasks.pendingCount().toString());
    bindStoreNavigation([this.inboxStore, this.pinStore, this.profileStore, this.boardStore, this.searchStore], undefined);

    this.nativeNetwork.invalidate();
    this.shareBridge.onNetworkRequest = undefined;
    this.nativeNetwork.onReadTrace = undefined; this.detailReadNetwork.onReadTrace = undefined;
    this.nativeNetwork.onRateLimited = undefined; this.detailReadNetwork.onRateLimited = undefined;
    this.detailJourney.close(); this.detailReturnJourney.close(); this.detailRequestOwners.clear();
    this.detailImageStage.reset();
    this.detailReadNetwork.invalidate(); this.openingRelated = undefined; this.pinStore.detailPrefetch.pause();
    this.shareBridge.onCancelNetwork = undefined;
    PinmonyRuntimeLog.info('PinmonyReturn: root page disappeared');
    this.shareBridge.onAuthState = undefined;
    if (this.authCheckTimer !== -1) this.pageTasks.cancelTimeout(this.authCheckTimer);
    this.dismissPostSnack();
    this.homeStore.customHomeMenuToken++;
    this.homeStore.customHomeMenu = undefined;
      this.photoMenuCoordinator.notify();
    this.pinStore.commentToken++;
    this.shareBridge.onHomeMenuChanged = undefined;
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

  private sessionDocumentUrl(): string {
    if(this.nativeLoginEnabled && !this.loginHostMounted)return '';
    try {return this.controller.getUrl();}catch (_) {return '';}
  }

  private runSessionScript(script: string): Promise<string> {
    if(this.nativeLoginEnabled && !this.loginHostMounted)return Promise.resolve('');
    try {return this.controller.runJavaScript(script);}catch (_) {return Promise.resolve('');}
  }

  private loadSessionDocument(url: string): void {
    if(this.nativeLoginEnabled && !this.loginHostMounted)return;
    try { this.controller.loadUrl(url); }
    catch (_) { throw new Error('session-navigation-unavailable'); }
  }

  private startNativeVerification(): void {
    if(!this.nativeLoginEnabled || this.businessSuspended || this.nativeVerificationPending)return;
    try {
      if (!connection.hasDefaultNetSync()) {
        this.sessionVerification.cancel('offline'); this.nativeSessionEpoch++;
        this.authStatus = 'error'; this.offlineCacheLoading = false; this.loadFailed = false;
        this.failureDetails = PinmonyI18n.message("pm_you_are_offline_connect_and_retry_0bc36d3c");
        PinmonyRuntimeLog.info('NativeSession: verification deferred reason=offline');
        return;
      }
    } catch (_) { /* Unknown network availability is not proof of being offline. */ }
    // Offline startup must not navigate to login or erase cached content.
    // This non-credential hint only chooses presentation; it never grants access.
    if (!this.loginHostMounted && AppStorage.get<boolean>('pinmonySessionConfirmed') !== true) {
      PinmonyRuntimeLog.info('NativeSession: login required reason=no-confirmed-history');
      this.openNativeLogin();
      return;
    }
    if(!this.sessionEnvironment.userAgent()){
      try {this.sessionEnvironment.capture(webview.WebviewController.getDefaultUserAgent());}catch (_) {}
    }
    if(!this.sessionEnvironment.userAgent()){
      this.authStatus = 'error';this.failureDetails = PinmonyI18n.message("pm_session_not_ready_please_retry_12de001e");return;
    }
    this.sessionVerification.cancel('native-attempt');
    const epoch: number = ++this.nativeSessionEpoch;
    this.nativeVerificationPending = true;this.authStatus = 'checking';this.offlineCacheLoading = false;
    this.loadFailed = false;this.failureDetails = '';
    void this.sessionVerification.demand().finally((): void => {if(epoch === this.nativeSessionEpoch)this.nativeVerificationPending = false;});
    this.coordinatorTasks.timeout((): void => {
      if(epoch !== this.nativeSessionEpoch || this.authStatus !== 'checking')return;
      this.sessionVerification.cancel('verification-timeout');this.nativeVerificationPending = false;
      this.authStatus = 'error';this.failureDetails = PinmonyI18n.message("pm_session_verification_timed_out_please_retry_a77e4178");
    },15000);
  }

  private openNativeLogin(): void {
    if(!this.nativeLoginEnabled)return;
    if (!PinmonySessionHistory.save(false)) PinmonyRuntimeLog.warn('NativeSession: history reset persistence unavailable');
    this.sessionVerification.cancel('login-required');this.nativeVerificationPending = false;
    this.nativeSessionEpoch++;this.authEpoch++;this.nativeLoginEvidenceKey = '';
    this.loginStartUrl = this.nativeSessionOrigin + '/login/';
    this.loginPageVisible = true;
    this.authStatus = 'unauthenticated';this.offlineCacheLoading = false;this.loadFailed = false;this.failureDetails = '';
    this.nativeRootOnly = false;this.navigationAddress = this.loginStartUrl;
    if(this.loginHostMounted)this.loadSessionDocument(this.loginStartUrl);
    else {this.controller = new webview.WebviewController();this.loginHostMounted = true;}
    PinmonyRuntimeLog.info('NativeSession: login host mounted');
  }

  private async releaseNativeLogin(): Promise<void> {
    if(!this.nativeLoginEnabled || this.authStatus !== 'authenticated')return;
    const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    if(!session.authenticated || !session.origin)return;
    const epoch: number = this.nativeSessionEpoch;
    try {
      await webview.WebCookieManager.saveCookieAsync();
      PinmonyRuntimeLog.info('NativeSession: cookie store saved');
    } catch (_) {
      PinmonyRuntimeLog.warn('NativeSession: cookie store save unavailable');
      return;
    }
    const current: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    if(this.businessSuspended || epoch !== this.nativeSessionEpoch || !current.authenticated ||
        current.generation !== session.generation || current.origin !== session.origin)return;
    this.nativeSessionOrigin = session.origin;
    AppStorage.setOrCreate<string>('pinmonySessionOrigin',session.origin);
    if (!PinmonySessionHistory.save(true)) PinmonyRuntimeLog.warn('NativeSession: history persistence unavailable');
    this.nativeVerificationPending = false;this.nativeSessionEpoch++;this.authEpoch++;
    this.logoutAwaitingLogin = false;this.nativeLoginEvidenceKey = '';this.loginHostMounted = false;
    PinmonyRuntimeLog.info('NativeSession: native account confirmed webMounted=false');
  }

  private handleNativeSessionExpired(origin: string, generation: number): void {
    if(!this.nativeLoginEnabled)return;
    this.coordinatorTasks.timeout((): void => {
      const current: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
      if(!current.authenticated || current.origin !== origin || current.generation !== generation)return;
      this.resetAuthenticatedContent();this.openNativeLogin();
      PinmonyRuntimeLog.info('NativeSession: explicit expiry accepted');
    },0);
  }

  private updateLoginPresentation(url: string): void {
    if (!this.nativeLoginEnabled || !this.loginHostMounted) return;
    if (isPinterestAuthRoute(url) ||
        /^https:\/\/(?:accounts\.google\.com|(?:www|m)\.facebook\.com)\//i.test(url)) {
      this.loginPageVisible = true;
    } else if (/^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(url)) {
      this.loginPageVisible = false;
    }
    // Non-Pinterest intermediate/blank URLs do not establish a business page.
  }

  private authWebVisible(): boolean {
    if (this.nativeLoginEnabled) return this.loginHostMounted && this.loginPageVisible &&
      this.authStatus !== 'authenticated' && this.authStatus !== 'error' && !this.loadFailed;
    if (this.nativeLoginEnabled && !this.loginHostMounted) return false;
    if (this.authStatus === 'authenticated' || this.authStatus === 'error' || this.loadFailed) return false;
    let url: string = this.navigationAddress || PINTEREST_URL;
    try { url = this.sessionDocumentUrl() || url; } catch (_) {}
    return isPinterestAuthRoute(url) ||
      /^https:\/\/(?:accounts\.google\.com|(?:www|m)\.facebook\.com)\//i.test(url);
  }

  private enterAuthenticatedRoot(home: string): void {
    if (!this.nativeBusinessRoutesEnabled || this.authStatus !== 'authenticated' ||
        !/^https:\/\/(?:www|uk)\.pinterest\.com\/$/.test(home)) return;
    this.navigationAddress = home;
    this.rootTabAddresses.set(0, home);
    this.nativeBackTarget = '';
    this.nativeRootOnly = true;
    this.pendingWebTab = -1;
    this.bottomBarCoordinator.resetForSession();
    this.syncFloatingTabsMotion();
    PinmonyRuntimeLog.info('StartupTrace: native root restored after authentication');
  }

  private confirmBusinessSession(appVersion: string = ''): void {
    if (this.authStatus !== 'authenticated') return;
    if (PinmonyI18n.isText(this.networkNotice, "该登录方式暂不可用")) this.clearNetworkNotice();
    const userAgent: string = this.sessionEnvironment?.userAgent() || '';
    this.businessSession.confirm(this.homeCacheAccountId, this.authenticatedProfileUrl, userAgent, appVersion);
    if (PIN_NATIVE_HOME_READS_ENABLED) this.coordinatorTasks.timeout((): void => { this.homeNativeReads.demand(); }, 80);
    if (PIN_NATIVE_SEARCH_DISCOVERY_ENABLED) this.coordinatorTasks.timeout((): void => { this.boardNativeReads.demand(); this.profileNativeReads.demand(); this.searchDiscoveryNativeReads.demand(); this.searchNativeReads.demand(); this.inboxUpdatesNativeReads.demand(); this.inboxMessagesNativeReads.demand(); }, 80);
  }


  private nativeBusinessSessionContext(): PinmonyBusinessSessionContext {
    return this.businessSession.context(this.authStatus);
  }

  private nativeNetworkContext(): PinmonyNetworkContext {
    let page: string = '', userAgent: string = '';
    try { page = this.sessionDocumentUrl(); } catch (_) {}
    userAgent = this.sessionEnvironment?.userAgent() || '';
    return { authenticated: this.authStatus === 'authenticated', epoch: this.authEpoch, page: page, userAgent: userAgent };
  }

  private bindNativeNetwork(): void { if(this.nativeLoginEnabled)return;return this.networkBridgeCoordinator.bindNativeNetwork(); }

  private requestNativeNetwork(value: string): void { return this.networkBridgeCoordinator.requestNativeNetwork(value); }

  private showNetworkNotice(message: string = PinmonyI18n.message("pm_connection_unstable_retrying_d0b9af7d")): void {
    this.networkNotice = message;
    if (this.networkNoticeTimer !== -1) this.pageTasks.cancelTimeout(this.networkNoticeTimer);
    this.networkNoticeTimer = this.pageTasks.timeout(() => {
      this.networkNotice = '';
      this.networkNoticeTimer = -1;
    }, 4500);
  }

  private showUnsupportedLogin(): void {
    if (this.authStatus === 'authenticated' || !this.authWebVisible()) return;
    const message: string = PinmonyI18n.message("pm_this_sign_in_method_is_currently_unavailable_d38f16a5");
    if (this.networkNotice === message) return;
    this.showNetworkNotice(message);
  }

  private clearNetworkNotice(): void {
    this.networkNotice = '';
    if (this.networkNoticeTimer !== -1) {
      this.pageTasks.cancelTimeout(this.networkNoticeTimer);
      this.networkNoticeTimer = -1;
    }
  }

  private bindCurrentDetailDocument(url: string): void {
    this.detailDocumentBindingService.bindCurrentDetailDocument(url);
  }

  private probeDetailDocument(url: string, token: number, attempt: number): void {
    this.detailDocumentBindingService.probeDetailDocument(url, token, attempt);
  }

  private async detailNetworkReply(job: PinmonyNetworkJob): Promise<PinmonyNetworkReply> { return this.networkBridgeCoordinator.detailNetworkReply(job); }

  private cancelNativeNetwork(id: string): void { return this.networkBridgeCoordinator.cancelNativeNetwork(id); }

  private resetAuthenticatedContent(): void { this.profileSearchReads.close(); this.inboxMenuNative.pause();this.boardInvitationNative.pause(); this.profileBoardOrigins.clear(); this.followingBoardReturn = undefined; this.boardNativeReads.reset(); this.profileNativeReads.reset(); this.inboxUpdatesNativeReads.reset(); this.searchNativeReads.reset(); this.searchDiscoveryNativeReads.reset(); return this.sessionCoordinator.resetAuthenticatedContent(); }

  private updateAuthState(value: string): void {
    if(this.nativeLoginEnabled && !this.loginHostMounted)return;
    this.sessionCoordinator.updateAuthState(value);
    if(!this.nativeLoginEnabled)this.sessionVerification?.observeWebEvidence(value);
  }

  private syncAuthentication(): void {
    if(this.nativeLoginEnabled){
      if(this.loginHostMounted){this.runSessionScript('window.PinmonyAuthSync && window.PinmonyAuthSync(' + this.authEpoch.toString() + ')').catch(() => {});}
      if(this.authStatus === 'checking' && (!this.loginHostMounted || !!this.nativeLoginEvidenceKey))this.startNativeVerification();
      return;
    }
    return this.sessionCoordinator.syncAuthentication();
  }

  private retryLogin(): void {
    if(this.nativeLoginEnabled){this.nativeVerificationPending = false;this.startNativeVerification();return;}
    return this.sessionCoordinator.retryLogin();
  }

  private updateShareSheet(value: string): void {
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED)return;
    const session: number = this.pinStore.shareSession;
    const kind: string = this.activeSheetKind;
    this.sharePanelsController.updateShareSheet(value);
    if (this.activeSheetKind === 'share' && !this.businessSuspended) {
      const key: string = this.pinStore.shareSession.toString();
      if (session !== this.pinStore.shareSession || kind !== 'share') this.pagePerformance.beginSecondary('share', key);
      if (!this.pinStore.shareLoading && !this.pinStore.shareError &&
          !['正在加载联系人…', '正在处理…'].some((source: string): boolean => PinmonyI18n.isText(this.pinStore.shareFeedback, source)))
        this.pagePerformance.markSecondary('share', key, 'content-ready');
    }
  }

  private dismissShareSheet(): void { try {
    PinmonyRuntimeLog.info('AsyncAction: stage=share-close');
    this.sharePanelsController.pause();
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED)this.shareNativeFlow.close();
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
      if(PIN_NATIVE_PIN_MENUS_ENABLED)return;
      this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.homeMenuClose(' + session + ')')
        .catch(() => PinmonyRuntimeLog.warn('Pinmony: home menu close unavailable'));
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
    if(!PIN_NATIVE_SHARE_PUBLISH_ENABLED)this.runSessionScript('window.PinmonyNativeShareClose && window.PinmonyNativeShareClose(' +
      session.toString() + ')').catch(() => {
      PinmonyRuntimeLog.warn('Pinmony: could not close the web share panel');
    });
   } catch (_) { PinmonyRuntimeLog.warn('AsyncAction: share-close unavailable'); }
   finally { this.rootContextCoordinator.notify(); } }

  private scheduleShareWebOpen(): void {
    return this.sharePanelsController.scheduleShareWebOpen();
  }

  private pinIdentity(value: string): string { return PinmonyRouteParser.pinIdentity(value); }

  private externalSourceUrl(value: string): string { return PinmonyRouteParser.externalSourceUrl(value); }

  private isCurrentMorePin(pin: string): boolean {
    const identity: string = this.pinIdentity(pin);
    return !!identity && (identity === this.pinIdentity(this.currentPinUrl()) ||
      this.inboxStore.inboxFlow?.screen === 'chat' && this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl() &&
      identity === this.pinIdentity(this.homeStore.homeMenuPin) &&
      this.inboxStore.inboxFlow.messages.some((message): boolean => this.pinIdentity(message.pinUrl || '') === identity) ||
      this.isCurrentBoardMenuPin(pin, this.homeStore.homeMenuPage) ||
      this.isCurrentSearchMenuPin(pin, this.homeStore.homeMenuPage) ||
      PIN_NATIVE_PIN_MENUS_ENABLED && this.profileStore.profile?.profileUrl === this.currentProfileUrl() && identity === this.pinIdentity(this.homeStore.homeMenuPin) && this.profileStore.profile.createdPins.concat(this.profileStore.profile.unorganizedPins || []).some((p: PinmonyCreatedPin): boolean => this.pinIdentity(p.targetUrl || '') === identity) ||
      !!this.homeStore.home && this.activeTab === 0 && this.homeStore.home.pageKey === this.currentHomePageKey() &&
      identity === this.pinIdentity(this.homeStore.homeMenuPin));
  }

  private closeMoreWebPanel(session: number, pin: string): void {
    PinmonyRuntimeLog.info('AsyncAction: stage=more-close');
    try { this.runSessionScript('window.PinmonyNativeMoreClose && window.PinmonyNativeMoreClose(' +
      session.toString() + ',' + JSON.stringify(pin) + ')').catch(() => {
      PinmonyRuntimeLog.warn('Pinmony: could not close the web Pin menu');
    }); } catch (_) { PinmonyRuntimeLog.warn('AsyncAction: more-close unavailable'); }
  }

  private suspendMoreForShare(): void {
    if (this.activeSheetKind !== 'more' || !this.pinStore.moreSession) return;
    this.pinStore.ignoredMoreSession = this.pinStore.moreSession;
    this.pinStore.moreOptions = [];
    this.pinStore.moreError = '';
    this.pinStore.moreLoading = false;
  }

  private updateMoreSheet(value: string): void {
    return this.sharePanelsController.updateMoreSheet(value);
  }

  private dismissMoreSheet(): void { try {
    this.sharePanelsController.pause();
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
    if(PIN_NATIVE_PIN_MENUS_ENABLED)return;
    if (this.pinStore.moreApiMode) {
      this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.detailMoreClose(' +
        session.toString() + ',' + JSON.stringify(pin) + ')').catch(() => {});
    } else this.closeMoreWebPanel(session, pin);
   } finally { this.rootContextCoordinator.notify(); } }

  private async openApiDetailMore(): Promise<void> {
    await this.sharePanelsController.openApiDetailMore();
  }

  private async performMoreAction(id: string): Promise<void> {
    await this.sharePanelsController.performMoreAction(id);
  }

  private async refreshMoreSheet(): Promise<void> {
    await this.sharePanelsController.refreshMoreSheet();
  }

  private async performShareAction(id: string): Promise<void> {
    await this.sharePanelsController.performShareAction(id);
  }

  private async searchShareContacts(value: string): Promise<void> {
    await this.sharePanelsController.searchShareContacts(value);
  }

  private async refreshShareSheet(): Promise<void> {
    await this.sharePanelsController.refreshShareSheet();
  }

  private sharePlatformName(label: string): string {
    const chinese: RegExpMatchArray | null = label.match(/^通过\s*(.+?)\s*分享$/);
    const english: RegExpMatchArray | null = label.match(/^Share\s+(?:via|through|on)\s+(.+)$/i);
    const name: string = chinese ? chinese[1].trim() : english ? english[1].trim() : label.trim();
    if (/^(?:Facebook\s+)?Messenger$/i.test(name)) return 'Messenger';
    if (/^(?:消息|信息|短信|Message|Messages|SMS)$/i.test(name)) return this.uiText("pm_sms_81a4ceb7");
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

  private inboxUrlFromAddress(address: string): string { return PinmonyRouteParser.inboxUrlFromAddress(address); }

  private currentInboxUrl(): string {
    if((PIN_NATIVE_INBOX_MESSAGES_ENABLED || PIN_NATIVE_INBOX_UPDATES_ENABLED && this.inboxUpdatesNativeReads.selected()) && this.authStatus === 'authenticated') {
      const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
      const page: string = this.inboxUrlFromAddress(this.rootTabAddresses.get(2) || '');
      if(session.authenticated)return page.startsWith(session.origin + '/') ? page : session.origin + '/inbox/';
      if(page)return page;
    }
    const nativeAddress: string = this.nativeRootPageAddress(2);
    if (nativeAddress) return this.inboxUrlFromAddress(nativeAddress);
    try {
      return this.inboxUrlFromAddress(this.sessionDocumentUrl());
    } catch (error) {
      return '';
    }
  }

  private clearInbox(): void { this.inboxReadController.clear(); }
  private restoreInbox(address: string): boolean { return this.inboxReadController.restore(address); }
  private expectInbox(): void { this.inboxReadController.expect(); }
  private updateInbox(value: string): void { try {
    const before: PinmonyInboxFlowSnapshot | undefined = this.inboxStore.inboxFlow;
    this.inboxReadController.update(value);
    const flow: PinmonyInboxFlowSnapshot | undefined = this.inboxStore.inboxFlow;
    if (flow && flow !== before && flow.screen === 'chat' && !this.businessSuspended) {
      const key: string = flow.session + ':' + (flow.conversationId || '');
      if (!before || before.screen !== 'chat' || before.session !== flow.session || before.conversationId !== flow.conversationId)
        this.pagePerformance.beginSecondary('chat', key);
      if (!flow.loading && !flow.error) this.pagePerformance.markSecondary('chat', key, 'content-ready');
    }
   } finally { this.rootContextCoordinator.notify(); } }
  private searchUrlFromAddress(address: string): string { return PinmonyRouteParser.searchUrlFromAddress(address); }

  private currentSearchPageKey(): string {
    if (PIN_NATIVE_SEARCH_READS_ENABLED && this.authStatus === 'authenticated') {
      const target: string = this.searchUrlFromAddress(this.rootTabAddresses.get(1) || '');if(target)return target;
      if(this.nativeRootOnly && this.activeTab === 1){const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();if(session.authenticated)return session.origin + '/search/';}
    }
    const nativeAddress: string = this.nativeRootPageAddress(1);
    if (nativeAddress) return this.searchUrlFromAddress(nativeAddress);
    try {
      return this.searchUrlFromAddress(this.sessionDocumentUrl());
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
    if(PIN_NATIVE_SEARCH_READS_ENABLED && this.authStatus === 'authenticated' && this.activeTab === 1 &&
      !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.boardStore.boardDetail && !this.boardStore.pendingBoardUrl &&
      this.profileStore.origins.length === 0 && !this.profileSettingsVisible && !this.profileStore.panel && !this.inboxStore.inboxFlow &&
      !!this.currentSearchPageKey() && !this.loadFailed)return true;
    const currentPage: string = this.searchUrlFromAddress(this.nativeDisplayAddress());
    const pendingPage: string = this.pendingSearchPageKey();
    const switchingToSearch: boolean = this.activeTab === 1 &&
      (this.pendingWebTab === 1 || this.retainedRootTabPending === 1);
    return this.activeTab === 1 && !!(currentPage || pendingPage) &&
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
    PinmonyRuntimeLog.info('RootTabTrace: guard-cleared targetTab=' + this.rootTabGuardTarget.toString() +
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
    mode: HdsAnimationMode = HdsAnimationMode.SCROLL_ANIMATION): void { return this.bottomBarCoordinator.setBottomBarHidden(hidden, mode); }

  private onBottomBarScrollSettingChanged(): void { return this.bottomBarCoordinator.onBottomBarScrollSettingChanged(); }

  private updateInboxScrollAvailability(scrollable: boolean): void { return this.bottomBarCoordinator.updateInboxScrollAvailability(scrollable); }

  private handleRootContentScroll(offset: number, state: ScrollState): void { return this.bottomBarCoordinator.handleRootContentScroll(offset, state); }

  private syncBottomBarForPageDepth(): void { return this.bottomBarCoordinator.syncBottomBarForPageDepth(); }

  private syncFloatingTabsMotion(): void { return this.bottomBarCoordinator.syncFloatingTabsMotion(); }

  private publishPageVisible(): boolean {
    const flow = this.profileStore.publishFlow;
    if (!flow) return false;
    // Keep the originating page mounted while the system picker supplies photos.
    return flow.kind !== 'photo' || !this.profileStore.publishPicking &&
      (flow.phase !== 'photo' || flow.pins.length > 0 || !!flow.error);
  }

  private nativeRootTabsVisible(): boolean {
    if (this.profileStore.searchVisible) return false;
    if (this.publishPageVisible()) return false;
    if (this.profileStore.origins.length > 0 || this.profileSettingsVisible || this.profileStore.panel) return false;
    if (this.inboxStore.inboxFlow || this.inboxStore.listSection) return false;
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
    return (this.nativeSearchPageVisible() || this.shouldKeepSearchPageMounted() || !!searchPage) && !this.pinStore.detail && !this.pinStore.detailWebFlow &&
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

  private searchPlaceholder(): PinmonySearchSnapshot {
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
    if (/[?&]q=[^&#]+/.test(this.currentSearchPageKey()) && !this.searchStore.searchInputFocused &&
      this.searchStore.searchOpenHistory) {
      this.searchStore.searchOpenHistory();
      return;
    }
    if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    const pageKey: string = this.currentSearchPageKey();
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
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
    this.clearRootTabGuard('search-results-back');
    this.rootContentInteracted = true;
    this.pendingWebTab = -1;
    this.retainedRootTabPending = -1;
    this.rootTabAddresses.set(1, target);
    this.nativeBackTarget = target;
    const restoredLanding: boolean = this.restoreRetainedSearch(target);
    if (!restoredLanding) {
      this.searchStore.search = { kind: 'loading', session: 0, pageKey: target, query: '', placeholder: '',
        selectedCategory: '', categories: [], suggestions: [], heroes: [], ideaSections: [], results: [] };
      this.searchStore.searchLoading = true;
    } else if (this.searchStore.search?.query.trim()) {
      // Landing suggestions belong to an old editing intent, not the return destination.
      const landing: PinmonySearchSnapshot = this.searchStore.search;
      landing.query = ''; landing.suggestions = []; landing.results = [];
      this.searchStore.search = landing;
    }
    PinmonyRuntimeLog.info('SearchReturn: landing-prepared cache=' + (restoredLanding ? 'hit' : 'miss') + ' actionsReady=false');
    if (PIN_NATIVE_SEARCH_READS_ENABLED && this.searchNativeReads.eligible()) { this.searchNativeReads.pause(); this.commitNativeSearchReturn(target); return; }
    const token: number = ++this.pageBackToken;
    try {
      this.loadSessionDocument(target);
      this.coordinatorTasks.timeout(() => { if (token === this.pageBackToken) this.pageHistory.cancelBack(); }, 2500);
    } catch (error) {
      this.pageHistory.cancelBack();
      this.showMessage(PinmonyI18n.message("pm_unable_to_return_to_search_please_retry_3ef58654"));
    }
  }

  private commitNativeSearchReturn(target: string): void {
    this.boardNativeReads.pause(); this.returnCoordinator.cancel();
    this.tabRequestToken++; this.pageBackToken++;
    this.nativeRootOnly = true; this.nativeBackTarget = ''; this.navigationAddress = target;
    this.rootTabAddresses.set(1, target); this.activeTab = 1; this.currentWebTab = -1;
    this.pendingWebTab = -1; this.retainedRootTabPending = -1;
    this.boardStore.boardDetail = undefined; this.boardStore.pendingBoardUrl = '';
    this.boardStore.presentationPage = ''; this.boardStore.presentationOnly = false;
    this.boardStore.boardReturnUrl = ''; this.boardStore.boardReturnPage = '';
    this.clearRootTabGuard('native-search-return'); this.pageHistory.cancelBack();
    this.pageHistory.visit(target, 'load'); this.showNativeTabs = true; this.loadFailed = false;
    // Root selection owns the guard and nativeRootOnly; clearing it here would expose the hidden document again.
    this.selectNativeRootTab(1);
    this.syncFloatingTabsMotion();
    this.searchDiscoveryNativeReads.demand(); this.searchNativeReads.demand();
    PinmonyRuntimeLog.info('SearchReturn: committed mounted=' + this.shouldKeepSearchRootMounted().toString() + ' visible=' + this.nativeSearchPageVisible().toString() + ' loading=' + this.searchStore.searchLoading.toString());
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

  private dismissSearchFilters(): void { try {
    return this.searchController.dismissSearchFilters();
   } finally { this.rootContextCoordinator.notify(); } }

  private expectSearch(): void {
    return this.searchController.expectSearch();
  }

  private updateSearch(value: string): void { try {
    if (this.nativeRootOnly && !this.rootContentInteracted) return;
    if (this.nativeBackTarget) {
      try {
        if (this.pageHistory.key(this.sessionDocumentUrl()) !== this.pageHistory.key(this.nativeBackTarget)) return;
      } catch (_) { return; }
    }
    this.searchController.updateSearch(value);
    this.markRootPerformance(1);
   } finally { this.rootContextCoordinator.notify(); } }

  private async updateSearchQuery(value: string, refreshSuggestions: boolean = false): Promise<void> {
    return this.searchController.updateSearchQuery(value, refreshSuggestions);
  }

  private async submitSearch(value: string): Promise<void> {
    return this.searchController.submitSearch(value);
  }

  private openDetailTagSearch(query: string, pin: string): void {
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    if (this.authStatus !== 'authenticated' || !detail || detail.pinUrl !== pin ||
        this.pinStore.detailPin !== pin || this.activeSheetKind) return;
    const target: string = descriptionTagSearchUrl(pin, detail.description, query);
    if (!target) return;
    this.pinStore.detailCache.put(this.pinIdentity(pin), detail, this.pinStore.detailScrollOffset);
    this.pageHistory.visit(pin, 'load');
    this.clearDetail();
    this.nativeRootOnly = true;
    this.nativeBackTarget = '';
    this.activeTab = 1;
    this.tabsController.changeIndex(1);
    if(PIN_NATIVE_SEARCH_READS_ENABLED){this.searchNativeReads.navigate(target);return;}
    this.prepareSearchNavigation(target);
    try { this.loadSessionDocument(target); }
    catch (_) {
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = PinmonyI18n.message("pm_unable_to_search_this_tag_please_retry_2b12d7c6");
    }
  }

  private openNativeSearchResult(target: string,source: string): void {
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if(!search || search.pageKey !== source || this.authStatus !== 'authenticated' || this.activeTab !== 1 || this.businessSuspended || this.activeSheetKind)return;
    if(!search.results.some((p): boolean => p.targetUrl === target && p.enabled) && !search.quiz?.cards.some((p): boolean => p.targetUrl === target))return;
    if(!target.startsWith(this.nativeBusinessSessionContext().origin + '/'))return;
    const pin: string = this.extractPinUrl(target),board: string = this.boardUrlFromAddress(target),profile: string = this.profileUrlFromAddress(target);
    if(pin){this.beginDetailOpening(pin,source);return;}
    if(profile){this.openUserProfile(profile);return;}
    if(!board)return;
    this.searchStore.searchCache.put(search,this.searchStore.searchScrollOffset);this.pageHistory.visit(source,'load');
    this.boardStore.rootTab = 1;this.boardStore.boardReturnUrl = source;this.boardStore.boardReturnPage = board;
    this.boardStore.pendingBoardSource = source;this.boardStore.pendingBoardUrl = board;this.boardStore.presentationPage = board;this.boardStore.presentationOnly = false;
    this.boardStore.boardDetail = {kind:'state',session:0,pageKey:board,boardId:'',title:'',pinCount:'',ownerName:'',ownerAvatar:'',loading:true,loadingMore:false,ready:false,error:'',hasMore:false,pins:[]};
    this.nativeRootOnly = false;this.nativeBackTarget = board;this.navigationAddress = board;this.pageHistory.visit(board,'push');this.boardNativeReads.demand();this.syncFloatingTabsMotion();
  }

  private async performSearchAction(id: string, kind: string): Promise<void> {
    if (kind === 'hero') {
      const search = this.searchStore.search;
      const hero = search?.heroes.find((item): boolean => item.id === id && item.enabled);
      const target: string = this.boardUrlFromAddress(hero?.targetUrl || '');
      if (!search || !target || !(PIN_NATIVE_BOARD_READS_ENABLED || this.searchDiscoveryNativeReads.owned() && !search.query || await this.ensureRootActionContext(1)) || this.searchStore.search?.pageKey !== search.pageKey) return;
      this.searchStore.searchCache.put(search, this.searchStore.searchScrollOffset);
      this.boardStore.boardReturnUrl = search.pageKey; this.boardStore.boardReturnPage = target;
      this.boardStore.discoveryBoardPage = target;
      this.boardStore.rootTab = 1;
      this.boardStore.pendingBoardSource = search.pageKey; this.boardStore.pendingBoardUrl = target;
      this.nativeRootOnly = false;
      this.boardStore.presentationPage = target;
      this.boardStore.presentationOnly = false;
      this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: '', title: '',
        pinCount: '', ownerName: '', ownerAvatar: '', loading: true, loadingMore: false,
        ready: false, error: '', hasMore: false, pins: [] };
      this.syncFloatingTabsMotion();
      this.clearRootTabGuard('search-hero');
      if(PIN_NATIVE_BOARD_READS_ENABLED){this.nativeBackTarget = target;this.navigationAddress = target;this.pageHistory.visit(target,'push');this.boardNativeReads.demand();return;}
      try { this.loadSessionDocument(target); }
      catch (_) {
        this.boardStore.pendingBoardSource = ''; this.boardStore.pendingBoardUrl = '';
        this.boardStore.boardReturnPage = '';
        this.showMessage(PinmonyI18n.message("pm_unable_to_open_board_please_retry_846bb29a"));
      }
      return;
    }
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
    if (!(kind === 'inbox' && (this.inboxUpdatesNativeReads.eligible() || this.inboxMessagesNativeReads.selected()) || kind === 'search' && (this.searchDiscoveryNativeReads.eligible() || this.searchNativeReads.eligible())) && this.nativeRootOnly && this.prepareRootPageRead(kind === 'search' ? 1 : 2)) return;
    const page: string = kind === 'search' ? this.currentSearchPageKey() : this.currentInboxUrl();
    if (!page) return;
    this.rootPullKind = kind;
    const token: number = ++this.rootPullToken;
    this.coordinatorTasks.timeout(() => {
      if (token !== this.rootPullToken || this.rootPullKind !== kind) return;
      this.finishRootPull(kind);
      const current: string = kind === 'search' ? this.currentSearchPageKey() : this.currentInboxUrl();
      if (current !== page) return;
      if (kind === 'search') { this.searchStore.searchLoading = false; this.searchStore.searchError = PinmonyI18n.message("pm_refresh_timed_out_please_retry_371c624f"); }
      else { this.inboxStore.inboxLoading = false; this.inboxStore.inboxError = PinmonyI18n.message("pm_refresh_timed_out_please_retry_371c624f"); }
    }, 20000);
    if (kind === 'search') await this.refreshSearch();
    else await this.retryInbox();
    if (token !== this.rootPullToken) return;
    if (kind === 'search' ? !!this.searchStore.searchError : !!this.inboxStore.inboxError) this.finishRootPull(kind);
  }

  private async refreshSearch(): Promise<void> {
    return this.searchController.refreshSearch();
  }

  private inboxPlaceholder(): PinmonyInboxSnapshot {
    return {
      kind: 'state', session: 0, pageUrl: '', section: 'updates',
      updateLabel: this.uiText("pm_updates_3055a035"), inboxLabel: this.uiText("pm_inbox_63a5e7b7"), emptyTitle: '', emptyDescription: '',
      homeLabel: '', homeId: '', composeLabel: '', composeId: '', contactsLabel: '',
      items: [], contacts: []
    };
  }

  private async selectInboxSection(section: string): Promise<void> {
    this.traceAction('inbox.section', section); await this.inboxReadController.selectSection(section);
  }
  private async performInboxAction(id: string): Promise<void> {
    this.traceAction('inbox.action', id); await this.inboxActionsController.open(id);
  }
  private async inboxFlowAction(action: string, value: string = ''): Promise<void> {
    await this.inboxActionsController.action(action, value);
    if (PIN_NATIVE_INBOX_UPDATES_ENABLED && action === 'back' && !this.inboxStore.inboxFlow) this.inboxUpdatesNativeReads.demand();
  }

  private async loadMoreInbox(): Promise<void> { await this.inboxReadController.loadMore(); }
  private async retryInbox(): Promise<void> { await this.inboxReadController.refresh(); }
  private async retryInboxContacts(): Promise<void> { await this.inboxReadController.refreshContacts(); }
  private nativeSnapshotPageKey(index: number): string {
    if (index === 0) {
      const snapshot: PinmonyHomeSnapshot | undefined = this.homeStore.home || this.homeStore.cachedHome;
      return (this.homeStore.homeActionsReady || this.homeStore.homeNativeReadsReady) && snapshot && this.isHomeRootAddress(snapshot.pageKey) &&
        (snapshot.kind === 'state' || snapshot.pins.length > 0) ? snapshot.pageKey : '';
    }
    if (index === 1) {
      const snapshot: PinmonySearchSnapshot | undefined = this.searchStore.search || this.searchStore.retainedSearch;
      return this.searchStore.searchActionsReady && snapshot ? this.searchUrlFromAddress(snapshot.pageKey) : '';
    }
    if (index === 2) {
      const snapshot: PinmonyInboxSnapshot | undefined = this.inboxStore.inbox;
      return this.inboxStore.inboxActionsReady && snapshot ? this.inboxUrlFromAddress(snapshot.pageUrl) : '';
    }
    if (index === 3) {
      const snapshot: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
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
      if (this.pageHistory.key(address) !== this.pageHistory.key(this.sessionDocumentUrl())) return '';
    } catch (_) { return ''; }
    if (index === 0) return this.isHomeRootAddress(address) ? address : '';
    if (index === 1) return this.searchUrlFromAddress(address);
    if (index === 2) return this.inboxUrlFromAddress(address);
    if (index === 3) return this.profileUrlFromAddress(address);
    return '';
  }

  private rootPresentationAddress(index: number): string {
    const address: string = this.navigationAddress || this.authenticatedProfileUrl;
    const origin: string = address.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/)?.[0] || PINTEREST_URL.slice(0, -1);
    return this.rootTabAddresses.get(index) ||
      (index === 0 ? this.homeStore.home?.pageKey || origin + '/' :
        index === 1 ? this.searchStore.search?.pageKey || origin + '/search/' :
          index === 2 ? this.inboxStore.inbox?.pageUrl || origin + '/inbox/' :
            this.authenticatedProfileUrl);
  }

  private selectNativeRootTab(index: number): void { return this.navigationCoordinator.selectNativeRootTab(index); }

  private rootPageHasReadState(index: number): boolean {
    if (index === 0) return !!this.homeStore.homeForPresentation(
      this.homePresentationPageKey() || this.retainedHomeRootPageKey()) ||
      this.homeStore.homeLoading || !!this.homeStore.homeError;
    if (index === 1) return !!this.searchStore.search || this.searchStore.searchLoading || !!this.searchStore.searchError;
    if (index === 2) return !!this.inboxStore.inbox || this.inboxStore.inboxLoading || !!this.inboxStore.inboxError;
    // A retained snapshot is a display state, never proof of operation readiness.
    return !!this.profileStore.profile || this.profileStore.profileLoading || !!this.profileStore.profileError;
  }

  private rootStatusError(index: number): string {
    return index === 0 ? this.homeStore.homeError : index === 1 ? this.searchStore.searchError :
      index === 2 ? this.inboxStore.inboxError : this.profileStore.profileError;
  }

  private rootStatusLoading(index: number): boolean {
    // An empty root waits for its first read, including document/bridge preparation.
    return (index === 0 && PIN_NATIVE_HOME_READS_ENABLED || !this.loadFailed) && !this.rootStatusError(index);
  }

  private failRootPreparation(index: number, message: string): void {
    this.rootContextCoordinator.failDocument(this.rootReadAddress);
    this.pendingWebTab = -1;
    this.rootReadToken = -1;
    if (index === 0) { this.homeStore.homeLoading = false; this.homeStore.homeError = message; }
    else if (index === 1) { this.searchStore.searchLoading = false; this.searchStore.searchError = message; }
    else if (index === 2) { this.inboxStore.inboxLoading = false; this.inboxStore.inboxError = message; }
    else { this.profileStore.profileLoading = false; this.profileStore.profileError = message; }
  }

  // A visible page owns its first read; the bottom-bar handler only changes presentation.
  private markReturnedHome(index: number): void {
    if (index !== 0) return;
    const token: number = this.tabRequestToken;
    const generation: number = this.nativeBusinessSessionContext().generation;
    this.coordinatorTasks.timeout((): void => {
      if (token !== this.tabRequestToken || generation !== this.nativeBusinessSessionContext().generation ||
          this.authStatus !== 'authenticated' || this.businessSuspended || this.activeTab !== 0 || !this.nativeRootTabsVisible()) return;
      const page: string = this.homePresentationPageKey() || this.retainedHomeRootPageKey();
      const snapshot: PinmonyHomeSnapshot | undefined = this.homeStore.homeForPresentation(page);
      if (!snapshot || snapshot.kind !== 'state' || snapshot.sourceError || this.homeStore.homeError) return;
      if (this.pagePerformance.restoreHome()) this.detailReturnJourney?.mark('return.home.cache.presented');
    }, 16);
  }

  private onRootPageVisible(index: number, visible: boolean): void {
    if (!visible) { if(index === 3 && PIN_NATIVE_PROFILE_READS_ENABLED) this.profileNativeReads.pause(); if(index === 2 && PIN_NATIVE_INBOX_UPDATES_ENABLED) this.inboxUpdatesNativeReads.pause(); if(index === 2 && PIN_NATIVE_INBOX_MESSAGES_ENABLED && !this.inboxStore.inboxFlow)this.inboxMessagesNativeReads.pause(); if (index === 1 && PIN_NATIVE_SEARCH_DISCOVERY_ENABLED) { this.searchDiscoveryNativeReads.pause(); this.searchNativeReads.pause(); } return; }
    if (this.activeTab === index && this.nativeRootTabsVisible()) {
      this.pagePerformance.mark(index, 'visible');
      const snapshot: boolean = index === 0 ? !!this.homeStore.home || !!this.homeStore.cachedHome :
        index === 1 ? !!this.searchStore.search : index === 2 ? !!this.inboxStore.inbox : !!this.profileStore.profile;
      if (snapshot) this.pagePerformance.mark(index, 'cache-visible');
      this.markRootPerformance(index);
    }
    const token: number = this.tabRequestToken;
    if(index === 2 && PIN_NATIVE_INBOX_UPDATES_ENABLED)this.coordinatorTasks.timeout((): void => {if(this.activeTab === 2 && token === this.tabRequestToken && this.nativeRootTabsVisible() && this.inboxStore.invitationReadPage !== this.currentInboxUrl())this.readBoardInvitations();},100);
    if(index === 3 && this.usesNativeProfileReads()) {this.coordinatorTasks.timeout((): void => {if(this.activeTab === 3 && token === this.tabRequestToken && this.nativeRootTabsVisible())this.profileNativeReads.demand();},80); return;}
    if(index === 2 && this.inboxMessagesNativeReads.selected()){this.coordinatorTasks.timeout((): void => {if(this.activeTab === 2 && token === this.tabRequestToken && this.nativeRootTabsVisible())this.inboxMessagesNativeReads.demand();},80); return;}
    if(index === 2 && PIN_NATIVE_INBOX_UPDATES_ENABLED && this.inboxUpdatesNativeReads.eligible()){ this.coordinatorTasks.timeout((): void => { if(this.activeTab === 2 && token === this.tabRequestToken && this.nativeRootTabsVisible())this.inboxUpdatesNativeReads.demand(); },80); return; }
    if (index === 1 && PIN_NATIVE_SEARCH_READS_ENABLED && this.searchNativeReads.eligible()) { this.coordinatorTasks.timeout((): void => { if(this.activeTab === 1 && token === this.tabRequestToken && this.nativeRootTabsVisible()) { this.searchDiscoveryNativeReads.demand(); this.searchNativeReads.demand(); } },80); return; }
    if (index === 1 && PIN_NATIVE_SEARCH_DISCOVERY_ENABLED && this.searchDiscoveryNativeReads.eligible()) {
      this.coordinatorTasks.timeout((): void => { if (this.activeTab === 1 && token === this.tabRequestToken && this.nativeRootTabsVisible()) this.searchDiscoveryNativeReads.demand(); }, 80);
      return;
    }
    if (index === 0 && PIN_NATIVE_HOME_READS_ENABLED) {
      this.coordinatorTasks.timeout((): void => { if (this.activeTab === 0 && token === this.tabRequestToken && this.nativeRootTabsVisible()) this.homeNativeReads.demand(); }, 80);
      return;
    }
    this.coordinatorTasks.timeout(() => {
      if (this.authStatus !== 'authenticated' || this.activeTab !== index || token !== this.tabRequestToken ||
          !this.nativeRootOnly || !this.nativeRootTabsVisible() || this.pendingWebTab !== -1 || this.loadFailed ||
          this.rootPageHasReadState(index)) return;
      PinmonyRuntimeLog.info('RootTabTrace: initial-page-read targetTab=' + index.toString() + ' reason=visible-empty');
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
    this.searchStore.search = this.searchController.searchPlaceholder(address);
    this.syncFloatingTabsMotion();
    this.searchStore.searchActionsReady = false;
    this.searchStore.searchInputReady = false;
    this.searchStore.searchLoading = true;
    this.searchStore.searchError = '';
    this.waitForWebTabConfirmation(1, this.tabRequestToken, this.rootReadStartedAt);
  }

  private rootReadInFlight(index: number, address: string): boolean { return this.rootContextCoordinator.rootReadInFlight(index, address); }

  private requestRootPage(index: number): void { if(index === 3 && this.usesNativeProfileReads()){this.profileNativeReads.refresh(); return;} if(index === 2 && this.inboxMessagesNativeReads.selected()){this.inboxMessagesNativeReads.refresh(); return;} if(index === 2 && this.inboxUpdatesNativeReads.eligible()){ this.inboxUpdatesNativeReads.refresh(); return; } if (index === 1 && this.searchNativeReads.eligible() && /[?&]q=/.test(this.currentSearchPageKey())) { this.searchNativeReads.refresh(); return; } if (index === 1 && this.searchDiscoveryNativeReads.eligible()) { this.searchDiscoveryNativeReads.refresh(); return; } if (index === 0 && PIN_NATIVE_HOME_READS_ENABLED) { this.homeNativeReads.refresh(); return; } return this.rootContextCoordinator.requestRootPage(index); }

  private prepareRootPageRead(index: number): boolean { return this.rootContextCoordinator.prepareRootPageRead(index); }

  private rootActionContextReady(index: number, requireData: boolean = true): boolean { return this.rootContextCoordinator.rootActionContextReady(index, requireData); }

  // Only explicit content intent may prepare a document. Never dispatch using a retained session.
  private async ensureRootActionContext(index: number, requireData: boolean = true, allowedSheet: string = '',
      isCurrent: () => boolean = (): boolean => true): Promise<boolean> { return this.rootContextCoordinator.ensureRootActionContext(index, requireData, allowedSheet, isCurrent); }

  private async prepareProfileInteraction(allowedSheet: string = '', isCurrent: () => boolean = (): boolean => true): Promise<boolean> {
    if (this.profileStore.origins.length > 0) return this.authStatus === 'authenticated' &&
      this.profileStore.profileActionsReady && this.profileStore.profile?.profileUrl === this.currentProfileUrl();
    if (PIN_NATIVE_PROFILE_READS_ENABLED) {
      if (!this.profileStore.profileNativeReadsReady) { await this.profileNativeReads.demand(); if (!this.profileStore.profileNativeReadsReady) return false; }
      const profile: string = this.profileStore.profile?.profileUrl || '';
      const generation: number = this.nativeBusinessSessionContext().generation;
      const token: number = this.tabRequestToken;
      const current = (): boolean => isCurrent() && this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 3 &&
        token === this.tabRequestToken && generation === this.nativeBusinessSessionContext().generation &&
        this.profileStore.profile?.profileUrl === profile && (!this.activeSheetKind || this.activeSheetKind === allowedSheet) &&
        !this.pinStore.detail && !this.pinStore.detailOpeningPin;
      if (!current() || !profile) return false;
      this.profileStore.profileActionsReady = false; this.profileStore.profileSessionReady = false;
      let preparedDocument: string = '';
      try {
        if (this.profileUrlFromAddress(this.sessionDocumentUrl()) !== profile) this.loadSessionDocument(profile);
        const deadline: number = Date.now() + 10000;
        while (current() && Date.now() < deadline) {
          if (this.profileUrlFromAddress(this.sessionDocumentUrl()) === profile) {
            const document: string = this.sessionDocumentUrl();
            if (preparedDocument !== document) {
              this.bindNativeNetwork();
              preparedDocument = document;
            }
            const install: string = this.profileNativeReads.installScript(); if (!install) return false;
            await this.runSessionScript(install + 'window.PinmonyProfileSync && window.PinmonyProfileSync();');
            if (current() && this.profileStore.profileActionsReady && this.profileStore.profileSessionReady &&
                this.profileStore.profile?.session === this.profileStore.profileSession) return true;
          }
          if (!await this.coordinatorTasks.wait(150)) return false;
        }
      } catch (_) { PinmonyRuntimeLog.warn('ProfilePrepareTrace: failed reason=script'); return false; }
      PinmonyRuntimeLog.info('ProfilePrepareTrace: stopped current=' + current().toString() + ' sessionReady=' + this.profileStore.profileSessionReady.toString() + ' actionsReady=' + this.profileStore.profileActionsReady.toString());
      return false;
    }
    return this.ensureRootActionContext(3, true, allowedSheet, isCurrent);
  }

  private profileDocumentMatches(url: string): boolean {
    let document: string = '';
    try { document = this.sessionDocumentUrl(); } catch (_) {}
    const profileUrl: string = this.profileUrlFromAddress(url);
    return !!profileUrl && (this.profileUrlFromAddress(document) === profileUrl ||
      this.profileUrlFromAddress(this.rootTabAddresses.get(3) || '') === profileUrl);
  }

  private async performSearchQuizAction(kind: string, id: string): Promise<void> {
    if(PIN_NATIVE_SEARCH_READS_ENABLED){await this.searchNativeReads.quizAction(kind,id);return;}
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
      PinmonyRuntimeLog.info('RootTabTrace: history-reuse unavailable');
    }
    return -1;
  }

  private clearRootTabCaches(clearPersistentCache: boolean = true): void {
    this.pagePerformance.cancel();
    this.controllerLifecycle().pause();
    this.boardInvitationController.reset();
    this.boardStore.collaboratorsToken++;
    this.boardStore.collaborators = undefined;
    this.singlePinMovePage = '';
    this.publishBoardReturn = '';
    this.retainedBoardContent = undefined;
    this.cancelledBoardPins.clear();
    this.detailReadCache.clear();
    this.homeCacheRestoreAttemptKey = '';
    this.homeStore.startupFeedCommitted = false;
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
    this.homeStore.diskCacheRestored = false;
    this.homeStore.diskCacheRestoredAt = 0;
    if (clearPersistentCache) {
      const filesRemoved: number = this.homeApiCache ? this.homeApiCache.clear() : -1;
      PinmonyRuntimeLog.info('HomeCache: clear scope=memory-and-disk filesRemoved=' + filesRemoved.toString());
      this.homeCacheAccountId = '';
      this.homeCacheIdentityEpoch = -1;
      this.clearOfflineHomeMarker();
    }
    this.searchStore.retainedSearch = undefined;
    this.searchStore.retainedSearchScrollOffset = 0;
  }

  private waitForWebTabConfirmation(index: number, token: number, requestedAt: number): void {
    this.coordinatorTasks.timeout(async () => {
      if (this.businessSuspended || this.tabRequestToken !== token || this.pendingWebTab !== index) return;
      if (this.loadFailed) {
        this.pendingWebTab = -1;
        return;
      }
      const now: number = Date.now();
      const pageEndGrace: boolean = this.webPageLoadFinishedAt > requestedAt &&
        now - this.webPageLoadFinishedAt < 1800;
      if (now - requestedAt >= 12000) {
        this.failRootPreparation(index, this.uiText("pm_page_preparation_timed_out_please_retry_33a2bee0"));
        PinmonyRuntimeLog.warn('RootTabTrace: preparation-timeout targetTab=' + index.toString());
        this.showMessage(PinmonyI18n.message("pm_page_preparation_timed_out_please_retry_33a2bee0")); return;
      }
      if (this.webPageLoading || now - requestedAt < 6500 || pageEndGrace) {
        this.waitForWebTabConfirmation(index, token, requestedAt);
        return;
      }
      await this.refreshWebNavigation();
      if (this.tabRequestToken !== token || this.pendingWebTab !== index) return;
      if (this.currentWebTab === index) {
        this.pendingWebTab = -1;
        PinmonyRuntimeLog.info('RootTabTrace: confirmed targetTab=' + index.toString() +
          ' elapsedMs=' + (Date.now() - requestedAt).toString());
        return;
      }
      if (index === 3 && !this.currentProfileUrl()) this.clearProfile();
      this.failRootPreparation(index, this.uiText("pm_page_data_not_ready_please_retry_cfdc4c01"));
      this.showMessage(PinmonyI18n.message("pm_page_data_not_ready_please_retry_cfdc4c01"));
    }, 500);
  }

  private async refreshWebNavigation(): Promise<void> {
    try {
      await this.runSessionScript(
        'window.PinmonyNavigationRefresh && window.PinmonyNavigationRefresh()');
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: navigation state refresh failed');
    }
  }

  private currentHomePageKey(): string {
    try {
      if (PIN_NATIVE_HOME_READS_ENABLED && this.authStatus === 'authenticated' && this.activeTab === 0)
        return this.homePresentationPageKey();
      if (this.nativeRootOnly) return this.homePageKeyFromAddress(this.sessionDocumentUrl());
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
      PinmonyRuntimeLog.warn('HomeCache: disk cache unavailable');
    }
  }

  private initializeOfflineHomeMarker(): void {
    this.initializeHomeApiCache();
    try {
      const raw: string = AppStorage.get<string>(PINWEB_HOME_OFFLINE_MARKER) || '';
      if (raw) {
        const marker: PinmonyOfflineHomeMarker | undefined = this.parseOfflineHomeMarker(raw);
        if (marker) {
          this.offlineHomeMarker = marker;
          PinmonyRuntimeLog.info('OfflineCache: marker loaded source=memory ageMs=' +
            Math.max(0, Date.now() - marker.savedAtMs).toString());
          return;
        }
        PinmonyRuntimeLog.warn('OfflineCache: marker rejected reason=invalid-shape source=memory');
        try { AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, ''); } catch (_) {}
      }
      if (!this.homeApiCache) return;
      const diskResult = this.homeApiCache.getWithMetadata<PinmonyOfflineHomeMarker>(
        PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY, PINWEB_HOME_OFFLINE_MARKER_TTL);
      PinmonyRuntimeLog.info('OfflineCache: marker lookup status=' + diskResult.status +
        ' ageMs=' + diskResult.ageMs.toString());
      if (!diskResult.value) return;
      const marker: PinmonyOfflineHomeMarker | undefined = this.parseOfflineHomeMarker(
        JSON.stringify(diskResult.value));
      if (!marker) {
        this.homeApiCache.remove(PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY);
        PinmonyRuntimeLog.warn('OfflineCache: marker rejected reason=invalid-shape source=disk');
        return;
      }
      this.offlineHomeMarker = marker;
      try { AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, JSON.stringify(marker)); } catch (_) {}
      PinmonyRuntimeLog.info('OfflineCache: marker loaded source=disk ageMs=' +
        Math.max(0, Date.now() - marker.savedAtMs).toString());
    } catch (_) {
      PinmonyRuntimeLog.warn('OfflineCache: marker read failed');
    }
  }

  private parseOfflineHomeMarker(raw: string): PinmonyOfflineHomeMarker | undefined {
    try {
      const marker: PinmonyOfflineHomeMarker = JSON.parse(raw) as PinmonyOfflineHomeMarker;
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
    const marker: PinmonyOfflineHomeMarker = { partitionId: partitionId, pageKey: pageKey, savedAtMs: Date.now() };
    this.offlineHomeMarker = marker;
    try {
      if (this.homeApiCache) {
        this.homeApiCache.put(PINWEB_HOME_OFFLINE_MARKER_CACHE_KEY, marker, PINWEB_HOME_OFFLINE_MARKER_TTL);
      }
      AppStorage.setOrCreate<string>(PINWEB_HOME_OFFLINE_MARKER, JSON.stringify(marker));
      PinmonyRuntimeLog.info('OfflineCache: marker saved source=' + (this.homeApiCache ? 'disk' : 'memory'));
    } catch (_) {
      PinmonyRuntimeLog.warn('OfflineCache: marker save failed');
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
      /^https:\/\/(?:(?:www|uk)\.)?pinterest\.com\/([a-zA-Z0-9_]+)\/?(?:[?#]|$)/i);
    return match ? hashCacheString(match[1].toLowerCase()) : '';
  }

  private tryRestoreAuthenticatedHome(accountId: string, pageKey: string): void {
    const reason: string = this.authStatus !== 'authenticated' ? 'session-unconfirmed' :
      !accountId ? 'identity-pending' : !pageKey || this.activeTab !== 0 ||
      this.pinStore.detail || this.pinStore.detailOpeningPin || this.boardStore.pendingBoardUrl ? 'not-home' :
      this.homeStore.startupFeedCommitted ? 'network-committed' : '';
    if (reason) {
      if (reason !== this.homeCacheRestoreSkipReason) {
        this.homeCacheRestoreSkipReason = reason;
        PinmonyRuntimeLog.info('HomeCache: restore skipped reason=' + reason);
      }
      return;
    }
    const attemptKey: string = accountId + ':' + pageKey;
    if (this.homeCacheRestoreAttemptKey === attemptKey) return;
    this.homeCacheRestoreAttemptKey = attemptKey;
    this.homeCacheRestoreSkipReason = '';
    PinmonyRuntimeLog.info('HomeCache: restore attempted trigger=authenticated-identity');
    this.restoreHomeDiskCache(accountId, pageKey, 'authenticated-identity');
  }

  private restoreHomeDiskCache(accountId: string, pageKey: string, trigger: string): boolean {
    this.initializeHomeApiCache();
    if (!this.homeApiCache || !accountId || !pageKey) return false;
    const snapshot: PinmonyHomeSnapshot | undefined = readHomeCache(this.homeApiCache, accountId, pageKey, trigger);
    if (!snapshot) return false;
    this.homeController.restoreCacheSnapshot(snapshot);
    return true;
  }

  private tryEnterOfflinePreview(failedUrl: string, reason: string = 'network-failure'): boolean {
    const marker: PinmonyOfflineHomeMarker | undefined = this.offlineHomeMarker;
    if (!marker || this.offlinePreviewMode || !this.isHomeRootAddress(failedUrl)) return false;
    if (this.offlineCacheLoading) return true;
    this.beginOfflineCacheRestore(failedUrl, reason);
    this.coordinatorTasks.timeout(() => {
      if (!this.offlineCacheLoading || this.offlinePreviewMode || this.offlineHomeMarker !== marker) return;
      const restored: boolean = this.restoreHomeDiskCache(marker.partitionId, marker.pageKey, 'offline-start');
      this.offlineCacheLoading = false;
      if (!restored) {
        PinmonyRuntimeLog.warn('OfflineCache: restore failed reason=cache-unavailable');
        if (this.homeStore.diskCacheRestoredAt === 0) this.clearOfflineHomeMarker();
        this.authStatus = 'error';
        this.loadFailed = true;
        this.failureDetails = PinmonyI18n.message("pm_recent_cache_unavailable_connect_and_retry_bf4baad7");
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
      PinmonyRuntimeLog.warn('OfflineCache: preview entered actionsReady=false');
    }, 0);
    return true;
  }

  private beginOfflineCacheRestore(failedUrl: string, reason: string): void {
    if (!this.offlineHomeMarker || this.offlinePreviewMode || !this.isHomeRootAddress(failedUrl)) return;
    this.offlineCacheLoading = true;
    PinmonyRuntimeLog.info('OfflineCache: restore started reason=' + reason);
  }

  private homeReadyToken: number = -1;
  private homePersistSignature: string = '';
  private homePersistAt: number = 0;

  private persistHomeDiskCache(snapshot: PinmonyHomeSnapshot): void {
    if (!this.homeApiCache || !this.homeCacheAccountId || this.authStatus !== 'authenticated' ||
        snapshot.pageKey !== (PIN_NATIVE_HOME_READS_ENABLED && this.homeStore.homeNativeReadsReady ? this.homeStore.home?.pageKey : this.currentHomePageKey())) return;
    const signature: string = JSON.stringify([this.homeCacheAccountId, snapshot.pageKey, snapshot.selectedTab,
      snapshot.tabs, snapshot.board, snapshot.pins, snapshot.endReached]);
    if (signature === this.homePersistSignature && Date.now() - this.homePersistAt < 60000) return;
    this.homePersistSignature = signature; this.homePersistAt = Date.now();
    writeHomeCache(this.homeApiCache, this.homeCacheAccountId, snapshot,
      (): void => this.saveOfflineHomeMarker(this.homeCacheAccountId, snapshot.pageKey));
  }

  private homePageKeyFromAddress(url: string): string {
    const match: RegExpMatchArray | null = url.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)(\/(?:ideas|today)(?:\/[^?#]*)?\/?|\/)(?=[?#]|$)/i);
    return match ? match[1] + match[2] : '';
  }

  private homePresentationPageKey(): string {
    if ((!this.offlinePreviewMode && this.authStatus !== 'authenticated') || this.activeTab !== 0 ||
        this.loadFailed && !this.offlinePreviewMode && !PIN_NATIVE_HOME_READS_ENABLED ||
        this.pinStore.detail || this.pinStore.detailOpeningPin || this.profileStore.origins.length > 0 ||
        this.profileSettingsVisible || this.profileStore.panel || this.inboxStore.inboxFlow ||
        this.boardStore.pendingBoardUrl) return '';
    if (this.offlinePreviewMode) return this.homeStore.home?.pageKey || this.offlineHomeMarker?.pageKey || '';
    if (PIN_NATIVE_HOME_READS_ENABLED) {
      const origin: string = this.nativeBusinessSessionContext().origin;
      const candidate: string = this.homeStore.home?.pageKey || (origin ? origin + '/' : this.rootTabAddresses.get(0) || PINTEREST_URL);
      return this.homePageKeyFromAddress(candidate);
    }
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
    const snapshot: PinmonyHomeSnapshot | undefined = this.homeStore.home || this.homeStore.cachedHome;
    if (snapshot && this.isHomeRootAddress(snapshot.pageKey)) return snapshot.pageKey;
    const retainedAddress: string = this.rootTabAddresses.get(0) || '';
    return this.isHomeRootAddress(retainedAddress) ? this.homePageKeyFromAddress(retainedAddress) : '';
  }

  private prepareHomeForPageBegin(url: string, retainedDocument: boolean = false): void {
    return this.homeController.prepareHomeForPageBegin(url, retainedDocument);
  }

  private clearHome(): void {
    return this.homeController.clearHome();
  }

  private homePlaceholder(): PinmonyHomeSnapshot {
    return { kind: 'loading', session: 0, pageKey: this.homePresentationPageKey(),
      selectedTab: '', tabs: [], pins: [] };
  }

  private expectHome(): void {
    return this.homeController.expectHome();
  }

  private updateHome(value: string): void { try {
    this.homeController.updateHome(value);
    this.markRootPerformance(0);
   } finally { this.rootContextCoordinator.notify(); } }

  private openHomeBoard(id: string): void {
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    const board = home?.board;
    if (!PIN_NATIVE_BOARD_READS_ENABLED || this.authStatus !== 'authenticated' || this.activeTab !== 0 ||
      this.businessSuspended || this.activeSheetKind || this.boardStore.pendingBoardUrl || this.homeStore.pendingHomeTab ||
      !home || home.pageKey !== this.homePresentationPageKey() || !board || board.id !== id ||
      !home.tabs.some((tab): boolean => tab.selected && tab.id === 'tab:' + id)) return;
    const target: string = this.boardUrlFromAddress(board.boardUrl || '');
    if (!target || !target.startsWith(this.nativeBusinessSessionContext().origin + '/')) return;
    const source: string = home.pageKey;
    this.homeNativeReads.pause(); this.returnCoordinator.cancel(); this.pageHistory.cancelBack(); this.pageBackToken++;
    this.boardStore.discoveryBoardPage = ''; this.boardStore.rootTab = 0;
    this.boardStore.boardReturnUrl = source; this.boardStore.boardReturnPage = target;
    this.boardStore.pendingBoardSource = source; this.boardStore.pendingBoardUrl = target;
    this.boardStore.presentationPage = target; this.boardStore.presentationOnly = false;
    this.boardStore.boardOpeningToken++;
    this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: id, title: board.name,
      pinCount: board.pinCount.toString(), ownerName: '', ownerAvatar: '', loading: true, loadingMore: false,
      ready: false, error: '', hasMore: false, pins: [] };
    this.nativeRootOnly = false; this.nativeBackTarget = target; this.navigationAddress = target;
    this.pageHistory.visit(source, 'load'); this.pageHistory.visit(target, 'push');
    this.boardNativeReads.demand(); this.syncFloatingTabsMotion();
  }

  private async selectHomeTab(id: string, restoring: boolean = false): Promise<void> {
    return this.homeController.selectHomeTab(id, restoring);
  }

  private async openHomePin(id: string): Promise<void> {
    return this.homeController.openHomePin(id);
  }

  private homeMenuReady(): boolean {
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    if(PIN_NATIVE_PIN_MENUS_ENABLED)return this.authStatus === 'authenticated' && !this.businessSuspended &&
      this.activeTab === 0 && !!home?.pins.length && home.pageKey === this.homePresentationPageKey() &&
      this.rootTabIndexFromAddress(home.pageKey) === 0 && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.activeSheetKind;
    return this.authStatus === 'authenticated' && this.activeTab === 0 && !!home && !!home.pins.length &&
      this.rootTabIndexFromAddress(home.pageKey) === 0 && !this.homeStore.homeLoading && !this.homeStore.homeRefreshing &&
      (!this.homeStore.pendingHomeTab || this.homeStore.retainingHomeFeed) &&
      (PIN_POST_API_ENABLED || this.homeStore.homeActionsReady);
  }

  private async openHomeMore(id: string): Promise<void> {
    this.traceAction('home.pin.more', id);
    if (this.rejectOfflineAction('home menu')) return;
    if (!PIN_POST_API_ENABLED || !PIN_NATIVE_PIN_MENUS_ENABLED && !await this.ensureRootActionContext(0)) return;
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    if (!home || !this.homeMenuReady() || !PIN_NATIVE_PIN_MENUS_ENABLED && this.homeStore.homeMoreLoadingId) return;
    const pin: PinmonyHomePin | undefined = home.pins.find((item: PinmonyHomePin): boolean => item.id === id);
    if (!pin) {
      this.showMessage(PinmonyI18n.message("pm_pin_unavailable_refresh_the_home_feed_and_retry_90e61e50"));
      return;
    }
    if (!PIN_POST_API_ENABLED) return;
    this.openCustomHomeMenu(pin.pinUrl, home.pageKey);
  }

  private cancelHomeDetailMore(): void { return this.photoMenuCoordinator.cancelHomeDetailMore(); }

  private isCurrentInboxMessagePin(url: string): boolean {
    return this.inboxStore.inboxFlow?.screen === 'chat' && this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl() &&
      this.inboxStore.inboxFlow.messages.some((message): boolean => message.pinUrl === url);
  }

  private openInboxBoard(messageId: string): void {
    const flow = this.inboxStore.inboxFlow;
    const nativeChat: boolean = this.inboxMessagesNativeReads.ownsFlow();
    let document: string = '';
    if(!nativeChat) {try { document = this.sessionDocumentUrl(); } catch (_) { return; }}
    if (!PIN_BOARD_API_ENABLED || this.authStatus !== 'authenticated' || this.businessSuspended || this.activeTab !== 2 ||
        this.activeSheetKind || this.boardStore.pendingBoardUrl || this.nativeBoardVisible() || this.pinStore.detail ||
        !flow || flow.screen !== 'chat' || flow.pageUrl !== this.currentInboxUrl() || flow.session !== this.inboxStore.inboxSession ||
        (!nativeChat && this.inboxUrlFromAddress(document) !== flow.pageUrl)) return;
    const message = flow.messages.find((item): boolean => item.id === messageId && !item.deleted);
    const card = message?.board;
    const target: string = this.boardUrlFromAddress(card?.url || '');
    if (!card || !/^\d+$/.test(card.id) || !target || target !== card.url || this.rejectOfflineAction('chat board')) return;
    this.traceAction('inbox.board.open');
    this.inboxStore.retainedChat = flow;
    this.inboxStore.chatReturnConversation = flow.conversationId || '';
    this.returnCoordinator.cancel(); this.pageHistory.cancelBack(); this.pageBackToken++;
    this.nativeBackTarget = ''; this.nativeRootOnly = false;
    const token: number = ++this.boardStore.boardOpeningToken;
    this.boardStore.rootTab = 2; this.boardStore.discoveryBoardPage = '';
    this.boardStore.boardReturnUrl = flow.pageUrl; this.boardStore.boardReturnPage = target;
    this.boardStore.pendingBoardSource = flow.pageUrl; this.boardStore.pendingBoardUrl = target;
    this.boardStore.presentationPage = target; this.boardStore.presentationOnly = false;
    this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: card.id, title: card.title || this.uiText("pm_board_bd3f17ee"),
      pinCount: card.pinCount === undefined ? '' : card.pinCount.toString(), ownerName: '', ownerAvatar: '',
      loading: true, loadingMore: false, ready: false, error: '', hasMore: false, pins: [] };
    this.pagePerformance.beginSecondary('board', target);
    this.clearRootTabGuard('chat-board'); this.syncFloatingTabsMotion();
    if(PIN_NATIVE_BOARD_READS_ENABLED){this.nativeBackTarget = target;this.navigationAddress = target;this.pageHistory.visit(target,'push');this.boardNativeReads.demand();return;}
    try { this.loadSessionDocument(target); }
    catch (_) {
      this.boardStore.pendingBoardUrl = ''; this.boardStore.pendingBoardSource = '';
      this.boardStore.boardReturnUrl = ''; this.boardStore.boardReturnPage = ''; this.boardStore.presentationPage = '';
      this.boardStore.boardDetail = undefined; this.inboxStore.retainedChat = undefined; this.inboxStore.chatReturnConversation = '';
      this.showMessage(PinmonyI18n.message("pm_unable_to_open_board_please_retry_846bb29a")); return;
    }
    this.coordinatorTasks.timeout(() => {
      const detail = this.boardStore.boardDetail;
      if (!detail || detail.pageKey !== target || detail.session !== 0 || detail.ready || this.boardStore.presentationOnly) return;
      const opening: boolean = token === this.boardStore.boardOpeningToken && this.boardStore.pendingBoardUrl === target;
      const awaiting: boolean = token + 1 === this.boardStore.boardOpeningToken && this.currentBoardUrl() === target;
      if (!opening && !awaiting) return;
      this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: card.id, title: card.title || this.uiText("pm_board_bd3f17ee"),
        pinCount: card.pinCount === undefined ? '' : card.pinCount.toString(), ownerName: '', ownerAvatar: '',
        loading: false, loadingMore: false, ready: false,
        error: opening ? this.uiText("pm_board_session_not_ready_please_retry_a1710cad") : this.uiText("pm_board_service_not_ready_please_retry_c1a3998b"), hasMore: false, pins: [] };
    }, 20000);
  }

  private async openCustomHomeMenu(pinUrl: string, pageKey: string, inboxAction: string = '', profilePin: boolean = false): Promise<void> { return this.photoMenuCoordinator.openCustomHomeMenu(pinUrl, pageKey, inboxAction, profilePin); }

  private async performCustomHomeAction(id: string): Promise<void> { return this.photoMenuCoordinator.performCustomHomeAction(id); }

  private async openProfilePinMenu(id: string): Promise<void> {
    if (!PIN_NATIVE_PIN_MENUS_ENABLED && !await this.prepareProfileInteraction()) return;
    if (this.rejectOfflineAction('profile menu')) return;
    const profile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile) return;
    const pin: PinmonyCreatedPin | undefined = profile.createdPins.concat(profile.unorganizedPins || []).find((item: PinmonyCreatedPin): boolean => item.id === id);
    if (!pin || !pin.targetUrl) return;
    this.openCustomHomeMenu(pin.targetUrl, profile.profileUrl, '', true);
  }

  private async openHomeMoreViaDetail(pinUrl: string, returnUrl: string): Promise<void> { return this.photoMenuCoordinator.openHomeMoreViaDetail(pinUrl, returnUrl); }

  private async loadMoreHome(): Promise<void> {
    return this.homeController.loadMoreHome();
  }

  private refreshHome(): void {
    return this.homeController.refreshHome();
  }

  @StorageLink('pinmonyUpdateUnread') private updateUnread: boolean = false;
  @Builder
  private buildNativeTab(labelKey: string, symbol: Resource, index: number) {
    Column({ space: 2 }) {
      Badge({ value: '', position: BadgePosition.RightTop,
        style: { badgeSize: index === 3 && this.updateUnread ? 6 : 0, fontSize: 0 } }) {
      SymbolGlyph(symbol)
        .fontSize(24)
        .fontColor([this.activeTab === index ? $r('app.color.tab_text_primary') :
          $r('app.color.tab_text_secondary')])
      }
      Text(PinmonyI18n.text(labelKey, this.uiLanguage))
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
    .accessibilityText(PinmonyI18n.text(labelKey, this.uiLanguage))
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
      this.returnCoordinator.cancel();
      PinmonyRuntimeLog.info('PinmonyReturn: destination route confirmed');
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
    if(PIN_NATIVE_DETAIL_READS_ENABLED && this.detailNativeReads.owned())return this.pinStore.detailPin || this.pinStore.detailOpeningPin;
    if(PIN_NATIVE_PROFILE_READS_ENABLED && this.profileStore.origins.length > 0)return this.navigationAddress;
    if (this.nativeRootOnly) return this.rootPresentationAddress(this.activeTab);
    const nativeAddress: string = this.nativeRootPageAddress(this.activeTab);
    if (nativeAddress) return nativeAddress;
    try { return this.sessionDocumentUrl(); } catch (_) { return this.navigationAddress; }
  }

  private presentNativeBackTarget(target: string): void { return this.navigationCoordinator.presentNativeBackTarget(target); }

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
      PinmonyRuntimeLog.warn('Pinmony: matching history entry unavailable');
    }
    return false;
  }

  private loadReturnTarget(target: string, token: number): void {
    if (this.businessSuspended || token !== this.pageBackToken || this.returnLoadToken === token) return;
    this.returnLoadToken = token;
    this.detailReturnJourney?.mark('return.target.load.once');
    try { this.loadSessionDocument(target); }
    catch (error) {
      if (!this.boardUrlFromAddress(target) || this.boardStore.boardDetail?.pageKey !== target) throw new Error(this.uiText("pm_unable_to_load_the_previous_page_1589d5b1"));
      this.boardStore.boardDetail.loading = false;
      this.boardStore.boardDetail.error = PinmonyI18n.message("pm_unable_to_sync_board_please_retry_f0f531e0");
      PinmonyRuntimeLog.warn('BoardReturn: navigation-dispatch-failed');
      return;
    }
    if (this.boardUrlFromAddress(target)) this.returnCoordinator.schedule(() => {
      if (token !== this.pageBackToken || this.boardStore.boardDetail?.pageKey !== target ||
          !this.boardStore.presentationOnly || this.pinStore.detail || this.pinStore.detailOpeningPin) return;
      this.boardStore.boardDetail.loading = false;
      this.boardStore.boardDetail.error = PinmonyI18n.message("pm_board_sync_timed_out_please_retry_a00c8b96");
      PinmonyRuntimeLog.warn('BoardReturn: synchronization-timeout');
    }, 20000);
  }

  private completeNativeBack(target: string): boolean {
    if(!PIN_NATIVE_DETAIL_READS_ENABLED || !PIN_NATIVE_BOARD_READS_ENABLED || !PIN_NATIVE_PROFILE_READS_ENABLED)return false;
    const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    if(!session.authenticated || !target.startsWith(session.origin + '/'))return false;
    if(this.returnToNativeProfile(target))return true;
    if (PIN_NATIVE_SEARCH_READS_ENABLED && this.searchUrlFromAddress(target)) {
      this.clearDetail(); this.searchNativeReads.pause(); this.commitNativeSearchReturn(target); return true;
    }
    const pin: string = this.extractPinUrl(target),board: string = this.boardUrlFromAddress(target),root: number = this.rootTabIndexFromAddress(target);
    if(!pin && !board && root < 0)return false;
    this.returnCoordinator.cancel();this.pageHistory.cancelBack();this.pageHistory.visit(target,'load');this.pageBackToken++;
    if(pin){this.beginDetailOpening(pin, '', true);return true;}
    if(board){
      this.clearDetail();this.nativeRootOnly = false;this.nativeBackTarget = target;this.navigationAddress = target;
      this.boardStore.presentationOnly = false;this.boardStore.presentationPage = target;this.syncBoardRoute(target);
      this.boardNativeReads.demand();this.syncFloatingTabsMotion();return true;
    }
    const retained = this.inboxStore.retainedChat;
    this.presentNativeBackTarget(target);this.nativeBackTarget = '';this.navigationAddress = target;this.nativeRootOnly = true;this.detailReturnedToRoot = true;
    this.activeTab = root;this.tabsController.changeIndex(root);this.rootTabAddresses.set(root,target);this.pendingWebTab = -1;this.retainedRootTabPending = -1;
    this.boardStore.boardDetail = undefined;this.boardStore.pendingBoardUrl = '';this.boardStore.pendingBoardSource = '';this.boardStore.boardReturnUrl = '';this.boardStore.boardReturnPage = '';
    if(root === 2 && retained){this.inboxStore.inboxFlow = retained;this.inboxStore.retainedChat = undefined;this.inboxStore.flowDismissed = false;this.nativeRootOnly = false;this.nativeBackTarget = target;this.inboxMessagesNativeReads.demand();}
    this.syncFloatingTabsMotion();return true;
  }

  private backOnePage(fallback: string = PINTEREST_URL, targetOverride: string = ''): boolean {
    if (this.boardSectionVisible) { this.closeBoardSection(); return true; }
    if (this.boardStore.collaborators) { this.closeBoardCollaborators(); return true; }
    if (this.pageHistory.isPending()) return true;
    try {
      const target: string = targetOverride ? this.pageHistory.prepareBackTo(targetOverride) :
        this.pageHistory.prepareBack(fallback);
      if (!target) return false;
      if(PIN_NATIVE_DETAIL_READS_ENABLED && PIN_NATIVE_BOARD_READS_ENABLED && this.completeNativeBack(target))return true;
      const token: number = ++this.pageBackToken;
      this.returnCoordinator.cancel();
      this.restoreRetainedSearch(this.searchUrlFromAddress(target));
      const canReuseHomeDocument: boolean = !this.webPageLoading && !this.pinStore.detailOpeningPin;
      const departedPin: string = this.pinStore.detailPin || this.pinStore.detailOpeningPin;
      if (departedPin) {
        this.runSessionScript('window.PinmonyDetailPause && window.PinmonyDetailPause(' +
          JSON.stringify(departedPin) + ')').catch(() => {});
      }
      const returnStartedAt: number = Date.now();
      PinmonyRuntimeLog.info('PinmonyReturn: requested');
      this.presentNativeBackTarget(target);
      this.nativeNetwork.invalidate();
      this.pinStore.detailPrefetch.pause();
      PinmonyRuntimeLog.info('PinmonyReturn: native-state prepared=' + (this.nativeBackTarget === target).toString() +
        ' elapsedMs=' + (Date.now() - returnStartedAt).toString());
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
      this.returnCoordinator.synchronize(target, token, canReuseHomeDocument, !!departedPin);
      this.lastRootBackAt = 0;
      return true;
    } catch (error) {
      this.pageHistory.cancelBack();
      this.showMessage(PinmonyI18n.message("pm_unable_to_go_back_please_retry_15d11c57"));
      return true;
    }
  }

  private async backFromDetail(): Promise<void> {
    PinmonyRuntimeLog.info('PinmonyReturn: detail back sheet=' + this.activeSheetKind +
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
    if(this.returnToNativeProfile(parent))return;
    if(PIN_NATIVE_PROFILE_READS_ENABLED && this.profileStore.origins.length > 0 && this.extractPinUrl(parent)){this.beginDetailOpening(this.extractPinUrl(parent));return;}
    this.backOnePage(parent || PINTEREST_URL, origin);
  }

  private returnFromSearchQuiz(): boolean {
    if(PIN_NATIVE_SEARCH_READS_ENABLED){if(this.searchStore.search?.pageKey === this.currentSearchPageKey() && this.searchStore.search?.quiz && this.searchStore.search.quiz.mode !== 'entry'){this.searchNativeReads.quizAction('back');return true;}return false;}
    const current: PinmonySearchSnapshot | undefined = this.searchStore.search;
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
    this.runSessionScript('window.PinmonySearchQuizApi && window.PinmonySearchQuizApi.action(' +
      JSON.stringify(current.pageKey) + ',"back","")')
      .catch(() => PinmonyRuntimeLog.warn('Pinmony: quiz background cancellation unavailable'));
    return true;
  }

  private async handleBack(): Promise<void> { return this.navigationCoordinator.handleBack(); }

  private reload(): void {
    if (this.offlinePreviewMode) {
      this.offlinePreviewMode = false;
      this.offlineCacheLoading = false;
      PinmonyRuntimeLog.info('OfflineCache: preview retry requested');
      PinmonyRuntimeLog.info('OfflineCache: preview exited reason=manual-retry');
      this.retryLogin();
      return;
    }
    if (this.authStatus !== 'authenticated') { this.retryLogin(); return; }
    if (this.nativeRootOnly) { this.requestRootPage(this.activeTab); return; }
    this.loadFailed = false;
    this.failureDetails = '';
    try {
      this.loadSessionDocument(this.lastPageUrl || PINTEREST_URL);
    } catch (error) {
      this.loadFailed = true;
    }
  }

  private async openInBrowser(): Promise<void> {
    try {
      await this.systemActions.openLink(PINTEREST_URL);
    } catch (error) {
      PinmonyRuntimeLog.error('Pinmony: failed to open Pinterest in browser');
      this.showMessage(PinmonyI18n.message("pm_unable_to_open_browser_7048491c"));
    }
  }

  private showMessage(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: PinmonyI18n.render(message, this.uiLanguage) });
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: message unavailable');
    }
  }

  private rejectOfflineAction(action: string, message: string = PinmonyI18n.message("pm_this_action_is_unavailable_offline_2fc3526f")): boolean {
    if (!this.offlinePreviewMode) return false;
    PinmonyRuntimeLog.info('ActionGate: ' + action + ' blocked reason=offline-preview');
    this.showMessage(message);
    return true;
  }

  private isCurrentPageFailure(url: string): boolean { return this.failureRecoveryCoordinator.isCurrentPageFailure(url); }

  /**
   * A root document can fail while its native snapshot is still usable. Keep
   * that snapshot visible and gate its actions instead of replacing the whole
   * root Tabs tree with the global load-failed page.
   */
  private retainRootSnapshotAfterFailure(failedRoot: number, url: string, code: number): boolean { return this.failureRecoveryCoordinator.retainRootSnapshotAfterFailure(failedRoot, url, code); }

  private configureDocumentRetention(enabled: boolean): void {
    if (this.nativeLoginEnabled && !this.loginHostMounted) {
      PinmonyRuntimeLog.info('RootTabTrace: document-retention skipped reason=web-unmounted');
      return;
    }
    try {
      // Visible business UI stays native; the hidden session must keep processing
      // network completions and bridge callbacks without inactive-page throttling.
      this.controller.onActive();
      PinmonyRuntimeLog.info('WebActivity: hidden=' + enabled.toString() + ' sessionActive=true');
    } catch (_) { PinmonyRuntimeLog.warn('WebActivity: update unavailable'); }
    try {
      const options: webview.BackForwardCacheOptions = new webview.BackForwardCacheOptions();
      options.size = enabled ? 4 : 0;
      options.timeToLive = 300;
      this.controller.setBackForwardCacheOptions(options);
      PinmonyRuntimeLog.info('RootTabTrace: document-retention size=' + options.size.toString() +
        ' ttlSeconds=' + options.timeToLive.toString());
    } catch (_) { PinmonyRuntimeLog.warn('PinmonyReturn: document retention configuration unavailable'); }
  }

  private scheduleInterruptedHomeRecovery(): void { return this.failureRecoveryCoordinator.scheduleInterruptedHomeRecovery(); }

  private handleMainFrameFailure(url: string, code: number, info: string): void { return this.failureRecoveryCoordinator.handleMainFrameFailure(url, code, info); }

  private describeFailure(url: string, code: number): string { return this.failureRecoveryCoordinator.describeFailure(url, code); }

  private clearProfile(preserveWebFlow: boolean = false): void {
    if(PIN_NATIVE_PROFILE_READS_ENABLED)this.profileNativeReads.pause();
    const preparingPublish: boolean = this.activeSheetKind === 'publish' && this.profileStore.publishPreparing;
    this.profileReadController.pause();
    this.profileActionsController.reset();
    this.closePublishFlow(true);
    this.finishProfilePull();
    const profileHasContent: boolean = !!this.profileStore.profile &&
      (this.profileStore.profileActionsReady || this.profileStore.profile.boards.length > 0 ||
        this.profileStore.profile.createdPins.length > 0 || !!this.profileStore.profile.displayName);
    if (this.profileStore.profile && profileHasContent) {
      this.profileStore.profileCache.put(this.profileStore.profile, this.profileStore.profileScrollOffset);
    }
    this.profileStore.profileActionsReady = false;
    this.profileStore.profileSessionReady = false;
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
    this.profileStore.publishLoading = preparingPublish;
    if (this.activeSheetKind === 'publish' && !preparingPublish) {
      this.showNativeSheet = false;
      this.activeSheetKind = '';
    }
  }

  private restoreProfile(address: string): boolean { return this.profileReadController.restore(address); }

  private expectProfile(): void { if(this.usesNativeProfileReads()){this.profileNativeReads.demand(); return;} this.profileReadController.expect(); }

  private profileUrlFromAddress(address: string): string { return PinmonyRouteParser.profileUrlFromAddress(address); }

  private usesNativeProfileReads(): boolean {
    return PIN_NATIVE_PROFILE_READS_ENABLED;
  }

  private currentProfileUrl(): string {
    if (this.profileStore.origins.length > 0) {
      const target: string = this.profileUrlFromAddress(this.nativeBackTarget || this.navigationAddress);
      if(PIN_NATIVE_PROFILE_READS_ENABLED)return target;
      if (target) return target;
    }
    if(PIN_NATIVE_PROFILE_READS_ENABLED && this.authStatus === 'authenticated' && this.profileStore.origins.length === 0)return this.profileUrlFromAddress(this.authenticatedProfileUrl);
    const nativeAddress: string = this.nativeRootPageAddress(3);
    if (nativeAddress) return this.profileUrlFromAddress(nativeAddress);
    try {
      return this.profileUrlFromAddress(this.sessionDocumentUrl());
    } catch (error) {
      return '';
    }
  }

  private boardUrlFromAddress(address: string): string { return PIN_BOARD_API_ENABLED ? PinmonyRouteParser.boardUrlFromAddress(address) : ''; }

  private currentBoardUrl(): string {
    if (this.nativeRootOnly) return '';
    if(PIN_NATIVE_BOARD_READS_ENABLED && this.nativeBackTarget && this.boardStore.boardDetail?.pageKey === this.nativeBackTarget && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.publishBoardReturn) return this.boardUrlFromAddress(this.nativeBackTarget);
    try { return this.boardUrlFromAddress(this.sessionDocumentUrl()); } catch (_) { return ''; }
  }

  private isCurrentBoardMenuPin(pinUrl: string, pageKey: string): boolean {
    const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
    if (this.authStatus !== 'authenticated' || !board || (!board.session && !(PIN_NATIVE_PIN_MENUS_ENABLED && board.nativeReadsReady && board.nativeAccountGeneration === this.nativeBusinessSessionContext().generation)) || !board.ready ||
        board.pageKey !== pageKey || this.currentBoardUrl() !== pageKey || board.flow?.busy ||
        (board.flow?.phase && board.flow.phase !== 'ideas' && board.flow.phase !== 'section')) return false;
    const pins: PinmonyBoardPin[] = boardVisiblePins(board);
    return !!this.pinIdentity(pinUrl) && pins.some((pin: PinmonyBoardPin): boolean => pin.pinUrl === pinUrl);
  }

  private openBoardPinMore(id: string): void {
    const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
    if (!PIN_POST_API_ENABLED || !board) return;
    const pins: PinmonyBoardPin[] = boardVisiblePins(board);
    const pin: PinmonyBoardPin | undefined = pins.find((item: PinmonyBoardPin): boolean => item.id === id);
    if (pin && !this.cancelledBoardPins.has(pin.pinUrl) && this.isCurrentBoardMenuPin(pin.pinUrl, board.pageKey)) this.openCustomHomeMenu(pin.pinUrl, board.pageKey);
  }

  private async openBoardChat(): Promise<void> {
    const board = this.boardStore.boardDetail;
    if (!board?.ready || this.currentBoardUrl() !== board.pageKey || !(board.editable || board.collaborator)) return;
    if (board.chatMemberCount !== 2 || !board.chatPeer) { this.showMessage(PinmonyI18n.message("pm_board_messaging_unavailable_only_two_person_chats_are_supported_4240c5cb")); return; }
    const peer = board.chatPeer;
    this.traceAction('board.chat');
    this.selectNativeRootTab(2);
    if(PIN_NATIVE_INBOX_MESSAGES_ENABLED) {
      await this.selectInboxSection('messages');
      if(!await this.inboxMessagesNativeReads.direct(peer.id,peer.name,peer.avatar,peer.username || ''))this.showMessage(PinmonyI18n.message("pm_chat_unavailable_please_retry_fcee3c6e"));
      return;
    }
    if (!await this.ensureRootActionContext(2)) return;
    await this.selectInboxSection('messages');
    for (let attempt: number = 0; attempt < 60; attempt++) {
      if (!this.currentInboxUrl() || this.businessSuspended) return;
      if (this.inboxStore.inbox?.section === 'messages' && this.inboxStore.inboxActionsReady && !this.inboxStore.inboxLoading) break;
      if (!await this.coordinatorTasks.wait(100)) return;
    }
    if (this.inboxStore.inbox?.section !== 'messages' || !this.inboxStore.inboxActionsReady || this.inboxStore.inboxLoading) { this.showMessage(PinmonyI18n.message("pm_chat_unavailable_please_retry_fcee3c6e")); return; }
    try {
      this.inboxStore.flowDismissed = false;
      const result = await this.runSessionScript('window.PinmonyInboxConversations && window.PinmonyInboxConversations.direct(' + JSON.stringify(peer) + ',' + this.inboxStore.inboxSession.toString() + ')');
      if (result === 'true' || result === '"true"') return;
    } catch (_) {}
    this.showMessage(PinmonyI18n.message("pm_chat_unavailable_please_retry_fcee3c6e"));
  }

  private async openBoardCollaborators(): Promise<void> {
    if(PIN_NATIVE_BOARD_READS_ENABLED){this.boardCollaboratorsController.pause();await this.boardNativeReads.openCollaborators();return;}
    await this.boardCollaboratorsController.open();
  }

  private pollBoardCollaborators(token: number): void {
    if(PIN_NATIVE_BOARD_READS_ENABLED && !this.boardNativeReads.collaboratorsPolling())return;
    this.boardCollaboratorsController.poll(token);
  }

  private boardCollaboratorsAction(action: string, value: string): void {
    if(PIN_NATIVE_BOARD_READS_ENABLED){this.boardNativeReads.collaboratorsAction(action,value).catch((): void => {});return;}
    this.boardCollaboratorsController.action(action, value);
  }

  private closeBoardCollaborators(): void {
    if(PIN_NATIVE_BOARD_READS_ENABLED){if(this.boardStore.collaborators?.busy)return;this.boardCollaboratorsController.pause();this.boardNativeReads.collaboratorsAction('close','').catch((): void => {});return;}
    this.boardCollaboratorsController.close();
  }

  private async readBoardInvitations(preview: boolean = false): Promise<void> { await this.boardInvitationController.open(preview); }

  private pollBoardInvitations(token: number, preview: boolean): void { this.boardInvitationController.poll(token, preview); }

  private previewBoardInvitation(item: PinmonyBoardInvitation): void {
    if (!this.boardInvitationController.preparePreview(item)) return;
    this.clearRootTabGuard('invitation-preview');
    this.boardStore.boardReturnUrl = this.currentInboxUrl(); this.boardStore.boardReturnPage = item.boardUrl;
    this.boardStore.pendingBoardSource = this.currentInboxUrl(); this.boardStore.pendingBoardUrl = item.boardUrl;
    this.boardStore.presentationPage = item.boardUrl;
    this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: item.boardUrl, boardId: item.boardId, title: item.boardName,
      pinCount: '', ownerName: '', ownerAvatar: '', loading: true, loadingMore: false, ready: false, error: '', hasMore: false, pins: [] };
    if(PIN_NATIVE_BOARD_READS_ENABLED){this.boardStore.rootTab = 2;this.nativeRootOnly = false;this.nativeBackTarget = item.boardUrl;this.navigationAddress = item.boardUrl;this.pageHistory.visit(item.boardUrl,'push');this.boardNativeReads.demand();this.readBoardInvitations(true);return;}
    try { this.loadSessionDocument(item.boardUrl); }
    catch (_) {
      this.boardStore.pendingBoardSource = ''; this.boardStore.pendingBoardUrl = '';
      this.boardStore.boardReturnPage = ''; this.boardStore.presentationPage = '';
      this.boardStore.boardDetail = undefined;
      this.showMessage(PinmonyI18n.message("pm_unable_to_open_invited_board_please_retry_f782ac68"));
    }
  }

  private acceptBoardInvitation(): void { this.boardInvitationController.accept(); }

  private isCurrentSearchMenuPin(pinUrl: string, pageKey: string): boolean {
    return this.activeTab === 1 && !!pageKey && this.searchStore.search?.pageKey === pageKey &&
      this.currentSearchPageKey() === pageKey && !this.pinStore.detail && !this.pinStore.detailOpeningPin &&
      this.searchStore.search.results.some((item): boolean => item.kind === 'pin' && item.targetUrl === pinUrl && item.enabled);
  }

  private async openSearchPinMenu(pinUrl: string): Promise<void> {
    const pageKey: string = this.searchStore.search?.pageKey || '';
    if (!PIN_POST_API_ENABLED || !this.isCurrentSearchMenuPin(pinUrl, pageKey)) return;
    if (!PIN_NATIVE_PIN_MENUS_ENABLED && !await this.ensureRootActionContext(1) || !this.isCurrentSearchMenuPin(pinUrl, pageKey)) return;
    this.openCustomHomeMenu(pinUrl, pageKey);
  }

  private currentShareObjectUrl(): string { return this.currentBoardUrl() || this.currentProfileUrl(); }
  private shareObjectReady(): boolean { return this.currentBoardUrl() ? this.boardStore.boardDetail?.ready === true : this.profileStore.profileActionsReady; }

  private async shareCurrentBoard(): Promise<void> {
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED){const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;if(board?.ready && (!board.flow?.phase || board.flow.phase === 'section') && !board.flow?.loading && !board.flow?.busy && !board.flow?.uncertain && !this.activeSheetKind)await this.shareNativeFlow.open('board',board.pageKey,board.boardId);return;}
    const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
    if (this.authStatus !== 'authenticated' || !board?.session || !board.ready || board.flow?.phase ||
        this.currentBoardUrl() !== board.pageKey) return;
    this.profileShareMode = true; this.pinStore.shareSession = 0; this.pinStore.ignoredShareSession = 0;
    try {
      const result: string = await this.runSessionScript('window.PinmonyNativeShareApiOpen && ' +
        'window.PinmonyNativeShareApiOpen(' + JSON.stringify(board.pageKey) + ')');
      if (result !== 'true' && result !== '"true"') this.showMessage(PinmonyI18n.message("pm_sharing_unavailable_please_retry_3883cb6a"));
    } catch (_) { this.showMessage(PinmonyI18n.message("pm_sharing_unavailable_please_retry_3883cb6a")); }
  }

  private syncBoardRoute(address: string): void {
    if (this.nativeRootOnly) return;
    if(PIN_NATIVE_BOARD_READS_ENABLED && this.nativeBackTarget === this.boardStore.boardDetail?.pageKey &&
      this.boardStore.boardDetail?.nativeVersion !== undefined && this.boardUrlFromAddress(address) && address !== this.nativeBackTarget)return;
    const before: string = this.boardStore.boardDetail?.pageKey || '';
    this.boardStateController.syncRoute(address);
    if(PIN_NATIVE_BOARD_READS_ENABLED) {if(this.boardNativeReads.eligible())this.boardNativeReads.demand();else this.boardNativeReads.pause();}
    const page: string = this.boardStore.boardDetail?.pageKey || '';
    if (page && page !== before && !this.businessSuspended) this.pagePerformance.beginSecondary('board', page);
  }

  private updateBoard(value: string): void {
    const before: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
    if(PIN_NATIVE_BOARD_READS_ENABLED)this.boardNativeReads.updateBridge(value);else this.boardStateController.update(value);
    const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
    if (board && board !== before && board.ready && !board.loading && !board.error && !this.businessSuspended)
      this.pagePerformance.markSecondary('board', board.pageKey, 'content-ready');
  }

  private nativeBoardVisible(): boolean {
    return !this.loadFailed && !!this.boardStore.boardDetail &&
      (!this.nativeRootOnly || this.publishBoardReturn === this.boardStore.boardDetail.pageKey) && (this.boardStore.presentationPage === this.boardStore.boardDetail.pageKey ||
        this.boardStore.pendingBoardUrl === this.boardStore.boardDetail.pageKey || this.boardUrlFromAddress(this.nativeDisplayAddress()) === this.boardStore.boardDetail.pageKey);
  }

  private syncNativeReturnRoute(address: string): void { return this.navigationCoordinator.syncNativeReturnRoute(address); }

  private openProfilePanelBoard(url: string): void {
    const target: string = this.boardUrlFromAddress(url), profile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
    const source: string = profile ? profile.profileUrl + (profile.section === 'created' ? '_created/' : '') : '';
    if(!target || !source || this.authStatus !== 'authenticated')return;
    if(!PIN_NATIVE_BOARD_READS_ENABLED){this.boardStore.boardReturnUrl = this.sessionDocumentUrl();this.closeProfilePanel();this.loadSessionDocument(target);return;}
    const panel: PinmonyProfilePanel | undefined = this.profileStore.panel;
    const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    this.followingBoardReturn = panel?.mode === 'following' && panel.section === 'boards' ? {
      board: target, source: source, mode: panel.mode, section: panel.section,
      account: session.accountId, generation: session.generation, origin: session.origin, depth: this.profileStore.origins.length
    } : undefined;
    this.closeProfilePanel();this.profileNativeReads.pause();this.returnCoordinator.cancel();this.pageHistory.cancelBack();this.pageBackToken++;
    this.nativeRootOnly = false;this.navigationAddress = target;this.nativeBackTarget = target;
    this.boardStore.rootTab = this.activeTab;this.boardStore.boardReturnUrl = source;this.boardStore.boardReturnPage = target;
    this.boardStore.boardOpeningToken++;this.boardStore.pendingBoardUrl = target;this.boardStore.pendingBoardSource = source;
    this.boardStore.boardDetail = {kind:'state',session:0,pageKey:target,boardId:'',title:this.uiText("pm_board_bd3f17ee"),pinCount:'',ownerName:'',ownerAvatar:'',loading:true,loadingMore:false,ready:false,error:'',hasMore:false,pins:[]};
    this.pageHistory.visit(source,'load');this.pageHistory.visit(target,'push');this.boardNativeReads.demand();this.syncFloatingTabsMotion();
  }

  private async openProfileBoard(id: string): Promise<void> {
    this.followingBoardReturn = undefined;
    this.boardStore.discoveryBoardPage = '';
    this.traceAction('profile.board', id);
    const intent: number = this.tabRequestToken;
    if (!PIN_BOARD_API_ENABLED) {
      PinmonyRuntimeLog.info('ActionTrace: profile.board disabled reason=api');
      return;
    }
    const profile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile) {
      PinmonyRuntimeLog.info('ActionTrace: profile.board disabled reason=profile-unavailable');
      return;
    }
    if (this.boardStore.pendingBoardUrl) {
      PinmonyRuntimeLog.info('ActionTrace: profile.board disabled reason=already-opening');
      return;
    }
    if (this.authStatus !== 'authenticated' ||
        (this.profileStore.origins.length === 0 ? this.activeTab !== 3 : this.currentProfileUrl() !== profile.profileUrl)) {
      PinmonyRuntimeLog.info('ActionTrace: profile.board disabled reason=profile-url-mismatch');
      return;
    }
    let card: PinmonyBoard | undefined = profile.boards.find((item: PinmonyBoard): boolean => item.id === id);
    if (!card) {
      // A profile bridge update can replace the card array in the same frame
      // as the tap event. Re-read the current snapshot once before rejecting
      // the tap as stale.
      if (!await this.coordinatorTasks.wait(80)) return;
      if (intent !== this.tabRequestToken) return;
      const latest: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
      if (latest && latest.profileUrl === profile.profileUrl && this.currentProfileUrl() === latest.profileUrl) {
        card = latest.boards.find((item: PinmonyBoard): boolean => item.id === id);
      }
    }
    if (!card) {
      PinmonyRuntimeLog.info('ActionTrace: profile.board disabled reason=board-not-found');
      return;
    }
    const target: string = card?.targetUrl ? this.boardUrlFromAddress(card.targetUrl) : '';
    if (!target) {
      PinmonyRuntimeLog.info('ActionTrace: profile.board disabled reason=board-target-invalid');
      return;
    }
    this.profileStore.profileCache.put(profile, this.profileStore.profileScrollOffset);
    this.nativeRootOnly = false;
    // A new board intent supersedes an unfinished return to the profile.
    this.returnCoordinator.cancel();
    this.pageHistory.cancelBack();
    this.pageBackToken++;
    this.nativeBackTarget = '';
    const token: number = ++this.boardStore.boardOpeningToken;
    this.boardStore.rootTab = this.activeTab;
    this.clearRootTabGuard('board-open');
    this.boardStore.pendingBoardSource = profile.section === 'created' ? profile.profileUrl + '_created/' : profile.profileUrl;
    try {
      const source: string = this.sessionDocumentUrl();
      const retained: string = this.rootTabAddresses.get(3) || '';
      if (this.profileUrlFromAddress(source) === profile.profileUrl) this.boardStore.pendingBoardSource = source;
      else if (this.profileStore.origins.length === 0 && this.profileUrlFromAddress(retained) === profile.profileUrl) {
        this.boardStore.pendingBoardSource = retained;
      }
    } catch (_) {}
    this.boardStore.boardReturnUrl = this.boardStore.pendingBoardSource;
    this.boardStore.boardReturnPage = target;
    this.pagePerformance.beginSecondary('board', target);
    this.boardStore.pendingBoardUrl = target;
    const initialTitle: string = /\/pins\/$/i.test(target) ? this.uiText("pm_all_pins_9a2e0270") : (card!.title || this.uiText("pm_board_bd3f17ee"));
    this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: '', title: initialTitle,
      pinCount: card!.pinCount, ownerName: '', ownerAvatar: '', loading: true, loadingMore: false,
      ready: false, error: '', hasMore: false, pins: [] };
    if(PIN_NATIVE_BOARD_READS_ENABLED){
      this.profileNativeReads.pause();this.nativeBackTarget = target;this.navigationAddress = target;this.pageHistory.visit(target,'push');this.boardNativeReads.demand();return;
    }
    let dispatched: boolean = false;
    try {
      // Board cards already carry a validated route. Keep navigation separate
      // from the profile business-action whitelist, which only opens Pins.
      this.loadSessionDocument(target);
      dispatched = true;
    } catch (_) {
      this.showMessage(PinmonyI18n.message("pm_unable_to_open_board_please_retry_846bb29a"));
    }
    if (!dispatched && token === this.boardStore.boardOpeningToken && this.boardStore.pendingBoardUrl === target) {
      this.boardStore.pendingBoardUrl = ''; this.boardStore.pendingBoardSource = ''; this.boardStore.boardDetail = undefined;
      this.boardStore.boardReturnUrl = ''; this.boardStore.boardReturnPage = '';
      return;
    }
    this.coordinatorTasks.timeout(() => {
      if (!this.boardStore.boardDetail || this.boardStore.boardDetail.pageKey !== target || this.boardStore.boardDetail.session !== 0 ||
          this.boardStore.presentationOnly || this.boardStore.boardDetail.ready) return;
      const stillOpening: boolean = token === this.boardStore.boardOpeningToken && this.boardStore.pendingBoardUrl === target;
      const awaitingBridge: boolean = token + 1 === this.boardStore.boardOpeningToken && this.currentBoardUrl() === target;
      if (!stillOpening && !awaitingBridge) return;
      this.boardStore.boardDetail = { kind: 'state', session: 0, pageKey: target, boardId: '', title: initialTitle,
        pinCount: card!.pinCount, ownerName: '', ownerAvatar: '', loading: false, loadingMore: false,
        ready: false, error: stillOpening ? this.uiText("pm_board_session_not_ready_please_retry_a1710cad") : this.uiText("pm_board_service_not_ready_please_retry_c1a3998b"), hasMore: false, pins: [] };
    }, 20000);
  }

  private backFromBoard(): void {
    if(PIN_NATIVE_BOARD_READS_ENABLED && !this.boardStore.boardDetail?.flow?.phase && !this.boardStore.boardDetail?.flow?.busy)this.boardNativeReads.pause();
    if (this.boardStore.presentationOnly && this.boardStore.boardDetail) {
      this.pageHistory.visit(this.boardStore.boardDetail.pageKey, 'load');
      this.pageHistory.cancelBack();
      this.nativeBackTarget = '';
      this.pageBackToken++;
    }
    if (this.boardStore.boardDetail?.flow?.busy) return;
    if(this.boardStore.boardDetail?.flow?.phase === 'targets' && this.boardStore.boardDetail.flow.targetBoardId && !this.boardStore.boardDetail.flow.uncertain) {
      this.boardOperation('flow', JSON.stringify({action:'sectionTargetBack'}));return;
    }
    if (this.boardStore.boardDetail?.flow?.phase) {
      const phase: string = this.boardStore.boardDetail.flow.phase;
      this.boardOperation('flow', JSON.stringify({ action: phase === 'targets' && !this.boardStore.boardDetail.flow.uncertain ? 'select' : 'close' }));
      return;
    }
    const panelReturn: PinmonyFollowingBoardReturn | undefined = this.followingBoardReturn;
    const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    if (panelReturn && panelReturn.board === this.boardStore.boardReturnPage && panelReturn.source === this.boardStore.boardReturnUrl &&
        panelReturn.depth === this.profileStore.origins.length && session.authenticated && session.accountId === panelReturn.account &&
        session.generation === panelReturn.generation && session.origin === panelReturn.origin) {
      this.followingBoardReturn = undefined;
      if (this.returnToNativeProfile(panelReturn.source)) {
        this.immediateFollowingReturn = true;
        this.profileActionsController.openPanel(panelReturn.mode, panelReturn.section);
        return;
      }
    }
    if(PIN_NATIVE_PROFILE_READS_ENABLED && this.boardStore.boardReturnUrl && this.returnToNativeProfile(this.boardStore.boardReturnUrl))return;
    if (this.boardStore.pendingBoardUrl) {
      const source: string = this.boardStore.pendingBoardSource;
      this.boardStore.pendingBoardUrl = ''; this.boardStore.pendingBoardSource = ''; this.boardStore.boardOpeningToken++;
      this.boardStore.boardReturnUrl = ''; this.boardStore.boardReturnPage = '';
      this.boardStore.boardDetail = undefined; this.profileStore.profileWebFlow = false;
      if (source) {
        if(PIN_NATIVE_DETAIL_READS_ENABLED && PIN_NATIVE_BOARD_READS_ENABLED && this.completeNativeBack(source))return;
        try { this.loadSessionDocument(source); }
        catch (_) { this.showMessage(PinmonyI18n.message("pm_unable_to_return_to_profile_please_retry_a60ed98f")); }
      }
      return;
    }
    if (this.boardStore.boardReturnUrl && (this.boardStore.boardReturnPage === this.currentBoardUrl() ||
        this.boardStore.presentationOnly && this.boardStore.boardReturnPage === this.boardStore.boardDetail?.pageKey)) {
      this.retainedBoardContent = undefined;
      this.cancelledBoardPins.clear();
      this.singlePinMovePage = '';
      this.boardInvitationController.clearPreview();
      const searchReturn: string = this.searchUrlFromAddress(this.boardStore.boardReturnUrl);
      if (PIN_NATIVE_SEARCH_READS_ENABLED && searchReturn) {
        this.presentNativeBackTarget(searchReturn);
        this.commitNativeSearchReturn(searchReturn);
        return;
      }
      this.backOnePage(this.boardStore.boardReturnUrl, this.boardStore.boardReturnUrl);
      return;
    }
    this.handleBack();
  }

  private async prepareBoardNativeDocument(): Promise<boolean> {
    const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;if(!board || this.authStatus !== 'authenticated' || this.businessSuspended || this.nativeRootOnly)return false;
    const page: string = board.pageKey, token: number = this.boardStore.boardOpeningToken, generation: number = this.nativeBusinessSessionContext().generation;
    const current = (): boolean => this.authStatus === 'authenticated' && !this.businessSuspended && !this.nativeRootOnly && !this.pinStore.detail && !this.pinStore.detailOpeningPin && this.boardStore.boardDetail?.pageKey === page && this.nativeBusinessSessionContext().generation === generation;
    try {
      if(this.sessionDocumentUrl().split(/[?#]/)[0] !== page && this.boardStore.pendingBoardUrl !== page)this.loadSessionDocument(page);
      const deadline: number = Date.now() + 10000;
      while(current() && Date.now() < deadline) {
        if(this.sessionDocumentUrl().split(/[?#]/)[0] === page)return true;
        // A new board intent cancels the old wait; a route confirmation may increment this token once.
        if(this.boardStore.boardOpeningToken > token + 1)return false;
        if(!await this.coordinatorTasks.wait(150))return false;
      }
    }catch (_) {}
    return false;
  }

  private boardOperation(method: string, id: string = ''): void {
    if(PIN_NATIVE_BOARD_READS_ENABLED) {this.boardNativeReads.handle(method,id).then((handled: boolean): void => {if(!handled)this.boardOperationsController.operate(method,id);}).catch((): void => {});return;}
    this.boardOperationsController.operate(method,id);
  }

  private updateProfile(value: string): void { try { if(this.usesNativeProfileReads()){this.profileNativeReads.updateBridge(value); if(this.profileStore.profileSessionReady && this.pendingWebTab === 3) {this.pendingWebTab = -1; this.currentWebTab = 3;} return;} this.profileReadController.update(value); if(PIN_NATIVE_PROFILE_SETTINGS_ENABLED)this.profileNativeActions.overlay(); this.markRootPerformance(3);  } finally { this.rootContextCoordinator.notify(); } }

  private updateProfilePublish(value: string): void {
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED)return;
    try {
      const message: PinmonyPublishSnapshot = JSON.parse(value) as PinmonyPublishSnapshot;
      if (!message || message.kind !== 'state' || message.session !== this.profileStore.profileSession ||
        message.profileUrl !== this.profileStore.profileUrl || !Array.isArray(message.options) ||
        this.activeSheetKind !== 'publish') return;
      this.profileStore.publishOptions = message.options.filter((item: PinmonyPublishOption): boolean =>
        !!item.id && !!item.kind && !!item.group && !!item.groupLabel && !!item.label);
      this.profileStore.publishTitle = message.title || '';
      this.profileStore.publishLoading = false;
      PinmonyRuntimeLog.info(`PublishTrace: options received count=${this.profileStore.publishOptions.length}`);
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid publishing state');
    }
  }

  private async changeProfileTab(section: string): Promise<void> { if(this.usesNativeProfileReads()){await this.profileNativeReads.select(section); return;} await this.profileActionsController.changeTab(section); }

  private async organizeProfile(action: string, value: string = '', secret: boolean = false): Promise<void> { if(this.usesNativeProfileReads() && await this.profileNativeReads.unorganizedAction(action))return; await this.profileActionsController.organize(action, value, secret); }

  private openUserProfile(url: string): void {
    const rootOnly: boolean = this.nativeRootOnly;
    const previousAddress: string = this.navigationAddress;
    const page: string = this.profileUrlFromAddress(url);
    if (this.authStatus !== 'authenticated' || !page) return;
    if (page === this.currentProfileUrl() && !this.pinStore.detail && !this.pinStore.detailOpeningPin &&
        (this.profileStore.origins.length > 0 || this.activeTab === 3 && !this.inboxStore.inboxFlow)) {
      this.closeProfilePanel(); this.profileSettingsVisible = false; return;
    }
    if (this.profileStore.origins.length >= 12) return;
    const searchSource: string = this.activeTab === 1 && !this.pinStore.detail && !this.boardStore.boardDetail && !this.profileStore.origins.length ? this.currentSearchPageKey() : '';
    this.clearRootTabGuard('profile-open');
    let source: string;
    try {
      const pinSource: string = this.pinStore.detail?.pinUrl || this.pinStore.detailOpeningPin || '';
      const boardSource: string = this.boardStore.boardDetail?.pageKey || '';
      source = PIN_NATIVE_PROFILE_READS_ENABLED ? (pinSource ||
        (boardSource && (boardSource === this.nativeBackTarget || boardSource === this.navigationAddress) ? boardSource : searchSource || this.nativeDisplayAddress())) : this.sessionDocumentUrl();
    }
    catch (_) { this.showMessage(PinmonyI18n.message("pm_page_not_ready_please_retry_e6aeff92")); return; }
    if(PIN_NATIVE_PROFILE_READS_ENABLED){
      if(!this.profileStore.origins.length)this.profileBoardOrigins.clear();
      this.profileBoardOrigins.set(this.profileStore.origins.length,{board:this.boardStore.boardDetail,returnUrl:this.boardStore.boardReturnUrl,returnPage:this.boardStore.boardReturnPage,rootTab:this.boardStore.rootTab,cancelledPins:Array.from(this.cancelledBoardPins)});
    }
    this.profileStore.origins.push({ page: source, tab: this.activeTab, profile: this.profileStore.profile,
      scroll: this.profileStore.profileScrollOffset, panel: this.profileStore.panel });
    if (this.pinStore.detail) this.pinStore.detailCache.put(this.pinIdentity(this.pinStore.detail.pinUrl), this.pinStore.detail, this.pinStore.detailScrollOffset);
    if (this.activeSheetKind === 'comments') this.dismissApiComments();
    this.closeProfilePanel();
    this.clearDetail();
    this.clearProfile();

    this.nativeRootOnly = false;
    this.navigationAddress = page;
    this.loadFailed = false;
    this.failureDetails = '';
    this.profileStore.profileUrl = page;
    this.profileStore.profileLoading = true;
    this.syncFloatingTabsMotion();
    this.pageHistory.visit(source, 'load');
    if(PIN_NATIVE_PROFILE_READS_ENABLED){
      this.returnCoordinator.cancel();this.pageHistory.cancelBack();this.pageBackToken++;
      this.boardNativeReads.pause();this.cancelledBoardPins.clear();this.singlePinMovePage = '';this.boardStore.boardDetail = undefined;this.boardStore.pendingBoardUrl = '';this.boardStore.pendingBoardSource = '';
      this.boardStore.collaborators = undefined;this.boardStore.presentationOnly = false;
      this.nativeBackTarget = page;this.detailReturnedToRoot = false;this.pageHistory.visit(page,'push');
      this.profileNativeReads.demand();return;
    }
    try { this.loadSessionDocument(page); }
    catch (_) {
      const origin = this.profileStore.origins.pop();
      this.nativeRootOnly = rootOnly;
      this.navigationAddress = previousAddress;
      this.profileStore.profile = origin?.profile;
      this.profileStore.profileScrollOffset = origin?.scroll || 0;
      this.profileStore.panel = origin?.panel;
      this.profileStore.profileActionsReady = false;
      this.profileStore.profileLoading = false;
      this.syncFloatingTabsMotion();
      this.showMessage(PinmonyI18n.message("pm_unable_to_open_profile_please_retry_7395435e"));
    }
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
    if(PIN_NATIVE_PROFILE_READS_ENABLED){
      const saved: PinmonyProfileBoardOrigin | undefined = this.profileBoardOrigins.get(this.profileStore.origins.length);
      this.profileBoardOrigins.delete(this.profileStore.origins.length);
      this.cancelledBoardPins.clear();(saved?.cancelledPins || []).forEach((p: string): void => {this.cancelledBoardPins.add(p);});
      this.retainedBoardContent = saved?.board;this.singlePinMovePage = '';
      this.returnCoordinator.cancel();this.pageHistory.cancelBack();this.pageBackToken++;
      this.navigationAddress = origin.page;this.nativeBackTarget = origin.page;this.nativeRootOnly = false;this.detailReturnedToRoot = false;
      this.pageHistory.visit(origin.page,'load');
      if(this.extractPinUrl(origin.page)){
        if(saved?.board){this.boardStore.boardDetail = saved.board;this.boardStore.boardReturnUrl = saved.returnUrl;this.boardStore.boardReturnPage = saved.returnPage;this.boardStore.rootTab = saved.rootTab;}
        this.beginDetailOpening(this.extractPinUrl(origin.page));
      }else if(saved?.board){
        this.boardStore.boardDetail = saved.board;this.boardStore.boardReturnUrl = saved.returnUrl;this.boardStore.boardReturnPage = saved.returnPage;this.boardStore.rootTab = saved.rootTab;
        this.boardStore.presentationOnly = false;this.boardStore.presentationPage = saved.board.pageKey;this.boardNativeReads.demand();
      }else if(this.profileUrlFromAddress(origin.page)){
        this.nativeRootOnly = this.profileStore.origins.length === 0;
        const section: string = origin.profile?.section || (origin.page.includes('/_created/') ? 'created' : 'saved');
        this.profileNativeReads.select(section);
      }else {
        this.nativeRootOnly = !this.inboxStore.inboxFlow;
        const searchReturn: string = this.searchUrlFromAddress(origin.page);
        if (this.activeTab === 1 && searchReturn) this.commitNativeSearchReturn(searchReturn);
        else this.restoreRetainedSearch(searchReturn);
        if(this.activeTab === 2){this.inboxMessagesNativeReads.demand();this.inboxUpdatesNativeReads.demand();}
      }
      this.syncFloatingTabsMotion();
    }else this.backOnePage(origin.page, origin.page);
    if (origin.panel && this.profileUrlFromAddress(origin.page)) {
      const mode: string = origin.panel.mode, section: string = origin.panel.section;
      this.profileActionsController.scheduleOpen(mode, section, this.profileUrlFromAddress(origin.page));
    }
  }

  private returnToNativeProfile(target: string): boolean {
    if(!PIN_NATIVE_PROFILE_READS_ENABLED || !this.profileUrlFromAddress(target))return false;
    this.returnCoordinator.cancel();this.pageHistory.cancelBack();this.pageBackToken++;
    this.clearDetail();this.boardNativeReads.pause();this.boardStore.boardDetail = undefined;this.boardStore.pendingBoardUrl = '';this.boardStore.pendingBoardSource = '';
    this.boardStore.boardReturnPage = '';this.boardStore.boardReturnUrl = '';this.boardStore.presentationOnly = false;
    this.nativeRootOnly = this.profileStore.origins.length === 0;this.nativeBackTarget = target;this.navigationAddress = target;this.detailReturnedToRoot = false;
    if(!this.profileStore.origins.length){this.activeTab = 3;this.tabsController.changeIndex(3);}
    this.pageHistory.visit(target,'load');this.profileStore.profileUrl = this.profileUrlFromAddress(target);
    this.profileNativeReads.select(target.includes('/_created/') ? 'created' : 'saved');
    this.syncFloatingTabsMotion();return true;
  }

  private async followProfileUser(id: string = ''): Promise<void> { await this.profileActionsController.follow(id); }

  private closeProfilePanel(): void { this.immediateFollowingReturn = false; try { this.profileActionsController.closePanel();  } finally { this.rootContextCoordinator.notify(); } }

  private nativeProfileSaved(page: string,username: string): void {
    const session: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    const target: string = /^[A-Za-z0-9_]+$/.test(username) ? session.origin + '/' + username + '/' : page;
    this.profileNativeReads.reset();this.profileStore.profileCache.clear();
    if(target !== page){this.authenticatedProfileUrl = target;this.rootTabAddresses.set(3,target);this.navigationAddress = target;this.profileStore.profileUrl = target;this.confirmBusinessSession();}
    this.profileNativeReads.refresh();
  }
  private async openProfilePanel(mode: string, section: string = 'users'): Promise<void> { await this.profileActionsController.openPanel(mode, section); }

  private openProfileWebsite(value: string): void {
    const url: string = value.trim();
    if (!/^https?:\/\/[^\s/]+(?:\/[^\s]*)?$/i.test(url)) return;
    this.systemActions.openLink(url).catch(() => this.showMessage(PinmonyI18n.message("pm_unable_to_open_website_please_retry_02ccbc57")));
  }

  private async changeProfileAvatar(): Promise<void> {
    if (PIN_NATIVE_PROFILE_SETTINGS_ENABLED) { await this.profileNativeActions.changeAvatar(); return; }
    const panel: PinmonyProfilePanel | undefined = this.profileStore.panel;
    const token: number = this.profileStore.panelToken;
    const page: string = panel?.page || '';
    const account: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    let source: string = '';
    try { if(!PIN_NATIVE_PROFILE_SETTINGS_ENABLED)source = this.sessionDocumentUrl(); }
    catch (_) { this.showMessage(PinmonyI18n.message("pm_page_not_ready_please_retry_e6aeff92")); return; }
    if (!panel || panel.mode !== 'edit' || panel.loading || this.profileStore.saving || this.authStatus !== 'authenticated') return;
    const ownsPreview = (): boolean => {const actual: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();return token === this.profileStore.panelToken && this.profileStore.panel?.page === page && this.authStatus === 'authenticated' && (PIN_NATIVE_PROFILE_SETTINGS_ENABLED ? this.currentProfileUrl() === page && actual.accountId === account.accountId && actual.generation === account.generation && actual.origin === account.origin : this.isCurrentWebDocument(source));};
    try {
      const uris: string[] = await pickPublishPhotoUris();
      if (!uris.length) return;
      if (!ownsPreview()) return;
      const photo: PinmonyPublishPhoto = await readPublishPhoto(uris[0]);
      if (!ownsPreview()) return;
      const current: PinmonyProfilePanel = JSON.parse(JSON.stringify(this.profileStore.panel)) as PinmonyProfilePanel;
      current.avatarPreview = photo.data;
      current.avatarError = this.uiText("pm_photo_selected_but_upload_details_are_incomplete_nothing_has_bee_a5c05c90");
      this.profileStore.panel = current;
    } catch (error) {
      if (ownsPreview()) {
        const current: PinmonyProfilePanel = JSON.parse(JSON.stringify(this.profileStore.panel)) as PinmonyProfilePanel;
        current.avatarError = (error as Error).message || this.uiText("pm_unable_to_select_this_photo_please_retry_ba873d07");
        this.profileStore.panel = current;
      }
    }
  }

  private async saveProfilePanel(inputText: string): Promise<void> { await this.profileActionsController.save(inputText); }

  private async performProfileAction(id: string): Promise<boolean> {
    this.traceAction('profile.action', id);
    const profile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || !id || this.authStatus !== 'authenticated' ||
        (this.profileStore.origins.length === 0 ? this.activeTab !== 3 : this.currentProfileUrl() !== profile.profileUrl)) return false;
    if (!PIN_PROFILE_API_ENABLED ||
        !profile.createdPins.concat(profile.unorganizedPins || []).some((pin: PinmonyCreatedPin): boolean => pin.id === id)) return false;
    this.pinStore.detailReturnUrl = profile.section === 'created' ? profile.profileUrl + '_created/' : profile.profileUrl;
    const target: PinmonyCreatedPin | undefined = profile.createdPins.concat(profile.unorganizedPins || [])
      .find((pin: PinmonyCreatedPin): boolean => pin.id === id);
    const pinUrl: string = this.extractPinUrl(target?.targetUrl || '');
    if (!pinUrl || !this.pinIdentity(pinUrl)) return false;
    if (target) this.pinStore.rememberDetailOrigin(this.pinIdentity(target.targetUrl || ''), this.pinStore.detailReturnUrl);
    this.clearRootTabGuard('profile-pin-open');
    this.profileStore.profileFlowLeftPage = false;
    this.profileStore.profileWebFlow = false;
    try {
      this.beginDetailOpening(pinUrl, this.pinStore.detailReturnUrl);
      if(!PIN_NATIVE_PROFILE_READS_ENABLED)this.loadSessionDocument(pinUrl);
      return true;
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: profile action unavailable');
    }
    this.profileStore.profileWebFlow = false;
    this.showMessage(PinmonyI18n.message("pm_this_page_action_is_unavailable_please_retry_f7a12cc1"));
    return false;
  }

  private async openProfileShare(): Promise<void> {
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED){const page: string = this.profileStore.profile?.profileUrl || '';if(page && !this.activeSheetKind)await this.shareNativeFlow.open('user',page,'');return;}
    if (!await this.prepareProfileInteraction()) return;
    const profile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || !profile.profileUrl || this.authStatus !== 'authenticated' || !this.profileStore.profileActionsReady || this.activeSheetKind) return;
    this.profileShareMode = true; this.pinStore.shareSession = 0; this.pinStore.ignoredShareSession = 0;
    try {
      const result: string = await this.runSessionScript('window.PinmonyNativeShareApiOpen && window.PinmonyNativeShareApiOpen(' + JSON.stringify(profile.profileUrl) + ',true)');
      if (result !== 'true' && result !== '"true"') { this.profileShareMode = false; this.showMessage(PinmonyI18n.message("pm_share_data_not_ready_please_retry_fa0dd1d7")); }
    } catch (_) { this.profileShareMode = false; this.showMessage(PinmonyI18n.message("pm_unable_to_load_share_data_please_retry_0afbe6f0")); }
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
      Text(this.uiText("pm_profile_options_344df243")).fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).width('100%')
        .padding({ left: 24, right: 24, top: 18, bottom: 12 })
      Text(this.uiText("pm_block_5e2a9472")).fontSize(17).fontColor($r('app.color.primary_text'))
        .width('100%').height(56).padding({ left: 24, right: 24 })
        .onClick(() => {}).accessibilityText(this.uiText("pm_block_5e2a9472"))
      Text(this.uiText("pm_close_3fd47edc")).fontSize(17).fontColor($r('app.color.primary_text'))
        .width('100%').height(56).padding({ left: 24, right: 24 })
        .onClick(() => this.dismissProfileMenu()).accessibilityText(this.uiText("pm_close_3fd47edc"))
    }.width('100%').backgroundColor($r('app.color.page_background'))
      .alignItems(HorizontalAlign.Start)
  }

  private openProfilePublish(): void {
    this.publishController.openMenu();
  }

  private readProfilePublishWhenReady(url: string, deadline: number, token: number): void {
    this.publishController.readMenuWhenReady(url, deadline, token);
  }

  private dismissProfilePublish(): void { try {
    this.publishController.dismissMenu();
   } finally { this.rootContextCoordinator.notify(); } }

  private restorePublishBoard(refresh: boolean = false): void {
    const target: string = this.publishBoardReturn;
    this.publishBoardReturn = '';
    if (!target || this.authStatus !== 'authenticated' || this.businessSuspended) return;
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED && this.boardStore.boardDetail?.pageKey === target && this.boardStore.boardDetail.nativeVersion !== undefined){
      this.nativeRootOnly = false;this.boardStore.presentationPage = target;this.boardStore.presentationOnly = false;
      this.nativeBackTarget = target;this.returnCoordinator.cancel();this.pageBackToken++;
      if(refresh)this.boardNativeReads.refresh();this.syncFloatingTabsMotion();return;
    }
    this.retainedBoardContent = this.boardStore.boardDetail;
    this.nativeBackTarget = target;
    this.loadReturnTarget(target, ++this.pageBackToken);
  }

  private openBoardSection(): void {
    this.boardSectionToken++;this.boardSectionVisible = true;
    const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
    if(PIN_NATIVE_BOARD_READS_ENABLED && board?.nativeVersion !== undefined) {
      this.publishBoardReturn = '';this.nativeRootOnly = false;
      this.boardStore.presentationPage = board.pageKey;this.boardStore.presentationOnly = false;
      this.returnCoordinator.cancel();this.nativeBackTarget = board.pageKey;this.pageBackToken++;
      this.boardNativeReads.demand();return;
    }
    this.restorePublishBoard();
  }
  private closeBoardSection(): void {
    if(this.boardSectionSubmitting)return;
    this.boardSectionToken++;this.boardSectionVisible = false;this.nativeChildBackUntil = Date.now() + 300;
    if(PIN_NATIVE_BOARD_READS_ENABLED && this.boardStore.boardDetail?.nativeVersion !== undefined) {
      if(this.boardStore.boardDetail.flow?.phase === 'sectionSelect')return;
      this.boardNativeReads.handle('flow',JSON.stringify({action:'close'}));return;
    }
    this.restorePublishBoard();
  }
  private boardSectionReady(): boolean {
    const board = this.boardStore.boardDetail;
    if(PIN_NATIVE_BOARD_READS_ENABLED)return this.boardSectionVisible && this.authStatus === 'authenticated' && !this.businessSuspended && this.boardNativeReads.contentReady();
    let documentPage: string = '';
    try { documentPage = this.boardUrlFromAddress(this.sessionDocumentUrl()); } catch (_) { return false; }
    return this.boardSectionVisible && this.authStatus === 'authenticated' && !this.businessSuspended &&
      !!board && board.ready && board.session > 0 && !board.loading && !board.refreshing &&
      !this.boardStore.presentationOnly && board.pageKey === this.currentBoardUrl() &&
      documentPage === board.pageKey &&
      (board.editable || board.canContribute === true);
  }

  private async createBoardSection(name: string): Promise<string> {
    if(PIN_NATIVE_BOARD_READS_ENABLED) {
      if(!this.boardSectionReady())return this.uiText("pm_board_not_ready_close_this_panel_and_retry_337e96bd");
      if(this.boardSectionSubmitting)return this.uiText("pm_creation_in_progress_please_wait_242ae2da");
      const token: number = this.boardSectionToken;this.boardSectionSubmitting = true;
      try {return this.boardNativeReads.beginSectionSelection(name);}
      finally {if(token === this.boardSectionToken)this.boardSectionSubmitting = false;}
    }
    const board = this.boardStore.boardDetail;
    if (!board || !this.boardSectionReady()) {
      PinmonyRuntimeLog.info('BoardSectionTrace: submit blocked reason=context-not-ready');
      return this.uiText("pm_board_not_ready_close_this_panel_and_retry_337e96bd");
    }
    if (this.boardSectionSubmitting) return this.uiText("pm_creation_in_progress_please_wait_242ae2da");
    this.boardSectionSubmitting = true;
    PinmonyRuntimeLog.info('BoardSectionTrace: submit start');
    try {
      const raw: string = await this.runSessionScript(
        'window.PinmonyBoardApi.sectionCreate(' + board.session.toString() + ',' +
        JSON.stringify(board.pageKey) + ',' + JSON.stringify(name.trim()) + ')');
      let result: string = raw === 'pending' || raw === 'created' || raw === 'unavailable' || raw === 'uncertain' ? raw : this.webJsonText(raw);
      PinmonyRuntimeLog.info('BoardSectionTrace: submit accepted=' + (result === 'pending').toString());
      const deadline: number = Date.now() + 35000;
      while (result === 'pending' && Date.now() < deadline && this.boardSectionVisible &&
          this.authStatus === 'authenticated' && !this.businessSuspended &&
          this.boardStore.boardDetail?.session === board.session && this.currentBoardUrl() === board.pageKey) {
        await new Promise<void>((resolve) => { setTimeout(resolve, 250); });
        const reply: string = await this.runSessionScript('window.PinmonyBoardApi.sectionCreateRead(' +
          board.session.toString() + ',' + JSON.stringify(board.pageKey) + ')');
        result = reply === 'pending' || reply === 'created' || reply === 'uncertain' ? reply : this.webJsonText(reply);
      }
      PinmonyRuntimeLog.info('BoardSectionTrace: submit confirmed=' + (result === 'created').toString());
      if (result === 'created') return '';
      return result === 'unavailable' ? this.uiText("pm_cannot_create_a_section_on_this_board_close_this_panel_and_retry_6716f2be") :
        this.uiText("pm_creation_not_confirmed_close_and_refresh_to_check_before_submitt_99e27f05");
    } catch (_) { return this.uiText("pm_creation_not_confirmed_close_and_refresh_to_check_before_submitt_99e27f05"); }
    finally { this.boardSectionSubmitting = false; }
  }

  private async selectProfilePublish(id: string): Promise<void> {
    await this.publishController.select(id);
  }

  private prefetchHomePinDetails(first: number, last: number): void { return this.detailOpeningCoordinator.prefetchHomePinDetails(first, last); }

  private prefetchHomePinDetailsNow(first: number, last: number): void { return this.detailOpeningCoordinator.prefetchHomePinDetailsNow(first, last); }

  private isCurrentPublish(token: number, page: string): boolean {
    return this.publishController.isCurrent(token, page);
  }

  private pollPublish(token: number, page: string): void {
    this.publishController.poll(token, page);
  }

  private closePublishFlow(force: boolean = false): void { try {
    this.publishController.close(force);
   } finally { this.rootContextCoordinator.notify(); } }

  private publishFlowAction(action: string, value: string = '', secret: boolean = false): void {
    this.publishController.action(action, value, secret);
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
        const photo: PinmonyPublishPhoto = await readPublishPhoto(uri);
        if(PIN_NATIVE_SHARE_PUBLISH_ENABLED){if(!this.publishNativeFlow.photo(token,page,photo))throw new Error(this.uiText("pm_image_loading_incomplete_5dab7b4b"));continue;}
        for (let offset: number = 0; offset < photo.data.length; offset += 60000) {
          if (!this.isCurrentPublish(token, page)) return;
          const chunk: string = photo.data.slice(offset, offset + 60000);
          const result: string = await this.runSessionScript('window.PinmonyPublishApi.photoChunk(' + token.toString() + ',' +
            JSON.stringify(chunk) + ',' + JSON.stringify(photo.uri) + ',' + (offset + 60000 >= photo.data.length).toString() + ')');
          if (result !== 'true' && result !== '"true"') throw new Error(this.uiText("pm_image_transfer_incomplete_e1d6ffba"));
        }
      }
    } catch (error) {
      if (this.isCurrentPublish(token, page)) {
        this.profileStore.publishPicking = false;
        this.closePublishFlow();
        this.showMessage((error as Error).message || this.uiText("pm_image_selection_incomplete_please_retry_f48e5cbe"));
      }
    } finally { if (token === this.profileStore.publishFlowToken) this.profileStore.publishPicking = false; }
  }

  private async refreshProfilePublish(): Promise<void> {
    const profile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
    if (!profile || this.activeSheetKind !== 'publish') return;
    this.profileStore.publishLoading = true;
    this.profileStore.publishOptions = [];
    if(PIN_NATIVE_SHARE_PUBLISH_ENABLED){this.publishController.readMenuWhenReady(profile.profileUrl,Date.now() + 8000,this.profileStore.publishRequestToken);return;}
    try {
      await this.runSessionScript('window.PinmonyProfilePublishClose && ' +
        'window.PinmonyProfilePublishClose(' + profile.session.toString() + ',' +
        JSON.stringify(profile.profileUrl) + ')');
      const result: string = await this.runSessionScript('window.PinmonyProfilePublishDiscover && ' +
        'window.PinmonyProfilePublishDiscover(' + profile.session.toString() + ',' +
        JSON.stringify(profile.profileUrl) + ')');
      if (result === 'true' || result === '"true"') return;
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: publish options retry unavailable');
    }
    this.profileStore.publishLoading = false;
  }

  private finishProfilePull(): void { this.profileReadController.finishPull(); }

  private refreshProfile(pull: boolean = false): void { if(this.usesNativeProfileReads()){this.profileNativeReads.refresh(pull); return;} this.profileReadController.refresh(pull); }

  private loadMoreProfile(): void { if(this.usesNativeProfileReads()){this.profileNativeReads.more(); return;} this.profileReadController.loadMore(); }

  private async returnFromProfileWebFlow(): Promise<void> {
    await this.handleBack();
    if (this.profileStore.profile && this.currentProfileUrl() === this.profileStore.profile.profileUrl) {
      this.profileStore.profileWebFlow = false;
      this.runSessionScript('window.PinmonyProfileResume && window.PinmonyProfileResume()')
        .catch(() => PinmonyRuntimeLog.warn('Pinmony: could not refresh profile'));
    }
  }

  private clearDetail(preserveRead: boolean = false, localOnly: boolean = false): void {
    this.postPanelsController.pause();
    this.detailController.pause();
    this.detailReadController.pause();
    this.detailNativeAuxiliary.pause();
    this.detailNativeReads.pause();
    this.detailOperationsController.pause();
    this.sharePanelsController.pause();
    this.detailDocumentBindingService.reset();
    this.pinStore.detailPresentationOnly = false; this.pinStore.detailPreparing = false;
    this.detailRequestOwners.clear();
    this.detailJourney.close();
    this.detailImageStage.reset();
    this.detailImageLoadedUrl = ''; this.detailImageFailedUrl = '';
    this.sharedDetailRequestId = '';
    if (!preserveRead) { this.pinStore.detailPrefetch.pause(); this.detailReadNetwork.invalidate(); this.openingRelated = undefined; }
    this.closeImageLayer(localOnly);
    this.dismissPostSnack();
    this.pinStore.saveUndoPin = ''; this.pinStore.saveUndoId = '';
    this.pinStore.saveCancelToken++;
    this.pinStore.viewerSaveBusy = false;
    this.pinStore.detailMediaRetryToken++;
    this.pinStore.detailMediaRetryBusy = false;
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
    PinmonyRuntimeLog.info('DetailNavigation: root preparation superseded');
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
    try { actual = this.sessionDocumentUrl(); } catch (_) {}
    if (actual === url && this.pinStore.detailActionsReady) {
      this.authEpoch++; this.nativeNetwork.invalidate();
      this.pinStore.detailActionsReady = false;
      this.detailDocumentBindingService.clearBinding();
      if (!this.pinStore.detailOpeningPin) this.pinStore.detailPresentationOnly = true;
      this.detailJourney.mark('document.superseded.actions.invalidated');
    }
    PinmonyRuntimeLog.info('DetailNavigation: obsolete document ignored');
    return true;
  }

  private beginDetailOpening(pinUrl: string, returnUrl: string = '', returning: boolean = false): void {
    this.detailReturnJourney?.close();
    const clickAt: number = this.detailClickedAt > 0 && Date.now() - this.detailClickedAt < 20000 ? this.detailClickedAt : Date.now();
    this.detailClickedAt = 0;
    this.closeImageLayer();
    if (!this.pinIdentity(pinUrl)) return;
    this.clearRootTabGuard('detail-open');
    if (this.pinStore.detailOpeningPin === pinUrl) return;
    this.supersedeRootPreparationForDetail();
    const identity: string = this.pinIdentity(pinUrl);
    if (returnUrl && this.detailReadCache.getPin() !== identity) this.detailReadCache.clear();
    if (returnUrl) this.pinStore.rememberDetailOrigin(identity, returnUrl);
    else if (!this.pinStore.detailOrigin(identity)) {
      this.pinStore.rememberDetailOrigin(identity, this.pinStore.detailReturnUrl || PINTEREST_URL);
    }
    this.pinStore.detailReturnUrl = this.pinStore.detailOrigin(identity) || PINTEREST_URL;
    const card: PinmonyHomePin | undefined = this.homeStore.home?.pins.find((item: PinmonyHomePin): boolean => item.pinUrl === pinUrl);
    const relatedCard: PinmonyRelatedPin | undefined = this.pinStore.detail?.related.find((item: PinmonyRelatedPin): boolean => item.pinUrl === pinUrl);
    if (this.detailPrefetchTimer !== -1) this.pageTasks.cancelTimeout(this.detailPrefetchTimer);
    this.detailPrefetchTimer = -1;
    this.pinStore.detailPrefetch.cancelExcept(pinUrl);
    if (this.nativeBackTarget) {
      // Commit the visible native parent, then supersede its background return.
      this.pageHistory.visit(this.nativeBackTarget, 'load');
      this.pageHistory.cancelBack();
      this.nativeBackTarget = '';
      PinmonyRuntimeLog.info('PinmonyReturn: reopen superseded pending return');
    }
    // Record the native child immediately, before ArkWeb has a completed history entry.
    this.pageHistory.visit(pinUrl, 'push');
    this.clearDetail(true);
    this.pagePerformance.beginSecondary('detail', pinUrl);
    this.pinStore.detailOpeningPin = pinUrl;
    this.pinStore.detailPin = pinUrl;
    if(PIN_NATIVE_DETAIL_READS_ENABLED){this.nativeRootOnly = false;this.detailReturnedToRoot = false;this.navigationAddress = pinUrl;}
    this.restoreCachedDetail(pinUrl);
    const token: number = ++this.pinStore.detailOpeningToken;
    this.detailOpenedAt = clickAt;
    this.detailJourney.begin(token, clickAt);
    this.detailJourney.mark('opening.snapshot');
    this.detailCommentsMeasured = false;
    this.detailRelatedMeasured = false;
    PinmonyRuntimeLog.info('DetailTrace: open openId=' + token.toString());
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
    const resumed: boolean = returning && PIN_NATIVE_DETAIL_READS_ENABLED && this.detailNativeReads.resume(pinUrl, token) &&
      (!PIN_NATIVE_DETAIL_AUXILIARY_ENABLED || this.detailNativeAuxiliary.resume(pinUrl, token));
    if (PIN_DETAIL_API_ENABLED && PIN_NATIVE_NETWORK_ENABLED && !resumed) this.startOpeningDetailRead(pinUrl, token);
    if (PIN_DETAIL_API_ENABLED && PIN_NATIVE_NETWORK_ENABLED && !PIN_NATIVE_DETAIL_READS_ENABLED) this.probeDetailDocument(pinUrl, token, 0);
    this.coordinatorTasks.timeout(() => {
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
          this.pinStore.detailApiError = PinmonyI18n.message("pm_pin_loading_timed_out_please_retry_b940342e");
        }
      } else this.pinStore.detailOpeningPin = '';
    }, 12000);
  }

  private restoreCachedDetail(pinUrl: string): boolean {
    const identity: string = this.pinIdentity(pinUrl);
    if (!identity || this.pinIdentity(this.pinStore.detailImageFailedPin) === identity) return false;
    const cached = this.pinStore.detailCache.get(identity);
    if (!cached || (PIN_DETAIL_API_ENABLED && cached.detail.dataSource !== 'api')) {
      const prefetched: PinmonyDetailSnapshot | undefined = this.pinStore.detailPrefetch.get(pinUrl);
      if (!prefetched || !PIN_DETAIL_API_ENABLED) return false;
      this.pinStore.detailSession = 0;
      this.pinStore.detailPin = pinUrl;
      this.pinStore.detailScrollOffset = 0;
      this.pinStore.detailActionsReady = false;
      this.pinStore.detail = this.pinStore.confirmedSaves.apply(identity, prefetched);
      PinmonyRuntimeLog.info('DetailPrefetch: cache hit on open');
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

  private withDetailLike(detail: PinmonyDetailSnapshot, id: string,
    selected: boolean, countText: string): PinmonyDetailSnapshot {
    const actions: PinmonyDetailAction[] = detail.actions.map((item: PinmonyDetailAction): PinmonyDetailAction => {
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

  private updateSearchPinTitle(pinUrl: string, value: string): void { return this.businessResultsCoordinator.updateSearchPinTitle(pinUrl, value); }

  private updateHomePinTitle(pinUrl: string, value: string): void { return this.businessResultsCoordinator.updateHomePinTitle(pinUrl, value); }

  private updateDetail(value: string): void {
    try { this.detailReadController.updateDetail(value); this.detailNativeReads.apply();this.detailNativeAuxiliary?.apply();this.postNativeOperations?.apply(); } finally { this.photoMenuCoordinator.notify(); }
  }

  private closeImageLayer(localOnly: boolean = false): void {
    this.detailOperationsController.cancelVisual();
    this.pinStore.imageLayer = '';
    this.pinStore.visualToken++;
    if (localOnly || PIN_NATIVE_DETAIL_AUXILIARY_ENABLED) return;
    try {
      this.runSessionScript('window.PinmonyVisualSearchApi && window.PinmonyVisualSearchApi.close()')
        .catch((): void => { PinmonyRuntimeLog.warn('VisualSearch: close unavailable'); });
    } catch (_) { PinmonyRuntimeLog.warn('VisualSearch: close unavailable'); }
  }

  private async searchImage(crop: PinmonyImageCrop, append: boolean, first: boolean): Promise<void> {
    await this.detailOperationsController.searchImage(crop, append, first);
  }

  private async openImageRelated(id: string): Promise<void> {
    if(PIN_NATIVE_DETAIL_AUXILIARY_ENABLED && this.detailNativeAuxiliary.ready()) {
      const result: PinmonyVisualResult = this.pinStore.visualResult;
      const item: PinmonyRelatedPin | undefined = result.items.find((value: PinmonyRelatedPin): boolean => value.id === id);
      if(item && result.pin === this.pinStore.detailPin) {
        if(item.pinUrl === result.pin || !/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(item.pinUrl) || item.pinUrl.split('/')[2] !== result.pin.split('/')[2])return;
        this.beginDetailOpening(item.pinUrl,result.pin);return;
      }
    }
    if (this.rejectOfflineAction('related pin')) return;
    if (this.authStatus !== 'authenticated' || this.businessSuspended ||
        !this.pinStore.videoForeground || this.pinStore.detailPreparing) return;
    if (this.pinStore.detailPresentationOnly || this.pinStore.detailNativeReadsReady && this.detailNativeReads.owned()) {
      const nativeReadRoute: boolean = this.pinStore.detailNativeReadsReady;
      const parent: string = this.pinStore.detail?.pinUrl || '';
      const target: string = this.pinStore.detail?.related.find((item: PinmonyRelatedPin): boolean => item.id === id)?.pinUrl || '';
      // A retained card supplies a validated read-only route, not a live control ID.
      // Present the target card before its own confirmation; do not reload the parent.
      if (!/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(parent) ||
          !/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(target) ||
          parent.split('/')[2] !== target.split('/')[2] ||
          this.pinStore.detailPin !== parent || target === parent || this.pinStore.detailOpeningPin === target) return;
      this.beginDetailOpening(target, parent);
      this.detailJourney.mark(nativeReadRoute ? 'related.native.route.opened' : 'related.cached.route.opened');
      if(!PIN_NATIVE_DETAIL_READS_ENABLED){try { this.loadSessionDocument(target); }
      catch (_) { this.failImageRelatedNavigation(target); }}
      return;
    }
    if (this.authStatus !== 'authenticated' || !this.pinStore.detailActionsReady) return;
    const result: PinmonyVisualResult = this.pinStore.visualResult;
    const item: PinmonyRelatedPin | undefined = result.items.find((p: PinmonyRelatedPin): boolean => p.id === id);
    if (!item || result.pin !== this.pinStore.detail?.pinUrl) { this.openRelatedDetail(id); return; }
    if (!/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(item.pinUrl)) return;
    this.pinStore.detailReturnUrl = result.pin;
    this.beginDetailOpening(item.pinUrl, result.pin);
    try { if(!PIN_NATIVE_DETAIL_READS_ENABLED)this.loadSessionDocument(item.pinUrl); }
    catch (_) { this.failImageRelatedNavigation(item.pinUrl); }
  }

  private failImageRelatedNavigation(pin: string): void {
    if (this.pinStore.detailOpeningPin !== pin) return;
    this.pinStore.detailOpeningToken++;
    this.pinStore.detailOpeningPin = '';
    this.pinStore.detailPreparing = false;
    this.pinStore.detailActionsReady = false;
    this.pinStore.detailApiError = PinmonyI18n.message("pm_unable_to_open_related_pin_please_retry_473d0b1f");
    this.pinStore.detailApiRetryable = true;
    this.showMessage(PinmonyI18n.message("pm_unable_to_open_related_pin_please_retry_473d0b1f"));
  }

  private isCurrentWebDocument(address: string): boolean {
    if (!address) return false;
    try { return this.sessionDocumentUrl() === address; }
    catch (_) { return false; }
  }

  private async downloadViewerImage(): Promise<void> {
    if (this.rejectOfflineAction('photo download')) return;
    const pin: string = this.pinStore.detail?.pinUrl || '';
    if(PIN_NATIVE_DETAIL_AUXILIARY_ENABLED){
      const url: string = this.detailNativeAuxiliary.downloadUrl();
      if(url)this.systemActions.downloadImage(url);return;
    }
    if (!pin || this.pinStore.imageLayer !== 'zoom' || !this.pinStore.detailActionsReady) {
      PinmonyRuntimeLog.info('ActionGate: photo download blocked reason=detail-not-ready');
      return;
    }
    PinmonyRuntimeLog.info('PhotoDownload: requested');
    try {
      const value: string = await this.runSessionScript('JSON.stringify(window.PinmonyPostApi && window.PinmonyPostApi.downloadUrl(' + JSON.stringify(pin) + '))');
      if (this.pinStore.detail?.pinUrl !== pin || this.pinStore.imageLayer !== 'zoom') return;
      const url: string = JSON.parse(this.webJsonText(value)) as string;
      if (/^https:\/\/i\.pinimg\.com\//.test(url)) {
        this.controller.startDownload(url);
        PinmonyRuntimeLog.info('PhotoDownload: dispatched');
      } else {
        PinmonyRuntimeLog.warn('PhotoDownload: blocked reason=invalid-media-url');
        this.showMessage(PinmonyI18n.message("pm_this_image_is_currently_unavailable_for_download_755fd218"));
      }
    } catch (_) {
      PinmonyRuntimeLog.warn('PhotoDownload: failed reason=resolve-error');
      this.showMessage(PinmonyI18n.message("pm_download_could_not_start_please_retry_54407e7d"));
    }
  }

  private async saveViewerImage(): Promise<void> {
    if (this.rejectOfflineAction('save')) return;
    if(PIN_NATIVE_POST_OPERATIONS_ENABLED && this.pinStore.imageLayer === 'zoom' && !this.pinStore.viewerSaveBusy){await this.postNativeOperations.detailAction('save');return;}
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    const action: PinmonyDetailAction | undefined = detail?.actions.find((a: PinmonyDetailAction): boolean => a.kind === 'save');
    if (!detail || !action || !action.enabled || this.pinStore.imageLayer !== 'zoom' || !this.pinStore.detailActionsReady || this.pinStore.viewerSaveBusy) {
      PinmonyRuntimeLog.info('ActionGate: save blocked reason=detail-not-ready');
      return;
    }
    if (!action.selected) { this.performDetailAction(action.id, action.kind); return; }
    await this.cancelDetailSave(detail.pinUrl, true);
  }

  private async cancelDetailSave(pin: string, viewer: boolean = false): Promise<void> {
    if(PIN_NATIVE_POST_OPERATIONS_ENABLED){await this.postNativeOperations.cancelSave(pin);return;}await this.detailOperationsController.cancelDetailSave(pin,viewer);
  }

  private async ensureDetailActionContext(): Promise<boolean> {
    return this.detailController.ensureActionContext();
  }

  private async retryDetailMedia(): Promise<void> {
    await this.detailOperationsController.retryDetailMedia();
  }

  private ownsPostPin(pin: string): boolean {
    if(this.authStatus !== 'authenticated' || this.businessSuspended || !this.pinIdentity(pin))return false;
    if(this.homeStore.customHomeMenu?.pinUrl === pin)return true;
    if(this.nativeRootOnly || this.pinStore.detail?.pinUrl !== pin || this.pinStore.detailPin !== pin)return false;
    return !this.pinStore.detailOpeningPin || this.pinStore.detailOpeningPin === pin &&
      this.pinStore.detailNativeReadsReady && this.detailNativeReads.owned();
  }

  private async performDetailAction(id: string, kind: string): Promise<void> {
    await this.detailController.performAction(id, kind);
  }

  private async handlePostResult(value: string): Promise<void> {
    if(PIN_NATIVE_PIN_MENUS_ENABLED){try{const kind: string = (JSON.parse(value) as PinmonyPostResult).kind;if(['feedbackReady','feedbackUndone','feedbackUndoError','help','editOpen'].includes(kind))return;}catch (_){return;}}
    return this.businessResultsCoordinator.handlePostResult(value);
  }

  private webJsonText(value: string): string {
    // ArkWeb may encode a JavaScript string result as a JSON string once more.
    const decoded: string = JSON.parse(value) as string;
    return typeof decoded === 'string' ? decoded : value;
  }

  private async openApiComments(): Promise<void> { await this.postPanelsController.openComments(); }

  private dismissApiComments(): void { try { this.postPanelsController.dismiss('comments');  } finally { this.rootContextCoordinator.notify(); } }

  private commentApiAction(method: string, id: string = ''): void { this.postPanelsController.commentAction(method, id); }

  private async pickCommentImage(): Promise<string> {
    const token: number = this.pinStore.commentToken;
    if (this.activeSheetKind !== 'comments' || this.pinStore.commentResult.busy) return '';
    try {
      const selectedUri: string = await this.systemActions.pickImage();
      if (token !== this.pinStore.commentToken || this.activeSheetKind !== 'comments') return '';
      return selectedUri;
    } catch (_) { this.showMessage(PinmonyI18n.message("pm_image_selection_incomplete_216e6d3a")); return ''; }
  }

  private async writeComment(encoded: string): Promise<void> { await this.postPanelsController.writeComment(encoded); }

  private async prepareCommentWrite(encoded: string, pin: string, current: () => boolean): Promise<string> {
    let value: NativeCommentWrite;
    try { value = JSON.parse(encoded) as NativeCommentWrite; } catch (_) { return ''; }
    if (!value || !['create', 'reply', 'edit', 'delete', 'photo'].includes(value.action) ||
        typeof value.text !== 'string' || value.text.length > 5000 || typeof value.id !== 'string') return '';
    if (value.action === 'photo') {
      if (!value.imageUri || !/^file:\/\/media\//.test(value.imageUri)) return '';
      try {
        const started: string = await this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.commentPhotoBegin(' + JSON.stringify(pin) + ')');
        if (!current() || (started !== 'true' && started !== '"true"')) return '';
        const bytes: ArrayBuffer = await this.systemActions.readJpeg(value.imageUri);
        if (!current()) return '';
        value.signature = await this.nativeNetwork.uploadCommentImage(bytes, pin, (): PinmonyNetworkContext => {
          const context: PinmonyNetworkContext = this.nativeNetworkContext();
          context.authenticated = context.authenticated && current(); return context;
        });
        value.imageUri = undefined;
      } catch (_) {
        if (current()) await this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.commentPhotoFail(' + JSON.stringify(pin) + ')').catch(() => {});
        return '';
      }
    }
    return current() ? JSON.stringify(value) : '';
  }

  private async openApiBoards(requestedPin: string = ''): Promise<void> { if(PIN_NATIVE_POST_OPERATIONS_ENABLED){await this.postNativeOperations.openSave(requestedPin || (this.activeSheetKind === 'save' ? this.pinStore.saveResult.pin : '') || this.pinStore.detail?.pinUrl || '');return;}await this.postPanelsController.openBoards(requestedPin); }

  private saveApiAction(method: string, args: string = ''): void { if(PIN_NATIVE_POST_OPERATIONS_ENABLED){this.postNativeOperations.saveAction(method,args);return;}this.postPanelsController.saveAction(method,args); }

  private dismissApiBoards(): void { try { if(PIN_NATIVE_POST_OPERATIONS_ENABLED)this.postNativeOperations.dismiss('save');else this.postPanelsController.dismiss('save');  } finally { this.rootContextCoordinator.notify(); } }

  private async openEditPin(pin: string): Promise<void> { if(PIN_NATIVE_POST_OPERATIONS_ENABLED){await this.postNativeOperations.openEdit(pin);return;}await this.postPanelsController.openEdit(pin); }

  private editPinAction(method: string, args: string): void { if(PIN_NATIVE_POST_OPERATIONS_ENABLED){this.postNativeOperations.editAction(method,args);return;}this.postPanelsController.editAction(method,args); }

  private dismissEditPin(force: boolean = false): void { try { if(PIN_NATIVE_POST_OPERATIONS_ENABLED)this.postNativeOperations.dismiss('edit',force);else this.postPanelsController.dismiss('edit',force);  } finally { this.rootContextCoordinator.notify(); } }

  private releasePostSnack(token: number, reason: string): boolean {
    if (token !== this.postSnackToken || !this.postSnack) return false;
    // HDS owns native close-button/back dismissal; those callbacks only release our owner.
    this.postSnackToken++;
    this.postSnack = undefined;
    this.postSnackExpiresAt = 0;
    PinmonyRuntimeLog.info('PostSnack: released snackSeq=' + token + ' reason=' + reason);
    return true;
  }

  private dismissPostSnack(reason: string = 'cleanup'): void {
    const snack: HdsSnackBar | undefined = this.postSnack;
    const expiresAt: number = this.postSnackExpiresAt;
    const token: number = this.postSnackToken;
    if (!snack) return;
    const expired: boolean = Date.now() >= expiresAt;
    if (!this.releasePostSnack(token, expired ? 'expired' : reason) || expired) return;
    PinmonyRuntimeLog.info('AsyncAction: stage=snackbar-dismiss');
    try { snack.dismiss(); }
    catch (_) { PinmonyRuntimeLog.warn('PostSnack: dismiss-threw snackSeq=' + token); }
  }

  private preparePostSnack(duration: number): HdsSnackBar {
    this.dismissPostSnack('replace');
    const snack: HdsSnackBar = new HdsSnackBar(this.getUIContext());
    this.postSnack = snack;
    this.postSnackToken++;
    this.postSnackExpiresAt = Date.now() + duration;
    PinmonyRuntimeLog.info('PostSnack: prepared snackSeq=' + this.postSnackToken + ' durationMs=' + duration);
    return snack;
  }

  private isCurrentPostSnack(token: number): boolean {
    if (token !== this.postSnackToken || !this.postSnack) return false;
    if (Date.now() >= this.postSnackExpiresAt) {
      this.dismissPostSnack();
      return false;
    }
    return true;
  }

  private handlePostSnackClose(token: number): void {
    if (this.isCurrentPostSnack(token)) this.releasePostSnack(token, 'close-button');
  }

  private handlePostSnackBack(token: number): void {
    if (!this.isCurrentPostSnack(token)) return;
    PinmonyRuntimeLog.info('AsyncAction: stage=snackbar-back');
    PinmonyRuntimeLog.info('PinmonyReturn: snackbar system back snackSeq=' + token);
    if (this.releasePostSnack(token, 'system-back')) this.onBackPress();
  }

  private showShareLinkSnack(): void {
    if (!PinmonyI18n.isText(this.pinStore.shareError, "分享链接尚未就绪，请重试")) return;
    const session: number = this.pinStore.shareSession;
    const pin: string = this.pinStore.sharePin;
    const key: string = session.toString() + ':' + pin + ':' + this.pinStore.shareError;
    if (this.pinStore.shareSnackKey === key) return;
    this.pinStore.shareSnackKey = key;
    const snack: HdsSnackBar = this.preparePostSnack(4000);
    const token: number = this.postSnackToken;
    snack.show({ icon: $r('sys.symbol.exclamationmark_circle'), iconType: SnackBarIconType.NORMAL }, { title: PinmonyI18n.render(this.pinStore.shareError, this.uiLanguage) }, {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: this.uiText("pm_retry_b8784c8d"),
      contentAccessibilityText: this.uiText("pm_reload_share_link_6a0a897d"), closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onContentClick: () => {
        if (!this.isCurrentPostSnack(token) || session !== this.pinStore.shareSession || pin !== this.pinStore.sharePin ||
            this.activeSheetKind !== 'share' || !this.showNativeSheet) return;
        this.dismissPostSnack();
        this.refreshShareSheet();
      },
      onCloseButtonClick: () => this.handlePostSnackClose(token)
    }, { duration: 4000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showShareFeedbackSnack(): void {
    if (!this.pinStore.shareFeedback || PinmonyI18n.isText(this.pinStore.shareFeedback, "正在加载联系人…") ||
        PinmonyI18n.isText(this.pinStore.shareFeedback, "正在处理…") || PinmonyI18n.isText(this.pinStore.shareFeedback, "没有可用的联系人")) {
      this.pinStore.shareFeedbackSnackKey = '';
      return;
    }
    const key: string = this.pinStore.shareSession.toString() + ':' + this.pinStore.sharePin + ':feedback:' + this.pinStore.shareFeedback;
    if (this.pinStore.shareFeedbackSnackKey === key) return;
    this.pinStore.shareFeedbackSnackKey = key;
    const snack: HdsSnackBar = this.preparePostSnack(5000);
    const token: number = this.postSnackToken;
    snack.show({ icon: $r('sys.symbol.info_circle'), iconType: SnackBarIconType.NORMAL }, { title: PinmonyI18n.render(this.pinStore.shareFeedback, this.uiLanguage) }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onCloseButtonClick: () => this.handlePostSnackClose(token)
    }, { duration: 5000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showUndoSnack(message: string, pin: string, undo: () => void): void {
    PinmonyRuntimeLog.info('PinmonyReturn: undo snackbar shown');
    const snack: HdsSnackBar = this.preparePostSnack(8000);
    const token: number = this.postSnackToken;
    snack.show({ icon: PinmonyI18n.isText(message, 'pm_undo_incomplete_please_retry_e69779de') ||
      PinmonyI18n.isText(message, 'pm_undo_failed_please_retry_ea519ad9') ?
      $r('sys.symbol.exclamationmark_circle') : $r('sys.symbol.checkmark_circle'), iconType: SnackBarIconType.NORMAL }, { title: PinmonyI18n.render(message, this.uiLanguage) }, {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: this.uiText("pm_undo_926a50b9"),
      contentAccessibilityText: this.uiText("pm_undo_this_action_fab003cc"), closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onContentClick: () => {
        if (!this.isCurrentPostSnack(token) || !(this.pinStore.saveUndoPin === pin && this.postNativeOperations?.owns(pin)) && this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
        PinmonyRuntimeLog.info('PinmonyReturn: snackbar undo clicked');
        this.dismissPostSnack(); undo();
      }, onCloseButtonClick: () => {
        PinmonyRuntimeLog.info('PinmonyReturn: snackbar close clicked');
        this.handlePostSnackClose(token);
      }
    }, { duration: 8000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showInboxUndoSnack(newsId: string): void {
    PinmonyRuntimeLog.info('PinmonyInbox: update hidden, undo snackbar shown');
    const snack: HdsSnackBar = this.preparePostSnack(8000);
    const token: number = this.postSnackToken;
    snack.show({ icon: $r('sys.symbol.trash'), iconType: SnackBarIconType.NORMAL }, { title: this.uiText("pm_update_deleted_509d0754") }, {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: this.uiText("pm_undo_926a50b9"),
      contentAccessibilityText: this.uiText("pm_undo_update_deletion_98448231"), closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onContentClick: () => {
        if(PIN_NATIVE_INBOX_UPDATES_ENABLED){if(this.isCurrentPostSnack(token)){this.dismissPostSnack();this.inboxMenuNative.undoNews(newsId).then((error: string | undefined): void => { if(error === undefined)return;this.inboxUpdatesNativeReads.demand();if(error)this.showMessage(error);else this.showInboxRestoredSnack(); });}return;}
        if (!this.isCurrentPostSnack(token) || !this.inboxStore.inboxFlow ||
            this.inboxStore.inboxFlow.newsId !== newsId || !this.inboxStore.inboxFlow.newsHidden) return;
        PinmonyRuntimeLog.info('PinmonyInbox: update undo clicked');
        this.dismissPostSnack();
        this.inboxFlowAction('undoNews');
      },
      onCloseButtonClick: () => this.handlePostSnackClose(token)
    }, { duration: 8000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showInboxRestoredSnack(): void {
    const snack: HdsSnackBar = this.preparePostSnack(4000);
    const token: number = this.postSnackToken;
    snack.show({ icon: $r('sys.symbol.checkmark_circle'), iconType: SnackBarIconType.NORMAL }, { title: this.uiText("pm_update_deletion_undone_e4e5cba0") }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onCloseButtonClick: () => this.handlePostSnackClose(token)
    }, { duration: 4000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private showInboxUnsubscribedSnack(): void {
    const snack: HdsSnackBar = this.preparePostSnack(8000);
    const token: number = this.postSnackToken;
    snack.show({ icon: $r('sys.symbol.bell_slash'), iconType: SnackBarIconType.NORMAL }, { title: this.uiText("pm_you_will_no_longer_receive_notifications_about_this_pin_75459ce5") }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onCloseButtonClick: () => this.handlePostSnackClose(token)
    }, { duration: 8000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  private async undoSavedPin(): Promise<void> {
    if(PIN_NATIVE_POST_OPERATIONS_ENABLED){const pin: string = this.pinStore.saveUndoPin;if(pin && this.pinStore.saveUndoId && this.postNativeOperations.owns(pin))await this.postNativeOperations.cancelSave(pin);return;}
    const pin: string = this.pinStore.saveUndoPin;
    const copyId: string = this.pinStore.saveUndoId;
    if (!pin || !copyId || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
    try {
      const result: string = await this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.saveUndo(' +
        JSON.stringify(pin) + ',' + JSON.stringify(copyId) + ')');
      if (result !== 'true' && result !== '"true"') this.showUndoSnack(this.uiText("pm_undo_incomplete_please_retry_e69779de"), pin, () => this.undoSavedPin());
    } catch (_) { this.showUndoSnack(this.uiText("pm_undo_failed_please_retry_ea519ad9"), pin, () => this.undoSavedPin()); }
  }

  private async undoMoreFeedback(): Promise<void> {
    if(PIN_NATIVE_PIN_MENUS_ENABLED){await this.pinMenuNative.undoFeedback();return;}
    const pin: string = this.pinStore.feedbackUndoPin;
    if (!pin || this.pinStore.feedbackUndoBusy || this.pinIdentity(pin) !== this.pinIdentity(this.currentPinUrl())) return;
    this.pinStore.feedbackUndoBusy = true;
    try {
      const result: string = await this.runSessionScript('window.PinmonyPostApi && window.PinmonyPostApi.feedbackUndo(' +
        JSON.stringify(pin) + ',' + this.pinStore.feedbackUndoSession.toString() + ')');
      if (result !== 'true' && result !== '"true"') {
        this.pinStore.feedbackUndoBusy = false;
        this.showUndoSnack(this.uiText("pm_undo_incomplete_please_retry_e69779de"), pin, () => this.undoMoreFeedback());
      }
    } catch (_) {
      this.pinStore.feedbackUndoBusy = false;
      this.showUndoSnack(this.uiText("pm_undo_failed_please_retry_ea519ad9"), pin, () => this.undoMoreFeedback());
    }
  }

  private async openRelatedDetail(id: string): Promise<void> {
    if (this.rejectOfflineAction('related pin')) return;
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || !this.pinStore.detailActionsReady || !id ||
        this.pinIdentity(detail.pinUrl) !== this.pinIdentity(this.currentPinUrl())) return;
    this.pinStore.detailReturnUrl = detail.pinUrl;
    const related: PinmonyRelatedPin | undefined = detail.related.find((pin: PinmonyRelatedPin): boolean => pin.id === id);
    const targetPinUrl: string = related?.pinUrl || '';
    if(PIN_NATIVE_DETAIL_READS_ENABLED && related){this.beginDetailOpening(targetPinUrl,detail.pinUrl);return;}
    if (related) this.beginDetailOpening(targetPinUrl, detail.pinUrl);
    else this.pinStore.detail = undefined;
    try {
      const result: string = await this.runSessionScript('window.PinmonyDetailRelated && ' +
        'window.PinmonyDetailRelated(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' +
        JSON.stringify(id) + ')');
      if (result !== 'true' && result !== '"true"') {
        // The old document may reject after the native opening state has
        // replaced the visible detail. Keep the new Pin opening state alive;
        // restoring `detail` here would paint the previous Pin over it.
        if (targetPinUrl && this.pinStore.detailOpeningPin === targetPinUrl) {
          this.loadSessionDocument(targetPinUrl);
        } else {
          this.showMessage(PinmonyI18n.message("pm_unable_to_open_related_pin_9d577ebe"));
        }
      }
    } catch (error) {
      if (targetPinUrl && this.pinStore.detailOpeningPin === targetPinUrl) {
        try {
          this.loadSessionDocument(targetPinUrl);
        } catch (_) {
          this.pinStore.detailOpeningPin = '';
          this.showMessage(PinmonyI18n.message("pm_unable_to_open_related_pin_9d577ebe"));
        }
      } else {
        this.showMessage(PinmonyI18n.message("pm_unable_to_open_related_pin_9d577ebe"));
      }
    }
  }

  private loadMoreRelated(): void {
    if (PIN_NATIVE_DETAIL_READS_ENABLED && !this.detailNativeReads.owned() && this.pinStore.detail && !this.businessSuspended && !this.activeSheetKind) { this.retryDetailApi(); return; }
    if (this.detailNativeReads.owned()) { this.detailNativeReads.loadMore(); return; }
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail || !this.pinStore.detailActionsReady ||
        (!PIN_DETAIL_API_ENABLED && !detail.related.length)) return;
    this.runSessionScript('window.PinmonyDetailLoadMore && ' +
      'window.PinmonyDetailLoadMore(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ')')
      .catch(() => PinmonyRuntimeLog.warn('Pinmony: related Pin loading unavailable'));
  }

  private retryDetailPreview(): void {
    if (PIN_NATIVE_DETAIL_READS_ENABLED && !this.detailNativeReads.owned() && this.pinStore.detail && !this.businessSuspended && !this.activeSheetKind) { this.retryDetailApi(); return; }
    if (this.detailNativeReads.owned()) { if (!this.detailNativeReads.retryPreview()) this.retryDetailApi(); return; }
    if (!this.pinStore.detailActionsReady || !this.pinStore.detail?.commentError ||
        this.pinStore.detail.commentLoading || this.nativeBackTarget ||
        this.pinIdentity(this.currentPinUrl()) !== this.pinIdentity(this.pinStore.detailPin)) return;
    this.detailCommentsMeasured = false;
    this.runSessionScript('window.PinmonyDetailPreviewRetry && window.PinmonyDetailPreviewRetry(' +
      this.pinStore.detailSession.toString() + ',' + JSON.stringify(this.pinStore.detailPin) + ')')
      .catch(() => PinmonyRuntimeLog.warn('DetailTrace: comments retry unavailable'));
  }

  private syncDetailImageStage(): void {
    this.detailImageStage.sync(this.detailImageLoadedUrl, this.detailImageFailedUrl);
  }

  private detailRenderIdentity(): string {
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail) return '';
    return detail.pinUrl + '|' + detail.imageUrl + '|' + detail.kind + '|' + detail.session.toString() +
      '|' + this.pinStore.detailOpeningToken.toString();
  }

  // Keep the detail page root mounted while one Pin moves from cached to
  // current content. Volatile snapshot/session fields belong to the page
  // props and image nodes, not to the root ForEach key.
  private detailRootIdentity(): string {
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    return this.pinIdentity(detail?.pinUrl || this.pinStore.detailOpeningPin);
  }

  private signalDetailImageStage(outcome: string): void { this.detailImageStage.signal(outcome); }

  private retryDetailApi(): void {
    if (this.pinStore.detailPresentationOnly) { this.ensureDetailActionContext(); return; }
    this.detailReadCache.clear();
    this.detailImageStage.reset();
    this.pinStore.detailApiError = '';
    this.pinStore.detailImageFailedPin = '';
    const pin: string = this.pinStore.detailPin || this.pinStore.detailOpeningPin;
    const restart: boolean = PIN_NATIVE_DETAIL_READS_ENABLED || !this.pinStore.detailActionsReady;
    if (restart && this.pinIdentity(pin) && PIN_NATIVE_NETWORK_ENABLED) {
      this.sharedDetailRequestId = '';
      this.pinStore.detailPrefetch.pause(); this.detailReadNetwork.invalidate(); this.openingRelated = undefined;
      this.pinStore.detailOpeningPin = pin;
      this.startOpeningDetailRead(pin, ++this.pinStore.detailOpeningToken);
    }
    this.runSessionScript('window.PinmonyDetailApiRetry && window.PinmonyDetailApiRetry(' +
      this.pinStore.detailSession.toString() + ',' + JSON.stringify(this.pinStore.detailPin) + ',' + restart.toString() + ');' +
      'window.PinmonyDetailRefresh && window.PinmonyDetailRefresh()')
      .catch(() => { this.pinStore.detailApiError = PinmonyI18n.message("pm_pin_service_unavailable_reopen_this_pin_adbeebe1"); });
  }

  private async returnFromDetailWebFlow(): Promise<void> {
    const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
    if (!detail) {
      this.pinStore.detailWebFlow = false;
      this.backFromDetail();
      return;
    }
    try {
      await this.runSessionScript('window.PinmonyHandleBack ? window.PinmonyHandleBack() : false');
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: could not close detail web panel');
    }
    if (this.pinIdentity(this.currentPinUrl()) === this.pinIdentity(detail.pinUrl)) {
      this.pinStore.detailWebFlow = false;
      this.runSessionScript('window.PinmonyDetailResume && window.PinmonyDetailResume()')
        .catch(() => PinmonyRuntimeLog.warn('Pinmony: could not refresh detail'));
    } else {
      this.backFromDetail();
    }
  }

  private currentPinUrl(): string {
    if(PIN_NATIVE_PROFILE_READS_ENABLED && this.nativeBackTarget && !this.extractPinUrl(this.nativeBackTarget))return '';
    if(PIN_NATIVE_DETAIL_READS_ENABLED && this.detailNativeReads.owned())return this.pinStore.detailPin || this.pinStore.detailOpeningPin;
    if (this.pinStore.detailPresentationOnly) return '';
    if (this.nativeRootOnly || this.detailReturnedToRoot) return '';
    try {
      return this.extractPinUrl(this.sessionDocumentUrl());
    } catch (error) {
      return '';
    }
  }

  private extractPinUrl(value: string): string { return PinmonyRouteParser.extractPinUrl(value); }

  private shareFromTarget(targetUrl: string, pinUrl: string): void {
    const url: string = this.extractPinUrl(targetUrl) || this.extractPinUrl(pinUrl) ||
      this.pinStore.sharePin || this.currentPinUrl();
    if (!url) {
      this.showMessage(PinmonyI18n.message("pm_unable_to_get_this_pin_s_link_e2a9f1db"));
      return;
    }
    this.sharePinUrl(url);
  }

  private detailSystemShareClosed: (() => void) | undefined = undefined;

  private async dismissPhotoMenuAfterAction(): Promise<void> {
    if (this.detailSystemShareClosed || !this.homeStore.customHomeMenu || this.activeSheetKind !== 'share') return;
    const menu: PinmonyHomeMenuState = this.homeStore.customHomeMenu;
    await new Promise<void>((resolve) => {
      let timer: number = -1;
      const finish = (): void => {
        if (this.detailSystemShareClosed !== finish) return;
        this.detailSystemShareClosed = undefined;
        if (timer >= 0) clearTimeout(timer);
        if (this.homeStore.customHomeMenu === menu && !this.showNativeSheet) this.dismissShareSheet();
        PinmonyRuntimeLog.info('SheetTrace: event=photo-action-closed');
        resolve();
      };
      this.detailSystemShareClosed = finish;
      timer = setTimeout(finish, 2000);
      // Keep the current builder and FIT_CONTENT height until the mask exits.
      this.showNativeSheet = false;
    });
  }

  private notifyDetailSystemShareClosed(): void {
    if (!this.showNativeSheet && this.detailSystemShareClosed) this.detailSystemShareClosed();
  }

  private async shareDetailPinAfterMenu(pin: string, boardPage: string = '', sharePanel: boolean = false): Promise<void> {
    if (this.detailSystemShareClosed || !this.showNativeSheet || this.activeSheetKind !== (boardPage || sharePanel ? 'share' : 'more')) return;
    const generation: number = this.nativeBusinessSessionContext().generation;
    const sourceRoute: string = this.nativeDisplayAddress();
    const menuToken: number = this.homeStore.customHomeMenuToken;
    PinmonyRuntimeLog.info('SystemShareTrace: phase=menu-closing');
    const closed: boolean = await new Promise<boolean>((resolve) => {
      let timer: number = -1;
      const finish = (disappeared: boolean): void => {
        if (this.detailSystemShareClosed !== onClosed) return;
        this.detailSystemShareClosed = undefined;
        if (timer >= 0) clearTimeout(timer);
        if (boardPage || sharePanel) this.dismissShareSheet();
        else this.dismissMoreSheet();
        PinmonyRuntimeLog.info('SystemShareTrace: phase=' + (disappeared ? 'menu-closed' : 'menu-close-timeout'));
        resolve(disappeared);
      };
      const onClosed = (): void => finish(true);
      this.detailSystemShareClosed = onClosed;
      timer = setTimeout(() => finish(false), 2000);
      // Preserve the Sheet builder, title and height throughout its exit animation.
      this.showNativeSheet = false;
    });
    if (!closed) return;
    await new Promise<void>((resolve) => {
      this.getUIContext().postFrameCallback({ onFrame: (): void => {}, onIdle: (): void => resolve() });
    });
    PinmonyRuntimeLog.info('SystemShareTrace: phase=frame-ready');
    if (closed && this.authStatus === 'authenticated' && !this.businessSuspended &&
        this.nativeBusinessSessionContext().generation === generation &&
        (boardPage ? this.nativeDisplayAddress() === sourceRoute && this.homeStore.customHomeMenuToken === menuToken + 1 : this.currentPinUrl() === pin) &&
        !this.showNativeSheet && !this.activeSheetKind) await this.sharePinUrl(pin);
  }

  private async sharePinUrl(url: string, title: string = 'Pinterest Pin'): Promise<void> {
    try {
      PinmonyRuntimeLog.info('SystemShareTrace: phase=present-requested');
      await this.systemActions.shareLink(url, title);
      PinmonyRuntimeLog.info('SystemShareTrace: phase=present-returned');
    } catch (error) {
      PinmonyRuntimeLog.error('Pinmony: system share failed');
      this.showMessage(PinmonyI18n.message("pm_unable_to_open_share_panel_43eea06a"));
    }
  }

  private isExternalShareTarget(url: string): boolean { return PinmonyRouteParser.isExternalShareTarget(url); }

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

  private cancelAccountSettings(): void { this.settingsController.cancel(); }
  private async readNotifications(): Promise<void> { await this.settingsController.readNotifications(); }

  private async logoutAccount(): Promise<void> {
    if (!PIN_LOGOUT_API_ENABLED || !PIN_NATIVE_NETWORK_ENABLED || this.authStatus !== 'authenticated' ||
        !this.profileSettingsVisible || this.settingsStore.screen !== 'root' || this.settingsStore.busy || this.settingsStore.loading) return;
    const business: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();
    if(!business.authenticated || !business.accountId)return;
    const account: string = business.accountId + ':' + business.generation.toString() + ':' + business.origin;
    if(this.logoutUnknownAccount === account){this.settingsStore.error = PinmonyI18n.message("pm_logout_not_confirmed_wait_for_session_verification_it_will_not_b_cfc74ac5");return;}
    const context: PinmonyNetworkContext = {authenticated:true,epoch:business.generation,page:business.origin + '/',userAgent:business.userAgent};
    const origin: RegExpMatchArray | null = context.page.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
    if (!origin) return;
    const token: number = ++this.settingsStore.token;
    this.settingsStore.busy = true;
    this.settingsStore.error = '';
    PinmonyRuntimeLog.info('SessionLogout: request started');
    this.logoutUnknownAccount = account;
    try {
      const job: PinmonyNetworkJob = { id: 'native_session_logout_' + token.toString() + '_' + Date.now().toString(),
        epoch: context.epoch, page: context.page, url: origin[0] + '/resource/UserSessionResource/delete/',
        method: 'POST', body: logoutRequestBody(), headers: { 'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/settings.js' } };
      const reply: PinmonyNetworkReply = await this.nativeNetwork.request(job, (): PinmonyNetworkContext => {const current: PinmonyBusinessSessionContext = this.nativeBusinessSessionContext();return {authenticated:current.authenticated && current.accountId === business.accountId && current.generation === business.generation && current.origin === business.origin && this.profileSettingsVisible && token === this.settingsStore.token,epoch:context.epoch,page:context.page,userAgent:current.userAgent};});
      if (token !== this.settingsStore.token || this.authStatus !== 'authenticated' ||
          this.nativeBusinessSessionContext().generation !== business.generation || this.nativeBusinessSessionContext().accountId !== business.accountId) return;
      if (reply.error || !logoutResponseSucceeded(reply.status, reply.body)) {
        if(['request-unavailable','background'].includes(reply.error))this.logoutUnknownAccount = '';
        this.settingsStore.error = this.logoutUnknownAccount ? this.uiText("pm_logout_not_confirmed_wait_for_session_verification_it_will_not_b_cfc74ac5") : this.uiText("pm_logout_was_not_sent_please_retry_6bd93118");
        PinmonyRuntimeLog.warn('SessionLogout: result not confirmed');
        return;
      }
      this.logoutUnknownAccount = '';
      PinmonyRuntimeLog.info('SessionLogout: server confirmed');
      this.resetAuthenticatedContent();
      this.authEpoch++;
      this.authStatus = 'unauthenticated';
      this.logoutAwaitingLogin = true;
      this.loginRedirectEpoch = this.authEpoch;
      this.navigationAddress = PINTEREST_LOGIN_URL;
      this.lastPageUrl = PINTEREST_LOGIN_URL;
      this.loadFailed = false;
      this.failureDetails = '';
      if(this.nativeLoginEnabled)this.openNativeLogin();else this.loadSessionDocument(PINTEREST_LOGIN_URL);
    } catch (_) {
      if (this.authStatus === 'unauthenticated') {
        this.authStatus = 'error';
        this.failureDetails = PinmonyI18n.message("pm_logged_out_but_the_sign_in_page_could_not_load_please_retry_93441c6b");
      } else if (token === this.settingsStore.token) this.settingsStore.error = PinmonyI18n.message("pm_logout_not_confirmed_please_retry_later_ec7c6e06");
      PinmonyRuntimeLog.warn('SessionLogout: operation unavailable');
    } finally {
      if (token === this.settingsStore.token) this.settingsStore.busy = false;
    }
  }

  private startOpeningDetailRead(pinUrl: string, token: number): void { return this.detailOpeningCoordinator.startOpeningDetailRead(pinUrl, token); }

  private async requestAccountSettings(action: string, value: string): Promise<void> {
    if (action === 'logout') { await this.logoutAccount(); return; }
    await this.settingsController.request(action, value);
  }

  private closeProfileSettings(): void { try {
    this.nativeChildBackUntil = Date.now() + 220;
    if (this.settingsStore.back()) { if (!this.settingsStore.busy) this.cancelAccountSettings(); return; }
    this.cancelAccountSettings(); this.settingsStore.reset(true);
    this.nativeChildBackUntil = Date.now() + 220;
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.profileSettingsVisible = false; });
   } finally { this.rootContextCoordinator.notify(); } }

  private rootExitBackAt: number = 0;
  private rootExitBackHandled: boolean = false;
  onBackPress(): boolean {
    this.rootExitBackHandled = false;
    const handled: boolean = this.navigationCoordinator.onBackPress();
    if (!this.rootExitBackHandled) this.rootExitBackAt = 0;
    return handled;
  }
  private handleRootExitBack(): boolean {
    this.rootExitBackHandled = true;
    const now: number = Date.now();
    if (this.rootExitBackAt > 0 && now - this.rootExitBackAt <= 2000 && now >= this.rootExitBackAt) {
      this.rootExitBackAt = 0;
      try {
        const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        context.terminateSelf().catch(() => PinmonyRuntimeLog.warn('RootExit: terminate-unavailable'));
      } catch (_) { PinmonyRuntimeLog.warn('RootExit: context-unavailable'); }
    } else {
      this.rootExitBackAt = now;
      this.showMessage(PinmonyI18n.message('pm_press_back_again_to_exit'));
    }
    return true;
  }

  @Builder
  private buildShareSheet() {
    PinmonyShareSheet({ pinStore: this.pinStore, onAction: (id: string) => this.performShareAction(id), onSearch: (value: string) => this.searchShareContacts(value), onRetry: () => this.refreshShareSheet(), hasCopyLink: () => this.hasCarouselCopyLink(), isCopyLink: (label: string) => this.isCopyLinkAction(label), onReady: () => { this.pagePerformance.markSecondary('share', this.pinStore.shareSession.toString(), 'component-ready'); this.scheduleShareWebOpen(); } })
  }

  @Builder
  private buildMoreSheet() {
    PinmonyMoreSheet({ pinStore: this.pinStore, onAction: (id: string) => this.performMoreAction(id),
      onRetry: () => this.refreshMoreSheet() })
  }

  @Builder
  private buildSearchFilterSheet() {
    PinmonySearchFilterSheet({ searchStore: this.searchStore, onSelect: (id: string) => this.selectSearchFilter(id), onRetry: () => this.retrySearchFilters() })
  }

  private nativeModalLabel(): string {
    return this.activeSheetKind === 'publish' ? (this.publishBoardReturn ? (this.boardStore.boardDetail?.flow?.phase === 'section' ? this.uiText("pm_add_to_section_d7aed82c") : this.uiText("pm_add_pins_or_sections_2274f06f")) : PinmonyI18n.render(this.profileStore.publishTitle, this.uiLanguage) || this.uiText("pm_add_to_profile_e076cb80")) :
        this.activeSheetKind === 'edit' ? (this.pinStore.editResult.phase === 'boards' ? (this.pinStore.saveCreating ? this.uiText("pm_create_board_513babc9") : this.uiText("pm_save_to_board_0233a416")) : this.uiText("pm_edit_pin_f9119bcf")) : this.activeSheetKind === 'comments' ? this.uiText("pm_what_do_you_think_e8fb167b") : this.activeSheetKind === 'save' ?
          (this.pinStore.saveCreating ? this.uiText("pm_create_board_513babc9") : this.uiText("pm_save_to_board_0233a416")) : this.activeSheetKind === 'more' ? this.uiText("pm_options_bb7486f4") :
          this.activeSheetKind === 'searchFilter' ? this.uiText("pm_filters_8d35790c") : PinmonyI18n.render(this.pinStore.shareTitle, this.uiLanguage);
  }

  private closeNativeModal(): void {
    if (this.detailSystemShareClosed) { this.showNativeSheet = false; return; }
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
    else if (this.activeSheetKind === 'profileMenu') this.dismissProfileMenu();
  }

  @Builder
  private buildNativeSheet() {
    if (this.homeStore.customHomeMenu && this.activeSheetKind === 'share') {
      if (this.homeStore.inboxMenuPending) {
        Column({ space: 12 }) {
          if (this.homeStore.customHomeMenu.error) {
            Text(PinmonyI18n.render(this.homeStore.customHomeMenu.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
          } else {
            LoadingProgress().width(28).height(28)
            Text(this.uiText("pm_loading_21bd738e")).fontColor($r('app.color.secondary_text'))
          }
        }.width('100%').padding(24)
      } else {
      PinmonyHomeMenuSheet({ menu: this.homeStore.customHomeMenu,
        onAction: (id: string) => this.performCustomHomeAction(id),
        onRetry: () => {
          const menu: PinmonyHomeMenuState | undefined = this.homeStore.customHomeMenu;
          if (menu && /取消收藏|收藏校验/.test(menu.error)) return;
          if (menu && this.isCurrentMorePin(menu.pinUrl)) this.openCustomHomeMenu(menu.pinUrl, this.homeStore.homeMenuPage);
        } })
      }
    } else if (this.activeSheetKind === 'edit') {
      PinmonyEditPinSheet({ result: this.pinStore.editResult,
        onAction: (method: string, args: string) => this.editPinAction(method, args),
        onRetry: () => this.openEditPin(this.pinStore.editResult.pin), onClose: () => this.dismissEditPin(),
        onCreatingChange: (creating: boolean) => { this.pinStore.saveCreating = creating; } })
    } else if (this.activeSheetKind === 'comments') {
      PinmonyCommentsSheet({ onUser: (url: string) => this.openUserProfile(url), result: this.pinStore.commentResult, onRetry: () => this.openApiComments(),
        onMore: () => this.commentApiAction('commentsMore'),
        onReplies: (id: string) => this.commentApiAction('commentReplies', id),
        onTranslate: PIN_NATIVE_DETAIL_READS_ENABLED ? (id: string) => this.commentApiAction('commentTranslate', id) : undefined,
        onWrite: (value: string) => this.writeComment(value), onPickImage: () => this.pickCommentImage(),
        onClose: () => this.dismissApiComments(),
        onLike: (id: string) => this.commentApiAction('commentLike', id) })
    } else if (this.activeSheetKind === 'save') {
      PinmonySaveSheet({ result: this.pinStore.saveResult, onRetry: () => {
          if(this.pinStore.saveResult.targetBoardId)this.saveApiAction('boardsSections', ',' + JSON.stringify(this.pinStore.saveResult.targetBoardId));else this.openApiBoards();
        },
        onOpenBoard: PIN_NATIVE_POST_OPERATIONS_ENABLED ? (id: string) => this.saveApiAction('boardsSections', ',' + JSON.stringify(id)) : undefined,
        onBack: () => this.saveApiAction('boardsBack'),
        onCreatingChange: (creating: boolean) => this.pinStore.saveCreating = creating,
        onSave: (id: string, section?: string) => this.saveApiAction('boardsSave', ',' + JSON.stringify(id) + (section ? ',' + JSON.stringify(section) : '')),
        onCreate: (name: string, secret: boolean) => this.saveApiAction('boardsCreate', ',' + JSON.stringify(name) + ',' + secret.toString()),
        onRemove: () => this.saveApiAction('boardsRemove') })
    } else if (this.activeSheetKind === 'publish') {
      PinmonyPublishSheet({
        onSection: () => {
          this.publishController.selectSection();
        },
        boardMode: !!this.publishBoardReturn,
        sectionMode: !!this.publishBoardReturn && this.boardStore.boardDetail?.flow?.phase === 'section',
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
    } else if (this.activeSheetKind === 'share') {
      this.buildShareSheet()
    }
  }

  @Builder
  private buildHomeRootContent() {
    PinmonyBuildHomeRootContent({
      homePresentationPageKey: (): string => this.homePresentationPageKey(),
      retainedHomeRootPageKey: (): string => this.retainedHomeRootPageKey(),
      nativeRootOnly: this.nativeRootOnly,
      homeStore: this.homeStore,
      pinStore: this.pinStore,
      rootContentInteracted: this.rootContentInteracted,
      activeTab: this.activeTab,
      activeSheetKind: this.activeSheetKind,
      currentPinUrl: (): string => this.currentPinUrl(),
      handleRootContentScroll: (offset: number, state: ScrollState): void => this.handleRootContentScroll(offset, state),
      homePlaceholder: (): PinmonyHomeSnapshot => this.homePlaceholder(),
      pendingWebTab: this.pendingWebTab,
      currentHomePageKey: (): string => this.currentHomePageKey(),
      authStatus: this.authStatus,
      homeMenuReady: (): boolean => this.homeMenuReady(),
      offlinePreviewMode: this.offlinePreviewMode,
      selectHomeTab: (id: string, restoring: boolean = false): Promise<void> => this.selectHomeTab(id, restoring),
      openHomePin: (id: string): Promise<void> => this.openHomePin(id),
      openHomeBoard: (id: string): void => this.openHomeBoard(id),
      openHomeMore: (id: string): Promise<void> => this.openHomeMore(id),
      loadMoreHome: (): Promise<void> => this.loadMoreHome(),
      refreshHome: (): void => this.refreshHome(),
      retryHome: (): void => { if (PIN_NATIVE_HOME_READS_ENABLED) { void this.homeNativeReads.retry(); } else this.refreshHome(); },
      prefetchHomePinDetails: (first: number, last: number): void => this.prefetchHomePinDetails(first, last),
      onTouch: (event: TouchEvent): void => this.markRootContentTouch(0, event),
    })
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
    PinmonyBuildSearchRootContent({
      photoSearch: (onSelected?: (uri: string) => void) => this.photoSearchFlow.search(onSelected),
      photoHistory: (cursor: string): Promise<PinmonyPhotoHistoryPage> => this.photoSearchFlow.history(cursor),
      selectPhotoHistory: (id: string, onSelected: (uri: string) => void) => this.photoSearchFlow.selectHistory(id, onSelected),
      photoRegionSearch: (crop: PinmonyImageCrop) => this.photoSearchFlow.crop({ x: crop.x, y: crop.y, w: crop.w, h: crop.h }),
      cancelPhotoSearch: () => this.photoSearchFlow.cancel(),
      openPhotoResult: (id: string) => this.photoSearchFlow.open(id),
      syncFloatingTabsMotion: (): void => this.syncFloatingTabsMotion(),
      searchStore: this.searchStore,
      shouldKeepSearchRootMounted: (): boolean => this.shouldKeepSearchRootMounted(),
      pinStore: this.pinStore,
      loadFailed: this.loadFailed,
      activeTab: this.activeTab,
      authStatus: this.authStatus,
      nativeRootOnly: this.nativeRootOnly,
      rootContentInteracted: this.rootContentInteracted,
      activeSheetKind: this.activeSheetKind,
      currentPinUrl: (): string => this.currentPinUrl(),
      handleRootContentScroll: (offset: number, state: ScrollState): void => this.handleRootContentScroll(offset, state),
      searchPlaceholder: (): PinmonySearchSnapshot => this.searchPlaceholder(),
      currentSearchPageKey: (): string => this.currentSearchPageKey(),
      updateSearchQuery: (value: string, refreshSuggestions: boolean = false): Promise<void> => this.updateSearchQuery(value, refreshSuggestions),
      submitSearch: (value: string): Promise<void> => this.submitSearch(value),
      performSearchAction: (id: string, kind: string): Promise<void> => this.performSearchAction(id, kind),
      openSearchPinMenu: (pinUrl: string): Promise<void> => this.openSearchPinMenu(pinUrl),
      loadMoreSearch: (): void => this.loadMoreSearch(),
      refreshSearch: (): Promise<void> => this.refreshSearch(),
      rootPullKind: this.rootPullKind,
      pullRefreshRoot: (kind: string): Promise<void> => this.pullRefreshRoot(kind),
      returnFromSearchQuiz: (): boolean => this.returnFromSearchQuiz(),
      backFromSearch: (): void => this.backFromSearch(),
      performSearchQuizAction: (kind: string, id: string): Promise<void> => this.performSearchQuizAction(kind, id),
      openSearchFilters: (): Promise<void> => this.openSearchFilters(),
      shouldKeepSearchPageMounted: (): boolean => this.shouldKeepSearchPageMounted(),
      nativeSearchPageVisible: (): boolean => this.nativeSearchPageVisible(),
      onTouch: (event: TouchEvent): void => this.markRootContentTouch(1, event),
      onContentInteracted: (): void => { this.rootContentInteracted = true; },
    })
  }

  @Builder
  private buildInboxRootContent() {
    PinmonyBuildInboxRootContent({
      inboxStore: this.inboxStore,
      pinStore: this.pinStore,
      activeSheetKind: this.activeSheetKind,
      loadFailed: this.loadFailed,
      openUserProfile: (url: string): void => this.openUserProfile(url),
      activeTab: this.activeTab,
      authStatus: this.authStatus,
      updateInboxScrollAvailability: (scrollable: boolean): void => this.updateInboxScrollAvailability(scrollable),
      handleRootContentScroll: (offset: number, state: ScrollState): void => this.handleRootContentScroll(offset, state),
      inboxPlaceholder: (): PinmonyInboxSnapshot => this.inboxPlaceholder(),
      currentInboxUrl: (): string => this.currentInboxUrl(),
      previewBoardInvitation: (item: PinmonyBoardInvitation): void => this.previewBoardInvitation(item),
      selectInboxSection: (section: string): Promise<void> => this.selectInboxSection(section),
      loadMoreInbox: (): Promise<void> => this.loadMoreInbox(),
      retryInboxContacts: (): Promise<void> => this.retryInboxContacts(),
      performInboxAction: (id: string): Promise<void> => this.performInboxAction(id),
      selectNativeRootTab: (index: number): void => this.selectNativeRootTab(index),
      retryInbox: (): Promise<void> => this.retryInbox(),
      rootPullKind: this.rootPullKind,
      pullRefreshRoot: (kind: string): Promise<void> => this.pullRefreshRoot(kind),
    })
  }

  @Builder
  private buildProfileRootContent() {
    if (this.profileStore.origins.length === 0) { this.buildProfileContent() }
  }

  private markRootContentTouch(index: number, event: TouchEvent): void {
    if (this.activeTab === index && event.type === TouchType.Move) this.rootContentInteracted = true;
  }

  private openProfileSettings(): void {
    if (this.authStatus === 'authenticated') {
      this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseOut }, () => { this.profileSettingsVisible = true; });
    }
  }

  private showInboxBlockSnack(blocked: boolean, userName: string): void {
    const snack: HdsSnackBar = this.preparePostSnack(4000);
    const token: number = this.postSnackToken;
    snack.show({ icon: $r('sys.symbol.info_circle'), iconType: SnackBarIconType.NORMAL }, { title: blocked ? this.uiText("pm_blocked_eb3c6420") + userName : this.uiText("pm_unblocked_16369d5f") + userName }, {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
      closeButtonAccessibilityText: this.uiText("pm_dismiss_notice_d301bc12"),
      onCloseButtonClick: () => this.handlePostSnackClose(token)
    }, { duration: 4000, pressBackCallback: () => this.handlePostSnackBack(token) });
  }

  @Builder
  private buildProfileContent() {
    PinmonyBuildProfileRootContent({
      profileStore: this.profileStore,
      pinStore: this.pinStore,
      loadFailed: this.loadFailed,
      authStatus: this.authStatus,
      activeTab: this.activeTab,
      nativeRootOnly: this.nativeRootOnly,
      rootContentInteracted: this.rootContentInteracted,
      handleRootContentScroll: (offset: number, state: ScrollState): void => this.handleRootContentScroll(offset, state),
      openUserProfile: (url: string): void => this.openUserProfile(url),
      backFromUserProfile: (): void => this.backFromUserProfile(),
      currentProfileUrl: (): string => this.currentProfileUrl(),
      changeProfileTab: (section: string): Promise<void> => this.changeProfileTab(section),
      openProfilePanel: (mode: string, section: string = 'users'): Promise<void> => this.openProfilePanel(mode, section),
      followProfileUser: (id: string = ''): Promise<void> => this.followProfileUser(id),
      performProfileAction: (id: string): Promise<boolean> => this.performProfileAction(id),
      openProfileBoard: (id: string): Promise<void> => this.openProfileBoard(id),
      traceAction: (name: string, detail: string = ''): void => this.traceAction(name, detail),
      openProfilePinMenu: (id: string): Promise<void> => this.openProfilePinMenu(id),
      openProfileSearch: (): void => { if (this.authStatus === 'authenticated' && !this.businessSuspended && this.activeTab === 3 && this.profileStore.profile?.isOwn === true && !this.activeSheetKind) { this.profileStore.searchBack = () => this.profileSearchReads.close(); this.profileSearchReads.open(); this.syncFloatingTabsMotion(); } },
      openProfilePublish: (): void => this.openProfilePublish(),
      openProfileShare: (): Promise<void> => this.openProfileShare(),
      openProfileMenu: (): void => this.openProfileMenu(),
      openWebsite: (url: string): void => this.openProfileWebsite(url),
      loadMoreProfile: (): void => this.loadMoreProfile(),
      refreshProfile: (pull: boolean = false): void => this.refreshProfile(pull),
      organizeProfile: (action: string, value: string = '', secret: boolean = false): Promise<void> => this.organizeProfile(action, value, secret),
      onTouch: (event: TouchEvent): void => this.markRootContentTouch(3, event),
      onContentInteracted: (): void => { this.rootContentInteracted = true; },
      onSettings: (): void => this.openProfileSettings(),
    })
  }

  @Builder
  private buildRootStatus(index: number) {
    if (!(index === 1 && this.shouldKeepSearchRootMounted() && this.nativeSearchPageVisible()) && !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.extractPinUrl(this.nativeDisplayAddress())) {
            PinmonyStatusPage({ title: [this.uiText("pm_home_3e0d676d"), this.uiText("pm_search_44ce7ae9"), this.uiText("pm_inbox_63a5e7b7"), this.uiText("pm_profile_7f1d9dd0")][index],
              message: this.rootStatusError(index) || (this.loadFailed ? this.failureDetails : this.uiText("pm_loading_content_2b1fde91")),
              loading: this.rootStatusLoading(index),
              showBack: !this.nativeRootTabsVisible(),
              onRetry: () => this.requestRootPage(index), onBack: () => this.backOnePage(),
            })
    }

  }

  @Builder
  private buildRootError(index: number) {
          if (this.loadFailed) {
            Column({ space: 16 }) {
              Text([this.uiText("pm_home_3e0d676d"), this.uiText("pm_search_44ce7ae9"), this.uiText("pm_inbox_63a5e7b7"), this.uiText("pm_profile_7f1d9dd0")][index] + this.uiText("pm_unable_to_load_d1d04482"))
                .fontSize(16)
                .fontColor($r('app.color.primary_text'))
              Text(PinmonyI18n.render(this.failureDetails, this.uiLanguage))
                .fontSize(12)
                .fontColor($r('app.color.secondary_text'))
                .textAlign(TextAlign.Center)
                .maxLines(3)
                .margin({ left: 24, right: 24 })
              Button(this.uiText("pm_retry_b8784c8d"))
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
      }.tabBar(this.buildNativeTab("pm_home_3e0d676d", $r('sys.symbol.house'), 0))
      TabContent() {
        Stack() {
          this.buildRootStatus(1)
          this.buildSearchRootContent()
          this.buildRootError(1)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(1, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab("pm_search_44ce7ae9", $r('sys.symbol.magnifyingglass'), 1))
      TabContent() {
        Stack() {
          this.buildRootStatus(2)
          this.buildInboxRootContent()
          this.buildRootError(2)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(2, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab("pm_inbox_63a5e7b7", $r('sys.symbol.ellipsis_bubble'), 2))
      TabContent() {
        Stack() {
          this.buildRootStatus(3)
          this.buildProfileRootContent()
          this.buildRootError(3)
        }
        .width('100%').height('100%')
        .onVisibleAreaChange([0.01], (visible: boolean) => this.onRootPageVisible(3, visible))
        .backgroundColor($r('app.color.page_background'))
      }.tabBar(this.buildNativeTab("pm_profile_7f1d9dd0", $r('sys.symbol.person'), 3))
    }
            .width('100%')
            .height('100%')
            .onAppear(() => {
              this.floatingTabsMounted = true;
              this.floatingTabsHidden = false;
              if (this.nativeRootTabsVisible()) this.bottomBarCoordinator.resetForSession();
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
            .barBackgroundColor(this.immersiveLightMode !== 'off' ? Color.Transparent : $r('app.color.surface_muted'))
            .barFloatingStyle({
              barBottomMargin: 28,
              systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)
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
      Text(PinmonyI18n.render(this.networkNotice, this.uiLanguage)).fontSize(14).fontColor($r('app.color.detail_on_accent'))
        .maxLines(2).layoutWeight(1)
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.accent'))
    .borderRadius(10)
    .margin({ bottom: 18 })
    .visibility(this.networkNotice.length > 0 ? Visibility.Visible : Visibility.None)
    .accessibilityText(PinmonyI18n.render(this.networkNotice, this.uiLanguage))
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Bottom }) {
        if (!this.nativeLoginEnabled || this.loginHostMounted) {
        PinmonyBuildLoginPage({
          controller: this.controller, bridge: this.shareBridge, scripts: this.nativeLoginEnabled ? this.loginScripts : this.documentStartScripts,
          url: this.nativeLoginEnabled ? this.loginStartUrl : PINTEREST_URL,
          isCurrent: (controller: webview.WebviewController): boolean => !this.nativeLoginEnabled || this.loginHostMounted && controller === this.controller,
          lifecycle: this.webLifecycleCoordinator, visible: this.authWebVisible(),
          authenticated: this.authStatus === 'authenticated', presentationOnly: this.pinStore.detailPresentationOnly,
          onUnsupportedLogin: (): void => this.showUnsupportedLogin(),
          captureEnvironment: (): void => {
            try { this.sessionEnvironment.capture(this.controller.getUserAgent()); } catch (_) {}
          }
        })
        }

        if (this.authStatus === 'authenticated') {
          this.buildRootTabs()
          if (this.profileStore.origins.length > 0 && this.currentProfileUrl()) {
            this.buildProfileContent()
          }

          if (this.profileStore.publishFlow && this.publishPageVisible()) {
            PinmonyPublishPage({ state: this.profileStore.publishFlow,
              onAction: (action: string, value: string, secret: boolean) => this.publishFlowAction(action, value, secret) })
              .width('100%').height('100%').transition(NATIVE_PAGE_TRANSITION)
          }

          if (this.profileSettingsVisible) {
            PinmonySettingsPage({ store: this.settingsStore, onOpenExternalLink: (url: string): Promise<void> => this.systemActions.openLink(url), onRequest: (action: string, value: string) => this.requestAccountSettings(action, value), onBack: () => this.closeProfileSettings(), onEditProfile: () => this.openProfilePanel('edit') })
              .width('100%').height('100%')
              .transition(NATIVE_PAGE_TRANSITION)
          }

          if (this.profileStore.panel) {
            PinmonyProfilePanelPage({ snapshot: this.profileStore.panel, followingBusy: this.profileStore.followingBusy, onFollow: (id: string) => this.followProfileUser(id), onAvatar: () => this.changeProfileAvatar(), saving: this.profileStore.saving, onSave: (input: string) => this.saveProfilePanel(input),
              onBoard: (url: string) => this.openProfilePanelBoard(url), onUser: (url: string) => this.openUserProfile(url), onBack: () => this.closeProfilePanel(),
              onSection: (section: string) => this.openProfilePanel('following', section),
              onLoadMore: () => { this.profileNativeActions.moreFollowers(); } })
              .width('100%').height('100%').transition(this.immediateFollowingReturn ? TransitionEffect.asymmetric(
                TransitionEffect.IDENTITY, TransitionEffect.translate({ x: '100%' }).animation({ duration: 150, curve: Curve.EaseIn })) : NATIVE_PAGE_TRANSITION)
          }
          if (this.boardStore.collaborators) {
            PinmonyBoardCollaboratorsPage({ snapshot: this.boardStore.collaborators,
              onClose: () => this.closeBoardCollaborators(),
              onAction: (action: string, value: string) => this.boardCollaboratorsAction(action, value) })
          }
          if (this.inboxStore.invitationAllVisible && this.inboxStore.boardInvitations) {
              PinmonyBoardInvitationList({ snapshot: this.inboxStore.boardInvitations, all: true,
                onBack: () => { this.inboxStore.invitationAllVisible = false; },
                onPreview: (item: PinmonyBoardInvitation) => this.previewBoardInvitation(item) })
                .width('100%').height('100%')
          }
          if (this.boardStore.boardDetail && this.nativeBoardVisible()) {
            PinmonyBoardPage({ profileBoard: this.boardStore.rootTab === 3,
              discoveryBoard: this.boardStore.discoveryBoardPage === this.boardStore.boardDetail.pageKey,
              onUser: (url: string) => this.openUserProfile(url), snapshot: this.boardStore.boardDetail, onBack: () => this.backFromBoard(),
              onPin: (id: string) => { this.traceAction('board.pin.open'); this.boardOperation('open', id); },
              onMessage: () => this.openBoardChat(), onMore: (id: string) => this.openBoardPinMore(id), onCollaborators: () => this.openBoardCollaborators(),
              invitationName: this.inboxStore.boardInvitationPreview?.inviter || '', invitationAvatar: this.inboxStore.boardInvitationPreview?.inviterAvatar || '',
              invitationVisible: this.inboxStore.invitationBannerVisible && this.inboxStore.boardInvitationPreview?.boardUrl === this.boardStore.boardDetail.pageKey,
              invitationBusy: this.inboxStore.invitationBusy, joinedAvatar: this.inboxStore.joinedBoardAvatar,
              onAcceptInvitation: () => this.acceptBoardInvitation(), onDismissInvitation: () => { this.inboxStore.invitationBannerVisible = false; },
              onShare: () => this.shareCurrentBoard(), onPublish: () => this.openProfilePublish(),
              onLoadMore: () => this.boardOperation('more'), onRetry: () => this.boardOperation('retry'),
              onRefresh: () => this.boardOperation('refresh'),
              onAction: (value: string) => this.boardOperation('flow', value) })
              .width('100%').height('100%')
              .visibility(this.boardStore.collaborators || this.publishPageVisible() && this.profileStore.publishFlow && this.profileStore.publishFlow.phase !== 'create' ? Visibility.Hidden : Visibility.Visible)
              .hitTestBehavior(this.boardStore.collaborators || this.profileStore.publishFlow || this.publishBoardReturn ? HitTestMode.None : HitTestMode.Default)
              .onAppear(() => {
                if (this.boardStore.boardDetail) this.pagePerformance.markSecondary('board', this.boardStore.boardDetail.pageKey, 'component-ready');
                if(PIN_NATIVE_BOARD_READS_ENABLED)this.boardNativeReads.demand();
              })
              .transition(this.followingBoardReturn ? TransitionEffect.asymmetric(
                TransitionEffect.translate({ x: '100%' }).animation({ duration: 150, curve: Curve.EaseOut }),
                TransitionEffect.IDENTITY) : BOARD_PAGE_TRANSITION)
          }

          if (this.boardSectionVisible) {
            PinmonyBoardSectionPage({ ready: this.boardSectionReady(), onCreate: (name: string): Promise<string> => this.createBoardSection(name), onClose: () => {
              this.closeBoardSection();
            } })
              .width('100%').height('100%')
          }
          if (this.activeTab === 3 && this.profileStore.searchVisible && this.profileStore.contentSearch &&
              !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.nativeBoardVisible() && this.profileStore.origins.length === 0) {
            PinmonyProfileSearchPage({ snapshot: this.profileStore.contentSearch,
              onResume: () => this.profileSearchReads.resume(),
              onPause: () => this.profileSearchReads.pause(),
              onInput: (query: string) => this.profileSearchReads.input(query),
              onSubmit: (query: string) => this.profileSearchReads.submit(query),
              onDeleteHistory: (query: string) => this.profileSearchReads.deleteHistory(query),
              onMore: () => this.profileSearchReads.more(), onRetry: () => this.profileSearchReads.retry(),
              onBack: () => { this.nativeChildBackUntil = Date.now() + 300; this.profileSearchReads.close(); this.syncFloatingTabsMotion(); },
              onPin: (id: string) => {
                const pin: PinmonyProfileSearchPin | undefined = this.profileStore.contentSearch?.pins.find((p: PinmonyProfileSearchPin): boolean => p.id === id) ||
                  this.profileStore.contentSearch?.suggestions.flatMap((s) => s.pins).find((p: PinmonyProfileSearchPin): boolean => p.id === id);
                if (!pin || this.authStatus !== 'authenticated' || this.businessSuspended || this.activeSheetKind) return;
                this.profileSearchReads.pause(); this.beginDetailOpening(this.nativeBusinessSessionContext().origin + '/pin/' + pin.id + '/', this.currentProfileUrl());
              } }).width('100%').height('100%')
          }
          if (this.activeTab === 2 && this.inboxStore.listSection && this.inboxStore.inbox &&
              !this.pinStore.detail && !this.nativeBoardVisible() && this.profileStore.origins.length === 0) {
            PinmonyInboxListPage({ snapshot: this.inboxStore.inbox,
              section: this.inboxStore.listSection,
              onSearchBackChange: (handler: (() => boolean) | undefined) => { this.inboxStore.listSearchBack = handler; },
              onSearchClosed: () => { this.nativeChildBackUntil = Date.now() + 300; },
              actionsReady: this.inboxStore.inboxNativeMessagesReady || this.inboxStore.inboxActionsReady,
              onSection: (section: string) => { this.inboxStore.listSection = section; },
              onBack: () => { this.nativeChildBackUntil = Date.now() + 300; this.inboxStore.listSection = ''; },
              onAction: (id: string) => this.performInboxAction(id),
              onRetry: () => this.retryInbox(), onContactsRetry: () => this.retryInboxContacts() })
              .width('100%').height('100%')
              .hitTestBehavior(this.inboxStore.inboxFlow ? HitTestMode.None : HitTestMode.Default)
          }
          if (!(PIN_NATIVE_PROFILE_READS_ENABLED && this.profileStore.origins.length > 0 && this.currentProfileUrl()) && !this.nativeBoardVisible() && this.inboxStore.inboxFlow && (this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl() ||
              this.activeTab === 2 && !!this.inboxStore.retainedChat)) {
            PinmonyInboxFlowPage({ onUser: (url: string) => this.openUserProfile(url), snapshot: this.inboxStore.inboxFlow,
              onCopyText: async (text: string): Promise<boolean> => {
                try { await this.systemActions.copyText(text); this.showMessage(PinmonyI18n.message("pm_copied_8f6f8d97")); return true; }
                catch (_) { this.showMessage(PinmonyI18n.message("pm_unable_to_copy_please_retry_86ee2899")); return false; }
              },
              onBoard: (messageId: string) => this.openInboxBoard(messageId),
              active: !this.pinStore.detail && !this.pinStore.detailOpeningPin && this.inboxStore.inboxFlow.pageUrl === this.currentInboxUrl(),
              restoreOffset: this.inboxStore.chatReturnConversation === this.inboxStore.inboxFlow.conversationId ? this.inboxStore.chatScrollOffset : -1,
              onOffset: (offset: number): void => { this.inboxStore.chatScrollOffset = offset; },
              onNewsHidden: (newsId: string) => this.showInboxUndoSnack(newsId),
              onNewsRestored: (_newsId: string) => this.showInboxRestoredSnack(),
              onPinUnsubscribed: () => this.showInboxUnsubscribedSnack(),
              onBlockChanged: (blocked: boolean, userName: string) => this.showInboxBlockSnack(blocked, userName),
              onNotifications: () => {
                this.inboxFlowAction('back');
                this.settingsStore.screen = 'notifications'; this.profileSettingsVisible = true; this.readNotifications();
              },
              onPinAction: (action: string, url: string) => {
                if (!this.isCurrentInboxMessagePin(url)) return;
                this.openCustomHomeMenu(url, this.currentInboxUrl(), action);
              },
              onPin: (url: string): void => {
                if (this.authStatus !== 'authenticated' || this.businessSuspended || this.activeSheetKind ||
                    !this.isCurrentInboxMessagePin(url)) return;
                const target: string = this.extractPinUrl(url);
                if (!target || this.rejectOfflineAction('chat pin')) return;
                this.traceAction('inbox.pin.open');
                this.inboxStore.retainedChat = this.inboxStore.inboxFlow;
                this.inboxStore.chatReturnConversation = this.inboxStore.inboxFlow?.conversationId || '';
                this.beginDetailOpening(target, this.currentInboxUrl());
                try { if(!PIN_NATIVE_DETAIL_READS_ENABLED)this.loadSessionDocument(target); }
                catch (_) { this.pinStore.detailOpeningPin = ''; this.showMessage(PinmonyI18n.message("pm_unable_to_open_pin_please_retry_1260c20b")); }
              },
              onAction: (action: string, value: string) => this.inboxFlowAction(action, value) })
              .width(this.inboxStore.inboxFlow.screen === 'updatesMenu' ? 1 : '100%')
              .height(this.inboxStore.inboxFlow.screen === 'updatesMenu' ? 1 : '100%')
              .hitTestBehavior(this.inboxStore.inboxFlow.screen === 'updatesMenu' ? HitTestMode.Transparent : HitTestMode.Default)
              .onAppear(() => {
                const flow: PinmonyInboxFlowSnapshot | undefined = this.inboxStore.inboxFlow;
                if (flow?.screen === 'chat') this.pagePerformance.markSecondary('chat', flow.session + ':' + (flow.conversationId || ''), 'component-ready');
              })
          }

          if ((this.pinStore.detail || this.pinStore.detailOpeningPin) && !this.pinStore.detailWebFlow && !this.loadFailed) {
            Stack() {
              if (this.pinStore.detail && !this.pinStore.detailWebFlow && !this.loadFailed) {
                ForEach([this.detailRootIdentity()], (_identity: string) => {
                PinmonyDetailPage({ onUser: (url: string) => this.openUserProfile(url),
                  onTagSearch: (query: string, pin: string) => this.openDetailTagSearch(query, pin),
                  detail: this.pinStore.detail,
                  renderIdentity: this.detailRenderIdentity(),
                  traceId: this.pinStore.detailOpeningToken,
                  contentError: this.pinStore.detailApiError,
                  contentRetryable: this.pinStore.detailApiRetryable,
                  onContentRetry: () => this.retryDetailApi(),
                  onPresented: () => {
                    this.detailJourney.mark('view.appeared'); this.detailJourney.mark('interaction.frame.appeared');
                    PinmonyRuntimeLog.info('DetailTrace: view appeared openId=' + this.pinStore.detailOpeningToken.toString() + ' elapsedMs=' + (Date.now() - this.detailOpenedAt).toString());
                  },
                  onImageLoaded: (pinUrl: string, imageUrl: string, renderIdentity: string) => {
                    if (renderIdentity !== this.detailRenderIdentity() ||
                        pinUrl !== this.pinStore.detailPin || imageUrl !== this.pinStore.detail?.imageUrl) return;
                    this.pinStore.detailImageFailedPin = '';
                    this.homeStore.recoverImage(pinUrl, imageUrl);
                    this.pagePerformance.markSecondary('detail', pinUrl, 'image-ready');
                    this.detailImageLoadedUrl = imageUrl;
                    this.signalDetailImageStage('loaded');
                    const current: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
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
                      this.detailImageStage.clearDeadline();
                    }
                    this.detailJourney.mark(this.pinStore.detailActionsReady ? 'main.image.loaded' : 'opening.image.loaded');
                    PinmonyRuntimeLog.info('DetailTrace: image loaded openId=' + this.pinStore.detailOpeningToken.toString() + ' elapsedMs=' + (Date.now() - this.detailOpenedAt).toString());
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
                    else this.detailOperationsController.openImageLayer(layer);
                  },
                  onVisualSearch: (crop: PinmonyImageCrop, append: boolean, first: boolean) => this.searchImage(crop, append, first),
                  onDownload: () => this.downloadViewerImage(),
                  onViewerSave: () => this.saveViewerImage(),
                  videoActive: this.pinStore.videoForeground && !this.activeSheetKind && !this.pinStore.detailWebFlow,
                  onVideoRetry: () => this.retryDetailMedia(),
                  postActionsReady: this.postNativeOperations.ready(),
                  menuActionsReady: PIN_NATIVE_PIN_MENUS_ENABLED && this.detailNativeReads.owned(),
                  shareActionsReady: PIN_NATIVE_SHARE_PUBLISH_ENABLED && this.detailNativeReads.owned(),
                  likeBlocked: PIN_NATIVE_POST_OPERATIONS_ENABLED && this.postNativeOperations.likeBlocked(this.pinStore.detail?.pinUrl || ''),
                  commentActionsReady: PIN_NATIVE_COMMENT_WRITES_ENABLED && this.detailNativeReads.owned(),
                  auxiliaryReady: PIN_NATIVE_DETAIL_AUXILIARY_ENABLED && this.detailNativeAuxiliary.ready(),
                  deferredActions: this.pinStore.detailPresentationOnly && !this.pinStore.detailPreparing && this.authStatus === 'authenticated',
                  actionsReady: this.pinStore.detailActionsReady,
                  readsReady: this.pinStore.detailNativeReadsReady,
                  saveBusy: this.pinStore.viewerSaveBusy,
                  mediaReadBusy: this.pinStore.detailMediaRetryBusy,
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
                    PinmonyRuntimeLog.info('DetailTrace: image failed; content retained');
                  },
                  onLoadMore: () => this.loadMoreRelated(),
                  onComments: async () => { if (PIN_NATIVE_DETAIL_READS_ENABLED && this.detailNativeReads.owned() || await this.ensureDetailActionContext()) this.openApiComments(); },
                  onCommentsRetry: () => this.retryDetailPreview(),
                  canUndoMore: false,
                  undoMoreBusy: this.pinStore.feedbackUndoBusy,
                  onUndoMore: () => this.undoMoreFeedback(),
                  onScrollPosition: (pinUrl: string, offset: number) =>
                    this.saveDetailScrollPosition(pinUrl, offset)
                })
                .width('100%')
                .height('100%')
                .onAppear(() => {
                  if (this.pinStore.detail) this.pagePerformance.markSecondary('detail', this.pinStore.detail.pinUrl, 'component-ready');
                })
                }, (_identity: string) => _identity)
              }

              if (this.pinStore.detailOpeningPin && !this.pinStore.detail && !this.pinStore.detailWebFlow && !this.loadFailed) {
                Column({ space: 16 }) {
                  if (this.pinStore.detailApiError) {
                    Text(PinmonyI18n.render(this.pinStore.detailApiError, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
                    if (this.pinStore.detailApiRetryable) {
                      Button(this.uiText("pm_retry_b8784c8d")).onClick(() => this.retryDetailApi())
                    }
                    Button(this.uiText("pm_back_572cf45b")).onClick(() => this.backFromDetail())
                  } else {
                    LoadingProgress().width(36).height(36).color($r('app.color.accent'))
                    Text(this.uiText("pm_loading_pin_0eab4d34")).fontSize(14).fontColor($r('app.color.secondary_text'))
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
              Text(this.uiText("pm_loading_pin_options_9d18460b"))
                .fontSize(14)
                .fontColor($r('app.color.secondary_text'))
              Button(this.uiText("pm_back_572cf45b")).onClick(() => {
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
          PinmonyStatusPage({
            title: this.offlineCacheLoading ? this.uiText("pm_loading_recent_cache_21b2ed90") :
              this.authStatus === 'error' ? this.uiText("pm_unable_to_load_current_session_447e235d") : this.uiText("pm_loading_existing_session_f538c37e"),
            message: this.offlineCacheLoading ? '' : this.authStatus === 'error' ? this.failureDetails : '',
            loading: this.offlineCacheLoading || this.authStatus !== 'error', onRetry: () => this.retryLogin(),
          })
        }
        if (this.authStatus !== 'authenticated') { this.networkNoticeView() }
      }
      if (this.authStatus === 'authenticated') { this.networkNoticeView() }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.publishPageVisible() && !!this.profileStore.publishFlow && this.profileStore.publishFlow.phase !== 'create' || (this.profileStore.origins.length > 0 && !!this.currentProfileUrl()) || !!this.profileStore.panel || this.profileSettingsVisible ||
      this.profileStore.searchVisible || !!this.inboxStore.listSection || (!!this.inboxStore.inboxFlow && this.inboxStore.inboxFlow.screen !== 'updatesMenu') ||
      this.inboxStore.invitationAllVisible || !!this.boardStore.collaborators || !!this.pinStore.detail || this.nativeSearchPageVisible() || this.nativeBoardVisible() ||
      (!this.pinStore.detail && !!this.profileStore.profile?.organize && !this.profileStore.profileWebFlow) ?
      0 : this.getUIContext().px2vp(this.statusBarHeightPx) })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.showNativeSheet, this.buildNativeSheet(), {
      radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
      onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=Index.showNativeSheet radius=four-corners-32vp' + ' kind=' + this.activeSheetKind); },
      keyboardAvoidMode: this.activeSheetKind === 'comments' ? SheetKeyboardAvoidMode.RESIZE_ONLY :
        SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
     height: ['save', 'edit', 'comments'].includes(this.activeSheetKind) ? SheetSize.LARGE :
        this.activeSheetKind === 'share' && !this.homeStore.customHomeMenu && this.pinStore.shareSearchActive ? SheetSize.LARGE : SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      title: { title: this.nativeModalLabel() },
      backgroundColor: $r('app.color.page_background'),
      maskColor: '#66000000',
      onDisappear: (): void => {
        if (!this.showNativeSheet && ['save', 'edit'].includes(this.activeSheetKind)) {
          const closed: (() => void) | undefined = this.postSheetClosed;
          const dismissed: boolean = this.postSheetDismissed;
          this.postSheetClosed = undefined;this.postSheetDismissed = false;this.activeSheetKind = '';
          if(dismissed && this.homeStore.customHomeMenu)this.dismissShareSheet();
          if(closed)closed();
        }
        if (!this.showNativeSheet && this.activeSheetKind === 'searchFilter') {
          const target: string = this.pendingSearchFilterTarget, source: string = this.pendingSearchFilterSource;
          this.pendingSearchFilterTarget = ''; this.pendingSearchFilterSource = ''; this.activeSheetKind = '';
          if (target && this.authStatus === 'authenticated' && this.activeTab === 1 &&
              !this.pinStore.detail && !this.pinStore.detailOpeningPin && this.currentSearchPageKey() === source) {
            this.searchNativeReads.navigate(target);
          }
        }
        if (this.publishSheetClosing) {
          this.publishSheetClosing = false;
          if (this.activeSheetKind === 'publish') this.activeSheetKind = '';
          const closed: ((closed: boolean) => void) | undefined = this.publishSheetClosed;
          this.publishSheetClosed = undefined;
          if (closed) closed(true);
        }
        if (!this.showNativeSheet && ['save', 'comments', 'edit'].includes(this.activeSheetKind)) this.activeSheetKind = '';
        this.syncFloatingTabsMotion();
        if (!this.showNativeSheet && this.activeSheetKind === 'publish') {
          this.dismissProfilePublish();
          this.publishSheetClosing = false;
          this.activeSheetKind = '';
        }
        this.notifyDetailSystemShareClosed();
      },
      onWillDismiss: (action: DismissSheetAction) => {
        if (this.detailSystemShareClosed) { action.dismiss(); return; }
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
