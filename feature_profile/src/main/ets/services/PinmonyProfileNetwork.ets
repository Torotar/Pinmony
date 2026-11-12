import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute, PinmonyTransferReply } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
export function buildPinmonyStoryMultipart(fields: Record<string,string>, mime: string, bytes: ArrayBuffer, boundary: string): ArrayBuffer {
  let head: string = '';
  Object.keys(fields).forEach((key: string): void => {
    const value: string = fields[key];
    if (!/^[A-Za-z0-9-]+$/.test(key) || /[^\x20-\x7e]/.test(value)) throw new Error('upload-field-encoding');
    head += '--' + boundary + '\r\nContent-Disposition: form-data; name="' + key + '"\r\n\r\n' + value + '\r\n';
  });
  const filename: string = mime === 'image/png' ? 'pin.png' : mime === 'image/webp' ? 'pin.webp' : 'pin.jpg';
  head += '--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="' + filename + '"\r\nContent-Type: ' + mime + '\r\n\r\n';
  const tail: string = '\r\n--' + boundary + '--\r\n';
  const result: Uint8Array = new Uint8Array(head.length + bytes.byteLength + tail.length);
  for (let index: number = 0; index < head.length; index++) result[index] = head.charCodeAt(index);
  result.set(new Uint8Array(bytes),head.length);
  for (let index: number = 0; index < tail.length; index++) result[head.length + bytes.byteLength + index] = tail.charCodeAt(index);
  return result.buffer as ArrayBuffer;
}
interface NativeUserAvatarReadEnvelope { options: NativeUserAvatarReadOptions; context: Record<string,string>; }
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface NativeSearchApiOptions { url: string; data: Record<string,Object>; }
interface PinmonyGraphQuery {
  queryHash: string;
  variables: Object;
}
interface ProfileAvatarUploadResponse { success?: boolean; image_upload_tracking_id?: string; }
interface StoryUploadRegistration { resource_response: StoryUploadResource; }
interface StoryUploadResource { status: string; code: number; endpoint_name: string; data: Record<string,CommentUploadData>; }
interface StoryMediaInfo { id: string; media_type: string; }
interface StoryRegisterOptions { url: string; data: StoryRegisterData; }
interface StoryRegisterData { media_info_list: string; }
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
interface NativeUserAvatarReadOptions { username: string; field_set_key: string; }

export class PinmonyProfileNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
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
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated: permitted && owner() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: captured.generation, page: page, userAgent: actual.userAgent };});
  }

