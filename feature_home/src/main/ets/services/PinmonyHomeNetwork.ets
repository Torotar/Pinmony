import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
interface HomeReadData { options: HomeReadOptions; }
interface HomeReadOptions { field_set_key?: string; in_nux?: boolean; in_news_hub?: boolean; static_feed?: boolean;
  type?: string; id?: string; __track__referrer?: number; bookmarks?: string[]; username?: string;
  filter_stories?: boolean; sort?: string; board_id?: string; is_mobile_fork?: boolean; }

export class PinmonyHomeNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
async requestBusinessHomeRead(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    username: string, board: string, ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();
    let permitted: boolean = false;
    try {
      const encoded: RegExpMatchArray | null = job.url.match(/[?&]data=([^&]+)/);
      const source: RegExpMatchArray | null = job.url.match(/[?&]source_url=([^&]+)/);
      const data: HomeReadData = encoded ? JSON.parse(decodeURIComponent(encoded[1])) as HomeReadData : {} as HomeReadData;
      const options: HomeReadOptions = data.options;
      const path: string = source ? decodeURIComponent(source[1]) : '';
      const boardSource: string = board ? '/?tabId=' + board : '/';
      const cursorValid: boolean = options?.bookmarks === undefined || Array.isArray(options.bookmarks) && options.bookmarks.length === 1 &&
        typeof options.bookmarks[0] === 'string' && options.bookmarks[0].length > 0 && options.bookmarks[0].length <= 4096;
      permitted = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && /^[A-Za-z0-9_]+$/.test(username) &&
        (!board || /^\d+$/.test(board)) && job.id.startsWith('native_home_') && job.page === captured.origin + '/' && job.epoch === captured.generation &&
        job.method === 'GET' && job.body === '' && job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' &&
        ((job.url.startsWith(captured.origin + '/resource/UserHomefeedResource/get/?') && !board && path === '/' && cursorValid &&
          options?.field_set_key === 'hf_grid' && options.in_nux === false && options.in_news_hub === false && options.static_feed === false) ||
         (job.url.startsWith(captured.origin + '/resource/BoardContentRecommendationResource/get/?') && !!board && path === boardSource && cursorValid &&
          options?.type === 'board' && options.id === board && options.__track__referrer === 19) ||
         (job.url.startsWith(captured.origin + '/resource/BoardsFeedResource/get/?') && path === '/' + username + '/' && options?.username === username &&
          options.field_set_key === 'profile_grid_item' && options.filter_stories === false && options.sort === 'last_pinned_to' && options.bookmarks === undefined) ||
         (job.url.startsWith(captured.origin + '/resource/BoardResource/get/?') && !!board && path === boardSource && options?.board_id === board &&
          options.field_set_key === 'profile_grid_item' && options.is_mobile_fork === true && options.bookmarks === undefined));
    } catch (_) {}
    return this.transport.request(job, (): PinmonyNetworkContext => {
      const actual: PinmonyBusinessSessionContext = session();
      return { authenticated: permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.origin === captured.origin && actual.generation === captured.generation, epoch: captured.generation, page: job.page, userAgent: actual.userAgent };
    });
  }
}
