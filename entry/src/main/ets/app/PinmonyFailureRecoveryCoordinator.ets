import { PinmonySearchStore, PinmonySearchSnapshot } from 'feature_search';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyBoardStore } from 'feature_board';
import { PinmonyRootContextCoordinator } from '../app/PinmonyRootContextCoordinator';
import { PinmonyInboxStore, PinmonyInboxSnapshot } from 'feature_inbox';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyProfileStore, PinmonyProfileSnapshot } from 'feature_profile';
import { PinmonyHomeStore, PinmonyHomeSnapshot } from 'feature_home';
import { PinmonyNativeNetwork } from 'common_network';
import { webview } from '@kit.ArkWeb';
import { PinmonyAuthStatus, isPinterestAuthRoute } from 'common_session';
import { HdsTabsController } from '@kit.UIDesignKit';
import { PinmonyNavigationHistory } from '../app/PinmonyNavigationHistory';

export interface PinmonyFailureRecoveryCoordinatorPorts {
  nativeRootOnly: () => boolean;
  logoutAwaitingLogin: () => boolean;
  authStatus: () => PinmonyAuthStatus;
  setAuthStatus: (value: PinmonyAuthStatus) => void;
  staleRootDocumentTarget: () => number;
  extractPinUrl: (value: string) => string;
  pinStore: () => PinmonyPinStore;
  nativeBackTarget: () => string;
  setNativeBackTarget: (value: string) => void;
  rootTabIndexFromAddress: (address: string) => number;
  effectiveRootDocumentTarget: () => number;
  activeTab: () => number;
  setActiveTab: (value: number) => void;
  protectedDetailAddress: () => string;
  rootReadToken: () => number;
  tabRequestToken: () => number;
  setTabRequestToken: (value: number) => void;
  rootReadAddress: () => string;
  navigationAddress: () => string;
  setNavigationAddress: (value: string) => void;
  homePageKeyFromAddress: (url: string) => string;
  homeStore: () => PinmonyHomeStore;
  searchUrlFromAddress: (address: string) => string;
  searchStore: () => PinmonySearchStore;
  inboxUrlFromAddress: (address: string) => string;
  inboxStore: () => PinmonyInboxStore;
  profileUrlFromAddress: (address: string) => string;
  profileStore: () => PinmonyProfileStore;
  interruptedHomePage: () => string;
  setInterruptedHomePage: (value: string) => void;
  homeRecoveryAttempted: () => boolean;
  setHomeRecoveryAttempted: (value: boolean) => void;
  homePresentationPageKey: () => string;
  isHomeRootAddress: (address: string) => boolean;
  showNativeSheet: () => boolean;
  homeRecoveryToken: () => number;
  setHomeRecoveryToken: (value: number) => void;
  authEpoch: () => number;
  pageBackToken: () => number;
  setPageBackToken: (value: number) => void;
  coordinatorTasks: () => PinmonyTaskRegistry;
  pageHistory: () => PinmonyNavigationHistory;
  nativeNetwork: () => PinmonyNativeNetwork;
  lastPageUrl: () => string;
  setLastPageUrl: (value: string) => void;
  expectHome: () => void;
  controller: () => webview.WebviewController;
  businessSuspended: () => boolean;
  setBusinessSuspended: (value: boolean) => void;
  showNetworkNotice: (message?: string) => void;
  webPageLoading: () => boolean;
  setWebPageLoading: (value: boolean) => void;
  webPageLoadFinishedAt: () => number;
  setWebPageLoadFinishedAt: (value: number) => void;
  tryEnterOfflinePreview: (failedUrl: string, reason?: string) => boolean;
  loadFailed: () => boolean;
  setLoadFailed: (value: boolean) => void;
  failureDetails: () => string;
  setFailureDetails: (value: string) => void;
  boardUrlFromAddress: (address: string) => string;
  boardStore: () => PinmonyBoardStore;
  pinIdentity: (value: string) => string;
  pendingWebTab: () => number;
  setPendingWebTab: (value: number) => void;
  clearInbox: () => void;
  clearDetail: (preserveRead?: boolean, localOnly?: boolean) => void;
  tabsController: () => HdsTabsController;
  clearHome: () => void;
  restoreRetainedSearch: (pageKey: string) => boolean;
  clearSearch: () => void;
  rootContextCoordinator: () => PinmonyRootContextCoordinator;
}

export class PinmonyFailureRecoveryCoordinator {
  private readonly ports: PinmonyFailureRecoveryCoordinatorPorts;
  constructor(ports: PinmonyFailureRecoveryCoordinatorPorts) { this.ports = ports; }

