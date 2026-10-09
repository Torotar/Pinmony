// Uses the current ArkWeb session; never stores or copies browser credentials.
export const PIN_PROFILE_API_ENABLED: boolean = true;

export const PIN_PROFILE_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var key = '', generation = 0, abort = null, attempted = false, info = null, failed = false;
  var savedPrefetch = null;
  function cancelSavedPrefetch() {
    if (savedPrefetch) savedPrefetch.controller.abort();
    savedPrefetch = null;
  }
  function reset() {
    cancelSavedPrefetch();
    generation++;
    if (abort) abort.abort();
    key = ''; abort = null; attempted = false; info = null; failed = false;
    resetContent();
  }
  function suspend() {
    cancelSavedPrefetch();
    // Keep completed API data and pagination, but invalidate all in-flight work.
    generation++;
    if (abort) abort.abort();
    abort = null;
    if (!info) { attempted = false; failed = false; }
    contentGeneration++;
    if (contentAbort) contentAbort.abort();
    contentAbort = null;
    if (contentState) {
      contentState.loading = false;
      if (!contentState.ready) resetContent();
    }
  }
  function clean(value, limit) {
    return typeof value === 'string' ? value.trim().slice(0, limit) : '';
  }
  function mapUser(user, username) {
    if (!user || user.type !== 'user' ||
        clean(user.username, 100).toLowerCase() !== username.toLowerCase()) return null;
    var avatar = [user.image_large_url, user.image_medium_url, user.image_small_url].filter(function (url) {
      return typeof url === 'string' && /^https:\\/\\//i.test(url);
    })[0] || '';
    function count(value) {
      return typeof value === 'number' && isFinite(value) && value >= 0 && Math.floor(value) === value ? value : null;
    }
    return { name: clean(user.full_name, 160), handle: clean(user.username, 100),
      followingUser: typeof user.explicitly_followed_by_me === 'boolean' ? user.explicitly_followed_by_me : null, blocked: user.blocked_by_me === true, business: user.is_partner === true, about: clean(user.about, 2000), website: clean(user.website_url, 2000),
      avatar: avatar.slice(0, 2000), followers: count(user.follower_count), following: count(user.following_count) };
  }
  async function request(profile, changed, current) {
    var token = generation, requestAbort = new AbortController();
    abort = requestAbort;
    var timer = setTimeout(function () { requestAbort.abort(); }, 10000);
    try {
      var username = decodeURIComponent(new URL(profile).pathname.split('/')[1]);
      var data = { options: { field_set_key: 'profile', username: username }, context: {} };
      var url = '/resource/UserResource/get/?source_url=' + encodeURIComponent(location.pathname) +
        '&data=' + encodeURIComponent(JSON.stringify(data)) + '&_=' + Date.now();
      var response = await fetch(url, { credentials: 'same-origin', signal: requestAbort.signal,
        headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest',
          'X-Pinterest-Pws-Handler': 'www/index.js' } });
      if (!response.ok) throw new Error('http-error');
      var payload = await response.json();
      if (token !== generation || key !== profile || !current()) return;
      var resource = payload.resource_response;
      var mapped = resource && resource.status === 'success' ? mapUser(resource.data, username) : null;
      if (!mapped) throw new Error('invalid-user');
      mapped.userId = clean(resource.data.id, 100);
      mapped.viewerId = clean(payload.client_context && payload.client_context.user && payload.client_context.user.id, 100);
      mapped.isOwn = payload.client_context && payload.client_context.user && payload.client_context.user.id ?
        payload.client_context.user.id === resource.data.id : null;
      mapped.pinCount = typeof resource.data.pin_count === 'number' && isFinite(resource.data.pin_count) &&
        resource.data.pin_count >= 0 && Math.floor(resource.data.pin_count) === resource.data.pin_count ? resource.data.pin_count : null;
      mapped.lastPinSaveTime = clean(resource.data.last_pin_save_time, 100);
      info = mapped;
      changed();
    } catch (_) {
      // Pure API mode reports failure; retry is explicit, never a polling loop.
      if (token === generation && key === profile && current()) {
        cancelSavedPrefetch();
        failed = true;
        changed();
        console.warn('PinWeb: profile API unavailable');
      }
    } finally {
      clearTimeout(timer);
      if (token === generation && abort === requestAbort) abort = null;
    }
  }
  var contentKey = '', contentGeneration = 0, contentAbort = null, contentState = null, targets = {};
  function resetContent() {
    contentGeneration++;
    if (contentAbort) contentAbort.abort();
    contentKey = ''; contentAbort = null; contentState = null; targets = {};
  }
  function safeUrl(value) {
    if (typeof value !== 'string' || !value.trim()) return '';
    try {
      var url = new URL(value, location.origin || 'https://www.pinterest.com');
      return url.protocol === 'https:' && url.origin === new URL(key).origin ? url.href : '';
    } catch (_) { return ''; }
  }
  function image(value) { return typeof value === 'string' && /^https:\\/\\//i.test(value) ? value : ''; }
  function relativeTime(value) {
    if (typeof value !== 'string' || !value.trim()) return '';
    var timestamp = Date.parse(value), elapsed = Date.now() - timestamp;
    if (!isFinite(timestamp) || elapsed < 0) return '';
    var minutes = Math.floor(elapsed / 60000);
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return minutes + ' 分钟前';
    var hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + ' 小时前';
    var days = Math.floor(hours / 24);
    if (days < 7) return days + ' 天前';
    if (days < 30) return Math.floor(days / 7) + ' 周前';
    if (days < 365) return Math.floor(days / 30) + ' 个月前';
    return Math.floor(days / 365) + ' 年前';
  }
  function mapItem(item, section) {
    var target = '', card;
    if (section === 'saved') {
      if (item.type === 'board') {
        target = safeUrl(item.url);
        var covers = (item.images && item.images['236x'] || []).map(function (img) { return image(img.url); }).filter(Boolean);
        if (!covers.length && image(item.image_cover_hd_url || item.image_cover_url)) covers.push(item.image_cover_hd_url || item.image_cover_url);
        card = { title: clean(item.name, 300), covers: covers.slice(0, 3),
          pinCount: typeof item.pin_count === 'number' && item.pin_count >= 0 ? item.pin_count + ' 张 Pin 图' : '',
          updated: relativeTime(item.board_order_modified_at) };
      } else if (item.type === 'story' && item.story_type === 'all_pins') {
        if (info.pinCount === 0 && !(item.objects || []).length) return null;
        target = safeUrl(item.action && item.action.url);
        if (target) {
          var internal = new URL(target).pathname.match(/^\\/users\\/(\\d+)\\/pins\\/?$/);
          if (internal) {
            if (internal[1] !== info.userId) return null;
            target = key + 'pins/'; // HAR-confirmed public collection route.
          }
        }
        card = { title: clean(item.title && (item.title.text || item.title.format), 300),
          covers: (item.objects || []).map(function (pin) { return image(pin.image_medium_url); }).filter(Boolean).slice(0, 3),
          pinCount: info.pinCount !== null ? info.pinCount + ' 张 Pin 图' : '',
          updated: relativeTime(info.lastPinSaveTime) };
      } else return null;
    } else {
      if (item.type !== 'pin' || !/^\\d+$/.test(item.id || '')) return null;
      target = safeUrl('/pin/' + item.id + '/');
      var img = item.images && (item.images['736x'] || item.images['474x'] || item.images['236x'] || item.images.orig);
      if (!img || !image(img.url)) return null;
      card = { title: clean(item.grid_title || item.title, 300), targetUrl: target, imageUrl: img.url,
        imageWidth: typeof img.width === 'number' ? img.width : 0, imageHeight: typeof img.height === 'number' ? img.height : 0 };
    }
    if (!target) return null;
    card.id = 'profile-api-' + contentGeneration + '-' + clean(String(item.id), 100);
    if (section === 'saved') card.targetUrl = target;
    targets[card.id] = target;
    return card;
  }
  function prefetchSaved(profile, section, current) {
    if (section !== 'saved') { cancelSavedPrefetch(); return false; }
    if (info || failed || savedPrefetch || key !== profile || !current()) return false;
    var username = decodeURIComponent(new URL(profile).pathname.split('/')[1]);
    // Only the authenticated own profile may prepare saved content early.
    if (!username || username !== window.PinWebHomeUsername) return false;
    var controller = new AbortController(), token = generation;
    var options = { field_set_key: 'profile_grid_item', filter_stories: false,
      sort: 'last_pinned_to', username: username };
    var source = new URL(profile).pathname;
    var timer = setTimeout(function () { controller.abort(); }, 10000);
    var promise = fetch('/resource/BoardsFeedResource/get/?source_url=' + encodeURIComponent(source) +
      '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now(),
      { credentials: 'same-origin', signal: controller.signal, headers: { Accept: 'application/json',
        'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } })
      .catch(function () { return null; }).finally(function () { clearTimeout(timer); });
    savedPrefetch = { profile: profile, generation: token, controller: controller, promise: promise };
    return true;
  }
  async function requestContent(profile, section, changed, current) {
    var prepared = section === 'saved' && !contentState.bookmark && savedPrefetch &&
      savedPrefetch.profile === profile && savedPrefetch.generation === generation ? savedPrefetch : null;
    if (prepared) savedPrefetch = null;
    var token = contentGeneration, requestKey = contentKey,
      requestAbort = prepared ? prepared.controller : new AbortController();
    contentAbort = requestAbort; contentState.loading = true; contentState.error = '';
    var timer = setTimeout(function () { requestAbort.abort(); }, 10000);
    try {
      if (section === 'created' && (!info.userId || info.isOwn === null)) throw new Error('unknown-profile-owner');
      var options = section === 'saved' ? { field_set_key: 'profile_grid_item', filter_stories: false,
        sort: 'last_pinned_to', username: info.handle } : { exclude_add_pin_rep: true,
        field_set_key: 'profile_created_grid_item', is_own_profile_pins: info.isOwn, user_id: info.userId, username: info.handle };
      if (contentState.bookmark) options.bookmarks = [contentState.bookmark];
      var source = new URL(profile).pathname + (section === 'created' ? '_created/' : '');
      var endpoint = section === 'saved' ? 'BoardsFeedResource' : 'UserActivityPinsResource';
      var response = prepared ? await prepared.promise : await fetch('/resource/' + endpoint + '/get/?source_url=' + encodeURIComponent(source) +
        '&data=' + encodeURIComponent(JSON.stringify({ options: options, context: {} })) + '&_=' + Date.now(),
        { credentials: 'same-origin', signal: requestAbort.signal, headers: { Accept: 'application/json',
          'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } });
      if (!response || !response.ok) throw new Error('http-error');
      var payload = await response.json(), resource = payload.resource_response;
      if (token !== contentGeneration || requestKey !== contentKey || !current()) return;
      if (!resource || resource.status !== 'success' || !Array.isArray(resource.data)) throw new Error('invalid-feed');
      var cards = resource.data.map(function (item) { return mapItem(item, section); }).filter(Boolean);
      if (resource.data.length && !cards.length && !resource.data.every(function (item) {
        return section === 'saved' && item.type === 'story' && item.story_type === 'all_pins' &&
          info.pinCount === 0 && !(item.objects || []).length;
      })) throw new Error('unsupported-feed');
      var seen = {};
      contentState.items.forEach(function (card) { seen[card.id] = true; });
      cards.forEach(function (card) { if (!seen[card.id]) { contentState.items.push(card); seen[card.id] = true; } });
      var bookmark = resource.bookmark || (payload.resource && payload.resource.options && payload.resource.options.bookmarks || [])[0] || '';
      contentState.hasMore = typeof bookmark === 'string' && !!bookmark && bookmark !== '-end-' && bookmark !== contentState.bookmark;
      contentState.bookmark = bookmark; contentState.ready = true;
    } catch (_) {
      if (token === contentGeneration && requestKey === contentKey && current()) contentState.error = '内容接口读取失败，请重试';
    } finally {
      clearTimeout(timer);
      if (token === contentGeneration && requestKey === contentKey) {
        contentAbort = null; contentState.loading = false;
        if (current()) changed();
      }
    }
  }
  window.PinWebProfileApi = {
    prefetchSaved: prefetchSaved,
    currentInfo: function (page) { return key === page ? info : null; },
    invalidateContent: resetContent,
    hasContentError: function () { return !!(contentState && contentState.error); },
    readContent: function (profile, section, changed, current) {
      if (!info) return null;
      if (contentKey !== profile + section) {
        resetContent(); contentKey = profile + section;
        contentState = { items: [], loading: false, ready: false, error: '', bookmark: '', hasMore: false };
        requestContent(profile, section, changed, current);
      }
      return contentState;
    },
    more: function (profile, section, changed, current) {
      if (!contentState || contentKey !== profile + section || contentState.loading || contentState.error || !contentState.hasMore) return;
      requestContent(profile, section, changed, current); changed();
    },
    retryContent: function (profile, section, changed, current) {
      if (contentState && contentKey === profile + section && !contentState.loading) {
        requestContent(profile, section, changed, current); changed();
      }
    },
    open: function (id) {
      if (!targets[id]) return false;
      location.href = targets[id]; return true;
    },
    reset: reset,
    suspend: suspend,
    retainForRoute: function () {
      if (!key) return false;
      var parts = location.pathname.split('/').filter(Boolean);
      var owner = new URL(key).pathname.split('/').filter(Boolean)[0];
      return !parts.length || /^(search|messages|inbox|updates|notifications|ideas|today)$/i.test(parts[0]) ||
        (parts.length === 2 && parts[0] === owner && !/^_/.test(parts[1])) ||
        (parts.length === 2 && parts[0] === 'pin' && /^\\d+$/.test(parts[1]));
    },
    read: function (profile, changed, current) {
      if (window.PinWebProfileApiEnabled !== true) { if (key) reset(); return null; }
      if (key !== profile) { reset(); key = profile; }
      if (!profile) return null;
      if (!attempted && typeof fetch === 'function' && typeof AbortController === 'function') {
        attempted = true;
        request(profile, changed, current);
      }
      if (!attempted) failed = true;
      return { kind: info ? 'ready' : failed ? 'failed' : 'loading', info: info };
    }
  };
})();`;
