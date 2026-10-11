const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = process.argv[2] ? fs.readFileSync(process.argv[2], 'utf8') : readSourceFileSync('entry/src/main/ets/services/PinmonyPostApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
new Function(script);
const requests = [], events = [];
const pin = 'https://www.pinterest.com/pin/101/';
let data = { id: '101', tracking_params: 'current-tracking', reaction_by_me: 0,
  aggregated_pin_id: '202', images: { '736x': { url: 'https://i.pinimg.com/current.jpg' } } };
const window = { PinmonyPostApiEnabled: true, PinmonyDetailApi: { raw: () => data },
  PinmonyShareBridge: { postState: value => events.push(JSON.parse(value)) } }; window.top = window;
const document = { cookie: 'csrftoken=current-session' };
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/pin/101/', href: pin };
class XHR { open() {} send() {} setRequestHeader() {} addEventListener() {} }
window.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }));
const context = { window, document, location, URL, URLSearchParams, Headers, XMLHttpRequest: XHR,
  AbortController, setTimeout, clearTimeout, fetch: (...args) => window.fetch(...args) };
vm.runInNewContext(script, context);
const api = window.PinmonyPostApi;
const flush = () => new Promise(resolve => setImmediate(resolve));
async function reply(index, resource, status = 200) {
  requests[index].resolve({ ok: status < 400, status, json: async () => resource, clone: () => ({ json: async () => resource }) }); await flush();
}
const ok = data => ({ resource_response: { status: 'success', code: 0, data } });
const snapshot = () => ({ session: 1, pinUrl: pin, options: [{ id: 'copy', label: '复制链接', enabled: true },
  { id: 'wa', label: 'WhatsApp', enabled: true }, { id: 'fb', label: 'Facebook', enabled: true }], actions: [], contacts: [{ id: 'old-dom' }] });
