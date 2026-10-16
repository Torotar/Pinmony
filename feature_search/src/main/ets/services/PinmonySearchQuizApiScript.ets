export const PIN_SEARCH_QUIZ_API_ENABLED: boolean = true;
export const PIN_SEARCH_QUIZ_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/i.test(location.hostname)) return;
  if(window.PinmonyNativeSearchReadsEnabled === true)return;
  var page = '', epoch = 0, abort = null, attempted = false, changed = function () {};
  var bookmark = '', ended = true;
  var observedEntry = null;
  var mode = 'entry', module = null, cards = [], selected = [], topic = '', busy = false, error = '';
  function reset() {
    epoch++; if (abort) abort.abort(); abort = null; page = ''; attempted = false;
    observedEntry = null; bookmark = ''; ended = true; mode = 'entry'; module = null; cards = []; selected = []; topic = ''; busy = false; error = '';
  }
  function live(token, key) { return token === epoch && page === key && location.origin + location.pathname + location.search === key; }
  function applyEntry(resource) {
    var data = resource.data && resource.data['1000269'], display = data && data.display_data;
    module = display && display.quiz && Array.isArray(display.related_query_items) ? display : null;
  }
  function entryInfo(url, body) {
    try {
      var endpoint = new URL(typeof url === 'string' ? url : url.url, location.href || location.origin);
      if (endpoint.origin !== location.origin || endpoint.pathname !== '/resource/UserExperienceResource/get/') return null;
      var fields = body ? new URLSearchParams(body) : endpoint.searchParams;
      var options = JSON.parse(fields.get('data') || '{}').options;
      var key = location.origin + location.pathname + location.search, route = new URL(key);
      if (!options || !Array.isArray(options.placement_ids) || options.placement_ids.indexOf(1000269) < 0 ||
          !options.extra_context || options.extra_context.search_query !== route.searchParams.get('q')) return null;
      var source = fields.get('source_url');
      if (source) { var sourceRoute = new URL(source, location.origin);
        if (sourceRoute.pathname !== route.pathname || sourceRoute.searchParams.get('q') !== route.searchParams.get('q')) return null; }
      return { page: key, epoch: epoch };
    } catch (_) { return null; }
  }
  function acceptEntry(info, payload) {
    var resource = payload && payload.resource_response;
    if (!info || info.page !== location.origin + location.pathname + location.search ||
        !resource || resource.status !== 'success' || !resource.data || typeof resource.data !== 'object') return;
    if (page && (page !== info.page || mode !== 'entry' || (info.epoch !== epoch && !busy))) return;
    observedEntry = { page: info.page, resource: resource };
    if (page === info.page) {
      epoch++; if (abort) abort.abort(); abort = null; busy = false; error = ''; attempted = true;
      applyEntry(resource); changed();
    }
  }
  if (typeof window.fetch === 'function') {
    var originalFetch = window.fetch;
    window.fetch = function (url, init) {
      var info = init && init.pinWebSearchQuizRequest ? null : entryInfo(url, init && init.body);
      return originalFetch.apply(this, arguments).then(function (response) {
        try { if (info && response.ok) response.clone().json().then(function (payload) { acceptEntry(info, payload); }).catch(function () {}); } catch (_) {}
        return response;
      });
    };
  }
  if (typeof XMLHttpRequest === 'function') {
    var originalOpen = XMLHttpRequest.prototype.open, originalSend = XMLHttpRequest.prototype.send, urls = new WeakMap();
    XMLHttpRequest.prototype.open = function (method, url) { urls.set(this, url); return originalOpen.apply(this, arguments); };
    XMLHttpRequest.prototype.send = function (body) {
      var info = entryInfo(urls.get(this), body), xhr = this;
      if (info) this.addEventListener('load', function () {
        try { if (xhr.status === 200) acceptEntry(info, xhr.responseType === 'json' ? xhr.response : JSON.parse(xhr.responseText)); } catch (_) {}
      }, { once: true });
      return originalSend.apply(this, arguments);
    };
  }
  async function request(path, options, consume) {
    if (busy || !page) return false;
    var token = ++epoch, key = page, controller = new AbortController(); abort = controller;
    busy = true; error = ''; changed();
    var timer = setTimeout(function () { controller.abort(); }, 15000);
    try {
      var route = new URL(page), fields = new URLSearchParams();
      fields.set('source_url', route.pathname + route.search);
      fields.set('data', JSON.stringify({ options: options, context: {} }));
      fields.set('_', String(Date.now()));
      var response = await fetch(path + '?' + fields.toString(), { credentials: 'same-origin', signal: controller.signal,
        pinWebSearchQuizRequest: true, headers: { Accept: 'application/json, text/javascript, */*, q=0.01',
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-AppState': 'active',
          'X-Pinterest-Pws-Handler': 'www/search/[scope].js', 'X-Pinterest-Source-Url': route.pathname + route.search } });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      var json;
      try { json = await response.json(); } catch (_) { throw new Error('返回内容不是有效 JSON'); }
      var resource = json && json.resource_response;
      if (!live(token, key)) return;
      if (!resource || resource.status !== 'success') throw new Error('接口未返回成功状态');
      consume(resource);
    } catch (failure) {
      if (live(token, key)) {
        if (failure && failure.pinmonyCancelled === true) {
          if (mode === 'entry') attempted = false;
          error = ''; return false;
        }
        var reason = controller.signal.aborted ? '请求超时' : failure && failure.message;
        if (!/^(HTTP [0-9]+|返回内容不是有效 JSON|接口未返回成功状态|返回数据格式不匹配|请求超时)$/.test(reason || '')) reason = '网络请求异常';
        error = '灵感推荐接口读取失败（' + reason + '），请重试';
      }
    }
    finally { clearTimeout(timer); if (live(token, key)) { busy = false; abort = null; changed(); } }
    return true;
  }
  function mapPins(items) {
    var seen = {};
    return items.map(function (pin) {
      if (!pin || pin.type !== 'pin' || !pin.id || seen[pin.id]) return null;
      var image = (pin.images || {})['474x'] || (pin.images || {})['236x'];
      var url = image ? image.url : pin.image_large_url || pin.image_medium_url;
      if (!/^https:\\/\\/i\\.pinimg\\.com\\//i.test(url || '')) return null;
      seen[pin.id] = true;
      return { id: String(pin.id), title: String(pin.grid_title || pin.title || ''), imageUrl: url,
        imageWidth: image && image.width > 0 ? image.width : 236,
        imageHeight: image && image.height > 0 ? image.height : 310,
        selected: selected.indexOf(String(pin.id)) >= 0,
        targetUrl: /^\\d+$/.test(String(pin.id)) ? location.origin + '/pin/' + pin.id + '/' : '' };
    }).filter(Boolean);
  }
  function loadEntry() {
    attempted = true;
    if (observedEntry && observedEntry.page === page) { applyEntry(observedEntry.resource); return; }
    request('/resource/UserExperienceResource/get/', { placement_ids: [1000269],
      extra_context: { search_query: new URL(page).searchParams.get('q') || '' } }, function (resource) {
      if (!resource.data || typeof resource.data !== 'object') throw new Error('返回数据格式不匹配');
      applyEntry(resource);
    });
  }
  function loadTopic(query, append) {
    var previous = bookmark;
    topic = query; mode = 'picker'; if (!append) { cards = []; bookmark = ''; ended = true; }
    var options = { query: query, scope: 'pins', page_size: 25, enable_promoted_pins: false };
    if (append) options.bookmarks = [previous];
    request('/resource/BaseSearchResource/get/', options, function (resource) {
      if (!resource.data || !Array.isArray(resource.data.results)) throw new Error('返回数据格式不匹配');
      var incoming = mapPins(resource.data.results);
      cards = append ? cards.concat(incoming.filter(function (card) { return !cards.some(function (old) { return old.id === card.id; }); })) : incoming;
      bookmark = typeof resource.bookmark === 'string' ? resource.bookmark : '';
      ended = !bookmark || bookmark === '-end-' || (append && bookmark === previous) || !resource.data.results.length;
    });
  }
  function showResults() {
    if (!selected.length) return false;
    mode = 'results'; cards = [];
    request('/resource/ApiResource/get/', { url: '/v3/batch/related/pins/',
      data: { client_type: 118, pin_ids: selected.slice(), prepend_seed_pins: false } }, function (resource) {
      if (!Array.isArray(resource.data)) throw new Error('pins');
      cards = mapPins(resource.data);
    });
    return true;
  }
  window.PinmonySearchQuizApi = {
    pause: function () {
      if (mode !== 'entry' || !busy) return;
      epoch++; if (abort) abort.abort(); abort = null; busy = false; attempted = false; error = '';
    },
    reset: reset,
    read: function (key, callback) {
      if (window.PinmonySearchQuizApiEnabled !== true) return null;
      var route = new URL(key);
      if (!route.searchParams.get('q') || !/^\\/search\\/(pins\\/?)?$/.test(route.pathname)) { if (page) reset(); return null; }
      if (key !== page) { var cached = !page && observedEntry && observedEntry.page === key ? observedEntry : null; reset(); page = key; observedEntry = cached; }
      changed = callback; if (!attempted) loadEntry();
      if (!module && !error) return null;
      return { mode: mode, title: mode === 'results' ? '基于你的偏好推荐' + (new URL(page).searchParams.get('q') || '') + '点子' : module ? module.quiz.title : '', eyebrow: module ? module.quiz.entry_eyebrow : '',
        entryTitle: module ? module.quiz.title : '',
        pickerTitle: module ? module.quiz.picker_title : '', submitLabel: module ? module.quiz.picker_see_results_button_copy : '',
        topics: module ? module.related_query_items.map(function (item, index) {
          return { id: String(index), query: item.query, imageUrl: item.cover_pin_url }; }) : [],
        cards: cards.map(function (item) { return Object.assign({}, item, { selected: selected.indexOf(item.id) >= 0 }); }),
        canMore: mode === 'picker' && !ended, count: selected.length, busy: busy, error: error };
    },
    action: function (key, kind, id) {
      if (key !== page || !live(epoch, key)) return false;
      if (kind === 'back') { epoch++; if (abort) abort.abort(); abort = null; busy = false; mode = 'entry'; cards = []; selected = []; error = ''; changed(); return true; }
      if (kind === 'dismiss') { epoch++; if (abort) abort.abort(); abort = null; busy = false; observedEntry = null; module = null; error = ''; changed(); return true; }
      if (busy) return false;
      if (kind === 'retry') { if (mode === 'entry') { observedEntry = null; loadEntry(); } else if (mode === 'picker') loadTopic(topic, cards.length > 0 && !ended); else showResults(); return true; }
      if (kind === 'topic' && module && module.related_query_items[Number(id)]) { loadTopic(module.related_query_items[Number(id)].query); return true; }
      if (kind === 'select' && mode === 'picker' && cards.some(function (card) { return card.id === id; })) {
        var index = selected.indexOf(id); if (index >= 0) selected.splice(index, 1); else if (selected.length < 10) selected.push(id); else return false;
        changed(); return true;
      }
      if (kind === 'more' && mode === 'picker' && !ended) { loadTopic(topic, true); return true; }
      if (kind === 'submit' && mode === 'picker') return showResults();
      return false;
    }
  };
})();`;
