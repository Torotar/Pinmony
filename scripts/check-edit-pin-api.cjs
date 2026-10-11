const { readSourceFileSync } = require('./source-files.cjs');
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = readSourceFileSync('entry/src/main/ets/services/PinmonyEditPinApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
const pin = 'https://www.pinterest.com/pin/101/';
const raw = { id: '101', pinner: { id: '1' }, is_repin: false, title: 'original title', description: '  original description  ', images: {} };
const graphPin = { entityId: '101', pinner: { entityId: '1' }, board: { entityId: '2', name: 'old board' },
  section: { entityId: '8' }, aiDisclosures: [9], trackingParams: 'runtime-track', images: { url: 'https://i.pinimg.com/a.jpg' } };
function harness(overrides = {}) {
  let current = pin; const requests = []; let picker = null;
  const api = { reset() {}, currentPin: p => p === current, sessionUserId: () => '1', boardsClose() { picker = null; },
    boardsStart() { picker = { pin, loading: false, busy: false, items: [{ id: '3', name: 'new board', enabled: true },
      { id: 'profile-quick-saves', enabled: true }], shortlist: [], suggestions: [] }; }, boardsRead: () => picker,
    resourceRequest: (p, name, op, options, valid, query) => new Promise((resolve, reject) => requests.push({
      name, op, options, query, resolve: result => valid() && p === current ? resolve(result) : reject(new Error('stale')), reject })) };
  const window = { PinmonyPostApi: api, PinmonyEditApiEnabled: true }; window.top = window;
  vm.runInNewContext(script, { window });
  async function load(r = raw, g = graphPin) {
    const start = api.editStart(pin); const request = requests.at(-1); request.resolve({ data: r });
    await new Promise(resolve => setImmediate(resolve));
    if (requests.at(-1).query) requests.at(-1).resolve({ v3GetPinQueryv2: { data: g } });
    await start;
  }
  return { api, requests, load, move: p => current = p };
}
async function main() {
  const h = harness(); await h.load();
  assert.equal(h.api.editRead(pin).ai, false);
  assert.equal(h.api.editRead(pin).title, raw.title);
  assert.equal(h.api.editRead(pin).description, raw.description);
  assert.equal(h.api.editRead(pin).editableContent, true);
  h.api.editAi(pin, true);
  const commit = h.api.editCommit(pin, false);
  assert.equal(await h.api.editCommit(pin, false), false, 'duplicate write blocked');
  assert.equal(h.api.editClose(), false, 'cannot close pending write');
  const save = h.requests.at(-1);
  assert.equal(save.options.title, raw.title); assert.equal(save.options.description, raw.description);
  assert.equal(save.options.board_section_id, '8'); assert.deepEqual(Array.from(save.options.ai_disclosures), [9, 1]);
  save.resolve({ code: 0, endpoint_name: 'v3_edit_pin', data: { id: '101', board: { id: '2' }, ai_disclosures: [9, 1] } });
  await commit; assert.equal(h.api.editRead(pin).done, 'saved');
  assert.equal(await h.api.editCommit(pin, false), false, 'completed write cannot replay');
  const edited = harness(); await edited.load();
  assert.equal(edited.api.editText(pin, 'title', '草稿标题'), true);
  assert.equal(edited.api.editText(pin, 'description', '第一行\n第二行'), true);
  assert.equal(edited.api.editText(pin, 'board', 'invalid'), false, 'only text fields accepted');
  assert.equal(edited.api.editText(pin, 'title', 'x'.repeat(10001)), false, 'draft bridge is bounded');
  assert.equal(edited.api.editText('https://www.pinterest.com/pin/999/', 'title', 'wrong Pin'), false);
  edited.api.editPhase(pin, 'boards'); edited.api.editSelect(pin, '3');
  assert.equal(edited.api.editRead(pin).description, '第一行\n第二行', 'board picker retains drafts');
  const edit = edited.api.editCommit(pin, false, '', '最终描述\n保留换行');
  const editRequest = edited.requests.at(-1);
  assert.equal(editRequest.options.title, '', 'title can be cleared');
  assert.equal(editRequest.options.description, '最终描述\n保留换行', 'commit carries the latest draft');
  assert.equal(edited.api.editText(pin, 'title', 'busy'), false);
  editRequest.resolve({ code: 0, endpoint_name: 'v3_edit_pin', data: { id: '101', board: { id: '3' },
    ai_disclosures: [9], title: '', description: '最终描述\n保留换行' } });
  await edit; assert.equal(edited.api.editRead(pin).done, 'saved');
  const mismatch = harness(); await mismatch.load();
  const mismatchCommit = mismatch.api.editCommit(pin, false, 'new title', '');
  mismatch.requests.at(-1).resolve({ code: 0, endpoint_name: 'v3_edit_pin', data: { id: '101', board: { id: '2' },
    ai_disclosures: [9], title: raw.title, description: raw.description } });
  await mismatchCommit;
  assert.equal(mismatch.api.editRead(pin).done, '', 'mismatched text cannot report success');
  assert.equal(mismatch.api.editRead(pin).uncertain, true);
  assert.equal(await mismatch.api.editCommit(pin, false), false, 'text mismatch cannot replay');
  const resetDraft = harness(); await resetDraft.load(); resetDraft.api.editText(pin, 'description', 'discard');
  resetDraft.api.editClose(); await resetDraft.load();
  assert.equal(resetDraft.api.editRead(pin).description, raw.description, 'reopening reads current source');
  const moved = harness(); await moved.load(); moved.api.editPhase(pin, 'boards');
  assert.equal(moved.api.editRead(pin).picker.items.length, 1, 'quick-save pseudo board excluded from edit picker');
  assert.equal(moved.api.editSelect(pin, 'profile-quick-saves'), false);
  assert.equal(moved.api.editSelect(pin, '3'), true);
  const move = moved.api.editCommit(pin, false); const moveRequest = moved.requests.at(-1);
  assert.equal(moveRequest.options.board_id, '3'); assert.equal(moveRequest.options.board_section_id, '');
  moveRequest.reject(new Error('network lost')); await move;
  assert.equal(moved.api.editRead(pin).uncertain, true);
  assert.equal(await moved.api.editCommit(pin, false), false, 'uncertain write requires reread');
  const deleted = harness(); await deleted.load();
  assert.equal(await deleted.api.editCommit(pin, true), false, 'deletion requires explicit confirmation phase');
  deleted.api.editPhase(pin, 'confirm'); const remove = deleted.api.editCommit(pin, true);
  const del = deleted.requests.at(-1); assert.equal(del.op, 'delete'); assert.equal(del.options.id, '101');
  assert.equal(del.options.client_tracking_params, 'runtime-track~0');
  del.resolve({ code: 0, endpoint_name: 'v3_delete_pin_handler', data: null }); await remove;
  assert.equal(deleted.api.editRead(pin).done, 'deleted');
  const repin = harness(); await repin.load({ ...raw, is_repin: true });
  assert.equal(repin.api.editRead(pin).editableContent, false);
  const repinCommit = repin.api.editCommit(pin, false, 'must-not-send', 'must-not-send');
  const repinRequest = repin.requests.at(-1);
  assert.equal(Object.prototype.hasOwnProperty.call(repinRequest.options, 'title'), false);
  assert.equal(Object.prototype.hasOwnProperty.call(repinRequest.options, 'description'), false);
  repinRequest.resolve({ code: 0, endpoint_name: 'v3_edit_pin', data: { id: '101', board: { id: '2' }, ai_disclosures: [9] } });
  await repinCommit;
  const other = harness(); await other.load({ ...raw, pinner: { id: '99' } });
  assert.match(other.api.editRead(pin).error, /当前账号/); assert.equal(other.requests.length, 1);
  const stale = harness(); const load = stale.api.editStart(pin); stale.move('https://www.pinterest.com/pin/999/');
  stale.requests[0].resolve({ data: raw }); await load; assert.equal(stale.api.editRead(pin), null);
  console.log('Edit Pin: text drafts, latest commit, clearing, multiline, response validation, ownership, field preservation, board selection, AI metadata, confirmation, duplicate and uncertain-write guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
