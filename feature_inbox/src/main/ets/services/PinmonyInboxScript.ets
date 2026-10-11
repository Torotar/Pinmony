// The hidden Pinterest document supplies only the authenticated same-origin
// session. Inbox content and actions are read through the resource interfaces.
export const PIN_INBOX_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/i.test(location.hostname)) return;
  var documentActive = true, bridgeWarning = false;
  if (window.addEventListener) {
    window.addEventListener('pagehide', function () { documentActive = false; });
    window.addEventListener('pageshow', function () { documentActive = true; bridgeWarning = false; lastState = ''; schedule(); });
  }
  var active = false;
  var session = 0;
  var rootUrl = '';
  var section = 'messages';
  var lastState = '';
  var scheduled = false;

  function pageUrl() {
    return location.origin + location.pathname.replace(/\\/$/, '') + '/';
  }
  function isRoot() {
    return /^\\/(?:messages|inbox|updates|notifications)\\/?$/i.test(location.pathname);
  }
  window.PinmonyInboxDemand = function (page) {
    if (!documentActive || page !== location.href) return false;
    clearTimeout(scheduled); scheduled = 0; sync(); return true;
  };
  function notify(value) {
    if (!documentActive) return;
    var serialized = JSON.stringify(value);
    if (serialized === lastState) return;
    try {
      var bridge = window.PinmonyShareBridge;
      if (!bridge || !bridge.inboxState) return;
      bridge.inboxState(serialized); lastState = serialized;
    } catch (_) { if (!bridgeWarning) { bridgeWarning = true; console.warn('BridgeTrace: inbox unavailable'); } }
  }
  function current(page, expectedSession) {
    return active && session === expectedSession && rootUrl === page && isRoot();
  }
  function resetApis(authRoute) {
    var apis = [window.PinmonyInboxApi, window.PinmonyInboxContactsApi, window.PinmonyInboxConversations];
    apis.forEach(function (api) {
      if (!api) return;
      if (authRoute || !api.pause) api.reset(); else api.pause();
    });
  }
  function labels() {
    return { updateLabel: '更新', inboxLabel: '收件箱', messagesLabel: '消息',
      readLabel: '已读', unreadLabel: '未读' };
  }
  function empty(sectionName, itemCount) {
    if (itemCount > 0) return { title: '', description: '' };
    if (sectionName === 'updates') return {
      title: '更新即将到来',
      description: '使用更新来查看 Pin 图和图板中的动态，并获取关于值得探索的主题的提示。更新很快就会发布。'
    };
    return {
      title: '开始对话',
      description: '使用消息与朋友聊天，分享 Pin 图和图板，共同计划创意。你的对话会显示在此处。'
    };
  }
  function apiFailure(sectionName, error) {
    return sectionName === 'updates' ? (error || '更新接口读取失败，请重试') :
      (error || '会话列表读取失败，请重试');
  }
  function mapUpdates(state) {
    if (!state || !Array.isArray(state.items)) return [];
    return state.items.map(function (item) {
      var copy = Object.assign({}, item);
      copy.enabled = true;
      copy.moreId = 'news-menu:' + item.id;
      return copy;
    });
  }
  function mapContacts(state) {
    if (!state || !Array.isArray(state.items)) return [];
    return state.items.map(function (item) {
      var copy = Object.assign({}, item);
      copy.id = 'contact:' + item.userId;
      copy.enabled = true;
      return copy;
    });
  }
  function sync() {
    scheduled = 0;
    if (!documentActive) return;
    if (window.PinmonyNativeNetworkEnabled === true && window.PinmonyNetwork && typeof window.PinmonyNetwork.isReady === "function" && !window.PinmonyNetwork.isReady()) return;
    scheduled = false;
    if (!isRoot()) {
      if (active) notify({ kind: 'closed', session: session, pageUrl: rootUrl });
      active = false;
      lastState = '';
      resetApis(/^\\/(?:login|logout|signup)(?:\\/|$)/i.test(location.pathname));
      return;
    }
    if (!active || rootUrl !== pageUrl()) {
      active = true;
      session++;
      rootUrl = pageUrl();
      lastState = '';
      section = /^\\/(?:updates|notifications)\\/?$/i.test(location.pathname) ? 'updates' : 'messages';
    }
    var page = rootUrl;
    var expectedSession = session;
    var isCurrent = function () { return current(page, expectedSession); };
    var api = section === 'updates' && window.PinmonyInboxApi ?
      window.PinmonyInboxApi.read(page, schedule, isCurrent) : null;
    var contacts = section === 'messages' && window.PinmonyInboxContactsApi ?
      window.PinmonyInboxContactsApi.read(page, schedule, isCurrent) : null;
    var conversations = section === 'messages' && window.PinmonyInboxConversations ?
      window.PinmonyInboxConversations.read(page, schedule, isCurrent) : null;
    var labelsValue = labels();
    var items = section === 'updates' ? mapUpdates(api && api.kind === 'ready' ? api : null) :
      conversations && conversations.kind === 'ready' ? conversations.items : [];
    var contactsItems = section === 'messages' ? mapContacts(contacts && contacts.kind === 'ready' ? contacts : null) : [];
    var emptyValue = empty(section, items.length);
    var conversationFailed = section === 'messages' && (!conversations || conversations.kind === 'failed');
    var apiFailed = section === 'updates' && (!api || api.kind === 'failed') || conversationFailed;
    var pending = section === 'updates' ? api && api.kind === 'loading' :
      !conversations || conversations.kind === 'loading';
    var message = {
      kind: pending ? 'apiPending' : apiFailed ? 'apiFailed' : 'state',
      session: session, pageUrl: page, section: section, dataSource: 'api',
      contactsDataSource: 'api', hasMore: !!(api && api.hasMore),
      moreLoading: !!(api && api.moreLoading), moreError: api ? api.moreError || '' : '',
      apiError: apiFailed ? apiFailure(section, section === 'updates' ? api && api.error : conversations && conversations.error) : '',
      contactsLoading: !!(contacts && contacts.kind === 'loading'),
      contactsError: contacts && contacts.kind === 'failed' ? contacts.error || '联系人接口读取失败，请重试' : '',
      updateLabel: labelsValue.updateLabel, inboxLabel: labelsValue.inboxLabel,
      messagesLabel: labelsValue.messagesLabel, readLabel: labelsValue.readLabel,
      unreadLabel: labelsValue.unreadLabel, emptyTitle: emptyValue.title,
      emptyDescription: emptyValue.description, homeLabel: section === 'updates' ? '浏览主页' : '',
      homeId: section === 'updates' ? 'home' : '', composeLabel: section === 'messages' ? '新消息' : '',
      composeId: section === 'messages' ? 'compose' : '', contactsLabel: section === 'messages' ? '联系人' : '',
      items: items, contacts: contactsItems
    };
    notify(message);
  }
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    setTimeout(sync, 0);
  }
  window.PinmonyInboxSelectApi = function (value, expectedSession) {
    if (!active || expectedSession !== session || !isRoot() || (value !== 'updates' && value !== 'messages')) return false;
    if (section === value) { schedule(); return true; }
    section = value;
    if (window.PinmonyInboxApi) window.PinmonyInboxApi.reset();
    if (window.PinmonyInboxContactsApi) window.PinmonyInboxContactsApi.reset();
    if (window.PinmonyInboxConversations) window.PinmonyInboxConversations.reset();
    lastState = '';
    schedule();
    return true;
  };
  window.PinmonyInboxApiMore = function (expectedSession) {
    if (!active || expectedSession !== session || !isRoot() || section !== 'updates' || !window.PinmonyInboxApi) return false;
    return window.PinmonyInboxApi.more(schedule, function () { return current(rootUrl, expectedSession); });
  };
  window.PinmonyInboxApiAction = function (id, expectedSession) {
    if (!active || expectedSession !== session || !isRoot() || !window.PinmonyInboxConversations) return false;
    if (id === 'home') return false;
    return window.PinmonyInboxConversations.open(id, expectedSession);
  };
  window.PinmonyInboxContactsApiRefresh = function (expectedSession) {
    if (!active || expectedSession !== session || !isRoot() || !window.PinmonyInboxContactsApi) return false;
    window.PinmonyInboxContactsApi.reset(); lastState = ''; schedule(); return true;
  };
  window.PinmonyInboxApiRefresh = function () {
    if (window.PinmonyInboxApi) window.PinmonyInboxApi.reset();
    if (window.PinmonyInboxContactsApi) window.PinmonyInboxContactsApi.reset();
    if (window.PinmonyInboxConversations) window.PinmonyInboxConversations.reset();
    lastState = ''; schedule(); return true;
  };
  window.addEventListener('popstate', schedule);
  window.addEventListener('pageshow', schedule);
  window.setInterval(function () { if (documentActive && isRoot()) schedule(); }, 2000);
  schedule();
})();`;


