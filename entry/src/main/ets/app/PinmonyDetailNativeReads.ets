import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore, PinmonyDetailSnapshot, PinmonyRelatedPin, readRelatedPresentation, RelatedPresentation, PinmonyComment, PinmonyCommentResult } from 'feature_pin';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PIN_BUSINESS_PIN_READ_ENABLED, PinmonyNativeNetwork, PinmonyNetworkContext, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export const PIN_NATIVE_DETAIL_READS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface CommentClient { user?: CommentUser; }
interface RetainedRelatedRead {
  at: number;
  pins: PinmonyRelatedPin[];
  bookmark: string;
  ended: boolean;
  reply: PinmonyNetworkReply;
  aggregate: string;
  previewText: string;
  previewEmpty: boolean;
  previewAvailable: boolean;
  previewReady: boolean;
}
interface BaseResponse { resource_response: BaseResource; client_context?: CommentClient; }
interface AutoplayResponse { resource_response?: AutoplayResource; client_context?: CommentClient; }
interface AutoplayResource { status: string; code: number; error?: Object; data?: AutoplaySettings; }
interface AutoplaySettings { id: string; autoplay_videos_on_wifi_enabled?: boolean; autoplay_videos_on_cellular_enabled?: boolean; }
interface BaseResource { status: string; data: BasePin; }
interface AggregatePinData { id?: string; comment_count?: number; }
interface BaseReaction { reaction_by_me?: number; reaction_counts?: Record<string, number>; }
interface BasePin { id: string; aggregated_pin_id?: string; aggregated_pin_data?: AggregatePinData; comment_count?: number;
  reaction_data?: BaseReaction; reaction_by_me?: number; reaction_counts?: Record<string, number>; }
interface PreviewResponse { resource_response: PreviewResource; }
interface PreviewResource { status: string; code?: number; error?: Object; data: PreviewItem[]; }
interface PreviewItem { unified_comment?: PreviewComment; aggregated_comment?: PreviewComment; user_did_it_data?: PreviewComment; }
interface PreviewComment { text?: string; details?: string; }
interface PreviewOptions { aggregated_pin_id: string; }
interface CommentUser { id?: string; username?: string; full_name?: string; image_medium_url?: string; }
interface CommentImage { originals?: CommentOriginal; }
interface CommentOriginal { url?: string; }
export interface NativeCommentData { id: string; type?: string; text?: string; details?: string; user?: CommentUser; created_at?: string;
  pin?: AggregatePinData; image_signatures?: string[]; done_at?: string; images?: CommentImage[]; like_count?: number; reaction_counts?: Record<string, number>;
  liked_by_me?: boolean; reaction_by_me?: number; comment_count?: number; }
interface CommentsResponse { resource_response: CommentsResource; client_context?: CommentClient; }
interface CommentsResource { endpoint_name?: string; status: string; code?: number; error?: Object; data: NativeCommentData[]; bookmark?: string; }
interface CommentsOptions { aggregated_pin_id: string; comment_featured_ids: string[]; page_size: number;
  redux_normalize_feed: boolean; is_reversed: boolean; bookmarks?: string[]; }
interface RepliesOptions { isUnifiedComment: boolean; objectId: string; redux_normalize_feed: boolean; }
interface TranslationOptions { url: string; }
interface TranslationResponse { resource_response: TranslationResource; }
interface TranslationResource { status: string; code?: number; error?: Object; endpoint_name: string; data: string | null; }
interface ReadEnvelope { options: Object; context: Record<string, string>; }
interface RelatedOptions { pin_id: string; page_size: number; context_pin_ids: string[]; homefeed_source_sig: boolean;
  search_query: string; source: string; top_level_source: string; top_level_source_depth: number; is_pdp: boolean;
  additional_fields: string[]; bookmarks?: string[]; }
export interface PinmonyDetailNativeReadsPorts {
  pinStore: () => PinmonyPinStore;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  legacyContext: () => PinmonyNetworkContext;
  foreground: () => boolean;
  rootOnly: () => boolean;
  backTarget: () => string;
  mark: (event: string) => void;
}

