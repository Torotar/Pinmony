import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore, ShareSheetOption } from 'feature_pin';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonySharePublishClient, PinmonySharePublishClientPorts, PinmonySharePublishOwner, PinmonyBusinessRejection } from './PinmonySharePublishClient';
interface User {
    id: string;
    type?: string;
    username?: string;
    full_name?: string;
    label?: string;
    image_medium_url?: string;
    send_pin_image?: string;
    image?: string;
}
interface Message {
    id: string;
    pin?: Item;
    board?: Item;
    user?: User;
}
interface Item {
    id?: string;
    type?: string;
    username?: string;
    client_tracking_params?: string;
    tracking_params?: string;
    users?: User[];
    last_message?: Message;
    items?: User[];
}
interface Resource {
    status: string;
    code: number;
    endpoint_name?: string;
    error?: Object;
    data: Item | User[];
}
interface Response {
    resource_response?: Resource;
    data?: GraphData;
    errors?: Object[];
    client_context?: Client;
}
interface Client {
    is_authenticated?: boolean;
    user?: User;
}
interface GraphData {
    v3InviteUserExternalQuery?: Invite;
}
interface Invite {
    data?: InviteData;
}
interface InviteData {
    inviteUrl: string;
    inviteCode: string;
    title: string;
    message: string;
}
interface Suggestions {
    field_set_key?: string;
    hide_group_conversations: boolean;
    suggestion_type?: string;
}
interface Search {
    count: number;
    term: string;
    pin_scope: string;
}
interface PinRead {
    id: string;
    field_set_key: string;
}
interface UserRead {
    username: string;
    field_set_key: string;
}
interface InviteType {
    invite_category: number;
    invite_object: number;
    invite_channel: number;
}
interface Variables {
    objectId: string;
    inviteType: string;
}
interface Graph {
    queryHash: string;
    variables: Variables;
}
interface Send {
    user_ids: string[];
    emails?: string[];
    source?: string;
    client_tracking_params?: string;
    pin?: string;
    board?: string;
    user?: string;
}
export interface PinmonyShareNativePorts extends PinmonySharePublishClientPorts {
    store: () => PinmonyPinStore;
    current: (kind: string, page: string, id: string) => boolean;
    visible: () => boolean;
    show: (profile: boolean) => void;
    feedback: () => void;
    copy: (value: string) => Promise<void>;
    share: (value: string) => Promise<void>;
}
export class PinmonyShareNativeFlow {
    private readonly ports: PinmonyShareNativePorts;
    private readonly client: PinmonySharePublishClient;
    private readonly contactsClient: PinmonySharePublishClient;
    private readonly store: PinmonyPinStore;
    private revision: number = 0;
    private searchRevision: number = 0;
    private timer: number = -1;
    private session: number = 0;
    private account: string = '';
    private generation: number = -1;
    private origin: string = '';
    private page: string = '';
    private mode: string = '';
    private id: string = '';
    private tracking: string = '';
    private viewer: string = '';
    private link: string = '';
    private users: User[] = [];
    private busy: boolean = false;
    private pending: string = '';
    private unknown: Set<string> = new Set();
    private sent: Set<string> = new Set();
    constructor(ports: PinmonyShareNativePorts) { this.ports = ports; this.store = ports.store(); this.client = new PinmonySharePublishClient(ports); this.contactsClient = new PinmonySharePublishClient(ports); }
    private key(target: string): string { return JSON.stringify([this.mode, this.id, target]); }
    private current(revision: number): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return revision === this.revision && s.authenticated && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.ports.visible() && this.store.shareSession === this.session && this.ports.current(this.mode, this.page, this.id); }
    private contacts(): void { this.store.shareContacts = this.users.map((u: User): ShareSheetOption => ({ id: 'native-contact:' + u.id, label: ((u.full_name || u.label || u.username || '') + (u.username ? ' @' + u.username : '')).slice(0, 300), icon: /^https:\/\//.test(u.send_pin_image || u.image_medium_url || u.image || '') ? (u.send_pin_image || u.image_medium_url || u.image || '').slice(0, 4096) : '', enabled: !this.busy && !this.unknown.has(this.key(u.id)) && !this.sent.has(u.id) })); if (this.users.some((u: User): boolean => this.unknown.has(this.key(u.id))))
        this.store.shareError = PinmonyI18n.message("pm_send_result_not_confirmed_check_the_conversation_before_sending__cfb05238"); }
    // Cancelling a transport cannot prove that an already sent mutation was undone.
    pause(): void { if (this.busy && this.pending) {
        this.unknown.add(this.pending);
        this.store.shareFeedback = PinmonyI18n.message("pm_send_result_not_confirmed_check_the_conversation_before_sending__cfb05238");
    } this.busy = false; this.pending = ''; this.contacts(); this.revision++; this.searchRevision++; if (this.timer >= 0)
        clearTimeout(this.timer); this.timer = -1; this.client.cancel(); this.contactsClient.cancel(); if (this.store.shareLoading || PinmonyI18n.isText(this.store.shareFeedback, '正在加载联系人…')) {
        this.store.shareLoading = false;
        this.store.shareFeedback = '';
        this.store.shareError = PinmonyI18n.message("pm_share_loading_paused_please_retry_1a0f4d77");
    } const s: PinmonyBusinessSessionContext = this.ports.session(); if (!s.authenticated || s.accountId !== this.account || s.generation !== this.generation) {
        this.users = [];
        this.store.shareContacts = [];
        this.link = '';
        this.tracking = '';
    } }
    close(): void { this.pause(); this.page = ''; this.id = ''; this.users = []; this.tracking = ''; this.link = ''; this.viewer = ''; this.sent.clear(); this.store.shareContacts = []; this.store.shareOptions = []; this.store.shareActions = []; }
    private owner(): PinmonySharePublishOwner { return { page: this.page, mode: this.mode, objectId: this.id, viewer: this.viewer, contacts: this.users.map((u: User): string => u.id), boards: [] }; }
    private async request(name: string, verb: string, options: Object, revision: number, owner?: PinmonySharePublishOwner, search?: number): Promise<Response> {
        const client: PinmonySharePublishClient = name.startsWith('ShareSuggestions') ? this.contactsClient : this.client;
        const raw: string = await client.request(owner || this.owner(), name, verb, options, this.page.slice(this.origin.length), this.mode === 'pin' ? 'www/pin/[id].js' : 'www/index.js', (): boolean => this.current(revision) && (search === undefined || search === this.searchRevision));
        const p: Response = JSON.parse(raw) as Response, r: Resource | undefined = p.resource_response;
        if (name === 'graphql') {
            if (p.errors || !p.data)
                throw new Error('graph');
            return p;
        }
        if (!r || r.status !== 'success' || r.code !== 0 || r.error || p.client_context?.is_authenticated === false || this.viewer && p.client_context?.user && p.client_context.user.id !== this.viewer) {
            if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)
                throw new PinmonyBusinessRejection(PinmonyI18n.message("pm_the_website_rejected_this_send_action_bedc7ede"));
            throw new Error('resource');
        }
        return p;
    }
    async open(mode: string, page: string, id: string): Promise<boolean> {
        this.close();
        const s: PinmonyBusinessSessionContext = this.ports.session();
        if (!s.authenticated || !page.startsWith(s.origin + '/') || !['pin', 'board', 'user'].includes(mode) || mode !== 'user' && !/^\d{1,40}$/.test(id) || !this.ports.current(mode, page, id))
            return false;
        if (s.accountId !== this.account || s.generation !== this.generation || s.origin !== this.origin)
            this.unknown.clear();
        this.account = s.accountId;
        this.generation = s.generation;
        this.origin = s.origin;
        this.mode = mode;
        this.page = page;
        this.id = id;
        this.session = Math.max(this.session + 1, this.store.shareSession + 1, 1);
        this.store.shareSession = this.session;
        this.store.ignoredShareSession = 0;
        this.store.sharePin = page;
        this.store.shareOnPinDetail = mode === 'pin';
        this.store.shareTitle = PinmonyI18n.message("pm_share_7e564575");
        this.store.shareSectionLabel = mode === 'user' ? PinmonyI18n.message("pm_send_to_5cf7607a") : PinmonyI18n.message("pm_send_to_contacts_8760742d");
        this.store.shareSearchActive = true;
        this.store.shareSearchId = 'native-search';
        this.store.shareSearchLabel = PinmonyI18n.message("pm_search_people_62eb3f93");
        this.store.shareSendId = '';
        this.store.shareQuery = '';
        this.store.shareFeedback = '';
        this.store.shareError = '';
        this.store.shareLoading = true;
        this.store.shareOptions = mode === 'user' ? ['Messenger', 'WhatsApp', '短信', 'Facebook', 'X'].map((v: string): ShareSheetOption => ({ id: 'native-share:' + v, label: v === '短信' ? PinmonyI18n.message('pm_messages_4da199fa') : v, icon: '', enabled: false })) : [];
        this.store.shareActions = mode === 'user' ? [{ id: 'native-copy', label: PinmonyI18n.message("pm_copy_link_8e86f9b1"), icon: '', enabled: false }] : mode === 'pin' ? [{ id: 'native-system-share', label: PinmonyI18n.message("pm_system_share_13a1c63f"), icon: '', enabled: false }] : [];
        this.ports.show(mode !== 'pin');
        const revision: number = this.revision;
        try {
            if (mode === 'pin') {
                const options: PinRead = { id: id, field_set_key: 'auth_web_main_pin' }, p: Response = await this.request('PinResource', 'get', options, revision), d: Item = p.resource_response!.data as Item;
                if (!this.current(revision))
                    return true;
                if (d.type !== 'pin' || d.id !== id)
                    throw new Error('pin');
                this.store.shareActions = [{ id: 'native-system-share', label: PinmonyI18n.message("pm_system_share_13a1c63f"), icon: '', enabled: true }];
                this.tracking = d.client_tracking_params || d.tracking_params || '';
                if (this.tracking.length > 16384)
                    this.tracking = '';
            }
            else if (mode === 'user') {
                const options: UserRead = { username: page.slice(s.origin.length).split('/')[1], field_set_key: 'profile' }, owner: PinmonySharePublishOwner = { page: page, mode: 'create-board', objectId: '', viewer: '', contacts: [], boards: [] }, p: Response = await this.request('UserResource', 'get', options, revision, owner), d: Item = p.resource_response!.data as Item;
                if (!this.current(revision))
                    return true;
                if (d.type !== 'user' || !/^\d{1,40}$/.test(d.id || '') || d.username !== options.username || !/^\d{1,40}$/.test(p.client_context?.user?.id || ''))
                    throw new Error('user');
                this.id = d.id!;
                this.viewer = p.client_context!.user!.id;
            }
            if (!this.current(revision))
                return true;
            this.store.shareLoading = false;
            const tasks: Promise<void>[] = [this.load('', revision)];
            if (mode !== 'pin')
                tasks.push(this.invite(revision));
            await Promise.allSettled(tasks);
        }
        catch (_) {
            if (this.current(revision)) {
                this.store.shareLoading = false;
                this.store.shareError = PinmonyI18n.message("pm_unable_to_load_share_data_please_retry_0afbe6f0");
            }
        }
        return true;
    }
    private async invite(revision: number): Promise<void> {
        const type: InviteType = { invite_category: 3, invite_object: this.mode === 'board' ? 2 : 3, invite_channel: 12 }, options: Graph = { queryHash: '6312848b4bb08588587683a04a42e4d0333e2e986fcab0cef4ed200786d3f5d9', variables: { objectId: this.id, inviteType: JSON.stringify(type) } };
        try {
            const p: Response = await this.request('graphql', 'create', options, revision), data: InviteData | undefined = p.data?.v3InviteUserExternalQuery?.data;
            if (!this.current(revision))
                return;
            if (!data || !/^https:\/\/pin\.it\/[A-Za-z0-9]+\/?$/.test(data.inviteUrl) || typeof data.inviteCode !== 'string' || typeof data.title !== 'string' || typeof data.message !== 'string')
                throw new Error('invite');
            this.link = data.inviteUrl;
            this.store.shareOptions = this.store.shareOptions.map((v: ShareSheetOption): ShareSheetOption => ({ id: v.id, label: v.label, icon: v.icon, enabled: true }));
            this.store.shareActions = this.store.shareActions.map((v: ShareSheetOption): ShareSheetOption => ({ id: v.id, label: v.label, icon: v.icon, enabled: true }));
        }
        catch (_) {
            if (this.current(revision))
                this.store.shareError = PinmonyI18n.message("pm_unable_to_load_share_link_please_retry_677a539d");
        }
    }
    private async load(query: string, revision: number): Promise<void> {
        this.contactsClient.cancel();
        const search: number = ++this.searchRevision;
        this.users = [];
        this.contacts();
        this.store.shareError = '';
        this.store.shareFeedback = PinmonyI18n.message("pm_loading_contacts_6c983c5f");
        const options: Suggestions | Search = query ? { count: 25, term: query, pin_scope: this.mode === 'pin' ? 'pins' : 'users' } : this.mode === 'pin' ? { field_set_key: 'default', hide_group_conversations: true } : { suggestion_type: 'share', hide_group_conversations: false };
        try {
            const p: Response = await this.request(query ? 'ShareSuggestionsTypeaheadResource' : 'ShareSuggestionsResource', 'get', options, revision, undefined, search);
            if (!this.current(revision) || search !== this.searchRevision)
                return;
            const data: Item | User[] = p.resource_response!.data, items: User[] | undefined = query ? (data as Item)?.items : data as User[];
            if (!Array.isArray(items) || items.length > 2000)
                throw new Error('contacts');
            this.users = items.filter((u: User, i: number): boolean => !!u && /^\d{1,40}$/.test(u.id) && typeof u.username === 'string' && !!u.username && items.findIndex((v: User): boolean => v?.id === u.id) === i).slice(0, 100);
            this.contacts();
            this.store.shareFeedback = this.users.length ? '' : PinmonyI18n.message("pm_no_contacts_available_5eaa443a");
        }
        catch (_) {
            if (this.current(revision) && search === this.searchRevision) {
                this.store.shareFeedback = '';
                this.store.shareError = PinmonyI18n.message("pm_unable_to_load_contacts_please_retry_9942b99b");
            }
        }
    }
    search(value: string): void { if (!this.current(this.revision) || this.busy)
        return; this.store.shareQuery = value.slice(0, 200); const revision: number = this.revision, query: string = this.store.shareQuery.trim(); this.searchRevision++; this.contactsClient.cancel(); this.users = []; this.contacts(); this.store.shareFeedback = PinmonyI18n.message("pm_loading_contacts_6c983c5f"); if (this.timer >= 0)
        clearTimeout(this.timer); this.timer = setTimeout((): void => { this.timer = -1; if (this.current(revision))
        this.load(query, revision); }, 300); }
    async refresh(): Promise<void> { if (!this.current(this.revision) || this.busy)
        return; if (this.timer >= 0)
        clearTimeout(this.timer); this.timer = -1; if (!this.id || this.mode === 'pin' && !this.tracking) {
        await this.open(this.mode, this.page, this.id);
        return;
    } const tasks: Promise<void>[] = [this.load(this.store.shareQuery.trim(), this.revision)]; if (this.mode !== 'pin' && !this.link)
        tasks.push(this.invite(this.revision)); await Promise.allSettled(tasks); }
    async action(id: string): Promise<void> {
        const revision: number = this.revision;
        if (!this.current(revision) || this.busy)
            return;
        if (id === 'native-system-share') {
            if (this.mode !== 'pin' || !this.store.shareActions.some((v: ShareSheetOption): boolean => v.id === id && v.enabled))
                return;
            await this.ports.share(this.page);
            return;
        }
        if (id === 'native-copy' || id.startsWith('native-share:')) {
            if (this.mode !== 'user' || !this.link || !this.store.shareOptions.concat(this.store.shareActions).some((v: ShareSheetOption): boolean => v.id === id && v.enabled))
                return;
            try {
                if (id === 'native-copy')
                    await this.ports.copy(this.link);
                else
                    await this.ports.share(this.link);
                if (this.current(revision) && id === 'native-copy') {
                    this.store.shareFeedback = PinmonyI18n.message("pm_link_copied_6ce7dfa5");
                    this.ports.feedback();
                }
            }
            catch (_) {
                if (this.current(revision))
                    this.store.shareError = PinmonyI18n.message("pm_sharing_incomplete_please_retry_2a3623dc");
            }
            return;
        }
        const target: string = id.startsWith('native-contact:') ? id.slice('native-contact:'.length) : '';
        if (!this.users.some((u: User): boolean => u.id === target) || this.unknown.has(this.key(target)) || this.sent.has(target) || !this.store.shareContacts.some((v: ShareSheetOption): boolean => v.id === id && v.enabled))
            return;
        if (this.mode === 'pin' && !this.tracking) {
            this.store.shareError = PinmonyI18n.message("pm_send_details_missing_for_this_pin_reopen_sharing_b785bbba");
            return;
        }
        const options: Send = { user_ids: [target] };
        if (this.mode === 'pin') {
            options.emails = [];
            options.source = 'Unknown';
            options.client_tracking_params = this.tracking;
            options.pin = this.id;
        }
        else if (this.mode === 'board')
            options.board = this.id;
        else
            options.user = this.id;
        this.busy = true;
        this.pending = this.key(target);
        this.store.shareError = '';
        this.store.shareFeedback = PinmonyI18n.message("pm_processing_574ec751");
        this.contacts();
        try {
            const p: Response = await this.request('ConversationsResource', 'create', options, revision);
            if (!this.current(revision))
                return;
            const r: Resource = p.resource_response!, d: Item = r.data as Item, m: Message | undefined = d?.last_message;
            if (r.endpoint_name !== 'v3_create_conversation' || d?.id !== undefined && !/^\d{1,40}$/.test(d.id) || !Array.isArray(d.users) || !d.users.some((u: User): boolean => u.id === target) || !m || !/^\d{1,40}$/.test(m.id) || (this.mode === 'pin' ? m.pin?.id !== this.id : this.mode === 'board' ? m.board?.id !== this.id : m.user !== undefined && m.user.id !== this.id))
                throw new Error('unconfirmed');
            this.sent.add(target);
            this.store.shareFeedback = PinmonyI18n.message("pm_sent_60823aae");
            PinmonyRuntimeLog.info('ShareNative: outcome=confirmed');
            this.ports.feedback();
        }
        catch (error) {
            if (this.current(revision)) {
                if (error instanceof PinmonyBusinessRejection) {
                    this.store.shareFeedback = '';
                    this.store.shareError = PinmonyI18n.message("pm_the_website_rejected_this_send_action_bedc7ede");
                }
                else {
                    this.unknown.add(this.key(target));
                    this.store.shareFeedback = PinmonyI18n.message("pm_send_result_not_confirmed_check_the_conversation_before_sending__cfb05238");
                }
                PinmonyRuntimeLog.info('ShareNative: outcome=' + (error instanceof PinmonyBusinessRejection ? 'rejected' : 'unknown'));
            }
        }
        finally {
            if (revision === this.revision) {
                this.busy = false;
                this.pending = '';
                this.contacts();
            }
        }
    }
}
