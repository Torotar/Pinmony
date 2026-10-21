import { PinmonyControllerLifecycle } from './PinmonyControllerLifecycle';
import { PinmonyPagePerformance } from 'common_foundation';
import { PinmonyReturnCoordinator } from './PinmonyReturnCoordinator';
import { PinmonySearchController } from 'feature_search';
import { PinmonyPublishFlow } from 'feature_profile';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyDetailReadCache } from 'feature_pin';
import { PinmonyBoardStore } from 'feature_board';
import { PinmonyProfileStore } from 'feature_profile';
import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonySearchStore } from 'feature_search';
import { PinmonyHomeController } from 'feature_home';
import { PinmonyHomeStore } from 'feature_home';
import { PinmonyRuntimeLog } from 'common_foundation';
import { webview } from '@kit.ArkWeb';
import { PinmonyAuthStatus } from 'common_session';
import { picker } from '@kit.CoreFileKit';
import { HdsTabsController } from '@kit.UIDesignKit';
import { PinmonyNavigationHistory } from './PinmonyNavigationHistory';
import { PinmonyProfileSnapshot } from 'feature_profile';
import { PinmonyHomeSnapshot } from 'feature_home';
const PINTEREST_URL: string = 'https://www.pinterest.com/';
export interface PinmonyNavigationCoordinatorPorts {
  rootPresented?: (index: number) => void;
  nativeBusinessOnly?: () => boolean;
  activeSheetKind: () => string;
  activeTab: () => number;
  setActiveTab: (value: number) => number;
  authStatus: () => PinmonyAuthStatus;
  backFromBoard: () => void;
  backFromDetail: () => Promise<void>;
  backFromSearch: () => void;
  backFromUserProfile: () => void;
  backInProgress: () => boolean;
  setBackInProgress: (value: boolean) => boolean;
  backOnePage: (fallback?: string, targetOverride?: string) => boolean;
  boardCollaboratorsAction: (action: string, value: string) => void;
  boardStore: () => PinmonyBoardStore;
  boardUrlFromAddress: (address: string) => string;
  cancelHomeDetailMore: () => void;
  clearDetail: (preserveRead?: boolean, localOnly?: boolean) => void;
  clearRootTabGuard: (reason: string) => void;
  closeBoardCollaborators: () => void;
  closeImageLayer: (localOnly?: boolean) => void;
  closeProfilePanel: () => void;
  closeProfileSettings: () => void;
  controller: () => webview.WebviewController;
  controllerLifecycle: () => PinmonyControllerLifecycle;
  currentBoardUrl: () => string;
  currentPinUrl: () => string;
  currentProfileUrl: () => string;
  currentSearchPageKey: () => string;
  currentWebTab: () => number;
  setCurrentWebTab: (value: number) => number;
  detailReadCache: () => PinmonyDetailReadCache;
  detailReturnedToRoot: () => boolean;
  setDetailReturnedToRoot: (value: boolean) => boolean;
  dismissApiBoards: () => void;
  dismissApiComments: () => void;
  dismissEditPin: (force?: boolean) => void;
  dismissMoreSheet: () => void;
  dismissProfileMenu: () => void;
  dismissProfilePublish: () => void;
  dismissSearchFilters: () => void;
  dismissShareSheet: () => void;
  editPinAction: (method: string, args: string) => void;
  extractPinUrl: (value: string) => string;
  failureDetails: () => string;
  setFailureDetails: (value: string) => string;
  homeController: () => PinmonyHomeController;
  homePageKeyFromAddress: (url: string) => string;
  homeStore: () => PinmonyHomeStore;
  ignoreSupersededDetailDocument: (url: string) => boolean;
  inboxFlowAction: (action: string, value?: string) => Promise<void>;
  inboxStore: () => PinmonyInboxStore;
  inboxUrlFromAddress: (address: string) => string;
  isHomeRootAddress: (address: string) => boolean;
  lastRootBackAt: () => number;
  setLastRootBackAt: (value: number) => number;
  loadFailed: () => boolean;
  setLoadFailed: (value: boolean) => boolean;
  logPageLifecycle: (event: string, detail?: string) => void;
  nativeBackTarget: () => string;
  setNativeBackTarget: (value: string) => string;
  nativeChildBackUntil: () => number;
  setNativeChildBackUntil: (value: number) => number;
  nativePinRoute: () => string;
  setNativePinRoute: (value: string) => string;
  nativeRootOnly: () => boolean;
  setNativeRootOnly: (value: boolean) => boolean;
  nativeRootTabsVisible: () => boolean;
  nativeSearchPageVisible: () => boolean;
  navigationAddress: () => string;
  setNavigationAddress: (value: string) => string;
  organizeProfile: (action: string, value?: string, secret?: boolean) => Promise<void>;
  pageBackToken: () => number;
  setPageBackToken: (value: number) => number;
  pageHistory: () => PinmonyNavigationHistory;
  pagePerformance: () => PinmonyPagePerformance;
  pendingWebTab: () => number;
  setPendingWebTab: (value: number) => number;
  pinIdentity: (value: string) => string;
  pinStore: () => PinmonyPinStore;
  prepareHomeForPageBegin: (url: string, retainedDocument?: boolean) => void;
  profileSettingsVisible: () => boolean;
  profileStore: () => PinmonyProfileStore;
  profileUrlFromAddress: (address: string) => string;
  publishFlowAction: (action: string, value?: string, secret?: boolean) => void;
  restoreCachedDetail: (pinUrl: string) => boolean;
  restoreInbox: (address: string) => boolean;
  restoreProfile: (address: string) => boolean;
  restoreRetainedSearch: (pageKey: string) => boolean;
  retainedHomeDocumentAddress: () => string;
  setRetainedHomeDocumentAddress: (value: string) => string;
  retainedHomeDocumentPending: () => boolean;
  setRetainedHomeDocumentPending: (value: boolean) => boolean;
  retainedRootTabAddress: () => string;
  setRetainedRootTabAddress: (value: string) => string;
  retainedRootTabPending: () => number;
  setRetainedRootTabPending: (value: number) => number;
  returnCoordinator: () => PinmonyReturnCoordinator;
  returnFromDetailWebFlow: () => Promise<void>;
  returnFromProfileWebFlow: () => Promise<void>;
  returnFromSearchQuiz: () => boolean;
  rootContentInteracted: () => boolean;
  setRootContentInteracted: (value: boolean) => boolean;
  rootPresentationAddress: (index: number) => string;
  rootPullKind: () => string;
  setRootPullKind: (value: string) => string;
  rootPullToken: () => number;
  setRootPullToken: (value: number) => number;
  rootReadAddress: () => string;
  setRootReadAddress: (value: string) => string;
  rootReadStartedAt: () => number;
  setRootReadStartedAt: (value: number) => number;
  rootReadToken: () => number;
  setRootReadToken: (value: number) => number;
  rootTabGuardAddress: () => string;
  setRootTabGuardAddress: (value: string) => string;
  rootTabGuardTarget: () => number;
  setRootTabGuardTarget: (value: number) => number;
  rootTabIndexFromAddress: (address: string) => number;
  searchController: () => PinmonySearchController;
  searchStore: () => PinmonySearchStore;
  searchUrlFromAddress: (address: string) => string;
  showNativeSheet: () => boolean;
  showNativeTabs: () => boolean;
  setShowNativeTabs: (value: boolean) => boolean;
  syncBoardRoute: (address: string) => void;
  syncFloatingTabsMotion: () => void;
  tabRequestToken: () => number;
  setTabRequestToken: (value: number) => number;
  tabsController: () => HdsTabsController;
  traceAction: (name: string, detail?: string) => void;
  waitForWebTabConfirmation: (index: number, token: number, requestedAt: number) => void;
  webPageLoading: () => boolean;
  setWebPageLoading: (value: boolean) => boolean;
}
export class PinmonyNavigationCoordinator {
  private readonly homeStore: PinmonyHomeStore;
  private readonly searchStore: PinmonySearchStore;
  private readonly profileStore: PinmonyProfileStore;
  private readonly inboxStore: PinmonyInboxStore;
  private readonly pinStore: PinmonyPinStore;
  private readonly boardStore: PinmonyBoardStore;
  private readonly ports: PinmonyNavigationCoordinatorPorts;
  constructor(ports: PinmonyNavigationCoordinatorPorts) { this.ports = ports; this.homeStore = ports.homeStore(); this.searchStore = ports.searchStore(); this.profileStore = ports.profileStore(); this.inboxStore = ports.inboxStore(); this.pinStore = ports.pinStore(); this.boardStore = ports.boardStore(); }
selectNativeRootTab(index: number): void {
    if (this.ports.authStatus() !== 'authenticated' || index < 0 || index > 3)
        return;
    this.ports.returnCoordinator().cancel();
    this.ports.controllerLifecycle().pause();
    this.ports.searchController().invalidatePending();
    this.ports.homeController().invalidatePending();
    this.ports.pagePerformance().begin(index, 'tab');
    this.ports.traceAction('root.tab', index.toString());
    this.ports.logPageLifecycle('root-tab-request', 'targetTab=' + index.toString());
    // Preserve the last completed profile snapshot before leaving a detail page.
    // The hidden Web document may take time to return to the profile route; the
    // native root can still present this account-scoped snapshot immediately.
    if (index === 3 && this.profileStore.profile) {
        const profileForCache: PinmonyProfileSnapshot = this.profileStore.profile;
        this.profileStore.profileCache.put(profileForCache, this.profileStore.profileScrollOffset);
    }
    // Only ArkUI presentation changes here. Business reads belong to explicit
    // page refresh/actions, never to the bottom-bar selection.
    this.ports.setNativeRootOnly(true);
    this.ports.setRootContentInteracted(false);
    this.searchStore.searchIntentToken++;
    this.ports.setTabRequestToken(this.ports.tabRequestToken() + 1);
    this.ports.setPageBackToken(this.ports.pageBackToken() + 1);
    this.ports.pageHistory().cancelBack();
    this.ports.setNativeBackTarget('');
    this.ports.setPendingWebTab(-1);
    this.ports.setRetainedRootTabPending(-1);
    this.ports.setRetainedRootTabAddress('');
    this.ports.setRetainedHomeDocumentPending(false);
    this.ports.setRetainedHomeDocumentAddress('');
    this.ports.setRootTabGuardTarget(index);
    this.ports.setRootTabGuardAddress(this.ports.rootPresentationAddress(index));
    this.ports.clearDetail(false, true);
    this.ports.setNativePinRoute('');
    this.pinStore.detailReturnUrl = '';
    this.ports.cancelHomeDetailMore();
    this.profileStore.origins = [];
    this.profileStore.profileWebFlow = false;
    this.inboxStore.listSection = '';
    this.inboxStore.inboxFlow = undefined;
    this.inboxStore.retainedChat = undefined;
    this.inboxStore.chatScrollOffset = 0;
    this.inboxStore.chatReturnConversation = '';
    this.inboxStore.inboxWebFlow = false;
    this.boardStore.pendingBoardUrl = '';
    this.boardStore.pendingBoardSource = '';
    this.boardStore.boardOpeningToken++;
    this.boardStore.boardDetail = undefined;
    this.ports.setActiveTab(index);
    this.ports.tabsController().changeIndex(index);
    this.ports.setNavigationAddress(this.ports.rootTabGuardAddress());
    this.ports.setShowNativeTabs(true);
    this.ports.setLoadFailed(false);
    this.ports.setFailureDetails('');
    this.ports.setWebPageLoading(false);
    const address: string = this.ports.rootTabGuardAddress();
    if (index === 0) {
        const cachedHome: PinmonyHomeSnapshot | undefined = this.homeStore.cachedHome;
        const homePageKey: string = this.ports.homePageKeyFromAddress(address) || PINTEREST_URL;
        if (cachedHome && cachedHome.pageKey === homePageKey && cachedHome.pins.length > 0) {
            this.homeStore.home = cachedHome;
            this.homeStore.retainingHomeFeed = true;
            this.homeStore.homeActionsReady = false;
            this.homeStore.homeLoading = false;
            this.homeStore.homeError = '';
            PinmonyRuntimeLog.info('HomeCache: root presentation restored pins=' + cachedHome.pins.length.toString() +
                ' actionsReady=false');
        }
    }
    if (index === 1 && !this.searchStore.search)
        this.ports.restoreRetainedSearch(address);
    if (index === 2 && !this.inboxStore.inbox)
        this.ports.restoreInbox(address);
    if (index === 3 && this.profileStore.profile?.profileUrl !== this.ports.profileUrlFromAddress(address)) {
        if (!this.ports.restoreProfile(address)) {
            // Keep an existing same-session snapshot visible while the hidden
            // document catches up; current-session actions remain gated below.
            const existingProfile: PinmonyProfileSnapshot | undefined = this.profileStore.profile;
            const targetProfile: string = this.ports.profileUrlFromAddress(address);
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
    this.ports.setRootPullToken(this.ports.rootPullToken() + 1);
    this.ports.setRootPullKind('');
    this.homeStore.homeLoading = false;
    this.searchStore.searchLoading = false;
    this.inboxStore.inboxLoading = false;
    this.profileStore.profileLoading = false;
    this.profileStore.profileSwitching = false;
    this.inboxStore.restoringInboxSection = '';
    this.inboxStore.pendingInboxSection = '';
    PinmonyRuntimeLog.info('RootTabTrace: native-switch targetTab=' + index.toString() +
        ' mode=presentation-only webNavigation=false apiDemand=false');
    this.ports.syncFloatingTabsMotion();
}

presentNativeBackTarget(target: string): void {
    const performanceRoot: number = this.ports.rootTabIndexFromAddress(target);
    if (performanceRoot >= 0)
        this.ports.pagePerformance().begin(performanceRoot, 'return');
    const pin: string = this.ports.extractPinUrl(target);
    // A nested Pin can only be presented immediately when its cache exists.
    if (pin && !this.pinStore.detailCache.get(this.ports.pinIdentity(pin)))
        return;
    this.ports.clearRootTabGuard('back');
    const root: number = this.ports.rootTabIndexFromAddress(target);
    if (root >= 0) {
        this.ports.setDetailReturnedToRoot(true);
        this.ports.setRootTabGuardTarget(root);
        this.ports.setRootTabGuardAddress(target);
        this.ports.setRootReadAddress(target);
        this.ports.setRootReadToken(this.ports.setTabRequestToken(this.ports.tabRequestToken() + 1));
        this.ports.setRootReadStartedAt(Date.now());
        this.ports.setPendingWebTab(root);
        this.ports.waitForWebTabConfirmation(root, this.ports.tabRequestToken(), this.ports.rootReadStartedAt());
        PinmonyRuntimeLog.info('RootTabTrace: return-preparation targetTab=' + root.toString());
    }
    this.ports.detailReadCache().setPin(pin);
    this.ports.setNativeBackTarget(target);
    this.ports.setNavigationAddress(target);
    this.ports.clearDetail();
    this.ports.setNativePinRoute(this.ports.pinIdentity(pin));
    this.homeStore.homeActionsReady = false;
    this.profileStore.profileActionsReady = false;
    this.inboxStore.inboxActionsReady = false;
    this.searchStore.searchActionsReady = false;
    this.searchStore.searchInputReady = false;
    const board: string = this.ports.boardUrlFromAddress(target);
    if (board) {
        this.ports.syncBoardRoute(target);
        this.boardStore.presentationPage = board;
        this.boardStore.presentationOnly = true;
        this.ports.setActiveTab(this.boardStore.rootTab);
        this.ports.setLoadFailed(false);
        this.ports.tabsController().changeIndex(this.ports.activeTab());
        PinmonyRuntimeLog.info('BoardReturn: native-presented snapshot=' +
            (!!this.boardStore.boardDetail?.pins.length).toString());
        return;
    }
    if (pin) {
        this.pinStore.detailReturnUrl = this.pinStore.detailOrigin(this.ports.pinIdentity(pin));
        this.ports.restoreCachedDetail(pin);
        return;
    }
    const profile: string = this.ports.profileUrlFromAddress(target);
    const inbox: string = this.ports.inboxUrlFromAddress(target);
    const search: string = this.ports.searchUrlFromAddress(target);
    if (profile || inbox || search || this.ports.isHomeRootAddress(target)) {
        this.boardStore.presentationPage = '';
        this.boardStore.presentationOnly = false;
        this.profileStore.profileWebFlow = false;
        this.profileStore.profileFlowLeftPage = false;
        this.ports.setLoadFailed(false);
    }
    if (profile) {
        if (this.profileStore.origins.length === 0)
            this.ports.setActiveTab(3);
        const restored: boolean = this.ports.restoreProfile(target);
        if (!restored) {
            this.profileStore.profile = undefined;
            this.profileStore.profileUrl = profile;
            this.profileStore.profileScrollOffset = 0;
            this.profileStore.profileLoading = true;
            this.profileStore.profileError = '';
        }
        PinmonyRuntimeLog.info('ProfileReturn: native-state cache=' + (restored ? 'hit' : 'miss') +
            ' scroll=' + this.profileStore.profileScrollOffset.toString());
    }
    else if (inbox) {
        this.ports.setActiveTab(2);
        const restored: boolean = this.ports.restoreInbox(target);
        if (!restored) {
            this.inboxStore.inbox = undefined;
            this.inboxStore.inboxUrl = inbox;
            this.inboxStore.inboxLoading = true;
            this.inboxStore.inboxError = '';
            this.inboxStore.inboxScrollOffset = 0;
        }
        PinmonyRuntimeLog.info('InboxReturn: native-state cache=' + (restored ? 'hit' : 'miss'));
    }
    else if (search) {
        this.ports.setActiveTab(1);
        const restored: boolean = this.ports.restoreRetainedSearch(search);
        if (!restored) {
            this.searchStore.search = undefined;
            this.searchStore.searchLoading = true;
            this.searchStore.searchError = '';
            this.searchStore.searchScrollOffset = 0;
        }
        PinmonyRuntimeLog.info('SearchReturn: native-state cache=' + (restored ? 'hit' : 'miss'));
    }
    else if (this.ports.isHomeRootAddress(target)) {
        this.ports.setActiveTab(0);
        this.ports.prepareHomeForPageBegin(target);
    }
    this.ports.tabsController().changeIndex(this.ports.activeTab());
    if (performanceRoot >= 0) this.ports.rootPresented?.(performanceRoot);
}

syncNativeReturnRoute(address: string): void {
    if (this.ports.ignoreSupersededDetailDocument(address))
        return;
    if (this.ports.nativeRootOnly())
        return;
    if (this.ports.nativeBackTarget() && this.ports.pageHistory().key(address) !== this.ports.pageHistory().key(this.ports.nativeBackTarget()))
        return;
    try {
        if (this.ports.pageHistory().key(address) !== this.ports.pageHistory().key(this.ports.controller().getUrl()))
            return;
    }
    catch (_) {
        return;
    }
    this.ports.setNavigationAddress(address);
    const pin: string = this.ports.extractPinUrl(address);
    const profile: string = this.ports.profileUrlFromAddress(address);
    if (pin) {
        this.ports.setNativePinRoute(this.ports.pinIdentity(pin));
        if (this.profileStore.profileWebFlow)
            this.profileStore.profileFlowLeftPage = true;
        return;
    }
    if (this.ports.nativePinRoute()) {
        this.ports.setNativePinRoute('');
        this.ports.clearDetail();
        this.pinStore.detailReturnUrl = '';
    }
    if (this.profileStore.profileWebFlow && !profile)
        this.profileStore.profileFlowLeftPage = true;
    const home: boolean = this.ports.isHomeRootAddress(address);
    const inbox: string = this.ports.inboxUrlFromAddress(address);
    const searchRoot: boolean = /^https:\/\/(?:[^/]+\.)?pinterest\.com\/search\/?(?:[?#]|$)/i.test(address) &&
        !/[?&]q=[^&#]+/i.test(address);
    if (this.profileStore.profileFlowLeftPage && (profile || home || inbox || searchRoot)) {
        this.profileStore.profileWebFlow = false;
        this.profileStore.profileFlowLeftPage = false;
    }
    if (profile && this.profileStore.origins.length > 0)
        return;
    if (profile || home || inbox || searchRoot) {
        if (!this.boardStore.pendingBoardUrl) {
            this.boardStore.boardReturnUrl = '';
            this.boardStore.boardReturnPage = '';
        }
        const index: number = profile ? 3 : inbox ? 2 : searchRoot ? 1 : 0;
        this.ports.setShowNativeTabs(true);
        this.ports.setActiveTab(index);
        this.ports.setCurrentWebTab(index);
        if (this.ports.pendingWebTab() === index)
            this.ports.setPendingWebTab(-1);
        this.ports.tabsController().changeIndex(index);
    }
}

async handleBack(): Promise<void> {
    if (Date.now() < this.pinStore.shareBackHandledUntil)
        return;
    if (this.ports.showNativeSheet() || this.ports.activeSheetKind()) {
        this.onBackPress();
        return;
    }
    if (this.pinStore.detail || this.ports.currentPinUrl()) {
        this.ports.backFromDetail();
        return;
    }
    if (this.ports.returnFromSearchQuiz())
        return;
    if (this.homeStore.pendingHomeMorePin)
        this.ports.cancelHomeDetailMore();
    if (this.ports.backInProgress() || this.ports.pageHistory().isPending()) {
        return;
    }
    if(this.ports.nativeBusinessOnly?.()){this.ports.backOnePage();this.ports.setLastRootBackAt(0);return;}
    this.ports.setBackInProgress(true);
    try {
        let handled: boolean = false;
        try {
            const result: string = await this.ports.controller().runJavaScript('window.PinmonyHandleBack ? window.PinmonyHandleBack() : false');
            handled = result === 'true' || result === '"true"';
        }
        catch (error) {
            PinmonyRuntimeLog.warn('Pinmony: could not inspect the open web panel');
        }
        if (this.ports.showNativeSheet() || this.ports.activeSheetKind() || this.pinStore.detail || this.ports.currentPinUrl() ||
            Date.now() < this.pinStore.shareBackHandledUntil) {
            this.ports.setLastRootBackAt(0);
            return;
        }
        if (handled) {
            this.ports.setLastRootBackAt(0);
        }
        else if (this.ports.backOnePage()) {
            this.ports.setLastRootBackAt(0);
        }
        else {
            // A sheet/HDS back event can reach the root after its child has closed.
            // Root back must never turn that second delivery into ability termination.
            this.ports.setLastRootBackAt(0);
            try {
                await this.ports.controller().runJavaScript('window.PinmonyDismissUnknownPanel && window.PinmonyDismissUnknownPanel()');
            }
            catch (error) {
                PinmonyRuntimeLog.warn('Pinmony: could not dismiss an unrecognized web panel');
            }
        }
    }
    catch (error) {
        PinmonyRuntimeLog.warn('Pinmony: back navigation failed');
    }
    finally {
        this.ports.setBackInProgress(false);
    }
}

onBackPress(): boolean {
    if (this.inboxStore.invitationAllVisible) {
        this.inboxStore.invitationAllVisible = false;
        return true;
    }
    if (this.boardStore.collaborators) {
        if (!this.boardStore.collaborators.busy) {
            if (this.boardStore.collaborators.phase === 'members' || this.boardStore.collaborators.uncertain)
                this.ports.closeBoardCollaborators();
            else
                this.ports.boardCollaboratorsAction('members', '');
        }
        return true;
    }
    PinmonyRuntimeLog.info('PinmonyReturn: root back sheet=' + this.ports.activeSheetKind() +
        ' detail=' + (!!this.pinStore.detail).toString() + ' pending=' + this.ports.pageHistory().isPending().toString());
    if (Date.now() < this.ports.nativeChildBackUntil())
        return true;
    if (this.profileStore.publishFlow) {
        const flow: PinmonyPublishFlow = this.profileStore.publishFlow;
        if (!flow.busy && !this.profileStore.publishPicking)
            this.ports.publishFlowAction(flow.uncertain || flow.kind === 'board' || ['website', 'photo', 'select'].includes(flow.phase) ? 'close' : 'back');
        return true;
    }
    if (this.pinStore.imageLayer && !this.ports.activeSheetKind()) {
        this.ports.closeImageLayer();
        return true;
    }
    if (this.profileStore.panel) {
        this.ports.closeProfilePanel();
        return true;
    }
    if (this.ports.activeSheetKind() === 'profileMenu') {
        this.ports.dismissProfileMenu();
        return true;
    }
    if (this.ports.profileSettingsVisible()) {
        this.ports.closeProfileSettings();
        return true;
    }
    if (this.ports.currentProfileUrl() && this.profileStore.origins.length > 0) {
        this.ports.backFromUserProfile();
        return true;
    }
    if (Date.now() < this.pinStore.shareBackHandledUntil)
        return true;
    const inboxPresented: boolean = !!this.ports.nativeBackTarget() &&
      this.ports.inboxUrlFromAddress(this.ports.nativeBackTarget()) === this.inboxStore.inboxFlow?.pageUrl;
    if (this.inboxStore.inboxFlow && (inboxPresented || !this.boardStore.pendingBoardUrl && !this.ports.currentBoardUrl() &&
        !this.pinStore.detail && !this.pinStore.detailOpeningPin && !this.ports.currentPinUrl())) {
        this.ports.setNativeChildBackUntil(Date.now() + 300);
        this.ports.inboxFlowAction('back');
        return true;
    }
    if (this.inboxStore.listSection && !this.pinStore.detail && !this.pinStore.detailOpeningPin &&
        !this.ports.currentPinUrl() && !this.boardStore.pendingBoardUrl && !this.ports.currentBoardUrl() && !this.ports.activeSheetKind()) {
        this.ports.setNativeChildBackUntil(Date.now() + 300);
        if (this.inboxStore.listSearchBack?.()) return true;
        this.inboxStore.listSection = '';
        return true;
    }
    if (this.profileStore.profile && this.profileStore.profile.organize) {
        if (!this.profileStore.profile.organize.busy) {
            const phase: string = this.profileStore.profile.organize.phase;
            this.ports.organizeProfile(phase === 'select' ? 'close' : phase === 'create' ? 'boards' : 'back');
        }
    }
    else if (this.ports.activeSheetKind() === 'edit') {
        if (!this.pinStore.editResult.busy && !this.pinStore.editResult.picker.busy) {
            if (this.pinStore.editResult.phase !== 'edit')
                this.ports.editPinAction('editPhase', ',"edit"');
            else
                this.ports.dismissEditPin();
        }
    }
    else if (this.ports.activeSheetKind() === 'comments') {
        this.ports.dismissApiComments();
    }
    else if (this.ports.activeSheetKind() === 'save') {
        this.ports.dismissApiBoards();
    }
    else if (this.ports.activeSheetKind() === 'publish') {
        this.ports.dismissProfilePublish();
    }
    else if (this.ports.activeSheetKind() === 'profileMenu') {
        this.ports.dismissProfileMenu();
    }
    else if (this.ports.activeSheetKind() === 'more') {
        this.ports.dismissMoreSheet();
    }
    else if (this.ports.activeSheetKind() === 'share') {
        this.ports.dismissShareSheet();
    }
    else if (this.ports.activeSheetKind() === 'searchFilter') {
        this.ports.dismissSearchFilters();
    }
    else if (this.ports.authStatus() === 'authenticated' && this.ports.activeTab() === 1 && this.ports.nativeRootTabsVisible() &&
        /[?&]q=[^&#]+/.test(this.ports.currentSearchPageKey())) {
        this.ports.backFromSearch();
    }
    else if (this.ports.authStatus() !== 'authenticated' || this.ports.nativeRootTabsVisible()) {
        PinmonyRuntimeLog.info('PinmonyReturn: root back delegated to system');
        return false;
    }
    else if (this.searchStore.search && this.ports.nativeSearchPageVisible() && this.searchStore.search.quiz && this.searchStore.search.quiz.mode !== 'entry') {
        this.handleBack();
    }
    else if (this.searchStore.searchInputFocused && !!this.ports.currentSearchPageKey() &&
        !this.pinStore.detail && !this.ports.currentPinUrl()) {
        this.ports.backFromSearch();
    }
    else if (this.pinStore.detailWebFlow) {
        this.ports.returnFromDetailWebFlow();
    }
    else if (this.boardStore.pendingBoardUrl || this.ports.currentBoardUrl()) {
        this.ports.backFromBoard();
    }
    else if (this.profileStore.profileWebFlow) {
        this.ports.returnFromProfileWebFlow();
    }
    else if (this.pinStore.detail) {
        this.ports.backFromDetail();
    }
    else if (this.ports.currentPinUrl()) {
        this.ports.backFromDetail();
    }
    else if (this.ports.currentSearchPageKey()) {
        this.ports.backFromSearch();
    }
    else {
        this.handleBack();
    }
    this.ports.setNativeChildBackUntil(Date.now() + 300);
    return true;
}
}
