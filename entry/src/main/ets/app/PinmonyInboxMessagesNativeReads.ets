import { PinmonyInboxStore, PinmonyInboxSnapshot, PinmonyInboxItem, PinmonyInboxFlowSnapshot, InboxFlowUser, InboxFlowMessage, InboxFlowBoard } from 'feature_inbox';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyInboxNativeWrites, PinmonyInboxWriteIdentity, PinmonyInboxWriteMessage } from './PinmonyInboxNativeWrites';
export const PIN_NATIVE_INBOX_MESSAGES_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface RawUser { id: string; username?: string; full_name?: string; image_medium_url?: string; image_large_url?: string; image_small_url?: string; type?: string; pin_thumbnail_urls?: string[]; recent_pin_images?: Record<string,RawImage[]>; }
interface RawImage { url?: string; width?: number; height?: number; }
interface RawPin { id?: string; images?: Record<string,RawImage>; }
interface RawBoard { id?: string; name?: string; url?: string; cover_images?: Record<string,RawImage>; pin_thumbnail_urls?: string[]; image_cover_hd_url?: string; image_cover_url?: string; image_thumbnail_url?: string; pin_count?: number; section_count?: number; }
interface RawMessage { user?: RawUser; id: string; text?: string; sender?: RawUser; created_at?: string; pin?: RawPin; board?: RawBoard; deleted_by?: Object; reactions?: Record<string,string>[]; }
interface RawConversation { id: string; name?: string; users: RawUser[]; last_message?: RawMessage; unread?: boolean; }
interface ReadOptions { field_set_key?: string | string[]; hide_group_conversations?: boolean; count?: number; term?: string; pin_scope?: string; url?: string; data?: ReadFields; conversation_id?: string; page_size?: number; refresh?: boolean; hide_sys_msg?: boolean; bookmarks?: string[]; }
interface ReadFields { fields: string[]; }
interface ReadEnvelope { options: ReadOptions; context: Record<string,string>; }
interface ReadResource { status: string; code?: number; error?: Object; endpoint_name?: string; data: Object; bookmark?: string; }
interface ReadBody { client_context?: InboxClientContext; resource_response: ReadResource; resource?: ReadEnvelope; }
interface InboxClientContext { user?: RawUser; }
interface TypeaheadData { items: RawUser[]; }
interface NativeContact extends PinmonyInboxItem { userId: string; username: string; }
export interface PinmonyInboxMessagesNativeReadsPorts {
  username?: () => string;
  store: () => PinmonyInboxStore;
  session: () => PinmonyBusinessSessionContext;
  page: () => string;
  active: () => boolean;
  network: () => PinmonyNativeNetwork;
  settled: () => void;
}
// Reads are owned by the account and native route. The document is used only to adopt a write context.
export class PinmonyInboxMessagesNativeReads {
  private readonly ports: PinmonyInboxMessagesNativeReadsPorts;
  private readonly store: PinmonyInboxStore;
  private section: string = '';
  private account: string = '';
  private viewer: string = '';
  private origin: string = '';
  private generation: number = -1;
  private page: string = '';
  private revision: number = 0;
  private flowRevision: number = 0;
  private sequence: number = 0;
  private listBusy: boolean = false;
  private contactsBusy: boolean = false;
  private flowBusy: boolean = false;
  private listReady: boolean = false;
  private contactsReady: boolean = false;
  private listError: string = '';
  private contactsError: string = '';
  private conversations: RawConversation[] = [];
  private rows: PinmonyInboxItem[] = [];
  private contacts: NativeContact[] = [];
  private flow: PinmonyInboxFlowSnapshot | undefined = undefined;
  private chat: PinmonyInboxFlowSnapshot | undefined = undefined;
  private cursor: string = '';
  private query: string = '';
  private readonly jobs: Map<string,string> = new Map<string,string>();
  private readonly writes: PinmonyInboxNativeWrites;
  private writePreparing: boolean = false;
  private blockSequence: number = 0;
  private readonly knownBlocks: Map<string,boolean> = new Map<string,boolean>();
  private readonly uncertainBlocks: Set<string> = new Set<string>();
  private readonly uncertainCreations: Set<string> = new Set<string>();
  constructor(ports: PinmonyInboxMessagesNativeReadsPorts) {
    this.ports = ports;this.store = ports.store();
    this.writes = new PinmonyInboxNativeWrites({
      state: (): PinmonyInboxFlowSnapshot | undefined => this.flow,
      identity: (): PinmonyInboxWriteIdentity | undefined => this.ownsFlow() && this.flow && /^\d{1,40}$/.test(this.viewer) ?
        {page:this.page,viewerId:this.viewer,token:this.flow.nativeToken || 0,screen:this.flow.screen,conversationId:this.flow.conversationId || '',
          contacts:this.flow.users.filter((u: InboxFlowUser): boolean => !u.self && u.id !== this.viewer).map((u: InboxFlowUser): string => u.id),selectedIds:this.flow.selectedIds.slice(),
          messages:this.flow.messages.map((m: InboxFlowMessage): PinmonyInboxWriteMessage =>
            ({id:m.id,own:m.own && m.sender?.id === this.viewer,deleted:m.deleted === true,reactable:!m.profile && !m.board}))} : undefined,
      session: (): PinmonyBusinessSessionContext => this.ports.session(),network: (): PinmonyNativeNetwork => this.ports.network(),
      changed: (flow: PinmonyInboxFlowSnapshot): void => {
        this.flow = flow;
        if(flow.writeUncertain && (flow.writeAction === 'blockUser' || flow.writeAction === 'unblockUser') && flow.writeTarget)this.uncertainBlocks.add(flow.writeTarget);
        if(flow.writeUncertain && flow.writeAction === 'next' && flow.writeTarget)this.uncertainCreations.add(flow.writeTarget);
        this.publish(true);
      },
      confirmed: (action: string,value: string,data: string): void => this.writeConfirmed(action,value,data)
    });
  }
  selected(): boolean { return PIN_NATIVE_INBOX_MESSAGES_ENABLED && (this.section === 'messages' || !this.section && (!this.store.inbox || this.store.inbox.section === 'messages')); }
  eligible(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.selected() && s.authenticated && !!s.accountId && this.ports.page().startsWith(s.origin + '/') && /^\/(?:inbox|messages|updates|notifications)\/$/.test(this.ports.page().slice(s.origin.length)); }
  owned(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.eligible() && this.ports.active() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.ports.page() === this.page; }
  ownsFlow(): boolean { return this.owned() && !!this.flow && !this.store.flowDismissed && this.store.inboxFlow?.nativeToken === this.flow.nativeToken; }
  private bind(): boolean {
    if (!this.eligible() || !this.ports.active()) return false;
    const s: PinmonyBusinessSessionContext = this.ports.session();
    if (this.account !== s.accountId || this.origin !== s.origin || this.generation !== s.generation || this.page !== this.ports.page()) {
      this.reset(); this.section = 'messages'; this.account = s.accountId; this.origin = s.origin; this.generation = s.generation; this.page = this.ports.page();
    }
    if(this.flow && !this.store.inboxFlow && !this.store.retainedChat) {
      this.flowRevision++; this.cancel('flow'); this.flow = undefined; this.chat = undefined; this.flowBusy = false; this.cursor = '';
    }
    return true;
  }
  private cancel(kind: string): void { const id: string = this.jobs.get(kind) || ''; if(id) this.ports.network().cancel(id); this.jobs.delete(kind); }
  pause(): void {
    this.writes.pause();this.writePreparing = false;this.revision++; this.flowRevision++; this.jobs.forEach((id: string): void => this.ports.network().cancel(id)); this.jobs.clear();
    this.listBusy = false; this.contactsBusy = false; this.flowBusy = false; this.store.inboxNativeMessagesReady = false;
    if(this.flow?.loading) { this.flow.loading = false; this.flow.error = '读取已暂停，请重试'; this.publish(); }
  }
  reset(): void {
    this.pause(); if(this.account) { this.store.inboxCache.clear(); if(this.store.inbox?.section === 'messages')this.store.inbox = undefined; if(this.flow?.nativeToken === this.store.inboxFlow?.nativeToken)this.store.inboxFlow = undefined; }
    this.section = ''; this.account = ''; this.viewer = ''; this.origin = ''; this.generation = -1; this.page = ''; this.listReady = false; this.contactsReady = false;
    this.blockSequence = 0;this.knownBlocks.clear();this.uncertainBlocks.clear();this.uncertainCreations.clear();this.rows = []; this.contacts = []; this.conversations = []; this.flow = undefined; this.chat = undefined; this.cursor = ''; this.query = ''; this.listError = ''; this.contactsError = '';
  }
  async select(section: string): Promise<boolean> {
    if(!PIN_NATIVE_INBOX_MESSAGES_ENABLED || !this.ports.session().authenticated || !this.ports.active())return false;
    if(section !== 'messages') { this.section = section; this.pause(); return false; }
    if(this.store.inbox && this.store.inbox.section !== section)this.store.inboxCache.put(this.store.inbox,this.store.inboxScrollOffset);
    this.section = section; if(!this.bind())return true;
    this.store.inboxScrollOffset = this.store.inboxCache.get(this.page,section)?.scrollOffset || 0;
    this.apply(); await this.demand(); return true;
  }
  apply(): void {
    if(!this.owned())return;
    const snapshot: PinmonyInboxSnapshot = {kind:'state',session:this.store.inboxSession,pageUrl:this.page,section:'messages',updateLabel:'更新',inboxLabel:'收件箱',messagesLabel:'消息',readLabel:'已读',unreadLabel:'未读',emptyTitle:this.listReady && !this.rows.length ? '开始对话' : '',emptyDescription:this.listReady && !this.rows.length ? '你的对话会显示在此处。' : '',homeLabel:'',homeId:'',composeLabel:'新消息',composeId:'compose',contactsLabel:'联系人',items:this.rows,contacts:this.contacts,dataSource:'api',contactsDataSource:'api',contactsLoading:this.contactsBusy && !this.contactsReady,contactsError:this.contactsError,apiError:this.listError,hasMore:false};
    this.store.inbox = snapshot; this.store.inboxUrl = this.page; this.store.inboxSectionReady = true; this.store.inboxNativeMessagesReady = this.listReady;
    this.store.inboxLoading = !this.listReady && this.listBusy; this.store.inboxError = this.listError; this.store.inboxWebFlow = false; this.store.pendingInboxSection = ''; this.store.restoringInboxSection = '';
    if(this.listReady && !this.listBusy && !this.listError)this.store.inboxCache.put(snapshot,this.store.inboxScrollOffset);
  }
  async demand(): Promise<void> { if(!this.bind())return; this.apply(); if(this.flow){ if(this.ownsFlow() && this.flow.error && !this.flow.writeUncertain && !this.flow.sending && !this.flow.messageBusy)await this.action('retry',''); return; } await Promise.all([this.listReady || this.listBusy ? Promise.resolve() : this.readList(false),this.contactsReady || this.contactsBusy ? Promise.resolve() : this.readContacts()]); }
  async refresh(): Promise<void> { if(this.bind() && !this.flow)await Promise.all([this.listBusy ? Promise.resolve() : this.readList(false),this.contactsBusy ? Promise.resolve() : this.readContacts()]); }
  async refreshContacts(): Promise<void> { if(this.bind() && !this.contactsBusy && !this.flow)await this.readContacts(); }
  async poll(): Promise<void> { if(!this.bind())return; if(this.flow){if(this.ownsFlow() && this.flow.screen === 'chat' && !this.flowBusy && !this.flow.sending && !this.flow.messageBusy && !this.flow.sendError && !this.flow.error && !this.flow.writeUncertain)await this.readMessages(false,true);}else if(this.listReady && !this.listBusy)await this.readList(true); }
  private clean(value: string | undefined): string { return typeof value === 'string' ? value.trim().slice(0,500) : ''; }
  private image(value: string | undefined): string { if(typeof value !== 'string' || value.length > 2048)return ''; return /^https:\/\/[^/@?#]+\//.test(value) ? value : ''; }
  private self(raw: RawUser | undefined): boolean {
    if(!raw)return false;
    const username: string = this.ports.username?.() || '';
    const matches: boolean = username ? this.clean(raw.username).toLowerCase() === username.toLowerCase() : raw.id === this.account;
    if(matches && /^\d{1,40}$/.test(raw.id))this.viewer = raw.id;
    return matches || !!this.viewer && raw.id === this.viewer;
  }
  private user(raw: RawUser): InboxFlowUser {
    if(!raw || typeof raw.id !== 'string' || !/^\d{1,40}$/.test(raw.id))throw new Error('user-format');
    const known: RawUser | undefined = this.conversations.flatMap((conversation: RawConversation): RawUser[] => conversation.users).find((user: RawUser): boolean => user.id === raw.id && !!user.username);
    const username: string = this.clean(raw.username) || this.clean(known?.username);
    return {id:raw.id,self:this.self(raw),name:this.clean(raw.full_name) || username,avatar:this.image(raw.image_medium_url || raw.image_large_url || raw.image_small_url),profileUrl:/^[a-zA-Z0-9_]+$/.test(username) ? this.origin + '/' + username + '/' : ''};
  }
  private board(raw: RawBoard | undefined): InboxFlowBoard | undefined {
    if(!raw || typeof raw.id !== 'string' || !/^\d{1,40}$/.test(raw.id))return undefined;
    let target: string = ''; const path: string = typeof raw.url === 'string' ? raw.url.replace(this.origin,'') : '';
    if(/^\/[^/?#]+\/[^/?#]+\/?$/.test(path) && !/^\/(?:_|pin|users|search|ideas|today|settings|messages|inbox|login|signup|business|explore)(?:\/|$)/i.test(path) && !/\/(?:_|followers|following)\/?$/.test(path))target = this.origin + path.replace(/\/$/,'') + '/';
    const images: string[] = Array.isArray(raw.pin_thumbnail_urls) ? raw.pin_thumbnail_urls.slice(0,3).map((v: string): string => this.image(v)).filter((v: string): boolean => !!v) : [];
    return {id:raw.id,title:this.clean(raw.name),url:target,images:images,cover:this.image(raw.cover_images?.['400x300']?.url) || this.image(raw.image_cover_hd_url || raw.image_cover_url || raw.image_thumbnail_url) || images[0] || '',pinCount:Number.isSafeInteger(raw.pin_count) && (raw.pin_count || 0) >= 0 ? raw.pin_count : undefined,sectionCount:Number.isSafeInteger(raw.section_count) && (raw.section_count || 0) >= 0 ? raw.section_count : undefined};
  }
  private profilePreview(raw: RawUser | undefined): string[] {
    if (!raw) return [];
    const recent: Record<string,RawImage[]> = raw.recent_pin_images || {} as Record<string,RawImage[]>;
    const sizes: string[] = Object.keys(recent).filter((key: string): boolean => /^\d+x$/.test(key)).sort((a: string,b: string): number => parseInt(b) - parseInt(a));
    for (const size of sizes) {
      const images: RawImage[] | undefined = raw.recent_pin_images?.[size]; if (!Array.isArray(images)) continue;
      const urls: string[] = images.slice(0,2).map((img: RawImage): string => this.image(img.url)).filter((url: string): boolean => /^https:\/\/i\.pinimg\.com\//.test(url));
      if (urls.length) return urls;
    }
    return (raw.pin_thumbnail_urls || []).slice(0,2).map((url: string): string => this.image(url)).filter((url: string): boolean => /^https:\/\/i\.pinimg\.com\//.test(url));
  }
  private message(raw: RawMessage): InboxFlowMessage {
    if(!raw || typeof raw.id !== 'string' || !/^\d{1,40}$/.test(raw.id) || !Number.isFinite(Date.parse(raw.created_at || '')))throw new Error('message-format');
    const imgs: Record<string,RawImage> | undefined = raw.pin?.images; const img: RawImage | undefined = imgs?.['236x'] || imgs?.['474x'] || imgs?.['736x'] || imgs?.['orig'];
    const reactions: string[] = []; if(Array.isArray(raw.reactions))raw.reactions.forEach((group: Record<string,string>): void => { if(group)Object.keys(group).forEach((id: string): void => { if(['❤️','😂','😍','😮','👍','👎'].includes(group[id]) && reactions.length < 20)reactions.push(group[id]); }); });
    const deleted: boolean = !!raw.deleted_by || raw.text === '此消息已被删除';
    return {id:raw.id,text:typeof raw.text === 'string' ? raw.text.trim().slice(0,2000) : '',image:this.image(img?.url),imageWidth:img && Number.isFinite(img.width) && (img.width || 0) > 0 ? img.width : undefined,imageHeight:img && Number.isFinite(img.height) && (img.height || 0) > 0 ? img.height : undefined,pinUrl:/^\d{1,40}$/.test(raw.pin?.id || '') ? this.origin + '/pin/' + raw.pin?.id + '/' : '',createdAt:this.clean(raw.created_at),own:this.self(raw.sender),sender:raw.sender ? this.user(raw.sender) : undefined,profile:!deleted && raw.user ? this.user(raw.user) : undefined,profileImages:deleted ? [] : this.profilePreview(raw.user),board:deleted ? undefined : this.board(raw.board),deleted:deleted,reactions:reactions};
  }
  private async request(kind: string,name: string,options: ReadOptions,endpoint: string,current: () => boolean): Promise<ReadResource> {
    const id: string = 'native_inbox_messages_' + (++this.sequence).toString(); this.cancel(kind); this.jobs.set(kind,id);
    const envelope: ReadEnvelope = {options:options,context:{}};
    const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:this.page,url:this.origin + '/resource/' + name + '/get/?source_url=' + encodeURIComponent(this.page.slice(this.origin.length)) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),method:'GET',body:'',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active','X-Pinterest-Source-Url':this.page.slice(this.origin.length),'X-Pinterest-Pws-Handler':'www/index.js'}};
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessInboxMessagesRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),current);
      if(!current())throw new Error('stale'); if(reply.error || reply.status !== 200 || reply.body.length > 4000000)throw new Error('inbox-request');
      const body: ReadBody = JSON.parse(reply.body) as ReadBody; const resource: ReadResource = body.resource_response;
      if(resource?.status !== 'success' || resource.code !== undefined && resource.code !== 0 || resource.error || endpoint && resource.endpoint_name && resource.endpoint_name !== endpoint)throw new Error('inbox-response');
      if(body.client_context?.user)this.self(body.client_context.user);
      resource.bookmark = resource.bookmark || body.resource?.options?.bookmarks?.[0] || ''; return resource;
    } finally { if(this.jobs.get(kind) === id)this.jobs.delete(kind); }
  }
  private async readList(quiet: boolean): Promise<void> {
    const revision: number = this.revision; const live = (): boolean => revision === this.revision && this.owned() && !this.flow;
    this.listBusy = true; if(!quiet)this.listError = ''; this.apply();
    try {
      const resource: ReadResource = await this.request('list','ConversationsResource',{field_set_key:'default'},'v3_get_conversations',live);
      const data: RawConversation[] = resource.data as RawConversation[]; if(!Array.isArray(data) || data.length > 2000)throw new Error('list-format');
      const ids: Set<string> = new Set<string>(); const rows: PinmonyInboxItem[] = []; const conversations: RawConversation[] = [];
      data.forEach((c: RawConversation): void => {
        if(!c || typeof c.id !== 'string' || !/^\d{1,40}$/.test(c.id) || !Array.isArray(c.users) || c.users.length > 1000)throw new Error('conversation-format');
        const users: InboxFlowUser[] = c.users.map((u: RawUser): InboxFlowUser => this.user(u)).filter((u: InboxFlowUser): boolean => !u.self);
        if(ids.has(c.id))return; ids.add(c.id); conversations.push(c); const last: RawMessage | undefined = c.last_message; const date: Date = new Date(last?.created_at || '');
        rows.push({id:'conversation:' + c.id,title:(users.length === 1 ? users[0].name : this.clean(c.name)) || users.map((u: InboxFlowUser): string => u.name).join('、') || '消息',outgoing:this.self(last?.sender),subtitle:this.clean(last?.text) || (last?.user ? (this.self(last.sender) ? '你发送了一份个人资料' : '发送了一份个人资料') : last?.board ? (this.self(last.sender) ? '你发送了一个图板' : '发送了一个图板') : last?.pin ? (this.self(last.sender) ? '你发送了一张 Pin 图' : '发送了一张 Pin 图') : ''),profileUrl:users.length === 1 ? users[0].profileUrl : '',imageUrl:users[0]?.avatar || '',enabled:true,unread:!!c.unread,timeLabel:Number.isFinite(date.getTime()) ? date.getHours().toString().padStart(2,'0') + ':' + date.getMinutes().toString().padStart(2,'0') : ''});
      });
      if(!live())return; this.rows = rows; this.conversations = conversations; this.listReady = true; this.listError = '';
      PinmonyRuntimeLog.info('InboxMessagesNativeTrace: list committed count=' + rows.length.toString());
    } catch (_) { if(live() && !quiet)this.listError = '消息列表读取失败，请重试'; }
    finally { if(revision === this.revision){this.listBusy = false; if(live())this.apply(); if(!this.listBusy && !this.contactsBusy)this.ports.settled();} }
  }
  private async readContacts(): Promise<void> {
    const revision: number = this.revision; const live = (): boolean => revision === this.revision && this.owned() && !this.flow;
    this.contactsBusy = true; this.contactsError = ''; this.apply();
    try {
      const resource: ReadResource = await this.request('contacts','ShareSuggestionsResource',{field_set_key:'default',hide_group_conversations:true},'v3_user_contacts_suggestion',live);
      const data: RawUser[] = resource.data as RawUser[]; if(!Array.isArray(data) || data.length > 1000)throw new Error('contacts-format');
      const ids: Set<string> = new Set<string>(); const rows: NativeContact[] = [];
      data.forEach((u: RawUser): void => { const user: InboxFlowUser = this.user(u); const username: string = this.clean(u.username); if(u.type !== 'user_share_suggestion' || !username)throw new Error('contact-format'); if(ids.has(u.id) || user.self)return; ids.add(u.id); rows.push({id:'contact:' + u.id,userId:u.id,username:username,title:user.name,subtitle:'@' + username,imageUrl:user.avatar,profileUrl:user.profileUrl,enabled:true}); });
      if(!live())return; this.contacts = rows; this.contactsReady = true;
    } catch (_) { if(live())this.contactsError = '联系人读取失败，请重试'; }
    finally { if(revision === this.revision){this.contactsBusy = false; if(live())this.apply(); this.ports.settled();} }
  }
  private newFlow(screen: string,conversation: string = ''): PinmonyInboxFlowSnapshot {
    this.writes.pause();this.writePreparing = false;this.cancel('identity');this.flowRevision++; this.cancel('flow'); this.flowBusy = false; if(screen !== 'settings')this.cursor = ''; this.store.flowDismissed = false;
    const flow: PinmonyInboxFlowSnapshot = {kind:'nativeFlow',nativeToken:this.flowRevision,session:this.store.inboxSession,pageUrl:this.page,screen:screen,title:screen === 'compose' ? '新消息' : '',loading:true,error:'',users:[],messages:[],selectedIds:[],hasMore:false,conversationId:conversation};
    this.flow = flow; this.publish(); return flow;
  }
  private publish(allowInactive: boolean = false): void {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const retained: boolean = allowInactive && session.authenticated && session.accountId === this.account && session.generation === this.generation && session.origin === this.origin && this.store.inboxFlow?.nativeToken === this.flow?.nativeToken;
    if(!this.flow || this.store.flowDismissed || !this.owned() && !retained)return;
    const flow: PinmonyInboxFlowSnapshot = this.flow;
    this.store.inboxFlow = {nativeAccountGeneration:this.generation,kind:flow.kind,pageUrl:flow.pageUrl,session:this.store.inboxSession,contextEpoch:flow.contextEpoch,
      writeUncertain:flow.writeUncertain,writeAction:flow.writeAction,writeTarget:flow.writeTarget,nativeToken:flow.nativeToken,nativeRead:flow.nativeRead,screen:flow.screen,title:flow.title,loading:flow.loading,error:flow.error,
      users:flow.users,messages:flow.messages,selectedIds:flow.selectedIds,hasMore:flow.hasMore,conversationId:flow.conversationId,
      sending:flow.sending,sentRevision:flow.sentRevision,sendError:flow.sendError,messageBusy:flow.messageBusy,
      blocked:flow.blocked,blockedUserId:flow.blockedUserId,blockRevision:flow.blockRevision};
  }
  async open(id: string): Promise<boolean> {
    if(!PIN_NATIVE_INBOX_MESSAGES_ENABLED || !this.selected() || !/^(?:compose$|conversation:\d+$|contact:\d+$)/.test(id))return false;
    if(!this.bind())return true;
    this.writes.pause();this.cancel('identity');this.writePreparing = false;
    this.cancel('list'); this.cancel('contacts'); this.revision++; this.listBusy = false; this.contactsBusy = false;
    if(id === 'compose') { this.chat = undefined; this.newFlow('compose'); await this.readCompose(''); return true; }
    if(id.startsWith('contact:')) {
      const contact: NativeContact | undefined = this.contacts.find((row: NativeContact): boolean => row.id === id); if(!contact)return true;
      const existing: RawConversation | undefined = this.conversations.find((c: RawConversation): boolean => c.users.length <= 2 && c.users.some((u: RawUser): boolean => u.id === contact.userId));
      if(existing) {this.newFlow('chat',existing.id); await this.readChat();}
      else {const flow: PinmonyInboxFlowSnapshot = this.newFlow('compose'); flow.users = [{id:contact.userId,name:contact.title,avatar:contact.imageUrl,profileUrl:contact.profileUrl,self:false}]; flow.selectedIds = [contact.userId]; flow.loading = false; this.publish();}
      return true;
    }
    const c: RawConversation | undefined = this.conversations.find((row: RawConversation): boolean => id === 'conversation:' + row.id); if(!c)return true;
    this.chat = undefined; this.newFlow('chat',c.id); await this.readChat(); return true;
  }
  async direct(id: string,name: string,avatar: string,username: string): Promise<boolean> {
    if(!this.bind() || !/^\d{1,40}$/.test(id) || id === this.account)return false;
    const existing: RawConversation | undefined = this.conversations.find((c: RawConversation): boolean => c.users.length <= 2 && c.users.some((u: RawUser): boolean => u.id === id));
    if(existing)return this.open('conversation:' + existing.id);
    const flow: PinmonyInboxFlowSnapshot = this.newFlow('compose'); flow.users = [{id:id,name:this.clean(name),avatar:this.image(avatar),self:false,profileUrl:/^[a-zA-Z0-9_]+$/.test(username) ? this.origin + '/' + username + '/' : ''}]; flow.selectedIds = [id]; flow.loading = false; this.publish(); return true;
  }
  async action(action: string,value: string): Promise<boolean> {
    if(action === 'back' && typeof this.store.inboxFlow?.nativeToken === 'number' && !this.ownsFlow()) {
      this.writes.pause();this.cancel('identity');this.writePreparing = false;this.flowRevision++; this.cancel('flow'); this.flowBusy = false;
      if(this.store.inboxFlow.screen === 'settings' && this.chat) { this.flow = this.chat; this.chat = undefined; this.flow.nativeToken = this.flowRevision; this.store.inboxFlow = this.flow; }
      else { this.flow = undefined; this.chat = undefined; this.store.flowDismissed = true; this.store.inboxFlow = undefined; this.store.retainedChat = undefined; this.store.chatReturnConversation = ''; this.store.chatScrollOffset = 0; }
      return true;
    }
    if(!this.ownsFlow() || !this.flow)return PIN_NATIVE_INBOX_MESSAGES_ENABLED && typeof this.store.inboxFlow?.nativeToken === 'number'; const flow: PinmonyInboxFlowSnapshot = this.flow;
    if(action === 'back') {
      this.writes.pause();this.cancel('identity');this.writePreparing = false;this.flowRevision++; this.cancel('flow'); this.flowBusy = false;
      if(flow.screen === 'settings' && this.chat){this.flow = this.chat; this.chat = undefined; this.flow.nativeToken = this.flowRevision; this.publish();}
      else {this.flow = undefined; this.chat = undefined; this.store.flowDismissed = true; this.store.inboxFlow = undefined; this.store.retainedChat = undefined; this.store.chatReturnConversation = ''; this.store.chatScrollOffset = 0; this.apply();}
      return true;
    }
    if(flow.sending || flow.messageBusy || this.writePreparing || this.writes.busy())return true;
    if(flow.writeUncertain) {
      if(action === 'retry')await this.recoverWrite();
      return true;
    }
    if(['send','next','react','deleteMessage','blockUser','unblockUser'].includes(action)) {
      if(flow.loading)return true;
      this.flowRevision++;flow.nativeToken = this.flowRevision;this.cancel('flow');this.flowBusy = false;this.publish();
      if(action === 'next') {
        const existing: string = this.matchConversation(flow.selectedIds,this.conversations);
        if(existing){this.newFlow('chat',existing);await this.readChat();return true;}
        const key: string = flow.selectedIds.slice().sort().join(',');
        if(this.uncertainCreations.has(key)){flow.writeUncertain = true;flow.writeAction = 'next';flow.writeTarget = key;flow.error = '会话创建结果未确认，请重新读取核对；不会重复创建';this.publish();return true;}
      }
      if((action === 'blockUser' || action === 'unblockUser') && this.uncertainBlocks.has(value)) {
        flow.writeUncertain = true;flow.writeAction = action;flow.writeTarget = value;flow.error = '屏蔽结果未确认，暂时无法核对状态；不会重复提交';this.publish();return true;
      }
      const revision: number = this.flowRevision;this.writePreparing = true;
      try {if(/^\d{1,40}$/.test(this.viewer))await this.writes.submit(action,value);else if(await this.ensureWriteIdentity())await this.writes.submit(action,value);}
      finally {if(revision === this.flowRevision)this.writePreparing = false;}
      return true;
    }
    if(action === 'settings' && flow.screen === 'chat' && !flow.loading){this.chat = flow; const settings: PinmonyInboxFlowSnapshot = this.newFlow('settings'); settings.title = '消息设置'; settings.users = flow.users;settings.conversationId = flow.conversationId; settings.blockedUserId = flow.users.find((u: InboxFlowUser): boolean => !u.self)?.id || ''; settings.blocked = this.knownBlocks.get(settings.blockedUserId) === true; settings.blockRevision = 0;
      if(this.uncertainBlocks.has(settings.blockedUserId)){settings.writeUncertain = true;settings.error = '屏蔽结果未确认，暂时无法核对状态；不会重复提交';} settings.loading = false; this.publish(); return true;}
    if(action === 'select' && flow.screen === 'compose' && !flow.loading){if(flow.users.some((u: InboxFlowUser): boolean => u.id === value && !u.self))flow.selectedIds = flow.selectedIds.includes(value) ? flow.selectedIds.filter((id: string): boolean => id !== value) : flow.selectedIds.concat([value]); this.publish(); return true;}
    if(action === 'search' && flow.screen === 'compose'){await this.readCompose(value.trim().slice(0,500)); return true;}
    if(action === 'more' && flow.screen === 'chat'){if(flow.hasMore && !this.flowBusy)await this.readMessages(true,false); return true;}
    if(action === 'retry'){if(flow.screen === 'chat')await this.readChat(); else if(flow.screen === 'compose')await this.readCompose(this.query); return true;}
    return true;
  }
  private matchConversation(ids: string[], rows: RawConversation[]): string {
    if(!ids.length || !ids.every((id: string,index: number): boolean => /^\d{1,40}$/.test(id) && id !== this.viewer && ids.indexOf(id) === index))return '';
    const conversation: RawConversation | undefined = rows.find((c: RawConversation): boolean => {
      if(!c || !/^\d{1,40}$/.test(c.id) || !Array.isArray(c.users))return false;
      const peers: string[] = c.users.filter((u: RawUser): boolean => u?.id !== this.viewer && !this.self(u)).map((u: RawUser): string => u.id);
      return peers.length === ids.length && peers.every((id: string,index: number): boolean => ids.includes(id) && peers.indexOf(id) === index);
    });return conversation?.id || '';
  }
  private async ensureWriteIdentity(): Promise<boolean> {
    if(/^\d{1,40}$/.test(this.viewer))return true;
    const flow: PinmonyInboxFlowSnapshot | undefined = this.flow, revision: number = this.flowRevision;if(!flow)return false;
    const live = (): boolean => revision === this.flowRevision && this.ownsFlow() && this.flow === flow;
    flow.loading = true;flow.error = '';this.publish();
    try {
      const r: ReadResource = await this.request('identity','ConversationsResource',{field_set_key:'default'},'v3_get_conversations',live);
      const rows: RawConversation[] = r.data as RawConversation[];if(!Array.isArray(rows) || rows.length > 2000)throw new Error('identity');
      rows.forEach((c: RawConversation): void => {if(!Array.isArray(c.users) || c.users.length > 1000)throw new Error('users');c.users.forEach((u: RawUser): void => {this.self(u);});});
      if(!live() || !/^\d{1,40}$/.test(this.viewer))throw new Error('identity');return true;
    }catch (_) {if(live())flow.error = '当前账号身份尚未确认，请重新读取后再操作';return false;}
    finally {if(live()){flow.loading = false;this.publish();}}
  }
  private writeConfirmed(action: string,value: string,raw: string): void {
    if(!this.ownsFlow() || !this.flow)return;
    const flow: PinmonyInboxFlowSnapshot = this.flow;
    this.listReady = false;this.cancel('list');this.revision++;
    flow.writeUncertain = false;flow.error = '';flow.sendError = '';
    if(action === 'next') {
      const data: RawConversation = JSON.parse(raw) as RawConversation;this.uncertainCreations.delete(flow.writeTarget || '');
      this.chat = undefined;this.newFlow('chat',data.id);this.readChat();return;
    }
    if(action === 'send') {
      const data: RawMessage = JSON.parse(raw) as RawMessage, message: InboxFlowMessage = this.message(data);
      flow.messages = flow.messages.filter((m: InboxFlowMessage): boolean => m.id !== message.id).concat([message]).sort((a: InboxFlowMessage,b: InboxFlowMessage): number => Date.parse(a.createdAt) - Date.parse(b.createdAt)).slice(-2000);
      flow.sentRevision = (flow.sentRevision || 0) + 1;this.publish();return;
    }
    if(action === 'blockUser' || action === 'unblockUser') {
      flow.blocked = action === 'blockUser';flow.blockedUserId = value;flow.blockRevision = ++this.blockSequence;this.knownBlocks.set(value,flow.blocked);
      this.publish();return;
    }
    if(action === 'deleteMessage') {
      const id: string = flow.writeTarget || '';
      flow.messages = flow.messages.map((message: InboxFlowMessage): InboxFlowMessage => {
        if(message.id !== id)return message;
        const deleted: InboxFlowMessage = JSON.parse(JSON.stringify(message)) as InboxFlowMessage;
        deleted.text = '此消息已被删除';deleted.deleted = true;deleted.image = '';deleted.pinUrl = '';deleted.board = undefined;deleted.profile = undefined;deleted.profileImages = [];deleted.reactions = [];return deleted;
      });
    }
    this.publish();this.readMessages(false,true);
  }
  private async recoverWrite(): Promise<void> {
    const flow: PinmonyInboxFlowSnapshot | undefined = this.flow;if(!flow || !this.ownsFlow() || this.flowBusy)return;
    if(flow.screen === 'settings'){flow.error = '屏蔽结果未确认，暂时无法核对状态；不会重复提交';this.publish();return;}
    if(flow.screen === 'chat') {
      await this.readChat();
      if(this.ownsFlow() && this.flow === flow && !flow.error){flow.writeUncertain = false;flow.sendError = '';this.publish();}
      return;
    }
    if(flow.screen !== 'compose')return;
    const revision: number = this.flowRevision;const live = (): boolean => revision === this.flowRevision && this.ownsFlow() && this.flow === flow;
    flow.loading = true;this.flowBusy = true;this.publish();
    try {
      const r: ReadResource = await this.request('flow','ConversationsResource',{field_set_key:'default'},'v3_get_conversations',live);
      const rows: RawConversation[] = r.data as RawConversation[];if(!Array.isArray(rows) || rows.length > 2000)throw new Error('conversations');
      rows.forEach((c: RawConversation): void => {if(!c || !/^\d{1,40}$/.test(c.id) || !Array.isArray(c.users) || c.users.length > 1000)throw new Error('conversation');c.users.forEach((u: RawUser): void => {this.user(u);});});
      const id: string = this.matchConversation(flow.selectedIds,rows);if(!live())return;
      if(id){this.uncertainCreations.delete(flow.writeTarget || '');this.newFlow('chat',id);this.readChat();return;}
      flow.error = '未找到可确认的会话，请稍后重新读取；不会重复创建';
    }catch (_) {if(live())flow.error = '会话结果仍未确认，请稍后重新读取；不会重复创建';}
    finally {if(live()){this.flowBusy = false;flow.loading = false;this.publish();}}
  }
  private async readChat(): Promise<void> {
    if(!this.ownsFlow() || !this.flow || this.flowBusy)return; const flow: PinmonyInboxFlowSnapshot = this.flow; const revision: number = this.flowRevision;
    const live = (): boolean => revision === this.flowRevision && this.ownsFlow() && this.flow === flow;
    flow.loading = true; flow.error = ''; this.flowBusy = true; this.publish();
    try {
      const resource: ReadResource = await this.request('flow','ApiResource',{url:'/v3/conversations/' + flow.conversationId + '/',data:{fields:CONVERSATION_FIELDS.slice()}},'v3_get_conversation',live);
      const data: RawConversation = resource.data as RawConversation; if(!data || data.id !== flow.conversationId || !Array.isArray(data.users) || data.users.length > 1000)throw new Error('chat-format');
      const users: InboxFlowUser[] = data.users.map((u: RawUser): InboxFlowUser => this.user(u)); if(!live())return;
      flow.users = users; const peers: InboxFlowUser[] = users.filter((u: InboxFlowUser): boolean => !u.self); flow.title = (peers.length === 1 ? peers[0].name : this.clean(data.name)) || peers.map((u: InboxFlowUser): string => u.name).join('、'); this.flowBusy = false;
      await this.readMessages(false,false);
    } catch (_) { if(live()){flow.loading = false; flow.error = '会话读取失败，请重试'; this.publish();} }
    finally { if(revision === this.flowRevision)this.flowBusy = false; }
  }
  private async readMessages(append: boolean,quiet: boolean): Promise<void> {
    if(!this.ownsFlow() || !this.flow || this.flowBusy)return; const flow: PinmonyInboxFlowSnapshot = this.flow; const revision: number = this.flowRevision; const previous: string = this.cursor;
    const live = (): boolean => revision === this.flowRevision && this.ownsFlow() && this.flow === flow;
    this.flowBusy = true; if(!quiet){flow.loading = true; flow.error = ''; this.publish();}
    const options: ReadOptions = {conversation_id:flow.conversationId,page_size:25,refresh:false,hide_sys_msg:true,field_set_key:['default_with_reactions_and_deleted_by']}; if(append)options.bookmarks = [previous];
    try {
      const resource: ReadResource = await this.request('flow','ConversationMessagesResource',options,'v3_get_conversation_messages',live);
      const data: RawMessage[] = resource.data as RawMessage[]; if(!Array.isArray(data) || data.length > 500)throw new Error('messages-format');
      const fresh: InboxFlowMessage[] = data.map((m: RawMessage): InboxFlowMessage => this.message(m));
      const cursor: string = typeof resource.bookmark === 'string' && resource.bookmark.length <= 4096 ? resource.bookmark : '';
      const oldest: number = fresh.length ? Math.min(...fresh.map((m: InboxFlowMessage): number => Date.parse(m.createdAt))) : Infinity;
      const older: InboxFlowMessage[] = append ? flow.messages : cursor && cursor !== '-end-' ? flow.messages.filter((m: InboxFlowMessage): boolean => Date.parse(m.createdAt) < oldest) : [];
      const merged: Map<string,InboxFlowMessage> = new Map<string,InboxFlowMessage>(); older.forEach((m: InboxFlowMessage): void => {merged.set(m.id,m);}); fresh.forEach((m: InboxFlowMessage): void => {merged.set(m.id,m);});
      if(!live())return; flow.messages = Array.from(merged.values()).sort((a: InboxFlowMessage,b: InboxFlowMessage): number => Date.parse(a.createdAt) - Date.parse(b.createdAt)).slice(-2000);
      if(!quiet || !previous){this.cursor = cursor; flow.hasMore = !!cursor && cursor !== '-end-' && cursor !== (append ? previous : '') && !!fresh.length && flow.messages.length < 2000;}
      if(!quiet){flow.sendError = ''; flow.loading = false;} flow.error = ''; this.publish();
      PinmonyRuntimeLog.info('InboxMessagesNativeTrace: chat committed append=' + append.toString() + ' count=' + flow.messages.length.toString());
    } catch (_) { if(live() && !quiet){flow.loading = false; flow.error = '会话消息读取失败，请重试'; this.publish();} }
    finally { if(revision === this.flowRevision)this.flowBusy = false; }
  }
  private async readCompose(query: string): Promise<void> {
    if(!this.ownsFlow() || !this.flow)return; const flow: PinmonyInboxFlowSnapshot = this.flow;
    const revision: number = ++this.flowRevision; flow.nativeToken = revision; this.query = query; this.flowBusy = true; this.cancel('flow'); flow.loading = true; flow.error = ''; this.publish();
    const live = (): boolean => revision === this.flowRevision && this.ownsFlow() && this.flow === flow;
    try {
      const resource: ReadResource = await this.request('flow',query ? 'ShareSuggestionsTypeaheadResource' : 'ShareSuggestionsResource',query ? {count:25,term:query,pin_scope:'pins'} : {field_set_key:'default'},query ? '' : 'v3_user_contacts_suggestion',live);
      const data: RawUser[] = query ? (resource.data as TypeaheadData)?.items : resource.data as RawUser[]; if(!Array.isArray(data) || data.length > 1000)throw new Error('compose-format');
      const users: Map<string,InboxFlowUser> = new Map<string,InboxFlowUser>(); data.forEach((u: RawUser): void => {const user: InboxFlowUser = this.user(u); if(!user.self)users.set(user.id,user);}); if(!live())return;
      flow.users = Array.from(users.values()); flow.selectedIds = flow.selectedIds.filter((id: string): boolean => users.has(id)); flow.loading = false; this.publish();
    } catch (_) { if(live()){flow.loading = false; flow.error = '联系人读取失败，请重试'; this.publish();} }
    finally { if(revision === this.flowRevision)this.flowBusy = false; }
  }
  // Called only after the existing controller validates document epoch, page and action session.
  acceptBridge(flow: PinmonyInboxFlowSnapshot): boolean {
    if(PIN_NATIVE_INBOX_MESSAGES_ENABLED)return true;
    if(!this.ownsFlow() || !this.flow || flow.nativeToken !== this.flow.nativeToken)return true;
    if(flow.screen !== this.flow.screen && !(this.flow.screen === 'compose' && flow.screen === 'chat' && /^\d{1,40}$/.test(flow.conversationId || '')))return true;
    if(flow.screen === 'chat' && this.flow.screen === 'chat' && flow.conversationId !== this.flow.conversationId)return true;
    this.flow = flow; this.store.inboxFlow = flow;
    if(flow.nativeRead && !flow.sending && !flow.messageBusy){flow.nativeRead = false; this.flowBusy = false; if(flow.screen === 'chat')this.readChat(); else if(flow.screen === 'compose')this.readCompose(this.query);}
    return true;
  }
  installScript(): string {
    if(!this.ownsFlow() || !this.flow)return '';
    this.flow.session = this.store.inboxSession; this.publish();
    return 'window.PinmonyInboxConversations && window.PinmonyInboxConversations.installNative && window.PinmonyInboxConversations.installNative(' + JSON.stringify(this.page) + ',' + JSON.stringify(this.flow) + ',' + JSON.stringify(this.viewer) + ');';
  }
}
export const CONVERSATION_FIELDS: string[] = ['conversation.id','conversation.name','conversation.users()','conversation.read_times_ms','user.id','user.username','user.full_name','user.image_medium_url','user.type'];