async requestBusinessSharePublish(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    mode: string, objectId: string, viewer: string, contacts: string[], boards: string[], ownerCurrent: () => boolean, topics: string[] = [], sections: string[] = []): Promise<PinmonyNetworkReply> {
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
          else if(resource === '/resource/AdvancedTypeaheadResource/get/')permitted = mode === 'photo' && digits(viewer) && source === '/idea-pin-builder/' && handler === 'www/idea-pin-builder.js' && keys.length === 8 && o['field_set_key'] === 'richResults' && o['limit'] === 8 && o['num_recent_queries'] === 20 && o['personal_search_only'] === false && o['pin_scope'] === 'pins' && o['recent_queries_tags'] === 'recent_queries,recent_personal_searches' && o['autocomplete_request_surface'] === 0 && typeof o['term'] === 'string' && (o['term'] as string).length <= 200;
          else if(resource === '/resource/BaseSearchResource/get/')permitted = mode === 'photo' && digits(viewer) && source === '/idea-pin-builder/' && handler === 'www/idea-pin-builder.js' && keys.length === 3 && o['enable_promoted_pins'] === false && o['scope'] === 'buyable_pins' && typeof o['query'] === 'string' && (o['query'] as string).length <= 200;
          else if(resource === '/resource/ApiResource/get/') {
            const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
            permitted = mode === 'photo' && digits(viewer) && source === '/settings/permissions/' && handler === 'www/settings/permissions.js' && keys.length === 2 && o['url'] === '/v3/users/settings/' && !!data && Object.keys(data).length === 0 ||
              mode === 'photo' && digits(viewer) && source === '/pin-creation-tool/' && handler === 'www/pin-creation-tool.js' && keys.length === 2 && o['url'] === '/v3/manual_tags/search/' && !!data && Object.keys(data).length === 5 && ['zh-cn','en'].includes(data['language'] as string) && typeof data['query'] === 'string' && !!data['query'] && (data['query'] as string).length <= 200 && data['corpus'] === 'interests' && data['limit'] === 20 && data['min_level'] === 3;
            if (!permitted) {
              const target: RegExpMatchArray | null = typeof o['url'] === 'string' ? (o['url'] as string).match(/^\/v3\/board\/(\d{1,40})\/sections\/all\/$/) : null;
              permitted = mode === 'photo' && digits(viewer) && source === '/pin-creation-tool/' && handler === 'www/pin-creation-tool.js' && keys.length === 2 && !!target && boards.includes(target[1]) && !!data && Object.keys(data).length === 2 && data['orbac_subject_id'] === '' && JSON.stringify(data['fields']) === JSON.stringify(['boardsection.board','boardsection.id','boardsection.slug','boardsection.title','boardsection.type','boardsection.preview_pins(limit:1)']);
            }
            if(!permitted)permitted = mode === 'photo' && digits(viewer) && source === '/idea-pin-builder/' && handler === 'www/idea-pin-builder.js' && keys.length === 2 && o['url'] === '/v3/products/find/' && !!data && Object.keys(data).length === 2 && web(data['url']) && data['source'] === 'creator';
            if(!permitted) {
              const draftFields: string[] = ['storypinimageblock.block_style','storypinimageblock.block_type','storypinimageblock.c2pa_parent_tracking_id','storypinimageblock.image[750x, 1200x, orig]','storypinimageblock.image_signature','storypinimageblock.type','storypinvideoblock.block_style','storypinvideoblock.block_type','storypinvideoblock.type','storypinvideoblock.video[V_720P]','storypinvideoblock.video_signature','storypindata.id','storypindata.mentioned_users()','storypindata.metadata','storypindata.page_count','storypindata.pages','storypindata.type','storypindata.draft()'];
              permitted = mode === 'photo' && digits(viewer) && source === '/pin-creation-tool/' && handler === 'www/pin-creation-tool.js' && keys.length === 3 && o['url'] === '/v3/users/' + viewer + '/storypins/drafts/' && o['redux_normalize_feed'] === true && !!data && Object.keys(data).length === 3 && data['user'] === viewer && data['page_size'] === 50 && JSON.stringify(data['fields']) === JSON.stringify(draftFields);
            }
          }
          else if(resource === '/resource/FindPinImagesResource/get/')permitted = mode === 'website' && source === path && handler === 'www/pin-builder.js' && keys.length === 5 && web(o['url']) && o['source'] === 'pin_create' && o['appendItems'] === false && o['followRedirects'] === true && o['scrapeMetric'] === 'www_url_scrape';
        }else if(envelope && !get) {
          if(resource === '/resource/ConversationsResource/create/') {
            const ids: string[] = o['user_ids'] as string[];
            permitted = share && source === path && handler === (mode === 'pin' ? 'www/pin/[id].js' : 'www/index.js') && Array.isArray(ids) && ids.length === 1 && digits(ids[0]) && contacts.includes(ids[0]) &&
              (mode === 'pin' ? keys.length === 5 && o['pin'] === objectId && Array.isArray(o['emails']) && !(o['emails'] as string[]).length && o['source'] === 'Unknown' && typeof o['client_tracking_params'] === 'string' && !!o['client_tracking_params'] && (o['client_tracking_params'] as string).length <= 16384 : keys.length === 2 && o[mode === 'board' ? 'board' : 'user'] === objectId);
          }else if(resource === '/resource/BoardResource/create/')permitted = publish && digits(viewer) && source === '/board/create/' && handler === 'www/board/create.js' && keys.length === 2 && typeof o['name'] === 'string' && !!o['name'] && (o['name'] as string).trim() === o['name'] && (o['name'] as string).length <= 100 && ['public','secret'].includes(o['privacy'] as string);
          else if(resource === '/resource/PinResource/update/')permitted = mode === 'photo' && digits(objectId) && digits(viewer) && source === '/pin/' + objectId + '/' && handler === 'www/pin/[id].js' && keys.length === 6 && keys.every((key: string): boolean => ['id','board_id','board_section_id','ai_disclosures','title','description'].includes(key)) && o['id'] === objectId && boards.includes(o['board_id'] as string) && (o['board_section_id'] === '' || digits(o['board_section_id']) && sections.includes(o['board_section_id'] as string)) && Array.isArray(o['ai_disclosures']) && (o['ai_disclosures'] as number[]).length <= 10 && (o['ai_disclosures'] as number[]).every((n: number): boolean => Number.isInteger(n) && n >= 0 && n <= 100) && typeof o['title'] === 'string' && (o['title'] as string).length <= 100 && typeof o['description'] === 'string' && (o['description'] as string).length <= 800;
          else if(['/resource/ApiResource/create/','/resource/ApiResource/update/'].includes(resource) && typeof o['url'] === 'string' && (o['url'] as string).startsWith('/v3/storypins/drafts/')) {
            const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
            const updating: boolean = resource.endsWith('/update/');
            const initialDraft: boolean = !updating && !!data && Object.keys(data).length === 6;
            const fields: string[] = ['board_id','is_comments_allowed','is_shopping_rec_allowed','story_pin','topic_tags','tagged_products'];
            const optional: string[] = ['alt_text','board_section_id','description','link','user_mention_tags'];
            optional.forEach((key: string): void => { if (data && Object.keys(data).includes(key)) fields.push(key); });
            if (updating) fields.push('ai_disclosures');
            permitted = mode === 'photo' && digits(viewer) && source === '/pin-creation-tool/' && handler === 'www/pin-creation-tool.js' && keys.length === 2 &&
              o['url'] === '/v3/storypins/drafts/' + (updating ? objectId + '/' : '') && (!updating || digits(objectId)) && !!data && Object.keys(data).length === fields.length && fields.every((key: string): boolean => Object.keys(data).includes(key)) &&
              digits(data['board_id']) && boards.includes(data['board_id'] as string) && (data['board_section_id'] === undefined || digits(data['board_section_id'])) &&
              (data['alt_text'] === undefined || typeof data['alt_text'] === 'string' && (data['alt_text'] as string).length <= 500) && (data['description'] === undefined || typeof data['description'] === 'string' && (data['description'] as string).length <= 800) && (data['link'] === undefined || typeof data['link'] === 'string' && (data['link'] === '' || web(data['link']))) && typeof data['is_comments_allowed'] === 'boolean' && typeof data['is_shopping_rec_allowed'] === 'boolean' &&
              typeof data['story_pin'] === 'string' && (data['story_pin'] as string).length <= 1000000 && typeof data['topic_tags'] === 'string' && (data['tagged_products'] === null || typeof data['tagged_products'] === 'string') && (data['user_mention_tags'] === undefined || typeof data['user_mention_tags'] === 'string');
            if (permitted) {
              const story: Record<string,Object> = JSON.parse(data['story_pin'] as string) as Record<string,Object>;
              const pages: Record<string,Object>[] = story['pages'] as Record<string,Object>[];
              const metadata: Record<string,Object> = story['metadata'] as Record<string,Object>;
              const tags: Record<string,Object>[] = JSON.parse(data['tagged_products'] === null ? '[]' : data['tagged_products'] as string) as Record<string,Object>[];
              const selected: Record<string,Object>[] = JSON.parse(data['topic_tags'] as string) as Record<string,Object>[];
              const mentions: Object[] = JSON.parse(data['user_mention_tags'] === undefined ? '[]' : data['user_mention_tags'] as string) as Object[];
              permitted = !!metadata && typeof metadata['pin_title'] === 'string' && (metadata['pin_title'] as string).length <= 100 && Array.isArray(pages) && pages.length > 0 && pages.length <= 20 &&
                pages.every((page: Record<string,Object>): boolean => Array.isArray(page['blocks']) && (page['blocks'] as Object[]).length <= 50 && (page['blocks'] as Record<string,Object>[]).every((block: Record<string,Object>): boolean => [0,2].includes(block['type'] as number) && !!block['block_style'] && (block['type'] !== 2 || typeof block['image_signature'] === 'string' && /^[a-f0-9]{32}$/.test(block['image_signature'] as string)))) &&
                Array.isArray(tags) && tags.length <= 10 && tags.every((tag: Record<string,Object>): boolean => digits(tag['pin_id']) && tag['product_id'] === tag['pin_id'] && tag['status'] === 'created' && !!tag['media'] && web((tag['media'] as Record<string,Object>)['url'])) &&
                Array.isArray(selected) && selected.length === topics.length && selected.every((tag: Record<string,Object>,index: number): boolean => tag['id'] === topics[index] && digits(tag['id'])) && Array.isArray(mentions) && mentions.length <= 50 &&
                (!updating || Array.isArray(data['ai_disclosures']) && (data['ai_disclosures'] as number[]).length <= 10 && (data['ai_disclosures'] as number[]).every((n: number): boolean => Number.isInteger(n) && n >= 0 && n <= 100));
            }
          }
          else if(resource === '/resource/ApiResource/delete/') {
            const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
            permitted = mode === 'photo' && digits(viewer) && digits(objectId) && source === '/pin-creation-tool/' && handler === 'www/pin-creation-tool.js' && keys.length === 2 && o['url'] === '/v3/storypins/drafts/' + objectId + '/' && !!data && !Array.isArray(data) && Object.keys(data).length === 0;
          }
          else if(resource === '/resource/ApiResource/create/') {
            const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
            const ids: string[] | undefined = data?.['interest_ids'] as string[] | undefined;
            permitted = mode === 'photo' && digits(viewer) && digits(objectId) && source === '/pin-creation-tool/' && handler === 'www/pin-creation-tool.js' && keys.length === 2 && o['url'] === '/v3/interest_tagger/pin/' + objectId + '/interests/' && !!data && Object.keys(data).length === 3 && data['data_source'] === 'zen' && data['zen_source'] === 3 && Array.isArray(ids) && ids.length > 0 && ids.length <= 10 && ids.length === topics.length && ids.every((id: string,index: number): boolean => digits(id) && ids.indexOf(id) === index && topics[index] === id);
          }
          else if(resource === '/resource/PinResource/create/')permitted = publish && mode !== 'create-board' && digits(viewer) && keys.length === 10 && boards.includes(o['board_id'] as string) && digits(o['board_id']) && source === '/pin/create/' + (mode === 'photo' ? 'uploaded' : 'pinbuilder') + '/' && handler === 'www/pin/create/[method].js' && o['method'] === (mode === 'photo' ? 'uploaded' : 'scraped');
          if(resource === '/resource/PinResource/update/' && keys.length === 15) {
            permitted = mode === 'photo' && digits(viewer) && digits(objectId) && source === '/pin/' + objectId + '/' && handler === 'www/pin/[id].js' && keys.every((key: string): boolean => ['pin_additional_note','alt_text','board_id','board_section_id','description','disable_comments','disable_did_it','id','is_shuffle_remixable','link','shopping_rec_disabled','title','user_mention_tags','product_pins','idea_pin_details_template_type'].includes(key)) && o['id'] === objectId && boards.includes(o['board_id'] as string) && (o['board_section_id'] === '' || digits(o['board_section_id']) && sections.includes(o['board_section_id'] as string)) && o['pin_additional_note'] === '' && typeof o['alt_text'] === 'string' && (o['alt_text'] as string).length <= 500 && typeof o['description'] === 'string' && (o['description'] as string).length <= 800 && typeof o['title'] === 'string' && (o['title'] as string).length <= 100 && typeof o['disable_comments'] === 'boolean' && typeof o['disable_did_it'] === 'boolean' && typeof o['shopping_rec_disabled'] === 'boolean' && o['is_shuffle_remixable'] === false && (o['link'] === '' || web(o['link'])) && o['user_mention_tags'] === '[]' && JSON.stringify(o['product_pins']) === '[]' && o['idea_pin_details_template_type'] === null;
          }
        }
      }
    }catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessProfileInitialSort(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length);
      const match: RegExpMatchArray | null = job.url.slice(job.url.indexOf('?') + 1).match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(match ? match[2] : '')) as NativeSearchEnvelope;
      const options: Record<string,Object | null> = envelope.options;
      const data: Record<string,Object | null> = options['data'] as Record<string,Object | null>;
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.page.startsWith(captured.origin + '/') && /^\/[A-Za-z0-9_]+\/$/.test(path) &&
        job.id.startsWith('native_profile_sort_initial_') && job.epoch === captured.generation &&
        job.method === 'GET' && job.body === '' && job.url.startsWith(captured.origin + '/resource/ApiResource/get/?') &&
        !!match && decodeURIComponent(match[1]) === path && Object.keys(envelope).length === 2 &&
        !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !Array.isArray(options) && Object.keys(options).length === 2 && options['url'] === '/v3/users/' + path.split('/')[1] + '/metadata/' &&
        !!data && !Array.isArray(data) && Object.keys(data).length === 0 &&
        job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded';
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};
    });
  }

