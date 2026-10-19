import { PinmonyI18n } from 'common_foundation';
import { PinmonyInboxStore } from '../stores/PinmonyInboxStore';

export interface PinmonyInboxActionsPorts {
  nativeOpen?: (id: string) => Promise<boolean>;
  nativeAction?: (action: string,value: string) => Promise<boolean>;
  nativeWrites?: () => boolean;
  allowed: () => boolean;
  epoch: () => number;
  document: () => string;
  currentInbox: () => string;
  enabled: () => boolean;
  prepare: (current: () => boolean) => Promise<boolean>;
  runScript: (script: string) => Promise<string>;
  feedback: (message: string) => void;
}
// Native owners handle migrated actions; a legacy bridge acknowledgement is never business success.
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
    if(this.ports.nativeOpen) {
      this.opening = true;
      try {if(await this.ports.nativeOpen(id))return;}
      finally {this.opening = false;}
    }
    const generation: number = this.generation;
    let epoch: number = -1;
    let page: string = '', session: number = -1;
    const current = (): boolean => generation === this.generation && (epoch < 0 || epoch === this.ports.epoch()) && this.ports.allowed() &&
      (!page || page === this.ports.document()) && (session < 0 || session === this.store.inboxSession);
    this.opening = true;
    try {
      if (!await this.ports.prepare(current) || !current() || !this.store.inboxActionsReady || !this.store.inbox ||
          this.store.inboxUrl !== this.ports.currentInbox()) return;
      page = this.ports.document(); session = this.store.inboxSession; epoch = this.ports.epoch();
      let target: string = id;
      const news: RegExpMatchArray | null = id.match(/^news-menu:inbox-news-api-\d+-(.+)$/);
      if (news) {
        const matches = this.store.inbox.items.filter(item =>
          item.moreId?.replace(/^news-menu:inbox-news-api-\d+-/, '') === news[1]);
        if (matches.length !== 1 || !matches[0].moreId) return;
        target = matches[0].moreId;
      }
      this.store.flowDismissed = false;
      const result: string = await this.ports.runScript('window.PinmonyInboxApiAction && window.PinmonyInboxApiAction(' +
        JSON.stringify(target) + ',' + session.toString() + ')');
      if (current() && page === this.ports.document() && session === this.store.inboxSession && result !== 'true' && result !== '"true"')
        this.ports.feedback(PinmonyI18n.message("pm_inbox_service_unavailable_please_retry_dc0da88f"));
    } catch (_) { if (current()) this.ports.feedback(PinmonyI18n.message("pm_inbox_service_unavailable_please_retry_dc0da88f")); }
    finally { if (generation === this.generation) this.opening = false; }
  }
  async action(action: string, value: string = ''): Promise<void> {
    if(this.ports.allowed() && await this.ports.nativeAction?.(action,value))return;
    if(this.ports.nativeWrites?.()) {
      const flow = this.store.inboxFlow;
      if(!this.ports.allowed() || !flow || flow.loading || flow.sending || flow.messageBusy || this.acting)return;
      const generation: number = this.generation; const intent: number = ++this.intent; const token: number | undefined = flow.nativeToken;
      const current = (): boolean => generation === this.generation && intent === this.intent && this.ports.allowed() && !this.store.flowDismissed && this.store.inboxFlow?.nativeToken === token;
      this.acting = true;
      try {
        if(!await this.ports.prepare(current) || !current() || !this.store.inboxActionsReady || this.store.inboxUrl !== this.ports.currentInbox())return;
        await this.ports.runScript('window.PinmonyInboxConversations && window.PinmonyInboxConversations.action(' + JSON.stringify(action) + ',' + JSON.stringify(value) + ',' + this.store.inboxSession.toString() + ')');
      } catch (_) {if(current())this.ports.feedback(PinmonyI18n.message("pm_message_action_unavailable_please_retry_e826e521"));}
      finally {if(generation === this.generation)this.acting = false;}
      return;
    }
    const flow = this.store.inboxFlow;
    if (action === 'back' && this.ports.allowed() && flow?.screen === 'chat') {
      // Returning to the native root never depends on a refreshed Web session.
      this.generation++; this.intent++; this.acting = false; this.opening = false;
      this.store.flowDismissed = true;
      this.store.retainedChat = undefined; this.store.inboxFlow = undefined;
      this.store.chatReturnConversation = ''; this.store.chatScrollOffset = 0;
      if (flow.pageUrl === this.ports.currentInbox() && flow.session === this.store.inboxSession) {
        try { await this.ports.runScript('window.PinmonyInboxConversations && window.PinmonyInboxConversations.close(' +
          flow.session.toString() + ',' + JSON.stringify(flow.conversationId || '') + ')'); } catch (_) {}
      }
      return;
    }
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
    catch (_) { if (current()) this.ports.feedback(PinmonyI18n.message("pm_message_action_unavailable_please_retry_e826e521")); }
    finally { if (!interrupt && generation === this.generation) this.acting = false; }
  }
}
