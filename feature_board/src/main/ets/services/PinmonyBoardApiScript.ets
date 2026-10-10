// Manual shutdown only; the native-login shell never exposes a business website fallback.
export const PIN_BOARD_API_ENABLED: boolean = true;
export const PIN_BOARD_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var key = '', generation = 0, session = 0, board = null, pins = [], ready = false;
  var boardBusy = false, feedBusy = false, attempted = false, error = '', bookmark = '', ended = false, aborts = [];
  var lastMessage = '';
  var refreshing = false;
  var viewerId = '';
  var flowEpoch = 0, targetBookmark = '', sourcePins = {}, pendingSave = {};
  function emptyFlow() { return { phase: '', loading: false, busy: false, uncertain: false, error: '',
    description: '', privacy: 'public', recommend: false, invites: false, requests: false,
    pins: [], targets: [], saved: [], hasMore: false }; }
  var flow = emptyFlow();
  var nextPage = '';
  var revision = 0;
  var recoveryRequired = false;
  var selectedIds = [];
  function route() {
    var parts = location.pathname.split('/').filter(Boolean);
    if (parts.length !== 2 || /^_|^(?:pin|users|search|ideas|today|settings|messages|inbox|login|signup|business|explore)$/i.test(parts[0]) ||
        /^_|^(?:followers|following)$/i.test(parts[1])) return '';
    return location.origin + '/' + parts[0] + '/' + parts[1] + '/';
  }
  function reset() {
    flowEpoch++; flow = emptyFlow(); targetBookmark = ''; sourcePins = {}; pendingSave = {};
    nextPage = '';
    revision = 0;
    recoveryRequired = false;
    selectedIds = [];
    generation++; aborts.forEach(function (abort) { abort.abort(); }); aborts = [];
    key = ''; board = null; pins = []; ready = false; attempted = false; viewerId = '';
    boardBusy = false; feedBusy = false; error = ''; bookmark = ''; ended = false; lastMessage = '';
    refreshing = false;
    session = Math.max(Date.now(), session + 1);
  }
  function clean(value) { return typeof value === 'string' ? value.trim().slice(0, 300) : ''; }
  function collection() { return new URL(key).pathname.split('/').filter(Boolean)[1] === 'pins'; }
  function image(url) { return typeof url === 'string' && /^https:\\/\\//i.test(url) ? url : ''; }
  function notify() {
    if (!key || route() !== key || !window.PinmonyShareBridge || !window.PinmonyShareBridge.boardState) return;
    var owner = board && board.owner || {};
    var own = board && (board.isOwn === true || viewerId && String(owner.id || '') === viewerId);
    var showOwner = board && !own && (board.isOwn === false || viewerId && String(owner.id || '') !== '' &&
      String(owner.id) !== viewerId);
    var value = JSON.stringify({ kind: 'state', session: session, pageKey: key,
      boardId: board ? String(board.id) : '', title: board ? clean(board.name) : '',
      pinCount: board && typeof board.pin_count === 'number' && isFinite(board.pin_count) && board.pin_count >= 0 ? board.pin_count + ' 张 Pin 图' : '',
      privacy: !collection() && board && ['public', 'secret'].indexOf(board.privacy) >= 0 ? board.privacy : undefined,
      ownerUrl: /^[a-zA-Z0-9_]+$/.test(owner.username || '') ? location.origin + '/' + owner.username + '/' : '',
      ownerName: showOwner ? clean(owner.full_name || owner.username) : '', ownerAvatar: showOwner ? image(owner.image_medium_url) : '',
      loading: !ready && (boardBusy || feedBusy || !attempted), loadingMore: ready && feedBusy && !refreshing,
      refreshing: refreshing,
      ready: ready, error: error, hasMore: !ended, pins: pins, flow: flow,
      memberAvatar: image(owner.image_medium_url || owner.image_small_url), nextPage: nextPage, revision: revision,
      editable: !!own && !collection() && !recoveryRequired && !boardBusy });
    if (value === lastMessage) return;
    lastMessage = value; window.PinmonyShareBridge.boardState(value);
  }
  function validBoard(value) {
    if (!value || value.type !== 'board' || !/^\\d+$/.test(String(value.id || ''))) return false;
    try { return new URL(value.url, location.origin).href === key; } catch (_) { return false; }
  }
  function mapPin(pin) {
    if (!pin || pin.type !== 'pin' || !/^\\d+$/.test(String(pin.id || ''))) return null;
    var sizes = pin.images || {}, art = null;
    ['736x', '474x', '236x', 'orig'].some(function (size) {
      var candidate = sizes[size];
      if (!candidate || !image(candidate.url) || !(candidate.width > 0) || !(candidate.height > 0)) return false;
      art = candidate; return true;
    });
    if (!art) return null;
    return { id: String(pin.id), pinUrl: location.origin + '/pin/' + pin.id + '/', imageUrl: art.url,
      imageWidth: art.width, imageHeight: art.height, title: clean(pin.grid_title || pin.title) };
  }
  function merge(data, next, append) {
    if (!Array.isArray(data)) throw new Error('invalid-feed');
    var mapped = [], pinItems = 0;
    data.forEach(function (item) {
      if (item && item.type === 'story') return; // Website end/recommendation modules are not saved Pins.
      pinItems++;
      var card = mapPin(item);
      if (!card) throw new Error('unsupported-pin');
      if (!collection() && item.board && String(item.board.id) !== String(board.id)) throw new Error('wrong-board-pin');
      mapped.push(card);
    });
    var previous = bookmark, merged = append ? pins.slice() : [];
    mapped.forEach(function (card) { if (!merged.some(function (old) { return old.id === card.id; })) merged.push(card); });
    pins = merged; ready = true;
    bookmark = typeof next === 'string' ? next : '';
    ended = !bookmark || bookmark === '-end-' || (append && bookmark === previous);
  }
  async function request(name, options, token, page, action) {
    var abort = new AbortController(); aborts.push(abort);
    var timer = setTimeout(function () { abort.abort(); }, 15000);
    try {
      var source = new URL(page).pathname, handler = 'www/index.js';
      if (name === 'BoardContentRecommendationResource' || name === 'RepinResource') {
        source += '_tools/more-ideas/?ideas_referrer=23'; handler = 'www/[username]/[slug]/_tools/more-ideas.js';
      } else if (name === 'BoardsResource' || name === 'ApiResource' && options.url === '/v3/pins/bulk/move/') {
        source = '/board/' + board.id + '/organize/repin/'; handler = 'www/board/[id]/organize.js';
      } else if (name === 'BoardResource' && (options.field_set_key === 'edit' || action === 'update' || action === 'delete')) {
        source = '/board/' + board.id + '/edit/'; handler = 'www/board/[id]/edit.js';
      } else if (name === 'ApiResource' && action === 'create') { handler = 'www/[username]/[slug].js'; }
      var encoded = 'source_url=' + encodeURIComponent(source) +
        '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} }));
      var response = await fetch('/resource/' + name + '/' + (action || 'get') + '/' +
        (action ? '' : '?' + encoded + '&_=' + Date.now()),
        { method: action ? 'POST' : 'GET', body: action ? encoded : undefined,
          credentials: 'same-origin', signal: abort.signal, headers: { Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': handler } });
      if (!response.ok) throw new Error('http-error');
      var payload = await response.json();
      if (token !== generation || page !== key || route() !== page) return null;
      if (!payload.resource_response || payload.resource_response.status !== 'success') throw new Error('invalid-response');
      var viewer = payload.client_context && payload.client_context.user;
      if (viewer && /^\\d+$/.test(String(viewer.id || ''))) viewerId = String(viewer.id);
      return payload;
    } finally {
      clearTimeout(timer); aborts = aborts.filter(function (item) { return item !== abort; });
    }
  }
  async function loadFeed(append) {
    if (!board || feedBusy || append && ended) return;
    var token = generation, page = key;
    feedBusy = true; error = ''; notify();
    try {
      var options = { add_vase: false, board_id: String(board.id), field_set_key: 'react_grid_pin',
        filter_section_pins: true, is_react: true, prepend: false, page_size: 15, redux_normalize_feed: true, gated: false };
      if (collection()) options = { add_vase: false, field_set_key: 'mobile_grid_item',
        is_own_profile_pins: board.isOwn, username: board.owner.username };
      if (append && bookmark) options.bookmarks = [bookmark];
      var payload = await request(collection() ? 'UserPinsResource' : 'BoardFeedResource', options, token, page);
      if (!payload) return;
      var next = payload.resource_response.bookmark || (payload.resource && payload.resource.options && payload.resource.options.bookmarks || [])[0];
      merge(payload.resource_response.data, next, append);
    } catch (_) {
      if (token === generation && route() === page) error = append ? '更多 Pin 图加载失败，请重试' : '图板内容读取失败，请重试';
    } finally {
      if (token === generation && page === key) { feedBusy = false; notify(); }
    }
  }
  async function loadBoard(force) {
    var token = generation, page = key;
    attempted = true; boardBusy = true; error = ''; notify();
    try {
      if (collection()) {
        var username = decodeURIComponent(new URL(page).pathname.split('/')[1]);
        var userPayload = await request('UserResource', { username: username }, token, page);
        if (!userPayload) return;
        var user = userPayload.resource_response.data;
        var viewer = userPayload.client_context && userPayload.client_context.user;
        if (!user || user.type !== 'user' || clean(user.username).toLowerCase() !== username.toLowerCase() ||
            !/^\\d+$/.test(String(user.id || '')) || !viewer || !/^\\d+$/.test(String(viewer.id || ''))) {
          throw new Error('unknown-collection-owner');
        }
        board = { id: String(user.id), name: '所有 Pin 图', pin_count: user.pin_count, owner: user,
          isOwn: String(viewer.id) === String(user.id) };
        await loadFeed(false);
        return;
      }
      var parts = new URL(page).pathname.split('/').filter(Boolean);
      var payload = await request('BoardResource', { field_set_key: 'profile_grid_item', is_mobile_fork: true,
        username: decodeURIComponent(parts[0]), slug: decodeURIComponent(parts[1]) }, token, page);
      if (!payload) return;
      var refreshedBoard = payload.resource_response.data;
      if (!validBoard(refreshedBoard)) throw new Error('invalid-board');
      board = refreshedBoard;
      await loadFeed(false);
      if (!error) recoveryRequired = false;
    } catch (_) {
      if (token === generation && route() === page) error = '图板资料读取失败，请重试';
    } finally {
      if (token === generation && page === key) { boardBusy = false; refreshing = false; notify(); }
    }
  }
  function sync() {
    if (window.PinmonyBoardApiEnabled !== true) { if (key) reset(); return; }
    var page = route();
    if (page !== key) { reset(); key = page; }
    if (!key) return;
    if (!attempted) loadBoard();
    notify();
  }
  function digits(value) { return typeof value === 'string' && value.length > 0 && value.length <= 30 &&
    value.split('').every(function (c) { return c >= '0' && c <= '9'; }); }
  function ownsBoard() { return board && !collection() && !recoveryRequired && !boardBusy && viewerId && String((board.owner || {}).id) === viewerId; }
  async function readFlow(phase, append) {
    if (!board || flow.loading || flow.busy || append && !flow.hasMore) return;
    var token = generation, page = key, epoch = ++flowEpoch;
    flow.phase = phase; flow.loading = true; flow.error = ''; notify();
    try {
      var payload;
      if (phase === 'ideas') {
        payload = await request('BoardContentRecommendationResource', { id: String(board.id), type: 'board', __track__referrer: 23 }, token, page);
      } else if (phase === 'targets') {
        var options = { privacy_filter: 'all', sort: 'custom', field_set_key: 'profile_grid_item',
          filter_stories: true, username: board.owner.username, page_size: 25, group_by: 'mix_public_private',
          include_archived: true, filter_all_pins: false };
        if (append && targetBookmark) options.bookmarks = [targetBookmark];
        payload = await request('BoardsResource', options, token, page);
      } else {
        payload = await request('BoardResource', { board_id: String(board.id), field_set_key: 'edit' }, token, page);
      }
      if (!payload || token !== generation || epoch !== flowEpoch || route() !== page) return;
      var data = payload.resource_response.data;
      if (phase === 'ideas') {
        if (!Array.isArray(data)) throw new Error('invalid-ideas');
        var mapped = [];
        data.forEach(function (pin) { var card = mapPin(pin); if (!card) return;
          if (!mapped.some(function (old) { return old.id === card.id; })) mapped.push(card);
          sourcePins[card.id] = pin; });
        flow.pins = mapped.slice(0, 500);
      } else if (phase === 'targets') {
        if (!Array.isArray(data)) throw new Error('invalid-targets');
        var targets = append ? flow.targets.slice() : [];
        data.forEach(function (item) { if (!item || item.type !== 'board' || !digits(String(item.id))) return;
          if (!targets.some(function (old) { return old.id === String(item.id); })) targets.push({ id: String(item.id),
            title: clean(item.name), imageUrl: image(item.image_cover_url),
            enabled: String(item.id) !== String(board.id) && !item.archived_by_me_at && !item.archived_by_me &&
              (Array.isArray(item.access) ? item.access.indexOf('write') >= 0 :
                typeof item.access === 'string' && item.access.split(' ').indexOf('write') >= 0) }); });
        flow.targets = targets.slice(0, 500);
        var next = payload.resource_response.bookmark || (payload.resource && payload.resource.options && payload.resource.options.bookmarks || [])[0];
        flow.hasMore = targets.length < 500 && !!next && next !== '-end-' && next !== targetBookmark;
        targetBookmark = typeof next === 'string' ? next : '';
      } else {
        if (!validBoard(data) || String(data.id) !== String(board.id)) throw new Error('wrong-board');
        board = data;
        flow.description = typeof data.description === 'string' ? data.description.slice(0, 500) : ''; flow.privacy = data.privacy;
        flow.recommend = data.allow_homefeed_recommendations === true;
        flow.invites = data.collaborator_invites_enabled === true;
        flow.requests = data.collaborator_requests_enabled === true;
      }
    } catch (_) {
      if (epoch === flowEpoch && token === generation) flow.error = '读取失败，请重试';
    } finally { if (epoch === flowEpoch && token === generation) { flow.loading = false; notify(); } }
  }
  async function writeFlow(action, value) {
    if (!ownsBoard() || flow.busy || flow.loading || flow.uncertain) return;
    var name, options, endpoint, verb;
    if (action === 'move') {
      var target = flow.targets.filter(function (item) { return item.id === value && item.enabled; })[0];
      if (flow.phase !== 'targets' || !target || !selectedIds.length || selectedIds.length > 500 ||
          !selectedIds.every(function (id) { return pins.some(function (pin) { return pin.id === id; }); })) return;
      name = 'ApiResource'; verb = 'create'; endpoint = 'v3_move_pins';
      options = { url: '/v3/pins/bulk/move/', data: { board_id: target.id, pin_ids: selectedIds.slice() } };
    } else if (action === 'save') {
      if (flow.phase !== 'ideas' || !sourcePins[value] || flow.saved.indexOf(value) >= 0 || pendingSave[value]) return;
      name = 'RepinResource'; verb = 'create'; endpoint = 'v3_repin_handler';
      options = { pin_id: value, board_id: String(board.id), user_id: viewerId };
      var tracking = sourcePins[value].tracking_params;
      if (typeof tracking === 'string') options.clientTrackingParams = tracking;
      pendingSave[value] = true;
    } else if (action === 'archive') {
      if (flow.phase !== 'archive') return;
      name = 'ApiResource'; verb = 'create'; endpoint = 'v3_archive_board';
      options = { url: '/v3/boards/' + board.id + '/archive/' };
    } else if (action === 'delete') {
      if (flow.phase !== 'edit') return;
      name = 'BoardResource'; verb = 'delete'; endpoint = 'v3_delete_board';
      options = { board_id: String(board.id) };
    } else if (action === 'editSave') {
      if (flow.phase !== 'edit' || !value || typeof value.name !== 'string' || !clean(value.name) ||
          typeof value.description !== 'string' || ['public', 'secret'].indexOf(value.privacy) < 0) return;
      name = 'BoardResource'; verb = 'update'; endpoint = 'v3_edit_board';
      options = { board_id: String(board.id), name: clean(value.name), description: value.description.slice(0, 500),
        privacy: value.privacy, allow_homefeed_recommendations: value.recommend === true,
        collaborator_invites_enabled: value.invites === true, collaborator_requests_enabled: value.requests === true,
        sensitivity: null };
    } else return;
    var token = generation, page = key, epoch = flowEpoch, destination = String(board.id);
    flow.busy = true; flow.error = ''; notify();
    try {
      var payload = await request(name, options, token, page, verb);
      if (!payload || epoch !== flowEpoch || token !== generation) return;
      var response = payload.resource_response, data = response.data;
      if (response.code !== 0 || response.endpoint_name !== endpoint) throw new Error('unconfirmed-write');
      if (action === 'delete') {
        if (data !== null) throw new Error('unconfirmed-delete');
        pins = []; ended = true; flow.phase = 'deleted';
        aborts.forEach(function (abort) { abort.abort(); }); aborts = [];
      } else if (action === 'move') {
        if (data !== null) throw new Error('unconfirmed-move');
        var moved = options.data.pin_ids;
        pins = pins.filter(function (pin) { return moved.indexOf(pin.id) < 0; });
        if (typeof board.pin_count === 'number') board.pin_count = Math.max(0, board.pin_count - moved.length);
        selectedIds = []; flowEpoch++; flow = emptyFlow(); targetBookmark = '';
        // Invalidate in-flight feed reads and fetch the source again after the confirmed mutation.
        generation++; aborts.forEach(function (abort) { abort.abort(); }); aborts = [];
        feedBusy = false;
      } else if (action === 'save') {
        if (!data || !digits(String(data.id)) || String((data.board || {}).id) !== destination ||
            String((data.pinner || {}).id) !== viewerId || data.is_repin !== true) throw new Error('wrong-save');
        flow.saved.push(value); if (typeof board.pin_count === 'number') board.pin_count++;
        var savedCard = mapPin(data);
        if (savedCard && !pins.some(function (pin) { return pin.id === savedCard.id; })) pins.unshift(savedCard);
      } else if (action === 'editSave') {
        if (!data || data.type !== 'board' || String(data.id) !== destination ||
            String((data.owner || {}).id) !== viewerId || data.name !== options.name || data.privacy !== options.privacy)
          throw new Error('wrong-edit');
        var updatedUrl = new URL(data.url, location.origin);
        var parts = updatedUrl.pathname.split('/').filter(Boolean);
        if (updatedUrl.origin !== location.origin || parts.length !== 2 ||
            decodeURIComponent(parts[0]).toLowerCase() !== String(board.owner.username).toLowerCase() || parts[1].charAt(0) === '_')
          throw new Error('wrong-edit-route');
        nextPage = updatedUrl.href !== page ? updatedUrl.href : '';
        board = data; flow.phase = '';
      } else { flow.phase = 'archived'; }
      revision++;
      if (action === 'move') { notify(); loadBoard(true); }
    } catch (_) {
      if (epoch === flowEpoch && token === generation) {
        flow.uncertain = true; flow.error = '操作结果未确认，请关闭后刷新核对；不会重复提交';
        recoveryRequired = true;
        revision++;
      }
    } finally { if (epoch === flowEpoch && token === generation) { flow.busy = false; notify(); } }
  }
  window.PinmonyBoardApi = {
    flow: function (requestedSession, page, encoded) {
      if (requestedSession !== session || page !== key || route() !== key || !board) return false;
      var value; try { value = JSON.parse(encoded); } catch (_) { return false; }
      if (!value || typeof value.action !== 'string' || flow.busy) return false;
      if (value.action === 'close') {
        var reload = flow.uncertain || flow.phase === 'archived';
        flowEpoch++; flow = emptyFlow(); targetBookmark = ''; sourcePins = {}; pendingSave = {}; selectedIds = []; notify();
        if (reload) { generation++; loadBoard(true); }
      } else if (value.action === 'ideas' && ownsBoard()) readFlow('ideas', false);
      else if (value.action === 'select' && ownsBoard()) { flowEpoch++; flow.phase = 'select'; flow.loading = false; flow.error = ''; notify(); }
      else if (value.action === 'targets' && ownsBoard()) {
        if (!Array.isArray(value.value) || !value.value.length || value.value.length > 500 ||
            !value.value.every(function (id, index, all) { return digits(id) && all.indexOf(id) === index &&
              pins.some(function (pin) { return pin.id === id; }); })) return false;
        selectedIds = value.value.slice(); targetBookmark = ''; readFlow('targets', false);
      }
      else if (value.action === 'targetsMore' && flow.phase === 'targets') readFlow('targets', true);
      else if (value.action === 'edit' && ownsBoard()) readFlow('edit', false);
      else if (value.action === 'archiveConfirm' && ownsBoard()) { flow.phase = 'archive'; notify(); }
      else if (value.action === 'retry' && !flow.uncertain) readFlow(flow.phase, flow.phase === 'targets' && !!targetBookmark);
      else writeFlow(value.action, value.value);
      return true;
    },
    refresh: function (requestedSession, page) {
      if (requestedSession !== session || page !== key || route() !== key || refreshing || boardBusy || flow.busy) return false;
      generation++; aborts.forEach(function (abort) { abort.abort(); }); aborts = [];
      feedBusy = false; refreshing = true;
      loadBoard(true); return true;
    },
    more: function (requestedSession, page) {
      if (requestedSession !== session || page !== key || route() !== key || error) return false;
      loadFeed(true); return true;
    },
    retry: function (requestedSession, page) {
      if (requestedSession !== session || page !== key || route() !== key || boardBusy || feedBusy) return false;
      if (!board || recoveryRequired) loadBoard(true); else loadFeed(ready); return true;
    },
    open: function (requestedSession, page, id) {
      if (requestedSession !== session || page !== key || route() !== key) return false;
      var card = pins.filter(function (pin) { return pin.id === id; })[0];
      if (!card) return false;
      location.href = card.pinUrl; return true;
    }
  };
  function start() { sync(); window.addEventListener('popstate', sync); window.setInterval(sync, 600); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();`;
