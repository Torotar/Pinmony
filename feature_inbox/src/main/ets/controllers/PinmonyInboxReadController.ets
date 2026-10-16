import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyInboxStore } from '../stores/PinmonyInboxStore';
import { PinmonyInboxSnapshot, PinmonyInboxItem } from '../models/PinmonyInbox';
import { PinmonyInboxFlowSnapshot } from '../models/PinmonyInboxFlow';
export interface PinmonyInboxReadPorts {
  nativeMessages?: () => boolean;
  nativeMessagesApply?: () => void;
  nativeMessagesDemand?: () => Promise<void>;
  nativeMessagesRefresh?: () => Promise<void>;
  nativeMessagesContacts?: () => Promise<void>;
  nativeMessagesBridge?: (flow: PinmonyInboxFlowSnapshot) => boolean;
  documentEpoch?: () => number;
  nativeUpdates?: () => boolean;
  nativeUpdatesApply?: () => void;
  nativeUpdatesSelect?: (section: string) => Promise<boolean>;
  nativeUpdatesDemand?: () => Promise<void>;
  nativeUpdatesRefresh?: () => Promise<void>;
  nativeUpdatesMore?: () => Promise<void>;
  nativeUpdatesVisibility?: (newsId: string,hidden: boolean) => void;
  authenticated: () => boolean;
  foreground: () => boolean;
  document: () => string;
  addressKey: (address: string) => string;
  inboxAddress: (address: string) => string;
  currentInbox: () => string;
  activeTab: () => number;
  pendingTab: () => number;
  rootAddress: () => string;
  rootOnly: () => boolean;
  interacted: () => boolean;
  backTarget: () => string;
  runScript: (script: string) => Promise<string>;
  finishPull: () => void;
  readInvitations: () => void;
  recordAddress: (address: string) => void;
  confirmed: () => void;
  readStarted: () => void;
  cancelled: (count: number) => void;
  prepareContext: () => Promise<boolean>;
  prepareRead: () => boolean;
  requestRead: () => void;
  feedback: (message: string) => void;
}
export class PinmonyInboxReadController {
  private readonly store: PinmonyInboxStore;
  private readonly ports: PinmonyInboxReadPorts;
  private readonly loadingTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly sectionTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly refreshTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private preparation: number = 0;
  private loadingMore: boolean = false;
  private refreshing: boolean = false;
  private refreshAwaiting: boolean = false;
  private contactsReading: boolean = false;
  constructor(store: PinmonyInboxStore, ports: PinmonyInboxReadPorts) { this.store = store; this.ports = ports; }
  private allowed(): boolean { return this.ports.authenticated() && this.ports.foreground(); }
  private matches(generation: number, document: string): boolean {
    return generation === this.generation && this.allowed() && document === this.ports.document();
  }
  pause(): void {
    this.preparation++;
    this.cancelReads();
  }
  private cancelReads(): void {
    this.generation++;
    const cancelled: number = this.loadingTasks.invalidate() + this.sectionTasks.invalidate() + this.refreshTasks.invalidate();
    if (cancelled > 0) this.ports.cancelled(cancelled);
    this.loadingMore = false; this.refreshing = false; this.refreshAwaiting = false; this.contactsReading = false;
    if (this.store.pendingInboxSection && this.store.inbox) this.store.inboxLoading = false;
    this.store.pendingInboxSection = ''; this.store.restoringInboxSection = '';
    this.ports.finishPull();
  }
  resume(): void { if (this.allowed() && this.ports.activeTab() === 2 && this.store.inboxLoading) this.armLoading(); }
  clear(): void {
    if(this.ports.nativeMessages?.()){this.cancelReads(); this.store.inboxActionsReady = false; this.ports.nativeMessagesApply?.(); return;}
    if(this.ports.nativeUpdates?.()){ this.cancelReads(); this.store.inboxActionsReady = false; this.ports.nativeUpdatesApply?.(); return; }
    // A document prepared for the latest explicit intent may clear the old snapshot.
    // Keep that waiting intent; tab/background/session cancellation goes through pause().
    this.cancelReads();
    this.store.inboxSectionReady = false;
    const inboxHasContent: boolean = !!this.store.inbox &&
      (this.store.inboxActionsReady || this.store.inbox.items.length > 0 ||
        this.store.inbox.contacts.length > 0);
    if (this.store.inbox && inboxHasContent) {
      this.store.inboxCache.put(this.store.inbox, this.store.inboxScrollOffset);
    }
    this.store.inboxActionsReady = false;
    this.store.inboxRetainedContent = false;
    this.store.inboxScrollOffset = 0;
    this.store.restoringInboxSection = '';
    this.store.inboxFlow = this.store.retainedChat;
    this.store.inboxRequestToken++;
    this.store.inbox = undefined;
    this.store.inboxSession = 0;
    this.store.inboxUrl = '';
    this.store.inboxLoading = false;
    this.store.inboxError = '';
    this.store.inboxWebFlow = false;
    this.store.pendingInboxSection = '';
  }


