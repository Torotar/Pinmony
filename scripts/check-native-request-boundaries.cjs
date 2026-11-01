const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(name, master = true, local = true) {
  let source = fs.readFileSync('entry/src/main/ets/app/' + name + '.ets', 'utf8');
  source = source.replace(/(const PIN_NATIVE_\w+_ROLLOUT_ENABLED: boolean = )true;/g, '$1' + local + ';');
  const exports = {};
  const mocks = new Proxy({ PIN_BUSINESS_PIN_READ_ENABLED: master, PIN_POST_API_ENABLED: true,
    PIN_EDIT_API_ENABLED: true, PIN_NATIVE_PROFILE_SETTINGS_ENABLED: master && local,
    PIN_NATIVE_SHARE_PUBLISH_ENABLED: master && local, PinmonyI18n: { message: key => key },
    PinmonyRuntimeLog: { info() {}, warn() {} } }, { get: (target, key) => target[key] });
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: () => mocks, setTimeout, clearTimeout });
  return exports[name];
}
const forbidden = new Proxy({}, { get(_, key) { throw Error('unexpected dependency: ' + String(key)); } });
async function disabled(master, local) {
  for (const name of ['PinmonySharePublishClient', 'PinmonyProfileSettingsClient']) {
    const Client = load(name, master, local), client = new Client(forbidden);
    const args = name.includes('Share') ? [{}, '', '', {}, '', '', () => true] : ['', '', '', {}, '', () => true];
    await assert.rejects(client.request(...args), /disabled/);
    assert.equal(client.waits.size, 0, 'disabled request allocates no cancellation handle');
    client.cancel();
  }
  for (const name of ['PinmonySearchNativeReads', 'PinmonySearchDiscoveryNativeReads', 'PinmonyProfileNativeReads', 'PinmonyBoardNativeReads']) {
    const Reader = load(name, master, local), reader = Object.create(Reader.prototype);
    reader.ports = forbidden; reader.store = forbidden;
    assert.equal(reader.eligible(), false, name + ' stops before reading session');
    if (name === 'PinmonySearchNativeReads') assert.equal(reader.navigate('https://www.pinterest.com/search/?q=test'), false);
    if (name === 'PinmonyProfileNativeReads') assert.equal(await reader.select('hub:pins'), false);
    if (name === 'PinmonyBoardNativeReads') assert.equal(reader.bind(), false);
  }
  for (const [name, calls] of [
    ['PinmonySettingsNativeFlow', [['requestAction', ['read', '']]]],
    ['PinmonyProfileNativeActions', [['open', ['edit', 'users']], ['follow', ['12']], ['save', ['text']], ['organizeAction', ['read', '', false]]]],
    ['PinmonyShareNativeFlow', [['open', ['pin', 'https://www.pinterest.com/pin/12/', '12']]]],
    ['PinmonyPublishNativeFlow', [['menu', [() => true]], ['open', []], ['action', ['publish', '', false]]]]
  ]) {
    const Flow = load(name, master, local), flow = Object.create(Flow.prototype);
    flow.ports = forbidden; flow.store = forbidden;
    for (const [method, args] of calls) await flow[method](...args);
    if (name !== 'PinmonyPublishNativeFlow') assert.equal(flow.current(0), false);
  }
  const Menu = load('PinmonyPinMenuNative', master, local), menu = Object.create(Menu.prototype);
  menu.ports = forbidden; menu.store = forbidden;
  await menu.open(); await menu.action('home-see-less'); await menu.toggleFavorite('https://www.pinterest.com/pin/12/');
  await menu.undoFeedback();
  const state = await menu.photoRead(7, 'https://www.pinterest.com/pin/12/');
  assert.equal(state.loading, false); assert.equal(state.error, ''); assert.equal(state.actions.length, 0);
  assert.equal(menu.current(0), false, 'disabled menu cannot accept a late reply');
  await assert.rejects(menu.request({}, 0), /disabled/);

  const Discovery = load('PinmonySearchDiscoveryNativeReads', master, local), discovery = Object.create(Discovery.prototype);
  const cancelled = []; discovery.ports = { network: () => ({ cancel: id => cancelled.push(id) }) };
  discovery.store = {}; discovery.revision = 2; discovery.requestId = 'pending'; discovery.busy = true;
  discovery.pause(); assert.deepEqual(cancelled, ['pending']); assert.equal(discovery.revision, 3);
  assert.equal(discovery.busy, false); assert.equal(discovery.store.searchDiscoveryReadsReady, false);

  const Board = load('PinmonyBoardNativeReads', master, local), board = Object.create(Board.prototype);
  let pauses = 0;
  for (const key of ['followWrites', 'sectionWrites', 'contentWrites', 'managementWrites', 'pinWrites', 'collaboratorWrites']) board[key] = { pause() { pauses++; } };
  board.ports = discovery.ports; board.store = { boardDetail: { loadingMore: true, refreshing: true } };
  for (const key of ['revision', 'version', 'sectionEpoch', 'flowEpoch', 'collabEpoch']) board[key] = 0;
  for (const key of ['requests', 'sectionRequests', 'flowRequests', 'collabRequests']) board[key] = new Set(key === 'requests' ? ['board-pending'] : []);
  board.pause(); assert.equal(pauses, 6); assert.equal(board.revision, 1);
  assert.equal(board.store.boardDetail.refreshing, false); assert.equal(board.requests.size, 0);
  assert(cancelled.includes('board-pending'));

  const Post = load('PinmonyPostNativeOperations', master, local), post = Object.create(Post.prototype);
  let released = false; post.ports = discovery.ports; post.store = { viewerSaveBusy: true };
  post.markUnknown = () => {}; post.requests = new Set(['post-pending']); post.waits = new Map([['pending', () => { released = true; }]]);
  post.revision = 4; post.busy = false; post.pause();
  assert(released); assert.equal(post.revision, 5); assert.equal(post.store.viewerSaveBusy, false);
  assert(cancelled.includes('post-pending'));
}
(async () => {
  await disabled(true, false); await disabled(false, true); await disabled(false, false);
  const Root = load('PinmonyRootContextCoordinator'), root = Object.create(Root.prototype);
  root.ports = new Proxy({ nativeBusinessOnly: () => true, businessSuspended: () => false,
    authStatus: () => 'authenticated', activeTab: () => 0, activeSheetKind: () => '' },
    { get: (target, key) => key in target ? target[key] : forbidden[key] });
  root.pinStore = {};
  for (let tab = 0; tab < 4; tab++) {
    root.requestRootPage(tab); assert.equal(root.prepareRootPageRead(tab), true);
    assert.equal(await root.ensureRootActionContext(tab), false);
  }
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert.match(index, /new PinmonyRootContextCoordinator\(\{\s*nativeBusinessOnly: \(\): boolean => this.nativeBusinessRoutesEnabled/);
  console.log('Native request boundaries: local/master disabled requests, preserved state, late menu rejection, unconditional cleanup and native root Web isolation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
