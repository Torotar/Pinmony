import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
export const PIN_NATIVE_PROFILE_SETTINGS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
export interface ProfileSettingsPorts {
    session: () => PinmonyBusinessSessionContext;
    network: () => PinmonyNativeNetwork;
}
export interface ProfileSettingsUser {
    id: string;
    username?: string;
}
export interface ProfileSettingsResource {
    status: string;
    code?: number;
    endpoint_name?: string;
    error?: Object;
    data: Object | null;
    bookmark?: string;
}
interface ResourceOptions {
    options?: ResourceBookmarks;
}
interface ResourceBookmarks {
    bookmarks?: string[];
}
export interface ProfileSettingsResponse {
    resource?: ResourceOptions;
    resource_response?: ProfileSettingsResource;
    data?: Object;
    errors?: Object[];
    client_context?: ProfileSettingsContext;
}
interface ProfileSettingsContext {
    user?: ProfileSettingsUser;
    is_authenticated?: boolean;
}
interface Envelope {
    options: Object;
    context: Record<string, string>;
}
export class ProfileSettingsRejected extends Error {
}
let sequence: number = 0;
// Credentials remain in the existing native adapter. No account data is persisted here.
export class PinmonyProfileSettingsClient {
    private readonly ports: ProfileSettingsPorts;
    private waits: Map<string, () => void> = new Map();
    user: string = '';
    viewer: string = '';
    allowed: string[] = [];
    permissions: string[] = [];
    constructor(ports: ProfileSettingsPorts) { this.ports = ports; }
    cancel(): void { this.waits.forEach((release: () => void, id: string): void => { this.ports.network().cancel(id); release(); }); this.waits.clear(); }
    async request(page: string, name: string, verb: string, options: Object, source: string, current: () => boolean, postRead: boolean = false): Promise<ProfileSettingsResponse> {
        if (!current())
            throw new Error('stale');
        const s: PinmonyBusinessSessionContext = this.ports.session(), graph: boolean = name === 'graphql', get: boolean = verb === 'get' && !postRead, envelope: Envelope = { options: options, context: {} }, form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
        const job: PinmonyNetworkJob = { id: 'native_profile_settings_' + (++sequence).toString(), epoch: s.generation, page: page, url: s.origin + (graph ? '/_/graphql/' : '/resource/' + name + '/' + verb + '/' + (get ? '?' + form : '')), method: get ? 'GET' : 'POST', body: get ? '' : graph ? JSON.stringify(options) : form, headers: { 'Accept': 'application/json', 'Content-Type': graph ? 'application/json' : 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-AppState': 'active', 'X-Pinterest-Pws-Handler': 'www/index.js', 'X-Pinterest-Source-Url': source } };
        if (s.appVersion)
            job.headers['X-App-Version'] = s.appVersion;
        const cancelled: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => { this.waits.set(job.id, (): void => resolve(undefined)); });
        try {
            const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessProfileSettings(job, (): PinmonyBusinessSessionContext => this.ports.session(), page, this.user, this.viewer, this.allowed, this.permissions, current), cancelled]);
            if (!current() || !reply || reply.error || reply.status < 200 || reply.status >= 300 || !reply.body || reply.body.length > 8000000)
                throw new Error('request');
            const body: ProfileSettingsResponse = JSON.parse(reply.body) as ProfileSettingsResponse;
            if (body.client_context?.is_authenticated === false || this.viewer && body.client_context?.user && body.client_context.user.id !== this.viewer)
                throw new Error('identity');
            if (!graph) {
                const r: ProfileSettingsResource | undefined = body.resource_response;
                if (!r || r.status !== 'success' || r.code !== 0 && !(r.code === undefined && r.endpoint_name === 'v3_get_settings_all_notifications') || r.error) {
                    if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)
                        throw new ProfileSettingsRejected('网站拒绝了本次操作');
                    throw new Error('business');
                }
            }
            return body;
        }
        finally {
            this.waits.delete(job.id);
        }
    }
}
