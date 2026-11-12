import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface PinmonyGraphQuery {
  queryHash: string;
  variables: Object;
}

export class PinmonyBoardNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
async requestBusinessBoardFollow(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
      page: string, board: string, viewer: string, owner: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const m: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(m ? m[2] : '')) as NativeSearchEnvelope;
      const o: Record<string, Object | null> = e.options, source: string = page.slice(captured.origin.length);
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && owner() && captured.authenticated && !!captured.accountId &&
        /^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) && page.startsWith(captured.origin + '/') &&
        /^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(page.slice(captured.origin.length)) && /^\d{1,40}$/.test(board) && /^\d{1,40}$/.test(viewer) &&
        job.id.startsWith('native_board_follow_') && job.epoch === captured.generation && job.page === page && job.method === 'POST' &&
        [captured.origin + '/resource/ApiResource/update/',captured.origin + '/resource/ApiResource/delete/'].includes(job.url) &&
        !!m && decodeURIComponent(m[1]) === source && Object.keys(e).length === 2 && Object.keys(e.context).length === 0 &&
        Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + board + '/follow/' &&
        job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js' && job.headers['X-Pinterest-Source-Url'] === source;
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated: permitted && owner() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: captured.generation, page: page, userAgent: actual.userAgent };});
  }

async requestBusinessBoardSectionRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext, board: string, section: string, sectionPath: string, current: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const query: RegExpMatchArray | null = job.url.match(/\?source_url=([^&]+)&data=([^&]+)&_=\d+$/);
      const e: NativeSearchEnvelope = JSON.parse(decodeURIComponent(query ? query[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = e.options, source: string = query ? decodeURIComponent(query[1]) : '';
      const base: string = job.page.slice(captured.origin.length), handler: string = job.headers['X-Pinterest-Pws-Handler'];
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && current() && job.id.startsWith('native_board_section_read_') && job.page.startsWith(captured.origin + '/') && /^\/[^/?#]+\/[^/?#]+\/$/.test(base) && /^\d{1,30}$/.test(board) && /^\d{1,30}$/.test(section) && job.epoch === captured.generation && job.method === 'GET' && !job.body && !!query && Object.keys(e).length === 2 && !!e.context && !Array.isArray(e.context) && Object.keys(e.context).length === 0 && !!o && !Array.isArray(o) && job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest';
      const organize: boolean = source === '/boardsection/' + section + '/organize/repin/' && handler === 'www/boardsection/[id]/organize/add.js';
      const route: boolean = sectionPath.startsWith(base) && /^[^/?#]+\/$/.test(sectionPath.slice(base.length));
      if(job.url.startsWith(captured.origin + '/resource/BoardSectionResource/get/?'))permitted = basic && organize && Object.keys(o).length === 1 && o['section_id'] === section;
      else if(job.url.startsWith(captured.origin + '/resource/ApiResource/get/?')) {
        const d: Record<string,Object> = o['data'] as Record<string,Object>;
        const tools: boolean = o['url'] === '/v3/boards/sections/' + section + '/tools/' && route && source === sectionPath && handler === 'www/[username]/[slug]/[section_slug].js';
        const targets: boolean = o['url'] === '/v3/board/' + board + '/sections/all/' && (organize || source === base + '_tools/organize/?organization_feed=False' && handler === 'www/[username]/[slug]/_tools/organize.js');
        permitted = basic && Object.keys(o).length === 2 && !!d && Object.keys(d).length === 1 && JSON.stringify(d['fields']) === JSON.stringify(tools ? ['boardtool.id','boardtool.type','boardtool.tool','boardtool.text','boardtool.icon','boardtool.link','boardtool.show_badge'] : ['boardsection.board','boardsection.id','boardsection.slug','boardsection.title','boardsection.type','boardsection.preview_pins(limit:1)']) && (tools || targets);
      } else if(job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?'))permitted = basic && route && source === sectionPath + '_tools/more-ideas/?ideas_referrer=24' && handler === 'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js' && Object.keys(o).length === 3 && o['id'] === board && o['type'] === 'board' && o['__track__referrer'] === 24;
    }catch (_) {}
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && current() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardSectionWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    board: string, section: string, viewer: string, owner: string, allIds: string[], selected: string[], complete: boolean,
    targets: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, source: string = form ? decodeURIComponent(form[1]) : '';
      const digits = (value: string): boolean => /^\d{1,30}$/.test(value);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_section_write_') && job.epoch === captured.generation && job.method === 'POST' &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(job.page.slice(captured.origin.length)) && job.page.startsWith(captured.origin + '/') &&
        digits(board) && digits(section) && digits(viewer) && viewer === owner &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 && !!o && !Array.isArray(o);
      if(job.url === captured.origin + '/resource/ApiResource/delete/')permitted = basic && Object.keys(o).length === 1 &&
        o['url'] === '/v3/board/sections/' + section + '/' && source === '/boardsection/' + section + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/edit.js';
      else if(job.url === captured.origin + '/resource/ApiResource/update/') {
        const d: Record<string,Object> = o['data'] as Record<string,Object>;
        permitted = basic && Object.keys(o).length === 2 && o['url'] === '/v3/board/sections/' + section + '/' && !!d && !Array.isArray(d) && Object.keys(d).length === 2 && typeof d['title'] === 'string' && (d['title'] as string).trim() === d['title'] && (d['title'] as string).length > 0 && (d['title'] as string).length <= 100 && JSON.stringify(d['fields']) === JSON.stringify(['boardsection.board()','boardsection.id','boardsection.pin_count','boardsection.preview_pins()','boardsection.slug','boardsection.title','boardsection.type']) && source === '/boardsection/' + section + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/edit.js';
      }
      else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        const d: Record<string,Object> = o['data'] as Record<string,Object>;
        const sectionTarget: boolean = typeof d?.['new_section_id'] === 'string';
        const destination: boolean = sectionTarget ? Object.keys(d).length === 4 && typeof d['new_section_id'] === 'string' && digits(d['new_section_id'] as string) && d['new_section_id'] !== section && typeof d['new_board_id'] === 'string' && targets.includes(d['new_board_id'] as string) && (d['new_board_id'] === board && targets.includes('section:' + (d['new_section_id'] as string)) || targets.includes('section:' + (d['new_board_id'] as string) + ':' + (d['new_section_id'] as string))) : !!d && Object.keys(d).length === 3 && typeof d['new_board_id'] === 'string' && targets.includes(d['new_board_id'] as string);
        permitted = basic && complete && allIds.length <= 500 && new Set(allIds).size === allIds.length && allIds.every(digits) &&
          selected.length > 0 && new Set(selected).size === selected.length && selected.every((id: string): boolean => allIds.includes(id)) &&
          Object.keys(o).length === 2 && o['url'] === '/v3/boards/' + board + '/bulk/' && !!d && !Array.isArray(d) && destination &&
          typeof d['new_board_id'] === 'string' && digits(d['new_board_id'] as string) && d['old_section_id'] === section &&
          JSON.stringify(d['exclude_pin_ids']) === JSON.stringify(allIds.filter((id: string): boolean => !selected.includes(id))) &&
          source === '/boardsection/' + section + '/organize/repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/boardsection/[id]/organize/add.js';
      }
    }catch (_) {}
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {
      authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,
      epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardContent(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, canContribute: boolean, loadedIds: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const get: boolean = job.method === 'GET', query: string = job.url.slice(job.url.indexOf('?') + 1);
      const form: RegExpMatchArray | null = (get ? query : job.body).match(get ? /^source_url=([^&]+)&data=([^&]+)&_=\d+$/ : /^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_content_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^\d{1,30}$/.test(ownerId) &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && typeof o === 'object' && !Array.isArray(o);
      if(job.url === captured.origin + '/resource/BoardSectionResource/create/') {
        permitted = basic && job.method === 'POST' && canContribute && [ '/board/' + boardId + '/create_section/', '/board/' + boardId + '/create_section/pins/' ].includes(source) &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/create_section.js' && Object.keys(o).length === 3 && o['board_id'] === boardId &&
          typeof o['name'] === 'string' && (o['name'] as string).length > 0 && (o['name'] as string).length <= 100 && (o['name'] as string).trim() === o['name'] &&
          Array.isArray(o['initial_pins']) && (o['initial_pins'] as string[]).length <= 500 &&
          new Set(o['initial_pins'] as string[]).size === (o['initial_pins'] as string[]).length &&
          (o['initial_pins'] as string[]).every((id: string): boolean => /^\d{1,30}$/.test(id) && loadedIds.includes(id)) &&
          (source.endsWith('/pins/') || (o['initial_pins'] as string[]).length === 0);
      }else {
        const pin: RegExpMatchArray | null = source.match(/^\/pin\/(\d{1,30})\/$/), id: string = pin ? pin[1] : '';
        const copy: boolean = basic && viewerId === ownerId && !!id && loadedIds.includes(id) && o['id'] === id &&
          job.headers['X-Pinterest-Pws-Handler'] === 'www/pin/[id].js' && job.headers['X-Pinterest-AppState'] === 'active' && job.headers['X-Pinterest-Source-Url'] === source;
        if(get)permitted = copy && job.body === '' && job.url.startsWith(captured.origin + '/resource/PinResource/get/?') && Object.keys(o).length === 2 && o['field_set_key'] === 'auth_web_main_pin';
        else permitted = copy && job.method === 'POST' && job.url === captured.origin + '/resource/PinResource/delete/' &&
          (Object.keys(o).length === 1 || Object.keys(o).length === 2 && typeof o['client_tracking_params'] === 'string' &&
            (o['client_tracking_params'] as string).length > 2 && (o['client_tracking_params'] as string).length <= 16386 && (o['client_tracking_params'] as string).endsWith('~0'));
      }
    }catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardManagementWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, member: boolean, ownerCurrent: () => boolean, mergeTargets: string[] = []): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, source: string = form ? decodeURIComponent(form[1].replace(/\+/g,' ')) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_management_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^\d{1,30}$/.test(ownerId) && job.method === 'POST' &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && typeof o === 'object' && !Array.isArray(o);
      const own: boolean = viewerId === ownerId, participant: boolean = own || member;
      const editSource: boolean = source === '/board/' + boardId + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/edit.js';
      if(job.url === captured.origin + '/resource/BoardResource/update/') {
        permitted = basic && own && editSource && Object.keys(o).length === 8 && o['board_id'] === boardId &&
          typeof o['name'] === 'string' && (o['name'] as string).length > 0 && (o['name'] as string).length <= 300 && (o['name'] as string).trim() === o['name'] &&
          typeof o['description'] === 'string' && (o['description'] as string).length <= 500 && (o['privacy'] === 'public' || o['privacy'] === 'secret') &&
          typeof o['allow_homefeed_recommendations'] === 'boolean' && typeof o['collaborator_invites_enabled'] === 'boolean' && typeof o['collaborator_requests_enabled'] === 'boolean' && o['sensitivity'] === null;
      }else if(job.url === captured.origin + '/resource/BoardResource/delete/') {
        permitted = basic && own && editSource && Object.keys(o).length === 1 && o['board_id'] === boardId;
      }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        permitted = basic && participant && source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js' &&
          Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + boardId + '/archive/';
        if(basic && own && source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js' && Object.keys(o).length === 2) {
          const target: RegExpMatchArray | null = (o['url'] as string || '').match(/^\/v3\/boards\/(\d{1,30})\/merge\/(\d{1,30})\/$/);
          const data: Object | null = o['data'];
          permitted = !!target && target[1] === boardId && target[2] !== boardId && mergeTargets.includes(target[2]) && !!data && typeof data === 'object' && !Array.isArray(data) && Object.keys(data).length === 0;
        }
      }else if(job.url === captured.origin + '/resource/ApiResource/delete/') {
        const allowed: boolean = basic && member && !own && source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js';
        permitted = allowed && (Object.keys(o).length === 1 && o['url'] === '/v3/boards/' + boardId + '/follow/' ||
          Object.keys(o).length === 2 && o['url'] === '/v3/boards/' + boardId + '/collaborators/' + viewerId + '/' &&
          !!o['data'] && typeof o['data'] === 'object' && !Array.isArray(o['data']) && Object.keys(o['data'] as Object).length === 0);
      }
    }catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardPinWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, loadedIds: string[], enabledTargets: string[], recommendedIds: string[], ownerCurrent: () => boolean, savedCopies: string[] = [], recommendationPath: string = ''): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
      const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = envelope.options, keys: string[] = Object.keys(o), source: string = form ? decodeURIComponent(form[1]) : '';
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_pin_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        (!/^_|^(?:pins|followers|following)$/i.test(parts[1]) || parts[1] === '_products_you_tagged' && (job.url === captured.origin + '/resource/ApiResource/delete/' && o['url'] === '/v3/pins/bulk/' || job.url === captured.origin + '/resource/RepinResource/create/')) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && job.method === 'POST' &&
        job.headers['Accept'] === 'application/json' && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        !!form && Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
        !!o && typeof o === 'object' && !Array.isArray(o);
      const section: boolean = recommendationPath.startsWith(path) && /^\/[^/?#]+\/[^/?#]+\/[^/?#]+\/_tools\/more-ideas\/\?ideas_referrer=24$/.test(recommendationPath);
      const createdBoardIdeas: boolean = recommendationPath === path && source === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js';
      const recommendation: boolean = createdBoardIdeas || (section ? source === recommendationPath && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js' : !recommendationPath && source === path + '_tools/more-ideas/?ideas_referrer=23' && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug]/_tools/more-ideas.js');
      if(job.url === captured.origin + '/resource/PinResource/delete/') {
        permitted = basic && recommendation && keys.length === 2 && typeof o['id'] === 'string' && /^\d{1,30}$/.test(o['id'] as string) && savedCopies.includes(o['id'] as string) && typeof o['client_tracking_params'] === 'string' && (o['client_tracking_params'] as string).length <= 16384;
      }else if(job.url === captured.origin + '/resource/RepinResource/create/') {
        const product: boolean = parts[1] === '_products_you_tagged';
        const event: Record<string,Object> | undefined = o['eventContext'] as Record<string,Object> | undefined;
        permitted = basic && recommendation &&
          (product || createdBoardIdeas ? (createdBoardIdeas || !recommendationPath) && keys.length === 12 && keys.every((key: string): boolean => ['pin_id','board_id','clientTrackingParams','description','title','link','image_base64','image_url','media_upload_id','is_buyable_pin','is_removable','eventContext'].includes(key)) &&
            typeof o['title'] === 'string' && (o['title'] as string).length <= 1000 && typeof o['description'] === 'string' && (o['description'] as string).length <= 10000 && typeof o['link'] === 'string' && (o['link'] as string).length <= 8192 &&
            typeof o['clientTrackingParams'] === 'string' && (o['clientTrackingParams'] as string).length <= 16384 && o['image_base64'] === '' && o['image_url'] === '' && o['media_upload_id'] === '' && o['is_buyable_pin'] === false && o['is_removable'] === false &&
            !!event && !Array.isArray(event) && Object.keys(event).length === 3 && event['viewType'] === 5 && event['viewParameter'] === 3173 && event['element'] === 10599 &&
            typeof o['pin_id'] === 'string' && /^\d{1,30}$/.test(o['pin_id'] as string) && recommendedIds.includes(o['pin_id'] as string) && o['board_id'] === boardId :
          (keys.length === 3 || keys.length === 4 && keys.includes('clientTrackingParams')) && typeof o['pin_id'] === 'string' && /^\d{1,30}$/.test(o['pin_id'] as string) &&
          recommendedIds.includes(o['pin_id'] as string) && o['board_id'] === boardId && o['user_id'] === viewerId && (o['clientTrackingParams'] === undefined || typeof o['clientTrackingParams'] === 'string' && (o['clientTrackingParams'] as string).length <= 16384));
      }else if(job.url === captured.origin + '/resource/BoardResource/create/') {
        permitted = basic && source === '/board/create/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/create.js' && keys.length === 2 &&
          typeof o['name'] === 'string' && !!(o['name'] as string).trim() && o['name'] === (o['name'] as string).trim() && (o['name'] as string).length <= 100 &&
          ['public','secret'].includes(o['privacy'] as string);
      }else if(job.url === captured.origin + '/resource/ApiResource/delete/') {
        const data: Record<string,Object> = o['data'] as Record<string,Object>, ids: string[] = data?.['pin_ids'] as string[];
        permitted = basic && source === (parts[1] === '_products_you_tagged' ? path + '_tools/organize/?organization_feed=False' : path) && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug]/_tools/organize.js' && keys.length === 2 && o['url'] === '/v3/pins/bulk/' && !!data && Object.keys(data).length === 1 && Array.isArray(ids) && ids.length > 0 && ids.length <= 500 && ids.every((id: string,index: number): boolean => typeof id === 'string' && /^\d{1,30}$/.test(id) && ids.indexOf(id) === index && loadedIds.includes(id));
      }else if(job.url === captured.origin + '/resource/ApiResource/create/') {
        const data: Record<string,Object> = o['data'] as Record<string,Object>, ids: string[] = data['pin_ids'] as string[];
        permitted = basic && source === '/board/' + boardId + '/organize/repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/organize.js' &&
          keys.length === 2 && o['url'] === '/v3/pins/bulk/move/' && !!data && typeof data === 'object' && !Array.isArray(data) && Object.keys(data).length === 2 &&
          typeof data['board_id'] === 'string' && /^\d{1,30}$/.test(data['board_id'] as string) && data['board_id'] !== boardId && enabledTargets.includes(data['board_id'] as string) &&
          Array.isArray(ids) && ids.length > 0 && ids.length <= 500 && ids.every((id: string,index: number): boolean => typeof id === 'string' && /^\d{1,30}$/.test(id) && ids.indexOf(id) === index && loadedIds.includes(id));
        if(data?.['section_id'] !== undefined) permitted = basic && source === job.page.slice(captured.origin.length) + '_tools/organize/?organization_feed=False' && job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug]/_tools/organize.js' &&
          keys.length === 2 && o['url'] === '/v3/pins/bulk/move/' && !Array.isArray(data) && Object.keys(data).length === 3 &&
          typeof data['board_id'] === 'string' && /^\d{1,30}$/.test(data['board_id'] as string) && data['board_id'] !== boardId && enabledTargets.includes(data['board_id'] as string) &&
          typeof data['section_id'] === 'string' && /^\d{1,30}$/.test(data['section_id'] as string) && enabledTargets.includes('section:' + data['board_id'] + ':' + data['section_id']) &&
          Array.isArray(ids) && ids.length > 0 && ids.length <= 500 && ids.every((id: string,index: number): boolean => typeof id === 'string' && /^\d{1,30}$/.test(id) && ids.indexOf(id) === index && loadedIds.includes(id));
        const targetSection: RegExpMatchArray | null = typeof o['url'] === 'string' ? (o['url'] as string).match(/^\/v3\/board\/sections\/(\d{1,30})\/$/) : null;
        const pins: string[] | undefined = data?.['pins'] as string[] | undefined;
        if(targetSection) permitted = basic && source === '/board/' + boardId + '/organize/repin/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/organize.js' &&
          keys.length === 2 && !!data && !Array.isArray(data) && Object.keys(data).length === 2 &&
          enabledTargets.includes('section:' + boardId + ':' + targetSection[1]) && Array.isArray(pins) && pins.length === 1 &&
          typeof pins[0] === 'string' && loadedIds.includes(pins[0]) && /^\d{1,30}$/.test(pins[0]) &&
          JSON.stringify(data['fields']) === JSON.stringify(['boardsection.board()','boardsection.id','boardsection.pin_count','boardsection.preview_pins()','boardsection.slug','boardsection.title','boardsection.type']);
      }
    }catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardCollaboratorWrite(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, canInvite: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((part: string): boolean => !!part);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_collab_write_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^\d{1,30}$/.test(ownerId) &&
        job.method === 'POST' && job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest';
      if(job.url === captured.origin + '/resource/BoardResource/update/') {
        const form: RegExpMatchArray | null = job.body.match(/^source_url=([^&]+)&data=([^&]+)$/);
        const envelope: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
        const o: Record<string,Object | null> = envelope.options;
        permitted = basic && viewerId === ownerId && !!form && decodeURIComponent(form[1]) === '/board/' + boardId + '/edit/' &&
          job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/edit.js' &&
          Object.keys(envelope).length === 2 && !!envelope.context && typeof envelope.context === 'object' && !Array.isArray(envelope.context) && Object.keys(envelope.context).length === 0 &&
          !!o && typeof o === 'object' && !Array.isArray(o) && Object.keys(o).length === 4 && o['board_id'] === boardId &&
          (o['collaborator_permissions_setting'] === 0 || o['collaborator_permissions_setting'] === 1) &&
          typeof o['collaborator_invites_enabled'] === 'boolean' && o['sensitivity'] === null;
      } else if(job.url === captured.origin + '/_/graphql/') {
        const query: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery;
        const v: Record<string,Object> = query.variables as Record<string,Object>, ids: string[] = v['collaboratorIds'] as string[];
        permitted = basic && canInvite && job.headers['Content-Type'] === 'application/json' && job.headers['X-Pinterest-Source-Url'] === path &&
          Object.keys(query).length === 2 && query.queryHash === '42ceaa3423a096a27613e5738f83aaadcee449c55d4dd03624d2f08a6b6dca04' &&
          !Array.isArray(v) && Object.keys(v).length === 3 && v['boardId'] === boardId && v['message'] === '' &&
          Array.isArray(ids) && ids.length === 1 && typeof ids[0] === 'string' && /^\d{1,30}$/.test(ids[0]) && ids[0] !== viewerId && ids[0] !== ownerId;
      }
    }catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};
    });
  }

