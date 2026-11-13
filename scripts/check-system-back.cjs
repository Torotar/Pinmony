const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  onBackPress(): boolean');
const end = source.indexOf('\n  @Builder', start);
const sandbox = { Date, PinmonyRuntimeLog: { info() {} }, PinmonyPageRecovery: { clear() {} }, PinmonyI18n: { message: key => key } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Page {' + source.slice(start, end) +
  '} globalThis.Page = Page;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, sandbox);
function page() {
  return Object.assign(new sandbox.Page(), {
    rootExitBackAt: 0, showMessage() {},
    pageRecovery: { cancel() {} }, imageViewer: { visible: false }, noticeChats: [],
    searchController: { cancelSubmittedPin: () => false }, restoreInboxNewsSearchParent: () => false,
    nativeBoardVisible: () => false,
    profileChatActive: false,
    getUIContext: () => ({ getHostContext: () => ({ terminateSelf: () => Promise.resolve() }) }),
    nativeChildBackUntil: 0, authStatus: 'authenticated', profileSettingsVisible: false, authWebVisible: () => false,
    pinStore: { shareBackHandledUntil: 0 }, inboxStore: {}, profileStore: { origins: [] }, searchStore: {}, boardStore: {},
    activeSheetKind: '', pageHistory: { isPending: () => false },
    nativeRootTabsVisible: () => true,
    handleBack() { throw Error('root must not consult hidden Web history'); },
    currentProfileUrl: () => '', currentSearchPageKey: () => '', currentPinUrl: () => '', currentBoardUrl: () => ''
  });
}
for (const activeTab of [0, 1, 2, 3]) {
  const root = page(); root.activeTab = activeTab;
  assert.equal(root.onBackPress(), true, 'each root consumes the first back and prompts, even if data failed');
  assert(root.rootExitBackAt > 0);
}
const login = page(); login.authStatus = 'checking'; login.authWebVisible = () => true; login.nativeRootTabsVisible = () => false;
assert.equal(login.onBackPress(), false, 'visible login screen delegates back');
for (const authStatus of ['unauthenticated', 'checking', 'error']) {
  const loggedOut = page(); let exits = 0, prompts = 0;
  loggedOut.authStatus = authStatus; loggedOut.authWebVisible = () => true;
  loggedOut.nativeRootTabsVisible = () => false; loggedOut.loggedOutAccounts = { active: true };
  loggedOut.showMessage = () => prompts++;
  loggedOut.getUIContext = () => ({ getHostContext: () => ({ terminateSelf: () => { exits++; return Promise.resolve(); } }) });
  assert.equal(loggedOut.onBackPress(), true); assert.equal(prompts, 1); assert.equal(exits, 0);
  assert.equal(loggedOut.onBackPress(), true); assert.equal(exits, 1, 'explicit-logout login root exits only on second back');
  const timeout = page(); timeout.authStatus = authStatus; timeout.loggedOutAccounts = { active: true };
  timeout.authWebVisible = () => true; timeout.rootExitBackAt = Date.now() - 2100;
  timeout.showMessage = () => prompts++;
  timeout.onBackPress(); assert.equal(prompts, 2, 'outside two seconds prompts again');
}
const sheet = page(); let closed = 0;
sheet.activeSheetKind = 'comments'; sheet.dismissApiComments = () => { closed++; sheet.activeSheetKind = ''; };
assert.equal(sheet.onBackPress(), true); assert.equal(closed, 1);
assert.equal(sheet.onBackPress(), true, 'duplicate child event does not exit the root');
sheet.nativeChildBackUntil = 0; assert.equal(sheet.onBackPress(), true);
const detail = page(); detail.nativeRootTabsVisible = () => false;
detail.pinStore.detail = {}; detail.backFromDetail = () => closed++;
assert.equal(detail.onBackPress(), true); assert.equal(closed, 2);
console.log('System back: root prompt/login delegation, child dismissal and duplicate event guard passed');

const image = page();
image.pinStore.imageLayer = 'zoom';
image.closeImageLayer = () => { image.pinStore.imageLayer = ''; };
assert.equal(image.onBackPress(), true, 'image viewer consumes back before detail navigation');
assert.equal(image.pinStore.imageLayer, '');

const publish = page(); publish.profileStore.publishFlow = { phase: 'boards', kind: 'website', busy: false, uncertain: false };
const publishActions = []; publish.publishFlowAction = action => publishActions.push(action);
assert.equal(publish.onBackPress(), true); assert.deepEqual(publishActions, ['back']);
publish.profileStore.publishFlow.busy = true; assert.equal(publish.onBackPress(), true); assert.equal(publishActions.length, 1, 'in-flight write consumes back without navigation');
publish.profileStore.publishFlow.busy = false; publish.profileStore.publishFlow.uncertain = true;
assert.equal(publish.onBackPress(), true); assert.equal(publishActions.at(-1), 'back', 'publish controller decides whether an uncertain flow closes without replay');
console.log('Publish nested/system back and pending-write protection passed');
