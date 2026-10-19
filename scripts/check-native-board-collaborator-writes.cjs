const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function load(file, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  }}).outputText, {exports, require: withLocalMessages(name => { const dependency = deps(name); return name.startsWith('./') && Object.keys(dependency).length === 0 ? load(require('node:path').resolve(require('node:path').dirname(file), name) + '.ets') : dependency; }), setTimeout, clearTimeout, console});
  return exports;
}
const logs = [];
const writerModule = load('entry/src/main/ets/app/PinmonyBoardCollaboratorsNativeWrites.ets', name =>
  name === 'common_foundation' ? {PinmonyRuntimeLog: {info: s => logs.push(s)}} : {});
const Writer = writerModule.PinmonyBoardCollaboratorsNativeWrites;
const {PinmonyNativeNetwork: Network, acceptsNetworkJob} = load('common_network/src/main/ets/PinmonyNativeNetwork.ets', name => name === 'common_session' ? {PinmonySessionCredentials: class {}} : {});
const origin = 'https://www.pinterest.com', page = origin + '/sample/board/';
const permission = JSON.stringify({permission: 0, invites: false});
const user = id => ({id, name: 'Synthetic ' + id, username: 'sample_' + id, avatar: '', status: ''});
const permissionResponse = (extra = {}) => JSON.stringify({resource_response: {
  status: 'success', code: 0, endpoint_name: 'v3_edit_board', data: {
    id: '100', owner: {id: '42'}, collaborator_permissions_setting: 0, collaborator_invites_enabled: false
  }
}, client_context: {user: {id: '42'}}, ...extra});
const inviteResponse = () => JSON.stringify({data: {v3InviteBoardCollaboratorsMutation: {__typename: 'V3InviteBoardCollaborators'}}});
const flush = () => new Promise(setImmediate);
function fixture(member = false) {
  let session = {authenticated: true, accountId: 'synthetic-cache', generation: 1, origin, userAgent: 'synthetic'};
  let identity = {page, boardId: '100', viewerId: '42', ownerId: member ? '43' : '42', member};
  let state = {token: 1, page, phase: 'permissions', owner: !member, canInvite: true,
    loading: false, busy: false, uncertain: false, error: '', feedback: '', permission: 1,
    invites: true, users: [{...user(identity.ownerId), status: 'owner'}], suggestions: [user('44'), user('45')]};
  const requests = [], cancelled = [], snapshots = [], feedback = [], confirmations = [];
  const network = {cancel: id => cancelled.push(id), requestBusinessBoardCollaboratorWrite(job, s, board, viewer, owner, canInvite, current) {
    assert(current()); assert.equal(s().accountId, session.accountId);
    return new Promise(resolve => requests.push({job, board, viewer, owner, canInvite, current,
      resolve: (body, status = 200, error = '') => resolve({body, status, error})}));
  }};
  const writer = new Writer({state: () => state, identity: () => identity, session: () => session,
    network: () => network, changed: next => {snapshots.push(next); state = next},
    confirmed: next => confirmations.push(next.feedback), feedback: s => feedback.push(s)});
  return {writer, network, requests, cancelled, snapshots, feedback, confirmations, state: () => state,
    session: () => session, identity: () => identity, setState: next => state = next,
    setSession: next => session = next, setIdentity: next => identity = next};
}
async function main() {
  const save = fixture(), old = save.state();
  let pending = save.writer.submit('save', permission);
  assert(save.state().busy); assert.equal(old.busy, false, 'publishes a new observable snapshot');
  assert.equal(save.feedback.length, 0); await save.writer.submit('save', permission);
  assert.equal(save.requests.length, 1, 'one pending POST despite repeated taps');
  const form = new URLSearchParams(save.requests[0].job.body), options = JSON.parse(form.get('data')).options;
  assert.equal(form.get('source_url'), '/board/100/edit/');
  assert.deepEqual(options, {board_id: '100', collaborator_permissions_setting: 0, collaborator_invites_enabled: false, sensitivity: null});
  save.requests[0].resolve(permissionResponse()); await pending;
  assert.equal(save.state().busy, false); assert.equal(save.state().permission, 0); assert.equal(save.state().invites, false);
  assert.equal(save.state().phase, 'members'); assert.deepEqual(save.feedback, ['权限已更新']); assert.equal(save.confirmations.length, 1);

  const invite = fixture(true); invite.state().phase = 'invite';
  pending = invite.writer.submit('send', '44'); await invite.writer.submit('send', '45');
  assert.equal(invite.requests.length, 1); assert.equal(invite.state().suggestions[0].status, '');
  const query = JSON.parse(invite.requests[0].job.body);
  assert.equal(query.queryHash, '42ceaa3423a096a27613e5738f83aaadcee449c55d4dd03624d2f08a6b6dca04');
  assert.deepEqual(query.variables, {collaboratorIds: ['44'], boardId: '100', message: ''});
  invite.requests[0].resolve(inviteResponse()); await pending;
  assert.equal(invite.state().suggestions[0].status, 'new'); assert.equal(invite.state().users.filter(u => u.id === '44').length, 1);
  assert.deepEqual(invite.feedback, ['已发送 1 个邀请！']);
  await invite.writer.submit('send', '44'); assert.equal(invite.requests.length, 1, 'confirmed invitation cannot be sent again');

  const invalids = [f => f.state().busy = true, f => f.state().uncertain = true,
    f => f.state().loading = true, f => f.state().error = 'read-error', f => f.state().owner = false,
    f => f.setIdentity({...f.identity(), ownerId: '43'}), f => f.setSession({...f.session(), authenticated: false})];
  for (const invalidate of invalids) {const f = fixture(); invalidate(f); await f.writer.submit('save', permission); assert.equal(f.requests.length, 0)}
  for (const input of ['invalid', '{}', JSON.stringify({permission: 2, invites: true}), JSON.stringify({permission: 0, invites: 'yes'})]) {
    const f = fixture(); await f.writer.submit('save', input); assert.equal(f.requests.length, 0);
  }
  for (const input of ['unknown', '42', '43']) {const f = fixture(true); f.state().phase = 'invite'; await f.writer.submit('send', input); assert.equal(f.requests.length, 0)}
  const disabled = fixture(true); disabled.state().phase = 'invite'; disabled.state().canInvite = false;
  await disabled.writer.submit('send', '44'); assert.equal(disabled.requests.length, 0);

  for (const body of ['invalid', permissionResponse({client_context: {user: {id: '999'}}}),
    permissionResponse({resource_response: {status: 'success', code: 0, endpoint_name: 'other', data: {id: '100'}}}),
    permissionResponse({resource_response: {status: 'success', code: 0, endpoint_name: 'v3_edit_board', data: {id: '999', collaborator_permissions_setting: 0, collaborator_invites_enabled: false}}})]) {
    const f = fixture(); const p = f.writer.submit('save', permission); f.requests[0].resolve(body); await p;
    assert(f.state().uncertain); assert.equal(f.state().busy, false); assert.equal(f.feedback.length, 0);
    await f.writer.submit('save', permission); assert.equal(f.requests.length, 1);
  }
  for (const reply of [{body: inviteResponse(), status: 503}, {body: '{}'},
    {body: JSON.stringify({errors: [], data: {v3InviteBoardCollaboratorsMutation: {__typename: 'V3InviteBoardCollaborators'}}})},
    {body: inviteResponse(), error: 'network-unavailable'}]) {
    const f = fixture(); f.state().phase = 'invite'; const p = f.writer.submit('send', '44');
    f.requests[0].resolve(reply.body, reply.status || 200, reply.error || ''); await p;
    assert(f.state().uncertain); assert.equal(f.state().suggestions[0].status, ''); assert.equal(f.feedback.length, 0);
  }
  const interrupted = fixture(); pending = interrupted.writer.submit('save', permission); interrupted.writer.pause();
  assert(interrupted.state().uncertain); assert.equal(interrupted.state().busy, false); assert(interrupted.cancelled.includes(interrupted.requests[0].job.id));
  interrupted.requests[0].resolve(permissionResponse()); await pending; assert.equal(interrupted.feedback.length, 0);
  await interrupted.writer.submit('save', permission); assert.equal(interrupted.requests.length, 1, 'pause never replays an unknown POST');
  for (const revoke of [f => f.setIdentity({...f.identity(), boardId: '101'}), f => f.setIdentity(undefined),
    f => f.setSession({...f.session(), accountId: 'other', generation: 2}), f => f.setState({...f.state(), token: 2})]) {
    const f = fixture(); const p = f.writer.submit('save', permission); revoke(f); f.requests[0].resolve(permissionResponse()); await p;
    assert.equal(f.feedback.length, 0); assert.equal(f.confirmations.length, 0);
  }

  // Run the real strict transport owner gate, then the normal canonical whitelist.
  const net = new Network(); let sent = 0, owner = true, session = save.session(), context;
  net.request = async (job, current) => {context = current; const permitted = acceptsNetworkJob(job, current()); if(permitted)sent++; return {error: permitted ? '' : 'rejected'}};
  const transport = (job, isOwner = true, canInvite = true) => net.requestBusinessBoardCollaboratorWrite(job, () => session, '100', '42', isOwner ? '42' : '43', canInvite, () => owner);
  const permissionJob = save.requests[0].job, inviteJob = invite.requests[0].job;
  assert.equal((await transport(permissionJob)).error, ''); assert.equal((await transport(inviteJob, false)).error, '');
  const before = sent;
  function editForm(mutator) {const q = new URLSearchParams(permissionJob.body), body = JSON.parse(q.get('data')); mutator(body.options); q.set('data', JSON.stringify(body)); return {...permissionJob, body: q.toString()}}
  function editQuery(mutator) {const body = JSON.parse(inviteJob.body); mutator(body); return {...inviteJob, body: JSON.stringify(body)}}
  for (const job of [{...permissionJob, method: 'GET'}, {...permissionJob, id: 'bridge'},
    {...permissionJob, page: origin + '/sample/pins/'}, {...permissionJob, url: origin + '/resource/BoardResource/delete/'},
    {...permissionJob, body: permissionJob.body + '&extra=true'}, editForm(o => o.name = 'unrelated'),
    editForm(o => o.board_id = '999'), editForm(o => o.collaborator_permissions_setting = 2),
    {...permissionJob, body: permissionJob.body.replace(/data=.*/, 'data=' + encodeURIComponent(JSON.stringify({options, context: ''})))},
    {...permissionJob, headers: {...permissionJob.headers, 'X-Pinterest-Pws-Handler': 'www/index.js'}},
    editQuery(o => o.queryHash = 'a'.repeat(64)), editQuery(o => o.variables.boardId = '999'),
    editQuery(o => o.variables.collaboratorIds = ['44', '45']), editQuery(o => o.variables.collaboratorIds = ['42']),
    editQuery(o => o.variables.message = 'unconfirmed'), editQuery(o => o.variables.extra = true),
    {...inviteJob, headers: {...inviteJob.headers, 'X-Pinterest-Source-Url': '/wrong/'}}]) assert((await transport(job)).error);
  assert((await transport(permissionJob, false)).error); assert((await transport(inviteJob, true, false)).error); assert.equal(sent, before);
  const regional = {...inviteJob, page: inviteJob.page.replace(origin, 'https://uk.pinterest.com'), url: inviteJob.url.replace(origin, 'https://uk.pinterest.com')};
  session = {...session, origin: 'https://uk.pinterest.com'}; assert.equal((await transport(regional, false)).error, '');
  session = {...session, accountId: 'revoked'}; assert.equal(context().authenticated, false); owner = false; assert.equal(context().authenticated, false);

  // Execute the actual native reader with Web access forbidden for the whole collaborator flow.
  const {PinmonyBoardNativeReads: Reader} = load('entry/src/main/ets/app/PinmonyBoardNativeReads.ets', name => name === './PinmonyBoardContentNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardContentNativeWrites.ets', n => n === 'common_foundation' ? {PinmonyRuntimeLog:{info(){}}} : {}) : name === './PinmonyBoardManagementNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardManagementNativeWrites.ets', name => name === 'common_foundation' ? {PinmonyRuntimeLog:{info(){}}} : {}) : name === './PinmonyBoardPinNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardPinNativeWrites.ets', name => name === 'common_foundation' ? {PinmonyRuntimeLog: {info(){}}} : {}) : name === './PinmonyBoardCollaboratorsNativeWrites' ? writerModule :
    name === 'common_network' ? {PIN_BUSINESS_PIN_READ_ENABLED: true} : name === 'common_foundation' ? {PinmonyRuntimeLog: {info: s => logs.push(s)}} : {});
  const store = {boardDetail: {kind: 'state', session: 0, pageKey: page, title: 'Board', pinCount: '', pins: [], ready: false}, collaboratorsToken: 0};
  const reads = [], post = [], nativeFeedback = [];
  const runtimeNetwork = {cancel() {}, requestBusinessBoardRead: job => new Promise(resolve => reads.push({job, resolve})),
    requestBusinessBoardAuxRead: job => new Promise(resolve => reads.push({job, resolve})),
    requestBusinessBoardCollaboratorWrite: job => new Promise(resolve => post.push({job, resolve}))};
  const reader = new Reader({store: () => store, session: () => save.session(), active: () => true,
    document: () => {throw Error('Web document must not gate native collaborators')}, documentEpoch: () => {throw Error('Web epoch')},
    prepareDocument: () => {throw Error('navigation')}, runScript: () => {throw Error('Web submission')}, jsonText: s => s,
    network: () => runtimeNetwork, install() {}, bridge() {}, committed() {}, openPin() {}, feedback: s => nativeFeedback.push(s)});
  const resource = data => ({body: JSON.stringify({resource_response: {status: 'success', code: 0, data}, client_context: {user: {id: '42'}}}), status: 200, error: ''});
  const board = {type: 'board', id: '100', url: '/sample/board/', name: 'Board', pin_count: 0, privacy: 'public', owner: {id: '42', username: 'sample'},
    collaborator_permissions_setting: 1, collaborator_invites_enabled: true};
  pending = reader.demand(); reads[0].resolve(resource(board)); await flush(); reads[1].resolve(resource([])); await pending;
  pending = reader.handle('flow', JSON.stringify({action: 'edit'})); reads[2].resolve(resource(board)); await pending;
  pending = reader.openCollaborators(); reads[3].resolve(resource(board)); reads[4].resolve(resource([])); reads[5].resolve(resource([{id: '44', username: 'suggested'}])); await pending;
  await reader.collaboratorsAction('permissions', ''); pending = reader.collaboratorsAction('save', permission);
  assert(store.collaborators.busy); await reader.collaboratorsAction('close', ''); assert(store.collaborators);
  const count = reads.length; await reader.refresh(); assert.equal(reads.length, count, 'refresh cannot invalidate pending POST');
  post[0].resolve({body: permissionResponse(), status: 200, error: ''}); assert.equal(await pending, true);
  assert.equal(store.boardDetail.flow.invites, false, 'editor cannot later submit an older invite switch');
  assert.equal(reader.collaboratorsPolling(), false); assert.deepEqual(nativeFeedback, ['权限已更新']);
  await reader.collaboratorsAction('invite', ''); pending = reader.collaboratorsAction('send', '44');
  post[1].resolve({body: inviteResponse(), status: 200, error: ''}); await pending;
  assert.equal(post.length, 2); assert.equal(store.collaborators.users.find(u => u.id === '44').status, 'new');
  await reader.collaboratorsAction('close', ''); assert.equal(store.collaborators, undefined);
  assert.equal(logs.some(s => s.includes('sample/board') || s.includes('synthetic-cache')), false, 'trace contains no route/account');

  // The real Web adapter accepts native busy/completed snapshots but cannot submit duplicate writes.
  const {PIN_BOARD_API_SCRIPT: script} = load('feature_board/src/main/ets/services/PinmonyBoardApiScript.ets');
  const location = {hostname: 'www.pinterest.com', origin, pathname: '/sample/board/', href: page};
  let fetches = 0; const states = [];
  const window = {PinmonyNativeBoardReadsEnabled: true, PinmonyNativeBoardAuxReadsEnabled: true, PinmonyNativeBoardCollaboratorWritesEnabled: true,
    PinmonyBoardApiEnabled: true, PinmonyNativeNetworkEnabled: true, PinmonyNetwork: {isReady: () => true, documentEpoch: () => 7},
    PinmonyShareBridge: {boardState: raw => states.push(JSON.parse(raw))}, addEventListener() {}, setInterval() {}}; window.top = window;
  const ctx = {window, location, URL, AbortController, console, setTimeout, clearTimeout, fetch() {fetches++; throw Error('duplicate Web operation')}};
  vm.runInNewContext(script, ctx); vm.runInNewContext(reader.installScript(), ctx);
  const state = {...save.state(), page, token: 11, busy: true};
  const snapshot = {...store.boardDetail, nativeVersion: store.boardDetail.nativeVersion + 1};
  assert(window.PinmonyBoardApi.installNative(page, board, '42', snapshot, '', {flowOwned: false, collaborators: state}));
  assert.equal(window.PinmonyBoardApi.collaboratorsAction(11, 'save', {permission: 1, invites: true}), false);
  const finished = {...state, busy: false, feedback: '权限已更新'};
  assert(window.PinmonyBoardApi.installNative(page, board, '42', {...snapshot, nativeVersion: snapshot.nativeVersion + 1}, '', {flowOwned: false, collaborators: finished}));
  assert.equal(window.PinmonyBoardApi.collaboratorsRead(11).busy, false); assert.equal(fetches, 0);
  assert(fs.readFileSync('entry/src/main/ets/app/PinmonyScriptRegistry.ets', 'utf8').includes('window.PinmonyNativeBoardCollaboratorWritesEnabled'));
  console.log('Native collaborator writes passed: permissions/invite, strict POST contracts, duplicate/unknown protection, cancel/stale isolation, native editor adoption, zero Web navigation or submission.');
}
const watchdog = setTimeout(() => {console.error('native collaborator write test did not complete'); process.exit(1)}, 15000);
main().then(() => clearTimeout(watchdog)).catch(error => {clearTimeout(watchdog); console.error(error); process.exitCode = 1});
