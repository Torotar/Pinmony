export const PIN_ACCOUNT_SETTINGS_SCRIPT: string = `
(function () {
  if (window !== window.top || location.origin !== 'https://www.pinterest.com' || window.PinWebAccountSettings) return;
  var state = null, generation = 0, abort = null, identity = '', active = '', closedActivity = new Set(), attemptedActivity = new Set();
  function valid(page) { return page === active && location.href === active; }
  function text(v, n) { return typeof v === 'string' ? v.slice(0, n) : ''; }
  function map(d) {
    if (!d || !/^\\d+$/.test(String(d.id || '')) || typeof d.username !== 'string') throw Error('shape');
    var username = decodeURIComponent(new URL(active).pathname.split('/')[1]);
    if (d.username.toLowerCase() !== username.toLowerCase()) throw Error('identity');
    identity = String(d.id);
    state.email = text(d.email, 320); state.confirmedEmail = d.has_confirmed_email === true;
    state.birthdate = text(d.birthdate, 10); state.gender = text(d.gender, 30);
    state.customGender = text(d.custom_gender, 500); state.country = text(d.country, 2);
    state.privateProfile = d.opt_in_private_account === true;
    state.searchPrivacy = typeof d.search_privacy_enabled === 'boolean' ? d.search_privacy_enabled : d.exclude_from_search === true;
    state.canChangePrivacy = d.allow_switch_between_private_and_public_profile === true && d.is_parental_control_passcode_enabled !== true && d.is_parental_control_passcode_verification_pending !== true;
    state.canEditSearchPrivacy = d.can_edit_search_privacy === true;
  }
  async function request(name, op, options, source, signal) {
    var body = 'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify({options: options, context: {}}));
    var write = op !== 'get';
    var response = await fetch('/resource/' + name + '/' + op + '/' + (write ? '' : '?' + body), {
      method: write ? 'POST' : 'GET', credentials: 'same-origin', signal: signal,
      body: write ? body : undefined, headers: {Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js'}
    });
    if (!response.ok) throw Error('http');
    var r = (await response.json()).resource_response;
    if (!r || r.status !== 'success' || r.code !== 0 || !r.data) throw Error('business');
    return name === 'UserRecentActivityResource' || name === 'ApiResource' && op === 'update' && options.url.startsWith('/v3/pfy/') ? r : r.data;
  }
  window.PinWebAccountSettings = {
    close: function () { generation++; if (abort) abort.abort(); abort = null; state = null; identity = ''; active = ''; closedActivity.clear(); attemptedActivity.clear(); },
    read: function () { return state; },
    start: async function (page, token, action, value) {
      if (location.href !== page || !/^https:\\/\\/www\\.pinterest\\.com\\/[^/?#]+\\/(?:_created\\/)?(?:[?#].*)?$/.test(page)) return;
      if (abort) return;
      active = page;
      var g = ++generation, previous = state;
      state = {page: page, token: token, loading: true, error: '', saved: false, ready: false, email: '', confirmedEmail: false,
        birthdate: '', gender: '', customGender: '', country: '', privateProfile: false, searchPrivacy: false, canChangePrivacy: false, canEditSearchPrivacy: false, topics: previous && previous.page === page ? previous.topics : [], activities: [], activityBookmark: '', activityHasMore: false, countries: previous && previous.page === page ? previous.countries : []};
      var a = new AbortController(); abort = a;
      var timer = setTimeout(function () { a.abort(); }, 15000), sent = false;
      try {
        var account = await request('UserSettingsResource', 'get', {}, '/settings/account-settings/', a.signal);
        if (g !== generation || !valid(page)) return;
        map(account);
        state.ready = true;
        if (action === 'countries' || action === 'country') {
          var countries = await request('CountriesResource', 'get', {}, '/settings/edit/country-region/', a.signal);
          if (g !== generation || !valid(page)) return;
          if (!Array.isArray(countries) || countries.length > 400) throw Error('countries');
          state.countries = countries.map(function (c) {
            if (!c || !/^[A-Z]{2}$/.test(c.key) || typeof c.name !== 'string') throw Error('country');
            return {key: c.key, name: c.name.slice(0, 160)};
          });
        }

        if (action === 'aiRead' || action === 'aiTopic' || action === 'aiAll') {
          var topicData = await request('ApiResource', 'get', {url: '/v3/users/settings/gen_ai/', data: {}}, '/edit/gen-ai-interests/', a.signal);
          if (g !== generation || !valid(page)) return;
          function mapTopics(items) {
            if (!Array.isArray(items) || items.length > 40) throw Error('topics');
            return items.map(function (t) {
              if (!t || typeof t.key !== 'string' || !/^[a-z_]{1,64}$/.test(t.key) || typeof t.text !== 'string' || typeof t.opt_out !== 'boolean' || !Array.isArray(t.interest_ids) || t.interest_ids.length > 20) throw Error('topic');
              return {key: t.key, text: t.text.slice(0,160), enabled: !t.opt_out};
            });
          }
          state.topics = mapTopics(topicData);
          if (action !== 'aiRead') {
            var change = action === 'aiTopic' ? JSON.parse(value) : {enabled: value === 'true'};
            if (typeof change.enabled !== 'boolean' || action === 'aiAll' && ['true','false'].indexOf(value) < 0) throw Error('change');
            var selected = topicData.filter(function (t) { return action === 'aiAll' || t.key === change.key; });
            if (!selected.length) throw Error('topic');
            var ids = Array.from(new Set(selected.reduce(function (out,t) { return out.concat(t.interest_ids.map(String)); }, [])));
            if (!ids.length || ids.length > 80 || ids.some(function(id) { return !/^\\d+$/.test(id); })) throw Error('ids');
            var field = change.enabled ? 'gen_ai_topics_opt_in' : 'gen_ai_topics_opt_out', update = {gen_ai_topics_update_source: 'hf_tuner'};
            update[field] = ids; sent = true;
            var result = await request('ApiResource', 'create', {url: '/v3/users/settings/', data: update}, '/edit/gen-ai-interests/', a.signal);
            if (g !== generation || !valid(page)) return;
            if (!Array.isArray(result.gen_ai_topics_opt_out) || ids.some(function (id) { return result.gen_ai_topics_opt_out.map(String).includes(id) === change.enabled; })) throw Error('result');
            var fresh = await request('ApiResource', 'get', {url: '/v3/users/settings/gen_ai/', data: {}}, '/edit/gen-ai-interests/', a.signal);
            if (g !== generation || !valid(page)) return;
            state.topics = mapTopics(fresh);
            if (state.topics.filter(function (t) { return action === 'aiAll' || t.key === change.key; }).some(function (t) { return t.enabled !== change.enabled; })) throw Error('readback');
            state.saved = true;
          }
        } else if (action === 'activityRead' || action === 'activityClose') {
          if (action === 'activityClose' && (!/^\\d+$/.test(value) || !previous || previous.page !== page || !previous.activities.some(function(p) { return p.id === value; }) || attemptedActivity.has(value))) throw Error('activity');
          var feed = await request('UserRecentActivityResource', 'get', {username: 'me', filter_type: 'all'}, '/edit/activity/', a.signal);
          if (g !== generation || !valid(page)) return;
          if (!Array.isArray(feed.data) || feed.data.length > 100) throw Error('feed');
          state.activities = feed.data.map(function (p) {
            if (!p || !/^\\d+$/.test(String(p.id || ''))) throw Error('pin');
            var image = p.images && (p.images['474x'] || p.images['236x'] || p.images.orig), url = image && image.url;
            if (typeof url !== 'string' || !/^https:\\/\\/[^/]*pinimg\\.com\\//.test(url)) throw Error('image');
            return {id: String(p.id), title: text(p.grid_title || p.title || p.description, 300), image: url,
              width: typeof image.width === 'number' && image.width > 0 ? image.width : 236,
              height: typeof image.height === 'number' && image.height > 0 ? image.height : 300,
              recommendationClosed: closedActivity.has(String(p.id)), closeUncertain: attemptedActivity.has(String(p.id)) && !closedActivity.has(String(p.id))};
          });
          state.activityBookmark = text(feed.bookmark, 4096); state.activityHasMore = !!state.activityBookmark && state.activityBookmark !== '-end-';
          if (action === 'activityClose') {
            var pin = state.activities.find(function(p) { return p.id === value; });
            if (!pin) throw Error('activity');
            attemptedActivity.add(value); pin.closeUncertain = true; sent = true;
            var feedback = await request('ApiResource', 'update', {url: '/v3/pfy/' + value + '/feedback/', data: {pin: value, feedback_type: 4, through_id: value, rec_reason_type: 4}}, '/edit/activity/', a.signal);
            if (g !== generation || !valid(page)) return;
            if (feedback.endpoint_name !== 'v3_provide_pfy_pin_feedback' || String(feedback.data.id) !== value || feedback.data.type !== 'pin') throw Error('feedback');
            closedActivity.add(value); pin.recommendationClosed = true; pin.closeUncertain = false; state.saved = true;
          }
        } else if (action === 'privateProfile' || action === 'searchPrivacy') {
          if (!['true','false'].includes(value) || action === 'privateProfile' && !state.canChangePrivacy || action === 'searchPrivacy' && !state.canEditSearchPrivacy) throw Error('permission');
          var field = action === 'privateProfile' ? 'opt_in_private_account' : 'exclude_from_search';
          var opts = {user_id: identity, surface_tag: 'settings'};
          opts[field] = value === 'true';
          if (action === 'privateProfile') opts.user_confirm_skip_passcode = false;
          sent = true;
          var result = await request('UserSettingsResource', 'update', opts, '/settings/profile-visibility/', a.signal);
          if (g !== generation || !valid(page)) return;
          if (result[field] !== opts[field]) throw Error('result');
          var account = await request('UserSettingsResource', 'get', {}, '/settings/profile-visibility/', a.signal);
          if (g !== generation || !valid(page)) return;
          map(account);
          if (state[action] !== opts[field]) throw Error('readback');
          state.saved = true;
        } else
        if (['birthdate', 'gender', 'customGender', 'country'].indexOf(action) >= 0) {
          var opts = {user_id: identity, surface_tag: 'settings'}, field = action === 'customGender' ? 'custom_gender' : action;
          if (action === 'birthdate') {
            if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(value)) throw Error('date');
            var date = new Date(value + 'T00:00:00Z');
            if (!isFinite(date.getTime()) || date.toISOString().slice(0,10) !== value || value > new Date().toISOString().slice(0,10)) throw Error('date');
            delete opts.user_id;
          } else if (action === 'gender') {
            if (['female','male','unspecified'].indexOf(value) < 0) throw Error('gender');
          } else if (action === 'customGender') {
            if (state.gender !== 'unspecified' || !value.trim() || value.length > 500) throw Error('custom');
          } else if (!state.countries.some(function (c) { return c.key === value; })) throw Error('country');
          opts[field] = value;
          sent = true;
          var source = '/settings/edit/' + (action === 'customGender' ? 'gender' : action === 'country' ? 'country-region' : action) + '/';
          var result = await request('UserSettingsResource', 'update', opts, source, a.signal);
          if (g !== generation || !valid(page)) return;
          if (result[field] !== value) throw Error('result');
          state[action] = value; state.saved = true;
        } else if (action !== 'read' && action !== 'countries') throw Error('action');
      } catch (_) {
        if (g === generation && valid(page)) state.error = sent ? '保存结果未确认，请返回后重新读取核对；不会自动重试保存' : '读取失败，请重试';
      } finally {
        clearTimeout(timer);
        if (g === generation && valid(page) && state) state.loading = false;
        if (abort === a) abort = null;
      }
    }
  };
})();`;
