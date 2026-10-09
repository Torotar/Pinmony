export const SHARE_LINK_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  function isExternalShare(url) {
    return /^(sms:|fb-messenger:\\/\\/|facebook-messenger:\\/\\/|whatsapp:\\/\\/)/i.test(url) ||
      /^https?:\\/\\/(?:[^/]+\\.)?(?:twitter\\.com|x\\.com|facebook\\.com|fb\\.com|messenger\\.com|whatsapp\\.com|wa\\.me)(?:\\/|\\?|$)/i.test(url);
  }
  var selectedPin = '';
  var selectedAt = 0;
  var lastXShareAt = 0;
  function pinNear(node) {
    for (var element = node, depth = 0; element && depth < 6; element = element.parentElement, depth++) {
      if (element.matches && element.matches('a[href*="/pin/"]')) return element.href;
      if (!element.querySelectorAll) continue;
      var links = element.querySelectorAll('a[href*="/pin/"]');
      var found = '';
      var different = false;
      for (var index = 0; index < links.length; index++) {
        if (found && found !== links[index].href) { different = true; break; }
        found = links[index].href;
      }
      if (found && !different) return found;
    }
    return '';
  }
  function share(targetUrl) {
    if (!window.PinWebShareBridge) return false;
    var pin = Date.now() - selectedAt < 30000 ? selectedPin : '';
    window.PinWebShareBridge.share(targetUrl, pin || location.href);
    return true;
  }
  window.PinWebSelectedPin = function () {
    return Date.now() - selectedAt < 30000 ? selectedPin : '';
  };
  function isXShareControl(node) {
    var matched = false;
    for (var element = node, depth = 0; element && depth < 6; element = element.parentElement, depth++) {
      if (!element.getAttribute) continue;
      var label = (element.getAttribute('aria-label') || element.getAttribute('title') || '').trim();
      if (/close|back|dismiss|关闭|返回|取消/i.test(label)) return false;
      var text = (element.innerText || element.textContent || '').trim().replace(/\\s+/g, ' ');
      if (/^(?:X|Twitter|Share (?:to|on) (?:X|Twitter)|分享到\\s*(?:X|Twitter))$/i.test(label) ||
          /^(?:X|Twitter)$/i.test(text)) matched = true;
    }
    return matched;
  }
  function interceptX(event) {
    var node = event.target;
    if (!isXShareControl(node) || !window.PinWebShareBridge) return false;
    var link = node && node.closest ? node.closest('a[href]') : null;
    if (Date.now() - lastXShareAt > 1500 && share(link ? link.href : '')) lastXShareAt = Date.now();
    event.preventDefault();
    event.stopImmediatePropagation();
    return true;
  }
  document.addEventListener('pointerdown', interceptX, true);
  document.addEventListener('click', function (event) {
    var node = event.target;
    var nearbyPin = pinNear(node);
    if (nearbyPin) { selectedPin = nearbyPin; selectedAt = Date.now(); }
    var link = node && node.closest ? node.closest('a[href]') : null;
    if (interceptX(event)) return;
    if (link && isExternalShare(link.href) && share(link.href)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }, true);
  var originalOpen = window.open;
  window.open = function (url) {
    if (typeof url === 'string' && isExternalShare(url) && share(url)) return null;
    return originalOpen.apply(window, arguments);
  };
  function visible(element) {
    if (!element || !element.getBoundingClientRect) return false;
    var rect = element.getBoundingClientRect();
    var style = window.getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < window.innerHeight &&
      style.display !== 'none' && style.visibility !== 'hidden';
  }
  function closeControl(container) {
    var controls = container.querySelectorAll('button, [role="button"], [aria-label]');
    for (var index = controls.length - 1; index >= 0; index--) {
      var control = controls[index];
      if (!visible(control)) continue;
      var label = (control.getAttribute('aria-label') || control.getAttribute('title') || '').trim();
      var content = (control.textContent || '').trim();
      if (/close|dismiss|关闭/i.test(label) || /^[×✕✖]$/.test(content)) {
        control.click();
        return true;
      }
    }
    return false;
  }
  function collapseExpanded(menu) {
    var expanded = document.querySelectorAll('[aria-expanded="true"]');
    for (var index = expanded.length - 1; index >= 0; index--) {
      var trigger = expanded[index];
      if (!visible(trigger)) continue;
      if (menu && menu.id && trigger.getAttribute('aria-controls') !== menu.id) continue;
      trigger.click();
      return true;
    }
    return false;
  }
  function escapeOverlay() {
    var target = document.activeElement || document;
    target.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true, cancelable: true
    }));
  }
  window.PinWebHandleBack = function () {
    var headings = document.querySelectorAll('h1, h2, h3, span, div');
    for (var headingIndex = headings.length - 1; headingIndex >= 0; headingIndex--) {
      var heading = headings[headingIndex];
      if (!visible(heading) || !/^(分享到|分享|Share to|Share with|Share)$/i.test((heading.textContent || '').trim())) continue;
      for (var parent = heading.parentElement, depth = 0; parent && depth < 5; parent = parent.parentElement, depth++) {
        if (!/Facebook|Messenger|WhatsApp|复制链接|Copy link|搜索联系人|Search contacts/.test(parent.textContent || '')) continue;
        if (!closeControl(parent)) escapeOverlay();
        return true;
      }
    }
    var menus = document.querySelectorAll('[role="menu"]');
    for (var menuIndex = menus.length - 1; menuIndex >= 0; menuIndex--) {
      if (!visible(menus[menuIndex])) continue;
      if (!closeControl(menus[menuIndex]) && !collapseExpanded(menus[menuIndex]) &&
          !collapseExpanded(null)) escapeOverlay();
      return true;
    }
    if (collapseExpanded(null)) return true;
    var dialogs = document.querySelectorAll('[role="dialog"], [aria-modal="true"]');
    for (var dialogIndex = dialogs.length - 1; dialogIndex >= 0; dialogIndex--) {
      if (!visible(dialogs[dialogIndex])) continue;
      if (!closeControl(dialogs[dialogIndex])) escapeOverlay();
      return true;
    }
    return false;
  };
  window.PinWebDismissUnknownPanel = function () {
    escapeOverlay();
    document.body.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
  };
})();`;
