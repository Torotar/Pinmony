import { PinmonyI18n } from 'common_foundation';
import { PinmonyProfileStore, PinmonyProfilePanel, PinmonyProfilePanelItem, PinmonyProfileSnapshot, PinmonyOrganizeSnapshot, PinmonyOrganizeBoard, PIN_PROFILE_ORGANIZE_ENABLED, pickPublishPhotoUris, readProfileAvatarPhoto, PinmonyProfileAvatarPhoto } from 'feature_profile';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyProfileSettingsClient, ProfileSettingsPorts, ProfileSettingsResponse, ProfileSettingsResource, ProfileSettingsRejected } from './PinmonyProfileSettingsClient';
interface AvatarPending { account: string; tracking: string; }
let avatarSequence: number = 0;
let boardFollowSequence: number = 0;
interface BoardFollowOptions { url: string; }
interface BoardFollowEnvelope { options: BoardFollowOptions; context: Record<string, string>; }
interface BoardFollowData { id: string; type: string; followed_by_me: boolean; }
interface User {
    id: string;
    type: string;
    username: string;
    explicitly_followed_by_me?: boolean;
    blocked_by_me?: boolean;
}
interface Image {
    url: string;
}
interface Row {
    id: string;
    username?: string;
    full_name?: string;
    name?: string;
    image_medium_url?: string;
    image_cover_url?: string;
    images?: Record<string, Image[]>;
    url?: string;
    pin_count?: number;
    board_order_modified_at?: string;
    blocked_by_me?: boolean;
    explicitly_followed_by_me?: boolean;
    followed_by_me?: boolean;
}
interface Board {
    id: string;
    type: string;
    name: string;
    privacy: string;
    access: string[] | string;
    archived_by_me?: boolean;
    image_cover_hd_url?: string;
    image_cover_url?: string;
}
interface Edit {
    firstName: string;
    lastName: string;
    about: string;
    websiteUrl: string;
    username: string;
    impressumUrl?: string;
    additionalWebsiteUrls?: string[];
    pronouns?: string[];
}
interface EditData {
    first_name?: string;
    last_name?: string;
    about?: string;
    website_url?: string;
    username: string;
    profile_image_url?: string;
    id?: string;
}
interface FollowUser {
    id: string;
    entityId?: string;
    username?: string;
    fullName?: string;
    imageMediumUrl?: string;
    explicitlyFollowedByMe?: boolean;
    blockedByMe?: boolean;
    __typename?: string;
}
interface Edge {
    node: FollowUser;
}
interface Connection {
    edges: Edge[];
    pageInfo: PageInfo;
}
interface PageInfo {
    hasNextPage: boolean;
    endCursor?: string;
}
interface FollowersData {
    id: string;
    followers?: Followers;
}
interface Followers {
    connection?: Connection;
}
interface EditOutcome {
    __typename: string;
    error?: EditError;
}
interface EditError {
    message?: string;
}
interface Mutation {
    data?: FollowUser;
    v3EditSettingsHandlerResponse?: EditOutcome;
    v3UsersMeViewerResponse?: Viewer;
}
interface Viewer {
    data: FollowUser;
}
interface FollowersMutation {
    data: FollowersData;
}
interface GraphData {
    node?: FollowersData;
    v3GetUserHandlerQuery?: FollowersMutation;
    v3FollowUserMethodMutation?: Mutation;
    v3UnfollowUserMethodMutation?: Mutation;
    v3EditSettingsHandlerMutation?: Mutation;
}
interface Graph {
    queryHash: string;
    variables: Object;
}
interface Identity {
    username: string;
    field_set_key: string;
}
interface Following {
    exclude_not_explictly_followed: boolean;
    page_size: number;
    explicit_following: boolean;
    username: string;
}
interface Api {
    url: string;
    data: Object;
}
interface FollowingBoards {
    explicit_following: boolean;
    page_size: number;
    fields: string[];
}
interface Boards {
    privacy_filter: string;
    sort: string;
    field_set_key: string;
    filter_stories: boolean;
    username: string;
    page_size: number;
    group_by: string;
    include_archived: boolean;
    filter_all_pins: boolean;
    bookmarks?: string[];
}
interface BoardCreate {
    name: string;
    privacy: string;
}
interface Move {
    board_id: string;
    pin_ids: string[];
}
interface VariableUser {
    userId?: string;
    followee?: string;
    input?: Edit;
}
interface FollowersPageVariables { count: number; cursor: string; id: string; }
export interface PinmonyProfileNativeActionsPorts extends ProfileSettingsPorts {
    store: () => PinmonyProfileStore;
    active: () => boolean;
    page: () => string;
    ownPage: () => string;
    motion: () => void;
    feedback: (message: string) => void;
    saved: (page: string, username: string) => void;
    refresh: () => void;
    avatarSaved?: (page: string, avatar: string) => void;
    morePins: (action: string) => Promise<boolean>;
}
export class PinmonyProfileNativeActions {
    private readonly ports: PinmonyProfileNativeActionsPorts;
    private readonly store: PinmonyProfileStore;
    private readonly client: PinmonyProfileSettingsClient;
    private boardFollowJob: string = '';
    private boardFollowRelease: (() => void) | undefined = undefined;
    private boardFollowUnknown: Map<string, boolean> = new Map();
    private avatarPicking: boolean = false;
    private avatarJob: string = '';
    private avatarPending: AvatarPending | undefined = undefined;
    private avatarRelease: (() => void) | undefined = undefined;
    private avatarWake: (() => void) | undefined = undefined;
    private account: string = '';
    private generation: number = -1;
    private origin: string = '';
    private page: string = '';
    private revision: number = 0;
    private token: number = 0;
    private root: User | undefined = undefined;
    private followersCursor: string = '';
    private following: string = '';
    private desired: boolean = false;
    private saving: boolean = false;
    private draft: Edit | undefined = undefined;
    private confirmed: Map<string, boolean> = new Map();
    private followUnknown: Map<string, boolean> = new Map();
    private saveUnknown: Edit | undefined = undefined;
    private organizeUnknown: Set<string> = new Set();
    private createUnknown: Set<string> = new Set();
    private moveDispatched: boolean = false;
    private createName: string = '';
    private organize: PinmonyOrganizeSnapshot | undefined = undefined;
    private cursor: string = '';
    constructor(ports: PinmonyProfileNativeActionsPorts) { this.ports = ports; this.store = ports.store(); this.client = new PinmonyProfileSettingsClient(ports); }
    private current(revision: number): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return revision === this.revision && s.authenticated && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.ports.active() && this.ports.page() === this.page && this.store.panelToken === this.token; }
    private panel(): void {
        if (this.store.panel)
            this.store.panel = JSON.parse(JSON.stringify(this.store.panel)) as PinmonyProfilePanel;
    }
    private syncOrganize(): void {
        if (this.store.profile?.profileUrl !== this.page)
            return;
        const profile: PinmonyProfileSnapshot = JSON.parse(JSON.stringify(this.store.profile)) as PinmonyProfileSnapshot;
        profile.organize = this.organize ? JSON.parse(JSON.stringify(this.organize)) as PinmonyOrganizeSnapshot : undefined;
        this.store.profile = profile;
    }
    pause(): void {
        if(this.boardFollowJob){this.ports.network().cancel(this.boardFollowJob);this.boardFollowJob = '';this.boardFollowRelease?.();this.boardFollowRelease = undefined;}
        if (this.avatarJob) {
            this.ports.network().cancelProfileAvatar(this.avatarJob);
            this.avatarJob = '';
            this.avatarRelease?.(); this.avatarRelease = undefined;
            this.avatarWake?.(); this.avatarWake = undefined;
            if (this.store.panel) {
                this.store.panel.avatarBusy = false;
                this.store.panel.avatarAction = this.avatarAction();
                this.store.panel.avatarError = this.store.panel.avatarAction === 'refresh' ? '上次上传缺少追踪信息，可刷新当前头像核对，暂不重复上传' : this.avatarPending ? '头像处理结果待确认，点“检查结果”只查询状态，不会重新上传' : PinmonyI18n.message("pm_profile_picture_upload_paused_1d4af343");
            }
        }
        if (this.following) {
            this.followUnknown.set(this.following, this.desired);
            this.store.followUncertain = true;
            if (this.store.panel)
                this.store.panel.error = PinmonyI18n.message("pm_follow_result_not_confirmed_reload_to_check_dde5efc6");
        }
        if (this.saving && this.draft) {
            this.saveUnknown = this.draft;
            this.store.saveUncertain = true;
            if (this.store.panel)
                this.store.panel.error = PinmonyI18n.message("pm_save_result_not_confirmed_reload_to_check_before_submitting_agai_b813e8b7");
        }
        if (this.organize?.busy) {
            this.organize.uncertain = true;
            this.organize.error = PinmonyI18n.message("pm_organize_result_not_confirmed_close_and_refresh_to_check_before__d161e558");
            if (this.moveDispatched)
                this.organize.selectedIds.forEach((id: string): void => { this.organizeUnknown.add(id); });
            if (this.createName)
                this.createUnknown.add(this.createName);
            this.store.organizeUncertain = true;
        }
        this.revision++;
        this.client.cancel();
        this.following = '';
        this.saving = false;
        this.store.saving = false;
        this.store.followingBusy = false;
        if (this.store.panel?.loading) {
            this.store.panel.loading = false;
            this.store.panel.error = PinmonyI18n.message("pm_loading_paused_please_reload_06c5d032");
        }
        this.panel();
        if (this.organize) {
            this.organize.busy = false;
            this.organize.loading = false;
            this.syncOrganize();
        }
    }
    close(): void { this.pause(); this.store.panelToken++; this.token = this.store.panelToken; this.store.panel = undefined; this.organize = undefined; this.syncOrganize(); this.ports.motion(); }
    private begin(): number {
        this.pause();
        const s: PinmonyBusinessSessionContext = this.ports.session();
        if (s.accountId !== this.account || s.generation !== this.generation || s.origin !== this.origin) {
            this.followUnknown.clear();
            this.boardFollowUnknown.clear();
            this.confirmed.clear();
            this.saveUnknown = undefined;
            this.organizeUnknown.clear();
            this.createUnknown.clear();
        }
        this.account = s.accountId;
        this.generation = s.generation;
        this.origin = s.origin;
        this.page = this.ports.page();
        this.token = ++this.store.panelToken;
        this.root = undefined;
        this.client.user = '';
        this.client.viewer = '';
        this.client.allowed = [];
        this.client.permissions = [];
        return this.revision;
    }
    private relay(id: string): string {
        const value: string = 'User:' + id, alphabet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        let out: string = '';
        for (let i: number = 0; i < value.length; i += 3) {
            const a: number = value.charCodeAt(i), b: number = i + 1 < value.length ? value.charCodeAt(i + 1) : 0, c: number = i + 2 < value.length ? value.charCodeAt(i + 2) : 0;
            out += alphabet[a >> 2] + alphabet[((a & 3) << 4) | (b >> 4)] + (i + 1 < value.length ? alphabet[((b & 15) << 2) | (c >> 6)] : '=') + (i + 2 < value.length ? alphabet[c & 63] : '=');
        }
        return out;
    }
    private emptyOptions(): Record<string, string> { return {}; }
    private async request(name: string, verb: string, options: Object, revision: number, postRead: boolean = false): Promise<ProfileSettingsResponse> { return this.client.request(this.page, name, verb, options, this.page.slice(this.origin.length), (): boolean => this.current(revision), postRead); }
    private async identity(revision: number): Promise<void> {
        const options: Identity = { username: this.page.slice(this.origin.length).split('/')[1], field_set_key: 'profile' }, p: ProfileSettingsResponse = await this.request('UserResource', 'get', options, revision), u: User = p.resource_response!.data as User, viewer: string = p.client_context?.user?.id || '';
        if (!u || u.type !== 'user' || u.username !== options.username || !/^\d{1,40}$/.test(u.id) || !/^\d{1,40}$/.test(viewer))
            throw new Error('identity');
        this.root = u;
        if (typeof u.explicitly_followed_by_me === 'boolean')
            this.confirmed.set(this.page, u.explicitly_followed_by_me);
        this.client.user = u.id;
        this.client.viewer = viewer;
        this.client.permissions = u.id === viewer && this.page === this.ports.ownPage() ? ['own'] : [];
        if (typeof u.explicitly_followed_by_me === 'boolean' && this.followUnknown.get(u.id) === u.explicitly_followed_by_me)
            this.followUnknown.delete(u.id);
    }
    private async graph(hash: string, variables: Object, revision: number): Promise<GraphData> {
        const q: Graph = { queryHash: hash, variables: variables }, p: ProfileSettingsResponse = await this.request('graphql', 'create', q, revision);
        if (p.errors?.length || !p.data)
            throw new Error('graph');
        return p.data as GraphData;
    }
    async open(mode: string, section: string): Promise<void> {
        if (!this.ports.active() || this.store.saving || this.store.followingBusy || !['edit', 'following', 'followers'].includes(mode) || !['users', 'boards'].includes(section))
            return;
        const revision: number = this.begin();
        this.followersCursor = '';
        this.organize = undefined;
        this.syncOrganize();
        this.store.panel = { page: this.page, mode: mode, section: section, token: this.token, loading: true, error: '', items: [], firstName: '', lastName: '', about: '', website: '', username: '', avatar: '' };
        this.ports.motion();
        try {
            await this.identity(revision);
            const panel: PinmonyProfilePanel = this.store.panel!;
            if (mode === 'edit') {
                if (!this.client.permissions.includes('own'))
                    throw new Error('permission');
                const options: Api = { url: '/v3/users/settings/', data: this.emptyOptions() }, p: ProfileSettingsResponse = await this.request('ApiResource', 'get', options, revision), d: EditData = p.resource_response!.data as EditData;
                if (!d || d.username !== this.root!.username || d.id !== undefined && d.id !== this.client.viewer)
                    throw new Error('identity');
                panel.firstName = (d.first_name || '').slice(0, 2000);
                panel.lastName = (d.last_name || '').slice(0, 2000);
                panel.about = (d.about || '').slice(0, 2000);
                panel.website = (d.website_url || '').slice(0, 2000);
                panel.username = d.username;
                panel.avatar = (d.profile_image_url || '').slice(0, 2000);
                panel.avatarAction = this.avatarAction();
                if (panel.avatarAction) panel.avatarError = panel.avatarAction === 'refresh' ? '上次上传缺少追踪信息，可刷新当前头像核对，暂不重复上传' : PinmonyI18n.message("pm_profile_picture_processing_not_confirmed_check_status_without_up_f4547bd7");
                if (this.saveUnknown && this.saveUnknown.username === panel.username && this.saveUnknown.firstName === panel.firstName && this.saveUnknown.lastName === panel.lastName && this.saveUnknown.about === panel.about && this.saveUnknown.websiteUrl === panel.website)
                    this.saveUnknown = undefined;
                this.store.saveUncertain = !!this.saveUnknown;
                if (this.saveUnknown)
                    panel.error = PinmonyI18n.message("pm_previous_save_not_confirmed_check_your_current_profile_before_su_2a81fa99");
            }
            else if (mode === 'followers') {
                const vars: VariableUser = { userId: this.root!.id }, d: GraphData = await this.graph('369b31865237e1a2f57f1879be69a6c01ee4d6d2806cc4c624d73baea9546b08', vars, revision), user: FollowersData | undefined = d.v3GetUserHandlerQuery?.data, connection: Connection | undefined = user?.followers?.connection;
                if (!user || user.id !== this.relay(this.root!.id) || !connection || !Array.isArray(connection.edges) || connection.edges.length > 2000 || !connection.pageInfo)
                    throw new Error('followers');
                panel.items = connection.edges.slice(0, 100).map((e: Edge): PinmonyProfilePanelItem => {
                    const u: FollowUser = e.node;
                    if (!u || !/^\d{1,40}$/.test(u.entityId || '') || !/^[A-Za-z0-9_]+$/.test(u.username || '') || typeof u.explicitlyFollowedByMe !== 'boolean')
                        throw new Error('user');
                    if (this.followUnknown.get(u.entityId!) === u.explicitlyFollowedByMe)
                        this.followUnknown.delete(u.entityId!);
                    return { id: u.entityId!, name: (u.fullName || u.username || '').slice(0, 300), avatar: /^https:\/\//.test(u.imageMediumUrl || '') ? u.imageMediumUrl! : '', profileUrl: this.origin + '/' + u.username + '/', following: u.explicitlyFollowedByMe, canFollow: !u.blockedByMe && u.entityId !== this.client.viewer && !this.followUnknown.has(u.entityId!) };
                });
                this.followersCursor = typeof connection.pageInfo.endCursor === 'string' && connection.pageInfo.endCursor.length <= 8192 ? connection.pageInfo.endCursor : '';
                panel.hasMore = connection.pageInfo.hasNextPage === true && !!this.followersCursor;
            }
            else {
                const name: string = section === 'boards' ? 'ApiResource' : 'UserFollowingResource', username: string = this.root!.username, boards: FollowingBoards = { explicit_following: true, page_size: 12, fields: ['board.id', 'board.name', 'board.image_cover_url', 'board.followed_by_me', 'board.type', 'board.images[236x]', 'board.image_cover_hd_url', 'board.pin_count', 'board.board_order_modified_at', 'board.url', 'board.owner()', 'user.username'] }, api: Api = { url: '/v3/users/' + username + '/boards/following/', data: boards }, following: Following = { exclude_not_explictly_followed: true, page_size: 50, explicit_following: true, username: username };
                const p: ProfileSettingsResponse = await this.request(name, 'get', section === 'boards' ? api : following, revision, section === 'boards'), rows: Row[] = p.resource_response!.data as Row[];
                if (!Array.isArray(rows) || rows.length > 2000)
                    throw new Error('list');
                panel.items = rows.slice(0, 100).map((r: Row): PinmonyProfilePanelItem => {
                    if (!r || !/^\d{1,40}$/.test(r.id) || typeof (r.full_name || r.name || r.username) !== 'string')
                        throw new Error('row');
                    const covers: string[] = (Array.isArray(r.images?.['236x']) ? r.images!['236x'] : []).filter((im: Image): boolean => !!im && /^https:\/\//.test(im.url)).map((im: Image): string => im.url).slice(0, 3), image: string = r.image_medium_url || r.image_cover_url || '';
                    if (!covers.length && /^https:\/\//.test(image))
                        covers.push(image);
                    if(section === 'boards' && this.boardFollowUnknown.get(r.id) === r.followed_by_me)this.boardFollowUnknown.delete(r.id);
                    const target: string = r.url?.startsWith('/') ? this.origin + r.url : r.url || '', following: boolean = section === 'boards' ? r.followed_by_me === true : r.explicitly_followed_by_me === true;
                    if (this.followUnknown.get(r.id) === following)
                        this.followUnknown.delete(r.id);
                    return { id: r.id, name: (r.full_name || r.name || r.username || '').slice(0, 300), avatar: /^https:\/\//.test(image) ? image : '', covers: covers, targetUrl: target.startsWith(this.origin + '/') && !/[?#\s]/.test(target) ? target : '', pinCount: typeof r.pin_count === 'number' ? r.pin_count.toString() + PinmonyI18n.message('pm_pins_0a89904f') : '', updated: this.updated(r.board_order_modified_at), profileUrl: /^[A-Za-z0-9_]+$/.test(r.username || '') ? this.origin + '/' + r.username + '/' : '', following: following, canFollow: section === 'boards' ? this.client.permissions.includes('own') && typeof r.followed_by_me === 'boolean' && !this.boardFollowUnknown.has(r.id) : r.blocked_by_me !== true && r.id !== this.client.viewer && typeof r.explicitly_followed_by_me === 'boolean' && !this.followUnknown.has(r.id) };
                });
            }
        }
        catch (_) {
            if (this.current(revision) && this.store.panel)
                this.store.panel.error = PinmonyI18n.message("pm_unable_to_load_please_reload_d84df6b3");
        }
        finally {
            if (this.current(revision) && this.store.panel) {
                this.store.panel.loading = false;
                this.panel();
            }
        }
    }
    async moreFollowers(): Promise<void> {
        const panel: PinmonyProfilePanel | undefined = this.store.panel, revision: number = this.revision;
        if (!panel || panel.mode !== 'followers' || panel.loading || panel.moreLoading || !panel.hasMore ||
            this.store.followingBusy || this.store.saving || !this.root || !this.followersCursor || !this.current(revision)) return;
        const cursor: string = this.followersCursor, userId: string = this.root.id;
        panel.moreLoading = true;panel.moreError = '';this.panel();
        try {
            const variables: FollowersPageVariables = {count:10,cursor:cursor,id:this.relay(userId)};
            const data: GraphData = await this.graph('aac6989e67cb8913e620879f06b197c7edee2e17bbf17bc73228a7a3ff560bfd',variables,revision);
            if (!this.current(revision) || this.store.panel?.mode !== 'followers') return;
            const user: FollowersData | undefined = data.node, connection: Connection | undefined = user?.followers?.connection;
            if (!user || user.id !== this.relay(userId) || !connection || !Array.isArray(connection.edges) ||
                connection.edges.length > 100 || !connection.pageInfo) throw new Error('followers');
            const incoming: PinmonyProfilePanelItem[] = connection.edges.map((edge: Edge): PinmonyProfilePanelItem => {
                const u: FollowUser = edge.node;
                if (!u || !/^\d{1,40}$/.test(u.entityId || '') || !/^[A-Za-z0-9_]+$/.test(u.username || '') || typeof u.explicitlyFollowedByMe !== 'boolean') throw new Error('user');
                return {id:u.entityId!,name:(u.fullName || u.username || '').slice(0,300),avatar:/^https:\/\//.test(u.imageMediumUrl || '') ? u.imageMediumUrl! : '',
                    profileUrl:this.origin + '/' + u.username + '/',following:u.explicitlyFollowedByMe,canFollow:!u.blockedByMe && u.entityId !== this.client.viewer && !this.followUnknown.has(u.entityId!)};
            });
            const current: PinmonyProfilePanel = this.store.panel;
            incoming.forEach((item: PinmonyProfilePanelItem): void => { if(!current.items.some((old: PinmonyProfilePanelItem): boolean => old.id === item.id))current.items.push(item); });
            const next: string = typeof connection.pageInfo.endCursor === 'string' && connection.pageInfo.endCursor.length <= 8192 ? connection.pageInfo.endCursor : '';
            this.followersCursor = next;current.hasMore = connection.pageInfo.hasNextPage === true && !!next && next !== cursor && !!incoming.length;
        } catch (_) { if(this.current(revision) && this.store.panel)this.store.panel.moreError = PinmonyI18n.message("pm_unable_to_load_followers_please_retry_7ce0b640"); }
        finally { if(this.current(revision) && this.store.panel){this.store.panel.moreLoading = false;this.panel();} }
    }
    async follow(id: string): Promise<void> {
        if(id && this.store.panel?.section === 'boards'){await this.followBoard(id);return;}
        if (!this.ports.active() || this.store.followingBusy || this.store.saving)
            return;
        let revision: number = this.revision;
        const recovering: boolean = !id && !!this.root && this.followUnknown.has(this.root.id);
        try {
            if (!id) {
                revision = this.begin();
                await this.identity(revision);
                if (recovering) {
                    this.overlay();
                    if (this.followUnknown.has(this.root!.id))
                        this.ports.feedback(PinmonyI18n.message("pm_follow_result_still_not_confirmed_check_again_later_83effe90"));
                    return;
                }
            }
            if (!this.current(revision) || !this.root || this.store.panel?.loading)
                return;
            const item = id ? this.store.panel?.section !== 'boards' ? this.store.panel?.items.find((r) => r.id === id && r.canFollow !== false) : undefined : undefined, target: string = item?.id || (!id && this.root.blocked_by_me !== true ? this.root.id : ''), previous: boolean | undefined = item?.following ?? this.root.explicitly_followed_by_me;
            if (!/^\d{1,40}$/.test(target) || target === this.client.viewer || typeof previous !== 'boolean' || this.followUnknown.has(target))
                return;
            this.following = target;
            this.desired = !previous;
            this.store.followingBusy = true;
            this.client.allowed = ['follow:' + target];
            const vars: VariableUser = { followee: target }, d: GraphData = await this.graph(this.desired ? '5e6f83666a4e4fbd33b6c78f26f80166c097f4164e666b6e408b4bb62cb8c1e5' : '84f6cda9933f7aa2786ff803f5c7a7bc31af0392a37434f830fd7e2602c994c0', vars, revision), user: FollowUser | undefined = (this.desired ? d.v3FollowUserMethodMutation : d.v3UnfollowUserMethodMutation)?.data;
            if (!user || user.id !== this.relay(target) || user.explicitlyFollowedByMe !== this.desired)
                throw new Error('unconfirmed');
            if (!this.current(revision))
                return;
            if (item) {
                item.following = this.desired;
                if (item.profileUrl)
                    this.confirmed.set(item.profileUrl, this.desired);
            }
            if (target === this.root.id) {
                this.root.explicitly_followed_by_me = this.desired;
                this.confirmed.set(this.page, this.desired);
            }
            this.panel();
            if (this.store.profile?.profileUrl === this.page) {
                const profile: PinmonyProfileSnapshot = JSON.parse(JSON.stringify(this.store.profile)) as PinmonyProfileSnapshot;
                profile.actions.forEach((a) => {
                    if (a.kind === 'follow')
                        a.label = this.desired ? '关注中' : '关注';
                });
                this.store.profile = profile;
            }
            this.following = '';
        }
        catch (_) {
            if (this.current(revision) && this.following) {
                this.followUnknown.set(this.following, this.desired);
                this.store.followUncertain = true;
                if (this.store.panel) {
                    this.store.panel.error = PinmonyI18n.message("pm_follow_result_not_confirmed_reload_to_check_dde5efc6");
                    this.store.panel.items.forEach((item): void => { if (item.id === this.following)
                        item.canFollow = false; });
                    this.panel();
                }
                this.ports.feedback(PinmonyI18n.message("pm_follow_result_not_confirmed_reload_to_check_before_submitting_ag_002f7a05"));
            }
        }
        finally {
            if (this.current(revision)) {
                this.following = '';
                this.store.followingBusy = false;
            }
        }
    }
    private async followBoard(id: string): Promise<void> {
        const revision: number = this.revision, panel: PinmonyProfilePanel | undefined = this.store.panel;
        const item: PinmonyProfilePanelItem | undefined = panel?.items.find((row: PinmonyProfilePanelItem): boolean => row.id === id);
        if(!this.current(revision) || !panel || panel.mode !== 'following' || panel.section !== 'boards' || panel.loading ||
            !item || item.canFollow === false || !/^\d{1,40}$/.test(id) || this.store.followingBusy || this.store.saving ||
            !this.client.permissions.includes('own') || this.boardFollowUnknown.has(id))return;
        const desired: boolean = !item.following, source: string = this.page.slice(this.origin.length) + '_following/';
        const envelope: BoardFollowEnvelope = {options:{url:'/v3/boards/' + id + '/follow/'},context:{}};
        const session: PinmonyBusinessSessionContext = this.ports.session();
        const job: PinmonyNetworkJob = {id:'native_profile_board_follow_' + (++boardFollowSequence).toString(),epoch:session.generation,page:this.page,
          url:this.origin + '/resource/ApiResource/' + (desired ? 'update' : 'delete') + '/',method:'POST',
          body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
          headers:{'Accept':'application/json','X-Pinterest-AppState':'active','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest',
            'X-Pinterest-Pws-Handler':'www/[username]/_following.js','X-Pinterest-Source-Url':source}};
        if(session.appVersion)job.headers['X-App-Version'] = session.appVersion;
        this.store.followingBusy = true;this.boardFollowJob = job.id;this.boardFollowUnknown.set(id,desired);item.canFollow = false;this.panel();
        const current = (): boolean => this.current(revision) && this.boardFollowJob === job.id && this.store.panel?.section === 'boards';
        const stopped: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => {this.boardFollowRelease = (): void => resolve(undefined);});
        try {
            const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessProfileBoardFollow(job,
                (): PinmonyBusinessSessionContext => this.ports.session(),this.page,id,this.client.viewer,current),stopped]);
            if(!current())return;
            if(!reply || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 2000000)throw new Error('unconfirmed');
            const response: ProfileSettingsResponse = JSON.parse(reply.body) as ProfileSettingsResponse, r: ProfileSettingsResource | undefined = response.resource_response;
            if(r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)throw new ProfileSettingsRejected(PinmonyI18n.message("pm_the_website_rejected_this_action_6d58f2a6"));
            if(!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== (desired ? 'v3_follow_board' : 'v3_unfollow_board') ||
                response.client_context?.user && response.client_context.user.id !== this.client.viewer)throw new Error('unconfirmed');
            const data: BoardFollowData | null = r.data as BoardFollowData | null;
            if(desired ? !data || data.id !== id || data.type !== 'board' || data.followed_by_me !== true : data !== null)throw new Error('unconfirmed');
            this.boardFollowUnknown.delete(id);
            const actual: PinmonyProfilePanelItem | undefined = this.store.panel?.items.find((row: PinmonyProfilePanelItem): boolean => row.id === id);
            if(actual){actual.following = desired;actual.canFollow = true;}
            this.store.profileCache.clear();this.ports.feedback(desired ? '已关注图板' : PinmonyI18n.message("pm_board_unfollowed_b3151db9"));
        }catch (error) {
            if(current()){
                const rejected: boolean = error instanceof ProfileSettingsRejected;
                if(rejected)this.boardFollowUnknown.delete(id);
                const actual: PinmonyProfilePanelItem | undefined = this.store.panel?.items.find((row: PinmonyProfilePanelItem): boolean => row.id === id);
                if(actual)actual.canFollow = rejected;
                this.ports.feedback(rejected ? '网站拒绝本次图板关注操作，可以重试' : PinmonyI18n.message("pm_board_follow_result_not_confirmed_reload_to_check_before_submitt_44c2a0cd"));
            }
        }finally {
            if(current()){this.boardFollowJob = '';this.boardFollowRelease = undefined;this.store.followingBusy = false;this.panel();}
        }
    }
    private avatarAction(): string {
        const account: PinmonyBusinessSessionContext = this.ports.session();
        const key: string = account.origin + ':' + account.accountId + ':' + account.generation.toString();
        return this.avatarPending?.account === key ? this.avatarPending.tracking ? 'check' : 'refresh' : '';
    }
    private async readCurrentAvatar(revision: number): Promise<string> {
        const options: Api = { url: '/v3/users/settings/', data: this.emptyOptions() };
        const reply: ProfileSettingsResponse = await this.request('ApiResource', 'get', options, revision);
        const data: EditData | null = reply.resource_response!.data as EditData | null;
        if (!this.current(revision) || !data || data.username !== this.root?.username ||
            data.id !== undefined && data.id !== this.client.viewer ||
            typeof data.profile_image_url !== 'string' || data.profile_image_url.length > 2000 ||
            !/^https:\/\/(?:i|s)\.pinimg\.com\//.test(data.profile_image_url)) throw new Error('avatar-readback');
        return data.profile_image_url;
    }
    async changeAvatar(): Promise<void> {
        const panel: PinmonyProfilePanel | undefined = this.store.panel;
        if (!panel || panel.mode !== 'edit' || panel.loading || panel.avatarBusy || this.avatarPicking || this.avatarJob ||
            this.store.saving || !this.current(this.revision) || this.page !== this.ports.ownPage() ||
            !this.root || this.root.id !== this.client.viewer || !this.client.permissions.includes('own')) return;
        const captured: PinmonyBusinessSessionContext = this.ports.session();
        const page: string = panel.page, token: number = this.store.panelToken;
        const key: string = captured.origin + ':' + captured.accountId + ':' + captured.generation.toString();
        if (this.avatarPending?.account !== key) this.avatarPending = undefined;
        // System photo selection temporarily backgrounds the app. Its result is
        // owned by account/panel, not by the hidden document or foreground revision.
        const ownsPanel = (): boolean => {
            const actual: PinmonyBusinessSessionContext = this.ports.session();
            return actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation &&
                actual.origin === captured.origin && this.store.panelToken === token && this.store.panel?.page === page &&
                this.store.panel?.mode === 'edit' && this.ports.page() === page && this.ports.ownPage() === page;
        };
        panel.avatarError = ''; panel.avatarBusy = true; this.panel();
        let photo: PinmonyProfileAvatarPhoto | undefined = undefined;
        try {
            if (!this.avatarPending) {
                this.avatarPicking = true;
                const uris: string[] = await pickPublishPhotoUris(1);
                if (!uris.length || !ownsPanel()) return;
                photo = await readProfileAvatarPhoto(uris[0]);
                if (!ownsPanel()) return;
                this.store.panel!.avatarPreview = photo.data;
                this.panel();
            }
        } catch (_) {
            if (ownsPanel()) this.store.panel!.avatarError = PinmonyI18n.message("pm_unable_to_read_photo_choose_a_png_jpeg_or_webp_image_of_4_mb_or__2ad5f56a");
            return;
        } finally {
            this.avatarPicking = false;
            if (ownsPanel()) { this.store.panel!.avatarBusy = false; this.panel(); }
        }
        if (!ownsPanel() || !this.ports.active()) return;
        const readOnlyRefresh: boolean = !!this.avatarPending && !this.avatarPending.tracking;
        const revision: number = this.revision;
        const id: string = 'native_profile_avatar_' + (++avatarSequence).toString();
        this.avatarJob = id;
        const current = (): boolean => ownsPanel() && this.current(revision) && this.avatarJob === id;
        this.store.panel!.avatarBusy = true;
        this.store.panel!.avatarError = readOnlyRefresh ? '正在重新读取当前头像…' : this.avatarPending ? '正在检查头像处理结果…' : PinmonyI18n.message("pm_uploading_profile_picture_dd6b1b58"); this.panel();
        const cancelled: Promise<string | undefined> = new Promise<string | undefined>((resolve): void => { this.avatarRelease = (): void => resolve(undefined); });
        const process = async (): Promise<string> => {
            if (readOnlyRefresh) return this.readCurrentAvatar(revision);
            let tracking: string = this.avatarPending?.tracking || '';
            if (!tracking && photo) {
                tracking = await this.ports.network().uploadProfileAvatar(photo.bytes, photo.mime, page, this.ports.ownPage(),
                    (): PinmonyBusinessSessionContext => this.ports.session(), current, id,
                    (): void => { this.avatarPending = { account: key, tracking: '' }; });
                if (!current()) throw new Error('stale');
                this.avatarPending = { account: key, tracking: tracking };
            }
            if (!tracking) throw new Error('avatar-unconfirmed');
            for (let attempt: number = 0; attempt < 10; attempt++) {
                if (!current()) throw new Error('stale');
                const status: number = await this.ports.network().readProfileAvatarStatus(tracking, page,
                    (): PinmonyBusinessSessionContext => this.ports.session(), current, id);
                if (!current()) throw new Error('stale');
                if (status === 5) throw new Error('avatar-rejected');
                if (status === 4) return this.readCurrentAvatar(revision);
                this.store.panel!.avatarError = PinmonyI18n.message("pm_photo_uploaded_processing_profile_picture_2fb3d576"); this.panel();
                await new Promise<void>((resolve): void => {
                    const timer: number = setTimeout((): void => { this.avatarWake = undefined; resolve(); }, 500 * (attempt + 1));
                    this.avatarWake = (): void => { clearTimeout(timer); resolve(); };
                });
            }
            throw new Error('avatar-unconfirmed');
        };
        try {
            const avatar: string | undefined = await Promise.race([process(), cancelled]);
            if (!current() || !avatar) return;
            if (!readOnlyRefresh) this.avatarPending = undefined;
            this.store.panel!.avatar = avatar; this.store.panel!.avatarPreview = '';
            this.store.panel!.avatarError = readOnlyRefresh ? PinmonyI18n.message("pm_profile_picture_reloaded_previous_upload_still_not_confirmed_upl_f11d47a5") : '';
            this.store.panel!.avatarAction = this.avatarAction();
            if (this.store.profile?.profileUrl === page) {
                const profile: PinmonyProfileSnapshot = JSON.parse(JSON.stringify(this.store.profile)) as PinmonyProfileSnapshot;
                profile.avatarUrl = avatar; this.store.profile = profile;
            }
            this.ports.avatarSaved?.(page, avatar); this.ports.refresh(); this.ports.feedback(readOnlyRefresh ? '已刷新当前头像' : PinmonyI18n.message("pm_profile_picture_updated_a938ed15"));
        } catch (error) {
            if (!current()) return;
            const rejected: boolean = (error as Error).message === 'avatar-rejected';
            if (rejected) this.avatarPending = undefined;
            this.store.panel!.avatarAction = this.avatarAction();
            this.store.panel!.avatarError = rejected ? PinmonyI18n.message("pm_the_website_could_not_process_your_profile_picture_you_can_selec_e9547476") :
                this.store.panel!.avatarAction === 'refresh' ? PinmonyI18n.message("pm_profile_picture_not_confirmed_tap_refresh_profile_picture_before_d22d4fa3") : this.avatarPending ? PinmonyI18n.message("pm_profile_picture_processing_not_confirmed_tap_check_status_to_que_d349978e") : PinmonyI18n.message("pm_profile_picture_not_uploaded_you_can_select_another_photo_8eb8ddd3");
        } finally {
            if (this.avatarJob === id) {
                this.avatarJob = ''; this.avatarRelease = undefined; this.avatarWake?.(); this.avatarWake = undefined;
                if (ownsPanel()) { this.store.panel!.avatarBusy = false; this.panel(); }
            }
        }
    }
    async save(text: string): Promise<void> {
        const p: PinmonyProfilePanel | undefined = this.store.panel, revision: number = this.revision;
        if (!p || p.mode !== 'edit' || p.loading || p.avatarBusy || !this.current(revision) || this.saving || this.saveUnknown || !this.client.permissions.includes('own'))
            return;
        let input: Edit;
        try {
            input = JSON.parse(text) as Edit;
            const keys: string[] = Object.keys(input);
            if (keys.length !== 5 || !['firstName', 'lastName', 'about', 'websiteUrl', 'username'].every((k: string): boolean => keys.includes(k)) || [input.firstName, input.lastName, input.about, input.websiteUrl, input.username].some((v: string): boolean => typeof v !== 'string' || v.length > 2000) || !/^[A-Za-z0-9_]+$/.test(input.username))
                throw new Error('input');
        }
        catch (_) {
            return;
        }
        input.impressumUrl = '';
        input.additionalWebsiteUrls = [];
        input.pronouns = [];
        this.draft = input;
        this.saving = true;
        this.store.saving = true;
        try {
            const vars: VariableUser = { input: input }, q: Graph = { queryHash: '7f7aa5597fc53cb10b582e1d45cac2e61336be40dde57f95a9f022fb83806e81', variables: vars }, response: ProfileSettingsResponse = await this.request('graphql', 'create', q, revision), d: GraphData = response.data as GraphData, m: Mutation | undefined = d?.v3EditSettingsHandlerMutation, outcome: EditOutcome | undefined = m?.v3EditSettingsHandlerResponse, user: FollowUser | undefined = m?.v3UsersMeViewerResponse?.data;
            if (outcome?.error?.message === '用户名已被使用。') {
                this.saving = false;
                this.store.saving = false;
                this.ports.feedback(PinmonyI18n.message("pm_username_already_taken_b003d15d"));
                return;
            }
            if (response.errors?.length || outcome?.__typename !== 'V3EditSettingsHandler' || user?.__typename !== 'User' || user.username !== input.username || user.id !== undefined && user.id !== this.relay(this.client.viewer))
                throw new Error('unconfirmed');
            if (!this.current(revision))
                return;
            this.saving = false;
            this.store.saving = false;
            this.saveUnknown = undefined;
            this.store.saveUncertain = false;
            const page: string = this.page;
            this.close();
            this.ports.feedback('修改完成');
            this.ports.saved(page, input.username);
        }
        catch (_) {
            if (this.current(revision)) {
                this.saveUnknown = input;
                this.store.saveUncertain = true;
                p.error = PinmonyI18n.message("pm_save_result_not_confirmed_reload_to_check_before_submitting_agai_b813e8b7");
                this.panel();
            }
        }
        finally {
            if (this.current(revision)) {
                this.saving = false;
                this.store.saving = false;
            }
        }
    }
    overlay(): void {
        const session: PinmonyBusinessSessionContext = this.ports.session(), profile: PinmonyProfileSnapshot | undefined = this.store.profile;
        if (!profile || session.accountId !== this.account || session.generation !== this.generation || session.origin !== this.origin)
            return;
        const confirmed: boolean | undefined = this.confirmed.get(profile.profileUrl);
        if (confirmed === undefined)
            return;
        const snapshot: PinmonyProfileSnapshot = JSON.parse(JSON.stringify(profile)) as PinmonyProfileSnapshot;
        snapshot.actions.forEach((action): void => { if (action.kind === 'follow')
            action.label = confirmed ? '关注中' : '关注'; });
        this.store.profile = snapshot;
    }
    private updated(value: string | undefined): string {
        const elapsed: number = Date.now() - Date.parse(value || '');
        if (!Number.isFinite(elapsed) || elapsed < 0) return '';
        const days: number = Math.floor(elapsed / 86400000);
        const count: number = days < 7 ? days : days < 30 ? Math.floor(days / 7) : days < 365 ? Math.floor(days / 30) : Math.floor(days / 365);
        const singular: string = days < 7 ? 'pm_one_day_ago_suffix' : days < 30 ? 'pm_one_week_ago_suffix' : days < 365 ? 'pm_one_month_ago_suffix' : 'pm_one_year_ago_suffix';
        const plural: string = days < 7 ? 'pm_days_ago_5972982c' : days < 30 ? 'pm_weeks_ago_2ad8bd1c' : days < 365 ? 'pm_months_ago_1bb931f2' : 'pm_years_ago_c533a6c6';
        return count.toString() + PinmonyI18n.message(count === 1 ? singular : plural);
    }
    private boardImage(value: string | undefined): string { return typeof value === 'string' && value.length <= 4096 && /^https:\/\/(?:i|s)\.pinimg\.com\//.test(value) ? value : ''; }
    private async boards(revision: number, append: boolean): Promise<void> {
        const o: PinmonyOrganizeSnapshot = this.organize!;
        o.loading = true;
        o.error = '';
        this.syncOrganize();
        const previous: string = this.cursor;
        try {
            const options: Boards = { privacy_filter: 'all', sort: 'custom', field_set_key: 'profile_grid_item', filter_stories: true, username: this.root!.username, page_size: 25, group_by: 'mix_public_private', include_archived: true, filter_all_pins: false };
            if (append && previous)
                options.bookmarks = [previous];
            const p: ProfileSettingsResponse = await this.request('BoardsResource', 'get', options, revision), rows: Board[] = p.resource_response!.data as Board[];
            if (!Array.isArray(rows) || rows.length > 2000)
                throw new Error('boards');
            const mapped: PinmonyOrganizeBoard[] = rows.filter((b: Board): boolean => !!b && b.type === 'board' && /^\d{1,40}$/.test(b.id) && !!b.name?.trim()).map((b: Board): PinmonyOrganizeBoard => ({ id: b.id, title: b.name.trim().slice(0, 300), imageUrl: this.boardImage(b.image_cover_hd_url || b.image_cover_url), secret: b.privacy === 'secret', enabled: (Array.isArray(b.access) ? b.access.includes('write') : /(?:^|\s)write(?:\s|$)/.test(b.access)) && !b.archived_by_me }));
            if (!append)
                o.boards = [];
            mapped.forEach((b: PinmonyOrganizeBoard): void => {
                if (!o.boards.some((old: PinmonyOrganizeBoard): boolean => old.id === b.id))
                    o.boards.push(b);
            });
            this.cursor = (p.resource_response!.bookmark || p.resource?.options?.bookmarks?.[0] || '').slice(0, 8192);
            o.hasMore = !!this.cursor && this.cursor !== '-end-' && this.cursor !== previous && !!rows.length;
        }
        catch (_) {
            if (this.current(revision))
                o.error = PinmonyI18n.message("pm_unable_to_load_boards_please_retry_04bec826");
        }
        finally {
            if (this.current(revision)) {
                o.loading = false;
                this.syncOrganize();
            }
        }
    }
    async organizeAction(action: string, value: string, secret: boolean): Promise<void> {
        if (!PIN_PROFILE_ORGANIZE_ENABLED || !this.ports.active())
            return;
        if (['morePins', 'retryPins'].includes(action)) {
            if (!this.organize?.busy)
                await this.ports.morePins(action);
            return;
        }
        if (action === 'open') {
            if (this.store.panel || this.organize?.busy || !this.store.profile?.unorganizedPins?.length || this.store.profile?.profileUrl !== this.ports.page())
                return;
            const revision: number = this.begin();
            this.organize = { phase: 'select', selectedIds: [], boards: [], loading: true, busy: false, error: '', feedback: '', hasMore: false, uncertain: false };
            this.syncOrganize();
            try {
                await this.identity(revision);
                if (!this.client.permissions.includes('own'))
                    throw new Error('permission');
            }
            catch (_) {
                if (this.current(revision))
                    this.organize.error = PinmonyI18n.message("pm_unable_to_verify_identity_close_and_retry_80632869");
            }
            finally {
                if (this.current(revision)) {
                    this.organize.loading = false;
                    this.syncOrganize();
                }
            }
            return;
        }
        const o: PinmonyOrganizeSnapshot | undefined = this.organize, revision: number = this.revision;
        if (!o || !this.current(revision) || o.busy)
            return;
        if (action === 'close') {
            this.organize = undefined;
            this.store.organizeUncertain = false;
            this.syncOrganize();
            this.ports.refresh();
            return;
        }
        if (o.loading)
            return;
        const pins: string[] = (this.store.profile?.unorganizedPins || []).map((p): string => p.id);
        if (action === 'toggle' && o.phase === 'select' && pins.includes(value))
            o.selectedIds = o.selectedIds.includes(value) ? o.selectedIds.filter((id: string): boolean => id !== value) : o.selectedIds.concat([value]);
        else if (action === 'all' && o.phase === 'select')
            o.selectedIds = o.selectedIds.length === pins.length ? [] : pins.slice(0, 100);
        else if (action === 'back') {
            o.phase = 'select';
            o.error = '';
        }
        else if (action === 'next' && o.selectedIds.length) {
            o.phase = 'boards';
            await this.boards(revision, false);
            return;
        }
        else if (['moreBoards', 'retryBoards'].includes(action)) {
            await this.boards(revision, action === 'moreBoards' && !!this.cursor);
            return;
        }
        else if (action === 'createForm' && !o.uncertain) {
            o.phase = 'create';
            o.error = '';
        }
        else if (action === 'boards') {
            o.phase = 'boards';
            o.error = '';
        }
        else if (['move', 'create'].includes(action) && !o.uncertain && o.selectedIds.length && o.selectedIds.length <= 100 && o.selectedIds.every((id: string): boolean => pins.includes(id))) {
            let target: PinmonyOrganizeBoard | undefined = o.boards.find((b: PinmonyOrganizeBoard): boolean => b.id === value && b.enabled);
            if (action === 'move' && (o.phase !== 'boards' || !target) || action === 'create' && (o.phase !== 'create' || !value.trim() || value.trim().length > 300))
                return;
            if (o.selectedIds.some((id: string): boolean => this.organizeUnknown.has(id)) || action === 'create' && this.createUnknown.has(value.trim())) {
                o.uncertain = true;
                o.error = PinmonyI18n.message("pm_previous_organize_result_not_confirmed_refresh_to_check_before_s_b7a64551");
                this.syncOrganize();
                return;
            }
            o.busy = true;
            o.error = '';
            this.syncOrganize();
            try {
                if (action === 'create') {
                    const options: BoardCreate = { name: value.trim(), privacy: secret ? 'secret' : 'public' };
                    this.createName = options.name;
                    const p: ProfileSettingsResponse = await this.request('BoardResource', 'create', options, revision), b: Board = p.resource_response!.data as Board;
                    if (p.resource_response?.endpoint_name !== 'v3_create_board' || !/^\d{1,40}$/.test(b?.id) || b.type !== 'board' || b.name !== options.name || b.privacy !== options.privacy)
                        throw new Error('board');
                    this.createName = '';
                    target = { id: b.id, title: b.name, imageUrl: this.boardImage(b.image_cover_hd_url || b.image_cover_url), secret: secret, enabled: (Array.isArray(b.access) ? b.access.includes('write') : /(?:^|\s)write(?:\s|$)/.test(b.access)) && !b.archived_by_me };
                    o.boards.push(target);
                    o.phase = 'boards';
                    this.store.profileCache.clear();
                    if (!target.enabled)
                        throw new ProfileSettingsRejected('图板已创建，但没有写入权限，请选择其他图板');
                    this.syncOrganize();
                }
                this.moveDispatched = true;
                this.client.allowed = ['board:' + target!.id].concat(o.selectedIds.map((id: string): string => 'organize:' + id));
                const move: Move = { board_id: target!.id, pin_ids: o.selectedIds.slice() }, options: Api = { url: '/v3/pins/bulk/move/', data: move }, p: ProfileSettingsResponse = await this.request('ApiResource', 'create', options, revision);
                if (p.resource_response?.endpoint_name !== 'v3_move_pins')
                    throw new Error('move');
                if (!this.current(revision))
                    return;
                o.busy = false;
                this.organize = undefined;
                this.syncOrganize();
                this.store.profileCache.clear();
                this.ports.refresh();
            }
            catch (error) {
                if (this.current(revision)) {
                    o.uncertain = !(error instanceof ProfileSettingsRejected);
                    if (o.uncertain) {
                        if (this.moveDispatched)
                            o.selectedIds.forEach((id: string): void => { this.organizeUnknown.add(id); });
                        if (this.createName)
                            this.createUnknown.add(this.createName);
                    }
                    o.error = o.uncertain ? PinmonyI18n.message("pm_organize_result_not_confirmed_close_and_refresh_to_check_before__d161e558") : (error as Error).message;
                }
            }
            finally {
                if (this.current(revision)) {
                    o.busy = false;
                    this.createName = '';
                    this.moveDispatched = false;
                    this.syncOrganize();
                }
            }
            return;
        }
        else
            return;
        this.syncOrganize();
    }
}