  private get nativeRootOnly(): boolean { return this.ports.nativeRootOnly(); }
  private get logoutAwaitingLogin(): boolean { return this.ports.logoutAwaitingLogin(); }
  private get authStatus(): PinmonyAuthStatus { return this.ports.authStatus(); }
  private set authStatus(value: PinmonyAuthStatus) { this.ports.setAuthStatus(value); }
  private get staleRootDocumentTarget(): () => number { return this.ports.staleRootDocumentTarget; }
  private get extractPinUrl(): (value: string) => string { return this.ports.extractPinUrl; }
  private get pinStore(): PinmonyPinStore { return this.ports.pinStore(); }
  private get nativeBackTarget(): string { return this.ports.nativeBackTarget(); }
  private set nativeBackTarget(value: string) { this.ports.setNativeBackTarget(value); }
  private get rootTabIndexFromAddress(): (address: string) => number { return this.ports.rootTabIndexFromAddress; }
  private get effectiveRootDocumentTarget(): () => number { return this.ports.effectiveRootDocumentTarget; }
  private get activeTab(): number { return this.ports.activeTab(); }
  private set activeTab(value: number) { this.ports.setActiveTab(value); }
  private get protectedDetailAddress(): () => string { return this.ports.protectedDetailAddress; }
  private get rootReadToken(): number { return this.ports.rootReadToken(); }
  private get tabRequestToken(): number { return this.ports.tabRequestToken(); }
  private set tabRequestToken(value: number) { this.ports.setTabRequestToken(value); }
  private get rootReadAddress(): string { return this.ports.rootReadAddress(); }
  private get navigationAddress(): string { return this.ports.navigationAddress(); }
  private set navigationAddress(value: string) { this.ports.setNavigationAddress(value); }
  private get homePageKeyFromAddress(): (url: string) => string { return this.ports.homePageKeyFromAddress; }
  private get homeStore(): PinmonyHomeStore { return this.ports.homeStore(); }
  private get searchUrlFromAddress(): (address: string) => string { return this.ports.searchUrlFromAddress; }
  private get searchStore(): PinmonySearchStore { return this.ports.searchStore(); }
  private get inboxUrlFromAddress(): (address: string) => string { return this.ports.inboxUrlFromAddress; }
  private get inboxStore(): PinmonyInboxStore { return this.ports.inboxStore(); }
  private get profileUrlFromAddress(): (address: string) => string { return this.ports.profileUrlFromAddress; }
  private get profileStore(): PinmonyProfileStore { return this.ports.profileStore(); }
  private get interruptedHomePage(): string { return this.ports.interruptedHomePage(); }
  private set interruptedHomePage(value: string) { this.ports.setInterruptedHomePage(value); }
  private get homeRecoveryAttempted(): boolean { return this.ports.homeRecoveryAttempted(); }
  private set homeRecoveryAttempted(value: boolean) { this.ports.setHomeRecoveryAttempted(value); }
  private get homePresentationPageKey(): () => string { return this.ports.homePresentationPageKey; }
  private get isHomeRootAddress(): (address: string) => boolean { return this.ports.isHomeRootAddress; }
  private get showNativeSheet(): boolean { return this.ports.showNativeSheet(); }
  private get homeRecoveryToken(): number { return this.ports.homeRecoveryToken(); }
  private set homeRecoveryToken(value: number) { this.ports.setHomeRecoveryToken(value); }
  private get authEpoch(): number { return this.ports.authEpoch(); }
  private get pageBackToken(): number { return this.ports.pageBackToken(); }
  private set pageBackToken(value: number) { this.ports.setPageBackToken(value); }
  private get coordinatorTasks(): PinmonyTaskRegistry { return this.ports.coordinatorTasks(); }
  private get pageHistory(): PinmonyNavigationHistory { return this.ports.pageHistory(); }
  private get nativeNetwork(): PinmonyNativeNetwork { return this.ports.nativeNetwork(); }
  private get lastPageUrl(): string { return this.ports.lastPageUrl(); }
  private set lastPageUrl(value: string) { this.ports.setLastPageUrl(value); }
  private get expectHome(): () => void { return this.ports.expectHome; }
  private get controller(): webview.WebviewController { return this.ports.controller(); }
  private get businessSuspended(): boolean { return this.ports.businessSuspended(); }
  private set businessSuspended(value: boolean) { this.ports.setBusinessSuspended(value); }
  private get showNetworkNotice(): (message?: string) => void { return this.ports.showNetworkNotice; }
  private get webPageLoading(): boolean { return this.ports.webPageLoading(); }
  private set webPageLoading(value: boolean) { this.ports.setWebPageLoading(value); }
  private get webPageLoadFinishedAt(): number { return this.ports.webPageLoadFinishedAt(); }
  private set webPageLoadFinishedAt(value: number) { this.ports.setWebPageLoadFinishedAt(value); }
  private get tryEnterOfflinePreview(): (failedUrl: string, reason?: string) => boolean { return this.ports.tryEnterOfflinePreview; }
  private get loadFailed(): boolean { return this.ports.loadFailed(); }
  private set loadFailed(value: boolean) { this.ports.setLoadFailed(value); }
  private get failureDetails(): string { return this.ports.failureDetails(); }
  private set failureDetails(value: string) { this.ports.setFailureDetails(value); }
  private get boardUrlFromAddress(): (address: string) => string { return this.ports.boardUrlFromAddress; }
  private get boardStore(): PinmonyBoardStore { return this.ports.boardStore(); }
  private get pinIdentity(): (value: string) => string { return this.ports.pinIdentity; }
  private get pendingWebTab(): number { return this.ports.pendingWebTab(); }
  private set pendingWebTab(value: number) { this.ports.setPendingWebTab(value); }
  private get clearInbox(): () => void { return this.ports.clearInbox; }
  private get clearDetail(): (preserveRead?: boolean, localOnly?: boolean) => void { return this.ports.clearDetail; }
  private get tabsController(): HdsTabsController { return this.ports.tabsController(); }
  private get clearHome(): () => void { return this.ports.clearHome; }
  private get restoreRetainedSearch(): (pageKey: string) => boolean { return this.ports.restoreRetainedSearch; }
  private get clearSearch(): () => void { return this.ports.clearSearch; }
  private get rootContextCoordinator(): PinmonyRootContextCoordinator { return this.ports.rootContextCoordinator(); }

