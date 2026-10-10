// Verified ghost text and filter-list endpoints, within the current website session.
export const PIN_SEARCH_UI_API_ENABLED: boolean = true;
export const PIN_SEARCH_UI_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/i.test(location.hostname)) return;
  if (window.PinmonySearchUiApiEnabled !== true) return;
  var page = '', generation = 0, hintAbort = null, filterAbort = null;
  var hintAttempted = false, hint = '', cursor = '', filterAttempted = false;
  var filterBusy = false, filterError = '', filters = [], changed = function () {};
  var captureVersion = 0;
  var searchVersion = 0, lastSearch = null;
  var filterEpoch = 0, websiteFilters = null, filterReplay = null;
  var deleteAbort = null;
  var suggestionTerm = null, suggestionEdited = false, suggestionItems = [], suggestionError = '', suggestionAbort = null, suggestionTimer = 0, suggestionVersion = 0;
  function currentPage() { return location.origin + location.pathname + location.search; }
  function reset() {
    generation++; captureVersion++; suggestionVersion++;
    if (deleteAbort) deleteAbort.abort(); deleteAbort = null;
    if (suggestionAbort) suggestionAbort.abort();
    if (suggestionTimer) clearTimeout(suggestionTimer);
    suggestionTimer = 0; suggestionAbort = null; suggestionTerm = null; suggestionItems = []; suggestionError = '';
    if (hintAbort) hintAbort.abort();
    if (filterAbort) filterAbort.abort();
    page = ''; hintAbort = null; filterAbort = null; hintAttempted = false; hint = '';
    cursor = ''; filterAttempted = false; filterBusy = false; filterError = ''; filters = [];
    lastSearch = null;
    filterEpoch++; websiteFilters = null; filterReplay = null;
  }
  function context(requestedPage) {
    if (page !== requestedPage) { reset(); page = requestedPage; }
  }
  function invalidateFilters() {
    captureVersion++;
    if (filterAbort) filterAbort.abort();
    filterAbort = null; filterAttempted = false; filterBusy = false; filterError = ''; filters = [];
  }
  function requestInfo(url, body) {
    try {
      var endpoint = new URL(typeof url === 'string' ? url : url.url, location.href);
      if (endpoint.origin !== location.origin ||
          (endpoint.pathname !== '/resource/BaseSearchResource/get/' && endpoint.pathname !== '/resource/ApiResource/get/')) return null;
      var fields = body ? new URLSearchParams(body) : endpoint.searchParams;
      var data = JSON.parse(fields.get('data') || '{}'), options = data.options || {};
      var key = currentPage();
      var source = fields.get('source_url');
      if (!/^\\/search\\//i.test(location.pathname)) return null;
      if (source) {
        var sourceUrl = new URL(source, location.origin), currentUrl = new URL(key);
        if (sourceUrl.pathname !== currentUrl.pathname || sourceUrl.searchParams.get('q') !== currentUrl.searchParams.get('q')) return null;
      }
      if (endpoint.pathname === '/resource/ApiResource/get/') {
        if (options.url !== '/v3/filters/' || !options.data || typeof options.data.bookmark_string !== 'string') return null;
        context(key);
        return { kind: 'filters', page: key, epoch: filterEpoch, options: options };
      }
      if (options.query !== (new URL(key).searchParams.get('q') || '')) return null;
      return { page: key, version: captureVersion, options: options };
    } catch (_) { return null; }
  }
  function capture(info, payload) {
    if (!info || info.page !== currentPage()) return;
    var resource = payload && payload.resource_response;
    if (info.kind === 'filters') {
      if (info.epoch !== filterEpoch || !resource || resource.status !== 'success' || !Array.isArray(resource.data)) return;
      try {
        var mapped = mapFilters(resource.data, generation, 'website-' + (++searchVersion));
        invalidateFilters();
        filterReplay = JSON.parse(JSON.stringify(info.options.data));
        websiteFilters = mapped; filters = mapped; filterAttempted = true;
        changed();
      } catch (_) {}
      return;
    }
    if (info.version !== captureVersion) return;
    if (!resource || resource.status !== 'success' || !resource.data || !Array.isArray(resource.data.results)) return;
    context(info.page);
    if (!Array.isArray(info.options.bookmarks) || !info.options.bookmarks.length) {
      lastSearch = { page: info.page, version: ++searchVersion, options: info.options, resource: resource };
    }
    if (typeof resource.bookmark === 'string' && resource.bookmark && resource.bookmark !== '-end-' && cursor !== resource.bookmark) {
      invalidateFilters(); cursor = resource.bookmark; changed();
    }
    changed();
  }
  // Observe only search and filter resource JSON; never derive filter labels from visible DOM.
  if (typeof window.fetch === 'function') {
    var originalFetch = window.fetch;
    window.fetch = function (url, init) {
      // The private init field is ignored by fetch; it prevents adopting our own pagination as a fresh website search.
      var privateRequest = init && (init.pinWebSearchRequest || init.pinWebSearchUiRequest || init.pinWebSearchQuizRequest);
      var info = privateRequest ? null : requestInfo(url, init && init.body), pending = null;
      if (!privateRequest && !info && url && typeof url.clone === 'function' && (!init || !init.body)) {
        try { pending = url.clone().text().then(function (body) { return requestInfo(url, body); }).catch(function () { return null; }); } catch (_) {}
      }
      return originalFetch.apply(this, arguments).then(function (response) {
        try {
          if (response.ok && (info || pending)) {
            var data = response.clone().json();
            Promise.all([pending || Promise.resolve(info), data]).then(function (values) { capture(values[0], values[1]); }).catch(function () {});
          }
        } catch (_) {}
        return response;
      });
    };
  }
  if (typeof XMLHttpRequest === 'function') {
    var originalOpen = XMLHttpRequest.prototype.open, originalSend = XMLHttpRequest.prototype.send;
    var urls = new WeakMap();
    XMLHttpRequest.prototype.open = function (method, url) {
      urls.set(this, url); return originalOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function (body) {
      var info = requestInfo(urls.get(this), body), xhr = this;
      if (info) this.addEventListener('load', function () {
        try { if (xhr.status === 200) capture(info, xhr.responseType === 'json' ? xhr.response : JSON.parse(xhr.responseText)); } catch (_) {}
      }, { once: true });
      return originalSend.apply(this, arguments);
    };
  }
  async function request(endpoint, data, controller, post) {
    var route = new URL(page);
    var direct = endpoint === '/resource/AdvancedTypeaheadResource/get/';
    var options = direct ? data : { url: endpoint, data: data };
    var fields = new URLSearchParams();
    fields.set('source_url', route.pathname + route.search);
    fields.set('data', JSON.stringify({ options: options, context: {} }));
    var headers = { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
      'X-Pinterest-Pws-Handler': 'www/index.js' };
    var init = { credentials: 'same-origin', signal: controller.signal, headers: headers, pinWebSearchUiRequest: true };
    var url = direct ? endpoint : '/resource/ApiResource/get/';
    if (post) {
      init.method = 'POST'; init.body = fields.toString();
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      var csrf = document.cookie.split(';').map(function (part) { return part.trim(); })
        .filter(function (part) { return part.indexOf('csrftoken=') === 0; })[0];
      if (csrf) headers['X-CSRFToken'] = decodeURIComponent(csrf.slice(10));
    } else url += '?' + fields.toString() + '&_=' + Date.now();
    var timer = setTimeout(function () { controller.abort(); }, 10000);
    try {
      var response = await fetch(url, init);
      if (!response.ok) throw new Error('http-error');
      var payload = await response.json(), resource = payload.resource_response;
      if (!resource || resource.status !== 'success') throw new Error('invalid-response');
      var values = direct ? resource.data && resource.data.items : resource.data;
      if (!Array.isArray(values)) throw new Error('invalid-response');
      return values;
    } finally { clearTimeout(timer); }
  }
  function loadHint() {
    hintAttempted = true;
    var token = generation, requested = page, controller = new AbortController(); hintAbort = controller;
    request('/v3/search/ghost_queries/', {}, controller, false).then(function (data) {
      if (token !== generation || requested !== currentPage()) return;
      var item = data.filter(function (item) { return item && typeof item.text === 'string' && item.text.trim(); })[0];
      hint = item ? item.text.trim().slice(0, 180) : ''; changed();
    }).catch(function () {}).finally(function () { if (token === generation) hintAbort = null; });
  }
  function filterScope(option) {
    var scopes = ['pins', 'videos', 'boards', 'users', 'buyable_pins'];
    var labels = { '所有 Pin 图': 'pins', '所有创意': 'pins', 'All Pins': 'pins', '视频': 'videos', 'Videos': 'videos',
      '画板': 'boards', '图板': 'boards', 'Boards': 'boards', '个人资料': 'users', '用户': 'users', 'Profiles': 'users',
      '商品': 'buyable_pins', '产品': 'buyable_pins', 'Products': 'buyable_pins' };
    return scopes.indexOf(option.sourceId) >= 0 ? option.sourceId : labels[option.label] || '';
  }
  function mapFilters(data, token, version) {
    var mapped = [];
    data.forEach(function (filter) {
      if (!filter || filter.type !== 'filter' || !Array.isArray(filter.filter_options)) return;
      filter.filter_options.forEach(function (option) {
        if (!option || option.type !== 'filteroption' || typeof option.label !== 'string' || !option.label.trim()) return;
        mapped.push({ id: 'api-filter-' + token + '-' + version + '-' + mapped.length,
          label: option.label.trim().slice(0, 70), group: typeof filter.title === 'string' ? filter.title.slice(0, 70) : '',
          selected: option.is_selected === true, enabled: option.disabled !== true && option.is_disabled !== true,
          sourceId: String(option.id || '') });
      });
    });
    if (data.length && !mapped.length) throw new Error('invalid-filters');
    mapped.forEach(function (option) { option.enabled = option.enabled && !!filterScope(option); });
    return mapped;
  }
  function loadFilters() {
    var token = generation, version = captureVersion, requested = page, controller = new AbortController();
    filterAbort = controller; filterAttempted = true; filterBusy = true; filterError = '';
    request('/v3/filters/', filterReplay || { bookmark_string: cursor }, controller, true).then(function (data) {
      if (token !== generation || version !== captureVersion || requested !== currentPage()) return;
      filters = mapFilters(data, token, version);
    }).catch(function () {
      if (token === generation && version === captureVersion && requested === currentPage()) filterError = '筛选选项接口读取失败，请重试';
    }).finally(function () {
      if (token === generation && version === captureVersion) { filterBusy = false; filterAbort = null; changed(); }
    });
  }
  function loadSuggestions(term, edited, version) {
    suggestionTimer = 0;
    var token = generation, requested = page, controller = new AbortController(); suggestionAbort = controller;
    var options = { field_set_key: 'richResults', limit: 8, num_recent_queries: 20,
      personal_search_only: false, pin_scope: 'pins', recent_queries_tags: 'recent_queries,recent_personal_searches',
      term: term, autocomplete_request_surface: 0 };
    request('/resource/AdvancedTypeaheadResource/get/', options, controller, false).then(function (items) {
      if (token !== generation || version !== suggestionVersion || requested !== currentPage() || term !== suggestionTerm) return;
      var seen = {};
      suggestionItems = items.slice(0, 40).map(function (item, index) {
        var label = item && (item.display_query || item.query || item.label);
        if (typeof label !== 'string' || !label.trim() || label.length > 300 || seen[label]) return null;
        seen[label] = true;
        var rawQuery = typeof item.query === 'string' && item.query.length > 0 && item.query.length <= 300 ? item.query : '';
        return { id: 'api-suggestion-' + version + '-' + index, label: label.trim(), enabled: true,
          query: rawQuery, historyType: item.type || '',
          deletable: term === '' && item.type === 'recent_query' && item.vertical === 'pins' && !!rawQuery, deleting: false };
      }).filter(Boolean);
      suggestionError = ''; changed();
    }).catch(function () {
      if (token === generation && version === suggestionVersion && requested === currentPage()) {
        suggestionError = '搜索建议读取失败，请重试'; changed();
      }
    }).finally(function () { if (suggestionAbort === controller) { suggestionAbort = null; changed(); } });
  }
  async function deleteHistory(requestedPage, id) {
    if (window.PinmonySearchUiApiEnabled !== true || requestedPage !== page || requestedPage !== currentPage() || suggestionTerm !== '' || deleteAbort) return false;
    var item = suggestionItems.find(function (value) { return value.id === id && value.deletable && !value.deleting; });
    if (!item) return false;
    var token = generation, version = suggestionVersion, controller = new AbortController(); deleteAbort = controller;
    item.deleting = true; suggestionError = ''; changed();
    var route = new URL(page), fields = new URLSearchParams();
    fields.set('source_url', route.pathname + route.search);
    fields.set('data', JSON.stringify({ options: { url: '/v3/search/recent/', data: { query: item.query, vertical: 'PIN' } }, context: {} }));
    var timer = setTimeout(function () { controller.abort(); }, 10000);
    try {
      var response = await fetch('/resource/ApiResource/delete/', { method: 'POST', credentials: 'same-origin', signal: controller.signal,
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' },
        body: fields.toString(), pinWebSearchUiRequest: true });
      if (!response.ok) throw new Error('http-error');
      var payload = await response.json(), resource = payload && payload.resource_response;
      if (!resource || resource.status !== 'success' || resource.code !== 0 || resource.endpoint_name !== 'v3_recent_search_delete') throw new Error('invalid-response');
      if (token !== generation || version !== suggestionVersion || requestedPage !== currentPage() || suggestionTerm !== '') return false;
      suggestionItems = suggestionItems.filter(function (value) { return value.id !== id; });
      suggestionVersion++; changed(); loadSuggestions('', suggestionEdited, suggestionVersion);
      return true;
    } catch (_) {
      if (token === generation && version === suggestionVersion && requestedPage === currentPage()) {
        item.deleting = false; suggestionError = '删除搜索历史未能确认成功，请刷新历史后检查'; changed();
      }
      return false;
    } finally { clearTimeout(timer); if (deleteAbort === controller) deleteAbort = null; }
  }
  window.PinmonySearchUiApi = {
    deleteHistory: deleteHistory,
    refreshSuggestions: function () {
      suggestionVersion++; if (suggestionAbort) suggestionAbort.abort(); if (suggestionTimer) clearTimeout(suggestionTimer);
      suggestionAbort = null; suggestionTimer = 0; suggestionTerm = null; suggestionItems = []; suggestionError = '';
    },
    readSuggestions: function (requestedPage, term, edited, callback) {
      if (requestedPage !== currentPage() || typeof term !== 'string' || term.length > 300) return null;
      context(requestedPage); changed = callback;
      if (!edited && new URL(requestedPage).searchParams.get('q')) return { items: [], error: '' };
      if (term !== suggestionTerm || edited !== suggestionEdited) {
        suggestionVersion++; if (suggestionAbort) suggestionAbort.abort(); if (suggestionTimer) clearTimeout(suggestionTimer);
        suggestionTerm = term; suggestionEdited = edited; suggestionItems = []; suggestionError = '';
        var version = suggestionVersion; suggestionTimer = setTimeout(function () { loadSuggestions(term, edited, version); }, 250);
      }
      return { items: suggestionItems, error: suggestionError, busy: !!suggestionTimer || !!suggestionAbort };
    },
    filterTarget: function (requestedPage, id) {
      if (requestedPage !== page || requestedPage !== currentPage() || filterBusy || filterError) return '';
      var option = filters.find(function (value) { return value.id === id && value.enabled; });
      if (!option) return '';
      var scope = filterScope(option), route = new URL(page), query = route.searchParams.get('q');
      if (!scope || !query || option.selected) return '';
      return route.origin + '/search/' + scope + '/?q=' + encodeURIComponent(query) + '&rs=content_type_filter';
    },
    filterOption: function (requestedPage, id) {
      if (window.PinmonySearchUiApiEnabled !== true || requestedPage !== page || requestedPage !== currentPage() ||
          filterBusy || filterError) return null;
      return filters.filter(function (option) { return option.id === id; })[0] || null;
    },
    readSearch: function (requestedPage) { return lastSearch && lastSearch.page === requestedPage ? lastSearch : null; },
    reset: reset,
    readHint: function (requestedPage, onChange) {
      if (window.PinmonySearchUiApiEnabled !== true) return null;
      context(requestedPage); changed = onChange;
      if (!hintAttempted && typeof fetch === 'function' && typeof AbortController === 'function') loadHint();
      return hint;
    },
    prepareFilters: function () { if (websiteFilters === null) invalidateFilters(); },
    retryFilters: function () { invalidateFilters(); websiteFilters = null; },
    selectedFilter: function () {
      invalidateFilters(); filterEpoch++; cursor = ''; lastSearch = null; websiteFilters = null; filterReplay = null;
    },
    readFilters: function (requestedPage) {
      if (window.PinmonySearchUiApiEnabled !== true) return null;
      if (requestedPage !== currentPage()) return { options: [], loading: false,
        error: '搜索页面已变化，请重新打开筛选器', status: 'error' };
      context(requestedPage);
      if (websiteFilters !== null) {
        filters = websiteFilters; filterAttempted = true;
      }
      if (websiteFilters === null && !filterReplay && window.PinmonySearchApi && window.PinmonySearchApi.context) {
        var resultContext = window.PinmonySearchApi.context();
        if (resultContext.page === page && resultContext.bookmark && resultContext.bookmark !== '-end-' &&
            cursor !== resultContext.bookmark) {
          invalidateFilters(); cursor = resultContext.bookmark;
        }
      }
      if (websiteFilters === null && !filterReplay && !cursor) return { options: [], loading: true, error: '', status: 'waiting-search' };
      if (!filterAttempted) loadFilters();
      return { loading: filterBusy, error: filterError,
        status: filterBusy ? 'loading' : filterError ? 'error' : filters.length ? 'ready' : 'empty',
        options: filters.map(function (option) {
        return { id: option.id, label: option.label, group: option.group,
          selected: option.selected, enabled: option.enabled };
      }) };
    }
  };
})();`;
