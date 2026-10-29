import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardFlow, PinmonyBoardCoverState, PinmonyBoardCoverCrop, PinmonyBoardPin, boardCoverCrop, boardCoverPreview } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';

export interface PinmonyBoardCoverIdentity { page: string; boardId: string; viewerId: string; ownerId: string; intent: number; }
interface CoverSourceImage { url: string; width: number; height: number; }
interface CoverSourcePin { id: string; type: string; images?: Record<string,CoverSourceImage>; }
interface CoverSavedPin { pin_id: string; custom_cover?: boolean; crop?: number[]; size?: number[]; scale?: number; image_url?: string; }
interface CoverBoardData { has_custom_cover?: boolean; id: string; type: string; owner: CoverBoardOwner; access: string[]; image_cover_url?: string; cover_pin?: CoverSavedPin; }
interface CoverBoardOwner { id: string; }
interface CoverTask { task_id: string; }
interface CoverResource { status: string; code: number; endpoint_name: string; data: CoverSourcePin[] | CoverBoardData | CoverTask; bookmark?: string; }
interface CoverResponseOptions { bookmarks?: string[]; }
interface CoverResponse { resource_response: CoverResource; resource?: CoverResponseResource; client_context?: CoverClientContext; }
interface CoverResponseResource { options?: CoverResponseOptions; }
interface CoverClientContext { user?: CoverBoardOwner; }
interface CoverReadOptions { board_id: string; field_set_key: string; filter_section_pins?: boolean; page_size?: number; bookmarks?: string[]; }
interface CoverWriteOptions { board_id: string; url: string; pin_id: string; pin_image_url: string; crop_x: number; crop_y: number; width: number; height: number; scale: number; }
interface CoverEnvelope { options: CoverReadOptions | CoverWriteOptions; context: Record<string,string>; }
export interface PinmonyBoardCoverPorts {
  state: () => PinmonyBoardFlow | undefined;
  identity: () => PinmonyBoardCoverIdentity | undefined;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  changed: (flow: PinmonyBoardFlow) => void;
  confirmed: (image: string) => void;
}

