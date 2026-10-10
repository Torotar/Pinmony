export const PIN_HOME_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\.com$/.test(location.hostname)) return;
  var session = 0;
  var pageKey = '';
  var selectedId = 'tab:all';
  var tabs = [];
  var lastState = '';
  var scheduled = 0;
  var paused = false;
  var returnRetention = false;
  var lastLoadAt = 0;
  function homeRoute() {
    return location.pathname === '/' || location.pathname === '/ideas' || location.pathname.indexOf('/ideas/') === 0 || location.pathname === '/today' || location.pathname.indexOf('/today/') === 0;
  }
  function tabId(boardId) { return boardId ? 'tab:' + boardId : 'tab:all'; }
  function makeTabs() {
    var saved = window.PinmonyHomeApi && window.PinmonyHomeApi.initialTabs();
    var result = [{ id: 'tab:all', label: '所有', selected: selectedId === 'tab:all', enabled: true }];
    (saved || []).forEach(function (board) {
      var id = tabId(board.boardId);
      result.push({ id: id, label: board.name, selected: selectedId === id, enabled: true });
    });
    if (!result.some(function (tab) { return tab.id === selectedId; })) selectedId = 'tab:all';
    result.forEach(function (tab) { tab.selected = tab.id === selectedId; });
    return result;
  }
  function publish() {
    scheduled = 0;
    if (paused || returnRetention) return;
    if (!homeRoute()) {
      if (pageKey) {
        if (window.PinmonyHomeApi && window.PinmonyHomeApi.reset) window.PinmonyHomeApi.reset();
        pageKey = ''; tabs = []; lastState = ''; session++;
        notify({ kind: 'closed', session: session, pageKey: '', selectedTab: '', tabs: [], pins: [] });
      }
      return;
    }
    var key = location.origin + location.pathname;
    if (pageKey !== key) {
      if (window.PinmonyHomeApi && window.PinmonyHomeApi.reset) window.PinmonyHomeApi.reset();
      pageKey = key; selectedId = 'tab:all'; session++; lastState = '';
    }
    if (!window.PinmonyHomeApiEnabled || !window.PinmonyHomeApi) {
      tabs = [{ id: 'tab:all', label: '所有', selected: true, enabled: true }];
      notify({ kind: 'failed', session: session, pageKey: pageKey, selectedTab: '所有',
        tabs: tabs, pins: [], dataSource: 'api', error: '首页接口不可用' });
      return;
    }
    var api = window.PinmonyHomeApi;
    // The authenticated username remains the gate; category data is independent
    // of the All feed and must not serialize its first request.
    if (!api.identityReady()) {
      tabs = [{ id: 'tab:all', label: '所有', selected: true, enabled: true }];
      notify({ kind: 'loading', session: session, pageKey: pageKey, selectedTab: '所有',
        tabs: tabs, pins: [], dataSource: 'api' });
      return;
    }
    var categoriesReady = api.savedTabsReady(), categoriesFailed = api.savedTabsFailed();
    if (categoriesReady || !tabs.length) tabs = makeTabs();
    if (!categoriesReady && !categoriesFailed) schedule(240);
    var selected = tabs.filter(function (tab) { return tab.id === selectedId; })[0] || tabs[0];
    var boardId = selected.id === 'tab:all' ? '' : selected.id.slice(4);
    var requestedSession = session, requestedPage = pageKey, requestedId = selected.id;
    var apiKey = location.origin + location.pathname + ':' + (boardId || 'homefeed');
    var feed = api.read(apiKey, true, schedule, function () {
      return homeRoute() && !paused && !returnRetention && session === requestedSession &&
        pageKey === requestedPage && selectedId === requestedId;
    }, boardId);
    var common = { session: session, pageKey: pageKey, selectedTab: selected.label, tabs: tabs,
      pins: feed && feed.active ? feed.pins : [], board: feed && feed.board ? feed.board : null,
      dataSource: 'api', refreshing: !!(feed && feed.refreshing),
      loadingMore: !!(feed && feed.active && feed.busy && !feed.refreshing),
      endReached: !!(feed && feed.ended), sourceError: feed ? feed.error : '' };
    common.categorySourceFailure = categoriesFailed;
    if (feed && feed.error && !feed.active) {
      common.kind = 'failed'; common.error = feed.error;
    } else {
      common.kind = feed && feed.active ? 'state' : 'loading';
    }
    notify(common);
  }
  function notify(value) {
    if (!window.PinmonyShareBridge || !window.PinmonyShareBridge.homeState) return;
    var serialized = JSON.stringify(value);
    if (serialized === lastState) return;
    lastState = serialized;
    window.PinmonyShareBridge.homeState(serialized);
  }
  function schedule(delay) {
    if (scheduled || paused || returnRetention) return;
    scheduled = setTimeout(publish, typeof delay === 'number' ? delay : 100);
  }
  function resume() { paused = false; returnRetention = false; }
  window.PinmonyHomeSetUsername = function (username) {
    if (!window.PinmonyHomeApi || !window.PinmonyHomeApi.setUsername) return false;
    window.PinmonyHomeApi.setUsername(username);
    lastState = ''; schedule(); return true;
  };
  window.PinmonyHomeTab = function (requestedSession, requestedPage, id) {
    if (requestedSession !== session || requestedPage !== pageKey || !homeRoute()) return false;
    var target = tabs.filter(function (tab) { return tab.id === id && tab.enabled; })[0];
    if (!target) return false;
    if (selectedId === id) return true;
    resume(); selectedId = id; session++; lastState = '';
    if (window.PinmonyHomeApi) window.PinmonyHomeApi.reset();
    schedule(0); return true;
  };
  window.PinmonyHomeLoadMore = function (requestedSession, requestedPage) {
    if (requestedSession !== session || requestedPage !== pageKey || !homeRoute() ||
        Date.now() - lastLoadAt < 800) return false;
    resume(); lastLoadAt = Date.now();
    return !!(window.PinmonyHomeApi && window.PinmonyHomeApi.loadMore());
  };
  window.PinmonyHomeDemand = function (requestedPage) {
    if (requestedPage !== location.href && requestedPage !== location.origin + location.pathname) return false;
    if (returnRetention) return true;
    paused = false; schedule(); return true;
  };
  window.PinmonyHomeRefresh = function () {
    if (returnRetention) return true;
    resume(); lastState = ''; schedule(0); return true;
  };
  window.PinmonyHomeApiRefresh = function (requestedSession, requestedPage) {
    if (requestedSession !== session || requestedPage !== pageKey || !homeRoute()) return false;
    resume();
    if (window.PinmonyHomeApi && window.PinmonyHomeApi.savedTabsFailed()) {
      window.PinmonyHomeApi.retrySavedTabs();
    }
    return !!(window.PinmonyHomeApi && window.PinmonyHomeApi.refresh());
  };
  window.PinmonyHomeRetryCategories = function (requestedPage) {
    if (!homeRoute() || requestedPage !== pageKey || !window.PinmonyHomeApi ||
        !window.PinmonyHomeApi.retrySavedTabs || !window.PinmonyHomeApi.retrySavedTabs()) return false;
    resume(); lastState = ''; schedule(0); return true;
  };
  window.PinmonyHomePauseForReturn = function () {
    returnRetention = true;
    if (window.PinmonyHomeApi && window.PinmonyHomeApi.pause) window.PinmonyHomeApi.pause();
  };
  window.addEventListener('pagehide', function () {
    paused = true;
    if (scheduled) clearTimeout(scheduled);
    scheduled = 0;
    if (window.PinmonyHomeApi && window.PinmonyHomeApi.pause) window.PinmonyHomeApi.pause();
  });
  window.addEventListener('pageshow', function (event) {
    if (!event.persisted) { paused = false; schedule(); }
  });
  window.addEventListener('popstate', function () { if (!returnRetention) schedule(); });
  if (window.history && window.history.pushState) {
    var originalPushState = window.history.pushState;
    window.history.pushState = function () {
      originalPushState.apply(this, arguments);
      if (!returnRetention) schedule();
    };
  }
  if (window.history && window.history.replaceState) {
    var originalReplaceState = window.history.replaceState;
    window.history.replaceState = function () {
      originalReplaceState.apply(this, arguments);
      if (!returnRetention) schedule();
    };
  }
  schedule(0);
  setInterval(function () { if (!paused && !returnRetention) publish(); }, 400);
})();
`;

