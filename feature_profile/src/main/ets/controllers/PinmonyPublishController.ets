import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyProfileStore } from '../stores/PinmonyProfileStore';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { PinmonyProfileSnapshot, PinmonyPublishOption, PinmonyCreatedPin, PinmonyOrganizeBoard } from '../models/PinmonyProfile';

export interface PinmonyPublishPorts {
  nativeFlow?: () => boolean;
  nativeMenu?: (current: () => boolean) => Promise<boolean>;
  nativeOpen?: () => Promise<boolean>;
  nativeAction?: (action: string,value: string,secret: boolean) => Promise<void>;
  nativePause?: () => void;
  nativeClose?: () => void;
  authenticated: () => boolean;
  foreground: () => boolean;
  activeProfileTab: () => boolean;
  menuVisible: () => boolean;
  sheetAvailable: () => boolean;
  setMenuVisible: (visible: boolean) => void;
  waitMenuClosed: () => Promise<boolean>;
  openSection: () => void;
  profileAddress: () => string;
  documentMatches: (profile: string) => boolean;
  currentDocument: () => string;
  normalizeProfile: (address: string) => string;
  prepareContext: (current: () => boolean) => Promise<boolean>;
  nativeEnabled: () => boolean;
  publishScript: () => string;
  runScript: (script: string) => Promise<string>;
  jsonText: (value: string) => string;
  captureBoardReturn: () => void;
  hasBoardReturn: () => boolean;
  restoreBoard: (refresh?: boolean) => void;
  syncMotion: () => void;
  suppressChildBack: () => void;
  refreshProfile: () => void;
  pickPhotos: (token: number, page: string) => Promise<void>;
  feedback: (value: string) => void;
  traceEntry: () => void;
}

export class PinmonyPublishController {
  private readonly store: PinmonyProfileStore;
  private readonly ports: PinmonyPublishPorts;
  private readonly menuTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly flowTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private menuGeneration: number = 0;
  private flowGeneration: number = 0;
  private polling: boolean = false;
  private selecting: boolean = false;

  constructor(store: PinmonyProfileStore, ports: PinmonyPublishPorts) { this.store = store; this.ports = ports; }

  pause(): void {
    this.menuGeneration++; this.menuTasks.invalidate();
    this.store.publishPreparing = false;
    this.pauseFlow();
  }

  private pauseFlow(): void {
    if(this.ports.nativeFlow?.())this.ports.nativePause?.();
    this.flowGeneration++; this.flowTasks.invalidate(); this.polling = false;
  }

  resume(): void {
    const flow: PinmonyPublishFlow | undefined = this.store.publishFlow;
    if (flow) { if(!this.ports.nativeFlow?.())this.poll(flow.token, flow.page); }
    else if (this.ports.menuVisible() && this.store.publishLoading && this.store.profile) {
      this.readMenuWhenReady(this.store.profile.profileUrl, Date.now() + 8000, this.store.publishRequestToken);
    }
  }

  private currentMenu(token: number, url: string, generation: number): boolean {
    return generation === this.menuGeneration && token === this.store.publishRequestToken &&
      this.ports.authenticated() && this.ports.foreground() && this.ports.activeProfileTab() &&
      this.ports.menuVisible() && this.store.profile?.profileUrl === url;
  }

  openMenu(): void {
    this.ports.traceEntry();
    const profile: PinmonyProfileSnapshot | undefined = this.store.profile;
    const url: string = profile?.profileUrl || this.ports.profileAddress();
    if (!url || !this.ports.sheetAvailable() || this.store.publishPreparing ||
        this.store.publishLoading && this.store.publishRequestToken > 0 || !this.ports.authenticated() ||
        !this.ports.foreground() || !this.ports.activeProfileTab()) return;
    this.menuGeneration++; this.menuTasks.invalidate();
    const generation: number = this.menuGeneration;
    this.ports.captureBoardReturn();
    this.store.publishOptions = []; this.store.publishTitle = ''; this.store.publishLoading = true;
    this.ports.setMenuVisible(true);
    const token: number = ++this.store.publishRequestToken;
    this.store.publishPreparing = true;
    // A missing profile can be loaded by preparation. Do not require it before preparation.
    const current: () => boolean = (): boolean => generation === this.menuGeneration &&
      token === this.store.publishRequestToken && this.ports.authenticated() && this.ports.foreground() &&
      this.ports.menuVisible() && this.ports.activeProfileTab();
    PinmonyRuntimeLog.info('PublishTrace: entry accepted');
    if(this.ports.nativeFlow?.() && this.ports.nativeMenu){
      this.ports.nativeMenu(current).then((ready: boolean): void => {if(current() && !ready)this.ports.feedback(PinmonyI18n.message("pm_publishing_not_ready_close_and_retry_ba174c2b"));}).finally((): void => {if(current())this.store.publishPreparing = false;});return;
    }
    this.ports.prepareContext(current).then((ready: boolean): void => {
      if (!current()) return;
      if (ready && this.store.profile?.profileUrl === url && this.ports.documentMatches(url)) {
        this.readMenuWhenReady(url, Date.now() + 8000, token);
      } else {
        this.store.publishLoading = false;
        this.ports.feedback(PinmonyI18n.message("pm_publishing_not_ready_close_and_retry_ba174c2b"));
      }
    }).catch((): void => {
      if (!current()) return;
      this.store.publishLoading = false;
      this.ports.feedback(PinmonyI18n.message("pm_publishing_not_ready_close_and_retry_ba174c2b"));
    }).finally((): void => {
      if (generation === this.menuGeneration && token === this.store.publishRequestToken) this.store.publishPreparing = false;
    });
  }

