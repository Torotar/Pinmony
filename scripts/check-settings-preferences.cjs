const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function moduleFrom(file) { const exports = {}; vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText, { exports, require: () => ({}) }); return exports; }
const { PIN_ACCOUNT_SETTINGS_SCRIPT } = moduleFrom('feature_settings/src/main/ets/services/PinmonyAccountSettingsScript.ets');
const { acceptsNetworkJob } = moduleFrom('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const page = 'https://www.pinterest.com/synthetic/';
function harness() {
  const account = { id: '123', username: 'synthetic', allow_switch_between_private_and_public_profile: true, can_edit_search_privacy: true, opt_in_private_account: false, search_privacy_enabled: true, exclude_from_search: true };
  const topics = [{ key: 'art', text: '艺术', opt_out: false, interest_ids: [101] }, { key: 'fashion', text: '时尚', opt_out: false, interest_ids: [102, 103] }];
  const writes = []; let mismatch = false, rejectWrite = false;
  const context = { URL, AbortController, setTimeout, clearTimeout, location: new URL(page),
    fetch: async (url, init) => {
      const p = new URLSearchParams(init.body || new URL(url, page).search), options = JSON.parse(p.get('data')).options;
      let data;
      if (init.method === 'POST') {
        writes.push(options); if (rejectWrite) throw Error('network');
        if (options.url === '/v3/users/settings/') {
          assert.equal(options.data.gen_ai_topics_update_source, 'hf_tuner');
          const enabled = !!options.data.gen_ai_topics_opt_in;
          const ids = options.data.gen_ai_topics_opt_in || options.data.gen_ai_topics_opt_out;
          topics.forEach(t => { if (t.interest_ids.some(id => ids.includes(String(id)))) t.opt_out = !enabled; });
          data = { gen_ai_topics_opt_out: topics.filter(t => t.opt_out).flatMap(t => t.interest_ids.map(String)) };
        } else if (options.url && options.url.startsWith('/v3/pfy/')) {
          assert.equal(p.get('source_url'), '/edit/activity/');
          assert.equal(options.url, '/v3/pfy/12/feedback/');
          assert.equal(options.data.pin, '12'); assert.equal(options.data.through_id, '12');
          assert.equal(options.data.feedback_type, 4); assert.equal(options.data.rec_reason_type, 4);
          data = { id: mismatch ? '99' : '12', type: 'pin' };
        } else {
          const field = Object.keys(options).find(k => !['user_id', 'surface_tag', 'user_confirm_skip_passcode'].includes(k));
          if (field === 'opt_in_private_account') assert.equal(options.user_confirm_skip_passcode, false);
          account[field] = options[field]; if (field === 'exclude_from_search') account.search_privacy_enabled = options[field];
          data = { [field]: mismatch ? !options[field] : options[field] };
        }
      } else if (options.url === '/v3/users/settings/gen_ai/') data = topics.map(t => ({ ...t }));
      else if (url.includes('UserRecentActivityResource')) {
        assert.equal(options.username, 'me'); assert.equal(options.filter_type, 'all');
        data = [{ id: '12', grid_title: 'Synthetic pin', images: { '474x': { url: 'https://i.pinimg.com/synthetic.jpg', width: 474, height: 800 } } }];
      } else data = { ...account };
      return { ok: true, json: async () => ({ resource_response: { status: 'success', code: 0, data,
        endpoint_name: options.url && options.url.startsWith('/v3/pfy/') ? 'v3_provide_pfy_pin_feedback' : '' } }) };
    } };
  context.window = context; context.top = context; vm.runInNewContext(PIN_ACCOUNT_SETTINGS_SCRIPT, context);
  return { api: context.PinmonyAccountSettings, writes, account, topics, mismatch() { mismatch = true; }, fail() { rejectWrite = true; } };
}
async function main() {
  const h = harness();
  await h.api.start(page, 1, 'aiRead', ''); assert.equal(h.api.read().topics.length, 2); assert.equal(h.api.read().topics[1].text, '时尚');
  await h.api.start(page, 2, 'aiTopic', JSON.stringify({ key: 'fashion', enabled: false }));
  assert.equal(h.api.read().saved, true); assert.equal(h.api.read().topics[1].enabled, false); assert.deepEqual(h.writes[0].data.gen_ai_topics_opt_out, ['102', '103']);
  await h.api.start(page, 3, 'aiAll', 'false'); assert(h.api.read().topics.every(t => !t.enabled)); assert.equal(h.writes[1].data.gen_ai_topics_opt_out.length, 3);
  await h.api.start(page, 4, 'aiAll', 'true'); assert(h.api.read().topics.every(t => t.enabled));
  await h.api.start(page, 5, 'aiTopic', JSON.stringify({ key: 'unknown', enabled: false })); assert.equal(h.writes.length, 3);
  await h.api.start(page, 6, 'activityRead', ''); assert.equal(h.api.read().activities.length, 1); assert.equal(h.api.read().activities[0].width, 474);
  await h.api.start(page, 7, 'privateProfile', 'true'); assert.equal(h.api.read().privateProfile, true); assert.equal(h.api.read().saved, true);
  await h.api.start(page, 8, 'searchPrivacy', 'false'); assert.equal(h.api.read().searchPrivacy, false);
  h.account.is_parental_control_passcode_enabled = true;
  await h.api.start(page, 9, 'privateProfile', 'false'); assert.equal(h.writes.length, 5); assert.equal(h.api.read().canChangePrivacy, false);
  const wrong = harness(); wrong.mismatch(); await wrong.api.start(page, 10, 'privateProfile', 'true'); assert.equal(wrong.api.read().saved, false); assert.match(wrong.api.read().error, /未确认/);
  const failed = harness(); failed.fail(); await failed.api.start(page, 11, 'aiAll', 'false'); assert.equal(failed.writes.length, 1); assert.equal(failed.api.read().saved, false);
  const activity = harness();
  await activity.api.start(page, 12, 'activityRead', '');
  assert.equal(activity.api.read().activities[0].recommendationClosed, false);
  await activity.api.start(page, 13, 'activityClose', '99'); assert.equal(activity.writes.length, 0);
  await activity.api.start(page, 14, 'activityRead', '');
  await activity.api.start(page, 15, 'activityClose', '12');
  assert.equal(activity.api.read().saved, true); assert.equal(activity.api.read().activities[0].recommendationClosed, true);
  await activity.api.start(page, 16, 'activityRead', ''); assert.equal(activity.api.read().activities[0].recommendationClosed, true);
  await activity.api.start(page, 17, 'activityClose', '12'); assert.equal(activity.writes.length, 1, 'confirmed closure is not replayed');
  const uncertain = harness(); await uncertain.api.start(page, 18, 'activityRead', ''); uncertain.mismatch();
  await uncertain.api.start(page, 19, 'activityClose', '12'); assert.equal(uncertain.api.read().saved, false);
  assert.equal(uncertain.api.read().activities[0].recommendationClosed, false); assert.equal(uncertain.api.read().activities[0].closeUncertain, true);
  await uncertain.api.start(page, 20, 'activityRead', ''); await uncertain.api.start(page, 21, 'activityClose', '12');
  assert.equal(uncertain.writes.length, 1, 'uncertain closure is not replayed');
  activity.api.close(); await activity.api.start(page, 22, 'activityRead', '');
  assert.equal(activity.api.read().activities[0].recommendationClosed, false, 'closure evidence is scoped to this settings session');
  const state = { authenticated: true, epoch: 1, page, userAgent: 'synthetic' };
  const job = { id: 'test', epoch: 1, page, url: 'https://www.pinterest.com/resource/UserSettingsResource/update/', method: 'POST', headers: {}, body: '' };
  const allowed = options => acceptsNetworkJob({ ...job, body: 'data=' + encodeURIComponent(JSON.stringify({ options })) }, state);
  assert(allowed({ user_id: '123', surface_tag: 'settings', opt_in_private_account: true, user_confirm_skip_passcode: false }));
  assert(!allowed({ user_id: '123', surface_tag: 'settings', opt_in_private_account: true, user_confirm_skip_passcode: true }));
  assert(allowed({ user_id: '123', surface_tag: 'settings', exclude_from_search: true }));
  assert(!allowed({ user_id: '123', surface_tag: 'settings', exclude_from_search: 'true' }));
  assert(!allowed({ user_id: '123', surface_tag: 'settings', exclude_from_search: true, password: 'synthetic' }));
  console.log('Preferences: live topics/IDs, AI global/per-topic writes and readback, activity, privacy permissions, no bypass, uncertain results and no replay passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
