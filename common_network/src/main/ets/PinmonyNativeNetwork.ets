import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PinmonySessionCredentials, PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyRequestPolicy, PinmonyRequestPermit } from './PinmonyRequestPolicy';
export interface PinmonySearchProductRoute {
  domains: string | null;
  priceMin: number | null;
  priceMax: number | null;
  applied: string;
}

export function readNativeSearchProductRoute(page: string): PinmonySearchProductRoute | undefined {
  try {
    const values: Map<string,string> = new Map<string,string>();
    for (const part of (page.split('?')[1] || '').split('&')) {
      const fields: string[] = part.split('=');
      const key: string = decodeURIComponent(fields[0] || '');
      if (!['domains','price_min','price_max','filter_location'].includes(key)) continue;
      if(values.has(key) || fields.length !== 2)return undefined;
      values.set(key,decodeURIComponent(fields[1].replace(/\+/g,' ')));
    }
    if(values.size && !/^https:\/\/(?:www|uk)\.pinterest\.com\/search\/buyable_pins\/\?/.test(page))return undefined;
    if(values.has('filter_location') && values.get('filter_location') !== '0')return undefined;
    const domains: string = values.get('domains') || '';
    if(domains.length > 2048 || domains && (domains.split(',').length > 10 || !domains.split(',').every((domain: string): boolean =>
        domain.length <= 253 && /^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/.test(domain))))return undefined;
    const min: string = values.get('price_min') || '', max: string = values.get('price_max') || '';
    if(min && !/^\d{1,9}$/.test(min) || max && !/^\d{1,9}$/.test(max))return undefined;
    const priceMin: number | null = min ? Number(min) : null, priceMax: number | null = max ? Number(max) : null;
    if(priceMin !== null && priceMax !== null && priceMin > priceMax)return undefined;
    return {domains:domains || null,priceMin:priceMin,priceMax:priceMax,applied:'-' + domains + '-' + max + '-' + min};
  } catch (_) {return undefined;}
}

export interface PinmonyNetworkContext {
  authenticated: boolean;
  epoch: number;
  page: string;
  userAgent: string;
}
export interface PinmonyNetworkJob {
  id: string;
  epoch: number;
  page: string;
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
  priority?: Priority;
}
export interface PinmonyNetworkReply {
  id: string;
  epoch: number;
  page: string;
  status: number;
  body: string;
  url: string;
  error: string;
  headers: Record<string, string>;
}

export interface PinmonyTransferFile { field: string; bytes: ArrayBuffer; mime: string; name: string; }
export interface PinmonyTransferJob {
  id: string; url: string; method: string; page: string; userAgent: string;
  authenticated: boolean; headers: Record<string, string>; body?: string | ArrayBuffer;
  fields?: Record<string, string>; file?: PinmonyTransferFile;
  timeoutMs: number; maxBytes: number;
}
export interface PinmonyTransferReply { status: number; text: string; bytes: ArrayBuffer; }

// Only contracts already used by Pinmony are permitted. No arbitrary native URL proxy.
const RESOURCES: string[] = ['UserHomefeedResource', 'BoardContentRecommendationResource', 'BoardResource',
  'BoardFeedResource', 'BoardSectionsResource', 'BoardSectionPinsResource', 'BoardSectionResource',
  'UserPinsResource', 'UserResource', 'BoardsResource', 'BoardsFeedResource',
  'UserSettingsResource', 'CountriesResource', 'UserRecentActivityResource', 'UserFollowingResource', 'UserActivityPinsResource', 'BoardlessPinsResource', 'PinResource', 'RelatedModulesResource', 'VisualSearchFlashlightUnifiedResource',
  'NewsHubDetailsResource', 'SearchTabResource', 'AdvancedTypeaheadResource', 'BaseSearchResource', 'UserExperienceResource', 'ApiResource', 'ConversationMessagesResource',
  'ConversationsResource', 'BoardInvitesResource', 'BoardInviteResource', 'ShareSuggestionsResource', 'ShareSuggestionsTypeaheadResource',
  'FindPinImagesResource', 'UserSessionResource', 'BoardPickerBoardsResource', 'UnifiedCommentsResource', 'UnifiedCommentsPreviewResource',
  'AggregatedCommentReplyFeedResource', 'AggregatedCommentReplyResource', 'AggregatedCommentResource', 'DidItCommentsResource', 'RepinResource'];
interface SessionVerificationOptions { url: string; data: Record<string, string>; field_sets: string[]; }
interface SessionVerificationEnvelope { options: SessionVerificationOptions; context: Record<string, string>; }
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface PinmonyGraphQuery {
  queryHash: string;
  variables: Object;
}
interface BoardInviteAcceptPayload {
  options: BoardInviteAcceptOptions;
  context: Object;
}
interface BoardInviteAcceptOptions { board_id: string; invited_user_id: string; }
interface BoardSectionCreatePayload { options: BoardSectionCreateOptions; context: Record<string, string>; }
interface BoardSectionCreateOptions { board_id: string; name: string; initial_pins: string[]; }
interface PinmonyResponseDiagnostic {
  resource_response?: PinmonyResourceDiagnostic;
  client_context?: PinmonyAuthenticationDiagnostic;
}
interface PinmonyAuthenticationUserDiagnostic { id?: string; }
interface PinmonyAuthenticationDiagnostic { is_authenticated?: boolean; user?: PinmonyAuthenticationUserDiagnostic; }
interface PinmonyTimingInfo {
  nameLookupTimeMs?: number;
  connectTimeMs?: number;
  tlsHandshakeTimeMs?: number;
  preTransferTimeMs?: number;
  startTransferTimeMs?: number;
  totalTimeMs?: number;
  redirectTimeMs?: number;
}
interface PinmonyResourceDiagnostic {
  status?: string;
  data?: Object;
}
export interface PinmonyPublishImageUpload { signature: string; uploadId: string; }

export function acceptsNetworkJob(job: PinmonyNetworkJob, context: PinmonyNetworkContext): boolean {
  if (!job || typeof job.page !== 'string' || typeof job.url !== 'string' || job.page !== context.page) return false;
  const pageOrigin: RegExpMatchArray | null = job.page.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
  const requestOrigin: RegExpMatchArray | null = job.url.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
  if (!pageOrigin || !requestOrigin || pageOrigin[0] !== requestOrigin[0]) return false;
  // Validate the existing path/body contracts without changing the actual URL
  // used for credentials, dispatch, replies or document ownership.
  const canonicalJob: PinmonyNetworkJob = { id: job.id, epoch: job.epoch,
    page: job.page.replace(pageOrigin[0], 'https://www.pinterest.com'),
    url: job.url.replace(requestOrigin[0], 'https://www.pinterest.com'),
    method: job.method, headers: job.headers, body: job.body };
  const canonicalContext: PinmonyNetworkContext = { authenticated: context.authenticated,
    epoch: context.epoch, page: context.page === job.page ? canonicalJob.page : context.page,
    userAgent: context.userAgent };
  return acceptsCanonicalNetworkJob(canonicalJob, canonicalContext);
}

