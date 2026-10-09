const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const sourceScript = path => Function('return `' + fs.readFileSync(path, 'utf8').match(/= `([\s\S]*?)`;/)[1] + '`')();
const pin = 'https://www.pinterest.com/pin/101/';
function harness() {
  const requests = [], location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/pin/101/', href: pin };
  const window = { PinWebPostApiEnabled: true, PinWebPostExtensionsEnabled: true,
    PinWebDetailApi: { raw: () => ({ id: '101', aggregated_pin_data: { id: '202' } }) } };
  window.top = window;
  window.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }));
  class XHR { open() {} send() {} setRequestHeader() {} addEventListener() {} }
  const context = { window, location, document: { cookie: 'csrftoken=synthetic-test', querySelectorAll: () => [] }, URL, URLSearchParams, Headers,
    XMLHttpRequest: XHR, AbortController, setTimeout, clearTimeout, fetch: (...args) => window.fetch(...args) };
  vm.runInNewContext(sourceScript('feature_pin/src/main/ets/services/PinWebPostApiScript.ets'), context);
  vm.runInNewContext(sourceScript('feature_pin/src/main/ets/services/PinWebPostExtensionsScript.ets'), context);
  const api = window.PinWebPostApi;
  const reply = async (index, data, endpoint = '') => {
    requests[index].resolve({ ok: true, json: async () => ({ client_context: { user: { id: '77' } },
      resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data }, bookmark: '-end-' }) });
    await new Promise(resolve => setImmediate(resolve));
  };
  return { api, requests, reply, location };
}
const comment = (id, text = 'hello', user = '77') => ({ id, type: 'aggregatedcomment', text, user: { id: user, full_name: 'Reader' } });
const options = request => JSON.parse(new URLSearchParams(request.options.body).get('data')).options;
async function main() {
  const h = harness(); h.api.commentsStart(pin); await h.reply(0, [comment('301'), comment('302', 'other', '88')]);
  assert.equal(h.api.commentsRead(pin).items[0].canEdit, true);
  assert.equal(h.api.commentsRead(pin).items[1].canDelete, false);
  assert.equal(await h.api.commentWrite(pin, JSON.stringify({ action: 'delete', id: '302' })), false);
  const create = h.api.commentWrite(pin, JSON.stringify({ action: 'create', text: 'new' }));
  assert.deepEqual(options(h.requests[1]), { force: false, objectId: '202', pinId: '101', tags: '[]', text: 'new' });
  assert.equal(await h.api.commentWrite(pin, JSON.stringify({ action: 'create', text: 'new' })), false);
  await h.reply(1, comment('303', 'new'), 'v3_create_aggregated_pin_data_comment'); await h.reply(2, [comment('303', 'new'), comment('301')]); await create;
  assert.equal(h.api.commentsRead(pin).mutationVersion, 1);
  const edit = h.api.commentWrite(pin, JSON.stringify({ action: 'edit', id: '301', text: 'edited' }));
  assert.deepEqual(options(h.requests[3]), { commentId: '301', force: false, tags: '[]', text: 'edited' });
  await h.reply(3, comment('301', 'edited'), 'v3_update_aggregated_comment'); await h.reply(4, [comment('301', 'edited')]); await edit;
  const deletion = h.api.commentWrite(pin, JSON.stringify({ action: 'delete', id: '301' }));
  await h.reply(5, null, 'v3_delete_aggregated_comment'); await h.reply(6, []); await deletion;
  assert.equal(h.api.commentsRead(pin).items.length, 0);
  assert.equal(h.api.commentPhotoBegin(pin), true);
  const photo = h.api.commentWrite(pin, JSON.stringify({ action: 'photo', text: 'look', signature: 'a'.repeat(32) }));
  assert.equal(options(h.requests[7]).url, '/v3/did_it/');
  const photoData = { id: '401', type: 'userdiditdata', details: 'look', user: { id: '77' }, pin: { id: '101' }, image_signatures: ['a'.repeat(32)] };
  await h.reply(7, photoData, 'v3_create_user_did_it_data'); await h.reply(8, [photoData]); await photo;
  const reply = h.api.commentWrite(pin, JSON.stringify({ action: 'reply', id: '401', text: 'reply' }));
  assert.match(h.requests[9].url, /DidItCommentsResource\/create/);
  assert.equal(options(h.requests[9]).objectId, '401');
  await h.reply(9, comment('501', 'reply'), 'v3_create_user_did_it_data_comment'); await h.reply(10, [photoData]); await reply;
  const failure = h.api.commentWrite(pin, JSON.stringify({ action: 'create', text: 'failed' }));
  await h.reply(11, comment('502', 'wrong'), 'v3_create_aggregated_pin_data_comment'); await failure;
  assert.equal(h.api.commentsRead(pin).uncertain, true);
  assert.equal(await h.api.commentWrite(pin, JSON.stringify({ action: 'create', text: 'failed' })), false);
  const late = harness(); late.api.commentsStart(pin); await late.reply(0, []);
  const pending = late.api.commentWrite(pin, JSON.stringify({ action: 'create', text: 'late' }));
  late.api.commentsClose(); late.location.pathname = '/pin/999/';
  await late.reply(1, comment('601', 'late'), 'v3_create_aggregated_pin_data_comment'); await pending;
  assert.equal(late.api.commentsRead(pin), null);
  const photoOps = harness(); photoOps.api.commentsStart(pin); await photoOps.reply(0, [photoData]);
  const like = photoOps.api.commentLike(pin, '401');
  assert.equal(options(photoOps.requests[1]).url, '/v3/did_it/401/like/');
  await photoOps.reply(1, null, 'v3_like_user_did_it_data');
  await photoOps.reply(2, [{ ...photoData, liked_by_me: true, like_count: 1 }]); await like;
  assert.equal(photoOps.api.commentsRead(pin).items[0].liked, true);
  const photoDeletion = photoOps.api.commentWrite(pin, JSON.stringify({ action: 'delete', id: '401' }));
  assert.deepEqual(options(photoOps.requests[3]), { url: '/v3/did_it/401/', data: { pin: '101' } });
  await photoOps.reply(3, { id: '202' }, 'v3_delete_user_did_it_data'); await photoOps.reply(4, []); await photoDeletion;
  assert.equal(photoOps.api.commentsRead(pin).items.length, 0);
  const textReplies = harness(); textReplies.api.commentsStart(pin); await textReplies.reply(0, [comment('701')]);
  assert.equal(textReplies.api.commentsRead(pin).items[0].canReply, true);
  assert.equal(await textReplies.api.commentWrite(pin, JSON.stringify({ action: 'reply', id: '999', text: 'child' })), false);
  const child = textReplies.api.commentWrite(pin, JSON.stringify({ action: 'reply', id: '701', text: 'child' }));
  assert.match(textReplies.requests[1].url, /AggregatedCommentReplyResource\/create/);
  assert.deepEqual(options(textReplies.requests[1]), { force: false, objectId: '701', pinId: '101', tags: '[]', text: 'child' });
  await textReplies.reply(1, comment('702', 'child'), 'v3_create_aggregated_comment_reply');
  await textReplies.reply(2, [{ ...comment('701'), comment_count: 1 }]); await child;
  assert.equal(textReplies.api.commentsRead(pin).mutationVersion, 1);
  console.log('comment writes: ownership, create/edit/delete, photo/reply, duplicate, uncertain and stale checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