// Owns native read fields only. Action IDs and mutation permissions still belong
// to the existing operations controllers until those contracts migrate.
export class PinmonyDetailNativeReads {
  private readonly ports: PinmonyDetailNativeReadsPorts;
  private readonly store: PinmonyPinStore;
  private revision: number = 0;
  private sequence: number = 0;
  private pin: string = '';
  private opening: number = 0;
  private sessionGeneration: number = -1;
  private aggregate: string = '';
  private commentViewer: string = '';
  private readonly commentAuthors: Map<string,string> = new Map<string,string>();
  private bookmark: string = '';
  private commentsBookmark: string = '';
  private commentsBusy: boolean = false;
  private commentsRevision: number = 0;
  private related: PinmonyRelatedPin[] = [];
  private relatedLoading: boolean = false;
  private relatedEnded: boolean = false;
  private relatedError: string = '';
  private readonly retainedRelated: Map<string, RetainedRelatedRead> = new Map<string, RetainedRelatedRead>();
  private retainedOwner: string = '';
  private previewLoading: boolean = false;
  private previewText: string = '';
  private previewEmpty: boolean = false;
  private previewError: string = '';
  private previewAvailable: boolean = false;
  private readonly requests: Set<string> = new Set<string>();
  private autoplayWifi: boolean | undefined = undefined;
  private autoplayCellular: boolean | undefined = undefined;
  constructor(ports: PinmonyDetailNativeReadsPorts) { this.ports = ports; this.store = ports.pinStore(); }

