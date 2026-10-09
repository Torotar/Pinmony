export const PINTEREST_LOGIN_URL: string = 'https://www.pinterest.com/login/';

// Login and internal-resource requests share ArkWeb's own cookie store.
// The host keeps rendering at its normal viewport size so existing DOM contracts still work.
export const PIN_AUTH_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var epoch = -1, evidence = null, initialNode = null, last = '', responseEvidence = false;
  var evidencePage = location.href.split('#')[0];
  function syncRoute() {
    var page = location.href.split('#')[0];
    if (page === evidencePage) return;
    evidencePage = page; evidence = null; responseEvidence = false; last = '';
    // The old initial-props node belongs to the previous SPA route: do not read it again.
  }
  function read(context) {
    if (!context || typeof context !== 'object') return null;
    var authenticated = context.is_authenticated;
    if (typeof authenticated !== 'boolean') authenticated = context.isAuthenticated;
    if (authenticated === false) return { status: 'unauthenticated', profileUrl: '' };
    var user = context.user;
    var hasUser = user && /^\\d+$/.test(String(user.id || '')) && String(user.id) !== '0';
    if (authenticated !== true && !hasUser) return null;
    var username = user && user.username;
    return { status: 'authenticated', profileUrl: typeof username === 'string' && /^[a-zA-Z0-9_]+$/.test(username) ?
      location.origin + '/' + username + '/' : '' };
  }
  function publish() {
    if (epoch < 0 || !evidence) return;
    var message = { status: evidence.status, profileUrl: evidence.profileUrl, epoch: epoch, pageUrl: location.href };
    var value = JSON.stringify(message);
    if (value === last) return;
    try {
      if (window.PinWebShareBridge && window.PinWebShareBridge.authState) {
        window.PinWebShareBridge.authState(value); last = value;
      }
    } catch (_) {}
  }
  function scanInitial() {
    syncRoute();
    var node = document.getElementById('__PWS_INITIAL_PROPS__');
    if (!node || node === initialNode) return;
    try {
      var initial = JSON.parse(node.textContent || '{}');
      initialNode = node;
      var session = initial.initialReduxState && initial.initialReduxState.session;
      var next = read(initial.client_context) || read(session);
      if (next && !responseEvidence) evidence = next;
    } catch (_) {}
  }
  function response(body, requestedPage, responseUrl) {
    // Late data from a previous SPA route cannot change the current login gate.
    if (requestedPage !== location.href) return;
    syncRoute();
    var next = read(body && body.client_context);
    if (!next && responseUrl && /\\/(?:login|signup)(?:\\/|[?#]|$)/i.test(responseUrl)) {
      next = { status: 'unauthenticated', profileUrl: '' };
    }
    if (next) { responseEvidence = true; evidence = next; publish(); }
  }
  var originalFetch = window.fetch;
  if (typeof originalFetch === 'function') window.fetch = function () {
    var requestedPage = location.href;
    return originalFetch.apply(this, arguments).then(function (result) {
      try {
        // Inspect only same-origin Pinterest responses, never third-party payloads.
        var target = new URL(result.url || location.href, location.href);
        if (target.origin === location.origin) {
          if (/^\\/(?:login|signup)(?:\\/|$)/i.test(target.pathname)) response(null, requestedPage, result.url);
          else if (/^\\/(?:resource\\/|_\\/graphql\\/)/.test(target.pathname)) {
            result.clone().json().then(function (body) { response(body, requestedPage, result.url); }).catch(function () {});
          }
        }
      } catch (_) {}
      return result;
    });
  };
  if (typeof XMLHttpRequest === 'function') {
    var originalSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      var xhr = this, requestedPage = location.href;
      xhr.addEventListener('load', function () {
        try {
          var target = new URL(xhr.responseURL || location.href, location.href);
          if (target.origin !== location.origin) return;
          if (/^\\/(?:login|signup)(?:\\/|$)/i.test(target.pathname)) {
            response(null, requestedPage, xhr.responseURL); return;
          }
          if (!/^\\/(?:resource\\/|_\\/graphql\\/)/.test(target.pathname)) return;
          var body = xhr.responseType === 'json' ? xhr.response : JSON.parse(xhr.responseText || '{}');
          response(body, requestedPage, xhr.responseURL);
        } catch (_) {}
      }, { once: true });
      return originalSend.apply(this, arguments);
    };
  }
  window.PinWebAuthSync = function (requestedEpoch) {
    if (typeof requestedEpoch !== 'number' || requestedEpoch < 0) return false;
    epoch = requestedEpoch; last = '';
    scanInitial();
    if (!evidence && /^\\/(?:login|signup|logout)(?:\\/|$)/i.test(location.pathname)) {
      evidence = { status: 'unauthenticated', profileUrl: '' };
    }
    publish(); return true;
  };
  // Initialization JSON may arrive before DOMContentLoaded while HTML is streaming.
  // Observe only the existing evidence node; a URL or Cookie alone is not login proof.
  if (typeof MutationObserver === 'function') {
    var initialObserver = new MutationObserver(function () {
      scanInitial(); publish();
      if (evidence) initialObserver.disconnect();
    });
    initialObserver.observe(document, { childList: true, subtree: true, characterData: true });
  }
  document.addEventListener('DOMContentLoaded', function () { scanInitial(); publish(); });
  scanInitial();
})();`;
