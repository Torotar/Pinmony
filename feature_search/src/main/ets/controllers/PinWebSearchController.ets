import { PinWebSearchCategory, PinWebSearchFilterOption, PinWebSearchFilterSnapshot,
  PinWebSearchHero, PinWebSearchIdea, PinWebSearchIdeaSection, PinWebSearchResult,
  PinWebSearchSnapshot, PinWebSearchSuggestion } from '../models/PinWebSearch';
import { PinWebSearchPorts } from '../models/PinWebSearchPorts';
import { PinWebSearchStore } from '../stores/PinWebSearchStore';
import { PIN_SEARCH_UI_API_ENABLED } from '../services/PinWebSearchUiApiScript';
import { findSearchResult, mergeSearchFeedResults } from '../services/PinWebSearchRetention';
import { PinWebRuntimeLog, PinWebTaskRegistry } from 'common_foundation';

// Owns search business state; product navigation/session capabilities are injected.
export class PinWebSearchController {
  private readonly tasks: PinWebTaskRegistry = new PinWebTaskRegistry();
  private generation: number = 0;
  private readonly waiting: Set<() => void> = new Set<() => void>();
  private readonly searchStore: PinWebSearchStore;
  private readonly ports: PinWebSearchPorts;
  constructor(searchStore: PinWebSearchStore, ports: PinWebSearchPorts) {
    this.searchStore = searchStore;
    this.ports = ports;
  }

  invalidatePending(): void {
    this.generation++;
    this.searchStore.searchIntentToken++;
    this.searchStore.searchQueryToken++;
    this.searchStore.searchRequestToken++;
    this.searchStore.searchFilterToken++;
    this.cancelTimers();
    if (this.searchStore.searchFilterLoading) {
      this.searchStore.searchFilterLoading = false;
      this.searchStore.searchFilterError = '筛选读取已取消，请重试';
    }
  }

  private cancelTimers(): void {
    this.tasks.invalidate();
    this.waiting.forEach((settle: () => void): void => settle());
    this.waiting.clear();
  }

