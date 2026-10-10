export const BOTTOM_BAR_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var lastVisible = null;
  var lastIndex = -1;
  var lastAddress = '';
  var currentShell = null;
  var currentTabs = null;
  var originalDisplay = null;
  var originalDisplayPriority = '';
  function visible(element) {
    if (!element || !element.getBoundingClientRect) return false;
    var rect = element.getBoundingClientRect();
    var style = window.getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
  }
  function tabIndex(element) {
    var labels = [element.getAttribute('aria-label') || '', element.innerText || element.textContent || ''];
    for (var index = 0; index < labels.length; index++) {
      var label = labels[index].trim().replace(/\\s+/g, ' ');
      if (/^(主页|首页|Home)$/i.test(label)) return 0;
      if (/^(搜索|Search)$/i.test(label)) return 1;
      if (/^(收件箱|Inbox|Messages)$/i.test(label)) return 2;
      if (/^(已收藏|收藏|Saved)$/i.test(label)) return 3;
    }
    return -1;
  }
  function tabsInside(container, includeHidden) {
    var found = [null, null, null, null];
    var controls = container.querySelectorAll('a, button, [role="button"]');
    for (var index = 0; index < controls.length; index++) {
      var control = controls[index];
      if (!includeHidden && !visible(control)) continue;
      var tab = tabIndex(control);
      if (tab >= 0 && !found[tab]) found[tab] = control;
    }
    return found[0] && found[1] && found[2] && found[3] ? found : null;
  }
  function isCompactBottomBar(shell, tabs) {
    var rect = shell.getBoundingClientRect();
    if (rect.width < window.innerWidth * .7 || rect.height < 32 || rect.height > 140 ||
        rect.top < window.innerHeight - 180 || rect.bottom < window.innerHeight - 100) return false;
    return tabs.every(function (tab) {
      var tabRect = tab.getBoundingClientRect();
      return shell.contains(tab) && tabRect.width > 0 && tabRect.height > 0 &&
        tabRect.top >= rect.top - 2 && tabRect.bottom <= rect.bottom + 2;
    });
  }
  function cachedTabsValid() {
    return currentShell && currentShell.isConnected && currentTabs &&
      currentTabs.every(function (tab, index) {
        return tab && tab.isConnected && currentShell.contains(tab) && tabIndex(tab) === index;
      });
  }
  function restoreShell() {
    if (currentShell && currentShell.isConnected && originalDisplay !== null &&
        currentShell.style.getPropertyValue('display') === 'none' &&
        currentShell.style.getPropertyPriority('display') === 'important') {
      if (originalDisplay) currentShell.style.setProperty('display', originalDisplay, originalDisplayPriority);
      else currentShell.style.removeProperty('display');
    }
    currentShell = null;
    currentTabs = null;
    originalDisplay = null;
    originalDisplayPriority = '';
  }
  function findBar() {
    var navigations = document.querySelectorAll('nav, [role="navigation"]');
    for (var index = navigations.length - 1; index >= 0; index--) {
      var nav = navigations[index];
      if (!visible(nav)) continue;
      var tabs = tabsInside(nav, false);
      if (tabs && isCompactBottomBar(nav, tabs)) return { shell: nav, tabs: tabs };
    }
    if (cachedTabsValid()) {
      return { shell: currentShell, tabs: currentTabs };
    }
    var all = document.querySelectorAll('a, button, [role="button"]');
    var found = [null, null, null, null];
    for (var controlIndex = 0; controlIndex < all.length; controlIndex++) {
      var control = all[controlIndex];
      if (!visible(control)) continue;
      var controlRect = control.getBoundingClientRect();
      if (controlRect.top < window.innerHeight - 180 || controlRect.bottom < window.innerHeight - 160) continue;
      var tabIndexValue = tabIndex(control);
      if (tabIndexValue >= 0 && !found[tabIndexValue]) found[tabIndexValue] = control;
    }
    if (!found[0] || !found[1] || !found[2] || !found[3]) return null;
    var shell = found[0].parentElement;
    while (shell && !(shell.contains(found[1]) && shell.contains(found[2]) && shell.contains(found[3]))) {
      shell = shell.parentElement;
    }
    if (!shell || shell === document.body) return null;
    if (!isCompactBottomBar(shell, found)) return null;
    return { shell: shell, tabs: found };
  }
  function selectedIndex(tabs) {
    for (var index = 0; index < tabs.length; index++) {
      if (tabs[index].getAttribute('aria-current') === 'page' ||
          tabs[index].getAttribute('aria-selected') === 'true' ||
          tabs[index].querySelector('[aria-current="page"], [aria-selected="true"]')) return index;
    }
    var path = location.pathname.toLowerCase();
    if (path.indexOf('/search') >= 0) return 1;
    if (path.indexOf('/messages') >= 0 || path.indexOf('/inbox') >= 0) return 2;
    if (path.indexOf('/_saved') >= 0 || path.indexOf('/_created') >= 0 ||
        path.indexOf('/saved') >= 0) return 3;
    var parts = path.split('/').filter(Boolean);
    if (parts.length === 1 &&
        !/^(pin|search|messages|inbox|login|signup|ideas|today|settings)$/i.test(parts[0])) {
      var controls = document.querySelectorAll('button, a, [role="tab"], [role="button"]');
      var created = false;
      var saved = false;
      for (var controlIndex = 0; controlIndex < controls.length; controlIndex++) {
        var name = (controls[controlIndex].getAttribute('aria-label') ||
          controls[controlIndex].innerText || '').trim();
        if (/^(已创建|Created)$/i.test(name)) created = true;
        if (/^(已收藏|Saved)$/i.test(name)) saved = true;
        if (created && saved) return 3;
      }
    }
    return 0;
  }
  function hasOverlay() {
    var route = location.pathname.split('/').filter(Boolean);
    if (route.length > 1 && /^(ideas|today)$/i.test(route[0])) return true;
    if (route.length && /^search$/i.test(route[0]) &&
        (route.length > 1 || (new URLSearchParams(location.search).get('q') || '').trim())) return true;
    if (route.length > 1 && /^(messages|inbox|updates|notifications)$/i.test(route[0])) return true;
    if (route.length && /^(pin|settings)$/i.test(route[0])) return true;
    if (route.length >= 2 && !/^(search|messages|inbox|ideas|today|login|signup)$/i.test(route[0]) &&
        !/^_(?:saved|created)$/i.test(route[1])) return true;
    var overlays = document.querySelectorAll('[role="dialog"], [role="menu"], [aria-modal="true"]');
    for (var index = 0; index < overlays.length; index++) {
      if (visible(overlays[index])) return true;
    }
    var headings = document.querySelectorAll('h1, h2, h3, span');
    for (var headingIndex = 0; headingIndex < headings.length; headingIndex++) {
      var heading = headings[headingIndex];
      if (!visible(heading) || !/^(分享到|分享|Share to|Share with|Share)$/i.test((heading.textContent || '').trim())) continue;
      for (var parent = heading.parentElement, depth = 0; parent && depth < 5; parent = parent.parentElement, depth++) {
        if (/Facebook|Messenger|WhatsApp|复制链接|Copy link|搜索联系人|Search contacts/.test(parent.textContent || '')) return true;
      }
    }
    var expanded = document.querySelectorAll('[aria-expanded="true"]');
    for (var expandedIndex = 0; expandedIndex < expanded.length; expandedIndex++) {
      var control = expanded[expandedIndex];
      var label = (control.getAttribute('aria-label') || control.textContent || '').trim();
      if (visible(control) && /more|options|share|send|更多|菜单|分享/i.test(label)) return true;
    }
    return false;
  }
  function notify(visibleBar, index) {
    if (!window.PinmonyShareBridge || !window.PinmonyShareBridge.navigation) return;
    if (visibleBar === lastVisible && index === lastIndex && location.href === lastAddress) return;
    window.PinmonyShareBridge.navigation(visibleBar, index);
    lastVisible = visibleBar;
    lastIndex = index;
    lastAddress = location.href;
  }
  function sync() {
    if (observer) observer.disconnect();
    try {
      if (currentShell && !cachedTabsValid()) restoreShell();
      var bar = document.body ? findBar() : null;
      if (bar) {
        if (currentShell && currentShell !== bar.shell) restoreShell();
        if (currentShell !== bar.shell) {
          currentShell = bar.shell;
          originalDisplay = bar.shell.style.getPropertyValue('display');
          originalDisplayPriority = bar.shell.style.getPropertyPriority('display');
        }
        currentTabs = bar.tabs;
        if (bar.shell.style.getPropertyValue('display') !== 'none' ||
            bar.shell.style.getPropertyPriority('display') !== 'important') {
          bar.shell.style.setProperty('display', 'none', 'important');
        }
        notify(!hasOverlay(), selectedIndex(bar.tabs));
      } else {
        restoreShell();
        notify(false, selectedIndex([]));
      }
    } finally {
      startObserver();
    }
  }
  window.PinmonySelectTab = function (index) {
    var bar = findBar();
    if (!bar || index < 0 || index > 3) return false;
    bar.tabs[index].click();
    return true;
  };
  window.PinmonyNavigationRefresh = function () {
    lastVisible = null;
    sync();
    return true;
  };
  function relevantNode(element) {
    if (!element || element.nodeType !== 1) return false;
    var selector = 'nav, [role="navigation"], [role="dialog"], [role="menu"], [aria-modal="true"]';
    if (element.matches && element.matches(selector)) return true;
    if (element.querySelector && element.querySelector(selector)) return true;
    var text = (element.textContent || '').trim();
    if (text.length > 500) return false;
    return (/主页|首页|Home/.test(text) && /搜索|Search/.test(text) &&
      /收件箱|Inbox|Messages/.test(text) && /已收藏|收藏|Saved/.test(text)) ||
      (/分享到|分享|Share to|Share with/.test(text) &&
      /Facebook|Messenger|WhatsApp|复制链接|Copy link/.test(text));
  }
  var syncScheduled = false;
  function scheduleSync() {
    if (syncScheduled) return;
    syncScheduled = true;
    window.requestAnimationFrame(function () {
      syncScheduled = false;
      sync();
    });
  }
  var observer = new MutationObserver(function (changes) {
    if (!currentShell || !currentShell.isConnected) { scheduleSync(); return; }
    for (var index = 0; index < changes.length; index++) {
      var change = changes[index];
      if (change.target === currentShell || currentShell.contains(change.target) || relevantNode(change.target)) {
        scheduleSync(); return;
      }
      if (change.type === 'attributes') {
        if (change.attributeName === 'aria-expanded') scheduleSync();
        continue;
      }
      for (var added = 0; added < change.addedNodes.length; added++) {
        if (relevantNode(change.addedNodes[added])) { scheduleSync(); return; }
      }
      for (var removed = 0; removed < change.removedNodes.length; removed++) {
        if (relevantNode(change.removedNodes[removed])) { scheduleSync(); return; }
      }
    }
  });
  function startObserver() {
    if (document.documentElement) observer.observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['style', 'class', 'hidden', 'aria-current', 'aria-selected', 'aria-expanded']
    });
  }
  startObserver();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', sync);
  if (!document.documentElement) document.addEventListener('DOMContentLoaded', startObserver);
  window.addEventListener('pageshow', function () { lastVisible = null; sync(); });
  window.addEventListener('popstate', function () { lastVisible = null; sync(); });
  sync();
  window.setInterval(sync, 1000);
})();`;
