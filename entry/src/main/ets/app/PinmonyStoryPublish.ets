import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyCreatedPin, PinmonyPublishFlow } from 'feature_profile';
import { PinmonySharePublishClientPorts, PinmonyBusinessRejection } from './PinmonySharePublishClient';

interface Board { id: string; type: string; privacy: string; owner?: Person; access?: string[]; }
interface Person { id: string; }
interface Photo { url: string; width?: number; height?: number; }
interface Block { type: string; pin_id?: string; image_signature?: string; is_removed?: boolean; }
interface Page { blocks: Block[]; }
interface Story { pages: Page[]; }
export interface PinmonyStoryResult {
  id: string; type?: string; board?: Board; pinner?: Person; images?: Record<string,Photo>;
  title?: string; description?: string; alt_text?: string; comments_disabled?: boolean; shopping_rec_disabled?: boolean;
  image_signature?: string; image_square_url?: string; story_pin_data_id?: string; story_pin_data?: Story;
}
export interface PinmonyDraftUpload { uploadId: string; signature: string; width: number; height: number; }
interface Resource { status: string; code: number; endpoint_name: string; data: PinmonyStoryResult; error?: Object; }
interface Response { resource_response: Resource; client_context?: Client; }
interface Client { is_authenticated?: boolean; user?: Person; }
interface ApiOptions { url: string; data: Object; }
interface ProductBoardData { fields: string[]; return_existing: boolean; }
interface ProductOptions { board_id: string; image_url: string; link: string; method: string; scrape_metric: Metric; }
interface Metric { source: string; }
interface Style { height: number; width: number; x_coord: number; y_coord: number; }
interface ImageBlock { block_style: Style; image_signature: string; type: number; invisible?: number; pin_id?: string; tracking_id?: string; }
interface Clip { clip_type: number; end_time_ms: number; is_converted_from_image: boolean; source_media_height: number; source_media_width: number; start_time_ms: number; }
interface PageStyle { background_color: string; }
interface StoryPage { blocks: ImageBlock[]; clips: Clip[]; layout: number; style: PageStyle; }
interface Metadata { pin_title: string; pin_image_signature: string; canvas_aspect_ratio: number; }
interface StoryPayload { metadata: Metadata; pages: StoryPage[]; }
interface CreateData { alt_text: string; allow_shopping_rec: boolean; board_id: string; description: string; fields: string[]; is_comments_allowed: boolean; is_unified_builder: boolean; link: string; method: string; story_pin: string; user_mention_tags: string; product_pins: string[]; }
interface ReadOptions { id: string; field_set_key: string; }
interface Envelope { options: Object; context: Record<string,string>; }
let sequence: number = 0;

