// Manual rollback only. API failures never invoke the old DOM actions.
export const PIN_POST_API_ENABLED: boolean = true;
export const PIN_POST_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname) || !window.PinmonyPostApiEnabled) return;
  var shares = null, more = null, comments = null, reaction = null, feedbackContext = {}, aggregated = {};
  var nextToken = 0, likeBusy = false, routeVersion = 0, graph = null, siteHeaders = {};
  var detailReadHandler = '';
  var homeMenu = null;
  var sessionUserId = '';
  function currentUserId() {
    if (sessionUserId) return sessionUserId;
    try {
      var node = document.getElementById && document.getElementById('__PWS_INITIAL_PROPS__');
      var initial = node && JSON.parse(node.textContent || '{}');
      var context = initial && initial.client_context;
      if (!context || !context.user) context = initial && initial.initialReduxState && initial.initialReduxState.session;
      var user = context && context.user;
      var authenticated = context && (typeof context.is_authenticated === 'boolean' ? context.is_authenticated : context.isAuthenticated);
      if (context && authenticated !== false && user && /^\\d+$/.test(String(user.id || '')) && String(user.id) !== '0')
        sessionUserId = String(user.id);
    } catch (_) {}
    return sessionUserId;
  }
  if (window.addEventListener) window.addEventListener('pagehide', function () { cancelContacts(shares); });
  function pinId(url) { var m = String(url || '').match(/\\/pin\\/(\\d+)/); return m ? m[1] : ''; }
  function current(pin) { return !!pinId(pin) && (pinId(location.pathname) === pinId(pin) ||
    homeMenu && homeMenu.pin === pin && homeMenu.pageKey === menuPageKey()); }
  function searchMenuPage() { return location.pathname === '/search/' || location.pathname.indexOf('/search/') === 0; }
  function menuPageKey() { return searchMenuPage() ? location.href.split('#')[0] : location.origin + location.pathname; }
  function raw(pin) { return homeMenu && homeMenu.pin === pin && current(pin) ? homeMenu.raw :
    window.PinmonyDetailApi && window.PinmonyDetailApi.raw(pin); }
  function csrf() { var m = document.cookie.match(/(?:^|;\\s*)csrftoken=([^;]+)/); return m ? decodeURIComponent(m[1]) : ''; }
  function appVersion() {
    if (siteHeaders['X-App-Version']) return siteHeaders['X-App-Version'];
    try {
      var node = document.getElementById && document.getElementById('__PWS_INITIAL_PROPS__');
      var initial = node && JSON.parse(node.textContent || '{}');
      var value = initial && initial.client_context && initial.client_context.app_version;
      return typeof value === 'string' && /^[A-Za-z0-9._-]{1,80}$/.test(value) ? value : '';
    } catch (_) { return ''; }
  }
  function detailReadHeadersReady() {
    return !!appVersion() && detailReadHandler === 'www/pin/[id].js';
  }
  async function waitDetailReadHeaders(pin, valid) {
    var page = location.href, version = routeVersion;
    // Only the read-only preview waits. Never dispatch a partial request or
    // replay a write while current-document metadata is still being learned.
    for (var attempt = 0; attempt < 160; attempt++) {
      if (version !== routeVersion || page !== location.href || !current(pin) || !valid()) throw new Error('stale');
      if (detailReadHeadersReady()) return;
      await new Promise(function (resolve) { setTimeout(resolve, 50); });
    }
    if (version !== routeVersion || page !== location.href || !current(pin) || !valid()) throw new Error('stale');
    if (!detailReadHeadersReady()) throw new Error('评论预览请求信息尚未就绪，请重试');
  }
  function learnReadHeaders(url, body, headers) {
    try {
      var outgoing = new URL(url, location.href);
      if (outgoing.origin !== location.origin || !/^\\/resource\\//.test(outgoing.pathname)) return;
      var values = new Headers(headers), version = values.get('X-App-Version');
      if (version && /^[A-Za-z0-9._-]{1,80}$/.test(version)) siteHeaders['X-App-Version'] = version;
      // Learn the existing detail handler only from a matching current Pin
      // resource. Index/search/repin and late previous-Pin headers cannot bind it.
      var source = new URLSearchParams(body || outgoing.search).get('source_url');
      if (/^\\/resource\\/(?:PinResource|RelatedModulesResource|UnifiedComments(?:Preview)?Resource)\\/get\\/$/.test(outgoing.pathname) &&
          pinId(source) && pinId(source) === pinId(location.pathname) &&
          values.get('X-Pinterest-Pws-Handler') === 'www/pin/[id].js') {
        detailReadHandler = 'www/pin/[id].js';
        siteHeaders['X-Pinterest-Pws-Handler'] = 'www/pin/[id].js';
      }
    } catch (_) {}
  }
  function event(kind, pin, value, session, scope, metadata) {
    if (!current(pin) || !window.PinmonyShareBridge || !window.PinmonyShareBridge.postState) return;
    window.PinmonyShareBridge.postState(JSON.stringify({ kind: kind, pinUrl: pin, value: value,
      session: session || 0, scope: scope || 'detail', platform: metadata && metadata.platform || '',
      targetUrl: metadata && metadata.targetUrl || '', title: metadata && metadata.title || '' }));
  }
  async function request(pin, name, operation, options, valid, graphql, readOwner) {
    if (!current(pin) || !valid()) throw new Error('stale');
    var previewRead = name === 'UnifiedCommentsPreviewResource' && operation === 'get', startedAt = Date.now();
    function timing(event) {
      if (previewRead && current(pin) && valid() && window.PinmonyDetailReadTiming)
        window.PinmonyDetailReadTiming(pin, 'comments.' + event, Date.now() - startedAt);
    }
    timing('context.wait');
    if (name === 'UnifiedCommentsPreviewResource' && operation === 'get' && !detailReadHeadersReady()) {
      try { await waitDetailReadHeaders(pin, valid); }
      catch (error) { timing('context.failed'); throw error; }
    }
    if (!current(pin) || !valid()) throw new Error('stale');
    timing('context.ready');
    var sourcePath = name === 'BoardResource' && operation === 'create' ? '/board/create/' + pinId(pin) :
      name === 'BoardPickerBoardsResource' ? '/pin/' + pinId(pin) + '/repin/' : '/pin/' + pinId(pin) + '/';
    var headers = Object.assign({}, siteHeaders, { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
      'X-Pinterest-AppState': 'active', 'X-Pinterest-Source-Url': sourcePath });
    // PinResource uses the detail route handler even when requested from the home feed.
    // Never inherit an index/search handler learned from an unrelated request.
    if (name === 'PinResource' && operation === 'get') headers['X-Pinterest-Pws-Handler'] = 'www/pin/[id].js';
    if (name === 'UnifiedCommentsPreviewResource' && operation === 'get')
      headers['X-Pinterest-Pws-Handler'] = detailReadHandler;
    // Captured successful board-picker request uses its own route handler.
    if (name === 'BoardPickerBoardsResource' && operation === 'get')
      headers['X-Pinterest-Pws-Handler'] = 'www/pin/[id]/repin.js';
    var versionHeader = appVersion();
    if (versionHeader) headers['X-App-Version'] = versionHeader;
    var args = { credentials: 'same-origin', headers: headers };
    var body = { options: options, context: {} }, url;
    if (graphql) {
      url = '/_/graphql/'; args.method = 'POST'; headers['Content-Type'] = 'application/json';
      args.body = JSON.stringify(graphql);
    } else {
      url = '/resource/' + name + '/' + operation + '/';
      var form = 'source_url=' + encodeURIComponent(sourcePath) + '&data=' + encodeURIComponent(JSON.stringify(body));
      if (operation === 'get') url += '?' + form + '&_=' + Date.now();
      else { args.method = 'POST'; headers['Content-Type'] = 'application/x-www-form-urlencoded'; args.body = form; }
    }
    if (args.method === 'POST') { var token = csrf(); if (!token) throw new Error('当前网页会话缺少请求凭据，请重新登录'); headers['X-CSRFToken'] = token; }
    var abort = new AbortController(); args.signal = abort.signal;
    if (readOwner) readOwner.contactsAbort = abort;
    var timer = setTimeout(function () { abort.abort(); }, 15000);
    try {
      timing('request.dispatched');
      var response = await fetch(url, args), json;
      timing('response.received');
      try { json = await response.json(); }
      catch (_) {
        if (!current(pin) || !valid()) throw new Error('stale');
        if (response.status === 401 || response.status === 403)
          throw new Error('接口请求被拒绝（HTTP ' + response.status + '），请重试');
        throw new Error('网页接口返回了无效数据' + (response.status ? '（HTTP ' + response.status + '）' : '') + '，请重试');
      }
      if (!current(pin) || !valid()) throw new Error('stale');
      if (graphql) {
        if (!response.ok || json.errors || !json.data) throw new Error('分享链接生成失败');
        return json.data;
      }
      var resource = json.resource_response, error = resource && resource.error;
      if (!response.ok || error || !resource || resource.status !== 'success' ||
          typeof resource.code === 'number' && resource.code !== 0)
        throw new Error(error && error.message || resource && resource.message || '请求失败，请重试');
      var user = json.client_context && json.client_context.user;
      if (json.client_context && json.client_context.is_authenticated === false) sessionUserId = '';
      else if (user && /^\\d+$/.test(String(user.id || ''))) sessionUserId = String(user.id);
      if (!resource.bookmark && json.resource && json.resource.options && Array.isArray(json.resource.options.bookmarks))
        resource.bookmark = json.resource.options.bookmarks[0] || '';
      timing('business.validated');
      return resource;
    } catch (error) {
      timing('request.failed');
      if (error.name === 'AbortError') throw new Error('请求超时，请重试');
      if (error.name === 'TypeError') throw new Error('网络请求失败，请重试');
      throw error;
    } finally { clearTimeout(timer); if (readOwner && readOwner.contactsAbort === abort) readOwner.contactsAbort = null; }
  }
  function inviteResult(json) {
    var result = json && json.data && json.data.v3InviteUserExternalQuery && json.data.v3InviteUserExternalQuery.data;
    if (!result || !/^https:\\/\\/pin\\.it\\/[A-Za-z0-9]+$/.test(result.inviteUrl || '')) throw new Error('分享链接返回无效');
    return result;
  }
  function learnHeaders(headers) {
    if (!headers) return;
    try { var parsed = new Headers(headers); ['X-Pinterest-AppState', 'X-Pinterest-Source-Url', 'X-Pinterest-Pws-Handler', 'X-App-Version'].forEach(function (name) {
      var value = parsed.get(name);
      if (value && (name !== 'X-App-Version' || /^[A-Za-z0-9._-]{1,80}$/.test(value))) siteHeaders[name] = value;
    }); } catch (_) {}
  }
  function capture(url, body, headers) {
    try {
      var u = new URL(url, location.href);
      if (u.origin !== location.origin) return null;
      if (u.pathname === '/_/graphql/') {
        var payload = JSON.parse(String(body || '{}')), variables = payload.variables || {}, type = JSON.parse(variables.inviteType || '{}');
        if (String(variables.objectId) !== pinId(location.pathname) || type.invite_category !== 3 || type.invite_object !== 1 || !/^[a-f0-9]{64}$/.test(payload.queryHash || '')) return null;
        learnHeaders(headers);
        var record = { pin: String(variables.objectId), template: payload, channel: String(type.invite_channel), version: routeVersion, share: shares, result: null, pending: null };
        graph = record; return { graph: record };
      }
      var form = new URLSearchParams(body || u.search), data = JSON.parse(form.get('data') || '{}'), id = pinId(form.get('source_url'));
      if (id !== pinId(location.pathname) || !id || !/ShareSuggestions(?:Typeahead)?Resource\\/get\\//.test(u.pathname)) return null;
      learnHeaders(headers);
      return { pin: id, version: routeVersion, share: shares, token: shares && shares.token,
        query: data.options && data.options.term || '', search: /Typeahead/.test(u.pathname) };
    } catch (_) { return null; }
  }
  function receive(contract, json) {
    if (!contract) return;
    if (contract.graph) {
      var record = contract.graph;
      if (record.version !== routeVersion || record.pin !== pinId(location.pathname) || record.share && record.share !== shares) return;
      try {
        record.result = inviteResult(json);
        if (shares && pinId(shares.pin) === record.pin && record.channel === '10') {
          shares.invite = record.result; shares.inviteError = ''; updateShare(shares);
        }
      } catch (_) {}
      return;
    }
    var state = shares, resource = json && json.resource_response;
    if (contract.version !== routeVersion || !state || contract.share && (contract.share !== state || contract.token !== state.token) ||
        contract.pin !== pinId(state.pin) || contract.query !== state.query.trim() || !resource || resource.status !== 'success') return;
    var items = contract.search ? resource.data && resource.data.items : resource.data;
    if (!Array.isArray(items)) return;
    state.token++; state.loading = false; state.items = items.filter(function (item) { return /^\\d+$/.test(String(item.id)) && item.username; });
    state.contactsError = ''; state.feedback = state.items.length ? '' : '没有可用的联系人'; updateShare(state);
  }
  function watchResponse(contract, pending) {
    if (!contract) return;
    var observed = pending.then(async function (response) {
      var json; try { json = await response.clone().json(); } catch (_) { return null; }
      receive(contract, json); return json;
    }).catch(function () { return null; });
    if (contract.graph) contract.graph.pending = observed;
  }
  // Observe only current-page resource contracts; never persist cookies or desktop capture values.
  function observe(url, body, json) {
    try {
      var u = new URL(url, location.href), form = new URLSearchParams(body || u.search), data = JSON.parse(form.get('data') || '{}');
      var options = data.options || {}, pin = pinId(form.get('source_url'));
      if (u.origin !== location.origin || !pin || pin !== pinId(location.pathname)) return;
      if (/UnifiedCommentsResource/.test(u.pathname) && /^\\d+$/.test(String(options.aggregated_pin_id || '')))
        aggregated[pin] = String(options.aggregated_pin_id);
      if (u.pathname === '/resource/ApiResource/update/' &&
          (options.url === '/v3/pin/' + pin + '/feedback/see_more/' || options.url === '/v3/pin/' + pin + '/feedback/see_more/undo/') &&
          options.data && String(options.data.pin) === pin)
        feedbackContext[pin] = Object.assign({}, feedbackContext[pin] || {}, options.data);
    } catch (_) {}
  }
  var originalFetch = window.fetch;
  window.fetch = function (input, init) {
    var url = typeof input === 'string' ? input : input && input.url || '';
    learnReadHeaders(url, init && init.body, init && init.headers || input && input.headers);
    if (/resource\\/(?:UnifiedCommentsResource|ApiResource)\\//.test(url)) observe(url, init && init.body, null);
    var contract = capture(url, init && init.body, init && init.headers || input && input.headers), pending = originalFetch.apply(this, arguments);
    watchResponse(contract, pending);
    if (!contract && input && typeof input.clone === 'function' && /\\/_\\/graphql\\//.test(url)) {
      var version = routeVersion;
      input.clone().text().then(function (body) {
        if (version === routeVersion) watchResponse(capture(url, body, init && init.headers || input.headers), pending);
      }).catch(function () {});
    }
    return pending;
  };
  var open = XMLHttpRequest.prototype.open, send = XMLHttpRequest.prototype.send;
  var setHeader = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.open = function (method, url) { this.__pinwebPostUrl = String(url); this.__pinwebPostHeaders = {}; return open.apply(this, arguments); };
  XMLHttpRequest.prototype.setRequestHeader = function (name, value) { this.__pinwebPostHeaders[name] = value; return setHeader.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function (body) {
    learnReadHeaders(this.__pinwebPostUrl || '', body, this.__pinwebPostHeaders);
    observe(this.__pinwebPostUrl || '', body, null);
    var contract = capture(this.__pinwebPostUrl || '', body, this.__pinwebPostHeaders), xhr = this;
    if (contract) this.addEventListener('load', function () { try { receive(contract, xhr.responseType === 'json' ? xhr.response : JSON.parse(xhr.responseText)); } catch (_) {} }, { once: true });
    return send.apply(this, arguments);
  };
  function aggregate(pin) {
    var p = raw(pin), value = p && (p.aggregated_pin_id || p.aggregated_pin_data && p.aggregated_pin_data.id);
    return /^\\d+$/.test(String(value || '')) ? String(value) : aggregated[pinId(pin)] || '';
  }
  function feedbackData(pin) {
    if (!current(pin)) return null;
    var id = pinId(pin), p = raw(pin), observed = feedbackContext[id];
    // PinResource does not always expose recommendation metadata. Do not require
    // a prior website feedback click to enable the first native feedback request.
    if (!p || String(p.id) !== id) p = {};
    var context = Object.assign({}, p, observed || {}), data = { pin: id };
    var tracking = context.client_tracking_params || context.tracking_params;
    if (typeof tracking === 'string' && tracking) data.client_tracking_params = tracking;
    if (typeof context.through_id === 'string' && context.through_id) data.through_id = context.through_id;
    ['rec_reason_type', 'source'].forEach(function (key) {
      if (typeof context[key] === 'number' && Number.isFinite(context[key])) data[key] = context[key];
    });
    return data;
  }
  function channel(label) {
    label = platform(label);
    if (/复制|copy/i.test(label)) return '12';
    if (/^Facebook$/i.test(label)) return '5';
    if (/^Messenger$/i.test(label)) return '6';
    if (/^(?:X|Twitter)$/i.test(label)) return '9';
    return '';
  }
  function platform(label) {
    var name = String(label || '').trim().replace(/^通过\\s*(.*?)\\s*分享$/, '$1').replace(/^Share\\s+(?:via|through|on)\\s+/i, '');
    if (/^(?:Facebook\\s+)?Messenger$/i.test(name)) return 'Messenger';
    if (/^(?:消息|信息|短信|Message|Messages|SMS)$/i.test(name)) return '短信';
    if (/^(?:Twitter|X)$/i.test(name)) return 'X';
    if (/^Facebook$/i.test(name)) return 'Facebook';
    if (/^WhatsApp$/i.test(name)) return 'WhatsApp';
    return name;
  }
  function destination(option, result) {
    try {
      var url = new URL(option.targetUrl || '');
      if (!/^https:$/.test(url.protocol) || !/(^|\\.)(twitter\\.com|x\\.com|facebook\\.com|messenger\\.com)$/.test(url.hostname)) return '';
      var key = ['url', 'u', 'link', 'text'].find(function (name) { return url.searchParams.has(name); });
      if (!key) return '';
      url.searchParams.set(key, key === 'text' ? result.title + '\\n' + result.inviteUrl : result.inviteUrl);
      return url.href;
    } catch (_) { return ''; }
  }
  async function invite(state, ch) {
    var record = graph;
    if (!record || record.pin !== pinId(state.pin) || record.version !== routeVersion) throw new Error('分享链接尚未就绪，请重试');
    if (record.channel === ch) {
      if (record.result) return record.result;
      if (record.pending) {
        var observed = await record.pending;
        if (shares !== state || !current(state.pin)) throw new Error('stale');
        if (observed) return inviteResult(observed);
      }
    }
    var payload = JSON.parse(JSON.stringify(record.template)), type = JSON.parse(payload.variables.inviteType);
    type.invite_channel = typeof type.invite_channel === 'number' ? Number(ch) : ch;
    payload.variables.inviteType = JSON.stringify(type); payload.variables.objectId = pinId(state.pin);
    var data = await request(state.pin, '', '', {}, function () { return shares === state; }, payload);
    return inviteResult({ data: data });
  }
  function notifyHomeMenu() {
    if (homeMenu && current(homeMenu.pin) && window.PinmonyShareBridge &&
        typeof window.PinmonyShareBridge.homeMenuChanged === 'function')
      window.PinmonyShareBridge.homeMenuChanged(homeMenu.session);
  }
  function updateShare(state) { if (shares === state && current(state.pin)) state.changed(); }
  function cancelContacts(state) { if (state && state.contactsAbort) { state.contactsAbort.abort(); state.contactsAbort = null; } }
  async function contacts(state, query) {
    cancelContacts(state);
    var token = ++state.token; state.loading = true; state.items = []; state.feedback = ''; state.contactsError = ''; updateShare(state);
    try {
      var resource = await request(state.pin, query ? 'ShareSuggestionsTypeaheadResource' : 'ShareSuggestionsResource', 'get',
        query ? { count: 25, term: query, pin_scope: 'pins' } : { field_set_key: 'default', hide_group_conversations: true },
        function () { return shares === state && state.token === token; }, null, state);
      var items = query ? resource.data && resource.data.items : resource.data;
      if (!Array.isArray(items)) throw new Error('联系人返回格式无效');
      state.items = items.filter(function (item) { return /^\\d+$/.test(String(item.id)) && item.username; });
      state.feedback = state.items.length ? '' : '没有可用的联系人';
    } catch (error) { if (shares === state && state.token === token) state.contactsError = error.message === 'stale' ? '' : error.message; }
    finally { if (shares === state && state.token === token) { state.loading = false; updateShare(state); } }
  }
  window.PinmonyPostApi = {
    resourceRequest: request,
    rawPin: raw,
    homeMenuPinData: function (pin) {
      return homeMenu && homeMenu.pin === pin && current(pin) && !homeMenu.loading && !homeMenu.error ? homeMenu.raw : null;
    },
    aggregateId: aggregate,
    currentPin: current,
    sessionUserId: function () { return currentUserId(); },
    reset: function () { cancelContacts(shares); homeMenu = null; routeVersion++; graph = null; siteHeaders = {}; detailReadHandler = ''; nextToken++; shares = null; more = null; comments = null; reaction = null; likeBusy = false; feedbackContext = {}; aggregated = {}; },
    homeMenuOpen: function (session, pin, pageKey) {
      if(window.PinmonyNativePinMenusEnabled === true)return false;
      if (!Number.isInteger(session) || session < 1 || !pinId(pin) ||
          new URL(pin, location.href).origin !== location.origin || pageKey !== menuPageKey() ||
          !searchMenuPage() && !/^(?:\\/|\\/(?:ideas|today)(?:\\/.*)?|\\/(?:inbox|messages|updates|notifications)\\/?|\\/(?!_|(?:pin|users|search|ideas|today|settings|messages|inbox|login|signup|business|explore)\\/)[^/]+\\/(?!_|(?:followers|following)(?:\\/|$))[^/]+\\/?)$/i.test(location.pathname)) return false;
      var state = homeMenu = { session: session, pin: pin, pageKey: pageKey, raw: null, loading: true, error: '' };
      shares = { session: session, pin: pin, changed: notifyHomeMenu, token: 0, query: '', items: [],
        loading: false, feedback: '', sending: '', options: [] };
      ['Messenger', 'WhatsApp', '短信', 'Facebook', 'X'].forEach(function (name) {
        shares.options.push({ id: 'home-share:' + name, label: name, targetUrl: '', enabled: true });
      });
      // Persisted query hash supplied in the user's Pinterest capture, not a credential.
      if (!graph || graph.pin !== pinId(pin) || graph.version !== routeVersion) {
        graph = { pin: pinId(pin), version: routeVersion, channel: '12', share: shares, result: null, pending: null,
          template: { queryHash: '6312848b4bb08588587683a04a42e4d0333e2e986fcab0cef4ed200786d3f5d9',
            variables: { objectId: pinId(pin), inviteType: JSON.stringify({ invite_category: 3, invite_object: 1, invite_channel: 12 }) } } };
      }
      more = null;
      request(pin, 'PinResource', 'get', { id: pinId(pin), field_set_key: 'auth_web_main_pin',
        noCache: true, fetch_visual_search_objects: false, get_page_metadata: false,
        add_fields: 'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin' },
        function () { return homeMenu === state; }).then(function (response) {
          if (!response.data || String(response.data.id) !== pinId(pin)) throw new Error('帖子信息未能确认，请重试');
          state.raw = response.data;
        }).catch(function (error) { if (homeMenu === state) state.error = error.message; })
        .finally(function () { if (homeMenu === state) { state.loading = false; notifyHomeMenu(); } });
      return true;
    },
    homeMenuRead: function (session, pin) {
      var state = homeMenu;
      if (!state || state.session !== session || state.pin !== pin || !current(pin)) return null;
      var snapshot = this.moreSnapshot({ session: session, pin: pin, options: [
        { id: 'home-download', label: '下载图片', enabled: !!state.raw },
        { id: 'home-see-more', label: '查看更多', enabled: !!state.raw },
        { id: 'home-see-less', label: '减少推荐', enabled: !!state.raw }
      ] });
      return { session: session, pinUrl: pin, loading: state.loading, busy: !!shares.sending || !!more.busy,
        error: state.error, feedback: shares.feedback || '',
        options: shares.options.map(function (item) { return Object.assign({}, item, { enabled: !!state.raw && !shares.sending && !more.busy }); }),
        actions: [{ id: 'home-save', label: '收藏', enabled: !!state.raw && !shares.sending && !more.busy &&
          typeof this.boardsStart === 'function' }].concat(snapshot.options) };
    },
    homeMenuAction: function (session, pin, id) {
      if (!homeMenu || homeMenu.session !== session || homeMenu.pin !== pin || !current(pin) ||
          homeMenu.loading || homeMenu.error || !more || shares.sending || more.busy) return false;
      return /^home-share:/.test(id) ? this.shareAction(session, id) : this.moreAction(session, pin, id, notifyHomeMenu);
    },
    homeMenuClose: function (session) {
      if (!homeMenu || homeMenu.session !== session) return false;
      homeMenu = null; shares = null; more = null;
      return true;
    },
    shareClose: function () { cancelContacts(shares); shares = null; },
    moreClose: function () { more = null; },
    shareSnapshot: function (snapshot, changed) {
      if(window.PinmonyNativeSharePublishEnabled === true)return snapshot;
      var state = shares;
      if (!state || state.session !== snapshot.session || state.pin !== snapshot.pinUrl) {
        state = shares = { session: snapshot.session, pin: snapshot.pinUrl, changed: changed, token: 0, query: '', items: [], loading: false, feedback: '', contactsError: '', inviteError: '', sending: '', options: [] };
        contacts(state, '');
      }
      state.changed = changed;
      state.options = (snapshot.options || []).concat(snapshot.actions || []).map(function (item) {
        var name = platform(item.label), supported = /^(?:Facebook|Messenger|X|WhatsApp|短信)$/.test(name) || channel(name) === '12';
        return Object.assign({}, item, { label: name, enabled: item.enabled && !state.sending && supported });
      });
      // The system resolves installed share targets; website href is optional, never a reason to disable a recognized app.
      snapshot.options = state.options.filter(function (item) { return (snapshot.options || []).some(function (old) { return old.id === item.id; }); });
      snapshot.actions = state.options.filter(function (item) { return (snapshot.actions || []).some(function (old) { return old.id === item.id; }); });
      snapshot.searchId = 'api-search'; snapshot.searchActive = true; snapshot.searchLabel = '搜索用户'; snapshot.query = state.query;
      snapshot.sendId = ''; snapshot.contacts = state.items.map(function (item) { return { id: 'api-user:' + item.id,
        label: (item.label || item.full_name || item.username) + ' @' + item.username,
        icon: item.send_pin_image || item.image_medium_url || item.image || '', enabled: !state.loading && !state.sending }; });
      snapshot.feedback = state.loading ? '正在加载联系人…' : state.sending ? '正在处理…' : state.feedback;
      snapshot.error = state.contactsError || state.inviteError;
      return snapshot;
    },
    shareSearch: function (session, query) {
      if(window.PinmonyNativeSharePublishEnabled === true)return false;
      if (!shares || shares.session !== session || !current(shares.pin)) return false;
      shares.query = String(query).slice(0, 200); contacts(shares, shares.query.trim()); return true;
    },
    shareRetry: function (session) {
      if(window.PinmonyNativeSharePublishEnabled === true)return false;
      if (!shares || shares.session !== session || !current(shares.pin)) return false;
      var state = shares; contacts(state, state.query.trim());
      if (state.inviteError) invite(state, '10').then(function (result) {
        if (shares === state) { state.invite = result; state.inviteError = ''; updateShare(state); }
      }).catch(function (error) { if (shares === state && error.message !== 'stale') {
        state.inviteError = '分享链接尚未就绪，请重试'; updateShare(state);
      } });
      return true;
    },
    shareAction: function (session, id) {
      if(window.PinmonyNativeSharePublishEnabled === true)return false;
      var state = shares; if (!state || state.session !== session || !current(state.pin) || state.sending) return false;
      var user = state.items.find(function (item) { return 'api-user:' + item.id === id; });
      var option = state.options.find(function (item) { return item.id === id && item.enabled; });
      if (!user && !option) return false;
      state.sending = id; state.feedback = ''; state.inviteError = ''; updateShare(state);
      (async function () {
        try {
          if (user) {
            var p = raw(state.pin), tracking = p && (p.client_tracking_params || p.tracking_params);
            if (!tracking) throw new Error('当前帖子缺少发送参数');
            var response = await request(state.pin, 'ConversationsResource', 'create', { emails: [], user_ids: [String(user.id)],
              source: 'Unknown', client_tracking_params: tracking, pin: pinId(state.pin) }, function () { return shares === state; });
            var message = response.data && response.data.last_message, users = response.data && response.data.users;
            if (!message || !message.id || !message.pin || String(message.pin.id) !== pinId(state.pin) ||
                !Array.isArray(users) || !users.some(function (item) { return String(item.id) === String(user.id); })) throw new Error('未确认发送结果');
            state.feedback = '已发送';
          } else {
            var ch = channel(option.label) || '10', result;
            try { result = await invite(state, ch); }
            catch (error) {
              if (error.message === 'stale' || shares !== state || !current(state.pin)) return;
              state.inviteError = '分享链接尚未就绪，请重试';
              var pin = raw(state.pin);
              if (!pin || String(pin.id) !== pinId(state.pin)) throw error;
              result = { inviteUrl: location.origin + '/pin/' + pin.id + '/', title: pin.title || 'Pinterest Pin' };
              // The validated original Pin URL satisfies this action; invitation failure is not its result.
              state.inviteError = '';
            }
            if (shares !== state || !current(state.pin)) return;
            if (ch === '12') event('copy', state.pin, result.inviteUrl, session, 'share');
            else event('systemShare', state.pin, result.inviteUrl, session, 'share', {
              platform: option.label, title: result.title, targetUrl: destination(option, result) });
          }
        } catch (error) { if (shares === state) state.feedback = error.message === 'stale' || state.inviteError ? '' : error.message; }
        finally { if (shares === state) { state.sending = ''; updateShare(state); } }
      })(); return true;
    },
    detailActions: function (pin, actions, changed) {
      var p = raw(pin), state = p && (p.reaction_data || p), selected = reaction && reaction.pin === pin ? reaction.selected : state && typeof state.reaction_by_me === 'number' ? state.reaction_by_me !== 0 : null;
      var counts = state && state.reaction_counts || p && p.reaction_counts;
      // These three detail actions are API-owned. Do not carry a matching
      // website button, selected state, label, or count into the native UI.
      actions = actions.filter(function (item) {
        return item.id === 'api-source' ||
          item.kind !== 'like' && item.kind !== 'comment' && item.kind !== 'save' &&
          item.kind !== 'more' && item.kind !== 'share' && item.kind !== 'source';
      });
      // Native API entry points do not depend on the website rendering a matching button.
      if (p && current(pin)) {
        actions.unshift({ id: 'api-like', kind: 'like', label: '点赞', countText: '', enabled: true, selected: false });
        actions.push({ id: 'api-comment', kind: 'comment', label: '评论', countText: '',
          enabled: !!aggregate(pin), selected: false });
        if (window.PinmonyPostExtensionsEnabled && !actions.some(function (item) { return item.kind === 'save'; }))
          actions.push({ id: 'api-save', kind: 'save', label: '收藏', countText: '', enabled: true, selected: false });
        if (!actions.some(function (item) { return item.kind === 'share'; }))
          actions.push({ id: 'api-share', kind: 'share', label: '分享', countText: '', enabled: true, selected: false });
        if (!actions.some(function (item) { return item.kind === 'more'; }))
          actions.push({ id: 'api-more', kind: 'more', label: '更多选项', countText: '', enabled: true, selected: false });
      }
      return actions.map(function (item) {
        if (item.kind === 'save' && window.PinmonyPostExtensionsEnabled && window.PinmonyPostApi.savedRead) {
          var saved = window.PinmonyPostApi.savedRead(pin);
          var isSaved = saved ? !!saved.id : item.selected;
          return Object.assign({}, item, { label: isSaved ? '已收藏' : '收藏',
            selected: !!isSaved, enabled: !!p && current(pin) });
        }
        if (item.kind === 'comment') {
          var count = p && p.aggregated_pin_data && p.aggregated_pin_data.comment_count;
          if (typeof count !== 'number') count = p && p.comment_count;
          return Object.assign({}, item, { countText: typeof count === 'number' && isFinite(count) && count >= 0 && Math.floor(count) === count ? (count > 0 ? String(count) : '') : item.countText === '0' ? '' : item.countText });
        }
        if (item.kind !== 'like') return item;
        return Object.assign({}, item, { selected: selected === null ? false : selected, enabled: item.enabled && selected === false && !likeBusy,
          countText: reaction && reaction.pin === pin && reaction.before === p ? '' :
            counts && typeof counts['1'] === 'number' && isFinite(counts['1']) && counts['1'] >= 0 &&
              Math.floor(counts['1']) === counts['1'] ? String(counts['1']) : '' });
      });
    },
    like: function (pin, changed, failed) {
      if(window.PinmonyNativePostOperationsEnabled === true)return false;
      var p = raw(pin), state = p && (p.reaction_data || p);
      if (!current(pin) || likeBusy || !p || !p.tracking_params ||
          reaction && reaction.pin === pin && reaction.selected || !state || state.reaction_by_me !== 0) return false;
      likeBusy = true; var token = ++nextToken;
      request(pin, 'ApiResource', 'create', { url: '/v3/pins/' + pinId(pin) + '/react/',
        data: { client_tracking_params: p.tracking_params, reaction_type: 1 } }, function () { return nextToken === token; })
        .then(function (result) {
          if (!result.data || String(result.data.id) !== pinId(pin)) throw new Error('未确认点赞结果');
          reaction = { pin: pin, selected: true, before: p };
          if (window.PinmonyDetailApi.reload) window.PinmonyDetailApi.reload();
        })
        .catch(function (error) { if (current(pin) && nextToken === token) failed(error.message); })
        .finally(function () { if (nextToken === token && current(pin)) { likeBusy = false; changed(); } });
      changed(); return true;
    },
    moreSnapshot: function (snapshot) {
      more = more && more.session === snapshot.session && more.pin === snapshot.pin ? more : { session: snapshot.session, pin: snapshot.pin, busy: false };
      more.options = snapshot.options.filter(function (item) { return !/举报|report|在应用中打开|open in app|拼贴|collage/i.test(item.label); })
        .map(function (item) { var download = /下载|download/i.test(item.label), feedback = /^(?:查看更多|查看更少|减少推荐|see more|see less)$/i.test(item.label), share = /^分享(?:链接)?$|^share$/i.test(item.label), help = /详细了解.*AI|learn more.*AI/i.test(item.label), edit = /编辑.*Pin|edit pin/i.test(item.label) && !!window.PinmonyEditApiEnabled;
          return Object.assign({}, item, { enabled: item.enabled && !more.busy && (download && !!window.PinmonyPostApi.downloadUrl(snapshot.pin) || feedback && !!feedbackData(snapshot.pin) || share && !!current(snapshot.pin) || help || edit),
            subtitle: download || feedback || help || edit || share ? item.subtitle : '此操作接口尚未确认' }); });
      snapshot.options = more.options; return snapshot;
    },
    detailMoreOpen: function (session, pin) {
      if(window.PinmonyNativePinMenusEnabled === true)return false;
      if (!Number.isInteger(session) || session < 1 || !pinId(pin) || !current(pin) || !raw(pin)) return false;
      more = { session: session, pin: pin, busy: false };
      return true;
    },
    detailMoreRead: function (session, pin) {
      if (!more || more.session !== session || more.pin !== pin || !current(pin)) return null;
      var p = raw(pin), options = [];
      if (this.downloadUrl(pin)) options.push({ id: 'detail-download', label: '下载图片', enabled: true });
      if (feedbackData(pin)) {
        options.push({ id: 'detail-see-more', label: '查看更多', enabled: true });
        options.push({ id: 'detail-see-less', label: '减少推荐', enabled: true });
        options.push({ id: 'detail-share', label: '分享链接', enabled: true });
      }
      if (p && (Array.isArray(p.ai_disclosures) && p.ai_disclosures.indexOf(1) >= 0 ||
          Array.isArray(p.gen_ai_topics) && p.gen_ai_topics.some(function (topic) {
            return topic && typeof topic.name === 'string' && !!topic.name.trim();
          })))
        options.push({ id: 'detail-ai-help', label: '详细了解 AI 标签', enabled: true });
      var userId = currentUserId();
      if (window.PinmonyEditApiEnabled && p && p.pinner && userId && String(p.pinner.id) === userId) options.unshift({ id: 'detail-edit', label: '编辑 Pin 图', enabled: true });
      var snapshot = this.moreSnapshot({ session: session, pin: pin, options: options });
      return { session: session, pin: pin, pinUrl: pin, loading: false, busy: !!more.busy, error: '', options: snapshot.options || [] };
    },
    detailMoreClose: function (session, pin) {
      if (!more || more.session !== session || more.pin !== pin) return false;
      more = null; return true;
    },
    moreAction: function (session, pin, id, changed) {
      if(window.PinmonyNativePinMenusEnabled === true)return false;
      var thisApi = this;
      var state = more, item = state && state.options.find(function (option) { return option.id === id && option.enabled; });
      if (!item || state.session !== session || state.pin !== pin || !current(pin) || state.busy) return false;
      if (/编辑.*Pin|edit pin/i.test(item.label) && window.PinmonyEditApiEnabled) { event('editOpen', pin, '', session, 'more'); return true; }
      if (/^分享(?:链接)?$|^share$/i.test(item.label)) { event('share', pin, pin, session, 'more'); return true; }
      if (/下载|download/i.test(item.label)) { event('download', pin, this.downloadUrl(pin), session, 'more'); return true; }
      if (/详细了解.*AI|learn more.*AI/i.test(item.label)) { event('help', pin, 'https://help.pinterest.com/en/article/gen-ai-labels', session, 'more'); return true; }
      var less = /查看更少|减少推荐|see less/i.test(item.label), data = feedbackData(pin); if (!data) return false;
      if (less) { delete data.source; delete data.through_id; delete data.rec_reason_type; data.feedback_type = 10; }
      else if (typeof data.source !== 'number' && !homeMenu) data.source = 5;
      state.busy = true; changed();
      request(pin, 'ApiResource', 'update', { url: less ? '/v3/pfy/' + pinId(pin) + '/feedback/' : '/v3/pin/' + pinId(pin) + '/feedback/see_more/', data: data },
        function () { return more === state; }).then(function (result) {
          var endpoint = less ? 'v3_provide_pfy_pin_feedback' : 'v3_pin_see_more_user_feedback';
          if (result.code !== 0 || result.endpoint_name !== endpoint || !result.data || String(result.data.id) !== pinId(pin))
            throw new Error('未能确认本次反馈结果，请重试');
          event('message', pin, less ? '已提交查看更少反馈' : '已提交查看更多反馈', session, 'more');
          if (!less && window.PinmonyPostExtensionsEnabled && thisApi.feedbackRecord) {
            thisApi.feedbackRecord(pin, session); event('feedbackReady', pin, '', session, 'detail');
          }
        })
        .catch(function (error) { if (more === state) event('message', pin, error.message, session, 'more'); })
        .finally(function () { if (more === state) { state.busy = false; changed(); } }); return true;
    },
    downloadUrl: function (pin) {
      var p = raw(pin), sizes = p && p.images || {}, image = sizes.orig || sizes['736x'] || sizes['474x'];
      return current(pin) && image && /^https:\\/\\/i\\.pinimg\\.com\\//.test(image.url || '') ? image.url : '';
    },
    commentsStart: function (pin) {
      var id = aggregate(pin), state = comments = { pin: pin, token: ++nextToken, loading: !!id, error: id ? '' : '当前帖子缺少评论聚合标识', items: [], ended: true };
      if (!id) return;
      request(pin, 'UnifiedCommentsResource', 'get', { aggregated_pin_id: id, comment_featured_ids: [], page_size: 25,
        redux_normalize_feed: true, is_reversed: false }, function () { return comments === state; })
        .then(function (resource) { if (!Array.isArray(resource.data)) throw new Error('评论返回格式无效');
          state.items = resource.data.map(function (item) { var user = item.user || {}; return { id: String(item.id), text: item.text || '',
            profileUrl: /^[a-zA-Z0-9_]+$/.test(user.username || '') ? location.origin + '/' + user.username + '/' : '', name: user.full_name || user.username || '', avatar: user.image_medium_url || '', createdAt: item.created_at || '' }; }); })
        .catch(function (error) { if (comments === state) state.error = error.message; })
        .finally(function () { if (comments === state) state.loading = false; });
    },
    commentsRead: function (pin) { return current(pin) && comments && comments.pin === pin ? comments : null; },
    commentsClose: function () { comments = null; }
  };
})();`;