  restore(address: string): boolean {
    this.store.inboxSectionReady = false;
    const url: string = this.ports.inboxAddress(address);
    const entry = this.store.inboxCache.get(url);
    if (!entry) return false;
    this.store.inbox = entry.snapshot;
    this.store.inboxUrl = url;
    this.store.inboxScrollOffset = entry.scrollOffset;
    this.store.inboxActionsReady = false;
    this.store.restoringInboxSection = entry.snapshot.section;
    this.store.inboxRetainedContent = true;
    this.store.inboxLoading = false;
    this.store.inboxError = '';
    return true;
  }


  expect(): void {
    if(this.ports.nativeMessages?.()){this.ports.nativeMessagesDemand?.(); return;}
    if(this.ports.nativeUpdates?.()){ this.ports.nativeUpdatesDemand?.(); return; }
    if (!this.allowed()) return;
    if (this.store.inbox && this.store.inboxUrl === this.ports.currentInbox()) return;
    if (this.store.inbox && this.ports.pendingTab() === 2 &&
        this.store.inboxUrl === this.ports.rootAddress()) return;
    if (this.restore(this.ports.currentInbox())) return;
    if (this.ports.pendingTab() === 2 && this.restore(this.ports.rootAddress() || '')) return;
    this.store.inboxLoading = true;
    this.store.inboxError = '';
    this.store.inboxWebFlow = false;
    this.armLoading();
  }

  private armLoading(): void {
    const token: number = ++this.store.inboxRequestToken;
    const generation: number = this.generation, document: string = this.ports.document();
    this.loadingTasks.invalidate();
    this.loadingTasks.timeout(() => {
      if (!this.matches(generation, document) || this.store.inboxRequestToken !== token || !this.store.inboxLoading) return;
      this.store.inboxLoading = false;
      this.refreshAwaiting = false;
      this.store.pendingInboxSection = '';
      if (this.ports.currentInbox()) this.store.inboxError = '无法读取当前 Pinterest 收件箱，请重试';
      else this.clear();
    }, 8000);
  }


