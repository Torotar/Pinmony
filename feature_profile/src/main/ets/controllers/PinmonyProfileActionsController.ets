import { PinmonyI18n } from 'common_foundation';
import { PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyProfileStore } from '../stores/PinmonyProfileStore';
import { PinmonyProfilePanel } from '../models/PinmonyProfilePanel';
interface ProfileOperation { token: number; page: string; document: string; session: number; }
interface ProfileSaveResult { pending?: boolean; ok?: boolean; duplicate?: boolean; message?: string; username?: string; }
export interface PinmonyProfileActionsPorts {
  nativeEnabled?: () => boolean;
  nativeOpen?: (mode: string,section: string) => Promise<void>;
  nativeClose?: () => void;
  nativePause?: () => void;
  nativeFollow?: (id: string) => Promise<void>;
  nativeSave?: (input: string) => Promise<void>;
  nativeOrganize?: (action: string,value: string,secret: boolean) => Promise<void>;
  authenticated: () => boolean;
  foreground: () => boolean;
  visible: () => boolean;
  document: () => string;
  currentProfile: () => string;
  prepare: () => Promise<boolean>;
  runScript: (script: string) => Promise<string>;
  jsonText: (raw: string) => string;
  feedback: (message: string) => void;
  syncMotion: () => void;
  markInteracted: () => void;
  saved: (page: string, username: string) => void;
}
export class PinmonyProfileActionsController {
  private readonly store: PinmonyProfileStore;
  private readonly ports: PinmonyProfileActionsPorts;
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly waits: Set<(value: boolean) => void> = new Set<(value: boolean) => void>();
  private generation: number = 0;
  private intent: number = 0;
  private uncertainSession: number = 0;
  private panelDocument: string = '';
  private panelReading: boolean = false;
  private followReading: boolean = false;
  private saveReading: boolean = false;
  private following: ProfileOperation | undefined = undefined;
  private saving: ProfileOperation | undefined = undefined;
  private organizePending: boolean = false;
  private organizeSession: number = 0;
  private organizeTicket: number = 0;
  private tabTicket: number = 0;
  private organizePage: string = '';
  constructor(store: PinmonyProfileStore, ports: PinmonyProfileActionsPorts) { this.store = store; this.ports = ports; }
  pause(): void {
    if(this.ports.nativeEnabled?.())this.ports.nativePause?.();
    this.generation++; this.intent++; this.tasks.invalidate();
    this.waits.forEach((resolve: (value: boolean) => void): void => resolve(false)); this.waits.clear();
    this.panelReading = false; this.followReading = false; this.saveReading = false; if (!this.following) this.store.followingBusy = false; this.store.profileSwitching = false;
  }
  reset(): void {
    this.pause(); this.following = undefined; this.saving = undefined; this.organizePending = false; this.organizeTicket++;
    this.store.followingBusy = false; this.store.saving = false; this.store.followUncertain = false; this.store.saveUncertain = false;
    this.store.organizeUncertain = false;
  }
  resume(): void {
    if(this.ports.nativeEnabled?.())return;
    this.reconcile();
    if (this.store.panel?.loading && this.panelDocument === this.ports.document()) this.readPanel();
    if (this.following) this.readFollow(this.following);
    if (this.saving) this.readSave(this.saving);
  }
  scheduleOpen(mode: string, section: string, page: string): void {
    const generation: number = this.generation;
    this.tasks.timeout((): void => { if (generation === this.generation && this.available() && this.ports.currentProfile() === page) this.openPanel(mode, section); }, 500);
  }
  private reconcile(): void {
    if (this.uncertainSession !== this.store.profileSession) { this.store.followUncertain = false; this.store.saveUncertain = false; }
    const stale = (context: ProfileOperation): boolean => context.token !== this.store.panelToken || context.session !== this.store.profileSession ||
      context.page !== this.ports.currentProfile() || context.document !== this.ports.document();
    if (this.following && stale(this.following)) { this.following = undefined; this.store.followingBusy = false; this.store.followUncertain = false; }
    if (this.saving && stale(this.saving)) { this.saving = undefined; this.store.saving = false; this.store.saveUncertain = false; }
  }
  private available(): boolean { return this.ports.authenticated() && this.ports.foreground() && this.ports.visible(); }
  private operation(): ProfileOperation { return { token: this.store.panelToken, page: this.ports.currentProfile(), document: this.ports.document(), session: this.store.profileSession }; }
  private bound(context: ProfileOperation): boolean {
    return this.ports.authenticated() && context.token === this.store.panelToken && context.session === this.store.profileSession && context.page === this.ports.currentProfile() && context.document === this.ports.document();
  }
  private matches(context: ProfileOperation): boolean { return this.available() && this.bound(context); }
  private delay(generation: number): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void): void => {
      this.waits.add(resolve); this.tasks.timeout((): void => { this.waits.delete(resolve); resolve(generation === this.generation); }, 250);
    });
  }
  private validPanel(panel: PinmonyProfilePanel, expected: PinmonyProfilePanel): boolean {
    return !!panel && panel.token === expected.token && panel.page === expected.page && panel.mode === expected.mode && panel.section === expected.section &&
      typeof panel.loading === 'boolean' && typeof panel.error === 'string' && Array.isArray(panel.items) && panel.items.length <= 100;
  }
  async openPanel(mode: string, section: string = 'users'): Promise<void> {
    if(this.ports.nativeEnabled?.()){await this.ports.nativeOpen?.(mode,section);return;}
    this.reconcile();
    if (!this.available() || !['edit','following','followers'].includes(mode) || !['users','boards'].includes(section) || this.store.saving || this.store.followingBusy) return;
    const intent: number = ++this.intent, generation: number = this.generation;
    const prepared: boolean = await this.ports.prepare();
    if (generation !== this.generation || intent !== this.intent || !this.available()) return;
    if (!prepared) { this.ports.feedback(PinmonyI18n.message('资料会话尚未就绪，请重试')); return; }
    const page: string = this.ports.currentProfile(); if (!page) return;
    this.closePanel(); this.panelDocument = this.ports.document();
    const token: number = ++this.store.panelToken;
    this.store.panel = { page: page, mode: mode, section: section, token: token, loading: true, error: '', items: [], firstName: '', lastName: '', about: '', website: '', username: '', avatar: '' };
    this.ports.syncMotion(); const context: ProfileOperation = this.operation();
    const openedGeneration: number = this.generation;
    try {
      await this.ports.runScript('window.PinmonyProfilePanel && window.PinmonyProfilePanel.open(' + JSON.stringify(page) + ',' + JSON.stringify(mode) + ',' + JSON.stringify(section) + ',' + token.toString() + '); true');
      if (openedGeneration === this.generation && this.matches(context)) await this.readPanel();
    } catch (_) { if (openedGeneration === this.generation && this.matches(context)) this.panelError('读取失败'); }
  }
  private panelError(message: string): void {
    if (!this.store.panel) return;
    const panel: PinmonyProfilePanel = JSON.parse(JSON.stringify(this.store.panel)) as PinmonyProfilePanel;
    panel.loading = false; panel.error = message; this.store.panel = panel;
  }
  private async readPanel(): Promise<void> {
    const expected: PinmonyProfilePanel | undefined = this.store.panel, context: ProfileOperation = this.operation(), generation: number = this.generation;
    if (!expected || this.panelReading || !this.matches(context) || this.panelDocument !== context.document) return;
    this.panelReading = true;
    try {
      for (let attempt: number = 0; attempt < 65; attempt++) {
        if (generation !== this.generation || !this.matches(context)) return;
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyProfilePanel && window.PinmonyProfilePanel.read())');
        if (generation !== this.generation || !this.matches(context)) return;
        const panel: PinmonyProfilePanel = JSON.parse(this.ports.jsonText(raw)) as PinmonyProfilePanel;
        if (!this.validPanel(panel, expected)) throw new Error('invalid');
        if (!panel.loading) { this.store.panel = panel; return; }
        if (!await this.delay(generation)) return;
      }
      throw new Error('timeout');
    } catch (_) { if (generation === this.generation && this.matches(context)) this.panelError(PinmonyI18n.message('读取失败，请重新读取')); }
    finally { if (generation === this.generation) this.panelReading = false; }
  }
  closePanel(): void {
    if(this.ports.nativeEnabled?.()){this.ports.nativeClose?.();return;}
    this.pause(); this.following = undefined; this.saving = undefined; this.store.followingBusy = false; this.store.saving = false; this.store.followUncertain = false; this.store.saveUncertain = false; this.store.panelToken++; this.store.panel = undefined; this.panelDocument = ''; this.ports.syncMotion();
    this.ports.runScript('window.PinmonyProfilePanel && window.PinmonyProfilePanel.close()').catch(() => {});
  }
  async follow(id: string = ''): Promise<void> {
    if(this.ports.nativeEnabled?.()){await this.ports.nativeFollow?.(id);return;}
    this.reconcile();
    if (!this.available() || this.store.followingBusy || this.store.followUncertain) return;
    const generation: number = this.generation;
    this.store.followingBusy = true;
    if (!id && (!await this.ports.prepare() || generation !== this.generation || !this.available())) { if (generation === this.generation) this.store.followingBusy = false; return; }
    const context: ProfileOperation = this.operation();
    if (!context.page || !this.store.profileActionsReady) { this.store.followingBusy = false; return; }
    this.following = context;
    try {
      const started: string = await this.ports.runScript('window.PinmonyProfilePanel && window.PinmonyProfilePanel.follow(' + JSON.stringify(context.page) + ',' + JSON.stringify(id) + ')');
      if (generation !== this.generation || !this.matches(context)) return;
      if (started !== 'true' && started !== '"true"') { this.following = undefined; this.store.followingBusy = false; return; }
      await this.readFollow(context);
    } catch (_) { if (generation === this.generation && this.matches(context)) this.followFailed(); }
  }
  private followFailed(): void { this.uncertainSession = this.store.profileSession; this.following = undefined; this.store.followingBusy = false; this.store.followUncertain = true; this.ports.feedback(PinmonyI18n.message('关注操作结果未确认，请刷新核对')); }
  private async readFollow(context: ProfileOperation): Promise<void> {
    const generation: number = this.generation;
    if (this.followReading || !this.matches(context)) return;
    this.followReading = true;
    try {
      for (let attempt: number = 0; attempt < 65; attempt++) {
        if (generation !== this.generation || !this.matches(context)) return;
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyProfilePanel.readFollow())');
        if (generation !== this.generation || !this.matches(context)) return;
        const status: string = this.ports.jsonText(raw);
        if (status === 'pending') { if (!await this.delay(generation)) return; continue; }
        if (status !== 'ok') { this.followFailed(); return; }
        if (this.store.panel) {
          const expected: PinmonyProfilePanel = this.store.panel;
          const value: string = await this.ports.runScript('JSON.stringify(window.PinmonyProfilePanel.read())');
          if (generation !== this.generation || !this.matches(context)) return;
          const panel: PinmonyProfilePanel = JSON.parse(this.ports.jsonText(value)) as PinmonyProfilePanel;
          if (!this.validPanel(panel, expected)) throw new Error('invalid'); this.store.panel = panel;
        }
        this.following = undefined; this.store.followingBusy = false;
        await this.ports.runScript('window.PinmonyProfileSync && window.PinmonyProfileSync()'); return;
      }
      this.followFailed();
    } catch (_) { if (generation === this.generation && this.matches(context)) this.followFailed(); }
    finally { if (generation === this.generation) this.followReading = false; }
  }
  async save(input: string): Promise<void> {
    if(this.ports.nativeEnabled?.()){await this.ports.nativeSave?.(input);return;}
    this.reconcile();
    const panel: PinmonyProfilePanel | undefined = this.store.panel;
    if (!this.available() || !panel || panel.loading || panel.mode !== 'edit' || this.store.saving || this.store.saveUncertain || this.panelDocument !== this.ports.document()) return;
    const context: ProfileOperation = this.operation(), generation: number = this.generation;
    this.saving = context; this.store.saving = true;
    try {
      await this.ports.runScript('if (window.PinmonyProfilePanel) window.PinmonyProfilePanel.update(' + JSON.stringify(panel.page) + ',' + panel.token.toString() + ',' + input + '); true');
      if (generation === this.generation && this.matches(context)) await this.readSave(context);
    } catch (_) { if (generation === this.generation && this.matches(context)) this.saveFailed(PinmonyI18n.message('保存结果未确认，请重新读取资料核对')); }
  }
  private saveFailed(message: string): void { this.uncertainSession = this.store.profileSession; this.saving = undefined; this.store.saving = false; this.store.saveUncertain = true; this.panelError(message); this.ports.feedback(message); }
  private async readSave(context: ProfileOperation): Promise<void> {
    const generation: number = this.generation;
    if (this.saveReading || !this.matches(context)) return;
    this.saveReading = true;
    try {
      for (let attempt: number = 0; attempt < 80; attempt++) {
        if (generation !== this.generation || !this.matches(context)) return;
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyProfilePanel && window.PinmonyProfilePanel.readSave())');
        if (generation !== this.generation || !this.matches(context)) return;
        const result: ProfileSaveResult | null = JSON.parse(this.ports.jsonText(raw)) as ProfileSaveResult | null;
        if (result?.pending === true) { if (!await this.delay(generation)) return; continue; }
        if (result?.ok === true) {
          const username: string = typeof result.username === 'string' && /^\w+$/.test(result.username) ? result.username : '';
          this.closePanel(); this.ports.feedback('修改完成'); this.ports.saved(context.page, username); return;
        }
        if (result?.duplicate === true) { this.saving = undefined; this.store.saving = false; this.ports.feedback(PinmonyI18n.message('用户名已被使用')); return; }
        this.saveFailed(typeof result?.message === 'string' ? result.message.slice(0,200) : PinmonyI18n.message('保存结果未确认，请重新读取资料核对')); return;
      }
      this.saveFailed(PinmonyI18n.message('保存结果未确认，请重新读取资料核对'));
    } catch (_) { if (generation === this.generation && this.matches(context)) this.saveFailed(PinmonyI18n.message('保存结果未确认，请重新读取资料核对')); }
    finally { if (generation === this.generation) this.saveReading = false; }
  }
  async changeTab(section: string): Promise<void> {
    if (!this.available() || !['saved','created'].includes(section)) return;
    const requestedProfile: string = this.store.profile?.profileUrl || this.ports.currentProfile();
    const ticket: number = ++this.tabTicket;
    const ready: boolean = await this.ports.prepare();
    if (ticket !== this.tabTicket || !this.available() ||
        requestedProfile && requestedProfile !== this.ports.currentProfile()) return;
    const generation: number = this.generation;
    const deadline: number = Date.now() + 8000;
    while (ready && generation === this.generation && ticket === this.tabTicket && this.available() &&
        !this.store.profileActionsReady && Date.now() < deadline) {
      if (!await this.delay(generation)) return;
    }
    if (ticket !== this.tabTicket) return;
    if (!ready || generation !== this.generation || !this.available() || !this.store.profileActionsReady) {
      if (generation === this.generation && this.available()) this.ports.feedback(PinmonyI18n.message('资料页签尚未就绪，请重试'));
      return;
    }
    const profile = this.store.profile, context: ProfileOperation = this.operation();
    if (!profile || section === profile.section) return;
    this.ports.markInteracted(); this.store.profileSwitching = true;
    this.tasks.timeout((): void => {
      if (generation !== this.generation || ticket !== this.tabTicket || !this.store.profileSwitching) return;
      this.store.profileSwitching = false;
      if (this.available() && this.store.profile?.section !== section) this.ports.feedback(PinmonyI18n.message('资料接口尚未切换页签，请重试'));
    }, 20000);
    try {
      const result: string = await this.ports.runScript('window.PinmonyProfileTab && window.PinmonyProfileTab(' + profile.session.toString() + ',' + JSON.stringify(profile.profileUrl) + ',' + JSON.stringify(section) + ')');
      if (generation !== this.generation || !this.matches(context)) return;
      if (result === 'true' || result === '"true"') {
        return;
      }
    } catch (_) { if (generation !== this.generation || !this.matches(context)) return; }
    this.store.profileSwitching = false; this.ports.feedback(PinmonyI18n.message('无法切换个人资料页签，请重试'));
  }
  async organize(action: string, value: string = '', secret: boolean = false): Promise<void> {
    if(this.ports.nativeEnabled?.()){await this.ports.nativeOrganize?.(action,value,secret);return;}
    if (!this.available() || this.organizePending) return;
    const generation: number = this.generation;
    if (!await this.ports.prepare() || generation !== this.generation || !this.available() || !this.store.profileActionsReady) return;
    const profile = this.store.profile, context: ProfileOperation = this.operation();
    if (this.organizePending || !profile || profile.section !== 'saved' || context.page !== profile.profileUrl || profile.organize?.busy) return;
    if (this.organizeSession !== profile.session || this.organizePage !== profile.profileUrl) this.store.organizeUncertain = false;
    this.organizeSession = profile.session; this.organizePage = profile.profileUrl;
    const write: boolean = action === 'move' || action === 'create';
    if (write && (this.store.organizeUncertain || profile.organize?.uncertain)) return;
    this.organizePending = true; const ticket: number = ++this.organizeTicket;
    try {
      const result: string = await this.ports.runScript('window.PinmonyProfileOrganizeAction && window.PinmonyProfileOrganizeAction(' + profile.session.toString() + ',' + JSON.stringify(profile.profileUrl) + ',' + JSON.stringify(action) + ',' + JSON.stringify(value) + ',' + secret.toString() + ')');
      if (generation === this.generation && this.matches(context) && result !== 'true' && result !== '"true"') this.ports.feedback(PinmonyI18n.message('当前操作不可用，请刷新后重试'));
    } catch (_) { if (this.bound(context)) { if (write) this.store.organizeUncertain = true; if (generation === this.generation) this.ports.feedback(write ? '整理结果未确认，请刷新核对' : PinmonyI18n.message('无法执行整理操作，请刷新后重试')); } }
    finally { if (ticket === this.organizeTicket) this.organizePending = false; }
  }
}
