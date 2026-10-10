export const PIN_MORE_MENU_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var panel = null;
  var hiddenRoots = [];
  var trigger = null;
  var pin = '';
  var session = 0;
  var nextId = 1;
  var ids = new WeakMap();
  var controls = {};
  var opening = false;
  var closing = false;
  var scheduled = false;
  var lastState = '';
  var missingTimer = 0;
  var knownPanels = [];
  var stagedState = null;
  var stagedText = '';
  var stagedAt = 0;
  var changedAt = 0;
  var publishTimer = 0;
  var openingFrame = 0;
  function currentPin() {
    var match = location.pathname.match(/^\\/pin\\/(\\d+)(?:\\/|$)/i);
    if (match) return location.origin + '/pin/' + match[1] + '/';
    if (location.pathname === '/' || /^\\/(?:ideas|today)(?:\\/.*)?$/i.test(location.pathname)) {
      return window.PinmonyHomeMenuPin || '';
    }
    return '';
  }
  function visible(element) {
    if (!element || !element.isConnected || !element.getBoundingClientRect) return false;
    var rect = element.getBoundingClientRect();
    var style = getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < innerHeight &&
      style.display !== 'none' && style.visibility !== 'hidden';
  }
  function rendered(element) {
    if (!element || !element.isConnected || !element.getBoundingClientRect) return false;
    var rect = element.getBoundingClientRect();
    var style = getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
  }
  function label(element) {
    return ((element.innerText || element.textContent || '').trim() ||
      (element.getAttribute && (element.getAttribute('aria-label') || element.getAttribute('title'))) ||
      '').trim().replace(/\\s+/g, ' ').slice(0, 300);
  }
  function isSheetChrome(element) {
    var name = (element.getAttribute &&
      (element.getAttribute('aria-label') || element.getAttribute('title')) || label(element)).trim();
    return /^(?:grabber|drag handle|sheet handle|捕获器|拖动条|关闭底部工作表|关闭面板|close bottom sheet|close sheet|close panel)$/i.test(name);
  }
  function isMoreTrigger(element) {
    if (!element || !element.matches || !element.matches('button, [role="button"]')) return false;
    if (element.closest('[role="menu"], [data-pinweb-native-share-hidden], [data-pinweb-native-more-hidden]')) return false;
    var name = (element.getAttribute('aria-label') || element.getAttribute('title') || label(element)).trim();
    var testId = (element.getAttribute('data-test-id') || '').trim();
    return /^(?:more|more options(?: for this pin)?|more actions(?: for this pin)?|pin options|options|更多|更多选项|更多操作|此 Pin 的更多选项|选项|\\.\\.\\.|…|⋯)$/i.test(name) ||
      /^(?:pin-)?more[-_]?options(?:[-_]?button)?$/i.test(testId);
  }
  function leaves(root) {
    var all = root.querySelectorAll('[role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"], [role="option"], button, a, [role="button"], li[tabindex]');
    var result = [];
    for (var index = 0; index < all.length; index++) {
      var node = all[index];
      if (!rendered(node) || node === trigger || node.contains(trigger) ||
          result.some(function (parent) { return parent.contains(node); })) continue;
      if (node.querySelector('[role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"], [role="option"]') &&
          !/^(?:menuitem|menuitemcheckbox|menuitemradio|option)$/.test(node.getAttribute('role') || '')) continue;
      var name = label(node);
      if (!name || isSheetChrome(node) ||
          /^(?:close|dismiss|back|cancel|关闭|返回|取消|×|✕)$/i.test(name)) continue;
      result.push(node);
    }
    var textNodes = root.querySelectorAll('span, p, div, li');
    for (var textIndex = 0; textIndex < textNodes.length; textIndex++) {
      var textNode = textNodes[textIndex];
      if (!rendered(textNode) || textNode.contains(trigger) ||
          textNode.closest('h1, h2, h3, [role="heading"]') ||
          result.some(function (control) { return control.contains(textNode) || textNode.contains(control); })) continue;
      var direct = '';
      for (var childIndex = 0; childIndex < textNode.childNodes.length; childIndex++) {
        if (textNode.childNodes[childIndex].nodeType === 3) direct += textNode.childNodes[childIndex].nodeValue || '';
      }
      var text = direct.trim().replace(/\\s+/g, ' ');
      var textRect = textNode.getBoundingClientRect();
      if (!text || text.length > 120 || textRect.height > 110 || isSheetChrome(textNode) ||
          /^(?:close|dismiss|back|cancel|关闭|返回|取消|×|✕)$/i.test(text)) continue;
      result.push(textNode);
    }
    result.sort(function (left, right) {
      var a = left.getBoundingClientRect();
      var b = right.getBoundingClientRect();
      return a.top - b.top || a.left - b.left;
    });
    return result;
  }
  function sheetFor(candidate) {
    var selected = null;
    var mostRows = 1;
    var smallest = Infinity;
    for (var ancestor = candidate; ancestor && ancestor !== document.body;
         ancestor = ancestor.parentElement) {
      if (ancestor.contains(trigger) || !visible(ancestor)) break;
      var rect = ancestor.getBoundingClientRect();
      if (rect.width < innerWidth * .78 || rect.height < 140 ||
          rect.height > innerHeight * .85 || rect.bottom < innerHeight - 90) continue;
      var rowCount = leaves(ancestor).length;
      if (rowCount < 2) continue;
      var area = rect.width * rect.height;
      if (rowCount > mostRows || rowCount === mostRows && area < smallest) {
        selected = ancestor;
        mostRows = rowCount;
        smallest = area;
      }
    }
    return selected || candidate;
  }
  function openingSheet() {
    if (!opening || !trigger) return null;
    var controls = document.querySelectorAll('button, [role="button"], [aria-label]');
    var selected = null;
    var smallest = Infinity;
    for (var index = 0; index < controls.length; index++) {
      var control = controls[index];
      if (!rendered(control) || !isSheetChrome(control) && !/^[×✕✖]$/.test(label(control))) continue;
      for (var ancestor = control.parentElement; ancestor && ancestor !== document.body;
           ancestor = ancestor.parentElement) {
        if (ancestor.contains(trigger)) break;
        var rect = ancestor.getBoundingClientRect();
        if (rect.width < innerWidth * .78 || rect.height < 140 ||
            rect.height > innerHeight * .85 || rect.bottom < innerHeight - 90) continue;
        var area = rect.width * rect.height;
        if (area < smallest) { selected = ancestor; smallest = area; }
      }
    }
    return selected;
  }
  function usable(candidate) {
    if (!candidate || candidate === document.body || candidate === document.documentElement ||
        candidate.contains(trigger) || !visible(candidate) || knownPanels.indexOf(candidate) >= 0) return false;
    var rect = candidate.getBoundingClientRect();
    if (rect.width > innerWidth * .98 && rect.height > innerHeight * .95) return false;
    return leaves(candidate).length > 0;
  }
  function findPanel() {
    if (!trigger || !trigger.isConnected) return null;
    var controlled = trigger.getAttribute('aria-controls');
    if (controlled) {
      var direct = document.getElementById(controlled);
      if (usable(direct)) return sheetFor(direct);
    }
    var candidates = document.querySelectorAll('[role="menu"], [role="listbox"], [role="dialog"], [data-test-id*="more-options"], [data-test-id*="more-menu"]');
    var best = null;
    var bestScore = -100000;
    var anchor = trigger.getBoundingClientRect();
    for (var index = 0; index < candidates.length; index++) {
      var candidate = candidates[index];
      if (!usable(candidate) || candidate.closest('[data-pinweb-native-share-hidden]')) continue;
      var complete = sheetFor(candidate);
      if (!usable(complete)) continue;
      var rect = candidate.getBoundingClientRect();
      var score = -Math.abs(rect.left - anchor.left) - Math.abs(rect.top - anchor.bottom);
      if (candidate.getAttribute('role') === 'menu') score += 600;
      if (candidate.getAttribute('aria-labelledby') === trigger.id && trigger.id) score += 1000;
      if (candidate.parentElement === trigger.parentElement) score += 300;
      if (score > bestScore) { best = complete; bestScore = score; }
    }
    return best;
  }
  function ensureStyle() {
    if (document.getElementById('pinweb-native-more-style')) return;
    var style = document.createElement('style');
    style.id = 'pinweb-native-more-style';
    style.textContent = '[data-pinweb-native-more-hidden="true"] {' +
      'opacity: 0 !important; pointer-events: none !important; }';
    (document.head || document.documentElement).appendChild(style);
  }
  function rootFor(candidate) {
    var root = candidate;
    for (var ancestor = candidate.parentElement; ancestor && ancestor !== document.body;
         ancestor = ancestor.parentElement) {
      if (ancestor.contains(trigger) || ancestor.querySelector('main, nav, [role="main"], [role="navigation"]')) break;
      var rect = ancestor.getBoundingClientRect();
      var child = candidate.getBoundingClientRect();
      if (rect.width < child.width || rect.height < child.height) break;
      var style = getComputedStyle(ancestor);
      if (style.position === 'fixed' || style.position === 'absolute' ||
          ancestor.getAttribute('role') === 'dialog') root = ancestor;
    }
    return root;
  }
  function hide(candidate) {
    ensureStyle();
    var root = rootFor(candidate);
    if (hiddenRoots.indexOf(root) < 0) hiddenRoots.push(root);
    root.setAttribute('data-pinweb-native-more-hidden', 'true');
  }
  function register(element) {
    var id = ids.get(element);
    if (!id) { id = 'm' + session + '-' + nextId++; ids.set(element, id); }
    controls[id] = element;
    return id;
  }
  function enabled(element) {
    for (var node = element; node && panel && panel.contains(node); node = node.parentElement) {
      if (node.disabled || node.getAttribute('aria-disabled') === 'true') return false;
    }
    return true;
  }
  function iconOf(element) {
    var image = element.querySelector('img');
    var source = image && (image.currentSrc || image.src) || '';
    if (/^https?:\\/\\//i.test(source) || /^data:image\\//i.test(source)) return source.slice(0, 2000);
    var svg = element.querySelector('svg');
    var markup = svg && svg.outerHTML || '';
    return markup && markup.length < 8000 ? 'data:image/svg+xml,' + encodeURIComponent(markup) : '';
  }
  function snapshot() {
    var rows = leaves(panel);
    var separators = panel.querySelectorAll('hr, [role="separator"]');
    var options = [];
    controls = {};
    for (var index = 0; index < rows.length && index < 40; index++) {
      var node = rows[index];
      var raw = (node.innerText || node.textContent || '').trim();
      var lines = raw.split(/\\n+/).map(function (part) { return part.trim(); }).filter(Boolean);
      var name = lines[0] || label(node);
      var group = 0;
      for (var separatorIndex = 0; separatorIndex < separators.length; separatorIndex++) {
        if (rendered(separators[separatorIndex]) &&
            separators[separatorIndex].getBoundingClientRect().top < node.getBoundingClientRect().top) group++;
      }
      options.push({ id: register(node), label: name, subtitle: lines.slice(1).join(' '),
        icon: iconOf(node), group: group,
        enabled: enabled(node) });
    }
    var heading = panel.querySelector('h1, h2, h3, [role="heading"]');
    var result = { kind: 'state', session: session, pin: pin,
      title: heading && visible(heading) ? label(heading) : '', options: options };
    return window.PinmonyPostApi ? window.PinmonyPostApi.moreSnapshot(result) : result;
  }
  function notify(value) {
    if (!window.PinmonyShareBridge || !window.PinmonyShareBridge.moreState) return;
    var text = JSON.stringify(value);
    if (lastState === text) return;
    lastState = text;
    window.PinmonyShareBridge.moreState(text);
  }
  function stage(value) {
    var now = Date.now();
    var text = JSON.stringify(value);
    if (text === lastState && !stagedState) return;
    if (!stagedAt) stagedAt = now;
    if (text !== stagedText) {
      stagedState = value;
      stagedText = text;
      changedAt = now;
    }
    if (publishTimer) return;
    publishTimer = setTimeout(function publish() {
      publishTimer = 0;
      if (!panel || closing || currentPin() !== pin || !stagedState) return;
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
    if (publishTimer) { clearTimeout(publishTimer); publishTimer = 0; }
    if (openingFrame) { cancelAnimationFrame(openingFrame); openingFrame = 0; }
    stagedState = null;
    stagedText = '';
    stagedAt = 0;
    changedAt = 0;
    hiddenRoots.forEach(function (root) { root.removeAttribute('data-pinweb-native-more-hidden'); });
    hiddenRoots = [];
    panel = null;
    trigger = null;
    controls = {};
    ids = new WeakMap();
    nextId = 1;
    opening = false;
    closing = false;
    knownPanels = [];
    notify({ kind: 'closed', session: session, pin: pin });
    pin = '';
    window.PinmonyHomeMenuPin = '';
  }
  function closeWebMenu() {
    if (trigger && trigger.isConnected && trigger.getAttribute('aria-expanded') === 'true') {
      trigger.click();
    } else {
      (panel || trigger || document.activeElement || document).dispatchEvent(new KeyboardEvent('keydown', {
        key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true, cancelable: true
      }));
    }
  }
  function sync() {
    scheduled = false;
    if (!pin) return;
    if (currentPin() !== pin || !trigger || !trigger.isConnected) { clear(); return; }
    var early = openingSheet();
    if (early) hide(early);
    var found = findPanel();
    if (!found && panel && panel.isConnected && visible(panel)) found = panel;
    if (found) {
      if (missingTimer) { clearTimeout(missingTimer); missingTimer = 0; }
      panel = found;
      hide(panel);
      opening = false;
      if (openingFrame) { cancelAnimationFrame(openingFrame); openingFrame = 0; }
      if (!closing) stage(snapshot());
    } else if (panel && !missingTimer) {
      missingTimer = setTimeout(function () {
        missingTimer = 0;
        if (!findPanel() && (!panel || !panel.isConnected || !visible(panel))) clear();
        else schedule();
      }, 160);
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
      if (!opening || closing) return;
      sync();
      if (opening) watchOpening();
    });
  }
  window.PinmonyNativeMoreAction = function (requestedSession, requestedPin, id) {
    if (window.PinmonyPostApi) return window.PinmonyPostApi.moreAction(requestedSession, requestedPin, id, schedule);
    var target = controls[id];
    if (!panel || closing || requestedSession !== session || requestedPin !== pin ||
        currentPin() !== pin || !target || !target.isConnected || !panel.contains(target) ||
        !enabled(target)) return false;
    target.click();
    schedule();
    return true;
  };
  window.PinmonyNativeMoreRefresh = function (requestedSession, requestedPin) {
    if (requestedSession !== session || requestedPin !== pin || currentPin() !== pin || closing) return false;
    lastState = '';
    if (panel) { schedule(); return true; }
    if (!trigger || !trigger.isConnected) return false;
    opening = true;
    knownPanels = [];
    trigger.click();
    watchOpening();
    var retrySession = session;
    setTimeout(function () {
      if (retrySession === session && opening && !panel && !closing) {
        closeWebMenu();
        notify({ kind: 'failed', session: session, pin: pin });
        setTimeout(function () { if (retrySession === session && !panel) clear(); }, 300);
      }
    }, 1200);
    return true;
  };
  window.PinmonyNativeMoreClose = function (requestedSession, requestedPin) {
    if (requestedSession !== session || requestedPin !== pin) return false;
    if (window.PinmonyPostApi) window.PinmonyPostApi.moreClose();
    closing = true;
    if (panel || opening) closeWebMenu();
    schedule();
    setTimeout(function () {
      if (!closing) return;
      if (panel && panel.isConnected && visible(panel)) document.body.click();
      setTimeout(function () {
        if (!closing) return;
        if (panel && panel.isConnected && visible(panel)) {
          notify({ kind: 'closeFailed', session: session, pin: pin });
        }
        clear();
      }, 500);
    }, 300);
    return true;
  };
  window.PinmonyNativeMoreOpenFromHome = function (target, requestedPin) {
    if (!target || !target.isConnected || !rendered(target) || panel || opening || closing ||
        !requestedPin || currentPin() !== requestedPin) return false;
    if (!visible(target) && target.scrollIntoView) {
      target.scrollIntoView({ block: 'center' });
    }
    if (!target.isConnected || !visible(target)) return false;
    trigger = target;
    pin = requestedPin;
    session++;
    ids = new WeakMap();
    controls = {};
    nextId = 1;
    lastState = '';
    opening = true;
    knownPanels = Array.prototype.slice.call(document.querySelectorAll('[role="menu"], [role="listbox"], [role="dialog"]'))
      .filter(visible);
    notify({ kind: 'opening', session: session, pin: pin });
    var openedSession = session;
    setTimeout(function () {
      if (openedSession === session && opening && !panel && !closing) {
        closeWebMenu();
        notify({ kind: 'failed', session: session, pin: pin });
        setTimeout(function () { if (openedSession === session && !panel) clear(); }, 300);
      }
    }, 1200);
    try {
      target.click();
    } catch (_) {
      opening = false;
      notify({ kind: 'failed', session: session, pin: pin });
      setTimeout(function () { if (openedSession === session && !panel) clear(); }, 300);
      return false;
    }
    schedule();
    watchOpening();
    return true;
  };
  document.addEventListener('click', function (event) {
    if (!currentPin() || panel || opening || closing) return;
    for (var target = event.target, depth = 0; target && depth < 5;
         target = target.parentElement, depth++) {
      if (!isMoreTrigger(target) || !visible(target)) continue;
      trigger = target;
      pin = currentPin();
      session++;
      ids = new WeakMap();
      controls = {};
      nextId = 1;
      lastState = '';
      opening = true;
      knownPanels = Array.prototype.slice.call(document.querySelectorAll('[role="menu"], [role="listbox"], [role="dialog"]'))
        .filter(visible);
      notify({ kind: 'opening', session: session, pin: pin });
      var openedSession = session;
      setTimeout(function () {
        if (openedSession === session && opening && !panel && !closing) {
          closeWebMenu();
          notify({ kind: 'failed', session: session, pin: pin });
          setTimeout(function () { if (openedSession === session && !panel) clear(); }, 300);
        }
      }, 1200);
      schedule();
      watchOpening();
      break;
    }
  }, true);
  function start() {
    if (!document.documentElement) return;
    new MutationObserver(schedule).observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['style', 'class', 'aria-hidden', 'aria-expanded', 'aria-disabled']
    });
  }
  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);
  window.addEventListener('popstate', schedule);
  window.setInterval(schedule, 500);
})();`;
