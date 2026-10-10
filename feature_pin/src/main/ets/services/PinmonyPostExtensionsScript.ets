// Confirmed website contracts only; disable independently for manual rollback.
export const PIN_POST_EXTENSIONS_ENABLED: boolean = true;
export const PIN_POST_EXTENSIONS_SCRIPT: string = `
(function () {
  var api = window.PinmonyPostApi;
  if (!api || window.PinmonyPostExtensionsEnabled !== true) return;
  var comments = null, boards = null, previews = {}, saved = {}, feedback = null, version = 0;
  var saveVersion = 0, restore = null, undo = null;
  var originalReset = api.reset;
  api.reset = function () { comments = null; boards = null; previews = {}; feedback = null; version++;
    saveVersion++; restore = null; undo = null; saved = {}; originalReset(); };
  function id(pin) { var m = String(pin).match(/\\/pin\\/(\\d+)/); return m ? m[1] : ''; }
  function valid(state, slot) { return api.currentPin(state.pin) && state === slot; }
  function clean(value) { return typeof value === 'string' ? value.trim() : ''; }
  function image(value) { return /^https:\\/\\/(?:i|s)\\.pinimg\\.com\\//.test(value || '') ? value : ''; }
  function relayPin(pin) {
    var found = null;
    Array.prototype.some.call(document.querySelectorAll('script[data-relay-completed-request]'), function (node) {
      var match = (node.textContent || '').match(/__PWS_RELAY_REGISTER_COMPLETED_REQUEST__\\(\\s*"[^"]*"\\s*,\\s*(\\{[\\s\\S]*\\})\\s*\\);?\\s*$/);
      if (!match) return false;
      try { var data = JSON.parse(match[1]), p = data.data && data.data.v3GetPinQueryv2 && data.data.v3GetPinQueryv2.data;
        if (p && String(p.entityId) === id(pin)) { found = p; return true; }
      } catch (_) {} return false;
    }); return found;
  }
  function aggregate(pin) {
    var p = relayPin(pin), value = p && p.aggregatedPinData && p.aggregatedPinData.entityId;
    return /^\\d+$/.test(String(value || '')) ? String(value) : api.aggregateId(pin);
  }
  function cursor(result) { return typeof result.bookmark === 'string' ? result.bookmark : ''; }
  function mapComment(item) {
    if (!item || !/^\\d+$/.test(String(item.id || ''))) return null;
    var photo = item.type === 'userdiditdata', user = item.user || {}, images = item.images || [];
    var own = !!api.sessionUserId() && String(user.id) === api.sessionUserId();
    return { id: String(item.id), type: item.type, text: clean(photo ? item.details : item.text),
      profileUrl: /^[a-zA-Z0-9_]+$/.test(user.username || '') ? location.origin + '/' + user.username + '/' : '',
      name: clean(user.full_name) || clean(user.username), avatar: image(user.image_medium_url),
      createdAt: clean(photo ? item.done_at : item.created_at), imageUrl: image(images[0] && images[0].originals && images[0].originals.url),
      likeCount: photo ? item.like_count || 0 : item.reaction_counts && item.reaction_counts['1'] || 0,
      liked: photo ? item.liked_by_me === true : item.reaction_by_me === 1,
      canLike: photo || item.type === 'aggregatedcomment', canEdit: own && item.type === 'aggregatedcomment',
      canDelete: own && (photo || item.type === 'aggregatedcomment'), canReply: photo || item.type === 'aggregatedcomment', replyCount: item.comment_count || 0,
      replies: [], repliesOpen: false, repliesLoading: false, repliesError: '', busy: false };
  }
  function merge(old, incoming) {
    incoming.forEach(function (item) { if (item && !old.some(function (p) { return p.id === item.id; })) old.push(item); }); return old;
  }
  async function loadComments(state, append) {
    if (!valid(state, comments) || state.loading || append && state.ended) return false;
    state.loading = true; state.error = ''; var previous = state.bookmark;
    try {
      var options = { aggregated_pin_id: state.aggregate, comment_featured_ids: [], page_size: 25, redux_normalize_feed: true, is_reversed: false };
      if (append) options.bookmarks = [previous];
      var result = await api.resourceRequest(state.pin, 'UnifiedCommentsResource', 'get', options, function () { return comments === state; });
      if (!Array.isArray(result.data)) throw new Error('评论返回格式无效');
      state.items = merge(append ? state.items.slice() : [], result.data.map(mapComment)); state.bookmark = cursor(result);
      state.ended = !state.bookmark || state.bookmark === '-end-' || append && state.bookmark === previous || !result.data.length;
    } catch (e) { if (valid(state, comments)) state.error = e.message; }
    finally { if (valid(state, comments)) state.loading = false; } return true;
  }
  api.commentsStart = function (pin) {
    if (!api.currentPin(pin)) return false;
    var state = comments = { pin: pin, token: ++version, aggregate: aggregate(pin), loading: false, error: '', items: [], bookmark: '', ended: false,
      busy: false, uncertain: false, mutationVersion: 0, actionError: '' };
    if (!state.aggregate) { state.error = '当前帖子缺少评论聚合标识，请稍后重试'; return false; }
    loadComments(state, false); return true;
  };
  api.commentsRead = function (pin) { return comments && comments.pin === pin && api.currentPin(pin) ? comments : null; };
  api.commentsClose = function () { comments = null; };
  api.commentsMore = function (pin) { return comments && !comments.busy && comments.pin === pin && loadComments(comments, comments.items.length > 0); };
  function findComment(state, commentId) {
    var found = null;
    state.items.some(function (item) { found = item.id === commentId ? item : item.replies.find(function (reply) { return reply.id === commentId; }); return !!found; });
    return found;
  }
  api.commentPhotoBegin = function (pin) {
    if (!comments || comments.pin !== pin || !valid(comments, comments) || comments.loading || comments.busy || comments.uncertain) return false;
    comments.busy = true; comments.photoPending = true; comments.actionError = ''; return true;
  };
  api.commentPhotoFail = function (pin) {
    if (!comments || comments.pin !== pin || !comments.photoPending) return;
    comments.photoPending = false; comments.busy = false; comments.actionError = '图片上传未确认，尚未提交评论，请重新选择图片';
  };
  api.commentWrite = async function (pin, encoded) {
    var state = comments, value;
    try { value = JSON.parse(encoded); } catch (_) { return false; }
    if (!state || state.pin !== pin || !valid(state, comments) || state.loading || state.uncertain ||
        state.busy && !(state.photoPending && value && value.action === 'photo')) return false;
    if (!value || !['create', 'reply', 'edit', 'delete', 'photo'].includes(value.action)) return false;
    var item = value.id && findComment(state, value.id), text = clean(value.text), name, verb, options, endpoint;
    if (value.action !== 'delete' && value.action !== 'photo' && (!text || text.length > 5000)) return false;
    if (text.length > 5000) return false;
    if (value.action === 'photo') {
      if (!state.photoPending || !/^[a-f0-9]{32}$/.test(value.signature || '')) return false;
      name = 'ApiResource'; verb = 'create'; endpoint = 'v3_create_user_did_it_data';
      options = { url: '/v3/did_it/', data: { details: text, image_signatures: [value.signature], pin: id(pin),
        fields: ['pin.id','user.id','user.full_name','user.username','user.image_medium_url',
          'userdiditdata.id','userdiditdata.type','userdiditdata.details','userdiditdata.user()',
          'userdiditdata.images[150x150,200x,736x,750x]','userdiditdata.pin()','userdiditdata.image_signatures',
          'userdiditdata.like_count','userdiditdata.liked_by_me','userdiditdata.comment_count','userdiditdata.done_at'], text_tags: '[]' } };
      state.photoPending = false;
    } else if (value.action === 'create' || value.action === 'reply') {
      if (value.action === 'reply' && (!item || !item.canReply)) return false;
      name = value.action === 'reply' ? item.type === 'userdiditdata' ? 'DidItCommentsResource' : 'AggregatedCommentReplyResource' : 'AggregatedCommentResource'; verb = 'create';
      endpoint = value.action === 'reply' ? item.type === 'userdiditdata' ? 'v3_create_user_did_it_data_comment' : 'v3_create_aggregated_comment_reply' : 'v3_create_aggregated_pin_data_comment';
      options = { force: false, objectId: item ? item.id : state.aggregate, pinId: id(pin), tags: '[]', text: text };
    } else if (value.action === 'edit') {
      if (!item || !item.canEdit) return false;
      name = 'AggregatedCommentResource'; verb = 'update'; endpoint = 'v3_update_aggregated_comment';
      options = { commentId: item.id, force: false, tags: '[]', text: text };
    } else {
      if (!item || !item.canDelete) return false;
      name = item.type === 'userdiditdata' ? 'ApiResource' : 'AggregatedCommentResource'; verb = 'delete';
      endpoint = item.type === 'userdiditdata' ? 'v3_delete_user_did_it_data' : 'v3_delete_aggregated_comment';
      options = item.type === 'userdiditdata' ? { url: '/v3/did_it/' + item.id + '/', data: { pin: id(pin) } } : { commentId: item.id };
    }
    state.busy = true; state.actionError = '';
    try {
      var response = await api.resourceRequest(pin, name, verb, options, function () { return comments === state; });
      if (!valid(state, comments)) return false;
      var data = response.data;
      if (response.code !== 0 || response.endpoint_name !== endpoint) throw new Error('unconfirmed');
      if (value.action === 'delete') {
        if (item.type === 'userdiditdata' ? !data || String(data.id) !== state.aggregate : data !== null) throw new Error('unconfirmed');
        state.items = state.items.filter(function (row) { row.replies = row.replies.filter(function (reply) { return reply.id !== item.id; }); return row.id !== item.id; });
      } else {
        var mapped = mapComment(data);
        if (!mapped || mapped.text !== text || !api.sessionUserId() || String((data.user || {}).id) !== api.sessionUserId() ||
            value.action === 'edit' && mapped.id !== item.id) throw new Error('unconfirmed');
        if (value.action === 'photo' && (mapped.type !== 'userdiditdata' || !data.pin || String(data.pin.id) !== id(pin) ||
            !Array.isArray(data.image_signatures) || data.image_signatures.indexOf(value.signature) < 0)) throw new Error('unconfirmed');
        if (value.action === 'reply') { item.replies.push(mapped); item.repliesOpen = true; }
        else if (value.action === 'edit') { Object.assign(item, mapped); }
        else state.items.unshift(mapped);
      }
      state.mutationVersion++; state.busy = false;
      await loadComments(state, false);
      return true;
    } catch (_) {
      if (valid(state, comments)) { state.uncertain = true; state.actionError = '操作结果未确认，请关闭后重新读取核对；不会重复提交'; }
      return false;
    } finally { if (valid(state, comments)) state.busy = false; }
  };
  api.commentReplies = async function (pin, commentId) {
    var state = comments, item = state && state.items.find(function (p) { return p.id === commentId; });
    if (!state || !valid(state, comments) || state.pin !== pin || !item || item.repliesLoading || state.busy) return false;
    if (item.repliesOpen && !item.repliesError) { item.repliesOpen = false; return true; }
    item.repliesOpen = true;
    if (item.replies.length && !item.repliesError) return true;
    item.repliesLoading = true; item.repliesError = '';
    try {
      var response = await api.resourceRequest(pin, 'AggregatedCommentReplyFeedResource', 'get',
        { isUnifiedComment: true, objectId: commentId, redux_normalize_feed: true }, function () { return comments === state; });
      if (!Array.isArray(response.data)) throw new Error('回复返回格式无效');
      item.replies = merge([], response.data.map(mapComment));
      if (cursor(response) && cursor(response) !== '-end-') item.repliesError = '还有更多回复，分页接口尚未确认';
    } catch (e) { if (valid(state, comments)) item.repliesError = e.message; }
    finally { if (valid(state, comments)) item.repliesLoading = false; } return true;
  };
  api.commentLike = async function (pin, commentId) {
    var state = comments, item = null;
    if (!state || state.pin !== pin || !valid(state, comments) || state.loading || state.busy || state.uncertain) return false;
    state.items.some(function (p) { item = p.id === commentId ? p : p.replies.find(function (r) { return r.id === commentId; }); return !!item; });
    if (!item || !item.canLike || item.busy) return false;
    item.busy = true; state.busy = true; state.actionError = ''; var selected = !item.liked;
    try {
      var photo = item.type === 'userdiditdata';
      var response = await api.resourceRequest(pin, 'ApiResource', selected ? 'create' : 'delete',
        { url: photo ? '/v3/did_it/' + item.id + '/like/' : '/v3/aggregated_comments/' + item.id + '/react/',
          data: photo ? {} : { reaction_type: 1 } }, function () { return comments === state; });
      if (response.endpoint_name !== (photo ? selected ? 'v3_like_user_did_it_data' : 'v3_unlike_user_did_it_data' :
          selected ? 'v3_add_reaction_to_comment' : 'v3_delete_reaction_from_comment') ||
          response.code !== 0 || (photo ? response.data !== null : !response.data || String(response.data.id) !== item.id)) throw new Error('未确认评论点赞结果');
      // Mutation response omits counts: refresh the corresponding list instead of inventing a count.
      if (state.items.indexOf(item) >= 0) await loadComments(state, false);
      else { var parent = state.items.find(function (p) { return p.replies.indexOf(item) >= 0; });
        if (parent) { parent.replies = []; parent.repliesOpen = false; await api.commentReplies(pin, parent.id); } }
    } catch (e) { if (valid(state, comments)) { state.uncertain = true; state.actionError = '点赞结果未确认，请重新读取核对；不会重复提交'; } }
    finally { item.busy = false; if (valid(state, comments)) state.busy = false; } return true;
  };
  api.previewRead = function (pin, readOnly) {
    if (!api.currentPin(pin)) return null;
    var state = previews[id(pin)], aggregated = aggregate(pin);
    if (!aggregated) return null;
    if (readOnly) return state && state.aggregate === aggregated ? state : null;
    if (!state || state.aggregate !== aggregated) {
      state = previews[id(pin)] = { pin: pin, aggregate: aggregated, text: '', loading: true, empty: false, error: '' };
      api.resourceRequest(pin, 'UnifiedCommentsPreviewResource', 'get', { aggregated_pin_id: aggregated },
        function () { return previews[id(pin)] === state; }).then(function (response) {
          if (!Array.isArray(response.data)) throw new Error('评论预览无效');
          state.empty = response.data.length === 0;
          var first = response.data[0], comment = first && (first.unified_comment || first.aggregated_comment || first.user_did_it_data);
          state.text = comment ? clean(comment.text) || clean(comment.details) : '';
        }).catch(function (error) { state.text = ''; state.error = error.message === '评论预览请求信息尚未就绪，请重试' ?
          error.message : '评论预览加载失败'; }).finally(function () { state.loading = false;
          if (api.currentPin(pin) && window.PinmonyDetailRefresh) window.PinmonyDetailRefresh(); });
    } return state;
  };
  api.previewRetry = function (pin) {
    var state = previews[id(pin)];
    if (!api.currentPin(pin) || !state || state.loading || !state.error) return false;
    delete previews[id(pin)];
    return !!api.previewRead(pin);
  };
  function mapBoard(p) {
    if (!p || !/^\\d+$/.test(String(p.id || ''))) return null;
    return { id: String(p.id), name: clean(p.name), imageUrl: image(p.image_cover_url || p.image_cover_hd_url),
      enabled: Array.isArray(p.access) && p.access.indexOf('write') >= 0, secret: p.privacy === 'secret' };
  }
  async function loadBoards(state) {
    state.loading = true; state.error = '';
    var stage = '帖子信息';
    try {
      // Obtain the authenticated user from the current session's response, never desktop IDs.
      var pin = api.homeMenuPinData && api.homeMenuPinData(state.pin);
      if (!pin || String(pin.id) !== id(state.pin) || !api.sessionUserId()) {
        var response = await api.resourceRequest(state.pin, 'PinResource', 'get', { id: id(state.pin), field_set_key: 'auth_web_main_pin',
          noCache: true, fetch_visual_search_objects: false, get_page_metadata: false,
          add_fields: 'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin' }, function () { return boards === state; });
        pin = response.data;
      }
      if (!valid(state, boards)) return;
      if (!pin || String(pin.id) !== id(state.pin)) throw new Error('帖子信息未能确认');
      state.raw = pin; state.userId = api.sessionUserId();
      if (!state.userId) throw new Error('当前会话缺少登录用户，请重新登录');
      stage = '图板列表';
      var result = await api.resourceRequest(state.pin, 'BoardPickerBoardsResource', 'get', { pin_id: id(state.pin), field_set_key: 'profile_grid_item',
        shortlist_length: 2, shortlist_suggestions: 3, user_id: state.userId }, function () { return boards === state; });
      if (!result.data || !Array.isArray(result.data.all_boards) || !Array.isArray(result.data.boards_shortlist)) throw new Error('图板列表返回无效');
      state.items = result.data.all_boards.map(mapBoard).filter(Boolean); state.shortlist = result.data.boards_shortlist.map(mapBoard).filter(Boolean);
      if (window.PinmonyProfileOrganizeEnabled === true)
        state.items.push({ id: 'profile-quick-saves', name: '个人资料', imageUrl: '', enabled: true, secret: false });
      // Query captured from the board picker, not a guessed GraphQL operation. Failure leaves manual naming available.
      api.resourceRequest(state.pin, '', '', {}, function () { return boards === state; }, {
        queryHash: '22ab0618812233f56510dbaeb1d76e342780a08cabb50624896db33300f9070e', variables: { pinId: id(state.pin) }
      }).then(function (data) {
        var p = data.v3GetPinQueryv2 && data.v3GetPinQueryv2.data;
        if (p && p.id === btoa('Pin:' + id(state.pin)) && Array.isArray(p.boardTitleSuggestions))
          state.suggestions = p.boardTitleSuggestions.map(function (item) { return clean(item.title); }).filter(Boolean);
      }).catch(function () {});
    } catch (e) { if (valid(state, boards)) state.error = stage + '读取失败：' + e.message; }
    finally { if (valid(state, boards)) state.loading = false; }
  }
  api.boardsStart = function (pin) { if (!api.currentPin(pin)) return false;
    boards = { pin: pin, loading: true, error: '', feedback: '', busy: false, items: [], shortlist: [], userId: '', raw: null,
      savedId: saved[id(pin)] && saved[id(pin)].id || '', savedBoard: saved[id(pin)] && saved[id(pin)].board || '', suggestions: [] };
    loadBoards(boards); return true;
  };
  api.boardsRead = function (pin) { return boards && boards.pin === pin && valid(boards, boards) ? boards : null; };
  api.boardsClose = function () { boards = null; };
  api.boardsSave = async function (pin, boardId) {
    var state = boards, board = state && state.items.concat(state.shortlist).find(function (p) { return p.id === boardId && p.enabled; });
    if (!state || state.pin !== pin || !valid(state, boards) || state.busy || state.loading || !board) return false;
    state.busy = true; state.error = ''; state.feedback = '';
    try {
      var quickSave = boardId === 'profile-quick-saves';
      var options = { pin_id: id(pin), user_id: state.userId }, tracking = state.raw.client_tracking_params || state.raw.tracking_params;
      if (!quickSave) options.board_id = boardId;
      if (tracking) options.clientTrackingParams = tracking;
      console.info('PinmonyDiagnostic: save request');
      var result = await api.resourceRequest(pin, 'RepinResource', 'create', options, function () { return boards === state; });
      if (result.endpoint_name !== 'v3_repin_handler' || result.code !== 0 || !result.data || !/^\\d+$/.test(String(result.data.id || '')) ||
          !result.data.board || (quickSave ? result.data.board.layout !== 'quick_saves' ||
          !result.data.pinner || String(result.data.pinner.id) !== state.userId :
          String(result.data.board.id) !== boardId)) throw new Error('未能确认收藏结果，请重新读取图板');
      saved[id(pin)] = { id: String(result.data.id), board: board.name, tracking: tracking || '', busy: false,
        user: api.sessionUserId(), page: location.href, version: saveVersion };
      console.info('PinmonyDiagnostic: save confirmed');
      state.savedId = String(result.data.id); state.savedBoard = board.name; state.feedback = '已收藏至“' + board.name + '”';
      if (window.PinmonyShareBridge) window.PinmonyShareBridge.postState(JSON.stringify({
        kind: 'saveReady', pinUrl: pin, objectId: state.savedId, value: state.feedback, session: 0, scope: 'detail' }));
    } catch (e) { if (valid(state, boards)) state.error = e.message; }
    finally { if (valid(state, boards)) state.busy = false; } return true;
  };
  api.boardsCreate = async function (pin, name, secret) {
    var state = boards;
    if (!state || state.pin !== pin || !valid(state, boards) || state.busy || state.loading || !clean(name)) return false;
    if (state.createdBoard && state.createdBoard.name === clean(name) && state.createdBoard.secret === !!secret) {
      return api.boardsSave(pin, state.createdBoard.id);
    }
    state.busy = true; state.error = ''; state.feedback = '';
    try {
      var options = { name: clean(name), privacy: secret ? 'secret' : 'public' }, tracking = state.raw && (state.raw.client_tracking_params || state.raw.tracking_params);
      if (tracking) options.initial_pin_client_tracking_params = [tracking];
      var response = await api.resourceRequest(pin, 'BoardResource', 'create', options, function () { return boards === state; });
      var p = response.data;
      if (response.endpoint_name !== 'v3_create_board' || response.code !== 0 || !p || p.name !== options.name || p.privacy !== options.privacy ||
          !/^\\d+$/.test(String(p.id || ''))) throw new Error('未能确认图板创建结果，请重新读取图板');
      var mapped = mapBoard(p); if (!mapped) throw new Error('图板数据无效');
      if (!valid(state, boards)) return false;
      state.items = merge(state.items.slice(), [mapped]);
      state.createdBoard = mapped;
      state.busy = false;
      var started = await api.boardsSave(pin, mapped.id);
      if (!started && valid(state, boards)) state.error = '图板已创建，但暂时无法收藏，请重试';
    } catch (e) { if (valid(state, boards)) state.error = e.message; }
    finally { if (valid(state, boards)) state.busy = false; } return true;
  };
  api.boardsRemove = async function (pin) {
    var state = boards, stored = saved[id(pin)];
    if (!state || state.pin !== pin || !valid(state, boards) || state.busy || !stored || !/^\\d+$/.test(stored.id) || stored.id !== state.savedId) return false;
    state.busy = true; state.error = ''; state.feedback = '';
    try {
      var options = { id: stored.id }, tracking = state.raw && state.raw.tracking_params;
      if (tracking) options.client_tracking_params = tracking;
      var result = await api.resourceRequest(pin, 'PinResource', 'delete', options, function () { return boards === state; });
      if (result.endpoint_name !== 'v3_delete_pin_handler' || result.code !== 0) throw new Error('未确认取消收藏结果');
      saved[id(pin)] = { id: '', board: '' }; state.savedId = ''; state.savedBoard = ''; state.feedback = '已取消本次收藏';
      if (window.PinmonyShareBridge) window.PinmonyShareBridge.postState(JSON.stringify({
        kind: 'saveUndone', pinUrl: pin, objectId: stored.id, value: state.feedback, session: 0, scope: 'detail' }));
    } catch (e) { if (valid(state, boards)) state.error = e.message; }
    finally { if (valid(state, boards)) state.busy = false; } return true;
  };
  function savedCurrent(stored) { return stored && stored.user === api.sessionUserId() &&
    stored.page === location.href && stored.version === saveVersion; }
  api.savedRead = function (pin) {
    var stored = saved[id(pin)];
    return api.currentPin(pin) && stored && (!stored.id || savedCurrent(stored)) ? stored : null;
  };
  // Native memory supplies only a copy ID from a previously validated save response.
  // Reconfirm ownership in this document before restoring the undo capability.
  api.savedRestore = async function (pin, copyId, validRestore) {
    var token = saveVersion, page = location.href, user = api.sessionUserId();
    if (!api.currentPin(pin) || !user || !/^\\d+$/.test(copyId) || copyId === id(pin)) return false;
    var stored = saved[id(pin)];
    if (stored && stored.busy) return false;
    function current() { return saveVersion === token && location.href === page && api.currentPin(pin) &&
      api.sessionUserId() === user && (!validRestore || validRestore()); }
    try {
      var response = await api.resourceRequest(pin, 'PinResource', 'get',
        { id: copyId, field_set_key: 'auth_web_main_pin' }, current);
      var copy = response.data;
      if (!current() || !copy || String(copy.id) !== copyId || !copy.pinner || String(copy.pinner.id) !== user ||
          saved[id(pin)] && saved[id(pin)].busy) return false;
      saved[id(pin)] = { id: copyId, board: copy.board && copy.board.name || '',
        tracking: copy.client_tracking_params || copy.tracking_params || '', busy: false,
        user: user, page: page, version: token };
      return true;
    } catch (_) { return false; }
  };
  // Return a synchronous acceptance flag; publish the asynchronous result separately.
  api.savedRestoreStart = function (pin, copyId, operation) {
    if (!api.currentPin(pin) || !Number.isInteger(operation) || operation < 1 || operation > 2147483647 ||
        restore && restore.status === 'pending') return false;
    var state = restore = { pin: pin, operation: operation, status: 'pending', error: '',
      page: location.href, version: saveVersion, user: api.sessionUserId() };
    api.savedRestore(pin, copyId, function () { return restore === state; }).then(function (ready) {
      if (restore !== state || !api.currentPin(pin)) return;
      state.status = ready ? 'ready' : 'error';
      if (!ready) state.error = '收藏副本校验未通过，请重新读取帖子后检查';
    }).catch(function () {
      if (restore === state) { state.status = 'error'; state.error = '收藏副本校验失败，请重新读取帖子后检查'; }
    });
    return true;
  };
  api.savedRestoreRead = function (pin, operation) {
    return restore && restore.pin === pin && restore.operation === operation && savedCurrent(restore) && api.currentPin(pin) ?
      { operation: operation, status: restore.status, error: restore.error } : null;
  };
  api.savedRestoreClose = function (pin, operation) {
    if (restore && restore.pin === pin && restore.operation === operation) restore = null;
  };
  api.savedUndoRead = function (pin, copyId) {
    return undo && undo.pin === pin && undo.copyId === copyId && savedCurrent(undo) && api.currentPin(pin) ?
      { operation: 0, status: undo.status, error: undo.error } : null;
  };
  api.saveUndo = function (pin, copyId) {
    var stored = saved[id(pin)];
    if (!api.currentPin(pin) || !savedCurrent(stored) || !/^\\d+$/.test(copyId) || copyId === id(pin) || stored.id !== copyId || stored.busy) return false;
    stored.busy = true;
    var token = saveVersion, page = location.href, user = api.sessionUserId();
    var state = undo = { pin: pin, copyId: copyId, status: 'pending', error: '', page: page, version: token, user: user };
    function current() { return saveVersion === token && location.href === page && api.currentPin(pin) &&
      api.sessionUserId() === user && undo === state; }
    function active() { return current() && saved[id(pin)] === stored; }
    function notify(kind, value) {
      if (current() && window.PinmonyShareBridge) window.PinmonyShareBridge.postState(JSON.stringify({
        kind: kind, pinUrl: pin, objectId: copyId, value: value, session: 0, scope: 'detail' }));
    }
    var options = { id: copyId };
    if (stored.tracking) options.client_tracking_params = stored.tracking;
    console.info('PinmonyDiagnostic: undo save request');
    api.resourceRequest(pin, 'PinResource', 'delete', options, active).then(function (result) {
      if (!active()) return;
      if (result.endpoint_name !== 'v3_delete_pin_handler' || result.code !== 0) throw new Error('未确认撤销收藏结果');
      console.info('PinmonyDiagnostic: undo save confirmed');
      state.status = 'done';
      saved[id(pin)] = { id: '', board: '' }; notify('saveUndone', '已撤销收藏');
      if (window.PinmonyDetailRefresh) window.PinmonyDetailRefresh();
    }).catch(function (e) { if (active()) { state.status = 'error'; state.error = e.message;
      notify('saveUndoError', e.message); } })
      .finally(function () { stored.busy = false; });
    return true;
  };
  api.feedbackRecord = function (pin, session) { feedback = { pin: pin, session: session, busy: false }; };
  api.feedbackUndo = function (pin, session) {
    var state = feedback;
    if (!state || state.pin !== pin || state.session !== session || !api.currentPin(pin) || state.busy) return false;
    state.busy = true;
    function notify(kind, value) {
      if (api.currentPin(pin) && window.PinmonyShareBridge) window.PinmonyShareBridge.postState(JSON.stringify({
        kind: kind, value: value, pinUrl: pin, session: session, scope: 'detail' }));
    }
    var p = api.rawPin(pin), data = { pin: id(pin), source: 5 };
    if (p && p.tracking_params) data.client_tracking_params = p.tracking_params;
    api.resourceRequest(pin, 'ApiResource', 'update', { url: '/v3/pin/' + id(pin) + '/feedback/see_more/undo/', data: data },
      function () { return feedback === state; }).then(function (result) {
      if (result.endpoint_name !== 'v3_pin_see_more_undo_user_feedback' || result.code !== 0 || !result.data || String(result.data.id) !== id(pin)) throw new Error('未确认撤销结果');
      feedback = null; notify('feedbackUndone', '已撤销查看更多反馈');
    }).catch(function (e) { if (feedback === state) notify('feedbackUndoError', e.message); })
      .finally(function () { state.busy = false; });
    return true;
  };
})();`;