interface PinmonyAccountBatchFields { fields: string; }
interface PinmonyAccountBatchRequest { uri: string; method: string; params: PinmonyAccountBatchFields; }
interface PinmonyAccountRequestEnvelope { options: Record<string, Object | null>; context: Record<string, string>; }
function acceptsSessionAccountJob(job: PinmonyNetworkJob): boolean {
  try {
    const source: string = '/switch_account/';
    if (job.method !== 'POST' || job.page !== 'https://www.pinterest.com' + source ||
        job.headers['X-Pinterest-Pws-Handler'] !== 'www/switch_account.js' || job.headers['X-Pinterest-Source-Url'] !== source ||
        job.headers['X-Requested-With'] !== 'XMLHttpRequest' || job.headers['Content-Type'] !== 'application/x-www-form-urlencoded') return false;
    const parts: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
    if (!parts || decodeURIComponent(parts[1]) !== source) return false;
    const e: PinmonyAccountRequestEnvelope = JSON.parse(decodeURIComponent(parts[2])) as PinmonyAccountRequestEnvelope;
    if (!e || Object.keys(e).length !== 2 || !e.context || Array.isArray(e.context) || Object.keys(e.context).length || !e.options || Array.isArray(e.options)) return false;
    const o: Record<string, Object | null> = e.options, keys: string[] = Object.keys(o);
    if (job.url === 'https://www.pinterest.com/resource/UserSessionResource/create/') {
      if (keys.length === 1 && o['session_accounts'] === true) return true;
      return keys.length === 8 && o['get_user'] === true && typeof o['switch_account'] === 'string' && /^[1-9]\d{0,39}$/.test(o['switch_account'] as string) &&
        o['app_type_from_client'] === 6 && o['ui_component'] === 'undefined.SwitchAccountPage' && o['handler'] === 'www/switch_account.js' &&
        o['visited_pages_before_login'] === '[]' && o['arkoseSessionToken'] === null && o['recaptchaV3Token'] === null;
    }
    if (job.url !== 'https://www.pinterest.com/resource/ApiResource/create/' || keys.length !== 2 || o['url'] !== '/v3/batch/') return false;
    const data: Record<string, Object> = o['data'] as Record<string, Object>;
    if (!data || Array.isArray(data) || Object.keys(data).length !== 1 || typeof data['requests'] !== 'string') return false;
    const requests: PinmonyAccountBatchRequest[] = JSON.parse(data['requests'] as string) as PinmonyAccountBatchRequest[];
    return Array.isArray(requests) && requests.length > 0 && requests.length <= 20 &&
      new Set<string>(requests.map((item: PinmonyAccountBatchRequest): string => item.uri)).size === requests.length &&
      requests.every((item: PinmonyAccountBatchRequest): boolean => !!item && Object.keys(item).length === 3 && item.method === 'GET' &&
        /^v3\/users\/[1-9]\d{0,39}\/$/.test(item.uri) && !!item.params && Object.keys(item.params).length === 1 && item.params.fields === 'partner.biz_ownership_email,partner.business_name,partner.contact_email,partner.contact_phone,partner.contact_phone_country(),partner.enable_profile_address,partner.enable_profile_message,partner.is_boost_a_pin_partner,partner.is_linked_business,partner.profile_place(),place.country,place.extra_street,place.locality,place.postal_code,place.region,place.street,user.businesses(),user.email,user.fast_advertiser_info_has_any_managed_advertisers,user.full_name,user.id,user.image_medium_url,user.owners(),user.partner(),user.username');
  } catch (_) { return false; }
}

