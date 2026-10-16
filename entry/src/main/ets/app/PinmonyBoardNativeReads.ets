import { PinmonyBoardSectionNativeWrites, BoardSectionWriteIdentity } from './PinmonyBoardSectionNativeWrites';
import { PinmonyBoardFollowNativeWrites, PinmonyBoardFollowNativeWritesPorts } from './PinmonyBoardFollowNativeWrites';
import { PinmonyBoardStore, PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardFlow, PinmonyBoardSection, PinmonyBoardTarget, PinmonyBoardCollaborators, PinmonyBoardCollaborator } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PIN_BUSINESS_PIN_READ_ENABLED } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBoardContentNativeWrites, PinmonyBoardContentIdentity } from './PinmonyBoardContentNativeWrites';
import { PinmonyBoardManagementNativeWrites, PinmonyBoardManagementIdentity } from './PinmonyBoardManagementNativeWrites';
import { PinmonyBoardPinNativeWrites, PinmonyBoardPinWriteIdentity } from './PinmonyBoardPinNativeWrites';
import { PinmonyBoardCollaboratorsNativeWrites, PinmonyBoardWriteIdentity } from './PinmonyBoardCollaboratorsNativeWrites';

export const PIN_NATIVE_BOARD_READS_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface BoardUser { type?: string; id: string; username: string; full_name?: string; pin_count?: number;
  image_medium_url?: string; image_small_url?: string; image_large_url?: string; verified_identity?: BoardVerified; }
interface BoardVerified { verified: boolean; }
interface BoardFeatured { curator?: BoardUser; board_tag?: string | number; is_sponsored_content?: boolean; board_subtitle?: string; }
interface BoardHeader { large_image_url?: string; small_image_url?: string; }
interface BoardData { type: string; id: string; url: string; name: string; owner: BoardUser; pin_count?: number;
  privacy?: string; description?: string; section_count?: number; is_collaborative?: boolean; collaborated_by_me?: boolean;
  followed_by_me?: boolean; collaborating_users?: BoardUser[]; collaborator_count?: number; access?: string[]; featured_board_metadata?: BoardFeatured; header?: BoardHeader; isOwn?: boolean; allow_homefeed_recommendations?: boolean; collaborator_invites_enabled?: boolean; collaborator_requests_enabled?: boolean; collaborator_permissions_setting?: number; }
interface BoardImage { url: string; width: number; height: number; }
interface BoardDimensions { width: number; height: number; }
interface BoardVideo { duration?: number; }
interface BoardVideos { video_list?: Record<string, BoardVideo>; }
interface BoardPinData { type: string; id: string; images?: Record<string, BoardImage>; image_large_url?: string;
  image_medium_url?: string; image_large_size_pixels?: BoardDimensions; image_medium_size_pixels?: BoardDimensions;
  grid_title?: string; title?: string; pinner?: BoardUser; board?: BoardPinOwner; videos?: BoardVideos; tracking_params?: string; }
interface BoardPinOwner { id: string; section_count?: number; }
interface BoardCreatedSection { id: string; title: string; pin_count?: number | null; board: BoardPinOwner; }
interface BoardToolData { type: string; tool: number; text: string; }
interface BoardSectionData { slug?: string; board?: BoardPinOwner; type: string; id: string; title: string; pin_count: number | null; preview_pins?: BoardPinData[]; }
interface BoardResource { endpoint_name?: string; status: string; code?: number; error?: Object; data: BoardData | BoardUser | BoardSectionData | BoardToolData[] | BoardPinData[] | BoardSectionData[] | BoardTargetData[] | BoardInviteData[] | BoardUser[]; bookmark?: string; }
interface BoardResponse { resource_response: BoardResource; client_context?: BoardContext; resource?: BoardRequestResource; }
interface BoardContext { user?: BoardUser; }
interface BoardRequestResource { options?: BoardReadOptions; }
interface BoardReadOptions { url?: string; data?: BoardSectionFields; field_set_key?: string; is_mobile_fork?: boolean; username?: string; slug?: string; board_id?: string;
  add_vase?: boolean; filter_section_pins?: boolean; is_react?: boolean; prepend?: boolean; page_size?: number;
  redux_normalize_feed?: boolean; gated?: boolean; is_own_profile_pins?: boolean; section_id?: string; bookmarks?: string[]; id?: string; type?: string; __track__referrer?: number; privacy_filter?: string; sort?: string; filter_stories?: boolean; group_by?: string; include_archived?: boolean; filter_all_pins?: boolean; status_filters?: string; include_inactive?: boolean; suggestion_type?: string; board?: string; }
interface BoardTargetData { type: string; id: string; name?: string; image_cover_url?: string; archived_by_me_at?: string; archived_by_me?: boolean; access?: string[] | string; }
interface BoardInviteData { board: BoardPinOwner; invited_user: BoardUser; status: string; }
interface BoardSourcePin { id: string; tracking_params?: string; }
interface BoardAuxiliary { flowOwned: boolean; sourcePins: BoardSourcePin[]; selectedIds: string[]; targetBookmark: string; collaborators?: PinmonyBoardCollaborators; }
interface BoardPreparedContext { session: number; page: string; version: number; }
interface BoardPermissionValue { permission: number; invites: boolean; }
interface BoardReadEnvelope { options: BoardReadOptions; context: Record<string, string>; }
interface BoardSectionFields { fields: string[]; }
interface BoardReadAction { action: string; value?: string | string[]; }
interface BoardBridgeState extends PinmonyBoardDetail { contextEpoch?: number; nativeVersion?: number; nativeReload?: number; nativeSectionsReload?: number; }
export interface PinmonyBoardNativeReadsPorts {
  store: () => PinmonyBoardStore; session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  active: () => boolean; document: () => string; documentEpoch: () => number;
  bridge: (value: string) => void; committed: () => void; install: (script: string) => void;
  openPin: (pin: PinmonyBoardPin, board: PinmonyBoardDetail) => void;
  renamed?: (previous: string, next: string) => void; exited?: (action: string) => void;
  prepareDocument?: () => Promise<boolean>; runScript?: (script: string) => Promise<string>; jsonText?: (value: string) => string; feedback?: (message: string) => void; invalidateProfile?: () => void; movePage?: () => string; clearMovePage?: () => void;
}

