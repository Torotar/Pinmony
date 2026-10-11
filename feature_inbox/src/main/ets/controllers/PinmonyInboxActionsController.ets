import { PinmonyInboxStore } from '../stores/PinmonyInboxStore';

export interface PinmonyInboxActionsPorts {
  allowed: () => boolean;
  epoch: () => number;
  document: () => string;
  currentInbox: () => string;
  enabled: () => boolean;
  prepare: (current: () => boolean) => Promise<boolean>;
  runScript: (script: string) => Promise<string>;
  feedback: (message: string) => void;
}
// The bridge owns server result validation. A bridge acknowledgement is never business success.
export class PinmonyInboxActionsController {
  private readonly store: PinmonyInboxStore;
  private readonly ports: PinmonyInboxActionsPorts;
  private generation: number = 0;
  private opening: boolean = false;
  private acting: boolean = false;
  private intent: number = 0;
  constructor(store: PinmonyInboxStore, ports: PinmonyInboxActionsPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.generation++; this.intent++; this.opening = false; this.acting = false; }
  async open(id: string): Promise<void> {
    if (!this.ports.allowed() || !this.ports.enabled() || this.opening ||
        !(id === 'compose' || id === 'home' || /^(?:conversation:|contact:|news-menu:)/.test(id))) return;
    const generation: number = this.generation, epoch: number = this.ports.epoch();
    let page: string = '', session: number = -1;
    const current = (): boolean => generation === this.generation && epoch === this.ports.epoch() && this.ports.allowed() &&
      (!page || page === this.ports.document()) && (session < 0 || session === this.store.inboxSession);
    this.opening = true;
    try {
      if (!await this.ports.prepare(current) || !current() || !this.store.inboxActionsReady || !this.store.inbox ||
          this.store.inboxUrl !== this.ports.currentInbox()) return;
      page = this.ports.document(); session = this.store.inboxSession;
      const result: string = await this.ports.runScript('window.PinmonyInboxApiAction && window.PinmonyInboxApiAction(' +
        JSON.stringify(id) + ',' + session.toString() + ')');
      if (current() && page === this.ports.document() && session === this.store.inboxSession && result !== 'true' && result !== '"true"')
        this.ports.feedback('收件箱接口入口不可用，请重试');
    } catch (_) { if (current()) this.ports.feedback('收件箱接口入口不可用，请重试'); }
    finally { if (generation === this.generation) this.opening = false; }
  }
  async action(action: string, value: string = ''): Promise<void> {
    const flow = this.store.inboxFlow;
    const interrupt: boolean = action === 'back' || action === 'search' || action === 'retry';
    if (!this.ports.allowed() || !flow || flow.pageUrl !== this.ports.currentInbox() || flow.session !== this.store.inboxSession || (this.acting && !interrupt)) return;
    // Keep back available; existing bridge checks determine which reads/actions are supported.
    if (!interrupt && (flow.loading || flow.sending || flow.messageBusy)) return;
    const generation: number = this.generation, epoch: number = this.ports.epoch(), page: string = this.ports.document();
    const session: number = this.store.inboxSession;
    const intent: number = ++this.intent;
    const current = (): boolean => intent === this.intent && generation === this.generation && epoch === this.ports.epoch() && this.ports.allowed() &&
      page === this.ports.document() && session === this.store.inboxSession && this.store.inboxFlow?.pageUrl === flow.pageUrl &&
      this.store.inboxFlow?.screen === flow.screen && this.store.inboxFlow?.conversationId === flow.conversationId && this.store.inboxFlow?.newsId === flow.newsId;
    if (!interrupt) this.acting = true;
    try { await this.ports.runScript('window.PinmonyInboxConversations && window.PinmonyInboxConversations.action(' +
      JSON.stringify(action) + ',' + JSON.stringify(value) + ',' + session.toString() + ')'); }
    catch (_) { if (current()) this.ports.feedback('当前消息操作不可用，请重试'); }
    finally { if (!interrupt && generation === this.generation) this.acting = false; }
  }
}
