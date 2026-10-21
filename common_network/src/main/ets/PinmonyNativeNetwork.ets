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


function profileRelayUser(id: string): string {
  const value: string = 'User:' + id, alphabet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result: string = '';
  for(let i: number = 0;i < value.length;i += 3){
    const a: number = value.charCodeAt(i), b: number = i + 1 < value.length ? value.charCodeAt(i + 1) : 0, c: number = i + 2 < value.length ? value.charCodeAt(i + 2) : 0;
    result += alphabet[a >> 2] + alphabet[((a & 3) << 4) | (b >> 4)] + (i + 1 < value.length ? alphabet[((b & 15) << 2) | (c >> 6)] : '=') + (i + 2 < value.length ? alphabet[c & 63] : '=');
  }
  return result;
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

// Only contracts already used by Pinmony are permitted. No arbitrary native URL proxy.
const RESOURCES: string[] = ['UserHomefeedResource', 'BoardContentRecommendationResource', 'BoardResource',
  'BoardFeedResource', 'BoardSectionsResource', 'BoardSectionPinsResource', 'BoardSectionResource',
  'UserPinsResource', 'UserResource', 'BoardsResource', 'BoardsFeedResource',
  'UserSettingsResource', 'CountriesResource', 'UserRecentActivityResource', 'UserFollowingResource', 'UserActivityPinsResource', 'BoardlessPinsResource', 'PinResource', 'RelatedModulesResource', 'VisualSearchFlashlightUnifiedResource',
  'SearchTabResource', 'AdvancedTypeaheadResource', 'BaseSearchResource', 'UserExperienceResource', 'ApiResource', 'ConversationMessagesResource',
  'ConversationsResource', 'BoardInvitesResource', 'BoardInviteResource', 'ShareSuggestionsResource', 'ShareSuggestionsTypeaheadResource',
  'FindPinImagesResource', 'UserSessionResource', 'BoardPickerBoardsResource', 'UnifiedCommentsResource', 'UnifiedCommentsPreviewResource',
  'AggregatedCommentReplyFeedResource', 'AggregatedCommentReplyResource', 'AggregatedCommentResource', 'DidItCommentsResource', 'RepinResource'];
interface SessionVerificationOptions { url: string; data: Record<string, string>; field_sets: string[]; }
interface SessionVerificationEnvelope { options: SessionVerificationOptions; context: Record<string, string>; }
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface NativeSearchApiOptions { url: string; data: Record<string,Object>; }
interface InboxUpdatesReadOptions { url: string; data: InboxUpdatesData; redux_normalize_feed: boolean; field_sets: string[]; bookmarks?: string[]; }
interface InboxUpdatesData { field_set_key: string; }
interface InboxUpdatesEnvelope { options: InboxUpdatesReadOptions; context: Record<string,string>; }
interface SearchDiscoveryVariables { count?: number; cursor?: string; }
interface SearchDiscoveryQuery { queryHash: string; variables: SearchDiscoveryVariables; }
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
interface ProfileAvatarUploadResponse { success?: boolean; image_upload_tracking_id?: string; }
interface ProfileAvatarStatusData { tracking_id: string; }
interface ProfileAvatarStatusOptions { url: string; data: ProfileAvatarStatusData; }
interface ProfileAvatarStatusEnvelope { options: ProfileAvatarStatusOptions; context: Record<string, string>; }
interface ProfileAvatarStatusResponse { resource_response: ProfileAvatarStatusResource; }
interface ProfileAvatarStatusResource { status: string; code: number; endpoint_name: string; data: Record<string, number>; }
interface CommentUploadRegistration {
  resource_response: CommentUploadRegistrationResponse;
}
interface CommentUploadRegistrationResponse {
  status: string;
  code: number;
  endpoint_name: string;
  data: CommentUploadData;
}
interface CommentUploadData { upload_id: string; upload_url: string; upload_parameters: Record<string, string>; }
interface CommentUploadStatus {
  resource_response: CommentUploadStatusResponse;
}
interface CommentUploadStatusResponse {
  status: string;
  code: number;
  endpoint_name: string;
  data: Record<string, CommentUploadItem>;
}
interface CommentUploadReadOptions { url: string; data: CommentUploadReadData; }
interface CommentUploadReadData { upload_ids: string[]; }
interface CommentUploadItem { upload_id: string; status: string; signature: string; type: string; }

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

function acceptsCanonicalNetworkJob(job: PinmonyNetworkJob, context: PinmonyNetworkContext): boolean {
  if (!job || !context.authenticated || job.epoch !== context.epoch || job.page !== context.page ||
      !/^https:\/\/www\.pinterest\.com\//.test(job.page) || !/^[a-zA-Z0-9_-]{1,96}$/.test(job.id) ||
      typeof job.url !== 'string' || job.url.length > 65536 || typeof job.body !== 'string' ||
      job.body.length > (job.url === 'https://www.pinterest.com/resource/PinResource/create/' ? 34 * 1024 * 1024 : 262144) || (job.method !== 'GET' && job.method !== 'POST') ||
      !job.headers || typeof job.headers !== 'object' || Array.isArray(job.headers)) return false;
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
      if (match[1] !== 'BoardInviteResource' || match[2] !== 'update' || job.method !== 'POST') return false;
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
        const data: PublishCreate = JSON.parse(decodeURIComponent(encoded[1])) as PublishCreate;
        const o: PublishCreateOptions = data.options;
        if (!o || Object.keys(o).some((key: string) => !['boardId', 'board_id', 'description', 'guid', 'imageBase64', 'image_base64', 'imageUrl', 'image_url', 'link', 'method'].includes(key)) ||
          typeof o.boardId !== 'string' || !/^\d+$/.test(o.boardId) || o.board_id !== o.boardId || o.guid !== '' ||
          typeof o.description !== 'string' || o.description.length > 2000 || typeof o.imageBase64 !== 'string' || o.imageBase64 !== o.image_base64 ||
          typeof o.imageUrl !== 'string' || o.image_url !== o.imageUrl || typeof o.link !== 'string') return false;
        return o.method === 'uploaded' ? o.imageUrl === '' && o.link === '' && o.imageBase64.length <= 5600000 &&
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
interface HomeReadData { options: HomeReadOptions; }
interface HomeReadOptions { field_set_key?: string; in_nux?: boolean; in_news_hub?: boolean; static_feed?: boolean;
  type?: string; id?: string; __track__referrer?: number; bookmarks?: string[]; username?: string;
  filter_stories?: boolean; sort?: string; board_id?: string; is_mobile_fork?: boolean; }
interface PinReadData { options: PinReadOptions; }
interface PinReadOptions { id?: string; field_set_key?: string; pin_id?: string; bookmarks?: string[]; aggregated_pin_id?: string; page_size?: number; redux_normalize_feed?: boolean; is_reversed?: boolean; comment_featured_ids?: string[]; objectId?: string; isUnifiedComment?: boolean; url?: string; }

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
  private readonly scheduler: RequestScheduler = new RequestScheduler(8);
  private readonly requestPolicy: PinmonyRequestPolicy = new PinmonyRequestPolicy();

  private constructor() {}

  private static instance(): NetworkManager {
    if (!NetworkManager.shared) NetworkManager.shared = new NetworkManager();
    return NetworkManager.shared;
  }

  private getOrCreateSession(): rcp.Session {
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
    return NetworkManager.instance().scheduler.enqueue(priority, task);
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

  // Only validated opening Pin and first-page related GETs may survive source -> Pin
  // navigation. The owner revokes this permission on back, account reset or a
  // different opening. All ordinary requests retain strict page/epoch checks.
  async requestPinRead(job: PinmonyNetworkJob, context: () => PinmonyNetworkContext,
    pinUrl: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const initial: PinmonyNetworkContext = context();
    const captured: PinmonyNetworkContext = { authenticated: initial.authenticated, epoch: initial.epoch,
      page: initial.page, userAgent: initial.userAgent };
    let permitted: boolean = false;
    try {
      const match: RegExpMatchArray | null = pinUrl.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/(\d+)\/$/);
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const data: PinReadData = encoded ? JSON.parse(decodeURIComponent(encoded[1])) as PinReadData : {} as PinReadData;
      permitted = !!match && acceptsNetworkJob(job, captured) && job.method === 'GET' && job.body === '' &&
        ((/^https:\/\/(?:www|uk)\.pinterest\.com\/resource\/PinResource\/get\/\?/.test(job.url) &&
          data.options?.id === match[1] && data.options?.field_set_key === 'auth_web_main_pin') ||
         (/^https:\/\/(?:www|uk)\.pinterest\.com\/resource\/RelatedModulesResource\/get\/\?/.test(job.url) &&
          job.id.startsWith('opening_related_') && data.options?.pin_id === match[1] &&
          data.options?.bookmarks === undefined));
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyNetworkContext = context();
      // onPageBegin can precede getUrl updating to the target. Only the owner
      // of the deliberate opening can keep that one transitional epoch alive.
      const epoch: boolean = actual.epoch >= captured.epoch && actual.epoch <= captured.epoch + 1;
      const source: boolean = epoch && actual.page === captured.page;
      const target: boolean = epoch && actual.page === pinUrl;
      if (!permitted || !actual.authenticated || !ownerCurrent() || (!source && !target))
        return { authenticated: false, epoch: actual.epoch, page: actual.page, userAgent: actual.userAgent };
      return { authenticated: true, epoch: job.epoch, page: job.page, userAgent: actual.userAgent };
    });
  }
  // First migration boundary: validated base Pin and opening-related reads only.
  // Legacy bridge jobs keep their document/epoch validation unchanged.
  // Business ownership replaces document ownership only for these migrated contracts.
  async requestBusinessProfileSettings(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, userId: string, viewer: string, allowed: string[], permissions: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), username: string = path.split('/')[1];
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() && /^\/[A-Za-z0-9_]+\/$/.test(path) && job.page === profileUrl && job.page === captured.origin + path && job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active' && job.epoch === captured.generation && job.id.startsWith('native_profile_settings_') && job.headers['Accept'] === 'application/json' && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js';
      const digits = (v: Object | null | undefined): boolean => typeof v === 'string' && /^\d{1,40}$/.test(v as string);
      if(job.url === captured.origin + '/_/graphql/') {
        const q: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery,v: Record<string,Object> = q.variables as Record<string,Object>;
        const graph: boolean = basic && job.headers['X-Pinterest-Source-Url'] === path && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' && Object.keys(q).length === 2 && !!v && !Array.isArray(v) && Object.keys(v).length === 1;
        if(q.queryHash === '369b31865237e1a2f57f1879be69a6c01ee4d6d2806cc4c624d73baea9546b08')permitted = graph && digits(userId) && v['userId'] === userId;
        if(q.queryHash === 'aac6989e67cb8913e620879f06b197c7edee2e17bbf17bc73228a7a3ff560bfd')permitted = basic &&
          job.headers['X-Pinterest-Source-Url'] === path && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' &&
          Object.keys(q).length === 2 && !!v && !Array.isArray(v) && Object.keys(v).length === 3 && digits(userId) &&
          v['id'] === profileRelayUser(userId) && v['count'] === 10 && typeof v['cursor'] === 'string' &&
          (v['cursor'] as string).length > 0 && (v['cursor'] as string).length <= 8192;
        else if(['5e6f83666a4e4fbd33b6c78f26f80166c097f4164e666b6e408b4bb62cb8c1e5','84f6cda9933f7aa2786ff803f5c7a7bc31af0392a37434f830fd7e2602c994c0'].includes(q.queryHash))permitted = graph && digits(viewer) && digits(v['followee']) && v['followee'] !== viewer && allowed.includes('follow:' + v['followee']);
        else if(q.queryHash === '7f7aa5597fc53cb10b582e1d45cac2e61336be40dde57f95a9f022fb83806e81') {
          const input: Record<string,Object> = v['input'] as Record<string,Object>;
          permitted = graph && permissions.includes('own') && userId === viewer && digits(viewer) && !!input && !Array.isArray(input) && Object.keys(input).length === 8 && ['firstName','lastName','about','websiteUrl','username','impressumUrl'].every((k: string): boolean => typeof input[k] === 'string' && (input[k] as string).length <= 2000) && /^[A-Za-z0-9_]+$/.test(input['username'] as string) && input['impressumUrl'] === '' && Array.isArray(input['pronouns']) && !(input['pronouns'] as string[]).length && Array.isArray(input['additionalWebsiteUrls']) && !(input['additionalWebsiteUrls'] as string[]).length;
        }
      }else {
        const get: boolean = job.method === 'GET',f: RegExpMatchArray | null = (get ? job.url.slice(job.url.indexOf('?') + 1) : job.body).match(/^source_url=([^&]+)&data=([^&]+)$/);
        const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(f ? f[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope,o: Record<string,Object | null> = e.options;
        const source: string = f ? decodeURIComponent(f[1].replace(/\+/g,' ')) : '',keys: string[] = Object.keys(o),resource: string = job.url.split('?')[0].slice(captured.origin.length);
        const envelope: boolean = basic && !!f && job.headers['X-Pinterest-Source-Url'] === source && Object.keys(e).length === 2 && !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && !Object.keys(e.context).length && !!o && !Array.isArray(o) && (get ? job.body === '' : job.method === 'POST' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded');
        const own: boolean = permissions.includes('own') && userId === viewer && digits(viewer);
        if(envelope && resource === '/resource/UserResource/get/')permitted = get && source === path && keys.length === 2 && o['username'] === username && o['field_set_key'] === 'profile';
        else if(envelope && resource === '/resource/UserFollowingResource/get/')permitted = get && source === path && keys.length === 4 && o['username'] === username && o['page_size'] === 50 && o['exclude_not_explictly_followed'] === true && o['explicit_following'] === true;
        else if(envelope && resource === '/resource/UserSettingsResource/get/')permitted = get && own && !keys.length && ['/settings/account-settings/','/settings/profile-visibility/'].includes(source);
        else if(envelope && resource === '/resource/CountriesResource/get/')permitted = get && own && !keys.length && source === '/settings/edit/country-region/';
        else if(envelope && resource === '/resource/UserRecentActivityResource/get/')permitted = get && own && source === '/edit/activity/' && keys.length === 2 && o['username'] === 'me' && o['filter_type'] === 'all';
        else if(envelope && resource === '/resource/UserSettingsResource/update/' && !get && own) {
          const fields: string[] = keys.filter((k: string): boolean => !['user_id','surface_tag','user_confirm_skip_passcode'].includes(k)),field: string = fields[0],value: Object | null = o[field];
          permitted = fields.length === 1 && o['surface_tag'] === 'settings' && (field === 'birthdate' ? keys.length === 2 && typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && source === '/settings/edit/birthdate/' : o['user_id'] === viewer && (field === 'opt_in_private_account' ? keys.length === 4 && permissions.includes('privacy') && o['user_confirm_skip_passcode'] === false && typeof value === 'boolean' && source === '/settings/profile-visibility/' : keys.length === 3 && (field === 'exclude_from_search' ? permissions.includes('search') && typeof value === 'boolean' && source === '/settings/profile-visibility/' : field === 'gender' ? ['female','male','unspecified'].includes(value as string) && source === '/settings/edit/gender/' : field === 'custom_gender' ? permissions.includes('custom') && typeof value === 'string' && !!(value as string).trim() && (value as string).length <= 500 && source === '/settings/edit/gender/' : field === 'country' && typeof value === 'string' && allowed.includes('country:' + value) && source === '/settings/edit/country/')));
          // Country source follows the existing country-region route.
          if(field === 'country')permitted = fields.length === 1 && keys.length === 3 && o['surface_tag'] === 'settings' && o['user_id'] === viewer && typeof value === 'string' && /^[A-Z]{2}$/.test(value) && allowed.includes('country:' + value) && source === '/settings/edit/country-region/';
          if (['autoplay_videos_on_wifi_enabled','autoplay_videos_on_cellular_enabled'].includes(field)) permitted = fields.length === 1 && keys.length === 3 && o['surface_tag'] === 'settings' && o['user_id'] === viewer && typeof value === 'boolean' && source === '/settings/permissions/';
          if (field === 'allow_mentions' || field === 'messaging_permissions') {
            const base: boolean = fields.length === 1 && keys.length === 4 && o['surface_tag'] === 'settings' && o['user_id'] === viewer && o['user_confirm_skip_passcode'] === false;
            if (field === 'allow_mentions') permitted = base && source === '/settings/edit/mentions/' && [0,1,2].includes(value as number) && allowed.includes('social-mentions:' + value);
            else {
              const choices: Record<string,Object> = value as Record<string,Object>, groups: string[] = choices && !Array.isArray(choices) ? Object.keys(choices) : [];
              const group: string = groups[0], level: Object = choices?.[group];
              const route: string = group === '0' ? 'friends' : group === '1' ? 'followers' : group === '2' ? 'following' : group === '4' ? 'others' : '';
              permitted = base && groups.length === 1 && !!route && source === '/settings/messages/' + route + '/' && [0,1,2].includes(level as number) && (group !== '4' || level !== 0) && allowed.includes('social-message:' + group + ':' + level);
            }
          }
        }else if(envelope && resource === '/resource/ApiResource/get/') {
          const data: Record<string,Object> = o['data'] as Record<string,Object>,url: string = o['url'] as string;
          permitted = keys.length === 1 && get && own && url === '/v3/settings/notifications/' && source === path;
          if(keys.length === 2 && data && !Array.isArray(data)) {
            if(get && !Object.keys(data).length)permitted = (url === '/v3/users/settings/' && own && [path,'/settings/edit/birthdate/','/settings/messages/','/settings/edit/mentions/'].includes(source)) || own && url === '/v3/users/settings/gen_ai/' && source === '/edit/gen-ai-interests/';
            else if(!get)permitted = source === path && url === '/v3/users/' + username + '/boards/following/' && data['explicit_following'] === true && data['page_size'] === 12 && Object.keys(data).length === 3 && JSON.stringify(data['fields']) === JSON.stringify(['board.id','board.name','board.image_cover_url','board.followed_by_me','board.type','board.images[236x]','board.image_cover_hd_url','board.pin_count','board.board_order_modified_at','board.url','board.owner()','user.username']);
            if(get && own && url === '/v3/users/blocked' && source === '/settings/blocked-accounts/') permitted = Object.keys(data).length === 1 && data['q'] === '';
          }
        }else if(envelope && resource === '/resource/ApiResource/delete/' && !get && own && keys.length === 1 && source === '/settings/blocked-accounts/') {
          const target: RegExpMatchArray | null = (o['url'] as string || '').match(/^\/v3\/users\/(\d{1,40})\/block\/$/);
          permitted = !!target && target[1] !== viewer && allowed.includes('social-unblock:' + target[1]);
        }else if(envelope && resource === '/resource/ApiResource/create/' && !get && own && keys.length === 2) {
          const data: Record<string,Object> = o['data'] as Record<string,Object>;
          if(o['url'] === '/v3/settings/notifications/' && source === path && data && Object.keys(data).length === 1 && typeof data['updated_settings'] === 'string' && (data['updated_settings'] as string).length < 1000) {
            const choices: Record<string,Object>[] = JSON.parse(data['updated_settings'] as string) as Record<string,Object>[];
            const c: Record<string,Object> = choices[0];
            permitted = Array.isArray(choices) && choices.length === 1 && !!c && Object.keys(c).length === 4 && typeof c['value'] === 'boolean' && ['push','email','news'].includes(c['type'] as string) && allowed.includes('notification:' + c['type'] + ':' + c['section'] + ':' + c['option']);
          }else if(o['url'] === '/v3/users/settings/' && source === '/edit/gen-ai-interests/' && data && Object.keys(data).length === 2 && data['gen_ai_topics_update_source'] === 'hf_tuner') {
            const ids: string[] = (data['gen_ai_topics_opt_in'] || data['gen_ai_topics_opt_out']) as string[];
            permitted = Array.isArray(ids) && ids.length > 0 && ids.length <= 80 && ids.every((id: string,i: number): boolean => digits(id) && allowed.includes('topic:' + id) && ids.indexOf(id) === i);
          }else if(o['url'] === '/v3/pins/bulk/move/' && source === path && data && Object.keys(data).length === 2) {
            const ids: string[] = data['pin_ids'] as string[];permitted = digits(data['board_id']) && allowed.includes('board:' + data['board_id']) && Array.isArray(ids) && ids.length > 0 && ids.length <= 100 && ids.every((id: string,i: number): boolean => digits(id) && allowed.includes('organize:' + id) && ids.indexOf(id) === i);
          }
        }else if(envelope && resource === '/resource/ApiResource/update/' && !get && own && source === '/edit/activity/' && keys.length === 2) {
          const data: Record<string,Object> = o['data'] as Record<string,Object>,id: string = data?.['pin'] as string;
          permitted = digits(id) && allowed.includes('pin:' + id) && o['url'] === '/v3/pfy/' + id + '/feedback/' && !!data && Object.keys(data).length === 4 && data['feedback_type'] === 4 && data['through_id'] === id && data['rec_reason_type'] === 4;
        }else if(envelope && resource === '/resource/BoardsResource/get/' && get && own && source === path) {
          permitted = keys.every((k: string): boolean => ['privacy_filter','sort','field_set_key','filter_stories','username','page_size','group_by','include_archived','filter_all_pins','bookmarks'].includes(k)) && keys.length >= 9 && keys.length <= 10 && o['privacy_filter'] === 'all' && o['sort'] === 'custom' && o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === true && o['username'] === username && o['page_size'] === 25 && o['group_by'] === 'mix_public_private' && o['include_archived'] === true && o['filter_all_pins'] === false && (!keys.includes('bookmarks') || Array.isArray(o['bookmarks']) && (o['bookmarks'] as string[]).length === 1 && typeof (o['bookmarks'] as string[])[0] === 'string' && (o['bookmarks'] as string[])[0].length <= 8192);
        }else if(envelope && resource === '/resource/BoardResource/create/' && !get && own && source === path)permitted = keys.length === 2 && typeof o['name'] === 'string' && !!(o['name'] as string).trim() && o['name'] === (o['name'] as string).trim() && (o['name'] as string).length <= 300 && ['public','secret'].includes(o['privacy'] as string);
      }
    }catch (_) {}
    return this.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessProfileBoardFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, board: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const m: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(m ? m[2] : '')) as NativeSearchEnvelope;
      const o: Record<string, Object | null> = e.options, source: string = page.slice(captured.origin.length) + '_following/';
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && owner() && captured.authenticated && !!captured.accountId &&
        /^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) && page.startsWith(captured.origin + '/') &&
        /^\/[A-Za-z0-9_]+\/$/.test(page.slice(captured.origin.length)) && /^\d{1,40}$/.test(board) && /^\d{1,40}$/.test(viewer) &&
        job.id.startsWith('native_profile_board_follow_') && job.epoch === captured.generation && job.page === page && job.method === 'POST' &&
        [captured.origin + '/resource/ApiResource/update/',captured.origin + '/resource/ApiResource/delete/'].includes(job.url) &&
        !!m && decodeURIComponent(m[1]) === source && Object.keys(e).length === 2 && Object.keys(e.context).length === 0 &&
        Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + board + '/follow/' &&
        job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/_following.js' && job.headers['X-Pinterest-Source-Url'] === source;
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated: permitted && owner() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: captured.generation, page: page, userAgent: actual.userAgent };});
  }
  async requestBusinessBoardFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, board: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const m: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(m ? m[2] : '')) as NativeSearchEnvelope;
      const o: Record<string, Object | null> = e.options, source: string = page.slice(captured.origin.length);
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && owner() && captured.authenticated && !!captured.accountId &&
        /^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) && page.startsWith(captured.origin + '/') &&
        /^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(page.slice(captured.origin.length)) && /^\d{1,40}$/.test(board) && /^\d{1,40}$/.test(viewer) &&
        job.id.startsWith('native_board_follow_') && job.epoch === captured.generation && job.page === page && job.method === 'POST' &&
        [captured.origin + '/resource/ApiResource/update/',captured.origin + '/resource/ApiResource/delete/'].includes(job.url) &&
        !!m && decodeURIComponent(m[1]) === source && Object.keys(e).length === 2 && Object.keys(e.context).length === 0 &&
        Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + board + '/follow/' &&
        job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js' && job.headers['X-Pinterest-Source-Url'] === source;
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated: permitted && owner() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: captured.generation, page: page, userAgent: actual.userAgent };});
  }
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
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated: permitted && owner() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: captured.generation, page: page, userAgent: actual.userAgent };});
  }
  async requestBusinessSharePublish(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    mode: string, objectId: string, viewer: string, contacts: string[], boards: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), share: boolean = ['pin','board','user'].includes(mode), publish: boolean = ['website','photo','create-board'].includes(mode);
      const digits = (v: Object | null | undefined): boolean => typeof v === 'string' && /^\d{1,40}$/.test(v as string);
      const web = (v: Object | null | undefined): boolean => typeof v === 'string' && /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(v as string) && (v as string).length <= 4096;
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.epoch === captured.generation && job.id.startsWith('native_share_publish_') && job.page === captured.origin + path &&
        /^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) && job.headers['Accept'] === 'application/json' &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active' &&
        (publish ? /^\/[A-Za-z0-9_]+\/$/.test(path) : share && digits(objectId) && (mode === 'pin' ? path === '/pin/' + objectId + '/' : mode === 'board' ? /^\/[^/?#]+\/[^/?#]+\/$/.test(path) : /^\/[A-Za-z0-9_]+\/$/.test(path)));
      if(job.url === captured.origin + '/_/graphql/') {
        const q: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery, v: Record<string,Object> = q.variables as Record<string,Object>, t: Record<string,Object> = JSON.parse(v['inviteType'] as string) as Record<string,Object>;
        permitted = basic && (mode === 'board' || mode === 'user') && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' &&
          job.headers['X-Pinterest-Source-Url'] === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && Object.keys(q).length === 2 && Object.keys(v).length === 2 &&
          q.queryHash === '6312848b4bb08588587683a04a42e4d0333e2e986fcab0cef4ed200786d3f5d9' && v['objectId'] === objectId && Object.keys(t).length === 3 && t['invite_category'] === 3 && t['invite_object'] === (mode === 'board' ? 2 : 3) && t['invite_channel'] === 12;
      }else {
        const get: boolean = job.method === 'GET', form: string = get ? job.url.slice(job.url.indexOf('?') + 1) : job.body;
        const m: RegExpMatchArray | null = form.match(/^source_url=([^&]+)&data=([^&]+)$/);
        const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(m ? m[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope, o: Record<string,Object | null> = e.options;
        const source: string = m ? decodeURIComponent(m[1].replace(/\+/g,' ')) : '', keys: string[] = Object.keys(o), resource: string = job.url.split('?')[0].slice(captured.origin.length);
        const envelope: boolean = basic && !!m && Object.keys(e).length === 2 && !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && !Object.keys(e.context).length &&
          !!o && typeof o === 'object' && !Array.isArray(o) && job.headers['X-Pinterest-Source-Url'] === source && (get ? job.body === '' : job.method === 'POST' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded');
        const handler: string = job.headers['X-Pinterest-Pws-Handler'];
        if(get && envelope) {
          if(resource === '/resource/UserResource/get/')permitted = source === path && handler === 'www/index.js' && keys.length === 2 && o['username'] === path.split('/')[1] && o['field_set_key'] === 'profile' && (publish || mode === 'user');
          else if(resource === '/resource/PinResource/get/')permitted = mode === 'pin' && source === path && handler === 'www/pin/[id].js' && keys.length === 2 && o['id'] === objectId && o['field_set_key'] === 'auth_web_main_pin';
          else if(resource === '/resource/ShareSuggestionsResource/get/')permitted = share && source === path && handler === (mode === 'pin' ? 'www/pin/[id].js' : 'www/index.js') && keys.length === 2 && (mode === 'pin' ? o['field_set_key'] === 'default' && o['hide_group_conversations'] === true : o['suggestion_type'] === 'share' && o['hide_group_conversations'] === false);
          else if(resource === '/resource/ShareSuggestionsTypeaheadResource/get/')permitted = share && source === path && handler === (mode === 'pin' ? 'www/pin/[id].js' : 'www/index.js') && keys.length === 3 && o['count'] === 25 && o['pin_scope'] === (mode === 'pin' ? 'pins' : 'users') && typeof o['term'] === 'string' && !!o['term'] && (o['term'] as string).length <= 200;
          else if(resource === '/resource/BoardPickerBoardsResource/get/')permitted = publish && digits(viewer) && source === '/pin/create/' + (mode === 'photo' ? 'uploaded' : 'pinbuilder') + '/' && handler === 'www/pin/create/[method].js' && keys.length === 3 && o['filter'] === 'all' && o['field_set_key'] === 'profile_grid_item' && o['user_id'] === viewer;
          else if(resource === '/resource/FindPinImagesResource/get/')permitted = mode === 'website' && source === path && handler === 'www/pin-builder.js' && keys.length === 5 && web(o['url']) && o['source'] === 'pin_create' && o['appendItems'] === false && o['followRedirects'] === true && o['scrapeMetric'] === 'www_url_scrape';
        }else if(envelope && !get) {
          if(resource === '/resource/ConversationsResource/create/') {
            const ids: string[] = o['user_ids'] as string[];
            permitted = share && source === path && handler === (mode === 'pin' ? 'www/pin/[id].js' : 'www/index.js') && Array.isArray(ids) && ids.length === 1 && digits(ids[0]) && contacts.includes(ids[0]) &&
              (mode === 'pin' ? keys.length === 5 && o['pin'] === objectId && Array.isArray(o['emails']) && !(o['emails'] as string[]).length && o['source'] === 'Unknown' && typeof o['client_tracking_params'] === 'string' && !!o['client_tracking_params'] && (o['client_tracking_params'] as string).length <= 16384 : keys.length === 2 && o[mode === 'board' ? 'board' : 'user'] === objectId);
          }else if(resource === '/resource/BoardResource/create/')permitted = publish && digits(viewer) && source === '/board/create/' && handler === 'www/board/create.js' && keys.length === 2 && typeof o['name'] === 'string' && !!o['name'] && (o['name'] as string).trim() === o['name'] && (o['name'] as string).length <= 100 && ['public','secret'].includes(o['privacy'] as string);
          else if(resource === '/resource/PinResource/create/')permitted = publish && mode !== 'create-board' && digits(viewer) && keys.length === 10 && boards.includes(o['board_id'] as string) && digits(o['board_id']) && source === '/pin/create/' + (mode === 'photo' ? 'uploaded' : 'pinbuilder') + '/' && handler === 'www/pin/create/[method].js' && o['method'] === (mode === 'photo' ? 'uploaded' : 'scraped');
        }
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessDetailAuxiliary(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const match: RegExpMatchArray | null = pin.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/(\d{1,30})\/$/);
      const id: string = match ? match[1] : '', path: string = '/pin/' + id + '/';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        !!match && pin === captured.origin + path && job.page === pin && job.epoch === captured.generation && job.id.startsWith('native_detail_aux_') &&
        job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active';
      if (job.url === captured.origin + '/_/graphql/') {
        const q: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery, v: Record<string,Object> = q.variables as Record<string,Object>;
        permitted = basic && job.id.startsWith('native_detail_aux_graph_') && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' && job.headers['X-Pinterest-Source-Url'] === path &&
          Object.keys(q).length === 2 && q.queryHash === 'c025ad33faccf5d04c2ed38344405d0a6c46dd1d786c17f3954b6980ef798538' &&
          !!v && !Array.isArray(v) && Object.keys(v).length === 7 && v['pinId'] === id && v['isAuth'] === true && v['isDesktop'] === false &&
          v['isAuthDesktop'] === false && v['isUnauth'] === false && v['shouldPrefetchStoryPinFragment'] === false && v['shouldSkipImageViewerOnPageQuery'] === true;
      } else {
        const form: RegExpMatchArray | null = job.url.slice(job.url.indexOf('?') + 1).match(/^source_url=([^&]+)&data=([^&]+)&_=\d+$/);
        const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
        const o: Record<string,Object | null> = e.options, keys: string[] = Object.keys(o), source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '';
        const envelope: boolean = basic && job.method === 'GET' && job.body === '' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' &&
          !!form && Object.keys(e).length === 2 && !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && Object.keys(e.context).length === 0 &&
          !!o && typeof o === 'object' && !Array.isArray(o) && job.headers['X-Pinterest-Source-Url'] === source;
        if (job.url.startsWith(captured.origin + '/resource/PinResource/get/?')) permitted = envelope && job.id.startsWith('native_detail_aux_pin_') && source === path &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' && keys.length === 6 && o['id'] === id && o['field_set_key'] === 'auth_web_main_pin' &&
          o['noCache'] === true && o['fetch_visual_search_objects'] === false && o['get_page_metadata'] === false &&
          o['add_fields'] === 'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin';
        else if (job.url.startsWith(captured.origin + '/resource/VisualSearchFlashlightUnifiedResource/get/?')) {
          const c: Record<string,Object> = o['crop'] as Record<string,Object>, bookmarks: Object | null = o['bookmarks'];
          permitted = envelope && job.id.startsWith('native_detail_aux_visual_') && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id]/visual-search.js' &&
            o['pin_id'] === id && o['is_shopping'] === false && o['entry_source'] === 'flashlight' &&
            (o['crop_source'] === 5 && o['entrypoint'] === 'closeup_cta' || o['crop_source'] === 6 && o['entrypoint'] === 'unknown') &&
            source === path + 'visual-search/?cropSource=' + String(o['crop_source']) + '&entrypoint=' + String(o['entrypoint']) + '&surfaceType=flashlight' &&
            (keys.length === 6 || keys.length === 7 && Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && !!bookmarks[0] && bookmarks[0].length <= 4096) &&
            !!c && !Array.isArray(c) && Object.keys(c).length === 4 && ['x','y','w','h'].every((k: string): boolean => typeof c[k] === 'number' && Number.isFinite(c[k] as number)) &&
            (c['x'] as number) >= 0 && (c['y'] as number) >= 0 && (c['w'] as number) >= 0.04 && (c['h'] as number) >= 0.04 &&
            (c['x'] as number) + (c['w'] as number) <= 1.00001 && (c['y'] as number) + (c['h'] as number) <= 1.00001;
        }
      }
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
      authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch:captured.generation,page:pin,userAgent:actual.userAgent
    }; });
  }
  async requestBusinessCommentWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, aggregate: string, viewer: string, comment: string, own: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const match: RegExpMatchArray | null = pin.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/(\d{1,30})\/$/);
      const id: string = match ? match[1] : '', path: string = '/pin/' + id + '/', get: boolean = job.method === 'GET';
      const form: RegExpMatchArray | null = (get ? job.url.slice(job.url.indexOf('?') + 1) : job.body).match(get ? /^source_url=([^&]+)&data=([^&]+)&_=\d+$/ : /^source_url=([^&]+)&data=([^&]+)$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = e.options, keys: string[] = Object.keys(o);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() && !!match && pin === captured.origin + path &&
        job.page === pin && job.epoch === captured.generation && job.id.startsWith('native_comment_write_') &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active' &&
        job.headers['X-Pinterest-Source-Url'] === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' &&
        !!form && decodeURIComponent(form[1].replace(/\+/g,' ')) === path && Object.keys(e).length === 2 &&
        !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && Object.keys(e.context).length === 0 && !!o && typeof o === 'object' && !Array.isArray(o);
      const digits = (value: string): boolean => /^\d{1,30}$/.test(value);
      const text: boolean = typeof o['text'] === 'string' && !!(o['text'] as string).trim() && (o['text'] as string).length <= 5000;
      if (get) permitted = basic && job.body === '' && job.url.startsWith(captured.origin + '/resource/PinResource/get/?') && keys.length === 2 && o['id'] === id && o['field_set_key'] === 'auth_web_main_pin';
      else if (basic && job.method === 'POST' && digits(viewer) && digits(aggregate)) {
        const suffix: string = job.url.slice(captured.origin.length);
        if (suffix === '/resource/AggregatedCommentResource/create/' || suffix === '/resource/AggregatedCommentReplyResource/create/' || suffix === '/resource/DidItCommentsResource/create/')
          permitted = keys.length === 5 && o['force'] === false && o['tags'] === '[]' && o['pinId'] === id && text &&
            o['objectId'] === (suffix === '/resource/AggregatedCommentResource/create/' ? aggregate : comment) && (suffix === '/resource/AggregatedCommentResource/create/' || digits(comment));
        else if (suffix === '/resource/AggregatedCommentResource/update/') permitted = own && digits(comment) && keys.length === 4 && o['commentId'] === comment && o['force'] === false && o['tags'] === '[]' && text;
        else if (suffix === '/resource/AggregatedCommentResource/delete/') permitted = own && digits(comment) && keys.length === 1 && o['commentId'] === comment;
        else if (suffix === '/resource/ApiResource/create/' || suffix === '/resource/ApiResource/delete/') {
          const data: Record<string,Object> = o['data'] as Record<string,Object>, url: Object | null = o['url'];
          if (keys.length === 2 && !!data && typeof data === 'object' && !Array.isArray(data)) {
            const fields: string[] = ['pin.id','user.id','user.full_name','user.username','user.image_medium_url','userdiditdata.id','userdiditdata.type','userdiditdata.details','userdiditdata.user()','userdiditdata.images[150x150,200x,736x,750x]','userdiditdata.pin()','userdiditdata.image_signatures','userdiditdata.like_count','userdiditdata.liked_by_me','userdiditdata.comment_count','userdiditdata.done_at'];
            if (suffix.endsWith('/create/') && url === '/v3/did_it/') permitted = Object.keys(data).length === 5 && data['pin'] === id && data['text_tags'] === '[]' &&
              typeof data['details'] === 'string' && (data['details'] as string).length <= 5000 && Array.isArray(data['image_signatures']) && (data['image_signatures'] as string[]).length === 1 &&
              /^[a-f0-9]{32}$/.test((data['image_signatures'] as string[])[0]) && Array.isArray(data['fields']) && JSON.stringify(data['fields']) === JSON.stringify(fields);
            else if (digits(comment) && url === '/v3/aggregated_comments/' + comment + '/react/') permitted = Object.keys(data).length === 1 && data['reaction_type'] === 1;
            else if (digits(comment) && url === '/v3/did_it/' + comment + '/like/') permitted = Object.keys(data).length === 0;
            else if (suffix.endsWith('/delete/') && own && digits(comment) && url === '/v3/did_it/' + comment + '/') permitted = Object.keys(data).length === 1 && data['pin'] === id;
          }
        }
      }
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
      authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch:captured.generation,page:pin,userAgent:actual.userAgent
    }; });
  }
  async requestBusinessPost(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, pin: string,
    viewer: string, writableBoards: string[], ownsPin: boolean, editableContent: boolean, copyId: string, copyOwned: boolean,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const match: RegExpMatchArray | null = pin.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/(\d{1,30})\/$/), id: string = match ? match[1] : '', path: string = '/pin/' + id + '/';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() && !!match && pin === captured.origin + path &&
        job.page === pin && job.epoch === captured.generation && job.id.startsWith('native_post_') && job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active';
      if(job.url === captured.origin + '/_/graphql/') {
        const q: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery, variables: Record<string,Object> = q.variables as Record<string,Object>;
        permitted = basic && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' && job.headers['X-Pinterest-Source-Url'] === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' &&
          Object.keys(q).length === 2 && !!variables && !Array.isArray(variables) && Object.keys(variables).length === 1 && variables['pinId'] === id &&
          (q.queryHash === '22ab0618812233f56510dbaeb1d76e342780a08cabb50624896db33300f9070e' || q.queryHash === 'b275f25a3893b0cf502a06e2f634402774be2a3d3b23199b141d4223174d39df' && ownsPin);
      }else {
        const get: boolean = job.method === 'GET', encoded: string = get ? job.url.slice(job.url.indexOf('?') + 1) : job.body;
        const form: RegExpMatchArray | null = encoded.match(get ? /^source_url=([^&]+)&data=([^&]+)&_=\d+$/ : /^source_url=([^&]+)&data=([^&]+)$/);
        const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope, o: Record<string,Object | null> = e.options;
        const source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '', keys: string[] = Object.keys(o);
        const envelope: boolean = basic && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && !!form && Object.keys(e).length === 2 &&
          !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && Object.keys(e.context).length === 0 && !!o && typeof o === 'object' && !Array.isArray(o) && job.headers['X-Pinterest-Source-Url'] === source;
        const pinSource: boolean = source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js';
        const user: boolean = /^\d{1,30}$/.test(viewer), text = (v: Object | null | undefined,max: number): boolean => typeof v === 'string' && v.length <= max;
        if(get && job.body === '' && job.url.startsWith(captured.origin + '/resource/PinResource/get/?'))permitted = envelope && pinSource && keys.length === 2 && o['field_set_key'] === 'auth_web_main_pin' && (o['id'] === id || !!copyId && copyId !== id && o['id'] === copyId && /^\d{1,30}$/.test(copyId) && user);
        else if(get && job.body === '' && job.url.startsWith(captured.origin + '/resource/BoardPickerBoardsResource/get/?'))permitted = envelope && user && source === path + 'repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id]/repin.js' && keys.length === 5 && o['pin_id'] === id && o['user_id'] === viewer && o['field_set_key'] === 'profile_grid_item' && o['shortlist_length'] === 2 && o['shortlist_suggestions'] === 3;
        else if(job.method === 'POST' && envelope && user) {
          if(job.url === captured.origin + '/resource/RepinResource/create/') {
            const quick: boolean = o['board_id'] === undefined, tracking: boolean = o['clientTrackingParams'] !== undefined;
            permitted = pinSource && o['pin_id'] === id && o['user_id'] === viewer && keys.length === (quick ? 2 : 3) + (tracking ? 1 : 0) && (!tracking || text(o['clientTrackingParams'],16384)) &&
              (quick ? writableBoards.includes('profile-quick-saves') : typeof o['board_id'] === 'string' && /^\d{1,30}$/.test(o['board_id'] as string) && writableBoards.includes(o['board_id'] as string));
          }else if(job.url === captured.origin + '/resource/BoardResource/create/') {
            const tracking: Object | null = o['initial_pin_client_tracking_params'];
            permitted = source === '/board/create/' + id && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' &&
              typeof o['name'] === 'string' && !!o['name'] && (o['name'] as string).trim() === o['name'] && text(o['name'],300) && (o['privacy'] === 'public' || o['privacy'] === 'secret') &&
              (keys.length === 2 || keys.length === 3 && Array.isArray(tracking) && tracking.length === 1 && text(tracking[0] as Object,16384));
          }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
            const data: Record<string,Object> = o['data'] as Record<string,Object>;
            permitted = pinSource && keys.length === 2 && o['url'] === '/v3/pins/' + id + '/react/' && !!data && !Array.isArray(data) && Object.keys(data).length === 2 && data['reaction_type'] === 1 && typeof data['client_tracking_params'] === 'string' && !!data['client_tracking_params'] && text(data['client_tracking_params'],16384);
          }else if(job.url === captured.origin + '/resource/PinResource/update/') {
            const disclosures: number[] = o['ai_disclosures'] as number[];
            permitted = pinSource && ownsPin && o['id'] === id && typeof o['board_id'] === 'string' && writableBoards.includes(o['board_id'] as string) &&
              typeof o['board_section_id'] === 'string' && (!o['board_section_id'] || /^\d{1,30}$/.test(o['board_section_id'] as string)) &&
              Array.isArray(disclosures) && disclosures.length <= 100 && disclosures.every((v: number): boolean => typeof v === 'number' && Number.isInteger(v)) &&
              (keys.length === 4 || editableContent && keys.length === 6 && text(o['title'],10000) && text(o['description'],10000));
          }else if(job.url === captured.origin + '/resource/PinResource/delete/') {
            permitted = pinSource && (keys.length === 1 || keys.length === 2 && text(o['client_tracking_params'],16386)) &&
              (o['id'] === id && ownsPin || copyOwned && !!copyId && copyId !== id && o['id'] === copyId && /^\d{1,30}$/.test(copyId));
          }
        }
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:pin,userAgent:actual.userAgent};});
  }
  async requestBusinessBoardSectionRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, board: string, section: string, sectionPath: string, current: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const query: RegExpMatchArray | null = job.url.match(/\?source_url=([^&]+)&data=([^&]+)&_=\d+$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(query ? query[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = e.options, source: string = query ? decodeURIComponent(query[1]) : '';
      const base: string = job.page.slice(captured.origin.length), handler: string = job.headers['X-Pinterest-Pws-Handler'];
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && current() && job.id.startsWith('native_board_section_read_') && job.page.startsWith(captured.origin + '/') && /^\/[^/?#]+\/[^/?#]+\/$/.test(base) && /^\d{1,30}$/.test(board) && /^\d{1,30}$/.test(section) && job.epoch === captured.generation && job.method === 'GET' && !job.body && !!query && Object.keys(e).length === 2 && !!e.context && !Array.isArray(e.context) && Object.keys(e.context).length === 0 && !!o && !Array.isArray(o) && job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest';
      const organize: boolean = source === '/boardsection/' + section + '/organize/repin/' && handler === 'www/boardsection/[id]/organize/add.js';
      const route: boolean = sectionPath.startsWith(base) && /^[^/?#]+\/$/.test(sectionPath.slice(base.length));
      if(job.url.startsWith(captured.origin + '/resource/BoardSectionResource/get/?'))permitted = basic && organize && Object.keys(o).length === 1 && o['section_id'] === section;
      else if(job.url.startsWith(captured.origin + '/resource/ApiResource/get/?')) {
        const d: Record<string,Object> = o['data'] as Record<string,Object>;
        const tools: boolean = o['url'] === '/v3/boards/sections/' + section + '/tools/' && route && source === sectionPath && handler === 'www/[username]/[slug]/[section_slug].js';
        const targets: boolean = o['url'] === '/v3/board/' + board + '/sections/all/' && organize;
        permitted = basic && Object.keys(o).length === 2 && !!d && Object.keys(d).length === 1 && JSON.stringify(d['fields']) === JSON.stringify(tools ? ['boardtool.id','boardtool.type','boardtool.tool','boardtool.text','boardtool.icon','boardtool.link','boardtool.show_badge'] : ['boardsection.board','boardsection.id','boardsection.slug','boardsection.title','boardsection.type','boardsection.preview_pins(limit:1)']) && (tools || targets);
      } else if(job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?'))permitted = basic && route && source === sectionPath + '_tools/more-ideas/?ideas_referrer=24' && handler === 'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js' && Object.keys(o).length === 3 && o['id'] === board && o['type'] === 'board' && o['__track__referrer'] === 24;
    }catch (_) {}
    return this.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && current() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

  async requestBusinessBoardSectionWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    board: string, section: string, viewer: string, owner: string, allIds: string[], selected: string[], complete: boolean,
    targets: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, source: string = form ? decodeURIComponent(form[1]) : '';
      const digits = (value: string): boolean => /^\d{1,30}$/.test(value);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_section_write_') && job.epoch === captured.generation && job.method === 'POST' &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(job.page.slice(captured.origin.length)) && job.page.startsWith(captured.origin + '/') &&
        digits(board) && digits(section) && digits(viewer) && viewer === owner &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 && !!o && !Array.isArray(o);
      if(job.url === captured.origin + '/resource/ApiResource/delete/')permitted = basic && Object.keys(o).length === 1 &&
        o['url'] === '/v3/board/sections/' + section + '/' && source === '/boardsection/' + section + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/edit.js';
      else if(job.url === captured.origin + '/resource/ApiResource/update/') {
        const d: Record<string,Object> = o['data'] as Record<string,Object>;
        permitted = basic && Object.keys(o).length === 2 && o['url'] === '/v3/board/sections/' + section + '/' && !!d && !Array.isArray(d) && Object.keys(d).length === 2 && typeof d['title'] === 'string' && (d['title'] as string).trim() === d['title'] && (d['title'] as string).length > 0 && (d['title'] as string).length <= 100 && JSON.stringify(d['fields']) === JSON.stringify(['boardsection.board()','boardsection.id','boardsection.pin_count','boardsection.preview_pins()','boardsection.slug','boardsection.title','boardsection.type']) && source === '/boardsection/' + section + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/edit.js';
      }
      else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        const d: Record<string,Object> = o['data'] as Record<string,Object>;
        const sectionTarget: boolean = typeof d?.['new_section_id'] === 'string';
        const destination: boolean = sectionTarget ? Object.keys(d).length === 4 && typeof d['new_section_id'] === 'string' && digits(d['new_section_id'] as string) && d['new_section_id'] !== section && typeof d['new_board_id'] === 'string' && targets.includes(d['new_board_id'] as string) && (d['new_board_id'] === board && targets.includes('section:' + (d['new_section_id'] as string)) || targets.includes('section:' + (d['new_board_id'] as string) + ':' + (d['new_section_id'] as string))) : !!d && Object.keys(d).length === 3 && typeof d['new_board_id'] === 'string' && targets.includes(d['new_board_id'] as string);
        permitted = basic && complete && allIds.length <= 500 && new Set(allIds).size === allIds.length && allIds.every(digits) &&
          selected.length > 0 && new Set(selected).size === selected.length && selected.every((id: string): boolean => allIds.includes(id)) &&
          Object.keys(o).length === 2 && o['url'] === '/v3/boards/' + board + '/bulk/' && !!d && !Array.isArray(d) && destination &&
          typeof d['new_board_id'] === 'string' && digits(d['new_board_id'] as string) && d['old_section_id'] === section &&
          JSON.stringify(d['exclude_pin_ids']) === JSON.stringify(allIds.filter((id: string): boolean => !selected.includes(id))) &&
          source === '/boardsection/' + section + '/organize/repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/organize/add.js';
      }
    }catch (_) {}
    return this.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

  async requestBusinessBoardContent(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, canContribute: boolean, loadedIds: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const get: boolean = job.method === 'GET', query: string = job.url.slice(job.url.indexOf('?') + 1);
      const form: RegExpMatchArray | null = (get ? query : job.body).match(get ? /^source_url=([^&]+)&data=([^&]+)&_=\d+$/ : /^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_content_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^\d{1,30}$/.test(ownerId) &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && typeof o === 'object' && !Array.isArray(o);
      if(job.url === captured.origin + '/resource/BoardSectionResource/create/') {
        permitted = basic && job.method === 'POST' && canContribute && [ '/board/' + boardId + '/create_section/', '/board/' + boardId + '/create_section/pins/' ].includes(source) &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/create_section.js' && Object.keys(o).length === 3 && o['board_id'] === boardId &&
          typeof o['name'] === 'string' && (o['name'] as string).length > 0 && (o['name'] as string).length <= 100 && (o['name'] as string).trim() === o['name'] &&
          Array.isArray(o['initial_pins']) && (o['initial_pins'] as string[]).length <= 500 &&
          new Set(o['initial_pins'] as string[]).size === (o['initial_pins'] as string[]).length &&
          (o['initial_pins'] as string[]).every((id: string): boolean => /^\d{1,30}$/.test(id) && loadedIds.includes(id)) &&
          (source.endsWith('/pins/') || (o['initial_pins'] as string[]).length === 0);
      }else {
        const pin: RegExpMatchArray | null = source.match(/^\/pin\/(\d{1,30})\/$/), id: string = pin ? pin[1] : '';
        const copy: boolean = basic && viewerId === ownerId && !!id && loadedIds.includes(id) && o['id'] === id &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' && job.headers['X-Pinterest-AppState'] === 'active' && job.headers['X-Pinterest-Source-Url'] === source;
        if(get)permitted = copy && job.body === '' && job.url.startsWith(captured.origin + '/resource/PinResource/get/?') && Object.keys(o).length === 2 && o['field_set_key'] === 'auth_web_main_pin';
        else permitted = copy && job.method === 'POST' && job.url === captured.origin + '/resource/PinResource/delete/' &&
          (Object.keys(o).length === 1 || Object.keys(o).length === 2 && typeof o['client_tracking_params'] === 'string' &&
            (o['client_tracking_params'] as string).length > 2 && (o['client_tracking_params'] as string).length <= 16386 && (o['client_tracking_params'] as string).endsWith('~0'));
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessBoardManagementWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, member: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_management_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^\d{1,30}$/.test(ownerId) && job.method === 'POST' &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && typeof o === 'object' && !Array.isArray(o);
      const own: boolean = viewerId === ownerId, participant: boolean = own || member;
      const editSource: boolean = source === '/board/' + boardId + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/edit.js';
      if(job.url === captured.origin + '/resource/BoardResource/update/') {
        permitted = basic && own && editSource && Object.keys(o).length === 8 && o['board_id'] === boardId &&
          typeof o['name'] === 'string' && (o['name'] as string).length > 0 && (o['name'] as string).length <= 300 && (o['name'] as string).trim() === o['name'] &&
          typeof o['description'] === 'string' && (o['description'] as string).length <= 500 && (o['privacy'] === 'public' || o['privacy'] === 'secret') &&
          typeof o['allow_homefeed_recommendations'] === 'boolean' && typeof o['collaborator_invites_enabled'] === 'boolean' && typeof o['collaborator_requests_enabled'] === 'boolean' && o['sensitivity'] === null;
      }else if(job.url === captured.origin + '/resource/BoardResource/delete/') {
        permitted = basic && own && editSource && Object.keys(o).length === 1 && o['board_id'] === boardId;
      }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        permitted = basic && participant && source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js' &&
          Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + boardId + '/archive/';
      }else if(job.url === captured.origin + '/resource/ApiResource/delete/') {
        const allowed: boolean = basic && member && !own && source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js';
        permitted = allowed && (Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + boardId + '/follow/' ||
          Object.keys(o).length === 2 && o['url'] === '/v3/boards/' + boardId + '/collaborators/' + viewerId + '/' &&
          !!o['data'] && typeof o['data'] === 'object' && !Array.isArray(o['data']) && Object.keys(o['data'] as Object).length === 0);
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessBoardPinWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, loadedIds: string[], enabledTargets: string[], recommendedIds: string[], ownerCurrent: () => boolean, savedCopies: string[] = [], recommendationPath: string = ''): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, keys: string[] = Object.keys(o), source: string = form ? decodeURIComponent(form[1]) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_pin_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && job.method === 'POST' &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && typeof o === 'object' && !Array.isArray(o);
      const section: boolean = recommendationPath.startsWith(path) && /^\/[^/?#]+\/[^/?#]+\/[^/?#]+\/_tools\/more-ideas\/\?ideas_referrer=24$/.test(recommendationPath);
      const recommendation: boolean = section ? source === recommendationPath && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js' : !recommendationPath && source === path + '_tools/more-ideas/?ideas_referrer=23' && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug]/_tools/more-ideas.js';
      if(job.url === captured.origin + '/resource/PinResource/delete/') {
        permitted = basic && recommendation && keys.length === 2 && typeof o['id'] === 'string' && /^\d{1,30}$/.test(o['id'] as string) && savedCopies.includes(o['id'] as string) && typeof o['client_tracking_params'] === 'string' && (o['client_tracking_params'] as string).length <= 16384;
      }else if(job.url === captured.origin + '/resource/RepinResource/create/') {
        permitted = basic && recommendation &&
          (keys.length === 3 || keys.length === 4 && keys.includes('clientTrackingParams')) && typeof o['pin_id'] === 'string' && /^\d{1,30}$/.test(o['pin_id'] as string) &&
          recommendedIds.includes(o['pin_id'] as string) && o['board_id'] === boardId && o['user_id'] === viewerId && (o['clientTrackingParams'] === undefined || typeof o['clientTrackingParams'] === 'string' && (o['clientTrackingParams'] as string).length <= 16384);
      }else if(job.url === captured.origin + '/resource/BoardResource/create/') {
        permitted = basic && source === '/board/create/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/create.js' && keys.length === 2 &&
          typeof o['name'] === 'string' && !!(o['name'] as string).trim() && o['name'] === (o['name'] as string).trim() && (o['name'] as string).length <= 100 &&
          ['public','secret'].includes(o['privacy'] as string);
      }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        const data: Record<string,Object> = o['data'] as Record<string,Object>, ids: string[] = data['pin_ids'] as string[];
        permitted = basic && source === '/board/' + boardId + '/organize/repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/organize.js' &&
          keys.length === 2 && o['url'] === '/v3/pins/bulk/move/' && !!data && typeof data === 'object' && !Array.isArray(data) && Object.keys(data).length === 2 &&
          typeof data['board_id'] === 'string' && /^\d{1,30}$/.test(data['board_id'] as string) && data['board_id'] !== boardId && enabledTargets.includes(data['board_id'] as string) &&
          Array.isArray(ids) && ids.length > 0 && ids.length <= 500 && ids.every((id: string,index: number): boolean => typeof id === 'string' && /^\d{1,30}$/.test(id) && ids.indexOf(id) === index && loadedIds.includes(id));
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessBoardCollaboratorWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, canInvite: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_collab_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^\d{1,30}$/.test(ownerId) &&
        job.method === 'POST' && job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest';
      if(job.url === captured.origin + '/resource/BoardResource/update/') {
        const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
        const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
        const o: Record<string,Object | null> = envelope.options;
        permitted = basic && viewerId === ownerId && !!form && decodeURIComponent(form[1]) === '/board/' + boardId + '/edit/' &&
          job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/edit.js' &&
          Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
          !!o && typeof o === 'object' && !Array.isArray(o) && Object.keys(o).length === 4 && o['board_id'] === boardId &&
          (o['collaborator_permissions_setting'] === 0 || o['collaborator_permissions_setting'] === 1) &&
          typeof o['collaborator_invites_enabled'] === 'boolean' && o['sensitivity'] === null;
      } else if(job.url === captured.origin + '/_/graphql/') {
        const query: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery;
        const v: Record<string,Object> = query.variables as Record<string,Object>, ids: string[] = v['collaboratorIds'] as string[];
        permitted = basic && canInvite && job.headers['Content-Type'] === 'application/json' && job.headers['X-Pinterest-Source-Url'] === path &&
          Object.keys(query).length === 2 && query.queryHash === '42ceaa3423a096a27613e5738f83aaadcee449c55d4dd03624d2f08a6b6dca04' &&
          !Array.isArray(v) && Object.keys(v).length === 3 && v['boardId'] === boardId && v['message'] === '' &&
          Array.isArray(ids) && ids.length === 1 && typeof ids[0] === 'string' && /^\d{1,30}$/.test(ids[0]) && ids[0] !== viewerId && ids[0] !== ownerId;
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};
    });
  }
  async requestBusinessBoardAuxRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, username: string, viewerId: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/), source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(encoded ? encoded[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options, keys: string[] = Object.keys(o), path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((p: string): boolean => !!p);
      const cursor: string[] | undefined = o['bookmarks'] as string[] | undefined, handler: string = job.headers['X-Pinterest-Pws-Handler'];
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_aux_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^[A-Za-z0-9_]+$/.test(username) &&
        job.method === 'GET' && job.body === '' && !!source && Object.keys(payload).length === 2 && !Array.isArray(o) && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        (cursor === undefined || Array.isArray(cursor) && cursor.length === 1 && typeof cursor[0] === 'string' && cursor[0].length > 0 && cursor[0].length <= 4096);
      const sourcePath: string = source ? decodeURIComponent(source[1]) : '';
      if(job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?')) {
        permitted = basic && sourcePath === path + '_tools/more-ideas/?ideas_referrer=23' && handler === 'www/[username]/[slug]/_tools/more-ideas.js' && keys.length === 3 && o['id'] === boardId && o['type'] === 'board' && o['__track__referrer'] === 23;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardsResource/get/?')) {
        permitted = basic && sourcePath === '/board/' + boardId + '/organize/repin/' && handler === 'www/board/[id]/organize.js' &&
          (keys.length === 9 || keys.length === 10 && keys.includes('bookmarks')) && keys.every((k: string): boolean => ['privacy_filter','sort','field_set_key','filter_stories','username','page_size','group_by','include_archived','filter_all_pins','bookmarks'].includes(k)) &&
          o['privacy_filter'] === 'all' && o['sort'] === 'custom' && o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === true && o['username'] === username && o['page_size'] === 25 && o['group_by'] === 'mix_public_private' && o['include_archived'] === true && o['filter_all_pins'] === false;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardResource/get/?')) {
        permitted = basic && keys.length === 2 && o['board_id'] === boardId && (o['field_set_key'] === 'edit' && sourcePath === '/board/' + boardId + '/edit/' && handler === 'www/board/[id]/edit.js' || o['field_set_key'] === 'boardEdit' && sourcePath === path && handler === 'www/index.js');
      } else if(job.url.startsWith(captured.origin + '/resource/BoardInvitesResource/get/?')) {
        permitted = basic && sourcePath === path && handler === 'www/index.js' && keys.length === 5 && o['board_id'] === boardId && o['sort'] === 'viewer_first' && o['field_set_key'] === 'boardEdit' && o['status_filters'] === 'new,accepted,contact_request_not_approved,pending_approval' && o['include_inactive'] === true;
      } else if(job.url.startsWith(captured.origin + '/resource/ShareSuggestionsResource/get/?')) {
        permitted = basic && sourcePath === path && handler === 'www/index.js' && keys.length === 2 && o['suggestion_type'] === 'group_board' && o['board'] === boardId;
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessBoardRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, sectionId: string, viewerId: string, ownCollection: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/), source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(encoded ? encoded[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options, keys: string[] = Object.keys(o), path: string = job.page.slice(captured.origin.length);
      const parts: string[] = path.split('/').filter((p: string): boolean => !!p), cursor: string[] | undefined = o['bookmarks'] as string[] | undefined;
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:followers|following)$/i.test(parts[1]) && job.method === 'GET' && job.body === '' &&
        !!source && decodeURIComponent(source[1]) === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        Object.keys(payload).length === 2 && !Array.isArray(o) && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        (cursor === undefined || Array.isArray(cursor) && cursor.length === 1 && typeof cursor[0] === 'string' && cursor[0].length > 0 && cursor[0].length <= 4096);
      const collection: boolean = parts[1] === 'pins', id: boolean = /^\d{1,30}$/.test(boardId), viewer: boolean = /^\d{1,30}$/.test(viewerId);
      if(job.url.startsWith(captured.origin + '/resource/BoardResource/get/?')) {
        permitted = basic && !collection && keys.length === 4 && o['field_set_key'] === 'profile_grid_item' && o['is_mobile_fork'] === true && o['username'] === decodeURIComponent(parts[0]) && o['slug'] === decodeURIComponent(parts[1]);
      } else if(job.url.startsWith(captured.origin + '/resource/UserResource/get/?')) {
        permitted = basic && collection && keys.length === 1 && o['username'] === decodeURIComponent(parts[0]);
      } else if(job.url.startsWith(captured.origin + '/resource/BoardFeedResource/get/?')) {
        const fields: string[] = ['add_vase','board_id','field_set_key','filter_section_pins','is_react','prepend','page_size','redux_normalize_feed','gated','bookmarks'];
        permitted = basic && !collection && id && viewer && (keys.length === 9 || keys.length === 10 && keys.includes('bookmarks')) && keys.every((k: string): boolean => fields.includes(k)) &&
          o['board_id'] === boardId && o['add_vase'] === false && o['field_set_key'] === 'react_grid_pin' && o['filter_section_pins'] === true && o['is_react'] === true && o['prepend'] === false && o['page_size'] === 15 && o['redux_normalize_feed'] === true && o['gated'] === false;
      } else if(job.url.startsWith(captured.origin + '/resource/UserPinsResource/get/?')) {
        permitted = basic && collection && id && viewer && (keys.length === 4 || keys.length === 5 && keys.includes('bookmarks')) && keys.every((k: string): boolean => ['add_vase','field_set_key','is_own_profile_pins','username','bookmarks'].includes(k)) && o['add_vase'] === false && o['field_set_key'] === 'mobile_grid_item' && o['is_own_profile_pins'] === ownCollection && o['username'] === decodeURIComponent(parts[0]);
      } else if(job.url.startsWith(captured.origin + '/resource/BoardSectionsResource/get/?')) {
        permitted = basic && !collection && id && viewer && keys.length === 2 && o['board_id'] === boardId && o['redux_normalize_feed'] === true;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardSectionPinsResource/get/?')) {
        permitted = basic && !collection && id && viewer && /^\d{1,30}$/.test(sectionId) && (keys.length === 3 || keys.length === 4 && keys.includes('bookmarks')) && keys.every((k: string): boolean => ['page_size','prepend','section_id','bookmarks'].includes(k)) && o['page_size'] === 25 && o['prepend'] === false && o['section_id'] === sectionId;
      }
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
  }
  async requestBusinessPinMenu(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = pin.slice(captured.origin.length), match: RegExpMatchArray | null = path.match(/^\/pin\/(\d{1,30})\/$/);
      const get: boolean = job.method === 'GET', source = (get ? job.url : job.body).match(/[?&]?source_url=([^&]+)/);
      const raw = (get ? job.url : job.body).match(/[?&]data=([^&]+)/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(raw ? raw[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, keys: string[] = Object.keys(o);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() && !!match &&
        pin === captured.origin + path && job.page === pin && job.epoch === captured.generation && job.id.startsWith('native_pin_menu_') &&
        job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' &&
        job.headers['X-Pinterest-Source-Url'] === path && !!source && decodeURIComponent(source[1]) === path &&
        Object.keys(envelope).length === 2 && !!o && !Array.isArray(o) && !!envelope.context && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0;
      if(get)permitted = basic && job.body === '' && job.url.startsWith(captured.origin + '/resource/PinResource/get/?') && keys.length === 6 &&
        keys.every((k: string): boolean => ['id','field_set_key','noCache','fetch_visual_search_objects','get_page_metadata','add_fields'].includes(k)) &&
        o['id'] === match![1] && o['field_set_key'] === 'auth_web_main_pin' && o['noCache'] === true && o['fetch_visual_search_objects'] === false && o['get_page_metadata'] === false &&
        o['add_fields'] === 'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin';
      else if(basic && job.method === 'POST' && job.url === captured.origin + '/resource/ApiResource/update/' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && keys.length === 2 && keys.includes('url') && keys.includes('data')) {
        const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>, names: string[] = Object.keys(data);
        const id: string = match![1], less: boolean = o['url'] === '/v3/pfy/' + id + '/feedback/', more: boolean = o['url'] === '/v3/pin/' + id + '/feedback/see_more/', undo: boolean = o['url'] === '/v3/pin/' + id + '/feedback/see_more/undo/';
        const fields: string[] = less ? ['pin','client_tracking_params','feedback_type'] : undo ? ['pin','client_tracking_params','source'] : ['pin','client_tracking_params','source','through_id','rec_reason_type'];
        permitted = (less || more || undo) && !!data && !Array.isArray(data) && data['pin'] === id && names.every((k: string): boolean => fields.includes(k)) &&
          (data['client_tracking_params'] === undefined || typeof data['client_tracking_params'] === 'string' && (data['client_tracking_params'] as string).length > 0 && (data['client_tracking_params'] as string).length <= 16384) &&
          (data['through_id'] === undefined || typeof data['through_id'] === 'string' && (data['through_id'] as string).length <= 2000) &&
          (data['source'] === undefined || typeof data['source'] === 'number' && Number.isFinite(data['source'] as number)) &&
          (data['rec_reason_type'] === undefined || typeof data['rec_reason_type'] === 'number' && Number.isFinite(data['rec_reason_type'] as number)) &&
          (!less || data['feedback_type'] === 10) && (!undo || data['source'] === 5);
      }
    }catch (_) {}
    return this.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

  async requestBusinessAuxiliary(job: PinmonyNetworkJob,session: () => PinmonyBusinessSessionContext,mode: string,target: string,ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const get: boolean = job.method === 'GET',fields: string = get ? job.url.split('?')[1] || '' : job.body;
      const source: RegExpMatchArray | null = fields.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(source ? source[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = e.options,keys: string[] = Object.keys(o),path: string = job.page.slice(captured.origin.length);
      const exact = (allowed: string[]): boolean => keys.length === allowed.length && keys.every((k: string): boolean => allowed.includes(k));
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_aux_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') && path.length <= 4096 && !path.includes('#') &&
        !!source && decodeURIComponent(source[1]) === path && Object.keys(e).length === 2 && !!e.context && !Array.isArray(e.context) && Object.keys(e.context).length === 0 && !!o && !Array.isArray(o) &&
        (get ? job.body === '' : job.method === 'POST') && job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-Source-Url'] === path &&
        job.headers['X-Pinterest-Pws-Handler'] === (mode === 'quiz' ? 'www/search/[scope].js' : 'www/index.js');
      const endpoint: string = job.url.split('?')[0].slice(captured.origin.length);
      const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
      const search: boolean = /^\/search\/(?:pins\/?)?(?:\?[^#]*)?$/.test(path);
      if(mode === 'quiz' && search && get) {
        if(endpoint === '/resource/UserExperienceResource/get/') {
          const extra: Record<string,Object | null> = o['extra_context'] as Record<string,Object | null>;
          const query: RegExpMatchArray | null = path.match(/[?&]q=([^&]*)/);
          permitted = basic && exact(['placement_ids','extra_context']) && JSON.stringify(o['placement_ids']) === '[1000269]' && !!query && !!extra && Object.keys(extra).length === 1 && extra['search_query'] === decodeURIComponent(query[1].replace(/\+/g,' '));
        }else if(endpoint === '/resource/BaseSearchResource/get/') {
          const bookmarks: string[] | undefined = o['bookmarks'] as string[] | undefined;
          permitted = basic && keys.every((k: string): boolean => ['query','scope','page_size','enable_promoted_pins','bookmarks'].includes(k)) && keys.length === (bookmarks ? 5 : 4) &&
            typeof o['query'] === 'string' && (o['query'] as string).length > 0 && (o['query'] as string).length <= 300 && o['query'] === target && o['scope'] === 'pins' && o['page_size'] === 25 && o['enable_promoted_pins'] === false &&
            (!bookmarks || Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && bookmarks[0].length > 0 && bookmarks[0].length <= 4096);
        }else if(endpoint === '/resource/ApiResource/get/') {
          const ids: string[] = data?.['pin_ids'] as string[];
          permitted = basic && exact(['url','data']) && o['url'] === '/v3/batch/related/pins/' && !!data && Object.keys(data).length === 3 && data['client_type'] === 118 && data['prepend_seed_pins'] === false && Array.isArray(ids) && ids.length > 0 && ids.length <= 10 && new Set(ids).size === ids.length && ids.every((id: string): boolean => /^\d{1,30}$/.test(id)) && ids.join(',') === target;
        }
      }else if(mode === 'history' && search && !get && endpoint === '/resource/ApiResource/delete/') {
        permitted = basic && exact(['url','data']) && o['url'] === '/v3/search/recent/' && !!data && Object.keys(data).length === 2 && typeof target === 'string' && target.trim().length > 0 && target.length <= 300 && data['query'] === target && data['vertical'] === 'PIN';
      }else if(mode === 'news' && /^\/(?:inbox|messages|updates|notifications)\/$/.test(path) && !get && /^\d{1,40}$/.test(target) && exact(['url','data']) && !!data) {
        if(endpoint === '/resource/ApiResource/update/')permitted = basic && o['url'] === '/v3/news_hub/hide/batch/' && Object.keys(data).length === 2 && JSON.stringify(data['news_ids']) === JSON.stringify([target]) && typeof data['should_hide'] === 'boolean';
        if(endpoint === '/resource/ApiResource/create/')permitted = basic && o['url'] === '/v3/settings/notifications/objects/' && Object.keys(data).length === 1 && JSON.stringify(data['object_ids_to_unsubscribe']) === JSON.stringify([target]);
      }else if(mode === 'invites' && (/^\/(?:inbox|messages|updates|notifications)\/$/.test(path) || /^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(path))) {
        if(get && endpoint === '/resource/BoardInvitesResource/get/')permitted = basic && exact(['current_user','field_set_key']) && o['current_user'] === true && o['field_set_key'] === 'news';
        if(endpoint === '/resource/BoardInviteResource/' + (get ? 'get/' : 'update/'))permitted = basic && exact(get ? ['board_id','invited_user_id','field_set_key'] : ['board_id','invited_user_id']) && /^\d{1,30}$/.test(o['board_id'] as string) && /^\d{1,30}$/.test(o['invited_user_id'] as string) && target === o['board_id'] + ':' + o['invited_user_id'] && (!get || o['field_set_key'] === 'boardEdit');
      }
    }catch (_) {}
    return this.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

  async requestBusinessProfileRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, userId: string, ownerCurrent: () => boolean, viewerId: string = '', visitor: boolean = false): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const raw: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/), source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(raw ? raw[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options, keys: string[] = Object.keys(o);
      const path: string = profileUrl.slice(captured.origin.length), username: string = path.split('/')[1], bookmarks: string[] | undefined = o['bookmarks'] as string[] | undefined;
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        profileUrl.startsWith(captured.origin + '/') && /^\/[A-Za-z0-9_]+\/$/.test(path) &&
        job.page === profileUrl && job.id.startsWith('native_profile_') && job.epoch === captured.generation && job.method === 'GET' && job.body === '' &&
        !!source && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && Object.keys(payload).length === 2 &&
        !Array.isArray(o) && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        (bookmarks === undefined || Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && bookmarks[0].length > 0 && bookmarks[0].length <= 4096);
      const own: boolean = typeof userId === 'string' && /^\d{1,40}$/.test(userId) && (!visitor || /^\d{1,40}$/.test(viewerId));
      const self: boolean = !visitor || userId === viewerId;
      if(job.url.startsWith(captured.origin + '/resource/UserResource/get/?')) {
        permitted = basic && decodeURIComponent(source![1]) === path && keys.length === 2 && o['field_set_key'] === 'profile' && o['username'] === username;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardsFeedResource/get/?')) {
        permitted = basic && own && decodeURIComponent(source![1]) === path && (keys.length === 4 || keys.length === 5 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','filter_stories','sort','username','bookmarks'].includes(k)) && o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === false && o['sort'] === 'last_pinned_to' && typeof o['username'] === 'string' && (o['username'] as string).toLowerCase() === username.toLowerCase();
      } else if(job.url.startsWith(captured.origin + '/resource/UserActivityPinsResource/get/?')) {
        permitted = basic && own && decodeURIComponent(source![1]) === path + '_created/' && (keys.length === 5 || keys.length === 6 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','exclude_add_pin_rep','is_own_profile_pins','user_id','username','bookmarks'].includes(k)) && o['field_set_key'] === 'profile_created_grid_item' && o['exclude_add_pin_rep'] === true && o['is_own_profile_pins'] === self && o['user_id'] === userId && typeof o['username'] === 'string' && (o['username'] as string).toLowerCase() === username.toLowerCase();
      } else if(job.url.startsWith(captured.origin + '/resource/BoardlessPinsResource/get/?')) {
        permitted = basic && own && self && decodeURIComponent(source![1]) === path && (keys.length === 3 || keys.length === 4 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','redux_normalize_feed','userId','bookmarks'].includes(k)) && o['field_set_key'] === 'mobile' && o['redux_normalize_feed'] === true && o['userId'] === userId;
      }
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
  }
  async requestBusinessInboxWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, viewerId: string, conversationId: string,
    contacts: string[], selectedIds: string[], reactionIds: string[], ownMessageIds: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, keys: string[] = Object.keys(o), source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_inbox_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') && /^\/(?:inbox|messages|updates|notifications)\/$/.test(path) &&
        /^\d{1,40}$/.test(viewerId) && job.method === 'POST' && source === path && job.headers['Accept'] === 'application/json' &&
        job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active' &&
        job.headers['X-Pinterest-Source-Url'] === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && !!form && Object.keys(envelope).length === 2 &&
        !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 && !!o && typeof o === 'object' && !Array.isArray(o);
      const chat: boolean = /^\d{1,40}$/.test(conversationId);
      if(job.url === captured.origin + '/resource/ConversationMessagesResource/create/') {
        const fields: string[] = o['field_set_key'] as string[];
        permitted = basic && chat && keys.length === 3 && o['conversation_id'] === conversationId && typeof o['text'] === 'string' &&
          (o['text'] as string).length > 0 && (o['text'] as string).length <= 2000 && (o['text'] as string).trim() === o['text'] && Array.isArray(fields) && fields.length === 1 && fields[0] === 'default_with_reactions';
      }else if(job.url === captured.origin + '/resource/ConversationsResource/create/') {
        const ids: string[] = o['user_ids'] as string[], emails: string[] = o['emails'] as string[];
        permitted = basic && !conversationId && keys.length === 2 && Array.isArray(emails) && emails.length === 0 && Array.isArray(ids) && ids.length > 0 && ids.length <= 1000 &&
          ids.length === selectedIds.length && ids.every((id: string,index: number): boolean => typeof id === 'string' && /^\d{1,40}$/.test(id) && id !== viewerId && ids.indexOf(id) === index && contacts.includes(id) && selectedIds[index] === id);
      }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        const url: RegExpMatchArray | null = typeof o['url'] === 'string' ? (o['url'] as string).match(/^\/v3\/conversations\/messages\/(\d{1,40})\/$/) : null;
        const data: Record<string,Object> = o['data'] as Record<string,Object>;
        permitted = basic && chat && keys.length === 2 && !!url && reactionIds.includes(url[1]) && !!data && typeof data === 'object' && !Array.isArray(data) && Object.keys(data).length === 1 &&
          typeof data['reaction_text'] === 'string' && ['❤️','😂','😍','😮','👍','👎'].includes(data['reaction_text'] as string);
      }else if(job.url === captured.origin + '/resource/ApiResource/delete/' || job.url === captured.origin + '/resource/ApiResource/update/') {
        const message: RegExpMatchArray | null = typeof o['url'] === 'string' ? (o['url'] as string).match(/^\/v3\/conversations\/messages\/(\d{1,40})\/$/) : null;
        const user: RegExpMatchArray | null = typeof o['url'] === 'string' ? (o['url'] as string).match(/^\/v3\/users\/(\d{1,40})\/block\/$/) : null;
        permitted = basic && chat && keys.length === 1 && (!!message && job.url === captured.origin + '/resource/ApiResource/delete/' && ownMessageIds.includes(message[1]) ||
          !!user && user[1] !== viewerId && contacts.includes(user[1]));
      }
    }catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
  async requestBusinessInboxMessagesRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const raw: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/); const source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(raw ? raw[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options; const keys: string[] = Object.keys(o);
      const path: string = job.page.slice(captured.origin.length);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_inbox_messages_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/(?:inbox|messages|updates|notifications)\/$/.test(path) && job.method === 'GET' && job.body === '' &&
        !!source && decodeURIComponent(source[1]) === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        Object.keys(payload).length === 2 && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 && !Array.isArray(o);
      if(job.url.startsWith(captured.origin + '/resource/ConversationsResource/get/?')) {
        permitted = basic && keys.length === 1 && o['field_set_key'] === 'default';
      } else if(job.url.startsWith(captured.origin + '/resource/ShareSuggestionsResource/get/?')) {
        permitted = basic && o['field_set_key'] === 'default' && (keys.length === 1 || keys.length === 2 && o['hide_group_conversations'] === true);
      } else if(job.url.startsWith(captured.origin + '/resource/ShareSuggestionsTypeaheadResource/get/?')) {
        permitted = basic && keys.length === 3 && o['count'] === 25 && o['pin_scope'] === 'pins' && typeof o['term'] === 'string' && (o['term'] as string).trim().length > 0 && (o['term'] as string).length <= 500;
      } else if(job.url.startsWith(captured.origin + '/resource/ConversationMessagesResource/get/?')) {
        const fields: string[] = o['field_set_key'] as string[]; const bookmarks: string[] | undefined = o['bookmarks'] as string[] | undefined;
        permitted = basic && (keys.length === 5 || keys.length === 6 && keys.includes('bookmarks')) &&
          keys.every((key: string): boolean => ['conversation_id','page_size','refresh','hide_sys_msg','field_set_key','bookmarks'].includes(key)) &&
          typeof o['conversation_id'] === 'string' && /^\d{1,40}$/.test(o['conversation_id'] as string) && o['page_size'] === 25 && o['refresh'] === false && o['hide_sys_msg'] === true &&
          Array.isArray(fields) && fields.length === 1 && fields[0] === 'default_with_reactions_and_deleted_by' &&
          (bookmarks === undefined || Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && bookmarks[0].length > 0 && bookmarks[0].length <= 4096);
      } else if(job.url.startsWith(captured.origin + '/resource/ApiResource/get/?')) {
        const api: NativeSearchApiOptions = o as Object as NativeSearchApiOptions;
        const fields: string[] = api.data['fields'] as string[]; const expected: string[] = ['conversation.id','conversation.name','conversation.users()','conversation.read_times_ms','user.id','user.username','user.full_name','user.image_medium_url','user.type'];
        permitted = basic && keys.length === 2 && keys.includes('url') && keys.includes('data') && /^\/v3\/conversations\/\d{1,40}\/$/.test(api.url) &&
          !Array.isArray(api.data) && Object.keys(api.data).length === 1 && Array.isArray(fields) && fields.length === expected.length && expected.every((field: string,index: number): boolean => fields[index] === field);
      }
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
  }
  async requestBusinessInboxUpdatesRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/); const source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: InboxUpdatesEnvelope = JSON.parse(decodeURIComponent(encoded ? encoded[1] : '')) as InboxUpdatesEnvelope;
      const o: InboxUpdatesReadOptions = payload.options; const keys: string[] = Object.keys(o); const fields: string[] = ['board.name','board.id','board.images[170x]','board.image_cover_url','board.image_thumbnail_urls[100x]','board.subscribed_to_notifications','board.type','interest.background_color','interest.id','interest.type','interest.images[236x]','interest.name','pin.description','pin.id','pin.image_signature','pin.images[150x150,345x]','pin.subscribed_to_notifications','pin.title','pin.tracking_params','pin.type','user.full_name','user.id','user.image_large_url','user.recent_pin_images[200x]','user.subscribed_to_notifications','user.type'];
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_inbox_updates_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/(?:inbox|messages|updates|notifications)\/$/.test(job.page.slice(captured.origin.length)) &&
        job.url.startsWith(captured.origin + '/resource/ApiResource/get/?') && job.method === 'GET' && job.body === '' &&
        !!source && decodeURIComponent(source[1]) === '/inbox/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        Object.keys(payload).length === 2 && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        !Array.isArray(o) && (keys.length === 4 || keys.length === 5 && keys.includes('bookmarks')) &&
        keys.every((key: string): boolean => ['url','data','redux_normalize_feed','field_sets','bookmarks'].includes(key)) &&
        o.url === '/v3/news_hub/feed/' && !Array.isArray(o.data) && Object.keys(o.data).length === 1 && o.data.field_set_key === 'unauthed' && o.redux_normalize_feed === true &&
        Array.isArray(o.field_sets) && o.field_sets.length === fields.length && fields.every((field: string,index: number): boolean => o.field_sets[index] === field) &&
        (o.bookmarks === undefined || Array.isArray(o.bookmarks) && o.bookmarks.length === 1 && typeof o.bookmarks[0] === 'string' && o.bookmarks[0].length > 0 && o.bookmarks[0].length <= 4096);
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent }; });
  }
  async requestBusinessProfileSearchDelete(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    query: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const raw: RegExpMatchArray | null = job.body.match(/(?:^|&)data=([^&]+)/);
      const source: RegExpMatchArray | null = job.body.match(/(?:^|&)source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(raw ? raw[1] : '')) as NativeSearchEnvelope;
      const o: NativeSearchApiOptions = payload.options as Object as NativeSearchApiOptions;
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_profile_history_delete_') && job.epoch === captured.generation && job.method === 'POST' &&
        job.page === captured.origin + '/search/me/' && job.url === captured.origin + '/resource/ApiResource/delete/' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/search/me.js' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' &&
        !!source && decodeURIComponent(source[1]) === '/search/me/' && Object.keys(payload).length === 2 &&
        !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 && !Array.isArray(o) &&
        Object.keys(o).length === 2 && o.url === '/v3/search/recent/' && !!o.data && !Array.isArray(o.data) &&
        Object.keys(o.data).length === 2 && query.trim().length > 0 && query.length <= 300 && o.data['query'] === query && o.data['vertical'] === 'PERSONAL';
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
  }
  async requestBusinessProfileSearchRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const fields: string = job.url.slice(job.url.indexOf('?') + 1);
      const raw: RegExpMatchArray | null = fields.match(/(?:^|&)data=([^&]+)/);
      const source: RegExpMatchArray | null = fields.match(/(?:^|&)source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(raw ? raw[1] : '')) as NativeSearchEnvelope;
      const o: Record<string, Object | null> = payload.options, keys: string[] = Object.keys(o);
      const path: string = job.page.slice(captured.origin.length);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_profile_search_') && job.epoch === captured.generation && job.method === 'GET' && job.body === '' &&
        job.page === captured.origin + path && !!source && decodeURIComponent(source[1]) === path &&
        Object.keys(payload).length === 2 && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 && !Array.isArray(o);
      if (job.url.startsWith(captured.origin + '/resource/AdvancedTypeaheadResource/get/?')) {
        const allowed: string[] = ['field_set_key', 'limit', 'num_recent_queries', 'personal_search_only', 'pin_scope', 'recent_queries_tags', 'term', 'autocomplete_request_surface'];
        permitted = basic && path === '/search/me/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/search/me.js' &&
          keys.length === 8 && keys.every((key: string): boolean => allowed.includes(key)) && o['field_set_key'] === 'richResults' &&
          o['limit'] === 3 && o['num_recent_queries'] === 20 && o['personal_search_only'] === true && o['pin_scope'] === 'my_content' &&
          o['recent_queries_tags'] === 'recent_queries,recent_personal_searches' && o['autocomplete_request_surface'] === 1 &&
          typeof o['term'] === 'string' && (o['term'] as string).length <= 300;
      } else if (job.url.startsWith(captured.origin + '/resource/BaseSearchResource/get/?')) {
        const match: RegExpMatchArray | null = path.match(/^\/search\/my_content\/\?rs=ac&q=([^&#]+)$/);
        const query: string = match ? decodeURIComponent(match[1]).trim() : '';
        const bookmarks: string[] | undefined = o['bookmarks'] as string[] | undefined;
        permitted = basic && !!match && query.length > 0 && query.length <= 300 && o['query'] === query && o['scope'] === 'my_pins' &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/search/my_content.js' && keys.length === (bookmarks ? 3 : 2) &&
          keys.every((key: string): boolean => ['query', 'scope', 'bookmarks'].includes(key)) &&
          (bookmarks === undefined || Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && bookmarks[0].length > 0 && bookmarks[0].length <= 4096 && bookmarks[0] !== '-end-');
      }
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
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
    return this.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent }; });
  }
  async requestBusinessSearchDiscoveryRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
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
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,
        epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
  }
  async requestBusinessHomeRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    username: string, board: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();
    let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const data: HomeReadData = encoded ? JSON.parse(decodeURIComponent(encoded[1])) as HomeReadData : {} as HomeReadData;
      const options: HomeReadOptions = data.options;
      const path: string = source ? decodeURIComponent(source[1]) : '';
      const boardSource: string = board ? '/?tabId=' + board : '/';
      const cursorValid: boolean = options?.bookmarks === undefined || Array.isArray(options.bookmarks) && options.bookmarks.length === 1 &&
        typeof options.bookmarks[0] === 'string' && options.bookmarks[0].length > 0 && options.bookmarks[0].length <= 4096;
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && /^[A-Za-z0-9_]+$/.test(username) &&
        (!board || /^\d+$/.test(board)) && job.id.startsWith('native_home_') && job.page === captured.origin + '/' && job.epoch === captured.generation &&
        job.method === 'GET' && job.body === '' && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        ((job.url.startsWith(captured.origin + '/resource/UserHomefeedResource/get/?') && !board && path === '/' && cursorValid &&
          options?.field_set_key === 'hf_grid' && options.in_nux === false && options.in_news_hub === false && options.static_feed === false) ||
         (job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?') && !!board && path === boardSource && cursorValid &&
          options?.type === 'board' && options.id === board && options.__track__referrer === 19) ||
         (job.url.startsWith(captured.origin + '/resource/BoardsFeedResource/get/?') && path === '/' + username + '/' && options?.username === username &&
          options.field_set_key === 'profile_grid_item' && options.filter_stories === false && options.sort === 'last_pinned_to' && options.bookmarks === undefined) ||
         (job.url.startsWith(captured.origin + '/resource/BoardResource/get/?') && !!board && path === boardSource && options?.board_id === board &&
          options.field_set_key === 'profile_grid_item' && options.is_mobile_fork === true && options.bookmarks === undefined));
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.origin === captured.origin && actual.generation === captured.generation, epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
  }
  async requestBusinessPinRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pinUrl: string, ownerCurrent: () => boolean,
    legacyContext?: () => PinmonyNetworkContext, aggregatedPinId: string = '', commentId: string = ''): Promise<PinmonyNetworkReply> {
    if (!PIN_BUSINESS_PIN_READ_ENABLED) {
      if (!legacyContext) return this.request(job, (): PinmonyNetworkContext => {
        return { authenticated: false, epoch: job.epoch, page: job.page, userAgent: '' };
      });
      const legacy: PinmonyNetworkContext = legacyContext();
      const legacyJob: PinmonyNetworkJob = { id: job.id, epoch: legacy.epoch, page: legacy.page,
        url: job.url, method: job.method, body: job.body, headers: job.headers, priority: job.priority };
      return this.requestPinRead(legacyJob, legacyContext, pinUrl, ownerCurrent);
    }
    const captured: PinmonyBusinessSessionContext = session();
    PinmonyRuntimeLog.info('SessionTrace: native-pin-read ownership=account-generation');
    let permitted: boolean = false;
    try {
      const match: RegExpMatchArray | null = pinUrl.match(/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/(\d+)\/$/);
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const data: PinReadData = encoded ? JSON.parse(decodeURIComponent(encoded[1])) as PinReadData : {} as PinReadData;
      permitted = captured.authenticated && !!captured.accountId && !!match &&
        pinUrl.startsWith(captured.origin + '/pin/') && job.page === pinUrl && job.epoch === captured.generation &&
        job.method === 'GET' && job.body === '' &&
        ((job.id.startsWith('native_autoplay_') && job.url.startsWith(captured.origin + '/resource/UserSettingsResource/get/?source_url=%2Fsettings%2Faccount-settings%2F&data=') &&
          !!data.options && Object.keys(data.options).length === 0 && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && job.headers['X-Pinterest-Source-Url'] === '/settings/account-settings/') ||
         (job.url.startsWith(captured.origin + '/resource/PinResource/get/?') &&
          data.options?.id === match[1] && data.options?.field_set_key === 'auth_web_main_pin') ||
         (job.url.startsWith(captured.origin + '/resource/RelatedModulesResource/get/?') &&
          (job.id.startsWith('opening_related_') || job.id.startsWith('native_related_')) && data.options?.pin_id === match[1] &&
          (data.options?.bookmarks === undefined || Array.isArray(data.options.bookmarks) && data.options.bookmarks.length === 1 &&
            typeof data.options.bookmarks[0] === 'string' && data.options.bookmarks[0].length > 0 && data.options.bookmarks[0].length <= 4096)) ||
         ((job.url.startsWith(captured.origin + '/resource/UnifiedCommentsPreviewResource/get/?') && job.id.startsWith('native_preview_') ||
           job.url.startsWith(captured.origin + '/resource/UnifiedCommentsResource/get/?') && job.id.startsWith('native_comments_') &&
           data.options?.page_size === 25 && data.options?.redux_normalize_feed === true && data.options?.is_reversed === false &&
           Array.isArray(data.options?.comment_featured_ids) && data.options.comment_featured_ids.length === 0 &&
           (data.options.bookmarks === undefined || Array.isArray(data.options.bookmarks) && data.options.bookmarks.length === 1 &&
            typeof data.options.bookmarks[0] === 'string' && data.options.bookmarks[0].length > 0 && data.options.bookmarks[0].length <= 4096)) &&
          /^\d+$/.test(aggregatedPinId) && data.options?.aggregated_pin_id === aggregatedPinId &&
          /^[A-Za-z0-9._-]{1,80}$/.test(captured.appVersion || '') && job.headers['X-App-Version'] === captured.appVersion &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js') ||
         ((job.url.startsWith(captured.origin + '/resource/AggregatedCommentReplyFeedResource/get/?') ||
           job.url.startsWith(captured.origin + '/resource/DidItCommentsResource/get/?')) && job.id.startsWith('native_replies_') &&
          /^\d+$/.test(commentId) && data.options?.objectId === commentId && data.options?.isUnifiedComment === true &&
          data.options?.redux_normalize_feed === true && data.options?.bookmarks === undefined &&
          /^[A-Za-z0-9._-]{1,80}$/.test(captured.appVersion || '') && job.headers['X-App-Version'] === captured.appVersion &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js') ||
         (job.url.startsWith(captured.origin + '/resource/ApiResource/get/?') && job.id.startsWith('native_translation_') &&
          /^\d+$/.test(commentId) && data.options?.url === '/v3/aggregated_comments/' + commentId + '/translate/' &&
          Object.keys(data.options).length === 1 && /^[A-Za-z0-9._-]{1,80}$/.test(captured.appVersion || '') &&
          job.headers['X-App-Version'] === captured.appVersion && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js'));
    } catch (_) {}
    return this.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      const current: boolean = permitted && ownerCurrent() && actual.authenticated &&
        actual.generation === captured.generation && actual.accountId === captured.accountId && actual.origin === captured.origin;
      return { authenticated: current, epoch: captured.generation, page: pinUrl, userAgent: actual.userAgent };
    });
  }

  cancelProfileAvatar(id: string): void {
    [id, id + '_status'].forEach((job: string): void => { if (this.pending.has(job)) this.cancel(job); });
  }
  // Captured web module 413225: one img part, then read-only processing status.
  async uploadProfileAvatar(bytes: ArrayBuffer, mime: string, page: string, ownPage: string,
      session: () => PinmonyBusinessSessionContext, owner: () => boolean, id: string,
      dispatched: () => void): Promise<string> {
    const state: PinmonyBusinessSessionContext = session();
    const captured: PinmonyBusinessSessionContext = { authenticated: state.authenticated, accountId: state.accountId,
      generation: state.generation, origin: state.origin, userAgent: state.userAgent };
    const generation: number = this.generation;
    const head: Uint8Array = new Uint8Array(bytes);
    const validImage: boolean = mime === 'image/jpeg' && head[0] === 255 && head[1] === 216 && head[2] === 255 ||
      mime === 'image/png' && head[0] === 137 && head[1] === 80 && head[2] === 78 && head[3] === 71 ||
      mime === 'image/webp' && head[0] === 82 && head[1] === 73 && head[8] === 87 && head[9] === 69;
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = session();
      return generation === this.generation && owner() && actual.authenticated &&
        actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin;
    };
    if (!PIN_BUSINESS_PIN_READ_ENABLED || !this.foreground || !current() || !captured.accountId ||
        !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) || page !== ownPage ||
        !/^[A-Za-z0-9_]+\/$/.test(page.slice(captured.origin.length + 1)) || !page.startsWith(captured.origin + '/') ||
        !/^native_profile_avatar_\d+$/.test(id) || !validImage || bytes.byteLength < 12 || bytes.byteLength > 4 * 1024 * 1024 ||
        this.pending.has(id) || this.pending.size >= 12 || NetworkManager.requestRemainingMs() > 0) throw new Error('avatar-unavailable');
    const url: string = captured.origin + '/upload-profile-image/';
    this.pending.add(id); this.cancelled.delete(id);
    const ownsRequest = (): boolean => current() && this.foreground && this.pending.has(id) && !this.cancelled.has(id);
    try {
      const cookie: string = await this.credentials.read(url);
      if (!ownsRequest()) throw new Error('stale');
      const csrf: RegExpMatchArray | null = cookie.match(/(?:^|;\s*)csrftoken=([^;]+)/);
      if (!csrf) throw new Error('missing-session');
      const fields: rcp.MultipartFormFields = {};
      fields['img'] = { contentOrPath: { content: bytes }, contentType: mime,
        remoteFileName: 'avatar.' + (mime === 'image/jpeg' ? 'jpg' : mime === 'image/png' ? 'png' : 'webp') };
      const headers: Record<string, string> = { 'Cookie': cookie, 'Referer': page, 'Origin': captured.origin,
        'User-Agent': captured.userAgent, 'X-CSRFToken': decodeURIComponent(csrf[1]), 'X-Requested-With': 'XMLHttpRequest' };
      const request: rcp.Request = new rcp.Request(url, 'POST', headers, new rcp.MultipartForm(fields), undefined, undefined,
        { transfer: { autoRedirect: false, timeout: { connectMs: 10000, transferMs: 20000 } } });
      this.jobs.set(id, request);
      const response: rcp.Response = await NetworkManager.enqueue(Priority.NORMAL, (): Promise<rcp.Response> => {
        if (!ownsRequest()) return Promise.reject(new Error('stale'));
        this.sentJobs.add(id); dispatched();
        PinmonyRuntimeLog.info('ProfileAvatar: upload dispatched');
        // A multipart write is dispatched once. Never use requestWithRetry here.
        return NetworkManager.getSession().fetch(request);
      });
      if (!ownsRequest()) throw new Error('stale');
      const setCookie: string | string[] | undefined = response.headers['set-cookie'];
      if (setCookie) await this.credentials.update(url, typeof setCookie === 'string' ? [setCookie] : setCookie, ownsRequest);
      if (!ownsRequest()) throw new Error('stale');
      const text: string = response.toString() || '';
      if (response.statusCode !== 200 || text.length > 65536) throw new Error('avatar-unconfirmed');
      const body: ProfileAvatarUploadResponse = JSON.parse(text) as ProfileAvatarUploadResponse;
      if (body.success === false) throw new Error('avatar-rejected');
      if (body.success !== true || typeof body.image_upload_tracking_id !== 'string' ||
          !/^[A-Za-z0-9_-]{1,200}$/.test(body.image_upload_tracking_id)) throw new Error('avatar-unconfirmed');
      return body.image_upload_tracking_id;
    } finally {
      this.jobs.delete(id); this.pending.delete(id); this.sentJobs.delete(id); this.cancelled.delete(id);
    }
  }
  async searchUploadedPhoto(bytes: ArrayBuffer, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<string> {
    const state: PinmonyBusinessSessionContext = session();
    const account: string = state.accountId, epoch: number = state.generation, origin: string = state.origin;
    const generation: number = this.generation;
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = session();
      return generation === this.generation && this.foreground && owner() && actual.authenticated &&
        actual.accountId === account && actual.generation === epoch && actual.origin === origin;
    };
    const head: Uint8Array = new Uint8Array(bytes);
    if (!current() || !account || !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin) ||
      page !== origin + '/search/' || !/^native_photo_search_\d+$/.test(id) ||
      bytes.byteLength < 12 || bytes.byteLength > 4 * 1024 * 1024 || head[0] !== 255 || head[1] !== 216 ||
      this.pending.has(id) || this.pending.size >= 12 || NetworkManager.requestRemainingMs() > 0) throw new Error('photo-unavailable');
    const url: string = origin + '/upload-lens-image/';
    this.pending.add(id); this.cancelled.delete(id);
    const live = (): boolean => current() && this.pending.has(id) && !this.cancelled.has(id);
    try {
      const cookie: string = await this.credentials.read(url);
      if (!live()) throw new Error('stale');
      const csrf: RegExpMatchArray | null = cookie.match(/(?:^|;\s*)csrftoken=([^;]+)/);
      if (!csrf) throw new Error('missing-session');
      const fields: rcp.MultipartFormFields = {};
      fields['image'] = { contentOrPath: { content: bytes }, contentType: 'image/jpeg', remoteFileName: 'lens-file-image' };
      fields['x'] = '0'; fields['y'] = '0'; fields['w'] = '1'; fields['h'] = '1';
      fields['crop_source'] = '5'; fields['source_type'] = '1';
      const request: rcp.Request = new rcp.Request(url, 'POST', {
        'Cookie': cookie, 'Referer': page, 'Origin': origin, 'User-Agent': state.userAgent,
        'X-CSRFToken': decodeURIComponent(csrf[1]), 'X-Requested-With': 'XMLHttpRequest'
      }, new rcp.MultipartForm(fields), undefined, undefined,
        { transfer: { autoRedirect: false, timeout: { connectMs: 10000, transferMs: 30000 } } });
      this.jobs.set(id, request);
      const response: rcp.Response = await NetworkManager.enqueue(Priority.NORMAL, (): Promise<rcp.Response> => {
        if (!live()) return Promise.reject(new Error('stale'));
        this.sentJobs.add(id);
        return NetworkManager.getSession().fetch(request);
      });
      if (!live()) throw new Error('stale');
      const cookies: string | string[] | undefined = response.headers['set-cookie'];
      if (cookies) await this.credentials.update(url, typeof cookies === 'string' ? [cookies] : cookies, live);
      if (!live()) throw new Error('stale');
      const text: string = response.toString() || '';
      if (response.statusCode !== 200 || !text || text.length > 8 * 1024 * 1024) throw new Error('photo-unconfirmed');
      return text;
    } finally {
      this.jobs.delete(id); this.pending.delete(id); this.sentJobs.delete(id); this.cancelled.delete(id);
    }
  }

  async readProfileAvatarStatus(tracking: string, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string): Promise<number> {
    const state: PinmonyBusinessSessionContext = session();
    const captured: PinmonyBusinessSessionContext = { authenticated: state.authenticated, accountId: state.accountId,
      generation: state.generation, origin: state.origin, userAgent: state.userAgent };
    if (!this.foreground || !owner() || !/^[A-Za-z0-9_-]{1,200}$/.test(tracking) ||
        !/^native_profile_avatar_\d+$/.test(id) || !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) ||
        !page.startsWith(captured.origin + '/') || !/^[A-Za-z0-9_]+\/$/.test(page.slice(captured.origin.length + 1))) throw new Error('avatar-status');
    const options: ProfileAvatarStatusOptions = { url: '/v3/images/upload/status/', data: { tracking_id: tracking } };
    const envelope: ProfileAvatarStatusEnvelope = { options: options, context: {} };
    const form: string = 'source_url=' + encodeURIComponent(page.slice(captured.origin.length)) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const job: PinmonyNetworkJob = { id: id + '_status', epoch: captured.generation, page: page,
      url: captured.origin + '/resource/ApiResource/get/?' + form, method: 'GET', body: '',
      headers: { 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } };
    const context = (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
      authenticated: owner() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: actual.generation, page: page, userAgent: actual.userAgent }; };
    const reply: PinmonyNetworkReply = await this.request(job, context);
    if (!context().authenticated || reply.error || reply.status !== 200) throw new Error('avatar-status');
    const body: ProfileAvatarStatusResponse = JSON.parse(reply.body) as ProfileAvatarStatusResponse;
    const r: ProfileAvatarStatusResource = body.resource_response;
    const status: number | undefined = r?.data?.[tracking];
    if (!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== 'v3_get_image_upload_status' ||
        !Number.isInteger(status) || status! < 0 || status! > 5) throw new Error('avatar-status');
    return status!;
  }
  async uploadCommentImage(bytes: ArrayBuffer, pin: string, context: () => PinmonyNetworkContext, ownerId: string = ''): Promise<string> {
    if (!this.foreground) throw new Error('background');
    const captured: PinmonyNetworkContext = context();
    const generation: number = this.generation;
    if (!captured.authenticated || captured.page.split(/[?#]/)[0] !== pin || !/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pin) ||
        bytes.byteLength < 1 || bytes.byteLength > 20 * 1024 * 1024) throw new Error('image-unavailable');
    const current = (): boolean => generation === this.generation && context().authenticated &&
      context().epoch === captured.epoch && context().page === captured.page;
    const jobId: string = /^native_comment_upload_\d+$/.test(ownerId) ? ownerId : 'comment_upload_' + Date.now().toString();
    const origin: string = pin.slice(0, pin.indexOf('/', 8));
    const resource = async (operation: string, options: string): Promise<string> => {
      if (!current()) throw new Error('stale');
      const body: string = 'source_url=' + encodeURIComponent(pin.slice(origin.length)) +
        '&data=' + encodeURIComponent('{"options":' + options + ',"context":{}}');
      const job: PinmonyNetworkJob = { id: jobId + '_' + operation, epoch: captured.epoch, page: captured.page,
        url: origin + '/resource/ApiResource/' + operation + '/' + (operation === 'get' ? '?' + body : ''),
        method: operation === 'get' ? 'GET' : 'POST', body: operation === 'get' ? '' : body,
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } };
      const response: PinmonyNetworkReply = await this.request(job, context);
      if (!current() || response.error || response.status !== 200) throw new Error('upload-resource');
      return response.body;
    };
    const registration: CommentUploadRegistration = JSON.parse(await resource('create',
      '{"url":"/v3/media/uploads/register/","data":{"type":"triedit-image"}}')) as CommentUploadRegistration;
    const business = registration.resource_response;
    const upload = business.data;
    if (business.status !== 'success' || business.code !== 0 || business.endpoint_name !== 'register_media_upload' ||
        !upload || !/^\d+$/.test(upload.upload_id) || upload.upload_url !== 'https://pinterest-media-upload.s3.amazonaws.com/' ||
        !upload.upload_parameters) throw new Error('upload-registration');
    const fields: rcp.MultipartFormFields = {};
    const required: string[] = ['x-amz-date', 'x-amz-signature', 'x-amz-security-token', 'x-amz-algorithm', 'key', 'policy', 'x-amz-credential', 'Content-Type'];
    if (Object.keys(upload.upload_parameters).some((key: string): boolean => !required.includes(key))) throw new Error('upload-fields');
    required.forEach((key: string) => {
      const value: string = upload.upload_parameters[key];
      if (typeof value !== 'string' || !value || value.length > 32768) throw new Error('upload-fields');
      fields[key] = value;
    });
    fields['file'] = { contentType: 'image/jpeg', remoteFileName: 'comment.jpg', contentOrPath: { content: bytes } };
    if (!this.foreground) throw new Error('background');
    if (!current()) throw new Error('stale');
    const session: rcp.Session = NetworkManager.getSession();
    const request: rcp.Request = new rcp.Request(upload.upload_url, 'POST', {}, new rcp.MultipartForm(fields),
      undefined, undefined, { transfer: { autoRedirect: false, timeout: { connectMs: 10000, transferMs: 60000 } },
        tracing: { collectTimeInfo: true } });
    const uploadGeneration: number = this.generation;
    const uploadCurrent = (): boolean => uploadGeneration === this.generation && this.pending.has(jobId) &&
      !this.cancelled.has(jobId) && current();
    this.pending.add(jobId);
    this.cancelled.delete(jobId);
    this.jobs.set(jobId, request);
    try {
      // This captured upload host receives no ArkWeb Cookie, CSRF or site headers.
      const response: rcp.Response = await NetworkManager.enqueue(Priority.NORMAL, (): Promise<rcp.Response> => {
        if (!uploadCurrent()) return Promise.reject(new Error('stale'));
        this.sentJobs.add(jobId);
        return session.fetch(request);
      });
      if (!uploadCurrent() || response.statusCode < 200 || response.statusCode >= 300) throw new Error('image-upload');
    } finally {
      if (this.jobs.get(jobId) === request) this.jobs.delete(jobId);
      this.pending.delete(jobId);
      this.sentJobs.delete(jobId);
      this.cancelled.delete(jobId);
    }
    for (let attempt: number = 0; attempt < 15; attempt++) {
      if (!current()) throw new Error('stale');
      const readOptions: CommentUploadReadOptions = {
        url: '/v3/media/uploads/', data: { upload_ids: [upload.upload_id] }
      };
      const status: CommentUploadStatus = JSON.parse(await resource('get', JSON.stringify(readOptions))) as CommentUploadStatus;
      const result = status.resource_response;
      const item: CommentUploadItem | undefined = result.data?.[upload.upload_id];
      if (result.status !== 'success' || result.code !== 0 || result.endpoint_name !== 'get_media_uploads' ||
          !item || String(item.upload_id) !== upload.upload_id || item.type !== 'triedit-image') throw new Error('upload-status');
      if (item.status === 'succeeded' && /^[a-f0-9]{32}$/.test(item.signature)) return item.signature;
      if (item.status !== 'registered' && item.status !== 'processing') throw new Error('upload-failed');
      await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 1000); });
    }
    throw new Error('upload-timeout');
  }
  async request(job: PinmonyNetworkJob, context: () => PinmonyNetworkContext, attempt: number = 0): Promise<PinmonyNetworkReply> {
    const startedAt: number = Date.now();
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
        if (allowed.includes(key.toLowerCase()) && typeof value === 'string' && value.length <= 4096 && !/[\r\n]/.test(value))
          headers[key] = value;
      });
      headers['Cookie'] = cookie;
      headers['Referer'] = job.page;
      headers['Origin'] = job.url.slice(0, job.url.indexOf('/', 8));
      headers['User-Agent'] = context().userAgent;
      const csrf: RegExpMatchArray | null = cookie.match(/(?:^|;\s*)csrftoken=([^;]+)/);
      if (job.method === 'POST' && !csrf) throw new Error('missing-session');
      if (csrf) headers['X-CSRFToken'] = decodeURIComponent(csrf[1]);
      const isHomeFeedRead: boolean = job.method === 'GET' &&
        /\/resource\/UserHomefeedResource\/get\//.test(job.url);
      request = new rcp.Request(job.url, job.method === 'POST' ? 'POST' : 'GET',
        headers, job.method === 'POST' ? job.body : undefined, undefined, undefined,
        { transfer: { autoRedirect: false, timeout: { connectMs: detailRead ? 4000 : 10000, transferMs: detailRead || isHomeFeedRead ? 5000 : 20000 } },
          tracing: { collectTimeInfo: true } });
      this.jobs.set(job.id, request);
      const session: rcp.Session = NetworkManager.getSession();
      stage = 'fetch';
      trace('dispatched');
      PinmonyRuntimeLog.info('NativeNetwork: request dispatched');
      const response: rcp.Response = await NetworkManager.enqueue(priorityForJob(job), (): Promise<rcp.Response> => {
        if (!current()) return Promise.reject(new Error('stale'));
        this.sentJobs.add(job.id);
        return NetworkManager.requestWithRetry(session, request!, detailRead ? 1 : 2, 300,
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
      PinmonyRuntimeLog.warn('NativeNetwork: request failed at ' + stage + ', code ' + code.toString() + ', current ' + current().toString());
      PinmonyRuntimeLog.warn('NetworkTrace: failed ' + requestLabel + ' elapsedMs=' + (Date.now() - startedAt).toString());
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
