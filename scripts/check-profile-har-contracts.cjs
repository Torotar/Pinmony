const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('feature_profile/src/main/ets/services/PinmonyProfilePanelScript.ets', 'utf8');
const script = Function('return ' + source.slice(source.indexOf('`'), source.lastIndexOf('`') + 1))();
new Function(script);
const flush = async () => { for (let i = 0; i < 8; i++) await new Promise(r => setImmediate(r)); };
function harness() {
  const page = 'https://www.pinterest.com/sample/';
  const location = { href: page, origin: 'https://www.pinterest.com', pathname: '/sample/' };
  const info = { userId: '123', viewerId: '999', isOwn: false, followingUser: false, blocked: false };
  const calls = [], notices = [];
  const window = { PinmonyProfileApi: { currentInfo: p => p === page ? info : null } };
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, btoa,
    fetch: (url, options) => new Promise(resolve => calls.push({ url, options, resolve })) });
  const respond = (i, data) => calls[i].resolve({ ok: true, json: async () => data });
  return { api: window.PinmonyProfilePanel, calls, notices, page, info, location, respond };
}
(async () => {
  let h = harness();
  const opening = h.api.open(h.page, 'followers', 'users', 1);
  assert.deepEqual(JSON.parse(h.calls[0].options.body).variables, { userId: '123' });
  h.respond(0, { data: { v3GetUserHandlerQuery: { data: { id: btoa('User:123'), followers: { connection: {
    edges: [{ node: { entityId: '456', username: 'other', fullName: 'Other', explicitlyFollowedByMe: false, blockedByMe: false } }],
    pageInfo: { endCursor: null, hasNextPage: false }
  } } } } } });
  await opening;
  assert.equal(h.api.read().items[0].id, '456');
  assert.equal(h.api.follow(h.page, '456'), true);
  assert.equal(h.api.follow(h.page, '456'), false);
  h.respond(1, { data: { v3FollowUserMethodMutation: { data: { id: btoa('User:456'), explicitlyFollowedByMe: true } } } });
  await flush();
  assert.equal(h.api.readFollow(), 'ok');
  assert.equal(h.api.read().items[0].following, true);
  assert.equal(h.api.follow(h.page, '456'), true);
  h.respond(2, { data: { v3UnfollowUserMethodMutation: { data: { id: btoa('User:777'), explicitlyFollowedByMe: false } } } });
  await flush();
  assert.equal(h.api.readFollow(), 'error');
  assert.equal(h.api.read().items[0].following, true);
  assert.equal(h.api.follow(h.page), true);
  h.api.close();
  h.respond(3, { data: { v3FollowUserMethodMutation: { data: { id: btoa('User:123'), explicitlyFollowedByMe: true } } } });
  await flush();
  assert.equal(h.info.followingUser, false);
  h = harness();
  assert.equal(h.api.shareOpen(h.page, 1, s => h.notices.push(s)), true);
  const payload = JSON.parse(h.calls[0].options.body);
  assert.deepEqual(JSON.parse(payload.variables.inviteType), { invite_category: 3, invite_object: 3, invite_channel: 12 });
  h.respond(0, { data: { v3InviteUserExternalQuery: { data: { inviteUrl: 'https://pin.it/AbCd123', inviteCode: 'example', title: 'Profile', message: 'Example' } } } });
  h.respond(1, { resource_response: { status: 'success', code: 0, data: [{ id: '456', username: 'other' }] } });
  await flush();
  assert.equal(h.api.shareLink(h.page, 1), 'https://pin.it/AbCd123');
  assert.equal(h.notices.at(-1).contacts[0].enabled, true);
  assert.equal(h.notices.at(-1).actions[0].enabled, true);
  h.location.href = h.page + '_created/';
  assert.equal(h.api.shareLink(h.page, 1), '');
  h.api.shareClose();
  h = harness();
  h.api.shareOpen(h.page, 2, s => h.notices.push(s));
  h.api.shareClose();
  h.respond(0, { data: { v3InviteUserExternalQuery: { data: { inviteUrl: 'https://pin.it/AbCd123', inviteCode: 'example', title: 'Profile', message: 'Example' } } } });
  h.respond(1, { resource_response: { status: 'success', code: 0, data: [] } });
  await flush();
  assert.equal(h.notices.length, 1);
  assert.equal(h.api.shareLink(h.page, 2), '');
  h = harness();
  const boards = h.api.open(h.page, 'following', 'boards', 3);
  assert.equal(h.calls[0].options.method, 'POST');
  const boardOptions = JSON.parse(new URLSearchParams(h.calls[0].options.body).get('data')).options;
  assert.equal(boardOptions.url, '/v3/users/sample/boards/following/');
  assert.ok(boardOptions.data.fields.includes('board.images[236x]'));
  assert.ok(boardOptions.data.fields.includes('board.owner()'));
  assert.ok(!boardOptions.data.fields.includes('board.images'));
  assert.ok(!boardOptions.data.fields.includes('board.owner.username'));
  h.respond(0, { resource_response: { status: 'success', code: 0, data: [{
    id: '456', type: 'board', name: 'Example', images: { '236x': [{ url: 'https://i.pinimg.com/example.jpg' }, null] },
    pin_count: 85, followed_by_me: true, url: '/other/example/', board_order_modified_at: '2026-01-01T00:00:00Z'
  }] } });
  await boards;
  assert.equal(h.api.read().error, '');
  assert.equal(h.api.read().items.length, 1);
  assert.equal(h.api.read().items[0].covers.length, 1);
  assert.equal(h.api.read().items[0].targetUrl, 'https://www.pinterest.com/other/example/');
  assert.equal(h.api.read().items[0].pinCount, '85 张 Pin 图');
  console.log('Profile HAR: followers, confirmed writes, duplicate click, identity mismatch, stale close and sharing OK');
})().catch(e => { console.error(e); process.exitCode = 1; });
