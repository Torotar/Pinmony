const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), ts = require(process.argv[2]);
const transpile = code => require('./native-network-test-fixture.cjs').transpile(ts, code, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
const bytes = value => { const b = Buffer.from(JSON.stringify(value)); return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength); };
const success = () => bytes({ resource_response: { status: 'success', code: 0, endpoint_name: 'v3_delete_lens_histories', data: null } });
const photo = id => ({ id, imageUrl: 'https://i.pinimg.com/test.jpg', width: 200, height: 300 });
const flowSource = fs.readFileSync('entry/src/main/ets/app/PinmonyPhotoSearchFlow.ets', 'utf8').replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
const Flow = vm.runInNewContext(transpile(flowSource + '\nPinmonyPhotoSearchFlow;'), {
  util: { TextDecoder: { create: () => ({ decodeToString: data => Buffer.from(data).toString('utf8') }) } },
  parsePhotoHistory: () => ({ items: [photo('one'), photo('two')], cursor: '', ended: true })
});
function method(source, name) {
  const tree = ts.createSourceFile('source.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
  let result;
  function visit(n) { if (ts.isMethodDeclaration(n) && n.name.getText(tree) === name) result = n.getText(tree); ts.forEachChild(n, visit); }
  visit(tree); assert(result, name); return result;
}
const uiSource = fs.readFileSync('feature_search/src/main/ets/components/PinmonyPhotoHistoryPage.ets', 'utf8');
const UI = vm.runInNewContext(transpile('class UI {' + ['visibleItems', 'deletePhotos', 'deleteAllPhotos', 'restorePhoto', 'back', 'changeManagement', 'enterManagement'].map(n => method(uiSource, n)).join('\n') + '} UI;'), { Curve: { EaseIn: 0, EaseOut: 1 } });
const networkSource = fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets', 'utf8');
const requests = [];
let response = { statusCode: 200, body: success(), headers: {} };
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, {
  common_foundation: {PinmonyRuntimeLog:{info(){},warn(){}}},
  common_session: {PinmonySessionCredentials:class {}},
  '@kit.RemoteCommunicationKit': {rcp: {Request: class {constructor(url,method,headers,body){Object.assign(this,{url,method,headers,body});}}, MultipartForm: class {constructor(fields){this.fields=fields;}}}},
  '@kit.BasicServicesKit': {}
}, {PinmonyTestTransportOnly:true});
const core=loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
core.NetworkManager.enqueue=(_,call)=>call();core.NetworkManager.requestRemainingMs=()=>0;
core.NetworkManager.getSession=()=>({fetch:async request=>{requests.push(request); return response;}});
const {PinmonyBusinessNetwork:Network}=loader.loadFile('entry/src/main/ets/app/PinmonyBusinessNetwork.ets');
(async () => {
  const origin = 'https://www.pinterest.com', session = { authenticated: true, accountId: 'synthetic-account', generation: 1, origin, userAgent: 'test-agent' };
  const network = new Network();
  Object.assign(network, { foreground: true, generation: 1, cancelled: new Set(), pending: new Set(), jobs: new Map(),
    credentials: { read: async () => 'csrftoken=synthetic-csrf', update: async () => {} } });
  await network.deletePhotoHistory(['one'], origin + '/search/', () => session, () => true, 'native_photo_history_delete_1');
  assert.equal(requests.length, 1); const request = requests[0];
  assert.equal(request.method, 'POST'); assert.equal(new URL(request.url).pathname, '/resource/ApiResource/delete/');
  assert.deepEqual(JSON.parse(new URLSearchParams(request.body).get('data')).options, { url: '/v3/visual_search/lens/history/', data: { lens_history_ids: ['one'] } });
  assert.equal(request.headers['X-CSRFToken'], 'synthetic-csrf'); assert.equal(network.pending.size, 0);
  for (const ids of [[], ['one', 'one'], ['bad/id']]) await assert.rejects(network.deletePhotoHistory(ids, origin + '/search/', () => session, () => true, 'native_photo_history_delete_2'));
  await assert.rejects(network.deletePhotoHistory(['one'], origin + '/search/', () => session, () => false, 'native_photo_history_delete_3'));
  assert.equal(requests.length, 1, 'invalid/stale intentions do not send writes');
  response = { statusCode: 500, body: success(), headers: {} };
  await assert.rejects(network.deletePhotoHistory(['one'], origin + '/search/', () => session, () => true, 'native_photo_history_delete_4'));
  let writes = 0, resolveWrite;
  const transport = { cancel() {}, readPhotoHistory: async () => new ArrayBuffer(0), deletePhotoHistory: async () => { writes++; return new Promise(resolve => { resolveWrite = resolve; }); } };
  const ports = { session: () => session, network: () => transport, page: () => origin + '/search/', active: () => true };
  const flow = new Flow(ports); await flow.history('');
  await assert.rejects(flow.deleteHistory(['foreign'])); assert.equal(writes, 0);
  let operation = flow.deleteHistory(['one']);
  await assert.rejects(flow.deleteHistory(['one'])); assert.equal(writes, 1, 'duplicate pending delete is blocked');
  resolveWrite(success()); await operation;
  await assert.rejects(flow.deleteHistory(['one'])); assert.equal(writes, 1, 'confirmed deletion cannot be submitted twice');
  operation = flow.deleteHistory(['two']); resolveWrite(bytes({ resource_response: { status: 'success', code: 0, endpoint_name: 'wrong', data: null } }));
  await assert.rejects(operation); await assert.rejects(flow.deleteHistory(['two'])); assert.equal(writes, 2, 'unconfirmed write is locked against replay');
  const stale = new Flow(ports); await stale.history(''); operation = stale.deleteHistory(['one']); stale.cancel(); resolveWrite(success()); await assert.rejects(operation);
  let uiWrites = 0;
  const ui = new UI(); Object.assign(ui, { alive: true, managing: true, managementAnimating: false, managementMotionVersion: 0, getUIContext: () => ({ animateTo: (options, update) => { update(); options.onFinish(); } }), deleting: false, busy: false, confirming: false, pendingIds: [], uncertainIds: [], items: [photo('one')], ended: false, cursor: 'next', syncSections() {},
    onDelete: async ids => { uiWrites++; return new Promise(resolve => { resolveWrite = resolve; }); },
    onLoad: async () => ({ items: [photo('two')], cursor: '', ended: true }) });
  ui.deletePhotos(['foreign']); assert.equal(ui.pendingIds.length, 0);
  ui.deletePhotos(['one']); assert.equal(ui.pendingIds[0], 'one'); assert.equal(uiWrites, 0, 'marking does not send a request');
  assert.equal(ui.visibleItems().length, 1, 'management retains original card position');
  ui.restorePhoto('one'); assert.equal(ui.pendingIds.length, 0, 'undo cancels unsent deletion'); assert.equal(uiWrites, 0);
  ui.deletePhotos(['one']); ui.deletePhotos(['one']); assert.equal(ui.pendingIds.length, 1);
  operation = ui.back(); assert.equal(uiWrites, 1); assert.equal(ui.managing, true, 'stay until confirmed');
  ui.restorePhoto('one'); assert.equal(ui.pendingIds.length, 1, 'no undo during submission');
  await ui.back(); assert.equal(uiWrites, 1, 'repeat back does not duplicate writes');
  resolveWrite(); await operation; assert.equal(ui.managing, false); assert.equal(ui.items.length, 0); assert.equal(ui.pendingIds.length, 0);
  ui.managing = true; ui.items = [photo('one')]; ui.ended = false;
  await ui.deleteAllPhotos(); assert.equal(ui.pendingIds.join(','), 'one,two', 'all pages staged'); assert.equal(uiWrites, 1, 'delete all also waits for exit');
  ui.restorePhoto('one'); assert.equal(ui.pendingIds.join(','), 'two');
  ui.onDelete = async ids => { uiWrites++; assert.equal(ids.join(','), 'two'); throw new Error('timeout'); };
  await ui.back(); assert.equal(ui.managing, true, 'failure retains management'); assert.equal(ui.items.length, 2);
  assert.equal(ui.actionError, 'pm_photo_history_delete_unconfirmed'); assert(ui.uncertainIds.includes('two'));
  ui.restorePhoto('two'); assert.equal(ui.pendingIds.join(','), 'two', 'ambiguous sent operation cannot be locally undone');
  await ui.back(); assert.equal(uiWrites, 2, 'ambiguous write is never replayed');
  ui.pendingIds = []; ui.uncertainIds = []; ui.ended = false; ui.cursor = 'loop'; ui.items = [photo('one')];
  ui.onLoad = async () => ({ items: [photo('two')], cursor: 'loop', ended: false });
  await ui.deleteAllPhotos(); assert.equal(ui.pendingIds.length, 0); assert.equal(ui.actionError, 'pm_photo_history_delete_all_incomplete');
  ui.busy = false; ui.pendingIds = []; ui.uncertainIds = []; await ui.back(); assert.equal(ui.managing, false); assert.equal(uiWrites, 2, 'empty exit sends nothing');
  assert(!uiSource.includes("Text(this.text('pm_photo_history_delete_all'))"), 'delete all stays an icon button');
  const frames = [];
  const motion = new UI(); Object.assign(motion, { alive: true, managing: false, managementAnimating: false, managementMotionVersion: 0,
    historyVisible: true, managementVisible: false, items: [photo('one'), photo('two')], pendingIds: ['one'], syncSections() {},
    getUIContext: () => ({ animateTo: (options, update) => { update(); frames.push(options.onFinish); } }) });
  motion.enterManagement(); assert.equal(motion.managementAnimating, true); assert.equal(motion.managing, true);
  assert.equal(motion.historyVisible, true, 'old history remains mounted during incoming animation');
  assert.equal(motion.managementVisible, true);
  motion.enterManagement(); assert.equal(frames.length, 1, 'repeat entry blocked');
  frames.shift()(); assert.equal(motion.historyVisible, false); assert.equal(motion.managementAnimating, false);
  motion.changeManagement(false, ['one']); assert.equal(motion.items.length, 1);
  assert.equal(motion.historyVisible, true); assert.equal(motion.managementVisible, true, 'old management retained underneath');
  frames.shift()(); assert.equal(motion.managementVisible, false); assert.equal(motion.managementAnimating, false);
  motion.changeManagement(true); motion.alive = false; frames.shift()(); assert.equal(motion.historyVisible, true, 'stale completion cannot unmount retained page');
  assert(!uiSource.includes('managementOffset') && !uiSource.includes('managementOpacity'), 'no custom outgoing slide or fade');
  assert(uiSource.includes('curve: Curve.EaseOut }), TransitionEffect.IDENTITY'), 'existing incoming-only transition contract');
  assert(!uiSource.includes('onRestore'), 'no invented restore transport');
  assert(!uiSource.includes('sys.symbol.checkmark'), 'no checkmark remains');
  const titleStart = uiSource.indexOf('.titleBar(PinmonyHdsTitleBar.resolve(');
  assert(titleStart >= 0, 'history title uses the shared theme-aware resolver');
  assert(uiSource.slice(titleStart).includes("icon: new SymbolGlyphModifier($r('sys.symbol.trash'))"), 'trash action occupies title menu');
  assert(!uiSource.includes('Blank().layoutWeight(1)'), 'body toolbar removed');
  console.log('Photo history delete: captured transport, session/ID gates, validated results, duplicates/uncertain/stale writes, card feedback and complete pagination passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
