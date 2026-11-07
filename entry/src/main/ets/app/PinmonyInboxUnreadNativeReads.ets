import { PinmonyInboxStore, PinmonyInboxHiddenConversations } from 'feature_inbox';
import { PinmonyInboxNoticeConversation } from './PinmonyInboxMessageNotice';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
import { INBOX_UPDATE_FIELDS, PIN_NATIVE_INBOX_UPDATES_ENABLED } from './PinmonyInboxUpdatesNativeReads';
import { PIN_NATIVE_INBOX_MESSAGES_ENABLED } from './PinmonyInboxMessagesNativeReads';
export const PIN_INBOX_MESSAGES_POLL_MS: number = 10000;
export const PIN_INBOX_UPDATES_POLL_MS: number = 30 * 60 * 1000;
export const PIN_INBOX_CHAT_POLL_MS: number = 2000;
interface PinmonyUnreadNewsData { field_set_key: string; }
interface PinmonyUnreadOptions { url?: string; data?: PinmonyUnreadNewsData; redux_normalize_feed?: boolean; field_sets?: string[]; field_set_key?: string; }
interface PinmonyUnreadEnvelope { options: PinmonyUnreadOptions; context: Record<string,string>; }
interface PinmonyUnreadRow extends PinmonyInboxNoticeConversation { last_updated_at?: string; }
interface PinmonyUnreadResource { status: string; code?: number; error?: object; endpoint_name?: string; data: PinmonyUnreadRow[]; }
interface PinmonyUnreadResponse { resource_response: PinmonyUnreadResource; }
export interface PinmonyInboxUnreadPorts {
  messagesObserved?: (rows: PinmonyInboxNoticeConversation[]) => void;
  session: () => PinmonyBusinessSessionContext;
  active: () => boolean;
  store: () => PinmonyInboxStore;
  network: () => PinmonyNativeNetwork;
}
// Foreground polling outside the inbox. Never owns or publishes page/chat snapshots.
export class PinmonyInboxUnreadNativeReads {
  private readonly ports: PinmonyInboxUnreadPorts;
  private revision: number = 0;
  private sequence: number = 0;
  private readonly lastPoll: Map<string,number> = new Map<string,number>();
  private lastGate: string = '';
  private readonly jobs: Map<string,string> = new Map<string,string>();
  constructor(ports: PinmonyInboxUnreadPorts) { this.ports = ports; }
  pause(): void { this.revision++; this.jobs.forEach((id: string): void => this.ports.network().cancel(id)); this.jobs.clear(); }
  reset(): void { this.pause(); this.lastPoll.clear(); this.ports.store().clearViewedUpdates(); this.ports.store().inboxMessagesUnread = false; this.ports.store().inboxUpdatesUnread = false; }
  async pollMessages(): Promise<void> {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(PIN_NATIVE_INBOX_MESSAGES_ENABLED && session.authenticated && session.accountId && this.ports.active())await this.readIfDue(false,session);
  }
  async poll(): Promise<void> {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(!session.authenticated || !session.accountId || !this.ports.active()) {
      const gate: string = !session.authenticated ? 'authentication' : !session.accountId ? 'account-unavailable' : 'inactive';
      if(gate !== this.lastGate)PinmonyRuntimeLog.info('InboxUnreadTrace: blocked reason=' + gate);
      this.lastGate = gate; this.pause(); return;
    }
    this.lastGate = '';
    await Promise.all([PIN_NATIVE_INBOX_MESSAGES_ENABLED ? this.readIfDue(false,session) : Promise.resolve(),
      PIN_NATIVE_INBOX_UPDATES_ENABLED ? this.readIfDue(true,session) : Promise.resolve()]);
  }
  private async readIfDue(updates: boolean, session: PinmonyBusinessSessionContext): Promise<void> {
    const kind: string = updates ? 'updates' : 'messages';
    const interval: number = updates ? PIN_INBOX_UPDATES_POLL_MS : PIN_INBOX_MESSAGES_POLL_MS;
    const previous: number | undefined = this.lastPoll.get(kind);
    if(this.jobs.has(kind) || previous !== undefined && Date.now() - previous < interval)return;
    this.lastPoll.set(kind,Date.now());
    await this.read(updates,session);
  }
  private async read(updates: boolean, captured: PinmonyBusinessSessionContext): Promise<void> {
    const revision: number = this.revision;
    const current = (): boolean => { const session: PinmonyBusinessSessionContext = this.ports.session(); return revision === this.revision && this.ports.active() && session.authenticated && session.accountId === captured.accountId && session.generation === captured.generation && session.origin === captured.origin; };
    const id: string = (updates ? 'native_inbox_updates_' : 'native_inbox_messages_') + 'unread_' + (++this.sequence).toString();
    const envelope: PinmonyUnreadEnvelope = updates ? {options:{url:'/v3/news_hub/feed/',data:{field_set_key:'unauthed'},redux_normalize_feed:true,field_sets:INBOX_UPDATE_FIELDS.slice()},context:{}} : {options:{field_set_key:'default'},context:{}};
    const data: string = JSON.stringify(envelope);
    const resource: string = updates ? 'ApiResource' : 'ConversationsResource';
    const job: PinmonyNetworkJob = {id:id,epoch:captured.generation,page:captured.origin+'/inbox/',url:captured.origin+'/resource/'+resource+'/get/?source_url='+encodeURIComponent('/inbox/')+'&data='+encodeURIComponent(data),method:'GET',body:'',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active','X-Pinterest-Source-Url':'/inbox/','X-Pinterest-Pws-Handler':'www/index.js'}};
    const kind: string = updates ? 'updates' : 'messages';
    this.jobs.set(kind,id);
    let phase: string = 'request';
    PinmonyRuntimeLog.info('InboxUnreadTrace: started kind='+(updates ? 'updates' : 'messages'));
    try {
      const reply: PinmonyNetworkReply = updates ? await this.ports.network().requestBusinessInboxUpdatesRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),current) : await this.ports.network().requestBusinessInboxMessagesRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),current);
      if(!current()){PinmonyRuntimeLog.info('InboxUnreadTrace: discarded kind='+(updates ? 'updates' : 'messages'));return;}
      if(reply.error || reply.status !== 200 || reply.body.length > 4000000)throw new Error('unread-request');
      phase = 'response-validation';
      const response: PinmonyUnreadResource = (JSON.parse(reply.body) as PinmonyUnreadResponse).resource_response;
      if(response?.status !== 'success' || response.error || response.code !== undefined && response.code !== 0 || response.endpoint_name && response.endpoint_name !== (updates ? 'v3_get_news_hub_feed' : 'v3_get_conversations') || !Array.isArray(response.data) || response.data.length > (updates ? 500 : 2000) || response.data.some((row: PinmonyUnreadRow): boolean => !row || typeof row.id !== 'string' || !row.id || row.unread !== undefined && typeof row.unread !== 'boolean' && (updates || typeof row.unread !== 'number' || !Number.isSafeInteger(row.unread) || row.unread < 0)))throw new Error('unread-response');
      const visible: PinmonyUnreadRow[] = updates ? response.data.filter((row: PinmonyUnreadRow): boolean =>
        this.ports.store().isUnseenUpdate('inbox-news-api-' + captured.generation.toString() + '-' + row.id, typeof row.last_updated_at === 'string' ? row.last_updated_at.trim().slice(0,500) : '')) : response.data.filter((row: PinmonyUnreadRow): boolean =>
        !PinmonyInboxHiddenConversations.hidden(captured.origin,captured.accountId,row.id));
      const unread: boolean = visible.some((row: PinmonyUnreadRow): boolean => row.unread === true || !updates && typeof row.unread === 'number' && row.unread > 0);
      const seen: Set<string> = new Set<string>();
      const count: number = visible.reduce((total: number, row: PinmonyUnreadRow): number => {
        if(seen.has(row.id))return total; seen.add(row.id);
        return Math.min(Number.MAX_SAFE_INTEGER, total + (typeof row.unread === 'number' ? row.unread : row.unread === true ? 1 : 0));
      }, 0);
      if(updates) { this.ports.store().inboxUpdatesUnreadCount = count; this.ports.store().inboxUpdatesUnread = unread; }
      else { this.ports.store().inboxMessagesUnreadCount = count; this.ports.store().inboxMessagesUnread = unread; }
      if(!updates)this.ports.messagesObserved?.(response.data);
      PinmonyRuntimeLog.info('InboxUnreadTrace: committed kind='+(updates ? 'updates' : 'messages')+' unread='+unread.toString());
    } catch (_) { if(current())PinmonyRuntimeLog.info('InboxUnreadTrace: retained kind='+(updates ? 'updates' : 'messages')+' stage='+phase); }
    finally { if(this.jobs.get(kind) === id)this.jobs.delete(kind); }
  }
}
