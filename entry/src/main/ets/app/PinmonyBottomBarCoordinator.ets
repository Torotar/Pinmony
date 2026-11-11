import { PinmonyPinStore } from 'feature_pin';
import { PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyAuthStatus } from 'common_session';
import { HdsTabsController, HdsAnimationMode } from '@kit.UIDesignKit';

export interface PinmonyBottomBarCoordinatorPorts {
  searchResultsVisible?: () => boolean;
  foreground?: () => boolean;
  floatingTabsMounted: () => boolean;
  setFloatingTabsMounted: (value: boolean) => void;
  floatingTabsHidden: () => boolean;
  setFloatingTabsHidden: (value: boolean) => void;
  tabsController: () => HdsTabsController;
  rootTabsScrollHidden: () => boolean[];
  setRootTabsScrollHidden: (value: boolean[]) => void;
  childBottomBarRestoreHidden: () => boolean | null;
  setChildBottomBarRestoreHidden: (value: boolean | null) => void;
  inboxContentScrollable: () => boolean;
  setInboxContentScrollable: (value: boolean) => void;
  childBottomBarRootTab: () => number;
  setChildBottomBarRootTab: (value: number) => void;
  authStatus: () => PinmonyAuthStatus;
  activeTab: () => number;
  nativeRootTabsVisible: () => boolean;
  bottomBarScrollCollapseEnabled: () => boolean;
  setBottomBarScrollCollapseEnabled: (value: boolean) => void;
  pinStore: () => PinmonyPinStore;
  floatingTabsMotionToken: () => number;
  setFloatingTabsMotionToken: (value: number) => void;
  coordinatorTasks: () => PinmonyTaskRegistry;
}

export class PinmonyBottomBarCoordinator {
  private readonly ports: PinmonyBottomBarCoordinatorPorts;
  private scrollDistance: number = 0;
  private scrollTab: number = -1;
  private lastScrollAt: number = 0;
  private lastAnimationAt: number = 0;
  private pendingScrollAnimation: number = -1;
  // Application request spacing, not an assumed HDS animation duration.
  private readonly scrollAnimationSpacingMs: number = 320;
  private readonly scrollDirectionThresholdVp: number = 20;
  constructor(ports: PinmonyBottomBarCoordinatorPorts) { this.ports = ports; }

  resetForSession(): void {
    this.resetScrollMotion();
    this.rootTabsScrollHidden = [false, false, false, false];
    this.childBottomBarRestoreHidden = null;
    this.childBottomBarRootTab = -1;
    ++this.floatingTabsMotionToken;
    if (this.floatingTabsMounted && this.authStatus === 'authenticated' && this.nativeRootTabsVisible()) {
      // A controller reused after logout may still retain its platform hide state.
      this.floatingTabsHidden = true;
      this.setBottomBarHidden(false, HdsAnimationMode.CLICK_ANIMATION);
    }
  }

  private get floatingTabsMounted(): boolean { return this.ports.floatingTabsMounted(); }
  private set floatingTabsMounted(value: boolean) { this.ports.setFloatingTabsMounted(value); }
  private get floatingTabsHidden(): boolean { return this.ports.floatingTabsHidden(); }
  private set floatingTabsHidden(value: boolean) { this.ports.setFloatingTabsHidden(value); }
  private get tabsController(): HdsTabsController { return this.ports.tabsController(); }
  private get rootTabsScrollHidden(): boolean[] { return this.ports.rootTabsScrollHidden(); }
  private set rootTabsScrollHidden(value: boolean[]) { this.ports.setRootTabsScrollHidden(value); }
  private get childBottomBarRestoreHidden(): boolean | null { return this.ports.childBottomBarRestoreHidden(); }
  private set childBottomBarRestoreHidden(value: boolean | null) { this.ports.setChildBottomBarRestoreHidden(value); }
  private get inboxContentScrollable(): boolean { return this.ports.inboxContentScrollable(); }
  private set inboxContentScrollable(value: boolean) { this.ports.setInboxContentScrollable(value); }
  private get childBottomBarRootTab(): number { return this.ports.childBottomBarRootTab(); }
  private set childBottomBarRootTab(value: number) { this.ports.setChildBottomBarRootTab(value); }
  private get authStatus(): PinmonyAuthStatus { return this.ports.authStatus(); }
  private get activeTab(): number { return this.ports.activeTab(); }
  private get nativeRootTabsVisible(): () => boolean { return this.ports.nativeRootTabsVisible; }
  private get bottomBarScrollCollapseEnabled(): boolean { return this.ports.bottomBarScrollCollapseEnabled(); }
  private set bottomBarScrollCollapseEnabled(value: boolean) { this.ports.setBottomBarScrollCollapseEnabled(value); }
  private get pinStore(): PinmonyPinStore { return this.ports.pinStore(); }
  private get floatingTabsMotionToken(): number { return this.ports.floatingTabsMotionToken(); }
  private set floatingTabsMotionToken(value: number) { this.ports.setFloatingTabsMotionToken(value); }
  private get coordinatorTasks(): PinmonyTaskRegistry { return this.ports.coordinatorTasks(); }

  private cancelPendingScrollAnimation(): void {
    if (this.pendingScrollAnimation !== -1) this.coordinatorTasks.cancelTimeout(this.pendingScrollAnimation);
    this.pendingScrollAnimation = -1;
  }

  private resetScrollMotion(): void {
    this.cancelPendingScrollAnimation();
    this.scrollDistance = 0;
    this.scrollTab = -1;
    this.lastScrollAt = 0;
  }

