const { runtime } = require('./return-coordinator-harness.cjs');
function create(ts, globals = {}) {
  const r = runtime(ts, globals);
  return r.compile('feature_board/src/main/ets/controllers/PinmonyBoardStateController.ets', () => ({ ...r.foundation, PinmonyRuntimeLog: { info() {}, warn() {} } }));
}
function bind(native, ts, globals = {}) {
  const { PinmonyBoardStateController } = create(ts, globals);
  native.boardStateController = new PinmonyBoardStateController(native.boardStore, {
    authenticated: () => native.authStatus === 'authenticated', foreground: () => !native.businessSuspended,
    rootOnly: () => !!native.nativeRootOnly, currentBoard: () => native.currentBoardUrl(),
    boardAddress: address => native.boardUrlFromAddress(address), profileAddress: address => native.profileUrlFromAddress(address),
    pinAddress: address => native.extractPinUrl(address), addressKey: address => native.pageHistory.key(address),
    publishReturn: () => native.publishBoardReturn, hasDetail: () => !!native.pinStore.detail || !!native.pinStore.detailOpeningPin,
    backTarget: () => native.nativeBackTarget, retainedContent: () => native.retainedBoardContent,
    movePage: () => native.singlePinMovePage, clearMovePage: () => native.singlePinMovePage = '',
    confirmInvitation: page => { if (native.inboxStore.boardInvitationPreview?.boardUrl === page && native.inboxStore.invitationReadPage !== page) native.readBoardInvitations(true); },
    invalidateProfile: () => { native.profileStore.profileActionsReady = false; native.clearProfile(); native.profileStore.profileCache.clear(); native.controller.runJavaScript('window.PinmonyProfileApi && window.PinmonyProfileApi.reset()').catch(() => {}); },
    feedback: message => native.showMessage(message), closeFlow: () => native.boardOperation('flow', JSON.stringify({ action: 'close' })),
    back: () => native.backFromBoard(), navigate: page => native.controller.loadUrl(page)
  });
}
module.exports = { create, bind };