function acceptsCanonicalNetworkJob(job: PinmonyNetworkJob, context: PinmonyNetworkContext): boolean {
  if (!job || !context.authenticated || job.epoch !== context.epoch || job.page !== context.page ||
      !/^https:\/\/www\.pinterest\.com\//.test(job.page) || !/^[a-zA-Z0-9_-]{1,96}$/.test(job.id) ||
      typeof job.url !== 'string' || job.url.length > 65536 || typeof job.body !== 'string' ||
      job.body.length > (job.url === 'https://www.pinterest.com/resource/PinResource/create/' ? 34 * 1024 * 1024 : 262144) || (job.method !== 'GET' && job.method !== 'POST') ||
      !job.headers || typeof job.headers !== 'object' || Array.isArray(job.headers)) return false;
  if (job.id.startsWith('native_account_switch_')) return acceptsSessionAccountJob(job);
  const match: RegExpMatchArray | null = job.url.match(/^https:\/\/www\.pinterest\.com\/resource\/([A-Za-z]+Resource)\/(get|create|update|delete)\/(?:\?[^#]*)?$/);
  if (match) {
    if (!RESOURCES.includes(match[1])) return false;
    if (match[1] === 'BoardSectionResource') {
      if(match[2] === 'get' && job.method === 'GET' && !job.body) {
        try {
          const query: RegExpMatchArray | null = job.url.match(/\?source_url=([^&]+)&data=([^&]+)&_=\d+$/);
          const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(query ? query[2] : '')) as NativeSearchEnvelope;
          const id: Object | null = e.options['section_id'];
          return !!query && Object.keys(e).length === 2 && Object.keys(e.options).length === 1 && typeof id === 'string' && /^\d{1,30}$/.test(id) &&
            !!e.context && !Array.isArray(e.context) && Object.keys(e.context).length === 0 &&
            decodeURIComponent(query[1]) === '/boardsection/' + id + '/organize/repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/organize/add.js';
        }catch (_) {return false;}
      }
      if (match[2] !== 'create' || job.method !== 'POST' || !/^https:\/\/www\.pinterest\.com\/[^/?#]+\/[^/?#]+\/$/.test(job.page)) return false;
      try {
        const data: RegExpMatchArray | null = job.body.match(/(?:^|&)data=([^&]+)/);
        const source: RegExpMatchArray | null = job.body.match(/(?:^|&)source_url=([^&]+)/);
        if (!data || !source || job.body.split('&').length !== 2) return false;
        const payload: BoardSectionCreatePayload = JSON.parse(decodeURIComponent(data[1])) as BoardSectionCreatePayload;
        const options: BoardSectionCreateOptions = payload.options;
        return Object.keys(payload).length === 2 && !!options && Object.keys(options).length === 3 &&
          typeof options.board_id === 'string' && /^\d{1,30}$/.test(options.board_id) &&
          typeof options.name === 'string' && !!options.name.trim() && options.name === options.name.trim() && options.name.length <= 100 &&
          Array.isArray(options.initial_pins) && options.initial_pins.length <= 500 && new Set(options.initial_pins).size === options.initial_pins.length &&
          options.initial_pins.every((id: string): boolean => typeof id === 'string' && /^\d{1,30}$/.test(id)) &&
          !!payload.context && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
          [ '/board/' + options.board_id + '/create_section/', '/board/' + options.board_id + '/create_section/pins/' ].includes(decodeURIComponent(source[1])) &&
          (decodeURIComponent(source[1]).endsWith('/pins/') || options.initial_pins.length === 0) &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/create_section.js';
      } catch (_) { return false; }
    }
    if (match[1] === 'BoardSectionsResource' || match[1] === 'BoardSectionPinsResource') {
      // HAR-confirmed section reads only; no section mutations or arbitrary options.
      if (match[2] !== 'get' || job.method !== 'GET' || job.body !== '') return false;
      try {
        const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
        if (!encoded) return false;
        const payload: BoardSectionReadData = JSON.parse(decodeURIComponent(encoded[1])) as BoardSectionReadData;
        if (!payload || Object.keys(payload).length !== 2 || !payload.options ||
            typeof payload.options !== 'object' || Array.isArray(payload.options) || !payload.context ||
            typeof payload.context !== 'object' || Array.isArray(payload.context) || Object.keys(payload.context).length !== 0) return false;
        const options: BoardSectionReadOptions = payload.options;
        const keys: string[] = Object.keys(options);
        if (match[1] === 'BoardSectionsResource') {
          return keys.length === 2 && typeof options.board_id === 'string' && /^\d{1,30}$/.test(options.board_id) &&
            options.redux_normalize_feed === true;
        }
        return keys.every((key: string) => ['section_id', 'page_size', 'prepend', 'bookmarks'].includes(key)) &&
          typeof options.section_id === 'string' && /^\d{1,30}$/.test(options.section_id) &&
          options.page_size === 25 && options.prepend === false &&
          (!keys.includes('bookmarks') || Array.isArray(options.bookmarks) && options.bookmarks.length === 1 &&
            typeof options.bookmarks[0] === 'string' && options.bookmarks[0].length > 0 && options.bookmarks[0].length <= 8192);
      } catch (_) { return false; }
    }
    if (match[1] === 'BoardInvitesResource' || match[1] === 'BoardInviteResource') {
      if (match[2] === 'get') return job.method === 'GET' && job.body === '';
      if (match[1] !== 'BoardInviteResource' || !['update','delete'].includes(match[2]) || job.method !== 'POST') return false;
      if (match[2] === 'delete' && (job.page !== 'https://www.pinterest.com/inbox/' ||
        job.headers['X-Pinterest-Pws-Handler'] !== 'www/inbox.js' || job.headers['X-Pinterest-Source-Url'] !== '/inbox/' ||
        !job.body.startsWith('source_url=%2Finbox%2F&data='))) return false;
      try {
        const data: RegExpMatchArray | null = job.body.match(/(?:^|&)data=([^&]+)/);
        if (!data || job.body.split('&').length !== 2 || !/(?:^|&)source_url=/.test(job.body)) return false;
        const payload: BoardInviteAcceptPayload = JSON.parse(decodeURIComponent(data[1])) as BoardInviteAcceptPayload;
        return Object.keys(payload).length === 2 && !!payload.options && !Array.isArray(payload.options) &&
          Object.keys(payload.options).length === 2 && /^\d{1,30}$/.test(String(payload.options.board_id)) &&
          /^\d{1,30}$/.test(String(payload.options.invited_user_id)) && !!payload.context &&
          typeof payload.context === 'object' && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0;
      } catch (_) { return false; }
    }
    if (match[1] === 'BoardInvitesResource' || match[1] === 'BoardInviteResource') {
      // Only documented invitation reads; accepting an invite remains a separate write contract.
      return match[2] === 'get' && job.method === 'GET' && job.body === '';
    }
    if (match[1] === 'UserSessionResource') {
      if (job.url !== 'https://www.pinterest.com/resource/UserSessionResource/delete/' || job.method !== 'POST' ||
          (job.headers['X-Pinterest-Pws-Handler'] || job.headers['x-pinterest-pws-handler']) !== 'www/settings.js') return false;
      try {
        const parts: string[] = job.body.split('&');
        if (parts.length !== 2 || !parts.some((part: string) => part === 'source_url=%2Fsettings%2F')) return false;
        const encoded: RegExpMatchArray | null = job.body.match(/(?:^|&)data=([^&]+)/);
        if (!encoded) return false;
        const payload: LogoutWrite = JSON.parse(decodeURIComponent(encoded[1])) as LogoutWrite;
        return Object.keys(payload).length === 2 && !!payload.options && !Array.isArray(payload.options) &&
          Object.keys(payload.options).length === 1 && payload.options.disable_auth_failure_redirect === true &&
          !!payload.context && typeof payload.context === 'object' && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0;
      } catch (_) { return false; }
    }
    // Only the GET read contracts captured in 搜索.har are enabled for these resources.
    if (match[1] === 'SearchTabResource' || match[1] === 'AdvancedTypeaheadResource') {
      return match[2] === 'get' && job.method === 'GET' && job.body === '';
    }
    if (match[2] === 'get') return true;
    if (job.method !== 'POST') return false;
    if (match[1] === 'UserSettingsResource') {
      if (match[2] !== 'update') return false;
      try {
        const encoded: RegExpMatchArray | null = job.body.match(/(?:^|&)data=([^&]+)/);
        if (!encoded) return false;
        const payload: SettingsUpdate = JSON.parse(decodeURIComponent(encoded[1])) as SettingsUpdate;
        const options: Record<string, Object> = payload.options;
        const keys: string[] = Object.keys(options);
        const fields: string[] = keys.filter((key: string) => !['user_id', 'surface_tag', 'user_confirm_skip_passcode'].includes(key));
        if (keys.length === 2 && options.surface_tag === 'holistic_profile_prompt' && typeof options['show_all_pins'] === 'boolean' && job.id.startsWith('native_profile_sort_')) return true;
        if (options.surface_tag !== 'settings' || fields.length !== 1 || keys.length > 4) return false;
        const field: string = fields[0]; const value: Object = options[field];
        if (['autoplay_videos_on_wifi_enabled','autoplay_videos_on_cellular_enabled'].includes(field)) {
          return keys.length === 3 && typeof options.user_id === 'string' && /^\d{1,40}$/.test(options.user_id as string) && typeof value === 'boolean' && job.id.startsWith('native_profile_settings_');
        }
        if (field === 'allow_mentions' || field === 'messaging_permissions') {
          if (keys.length !== 4 || typeof options.user_id !== 'string' || !/^\d{1,40}$/.test(options.user_id as string) || options.user_confirm_skip_passcode !== false || !job.id.startsWith('native_profile_settings_')) return false;
          if (field === 'allow_mentions') return typeof value === 'number' && [0,1,2].includes(value);
          const groups: Record<string, Object> = value as Record<string,Object>;
          const ids: string[] = groups && !Array.isArray(groups) ? Object.keys(groups) : [];
          return ids.length === 1 && ['0','1','2','4'].includes(ids[0]) && [0,1,2].includes(groups[ids[0]] as number) && (ids[0] !== '4' || groups[ids[0]] !== 0);
        }
        if (field === 'opt_in_private_account' || field === 'exclude_from_search') {
          return typeof options.user_id === 'string' && /^\d+$/.test(options.user_id) && typeof value === 'boolean' &&
            (field === 'opt_in_private_account' ? options.user_confirm_skip_passcode === false : !keys.includes('user_confirm_skip_passcode'));
        }
        if (keys.includes('user_confirm_skip_passcode')) return false;
        if (typeof value !== 'string') return false;
        if (field !== 'birthdate' && !(typeof options.user_id === 'string' && /^\d+$/.test(options.user_id))) return false;
        return field === 'birthdate' ? /^\d{4}-\d{2}-\d{2}$/.test(value) :
          field === 'gender' ? ['female', 'male', 'unspecified'].includes(value) :
          field === 'custom_gender' ? value.length > 0 && value.length <= 500 :
          field === 'country' && /^[A-Z]{2}$/.test(value);
      } catch (_) { return false; }
    }
    if (match[1] === 'ApiResource') return true;
    if (match[1] === 'PinResource') {
      if (match[2] !== 'create') return match[2] === 'update' || match[2] === 'delete';
      try {
        const encoded: RegExpMatchArray | null = job.body.match(/(?:^|&)data=([^&]+)/);
        if (!encoded) return false;
        if(/^native_story_publish_\d+$/.test(job.id) && job.headers['X-Pinterest-Source-Url'] === '/pin-creation-tool/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin-creation-tool.js') {
          const product: StoryProductEnvelope = JSON.parse(decodeURIComponent(encoded[1])) as StoryProductEnvelope;
          const p: StoryProductOptions = product.options;
          return !!p && Object.keys(p).length === 5 && Object.keys(p).every((key: string): boolean => ['board_id','image_url','link','method','scrape_metric'].includes(key)) && /^\d{1,40}$/.test(p.board_id) && p.method === 'scraped' && typeof p.link === 'string' && p.link.length <= 4096 && /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(p.link) && typeof p.image_url === 'string' && p.image_url.length <= 4096 && /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(p.image_url) && !!p.scrape_metric && Object.keys(p.scrape_metric).length === 1 && p.scrape_metric.source === 'www_url_scrape';
        }
        const data: PublishCreate = JSON.parse(decodeURIComponent(encoded[1])) as PublishCreate;
        const o: PublishCreateOptions = data.options;
        if (!o || Object.keys(o).some((key: string) => !['boardId', 'board_id', 'description', 'guid', 'imageBase64', 'image_base64', 'imageUrl', 'image_url', 'link', 'method'].includes(key)) ||
          typeof o.boardId !== 'string' || !/^\d+$/.test(o.boardId) || o.board_id !== o.boardId || o.guid !== '' ||
          typeof o.description !== 'string' || o.description.length > 2000 || typeof o.imageBase64 !== 'string' || o.imageBase64 !== o.image_base64 ||
          typeof o.imageUrl !== 'string' || o.image_url !== o.imageUrl || typeof o.link !== 'string') return false;
        return o.method === 'uploaded' ? o.imageUrl === '' && (o.link === '' || /^https?:\/\/[^\s]+$/.test(o.link) && o.link.length <= 4096) && o.imageBase64.length <= 5600000 &&
          /^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/]+=*$/.test(o.imageBase64) :
          o.method === 'scraped' && o.imageBase64 === '' && /^https?:\/\//.test(o.link) && o.link.length <= 4096 &&
          /^https?:\/\//.test(o.imageUrl) && o.imageUrl.length <= 4096;
      } catch (_) { return false; }
    }
    if (match[1] === 'AggregatedCommentResource') return ['create', 'update', 'delete'].includes(match[2]);
    if (match[1] === 'DidItCommentsResource' || match[1] === 'AggregatedCommentReplyResource') return match[2] === 'create';
    if (match[1] === 'BoardResource') return match[2] === 'create' || match[2] === 'update' || match[2] === 'delete';
    return match[2] === 'create' && ['BoardResource', 'ConversationsResource', 'ConversationMessagesResource', 'RepinResource'].includes(match[1]);
  }
  if (job.url !== 'https://www.pinterest.com/_/graphql/' || job.method !== 'POST') return false;
  try {
    const query: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery;
    return !!query && /^[a-f0-9]{64}$/.test(query.queryHash) && !!query.variables &&
      typeof query.variables === 'object' && !Array.isArray(query.variables);
  } catch (_) { return false; }
}

interface PublishCreate { options: PublishCreateOptions; }
interface StoryProductEnvelope { options: StoryProductOptions; }
interface StoryProductOptions { board_id: string; image_url: string; link: string; method: string; scrape_metric: StoryProductMetric; }
interface StoryProductMetric { source: string; }
interface PublishCreateOptions {
  boardId: string; board_id: string; description: string; guid: string;
  imageBase64: string; image_base64: string; imageUrl: string; image_url: string; link: string; method: string;
}
interface SettingsUpdate { options: Record<string, Object>; }
interface LogoutWrite { options: LogoutWriteOptions; context: Object; }
interface LogoutWriteOptions { disable_auth_failure_redirect: boolean; }
interface BoardSectionReadData { options: BoardSectionReadOptions; context: Object; }
interface BoardSectionReadOptions {
  board_id?: string; redux_normalize_feed?: boolean; section_id?: string;
  page_size?: number; prepend?: boolean; bookmarks?: string[];
}

export enum Priority {
  HIGH,
  NORMAL,
  LOW
}

function priorityName(priority: Priority): string {
  if (priority === Priority.HIGH) return 'HIGH';
  if (priority === Priority.LOW) return 'LOW';
  return 'NORMAL';
}

type ScheduledTask = () => Promise<Object>;

interface RequestSchedulerItem {
  priority: Priority;
  order: number;
  task: ScheduledTask;
  resolve: (value: Object) => void;
  reject: (reason: Error) => void;
}

export class RequestScheduler {
  private readonly maxConcurrent: number;
  private readonly queue: RequestSchedulerItem[] = [];
  private active: number = 0;
  private nextOrder: number = 0;

  constructor(maxConcurrent: number = 8) {
    this.maxConcurrent = maxConcurrent > 0 ? Math.floor(maxConcurrent) : 1;
  }

  isIdle(): boolean { return this.active === 0 && this.queue.length === 0; }

  enqueue<T>(priority: Priority, task: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void) => {
      const item: RequestSchedulerItem = {
        priority: priority,
        order: this.nextOrder++,
        task: async (): Promise<Object> => {
          const value: T = await task();
          return value as Object;
        },
        resolve: (value: Object): void => resolve(value as T),
        reject: (reason: Error): void => reject(reason)
      };
      this.queue.push(item);
      PinmonyRuntimeLog.info('NetworkTrace: queue-enqueue priority=' + priorityName(priority) +
        ' order=' + item.order.toString() + ' active=' + this.active.toString() +
        ' queued=' + this.queue.length.toString());
      this.pump();
    });
  }

  private pump(): void {
    this.queue.sort((left: RequestSchedulerItem, right: RequestSchedulerItem): number =>
      left.priority - right.priority || left.order - right.order);
    while (this.active < this.maxConcurrent && this.queue.length > 0) {
      const item: RequestSchedulerItem | undefined = this.queue.shift();
      if (!item) return;
      this.active++;
      PinmonyRuntimeLog.info('NetworkTrace: queue-start priority=' + priorityName(item.priority) +
        ' order=' + item.order.toString() + ' active=' + this.active.toString() +
        ' queued=' + this.queue.length.toString() + ' max=' + this.maxConcurrent.toString());
      let outcome: string = 'ok';
      Promise.resolve().then((): Promise<Object> => item.task())
        .then((value: Object): void => item.resolve(value))
        .catch((error: Error): void => {
          outcome = 'error';
          item.reject(error);
        })
        .finally((): void => {
          this.active--;
          PinmonyRuntimeLog.info('NetworkTrace: queue-finish priority=' + priorityName(item.priority) +
            ' order=' + item.order.toString() + ' outcome=' + outcome +
            ' active=' + this.active.toString() + ' queued=' + this.queue.length.toString());
          this.pump();
        });
    }
  }
}

export class NetworkManager {
  private static shared: NetworkManager | undefined;
  private session: rcp.Session | undefined;
  private sessionGeneration: number = 0;
  private sessionAccessCount: number = 0;
  private preconnectState: string = 'idle';
  private preconnectStartedAt: number = 0;
  private foreground: boolean = true;
  private connectionRenewPending: boolean = false;
  private readonly scheduler: RequestScheduler = new RequestScheduler(8);
  private readonly requestPolicy: PinmonyRequestPolicy = new PinmonyRequestPolicy();

  private constructor() {}

  private static instance(): NetworkManager {
    if (!NetworkManager.shared) NetworkManager.shared = new NetworkManager();
    return NetworkManager.shared;
  }

  private getOrCreateSession(): rcp.Session {
    this.renewIdleConnection();
    if (!this.session) {
      try { this.session = rcp.createSession({ requestConfiguration: {
        transfer: { autoRedirect: false, timeout: { connectMs: 10000, transferMs: 20000 } },
        tracing: { collectTimeInfo: true }
      } }); } catch (error) {
        PinmonyRuntimeLog.warn('NetworkTrace: session-create-failed');
        throw error as Error;
      }
      this.sessionGeneration++;
      this.sessionAccessCount = 1;
      PinmonyRuntimeLog.info('NetworkTrace: session-created generation=' + this.sessionGeneration.toString());
    } else {
      this.sessionAccessCount++;
      PinmonyRuntimeLog.info('NetworkTrace: session-reused generation=' + this.sessionGeneration.toString() +
        ' access=' + this.sessionAccessCount.toString());
    }
    return this.session;
  }

  static getSession(): rcp.Session {
    return NetworkManager.instance().getOrCreateSession();
  }

  static enqueue<T>(priority: Priority, task: () => Promise<T>): Promise<T> {
    const manager: NetworkManager = NetworkManager.instance();
    manager.renewIdleConnection();
    return manager.scheduler.enqueue(priority, task);
  }

  static setForeground(value: boolean): void {
    const manager: NetworkManager = NetworkManager.instance();
    if (manager.foreground === value) return;
    manager.foreground = value;
    if (!value) manager.connectionRenewPending = true;
    else manager.renewIdleConnection();
  }

  private renewIdleConnection(): void {
    if (!this.foreground || !this.connectionRenewPending || !this.scheduler.isIdle() || this.preconnectState === 'pending') return;
    const session: rcp.Session | undefined = this.session;
    this.session = undefined;
    this.connectionRenewPending = false;
    this.preconnectState = 'idle';
    this.preconnectStartedAt = 0;
    if (!session) return;
    try { session.close(); } catch (_) { PinmonyRuntimeLog.warn('NetworkTrace: resumed-session-close-unavailable'); }
    PinmonyRuntimeLog.info('NetworkTrace: transport-renew reason=foreground generation=' + this.sessionGeneration.toString());
  }

  static cancel(request: rcp.Request): void {
    const session: rcp.Session | undefined = NetworkManager.shared?.session;
    if (!session) return;
    try { session.cancel(request); } catch (_) { PinmonyRuntimeLog.warn('NativeNetwork: request cancellation unavailable'); }
  }

  static async preConnect(url: string): Promise<void> {
    const manager: NetworkManager = NetworkManager.instance();
    manager.preconnectState = 'pending';
    manager.preconnectStartedAt = Date.now();
    PinmonyRuntimeLog.info('NetworkTrace: preconnect-start');
    try {
      const session: rcp.Session = NetworkManager.getSession();
      const request: rcp.Request = new rcp.Request(url, 'GET');
      request.connectOnly = true;
      const response: rcp.Response = await session.fetch(request);
      if (manager.session === session) manager.preconnectState = 'ok';
      PinmonyRuntimeLog.info('NetworkTrace: preconnect-ok connectOnly=true ' + responseMetrics(response));
    } catch (error) {
      manager.preconnectState = 'failed';
      const code: number = (error as BusinessError).code || 0;
      PinmonyRuntimeLog.warn('NetworkTrace: preconnect-failed code=' + code.toString());
      // Pre-connect is best effort and must never delay app startup.
    }
  }

  static async requestWithRetry(session: rcp.Session, request: rcp.Request,
    maxRetries: number = 2, baseDelay: number = 300,
    onRetry?: (attempt: number, status: number) => void,
    shouldContinue?: () => boolean, speculative: boolean = false): Promise<rcp.Response> {
    if (shouldContinue && !shouldContinue()) throw new Error('stale');
    const policy: PinmonyRequestPolicy = NetworkManager.instance().requestPolicy;
    const permit = policy.acquire(String(request.method).toUpperCase() === 'GET', speculative);
    if (!permit.allowed) throw new Error('rate-limited');
    let status: number = 0;
    try {
      const response: rcp.Response = await NetworkManager.performRequestWithRetry(session, request,
        maxRetries, baseDelay, permit, onRetry, shouldContinue);
      if (shouldContinue && !shouldContinue()) throw new Error('stale');
      status = response.statusCode;
      return response;
    } finally { policy.finish(permit, status); }
  }

  static requestRemainingMs(): number { return NetworkManager.instance().requestPolicy.remainingMs(); }
  static allowsSpeculativeRequests(): boolean { return NetworkManager.instance().requestPolicy.allowsSpeculativeRequests(); }

  private static async performRequestWithRetry(session: rcp.Session, request: rcp.Request,
    maxRetries: number, baseDelay: number, permit: PinmonyRequestPermit,
    onRetry?: (attempt: number, status: number) => void,
    shouldContinue?: () => boolean): Promise<rcp.Response> {
    const retries: number = Math.max(0, Math.floor(maxRetries));
    const delayBase: number = Math.max(0, baseDelay);
    const manager: NetworkManager = NetworkManager.instance();
    PinmonyRuntimeLog.info('NetworkTrace: connection-context sharedSession=' + (session === manager.session).toString() +
      ' generation=' + manager.sessionGeneration.toString() + ' preconnect=' + manager.preconnectState +
      ' preconnectAgeMs=' + (manager.preconnectStartedAt > 0 ? Date.now() - manager.preconnectStartedAt : -1).toString());
    let attempt: number = 0;
    while (true) {
      try {
        if (shouldContinue && !shouldContinue()) throw new Error('stale');
        if (!manager.requestPolicy.canSend(permit)) throw new Error('rate-limited');
        const response: rcp.Response = await session.fetch(request);
        const method: string = String(request.method).toUpperCase();
        if (response.statusCode === 429) {
          manager.requestPolicy.rateLimited(response.headers || {});
          return response;
        }
        const transientStatus: boolean = response.statusCode >= 500 && response.statusCode <= 599;
        if (!transientStatus) return response;
        if (method !== 'GET') {
          PinmonyRuntimeLog.info('NetworkTrace: retry-skip method=' + method +
            ' reason=non-idempotent status=' + response.statusCode.toString());
          return response;
        }
        if (attempt >= retries) {
          PinmonyRuntimeLog.warn('NetworkTrace: retry-exhausted kind=http method=GET status=' +
            response.statusCode.toString() + ' attempts=' + (attempt + 1).toString());
          throw new Error('retry-exhausted');
        }
        if (shouldContinue && !shouldContinue()) throw new Error('stale');
        if (onRetry) onRetry(attempt + 1, response.statusCode);
        if (shouldContinue && !shouldContinue()) throw new Error('stale');
        const delay: number = delayBase * Math.pow(2, attempt) + Math.floor(Math.random() * 201);
        PinmonyRuntimeLog.info('NetworkTrace: retry kind=http method=GET status=' +
          response.statusCode.toString() + ' attempt=' + (attempt + 1).toString() +
          ' delayMs=' + delay.toString());
        await NetworkManager.delay(delay);
        if (shouldContinue && !shouldContinue()) throw new Error('stale');
        attempt++;
      } catch (error) {
        const code: number = (error as BusinessError).code || 0;
        const failure: Error = error instanceof Error ? error : new Error('network-unavailable');
        const method: string = String(request.method).toUpperCase();
        const retryTransport: boolean = method === 'GET' &&
          [1007900028, 1007900035, 1007900056].includes(code);
        if (!retryTransport || attempt >= retries) {
          if (retryTransport) {
            PinmonyRuntimeLog.warn('NetworkTrace: retry-exhausted kind=transport method=GET code=' +
              code.toString() + ' attempts=' + (attempt + 1).toString());
          }
          throw failure;
        }
        if (shouldContinue && !shouldContinue()) throw failure;
        if (onRetry) onRetry(attempt + 1, 0);
        if (shouldContinue && !shouldContinue()) throw new Error('stale');
        const delay: number = delayBase * Math.pow(2, attempt) + Math.floor(Math.random() * 201);
        PinmonyRuntimeLog.info('NetworkTrace: retry kind=transport method=GET code=' + code.toString() +
          ' attempt=' + (attempt + 1).toString() + ' delayMs=' + delay.toString());
        await NetworkManager.delay(delay);
        if (shouldContinue && !shouldContinue()) throw new Error('stale');
        attempt++;
      }
    }
  }

  static destroy(): void {
    const instance: NetworkManager | undefined = NetworkManager.shared;
    NetworkManager.shared = undefined;
    if (!instance || !instance.session) return;
    PinmonyRuntimeLog.info('NetworkTrace: session-destroy generation=' + instance.sessionGeneration.toString() +
      ' accesses=' + instance.sessionAccessCount.toString());
    const session: rcp.Session = instance.session;
    instance.session = undefined;
    try { session.cancel(); } catch (_) { PinmonyRuntimeLog.warn('NativeNetwork: shared cancellation unavailable'); }
    try { session.close(); } catch (_) { PinmonyRuntimeLog.warn('NativeNetwork: shared close unavailable'); }
  }

  private static delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => { setTimeout(resolve, milliseconds); });
  }
}

