// Same-origin Pinterest website resource, using the existing ArkWeb session.
export const PIN_INBOX_API_ENABLED: boolean = true;
export const PIN_INBOX_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  if (window.PinmonyNativeInboxUpdatesEnabled === true) {
    var nativeRows = [];
    window.PinmonyInboxApi = {
      installNative:function(page,rows){ if(page !== location.origin + location.pathname.replace(/\\/$/,'') + '/' || !Array.isArray(rows) || rows.length > 2000)return false; nativeRows = rows; return true; },
      read:function(){return {kind:'ready',items:nativeRows,hasMore:false,moreLoading:false,moreError:''};},
      find:function(id){return nativeRows.find(function(row){return row.id === id;}) || null;},
      hideConfirmed:function(id){nativeRows = nativeRows.filter(function(row){return row.newsId !== id;});},
      reset:function(){nativeRows = [];},pause:function(){},poll:function(){return false;},more:function(){return false;}
    }; return;
  }
  var key = '', generation = 0, controller = null, state = null;
  var fields = ['board.name','board.id','board.images[170x]','board.image_cover_url',
    'board.image_thumbnail_urls[100x]','board.subscribed_to_notifications','board.type',
    'interest.background_color','interest.id','interest.type','interest.images[236x]','interest.name',
    'pin.description','pin.id','pin.image_signature','pin.images[150x150,345x]',
    'pin.subscribed_to_notifications','pin.title','pin.tracking_params','pin.type',
    'user.full_name','user.id','user.image_large_url','user.recent_pin_images[200x]',
    'user.subscribed_to_notifications','user.type'];
  function reset() {
    generation++; if (controller) controller.abort();
    controller = null; key = ''; state = null;
  }
  function clean(v) { return typeof v === 'string' ? v.trim().slice(0, 500) : ''; }
  function label(v, mapping) {
    return clean(v).replace(/\\{([^{}]+)\\}/g, function (_, name) {
      return clean(mapping && mapping[name] && mapping[name].t) || _;
    });
  }
  function image(v) { return /^https:\\/\\//i.test(v || '') ? v : ''; }
  function map(row, g) {
    if (!row || row.type !== 'news' || !clean(row.id)) throw new Error('Invalid news');
    var title = label(row.header_text || row.title_text, row.text_mapping);
    if (!title || /\\{[^{}]+\\}/.test(title)) throw new Error('Invalid title');
    var obj = row.object_map && row.header_icon_object_ids && row.object_map[row.header_icon_object_ids[0]];
    var imgs = obj && obj.images;
    var url = image(row.header_icon_image_url) || image(imgs && imgs['150x150'] && imgs['150x150'].url) ||
      image(imgs && imgs['345x'] && imgs['345x'].url) || image(obj && (obj.image_cover_url || obj.image_large_url));
    return { id: 'inbox-news-api-' + g + '-' + row.id, newsId: row.id, title: title,
      subtitle: label(row.content_text || row.sub_header_text, row.text_mapping), imageUrl: url, enabled: false,
      notificationPinId: obj && obj.type === 'pin' && /^\\d+$/.test(obj.id || '') ? obj.id : '',
      updatedAt: clean(row.last_updated_at), unread: typeof row.unread === 'boolean' ? row.unread : undefined };
  }
  function request(more, changed, current, quiet) {
    var g = generation, page = key, previous = state.bookmark;
    if (more) { state.moreLoading = true; state.moreError = ''; }
    controller = new AbortController();
    var abort = controller;
    var timer = setTimeout(function () { abort.abort(); }, 12000);
    var options = { url: '/v3/news_hub/feed/', data: { field_set_key: 'unauthed' },
      redux_normalize_feed: true, field_sets: fields };
    if (more) options.bookmarks = [previous];
    var query = new URLSearchParams({ source_url: '/inbox/',
      data: JSON.stringify({ options: options, context: {} }), _: String(Date.now()) });
    fetch('/resource/ApiResource/get/?' + query, { credentials: 'same-origin', signal: abort.signal,
      headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
        'X-Pinterest-Pws-Handler': 'www/index.js' } }).then(function (response) {
      if (!response.ok) throw new Error('更新请求失败（HTTP ' + response.status + '），请重试');
      return response.json().catch(function () { throw new Error('更新接口未返回 JSON，请检查当前网页登录状态'); });
    }).then(function (body) {
      if (g !== generation || page !== key || !current()) return;
      var r = body && body.resource_response;
      if (!r || r.status !== 'success' || r.code !== undefined && r.code !== 0 || r.error) throw new Error('更新接口业务状态未成功，请重试');
      if (!Array.isArray(r.data) || r.endpoint_name && r.endpoint_name !== 'v3_get_news_hub_feed') throw new Error('更新返回格式无效');
      var rows = r.data.map(function (row) { return map(row, g); });
      var combined = more ? state.items.concat(rows) : quiet ? rows.concat(state.items) : rows;
      var seen = {};
      state.items = combined.filter(function (row) { if (seen[row.id]) return false; seen[row.id] = true; return true; });
      if (!quiet) {
        state.bookmark = clean(r.bookmark);
        state.hasMore = !!state.bookmark && state.bookmark !== '-end-' && state.bookmark !== previous;
      }
      state.kind = 'ready'; state.moreLoading = false; state.moreError = ''; changed();
    }).catch(function (e) {
      if (g !== generation || page !== key || !current()) return;
      if (quiet) return;
      if (more) { state.moreLoading = false; state.moreError = '加载更多失败，请重试'; }
      else {
        state.kind = 'failed'; state.error = e.name === 'AbortError' ? '更新请求超时，请重试' :
          e.name === 'TypeError' ? '更新网络请求失败，请重试' : /^更新/.test(e.message || '') ? e.message : '更新数据结构不符合预期，请重试';
      }
      changed();
    }).finally(function () { clearTimeout(timer); if (controller === abort) controller = null; });
  }
  window.PinmonyInboxApi = {
    poll: function (changed, current) {
      if (!state || state.kind !== 'ready' || controller || !current()) return false;
      request(false, changed, current, true); return true;
    },
    find: function (id) { return state && state.kind === 'ready' ? state.items.find(function (row) { return row.id === id; }) : null; },
    hideConfirmed: function (id) { if (state && state.kind === 'ready') state.items = state.items.filter(function (row) { return row.newsId !== id; }); },
    reset: reset,
    pause: function () {
      generation++; if (controller) controller.abort(); controller = null;
      if (state && state.kind === 'ready') state.moreLoading = false;
      else state = null;
    },
    read: function (page, changed, current) {
      if (!window.PinmonyInboxApiEnabled) { reset(); return null; }
      if (page !== key) reset();
      if (!state) {
        key = page; state = { kind: 'loading', items: [], bookmark: '', hasMore: false,
          moreLoading: false, moreError: '' }; request(false, changed, current);
      }
      return state;
    },
    more: function (changed, current) {
      if (!state || state.kind !== 'ready' || !state.hasMore || state.moreLoading || !current()) return false;
      request(true, changed, current); changed(); return true;
    }
  };
})();`;