  private pause(delayMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      const settle = (): void => { this.waiting.delete(settle); resolve(); };
      this.waiting.add(settle);
      this.tasks.timeout(settle, delayMs);
    });
  }

  hasMeaningfulSearchPinTitle(value: string): boolean {
    const title: string = (value || '').trim();
    return !!title && !/^(?:标题暂不可用|pin(?:\s*(?:图|image|picture))?|图片|图像|image|photo)$/i.test(title);
  }

  mergeSearchIdeaSections(previous: PinWebSearchIdeaSection[],
    incoming: PinWebSearchIdeaSection[]): PinWebSearchIdeaSection[] {
    const merged: PinWebSearchIdeaSection[] = previous.map((section: PinWebSearchIdeaSection): PinWebSearchIdeaSection => {
      return {
        id: section.id, eyebrow: section.eyebrow, title: section.title, actionId: section.actionId,
        targetUrl: section.targetUrl,
        items: section.items.slice(0, 4)
      };
    });
    for (let sectionIndex: number = 0; sectionIndex < incoming.length; sectionIndex++) {
      const section: PinWebSearchIdeaSection = incoming[sectionIndex];
      let match: number = -1;
      for (let index: number = 0; index < merged.length; index++) {
        if (merged[index].title === section.title &&
          (!merged[index].eyebrow || !section.eyebrow || merged[index].eyebrow === section.eyebrow)) {
          match = index;
          break;
        }
      }
      if (match < 0) {
        if (merged.length < 24) merged.push({ id: section.id, eyebrow: section.eyebrow,
          title: section.title, actionId: section.actionId, targetUrl: section.targetUrl,
          items: section.items.slice(0, 4) });
        continue;
      }
      const current: PinWebSearchIdeaSection = merged[match];
      const items: PinWebSearchIdea[] = current.items.slice(0, 4);
      for (let itemIndex: number = 0; itemIndex < section.items.length; itemIndex++) {
        const item: PinWebSearchIdea = section.items[itemIndex];
        let existingIndex: number = -1;
        for (let candidateIndex: number = 0; candidateIndex < items.length; candidateIndex++) {
          if (items[candidateIndex].imageUrl === item.imageUrl) {
            existingIndex = candidateIndex;
            break;
          }
        }
        if (existingIndex >= 0) items[existingIndex] = item;
        else if (items.length < 4) items.push(item);
      }
      merged[match] = { id: current.id, eyebrow: section.eyebrow || current.eyebrow,
        title: current.title, actionId: section.actionId || current.actionId,
        targetUrl: section.targetUrl, items: items };
    }
    return merged;
  }

  clearSearch(): void {
    // A document reset may be part of the current user intent's context preparation.
    // Cancel old business timers without superseding that product intent.
    this.cancelTimers();
    this.ports.finishPull();
    const searchHasContent: boolean = !!this.searchStore.search &&
      (this.searchStore.searchActionsReady || this.searchStore.search.results.length > 0 ||
        this.searchStore.search.heroes.length > 0 || this.searchStore.search.ideaSections.length > 0);
    if (this.searchStore.search && searchHasContent) {
      const currentSearch: PinWebSearchSnapshot = this.searchStore.search;
      // A tab switch may interrupt an in-flight API response. Cache the last
      // visible content as a read-only state instead of retaining its busy or
      // error flags, which are intentionally rejected by PinWebSearchCache.
      const retainedSearch: PinWebSearchSnapshot = {
        kind: 'state', session: currentSearch.session, pageKey: currentSearch.pageKey,
        query: currentSearch.query, placeholder: currentSearch.placeholder,
        selectedCategory: currentSearch.selectedCategory, categories: currentSearch.categories,
        suggestions: currentSearch.suggestions, heroes: currentSearch.heroes,
        ideaSections: currentSearch.ideaSections, results: currentSearch.results,
        api: currentSearch.api, apiActive: currentSearch.apiActive, apiEnded: currentSearch.apiEnded,
        discoveryApi: currentSearch.discoveryApi, discoveryActive: currentSearch.discoveryActive,
        discoveryEnded: currentSearch.discoveryEnded,
        quiz: currentSearch.quiz ? {
          mode: currentSearch.quiz.mode, title: currentSearch.quiz.title,
          eyebrow: currentSearch.quiz.eyebrow, pickerTitle: currentSearch.quiz.pickerTitle,
          submitLabel: currentSearch.quiz.submitLabel, topics: currentSearch.quiz.topics,
          cards: currentSearch.quiz.cards, canMore: currentSearch.quiz.canMore,
          count: currentSearch.quiz.count, busy: false, error: ''
        } : undefined
      };
      this.searchStore.searchCache.put(retainedSearch, this.searchStore.searchScrollOffset);
    }
    if (this.ports.sheetKind() === 'searchFilter') this.dismissSearchFilters();
    this.searchStore.searchRequestToken++;
    this.searchStore.searchQueryToken++;
    if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    this.searchStore.search = undefined;
    this.searchStore.searchActionsReady = false;
    this.searchStore.searchInputReady = false;
    this.searchStore.searchScrollOffset = 0;
    this.searchStore.searchLoading = false;
    this.searchStore.searchError = '';
    this.searchStore.searchReturnPageKey = '';
  }

  searchPlaceholder(): PinWebSearchSnapshot {
    return { kind: 'loading', session: 0, pageKey: this.ports.currentPageKey(), query: '',
      placeholder: '', selectedCategory: '', categories: [], suggestions: [], heroes: [],
      ideaSections: [], results: [] };
  }

  restoreRetainedSearch(pageKey: string): boolean {
    const cached = this.searchStore.searchCache.get(pageKey);
    if (cached) {
      this.searchStore.retainedSearch = cached.snapshot;
      this.searchStore.retainedSearchScrollOffset = cached.scrollOffset;
    }
    if (!this.searchStore.retainedSearch || this.searchStore.retainedSearch.pageKey !== pageKey) return false;
    this.searchStore.search = this.searchStore.retainedSearch;
    this.searchStore.searchScrollOffset = this.searchStore.retainedSearchScrollOffset;
    this.searchStore.searchReturnPageKey = pageKey;
    this.searchStore.searchActionsReady = false;
    this.searchStore.searchInputReady = false;
    this.searchStore.searchLoading = false;
    this.searchStore.searchError = '';
    return true;
  }

  private searchFilterScript(name: string, id?: string): string {
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search) return 'false';
    return 'window.' + name + ' && window.' + name + '(' + search.session.toString() + ',' +
      JSON.stringify(search.pageKey) + (id ? ',' + JSON.stringify(id) : '') + ')';
  }

  async openSearchFilters(): Promise<void> {
    const generation: number = this.generation;
    if (!await this.ports.ensureContext(true) || generation !== this.generation) return;
    if (!this.searchStore.searchActionsReady) return;
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search || !search.query.trim() || search.pageKey !== this.ports.currentPageKey() || this.ports.sheetKind()) return;
    if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    const token: number = ++this.searchStore.searchFilterToken;
    this.searchStore.searchFilterOptions = [];
    this.searchStore.searchFilterError = '';
    this.searchStore.searchFilterLoading = true;
    this.ports.setFilterVisible(true);
    try {
      if (PIN_SEARCH_UI_API_ENABLED) {
        await this.ports.runScript('window.PinWebSearchUiApi && window.PinWebSearchUiApi.prepareFilters()');
        if (token !== this.searchStore.searchFilterToken) return;
      }
      const opened: string = await this.ports.runScript(this.searchFilterScript('PinWebSearchOpenFilters'));
      if (token !== this.searchStore.searchFilterToken) return;
      if (opened !== 'true' && opened !== '"true"') {
        this.searchStore.searchFilterLoading = false;
        this.searchStore.searchFilterError = '无法读取当前 Pinterest 页面的筛选入口';
        return;
      }
      await this.pause(280);
      await this.refreshSearchFilters(token);
    } catch (error) {
      if (token !== this.searchStore.searchFilterToken) return;
      this.searchStore.searchFilterLoading = false;
      this.searchStore.searchFilterError = '筛选器读取失败，请重试';
    }
  }

  async refreshSearchFilters(token: number = this.searchStore.searchFilterToken, attempt: number = 0): Promise<void> {
    if (token !== this.searchStore.searchFilterToken || this.ports.sheetKind() !== 'searchFilter') return;
    try {
      const raw: string = await this.ports.runScript('JSON.stringify(' +
        this.searchFilterScript('PinWebSearchReadFilters') + ')');
      if (token !== this.searchStore.searchFilterToken) return;
      let parsed: Object = JSON.parse(raw) as Object;
      if (typeof parsed === 'string') parsed = JSON.parse(parsed as string) as Object;
      const snapshot: PinWebSearchFilterSnapshot | undefined = !Array.isArray(parsed) && parsed ?
        parsed as PinWebSearchFilterSnapshot : undefined;
      if (PIN_SEARCH_UI_API_ENABLED && (!snapshot || !Array.isArray(snapshot.options) ||
          typeof snapshot.loading !== 'boolean' || typeof snapshot.error !== 'string')) {
        this.searchStore.searchFilterOptions = [];
        this.searchStore.searchFilterError = '筛选接口桥接响应无效，请重试';
        this.searchStore.searchFilterLoading = false;
        return;
      }
      if (snapshot && snapshot.loading) {
        if (attempt >= 60) {
          this.searchStore.searchFilterError = snapshot.status === 'session-sync' ? '搜索会话尚未同步，请重新打开筛选器' :
            '筛选接口尚未取得当前搜索数据，请重试';
          this.searchStore.searchFilterLoading = false;
          return;
        }
        await this.pause(250);
        await this.refreshSearchFilters(token, attempt + 1);
        return;
      }
      const options: PinWebSearchFilterOption[] = snapshot && Array.isArray(snapshot.options) ? snapshot.options :
        Array.isArray(parsed) ? parsed as PinWebSearchFilterOption[] : [];
      this.searchStore.searchFilterOptions = options.filter(
        (item: PinWebSearchFilterOption): boolean => !!item.id && !!item.label);
      this.searchStore.searchFilterError = snapshot && snapshot.error ? snapshot.error :
        this.searchStore.searchFilterOptions.length ? '' : PIN_SEARCH_UI_API_ENABLED ?
          '筛选接口返回空列表，请重试' : '当前网页没有可用的筛选选项';
    } catch (error) {
      if (token !== this.searchStore.searchFilterToken) return;
      this.searchStore.searchFilterError = '筛选选项读取失败，请重试';
    }
    this.searchStore.searchFilterLoading = false;
  }

  async retrySearchFilters(): Promise<void> {
    if (this.ports.sheetKind() !== 'searchFilter' || this.searchStore.searchFilterLoading) return;
    const token: number = ++this.searchStore.searchFilterToken;
    this.searchStore.searchFilterLoading = true;
    this.searchStore.searchFilterError = '';
    try {
      await this.ports.runScript('window.PinWebSearchUiApi && window.PinWebSearchUiApi.retryFilters()');
      const opened: string = await this.ports.runScript(this.searchFilterScript('PinWebSearchOpenFilters'));
      if (token !== this.searchStore.searchFilterToken) return;
      if (opened !== 'true' && opened !== '"true"') {
        this.searchStore.searchFilterError = '无法读取当前 Pinterest 页面的筛选入口';
        this.searchStore.searchFilterLoading = false;
        return;
      }
      await this.pause(280);
      await this.refreshSearchFilters(token);
    } catch (error) {
      if (token === this.searchStore.searchFilterToken) {
        this.searchStore.searchFilterLoading = false;
        this.searchStore.searchFilterError = '筛选器读取失败，请重试';
      }
    }
  }

  async selectSearchFilter(id: string): Promise<void> {
    this.ports.traceAction('search.filter', id);
    const token: number = this.searchStore.searchFilterToken;
    if (this.ports.sheetKind() !== 'searchFilter' || this.searchStore.searchFilterLoading ||
        !this.searchStore.searchFilterOptions.some((item: PinWebSearchFilterOption): boolean => item.id === id && item.enabled && !item.selected)) return;
    if (!await this.ports.ensureContext(true, 'searchFilter', (): boolean =>
        token === this.searchStore.searchFilterToken && this.ports.sheetKind() === 'searchFilter')) return;
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search) return;
    try {
      const raw: string = await this.ports.runScript('window.PinWebSearchUiApi && window.PinWebSearchUiApi.filterTarget(' +
        JSON.stringify(search.pageKey) + ',' + JSON.stringify(id) + ')');
      if (token !== this.searchStore.searchFilterToken || this.ports.sheetKind() !== 'searchFilter') return;
      let target: string = raw;
      if (raw.startsWith('"')) target = JSON.parse(raw) as string;
      if (!/^https:\/\/www\.pinterest\.com\/search\/(?:pins|videos|boards|users|buyable_pins)\/\?q=/.test(target)) return;
      this.dismissSearchFilters();
      this.searchStore.searchResultsResetPending = true;
      this.searchStore.searchScrollOffset = 0;
      this.ports.navigateSearch(target, '');
      PinWebRuntimeLog.info('SearchFilterTrace: type-navigation');
    } catch (_) {
      if (token === this.searchStore.searchFilterToken) this.searchStore.searchFilterError = '筛选导航失败，请重试';
    }
  }

  dismissSearchFilters(): void {
    if (this.ports.sheetKind() !== 'searchFilter') return;
    const script: string = this.searchFilterScript('PinWebSearchCloseFilters');
    this.searchStore.searchFilterToken++;
    this.ports.setFilterVisible(false);
    this.searchStore.searchFilterLoading = false;
    this.searchStore.searchFilterError = '';
    this.searchStore.searchFilterOptions = [];
    this.ports.runScript(script).catch(() => PinWebRuntimeLog.warn('PinWeb: could not close web search filters'));
  }

  expectSearch(): void {
    const pageKey: string = this.ports.currentPageKey();
    if (!pageKey) return;
    const token: number = ++this.searchStore.searchRequestToken;
    this.searchStore.searchLoading = true;
    this.searchStore.searchError = '';
    this.tasks.timeout(() => {
      if (token !== this.searchStore.searchRequestToken || !this.searchStore.searchLoading) return;
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = '无法读取当前 Pinterest 搜索内容';
    }, 8000);
  }

  updateSearch(value: string): void {
    try {
      const message: PinWebSearchSnapshot = JSON.parse(value) as PinWebSearchSnapshot;
      if (!message || typeof message.session !== 'number' || typeof message.pageKey !== 'string') return;
      const activePage: string = this.ports.currentPageKey();
      if (activePage && (!this.searchStore.search || this.searchStore.search.pageKey !== activePage)) this.restoreRetainedSearch(activePage);
      const preservingPinSearch: boolean = this.ports.preservingPinSearch();
      if (this.searchStore.search && this.searchStore.search.pageKey !== activePage && !preservingPinSearch) {
        this.searchStore.search = undefined;
        this.searchStore.searchError = '';
        this.searchStore.searchReturnPageKey = '';
        this.ports.setDetailReturn('');
        this.searchStore.searchLoading = !!activePage;
        if (activePage) this.expectSearch();
      }
      if (message.kind === 'closed') {
        if (!activePage && !preservingPinSearch) this.clearSearch();
        return;
      }
      if (message.pageKey !== activePage) return;
      if (this.searchStore.searchQueryClearPage === activePage) {
        if ((message.query || '').trim()) {
          if (message.kind === 'state') {
            // Use the newly confirmed session when returning from a cache.
            this.ports.runScript('window.PinWebSearchQuery && window.PinWebSearchQuery(' +
              message.session.toString() + ',' + JSON.stringify(message.pageKey) + ',"")')
              .catch(() => PinWebRuntimeLog.warn('PinWeb: search query dismissal unavailable'));
          }
          return;
        }
        if (message.kind === 'state') this.searchStore.searchQueryClearPage = '';
      }
      if (this.searchStore.searchActionsReady && this.searchStore.search && this.searchStore.search.pageKey === message.pageKey &&
          message.session < this.searchStore.search.session) return;
      const retainedContext: boolean = !!this.searchStore.retainedSearch && this.searchStore.retainedSearch.pageKey === message.pageKey;
      if (!message.api && retainedContext && (message.kind === 'loading' || message.kind === 'unavailable')) {
        this.searchStore.searchActionsReady = false;
        this.searchStore.searchInputReady = false;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '';
        return;
      }
      if (message.kind === 'unavailable') {
        this.ports.finishPull();
        this.searchStore.searchRequestToken++;
        this.searchStore.search = undefined;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '无法识别当前 Pinterest 搜索内容';
        this.searchStore.searchReturnPageKey = '';
        this.ports.setDetailReturn('');
        return;
      }
      if (!message.api && message.kind === 'loading' && this.searchStore.searchError) return;
      if ((message.kind !== 'state' && message.kind !== 'loading') ||
          !Array.isArray(message.categories) || !Array.isArray(message.suggestions) ||
          !Array.isArray(message.results)) return;
      const categories: PinWebSearchCategory[] = message.categories.filter((item: PinWebSearchCategory): boolean =>
        !!item.id && !!item.label);
      const suggestions: PinWebSearchSuggestion[] = message.suggestions.filter((item: PinWebSearchSuggestion): boolean =>
        !!item.id && !!item.label);
      let heroes: PinWebSearchHero[] = Array.isArray(message.heroes) ?
        message.heroes.filter((item: PinWebSearchHero): boolean => !!item.id && !!item.title &&
          /^https:\/\//i.test(item.imageUrl)) : [];
      let ideaSections: PinWebSearchIdeaSection[] = Array.isArray(message.ideaSections) ?
        message.ideaSections.filter((section: PinWebSearchIdeaSection): boolean => !!section.id && !!section.title &&
          Array.isArray(section.items)).map((section: PinWebSearchIdeaSection): PinWebSearchIdeaSection => {
            return {
              id: section.id,
              eyebrow: section.eyebrow || '',
              title: section.title,
              actionId: section.actionId || '',
              targetUrl: section.targetUrl,
              items: section.items.filter((item) => !!item.id && !!item.title && /^https:\/\//i.test(item.imageUrl))
            };
          }) : [];
      let results: PinWebSearchResult[] = message.results.filter((item: PinWebSearchResult): boolean =>
        !!item.id && (item.kind === 'pin' || !!item.title) && /^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(item.targetUrl) &&
          (!item.imageUrl || /^https:\/\//i.test(item.imageUrl)));
      results = results.map((item: PinWebSearchResult): PinWebSearchResult => {
        const title: string | undefined = this.searchStore.knownSearchPinTitles.get(this.ports.pinIdentity(item.targetUrl));
        if (item.kind !== 'pin' || !title) return item;
        return { id: item.id, kind: item.kind, title: title, subtitle: item.subtitle,
          targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
          imageHeight: item.imageHeight, video: item.video, enabled: item.enabled };
      });
      const previousSearch: PinWebSearchSnapshot | undefined = this.searchStore.search;
      if (!message.api && retainedContext && this.searchStore.retainedSearch && message.kind === 'state') {
        if ((message.query || '') !== this.searchStore.retainedSearch.query) return;
        if (this.searchStore.retainedSearch.query && !results.length) return;
      }
      if (previousSearch) {
        results = results.map((item: PinWebSearchResult): PinWebSearchResult => {
          if (item.kind !== 'pin' || this.hasMeaningfulSearchPinTitle(item.title)) return item;
          const previousItem: PinWebSearchResult | undefined = previousSearch.results.find(
            (candidate: PinWebSearchResult): boolean => candidate.kind === 'pin' &&
              this.ports.pinIdentity(candidate.targetUrl) === this.ports.pinIdentity(item.targetUrl));
          if (!previousItem || !this.hasMeaningfulSearchPinTitle(previousItem.title)) return item;
          return { id: item.id, kind: item.kind, title: previousItem.title, subtitle: item.subtitle,
            targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
            imageHeight: item.imageHeight, video: item.video, enabled: item.enabled };
        });
      }
      const retainingApiResults: boolean = message.api === true && !!previousSearch &&
        previousSearch.pageKey === message.pageKey && previousSearch.query === (message.query || '') &&
        !this.searchStore.searchResultsResetPending && (message.kind === 'loading' || message.apiBusy === true || !!message.apiError);
      const sameSearchContext: boolean = (!message.api || retainingApiResults) && !this.searchStore.searchResultsResetPending && !!previousSearch &&
        previousSearch.pageKey === message.pageKey && previousSearch.query === (message.query || '') &&
        (!message.selectedCategory || !previousSearch.selectedCategory ||
          previousSearch.selectedCategory === message.selectedCategory);
      results = mergeSearchFeedResults(sameSearchContext && previousSearch ? previousSearch.results : [], results);
      const preservedSearchResults: boolean = sameSearchContext && results.length > 0;
      const sameDiscoverySession: boolean = !message.query && !!previousSearch &&
        (message.discoveryBusy === true || !!message.discoveryError || message.discoveryActive !== true) &&
        previousSearch.pageKey === message.pageKey &&
        !previousSearch.query;
      if (sameDiscoverySession && previousSearch) {
        if (heroes.length === 0) heroes = previousSearch.heroes;
        ideaSections = this.mergeSearchIdeaSections(previousSearch.ideaSections, ideaSections);
      }
      const preservedDiscovery: boolean = sameDiscoverySession && !!previousSearch &&
        (previousSearch.heroes.length > 0 || previousSearch.ideaSections.length > 0);
      const stableKind: string = message.kind === 'loading' && (preservedDiscovery || preservedSearchResults) ?
        'state' : message.kind;
      if (this.searchStore.searchQuizReturnPage === message.pageKey) {
        if (!message.quiz || message.quiz.mode === 'entry') this.searchStore.searchQuizReturnPage = '';
        else message.quiz = previousSearch && previousSearch.pageKey === message.pageKey &&
          previousSearch.quiz && previousSearch.quiz.mode === 'entry' ? previousSearch.quiz : undefined;
      } else if (this.searchStore.searchQuizReturnPage) this.searchStore.searchQuizReturnPage = '';
      this.searchStore.search = { kind: stableKind, session: message.session, pageKey: message.pageKey,
        quiz: message.quiz, inputReady: message.inputReady === true,
        api: message.api, apiError: message.apiError,
        suggestionBusy: message.suggestionBusy, suggestionError: message.suggestionError,
        discoveryApi: message.discoveryApi, discoveryBusy: message.discoveryBusy,
        discoveryError: message.discoveryError, discoveryActive: message.discoveryActive,
        discoveryEnded: message.discoveryEnded,
        apiBusy: message.apiBusy, apiActive: message.apiActive, apiEnded: message.apiEnded,
        query: message.query || '', placeholder: message.placeholder || '',
        selectedCategory: message.selectedCategory || '', categories: categories,
        suggestions: suggestions, heroes: heroes, ideaSections: ideaSections, results: results };
      this.searchStore.searchActionsReady = message.kind === 'state' && !retainingApiResults;
      this.searchStore.searchInputReady = message.inputReady === true;
      if (this.searchStore.searchInputReady) this.ports.recordPageKey(message.pageKey);
      if (!!message.apiError || !!message.discoveryError || message.kind === 'state' &&
          !message.apiBusy && !message.discoveryBusy) this.ports.finishPull();
      if (this.searchStore.searchActionsReady) this.ports.recordPageKey(message.pageKey);
      if (message.kind === 'state') this.searchStore.searchResultsResetPending = false;
      if (retainedContext && stableKind === 'state') this.searchStore.retainedSearch = this.searchStore.search;
      if (stableKind === 'state') {
        if (!message.apiError) this.searchStore.searchCache.put(this.searchStore.search, this.searchStore.searchScrollOffset);
        this.searchStore.searchRequestToken++;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '';
      } else {
        this.searchStore.searchLoading = true;
      }
      if (message.api) {
        this.searchStore.searchRequestToken++;
        this.searchStore.searchLoading = message.kind === 'loading' && !preservedSearchResults;
        this.searchStore.searchError = message.apiError || '';
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: invalid search state');
    }
  }

  async updateSearchQuery(value: string, refreshSuggestions: boolean = false): Promise<void> {
    if (refreshSuggestions) PinWebRuntimeLog.info("SearchInputTrace: panel-open refresh=true");
    if (value.trim()) this.searchStore.searchQueryClearPage = '';
    const intent: number = ++this.searchStore.searchIntentToken;
    if (!await this.ports.ensureContext(false) || intent !== this.searchStore.searchIntentToken) return;
    const token: number = ++this.searchStore.searchQueryToken;
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search || !(this.searchStore.searchInputReady || this.searchStore.searchActionsReady) || search.pageKey !== this.ports.currentPageKey()) return;
    this.ports.markInteracted();
    try {
      const result: string = await this.ports.runScript('window.PinWebSearchQuery && ' +
        'window.PinWebSearchQuery(' + search.session.toString() + ',' + JSON.stringify(search.pageKey) + ',' +
        JSON.stringify(value) + ',' + (refreshSuggestions ? 'true' : 'false') + ')');
      if (token === this.searchStore.searchQueryToken && result !== 'true' && result !== '"true"') {
        this.searchStore.searchRequestToken++;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '搜索输入暂不可用，请重试';
      }
    } catch (error) {
      if (token === this.searchStore.searchQueryToken) {
        this.searchStore.searchRequestToken++;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '搜索输入暂不可用，请重试';
      }
    }
  }

  async submitSearch(value: string): Promise<void> {
    if (typeof value !== 'string' || !value.trim() || value.length > 300) return;
    this.searchStore.searchQueryClearPage = '';
    const intent: number = ++this.searchStore.searchIntentToken;
    this.searchStore.searchQueryToken++;
    if (!await this.ports.ensureContext(false) || intent !== this.searchStore.searchIntentToken) return;
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search || !(this.searchStore.searchInputReady || this.searchStore.searchActionsReady) || search.pageKey !== this.ports.currentPageKey()) return;
    if (this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false; this.searchStore.searchInputStopEditing = undefined;
    this.ports.clearTabGuard('search-submit');
    this.searchStore.retainedSearch = undefined;
    this.searchStore.searchResultsResetPending = true;
    this.searchStore.searchScrollOffset = 0;
    this.searchStore.searchRequestToken++;
    const target: string = 'https://www.pinterest.com/search/pins/?q=' + encodeURIComponent(value.trim());
    try {
      this.ports.navigateSearch(target, search.pageKey);
      PinWebRuntimeLog.info('SearchNavigationTrace: submit-native');
    } catch (_) {
      this.ports.cancelNavigation(false);
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = '无法提交搜索，请重试';
      this.searchStore.searchResultsResetPending = false;
    }
  }

  async performSearchAction(id: string, kind: string): Promise<void> {
    if (kind === 'result') this.ports.traceAction('search.pin.open');
    this.ports.traceAction('search.action.' + kind, id);
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search || !id || !this.ports.isActive()) return;
    if (kind === 'deleteHistory') {
      const generation: number = this.generation;
      if (!this.searchStore.searchInputReady && !this.searchStore.searchActionsReady) return;
      const item: PinWebSearchSuggestion | undefined = search.suggestions.find((value: PinWebSearchSuggestion): boolean => value.id === id && value.deletable === true && value.deleting !== true);
      if (!item || search.query.trim()) return;
      try {
        await this.ports.runScript('window.PinWebSearchDeleteHistory && window.PinWebSearchDeleteHistory(' + search.session + ',' + JSON.stringify(search.pageKey) + ',' + JSON.stringify(id) + ')');
      } catch (_) {
        if (generation === this.generation && search.pageKey === this.ports.currentPageKey())
          this.searchStore.searchError = '删除搜索历史未能确认成功，请刷新历史后检查';
      }
      return;
    }
    if (kind === 'suggestion') {
      const suggestion: PinWebSearchSuggestion | undefined = search.suggestions.find((item: PinWebSearchSuggestion): boolean => item.id === id && item.enabled);
      if (suggestion) await this.submitSearch(suggestion.query || suggestion.label);
      return;
    }
    if (kind !== 'result' && !(kind === 'category' && search.api) &&
        !(search.discoveryApi && (kind === 'idea' || kind === 'ideaSection'))) return;
    this.ports.clearTabGuard('search-action');
    if (kind === 'category' && search.api) {
      const guide: PinWebSearchCategory | undefined = search.categories.find((item: PinWebSearchCategory): boolean =>
        item.id === id && item.enabled);
      const target: string = guide?.targetUrl || '';
      const origin: string = search.pageKey.split('/').slice(0, 3).join('/');
      if (!target.startsWith(origin + '/search/pins/?q=') || !/^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(target)) return;
      this.searchStore.searchRequestToken++;
      this.searchStore.searchCache.put(search, this.searchStore.searchScrollOffset);
      this.searchStore.searchResultsResetPending = true;
      this.searchStore.searchScrollOffset = 0;
      if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
      this.searchStore.searchInputFocused = false;
      this.searchStore.searchInputStopEditing = undefined;
      try {
        this.ports.navigateSearch(target, search.pageKey);
      }
      catch (_) {
        this.ports.cancelNavigation(true);
        this.searchStore.searchLoading = false;
        this.searchStore.searchResultsResetPending = false;
        this.ports.showMessage('无法打开此搜索分类，请重试');
      }
      return;
    }
    if (kind !== 'result' && !(search.discoveryApi && (kind === 'idea' || kind === 'ideaSection'))) return;
    const token: number = ++this.searchStore.searchRequestToken;
    const navigationAction: boolean = kind === 'result' || kind === 'idea' || kind === 'ideaSection';
    const resultItem: PinWebSearchResult | undefined = kind === 'result' ?
      findSearchResult(search.results, id) : undefined;
    if (kind === 'result') {
      const targetUrl: string = resultItem ? resultItem.targetUrl : id;
      if (!/^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(targetUrl)) {
        this.ports.showMessage('这张帖子的链接暂不可用，请重新读取搜索结果');
        return;
      }
      this.searchStore.retainedSearch = search;
      this.searchStore.retainedSearchScrollOffset = this.searchStore.searchScrollOffset;
      this.searchStore.searchReturnPageKey = search.pageKey;
      this.ports.setDetailReturn(search.pageKey);
      if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
      this.searchStore.searchInputFocused = false;
      this.searchStore.searchInputStopEditing = undefined;
      try {
        // Record the actual source even if the SPA never reported its route.
        this.ports.navigateResult(targetUrl, search.pageKey);
      } catch (error) {
        this.ports.clearOpeningDetail();
        this.ports.showMessage('无法打开此 Pinterest 内容，请重试');
      }
      return;
    }
    if (search.discoveryApi && (kind === 'idea' || kind === 'ideaSection')) {
      let targetUrl: string = '';
      for (const section of search.ideaSections) {
        if (kind === 'ideaSection' && section.actionId === id) {
          targetUrl = section.targetUrl || '';
          // Older retained snapshots may lack the section URL while their API cards still carry it.
          if (!targetUrl) {
            const card: PinWebSearchIdea | undefined = section.items.find((item: PinWebSearchIdea): boolean =>
              item.enabled && !!item.targetUrl);
            targetUrl = card?.targetUrl || '';
          }
          break;
        }
        if (kind === 'idea') {
          for (const item of section.items) {
            if (item.id === id && item.enabled) {
              targetUrl = item.targetUrl || '';
              break;
            }
          }
          if (targetUrl) break;
        }
      }
      // Use only the API URL attached to a card in the current page snapshot.
      if (!/^https:\/\/(?:[^/]+\.)?pinterest\.com\/search\/pins\//i.test(targetUrl)) {
        this.ports.showMessage('这个主题的链接已失效，请重新读取');
        return;
      }
      this.searchStore.retainedSearch = search;
      this.searchStore.retainedSearchScrollOffset = this.searchStore.searchScrollOffset;
      this.searchStore.searchReturnPageKey = search.pageKey;
      if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
      this.searchStore.searchInputFocused = false;
      this.searchStore.searchInputStopEditing = undefined;
      try {
        this.ports.navigateSearch(targetUrl, search.pageKey);
      } catch (error) {
        this.ports.cancelNavigation(true);
        this.searchStore.searchLoading = false;
        this.ports.showMessage('无法打开此 Pinterest 内容，请重试');
      }
      return;
    }
    if (!navigationAction) {
      this.searchStore.retainedSearch = undefined;
      this.searchStore.searchResultsResetPending = true;
      this.searchStore.searchScrollOffset = 0;
    }
    if (!navigationAction) {
      this.searchStore.searchLoading = true;
      this.searchStore.searchError = '';
    }
    try {
      const result: string = await this.ports.runScript('window.PinWebSearchAction && ' +
        'window.PinWebSearchAction(' + search.session.toString() + ',' + JSON.stringify(search.pageKey) + ',' +
        JSON.stringify(id) + ',' + JSON.stringify(kind) + ')');
      if (result === 'true' || result === '"true"') {
        if (navigationAction) {
          return;
        }
        this.tasks.timeout(() => {
          if (token !== this.searchStore.searchRequestToken || !this.searchStore.searchLoading) return;
          this.searchStore.searchLoading = false;
          this.searchStore.searchError = '搜索分类尚未更新，请重试';
        }, 5000);
        return;
      }
    } catch (error) {
      PinWebRuntimeLog.warn('PinWeb: search action unavailable');
    }
    if (token !== this.searchStore.searchRequestToken) return;
    this.searchStore.searchLoading = false;
    this.searchStore.searchResultsResetPending = false;
    if (navigationAction) this.ports.showMessage('无法打开此 Pinterest 内容，请重试');
    else this.searchStore.searchError = '当前搜索选项暂不可用，请重试';
  }

  loadMoreSearch(): void {
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!search || !this.searchStore.searchActionsReady || this.searchStore.searchLoading || search.pageKey !== this.ports.currentPageKey()) return;
    this.ports.runScript('window.PinWebSearchLoadMore && ' +
      'window.PinWebSearchLoadMore(' + search.session.toString() + ',' + JSON.stringify(search.pageKey) + ')')
      .catch(() => PinWebRuntimeLog.warn('PinWeb: search loading unavailable'));
  }

  async refreshSearch(): Promise<void> {
    const generation: number = this.generation;
    if (this.ports.prepareRead()) return;
    this.searchStore.retainedSearch = undefined;
    this.searchStore.searchResultsResetPending = true;
    const pageKey: string = this.ports.currentPageKey();
    if (!pageKey) {
      this.ports.requestRead();
      return;
    }
    this.expectSearch();
    const token: number = this.searchStore.searchRequestToken;
    const search: PinWebSearchSnapshot | undefined = this.searchStore.search;
    try {
      const result: string = await this.ports.runScript('window.PinWebSearchRefresh && ' +
        'window.PinWebSearchRefresh(' + (search ? search.session.toString() : 'undefined') + ',' +
        (search ? JSON.stringify(search.pageKey) : 'undefined') + ')');
      if (generation !== this.generation || token !== this.searchStore.searchRequestToken || pageKey !== this.ports.currentPageKey()) return;
      if (result === 'false' || result === '"false"') {
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = '无法重新读取搜索内容';
        this.searchStore.searchResultsResetPending = false;
      }
    } catch (error) {
      if (generation !== this.generation || token !== this.searchStore.searchRequestToken || pageKey !== this.ports.currentPageKey()) return;
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = '无法重新读取搜索内容';
      this.searchStore.searchResultsResetPending = false;
    }
  }

  async performSearchQuizAction(kind: string, id: string): Promise<void> {
    const generation: number = this.generation;
    if (!await this.ports.ensureContext(true) || generation !== this.generation) return;
    const current: PinWebSearchSnapshot | undefined = this.searchStore.search;
    if (!current || current.pageKey !== this.ports.currentPageKey()) return;
    try {
      const result: string = await this.ports.runScript('window.PinWebSearchQuizAction && window.PinWebSearchQuizAction(' +
        current.session.toString() + ',' + JSON.stringify(current.pageKey) + ',' +
        JSON.stringify(kind) + ',' + JSON.stringify(id) + ')');
      if (generation !== this.generation || current.pageKey !== this.ports.currentPageKey()) return;
      if (result !== 'true' && result !== '"true"') this.ports.showMessage('灵感推荐操作尚未就绪，请重试');
    } catch (_) {
      if (generation === this.generation && current.pageKey === this.ports.currentPageKey()) this.ports.showMessage('无法操作灵感推荐，请重试');
    }
  }
}