  private menuError(token: number, url: string, generation: number): void {
    if (!this.currentMenu(token, url, generation)) return;
    this.store.publishLoading = false;
    this.ports.feedback(PinmonyI18n.message("pm_publishing_not_ready_close_and_retry_ba174c2b"));
  }

  readMenuWhenReady(url: string, deadline: number, token: number): void {
    const generation: number = this.menuGeneration;
    if (!this.currentMenu(token, url, generation)) return;
    if(this.ports.nativeFlow?.() && this.ports.nativeMenu){this.ports.nativeMenu((): boolean => this.currentMenu(token,url,generation));return;}
    if (!this.store.profileSessionReady || !this.ports.documentMatches(url)) {
      if (Date.now() >= deadline) { this.menuError(token, url, generation); return; }
      this.menuTasks.timeout((): void => this.readMenuWhenReady(url, deadline, token), 150);
      return;
    }
    const session: number = this.store.profile!.session;
    this.ports.runScript('window.PinmonyProfilePublishDiscover && window.PinmonyProfilePublishDiscover(' +
      session.toString() + ',' + JSON.stringify(url) + ')').then((result: string): void => {
      if (!this.currentMenu(token, url, generation) || this.store.profile?.session !== session) return;
      PinmonyRuntimeLog.info('PublishTrace: discover dispatched result=' + (result === 'true' || result === '"true"' ? 'accepted' : 'rejected'));
      if (result !== 'true' && result !== '"true"') this.store.publishLoading = false;
    }).catch((): void => {
      if (this.currentMenu(token, url, generation) && this.store.profile?.session === session) this.store.publishLoading = false;
    });
  }

  dismissMenu(restore: boolean = true): void {
    if(this.ports.nativeFlow?.())this.ports.nativePause?.();
    if (restore) this.ports.suppressChildBack();
    if (restore && this.selecting) this.pauseFlow();
    // bindSheet may already have cleared its visibility before dismissal arrives.
    // Always release the logical menu and pending reads as well.
    this.menuGeneration++; this.menuTasks.invalidate(); this.store.publishRequestToken++;
    this.store.publishPreparing = false;
    const session: number = this.store.profileSession, url: string = this.store.profileUrl;
    this.ports.setMenuVisible(false);
    this.store.publishLoading = false; this.store.publishOptions = []; this.store.publishTitle = '';
    if(!this.ports.nativeFlow?.())this.ports.runScript('window.PinmonyProfilePublishClose && window.PinmonyProfilePublishClose(' +
      session.toString() + ',' + JSON.stringify(url) + ')').catch(() => {});
    if (restore && !this.selecting && !this.store.publishFlow) this.ports.restoreBoard();
  }

  isCurrent(token: number, page: string): boolean {
    return this.ports.authenticated() && token === this.store.publishFlowToken &&
      this.store.publishFlow?.token === token && this.ports.currentDocument() === page;
  }

