// Pinterest website resource API, using only the current ArkWeb session.
export const PIN_SEARCH_API_ENABLED: boolean = true;
export const PIN_SEARCH_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/i.test(location.hostname)) return;
  var key = '', generation = 0, abort = null, busy = false, attempted = false;
  var results = [], categories = [], bookmark = '', ended = false, error = '', active = false;
  var changed = function () {}, current = function () { return false; };
  var suspendedPage = '';
  var capturedOptions = null, observedVersion = 0, waitingSince = 0;
  var needsObserved = false;
  function reset() {
    generation++;
    if (abort) abort.abort();
    key = ''; abort = null; busy = false; attempted = false;
    results = []; categories = []; bookmark = ''; ended = false; error = ''; active = false;
    capturedOptions = null; observedVersion = 0; waitingSince = 0;
    needsObserved = false;
  }
  function mapGuides(data, routeKey) {
    var guides = data && data.rankedGuides;
    if (!Array.isArray(guides)) return [];
    var origin = new URL(routeKey).origin, seen = {};
    return guides.slice(0, 40).map(function (guide) {
      if (!guide || typeof guide.term !== 'string' || !guide.term.trim() || guide.term.length > 300 ||
          typeof guide.display !== 'string' || !guide.display.trim() || seen[guide.term]) return null;
      seen[guide.term] = true;
      return { id: 'api-guide-' + guide.term, label: guide.display.slice(0, 100), selected: false, enabled: true,
        targetUrl: origin + '/search/pins/?q=' + encodeURIComponent(guide.term),
        imageUrl: /^https:\\/\\/i\\.pinimg\\.com\\//i.test(guide.image_medium_url || '') ? guide.image_medium_url.slice(0, 2000) : '',
        backgroundColor: /^#[0-9a-f]{6}$/i.test(guide.dominant_color || '') ? guide.dominant_color : '' };
    }).filter(Boolean);
  }
  function mapResults(items) {
    var mapped = [], seen = {};
    items.forEach(function (pin) {
      if (!pin || !pin.id || seen[pin.id]) return;
      if (pin.type === 'board' || pin.type === 'user') {
        var target = pin.type === 'board' ? pin.url : '/' + pin.username + '/';
        try { target = new URL(target, location.origin); } catch (_) { return; }
        if (target.origin !== location.origin || target.protocol !== 'https:' || !pin.name && !pin.full_name && !pin.username) return;
        var cover = pin.type === 'user' ? pin.image_large_url || pin.image_medium_url : ((pin.images || {})['236x'] || [])[0];
        var imageUrl = typeof cover === 'string' ? cover : cover && cover.url;
      seen[pin.id] = true;
        mapped.push({ id: 'api-' + pin.type + '-' + pin.id, kind: pin.type, title: pin.name || pin.full_name || pin.username,
          subtitle: pin.type === 'board' ? (typeof pin.pin_count === 'number' ? String(pin.pin_count) + ' 个 Pin 图' : '') : pin.username,
          targetUrl: target.href, imageUrl: /^https:\\/\\//.test(imageUrl || '') ? imageUrl : '', imageWidth: 236, imageHeight: 236, enabled: true });
        return;
      }
      if (pin.type !== 'pin' || ! /^(?:[0-9]+|[A-Za-z0-9_-]{20,})$/.test(String(pin.id))) return;
      var image = null, sizes = pin.images || {};
      ['474x', '736x', '564x', 'orig', '236x'].some(function (size) {
        var candidate = sizes[size];
        if (!candidate || typeof candidate.url !== 'string' || !/^https:\\/\\//i.test(candidate.url) ||
            typeof candidate.width !== 'number' || !isFinite(candidate.width) || candidate.width <= 0 ||
            typeof candidate.height !== 'number' || !isFinite(candidate.height) || candidate.height <= 0) return false;
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
      mapped.push({ id: 'api-pin-' + pin.id, kind: 'pin', title: title.trim().slice(0, 180),
        subtitle: '', targetUrl: /^\\d+$/.test(String(pin.id)) ? location.origin + '/pin/' + pin.id + '/' : '', imageUrl: image.url.slice(0, 2000),
        video: video, imageWidth: image.width, imageHeight: image.height, enabled: /^\\d+$/.test(String(pin.id)) });
    });
    return mapped;
  }
  async function request(append) {
    if (busy || !key || !current() || (append && (!active || ended))) return;
    var token = generation, requestedKey = key, previous = bookmark;
    var route = new URL(key), params = route.searchParams;
    var options = capturedOptions ? JSON.parse(JSON.stringify(capturedOptions)) : { query: params.get('q') || '', scope: (route.pathname.split('/')[2] || 'pins'),
      appliedProductFilters: '---', domains: null, user: null, seoDrawerEnabled: false,
      applied_unified_filters: null, auto_correction_disabled: false, filter_genai: false,
      journey_depth: null, source_id: params.get('source_id') || '', source_module_id: null,
      source_url: route.pathname + route.search, static_feed: false, selected_one_bar_modules: null,
      query_pin_sigs: null, page_size: 25, gated: null, price_max: null, price_min: null,
      query_image_pins: null, request_params: null, top_pin_ids: params.get('top_pin_ids') || null,
      article: null, corpus: null, filters: null, rs: params.get('rs') || 'typed' };
    delete options.bookmarks;
    if (append) options.bookmarks = [previous];
    busy = true; attempted = true; error = ''; changed();
    var requestAbort = new AbortController(); abort = requestAbort;
    var timer = setTimeout(function () { requestAbort.abort(); }, 15000);
    try {
      var body = new URLSearchParams();
      body.set('source_url', route.pathname + route.search);
      body.set('data', JSON.stringify({ options: options, context: {} }));
      var csrf = document.cookie.split(';').map(function (part) { return part.trim(); })
        .filter(function (part) { return part.indexOf('csrftoken=') === 0; })[0];
      var headers = { 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' };
      if (csrf) headers['X-CSRFToken'] = decodeURIComponent(csrf.slice('csrftoken='.length));
      var response = await fetch('/resource/BaseSearchResource/get/', {
        pinWebSearchRequest: true,
        method: 'POST', credentials: 'same-origin', signal: requestAbort.signal, headers: headers,
        body: body.toString() });
      if (!response.ok) throw new Error('http-error');
      var payload = await response.json();
      if (token !== generation || key !== requestedKey || !current()) return;
      var resource = payload.resource_response;
      var items = resource && resource.data && resource.data.results;
      if (!resource || resource.status !== 'success' || !Array.isArray(items)) throw new Error('invalid-response');
      var incoming = mapResults(items);
      if (items.length && !incoming.length) throw new Error('invalid-pins');
      if (!append) categories = mapGuides(resource.data, requestedKey);
      var next = typeof resource.bookmark === 'string' ? resource.bookmark : '';
      var merged = append ? results.slice() : [];
      incoming.forEach(function (item) {
        if (!merged.some(function (saved) { return saved.id === item.id; })) merged.push(item);
      });
      results = merged; bookmark = next; active = true;
      ended = !next || next === '-end-' || (append && previous === next) || !items.length;
    } catch (_) {
      if (token !== generation || key !== requestedKey || !current()) return;
      error = append ? '更多搜索结果读取失败，请重试' : '搜索结果接口读取失败，请重试';
    } finally {
      clearTimeout(timer);
      if (token === generation && key === requestedKey) {
        busy = false; abort = null;
        if (current()) changed();
      }
    }
  }
  window.PinmonySearchApi = {
    context: function () { return { page: key, bookmark: bookmark }; },
    reset: reset,
    pause: function () {
      generation++; if (abort) abort.abort(); abort = null; busy = false;
      if (!active) attempted = false;
    },
    suspend: function (page) { reset(); suspendedPage = page; },
    read: function (page, onChange, isCurrent) {
      if (window.PinmonySearchApiEnabled !== true) { if (key) reset(); return null; }
      var route = new URL(page);
      if (!/^\\/search(?:\\/|$)/i.test(route.pathname)) { if (key) reset(); return null; }
      if (key !== page) { reset(); key = page; if (suspendedPage !== page) suspendedPage = ''; }
      changed = onChange; current = isCurrent;
      if (!(route.searchParams.get('q') || '').trim()) {
        return { categories: categories, results: [], busy: false, active: false, error: '探索推荐接口尚未接入，请输入关键词搜索', ended: true };
      }
        var observed = window.PinmonySearchUiApi && window.PinmonySearchUiApi.readSearch && window.PinmonySearchUiApi.readSearch(page);
        if (observed && observed.version !== observedVersion) {
          observedVersion = observed.version;
          var items = observed.resource.data.results, incoming = mapResults(items);
          if (active && results.length && !items.length) return { categories: categories, results: results, busy: busy, active: active, error: error, ended: ended };
          generation++; if (abort) abort.abort(); abort = null; busy = false;
          attempted = true;
          if (items.length && !incoming.length) {
            results = []; categories = []; active = false; error = '此类搜索结果的接口解析尚未接入'; ended = true;
          } else {
            categories = mapGuides(observed.resource.data, page);
            results = incoming; active = true; error = ''; capturedOptions = observed.options;
            bookmark = typeof observed.resource.bookmark === 'string' ? observed.resource.bookmark : '';
            ended = !bookmark || bookmark === '-end-' || !items.length;
          }
        }
      var requiresObserved = suspendedPage === page || !/^\\/search\\/(?:(pins|videos|boards|users|buyable_pins)\\/?)?$/i.test(route.pathname) ||
          ['filters', 'filter', 'shopping', 'color', 'video', 'filter_genai', 'applied_unified_filters']
            .some(function (name) { return route.searchParams.has(name); });
      needsObserved = requiresObserved;
      if (requiresObserved) {
        if (!attempted) {
          if (!waitingSince) waitingSince = Date.now();
          var waiting = Date.now() - waitingSince < 15000;
          return { categories: categories, results: [], busy: waiting, active: false, error: waiting ? '' : '当前搜索接口响应不可用，请重试', ended: true };
        }
        return { categories: categories, results: results, busy: busy, active: active, error: error, ended: ended };
      }
      if (!attempted) {
        if (typeof fetch !== 'function' || typeof AbortController !== 'function') {
          attempted = true; error = '搜索结果接口不可用';
        } else request(false);
      }
      return { categories: categories, results: results, busy: busy, active: active, error: error, ended: ended };
    },
    loadMore: function () {
      if (!key || !current() || busy || !active || ended) return false;
      request(true); return true;
    },
    refresh: function () {
      if (!key || !current()) return false;
      if (!attempted || (needsObserved && !capturedOptions)) return false;
      generation++;
      if (abort) abort.abort();
      abort = null; busy = false; results = []; active = false; bookmark = ''; ended = false;
      request(false); return true;
    }
  };
})();`;
