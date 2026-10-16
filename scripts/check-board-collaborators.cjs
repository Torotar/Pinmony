const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync('feature_board/src/main/ets/services/PinmonyBoardApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
const flush = async () => { for (let i = 0; i < 12; i++) await new Promise(setImmediate); };
async function harness(member = false, allowInvites = false, editFirst = false, confirmLeave = true) {
  const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/sample/board/', href: 'https://www.pinterest.com/sample/board/' };
  const messages = [], writes = [], window = { addEventListener() {}, setInterval() {}, PinmonyBoardApiEnabled: true, PinmonyShareBridge: { boardState: raw => messages.push(JSON.parse(raw)) } }; window.top = window;
  let deferred, permissions = 1, invites = allowInvites;
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, document: { readyState: 'complete' },
    fetch: async (url, args) => {
      if (url === '/_/graphql/') { writes.push(JSON.parse(args.body)); return new Promise(resolve => { deferred = resolve; }); }
      const name = url.split('/')[2], query = new URLSearchParams(args.body || new URL(url, location.origin).search);
      const options = JSON.parse(query.get('data')).options;
      if (url.includes('/update/')) { writes.push(options); permissions = options.collaborator_permissions_setting; invites = options.collaborator_invites_enabled; }
      let data = name === 'BoardResource' ? { type: 'board', id: '100', url: '/sample/board/', name: 'Board',
        pin_count: 0, collaborated_by_me: options.field_set_key === 'boardEdit' ? undefined : member,
        owner: options.field_set_key === 'boardEdit' ? { id: member ? '201' : '200' } :
          { id: member ? '201' : '200', username: 'sample', full_name: 'Owner', image_large_url: 'https://example.invalid/owner.jpg' }, collaborator_permissions_setting: permissions,
        collaborator_invites_enabled: invites } : name === 'ShareSuggestionsResource' ? [{ id: '300', username: 'suggested', full_name: 'Suggested' }] : [];
      if (url.includes('/delete/')) { writes.push(options); data = options.url.endsWith('/follow/') ? null : { type: 'board', id: '100', collaborated_by_me: !confirmLeave }; }
      return { ok: true, json: async () => ({ resource_response: { status: 'success', code: 0,
        endpoint_name: url.includes('/delete/') ? options.url.endsWith('/follow/') ? 'v3_unfollow_board' : 'v3_remove_board_collaborators' : url.includes('/update/') ? 'v3_edit_board' : 'read', data, bookmark: '-end-' }, client_context: { user: { id: '200' } } }) };
    } });
  await flush();
  const api = window.PinmonyBoardApi, board = messages.at(-1);
  if (editFirst) { api.flow(board.session, board.pageKey, JSON.stringify({ action: 'edit' })); await flush(); assert.equal(messages.at(-1).collaborator, true); }
  assert(api.collaboratorsOpen(board.session, board.pageKey, 1)); await flush();
  return { api, board, messages, location, writes, resolve: value => deferred(value) };
}
(async () => {
  const permissionFlow = await harness();
  assert(permissionFlow.api.collaboratorsAction(1, 'permissions', ''));
  assert(permissionFlow.api.collaboratorsAction(1, 'save', { permission: 0, invites: true }));
  await flush();
  assert.equal(permissionFlow.api.collaboratorsRead(1).permission, 0);
  assert.equal(permissionFlow.writes.at(-1).collaborator_permissions_setting, 0);
  assert(permissionFlow.api.collaboratorsAction(1, 'permissions', ''));
  assert(permissionFlow.api.collaboratorsAction(1, 'save', { permission: 1, invites: true }));
  await flush();
  assert.equal(permissionFlow.api.collaboratorsRead(1).permission, 1);
  assert.equal(permissionFlow.api.collaboratorsRead(1).invites, true);

  const unfollow = await harness(true, true);
  unfollow.api.flow(unfollow.board.session, unfollow.board.pageKey, JSON.stringify({ action: 'unfollow' }));
  unfollow.api.flow(unfollow.board.session, unfollow.board.pageKey, JSON.stringify({ action: 'unfollow' }));
  await flush();
  assert.equal(unfollow.writes.length, 1);
  assert.equal(unfollow.messages.at(-1).flow.phase, 'unfollowed');
  assert.equal(unfollow.messages.at(-1).collaborator, true);

  const leaving = await harness(true, true, true);
  leaving.api.flow(leaving.board.session, leaving.board.pageKey, JSON.stringify({ action: 'leave' }));
  leaving.api.flow(leaving.board.session, leaving.board.pageKey, JSON.stringify({ action: 'leave' }));
  await flush();
  assert.equal(leaving.writes.length, 1);
  assert.equal(leaving.messages.at(-1).flow.phase, 'left');
  const uncertain = await harness(true, true, true, false);
  uncertain.api.flow(uncertain.board.session, uncertain.board.pageKey, JSON.stringify({ action: 'leave' }));
  await flush();
  assert.equal(uncertain.messages.at(-1).flow.uncertain, true);
  uncertain.api.flow(uncertain.board.session, uncertain.board.pageKey, JSON.stringify({ action: 'leave' }));
  assert.equal(uncertain.writes.length, 1);

  const allowed = await harness(true, true, true);
  assert.equal(allowed.api.collaboratorsRead(1).canInvite, true);
  assert(allowed.api.collaboratorsAction(1, 'invite', ''));
  assert.equal(allowed.api.collaboratorsAction(1, 'permissions', ''), false);
  assert(allowed.api.collaboratorsAction(1, 'send', '300'));
  assert.equal(allowed.api.collaboratorsAction(1, 'send', '300'), false);
  allowed.resolve({ ok: true, json: async () => ({ data: { v3InviteBoardCollaboratorsMutation: { __typename: 'V3InviteBoardCollaborators' } } }) });
  await flush();
  assert.equal(allowed.api.collaboratorsRead(1).suggestions[0].status, 'new');
  const denied = await harness(true, false);
  assert.equal(denied.api.collaboratorsAction(1, 'invite', ''), false);
  assert.equal(denied.writes.length, 0);
  const h = await harness();
  assert.equal(h.api.collaboratorsRead(1).error, '', JSON.stringify(h.api.collaboratorsRead(1)));
  assert.equal(h.api.collaboratorsRead(1).users[0].status, 'owner');
  assert.equal(h.api.collaboratorsRead(1).users[0].name, 'Owner');
  assert.equal(h.api.collaboratorsRead(1).users[0].avatar, 'https://example.invalid/owner.jpg');
  assert(h.api.collaboratorsAction(1, 'invite', ''));
  assert.equal(h.api.collaboratorsAction(1, 'send', 'unknown'), false);
  assert(h.api.collaboratorsAction(1, 'send', '300'));
  assert.equal(h.api.collaboratorsAction(1, 'send', '300'), false, 'block duplicate while sending');
  h.resolve({ ok: true, json: async () => ({ data: { v3InviteBoardCollaboratorsMutation: { __typename: 'V3InviteBoardCollaborators' } } }) });
  await flush();
  assert.equal(h.api.collaboratorsRead(1).feedback, '已发送 1 个邀请！');
  assert.equal(h.api.collaboratorsAction(1, 'send', '300'), false, 'confirmed invited user cannot be sent again');
  assert(h.api.collaboratorsAction(1, 'permissions', ''));
  assert(h.api.collaboratorsAction(1, 'save', { permission: 1, invites: true })); await flush();
  assert.equal(h.api.collaboratorsRead(1).phase, 'members');
  assert.equal(h.api.collaboratorsRead(1).invites, true);
  const failed = await harness(); failed.api.collaboratorsAction(1, 'invite', ''); failed.api.collaboratorsAction(1, 'send', '300');
  failed.resolve({ ok: true, json: async () => ({ errors: [{ message: 'failure' }] }) }); await flush();
  assert.equal(failed.api.collaboratorsRead(1).feedback, '');
  assert.equal(failed.api.collaboratorsRead(1).uncertain, true);
  assert.equal(failed.api.collaboratorsAction(1, 'send', '300'), false);
  failed.location.pathname = '/sample/other/'; assert.equal(failed.api.collaboratorsRead(1), null);
  console.log('Board collaborators: reads, verified invite/permissions, duplicate protection, errors and stale routes passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
