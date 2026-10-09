// Manual rollback only. Failed native requests never replay through ArkWeb.
export const PIN_NATIVE_NETWORK_ENABLED: boolean = true;

// Transforms only our injected API scripts, not Pinterest's own fetch calls.
export function useNativeTransport(script: string): string {
  return script.replace(/(^|[^\w.])fetch\(/g, '$1window.PinWebNetwork.fetch(');
}

export const PIN_NATIVE_NETWORK_SCRIPT: string = `
(function () {
  if (window !== window.top || location.origin !== 'https://www.pinterest.com') return;
  if (window.PinWebNetwork) return;
  var originalFetch = window.fetch, epoch = -1, serial = 0, foreground = typeof document === 'undefined' || !document.hidden;
  var nonce = Math.random().toString(36).slice(2), pending = new Map();
  window.addEventListener('pagehide', function () {
    epoch = -1;
    pending.forEach(function (job) { job.abort(); });
  });
  function responseWithUrl(response, url) {
    Object.defineProperty(response, 'url', { value: url });
    var clone = response.clone.bind(response);
    response.clone = function () { return responseWithUrl(clone(), url); };
    return response;
  }
  window.PinWebNetwork = {
    isForeground: function () { return foreground && (typeof document === 'undefined' || !document.hidden); },
    setForeground: function (value) {
      foreground = value === true;
      if (!foreground) pending.forEach(function (job) { if (!job.sent || job.readOnly) job.abort(); });
    },
    bind: function (value, page) {
      if (page !== location.href || !Number.isInteger(value)) return;
      epoch = value;
      // Settle old-epoch reads now; they cannot accept a response after rebinding.
      pending.forEach(function (job) { if (job.sent && job.readOnly && job.epoch !== epoch) job.abort('epoch'); });
      pending.forEach(function (job) { if (!job.sent) job.send(); });
    },
    complete: function (reply) {
      var job = pending.get(reply.id);
      if (!job) return 'no-job';
      if (reply.epoch !== job.epoch || reply.page !== job.page || job.page !== location.href) return 'stale';
      if (reply.error) {
        var failure = new TypeError('原生网络请求未完成');
        if (/^(cancelled|stale|current=false|background)$/.test(reply.error)) failure.name = 'AbortError';
        job.fail(failure); return;
      }
      try {
        var body = [204, 205, 304].indexOf(reply.status) >= 0 ? null : reply.body;
        job.finish(responseWithUrl(new Response(body, { status: reply.status, headers: reply.headers || {} }), reply.url));
      } catch (_) { job.fail(new TypeError('原生响应转换失败')); return 'invalid-response'; }
      return 'delivered';
    },
    fetch: function (input, init) {
      init = init || {};
      if (!foreground || (typeof document !== 'undefined' && document.hidden)) { var paused = new Error('应用已暂停'); paused.name = 'AbortError'; return Promise.reject(paused); }
      if (window.PinWebNativeNetworkEnabled !== true) return window.fetch(input, init);
      return new Promise(function (resolve, reject) {
        var id = nonce + '_' + (++serial), page = location.href, signal = init.signal;
        var readOnly = String(init.method || 'GET').toUpperCase() === 'GET' || /\\/resource\\/[A-Za-z]+Resource\\/get\\//.test(String(input));
        var job = { page: page, epoch: -1, sent: false, readOnly: readOnly }, timer;
        function clean() { clearTimeout(timer); pending.delete(id); if (signal) signal.removeEventListener('abort', abort); }
        job.finish = function (value) { clean(); resolve(value); };
        job.fail = function (error) { clean(); reject(error); };
        function abort(reason) {
          if (job.sent && window.PinWebShareBridge && window.PinWebShareBridge.cancelNetwork)
            window.PinWebShareBridge.cancelNetwork(id);
          var error = new Error('请求已取消'); error.name = 'AbortError';
          if (reason === 'epoch') error.pinWebEpochChanged = true;
          job.fail(error);
        }
        job.abort = abort;
        job.send = function () {
          if (job.sent || !pending.has(id)) return;
          if (page !== location.href) { abort(); return; }
          try {
            var url = new URL(String(input), location.href);
            if (url.origin !== location.origin) throw new Error('invalid-origin');
            var headers = {}, supplied = new Headers(init.headers || {});
            supplied.forEach(function (value, key) {
              if (!/^(cookie|authorization|x-csrftoken)$/i.test(key)) headers[key] = value;
            });
            job.sent = true; job.epoch = epoch;
            if (!window.PinWebShareBridge || !window.PinWebShareBridge.networkRequest) throw new Error('bridge-unavailable');
            window.PinWebShareBridge.networkRequest(JSON.stringify({ id: id, page: page, epoch: epoch,
              url: url.href, method: String(init.method || 'GET').toUpperCase(), headers: headers,
              body: typeof init.body === 'string' ? init.body : '' }));
          } catch (_) { job.fail(new TypeError('原生网络请求不可用')); }
        };
        if (signal && signal.aborted) { abort(); return; }
        pending.set(id, job);
        if (signal) signal.addEventListener('abort', abort, { once: true });
        timer = setTimeout(abort, 20000);
        if (epoch >= 0) job.send();
      });
    }
  };
  window.addEventListener('visibilitychange', function () { window.PinWebNetwork.setForeground(typeof document === 'undefined' || !document.hidden); });
  // Retain the existing auth/contract observers around fetch without changing website requests.
  window.PinWebNetwork.fetchObserved = function (input, init) {
    init = Object.assign({}, init || {}, { pinWebNativeRequest: true });
    return window.fetch(input, init).catch(function (error) {
      var name = error && ['TypeError', 'SyntaxError', 'AbortError', 'Error'].indexOf(error.name) >= 0 ? error.name : 'UnknownError';
      console.warn('PinWebNetworkDiagnostic: fetch observer failed ' + name);
      throw error;
    });
  };
  var nativeFetch = window.PinWebNetwork.fetch;
  window.fetch = function (input, init) {
    if (init && init.pinWebNativeRequest && window.PinWebNativeNetworkEnabled === true)
      return nativeFetch(input, init);
    return originalFetch.call(this, input, init);
  };
  window.PinWebNetwork.fetch = window.PinWebNetwork.fetchObserved;
})();`;