  update(value: string): void {
    if (!this.allowed()) return;
    if (this.ports.rootOnly() && !this.ports.interacted()) return;
    if (this.ports.backTarget()) {
      try {
        if (this.ports.addressKey(this.ports.document()) !== this.ports.addressKey(this.ports.backTarget())) return;
      } catch (_) { return; }
    }
    try {
      const flow: PinmonyInboxFlowSnapshot = JSON.parse(value) as PinmonyInboxFlowSnapshot;
      if (flow.kind === 'nativeFlow') {
        if(this.ports.nativeUpdates?.() && flow.screen === 'updatesMenu')return;
        if((this.ports.nativeUpdates?.() || this.ports.nativeMessages?.()) && this.ports.documentEpoch && flow.contextEpoch !== this.ports.documentEpoch()) return;
        if (this.store.flowDismissed) return;
        if (flow.pageUrl !== this.ports.currentInbox() || flow.session !== this.store.inboxSession ||
            this.ports.inboxAddress(this.ports.document()) !== flow.pageUrl) return;
        if(this.ports.nativeMessages?.() && flow.screen === 'closed')return;
        if (flow.screen === 'closed') {
          if (!this.store.retainedChat) { this.store.inboxFlow = undefined; this.store.chatReturnConversation = ''; }
          this.ports.nativeUpdatesApply?.(); return;
        }
        if (!Array.isArray(flow.users) || !Array.isArray(flow.messages) || !Array.isArray(flow.selectedIds) ||
            flow.users.length > 1000 || flow.messages.length > 2000 || flow.selectedIds.length > 1000) return;
        if(this.ports.nativeMessages?.() && this.ports.nativeMessagesBridge?.(flow))return;
        if (flow.screen === 'chat' && flow.loading && this.store.retainedChat?.conversationId === flow.conversationId) return;
        const retained = this.store.retainedChat;
        if (flow.screen === 'chat' && retained && retained.conversationId === flow.conversationId && !flow.loading) {
          if (flow.error) flow.messages = retained.messages;
          else if (flow.messages.length > 0 && flow.hasMore) {
            const oldest: number = Math.min(...flow.messages.map(message => Date.parse(message.createdAt)).filter(value => Number.isFinite(value)));
            const freshIds: Set<string> = new Set(flow.messages.map(message => message.id));
            const older = retained.messages.filter(message => !freshIds.has(message.id) && Date.parse(message.createdAt) < oldest);
            flow.messages = older.concat(flow.messages);
            if (older.length > 0) {
              // Restore read history in the current script too, so later reads and
              // confirmed reactions do not discard it. This dispatch never sends a message.
              this.ports.runScript('window.PinmonyInboxConversations && window.PinmonyInboxConversations.retainHistory(' +
                flow.session.toString() + ',' + JSON.stringify(flow.conversationId) + ',' + JSON.stringify(older) + ')').catch(() => {});
            }
          }
        }
        this.store.inboxFlow = flow;
        if(flow.screen === 'updatesMenu' && typeof flow.newsHidden === 'boolean' && flow.newsId) this.ports.nativeUpdatesVisibility?.(flow.newsId,flow.newsHidden);
        if (flow.screen === 'chat' && !flow.loading && !flow.error && this.store.retainedChat?.conversationId === flow.conversationId) this.store.retainedChat = undefined;
        return;
      }
      const message: PinmonyInboxSnapshot = JSON.parse(value) as PinmonyInboxSnapshot;
      if(this.ports.nativeUpdates?.() || this.ports.nativeMessages?.()) {
        // Only the current document may confirm an action session; its root data stays separate.
        if(message && Number.isInteger(message.session) && message.session >= 0 && (!this.ports.documentEpoch || message.contextEpoch === this.ports.documentEpoch()) && message.pageUrl === this.ports.currentInbox() && this.ports.inboxAddress(this.ports.document()) === message.pageUrl) {
          this.store.inboxSession = message.session; this.store.inboxActionsReady = message.kind === 'state'; this.ports.nativeUpdatesApply?.(); this.ports.nativeMessagesApply?.();
        }
        return;
      }
      if (!message || !Number.isInteger(message.session) || message.session < 0 || typeof message.pageUrl !== 'string') return;
      if (message.kind === 'closed') {
        if (this.ports.currentInbox()) return;
        if (message.pageUrl === this.store.inboxUrl && message.session >= this.store.inboxSession) this.clear();
        return;
      }
      if (this.ports.currentInbox() !== message.pageUrl || this.ports.inboxAddress(this.ports.document()) !== message.pageUrl ||
          message.session < this.store.inboxSession) return;
      if (message.kind === 'unavailable') {
        this.refreshAwaiting = false;
        this.refreshTasks.invalidate();
        this.loadingTasks.invalidate(); this.sectionTasks.invalidate();
        this.ports.finishPull();
        this.store.inboxSectionReady = false;
        this.store.inboxSession = message.session;
        this.store.inboxUrl = message.pageUrl;
        this.store.inboxRequestToken++;
        this.store.inbox = undefined;
        this.store.inboxLoading = false;
        this.store.inboxError = '无法识别当前收件箱内容，请重试';
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') ||
        (message.section !== 'updates' && message.section !== 'messages') ||
        !message.updateLabel || !message.inboxLabel ||
        !Array.isArray(message.items) || !Array.isArray(message.contacts) || message.items.length > 2000 || message.contacts.length > 1000) return;
      if (this.ports.activeTab() === 2 && !this.store.boardInvitationPreview &&
          this.store.invitationReadPage !== message.pageUrl) this.ports.readInvitations();
      if (this.store.pendingInboxSection && this.store.pendingInboxSection !== message.section) return;
      if (this.store.restoringInboxSection && this.store.restoringInboxSection !== message.section) {
        const section: string = this.store.restoringInboxSection;
        this.store.restoringInboxSection = '';
        this.store.pendingInboxSection = section;
        this.store.inboxSession = message.session;
        const generation: number = this.generation, document: string = this.ports.document();
        const token: number = ++this.store.inboxRequestToken;
        this.sectionTasks.invalidate();
        this.ports.readStarted();
        this.ports.runScript('window.PinmonyInboxSelectApi && window.PinmonyInboxSelectApi(' +
          JSON.stringify(section) + ',' + message.session.toString() + ')')
          .then((result: string) => {
            if (!this.matches(generation, document) || token !== this.store.inboxRequestToken || this.store.inboxSession !== message.session || this.ports.currentInbox() !== message.pageUrl) return;
            if (result !== 'true' && result !== '"true"') {
              this.store.pendingInboxSection = '';
              this.store.inboxError = '无法恢复收件箱分段，请重试';
            }
          }).catch(() => {
            if (!this.matches(generation, document) || token !== this.store.inboxRequestToken || this.store.inboxSession !== message.session || this.ports.currentInbox() !== message.pageUrl) return;
            this.store.pendingInboxSection = '';
            this.store.inboxError = '无法恢复收件箱分段，请重试';
          });
        this.sectionTasks.timeout(() => {
          if (!this.matches(generation, document) || token !== this.store.inboxRequestToken || this.store.inboxSession !== message.session || this.ports.currentInbox() !== message.pageUrl ||
              this.store.pendingInboxSection !== section) return;
          this.store.pendingInboxSection = '';
          this.store.inboxError = '收件箱分段恢复超时，请重试';
        }, 8000);
        return;
      }
      this.loadingTasks.invalidate(); this.sectionTasks.invalidate();
      this.store.restoringInboxSection = '';
      this.store.inboxSectionReady = true;
      const cachedInbox = this.store.inboxCache.get(message.pageUrl, message.section);
      const retainingInbox: boolean = !!cachedInbox && message.kind !== 'state';
      this.store.inboxRetainedContent = retainingInbox;
      if (this.store.inbox && this.store.inbox.section !== message.section) this.store.inboxScrollOffset = cachedInbox?.scrollOffset || 0;
      this.store.inboxSession = message.session;
      this.store.inboxUrl = message.pageUrl;
      this.store.inboxRequestToken++;
      this.store.pendingInboxSection = '';
      this.store.inboxLoading = false;
      this.store.inboxError = '';
      this.store.inboxWebFlow = false;
      this.store.inboxLoading = !retainingInbox && message.kind === 'apiPending';
      this.store.inboxError = message.kind === 'apiFailed' ? (message.apiError || (message.section === 'updates' ? '更新接口读取失败，请重试' : '会话列表读取失败，请重试')) : '';
      this.store.inbox = {
        kind: 'state', session: message.session, pageUrl: message.pageUrl, section: message.section,
        updateLabel: message.updateLabel, inboxLabel: message.inboxLabel,
        emptyTitle: message.emptyTitle || '', emptyDescription: message.emptyDescription || '',
        homeLabel: message.homeLabel || '', homeId: message.homeId || '',
        composeLabel: message.composeLabel || '', composeId: message.composeId || '',
        contactsLabel: message.contactsLabel || '',
        dataSource: message.dataSource, hasMore: message.hasMore, moreLoading: message.moreLoading, moreError: message.moreError,
        contactsDataSource: message.contactsDataSource, contactsLoading: message.contactsLoading,
        contactsError: message.contactsError,
        messagesLabel: message.messagesLabel, readLabel: message.readLabel, unreadLabel: message.unreadLabel,
        items: retainingInbox && cachedInbox ? cachedInbox.snapshot.items :
          message.items.filter((item: PinmonyInboxItem): boolean => !!item.id && !!item.title),
        contacts: (message.contactsLoading || message.contactsError) && cachedInbox ?
          cachedInbox.snapshot.contacts.map((item: PinmonyInboxItem): PinmonyInboxItem => {
            return { id: item.id, title: item.title, subtitle: item.subtitle, imageUrl: item.imageUrl, enabled: false };
          }) :
          message.contacts.filter((item: PinmonyInboxItem): boolean => !!item.id && !!item.title)
      };
      this.store.inboxActionsReady = message.kind === 'state';
      if (message.kind !== 'apiPending') { this.refreshAwaiting = false; this.refreshTasks.invalidate(); }
      if (this.store.inboxLoading) this.armLoading();
      if (message.kind === 'apiFailed' || message.kind === 'state' &&
          (message.section === 'updates' || message.contactsLoading !== true)) this.ports.finishPull();
      if (this.store.inboxActionsReady) {
        const chat = this.store.retainedChat;
        if (chat && chat.pageUrl === message.pageUrl && /^\d+$/.test(chat.conversationId || '')) {
          this.ports.runScript('window.PinmonyInboxApiAction && window.PinmonyInboxApiAction(' +
            JSON.stringify('conversation:' + chat.conversationId) + ',' + message.session.toString() + ')').catch(() => {});
        }
        this.store.inboxCache.put(this.store.inbox, this.store.inboxScrollOffset);
        this.ports.recordAddress(message.pageUrl);
        this.ports.confirmed();
      }
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid inbox state');
    }
  }


