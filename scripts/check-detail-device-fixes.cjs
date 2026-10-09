const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts;
try { ts = require('typescript'); }
catch (_) {
  if (!process.argv[2]) throw new Error('Pass the DevEco TypeScript module path as the first argument');
  ts = require(process.argv[2]);
}
const index = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const base = readSourceFileSync('entry/src/main/ets/services/PinWebPostApiScript.ets', 'utf8');
const pin = 'https://www.pinterest.com/pin/101/';
const messages = [], requests = [];
const window = { PinWebPostApiEnabled: true, PinWebPostExtensionsEnabled: true,
  PinWebDetailApi: { raw: () => ({ id: '101', reaction_by_me: 1 }) },
  PinWebShareBridge: { sheetState: value => messages.push(JSON.parse(value)) }, addEventListener() {} };
window.top = window;
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/pin/101/', href: pin };
const document = { cookie: 'csrftoken=current', addEventListener() {}, querySelectorAll: () => [],
  getElementById: () => ({}), documentElement: null };
class XHR { open() {} send() {} setRequestHeader() {} addEventListener() {} }
window.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }));
const context = { window, location, document, URL, URLSearchParams, Headers, AbortController, XMLHttpRequest: XHR,
  fetch: (...args) => window.fetch(...args), setTimeout, clearTimeout, console };
function template(source, pattern) { return Function('return `' + source.match(pattern)[1] + '`')(); }
vm.runInNewContext(template(base, /= `([\s\S]*?)`;/), context);
const sharePanel = readSourceFileSync('feature_pin/src/main/ets/services/PinWebSharePanelScript.ets', 'utf8');
vm.runInNewContext(template(sharePanel, /const SHARE_PANEL_BRIDGE_SCRIPT: string = `([\s\S]*?)`;/), context);
const api = window.PinWebPostApi;
api.savedRead = () => null;
const actions = api.detailActions(pin, [], () => {});
assert.equal(actions.find(item => item.kind === 'save').enabled, true, 'API save exists without any DOM button');
assert.equal(actions.find(item => item.kind === 'share').enabled, true);
api.savedRead = () => ({ id: '707' });
assert.equal(api.detailActions(pin, [], () => {}).find(item => item.kind === 'save').label, '已收藏');
assert.equal(window.PinWebNativeShareApiOpen(pin), true);
const first = messages.at(-1);
assert.equal(first.kind, 'state', 'First share publication is ready, with no DOM opening phase');
assert.deepEqual(first.options.map(item => item.label), ['Messenger', 'WhatsApp', '短信', 'Facebook', 'X']);
assert.equal(first.actions[0].label, '复制链接');
assert.match(first.feedback, /加载联系人/);
assert.equal(window.PinWebNativeShareApiOpen(pin.replace('101', '999')), false);
assert.equal(window.PinWebNativeShareClose(first.session), true);
assert.equal(messages.at(-1).kind, 'closed');
const messageCount = messages.length;
const flush = () => new Promise(resolve => setImmediate(resolve));
function method(name, next) {
  return index.slice(index.indexOf('  private ' + name), index.indexOf('  private ' + next));
}
const nativeClass = 'class Native { ' + method('webJsonText', 'async openApiComments') +
  method('isCurrentMorePin', 'closeMoreWebPanel') +
  method('async openApiComments', 'dismissApiComments') + method('async openApiBoards', 'saveApiAction') +
  ' }; Native;';
const compiled = ts.transpileModule(nativeClass, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
async function main() {
  requests[0].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0,
    data: [{ id: '808', username: 'late' }] } }) });
  await flush();
  assert.equal(messages.length, messageCount, 'Late contacts cannot reopen a closed share sheet');
  for (const wrapped of [false, true]) {
    const timers = [];
    const Native = vm.runInNewContext(compiled, { PIN_POST_API_ENABLED: true,
      JSON, setTimeout: callback => timers.push(callback), console });
    const native = new Native();
    Object.assign(native, { detail: { pinUrl: pin }, commentToken: 0, saveToken: 0,
      currentPinUrl: () => pin, pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '',
      showMessage: message => { throw new Error(message); } });
    const comments = { pin, loading: false, error: '', items: [{ id: '301', text: '真实评论' }] };
    const boards = { pin, loading: false, busy: false, error: '', items: [{ id: '401', name: '风景' }], shortlist: [] };
    let responsePin = pin;
    native.controller = { runJavaScript: async script => {
      if (!script.startsWith('JSON.stringify')) return 'true';
      const result = script.includes('commentsRead') ? comments : boards;
      const text = JSON.stringify({ ...result, pin: responsePin });
      return wrapped ? JSON.stringify(text) : text;
    } };
    await native.openApiComments(); await flush();
    assert.equal(native.commentResult.items[0].text, '真实评论', 'Both ArkWeb return encodings reach native comments');
    await native.openApiBoards(); await flush();
    assert.equal(native.saveResult.items[0].name, '风景');
    native.activeSheetKind = 'comments'; native.commentToken++;
    await timers[0]();
    assert.equal(native.commentResult.items[0].id, '301', 'Expired poll is ignored');
    responsePin = pin.replace('101', '999');
    await native.openApiComments(); await flush();
    assert.equal(native.commentResult.items.length, 0, 'A response for another Pin is rejected');
    assert.match(native.commentResult.error, /加载失败/);
  }
  console.log('detail fixes: absent DOM save, immediate share, late response, ArkWeb JSON encodings and Pin guards OK');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
