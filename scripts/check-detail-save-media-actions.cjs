const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private async ' + name + '(');
  assert(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const context = { PIN_POST_API_ENABLED: true, PIN_POST_EXTENSIONS_ENABLED: true,
  PinmonyRuntimeLog: { info() {} }, setTimeout };
vm.runInNewContext(ts.transpileModule(`class Native {
  ${['performDetailAction', 'cancelDetailSave', 'retryDetailMedia'].map(method).join('\n')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const pin = 'https://www.pinterest.com/pin/101/';
function harness(selected = true) {
  const native = new context.Native(), events = [];
  Object.assign(native, { authStatus: 'authenticated', authEpoch: 3,
    pinStore: { detail: { kind: 'state', pinUrl: pin, actions: [{ id: 'api-save', kind: 'save', enabled: true, selected }] },
      detailSession: 5, detailOpeningToken: 7, detailActionsReady: true, detailPresentationOnly: false, viewerSaveBusy: false, saveCancelToken: 0,
      detailMediaRetryToken: 0, detailMediaRetryBusy: false,
      confirmedSaves: { copyId: () => '' } },
    pinIdentity: value => value.match(/\/pin\/(\d+)/)?.[1] || '', currentPinUrl: () => pin,
    rejectOfflineAction: () => false, traceAction() {}, webJsonText: value => value,
    detailJourney: { mark: event => events.push(event) },
    showMessage: message => events.push('message:' + message),
    openApiBoards: async () => events.push('boards'), undoSavedPin: async () => events.push('delete:' + native.pinStore.saveUndoId),
    ensureDetailActionContext: async () => true,
    controller: { runJavaScript: async script => {
      events.push(script);
      if (script.includes('.saveUndo(')) { events.push('delete:802'); return 'true'; }
      if (script.includes('savedUndoRead')) return JSON.stringify({ status: 'done' });
      return JSON.stringify({ id: '802' });
    } } });
  return { native, events };
}
async function main() {
  const saved = harness(); await saved.native.performDetailAction('api-save', 'save');
  assert(saved.events.includes('delete:802')); assert(!saved.events.includes('boards'));
  const fresh = harness(false); await fresh.native.performDetailAction('api-save', 'save');
  assert.deepEqual(fresh.events, ['boards']);
  const reopen = harness(); let reads = 0;
  reopen.native.pinStore.confirmedSaves.copyId = () => '802';
  reopen.native.controller.runJavaScript = async script => {
    reopen.events.push(script);
    if (script.includes('savedRestoreStart')) return 'true';
    if (script.includes('savedRestoreRead')) return JSON.stringify({ operation: 1, status: 'ready' });
    if (script.includes('savedRestoreClose')) return 'undefined';
    if (script.includes('.saveUndo(')) { reopen.events.push('delete:802'); return 'true'; }
    if (script.includes('savedUndoRead')) return JSON.stringify({ status: 'done' });
    return JSON.stringify(++reads === 1 ? null : { id: '802' });
  };
  await reopen.native.performDetailAction('api-save', 'save');
  assert(reopen.events.some(event => event.includes('savedRestore')));
  assert(reopen.events.includes('delete:802'));
  const late = harness(); let deliver;
  late.native.controller.runJavaScript = () => new Promise(resolve => deliver = resolve);
  const pending = late.native.performDetailAction('api-save', 'save');
  await late.native.performDetailAction('api-save', 'save');
  late.native.authEpoch++; deliver(JSON.stringify({ id: '802' })); await pending;
  assert(!late.events.some(event => event.startsWith('delete:')), 'late reads and duplicate intent cannot delete');
  const media = harness(); media.native.pinStore.detailPresentationOnly = true;
  media.native.ensureDetailActionContext = async () => {
    media.events.push('prepare'); media.native.pinStore.detail.mediaLoading = true; return true;
  };
  await media.native.retryDetailMedia(); assert.deepEqual(media.events, ['prepare'], 'fresh preparation owns its media request');
  media.native.pinStore.detailPresentationOnly = false; media.native.pinStore.detail.mediaLoading = false;
  media.native.pinStore.detail.video = { sources: [] };
  media.native.ensureDetailActionContext = async () => true;
  media.native.controller.runJavaScript = async script => { media.events.push(script);
    return script.includes('mediaRetryRead') ? JSON.stringify({ operation: 2, status: 'ready' }) : 'true'; };
  await media.native.retryDetailMedia();
  assert(media.events.some(event => event.includes('retryMedia')), 'playback failure can reread an existing source');
  const moved = harness(); moved.native.ensureDetailActionContext = async () => {
    moved.native.pinStore.detail.pinUrl = 'https://www.pinterest.com/pin/999/'; return true;
  };
  await moved.native.retryDetailMedia(); assert.equal(moved.events.length, 0, 'new Pin rejects old media intent');
  console.log('Detail save/media actions: toggle, verified copy restoration, duplicate/stale guards and retained media preparation passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
