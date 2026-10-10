// Current-session SearchTabResource from 搜索.har; no DOM or persisted GraphQL hash.
export const PIN_SEARCH_DISCOVERY_API_ENABLED: boolean = true;
export const PIN_SEARCH_DISCOVERY_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/i.test(location.hostname) || window.PinmonySearchDiscoveryApiEnabled !== true) return;
  var page = '', generation = 0, abort = null, sections = [], heroes = [], targets = {};
  var cursor = '', ended = false, active = false, busy = false, attempted = false, error = '', changed = function () {};
  function key() { return location.origin + location.pathname + location.search; }
  function eligible() { return /^\\/search\\/?$/.test(location.pathname) && !new URLSearchParams(location.search).get('q'); }
  function reset() { generation++; if (abort) abort.abort(); page = ''; abort = null; sections = []; heroes = []; targets = {};
    cursor = ''; ended = false; active = false; busy = false; attempted = false; error = ''; }
  function target(value) { try { var url = new URL(value, location.href); return url.origin === location.origin && url.protocol === 'https:' ? url.href : ''; } catch (_) { return ''; } }
  function image(value) { return typeof value === 'string' && /^https:\\/\\/i\\.pinimg\\.com\\//i.test(value) ? value.slice(0, 2000) : ''; }
  function text(value) { return value && typeof value.format === 'string' ? value.format.trim().slice(0, 180) : ''; }
  async function requestPage(append) {
    if (busy || !eligible() || append && (ended || !cursor)) return false;
    var token = generation, requestedPage = page, previous = append ? cursor : '';
    var controller = new AbortController(); abort = controller; busy = true; attempted = true; error = ''; changed();
    var options = {}; if (append) options.bookmarks = [previous];
    var fields = new URLSearchParams(); fields.set('source_url', location.pathname + location.search);
    fields.set('data', JSON.stringify({ options: options, context: {} }));
    var timer = setTimeout(function () { controller.abort(); }, 15000);
    try {
      var response = await fetch('/resource/SearchTabResource/get/?' + fields.toString() + '&_=' + Date.now(), {
        credentials: 'same-origin', signal: controller.signal, pinWebDiscoveryRequest: true,
        headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } });
      if (!response.ok) throw new Error('http');
      var payload = await response.json(), resource = payload.resource_response;
      if (token !== generation || requestedPage !== key() || !eligible()) return;
      if (!resource || resource.status !== 'success' || !Array.isArray(resource.data)) throw new Error('invalid-response');
      var mapped = append ? sections.slice() : [], banners = append ? heroes.slice() : [], nextTargets = append ? Object.assign({}, targets) : {};
      resource.data.slice(0, 80).forEach(function (node, index) {
        if (!node || !Array.isArray(node.objects)) return;
        var title = text(node.title), id = 'discovery-' + String(node.id || index);
        if (node.story_type === 'slp_immersive_header') {
          node.objects.slice(0, 20).forEach(function (board, n) {
            var cover = image(board && board.image_cover_hd_url), url = target(board && board.url);
            if (!board || board.type !== 'board' || !cover || !url || typeof board.name !== 'string' || !board.name.trim()) return;
            var heroId = id + '-hero-' + n; nextTargets[heroId] = url;
            if (!banners.some(function (v) { return v.id === heroId; })) banners.push({ id: heroId, title: board.name.slice(0, 180), subtitle: title, imageUrl: cover, enabled: true });
          }); return;
        }
        var url = target(node.action && node.action.url);
        if (node.story_type !== 'slp_search_recommendation' || !title || !url || !/^\\/search\\/pins\\//.test(new URL(url).pathname)) return;
        var items = [];
        node.objects.slice(0, 4).forEach(function (pin, n) {
          var cover = image(pin && pin.image_medium_url); if (!cover) return;
          var itemId = id + '-' + n; nextTargets[itemId] = url;
          items.push({ id: itemId, title: title, imageUrl: cover, targetUrl: url, enabled: true });
        });
        if (!items.length) return;
        nextTargets[id] = url;
        var section = { id: id, title: title, eyebrow: text(node.subtitle), actionId: id, targetUrl: url, items: items };
        var existing = mapped.findIndex(function (v) { return v.id === id; }); if (existing < 0) mapped.push(section); else mapped[existing] = section;
      });
      var next = resource.bookmark; if (!next && resource.bookmarks) next = resource.bookmarks[0];
      cursor = typeof next === 'string' ? next : ''; ended = !cursor || cursor === '-end-' || cursor === previous;
      sections = mapped; heroes = banners; targets = nextTargets; active = true; busy = false; error = ''; changed();
    } catch (_) { if (token === generation && requestedPage === key()) { busy = false; error = '搜索发现接口读取失败，请重试'; changed(); } }
    finally { clearTimeout(timer); if (abort === controller) abort = null; }
  }
  window.PinmonySearchDiscoveryApi = {
    read: function (requestedPage, callback) {
      if (!eligible() || requestedPage !== key()) { if (page) reset(); return null; }
      if (page !== key()) { reset(); page = key(); } changed = callback;
      if (!active && !attempted) requestPage(false);
      return { sections: sections, heroes: heroes, busy: busy, active: active, error: error, ended: ended };
    },
    loadMore: function () { if (!eligible() || page !== key() || busy || !active || ended) return false; requestPage(true); return true; },
    action: function (id) { if (!eligible() || page !== key() || !targets[id]) return false; location.assign(targets[id]); return true; },
    refresh: function () { if (!eligible() || page !== key()) return false; if (abort) abort.abort(); generation++; busy = false; requestPage(false); return true; },
    pause: function () { generation++; if (abort) abort.abort(); abort = null; busy = false; if (!active) attempted = false; }, reset: reset
  };
})();`;
