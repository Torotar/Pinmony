const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function script(path) {
  const source = readSourceFileSync(path, 'utf8');
  const result = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
  new Function(result); return result;
}
const base = script('entry/src/main/ets/services/PinWebPostApiScript.ets');
const extension = script('entry/src/main/ets/services/PinWebPostExtensionsScript.ets');
const requests = [], events = [];
const pin = 'https://www.pinterest.com/pin/101/';
const raw = { id: '101', tracking_params: 'runtime-only' };
const relay = { data: { v3GetPinQueryv2: { data: { entityId: '101', aggregatedPinData: { entityId: '202' } } } } };
const window = { PinWebPostApiEnabled: true, PinWebPostExtensionsEnabled: true, PinWebProfileOrganizeEnabled: true,
  PinWebDetailApi: { raw: () => raw }, PinWebShareBridge: { postState: value => events.push(JSON.parse(value)) } };
window.top = window;
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/pin/101/', href: pin };
const document = { cookie: 'csrftoken=current', querySelectorAll: () => [{ textContent:
  'window.__PWS_RELAY_REGISTER_COMPLETED_REQUEST__("%7B%7D",' + JSON.stringify(relay) + ');' }] };
class XHR { open() {} send() {} setRequestHeader() {} addEventListener() {} }
window.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }));
const context = { window, location, document, URL, URLSearchParams, Headers, AbortController, XMLHttpRequest: XHR,
  btoa: value => Buffer.from(value).toString('base64'),
  fetch: (...args) => window.fetch(...args), setTimeout, clearTimeout, console };
vm.runInNewContext(base, context); vm.runInNewContext(extension, context);
// Supply current-document metadata through the same XHR observer as the website.
const bootstrap = new XHR();
bootstrap.open('GET', '/resource/PinResource/get/?source_url=%2Fpin%2F101%2F');
bootstrap.setRequestHeader('X-App-Version', 'synthetic-current');
bootstrap.setRequestHeader('X-Pinterest-Pws-Handler', 'www/pin/[id].js');
bootstrap.send();
const api = window.PinWebPostApi;
const flush = () => new Promise(resolve => setImmediate(resolve));
function options(index) {
  const request = requests[index];
  return JSON.parse(new URLSearchParams(request.options.body || new URL(request.url, pin).search).get('data')).options;
}
async function respond(index, data, endpoint = '', bookmark = '-end-', extra = {}) {
  const json = { resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data },
    resource: { options: { bookmarks: [bookmark] } }, ...extra };
  requests[index].resolve({ ok: true, json: async () => json }); await flush();
}
const comment = (id, text = 'text') => ({ id, type: 'aggregatedcomment', text,
  reaction_counts: { 1: 2 }, reaction_by_me: 0, user: { full_name: 'Reader' }, comment_count: 1 });
