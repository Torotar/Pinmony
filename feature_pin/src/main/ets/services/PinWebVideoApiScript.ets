export const PIN_VIDEO_API_ENABLED: boolean = true;
export const PIN_VIDEO_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname) || window.PinWebVideoApiEnabled !== true) return;
  var nativePin = '';
  function nativePage() { return nativePin && location.pathname === '/pin/' + nativePin + '/'; }
  function pauseWebsite() {
    if (!nativePage()) return;
    Array.prototype.forEach.call(document.querySelectorAll('main video, [role="main"] video'), function (video) { video.pause(); });
  }
  document.addEventListener('play', function (event) {
    if (!nativePage()) return;
    var video = event.target;
    if (video && video.tagName === 'VIDEO' && video.closest('main, [role="main"]')) video.pause();
  }, true);
  function validUrl(value, kind) {
    if (typeof value !== 'string') return '';
    try {
      var u = new URL(value);
      return u.protocol === 'https:' && /(^|\\.)pinimg\\.com$/.test(u.hostname) && !u.username && !u.password &&
        /^\\/videos\\//.test(u.pathname) && (kind === 'hls' ? /\\.m3u8$/i : /\\.mp4$/i).test(u.pathname) ? u.href : '';
    } catch (_) { return ''; }
  }
  function map(pin, id, graph) {
    if (!pin || String(graph ? pin.entityId : pin.id) !== id) return null;
    var list = pin.videos && (graph ? pin.videos.videoList : pin.videos.video_list);
    if (!list) return null;
    var hls = graph ? list.vHLSV4 : list.V_HLSV4;
    var mp4 = graph ? list.v720P : list.V_720P;
    var sources = [], primary = null;
    [[hls, 'hls'], [mp4, 'mp4']].forEach(function (entry) {
      var v = entry[0], url = validUrl(v && v.url, entry[1]);
      if (url) { sources.push({ url: url, kind: entry[1] }); if (!primary) primary = v; }
    });
    if (!sources.length) return null;
    function positive(v) { return typeof v === 'number' && isFinite(v) && v > 0 ? v : 0; }
    return { pinId: id, sources: sources, width: positive(primary.width), height: positive(primary.height), duration: positive(primary.duration) };
  }
  function cached(id) {
    var result = null;
    Array.prototype.some.call(document.querySelectorAll('script[data-relay-completed-request]'), function (node) {
      var match = (node.textContent || '').match(/__PWS_RELAY_REGISTER_COMPLETED_REQUEST__\\(\\s*"[^"]*"\\s*,\\s*(\\{[\\s\\S]*\\})\\s*\\);?\\s*$/);
      if (!match) return false;
      try {
        var p = JSON.parse(match[1]);
        result = map(p.data && p.data.v3GetPinQueryv2 && p.data.v3GetPinQueryv2.data, id, true);
      } catch (_) {}
      return !!result;
    }); return result;
  }
  window.PinWebVideoApi = {
    detect: function (pin, id) {
      if (!pin || String(pin.id) !== id) return false;
      var list = pin.videos && pin.videos.video_list;
      return pin.is_video === true || !!map(pin, id, false) || !!(list &&
        Object.keys(list).some(function (key) { return list[key] && typeof list[key].url === 'string' && list[key].url; })) || !!cached(id);
    },
    nativeMode: function (id, enabled) { nativePin = enabled && /^\\d+$/.test(id) ? id : ''; pauseWebsite(); },
    resolve: async function (pin, id, signal, current) {
      if (!/^\\d+$/.test(id) || !current() || signal.aborted) throw new Error('stale');
      var mapped = map(pin, id, false) || cached(id);
      if (mapped) return mapped;
      var csrf = document.cookie.match(/(?:^|;\\s*)csrftoken=([^;]+)/);
      if (!csrf) throw new Error('missing-session');
      // Full mobile Pin query captured in 视频.har. Never copies HAR account/session values.
      var response = await fetch('/_/graphql/', { method: 'POST', credentials: 'same-origin', signal: signal,
        headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRFToken': decodeURIComponent(csrf[1]),
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/pin/[id].js' },
        body: JSON.stringify({ queryHash: 'c025ad33faccf5d04c2ed38344405d0a6c46dd1d786c17f3954b6980ef798538',
          variables: { pinId: id, isAuth: true, isDesktop: false, isAuthDesktop: false, isUnauth: false,
            shouldPrefetchStoryPinFragment: false, shouldSkipImageViewerOnPageQuery: true } }) });
      if (!response.ok) throw new Error('video-request-failed');
      var payload = await response.json();
      if (!current() || signal.aborted) throw new Error('stale');
      if (payload.errors) throw new Error('video-response-failed');
      mapped = map(payload.data && payload.data.v3GetPinQueryv2 && payload.data.v3GetPinQueryv2.data, id, true);
      if (!mapped) throw new Error('video-source-missing');
      return mapped;
    }
  };
})();`;
