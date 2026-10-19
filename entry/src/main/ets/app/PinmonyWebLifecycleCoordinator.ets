import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyProfileStore } from 'feature_profile';
import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonySearchStore } from 'feature_search';
import { PinmonyHomeStore } from 'feature_home';
import { PinmonyNativeNetwork } from 'common_network';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { webview } from '@kit.ArkWeb';
import { PinmonyAuthStatus, isPinterestAuthRoute } from 'common_session';
import { PinmonyNavigationHistory } from './PinmonyNavigationHistory';

const PINTEREST_URL: string = 'https://www.pinterest.com/';

export interface PinmonyWebLifecycleCoordinatorPorts {
  nativeBusinessOnly?: () => boolean;
  navigationBegun: (url: string) => void;
  activeSheetKind: () => string;
  setActiveSheetKind: (value: string) => string;
  activeTab: () => number;
  authCheckTimer: () => number;
  setAuthCheckTimer: (value: number) => number;
  authEpoch: () => number;
  setAuthEpoch: (value: number) => number;
  authStatus: () => PinmonyAuthStatus;
  setAuthStatus: (value: PinmonyAuthStatus) => PinmonyAuthStatus;
  beginDetailOpening: (pinUrl: string, returnUrl?: string) => void;
  bindCurrentDetailDocument: (url: string) => void;
  businessSuspended: () => boolean;
  cancelHomeDetailMore: () => void;
  clearDetail: (preserveRead?: boolean, localOnly?: boolean) => void;
  clearInbox: () => void;
  clearProfile: (preserveWebFlow?: boolean) => void;
  clearRootTabCaches: (clearPersistentCache?: boolean) => void;
  clearRootTabGuard: (reason: string) => void;
  clearSearch: () => void;
  configureDocumentRetention: (enabled: boolean) => void;
  controller: () => webview.WebviewController;
  coordinatorTasks: () => PinmonyTaskRegistry;
  effectiveRootDocumentTarget: () => number;
  expectInbox: () => void;
  expectProfile: () => void;
  expectSearch: () => void;
  extractPinUrl: (value: string) => string;
  failureDetails: () => string;
  setFailureDetails: (value: string) => string;
  handleExternalShareTarget: (url: string) => boolean;
  handleMainFrameFailure: (url: string, code: number, info: string) => void;
  homePageKeyFromAddress: (url: string) => string;
  homeStore: () => PinmonyHomeStore;
  homeTraceCardsPageKey: () => string;
  setHomeTraceCardsPageKey: (value: string) => string;
  homeTracePageKey: () => string;
  setHomeTracePageKey: (value: string) => string;
  ignoreSupersededDetailDocument: (url: string) => boolean;
  inboxStore: () => PinmonyInboxStore;
  inboxUrlFromAddress: (address: string) => string;
  installDownloadDelegate: () => void;
  isHomeRootAddress: (address: string) => boolean;
  isStaleRootDocumentBegin: (address: string) => boolean;
  lastDocumentBeginAt: () => number;
  setLastDocumentBeginAt: (value: number) => number;
  lastDocumentBeginUrl: () => string;
  setLastDocumentBeginUrl: (value: string) => string;
  lastPageUrl: () => string;
  setLastPageUrl: (value: string) => string;
  loadFailed: () => boolean;
  setLoadFailed: (value: boolean) => boolean;
  logPageLifecycle: (event: string, detail?: string) => void;
  logoutAwaitingLogin: () => boolean;
  setLogoutAwaitingLogin: (value: boolean) => boolean;
  markRootDocumentReady: () => void;
  nativeBackTarget: () => string;
  nativeNetwork: () => PinmonyNativeNetwork;
  nativeRootOnly: () => boolean;
  notifyMenuStateChanged: () => void;
  navigationAddress: () => string;
  setNavigationAddress: (value: string) => string;
  pageHistory: () => PinmonyNavigationHistory;
  pageTasks: () => PinmonyTaskRegistry;
  pendingWebTab: () => number;
  pinIdentity: (value: string) => string;
  pinStore: () => PinmonyPinStore;
  prepareHomeForPageBegin: (url: string, retainedDocument?: boolean) => void;
  profileStore: () => PinmonyProfileStore;
  profileUrlFromAddress: (address: string) => string;
  recordPageNavigation: (url: string, mode?: string) => void;
  refreshWebNavigation: () => Promise<void>;
  resetAuthenticatedContent: () => void;
  restoreInbox: (address: string) => boolean;
  restoreProfile: (address: string) => boolean;
  restoreRetainedSearch: (pageKey: string) => boolean;
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
  rootTabGuardTarget: () => number;
  rootTabIndexFromAddress: (address: string) => number;
  rootTabKindFromAddress: (address: string) => string;
  searchStore: () => PinmonySearchStore;
  searchUrlFromAddress: (address: string) => string;
  showNativeSheet: () => boolean;
  setShowNativeSheet: (value: boolean) => boolean;
  showNativeTabs: () => boolean;
  setShowNativeTabs: (value: boolean) => boolean;
  staleRootDocumentTarget: () => number;
  syncAuthentication: () => void;
  syncBoardRoute: (address: string) => void;
  tabRequestToken: () => number;
  tryEnterOfflinePreview: (failedUrl: string, reason?: string) => boolean;
  webPageLoadFinishedAt: () => number;
  setWebPageLoadFinishedAt: (value: number) => number;
  webPageLoading: () => boolean;
  setWebPageLoading: (value: boolean) => boolean;
}

