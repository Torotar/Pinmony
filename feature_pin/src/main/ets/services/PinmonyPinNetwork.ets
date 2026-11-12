import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute, PinmonyTransferReply, acceptsNetworkJob } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
interface ProductVariables { isAuth: boolean; isAuthDesktop: boolean; isDesktop: boolean; isUnauth: boolean; pinId: string; shouldDefer: boolean; shouldFetchAIInsight: boolean; shouldFetchDesktopShoppingModule: boolean; shouldFetchMobileShoppingModule: boolean; shouldFetchUnauthAmazonModule: boolean; shouldShowSeoDrawerOption: boolean; }
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface PinmonyGraphQuery {
  queryHash: string;
  variables: Object;
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
interface PinReadData { options: PinReadOptions; }
interface PinReadOptions { id?: string; field_set_key?: string; pin_id?: string; bookmarks?: string[]; aggregated_pin_id?: string; page_size?: number; redux_normalize_feed?: boolean; is_reversed?: boolean; comment_featured_ids?: string[]; objectId?: string; isUnifiedComment?: boolean; url?: string; }

export class PinmonyPinNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
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
    return this.transport.request(job, (): PinmonyNetworkContext => {
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

async requestBusinessShuffleRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, shuffleId: string, current: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();
    let permitted: boolean = false;
    try {
      const path: string = pin.slice(captured.origin.length);
      const form: RegExpMatchArray | null = job.url.match(/\?source_url=([^&]+)&data=([^&]+)&_=\d+$/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const options: Record<string,Object | null> = payload.options;
      const data: Record<string,Object | null> = options['data'] as Record<string,Object | null>;
      const fields: string[] = ['shuffle.{id,items,effect_data}','shuffleitem.{id,pin,shuffle_item_image(),settings,item_type,text,offset,scale,rotation,effect_data,mask,bitmap_mask,shuffle_asset,shuffle_item_image,images[236x,736x,736x(heic),750x,750x(heic)]}','shuffleasset.{id,cutout_images[originals],source_images[236x]}'];
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && current() &&
        pin === captured.origin + path && /^\/pin\/\d{1,30}\/$/.test(path) && /^\d{1,40}$/.test(shuffleId) &&
        job.page === pin && job.epoch === captured.generation && job.id.startsWith('native_detail_aux_shuffle_') &&
        job.method === 'GET' && job.body === '' && job.url.startsWith(captured.origin + '/resource/ApiResource/get/?') &&
        !!form && decodeURIComponent(form[1]) === path && Object.keys(payload).length === 2 &&
        !!payload.context && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        !!options && !Array.isArray(options) && Object.keys(options).length === 3 && options['url'] === '/v3/shuffles/' + shuffleId + '/' &&
        options['fetchPolicy'] === 'store-or-network' && !!data && !Array.isArray(data) && Object.keys(data).length === 1 && JSON.stringify(data['fields']) === JSON.stringify(fields) &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' && job.headers['X-Pinterest-Source-Url'] === path &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest';
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return {authenticated:permitted && current() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
        epoch:captured.generation,page:pin,userAgent:actual.userAgent};
    });
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
        const contentRead: boolean = job.id.startsWith('native_detail_aux_content_') && q.queryHash === 'b39ed2f55c3ee5de2035ca16b0c943f09ad5737d6ea4cc6d20f6131a2f9589e8' && !!v && !Array.isArray(v) && Object.keys(v).length === 5;
        const mediaRead: boolean = job.id.startsWith('native_detail_aux_graph_') && q.queryHash === 'c025ad33faccf5d04c2ed38344405d0a6c46dd1d786c17f3954b6980ef798538' && !!v && !Array.isArray(v) && Object.keys(v).length === 7 && v['shouldPrefetchStoryPinFragment'] === false && v['shouldSkipImageViewerOnPageQuery'] === true;
        permitted = basic && (contentRead || mediaRead) && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' && job.headers['X-Pinterest-Source-Url'] === path &&
          Object.keys(q).length === 2 && v['pinId'] === id && v['isAuth'] === true && v['isDesktop'] === false &&
          v['isAuthDesktop'] === false && v['isUnauth'] === false;
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
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
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
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
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
        else if(get && job.body === '' && job.url.startsWith(captured.origin + '/resource/ApiResource/get/?')) {
          const target: RegExpMatchArray | null = typeof o['url'] === 'string' ? (o['url'] as string).match(/^\/v3\/board\/(\d{1,30})\/sections\/all\/$/) : null;
          const d: Record<string,Object> = o['data'] as Record<string,Object>;
          permitted = envelope && user && pinSource && keys.length === 2 && !!target && writableBoards.includes(target[1]) && !!d && !Array.isArray(d) && Object.keys(d).length === 2 && d['orbac_subject_id'] === '' &&
            JSON.stringify(d['fields']) === JSON.stringify(['boardsection.board','boardsection.id','boardsection.slug','boardsection.title','boardsection.type','boardsection.preview_pins(limit:1)']);
        }
        else if(job.method === 'POST' && envelope && user) {
          if(job.url === captured.origin + '/resource/RepinResource/create/') {
            const quick: boolean = o['board_id'] === undefined, tracking: boolean = o['clientTrackingParams'] !== undefined, section: boolean = o['section'] !== undefined;
            permitted = pinSource && o['pin_id'] === id && o['user_id'] === viewer && keys.length === (quick ? 2 : 3) + (tracking ? 1 : 0) + (section ? 1 : 0) && (!tracking || text(o['clientTrackingParams'],16384)) &&
              (!section || !quick && typeof o['section'] === 'string' && /^\d{1,30}$/.test(o['section'] as string) && writableBoards.includes('section:' + o['board_id'] + ':' + o['section'])) &&
              (quick ? writableBoards.includes('profile-quick-saves') : typeof o['board_id'] === 'string' && /^\d{1,30}$/.test(o['board_id'] as string) && writableBoards.includes(o['board_id'] as string));
          }else if(job.url === captured.origin + '/resource/BoardResource/create/') {
            const tracking: Object | null = o['initial_pin_client_tracking_params'];
            permitted = source === '/board/create/' + id && job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' &&
              typeof o['name'] === 'string' && !!o['name'] && (o['name'] as string).trim() === o['name'] && text(o['name'],300) && (o['privacy'] === 'public' || o['privacy'] === 'secret') &&
              (keys.length === 2 || keys.length === 3 && Array.isArray(tracking) && tracking.length === 1 && text(tracking[0] as Object,16384));
          }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
            const data: Record<string,Object> = o['data'] as Record<string,Object>;
            permitted = pinSource && keys.length === 2 && o['url'] === '/v3/pins/' + id + '/react/' && !!data && !Array.isArray(data) && Object.keys(data).length === 2 && data['reaction_type'] === 1 && typeof data['client_tracking_params'] === 'string' && !!data['client_tracking_params'] && text(data['client_tracking_params'],16384);
            if(o['url'] === '/v3/pins/bulk/move/') {
              const section: boolean = data?.['section_id'] !== undefined;
              const movable: string = copyOwned && /^\d{1,30}$/.test(copyId) && copyId !== id ? copyId : ownsPin ? id : '';
              permitted = pinSource && keys.length === 2 && !!movable && !!data && !Array.isArray(data) && Object.keys(data).length === (section ? 3 : 2) &&
                typeof data['board_id'] === 'string' && /^\d{1,30}$/.test(data['board_id'] as string) && writableBoards.includes(data['board_id'] as string) &&
                Array.isArray(data['pin_ids']) && (data['pin_ids'] as Object[]).length === 1 && (data['pin_ids'] as Object[])[0] === movable &&
                (!section || typeof data['section_id'] === 'string' && /^\d{1,30}$/.test(data['section_id'] as string) && writableBoards.includes('section:' + data['board_id'] + ':' + data['section_id']));
            }
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
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:pin,userAgent:actual.userAgent};});
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
      else if(basic && job.method === 'POST' && keys.length === 1 && o['url'] === '/v3/pins/' + match![1] + '/favorite/' &&
        job.headers['Content-Type'] === 'application/x-www-form-urlencoded' &&
        (job.url === captured.origin + '/resource/ApiResource/create/' || job.url === captured.origin + '/resource/ApiResource/delete/'))permitted = true;
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
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
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
        job.headers['X-Pinterest-Pws-Handler'] === (mode === 'quiz' ? 'www/search/[scope].js' : mode === 'invites' && job.url === captured.origin + '/resource/BoardInviteResource/delete/' ? 'www/inbox.js' : 'www/index.js');
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
        if(endpoint === '/resource/BoardInviteResource/' + (get ? 'get/' : 'update/') || !get && endpoint === '/resource/BoardInviteResource/delete/' && path === '/inbox/')permitted = basic && exact(get ? ['board_id','invited_user_id','field_set_key'] : ['board_id','invited_user_id']) && /^\d{1,30}$/.test(o['board_id'] as string) && /^\d{1,30}$/.test(o['invited_user_id'] as string) && target === o['board_id'] + ':' + o['invited_user_id'] && (!get || o['field_set_key'] === 'boardEdit');
      }
    }catch (_) {}
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessProductRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pin: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const query: Record<string, Object> = JSON.parse(job.body) as Record<string, Object>;
      const variables: Record<string, Object> = query['variables'] as Record<string, Object>;
      const expected: ProductVariables = { isAuth: true, isAuthDesktop: false, isDesktop: false,
        isUnauth: false, pinId: pin.split('/pin/')[1].split('/')[0], shouldDefer: false,
        shouldFetchAIInsight: false, shouldFetchDesktopShoppingModule: false, shouldFetchMobileShoppingModule: true,
        shouldFetchUnauthAmazonModule: false, shouldShowSeoDrawerOption: false };
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId &&
        /^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pin) && pin.startsWith(captured.origin + '/') &&
        job.page === pin && job.epoch === captured.generation && job.id.startsWith('native_product_') &&
        job.url === captured.origin + '/_/graphql/' && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' &&
        Object.keys(query).length === 2 && query['queryHash'] === '43164757b22ade73c6219d2108b664c014b574d314f725af6b16036188662335' &&
        !!variables && Object.keys(variables).length === Object.keys(expected).length &&
        Object.keys(expected).every((key: string): boolean => variables[key] === (expected as Object as Record<string, Object>)[key]);
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,
        epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
  }

async requestBusinessPinRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    pinUrl: string, ownerCurrent: () => boolean,
    legacyContext?: () => PinmonyNetworkContext, aggregatedPinId: string = '', commentId: string = ''): Promise<PinmonyNetworkReply> {
    if (!PIN_BUSINESS_PIN_READ_ENABLED) {
      if (!legacyContext) return this.transport.request(job, (): PinmonyNetworkContext => {
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
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      const current: boolean = permitted && ownerCurrent() && actual.authenticated &&
        actual.generation === captured.generation && actual.accountId === captured.accountId && actual.origin === captured.origin;
      return { authenticated: current, epoch: captured.generation, page: pinUrl, userAgent: actual.userAgent };
    });
  }

async uploadCommentImage(bytes: ArrayBuffer, pin: string, context: () => PinmonyNetworkContext, ownerId: string = ''): Promise<string> {
    if (!this.transport.isForeground()) throw new Error('background');
    const captured: PinmonyNetworkContext = context();
    const generation: number = this.transport.currentGeneration();
    if (!captured.authenticated || captured.page.split(/[?#]/)[0] !== pin || !/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pin) ||
        bytes.byteLength < 1 || bytes.byteLength > 20 * 1024 * 1024) throw new Error('image-unavailable');
    const current = (): boolean => generation === this.transport.currentGeneration() && context().authenticated &&
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
      const response: PinmonyNetworkReply = await this.transport.request(job, context);
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
    const fields: Record<string, string> = {};
    const required: string[] = ['x-amz-date', 'x-amz-signature', 'x-amz-security-token', 'x-amz-algorithm', 'key', 'policy', 'x-amz-credential', 'Content-Type'];
    if (Object.keys(upload.upload_parameters).some((key: string): boolean => !required.includes(key))) throw new Error('upload-fields');
    required.forEach((key: string) => {
      const value: string = upload.upload_parameters[key];
      if (typeof value !== 'string' || !value || value.length > 32768) throw new Error('upload-fields');
      fields[key] = value;
    });
    if (!this.transport.isForeground()) throw new Error('background');
    if (!current()) throw new Error('stale');
    const response: PinmonyTransferReply = await this.transport.transfer({ id: jobId, url: upload.upload_url, method: 'POST', page: captured.page,
      userAgent: '', authenticated: false, headers: {}, fields: fields, file: { field: 'file', bytes: bytes, mime: 'image/jpeg', name: 'comment.jpg' },
      timeoutMs: 60000, maxBytes: 1024 * 1024 }, current);
    if (!current() || response.status < 200 || response.status >= 300) throw new Error('image-upload');
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
}