async requestBusinessBoardCover(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, viewerId: string, ownerId: string, pinId: string, image: string, imageWidth: number, imageHeight: number,
    ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const get: boolean = job.method === 'GET';
      const form: RegExpMatchArray | null = (get ? job.url.slice(job.url.indexOf('?')+1) : job.body).match(/^source_url=([^&]+)&data=([^&]+)$/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(form ? form[2] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options, keys: string[] = Object.keys(o);
      const path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((p: string): boolean => !!p);
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_cover_') && job.epoch === captured.generation && job.page.startsWith(captured.origin+'/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        !/^_|^(?:pins|followers|following|edit)$/i.test(parts[1]) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && viewerId === ownerId &&
        !!form && decodeURIComponent(form[1]) === path && Object.keys(payload).length === 2 && !!payload.context && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        !!o && !Array.isArray(o) && o['board_id'] === boardId && job.headers['Accept'] === 'application/json' && job.headers['X-Requested-With'] === 'XMLHttpRequest' &&
        job.headers['X-Pinterest-Pws-Handler'] === 'www/[username]/[slug].js';
      if(get && job.body === '' && job.url.startsWith(captured.origin+'/resource/BoardResource/get/?'))
        permitted = basic && keys.length === 2 && o['field_set_key'] === 'edit';
      else if(get && job.body === '' && job.url.startsWith(captured.origin+'/resource/BoardFeedResource/get/?')) {
        const cursor: string[] | undefined = o['bookmarks'] as string[] | undefined;
        permitted = basic && (keys.length === 4 || keys.length === 5 && keys.includes('bookmarks')) &&
          keys.every((k: string): boolean => ['board_id','field_set_key','filter_section_pins','page_size','bookmarks'].includes(k)) &&
          o['field_set_key'] === 'images_only_item' && o['filter_section_pins'] === false && o['page_size'] === 50 &&
          (cursor === undefined || Array.isArray(cursor) && cursor.length === 1 && typeof cursor[0] === 'string' && !!cursor[0] && cursor[0] !== '-end-' && cursor[0].length <= 4096);
      }else if(job.method === 'POST' && job.url === captured.origin+'/resource/BoardResource/update/') {
          const side: number = Math.min(imageWidth,imageHeight);
          const scale: number = Math.max(236/imageWidth,236/(5/3)/imageHeight);
          const width: number = Math.max(1,Math.round(236/scale)),height: number = Math.max(1,Math.round(236/(5/3)/scale));
          const square: boolean = o['width'] === side && o['height'] === side && o['scale'] === 236/side;
          const wide: boolean = o['width'] === width && o['height'] === height && o['scale'] === scale;
        const x: number = o['crop_x'] as number,y: number = o['crop_y'] as number;
        permitted = basic && job.headers['Content-Type'] === 'application/x-www-form-urlencoded' && keys.length === 9 &&
          keys.every((k: string): boolean => ['board_id','url','pin_id','pin_image_url','crop_x','crop_y','width','height','scale'].includes(k)) &&
          /^\d{1,30}$/.test(pinId) && /^https:\/\/i\.pinimg\.com\//.test(image) && image.length <= 2048 &&
          Number.isInteger(imageWidth) && Number.isInteger(imageHeight) && side > 0 && imageWidth <= 20000 && imageHeight <= 20000 &&
            o['pin_id'] === pinId && o['url'] === image && o['pin_image_url'] === image && (square || wide) &&
            Number.isInteger(x) && Number.isInteger(y) && x >= 0 && y >= 0 && x <= imageWidth-(o['width'] as number) && y <= imageHeight-(o['height'] as number);
      }
    }catch(_){}
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardAuxRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, username: string, viewerId: string, ownerCurrent: () => boolean, createdBoardIdeas: boolean = false): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/), source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(encoded ? encoded[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options, keys: string[] = Object.keys(o), path: string = job.page.slice(captured.origin.length), parts: string[] = path.split('/').filter((p: string): boolean => !!p);
      const cursor: string[] | undefined = o['bookmarks'] as string[] | undefined, handler: string = job.headers['X-Pinterest-Pws-Handler'];
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_aux_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        (!/^_|^(?:pins|followers|following)$/i.test(parts[1]) || parts[1] === '_products_you_tagged' && job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?')) && /^\d{1,30}$/.test(boardId) && /^\d{1,30}$/.test(viewerId) && /^[A-Za-z0-9_]+$/.test(username) &&
        job.method === 'GET' && job.body === '' && !!source && Object.keys(payload).length === 2 && !Array.isArray(o) && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        (cursor === undefined || Array.isArray(cursor) && cursor.length === 1 && typeof cursor[0] === 'string' && cursor[0].length > 0 && cursor[0].length <= 4096);
      const sourcePath: string = source ? decodeURIComponent(source[1]) : '';
      if(job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?')) {
        permitted = basic && (createdBoardIdeas ? sourcePath === path && handler === 'www/[username]/[slug].js' && o['__track__referrer'] === 21 : sourcePath === path + '_tools/more-ideas/?ideas_referrer=23' && handler === 'www/[username]/[slug]/_tools/more-ideas.js' && o['__track__referrer'] === (parts[1] === '_products_you_tagged' ? '23' : 23)) && (keys.length === 3 || keys.length === 4 && keys.includes('bookmarks')) && o['id'] === boardId && o['type'] === 'board';
      } else if(job.url.startsWith(captured.origin + '/resource/BoardsResource/get/?')) {
        permitted = basic && sourcePath === '/board/' + boardId + '/organize/repin/' && handler === 'www/board/[id]/organize.js' &&
          (keys.length === 9 || keys.length === 10 && keys.includes('bookmarks')) && keys.every((k: string): boolean => ['privacy_filter','sort','field_set_key','filter_stories','username','page_size','group_by','include_archived','filter_all_pins','bookmarks'].includes(k)) &&
          o['privacy_filter'] === 'all' && o['sort'] === 'custom' && o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === true && o['username'] === username && o['page_size'] === 25 && o['group_by'] === 'mix_public_private' && o['include_archived'] === true && o['filter_all_pins'] === false;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardResource/get/?')) {
        permitted = basic && keys.length === 2 && o['board_id'] === boardId && (o['field_set_key'] === 'edit' && sourcePath === '/board/' + boardId + '/edit/' && handler === 'www/board/[id]/edit.js' || o['field_set_key'] === 'boardEdit' && sourcePath === path && handler === 'www/index.js');
      } else if(job.url.startsWith(captured.origin + '/resource/BoardInvitesResource/get/?')) {
        permitted = basic && sourcePath === path && handler === 'www/index.js' && keys.length === 5 && o['board_id'] === boardId && o['sort'] === 'viewer_first' && o['field_set_key'] === 'boardEdit' && o['status_filters'] === 'new,accepted,contact_request_not_approved,pending_approval' && o['include_inactive'] === true;
      } else if(job.url.startsWith(captured.origin + '/resource/ShareSuggestionsResource/get/?')) {
        permitted = basic && sourcePath === path && handler === 'www/index.js' && keys.length === 2 && o['suggestion_type'] === 'group_board' && o['board'] === boardId;
      }
    }catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }

async requestBusinessBoardRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    boardId: string, sectionId: string, viewerId: string, ownCollection: boolean, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session(); let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/), source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const payload: NativeSearchEnvelope = JSON.parse(decodeURIComponent(encoded ? encoded[1] : '')) as NativeSearchEnvelope;
      const o: Record<string,Object | null> = payload.options, keys: string[] = Object.keys(o), path: string = job.page.slice(captured.origin.length);
      const parts: string[] = path.split('/').filter((p: string): boolean => !!p), cursor: string[] | undefined = o['bookmarks'] as string[] | undefined;
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() &&
        job.id.startsWith('native_board_') && job.epoch === captured.generation && job.page.startsWith(captured.origin + '/') &&
        /^\/[^/?#]+\/[^/?#]+\/$/.test(path) && !/^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|logout|signup|business|explore)$/i.test(parts[0]) &&
        (!/^_|^(?:followers|following)$/i.test(parts[1]) || parts[1] === '_products_you_tagged') && job.method === 'GET' && job.body === '' &&
        !!source && decodeURIComponent(source[1]) === path && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        Object.keys(payload).length === 2 && !Array.isArray(o) && !Array.isArray(payload.context) && Object.keys(payload.context).length === 0 &&
        (cursor === undefined || Array.isArray(cursor) && cursor.length === 1 && typeof cursor[0] === 'string' && cursor[0].length > 0 && cursor[0].length <= 4096);
      const collection: boolean = parts[1] === 'pins', id: boolean = /^\d{1,30}$/.test(boardId), viewer: boolean = /^\d{1,30}$/.test(viewerId);
      if(job.url.startsWith(captured.origin + '/resource/BoardResource/get/?')) {
        permitted = basic && !collection && keys.length === 4 && o['field_set_key'] === 'profile_grid_item' && o['is_mobile_fork'] === true && o['username'] === decodeURIComponent(parts[0]) && o['slug'] === decodeURIComponent(parts[1]);
      } else if(job.url.startsWith(captured.origin + '/resource/UserResource/get/?')) {
        permitted = basic && collection && keys.length === 1 && o['username'] === decodeURIComponent(parts[0]);
      } else if(job.url.startsWith(captured.origin + '/resource/BoardFeedResource/get/?')) {
        const fields: string[] = ['add_vase','board_id','field_set_key','filter_section_pins','is_react','prepend','page_size','redux_normalize_feed','gated','bookmarks'];
        permitted = basic && !collection && id && viewer && (keys.length === 9 || keys.length === 10 && keys.includes('bookmarks')) && keys.every((k: string): boolean => fields.includes(k)) &&
          o['board_id'] === boardId && o['add_vase'] === false && o['field_set_key'] === 'react_grid_pin' && o['filter_section_pins'] === true && o['is_react'] === true && o['prepend'] === false && o['page_size'] === 15 && o['redux_normalize_feed'] === true && o['gated'] === false;
        const favoriteFields: string[] = ['board_id','board_url','currentFilter','field_set_key','filter_section_pins','sort','layout','page_size','redux_normalize_feed','bookmarks'];
        permitted = permitted || basic && !collection && id && viewer && (keys.length === 9 || keys.length === 10 && keys.includes('bookmarks')) && keys.every((k: string): boolean => favoriteFields.includes(k)) &&
          o['board_id'] === boardId && o['board_url'] === path && o['currentFilter'] === 6 && o['field_set_key'] === 'react_grid_pin' && o['filter_section_pins'] === false && o['sort'] === 'default' && o['layout'] === 'default' && o['page_size'] === 25 && o['redux_normalize_feed'] === true;
      } else if(job.url.startsWith(captured.origin + '/resource/UserPinsResource/get/?')) {
        permitted = basic && collection && id && viewer && (keys.length === 4 || keys.length === 5 && keys.includes('bookmarks')) && keys.every((k: string): boolean => ['add_vase','field_set_key','is_own_profile_pins','username','bookmarks'].includes(k)) && o['add_vase'] === false && o['field_set_key'] === 'mobile_grid_item' && o['is_own_profile_pins'] === ownCollection && o['username'] === decodeURIComponent(parts[0]);
      } else if(job.url.startsWith(captured.origin + '/resource/BoardSectionsResource/get/?')) {
        permitted = basic && !collection && id && viewer && keys.length === 2 && o['board_id'] === boardId && o['redux_normalize_feed'] === true;
      } else if(job.url.startsWith(captured.origin + '/resource/BoardSectionPinsResource/get/?')) {
        permitted = basic && !collection && id && viewer && /^\d{1,30}$/.test(sectionId) && (keys.length === 3 || keys.length === 4 && keys.includes('bookmarks')) && keys.every((k: string): boolean => ['page_size','prepend','section_id','bookmarks'].includes(k)) && o['page_size'] === 25 && o['prepend'] === false && o['section_id'] === sectionId;
      }
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent}; });
  }
}
