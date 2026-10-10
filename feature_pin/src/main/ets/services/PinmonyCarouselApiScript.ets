export const PIN_CAROUSEL_API_ENABLED: boolean = true;
export const PIN_CAROUSEL_API_SCRIPT: string = `
(function () {
  if (window !== window.top || window.PinmonyCarouselApiEnabled !== true) return;
  function map(pin, id, graph) {
    if (!pin || String(graph ? pin.entityId : pin.id) !== id) return null;
    var data = graph ? pin.carouselData : pin.carousel_data;
    var slots = data && (graph ? data.carouselSlots : data.carousel_slots);
    if (!Array.isArray(slots) || !slots.length) return null;
    var items = slots.map(function (slot) {
      var sizes = graph ? slot : slot.images || {};
      var image = null;
      ['1200x', '736x', '474x', '564x', 'orig', '236x'].some(function (size) {
        var candidate = sizes[graph ? 'images_' + size : size];
        if (!candidate || !(candidate.width > 0) || !(candidate.height > 0)) return false;
        try { var url = new URL(candidate.url);
          if (url.protocol !== 'https:' || !/(^|\\.)pinimg\\.com$/.test(url.hostname) || url.username || url.password) return false;
        } catch (_) { return false; }
        image = candidate; return true;
      });
      var slotId = String(graph ? slot.slotId || '' : slot.id || slot.slot_id || '');
      return image && slotId ? { id: slotId, imageUrl: image.url, imageWidth: image.width,
        imageHeight: image.height, title: typeof slot.title === 'string' ? slot.title : '' } : null;
    });
    if (items.some(function (item) { return !item; })) return null;
    return { pinId: id, items: items };
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

  window.PinmonyCarouselApi = {
    detect: function(pin, id) { return !!map(pin, id, false) || !!cached(id) || !!(pin && pin.carousel_data &&
      Array.isArray(pin.carousel_data.carousel_slots) && pin.carousel_data.carousel_slots.length); },
    resolve: async function(pin, id, signal, current) {
      if (!/^\\d+$/.test(id) || !current() || signal.aborted) throw new Error('stale');
      var mapped = map(pin, id, false) || cached(id);
      if (mapped) return mapped;
      var csrf = document.cookie.match(/(?:^|;\\s*)csrftoken=([^;]+)/);
      if (!csrf) throw new Error('missing-session');
      // Full mobile Pin query captured in 搜索结果.har. Never copies HAR account/session values.
      var response = await fetch('/_/graphql/', { method: 'POST', credentials: 'same-origin', signal: signal,
        headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRFToken': decodeURIComponent(csrf[1]),
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/pin/[id].js' },
        body: JSON.stringify({ queryHash: 'c025ad33faccf5d04c2ed38344405d0a6c46dd1d786c17f3954b6980ef798538',
          variables: { pinId: id, isAuth: true, isDesktop: false, isAuthDesktop: false, isUnauth: false,
            shouldPrefetchStoryPinFragment: false, shouldSkipImageViewerOnPageQuery: true } }) });
      if (!response.ok) throw new Error('carousel-request-failed');
      var payload = await response.json();
      if (!current() || signal.aborted) throw new Error('stale');
      if (payload.errors) throw new Error('carousel-response-failed');
      mapped = map(payload.data && payload.data.v3GetPinQueryv2 && payload.data.v3GetPinQueryv2.data, id, true);

      if (!mapped) throw new Error('carousel-source-missing');
      return mapped;
    }
  };
})();`;
