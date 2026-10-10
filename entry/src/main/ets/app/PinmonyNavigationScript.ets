export const PIN_NAVIGATION_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || window.PinmonyRouteBridgeInstalled) return;
  window.PinmonyRouteBridgeInstalled = true;
  var samePageDepth = 0;
  function notify(mode) {
    if (window.PinmonyShareBridge && window.PinmonyShareBridge.pageNavigation) {
      window.PinmonyShareBridge.pageNavigation(location.href, mode);
    }
  }
  ['pushState', 'replaceState'].forEach(function (name) {
    var original = history[name];
    history[name] = function () {
      var previous = location.href;
      var result = original.apply(this, arguments);
      if (name === 'pushState') samePageDepth = previous === location.href ? samePageDepth + 1 : 0;
      notify(name === 'replaceState' ? 'replace' : 'push');
      return result;
    };
  });
  function hasOverlay() {
    var panels = document.querySelectorAll('[role="dialog"], [role="menu"], [aria-modal="true"]');
    for (var index = 0; index < panels.length; index++) {
      if (panels[index].getClientRects().length) return true;
    }
    return false;
  }
  function nativeBack() {
    if (samePageDepth || hasOverlay() || !window.PinmonyShareBridge || !window.PinmonyShareBridge.pageBack) return false;
    window.PinmonyShareBridge.pageBack();
    return true;
  }
  var originalBack = history.back;
  history.back = function () {
    if (!nativeBack()) return originalBack.apply(this, arguments);
  };
  var originalGo = history.go;
  history.go = function (delta) {
    if (Number(delta) < 0 && nativeBack()) return;
    return originalGo.apply(this, arguments);
  };
  window.addEventListener('popstate', function () {
    samePageDepth = Math.max(0, samePageDepth - 1);
    notify('pop');
  });
  window.addEventListener('pageshow', function (event) { notify(event.persisted ? 'restore' : 'observe'); });
  // Bind the current auth epoch at DOM readiness instead of waiting for all page assets.
  document.addEventListener('DOMContentLoaded', function () { notify('ready'); });
  notify('observe');
})();`;
