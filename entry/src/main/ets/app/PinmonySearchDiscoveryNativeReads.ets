import { PinmonyI18n } from 'common_foundation';
import { PinmonySearchStore, PinmonySearchSnapshot, PinmonySearchHero, PinmonySearchIdeaSection, PinmonySearchIdea } from 'feature_search';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PIN_BUSINESS_PIN_READ_ENABLED, PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyRuntimeLog } from 'common_foundation';

export const PIN_NATIVE_SEARCH_DISCOVERY_ENABLED: boolean = PIN_BUSINESS_PIN_READ_ENABLED;
interface FormattedText { format?: string; }
interface FeaturedMetadata { boardHdCoverUrl?: string; boardSubtitle?: string; }
interface DiscoveryObject { boardType?: string; boardName?: string; boardUrl?: string; featuredBoardMetadata?: FeaturedMetadata; imageMediumUrl?: string; }
interface DiscoveryAction { url?: string; }
interface DiscoveryNode { storyId?: string; story_type?: string; title?: FormattedText; subtitle?: FormattedText; objects?: DiscoveryObject[]; action?: DiscoveryAction; }
interface DiscoveryEdge { node?: DiscoveryNode; }
interface DiscoveryPageInfo { hasNextPage: boolean; endCursor?: string; }
interface DiscoveryConnection { edges: DiscoveryEdge[]; pageInfo: DiscoveryPageInfo; }
interface DiscoveryData { connection: DiscoveryConnection; }
interface DiscoveryQuery { data: DiscoveryData; }
interface DiscoveryPayloadData { v3SearchTabHandlerQuery: DiscoveryQuery; }
interface DiscoveryPayload { data: DiscoveryPayloadData; errors?: Object[]; }
interface DiscoveryVariables { count?: number; cursor?: string; }
interface DiscoveryRequest { queryHash: string; variables: DiscoveryVariables; }
export interface PinmonySearchDiscoveryNativeReadsPorts {
  store: () => PinmonySearchStore;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  page: () => string;
  active: () => boolean;
  committed: (page: string) => void;
  settled: () => void;
}

