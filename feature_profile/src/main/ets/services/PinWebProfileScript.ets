// Profile data and tab changes use website resource APIs through the current ArkWeb session.
// The hidden document remains mounted for session and route continuity; it is not a profile
// data source and no profile list/action falls back to DOM extraction or clicks.
export const PIN_PROFILE_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
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
  function notify(kind, value) {
    if (!window.PinWebShareBridge) return;
    var serialized = JSON.stringify(value);
    if (kind === 'profile') {
      if (serialized === lastState) return;
      lastState = serialized;
      if (window.PinWebShareBridge.profileState) window.PinWebShareBridge.profileState(serialized);
    } else if (window.PinWebShareBridge.profilePublish) {
      window.PinWebShareBridge.profilePublish(serialized);
    }
  }
  function sync() {
    scheduled = 0;
    var profile = profileUrl();
    if (!profile && window.PinWebProfileApi) {
      if (window.PinWebProfileApi.retainForRoute()) window.PinWebProfileApi.suspend();
      else window.PinWebProfileApi.reset();
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
    if (forcedSection && routeSection !== forcedSection && /_(?:created|saved)(?:\\/|$)/i.test(location.pathname)) {
      forcedSection = '';
    }
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
    var apiState = window.PinWebProfileApi && window.PinWebProfileApi.read(profile, schedule, function () {
      return profileUrl() === profile && activeProfile === profile;
    });
    if (window.PinWebProfileApiEnabled === true && (!apiState || apiState.kind !== 'ready')) {
      if (apiState && apiState.kind === 'loading' && window.PinWebProfileApi.prefetchSaved) {
        window.PinWebProfileApi.prefetchSaved(profile, section, function () {
          return profileUrl() === profile && activeProfile === profile && activeSection === section;
        });
      }
      notify('profile', { kind: apiState && apiState.kind === 'failed' ? 'apiFailed' : 'apiPending',
        session: session, profileUrl: profile, section: section });
      return;
    }
    var content = apiState && window.PinWebProfileApi.readContent(profile, section, schedule, function () {
      return profileUrl() === profile && activeProfile === profile && activeSection === section;
    });
    var unorganized = apiState && window.PinWebProfileApi.readUnorganized &&
      window.PinWebProfileApi.readUnorganized(profile, section, schedule, function () {
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
    scheduled = setTimeout(sync, 140);
  }
  function restorePublishMenu() {
    if (publishMenu && publishMenu.isConnected) {
      if (publishOriginal) publishMenu.style.setProperty('display', publishOriginal, publishPriority);
      else publishMenu.style.removeProperty('display');
    }
    publishMenu = null;
    publishOptions = {};
    publishSnapshot = [];
  }
  function publishKind(value) {
    var normalized = (value || '').replace(/\s+/g, ' ').trim();
    if (/(?:网站|Website|Web site|web)/i.test(normalized) && !/(?:网页搜索|search web)/i.test(normalized)) return 'website';
    if (/(?:照片|Photo|Photos|图片|Image|upload)/i.test(normalized)) return 'photo';
    if (/(?:图板|创建图板|新建图板|Board|Create Board)/i.test(normalized)) return 'board';
    return '';
  }
  function publishTitle() {
    if (!publishMenu) return '';
    var headings = publishMenu.querySelectorAll('h1, h2, h3, [role="heading"], span, div');
    for (var index = 0; index < headings.length; index++) {
      var value = label(headings[index]);
      if (/^(?:添加到个人资料|Add to profile|Add to your profile)$/i.test(value)) return value;
    }
    return '';
  }
  function containsPublishOptions(node) {
    if (!node || !node.querySelectorAll) return false;
    var nodes = node.querySelectorAll('button, a, [role="menuitem"], [role="button"], span, div');
    var found = {};
    for (var index = 0; index < nodes.length; index++) {
      var kind = publishKind(label(nodes[index]));
      if (kind) found[kind] = true;
    }
    return !!(found.website && found.photo && found.board);
  }
  function findPublishMenu() {
    var nodes = document.querySelectorAll('[role="dialog"], [role="menu"], [aria-modal="true"], [data-test-id*="create"], [data-test-id*="Create"]');
    for (var index = 0; index < nodes.length; index++) {
      var node = nodes[index];
      if (!visible(node)) continue;
      var bounds = node.getBoundingClientRect();
      if (bounds.width < 650 && bounds.height < innerHeight * .8 && containsPublishOptions(node)) return node;
    }
    var options = document.querySelectorAll('button, a, [role="menuitem"], [role="button"], span, div');
    for (var optionIndex = 0; optionIndex < options.length; optionIndex++) {
      var option = options[optionIndex];
      if (!visible(option) || !publishKind(label(option))) continue;
      for (var parent = option.parentElement, depth = 0; parent && depth < 5;
           parent = parent.parentElement, depth++) {
        var bounds = parent.getBoundingClientRect();
        if (bounds.width < 650 && bounds.height < innerHeight * .8 &&
          containsPublishOptions(parent)) return parent;
      }
    }
    return null;
  }
  function readPublishOptions() {
    publishOptions = {};
    publishSnapshot = [];
    if (!publishMenu || !publishMenu.isConnected) return;
    var nodes = publishMenu.querySelectorAll('button, a, [role="menuitem"], [role="button"], span, div');
    var found = {};
    for (var index = 0; index < nodes.length; index++) {
      var node = nodes[index];
      if (!visible(node)) continue;
      var name = label(node);
      var kind = publishKind(name);
      if (!kind || found[kind]) continue;
      var target = node;
      for (var depth = 0; depth < 4 && target.parentElement && target !== publishMenu; depth++) {
        if (target.matches('button, a, [role="menuitem"], [role="button"]')) break;
        target = target.parentElement;
      }
      if (!target || target === publishMenu) target = node;
      var id = 'publish-' + session + '-' + kind;
      var group = kind === 'board' ? 'add' : 'create';
      var groupLabel = group === 'add' ? (/添加/.test(text(publishMenu)) ? '添加' : 'Add') :
        (/创建/.test(text(publishMenu)) ? '创建' : 'Create');
      publishOptions[id] = target;
      publishSnapshot.push({ id: id, kind: kind, group: group, groupLabel: groupLabel,
        label: name, enabled: enabled(target) });
      found[kind] = true;
    }
  }
  window.PinWebProfileTab = function (requestedSession, requestedProfile, section) {
    if ((section !== 'created' && section !== 'saved') ||
      requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile ||
      !window.PinWebProfileApiEnabled || !window.PinWebProfileApi) return false;
    try {
      var profilePath = new URL(activeProfile).pathname;
      history.replaceState({}, '', profilePath + (section === 'created' ? '_created/' : ''));
    } catch (_) { return false; }
    forcedSection = '';
    activeSection = section;
    lastState = '';
    schedule();
    return true;
  };
  window.PinWebProfileAction = function (requestedSession, requestedProfile, id) {
    if (window.PinWebProfileApiEnabled === true && /^\\d+$/.test(id)) {
      if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
      return !!(window.PinWebProfileApi.openUnorganized && window.PinWebProfileApi.openUnorganized(id));
    }
    if (window.PinWebProfileApiEnabled === true && /^profile-api-/.test(id)) {
      if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
      return window.PinWebProfileApi.open(id);
    }
    return false;
  };
  window.PinWebProfilePublishDiscover = function (requestedSession, requestedProfile) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
    var create = null;
    for (var id in controls) {
      var control = controls[id];
      var controlLabel = label(control);
      var controlTestId = control && (control.getAttribute('data-test-id') || control.getAttribute('data-test-id-content') || '') || '';
      if (control && (/(?:创建|添加|发布|Create|Add)/i.test(controlLabel) ||
          /(?:create|add|publish|new-pin|pin-builder)/i.test(controlTestId) || controlLabel === '+')) {
        create = control; break;
      }
    }
    if (!create) {
      var buttons = document.querySelectorAll('button, [role="button"]');
      for (var buttonIndex = 0; buttonIndex < buttons.length; buttonIndex++) {
        var button = buttons[buttonIndex];
        var buttonLabel = label(button);
        var buttonTestId = button.getAttribute('data-test-id') || button.getAttribute('data-test-id-content') || '';
        if (visible(button) && enabled(button) &&
          (/(?:创建|添加|发布|Create|Add)/i.test(buttonLabel) || /(?:create|add|publish|new-pin|pin-builder)/i.test(buttonTestId) || buttonLabel === '+')) {
          create = button;
          break;
        }
      }
    }
    if (!create) {
      notify('publish', { kind: 'state', session: session, profileUrl: activeProfile, options: [] });
      return false;
    }
    publishTrigger = create;
    create.click();
    var attempts = 0;
    function capture() {
      if (requestedSession !== session || requestedProfile !== activeProfile ||
        profileUrl() !== activeProfile) return;
      publishMenu = findPublishMenu();
      if (!publishMenu && attempts++ < 12) { setTimeout(capture, 180); return; }
      if (publishMenu) {
        readPublishOptions();
        publishOriginal = publishMenu.style.getPropertyValue('display');
        publishPriority = publishMenu.style.getPropertyPriority('display');
        publishMenu.style.setProperty('display', 'none', 'important');
      }
      notify('publish', { kind: 'state', session: session, profileUrl: activeProfile,
        title: publishTitle(),
        options: publishSnapshot });
    }
    setTimeout(capture, 180);
    return true;
  };
  window.PinWebProfilePublishSelect = function (requestedSession, requestedProfile, id) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
    var target = publishOptions[id];
    if (!target || !target.isConnected || !enabled(target)) return false;
    restorePublishMenu();
    flowActive = true;
    flowSawPanel = false;
    target.click();
    schedule();
    return true;
  };
  window.PinWebProfilePublishClose = function (requestedSession, requestedProfile) {
    if (requestedSession !== session || requestedProfile !== activeProfile) return false;
    restorePublishMenu();
    var menu = findPublishMenu();
    if (menu) {
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      if (menu.isConnected && visible(menu) && publishTrigger && publishTrigger.isConnected) publishTrigger.click();
    }
    publishTrigger = null;
    schedule();
    return true;
  };
  window.PinWebProfileSync = function () { lastState = ''; schedule(); };
  window.PinWebProfileRefresh = function (force) {
    if (!force && window.PinWebProfileApiEnabled === true && window.PinWebProfileApi && activeProfile &&
        window.PinWebProfileApi.hasContentError()) {
      window.PinWebProfileApi.retryContent(activeProfile, activeSection, schedule, function () {
        return profileUrl() === activeProfile;
      });
      return;
    }
    if (window.PinWebProfileApi) window.PinWebProfileApi.reset();
    lastState = ''; schedule();
  };
  window.PinWebProfileResume = function () {
    if (window.PinWebProfileApi) window.PinWebProfileApi.reset();
    flowActive = false;
    flowSawPanel = false;
    lastState = '';
    schedule();
  };
  window.PinWebProfileLoadMore = function (requestedSession, requestedProfile) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile) return false;
    if (window.PinWebProfileApiEnabled === true) {
      var section = activeSection;
      window.PinWebProfileApi.more(activeProfile, section, schedule, function () {
        return profileUrl() === requestedProfile && activeProfile === requestedProfile && activeSection === section;
      });
      return true;
    }
    window.scrollBy(0, Math.max(350, innerHeight * .8));
    schedule();
    return true;
  };
  window.PinWebProfileOrganizeAction = function (requestedSession, requestedProfile, action, value, secret) {
    if (requestedSession !== session || requestedProfile !== activeProfile || profileUrl() !== activeProfile || activeSection !== 'saved') return false;
    return !!(window.PinWebProfileApi && window.PinWebProfileApi.organizeAction &&
      window.PinWebProfileApi.organizeAction(action, value, secret));
  };
  function start() {
    if (!document.documentElement) return;
    new MutationObserver(schedule).observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['src', 'class', 'style', 'aria-label', 'aria-selected', 'aria-current', 'disabled']
    });
    window.addEventListener('popstate', schedule);
    window.addEventListener('pageshow', schedule);
    window.setInterval(schedule, 700);
    schedule();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();`;

