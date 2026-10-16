import { PinmonyTaskRegistry, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { PinmonyDetailSnapshot, PinmonyMediaReadResult } from '../models/PinmonyDetail';
import { PinmonyImageCrop, PinmonyVisualResult, emptyVisualResult } from '../models/PinmonyVisualSearch';
import { PinmonySaveOperationResult } from '../models/PinmonyComments';
import { PinmonyEditPinResult } from '../models/PinmonyEditPin';
import { PIN_VISUAL_SEARCH_API_ENABLED } from '../services/PinmonyVisualSearchApiScript';
interface PinmonySaveIdentity { id: string; }

export interface PinmonyDetailOperationsControllerPorts {
  nativeOpenLayer?: (layer: string) => Promise<void>;
  nativeSearch?: (crop: PinmonyImageCrop, append: boolean, first: boolean) => Promise<void>;
  nativeRetryMedia?: () => Promise<void>;
  nativePause?: () => void;
  nativeCancelVisual?: () => void;
  authEpoch: () => number;
  authStatus: () => string;
  businessSuspended: () => boolean;
  runScript: (script: string) => Promise<string>;
  visualStart: () => string;
  document: () => string;
  webJsonText: (value: string) => string;
  mark: (event: string) => void;
  pinIdentity: (value: string) => string;
  currentPinUrl: () => string;
  showMessage: (value: string) => void;
  ensureDetailActionContext: () => Promise<boolean>;
  rejectOfflineAction: (value: string) => boolean;
}

export class PinmonyDetailOperationsController {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private readonly visualTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly store: PinmonyPinStore;
  private readonly ports: PinmonyDetailOperationsControllerPorts;
  constructor(store: PinmonyPinStore, ports: PinmonyDetailOperationsControllerPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.ports.nativePause?.(); this.generation++; this.tasks.invalidate(); this.cancelVisual(); }

  async openImageLayer(layer: string): Promise<void> {
    if(this.ports.nativeOpenLayer){await this.ports.nativeOpenLayer(layer);return;}
    if ((layer !== 'search' && layer !== 'zoom') || layer === 'search' && !PIN_VISUAL_SEARCH_API_ENABLED ||
        this.ports.authStatus() !== 'authenticated' || this.ports.businessSuspended() || this.store.detailPreparing) return;
    const pin: string = this.store.detail?.pinUrl || '';
    if (!this.ports.pinIdentity(pin)) return;
    const generation: number = this.generation;
    const epoch: number = this.ports.authEpoch();
    // Preparing a retained detail closes the old image layer synchronously.
    const preparation: Promise<boolean> = this.ports.ensureDetailActionContext();
    const visualToken: number = this.store.visualToken;
    if (!await preparation || generation !== this.generation || epoch !== this.ports.authEpoch() ||
        visualToken !== this.store.visualToken || this.ports.businessSuspended() ||
        this.ports.authStatus() !== 'authenticated' || this.store.detail?.pinUrl !== pin ||
        this.store.detailPin !== pin || !this.store.detailActionsReady) return;
    this.store.imageLayer = layer;
    this.store.visualResult = emptyVisualResult();
  }

  cancelVisual(): void {
    this.ports.nativeCancelVisual?.();
    this.visualTasks.invalidate(); this.store.visualToken++;
    if (this.store.visualResult.loading) {
      this.store.visualResult.loading = false;
      this.store.visualResult.error = '图片搜索已暂停，请重试';
    }
  }

  async searchImage(crop: PinmonyImageCrop, append: boolean, first: boolean): Promise<void> {
    if(this.ports.nativeSearch){await this.ports.nativeSearch(crop,append,first);return;}
    const detail: PinmonyDetailSnapshot | undefined = this.store.detail;
    if (this.ports.authStatus() !== 'authenticated' || this.ports.businessSuspended() || !PIN_VISUAL_SEARCH_API_ENABLED || !detail || this.store.imageLayer !== 'search' || !this.store.detailActionsReady ||
        append && (this.store.visualResult.loading || this.store.visualResult.ended)) return;
    const pin: string = detail.pinUrl;
    const epoch: number = this.ports.authEpoch();
    this.visualTasks.invalidate();
    const generation: number = this.generation;
    const page: string = this.ports.document();
    const token: number = ++this.store.visualToken;
    const current = (): boolean => generation === this.generation && !this.ports.businessSuspended() && page === this.ports.document() && token === this.store.visualToken && this.ports.authEpoch() === epoch &&
      this.ports.authStatus() === 'authenticated' && this.store.imageLayer === 'search' && this.store.detail?.pinUrl === pin;
    this.store.visualResult = { pin: pin, loading: true, error: '', ended: false,
      items: append ? this.store.visualResult.items : [] };
    try {
      const started: string = await this.ports.runScript(this.ports.visualStart() +
        'window.PinmonyVisualSearchApi.start(' + JSON.stringify(pin) + ',' + JSON.stringify(crop) + ',' + append + ',' + first + ')');
      if (!current()) return;
      if (started !== 'true' && started !== '"true"') throw new Error('Unavailable');
      const until: number = Date.now() + 18000;
      const poll = async (): Promise<void> => {
        if (!current()) return;
        try {
          const value: string = await this.ports.runScript('JSON.stringify(window.PinmonyVisualSearchApi.read(' + JSON.stringify(pin) + '))');
          if (!current()) return;
          const result: PinmonyVisualResult | null = JSON.parse(this.ports.webJsonText(value)) as PinmonyVisualResult | null;
          if (!result || result.pin !== pin || !Array.isArray(result.items) || result.items.length > 400) throw new Error('Invalid');
          this.store.visualResult = result;
          if (!result.loading) return;
          if (Date.now() > until) throw new Error('Timeout');
          this.visualTasks.timeout((): void => { poll(); }, 180);
        } catch (_) {
          if (current()) this.store.visualResult = { pin: pin, loading: false, error: '图片搜索未完成，请重试',
            ended: false, items: this.store.visualResult.items };
        }
      };
      poll();
    } catch (_) {
      if (current()) this.store.visualResult = { pin: pin, loading: false, error: '图片搜索暂不可用，请重试', ended: false, items: [] };
    }
  }


  async cancelDetailSave(pin: string, viewer: boolean = false): Promise<void> {
    if (this.ports.businessSuspended() || this.ports.authStatus() !== 'authenticated' || this.store.viewerSaveBusy || !this.store.detailActionsReady || this.store.detail?.pinUrl !== pin) return;
    const generation: number = this.generation;
    const page: string = this.ports.document();
    const epoch: number = this.ports.authEpoch();
    const session: number = this.store.detailSession;
    const operation: number = this.store.saveCancelToken = (this.store.saveCancelToken % 2147483647) + 1;
    const current = (): boolean => generation === this.generation && page === this.ports.document() && this.ports.authEpoch() === epoch && this.ports.authStatus() === 'authenticated' &&
      !this.ports.businessSuspended() && this.store.saveCancelToken === operation &&
      (!viewer || this.store.imageLayer === 'zoom') && this.store.detailSession === session &&
      this.store.detailActionsReady && this.store.detail?.pinUrl === pin && this.ports.currentPinUrl() === pin;
    this.store.viewerSaveBusy = true;
    this.ports.mark('save.cancel.started');
    let deleteSent: boolean = false;
    try {
      const value: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi.savedRead(' + JSON.stringify(pin) + '))');
      if (!current()) return;
      let saved: PinmonySaveIdentity | null = JSON.parse(this.ports.webJsonText(value)) as PinmonySaveIdentity | null;
      const copyId: string = this.store.confirmedSaves.copyId(this.ports.pinIdentity(pin));
      if (!saved?.id && copyId) {
        this.ports.mark('save.cancel.verify.started');
        const started: string = await this.ports.runScript('window.PinmonyPostApi.savedRestoreStart(' +
          JSON.stringify(pin) + ',' + JSON.stringify(copyId) + ',' + operation.toString() + ')');
        if (!current()) return;
        if (started !== 'true' && started !== '"true"') throw new Error('Unconfirmed');
        let verified: boolean = false;
        const until: number = Date.now() + 15000;
        while (current() && Date.now() < until) {
          const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi.savedRestoreRead(' +
            JSON.stringify(pin) + ',' + operation.toString() + '))');
          if (!current()) return;
          const result: PinmonySaveOperationResult | null = JSON.parse(this.ports.webJsonText(raw)) as PinmonySaveOperationResult | null;
          if (!result || result.operation !== operation || result.status === 'error') throw new Error('Unconfirmed');
          if (result.status === 'ready') { verified = true; break; }
          if (result.status !== 'pending') throw new Error('Unconfirmed');
          if (!await this.tasks.wait(200)) return;
        }
        if (!current()) return;
        if (!verified) throw new Error('Timeout');
        this.ports.mark('save.cancel.verify.ready');
        const fresh: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi.savedRead(' + JSON.stringify(pin) + '))');
        if (!current()) return;
        saved = JSON.parse(this.ports.webJsonText(fresh)) as PinmonySaveIdentity | null;
      }
      if (saved && /^\d+$/.test(saved.id)) {
        if (saved.id === this.ports.pinIdentity(pin)) throw new Error('Unconfirmed');
        this.store.saveUndoPin = pin; this.store.saveUndoId = saved.id;
        const copy: string = saved.id;
        const started: string = await this.ports.runScript('window.PinmonyPostApi.saveUndo(' +
          JSON.stringify(pin) + ',' + JSON.stringify(copy) + ')');
        if (!current()) return;
        if (started !== 'true' && started !== '"true"') throw new Error('Unconfirmed');
        deleteSent = true;
        this.ports.mark('save.cancel.delete.dispatched');
        const until: number = Date.now() + 20000;
        while (current() && Date.now() < until) {
          const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi.savedUndoRead(' +
            JSON.stringify(pin) + ',' + JSON.stringify(copy) + '))');
          if (!current()) return;
          const result: PinmonySaveOperationResult | null = JSON.parse(this.ports.webJsonText(raw)) as PinmonySaveOperationResult | null;
          if (!result || result.status === 'error') throw new Error('Unconfirmed');
          if (result.status === 'done') { this.ports.mark('save.cancel.confirmed'); return; }
          if (result.status !== 'pending') throw new Error('Unconfirmed');
          if (!await this.tasks.wait(200)) return;
        }
        if (!current()) return;
        throw new Error('Timeout');
      }
      // For older saved Pins, the existing edit reader verifies current-account ownership before deletion.
      await this.ports.runScript('window.PinmonyPostApi.editStart(' + JSON.stringify(pin) + ')');
      let sent: boolean = false;
      const until: number = Date.now() + 20000;
      while (current() && Date.now() < until) {
        const read: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi.editRead(' + JSON.stringify(pin) + '))');
        if (!current()) return;
        const result: PinmonyEditPinResult | null = JSON.parse(this.ports.webJsonText(read)) as PinmonyEditPinResult | null;
        if (!result || result.error || result.uncertain) throw new Error('Unconfirmed');
        if (result.done === 'deleted') {
          this.store.confirmedSaves.confirm(this.ports.pinIdentity(pin), false);
          if (this.store.detail) this.store.detail = this.store.confirmedSaves.apply(this.ports.pinIdentity(pin), this.store.detail);
          this.store.detailCache.remove(this.ports.pinIdentity(pin));
          this.ports.showMessage('已取消收藏'); return;
        }
        if (!result.loading && !result.busy && !sent) {
          sent = true; deleteSent = true;
          await this.ports.runScript('window.PinmonyPostApi.editPhase(' + JSON.stringify(pin) + ',"confirm") && window.PinmonyPostApi.editCommit(' + JSON.stringify(pin) + ',true); true');
        }
        if (!await this.tasks.wait(200)) return;
      }
      if (current()) throw new Error('Timeout');
    } catch (_) {
      if (current()) {
        this.ports.mark(deleteSent ? 'save.cancel.delete.unconfirmed' : 'save.cancel.verify.failed');
        this.ports.showMessage(deleteSent ? '取消收藏结果未确认，请重新读取帖子后检查' : '取消收藏未确认，请重新读取后检查');
      }
    } finally {
      if (this.ports.authEpoch() === epoch && page === this.ports.document()) this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.savedRestoreClose(' +
        JSON.stringify(pin) + ',' + operation.toString() + ')').catch(() => {});
      if (this.store.saveCancelToken === operation) this.store.viewerSaveBusy = false;
    }
  }


  async retryDetailMedia(): Promise<void> {
    if(this.ports.nativeRetryMedia){await this.ports.nativeRetryMedia();return;}
    if (this.store.detailMediaRetryBusy || this.store.detailPreparing || this.ports.businessSuspended() || this.ports.rejectOfflineAction('video refresh')) return;
    const pin: string = this.store.detail?.pinUrl || '';
    PinmonyRuntimeLog.info('VideoTrace: openId=' + this.store.detailOpeningToken.toString() + ' event=refresh-context-requested');
    const generation: number = this.generation;
    const retained: boolean = this.store.detailPresentationOnly;
    if (!this.ports.pinIdentity(pin)) return;
    const operation: number = this.store.detailMediaRetryToken = (this.store.detailMediaRetryToken % 2147483647) + 1;
    const epoch: number = this.ports.authEpoch();
    this.store.detailMediaRetryBusy = true;
    try {
      if (!await this.ports.ensureDetailActionContext()) return;
      // Retained-page preparation creates a new detail token and owns its initial media read.
      if (generation !== this.generation || this.ports.businessSuspended() || this.ports.authEpoch() !== epoch || this.store.detailMediaRetryToken !== operation ||
          this.store.detail?.pinUrl !== pin || this.ports.currentPinUrl() !== pin || !this.store.detailActionsReady) return;
      if (this.store.detail.mediaLoading || retained && this.store.detail.video) return;
      const page: string = this.ports.document();
      const session: number = this.store.detailSession;
      const current = (): boolean => generation === this.generation && page === this.ports.document() &&
        this.ports.authEpoch() === epoch && this.ports.authStatus() === 'authenticated' &&
        !this.ports.businessSuspended() && this.store.detailMediaRetryToken === operation &&
        this.store.detailSession === session && this.store.detail?.pinUrl === pin &&
        this.ports.currentPinUrl() === pin && this.store.detailActionsReady;
      const started: string = await this.ports.runScript('window.PinmonyDetailApi && window.PinmonyDetailApi.retryMedia(' +
        JSON.stringify(pin) + ',' + operation.toString() + ')');
      if (!current()) return;
      if (started !== 'true' && started !== '"true"') { this.ports.showMessage('视频地址读取暂不可用，请重试'); return; }
      this.ports.mark('video.refresh.accepted');
      const until: number = Date.now() + 17000;
      while (current() && Date.now() < until) {
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyDetailApi.mediaRetryRead(' +
          JSON.stringify(pin) + ',' + operation.toString() + '))');
        if (!current()) return;
        const result: PinmonyMediaReadResult | null = JSON.parse(this.ports.webJsonText(raw)) as PinmonyMediaReadResult | null;
        if (!result || result.operation !== operation) throw new Error('Unconfirmed');
        if (result.status === 'ready') { this.ports.mark('video.address.read.confirmed'); return; }
        if (result.status === 'error') { this.ports.mark('video.address.read.failed'); return; }
        if (result.status !== 'pending') throw new Error('Unconfirmed');
        if (!await this.tasks.wait(200)) return;
      }
      if (current()) this.ports.showMessage('视频地址读取结果未确认，请重试');
    } catch (_) {
      if (generation === this.generation && this.ports.authEpoch() === epoch && this.ports.authStatus() === 'authenticated' && !this.ports.businessSuspended() &&
          this.store.detailMediaRetryToken === operation && this.store.detail?.pinUrl === pin && this.ports.currentPinUrl() === pin)
        this.ports.showMessage('视频接口暂不可用，请重试');
    } finally {
      if (this.store.detailMediaRetryToken === operation) this.store.detailMediaRetryBusy = false;
    }
  }


}
