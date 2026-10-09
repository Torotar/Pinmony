const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const compile = code => ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const source = readSourceFileSync('entry/src/main/ets/services/PinWebConfirmedSaves.ets', 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
const context = {};
vm.runInNewContext(compile(source + '\nglobalThis.Saves = PinWebConfirmedSaves;'), context);
const saves = new context.Saves();
const fresh = { pinUrl: 'pin1', session: 9, actions: [{ id: 's', kind: 'save', selected: false, enabled: true },
  { id: 'l', kind: 'like', selected: true, enabled: false }] };
saves.confirm('1', true);
const reopened = saves.apply('1', fresh);
assert.equal(reopened.actions[0].selected, true);
assert.equal(reopened.actions[0].label, '已收藏');
assert.equal(fresh.actions[0].selected, false, 'Do not mutate incoming snapshots');
assert.equal(reopened.actions[1].selected, true);
assert.equal(saves.apply('2', fresh).actions[0].selected, false, 'Other Pins stay independent');
saves.confirm('1', false);
assert.equal(saves.apply('1', reopened).actions[0].selected, false);
saves.clear();
assert.equal(saves.apply('1', fresh).actions[0].selected, false, 'Session reset removes prior evidence');
const index = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const method = index.match(/  private beginDetailOpening\([^\n]*\): void \{[\s\S]*?(?=\r?\n  private restoreCachedDetail)/)[0];
const events = [];
const navContext = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: false,
  PINTEREST_URL: 'https://www.pinterest.com/', clearTimeout() {}, setTimeout() {}, PinWebRuntimeLog: { info() {} } };
vm.runInNewContext(compile('class Native { ' + method + ' } globalThis.Native = Native;'), navContext);
const native = new navContext.Native();
native.detailJourney = { begin() {}, mark() {} };
Object.assign(native, { nativeBackTarget: 'home', pageBackToken: 3, detailOpeningToken: 1,
  detailPrefetchTimer: -1, clearRootTabGuard() {},
  supersedeRootPreparationForDetail() { this.pageBackToken++; }, pageTasks: { cancelTimeout() {} },
  pinStore: { detailPrefetch: { pause() {}, cancelExcept() {} }, rememberDetailOrigin() {}, detailOrigin: () => 'home' },
  closeImageLayer: () => events.push('close-image-layer'),
  pinIdentity: pin => pin, clearDetail: () => events.push('clear'), restoreCachedDetail: () => events.push('cache'),
  pageHistory: { visit: target => events.push('commit:' + target), cancelBack: () => events.push('cancel') } });
native.beginDetailOpening('pin1');
assert.equal(native.nativeBackTarget, '');
assert.equal(native.detailOpeningPin, 'pin1');
assert.equal(native.pageBackToken, 4);
assert.deepEqual(events, ['close-image-layer', 'commit:home', 'cancel', 'commit:pin1', 'clear', 'cache']);
assert(index.includes('this.confirmedSaves.clear();'));
console.log('Confirmed save/reopen: fresh document state, Pin isolation, undo, session reset and pending return supersession passed');
