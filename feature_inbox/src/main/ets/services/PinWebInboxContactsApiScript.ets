// Recommended contacts only, not the conversation history or a message sender.
export const PIN_INBOX_CONTACTS_API_ENABLED: boolean = true;
export const PIN_INBOX_CONTACTS_API_SCRIPT: string = `
(function () {
  if (window !== window.top || !/(^|\\.)pinterest\\.com$/.test(location.hostname)) return;
  var key = '', generation = 0, abort = null, state = null;
  function reset() {
    generation++; if (abort) abort.abort();
    key = ''; abort = null; state = null;
  }
  function clean(v, max) { return typeof v === 'string' ? v.trim().slice(0, max) : ''; }
  function mapContacts(rows, g) {
    var seen = {};
    return rows.map(function (row) {
      if (!row || !/^\\d+$/.test(row.id || '') || typeof row.id !== 'string' ||
          row.type !== 'user_share_suggestion' || !clean(row.username, 100)) throw new Error('Contact format');
      return { id: 'inbox-contact-api-' + g + '-' + row.id, userId: row.id,
        username: clean(row.username, 100), title: clean(row.full_name, 160) || clean(row.username, 100),
        subtitle: '@' + clean(row.username, 100),
        imageUrl: [row.image_medium_url, row.image_large_url, row.image_small_url].filter(function (v) {
          return typeof v === 'string' && /^https:\\/\\//i.test(v);
        })[0] || '', enabled: false };
    }).filter(function (row) { if (seen[row.userId]) return false; seen[row.userId] = true; return true; });
  }
  window.PinWebInboxContactsApi = {
    find: function (id) { return state && state.kind === 'ready' ? state.items.find(function (row) { return row.userId === id; }) : null; },
    reset: reset,
    pause: function () {
      generation++; if (abort) abort.abort(); abort = null;
      if (!state || state.kind !== 'ready') state = null;
    },
    read: function (page, changed, current) {
      if (!window.PinWebInboxContactsApiEnabled) { reset(); return null; }
      if (key !== page) reset();
      if (state) return state;
      key = page; state = { kind: 'loading', items: [] };
      var g = generation, pending = state, controller = abort = new AbortController();
      var timer = setTimeout(function () { controller.abort(); }, 12000);
      var source = new URL(page).pathname;
      var query = new URLSearchParams({ source_url: source,
        data: JSON.stringify({ options: { field_set_key: 'default', hide_group_conversations: true }, context: {} }),
        _: String(Date.now()) });
      fetch('/resource/ShareSuggestionsResource/get/?' + query, {
        credentials: 'same-origin', signal: controller.signal,
        headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' }
      }).then(function (response) {
        if (!response.ok) throw new Error('联系人请求失败（HTTP ' + response.status + '），请重试');
        return response.json().catch(function () { throw new Error('联系人接口未返回 JSON，请检查当前网页登录状态'); });
      }).then(function (body) {
        if (g !== generation || key !== page || !current()) return;
        var r = body && body.resource_response;
        if (!r || r.status !== 'success' || r.code !== undefined && r.code !== 0 || r.error) throw new Error('联系人接口业务状态未成功，请重试');
        if (!Array.isArray(r.data) || r.endpoint_name && r.endpoint_name !== 'v3_user_contacts_suggestion') throw new Error('联系人返回格式无效');
        pending.items = mapContacts(r.data, g); pending.kind = 'ready'; changed();
      }).catch(function (e) {
        if (g !== generation || key !== page || !current()) return;
        pending.items = []; pending.kind = 'failed';
        pending.error = e.name === 'AbortError' ? '联系人请求超时，请重试' : e.name === 'TypeError' ? '联系人网络请求失败，请重试' :
          /^联系人/.test(e.message || '') ? e.message : '联系人数据结构不符合预期，请重试'; changed();
      }).finally(function () { clearTimeout(timer); if (abort === controller) abort = null; });
      return pending;
    }
  };
})();`;
