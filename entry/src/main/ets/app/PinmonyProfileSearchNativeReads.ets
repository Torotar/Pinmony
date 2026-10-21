import { PinmonyI18n } from 'common_foundation';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyProfileStore, PinmonyProfileSearchSnapshot, PinmonyProfileSearchPin, PinmonyProfileSearchSuggestion } from 'feature_profile';

interface SearchImage { url: string; }
interface SearchPin { id?: string; title?: string; grid_title?: string; description?: string; images?: Record<string, SearchImage>; }
interface Suggestion { type?: string; query?: string; pins?: SearchPin[]; }
interface SearchData { items?: Suggestion[]; results?: SearchPin[]; }
interface SearchResource { status: string; data: SearchData; bookmark?: string; }
interface SearchResponse { resource_response: SearchResource; }
interface HistoryDeleteData { query: string; vertical: string; }
interface HistoryDeleteOptions { url: string; data: HistoryDeleteData; }
interface HistoryDeleteEnvelope { options: HistoryDeleteOptions; context: Record<string, string>; }
interface HistoryDeleteResource { status: string; code: number; endpoint_name: string; }
interface HistoryDeleteResponse { resource_response: HistoryDeleteResource; }
interface PersonalTypeaheadOptions { field_set_key: string; limit: number; num_recent_queries: number; personal_search_only: boolean; pin_scope: string; recent_queries_tags: string; term: string; autocomplete_request_surface: number; }
interface PersonalResultOptions { query: string; scope: string; bookmarks?: string[]; }
interface SearchEnvelope { options: PersonalTypeaheadOptions | PersonalResultOptions; context: Record<string, string>; }
interface SearchPatch { query?: string; submitted?: string; editing?: boolean; loading?: boolean; error?: string; suggestions?: PinmonyProfileSearchSuggestion[]; pins?: PinmonyProfileSearchPin[]; ended?: boolean; }
export interface PinmonyProfileSearchPorts {
  store: () => PinmonyProfileStore;
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  active: () => boolean;
}

