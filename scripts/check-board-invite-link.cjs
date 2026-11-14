const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { createSearchRuntime } = require('./search-controller-harness.cjs');
const networkExports = { PIN_BUSINESS_PIN_READ_ENABLED: true };
const logs = [];
const foundation = { PinmonyRuntimeLog: { info: value => logs.push(value), warn() {} } };
const loader = createArktsLoader(ts, {
  common_network: networkExports, common_session: {}, feature_inbox: {}, feature_pin: {},
  common_foundation: foundation,
  '@kit.RemoteCommunicationKit': { rcp: {} }, '@kit.BasicServicesKit': {}
});
foundation.PinmonyTaskRegistry = loader.loadFile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets').PinmonyTaskRegistry;
const parser = loader.loadFile('common_network/src/main/ets/PinmonyBoardInviteLink.ets');
Object.assign(networkExports, parser);
const { parseBoardInviteLink } = parser;
const { hasBoardInviteLinkContext } = parser;
const { PinmonyPinNetwork } = loader.loadFile('feature_pin/src/main/ets/services/PinmonyPinNetwork.ets');
const { acceptsNetworkJob } = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const { PinmonyBoardInvitationNative } = loader.loadFile('entry/src/main/ets/app/PinmonyBoardInvitationNative.ets');
const { PinmonyShareNativeFlow } = loader.loadFile('entry/src/main/ets/app/PinmonyShareNativeFlow.ets');
const origin = 'https://www.pinterest.com', boardUrl = origin + '/owner/art/';
const linkUrl = boardUrl + '?invite_code=synthetic_invite&board_collab_inviter=true&inviter_user_id=42';
const link = parseBoardInviteLink(linkUrl);
assert.equal(link.boardUrl, boardUrl);
for (const boolean of ['true', 'True', 'TRUE']) {
  assert.equal(parseBoardInviteLink(linkUrl.replace('inviter=true', 'inviter=' + boolean))?.boardUrl, boardUrl,
    'Captured invitation boolean spelling must be accepted');
}
for (const boolean of ['false', 'False', '1', 'truex', '']) {
  assert.equal(parseBoardInviteLink(linkUrl.replace('inviter=true', 'inviter=' + boolean)), undefined);
}
const encodedLink = linkUrl.replace('invite_code', '%69nvite_code');
assert(hasBoardInviteLinkContext(encodedLink));
assert(hasBoardInviteLinkContext(boardUrl + '?%69nvite_code'));
assert(!hasBoardInviteLinkContext('ordinary invite_code=word'));
assert.equal(parseBoardInviteLink(encodedLink).inviteCode, link.inviteCode);
for (const url of [linkUrl.replace('www.pinterest.com','www.pinterest.com.evil.test'),
  linkUrl.replace('https://','http://'), linkUrl.replace('/owner/','/user@owner/'),
  linkUrl.replace('/art/','/%2f/'), linkUrl.replace('inviter=true','inviter=false'),
  linkUrl + '&invite_code=duplicate', linkUrl.replace('inviter_user_id=42','inviter_user_id=bad'),
  linkUrl.replace('/owner/art/','/search/art/'), linkUrl + '\nnext']) {
  assert.equal(parseBoardInviteLink(url), undefined, url);
}
const viewer = { id: '41', username: 'viewer' }, inviter = { id: '42', username: 'owner' };
const board = { id: '400', name: 'Art', url: '/owner/art/' };
const clone = value => JSON.parse(JSON.stringify(value));
function fixture() {
  const session = { authenticated: true, accountId: 'synthetic', generation: 1, origin };
  const store = { shareContacts: [], shareActions: [], shareOptions: [], shareSession: 0 };
  const requests = [], copies = [];
  let bannerBoard = { id: board.id };
  let active = true, allowed = true, visible = false, status = 'new', decline = false, landFailure = false, copyFailure = false, authenticated = true, landAccepted = false, hold;
  const response = (data, endpoint) => ({ status: 200, body: JSON.stringify({
    resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data }, client_context: { user: viewer, is_authenticated: authenticated }
  }) });
  const invite = () => ({ board, invited_by_user: inviter, invited_user: viewer, status: decline ? 'declined' : status, type: 'collaboratorinvite' });
  const transport = { request: async (job, context) => {
    const contextValue = context();
    if (!contextValue.authenticated || !acceptsNetworkJob(job, contextValue)) return { status: 0, error: 'request-unavailable', body: '' };
    requests.push(clone(job));
    const path = new URL(job.url).pathname;
    if (hold) { const work = hold; hold = undefined; return work(job); }
    if (path.includes('BoardResource')) return response(board, 'board');
    if (path.includes('BoardInviteResource')) return response({ ...invite(), board: bannerBoard }, 'v3_get_user_board_invite');
    if (path.includes('BoardInvitesResource')) return response([invite()], 'v3_user_board_invites');
    if (job.method === 'POST') {
      if (landFailure) throw Error('transport-disconnected');
      return response({ type: 'invitecode', board, from_user_id: inviter.id, is_accepted: landAccepted }, 'v3_log_invite_land_attribution');
    }
    return response({ invite_url: 'https://pin.it/Synthetic', invite_code: 'synthetic_invite' }, 'v3_invite_user_external');
  } };
  const pinNetwork = new PinmonyPinNetwork(transport);
  const network = { cancel() {}, requestBusinessAuxiliary: (...args) => pinNetwork.requestBusinessAuxiliary(...args),
    requestBusinessSharePublish: async job => job.url.includes('graphql') ? { status: 200, body: JSON.stringify({ data: {
      v3InviteUserExternalQuery: { data: { inviteUrl: 'https://pin.it/Existing', inviteCode: 'ordinary', title: 'Board', message: 'Board' } }
    } }) } : response([], 'contacts') };
  const ports = { session: () => session, network: () => network, store: () => store,
    page: () => boardUrl, active: () => active, username: () => 'viewer', avatar: () => '', feedback() {} };
  const receiving = new PinmonyBoardInvitationNative(ports);
  const sharing = new PinmonyShareNativeFlow({ ...ports,
    current: () => active, visible: () => visible, show: () => { visible = true; },
    copy: async value => { if (copyFailure) throw Error('clipboard'); copies.push(value); }, share: async () => {}, canInviteBoard: () => allowed
  });
  return { store, requests, copies, session, receiving, sharing, network, response, current: () => active,
    setActive: value => { active = value; }, setAllowed: value => { allowed = value; }, setStatus: value => { status = value; },
    setDeclined: () => { decline = true; }, failLand: () => { landFailure = true; }, failCopy: () => { copyFailure = true; },
    setAuthenticated: value => { authenticated = value; }, setLandAccepted: value => { landAccepted = value; },
    setBannerBoard: value => { bannerBoard = value; },
    hold: fn => { hold = fn; } };
}
async function main() {
  const receiver = fixture();
  const loggedOut = fixture(); loggedOut.setAuthenticated(false);
  await assert.rejects(loggedOut.receiving.resolveLink(link, loggedOut.current));
  assert.equal(loggedOut.requests.length, 1, 'Explicit logged-out response cannot land an invitation');
  const inconsistent = fixture(); inconsistent.setLandAccepted(true);
  const attributed = await inconsistent.receiving.resolveLink(link, inconsistent.current);
  assert.equal(attributed.status, 'new', 'Attribution acceptance cannot override confirmed collaboration status');
  assert.equal((await inconsistent.receiving.resolveLink(link, inconsistent.current)).status, 'new');
  assert.equal(inconsistent.requests.filter(job => job.method === 'POST').length, 1, 'Confirmed attribution never replays landing');
  assert(!inconsistent.requests.some(job => /BoardInviteResource\/(update|delete)/.test(job.url)), 'Attribution never accepts collaboration');
  const item = await receiver.receiving.resolveLink(link, receiver.current);
  assert.equal(item.status, 'new'); assert.equal(item.invitedUser, viewer.id);
  assert.equal(item.boardUrl, boardUrl); assert.equal(item.boardName, board.name, 'ID-only banner reuses verified lookup details');
  for (const invalid of [{ id: '401' }, { id: board.id, url: '/other/board/' }, { id: board.id, url: 'https://evil.test/owner/art/' }]) {
    const mismatch = fixture(); mismatch.setBannerBoard(invalid);
    await assert.rejects(mismatch.receiving.resolveLink(link, mismatch.current));
    assert(!mismatch.requests.some(job => job.method === 'POST'), 'Conflicting board identity cannot land');
  }
  assert.deepEqual(receiver.requests.map(job => new URL(job.url).pathname), ['/resource/BoardResource/get/',
    '/resource/BoardInviteResource/get/', '/resource/ApiResource/create/', '/resource/BoardInviteResource/get/']);
  const landing = receiver.requests[2];
  assert.equal(landing.headers['Content-Type'], 'application/json');
  assert.equal(JSON.parse(landing.body).data.options.data.invite_code, 'synthetic_invite');
  assert.equal(receiver.store.boardInvitations, undefined, 'Inbox must reload server invitations');
  assert.equal(receiver.store.invitationReadPage, '');
  assert(!receiver.requests.some(job => /BoardInviteResource\/(update|delete)/.test(job.url)), 'Opening never accepts or declines');
  await receiver.receiving.resolveLink(link, receiver.current);
  assert.equal(receiver.requests.filter(job => job.method === 'POST').length, 1, 'Confirmed landing is not replayed');
  const accepted = fixture(); accepted.setStatus('accepted');
  assert.equal((await accepted.receiving.resolveLink(link, accepted.current)).status, 'accepted');
  assert(!accepted.requests.some(job => job.method === 'POST'));
  const declined = fixture(); declined.setDeclined(); await assert.rejects(declined.receiving.resolveLink(link, declined.current));
  assert(!declined.requests.some(job => job.method === 'POST'));
  const uncertain = fixture(); uncertain.failLand();
  await assert.rejects(uncertain.receiving.resolveLink(link, uncertain.current));
  assert.equal((await uncertain.receiving.resolveLink(link, uncertain.current)).status, 'new');
  assert.equal(uncertain.requests.filter(job => job.method === 'POST').length, 1, 'Unknown landing reconciles with inbox instead of replaying');
  assert(uncertain.requests.some(job => job.url.includes('BoardInvitesResource')));
  const stale = fixture(); let finish;
  stale.hold(() => new Promise(resolve => { finish = resolve; }));
  const pending = stale.receiving.resolveLink(link, stale.current); stale.session.generation++;
  finish(stale.response(board, 'board')); await assert.rejects(pending);
  assert.equal(stale.requests.length, 1, 'Account change prevents downstream requests');

  const sharing = fixture(); await sharing.sharing.open('board', boardUrl, board.id);
  assert.equal(sharing.store.shareBoardInviteVisible, true);
  sharing.sharing.pause(true);
  assert.equal(sharing.store.shareBoardInviteVisible, false);
  await sharing.sharing.refresh();
  assert.equal(sharing.store.shareBoardInviteVisible, true, 'Resuming rechecks board permission and restores footer');
  await sharing.sharing.action('native-board-invite-copy');
  assert.deepEqual(sharing.copies, ['https://pin.it/Synthetic']);
  assert.equal(sharing.store.shareBoardInviteBusy, false); assert(sharing.store.shareBoardInviteFeedback);
  sharing.failCopy(); await sharing.sharing.action('native-board-invite-copy');
  assert.equal(sharing.copies.length, 1); assert(/无法/.test(sharing.store.shareBoardInviteFeedback));
  sharing.setAllowed(false); const count = sharing.requests.length;
  await sharing.sharing.action('native-board-invite-copy'); assert.equal(sharing.requests.length, count);
  const denied = fixture(); denied.setAllowed(false); await denied.sharing.open('board', boardUrl, board.id);
  assert.equal(denied.store.shareBoardInviteVisible, false);
  const cancelled = fixture(); let release;
  cancelled.hold(() => new Promise(resolve => { release = resolve; }));
  const resolving = cancelled.receiving.resolveLink(link, cancelled.current);
  cancelled.receiving.cancelLink(); release(cancelled.response(board, 'board'));
  await assert.rejects(resolving); assert.equal(cancelled.requests.length, 1);
  const duplicate = fixture(); await duplicate.sharing.open('board', boardUrl, board.id); let complete;
  duplicate.hold(() => new Promise(resolve => { complete = resolve; }));
  const copying = duplicate.sharing.action('native-board-invite-copy');
  await duplicate.sharing.action('native-board-invite-copy'); assert.equal(duplicate.requests.length, 1);
  duplicate.sharing.close(); complete(duplicate.response({invite_url:'https://pin.it/Synthetic',invite_code:'synthetic_invite'},'v3_invite_user_external'));
  await copying; assert.equal(duplicate.copies.length, 0, 'Closing prevents late clipboard writes');
  assert.equal(duplicate.store.shareBoardInviteVisible, false);

  // A response arriving after a copy loses permission, account, or board ownership
  // must never reach the clipboard, even if its server envelope is valid.
  for (const change of ['permission', 'account', 'board']) {
    const late = fixture(); await late.sharing.open('board', boardUrl, board.id);
    let releaseCopy;
    late.hold(() => new Promise(resolve => { releaseCopy = resolve; }));
    const work = late.sharing.action('native-board-invite-copy');
    assert.equal(late.store.shareBoardInviteBusy, true);
    if (change === 'permission') late.setAllowed(false);
    if (change === 'account') late.session.generation++;
    if (change === 'board') await late.sharing.open('board', origin + '/owner/other/', '402');
    releaseCopy(late.response({ invite_url: 'https://pin.it/Synthetic', invite_code: 'synthetic_invite' }, 'v3_invite_user_external'));
    await work;
    assert.equal(late.copies.length, 0, change + ' change prevents late clipboard writes');
    assert.equal(late.store.shareBoardInviteBusy, false);
    assert(!late.store.shareBoardInviteFeedback, change + ' change cannot show copied success');
  }
  for (const invalid of [
    { invite_url: 'https://evil.test/Synthetic', invite_code: 'synthetic_invite' },
    { invite_url: 'https://pin.it/Synthetic' },
    { invite_url: boardUrl, invite_code: 'synthetic_invite' }
  ]) {
    const malformed = fixture(); await malformed.sharing.open('board', boardUrl, board.id);
    malformed.hold(async () => malformed.response(invalid, 'v3_invite_user_external'));
    await malformed.sharing.action('native-board-invite-copy');
    assert.equal(malformed.copies.length, 0, 'malformed reply cannot copy an ordinary or foreign link');
    assert(malformed.store.shareBoardInviteFeedback);
    assert.equal(malformed.store.shareBoardInviteBusy, false);
  }
  for (const mode of ['pin', 'user']) {
    const other = fixture();
    await other.sharing.open(mode, mode === 'pin' ? origin + '/pin/101/' : origin + '/owner/', mode === 'pin' ? '101' : '42');
    assert.equal(other.store.shareBoardInviteVisible, false, mode + ' share cannot show board invitation footer');
    const before = other.requests.length;
    await other.sharing.action('native-board-invite-copy');
    assert.equal(other.requests.length, before, mode + ' share cannot request a board invitation link');
    assert.equal(other.copies.length, 0);
  }

  // Hold replies after the real transport has issued them, covering cancellation
  // at every receiving stage, especially an already-sent attribution mutation.
  for (const stage of ['banner', 'land', 'recheck']) {
    const late = fixture(); const request = late.network.requestBusinessAuxiliary;
    let releaseReply; let banners = 0;
    late.network.requestBusinessAuxiliary = async (...args) => {
      const reply = await request(...args);
      const path = new URL(args[0].url).pathname;
      if (path.includes('BoardInviteResource')) banners++;
      if ((stage === 'banner' && banners === 1 && path.includes('BoardInviteResource')) ||
          (stage === 'land' && path.includes('ApiResource/create')) ||
          (stage === 'recheck' && banners === 2 && path.includes('BoardInviteResource'))) {
        await new Promise(resolve => { releaseReply = resolve; });
      }
      return reply;
    };
    const work = late.receiving.resolveLink(link, late.current);
    for (let tick = 0; !releaseReply && tick < 20; tick++) await new Promise(resolve => setImmediate(resolve));
    assert(releaseReply, stage + ' stage reached real transport');
    const before = late.requests.length;
    late.receiving.cancelLink(); releaseReply();
    await assert.rejects(work, stage + ' late response cannot open a board');
    assert.equal(late.requests.length, before, stage + ' cancellation prevents downstream requests');
    const writes = late.requests.filter(job => job.method === 'POST').length;
    await late.receiving.resolveLink(link, late.current);
    assert.equal(late.requests.filter(job => job.method === 'POST').length, stage === 'banner' ? writes + 1 : writes,
      stage + ' retry reconciles an already-issued landing without replaying it');
  }

  const { harness } = createSearchRuntime(ts); const opened = [];
  const searchPage = origin + '/search/pins/?q=art';
  const search = harness({ nativeSearch: () => true, openSubmittedPin() {},
    resolveSubmittedLink: async () => ({ kind: 'board-invite', invitation: link }),
    openSubmittedBoardInvite: async (invitation, source, current) => { assert(current()); opened.push([invitation, source]); }
  });
  search.store.searchNativeInputReady = true;
  search.store.search = { kind:'state',session:1,pageKey:searchPage,query:'art',categories:[],suggestions:[],results:[],heroes:[],ideaSections:[] };
  await search.controller.submitSearch(linkUrl); await search.controller.submitSearch('https://pin.it/Synthetic');
  assert.equal(opened.length, 2); assert.equal(opened[0][1], searchPage);
  assert.equal(search.store.submittedPinLoading, false);
  assert(!search.events.some(event => event[0] === 'search'), 'Invitation links never become text search routes');
  const indexSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const method = name => {
    const start = indexSource.indexOf('  private ' + name + '(');
    assert(start >= 0, name);
    const end = indexSource.indexOf('\n  private ', start + 1);
    return indexSource.slice(start, end);
  };
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method('previewBoardInvitation') + method('commitNativeSearchReturn') + '} Host;',
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText,
    { PIN_NATIVE_BOARD_READS_ENABLED: true, PinmonyRuntimeLog: { info() {} } });
  const host = new Host(), navigation = [], retained = search.store.search;
  const { PinmonyBoardInvitationController } = loader.loadFile('feature_inbox/src/main/ets/controllers/PinmonyBoardInvitationController.ets');
  const previewStore = { boardInvitationToken: 0 };
  const previewController = new PinmonyBoardInvitationController(previewStore, {
    authenticated: () => true, foreground: () => true, nativePause: () => inconsistent.receiving.pause()
  });
  Object.assign(host, { activeTab: 1, boardStore: {}, rootTabAddresses: new Map(), searchStore: search.store,
    boardInvitationController: previewController, clearRootTabGuard() {},
    boardNativeReads: { demand() {}, pause() {} }, returnCoordinator: { cancel() {} },
    pageHistory: { visit: (...args) => navigation.push(args), cancelBack() {} },
    readBoardInvitations: () => navigation.push(['invitations']), selectNativeRootTab: tab => assert.equal(tab, 1),
    syncFloatingTabsMotion() {}, searchDiscoveryNativeReads: { demand() {} }, searchNativeReads: { demand() {} },
    shouldKeepSearchRootMounted: () => true, nativeSearchPageVisible: () => true,
    tabRequestToken: 0, pageBackToken: 0, authEpoch: 1,
    currentSearchPageKey: () => searchPage, nativeBusinessSessionContext: () => inconsistent.session,
    boardInvitationNative: inconsistent.receiving });
  const callbackStart = indexSource.indexOf('    openSubmittedBoardInvite: async (');
  const callbackEnd = indexSource.indexOf('    resolveSubmittedLink:', callbackStart);
  assert(callbackStart >= 0 && callbackEnd > callbackStart);
  const bindInvite = vm.runInNewContext(ts.transpileModule('(function() { return ({' +
    indexSource.slice(callbackStart, callbackEnd) + '}); })',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, { PIN_NATIVE_BOARD_READS_ENABLED: true });
  await bindInvite.call(host).openSubmittedBoardInvite(link, searchPage, () => true);
  assert.equal(previewStore.boardInvitationPreview.status, 'new', 'Actual controller accepts collaboration status independent of attribution');
  assert.equal(previewStore.invitationBannerVisible, true);
  assert.equal(host.navigationAddress, boardUrl, 'Actual product callback commits the invited board route');
  assert.equal(inconsistent.requests.filter(job => job.method === 'POST').length, 1);
  assert.equal(host.boardStore.boardReturnUrl, searchPage); assert.equal(host.boardStore.rootTab, 1);
  assert.equal(host.boardStore.boardDetail.pageKey, boardUrl);
  assert(navigation.some(event => event[0] === 'invitations'), 'Preview rereads server invitation state');
  host.commitNativeSearchReturn(host.boardStore.boardReturnUrl);
  assert.equal(host.navigationAddress, searchPage); assert.equal(host.boardStore.boardDetail, undefined);
  assert.equal(host.searchStore.search, retained, 'Return preserves the committed search snapshot');
  const { PinmonySearchCache } = loader.loadFile('feature_search/src/main/ets/services/PinmonySearchCache.ets');
  const cache = new PinmonySearchCache(); cache.put({ ...search.store.search, query: linkUrl }, 100);
  assert.equal(cache.get(searchPage), undefined, 'Invitation codes do not enter search cache');
  cache.put({ ...search.store.search, query: encodedLink }, 100);
  assert.equal(cache.get(searchPage), undefined, 'Encoded invitation codes do not enter search cache');

  const sheet = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyShareSheet.ets', 'utf8');
  assert(sheet.indexOf('if (this.pinStore.shareBoardInviteVisible)') > sheet.indexOf('Scroll()'));
  assert(sheet.includes('.flexShrink(0)')); assert(sheet.includes('.layoutWeight(1)'));
  assert(sheet.includes('this.pinStore.shareLoading || !this.pinStore.shareSearchActive'), 'Loading keeps footer at panel bottom');
  assert(!logs.some(line => /synthetic_invite|inviter_user_id/.test(line)), 'Invitation context must not leak into logs');
  console.log('Board invitation links: parser, exact transport, pending/accepted/declined, no write replay, inbox invalidation, copy permission/failure/duplicate/stale, typed search and cache isolation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