async requestBusinessProfileSort(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    userId: string, viewerId: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), write: boolean = job.method === 'POST';
      const form: string = write ? job.body : job.url.slice(job.url.indexOf('?') + 1);
      const match: RegExpMatchArray | null = form.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(match ? match[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
      const visibilityRead: boolean = !write && o['url'] === '/v3/users/settings/' && Object.keys(o).length === 2 && !!data && !Array.isArray(data) && Object.keys(data).length === 0;
      const visibilityWrite: boolean = write && job.url === captured.origin + '/resource/UserSettingsResource/update/' && Object.keys(o).length === 2 && o['surface_tag'] === 'holistic_profile_prompt' && typeof o['show_all_pins'] === 'boolean';
      const reorder: boolean = write && !Array.isArray(o) && Object.keys(o).length === 2 && o['url'] === '/v3/users/boards/partial_reorder/' && !!data && !Array.isArray(data) &&
        Object.keys(data).length === 1 && Array.isArray(data['board_ids']) && (data['board_ids'] as Object[]).length <= 2000 &&
        (data['board_ids'] as Object[]).every((id: Object): boolean => typeof id === 'string' && /^\d{1,40}$/.test(id as string));
      const metadata: boolean = !Array.isArray(o) && Object.keys(o).length === 2 && o['url'] === (write ? '/v3/users/me/metadata/' : '/v3/users/' + path.split('/')[1] + '/metadata/') && !!data && !Array.isArray(data) &&
        (write ? Object.keys(data).length === 2 && data['orbac_subject_id'] === '' && ['alphabetical','last_pinned_to','custom'].includes(data['most_recent_board_sort_order'] as string) : Object.keys(data).length === 0);
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        /^\d{1,40}$/.test(userId) && userId === viewerId && /^\/[A-Za-z0-9_]+\/$/.test(path) && job.page === captured.origin + path &&
        job.epoch === captured.generation && job.id.startsWith('native_profile_sort_') && !!match && decodeURIComponent(match[1]) === path &&
        Object.keys(envelope).length === 2 && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['Accept'] === 'application/json' && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        (write ? job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && (visibilityWrite || metadata && job.url === captured.origin + '/resource/ApiResource/create/' || reorder && job.url === captured.origin + '/resource/ApiResource/create/') :
          job.method === 'GET' && job.body === '' && job.url.startsWith(captured.origin + '/resource/ApiResource/get/?') && (metadata || visibilityRead));
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
  }

async requestBusinessProfileSuggestion(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    clusterId: string, name: string, ownerCurrent: () => boolean, clusterPins: string[] = []): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options;
      const path: string = job.page.slice(captured.origin.length);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.page.startsWith(captured.origin + '/') && /^\/[A-Za-z0-9_]+\/$/.test(path) && job.epoch === captured.generation && job.id.startsWith('native_profile_suggestion_') &&
        job.method === 'POST' && !!form && decodeURIComponent(form[1]) === path && /^[A-Za-z0-9_-]{1,160}$/.test(clusterId) && !!name && name.length <= 300 &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && Object.keys(payload).length === 2 && Object.keys(payload.context).length === 0;
      if(job.url === captured.origin + '/resource/BoardResource/create/')permitted = basic && Object.keys(o).length === 2 && o['name'] === name && JSON.stringify(o['aux_data']) === '{"source":"create_pin_cluster_page"}';
      if(job.url === captured.origin + '/resource/ApiResource/update/') {
        const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
        permitted = basic && Object.keys(o).length === 2 && o['url'] === '/v3/pins/cluster/' + clusterId + '/bulk/move/' && !!data && Object.keys(data).length === 2 &&
          /^\d{1,40}$/.test(data['board_id'] as string) && Array.isArray(data['deselected_pin_ids']) && (data['deselected_pin_ids'] as string[]).length <= 2000 && (data['deselected_pin_ids'] as string[]).every((id: string,index: number,ids: string[]): boolean => /^\d{1,40}$/.test(id) && ids.indexOf(id) === index && clusterPins.includes(id));
      }
    } catch (_) {}
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessUserAvatarRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    const path: string = profileUrl.slice(captured.origin.length), match: RegExpMatchArray | null = path.match(/^\/[A-Za-z0-9_]+\/$/);
    if (match) {
      const username: string = path.slice(1,-1);
      const envelope: NativeUserAvatarReadEnvelope = {options:{username:username,field_set_key:'profile'},context:{}};
      const expected: string = captured.origin + '/resource/UserResource/get/?source_url=' + encodeURIComponent(path) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        profileUrl === captured.origin + path && job.url === expected && /^native_avatar_\d+$/.test(job.id) &&
        job.epoch === captured.generation && job.method === 'GET' && job.body === '' &&
        job.page.startsWith(captured.origin + '/') && job.page.length <= 8192 && !/[\r\n#]/.test(job.page) &&
        !['pin','settings','inbox','messages','search','login','signup','business','ideas','today','news_hub','notifications','updates'].includes(username.toLowerCase()) &&
        job.headers['Accept'] === 'application/json' && job.headers['X-Pinterest-AppState'] === 'active' &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' && job.headers['X-Pinterest-Source-Url'] === path;
    }
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
        epoch:captured.generation,page:job.page,userAgent:actual.userAgent};
    });
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
        !!source && (job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' || job.url.startsWith(captured.origin + '/resource/BoardsResource/get/?') && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username].js' && job.headers['X-Pinterest-Source-Url'] === decodeURIComponent(source[1]) && job.headers['X-Pinterest-AppState'] === 'active') && Object.keys(payload).length === 2 &&
        !Array.isArray(o) && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        (bookmarks === undefined || Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && bookmarks[0].length > 0 && bookmarks[0].length <= 4096);
      const own: boolean = typeof userId === 'string' && /^\d{1,40}$/.test(userId) && (!visitor || /^\d{1,40}$/.test(viewerId));
      const self: boolean = !visitor || userId === viewerId;
      if(job.url.startsWith(captured.origin + '/resource/UserResource/get/?')) {
        permitted = basic && decodeURIComponent(source![1]) === path && keys.length === 2 && o['field_set_key'] === 'profile' && o['username'] === username;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardsFeedResource/get/?')) {
        permitted = basic && own && decodeURIComponent(source![1]) === path && (keys.length === 4 || keys.length === 5 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','filter_stories','sort','username','bookmarks'].includes(k)) && o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === false && o['sort'] === 'last_pinned_to' && typeof o['username'] === 'string' && (o['username'] as string).toLowerCase() === username.toLowerCase();
      } else if(job.url.startsWith(captured.origin + '/resource/BoardsResource/get/?')) {
        permitted = basic && own && userId === viewerId && decodeURIComponent(source![1]) === path && (keys.length === 10 || keys.length === 11 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','filter_stories','sort','username','bookmarks','privacy_filter','page_size','group_by','include_archived','filter_all_pins','add_fields'].includes(k)) &&
          o['privacy_filter'] === 'all' && o['page_size'] === 25 && o['group_by'] === 'mix_public_private' && o['include_archived'] === false && o['filter_all_pins'] === true && o['add_fields'] === 'board.{meal_plan}' &&
          o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === false && ['alphabetical','last_pinned_to','custom'].includes(o['sort'] as string) && typeof o['username'] === 'string' && (o['username'] as string).toLowerCase() === username.toLowerCase();
        if(o['filter_types'] !== undefined) permitted = basic && own && userId === viewerId && decodeURIComponent(source![1]) === path &&
          keys.every((k: string): boolean => ['boardOrder','filterStories','isOwnProfile','isRetrievalHub','isViewerProfile','mixPublicSecret','sort','field_set_key','filter_types','privacyFilter','add_fields','username','bookmarks'].includes(k)) &&
          keys.length === (bookmarks ? 13 : 12) && [2,3].includes(o['filter_types'] as number) && o['privacyFilter'] === 'all' && o['field_set_key'] === 'profile_grid_item' && o['filterStories'] === false &&
          o['isOwnProfile'] === true && o['isRetrievalHub'] === true && o['isViewerProfile'] === true && o['mixPublicSecret'] === true && o['username'] === username &&
          o['add_fields'] === 'board.{meal_plan}' && o['boardOrder'] === o['sort'] && ['alphabetical','custom','last_pinned_to'].includes(o['sort'] as string);
      } else if(job.url.startsWith(captured.origin + '/resource/ApiResource/get/?')) {
        const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>;
        permitted = basic && own && userId === viewerId && decodeURIComponent(source![1]) === path && keys.length === (bookmarks ? 3 : 2) &&
          keys.every((k: string): boolean => ['url','data','bookmarks'].includes(k)) && !!data && !Array.isArray(data) && (
          o['url'] === '/v3/users/me/filtered/pins/' && Object.keys(data).length === 2 && ['', 'FAVORITED','CREATED_BY_ME','FAVORITED,CREATED_BY_ME'].includes(data['flag_filters'] as string) &&
            data['fields'] === 'pin.id,pin.type,pin.images[236x,474x,736x,orig],pin.grid_title,pin.title,pin.favorited_by_me' ||
          o['url'] === '/v3/users/me/shuffles/' && Object.keys(data).length === 3 && typeof data['is_draft'] === 'boolean' && data['transform_to_pins'] === !data['is_draft'] &&
            JSON.stringify(data['fields']) === JSON.stringify(data['is_draft'] ? ['shuffle.id','shuffle.images','shuffle.updated_at'] : ['pin.access','pin.type','pin.id','pin.images','pin.description','pin.pinner','pin.shuffle()']) ||
          /^\/v3\/users\/profile\/pins\/cluster\/[A-Za-z0-9_-]{1,160}\/feed\/$/.test(o['url'] as string) && Object.keys(data).length === 1 && JSON.stringify(data['fields']) === '["pin.id","pin.images[170x,136x136,236x,474x,736x,orig]"]' ||
          o['url'] === '/v3/users/profile/pins/clusters/' && Object.keys(data).length === 2 && data['exclude_quick_save_pins'] === true && data['max_cluster_limit'] === 10);
      } else if(job.url.startsWith(captured.origin + '/resource/UserActivityPinsResource/get/?')) {
        permitted = basic && own && decodeURIComponent(source![1]) === path + '_created/' && (keys.length === 5 || keys.length === 6 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','exclude_add_pin_rep','is_own_profile_pins','user_id','username','bookmarks'].includes(k)) && o['field_set_key'] === 'profile_created_grid_item' && o['exclude_add_pin_rep'] === true && o['is_own_profile_pins'] === self && o['user_id'] === userId && typeof o['username'] === 'string' && (o['username'] as string).toLowerCase() === username.toLowerCase();
      } else if(job.url.startsWith(captured.origin + '/resource/BoardlessPinsResource/get/?')) {
        permitted = basic && own && self && decodeURIComponent(source![1]) === path && (keys.length === 3 || keys.length === 4 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['field_set_key','redux_normalize_feed','userId','bookmarks'].includes(k)) && o['field_set_key'] === 'mobile' && o['redux_normalize_feed'] === true && o['userId'] === userId;
      }
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
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
    return this.transport.request(job, (): PinmonyNetworkContext => {
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
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
  }

async uploadProfileAvatar(bytes: ArrayBuffer, mime: string, page: string, ownPage: string,
      session: () => PinmonyBusinessSessionContext, owner: () => boolean, id: string,
      dispatched: () => void): Promise<string> {
    const state: PinmonyBusinessSessionContext = session();
    const captured: PinmonyBusinessSessionContext = { authenticated: state.authenticated, accountId: state.accountId,
      generation: state.generation, origin: state.origin, userAgent: state.userAgent };
    const generation: number = this.transport.currentGeneration();
    const head: Uint8Array = new Uint8Array(bytes);
    const validImage: boolean = mime === 'image/jpeg' && head[0] === 255 && head[1] === 216 && head[2] === 255 ||
      mime === 'image/png' && head[0] === 137 && head[1] === 80 && head[2] === 78 && head[3] === 71 ||
      mime === 'image/webp' && head[0] === 82 && head[1] === 73 && head[8] === 87 && head[9] === 69;
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = session();
      return generation === this.transport.currentGeneration() && owner() && actual.authenticated &&
        actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin;
    };
    if (!PIN_BUSINESS_PIN_READ_ENABLED || !this.transport.isForeground() || !current() || !captured.accountId ||
        !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) || page !== ownPage ||
        !/^[A-Za-z0-9_]+\/$/.test(page.slice(captured.origin.length + 1)) || !page.startsWith(captured.origin + '/') ||
        !/^native_profile_avatar_\d+$/.test(id) || !validImage || bytes.byteLength < 12 || bytes.byteLength > 4 * 1024 * 1024 ||
        !this.transport.transferAvailable(id)) throw new Error('avatar-unavailable');
    const url: string = captured.origin + '/upload-profile-image/';
    const response: PinmonyTransferReply = await this.transport.transfer({ id: id, url: url, method: 'POST', page: page,
      userAgent: captured.userAgent, authenticated: true, headers: {},
      file: { field: 'img', bytes: bytes, mime: mime, name: 'avatar.' + (mime === 'image/jpeg' ? 'jpg' : mime === 'image/png' ? 'png' : 'webp') },
      timeoutMs: 20000, maxBytes: 65536 }, current, dispatched);
    if (!current() || response.status !== 200) throw new Error('avatar-unconfirmed');
    const body: ProfileAvatarUploadResponse = JSON.parse(response.text) as ProfileAvatarUploadResponse;
    if (body.success === false) throw new Error('avatar-rejected');
    if (body.success !== true || typeof body.image_upload_tracking_id !== 'string' ||
        !/^[A-Za-z0-9_-]{1,200}$/.test(body.image_upload_tracking_id)) throw new Error('avatar-unconfirmed');
    return body.image_upload_tracking_id;
  }

async uploadPublishImage(bytes: ArrayBuffer, mime: string, pin: string, context: () => PinmonyNetworkContext, viewer: string, ownerId: string, mediaIds: string[]): Promise<PinmonyPublishImageUpload> {
    if (!this.transport.isForeground()) throw new Error('background');
    const initial: PinmonyNetworkContext = context();
    const captured: PinmonyNetworkContext = {authenticated:initial.authenticated,epoch:initial.epoch,page:initial.page,userAgent:initial.userAgent};
    const generation: number = this.transport.currentGeneration();
    if (!captured.authenticated || captured.page.split(/[?#]/)[0] !== pin || !/^https:\/\/(?:www|uk)\.pinterest\.com\/[A-Za-z0-9_]+\/$/.test(pin) || !/^\d{1,40}$/.test(viewer) || !['image/jpeg','image/png','image/webp'].includes(mime) ||
        bytes.byteLength < 1 || bytes.byteLength > 20 * 1024 * 1024) throw new Error('image-unavailable');
    const current = (): boolean => generation === this.transport.currentGeneration() && context().authenticated &&
      context().epoch === captured.epoch && context().page === captured.page;
    if(!/^native_publish_upload_\d+$/.test(ownerId) || mediaIds.length !== 2 || mediaIds[0] === mediaIds[1] || mediaIds.some((id: string): boolean => !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(id)))throw new Error('upload-owner');
    const jobId: string = ownerId;
    const origin: string = pin.slice(0, pin.indexOf('/', 8));
    const resource = async (operation: string, options: string): Promise<string> => {
      if (!current()) throw new Error('stale');
      const body: string = 'source_url=' + encodeURIComponent('/pin-creation-tool/') +
        '&data=' + encodeURIComponent('{"options":' + options + ',"context":{}}');
      const job: PinmonyNetworkJob = { id: jobId + '_' + operation, epoch: captured.epoch, page: captured.page,
        url: origin + '/resource/ApiResource/' + operation + '/' + (operation === 'get' ? '?' + body : ''),
        method: operation === 'get' ? 'GET' : 'POST', body: operation === 'get' ? '' : body,
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Pinterest-Pws-Handler': 'www/pin-creation-tool.js' } };
      const response: PinmonyNetworkReply = await this.transport.request(job, context);
      if (!current() || response.error || response.status !== 200) throw new Error('upload-resource');
      return response.body;
    };
    const media: StoryMediaInfo[] = mediaIds.map((id: string): StoryMediaInfo => ({id:id,media_type:'image-story-pin'}));
    const options: StoryRegisterOptions = {url:'/v3/media/uploads/register/batch/',data:{media_info_list:JSON.stringify(media)}};
    const registration: StoryUploadRegistration = JSON.parse(await resource('create',JSON.stringify(options))) as StoryUploadRegistration;
    const business: StoryUploadResource = registration.resource_response;
    const upload: CommentUploadData | undefined = business?.data?.[media[0].id];
    if(!business || business.status !== 'success' || business.code !== 0 || business.endpoint_name !== 'register_media_upload_batch' || !upload || !/^\d{1,40}$/.test(upload.upload_id) || !['https://pinterest-media-upload.s3.amazonaws.com/','https://u.pinimg.com/'].includes(upload.upload_url) || !upload.upload_parameters || !upload.upload_parameters['key']?.includes(':image-story-pin:' + viewer + ':' + upload.upload_id + ':'))throw new Error('upload-registration');
    const fields: Record<string,string> = {};
    const required: string[] = ['x-amz-date', 'x-amz-signature', 'x-amz-security-token', 'x-amz-algorithm', 'key', 'policy', 'x-amz-credential', 'Content-Type'];
    if (Object.keys(upload.upload_parameters).some((key: string): boolean => !required.includes(key))) throw new Error('upload-fields');
    required.forEach((key: string) => {
      const value: string = upload.upload_parameters[key];
      if (typeof value !== 'string' || !value || value.length > 32768) throw new Error('upload-fields');
      fields[key] = value;
    });
    const boundary: string = '----PinmonyStoryUpload' + ownerId.replace(/[^A-Za-z0-9]/g,'');
    const multipart: ArrayBuffer = buildPinmonyStoryMultipart(fields,mime,bytes,boundary);
    if (!this.transport.isForeground()) throw new Error('background');
    if (!current()) throw new Error('stale');
    const response: PinmonyTransferReply = await this.transport.transfer({ id: jobId, url: upload.upload_url, method: 'POST', page: captured.page,
      userAgent: '', authenticated: false, headers: { 'Content-Type': 'multipart/form-data; boundary=' + boundary }, body: multipart,
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
          !item || String(item.upload_id) !== upload.upload_id || item.type !== 'image-story-pin') throw new Error('upload-status');
      if (item.status === 'succeeded' && /^[a-f0-9]{32}$/.test(item.signature)) return {signature:item.signature,uploadId:upload.upload_id};
      if (item.status !== 'registered' && item.status !== 'processing') throw new Error('upload-failed');
      await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 1000); });
    }
    throw new Error('upload-timeout');
  }
}
