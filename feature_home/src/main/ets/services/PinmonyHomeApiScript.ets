// Home data is API-only. No credentials are stored here.
export const PIN_HOME_API_ENABLED: boolean = true;

export const PIN_HOME_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var enabled = window.PinmonyHomeApiEnabled === true;
  var key = '', generation = 0, abort = null, boardAbort = null, busy = false;
  var attempted = false, active = false, pins = [], bookmark = '', ended = false, error = '', refreshing = false;
  var changed = function () {}, current = function () { return false; };
  var lastRequestKey = '', lastRequestAt = 0;
  var feedBoard = '';
  var boardSummary = null;
  var savedUsername = '', savedTabs = [], savedTabsStatus = 'idle';
  var savedAbort = null, savedGeneration = 0;
  function savedChanged() { if (window.PinmonyHomeDemand) window.PinmonyHomeDemand(location.href); }
  function mapSavedTabs(resource) {
    if (!resource || resource.status !== 'success' || !Array.isArray(resource.data)) return null;
    var result = [], seen = {};
    resource.data.forEach(function (item, position) {
      var id = String(item && item.id || '');
      var name = item && item.name;
      if (!item || item.type !== 'board' || !/^\\d+$/.test(id) || typeof name !== 'string' ||
          !name.trim() || seen[id]) return;
      seen[id] = true;
      result.push({ name: name.trim().slice(0, 160), boardId: id, index: position });
    });
    return result;
  }
  function requestSavedTabs(username) {
    var token = ++savedGeneration;
    if (savedAbort) savedAbort.abort();
    savedTabsStatus = 'loading'; savedTabs = []; savedUsername = username;
    if (!username) { savedTabsStatus = 'idle'; savedUsername = ''; return; }
    var controller = new AbortController(); savedAbort = controller;
    var options = { field_set_key: 'profile_grid_item', filter_stories: false,
      sort: 'last_pinned_to', username: username };
    var source = '/' + username + '/';
    var url = '/resource/BoardsFeedResource/get/?source_url=' + encodeURIComponent(source) + '&data=' +
      encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now();
    var timer = setTimeout(function () { if (token !== savedGeneration) return; controller.abort(); savedTabsStatus = 'failed'; console.warn('HomeCategoryTrace: timeout'); savedChanged(); }, 15000);
    fetch(url, { credentials: 'same-origin', signal: controller.signal,
      headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
        'X-Pinterest-Pws-Handler': 'www/index.js' } }).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.json();
    }).then(function (payload) {
      if (token !== savedGeneration || controller.signal.aborted) return;
      var mapped = mapSavedTabs(payload.resource_response);
      savedTabsStatus = mapped ? 'ready' : 'failed'; savedTabs = mapped || [];
      if (!mapped) console.warn('HomeCategoryTrace: invalid-resource status=' + (payload.resource_response && payload.resource_response.status === 'success' ? 'success' : 'other') + ' list=' + Array.isArray(payload.resource_response && payload.resource_response.data));
      savedChanged();
    }).catch(function (error) {
      if (token === savedGeneration && error && error.pinmonyCancelled === true) { savedTabsStatus = 'idle'; return; }
      if (token === savedGeneration && !controller.signal.aborted) { savedTabsStatus = 'failed'; savedTabs = []; console.warn('HomeCategoryTrace: request-failed'); savedChanged(); }
    }).finally(function () {
      clearTimeout(timer); if (savedAbort === controller) savedAbort = null;
    });
  }
  function ensureSavedTabs() {
    if (!enabled) return;
    // This API is injected into every document; only Home owns category reads.
    if (!(location.pathname === '/' || location.pathname === '/ideas' ||
        location.pathname.indexOf('/ideas/') === 0 || location.pathname === '/today' ||
        location.pathname.indexOf('/today/') === 0)) return;
    var username = window.PinmonyHomeUsername || '';
    if (username === savedUsername &&
        (savedTabsStatus === 'loading' || savedTabsStatus === 'ready' || savedTabsStatus === 'failed')) return;
    requestSavedTabs(username);
  }
  function retrySavedTabs() {
    if (!enabled) return false;
    var username = window.PinmonyHomeUsername || '';
    if (!username) return false;
    requestSavedTabs(username);
    return true;
  }
  function initialTabs() {
    ensureSavedTabs();
    return savedTabsStatus === 'ready' ? savedTabs : [];
  }
  function reset() {
    generation++;
    if (abort) abort.abort();
    if (boardAbort) boardAbort.abort();
    key = ''; feedBoard = ''; abort = null; boardAbort = null; busy = false; attempted = false; active = false;
    pins = []; bookmark = ''; ended = false; error = ''; refreshing = false;
    boardSummary = null;
    lastRequestKey = ''; lastRequestAt = 0;
  }
  function pause() {
    savedGeneration++;
    if (savedAbort) { savedAbort.abort(); savedAbort = null; }
    if (savedTabsStatus === 'loading') savedTabsStatus = 'idle';
    generation++; if (abort) abort.abort();
    if (boardAbort) boardAbort.abort();
    abort = null; boardAbort = null; busy = false; refreshing = false;
    if (!active) attempted = false;
    lastRequestKey = ''; lastRequestAt = 0;
  }
  function mapPins(data) {
    var result = [], seen = {};
    data.forEach(function (pin) {
      if (!pin || pin.type !== 'pin' || !/^\\d+$/.test(String(pin.id || '')) || seen[pin.id]) return;
      var sizes = pin.images || {}, image = null;
      ['474x', '736x', '564x', 'orig', '236x'].some(function (size) {
        var candidate = sizes[size];
        if (!candidate || !/^https:\\/\\//i.test(candidate.url || '') ||
            !(candidate.width > 0) || !(candidate.height > 0)) return false;
        image = candidate; return true;
      });
      if (!image) return;
      var title = [pin.grid_title, pin.title, pin.description].filter(function (value) {
        return typeof value === 'string' && value.trim();
      })[0] || '';
      var list = pin.videos && pin.videos.video_list || {};
      var sources = [];
      ['V_HLSV4', 'V_720P'].forEach(function (name) {
        var value = list[name], url;
        try { url = new URL(value && value.url); } catch (_) { return; }
        var kind = name === 'V_HLSV4' ? 'hls' : 'mp4';
        if (url.protocol !== 'https:' || !/(^|[.])pinimg[.]com$/i.test(url.hostname) ||
            url.pathname.indexOf('/videos/') !== 0 || value.url.length > 2000 ||
            !(kind === 'hls' ? /[.]m3u8$/i : /[.]mp4$/i).test(url.pathname)) return;
        sources.push({ url: value.url, kind: kind });
      });
      var info = list.V_HLSV4 || list.V_720P;
      var video = sources.length && info ? { pinId: String(pin.id), sources: sources,
        width: Number(info.width) || 0, height: Number(info.height) || 0,
        duration: Math.max(0, Math.min(86400000, Number(info.duration) || 0)) } : undefined;
      seen[pin.id] = true;
      result.push({ id: String(pin.id), pinUrl: location.origin + '/pin/' + pin.id + '/',
        imageUrl: image.url, video: video, imageWidth: image.width, imageHeight: image.height,
        title: title.trim().slice(0, 160), hasMore: false });
    });
    return result;
  }
  function boardImage(value) {
    if (typeof value !== 'string' || value.length > 2000 ||
        !/^https:\\/\\/(?:[a-z0-9-]+\\.)*pinimg\\.com\\//i.test(value)) return '';
    return value;
  }
  function mapBoard(resource, requestedBoard) {
    if (!resource || resource.status !== 'success' || resource.code !== 0 ||
        resource.endpoint_name !== 'v3_get_board' || !resource.data) return null;
    var data = resource.data;
    if (String(data.id || '') !== requestedBoard || typeof data.name !== 'string' || !data.name.trim()) return null;
    var count = Number(data.pin_count);
    if (!isFinite(count) || count < 0 || count > 1000000000) return null;
    var image = '';
    var covers = data.cover_images || {};
    ['236x', '200x150'].some(function (size) {
      var cover = covers[size];
      var value = cover && (cover.url || cover.src);
      image = boardImage(value);
      return !!image;
    });
    if (!image) image = boardImage(data.image_cover_url);
    if (!image) image = boardImage(data.image_cover_hd_url);
    if (!image && data.images) {
      var candidates = data.images['236x'];
      if (Array.isArray(candidates)) candidates.some(function (candidate) {
        image = boardImage(candidate && candidate.url);
        return !!image;
      });
    }
    return { id: requestedBoard, name: data.name.trim().slice(0, 160),
      pinCount: Math.floor(count), thumbnailUrl: image };
  }
  async function requestBoard(token, requestedKey, requestedBoard) {
    if (boardAbort) boardAbort.abort();
    boardSummary = null;
    if (!requestedBoard) return;
    var controller = new AbortController();
    boardAbort = controller;
    var source = '/?tabId=' + requestedBoard;
    var options = { field_set_key: 'profile_grid_item', is_mobile_fork: true, board_id: requestedBoard };
    var url = '/resource/BoardResource/get/?source_url=' + encodeURIComponent(source) + '&data=' +
      encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now();
    var timer = setTimeout(function () { controller.abort(); }, 15000);
    try {
      var response = await fetch(url, { credentials: 'same-origin', signal: controller.signal,
        headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/index.js' } });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      var payload = await response.json();
      if (token !== generation || requestedKey !== key || feedBoard !== requestedBoard || !current()) return;
      boardSummary = mapBoard(payload.resource_response, requestedBoard);
      changed();
    } catch (_) {
      if (token === generation && requestedKey === key && feedBoard === requestedBoard && current()) {
        boardSummary = null;
        changed();
      }
    } finally {
      clearTimeout(timer);
      if (boardAbort === controller) boardAbort = null;
    }
  }
  async function request(append) {
    if (!current() || busy || (append && (!active || ended))) return false;
    var token = generation, requestedKey = key, previous = bookmark;
    if (!append) { lastRequestKey = requestedKey; lastRequestAt = Date.now(); }
    busy = true; refreshing = !append; attempted = true; error = ''; changed();
    abort = new AbortController();
    var requestAbort = abort;
    var timer = setTimeout(function () { requestAbort.abort(); }, 15000);
    try {
      var options = feedBoard ? { type: 'board', id: feedBoard, __track__referrer: 19 } :
        { field_set_key: 'hf_grid', in_nux: false, in_news_hub: false, static_feed: false };
      if (append) options.bookmarks = [previous];
      var source = feedBoard ? '/?tabId=' + feedBoard : '/';
      var endpoint = feedBoard ? 'BoardContentRecommendationResource' : 'UserHomefeedResource';
      var url = '/resource/' + endpoint + '/get/?source_url=' + encodeURIComponent(source) + '&data=' +
        encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now();
      var responsePromise = fetch(url, { credentials: 'same-origin', signal: requestAbort.signal,
        headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/index.js' } });
      // Keep the feed request first on the wire; board metadata is optional and
      // must not delay the first card snapshot.
      if (!append) requestBoard(token, requestedKey, feedBoard);
      var response = await responsePromise;
      if (!response.ok) throw new Error('HTTP ' + response.status);
      var payload = await response.json();
      if (token !== generation || requestedKey !== key || !current()) return false;
      var resource = payload.resource_response;
      if (!resource || resource.status !== 'success' || !Array.isArray(resource.data)) {
        throw new Error('invalid-response');
      }
      var incoming = mapPins(resource.data);
      if (!append && !incoming.length) throw new Error('no-valid-pins');
      if (append && resource.data.length && !incoming.length) throw new Error('invalid-pins');
      var next = typeof resource.bookmark === 'string' ? resource.bookmark : '';
      var merged = append ? pins.slice() : [];
      incoming.forEach(function (pin) {
        if (!merged.some(function (saved) { return saved.id === pin.id; })) merged.push(pin);
      });
      pins = merged; bookmark = next;
      ended = !next || next === '-end-' || (append && next === previous) || !resource.data.length;
      active = true;
    } catch (failure) {
      if (token !== generation || requestedKey !== key || !current()) return false;
      if (failure && failure.pinmonyCancelled === true) { attempted = false; error = ''; return false; }
      error = append ? '更多帖子读取失败，请重试' : active ? '首页刷新失败，请下拉重试' : '首页接口读取失败，请重试';
      console.warn('Pinmony home API: ' + (failure.message || 'request-failed'));
    } finally {
      clearTimeout(timer);
      if (token === generation && requestedKey === key) {
        busy = false; refreshing = false; abort = null;
        if (current()) changed();
      }
    }
    return active;
  }
  window.PinmonyHomeApi = {
    setUsername: function (username) {
      var value = typeof username === 'string' && /^[a-zA-Z0-9_]+$/.test(username) ? username : '';
      if (value === (window.PinmonyHomeUsername || '')) return;
      window.PinmonyHomeUsername = value;
      savedTabsStatus = 'idle'; savedTabs = []; savedUsername = '';
      if (savedAbort) { savedAbort.abort(); savedAbort = null; }
      savedGeneration++;
      ensureSavedTabs();
    },
    initialTabs: initialTabs,
    identityReady: function () { return !!(window.PinmonyHomeUsername || ''); },
    savedTabsReady: function () { ensureSavedTabs(); return savedTabsStatus === 'ready'; },
    savedTabsFailed: function () { ensureSavedTabs(); return savedTabsStatus === 'failed'; },
    retrySavedTabs: retrySavedTabs,
    reset: reset,
    pause: pause,
    isActive: function () { return active && current(); },
    refresh: function () {
      if (busy && refreshing) return false;
      if (!key || !current()) return retrySavedTabs();
      generation++;
      if (abort) abort.abort();
      busy = false; abort = null;
      request(false); return true;
    },
    read: function (contextKey, eligible, onChange, isCurrent, boardId) {
      if (!enabled) { if (key) reset(); return null; }
      if (!eligible) { pause(); return null; }
      var requestedBoard = /^\\d+$/.test(String(boardId || '')) ? String(boardId) : '';
      if (key !== contextKey || feedBoard !== requestedBoard) { reset(); key = contextKey; feedBoard = requestedBoard; }
      changed = onChange; current = isCurrent;
      if (!attempted && !busy && lastRequestKey === contextKey && Date.now() - lastRequestAt < 5000) {
        attempted = true;
      }
      if (!attempted) request(false);
      return { active: active, pins: pins, busy: busy, refreshing: refreshing, ended: ended, error: error,
        board: boardSummary };
    },
    loadMore: function () { if (!current() || !active || busy || ended) return false; request(true); return true; }
  };
})();
`;
