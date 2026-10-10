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
  var cancelPinState = null;
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
    var member = board && board.collaborated_by_me === true;
    var avatars = board && board.is_collaborative === true ? [owner].concat(board.collaborating_users || []).filter(function (u, i, all) { return u && all.findIndex(function (v) { return v && String(v.id) === String(u.id); }) === i; }).slice(0, 6).map(function (u) { return image(u.image_medium_url || u.image_small_url); }).filter(Boolean) : [];
    var members = board && board.is_collaborative === true ? [owner].concat(board.collaborating_users || []).filter(function (u, i, all) { return u && digits(String(u.id)) && all.findIndex(function (v) { return v && String(v.id) === String(u.id); }) === i; }) : [];
    var peer = members.length === 2 && members.some(function (u) { return String(u.id) === viewerId; }) ? members.find(function (u) { return String(u.id) !== viewerId; }) : null;
    var showOwner = board && !member && !own && (board.isOwn === false || viewerId && String(owner.id || '') !== '' &&
      String(owner.id) !== viewerId);
    var value = JSON.stringify({ kind: 'state', session: session, pageKey: key,
      boardId: board ? String(board.id) : '', title: board ? clean(board.name) : '',
      pinCount: board && typeof board.pin_count === 'number' && isFinite(board.pin_count) && board.pin_count >= 0 ? board.pin_count + ' 张 Pin 图' : '',
      featured: !!(board && board.featured_board_metadata),
      subtitle: board && board.featured_board_metadata ? clean(board.featured_board_metadata.board_subtitle) : '',
      description: board && typeof board.description === 'string' ? board.description.slice(0, 2000) : '',
      headerImage: board && board.header ? image(board.header.large_image_url || board.header.small_image_url) : '',
      privacy: !collection() && board && ['public', 'secret'].indexOf(board.privacy) >= 0 ? board.privacy : undefined,
      ownerUrl: /^[a-zA-Z0-9_]+$/.test(owner.username || '') ? location.origin + '/' + owner.username + '/' : '',
      ownerName: showOwner ? clean(owner.full_name || owner.username) : '', ownerAvatar: showOwner ? image(owner.image_medium_url) : '',
      loading: !ready && (boardBusy || feedBusy || !attempted), loadingMore: ready && feedBusy && !refreshing,
      refreshing: refreshing,
      ready: ready, error: error, hasMore: !ended, pins: pins, flow: flow,
      chatMemberCount: Math.max(members.length, board && typeof board.collaborator_count === 'number' ? board.collaborator_count + 1 : 0),
      chatPeer: peer ? { id: String(peer.id), name: clean(peer.full_name || peer.username), avatar: image(peer.image_medium_url || peer.image_small_url), username: clean(peer.username) } : undefined,
      collaborator: !!member, canContribute: !!contributes(), collaboratorAvatars: avatars,
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
  function participates() { return ownsBoard() || board && !collection() && !recoveryRequired && !boardBusy && viewerId && board.collaborated_by_me === true; }
  function contributes() { return ownsBoard() || board && !collection() && !recoveryRequired && !boardBusy && viewerId && board.collaborated_by_me === true && Array.isArray(board.access) && board.access.indexOf('write') >= 0; }
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
        if (!data.owner || String(data.owner.id) !== String((board.owner || {}).id)) throw new Error('wrong-owner');
        if (typeof data.collaborated_by_me !== 'boolean') data.collaborated_by_me = board.collaborated_by_me;
        if (!Array.isArray(data.collaborating_users)) data.collaborating_users = board.collaborating_users;
        if (typeof data.is_collaborative !== 'boolean') data.is_collaborative = board.is_collaborative;
        if (!Array.isArray(data.access)) data.access = board.access;
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
    if (!(action === 'move' || action === 'save' ? contributes() : action === 'archive' ? participates() : action === 'leave' || action === 'unfollow' ? participates() && !ownsBoard() : ownsBoard()) || flow.busy || flow.loading || flow.uncertain) return;
    var name, options, endpoint, verb;
    if (action === 'unfollow') {
      if (flow.phase || board.collaborated_by_me !== true || ownsBoard() || board.followed_by_me === false) return;
      name = 'ApiResource'; verb = 'delete'; endpoint = 'v3_unfollow_board';
      options = { url: '/v3/boards/' + board.id + '/follow/' };
    } else if (action === 'leave') {
      if (flow.phase !== 'edit' || board.collaborated_by_me !== true || ownsBoard()) return;
      name = 'ApiResource'; verb = 'delete'; endpoint = 'v3_remove_board_collaborators';
      options = { url: '/v3/boards/' + board.id + '/collaborators/' + viewerId + '/', data: {} };
    } else if (action === 'move') {
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
      if (action === 'unfollow') {
        if (data !== null) throw new Error('unconfirmed-unfollow');
        board.followed_by_me = false; flow.phase = 'unfollowed';
      } else if (action === 'leave') {
        if (!data || data.type !== 'board' || String(data.id) !== destination || data.collaborated_by_me !== false) throw new Error('unconfirmed-leave');
        board.collaborated_by_me = false; flow.phase = 'left';
      } else if (action === 'delete') {
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
  var collaborators = null;
  function collabCurrent(state) { return collaborators === state && state.page === key && route() === key && state.generation === generation; }
  function collabUser(user, status) {
    if (!user || !digits(String(user.id))) throw new Error('invalid-user');
    return { id: String(user.id), name: clean(user.full_name || user.username), username: clean(user.username),
      avatar: image(user.image_medium_url || user.image_small_url) ? user.image_medium_url || user.image_small_url : '', status: status || '' };
  }
  async function collabLoad(state) {
    state.loading = true; state.error = '';
    try {
      var values = await Promise.all([
        request('BoardResource', { board_id: board.id, field_set_key: 'boardEdit' }, generation, key),
        request('BoardInvitesResource', { board_id: board.id, sort: 'viewer_first', field_set_key: 'boardEdit',
          status_filters: 'new,accepted,contact_request_not_approved,pending_approval', include_inactive: true }, generation, key),
        request('ShareSuggestionsResource', { suggestion_type: 'group_board', board: board.id }, generation, key)
      ]);
      if (!collabCurrent(state)) return;
      var detail = values[0] && values[0].resource_response.data, invitations = values[1] && values[1].resource_response.data,
        suggested = values[2] && values[2].resource_response.data;
      if (!detail || String(detail.id) !== String(board.id) || !detail.owner || !(String(detail.owner.id) === viewerId || detail.collaborated_by_me === true || typeof detail.collaborated_by_me !== 'boolean' && board.collaborated_by_me === true && String(detail.owner.id) === String((board.owner || {}).id)) ||
          !Array.isArray(invitations) || !Array.isArray(suggested)) throw new Error('invalid-collaborators');
      state.owner = String(detail.owner.id) === viewerId;
      state.permission = detail.collaborator_permissions_setting;
      state.invites = detail.collaborator_invites_enabled === true;
      state.canInvite = state.owner || (detail.collaborated_by_me === true || typeof detail.collaborated_by_me !== 'boolean' && board.collaborated_by_me === true) && state.invites;
      state.users = [collabUser(detail.owner, 'owner')];
      invitations.forEach(function (item) {
        if (!item.board || String(item.board.id) !== String(board.id) || !item.invited_user) throw new Error('wrong-board-invite');
        var user = collabUser(item.invited_user, item.status);
        if (!state.users.some(function (old) { return old.id === user.id; })) state.users.push(user);
      });
      state.suggestions = suggested.slice(0, 100).map(function (user) {
        var old = state.users.find(function (item) { return item.id === String(user.id); });
        return collabUser(user, old ? old.status : '');
      }).filter(function (user) { return user.id !== viewerId; });
    } catch (_) { if (collabCurrent(state)) state.error = '合作用户读取失败，请重试'; }
    finally { if (collabCurrent(state)) state.loading = false; }
  }
  async function collabWrite(state, action, value) {
    if (action === 'invite' ? state.canInvite !== true : !ownsBoard()) return;
    state.busy = true; state.error = ''; state.feedback = '';
    var sent = false;
    try {
      if (action === 'invite') {
        var user = state.suggestions.find(function (item) { return item.id === value && !item.status; });
        if (!user) throw new Error('invalid-user');
        sent = true;
        var response = await fetch('/_/graphql/', { method: 'POST', credentials: 'same-origin',
          headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
            'X-Pinterest-Source-Url': new URL(state.page).pathname },
          body: JSON.stringify({ queryHash: '42ceaa3423a096a27613e5738f83aaadcee449c55d4dd03624d2f08a6b6dca04',
            variables: { collaboratorIds: [user.id], boardId: String(board.id), message: '' } }) });
        if (!collabCurrent(state)) return;
        var payload = await response.json();
        if (!collabCurrent(state)) return;
        if (!response.ok || payload.errors || !payload.data || !payload.data.v3InviteBoardCollaboratorsMutation ||
            payload.data.v3InviteBoardCollaboratorsMutation.__typename !== 'V3InviteBoardCollaborators') throw new Error('unconfirmed-invite');
        user.status = 'new'; state.users.push(collabUser({ id: user.id, full_name: user.name, username: user.username,
          image_medium_url: user.avatar }, 'new')); state.feedback = '已发送 1 个邀请！';
      } else {
        if (!value || [0, 1].indexOf(value.permission) < 0 || typeof value.invites !== 'boolean') throw new Error('unsupported-permission');
        sent = true;
        var result = await request('BoardResource', { board_id: board.id, collaborator_permissions_setting: value.permission,
          collaborator_invites_enabled: value.invites, sensitivity: null }, generation, key, 'update');
        result = result && result.resource_response;
        if (!collabCurrent(state)) return;
        if (!result || result.code !== 0 || result.endpoint_name !== 'v3_edit_board' || !result.data ||
            String(result.data.id) !== String(board.id) || result.data.collaborator_permissions_setting !== value.permission ||
            result.data.collaborator_invites_enabled !== value.invites) throw new Error('unconfirmed-permissions');
        state.permission = value.permission; state.invites = value.invites; state.phase = 'members'; state.feedback = '权限已更新';
      }
    } catch (_) {
      if (collabCurrent(state)) { state.uncertain = sent; state.error = sent ? '操作结果未确认，请关闭后重新查看，勿重复提交' : '当前操作不可用'; }
    } finally { if (collabCurrent(state)) state.busy = false; }
  }
  window.PinmonyBoardApi = {
    shareInfo: function (page) { return page === key && route() === key && board && ready ? { userId: String(board.id), board: true } : null; },
    collaboratorsOpen: function (s, page, token) {
      if (s !== session || page !== key || route() !== key || !(ownsBoard() || board && board.collaborated_by_me === true) || (flow.phase && flow.phase !== 'edit') || flow.loading || flow.busy || flow.uncertain || boardBusy || feedBusy) return false;
      collaborators = { token: token, page: page, generation: generation, phase: 'members', loading: true, busy: false,
        uncertain: false, error: '', feedback: '', permission: 1, invites: false, users: [], suggestions: [] };
      collabLoad(collaborators); return true;
    },
    collaboratorsRead: function (token) { return collaborators && collaborators.token === token && collabCurrent(collaborators) ? collaborators : null; },
    collaboratorsAction: function (token, action, value) {
      var state = collaborators;
      if (state && state.token === token && action === 'close' && !state.busy) { collaborators = null; return true; }
      if (!state || state.token !== token || !collabCurrent(state) || state.busy || state.uncertain) return false;
      state.feedback = '';
      if (action === 'close') { collaborators = null; return true; }
      if (action === 'retry') { collabLoad(state); return true; }
      if (state.loading || state.error) return false;
      if ((action === 'permissions' || action === 'save') && !ownsBoard()) return false;
      if ((action === 'invite' || action === 'send') && state.canInvite !== true) return false;
      if (['members', 'invite', 'permissions'].indexOf(action) >= 0) { state.phase = action; return true; }
      if (action === 'send' && state.phase === 'invite' && state.suggestions.some(function (item) { return item.id === value && !item.status; })) {
        collabWrite(state, 'invite', value); return true;
      }
      if (action === 'save' && state.phase === 'permissions') { collabWrite(state, 'permissions', value); return true; }
      return false;
    },
    cancelPinStart: function (requestedSession, page, pinId) {
      var api = window.PinmonyPostApi;
      if (requestedSession !== session || page !== key || route() !== key || !ownsBoard() ||
          flow.phase || flow.busy || feedBusy || !api || cancelPinState && cancelPinState.busy ||
          !pins.some(function (pin) { return pin.id === pinId; })) return false;
      var pinUrl = location.origin + '/pin/' + pinId + '/';
      var state = cancelPinState = { session: session, page: page, pinUrl: pinUrl, busy: true, error: '', feedback: '', sent: false };
      var user = viewerId, boardId = String(board.id), token = generation;
      function current() { return cancelPinState === state && session === requestedSession &&
        generation === token && key === page && route() === page && viewerId === user && ownsBoard(); }
      (async function () {
        try {
          var read = await api.resourceRequest(pinUrl, 'PinResource', 'get',
            { id: pinId, field_set_key: 'auth_web_main_pin' }, current);
          var copy = read.data;
          if (!current()) return;
          if (!copy || String(copy.id) !== pinId || copy.is_repin !== true ||
              String((copy.pinner || {}).id) !== user || String((copy.board || {}).id) !== boardId)
            throw new Error('当前账号的图板收藏未能确认，未执行取消收藏');
          var options = { id: pinId };
          if (typeof copy.tracking_params === 'string' && copy.tracking_params) options.client_tracking_params = copy.tracking_params + '~0';
          state.sent = true;
          var result = await api.resourceRequest(pinUrl, 'PinResource', 'delete', options, current);
          if (!current()) return;
          if (result.code !== 0 || result.endpoint_name !== 'v3_delete_pin_handler') throw new Error('unconfirmed-delete');
          generation++; aborts.forEach(function (abort) { abort.abort(); }); aborts = [];
          boardBusy = false; feedBusy = false; revision++;
          state.feedback = '已取消收藏';
          notify();
        } catch (e) {
          if (cancelPinState === state && session === requestedSession && key === page && route() === page) {
            state.error = state.sent ? '取消收藏结果未确认，请关闭后刷新核对；不会重复提交' : '收藏校验失败，未执行取消收藏';
            if (state.sent) { recoveryRequired = true; revision++; notify(); }
          }
        } finally { if (cancelPinState === state) state.busy = false; }
      })();
      return true;
    },
    cancelPinRead: function (requestedSession, page, pinUrl) {
      return cancelPinState && cancelPinState.session === requestedSession && cancelPinState.page === page &&
        cancelPinState.pinUrl === pinUrl && session === requestedSession && key === page && route() === page ? cancelPinState : null;
    },
    flow: function (requestedSession, page, encoded) {
      if (requestedSession !== session || page !== key || route() !== key || !board) return false;
      var value; try { value = JSON.parse(encoded); } catch (_) { return false; }
      if (!value || typeof value.action !== 'string' || flow.busy) return false;
      if (value.action === 'close') {
        var reload = flow.uncertain || flow.phase === 'archived';
        flowEpoch++; flow = emptyFlow(); targetBookmark = ''; sourcePins = {}; pendingSave = {}; selectedIds = []; notify();
        if (reload) { generation++; loadBoard(true); }
      } else if (value.action === 'ideas' && contributes()) readFlow('ideas', false);
      else if (value.action === 'select' && contributes()) { flowEpoch++; flow.phase = 'select'; flow.loading = false; flow.error = ''; notify(); }
      else if (value.action === 'targets' && contributes()) {
        if (!Array.isArray(value.value) || !value.value.length || value.value.length > 500 ||
            !value.value.every(function (id, index, all) { return digits(id) && all.indexOf(id) === index &&
              pins.some(function (pin) { return pin.id === id; }); })) return false;
        selectedIds = value.value.slice(); targetBookmark = ''; readFlow('targets', false);
      }
      else if (value.action === 'targetsMore' && flow.phase === 'targets') readFlow('targets', true);
      else if (value.action === 'edit' && participates()) readFlow('edit', false);
      else if (value.action === 'archiveConfirm' && participates()) { flow.phase = 'archive'; notify(); }
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