  setBottomBarHidden(hidden: boolean,
    mode: HdsAnimationMode = HdsAnimationMode.SCROLL_ANIMATION, force: boolean = false): void {
    if (!this.floatingTabsMounted) { this.resetScrollMotion(); return; }
    if (mode === HdsAnimationMode.SCROLL_ANIMATION && !force) {
      // Replace any queued reversal with the latest confirmed direction.
      this.cancelPendingScrollAnimation();
      if (this.floatingTabsHidden === hidden) return;
      const remaining: number = this.scrollAnimationSpacingMs - (Date.now() - this.lastAnimationAt);
      if (remaining > 0) {
        const tab: number = this.activeTab;
        this.pendingScrollAnimation = this.coordinatorTasks.timeout((): void => {
          this.pendingScrollAnimation = -1;
          if (tab !== this.activeTab || !this.floatingTabsMounted || this.authStatus !== 'authenticated' ||
              this.ports.foreground?.() === false ||
              !this.bottomBarScrollCollapseEnabled || !this.nativeRootTabsVisible() ||
              this.pinStore.detailOpeningPin || this.ports.searchResultsVisible?.() ||
              tab === 2 && !this.inboxContentScrollable) return;
          this.setBottomBarHidden(hidden, HdsAnimationMode.SCROLL_ANIMATION);
        }, remaining);
        return;
      }
      this.rootTabsScrollHidden[this.activeTab] = hidden;
    } else if (force || this.floatingTabsHidden !== hidden) {
      this.resetScrollMotion();
    }
    if (!force && this.floatingTabsHidden === hidden) return;
    this.lastAnimationAt = Date.now();
    this.floatingTabsHidden = hidden;
    if (hidden) this.tabsController.applyHideAnimation(mode);
    else this.tabsController.applyShowAnimation(mode);
  }

  resumeAfterForeground(): void {
    this.resetScrollMotion();
    ++this.floatingTabsMotionToken;
    this.coordinatorTasks.timeout(() => {
      if (!this.floatingTabsMounted) return;
      if (this.authStatus === 'authenticated' && this.nativeRootTabsVisible() &&
          !this.pinStore.detailOpeningPin && !this.ports.searchResultsVisible?.()) {
        this.rootTabsScrollHidden[this.activeTab] = false;
        this.childBottomBarRestoreHidden = null;
        this.childBottomBarRootTab = -1;
      }
      this.syncBottomBarForPageDepth();
      // The HDS animation can be interrupted while the app is backgrounded;
      // the local boolean alone cannot confirm the platform's visual state.
      this.setBottomBarHidden(this.floatingTabsHidden, HdsAnimationMode.CLICK_ANIMATION, true);
    }, 0);
  }

  onBottomBarScrollSettingChanged(): void {
    this.resetScrollMotion();
    this.rootTabsScrollHidden = [false, false, false, false];
    if (this.childBottomBarRestoreHidden !== null) this.childBottomBarRestoreHidden = false;
    this.syncFloatingTabsMotion();
  }

  updateInboxScrollAvailability(scrollable: boolean): void {
    this.inboxContentScrollable = scrollable;
    if (scrollable) return;
    if (this.activeTab === 2) this.resetScrollMotion();
    this.rootTabsScrollHidden[2] = false;
    if (this.childBottomBarRootTab === 2) this.childBottomBarRestoreHidden = false;
    if (this.authStatus === 'authenticated' && this.activeTab === 2 && this.nativeRootTabsVisible()) {
      this.setBottomBarHidden(false, HdsAnimationMode.CLICK_ANIMATION);
    }
  }

  handleRootContentScroll(offset: number, state: ScrollState): void {
    if (this.ports.searchResultsVisible?.() || this.activeTab === 2 && !this.inboxContentScrollable ||
        this.ports.foreground?.() === false ||
        !this.bottomBarScrollCollapseEnabled ||
        !this.floatingTabsMounted || this.authStatus !== 'authenticated' ||
        this.pinStore.detailOpeningPin || !this.nativeRootTabsVisible()) {
      this.resetScrollMotion();
      return;
    }
    if (state !== ScrollState.Scroll) {
      this.scrollDistance = 0;
      this.lastScrollAt = 0;
      return;
    }
    if (!Number.isFinite(offset) || Math.abs(offset) < 0.1) return;
    const now: number = Date.now();
    if (this.scrollTab !== this.activeTab || now - this.lastScrollAt > 160 || this.scrollDistance * offset < 0) {
      this.scrollDistance = 0;
    }
    this.scrollTab = this.activeTab;
    this.lastScrollAt = now;
    this.scrollDistance += offset;
    if (Math.abs(this.scrollDistance) < this.scrollDirectionThresholdVp) return;
    this.scrollDistance = 0;
    this.setBottomBarHidden(offset > 0);
  }

  syncBottomBarForPageDepth(): void {
    if (this.scrollTab !== -1 && this.scrollTab !== this.activeTab) this.resetScrollMotion();
    if (this.authStatus !== 'authenticated') {
      this.resetScrollMotion();
      this.rootTabsScrollHidden = [false, false, false, false];
      this.childBottomBarRestoreHidden = null;
      this.childBottomBarRootTab = -1;
      this.setBottomBarHidden(true, HdsAnimationMode.CLICK_ANIMATION);
      return;
    }
    if (this.pinStore.detailOpeningPin || !this.nativeRootTabsVisible() || this.ports.searchResultsVisible?.()) {
      this.resetScrollMotion();
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

  syncFloatingTabsMotion(): void {
    const token: number = ++this.floatingTabsMotionToken;
    // Web route and native snapshot fields can change together in one turn.
    this.coordinatorTasks.timeout(() => {
      if (token !== this.floatingTabsMotionToken || !this.floatingTabsMounted) return;
      this.syncBottomBarForPageDepth();
    }, 0);
  }
}
