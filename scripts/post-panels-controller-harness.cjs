const { runtime } = require('./return-coordinator-harness.cjs');
function create(ts, globals = {}) { const r = runtime(ts, globals); return r.compile('feature_pin/src/main/ets/controllers/PinmonyPostPanelsController.ets', () => r.foundation); }
function bind(native, ts, globals = {}) {
  const { PinmonyPostPanelsController } = create(ts, globals);
  native.postPanelsController = new PinmonyPostPanelsController(native.pinStore, {
    authenticated: () => native.authStatus === 'authenticated', foreground: () => !native.businessSuspended,
    document: () => native.controller.getUrl(), sheet: () => native.activeSheetKind,
    show: kind => { native.activeSheetKind = kind; native.showNativeSheet = !!kind; }, currentPin: () => native.currentPinUrl(),
    pinIdentity: pin => native.pinIdentity(pin), moreCurrent: pin => native.isCurrentMorePin(pin),
    runScript: script => native.controller.runJavaScript(script), jsonText: raw => native.webJsonText(raw), feedback: message => native.showMessage(message),
    saveDismissed() {}, editCompleted: async () => {}, prepareComment: async encoded => encoded
  });
}
module.exports = { create, bind };
