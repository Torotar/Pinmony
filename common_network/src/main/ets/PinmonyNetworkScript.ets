// Manual rollback only. Failed native requests never replay through ArkWeb.
export const PIN_NATIVE_NETWORK_ENABLED: boolean = true;
export const PIN_READ_MERGING_ENABLED: boolean = true;

// Transforms only our injected API scripts, not Pinterest's own fetch calls.
export function useNativeTransport(script: string): string {
  return script.replace(/(^|[^\w.])fetch\(/g, '$1window.PinmonyNetwork.fetch(');
}

export const PIN_NATIVE_NETWORK_SCRIPT: string = `
(function () {
  if (window !== window.top || !/^https:[/][/](?:www|uk)\\.pinterest\\.com$/.test(location.origin)) return;
  if (window.PinmonyNetwork) return;
  var originalFetch = window.fetch, epoch = -1, serial = 0, foreground = typeof document === 'undefined' || !document.hidden;
  var nativeManaged = false, boundPage = "";
  var nonce = Math.random().toString(36).slice(2), pending = new Map();
  window.addEventListener('pagehide', function () {
    epoch = -1;
    pending.forEach(function (job) { job.abort("pagehide"); });
  });
  function responseWithUrl(response, url) {
    Object.defineProperty(response, 'url', { value: url });
    var clone = response.clone.bind(response);
    response.clone = function () { return responseWithUrl(clone(), url); };
    return response;
  }
  window.PinmonyNetwork = {
    isReady: function () { return nativeManaged && foreground && epoch >= 0 && boundPage === location.href; },
    isForeground: function () { return (!nativeManaged && epoch < 0) || foreground && (nativeManaged || typeof document === 'undefined' || !document.hidden); },
    setForeground: function (value) {
      nativeManaged = true; foreground = value === true;
      if (!foreground) pending.forEach(function (job) { if (!job.sent || job.readOnly) job.abort("background"); });
    },
    bind: function (value, page) {
      if (page !== location.href || !Number.isInteger(value)) return;
      epoch = value; boundPage = page;
      // Settle old-epoch reads now; they cannot accept a response after rebinding.
      pending.forEach(function (job) { if (job.sent && job.readOnly && job.epoch !== epoch) job.abort('epoch'); });
      pending.forEach(function (job) { if (!job.sent) job.send(); });
    },
    complete: function (reply) {
      var job = pending.get(reply.id);
      if (!job) return 'no-job';
      if (reply.epoch !== job.epoch || reply.page !== job.page || job.page !== location.href) return 'stale';
      if (reply.error) {
        var failure = new TypeError(reply.error === 'rate-limited' ? '请求过于频繁，请稍后重试' : '原生网络请求未完成');
        if (reply.error === 'rate-limited') failure.pinmonyRateLimited = true;
        if (/^(cancelled|stale|current=false|background)$/.test(reply.error)) { failure.name = 'AbortError'; failure.pinmonyCancelled = true; }
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
      if (!window.PinmonyNetwork.isForeground()) { var paused = new Error('应用已暂停'); paused.name = 'AbortError'; return Promise.reject(paused); }
      if (window.PinmonyNativeNetworkEnabled !== true) return window.fetch(input, init);
      return new Promise(function (resolve, reject) {
        var id = nonce + '_' + (++serial), page = location.href, signal = init.signal;
        var readOnly = String(init.method || 'GET').toUpperCase() === 'GET' || /\\/resource\\/[A-Za-z]+Resource\\/get\\//.test(String(input));
        var job = { page: page, epoch: -1, sent: false, settled: false, readOnly: readOnly }, timer;
        function clean() { clearTimeout(timer); pending.delete(id); if (signal) signal.removeEventListener('abort', abort); }
        job.finish = function (value) { if (job.settled) return; job.settled = true; clean(); resolve(value); };
        job.fail = function (error) { if (job.settled) return; job.settled = true; clean(); reject(error); };
        function abort(reason) {
          if (job.settled) return;
          if (job.sent && epoch >= 0 && page === location.href) {
            try { var bridge = window.PinmonyShareBridge; if (bridge && bridge.cancelNetwork) bridge.cancelNetwork(id); } catch (_) {}
          }
          var error = new Error('请求已取消'); error.name = 'AbortError';
          if (reason === 'epoch') error.pinWebEpochChanged = true;
          error.pinmonyCancelled = ['epoch', 'background', 'pagehide', 'stale'].indexOf(reason) >= 0;
          job.fail(error);
        }
        job.abort = abort;
        job.send = function () {
          if (job.sent || !pending.has(id)) return;
          if (page !== location.href) { abort("stale"); return; }
          try {
            var url = new URL(String(input), location.href);
            if (url.origin !== location.origin) throw new Error('invalid-origin');
            var headers = {}, supplied = new Headers(init.headers || {});
            supplied.forEach(function (value, key) {
              if (!/^(cookie|authorization|x-csrftoken)$/i.test(key)) headers[key] = value;
            });
            job.sent = true; job.epoch = epoch;
            if (!window.PinmonyShareBridge || !window.PinmonyShareBridge.networkRequest) throw new Error('bridge-unavailable');
            window.PinmonyShareBridge.networkRequest(JSON.stringify({ id: id, page: page, epoch: epoch,
              url: url.href, method: String(init.method || 'GET').toUpperCase(), headers: headers,
              body: typeof init.body === 'string' ? init.body : '' }));
          } catch (_) { job.fail(new TypeError('原生网络请求不可用')); }
        };
        if (signal && signal.aborted) { abort(); return; }
        pending.set(id, job);
        if (signal) signal.addEventListener('abort', abort, { once: true });
        timer = setTimeout(function () { abort('timeout'); }, 20000);
        if (epoch >= 0) job.send();
      });
    }
  };
  window.addEventListener('visibilitychange', function () { if (!nativeManaged) { foreground = typeof document === 'undefined' || !document.hidden;
    if (!foreground) pending.forEach(function (job) { if (!job.sent || job.readOnly) job.abort(); }); } });
  // Retain the existing auth/contract observers around fetch without changing website requests.
  var readGroups = new Map();
  function observed(input, init) {
    init = Object.assign({}, init || {}, { pinWebNativeRequest: true });
    return window.fetch(input, init).catch(function (error) {
      var name = error && ['TypeError', 'SyntaxError', 'AbortError', 'Error'].indexOf(error.name) >= 0 ? error.name : 'UnknownError';
      console.warn('PinmonyNetworkDiagnostic: fetch observer failed ' + name);
      throw error;
    });
  }
  // Share only in-flight resource reads within one complete page and epoch.
  // Each subscriber owns its abort; the native request is cancelled only when all leave.
  window.PinmonyNetwork.fetchObserved = function (input, init) {
    init = init || {};
    var method = String(init.method || 'GET').toUpperCase(), target;
    try { target = new URL(String(input), location.href); } catch (_) { return observed(input, init); }
    if (window.PinmonyReadMergingEnabled === false || window.PinmonyNativeNetworkEnabled !== true || typeof AbortController !== 'function' || epoch < 0 ||
        !window.PinmonyNetwork.isForeground() || target.origin !== location.origin ||
        !/^\\/resource\\/[A-Za-z]+Resource\\/get\\/$/.test(target.pathname) ||
        ['GET', 'POST'].indexOf(method) < 0 || (init.body !== undefined && typeof init.body !== 'string')) return observed(input, init);
    var signal = init.signal;
    if (signal && signal.aborted) { var aborted = new Error('请求已取消'); aborted.name = 'AbortError'; return Promise.reject(aborted); }
    var headers = [], supplied = new Headers(init.headers || {});
    supplied.forEach(function (value, key) { if (!/^(cookie|authorization|x-csrftoken)$/i.test(key)) headers.push([key, value]); });
    headers.sort(function (a, b) { return a[0].localeCompare(b[0]); });
    var key = JSON.stringify([epoch, location.href, target.href, method, init.body || '', headers]);
    var group = readGroups.get(key);
    if (!group) {
      if (readGroups.size >= 12) return observed(input, init);
      group = { controller: new AbortController(), subscribers: new Set() };
      readGroups.set(key, group);
      var sharedInit = Object.assign({}, init, { signal: group.controller.signal });
      group.promise = observed(input, sharedInit);
      group.promise.then(function () { if (readGroups.get(key) === group) readGroups.delete(key); },
        function () { if (readGroups.get(key) === group) readGroups.delete(key); });
    } else console.info('RequestPolicy: read-merged');
    return new Promise(function (resolve, reject) {
      var subscriber = {}, settled = false;
      group.subscribers.add(subscriber);
      function clean() { group.subscribers.delete(subscriber); if (signal) signal.removeEventListener('abort', abort); }
      function abort() {
        if (settled) return;
        settled = true; clean();
        var failure = new Error('请求已取消'); failure.name = 'AbortError'; reject(failure);
        if (!group.subscribers.size) {
          if (readGroups.get(key) === group) readGroups.delete(key);
          group.controller.abort();
        }
      }
      if (signal) signal.addEventListener('abort', abort, { once: true });
      group.promise.then(function (response) {
        if (settled) return;
        settled = true; clean();
        try { resolve(response.clone()); } catch (_) { reject(new TypeError('原生响应转换失败')); }
      }, function (error) { if (!settled) { settled = true; clean(); reject(error); } });
    });
  };
  var nativeFetch = window.PinmonyNetwork.fetch;
  window.fetch = function (input, init) {
    if (init && init.pinWebNativeRequest && window.PinmonyNativeNetworkEnabled === true)
      return nativeFetch(input, init);
    return originalFetch.call(this, input, init);
  };
  window.PinmonyNetwork.fetch = window.PinmonyNetwork.fetchObserved;
})();`;
