import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute, PinmonyTransferReply, PinmonySearchProductRoute } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';

interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface NativeSearchApiOptions { url: string; data: Record<string,Object>; }
interface SearchDiscoveryVariables { count?: number; cursor?: string; }
interface SearchDiscoveryQuery { queryHash: string; variables: SearchDiscoveryVariables; }
export interface PhotoSearchRegion { x: number; y: number; w: number; h: number; }
interface PhotoHistoryCreateReply { success: boolean; status: string; code: number; endpoint_name: string; data: Object; }
interface PhotoHistoryOptions { url: string; data: Record<string, string>; bookmarks?: string[]; }
interface PhotoHistoryEnvelope { options: PhotoHistoryOptions; context: Record<string, string>; }
interface PhotoHistoryDeleteEnvelope { options: PhotoHistoryDeleteOptions; context: Record<string, string>; }
interface PhotoHistoryDeleteOptions { url: string; data: PhotoHistoryDeleteData; }
interface PhotoHistoryDeleteData { lens_history_ids: string[]; }

export class PinmonySearchNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
async requestBusinessSearchUserFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, user: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const m: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(m ? m[2] : '')) as NativeSearchEnvelope;
      const o: Record<string, Object | null> = e.options, source: string = page.slice(captured.origin.length);
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && owner() && captured.authenticated && !!captured.accountId &&
        /^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) && page.startsWith(captured.origin + '/') &&
        /^\/[A-Za-z0-9_]+\/$/.test(page.slice(captured.origin.length)) && /^\d{1,40}$/.test(user) && user !== viewer && /^\d{1,40}$/.test(viewer) &&
        job.id.startsWith('native_search_user_follow_') && job.epoch === captured.generation && job.page === page && job.method === 'POST' &&
        [captured.origin + '/resource/ApiResource/update/',captured.origin + '/resource/ApiResource/delete/'].includes(job.url) &&
        !!m && decodeURIComponent(m[1]) === source && Object.keys(e).length === 2 && !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && Object.keys(e.context).length === 0 &&
        o['url'] === '/v3/users/' + user + '/follow/' &&
        (job.url.endsWith('/update/') ? Object.keys(o).length === 2 && !!o['data'] && typeof o['data'] === 'object' && !Array.isArray(o['data']) && Object.keys(o['data'] as Object).length === 0 : Object.keys(o).length === 1) &&
        job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/[username].js' && job.headers['X-Pinterest-Source-Url'] === source;
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated: permitted && owner() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: captured.generation, page: page, userAgent: actual.userAgent };});
  }

async requestBusinessSearchRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const source: string = job.method === 'POST' ? job.body : job.url.slice(job.url.indexOf('?') + 1);
      const raw: RegExpMatchArray | null = source.match(/(?:^|&)data=([^&]+)/);
      const route: RegExpMatchArray | null = source.match(/(?:^|&)source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(raw ? raw[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options; const keys: string[] = Object.keys(o);
      const path: string = job.page.slice(captured.origin.length);
      const queryMatch: RegExpMatchArray | null = path.match(/[?&]q=([^&#]*)/);
      const query: string = queryMatch ? decodeURIComponent(queryMatch[1].replace(/\+/g,' ')).trim() : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_search_read_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/search/') &&
        /^\/search\/(?:(pins|videos|boards|users|buyable_pins)\/)?(?:\?[^#]*)?$/.test(path) && query.length <= 300 &&
        !/[?&](?:filters|filter|shopping|color|video|filter_genai|applied_unified_filters)=/.test(path) &&
        !!route && decodeURIComponent(route[1]) === path && !Array.isArray(payload.context) && Object.keys(payload).length === 2 && Object.keys(payload.context).length === 0 &&
        !Array.isArray(o) && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js';
      if (job.url === captured.origin + '/resource/BaseSearchResource/get/' && job.method === 'POST') {
        const allowed: string[] = ['query','scope','appliedProductFilters','domains','user','seoDrawerEnabled','applied_unified_filters','auto_correction_disabled','filter_genai','journey_depth','source_id','source_module_id','source_url','static_feed','selected_one_bar_modules','query_pin_sigs','page_size','gated','price_max','price_min','query_image_pins','request_params','top_pin_ids','article','corpus','filters','rs','bookmarks'];
        const bookmarks: string[] = o['bookmarks'] as string[];
        const scope: string = path.split('?')[0].split('/')[2] || 'pins';
        const product: PinmonySearchProductRoute | undefined = readNativeSearchProductRoute(job.page);
        const nulls: string[] = ['user','applied_unified_filters','journey_depth','source_module_id','selected_one_bar_modules','query_pin_sigs','gated','query_image_pins','request_params','article','corpus','filters'];
        permitted = basic && keys.length >= 27 && keys.length <= 28 && keys.every((key: string): boolean => allowed.includes(key)) &&
          query.length > 0 && o['query'] === query && o['scope'] === scope && o['source_url'] === path && o['page_size'] === 25 &&
          !!product && o['appliedProductFilters'] === product.applied && o['domains'] === product.domains && o['price_min'] === product.priceMin && o['price_max'] === product.priceMax && o['seoDrawerEnabled'] === false && o['auto_correction_disabled'] === false && o['filter_genai'] === false && o['static_feed'] === false &&
          nulls.every((key: string): boolean => o[key] === null) && typeof o['source_id'] === 'string' && typeof o['rs'] === 'string' &&
          (o['top_pin_ids'] === null || typeof o['top_pin_ids'] === 'string') &&
          (bookmarks === undefined || Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && bookmarks[0].length > 0 && bookmarks[0].length <= 4096);
      } else if (job.url.startsWith(captured.origin + '/resource/AdvancedTypeaheadResource/get/?') && job.method === 'GET' && job.body === '') {
        const allowed: string[] = ['field_set_key','limit','num_recent_queries','personal_search_only','pin_scope','recent_queries_tags','term','autocomplete_request_surface'];
        permitted = basic && keys.length === 8 && keys.every((key: string): boolean => allowed.includes(key)) && o['field_set_key'] === 'richResults' && o['limit'] === 8 && o['num_recent_queries'] === 20 && o['personal_search_only'] === false && o['pin_scope'] === 'pins' && o['recent_queries_tags'] === 'recent_queries,recent_personal_searches' && o['autocomplete_request_surface'] === 0 && typeof o['term'] === 'string' && (o['term'] as string).length <= 300;
      } else {
        const api: NativeSearchApiOptions = o as Object as NativeSearchApiOptions;
        permitted = basic && !Array.isArray(api.data) && keys.length === 2 && keys.includes('url') && keys.includes('data') &&
          (api.url === '/v3/search/ghost_queries/' && job.method === 'GET' && job.body === '' && job.url.startsWith(captured.origin + '/resource/ApiResource/get/?') && Object.keys(api.data).length === 0 ||
           api.url === '/v3/filters/' && job.method === 'POST' && job.url === captured.origin + '/resource/ApiResource/get/' && Object.keys(api.data).length === 1 && typeof api.data['bookmark_string'] === 'string' && (api.data['bookmark_string'] as string).length > 0 && (api.data['bookmark_string'] as string).length <= 4096);
      }
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent }; });
  }

async requestBusinessSearchDiscoveryRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    // Discovery uses the same mobile content contract on phones and tablets.
    // Preserve the active engine versions and credentials; normalize only the
    // tablet device tokens for this read, never the login host or other APIs.
    const mobileAgent = (agent: string): string => {
      if (!/\bArkWeb\/[0-9.]+/.test(agent) || !/\bTablet\b/.test(agent)) return agent;
      let normalized: string = agent.replace(/\bTablet\b/g, 'Phone');
      if (!/\bMobile\b/.test(normalized)) normalized = normalized.replace(/\bSafari\//, 'Mobile Safari/');
      return normalized;
    };
    PinmonyRuntimeLog.info('SearchDiscoveryTrace: phase=context tablet=' + /\bTablet\b/.test(captured.userAgent).toString() +
      ' mobile=' + /\bMobile\b/.test(captured.userAgent).toString() +
      ' normalized=' + (mobileAgent(captured.userAgent) !== captured.userAgent).toString());
    try {
      const query: SearchDiscoveryQuery = JSON.parse(job.body) as SearchDiscoveryQuery;
      const variables: SearchDiscoveryVariables = query.variables;
      const keys: string[] = Object.keys(variables);
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId &&
        job.id.startsWith('native_search_discovery_') && job.epoch === captured.generation &&
        (job.page === captured.origin + '/search/' || job.page === captured.origin + '/search') &&
        job.url === captured.origin + '/_/graphql/' && job.method === 'POST' && Object.keys(query).length === 2 &&
        job.headers['Content-Type'] === 'application/json' && typeof variables === 'object' && variables !== null && !Array.isArray(variables) &&
        ((query.queryHash === 'a0959c548d14cf06adbc04230c8151f3aec27082f8328131fbf4ac52af844041' && keys.length === 0) ||
         (query.queryHash === 'a53e4b9faaa4d08b5450d8a2f60945e513d19f0273c6175ed3a6560c70f22b4b' && keys.length === 2 &&
          keys.every((key: string): boolean => key === 'count' || key === 'cursor') && variables.count === 6 &&
          typeof variables.cursor === 'string' && variables.cursor.length > 0 && variables.cursor.length <= 4096));
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,
        epoch: captured.generation, page: job.page, userAgent: mobileAgent(actual.userAgent) };
    });
  }

async readPhotoHistory(cursor: string, imageUrl: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<ArrayBuffer> {
    const state: PinmonyBusinessSessionContext = session();
    const account: string = state.accountId, epoch: number = state.generation, origin: string = state.origin, generation: number = this.transport.currentGeneration();
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = session();
      return this.transport.isForeground() && owner() && generation === this.transport.currentGeneration() && actual.authenticated &&
        actual.accountId === account && actual.generation === epoch && actual.origin === origin;
    };
    if (!PIN_BUSINESS_PIN_READ_ENABLED || !current() || !account || !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin) ||
      !/^native_photo_history_\d+$/.test(id) || cursor.length > 4096 || !this.transport.transferAvailable(id) ||
      imageUrl && !/^https:\/\/i\.pinimg\.com\/[A-Za-z0-9_/.%-]+\.(?:jpg|jpeg|png|webp)$/i.test(imageUrl)) throw new Error('history-unavailable');
    const options: PhotoHistoryOptions = { url: '/v3/visual_search/lens/history/', data: {} };
    if (cursor) options.bookmarks = [cursor];
    const envelope: PhotoHistoryEnvelope = { options: options, context: {} };
    const source: string = '/?search_box_open=true';
    const url: string = imageUrl || origin + '/resource/ApiResource/get/?source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const headers: Record<string, string> = {};
    if (!imageUrl) { headers['X-Pinterest-Source-Url'] = source; headers['X-Pinterest-Pws-Handler'] = 'www/index.js'; }
    const response: PinmonyTransferReply = await this.transport.transfer({ id: id, url: url, method: 'GET', page: origin + '/search/',
      userAgent: state.userAgent, authenticated: !imageUrl, headers: headers, timeoutMs: 30000, maxBytes: 8 * 1024 * 1024 }, current);
    if (!current() || response.status !== 200) throw new Error('history-response');
    return response.bytes;
  }

async deletePhotoHistory(ids: string[], page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<ArrayBuffer> {
    const state: PinmonyBusinessSessionContext = session();
    const generation: number = this.transport.currentGeneration();
    const live = (): boolean => {
      const actual: PinmonyBusinessSessionContext = session();
      return this.transport.isForeground() && owner() && generation === this.transport.currentGeneration() && actual.authenticated &&
        actual.accountId === state.accountId && actual.generation === state.generation && actual.origin === state.origin;
    };
    if (!PIN_BUSINESS_PIN_READ_ENABLED || !live() || !state.accountId || !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(state.origin) ||
      !page.startsWith(state.origin + '/search/') || !/^native_photo_history_delete_\d+$/.test(id) || !this.transport.transferAvailable(id) ||
      ids.length < 1 || ids.length > 1000 || new Set<string>(ids).size !== ids.length ||
      !ids.every((value: string): boolean => /^[A-Za-z0-9_-]{1,200}$/.test(value))) throw new Error('history-delete-unavailable');
    const url: string = state.origin + '/resource/ApiResource/delete/';
    const source: string = page.slice(state.origin.length);
    const payload: PhotoHistoryDeleteEnvelope = { options: { url: '/v3/visual_search/lens/history/', data: { lens_history_ids: ids } }, context: {} };
    const body: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(payload));
    const response: PinmonyTransferReply = await this.transport.transfer({ id: id, url: url, method: 'POST', page: page,
      userAgent: state.userAgent, authenticated: true, headers: { 'Content-Type': 'application/x-www-form-urlencoded',
        'X-Pinterest-Source-Url': source, 'X-Pinterest-Pws-Handler': 'www/search/[scope].js' }, body: body,
      timeoutMs: 30000, maxBytes: 1024 * 1024 }, live);
    if (!live() || response.status !== 200) throw new Error('history-delete-response');
    return response.bytes;
  }

async searchUploadedPhoto(bytes: ArrayBuffer, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string, crop?: PhotoSearchRegion): Promise<string> {
    return this.uploadPhoto(bytes, page, session, owner, id, crop);
  }

async saveUploadedPhotoHistory(bytes: ArrayBuffer, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<void> {
    const text: string = await this.uploadPhoto(bytes, page, session, owner, id, undefined, true);
    const result: PhotoHistoryCreateReply = JSON.parse(text) as PhotoHistoryCreateReply;
    if (result.success !== true || result.status !== 'success' || result.code !== 0 ||
      result.endpoint_name !== 'v3_create_lens_history' || !result.data || Array.isArray(result.data) || typeof result.data !== 'object') throw new Error('history-save-unconfirmed');
  }

private async uploadPhoto(bytes: ArrayBuffer, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string, crop?: PhotoSearchRegion, history: boolean = false): Promise<string> {
    const region: PhotoSearchRegion = crop || { x: 0, y: 0, w: 1, h: 1 };
    if (![region.x, region.y, region.w, region.h].every((n: number): boolean => Number.isFinite(n)) ||
      region.x < 0 || region.y < 0 || region.w < 0.08 || region.h < 0.08 ||
      region.x + region.w > 1.00001 || region.y + region.h > 1.00001) throw new Error('photo-region');
    const state: PinmonyBusinessSessionContext = session();
    const account: string = state.accountId, epoch: number = state.generation, origin: string = state.origin;
    const generation: number = this.transport.currentGeneration();
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = session();
      return generation === this.transport.currentGeneration() && this.transport.isForeground() && owner() && actual.authenticated &&
        actual.accountId === account && actual.generation === epoch && actual.origin === origin;
    };
    const head: Uint8Array = new Uint8Array(bytes);
    if (!current() || !account || !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin) ||
      page !== origin + '/search/' || !/^native_photo_search_\d+$/.test(id) ||
      bytes.byteLength < 12 || bytes.byteLength > 4 * 1024 * 1024 || head[0] !== 255 || head[1] !== 216 ||
      !this.transport.transferAvailable(id)) throw new Error('photo-unavailable');
    const url: string = origin + (history ? '/upload-lens-image-history/' : '/upload-lens-image/');
    const fields: Record<string, string> = {};
    if (history) fields['source_type'] = 'CAMERA_GALLERY';
    else { fields['x'] = region.x.toString(); fields['y'] = region.y.toString(); fields['w'] = region.w.toString(); fields['h'] = region.h.toString(); fields['crop_source'] = '5'; fields['source_type'] = '1'; }
    const response: PinmonyTransferReply = await this.transport.transfer({ id: id, url: url, method: history ? 'PUT' : 'POST', page: page,
      userAgent: state.userAgent, authenticated: true, headers: {}, fields: fields,
      file: { field: 'image', bytes: bytes, mime: 'image/jpeg', name: 'lens-file-image' }, timeoutMs: 30000, maxBytes: 8 * 1024 * 1024 }, current);
    if (!current() || response.status !== 200 || !response.text) throw new Error('photo-unconfirmed');
    return response.text;
  }
}
