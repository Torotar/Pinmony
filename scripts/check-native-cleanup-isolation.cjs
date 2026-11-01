const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = index.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const end = index.indexOf('\n  private ', start + 1);
  assert(end > start, name + ' boundary');
  return index.slice(start, end);
}
const accountBinding = index.match(/setHomeCacheAccountId: (\(value: string\): string => \{[^\n]+\}),/);
assert(accountBinding, 'actual account reset binding');
async function scenario(master, local) {
  const enabled = master && local;
  const flags = { PIN_NATIVE_BOARD_READS_ENABLED: enabled, PIN_NATIVE_SHARE_PUBLISH_ENABLED: enabled,
    PIN_NATIVE_PIN_MENUS_ENABLED: enabled, PIN_NATIVE_HOME_READS_ENABLED: enabled,
    PIN_NATIVE_SEARCH_DISCOVERY_ENABLED: enabled };
  const loader = createArktsLoader(ts, { common_network: { PIN_BUSINESS_PIN_READ_ENABLED: master },
    common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }, '@kit.ArkTS': {}, '@kit.ImageKit': {} }, flags);
  const names = ['openBoardCollaborators', 'pollBoardCollaborators', 'boardCollaboratorsAction',
    'closeBoardCollaborators', 'updateShareSheet', 'dismissShareSheet'];
  const Host = vm.runInNewContext(ts.transpileModule('class Host { accountPort() { return ' + accountBinding[1] + '; }\n' +
    names.map(method).join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { ...flags, PinmonyRuntimeLog: { info() {}, warn(message) { throw Error(message); } } });
  const calls = [], forbidden = () => { throw Error('unexpected legacy work'); };
  const host = new Host();
  Object.assign(host, { nativeBusinessRoutesEnabled: true, activeSheetKind: 'share', showNativeSheet: true,
    homeCacheAccountId: 'old', pinStore: { shareSession: 7, shareError: 'retained', shareContacts: [{ id: 'retained' }] },
    homeStore: {}, boardStore: { collaboratorsToken: 1 },
    boardCollaboratorsController: { pause() {}, open: forbidden, action: forbidden, poll: forbidden, close: forbidden },
    sharePanelsController: { pause() {}, updateShareSheet: forbidden },
    runSessionScript: forbidden, dismissPostSnack() {}, rootContextCoordinator: { notify() {} } });
  const Reader = loader.loadFile('entry/src/main/ets/app/PinmonyBoardNativeReads.ets').PinmonyBoardNativeReads;
  const reader = Object.create(Reader.prototype);
  Object.assign(reader, { store: host.boardStore, collabEpoch: 0, collabRequests: new Set(['pending']),
    ports: { session: () => ({ authenticated: true }), active: () => true,
      network: () => ({ cancel: id => calls.push('cancel:' + id) }) },
    // Publishing the updated board is outside this dispatch test; cancellation and token changes are real.
    syncAuxiliary() { calls.push('board-published'); } });
  host.boardNativeReads = reader;
  if (!enabled) {
    await host.openBoardCollaborators(); host.pollBoardCollaborators(1);
    assert.equal(host.boardStore.collaborators, undefined, 'disabled open does not fabricate a panel');
    host.boardStore.collaborators = { busy: false, uncertain: false, phase: 'members' };
    const before = JSON.stringify(host.boardStore.collaborators);
    for (const action of ['save', 'send', 'permissions', 'invite', 'retry'])
      await reader.collaboratorsAction(action, 'synthetic');
    assert.equal(JSON.stringify(host.boardStore.collaborators), before, 'disabled actions retain state');
  }
  // Back/close is local cleanup even if the page or account is no longer current.
  reader.current = () => false;
  host.boardStore.collaborators = { busy: true, uncertain: false, phase: 'permissions' };
  host.closeBoardCollaborators(); assert.equal(host.boardStore.collaborators.phase, 'permissions');
  host.boardStore.collaborators.busy = false;
  host.closeBoardCollaborators(); assert.equal(host.boardStore.collaborators.phase, 'members');
  host.closeBoardCollaborators(); assert.equal(host.boardStore.collaborators, undefined);
  assert.equal(host.boardStore.collaboratorsToken, 2);
  assert.equal(reader.collabEpoch, 1); assert.equal(reader.collabRequests.size, 0);
  assert(calls.includes('cancel:pending'));
  host.boardStore.collaborators = { busy: false, uncertain: true, phase: 'permissions' };
  host.closeBoardCollaborators(); assert.equal(host.boardStore.collaborators, undefined);
  assert.equal(host.boardStore.collaboratorsToken, 3);
  const Share = loader.loadFile('entry/src/main/ets/app/PinmonyShareNativeFlow.ets').PinmonyShareNativeFlow;
  const share = Object.create(Share.prototype);
  Object.assign(share, { store: host.pinStore, busy: false, pending: '', page: 'old', id: '12', users: [{}],
    tracking: 'old', link: 'old', viewer: 'old', sent: new Set(['12']), unknown: new Set(), revision: 0, searchRevision: 0, timer: -1,
    ports: { session: () => ({ authenticated: true, accountId: 'old', generation: 1 }) }, account: 'old', generation: 1,
    client: { cancel: () => calls.push('share-cancel') }, contactsClient: { cancel: () => calls.push('contacts-cancel') } });
  host.shareNativeFlow = share;
  const retained = JSON.stringify(host.pinStore);
  host.updateShareSheet('{}'); assert.equal(JSON.stringify(host.pinStore), retained, 'legacy snapshots are ignored');
  host.dismissShareSheet();
  assert.equal(host.showNativeSheet, false); assert.equal(host.activeSheetKind, '');
  assert.equal(share.page, ''); assert.equal(share.id, ''); assert.equal(share.users.length, 0);
  assert.equal(share.revision, 1); assert.equal(host.pinStore.shareContacts.length, 0);
  assert(calls.includes('share-cancel') && calls.includes('contacts-cancel'));
  host.homeStore.customHomeMenu = { session: 8 }; host.homeStore.customHomeMenuToken = 0;
  host.activeSheetKind = 'share'; host.showNativeSheet = true;
  host.dismissShareSheet(); assert.equal(host.homeStore.customHomeMenu, undefined);
  assert.equal(host.showNativeSheet, false); assert.equal(host.homeStore.customHomeMenuToken, 1);
  const resetNames = ['businessSession', 'boardNativeReads', 'profileNativeReads', 'inboxUpdatesNativeReads',
    'inboxMessagesNativeReads', 'searchDiscoveryNativeReads', 'searchNativeReads', 'homeNativeReads'];
  const resets = [];
  for (const name of resetNames) host[name] = { reset: () => resets.push(name) };
  const setAccount = host.accountPort();
  assert.equal(setAccount('new'), 'new'); assert.deepEqual(resets, resetNames);
  setAccount('new'); assert.equal(resets.length, resetNames.length, 'unchanged identity is a no-op');
  setAccount(''); setAccount('another');
  assert.deepEqual(resets, [...resetNames, ...resetNames, ...resetNames], 'logout and first identity reset all owners');
}
(async () => {
  for (const [master, local] of [[true, false], [false, true], [false, false], [true, true]]) await scenario(master, local);
  console.log('Native cleanup isolation: actual Index, board cancellation, share closure and account resets remain native across local/master gates; writes stay locked and legacy callbacks are ignored');
})().catch(error => { console.error(error); process.exitCode = 1; });
