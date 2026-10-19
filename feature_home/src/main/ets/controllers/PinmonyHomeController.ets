import { PinmonyI18n } from 'common_foundation';
import { PinmonyHomeBoard, PinmonyHomePin, PinmonyHomeSnapshot, PinmonyHomeTab } from '../models/PinmonyHome';
import { PinmonyHomePorts } from '../models/PinmonyHomePorts';
import { PinmonyHomeStore } from '../stores/PinmonyHomeStore';
import { normalizeHomeBoard } from '../services/PinmonyHomeCache';
import { retainHomePins } from '../services/PinmonyHomeRetention';
import { PIN_HOME_API_ENABLED } from '../services/PinmonyHomeApiScript';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';

// Home business owns one Store; real Web/session and product navigation stay in entry.
export class PinmonyHomeController {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private tabIntent: number = 0;
  private readonly homeStore: PinmonyHomeStore;
  private readonly ports: PinmonyHomePorts;
  constructor(homeStore: PinmonyHomeStore, ports: PinmonyHomePorts) {
    this.homeStore = homeStore;
    this.ports = ports;
  }

  invalidatePending(): void {
    this.generation++;
    this.tabIntent++;
    this.tasks.invalidate();
    this.homeStore.homeRequestToken++;
    this.homeStore.homeRefreshToken++;
    this.homeStore.homeMoreRequestToken++;
    const pending: boolean = !!this.homeStore.pendingHomeTab || this.homeStore.homeRefreshing;
    this.homeStore.pendingHomeTab = '';
    this.homeStore.homeTabNeedsRedispatch = false;
    this.homeStore.homeRefreshing = false;
    this.homeStore.homeRefreshAwaitingPage = false;
    if (pending) this.homeStore.homeLoading = false;
  }

  restoreCacheSnapshot(snapshot: PinmonyHomeSnapshot): void {
    this.homeStore.cachedHome = snapshot;
    this.homeStore.home = snapshot;
    this.homeStore.cachedHomeScrollOffset = 0;
    this.homeStore.retainingHomeFeed = true;
    this.homeStore.homeAppendRequested = false;
    this.homeStore.homeActionsReady = false;
    this.homeStore.homeLoading = false;
    this.homeStore.homeError = '';
    this.homeStore.diskCacheRestored = true;
    this.homeStore.diskCacheRestoredAt = Date.now();
    this.ports.recordPageKey(snapshot.pageKey);
  }

