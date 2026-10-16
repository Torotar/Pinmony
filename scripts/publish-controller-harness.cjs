const { runtime } = require('./return-coordinator-harness.cjs');
function create(ts, globals = {}) {
  const r = runtime(ts, globals);
  const foundation = { ...r.foundation, PinmonyRuntimeLog: { info() {}, warn() {} } };
  return r.compile('feature_profile/src/main/ets/controllers/PinmonyPublishController.ets', () => foundation);
}
function bind(native, ts, globals = {}) {
  const { PinmonyPublishController } = create(ts, globals);
  native.profileStore.publishRequestToken ??= 0;
  native.profileStore.publishFlowToken ??= 0;
  native.publishController = new PinmonyPublishController(native.profileStore, {
    authenticated: () => native.authStatus === 'authenticated', foreground: () => !native.businessSuspended,
    activeProfileTab: () => native.activeTab === 3,
    menuVisible: () => native.activeSheetKind === 'publish' && native.showNativeSheet,
    sheetAvailable: () => !native.activeSheetKind,
    setMenuVisible: visible => { native.showNativeSheet = visible; native.activeSheetKind = visible ? 'publish' : ''; },
    waitMenuClosed: () => Promise.resolve(true),
    profileAddress: () => native.profileUrlFromAddress(native.authenticatedProfileUrl || ''),
    documentMatches: profile => native.profileDocumentMatches(profile), currentDocument: () => native.controller.getUrl(),
    normalizeProfile: address => native.profileUrlFromAddress(address),
    prepareContext: current => native.ensureRootActionContext(3, true, 'publish', current),
    nativeEnabled: () => true, publishScript: () => '', runScript: script => native.controller.runJavaScript(script),
    jsonText: value => native.webJsonText(value),
    captureBoardReturn: () => { native.publishBoardReturn = native.nativeBoardVisible?.() ? native.boardStore.boardDetail?.pageKey || '' : ''; },
    hasBoardReturn: () => !!native.publishBoardReturn, restoreBoard: () => native.restorePublishBoard?.(),
    syncMotion: () => native.syncFloatingTabsMotion?.(), suppressChildBack() {}, refreshProfile: () => native.refreshProfile?.(),
    pickPhotos: (token, page) => native.pickPublishPhotos?.(token, page) || Promise.resolve(),
    feedback: value => native.showMessage(value), traceEntry: () => native.traceAction('profile.publish')
  });
}
module.exports = { create, bind };