export class PinmonySearchDiscoveryNativeReads {
  private readonly ports: PinmonySearchDiscoveryNativeReadsPorts;
  private readonly store: PinmonySearchStore;
  private account: string = '';
  private generation: number = -1;
  private origin: string = '';
  private revision: number = 0;
  private sequence: number = 0;
  private requestId: string = '';
  private busy: boolean = false;
  private ready: boolean = false;
  private ended: boolean = false;
  private error: string = '';
  private cursor: string = '';
  private heroes: PinmonySearchHero[] = [];
  private sections: PinmonySearchIdeaSection[] = [];
  constructor(ports: PinmonySearchDiscoveryNativeReadsPorts) { this.ports = ports; this.store = ports.store(); }
  eligible(): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return PIN_NATIVE_SEARCH_DISCOVERY_ENABLED && session.authenticated && !!session.accountId &&
      (this.ports.page() === session.origin + '/search/' || this.ports.page() === session.origin + '/search');
  }
  owned(): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return this.eligible() && this.ports.active() && session.accountId === this.account &&
      session.generation === this.generation && session.origin === this.origin;
  }
  pause(): void {
    if (!PIN_NATIVE_SEARCH_DISCOVERY_ENABLED) return;
    this.revision++; if (this.requestId) this.ports.network().cancel(this.requestId);
    this.requestId = ''; this.busy = false; this.store.searchDiscoveryReadsReady = false;
  }
  reset(): void {
    this.pause(); this.account = ''; this.generation = -1; this.origin = ''; this.cursor = '';
    this.heroes = []; this.sections = []; this.ready = false; this.error = ''; this.ended = false;
    this.store.searchDiscoveryReadsReady = false; this.store.searchActionsReady = false; this.store.searchInputReady = false;
    this.store.search = undefined; this.store.retainedSearch = undefined; this.store.searchCache.clear(); this.store.searchScrollOffset = 0;
  }
  private bind(): boolean {
    if (!this.eligible() || !this.ports.active()) return false;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if (session.accountId !== this.account || session.generation !== this.generation || session.origin !== this.origin) {
      const changed: boolean = !!this.account && (session.accountId !== this.account || session.origin !== this.origin);
      this.reset(); if (changed) { this.store.search = undefined; this.store.retainedSearch = undefined; this.store.searchScrollOffset = 0; }
      this.account = session.accountId; this.generation = session.generation; this.origin = session.origin;
    }
    return true;
  }
  apply(): void {
    if (!this.owned()) { this.store.searchDiscoveryReadsReady = false; return; }
    const page: string = this.ports.page();
    const existing: PinmonySearchSnapshot | undefined = this.store.search;
    const next: PinmonySearchSnapshot = existing?.pageKey === page ? JSON.parse(JSON.stringify(existing)) as PinmonySearchSnapshot :
      { kind: 'loading', session: 0, pageKey: page, query: '', placeholder: '', selectedCategory: '', categories: [], suggestions: [], heroes: [], ideaSections: [], results: [] };
    next.kind = this.ready || this.error ? 'state' : 'loading';
    next.heroes = this.heroes.slice(); next.ideaSections = this.sections.slice(); next.discoveryApi = true;
    next.discoveryActive = this.ready; next.discoveryBusy = this.busy; next.discoveryError = this.error; next.discoveryEnded = this.ended;
    this.store.searchDiscoveryReadsReady = this.ready; this.store.searchLoading = !this.ready && this.busy;
    this.store.searchError = this.ready ? '' : this.error;
    this.store.search = next;
    if (this.ready && !next.query && !this.error && !this.busy) this.store.searchCache.put(next, this.store.searchScrollOffset);
  }
  async demand(): Promise<void> {
    if (!this.bind()) return;
    this.apply(); if (this.busy || this.ready) return; await this.read(false);
  }
  async refresh(): Promise<void> {
    if (!this.bind() || this.busy) return;
    await this.read(false);
  }
  async more(): Promise<void> {
    if (!this.bind() || this.busy || this.store.search?.query || this.ended && !this.error) return;
    await this.read(this.ready && !!this.cursor);
  }
  private target(value: string | undefined): string {
    if (typeof value !== 'string' || value.length > 2000 || /\s/.test(value)) return '';
    const url: string = value.startsWith('/') && !value.startsWith('//') ? this.origin + value : value;
    return url.startsWith(this.origin + '/') && !url.includes('\\') ? url : '';
  }
  private image(value: string | undefined): string { return typeof value === 'string' && value.length <= 2000 && /^https:\/\/i\.pinimg\.com\//i.test(value) ? value : ''; }
  private text(value: FormattedText | undefined): string { return typeof value?.format === 'string' ? value.format.trim().slice(0, 180) : ''; }
  private async read(append: boolean): Promise<void> {
    const revision: number = this.revision; const previous: string = append ? this.cursor : '';
    const page: string = this.ports.page();
    const live = (): boolean => revision === this.revision && this.owned() && this.ports.page() === page;
    const id: string = 'native_search_discovery_' + (++this.sequence).toString();
    this.requestId = id; this.busy = true; this.error = ''; this.apply();
    const envelope: DiscoveryRequest = { queryHash: append ? 'a53e4b9faaa4d08b5450d8a2f60945e513d19f0273c6175ed3a6560c70f22b4b' : 'a0959c548d14cf06adbc04230c8151f3aec27082f8328131fbf4ac52af844041',
      variables: append ? { count: 6, cursor: previous } : {} };
    const job: PinmonyNetworkJob = { id: id, page: page, epoch: this.generation, url: this.origin + '/_/graphql/', method: 'POST', body: JSON.stringify(envelope),
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } };
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessSearchDiscoveryRead(job, (): PinmonyBusinessSessionContext => this.ports.session(), live);
      if (!live()) return;
      if (reply.error || reply.status !== 200 || reply.body.length > 4000000) throw new Error('discovery-request');
      const payload: DiscoveryPayload = JSON.parse(reply.body) as DiscoveryPayload;
      const connection: DiscoveryConnection = payload.data?.v3SearchTabHandlerQuery?.data?.connection;
      if (payload.errors || !connection || !Array.isArray(connection.edges) || connection.edges.length > 80 ||
        typeof connection.pageInfo?.hasNextPage !== 'boolean') throw new Error('discovery-response');
      const heroes: PinmonySearchHero[] = append ? this.heroes.slice() : [];
      const sections: PinmonySearchIdeaSection[] = append ? this.sections.slice() : [];
      connection.edges.forEach((edge: DiscoveryEdge, index: number): void => {
        const node: DiscoveryNode | undefined = edge?.node;
        if (!node || !Array.isArray(node.objects)) return;
        const title: string = this.text(node.title); const sectionId: string = 'discovery-' + String(node.storyId || index);
        if (node.story_type === 'slp_immersive_header') {
          node.objects.slice(0, 20).forEach((board: DiscoveryObject, n: number): void => {
            const cover: string = this.image(board?.featuredBoardMetadata?.boardHdCoverUrl); const url: string = this.target(board?.boardUrl);
            if (board?.boardType !== 'board' || !cover || !url || typeof board.boardName !== 'string' || !board.boardName.trim()) return;
            if (heroes.length < 80 && !heroes.some((hero: PinmonySearchHero): boolean => hero.targetUrl === url))
              heroes.push({ id: sectionId + '-hero-' + n.toString(), title: board.boardName.slice(0, 180),
                subtitle: String(board.featuredBoardMetadata?.boardSubtitle || title).slice(0, 180), targetUrl: url, imageUrl: cover, enabled: true });
          }); return;
        }
        const url: string = this.target(node.action?.url);
        if (node.story_type !== 'slp_search_recommendation' || !title || !url.startsWith(this.origin + '/search/pins/')) return;
        const items: PinmonySearchIdea[] = [];
        node.objects.slice(0, 4).forEach((pin: DiscoveryObject, n: number): void => {
          const cover: string = this.image(pin?.imageMediumUrl); if (!cover) return;
          items.push({ id: sectionId + '-' + n.toString(), title: title, imageUrl: cover, targetUrl: url, enabled: true });
        });
        if (!items.length) return;
        const section: PinmonySearchIdeaSection = { id: sectionId, title: title, eyebrow: this.text(node.subtitle), actionId: sectionId, targetUrl: url, items: items };
        const existing: number = sections.findIndex((value: PinmonySearchIdeaSection): boolean => value.id === sectionId || value.targetUrl === url);
        if (existing >= 0) sections[existing] = section; else if (sections.length < 80) sections.push(section);
      });
      const cursor: string = typeof connection.pageInfo.endCursor === 'string' && connection.pageInfo.endCursor.length <= 4096 ? connection.pageInfo.endCursor : '';
      this.heroes = heroes; this.sections = sections; this.cursor = cursor;
      this.ended = !connection.pageInfo.hasNextPage || !cursor || !!previous && cursor === previous || connection.edges.length === 0;
      this.ready = true; this.ports.committed(page);
      PinmonyRuntimeLog.info('SearchNativeTrace: discovery committed append=' + append.toString() + ' sections=' + sections.length.toString());
    } catch (_) { if (live()) this.error = PinmonyI18n.message("pm_unable_to_load_search_discovery_please_retry_f37a889f"); }
    finally { if (revision === this.revision) { this.requestId = ''; this.busy = false; if (live()) this.apply(); this.ports.settled(); } }
  }
}