  async selectSection(section: string): Promise<void> {
    if (this.store.inboxFlow) return;
    if (!this.allowed() || this.ports.activeTab() !== 2) return;
    const preparation: number = ++this.preparation;
    if (section !== 'updates' && section !== 'messages') return;
    if(await this.ports.nativeUpdatesSelect?.(section)) return;
    if (!await this.ports.prepareContext() || preparation !== this.preparation || !this.allowed() || this.ports.activeTab() !== 2) return;
    const generation: number = this.generation;
    if (!this.store.inboxSectionReady || !this.store.inbox || this.store.inboxSession !== this.store.inbox.session || this.store.inboxUrl !== this.ports.currentInbox() ||
      this.store.restoringInboxSection || this.store.pendingInboxSection) return;
    if (this.store.inboxActionsReady === false && this.store.inbox.dataSource !== 'api') return;
    if (this.store.inboxActionsReady && !this.store.inboxLoading && !this.store.inboxError) this.store.inboxCache.put(this.store.inbox, this.store.inboxScrollOffset);
    this.store.inboxScrollOffset = 0;
    if (!this.store.inbox || ((this.store.inboxLoading || !!this.store.inboxError) && this.store.inbox.dataSource !== 'api') ||
      section === this.store.inbox.section || this.store.inboxUrl !== this.ports.currentInbox()) return;
    const session: number = this.store.inboxSession;
    const document: string = this.ports.document();
    this.sectionTasks.invalidate();
    const token: number = ++this.store.inboxRequestToken;
    this.store.pendingInboxSection = section;
    this.store.inboxLoading = true;
    this.ports.readStarted();
    try {
      const result: string = await this.ports.runScript(
        'window.PinmonyInboxSelectApi && window.PinmonyInboxSelectApi(' +
        JSON.stringify(section) + ',' + session.toString() + ')');
      if (!this.matches(generation, document) || token !== this.store.inboxRequestToken || session !== this.store.inboxSession) return;
      if (result === 'true' || result === '"true"') {
        this.sectionTasks.timeout(() => {
          if (!this.matches(generation, document) || this.store.inboxRequestToken !== token || this.store.pendingInboxSection !== section) return;
          this.store.pendingInboxSection = '';
          this.store.inboxLoading = false;
          this.ports.feedback('收件箱接口切换超时，请重试');
        }, 4500);
        return;
      }
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: inbox section switch failed');
    }
    if (!this.matches(generation, document) || this.store.inboxRequestToken !== token) return;
    this.store.pendingInboxSection = '';
    this.store.inboxLoading = false;
    this.ports.feedback('当前分段不可用，请重试');
  }