// Captured website contracts, bound to the current native publishing owner. Never replay writes.
export class PinmonyStoryPublish {
  private ports: PinmonySharePublishClientPorts;
  private pending: Set<string> = new Set();
  constructor(ports: PinmonySharePublishClientPorts) { this.ports = ports; }
  cancel(): void { this.pending.forEach((id: string): void => { this.ports.network().cancel(id);this.ports.network().cancel(id + '_create');this.ports.network().cancel(id + '_get'); });this.pending.clear(); }
  private digits(value: string): boolean { return /^\d{1,40}$/.test(value); }
  private web(value: string): boolean { return value.length <= 4096 && /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(value); }
  private signature(pin: PinmonyCreatedPin): string { return /^https:\/\/i\.pinimg\.com\//.test(pin.imageUrl) ? pin.imageUrl.match(/\/([a-f0-9]{32})\.(?:jpg|jpeg|png|webp)(?:\?|$)/)?.[1] || '' : ''; }
  selectable(pin: PinmonyCreatedPin): boolean { return this.digits(pin.id) && !!this.signature(pin); }
  async uploadDraftImage(base64: string, page: string, viewer: string, current: () => boolean): Promise<PinmonyDraftUpload> {
    const match: RegExpMatchArray | null = base64.match(/^data:(image\/(?:png|jpeg|webp));base64,([A-Za-z0-9+/]+=*)$/);
    if (!match || base64.length > 5600000) throw new Error('photo');
    const bytes: Uint8Array = new util.Base64Helper().decodeSync(match[2]);
    const buffer: ArrayBuffer = bytes.buffer as ArrayBuffer;
    const source: image.ImageSource = image.createImageSource(buffer);
    let width: number = 0, height: number = 0;
    try { const info: image.ImageInfo = await source.getImageInfo(); width = info.size.width; height = info.size.height; } finally { source.release(); }
    if (!current() || width < 1 || height < 1 || width > 30000 || height > 30000) throw new Error('image-size');
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const id: string = 'native_publish_upload_' + (++sequence).toString();
    this.pending.add(id);
    try {
      const result: PinmonyPublishImageUpload = await this.ports.network().uploadPublishImage(buffer, match[1], page, (): PinmonyNetworkContext => this.context(page,current,session), viewer, id, [util.generateRandomUUID(),util.generateRandomUUID()]);
      return { uploadId: result.uploadId, signature: result.signature, width: width, height: height };
    } finally { this.pending.delete(id); }
  }
  private context(page: string, current: () => boolean, session: PinmonyBusinessSessionContext): PinmonyNetworkContext {
    const now: PinmonyBusinessSessionContext = this.ports.session();
    return {authenticated:current() && now.authenticated && now.accountId === session.accountId && now.generation === session.generation && now.origin === session.origin,epoch:now.generation,page:page,userAgent:now.userAgent};
  }
  private async request(name: string, verb: string, options: Object, page: string, viewer: string, current: () => boolean, endpoint: string, pin: string = ''): Promise<PinmonyStoryResult> {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(!current() || !session.authenticated || !this.digits(viewer) || !page.startsWith(session.origin + '/'))throw new Error('stale');
    const source: string = pin ? '/pin/' + pin + '/' : '/pin-creation-tool/';
    const envelope: Envelope = {options:options,context:{}};
    const form: string = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const id: string = 'native_story_publish_' + (++sequence).toString();
    const job: PinmonyNetworkJob = {id:id,epoch:session.generation,page:page,url:session.origin + '/resource/' + name + '/' + verb + '/' + (verb === 'get' ? '?' + form : ''),method:verb === 'get' ? 'GET' : 'POST',body:verb === 'get' ? '' : form,headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active','X-Pinterest-Source-Url':source,'X-Pinterest-Pws-Handler':pin ? 'www/pin/[id].js' : 'www/pin-creation-tool.js'}};
    if(session.appVersion)job.headers['X-App-Version'] = session.appVersion;
    this.pending.add(id);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().request(job,(): PinmonyNetworkContext => this.context(page,current,session));
      if(!this.context(page,current,session).authenticated || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 8000000)throw new Error('story-request');
      const response: Response = JSON.parse(reply.body) as Response, r: Resource = response.resource_response;
      if(response.client_context?.is_authenticated === false || response.client_context?.user && response.client_context.user.id !== viewer)throw new Error('story-owner');
      if(!r || typeof r.status !== 'string' || typeof r.code !== 'number')throw new Error('story-envelope');
      if(r.status !== 'success' || r.code !== 0)throw new PinmonyBusinessRejection(PinmonyI18n.message('pm_publish_submit_failed'));
      if(r.error)throw new Error('story-error');
      if(r.endpoint_name !== endpoint || !r.data)throw new Error('story-response');
      return r.data;
    } finally {this.pending.delete(id);}
  }
  async createProduct(pin: PinmonyCreatedPin, page: string, viewer: string, current: () => boolean): Promise<PinmonyCreatedPin> {
    if(!this.web(pin.imageUrl) || !this.web(pin.targetUrl || '') || !/^link-\d+$/.test(pin.id))throw new Error('product-candidate');
    const fields: string[] = ['board.access','board.allow_homefeed_recommendations','board.category','board.collaborated_by_me','board.collaborating_users()','board.collaborator_count','board.collaborator_invites_enabled','board.created_at','board.description','board.followed_by_me','board.follower_count','board.id','board.image_cover_url','board.image_thumbnail_url','board.images[170x]','board.is_collaborative','board.layout','board.name','board.owner()','board.pin_count','board.pin_thumbnail_urls','board.privacy','board.type','board.url'];
    const boardData: ProductBoardData = {fields:fields,return_existing:true};
    const boardOptions: ApiOptions = {url:'/v3/visual_links/boards/tagged/',data:boardData};
    const b: Board = await this.request('ApiResource','update',boardOptions,page,viewer,current,'create_products_tagged_board') as Board;
    if(!this.digits(b.id) || b.type !== 'board' || b.privacy !== 'protected' || b.owner?.id !== viewer || !b.access?.includes('write'))throw new Error('product-board');
    const options: ProductOptions = {board_id:b.id,image_url:pin.imageUrl,link:pin.targetUrl!,method:'scraped',scrape_metric:{source:'www_url_scrape'}};
    const d: PinmonyStoryResult = await this.request('PinResource','create',options,page,viewer,current,'v3_create_pin_handler');
    if(!this.digits(d.id) || d.type !== 'pin' || d.board?.id !== b.id || d.pinner?.id !== viewer || !d.images)throw new Error('product-unconfirmed');
    const photo: Photo | undefined = d.images['orig'] || d.images['474x'] || d.images[Object.keys(d.images)[0]];
    const result: PinmonyCreatedPin = {id:d.id,title:d.title || pin.title,imageUrl:photo?.url || '',imageWidth:photo?.width || 0,imageHeight:photo?.height || 0,targetUrl:pin.targetUrl};
    if(!this.selectable(result))throw new Error('product-image');
    return result;
  }
  async publish(base64: string, board: string, flow: PinmonyPublishFlow, page: string, viewer: string, current: () => boolean): Promise<PinmonyStoryResult> {
    const products: PinmonyCreatedPin[] = flow.selectedProducts || [];
    if(!this.digits(board) || !products.length || products.length > 10 || products.some((p: PinmonyCreatedPin): boolean => !this.selectable(p)) || new Set(products.map((p: PinmonyCreatedPin): string => p.id)).size !== products.length)throw new Error('product-selection');
    const match: RegExpMatchArray | null = base64.match(/^data:(image\/(?:png|jpeg|webp));base64,([A-Za-z0-9+/]+=*)$/);
    if(!match || base64.length > 5600000)throw new Error('photo');
    const bytes: Uint8Array = new util.Base64Helper().decodeSync(match[2]);
    const buffer: ArrayBuffer = bytes.buffer as ArrayBuffer;
    const source: image.ImageSource = image.createImageSource(buffer);
    let width: number = 0, height: number = 0;
    try {const info: image.ImageInfo = await source.getImageInfo();width = info.size.width;height = info.size.height;}finally{source.release();}
    if(!current() || !Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 || width > 30000 || height > 30000)throw new Error('image-size');
    const session: PinmonyBusinessSessionContext = this.ports.session(), uploadId: string = 'native_publish_upload_' + (++sequence).toString();
    this.pending.add(uploadId);
    let upload: PinmonyPublishImageUpload;
    try {upload = await this.ports.network().uploadPublishImage(buffer,match[1],page,(): PinmonyNetworkContext => this.context(page,current,session),viewer,uploadId,[util.generateRandomUUID(),util.generateRandomUUID()]);}finally{this.pending.delete(uploadId);}
    const blocks: ImageBlock[] = [{block_style:{height:100,width:100,x_coord:0,y_coord:0},image_signature:upload.signature,type:2}];
    products.forEach((p: PinmonyCreatedPin): void => {blocks.push({block_style:{height:0,width:0,x_coord:0,y_coord:0},image_signature:this.signature(p),invisible:1,pin_id:p.id,tracking_id:upload.uploadId,type:13});});
    const story: StoryPayload = {metadata:{pin_title:flow.photoTitle || '',pin_image_signature:upload.signature,canvas_aspect_ratio:width / height},pages:[{blocks:blocks,clips:[{clip_type:0,end_time_ms:-1,is_converted_from_image:false,source_media_height:height,source_media_width:width,start_time_ms:-1}],layout:0,style:{background_color:'#000000'}}]};
    const data: CreateData = {alt_text:flow.altText || '',allow_shopping_rec:flow.allowShopping !== false,board_id:board,description:flow.photoDescription || '',fields:['pin.id','pin.image_signature','pin.image_square_url','pin.story_pin_data_id'],is_comments_allowed:flow.allowComments !== false,is_unified_builder:true,link:flow.photoLink || '',method:'uploaded',story_pin:JSON.stringify(story),user_mention_tags:'[]',product_pins:products.map((p: PinmonyCreatedPin): string => p.id)};
    const options: ApiOptions = {url:'/v3/storypins/',data:data};
    const created: PinmonyStoryResult = await this.request('ApiResource','create',options,page,viewer,current,'v3_create_story_pin_data');
    // After creation, every failure is an uncertain main write, including a rejected readback.
    try {
      if(!this.digits(created.id) || !this.digits(created.story_pin_data_id || '') || created.image_signature !== upload.signature || !this.web(created.image_square_url || ''))throw new Error('story-created');
      const read: ReadOptions = {id:created.id,field_set_key:'auth_web_main_pin'};
      const pin: PinmonyStoryResult = await this.request('PinResource','get',read,page,viewer,current,'v3_get_pin',created.id);
      const all: Block[] = pin.story_pin_data?.pages?.reduce((rows: Block[], p: Page): Block[] => rows.concat(p.blocks || []),[]) || [];
      const tagged: string[] = all.filter((b: Block): boolean => b.type === 'story_pin_product_sticker_block' && !b.is_removed).map((b: Block): string => b.pin_id || '').sort();
      if(pin.id !== created.id || pin.type !== 'pin' || pin.board?.id !== board || pin.pinner?.id !== viewer || pin.story_pin_data_id !== created.story_pin_data_id || pin.title !== dataTitle(flow) || pin.description !== data.description || pin.alt_text !== data.alt_text || pin.comments_disabled !== !data.is_comments_allowed || pin.shopping_rec_disabled !== !data.allow_shopping_rec || JSON.stringify(tagged) !== JSON.stringify(data.product_pins.slice().sort()) || !all.some((b: Block): boolean => b.type === 'story_pin_image_block' && b.image_signature === upload.signature))throw new Error('story-readback');
      return pin;
    }catch (_) {throw new Error('story-unconfirmed');}
  }
  async confirmProducts(id: string, board: string, flow: PinmonyPublishFlow, page: string, viewer: string, current: () => boolean): Promise<void> {
    if(!this.digits(id))throw new Error('story-id');
    const read: ReadOptions = {id:id,field_set_key:'auth_web_main_pin'};
    const pin: PinmonyStoryResult = await this.request('PinResource','get',read,page,viewer,current,'v3_get_pin',id);
    const blocks: Block[] = pin.story_pin_data?.pages?.reduce((rows: Block[], p: Page): Block[] => rows.concat(p.blocks || []),[]) || [];
    const ids: string[] = blocks.filter((b: Block): boolean => b.type === 'story_pin_product_sticker_block' && !b.is_removed).map((b: Block): string => b.pin_id || '').sort();
    if(pin.id !== id || pin.board?.id !== board || pin.pinner?.id !== viewer || JSON.stringify(ids) !== JSON.stringify((flow.selectedProducts || []).map((p: PinmonyCreatedPin): string => p.id).sort()))throw new Error('products-unconfirmed');
  }
}
function dataTitle(flow: PinmonyPublishFlow): string {return flow.photoTitle || '';}
