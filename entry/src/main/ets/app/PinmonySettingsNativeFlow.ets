import { PinmonyI18n } from 'common_foundation';
import { PinmonySettingsStore, PinmonyAccountSettings, PinmonyAiTopic, PinmonyRecentActivity, NotificationGroup, NotificationCategory } from 'feature_settings';
import { PinmonyBusinessSessionContext } from 'common_session';
import { ProfileSettingsPorts, PinmonyProfileSettingsClient, ProfileSettingsResponse, ProfileSettingsRejected } from './PinmonyProfileSettingsClient';
interface User {
    id: string;
    type?: string;
    username: string;
    email?: string;
    has_confirmed_email?: boolean;
    birthdate?: string;
    birthday?: number;
    gender?: string;
    custom_gender?: string;
    country?: string;
    opt_in_private_account?: boolean;
    search_privacy_enabled?: boolean;
    exclude_from_search?: boolean;
    allow_switch_between_private_and_public_profile?: boolean;
    can_edit_search_privacy?: boolean;
    is_parental_control_passcode_enabled?: boolean;
    is_parental_control_passcode_verification_pending?: boolean;
    gen_ai_topics_opt_out?: string[];
}
interface Topic {
    key: string;
    text: string;
    opt_out: boolean;
    interest_ids: (string | number)[];
}
interface Image {
    url: string;
    width?: number;
    height?: number;
}
interface Pin {
    id: string;
    type: string;
    grid_title?: string;
    title?: string;
    description?: string;
    images?: Record<string, Image>;
}
interface Country {
    key: string;
    name: string;
}
interface Group {
    type: string;
    key: string;
    label: string;
    subcategories: Category[];
}
interface Category {
    key: string;
    label: string;
    description?: string;
    channel_options_label?: string;
    channel_options: Channel[];
}
interface Channel {
    label: string;
    value: boolean;
}
interface Api {
    url: string;
    data?: Object;
}
interface Identity {
    username: string;
    field_set_key: string;
}
interface Update {
    user_id?: string;
    surface_tag: string;
    birthdate?: string;
    gender?: string;
    custom_gender?: string;
    country?: string;
    opt_in_private_account?: boolean;
    exclude_from_search?: boolean;
    user_confirm_skip_passcode?: boolean;
}
interface AiUpdate {
    gen_ai_topics_update_source: string;
    gen_ai_topics_opt_in?: string[];
    gen_ai_topics_opt_out?: string[];
}
interface AiChoice {
    key?: string;
    enabled: boolean;
}
interface ActivityOptions {
    username: string;
    filter_type: string;
}
interface ActivityFeedback {
    pin: string;
    feedback_type: number;
    through_id: string;
    rec_reason_type: number;
}
export interface PinmonySettingsNativePorts extends ProfileSettingsPorts {
    store: () => PinmonySettingsStore;
    active: () => boolean;
    page: () => string;
}
export class PinmonySettingsNativeFlow {
    private readonly ports: PinmonySettingsNativePorts;
    private readonly store: PinmonySettingsStore;
    private readonly client: PinmonyProfileSettingsClient;
    private account: string = '';
    private generation: number = -1;
    private origin: string = '';
    private page: string = '';
    private revision: number = 0;
    private token: number = 0;
    private screen: string = '';
    private pending: string = '';
    private sent: boolean = false;
    private owned: boolean = false;
    private uncertain: Map<string, string> = new Map();
    private activityUnknown: Set<string> = new Set();
    private activityClosed: Set<string> = new Set();
    private value: PinmonyAccountSettings | undefined = undefined;
    constructor(ports: PinmonySettingsNativePorts) { this.ports = ports; this.store = ports.store(); this.client = new PinmonyProfileSettingsClient(ports); }
    private current(revision: number): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return revision === this.revision && s.authenticated && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.ports.active() && this.page === this.ports.page() && this.token === this.store.token && this.screen === this.store.screen; }
    pause(): void {
        if (this.owned && this.sent && this.pending) {
            this.uncertain.set(this.pending, this.uncertain.get(this.pending) || '');
            this.store.writeUncertain = true;
            this.store.error = PinmonyI18n.message('保存结果未确认，请重新读取核对；不会自动重试保存');
        }
        else if (this.owned && this.store.loading)
            this.store.error = PinmonyI18n.message('读取已暂停，请重试');
        this.revision++;
        this.client.cancel();
        this.sent = false;
        this.pending = '';
        if (this.owned) {
            this.store.loading = false;
            this.store.busy = false;
        }
        this.owned = false;
        this.value = undefined;
    }
    private bind(): void {
        const s: PinmonyBusinessSessionContext = this.ports.session();
        if (this.account !== s.accountId || this.generation !== s.generation || this.origin !== s.origin) {
            this.uncertain.clear();
            this.activityUnknown.clear();
            this.activityClosed.clear();
            this.store.data = undefined;
            this.store.notifications = [];
            this.client.user = '';
            this.client.viewer = '';
        }
        this.account = s.accountId;
        this.generation = s.generation;
        this.origin = s.origin;
        this.page = this.ports.page();
        this.client.allowed = [];
        this.client.permissions = [];
    }
    private commit(revision: number): void {
        if (!this.current(revision) || !this.value)
            return;
        if(this.uncertain.size > 0 && !this.value.error){this.value.error = PinmonyI18n.message('上次保存结果仍未确认，已读取当前设置，请勿重复提交');this.store.error = this.value.error;}
        this.store.data = JSON.parse(JSON.stringify(this.value)) as PinmonyAccountSettings;
        this.store.writeUncertain = this.uncertain.size > 0;
    }
    private empty(): PinmonyAccountSettings { return { page: this.page, token: this.token, loading: false, error: '', saved: false, ready: false, email: '', confirmedEmail: false, birthdate: '', gender: '', customGender: '', country: '', countries: [], privateProfile: false, searchPrivacy: false, canChangePrivacy: false, canEditSearchPrivacy: false, topics: [], activities: [], activityBookmark: '', activityHasMore: false }; }
    private emptyOptions(): Record<string, string> { return {}; }
    private async request(name: string, verb: string, options: Object, source: string, revision: number): Promise<ProfileSettingsResponse> { return this.client.request(this.page, name, verb, options, source, (): boolean => this.current(revision)); }
    private date(v: string | undefined): string {
        if (typeof v !== 'string')
            return '';
        const m: RegExpMatchArray | null = v.trim().match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:T.*)?$/);
        if (!m)
            return '';
        const value: string = m[1] + '-' + m[2].padStart(2, '0') + '-' + m[3].padStart(2, '0'), d: Date = new Date(value + 'T00:00:00Z');
        return Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === value && value >= '1900-01-01' && value <= new Date().toISOString().slice(0, 10) ? value : '';
    }
    private map(account: User): void {
        if (!account || account.id !== this.client.viewer || account.username?.toLowerCase() !== this.page.slice(this.origin.length).split('/')[1].toLowerCase())
            throw new Error('identity');
        const v: PinmonyAccountSettings = this.value!;
        v.email = (account.email || '').slice(0, 320);
        v.confirmedEmail = account.has_confirmed_email === true;
        v.birthdate = this.date(account.birthdate);
        if (!v.birthdate && Number.isSafeInteger(account.birthday) && account.birthday! > 0) {
            const d: Date = new Date(account.birthday! * 1000);
            if (Number.isFinite(d.getTime()))
                v.birthdate = this.date(d.toISOString().slice(0, 10));
        }
        v.gender = (account.gender || '').slice(0, 30);
        v.customGender = (account.custom_gender || '').slice(0, 500);
        v.country = (account.country || '').slice(0, 2);
        v.privateProfile = account.opt_in_private_account === true;
        v.searchPrivacy = typeof account.search_privacy_enabled === 'boolean' ? account.search_privacy_enabled : account.exclude_from_search === true;
        v.canChangePrivacy = account.allow_switch_between_private_and_public_profile === true && account.is_parental_control_passcode_enabled !== true && account.is_parental_control_passcode_verification_pending !== true;
        v.canEditSearchPrivacy = account.can_edit_search_privacy === true;
        v.ready = true;
        this.client.permissions = ['own'];
        if (v.canChangePrivacy)
            this.client.permissions.push('privacy');
        if (v.canEditSearchPrivacy)
            this.client.permissions.push('search');
        if (v.gender === 'unspecified')
            this.client.permissions.push('custom');
        this.uncertain.forEach((value: string, key: string): void => {
            const actual: string | undefined = key === 'birthdate' ? v.birthdate : key === 'gender' ? v.gender : key === 'customGender' ? v.customGender : key === 'country' ? v.country : key === 'privateProfile' ? v.privateProfile.toString() : key === 'searchPrivacy' ? v.searchPrivacy.toString() : undefined;
            if (actual !== undefined && actual === value)
                this.uncertain.delete(key);
        });
    }
    private topics(items: Topic[]): PinmonyAiTopic[] {
        if (!Array.isArray(items) || items.length > 40)
            throw new Error('topics');
        return items.map((t: Topic): PinmonyAiTopic => {
            if (!t || !/^[a-z_]{1,64}$/.test(t.key) || typeof t.text !== 'string' || typeof t.opt_out !== 'boolean' || !Array.isArray(t.interest_ids) || !t.interest_ids.length || t.interest_ids.length > 20 || t.interest_ids.some((id: string | number): boolean => !/^\d{1,40}$/.test(String(id))))
                throw new Error('topic');
            return { key: t.key, text: t.text.slice(0, 160), enabled: !t.opt_out };
        });
    }
    private async notify(revision: number): Promise<void> {
        const options: Api = { url: '/v3/settings/notifications/' }, p: ProfileSettingsResponse = await this.request('ApiResource', 'get', options, this.page.slice(this.origin.length), revision), rows: Group[] = p.resource_response!.data as Group[];
        if (p.resource_response?.endpoint_name !== 'v3_get_settings_all_notifications' || !Array.isArray(rows) || rows.length > 100)
            throw new Error('notifications');
        const mapped: NotificationGroup[] = rows.slice(0, 40).map((g: Group): NotificationGroup => {
            if (g?.type !== 'notification_settings_group' || typeof g.label !== 'string' || !Array.isArray(g.subcategories))
                throw new Error('group');
            return { key: String(g.key).slice(0, 100), label: g.label.slice(0, 200), categories: g.subcategories.slice(0, 60).map((c: Category): NotificationCategory => {
                    if (typeof c.label !== 'string' || !Array.isArray(c.channel_options))
                        throw new Error('category');
                    return { key: String(c.key).slice(0, 100), label: c.label.slice(0, 200), description: String(c.description || '').slice(0, 500), summary: String(c.channel_options_label || '').slice(0, 500), channels: c.channel_options.slice(0, 10).map((o: Channel): Channel => {
                            if (typeof o.label !== 'string' || typeof o.value !== 'boolean')
                                throw new Error('channel');
                            return { label: o.label.slice(0, 100), value: o.value };
                        }) };
                }) };
        });
        if (this.current(revision))
            this.store.notifications = mapped;
    }
    async requestAction(action: string, value: string): Promise<void> {
        if (!this.ports.active() || this.store.busy || this.store.loading || !['read', 'countries', 'birthdate', 'gender', 'customGender', 'country', 'aiRead', 'aiTopic', 'aiAll', 'activityRead', 'activityClose', 'privateProfile', 'searchPrivacy', 'notifications'].includes(action))
            return;
        const write: boolean = ['birthdate', 'gender', 'customGender', 'country', 'aiTopic', 'aiAll', 'activityClose', 'privateProfile', 'searchPrivacy'].includes(action);
        this.bind();
        if (write && this.uncertain.size) {
            this.store.writeUncertain = true;
            this.store.error = PinmonyI18n.message('请先重新读取核对保存结果');
            return;
        }
        this.revision++;
        this.client.cancel();
        this.token = ++this.store.token;
        this.screen = this.store.screen;
        const revision: number = this.revision;
        this.pending = '';
        this.sent = false;
        this.value = this.store.data?.page === this.page ? JSON.parse(JSON.stringify(this.store.data)) as PinmonyAccountSettings : this.empty();
        this.value.token = this.token;
        this.value.saved = false;
        this.value.error = '';
        this.owned = true;
        this.store.busy = write;
        this.store.loading = !write;
        this.store.error = '';
        try {
            this.client.user = '';
            this.client.viewer = '';
            this.client.permissions = [];
            const identity: Identity = { field_set_key: 'profile', username: this.page.slice(this.origin.length).split('/')[1] }, proof: ProfileSettingsResponse = await this.request('UserResource', 'get', identity, this.page.slice(this.origin.length), revision), u: User = proof.resource_response!.data as User;
            if (!u || u.type !== 'user' || !/^\d{1,40}$/.test(u.id) || u.username !== identity.username || proof.client_context?.user?.id !== u.id)
                throw new Error('identity');
            this.client.user = u.id;
            this.client.viewer = u.id;
            this.client.permissions = ['own'];
            if (action === 'notifications') {
                this.store.notifications = [];
                await this.notify(revision);
                return;
            }
            let response: ProfileSettingsResponse = await this.request('UserSettingsResource', 'get', this.emptyOptions(), '/settings/account-settings/', revision);
            this.map(response.resource_response!.data as User);
            if (!this.value.birthdate && action === 'read') {
                const o: Api = { url: '/v3/users/settings/', data: this.emptyOptions() };
                response = await this.request('ApiResource', 'get', o, '/settings/edit/birthdate/', revision);
                this.map(response.resource_response!.data as User);
            }
            if (action === 'countries' || action === 'country') {
                response = await this.request('CountriesResource', 'get', this.emptyOptions(), '/settings/edit/country-region/', revision);
                const countries: Country[] = response.resource_response!.data as Country[];
                if (!Array.isArray(countries) || countries.length > 400 || countries.some((c: Country): boolean => !c || !/^[A-Z]{2}$/.test(c.key) || typeof c.name !== 'string'))
                    throw new Error('countries');
                this.value.countries = countries.map((c: Country): Country => ({ key: c.key, name: c.name.slice(0, 160) }));
                this.client.allowed = countries.map((c: Country): string => 'country:' + c.key);
            }
            if (['aiRead', 'aiTopic', 'aiAll'].includes(action)) {
                const read: Api = { url: '/v3/users/settings/gen_ai/', data: this.emptyOptions() };
                response = await this.request('ApiResource', 'get', read, '/edit/gen-ai-interests/', revision);
                const raw: Topic[] = response.resource_response!.data as Topic[];
                this.value.topics = this.topics(raw);
                this.uncertain.forEach((expected: string, key: string): void => {
                    if (!key.startsWith('ai:'))
                        return;
                    const parts: string[] = key.slice(3).split(','), desired: boolean = expected === 'true';
                    if (parts.every((k: string): boolean => this.value!.topics.some((t: PinmonyAiTopic): boolean => t.key === k && t.enabled === desired)))
                        this.uncertain.delete(key);
                });
                if (action !== 'aiRead') {
                    const choice: AiChoice = action === 'aiTopic' ? JSON.parse(value) as AiChoice : { enabled: value === 'true' };
                    if (typeof choice.enabled !== 'boolean' || action === 'aiAll' && !['true', 'false'].includes(value))
                        throw new Error('input');
                    const selected: Topic[] = raw.filter((t: Topic): boolean => action === 'aiAll' || t.key === choice.key);
                    if (!selected.length)
                        throw new Error('topic');
                    const ids: string[] = [];
                    selected.forEach((t: Topic): void => t.interest_ids.forEach((id: string | number): void => {
                        if (!ids.includes(String(id)))
                            ids.push(String(id));
                    }));
                    if (ids.length > 80 || !ids.length)
                        throw new Error('ids');
                    this.client.allowed = ids.map((id: string): string => 'topic:' + id);
                    const update: AiUpdate = { gen_ai_topics_update_source: 'hf_tuner' };
                    if (choice.enabled)
                        update.gen_ai_topics_opt_in = ids;
                    else
                        update.gen_ai_topics_opt_out = ids;
                    const body: Api = { url: '/v3/users/settings/', data: update };
                    this.pending = 'ai:' + selected.map((t: Topic): string => t.key).join(',');
                    this.uncertain.set(this.pending, choice.enabled.toString());
                    this.sent = true;
                    response = await this.request('ApiResource', 'create', body, '/edit/gen-ai-interests/', revision);
                    const result: User = response.resource_response!.data as User;
                    if (!Array.isArray(result?.gen_ai_topics_opt_out) || ids.some((id: string): boolean => result.gen_ai_topics_opt_out!.map(String).includes(id) === choice.enabled))
                        throw new Error('result');
                    response = await this.request('ApiResource', 'get', read, '/edit/gen-ai-interests/', revision);
                    this.value.topics = this.topics(response.resource_response!.data as Topic[]);
                    if (!selected.every((t: Topic): boolean => this.value!.topics.some((row: PinmonyAiTopic): boolean => row.key === t.key && row.enabled === choice.enabled)))
                        throw new Error('readback');
                    this.uncertain.delete(this.pending);
                    this.sent = false;
                    this.value.saved = true;
                }
            }
            else if (action === 'activityRead' || action === 'activityClose') {
                if (action === 'activityClose' && (!/^\d{1,40}$/.test(value) || this.activityUnknown.has(value) || this.activityClosed.has(value) || !this.store.data?.activities.some((p: PinmonyRecentActivity): boolean => p.id === value)))
                    throw new Error('activity');
                const options: ActivityOptions = { username: 'me', filter_type: 'all' };
                response = await this.request('UserRecentActivityResource', 'get', options, '/edit/activity/', revision);
                const pins: Pin[] = response.resource_response!.data as Pin[];
                if (!Array.isArray(pins) || pins.length > 100)
                    throw new Error('pins');
                this.value.activities = pins.map((p: Pin): PinmonyRecentActivity => {
                    const im: Image | undefined = p.images?.['474x'] || p.images?.['236x'] || p.images?.orig;
                    if (!/^\d{1,40}$/.test(p.id) || !im || !/^https:\/\/(?:[^/.]+\.)?pinimg\.com\//.test(im.url))
                        throw new Error('pin');
                    return { id: p.id, title: (p.grid_title || p.title || p.description || '').slice(0, 300), image: im.url, width: im.width! > 0 ? im.width! : 236, height: im.height! > 0 ? im.height! : 300, recommendationClosed: this.activityClosed.has(p.id), closeUncertain: this.activityUnknown.has(p.id) };
                });
                this.value.activityBookmark = (response.resource_response!.bookmark || '').slice(0, 4096);
                this.value.activityHasMore = !!this.value.activityBookmark && this.value.activityBookmark !== '-end-';
                if (action === 'activityClose') {
                    if (!this.value.activities.some((p: PinmonyRecentActivity): boolean => p.id === value))
                        throw new Error('activity');
                    this.client.allowed = ['pin:' + value];
                    const data: ActivityFeedback = { pin: value, feedback_type: 4, through_id: value, rec_reason_type: 4 }, options: Api = { url: '/v3/pfy/' + value + '/feedback/', data: data };
                    this.pending = 'activity:' + value;
                    this.activityUnknown.add(value);
                    this.uncertain.set(this.pending, value);
                    this.sent = true;
                    response = await this.request('ApiResource', 'update', options, '/edit/activity/', revision);
                    const result: Pin = response.resource_response!.data as Pin;
                    if (response.resource_response?.endpoint_name !== 'v3_provide_pfy_pin_feedback' || result?.id !== value || result.type !== 'pin')
                        throw new Error('feedback');
                    this.activityUnknown.delete(value);
                    this.activityClosed.add(value);
                    this.uncertain.delete(this.pending);
                    this.sent = false;
                    this.value.activities.forEach((p: PinmonyRecentActivity): void => {
                        if (p.id === value) {
                            p.recommendationClosed = true;
                            p.closeUncertain = false;
                        }
                    });
                    this.value.saved = true;
                }
            }
            else if (write) {
                const update: Update = { surface_tag: 'settings' };
                if (action !== 'birthdate')
                    update.user_id = this.client.viewer;
                let field: string = action;
                if (action === 'birthdate') {
                    if (this.date(value) !== value)
                        throw new Error('date');
                    update.birthdate = value;
                }
                else if (action === 'gender') {
                    if (!['female', 'male', 'unspecified'].includes(value))
                        throw new Error('gender');
                    update.gender = value;
                }
                else if (action === 'customGender') {
                    if (this.value.gender !== 'unspecified' || !value.trim() || value.length > 500)
                        throw new Error('custom');
                    update.custom_gender = value;
                    field = 'custom_gender';
                }
                else if (action === 'country') {
                    if (!this.value.countries.some((c: Country): boolean => c.key === value))
                        throw new Error('country');
                    update.country = value;
                }
                else {
                    if (!['true', 'false'].includes(value) || action === 'privateProfile' && !this.value.canChangePrivacy || action === 'searchPrivacy' && !this.value.canEditSearchPrivacy)
                        throw new Error('permission');
                    if (action === 'privateProfile') {
                        field = 'opt_in_private_account';
                        update.opt_in_private_account = value === 'true';
                        update.user_confirm_skip_passcode = false;
                    }
                    else {
                        field = 'exclude_from_search';
                        update.exclude_from_search = value === 'true';
                    }
                }
                this.pending = action;
                this.uncertain.set(action, value);
                this.sent = true;
                const source: string = ['privateProfile', 'searchPrivacy'].includes(action) ? '/settings/profile-visibility/' : '/settings/edit/' + (action === 'country' ? 'country-region' : action === 'customGender' ? 'gender' : action) + '/';
                response = await this.request('UserSettingsResource', 'update', update, source, revision);
                const result: Record<string, Object> = response.resource_response!.data as Record<string, Object>;
                if (result?.[field] !== (['privateProfile', 'searchPrivacy'].includes(action) ? value === 'true' : value))
                    throw new Error('result');
                if (['privateProfile', 'searchPrivacy'].includes(action)) {
                    response = await this.request('UserSettingsResource', 'get', this.emptyOptions(), '/settings/profile-visibility/', revision);
                    this.map(response.resource_response!.data as User);
                    if (this.uncertain.has(action))
                        throw new Error('readback');
                }
                else {
                    if (action === 'birthdate')
                        this.value.birthdate = value;
                    else if (action === 'gender')
                        this.value.gender = value;
                    else if (action === 'customGender')
                        this.value.customGender = value;
                    else
                        this.value.country = value;
                    this.uncertain.delete(action);
                }
                this.sent = false;
                this.value.saved = true;
            }
            this.commit(revision);
        }
        catch (error) {
            if (this.current(revision)) {
                if (error instanceof ProfileSettingsRejected && this.pending) {
                    this.uncertain.delete(this.pending);
                    if (this.pending.startsWith('activity:'))
                        this.activityUnknown.delete(this.pending.slice(9));
                    this.sent = false;
                }
                this.store.error = this.sent ? '保存结果未确认，请重新读取核对；不会自动重试保存' : error instanceof ProfileSettingsRejected ? '网站拒绝了本次操作' : write ? '未能确认当前设置或权限，请重新读取后重试' : PinmonyI18n.message('读取失败，请重试');
                if (this.value) {
                    this.value.error = this.store.error;
                    this.commit(revision);
                }
                this.store.writeUncertain = this.uncertain.size > 0;
            }
        }
        finally {
            if (this.current(revision)) {
                this.store.busy = false;
                this.store.loading = false;
                this.owned = false;
                this.sent = false;
                this.pending = '';
            }
        }
    }
}