export class PinmonyBoardCoverNativeFlow {
  private readonly ports: PinmonyBoardCoverPorts;
  private revision: number = 0;
  private sequence: number = 0;
  private cursor: string = '';
  private restore: CoverSavedPin | undefined = undefined;
  private readonly cursors: Set<string> = new Set<string>();
  private readonly jobs: Set<string> = new Set<string>();
  // Sent writes remain locked across close/reopen and navigation. Only matching
  // readback can release the lock; neither a timeout nor HTTP 200 permits replay.
  private readonly pending: Map<string,PinmonyBoardCoverCrop> = new Map<string,PinmonyBoardCoverCrop>();
  private pendingAccount: string = '';
  private timer: number = -1;
  private wake: (() => void) | undefined = undefined;
  constructor(ports: PinmonyBoardCoverPorts) { this.ports = ports; }
  private key(identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext): string {
    return session.origin + ':' + session.accountId + ':' + session.generation + ':' + identity.boardId;
  }
  private publish(flow: PinmonyBoardFlow): void { this.ports.changed(flow); }
  pause(): void {
    this.revision++;
    this.jobs.forEach((id: string): void => this.ports.network().cancel(id));this.jobs.clear();
    if(this.timer >= 0)clearTimeout(this.timer);this.timer = -1;this.wake?.();this.wake = undefined;
    const f: PinmonyBoardFlow | undefined = this.ports.state();
    if(f?.cover){if(f.busy){f.cover.status = 'uncertain';f.uncertain = true;f.cover.error = PinmonyI18n.message('pm_board_cover_unconfirmed');}
      else if(f.cover.loading)f.cover.error = PinmonyI18n.message('pm_loading_interrupted_please_retry_b469c1dd');
      f.busy = false;f.cover.loading = false;this.publish(f);}
  }
  private safeImage(url: string | undefined): string { return typeof url === 'string' && url.length <= 2048 && /^https:\/\/i\.pinimg\.com\//.test(url) ? url : ''; }
  async handle(action: string, encoded: string = ''): Promise<void> {
    const f: PinmonyBoardFlow | undefined = this.ports.state(), identity: PinmonyBoardCoverIdentity | undefined = this.ports.identity();
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(!f || f.phase !== 'edit' || !identity || identity.ownerId !== identity.viewerId || !session.authenticated || !session.accountId)return;
    if(action === 'coverBack') {
      if(f.busy)return;this.pause();f.cover = undefined;f.uncertain = false;this.publish(f);return;
    }
    if(f.busy || f.loading || f.cover?.loading)return;
    const account: string = session.origin + ':' + session.accountId + ':' + session.generation;
    if(this.pendingAccount !== account){this.pendingAccount = account;this.pending.clear();}
    const key: string = this.key(identity,session);
    if(action === 'coverOpen' || action === 'coverAdjust') {
      if(f.uncertain || f.error)return;
      this.cursor = '';this.cursors.clear();this.restore = undefined;
      const locked: PinmonyBoardCoverCrop | undefined = this.pending.get(key);
      f.cover = {adjusting:action === 'coverAdjust',pins:[],loading:true,hasMore:false,status:locked ? 'uncertain' : '',error:locked ? PinmonyI18n.message('pm_board_cover_unconfirmed') : '',selected:locked};
      f.uncertain = !!locked;this.publish(f);
      await this.load(f,identity,session,false);return;
    }
    const c: PinmonyBoardCoverState | undefined = f.cover;if(!c)return;
    if(action === 'coverCheck'){if(this.pending.has(key))await this.check(f,identity,session);return;}
    if(this.pending.has(key) || f.uncertain)return;
    if(action === 'coverMore' || action === 'coverRetry') {
      if(action === 'coverMore' && (c.adjusting || !c.hasMore))return;
      await this.load(f,identity,session,!!this.cursor);return;
    }
    if(action === 'coverSelect') {
      if(c.adjusting)return;
      const pin: PinmonyBoardPin | undefined = c.pins.find((p: PinmonyBoardPin): boolean => p.id === encoded);
      if(pin){c.selected = boardCoverCrop(pin,(pin.imageWidth-Math.min(pin.imageWidth,pin.imageHeight))/2,(pin.imageHeight-Math.min(pin.imageWidth,pin.imageHeight))/2);c.error = '';this.publish(f);}return;
    }
    if(action === 'coverCrop') {
      let crop: PinmonyBoardCoverCrop;try{crop = JSON.parse(encoded) as PinmonyBoardCoverCrop;}catch(_){return;}
      const pin: PinmonyBoardPin | undefined = c.pins.find((p: PinmonyBoardPin): boolean => p.id === crop.pinId && p.id === c.selected?.pinId);
      if(!pin || !Number.isFinite(crop.cropX) || !Number.isFinite(crop.cropY))return;
      c.selected = boardCoverCrop(pin,crop.cropX,crop.cropY);this.publish(f);return;
    }
    if(action === 'coverSave' && c.selected)await this.save(f,identity,session);
  }
  private live(identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext, revision: number, flow: PinmonyBoardFlow): boolean {
    const actual: PinmonyBoardCoverIdentity | undefined = this.ports.identity(), s: PinmonyBusinessSessionContext = this.ports.session();
    return revision === this.revision && s.authenticated && s.accountId === session.accountId && s.generation === session.generation && s.origin === session.origin &&
      !!actual && actual.page === identity.page && actual.boardId === identity.boardId && actual.viewerId === identity.viewerId && actual.ownerId === identity.ownerId && actual.intent === identity.intent &&
      this.ports.state()?.cover === flow.cover && this.ports.state()?.phase === 'edit';
  }
  private async request(name: string, options: CoverReadOptions | CoverWriteOptions, write: boolean, identity: PinmonyBoardCoverIdentity,
    session: PinmonyBusinessSessionContext, live: () => boolean, pin?: PinmonyBoardPin): Promise<CoverResponse> {
    const envelope: CoverEnvelope = {options:options,context:{}};
    const source: string = identity.page.slice(session.origin.length), data: string = encodeURIComponent(JSON.stringify(envelope));
    const job: PinmonyNetworkJob = {id:'native_board_cover_' + (++this.sequence).toString(),epoch:session.generation,page:identity.page,
      url:session.origin + '/resource/' + name + '/' + (write ? 'update/' : 'get/?source_url=' + encodeURIComponent(source) + '&data=' + data),
      method:write ? 'POST' : 'GET',body:write ? 'source_url=' + encodeURIComponent(source) + '&data=' + data : '',
      headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/[username]/[slug].js'}};
    if(write)job.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    this.jobs.add(job.id);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessBoardCover(job,(): PinmonyBusinessSessionContext => this.ports.session(),
        identity.boardId,identity.viewerId,identity.ownerId,pin?.id || '',pin?.imageUrl || '',pin?.imageWidth || 0,pin?.imageHeight || 0,live);
      if(!live() || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 6000000)throw new Error('cover-response');
      const body: CoverResponse = JSON.parse(reply.body) as CoverResponse,r: CoverResource = body.resource_response;
      const endpoint: string = write ? 'v3_set_board_cover' : name === 'BoardFeedResource' ? 'v3_board_pins' : 'v3_get_board';
      if(!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== endpoint || body.client_context?.user && body.client_context.user.id !== identity.viewerId)throw new Error('cover-business');
      return body;
    }finally{this.jobs.delete(job.id);}
  }
  private board(body: CoverResponse, identity: PinmonyBoardCoverIdentity): CoverBoardData {
    const b: CoverBoardData = body.resource_response.data as CoverBoardData;
    if(!b || b.type !== 'board' || b.id !== identity.boardId || b.owner?.id !== identity.viewerId || !Array.isArray(b.access) || !b.access.includes('write'))throw new Error('cover-owner');
    return b;
  }
  private async load(f: PinmonyBoardFlow, identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext, append: boolean): Promise<void> {
    const state: PinmonyBoardCoverState | undefined = f.cover;if(!state)return;
    const revision: number = this.revision;
    state.loading = true;this.publish(f);
    try {
    await this.read(f,identity,session,append);
    for(let page: number = 0;page < 32 && this.live(identity,session,revision,f) && f.cover === state && state.adjusting &&
      !state.selected && state.hasMore && !state.error && state.status !== 'uncertain';page++)await this.read(f,identity,session,true);
    if(this.live(identity,session,revision,f) && f.cover === state && state.adjusting && !state.selected && !state.error) {
      state.error = PinmonyI18n.message('pm_board_cover_image_failed');
    }
    }finally{if(this.live(identity,session,revision,f) && f.cover === state){state.loading = false;this.publish(f);}}
  }
  private async read(f: PinmonyBoardFlow, identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext, append: boolean): Promise<void> {
    const c: PinmonyBoardCoverState | undefined = f.cover;if(!c)return;
    const revision: number = this.revision, live = (): boolean => this.live(identity,session,revision,f);
    if(c.status !== 'uncertain')c.error = '';
    try {
      if(!append){const b: CoverBoardData = this.board(await this.request('BoardResource',{board_id:identity.boardId,field_set_key:'edit'},false,identity,session,live),identity);
        if(!live())return;this.restore = c.adjusting && b.cover_pin?.custom_cover === true ? b.cover_pin : undefined;if(f.coverImage !== this.safeImage(b.image_cover_url))f.coverPreview = undefined;f.coverImage = b.has_custom_cover === true || b.cover_pin?.custom_cover === true || this.safeImage(b.image_cover_url).includes('/custom_covers/') ? this.safeImage(b.image_cover_url) : '';
        if(this.pending.has(this.key(identity,session)) && this.match(b,c.selected)){this.confirm(f,b,identity,session);return;}}
      const options: CoverReadOptions = {board_id:identity.boardId,field_set_key:'images_only_item',filter_section_pins:false,page_size:50};
      if(append)options.bookmarks = [this.cursor];
      const body: CoverResponse = await this.request('BoardFeedResource',options,false,identity,session,live);
      if(!live())return;
      const rows: CoverSourcePin[] = body.resource_response.data as CoverSourcePin[];
      if(!Array.isArray(rows) || rows.length > 500)throw new Error('cover-pins');
      const pins: PinmonyBoardPin[] = append ? c.pins.slice() : [];
      rows.forEach((p: CoverSourcePin): void => {
        const image: CoverSourceImage | undefined = p?.images?.['236x'];
        if(p?.type !== 'pin' || !/^\d{1,30}$/.test(p.id) || !image || !this.safeImage(image.url) || !Number.isInteger(image.width) || !Number.isInteger(image.height) || image.width < 1 || image.height < 1 || image.width > 20000 || image.height > 20000)return;
        let preview: CoverSourceImage = image;
        ['474x','564x','736x','orig'].forEach((tier: string): void => {const candidate: CoverSourceImage | undefined = p.images?.[tier];
          if(candidate && this.safeImage(candidate.url) && Number.isInteger(candidate.width) && Number.isInteger(candidate.height) && candidate.width > preview.width && candidate.width <= 20000 && candidate.height > 0 && candidate.height <= 20000 && Math.abs(candidate.height/candidate.width-image.height/image.width) <= 2/image.width)preview = candidate;});
        if(!pins.some((v: PinmonyBoardPin): boolean => v.id === p.id))pins.push({id:p.id,pinUrl:session.origin+'/pin/'+p.id+'/',imageUrl:image.url,previewImageUrl:preview.url,imageWidth:image.width,imageHeight:image.height,title:''});
      });
      const saved: CoverSavedPin | undefined = this.restore;
      const source: PinmonyBoardPin | undefined = pins.find((pin: PinmonyBoardPin): boolean => pin.id === saved?.pin_id);
      if(c.adjusting && !c.selected && source && saved?.crop?.length === 2 && saved.size?.length === 2) {
        const crop: PinmonyBoardCoverCrop = boardCoverCrop(source,saved.crop[0],saved.crop[1]);
        if(Number.isFinite(saved.crop[0]) && Number.isFinite(saved.crop[1]) && crop.cropX === saved.crop[0] && crop.cropY === saved.crop[1] &&
          crop.width === saved.size[0] && crop.height === saved.size[1] && typeof saved.scale === 'number' && Math.abs(crop.scale-saved.scale) < 0.000001)c.selected = crop;
      }
      const next: string = body.resource_response.bookmark || body.resource?.options?.bookmarks?.[0] || '';
      c.hasMore = typeof next === 'string' && !!next && next !== '-end-' && next.length <= 4096 && !this.cursors.has(next) && rows.length > 0 && pins.length < 500;
      c.pins = pins.slice(0,500);if(c.hasMore){this.cursor = next;this.cursors.add(next);}else this.cursor = '';
    }catch(_){if(live())c.error = PinmonyI18n.message(c.status === 'uncertain' ? 'pm_board_cover_unconfirmed' : 'pm_unable_to_load_please_retry_b22c1af1');}
    finally{if(live())this.publish(f);}
  }
  private match(b: CoverBoardData, crop: PinmonyBoardCoverCrop | undefined): boolean {
    const p: CoverSavedPin | undefined = b.cover_pin;
    return !!crop && !!p && p.custom_cover === true && p.pin_id === crop.pinId && p.crop?.length === 2 && p.size?.length === 2 &&
      p.crop[0] === crop.cropX && p.crop[1] === crop.cropY && p.size[0] === crop.width && p.size[1] === crop.height &&
      typeof p.scale === 'number' && Math.abs(p.scale-crop.scale) < 0.000001 && !!this.safeImage(b.image_cover_url);
  }
  private confirm(f: PinmonyBoardFlow, board: CoverBoardData, identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext): void {
    const selected: PinmonyBoardPin | undefined = f.cover?.pins.find((pin: PinmonyBoardPin): boolean => pin.id === board.cover_pin?.pin_id);
    const crop: PinmonyBoardCoverCrop | undefined = f.cover?.selected;
    f.coverPreview = selected && crop ? boardCoverPreview(selected,crop.cropX,crop.cropY,crop.width,crop.height,selected.imageWidth) : undefined;
    this.pending.delete(this.key(identity,session));f.coverImage = this.safeImage(board.image_cover_url);f.cover = undefined;f.busy = false;f.uncertain = false;
    this.publish(f);this.ports.confirmed(f.coverImage);
  }
  private async save(f: PinmonyBoardFlow, identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext): Promise<void> {
    const c: PinmonyBoardCoverState | undefined = f.cover, crop: PinmonyBoardCoverCrop | undefined = c?.selected;
    const pin: PinmonyBoardPin | undefined = c?.pins.find((p: PinmonyBoardPin): boolean => p.id === crop?.pinId);if(!c || !crop || !pin)return;
    const revision: number = this.revision,live = (): boolean => this.live(identity,session,revision,f);
    const options: CoverWriteOptions = {board_id:identity.boardId,pin_id:pin.id,url:pin.imageUrl,pin_image_url:pin.imageUrl,
      crop_x:crop.cropX,crop_y:crop.cropY,width:crop.width,height:crop.height,scale:crop.scale};
    this.pending.set(this.key(identity,session),crop);f.busy = true;c.status = 'saving';c.error = '';this.publish(f);
    try {
      const body: CoverResponse = await this.request('BoardResource',options,true,identity,session,live,pin);
      const task: CoverTask = body.resource_response.data as CoverTask;
      if(!task || typeof task.task_id !== 'string' || !task.task_id || task.task_id.length > 512)throw new Error('cover-task');
      if(!live())return;f.busy = false;await this.check(f,identity,session);
    }catch(_){if(live()){f.busy = false;f.uncertain = true;c.status = 'uncertain';c.error = PinmonyI18n.message('pm_board_cover_unconfirmed');this.publish(f);}}
  }
  private async check(f: PinmonyBoardFlow, identity: PinmonyBoardCoverIdentity, session: PinmonyBusinessSessionContext): Promise<void> {
    const c: PinmonyBoardCoverState | undefined = f.cover;if(!c)return;
    const revision: number = this.revision,live = (): boolean => this.live(identity,session,revision,f);
    f.busy = true;c.status = 'verifying';c.error = '';this.publish(f);
    try {
      for(let attempt: number = 0;attempt < 11;attempt++) {
        if(!live())return;
        const b: CoverBoardData = this.board(await this.request('BoardResource',{board_id:identity.boardId,field_set_key:'edit'},false,identity,session,live),identity);
        if(!live())return;
        if(this.match(b,this.pending.get(this.key(identity,session)))){this.confirm(f,b,identity,session);return;}
        if(attempt < 10)await new Promise<void>((resolve: () => void): void => {this.wake = resolve;this.timer = setTimeout((): void => {this.timer = -1;this.wake = undefined;resolve();},3000);});
      }
    }catch(_){}
    if(live()){f.busy = false;f.uncertain = true;c.status = 'uncertain';c.error = PinmonyI18n.message('pm_board_cover_unconfirmed');this.publish(f);}
  }
}