  isCurrentPageFailure(url: string): boolean {
    if (this.nativeRootOnly && !isPinterestAuthRoute(url)) return false;
    if (this.logoutAwaitingLogin && !isPinterestAuthRoute(url)) return false;
    if (this.authStatus !== 'authenticated') return true;
    if (this.staleRootDocumentTarget() >= 0 && this.extractPinUrl(url) &&
        !this.pinStore.detailOpeningPin && !this.nativeBackTarget) {
      PinmonyRuntimeLog.info('RootTabTrace: ignored-secondary-failure targetTab=' +
        this.staleRootDocumentTarget().toString());
      return false;
    }
    const failedRoot: number = this.rootTabIndexFromAddress(url);
    if (failedRoot >= 0 && failedRoot !== this.effectiveRootDocumentTarget()) {
      PinmonyRuntimeLog.info('RootTabTrace: ignored-root-failure failedTab=' + failedRoot.toString() +
        ' activeTab=' + this.activeTab.toString() + ' pendingTarget=' + this.staleRootDocumentTarget().toString());
      return false;
    }
    const expected: string = this.nativeBackTarget || this.protectedDetailAddress() ||
      (this.rootReadToken >= 0 && this.rootReadToken === this.tabRequestToken ? this.rootReadAddress : '') ||
      this.navigationAddress;
    return !expected || url === expected;
  }

  retainRootSnapshotAfterFailure(failedRoot: number, url: string, code: number): boolean {
    const message: string = this.describeFailure(url, code);
    if (failedRoot === 0) {
      const pageKey: string = this.homePageKeyFromAddress(url);
      const snapshot: PinmonyHomeSnapshot | undefined = this.homeStore.cachedHome?.pageKey === pageKey ?
        this.homeStore.cachedHome : this.homeStore.home?.pageKey === pageKey ? this.homeStore.home : undefined;
      if (!snapshot || snapshot.pins.length === 0) return false;
      this.homeStore.home = snapshot;
      this.homeStore.homeLoading = false;
      this.homeStore.homeRefreshing = false;
      this.homeStore.homeActionsReady = false;
      this.homeStore.homeError = message || '首页连接失败，请重试';
    } else if (failedRoot === 1) {
      const pageKey: string = this.searchUrlFromAddress(url);
      const snapshot: PinmonySearchSnapshot | undefined = this.searchStore.search?.pageKey === pageKey ?
        this.searchStore.search : this.searchStore.retainedSearch?.pageKey === pageKey ? this.searchStore.retainedSearch : undefined;
      if (!snapshot || (snapshot.results.length === 0 && snapshot.heroes.length === 0 && snapshot.ideaSections.length === 0)) return false;
      this.searchStore.search = snapshot;
      this.searchStore.searchLoading = false;
      this.searchStore.searchActionsReady = false;
      this.searchStore.searchInputReady = false;
      this.searchStore.searchError = message || '搜索连接失败，请重试';
    } else if (failedRoot === 2) {
      const pageUrl: string = this.inboxUrlFromAddress(url);
      const snapshot: PinmonyInboxSnapshot | undefined = this.inboxStore.inbox?.pageUrl === pageUrl ?
        this.inboxStore.inbox : undefined;
      if (!snapshot || (snapshot.items.length === 0 && snapshot.contacts.length === 0)) return false;
      this.inboxStore.inboxLoading = false;
      this.inboxStore.inboxActionsReady = false;
      this.inboxStore.inboxRetainedContent = true;
      this.inboxStore.inboxError = message || '收件箱连接失败，请重试';
    } else if (failedRoot === 3) {
      const profileUrl: string = this.profileUrlFromAddress(url);
      const snapshot: PinmonyProfileSnapshot | undefined = this.profileStore.profile?.profileUrl === profileUrl ?
        this.profileStore.profile : undefined;
      if (!snapshot || (snapshot.boards.length === 0 && snapshot.createdPins.length === 0 && !snapshot.displayName)) return false;
      this.profileStore.profileSwitching = false;
      this.profileStore.profileLoading = false;
      this.profileStore.profileActionsReady = false;
      this.profileStore.profileError = message || '资料连接失败，请重试';
    } else {
      return false;
    }
    PinmonyRuntimeLog.warn('RootTabTrace: snapshot-retained-after-failure targetTab=' +
      failedRoot.toString() + ' actionsReady=false');
    return true;
  }

