import { PinmonyI18n } from 'common_foundation';
import { PinmonySearchCategory, PinmonySearchFilterOption, PinmonySearchFilterSnapshot,
  PinmonySearchHero, PinmonySearchIdea, PinmonySearchIdeaSection, PinmonySearchResult,
  PinmonySearchSnapshot, PinmonySearchSuggestion } from '../models/PinmonySearch';
import { PinmonySearchPorts } from '../models/PinmonySearchPorts';
import { PinmonySearchStore } from '../stores/PinmonySearchStore';
import { PIN_SEARCH_UI_API_ENABLED } from '../services/PinmonySearchUiApiScript';
import { findSearchResult, mergeSearchFeedResults } from '../services/PinmonySearchRetention';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';

// Owns search business state; product navigation/session capabilities are injected.
export class PinmonySearchController {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private readonly waiting: Set<() => void> = new Set<() => void>();
  private readonly searchStore: PinmonySearchStore;
  private readonly ports: PinmonySearchPorts;
  constructor(searchStore: PinmonySearchStore, ports: PinmonySearchPorts) {
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
      this.searchStore.searchFilterError = PinmonyI18n.message('筛选读取已取消，请重试');
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

  mergeSearchIdeaSections(previous: PinmonySearchIdeaSection[],
    incoming: PinmonySearchIdeaSection[]): PinmonySearchIdeaSection[] {
    const merged: PinmonySearchIdeaSection[] = previous.map((section: PinmonySearchIdeaSection): PinmonySearchIdeaSection => {
      return {
        id: section.id, eyebrow: section.eyebrow, title: section.title, actionId: section.actionId,
        targetUrl: section.targetUrl,
        items: section.items.slice(0, 4)
      };
    });
    for (let sectionIndex: number = 0; sectionIndex < incoming.length; sectionIndex++) {
      const section: PinmonySearchIdeaSection = incoming[sectionIndex];
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
      const current: PinmonySearchIdeaSection = merged[match];
      const items: PinmonySearchIdea[] = current.items.slice(0, 4);
      for (let itemIndex: number = 0; itemIndex < section.items.length; itemIndex++) {
        const item: PinmonySearchIdea = section.items[itemIndex];
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
    if (this.ports.nativeSearch?.()) { this.cancelTimers(); this.ports.finishPull(); this.searchStore.searchActionsReady = false; this.searchStore.searchInputReady = false; this.ports.nativeDiscoveryApply?.(); this.ports.nativeSearchApply?.(); return; }
    if (this.ports.nativeDiscovery?.()) {
      this.cancelTimers(); this.ports.finishPull();
      this.searchStore.searchActionsReady = false; this.searchStore.searchInputReady = false;
      this.ports.nativeDiscoveryApply?.(); return;
    }
    // A document reset may be part of the current user intent's context preparation.
    // Cancel old business timers without superseding that product intent.
    this.cancelTimers();
    this.ports.finishPull();
    const searchHasContent: boolean = !!this.searchStore.search &&
      (this.searchStore.searchActionsReady || this.searchStore.search.results.length > 0 ||
        this.searchStore.search.heroes.length > 0 || this.searchStore.search.ideaSections.length > 0);
    if (this.searchStore.search && searchHasContent) {
      const currentSearch: PinmonySearchSnapshot = this.searchStore.search;
      // A tab switch may interrupt an in-flight API response. Cache the last
      // visible content as a read-only state instead of retaining its busy or
      // error flags, which are intentionally rejected by PinmonySearchCache.
      const retainedSearch: PinmonySearchSnapshot = {
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

  searchPlaceholder(pageKey: string = this.ports.currentPageKey()): PinmonySearchSnapshot {
    let query: string = '';
    const match: RegExpMatchArray | null = pageKey.match(/[?&]q=([^&#]*)/);
    try { query = match ? decodeURIComponent(match[1].replace(/\+/g, ' ')) : ''; } catch (_) {}
    return { kind: 'loading', session: 0, pageKey: pageKey, query: query,
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
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search) return 'false';
    return 'window.' + name + ' && window.' + name + '(' + search.session.toString() + ',' +
      JSON.stringify(search.pageKey) + (id ? ',' + JSON.stringify(id) : '') + ')';
  }

  async openSearchFilters(): Promise<void> {
    if (this.ports.nativeSearch?.()) {
      if (!this.searchStore.searchNativeReadsReady || !this.searchStore.search?.query.trim() || this.ports.sheetKind()) return;
      if (this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing(); this.searchStore.searchInputFocused = false;
      this.searchStore.searchFilterToken++; this.searchStore.searchFilterOptions = []; this.ports.setFilterVisible(true); await this.ports.nativeSearchFilters?.(); return;
    }
    this.ports.traceAction('search.filters');
    const generation: number = this.generation;
    if (!await this.ports.ensureContext(true) || generation !== this.generation) {
      PinmonyRuntimeLog.warn('SearchFilter: entry rejected reason=context-or-cancelled');
      return;
    }
    if (!this.searchStore.searchActionsReady) {
      PinmonyRuntimeLog.warn('SearchFilter: entry rejected reason=actions-not-ready');
      this.ports.showMessage(PinmonyI18n.message('搜索操作尚未就绪，请稍后重试'));
      return;
    }
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search || !search.query.trim() || search.pageKey !== this.ports.currentPageKey() || this.ports.sheetKind()) return;
    if (this.searchStore.searchInputFocused && this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false;
    this.searchStore.searchInputStopEditing = undefined;
    const token: number = ++this.searchStore.searchFilterToken;
    this.searchStore.searchFilterOptions = [];
    this.searchStore.searchFilterError = '';
    this.searchStore.searchFilterLoading = true;
    this.ports.setFilterVisible(true);
    PinmonyRuntimeLog.info('SearchFilter: panel opened');
    try {
      if (PIN_SEARCH_UI_API_ENABLED) {
        await this.ports.runScript('window.PinmonySearchUiApi && window.PinmonySearchUiApi.prepareFilters()');
        if (token !== this.searchStore.searchFilterToken) return;
      }
      const opened: string = await this.ports.runScript(this.searchFilterScript('PinmonySearchOpenFilters'));
      if (token !== this.searchStore.searchFilterToken) return;
      if (opened !== 'true' && opened !== '"true"') {
        this.searchStore.searchFilterLoading = false;
        this.searchStore.searchFilterError = PinmonyI18n.message('无法读取当前 Pinterest 页面的筛选入口');
        return;
      }
      await this.refreshSearchFilters(token);
    } catch (error) {
      if (token !== this.searchStore.searchFilterToken) return;
      this.searchStore.searchFilterLoading = false;
      this.searchStore.searchFilterError = PinmonyI18n.message('筛选器读取失败，请重试');
    }
  }

  async refreshSearchFilters(token: number = this.searchStore.searchFilterToken, attempt: number = 0): Promise<void> {
    if (token !== this.searchStore.searchFilterToken || this.ports.sheetKind() !== 'searchFilter') return;
    try {
      const raw: string = await this.ports.runScript('JSON.stringify(' +
        this.searchFilterScript('PinmonySearchReadFilters') + ')');
      if (token !== this.searchStore.searchFilterToken) return;
      let parsed: Object = JSON.parse(raw) as Object;
      if (typeof parsed === 'string') parsed = JSON.parse(parsed as string) as Object;
      const snapshot: PinmonySearchFilterSnapshot | undefined = !Array.isArray(parsed) && parsed ?
        parsed as PinmonySearchFilterSnapshot : undefined;
      if (PIN_SEARCH_UI_API_ENABLED && (!snapshot || !Array.isArray(snapshot.options) ||
          typeof snapshot.loading !== 'boolean' || typeof snapshot.error !== 'string')) {
        this.searchStore.searchFilterOptions = [];
        this.searchStore.searchFilterError = PinmonyI18n.message('筛选接口桥接响应无效，请重试');
        this.searchStore.searchFilterLoading = false;
        return;
      }
      if (snapshot && snapshot.loading) {
        if (attempt === 0) PinmonyRuntimeLog.info('SearchFilter: waiting status=' + (snapshot.status || 'loading'));
        if (attempt >= 60) {
          this.searchStore.searchFilterError = snapshot.status === 'session-sync' ? PinmonyI18n.message('搜索会话尚未同步，请重新打开筛选器') :
            PinmonyI18n.message('筛选接口尚未取得当前搜索数据，请重试');
          this.searchStore.searchFilterLoading = false;
          return;
        }
        await this.pause(250);
        await this.refreshSearchFilters(token, attempt + 1);
        return;
      }
      const options: PinmonySearchFilterOption[] = snapshot && Array.isArray(snapshot.options) ? snapshot.options :
        Array.isArray(parsed) ? parsed as PinmonySearchFilterOption[] : [];
      this.searchStore.searchFilterOptions = options.filter(
        (item: PinmonySearchFilterOption): boolean => !!item.id && !!item.label);
      PinmonyRuntimeLog.info('SearchFilter: options received count=' + this.searchStore.searchFilterOptions.length.toString());
      this.searchStore.searchFilterError = snapshot && snapshot.error ? snapshot.error :
        this.searchStore.searchFilterOptions.length ? '' : PIN_SEARCH_UI_API_ENABLED ?
          snapshot?.status === 'empty' ? PinmonyI18n.message('当前搜索没有可用的筛选选项') : PinmonyI18n.message('筛选接口返回空列表，请重试') : PinmonyI18n.message('当前网页没有可用的筛选选项');
    } catch (error) {
      if (token !== this.searchStore.searchFilterToken) return;
      this.searchStore.searchFilterError = PinmonyI18n.message('筛选选项读取失败，请重试');
    }
    this.searchStore.searchFilterLoading = false;
  }

  async retrySearchFilters(): Promise<void> {
    if (this.ports.nativeSearch?.()) { if(this.ports.sheetKind() === 'searchFilter' && !this.searchStore.searchFilterLoading) await this.ports.nativeSearchFilters?.(); return; }
    if (this.ports.sheetKind() !== 'searchFilter' || this.searchStore.searchFilterLoading) return;
    const token: number = ++this.searchStore.searchFilterToken;
    this.searchStore.searchFilterLoading = true;
    this.searchStore.searchFilterError = '';
    try {
      await this.ports.runScript('window.PinmonySearchUiApi && window.PinmonySearchUiApi.retryFilters()');
      const opened: string = await this.ports.runScript(this.searchFilterScript('PinmonySearchOpenFilters'));
      if (token !== this.searchStore.searchFilterToken) return;
      if (opened !== 'true' && opened !== '"true"') {
        this.searchStore.searchFilterError = PinmonyI18n.message('无法读取当前 Pinterest 页面的筛选入口');
        this.searchStore.searchFilterLoading = false;
        return;
      }
      await this.refreshSearchFilters(token);
    } catch (error) {
      if (token === this.searchStore.searchFilterToken) {
        this.searchStore.searchFilterLoading = false;
        this.searchStore.searchFilterError = PinmonyI18n.message('筛选器读取失败，请重试');
      }
    }
  }

  async selectSearchFilter(id: string): Promise<void> {
    if (this.ports.nativeSearch?.()) {
      if (this.ports.sheetKind() !== 'searchFilter' || this.searchStore.searchFilterLoading) return;
      const target: string = this.ports.nativeSearchFilterTarget?.(id) || '';
      if (target) {
        const source: string = this.ports.currentPageKey();
        if (this.ports.navigateFilterAfterClose) this.ports.navigateFilterAfterClose(target, source);
        else { this.dismissSearchFilters(); this.ports.navigateSearch(target, source); }
      }
      return;
    }
    this.ports.traceAction('search.filter', id);
    const token: number = this.searchStore.searchFilterToken;
    if (this.ports.sheetKind() !== 'searchFilter' || this.searchStore.searchFilterLoading ||
        !this.searchStore.searchFilterOptions.some((item: PinmonySearchFilterOption): boolean => item.id === id && item.enabled && !item.selected)) return;
    if (!await this.ports.ensureContext(true, 'searchFilter', (): boolean =>
        token === this.searchStore.searchFilterToken && this.ports.sheetKind() === 'searchFilter')) return;
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search) return;
    try {
      const raw: string = await this.ports.runScript('window.PinmonySearchUiApi && window.PinmonySearchUiApi.filterTarget(' +
        JSON.stringify(search.pageKey) + ',' + JSON.stringify(id) + ')');
      if (token !== this.searchStore.searchFilterToken || this.ports.sheetKind() !== 'searchFilter') return;
      let target: string = raw;
      if (raw.startsWith('"')) target = JSON.parse(raw) as string;
      if (!/^https:\/\/(?:www|uk)\.pinterest\.com\/search\/(?:pins|videos|boards|users|buyable_pins)\/\?q=/.test(target) ||
          target.split('/')[2] !== search.pageKey.split('/')[2]) return;
      this.dismissSearchFilters();
      this.searchStore.searchResultsResetPending = true;
      this.searchStore.searchScrollOffset = 0;
      this.ports.navigateSearch(target, '');
      PinmonyRuntimeLog.info('SearchFilterTrace: type-navigation');
    } catch (_) {
      if (token === this.searchStore.searchFilterToken) this.searchStore.searchFilterError = PinmonyI18n.message('筛选导航失败，请重试');
    }
  }

  dismissSearchFilters(): void {
    if (this.ports.sheetKind() !== 'searchFilter') return;
    const script: string = this.searchFilterScript('PinmonySearchCloseFilters');
    this.searchStore.searchFilterToken++;
    if (this.ports.nativeSearch?.()) this.ports.nativeSearchCancelFilters?.();
    this.ports.setFilterVisible(false);
    this.searchStore.searchFilterLoading = false;
    this.searchStore.searchFilterError = '';
    this.searchStore.searchFilterOptions = [];
    if (!this.ports.nativeSearch?.()) this.ports.runScript(script).catch(() => PinmonyRuntimeLog.warn('Pinmony: could not close web search filters'));
  }

  expectSearch(): void {
    if (this.ports.nativeSearch?.() && /[?&]q=/.test(this.ports.currentPageKey())) { this.ports.nativeSearchDemand?.(); return; }
    if (this.ports.nativeDiscovery?.()) { this.ports.nativeDiscoveryDemand?.(); return; }
    const pageKey: string = this.ports.currentPageKey();
    if (!pageKey) return;
    const token: number = ++this.searchStore.searchRequestToken;
    this.searchStore.searchLoading = true;
    this.searchStore.searchError = '';
    this.tasks.timeout(() => {
      if (token !== this.searchStore.searchRequestToken || !this.searchStore.searchLoading) return;
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = PinmonyI18n.message('无法读取当前 Pinterest 搜索内容');
    }, 8000);
  }

  updateSearch(value: string): void {
    if (this.ports.nativeSearch?.()) {
      this.ports.nativeDiscoveryApply?.(); this.ports.nativeSearchApply?.(); return;
    }
    try {
      const message: PinmonySearchSnapshot = JSON.parse(value) as PinmonySearchSnapshot;
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
      if (message.pageKey !== activePage) {
        PinmonyRuntimeLog.info('SearchSnapshot: rejected reason=page-mismatch kind=' + message.kind);
        return;
      }
      if (this.searchStore.searchQueryClearPage === activePage) {
        if ((message.query || '').trim()) {
          if (message.kind === 'state') {
            // Use the newly confirmed session when returning from a cache.
            this.ports.runScript('window.PinmonySearchQuery && window.PinmonySearchQuery(' +
              message.session.toString() + ',' + JSON.stringify(message.pageKey) + ',"")')
              .catch(() => PinmonyRuntimeLog.warn('Pinmony: search query dismissal unavailable'));
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
        this.searchStore.searchError = PinmonyI18n.message('无法识别当前 Pinterest 搜索内容');
        this.searchStore.searchReturnPageKey = '';
        this.ports.setDetailReturn('');
        return;
      }
      if (!message.api && message.kind === 'loading' && this.searchStore.searchError) return;
      if ((message.kind !== 'state' && message.kind !== 'loading') ||
          !Array.isArray(message.categories) || !Array.isArray(message.suggestions) ||
          !Array.isArray(message.results)) return;
      const categories: PinmonySearchCategory[] = message.categories.filter((item: PinmonySearchCategory): boolean =>
        !!item.id && !!item.label);
      const suggestions: PinmonySearchSuggestion[] = message.suggestions.filter((item: PinmonySearchSuggestion): boolean =>
        !!item.id && !!item.label);
      let heroes: PinmonySearchHero[] = Array.isArray(message.heroes) ?
        message.heroes.filter((item: PinmonySearchHero): boolean => !!item.id && !!item.title &&
          /^https:\/\//i.test(item.imageUrl)) : [];
      let ideaSections: PinmonySearchIdeaSection[] = Array.isArray(message.ideaSections) ?
        message.ideaSections.filter((section: PinmonySearchIdeaSection): boolean => !!section.id && !!section.title &&
          Array.isArray(section.items)).map((section: PinmonySearchIdeaSection): PinmonySearchIdeaSection => {
            return {
              id: section.id,
              eyebrow: section.eyebrow || '',
              title: section.title,
              actionId: section.actionId || '',
              targetUrl: section.targetUrl,
              items: section.items.filter((item) => !!item.id && !!item.title && /^https:\/\//i.test(item.imageUrl))
            };
          }) : [];
      let results: PinmonySearchResult[] = message.results.filter((item: PinmonySearchResult): boolean =>
        !!item.id && (item.kind === 'pin' || !!item.title) && /^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(item.targetUrl) &&
          (!item.imageUrl || /^https:\/\//i.test(item.imageUrl)));
      results = results.map((item: PinmonySearchResult): PinmonySearchResult => {
        const title: string | undefined = this.searchStore.knownSearchPinTitles.get(this.ports.pinIdentity(item.targetUrl));
        if (item.kind !== 'pin' || !title) return item;
        return { id: item.id, kind: item.kind, title: title, subtitle: item.subtitle,
          targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
          imageHeight: item.imageHeight, video: item.video, enabled: item.enabled };
      });
      const previousSearch: PinmonySearchSnapshot | undefined = this.searchStore.search;
      if (!message.api && retainedContext && this.searchStore.retainedSearch && message.kind === 'state') {
        if ((message.query || '') !== this.searchStore.retainedSearch.query) return;
        if (this.searchStore.retainedSearch.query && !results.length) return;
      }
      if (previousSearch) {
        results = results.map((item: PinmonySearchResult): PinmonySearchResult => {
          if (item.kind !== 'pin' || this.hasMeaningfulSearchPinTitle(item.title)) return item;
          const previousItem: PinmonySearchResult | undefined = previousSearch.results.find(
            (candidate: PinmonySearchResult): boolean => candidate.kind === 'pin' &&
              this.ports.pinIdentity(candidate.targetUrl) === this.ports.pinIdentity(item.targetUrl));
          if (!previousItem || !this.hasMeaningfulSearchPinTitle(previousItem.title)) return item;
          return { id: item.id, kind: item.kind, title: previousItem.title, subtitle: item.subtitle,
            targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
            imageHeight: item.imageHeight, video: item.video, enabled: item.enabled };
        });
      }
      const retainingApiResults: boolean = message.api === true && !!previousSearch &&
        previousSearch.pageKey === message.pageKey && previousSearch.query === (message.query || '') &&
        (message.kind === 'loading' || message.apiBusy === true || !!message.apiError);
      const sameSearchContext: boolean =
        (results.length > 0 || retainingApiResults) && !!previousSearch &&
        previousSearch.pageKey === message.pageKey && previousSearch.query === (message.query || '') &&
        (!message.selectedCategory || !previousSearch.selectedCategory ||
          previousSearch.selectedCategory === message.selectedCategory);
      results = mergeSearchFeedResults(sameSearchContext && previousSearch ? previousSearch.results : [], results);
      const preservedSearchResults: boolean = sameSearchContext && results.length > 0;
      const sameDiscoverySession: boolean = !message.query && !!previousSearch &&
        (heroes.length > 0 || ideaSections.length > 0 || message.discoveryBusy === true ||
          !!message.discoveryError || message.discoveryActive !== true) &&
        previousSearch.pageKey === message.pageKey &&
        !previousSearch.query;
      if (sameDiscoverySession && previousSearch) {
        heroes = previousSearch.heroes.map((hero: PinmonySearchHero): PinmonySearchHero =>
          heroes.find((incoming: PinmonySearchHero): boolean => incoming.targetUrl === hero.targetUrl) || hero)
          .concat(heroes.filter((hero: PinmonySearchHero): boolean =>
            !previousSearch.heroes.some((previous: PinmonySearchHero): boolean => previous.targetUrl === hero.targetUrl)));
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
      const nextSearch: PinmonySearchSnapshot = { kind: stableKind, session: message.session, pageKey: message.pageKey,
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
      // Preserve object identity for an identical validated snapshot, including readiness fields.
      if (!this.searchStore.search || JSON.stringify(this.searchStore.search) !== JSON.stringify(nextSearch))
        this.searchStore.search = nextSearch;
      this.searchStore.searchActionsReady = message.kind === 'state' && !retainingApiResults;
      PinmonyRuntimeLog.info('SearchSnapshot: accepted kind=' + message.kind + ' results=' + results.length.toString() +
        ' sections=' + ideaSections.length.toString() + ' actionsReady=' + this.searchStore.searchActionsReady.toString());
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
      PinmonyRuntimeLog.warn('Pinmony: invalid search state');
    } finally { this.ports.nativeDiscoveryApply?.(); this.ports.nativeSearchApply?.(); }
  }

  async updateSearchQuery(value: string, refreshSuggestions: boolean = false): Promise<void> {
    if (this.ports.nativeSearch?.()) { this.ports.markInteracted(); await this.ports.nativeSearchInput?.(value,refreshSuggestions); return; }
    if (refreshSuggestions) PinmonyRuntimeLog.info("SearchInputTrace: panel-open refresh=true");
    if (value.trim()) this.searchStore.searchQueryClearPage = '';
    const intent: number = ++this.searchStore.searchIntentToken;
    if (!(this.ports.nativeSearch?.() || await this.ports.ensureContext(false)) || intent !== this.searchStore.searchIntentToken) return;
    const token: number = ++this.searchStore.searchQueryToken;
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search || !(this.searchStore.searchNativeInputReady || this.searchStore.searchInputReady || this.searchStore.searchActionsReady) || search.pageKey !== this.ports.currentPageKey()) return;
    this.ports.markInteracted();
    try {
      const result: string = await this.ports.runScript('window.PinmonySearchQuery && ' +
        'window.PinmonySearchQuery(' + search.session.toString() + ',' + JSON.stringify(search.pageKey) + ',' +
        JSON.stringify(value) + ',' + (refreshSuggestions ? 'true' : 'false') + ')');
      if (token === this.searchStore.searchQueryToken && result !== 'true' && result !== '"true"') {
        this.searchStore.searchRequestToken++;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = PinmonyI18n.message('搜索输入暂不可用，请重试');
      }
    } catch (error) {
      if (token === this.searchStore.searchQueryToken) {
        this.searchStore.searchRequestToken++;
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = PinmonyI18n.message('搜索输入暂不可用，请重试');
      }
    }
  }

  async submitSearch(value: string): Promise<void> {
    if (typeof value !== 'string' || !value.trim() || value.length > 300) return;
    this.searchStore.searchQueryClearPage = '';
    const intent: number = ++this.searchStore.searchIntentToken;
    this.searchStore.searchQueryToken++;
    if (!(this.ports.nativeSearch?.() || await this.ports.ensureContext(false)) || intent !== this.searchStore.searchIntentToken) return;
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search || !(this.searchStore.searchNativeInputReady || this.searchStore.searchInputReady || this.searchStore.searchActionsReady) || search.pageKey !== this.ports.currentPageKey()) return;
    if (this.searchStore.searchInputStopEditing) this.searchStore.searchInputStopEditing();
    this.searchStore.searchInputFocused = false; this.searchStore.searchInputStopEditing = undefined;
    this.ports.clearTabGuard('search-submit');
    this.searchStore.searchCache.put(search,this.searchStore.searchScrollOffset);
    this.searchStore.retainedSearch = undefined;
    this.searchStore.searchResultsResetPending = true;
    this.searchStore.searchScrollOffset = 0;
    this.searchStore.searchRequestToken++;
    const origin: RegExpMatchArray | null = search.pageKey.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/)/);
    if (!origin) return;
    const target: string = origin[0] + '/search/pins/?q=' + encodeURIComponent(value.trim());
    try {
      this.ports.navigateSearch(target, search.pageKey);
      PinmonyRuntimeLog.info('SearchNavigationTrace: submit-native');
    } catch (_) {
      this.ports.cancelNavigation(false);
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = PinmonyI18n.message('无法提交搜索，请重试');
      this.searchStore.searchResultsResetPending = false;
    }
  }

  async performSearchAction(id: string, kind: string): Promise<void> {
    if (kind === 'result') this.ports.traceAction('search.pin.open');
    this.ports.traceAction('search.action.' + kind, id);
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search || !id || !this.ports.isActive()) return;
    if (kind === 'clearProductFilter') {
      if (this.ports.nativeSearch?.() && search.results.length === 0 && !this.searchStore.searchLoading && !this.searchStore.searchError) this.ports.nativeSearchClearProductFilter?.(id);
      return;
    }
    if (kind === 'followUser') {
      if (this.ports.nativeSearch?.()) await this.ports.nativeSearchFollowUser?.(id);
      return;
    }
    if (kind === 'followBoard') {
      if (this.ports.nativeSearch?.()) await this.ports.nativeSearchFollowBoard?.(id);
      return;
    }
    if (kind === 'deleteHistory') {
      if(this.ports.nativeSearch?.()){await this.ports.nativeSearchDeleteHistory?.(id);return;}
      const generation: number = this.generation;
      if (!this.searchStore.searchInputReady && !this.searchStore.searchActionsReady) return;
      const item: PinmonySearchSuggestion | undefined = search.suggestions.find((value: PinmonySearchSuggestion): boolean => value.id === id && value.deletable === true && value.deleting !== true);
      if (!item || search.query.trim()) return;
      try {
        await this.ports.runScript('window.PinmonySearchDeleteHistory && window.PinmonySearchDeleteHistory(' + search.session + ',' + JSON.stringify(search.pageKey) + ',' + JSON.stringify(id) + ')');
      } catch (_) {
        if (generation === this.generation && search.pageKey === this.ports.currentPageKey())
          this.searchStore.searchError = PinmonyI18n.message('删除搜索历史未能确认成功，请刷新历史后检查');
      }
      return;
    }
    if (kind === 'suggestion') {
      const suggestion: PinmonySearchSuggestion | undefined = search.suggestions.find((item: PinmonySearchSuggestion): boolean => item.id === id && item.enabled);
      if (suggestion) await this.submitSearch(suggestion.query || suggestion.label);
      return;
    }
    if (kind !== 'result' && !(kind === 'category' && search.api) &&
        !(search.discoveryApi && (kind === 'idea' || kind === 'ideaSection'))) return;
    this.ports.clearTabGuard('search-action');
    if (kind === 'category' && search.api) {
      const guide: PinmonySearchCategory | undefined = search.categories.find((item: PinmonySearchCategory): boolean =>
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
        this.ports.showMessage(PinmonyI18n.message('无法打开此搜索分类，请重试'));
      }
      return;
    }
    if (kind !== 'result' && !(search.discoveryApi && (kind === 'idea' || kind === 'ideaSection'))) return;
    const token: number = ++this.searchStore.searchRequestToken;
    const navigationAction: boolean = kind === 'result' || kind === 'idea' || kind === 'ideaSection';
    const resultItem: PinmonySearchResult | undefined = kind === 'result' ?
      findSearchResult(search.results, id) : undefined;
    if (kind === 'result') {
      const targetUrl: string = resultItem ? resultItem.targetUrl : id;
      if (!/^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(targetUrl)) {
        this.ports.showMessage(PinmonyI18n.message('这张帖子的链接暂不可用，请重新读取搜索结果'));
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
        this.ports.showMessage(PinmonyI18n.message('无法打开此 Pinterest 内容，请重试'));
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
            const card: PinmonySearchIdea | undefined = section.items.find((item: PinmonySearchIdea): boolean =>
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
        this.ports.showMessage(PinmonyI18n.message('这个主题的链接已失效，请重新读取'));
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
        this.ports.showMessage(PinmonyI18n.message('无法打开此 Pinterest 内容，请重试'));
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
      const result: string = await this.ports.runScript('window.PinmonySearchAction && ' +
        'window.PinmonySearchAction(' + search.session.toString() + ',' + JSON.stringify(search.pageKey) + ',' +
        JSON.stringify(id) + ',' + JSON.stringify(kind) + ')');
      if (result === 'true' || result === '"true"') {
        if (navigationAction) {
          return;
        }
        this.tasks.timeout(() => {
          if (token !== this.searchStore.searchRequestToken || !this.searchStore.searchLoading) return;
          this.searchStore.searchLoading = false;
          this.searchStore.searchError = PinmonyI18n.message('搜索分类尚未更新，请重试');
        }, 5000);
        return;
      }
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: search action unavailable');
    }
    if (token !== this.searchStore.searchRequestToken) return;
    this.searchStore.searchLoading = false;
    this.searchStore.searchResultsResetPending = false;
    if (navigationAction) this.ports.showMessage(PinmonyI18n.message('无法打开此 Pinterest 内容，请重试'));
    else this.searchStore.searchError = PinmonyI18n.message('当前搜索选项暂不可用，请重试');
  }

  loadMoreSearch(): void {
    if (this.ports.nativeSearch?.() && /[?&]q=/.test(this.ports.currentPageKey())) { this.ports.nativeSearchMore?.(); return; }
    if (this.ports.nativeDiscovery?.() && !this.searchStore.search?.query) { this.ports.nativeDiscoveryMore?.(); return; }
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!search || !this.searchStore.searchActionsReady || this.searchStore.searchLoading || search.pageKey !== this.ports.currentPageKey()) return;
    this.ports.runScript('window.PinmonySearchLoadMore && ' +
      'window.PinmonySearchLoadMore(' + search.session.toString() + ',' + JSON.stringify(search.pageKey) + ')')
      .catch(() => PinmonyRuntimeLog.warn('Pinmony: search loading unavailable'));
  }

  async refreshSearch(): Promise<void> {
    if (this.ports.nativeSearch?.() && /[?&]q=/.test(this.ports.currentPageKey())) { await this.ports.nativeSearchRefresh?.(); this.ports.finishPull(); return; }
    if (this.ports.nativeDiscovery?.()) { await this.ports.nativeDiscoveryRefresh?.(); this.ports.finishPull(); return; }
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
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    try {
      const result: string = await this.ports.runScript('window.PinmonySearchRefresh && ' +
        'window.PinmonySearchRefresh(' + (search ? search.session.toString() : 'undefined') + ',' +
        (search ? JSON.stringify(search.pageKey) : 'undefined') + ')');
      if (generation !== this.generation || token !== this.searchStore.searchRequestToken || pageKey !== this.ports.currentPageKey()) return;
      if (result === 'false' || result === '"false"') {
        this.searchStore.searchLoading = false;
        this.searchStore.searchError = PinmonyI18n.message('无法重新读取搜索内容');
        this.searchStore.searchResultsResetPending = false;
      }
    } catch (error) {
      if (generation !== this.generation || token !== this.searchStore.searchRequestToken || pageKey !== this.ports.currentPageKey()) return;
      this.searchStore.searchLoading = false;
      this.searchStore.searchError = PinmonyI18n.message('无法重新读取搜索内容');
      this.searchStore.searchResultsResetPending = false;
    }
  }

  async performSearchQuizAction(kind: string, id: string): Promise<void> {
    const generation: number = this.generation;
    if (!await this.ports.ensureContext(true) || generation !== this.generation) return;
    const current: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!current || current.pageKey !== this.ports.currentPageKey()) return;
    try {
      const result: string = await this.ports.runScript('window.PinmonySearchQuizAction && window.PinmonySearchQuizAction(' +
        current.session.toString() + ',' + JSON.stringify(current.pageKey) + ',' +
        JSON.stringify(kind) + ',' + JSON.stringify(id) + ')');
      if (generation !== this.generation || current.pageKey !== this.ports.currentPageKey()) return;
      if (result !== 'true' && result !== '"true"') this.ports.showMessage(PinmonyI18n.message('灵感推荐操作尚未就绪，请重试'));
    } catch (_) {
      if (generation === this.generation && current.pageKey === this.ports.currentPageKey()) this.ports.showMessage(PinmonyI18n.message('无法操作灵感推荐，请重试'));
    }
  }
}
