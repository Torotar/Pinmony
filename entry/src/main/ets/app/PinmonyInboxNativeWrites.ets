import { PinmonyInboxFlowSnapshot } from 'feature_inbox';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyInboxWriteMessage { id: string; own: boolean; deleted: boolean; reactable: boolean; }
export interface PinmonyInboxWriteIdentity {
  page: string; viewerId: string; token: number; screen: string; conversationId: string;
  contacts: string[]; selectedIds: string[]; messages: PinmonyInboxWriteMessage[];
}
interface SendOptions { conversation_id: string; text: string; field_set_key: string[]; }
interface CreateOptions { user_ids: string[]; emails: string[]; }
interface ReactionData { reaction_text: string; }
interface ApiOptions { url: string; data?: ReactionData; }
interface WriteEnvelope { options: SendOptions | CreateOptions | ApiOptions; context: Record<string,string>; }
interface WriteUser { id: string; }
interface WriteData { id: string; type?: string; text?: string; sender?: WriteUser; created_at?: string; conversation_id?: string; users?: WriteUser[]; }
interface WriteResource { status: string; code?: number; error?: Object; endpoint_name: string; data: WriteData | null; }
interface WriteResponse { resource_response: WriteResource; client_context?: WriteContext; }
interface WriteContext { user?: WriteUser; }
export interface PinmonyInboxNativeWritePorts {
  state: () => PinmonyInboxFlowSnapshot | undefined;
  identity: () => PinmonyInboxWriteIdentity | undefined;
  session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  changed: (flow: PinmonyInboxFlowSnapshot) => void;
  confirmed: (action: string, value: string, data: string) => void;
}