async function main() {
  window.fetch('/_/graphql/', { credentials: 'same-origin', method: 'POST', headers: { 'X-CSRFToken': 'current-session' },
    body: JSON.stringify({ queryHash: 'a'.repeat(64), variables: { objectId: '101', inviteType: JSON.stringify({ invite_category: 3, invite_object: 1, invite_channel: 10 }) } }) });
  assert.equal(api.shareSnapshot(snapshot(), () => {}).contacts.length, 0);
  assert.equal(requests.length, 2);
  assert.match(requests[1].url, /ShareSuggestionsResource\/get/);
  assert.equal(requests[1].options.credentials, 'same-origin');
  assert.equal(requests[0].options.headers['X-CSRFToken'], 'current-session');
  assert.equal(requests[1].options.headers.Cookie, undefined);
  assert.equal(JSON.parse(requests[0].options.body).variables.objectId, '101');
  await reply(1, ok([{ id: '303', username: 'person', full_name: 'Person' }]));
  await reply(0, { data: { v3InviteUserExternalQuery: { data: { inviteUrl: 'https://pin.it/test', title: 'Look' } } } });
  const ready = api.shareSnapshot(snapshot(), () => {});
  assert.equal(ready.contacts[0].id, 'api-user:303');
  assert.equal(ready.options.find(x => x.id === 'fb').enabled, true);
  api.shareSearch(1, 'old'); api.shareSearch(1, 'new');
  await reply(3, ok({ items: [{ id: '404', username: 'new' }] }));
  await reply(2, ok({ items: [{ id: '505', username: 'old' }] }));
  assert.equal(api.shareSnapshot(snapshot(), () => {}).contacts[0].id, 'api-user:404');
  assert.equal(api.shareAction(1, 'api-user:505'), false);
  assert.equal(api.shareAction(1, 'api-user:404'), true);
  assert.equal(api.shareAction(1, 'api-user:404'), false); // Duplicate writes blocked.
  await reply(4, { resource_response: { error: { code: 4372, message: '收件人不允许消息' } } }, 409);
  assert.match(api.shareSnapshot(snapshot(), () => {}).feedback, /收件人/);
  api.shareAction(1, 'api-user:404');
  await reply(5, ok({ last_message: { id: 'message', pin: { id: '101' } }, users: [{ id: '404' }] }));
  assert.equal(api.shareSnapshot(snapshot(), () => {}).feedback, '已发送');
  api.shareAction(1, 'copy'); api.shareClose();
  assert.equal(JSON.parse(requests[6].options.body).queryHash, 'a'.repeat(64));
  assert.equal(JSON.parse(JSON.parse(requests[6].options.body).variables.inviteType).invite_channel, 12);
  await reply(6, { data: { v3InviteUserExternalQuery: { data: { inviteUrl: 'https://pin.it/stale', title: 'Old' } } } });
  assert.equal(events.length, 0); // Closing sheet cannot copy a late result.
  api.commentsStart(pin);
  const commentBody = JSON.parse(new URL(requests[7].url, pin).searchParams.get('data'));
  assert.equal(commentBody.options.aggregated_pin_id, '202');
  await reply(7, ok([{ id: '9007199254740999', text: 'hello', user: { full_name: 'Person' } }]));
  assert.equal(api.commentsRead(pin).items[0].id, '9007199254740999');
  assert.equal(api.commentsRead(pin).items[0].avatar, '');
  data = { ...data, aggregated_pin_id: undefined }; api.reset();
  api.commentsStart(pin); assert.ok(api.commentsRead(pin).error); assert.equal(requests.length, 8);
  const menu = api.moreSnapshot({ session: 2, pin, options: ['举报 Pin 图', '在应用中打开', '添加到拼贴', '下载图片', '查看更多', '编辑 Pin 图']
    .map((label, i) => ({ id: String(i), label, enabled: true })) });
  assert.equal(menu.options.length, 3);
  assert.equal(menu.options.find(x => x.label === '查看更多').enabled, true);
  assert.equal(menu.options.find(x => x.label === '下载图片').enabled, true);
  const action = [{ id: 'like', kind: 'like', enabled: true }];
  assert.equal(api.detailActions(pin, action)[0].enabled, true);
  api.like(pin, () => {}, () => {});
  assert.equal(api.detailActions(pin, action)[0].selected, false); // No optimistic success.
  await reply(8, ok({ id: '101' }));
  assert.equal(api.detailActions(pin, action)[0].selected, true);
  assert.equal(api.detailActions(pin, action)[0].enabled, false); // Unknown unlike contract cannot be guessed.
  api.reset(); api.like(pin, () => {}, () => { throw Error('stale failure leaked'); }); api.reset();
  await reply(9, ok({ id: '101' }));
  assert.equal(api.detailActions(pin, action)[0].selected, false);
  document.cookie = ''; api.shareSnapshot(snapshot(), () => {}); await flush();
  await reply(10, ok([]));
  assert.equal(api.shareSnapshot(snapshot(), () => {}).error, ''); // Opening does not generate an invitation.
  assert.equal(api.shareAction(1, 'copy'), true);
  await flush();
  assert.equal(api.shareSnapshot(snapshot(), () => {}).error, ''); // Validated original-link copy is not an invitation failure.
  assert.equal(events.at(-1).kind, 'copy'); // Original Pin URL remains usable.
  events.length = 0;
  api.shareClose();
  document.cookie = 'csrftoken=current-session';
  const observed = { pin: '101', through_id: 'current-page', rec_reason_type: 36, client_tracking_params: 'current', source: 5 };
  const xhr = new XHR(); xhr.open('POST', '/resource/ApiResource/update/');
  xhr.send('source_url=' + encodeURIComponent('/pin/101/') + '&data=' + encodeURIComponent(JSON.stringify({
    options: { url: '/v3/pin/101/feedback/see_more/', data: observed }
  })));
  const feedback = api.moreSnapshot({ session: 3, pin, options: [{ id: 'more', label: '查看更多', enabled: true },
    { id: 'less', label: '查看更少', enabled: true }] });
  assert.equal(feedback.options[0].enabled, true);
  api.moreAction(3, pin, 'less', () => {});
  const sent = JSON.parse(new URLSearchParams(requests[11].options.body).get('data'));
  assert.equal(sent.options.url, '/v3/pfy/101/feedback/');
  assert.equal(sent.options.data.feedback_type, 10);
  api.moreClose(); await reply(11, ok({ id: '101' })); assert.equal(events.length, 0);
  const mobile = { ...snapshot(), session: 2, options: [{ id: 'messenger', label: 'Facebook Messenger', enabled: true },
    { id: 'sms', label: '信息', enabled: true }] };
  const mobileState = api.shareSnapshot(mobile, () => {});
  assert.equal(mobileState.options[0].label, 'Messenger');
  assert.equal(mobileState.options[1].label, '短信');
  assert.equal(mobileState.options[0].enabled, true);
  await reply(12, ok([]));
  api.shareAction(2, 'messenger'); await flush();
  assert.equal(events[0].kind, 'systemShare');
  assert.equal(events[0].platform, 'Messenger');
  assert.equal(events[0].value, pin); // Valid current JSON Pin URL is usable even if a short-link request fails.
  api.shareSearch(2, 'broken');
  requests[13].resolve({ ok: false, status: 400, json: async () => { throw new SyntaxError('Unexpected token I, Invalid Request'); }, clone: () => ({ json: async () => { throw new SyntaxError(); } }) });
  await flush();
  const broken = api.shareSnapshot(mobile, () => {});
  assert.match(broken.error, /无效数据/); assert.doesNotMatch(broken.error, /Unexpected token|Invalid Request/);
  window.fetch('/resource/ShareSuggestionsTypeaheadResource/get/?source_url=%2Fpin%2F101%2F&data=' +
    encodeURIComponent(JSON.stringify({ options: { term: 'broken' } })), { headers: { 'X-Pinterest-Pws-Handler': 'current-mobile-handler' } });
  await reply(14, ok({ items: [{ id: '606', username: 'recovered' }] }));
  assert.equal(api.shareSnapshot(mobile, () => {}).contacts[0].id, 'api-user:606');
  assert.doesNotMatch(api.shareSnapshot(mobile, () => {}).error, /无效数据/);
  assert.doesNotMatch(source, /9444c7d899b56b0d3f582/); // Desktop persisted-query hash must not be shipped as the mobile default.
  api.shareClose();
  api.reset(); events.length = 0;
  const feedbackMenu = () => api.moreSnapshot({ session: 4, pin, options: [
    { id: 'more', label: '查看更多', enabled: true }, { id: 'less', label: '查看更少', enabled: true }] });
  const start = requests.length;
  feedbackMenu();
  assert.equal(api.moreAction(4, pin, 'more', () => {}), true); // First click needs no earlier website feedback.
  assert.equal(api.moreAction(4, pin, 'less', () => {}), false);
  assert.equal(feedbackMenu().options[0].enabled, false);
  const firstFeedback = JSON.parse(new URLSearchParams(requests[start].options.body).get('data')).options;
  assert.equal(firstFeedback.url, '/v3/pin/101/feedback/see_more/');
  assert.deepEqual(firstFeedback.data, { pin: '101', client_tracking_params: 'current-tracking', source: 5 });
  await reply(start, { resource_response: { status: 'success', code: 0,
    endpoint_name: 'v3_pin_see_more_user_feedback', data: { id: '101' } } });
  assert.equal(events.at(-1).value, '已提交查看更多反馈');
  assert.equal(feedbackMenu().options[1].enabled, true);
  api.moreAction(4, pin, 'less', () => {});
  await reply(start + 1, { resource_response: { status: 'failure', error: { message: '缺少反馈上下文' } } }, 400);
  assert.equal(events.at(-1).value, '缺少反馈上下文');
  assert.equal(feedbackMenu().options[1].enabled, true); // A real failed request can be retried.
  api.moreAction(4, pin, 'less', () => {});
  await reply(start + 2, { resource_response: { status: 'success', code: 0,
    endpoint_name: 'v3_provide_pfy_pin_feedback', data: { id: '999' } } });
  assert.match(events.at(-1).value, /未能确认/); // HTTP success for another Pin is not feedback success.
  feedbackMenu(); api.moreAction(4, pin, 'less', () => {});
  await reply(start + 3, { resource_response: { status: 'success', code: 0,
    endpoint_name: 'v3_provide_pfy_pin_feedback', data: { id: '101' } } });
  assert.equal(events.at(-1).value, '已提交查看更少反馈');
  api.reset();
  data = { id: '999', tracking_params: 'other-pin', through_id: 'other-context', source: 5 };
  feedbackMenu(); api.moreAction(4, pin, 'more', () => {});
  assert.deepEqual(JSON.parse(new URLSearchParams(requests[start + 4].options.body).get('data')).options.data, { pin: '101', source: 5 });
  const eventCount = events.length;
  api.moreClose();
  await reply(start + 4, { resource_response: { status: 'success', code: 0,
    endpoint_name: 'v3_pin_see_more_user_feedback', data: { id: '101' } } });
  assert.equal(events.length, eventCount);
  window.PinmonyEditApiEnabled = true;
  const editMenu = api.moreSnapshot({ session: 8, pin, options: [{ id: 'edit', label: '编辑 Pin 图', enabled: true }] });
  assert.equal(editMenu.options[0].enabled, true);
  assert.equal(api.moreAction(7, pin, 'edit', () => {}), false, 'stale menu session cannot open editor');
  assert.equal(api.moreAction(8, pin, 'edit', () => {}), true);
  assert.equal(events.at(-1).kind, 'editOpen');
  window.PinmonyEditApiEnabled = false;
  assert.equal(api.moreSnapshot({ session: 9, pin, options: [{ id: 'edit', label: '编辑 Pin 图', enabled: true }] }).options[0].enabled, false);
  const disabled = { ...window, PinmonyPostApi: undefined, PinmonyPostApiEnabled: false }; disabled.top = disabled;
  vm.runInNewContext(script, { ...context, window: disabled }); assert.equal(disabled.PinmonyPostApi, undefined);
  console.log('post API contracts, writes, privacy errors, stale sessions, missing context, comments and rollback flag OK');
}
main().catch(error => { console.error(error); process.exit(1); });



