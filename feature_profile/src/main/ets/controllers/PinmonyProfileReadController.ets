import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyProfileStore } from '../stores/PinmonyProfileStore';
import { PinmonyProfileSnapshot, PinmonyProfileAction, PinmonyBoard, PinmonyCreatedPin } from '../models/PinmonyProfile';
export interface PinmonyProfileReadPorts {
  authenticated: () => boolean;
  foreground: () => boolean;
  document: () => string;
  addressKey: (address: string) => string;
  profileAddress: (address: string) => string;
  currentProfile: () => string;
  rootOnly: () => boolean;
  interacted: () => boolean;
  backTarget: () => string;
  apiEnabled: () => boolean;
  activeTab: () => number;
  pendingTab: () => number;
  rootAddress: () => string;
  selectProfile: () => void;
  confirmPending: () => void;
  recordAddress: (address: string) => void;
  clearProfile: (preserve: boolean) => void;
  prepareRead: () => boolean;
  requestRead: () => void;
  runScript: (script: string) => Promise<string>;
}
export class PinmonyProfileReadController {
  private readonly store: PinmonyProfileStore;
  private readonly ports: PinmonyProfileReadPorts;
  private readonly loadingTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly pullTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private loadingMore: boolean = false;
  constructor(store: PinmonyProfileStore, ports: PinmonyProfileReadPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.generation++; this.loadingTasks.invalidate(); this.finishPull(); this.loadingMore = false; }
  resume(): void { if (!this.store.profile && this.store.profileLoading && this.ports.authenticated() && this.ports.foreground()) this.expect(); }
  restore(address: string): boolean {
    const url: string = this.ports.profileAddress(address);
    const section: string = /\/_created(?:\/|[?#]|$)/i.test(address) ? 'created' : 'saved';
    const entry = this.store.profileCache.get(url, section);
    if (!entry) return false;
    this.store.profile = entry.snapshot;
    this.store.profileUrl = url;
    this.store.profileScrollOffset = entry.scrollOffset;
    this.store.profileActionsReady = false;
    this.store.profileSessionReady = false;
    this.store.profileLoading = false;
    this.store.profileError = '';
    return true;
  }

  expect(): void {
    if (!this.ports.authenticated() || !this.ports.foreground()) return;
    let address: string = '';
    if (this.ports.pendingTab() === 3) address = this.ports.rootAddress() || '';
    else { try { address = this.ports.document(); } catch (_) {} }
    if (this.restore(address)) return;
    if (this.ports.pendingTab() === 3 && this.restore(this.ports.rootAddress() || '')) return;
    this.store.profileRequestToken++;
    this.loadingTasks.invalidate();
    const token: number = this.store.profileRequestToken;
    this.store.profileLoading = true;
    this.store.profileError = '';
    const generation: number = this.generation;
    this.loadingTasks.invalidate();
    this.loadingTasks.timeout((): void => {
      if (generation !== this.generation || !this.ports.authenticated() || !this.ports.foreground() || token !== this.store.profileRequestToken || this.store.profile || !this.store.profileLoading) return;
      if (this.ports.activeTab() !== 3 && !this.ports.currentProfile()) {
        this.ports.clearProfile(false);
        return;
      }
      this.store.profileLoading = false;
      this.store.profileError = this.ports.currentProfile() ? '无法读取当前 Pinterest 资料页' :
        '网页未进入资料页，请重试';
    }, 8000);
  }

  update(value: string): void {
    if (!this.ports.authenticated() || !this.ports.foreground()) return;
    if (this.ports.rootOnly() && !this.ports.interacted()) return;
    if (this.ports.backTarget()) {
      try {
        if (this.ports.addressKey(this.ports.document()) !== this.ports.addressKey(this.ports.backTarget())) return;
      } catch (_) { return; }
    }
    try {
      const message: PinmonyProfileSnapshot = JSON.parse(value) as PinmonyProfileSnapshot;
      if (!message || typeof message.session !== 'number' || !Number.isInteger(message.session) || message.session < 0 || typeof message.profileUrl !== 'string') return;
      if (this.ports.apiEnabled() && (message.kind === 'apiPending' || message.kind === 'apiFailed')) {
        if (message.session < this.store.profileSession || this.ports.currentProfile() !== message.profileUrl) return;
        this.store.profileRequestToken++;
    this.loadingTasks.invalidate();
        this.store.profileSession = message.session;
        this.store.profileUrl = message.profileUrl;
        this.store.profileActionsReady = false;
        this.store.profileSessionReady = false;
        if (!this.restore(message.profileUrl + (message.section === 'created' ? '_created/' : ''))) {
          this.store.profile = undefined;
        }
        this.store.profileLoading = !this.store.profile && message.kind === 'apiPending';
        this.store.profileError = message.kind === 'apiFailed' ? '用户资料接口读取失败，请重试' : '';
        if (message.kind === 'apiFailed') this.finishPull();
        if (this.store.profileLoading) this.expect();
        return;
      }
      if (message.kind === 'closed') {
        if (this.ports.currentProfile()) return;
        if (message.session >= this.store.profileSession) this.ports.clearProfile(this.store.profileWebFlow);
        return;
      }
      if (message.kind === 'unavailable') {
        if (message.session >= this.store.profileSession &&
            this.ports.currentProfile() === message.profileUrl) {
          this.store.profileRequestToken++;
    this.loadingTasks.invalidate();
          this.store.profile = undefined;
          this.store.profileSession = message.session;
          this.store.profileSessionReady = false;
          this.store.profileUrl = message.profileUrl;
          this.store.profileLoading = false;
          this.store.profileError = '无法读取当前 Pinterest 资料页';
          this.finishPull();
        }
        return;
      }
      if (message.kind === 'flowClosed') {
        if (message.session === this.store.profileSession && message.profileUrl === this.store.profileUrl) {
          this.store.profileWebFlow = false;
        }
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') || message.session < this.store.profileSession ||
        (message.section !== 'saved' && message.section !== 'created') ||
        !Array.isArray(message.actions) || !Array.isArray(message.boards) ||
        !Array.isArray(message.createdPins) || this.ports.currentProfile() !== message.profileUrl) return;
      if (this.store.profileFlowLeftPage) {
        this.store.profileWebFlow = false;
        this.store.profileFlowLeftPage = false;
      }
      this.store.profileSession = message.session;
      this.store.profileUrl = message.profileUrl;
      this.store.profileRequestToken++;
    this.loadingTasks.invalidate();
      this.store.profileLoading = false;
      this.store.profileError = '';
      if (this.store.origins.length === 0 && !this.ports.rootOnly()) {
        this.ports.selectProfile();
      }
      if (this.ports.pendingTab() === 3) this.ports.confirmPending();
      this.store.profileSwitching = false;
      const actions: PinmonyProfileAction[] = message.actions.filter((item: PinmonyProfileAction): boolean =>
        !!item.id && !!item.kind && (!!item.label || item.kind === 'settings'));
      const boards: PinmonyBoard[] = message.boards.filter((item: PinmonyBoard): boolean =>
        !!item.id && !!item.title && Array.isArray(item.covers));
      const createdPins: PinmonyCreatedPin[] = message.createdPins.filter((item: PinmonyCreatedPin): boolean =>
        !!item.id && !!item.imageUrl);
      const retained = this.store.profileCache.get(message.profileUrl, message.section);
      const retainingContent: boolean = !!retained && (message.contentLoading === true || !!message.contentError);
      if (this.store.profile && (this.store.profile.profileUrl !== message.profileUrl || this.store.profile.section !== message.section)) {
        this.store.profileScrollOffset = 0;
      }
      this.store.profile = {
        kind: 'state', session: message.session, profileUrl: message.profileUrl, section: message.section,
        displayName: message.displayName || '', handle: message.handle || '',
        avatarUrl: message.avatarUrl || '', followers: message.followers || '',
        monthlyViews: typeof message.monthlyViews === 'number' && Number.isSafeInteger(message.monthlyViews) &&
          message.monthlyViews >= 0 ? message.monthlyViews : undefined,
        following: message.following || '', actions: actions,
        business: message.business === true, isOwn: message.isOwn, about: typeof message.about === 'string' ? message.about.slice(0, 2000) : '',
        website: typeof message.website === 'string' && /^https?:\/\//.test(message.website) ? message.website.slice(0, 2000) : '',
        boards: retainingContent && retained ? retained.snapshot.boards : boards,
        createdPins: retainingContent && retained ? retained.snapshot.createdPins : createdPins,
        contentLoading: !retainingContent && message.contentLoading === true, contentLoadingMore: message.contentLoadingMore === true,
        contentError: message.contentError || '',
        unorganizedPins: Array.isArray(message.unorganizedPins) ? message.unorganizedPins.filter(
          (pin: PinmonyCreatedPin): boolean => !!pin.id && !!pin.imageUrl) : [],
        unorganizedLoading: message.unorganizedLoading === true,
        unorganizedError: message.unorganizedError || '', unorganizedHasMore: message.unorganizedHasMore === true,
        unorganizedFeedback: message.unorganizedFeedback || '', organize: message.organize || undefined
      };
      this.store.profileActionsReady = !retainingContent;
      this.store.profileSessionReady = message.kind === 'state';
      if (this.store.profileActionsReady && this.store.origins.length === 0) this.ports.recordAddress(
        message.profileUrl + (message.section === 'created' ? '_created/' : ''));
      if (message.contentLoading !== true || !!message.contentError) this.finishPull();
      if (this.store.profileActionsReady) this.store.profileCache.put(this.store.profile, this.store.profileScrollOffset);
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid profile state');
    }
  }

  finishPull(): void {
    this.pullTasks.invalidate();
    this.store.profilePullRefreshing = false;
    this.store.profilePullToken++;
  }

  refresh(pull: boolean = false): void {
    if (!this.ports.authenticated() || !this.ports.foreground()) return;
    const generation: number = this.generation;
    if (this.ports.rootOnly() && this.ports.prepareRead()) return;
    if (this.store.profilePullRefreshing) return;
    if (pull && (!this.store.profile || this.store.profileSwitching)) return;
    if (pull && this.store.profile) this.store.profileCache.put(this.store.profile, this.store.profileScrollOffset);
    else this.store.profileCache.clear();
    this.store.profileActionsReady = false;
    this.store.profileSessionReady = false;
    this.store.profileError = '';
    if (!this.ports.currentProfile()) {
      this.ports.requestRead();
      return;
    }
    if (pull) {
      this.store.profilePullRefreshing = true;
      const token: number = ++this.store.profilePullToken;
      const page: string = this.ports.currentProfile(), document: string = this.ports.document();
      this.pullTasks.timeout((): void => {
        if (generation !== this.generation || !this.ports.authenticated() || !this.ports.foreground() || token !== this.store.profilePullToken || !this.store.profilePullRefreshing || this.ports.currentProfile() !== page || this.ports.document() !== document) return;
        this.finishPull();
        this.store.profileError = '刷新超时，请重试';
      }, 20000);
    }
    if (!this.store.profile && !this.store.profileLoading) this.expect();
    const request: number = this.store.profileRequestToken, pullToken: number = this.store.profilePullToken, page: string = this.ports.document();
    this.ports.runScript('window.PinmonyProfileRefresh && window.PinmonyProfileRefresh(' + pull.toString() + ')')
      .catch(() => {
        if (generation !== this.generation || request !== this.store.profileRequestToken || pullToken !== this.store.profilePullToken || page !== this.ports.document() || !this.ports.authenticated() || !this.ports.foreground()) return;
        this.finishPull();
        this.store.profileLoading = false;
        this.store.profileError = '无法读取当前 Pinterest 资料页';
      });
  }

  loadMore(): void {
    if (!this.ports.authenticated() || !this.ports.foreground() || this.loadingMore) return;
    if (this.store.profileActionsReady === false) return;
    const profile: PinmonyProfileSnapshot | undefined = this.store.profile;
    if (!profile || profile.contentLoadingMore || profile.contentLoading || this.ports.currentProfile() !== profile.profileUrl) return;
    const generation: number = this.generation;
    this.loadingMore = true;
    this.ports.runScript('window.PinmonyProfileLoadMore && ' +
      'window.PinmonyProfileLoadMore(' + profile.session.toString() + ',' + JSON.stringify(profile.profileUrl) + ')')
      .catch(() => { if (generation === this.generation) PinmonyRuntimeLog.warn('Pinmony: profile content loading unavailable'); }).finally(() => { if (generation === this.generation) this.loadingMore = false; });
  }

}
