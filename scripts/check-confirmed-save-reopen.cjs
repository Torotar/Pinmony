const { readSourceFileSync } = require('./source-files.cjs');
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const compile = code => ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const source = readSourceFileSync('entry/src/main/ets/services/PinmonyConfirmedSaves.ets', 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
const context = {};
require('./product-coordination-harness.cjs').run(ts,compile(source + '\nglobalThis.Saves = PinmonyConfirmedSaves;'), context);
const saves = new context.Saves();
const fresh = { pinUrl: 'pin1', session: 9, actions: [{ id: 's', kind: 'save', selected: false, enabled: true },
  { id: 'l', kind: 'like', selected: true, enabled: false }] };
saves.confirm('1', true, '801');
assert.equal(saves.copyId('1'), '801');
assert.equal(saves.copyId('2'), '');
const reopened = saves.apply('1', fresh);
assert.equal(reopened.actions[0].selected, true);
assert.equal(reopened.actions[0].label, '已收藏');
saves.confirm('1', true, '801', '旅行 Travel');
assert.equal(saves.apply('1', fresh).actions[0].label, '旅行 Travel', 'confirmed destination is displayed verbatim after reopening');
saves.confirm('1', true);
assert.equal(saves.apply('1', fresh).actions[0].label, '旅行 Travel', 'later saved-state evidence retains the confirmed destination');
assert.equal(fresh.actions[0].selected, false, 'Do not mutate incoming snapshots');
assert.equal(reopened.actions[1].selected, true);
const progressive = { ...fresh, mediaLoading: true, mediaKind: 'video', commentLoading: true,
  imageStageReady: true, relatedRetained: true };
const merged = saves.apply('1', progressive);
for (const key of ['mediaLoading', 'mediaKind', 'commentLoading', 'imageStageReady', 'relatedRetained'])
  assert.equal(merged[key], progressive[key], 'save evidence must preserve progressive state: ' + key);
assert.equal(saves.apply('2', fresh).actions[0].selected, false, 'Other Pins stay independent');
saves.confirm('1', false);
assert.equal(saves.copyId('1'), '');
assert.equal(saves.apply('1', reopened).actions[0].selected, false);
assert.equal(saves.apply('1', reopened).actions[0].label, '收藏', 'unsave clears the destination label');
saves.confirm('1', true, '802'); saves.clear();
assert.equal(saves.copyId('1'), '', 'session reset clears saved-copy identities');
assert.equal(saves.apply('1', fresh).actions[0].selected, false, 'Session reset removes prior evidence');
const index = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const boardOpenBody = index.match(/openPin: \(pin: PinmonyBoardPin, board: PinmonyBoardDetail\): void => \{([\s\S]*?)\n    \}/)[1];
const boardHost = { cancelledBoardPins: new Set(), pinStore: { confirmedSaves: saves, rememberDetailOrigin() {} },
  pinIdentity: () => '42', beginDetailOpening() {
    assert.equal(saves.apply('42', fresh).actions[0].label, '风景 Landscape', 'board title is available before detail opening');
  } };
vm.runInNewContext(compile('(function(pin,board){' + boardOpenBody + '}).call(host,pin,board)'), {
  host: boardHost, pin: { pinUrl: 'https://www.pinterest.com/pin/42/' },
  board: { pageKey: 'https://www.pinterest.com/test/landscape/', title: '风景 Landscape' }, PIN_NATIVE_DETAIL_READS_ENABLED: true
});
const method = index.match(/  private beginDetailOpening\([^\n]*\): void \{[\s\S]*?(?=\r?\n  private restoreCachedDetail)/)[0];
const events = [];
const navContext = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: false,
  PINTEREST_URL: 'https://www.pinterest.com/', clearTimeout() {}, setTimeout() {}, PinmonyRuntimeLog: { info() {} } };
require('./product-coordination-harness.cjs').run(ts,compile('class Native { ' + method + ' } globalThis.Native = Native;'), navContext);
const native = require('./product-coordination-harness.cjs').createHost(navContext.Native, ts, navContext);
native.detailJourney = { begin() {}, mark() {} };
Object.assign(native, {
    nativeBackTarget: 'home', pageBackToken: 3,
    detailPrefetchTimer: -1, clearRootTabGuard() { },
    supersedeRootPreparationForDetail() { this.pageBackToken++; }, pageTasks: { cancelTimeout() { } },
    closeImageLayer: () => events.push('close-image-layer'),
    pinIdentity: pin => pin, clearDetail: () => events.push('clear'), restoreCachedDetail: () => events.push('cache'),
    pageHistory: { visit: target => events.push('commit:' + target), cancelBack: () => events.push('cancel') },
    pinStore: Object.assign(native.pinStore, { detailPrefetch: { pause() { }, cancelExcept() { } }, rememberDetailOrigin() { }, detailOrigin: () => 'home' }, {
        detailOpeningToken: 1
    })
});
require('./medium-priority-controller-harness.cjs').bindWork(native, ts, navContext);
native.beginDetailOpening('pin1');
assert.equal(native.nativeBackTarget, '');
assert.equal(native.pinStore.detailOpeningPin, 'pin1');
assert.equal(native.pageBackToken, 4);
assert.deepEqual(events, ['close-image-layer', 'commit:home', 'cancel', 'commit:pin1', 'clear', 'cache']);
assert(fs.readFileSync('entry/src/main/ets/app/PinmonySessionCoordinator.ets','utf8').includes('this.pinStore.confirmedSaves.clear();'));
console.log('Confirmed save/reopen: fresh document state, Pin isolation, undo, session reset and pending return supersession passed');
