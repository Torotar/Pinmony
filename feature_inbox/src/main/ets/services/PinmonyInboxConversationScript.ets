// Inbox conversation and text-send contracts verified in the supplied HAR.
export const PIN_INBOX_CONVERSATIONS_API_ENABLED: boolean = true;
export const PIN_INBOX_CONVERSATION_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname) || !window.PinmonyInboxConversationsEnabled) return;
  var list = null, listKey = '', listGeneration = 0, selfId = '', flow = null, stack = [], generation = 0;
  var controllers = [];
  function root() { return /^\\/(?:inbox|messages|updates|notifications)\\/?$/.test(location.pathname); }
  function page() { return location.origin + location.pathname.replace(/\\/$/, '') + '/'; }
  function clean(v) { return typeof v === 'string' ? v.trim().slice(0, 500) : ''; }
  function user(u) {
    if (!u || typeof u.id !== 'string' || !/^\\d+$/.test(u.id)) throw new Error('用户返回格式无效');
    return { profileUrl: /^[a-zA-Z0-9_]+$/.test(u.username || '') ? location.origin + '/' + u.username + '/' : '', id: u.id, self: !!(selfId && u.id === selfId), name: clean(u.full_name) || clean(u.username),
      avatar: /^https:\\/\\//.test(u.image_medium_url || u.image_large_url || '') ? u.image_medium_url || u.image_large_url : '' };
  }
  function valid(s) { return root() && flow === s && s.pageUrl === page(); }
  function publish() {
    if (!flow || !valid(flow) || !window.PinmonyShareBridge) return;
    window.PinmonyShareBridge.inboxState(JSON.stringify(flow));
  }
  async function request(name, operation, options, current) {
    var controller = new AbortController();
    var args = { credentials: 'same-origin', signal: controller.signal,
      headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
        'X-Pinterest-AppState': 'active', 'X-Pinterest-Source-Url': location.pathname,
        'X-Pinterest-Pws-Handler': 'www/index.js' } };
    var form = new URLSearchParams({ source_url: location.pathname, data: JSON.stringify({ options: options, context: {} }) });
    var url = '/resource/' + name + '/' + operation + '/';
    if (operation === 'get') url += '?' + form + '&_=' + Date.now();
    else {
      var csrf = document.cookie.match(/(?:^|;\\s*)csrftoken=([^;]+)/);
      if (!csrf) throw new Error('当前网页会话缺少凭据，请重新登录');
      args.method = 'POST'; args.body = form.toString();
      args.headers['Content-Type'] = 'application/x-www-form-urlencoded'; args.headers['X-CSRFToken'] = decodeURIComponent(csrf[1]);
    }
    controllers.push(controller);
    var timer = setTimeout(function () { controller.abort(); }, 15000);
    try {
      var response = await fetch(url, args);
      if (!response.ok) throw new Error('会话请求失败（HTTP ' + response.status + '），请重试');
      var body;
      try { body = await response.json(); } catch (_) { throw new Error('会话接口未返回 JSON，请检查当前网页登录状态'); }
      if (!current()) throw new Error('stale');
      var r = body.resource_response;
      if (!r || r.status !== 'success' || r.code !== undefined && r.code !== 0 || r.error) throw new Error('会话接口业务状态未成功，请重试');
      var me = body.client_context && body.client_context.user;
      if (me && typeof me.id === 'string') selfId = me.id;
      r.bookmark = r.bookmark || body.resource && body.resource.options && body.resource.options.bookmarks && body.resource.options.bookmarks[0] || '';
      return r;
    } finally { clearTimeout(timer); controllers = controllers.filter(function (c) { return c !== controller; }); }
  }
  function reset() {
    generation++; listGeneration++; controllers.forEach(function (c) { c.abort(); }); controllers = [];
    list = null; listKey = ''; flow = null; stack = []; selfId = '';
  }
  function newFlow(screen, session) {
    generation++;
    var s = { kind: 'nativeFlow', pageUrl: page(), session: session, screen: screen, title: '', loading: true,
      error: '', users: [], messages: [], selectedIds: [], hasMore: false, conversationId: '', bookmark: '' };
    flow = s; publish(); return s;
  }
  async function messages(s, more) {
    s.loading = true; s.error = ''; publish();
    try {
      var options = { conversation_id: s.conversationId, page_size: 25, refresh: false, hide_sys_msg: true,
        field_set_key: ['default_with_reactions_and_deleted_by'] };
      if (more) options.bookmarks = [s.bookmark];
      var r = await request('ConversationMessagesResource', 'get', options, function () { return valid(s); });
      if (r.endpoint_name && r.endpoint_name !== 'v3_get_conversation_messages' || !Array.isArray(r.data)) throw new Error('消息返回格式无效');
      var rows = r.data.map(function (m) {
        if (!m || typeof m.id !== 'string') throw new Error('消息标识无效');
        var pin = m.pin, imgs = pin && pin.images || {}, img = imgs['236x'] || imgs['474x'] || imgs['736x'] || imgs.orig;
        return { id: m.id, text: clean(m.text), image: img && /^https:\\/\\//.test(img.url || '') ? img.url : '',
          pinUrl: pin && /^\\d+$/.test(pin.id || '') ? location.origin + '/pin/' + pin.id + '/' : '',
          createdAt: clean(m.created_at), own: !!(selfId && m.sender && m.sender.id === selfId),
          sender: m.sender ? user(m.sender) : undefined,
          deleted: !!m.deleted_by || m.text === '此消息已被删除',
          reactions: Array.isArray(m.reactions) ? m.reactions.reduce(function (all, group) {
            return all.concat(Object.keys(group || {}).map(function (id) { return group[id]; })
              .filter(function (v) { return ['❤️','😂','😍','😮','👍','👎'].indexOf(v) >= 0; }));
          }, []).slice(0, 20) : [] };
      });
      var seen = {}; s.messages = (more ? s.messages.concat(rows) : rows).filter(function (m) {
        if (seen[m.id]) return false; seen[m.id] = true; return true;
      }).sort(function (a, b) { return Date.parse(a.createdAt) - Date.parse(b.createdAt); });
      s.hasMore = !!r.bookmark && r.bookmark !== '-end-' && r.bookmark !== s.bookmark; s.bookmark = r.bookmark;
    } catch (e) { if (valid(s)) s.error = e.message === 'stale' ? '' : e.name === 'AbortError' ? '会话消息请求超时，请重试' : e.message; }
    finally { if (valid(s)) { s.loading = false; publish(); } }
  }
  async function openChat(id, session, users) {
    if (!/^\\d+$/.test(id || '')) return false;
    var s = newFlow('chat', session); s.conversationId = id; s.users = users || [];
    try {
      var r = await request('ApiResource', 'get', { url: '/v3/conversations/' + id + '/',
        data: { fields: ['conversation.id','conversation.name','conversation.users()','conversation.read_times_ms',
          'user.id','user.username','user.full_name','user.image_medium_url','user.type'] } }, function () { return valid(s); });
      if (r.endpoint_name && r.endpoint_name !== 'v3_get_conversation' || !r.data || r.data.id !== id || !Array.isArray(r.data.users)) throw new Error('会话信息无效');
      s.users = r.data.users.map(user); s.title = clean(r.data.name) || s.users.filter(function (u) { return u.id !== selfId; }).map(function (u) { return u.name; }).join('、');
      await messages(s, false);
    } catch (e) { if (valid(s)) { s.loading = false; s.error = e.name === 'AbortError' ? '会话请求超时，请重试' : e.message; publish(); } }
    return true;
  }
  async function compose(s, query) {
    var token = ++generation; s.loading = true; s.error = ''; publish();
    try {
      var options = query ? { count: 25, term: query, pin_scope: 'pins' } : { field_set_key: 'default' };
      var r = await request(query ? 'ShareSuggestionsTypeaheadResource' : 'ShareSuggestionsResource', 'get', options,
        function () { return valid(s) && token === generation; });
      var rows = query ? r.data && r.data.items : r.data;
      if (!Array.isArray(rows)) throw new Error('用户列表无效');
      s.users = rows.map(user);
    } catch (e) { if (valid(s) && token === generation) s.error = '无法读取联系人，请重试'; }
    finally { if (valid(s) && token === generation) { s.loading = false; publish(); } }
  }
  window.PinmonyInboxConversations = {
    reset: reset,
    pause: function () {
      generation++; listGeneration++; controllers.forEach(function (c) { c.abort(); }); controllers = [];
      if (!list || list.kind !== 'ready') list = null;
      flow = null; stack = [];
    },
    direct: function (peer, session) {
      if (!root() || !peer || peer.id === selfId || !/^\\d+$/.test(peer.id || '') || typeof peer.name !== 'string' || peer.name.length > 300 || !list || list.kind !== 'ready') return false;
      var existing = list.conversations.find(function (c) { return c.users.some(function (u) { return u.id === peer.id; }) && c.users.length <= 2; });
      stack = [];
      if (existing) openChat(existing.id, session, []);
      else { var s = newFlow('compose', session); s.loading = false; s.directContact = true; s.users = [{ profileUrl: /^[a-zA-Z0-9_]+$/.test(peer.username || '') ? location.origin + '/' + peer.username + '/' : '', id: peer.id, name: peer.name, avatar: peer.avatar || '' }]; s.selectedIds = [peer.id]; publish(); this.action('next', '', session); }
      return true;
    },
    read: function (key, changed, current) {
      if (listKey !== key) { list = null; listKey = key; listGeneration++; }
      if (list) return list;
      var token = listGeneration; list = { kind: 'loading', error: '', items: [], conversations: [] }; var pending = list;
      request('ConversationsResource', 'get', { field_set_key: 'default' }, function () { return current() && token === listGeneration && listKey === key; })
        .then(function (r) {
          if (r.endpoint_name && r.endpoint_name !== 'v3_get_conversations' || !Array.isArray(r.data)) throw new Error('会话列表返回格式无效');
          pending.conversations = r.data;
          pending.items = r.data.map(function (c) {
            if (!c || typeof c.id !== 'string' || !Array.isArray(c.users)) throw new Error('会话列表缺少有效 ID 或成员');
            var users = c.users.map(user).filter(function (u) { return u.id !== selfId; }); var last = c.last_message;
            var text = last && clean(last.text) || (last && last.pin ? (last.sender && last.sender.id === selfId ? '你发送了一张 Pin 图' : '发送了一张 Pin 图') : '');
            var date = last && new Date(last.created_at);
            return { id: 'conversation:' + c.id, title: clean(c.name) || users.map(function (u) { return u.name; }).join('、'),
              subtitle: text, profileUrl: users.length === 1 ? users[0].profileUrl || '' : '', imageUrl: users[0] && users[0].avatar || '', enabled: true, unread: !!c.unread,
              timeLabel: date && !isNaN(date.getTime()) ? String(date.getHours()).padStart(2,'0') + ':' + String(date.getMinutes()).padStart(2,'0') : '' };
          }); pending.kind = 'ready'; changed();
        }).catch(function (e) { if (current() && token === listGeneration) {
          pending.kind = 'failed'; pending.error = e.name === 'AbortError' ? '会话列表请求超时，请重试' :
            e instanceof TypeError ? '会话列表网络请求失败，请重试' : clean(e.message); changed();
        } });
      return list;
    },
    open: function (id, session) {
      if (!root()) return false;
      if (id.indexOf('news-menu:') === 0 && window.PinmonyInboxApi && window.PinmonyInboxApi.find(id.slice(10))) {
        var news = window.PinmonyInboxApi.find(id.slice(10));
        stack = []; var menu = newFlow('updatesMenu', session); menu.loading = false;
        menu.notificationPinId = news.notificationPinId || ''; menu.canUnsubscribePin = !!menu.notificationPinId;
        menu.newsId = news.newsId || '';
        publish(); return true;
      }
      if (id === 'compose') { stack = []; compose(newFlow('compose', session), ''); return true; }
      if (id.indexOf('contact:') === 0 && window.PinmonyInboxContactsApi) {
        var contact = window.PinmonyInboxContactsApi.find(id.slice(8));
        if (!contact) return false;
        var existing = list && list.conversations.find(function (c) {
          return c.users.some(function (u) { return u.id === contact.userId; });
        });
        stack = [];
        if (existing) openChat(existing.id, session, []);
        else {
          var s = newFlow('compose', session); s.loading = false;
          s.directContact = true;
          s.users = [{ profileUrl: /^[a-zA-Z0-9_]+$/.test(contact.username || '') ? location.origin + '/' + contact.username + '/' : '', id: contact.userId, name: contact.title, avatar: contact.imageUrl }];
          s.selectedIds = [contact.userId]; publish(); this.action('next','',session);
        }
        return true;
      }
      var c = list && list.conversations.find(function (v) { return 'conversation:' + v.id === id; });
      if (c) { stack = []; openChat(c.id, session, []); return true; }
      return false;
    },
    action: function (action, value, session) {
      var s = flow; if (!s || !valid(s) || s.session !== session) return false;
      if (action === 'hideNews' && s.screen === 'updatesMenu' && !s.messageBusy && /^\\d+$/.test(s.newsId || '')) {
        s.messageBusy = true; s.error = ''; publish();
        request('ApiResource', 'update', { url: '/v3/news_hub/hide/batch/',
          data: { news_ids: [s.newsId], should_hide: true } }, function () { return valid(s); })
          .then(function (r) {
            if (r.endpoint_name !== 'v3_hide_batch_by_news_ids' || r.data !== null) throw new Error('更新删除结果未确认');
            if (!valid(s)) return;
            window.PinmonyInboxApi.hideConfirmed(s.newsId); s.newsHidden = true;
          }).catch(function () { if (valid(s)) s.error = '删除更新未确认，请刷新列表后确认'; })
          .finally(function () { if (valid(s)) { s.messageBusy = false; publish(); } });
        return true;
      }
      if (action === 'undoNews' && s.screen === 'updatesMenu' && s.newsHidden && !s.messageBusy && /^\\d+$/.test(s.newsId || '')) {
        s.messageBusy = true; s.error = ''; publish();
        request('ApiResource', 'update', { url: '/v3/news_hub/hide/batch/',
          data: { news_ids: [s.newsId], should_hide: false } }, function () { return valid(s); })
          .then(function (r) {
            if (r.endpoint_name !== 'v3_hide_batch_by_news_ids' || r.data !== null) throw new Error('撤销删除结果未确认');
            // Keep the conversation flow alive. PinmonyInboxRefresh also resets this flow,
            // which leaves the native sheet waiting on a snapshot that can never arrive.
            if (valid(s)) { s.newsHidden = false; publish(); }
          }).catch(function () { if (valid(s)) s.error = '撤销删除未确认，请刷新更新列表后确认'; })
          .finally(function () { if (valid(s)) { s.messageBusy = false; publish(); } });
        return true;
      }
      if (action === 'unsubscribePin' && s.screen === 'updatesMenu' && s.canUnsubscribePin &&
          !s.messageBusy && !s.unsubscribedPin && /^\\d+$/.test(s.notificationPinId || '')) {
        s.messageBusy = true; s.error = ''; publish();
        request('ApiResource', 'create', { url: '/v3/settings/notifications/objects/',
          data: { object_ids_to_unsubscribe: [s.notificationPinId] } }, function () { return valid(s); })
          .then(function (r) { if (r.endpoint_name !== 'v3_update_object_subscriptions_for_notifications' ||
            !r.data || r.data[s.notificationPinId] !== false) throw new Error('更新订阅结果未确认');
            if (valid(s)) s.unsubscribedPin = true;
          }).catch(function () { if (valid(s)) s.error = '更新订阅结果未确认，请重新读取后确认'; })
          .finally(function () { if (valid(s)) { s.messageBusy = false; publish(); } });
        return true;
      }
      if ((action === 'blockUser' || action === 'unblockUser') && s.screen === 'settings' &&
          !s.messageBusy && /^\\d+$/.test(value || '') && s.users.some(function (u) { return u.id === value && !u.self; })) {
        s.messageBusy = true; s.error = ''; publish();
        var blockOperation = action === 'blockUser' ? 'update' : 'delete';
        var blockEndpoint = action === 'blockUser' ? 'v3_block_user' : 'v3_unblock_user';
        request('ApiResource', blockOperation, { url: '/v3/users/' + value + '/block/' }, function () { return valid(s); })
          .then(function (r) {
            if (r.endpoint_name !== blockEndpoint || r.data !== null) throw new Error('屏蔽结果未确认');
            if (valid(s)) {
              s.blocked = action === 'blockUser'; s.blockedUserId = value;
              s.blockRevision = (s.blockRevision || 0) + 1;
            }
          }).catch(function () { if (valid(s)) s.error = action === 'blockUser' ? '屏蔽未确认，请重试' : '取消屏蔽未确认，请重试'; })
          .finally(function () { if (valid(s)) { s.messageBusy = false; publish(); } });
        return true;
      }
      if ((action === 'react' || action === 'deleteMessage') && s.screen === 'chat' &&
          !s.loading && !s.sending && !s.messageBusy) {
        var parts = String(value || '').split('|'), id = parts[0], reaction = parts[1];
        var target = s.messages.find(function (m) { return m.id === id; });
        if (!target || target.deleted || !/^\\d+$/.test(id) || action === 'deleteMessage' && !target.own ||
            action === 'react' && ['❤️','😂','😍','😮','👍','👎'].indexOf(reaction) < 0) return false;
        s.messageBusy = true; s.error = ''; publish();
        request('ApiResource', action === 'react' ? 'create' : 'delete',
          action === 'react' ? { url: '/v3/conversations/messages/' + id + '/', data: { reaction_text: reaction } } :
          { url: '/v3/conversations/messages/' + id + '/' }, function () { return valid(s); })
          .then(async function (r) {
            if (r.endpoint_name !== (action === 'react' ? 'v3_post_reaction_message' : 'v3_delete_conversation_message') ||
              !r.data || r.data.id !== id || action === 'deleteMessage' && r.data.text !== '此消息已被删除')
              throw new Error('消息操作结果未能确认');
            if (!valid(s)) return;
            list = null; listGeneration++;
            await messages(s, false);
          }).catch(function () { if (valid(s)) s.error = '消息操作未确认，请重新读取会话后确认'; })
          .finally(function () { if (valid(s)) { s.messageBusy = false; publish(); } });
        return true;
      }
      if (action === 'send' && s.screen === 'chat' && !s.loading && !s.sending) {
        var text = typeof value === 'string' ? value.trim() : '';
        if (!text || text.length > 2000 || !/^\\d+$/.test(s.conversationId || '')) return false;
        s.sending = true; s.sendError = ''; publish();
        request('ConversationMessagesResource', 'create', { conversation_id: s.conversationId,
          text: text, field_set_key: ['default_with_reactions'] }, function () { return valid(s); })
          .then(function (r) {
            var m = r.data;
            if (r.endpoint_name && r.endpoint_name !== 'v3_add_conversation_message' || !m || typeof m.id !== 'string' ||
              !/^\\d+$/.test(m.id) || !m.sender ||
              typeof m.sender.id !== 'string' || !/^\\d+$/.test(m.sender.id) || m.sender.id !== selfId) throw new Error('发送结果未能确认，请先重新读取会话');
            if (!valid(s)) return;
            s.messages = s.messages.filter(function (old) { return old.id !== m.id; }).concat([{
              id: m.id, text: typeof m.text === 'string' ? m.text : text, image: '', pinUrl: '', createdAt: m.created_at || '', own: true
            }]);
            s.sentRevision = (s.sentRevision || 0) + 1;
            list = null; listGeneration++;
          }).catch(function (e) { if (valid(s)) s.sendError = e.name === 'AbortError' ?
            '发送结果未知，请重新读取会话后确认，避免重复发送' : '发送未确认，请重新读取会话后确认'; })
          .finally(function () { if (valid(s)) { s.sending = false; publish(); } });
        return true;
      }
      if (action === 'back') { generation++; flow = stack.pop() || null;
        if (flow) { if (flow.screen === 'compose') flow.loading = false; publish(); }
        else window.PinmonyShareBridge.inboxState(JSON.stringify({ kind:'nativeFlow',screen:'closed',session:session,pageUrl:page() })); return true; }
      if (action === 'settings' && s.screen === 'chat' && !s.loading) {
        stack.push(s); var settings = newFlow('settings', session); settings.users = s.users; settings.loading = false; settings.title = '消息设置';
        var blockTarget = settings.users.filter(function (u) { return !u.self; })[0];
        settings.blockedUserId = blockTarget ? blockTarget.id : ''; settings.blocked = false; settings.blockRevision = 0;
        publish(); return true;
      }
      if (action === 'select' && s.screen === 'compose' && !s.loading && s.users.some(function (u) { return u.id === value; })) {
        s.selectedIds = s.selectedIds.indexOf(value) >= 0 ? s.selectedIds.filter(function (id) { return id !== value; }) : s.selectedIds.concat([value]); publish(); return true;
      }
      if (action === 'search' && s.screen === 'compose') { compose(s, clean(value)); return true; }
      if (action === 'more' && s.screen === 'chat' && !s.loading && s.hasMore) { messages(s, true); return true; }
      if (action === 'retry') { if (s.screen === 'chat') openChat(s.conversationId, session, s.users); else if (s.screen === 'compose') compose(s,''); return true; }
      if (action === 'next' && s.screen === 'compose' && s.selectedIds.length && !s.loading) {
        s.loading = true; s.error = ''; publish();
        request('ConversationsResource','create',{ user_ids: s.selectedIds, emails: [] },function () { return valid(s); })
          .then(function (r) { if (r.endpoint_name !== 'v3_create_conversation' || !r.data || typeof r.data.id !== 'string') throw new Error('会话创建未确认');
            s.loading = false; if (!s.directContact) stack.push(s); openChat(r.data.id, session, s.users); })
          .catch(function () { if (valid(s)) { s.loading = false; s.error = '无法创建会话，请重试'; publish(); } }); return true;
      }
      return false;
    }
  };
})();`;

