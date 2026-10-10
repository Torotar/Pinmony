import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PinmonySessionCredentials } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyRequestPolicy, PinmonyRequestPermit } from './PinmonyRequestPolicy';

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
  'BoardFeedResource', 'UserPinsResource', 'UserResource', 'BoardsResource', 'BoardsFeedResource',
  'UserSettingsResource', 'CountriesResource', 'UserRecentActivityResource', 'UserFollowingResource', 'UserActivityPinsResource', 'BoardlessPinsResource', 'PinResource', 'RelatedModulesResource', 'VisualSearchFlashlightUnifiedResource',
  'SearchTabResource', 'AdvancedTypeaheadResource', 'BaseSearchResource', 'UserExperienceResource', 'ApiResource', 'ConversationMessagesResource',
  'ConversationsResource', 'ShareSuggestionsResource', 'ShareSuggestionsTypeaheadResource',
  'FindPinImagesResource', 'UserSessionResource', 'BoardPickerBoardsResource', 'UnifiedCommentsResource', 'UnifiedCommentsPreviewResource',
  'AggregatedCommentReplyFeedResource', 'AggregatedCommentReplyResource', 'AggregatedCommentResource', 'DidItCommentsResource', 'RepinResource'];
interface PinmonyGraphQuery {
  queryHash: string;
  variables: Object;
}
interface PinmonyResponseDiagnostic {
  resource_response?: PinmonyResourceDiagnostic;
}
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
  if (!job || !context.authenticated || job.epoch !== context.epoch || job.page !== context.page ||
      !/^https:\/\/www\.pinterest\.com\//.test(job.page) || !/^[a-zA-Z0-9_-]{1,96}$/.test(job.id) ||
      typeof job.url !== 'string' || job.url.length > 65536 || typeof job.body !== 'string' ||
      job.body.length > (job.url === 'https://www.pinterest.com/resource/PinResource/create/' ? 34 * 1024 * 1024 : 262144) || (job.method !== 'GET' && job.method !== 'POST') ||
      !job.headers || typeof job.headers !== 'object' || Array.isArray(job.headers)) return false;
  const match: RegExpMatchArray | null = job.url.match(/^https:\/\/www\.pinterest\.com\/resource\/([A-Za-z]+Resource)\/(get|create|update|delete)\/(?:\?[^#]*)?$/);
  if (match) {
    if (!RESOURCES.includes(match[1])) return false;
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
        const options: Record<string, string | boolean> = payload.options;
        const keys: string[] = Object.keys(options);
        const fields: string[] = keys.filter((key: string) => !['user_id', 'surface_tag', 'user_confirm_skip_passcode'].includes(key));
        if (options.surface_tag !== 'settings' || fields.length !== 1 || keys.length > 4) return false;
        const field: string = fields[0]; const value: string | boolean = options[field];
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
interface SettingsUpdate { options: Record<string, string | boolean>; }
interface LogoutWrite { options: LogoutWriteOptions; context: Object; }
interface LogoutWriteOptions { disable_auth_failure_redirect: boolean; }
interface PinReadData { options: PinReadOptions; }
interface PinReadOptions { id?: string; field_set_key?: string; pin_id?: string; bookmarks?: string[]; }

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
      this.session = rcp.createSession({ requestConfiguration: {
        transfer: { autoRedirect: false, timeout: { connectMs: 10000, transferMs: 20000 } },
        tracing: { collectTimeInfo: true }
      } });
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

export class PinmonyNativeNetwork {
  onTransientRetry?: (resource: string, speculative: boolean) => void;
  onRateLimited?: (remainingMs: number) => void;
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
      const match: RegExpMatchArray | null = pinUrl.match(/^https:\/\/www\.pinterest\.com\/pin\/(\d+)\/$/);
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const data: PinReadData = encoded ? JSON.parse(decodeURIComponent(encoded[1])) as PinReadData : {} as PinReadData;
      permitted = !!match && acceptsNetworkJob(job, captured) && job.method === 'GET' && job.body === '' &&
        ((/^https:\/\/www\.pinterest\.com\/resource\/PinResource\/get\/\?/.test(job.url) &&
          data.options?.id === match[1] && data.options?.field_set_key === 'auth_web_main_pin') ||
         (/^https:\/\/www\.pinterest\.com\/resource\/RelatedModulesResource\/get\/\?/.test(job.url) &&
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
  async uploadCommentImage(bytes: ArrayBuffer, pin: string, context: () => PinmonyNetworkContext): Promise<string> {
    if (!this.foreground) throw new Error('background');
    const captured: PinmonyNetworkContext = context();
    const generation: number = this.generation;
    if (!captured.authenticated || captured.page.split(/[?#]/)[0] !== pin || !/^https:\/\/www\.pinterest\.com\/pin\/\d+\/$/.test(pin) ||
        bytes.byteLength < 1 || bytes.byteLength > 20 * 1024 * 1024) throw new Error('image-unavailable');
    const current = (): boolean => generation === this.generation && context().authenticated &&
      context().epoch === captured.epoch && context().page === captured.page;
    const jobId: string = 'comment_upload_' + Date.now().toString();
    const resource = async (operation: string, options: string): Promise<string> => {
      if (!current()) throw new Error('stale');
      const body: string = 'source_url=' + encodeURIComponent(pin.replace('https://www.pinterest.com', '')) +
        '&data=' + encodeURIComponent('{"options":' + options + ',"context":{}}');
      const job: PinmonyNetworkJob = { id: jobId + '_' + operation, epoch: captured.epoch, page: captured.page,
        url: 'https://www.pinterest.com/resource/ApiResource/' + operation + '/' + (operation === 'get' ? '?' + body : ''),
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
    const detailRead: boolean = job.method === 'GET' && /\/resource\/(PinResource|RelatedModulesResource|UnifiedCommentsPreviewResource)\/get\//.test(job.url);
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
      PinmonyRuntimeLog.warn('NativeNetwork: request rejected before dispatch');
      this.audit('reject', 'label=' + requestLabel);
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
      headers['Origin'] = 'https://www.pinterest.com';
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
      if (response.statusCode >= 300 && response.statusCode < 400 && typeof location === 'string' &&
          /^(?:https:\/\/www\.pinterest\.com)?\/(?:login|signup)(?:\/|[?#]|$)/.test(location))
        result.url = location.startsWith('/') ? 'https://www.pinterest.com' + location : location;
    } catch (error) {
      // Only SDK numeric error codes are diagnostic; never log request/response or exception messages.
      const code: number = (error as BusinessError).code || 0;
      trace((current() ? 'failed.code' : 'cancelled.code') + code.toString());
      PinmonyRuntimeLog.warn('NativeNetwork: request failed at ' + stage + ', code ' + code.toString() + ', current ' + current().toString());
      PinmonyRuntimeLog.warn('NetworkTrace: failed ' + requestLabel + ' elapsedMs=' + (Date.now() - startedAt).toString());
      const deadlineExpired: boolean = detailRead && Date.now() - startedAt >= 12000 &&
        this.generation === generation && !this.cancelled.has(job.id) && acceptsNetworkJob(job, context());
      const limited: boolean = error instanceof Error && error.message === 'rate-limited';
      result.error = !current() ? 'cancelled' : limited ? 'rate-limited' : deadlineExpired ? 'timeout' : 'network-unavailable';
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
