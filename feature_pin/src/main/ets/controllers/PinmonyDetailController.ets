import { PinmonyDetailAction } from '../models/PinmonyDetail';
import { PinmonyDetailPorts } from '../models/PinmonyDetailPorts';
import { PinmonyTaskRegistry } from 'common_foundation';

// Owns detail action readiness and dispatch; product navigation remains injected.
export class PinmonyDetailController {
  private readonly ports: PinmonyDetailPorts;
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  constructor(ports: PinmonyDetailPorts) { this.ports = ports; }
  pause(): void { this.generation++; this.tasks.invalidate(); }

  async ensureActionContext(): Promise<boolean> {
    const store = this.ports.store;
    if (this.ports.isOffline('detail preparation')) return false;
    const pin = store.detail?.pinUrl || '';
    if (!this.ports.pinIdentity(pin) || !this.ports.isAuthenticated() || store.detailPreparing) return false;
    if (!store.detailPresentationOnly) return store.detailActionsReady;
    this.ports.beginDetailOpening(pin);
    store.detailPreparing = true;
    const token = store.detailOpeningToken;
    const generation: number = this.generation;
    this.ports.markJourney('action.context.requested');
    try {
      this.ports.loadDetailUrl(pin);
      for (let attempt = 0; attempt < 80; attempt++) {
        if (generation !== this.generation || token !== store.detailOpeningToken || !this.ports.isAuthenticated() ||
            store.detailPin !== pin || !this.ports.isForeground()) return false;
        if (store.detailActionsReady && store.detail?.imageStageReady &&
            !store.detail.actionsRetained && this.ports.currentPinUrl() === pin) {
          this.ports.markJourney('action.context.confirmed');
          return true;
        }
        if (store.detailApiError) return false;
        if (!await this.tasks.wait(150)) return false;
      }
      store.detailApiError = '当前帖子状态尚未确认，请重试';
      return false;
    } catch (_) {
      if (generation === this.generation && token === store.detailOpeningToken && this.ports.isAuthenticated() &&
          this.ports.isForeground()) store.detailApiError = '当前帖子状态准备失败，请重试';
      return false;
    } finally {
      if (token === store.detailOpeningToken) store.detailPreparing = false;
    }
  }

  async performAction(id: string, kind: string): Promise<void> {
    const store = this.ports.store;
    this.ports.traceAction('detail.action.' + kind, id);
    if (this.ports.isOffline('detail.' + kind) || !this.ports.isAuthenticated()) return;
    if(this.ports.nativePostAction && ['like','save','share','comment','more'].includes(kind) && await this.ports.nativePostAction(kind))return;
    if (store.detailPresentationOnly) {
      if (!await this.ensureActionContext()) return;
      const fresh: PinmonyDetailAction | undefined = store.detail?.actions.find(
        (item: PinmonyDetailAction): boolean => item.kind === kind);
      if (!fresh?.enabled) return;
      id = fresh.id;
    }
    const detail = store.detail;
    if (!detail || detail.kind === 'cached' || !store.detailActionsReady || !id ||
        this.ports.pinIdentity(detail.pinUrl) !== this.ports.pinIdentity(this.ports.currentPinUrl())) return;
    if (this.ports.postApiEnabled() && kind === 'comment') { this.ports.openComments(); return; }
    if (kind === 'save') {
      if (!this.ports.postApiEnabled() || !this.ports.postExtensionsEnabled()) return;
      const save = detail.actions.find((item: PinmonyDetailAction): boolean => item.id === id && item.kind === 'save');
      if (!save?.enabled || store.viewerSaveBusy) return;
      if (save.selected) await this.ports.cancelSave(detail.pinUrl);
      else await this.ports.openBoards();
      return;
    }
    if (this.ports.postApiEnabled() && kind === 'share') {
      try {
        const result = await this.ports.openShare(detail.pinUrl);
        if (result !== 'true' && result !== '"true"') this.ports.showMessage('分享接口暂不可用，请重试');
      } catch (_) { this.ports.showMessage('分享接口暂不可用，请重试'); }
      return;
    }
    if (this.ports.postApiEnabled() && kind === 'more') { await this.ports.openMore(); return; }
    if (this.ports.postApiEnabled() && kind === 'source') {
      const source = this.ports.externalSourceUrl(detail.sourceUrl || '');
      if (!source) { this.ports.showMessage('当前来源链接不可用'); return; }
      try { await this.ports.openExternalLink(source); }
      catch (_) { this.ports.showMessage('无法打开来源链接，请重试'); }
      return;
    }
    if (!this.ports.postApiEnabled() || kind !== 'like') return;
    try {
      const result = await this.ports.runScript('window.PinmonyDetailAction && window.PinmonyDetailAction(' +
        detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' + JSON.stringify(id) + ')');
      if (result !== 'true' && result !== '"true"') this.ports.showMessage('当前操作暂不可用，请重试');
    } catch (_) { this.ports.showMessage('当前操作暂不可用，请重试'); }
  }
}
