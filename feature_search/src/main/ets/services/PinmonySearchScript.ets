export const PIN_SEARCH_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/i.test(location.hostname)) return;
  var documentActive = true, bridgeWarning = false;
  if (window.addEventListener) {
    window.addEventListener('pagehide', function () { documentActive = false; });
    window.addEventListener('pageshow', function () { documentActive = true; bridgeWarning = false; lastState = ''; schedule(); });
  }
  var session = 0, pageKey = '', query = '', edited = false, lastState = '', scheduled = 0, lastLoadAt = 0;
  var categories = [], suggestions = [], heroes = [], sections = [], results = [];
  function searchRoute() { return /^\\/search(?:\\/|$)/i.test(location.pathname); }
  function currentPageKey() { return location.origin + location.pathname + location.search; }
  window.PinmonySearchDemand = function (page) {
    if (!documentActive || page !== location.href) return false;
    clearTimeout(scheduled); scheduled = 0; sync(); return true;
  };
  function notify(value) {
    if (!documentActive) return;
    var serialized = JSON.stringify(value);
    if (serialized === lastState) return;
    try {
      var bridge = window.PinmonyShareBridge;
      if (!bridge || !bridge.searchState) return;
      bridge.searchState(serialized); lastState = serialized;
    } catch (_) { if (!bridgeWarning) { bridgeWarning = true; console.warn('BridgeTrace: search unavailable'); } }
  }
  function empty(kind) { return { kind: kind, session: session, pageKey: pageKey, query: query, placeholder: '',
    selectedCategory: '', categories: [], suggestions: [], heroes: [], ideaSections: [], results: [] }; }
  function sync() {
    scheduled = 0;
    if (!documentActive) return;
    if (window.PinmonyNativeNetworkEnabled === true && window.PinmonyNetwork && typeof window.PinmonyNetwork.isReady === "function" && !window.PinmonyNetwork.isReady()) return;
    scheduled = 0;
    if (window.PinmonyNetwork && !window.PinmonyNetwork.isForeground()) {
      ['PinmonySearchApi', 'PinmonySearchDiscoveryApi'].forEach(function (name) { if (window[name]) window[name].pause(); });
      return;
    }
    if (!searchRoute()) {
      if (!pageKey) return;
      var authRoute = /^\\/(?:login|logout|signup)(?:\\/|$)/i.test(location.pathname);
      ['PinmonySearchApi', 'PinmonySearchDiscoveryApi', 'PinmonySearchUiApi'].forEach(function (name) {
        var api = window[name]; if (api) { if (!authRoute && api.pause) api.pause(); else api.reset(); }
      });
      if (window.PinmonySearchQuizApi) window.PinmonySearchQuizApi.reset();
      pageKey = ''; query = ''; edited = false; session++; notify(empty('closed')); return;
    }
    var key = currentPageKey();
    if (key !== pageKey) { pageKey = key; session++; edited = false; query = new URLSearchParams(location.search).get('q') || ''; lastState = ''; }
    var api = window.PinmonySearchApi && window.PinmonySearchApi.read(key, schedule, function () {
      return searchRoute() && currentPageKey() === key && pageKey === key;
    });
    var discovery = window.PinmonySearchDiscoveryApi && window.PinmonySearchDiscoveryApi.read(key, schedule);
    if (discovery) api = null;
    var ui = window.PinmonySearchUiApi;
    var hint = ui && ui.readHint(key, schedule);
    var typeahead = ui && ui.readSuggestions(key, query, edited, schedule);
    var quiz = window.PinmonySearchQuizApi && window.PinmonySearchQuizApi.read(key, schedule);
    categories = api && api.categories || []; results = api && api.results || [];
    suggestions = typeahead ? typeahead.items : []; heroes = discovery && discovery.heroes || [];
    sections = discovery && discovery.sections || [];
    var value = empty((api && api.busy && !api.active || discovery && discovery.busy && !discovery.active) ? 'loading' : 'state');
    value.placeholder = typeof hint === 'string' ? hint : '';
    value.categories = categories; value.suggestions = suggestions; value.heroes = heroes;
    value.suggestionBusy = !!(typeahead && typeahead.busy); value.suggestionError = typeahead ? typeahead.error : "";
    value.ideaSections = sections; value.results = results; value.quiz = quiz || undefined;
    value.discoveryApi = !!discovery; value.discoveryBusy = !!(discovery && discovery.busy);
    value.inputReady = !!ui && typeof window.PinmonySearchQuery === 'function' &&
      typeof window.PinmonySearchSubmit === 'function';
    value.discoveryError = discovery ? discovery.error : ''; value.discoveryActive = !!(discovery && discovery.active);
    value.discoveryEnded = !!(discovery && discovery.ended); value.api = true;
    value.apiError = api ? api.error : discovery ? '' : '搜索接口不可用，请重试';
    if (typeahead && typeahead.error && edited) value.apiError = typeahead.error;
    value.apiActive = !!(api && api.active); value.apiBusy = !!(api && api.busy); value.apiEnded = !!(api && api.ended);
    notify(value);
  }
  function schedule() { if (!scheduled) scheduled = setTimeout(sync, 0); }
  function valid(s, p) { return s === session && p === pageKey && p === currentPageKey() && searchRoute(); }
  function navigate(value) {
    try { var url = new URL(value, pageKey); if (url.origin !== location.origin || url.protocol !== 'https:') return false;
      location.assign(url.href); return true; } catch (_) { return false; }
  }
  function submit(value) {
    if (typeof value !== 'string' || !value.trim() || value.length > 300) return false;
    return navigate('/search/pins/?q=' + encodeURIComponent(value.trim()));
  }
  window.PinmonySearchQuery = function (s, p, value, refreshSuggestions) {
    if (!valid(s, p) || typeof value !== 'string' || value.length > 300) return false;
    if (refreshSuggestions && window.PinmonySearchUiApi) window.PinmonySearchUiApi.refreshSuggestions();
    query = value; edited = true; schedule(); return true;
  };
  window.PinmonySearchSubmit = function (s, p, value) { return valid(s, p) && submit(value); };
  window.PinmonySearchAction = function (s, p, id, kind) {
    if (!valid(s, p) || typeof id !== 'string') return false;
    if (kind === 'suggestion') { var item = suggestions.find(function (v) { return v.id === id && v.enabled; }); return !!item && submit(item.label); }
    if (kind === 'hero' || kind === 'idea' || kind === 'ideaSection') return !!window.PinmonySearchDiscoveryApi && window.PinmonySearchDiscoveryApi.action(id);
    var values = kind === 'category' ? categories : kind === 'result' ? results : [];
    var item = values.find(function (v) { return v.id === id && v.enabled; }); return !!item && navigate(item.targetUrl);
  };
  window.PinmonySearchQuizAction = function (s, p, kind, id) { return valid(s, p) && !!window.PinmonySearchQuizApi && window.PinmonySearchQuizApi.action(p, kind, id); };
  window.PinmonySearchOpenFilters = function (s, p) { return valid(s, p) && !!window.PinmonySearchUiApi; };
  window.PinmonySearchReadFilters = function (s, p) {
    if (!valid(s, p)) return { options: [], loading: searchRoute() && p === currentPageKey(), error: '', status: 'session-sync' };
    return window.PinmonySearchUiApi ? window.PinmonySearchUiApi.readFilters(p) : { options: [], loading: false, error: '筛选接口不可用，请重试' };
  };
  window.PinmonySearchDeleteHistory = function (s, p, id) { return valid(s, p) && !!window.PinmonySearchUiApi && window.PinmonySearchUiApi.deleteHistory(p, id); };
  window.PinmonySearchSelectFilter = function () { return false; };
  window.PinmonySearchCloseFilters = function (s, p) { return valid(s, p); };
  window.PinmonySearchLoadMore = function (s, p) {
    if (!valid(s, p) || Date.now() - lastLoadAt < 700) return false;
    lastLoadAt = Date.now(); var api = new URLSearchParams(location.search).get('q') ? window.PinmonySearchApi : window.PinmonySearchDiscoveryApi;
    return !!api && api.loadMore();
  };
  window.PinmonySearchRefresh = function (s, p) {
    if (s !== undefined && !valid(s, p)) return false;
    if (!searchRoute()) return false;
    if (window.PinmonySearchUiApi) window.PinmonySearchUiApi.reset();
    var api = new URLSearchParams(location.search).get('q') ? window.PinmonySearchApi : window.PinmonySearchDiscoveryApi;
    var accepted = !!api && api.refresh(); lastState = ''; schedule(); return accepted;
  };
  window.addEventListener('pageshow', function () { lastState = ''; schedule(); });
  window.addEventListener('popstate', function () { lastState = ''; schedule(); });
  window.setInterval(function () { if (documentActive && searchRoute()) schedule(); }, 2000); schedule();
})();`;
