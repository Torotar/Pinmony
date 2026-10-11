const { runtime } = require('./return-coordinator-harness.cjs');
function create(ts, globals = {}) {
  const r = runtime(ts, { Observed: value => value, ...globals });
  const cache = r.compile('feature_inbox/src/main/ets/services/PinmonyInboxCache.ets', () => ({}));
  const store = r.compile('feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets', () => cache);
  const controller = r.compile('feature_inbox/src/main/ets/controllers/PinmonyInboxReadController.ets', () =>
    ({ ...r.foundation, PinmonyRuntimeLog: { info() {}, warn() {} } }));
  return { ...controller, Store: store.PinmonyInboxStore };
}
function bind(native, ts, globals = {}) {
  const { PinmonyInboxReadController } = create(ts, globals);
  native.inboxReadController = new PinmonyInboxReadController(native.inboxStore, {
    authenticated: () => native.authStatus === 'authenticated', foreground: () => !native.businessSuspended,
    document: () => native.controller.getUrl(), addressKey: a => native.pageHistory.key(a),
    inboxAddress: a => native.inboxUrlFromAddress(a), currentInbox: () => native.currentInboxUrl(),
    activeTab: () => native.activeTab, pendingTab: () => native.pendingWebTab, rootAddress: () => native.rootTabAddresses?.get(2) || '',
    rootOnly: () => !!native.nativeRootOnly, interacted: () => !!native.rootContentInteracted, backTarget: () => native.nativeBackTarget,
    runScript: script => native.controller.runJavaScript(script), finishPull: () => native.finishRootPull('inbox'),
    readInvitations: () => native.readBoardInvitations(), recordAddress: a => native.rootTabAddresses.set(2, a), confirmed: () => native.markRootPerformance(2),
    readStarted: () => native.pagePerformance.count(2, 'read'),
    cancelled: count => native.pagePerformance.count(2, 'cancel', count),
    prepareContext: () => native.ensureRootActionContext(2, false), prepareRead: () => native.prepareRootPageRead(2),
    requestRead: () => native.requestRootPage(2), feedback: message => native.showMessage(message)
  });
}
module.exports = { create, bind };
