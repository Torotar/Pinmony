export const PIN_VISUAL_SEARCH_API_ENABLED: boolean = true;
export const PIN_VISUAL_SEARCH_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/^https:[/][/](?:www|uk)\\.pinterest\\.com$/.test(location.origin) || window.PinmonyVisualSearchApi) return;
  var state = null, abort = null;
  function current(s) { return state === s && s.page === location.href && location.pathname === '/pin/' + s.id + '/'; }
  function validCrop(c) {
    return c && ['x', 'y', 'w', 'h'].every(function (k) { return typeof c[k] === 'number' && isFinite(c[k]); }) &&
      c.x >= 0 && c.y >= 0 && c.w >= 0.04 && c.h >= 0.04 && c.x + c.w <= 1.00001 && c.y + c.h <= 1.00001;
  }
  function map(p) {
    if (!p || p.type !== 'pin' || !/^\\d+$/.test(String(p.id || ''))) return null;
    var sizes = p.images || {}, image = sizes['736x'] || sizes['474x'] || sizes.orig || sizes['236x'];
    if (!image || !/^https:\\/\\/i\\.pinimg\\.com\\//.test(image.url || '') || !(image.width > 0 && image.height > 0)) return null;
    return { id: 'api:' + p.id, pinUrl: location.origin + '/pin/' + p.id + '/', imageUrl: image.url,
      imageWidth: image.width, imageHeight: image.height, title: String(p.grid_title || p.title || '').slice(0, 160) };
  }
  window.PinmonyVisualSearchApi = {
    close: function () { state = null; if (abort) abort.abort(); abort = null; },
    read: function (pin) { return state && state.pin === pin && current(state) ?
      { pin: pin, loading: state.loading, error: state.error, ended: state.ended, items: state.items } : null; },
    start: function (pin, crop, append, first) {
      var m = String(pin).match(/^https:[/][/](?:www|uk)\\.pinterest\\.com[/]pin[/](\\d+)[/]$/);
      if (!m || String(pin) !== location.origin + '/pin/' + m[1] + '/' || location.pathname !== '/pin/' + m[1] + '/' || !validCrop(crop)) return false;
      if (append && (!state || !current(state) || state.pin !== pin || state.loading || state.ended ||
          JSON.stringify(state.crop) !== JSON.stringify(crop))) return false;
      if (abort) abort.abort();
      var s = { pin: pin, id: m[1], page: location.href, crop: crop, loading: true,
        error: '', ended: false, items: append ? state.items.slice() : [], bookmark: append ? state.bookmark : '' };
      state = s; abort = new AbortController(); var signal = abort.signal;
      var timer = setTimeout(function () { if (current(s)) abort.abort(); }, 15000);
      var options = { pin_id: s.id, crop: crop, crop_source: first ? 5 : 6, is_shopping: false,
        entry_source: 'flashlight', entrypoint: first ? 'closeup_cta' : 'unknown' };
      if (append) options.bookmarks = [s.bookmark];
      var source = '/pin/' + s.id + '/visual-search/?cropSource=' + options.crop_source +
        '&entrypoint=' + options.entrypoint + '&surfaceType=flashlight';
      var url = '/resource/VisualSearchFlashlightUnifiedResource/get/?source_url=' + encodeURIComponent(source) +
        '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now();
      fetch(url, { credentials: 'same-origin', signal: signal,
        headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/pin/[id]/visual-search.js' } })
        .then(function (r) { if (!r.ok) throw new Error('request'); return r.json(); })
        .then(function (p) {
          if (!current(s) || signal.aborted) return;
          var r = p.resource_response;
          if (!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== 'v3_unified_flashlight_handler' ||
              !r.data || !Array.isArray(r.data.results)) throw new Error('contract');
          var seen = new Set(s.items.map(function (p) { return p.id; }));
          r.data.results.map(map).filter(Boolean).forEach(function (p) { if (!seen.has(p.id) && s.items.length < 400) { seen.add(p.id); s.items.push(p); } });
          var next = typeof r.bookmark === 'string' ? r.bookmark : '';
          s.ended = !next || next === '-end-' || next === s.bookmark || s.items.length >= 400; s.bookmark = next;
        }).catch(function () { if (current(s)) s.error = '图片搜索失败，请重试'; })
        .finally(function () { clearTimeout(timer); if (current(s)) s.loading = false; });
      return true;
    }
  };
})();
`;