export class PinmonyInboxNativeWrites {
  private readonly ports: PinmonyInboxNativeWritePorts;
  private revision: number = 0; private sequence: number = 0; private job: string = '';
  private displayed: PinmonyInboxFlowSnapshot | undefined = undefined;
  private cancelWait: (() => void) | undefined = undefined;
  constructor(ports: PinmonyInboxNativeWritePorts) {this.ports = ports;}
  busy(): boolean {return !!this.job;}
  private clone(f: PinmonyInboxFlowSnapshot): PinmonyInboxFlowSnapshot {
    return {nativeAccountGeneration:f.nativeAccountGeneration,kind:f.kind,pageUrl:f.pageUrl,session:f.session,contextEpoch:f.contextEpoch,nativeToken:f.nativeToken,nativeRead:f.nativeRead,
      screen:f.screen,title:f.title,loading:f.loading,error:f.error,users:f.users.slice(),messages:f.messages.slice(),selectedIds:f.selectedIds.slice(),hasMore:f.hasMore,
      conversationId:f.conversationId,sending:f.sending,sentRevision:f.sentRevision,sendError:f.sendError,messageBusy:f.messageBusy,
      blocked:f.blocked,blockedUserId:f.blockedUserId,blockRevision:f.blockRevision,writeUncertain:f.writeUncertain,writeAction:f.writeAction,writeTarget:f.writeTarget};
  }
  private publish(f: PinmonyInboxFlowSnapshot): void {this.displayed = this.clone(f);this.ports.changed(this.displayed);}
  private unknown(f: PinmonyInboxFlowSnapshot): void {
    f.sending = false;f.messageBusy = false;f.loading = false;f.writeUncertain = true;
    const text: string = '操作结果未确认，请重新读取核对；不会自动重复提交';
    if(f.writeAction === 'send')f.sendError = '发送结果未确认，请重新读取会话核对；不会自动重发';else f.error = text;
    this.publish(f);PinmonyRuntimeLog.info('InboxNativeWrite: outcome=unknown');
  }
  pause(): void {
    this.revision++;
    if(this.job)this.ports.network().cancel(this.job);
    this.cancelWait?.();this.cancelWait = undefined;
    if(this.job && this.displayed && (this.displayed.sending || this.displayed.messageBusy || this.displayed.loading) && this.ports.state() === this.displayed)this.unknown(this.clone(this.displayed));
    this.job = '';this.displayed = undefined;
  }
  async submit(action: string, value: string): Promise<void> {
    const original: PinmonyInboxFlowSnapshot | undefined = this.ports.state(), identity: PinmonyInboxWriteIdentity | undefined = this.ports.identity();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(this.job || !original || !identity || !session.authenticated || !session.accountId || !/^\d{1,40}$/.test(identity.viewerId) ||
      original.loading || original.sending || original.messageBusy || original.writeUncertain || original.error || original.sendError)return;
    let options: SendOptions | CreateOptions | ApiOptions, name: string, verb: string, endpoint: string, target: string = '', submitted: string = value;
    if(action === 'send') {
      submitted = typeof value === 'string' ? value.trim() : '';
      if(identity.screen !== 'chat' || !/^\d{1,40}$/.test(identity.conversationId) || !submitted || submitted.length > 2000)return;
      options = {conversation_id:identity.conversationId,text:submitted,field_set_key:['default_with_reactions']};name = 'ConversationMessagesResource';verb = 'create';endpoint = 'v3_add_conversation_message';target = identity.conversationId;
    }else if(action === 'next') {
      const ids: string[] = identity.selectedIds;
      if(identity.screen !== 'compose' || !ids.length || ids.length > 1000 || !ids.every((id: string,index: number): boolean => /^\d{1,40}$/.test(id) && id !== identity.viewerId && ids.indexOf(id) === index && identity.contacts.includes(id)))return;
      options = {user_ids:ids.slice(),emails:[]};name = 'ConversationsResource';verb = 'create';endpoint = 'v3_create_conversation';target = ids.slice().sort().join(',');
    }else if(action === 'react' || action === 'deleteMessage') {
      const parts: string[] = typeof value === 'string' ? value.split('|') : [];
      const message: PinmonyInboxWriteMessage | undefined = identity.messages.find((m: PinmonyInboxWriteMessage): boolean => m.id === parts[0]);
      if(identity.screen !== 'chat' || !/^\d{1,40}$/.test(identity.conversationId) || !message || !/^\d{1,40}$/.test(message.id) || message.deleted ||
        action === 'deleteMessage' && (!message.own || parts.length !== 1) || action === 'react' && (!message.reactable || parts.length !== 2 || !['❤️','😂','😍','😮','👍','👎'].includes(parts[1])))return;
      options = action === 'react' ? {url:'/v3/conversations/messages/' + message.id + '/',data:{reaction_text:parts[1]}} : {url:'/v3/conversations/messages/' + message.id + '/'};
      name = 'ApiResource';verb = action === 'react' ? 'create' : 'delete';endpoint = action === 'react' ? 'v3_post_reaction_message' : 'v3_delete_conversation_message';target = message.id;
    }else if(action === 'blockUser' || action === 'unblockUser') {
      if(identity.screen !== 'settings' || !/^\d{1,40}$/.test(identity.conversationId) || !/^\d{1,40}$/.test(value) || value === identity.viewerId || !identity.contacts.includes(value) ||
        action === 'unblockUser' && (!original.blocked || original.blockedUserId !== value) || action === 'blockUser' && original.blocked && original.blockedUserId === value)return;
      options = {url:'/v3/users/' + value + '/block/'};name = 'ApiResource';verb = action === 'blockUser' ? 'update' : 'delete';endpoint = action === 'blockUser' ? 'v3_block_user' : 'v3_unblock_user';target = value;
    }else return;
    const revision: number = this.revision, state: PinmonyInboxFlowSnapshot = this.clone(original);
    const current = (): boolean => {
      const s: PinmonyBusinessSessionContext = this.ports.session(), actual: PinmonyInboxWriteIdentity | undefined = this.ports.identity();
      return revision === this.revision && s.authenticated && s.accountId === session.accountId && s.generation === session.generation && s.origin === session.origin &&
        !!actual && actual.page === identity.page && actual.viewerId === identity.viewerId && actual.token === identity.token && actual.screen === identity.screen &&
        actual.conversationId === identity.conversationId && JSON.stringify(actual.selectedIds) === JSON.stringify(identity.selectedIds) &&
        JSON.stringify(actual.contacts) === JSON.stringify(identity.contacts) && this.ports.state() === this.displayed;
    };
    const envelope: WriteEnvelope = {options:options,context:{}}, source: string = identity.page.slice(session.origin.length);
    const job: PinmonyNetworkJob = {id:'native_inbox_write_' + (++this.sequence).toString(),epoch:session.generation,page:identity.page,
      url:session.origin + '/resource/' + name + '/' + verb + '/',method:'POST',body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active','X-Pinterest-Source-Url':source,'X-Pinterest-Pws-Handler':'www/index.js'}};
    state.writeAction = action;state.writeTarget = target;state.error = '';state.sendError = '';state.writeUncertain = false;
    if(action === 'send')state.sending = true;else if(action === 'next')state.loading = true;else state.messageBusy = true;
    this.job = job.id;this.publish(state);PinmonyRuntimeLog.info('InboxNativeWrite: start action=' + action);
    const cancelled: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => {this.cancelWait = (): void => resolve(undefined);});
    try {
      const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessInboxWrite(job,(): PinmonyBusinessSessionContext => this.ports.session(),
        identity.viewerId,identity.conversationId,identity.contacts,identity.selectedIds,identity.messages.filter((m: PinmonyInboxWriteMessage): boolean => !m.deleted && m.reactable).map((m: PinmonyInboxWriteMessage): string => m.id),
        identity.messages.filter((m: PinmonyInboxWriteMessage): boolean => !m.deleted && m.own).map((m: PinmonyInboxWriteMessage): string => m.id),current),cancelled]);
      if(!current())return;
      if(!reply || reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 4000000)throw new Error('request');
      const body: WriteResponse = JSON.parse(reply.body) as WriteResponse, r: WriteResource = body.resource_response, data: WriteData | null = r?.data;
      if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0 || r.endpoint_name !== endpoint ||
        body.client_context?.user && body.client_context.user.id !== identity.viewerId)throw new Error('business');
      if(action === 'send') {
        if(!data || !/^\d{1,40}$/.test(data.id) || data.sender?.id !== identity.viewerId || data.text !== submitted || !Number.isFinite(Date.parse(data.created_at || '')) ||
          data.type !== undefined && data.type !== 'message' || data.conversation_id !== undefined && data.conversation_id !== identity.conversationId)throw new Error('message');
      }else if(action === 'next') {
        if(!data || !/^\d{1,40}$/.test(data.id))throw new Error('conversation');
        if(data.users !== undefined) {
          if(!Array.isArray(data.users) || data.users.length > 1001)throw new Error('participants');
          const peers: string[] = data.users.filter((u: WriteUser): boolean => u?.id !== identity.viewerId).map((u: WriteUser): string => u.id);
          if(peers.length !== identity.selectedIds.length || !peers.every((id: string,index: number): boolean => identity.selectedIds.includes(id) && peers.indexOf(id) === index))throw new Error('participants');
        }
      }else if(action === 'react' || action === 'deleteMessage') {
        if(!data || data.id !== target || data.conversation_id !== undefined && data.conversation_id !== identity.conversationId || action === 'deleteMessage' && data.text !== '此消息已被删除')throw new Error('message-operation');
      }else if(data !== null)throw new Error('block');
      state.sending = false;state.messageBusy = false;state.loading = false;this.publish(state);
      PinmonyRuntimeLog.info('InboxNativeWrite: outcome=confirmed action=' + action);
      this.ports.confirmed(action,submitted,JSON.stringify(data));
    }catch (_) {if(current())this.unknown(state);}
    finally {if(revision === this.revision){if(this.displayed && this.ports.state() === this.displayed && (this.displayed.sending || this.displayed.messageBusy || this.displayed.loading))this.unknown(state);this.job = '';this.displayed = undefined;this.cancelWait = undefined;}}
  }
}