// Independent account-owned reads; never changes the global search or the background document route.
export class PinmonyProfileSearchNativeReads {
  private readonly ports: PinmonyProfileSearchPorts;
  private sequence: number = 0;
  private revision: number = 0;
  private timer: number = -1;
  private requests: Set<string> = new Set<string>();
  private account: string = '';
  private generation: number = -1;
  private origin: string = '';
  private interrupted: boolean = false;
  private cursor: string = '';
  private cursors: Set<string> = new Set<string>();
  private historyJob: string = '';
  private historyPending: string = '';
  private historyLocks: Set<string> = new Set<string>();
  constructor(ports: PinmonyProfileSearchPorts) { this.ports = ports; }
  private fresh(): PinmonyProfileSearchSnapshot {
    return { query: '', submitted: '', editing: true, loading: false, error: '', suggestions: [], pins: [], ended: false };
  }
  private live(revision: number): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return revision === this.revision && this.ports.active() && this.ports.store().searchVisible &&
      session.authenticated && session.accountId === this.account && session.generation === this.generation && session.origin === this.origin;
  }
  pause(): void {
    this.revision++;
    if (this.historyJob) this.ports.network().cancel(this.historyJob);
    this.historyJob = ''; this.historyPending = '';
    if (this.timer >= 0) clearTimeout(this.timer);
    this.timer = -1;
    this.requests.forEach((id: string): void => this.ports.network().cancel(id)); this.requests.clear();
    const value: PinmonyProfileSearchSnapshot | undefined = this.ports.store().contentSearch;
    this.interrupted = this.interrupted || value?.loading === true;
    if (value) this.update(this.change(value, { loading: false }));
  }
  resume(): void {
    if (!this.interrupted || !this.live(this.revision)) return;
    this.interrupted = false; this.retry();
  }
  close(): void { this.pause(); this.interrupted = false; this.ports.store().searchVisible = false; this.ports.store().contentSearch = undefined; this.cursor = ''; this.cursors.clear(); }
  open(): void {
    this.close(); const session: PinmonyBusinessSessionContext = this.ports.session();
    if (!session.authenticated || !session.accountId) return;
    if (this.account !== session.accountId || this.generation !== session.generation || this.origin !== session.origin) this.historyLocks.clear();
    this.account = session.accountId; this.generation = session.generation; this.origin = session.origin;
    this.ports.store().contentSearch = this.fresh(); this.ports.store().searchVisible = true; this.input('');
  }
  private change(value: PinmonyProfileSearchSnapshot, patch: SearchPatch): PinmonyProfileSearchSnapshot {
    const next: PinmonyProfileSearchSnapshot = JSON.parse(JSON.stringify(value)) as PinmonyProfileSearchSnapshot;
    if (patch.query !== undefined) next.query = patch.query;
    if (patch.submitted !== undefined) next.submitted = patch.submitted;
    if (patch.editing !== undefined) next.editing = patch.editing;
    if (patch.loading !== undefined) next.loading = patch.loading;
    if (patch.error !== undefined) next.error = patch.error;
    if (patch.suggestions !== undefined) next.suggestions = patch.suggestions;
    if (patch.pins !== undefined) next.pins = patch.pins;
    if (patch.ended !== undefined) next.ended = patch.ended;
    return next;
  }
  private update(value: PinmonyProfileSearchSnapshot): void {
    value.suggestions.forEach((item: PinmonyProfileSearchSuggestion): void => {
      item.deleting = this.historyPending === item.query;
      item.deletable = value.editing && !value.query.trim() && !this.historyPending && !this.historyLocks.has(item.query);
    });
    this.ports.store().contentSearch = value;
  }
  async deleteHistory(query: string): Promise<void> {
    const value: PinmonyProfileSearchSnapshot | undefined = this.ports.store().contentSearch;
    if (!this.live(this.revision) || !value?.editing || value.query.trim() || this.historyPending || this.historyLocks.has(query) ||
      !value.suggestions.some((item: PinmonyProfileSearchSuggestion): boolean => item.query === query && item.deletable === true)) return;
    const revision: number = this.revision, account: string = this.account, generation: number = this.generation;
    const id: string = 'native_profile_history_delete_' + (++this.sequence).toString();
    const live = (): boolean => this.live(revision) && this.historyJob === id && this.ports.store().contentSearch?.editing === true && !this.ports.store().contentSearch?.query.trim();
    this.historyJob = id; this.historyPending = query; this.historyLocks.add(query);
    this.update(this.change(value, { error: '' }));
    const payload: HistoryDeleteEnvelope = { options: { url: '/v3/search/recent/', data: { query: query, vertical: 'PERSONAL' } }, context: {} as Record<string, string> };
    const job: PinmonyNetworkJob = { id: id, epoch: generation, page: this.origin + '/search/me/',
      url: this.origin + '/resource/ApiResource/delete/', method: 'POST',
      body: 'source_url=' + encodeURIComponent('/search/me/') + '&data=' + encodeURIComponent(JSON.stringify(payload)),
      headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
        'X-Pinterest-Pws-Handler': 'www/search/me.js', 'Content-Type': 'application/x-www-form-urlencoded' } };
    let confirmed: boolean = false;
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessProfileSearchDelete(job,
        (): PinmonyBusinessSessionContext => this.ports.session(), query, live);
      if (reply.error || reply.status !== 200 || reply.body.length > 1000000) {
        // These failures are returned before native dispatch; an unknown sent result stays locked.
        if (['background', 'request-unavailable'].includes(reply.error) && this.account === account && this.generation === generation) this.historyLocks.delete(query);
        throw new Error('history-delete');
      }
      const resource: HistoryDeleteResource = (JSON.parse(reply.body) as HistoryDeleteResponse).resource_response;
      if (resource?.status === 'failure' && typeof resource.code === 'number' && resource.code !== 0 && this.account === account && this.generation === generation) this.historyLocks.delete(query);
      confirmed = resource?.status === 'success' && resource.code === 0 && resource.endpoint_name === 'v3_recent_search_delete';
      if (!confirmed) throw new Error('history-unconfirmed');
      if (this.account === account && this.generation === generation) this.historyLocks.delete(query);
      if (live()) {
        const current: PinmonyProfileSearchSnapshot = this.ports.store().contentSearch!;
        this.update(this.change(current, { suggestions: current.suggestions.filter((item: PinmonyProfileSearchSuggestion): boolean => item.query !== query), error: '' }));
      }
    } catch (_) {
      if (live()) this.update(this.change(this.ports.store().contentSearch!, { error: PinmonyI18n.message('pm_search_history_deletion_not_confirmed_refresh_history_to_check_faf71160') }));
    } finally {
      if (this.historyJob === id) {
        this.historyJob = ''; this.historyPending = '';
        if (this.live(revision) && this.ports.store().contentSearch) this.update(this.change(this.ports.store().contentSearch!, {}));
      }
    }
  }
  private pin(raw: SearchPin): PinmonyProfileSearchPin | undefined {
    if (!raw || !/^\d{1,40}$/.test(raw.id || '')) return undefined;
    const image: string = raw.images?.['236x']?.url || raw.images?.['474x']?.url || raw.images?.['originals']?.url || '';
    if (!/^https:\/\/i\.pinimg\.com\//i.test(image) || image.length > 2048) return undefined;
    return { id: raw.id!, image: image, title: (raw.grid_title || raw.title || raw.description || '').slice(0, 300) };
  }
  private async request(resource: string, page: string, options: PersonalTypeaheadOptions | PersonalResultOptions, revision: number): Promise<SearchResponse> {
    const id: string = 'native_profile_search_' + (++this.sequence).toString();
    const fields: string = 'source_url=' + encodeURIComponent(page) + '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} as Record<string, string> } as SearchEnvelope));
    const job: PinmonyNetworkJob = { id: id, epoch: this.generation, page: this.origin + page,
      url: this.origin + '/resource/' + resource + '/get/?' + fields, method: 'GET', body: '',
      headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
        'X-Pinterest-Pws-Handler': resource === 'AdvancedTypeaheadResource' ? 'www/search/me.js' : 'www/search/my_content.js' } };
    this.requests.add(id);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessProfileSearchRead(job,
        (): PinmonyBusinessSessionContext => this.ports.session(), (): boolean => this.live(revision));
      if (!this.live(revision) || reply.error || reply.status !== 200 || reply.body.length > 12000000) throw new Error('search-read');
      const response: SearchResponse = JSON.parse(reply.body) as SearchResponse;
      if (response.resource_response?.status !== 'success' || !response.resource_response.data) throw new Error('search-response');
      return response;
    } finally { this.requests.delete(id); }
  }
  input(query: string): void {
    if (query.length > 300 || !this.ports.store().searchVisible) return;
    this.pause(); this.interrupted = false; const revision: number = this.revision;
    const value: PinmonyProfileSearchSnapshot = this.ports.store().contentSearch || this.fresh();
    this.update(this.change(value, { query: query, editing: true, loading: true, error: '', suggestions: [] }));
    const load = async (): Promise<void> => {
      this.timer = -1; if (!this.live(revision)) return;
      try {
        const response: SearchResponse = await this.request('AdvancedTypeaheadResource', '/search/me/',
          { field_set_key: 'richResults', limit: 3, num_recent_queries: 20, personal_search_only: true,
            pin_scope: 'my_content', recent_queries_tags: 'recent_queries,recent_personal_searches', term: query, autocomplete_request_surface: 1 }, revision);
        if (!this.live(revision)) return;
        const items: Suggestion[] | undefined = response.resource_response.data.items;
        if (!Array.isArray(items)) throw new Error('suggestions');
        const suggestions: PinmonyProfileSearchSuggestion[] = [];
        items.slice(0, 60).forEach((item: Suggestion): void => {
          if (item.type !== (query.trim() ? 'personal_query' : 'recent_personal_searches') ||
            typeof item.query !== 'string' || !item.query.trim() || item.query.length > 300 || suggestions.some((s: PinmonyProfileSearchSuggestion): boolean => s.query === item.query)) return;
          const pins: PinmonyProfileSearchPin[] = [];
          if (Array.isArray(item.pins)) item.pins.slice(0, 4).forEach((raw: SearchPin): void => { const pin: PinmonyProfileSearchPin | undefined = this.pin(raw); if (pin) pins.push(pin); });
          suggestions.push({ query: item.query, pins: pins });
        });
        this.update(this.change(this.ports.store().contentSearch!, { loading: false, suggestions: suggestions }));
      } catch (_) { if (this.live(revision)) this.update(this.change(this.ports.store().contentSearch!, { loading: false, error: PinmonyI18n.message('pm_unable_to_load_search_suggestions_please_retry_547b05bc') })); }
    };
    if (!query) load(); else this.timer = setTimeout((): void => { load(); }, 250);
  }
  submit(query: string): void {
    const term: string = query.trim(); if (!term || term.length > 300 || !this.ports.store().searchVisible) return;
    this.pause(); this.interrupted = false; this.cursor = ''; this.cursors.clear();
    this.update(this.change(this.fresh(), { query: term, submitted: term, editing: false })); this.more();
  }
  async more(): Promise<void> {
    const value: PinmonyProfileSearchSnapshot | undefined = this.ports.store().contentSearch;
    if (!value || value.editing || value.loading || value.ended || !this.live(this.revision)) return;
    const revision: number = this.revision, cursor: string = this.cursor;
    this.update(this.change(value, { loading: true, error: '' }));
    const options: PersonalResultOptions = { query: value.submitted, scope: 'my_pins' };
    if (cursor) options.bookmarks = [cursor];
    try {
      const response: SearchResponse = await this.request('BaseSearchResource', '/search/my_content/?rs=ac&q=' + encodeURIComponent(value.submitted), options, revision);
      if (!this.live(revision)) return;
      const raw: SearchPin[] | undefined = response.resource_response.data.results;
      if (!Array.isArray(raw)) throw new Error('results');
      const pins: PinmonyProfileSearchPin[] = value.pins.slice(); let valid: number = 0;
      raw.slice(0, 100).forEach((item: SearchPin): void => { const pin: PinmonyProfileSearchPin | undefined = this.pin(item); if (pin) { valid++; if (!pins.some((p: PinmonyProfileSearchPin): boolean => p.id === pin.id)) pins.push(pin); } });
      if (raw.length && !valid) throw new Error('unknown-results');
      const next: string = response.resource_response.bookmark || '';
      if (typeof next !== 'string' || next.length > 4096) throw new Error('cursor');
      const ended: boolean = !next || next === '-end-' || next === cursor || this.cursors.has(next) || !raw.length;
      if (cursor) this.cursors.add(cursor); this.cursor = next;
      this.update(this.change(value, { loading: false, error: '', pins: pins, ended: ended }));
    } catch (_) { if (this.live(revision)) this.update(this.change(value, { loading: false, error: PinmonyI18n.message('pm_unable_to_load_search_results_please_retry_27aeffd1') })); }
  }
  retry(): void { const value: PinmonyProfileSearchSnapshot | undefined = this.ports.store().contentSearch; if (value?.editing) this.input(value.query); else this.more(); }
}
