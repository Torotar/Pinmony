import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface NativeSearchApiOptions { url: string; data: Record<string,Object>; }
interface InboxNewsReadOptions { news_id?: string; url?: string; data?: Record<string,string>; bookmarks?: string[]; }
interface InboxNewsReadEnvelope { options: InboxNewsReadOptions; context: Record<string,string>; }
interface InboxUpdatesReadOptions { url: string; data: InboxUpdatesData; redux_normalize_feed: boolean; field_sets: string[]; bookmarks?: string[]; }
interface InboxUpdatesData { field_set_key: string; }
interface InboxUpdatesEnvelope { options: InboxUpdatesReadOptions; context: Record<string,string>; }

export class PinmonyInboxNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
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
        permitted = basic && !conversationId && (keys.length === 2 && Array.isArray(emails) && emails.length === 0 || keys.length === 1 && emails === undefined && Array.isArray(ids) && ids.length === 1) && Array.isArray(ids) && ids.length > 0 && ids.length <= 1000 &&
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
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessInboxActivity(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    target: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const write: boolean = !!target;
      const encoded: string = write ? job.body : job.url.slice(job.url.indexOf('?') + 1);
      const match: RegExpMatchArray | null = encoded.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(match ? match[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options;
      const data: Record<string,Object> = o['data'] as Record<string,Object>;
      const fields: string[] = o['field_sets'] as string[];
      const expected: string[] = ['socialrelationship.user()','socialrelationship.relationship_type','socialrelationship.last_action_time','socialrelationship.followed_by_me','user.id','user.full_name','user.image_large_url','user.username'];
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && ownerCurrent() && captured.authenticated && !!captured.accountId &&
        /^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) && job.page === captured.origin + '/inbox/' &&
        job.id.startsWith('native_inbox_activity_') && job.epoch === captured.generation && !!match && decodeURIComponent(match[1]) === '/inbox/' &&
        Object.keys(envelope).length === 2 && !!envelope.context && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && !Array.isArray(o) && !!data && !Array.isArray(data) &&
        job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-Pws-Handler'] === 'www/inbox.js' && job.headers['X-Pinterest-Source-Url'] === '/inbox/';
      permitted = basic && (write ? /^\d{1,40}$/.test(target) && job.method === 'POST' &&
        job.url === captured.origin + '/resource/ApiResource/update/' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' &&
        Object.keys(o).length === 2 && o['url'] === '/v3/users/' + target + '/follow/' && Object.keys(data).length === 0 :
        job.method === 'GET' && job.body === '' && job.url === captured.origin + '/resource/ApiResource/get/?' + encoded &&
        Object.keys(o).length === 3 && o['url'] === '/v3/social_relationships/inbox/' && Object.keys(data).length === 1 && data['page_size'] === 20 &&
        Array.isArray(fields) && fields.length === expected.length && expected.every((field: string,index: number): boolean => field === fields[index]));
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
      authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
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
        const fields: string[] = api.data['fields'] as string[]; const expected: string[] = ['conversation.id','conversation.name','conversation.users()','conversation.read_times_ms','user.id','user.username','user.full_name','user.image_medium_url','user.avatar_color_index','user.type'];
        permitted = basic && keys.length === 2 && keys.includes('url') && keys.includes('data') && /^\/v3\/conversations\/\d{1,40}\/$/.test(api.url) &&
          !Array.isArray(api.data) && Object.keys(api.data).length === 1 && Array.isArray(fields) && fields.length === expected.length && expected.every((field: string,index: number): boolean => fields[index] === field);
      }
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
  }

async requestBusinessInboxNewsRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    newsId: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const envelope: InboxNewsReadEnvelope = JSON.parse(decodeURIComponent(encoded ? encoded[1] : '')) as InboxNewsReadEnvelope;
      const o: InboxNewsReadOptions = envelope.options;
      const path: string = '/news_hub/' + newsId + '/';
      const summary: boolean = job.url.startsWith(captured.origin + '/resource/ApiResource/get/?');
      const keys: string[] = Object.keys(o);
      const cursor: boolean = !keys.includes('bookmarks') || Array.isArray(o.bookmarks) && o.bookmarks.length === 1 &&
        typeof o.bookmarks[0] === 'string' && o.bookmarks[0].length > 0 && o.bookmarks[0].length <= 4096 && o.bookmarks[0] !== '-end-';
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        /^\d{1,40}$/.test(newsId) && /^native_inbox_news_\d+$/.test(job.id) && job.epoch === captured.generation &&
        job.page.startsWith(captured.origin + '/') && /^\/(?:inbox|messages|updates|notifications)\/$/.test(job.page.slice(captured.origin.length)) &&
        job.method === 'GET' && job.body === '' && !!source && decodeURIComponent(source[1]) === path &&
        job.headers['X-Pinterest-Source-Url'] === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/news_hub/[id].js' &&
        Object.keys(envelope).length === 2 && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 && !Array.isArray(o) &&
        (summary ? keys.length === 2 && o.url === '/v3/news_hub/' + newsId + '/' && !!o.data && !Array.isArray(o.data) &&
          Object.keys(o.data).length === 1 && o.data['fields'] === 'user.full_name,user.image_large_url,user.type,user.username' :
          job.url.startsWith(captured.origin + '/resource/NewsHubDetailsResource/get/?') && cursor &&
          keys.every((key: string): boolean => ['news_id','bookmarks'].includes(key)) && o.news_id === newsId);
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
        epoch: captured.generation, page: job.page, userAgent: actual.userAgent }; });
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
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin, epoch: captured.generation, page: job.page, userAgent: actual.userAgent }; });
  }
}
