export const PIN_BOARD_INVITATION_SCRIPT: string = String.raw`
(function () {
  if (window !== window.top || !/(^|\.)pinterest\.com$/i.test(location.hostname)) return;
  if(window.PinmonyNativeInboxUpdatesEnabled === true)return;
  var state = null, epoch = 0;
  function valid(s) { return state === s && s.epoch === epoch && s.page === location.href.split('#')[0]; }
  function id(value) { return /^\d{1,30}$/.test(String(value || '')); }
  function text(value) { return typeof value === 'string' ? value.trim().slice(0, 200) : ''; }
  function image(value) { return typeof value === 'string' && value.indexOf('https://') === 0 ? value : ''; }
  async function request(s, name, options, verb) {
    var controller = new AbortController(), timer = setTimeout(function () { controller.abort(); }, 15000);
    try {
      var params = new URLSearchParams({ source_url: location.pathname, data: JSON.stringify({ options: options, context: {} }) });
      var response = await fetch('/resource/' + name + '/' + (verb || 'get') + '/' + (verb ? '' : '?' + params.toString()), {
        method: verb ? 'POST' : 'GET', body: verb ? params.toString() : undefined, signal: controller.signal,
        credentials: 'same-origin', headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded',
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } });
      var payload = await response.json();
      if (!valid(s)) throw new Error('stale');
      if (!response.ok || !payload.resource_response || payload.resource_response.status !== 'success' || payload.resource_response.code !== 0)
        throw new Error('invalid-response');
      return payload;
    } finally { clearTimeout(timer); }
  }
  function map(item) {
    var b = item && item.board, from = item && item.invited_by_user, to = item && item.invited_user;
    if (!b || !id(b.id) || !from || !id(from.id) || !to || !id(to.id)) throw new Error('invalid-invite');
    var url = new URL(b.url, location.origin);
    if (url.origin !== location.origin || !/^\/[^/]+\/[^/]+\/$/.test(url.pathname)) throw new Error('invalid-board');
    return { boardId: String(b.id), boardUrl: url.href, boardName: text(b.name), imageUrl: image(b.image_thumbnail_url || b.image_cover_url),
      inviter: text(from.full_name || from.username), inviterAvatar: image(from.image_medium_url || from.image_large_url),
      invitedUser: String(to.id), invitedAvatar: image(to.image_medium_url), createdAt: text(item.created_at), status: text(item.status) };
  }
  window.PinmonyBoardInvitations = {
    open: function (token, preview, username) {
      epoch++; var s = state = { token: token, epoch: epoch, page: location.href.split('#')[0], loading: true, busy: false,
        uncertain: false, error: '', feedback: '', items: preview ? [preview] : [] };
      var options = preview ? { board_id: preview.boardId, invited_user_id: preview.invitedUser, field_set_key: 'boardEdit' } :
        { current_user: true, field_set_key: 'news' };
      request(s, preview ? 'BoardInviteResource' : 'BoardInvitesResource', options).then(async function (payload) {
        var r = payload.resource_response, viewer = payload.client_context && payload.client_context.user;
        if (preview) {
          if (!r.data || !r.data.board || String(r.data.board.id) !== preview.boardId || !r.data.invited_user ||
              String(r.data.invited_user.id) !== preview.invitedUser || !viewer || String(viewer.id) !== preview.invitedUser)
            throw new Error('wrong-invite');
          preview.status = text(r.data.status); s.items = [preview];
          preview.invitedAvatar = image(viewer.image_medium_url || viewer.image_small_url) || preview.invitedAvatar;
          if (!preview.invitedAvatar && (viewer.username || username)) {
            var profile = await request(s, 'UserResource', { username: viewer.username || username });
            if (profile.resource_response.data && String(profile.resource_response.data.id) === preview.invitedUser)
              preview.invitedAvatar = image(profile.resource_response.data.image_medium_url || profile.resource_response.data.image_large_url);
          }
        } else {
          if (!Array.isArray(r.data) || !viewer || !id(viewer.id)) throw new Error('invalid-list');
          s.items = r.data.filter(function (item) { return item.status === 'new' && String((item.invited_user || {}).id) === String(viewer.id); }).slice(0, 100).map(map);
  }
      }).catch(function () { if (valid(s)) s.error = '图板邀请读取失败，请重试'; })
        .finally(function () { if (valid(s)) s.loading = false; });
      return true;
    },
    read: function (token) { return state && state.token === token && valid(state) ? state : null; },
    accept: function (token) {
      var s = state, item = s && s.items[0];
      if (!s || s.token !== token || !valid(s) || s.loading || s.busy || s.uncertain || s.error || !item || item.status !== 'new') return false;
      s.busy = true; s.feedback = '';
      request(s, 'BoardInviteResource', { board_id: item.boardId, invited_user_id: item.invitedUser }, 'update').then(function (payload) {
        var r = payload.resource_response, data = r.data;
        if (r.endpoint_name !== 'v3_accept_board_collaborator_invite' || !data || data.status !== 'accepted' ||
            !data.board || String(data.board.id) !== item.boardId || !data.invited_user || String(data.invited_user.id) !== item.invitedUser)
          throw new Error('unconfirmed');
        item.status = 'accepted'; s.feedback = '你已加入！收藏 Pin 图，与合作用户一起制定计划，还有更多乐趣！';
      }).catch(function () { if (valid(s)) { s.uncertain = true; s.error = '加入结果未确认，请关闭后重新查看，勿重复接受'; } })
        .finally(function () { if (valid(s)) s.busy = false; }); return true;
    }
  };
})();`;
