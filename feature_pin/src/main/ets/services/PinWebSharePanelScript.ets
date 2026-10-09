export const SHARE_PANEL_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var panel = null;
  var apiSharePin = '';
  var profileSharePage = '';
  var hiddenRoots = [];
  var session = 0;
  var nextId = 1;
  var ids = new WeakMap();
  var controls = {};
  var lastState = '';
  var scheduled = false;
  var closing = false;
  var missingTimer = 0;
  var opening = false;
  var closeAttempted = false;
  var openingTrigger = null;
  var homeSharePin = '';
  var homeSharePage = '';
  var replayingShareClick = false;
  var openingFrame = 0;
  var stagedState = null;
  var stagedText = '';
  var stagedAt = 0;
  var changedAt = 0;
  var publishTimer = 0;
  function ensureStyle() {
    if (document.getElementById('pinweb-native-share-style')) return;
    var style = document.createElement('style');
    style.id = 'pinweb-native-share-style';
    style.textContent = '[data-pinweb-native-share-hidden="true"] {' +
      'opacity: 0 !important; clip-path: inset(100%) !important; ' +
      'transition: none !important; animation: none !important; pointer-events: none !important; }';
    (document.head || document.documentElement).appendChild(style);
  }
  function visible(element) {
    if (!element || !element.getBoundingClientRect) return false;
    var rect = element.getBoundingClientRect();
    var style = window.getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < window.innerHeight &&
      style.display !== 'none' && style.visibility !== 'hidden';
  }
  function rendered(element) {
    if (!element || !element.isConnected || !element.getBoundingClientRect) return false;
    var rect = element.getBoundingClientRect();
    var style = window.getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 &&
      style.display !== 'none' && style.visibility !== 'hidden';
  }
  function label(element) {
    return (element.innerText || element.textContent ||
      (element.getAttribute && (element.getAttribute('aria-label') || element.getAttribute('title'))) ||
      '').trim().replace(/\\s+/g, ' ').slice(0, 300);
  }
  function heading(container, expression) {
    var candidates = container.querySelectorAll('h1, h2, h3, [role="heading"], span, div');
    for (var index = 0; index < candidates.length; index++) {
      if (visible(candidates[index]) && expression.test((candidates[index].textContent || '').trim())) {
        return candidates[index];
      }
    }
    return null;
  }
  function findPanel() {
    var mobilePanels = document.querySelectorAll('[data-test-id="mobile-signup-mask"]');
    for (var mobileIndex = mobilePanels.length - 1; mobileIndex >= 0; mobileIndex--) {
      var mobile = mobilePanels[mobileIndex];
      var mobileHeading = mobile.querySelector('[data-test-id="mobile-modal-heading"]');
      if (rendered(mobile) && mobileHeading && /^(?:分享|Share)$/i.test((mobileHeading.textContent || '').trim()) &&
          mobile.querySelector('[data-test-id="copy-link-share-icon"], [data-test-id$="share-icon"]')) return mobile;
    }
    var headings = document.querySelectorAll('h1, h2, h3, [role="heading"], span, div');
    for (var index = headings.length - 1; index >= 0; index--) {
      var titleNode = headings[index];
      var title = (titleNode.textContent || '').trim();
      if (!/^(?:Share to|Share with|Share|分享到|分享)$/i.test(title) || !visible(titleNode) ||
          openingTrigger && openingTrigger.contains(titleNode)) continue;
      var candidate = null;
      for (var parent = titleNode.parentElement, depth = 0; parent && depth < 9; parent = parent.parentElement, depth++) {
        if (openingTrigger && parent.contains(openingTrigger)) break;
        var rect = parent.getBoundingClientRect();
        if (rect.width < window.innerWidth * .85 || rect.height < 80 ||
            rect.height > window.innerHeight * .88 || rect.bottom < window.innerHeight - 90) continue;
        if (!parent.querySelector('button, a, [role="button"]')) continue;
        candidate = parent;
      }
      if (candidate) return candidate;
    }
    var inputs = document.querySelectorAll('input[placeholder*="搜索联系人"], input[placeholder*="Search contacts"], input[aria-label*="搜索联系人"], input[aria-label*="Search contacts"]');
    for (var inputIndex = inputs.length - 1; inputIndex >= 0; inputIndex--) {
      if (!visible(inputs[inputIndex])) continue;
      for (var searchParent = inputs[inputIndex].parentElement, searchDepth = 0;
           searchParent && searchDepth < 9; searchParent = searchParent.parentElement, searchDepth++) {
        var searchRect = searchParent.getBoundingClientRect();
        if (searchRect.width >= window.innerWidth * .85 && searchRect.height >= 160 &&
            searchRect.height <= window.innerHeight * .95 &&
            searchRect.bottom >= window.innerHeight - 90) return searchParent;
      }
    }
    return null;
  }
  function openingSheet() {
    if (!opening || !openingTrigger) return null;
    var mobileShare = findPanel();
    if (mobileShare && mobileShare.getAttribute('data-test-id') === 'mobile-signup-mask') return mobileShare;
    var headings = document.querySelectorAll('h1, h2, h3, [role="heading"], span, div');
    var selected = null;
    var largest = 0;
    for (var index = headings.length - 1; index >= 0; index--) {
      var title = headings[index];
      if (!rendered(title) || !/^(?:Share to|Share with|Share|分享到|分享)$/i.test((title.textContent || '').trim())) continue;
      for (var parent = title.parentElement, depth = 0; parent && depth < 9 && parent !== document.body;
           parent = parent.parentElement, depth++) {
        if (parent.contains(openingTrigger)) break;
        var rect = parent.getBoundingClientRect();
        if (rect.width < window.innerWidth * .85 || rect.height < 140 ||
            rect.height > window.innerHeight * .95 || rect.bottom < window.innerHeight - 90) continue;
        var area = rect.width * rect.height;
        if (area > largest) { selected = parent; largest = area; }
      }
    }
    if (selected) return selected;
    var controls = document.querySelectorAll('button, [role="button"], [aria-label]');
    for (var controlIndex = 0; controlIndex < controls.length; controlIndex++) {
      var control = controls[controlIndex];
      var name = (control.getAttribute('aria-label') || control.getAttribute('title') || label(control)).trim();
      if (!rendered(control) || !/^(?:关闭|关闭底部工作表|关闭面板|Close|Close bottom sheet|Close sheet|×|✕|✖)$/i.test(name)) continue;
      for (var ancestor = control.parentElement, ancestorDepth = 0;
           ancestor && ancestorDepth < 10 && ancestor !== document.body;
           ancestor = ancestor.parentElement, ancestorDepth++) {
        if (ancestor.contains(openingTrigger)) break;
        var bounds = ancestor.getBoundingClientRect();
        if (bounds.width < window.innerWidth * .85 || bounds.height < 140 ||
            bounds.height > window.innerHeight * .95 || bounds.bottom < window.innerHeight - 90) continue;
        var size = bounds.width * bounds.height;
        if (size > largest) { selected = ancestor; largest = size; }
      }
    }
    return selected;
  }
  function rootFor(candidate) {
    var result = candidate;
    for (var parent = candidate; parent && parent !== document.body; parent = parent.parentElement) {
      if (openingTrigger && parent.contains(openingTrigger)) break;
      var rect = parent.getBoundingClientRect();
      var style = window.getComputedStyle(parent);
      if (parent !== candidate && parent.querySelector('nav, [role="navigation"], main')) break;
      if ((style.position === 'fixed' || parent.getAttribute('role') === 'dialog') &&
          rect.width >= window.innerWidth * .85 && rect.height >= candidate.getBoundingClientRect().height) {
        result = parent;
      }
    }
    return result;
  }
  function hide(candidate) {
    ensureStyle();
    var root = rootFor(candidate);
    if (hiddenRoots.indexOf(root) < 0) hiddenRoots.push(root);
    root.setAttribute('data-pinweb-native-share-hidden', 'true');
  }
  function hideAddedSheet(changes) {
    if (!opening || !openingTrigger || !changes) return;
    var selected = null;
    var largest = 0;
    for (var changeIndex = 0; changeIndex < changes.length; changeIndex++) {
      var added = changes[changeIndex].addedNodes || [];
      for (var addedIndex = 0; addedIndex < added.length; addedIndex++) {
        var entry = added[addedIndex];
        if (!entry.getBoundingClientRect) continue;
        var candidates = [entry];
        if (entry.querySelectorAll) candidates = candidates.concat(Array.prototype.slice.call(entry.querySelectorAll('*')));
        for (var index = 0; index < candidates.length; index++) {
          var candidate = candidates[index];
          if (!rendered(candidate) || candidate.contains(openingTrigger)) continue;
          var rect = candidate.getBoundingClientRect();
          if (rect.width < window.innerWidth * .85 || rect.height < 140 ||
              rect.height > window.innerHeight * .95 || rect.bottom < window.innerHeight - 90) continue;
          var overlay = false;
          for (var parent = candidate; parent && parent !== document.body; parent = parent.parentElement) {
            if (parent.contains(openingTrigger)) break;
            var style = window.getComputedStyle(parent);
            if (style.position === 'fixed' || style.position === 'absolute' ||
                parent.getAttribute('role') === 'dialog' || parent.getAttribute('aria-modal') === 'true') {
              overlay = true;
              break;
            }
          }
          var area = rect.width * rect.height;
          if (overlay && area > largest) { selected = candidate; largest = area; }
        }
      }
    }
    if (selected) hide(selected);
  }
  function register(element) {
    var id = ids.get(element);
    if (!id) {
      id = 's' + session + '-' + nextId++;
      ids.set(element, id);
    }
    controls[id] = element;
    return id;
  }
  function iconOf(element) {
    var image = element.querySelector('img');
    var source = image && (image.currentSrc || image.src) || '';
    return /^https?:\\/\\//i.test(source) || /^data:image\\//i.test(source) ? source.slice(0, 2000) : '';
  }
  function pinUrl() {
    if (homeSharePin && homeSharePage === location.origin + location.pathname) return homeSharePin;
    var selected = window.PinWebSelectedPin ? window.PinWebSelectedPin() : '';
    if (/\\/pin\\/\\d+/.test(location.pathname)) return location.href;
    if (selected) return selected;
    if (panel) {
      var link = panel.querySelector('a[href*="/pin/"]');
      if (link) return link.href;
    }
    return '';
  }
  function snapshot() {
    var external = [];
    var actions = [];
    var contacts = [];
    var searchId = '';
    var searchLabel = '';
    var sendId = '';
    var sendLabel = '';
    var searchInput = panel.querySelector('input[type="search"], input[placeholder*="搜索"], input[placeholder*="Search"], input[aria-label*="搜索"], input[aria-label*="Search"]');
    var section = heading(panel, /^(?:在 Pinterest 上发送|在 Pinerest 上发送|Send on Pinterest)$/i);
    var optionsHeading = heading(panel, /^(?:选项|Options)$/i);
    var titleNode = heading(panel, /^(?:Share to|Share with|Share|分享到|分享)$/i);
    var titleBottom = titleNode ? titleNode.getBoundingClientRect().bottom : panel.getBoundingClientRect().top;
    var panelWidth = panel.getBoundingClientRect().width;
    var nodes = panel.querySelectorAll('a, button, [role="button"], [role="option"]');
    var searchTop = panel.getBoundingClientRect().bottom;
    for (var searchIndex = 0; searchIndex < nodes.length; searchIndex++) {
      var searchNode = nodes[searchIndex];
      if (rendered(searchNode) &&
          /^(?:搜索联系人|搜索用户|Search contacts|Search people|Search users)$/i.test(label(searchNode))) {
        searchTop = Math.min(searchTop, searchNode.getBoundingClientRect().top);
      }
    }
    var sectionTop = section ? section.getBoundingClientRect().top :
      optionsHeading ? optionsHeading.getBoundingClientRect().top : searchTop;
    var seen = [];
    for (var index = 0; index < nodes.length; index++) {
      var node = nodes[index];
      if (node.querySelector('a, button, [role="button"], [role="option"]')) continue;
      if (!visible(node) || seen.some(function (parent) { return parent.contains(node); })) continue;
      var name = label(node);
      if (!name || name.length > 300 || /^(?:关闭(?:背景模式|底部工作表|面板)?|返回|取消|Close|Back|Cancel|×|✕)$/i.test(name)) continue;
      var rect = node.getBoundingClientRect();
      if (rect.bottom <= titleBottom + 2) continue;
      if (/^(?:搜索联系人|搜索用户|Search contacts|Search people|Search users)$/i.test(name)) {
        searchId = register(node);
        searchLabel = name;
        seen.push(node);
        continue;
      }
      if (/^(?:发送|Send)$/i.test(name) && (searchInput || rect.top >= sectionTop)) {
        sendId = register(node);
        sendLabel = name;
        seen.push(node);
        continue;
      }
      var option = { id: register(node), label: name, icon: iconOf(node),
        targetUrl: node.href || '',
        enabled: !node.disabled && node.getAttribute('aria-disabled') !== 'true' };
      var textAction = /^(?:下载|隐藏|举报|复制|分享此 Pin 图的链接|Download|Hide|Report|Copy link)/i.test(name);
      if (!searchInput && rect.top < sectionTop - 4 && rect.width < panelWidth * .55 &&
          external.length < 24) {
        external.push(option);
        seen.push(node);
      } else if (!searchInput && (node.getAttribute('role') === 'menuitem' || textAction ||
          (rect.top < sectionTop - 4 && rect.width >= panelWidth * .55) ||
          (optionsHeading && rect.top >= sectionTop)) &&
          actions.length < 24) {
        var raw = (node.innerText || node.textContent || '').trim();
        var lines = raw.split(/\\n+/).map(function (part) { return part.trim(); }).filter(Boolean);
        actions.push({ id: option.id, label: lines[0] || name, subtitle: lines.slice(1).join(' '),
          icon: option.icon, enabled: option.enabled, beforeSection: rect.top < sectionTop - 4 });
        seen.push(node);
      } else if (!searchInput && rect.top < sectionTop - 4 && external.length < 24) {
        external.push(option);
        seen.push(node);
      } else if (rect.top >= (searchInput ? searchInput.getBoundingClientRect().bottom - 2 : sectionTop) &&
                 contacts.length < 60) {
        contacts.push(option);
        seen.push(node);
      }
    }
    var feedback = '';
    var alerts = document.querySelectorAll('[role="alert"], [role="status"]');
    for (var alertIndex = alerts.length - 1; alertIndex >= 0; alertIndex--) {
      if (visible(alerts[alertIndex])) {
        feedback = label(alerts[alertIndex]);
        if (feedback) break;
      }
    }
    var alternateTitle = !titleNode ? panel.querySelector('h1, h2, h3, [role="heading"]') : null;
    var result = { kind: 'state', session: session, pinUrl: pinUrl(),
      pinDetail: /^\\/pin\\/\\d+(?:\\/|$)/i.test(location.pathname),
      title: titleNode ? (titleNode.textContent || '').trim() :
        (alternateTitle && visible(alternateTitle) ? (alternateTitle.textContent || '').trim() : ''),
      sectionLabel: section ? (section.textContent || '').trim() :
        optionsHeading ? (optionsHeading.textContent || '').trim() : '',
      options: external, actions: actions, searchId: searchId,
      searchLabel: searchInput ? (searchInput.getAttribute('placeholder') || searchInput.getAttribute('aria-label') || '') : searchLabel,
      searchActive: !!searchInput, query: searchInput ? searchInput.value : '',
      contacts: contacts, sendId: sendId, sendLabel: sendLabel, feedback: feedback };
    return window.PinWebPostApi && !homeSharePin ? window.PinWebPostApi.shareSnapshot(result, schedule) : result;
  }
  function notify(state) {
    if (!window.PinWebShareBridge || !window.PinWebShareBridge.sheetState) return;
    var value = JSON.stringify(state);
    if (value === lastState) return;
    lastState = value;
    window.PinWebShareBridge.sheetState(value);
  }
  function stage(state) {
    var now = Date.now();
    var value = JSON.stringify(state);
    if (value === lastState && !stagedState) return;
    if (!stagedAt) stagedAt = now;
    if (value !== stagedText) {
      stagedState = state;
      stagedText = value;
      changedAt = now;
    }
    if (publishTimer) return;
    publishTimer = setTimeout(function publish() {
      publishTimer = 0;
      if (!panel || closing || !stagedState) return;
      var elapsed = Date.now() - stagedAt;
      var quiet = Date.now() - changedAt;
      if (elapsed < 180 || quiet < 80 && elapsed < 600) {
        publishTimer = setTimeout(publish, 80);
        return;
      }
      notify(stagedState);
      stagedState = null;
      stagedText = '';
      stagedAt = 0;
      changedAt = 0;
    }, 80);
  }
  function clear() {
    if (missingTimer) { clearTimeout(missingTimer); missingTimer = 0; }
    if (openingFrame) { cancelAnimationFrame(openingFrame); openingFrame = 0; }
    if (publishTimer) { clearTimeout(publishTimer); publishTimer = 0; }
    stagedState = null;
    stagedText = '';
    stagedAt = 0;
    changedAt = 0;
    hiddenRoots.forEach(function (root) { root.removeAttribute('data-pinweb-native-share-hidden'); });
    hiddenRoots = [];
    panel = null;
    controls = {};
    ids = new WeakMap();
    nextId = 1;
    closing = false;
    opening = false;
    closeAttempted = false;
    openingTrigger = null;
    homeSharePin = '';
    homeSharePage = '';
    notify({ kind: 'closed', session: session });
  }
  function closeWebPanel(candidate) {
    var mobileClose = candidate.querySelector('[data-test-id="mobile-modal-cancel-button"] button');
    if (mobileClose) { mobileClose.click(); return; }
    var buttons = candidate.querySelectorAll('button, [role="button"], [aria-label]');
    for (var index = 0; index < buttons.length; index++) {
      if (/^(?:关闭|关闭底部工作表|关闭面板|Close|Close bottom sheet|Close sheet|×|✕|✖)$/i.test(label(buttons[index]))) {
        buttons[index].click();
        return;
      }
    }
    (document.activeElement || candidate).dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Escape', code: 'Escape', bubbles: true
    }));
  }
  function sync() {
    scheduled = false;
    if (profileSharePage) {
      if (!window.PinWebProfilePanel || !window.PinWebProfilePanel.shareCurrent(profileSharePage)) {
        profileSharePage = ''; window.PinWebProfilePanel && window.PinWebProfilePanel.shareClose();
        notify({ kind: 'closed', session: session });
      }
      return;
    }
    if (apiSharePin) {
      if (!window.PinWebPostApi || !window.PinWebPostApi.currentPin(apiSharePin)) {
        apiSharePin = ''; window.PinWebPostApi && window.PinWebPostApi.shareClose();
        notify({ kind: 'closed', session: session });
      }
      return;
    }
    if (homeSharePin && homeSharePage !== location.origin + location.pathname) { clear(); return; }
    var early = openingSheet();
    if (early) hide(early);
    var found = findPanel();
    if (!found && panel && panel.isConnected && visible(panel)) found = panel;
    if (found) {
      if (missingTimer) { clearTimeout(missingTimer); missingTimer = 0; }
      if (!panel || panel !== found) {
        if (!panel) {
          if (!opening && !closing) {
            console.warn('PinWeb: share panel appeared without a captured share trigger');
            session++;
          }
          lastState = '';
        }
        panel = found;
        controls = {};
      }
      hide(panel);
      opening = false;
      if (openingFrame) { cancelAnimationFrame(openingFrame); openingFrame = 0; }
      if (closing) {
        if (!closeAttempted) {
          closeAttempted = true;
          closeWebPanel(panel);
        }
      } else {
        stage(snapshot());
      }
    } else if (panel && !missingTimer) {
      missingTimer = setTimeout(function () {
        missingTimer = 0;
        if (!findPanel() && (!panel || !panel.isConnected || !visible(panel))) clear();
        else schedule();
      }, 180);
    }
  }
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    Promise.resolve().then(sync);
  }
  function watchOpening() {
    if (openingFrame || typeof requestAnimationFrame !== 'function') return;
    openingFrame = requestAnimationFrame(function frame() {
      openingFrame = 0;
      if (!opening) return;
      sync();
      if (opening) watchOpening();
    });
  }
  window.PinWebNativeShareAction = function (requestedSession, id) {
    if (homeSharePin && homeSharePage !== location.origin + location.pathname) return false;
    if (window.PinWebPostApi && !homeSharePin) return window.PinWebPostApi.shareAction(requestedSession, id);
    var target = controls[id];
    if (!panel || requestedSession !== session || !target || !target.isConnected ||
        !panel.contains(target) || target.disabled || target.getAttribute('aria-disabled') === 'true') return false;
    target.click();
    schedule();
    return true;
  };
  window.PinWebNativeShareSearch = function (requestedSession, value) {
    if (homeSharePin && homeSharePage !== location.origin + location.pathname) return false;
    if (profileSharePage && window.PinWebProfilePanel) return window.PinWebProfilePanel.shareSearch(profileSharePage, requestedSession, value, function (state) { notify(state); });
    if (window.PinWebPostApi && !homeSharePin) return window.PinWebPostApi.shareSearch(requestedSession, value);
    if (!panel || requestedSession !== session) return false;
    var input = panel.querySelector('input[type="search"], input[placeholder*="搜索"], input[placeholder*="Search"], input[aria-label*="搜索"], input[aria-label*="Search"]');
    if (!input) return false;
    var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    schedule();
    return true;
  };
  window.PinWebNativeShareApiOpen = function (pin, profile) {
    if (profile === true) {
      if (!window.PinWebProfilePanel || panel || opening || closing || apiSharePin || profileSharePage) return false;
      session++; var opened = session; profileSharePage = pin;
      var accepted = window.PinWebProfilePanel.shareOpen(pin, opened, function (state) {
        if (profileSharePage === pin && opened === session) notify(state);
      });
      if (!accepted) profileSharePage = '';
      return accepted;
    }
    if (!window.PinWebPostApi || !window.PinWebPostApi.currentPin(pin) ||
        !window.PinWebPostApi.rawPin(pin) || panel || opening || closing) return false;
    homeSharePin = ''; homeSharePage = ''; apiSharePin = pin;
    session++; var openedSession = session;
    function publish() {
      if (apiSharePin !== pin || session !== openedSession || !window.PinWebPostApi.currentPin(pin)) return;
      var state = { kind: 'state', session: openedSession, pinUrl: pin, pinDetail: true,
        title: '分享', sectionLabel: '发送给', options: [], actions: [
          { id: 'api-copy', label: '复制链接', enabled: true }
        ] };
      ['Messenger', 'WhatsApp', '短信', 'Facebook', 'X'].forEach(function (name) {
        state.options.push({ id: 'api-share:' + name, label: name, enabled: true, targetUrl: '' });
      });
      notify(window.PinWebPostApi.shareSnapshot(state, publish));
    }
    publish(); return true;
  };
  window.PinWebNativeShareRefresh = function (requestedSession) {
    if (apiSharePin && requestedSession === session && window.PinWebPostApi)
      return window.PinWebPostApi.shareRetry(requestedSession);
    if (window.PinWebPostApi && panel && !homeSharePin) return window.PinWebPostApi.shareRetry(requestedSession);
    if (requestedSession !== session) return false;
    if (!panel && openingTrigger && openingTrigger.isConnected) {
      lastState = '';
      return window.PinWebNativeShareOpen(requestedSession);
    }
    if (!panel) return false;
    lastState = '';
    schedule();
    return true;
  };
  window.PinWebNativeShareOpenFromHome = function (target, requestedPin) {
    if (!target || !target.isConnected || !rendered(target) || panel || opening || closing ||
        !/^https:\\/\\/(?:[^/]+\\.)?pinterest\\.com\\/pin\\/\\d+\\/?$/i.test(requestedPin) ||
        !window.PinWebHomeMenuPin || window.PinWebHomeMenuPin !== requestedPin ||
        !/^(?:\\/|\\/(?:ideas|today)(?:\\/.*)?)$/i.test(location.pathname)) return false;
    if (target.scrollIntoView) target.scrollIntoView({ block: 'center' });
    homeSharePin = requestedPin;
    homeSharePage = location.origin + location.pathname;
    session++;
    opening = true;
    openingTrigger = target;
    lastState = '';
    notify({ kind: 'opening', session: session, pinUrl: requestedPin, pinDetail: false });
    return true;
  };
  window.PinWebNativeShareOpen = function (requestedSession) {
    if (homeSharePin && homeSharePage !== location.origin + location.pathname) return false;
    if (requestedSession !== session || !opening || closing || panel ||
        !openingTrigger || !openingTrigger.isConnected) return false;
    replayingShareClick = true;
    try { openingTrigger.click(); }
    finally { replayingShareClick = false; }
    schedule();
    watchOpening();
    var openedSession = session;
    setTimeout(function () {
      if (openedSession === session && opening && !panel && !closing) {
        notify({ kind: 'failed', session: session });
      }
    }, 1200);
    return true;
  };
  window.PinWebNativeShareClose = function (requestedSession) {
    if (requestedSession !== session) return false;
    if (profileSharePage) {
      profileSharePage = ''; window.PinWebProfilePanel && window.PinWebProfilePanel.shareClose();
      notify({ kind: 'closed', session: session }); return true;
    }
    if (window.PinWebPostApi) window.PinWebPostApi.shareClose();
    if (apiSharePin) {
      apiSharePin = ''; notify({ kind: 'closed', session: session }); return true;
    }
    closing = true;
    if (panel && !closeAttempted) {
      closeAttempted = true;
      closeWebPanel(panel);
    } else if (!panel) {
      watchOpening();
      setTimeout(function () {
        if (closing && !panel) clear();
      }, 1500);
    }
    schedule();
    return true;
  };
  function interceptShareTrigger(event) {
    if (replayingShareClick || !/^\\/pin\\/\\d+(?:\\/|$)/i.test(location.pathname) ||
        !window.PinWebShareBridge || !window.PinWebShareBridge.sheetState) return;
    var path = event.composedPath ? event.composedPath() : [];
    if (!path.length) {
      for (var ancestor = event.target, depth = 0; ancestor && depth < 12;
           ancestor = ancestor.parentElement, depth++) path.push(ancestor);
    }
    for (var index = 0; index < path.length && index < 16; index++) {
      var target = path[index];
      if (!target.matches || !target.matches('button, a, [role="button"]')) continue;
      var name = (target.getAttribute('aria-label') || target.getAttribute('title') || label(target)).trim();
      var testId = (target.getAttribute('data-test-id') || '').trim();
      var named = /^(?:分享|发送|Share|Send|分享此 Pin 图|发送此 Pin 图|发送 Pin 图|Share Pin|Share this Pin|Send Pin|Send this Pin)$/i.test(name);
      var tested = /^(?:pin[-_])?(?:share|send)(?:[-_](?:pin|button))*$/i.test(testId);
      var neighboringMore = false;
      if (!named && !tested && /\\/pin\\/\\d+/.test(location.pathname)) {
        var rect = target.getBoundingClientRect();
        var buttons = document.querySelectorAll('button, [role="button"]');
        for (var buttonIndex = 0; buttonIndex < buttons.length; buttonIndex++) {
          var other = buttons[buttonIndex];
          var otherName = (other.getAttribute('aria-label') || other.getAttribute('title') || label(other)).trim();
          if (other === target || !/^(?:more|more options|more actions|更多|更多选项|更多操作|…|⋯)$/i.test(otherName)) continue;
          var moreRect = other.getBoundingClientRect();
          if (Math.abs((rect.top + rect.bottom) / 2 - (moreRect.top + moreRect.bottom) / 2) < 36 &&
              moreRect.left >= rect.right - 12 && moreRect.left - rect.right < 120) {
            var between = false;
            for (var middleIndex = 0; middleIndex < buttons.length; middleIndex++) {
              var middle = buttons[middleIndex];
              if (middle === target || middle === other) continue;
              var middleRect = middle.getBoundingClientRect();
              if (middleRect.left > rect.left + 8 && middleRect.left < moreRect.left - 8 &&
                  Math.abs((middleRect.top + middleRect.bottom) / 2 -
                    (moreRect.top + moreRect.bottom) / 2) < 36) {
                between = true;
                break;
              }
            }
            neighboringMore = !between;
            break;
          }
        }
      }
      if (!named && !tested && !neighboringMore) continue;
      if (panel || closing) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      if (!opening) {
        session++;
        opening = true;
        openingTrigger = target;
        lastState = '';
        console.info('PinWeb: captured share trigger on ' + event.type);
        notify({ kind: 'opening', session: session, pinUrl: pinUrl(), pinDetail: true });
      }
      break;
    }
  }
  document.addEventListener('pointerdown', interceptShareTrigger, true);
  document.addEventListener('pointerup', interceptShareTrigger, true);
  document.addEventListener('click', interceptShareTrigger, true);
  window.addEventListener('pointerdown', interceptShareTrigger, true);
  window.addEventListener('pointerup', interceptShareTrigger, true);
  window.addEventListener('click', interceptShareTrigger, true);
  function start() {
    if (!document.documentElement) return;
    ensureStyle();
    new MutationObserver(function (changes) {
      hideAddedSheet(changes);
      schedule();
    }).observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['style', 'class', 'aria-hidden', 'aria-expanded', 'aria-disabled', 'value']
    });
    schedule();
  }
  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);
})();`;
