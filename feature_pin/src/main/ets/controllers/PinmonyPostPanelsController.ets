import { PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { PinmonyCommentResult, PinmonySaveResult } from '../models/PinmonyComments';
import { PinmonyEditPinResult } from '../models/PinmonyEditPin';

interface PinmonyPanelCommentAction { action: string; }

export interface PinmonyPostPanelsPorts {
  authenticated: () => boolean;
  foreground: () => boolean;
  document: () => string;
  sheet: () => string;
  show: (kind: string) => void;
  currentPin: () => string;
  pinIdentity: (pin: string) => string;
  moreCurrent: (pin: string) => boolean;
  runScript: (script: string) => Promise<string>;
  jsonText: (raw: string) => string;
  feedback: (message: string) => void;
  saveDismissed: () => void;
  editCompleted: (pin: string, deleted: boolean) => Promise<void>;
  prepareComment: (encoded: string, pin: string, current: () => boolean) => Promise<string>;
}

export class PinmonyPostPanelsController {
  private readonly store: PinmonyPinStore;
  private readonly ports: PinmonyPostPanelsPorts;
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private reading: boolean = false;
  private pendingWrite: boolean = false;
  private uncertain: boolean = false;
  private mode: string = '';
  private pin: string = '';
  private page: string = '';
  constructor(store: PinmonyPinStore, ports: PinmonyPostPanelsPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.generation++; this.tasks.invalidate(); this.reading = false; }
  resume(): void { this.poll(); }
  private token(): number { return this.mode === 'comments' ? this.store.commentToken : this.mode === 'save' ? this.store.saveToken : this.store.editToken; }
  private context(token: number): boolean {
    return !!this.mode && token === this.token() && this.ports.authenticated() && this.ports.sheet() === this.mode &&
      this.page === this.ports.document() && (this.mode === 'comments' ?
      this.ports.pinIdentity(this.pin) === this.ports.pinIdentity(this.ports.currentPin()) : this.ports.moreCurrent(this.pin));
  }
  private current(token: number, generation: number): boolean { return generation === this.generation && this.ports.foreground() && this.context(token); }
  private begin(mode: string, pin: string): void {
    this.pause(); this.mode = mode; this.pin = pin; this.page = this.ports.document(); this.pendingWrite = false; this.uncertain = false;
    if (mode === 'comments') this.store.commentToken++;
    else if (mode === 'save') this.store.saveToken++;
    else this.store.editToken++;
    this.ports.show(mode);
  }
  private async start(method: string): Promise<void> {
    const token: number = this.token(), generation: number = this.generation;
    try {
      await this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.' + method + '(' + JSON.stringify(this.pin) + ')');
      if (this.current(token, generation)) this.poll();
    } catch (_) { if (this.current(token, generation)) this.fail('接口不可用，请重新读取'); }
  }
  async openComments(): Promise<void> {
    const pin: string = this.store.detail?.pinUrl || '';
    if (!pin || !this.ports.authenticated() || !this.ports.foreground() || this.pendingWrite ||
        this.ports.pinIdentity(pin) !== this.ports.pinIdentity(this.ports.currentPin())) return;
    this.begin('comments', pin); this.store.commentResult = { pin: pin, loading: true, error: '', items: [] };
    await this.start('commentsStart');
  }
  async openBoards(requestedPin: string = ''): Promise<void> {
    const pin: string = requestedPin || (this.ports.sheet() === 'save' ? this.store.saveResult.pin : this.store.detail?.pinUrl || '');
    if (!pin || !this.ports.authenticated() || !this.ports.foreground() || this.pendingWrite || !this.ports.moreCurrent(pin) || this.store.saveResult.busy) return;
    this.store.saveCreating = false;
    this.store.saveResult = { pin: pin, loading: true, busy: false, error: '', feedback: '', items: [], shortlist: [], savedId: '', savedBoard: '' };
    this.begin('save', pin);
    await this.start('boardsStart');
  }
  async openEdit(pin: string): Promise<void> {
    if (!this.ports.authenticated() || !this.ports.foreground() || this.pendingWrite || !this.ports.moreCurrent(pin) || this.store.editResult.busy || this.store.editResult.picker.busy) return;
    this.begin('edit', pin); this.store.saveCreating = false;
    this.store.editResult = { pin: pin, loading: true, busy: false, error: '', phase: 'edit', imageUrl: '', title: '', description: '', editableContent: false, ai: false,
      uncertain: false, done: '', board: { id: '', name: '', imageUrl: '', enabled: false, secret: false },
      picker: { pin: pin, loading: false, busy: false, error: '', feedback: '', items: [], shortlist: [], savedId: '', savedBoard: '' } };
    await this.start('editStart');
  }
  private fail(message: string): void {
    if (this.mode === 'comments') { this.store.commentResult.loading = false; this.store.commentResult.busy = false; this.store.commentResult.error = message; if (this.uncertain) this.store.commentResult.uncertain = true; }
    else if (this.mode === 'save') { this.store.saveResult.loading = false; this.store.saveResult.busy = false; this.store.saveResult.error = message; }
    else { this.store.editResult.loading = false; this.store.editResult.busy = false; this.store.editResult.picker.busy = false; this.store.editResult.error = message; if (this.uncertain) this.store.editResult.uncertain = true; }
  }
  private boardsValid(result: PinmonySaveResult): boolean {
    return !!result && result.pin === this.pin && typeof result.loading === 'boolean' && typeof result.busy === 'boolean' && typeof result.error === 'string' &&
      Array.isArray(result.items) && Array.isArray(result.shortlist) && result.items.length <= 2000 && result.shortlist.length <= 2000 &&
      result.items.concat(result.shortlist).every((board): boolean => !!board && typeof board.id === 'string' && typeof board.name === 'string' &&
        typeof board.enabled === 'boolean' && typeof board.imageUrl === 'string');
  }
  private poll(): void {
    const token: number = this.token(), generation: number = this.generation;
    if (this.reading || !this.current(token, generation)) return;
    this.tasks.invalidate(); this.reading = true;
    const method: string = this.mode === 'comments' ? 'commentsRead' : this.mode === 'save' ? 'boardsRead' : 'editRead';
    this.ports.runScript('JSON.stringify(window.PinmonyPostApi && window.PinmonyPostApi.' + method + '(' + JSON.stringify(this.pin) + '))')
      .then(async (raw: string): Promise<void> => {
        if (!this.current(token, generation)) return;
        let busy: boolean = false;
        if (this.mode === 'comments') {
          const result: PinmonyCommentResult | null = JSON.parse(this.ports.jsonText(raw)) as PinmonyCommentResult | null;
          if (!result || result.pin !== this.pin || typeof result.loading !== 'boolean' || typeof result.error !== 'string' || !Array.isArray(result.items) || result.items.length > 2000) throw new Error('Unavailable');
          if (this.uncertain) result.uncertain = true;
          this.store.commentResult = result; busy = result.loading || result.busy === true;
        } else if (this.mode === 'save') {
          const result: PinmonySaveResult | null = JSON.parse(this.ports.jsonText(raw)) as PinmonySaveResult | null;
          if (!result || !this.boardsValid(result)) throw new Error('Unavailable');
          this.store.saveResult = result; busy = result.loading || result.busy;
        } else {
          const result: PinmonyEditPinResult | null = JSON.parse(this.ports.jsonText(raw)) as PinmonyEditPinResult | null;
          if (!result || result.pin !== this.pin || !result.board || !result.picker || !this.boardsValid(result.picker) ||
              typeof result.loading !== 'boolean' || typeof result.busy !== 'boolean' || typeof result.uncertain !== 'boolean' || typeof result.error !== 'string') throw new Error('Unavailable');
          if (this.uncertain) result.uncertain = true;
          this.store.editResult = result; busy = result.loading || result.busy || result.picker.loading || result.picker.busy;
          if ((result.done === 'saved' || result.done === 'deleted') && !this.pendingWrite) {
            const pin: string = this.pin, deleted: boolean = result.done === 'deleted';
            this.dismiss('edit', true); await this.ports.editCompleted(pin, deleted); return;
          }
        }
        this.tasks.timeout((): void => this.poll(), busy ? 250 : 500);
      }).catch((): void => {
        if (this.current(token, generation)) {
          const busy: boolean = this.mode === 'comments' ? this.store.commentResult.busy === true :
            this.mode === 'save' ? this.store.saveResult.busy : this.store.editResult.busy || this.store.editResult.picker.busy;
          if (this.pendingWrite || busy) this.uncertain = true;
          this.fail('状态读取失败，请重新读取核对');
        }
      }).finally((): void => { if (generation === this.generation) this.reading = false; });
  }
  private blocked(): boolean {
    if (this.pendingWrite || this.uncertain) return true;
    if (this.mode === 'comments') return this.store.commentResult.busy === true || this.store.commentResult.uncertain === true;
    if (this.mode === 'save') return this.store.saveResult.busy;
    return this.store.editResult.busy || this.store.editResult.picker.busy || this.store.editResult.uncertain;
  }
  private async dispatch(method: string, args: string, write: boolean): Promise<void> {
    const token: number = this.token(), pin: string = this.pin, mode: string = this.mode;
    if (!this.current(token, this.generation) || this.blocked()) return;
    this.pause(); if (write) {
      this.pendingWrite = true;
      if (mode === 'comments') this.store.commentResult.busy = true;
      else if (mode === 'save') this.store.saveResult.busy = true;
      else if (method === 'boardsCreate') this.store.editResult.picker.busy = true;
      else this.store.editResult.busy = true;
    }
    try { await this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.' + method + '(' + JSON.stringify(pin) + args + ')'); }
    catch (_) { if (this.mode === mode && this.context(token)) { if (write) this.uncertain = true; this.fail(write ? '操作结果未确认，请关闭后重新读取核对' : '读取操作失败，请重试'); } }
    finally { if (this.mode === mode && this.context(token)) { this.pendingWrite = false; this.poll(); } }
  }
  commentAction(method: string, id: string = ''): void {
    if (this.mode !== 'comments' || !['commentsMore', 'commentReplies', 'commentLike'].includes(method)) return;
    this.dispatch(method, id ? ',' + JSON.stringify(id) : '', method === 'commentLike');
  }
  saveAction(method: string, args: string = ''): void {
    if (this.mode !== 'save' || !['boardsSave', 'boardsCreate', 'boardsRemove'].includes(method)) return;
    this.dispatch(method, args, true);
  }
  editAction(method: string, args: string): void {
    if (this.mode !== 'edit' || !['editPhase', 'editSelect', 'editText', 'editAi', 'editCommit', 'boardsCreate', 'boardsMore', 'boardsSuggest'].includes(method)) return;
    if (method === 'editPhase' || method === 'editSelect') this.store.saveCreating = false;
    this.dispatch(method, args, method === 'editCommit' || method === 'boardsCreate');
  }
  async writeComment(encoded: string): Promise<void> {
    const token: number = this.token(), pin: string = this.pin;
    if (this.mode !== 'comments' || !this.current(token, this.generation) || this.blocked()) return;
    this.pause(); this.pendingWrite = true; this.store.commentResult.busy = true;
    try {
      const prepared: string = await this.ports.prepareComment(encoded, pin, (): boolean => this.mode === 'comments' && this.pin === pin && this.context(token));
      if (!prepared || this.mode !== 'comments' || this.pin !== pin || !this.context(token)) {
        if (this.mode === 'comments' && this.pin === pin && this.context(token)) this.store.commentResult.busy = false;
        return;
      }
      if (!this.ports.foreground()) {
        const value: PinmonyPanelCommentAction = JSON.parse(prepared) as PinmonyPanelCommentAction;
        if (value.action === 'photo') await this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.commentPhotoFail(' + JSON.stringify(pin) + ')').catch(() => {});
        this.store.commentResult.busy = false;
        return;
      }
      await this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.commentWrite(' + JSON.stringify(pin) + ',' + JSON.stringify(prepared) + ')');
    } catch (_) { if (this.mode === 'comments' && this.pin === pin && this.context(token)) { this.uncertain = true; this.fail('评论提交结果未确认，请重新读取核对'); } }
    finally { if (this.mode === 'comments' && this.pin === pin && this.context(token)) { this.pendingWrite = false; this.poll(); } }
  }
  dismiss(kind: string, force: boolean = false): void {
    if (this.mode !== kind) return;
    if (kind === 'edit' && !force && (this.pendingWrite || this.store.editResult.busy || this.store.editResult.picker.busy)) return;
    this.pause();
    if (kind === 'comments') this.store.commentToken++;
    else if (kind === 'save') { this.store.saveToken++; this.store.saveCreating = false; this.store.saveResult.busy = false; }
    else { this.store.editToken++; this.store.editResult.busy = false; this.store.editResult.picker.busy = false; }
    this.mode = ''; this.pendingWrite = false; this.uncertain = false; this.ports.show('');
    const close: string = kind === 'comments' ? 'commentsClose' : kind === 'save' ? 'boardsClose' : 'editClose';
    this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.' + close + '()').catch(() => {});
    if (kind === 'save') this.ports.saveDismissed();
  }
}
