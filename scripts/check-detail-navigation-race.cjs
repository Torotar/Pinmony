const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  const rest = source.slice(start);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
const timers = [], logs = [], marks = [], effects = [];
const context = { Date, setTimeout: fn => timers.push(fn),
  isPinterestAuthRoute: url => url.includes('/login/'),
  PinWebRuntimeLog: { info: line => logs.push(line), warn: line => logs.push(line) } };
vm.runInNewContext(ts.transpileModule(`class Native {
  ${['supersedeRootPreparationForDetail', 'protectedDetailAddress', 'ignoreSupersededDetailDocument',
    'isCurrentPageFailure', 'waitForWebTabConfirmation', 'requestRootPage',
    'recordPageNavigation', 'syncNativeReturnRoute'].map(method).join('\n')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const pin = 'https://www.pinterest.com/pin/123/', oldPin = 'https://www.pinterest.com/pin/456/';
const search = 'https://www.pinterest.com/search/pins/?q=example', n = new context.Native();
let document = pin;
const detail = { pinUrl: pin, imageUrl: 'https://i.pinimg.com/hero.jpg', related: [{ pinUrl: oldPin }] };
Object.assign(n, { authStatus: 'authenticated', authEpoch: 10, activeTab: 1,
  tabRequestToken: 7, pageBackToken: 3, homeRecoveryToken: 2, rootReadToken: 7,
  rootReadAddress: search, rootReadStartedAt: Date.now(), pendingWebTab: 1,
  retainedRootTabPending: 1, retainedRootTabAddress: search, retainedHomeDocumentPending: true,
  navigationAddress: pin, pinStore: { detail, detailPin: pin, detailOpeningPin: '', detailActionsReady: true },
  nativeNetwork: { invalidate: () => effects.push('invalidate') },
  detailJourney: { mark: event => marks.push(event) }, controller: { getUrl: () => document },
  staleRootDocumentTarget: () => -1, effectiveRootDocumentTarget: () => 1,
  rootTabIndexFromAddress: url => url.includes('/search/') ? 1 : -1,
  extractPinUrl: url => url.includes('/pin/') ? url : '',
  refreshWebNavigation: async () => effects.push('refresh'), showMessage: () => effects.push('message') });
async function main() {
  n.waitForWebTabConfirmation(1, 7, Date.now());
  n.supersedeRootPreparationForDetail(); await timers[0]();
  assert.equal(n.tabRequestToken, 8); assert.equal(n.pageBackToken, 4);
  assert.equal(n.pendingWebTab, -1); assert.equal(n.rootReadToken, -1);
  assert.equal(n.retainedRootTabPending, -1); assert.equal(n.retainedRootTabAddress, '');
  assert.deepEqual(effects, [], 'old return/preparation timer cannot refresh or notify after new Pin intent');
  assert.equal(n.protectedDetailAddress(), pin, 'protection survives clearing detailOpeningPin after snapshot commit');
  assert.equal(n.ignoreSupersededDetailDocument(search), true);
  assert.equal(n.pinStore.detail, detail); assert.equal(n.pinStore.detailActionsReady, true);
  assert.equal(n.authEpoch, 10, 'a late callback for a document that is no longer real cannot alter epoch');
  document = search;
  n.recordPageNavigation(search); n.syncNativeReturnRoute(search);
  assert.equal(n.navigationAddress, pin, 'obsolete handlers do not advance native navigation state');
  assert.equal(n.ignoreSupersededDetailDocument(search), true);
  assert.equal(n.pinStore.detail, detail, 'actual old-root document cannot erase current native content');
  assert.equal(n.pinStore.detailActionsReady, false, 'real document change invalidates old operation controls');
  assert.equal(n.pinStore.detailPresentationOnly, true, 'successful presentation remains read-only for on-demand preparation');
  assert.equal(n.authEpoch, 11); assert.deepEqual(effects, ['invalidate']);
  assert.equal(n.isCurrentPageFailure(search), false, 'old search failure cannot become current detail failure');
  assert.equal(n.isCurrentPageFailure(oldPin), false);
  assert.equal(n.isCurrentPageFailure(pin + '?different=1'), false, 'failure URL matching preserves complete query');
  assert.equal(n.isCurrentPageFailure(pin), true);
  n.requestRootPage(1); assert.deepEqual(effects, ['invalidate'], 'visible detail prevents new root demand');
  n.nativeBackTarget = search;
  assert.equal(n.ignoreSupersededDetailDocument(search), false, 'explicit user back may open its root target');
  assert.equal(n.isCurrentPageFailure(search), true, 'real current return failure remains retryable');
  n.nativeBackTarget = ''; n.authStatus = 'checking';
  assert.equal(n.ignoreSupersededDetailDocument('https://www.pinterest.com/login/'), false);
  assert.equal(n.isCurrentPageFailure('https://www.pinterest.com/login/'), true);
  const begin = source.slice(source.indexOf('.onPageBegin((event) => {'), source.indexOf('.onPageEnd('));
  assert(begin.indexOf('ignoreSupersededDetailDocument') < begin.indexOf('else this.clearDetail()'));
  assert(source.slice(source.indexOf('this.shareBridge.onPageNavigation ='), source.indexOf('this.shareBridge.onShare =')).includes('ignoreSupersededDetailDocument(url)'));
  assert(marks.includes('document.superseded.actions.invalidated'));
  assert(!logs.join('\n').includes('https://'));
  console.log('Detail navigation race: old return/preparation superseded, post-commit lifetime guard, real-document operation invalidation, exact failure ownership and explicit back/auth boundaries passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