function priorityForJob(job: PinmonyNetworkJob): Priority {
  if (job.priority !== undefined) return job.priority;
  if (/^(?:detail_prefetch_|title_)/i.test(job.id)) return Priority.LOW;
  const resourceMatch: RegExpMatchArray | null = job.url.match(/\/resource\/([A-Za-z]+Resource)\//);
  const resource: string = resourceMatch ? resourceMatch[1] : '';
  const pagination: boolean = /(?:bookmarks|bookmark|cursor)/i.test(job.url + ' ' + job.body);
  if (!pagination && ['UserHomefeedResource', 'BoardContentRecommendationResource', 'BaseSearchResource'].includes(resource)) {
    return Priority.HIGH;
  }
  return pagination ? Priority.NORMAL : Priority.NORMAL;
}

function metricValue(value: number | undefined): string {
  return typeof value === 'number' && value >= 0 && value === value ? Math.round(value).toString() : '-1';
}

function responseMetrics(response: rcp.Response): string {
  const timing: PinmonyTimingInfo | undefined = response.timeInfo as PinmonyTimingInfo | undefined;
  return 'protocol=' + (response.httpVersion || 'unknown') +
    ' dnsMs=' + metricValue(timing?.nameLookupTimeMs) +
    ' connectMs=' + metricValue(timing?.connectTimeMs) +
    ' tlsMs=' + metricValue(timing?.tlsHandshakeTimeMs) +
    ' preTransferMs=' + metricValue(timing?.preTransferTimeMs) +
    ' firstByteMs=' + metricValue(timing?.startTransferTimeMs) +
    ' totalTransferMs=' + metricValue(timing?.totalTimeMs) +
    ' redirectMs=' + metricValue(timing?.redirectTimeMs);
}

// Manual rollout control. Failures never switch implementations automatically.
export const PIN_BUSINESS_PIN_READ_ENABLED: boolean = true;

export class PinmonyNativeNetwork {
  private transferSequence: number = 0;
  private readonly transferOwners: Map<string, number> = new Map<string, number>();
  currentGeneration(): number { return this.generation; }
  isForeground(): boolean { return this.foreground; }
  transferAvailable(id: string): boolean {
    return this.foreground && !this.pending.has(id) && this.pending.size < 12 && NetworkManager.requestRemainingMs() <= 0;
  }

  // One dispatch, with the same cancellation and account lifetime as resource requests.
  // Feature contracts authorize the operation; this boundary restricts credential destinations.
  async transfer(job: PinmonyTransferJob, owner: () => boolean, dispatched?: () => void): Promise<PinmonyTransferReply> {
    const site: boolean = /^https:\/\/(?:www|uk)\.pinterest\.com\//.test(job.url);
    const external: boolean = /^https:\/\/(?:i\.pinimg\.com\/|u\.pinimg\.com\/$|pinterest-media-upload\.s3\.amazonaws\.com\/$)/.test(job.url);
    if (!this.transferAvailable(job.id) || !owner() || !site && !external || job.authenticated && !site ||
        !['GET', 'POST', 'PUT'].includes(job.method) || job.maxBytes < 1 || job.maxBytes > 8 * 1024 * 1024 ||
        job.timeoutMs < 1 || job.timeoutMs > 60000) throw new Error('transfer-unavailable');
    if (job.authenticated && (!/^https:\/\/(?:www|uk)\.pinterest\.com\//.test(job.page) ||
        job.page.split('/').slice(0, 3).join('/') !== job.url.split('/').slice(0, 3).join('/'))) throw new Error('transfer-origin');
    if (Object.keys(job.headers).some((key: string): boolean => !['content-type', 'x-pinterest-source-url', 'x-pinterest-pws-handler'].includes(key.toLowerCase()))) throw new Error('transfer-headers');
    const generation: number = this.generation;
    const ownerToken: number = ++this.transferSequence;
    this.transferOwners.set(job.id, ownerToken);
    this.pending.add(job.id); this.cancelled.delete(job.id);
    if (job.method === 'GET') this.readJobs.add(job.id);
    const live = (): boolean => generation === this.generation && this.transferOwners.get(job.id) === ownerToken && owner() && this.pending.has(job.id) &&
      !this.cancelled.has(job.id) && (this.foreground || this.sentJobs.has(job.id) && job.method !== 'GET');
    let request: rcp.Request | undefined = undefined;
    try {
      const headers: Record<string, string> = {};
      Object.keys(job.headers).forEach((key: string): void => { headers[key] = job.headers[key]; });
      if (job.userAgent) headers['User-Agent'] = job.userAgent;
      if (job.authenticated) {
        const cookie: string = await this.credentials.read(job.url);
        if (!live()) throw new Error('stale');
        headers['Cookie'] = cookie; headers['Referer'] = job.page; headers['X-Requested-With'] = 'XMLHttpRequest';
        if (job.method !== 'GET') {
          const csrf: RegExpMatchArray | null = cookie.match(/(?:^|;\s*)csrftoken=([^;]+)/);
          if (!csrf) throw new Error('missing-session');
          headers['X-CSRFToken'] = decodeURIComponent(csrf[1]);
          headers['Origin'] = job.url.split('/').slice(0, 3).join('/');
        }
      }
      let content: string | ArrayBuffer | rcp.MultipartForm | undefined = job.body;
      if (job.fields || job.file) {
        const fields: rcp.MultipartFormFields = {};
        if (job.fields) Object.keys(job.fields).forEach((key: string): void => { fields[key] = job.fields![key]; });
        if (job.file) fields[job.file.field] = { contentOrPath: { content: job.file.bytes }, contentType: job.file.mime, remoteFileName: job.file.name };
        content = new rcp.MultipartForm(fields);
      }
      if (!live()) throw new Error('stale');
      request = new rcp.Request(job.url, job.method, headers, content, undefined, undefined,
        { transfer: { autoRedirect: false, timeout: { connectMs: 10000, transferMs: job.timeoutMs } } });
      const active: rcp.Request = request;
      this.jobs.set(job.id, active);
      const response: rcp.Response = await NetworkManager.enqueue(Priority.NORMAL, (): Promise<rcp.Response> => {
        if (!live()) return Promise.reject(new Error('stale'));
        this.sentJobs.add(job.id); if (dispatched) dispatched();
        return NetworkManager.getSession().fetch(active);
      });
      if (!live()) throw new Error('stale');
      if (job.authenticated) {
        const cookies: string | string[] | undefined = response.headers['set-cookie'];
        if (cookies) await this.credentials.update(job.url, typeof cookies === 'string' ? [cookies] : cookies, live);
      }
      const bytes: ArrayBuffer = response.body || new ArrayBuffer(0);
      if (!live() || bytes.byteLength > job.maxBytes) throw new Error('transfer-response');
      return { status: response.statusCode, text: response.toString() || '', bytes: bytes };
    } finally {
      if (this.transferOwners.get(job.id) === ownerToken) {
        this.transferOwners.delete(job.id);
        if (!request || this.jobs.get(job.id) === request) this.jobs.delete(job.id);
        this.pending.delete(job.id); this.readJobs.delete(job.id); this.sentJobs.delete(job.id); this.cancelled.delete(job.id);
      }
    }
  }
  onTransientRetry?: (resource: string, speculative: boolean) => void;
  onRateLimited?: (remainingMs: number) => void;
  onSessionExpired?: (origin: string, epoch: number) => void;
  onReadTrace?: (id: string, resource: string, event: string, duration: number, attempt: number) => void;
  private readonly credentials: PinmonySessionCredentials = new PinmonySessionCredentials();
  private readonly jobs: Map<string, rcp.Request> = new Map<string, rcp.Request>();
  private readonly pending: Set<string> = new Set<string>();
  private readonly cancelled: Set<string> = new Set<string>();
  private generation: number = 0;
  private foreground: boolean = true;
  private readonly readJobs: Set<string> = new Set<string>();
  private readonly sentJobs: Set<string> = new Set<string>();
  private resumeReadNeeded: boolean = false;
  setForeground(value: boolean): boolean {
    this.foreground = value;
    if (!value) {
      const reads: string[] = Array.from(this.readJobs);
      this.resumeReadNeeded = this.resumeReadNeeded || reads.length > 0;
      const unsent: string[] = Array.from(this.pending).filter((id: string): boolean => !this.sentJobs.has(id));
      Array.from(new Set<string>(reads.concat(unsent))).forEach((id: string) => this.cancel(id));
      this.audit('suspend', 'readCount=' + reads.length.toString()); return false;
    }
    const needed: boolean = this.resumeReadNeeded; this.resumeReadNeeded = false;
    this.audit('resume', 'readNeeded=' + needed.toString()); return needed;
  }

  private audit(event: string, detail: string = ''): void {
    PinmonyRuntimeLog.info('NetworkTrace: lifecycle=' + event +
      ' generation=' + this.generation.toString() +
      ' pending=' + this.pending.size.toString() +
      ' jobs=' + this.jobs.size.toString() +
      ' cancelled=' + this.cancelled.size.toString() +
      (detail ? ' ' + detail : ''));
  }

  private release(request: rcp.Request): void {
    NetworkManager.cancel(request);
  }

  cancel(id: string): void {
    this.transferOwners.delete(id);
    this.cancelled.add(id);
    this.readJobs.delete(id); this.sentJobs.delete(id);
    const request: rcp.Request | undefined = this.jobs.get(id);
    this.jobs.delete(id);
    this.pending.delete(id);
    if (request) this.release(request);
    this.audit('cancel', 'requestIdPresent=' + (request !== undefined).toString());
  }
  invalidateDocument(): void {
    // Native business jobs retain their own account and route guards.
    Array.from(this.pending).filter((id: string): boolean => !id.startsWith('native_')).forEach((id: string): void => this.cancel(id));
    this.audit('document-invalidate');
  }
  invalidate(): void {
    this.transferOwners.clear();
    const pendingBefore: number = this.pending.size;
    this.generation++;
    const requests: rcp.Request[] = Array.from(this.jobs.values());
    this.jobs.clear();
    this.pending.clear();
    this.readJobs.clear(); this.sentJobs.clear();
    requests.forEach((request: rcp.Request) => this.release(request));
    this.audit('invalidate', 'pendingBefore=' + pendingBefore.toString());
  }
  // Startup read permission is restricted to this constructed GET. It does not
  // authenticate the account or admit any other business operation.
  async verifySession(origin: string, userAgent: string, epoch: number, id: string,
      owner: () => boolean): Promise<PinmonyNetworkReply> {
    if (!/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin) ||
        !/^session_probe_\d+$/.test(id) || !Number.isInteger(epoch) || epoch < 0 ||
        !userAgent || userAgent.length > 4096 || /[\r\n]/.test(userAgent) || !owner()) throw new Error('session-probe-unavailable');
    const options: SessionVerificationOptions = { url: '/v3/users/settings/', data: {},
      field_sets: ["partner.selected_ecommerce_platforms","partner.advertising_intent","partner.business_name","partner.business_goals","partner.top_business_goal","partner.daily_ads_budget","partner.marketing_plan_name","partner.custom_daily_ads_budget","partner.business_vertical","partner.business_vertical_other","partner.number_employees","partner.contact_name","partner.account_type","partner.contact_email","partner.contact_phone","partner.contact_phone_country()","partner.enable_profile_address","partner.enable_profile_message","partner.is_linked_business","partner.profile_place()","place.latitude","place.longitude","place.country","place.postal_code","place.street","place.extra_street","place.region","place.locality","partner.is_agency_employee","partner.number_agency_clients","partner.agency_content","partner.agency_services","partner.agency_services_other","user.ip_stela_rec_disabled"] };
    const envelope: SessionVerificationEnvelope = { options: options, context: {} };
    const source: string = '/settings/';
    const query: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const page: string = origin + source;
    const job: PinmonyNetworkJob = { id: id, epoch: epoch, page: page,
      url: origin + '/resource/ApiResource/get/?' + query, method: 'GET', body: '',
      headers: { 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/settings.js',
        'X-Pinterest-Source-Url': source, 'X-Pinterest-AppState': 'active' } };
    return this.request(job, (): PinmonyNetworkContext => ({ authenticated: owner(), epoch: epoch, page: page, userAgent: userAgent }));
  }

  cancelProfileAvatar(id: string): void {
    [id, id + '_status'].forEach((job: string): void => { if (this.pending.has(job)) this.cancel(job); });
  }
  async request(job: PinmonyNetworkJob, context: () => PinmonyNetworkContext, attempt: number = 0): Promise<PinmonyNetworkReply> {
    const startedAt: number = Date.now();
    // Only the constructed read-only startup settings probe gets the shorter budget.
    const sessionProbe: boolean = /^session_probe_\d+$/.test(job.id) && job.method === 'GET' && job.body === '' &&
      /^https:\/\/(?:www|uk)\.pinterest\.com\/settings\/$/.test(job.page) &&
      /^https:\/\/(?:www|uk)\.pinterest\.com\/resource\/ApiResource\/get\/\?/.test(job.url);
    const detailRead: boolean = job.method === 'GET' && (/\/resource\/(PinResource|RelatedModulesResource|UnifiedCommentsPreviewResource|UnifiedCommentsResource|AggregatedCommentReplyFeedResource|DidItCommentsResource)\/get\//.test(job.url) ||
      job.id.startsWith('native_translation_') && /\/resource\/ApiResource\/get\//.test(job.url));
    const pathMatch: RegExpMatchArray | null = job.url.match(/\/resource\/([A-Za-z]+Resource)\/(get|create|update|delete)\//);
    const requestLabel: string = pathMatch ? pathMatch[1] + '/' + pathMatch[2] :
      (job.url === 'https://www.pinterest.com/_/graphql/' ? 'GraphQL' : 'unknown');
    let traceAttempt: number = attempt;
    const trace = (event: string): void => {
      if (job.method === 'GET' && pathMatch && this.onReadTrace)
        this.onReadTrace(job.id, pathMatch[1], event, Date.now() - startedAt, traceAttempt);
    };
    trace('started');
    PinmonyRuntimeLog.info('NetworkTrace: start ' + requestLabel + ' method=' + job.method +
      ' bodyBytes=' + job.body.length.toString() + ' headerCount=' + Object.keys(job.headers).length.toString() +
      ' attempt=' + attempt.toString());
    const result: PinmonyNetworkReply = { id: job.id, epoch: job.epoch, page: job.page,
      status: 0, body: '', url: job.url, error: '', headers: {} };
    if (!this.foreground) { this.resumeReadNeeded = true; result.error = 'background'; this.audit('deferred'); return result; }
    if (!acceptsNetworkJob(job, context()) || this.pending.has(job.id) || this.pending.size >= 12) {
      const state: PinmonyNetworkContext = context();
      const reason: string = !state.authenticated || job.epoch !== state.epoch || job.page !== state.page ? 'stale-context' :
        this.pending.has(job.id) ? 'duplicate' : this.pending.size >= 12 ? 'capacity' : 'contract';
      PinmonyRuntimeLog.warn('NativeNetwork: request rejected before dispatch reason=' + reason);
      this.audit('reject', 'label=' + requestLabel + ' reason=' + reason);
      trace('rejected');
      result.error = 'request-unavailable'; return result;
    }
    if (NetworkManager.requestRemainingMs() > 0) {
      result.error = 'rate-limited'; result.status = 429;
      if (this.onRateLimited && job.id.indexOf('detail_prefetch_') !== 0)
        this.onRateLimited(NetworkManager.requestRemainingMs());
      return result;
    }
    this.pending.add(job.id);
    if (job.method === 'GET' || /\/resource\/[A-Za-z]+Resource\/get\//.test(job.url)) this.readJobs.add(job.id);
    this.cancelled.delete(job.id);
    this.audit('start', 'label=' + requestLabel + ' method=' + job.method);
    const generation: number = this.generation;
    let request: rcp.Request | undefined;
    const current = (): boolean => this.generation === generation && this.pending.has(job.id) &&
      !this.cancelled.has(job.id) && (!detailRead || Date.now() - startedAt < 12000) && acceptsNetworkJob(job, context()) &&
      (!request || this.jobs.get(job.id) === request);
    let stage: string = 'read-session';
    try {
      PinmonyRuntimeLog.info('NativeNetwork: reading current session');
      const cookie: string = await this.credentials.read(job.url);
      if (!current()) throw new Error('stale');
      const headers: Record<string, string> = {};
      const allowed: string[] = ['accept', 'content-type', 'x-requested-with', 'x-pinterest-pws-handler',
        'x-pinterest-source-url', 'x-pinterest-appstate', 'x-app-version'];
      Object.keys(job.headers).forEach((key: string) => {
        const value: string = job.headers[key];
        if (job.method === 'GET' && job.id.startsWith('native_translation_') &&
            /\/resource\/ApiResource\/get\//.test(job.url) && value === 'no-cache') {
          if (key.toLowerCase() === 'cache-control') headers['Cache-Control'] = value;
          if (key.toLowerCase() === 'pragma') headers['Pragma'] = value;
        }
        if (key.toLowerCase() === 'accept-language' && job.id.startsWith('native_translation_') &&
            /\/resource\/ApiResource\/get\//.test(job.url) &&
            /^(?:zh-CN,zh|zh-TW,zh|en-US,en|en-GB,en|ja-JP,ja|ko-KR,ko|ru-RU,ru|pt-BR,pt);q=0\.9$/.test(value)) {
          headers['Accept-Language'] = value;
        }
        if (allowed.includes(key.toLowerCase()) && typeof value === 'string' && value.length <= 4096 && !/[\r\n]/.test(value))
          headers[key] = value;
      });
      headers['Cookie'] = cookie;
      headers['Referer'] = job.page;
      headers['Origin'] = job.url.slice(0, job.url.indexOf('/', 8));
      headers['User-Agent'] = context().userAgent;
      // Keep translation and its eligibility reads in the same desktop-compatible
      // context. The mobile service can disable is_translatable for every comment.
      const translationContextRead: boolean = job.method === 'GET' &&
        (job.id.startsWith('native_translation_') && /\/resource\/ApiResource\/get\//.test(job.url) ||
         job.id.startsWith('native_comments_') && /\/resource\/UnifiedCommentsResource\/get\//.test(job.url) ||
         job.id.startsWith('native_replies_') && /\/resource\/AggregatedCommentReplyFeedResource\/get\//.test(job.url));
      if (translationContextRead &&
          /\bArkWeb\/[0-9.]+/.test(headers['User-Agent'])) {
        const webkit: RegExpMatchArray | null = headers['User-Agent'].match(/\bAppleWebKit\/([0-9.]+)/);
        const chrome: RegExpMatchArray | null = headers['User-Agent'].match(/\bChrome\/([0-9.]+)/);
        const safari: RegExpMatchArray | null = headers['User-Agent'].match(/\bSafari\/([0-9.]+)/);
        if (webkit && chrome && safari) {
          headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/' +
            webkit[1] + ' (KHTML, like Gecko) Chrome/' + chrome[1] + ' Safari/' + safari[1];
        }
      }
      // Web resource wrapper seeds its platform browser id from the current _b
      // cookie when no refreshed pid is available. Keep this credential native,
      // per request, and restricted to the captured comment translation GET.
      if (job.method === 'GET' && job.id.startsWith('native_translation_') &&
          /\/resource\/ApiResource\/get\//.test(job.url)) {
        const browserCookie: RegExpMatchArray | null = cookie.match(/(?:^|;\s*)_b=([^;]*)/);
        const browserId: string = browserCookie ? browserCookie[1].replace(/"/g, '') : '';
        if (browserId.length > 0 && browserId.length <= 4096 && !/[^\x21-\x7e]/.test(browserId))
          headers['X-Pinterest-Platform-Bid'] = browserId;
      }
      if (job.id.startsWith('native_translation_')) {
        PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=transport language=' +
          (headers['Accept-Language'] || 'absent') + ' noCache=' +
          (headers['Cache-Control'] === 'no-cache' && headers['Pragma'] === 'no-cache').toString() +
          ' nonce=' + /[?&]_=\d+(?:&|$)/.test(job.url).toString() +
          ' platformBid=' + (headers['X-Pinterest-Platform-Bid'] ? 'current-cookie' : 'absent') +
          ' ua=' + (headers['User-Agent'] !== context().userAgent ? 'desktop-compatible' : 'current'));
      }
      const csrf: RegExpMatchArray | null = cookie.match(/(?:^|;\s*)csrftoken=([^;]+)/);
      if (job.method === 'POST' && !csrf) throw new Error('missing-session');
      if (csrf) headers['X-CSRFToken'] = decodeURIComponent(csrf[1]);
      const isHomeFeedRead: boolean = job.method === 'GET' &&
        /\/resource\/UserHomefeedResource\/get\//.test(job.url);
      request = new rcp.Request(job.url, job.method === 'POST' ? 'POST' : 'GET',
        headers, job.method === 'POST' ? job.body : undefined, undefined, undefined,
        { transfer: { autoRedirect: false, timeout: { connectMs: sessionProbe ? 3000 : detailRead ? 4000 : 10000,
          transferMs: sessionProbe || detailRead || isHomeFeedRead ? 5000 : 20000 } },
          tracing: { collectTimeInfo: true } });
      this.jobs.set(job.id, request);
      const session: rcp.Session = NetworkManager.getSession();
      stage = 'fetch';
      trace('dispatched');
      PinmonyRuntimeLog.info('NativeNetwork: request dispatched');
      if (sessionProbe) PinmonyRuntimeLog.info('NetworkTrace: session-probe-budget connectMs=3000 transferMs=5000 retries=1 baseDelayMs=100');
      const response: rcp.Response = await NetworkManager.enqueue(priorityForJob(job), (): Promise<rcp.Response> => {
        if (!current()) return Promise.reject(new Error('stale'));
        this.sentJobs.add(job.id);
        return NetworkManager.requestWithRetry(session, request!, sessionProbe || detailRead ? 1 : 2, sessionProbe ? 100 : 300,
          (_retryAttempt: number, _status: number): void => {
            traceAttempt++;
            trace('retry');
            if (this.onTransientRetry) this.onTransientRetry(requestLabel, job.id.indexOf('detail_prefetch_') === 0);
          }, current, job.id.indexOf('detail_prefetch_') === 0);
      });
      trace('http' + response.statusCode.toString());
      PinmonyRuntimeLog.info('NativeNetwork: response received, HTTP ' + response.statusCode.toString());
      PinmonyRuntimeLog.info('NetworkTrace: response ' + requestLabel + ' status=' + response.statusCode.toString() +
        ' elapsedMs=' + (Date.now() - startedAt).toString() + ' ' + responseMetrics(response));
      if (!current()) throw new Error('stale');
      if (response.statusCode === 429) {
        const limitCookie: string | string[] | undefined = response.headers['set-cookie'];
        if (limitCookie) await this.credentials.update(job.url,
          typeof limitCookie === 'string' ? [limitCookie] : limitCookie, current);
        if (!current()) throw new Error('stale');
        result.status = 429; result.error = 'rate-limited';
        if (this.onRateLimited && job.id.indexOf('detail_prefetch_') !== 0)
          this.onRateLimited(NetworkManager.requestRemainingMs());
        return result;
      }
      stage = 'decode-response';
      const body: string = response.toString() || '';
      const resource: RegExpMatchArray | null = job.url.match(/\/resource\/([A-Za-z]+Resource)\//);
      const label: string = resource && RESOURCES.includes(resource[1]) ? resource[1] : 'GraphQL';
      const jsonBody: boolean = /^\s*[\[{]/.test(body);
      PinmonyRuntimeLog.info('NativeNetwork: ' + label + ', JSON-shaped response ' + jsonBody.toString());
      try {
        const parsed: PinmonyResponseDiagnostic = JSON.parse(body) as PinmonyResponseDiagnostic;
        const business: PinmonyResourceDiagnostic | undefined = parsed.resource_response;
        const status: string = business?.status === 'success' ? 'success' :
          business?.status === 'failure' ? 'failure' : 'unknown';
        PinmonyRuntimeLog.info('NativeNetwork: business ' + status + ', resource present ' +
          (!!business).toString() + ', list data ' + Array.isArray(business?.data).toString());
      } catch (_) { PinmonyRuntimeLog.warn('NativeNetwork: response is not valid JSON'); }
      if (body.length > 8388608) throw new Error('response-too-large');
      trace('decoded');
      const setCookie: string | string[] | undefined = response.headers['set-cookie'];
      stage = 'sync-session';
      if (setCookie) await this.credentials.update(job.url, typeof setCookie === 'string' ? [setCookie] : setCookie, current);
      if (!current()) throw new Error('stale');
      result.status = response.statusCode;
      result.body = body;
      try {
        const authentication: PinmonyResponseDiagnostic = JSON.parse(body) as PinmonyResponseDiagnostic;
        if (response.statusCode === 200 && authentication.resource_response &&
            authentication.client_context?.is_authenticated === false &&
            (!authentication.client_context.user?.id || authentication.client_context.user.id === '0') && current())
          this.onSessionExpired?.(job.url.slice(0, job.url.indexOf('/', 8)), job.epoch);
      } catch (_) { /* Non-JSON failures are not authentication evidence. */ }
      // Expose only response metadata needed by fetch consumers, never Set-Cookie.
      Object.keys(response.headers).forEach((name: string) => {
        const key: string = name.toLowerCase();
        const value: string | string[] | undefined = response.headers[name];
        if (['content-type', 'content-language', 'cache-control'].includes(key) &&
            typeof value === 'string' && value.length <= 2048 && !/[\r\n]/.test(value))
          result.headers[key] = value;
      });
      // A same-origin login redirect is evidence for the existing auth observer; never follow it with credentials.
      const location: string | string[] | undefined = response.headers['location'];
      const origin: string = job.url.slice(0, job.url.indexOf('/', 8));
      if (response.statusCode >= 300 && response.statusCode < 400 && typeof location === 'string') {
        const target: string = location.startsWith('/') ? origin + location : location;
        if (target.startsWith(origin + '/') && /^\/(?:login|signup)(?:\/|[?#]|$)/.test(target.slice(origin.length)))
          result.url = target;
      }
    } catch (error) {
      // Only SDK numeric error codes are diagnostic; never log request/response or exception messages.
      const code: number = (error as BusinessError).code || 0;
      trace((current() ? 'failed.code' : 'cancelled.code') + code.toString());
      if (current()) {
        PinmonyRuntimeLog.warn('NativeNetwork: request failed at ' + stage + ', code ' + code.toString() + ', current true');
        PinmonyRuntimeLog.warn('NetworkTrace: failed ' + requestLabel + ' elapsedMs=' + (Date.now() - startedAt).toString());
      } else {
        PinmonyRuntimeLog.info('NetworkTrace: cancelled ' + requestLabel + ' stage=' + stage +
          ' code=' + code.toString() + ' elapsedMs=' + (Date.now() - startedAt).toString());
      }
      const deadlineExpired: boolean = detailRead && Date.now() - startedAt >= 12000 &&
        this.generation === generation && !this.cancelled.has(job.id) && acceptsNetworkJob(job, context());
      const limited: boolean = error instanceof Error && error.message === 'rate-limited';
      const missingSession: boolean = stage === 'read-session' && error instanceof Error && error.message === 'missing-session';
      result.error = !current() ? 'cancelled' : missingSession ? 'missing-session' : limited ? 'rate-limited' : deadlineExpired ? 'timeout' : 'network-unavailable';
      if (result.error === 'rate-limited') {
        result.status = 429;
        if (this.onRateLimited && job.id.indexOf('detail_prefetch_') !== 0)
          this.onRateLimited(NetworkManager.requestRemainingMs());
      }
    } finally {
      if (request && this.jobs.get(job.id) === request) this.jobs.delete(job.id);
      this.pending.delete(job.id);
      this.cancelled.delete(job.id);
      this.readJobs.delete(job.id); this.sentJobs.delete(job.id);
      this.audit('finish', 'label=' + requestLabel + ' status=' + result.status.toString() +
        ' error=' + (result.error || 'none'));
    }
    return result;
  }
}
