// Disable to restore DOM content reading without changing the native presentation.
export const PIN_DETAIL_API_ENABLED: boolean = true;
export const PIN_DETAIL_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var enabled = window.PinWebDetailApiEnabled === true;
  var key = '', generation = 0, detail = null, related = null, bookmark = '', ended = false;
  var detailBusy = false, relatedBusy = false, detailAttempted = false, relatedAttempted = false, relatedRetryCount = 0, detailRetryCount = 0;
  var detailError = '', relatedError = '', mediaUnsupported = false;
  var aborts = [], changed = function () {}, current = function () { return false; };
  var reactionCount = null, relatedTimer = -1;
  var imageStage = 'waiting', interactionsSettled = false;
  var carousel = null;
  var video = null, videoError = '', isVideo = false, mediaLoading = false, mediaError = '', mediaKind = '';
  function reset() {
    if (window.PinWebVideoApi) window.PinWebVideoApi.nativeMode('', false);
    generation++; clearTimeout(relatedTimer); relatedTimer = -1;
    aborts.forEach(function (abort) { abort.abort(); }); aborts = [];
    key = ''; detail = null; related = null; bookmark = ''; ended = false;
    detailBusy = false; relatedBusy = false; detailAttempted = false; relatedAttempted = false; relatedRetryCount = 0; detailRetryCount = 0;
    detailError = ''; relatedError = ''; mediaUnsupported = false;
    reactionCount = null;
    imageStage = 'waiting'; interactionsSettled = false;
    carousel = null; video = null; videoError = ''; isVideo = false;
    mediaLoading = false; mediaError = ''; mediaKind = '';
  }
  // Observe only the confirmed website GraphQL response; it is not a full Pin detail response.
  if (enabled && typeof window.fetch === 'function') {
    var originalFetch = window.fetch;
    window.fetch = function (input, args) {
      var requestedPin = '', requestedKey = key, token = generation;
      try {
        var url = new URL(typeof input === 'string' ? input : input.url, location.origin);
        var body = args && typeof args.body === 'string' ? JSON.parse(args.body) : null;
        if (url.origin === location.origin && url.pathname === '/_/graphql/' && body && body.variables &&
            /^\\d+$/.test(String(body.variables.pinId || ''))) requestedPin = String(body.variables.pinId);
      } catch (_) {}
      var result = originalFetch.apply(this, arguments);
      if (requestedPin && requestedKey === location.origin + '/pin/' + requestedPin + '/') {
        result.then(function (response) {
          if (response.ok) response.clone().json().then(function (payload) {
            if (token !== generation || key !== requestedKey || !current()) return;
            var pin = payload && payload.data && payload.data.v3GetPinQueryv2 && payload.data.v3GetPinQueryv2.data;
            if (!pin || String(pin.entityId) !== requestedPin || !Array.isArray(pin.reactionCountsData)) return;
            var item = pin.reactionCountsData.filter(function (entry) { return entry.reactionType === 1; })[0];
            if (!item || typeof item.reactionCount !== 'number' || !isFinite(item.reactionCount) ||
                item.reactionCount < 0 || Math.floor(item.reactionCount) !== item.reactionCount) return;
            reactionCount = String(item.reactionCount); changed();
          }).catch(function () {});
        }).catch(function () {});
      }
      return result;
    };
  }
  function artwork(pin, thumbnail) {
    var sizes = pin.images || {}, result = null;
    (thumbnail ? ['474x', '236x', '564x', '736x', 'orig'] : ['736x', '474x', '564x', 'orig', '236x']).some(function (size) {
      var image = sizes[size];
      if (!image || !/^https:\\/\\//i.test(image.url || '') || !(image.width > 0) || !(image.height > 0)) return false;
      result = image; return true;
    });
    return result;
  }
  function clean(value) { return typeof value === 'string' ? value.trim() : ''; }
  function hasMedia(value) {
    if (!value || typeof value !== 'object') return false;
    return Object.keys(value).some(function (key) {
      if (key === '__typename') return false;
      var item = value[key];
      if (key === 'url' && typeof item === 'string' && /^https:\\/\\//i.test(item)) return true;
      return Array.isArray(item) ? item.length > 0 : item && typeof item === 'object' && hasMedia(item);
    });
  }
  function hasPages(value) {
    return !!value && [value.pages, value.story_pages, value.carousel_slots].some(function (items) {
      return Array.isArray(items) && items.length > 0;
    });
  }
  function singleImageStory(pin) {
    var story = pin.story_pin_data, pages = story && story.pages;
    if (!Array.isArray(pages) || pages.length !== 1 || !artwork(pin) || story.is_deleted === true) return false;
    var blocks = pages[0] && pages[0].blocks;
    if (!Array.isArray(blocks) || blocks.length !== 1) return false;
    var block = blocks[0];
    return !!block && (block.block_type === 2 || block.blockType === 2 || block.__typename === 'StoryPinImageBlock') &&
      !block.video && !block.videos && !block.video_data;
  }
  function mapPin(pin) {
    if (!pin || pin.type !== 'pin' || !/^\\d+$/.test(String(pin.id || ''))) return null;
    var image = artwork(pin, true);
    if (!image) return null;
    var images = {};
    Object.keys(pin.images || {}).forEach(function (size) {
      var candidate = pin.images[size];
      if (candidate && typeof candidate.url === 'string' && /^https:\\/\\//i.test(candidate.url)) {
        images[size] = { url: candidate.url };
      }
    });
    return { id: 'api:' + pin.id, pinUrl: location.origin + '/pin/' + pin.id + '/',
      imageUrl: image.url, imageWidth: image.width, imageHeight: image.height,
      images: images,
      title: (clean(pin.grid_title) || clean(pin.title) || clean(pin.description)).slice(0, 160) };
  }
  async function resolveMedia(pin, requestedKey, token, abort) {
    var id = String(pin.id);
    isVideo = pin.is_video === true || hasMedia(pin.videos) || !!(window.PinWebVideoApi &&
      window.PinWebVideoApi.detect && window.PinWebVideoApi.detect(pin, id));
    carousel = null;
    var isCarousel = hasPages(pin.carousel_data) || !!(window.PinWebCarouselApi && window.PinWebCarouselApi.detect(pin, id));
    mediaUnsupported = isCarousel && !window.PinWebCarouselApi ||
      hasPages(pin.story_pin_data) && !singleImageStory(pin) && !isCarousel && !isVideo ||
      isVideo && !window.PinWebVideoApi;
    if (mediaUnsupported) {
      detail = null; detailError = '暂不支持此帖子的媒体内容';
      return false;
    }
    if (!mapPin(pin)) throw new Error('invalid-pin');
    // Publish the verified base before waiting for extra media resources.
    detail = pin; detailBusy = false; video = null; videoError = ''; mediaError = '';
    mediaKind = isCarousel ? 'carousel' : isVideo ? 'video' : '';
    mediaLoading = !!mediaKind;
    changed();
    if (token !== generation || requestedKey !== key || !current()) return false;
    if (isCarousel && window.PinWebCarouselApi) {
      try {
        carousel = await window.PinWebCarouselApi.resolve(pin, id, abort.signal, function () {
          return token === generation && requestedKey === key && current();
        });
      } catch (_) {
        if (token !== generation || requestedKey !== key || !current()) return false;
        mediaError = '多图内容加载失败，请重试';
      }
      if (token !== generation || requestedKey !== key || !current()) return false;
    }
    if (isVideo && !mediaUnsupported) {
      try {
        video = await window.PinWebVideoApi.resolve(pin, id, abort.signal, function () {
          return token === generation && requestedKey === key && current();
        });
      } catch (_) {
        if (token !== generation || requestedKey !== key || !current()) return false;
        videoError = '视频地址读取失败，请重试';
      }
      if (token !== generation || requestedKey !== key || !current()) return false;
    }
    return true;
  }
  async function retryMedia() {
    if (!enabled || !detail || !current() || detailBusy || mediaLoading || mediaUnsupported) return false;
    var token = generation, requestedKey = key, pin = detail;
    var abort = new AbortController(); aborts.push(abort);
    var timer = setTimeout(function () { abort.abort(); }, 15000);
    try { await resolveMedia(pin, requestedKey, token, abort); }
    finally {
      clearTimeout(timer); aborts = aborts.filter(function (item) { return item !== abort; });
      if (token === generation && requestedKey === key) { mediaLoading = false; if (current()) changed(); }
    }
    return true;
  }
  async function request(isRelated, append) {
    // Related content may start once the current Pin is verified; comments
    // and other interaction state are refreshed independently.
    if (isRelated ? relatedBusy || (append && ended) : detailBusy || mediaLoading) return false;
    var requestedKey = key, token = generation, previous = bookmark;
    var id = key.split('/pin/')[1].split('/')[0];
    if (isRelated) { relatedBusy = true; relatedAttempted = true; relatedError = ''; }
    else { detailBusy = true; detailAttempted = true; detailError = ''; mediaUnsupported = false; }
    var abort = new AbortController(); aborts.push(abort);
    var timer = setTimeout(function () { abort.abort(); }, 15000);
    try {
      var options = isRelated ? { pin_id: id, page_size: 12, context_pin_ids: [],
        homefeed_source_sig: false, search_query: '', source: 'feed_home',
        top_level_source: 'feed_home', top_level_source_depth: 1, is_pdp: false,
        additional_fields: ['pin.gen_ai_topics'] } : { id: id, field_set_key: 'auth_web_main_pin',
        noCache: true, fetch_visual_search_objects: false, get_page_metadata: false,
        add_fields: 'pin.gen_ai_topics,pin.is_eligible_for_image_download,pin.is_eligible_for_ai_comparison,pin.has_hidden_inner_pin' };
      if (isRelated && append) options.bookmarks = [previous];
      var name = isRelated ? 'RelatedModulesResource' : 'PinResource';
      var url = '/resource/' + name + '/get/?source_url=' + encodeURIComponent('/pin/' + id + '/') +
        '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now();
      var response = await fetch(url, { credentials: 'same-origin', signal: abort.signal,
        headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/pin/[id].js' } });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      var payload = await response.json();
      if (token !== generation || requestedKey !== key || !current()) return false;
      var resource = payload.resource_response;
      if (!resource || resource.status !== 'success') throw new Error('invalid-response');
      if (!isRelated) {
        var pin = resource.data;
        if (!pin || pin.type !== 'pin' || String(pin.id) !== id) throw new Error('invalid-pin');
        // The Pin identity and response are verified. Start recommendations
        // before resolving optional carousel/video media so these reads run
        // alongside the main image and media work.
        if (token === generation && requestedKey === key && current() && !relatedAttempted && !relatedBusy) {
          request(true, false);
        }
        await resolveMedia(pin, requestedKey, token, abort);
      } else {
        if (!Array.isArray(resource.data)) {
          if (window.PinWebDetailReadTiming) window.PinWebDetailReadTiming(key, 'related.mapping.invalidshape', 0);
          throw new Error('invalid-related');
        }
        var incoming = resource.data.map(mapPin).filter(function (pin) {
          return pin && pin.pinUrl !== key;
        });
        if (resource.data.length && !incoming.length) {
          if (window.PinWebDetailReadTiming) window.PinWebDetailReadTiming(key, 'related.mapping.nopins', 0);
          throw new Error('invalid-related-pins');
        }
        var merged = append && related ? related.slice() : [];
        incoming.forEach(function (pin) { if (!merged.some(function (item) { return item.id === pin.id; })) merged.push(pin); });
        related = merged;
        bookmark = typeof resource.bookmark === 'string' ? resource.bookmark : '';
        ended = !bookmark || bookmark === '-end-' || (append && bookmark === previous) || !resource.data.length;
      }
    } catch (error) {
      if (token === generation && requestedKey === key && current()) {
        console.warn('PinWeb detail API: ' + name + ' ' + (error.message || 'request-failed'));
        if (isRelated) {
          relatedError = '推荐内容加载失败，请重试';
          // A page-local abort can occur while the bridge is rebinding. Retry
          // once for the still-current Pin; HTTP/business failures remain manual.
          if (error && error.name === 'AbortError' && relatedRetryCount < 1) {
            relatedRetryCount++;
            relatedAttempted = false;
            setTimeout(function () {
              if (token === generation && requestedKey === key && current() && !relatedBusy) request(true, false);
            }, 0);
          }
        }
        else {
          detailError = '帖子加载失败，请重试';
          if (error && error.name === 'AbortError' && error.pinWebEpochChanged === true && detailRetryCount < 1) {
            detailRetryCount++;
            setTimeout(function () {
              if (token === generation && requestedKey === key && current() && !detailBusy) request(false, false);
            }, 0);
          }
        }
      }
    } finally {
      clearTimeout(timer);
      aborts = aborts.filter(function (item) { return item !== abort; });
      if (token === generation && requestedKey === key) {
        if (isRelated) relatedBusy = false;
        else { detailBusy = false; mediaLoading = false; }
        if (current()) {
          changed();
        }
      }
    }
    return true;
  }
  window.PinWebDetailApi = {
    restart: function (pin) {
      if (!enabled || pin !== key || !current()) return false;
      var onChange = changed, isCurrent = current;
      reset(); key = pin; changed = onChange; current = isCurrent;
      request(false, false); changed();
      return true;
    },
    retryMedia: retryMedia,
    scheduleRelated: function (pin) {
      if (pin !== key || !current() || !detail || relatedAttempted || relatedTimer !== -1) return false;
      var token = generation;
      // Dispatch immediately after the verified Pin snapshot. The request
      // function applies the generation/current-page guards and deduplicates.
      relatedTimer = 0;
      if (token === generation) {
        relatedTimer = -1;
        request(true, false);
      }
      return true;
    },
    startRelated: function (pin) {
      if (!enabled || pin !== key || !current() || !detail ||
          relatedAttempted || relatedBusy) return false;
      clearTimeout(relatedTimer); relatedTimer = -1;
      request(true, false);
      return true;
    },
    settleImage: function (pin, url, outcome) {
      if (!enabled || pin !== key || !current() || !detail || !artwork(detail) ||
          artwork(detail).url !== url || !/^(loaded|failed|timeout)$/.test(outcome)) return false;
      if (imageStage !== 'waiting' && (outcome !== 'loaded' || imageStage === 'loaded')) return true;
      imageStage = outcome; changed(); return true;
    },
    settleInteractions: function (pin) {
      if (pin !== key || !current() || !detail) return false;
      if (!interactionsSettled) {
        interactionsSettled = true;
        if (window.PinWebDetailReadTiming) window.PinWebDetailReadTiming(pin, 'interactions.settled', 0);
        changed();
      }
      return true;
    },
    reload: function () { if (enabled && key && current() && !detailBusy) request(false, false); },
    raw: function (pin) {
      var match = String(pin || '').match(/\\/pin\\/(\\d+)/), active = key.match(/\\/pin\\/(\\d+)/);
      return match && active && match[1] === active[1] && current() ? detail : null;
    },
    reset: reset,
    read: function (pin, onChange, isCurrent) {
      if (!enabled) return null;
      if (key !== pin) { reset(); key = pin; }
      changed = onChange; current = isCurrent;
      if (!detailAttempted) request(false, false);
      return { detail: detail, image: detail ? artwork(detail) : null, related: related,
        imageStageReady: imageStage !== 'waiting', imageLoaded: imageStage === 'loaded', interactionsSettled: interactionsSettled,
        detailError: detailError, relatedError: relatedError, detailBusy: detailBusy,
        relatedBusy: relatedBusy || relatedTimer !== -1, ended: ended, mediaUnsupported: mediaUnsupported, reactionCount: reactionCount,
        carousel: carousel, video: video, videoError: videoError, isVideo: isVideo,
        mediaLoading: mediaLoading, mediaError: mediaError, mediaKind: mediaKind };
    },
    retry: function () {
      if (!enabled || !key || !current()) return false;
      if (detailError && !mediaUnsupported && !detailBusy) request(false, false);
      else if (videoError || mediaError) retryMedia();
      if (interactionsSettled && relatedError && !relatedBusy) request(true, related !== null);
      return true;
    },
    loadMore: function () {
      if (!enabled || !current() || !interactionsSettled) return false;
      if (related === null) {
        if (relatedError && !relatedBusy) request(true, false);
        else window.PinWebDetailApi.startRelated(key);
        return true;
      }
      if (!relatedBusy && !ended) request(true, true);
      return true;
    },
    relatedUrl: function (id) {
      var pin = related && related.find(function (item) { return item.id === id; });
      return current() && pin ? pin.pinUrl : '';
    }
  };
})();`;
