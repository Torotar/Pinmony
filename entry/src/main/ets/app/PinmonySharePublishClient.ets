import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
function diagnosticResourcePresent(body: string): boolean {
    try { const value: DraftDiagnostic = JSON.parse(body) as DraftDiagnostic; return !!value.resource_response; } catch (_) { return false; }
}
let requestSequence: number = 0;
export const PIN_NATIVE_SHARE_PUBLISH_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
export interface PinmonySharePublishClientPorts {
    session: () => PinmonyBusinessSessionContext;
    network: () => PinmonyNativeNetwork;
}
export interface PinmonySharePublishOwner {
    page: string;
    mode: string;
    objectId: string;
    viewer: string;
    contacts: string[];
    topics?: string[];
    sections?: string[];
    boards: string[];
}
interface DraftDiagnostic { resource_response?: DraftDiagnosticResource; error?: Object; status?: string; code?: number; }
interface DraftDiagnosticError { code?: number; message?: string; }
interface DraftDiagnosticResource { code?: number; endpoint_name?: string; status?: string; error?: DraftDiagnosticError; message?: string; }
interface Envelope {
    options: Object;
    context: Record<string, string>;
}
export class PinmonyBusinessRejection extends Error {
}
// No credentials, payloads or response data are logged or persisted here.
export class PinmonySharePublishClient {
    private readonly ports: PinmonySharePublishClientPorts;
    private waits: Map<string, () => void> = new Map();
    constructor(ports: PinmonySharePublishClientPorts) { this.ports = ports; }
    cancel(): void { this.waits.forEach((release: () => void, id: string): void => { this.ports.network().cancel(id); release(); }); this.waits.clear(); }
    async request(owner: PinmonySharePublishOwner, name: string, verb: string, options: Object, source: string, handler: string, current: () => boolean): Promise<string> {
        const session: PinmonyBusinessSessionContext = this.ports.session();
        if (!current() || !session.authenticated)
            throw new Error('stale');
        const graph: boolean = name === 'graphql', get: boolean = verb === 'get', envelope: Envelope = { options: options, context: {} }, form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
        const job: PinmonyNetworkJob = { id: 'native_share_publish_' + (++requestSequence).toString() + '_' + Date.now().toString(), epoch: session.generation, page: owner.page,
            url: session.origin + (graph ? '/_/graphql/' : '/resource/' + name + '/' + verb + '/' + (get ? '?' + form : '')), method: get ? 'GET' : 'POST', body: get ? '' : graph ? JSON.stringify(options) : form,
            headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-AppState': 'active', 'X-Pinterest-Source-Url': source, 'X-Pinterest-Pws-Handler': handler, 'Content-Type': graph ? 'application/json' : 'application/x-www-form-urlencoded' } };
        if (session.appVersion)
            job.headers['X-App-Version'] = session.appVersion;
        const stopped: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => { this.waits.set(job.id, (): void => resolve(undefined)); });
        try {
            const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessSharePublish(job, (): PinmonyBusinessSessionContext => this.ports.session(), owner.mode, owner.objectId, owner.viewer, owner.contacts, owner.boards, current, owner.topics || [], owner.sections || []), stopped]);
            if (!current() || !reply || reply.error || !reply.body || reply.body.length > 8000000)
                throw new Error('request');
            if (reply.status < 200 || reply.status >= 300) {
                if (name === 'ApiResource' && (verb === 'create' || verb === 'update') && owner.mode === 'photo') {
                    let code: number = -1;
                    let endpoint: string = 'unknown';
                    let category: string = 'unknown';
                    try {
                        const diagnostic: DraftDiagnostic = JSON.parse(reply.body) as DraftDiagnostic;
                        if (typeof diagnostic.resource_response?.code === 'number') code = diagnostic.resource_response.code;
                        const resource: DraftDiagnosticResource | undefined = diagnostic.resource_response;
                        if (typeof resource?.error?.code === 'number') code = resource.error.code;
                        const message: string = (resource?.error?.message || resource?.message || '').toLowerCase();
                        if (/not found|does not exist/.test(message)) category = 'not-found';
                        else if (/csrf/.test(message)) category = 'csrf';
                        else if (/permission|unauthorized|forbidden/.test(message)) category = 'permission';
                        else if (/image|media|upload/.test(message)) category = 'media';
                        else if (/invalid|parameter|argument/.test(message)) category = 'invalid-input';
                        const value: string = resource?.endpoint_name || '';
                        if (/^[a-z_]{1,80}$/.test(value)) endpoint = value;
                    } catch (_) {}
                    PinmonyRuntimeLog.warn('DraftSaveTrace: http=' + reply.status.toString() + ' code=' + code.toString() + ' endpoint=' + endpoint + ' category=' + category + ' responsePresent=' + (!!diagnosticResourcePresent(reply.body)).toString());
                }
                throw new Error('http');
            }
            return reply.body;
        }
        finally {
            this.waits.delete(job.id);
        }
    }
}