async function main() {
  api.commentsStart(pin);
  assert.equal(options(0).aggregated_pin_id, '202', 'Relay entity ID is used rather than URL Pin ID');
  await respond(0, [comment('301'), { id: '302', type: 'userdiditdata', details: '', images: [
    { originals: { url: 'https://i.pinimg.com/photo.jpg' } }], user: {}, like_count: 1 }], '', 'next');
  assert.equal(api.commentsRead(pin).items[1].imageUrl, 'https://i.pinimg.com/photo.jpg');
  assert.equal(api.commentsRead(pin).items[1].canLike, true);
  api.commentsMore(pin); api.commentsMore(pin);
  assert.equal(requests.length, 2); assert.equal(options(1).bookmarks[0], 'next');
  requests[1].resolve({ ok: false, json: async () => ({ resource_response: { status: 'failure', message: 'retry' } }) }); await flush();
  assert.equal(api.commentsRead(pin).items.length, 2);
  api.commentsMore(pin); await respond(2, [comment('301'), comment('303')]);
  assert.equal(api.commentsRead(pin).items.length, 3); assert.equal(api.commentsRead(pin).ended, true);
  api.commentsMore(pin); assert.equal(requests.length, 3);
  api.commentReplies(pin, '301');
  assert.equal(options(3).objectId, '301'); await respond(3, [comment('401')], 'v3_get_aggregated_comment_replies');
  assert.equal(api.commentsRead(pin).items[0].replies[0].id, '401');
  const beforeFold = requests.length;
  await api.commentReplies(pin, '301');
  assert.equal(api.commentsRead(pin).items[0].repliesOpen, false);
  await api.commentReplies(pin, '301');
  assert.equal(api.commentsRead(pin).items[0].repliesOpen, true);
  assert.equal(api.commentsRead(pin).items[0].replies[0].id, '401');
  assert.equal(requests.length, beforeFold, 'Reopening loaded replies uses the current sheet cache');
  api.commentLike(pin, '301'); api.commentLike(pin, '301'); assert.equal(requests.length, 5);
  assert.match(requests[4].url, /ApiResource\/create/);
  assert.equal(options(4).url, '/v3/aggregated_comments/301/react/');
  await respond(4, { id: '301' }, 'v3_add_reaction_to_comment');
  assert.equal(api.commentsRead(pin).items[0].liked, false, 'No optimistic count/state before refresh');
  await respond(5, [{ ...comment('301'), reaction_by_me: 1, reaction_counts: { 1: 3 } }]);
  assert.equal(api.commentsRead(pin).items[0].liked, true);
  api.commentLike(pin, '301'); assert.match(requests[6].url, /ApiResource\/delete/);
  await respond(6, { id: '301' }, 'v3_delete_reaction_from_comment'); await respond(7, [comment('301')]);
  api.commentsClose(); api.commentsStart(pin); api.commentsClose(); await respond(8, [comment('999')]);
  assert.equal(api.commentsRead(pin), null, 'Closed panel ignores late comments');
  assert.equal(api.previewRead(pin, true), null, 'Snapshot reads must not start preview requests');
  api.previewRead(pin); assert.equal(options(9).aggregated_pin_id, '202');
  await respond(9, [{ unified_comment: { text: 'preview' } }]); assert.equal(api.previewRead(pin).text, 'preview');
  api.boardsStart(pin); await respond(10, { id: '101', tracking_params: 'current-pin' }, '', '',
    { client_context: { user: { id: '77' } } });
  assert.equal(options(11).user_id, '77');
  const board = { id: '501', name: 'Landscape', access: ['write'], privacy: 'public' };
  await respond(11, { all_boards: [board], boards_shortlist: [board] });
  assert.equal(requests[12].url, '/_/graphql/');
  requests[12].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: { id: Buffer.from('Pin:101').toString('base64'), boardTitleSuggestions: [{ title: 'Travel' }] } } } }) }); await flush();
  assert.equal(api.boardsRead(pin).suggestions[0], 'Travel');
  api.boardsCreate(pin, 'Secret', true); api.boardsCreate(pin, 'Secret', true);
  assert.equal(requests.length, 14); assert.equal(options(13).privacy, 'secret');
  await respond(13, { id: '502', name: 'Secret', access: ['write'], privacy: 'secret' }, 'v3_create_board');
  assert.equal(api.boardsRead(pin).items.length, 3);
  api.boardsSave(pin, '501'); api.boardsSave(pin, '501'); assert.equal(requests.length, 15);
  assert.equal(options(14).pin_id, '101'); assert.equal(options(14).board_id, '502', 'Creation automatically saves to the returned board');
  assert.equal(api.boardsRead(pin).savedId, '', 'Creating a board is not proof of saving');
  await respond(14, { id: '801', board: { id: '502' } }, 'v3_repin_handler');
  api.boardsRemove(pin); assert.equal(options(15).id, '801', 'Only the returned saved copy ID is deleted');
  await respond(15, null, 'v3_delete_pin_handler'); assert.equal(api.boardsRead(pin).savedId, '');
  assert.equal(await api.boardsRemove(pin), false);
  api.boardsCreate(pin, 'Landscape', false);
  requests[16].resolve({ ok: false, json: async () => ({ resource_response: { status: 'failure', message: 'Duplicate name' } }) }); await flush();
  assert.equal(api.boardsRead(pin).error, 'Duplicate name');
  api.feedbackRecord(pin, 9);
  const eventCount = events.length;
  assert.equal(api.feedbackUndo(pin, 8), false);
  assert.equal(api.feedbackUndo(pin, 9), true);
  assert.equal(api.feedbackUndo(pin, 9), false);
  assert.equal(events.length, eventCount, 'Dispatch does not report undo success');
  assert.equal(options(17).url, '/v3/pin/101/feedback/see_more/undo/');
  await respond(17, { id: '101' }, 'v3_pin_see_more_undo_user_feedback');
  assert.equal(events.at(-1).kind, 'feedbackUndone');
  api.boardsStart(pin); api.boardsClose(); await respond(18, { id: '101' });
  assert.equal(requests.length, 19, 'Closed board panel does not launch a late list request');
  api.boardsStart(pin);
  await respond(19, { id: '101', tracking_params: 'current-pin' }, '', '', { client_context: { user: { id: '77' } } });
  await respond(20, { all_boards: [board], boards_shortlist: [] });
  requests[21].resolve({ ok: true, json: async () => ({ data: { v3GetPinQueryv2: { data: { id: Buffer.from('Pin:101').toString('base64'), boardTitleSuggestions: [] } } } }) }); await flush();
  assert.equal(api.boardsRead(pin).items.at(-1).name, '个人资料');
  api.boardsSave(pin, 'profile-quick-saves');
  assert.equal(options(22).board_id, undefined, 'Quick save omits board_id as captured');
  assert.equal(options(22).user_id, '77');
  await respond(22, { id: '802', board: { id: '503', layout: 'quick_saves' }, pinner: { id: '77' } }, 'v3_repin_handler');
  assert.equal(api.boardsRead(pin).savedBoard, '个人资料');
  assert.equal(api.boardsRead(pin).savedId, '802');
  api.boardsSave(pin, 'profile-quick-saves');
  await respond(23, { id: '803', board: { id: '501' }, pinner: { id: '77' } }, 'v3_repin_handler');
  assert.equal(api.boardsRead(pin).savedId, '802', 'Wrong quick-save layout never reports success');
  assert.ok(api.boardsRead(pin).error);
  api.boardsClose();
  assert.equal(api.saveUndo(pin, '101'), false, 'Original Pin ID cannot be deleted by the snackbar');
  const beforeUndo = events.length;
  assert.equal(api.saveUndo(pin, '802'), true, 'Undo works after the board sheet has closed');
  assert.equal(api.saveUndo(pin, '802'), false, 'Duplicate undo writes are locked');
  assert.equal(options(24).id, '802');
  assert.equal(events.length, beforeUndo, 'Dispatch cannot report a successful undo');
  requests[24].resolve({ ok: false, json: async () => ({ resource_response: { status: 'failure', message: 'Retry undo' } }) }); await flush();
  assert.equal(events.at(-1).kind, 'saveUndoError');
  assert.equal(api.savedRead(pin).id, '802', 'Failed undo preserves the returned saved-copy ID');
  assert.equal(api.saveUndo(pin, '802'), true);
  await respond(25, null, 'v3_delete_pin_handler');
  assert.equal(events.at(-1).kind, 'saveUndone');
  assert.equal(events.at(-1).objectId, '802');
  assert.equal(api.savedRead(pin).id, '');
  assert.equal(api.saveUndo(pin, '802'), false);
  location.pathname = '/pin/999/'; assert.equal(api.boardsStart(pin), false);
  assert.equal(await api.commentLike(pin, '301'), false);
  console.log('post extensions: Relay ID, preview, comments/photos/pagination/retry/replies/reactions, boards/create/save/delete, undo and stale guards OK');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