  async select(id: string): Promise<void> {
    const profile: PinmonyProfileSnapshot | undefined = this.store.profile;
    if (!profile || !this.ports.menuVisible() || !this.ports.authenticated() || !this.ports.foreground() ||
        this.store.publishFlow || this.selecting || !this.ports.nativeEnabled()) return;
    const option: PinmonyPublishOption | undefined = this.store.publishOptions.find((item: PinmonyPublishOption): boolean => item.id === id && item.enabled);
    if (!option || !['website', 'photo', 'board'].includes(option.kind)) return;
    const page: string = this.ports.currentDocument();
    if (this.ports.normalizeProfile(page) !== this.ports.normalizeProfile(profile.profileUrl)) return;
    this.pauseFlow();
    const generation: number = this.flowGeneration;
    const token: number = ++this.store.publishFlowToken;
    this.selecting = true;
    const closed: Promise<boolean> = this.ports.waitMenuClosed();
    this.dismissMenu(false);
    const disappeared: boolean = await closed;
    this.selecting = false;
    if (!disappeared || generation !== this.flowGeneration || token !== this.store.publishFlowToken ||
        !this.ports.authenticated() || !this.ports.foreground() || this.ports.currentDocument() !== page) {
      this.ports.restoreBoard();
      return;
    }
    this.store.publishFlow = { token: token, page: page, profile: profile.profileUrl, kind: option.kind,
      phase: option.kind === 'board' ? 'create' : option.kind === 'photo' ? 'photo' : 'website',
      pins: [], selectedIds: [], boards: [], loading: true, busy: false, error: '', feedback: '', hasMore: false, uncertain: false, completed: 0 };
    PinmonyRuntimeLog.info('PublishTrace: selected kind=' + option.kind);
    this.ports.syncMotion();
    try {
      if(this.ports.nativeFlow?.() && this.ports.nativeOpen){
        const opened: boolean = await this.ports.nativeOpen();
        if(opened && this.isCurrent(token,page) && option.kind === 'photo')await this.ports.pickPhotos(token,page);
        return;
      }
      const result: string = await this.ports.runScript(this.ports.publishScript() +
        'window.PinmonyPublishApi.open(' + JSON.stringify(profile.profileUrl) + ',' + JSON.stringify(option.kind) + ',' + token.toString() + ')');
      if (generation !== this.flowGeneration || !this.isCurrent(token, page)) return;
      if (result !== 'true' && result !== '"true"') throw new Error('unavailable');
      if (option.kind === 'photo') {
        this.store.publishFlow!.loading = false;
        this.commit(this.store.publishFlow!);
        await this.ports.pickPhotos(token, page);
        if (this.isCurrent(token, page)) this.poll(token, page);
      } else this.poll(token, page);
    } catch (_) {
      if (generation === this.flowGeneration && this.isCurrent(token, page)) {
        this.store.publishFlow!.loading = false; this.store.publishFlow!.error = PinmonyI18n.message("pm_publishing_service_unavailable_go_back_and_retry_771a82b9");
        this.commit(this.store.publishFlow!);
      }
    }
  }

  async selectSection(): Promise<void> {
    if (this.selecting || !this.ports.menuVisible() || !this.ports.hasBoardReturn() ||
        !this.ports.authenticated() || !this.ports.foreground()) return;
    this.pauseFlow();
    const generation: number = this.flowGeneration;
    this.selecting = true;
    const closed: Promise<boolean> = this.ports.waitMenuClosed();
    this.dismissMenu(false);
    const disappeared: boolean = await closed;
    this.selecting = false;
    if (!disappeared || generation !== this.flowGeneration || !this.ports.authenticated() || !this.ports.foreground()) {
      this.ports.restoreBoard(); return;
    }
    this.ports.openSection();
  }