  async loadMore(): Promise<void> {
    if(this.ports.nativeUpdates?.()){ await this.ports.nativeUpdatesMore?.(); return; }
    if (!this.allowed() || this.ports.activeTab() !== 2 || this.loadingMore || !this.store.inbox?.hasMore || this.store.inbox?.moreLoading) return;
    if (this.store.inboxActionsReady === false) return;
    if (!this.store.inbox || this.store.inbox.section !== 'updates' || this.store.inboxUrl !== this.ports.currentInbox()) return;
    const generation: number = this.generation, document: string = this.ports.document();
    this.loadingMore = true;
    this.ports.readStarted();
    try { await this.ports.runScript('window.PinmonyInboxApiMore && window.PinmonyInboxApiMore(' + this.store.inboxSession.toString() + ')'); }
    catch (error) { if (this.matches(generation, document)) this.ports.feedback('无法加载更多更新，请重试'); }
    finally { if (generation === this.generation) this.loadingMore = false; }
  }

  async refresh(): Promise<void> {
    if(this.ports.nativeMessages?.()){await this.ports.nativeMessagesRefresh?.(); this.ports.finishPull(); return;}
    if(this.ports.nativeUpdates?.()){ await this.ports.nativeUpdatesRefresh?.(); this.ports.finishPull(); return; }
    if (!this.allowed() || this.ports.activeTab() !== 2 || this.refreshing || this.refreshAwaiting) return;
    if (this.ports.rootOnly() && this.ports.prepareRead()) return;
    if (!this.ports.currentInbox()) { this.ports.requestRead(); return; }
    this.store.inboxActionsReady = false;
    this.store.inboxError = '';
    this.store.restoringInboxSection = '';
    this.store.pendingInboxSection = '';
    this.expect();
    const generation: number = this.generation, document: string = this.ports.document(), token: number = this.store.inboxRequestToken;
    this.refreshing = true;
    this.refreshAwaiting = true; this.ports.readStarted();
    this.refreshTasks.invalidate();
    this.refreshTasks.timeout((): void => {
      if (!this.matches(generation, document) || !this.refreshAwaiting) return;
      this.refreshAwaiting = false; this.store.inboxLoading = false;
      this.store.inboxError = '刷新超时，请重试'; this.ports.finishPull();
    }, 20000);
    try {
      const result: string = await this.ports.runScript('window.PinmonyInboxApiRefresh && window.PinmonyInboxApiRefresh()');
      if (!this.matches(generation, document) || token !== this.store.inboxRequestToken) return;
      if (result !== 'true' && result !== '"true"') {
        this.refreshAwaiting = false;
        this.store.inboxLoading = false;
        this.store.inboxError = '无法重新读取收件箱，请稍后重试';
      }
    } catch (error) {
      if (this.matches(generation, document) && token === this.store.inboxRequestToken) {
        this.refreshAwaiting = false;
        this.store.inboxLoading = false; this.store.inboxError = '无法重新读取收件箱，请稍后重试';
      }
    } finally { if (generation === this.generation) this.refreshing = false; }
  }


  async refreshContacts(): Promise<void> {
    if(this.ports.nativeMessages?.()){await this.ports.nativeMessagesContacts?.(); return;}
    if (!this.allowed() || this.ports.activeTab() !== 2 || this.contactsReading) return;
    const preparation: number = ++this.preparation;
    if (!await this.ports.prepareContext() || preparation !== this.preparation || !this.allowed() || this.ports.activeTab() !== 2) return;
    const generation: number = this.generation;
    if (!this.store.inbox || this.store.inbox.section !== 'messages' || this.store.inboxUrl !== this.ports.currentInbox()) return;
    const document: string = this.ports.document(); this.contactsReading = true;
    this.ports.readStarted();
    try {
      await this.ports.runScript('window.PinmonyInboxContactsApiRefresh && window.PinmonyInboxContactsApiRefresh(' +
        this.store.inboxSession.toString() + ')');
    } catch (error) { if (this.matches(generation, document)) this.ports.feedback('无法重新读取联系人，请重试'); }
    finally { if (generation === this.generation) this.contactsReading = false; }
  }

}