// Business GETs belong to the selected native board and account, never to a Web document.
export class PinmonyBoardNativeReads {
  private readonly ports: PinmonyBoardNativeReadsPorts;
  private readonly store: PinmonyBoardStore;
  private page: string = ''; private origin: string = ''; private account: string = ''; private generation: number = -1;
  private revision: number = 0; private sequence: number = 0; private version: number = 0; private recoveryVersion: number = 0;
  private board: BoardData | undefined = undefined; private viewer: string = ''; private verified: boolean = false;
  private pins: PinmonyBoardPin[] = []; private sections: PinmonyBoardSection[] = [];
  private cursor: string = ''; private ended: boolean = false; private ready: boolean = false; private busy: boolean = false;
  private attempted: boolean = false; private error: string = ''; private refreshing: boolean = false;
  private sectionsError: string = ''; private sectionsBusy: boolean = false; private sectionsReady: boolean = false; private sectionsQueued: boolean = false;
  private sectionEpoch: number = 0; private sectionCursor: string = ''; private flow: PinmonyBoardFlow | undefined = undefined;
  private bridgeEpoch: number = -1; private bridgeSession: number = 0; private adoptedVersion: number = -1;
  private reload: number = 0; private sectionsReload: number = 0; private refreshQueued: boolean = false;
  private readonly requests: Set<string> = new Set<string>();
  private preparing: boolean = false; private flowEpoch: number = 0; private collabEpoch: number = 0;
  private targetCursor: string = ''; private selectedIds: string[] = []; private sources: BoardSourcePin[] = [];
  private readonly flowRequests: Set<string> = new Set<string>(); private readonly collabRequests: Set<string> = new Set<string>();
  private readonly sectionRequests: Set<string> = new Set<string>();
  private readonly contentWrites: PinmonyBoardContentNativeWrites;
  private sectionDraftPins: string[] = [];
  private readonly sectionWrites: PinmonyBoardSectionNativeWrites;
  private sectionSource: PinmonyBoardFlow | undefined = undefined;
  private sectionComplete: boolean = false;
  private sectionEnumerationValid: boolean = false;
  private readonly cancelledCards: Map<string,PinmonyBoardPin> = new Map<string,PinmonyBoardPin>();
  private readonly cancelledPositions: Map<string,number> = new Map<string,number>();
  private cancelledDisplayCount: number | undefined = undefined;
  private readonly managementWrites: PinmonyBoardManagementNativeWrites;
  private sectionIdeaPath: string = '';
  private readonly pinWrites: PinmonyBoardPinNativeWrites;
  private readonly collaboratorWrites: PinmonyBoardCollaboratorsNativeWrites;
  private readonly followWrites: PinmonyBoardFollowNativeWrites;
  constructor(ports: PinmonyBoardNativeReadsPorts) {
    this.followWrites = new PinmonyBoardFollowNativeWrites({
      session: ports.session, network: ports.network, changed: (): void => this.apply(),
      feedback: (value: string): void => { ports.feedback?.(value); },
      confirmed: (id: string, following: boolean): void => {
        if (this.board?.id === id) this.board.followed_by_me = following;
        ports.invalidateProfile?.();
      }
    } as PinmonyBoardFollowNativeWritesPorts);
    this.ports = ports; this.store = ports.store();
    this.sectionWrites = new PinmonyBoardSectionNativeWrites({
      state: (): PinmonyBoardFlow | undefined => this.flow,
      identity: (): BoardSectionWriteIdentity | undefined => this.sectionWriteIdentity(),
      session: (): PinmonyBusinessSessionContext => this.ports.session(),network: (): PinmonyNativeNetwork => this.ports.network(),
      changed: (flow: PinmonyBoardFlow): void => {this.flow = flow;this.syncAuxiliary();},
      confirmed: (action: string,title?: string): void => this.sectionWriteConfirmed(action,title)
    });
    this.contentWrites = new PinmonyBoardContentNativeWrites({
      state: (): PinmonyBoardFlow | undefined => this.store.boardDetail?.flow,
      page: (): string => this.store.boardDetail?.pageKey || '',
      identity: (): PinmonyBoardContentIdentity | undefined => this.current() && this.verified && this.ready && this.board && !this.collection() ?
        {page:this.page,boardId:this.board.id,ownerId:this.board.owner.id,viewerId:this.viewer,canContribute:this.contributes(),intent:this.flowEpoch,
          loadedIds:(this.flow?.phase === 'section' ? this.flow.pins : this.sectionSource?.pins || this.pins).filter((p: PinmonyBoardPin): boolean => !this.cancelledCards.has(p.id)).map((p: PinmonyBoardPin): string => p.id)} : undefined,
      session: (): PinmonyBusinessSessionContext => this.ports.session(),network: (): PinmonyNativeNetwork => this.ports.network(),
      changed: (flow: PinmonyBoardFlow): void => {const unknown: boolean = flow.uncertain && !this.store.boardDetail?.flow?.uncertain;this.flow = flow;if(this.store.boardDetail)this.store.boardDetail.flow = flow;this.syncAuxiliary();if(unknown && this.ports.invalidateProfile)this.ports.invalidateProfile();},
      confirmed: (action: string, value: string, data: string): void => this.contentConfirmed(action,value,data)
    });
    this.managementWrites = new PinmonyBoardManagementNativeWrites({
      state: (): PinmonyBoardFlow | undefined => this.store.boardDetail?.flow,
      page: (): string => this.store.boardDetail?.pageKey || '',
      identity: (): PinmonyBoardManagementIdentity | undefined => this.current() && this.verified && this.ready && this.board && !this.collection() ?
        {page:this.page,boardId:this.board.id,ownerId:this.board.owner.id,ownerUsername:this.board.owner.username,viewerId:this.viewer,
          member:this.board.collaborated_by_me === true,followed:this.board.followed_by_me !== false,intent:this.flowEpoch} : undefined,
      session: (): PinmonyBusinessSessionContext => this.ports.session(),network: (): PinmonyNativeNetwork => this.ports.network(),
      changed: (flow: PinmonyBoardFlow): void => {const unknown: boolean = flow.uncertain && !this.store.boardDetail?.flow?.uncertain;this.flow = flow;if(this.store.boardDetail)this.store.boardDetail.flow = flow;this.syncAuxiliary();if(unknown && this.ports.invalidateProfile)this.ports.invalidateProfile();},
      confirmed: (action: string, data: string, next: string): void => this.managementConfirmed(action,data,next)
    });
    this.pinWrites = new PinmonyBoardPinNativeWrites({
      state: (): PinmonyBoardFlow | undefined => this.store.boardDetail?.flow,
      page: (): string => this.store.boardDetail?.pageKey || '',
      identity: (): PinmonyBoardPinWriteIdentity | undefined => this.current() && this.verified && this.ready && this.board && !this.collection() ?
        {page:this.page,boardId:this.board.id,viewerId:this.viewer,intent:this.flowEpoch,canContribute:this.contributes(),recommendationPath:this.flow?.phase === 'ideas' && this.flow.sectionId ? this.sectionIdeaPath : undefined,loadedIds:this.pins.map((pin: PinmonyBoardPin): string => pin.id),selectedIds:this.selectedIds.slice(),sources:this.sources.slice()} : undefined,
      session: (): PinmonyBusinessSessionContext => this.ports.session(),network: (): PinmonyNativeNetwork => this.ports.network(),
      changed: (flow: PinmonyBoardFlow): void => {const unknown: boolean = flow.uncertain && !this.store.boardDetail?.flow?.uncertain;this.flow = flow;if(this.store.boardDetail)this.store.boardDetail.flow = flow;this.syncAuxiliary();if(unknown && this.ports.invalidateProfile)this.ports.invalidateProfile();},
      confirmed: (action: string, ids: string[], copy: string): void => this.pinWriteConfirmed(action,ids,copy)
    });
    this.collaboratorWrites = new PinmonyBoardCollaboratorsNativeWrites({
      state: (): PinmonyBoardCollaborators | undefined => this.store.collaborators,
      identity: (): PinmonyBoardWriteIdentity | undefined => this.current() && this.verified && this.ready && this.board && !this.collection() ?
        {page:this.page,boardId:this.board.id,ownerId:this.board.owner.id,viewerId:this.viewer,member:this.board.collaborated_by_me === true} : undefined,
      session: (): PinmonyBusinessSessionContext => this.ports.session(), network: (): PinmonyNativeNetwork => this.ports.network(),
      changed: (state: PinmonyBoardCollaborators): void => {this.store.collaborators = state;this.syncAuxiliary();},
      confirmed: (state: PinmonyBoardCollaborators): void => {
        if(this.board){this.board.collaborator_permissions_setting = state.permission;this.board.collaborator_invites_enabled = state.invites;}
        if(this.flow?.phase === 'edit')this.flow.invites = state.invites;
        if(this.store.boardDetail?.flow?.phase === 'edit')this.store.boardDetail.flow.invites = state.invites;
      },
      feedback: (message: string): void => {if(this.ports.feedback)this.ports.feedback(message);}
    });
  }
  eligible(): boolean { return PIN_NATIVE_BOARD_READS_ENABLED && this.ports.active(); }
  pause(): void {
    if(!PIN_NATIVE_BOARD_READS_ENABLED)return;
    this.followWrites.pause();
    this.sectionWrites.pause();this.contentWrites.pause();this.managementWrites.pause();this.pinWrites.pause();this.collaboratorWrites.pause();
    this.preparing = false; this.revision++; this.version++; this.sectionEpoch++; this.flowEpoch++; this.collabEpoch++;
    this.requests.forEach((id: string): void => this.ports.network().cancel(id)); this.requests.clear(); this.sectionRequests.clear(); this.flowRequests.clear(); this.collabRequests.clear();
    this.busy = false; this.sectionsBusy = false; this.sectionsQueued = false; this.refreshing = false; if(!this.ready)this.attempted = false; if(this.flow?.phase === 'section')this.flow = undefined;
    else if(this.flow?.loading){this.flow.loading = false;this.flow.error = '读取已中断，请重试';}
    if(this.store.collaborators?.loading){this.store.collaborators.loading = false;this.store.collaborators.error = '读取已中断，请重试';}
    this.refreshQueued = false;
    if(this.store.boardDetail) {this.store.boardDetail.session = 0; this.store.boardDetail.loadingMore = false; this.store.boardDetail.refreshing = false; if(this.store.boardDetail.flow?.phase === 'section')this.store.boardDetail.flow = undefined;}
  }
  reset(): void { this.pause();this.cancelledCards.clear();this.cancelledPositions.clear();this.cancelledDisplayCount = undefined; this.sectionSource = undefined;this.sectionComplete = false;this.page = ''; this.account = ''; this.generation = -1; this.board = undefined; this.viewer = ''; this.verified = false; this.pins = []; this.sections = []; this.ready = false; this.attempted = false; this.error = ''; this.sectionsReady = false; this.sectionsError = ''; this.cursor = ''; this.ended = false; this.targetCursor = ''; this.selectedIds = []; this.sources = []; this.flow = undefined; this.store.collaborators = undefined; }
  private bind(): boolean {
    const s: PinmonyBusinessSessionContext = this.ports.session(), page: string = this.store.boardDetail?.pageKey || '';
    if(!this.eligible() || !s.authenticated || !s.accountId || !page.startsWith(s.origin + '/') ||
      !/^\/[^/?#]+\/[^/?#]+\/$/.test(page.slice(s.origin.length)))return false;
    if(this.page !== page || this.account !== s.accountId || this.generation !== s.generation || this.origin !== s.origin || this.store.boardDetail?.nativeVersion === undefined) {
      const accountChanged: boolean = s.accountId !== this.account || s.generation !== this.generation || s.origin !== this.origin;
      this.reset(); if (accountChanged) this.followWrites.reset(); this.page = page; this.origin = s.origin; this.account = s.accountId; this.generation = s.generation;
      this.bridgeEpoch = -1; this.bridgeSession = 0; this.adoptedVersion = -1; this.reload = 0; this.sectionsReload = 0;
    }
    return true;
  }
  private current(): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return this.eligible() && s.authenticated && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.store.boardDetail?.pageKey === this.page; }
  private collection(): boolean { return this.page.endsWith('/pins/'); }
  private clean(value: string | undefined, max: number = 300): string { return typeof value === 'string' ? value.trim().slice(0,max) : ''; }
  private digits(value: string | undefined): boolean { return typeof value === 'string' && /^\d{1,30}$/.test(value); }
  private image(value: string | undefined): string { return typeof value === 'string' && value.length <= 2048 && /^https:\/\/(?:i|s)\.pinimg\.com\//.test(value) ? value : ''; }
  private count(value: number | undefined): number | undefined { return Number.isFinite(value) && (value || 0) >= 0 ? value : undefined; }
  private emptyFlow(): PinmonyBoardFlow { return {phase:'',loading:false,busy:false,uncertain:false,error:'',description:'',privacy:'public',recommend:false,invites:false,requests:false,pins:[],targets:[],saved:[],hasMore:false}; }
  apply(): void {
    if(!this.current())return;
    const b: BoardData | undefined = this.board, existing: PinmonyBoardDetail | undefined = this.store.boardDetail;
    const owner: BoardUser | undefined = b?.owner, own: boolean = !!b && !!this.viewer && owner?.id === this.viewer;
    const member: boolean = b?.collaborated_by_me === true, curator: BoardUser | undefined = b?.featured_board_metadata?.curator;
    const display: BoardUser | undefined = curator || owner, showOwner: boolean = !!b && !own && !member;
    const members: BoardUser[] = b?.is_collaborative ? [owner!].concat(b.collaborating_users || []).filter((u: BoardUser,index: number,all: BoardUser[]): boolean => !!u && this.digits(u.id) && all.findIndex((v: BoardUser): boolean => !!v && v.id === u.id) === index).slice(0,100) : [];
    const peer: BoardUser | undefined = members.length === 2 && members.some((u: BoardUser): boolean => u.id === this.viewer) ? members.find((u: BoardUser): boolean => u.id !== this.viewer) : undefined;
    const count: number | undefined = this.count(b?.pin_count), tag: string | number | undefined = b?.featured_board_metadata?.board_tag;
    const snapshot: PinmonyBoardDetail = {kind:'state',nativeWriteIntent:this.flowEpoch,nativeAccountGeneration:this.generation,nativeVersion:this.version,nativeRecoveryVersion:this.recoveryVersion,nativeReadsReady:this.verified && this.ready,
      session:existing?.session || 0,pageKey:this.page,boardId:b?.id || '',title:this.clean(b?.name) || existing?.title || '图板',
      pinCount:count === undefined ? existing?.pinCount || '' : count.toString() + ' 张 Pin 图',
      privacy:!this.collection() && ['public','secret'].includes(b?.privacy || '') ? b?.privacy : undefined,
      ownerName:curator || showOwner ? this.clean(display?.full_name || display?.username) : '',ownerAvatar:curator || showOwner ? this.image(display?.image_medium_url || display?.image_small_url) : '',
      ownerUrl:display && /^[A-Za-z0-9_]+$/.test(display.username) ? this.origin + '/' + display.username + '/' : '',
      memberAvatar:this.image(owner?.image_medium_url || owner?.image_small_url),collaboratorAvatars:members.slice(0,6).map((u: BoardUser): string => this.image(u.image_medium_url || u.image_small_url)).filter((url: string): boolean => !!url),
      chatMemberCount:Math.max(members.length,this.count(b?.collaborator_count) === undefined ? 0 : (b?.collaborator_count || 0) + 1),
      chatPeer:peer ? {id:peer.id,name:this.clean(peer.full_name || peer.username),avatar:this.image(peer.image_medium_url || peer.image_small_url),username:this.clean(peer.username)} : undefined,
      following:typeof b?.followed_by_me === 'boolean' ? b.followed_by_me : undefined,followBusy:this.followWrites.busy(b?.id || ''),
      canFollow:this.verified && this.ready && !own && !this.collection() && typeof b?.followed_by_me === 'boolean' && !this.followWrites.pending() && !this.followWrites.locked(b.id),
      editable:this.verified && own && !this.collection(),collaborator:member,canContribute:this.verified && !this.collection() && (own || member && !!b?.access?.includes('write')),
      featured:!!b?.featured_board_metadata,featuredCreator:tag !== undefined && /^\d+$/.test(tag.toString()) && Number.isInteger(Number(tag)) && Number(tag) >= 0,
      sponsored:b?.featured_board_metadata?.is_sponsored_content === true,ownerVerified:display?.verified_identity?.verified === true,
      sectionCount:Number.isInteger(b?.section_count) && (b?.section_count || 0) > 0 ? b?.section_count : 0,
      sections:this.sections.slice(),sectionsError:this.sectionsError,subtitle:this.clean(b?.featured_board_metadata?.board_subtitle),description:this.clean(b?.description,2000),headerImage:this.image(b?.header?.large_image_url || b?.header?.small_image_url),
      loading:!this.ready && this.busy,loadingMore:this.ready && this.busy && !this.refreshing,refreshing:this.refreshing,
      ready:this.ready,error:this.error,hasMore:!this.ended && !!this.cursor,pins:this.pins.slice(),flow:this.flow || existing?.flow,revision:existing?.revision || 0};
    this.store.boardDetail = snapshot;
    if(this.ready)this.ports.committed();
  }
  async demand(): Promise<void> { if(!this.bind())return; this.apply(); if(this.busy || this.error)return; if(!this.ready && !this.attempted)await this.read(false,false); else if(this.verified && !this.sectionsReady && !this.sectionsBusy && !this.sectionsError)await this.readSections(); }
  async refresh(): Promise<void> { if(!this.bind() || this.busy || this.store.boardDetail?.flow?.busy || this.store.collaborators?.busy)return; if(this.flow?.uncertain && !this.flow.phase)this.flow = this.emptyFlow(); this.pause(); await this.read(false,true); }
  async more(): Promise<void> { if(this.store.boardDetail?.flow?.busy || !this.bind() || !this.verified || !this.ready || this.busy || this.ended || !this.cursor)return; await this.read(true,false); }
  async handle(method: string, encoded: string = ''): Promise<boolean> {
    if(!PIN_NATIVE_BOARD_READS_ENABLED)return false;
    if(['refresh','retry','more','open'].includes(method)) {
      if(!this.bind())return true;
      if(method === 'more')await this.more(); else if(method === 'refresh' || method === 'retry')await this.refresh();
      else {const snapshot: PinmonyBoardDetail | undefined = this.store.boardDetail; if(snapshot?.flow?.busy || snapshot?.flow?.phase && snapshot.flow.phase !== 'section')return true; const p: PinmonyBoardPin | undefined = (snapshot?.flow?.phase === 'section' ? snapshot.flow.pins : this.pins.concat(this.sections.reduce((all: PinmonyBoardPin[],s: PinmonyBoardSection): PinmonyBoardPin[] => all.concat(s.pins || []),[]))).find((v: PinmonyBoardPin): boolean => v.id === encoded);
        if(p && snapshot && this.verified && this.ready) {this.ports.openPin(p,snapshot); this.pause();}}
      return true;
    }
    if(method !== 'flow')return false;
    let a: BoardReadAction; try {a = JSON.parse(encoded) as BoardReadAction;} catch (_) {return true;}
    if(a.action === 'sectionCreateSelected' && this.flow?.phase === 'targets') {
      if(!this.bind() || this.flow.busy || this.flow.loading || this.flow.uncertain || typeof a.value !== 'string' || !this.selectedIds.length)return true;
      this.flow.error = '';this.syncAuxiliary();this.sectionDraftPins = this.selectedIds.slice();
      const error: string = await this.contentWrites.submit('section',a.value,(): boolean => this.current(),this.sectionDraftPins);
      if(error && this.flow?.phase === 'targets'){this.flow.error = error;this.syncAuxiliary();}return true;
    }
    if(a.action === 'sectionCreate' && this.flow?.phase === 'sectionSelect') {
      if(!this.bind() || this.flow.busy || this.flow.uncertain || !Array.isArray(a.value) || !a.value.every((id): boolean => typeof id === 'string'))return true;
      this.flow.error = '';this.syncAuxiliary();
      const ids: string[] = a.value as string[], title: string = this.flow.sectionTitle || '';
      this.sectionDraftPins = ids.slice();
      const error: string = await this.contentWrites.submit('section',title,(): boolean => this.current(),ids);
      if(error && this.flow?.phase === 'sectionSelect'){this.flow.error = error;this.syncAuxiliary();}return true;
    }
    if(a.action === 'sectionSingleMove') {
      if(!this.bind() || this.board?.owner.id !== this.viewer || this.flow?.phase !== 'section' || typeof a.value !== 'string' || !this.flow.pins.some((pin: PinmonyBoardPin): boolean => pin.id === a.value))return true;
      const id: string = a.value;
      await this.sectionAction({action:'sectionOrganize'});
      if(this.store.boardDetail?.flow?.phase === 'select' && this.sectionSource && !this.flow.error && !this.flow.loading && !this.flow.busy)await this.auxiliaryAction({action:'targets',value:[id]});
      return true;
    }
    if(['sectionEdit','sectionOrganize','sectionReturn','sectionDelete','sectionRename','sectionIdeas','sectionTargetOpen','sectionTargetBack'].includes(a.action) || a.action === 'move' && this.sectionSource) {
      await this.sectionAction(a);return true;
    }
    const section: boolean = this.store.boardDetail?.flow?.phase === 'section';
    if(a.action === 'section' || a.action === 'sectionsRetry' || section && ['close','sectionMore','retry'].includes(a.action)) {
      if(!this.bind() || !this.verified)return true;
      if(a.action === 'sectionsRetry')await this.readSections(true);
      else if(a.action === 'close') {this.sectionSource = undefined;this.cancelSection(); this.version++; this.flow = this.emptyFlow(); if(this.store.boardDetail)this.store.boardDetail.flow = undefined; this.apply(); this.ports.install(this.installScript());}
      else await this.readSection(a.action === 'section' && typeof a.value === 'string' ? a.value : this.flow?.sectionId || '',a.action === 'sectionMore');
      return true;
    }
    const phase: string = this.store.boardDetail?.flow?.phase || '';
    if(['ideas','select','targets','targetsMore','edit','archiveConfirm'].includes(a.action) || ['ideas','targets','edit'].includes(phase) && a.action === 'retry' || a.action === 'close') {
      await this.auxiliaryAction(a);return true;
    }
    if(a.action === 'saveParentIdea') {
      if(this.bind() && this.board?.owner.id === this.viewer && this.flow?.phase === 'ideas' && this.flow.sectionId && typeof a.value === 'string') await this.pinWrites.submit('save',a.value);
      return true;
    }
    if(a.action === 'save' && this.flow?.sectionId)return true;
    if(a.action === 'save' || a.action === 'move' || a.action === 'createTarget'){if(this.bind() && typeof a.value === 'string')await this.pinWrites.submit(a.action,a.value);return true;}
    if(a.action === 'followToggle') {
      if(this.bind() && this.verified && this.ready && this.board && this.board.owner.id !== this.viewer && !this.collection()) {
        const revision: number = this.revision, page: string = this.page;
        await this.followWrites.submit({id:this.board.id,boardId:this.board.id,kind:'board',following:this.board.followed_by_me,targetUrl:this.page,
          title:this.board.name || '',subtitle:'',imageUrl:'',imageWidth:0,imageHeight:0,enabled:true},this.viewer,
          (): boolean => this.current() && this.revision === revision && this.page === page);
      }
      return true;
    }
    if(['editSave','archive','delete','leave','unfollow'].includes(a.action)){if(this.bind()){if(!this.store.boardDetail?.flow){this.flow = this.emptyFlow();this.apply();}await this.managementWrites.submit(encoded);}return true;}
    return false;
  }
  contentReady(): boolean {
    return this.bind() && this.verified && this.ready && this.contributes() && !this.busy && !this.store.collaborators?.busy &&
      !this.store.boardDetail?.flow?.busy && !this.store.boardDetail?.flow?.loading && !this.store.boardDetail?.flow?.uncertain && !this.store.boardDetail?.flow?.phase;
  }
  async createSection(name: string, current: () => boolean): Promise<string> {
    if(!this.contentReady())return '图板尚未就绪，请关闭面板后重试';
    if(!this.flow){this.flow = this.emptyFlow();this.apply();}
    return this.contentWrites.submit('section',name,current);
  }
  beginSectionSelection(name: string): string {
    if(!this.contentReady() || !name.trim() || name.trim().length > 100)return '图板尚未就绪或区块名称无效';
    this.cancelFlow();this.flow = this.emptyFlow();this.flow.phase = 'sectionSelect';this.flow.sectionTitle = name.trim();
    this.sectionDraftPins = [];
    this.apply();return '';
  }
  async cancelSavedPin(id: string, current: () => boolean): Promise<string> {
    const sectionReady: boolean = this.bind() && this.verified && this.ready && this.board?.owner.id === this.viewer && this.flow?.phase === 'section' && !this.busy && !this.flow.busy && !this.flow.loading && !this.flow.uncertain && !this.flow.error && this.flow.pins.some((pin: PinmonyBoardPin): boolean => pin.id === id);
    if((!this.contentReady() && !sectionReady) || this.cancelledCards.has(id))return '收藏校验失败或已取消，未执行取消收藏';
    if(!this.flow){this.flow = this.emptyFlow();this.apply();}
    return this.contentWrites.submit('cancel',id,current);
  }
  private contentConfirmed(action: string, value: string, raw: string): void {
    if(!this.current() || !this.board)return;
    const openCreated: boolean = action === 'section' && this.flow?.phase === 'sectionSelect';
    const sectionFlow: PinmonyBoardFlow | undefined = action === 'cancel' && this.flow?.phase === 'section' ? JSON.parse(JSON.stringify(this.flow)) as PinmonyBoardFlow : undefined;
    this.pause();this.flow = sectionFlow || this.emptyFlow();
    if(this.ports.invalidateProfile)this.ports.invalidateProfile();
    if(action === 'section') {
      const data: BoardCreatedSection = JSON.parse(raw) as BoardCreatedSection;
      if(this.sectionDraftPins.length)this.pins = this.pins.filter((pin: PinmonyBoardPin): boolean => !this.sectionDraftPins.includes(pin.id));
      this.sectionDraftPins = [];this.selectedIds = [];this.sectionSource = undefined;
      if(this.ports.feedback)this.ports.feedback(data.title + '图板区块已添加！');
      if(!this.sections.some((section: PinmonyBoardSection): boolean => section.id === data.id))this.sections.push({id:data.id,title:data.title,
        pinCount:this.count(data.pin_count === null ? undefined : data.pin_count),images:[],pins:[]});
      this.board.section_count = this.count(data.board.section_count) === undefined ? Math.max(this.sections.length,(this.board.section_count || 0) + 1) : data.board.section_count;
      this.sectionsReady = false;this.sectionsError = '';this.syncAuxiliary();this.readSections(true);if(openCreated)this.readSection(data.id,false);
    }else {
      const pin: PinmonyBoardPin | undefined = (sectionFlow?.pins || this.pins).find((p: PinmonyBoardPin): boolean => p.id === value);
      if(pin){pin.cancelled = true;this.cancelledCards.set(value,pin);this.cancelledPositions.set(value,this.pins.indexOf(pin));}
      if(this.cancelledDisplayCount === undefined)this.cancelledDisplayCount = this.count(this.board.pin_count);
      this.syncAuxiliary();
    }
  }
  private managementConfirmed(action: string, raw: string, next: string): void {
    if(!this.current() || !this.board)return;
    const old: BoardData = this.board, previous: string = this.page;
    this.pause();this.flow = this.emptyFlow();
    if(this.ports.invalidateProfile)this.ports.invalidateProfile();
    if(action === 'editSave') {
      const b: BoardData = JSON.parse(raw) as BoardData;
      b.owner = {id:b.owner.id,username:b.owner.username || old.owner.username,full_name:b.owner.full_name || old.owner.full_name,
        image_medium_url:b.owner.image_medium_url || old.owner.image_medium_url,image_small_url:b.owner.image_small_url || old.owner.image_small_url,image_large_url:b.owner.image_large_url || old.owner.image_large_url};
      if(b.collaborated_by_me === undefined)b.collaborated_by_me = old.collaborated_by_me;
      if(b.is_collaborative === undefined)b.is_collaborative = old.is_collaborative;
      if(b.collaborating_users === undefined)b.collaborating_users = old.collaborating_users;
      if(b.collaborator_count === undefined)b.collaborator_count = old.collaborator_count;
      if(b.followed_by_me === undefined)b.followed_by_me = old.followed_by_me;
      if(b.pin_count === undefined)b.pin_count = old.pin_count;
      this.board = b;this.page = next;
      if(this.store.boardDetail){this.store.boardDetail.pageKey = next;this.store.boardDetail.session = 0;}
      if(next !== previous && this.ports.renamed)this.ports.renamed(previous,next);
    }else if(action === 'archive')this.flow.phase = 'archived';
    else if(action === 'unfollow'){this.board.followed_by_me = false;if(this.ports.feedback)this.ports.feedback('已取消关注');}
    else {
      this.pins = [];this.sections = [];this.ended = true;this.cursor = '';
      if(action === 'leave')this.board.collaborated_by_me = false;
      this.syncAuxiliary();if(this.ports.exited)this.ports.exited(action);return;
    }
    this.syncAuxiliary();
    if(action !== 'archive')this.read(false,true);
  }
  private pinWriteConfirmed(action: string, ids: string[], copy: string): void {
    if(!this.current() || !this.board)return;
    if(action === 'createTarget'){if(this.ports.invalidateProfile)this.ports.invalidateProfile();this.syncAuxiliary();return;}
    if(action === 'move' && this.ports.movePage?.() === this.page)this.ports.clearMovePage?.();
    if(action === 'save') {
      try {const data: BoardPinData = JSON.parse(copy) as BoardPinData;const pin: PinmonyBoardPin = this.mapPin(data);if(!this.pins.some((p: PinmonyBoardPin): boolean => p.id === pin.id))this.pins.unshift(pin);}catch (_) {}
      if(this.count(this.board.pin_count) !== undefined)this.board.pin_count = (this.board.pin_count || 0) + 1;
      if(this.cancelledDisplayCount !== undefined)this.cancelledDisplayCount++;
    }else if(action === 'unsave') {
      this.pins = this.pins.filter((pin: PinmonyBoardPin): boolean => pin.id !== copy);
      if(this.count(this.board.pin_count) !== undefined)this.board.pin_count = Math.max(0,(this.board.pin_count || 0) - 1);
      if(this.cancelledDisplayCount !== undefined)this.cancelledDisplayCount = Math.max(0,this.cancelledDisplayCount - 1);
    }else {
      this.pins = this.pins.filter((pin: PinmonyBoardPin): boolean => !ids.includes(pin.id));
      this.sections = [];
      if(this.count(this.board.pin_count) !== undefined)this.board.pin_count = Math.max(0,(this.board.pin_count || 0) - ids.length);
      if(this.cancelledDisplayCount !== undefined)this.cancelledDisplayCount = Math.max(0,this.cancelledDisplayCount - ids.length);
      this.flow = this.emptyFlow();this.selectedIds = [];this.targetCursor = '';this.sources = [];
    }
    if(this.ports.invalidateProfile)this.ports.invalidateProfile();
    this.syncAuxiliary();
    if((action === 'save' || action === 'unsave') && this.flow?.phase === 'ideas' && this.flow.sectionId)return;
    // Cancel every older read before revalidating, so a late feed cannot restore moved Pins.
    this.pause();this.read(false,true);
  }
  private auxiliarySnapshot(): BoardAuxiliary { return {flowOwned:!!this.flow,sourcePins:this.sources.slice(),selectedIds:this.selectedIds.slice(),targetBookmark:this.targetCursor,collaborators:this.store.collaborators}; }
  private cancelFlow(): void {this.flowEpoch++;this.flowRequests.forEach((id: string): void => this.ports.network().cancel(id));this.flowRequests.clear();}
  private contributes(): boolean {return this.verified && !this.collection() && !!this.board && (this.board.owner.id === this.viewer || this.board.collaborated_by_me === true && !!this.board.access?.includes('write'));}
  private participates(): boolean {return this.verified && !this.collection() && !!this.board && (this.board.owner.id === this.viewer || this.board.collaborated_by_me === true);}
  private syncAuxiliary(): void {this.version++;this.apply();this.ports.install(this.installScript());}
  private sectionWriteIdentity(): BoardSectionWriteIdentity | undefined {
    const source: PinmonyBoardFlow | undefined = this.sectionSource || this.flow;
    if(!this.current() || !this.verified || !this.board || this.board.owner.id !== this.viewer || !source?.sectionId || !this.sections.some((s: PinmonyBoardSection): boolean => s.id === source.sectionId))return undefined;
    return {page:this.page,board:this.board.id,section:source.sectionId,viewer:this.viewer,owner:this.board.owner.id,intent:this.flowEpoch,
      allIds:source.pins.map((p: PinmonyBoardPin): string => p.id),selectedIds:this.selectedIds.slice(),complete:this.sectionComplete,
      targets:(this.flow?.targets || []).filter((t: PinmonyBoardTarget): boolean => t.enabled).map((t: PinmonyBoardTarget): string => t.id).concat(this.flow?.targetBoardId && this.flow.targets.some((t: PinmonyBoardTarget): boolean => t.id === this.flow?.targetBoardId && t.enabled) ? (this.flow.targetSections || []).map((s: PinmonyBoardSection): string => 'section:' + this.flow!.targetBoardId + ':' + s.id) : [])};
  }
  private async sectionAction(a: BoardReadAction): Promise<void> {
    if(!this.bind() || !this.verified || !this.board || this.board.owner.id !== this.viewer || !this.flow || this.flow.busy || this.flow.uncertain)return;
    if(a.action === 'sectionReturn' && this.sectionSource){this.cancelFlow();this.flow = this.sectionSource;this.flow.phase = 'section';this.sectionSource = undefined;this.selectedIds = [];this.syncAuxiliary();return;}
    if(a.action === 'sectionTargetBack' && this.flow.phase === 'targets'){this.cancelFlow();this.flow.targetBoardId = undefined;this.flow.targetSections = undefined;this.flow.loading = false;this.flow.error = '';this.syncAuxiliary();return;}
    if(this.flow.loading)return;
    if(a.action === 'sectionTargetOpen' && typeof a.value === 'string'){await this.readTargetSections(a.value);return;}
    const f: PinmonyBoardFlow = this.flow;
    if(a.action === 'sectionIdeas'){await this.readSectionIdeas();return;}
    if(a.action === 'sectionRename' && typeof a.value === 'string'){if(a.value === f.sectionTitle){await this.sectionAction({action:'sectionReturn'});return;}await this.sectionWrites.submit('rename',a.value);return;}
    if(a.action === 'sectionDelete'){await this.sectionWrites.submit('delete');return;}
    if(a.action === 'move' && typeof a.value === 'string'){await this.sectionWrites.submit('move',a.value);return;}
    if(f.phase !== 'section' || !f.sectionId)return;
    if(a.action === 'sectionOrganize') {
      while(this.flow === f && f.hasMore && !f.error && f.pins.length < 500)await this.readSection(f.sectionId,true);
      if(!this.current() || this.flow !== f || f.error)return;
      const known: PinmonyBoardSection | undefined = this.sections.find((s: PinmonyBoardSection): boolean => s.id === f.sectionId);
      this.sectionComplete = this.sectionEnumerationValid && !f.hasMore && (!this.sectionCursor || this.sectionCursor === '-end-') && (known?.pinCount === undefined || known.pinCount === f.pins.length);
      if(!this.sectionComplete){f.error = '区块内容尚未完整读取，暂不能安全整理';this.syncAuxiliary();return;}
    }
    this.sectionSource = JSON.parse(JSON.stringify(f)) as PinmonyBoardFlow;this.cancelFlow();
    f.phase = a.action === 'sectionEdit' ? 'sectionEdit' : 'select';this.selectedIds = [];this.syncAuxiliary();
  }
  private sectionWriteConfirmed(action: string, renamed?: string): void {
    if(!this.current() || !this.board)return;
    const source: PinmonyBoardFlow | undefined = this.sectionSource || this.flow, id: string = source?.sectionId || '', title: string = source?.sectionTitle || '';
    if(action === 'rename' && source && renamed){this.pause();source.sectionTitle = renamed;source.phase = 'section';source.busy = false;source.error = '';this.flow = source;this.sectionSource = undefined;const section: PinmonyBoardSection | undefined = this.sections.find((s: PinmonyBoardSection): boolean => s.id === id);if(section)section.title = renamed;this.ports.invalidateProfile?.();this.syncAuxiliary();this.readSections(true);this.ports.feedback?.('图板区块名称已更新');return;}
    this.pause();this.sectionSource = undefined;this.selectedIds = [];this.flow = this.emptyFlow();
    if(this.ports.invalidateProfile)this.ports.invalidateProfile();
    if(action === 'delete'){this.sections = this.sections.filter((s: PinmonyBoardSection): boolean => s.id !== id);if(this.ports.feedback)this.ports.feedback(title + '图板区块已删除');}
    else if(this.ports.feedback)this.ports.feedback('已移动所选 Pin 图');
    this.sectionsReady = false;this.syncAuxiliary();this.readSections(true);
    if(action === 'move')this.readSection(id,false);else this.read(false,true);
  }
  private async auxiliaryAction(a: BoardReadAction): Promise<void> {
    if(!this.bind() || this.store.boardDetail?.flow?.busy)return;
    const old: PinmonyBoardFlow | undefined = this.store.boardDetail?.flow;
    if(this.ports.movePage?.() === this.page && a.action === 'select')a.action = 'close';
    if(a.action === 'close') {
      if(this.ports.movePage?.() === this.page)this.ports.clearMovePage?.();
      const recover: boolean = old?.uncertain === true || old?.phase === 'archived';this.cancelFlow();this.cancelSection();this.flow = this.emptyFlow();this.sectionSource = undefined;this.targetCursor = '';this.selectedIds = [];this.sources = [];this.syncAuxiliary();if(recover)await this.refresh();return;
    }
    if(!this.verified || !this.ready || old?.uncertain)return;
    if(old?.loading && (a.action === old.phase || a.action === 'retry'))return;
    if(a.action === 'select' || a.action === 'targets' || a.action === 'targetsMore' || a.action === 'ideas') {if(!this.contributes())return;}
    else if(!this.participates())return;
    if(a.action === 'select' || a.action === 'archiveConfirm') {this.cancelFlow();this.flow = this.emptyFlow();this.flow.phase = a.action === 'select' ? 'select' : 'archive';if(a.action === 'select' && this.sectionSource){this.flow.sectionId = this.sectionSource.sectionId;this.flow.sectionTitle = this.sectionSource.sectionTitle;this.flow.pins = this.sectionSource.pins.slice();}this.syncAuxiliary();return;}
    if(a.action === 'targets') {
      const ids: string[] | undefined = Array.isArray(a.value) ? a.value : undefined;
      if(!ids || !ids.length || ids.length > 500 || !ids.every((id: string,index: number): boolean => this.digits(id) && ids.indexOf(id) === index && (this.sectionSource?.pins || this.pins).some((p: PinmonyBoardPin): boolean => p.id === id)))return;
      this.selectedIds = ids.slice();this.targetCursor = '';await this.readAuxiliary('targets',false);return;
    }
    if(a.action === 'targetsMore') {if(old?.phase === 'targets' && !old.targetBoardId)await this.readAuxiliary('targets',true);return;}
    if(a.action === 'retry' && old?.phase === 'targets' && old.targetBoardId){await this.readTargetSections(old.targetBoardId);return;}
    if(a.action === 'retry' && old?.phase === 'ideas' && old.sectionId && this.sectionSource){this.cancelFlow();this.flow = this.sectionSource;this.flow.phase = 'section';this.sectionSource = undefined;await this.readSectionIdeas();return;}
    const phase: string = a.action === 'retry' ? old?.phase || '' : a.action;
    if(['ideas','targets','edit'].includes(phase))await this.readAuxiliary(phase,a.action === 'retry' && phase === 'targets' && !!this.targetCursor);
  }
  private async readAuxiliary(phase: string, append: boolean): Promise<void> {
    if(!this.current() || !this.board || this.store.boardDetail?.flow?.busy || append && (this.flow?.loading || !this.flow?.hasMore && !this.flow?.error))return;
    this.cancelFlow();const epoch: number = this.flowEpoch, revision: number = this.revision, board: BoardData = this.board;
    if(!append){this.flow = this.emptyFlow();if(this.sectionSource && phase === 'targets'){this.flow.sectionId = this.sectionSource.sectionId;this.flow.sectionTitle = this.sectionSource.sectionTitle;this.flow.pins = this.sectionSource.pins.slice();}if(phase === 'ideas')this.sources = [];}
    const f: PinmonyBoardFlow | undefined = this.flow;if(!f)return;f.phase = phase;f.loading = true;f.error = '';this.syncAuxiliary();
    const live = (): boolean => this.current() && revision === this.revision && epoch === this.flowEpoch && this.flow === f;
    try {
      let name: string = 'BoardResource', o: BoardReadOptions = {board_id:board.id,field_set_key:'edit'};
      if(phase === 'ideas'){name = 'BoardContentRecommendationResource';o = {id:board.id,type:'board',__track__referrer:23};}
      else if(phase === 'targets'){name = 'BoardsResource';o = {privacy_filter:'all',sort:'custom',field_set_key:'profile_grid_item',filter_stories:true,username:board.owner.username,page_size:25,group_by:'mix_public_private',include_archived:true,filter_all_pins:false};if(append)o.bookmarks = [this.targetCursor];}
      const body: BoardResponse = await this.request(name,o,revision,-1,true,live);
      if(phase === 'ideas') {
        const rows: BoardPinData[] = body.resource_response.data as BoardPinData[];if(!Array.isArray(rows) || rows.length > 500)throw new Error('ideas');
        const pins: PinmonyBoardPin[] = [], sources: BoardSourcePin[] = [];rows.forEach((p: BoardPinData): void => {let pin: PinmonyBoardPin;try {pin = this.mapPin(p);}catch (_) {return;}if(!pins.some((old: PinmonyBoardPin): boolean => old.id === pin.id)){pins.push(pin);sources.push({id:pin.id,tracking_params:typeof p.tracking_params === 'string' && p.tracking_params.length <= 16384 ? p.tracking_params : undefined});}});if(rows.some((p: BoardPinData): boolean => p?.type === 'pin') && !pins.length)throw new Error('unsupported-ideas');f.pins = pins;this.sources = sources;f.saved = this.pinWrites.savedIds();
      } else if(phase === 'targets') {
        const rows: BoardTargetData[] = body.resource_response.data as BoardTargetData[];if(!Array.isArray(rows) || rows.length > 500)throw new Error('targets');
        const targets: PinmonyBoardTarget[] = append ? f.targets.slice() : [];
        rows.forEach((b: BoardTargetData): void => {if(!b || b.type !== 'board' || !this.digits(b.id))throw new Error('target');const access: string[] = Array.isArray(b.access) ? b.access : typeof b.access === 'string' ? b.access.split(' ') : [];if(!targets.some((t: PinmonyBoardTarget): boolean => t.id === b.id))targets.push({id:b.id,title:this.clean(b.name),imageUrl:this.image(b.image_cover_url),enabled:(b.id !== board.id || !!this.sectionSource) && !b.archived_by_me_at && b.archived_by_me !== true && access.includes('write')});});
        if(this.sectionSource && !append){const all: BoardResponse = await this.sectionRead('targets',this.sectionSource.sectionId || '', '',live);const sections: BoardSectionData[] = all.resource_response.data as BoardSectionData[];if(!Array.isArray(sections) || sections.length > 500 || !sections.every((v: BoardSectionData): boolean => v?.type === 'board_section' && this.digits(v.id) && v.board?.id === board.id))throw new Error('target-sections');const current: BoardSectionData | undefined = sections.find((v: BoardSectionData): boolean => v.id === this.sectionSource?.sectionId);if(!current)throw new Error('source-section-missing');f.sectionTitle = this.clean(current.title);sections.forEach((v: BoardSectionData): void => {if(v.id !== this.sectionSource?.sectionId && !targets.some((t: PinmonyBoardTarget): boolean => t.id === 'section:' + v.id))targets.push({id:'section:' + v.id,title:this.clean(v.title),imageUrl:this.image(v.preview_pins?.[0]?.image_medium_url) || this.image(v.preview_pins?.[0]?.images?.['236x']?.url),enabled:true});});}
        if(this.sectionSource && !targets.some((t: PinmonyBoardTarget): boolean => t.id === board.id))targets.unshift({id:board.id,title:board.name,imageUrl:'',enabled:true});
        const next: string = this.next(body);f.targets = targets.slice(0,500);f.hasMore = !!next && next !== '-end-' && next !== this.targetCursor && !!rows.length && targets.length < 500;this.targetCursor = next;
      } else {
        const b: BoardData = body.resource_response.data as BoardData;this.validateAuxiliaryBoard(b,true);
        if(!['public','secret'].includes(b.privacy || ''))throw new Error('privacy');
        // Read/edit field sets omit role fields; retain only fields already verified for this board.
        b.owner = {id:b.owner.id,username:b.owner.username || board.owner.username,full_name:b.owner.full_name || board.owner.full_name,image_medium_url:b.owner.image_medium_url || board.owner.image_medium_url,image_small_url:b.owner.image_small_url || board.owner.image_small_url,image_large_url:b.owner.image_large_url || board.owner.image_large_url};
        if(typeof b.collaborated_by_me !== 'boolean')b.collaborated_by_me = board.collaborated_by_me;
        if(typeof b.is_collaborative !== 'boolean')b.is_collaborative = board.is_collaborative;
        if(!Array.isArray(b.collaborating_users))b.collaborating_users = board.collaborating_users;
        if(!Array.isArray(b.access))b.access = board.access;
        this.board = b;f.description = this.clean(b.description,500);f.privacy = b.privacy!;f.recommend = b.allow_homefeed_recommendations === true;f.invites = b.collaborator_invites_enabled === true;f.requests = b.collaborator_requests_enabled === true;
      }
    }catch (_) {if(live())f.error = '读取失败，请重试';}
    finally {if(live()){f.loading = false;this.syncAuxiliary();}}
  }
  private async readTargetSections(target: string): Promise<void> {
    const f: PinmonyBoardFlow | undefined = this.flow;
    if(!this.current() || !this.board || !this.sectionSource || f?.phase !== 'targets' || f.busy || f.uncertain || !this.digits(target) || !f.targets.some((t: PinmonyBoardTarget): boolean => t.id === target && t.enabled))return;
    this.cancelFlow();const revision: number = this.revision,epoch: number = this.flowEpoch;
    f.targetBoardId = target;f.targetSections = [];f.loading = true;f.error = '';this.syncAuxiliary();
    const live = (): boolean => this.current() && revision === this.revision && epoch === this.flowEpoch && this.flow === f && f.targetBoardId === target && f.targets.some((t: PinmonyBoardTarget): boolean => t.id === target && t.enabled);
    try {const body: BoardResponse = await this.sectionRead('targets',this.sectionSource.sectionId || '', '',live,target),rows: BoardSectionData[] = body.resource_response.data as BoardSectionData[];
      if(!Array.isArray(rows) || rows.length > 500 || !rows.every((v: BoardSectionData): boolean => v?.type === 'board_section' && this.digits(v.id) && v.board?.id === target && !!this.clean(v.title)))throw new Error('target-section');
      const sections: PinmonyBoardSection[] = [];rows.forEach((v: BoardSectionData): void => {if(v.id !== this.sectionSource?.sectionId && !sections.some((s: PinmonyBoardSection): boolean => s.id === v.id))sections.push({id:v.id,title:this.clean(v.title),images:[this.image(v.preview_pins?.[0]?.image_medium_url) || this.image(v.preview_pins?.[0]?.images?.['236x']?.url)].filter((u: string): boolean => !!u)});});f.targetSections = sections;
    }catch (_) {if(live())f.error = '目标图板区块读取失败，请重试';}
    finally {if(live()){f.loading = false;this.syncAuxiliary();}}
  }
  private async sectionRead(kind: string, id: string, path: string, live: () => boolean, targetBoard: string = ''): Promise<BoardResponse> {
    if(!this.board || !this.digits(id) || !live())throw new Error('section');
    const requestedBoard: string = targetBoard || this.board.id;
    let name: string = 'ApiResource', source: string = '/boardsection/' + id + '/organize/repin/', handler: string = 'www/boardsection/[id]/organize/add.js';
    let options: BoardReadOptions = {url:'/v3/board/' + requestedBoard + '/sections/all/',data:{fields:['boardsection.board','boardsection.id','boardsection.slug','boardsection.title','boardsection.type','boardsection.preview_pins(limit:1)']}};
    if(kind === 'metadata'){name = 'BoardSectionResource';options = {section_id:id};}
    else if(kind === 'tools'){source = path;handler = 'www/[username]/[slug]/[section_slug].js';options = {url:'/v3/boards/sections/' + id + '/tools/',data:{fields:['boardtool.id','boardtool.type','boardtool.tool','boardtool.text','boardtool.icon','boardtool.link','boardtool.show_badge']}};}
    else if(kind === 'ideas'){name = 'BoardContentRecommendationResource';source = path + '_tools/more-ideas/?ideas_referrer=24';handler = 'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js';options = {id:this.board.id,type:'board',__track__referrer:24};}
    const envelope: BoardReadEnvelope = {options:options,context:{}};
    const job: PinmonyNetworkJob = {id:'native_board_section_read_' + (++this.sequence).toString(),epoch:this.generation,page:this.page,url:this.origin + '/resource/' + name + '/get/?source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)) + '&_=' + Date.now().toString(),method:'GET',body:'',headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':handler}};
    this.requests.add(job.id);this.flowRequests.add(job.id);
    try {const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessBoardSectionRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),requestedBoard,id,path,live);
      if(!live() || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 6000000)throw new Error('request');
      const body: BoardResponse = JSON.parse(reply.body) as BoardResponse,r: BoardResource = body.resource_response;
      const expected: string = kind === 'metadata' ? 'v3_get_board_section' : kind === 'tools' ? 'v3_get_board_section_tools' : 'get_all_boards_sections';
      if(r?.status !== 'success' || r.error || (kind === 'ideas' ? r.code !== undefined && r.code !== 0 : r.code !== 0) || kind !== 'ideas' && r.endpoint_name !== expected || body.client_context?.user && body.client_context.user.id !== this.viewer)throw new Error('response');return body;
    }finally {this.requests.delete(job.id);this.flowRequests.delete(job.id);}
  }
  private async readSectionIdeas(): Promise<void> {
    const source: PinmonyBoardFlow | undefined = this.flow;
    if(!this.current() || !this.board || source?.phase !== 'section' || !source.sectionId)return;
    this.cancelFlow();const revision: number = this.revision, epoch: number = this.flowEpoch,id: string = source.sectionId;
    this.sectionSource = JSON.parse(JSON.stringify(source)) as PinmonyBoardFlow;
    const f: PinmonyBoardFlow = this.emptyFlow();f.phase = 'ideas';f.sectionId = id;f.sectionTitle = source.sectionTitle;f.loading = true;this.flow = f;this.syncAuxiliary();
    const live = (): boolean => this.current() && revision === this.revision && epoch === this.flowEpoch && this.flow === f;
    let stage: string = '区块资料';
    try {
      const metadata: BoardResponse = await this.sectionRead('metadata',id,'',live),d: BoardSectionData = metadata.resource_response.data as BoardSectionData;
      if(d?.type !== 'board_section' || d.id !== id || d.board?.id !== this.board.id || !d.slug || d.slug.length > 300 || /[/?#]/.test(d.slug))throw new Error('section');
      const path: string = this.page.slice(this.origin.length) + encodeURIComponent(d.slug) + '/';
      this.sectionIdeaPath = path + '_tools/more-ideas/?ideas_referrer=24';
      stage = '区块工具';
      const tools: BoardResponse = await this.sectionRead('tools',id,path,live),list: BoardToolData[] = tools.resource_response.data as BoardToolData[];
      if(!Array.isArray(list) || list.length > 20 || !list.some((t: BoardToolData): boolean => t.type === 'boardtool' && t.tool === 1))throw new Error('tools');
      stage = '推荐内容';
      const ideas: BoardResponse = await this.sectionRead('ideas',id,path,live),rows: BoardPinData[] = ideas.resource_response.data as BoardPinData[];
      if(!Array.isArray(rows) || rows.length > 500)throw new Error('ideas');
      const pins: PinmonyBoardPin[] = [], sources: BoardSourcePin[] = [];rows.forEach((row: BoardPinData): void => {try {const pin: PinmonyBoardPin = this.mapPin(row);if(!pins.some((p: PinmonyBoardPin): boolean => p.id === pin.id)){pins.push(pin);sources.push({id:pin.id,tracking_params:typeof row.tracking_params === 'string' && row.tracking_params.length <= 16384 ? row.tracking_params : undefined});}}catch (_) {}});
      this.sources = sources;f.saved = this.pinWrites.savedIds();
      if(rows.some((p: BoardPinData): boolean => p?.type === 'pin') && !pins.length)throw new Error('unsupported');f.pins = pins;
    }catch (_) {if(live())f.error = stage + '读取失败，请重试';}
    finally {if(live()){f.loading = false;this.syncAuxiliary();}}
  }
  private validateAuxiliaryBoard(b: BoardData, requireUrl: boolean): void {
    if(!b || b.type !== 'board' || b.id !== this.board?.id || !b.owner || b.owner.id !== this.board?.owner.id ||
      (requireUrl || b.url !== undefined) && (typeof b.url === 'string' && b.url.startsWith('/') && !b.url.startsWith('//') ? this.origin + b.url : b.url) !== this.page)throw new Error('board');
  }
  // A write intent waits for a current document and installs only already verified native preparation.
  private async prepareWrite(): Promise<boolean> {
    if(this.preparing)return false;const revision: number = this.revision;this.preparing = true;
    try {return await this.prepareWriteContext();}finally {if(revision === this.revision)this.preparing = false;}
  }
  private async prepareWriteContext(): Promise<boolean> {
    if(!this.current() || !this.verified || !this.ready || this.store.boardDetail?.flow?.loading || this.store.boardDetail?.flow?.busy || this.store.boardDetail?.flow?.uncertain || !this.ports.prepareDocument || !this.ports.runScript || !this.ports.jsonText)return false;
    const revision: number = this.revision, flowEpoch: number = this.flowEpoch, token: number = this.store.collaboratorsToken;
    if(!await this.ports.prepareDocument() || !this.current() || revision !== this.revision || flowEpoch !== this.flowEpoch || token !== this.store.collaboratorsToken)return false;
    const epoch: number = this.ports.documentEpoch();if(this.ports.document().split(/[?#]/)[0] !== this.page)return false;
    try {const raw: string = await this.ports.runScript('(function(){' + this.installScript() + 'return JSON.stringify(window.PinmonyBoardApi && window.PinmonyBoardApi.nativePreparedContext(' + JSON.stringify(this.page) + ',' + this.version.toString() + '));})()');
      const c: BoardPreparedContext = JSON.parse(this.ports.jsonText(raw)) as BoardPreparedContext;
      if(!this.current() || revision !== this.revision || flowEpoch !== this.flowEpoch || token !== this.store.collaboratorsToken || epoch !== this.ports.documentEpoch() || this.ports.document().split(/[?#]/)[0] !== this.page || !c || c.page !== this.page || c.version !== this.version || !Number.isInteger(c.session) || c.session <= 0)return false;
      this.bridgeEpoch = epoch;this.bridgeSession = c.session;this.adoptedVersion = this.version;if(this.store.boardDetail)this.store.boardDetail.session = c.session;
      this.store.presentationOnly = false;if(this.store.pendingBoardUrl === this.page){this.store.pendingBoardUrl = '';this.store.pendingBoardSource = '';this.store.boardOpeningToken++;}
      this.flow = undefined;return true;
    }catch (_) {return false;}
  }
  collaboratorsPolling(): boolean {return false;}
  async openCollaborators(): Promise<void> {
    if(!this.bind() || !this.participates() || !this.ready || this.store.collaborators || this.store.boardDetail?.flow?.busy || this.store.boardDetail?.flow?.uncertain || this.store.boardDetail?.flow?.loading || this.store.boardDetail?.flow?.phase && this.store.boardDetail.flow.phase !== 'edit')return;
    const token: number = ++this.store.collaboratorsToken;
    this.store.collaborators = {token:token,page:this.page,phase:'members',loading:true,busy:false,uncertain:false,error:'',feedback:'',permission:1,invites:false,users:[],suggestions:[]};await this.readCollaborators();
  }
  private cancelCollaborators(): void {this.collabEpoch++;this.collabRequests.forEach((id: string): void => this.ports.network().cancel(id));this.collabRequests.clear();}
  private collaborator(user: BoardUser, status: string): PinmonyBoardCollaborator {if(!user || !this.digits(user.id) || typeof user.username === 'string' && !/^[A-Za-z0-9_]*$/.test(user.username))throw new Error('collaborator');return {id:user.id,name:this.clean(user.full_name || user.username),username:this.clean(user.username),avatar:this.image(user.image_medium_url || user.image_small_url || user.image_large_url),status:status};}
  private async readCollaborators(): Promise<void> {
    if(!this.current() || !this.board || !this.participates())return;this.cancelCollaborators();const epoch: number = this.collabEpoch, revision: number = this.revision, state: PinmonyBoardCollaborators | undefined = this.store.collaborators;if(!state || state.busy)return;
    state.loading = true;state.error = '';const live = (): boolean => this.current() && revision === this.revision && epoch === this.collabEpoch && this.store.collaborators === state && state.token === this.store.collaboratorsToken;
    try {const values: BoardResponse[] = await Promise.all([
      this.request('BoardResource',{board_id:this.board.id,field_set_key:'boardEdit'},revision,-1,true,live),
      this.request('BoardInvitesResource',{board_id:this.board.id,sort:'viewer_first',field_set_key:'boardEdit',status_filters:'new,accepted,contact_request_not_approved,pending_approval',include_inactive:true},revision,-1,true,live),
      this.request('ShareSuggestionsResource',{suggestion_type:'group_board',board:this.board.id},revision,-1,true,live)]);
      if(!live())return;const b: BoardData = values[0].resource_response.data as BoardData;this.validateAuxiliaryBoard(b,false);
      const member: boolean = typeof b.collaborated_by_me === 'boolean' ? b.collaborated_by_me : this.board.collaborated_by_me === true;
      if(b.owner.id !== this.viewer && !member || b.collaborator_permissions_setting !== 0 && b.collaborator_permissions_setting !== 1)throw new Error('permissions');
      const invites: BoardInviteData[] = values[1].resource_response.data as BoardInviteData[], suggested: BoardUser[] = values[2].resource_response.data as BoardUser[];
      if(!Array.isArray(invites) || invites.length > 500 || !Array.isArray(suggested) || suggested.length > 500)throw new Error('users');
      const owner: PinmonyBoardCollaborator = this.collaborator(b.owner,'owner');[this.board.owner,values[0].client_context?.user].forEach((u: BoardUser | undefined): void => {if(u?.id === owner.id){const known: PinmonyBoardCollaborator = this.collaborator(u,'owner');owner.name = owner.name || known.name;owner.username = owner.username || known.username;owner.avatar = owner.avatar || known.avatar;}});
      const users: PinmonyBoardCollaborator[] = [owner];invites.forEach((i: BoardInviteData): void => {if(!i || i.board?.id !== this.board?.id || !['new','accepted','contact_request_not_approved','pending_approval'].includes(i.status))throw new Error('invite');const user: PinmonyBoardCollaborator = this.collaborator(i.invited_user,i.status);if(!users.some((u: PinmonyBoardCollaborator): boolean => u.id === user.id))users.push(user);});
      const suggestions: PinmonyBoardCollaborator[] = [];suggested.slice(0,100).forEach((u: BoardUser): void => {const user: PinmonyBoardCollaborator = this.collaborator(u,users.find((v: PinmonyBoardCollaborator): boolean => v.id === u.id)?.status || '');if(user.id !== this.viewer && !suggestions.some((v: PinmonyBoardCollaborator): boolean => v.id === user.id))suggestions.push(user);});
      state.owner = b.owner.id === this.viewer;state.permission = b.collaborator_permissions_setting;state.invites = b.collaborator_invites_enabled === true;state.canInvite = state.owner || member && state.invites;state.users = users.slice(0,500);state.suggestions = suggestions;
    }catch (_) {if(live()){state.error = '合作用户读取失败，请重试';this.collabRequests.forEach((id: string): void => this.ports.network().cancel(id));this.collabRequests.clear();}}
    finally {if(live()){state.loading = false;this.syncAuxiliary();}}
  }
  async collaboratorsAction(action: string, value: string): Promise<boolean> {
    const s: PinmonyBoardCollaborators | undefined = this.store.collaborators;if(!this.current() || !s || s.busy)return true;
    if(action === 'close'){this.cancelCollaborators();this.store.collaborators = undefined;this.store.collaboratorsToken++;this.syncAuxiliary();return true;}
    if(s.uncertain)return true;if(action === 'retry'){await this.readCollaborators();return true;}if(s.loading || s.error)return true;
    if(['members','invite','permissions'].includes(action)){if(action === 'permissions' && !s.owner)return true;s.phase = action;this.syncAuxiliary();return true;}
    if(action === 'send'){if(s.phase !== 'invite' || !s.canInvite || !s.suggestions.some((u: PinmonyBoardCollaborator): boolean => u.id === value && !u.status))return true;}
    else if(action === 'save'){let v: BoardPermissionValue;try {v = JSON.parse(value) as BoardPermissionValue;}catch (_) {return true;}if(s.phase !== 'permissions' || !s.owner || ![0,1].includes(v.permission) || typeof v.invites !== 'boolean')return true;}
    else return true;
    await this.collaboratorWrites.submit(action,value);return true;
  }
  private async request(name: string, options: BoardReadOptions, revision: number, section: number = -1, auxiliary: boolean = false, operationCurrent?: () => boolean): Promise<BoardResponse> {
    const envelope: BoardReadEnvelope = {options:options,context:{}};
    let source: string = this.page.slice(this.origin.length), handler: string = 'www/index.js';
    if(auxiliary && name === 'BoardContentRecommendationResource'){source += '_tools/more-ideas/?ideas_referrer=23';handler = 'www/[username]/[slug]/_tools/more-ideas.js';}
    else if(auxiliary && name === 'BoardsResource'){source = '/board/' + (this.board?.id || '') + '/organize/repin/';handler = 'www/board/[id]/organize.js';}
    else if(auxiliary && name === 'BoardResource' && options.field_set_key === 'edit'){source = '/board/' + (this.board?.id || '') + '/edit/';handler = 'www/board/[id]/edit.js';}
    const job: PinmonyNetworkJob = {id:(auxiliary ? 'native_board_aux_' : 'native_board_') + (++this.sequence).toString(),epoch:this.generation,page:this.page,
      url:this.origin + '/resource/' + name + '/get/?source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)) + '&_=' + Date.now().toString(),
      method:'GET',body:'',headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':handler}};
    this.requests.add(job.id); if(section >= 0)this.sectionRequests.add(job.id); let reply: PinmonyNetworkReply;
    const current = (): boolean => this.current() && revision === this.revision && (section < 0 || section === this.sectionEpoch) && (!operationCurrent || operationCurrent());
    if(auxiliary)(options.field_set_key === 'boardEdit' || name === 'BoardInvitesResource' || name === 'ShareSuggestionsResource' ? this.collabRequests : this.flowRequests).add(job.id);
    try {reply = auxiliary ? await this.ports.network().requestBusinessBoardAuxRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.board?.id || '',this.board?.owner.username || '',this.viewer,current) : await this.ports.network().requestBusinessBoardRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),this.board?.id || '',section >= 0 ? this.flow?.sectionId || '' : '',this.viewer,this.board?.isOwn === true,current);} finally {this.requests.delete(job.id);this.sectionRequests.delete(job.id);this.flowRequests.delete(job.id);this.collabRequests.delete(job.id);}
    if(!current())throw new Error('cancelled');
    if(!this.current() || revision !== this.revision || section >= 0 && section !== this.sectionEpoch)throw new Error('cancelled');
    if(reply.error || reply.status !== 200 || reply.body.length > 6000000)throw new Error('request');
    const payload: BoardResponse = JSON.parse(reply.body) as BoardResponse, r: BoardResource = payload.resource_response;
    if(!r || r.status !== 'success' || r.error || r.code !== undefined && r.code !== 0)throw new Error('response');
    const viewer: string | undefined = payload.client_context?.user?.id;
    if(viewer !== undefined && (!this.digits(viewer) || this.viewer && viewer !== this.viewer))throw new Error('viewer');
    return payload;
  }
  private next(body: BoardResponse): string { const next: string | undefined = body.resource_response.bookmark || body.resource?.options?.bookmarks?.[0]; if(next !== undefined && (typeof next !== 'string' || next.length > 4096))throw new Error('bookmark'); return next || ''; }
  private mapPin(p: BoardPinData): PinmonyBoardPin {
    if(!p || p.type !== 'pin' || !this.digits(p.id))throw new Error('pin');
    let art: BoardImage | undefined;
    ['736x','474x','236x','orig'].some((key: string): boolean => {const a: BoardImage | undefined = p.images?.[key]; if(a && this.image(a.url) && Number.isFinite(a.width) && a.width > 0 && Number.isFinite(a.height) && a.height > 0){art = a;return true;} return false;});
    if(!art) {const d: BoardDimensions | undefined = p.image_large_size_pixels || p.image_medium_size_pixels, url: string = this.image(p.image_large_url || p.image_medium_url); if(d && url && Number.isFinite(d.width) && d.width > 0 && Number.isFinite(d.height) && d.height > 0)art = {url:url,width:d.width,height:d.height};}
    if(!art)throw new Error('image');
    let duration: string = ''; const videos: Record<string,BoardVideo> = p.videos?.video_list || {};
    Object.keys(videos).some((key: string): boolean => {const ms: number | undefined = videos[key].duration; if(typeof ms !== 'number' || !Number.isFinite(ms) || ms <= 0 || ms > 86400000)return false; const secs: number = Math.floor(ms / 1000); duration = Math.floor(secs / 60).toString() + ':' + (secs % 60).toString().padStart(2,'0'); return true;});
    return {id:p.id,pinUrl:this.origin + '/pin/' + p.id + '/',imageUrl:art.url,imageWidth:art.width,imageHeight:art.height,title:this.clean(p.grid_title || p.title),creatorName:this.clean(p.pinner?.full_name),duration:duration};
  }
  private matchesBoardPage(value: string | undefined): boolean {
    if(typeof value !== 'string')return false;
    const full: string = value.startsWith('/') && !value.startsWith('//') ? this.origin + value : value;
    if(!full.startsWith(this.origin + '/'))return false;
    try {const a: string[] = full.slice(this.origin.length).split('/'),b: string[] = this.page.slice(this.origin.length).split('/');
      return a.length === b.length && a.length === 4 && a.every((part: string,index: number): boolean => {const decoded: string = decodeURIComponent(part);return !/[/?#]/.test(decoded) && decoded === decodeURIComponent(b[index]);});
    }catch (_) {return false;}
  }
  private mapPins(body: BoardResponse, boardFeed: boolean): PinmonyBoardPin[] {
    const rows: BoardPinData[] = body.resource_response.data as BoardPinData[]; if(!Array.isArray(rows) || rows.length > 500)throw new Error('feed');
    const pins: PinmonyBoardPin[] = [];
    rows.filter((p: BoardPinData): boolean => p?.type !== 'story').forEach((p: BoardPinData): void => {if(boardFeed && !this.collection() && p?.type === 'pin' && p.board && p.board.id !== this.board?.id)throw new Error('board-pin');try {const pin: PinmonyBoardPin = this.mapPin(p);if(!pins.some((v: PinmonyBoardPin): boolean => v.id === pin.id))pins.push(pin);}catch (_) {}});
    if(rows.some((p: BoardPinData): boolean => p?.type === 'pin') && !pins.length)throw new Error('unsupported-feed');return pins;
  }
  private async read(append: boolean, refresh: boolean): Promise<void> {
    const revision: number = this.revision, previous: string = append ? this.cursor : ''; this.busy = true; this.attempted = true; this.error = ''; this.refreshing = refresh; this.apply();
    const live = (): boolean => this.current() && revision === this.revision;
    let stage: string = '图板资料';
    try {
      const parts: string[] = this.page.slice(this.origin.length).split('/').filter((p: string): boolean => !!p);
      if(!this.board || refresh) {
        this.verified = false; this.apply();
        const body: BoardResponse = await this.request(this.collection() ? 'UserResource' : 'BoardResource',this.collection() ? {username:decodeURIComponent(parts[0])} : {field_set_key:'profile_grid_item',is_mobile_fork:true,username:decodeURIComponent(parts[0]),slug:decodeURIComponent(parts[1])},revision);
        const viewer: string | undefined = body.client_context?.user?.id;
        if(!this.digits(viewer))throw new Error('identity');
        let b: BoardData;
        if(this.collection()) {const u: BoardUser = body.resource_response.data as BoardUser; if(!u || u.type !== 'user' || !this.digits(u.id) || this.clean(u.username).toLowerCase() !== decodeURIComponent(parts[0]).toLowerCase())throw new Error('user'); b = {type:'board',id:u.id,url:this.page,name:'所有 Pin 图',pin_count:u.pin_count,owner:u,isOwn:u.id === viewer};}
        else {b = body.resource_response.data as BoardData; if(!b || b.type !== 'board' || !this.digits(b.id) || !this.matchesBoardPage(b.url) || !b.owner || !this.digits(b.owner.id))throw new Error('board');}
        if(b.id === this.board?.id && viewer === this.viewer && b.followed_by_me === undefined)b.followed_by_me = this.board.followed_by_me;
        if (typeof b.followed_by_me === 'boolean') this.followWrites.reconcile(b.id,b.followed_by_me);
        this.board = b; this.viewer = viewer!; this.verified = true; this.sectionsReady = false; this.sectionsError = ''; this.version++; this.apply();
      }
      stage = '图板内容';
      const b: BoardData | undefined = this.board; if(!b || !this.verified)throw new Error('identity');
      const o: BoardReadOptions = this.collection() ? {add_vase:false,field_set_key:'mobile_grid_item',is_own_profile_pins:b.isOwn === true,username:b.owner.username} : {add_vase:false,board_id:b.id,field_set_key:'react_grid_pin',filter_section_pins:true,is_react:true,prepend:false,page_size:15,redux_normalize_feed:true,gated:false}; if(append)o.bookmarks = [previous];
      const body: BoardResponse = await this.request(this.collection() ? 'UserPinsResource' : 'BoardFeedResource',o,revision);
      const mapped: PinmonyBoardPin[] = this.mapPins(body,true), next: string = this.next(body), pins: PinmonyBoardPin[] = append ? this.pins.slice() : [];
      mapped.forEach((p: PinmonyBoardPin): void => {if(!pins.some((v: PinmonyBoardPin): boolean => v.id === p.id))pins.push(p);});
      this.cancelledCards.forEach((pin: PinmonyBoardPin,id: string): void => {
        const index: number = pins.findIndex((p: PinmonyBoardPin): boolean => p.id === id);
        if(index >= 0)pins[index] = pin;else pins.splice(Math.min(this.cancelledPositions.get(id) || 0,pins.length),0,pin);
      });
      if(this.cancelledDisplayCount !== undefined && this.board)this.board.pin_count = this.cancelledDisplayCount;
      this.pins = pins.slice(0,2000); this.cursor = next; this.ended = !next || next === '-end-' || next === previous || !mapped.length || pins.length >= 2000; this.ready = true; this.version++; if(!append)this.recoveryVersion = this.version;
      PinmonyRuntimeLog.info('BoardNativeTrace: committed append=' + append.toString() + ' count=' + this.pins.length.toString());
    } catch (_) {if(live()){this.error = append ? '更多 Pin 图加载失败，请重试' : stage + '读取失败，请重试';PinmonyRuntimeLog.info('BoardNativeTrace: failed stage=' + (stage === '图板资料' ? 'metadata' : 'feed'));}}
    finally {if(live()){this.busy = false;this.refreshing = false;this.apply();this.ports.install(this.installScript());if(this.refreshQueued){this.refreshQueued = false;this.refresh();}else if(this.verified && !this.sectionsReady && !this.sectionsBusy && !this.sectionsError)this.readSections();}}
  }
  private async readSections(force: boolean = false): Promise<void> {
    if(!this.current() || !this.verified || !this.board || this.sectionsBusy)return;
    if(this.collection() || !force && !(this.board.section_count && this.board.section_count > 0)){this.sections = [];this.sectionsReady = true;this.sectionsError = '';this.apply();return;}
    const revision: number = this.revision; this.sectionsBusy = true; this.sectionsError = '';
    try {const body: BoardResponse = await this.request('BoardSectionsResource',{board_id:this.board.id,redux_normalize_feed:true},revision), rows: BoardSectionData[] = body.resource_response.data as BoardSectionData[];
      if(!Array.isArray(rows) || rows.length > 500)throw new Error('sections');
      const sections: PinmonyBoardSection[] = rows.slice(0,100).map((s: BoardSectionData): PinmonyBoardSection => {if(!s || s.type !== 'board_section' || !this.digits(s.id) || !this.clean(s.title) || s.pin_count !== null && s.pin_count !== undefined && this.count(s.pin_count) === undefined)throw new Error('section'); const previews: BoardPinData[] = Array.isArray(s.preview_pins) ? s.preview_pins.slice(0,2) : []; const pins: PinmonyBoardPin[] = []; previews.forEach((p: BoardPinData): void => {try {pins.push(this.mapPin(p));}catch (_) {}});return {id:s.id,title:this.clean(s.title),pinCount:s.pin_count === null || s.pin_count === undefined ? undefined : s.pin_count,images:previews.map((p: BoardPinData): string => this.image(p.image_medium_url) || this.image(p.images?.['236x']?.url) || this.image(p.images?.['474x']?.url) || this.image(p.images?.['orig']?.url)).filter((u: string): boolean => !!u),pins:pins};});
      this.sections = sections;if(force && this.board)this.board.section_count = sections.length;this.sectionsReady = true;this.version++;
    }catch (_) {if(this.current() && revision === this.revision)this.sectionsError = '图板区块读取失败，请重试';}
    finally {if(this.current() && revision === this.revision){this.sectionsBusy = false;this.apply();this.ports.install(this.installScript());if(this.sectionsQueued){this.sectionsQueued = false;this.readSections(true);}}}
  }
  private cancelSection(): void {this.sectionEpoch++;this.sectionRequests.forEach((id: string): void => this.ports.network().cancel(id));this.sectionRequests.clear();}
  private async readSection(id: string, append: boolean): Promise<void> {
    const section: PinmonyBoardSection | undefined = this.sections.find((s: PinmonyBoardSection): boolean => s.id === id); if(!section || append && (this.flow?.loading || !this.flow?.hasMore))return;
    if(!append)this.cancelSection();
    const epoch: number = this.sectionEpoch, revision: number = this.revision;
    if(!append){this.flow = this.emptyFlow();this.sectionCursor = '';this.sectionEnumerationValid = true;}
    const f: PinmonyBoardFlow | undefined = this.flow; if(!f)return; const previous: string = this.sectionCursor;
    f.phase = 'section';f.sectionId = id;f.sectionTitle = section.title;f.loading = true;f.error = '';this.apply();
    try {const o: BoardReadOptions = {page_size:25,prepend:false,section_id:id}; if(append)o.bookmarks = [previous];const body: BoardResponse = await this.request('BoardSectionPinsResource',o,revision,epoch), pins: PinmonyBoardPin[] = this.mapPins(body,false), next: string = this.next(body);
      const raw: BoardPinData[] = body.resource_response.data as BoardPinData[];
      if(!Array.isArray(raw) || !raw.filter((p: BoardPinData): boolean => p?.type !== 'story').every((p: BoardPinData): boolean => p?.type === 'pin' && this.digits(p.id) && pins.some((pin: PinmonyBoardPin): boolean => pin.id === p.id)))this.sectionEnumerationValid = false;
      const merged: PinmonyBoardPin[] = append ? f.pins.slice() : [];pins.forEach((p: PinmonyBoardPin): void => {if(!merged.some((v: PinmonyBoardPin): boolean => v.id === p.id))merged.push(p);}); if(merged.length > 500)this.sectionEnumerationValid = false;f.pins = merged.slice(0,500); f.hasMore = !!next && next !== '-end-' && next !== previous && !!pins.length && merged.length < 500; this.sectionCursor = next;this.version++;
    } catch (_) {if(this.current() && revision === this.revision && epoch === this.sectionEpoch)f.error = '图板区块内容读取失败，请重试';}
    finally {if(this.current() && revision === this.revision && epoch === this.sectionEpoch){f.loading = false;this.apply();this.ports.install(this.installScript());}}
  }
  installScript(): string { if(!this.current() || !this.verified || !this.board || !this.ready)return '';return 'window.PinmonyBoardApi && window.PinmonyBoardApi.installNative && window.PinmonyBoardApi.installNative(' + JSON.stringify(this.page) + ',' + JSON.stringify(this.board) + ',' + JSON.stringify(this.viewer) + ',' + JSON.stringify(this.store.boardDetail) + ',' + JSON.stringify(this.cursor) + ',' + JSON.stringify(this.auxiliarySnapshot()) + ');'; }
  updateBridge(value: string): void {
    if(!this.bind())return;
    try {const m: BoardBridgeState = JSON.parse(value) as BoardBridgeState;
      if(m.pageKey !== this.page || this.ports.document().split(/[?#]/)[0] !== this.page || m.contextEpoch !== this.ports.documentEpoch() || !Number.isInteger(m.session) || m.session <= 0 || this.bridgeEpoch === m.contextEpoch && m.session < this.bridgeSession)return;
      if(m.kind === 'nativeContext'){this.ports.install(this.installScript());return;}
      if(m.kind !== 'state' || !this.verified)return;
      if(m.nextPage || ['deleted','left','unfollowed'].includes(m.flow?.phase || ''))return;
      if(m.nativeVersion !== this.version){
        if(this.bridgeEpoch === m.contextEpoch && this.bridgeSession === m.session && m.nativeVersion === this.adoptedVersion)this.invalidate(m);
        // Adoption may have been deferred while an existing read/write flow was busy.
        if(!m.flow?.busy && !m.flow?.loading)this.ports.install(this.installScript());
        return;
      }
      if(this.bridgeEpoch !== m.contextEpoch){this.reload = 0;this.sectionsReload = 0;}
      this.bridgeEpoch = m.contextEpoch;this.bridgeSession = m.session;this.adoptedVersion = this.version;
      if(this.flow?.phase === '')this.flow = undefined;
      this.ports.bridge(value);this.apply();this.invalidate(m);
    }catch (_) {}
  }
  private invalidate(m: BoardBridgeState): void {
    if(Number.isInteger(m.nativeReload) && (m.nativeReload || 0) > this.reload){this.reload = m.nativeReload || 0;if(this.busy)this.refreshQueued = true;else this.refresh();}
    if(Number.isInteger(m.nativeSectionsReload) && (m.nativeSectionsReload || 0) > this.sectionsReload){this.sectionsReload = m.nativeSectionsReload || 0;this.sectionsReady = false;if(this.sectionsBusy)this.sectionsQueued = true;else this.readSections(true);}
  }
}
