// Contracts captured in 发布.har and zhaop.har. Credentials stay in the active session.
export const PIN_PUBLISH_API_SCRIPT: string = String.raw`
(function () {
  if (window !== window.top || location.origin !== 'https://www.pinterest.com' || window.PinmonyPublishApi) return;
  var state = null, pendingWrite = false;
  function clean(v, n) { return typeof v === 'string' ? v.trim().slice(0, n || 2000) : ''; }
  function web(v) { try { var u = new URL(v); return /^https?:$/.test(u.protocol) && !u.username && !u.password ? u.href : ''; } catch (_) { return ''; } }
  function current(s) { return state === s && s.page === location.href; }
  function definite(message) { var e = new Error(message); e.definite = true; return e; }
  async function request(s, name, op, options) {
    if (!current(s)) throw definite('页面已切换');
    var abort = new AbortController(); s.abort = abort;
    var timer = setTimeout(function () { abort.abort(); }, 20000);
    var sourcePath = name === 'BoardResource' ? '/board/create/' :
      name === 'PinResource' || name === 'BoardPickerBoardsResource' ? '/pin/create/' + (s.kind === 'photo' ? 'uploaded' : 'pinbuilder') + '/' : new URL(s.profile).pathname;
    var form = 'source_url=' + encodeURIComponent(sourcePath) +
      '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} }));
    var url = '/resource/' + name + '/' + op + '/', args = { credentials: 'same-origin', signal: abort.signal,
      headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
        'X-Pinterest-Pws-Handler': 'www/pin/create/[method].js' } };
    if (name === 'BoardResource') args.headers['X-Pinterest-Pws-Handler'] = 'www/board/create.js';
    if (name === 'FindPinImagesResource') args.headers['X-Pinterest-Pws-Handler'] = 'www/pin-builder.js';
    if (name === 'UserResource') args.headers['X-Pinterest-Pws-Handler'] = 'www/index.js';
    args.headers['X-Pinterest-AppState'] = 'active'; args.headers['X-Pinterest-Source-Url'] = sourcePath;
    try {
      var node = document.getElementById('__PWS_INITIAL_PROPS__');
      var initial = node && JSON.parse(node.textContent || '{}');
      var version = initial && initial.client_context && initial.client_context.app_version;
      if (typeof version === 'string' && /^[A-Za-z0-9._-]{1,80}$/.test(version)) args.headers['X-App-Version'] = version;
    } catch (_) { /* Missing runtime version never becomes a hardcoded captured value. */ }
    if (op === 'get') url += '?' + form;
    else { args.method = 'POST'; args.body = form; args.headers['Content-Type'] = 'application/x-www-form-urlencoded'; }
    try {
      var response = await fetch(url, args), p = await response.json();
      if (!current(s)) throw definite('页面已切换');
      var r = p.resource_response;
      if (!response.ok || !r || r.status !== 'success' || r.code !== 0) {
        if (r && r.status === 'failure' && typeof r.code === 'number' && r.code !== 0) throw definite('网站拒绝了本次操作');
        throw new Error('接口响应未确认');
      }
      return p;
    } finally { clearTimeout(timer); if (s.abort === abort) s.abort = null; }
  }
  function mapBoard(b) {
    if (!b || b.type !== 'board' || !/^\d+$/.test(b.id || '') || !clean(b.name, 100)) return null;
    return { id: b.id, title: clean(b.name, 100), imageUrl: web(b.image_cover_hd_url || b.image_cover_url),
      secret: b.privacy === 'secret', enabled: Array.isArray(b.access) && b.access.indexOf('write') >= 0 && !b.archived_by_me && !b.archived_by_me_at };
  }
  async function identity(s) {
    var username = new URL(s.profile).pathname.split('/')[1];
    var p = await request(s, 'UserResource', 'get', { field_set_key: 'profile', username: username });
    var u = p.resource_response.data, viewer = p.client_context && p.client_context.user;
    if (!u || u.type !== 'user' || !/^\d+$/.test(u.id || '') || !viewer || viewer.id !== u.id || u.username !== username)
      throw definite('无法确认当前账号身份，请返回刷新资料');
    s.userId = u.id;
  }
  async function boards(s) {
    s.loading = true; s.error = '';
    try {
      var p = await request(s, 'BoardPickerBoardsResource', 'get', { filter: 'all', field_set_key: 'profile_grid_item', user_id: s.userId });
      var data = p.resource_response.data;
      if (!data || !Array.isArray(data.all_boards)) throw new Error('图板返回格式无效');
      s.boards = data.all_boards.map(mapBoard).filter(Boolean); s.phase = 'boards';
    } catch (e) { if (current(s)) s.error = clean(e.message); }
    finally { if (current(s)) s.loading = false; }
  }
  async function scrape(s, value) {
    if (!web(value) || value.length > 4096) return false;
    s.loading = true; s.error = ''; s.input = value;
    try {
      var p = await request(s, 'FindPinImagesResource', 'get', { url: value, source: 'pin_create', appendItems: false,
        followRedirects: true, scrapeMetric: 'www_url_scrape' });
      var r = p.resource_response, d = r.data;
      if (r.endpoint_name !== 'v3_find_image' || !d || !Array.isArray(d.items)) throw new Error('图片解析返回格式无效');
      s.candidates = d.items.filter(function (v) { return v.type === 'pinnable' && web(v.url) && web(v.link || d.destination_url || value); })
        .slice(0, 100).map(function (v, i) { return { id: 'scraped-' + i, title: clean(d.title), imageUrl: web(v.url),
          imageWidth: 0, imageHeight: 0, link: web(v.link || d.destination_url || value), base64: '' }; });
      s.selectedIds = []; s.phase = s.candidates.length ? 'select' : 'empty';
    } catch (e) { if (current(s)) s.error = clean(e.message) || '读取图片失败，请重试'; }
    finally { if (current(s)) s.loading = false; }
    return true;
  }
  async function submit(s, board, name, secret) {
    if (pendingWrite || s.busy || s.loading || s.uncertain) return;
    s.busy = true; s.error = ''; pendingWrite = true;
    try {
      if (name) {
        var created = await request(s, 'BoardResource', 'create', { name: name, privacy: secret ? 'secret' : 'public' });
        var b = created.resource_response.data, mapped = mapBoard(b);
        if (created.resource_response.endpoint_name !== 'v3_create_board' || !mapped || b.name !== name ||
          b.privacy !== (secret ? 'secret' : 'public') || !b.owner || b.owner.id !== s.userId) throw new Error('图板创建结果未确认');
        s.boards.push(mapped); board = mapped;
        if (s.kind === 'board') { s.completed = 1; s.phase = 'done'; return; }
        s.phase = 'boards';
        if (!mapped.enabled) throw definite('图板已创建，但没有发布权限，请选择其他图板');
      }
      var selected = s.candidates.filter(function (p) { return s.selectedIds.indexOf(p.id) >= 0 && !p.done; });
      if (!board || !board.enabled || !selected.length) throw definite('请选择图片和可写入的图板');
      for (var i = 0; i < selected.length; i++) {
        var pin = selected[i], photo = s.kind === 'photo';
        var p = await request(s, 'PinResource', 'create', { boardId: board.id, board_id: board.id,
          description: pin.title, guid: '', imageBase64: photo ? pin.base64 : '', image_base64: photo ? pin.base64 : '',
          imageUrl: photo ? '' : pin.imageUrl, image_url: photo ? '' : pin.imageUrl, link: photo ? '' : pin.link,
          method: photo ? 'uploaded' : 'scraped' });
        var r = p.resource_response, result = r.data;
        if (r.endpoint_name !== 'v3_create_pin_handler' || !result || result.type !== 'pin' || !/^\d+$/.test(result.id || '') ||
          !result.board || result.board.id !== board.id || !result.pinner || result.pinner.id !== s.userId || result.is_repin !== false ||
          !result.images || !Object.keys(result.images).some(function (key) { return web(result.images[key].url); })) throw new Error('发布结果未确认');
        pin.done = true; pin.base64 = ''; s.completed++;
      }
      s.phase = 'done'; s.candidates = [];
    } catch (e) {
      if (current(s)) { s.uncertain = !e.definite;
        s.error = s.uncertain ? '操作结果未确认，请关闭后刷新核对，勿重复提交' : clean(e.message);
        if (s.completed) s.error = '已确认发布 ' + s.completed + ' 张。' + s.error;
      }
    } finally { pendingWrite = false; if (current(s)) s.busy = false; }
  }
  window.PinmonyPublishApi = {
    open: function (profile, kind, token) {
      if (pendingWrite || !['website', 'photo', 'board'].includes(kind) || !/^https:\/\/www\.pinterest\.com\/[^/]+\/(?:_saved\/|_created\/)?$/.test(profile)) return false;
      if (state && state.abort) state.abort.abort();
      var s = state = { profile: profile, page: location.href, kind: kind, token: token, phase: kind === 'board' ? 'create' : kind === 'photo' ? 'photo' : 'website',
        candidates: [], selectedIds: [], boards: [], loading: true, busy: false, error: '', feedback: '', uncertain: false, completed: 0, userId: '', photoChunk: '' };
      identity(s).catch(function (e) { if (current(s)) s.error = clean(e.message); }).finally(function () { if (current(s)) s.loading = false; });
      return true;
    },
    read: function (token) {
      var s = state; if (!s || !current(s) || token !== s.token) return null;
      return { token: s.token, page: s.page, profile: s.profile, kind: s.kind, phase: s.phase,
        selectedIds: s.selectedIds.filter(function (id) { return s.candidates.some(function (p) { return p.id === id && !p.done; }); }),
        boards: s.boards, loading: s.loading, busy: s.busy, error: s.error, feedback: s.feedback, hasMore: false,
        uncertain: s.uncertain, completed: s.completed, pins: s.candidates.filter(function (p) { return !p.done; })
          .map(function (p) { return { id: p.id, title: p.title, imageUrl: p.imageUrl, imageWidth: p.imageWidth, imageHeight: p.imageHeight }; }) };
    },
    photoChunk: function (token, value, uri, last) {
      var s = state; if (!s || !current(s) || token !== s.token || s.kind !== 'photo' || s.busy || s.uncertain ||
        !['photo', 'select'].includes(s.phase) || typeof value !== 'string' || value.length > 65536 || s.candidates.length >= 10 || !/^file:\/\/media\//.test(uri)) return false;
      if (s.photoChunk.length + value.length > 5600000) { s.photoChunk = ''; return false; }
      s.photoChunk += value;
      if (last) {
        if (!/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/]+=*$/.test(s.photoChunk)) { s.photoChunk = ''; return false; }
        var id = 'photo-' + s.candidates.length;
        s.candidates.push({ id: id, title: '', imageUrl: uri, imageWidth: 0, imageHeight: 0, base64: s.photoChunk });
        s.photoChunk = ''; s.selectedIds.push(id); s.phase = 'select';
      }
      return true;
    },
    action: function (token, action, value, secret) {
      var s = state; if (!s || !current(s) || s.token !== token) return false;
      if (action === 'close') { if (s.abort) s.abort.abort(); s.candidates = []; s.photoChunk = ''; state = null; return true; }
      if (s.busy || s.loading || s.uncertain || !s.userId) return false;
      if (action === 'scrape' && s.phase === 'website') { scrape(s, value); return true; }
      if (action === 'back') { s.phase = s.phase === 'create' ? (s.kind === 'board' ? 'done' : 'boards') : s.phase === 'boards' ? 'select' : 'website'; s.error = ''; return true; }
      if (action === 'toggle' && s.phase === 'select' && s.candidates.some(function (p) { return p.id === value && !p.done; }))
        s.selectedIds = s.selectedIds.includes(value) ? s.selectedIds.filter(function (id) { return id !== value; }) : s.selectedIds.concat([value]);
      else if (action === 'all' && s.phase === 'select') { var ids = s.candidates.filter(function (p) { return !p.done; }).map(function (p) { return p.id; }); s.selectedIds = s.selectedIds.length === ids.length ? [] : ids; }
      else if (action === 'next' && s.phase === 'select' && s.selectedIds.length) { s.phase = 'boards'; boards(s); }
      else if (action === 'retryBoards' && s.phase === 'boards') boards(s);
      else if (action === 'createForm' && s.phase === 'boards') { s.phase = 'create'; s.error = ''; }
      else if (action === 'boards' && s.phase === 'create') { s.phase = 'boards'; s.error = ''; }
      else if (action === 'move' && s.phase === 'boards') { var b = s.boards.find(function (b) { return b.id === value && b.enabled; }); if (!b || !s.selectedIds.length) return false; submit(s, b); }
      else if (action === 'create' && s.phase === 'create' && clean(value, 100) && value.trim().length <= 100) submit(s, null, clean(value, 100), secret === true);
      else return false;
      return true;
    }
  };
})();`;