  scheduleInterruptedHomeRecovery(): void {
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
    this.coordinatorTasks.timeout(() => {
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
      PinmonyRuntimeLog.info('HomeRecovery: reloading interrupted home document');
      try {
        this.controller.loadUrl(page);
      } catch (_) {
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = '首页连接失败，请重试';
        PinmonyRuntimeLog.warn('HomeRecovery: reload unavailable, manual retry retained');
      }
    }, 250);
  }

  handleMainFrameFailure(url: string, code: number, info: string): void { try {
    if (!this.isCurrentPageFailure(url)) {
      PinmonyRuntimeLog.info('PinmonyReturn: ignored obsolete main frame failure, code ' + code.toString());
      return;
    }
    PinmonyRuntimeLog.warn('NavigationFailureTrace: epoch=' + this.authEpoch + ' targetTab=' + this.effectiveRootDocumentTarget().toString() + ' preparing=' + (this.rootReadToken === this.tabRequestToken).toString() + ' foreground=' + (!this.businessSuspended).toString());
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
      PinmonyRuntimeLog.warn('HomeRecovery: certificate failure; manual retry required');
    }
    if (this.authStatus !== 'authenticated') {
      if (this.tryEnterOfflinePreview(url, 'network-failure')) return;
      this.authStatus = 'error';
      this.loadFailed = true;
      this.failureDetails = this.describeFailure(url, code);
      return;
    }
    const failedBoard: string = this.boardUrlFromAddress(url);
    if (failedBoard && this.boardStore.boardDetail?.pageKey === failedBoard) {
      this.boardStore.presentationPage = failedBoard;
      this.boardStore.presentationOnly = true;
      this.boardStore.boardDetail.session = 0;
      this.boardStore.boardDetail.loading = false;
      this.boardStore.boardDetail.loadingMore = false;
      this.boardStore.boardDetail.refreshing = false;
      this.boardStore.boardDetail.error = '图板连接失败，请重试';
      this.loadFailed = false;
      this.failureDetails = '';
      PinmonyRuntimeLog.warn('BoardReturn: synchronization-failed snapshotRetained=true');
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
      PinmonyRuntimeLog.error('Pinmony: main frame load failed, code ' + code + ', info ' + info);
      return;
    }
    // A failed Pin document has no home page key, but the feed is
    // still the valid parent screen and should remain visible.
    const cachedHome: PinmonyHomeSnapshot | undefined = this.homeStore.cachedHome;
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
      PinmonyRuntimeLog.warn('HomeRefresh: failed reason=main-frame-error snapshotRetained=true');
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
        PinmonyRuntimeLog.warn('HomeRefresh: failed reason=main-frame-error snapshotRetained=false');
      }
      this.clearHome();
    }
    if (keepSearchAfterReturnFailure) this.restoreRetainedSearch(this.searchUrlFromAddress(url));
    else if (!keepSearchAfterPinFailure) this.clearSearch();
    PinmonyRuntimeLog.error('Pinmony: main frame load failed, code ' + code +
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
   } finally { this.rootContextCoordinator.notify(); } }

  describeFailure(url: string, code: number): string {
    const path: string = url.split('?')[0].split('#')[0];
    const shortPath: string = path.length > 140 ? path.substring(0, 140) + '…' : path;
    const reason: string = code === -113 ? 'HTTPS 安全连接协商失败 · ' :
      code === -200 ? '网站证书校验失败，请检查网络或代理后重试 · ' : code === -100 ? '连接被关闭 · ' : '';
    return reason + '错误码 ' + code.toString() + ' · ' + shortPath;
  }
}
