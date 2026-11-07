const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const {createArktsLoader} = require('./arkts-module-loader.cjs');
const logs = [];
const loader = createArktsLoader(ts, {
  common_foundation: {PinmonyRuntimeLog: {info: text => logs.push(text), warn: text => logs.push(text)}},
  common_network: {PIN_BUSINESS_PIN_READ_ENABLED: true}, common_session: {},
  '@kit.RemoteCommunicationKit': {rcp: {}}, '@kit.BasicServicesKit': {}
}, {Error});
const {PinmonySettingsNativeFlow} = loader.loadFile('entry/src/main/ets/app/PinmonySettingsNativeFlow.ets');
const {emptySocialPermissions} = loader.loadFile('feature_settings/src/main/ets/models/PinmonySocialPermissions.ets');
function fixture(screen = 'socialComments') {
  const store = {social: emptySocialPermissions(), socialMessageGroup: 0};
  const flow = new PinmonySettingsNativeFlow({store: () => store});
  Object.assign(flow, {screen, current: () => true});
  flow.client.viewer = '1';
  const settings = {id: '1', is_partner: false, allow_mentions: 0,
    comments_disabled: 2, shopping_rec_disabled: false, allow_idea_pin_downloads: false,
    is_parental_control_passcode_enabled: false, is_parental_control_passcode_verification_pending: false,
    messaging_permissions: [0, 1, 2, 4].map(group_id => ({group_id,
      eligible_levels: group_id === 4 ? [1, 2] : [0, 1, 2], selected_level: group_id === 0 ? 0 : 1}))};
  const filters = {comments_phrase_filter_list: [], comments_phrase_filter_list_enabled: false,
    pinner_comments_phrase_filter_list: [], pinner_comments_phrase_filter_list_enabled: false};
  const calls = [];
  flow.request = async (name, verb, options, source) => {
    calls.push(options.url);
    assert.equal(name, 'ApiResource'); assert.equal(verb, 'get');
    assert.equal(source, screen === 'socialMentions' ? '/settings/edit/mentions/' :
      ['social', 'socialComments'].includes(screen) ? '/settings/permissions/' : '/settings/messages/');
    const filter = options.url === '/v3/aggregated_comments/features/';
    if (filter) assert.equal(options.data.user, '1');
    return {resource_response: {endpoint_name: filter ? 'v3_get_aggregated_comment_features' : 'v3_get_user_settings', data: filter ? filters : settings}};
  };
  return {flow, store, settings, filters, calls};
}
async function main() {
  for (const screen of ['social', 'socialComments']) {
    const f = fixture(screen); await f.flow.socialRead(11);
    assert.equal(f.store.social.ready, true); assert.equal(f.store.social.commentsEnabled, false);
    assert.equal(f.store.social.protected, false);
    assert.equal(f.store.social.myCommentFilterPhrases.length, 0, 'captured empty lists are valid');
    assert.equal(f.calls.length, 2);
    f.settings.comments_disabled = 1;
    f.filters.pinner_comments_phrase_filter_list = ['synthetic-filter'];
    f.filters.pinner_comments_phrase_filter_list_enabled = true;
    await f.flow.socialRead(12);
    assert.equal(f.store.social.commentsEnabled, true);
    assert.equal(f.store.social.otherCommentFilterPhrases[0], 'synthetic-filter');
    assert(logs.some(text => text.includes(`revision=12 screen=${screen} phase=committed`)));
  }
  for (const screen of ['socialMentions', 'socialMessages', 'socialFriends', 'socialFollowers', 'socialFollowing', 'socialOthers']) {
    const f = fixture(screen); await f.flow.socialRead(12);
    assert.equal(f.store.social.ready, true);
    assert.equal(f.calls.length, 1, 'message and mention pages keep their existing single settings read');
  }
  for (const [stage, reason, change] of [
    ['settings-validation', 'social', f => {f.settings.id = '2';}],
    ['message-groups', 'social-group', f => {f.settings.messaging_permissions[0].group_id = 99;}],
    ['message-groups', 'duplicate-group', f => {f.settings.messaging_permissions.push(f.settings.messaging_permissions[0]);}],
    ['filters-validation', 'social-filters', f => {delete f.filters.comments_phrase_filter_list_enabled;}],
    ['filter-phrases', 'social-phrases', f => {f.filters.comments_phrase_filter_list = null;}],
    ['filter-phrases', 'social-phrase', f => {f.filters.comments_phrase_filter_list = [' '];}],
    ['filter-phrases', 'social-phrase-duplicate', f => {f.filters.comments_phrase_filter_list = ['x', 'x'];}],
    ['comment-settings', 'social-setting-shape', f => {delete f.settings.allow_idea_pin_downloads;}]
  ]) {
    const f = fixture(); change(f); const before = logs.length;
    await assert.rejects(f.flow.socialRead(13), {message: reason});
    assert(logs.slice(before).some(text => text.includes(`phase=failed stage=${stage} reason=${reason}`)));
    assert.equal(f.store.social.ready, false, 'invalid data never becomes a successful snapshot');
  }
  for (const stage of ['settings-request', 'filters-request']) {
    const f = fixture(), request = f.flow.request;
    f.flow.request = async (...args) => {
      if (stage === 'settings-request' || args[2].url.includes('aggregated_comments')) throw Error('request');
      return request(...args);
    };
    const before = logs.length;
    await assert.rejects(f.flow.socialRead(14), {message: 'request'});
    assert(logs.slice(before).some(text => text.includes(`stage=${stage} reason=request`)));
  }
  const stale = fixture(); stale.flow.current = () => false;
  await stale.flow.socialRead(15);
  assert.equal(stale.store.social.ready, false); assert.equal(stale.calls.length, 1);
  assert(logs.some(text => text.includes('revision=15 screen=socialComments phase=discarded')));
  const sensitive = fixture(); sensitive.flow.request = async () => {throw Error('synthetic-secret-cookie');};
  await assert.rejects(sensitive.flow.socialRead(16));
  assert(!logs.some(text => text.includes('synthetic-secret-cookie')));
  assert(!logs.some(text => text.includes('synthetic-filter')));
  const source = fs.readFileSync('entry/src/main/ets/app/PinmonySettingsNativeFlow.ets', 'utf8');
  assert(source.includes("if (action === 'socialRead') {"));
  assert(source.includes("phase=action-failed reason="), 'identity preflight failures are observable too');
  console.log('Social read diagnostics: captured response shapes, both pages, empty filters, failure stages, stale reads and redacted errors passed');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
