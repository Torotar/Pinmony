// Profile data and tab changes use website resource APIs through the current ArkWeb session.
// The hidden document remains mounted for session and route continuity; it is not a profile
// data source and no profile list/action falls back to DOM extraction or clicks.
export const PIN_PROFILE_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var documentActive = true, bridgeWarning = false;
  if (window.addEventListener) {
    window.addEventListener('pagehide', function () { documentActive = false; });
    window.addEventListener('pageshow', function () { documentActive = true; bridgeWarning = false; lastState = ''; schedule(); });
  }
  var session = 0;
  var activeProfile = '';
  var activeSection = '';
  var controls = {};
  var lastState = '';
  var scheduled = 0;
  var forcedSection = '';
  var publishMenu = null;
  var publishTrigger = null;
  var publishOriginal = '';
  var publishPriority = '';
  var publishOptions = {};
  var publishSnapshot = [];
  var flowActive = false;
  var flowSawPanel = false;

  function text(node) {
    return node ? (node.innerText || node.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 500) : '';
  }
  function label(node) {
    return (node && (node.getAttribute('aria-label') || node.getAttribute('title') || text(node)) || '').trim();
  }
  function visible(node) {
    if (!node || !node.isConnected || !node.getBoundingClientRect) return false;
    var rect = node.getBoundingClientRect();
    var style = getComputedStyle(node);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' &&
      style.visibility !== 'hidden' && style.opacity !== '0';
  }
  function enabled(node) {
    return !!node && !node.disabled && node.getAttribute('disabled') === null &&
      node.getAttribute('aria-disabled') !== 'true';
  }
  function imageUrl(node) {
    var value = node && (node.currentSrc || node.src || node.getAttribute('src')) || '';
    return /^https:\\/\\//i.test(value) ? value.slice(0, 2000) : '';
  }
  function profileUrl() {
    var parts = location.pathname.split('/').filter(Boolean);
    if (!parts.length || /^(pin|search|messages|inbox|updates|notifications|login|signup|ideas|today|settings)$/i.test(parts[0])) return '';
    if (parts.length > 2 || (parts.length === 2 &&
      !/^_(?:saved|created)$/i.test(parts[1]))) return '';
    return location.origin + '/' + parts[0] + '/';
  }
  window.PinmonyProfileDemand = function (page) {
    if (!documentActive || page !== location.href) return false;
    clearTimeout(scheduled); scheduled = 0; sync(); return true;
  };
  function notify(kind, value) {
    if (!documentActive) return;
    var serialized = JSON.stringify(value);
    if (kind === 'profile' && serialized === lastState) return;
    try {
      var bridge = window.PinmonyShareBridge;
      var method = kind === 'profile' ? 'profileState' : 'profilePublish';
      if (!bridge || !bridge[method]) return;
      bridge[method](serialized);
      if (kind === 'profile') lastState = serialized;
    } catch (_) { if (!bridgeWarning) { bridgeWarning = true; console.warn('BridgeTrace: profile unavailable'); } }
  }
  function sync() {
    scheduled = 0;
    if (!documentActive) return;
    if (window.PinmonyNativeNetworkEnabled === true && window.PinmonyNetwork && typeof window.PinmonyNetwork.isReady === "function" && !window.PinmonyNetwork.isReady()) return;
    scheduled = 0;
    var profile = profileUrl();
    if (!profile && window.PinmonyProfileApi) {
      if (window.PinmonyProfileApi.retainForRoute()) window.PinmonyProfileApi.suspend();
      else window.PinmonyProfileApi.reset();
    }
    if (!profile) {
      if (activeProfile) {
        activeProfile = '';
        activeSection = '';
        forcedSection = '';
        session++;
        controls = {};
        restorePublishMenu();
        publishTrigger = null;
        notify('profile', { kind: 'closed', session: session, profileUrl: '', section: '' });
      }
      return;
    }
    var routeSection = /_created(?:\\/|$)/i.test(location.pathname) ? 'created' : 'saved';
    if (profile !== activeProfile) forcedSection = '';
    var section = forcedSection || routeSection;
    if (profile !== activeProfile || section !== activeSection) {
      activeProfile = profile;
      activeSection = section;
      session++;
      controls = {};
      lastState = '';
      flowActive = false;
      flowSawPanel = false;
      restorePublishMenu();
      publishTrigger = null;
    }
    var apiState = window.PinmonyProfileApi && window.PinmonyProfileApi.read(profile, schedule, function () {
      return profileUrl() === profile && activeProfile === profile;
    });
    if (window.PinmonyProfileApiEnabled === true && (!apiState || apiState.kind !== 'ready')) {
      if (apiState && apiState.kind === 'loading' && window.PinmonyProfileApi.prefetchSaved) {
        window.PinmonyProfileApi.prefetchSaved(profile, section, function () {
          return profileUrl() === profile && activeProfile === profile && activeSection === section;
        });
      }
      notify('profile', { kind: apiState && apiState.kind === 'failed' ? 'apiFailed' : 'apiPending',
        session: session, profileUrl: profile, section: section });
      return;
    }
    var content = apiState && window.PinmonyProfileApi.readContent(profile, section, schedule, function () {
      return profileUrl() === profile && activeProfile === profile && activeSection === section;
    });
    var unorganized = apiState && window.PinmonyProfileApi.readUnorganized &&
      window.PinmonyProfileApi.readUnorganized(profile, section, schedule, function () {
        return profileUrl() === profile && activeProfile === profile && activeSection === section;
      });
    var info = { name: '', handle: '', avatar: '', followers: '', following: '' };
    var apiInfo = apiState && apiState.info;
    if (apiInfo) {
      var chinese = /^zh/i.test(navigator.language || '');
      info.name = apiInfo.name;
      info.handle = apiInfo.handle;
      info.avatar = apiInfo.avatar;
      if (apiInfo.followers !== null) info.followers = apiInfo.followers + (chinese ? ' 粉丝' : ' followers');
      if (apiInfo.following !== null) info.following = apiInfo.following + (chinese ? ' 关注中' : ' following');
    }
    var actions = apiInfo && apiInfo.isOwn === true ?
      [{ id: 'api-edit-profile', kind: 'edit', label: '编辑个人资料', enabled: true }] :
      apiInfo && apiInfo.isOwn === false && typeof apiInfo.followingUser === 'boolean' && !apiInfo.blocked ?
      [{ id: 'api-follow-user', kind: 'follow', label: apiInfo.followingUser ? '关注中' : '关注', enabled: true }] : [];
    notify('profile', { kind: 'state', session: session, profileUrl: profile, section: section,
      displayName: info.name, handle: info.handle, avatarUrl: info.avatar,
      followers: info.followers, following: info.following, actions: actions,
      business: !!(apiInfo && apiInfo.business), isOwn: apiInfo ? apiInfo.isOwn : undefined,
      about: apiInfo ? apiInfo.about : "", website: apiInfo ? apiInfo.website : "",
      contentLoading: !!(content && content.loading && !content.ready),
      contentError: content ? content.error : '', contentLoadingMore: !!(content && content.loading && content.ready),
      boards: section === 'saved' ? (content ? content.items : []) : [],
      createdPins: section === 'created' ? (content ? content.items : []) : [],
      unorganizedPins: unorganized ? unorganized.pins : [], unorganizedLoading: !!(unorganized && unorganized.loading),
      unorganizedError: unorganized ? unorganized.error : '', unorganizedHasMore: !!(unorganized && unorganized.hasMore),
      unorganizedFeedback: unorganized ? unorganized.feedback : '', organize: unorganized ? unorganized.organize : null });
  }
  function schedule() {
    if (scheduled) return;
    scheduled = setTimeout(sync, 0);
  }
  function restorePublishMenu() {}
  window.PinmonyProfileTab = function (requestedSession, requestedProfile, section) {
    if ((section !== 'created' && section !== 'saved') ||
      requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile ||
      !window.PinmonyProfileApiEnabled || !window.PinmonyProfileApi) return false;
    // Native sections share one bound document. Changing the URL here invalidates
    // the native transport binding before the next profile snapshot can be read.
    forcedSection = section;
    lastState = '';
    schedule();
    return true;
  };
  window.PinmonyProfileAction = function (requestedSession, requestedProfile, id) {
    if (window.PinmonyProfileApiEnabled === true && /^\\d+$/.test(id)) {
      if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
      return !!(window.PinmonyProfileApi.openUnorganized && window.PinmonyProfileApi.openUnorganized(id));
    }
    if (window.PinmonyProfileApiEnabled === true && /^profile-api-/.test(id)) {
      if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
      return window.PinmonyProfileApi.open(id);
    }
    return false;
  };
  window.PinmonyProfilePublishDiscover = function (requestedSession, requestedProfile) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile ||
        !window.PinmonyProfileApiEnabled) return false;
    notify('publish', { kind: 'state', session: session, profileUrl: activeProfile, title: '创建', options: [
      { id: 'native-website', kind: 'website', group: 'create', groupLabel: '创建', label: '网站', enabled: true },
      { id: 'native-photo', kind: 'photo', group: 'create', groupLabel: '创建', label: '照片', enabled: true },
      { id: 'native-board', kind: 'board', group: 'add', groupLabel: '添加', label: '图板', enabled: true }
    ] });
    return true;
  };
  window.PinmonyProfilePublishSelect = function () { return false; };
  window.PinmonyProfilePublishClose = function (requestedSession, requestedProfile) {
    if (requestedSession !== session || requestedProfile !== activeProfile) return false;
    restorePublishMenu();
    publishTrigger = null;
    schedule();
    return true;
  };
  window.PinmonyProfileSync = function () { lastState = ''; schedule(); };
  window.PinmonyProfileRefresh = function (force) {
    if (!force && window.PinmonyProfileApiEnabled === true && window.PinmonyProfileApi && activeProfile &&
        window.PinmonyProfileApi.hasContentError()) {
      window.PinmonyProfileApi.retryContent(activeProfile, activeSection, schedule, function () {
        return profileUrl() === activeProfile;
      });
      return;
    }
    if (window.PinmonyProfileApi) window.PinmonyProfileApi.reset();
    lastState = ''; schedule();
  };
  window.PinmonyProfileResume = function () {
    if (window.PinmonyProfileApi) window.PinmonyProfileApi.reset();
    flowActive = false;
    flowSawPanel = false;
    lastState = '';
    schedule();
  };
  window.PinmonyProfileLoadMore = function (requestedSession, requestedProfile) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
    if (window.PinmonyProfileApiEnabled === true) {
      var section = activeSection;
      window.PinmonyProfileApi.more(activeProfile, section, schedule, function () {
        return profileUrl() === requestedProfile && activeProfile === requestedProfile && activeSection === section;
      });
      return true;
    }
    window.scrollBy(0, Math.max(350, innerHeight * .8));
    schedule();
    return true;
  };
  window.PinmonyProfileOrganizeAction = function (requestedSession, requestedProfile, action, value, secret) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile || activeSection !== 'saved') return false;
    return !!(window.PinmonyProfileApi && window.PinmonyProfileApi.organizeAction &&
      window.PinmonyProfileApi.organizeAction(action, value, secret));
  };
  function start() {
    if (!document.documentElement) return;
    new MutationObserver(schedule).observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['src', 'class', 'style', 'aria-label', 'aria-selected', 'aria-current', 'disabled']
    });
    window.addEventListener('popstate', schedule);
    window.addEventListener('pageshow', schedule);
    window.setInterval(function () { if (documentActive && profileUrl()) schedule(); }, 2000);
    schedule();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();`;

