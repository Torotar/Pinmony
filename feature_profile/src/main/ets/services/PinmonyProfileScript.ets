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
  var lastState = '';
  var scheduled = 0;
  var forcedSection = '';

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
    value.contextEpoch = window.PinmonyNetwork && window.PinmonyNetwork.documentEpoch ? window.PinmonyNetwork.documentEpoch() : -1;
    value.nativeOwn = !!(window.PinmonyProfileApi && window.PinmonyProfileApi.nativeOwn && window.PinmonyProfileApi.nativeOwn(value.profileUrl));
    if (value.nativeOwn && window.PinmonyProfileApi.nativeVersion) value.nativeVersion = window.PinmonyProfileApi.nativeVersion();
    if (value.nativeOwn && window.PinmonyProfileApi.nativeInvalidation) value.nativeInvalidation = window.PinmonyProfileApi.nativeInvalidation();
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
    if (window.PinmonyNetwork && typeof window.PinmonyNetwork.isForeground === 'function' && !window.PinmonyNetwork.isForeground()) {
      if (window.PinmonyProfileApi) window.PinmonyProfileApi.suspend();
      return;
    }
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
      lastState = '';
    }
    if (window.PinmonyProfileApi && window.PinmonyProfileApi.nativeOwn && window.PinmonyProfileApi.nativeOwn(profile) && !window.PinmonyProfileApi.currentInfo(profile)) {
      notify('profile', { kind: 'nativeContext', session: session, profileUrl: profile, section: section }); return;
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
      monthlyViews: apiInfo ? apiInfo.monthlyViews : undefined,
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
  window.PinmonyProfileNativeSection = function (section) { if (section === 'saved' || section === 'created') { forcedSection = section; lastState = ''; schedule(); } };
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
    if(window.PinmonyNativeSharePublishEnabled === true)return false;
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
    schedule();
    return true;
  };
  window.PinmonyProfileSync = function () { lastState = ''; sync(); };
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
    return false;
  };
  window.PinmonyProfileOrganizeAction = function (requestedSession, requestedProfile, action, value, secret) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile || activeSection !== 'saved') return false;
    return !!(window.PinmonyProfileApi && window.PinmonyProfileApi.organizeAction &&
      window.PinmonyProfileApi.organizeAction(action, value, secret));
  };
  function start() {
    // Profile presentation is API-only; document mutations are not data signals.
    window.addEventListener('popstate', schedule);
    window.addEventListener('pageshow', schedule);
    window.addEventListener('pagehide', function () {
      if (scheduled) clearTimeout(scheduled); scheduled = 0;
      if (window.PinmonyProfileApi) window.PinmonyProfileApi.suspend();
    });
    window.setInterval(function () { if (documentActive && profileUrl()) schedule(); }, 2000);
    schedule();
  }
  start();
})();`;