  prepareHomeForPageBegin(url: string, retainedDocument: boolean = false): void {
    if (this.ports.nativeReads?.() && this.ports.isAuthenticated()) { this.homeStore.homeActionsReady = false; return; }
    const pageKey: string = this.ports.pageKeyFromAddress(url);
    if (!pageKey) {
      // A root-tab route change does not invalidate the native home snapshot.
      // Keep it available while the hidden Web document changes tabs;
      // detail/board/auth routes still use the existing clear path below.
      if (this.ports.isOtherRoot(url)) {
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
      const selected: PinmonyHomeTab | undefined = this.homeStore.cachedHome.tabs.find((tab: PinmonyHomeTab): boolean => tab.selected);
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
    this.tasks.timeout(() => {
      if (token !== this.homeStore.homeRequestToken || !this.homeStore.pendingHomeTab || !this.homeStore.homeLoading) return;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = PinmonyI18n.message('分类内容加载超时，请重试');
    }, 30000);
  }

  clearHome(): void {
    if (this.ports.nativeReads?.() && this.ports.isAuthenticated()) { this.homeStore.homeActionsReady = false; return; }
    this.homeStore.homeNativeReadsReady = false;
    // A document reset can be part of the user intent waiting for a fresh context.
    this.tasks.invalidate();
    this.homeStore.homeRefreshToken++;
    this.homeStore.diskCacheRestored = false;
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

  expectHome(): void {
    if (this.ports.nativeReads?.()) { this.ports.nativeDemand?.(); return; }
    const token: number = ++this.homeStore.homeRequestToken;
    this.homeStore.homeLoading = !this.homeStore.home?.pins.length;
    this.homeStore.homeError = '';
    this.tasks.timeout(() => {
      if (token !== this.homeStore.homeRequestToken || this.homeStore.homeActionsReady || this.homeStore.homeError) return;
      this.homeStore.homeLoading = false;
      this.homeStore.homeError = this.homeStore.home?.pins.length ?
        PinmonyI18n.message('首页内容同步超时，请重试') : PinmonyI18n.message('无法读取当前 Pinterest 首页');
    }, 20000);
  }

  updateHome(value: string): void {
    if (this.ports.nativeReads?.()) {
      try { const message: PinmonyHomeSnapshot = JSON.parse(value) as PinmonyHomeSnapshot;
        if (message.kind === 'context' && typeof message.session === 'number' && typeof message.contextEpoch === 'number' &&
            message.contextEpoch >= 0 && message.contextEpoch === this.ports.documentEpoch?.() && this.ports.canAcceptMessages() &&
            this.ports.isAuthenticated() && this.homeStore.homeNativeReadsReady && message.pageKey === this.ports.currentPageKey() &&
            message.pageKey === this.homeStore.home?.pageKey) this.homeStore.homeActionsReady = true;
      } catch (_) {}
      return;
    }
    if (!this.ports.canAcceptMessages()) return;
    try {
      const message: PinmonyHomeSnapshot = JSON.parse(value) as PinmonyHomeSnapshot;
      if (!message || typeof message.session !== 'number' || typeof message.pageKey !== 'string') return;
      if (message.kind === 'closed') {
        if (!this.ports.currentPageKey()) this.clearHome();
        return;
      }
      if (message.kind !== 'state' && message.kind !== 'loading' && message.kind !== 'failed' ||
          !Array.isArray(message.tabs) || !Array.isArray(message.pins) ||
          !message.pageKey || message.pageKey !== this.ports.currentPageKey()) return;
      if (this.homeStore.homeRefreshing && this.homeStore.homeRefreshAwaitingPage) return;
      if (this.homeStore.homeActionsReady && this.homeStore.home && this.homeStore.home.pageKey === message.pageKey &&
          message.session < this.homeStore.home.session) return;
      const tabs: PinmonyHomeTab[] = message.tabs.filter((tab: PinmonyHomeTab): boolean =>
        !!tab.id && !!tab.label);
      if (!tabs.length || !tabs.some((tab: PinmonyHomeTab): boolean => tab.selected)) return;
      const board: PinmonyHomeBoard | undefined = normalizeHomeBoard(message.board);
      if (message.kind === 'failed') {
        this.homeStore.homeRefreshing = false;
        if (this.homeStore.home?.pins.length) {
          this.homeStore.homeActionsReady = false;
          this.homeStore.homeLoading = false;
          this.homeStore.pendingHomeTab = '';
          this.homeStore.homeError = message.error || PinmonyI18n.message('首页内容加载失败，请下拉重试');
          if (this.homeStore.diskCacheRestoredAt > 0) {
            PinmonyRuntimeLog.warn('HomeCache: refresh failed snapshotRetained=true actionsReady=false');
          }
          return;
        }
        this.homeStore.home = { kind: 'state', session: message.session, pageKey: message.pageKey,
          selectedTab: message.selectedTab || '', tabs: tabs, board: board, pins: [] };
        this.homeStore.homeRequestToken++;
        this.homeStore.pendingHomeTab = '';
        this.homeStore.homeTabNeedsRedispatch = false;
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = message.error || PinmonyI18n.message('分类内容加载失败，请重试');
        return;
      }
      if (message.kind === 'loading') {
        const loadingPins: PinmonyHomePin[] = message.pins.filter((pin: PinmonyHomePin): boolean =>
          !!pin.id && !!this.ports.pinIdentity(pin.pinUrl) && /^https:\/\//i.test(pin.imageUrl));
        if (this.homeStore.pendingHomeTab && !this.homeStore.retainingHomeFeed &&
            tabs.some((tab: PinmonyHomeTab): boolean => tab.id === this.homeStore.pendingHomeTab && tab.selected)) {
          this.homeStore.home = { kind: 'loading', session: message.session, pageKey: message.pageKey,
            selectedTab: message.selectedTab || '', tabs: tabs, board: board, pins: loadingPins,
            dataSource: message.dataSource };
          this.homeStore.homeActionsReady = false;
          this.homeStore.homeLoading = true;
          this.homeStore.homeError = '';
          return;
        }
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
      let pins: PinmonyHomePin[] = message.pins.filter((pin: PinmonyHomePin): boolean =>
        !!pin.id && !!this.ports.pinIdentity(pin.pinUrl) && /^https:\/\//i.test(pin.imageUrl))
        .map((pin: PinmonyHomePin): PinmonyHomePin => {
          return { id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
            imageWidth: pin.imageWidth, imageHeight: pin.imageHeight, video: pin.video,
            title: this.ports.knownPinTitle(this.ports.pinIdentity(pin.pinUrl)) || pin.title || '', hasMore: pin.hasMore,
            saved: this.ports.isSaved(this.ports.pinIdentity(pin.pinUrl)) };
        });
      if (message.kind === 'state' && message.dataSource === 'api') this.homeStore.startupFeedCommitted = true;
      const restoredFromDisk: boolean = this.homeStore.diskCacheRestored;
      if (!restoredFromDisk && !this.homeStore.homeActionsReady && this.homeStore.home?.pins.length && !pins.length) return;
      if (restoredFromDisk) {
        this.homeStore.diskCacheRestored = false;
        this.homeStore.retainingHomeFeed = false;
        PinmonyRuntimeLog.info('HomeCache: current session snapshot committed pins=' + pins.length.toString() +
          ' sinceRestoreMs=' + (Date.now() - this.homeStore.diskCacheRestoredAt).toString());
      }
      const confirmed: boolean = !this.homeStore.pendingHomeTab || tabs.some((tab: PinmonyHomeTab): boolean =>
        tab.id === this.homeStore.pendingHomeTab && tab.selected);
      if (this.homeStore.homeRefreshing && confirmed && !message.refreshing) this.homeStore.retainingHomeFeed = false;
      const retained: PinmonyHomeSnapshot | undefined = this.homeStore.retainingHomeFeed && !restoredFromDisk ?
        this.homeStore.cachedHome : undefined;
      const sameCategory: boolean = retained?.selectedTab === message.selectedTab;
      if (retained && (retained.dataSource === message.dataSource || this.homeStore.retainingHomeFeed)) {
        pins = retainHomePins(retained.pins, pins, sameCategory && this.homeStore.homeAppendRequested);
      }
      this.ports.cardsCommitted(message.pageKey, pins.length, !!retained);
      if (!retained && (!this.homeStore.cachedHome || this.homeStore.cachedHome.pageKey !== message.pageKey ||
          this.homeStore.cachedHome.selectedTab !== message.selectedTab)) this.homeStore.cachedHomeScrollOffset = 0;
      this.homeStore.home = { kind: 'state', session: message.session, pageKey: message.pageKey,
        selectedTab: retained?.selectedTab || message.selectedTab || '',
        tabs: retained && (!sameCategory || message.categorySourceFailure === true) ? retained.tabs : tabs,
        board: board || (retained && sameCategory ? retained.board : undefined),
        pins: pins,
        dataSource: message.dataSource, loadingMore: message.loadingMore, refreshing: message.refreshing,
        endReached: message.endReached, sourceError: message.sourceError,
        categorySourceFailure: message.categorySourceFailure === true };
      if (message.sourceError && message.sourceError !== this.homeStore.homeSourceWarning) {
        this.ports.showMessage(message.sourceError);
      }
      this.homeStore.homeSourceWarning = message.sourceError || '';
      this.homeStore.cachedHome = this.homeStore.home;
      this.ports.recordPageKey(message.pageKey);
      this.homeStore.homeActionsReady = !message.refreshing;
      if (this.homeStore.homeActionsReady) this.ports.contentReady(pins.length);
      if (this.homeStore.diskCacheRestoredAt > 0) {
        PinmonyRuntimeLog.info('HomeCache: current session state actionsReady=' +
          this.homeStore.homeActionsReady.toString() + ' sinceRestoreMs=' +
          (Date.now() - this.homeStore.diskCacheRestoredAt).toString());
        if (this.homeStore.homeActionsReady) this.homeStore.diskCacheRestoredAt = 0;
      }
      if (this.homeStore.homeActionsReady && !message.sourceError) this.ports.markFeedConfirmed();
      if (this.homeStore.homeTabNeedsRedispatch && this.homeStore.pendingHomeTab) {
        const requestedId: string = this.homeStore.pendingHomeTab;
        const requestedTab: PinmonyHomeTab | undefined = tabs.find((tab: PinmonyHomeTab): boolean =>
          tab.id === requestedId);
        if (requestedTab && requestedTab.selected) {
          this.homeStore.homeTabNeedsRedispatch = false;
        } else if (requestedTab) {
          this.homeStore.homeTabNeedsRedispatch = false;
          this.tasks.timeout(() => {
            if (this.homeStore.pendingHomeTab === requestedId) {
              this.selectHomeTab(requestedId, true).catch(() => {
                PinmonyRuntimeLog.warn('Pinmony: could not restore selected home category');
              });
            }
          }, 0);
          return;
        }
      }
      if (!this.homeStore.pendingHomeTab || tabs.some((tab: PinmonyHomeTab): boolean =>
          tab.id === this.homeStore.pendingHomeTab && tab.selected)) {
        this.homeStore.homeRequestToken++;
        this.homeStore.pendingHomeTab = '';
        this.homeStore.homeLoading = false;
        this.homeStore.homeRefreshing = !!message.refreshing;
        this.homeStore.homeError = message.categorySourceFailure === true ? PinmonyI18n.message('已收藏图板分类读取失败，请重试') : '';
        const committedHome: PinmonyHomeSnapshot | undefined = this.homeStore.home;
        if (message.kind === 'state' && confirmed && !message.refreshing && !message.loadingMore && !message.sourceError &&
            this.homeStore.homeActionsReady && committedHome) this.ports.persistSnapshot(committedHome);
        if (message.dataSource === 'api' && !message.refreshing && !message.sourceError) {
          this.ports.finishRecovery();
        }
      }
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid home state');
    }
  }

  async selectHomeTab(id: string, restoring: boolean = false): Promise<void> {
    if (this.ports.nativeReads?.()) { if (!this.ports.rejectOffline('home tab')) await this.ports.nativeSelect?.(id); return; }
    const generation: number = this.generation;
    const intent: number = ++this.tabIntent;
    this.ports.traceAction(restoring ? 'home.tab.restore' : 'home.tab', id);
    if (this.ports.rejectOffline('home tab')) return;
    const switching: boolean = !!this.homeStore.pendingHomeTab && this.homeStore.home?.kind === 'loading' &&
      this.ports.isActive() && this.ports.isAuthenticated() &&
      this.homeStore.home.pageKey === this.ports.currentPageKey();
    if (!restoring && !switching && !await this.ports.ensureContext(true,
      (): boolean => generation === this.generation && intent === this.tabIntent)) return;
    if (generation !== this.generation || intent !== this.tabIntent) return;
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    if (!home || (!this.homeStore.homeActionsReady && !switching) || !id || home.pageKey !== this.ports.currentPageKey()) return;
    const target: PinmonyHomeTab | undefined = home.tabs.find((tab: PinmonyHomeTab): boolean => tab.id === id);
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
      const latest: PinmonyHomeSnapshot | undefined = this.homeStore.home;
      if (latest && latest.pageKey === this.ports.currentPageKey()) {
        const result: string = await this.ports.runScript('window.PinmonyHomeTab && ' +
          'window.PinmonyHomeTab(' + latest.session.toString() + ',' + JSON.stringify(latest.pageKey) + ',' +
          JSON.stringify(id) + ')');
        dispatched = result === 'true' || result === '"true"';
      }
    } catch (_) {
      PinmonyRuntimeLog.warn('Pinmony: home API category request unavailable');
    }
    if (generation !== this.generation || token !== this.homeStore.homeRequestToken || this.homeStore.pendingHomeTab !== id) return;
    if (!dispatched) {
      if (token !== this.homeStore.homeRequestToken || this.homeStore.pendingHomeTab !== id) return;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.homeLoading = false;
      this.ports.showMessage(PinmonyI18n.message('分类暂不可用，请重试'));
      return;
    }
    this.tasks.timeout(() => {
      if (token !== this.homeStore.homeRequestToken || this.homeStore.pendingHomeTab !== id) return;
      this.homeStore.pendingHomeTab = '';
      this.homeStore.homeLoading = false;
      this.homeStore.homeRefreshing = false;
      if (restoring) this.ports.showMessage(PinmonyI18n.message('分类同步超时，请下拉重试'));
      else this.homeStore.homeError = PinmonyI18n.message('分类内容加载超时，请重试');
    }, 30000);
  }

  async loadMoreHome(): Promise<void> {
    if (this.ports.nativeReads?.()) { await this.ports.nativeMore?.(); return; }
    const generation: number = this.generation;
    if (this.ports.rejectOffline('home load-more')) return;
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    if (!home || this.homeStore.homeLoading || home.pageKey !== (this.ports.currentPageKey() || this.ports.presentationPageKey())) return;
    if (this.homeStore.pendingHomeTab || this.homeStore.homeRefreshing) return;
    const requestPage: string = home.pageKey;
    if (!this.homeStore.homeActionsReady) {
      const ready: boolean = await this.ports.ensureContext(true, (): boolean =>
        generation === this.generation && this.ports.isActive() && this.homeStore.home?.pageKey === requestPage &&
        !this.homeStore.homeRefreshing && !this.homeStore.pendingHomeTab);
      if (generation !== this.generation || !ready || !this.homeStore.home || !this.homeStore.homeActionsReady ||
          this.homeStore.home.pageKey !== requestPage) return;
    }
    this.homeStore.homeAppendRequested = true;
    const currentHome: PinmonyHomeSnapshot | undefined = this.homeStore.home;
    if (!currentHome || !this.ports.isActive() || currentHome.pageKey !== requestPage ||
        this.homeStore.homeRefreshing || this.homeStore.pendingHomeTab) return;
    this.ports.runScript('window.PinmonyHomeLoadMore && ' +
      'window.PinmonyHomeLoadMore(' + currentHome.session.toString() + ',' + JSON.stringify(currentHome.pageKey) + ')')
      .catch(() => PinmonyRuntimeLog.warn('Pinmony: home API pagination unavailable'));
  }

  refreshHome(): void {
    if (this.ports.nativeReads?.()) { if (!this.ports.recoverOffline()) this.ports.nativeRefresh?.(); return; }
    if (this.ports.recoverOffline()) return;
    if (this.ports.prepareRead()) return;
    const currentPageKey: string = this.ports.currentPageKey();
    // A failed Web main-frame load can leave getUrl() temporarily empty while
    // the retained native snapshot still identifies the valid home route.
    // Use that route to make pull-to-refresh recover the session instead of
    // repeatedly stopping at page-or-state-unavailable.
    const retainedHome: PinmonyHomeSnapshot | undefined = this.homeStore.cachedHome;
    const pageKey: string = currentPageKey || this.ports.presentationPageKey() ||
      (retainedHome ? retainedHome.pageKey : '');
    if (pageKey && !this.homeStore.homeActionsReady && !this.homeStore.homeRefreshing &&
        !this.homeStore.pendingHomeTab && this.ports.isAuthenticated()) {
      PinmonyRuntimeLog.info('HomeRecoveryTrace: phase=request source=refresh');
      this.ports.requestRead();
      return;
    }
    if (!pageKey || this.homeStore.homeRefreshing || this.homeStore.pendingHomeTab && !this.homeStore.retainingHomeFeed) {
      PinmonyRuntimeLog.info('ActionGate: home refresh blocked reason=page-or-state-unavailable');
      return;
    }
    if (this.homeStore.home?.categorySourceFailure ||
        this.homeStore.home?.kind === 'failed' && !this.homeStore.home.tabs.length) {
      const token: number = ++this.homeStore.homeRequestToken;
      const generation: number = this.generation;
      this.homeStore.homeLoading = !this.homeStore.home?.pins.length;
      this.homeStore.homeError = '';
      this.ports.runScript('window.PinmonyHomeRetryCategories && window.PinmonyHomeRetryCategories(' +
        JSON.stringify(pageKey) + ')').then((result: string) => {
        if (generation !== this.generation || token !== this.homeStore.homeRequestToken || pageKey !== this.ports.currentPageKey()) return;
        if (result === 'true' || result === '"true"') return;
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = PinmonyI18n.message('已收藏图板分类重试暂不可用，请重试');
      }).catch(() => {
        if (generation !== this.generation || token !== this.homeStore.homeRequestToken || pageKey !== this.ports.currentPageKey()) return;
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = PinmonyI18n.message('已收藏图板分类重试失败，请重试');
      });
      return;
    }
    const canRefreshApi: boolean = PIN_HOME_API_ENABLED && this.homeStore.home?.dataSource === 'api' &&
      this.homeStore.homeActionsReady;
    PinmonyRuntimeLog.info('HomeRefresh: requested source=' + (canRefreshApi ? 'api' : 'web') +
      ' actionsReady=' + this.homeStore.homeActionsReady.toString());
    const token: number = ++this.homeStore.homeRefreshToken;
    this.homeStore.homeRequestToken++;
    this.homeStore.homeRefreshing = true;
    this.homeStore.homeRefreshAwaitingPage = true;
    this.homeStore.homeActionsReady = false;
    this.homeStore.homeLoading = !this.homeStore.home?.pins.length;
    this.homeStore.homeError = '';
    try {
      const home: PinmonyHomeSnapshot | undefined = this.homeStore.home;
      if (canRefreshApi && home) {
        this.homeStore.homeRefreshAwaitingPage = false;
        this.ports.runScript('window.PinmonyHomeApiRefresh && window.PinmonyHomeApiRefresh(' +
          home.session.toString() + ',' + JSON.stringify(home.pageKey) + ')').then((result: string) => {
          if (token !== this.homeStore.homeRefreshToken || result === 'true' || result === '"true"') return;
          // The retained native snapshot may be visible while the hidden Web
          // document is still on a child route or an older session. Rebind it
          // to the current home route before treating refresh as unavailable.
          this.homeStore.homeRefreshAwaitingPage = true;
          PinmonyRuntimeLog.info('HomeRefresh: bridge-unavailable fallback=web-sync');
          try {
            this.ports.reloadPage(pageKey, false);
          } catch (_) {
            if (token !== this.homeStore.homeRefreshToken) return;
            this.homeStore.homeRefreshing = false;
            this.homeStore.homeRefreshAwaitingPage = false;
            this.homeStore.homeActionsReady = true;
            PinmonyRuntimeLog.warn('HomeRefresh: failed reason=bridge-fallback-load');
            this.ports.showMessage(PinmonyI18n.message('首页刷新失败，请重试'));
          }
        }).catch(() => {
          if (token !== this.homeStore.homeRefreshToken) return;
          this.homeStore.homeRefreshing = false;
          this.homeStore.homeActionsReady = true;
          PinmonyRuntimeLog.warn('HomeRefresh: failed reason=bridge-error');
          this.ports.showMessage(PinmonyI18n.message('首页刷新失败，请重试'));
        });
      } else if (currentPageKey === pageKey) {
        this.ports.reloadPage(pageKey, true);
      } else {
        // A retained homepage may be visible while the failed Web document is still a Pin.
        this.ports.reloadPage(pageKey, false);
      }
    } catch (error) {
      this.homeStore.homeRefreshing = false;
      this.homeStore.homeRefreshAwaitingPage = false;
      this.homeStore.homeLoading = false;
      PinmonyRuntimeLog.warn('HomeRefresh: failed reason=exception');
      this.ports.showMessage(PinmonyI18n.message('首页刷新失败，请重试'));
    }
    this.tasks.timeout(() => {
      if (token !== this.homeStore.homeRefreshToken || !this.homeStore.homeRefreshing) return;
      this.homeStore.homeRefreshing = false;
      this.homeStore.homeRefreshAwaitingPage = false;
      this.homeStore.pendingHomeTab = '';
      if (this.homeStore.home?.pins.length) {
        PinmonyRuntimeLog.warn('HomeRefresh: failed reason=timeout snapshotRetained=true');
        this.ports.showMessage(PinmonyI18n.message('首页刷新超时，请下拉重试'));
      } else {
        this.homeStore.homeLoading = false;
        this.homeStore.homeError = PinmonyI18n.message('无法读取当前 Pinterest 首页');
        PinmonyRuntimeLog.warn('HomeRefresh: failed reason=timeout snapshotRetained=false');
      }
    }, 20000);
  }

  async openHomePin(id: string): Promise<void> {
    this.ports.traceAction('home.pin.open', id);
    if (this.ports.rejectOffline('home pin')) return;
    const home: PinmonyHomeSnapshot | undefined = this.homeStore.homeForPresentation(
      this.ports.presentationPageKey() || this.ports.retainedPageKey());
    if (!home || !this.ports.isAuthenticated() || !this.ports.isActive()) return;
    const openingPin: PinmonyHomePin | undefined = home.pins.find((pin: PinmonyHomePin): boolean => pin.id === id);
    const pinUrl: string = openingPin && this.ports.pinIdentity(openingPin.pinUrl) ? openingPin.pinUrl : '';
    if (pinUrl) this.homeStore.cachedHome = home;
    if (pinUrl) this.invalidatePending();
    this.ports.openPin(pinUrl, home.pageKey);
  }

  updateHomePinTitle(pinUrl: string, value: string): void {
    const identity: string = this.ports.pinIdentity(pinUrl);
    const title: string = (value || '').trim().replace(/\s+/g, ' ').slice(0, 160);
    if (!identity || !this.ports.hasMeaningfulTitle(title)) return;
    const saved: PinmonyHomeSnapshot | undefined = this.homeStore.cachedHome;
    if (!saved || saved.dataSource === 'api') return;
    const pins: PinmonyHomePin[] = saved.pins.map((pin: PinmonyHomePin): PinmonyHomePin => {
      return { id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
        imageWidth: pin.imageWidth, imageHeight: pin.imageHeight, video: pin.video,
        title: this.ports.pinIdentity(pin.pinUrl) === identity ? title : pin.title, hasMore: pin.hasMore, saved: pin.saved };
    });
    this.homeStore.cachedHome = { kind: saved.kind, session: saved.session, pageKey: saved.pageKey,
      selectedTab: saved.selectedTab, tabs: saved.tabs, board: saved.board, pins: pins,
      dataSource: saved.dataSource, loadingMore: saved.loadingMore, refreshing: saved.refreshing,
      endReached: saved.endReached, sourceError: saved.sourceError };
    if (this.homeStore.home?.pageKey === saved.pageKey && this.homeStore.home.selectedTab === saved.selectedTab) {
      this.homeStore.home = this.homeStore.cachedHome;
    }
  }
}