  pause(): void {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if (!session.authenticated || this.retainedOwner !== session.accountId + ':' + session.generation.toString()) {
      this.retainedRelated.clear(); this.retainedOwner = '';
    }
    this.autoplayWifi = undefined; this.autoplayCellular = undefined;
    this.revision++;
    this.requests.forEach((id: string) => this.ports.network().cancel(id)); this.requests.clear();
    this.commentViewer = ''; this.commentAuthors.clear();
    this.pin = ''; this.commentsBusy = false; this.commentsBookmark = ''; this.store.detailNativeReadsReady = false;
  }
  owned(): boolean {
    if (!PIN_NATIVE_DETAIL_READS_ENABLED || !this.pin) return false;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return PIN_NATIVE_DETAIL_READS_ENABLED && !!this.pin && session.authenticated && session.generation === this.sessionGeneration &&
      this.ports.foreground() && !this.ports.rootOnly() && !this.ports.backTarget() &&
      this.opening === this.store.detailOpeningToken && (this.store.detailPin === this.pin || this.store.detailOpeningPin === this.pin);
  }
  resume(pin: string, opening: number): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const cached: RetainedRelatedRead | undefined = this.retainedRelated.get(pin);
    if (!session.authenticated || this.retainedOwner !== session.accountId + ':' + session.generation.toString() ||
        !cached || !cached.previewReady || Date.now() - cached.at >= 300000 || this.store.detail?.pinUrl !== pin) return false;
    this.pause(); this.pin = pin; this.opening = opening; this.sessionGeneration = session.generation;
    if (!this.owned()) return false;
    this.aggregate = cached.aggregate; this.bookmark = cached.bookmark; this.related = cached.pins.slice();
    this.relatedLoading = false; this.relatedEnded = cached.ended; this.relatedError = '';
    this.previewText = cached.previewText; this.previewEmpty = cached.previewEmpty;
    this.previewAvailable = cached.previewAvailable; this.previewLoading = false; this.previewError = '';
    this.apply(); this.readAutoplay(); this.ports.mark('return.native.reads.restored');
    return true;
  }
  apply(): void {
    if (!this.owned()) { this.store.detailNativeReadsReady = false; return; }
    const detail: PinmonyDetailSnapshot | undefined = this.store.detail;
    if (!detail || detail.pinUrl !== this.pin) return;
    this.store.detailNativeReadsReady = true;
    const next: PinmonyDetailSnapshot = JSON.parse(JSON.stringify(detail)) as PinmonyDetailSnapshot;
    next.autoplayWifi = this.autoplayWifi; next.autoplayCellular = this.autoplayCellular;
    next.commentPreview = this.previewText; next.commentLoading = this.previewLoading;
    next.commentEmpty = this.previewEmpty; next.commentError = this.previewError; next.commentsAvailable = this.previewAvailable;
    next.commentsRetained = false; next.related = this.related.slice(); next.relatedLoading = this.relatedLoading;
    next.relatedEnded = this.relatedEnded; next.relatedError = this.relatedError; next.relatedRetained = false;
    this.store.detail = next;
    this.store.detailCache.put(this.pin.split('/pin/')[1].split('/')[0], next, this.store.detailScrollOffset);
  }
  async start(pin: string, opening: number, body: string): Promise<PinmonyNetworkReply> {
    this.pause();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const owner: string = session.authenticated ? session.accountId + ':' + session.generation.toString() : '';
    if (!owner || owner !== this.retainedOwner) this.retainedRelated.clear();
    this.retainedOwner = owner;
    const response: BaseResponse = JSON.parse(body) as BaseResponse;
    const resource: BaseResource = response.resource_response;
    this.commentViewer = /^\d{1,30}$/.test(response.client_context?.user?.id || '') ? response.client_context!.user!.id! : '';
    if (!session.authenticated || resource?.status !== 'success' || String(resource.data?.id) !== pin.split('/pin/')[1]?.split('/')[0])
      throw new Error('invalid-native-base');
    this.pin = pin; this.opening = opening; this.sessionGeneration = session.generation;
    // Both shapes belong to the verified current PinResource response. The
    // website currently returns the nested shape; never substitute the Pin ID.
    const direct: string = String(resource.data.aggregated_pin_id || '');
    const nested: string = String(resource.data.aggregated_pin_data?.id || '');
    this.aggregate = /^\d+$/.test(direct) ? direct : /^\d+$/.test(nested) ? nested : '';
    if (this.owned() && this.store.detail?.pinUrl === pin) {
      const next: PinmonyDetailSnapshot = JSON.parse(JSON.stringify(this.store.detail)) as PinmonyDetailSnapshot;
      const raw: BasePin = resource.data, reaction: BaseReaction = raw.reaction_data || raw;
      const likes: number | undefined = reaction.reaction_counts?.['1'] ?? raw.reaction_counts?.['1'];
      const comments: number | undefined = raw.aggregated_pin_data?.comment_count ?? raw.comment_count;
      const count = (value: number | undefined): string => typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value.toString() : '';
      next.actions = next.actions.filter((item): boolean => !['like','comment','save','more','share'].includes(item.kind));
      next.actions.push({id:'native-like',kind:'like',label:PinmonyI18n.message("pm_like_aced5d7f"),countText:count(likes),enabled:reaction.reaction_by_me === 0,selected:reaction.reaction_by_me === 1});
      next.actions.push({id:'native-comment',kind:'comment',label:PinmonyI18n.message("pm_comments_6849b825"),countText:count(comments),enabled:!!this.aggregate,selected:false});
      next.actions.push({id:'native-save',kind:'save',label:PinmonyI18n.message("pm_save_60a53514"),countText:'',enabled:true,selected:false});
      next.actions.push({id:'native-more',kind:'more',label:PinmonyI18n.message("pm_more_options_c611656f"),countText:'',enabled:true,selected:false});
      next.actions.push({id:'native-share',kind:'share',label:PinmonyI18n.message("pm_share_7e564575"),countText:'',enabled:true,selected:false});
      next.actions = this.store.confirmedSaves ? this.store.confirmedSaves.actions(resource.data.id,next.actions) : next.actions;
      this.store.detail = next;
    }
    this.ports.mark(this.aggregate ? 'comments.native.identity.ready' : 'comments.native.identity.missing');
    const existing: PinmonyDetailSnapshot | undefined = this.store.detail;
    const cached: RetainedRelatedRead | undefined = this.retainedRelated.get(pin);
    const retained: RetainedRelatedRead | undefined = cached && Date.now() - cached.at < 300000 ? cached : undefined;
    this.bookmark = retained?.bookmark || ''; this.related = retained ? retained.pins.slice() : existing?.pinUrl === pin ? existing.related.slice() : [];
    this.relatedLoading = !retained; this.relatedEnded = retained?.ended || false; this.relatedError = '';
    this.previewText = ''; this.previewError = this.aggregate ? '' : PinmonyI18n.message("pm_missing_comment_id_retry_the_comment_preview_b1b3707a"); this.previewEmpty = false;
    this.previewAvailable = !!this.aggregate; this.previewLoading = !!this.aggregate; this.apply();
    const revision: number = this.revision;
    this.readAutoplay();
    await this.readPreview();
    if (revision !== this.revision || !this.owned()) throw new Error('stale-native-read');
    if (retained) { this.ports.mark('related.native.retained'); return retained.reply; }
    return this.readRelated(false);
  }
  retryPreview(): boolean {
    if (!this.owned() || !this.aggregate) return false;
    if (!this.previewLoading && !!this.previewError) this.readPreview();
    return true;
  }
  loadMore(): void { if (this.owned() && !this.relatedLoading && (!this.relatedEnded || !!this.relatedError)) this.readRelated(!!this.bookmark); }

  cancelComments(): void {
    const listLoading: boolean = this.commentsBusy;
    this.commentsRevision++; this.commentsBusy = false;
    this.store.commentResult?.items.forEach((item: PinmonyComment): void => {
      if (item.repliesLoading) { item.repliesLoading = false; item.repliesError = PinmonyI18n.message("pm_reply_loading_interrupted_please_retry_0ee5475c"); }
      this.cancelTranslation(item);
      item.replies?.forEach((reply: PinmonyComment): void => this.cancelTranslation(reply));
    });
    const result: PinmonyCommentResult = this.store.commentResult;
    if (result?.pin === this.pin) {
      if (listLoading && result.loading) { result.loading = false; result.error = PinmonyI18n.message("pm_comment_loading_interrupted_please_retry_96182a1c"); }
      this.publishComments(result);
    }
    this.requests.forEach((id: string): void => { if (id.startsWith('native_comments_') || id.startsWith('native_replies_') || id.startsWith('native_translation_')) this.ports.network().cancel(id); });
  }
  private cancelTranslation(item: PinmonyComment): void {
    if (item.translationLoading) { item.translationLoading = false; item.translationError = PinmonyI18n.message("pm_translation_interrupted_please_retry_010117c5"); }
  }
  // PinStore is observed, but the nested result/items are plain objects.
  // Replace its root property to notify the sheet, retaining item identity for
  // concurrent reply/translation ownership checks.
  private publishComments(result: PinmonyCommentResult): void {
    const next: PinmonyCommentResult = { pin: result.pin, loading: result.loading, error: result.error, items: result.items,
      ended: result.ended, actionError: result.actionError, busy: result.busy, uncertain: result.uncertain,
      mutationVersion: result.mutationVersion };
    this.store.commentResult = next;
  }
  commentAggregate(): string { return this.owned() ? this.aggregate : ''; }
  commentViewerIdentity(): string { return this.owned() ? this.commentViewer : ''; }
  commentAuthor(id: string): string {
    const present: boolean = this.store.commentResult.items.some((item: PinmonyComment): boolean => item.id === id || !!item.replies?.some((reply: PinmonyComment): boolean => reply.id === id));
    return this.owned() && present ? this.commentAuthors.get(id) || '' : '';
  }
  mapWrittenComment(item: NativeCommentData, viewer: string): PinmonyComment | undefined {
    if (!this.owned() || !/^\d{1,30}$/.test(viewer)) return undefined;
    this.commentViewer = viewer; return this.mapComment(item);
  }
  commentsSeed(): string { return JSON.stringify({ aggregate: this.aggregate, result: this.store.commentResult }); }
  async readComments(append: boolean, current: () => boolean): Promise<void> {
    if (!current() || this.commentsBusy) return;
    if (!this.owned()) {
      const result: PinmonyCommentResult = this.store.commentResult;
      result.loading = false; result.error = PinmonyI18n.message("pm_comment_session_not_ready_reopen_the_pin_ca5a4313"); this.publishComments(result); return;
    }
    const revision: number = this.revision;
    const token: number = this.store.commentToken;
    const commentsRevision: number = this.commentsRevision;
    const pin: string = this.pin;
    const live = (): boolean => commentsRevision === this.commentsRevision && revision === this.revision && token === this.store.commentToken && this.owned() && current();
    const previous: string = append ? this.commentsBookmark : '';
    if (append && this.store.commentResult.ended && !this.store.commentResult.error) return;
    this.commentsBusy = true;
    const prior: PinmonyCommentResult = this.store.commentResult;
    const retainedItems: PinmonyComment[] = prior.items.slice();
    const retainedAuthors: Map<string,string> = new Map<string,string>(this.commentAuthors);
    const result: PinmonyCommentResult = { pin: pin, loading: true, error: '', items: prior.items.slice(), busy: prior.busy,
      uncertain: prior.uncertain, actionError: prior.actionError, mutationVersion: prior.mutationVersion };
    this.publishComments(result);
    try {
      if (!this.aggregate) { this.ports.mark('comments.native.identity.missing'); throw new Error(PinmonyI18n.message("pm_missing_comment_id_return_to_the_pin_and_retry_the_preview_e1f7470d")); }
      if (!this.ports.session().appVersion) { this.ports.mark('comments.native.metadata.missing'); throw new Error(PinmonyI18n.message("pm_comment_request_not_ready_please_retry_2a902071")); }
      const options: CommentsOptions = { aggregated_pin_id: this.aggregate, comment_featured_ids: [], page_size: 25,
        redux_normalize_feed: true, is_reversed: false };
      if (previous) options.bookmarks = [previous];
      const reply: PinmonyNetworkReply = await this.request('UnifiedCommentsResource', options, 'native_comments_', live);
      if (!live()) return;
      if (reply.error || reply.status !== 200 || reply.body.length > 2000000) throw new Error(PinmonyI18n.message("pm_unable_to_load_comments_please_retry_eccfe65c"));
      const data: CommentsResource = (JSON.parse(reply.body) as CommentsResponse).resource_response;
      if (data?.status !== 'success' || data.error || data.code !== undefined && data.code !== 0 || !Array.isArray(data.data) || data.data.length > 2000)
        throw new Error(PinmonyI18n.message("pm_invalid_comment_response_please_retry_d0bf35c9"));
      const viewer: string | undefined = (JSON.parse(reply.body) as CommentsResponse).client_context?.user?.id;
      if (viewer !== undefined) { if (!/^\d{1,30}$/.test(viewer) || this.commentViewer && this.commentViewer !== viewer) throw new Error(PinmonyI18n.message("pm_comment_account_verification_failed_34d6e3c6")); this.commentViewer = viewer; }
      if (!append) { result.items = []; this.commentAuthors.clear(); }
      let recognized: number = 0;
      data.data.forEach((item: NativeCommentData): void => {
        const value: PinmonyComment | undefined = this.mapComment(item);
        if (value) recognized++;
        if (value && !result.items.some((old: PinmonyComment): boolean => old.id === value.id) && result.items.length < 2000) result.items.push(value);
      });
      if (data.data.length && !recognized) throw new Error(PinmonyI18n.message("pm_unsupported_comment_format_please_retry_25ae935c"));
      PinmonyRuntimeLog.info('CommentsTrace: list parsed incoming=' + data.data.length.toString() + ' recognized=' + recognized.toString() +
        ' count=' + result.items.length.toString() + ' append=' + append.toString());
      const cursor: string = typeof data.bookmark === 'string' && data.bookmark.length <= 4096 ? data.bookmark : '';
      this.commentsBookmark = cursor;
      result.ended = !cursor || cursor === '-end-' || !!previous && cursor === previous || data.data.length === 0 || result.items.length >= 2000;
      this.ports.mark('comments.list.native.committed');
    } catch (error) { if (live()) {
      result.items = retainedItems; this.commentAuthors.clear();
      retainedAuthors.forEach((author: string, id: string): void => { this.commentAuthors.set(id,author); });
      result.error = error instanceof Error ? error.message : PinmonyI18n.message("pm_unable_to_load_comments_please_retry_eccfe65c"); this.ports.mark('comments.list.native.failed');
    } }
    finally { if (revision === this.revision && commentsRevision === this.commentsRevision) this.commentsBusy = false; if (live()) { result.loading = false; this.publishComments(result); } }
  }
  private mapComment(item: NativeCommentData): PinmonyComment | undefined {
    if (!item || !/^\d+$/.test(String(item.id || ''))) return undefined;
    const session: PinmonyBusinessSessionContext = this.ports.session();
        const user: CommentUser = item.user || {};
        const photo: boolean = item.type === 'userdiditdata';
        if (/^\d{1,30}$/.test(user.id || '')) this.commentAuthors.set(String(item.id), user.id!);
        const own: boolean = !!this.commentViewer && String(user.id || '') === this.commentViewer;
        const image = (url: string): string => /^https:\/\/(?:i|s)\.pinimg\.com\//.test(url) ? url : '';
    return { id: String(item.id), type: item.type, text: String((photo ? item.details : item.text) || '').trim().slice(0, 5000),
          name: user.full_name || user.username || '', avatar: image(user.image_medium_url || ''),
          profileUrl: /^[A-Za-z0-9_]+$/.test(user.username || '') ? session.origin + '/' + user.username + '/' : '',
          createdAt: (photo ? item.done_at : item.created_at) || '', imageUrl: image(item.images?.[0]?.originals?.url || ''),
          likeCount: photo ? item.like_count || 0 : item.reaction_counts?.['1'] || 0, liked: photo ? item.liked_by_me === true : item.reaction_by_me === 1,
          canLike: photo || item.type === 'aggregatedcomment', canReply: photo || item.type === 'aggregatedcomment',
          canTranslate: item.type === 'aggregatedcomment' && typeof item.text === 'string' && !!item.text.trim(),
          canEdit: own && item.type === 'aggregatedcomment', canDelete: own && (photo || item.type === 'aggregatedcomment'),
          replyCount: item.comment_count || 0, replies: [], repliesOpen: false, repliesLoading: false, repliesError: '', busy: false };

  }
  async readReplies(commentId: string, current: () => boolean, afterWrite: boolean = false): Promise<void> {
    const result: PinmonyCommentResult = this.store.commentResult;
    const item: PinmonyComment | undefined = result.items.find((value: PinmonyComment): boolean => value.id === commentId);
    if (!this.owned() || !current() || result.pin !== this.pin || result.loading || result.busy && !afterWrite || result.uncertain ||
        !item || !/^\d+$/.test(commentId) || item.repliesLoading) return;
    if (!afterWrite && item.repliesOpen && !item.repliesError) { item.repliesOpen = false; this.publishComments(result); return; }
    item.repliesOpen = true;
    if (!afterWrite && item.replies?.length && !item.repliesError) { this.publishComments(result); return; }
    const revision: number = this.revision, token: number = this.store.commentToken;
    const commentsRevision: number = this.commentsRevision;
    const live = (): boolean => revision === this.revision && commentsRevision === this.commentsRevision && token === this.store.commentToken && this.owned() && current() &&
      this.store.commentResult.pin === result.pin && this.store.commentResult.items === result.items && result.items.includes(item);
    item.repliesLoading = true; item.repliesError = ''; this.publishComments(result);
    try {
      if (!this.ports.session().appVersion) throw new Error(PinmonyI18n.message("pm_reply_request_not_ready_please_retry_e555cdf8"));
      const options: RepliesOptions = { isUnifiedComment: true, objectId: commentId, redux_normalize_feed: true };
      const resource: string = item.type === 'userdiditdata' ? 'DidItCommentsResource' : 'AggregatedCommentReplyFeedResource';
      const reply: PinmonyNetworkReply = await this.request(resource, options, 'native_replies_', live, commentId);
      if (!live()) return;
      this.ports.mark('comments.replies.response status=' + reply.status.toString() + ' parentType=' + (item.type || 'unknown'));
      if (reply.status === 404) throw new Error(PinmonyI18n.message("pm_replies_unavailable_http_404_ce396bf4"));
      if (reply.error || reply.status !== 200 || reply.body.length > 2000000) throw new Error(PinmonyI18n.message("pm_unable_to_load_replies_please_retry_81668953"));
      const data: CommentsResource = (JSON.parse(reply.body) as CommentsResponse).resource_response;
      if (data?.status !== 'success' || data.error || data.code !== undefined && data.code !== 0 || !Array.isArray(data.data) || data.data.length > 2000)
        throw new Error(PinmonyI18n.message("pm_invalid_reply_response_please_retry_7f846edb"));
      const endpoint: string = item.type === 'userdiditdata' ? 'v3_get_user_did_it_data_comments' : 'v3_get_aggregated_comment_replies';
      if (data.endpoint_name && data.endpoint_name !== endpoint) throw new Error(PinmonyI18n.message("pm_unexpected_reply_response_please_retry_37cf2c84"));
      const replies: PinmonyComment[] = [];
      data.data.forEach((raw: NativeCommentData): void => {
        const value: PinmonyComment | undefined = this.mapComment(raw);
        if (value && !replies.some((old: PinmonyComment): boolean => old.id === value.id)) replies.push(value);
      });
      item.replies = replies;
      if (data.bookmark && data.bookmark !== '-end-') item.repliesError = PinmonyI18n.message("pm_more_replies_exist_but_pagination_is_not_supported_yet_fe6ddfb2");
      this.ports.mark('comments.replies.native.committed');
    } catch (error) { if (live()) item.repliesError = error instanceof Error ? error.message : PinmonyI18n.message("pm_unable_to_load_replies_please_retry_81668953"); }
    finally { if (live()) { item.repliesLoading = false; this.publishComments(result); } }
  }
  async translateComment(commentId: string, current: () => boolean): Promise<void> {
    const result: PinmonyCommentResult = this.store.commentResult;
    let item: PinmonyComment | undefined = result.items.find((value: PinmonyComment): boolean => value.id === commentId);
    if (!item) {
      for (const parent of result.items) {
        item = parent.replies?.find((value: PinmonyComment): boolean => value.id === commentId);
        if (item) break;
      }
    }
    if (!this.owned() || !current() || result.pin !== this.pin || result.loading || result.busy || result.uncertain ||
        !item || !/^\d+$/.test(commentId) || item.type !== 'aggregatedcomment' || typeof item.text !== 'string' || !item.text.trim() || item.translationLoading) return;
    if (item.translatedText) { item.translationVisible = !item.translationVisible; this.publishComments(result); return; }
    const selected: PinmonyComment = item;
    const revision: number = this.revision, token: number = this.store.commentToken, commentsRevision: number = this.commentsRevision;
    const text: string = selected.text;
    const live = (): boolean => revision === this.revision && commentsRevision === this.commentsRevision && token === this.store.commentToken &&
      this.owned() && current() && this.store.commentResult.pin === this.pin && selected.text === text &&
      (this.store.commentResult.items.includes(selected) || this.store.commentResult.items.some((parent: PinmonyComment): boolean => !!parent.replies?.includes(selected)));
    selected.translationLoading = true; selected.translationError = ''; this.publishComments(result);
    try {
      if (!this.ports.session().appVersion) throw new Error(PinmonyI18n.message("pm_translation_request_not_ready_please_retry_bfacc5b2"));
      PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=request');
      const options: TranslationOptions = { url: '/v3/aggregated_comments/' + commentId + '/translate/' };
      const reply: PinmonyNetworkReply = await this.request('ApiResource', options, 'native_translation_', live, commentId);
      if (!live()) return;
      if (reply.error || reply.status !== 200 || reply.body.length > 128000) { PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=request-failed status=' + reply.status.toString()); throw new Error(PinmonyI18n.message('pm_comment_translation_request_failed_please_retry_9ff98b48')); }
      const resource: TranslationResource = (JSON.parse(reply.body) as TranslationResponse).resource_response;
      if (resource?.status !== 'success' || resource.error || resource.code !== undefined && resource.code !== 0 ||
          resource.endpoint_name !== 'v3_get_translation') { PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=invalid-envelope'); throw new Error(PinmonyI18n.message('pm_invalid_comment_translation_response_please_retry_2f478594')); }
      const shape: string = resource.data === null ? 'null' : Array.isArray(resource.data) ? 'array' : typeof resource.data;
      PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=response shape=' + shape + ' textLength=' + (typeof resource.data === 'string' ? resource.data.trim().length.toString() : '0'));
      if (resource.data === null || typeof resource.data === 'string' && !resource.data.trim()) {
        PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=empty');
        selected.translationError = PinmonyI18n.message("pm_no_translation_available_52561070"); return;
      }
      // The supplied HAR proves only null. Accept bounded plain text; never render
      // an unconfirmed object shape or treat HTTP success alone as a translation.
      if (typeof resource.data !== 'string' || resource.data.length > 10000) { PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=unsupported-format'); throw new Error(PinmonyI18n.message('pm_unsupported_translation_format_9a4c1587')); }
      selected.translatedText = resource.data.trim(); selected.translationVisible = true;
      PinmonyRuntimeLog.info('CommentsTranslationTrace: phase=committed');
    } catch (error) { if (live()) selected.translationError = error instanceof Error ? error.message : PinmonyI18n.message("pm_comment_translation_failed_please_retry_0c86faa9"); }
    finally { if (live()) { selected.translationLoading = false; this.publishComments(this.store.commentResult); } }
  }
  private async readAutoplay(): Promise<void> {
    const revision: number = this.revision, viewer: string = this.commentViewer;
    try {
      if (!this.owned()) return;
      // Settings are a current-session self read. PinResource may omit its
      // viewer; use the settings response's own matching identity evidence.
      const options: Record<string,string> = {};
      const reply: PinmonyNetworkReply = await this.request('UserSettingsResource',options,'native_autoplay_');
      if (revision !== this.revision || !this.owned() || reply.error || reply.status !== 200) return;
      const body: AutoplayResponse = JSON.parse(reply.body || '') as AutoplayResponse, r: AutoplayResource | undefined = body.resource_response;
      const settingsViewer: string = r?.data?.id || '';
      if (!r || !r.data || r.status !== 'success' || r.code !== 0 || r.error || !/^\d{1,30}$/.test(settingsViewer) ||
          settingsViewer === '0' || body.client_context?.user?.id !== settingsViewer || (!!viewer && settingsViewer !== viewer)) {
        PinmonyRuntimeLog.warn('VideoAutoplayTrace: preferences=identity-rejected'); return;
      }
      this.autoplayWifi = typeof r.data.autoplay_videos_on_wifi_enabled === 'boolean' ? r.data.autoplay_videos_on_wifi_enabled : undefined;
      this.autoplayCellular = typeof r.data.autoplay_videos_on_cellular_enabled === 'boolean' ? r.data.autoplay_videos_on_cellular_enabled : undefined;
      PinmonyRuntimeLog.info('VideoAutoplayTrace: preferences=confirmed wifi=' + this.autoplayWifi + ' cellular=' + this.autoplayCellular);
      this.apply();
    } catch (_) { PinmonyRuntimeLog.warn('VideoAutoplayTrace: preferences=unavailable'); }
  }
  private async request(resource: string, options: Object, prefix: string, extraCurrent: () => boolean = (): boolean => true, commentId: string = ''): Promise<PinmonyNetworkReply> {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const pin: string = this.pin;
    const revision: number = this.revision;
    const id: string = prefix + (++this.sequence).toString();
    const source: string = prefix === 'native_autoplay_' ? '/settings/account-settings/' : pin.slice(session.origin.length);
    const headers: Record<string, string> = { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
      'X-Pinterest-Pws-Handler': 'www/pin/[id].js', 'X-Pinterest-AppState': 'active', 'X-Pinterest-Source-Url': source };
    if (session.appVersion) headers['X-App-Version'] = session.appVersion;
    if (prefix === 'native_autoplay_') headers['X-Pinterest-Pws-Handler'] = 'www/index.js';
    const envelope: ReadEnvelope = { options: options, context: {} };
    const job: PinmonyNetworkJob = { id: id, epoch: session.generation, page: pin, method: 'GET', body: '', headers: headers,
      url: session.origin + '/resource/' + resource + '/get/?source_url=' + encodeURIComponent(source) +
        '&data=' + encodeURIComponent(JSON.stringify(envelope)) };
    this.requests.add(id);
    try { return await this.ports.network().requestBusinessPinRead(job, (): PinmonyBusinessSessionContext => this.ports.session(), pin,
      (): boolean => revision === this.revision && this.owned() && extraCurrent(), (): PinmonyNetworkContext => this.ports.legacyContext(), this.aggregate, commentId); }
    finally { this.requests.delete(id); }
  }
  private async readPreview(): Promise<void> {
    if (!this.owned() || !this.aggregate) return;
    const revision: number = this.revision;
    this.previewLoading = true; this.previewError = ''; this.apply(); this.ports.mark('comments.native.request');
    try {
      if (!this.ports.session().appVersion) { this.ports.mark('comments.native.metadata.missing'); throw new Error('metadata-unavailable'); }
      const options: PreviewOptions = { aggregated_pin_id: this.aggregate };
      const reply: PinmonyNetworkReply = await this.request('UnifiedCommentsPreviewResource', options, 'native_preview_');
      if (reply.error || reply.status !== 200 || reply.body.length > 1000000) throw new Error('preview-unavailable');
      const resource: PreviewResource = (JSON.parse(reply.body) as PreviewResponse).resource_response;
      if (resource?.status !== 'success' || resource.error || resource.code !== undefined && resource.code !== 0 || !Array.isArray(resource.data))
        throw new Error('preview-invalid');
      if (revision !== this.revision || !this.owned()) return;
      const first: PreviewItem | undefined = resource.data[0];
      const comment: PreviewComment | undefined = first?.unified_comment || first?.aggregated_comment || first?.user_did_it_data;
      if (first && !comment) throw new Error('preview-shape');
      const value: string | undefined = comment?.text || comment?.details;
      this.previewText = typeof value === 'string' ? value.trim().slice(0, 4000) : '';
      this.previewEmpty = resource.data.length === 0;
      this.ports.mark('comments.native.committed');
    } catch (_) {
      if (revision === this.revision && this.owned()) { this.previewText = ''; this.previewError = this.ports.session().appVersion ?
        PinmonyI18n.message("pm_unable_to_load_comment_preview_please_retry_38deac0d") : PinmonyI18n.message("pm_comment_preview_request_not_ready_please_retry_bcf43624"); }
    } finally { if (revision === this.revision && this.owned()) { this.previewLoading = false; this.apply(); } }
  }
  private async readRelated(append: boolean): Promise<PinmonyNetworkReply> {
    const revision: number = this.revision;
    const previous: string = this.bookmark;
    this.relatedLoading = true; this.relatedError = ''; this.apply(); this.ports.mark('related.native.request');
    const options: RelatedOptions = { pin_id: this.pin.split('/pin/')[1].split('/')[0], page_size: 12,
      context_pin_ids: [], homefeed_source_sig: false, search_query: '', source: 'feed_home', top_level_source: 'feed_home',
      top_level_source_depth: 1, is_pdp: false, additional_fields: ['pin.gen_ai_topics'] };
    if (append) options.bookmarks = [previous];
    let reply: PinmonyNetworkReply = { id: '', epoch: this.sessionGeneration, page: this.pin, status: 0, body: '', url: '', error: 'cancelled', headers: {} };
    try {
      reply = await this.request('RelatedModulesResource', options, 'native_related_');
      if (revision !== this.revision || !this.owned()) return reply;
      const mapped: RelatedPresentation | undefined = !reply.error && reply.status === 200 ? readRelatedPresentation(reply.body, this.pin) : undefined;
      if (!mapped) throw new Error('related-unavailable');
      const merged: PinmonyRelatedPin[] = append ? this.related.slice() : [];
      mapped.pins.forEach((pin: PinmonyRelatedPin) => { if (!merged.some((existing: PinmonyRelatedPin): boolean => existing.pinUrl === pin.pinUrl)) merged.push(pin); });
      this.related = merged; this.bookmark = mapped.bookmark || '';
      this.relatedEnded = mapped.ended || append && this.bookmark === previous;
      this.retainedRelated.delete(this.pin);
      this.retainedRelated.set(this.pin, { at: Date.now(), pins: this.related.slice(), bookmark: this.bookmark,
        ended: this.relatedEnded, aggregate: this.aggregate, previewText: this.previewText,
        previewEmpty: this.previewEmpty, previewAvailable: this.previewAvailable,
        previewReady: !this.previewLoading && !this.previewError, reply: { id: '', epoch: this.sessionGeneration, page: this.pin,
          status: 200, body: '', url: '', error: '', headers: {} } });
      if (this.retainedRelated.size > 12) this.retainedRelated.delete(this.retainedRelated.keys().next().value);
      this.ports.mark('related.native.committed');
    } catch (_) { if (revision === this.revision && this.owned()) { this.relatedError = PinmonyI18n.message("pm_unable_to_load_recommendations_please_retry_87984c87"); reply.error = reply.error || 'invalid-response'; } }
    finally { if (revision === this.revision && this.owned()) { this.relatedLoading = false; this.apply(); } }
    PinmonyRuntimeLog.info('DetailTrace: native-read-chain settled');
    return reply;
  }
}