// Product Web event orchestration; native payload adapters and the stable Web node remain in Index.
export class PinmonyWebLifecycleCoordinator {
  private readonly ports: PinmonyWebLifecycleCoordinatorPorts;
  private readonly homeStore: PinmonyHomeStore;
  private readonly searchStore: PinmonySearchStore;
  private readonly inboxStore: PinmonyInboxStore;
  private readonly profileStore: PinmonyProfileStore;
  private readonly pinStore: PinmonyPinStore;
  constructor(ports: PinmonyWebLifecycleCoordinatorPorts) {
    this.ports = ports;
    this.homeStore = ports.homeStore();
    this.searchStore = ports.searchStore();
    this.inboxStore = ports.inboxStore();
    this.profileStore = ports.profileStore();
    this.pinStore = ports.pinStore();
  }
controllerAttached(): void {
    this.ports.installDownloadDelegate();
    this.ports.configureDocumentRetention(this.ports.authStatus() === 'authenticated');
}

pageBegin(url: string): void {
    if(this.ports.nativeBusinessOnly?.() && this.ports.authStatus() === 'authenticated' && !isPinterestAuthRoute(url)){
      try {if(this.ports.controller().getUrl().split('#')[0] !== url.split('#')[0])return;}catch (_) {return;}
      if(this.ports.lastDocumentBeginUrl() === url && Date.now() - this.ports.lastDocumentBeginAt() < 1500 && this.ports.webPageLoading())return;
      this.ports.setLastDocumentBeginUrl(url);this.ports.setLastDocumentBeginAt(Date.now());this.ports.setAuthEpoch(this.ports.authEpoch() + 1);this.ports.nativeNetwork().invalidateDocument();this.ports.setWebPageLoading(true);
      PinmonyRuntimeLog.info('NativeRouteTrace: background document changed authOnly=true');return;
    }
    this.ports.navigationBegun(url);
    if (this.ports.ignoreSupersededDetailDocument(url))
        return;
    if (this.ports.nativeRootOnly() && !isPinterestAuthRoute(url)) {
        // Keep the selected screen, but a real hidden document change
        // still invalidates controls and in-flight session reads.
        try {
            if (this.ports.pageHistory().key(url) === this.ports.pageHistory().key(this.ports.controller().getUrl())) {
                this.ports.setAuthEpoch(this.ports.authEpoch() + 1);
                this.ports.nativeNetwork().invalidateDocument();
                this.homeStore.homeActionsReady = false;
                this.searchStore.searchActionsReady = false;
                this.searchStore.searchInputReady = false;
                this.inboxStore.inboxActionsReady = false;
                this.inboxStore.inboxSectionReady = false;
                this.profileStore.profileActionsReady = false;
            }
        }
        catch (_) { }
        PinmonyRuntimeLog.info('RootTabTrace: background-page-begin ignored mode=presentation-only');
        return;
    }
    if (this.pinStore.detailPresentationOnly && !isPinterestAuthRoute(url)) {
        PinmonyRuntimeLog.info('PinmonyReturn: background navigation ignored for cached parent');
        return;
    }
    const beginAt: number = Date.now();
    const documentKind: string = isPinterestAuthRoute(url) ? 'auth' :
        this.ports.rootTabKindFromAddress(url);
    const documentRoot: number = this.ports.rootTabIndexFromAddress(url);
    const targetPinUrlAtBegin: string = this.ports.extractPinUrl(url);
    const rootRequestTarget: number = this.ports.staleRootDocumentTarget();
    const rootGuardConfirmed: boolean = this.ports.rootTabGuardTarget() >= 0 &&
        this.ports.rootTabGuardTarget() === documentRoot;
    const explicitDetailOpening: boolean = !!this.pinStore.detailOpeningPin ||
        (!!this.homeStore.pendingHomeMorePin && !!targetPinUrlAtBegin &&
            this.ports.pinIdentity(this.homeStore.pendingHomeMorePin) === this.ports.pinIdentity(targetPinUrlAtBegin));
    const staleSecondaryDocument: boolean = rootRequestTarget >= 0 &&
        !!targetPinUrlAtBegin && !explicitDetailOpening && !this.ports.nativeBackTarget();
    const staleRootDocument: boolean = this.ports.isStaleRootDocumentBegin(url);
    this.ports.logPageLifecycle('web-page-begin', 'kind=' + documentKind +
        (staleRootDocument ? ' staleRoot=true' : staleSecondaryDocument ? ' staleSecondary=true' : ''));
    // A root-tab request can leave one late Pin document callback in
    // the WebView history. It is not a new user action; accepting it
    // would reopen the previous detail over the selected root tab.
    if (staleSecondaryDocument) {
        PinmonyRuntimeLog.info('RootTabTrace: stale-secondary-page-begin ignored targetTab=' +
            this.ports.staleRootDocumentTarget().toString());
        return;
    }
    if (staleRootDocument) {
        PinmonyRuntimeLog.info('RootTabTrace: stale-page-begin ignored targetTab=' +
            this.ports.effectiveRootDocumentTarget().toString() + ' kind=' + documentKind +
            ' documentTab=' + documentRoot.toString());
        return;
    }
    if (documentRoot >= 0) {
        PinmonyRuntimeLog.info('RootTabTrace: root-visible targetTab=' + documentRoot.toString() +
            ' kind=' + documentKind + ' pendingTarget=' + this.ports.staleRootDocumentTarget().toString());
    }
    const duplicateBegin: boolean = this.ports.lastDocumentBeginUrl() === url &&
        beginAt - this.ports.lastDocumentBeginAt() < 1500;
    PinmonyRuntimeLog.info('StartupTrace: document begin ' +
        (this.ports.isHomeRootAddress(url) ? 'home' : isPinterestAuthRoute(url) ? 'auth' : 'other') +
        ' duplicate=' + duplicateBegin.toString() + ' epoch=' + this.ports.authEpoch().toString());
    this.ports.setLastDocumentBeginUrl(url);
    this.ports.setLastDocumentBeginAt(beginAt);
    if (this.ports.isHomeRootAddress(url)) {
        this.ports.setHomeTracePageKey(this.ports.homePageKeyFromAddress(url));
        this.ports.setHomeTraceCardsPageKey('');
    }
    else {
        this.ports.setHomeTracePageKey('');
        this.ports.setHomeTraceCardsPageKey('');
    }
    if (duplicateBegin && this.ports.webPageLoading())
        return;
    if (this.ports.logoutAwaitingLogin()) {
        if (!isPinterestAuthRoute(url))
            return;
        this.ports.setLogoutAwaitingLogin(false);
    }
    if (this.ports.authStatus() !== 'authenticated') {
    }
    if (!isPinterestAuthRoute(url) && this.ports.nativeBackTarget() &&
        this.ports.pageHistory().key(url) !== this.ports.pageHistory().key(this.ports.nativeBackTarget())) {
        PinmonyRuntimeLog.info('PinmonyReturn: ignored late source navigation');
        return;
    }
    if (!isPinterestAuthRoute(url) && this.pinStore.detailOpeningPin &&
        this.ports.pinIdentity(this.ports.extractPinUrl(url)) !== this.ports.pinIdentity(this.pinStore.detailOpeningPin))
        return;
    this.ports.setAuthEpoch(this.ports.authEpoch() + 1);
    this.ports.setRetainedHomeAwaitingAuth(false);
    this.ports.setRetainedHomeAwaitingFeed(false);
    this.ports.nativeNetwork().invalidateDocument();
    if (this.ports.authCheckTimer() !== -1)
        this.ports.pageTasks().cancelTimeout(this.ports.authCheckTimer());
    if (isPinterestAuthRoute(url)) {
        if (this.ports.authStatus() === 'authenticated')
            this.ports.resetAuthenticatedContent();
        this.ports.setAuthStatus('checking');
    }
    const loadingEpoch: number = this.ports.authEpoch();
    if (this.ports.authStatus() !== 'authenticated') {
        this.ports.setAuthCheckTimer(this.ports.pageTasks().timeout(() => {
            if (this.ports.authEpoch() !== loadingEpoch || !this.ports.webPageLoading())
                return;
            if (this.ports.tryEnterOfflinePreview(url, 'page-timeout'))
                return;
            this.ports.setAuthStatus('error');
            this.ports.setFailureDetails(PinmonyI18n.message("pm_session_page_loading_timed_out_please_retry_6a97119e"));
        }, 20000));
    }
    this.ports.syncBoardRoute(url);
    this.homeStore.customHomeMenuToken++;
    this.homeStore.customHomeMenu = undefined;
    this.ports.notifyMenuStateChanged();
    this.ports.setWebPageLoading(true);
    this.ports.setWebPageLoadFinishedAt(0);
    const targetSearchPage: string = this.ports.searchUrlFromAddress(url);
    const targetPinUrl: string = targetPinUrlAtBegin;
    if (this.homeStore.pendingHomeMorePin &&
        this.ports.pinIdentity(targetPinUrl) !== this.ports.pinIdentity(this.homeStore.pendingHomeMorePin)) {
        this.ports.cancelHomeDetailMore();
    }
    this.ports.recordPageNavigation(url);
    const keepSearchForTargetPin: boolean = !!targetPinUrl && !!this.searchStore.search &&
        this.searchStore.searchReturnPageKey === this.searchStore.search.pageKey;
    if (targetPinUrl && !this.ports.extractPinUrl(this.ports.lastPageUrl()) && !this.pinStore.detailReturnUrl) {
        this.pinStore.detailReturnUrl = this.ports.lastPageUrl() || PINTEREST_URL;
    }
    const expectedProfile: boolean = this.profileStore.profileLoading &&
        (this.ports.activeTab() === 3 || this.ports.pendingWebTab() === 3) || this.profileStore.profileWebFlow;
    if (this.profileStore.profileWebFlow && !this.ports.profileUrlFromAddress(url)) {
        this.profileStore.profileFlowLeftPage = true;
    }
    if (targetPinUrl)
        this.ports.beginDetailOpening(targetPinUrl);
    else
        this.ports.clearDetail();
    this.ports.clearProfile(this.profileStore.profileWebFlow && !this.ports.profileUrlFromAddress(url));
    if (/\/(?:login|logout|signup)(?:\/|[?#]|$)/i.test(url))
        this.profileStore.profileCache.clear();
    this.ports.restoreProfile(url);
    this.ports.clearInbox();
    this.ports.restoreInbox(url);
    const retainingRootDocument: boolean = this.ports.retainedRootTabPending() >= 0 &&
        this.ports.retainedRootTabPending() === documentRoot &&
        (this.ports.retainedRootTabPending() === this.ports.pendingWebTab() || rootGuardConfirmed) &&
        this.ports.pageHistory().key(url) === this.ports.pageHistory().key(this.ports.retainedRootTabAddress());
    const retainingHomeDocument: boolean = this.ports.retainedHomeDocumentPending() &&
        this.ports.isHomeRootAddress(url) && !!this.homeStore.cachedHome?.pins.length &&
        this.homeStore.cachedHome?.pageKey === this.ports.homePageKeyFromAddress(url) &&
        this.ports.pageHistory().key(url) === this.ports.pageHistory().key(this.ports.retainedHomeDocumentAddress());
    if (retainingRootDocument) {
        PinmonyRuntimeLog.info('RootTabTrace: retained-document targetTab=' +
            this.ports.retainedRootTabPending().toString());
        this.ports.setRetainedRootTabPending(-1);
        this.ports.setRetainedRootTabAddress('');
    }
    if (rootGuardConfirmed)
        this.ports.clearRootTabGuard('root-visible');
    if (retainingHomeDocument) {
        this.ports.setRetainedHomeDocumentPending(false);
        this.ports.setRetainedHomeDocumentAddress('');
    }
    this.ports.prepareHomeForPageBegin(url, retainingHomeDocument);
    if (retainingHomeDocument) {
        // The native home snapshot is already visible while ArkWeb
        // restores the hidden route. Pause the new document's home
        // observer/API demand so a fresh feed cannot replace the
        // returned cards before the user explicitly refreshes.
        try { this.ports.controller().runJavaScript('window.PinmonyHomePauseForReturn && window.PinmonyHomePauseForReturn()')
            .then(() => PinmonyRuntimeLog.info('RootTabTrace: retained-home-guarded'))
            .catch(() => PinmonyRuntimeLog.warn('RootTabTrace: retained-home-guard-unavailable')); }
        catch (_) { PinmonyRuntimeLog.warn('RootTabTrace: retained-home-guard-unavailable'); }
    }
    if (targetSearchPage) {
        if (!this.searchStore.search || this.searchStore.search.pageKey !== targetSearchPage)
            this.ports.restoreRetainedSearch(targetSearchPage);
        const hasTargetSearch: boolean = !!this.searchStore.search && this.searchStore.search.pageKey === targetSearchPage;
        const hasCachedSearch: boolean = hasTargetSearch && this.searchStore.search?.kind === 'state';
        if (hasCachedSearch) {
            this.searchStore.searchLoading = false;
            this.searchStore.searchError = '';
        }
        else {
            if (!hasTargetSearch) this.ports.clearSearch();
            this.searchStore.searchLoading = true;
            this.searchStore.searchError = '';
        }
        this.ports.setShowNativeTabs(true);
        if (!hasCachedSearch) {
            const token: number = this.ports.tabRequestToken(), epoch: number = this.ports.authEpoch();
            this.ports.coordinatorTasks().timeout((): void => {
                if (!this.ports.businessSuspended() && epoch === this.ports.authEpoch() && this.ports.activeTab() === 1 &&
                    token === this.ports.tabRequestToken() && this.currentDocumentIs(url))
                    this.ports.expectSearch();
            }, 350);
        }
    }
    else if (keepSearchForTargetPin) {
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '';
    }
    else {
        this.ports.clearSearch();
    }
    if (this.ports.inboxUrlFromAddress(url))
        this.ports.expectInbox();
    if (/\/(?:login|logout|signup)(?:\/|[?#]|$)/i.test(url))
        this.ports.clearRootTabCaches();
    if (this.ports.profileUrlFromAddress(url) &&
        (expectedProfile || /\/_(?:saved|created)(?:\/|[?#]|$)/i.test(url))) {
        this.ports.expectProfile();
    }
    const keepPublish: boolean = this.profileStore.publishLoading && this.ports.activeSheetKind() === 'publish' &&
        !!this.ports.profileUrlFromAddress(url) && this.ports.profileUrlFromAddress(url) === this.profileStore.profile?.profileUrl;
    if (!keepPublish) {
        this.ports.setShowNativeSheet(false);
        this.ports.setActiveSheetKind('');
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
    this.ports.setLastPageUrl(url);
    this.ports.setNavigationAddress(url);
    if (targetPinUrl)
        this.ports.bindCurrentDetailDocument(url);
    this.ports.setLoadFailed(false);
    this.ports.setFailureDetails('');
    if (url.includes('/pin/') || url.includes('/login') || url.includes('/signup')) {
        this.ports.setShowNativeTabs(false);
    }
}

private currentDocumentIs(url: string): boolean {
    if (!url) return false;
    try { return this.ports.controller().getUrl() === url; }
    catch (_) { return false; }
}

pageEnd(): void {
    if(this.ports.nativeBusinessOnly?.() && this.ports.authStatus() === 'authenticated'){this.ports.setWebPageLoading(false);this.ports.setWebPageLoadFinishedAt(Date.now());this.ports.syncAuthentication();return;}
    this.ports.logPageLifecycle('web-page-end');
    try {
        if (this.ports.ignoreSupersededDetailDocument(this.ports.controller().getUrl())) {
            this.ports.setWebPageLoading(false);
            return;
        }
    }
    catch (_) { }
    this.ports.markRootDocumentReady();
    if (this.ports.nativeRootOnly()) {
        this.ports.syncAuthentication();
        return;
    }
    this.ports.setWebPageLoading(false);
    this.ports.setWebPageLoadFinishedAt(Date.now());
    this.ports.refreshWebNavigation();
    try {
        this.ports.bindCurrentDetailDocument(this.ports.controller().getUrl());
    }
    catch (_) { }
    this.ports.syncAuthentication();
}

consoleMessage(message: string): boolean {
    if (message.length > 512) return false;
    if (/^HomePaginationTrace: phase=(request|merged|failed) append=(true|false)( (count|incoming|added|elapsedMs)=\d+)*$/.test(message)) {
        PinmonyRuntimeLog.info(message);
    }
    if (message === 'RequestPolicy: read-merged') {
        PinmonyRuntimeLog.info('RequestPolicy: read-merged');
    }
    if (/^PinmonyNetworkDiagnostic: fetch observer failed (TypeError|SyntaxError|AbortError|Error|UnknownError)$/.test(message)) {
        PinmonyRuntimeLog.warn(message);
    }
    if (/^PinmonyDiagnostic: (save request|save confirmed|undo save request|undo save confirmed)$/.test(message)) {
        PinmonyRuntimeLog.info('Web: ' + message);
    }
    if (/^PinmonyDiagnostic: (video\.resolve\.(started|ready source=(resource|relay|graphql)|failed reason=(missing-session|video-request-failed|video-response-failed|video-source-missing|network-or-parse))|video\.retry\.requested|video\.refresh\.(started|resource\.validated|address\.ready changed=(true|false)|failed reason=(timeout|missing-session|video-request-failed|video-response-failed|video-source-missing|network-or-parse)))$/.test(message)) {
        PinmonyRuntimeLog.info('VideoApiTrace: openId=' + this.pinStore.detailOpeningToken.toString() + ' ' + message);
    }
    return false;
}

mainFrameError(url: string, code: number, info: string): void {
    if(this.ports.nativeBusinessOnly?.() && this.ports.authStatus() === 'authenticated' && !isPinterestAuthRoute(url)){this.ports.setWebPageLoading(false);PinmonyRuntimeLog.info('NativeRouteTrace: background document failure ignored authOnly=true');return;}
    let knownOtherDocument: boolean = false;
    try {
      const currentUrl: string = this.ports.controller().getUrl();
      knownOtherDocument = !!url && !!currentUrl && url.split('#')[0] !== currentUrl.split('#')[0];
    } catch (_) { /* A missing platform URL is not proof of a stale error. */ }
    if (url && (knownOtherDocument || this.ports.nativeBackTarget() &&
        this.ports.pageHistory().key(url) !== this.ports.pageHistory().key(this.ports.nativeBackTarget()))) {
      PinmonyRuntimeLog.info('Web: stale main frame error ignored'); return;
    }
    if (this.pinStore.detailPresentationOnly)
        return;
    {
        const errorInfo: string = info;
        const safeInfo: string = /^(?:ERR_[A-Z0-9_]+|[A-Za-z0-9_-]{1,32})$/.test(errorInfo) ? errorInfo : 'classified';
        PinmonyRuntimeLog.warn('Web: main frame error code=' + code.toString() +
            ' info=' + safeInfo + ' urlKind=' +
            (this.ports.isHomeRootAddress(url) ? 'home' :
                isPinterestAuthRoute(url) ? 'auth' : 'other'));
        this.ports.handleMainFrameFailure(url || this.ports.lastPageUrl(), code, info);
    }
}

overrideUrl(url: string): boolean {
    this.ports.navigationBegun(url);
    if (this.ports.authStatus() !== 'authenticated')
        return false;
    return this.ports.handleExternalShareTarget(url);
}

interceptLoad(url: string, mainFrame: boolean): boolean {
    if (mainFrame) this.ports.navigationBegun(url);
    if (!mainFrame || this.ports.authStatus() !== 'authenticated') {
        return false;
    }
    return this.ports.handleExternalShareTarget(url);
}
}
