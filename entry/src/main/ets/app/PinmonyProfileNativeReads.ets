import { PinmonyI18n } from 'common_foundation';
import { PinmonyProfileStore, PinmonyProfileSnapshot, PinmonyProfileAction, PinmonyBoard, PinmonyCreatedPin } from 'feature_profile';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
export const PIN_NATIVE_PROFILE_READS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface ProfileImage { url?: string; width?: number; height?: number; }
interface ProfileCover { source?: string; images?: Record<string,ProfileImage>; }
interface ProfileBoardCoverPin { custom_cover?: boolean; image_url?: string; image_signature?: string; }
interface ProfileUser { profile_cover?: ProfileCover; should_show_messaging?: boolean; profile_reach?: number; id: string; type: string; username: string; full_name?: string; image_large_url?: string; image_medium_url?: string; image_small_url?: string; follower_count?: number; following_count?: number; pin_count?: number; last_pin_save_time?: string; is_partner?: boolean; about?: string; website_url?: string; explicitly_followed_by_me?: boolean; blocked_by_me?: boolean; }
interface ProfileRow { has_custom_cover?: boolean; cover_pin?: ProfileBoardCoverPin; cover_images?: Record<string,ProfileImage>; names?: string[]; thumbnails?: Record<string,ProfileImage>[]; favorited_by_me?: boolean; access?: string[]; privacy?: string; id: string; type: string; url?: string; name?: string; title?: string | ProfileTitle; grid_title?: string; images?: Record<string,ProfileImage | ProfileImage[]>; image_cover_hd_url?: string; image_cover_url?: string; image_medium_url?: string; pin_count?: number; section_count?: number; board_order_modified_at?: string; is_collaborative?: boolean; owner?: ProfileUser; collaborating_users?: ProfileUser[]; story_type?: string; action?: ProfileAction; objects?: ProfileRow[]; pinner?: ProfileUser; }
interface ProfileTitle { text?: string; format?: string; }
interface ProfileAction { url?: string; }
interface ProfileResource { status: string; code?: number; error?: Object; data: ProfileUser | ProfileRow | ProfileRow[]; endpoint_name?: string; bookmark?: string; }
interface ProfileResponse { resource_response: ProfileResource; resource?: ProfileResourceOptions; client_context?: ProfileClient; }
interface ProfileResourceOptions { options?: ProfileOptions; }
interface ProfileClient { user?: ProfileUser; }
interface ProfileOptions { field_set_key?: string; url?: string; data?: ProfileHubData; filter_types?: number; privacyFilter?: string; boardOrder?: string; filterStories?: boolean; isOwnProfile?: boolean; isRetrievalHub?: boolean; isViewerProfile?: boolean; mixPublicSecret?: boolean; username?: string; filter_stories?: boolean; sort?: string; privacy_filter?: string; page_size?: number; group_by?: string; include_archived?: boolean; filter_all_pins?: boolean; add_fields?: string; exclude_add_pin_rep?: boolean; is_own_profile_pins?: boolean; user_id?: string; userId?: string; redux_normalize_feed?: boolean; bookmarks?: string[]; }
interface ProfileSuggestionAux { source: string; }
interface ProfileSuggestionData { board_id: string; deselected_pin_ids: string[]; }
interface ProfileSuggestionOptions { name?: string; aux_data?: ProfileSuggestionAux; url?: string; data?: ProfileSuggestionData; }
interface ProfileSuggestionEnvelope { options: ProfileSuggestionOptions; context: Record<string,string>; }
interface ProfileHubData { flag_filters?: string; fields?: string | string[]; exclude_quick_save_pins?: boolean; max_cluster_limit?: number; is_draft?: boolean; transform_to_pins?: boolean; }
interface ProfileEnvelope { options: ProfileOptions; context: Record<string,string>; }
interface ProfileMergeResponse { resource_response?: ProfileMergeResource; client_context?: ProfileClient; }
interface ProfileMergeResource { status: string; code: number; endpoint_name: string; error?: Object; data?: ProfileRow; }
interface ProfileSortData { most_recent_board_sort_order?: string; orbac_subject_id?: string; show_all_pins?: boolean; board_ids?: string[]; }
interface ProfileVisibilityWrite { show_all_pins: boolean; surface_tag: string; }
interface ProfileVisibilityEnvelope { options: ProfileSortOptions | ProfileVisibilityWrite; context: Record<string,string>; }
interface ProfileSortOptions { url: string; data: ProfileSortData; }
interface ProfileSortEnvelope { options: ProfileSortOptions; context: Record<string,string>; }
interface ProfileSortResponse { resource_response?: ProfileSortResource; client_context?: ProfileClient; }
interface ProfileSortResource { status: string; code: number; endpoint_name: string; error?: Object; data: ProfileSortData | null; }
interface ProfileInfo { cover: string; contact: boolean; monthlyViews?: number; name: string; handle: string; avatar: string; followers: number | null; following: number | null; userId: string; viewerId: string; isOwn: boolean; followingUser: boolean | null; blocked: boolean; business: boolean; about: string; website: string; pinCount: number | null; lastPinSaveTime: string; }
class ProfileSuggestionSelection {
  id: string = ''; title: string = ''; pins: PinmonyCreatedPin[] = []; selectedIds: string[] = [];
  loading: boolean = false; error: string = ''; uncertain: boolean = false;
}
class ProfileFeed {
  sort: string = '';
  ready: boolean = false; busy: boolean = false; cursor: string = ''; ended: boolean = false; error: string = ''; scroll: number = 0;
  boards: PinmonyBoard[] = []; pins: PinmonyCreatedPin[] = [];
}
export interface PinmonyProfileNativeReadsPorts {
  store: () => PinmonyProfileStore; session: () => PinmonyBusinessSessionContext; page: () => string; selected: () => boolean; active: () => boolean;
  network: () => PinmonyNativeNetwork; settled: () => void; recordAddress: (address: string) => void;
  document: () => string; documentEpoch: () => number; visitor?: () => boolean;
}
interface ProfileRouteState { hubMode: string; hubFavorite: boolean; hubCreated: boolean; hubFeed: ProfileFeed; suggestions: PinmonyBoard[]; section: string; info?: ProfileInfo; infoError: string; identityVerified: boolean; saved: ProfileFeed; created: ProfileFeed; unorganized: ProfileFeed; }
// Own-profile reads belong to the business account, independently of the hidden document.
export class PinmonyProfileNativeReads {
  private readonly ports: PinmonyProfileNativeReadsPorts;
  private readonly store: PinmonyProfileStore;
  private account: string = ''; private origin: string = ''; private generation: number = -1; private page: string = '';
  private revision: number = 0; private version: number = 0; private sequence: number = 0; private requestId: string = ''; private busy: boolean = false;
  private bridgeEpoch: number = -1; private bridgeSession: number = -1; private adoptedVersion: number = -1; private invalidation: number = 0; private invalidationEpoch: number = -1; private refreshNeeded: boolean = false;
  private bridgeRejection: string = '';
  private readonly routes: Map<string,ProfileRouteState> = new Map<string,ProfileRouteState>();
  private hubMode: string = ''; private hubFavorite: boolean = false; private hubCreated: boolean = false;
  private hubFeed: ProfileFeed = new ProfileFeed();
  private readonly hubFeeds: Map<string,ProfileFeed> = new Map();
  private hubFeedKey(mode: string, favorite: boolean, created: boolean): string { return this.account + ':' + this.generation + ':' + this.page + ':' + mode + ':' + favorite + ':' + created; }
  private suggestionSelection: ProfileSuggestionSelection | undefined = undefined;
  private suggestionWriting: boolean = false;
  private readonly attemptedSuggestions: Set<string> = new Set<string>();
  private suggestions: PinmonyBoard[] = []; private suggestionError: string = "";
  private section: string = 'saved'; private info: ProfileInfo | undefined = undefined; private infoError: string = ''; private identityVerified: boolean = false;
  private boardSortPending: string = ''; private boardSort: string = ''; private sortBusy: boolean = false; private sortError: string = '';
  private showAllPins: boolean | undefined = undefined; private visibilityBusy: boolean = false; private visibilityError: string = '';
  private saved: ProfileFeed = new ProfileFeed(); private created: ProfileFeed = new ProfileFeed(); private unorganized: ProfileFeed = new ProfileFeed();
  constructor(ports: PinmonyProfileNativeReadsPorts) { this.ports = ports; this.store = ports.store(); }
  eligible(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return PIN_NATIVE_PROFILE_READS_ENABLED && this.ports.selected() && s.authenticated && !!s.accountId && this.ports.page().startsWith(s.origin + '/') && /^\/[A-Za-z0-9_]+\/$/.test(this.ports.page().slice(s.origin.length)); }
  private bound(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.eligible() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.page === this.ports.page(); }
  owned(): boolean { return this.bound() && this.ports.active(); }
  private feed(): ProfileFeed { return this.hubMode ? this.hubFeed : this.section === 'created' ? this.created : this.saved; }
  private bind(): boolean {
    if(!this.eligible() || !this.ports.active())return false; const s: PinmonyBusinessSessionContext = this.ports.session();
    if(!this.bound()) {
      const sameAccount: boolean = this.account === s.accountId && this.generation === s.generation && this.origin === s.origin;
      if(sameAccount) {
        this.pause();
        if(this.page)this.routes.set(this.page,{hubMode:this.hubMode,hubFavorite:this.hubFavorite,hubCreated:this.hubCreated,hubFeed:this.hubFeed,suggestions:this.suggestions,section:this.section,info:this.info,infoError:this.infoError,identityVerified:this.identityVerified,saved:this.saved,created:this.created,unorganized:this.unorganized});
        while(this.routes.size > 12)this.routes.delete(this.routes.keys().next().value);
        const retained: ProfileRouteState | undefined = this.routes.get(this.ports.page());

        this.hubMode = retained?.hubMode || '';this.hubFavorite = retained?.hubFavorite === true;this.hubCreated = retained?.hubCreated === true;this.hubFeed = retained?.hubFeed || new ProfileFeed();this.suggestions = retained?.suggestions || [];
        this.section = retained?.section || 'saved';this.info = retained?.info;this.infoError = retained?.infoError || '';this.identityVerified = retained?.identityVerified === true;
        this.saved = retained?.saved || new ProfileFeed();this.created = retained?.created || new ProfileFeed();this.unorganized = retained?.unorganized || new ProfileFeed();
      }else this.reset();
      this.account = s.accountId; this.origin = s.origin; this.generation = s.generation; this.page = this.ports.page();
    }
    return true;
  }
  private pendingSortRead: boolean = false;
  pause(): void { this.suggestionSelection = undefined; this.pendingSortRead = false; this.suggestionWriting = false; if(this.store.profile?.profileUrl === this.page && this.store.profile.section === this.section)this.feed().scroll = this.store.profileScrollOffset; this.revision++; this.version++; if(this.requestId)this.ports.network().cancel(this.requestId); this.requestId = ''; this.busy = false; this.sortBusy = false; this.visibilityBusy = false; this.hubFeed.busy = false; this.saved.busy = false; this.created.busy = false; this.unorganized.busy = false; this.store.profileNativeReadsReady = false; this.store.profileActionsReady = false; this.store.profileSessionReady = false; this.store.profilePullRefreshing = false; this.bridgeEpoch = -1; this.bridgeSession = -1; this.adoptedVersion = -1; this.refreshNeeded = false; }
  reset(): void { this.hubFeeds.clear(); this.suggestionWriting = false;  this.attemptedSuggestions.clear();this.suggestions = [];this.suggestionError = ''; this.hubMode = ''; this.hubFeed = new ProfileFeed(); this.hubFavorite = false; this.hubCreated = false; this.showAllPins = undefined; this.visibilityError = ''; this.boardSort = ''; this.sortError = ''; this.routes.clear(); this.pause(); if(this.account) {this.store.profileCache.clear(); if(this.store.profile?.profileUrl === this.page)this.store.profile = undefined;} this.account = ''; this.origin = ''; this.generation = -1; this.page = ''; this.section = 'saved'; this.info = undefined; this.identityVerified = false; this.infoError = ''; this.invalidation = 0; this.invalidationEpoch = -1; this.saved = new ProfileFeed(); this.created = new ProfileFeed(); this.unorganized = new ProfileFeed(); }
  async select(section: string): Promise<boolean> {
    if(this.suggestionWriting)return false;
    if(section.startsWith('hub-create:')){await this.openSuggestion(section.slice(11));return true;}
    if(section.startsWith('hub:')) {
      const parts: string[] = section.split(':');
      if(!['pins','boards','collages','drafts','groups','secret'].includes(parts[1]) || !this.bind() || !this.info?.isOwn || !this.identityVerified)return false;
      if(this.hubFeeds.size >= 32)this.hubFeeds.clear();
      if(this.hubMode && this.hubFeed.ready && !this.hubFeed.error)this.hubFeeds.set(this.hubFeedKey(this.hubMode,this.hubFavorite,this.hubCreated),this.hubFeed);
      this.pause(); this.hubMode = parts[1]; this.hubFavorite = parts[2] === '1'; this.hubCreated = parts[3] === '1';
      this.section = ['boards','groups','secret'].includes(this.hubMode) ? 'saved' : 'created';
      this.hubFeed = this.hubFeeds.get(this.hubFeedKey(this.hubMode,this.hubFavorite,this.hubCreated)) || new ProfileFeed(); this.apply(); await this.demand(); return true;
    }
    if(this.hubMode){this.pause();this.hubMode = '';this.hubFeed = new ProfileFeed();}
 if(!['saved','created'].includes(section) || !this.bind())return false; if(section !== this.section) {this.pause(); this.section = section; this.store.profileScrollOffset = this.feed().scroll; this.store.profileSwitching = false; this.ports.recordAddress(this.page + (section === 'created' ? '_created/' : ''));} this.apply(); await this.demand(); return true; }
  favoriteChanged(pin: string, favorite: boolean): void {
    this.pause();this.hubFeeds.clear();this.routes.clear();this.store.profileCache.clear();
    [this.hubFeed,this.created,this.unorganized].forEach((feed: ProfileFeed): void => {
      feed.pins.forEach((p: PinmonyCreatedPin): void => {if(p.targetUrl === pin)p.favorite = favorite;});
    });
    if(this.hubMode === 'pins') {
      if(this.hubFavorite && !favorite)this.hubFeed.pins = this.hubFeed.pins.filter((p: PinmonyCreatedPin): boolean => p.targetUrl !== pin);
      this.hubFeed.ready = false;this.hubFeed.cursor = '';this.hubFeed.ended = false;
    }
    this.apply();
  }
  confirmAvatar(page: string, avatar: string): void {
    if (!this.owned() || page !== this.page || !this.info?.isOwn || !this.image(avatar)) return;
    // Retire reads started before the confirmed upload; cached profile metadata
    // must not restore the former avatar while the new profile read is pending.
    this.pause();
    this.info.avatar = avatar;
    this.store.profileCache.clear();
    this.apply();
  }
  apply(): void {
    if(!this.owned())return; const f: ProfileFeed = this.feed(), i: ProfileInfo | undefined = this.info;
    if(this.store.profile?.profileUrl !== this.page || this.store.profile.section !== this.section)this.store.profileScrollOffset = f.scroll;
    const previous: PinmonyProfileSnapshot | undefined = this.store.profile?.profileUrl === this.page && this.store.profile.section === this.section ? this.store.profile : undefined;
    const actions: PinmonyProfileAction[] = i?.isOwn ? [{id:'api-edit-profile',kind:'edit',label:PinmonyI18n.message("pm_edit_profile_3b0b2bb8"),enabled:true}] : i && typeof i.followingUser === 'boolean' && !i.blocked ? [{id:'api-follow-user',kind:'follow',label:i.followingUser ? PinmonyI18n.message("pm_following_7dfa5d8f") : PinmonyI18n.message("pm_follow_eb137dee"),enabled:true}] : [];
    if(i && !i.isOwn && i.contact && !i.blocked)actions.push({id:'api-contact-user',kind:'contact',label:PinmonyI18n.message("pm_contact_bfc96732"),enabled:true});
    const snapshot: PinmonyProfileSnapshot = { suggestionTitle:this.suggestionSelection?.title,suggestionWriting:this.suggestionWriting,suggestionUnavailableIds:Array.from(this.attemptedSuggestions),suggestions:this.suggestions.slice(),suggestionError:this.suggestionError,hubMode:this.hubMode,hubFavorite:this.hubFavorite,hubCreated:this.hubCreated,kind:'state',nativeVersion:this.version,session:this.store.profileSession,profileUrl:this.page,section:this.section,
      monthlyViews:i?.monthlyViews,displayName:i?.name || '',handle:i?.handle || '',avatarUrl:i?.avatar || '',coverUrl:i?.cover || '',business:i?.business,isOwn:i?.isOwn,about:i?.about || '',website:i?.website || '',
      followers:i?.followers !== undefined && i.followers !== null ? i.followers.toString() + PinmonyI18n.message("pm_followers_7c3af361") : '',following:i?.following !== undefined && i.following !== null ? i.following.toString() + PinmonyI18n.message("pm_following_52ff9a6f") : '',
      actions:actions,boards:f.boards.slice(),createdPins:f.pins.slice(),boardSort:i?.isOwn ? this.boardSort : '',boardSortBusy:this.sortBusy,boardSortPending:this.boardSortPending,boardSortError:this.sortError,
      showAllPins:i?.isOwn ? this.showAllPins : undefined,visibilityBusy:this.visibilityBusy,visibilityError:this.visibilityError,
      contentLoading:!f.ready && this.busy,contentLoadingMore:f.ready && f.busy,contentError:f.error,contentHasMore:!f.ended && !!f.cursor,
      unorganizedPins:(!this.hubMode || this.hubMode === 'boards') && this.section === 'saved' ? this.unorganized.pins.slice() : [],unorganizedLoading:this.section === 'saved' && this.unorganized.busy,
      unorganizedError:this.unorganized.error,unorganizedHasMore:!this.unorganized.ended && !!this.unorganized.cursor,unorganizedFeedback:previous?.unorganizedFeedback || '',organize:previous?.organize };
    if(this.suggestionSelection) {
      const selection: ProfileSuggestionSelection = this.suggestionSelection;
      snapshot.unorganizedPins = selection.pins.slice(); snapshot.unorganizedLoading = selection.loading;
      snapshot.unorganizedError = selection.error; snapshot.unorganizedHasMore = false;
      snapshot.organize = {phase:'select',selectedIds:selection.selectedIds.slice(),boards:[],loading:selection.loading,busy:this.suggestionWriting,error:selection.uncertain ? selection.error : '',feedback:'',hasMore:false,uncertain:selection.uncertain};
    } else if(previous?.suggestionTitle) snapshot.organize = undefined;
    this.store.profile = snapshot; this.store.profileUrl = this.page; this.store.profileNativeReadsReady = this.identityVerified && !!i && f.ready; this.store.profileLoading = !i && this.busy; this.store.profileError = this.infoError;
    if(i && f.ready && !this.busy && !f.error && !this.suggestionSelection)this.store.profileCache.put(snapshot,this.store.profileScrollOffset);
    if(this.pendingSortRead && !this.busy && !this.sortBusy && this.identityVerified && i?.isOwn && this.section === 'saved') {
      this.pendingSortRead = false;
      PinmonyRuntimeLog.info('ProfileSortTrace: phase=dequeued');
      const queuedRevision: number = this.revision;
      this.sortBoards('').then((): void => { if (queuedRevision === this.revision && this.owned()) this.loadBoardVisibility(); });
    }
  }
  async demand(): Promise<void> { if(!this.bind())return; this.apply(); if(this.suggestionSelection)return; if(this.busy || this.infoError || this.feed().error)return; if(!this.info || !this.feed().ready)await this.read(false,false); else if((!this.hubMode || this.hubMode === 'boards') && this.info?.isOwn && this.section === 'saved' && !this.unorganized.ready && !this.unorganized.error)await this.readUnorganized(false); }
  async sortBoards(value: string): Promise<void> {
    if (!this.bind() || !this.identityVerified || !this.info?.isOwn || this.section !== 'saved') return;
    if (this.busy || this.sortBusy) {
      if (!value && !this.sortBusy) {
        this.pendingSortRead = true;
        PinmonyRuntimeLog.info('ProfileSortTrace: phase=queued reason=profile-busy');
      }
      return;
    }
    this.pendingSortRead = false;
    if (value && (!['alphabetical','last_pinned_to','custom'].includes(value) || !this.boardSort || !!this.sortError)) return;
    if (value && value === this.boardSort) return;
    const revision: number = this.revision, page: string = this.page, previous: string = this.boardSort || 'last_pinned_to';
    const live = (): boolean => revision === this.revision && this.owned() && this.page === page && this.info?.isOwn === true;
    this.busy = true; this.sortBusy = true; this.boardSortPending = value || this.boardSort || 'alphabetical'; this.sortError = ''; this.apply();
    let reload: boolean = false;
    let failure: string = 'request-dispatch';
    try {
      const options: ProfileSortOptions = { url: value ? '/v3/users/me/metadata/' : '/v3/users/' + this.info.handle + '/metadata/', data: value ? {most_recent_board_sort_order:value,orbac_subject_id:''} : {} };
      const envelope: ProfileSortEnvelope = {options:options,context:{}}, source: string = page.slice(this.origin.length);
      const form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
      const id: string = 'native_profile_sort_' + (++this.sequence).toString(); this.requestId = id;
      const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:page,url:this.origin + '/resource/ApiResource/' + (value ? 'create/' : 'get/?' + form),method:value ? 'POST' : 'GET',body:value ? form : '',headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}};
      const reply = await this.ports.network().requestBusinessProfileSort(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.info.userId,this.info.viewerId,live);
      if (!live()) return;
      PinmonyRuntimeLog.info('ProfileSortTrace: phase=response write=' + (!!value).toString() + ' status=' + reply.status.toString() + ' transportError=' + (!!reply.error).toString());
      failure = 'transport';if (reply.error) throw new Error('sort-request');
      failure = 'http-status';if (reply.status !== 200) throw new Error('sort-request');
      failure = 'body-empty';if (!reply.body) throw new Error('sort-request');
      failure = 'body-limit';if (reply.body.length > 100000) throw new Error('sort-request');
      failure = 'json-parse';
      const response: ProfileSortResponse = JSON.parse(reply.body) as ProfileSortResponse;
      failure = 'response-shape';if (!response || typeof response !== 'object' || Array.isArray(response)) throw new Error('sort-response');
      const r: ProfileSortResource | undefined = response.resource_response;
      failure = 'resource-missing';if (!r || typeof r !== 'object' || Array.isArray(r)) throw new Error('sort-response');
      PinmonyRuntimeLog.info('ProfileSortTrace: phase=validation write=' + (!!value).toString() +
        ' statusOk=' + (r.status === 'success').toString() + ' codePresent=' + (r.code !== undefined).toString() +
        ' codeZero=' + (r.code === 0).toString() + ' errorPresent=' + (!!r.error).toString() +
        ' endpointPresent=' + (typeof r.endpoint_name === 'string' && r.endpoint_name.length > 0).toString() +
        ' endpointMatch=' + (r.endpoint_name === (value ? 'v3_user_metdata_set' : 'v3_user_metdata_get')).toString() +
        ' viewerPresent=' + (!!response.client_context?.user?.id).toString() +
        ' viewerMatch=' + (!response.client_context?.user?.id || response.client_context.user.id === this.info.viewerId).toString() +
        ' dataNull=' + (r.data === null).toString() + ' sortType=' + typeof r.data?.most_recent_board_sort_order);
      failure = 'business-status';if (r.status !== 'success') throw new Error('sort-response');
      failure = 'business-code';if (r.code !== 0) throw new Error('sort-response');
      failure = 'business-error';if (r.error) throw new Error('sort-response');
      failure = 'endpoint-mismatch';if (r.endpoint_name !== (value ? 'v3_user_metdata_set' : 'v3_user_metdata_get')) throw new Error('sort-response');
      failure = 'viewer-mismatch';if (response.client_context?.user?.id && response.client_context.user.id !== this.info.viewerId) throw new Error('sort-response');
      const confirmed: string = value || r.data?.most_recent_board_sort_order || '';
      failure = 'sort-missing';if (!confirmed) throw new Error('sort-value');
      failure = 'sort-unsupported';if (!['alphabetical','last_pinned_to','custom'].includes(confirmed)) throw new Error('sort-value');
      failure = 'write-data-not-null';if (value && r.data !== null) throw new Error('sort-value');
      PinmonyRuntimeLog.info('ProfileSortTrace: phase=validated write=' + (!!value).toString());
      // Opening the options panel reads metadata without invalidating its visible feed.
      reload = !!value && previous !== confirmed; this.boardSort = confirmed;
      if(reload)this.store.profileCache.clear();
      if (reload) { this.hubFeeds.clear(); this.feed().ready = false;this.feed().cursor = '';this.feed().ended = false; this.saved.ready = false; this.saved.cursor = ''; this.saved.ended = false; this.saved.error = ''; }
    } catch (_) {
      if (live()) {
        PinmonyRuntimeLog.info('ProfileSortTrace: phase=rejected write=' + (!!value).toString() + ' reason=' + failure);
        this.sortError = value ? 'pm_profile_sort_save_error' : 'pm_profile_sort_load_error';
      }
    }
    finally { if (revision === this.revision) { if (live() && reload) await this.read(false,false); if (revision === this.revision) { this.busy = false; this.sortBusy = false; this.boardSortPending = ''; this.requestId = ''; if (live()) this.apply(); this.ports.settled(); } } }
  }
  private uncertainMerges: Set<string> = new Set<string>();
  async mergeBoards(sourceId: string, targetId: string): Promise<string> {
    if (!this.bind() || !this.identityVerified || !this.info?.isOwn || this.section !== 'saved' || this.busy || this.sortBusy) return 'unavailable';
    const source: PinmonyBoard | undefined = this.feed().boards.find((b: PinmonyBoard): boolean => b.id === sourceId && b.mergeable === true);
    const target: PinmonyBoard | undefined = this.feed().boards.find((b: PinmonyBoard): boolean => b.id === targetId && b.mergeable === true);
    const from: string = sourceId.replace(/^profile-api-native-/, ''), to: string = targetId.replace(/^profile-api-native-/, '');
    const key: string = this.account + ':' + this.generation.toString() + ':' + from + ':' + to;
    if (!source || !target || sourceId === targetId || !/^\d{1,30}$/.test(from) || !/^\d{1,30}$/.test(to) || !source.targetUrl) return 'unavailable';
    if (this.uncertainMerges.has(key)) return 'uncertain';
    const revision: number = this.revision, page: string = this.page;
    const live = (): boolean => revision === this.revision && this.owned() && this.page === page && this.info?.isOwn === true;
    this.busy = true; this.sortBusy = true; this.sortError = ''; this.apply();
    let result: string = 'uncertain';
    // A response lost after dispatch cannot safely be replayed.
    this.uncertainMerges.add(key);
    try {
      const envelope: ProfileSortEnvelope = { options: { url: '/v3/boards/' + from + '/merge/' + to + '/', data: {} }, context: {} };
      const job: PinmonyNetworkJob = { id: 'native_board_management_write_profile_' + (++this.sequence).toString(), epoch: this.generation,
        page: source.targetUrl, url: this.origin + '/resource/ApiResource/create/', method: 'POST',
        body: 'source_url=' + encodeURIComponent(source.targetUrl.slice(this.origin.length)) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/[username]/[slug].js' } };
      this.requestId = job.id;
      const reply = await this.ports.network().requestBusinessBoardManagementWrite(job, (): PinmonyBusinessSessionContext => this.ports.session(),
        from, this.info.viewerId, this.info.viewerId, false, live, [to]);
      if (!live() || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 6000000) throw new Error('merge-request');
      const response: ProfileMergeResponse = JSON.parse(reply.body) as ProfileMergeResponse, r: ProfileMergeResource | undefined = response.resource_response;
      if (!r || r.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'v3_board_merge' || r.data?.type !== 'board' ||
        r.data.id !== to || response.client_context?.user?.id && response.client_context.user.id !== this.info.viewerId) throw new Error('merge-response');
      result = 'confirmed'; this.uncertainMerges.delete(key); this.store.profileCache.clear();
      this.feed().boards = this.feed().boards.filter((b: PinmonyBoard): boolean => b.id !== sourceId);
      this.hubFeeds.clear();this.feed().ready = false;this.saved.ready = false; this.feed().cursor = '';this.saved.cursor = ''; this.saved.ended = false; this.saved.error = '';
    } catch (_) { if (live()) this.sortError = 'pm_unconfirmed_c098e854'; }
    finally {
      if (revision === this.revision) {
        if (live() && result === 'confirmed') await this.read(false, false);
        if (revision === this.revision) { this.busy = false; this.sortBusy = false; this.requestId = ''; if (live()) this.apply(); this.ports.settled(); }
      }
    }
    return result;
  }
  async reorderBoards(boardIds: string[]): Promise<void> {
    if (!this.bind() || !this.identityVerified || !this.info?.isOwn || this.section !== 'saved' || this.busy || this.sortBusy) return;
    const ids: string[] = boardIds.filter((id: string): boolean => /^\d{1,40}$/.test(id));
    if (!ids.length || new Set(ids).size !== ids.length) return;
    const revision: number = this.revision, page: string = this.page;
    const live = (): boolean => revision === this.revision && this.owned() && this.page === page && this.info?.isOwn === true;
    this.busy = true; this.sortBusy = true; this.boardSortPending = 'custom'; this.sortError = ''; this.apply();
    try {
      const options: ProfileSortOptions = { url: '/v3/users/boards/partial_reorder/', data: { board_ids: ids } as ProfileSortData };
      const envelope: ProfileSortEnvelope = { options: options, context: {} }, source: string = page.slice(this.origin.length);
      const form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
      const id: string = 'native_profile_sort_reorder_' + (++this.sequence).toString(); this.requestId = id;
      const job: PinmonyNetworkJob = { id: id, epoch: this.generation, page: page, url: this.origin + '/resource/ApiResource/create/', method: 'POST', body: form,
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } };
      const reply = await this.ports.network().requestBusinessProfileSort(job, (): PinmonyBusinessSessionContext => this.ports.session(), this.info.userId, this.info.viewerId, live);
      if (!live() || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 100000) throw new Error('reorder-request');
      const response: ProfileSortResponse = JSON.parse(reply.body) as ProfileSortResponse, resource: ProfileSortResource | undefined = response.resource_response;
      if (!resource || resource.status !== 'success' || resource.code !== 0 || resource.error || resource.endpoint_name !== 'v3_partial_reorder_boards_handler' || resource.data !== null) throw new Error('reorder-response');
      if (response.client_context?.user?.id && response.client_context.user.id !== this.info.viewerId) throw new Error('reorder-viewer');
      // Reordering positions does not persist the profile's active sort preference.
      const preference: ProfileSortEnvelope = { options: { url: '/v3/users/me/metadata/', data: { most_recent_board_sort_order: 'custom', orbac_subject_id: '' } }, context: {} };
      const preferenceId: string = 'native_profile_sort_' + (++this.sequence).toString(); this.requestId = preferenceId;
      const preferenceJob: PinmonyNetworkJob = { id: preferenceId, epoch: this.generation, page: page,
        url: this.origin + '/resource/ApiResource/create/', method: 'POST',
        body: 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(preference)), headers: job.headers };
      const preferenceReply = await this.ports.network().requestBusinessProfileSort(preferenceJob, (): PinmonyBusinessSessionContext => this.ports.session(), this.info.userId, this.info.viewerId, live);
      if (!live() || preferenceReply.error || preferenceReply.status !== 200 || !preferenceReply.body || preferenceReply.body.length > 100000) throw new Error('reorder-preference-request');
      const preferenceResponse: ProfileSortResponse = JSON.parse(preferenceReply.body) as ProfileSortResponse;
      const confirmed: ProfileSortResource | undefined = preferenceResponse.resource_response;
      if (!confirmed || confirmed.status !== 'success' || confirmed.code !== 0 || confirmed.error || confirmed.endpoint_name !== 'v3_user_metdata_set' ||
        confirmed.data !== null || preferenceResponse.client_context?.user?.id && preferenceResponse.client_context.user.id !== this.info.viewerId) throw new Error('reorder-preference-response');
      this.boardSort = 'custom'; this.store.profileCache.clear(); this.hubFeeds.clear();this.feed().ready = false;this.saved.ready = false; this.feed().cursor = '';this.saved.cursor = ''; this.saved.ended = false; this.saved.error = '';
    } catch (_) { if (live()) this.sortError = 'pm_profile_sort_save_error'; }
    finally { if (revision === this.revision) { if (live() && !this.sortError) await this.read(false, false); if (revision === this.revision) { this.busy = false; this.sortBusy = false; this.boardSortPending = ''; this.requestId = ''; if (live()) this.apply(); this.ports.settled(); } } }
  }
  private async requestVisibility(value: boolean | undefined, revision: number): Promise<boolean> {
    const write: boolean = typeof value === 'boolean';
    const envelope: ProfileVisibilityEnvelope = {options:write ? {show_all_pins:value === true,surface_tag:'holistic_profile_prompt'} : {url:'/v3/users/settings/',data:{}},context:{}};
    const form: string = 'source_url=' + encodeURIComponent(this.page.slice(this.origin.length)) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const id: string = 'native_profile_sort_' + (++this.sequence).toString(); this.requestId = id;
    const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:this.page,url:this.origin + (write ? '/resource/UserSettingsResource/update/' : '/resource/ApiResource/get/?' + form),method:write ? 'POST' : 'GET',body:write ? form : '',headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}};
    const reply = await this.ports.network().requestBusinessProfileSort(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.info?.userId || '',this.info?.viewerId || '',(): boolean => revision === this.revision && this.owned() && this.info?.isOwn === true);
    if (revision !== this.revision || !this.owned() || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 1000000) throw new Error('visibility-request');
    const response: ProfileSortResponse = JSON.parse(reply.body) as ProfileSortResponse, r: ProfileSortResource | undefined = response.resource_response;
    if (!r || r.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== (write ? 'v3_edit_settings_handler' : 'v3_get_user_settings') || typeof r.data?.show_all_pins !== 'boolean' || response.client_context?.user?.id && response.client_context.user.id !== this.info?.viewerId) throw new Error('visibility-response');
    if (write && r.data.show_all_pins !== value) throw new Error('visibility-result');
    return r.data.show_all_pins;
  }
  async loadBoardVisibility(value?: boolean): Promise<void> {
    if (!this.bind() || !this.identityVerified || !this.info?.isOwn || this.section !== 'saved' || this.busy) return;
    if (typeof value === 'boolean' && (typeof this.showAllPins !== 'boolean' || !!this.visibilityError || value === this.showAllPins)) return;
    const revision: number = this.revision;
    const live = (): boolean => revision === this.revision && this.owned() && this.info?.isOwn === true;
    this.busy = true; this.visibilityBusy = true; this.visibilityError = ''; this.apply();
    try {
      if (typeof value === 'boolean') await this.requestVisibility(value,revision);
      if (!live()) return;
      const confirmed: boolean = await this.requestVisibility(undefined,revision);
      if (!live()) return;
      if (typeof value === 'boolean' && confirmed !== value) throw new Error('visibility-readback');
      this.showAllPins = confirmed; this.store.profileCache.clear();
      if (typeof value === 'boolean') { this.saved.cursor = ''; this.saved.ended = false; await this.read(false,true); }
    } catch (_) { if (live()) this.visibilityError = typeof value === 'boolean' ? 'pm_profile_visibility_save_error' : 'pm_profile_visibility_load_error'; }
    finally { if (revision === this.revision) { this.busy = false; this.visibilityBusy = false; this.requestId = ''; if (live()) this.apply(); this.ports.settled(); } }
  }

  async refresh(pull: boolean = false): Promise<void> { if(!this.bind())return; if(this.busy){this.refreshNeeded = true;this.store.profilePullRefreshing = this.store.profilePullRefreshing || pull;return;} this.hubFeeds.clear(); this.store.profileCache.clear(); this.version++; this.store.profilePullRefreshing = pull; this.store.profileActionsReady = false; this.store.profileSessionReady = false; await this.read(false,true); }
  async more(): Promise<void> { if(!this.bind() || !this.identityVerified || this.busy || this.feed().ended || !this.feed().cursor)return; await this.read(true,false); }
  async unorganizedAction(action: string, value: string = ''): Promise<boolean> {
    const selection: ProfileSuggestionSelection | undefined = this.suggestionSelection;
    if(selection) {
      if(!this.bind() || !this.info?.isOwn || this.suggestionSelection !== selection)return true;
      if(this.suggestionWriting)return true;
      if(action === 'close' || action === 'back') {this.revision++;if(this.requestId)this.ports.network().cancel(this.requestId);this.requestId = '';this.busy = false;this.suggestionSelection = undefined;this.apply();return true;}
      if(selection.loading || selection.uncertain)return true;
      if(action === 'retryPins') {await this.openSuggestion(selection.id);return true;}
      if(action === 'toggle' && selection.pins.some((p: PinmonyCreatedPin): boolean => p.id === value))selection.selectedIds = selection.selectedIds.includes(value) ? selection.selectedIds.filter((id: string): boolean => id !== value) : selection.selectedIds.concat(value);
      if(action === 'all')selection.selectedIds = selection.selectedIds.length === selection.pins.length ? [] : selection.pins.map((p: PinmonyCreatedPin): string => p.id);
      if(action === 'next' && !selection.error && selection.selectedIds.length)await this.createSuggestion(selection.id);
      this.apply();return true;
    }
 if(!['morePins','retryPins'].includes(action) || !this.bind() || !this.info?.isOwn)return false; if(this.busy)return true; await this.readUnorganized(action === 'morePins' && this.unorganized.ready && !!this.unorganized.cursor); return true; }
  installScript(): string {
    if(this.ports.visitor?.() || !this.owned() || !this.info || !this.identityVerified)return '';
    // pause/refresh advances the native version while retaining the visible snapshot.
    // Publish a current snapshot before serializing the document handshake.
    this.apply();
    return '(function(){var profile=' + JSON.stringify(this.page) + ';if([profile,profile+"_created/",profile+"_saved/"].indexOf(location.origin+location.pathname)<0)return false;if(window.PinmonyHomeApi && window.PinmonyHomeApi.setUsername)window.PinmonyHomeApi.setUsername(' + JSON.stringify(this.info.handle) + ');return window.PinmonyProfileApi && window.PinmonyProfileApi.installNative && window.PinmonyProfileApi.installNative(' + JSON.stringify(this.page) + ',' + JSON.stringify(this.info) + ',' + JSON.stringify(this.section) + ',' + JSON.stringify(this.store.profile) + ',' + JSON.stringify(this.unorganized.cursor) + ');})();';
  }
  // A document handshake grants write readiness; its arrays never replace native main feeds.
  private rejectBridge(reason: string): void {
    if (this.bridgeRejection === reason) return;
    this.bridgeRejection = reason;
    PinmonyRuntimeLog.info('ProfileNativeTrace: context-rejected reason=' + reason);
  }
  updateBridge(value: string): void {
    if(this.ports.visitor?.() || !this.bound())return;
    try {
      const m: PinmonyProfileSnapshot = JSON.parse(value) as PinmonyProfileSnapshot;
      const path: string = this.ports.document().split(/[?#]/)[0];
      if(!this.owned() || !m.nativeOwn) {this.rejectBridge('ownership');return;}
      if(m.contextEpoch !== this.ports.documentEpoch()) {this.rejectBridge('document-epoch');return;}
      if(m.profileUrl !== this.page || ![this.page,this.page + '_created/',this.page + '_saved/'].includes(path)) {this.rejectBridge('document-route');return;}
      if(m.kind !== 'nativeContext' && m.section !== this.section) {this.rejectBridge('section');return;}
      if(!Number.isInteger(m.session) || m.session < 0) {this.rejectBridge('session');return;}
      if(m.kind !== 'nativeContext' && m.kind !== 'state')return;
      if(m.kind === 'state' && m.nativeVersion !== this.version) {
        this.rejectBridge('native-version');
        // A write already confirmed in this document may finish after a newer native GET.
        // Accept its invalidation signal only; its old arrays and permissions stay rejected.
        if(this.bridgeEpoch === m.contextEpoch && m.session === this.bridgeSession && m.nativeVersion === this.adoptedVersion)this.invalidateFromBridge(m);
        return;
      }
      if(this.invalidationEpoch !== m.contextEpoch){this.invalidationEpoch = m.contextEpoch || 0; this.invalidation = 0;}
      if(this.bridgeEpoch === m.contextEpoch && m.session < this.bridgeSession)return; this.bridgeEpoch = m.contextEpoch; this.bridgeSession = m.session;
      if(m.kind === 'state')this.adoptedVersion = m.nativeVersion === undefined ? -1 : m.nativeVersion;
      if(m.kind === 'state' && (!this.store.profileActionsReady || this.bridgeRejection))PinmonyRuntimeLog.info('ProfileNativeTrace: action-context accepted');
      this.bridgeRejection = '';
      this.store.profileSession = m.session; this.store.profileSessionReady = this.identityVerified && !!this.info; this.store.profileActionsReady = m.kind === 'state' && this.identityVerified && !!this.info;
      if(m.kind === 'state' && Array.isArray(m.unorganizedPins) && m.unorganizedPins.length <= 500) {
        const pins: PinmonyCreatedPin[] = m.unorganizedPins;
        if(pins.every((p: PinmonyCreatedPin): boolean => /^\d{1,40}$/.test(p.id) && !!this.image(p.imageUrl))) {
          this.unorganized.pins = pins.map((p: PinmonyCreatedPin): PinmonyCreatedPin => ({id:p.id,title:p.title,imageUrl:p.imageUrl,imageWidth:p.imageWidth,imageHeight:p.imageHeight,targetUrl:this.origin + '/pin/' + p.id + '/'}));
          this.unorganized.error = m.unorganizedError || '';
          if(this.store.profile){ this.store.profile.organize = m.organize; this.store.profile.unorganizedFeedback = m.unorganizedFeedback; }
        }
      }
      this.apply();
      if(m.kind === 'state')this.invalidateFromBridge(m);
    } catch (_) {}
  }
  private invalidateFromBridge(m: PinmonyProfileSnapshot): void {
    if(!Number.isInteger(m.nativeInvalidation) || (m.nativeInvalidation || 0) <= this.invalidation)return;
    this.invalidation = m.nativeInvalidation || 0;
    if(this.busy)this.refreshNeeded = true; else this.refresh();
  }
  private clean(value: string | undefined, limit: number = 300): string { return typeof value === 'string' ? value.trim().slice(0,limit) : ''; }
  private image(value: string | undefined): string { return typeof value === 'string' && value.length <= 2000 && /^https:\/\/(?:i|s)\.pinimg\.com\//i.test(value) ? value : ''; }
  private count(value: number | undefined): number | null { return typeof value === 'number' && Number.isFinite(value) && value >= 0 && Number.isInteger(value) ? value : null; }
  private updated(value: string | undefined): string { const elapsed: number = Date.now() - Date.parse(value || ''); if(!Number.isFinite(elapsed) || elapsed < 0)return ''; const d: number = Math.floor(elapsed / 86400000); return d < 1 ? PinmonyI18n.message("pm_today_d5f5a7a0") : d < 7 ? d.toString() + PinmonyI18n.message("pm_days_ago_5972982c") : d < 30 ? Math.floor(d / 7).toString() + PinmonyI18n.message("pm_weeks_ago_2ad8bd1c") : d < 365 ? Math.floor(d / 30).toString() + PinmonyI18n.message("pm_months_ago_1bb931f2") : Math.floor(d / 365).toString() + PinmonyI18n.message("pm_years_ago_c533a6c6"); }
  private target(value: string | undefined): string { if(typeof value !== 'string' || value.length > 2000)return ''; const url: string = value.startsWith('/') ? this.origin + value : value; return url.startsWith(this.origin + '/') && !/[\s?#]/.test(url) ? url : ''; }
  private pin(row: ProfileRow, unorganized: boolean = false): PinmonyCreatedPin | undefined {
    if(row?.type !== 'pin' || typeof row.id !== 'string' || !/^\d{1,40}$/.test(row.id) || unorganized && row.pinner?.id !== this.info?.userId)return undefined;
    const img: ProfileImage | undefined = (row.images?.['736x'] || row.images?.['474x'] || row.images?.['236x'] || row.images?.['orig']) as ProfileImage | undefined;
    if(!this.image(img?.url))return undefined;
    return {id:unorganized ? row.id : 'profile-api-native-' + row.id,targetUrl:this.origin + '/pin/' + row.id + '/',favorite:typeof row.favorited_by_me === 'boolean' ? row.favorited_by_me : undefined,title:this.clean(row.grid_title || (typeof row.title === 'string' ? row.title : '')),imageUrl:this.image(img?.url),imageWidth:img?.width || 0,imageHeight:img?.height || 0};
  }
  private collageDraft(row: ProfileRow): PinmonyCreatedPin | undefined {
    // The captured drawer response contains shuffle fields, without a Pin type or route.
    if (!row || row.type !== undefined || typeof row.id !== 'string' || !/^\d{1,40}$/.test(row.id)) return undefined;
    const img: ProfileImage | undefined = (row.images?.['736x'] || row.images?.['474x'] ||
      row.images?.['236x'] || row.images?.['originals']) as ProfileImage | undefined;
    const imageUrl: string = this.image(img?.url);
    if (!imageUrl) return undefined;
    return { id: 'profile-collage-draft-' + row.id, collageDraft: true, title: '', imageUrl: imageUrl,
      imageWidth: img?.width || 0, imageHeight: img?.height || 0 };
  }
  private board(row: ProfileRow): PinmonyBoard | undefined {
    if(!row || typeof row.id !== 'string' || row.id.length > 100)return undefined;
    const coverAlternatives: string[] = [];
    let target: string = '', title: string = '', covers: string[] = [], count: number | null = null, updated: string = ''; const avatars: string[] = [];
    if(row.type === 'board') {
      if(!/^\d{1,40}$/.test(row.id))return undefined; target = this.target(row.url); title = this.clean(row.name); count = this.count(row.pin_count); updated = this.updated(row.board_order_modified_at);
      const imgs: ProfileImage[] = row.images?.['236x'] as ProfileImage[] || []; if(Array.isArray(imgs))covers = imgs.map((im: ProfileImage): string => this.image(im.url)).filter((v: string): boolean => !!v);
      const generated: string = this.image(row.image_cover_url) || this.image(row.cover_images?.['200x150']?.url) || this.image(row.cover_images?.['236x']?.url);
      if(generated && (row.has_custom_cover === true || row.cover_pin?.custom_cover === true || generated.includes('/custom_covers/'))) {
        [generated,this.image(row.cover_images?.['200x150']?.url),this.image(row.cover_images?.['236x']?.url)].forEach((url: string): void => {if(url && !coverAlternatives.includes(url))coverAlternatives.push(url);});
        const signature: string = typeof row.cover_pin?.image_signature === 'string' && /^[a-f0-9]{32}$/i.test(row.cover_pin.image_signature) ? row.cover_pin.image_signature : '';
        const source: string = this.image(row.cover_pin?.image_url);
        covers = [generated].concat(covers.filter((url: string): boolean => url !== generated && url !== source && (!signature || !url.includes('/'+signature+'.'))));
      }
      if(!covers.length && this.image(row.image_cover_hd_url || row.image_cover_url))covers.push(this.image(row.image_cover_hd_url || row.image_cover_url));
      if(row.is_collaborative === true) {const seen: Set<string> = new Set<string>(); const users: ProfileUser[] = row.owner ? [row.owner] : []; users.concat(row.collaborating_users || []).slice(0,100).forEach((u: ProfileUser): void => {if(u && !seen.has(u.id) && avatars.length < 6) {seen.add(u.id); const avatar: string = this.image(u.image_small_url || u.image_medium_url); if(avatar)avatars.push(avatar);}});}
    } else if(row.type === 'story' && row.story_type === 'all_pins') {
      if(this.info?.pinCount === 0 && !row.objects?.length)return undefined; target = this.target(row.action?.url);
      const internal: RegExpMatchArray | null = target.match(/\/users\/(\d+)\/pins\/?$/); if(internal) {if(internal[1] !== this.info?.userId)return undefined; target = this.page + 'pins/';}
      const t: ProfileTitle | undefined = typeof row.title === 'object' ? row.title : undefined; title = this.clean(t?.text || t?.format);
      covers = (row.objects || []).map((p: ProfileRow): string => this.image(p.image_medium_url)).filter((v: string): boolean => !!v); count = this.info?.pinCount === undefined ? null : this.info.pinCount; updated = this.updated(this.info?.lastPinSaveTime);
    } else return undefined;
    if(!target || !title)return undefined;
    const sections: number | null = row.type === 'board' ? this.count(row.section_count) : null;
    const metadata: string = (count !== null ? count.toString() + PinmonyI18n.message("pm_pins_0a89904f") : '') +
      (sections !== null && Number.isInteger(sections) && sections > 0 ? (count !== null ? ' · ' : '') +
        (sections === 1 ? PinmonyI18n.message("pm_1_section_4d13c778") : sections.toString() + PinmonyI18n.message("pm_sections_68d526a8")) : '');
    return {mergeable:row.type === 'board' && row.owner?.id === this.info?.viewerId && !!row.access?.includes('write') && !!row.access?.includes('delete'),sortable:row.type === 'board',secret:row.type === 'board' && row.privacy === 'secret',protectedBoard:row.type === 'board' && row.privacy === 'protected',id:'profile-api-native-' + row.id,targetUrl:target,title:title,covers:covers.slice(0,3),coverAlternatives:coverAlternatives.length ? coverAlternatives : undefined,collaboratorAvatars:avatars,pinCount:metadata,updated:updated};
  }
  private async request(resource: string, options: ProfileOptions, source: string, revision: number): Promise<ProfileResponse> {
    const id: string = 'native_profile_' + (++this.sequence).toString(); this.requestId = id;
    const envelope: ProfileEnvelope = {options:options,context:{}};
    const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:this.page,url:this.origin + '/resource/' + resource + '/get/?source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),method:'GET',body:'',headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}};
    const reply = await this.ports.network().requestBusinessProfileRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.page,this.info?.userId || '',(): boolean => this.owned() && revision === this.revision,this.info?.viewerId || '',this.ports.visitor?.() === true);
    if(revision !== this.revision || !this.owned())throw new Error('cancelled'); if(reply.error || reply.status !== 200 || reply.body.length > 6000000)throw new Error('profile-request');
    const body: ProfileResponse = JSON.parse(reply.body) as ProfileResponse; const r: ProfileResource = body.resource_response;
    if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0)throw new Error('profile-response'); if(this.info?.viewerId && body.client_context?.user?.id && body.client_context.user.id !== this.info.viewerId)throw new Error('profile-viewer'); return body;
  }
  private cursor(body: ProfileResponse): string { const raw: string | undefined = body.resource_response.bookmark || body.resource?.options?.bookmarks?.[0]; if(raw !== undefined && (typeof raw !== 'string' || raw.length > 4096))throw new Error('cursor'); return raw || ''; }
  private async read(append: boolean, refresh: boolean): Promise<void> {
    const revision: number = this.revision, f: ProfileFeed = this.feed(), section: string = this.section, previous: string = append ? f.cursor : ''; this.busy = true; f.busy = true; f.error = ''; this.infoError = ''; this.apply();
    let readingUser: boolean = !this.info || refresh;
    const live = (): boolean => revision === this.revision && this.owned();
    try {
      const path: string = this.page.slice(this.origin.length), username: string = path.split('/')[1];
      if(readingUser) {
        this.identityVerified = false; this.apply();
        const response: ProfileResponse = await this.request('UserResource',{field_set_key:'profile',username:username},path,revision); if(!live())return;
        const u: ProfileUser = response.resource_response.data as ProfileUser; const viewer: string | undefined = response.client_context?.user?.id;
        // accountId is a local cache hash, not the numeric server ID. Server viewer evidence proves ownership.
        if(!u || u.type !== 'user' || typeof u.id !== 'string' || !/^\d{1,40}$/.test(u.id) || (!this.ports.visitor?.() && viewer !== u.id || typeof viewer !== 'string' || !/^\d{1,40}$/.test(viewer)) || this.clean(u.username,100).toLowerCase() !== username.toLowerCase())throw new Error('profile-owner');
        this.info = {cover:u.profile_cover?.source === 'image' ? this.image(u.profile_cover.images?.['1200x']?.url || u.profile_cover.images?.['750x']?.url || u.profile_cover.images?.['736x']?.url || u.profile_cover.images?.['originals']?.url) : '',contact:u.should_show_messaging === true,monthlyViews:this.count(u.profile_reach) ?? undefined,name:this.clean(u.full_name,160),handle:this.clean(u.username,100),avatar:this.image(u.image_large_url || u.image_medium_url || u.image_small_url),followers:this.count(u.follower_count),following:this.count(u.following_count),userId:u.id,viewerId:viewer,isOwn:viewer === u.id,followingUser:typeof u.explicitly_followed_by_me === 'boolean' ? u.explicitly_followed_by_me : null,blocked:u.blocked_by_me === true,business:u.is_partner === true,about:this.clean(u.about,2000),website:this.clean(u.website_url,2000),pinCount:this.count(u.pin_count),lastPinSaveTime:this.clean(u.last_pin_save_time,100)}; this.identityVerified = true; this.version++; readingUser = false; this.apply();
      }
      const info: ProfileInfo | undefined = this.info; if(!info || !this.identityVerified)throw new Error('profile-owner');
      if(!append)f.sort = this.boardSort;
      const sort: string = f.sort;
      // Sorted boards exclude the all-Pins story. A full refresh must fetch its
      // current presence and cover instead of retaining the previous snapshot.
      let refreshedStories: PinmonyBoard[] | undefined = undefined;
      if (!this.hubMode && refresh && !append && section === 'saved' && info.isOwn && sort) {
        const feed: ProfileResponse = await this.request('BoardsFeedResource',{field_set_key:'profile_grid_item',filter_stories:false,sort:'last_pinned_to',username:info.handle},path,revision);
        if (!live()) return;
        const rows: ProfileRow[] = feed.resource_response.data as ProfileRow[];
        if (!Array.isArray(rows) || rows.length > 500) throw new Error('profile-stories');
        refreshedStories = [];
        rows.forEach((row: ProfileRow): void => { if (row.type === 'story' && row.story_type === 'all_pins') { const story: PinmonyBoard | undefined = this.board(row); if (story) refreshedStories!.push(story); } });
      }
      if(this.hubMode) { await this.readHub(append,revision); if(this.hubMode === 'boards' && revision === this.revision && this.owned() && !append && (refresh || !this.unorganized.ready && !this.unorganized.error))await this.readUnorganized(false,true); return; }
      const options: ProfileOptions = section === 'saved' ? {field_set_key:'profile_grid_item',filter_stories:false,sort:info.isOwn && sort ? sort : 'last_pinned_to',username:info.handle} : {field_set_key:'profile_created_grid_item',exclude_add_pin_rep:true,is_own_profile_pins:info.isOwn,user_id:info.userId,username:info.handle}; if(append)options.bookmarks = [previous];
      if (section === 'saved' && info.isOwn && sort) {
        options.privacy_filter = 'all'; options.page_size = 25; options.group_by = 'mix_public_private';
        options.include_archived = false; options.filter_all_pins = true; options.add_fields = 'board.{meal_plan}';
      }
      const body: ProfileResponse = await this.request(section === 'saved' ? (info.isOwn && sort ? 'BoardsResource' : 'BoardsFeedResource') : 'UserActivityPinsResource',options,path + (section === 'created' ? '_created/' : ''),revision); if(!live())return;
      const rows: ProfileRow[] = body.resource_response.data as ProfileRow[]; if(!Array.isArray(rows) || rows.length > 500)throw new Error('profile-feed');
      const boards: PinmonyBoard[] = append ? f.boards.slice() : (refreshedStories !== undefined ? refreshedStories : section === 'saved' && info.isOwn && sort ? f.boards.filter((b: PinmonyBoard): boolean => b.targetUrl === this.page + 'pins/') : []), pins: PinmonyCreatedPin[] = append ? f.pins.slice() : []; let supported: number = 0;
      rows.forEach((r: ProfileRow): void => {if(section === 'saved') {const b: PinmonyBoard | undefined = this.board(r); if(b) {supported++; if(!boards.some((v: PinmonyBoard): boolean => v.id === b.id))boards.push(b);} else if(r?.type === 'story' && r.story_type === 'all_pins' && this.info?.pinCount === 0 && !r.objects?.length)supported++;} else {const p: PinmonyCreatedPin | undefined = this.pin(r); if(p) {supported++; if(!pins.some((v: PinmonyCreatedPin): boolean => v.id === p.id))pins.push(p);}}});
      if(rows.length && !supported)throw new Error('unsupported-feed'); const cursor: string = this.cursor(body);
      if(section === 'saved' && sort === 'alphabetical') {
        const stories: PinmonyBoard[] = boards.filter((b: PinmonyBoard): boolean => b.targetUrl === this.page + 'pins/');
        const ordered: PinmonyBoard[] = boards.filter((b: PinmonyBoard): boolean => b.targetUrl !== this.page + 'pins/');
        ordered.sort((a: PinmonyBoard,b: PinmonyBoard): number => a.title.toLocaleLowerCase().localeCompare(b.title.toLocaleLowerCase()));
        boards.splice(0,boards.length);stories.concat(ordered).forEach((board: PinmonyBoard): void => {boards.push(board);});
      }
      this.version++; f.boards = boards.slice(0,2000); f.pins = pins.slice(0,2000); f.cursor = cursor; f.ended = !cursor || cursor === '-end-' || cursor === previous || !rows.length; f.ready = true; if(boards.length >= 2000 || pins.length >= 2000)f.ended = true;
      PinmonyRuntimeLog.info('ProfileNativeTrace: committed section=' + section + ' append=' + append.toString() + ' count=' + (boards.length + pins.length).toString());
      if(info.isOwn && section === 'saved' && !append && (refresh || !this.unorganized.ready && !this.unorganized.error))await this.readUnorganized(false,true);
    } catch (_) { if(live()) {if(readingUser)this.infoError = PinmonyI18n.message("pm_unable_to_load_profile_please_retry_6dbb335a"); else f.error = PinmonyI18n.message("pm_unable_to_load_content_please_retry_95306b92");} }
    finally { if(revision === this.revision){this.busy = false; f.busy = false; this.requestId = ''; if(live())this.apply(); this.ports.settled(); if(this.refreshNeeded && live()){this.refreshNeeded = false; this.refresh();}} }
  }
  private async openSuggestion(id: string): Promise<void> {
    if(!this.bind() || !this.identityVerified || !this.info?.isOwn || this.busy || this.hubMode !== 'pins' || this.hubFavorite || this.hubCreated || this.attemptedSuggestions.has(id))return;
    const cluster: PinmonyBoard | undefined = this.suggestions.find((b: PinmonyBoard): boolean => b.id === id);
    if(!cluster)return;
    const selection: ProfileSuggestionSelection = new ProfileSuggestionSelection();selection.id = id;selection.title = cluster.title;selection.loading = true;
    this.suggestionSelection = selection;this.busy = true;this.apply();
    const revision: number = this.revision;
    const live = (): boolean => revision === this.revision && this.owned() && this.suggestionSelection === selection;
    try {
      let cursor: string = '';const seen: Set<string> = new Set<string>();
      for(let page: number = 0;page < 80;page++) {
        const options: ProfileOptions = {url:'/v3/users/profile/pins/cluster/' + id + '/feed/',data:{fields:['pin.id','pin.images[170x,136x136,236x,474x,736x,orig]']}};
        if(cursor)options.bookmarks = [cursor];
        const body: ProfileResponse = await this.request('ApiResource',options,this.page.slice(this.origin.length),revision);
        if(!live())return;
        const rows: ProfileRow[] = body.resource_response.data as ProfileRow[];
        if(body.resource_response.endpoint_name !== 'v3_get_user_profile_pins_cluster_feed' || !Array.isArray(rows) || rows.length > 500)throw new Error('cluster-feed');
        for(const row of rows) {
          if(row.type !== undefined && row.type !== 'pin')throw new Error('cluster-pin-type');
          const pin: PinmonyCreatedPin | undefined = this.pin({id:row.id,type:'pin',images:row.images});
          if(!pin)throw new Error('cluster-pin');pin.id = row.id;
          if(!selection.pins.some((p: PinmonyCreatedPin): boolean => p.id === pin.id))selection.pins.push(pin);
        }
        if(selection.pins.length > 2000)throw new Error('cluster-limit');
        const next: string = this.cursor(body);
        if(!next || next === '-end-') {selection.selectedIds = selection.pins.map((p: PinmonyCreatedPin): string => p.id);return;}
        if(!rows.length || seen.has(next))throw new Error('cluster-pagination');seen.add(next);cursor = next;
      }
      throw new Error('cluster-limit');
    } catch (_) {if(live()){selection.pins = [];selection.selectedIds = [];selection.error = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92');}}
    finally {if(live()){selection.loading = false;this.busy = false;this.requestId = '';this.apply();this.ports.settled();}}
  }
  private async createSuggestion(id: string): Promise<void> {
    if(!this.bind() || !this.identityVerified || !this.info?.isOwn || this.busy || this.hubMode !== 'pins' || this.hubFavorite || this.hubCreated || this.attemptedSuggestions.has(id))return;
    const cluster: PinmonyBoard | undefined = this.suggestions.find((b: PinmonyBoard): boolean => b.id === id);
    if(!cluster)return;
    const selection: ProfileSuggestionSelection | undefined = this.suggestionSelection;
    if(!selection || selection.id !== id || selection.loading || selection.error || !selection.selectedIds.length)return;
    const deselected: string[] = selection.pins.filter((p: PinmonyCreatedPin): boolean => !selection.selectedIds.includes(p.id)).map((p: PinmonyCreatedPin): string => p.id);
    const revision: number = this.revision; this.suggestionWriting = true; this.busy = true; this.hubFeed.busy = true; this.hubFeed.error = ''; this.attemptedSuggestions.add(id); this.apply();
    const live = (): boolean => this.owned() && revision === this.revision && this.info?.isOwn === true;
    try {
      const createEnvelope: ProfileSuggestionEnvelope = {options:{name:cluster.title,aux_data:{source:'create_pin_cluster_page'}},context:{}};
      const create: string = JSON.stringify(createEnvelope);
      const send = async (resource: string, payload: string): Promise<ProfileResponse> => {
        const job: PinmonyNetworkJob = {id:'native_profile_suggestion_' + (++this.sequence),epoch:this.generation,page:this.page,url:this.origin + '/resource/' + resource + '/',method:'POST',body:'source_url=' + encodeURIComponent(this.page.slice(this.origin.length)) + '&data=' + encodeURIComponent(payload),headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}};
        this.requestId = job.id;
        const reply = await this.ports.network().requestBusinessProfileSuggestion(job,(): PinmonyBusinessSessionContext => this.ports.session(),id,cluster.title,(): boolean => live(),selection.pins.map((p: PinmonyCreatedPin): string => p.id));
        if(!live() || reply.error || reply.status !== 200)throw new Error('suggestion-request');
        const result: ProfileResponse = JSON.parse(reply.body) as ProfileResponse;
        if(result.resource_response?.status !== 'success' || result.resource_response.code !== 0 || result.resource_response.error)throw new Error('suggestion-response');
        return result;
      };
      const created: ProfileResponse = await send('BoardResource/create',create);
      const board: ProfileRow = created.resource_response.data as ProfileRow;
      if(created.resource_response.endpoint_name !== 'v3_create_board' || board.type !== 'board' || !/^\d{1,40}$/.test(board.id) || board.name !== cluster.title || board.owner?.id !== this.info.userId || !board.access?.includes('write'))throw new Error('suggestion-board');
      const moveEnvelope: ProfileSuggestionEnvelope = {options:{url:'/v3/pins/cluster/' + id + '/bulk/move/',data:{board_id:board.id,deselected_pin_ids:deselected}},context:{}};
      const moved: ProfileResponse = await send('ApiResource/update',JSON.stringify(moveEnvelope));
      if(moved.resource_response.endpoint_name !== 'v3_move_cluster_pins' || moved.resource_response.data !== null)throw new Error('suggestion-move');
      if(live()) {this.suggestionSelection = undefined;this.hubFeeds.clear();this.suggestions = this.suggestions.filter((b: PinmonyBoard): boolean => b.id !== id);this.saved.ready = false;this.hubFeed.ready = false;}
    } catch (_) {if(live()){selection.uncertain = true;selection.error = PinmonyI18n.message('pm_profile_suggestion_unconfirmed');this.hubFeed.error = selection.error;}}
    finally {if(revision === this.revision)this.suggestionWriting = false;if(live()){this.busy = false;this.hubFeed.busy = false;this.requestId = '';this.apply();if(!this.hubFeed.error)await this.read(false,false);}}
  }
  private async readHub(append: boolean, revision: number): Promise<void> {
    const f: ProfileFeed = this.hubFeed, info: ProfileInfo = this.info!, mode: string = this.hubMode;
    const boardMode: boolean = ['boards','groups','secret'].includes(mode);
    let resource: string = 'ApiResource';
    let options: ProfileOptions = {url:'/v3/users/me/filtered/pins/',data:{flag_filters:[this.hubFavorite ? 'FAVORITED' : '',this.hubCreated ? 'CREATED_BY_ME' : ''].filter((v: string): boolean => !!v).join(','),fields:'pin.id,pin.type,pin.images[236x,474x,736x,orig],pin.grid_title,pin.title,pin.favorited_by_me'}};
    let source: string = this.page.slice(this.origin.length);
    if(boardMode) {
      resource = 'BoardsResource';
      options = mode === 'boards' ? {field_set_key:'profile_grid_item',filter_stories:false,sort:f.sort || 'last_pinned_to',username:info.handle,privacy_filter:'all',page_size:25,group_by:'mix_public_private',include_archived:false,filter_all_pins:true,add_fields:'board.{meal_plan}'} :
        {boardOrder:f.sort || 'last_pinned_to',filterStories:false,isOwnProfile:true,isRetrievalHub:true,isViewerProfile:true,mixPublicSecret:true,sort:f.sort || 'last_pinned_to',field_set_key:'profile_grid_item',filter_types:mode === 'groups' ? 2 : 3,privacyFilter:'all',add_fields:'board.{meal_plan}',username:info.handle};
    } else if(['collages','drafts'].includes(mode))options = {url:'/v3/users/me/shuffles/',data:{is_draft:mode === 'drafts',transform_to_pins:mode !== 'drafts',fields:mode === 'drafts' ? ['shuffle.id','shuffle.images','shuffle.updated_at'] : ['pin.access','pin.type','pin.id','pin.images','pin.description','pin.pinner','pin.shuffle()']}};
    if(mode === 'pins' && !this.hubFavorite && !this.hubCreated && !append) {
      this.suggestions = []; this.suggestionError = '';
      try {
        const suggestionBody: ProfileResponse = await this.request('ApiResource',{url:'/v3/users/profile/pins/clusters/',data:{exclude_quick_save_pins:true,max_cluster_limit:10}},this.page.slice(this.origin.length),revision);
        if(revision !== this.revision || !this.owned())return;
        if(suggestionBody.resource_response.endpoint_name !== 'v3_get_user_profile_pin_clusters')throw new Error('clusters-endpoint');
        const story: ProfileRow = suggestionBody.resource_response.data as ProfileRow;
        if(story.type !== 'story' || story.story_type !== 'user_organize_pin_groupings' || !Array.isArray(story.objects))throw new Error('clusters');
        for(const cluster of story.objects.slice(0,10)) {
          if(cluster.type !== 'pincluster' || !/^[A-Za-z0-9_-]{1,160}$/.test(cluster.id) || !cluster.names?.[0])continue;
          const covers: string[] = (cluster.thumbnails || []).map((t: Record<string,ProfileImage>): string => this.image(t['236x']?.url)).filter((v: string): boolean => !!v).slice(0,3);
          this.suggestions.push({id:cluster.id,title:this.clean(cluster.names[0],300),covers:covers,pinCount:String(this.count(cluster.pin_count) || 0),updated:''});
        }
      } catch (_) {if(revision === this.revision)this.suggestionError = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92');}
    }
    const previous: string = append ? f.cursor : ''; if(append)options.bookmarks = [previous];
    const body: ProfileResponse = await this.request(resource,options,source,revision);
    if(revision !== this.revision || !this.owned())return;
    const expected: string = resource === 'BoardsResource' ? mode === 'boards' ? 'v3_user_profile_boards_feed' : 'v3_get_user_filtered_board_feed' : resource === 'UserActivityPinsResource' ? 'v3_get_bizpro_feed' : ['collages','drafts'].includes(mode) ? 'v3_get_user_collage_drawer_homefeed_pins' : 'v3_get_user_filtered_pins_handler';
    if(body.resource_response.endpoint_name !== expected)throw new Error('hub-endpoint');
    const rows: ProfileRow[] = body.resource_response.data as ProfileRow[];
    if(!Array.isArray(rows) || rows.length > 500)throw new Error('hub-feed');
    const boards: PinmonyBoard[] = append ? f.boards.slice() : [], pins: PinmonyCreatedPin[] = append ? f.pins.slice() : [];
    for(const row of rows) {
      if(boardMode){const b: PinmonyBoard | undefined = this.board(row);if(!b)throw new Error('hub-board');if(!boards.some((v: PinmonyBoard): boolean => v.id === b.id))boards.push(b);}
      else {const p: PinmonyCreatedPin | undefined = mode === 'drafts' ? this.collageDraft(row) : this.pin(row);if(this.hubFavorite && p)p.favorite = true;if(!p)throw new Error(mode === 'drafts' ? 'hub-draft' : 'hub-pin');if(!pins.some((v: PinmonyCreatedPin): boolean => v.id === p.id))pins.push(p);}
    }
    if(boardMode && f.sort === 'alphabetical')boards.sort((a: PinmonyBoard,b: PinmonyBoard): number => a.title.toLocaleLowerCase().localeCompare(b.title.toLocaleLowerCase()));
    const cursor: string = this.cursor(body); f.boards = boards.slice(0,2000); f.pins = pins.slice(0,2000); f.cursor = cursor;
    f.ended = !cursor || cursor === '-end-' || cursor === previous || !rows.length || boards.length >= 2000 || pins.length >= 2000; f.ready = true; this.version++;
  }
  private async readUnorganized(append: boolean, nested: boolean = false): Promise<void> {
    if(!this.info?.isOwn || !this.identityVerified || append && this.unorganized.ended)return; const revision: number = this.revision, f: ProfileFeed = this.unorganized, previous: string = append ? f.cursor : ''; if(!nested)this.busy = true; f.busy = true; f.error = ''; this.apply();
    const live = (): boolean => revision === this.revision && this.owned();
    try {const options: ProfileOptions = {field_set_key:'mobile',redux_normalize_feed:true,userId:this.info.userId}; if(append)options.bookmarks = [previous]; const body: ProfileResponse = await this.request('BoardlessPinsResource',options,this.page.slice(this.origin.length),revision); if(!live())return;
      const rows: ProfileRow[] = body.resource_response.data as ProfileRow[]; if(!Array.isArray(rows) || rows.length > 500)throw new Error('unorganized-feed'); const pins: PinmonyCreatedPin[] = append ? f.pins.slice() : [];
      rows.forEach((r: ProfileRow): void => {const p: PinmonyCreatedPin | undefined = this.pin(r,true); if(!p)throw new Error('unorganized-owner'); if(!pins.some((v: PinmonyCreatedPin): boolean => v.id === p.id))pins.push(p);});
      const cursor: string = this.cursor(body); this.version++; f.pins = pins.slice(0,2000); f.cursor = cursor; f.ended = !cursor || cursor === '-end-' || cursor === previous || !rows.length || pins.length >= 2000; f.ready = true;
    } catch (_) {if(live())f.error = PinmonyI18n.message("pm_unable_to_load_unorganized_pins_please_retry_df900d1b");}
    finally {if(revision === this.revision){f.busy = false; if(!nested){this.busy = false; this.requestId = ''; if(live())this.apply(); this.ports.settled(); if(this.refreshNeeded && live()){this.refreshNeeded = false; this.refresh();}} }}
  }
}
