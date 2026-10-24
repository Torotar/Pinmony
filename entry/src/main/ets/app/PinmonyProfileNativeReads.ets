import { PinmonyI18n } from 'common_foundation';
import { PinmonyProfileStore, PinmonyProfileSnapshot, PinmonyProfileAction, PinmonyBoard, PinmonyCreatedPin } from 'feature_profile';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
export const PIN_NATIVE_PROFILE_READS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface ProfileImage { url?: string; width?: number; height?: number; }
interface ProfileCover { source?: string; images?: Record<string,ProfileImage>; }
interface ProfileUser { profile_cover?: ProfileCover; should_show_messaging?: boolean; profile_reach?: number; id: string; type: string; username: string; full_name?: string; image_large_url?: string; image_medium_url?: string; image_small_url?: string; follower_count?: number; following_count?: number; pin_count?: number; last_pin_save_time?: string; is_partner?: boolean; about?: string; website_url?: string; explicitly_followed_by_me?: boolean; blocked_by_me?: boolean; }
interface ProfileRow { privacy?: string; id: string; type: string; url?: string; name?: string; title?: string | ProfileTitle; grid_title?: string; images?: Record<string,ProfileImage | ProfileImage[]>; image_cover_hd_url?: string; image_cover_url?: string; image_medium_url?: string; pin_count?: number; section_count?: number; board_order_modified_at?: string; is_collaborative?: boolean; owner?: ProfileUser; collaborating_users?: ProfileUser[]; story_type?: string; action?: ProfileAction; objects?: ProfileRow[]; pinner?: ProfileUser; }
interface ProfileTitle { text?: string; format?: string; }
interface ProfileAction { url?: string; }
interface ProfileResource { status: string; code?: number; error?: Object; data: ProfileUser | ProfileRow[]; bookmark?: string; }
interface ProfileResponse { resource_response: ProfileResource; resource?: ProfileResourceOptions; client_context?: ProfileClient; }
interface ProfileResourceOptions { options?: ProfileOptions; }
interface ProfileClient { user?: ProfileUser; }
interface ProfileOptions { field_set_key: string; username?: string; filter_stories?: boolean; sort?: string; privacy_filter?: string; page_size?: number; group_by?: string; include_archived?: boolean; filter_all_pins?: boolean; add_fields?: string; exclude_add_pin_rep?: boolean; is_own_profile_pins?: boolean; user_id?: string; userId?: string; redux_normalize_feed?: boolean; bookmarks?: string[]; }
interface ProfileEnvelope { options: ProfileOptions; context: Record<string,string>; }
interface ProfileSortData { most_recent_board_sort_order?: string; orbac_subject_id?: string; show_all_pins?: boolean; }
interface ProfileVisibilityWrite { show_all_pins: boolean; surface_tag: string; }
interface ProfileVisibilityEnvelope { options: ProfileSortOptions | ProfileVisibilityWrite; context: Record<string,string>; }
interface ProfileSortOptions { url: string; data: ProfileSortData; }
interface ProfileSortEnvelope { options: ProfileSortOptions; context: Record<string,string>; }
interface ProfileSortResponse { resource_response?: ProfileSortResource; client_context?: ProfileClient; }
interface ProfileSortResource { status: string; code: number; endpoint_name: string; error?: Object; data: ProfileSortData | null; }
interface ProfileInfo { cover: string; contact: boolean; monthlyViews?: number; name: string; handle: string; avatar: string; followers: number | null; following: number | null; userId: string; viewerId: string; isOwn: boolean; followingUser: boolean | null; blocked: boolean; business: boolean; about: string; website: string; pinCount: number | null; lastPinSaveTime: string; }
class ProfileFeed {
  ready: boolean = false; busy: boolean = false; cursor: string = ''; ended: boolean = false; error: string = ''; scroll: number = 0;
  boards: PinmonyBoard[] = []; pins: PinmonyCreatedPin[] = [];
}
export interface PinmonyProfileNativeReadsPorts {
  store: () => PinmonyProfileStore; session: () => PinmonyBusinessSessionContext; page: () => string; selected: () => boolean; active: () => boolean;
  network: () => PinmonyNativeNetwork; settled: () => void; recordAddress: (address: string) => void;
  document: () => string; documentEpoch: () => number; visitor?: () => boolean;
}
interface ProfileRouteState { section: string; info?: ProfileInfo; infoError: string; identityVerified: boolean; saved: ProfileFeed; created: ProfileFeed; unorganized: ProfileFeed; }
// Own-profile reads belong to the business account, independently of the hidden document.
export class PinmonyProfileNativeReads {
  private readonly ports: PinmonyProfileNativeReadsPorts;
  private readonly store: PinmonyProfileStore;
  private account: string = ''; private origin: string = ''; private generation: number = -1; private page: string = '';
  private revision: number = 0; private version: number = 0; private sequence: number = 0; private requestId: string = ''; private busy: boolean = false;
  private bridgeEpoch: number = -1; private bridgeSession: number = -1; private adoptedVersion: number = -1; private invalidation: number = 0; private invalidationEpoch: number = -1; private refreshNeeded: boolean = false;
  private bridgeRejection: string = '';
  private readonly routes: Map<string,ProfileRouteState> = new Map<string,ProfileRouteState>();
  private section: string = 'saved'; private info: ProfileInfo | undefined = undefined; private infoError: string = ''; private identityVerified: boolean = false;
  private boardSortPending: string = ''; private boardSort: string = ''; private sortBusy: boolean = false; private sortError: string = '';
  private showAllPins: boolean | undefined = undefined; private visibilityBusy: boolean = false; private visibilityError: string = '';
  private saved: ProfileFeed = new ProfileFeed(); private created: ProfileFeed = new ProfileFeed(); private unorganized: ProfileFeed = new ProfileFeed();
  constructor(ports: PinmonyProfileNativeReadsPorts) { this.ports = ports; this.store = ports.store(); }
  eligible(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return PIN_NATIVE_PROFILE_READS_ENABLED && this.ports.selected() && s.authenticated && !!s.accountId && this.ports.page().startsWith(s.origin + '/') && /^\/[A-Za-z0-9_]+\/$/.test(this.ports.page().slice(s.origin.length)); }
  private bound(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.eligible() && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.page === this.ports.page(); }
  owned(): boolean { return this.bound() && this.ports.active(); }
  private feed(): ProfileFeed { return this.section === 'created' ? this.created : this.saved; }
  private bind(): boolean {
    if(!this.eligible() || !this.ports.active())return false; const s: PinmonyBusinessSessionContext = this.ports.session();
    if(!this.bound()) {
      const sameAccount: boolean = this.account === s.accountId && this.generation === s.generation && this.origin === s.origin;
      if(sameAccount) {
        this.pause();
        if(this.page)this.routes.set(this.page,{section:this.section,info:this.info,infoError:this.infoError,identityVerified:this.identityVerified,saved:this.saved,created:this.created,unorganized:this.unorganized});
        while(this.routes.size > 12)this.routes.delete(this.routes.keys().next().value);
        const retained: ProfileRouteState | undefined = this.routes.get(this.ports.page());
        this.section = retained?.section || 'saved';this.info = retained?.info;this.infoError = retained?.infoError || '';this.identityVerified = retained?.identityVerified === true;
        this.saved = retained?.saved || new ProfileFeed();this.created = retained?.created || new ProfileFeed();this.unorganized = retained?.unorganized || new ProfileFeed();
      }else this.reset();
      this.account = s.accountId; this.origin = s.origin; this.generation = s.generation; this.page = this.ports.page();
    }
    return true;
  }
  pause(): void { if(this.store.profile?.profileUrl === this.page && this.store.profile.section === this.section)this.feed().scroll = this.store.profileScrollOffset; this.revision++; this.version++; if(this.requestId)this.ports.network().cancel(this.requestId); this.requestId = ''; this.busy = false; this.sortBusy = false; this.visibilityBusy = false; this.saved.busy = false; this.created.busy = false; this.unorganized.busy = false; this.store.profileNativeReadsReady = false; this.store.profileActionsReady = false; this.store.profileSessionReady = false; this.store.profilePullRefreshing = false; this.bridgeEpoch = -1; this.bridgeSession = -1; this.adoptedVersion = -1; this.refreshNeeded = false; }
  reset(): void { this.showAllPins = undefined; this.visibilityError = ''; this.boardSort = ''; this.sortError = ''; this.routes.clear(); this.pause(); if(this.account) {this.store.profileCache.clear(); if(this.store.profile?.profileUrl === this.page)this.store.profile = undefined;} this.account = ''; this.origin = ''; this.generation = -1; this.page = ''; this.section = 'saved'; this.info = undefined; this.identityVerified = false; this.infoError = ''; this.invalidation = 0; this.invalidationEpoch = -1; this.saved = new ProfileFeed(); this.created = new ProfileFeed(); this.unorganized = new ProfileFeed(); }
  async select(section: string): Promise<boolean> { if(!['saved','created'].includes(section) || !this.bind())return false; if(section !== this.section) {this.pause(); this.section = section; this.store.profileScrollOffset = this.feed().scroll; this.store.profileSwitching = false; this.ports.recordAddress(this.page + (section === 'created' ? '_created/' : ''));} this.apply(); await this.demand(); return true; }
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
    const snapshot: PinmonyProfileSnapshot = { kind:'state',nativeVersion:this.version,session:this.store.profileSession,profileUrl:this.page,section:this.section,
      monthlyViews:i?.monthlyViews,displayName:i?.name || '',handle:i?.handle || '',avatarUrl:i?.avatar || '',coverUrl:i?.cover || '',business:i?.business,isOwn:i?.isOwn,about:i?.about || '',website:i?.website || '',
      followers:i?.followers !== undefined && i.followers !== null ? i.followers.toString() + PinmonyI18n.message("pm_followers_7c3af361") : '',following:i?.following !== undefined && i.following !== null ? i.following.toString() + PinmonyI18n.message("pm_following_52ff9a6f") : '',
      actions:actions,boards:f.boards.slice(),createdPins:f.pins.slice(),boardSort:i?.isOwn ? this.boardSort : '',boardSortBusy:this.sortBusy,boardSortPending:this.boardSortPending,boardSortError:this.sortError,
      showAllPins:i?.isOwn ? this.showAllPins : undefined,visibilityBusy:this.visibilityBusy,visibilityError:this.visibilityError,
      contentLoading:!f.ready && this.busy,contentLoadingMore:f.ready && f.busy,contentError:f.error,contentHasMore:!f.ended && !!f.cursor,
      unorganizedPins:this.section === 'saved' ? this.unorganized.pins.slice() : [],unorganizedLoading:this.section === 'saved' && this.unorganized.busy,
      unorganizedError:this.unorganized.error,unorganizedHasMore:!this.unorganized.ended && !!this.unorganized.cursor,unorganizedFeedback:previous?.unorganizedFeedback || '',organize:previous?.organize };
    this.store.profile = snapshot; this.store.profileUrl = this.page; this.store.profileNativeReadsReady = this.identityVerified && !!i && f.ready; this.store.profileLoading = !i && this.busy; this.store.profileError = this.infoError;
    if(i && f.ready && !this.busy && !f.error)this.store.profileCache.put(snapshot,this.store.profileScrollOffset);
  }
  async demand(): Promise<void> { if(!this.bind())return; this.apply(); if(this.busy || this.infoError || this.feed().error)return; if(!this.info || !this.feed().ready)await this.read(false,false); else if(this.info?.isOwn && this.section === 'saved' && !this.unorganized.ready && !this.unorganized.error)await this.readUnorganized(false); }
  async sortBoards(value: string): Promise<void> {
    if (!this.bind() || !this.identityVerified || !this.info?.isOwn || this.section !== 'saved' || this.busy || this.sortBusy) return;
    if (value && (!['alphabetical','last_pinned_to','custom'].includes(value) || !this.boardSort || !!this.sortError)) return;
    if (value && value === this.boardSort) return;
    const revision: number = this.revision, page: string = this.page, previous: string = this.boardSort || 'last_pinned_to';
    const live = (): boolean => revision === this.revision && this.owned() && this.page === page && this.info?.isOwn === true;
    this.busy = true; this.sortBusy = true; this.boardSortPending = value || this.boardSort || 'alphabetical'; this.sortError = ''; this.apply();
    let reload: boolean = false;
    try {
      const options: ProfileSortOptions = { url: value ? '/v3/users/me/metadata/' : '/v3/users/' + this.info.handle + '/metadata/', data: value ? {most_recent_board_sort_order:value,orbac_subject_id:''} : {} };
      const envelope: ProfileSortEnvelope = {options:options,context:{}}, source: string = page.slice(this.origin.length);
      const form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
      const id: string = 'native_profile_sort_' + (++this.sequence).toString(); this.requestId = id;
      const job: PinmonyNetworkJob = {id:id,epoch:this.generation,page:page,url:this.origin + '/resource/ApiResource/' + (value ? 'create/' : 'get/?' + form),method:value ? 'POST' : 'GET',body:value ? form : '',headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}};
      const reply = await this.ports.network().requestBusinessProfileSort(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.info.userId,this.info.viewerId,live);
      if (!live()) return;
      PinmonyRuntimeLog.info('ProfileSortTrace: phase=response write=' + (!!value).toString() + ' status=' + reply.status.toString() + ' transportError=' + (!!reply.error).toString());
      if (reply.error || reply.status !== 200 || !reply.body || reply.body.length > 100000) throw new Error('sort-request');
      const response: ProfileSortResponse = JSON.parse(reply.body) as ProfileSortResponse, r: ProfileSortResource | undefined = response.resource_response;
      if (!r || r.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== (value ? 'v3_user_metdata_set' : 'v3_user_metdata_get') || response.client_context?.user?.id && response.client_context.user.id !== this.info.viewerId) throw new Error('sort-response');
      const confirmed: string = value || r.data?.most_recent_board_sort_order || '';
      if (!['alphabetical','last_pinned_to','custom'].includes(confirmed) || value && r.data !== null) throw new Error('sort-value');
      reload = !this.boardSort || previous !== confirmed; this.boardSort = confirmed; this.store.profileCache.clear();
      if (reload) { this.saved.ready = false; this.saved.cursor = ''; this.saved.ended = false; this.saved.error = ''; }
    } catch (_) { if (live()) this.sortError = value ? 'pm_profile_sort_save_error' : 'pm_profile_sort_load_error'; }
    finally { if (revision === this.revision) { if (live() && reload) await this.read(false,false); if (revision === this.revision) { this.busy = false; this.sortBusy = false; this.boardSortPending = ''; this.requestId = ''; if (live()) this.apply(); this.ports.settled(); } } }
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

  async refresh(pull: boolean = false): Promise<void> { if(!this.bind() || this.busy)return; this.store.profileCache.clear(); this.version++; this.store.profilePullRefreshing = pull; this.store.profileActionsReady = false; this.store.profileSessionReady = false; await this.read(false,true); }
  async more(): Promise<void> { if(!this.bind() || !this.identityVerified || this.busy || this.feed().ended || !this.feed().cursor)return; await this.read(true,false); }
  async unorganizedAction(action: string): Promise<boolean> { if(!['morePins','retryPins'].includes(action) || !this.bind() || !this.info?.isOwn)return false; if(this.busy)return true; await this.readUnorganized(action === 'morePins' && this.unorganized.ready && !!this.unorganized.cursor); return true; }
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
    return {id:unorganized ? row.id : 'profile-api-native-' + row.id,targetUrl:this.origin + '/pin/' + row.id + '/',title:this.clean(row.grid_title || (typeof row.title === 'string' ? row.title : '')),imageUrl:this.image(img?.url),imageWidth:img?.width || 0,imageHeight:img?.height || 0};
  }
  private board(row: ProfileRow): PinmonyBoard | undefined {
    if(!row || typeof row.id !== 'string' || row.id.length > 100)return undefined;
    let target: string = '', title: string = '', covers: string[] = [], count: number | null = null, updated: string = ''; const avatars: string[] = [];
    if(row.type === 'board') {
      if(!/^\d{1,40}$/.test(row.id))return undefined; target = this.target(row.url); title = this.clean(row.name); count = this.count(row.pin_count); updated = this.updated(row.board_order_modified_at);
      const imgs: ProfileImage[] = row.images?.['236x'] as ProfileImage[] || []; if(Array.isArray(imgs))covers = imgs.map((im: ProfileImage): string => this.image(im.url)).filter((v: string): boolean => !!v);
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
    return {secret:row.type === 'board' && row.privacy === 'secret',id:'profile-api-native-' + row.id,targetUrl:target,title:title,covers:covers.slice(0,3),collaboratorAvatars:avatars,pinCount:metadata,updated:updated};
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
      // Sorted boards exclude the all-Pins story. A full refresh must fetch its
      // current presence and cover instead of retaining the previous snapshot.
      let refreshedStories: PinmonyBoard[] | undefined = undefined;
      if (refresh && !append && section === 'saved' && info.isOwn && this.boardSort) {
        const feed: ProfileResponse = await this.request('BoardsFeedResource',{field_set_key:'profile_grid_item',filter_stories:false,sort:'last_pinned_to',username:info.handle},path,revision);
        if (!live()) return;
        const rows: ProfileRow[] = feed.resource_response.data as ProfileRow[];
        if (!Array.isArray(rows) || rows.length > 500) throw new Error('profile-stories');
        refreshedStories = [];
        rows.forEach((row: ProfileRow): void => { if (row.type === 'story' && row.story_type === 'all_pins') { const story: PinmonyBoard | undefined = this.board(row); if (story) refreshedStories!.push(story); } });
      }
      const options: ProfileOptions = section === 'saved' ? {field_set_key:'profile_grid_item',filter_stories:false,sort:info.isOwn && this.boardSort ? this.boardSort : 'last_pinned_to',username:info.handle} : {field_set_key:'profile_created_grid_item',exclude_add_pin_rep:true,is_own_profile_pins:info.isOwn,user_id:info.userId,username:info.handle}; if(append)options.bookmarks = [previous];
      if (section === 'saved' && info.isOwn && this.boardSort) {
        options.privacy_filter = 'all'; options.page_size = 25; options.group_by = 'mix_public_private';
        options.include_archived = false; options.filter_all_pins = true; options.add_fields = 'board.{meal_plan}';
      }
      const body: ProfileResponse = await this.request(section === 'saved' ? (info.isOwn && this.boardSort ? 'BoardsResource' : 'BoardsFeedResource') : 'UserActivityPinsResource',options,path + (section === 'created' ? '_created/' : ''),revision); if(!live())return;
      const rows: ProfileRow[] = body.resource_response.data as ProfileRow[]; if(!Array.isArray(rows) || rows.length > 500)throw new Error('profile-feed');
      const boards: PinmonyBoard[] = append ? f.boards.slice() : (refreshedStories !== undefined ? refreshedStories : section === 'saved' && info.isOwn && this.boardSort ? f.boards.filter((b: PinmonyBoard): boolean => b.targetUrl === this.page + 'pins/') : []), pins: PinmonyCreatedPin[] = append ? f.pins.slice() : []; let supported: number = 0;
      rows.forEach((r: ProfileRow): void => {if(section === 'saved') {const b: PinmonyBoard | undefined = this.board(r); if(b) {supported++; if(!boards.some((v: PinmonyBoard): boolean => v.id === b.id))boards.push(b);} else if(r?.type === 'story' && r.story_type === 'all_pins' && this.info?.pinCount === 0 && !r.objects?.length)supported++;} else {const p: PinmonyCreatedPin | undefined = this.pin(r); if(p) {supported++; if(!pins.some((v: PinmonyCreatedPin): boolean => v.id === p.id))pins.push(p);}}});
      if(rows.length && !supported)throw new Error('unsupported-feed'); const cursor: string = this.cursor(body);
      this.version++; f.boards = boards.slice(0,2000); f.pins = pins.slice(0,2000); f.cursor = cursor; f.ended = !cursor || cursor === '-end-' || cursor === previous || !rows.length; f.ready = true; if(boards.length >= 2000 || pins.length >= 2000)f.ended = true;
      PinmonyRuntimeLog.info('ProfileNativeTrace: committed section=' + section + ' append=' + append.toString() + ' count=' + (boards.length + pins.length).toString());
      if(info.isOwn && section === 'saved' && !append && (refresh || !this.unorganized.ready && !this.unorganized.error))await this.readUnorganized(false,true);
    } catch (_) { if(live()) {if(readingUser)this.infoError = PinmonyI18n.message("pm_unable_to_load_profile_please_retry_6dbb335a"); else f.error = PinmonyI18n.message("pm_unable_to_load_content_please_retry_95306b92");} }
    finally { if(revision === this.revision){this.busy = false; f.busy = false; this.requestId = ''; if(live())this.apply(); this.ports.settled(); if(this.refreshNeeded && live()){this.refreshNeeded = false; this.refresh();}} }
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
