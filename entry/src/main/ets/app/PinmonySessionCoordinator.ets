import { PinmonyControllerLifecycle } from './PinmonyControllerLifecycle';
import { PinmonyReturnCoordinator } from './PinmonyReturnCoordinator';
import { PinmonySearchController } from 'feature_search';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyDetailTrace, PinmonyDetailReadCache } from 'feature_pin';
import { PinmonyBoardStore } from 'feature_board';
import { PinmonyProfileStore } from 'feature_profile';
import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonyHomeController } from 'feature_home';
import { PinmonyHomeStore } from 'feature_home';
import { PinmonyNativeNetwork } from 'common_network';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { webview } from '@kit.ArkWeb';
import { PinmonyAuthMessage, PinmonyAuthStatus, acceptsAuthMessage, isPinterestAuthRoute } from 'common_session';
import { PINTEREST_LOGIN_URL } from 'common_session';
import { PinmonySettingsStore } from 'feature_settings';
import { HdsTabsController } from '@kit.UIDesignKit';
import { PinmonyNavigationHistory } from './PinmonyNavigationHistory';
interface PendingDetailLike {
  id: string;
  pinUrl: string;
  session: number;
  selected: boolean;
  countText: string;
}
const PINTEREST_URL: string = 'https://www.pinterest.com/';
export interface PinmonySessionCoordinatorPorts {
  activeSheetKind: () => string;
  setActiveSheetKind: (value: string) => string;
  activeTab: () => number;
  setActiveTab: (value: number) => number;
  authCheckTimer: () => number;
  setAuthCheckTimer: (value: number) => number;
  authEpoch: () => number;
  authStatus: () => PinmonyAuthStatus;
  setAuthStatus: (value: PinmonyAuthStatus) => PinmonyAuthStatus;
  authWebVisible: () => boolean;
  authenticatedProfileUrl: () => string;
  setAuthenticatedProfileUrl: (value: string) => string;
  bindNativeNetwork: () => void;
  confirmBusinessSession: (appVersion: string) => void;
  boardStore: () => PinmonyBoardStore;
  cancelAccountSettings: () => void;
  cancelHomeDetailMore: () => void;
  clearDetail: (preserveRead?: boolean, localOnly?: boolean) => void;
  clearOfflineHomeMarker: () => void;
  clearRootTabCaches: (clearPersistentCache?: boolean) => void;
  closeImageLayer: (localOnly?: boolean) => void;
  closeProfilePanel: () => void;
  configureDocumentRetention: (enabled: boolean) => void;
  controller: () => webview.WebviewController;
  controllerLifecycle: () => PinmonyControllerLifecycle;
  currentWebTab: () => number;
  setCurrentWebTab: (value: number) => number;
  detailClickedAt: () => number;
  setDetailClickedAt: (value: number) => number;
  detailReadCache: () => PinmonyDetailReadCache;
  detailReturnJourney: () => PinmonyDetailTrace;
  detailReturnedToRoot: () => boolean;
  setDetailReturnedToRoot: (value: boolean) => boolean;
  dismissPostSnack: (reason?: string) => void;
  expectHome: () => void;
  failureDetails: () => string;
  setFailureDetails: (value: string) => string;
  homeCacheAccountId: () => string;
  setHomeCacheAccountId: (value: string) => string;
  homeCacheAccountIdFromProfileUrl: (profileUrl: string) => string;
  homeCacheIdentityEpoch: () => number;
  setHomeCacheIdentityEpoch: (value: number) => number;
  homeController: () => PinmonyHomeController;
  homePageKeyFromAddress: (url: string) => string;
  homeRecoveryAttempted: () => boolean;
  setHomeRecoveryAttempted: (value: boolean) => boolean;
  homeRecoveryToken: () => number;
  setHomeRecoveryToken: (value: number) => number;
  homeStore: () => PinmonyHomeStore;
  inboxStore: () => PinmonyInboxStore;
  interruptedHomePage: () => string;
  setInterruptedHomePage: (value: string) => string;
  isHomeRootAddress: (address: string) => boolean;
  lastLoginRetryAt: () => number;
  setLastLoginRetryAt: (value: number) => number;
  lastPageUrl: () => string;
  loadFailed: () => boolean;
  setLoadFailed: (value: boolean) => boolean;
  loginRedirectEpoch: () => number;
  setLoginRedirectEpoch: (value: number) => number;
  logoutAwaitingLogin: () => boolean;
  nativeBackTarget: () => string;
  setNativeBackTarget: (value: string) => string;
  nativeNetwork: () => PinmonyNativeNetwork;
  nativePinRoute: () => string;
  setNativePinRoute: (value: string) => string;
  nativeRootOnly: () => boolean;
  setNativeRootOnly: (value: boolean) => boolean;
  navigationAddress: () => string;
  setNavigationAddress: (value: string) => string;
  offlineCacheLoading: () => boolean;
  setOfflineCacheLoading: (value: boolean) => boolean;
  offlinePreviewMode: () => boolean;
  setOfflinePreviewMode: (value: boolean) => boolean;
  pageBackToken: () => number;
  setPageBackToken: (value: number) => number;
  pageHistory: () => PinmonyNavigationHistory;
  pageTasks: () => PinmonyTaskRegistry;
  pendingDetailLike: () => PendingDetailLike | undefined;
  setPendingDetailLike: (value: PendingDetailLike | undefined) => PendingDetailLike | undefined;
  pendingWebTab: () => number;
  setPendingWebTab: (value: number) => number;
  pinStore: () => PinmonyPinStore;
  profileSettingsVisible: () => boolean;
  setProfileSettingsVisible: (value: boolean) => boolean;
  profileStore: () => PinmonyProfileStore;
  profileUrlFromAddress: (address: string) => string;
  refreshWebNavigation: () => Promise<void>;
  retainedHomeAwaitingAuth: () => boolean;
  setRetainedHomeAwaitingAuth: (value: boolean) => boolean;
  retainedHomeAwaitingFeed: () => boolean;
  setRetainedHomeAwaitingFeed: (value: boolean) => boolean;
  retainedHomeDocumentAddress: () => string;
  setRetainedHomeDocumentAddress: (value: string) => string;
  retainedHomeDocumentPending: () => boolean;
  setRetainedHomeDocumentPending: (value: boolean) => boolean;
  retainedRootTabAddress: () => string;
  setRetainedRootTabAddress: (value: string) => string;
  retainedRootTabPending: () => number;
  setRetainedRootTabPending: (value: number) => number;
  returnCoordinator: () => PinmonyReturnCoordinator;
  rootContentInteracted: () => boolean;
  setRootContentInteracted: (value: boolean) => boolean;
  rootTabGuardAddress: () => string;
  setRootTabGuardAddress: (value: string) => string;
  rootTabGuardTarget: () => number;
  setRootTabGuardTarget: (value: number) => number;
  searchController: () => PinmonySearchController;
  settingsStore: () => PinmonySettingsStore;
  showNativeSheet: () => boolean;
  setShowNativeSheet: (value: boolean) => boolean;
  showNetworkNotice: (message?: string) => void;
  tabRequestToken: () => number;
  setTabRequestToken: (value: number) => number;
  tabsController: () => HdsTabsController;
  tryEnterOfflinePreview: (failedUrl: string, reason?: string) => boolean;
  tryRestoreAuthenticatedHome: (accountId: string, pageKey: string) => void;
  webPageLoading: () => boolean;
}
export class PinmonySessionCoordinator {
  private readonly homeStore: PinmonyHomeStore;
  private readonly profileStore: PinmonyProfileStore;
  private readonly inboxStore: PinmonyInboxStore;
  private readonly pinStore: PinmonyPinStore;
  private readonly boardStore: PinmonyBoardStore;
  private readonly settingsStore: PinmonySettingsStore;
  private readonly ports: PinmonySessionCoordinatorPorts;
  constructor(ports: PinmonySessionCoordinatorPorts) { this.ports = ports; this.homeStore = ports.homeStore(); this.profileStore = ports.profileStore(); this.inboxStore = ports.inboxStore(); this.pinStore = ports.pinStore(); this.boardStore = ports.boardStore(); this.settingsStore = ports.settingsStore(); }
updateAuthState(value: string): void {
    try {
        const message: PinmonyAuthMessage = JSON.parse(value) as PinmonyAuthMessage;
        const currentUrl: string = this.ports.controller().getUrl();
        if (!acceptsAuthMessage(message, currentUrl, this.ports.authEpoch()))
            return;
        if (this.ports.logoutAwaitingLogin() && !isPinterestAuthRoute(currentUrl))
            return;
        try {
            this.ports.controller().runJavaScript('window.PinmonyAuthAcknowledge && window.PinmonyAuthAcknowledge(' +
                JSON.stringify(value) + ')').catch(() => PinmonyRuntimeLog.warn('Pinmony: authentication acknowledgement unavailable'));
        }
        catch (_) {
            PinmonyRuntimeLog.warn('Pinmony: authentication acknowledgement unavailable');
        }
        if (message.status === 'unauthenticated') {
            this.ports.setOfflineCacheLoading(false);
            if (this.ports.authStatus() === 'authenticated')
                this.resetAuthenticatedContent();
            this.ports.setAuthStatus('unauthenticated');
            this.ports.setLoadFailed(false);
            this.ports.setFailureDetails('');
            if (!isPinterestAuthRoute(currentUrl) && this.ports.loginRedirectEpoch() !== this.ports.authEpoch()) {
                // Repeated evidence callbacks must not queue multiple login navigations.
                this.ports.setLoginRedirectEpoch(this.ports.authEpoch());
                PinmonyRuntimeLog.info('StartupTrace: session unavailable, opening login');
                this.ports.controller().loadUrl(PINTEREST_LOGIN_URL);
            }
            return;
        }
        const entering: boolean = this.ports.authStatus() !== 'authenticated';
        this.ports.setLoginRedirectEpoch(-1);
        this.ports.setOfflineCacheLoading(false);
        this.ports.setAuthStatus('authenticated');
        if (this.ports.offlinePreviewMode()) {
            this.ports.setOfflinePreviewMode(false);
            PinmonyRuntimeLog.info('OfflineCache: preview exited reason=current-session-confirmed');
        }
        this.ports.setRetainedHomeAwaitingAuth(false);
        const accountId: string = this.ports.homeCacheAccountIdFromProfileUrl(message.profileUrl);
        const accountChanged: boolean = !!this.ports.homeCacheAccountId() && !!accountId &&
            this.ports.homeCacheAccountId() !== accountId;
        if (accountChanged) {
            PinmonyRuntimeLog.info('HomeCache: account identity changed; clearing memory and preserving disk partitions');
            this.ports.clearOfflineHomeMarker();
            this.ports.clearRootTabCaches(false);
            this.ports.nativeNetwork().invalidate();
            this.ports.clearDetail();
            this.pinStore.detailCache.clear(); this.homeStore.imageRecovery = undefined;
            this.pinStore.clearDetailOrigins();
            this.pinStore.detailPrefetch.clear();
            this.pinStore.prefetchedImageUrls = [];
            this.pinStore.confirmedSaves.clear();
        }
        else if (!accountId && this.ports.homeCacheAccountId() && this.ports.homeCacheIdentityEpoch() !== message.epoch) {
            // A root-tab document transition can produce an auth callback before
            // the profile URL is available. That is not evidence of an account
            // change. Clearing the in-memory feed here made every tab return look
            // like a cold start and allowed a fresh feed response to replace the
            // content the user had just left.
            PinmonyRuntimeLog.info('HomeCache: account identity unavailable; retaining memory epoch=' + message.epoch.toString());
        }
        if (accountId)
            this.ports.setHomeCacheAccountId(accountId);
        this.ports.setHomeCacheIdentityEpoch(message.epoch);
        const authenticatedHomePage: string = this.ports.homePageKeyFromAddress(currentUrl);
        this.ports.tryRestoreAuthenticatedHome(accountId, authenticatedHomePage);
        if (entering)
            this.ports.configureDocumentRetention(true);
        if (entering)
            PinmonyRuntimeLog.info('StartupTrace: authenticated session confirmed');
        this.ports.setLoadFailed(false);
        this.ports.setFailureDetails('');
        if (this.ports.authCheckTimer() !== -1)
            this.ports.pageTasks().cancelTimeout(this.ports.authCheckTimer());
        if (message.profileUrl && this.ports.profileUrlFromAddress(message.profileUrl) &&
            /^https:\/\/(?:www|uk)\.pinterest\.com\//.test(message.profileUrl)) {
            this.ports.setAuthenticatedProfileUrl(message.profileUrl);
        }
        this.ports.confirmBusinessSession(message.appVersion || '');
        const authenticatedProfile: string = this.ports.profileUrlFromAddress(this.ports.authenticatedProfileUrl());
        const usernameMatch: RegExpMatchArray | null = authenticatedProfile.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/([a-zA-Z0-9_]+)\//i);
        const homeUsername: string = usernameMatch ? usernameMatch[1] : '';
        PinmonyRuntimeLog.info('StartupTrace: home identity ready=' + (!!homeUsername).toString() +
            ' profilePresent=' + (!!authenticatedProfile).toString());
        this.ports.controller().runJavaScript('window.PinmonyHomeSetUsername && window.PinmonyHomeSetUsername(' +
            JSON.stringify(homeUsername) + ')').catch(() => PinmonyRuntimeLog.warn('Pinmony: home identity bridge unavailable'));
        this.ports.bindNativeNetwork();
        if (entering) {
            this.ports.setActiveTab(0);
            this.ports.tabsController().changeIndex(0);
            this.ports.pageHistory().reset();
            if (!this.ports.isHomeRootAddress(currentUrl))
                this.ports.controller().loadUrl(PINTEREST_URL);
            else {
                this.ports.expectHome();
                this.ports.controller().runJavaScript('window.PinmonyHomeRefresh && window.PinmonyHomeRefresh()')
                    .catch(() => PinmonyRuntimeLog.warn('Pinmony: initial home sync unavailable'));
                this.ports.refreshWebNavigation();
            }
        }
        else if (accountChanged && authenticatedHomePage) {
            this.ports.expectHome();
            this.ports.controller().runJavaScript('window.PinmonyHomeRefresh && window.PinmonyHomeRefresh()')
                .catch(() => PinmonyRuntimeLog.warn('Pinmony: account home sync unavailable'));
        }
    }
    catch (_) {
        PinmonyRuntimeLog.warn('Pinmony: invalid authentication state');
    }
}

resetAuthenticatedContent(): void {
    this.ports.returnCoordinator().cancel();
    this.ports.controllerLifecycle().pause();
    this.ports.homeController().invalidatePending();
    this.ports.searchController().invalidatePending();
    this.pinStore.detailPresentationOnly = false;
    this.pinStore.detailPreparing = false;
    this.ports.detailReadCache().clear();
    this.ports.detailReturnJourney()?.close();
    this.ports.setDetailClickedAt(0);
    this.ports.setRetainedHomeAwaitingAuth(false);
    this.ports.setRetainedHomeAwaitingFeed(false);
    this.ports.configureDocumentRetention(false);
    try {
        this.ports.controller().clearHistory();
    }
    catch (_) { }
    this.ports.setInterruptedHomePage('');
    this.ports.setHomeRecoveryAttempted(false);
    this.ports.setHomeRecoveryToken(this.ports.homeRecoveryToken() + 1);
    this.ports.closeImageLayer();
    this.ports.nativeNetwork().invalidate();
    this.ports.setNativeBackTarget('');
    this.ports.closeProfilePanel();
    this.ports.setProfileSettingsVisible(false);
    this.settingsStore.reset();
    this.inboxStore.retainedChat = undefined;
    this.inboxStore.inboxFlow = undefined;
    this.inboxStore.chatScrollOffset = 0;
    this.inboxStore.chatReturnConversation = '';
    this.ports.cancelAccountSettings();
    this.ports.setShowNativeSheet(false);
    this.ports.setActiveSheetKind('');
    this.ports.dismissPostSnack();
    this.ports.cancelHomeDetailMore();
    this.ports.clearRootTabCaches();
    this.ports.clearDetail();
    this.pinStore.detailCache.clear(); this.homeStore.imageRecovery = undefined;
    this.pinStore.clearDetailOrigins();
    this.pinStore.detailPrefetch.clear();
    this.pinStore.prefetchedImageUrls = [];
    this.pinStore.confirmedSaves.clear();
    this.boardStore.boardDetail = undefined;
    this.boardStore.presentationPage = '';
    this.boardStore.presentationOnly = false;
    this.boardStore.pendingBoardUrl = '';
    this.inboxStore.inboxFlow = undefined;
    this.ports.setPendingWebTab(-1);
    this.ports.setRetainedRootTabPending(-1);
    this.ports.setRetainedRootTabAddress('');
    this.ports.setRootTabGuardTarget(-1);
    this.ports.setDetailReturnedToRoot(false);
    this.ports.setRootTabGuardAddress('');
    this.ports.setNativeRootOnly(false);
    this.ports.setRootContentInteracted(false);
    this.ports.setRetainedHomeDocumentPending(false);
    this.ports.setRetainedHomeDocumentAddress('');
    this.ports.setTabRequestToken(this.ports.tabRequestToken() + 1);
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
    this.ports.setPendingDetailLike(undefined);
    this.pinStore.detailReturnUrl = '';
    this.boardStore.boardReturnUrl = '';
    this.boardStore.boardReturnPage = '';
    this.ports.setNativePinRoute('');
    this.ports.setPageBackToken(this.ports.pageBackToken() + 1);
    this.pinStore.detailOpeningToken++;
    this.boardStore.boardOpeningToken++;
    this.pinStore.saveUndoPin = '';
    this.pinStore.saveCancelToken++;
    this.pinStore.viewerSaveBusy = false;
    this.pinStore.detailMediaRetryToken++;
    this.pinStore.detailMediaRetryBusy = false;
    this.pinStore.feedbackUndoPin = '';
    this.ports.setAuthenticatedProfileUrl('');
    this.ports.setActiveTab(0);
    this.ports.setCurrentWebTab(0);
    this.ports.tabsController().changeIndex(0);
    this.ports.pageHistory().reset();
}

syncAuthentication(): void {
    const epoch: number = this.ports.authEpoch();
    this.ports.controller().runJavaScript('window.PinmonyAuthSync && window.PinmonyAuthSync(' + epoch.toString() + ')')
        .catch(() => PinmonyRuntimeLog.warn('Pinmony: authentication bridge unavailable'));
    if (this.ports.authCheckTimer() !== -1)
        this.ports.pageTasks().cancelTimeout(this.ports.authCheckTimer());
    this.ports.setAuthCheckTimer(this.ports.pageTasks().timeout(() => {
        if (epoch !== this.ports.authEpoch() || this.ports.authStatus() !== 'checking' || this.ports.authWebVisible())
            return;
        if (this.ports.tryEnterOfflinePreview(this.ports.navigationAddress() || this.ports.lastPageUrl() || PINTEREST_URL, 'auth-timeout'))
            return;
        this.ports.setAuthStatus('error');
        this.ports.setFailureDetails('无法确认当前会话，请重试读取');
    }, 15000));
}

retryLogin(): void {
    if (this.ports.authStatus() === 'checking' && this.ports.webPageLoading())
        return;
    const now: number = Date.now();
    if (this.ports.lastLoginRetryAt() >= 0 && now - this.ports.lastLoginRetryAt() < 5000) {
        this.ports.showNetworkNotice('会话页面正在重试，请稍后再试');
        PinmonyRuntimeLog.info('RequestPolicy: login-retry-paused');
        return;
    }
    this.ports.setLastLoginRetryAt(now);
    const target: string = this.ports.authStatus() === 'unauthenticated' || isPinterestAuthRoute(this.ports.navigationAddress()) ?
        PINTEREST_LOGIN_URL : PINTEREST_URL;
    this.ports.setAuthStatus('checking');
    this.ports.setOfflineCacheLoading(false);
    this.ports.setLoginRedirectEpoch(-1);
    this.ports.setLoadFailed(false);
    this.ports.setFailureDetails('');
    this.ports.setNavigationAddress(target);
    try {
        this.ports.controller().loadUrl(target);
    }
    catch (_) {
        this.ports.setAuthStatus('error');
        this.ports.setFailureDetails('当前会话页面暂时无法加载，请重试');
    }
}
}
