// Captured website contracts. Uses only the current ArkWeb session.
export const PIN_PROFILE_ORGANIZE_ENABLED: boolean = true;
export const PIN_PROFILE_ORGANIZE_SCRIPT: string = `
(function () {
  var api = window.PinmonyProfileApi;
  if (!api || window.PinmonyProfileOrganizeEnabled !== true) return;
  var state = null, pendingWrite = false, originalReset = api.reset;
  api.reset = function () { state = null; originalReset(); };
  var originalSuspend = api.suspend;
  api.suspend = function () {
    if (state && (state.loading || state.organize)) state = null;
    if (originalSuspend) originalSuspend();
  };
  function valid(s) { return state === s && s.current(); }
  function clean(v) { return typeof v === 'string' ? v.trim().slice(0, 300) : ''; }
  function image(v) { return typeof v === 'string' && /^https:\\/\\/(?:i|s)\\.pinimg\\.com\\//.test(v) ? v : ''; }
  function cursor(p) { return p.resource_response.bookmark || (p.resource && p.resource.options && p.resource.options.bookmarks || [])[0] || ''; }
  function changed(s) { if (valid(s)) s.changed(); }
  async function request(s, resource, action, options) {
    if (!valid(s)) throw new Error('页面已切换');
    var controller = new AbortController(), timer = setTimeout(function () { controller.abort(); }, 12000);
    var headers = { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' };
    var form = 'source_url=' + encodeURIComponent(new URL(s.profile).pathname) + '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} }));
    var args = { credentials: 'same-origin', headers: headers, signal: controller.signal };
    var url = '/resource/' + resource + '/' + action + '/';
    try {
      if (action === 'get') url += '?' + form + '&_=' + Date.now();
      else {
        var match = document.cookie.match(/(?:^|;\\s*)csrftoken=([^;]+)/);
        if (!match) throw new Error('当前网页会话缺少请求凭据，请重新登录');
        headers['X-CSRFToken'] = decodeURIComponent(match[1]); headers['Content-Type'] = 'application/x-www-form-urlencoded';
        args.method = 'POST'; args.body = form;
      }
      var response = await fetch(url, args), p = await response.json();
      if (!valid(s)) throw new Error('页面已切换');
      var r = p.resource_response;
      if (!response.ok || !r || r.status !== 'success' || r.code !== 0) {
        var error = new Error(clean(r && r.message) || '接口请求失败');
        error.definite = !!(r && r.status === 'failure' && typeof r.code === 'number' && r.code !== 0);
        throw error;
      }
      return p;
    } finally { clearTimeout(timer); }
  }
  function mapPin(p, s) {
    if (!p || p.type !== 'pin' || !/^\\d+$/.test(p.id || '') || !p.pinner || p.pinner.id !== s.userId) return null;
    var im = p.images && (p.images['736x'] || p.images['474x'] || p.images['236x'] || p.images.orig);
    if (!im || !image(im.url)) return null;
    return { id: p.id, title: clean(p.grid_title || p.title), imageUrl: im.url,
      imageWidth: Number(im.width) || 0, imageHeight: Number(im.height) || 0 };
  }
  function mapBoard(b) {
    if (!b || b.type !== 'board' || !/^\\d+$/.test(b.id || '') || !clean(b.name)) return null;
    return { id: b.id, title: clean(b.name), imageUrl: image(b.image_cover_hd_url || b.image_cover_url),
      secret: b.privacy === 'secret', enabled: (Array.isArray(b.access) ? b.access.indexOf('write') >= 0 :
        /(?:^|\\s)write(?:\\s|$)/.test(b.access || '')) && !b.archived_by_me };
  }
  function merge(old, next) { next.forEach(function (p) { if (p && !old.some(function (v) { return v.id === p.id; })) old.push(p); }); return old; }
  async function loadPins(s, append) {
    if (!valid(s) || s.loading || append && !s.hasMore) return;
    s.loading = true; s.error = ''; changed(s);
    var previous = s.bookmark;
    try {
      var options = { field_set_key: 'mobile', redux_normalize_feed: true, userId: s.userId };
      if (append) options.bookmarks = [previous];
      var p = await request(s, 'BoardlessPinsResource', 'get', options);
      if (!Array.isArray(p.resource_response.data)) throw new Error('未整理 Pin 返回格式无效');
      var mapped = p.resource_response.data.map(function (pin) { return mapPin(pin, s); });
      if (mapped.some(function (pin) { return !pin; })) throw new Error('未整理 Pin 身份或图片无效');
      s.pins = merge(append ? s.pins.slice() : [], mapped); s.bookmark = cursor(p);
      s.hasMore = !!s.bookmark && s.bookmark !== '-end-' && s.bookmark !== previous && mapped.length > 0;
    } catch (e) { if (valid(s)) s.error = clean(e.message) || '未整理 Pin 读取失败，请重试'; }
    finally { if (valid(s)) { s.loading = false; changed(s); } }
  }
  async function loadBoards(s, append) {
    var o = s.organize;
    if (!valid(s) || !o || o.loading || o.busy || append && !o.hasMore) return;
    o.loading = true; o.error = ''; changed(s); var previous = o.bookmark;
    try {
      var options = { privacy_filter: 'all', sort: 'custom', field_set_key: 'profile_grid_item', filter_stories: true,
        username: s.username, page_size: 25, group_by: 'mix_public_private', include_archived: true, filter_all_pins: false };
      if (append) options.bookmarks = [previous];
      var p = await request(s, 'BoardsResource', 'get', options);
      if (s.organize !== o) return;
      if (!Array.isArray(p.resource_response.data)) throw new Error('图板列表返回格式无效');
      o.boards = merge(append ? o.boards.slice() : [], p.resource_response.data.map(mapBoard)); o.bookmark = cursor(p);
      o.hasMore = !!o.bookmark && o.bookmark !== '-end-' && o.bookmark !== previous && p.resource_response.data.length > 0;
    } catch (e) { if (valid(s) && s.organize === o) o.error = clean(e.message) || '图板读取失败，请重试'; }
    finally { if (valid(s) && s.organize === o) { o.loading = false; changed(s); } }
  }
  api.readUnorganized = function (profile, section, notify, current) {
    if (section !== 'saved') { state = null; return null; }
    var user = api.read(profile, notify, current).info;
    if (!user || user.isOwn !== true || !/^\\d+$/.test(user.userId || '')) { state = null; return null; }
    if (!state || state.profile !== profile || state.userId !== user.userId) {
      state = { profile: profile, userId: user.userId, username: user.handle, changed: notify, current: current,
        pins: [], loading: false, error: '', bookmark: '', hasMore: false, feedback: '', organize: null };
      loadPins(state, false);
    }
    state.changed = notify; state.current = current;
    return state;
  };
  api.organizeAction = function (action, value, secret) {
    var s = state, o = s && s.organize;
    if (!s || !valid(s)) return false;
    if (action === 'morePins' || action === 'retryPins') { if (!o || !o.busy) loadPins(s, action === 'morePins' || !!s.pins.length); return true; }
    if (action === 'open') {
      if (pendingWrite || s.loading || !s.pins.length) return false;
      s.feedback = ''; s.organize = { phase: 'select', selectedIds: [], boards: [], loading: false, busy: false,
        error: '', feedback: '', bookmark: '', hasMore: false, uncertain: false }; changed(s); return true;
    }
    if (!o || o.busy) return false;
    if (action === 'close') {
      s.organize = null;
      if (o.uncertain) { state = null; api.invalidateContent(); if (s.current()) s.changed(); }
      else changed(s);
      return true;
    }
    if (action === 'back') { o.phase = 'select'; o.error = ''; changed(s); return true; }
    if (action === 'toggle' && o.phase === 'select' && s.pins.some(function (p) { return p.id === value; })) {
      o.selectedIds = o.selectedIds.indexOf(value) < 0 ? o.selectedIds.concat([value]) : o.selectedIds.filter(function (id) { return id !== value; });
    } else if (action === 'all' && o.phase === 'select') {
      o.selectedIds = o.selectedIds.length === s.pins.length ? [] : s.pins.map(function (p) { return p.id; });
    } else if (action === 'next' && o.selectedIds.length && o.phase === 'select') { o.phase = 'boards'; loadBoards(s, false); }
    else if (action === 'moreBoards' || action === 'retryBoards') { loadBoards(s, action === 'moreBoards' || !!o.boards.length); }
    else if (action === 'createForm' && !o.uncertain) { o.phase = 'create'; o.error = ''; }
    else if (action === 'boards') { o.phase = 'boards'; o.error = ''; }
    else if ((action === 'move' || action === 'create') && !o.uncertain && !o.loading && !pendingWrite) {
      var board = o.boards.find(function (b) { return b.id === value && b.enabled; });
      if (action === 'move' && (!board || o.phase !== 'boards' || !o.selectedIds.length ||
          !o.selectedIds.every(function (id) { return s.pins.some(function (p) { return p.id === id; }); }))) return false;
      if (action === 'create' && (o.phase !== 'create' || !clean(value) || !o.selectedIds.length ||
          !o.selectedIds.every(function (id) { return s.pins.some(function (p) { return p.id === id; }); }))) return false;
      o.busy = true; o.error = ''; pendingWrite = true; changed(s);
      (async function () {
        try {
          var p = action === 'move' ? await request(s, 'ApiResource', 'create', { url: '/v3/pins/bulk/move/',
            data: { board_id: board.id, pin_ids: o.selectedIds.slice() } }) :
            await request(s, 'BoardResource', 'create', { name: clean(value), privacy: secret ? 'secret' : 'public' });
          if (!valid(s) || s.organize !== o) return;
          var r = p.resource_response;
          if (action === 'create') {
            var b = r.data, mapped = mapBoard(b);
            if (r.endpoint_name !== 'v3_create_board' || !mapped || b.name !== clean(value) || b.privacy !== (secret ? 'secret' : 'public')) throw new Error('未能确认图板创建结果');
            o.boards = merge(o.boards.slice(), [mapped]); o.phase = 'boards';
            api.invalidateContent();
            if (!mapped.enabled) {
              var permissionError = new Error('图板已创建，但当前没有写入权限，请选择其他图板');
              permissionError.definite = true; throw permissionError;
            }
            p = await request(s, 'ApiResource', 'create', { url: '/v3/pins/bulk/move/',
              data: { board_id: mapped.id, pin_ids: o.selectedIds.slice() } });
            if (!valid(s) || s.organize !== o) return;
            r = p.resource_response;
          }
          if (r.endpoint_name !== 'v3_move_pins') throw new Error('未能确认整理结果');
          s.pins = s.pins.filter(function (pin) { return o.selectedIds.indexOf(pin.id) < 0; });
          s.feedback = ''; s.organize = null;
          s.bookmark = ''; loadPins(s, false); api.invalidateContent();
        } catch (e) {
          if (valid(s) && s.organize === o) {
            o.error = clean(e.message) || '操作未完成';
            // Network/format/timeout failures may follow a committed write. Never offer replay.
            o.uncertain = !e.definite && !/缺少请求凭据/.test(o.error);
            if (o.uncertain) o.error = '操作结果未确认，请关闭后刷新列表核对，勿重复提交';
          }
        } finally { pendingWrite = false; if (valid(s)) { o.busy = false; changed(s); } }
      })();
    } else return false;
    changed(s); return true;
  };
  api.openUnorganized = function (id) {
    if (!state || !valid(state) || state.organize || !state.pins.some(function (p) { return p.id === id; })) return false;
    location.href = '/pin/' + id + '/'; return true;
  };
})();`;
