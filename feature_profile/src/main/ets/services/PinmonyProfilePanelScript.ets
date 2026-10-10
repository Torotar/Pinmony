export const PIN_PROFILE_PANEL_SCRIPT: string = `
(function () {
  var state = null, generation = 0, abort = null, saveResult = null, followResult = "", followBusy = false;
  async function graph(page, hash, variables, signal) {
    var address = location.href;
    var r = await fetch("/_/graphql/", { method: "POST", credentials: "same-origin", signal: signal,
      headers: { Accept: "application/json", "Content-Type": "application/json" }, body: JSON.stringify({ queryHash: hash, variables: variables }) });
    var j = await r.json();
    if (!current(page) || location.href !== address) throw new Error("stale");
    if (!r.ok || !j.data || j.errors && j.errors.length) throw new Error("business");
    return j.data;
  }
  function current(page) {
    return location.origin + location.pathname.replace(/(?:_saved|_created)\\/?$/, '') === page;
  }
  function requestHeaders() {
    var headers = { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
      'X-Pinterest-AppState': 'active', 'X-Pinterest-Source-Url': location.pathname,
      'X-Pinterest-Pws-Handler': 'www/index.js' };
    try {
      var node = document.getElementById && document.getElementById('__PWS_INITIAL_PROPS__');
      var initial = node && JSON.parse(node.textContent || '{}');
      var version = initial && initial.client_context && initial.client_context.app_version;
      if (typeof version === 'string' && /^[A-Za-z0-9._-]{1,80}$/.test(version)) headers['X-App-Version'] = version;
    } catch (_) {}
    return headers;
  }
  function stop() { generation++; if (abort) abort.abort(); abort = null; state = null; }
  var sharing = null, shareGeneration = 0;
  window.PinmonyProfilePanel = {
    close: stop,
    shareClose: function () { shareGeneration++; if (sharing && sharing.abort) sharing.abort.abort(); sharing = null; },
    shareCurrent: function (page) { return !!sharing && sharing.page === page && sharing.address === location.href && current(page); },
    shareLink: function (page, session) { return this.shareCurrent(page) && sharing.session === session ? sharing.link : ''; },
    shareOpen: function (page, session, changed) {
      var info = window.PinmonyProfileApi && window.PinmonyProfileApi.currentInfo(page);
      if (!current(page) || !info || !/^\\d+$/.test(info.userId)) return false;
      this.shareClose(); var g = shareGeneration;
      var controller = new AbortController();
      var s = sharing = { page: page, address: location.href, session: session, link: '', abort: controller,
        kind: 'state', pinUrl: page, pinDetail: false, title: '分享', sectionLabel: '发送给',
        options: ['Messenger','WhatsApp','短信','Facebook','X'].map(function (name) { return { id: 'profile-share:' + name, label: name, enabled: false }; }),
        actions: [{ id: 'profile-copy', label: '复制链接', enabled: false }], contacts: [], searchActive: true, searchLabel: '搜索用户', feedback: '正在加载…', error: '' };
      function publish() {
        if (g !== shareGeneration || sharing !== s || s.address !== location.href || !current(page)) return;
        changed({ kind: s.kind, session: session, pinUrl: page, pinDetail: false, title: s.title, sectionLabel: s.sectionLabel,
          options: s.options, actions: s.actions, contacts: s.contacts, searchActive: true, searchLabel: '搜索用户', feedback: s.feedback, error: s.error });
      }
      publish();
      var timer = setTimeout(function () { controller.abort(); }, 15000);
      Promise.allSettled([
        graph(page, '6312848b4bb08588587683a04a42e4d0333e2e986fcab0cef4ed200786d3f5d9',
          { objectId: info.userId, inviteType: JSON.stringify({ invite_category: 3, invite_object: 3, invite_channel: 12 }) }, controller.signal),
        fetch('/resource/ShareSuggestionsResource/get/?source_url=' + encodeURIComponent(location.pathname) + '&data=' + encodeURIComponent(JSON.stringify({ options: { suggestion_type: 'share', hide_group_conversations: false }, context: {} })),
          { credentials: 'same-origin', signal: controller.signal, headers: requestHeaders() }).then(async function (r) {
            var j = await r.json(), resource = j.resource_response;
            if (!r.ok || !resource || resource.status !== 'success' || resource.code !== 0 || !Array.isArray(resource.data)) throw new Error('contacts');
            return resource.data;
          })
      ]).then(function (results) {
        if (g !== shareGeneration || sharing !== s || s.address !== location.href || !current(page)) return;
        var link = results[0].status === 'fulfilled' && results[0].value.v3InviteUserExternalQuery;
        var data = link && link.data;
        if (data && /^https:\\/\\/pin\\.it\\/[A-Za-z0-9]+\\/?$/.test(data.inviteUrl) && typeof data.inviteCode === 'string' && typeof data.title === 'string' && typeof data.message === 'string') {
          s.link = data.inviteUrl; s.actions[0].enabled = true;
          s.options.forEach(function (option) { option.enabled = true; });
        } else s.error = '分享链接读取失败，请关闭后重试';
        if (results[1].status === 'fulfilled') s.contacts = results[1].value.slice(0,100).filter(function (u) { return /^\\d+$/.test(u.id) && typeof u.username === 'string'; }).map(function (u) {
          return { id: 'profile-contact:' + u.id, label: String(u.full_name || u.username).slice(0,300), icon: /^https:\\/\\//.test(u.image_medium_url || '') ? u.image_medium_url : '', enabled: true };
        }); else s.error = s.error || '联系人读取失败，请关闭后重试';
        s.feedback = ''; publish();
      }).finally(function () { clearTimeout(timer); });
      return true;
    },
    shareSearch: function (page, session, value, changed) {
      if (!sharing || sharing.page !== page || sharing.session !== session || !current(page)) return false;
      var query = String(value || '').trim().slice(0, 200), g = shareGeneration, s = sharing;
      if (!query) { s.contacts = []; s.feedback = ''; changed({ kind: 'state', session: session, pinUrl: page, title: s.title, sectionLabel: s.sectionLabel, options: s.options, actions: s.actions, contacts: s.contacts, searchActive: true, query: '', feedback: '', error: '' }); return true; }
      s.feedback = '正在搜索…';
      fetch('/resource/ShareSuggestionsTypeaheadResource/get/?source_url=' + encodeURIComponent(location.pathname) + '&data=' + encodeURIComponent(JSON.stringify({ options: { count: 25, term: query, pin_scope: 'users' }, context: {} })), { credentials: 'same-origin', headers: requestHeaders() }).then(function (r) { return r.json(); }).then(function (j) {
        if (g !== shareGeneration || sharing !== s || !current(page)) return;
        var resource = j && j.resource_response, items = resource && resource.data && resource.data.items;
        if (!resource || resource.status !== 'success' || resource.code !== 0 || !Array.isArray(items)) throw new Error('search');
        s.contacts = items.slice(0, 100).filter(function (u) { return /^\\d+$/.test(u.id) && typeof u.username === 'string'; }).map(function (u) { return { id: 'profile-contact:' + u.id, label: String(u.full_name || u.username).slice(0, 300), icon: /^https:\\/\\//.test(u.image_medium_url || '') ? u.image_medium_url : '', enabled: true }; });
        s.feedback = ''; changed({ kind: 'state', session: session, pinUrl: page, title: s.title, sectionLabel: s.sectionLabel, options: s.options, actions: s.actions, contacts: s.contacts, searchActive: true, query: query, feedback: '', error: '' });
      }).catch(function () { if (g === shareGeneration && sharing === s) { s.feedback = '联系人搜索失败，请重试'; changed({ kind: 'state', session: session, pinUrl: page, title: s.title, sectionLabel: s.sectionLabel, options: s.options, actions: s.actions, contacts: [], searchActive: true, query: query, feedback: s.feedback, error: '' }); } });
      return true;
    },
    shareContact: function (page, session, id, changed) {
      if (!sharing || sharing.page !== page || sharing.session !== session || !current(page) || !/^profile-contact:\\d+$/.test(id)) return false;
      var target = id.slice('profile-contact:'.length), info = window.PinmonyProfileApi && window.PinmonyProfileApi.currentInfo(page), g = shareGeneration, s = sharing;
      if (!info || !/^\\d+$/.test(info.userId)) return false;
      s.feedback = '正在发送…'; changed({ kind: 'state', session: session, pinUrl: page, title: s.title, sectionLabel: s.sectionLabel, options: s.options, actions: s.actions, contacts: s.contacts, searchActive: true, feedback: s.feedback, error: '' });
      var headers = requestHeaders(); headers['Content-Type'] = 'application/x-www-form-urlencoded';
      fetch('/resource/ConversationsResource/create/', { method: 'POST', credentials: 'same-origin', headers: headers, body: 'data=' + encodeURIComponent(JSON.stringify({ options: { user_ids: [target], user: info.userId }, context: {} })) }).then(function (r) { return r.json(); }).then(function (j) {
        if (g !== shareGeneration || sharing !== s || !current(page)) return;
        var resource = j && j.resource_response, users = resource && resource.data && resource.data.users, message = resource && resource.data && resource.data.last_message;
        if (!resource || resource.status !== 'success' || resource.code !== 0 || !Array.isArray(users) || !users.some(function (u) { return String(u.id) === target; }) || !message || !message.id) throw new Error('send');
        s.feedback = '已发送'; changed({ kind: 'state', session: session, pinUrl: page, title: s.title, sectionLabel: s.sectionLabel, options: s.options, actions: s.actions, contacts: s.contacts, searchActive: true, feedback: s.feedback, error: '' });
      }).catch(function () { if (g === shareGeneration && sharing === s) { s.feedback = '发送失败，请重试'; changed({ kind: 'state', session: session, pinUrl: page, title: s.title, sectionLabel: s.sectionLabel, options: s.options, actions: s.actions, contacts: s.contacts, searchActive: true, feedback: s.feedback, error: '' }); } });
      return true;
    },
    read: function () { return state; },
    readSave: function () { return saveResult; },
    readFollow: function () { return followResult; },
    follow: function (page, id) {
      if (followBusy || !current(page)) return false;
      var info = window.PinmonyProfileApi && window.PinmonyProfileApi.currentInfo(page);
      var item = id && state && state.page === page && state.section !== 'boards' && state.items.find(function (v) { return v.id === id; });
      var target = item ? item.id : !id && info && info.isOwn === false && !info.blocked ? info.userId : '';
      var previous = item ? item.following : info && info.followingUser;
      if (!/^\\d+$/.test(target) || typeof previous !== 'boolean' || !info || info.viewerId === target || item && item.canFollow === false) return false;
      var g = generation, address = location.href, desired = !previous;
      followBusy = true; followResult = 'pending';
      var controller = new AbortController(), timer = setTimeout(function () { controller.abort(); }, 15000);
      graph(page, desired ? '5e6f83666a4e4fbd33b6c78f26f80166c097f4164e666b6e408b4bb62cb8c1e5' :
        '84f6cda9933f7aa2786ff803f5c7a7bc31af0392a37434f830fd7e2602c994c0', { followee: target }, controller.signal)
        .then(function (data) {
          if (g !== generation || location.href !== address) return;
          var result = data[desired ? 'v3FollowUserMethodMutation' : 'v3UnfollowUserMethodMutation'];
          var user = result && result.data;
          if (!user || user.id !== btoa('User:' + target) || user.explicitlyFollowedByMe !== desired) throw new Error('unconfirmed');
          if (item) item.following = desired;
          if (info && info.userId === target) info.followingUser = desired;
          followResult = 'ok';
        }).catch(function () { if (g === generation) followResult = 'error'; })
        .finally(function () { clearTimeout(timer); followBusy = false; });
      return true;
    },
    update: async function (page, token, input) {
      if (!state || state.page !== page || state.token !== token || state.mode !== 'edit' || !current(page)) return { ok: false, error: 'stale' };
      var g = generation; saveResult = { pending: true };
      try {
        input.impressumUrl = input.impressumUrl || ''; input.additionalWebsiteUrls = input.additionalWebsiteUrls || []; input.pronouns = input.pronouns || [];
        var response = await fetch('/_/graphql/', { method: 'POST', credentials: 'same-origin', headers: { Accept: 'application/json', 'Content-Type': 'application/json' }, body: JSON.stringify({ queryHash: '7f7aa5597fc53cb10b582e1d45cac2e61336be40dde57f95a9f022fb83806e81', variables: { input: input } }) });
        var result = await response.json();
        if (g !== generation || !state || state.token !== token || !current(page)) return;
        var mutation = result && result.data && result.data.v3EditSettingsHandlerMutation;
        var outcome = mutation && mutation.v3EditSettingsHandlerResponse;
        var user = mutation && mutation.v3UsersMeViewerResponse && mutation.v3UsersMeViewerResponse.data;
        var message = outcome && outcome.error && outcome.error.message;
        saveResult = response.ok && !(result.errors && result.errors.length) && outcome && outcome.__typename === 'V3EditSettingsHandler' && user && user.__typename === 'User' && user.username === input.username ?
          { ok: true, username: user.username } : { ok: false, duplicate: message === '用户名已被使用。', message: typeof message === 'string' ? message.slice(0, 200) : '资料保存未确认，请重试' };
      } catch (_) { if (g === generation) saveResult = { ok: false, message: '网络请求失败，保存结果未确认' }; }
    },
    open: async function (page, mode, section, token) {
      if (!current(page) || !/^(edit|following|followers)$/.test(mode)) return false;
      stop(); var g = generation, address = location.href;
      state = { page: page, mode: mode, section: section, token: token, loading: true, error: '', items: [],
        firstName: '', lastName: '', about: '', website: '', username: '', avatar: '' };

      abort = new AbortController(); var requestAbort = abort; var timer = setTimeout(function () { requestAbort.abort(); }, 15000);
      try {
        var username = decodeURIComponent(new URL(page).pathname.split('/')[1]);
        if (mode === 'followers') {
          var info = window.PinmonyProfileApi && window.PinmonyProfileApi.currentInfo(page);
          if (!info || !/^\\d+$/.test(info.userId)) throw new Error('identity');
          var data = await graph(page, '369b31865237e1a2f57f1879be69a6c01ee4d6d2806cc4c624d73baea9546b08', { userId: info.userId }, abort.signal);
          if (g !== generation || !state) return false;
          var user = data.v3GetUserHandlerQuery && data.v3GetUserHandlerQuery.data;
          var connection = user && user.followers && user.followers.connection;
          if (!user || user.id !== btoa('User:' + info.userId) || !connection || !Array.isArray(connection.edges) || !connection.pageInfo) throw new Error('shape');
          state.items = connection.edges.slice(0, 100).map(function (edge) {
            var u = edge.node;
            if (!u || !/^\\d+$/.test(u.entityId) || !/^[a-zA-Z0-9_]+$/.test(u.username) || typeof u.explicitlyFollowedByMe !== 'boolean') throw new Error('user');
            return { id: u.entityId, name: String(u.fullName || u.username).slice(0,300), avatar: /^https:\\/\\//.test(u.imageMediumUrl || '') ? u.imageMediumUrl : '',
              profileUrl: location.origin + '/' + u.username + '/', following: u.explicitlyFollowedByMe, canFollow: !u.blockedByMe && u.entityId !== info.viewerId };
          });
          state.hasMore = connection.pageInfo.hasNextPage === true;
          return true;
        }
        var name = mode === 'edit' ? 'ApiResource' : section === 'boards' ? 'ApiResource' : 'UserFollowingResource';
        var options = mode === 'edit' ? { url: '/v3/users/settings/', data: {} } : section === 'boards' ? {
          url: '/v3/users/' + encodeURIComponent(username) + '/boards/following/',
          data: { explicit_following: true, page_size: 12, fields: ['board.id','board.name','board.image_cover_url','board.followed_by_me','board.type','board.images[236x]','board.image_cover_hd_url','board.pin_count','board.board_order_modified_at','board.url','board.owner()','user.username'] }
        } : { exclude_not_explictly_followed: true, page_size: 50, explicit_following: true, username: username };
        var url = '/resource/' + name + '/get/';
        var encoded = 'source_url=' + encodeURIComponent(new URL(page).pathname) + '&data=' +
          encodeURIComponent(JSON.stringify({ options: options, context: {} }));
        var post = mode === 'following' && section === 'boards';
        var response = await fetch(post ? url : url + '?' + encoded, { method: post ? 'POST' : 'GET',
          credentials: 'same-origin', signal: abort.signal, body: post ? encoded : undefined,
          headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
            'Content-Type': 'application/x-www-form-urlencoded', 'X-Pinterest-Pws-Handler': 'www/index.js' } });
        if (!response.ok) throw new Error('http');
        var payload = await response.json();
        if (g !== generation || location.href !== address || !current(page)) return false;
        var r = payload.resource_response;
        if (!r || r.status !== 'success' || r.code !== 0) throw new Error('business');
        if (mode === 'edit') {
          var d = r.data;
          if (!d || typeof d.username !== 'string' || d.username.toLowerCase() !== username.toLowerCase()) throw new Error('identity');
          ['first_name','last_name','about','website_url','username','profile_image_url'].forEach(function (field, i) {
            var targets = ['firstName','lastName','about','website','username','avatar'];
            state[targets[i]] = typeof d[field] === 'string' ? d[field].slice(0, 2000) : '';
          });
        } else {
          if (!Array.isArray(r.data)) throw new Error('shape');
          state.items = r.data.slice(0, 100).map(function (item) {
            if (!item || !/^\\d+$/.test(String(item.id || '')) || typeof (item.full_name || item.name || item.username) !== 'string') throw new Error('item');
            var image = item.image_medium_url || item.image_cover_url || '';
            var covers = (item.images && Array.isArray(item.images['236x']) ? item.images['236x'] : []).map(function (img) { return img && typeof img.url === 'string' && img.url.startsWith('https://') ? img.url : ''; }).filter(Boolean).slice(0,3);
            if (!covers.length && image.startsWith('https://')) covers.push(image);
            var target = ''; try { var dest = new URL(item.url || '', location.origin); if (item.url && dest.origin === location.origin) target = dest.href; } catch (_) {}
            var updated = ''; var elapsed = Date.now() - Date.parse(item.board_order_modified_at || '');
            if (isFinite(elapsed) && elapsed >= 0) { var days = Math.floor(elapsed / 86400000); updated = days < 7 ? days + ' 天前' : days < 30 ? Math.floor(days / 7) + ' 周前' : days < 365 ? Math.floor(days / 30) + ' 个月前' : Math.floor(days / 365) + ' 年前'; }
            return { covers: covers, targetUrl: target, pinCount: typeof item.pin_count === 'number' ? item.pin_count + ' 张 Pin 图' : '', updated: updated, profileUrl: typeof item.username === 'string' && /^[a-zA-Z0-9_]+$/.test(item.username) ? location.origin + '/' + item.username + '/' : '', id: String(item.id), name: (item.full_name || item.name || item.username).slice(0,300),
              avatar: /^https:\\/\\//.test(image) ? image : '', canFollow: item.blocked_by_me !== true && String(item.id) !== (window.PinmonyProfileApi.currentInfo(page) || {}).viewerId, following: section === 'boards' ? item.followed_by_me === true : item.explicitly_followed_by_me === true };
          });
        }
      } catch (_) { if (g === generation && location.href === address && current(page)) state.error = '读取失败，请重试'; }
      finally { clearTimeout(timer); if (g === generation && state) { state.loading = false; abort = null; } }
      return true;
    }
  };
})();`;
