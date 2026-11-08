const assert = require('node:assert/strict'), fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const loader = require('./arkts-module-loader.cjs').createArktsLoader(ts, {
  common_network: {PIN_BUSINESS_PIN_READ_ENABLED: true}, common_session: {PinmonySessionCredentials: class {}},
  common_foundation: {PinmonyRuntimeLog: {info() {}, warn() {}, error() {}}}, feature_inbox: {},
  '@kit.RemoteCommunicationKit': {rcp: {}}, '@kit.BasicServicesKit': {}
});
const {PinmonyNativeNetwork: Network, acceptsNetworkJob} = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const {PinmonyBoardInvitationNative: Invites} = loader.loadFile('entry/src/main/ets/app/PinmonyBoardInvitationNative.ets');
const origin = 'https://www.pinterest.com', viewer = {id: '41', username: 'viewer'};
const raw = {board: {id: '123', url: '/peer/art/', name: 'Board'}, invited_user: viewer,
  invited_by_user: {id: '42', username: 'peer', full_name: 'Peer'}, status: 'new', created_at: '2026-11-08T00:00:00Z'};
function fixture() {
  let page = origin + '/inbox/', session = {authenticated: true, accountId: 'synthetic', generation: 1, origin}, active = true;
  const jobs = [], cancelled = [], store = {boardInvitationToken: 0};
  const net = Object.create(Network.prototype); net.cancel = id => cancelled.push(id);
  net.request = (job, current) => {
    assert(acceptsNetworkJob(job, current()), 'actual transport general allowlist');
    assert(current().authenticated, 'actual auxiliary allowlist');
    return new Promise(resolve => jobs.push({job, finish: (data, endpoint, extra = {}, status = 'success', code = 0) =>
      resolve({status: 200, error: '', body: JSON.stringify({resource_response: {status, code, endpoint_name: endpoint, data, ...extra}, client_context: {user: viewer}})}),
      response: result => resolve(result)}));
  };
  const native = new Invites({store: () => store, session: () => session, network: () => net, page: () => page,
    active: () => active, username: () => 'viewer', avatar: () => '', feedback() {}});
  return {native, store, jobs, cancelled, changeAccount() {session = {...session, accountId: 'other', generation: 2};},
    board(item) {page = item.boardUrl; store.boardInvitationPreview = item; store.invitationBannerVisible = true;},
    leave() {page = origin + '/other/'; native.pause();}, background() {active = false; native.pause();}};
}
async function loaded() {const f = fixture(), pending = f.native.open(false); f.jobs[0].finish([raw], 'v3_user_board_invites'); await pending; return f;}
const endpoint = 'v3_decline_or_delete_board_collaborator_invite';
async function main() {
  const accepting = await loaded(), acceptedItem = accepting.store.boardInvitations.items[0];
  let acceptingWrite = accepting.native.acceptFromList(acceptedItem);
  await accepting.native.acceptFromList(acceptedItem); await accepting.native.decline(acceptedItem);
  assert.equal(accepting.jobs.length, 2, 'accept and decline share single write gate');
  assert.equal(accepting.store.boardInvitations.items.length, 1, 'accept has no optimistic removal');
  const acceptJob = accepting.jobs[1].job;
  assert.equal(acceptJob.url, origin + '/resource/BoardInviteResource/update/');
  assert.equal(acceptJob.method, 'POST');
  assert.deepEqual(JSON.parse(new URLSearchParams(acceptJob.body).get('data')), {options: {board_id: '123', invited_user_id: '41'}, context: {}});
  accepting.jobs[1].finish({...raw, status: 'accepted'}, 'v3_accept_board_collaborator_invite'); await acceptingWrite;
  assert.equal(accepting.store.boardInvitations.items.length, 0, 'confirmed accept removes only pending row');
  for(const scenario of ['wrong-endpoint','new-status','wrong-board','wrong-user','not-sent','rejected','leave','changeAccount','background']) {
    const x = await loaded(); const chosen = x.store.boardInvitations.items[0];
    const pending = x.native.acceptFromList(chosen);
    if(['leave','changeAccount','background'].includes(scenario))x[scenario]();
    const before = x.store.boardInvitations;
    if(scenario === 'not-sent')x.jobs[1].response({status:0,error:'request-unavailable',body:''});
    else if(scenario === 'rejected')x.jobs[1].finish(null,'v3_accept_board_collaborator_invite',{},'failure',1);
    else x.jobs[1].finish({...raw, status:scenario === 'new-status' ? 'new' : 'accepted',
      board:scenario === 'wrong-board' ? {...raw.board,id:'999'} : raw.board,
      invited_user:scenario === 'wrong-user' ? {id:'999'} : viewer}, scenario === 'wrong-endpoint' ? 'wrong' : 'v3_accept_board_collaborator_invite');
    await pending;
    assert.equal(x.store.boardInvitations.items.length, 1, 'unconfirmed acceptance retains invitation');
    if(['leave','changeAccount','background'].includes(scenario))assert.equal(x.store.boardInvitations,before,'late acceptance ignored');
    else {
      const safe = ['not-sent','rejected'].includes(scenario);
      assert.equal(x.store.boardInvitations.uncertain,!safe);
      if(!safe) {await x.native.acceptFromList(chosen); assert.equal(x.jobs.length,2,'unknown acceptance never replays');}
    }
  }
  const refresh = fixture();
  let read = refresh.native.open(false); await refresh.native.open(false);
  assert.equal(refresh.jobs.length, 1, 'same active read deduplicates');
  assert.equal(refresh.store.invitationReadPage, '', 'inflight is not a completed read');
  refresh.jobs[0].finish([], 'v3_user_board_invites'); await read;
  assert.equal(refresh.store.boardInvitations.items.length, 0);
  read = refresh.native.open(false); refresh.jobs[1].finish([raw], 'v3_user_board_invites'); await read;
  assert.equal(refresh.store.boardInvitations.items.length, 1, 'previous empty result does not suppress a new invitation');
  read = refresh.native.open(false);
  assert.equal(refresh.store.boardInvitations.items.length, 1, 'refresh retains existing rows');
  refresh.jobs[2].finish([], 'wrong'); await read;
  assert.equal(refresh.store.boardInvitations.items.length, 1, 'invalid endpoint cannot clear rows');
  assert.equal(refresh.store.invitationReadPage, '', 'failed reads remain retryable');
  read = refresh.native.open(false); refresh.native.pause(); const cancelled = refresh.store.boardInvitations;
  refresh.jobs[3].finish([], 'v3_user_board_invites'); await read;
  assert.equal(refresh.store.boardInvitations, cancelled, 'cancelled result is discarded');
  assert.equal(refresh.store.invitationReadPage, '');
  read = refresh.native.open(false); refresh.jobs[4].finish([raw], 'v3_user_board_invites'); await read;
  assert.equal(refresh.store.boardInvitations.loading, false, 'read resumes after cancellation');
  refresh.changeAccount(); read = refresh.native.open(false);
  assert.equal(refresh.store.boardInvitations.items.length, 0, 'previous account rows are not retained');
  refresh.jobs[5].finish([], 'v3_user_board_invites'); await read;
  const f = await loaded(), item = f.store.boardInvitations.items[0];
  let pending = f.native.decline(item); await f.native.decline(item);
  assert.equal(f.jobs.length, 2); assert.equal(f.store.boardInvitations.busy, true);
  assert.equal(f.store.boardInvitations.items.length, 1, 'no optimistic success');
  const job = f.jobs[1].job, form = new URLSearchParams(job.body);
  assert.equal(job.method, 'POST'); assert.equal(job.url, origin + '/resource/BoardInviteResource/delete/');
  assert.equal(job.headers['X-Pinterest-Pws-Handler'], 'www/inbox.js'); assert.equal(form.get('source_url'), '/inbox/');
  assert.deepEqual(JSON.parse(form.get('data')), {options: {board_id: '123', invited_user_id: '41'}, context: {}});
  f.jobs[1].finish(raw, endpoint); await pending;
  assert.equal(f.store.boardInvitations.items.length, 0, 'captured success status=new is accepted only with matching endpoint and identities');
  assert.equal(f.store.boardInvitations.busy, false);
  for (const response of [{data: {...raw, board: {...raw.board, id: '999'}}, endpoint}, {data: raw, endpoint: 'wrong'},
    {data: {...raw, invited_user: {id: '99'}}, endpoint}, {data: raw, endpoint, extra: {error: {message: 'failure'}}}]) {
    const x = await loaded(); pending = x.native.decline(x.store.boardInvitations.items[0]);
    x.jobs[1].finish(response.data, response.endpoint, response.extra); await pending;
    assert.equal(x.store.boardInvitations.items.length, 1); assert.equal(x.store.boardInvitations.uncertain, true);
    await x.native.decline(x.store.boardInvitations.items[0]); assert.equal(x.jobs.length, 2, 'unknown writes never replay');
    let read = x.native.open(false); x.jobs[2].finish([raw], 'v3_user_board_invites'); await read;
    assert.equal(x.store.boardInvitations.uncertain, true, 'still-new read cannot authorize replay');
    read = x.native.open(false); x.jobs[3].finish([], 'v3_user_board_invites'); await read;
    assert.equal(x.store.boardInvitations.uncertain, false, 'confirmed absent invite resolves uncertainty');
  }
  for (const failure of ['not-sent', 'rejected']) {
    const x = await loaded(); pending = x.native.decline(x.store.boardInvitations.items[0]);
    if (failure === 'not-sent') x.jobs[1].response({status: 0, error: 'request-unavailable', body: ''});
    else x.jobs[1].finish(null, endpoint, {}, 'failure', 1);
    await pending; assert.equal(x.store.boardInvitations.uncertain, false); assert.equal(x.store.boardInvitations.items.length, 1);
  }
  for (const method of ['leave', 'changeAccount', 'background']) {
    const x = await loaded(); pending = x.native.decline(x.store.boardInvitations.items[0]); x[method]();
    const before = x.store.boardInvitations; x.jobs[1].finish(raw, endpoint); await pending;
    assert.equal(x.store.boardInvitations, before, 'late response cannot update inactive route/account');
  }
  const denied = await loaded(); await denied.native.decline({...denied.store.boardInvitations.items[0], invitedUser: '999'});
  assert.equal(denied.jobs.length, 1, 'wrong viewer denied before write');
  for(const outcome of ['success','wrong','not-sent','late']) {
    const board = await loaded(), selected = board.store.boardInvitations.items[0]; board.board(selected);
    let read = board.native.open(true); board.jobs.at(-1).finish(raw,'v3_get_user_board_invite'); await read;
    const write = board.native.declinePreview(); await board.native.declinePreview();
    assert.equal(board.jobs.length,3,'board card submits at most once'); assert(board.store.invitationBannerVisible,'card remains before confirmation');
    const request=board.jobs.at(-1).job; assert.equal(request.page,origin+'/inbox/');assert.equal(new URLSearchParams(request.body).get('source_url'),'/inbox/');
    if(outcome==='not-sent')board.jobs.at(-1).response({status:0,error:'request-unavailable',body:''});
    else {if(outcome==='late')board.background();board.jobs.at(-1).finish(raw,outcome==='wrong'?'wrong':endpoint);}
    await write;
    assert.equal(board.store.invitationBannerVisible,outcome!=='success','only confirmed live decline removes board card');
    if(outcome==='success'){assert.equal(board.store.boardInvitationPreview,undefined);assert.equal(board.store.boardInvitations.items.length,0);}
    if(outcome==='wrong'){assert(board.store.invitationBusy);await board.native.declinePreview();assert.equal(board.jobs.length,3,'uncertain preview decline is never replayed');}
    if(outcome==='not-sent')assert.equal(board.store.invitationBusy,false);
  }
  const page = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', 'utf8');
  const root = fs.readFileSync('entry/src/main/ets/components/PinmonyInboxRootContent.ets', 'utf8');
  const host = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert(page.includes('onAccept: this.onInvitationAccept'));
  assert(root.includes('view.acceptBoardInvitationItem(item)'));
  assert(host.includes('acceptBoardInvitationItem: (item: PinmonyBoardInvitation): void => this.acceptBoardInvitationItem(item)'));
  assert(host.includes('onAccept: (item: PinmonyBoardInvitation) => this.acceptBoardInvitationItem(item)'));
  assert(host.includes('Promise.all([this.inboxReadController.refresh(), this.readBoardInvitations()])'), 'pull refresh includes request list');
  const entryRead = host.split('\n').find(line => line.includes('if(index === 2') && line.includes('this.readBoardInvitations()'));
  assert(entryRead && !entryRead.includes('invitationReadPage'), 'root reentry refreshes even a previous successful empty list');
  assert(page.includes('onDecline: this.onInvitationDecline')); assert(root.includes('view.declineBoardInvitation(item)'));
  assert(host.includes('onDecline: (item: PinmonyBoardInvitation) => this.declineBoardInvitation(item)'));
  assert(host.includes('declineBoardInvitation: (item: PinmonyBoardInvitation): void => this.declineBoardInvitation(item)'));
  assert(host.includes('readBoardInvitations: (preview?: boolean): Promise<void> => this.readBoardInvitations(preview)'));
  console.log('Invitation decline: exact captured contract, both entries, success=new, no optimistic success, mismatch/unknown locks, safe read recovery, failures and late account/route/background passed');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
