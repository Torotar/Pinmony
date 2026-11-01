const assert = require('node:assert/strict');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const ts = require(process.argv[2] || 'typescript');
const loader = createArktsLoader(ts, {
  common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } },
  '@kit.RemoteCommunicationKit': { rcp: {} }, '@kit.BasicServicesKit': {}
});
const { PinmonySettingsNativeFlow } = loader.loadFile('entry/src/main/ets/app/PinmonySettingsNativeFlow.ets');
const { PinmonySettingsStore } = loader.loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets');
const { PinmonyNativeNetwork, acceptsNetworkJob } = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const clone = value => JSON.parse(JSON.stringify(value));
function fixture() {
  const origin = 'https://www.pinterest.com', page = origin + '/sample/';
  let session = { authenticated: true, accountId: 'synthetic', generation: 1, origin, userAgent: 'synthetic' };
  const st = new PinmonySettingsStore(); st.screen = 'recommend'; st.recommendationTab = 'boards';
  const board = { id: '300', type: 'board', owner: { id: '1' }, name: 'My board', description: 'Keep this description', privacy: 'secret',
    pin_count: 7, image_cover_url: 'https://i.pinimg.com/synthetic.jpg', last_pinned_to: '2026-10-27T00:00:00Z',
    allow_homefeed_recommendations: true, collaborator_invites_enabled: false, collaborator_requests_enabled: true };
  const state = { board, rows: [board, { ...clone(board), id: '301', owner: { id: '2' } }], next: '-end-', mode: '',
    badRead: false, posts: 0, requests: [], denials: [], hold: undefined, staleReads: 0, previousFlag: true };
  const response = (data, endpoint = 'synthetic') => ({ resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data }, client_context: { user: { id: '1' } } });
  const network = Object.create(PinmonyNativeNetwork.prototype); network.cancel = () => {};
  network.request = async (job, context) => {
    const c = context(); if (!c.authenticated || !acceptsNetworkJob(job, c)) { state.denials.push(job); return { status: 0, error: 'rejected' }; }
    state.requests.push(job);
    const e = JSON.parse(new URLSearchParams(job.method === 'GET' ? job.url.split('?')[1] : job.body).get('data'));
    let body;
    if (job.url.includes('/UserResource/get/')) body = response({ id: '1', type: 'user', username: 'sample' });
    else if (job.url.includes('/BoardsResource/get/')) { if (state.mode === 'readFailed') return { status: 503, error: 'unavailable' }; body = response(clone(state.rows)); body.resource_response.bookmark = state.next; }
    else if (job.url.includes('/BoardResource/get/')) {
      if (state.mode === 'ackReadFailed' && state.posts) return { status: 503, error: 'unavailable' };
      if (state.mode === 'ackReadHold' && state.posts) return new Promise(resolve => { state.hold = () => resolve({ status: 200, body: JSON.stringify(response(clone(state.board), 'v3_get_board')) }); });
      body = response(clone(state.board), 'v3_get_board');
      if (state.staleReads > 0) { state.staleReads--; body.resource_response.data.allow_homefeed_recommendations = state.previousFlag; }
      if (state.badRead) delete body.resource_response.data.collaborator_requests_enabled;
    } else if (job.url.includes('/BoardResource/update/')) {
      state.posts++; state.lastUpdate = e.options;
      if (state.mode === 'reject') body = { resource_response: { status: 'failure', code: 42, data: null } };
      else {
        state.previousFlag = state.board.allow_homefeed_recommendations;
        if (state.mode !== 'unchanged') state.board.allow_homefeed_recommendations = e.options.allow_homefeed_recommendations;
        if (state.mode === 'delayed') state.staleReads = 2;
        if (state.mode === 'ackStale') state.staleReads = 20;
        body = response(clone(state.board), state.mode === 'wrong' ? 'wrong' : 'v3_edit_board');
        if (['delayed', 'noUpdateFlag'].includes(state.mode)) delete body.resource_response.data.allow_homefeed_recommendations;
        if (state.mode === 'hold') return new Promise(resolve => { state.hold = () => resolve({ status: 200, body: JSON.stringify(body) }); });
      }
    } else throw Error('Unexpected request');
    return { status: 200, body: JSON.stringify(body) };
  };
  const flow = new PinmonySettingsNativeFlow({ store: () => st, active: () => true, page: () => page, session: () => session, network: () => network });
  return { st, flow, state, network, session: () => session, account: () => { session = { ...session, generation: 2, accountId: 'other' }; } };
}
const read = f => f.flow.requestAction('recommendBoardsRead', '');
const set = (f, enabled, id = '300') => f.flow.requestAction('recommendBoardSet', JSON.stringify({ id, enabled }));
async function main() {
  const f = fixture(); await read(f);
  assert.equal(f.state.denials.length, 0); assert.equal(f.st.recommendationBoards.length, 1);
  assert.equal(f.st.recommendationBoards[0].enabled, true); assert.equal(f.st.recommendationBoards[0].pinCount, 7);
  await set(f, false); assert.equal(f.state.posts, 1); assert.equal(f.st.recommendationBoards[0].enabled, false);
  assert.deepEqual(f.state.lastUpdate, { board_id: '300', name: 'My board', description: 'Keep this description', privacy: 'secret',
    allow_homefeed_recommendations: false, collaborator_invites_enabled: false, collaborator_requests_enabled: true, sensitivity: null });
  const write = f.state.requests.find(job => job.url.includes('/BoardResource/update/'));
  const form = new URLSearchParams(write.body), envelope = JSON.parse(form.get('data'));
  const original = clone(envelope.options); envelope.options.privacy = 'public'; form.set('data', JSON.stringify(envelope));
  await f.network.requestBusinessProfileSettings({ ...write, body: form.toString() }, f.session, write.page, '1', '1',
    ['recommend-board:300', 'recommend-board-update:' + JSON.stringify(original)], ['own'], () => true);
  assert.equal(f.state.denials.length, 1, 'transport refuses changing unrelated fields');
  await f.network.requestBusinessProfileSettings(write, f.session, write.page, '1', '1', [], ['own'], () => true);
  assert.equal(f.state.denials.length, 2, 'transport refuses a board outside the loaded selection');
  await set(f, false); assert.equal(f.state.posts, 1, 'no redundant write');
  await set(f, true, '301'); assert.equal(f.state.posts, 1, 'foreign board cannot write');
  await read(f); f.state.board.owner.id = '2'; await set(f, true); assert.equal(f.state.posts, 1, 'ownership revalidated before write');
  const partial = fixture(); partial.state.badRead = true; await read(partial);
  assert.equal(partial.st.recommendationBoards[0].enabled, undefined); await set(partial, false); assert.equal(partial.state.posts, 0);
  const failed = fixture(); failed.state.mode = 'readFailed'; await read(failed); assert(failed.st.error); assert.equal(failed.st.recommendationBoardsReady, false);
  const archived = fixture(); archived.state.rows[0].is_archived = true; await read(archived); assert.equal(archived.st.recommendationBoards.length, 0);
  const nativeArchived = fixture(); nativeArchived.state.rows[0].archived_by_me_at = '2026-10-29T00:00:00Z'; await read(nativeArchived); assert.equal(nativeArchived.st.recommendationBoards.length, 0);
  const paging = fixture(); paging.state.next = 'next'; await read(paging); await paging.flow.requestAction('recommendBoardsMore', '');
  assert.equal(paging.st.recommendationBoards.length, 1); assert.equal(paging.st.recommendationBoardCursor, '', 'repeated cursor stops');
  const rejected = fixture(); await read(rejected); rejected.state.mode = 'reject'; await set(rejected, false);
  assert.equal(rejected.st.writeUncertain, false); assert.equal(rejected.st.recommendationBoards[0].enabled, true);
  const unknown = fixture(); await read(unknown); unknown.state.mode = 'wrong'; await set(unknown, false);
  assert.equal(unknown.st.writeUncertain, true); assert.equal(unknown.st.recommendationBoards[0].enabled, true);
  await set(unknown, false); assert.equal(unknown.state.posts, 1, 'unknown writes never replay');
  unknown.state.mode = ''; await read(unknown); assert.equal(unknown.st.writeUncertain, false); assert.equal(unknown.st.recommendationBoards[0].enabled, false);
  const acknowledged = fixture(); await read(acknowledged); acknowledged.state.mode = 'ackStale'; await set(acknowledged, false);
  assert.equal(acknowledged.st.writeUncertain, false, 'a stale GET cannot undo a matching, validated update response');
  assert.equal(acknowledged.st.recommendationBoards[0].enabled, false); assert.equal(acknowledged.st.error, ''); assert.equal(acknowledged.state.posts, 1);
  const delayed = fixture(); await read(delayed); delayed.state.mode = 'delayed'; await set(delayed, false);
  assert.equal(delayed.st.recommendationBoards[0].enabled, false); assert.equal(delayed.st.writeUncertain, false); assert.equal(delayed.state.posts, 1, 'settling only rereads GET');
  const missingUpdateFlag = fixture(); await read(missingUpdateFlag); missingUpdateFlag.state.mode = 'noUpdateFlag'; await set(missingUpdateFlag, false);
  assert.equal(missingUpdateFlag.st.writeUncertain, false, 'GET can confirm a response with no explicit flag');
  const readFailure = fixture(); await read(readFailure); readFailure.state.mode = 'ackReadFailed'; await set(readFailure, false);
  assert.equal(readFailure.st.writeUncertain, false); assert.equal(readFailure.st.recommendationBoards[0].enabled, false, 'a failed GET does not invalidate confirmed write data');
  const unchanged = fixture(); await read(unchanged); unchanged.state.mode = 'unchanged'; await set(unchanged, false);
  assert.equal(unchanged.st.writeUncertain, true); assert.equal(unchanged.st.recommendationBoards[0].enabled, true); assert.equal(unchanged.state.posts, 1, 'HTTP success without a confirmed flag never claims success');
  await set(unchanged, false); assert.equal(unchanged.state.posts, 1, 'unconfirmed write remains locked');
  const paused = fixture(); await read(paused); paused.state.mode = 'hold'; const pending = set(paused, false);
  for (let i = 0; i < 20 && !paused.state.hold; i++) await new Promise(resolve => setImmediate(resolve));
  assert(paused.state.hold); paused.flow.pause(); paused.state.hold(); await pending;
  assert.equal(paused.st.writeUncertain, true); assert.equal(paused.st.recommendationBoards[0].enabled, true, 'late response cannot commit');
  const settling = fixture(); await read(settling); settling.state.mode = 'delayed'; const settlingWrite = set(settling, false);
  for (let i = 0; i < 30 && !settling.state.staleReads; i++) await new Promise(resolve => setImmediate(resolve));
  assert(settling.state.staleReads); settling.flow.pause(); await settlingWrite;
  assert.equal(settling.st.recommendationBoards[0].enabled, true); assert.equal(settling.state.posts, 1, 'pause during settlement never writes again or commits late');
  const confirmedPause = fixture(); await read(confirmedPause); confirmedPause.state.mode = 'ackReadHold'; const confirmedWrite = set(confirmedPause, false);
  for (let i = 0; i < 30 && !confirmedPause.state.hold; i++) await new Promise(resolve => setImmediate(resolve));
  assert(confirmedPause.state.hold); assert.equal(confirmedPause.st.recommendationBoards[0].enabled, false, 'publish a confirmed update without waiting for another GET');
  confirmedPause.flow.pause(); confirmedPause.state.hold(); await confirmedWrite;
  assert.equal(confirmedPause.st.writeUncertain, false, 'backgrounding cannot turn a confirmed update back into unknown');
  const switched = fixture(); await read(switched); switched.account(); await set(switched, false); assert.equal(switched.state.posts, 0, 'session change clears old selections');
  f.st.reset(); assert.equal(f.st.recommendationBoards.length, 0); assert.equal(f.st.recommendationBoardsReady, false);
  console.log('Recommendation boards: list, full edit preservation, ownership, pagination, unavailable, rejected, uncertain, cancellation and session checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