  poll(token: number, page: string): void {
    if(this.ports.nativeFlow?.())return;
    const generation: number = this.flowGeneration;
    if (this.polling || !this.ports.foreground() || !this.isCurrent(token, page)) return;
    this.flowTasks.invalidate(); this.polling = true;
    this.ports.runScript('JSON.stringify(window.PinmonyPublishApi.read(' + token.toString() + '))').then((raw: string): void => {
      if (generation !== this.flowGeneration || !this.ports.foreground() || !this.isCurrent(token, page)) return;
      const value: PinmonyPublishFlow = JSON.parse(this.ports.jsonText(raw)) as PinmonyPublishFlow;
      if (!value || value.token !== token || value.page !== page || value.profile !== this.store.publishFlow?.profile ||
          !Array.isArray(value.pins) || value.pins.length > 100 || !Array.isArray(value.boards) || value.boards.length > 2000 ||
          !Array.isArray(value.selectedIds) || value.selectedIds.length > 100 || value.kind !== this.store.publishFlow?.kind ||
          !['website', 'photo', 'select', 'boards', 'create', 'empty', 'done'].includes(value.phase) ||
          !Number.isInteger(value.completed) || value.completed < 0 || value.completed > 100 ||
          value.pins.some((pin: PinmonyCreatedPin): boolean => !pin || typeof pin.id !== 'string' || typeof pin.imageUrl !== 'string') ||
          value.boards.some((board: PinmonyOrganizeBoard): boolean => !board || !/^\d+$/.test(board.id) || typeof board.title !== 'string')) throw new Error('invalid');
      value.loading = value.loading || this.store.publishPicking;
      this.store.publishFlow = value;
      if (value.phase === 'done') {
        const completed: number = value.completed, boardOnly: boolean = value.kind === 'board';
        this.close();
        if (completed > 0) this.ports.feedback(boardOnly ? PinmonyI18n.message("pm_board_created_f7d22eaf") : PinmonyI18n.message("pm_published_58e1bd74") + completed.toString() + PinmonyI18n.message("pm_pins_0a89904f"));
        return;
      }
      if (value.phase === 'photo' && !value.loading && !value.error && !this.store.publishPicking) this.ports.pickPhotos(token, page);
      this.flowTasks.timeout((): void => this.poll(token, page), value.loading || value.busy ? 250 : 500);
    }).catch((): void => {
      if (generation !== this.flowGeneration || !this.ports.foreground() || !this.isCurrent(token, page)) return;
      const flow: PinmonyPublishFlow = this.store.publishFlow!;
      flow.uncertain = flow.busy; flow.busy = false; flow.loading = false;
      flow.error = flow.uncertain ? PinmonyI18n.message("pm_result_not_confirmed_close_and_refresh_to_check_before_submittin_5d6ac26e") : PinmonyI18n.message("pm_unable_to_load_publishing_status_go_back_and_retry_ade379b3");
      this.commit(flow);
    }).finally((): void => { if (generation === this.flowGeneration) this.polling = false; });
  }

  close(force: boolean = false): void {
    const flow: PinmonyPublishFlow | undefined = this.store.publishFlow;
    if (!flow && !this.store.publishPicking || !force && (flow?.busy || this.store.publishPicking)) return;
    const refreshBoard: boolean = !!flow && (flow.completed > 0 || !!flow.boardCreated || flow.uncertain || flow.busy);
    PinmonyRuntimeLog.info('PublishTrace: close force=' + force.toString());
    if(this.ports.nativeFlow?.())this.ports.nativeClose?.();
    this.pauseFlow(); this.store.publishFlowToken++; this.store.publishFlow = undefined; this.store.publishPicking = false;
    this.ports.suppressChildBack(); this.ports.syncMotion();
    if (flow && (flow.completed > 0 || flow.boardCreated || flow.uncertain || flow.busy)) {
      this.store.profileCache.clear();
      if (!force && !this.ports.hasBoardReturn()) this.ports.refreshProfile();
    }
    if (flow && !this.ports.nativeFlow?.()) this.ports.runScript('window.PinmonyPublishApi && window.PinmonyPublishApi.action(' + flow.token.toString() + ',"close","",false)').catch(() => {});
    this.ports.restoreBoard(refreshBoard);
  }

  action(action: string, value: string = '', secret: boolean = false): void {
    const flow: PinmonyPublishFlow | undefined = this.store.publishFlow;
    if (!flow || this.store.publishPicking || !this.ports.foreground() || !this.isCurrent(flow.token, flow.page)) return;
    if (action === 'close' || action === 'next' && flow.selectedIds.length === 0) { this.close(); return; }
    if (action === 'pickPhoto') { this.ports.pickPhotos(flow.token, flow.page); return; }
    if (flow.busy || flow.loading || flow.uncertain) return;
    if(this.ports.nativeFlow?.() && this.ports.nativeAction){this.ports.nativeAction(action,value,secret);return;}
    const token: number = flow.token, page: string = flow.page;
    const write: boolean = ['move', 'create'].includes(action);
    if (write) { flow.busy = true; this.commit(flow); }
    this.ports.runScript('window.PinmonyPublishApi.action(' + token.toString() + ',' + JSON.stringify(action) + ',' +
      JSON.stringify(value) + ',' + secret.toString() + ')').catch((): void => {
      if (!this.isCurrent(token, page)) return;
      const latest: PinmonyPublishFlow = this.store.publishFlow!;
      latest.busy = false; latest.uncertain = write;
      latest.error = write ? PinmonyI18n.message("pm_result_not_confirmed_close_and_refresh_to_check_before_submittin_5d6ac26e") : PinmonyI18n.message("pm_action_unavailable_go_back_and_retry_4ce37c85");
      this.commit(latest);
    });
  }

  private commit(flow: PinmonyPublishFlow): void {
    this.store.publishFlow = JSON.parse(JSON.stringify(flow)) as PinmonyPublishFlow;
  }
}
