import { PinmonyReadinessGate } from './PinmonyReadinessGate';
import { PinmonyPagePerformance } from 'common_foundation';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyProfileStore } from 'feature_profile';
import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonySearchStore } from 'feature_search';
import { PinmonyHomeStore } from 'feature_home';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { webview } from '@kit.ArkWeb';
import { PinmonyAuthStatus } from 'common_session';
import { PinmonyNavigationHistory } from './PinmonyNavigationHistory';
export interface PinmonyRootContextCoordinatorPorts {
  activeSheetKind: () => string;
  activeTab: () => number;
  authStatus: () => PinmonyAuthStatus;
  businessSuspended: () => boolean;
  clearRootTabGuard: (reason: string) => void;
  controller: () => webview.WebviewController;
  coordinatorTasks: () => PinmonyTaskRegistry;
  currentHomePageKey: () => string;
  currentInboxUrl: () => string;
  currentProfileUrl: () => string;
  profileUrlFromAddress: (address: string) => string;
  currentSearchPageKey: () => string;
  expectHome: () => void;
  expectInbox: () => void;
  expectProfile: () => void;
  expectSearch: () => void;
  failureDetails: () => string;
  setFailureDetails: (value: string) => string;
  homeStore: () => PinmonyHomeStore;
  inboxStore: () => PinmonyInboxStore;
  lastDocumentBeginAt: () => number;
  lastDocumentBeginUrl: () => string;
  loadFailed: () => boolean;
  setLoadFailed: (value: boolean) => boolean;
  pageHistory: () => PinmonyNavigationHistory;
  pagePerformance: () => PinmonyPagePerformance;
  pendingWebTab: () => number;
  setPendingWebTab: (value: number) => number;
  pinStore: () => PinmonyPinStore;
  profileStore: () => PinmonyProfileStore;
  retainedRootTabAddress: () => string;
  setRetainedRootTabAddress: (value: string) => string;
  retainedRootTabPending: () => number;
  setRetainedRootTabPending: (value: number) => number;
  rootContentInteracted: () => boolean;
  setRootContentInteracted: (value: boolean) => boolean;
  rootPresentationAddress: (index: number) => string;
  rootReadAddress: () => string;
  setRootReadAddress: (value: string) => string;
  rootReadStartedAt: () => number;
  setRootReadStartedAt: (value: number) => number;
  rootReadToken: () => number;
  setRootReadToken: (value: number) => number;
  rootTabAddresses: () => Map<number, string>;
  rootTabGuardAddress: () => string;
  setRootTabGuardAddress: (value: string) => string;
  rootTabGuardTarget: () => number;
  setRootTabGuardTarget: (value: number) => number;
  rootTabIndexFromAddress: (address: string) => number;
  searchStore: () => PinmonySearchStore;
  showMessage: (message: string) => void;
  syncAuthentication: () => void;
  tabRequestToken: () => number;
  setTabRequestToken: (value: number) => number;
  waitForWebTabConfirmation: (index: number, token: number, requestedAt: number) => void;
  webPageLoading: () => boolean;
}
export class PinmonyRootContextCoordinator {
  private readonly homeStore: PinmonyHomeStore;
  private readonly searchStore: PinmonySearchStore;
  private readonly profileStore: PinmonyProfileStore;
  private readonly inboxStore: PinmonyInboxStore;
  private readonly pinStore: PinmonyPinStore;
  private readonly readiness: PinmonyReadinessGate = new PinmonyReadinessGate();
  notify(): void { this.readiness.notify(); }
  pause(): void { this.readiness.cancel(); }
  private readonly ports: PinmonyRootContextCoordinatorPorts;
  constructor(ports: PinmonyRootContextCoordinatorPorts) { this.ports = ports; this.homeStore = ports.homeStore(); this.searchStore = ports.searchStore(); this.profileStore = ports.profileStore(); this.inboxStore = ports.inboxStore(); this.pinStore = ports.pinStore(); }
rootActionContextReady(index: number, requireData: boolean = true): boolean {
    let document: string = '';
    try {
        document = this.ports.controller().getUrl();
    }
    catch (_) { }
    const address: string = this.ports.rootPresentationAddress(index);
    const sameDocument: boolean = index === 3 ? !!this.ports.profileUrlFromAddress(document) &&
        this.ports.profileUrlFromAddress(document) === this.ports.profileUrlFromAddress(address) :
        this.ports.pageHistory().key(document) === this.ports.pageHistory().key(address);
    if (this.ports.authStatus() !== 'authenticated' || this.ports.activeTab() !== index || !sameDocument)
        return false;
    if (index === 0)
        return this.homeStore.homeActionsReady && this.homeStore.home?.pageKey === this.ports.currentHomePageKey();
    if (index === 1)
        return (requireData ? this.searchStore.searchActionsReady :
            this.searchStore.searchInputReady || this.searchStore.searchActionsReady) &&
            this.searchStore.search?.pageKey === this.ports.currentSearchPageKey();
    if (index === 2)
        return this.inboxStore.inboxSectionReady &&
            (!requireData || this.inboxStore.inboxActionsReady) &&
            this.inboxStore.inboxSession === this.inboxStore.inbox?.session &&
            this.inboxStore.inboxUrl === this.ports.currentInboxUrl();
    if (index === 3)
        return this.profileStore.profileActionsReady &&
            this.profileStore.profileSession === this.profileStore.profile?.session &&
            this.profileStore.profile?.profileUrl === this.ports.currentProfileUrl();
    return false;
}

async ensureRootActionContext(index: number, requireData: boolean = true, allowedSheet: string = '', isCurrent: () => boolean = (): boolean => true): Promise<boolean> {
    if (this.ports.businessSuspended() || this.ports.authStatus() !== 'authenticated' || this.ports.activeTab() !== index || this.pinStore.detail ||
        this.pinStore.detailOpeningPin || (this.ports.activeSheetKind() && this.ports.activeSheetKind() !== allowedSheet) || !isCurrent())
        return false;
    this.ports.setRootContentInteracted(true);
    if (this.rootActionContextReady(index, requireData)) {
        this.ports.clearRootTabGuard('content-action');
        return true;
    }
    this.requestRootPage(index);
    this.readiness.notify();
    const token: number = this.ports.tabRequestToken();
    const current = (): boolean => token === this.ports.tabRequestToken() && !this.ports.businessSuspended() &&
      this.ports.authStatus() === 'authenticated' && this.ports.activeTab() === index && !this.pinStore.detail &&
      !this.pinStore.detailOpeningPin && (!this.ports.activeSheetKind() || this.ports.activeSheetKind() === allowedSheet) && isCurrent();
    const ready: boolean = await this.readiness.wait(current, (): boolean => this.rootActionContextReady(index, requireData),
      (): boolean => this.ports.loadFailed(), 12000);
    if (ready) return true;
    if (current()) {
        PinmonyRuntimeLog.warn('RootTabTrace: content-context unavailable targetTab=' + index.toString());
        this.ports.showMessage('当前页面操作尚未就绪，请重试');
    }
    return false;
}

requestRootPage(index: number): void {
    if (this.ports.businessSuspended() || this.ports.authStatus() !== 'authenticated' || this.ports.activeTab() !== index)
        return;
    if (this.pinStore.detail || this.pinStore.detailOpeningPin)
        return;
    const address: string = this.ports.rootPresentationAddress(index);
    if (!address || this.ports.rootTabIndexFromAddress(address) !== index) {
        this.ports.showMessage('当前页面地址尚未确认，请稍后重试');
        return;
    }
    if (this.rootReadInFlight(index, address)) {
        PinmonyRuntimeLog.info('RootTabTrace: page-read-joined targetTab=' + index.toString());
        return;
    }
    this.ports.pagePerformance().count(index, 'read');
    this.ports.clearRootTabGuard('page-read');
    let document: string = '';
    try { document = this.ports.controller().getUrl(); }
    catch (_) { PinmonyRuntimeLog.warn('RootTabTrace: document-read-unavailable'); }
    const reuseHomeDocument: boolean = index === 0 && !!document && !this.ports.webPageLoading() && !this.ports.loadFailed() &&
        !this.homeStore.homeError && this.ports.pageHistory().key(document) === this.ports.pageHistory().key(address);
    const token: number = this.ports.setTabRequestToken(this.ports.tabRequestToken() + 1);
    this.ports.setRootReadAddress(address);
    this.ports.setRootReadToken(token);
    this.ports.setRootReadStartedAt(Date.now());
    this.ports.setPendingWebTab(index);
    this.ports.setRootTabGuardTarget(index);
    this.ports.setRootTabGuardAddress(address);
    this.ports.setRetainedRootTabPending(index);
    this.ports.setRetainedRootTabAddress(address);
    this.ports.rootTabAddresses().set(index, address);
    this.ports.setLoadFailed(false);
    if (index === 0)
        this.ports.expectHome();
    else if (index === 1)
        this.ports.expectSearch();
    else if (index === 2)
        this.ports.expectInbox();
    else
        this.ports.expectProfile();
    PinmonyRuntimeLog.info('RootTabTrace: page-read-request targetTab=' + index.toString());
    if (reuseHomeDocument) {
        // Confirm the live document and bridge before reusing it; the native
        // cached snapshot and getUrl() alone are not session evidence.
        this.ports.controller().runJavaScript('location.href === ' + JSON.stringify(address) +
            ' && typeof window.PinmonyHomeRefresh === "function" ? (window.PinmonyHomeRefresh(), true) : false')
            .then((result: string) => {
            if (token !== this.ports.tabRequestToken() || this.ports.activeTab() !== 0)
                return;
            if (result === 'true' || result === '"true"') {
                PinmonyRuntimeLog.info('HomeRecoveryTrace: phase=document-reused elapsedMs=' +
                    (Date.now() - this.ports.rootReadStartedAt()).toString());
                this.ports.syncAuthentication();
            }
            else {
                PinmonyRuntimeLog.info('HomeRecoveryTrace: phase=document-load reason=bridge-unavailable');
                this.ports.controller().loadUrl(address);
            }
        }).catch(() => {
            if (token !== this.ports.tabRequestToken() || this.ports.activeTab() !== 0)
                return;
            this.ports.setRootReadToken(-1);
            this.ports.setPendingWebTab(-1);
            this.homeStore.homeLoading = false;
            this.homeStore.homeError = '首页会话恢复失败，请重试';
            PinmonyRuntimeLog.warn('HomeRecoveryTrace: phase=failed reason=document-reuse');
        });
        this.ports.waitForWebTabConfirmation(index, token, this.ports.rootReadStartedAt());
        return;
    }
    try {
        this.ports.controller().loadUrl(address);
        this.ports.waitForWebTabConfirmation(index, token, Date.now());
    }
    catch (_) {
        this.ports.setRootReadToken(-1);
        this.ports.setPendingWebTab(-1);
        this.ports.setRetainedRootTabPending(-1);
        this.ports.clearRootTabGuard('page-read-failed');
        this.ports.setLoadFailed(true);
        this.ports.setFailureDetails('无法加载当前页面，请重试');
    }
}

prepareRootPageRead(index: number): boolean {
    if (this.ports.authStatus() !== 'authenticated' || this.ports.activeTab() !== index)
        return true;
    const address: string = this.ports.rootPresentationAddress(index);
    let document: string = '';
    try {
        document = this.ports.controller().getUrl();
    }
    catch (_) { }
    if (!address || this.ports.pageHistory().key(address) !== this.ports.pageHistory().key(document)) {
        this.requestRootPage(index);
        return true;
    }
    this.ports.clearRootTabGuard('page-refresh');
    return false;
}

rootReadInFlight(index: number, address: string): boolean {
    if (this.ports.loadFailed() || this.rootActionContextReady(index))
        return false;
    let document: string = '';
    try { document = this.ports.controller().getUrl(); }
    catch (_) { PinmonyRuntimeLog.warn('RootTabTrace: document-read-unavailable'); }
    if (this.ports.rootReadToken() === this.ports.tabRequestToken() &&
        (!!document && this.ports.pageHistory().key(document) === this.ports.pageHistory().key(address) ||
            this.ports.pendingWebTab() === index || this.ports.retainedRootTabPending() === index) &&
        this.ports.pageHistory().key(this.ports.rootReadAddress()) === this.ports.pageHistory().key(address) &&
        Date.now() - this.ports.rootReadStartedAt() < 12000)
        return true;
    // JS search submission may start a document without a native loadUrl call.
    try {
        return this.ports.webPageLoading() && Date.now() - this.ports.lastDocumentBeginAt() < 12000 &&
            this.ports.pageHistory().key(this.ports.lastDocumentBeginUrl()) === this.ports.pageHistory().key(address) &&
            this.ports.pageHistory().key(this.ports.controller().getUrl()) === this.ports.pageHistory().key(address);
    }
    catch (_) {
        return false;
    }
}
}
