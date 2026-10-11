const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const read = file => fs.readFileSync((process.argv[3] ? process.argv[3] + '/' : '') + file, 'utf8');
const source = read('entry/src/main/ets/pages/Index.ets');
const postSource = read('feature_pin/src/main/ets/services/PinmonyPostApiScript.ets');
const logSource = fs.readFileSync('common_foundation/src/main/ets/services/PinmonyRuntimeLog.ets', 'utf8');
function method(name) {
  const pattern = new RegExp('  private(?: async)? ' + name + '\\(');
  const start = source.search(pattern);
  assert(start >= 0, name + ' exists');
  const next = source.slice(start + 1).search(/\n  (?:private |@Builder)/);
  assert(next >= 0);
  return source.slice(start, start + 1 + next);
}
const start = Math.min(...['releasePostSnack', 'dismissPostSnack'].map(name => source.indexOf('  private ' + name + '(')).filter(value => value >= 0));
const end = source.indexOf('  private async undoSavedPin()', start);
const sanitize = logSource.slice(logSource.indexOf('  static sanitize('), logSource.indexOf('  static initialize('));
const presentations = [], logs = [], messages = [], copies = [];
let now = 1000, current = 'https://www.pinterest.com/pin/101/', copyResolve, copyReject;
class HdsSnackBar {
  show(icon, message, operation, style) { presentations.push({ title: message.title, operation, style }); }
  dismiss() {}
}
const nativeContext = { HdsSnackBar, SnackBarOperationType: { TEXT_WITH_CLOSE: 3, CLOSE_BUTTON_ONLY: 1 }, Date: { now: () => now } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Log { ' + sanitize + ' } globalThis.Log = Log;', {}).outputText, nativeContext);
nativeContext.PinmonyRuntimeLog = { info: text => logs.push(nativeContext.Log.sanitize(text)), warn: text => logs.push(nativeContext.Log.sanitize(text)) };
const nativeCode = 'class Native { ' + source.slice(start, end) + method('updateShareSheet') + method('handlePostResult') + ' } globalThis.Native = Native;';
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(nativeCode, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, nativeContext);
const native = new nativeContext.Native();
Object.assign(native, { postSnackToken: 0, homeStore: {}, profileStore: {}, inboxStore: {},
  pinStore: { shareSession: 1, sharePin: current, shareFeedback: '', shareError: '', shareFeedbackSnackKey: '', shareSnackKey: '', shareOptions: [], shareActions: [] },
  activeSheetKind: 'share', showNativeSheet: true, getUIContext: () => ({}),
  isCurrentMorePin: pin => pin === current, extractPinUrl: pin => pin, pinIdentity: pin => /\/pin\/(\d+)\//.exec(pin)?.[1] || '',
  isCopyLinkAction: label => label === '复制链接', suspendMoreForShare: () => {},
  showMessage: message => messages.push(message), onBackPress: () => { native.dismissPostSnack(); native.activeSheetKind = ''; },
  systemActions: { copyText: value => { copies.push(value); return new Promise((resolve, reject) => { copyResolve = resolve; copyReject = reject; }); } } });

native.authStatus = 'authenticated'; native.controller = { getUrl: () => current };
require('./pin-priority-controller-harness.cjs').bind(native, ts, nativeContext);
const pin = current, requests = [], pendingCopies = [];
let rawPin = { id: '101', title: 'Synthetic current Pin' };
const snapshot = () => ({ kind: 'state', session: 1, pinUrl: pin, pinDetail: true, options: [{ id: 'copy', label: '复制链接', enabled: true }], actions: [], contacts: [] });
const window = { PinmonyPostApiEnabled: true, PinmonyDetailApi: { raw: () => rawPin }, PinmonyShareBridge: {
  postState: text => pendingCopies.push(native.handlePostResult(text))
} };
window.top = window;
window.fetch = async (url, options) => { requests.push({ url, options }); return { ok: true, status: 200,
  json: async () => ({ resource_response: { status: 'success', code: 0, data: [] } }) }; };
class XHR { open() {} send() {} setRequestHeader() {} addEventListener() {} }
const context = { window, document: { cookie: '' }, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/pin/101/', href: pin },
  URL, URLSearchParams, Headers, XMLHttpRequest: XHR, AbortController, setTimeout, clearTimeout, fetch: (...args) => window.fetch(...args) };
const script = Function('return `' + postSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
require('./product-coordination-harness.cjs').run(ts,script, context);
const api = window.PinmonyPostApi;
const update = () => native.updateShareSheet(JSON.stringify(api.shareSnapshot(snapshot(), update)));
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  update();
  assert.equal(presentations.length, 0, 'contact loading stays inside the share panel');
  await flush();
  assert.equal(presentations.length, 0, 'empty contacts are not an action-result popup');
  assert(api.shareAction(1, 'copy'));
  await flush();
  assert.equal(copies.at(-1), pin, 'existing identity-validated canonical link is still usable');
  assert.equal(api.shareSnapshot(snapshot(), update).error, '', 'canonical copy is not a failed invitation');
  assert.equal(presentations.length, 0, 'processing and bridge delivery do not claim clipboard success');
  copyResolve(); await Promise.all(pendingCopies.splice(0));
  assert.deepEqual(presentations.map(item => item.title), ['链接已复制']);
  assert.equal(native.pinStore.shareError, '');
  assert.equal(requests.length, 1, 'no new invitation/write request or DOM fallback');

  // A real clipboard rejection must produce failure, never copied success.
  now += 9000; update();
  assert(api.shareAction(1, 'copy')); await flush();
  copyReject(new Error('synthetic clipboard failure')); await Promise.all(pendingCopies.splice(0));
  assert.equal(presentations.length, 1);
  assert.equal(messages.at(-1), '复制链接失败，请重试');

  // Closing the sheet, changing session or switching Pin during the system call cannot show a late success.
  for (const stale of ['sheet', 'session', 'pin']) {
    current = pin; native.activeSheetKind = 'share'; native.pinStore.shareSession = 1; update();
    assert(api.shareAction(1, 'copy')); await flush();
    if (stale === 'sheet') native.activeSheetKind = '';
    if (stale === 'session') native.pinStore.shareSession = 2;
    if (stale === 'pin') current = 'https://www.pinterest.com/pin/102/';
    copyResolve(); await Promise.all(pendingCopies.splice(0));
    assert.equal(presentations.length, 1, 'late ' + stale + ' success discarded');
  }
  current = pin; native.activeSheetKind = 'share'; native.pinStore.shareSession = 1;
  rawPin = { id: '102' }; update();
  const copyCount = copies.length;
  assert(api.shareAction(1, 'copy')); await flush();
  assert.equal(copies.length, copyCount, 'a mismatching raw Pin cannot supply the fallback link');
  assert.match(api.shareSnapshot(snapshot(), update).error, /尚未就绪/);
  const retryPresentation = presentations.at(-1);
  assert.equal(retryPresentation.style.duration, 4000);

  assert(logs.some(line => /PostSnack: prepared snackSeq=\d+/.test(line)), 'local sequence survives real export sanitizer');
  assert(logs.every(line => !/PostSnack:.*\[credential\]/.test(line)));
  assert.equal(nativeContext.Log.sanitize('token=secret Cookie=secret csrf=secret').includes('secret'), false, 'credential redaction remains');
  console.log('Share feedback: real script → real Index, process/empty states, canonical copy, failure, stale sheet/session/Pin, missing context and sanitized sequence passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
