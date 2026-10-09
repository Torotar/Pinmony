const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('feature_board/src/main/ets/services/PinWebBoardApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
const board = { type: 'board', id: '123', url: '/sample/board/', name: 'Board', pin_count: 1,
  owner: { id: '700', username: 'sample' } };
const pin = id => ({ type: 'pin', id, images: { '736x': { url: 'https://i.pinimg.com/test.jpg', width: 736, height: 900 } } });
function harness(pinIds = ['111']) {
  const requests = [], messages = [];
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/sample/board/' };
  const initial = { initialReduxState: { session: { user: { id: '700' } }, boards: { 123: board },
    resources: { BoardFeedResource: { [JSON.stringify([['board_id','123'],['field_set_key','react_grid_pin']])]:
      { fetching: false, data: pinIds.map(id => ({ ...pin(id), board: { id: '123' } })), nextBookmark: '-end-' } } } } };
  const window = { PinWebBoardApiEnabled: true, addEventListener() {}, setInterval() {},
    PinWebShareBridge: { boardState: value => messages.push(JSON.parse(value)) } }; window.top = window;
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout,
    document: { readyState: 'complete', getElementById: () => ({ textContent: JSON.stringify(initial) }) },
    fetch: (url, init) => new Promise(resolve => requests.push({ url, init, resolve })) });
  const state = () => messages.at(-1);
  const act = (action, value) => window.PinWebBoardApi.flow(state().session, state().pageKey, JSON.stringify({ action, value }));
  const respond = async (index, data, endpoint, code = 0) => {
    requests[index].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data,
      code, endpoint_name: endpoint }, client_context: { user: { id: '700' } } }) }); await flush();
  };
  return { requests, state, act, respond, window, location };
}
async function main() {
  if (process.argv[2]) {
    const ts = require(process.argv[2]), exports = {};
    vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_network/src/main/ets/PinWebNativeNetwork.ets','utf8'),
      { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText,
      { exports, require: () => ({}) });
    const context = { authenticated: true, epoch: 1, page: 'https://www.pinterest.com/sample/board/', userAgent: '' };
    const job = { id: 'test', epoch: 1, page: context.page, url: 'https://www.pinterest.com/resource/BoardResource/update/',
      method: 'POST', headers: {}, body: '' };
    assert.equal(exports.acceptsNetworkJob(job,context), true, 'board editing admitted by native transport');
    assert.equal(exports.acceptsNetworkJob({...job, url: job.url.replace('update','delete')}, context), false,
      'unrequested board deletion stays excluded');
    assert.equal(exports.acceptsNetworkJob({...job,method:'GET'},context), false);
  }
  const h = harness(); await flush(); assert.equal(h.state().editable, true);
  h.act('select'); assert.equal(h.state().flow.phase, 'select'); assert.equal(h.requests.length, 0);
  h.act('targets', ['111']); assert(h.requests[0].url.includes('/BoardsResource/get/'));
  await h.respond(0, [{ ...board, image_cover_url: 'https://i.pinimg.com/cover.jpg' }]);
  const count = h.requests.length; h.act('move', '123'); await flush();
  assert.equal(h.requests.length, count, 'source board cannot be a move destination');
  h.act('close'); h.act('ideas'); await h.respond(1, [pin('222')]);
  h.act('save', '999'); assert.equal(h.requests.length, 2, 'unknown Pin rejected');
  h.act('save', '222'); h.act('save', '222'); assert.equal(h.requests.length, 3, 'write locked');
  const options = JSON.parse(new URLSearchParams(h.requests[2].init.body).get('data')).options;
  assert.equal(options.board_id, '123'); assert.equal(options.pin_id, '222'); assert.equal(options.user_id, '700');
  assert.equal(h.requests[2].init.method, 'POST'); assert.equal(h.requests[2].init.headers.Cookie, undefined);
  await h.respond(2, { id: '333', board: { id: '123' }, pinner: { id: '700' }, is_repin: true }, 'v3_repin_handler');
  assert.deepEqual(Array.from(h.state().flow.saved), ['222']);
  h.act('save', '222'); assert.equal(h.requests.length, 3, 'confirmed save cannot duplicate');
  h.act('close'); h.act('archiveConfirm'); h.act('archive');
  assert.equal(JSON.parse(new URLSearchParams(h.requests[3].init.body).get('data')).options.url, '/v3/boards/123/archive/');
  await h.respond(3, null, 'wrong-endpoint'); assert.equal(h.state().flow.uncertain, true);
  h.act('archive'); assert.equal(h.requests.length, 4, 'unknown result cannot replay');
  const editing = harness(); await flush(); editing.act('edit');
  assert.equal(JSON.parse(new URL(editing.requests[0].url, editing.location.origin).searchParams.get('data')).options.field_set_key, 'edit');
  await editing.respond(0, { ...board, description: 'Description', privacy: 'public' });
  editing.act('editSave', { name: 'Updated', description: 'New', privacy: 'public', recommend: false, invites: false, requests: false });
  await editing.respond(1, { ...board, name: 'Updated', privacy: 'public' }, 'v3_edit_board');
  assert.equal(editing.state().title, 'Updated'); assert.equal(editing.state().flow.phase, '');
  const deleting = harness(); await flush(); deleting.act('edit');
  await deleting.respond(0, board);
  deleting.act('delete'); deleting.act('delete');
  assert.equal(deleting.requests.length, 2, 'delete cannot submit twice');
  const deletion = deleting.requests[1];
  assert.match(deletion.url, /BoardResource\/delete\//);
  const deletionBody = new URLSearchParams(deletion.init.body);
  assert.deepEqual(JSON.parse(deletionBody.get('data')).options, { board_id: '123' });
  assert.equal(deletionBody.get('source_url'), '/board/123/edit/');
  assert.equal(deletion.init.headers['X-Pinterest-Pws-Handler'], 'www/board/[id]/edit.js');
  await deleting.respond(1, null, 'v3_delete_board');
  assert.equal(deleting.state().flow.phase, 'deleted');
  assert.equal(deleting.state().pins.length, 0);
  const failedDelete = harness(); await flush(); failedDelete.act('edit'); await failedDelete.respond(0, board);
  failedDelete.act('delete'); await failedDelete.respond(1, {}, 'v3_delete_board');
  assert.equal(failedDelete.state().flow.uncertain, true);
  failedDelete.act('delete'); assert.equal(failedDelete.requests.length, 2, 'unknown deletion cannot replay');
  const stale = harness(); await flush(); stale.act('ideas'); stale.act('close');
  await stale.respond(0, [pin('444')]); assert.equal(stale.state().flow.phase, ''); assert.equal(stale.state().flow.pins.length, 0);
  assert.equal(stale.window.PinWebBoardApi.flow(-1, stale.state().pageKey, '{"action":"archive"}'), false);
  for (const ids of [['111'], ['111','112','113']]) {
    const moving = harness(ids); await flush(); moving.act('select');
    assert.equal(moving.act('targets', ['999']), false, 'unknown selection rejected');
    assert.equal(moving.act('targets', ['111','111']), false, 'duplicate selection rejected');
    moving.act('targets', ids);
    await moving.respond(0, [{ ...board, id:'456', access:['write'] },
      { ...board, id:'789', access:['write'], archived_by_me_at:'synthetic' }, { ...board, id:'999', access:[] }]);
    moving.act('move','789'); moving.act('move','999'); assert.equal(moving.requests.length,1);
    moving.act('move','456'); moving.act('move','456'); assert.equal(moving.requests.length,2);
    const body = new URLSearchParams(moving.requests[1].init.body);
    assert.deepEqual(JSON.parse(body.get('data')).options, {url:'/v3/pins/bulk/move/',data:{board_id:'456',pin_ids:ids}});
    assert.equal(body.get('source_url'),'/board/123/organize/repin/');
    assert.equal(moving.requests[1].init.headers['X-Pinterest-Pws-Handler'],'www/board/[id]/organize.js');
    await moving.respond(1,null,'v3_move_pins');
    assert.equal(moving.state().flow.phase,''); assert.equal(moving.state().pins.length,0);
    await moving.respond(2,{...board,pin_count:0}); await moving.respond(3,[]);
    assert.equal(moving.state().ready,true);
  }
  const uncertain = harness(); await flush(); uncertain.act('select'); uncertain.act('targets',['111']);
  await uncertain.respond(0,[{...board,id:'456',access:['write']}]); uncertain.act('move','456');
  await uncertain.respond(1,null,'wrong-endpoint');
  assert.equal(uncertain.state().flow.uncertain,true); assert.equal(uncertain.state().pins.length,1);
  uncertain.act('move','456'); assert.equal(uncertain.requests.length,2,'unconfirmed move cannot replay');
  const late = harness(); await flush(); late.act('select'); late.act('targets',['111']);
  await late.respond(0,[{...board,id:'456',access:['write']}]); late.act('move','456');
  late.location.pathname='/other/board/'; await late.respond(1,null,'v3_move_pins');
  assert.equal(late.state().pins.length,1,'late move cannot modify another route');
  console.log('Board options, single/bulk move, permissions, write validation and stale response checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
