const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync(process.argv[3] || 'entry/src/main/ets/pages/Index.ets', 'utf8');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, { common_foundation: {
  PinmonyRuntimeLog: { info() {}, warn() {} },
  PinmonyTaskRegistry: class { invalidate() {} timeout() {} }
} });
const { PinmonyPublishController } = loader.loadFile('feature_profile/src/main/ets/controllers/PinmonyPublishController.ets');
function method(name, optional = false) {
  const start = source.indexOf('  private ' + name + '(');
  if (optional && start < 0) return '';
  assert(start >= 0, name);
  const end = source.indexOf('\n  private ', start + 1);
  return source.slice(start, end < 0 ? source.length : end);
}
function bodyAt(position) {
  const start = source.indexOf('{', position);
  let depth = 1, end = start + 1;
  for (; depth && end < source.length; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(start + 1, end - 1);
}
const bindingStart = source.indexOf('  private readonly publishController:');
const bindingEnd = source.indexOf('\n  private ', bindingStart + 1);
const binding = source.slice(bindingStart, bindingEnd).trim()
  .replace(/^private readonly /, 'this.').replace(/: PinmonyPublishController = /, ' = ');
const sheet = source.indexOf('.bindSheet($$this.showNativeSheet');
const disappear = bodyAt(source.indexOf('onDisappear:', sheet));
const willDismiss = bodyAt(source.indexOf('onWillDismiss:', sheet));
const context = { PinmonyPublishController, PIN_NATIVE_SHARE_PUBLISH_ENABLED: true,
  PIN_NATIVE_NETWORK_ENABLED: true, PinmonyRuntimeLog: { info() {} },
  PinmonyI18n: { render: value => value }, Promise, Date };
const code = 'class Host {' + ['dismissProfilePublish', 'restorePublishBoard', 'nativeModalLabel']
  .map(name => method(name)).join('\n') + method('finishPublishMenuClose', true) +
  ' runDisappear(){' + disappear + '} runWillDismiss(action){' + willDismiss + '}' +
  ' bind(){' + binding + '} } Host;';
const Host = vm.runInNewContext(ts.transpileModule(code, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, context);
const profile = 'https://www.pinterest.com/synthetic/';
const board = profile + 'board/';
function harness(mode) {
  const h = new Host(); let restores = 0, pauses = 0, opens = 0;
  const options = [{ id: 'photo', kind: 'photo', enabled: true }];
  const detail = { pageKey: board, nativeVersion: 1, flow: mode === 'section' ? { phase: 'section' } : undefined };
  Object.assign(h, {
    nativeBusinessRoutesEnabled: true, authStatus: 'authenticated', businessSuspended: false,
    activeTab: 3, activeSheetKind: '', showNativeSheet: false, publishSheetClosing: false,
    publishBoardRestorePending: false, publishBoardReturn: '', nativeChildBackUntil: 0,
    profileStore: { profile: { profileUrl: profile }, profileUrl: profile, profileSession: 1,
      publishRequestToken: 0, publishFlowToken: 0 }, boardStore: { boardDetail: detail },
    profileUrlFromAddress: value => value, authenticatedProfileUrl: profile,
    nativeBoardVisible: () => mode !== 'profile', nativeRootOnly: false,
    pagePerformance: { cancel() {} }, detailReturnJourney: { close() {} },
    publishNativeFlow: { menu: async current => {
      if (current()) { h.profileStore.publishOptions = options; h.profileStore.publishLoading = false; }
      return true;
    }, pause() { pauses++; }, open: async () => { opens++; return true; } },
    traceAction() {}, syncFloatingTabsMotion() {}, showMessage() {}, uiText: key => key,
    rootContextCoordinator: { notify() {} }, pageTasks: { timeout() {} },
    pinStore: {}, returnCoordinator: { cancel() { restores++; } }, pageBackToken: 0,
    notifyDetailSystemShareClosed() {}, homeStore: {},
    nativeBusinessSessionContext() {}, nativeNetwork: {}, refreshProfile() {},
    openBoardSection() { opens++; }, pickPublishPhotos() {},
    loadReturnTarget() { throw Error('Native board should stay mounted'); }
  });
  h.bind(); h.publishController.openMenu();
  return { h, options, counts: () => ({ restores, pauses, opens }) };
}
async function run() {
  for (const mode of ['board', 'section', 'profile']) {
    for (const close of ['button', 'interactive', 'binding-first']) {
      const { h, options, counts } = harness(mode);
      await Promise.resolve();
      const title = h.nativeModalLabel(), returnPage = h.publishBoardReturn;
      if (close === 'binding-first') h.showNativeSheet = false;
      let dismissed = 0;
      if (close === 'button') h.dismissProfilePublish();
      else h.runWillDismiss({ dismiss() { dismissed++; } });
      assert.equal(h.showNativeSheet, false);
      assert.equal(h.activeSheetKind, 'publish', 'retain the rendered Sheet until animation completion');
      assert.equal(h.publishBoardReturn, returnPage, 'boardMode and section row must stay stable during exit');
      assert.equal(h.nativeModalLabel(), title, 'title must not switch to the profile title during exit');
      assert.equal(h.profileStore.publishOptions, options);
      assert.equal(counts().restores, 0, 'restore parent only after native exit finishes');
      const token = h.profileStore.publishRequestToken;
      h.dismissProfilePublish(); assert.equal(h.profileStore.publishRequestToken, token, 'duplicate close is idempotent');
      h.runDisappear(); h.runDisappear();
      assert.equal(h.activeSheetKind, ''); assert.equal(h.publishSheetClosing, false);
      assert.equal(h.publishBoardReturn, '');
      assert.equal(counts().restores, mode === 'profile' ? 0 : 1);
      assert.equal(dismissed, close === 'button' ? 0 : 1);
      h.publishController.openMenu(); await Promise.resolve();
      assert.equal(h.showNativeSheet, true, 'reopen works after cleanup');
      h.finishPublishMenuClose(); assert.equal(h.showNativeSheet, true, 'late callback cannot close an open Sheet');
    }
  }
  for (const target of ['photo', 'section']) {
    const { h, counts } = harness('board'); await Promise.resolve();
    const selected = target === 'section' ? h.publishController.selectSection() : h.publishController.select('photo');
    assert.equal(counts().opens, 0); assert.equal(h.publishBoardReturn, board);
    h.runDisappear(); await selected;
    assert.equal(counts().opens, 1, 'handoff starts only after native disappearance');
    assert.equal(counts().restores, 0, 'handoff keeps the retained board context');
    assert.equal(h.publishBoardReturn, board);
    h.activeSheetKind = 'share'; h.showNativeSheet = false;
    h.finishPublishMenuClose(); assert.equal(h.activeSheetKind, 'share', 'stale publish cleanup cannot clear another Sheet');
  }
  // Fallback: a native visibility update without onWillDismiss still cleans up once.
  const { h, counts } = harness('board'); await Promise.resolve();
  h.showNativeSheet = false; h.runDisappear(); h.runDisappear();
  assert.equal(counts().restores, 1); assert.equal(h.publishSheetClosing, false);
  for (const interrupt of ['background', 'logout']) {
    const { h: interrupted, counts: interruptedCounts } = harness('board'); await Promise.resolve();
    interrupted.dismissProfilePublish();
    if (interrupt === 'background') interrupted.businessSuspended = true;
    else interrupted.authStatus = 'unauthenticated';
    interrupted.runDisappear();
    assert.equal(interruptedCounts().restores, 0, 'do not restore a board in an inactive session');
    assert.equal(interrupted.publishBoardRestorePending, false);
    assert.equal(interrupted.activeSheetKind, '');
  }
  const loading = harness('board');
  loading.h.profileStore.publishOptions = []; loading.h.profileStore.publishLoading = true;
  loading.h.dismissProfilePublish();
  assert.equal(loading.h.profileStore.publishLoading || loading.h.publishSheetClosing &&
    loading.h.profileStore.publishOptions.length === 0, true, 'keep the loading branch until exit completes');
  const prepared = loading.h.profileStore.publishPreparing;
  loading.h.profileStore.publishPreparing = true;
  await Promise.resolve();
  assert.equal(loading.h.profileStore.publishPreparing, true, 'late menu completion cannot update the closed generation');
  loading.h.profileStore.publishPreparing = prepared;
  loading.h.runDisappear();
  console.log('Publish menu exit: stable board/section/title/content, native dismissal, duplicate callbacks, reopen and subflow handoff passed');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
